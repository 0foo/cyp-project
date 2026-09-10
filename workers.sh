#!/usr/bin/env bash
#==============================================================================
# workers.sh
#
# Supervisor for worker.sh. Starts N workers as detached daemons, stops
# them cleanly, and reports progress.
#
# This script holds no state of its own beyond pid files. The workers
# coordinate with each other through $STATE_DIR (see the header of
# worker.sh); this is only a convenience wrapper for launching them.
#
#------------------------------------------------------------------------------
# USAGE
#
#   ./workers.sh start [n]    launch n workers (default 4)
#   ./workers.sh stop         SIGTERM all of them, gracefully
#   ./workers.sh status       pid check + queue counts (the default)
#
# Configuration is passed to the workers through the environment, so either
# export what you need first:
#
#   export IN_DIR=/data/genomes WORK_DIR=/scratch/rmodeler/work THREADS=6
#   ./workers.sh start 4
#
# ...or edit the defaults below. Whatever is set here is exported, so all
# workers inherit an identical configuration -- which they must, since they
# share $STATE_DIR and $OUT_DIR.
#
#------------------------------------------------------------------------------
# HOW MANY WORKERS
#
# Total cores used is roughly n * THREADS, capped per container by --cpus.
# On a 24-core / 124 GB box, `start 4` with THREADS=6 is the sane default.
#
# Adding workers later is safe -- a new one just joins in and starts claiming
# unclaimed genomes. There is no need to stop the others first.
#
#------------------------------------------------------------------------------
# STOPPING
#
# `stop` sends SIGTERM, which each worker traps: it stops its running
# container, releases its claim WITHOUT writing a state marker, deletes that
# genome's scratch directory, and exits. Interrupted genomes are simply picked
# up again next time you start.
#
# Never use kill -9 here. A hard kill leaves claims and containers orphaned.
# They are recoverable -- the next worker startup reaps them -- but you lose
# the graceful container shutdown and it makes `status` misleading until then.
#
# `stop` returns as soon as the signals are sent. Containers take up to
# STOP_GRACE seconds to actually go away; watch `docker ps` if you need to
# know when the box is idle.
#
#==============================================================================

set -uo pipefail

# Resolve the worker next to this script, so it works from any cwd.
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
WORKER="$HERE/worker.sh"

#=================================================================== config file
# Optional. Same reader as worker.sh (kept duplicated on purpose -- these are
# standalone scripts with no shared library, matching how the rest of the
# configuration is handled). See worker.sh's copy of this comment for the
# full rationale; short version: plain KEY=value lines, not `source`, looked
# up from $CONFIG_FILE or <script dir>/rmodeler.conf, and only used to fill
# in settings the environment didn't already set.
#
# Every variable this loads is exported, not just plain-assigned -- workers
# started below only inherit what's in the environment, so a config-file
# setting that isn't on the hardcoded `export` list further down (GLOB,
# MEM_LIMIT, ENGINE, ...) would otherwise silently fail to reach them.
_CONFIG_LOADED_FROM=""
load_config() {
    local file="${CONFIG_FILE:-$HERE/rmodeler.conf}"
    [[ -f $file ]] || return 0

    local line key value
    while IFS= read -r line || [[ -n $line ]]; do
        line="${line%%#*}"
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"
        [[ -z $line || $line != *=* ]] && continue

        key="${line%%=*}"
        value="${line#*=}"
        [[ $key =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || continue

        if [[ $value == \"*\" ]]; then value="${value#\"}"; value="${value%\"}"
        elif [[ $value == \'*\' ]]; then value="${value#\'}"; value="${value%\'}"
        fi

        if [[ -z ${!key+x} ]]; then
            printf -v "$key" '%s' "$value"
            export "$key"
        fi
    done < "$file"
    _CONFIG_LOADED_FROM=$file
}
load_config
[[ -n $_CONFIG_LOADED_FROM ]] && echo "config: $_CONFIG_LOADED_FROM" >&2

#=============================================================== configuration
# Exported, so every worker launched below inherits the same values. Each is
# ${VAR:-default}, so anything already set in your environment wins.
export IN_DIR="${IN_DIR:-/data/genomes}"                # gzipped genome FASTAs
export RM_IMAGE="${RM_IMAGE:-dfam/tetools:latest}"      # container with RepeatModeler
export DOCKER="${DOCKER:-docker}"                       # or "sudo docker" / "podman"
export WORK_DIR="${WORK_DIR:-/scratch/rmodeler/work}"   # scratch; needs lots of room
export OUT_DIR="${OUT_DIR:-/data/rmodeler/out}"         # families files
export STATE_DIR="${STATE_DIR:-/data/rmodeler/state}"   # claimed/ done/ failed/
export LOG_DIR="${LOG_DIR:-/data/rmodeler/logs}"        # per-genome + per-worker logs
export THREADS="${THREADS:-6}"                          # cores per genome
export GLOB="${GLOB:-*.fna.gz}"                         # which files in $IN_DIR count as input;
                                                         # status() below reads this same var so
                                                         # the "queued" count matches what workers
                                                         # actually process

# Pid files live here, one per worker slot. Under $STATE_DIR by default so
# everything about a run sits in one place.
RUN_DIR="${RUN_DIR:-$STATE_DIR/run}"
mkdir -p "$RUN_DIR" "$LOG_DIR"

#======================================================================= start
# Launch workers 1..n, skipping any slot whose worker is already alive. That
# makes `start` idempotent: run it again after one worker dies and only the
# dead slot is refilled.
start() {
    local n=${1:-4} i

    # Pull once, here, rather than letting n workers each start the same
    # download. The workers themselves refuse to run if the image is missing.
    if ! $DOCKER image inspect "$RM_IMAGE" >/dev/null 2>&1; then
        echo "pulling $RM_IMAGE ..."
        $DOCKER pull "$RM_IMAGE" || exit 1
    fi

    for (( i=1; i<=n; i++ )); do
        local pidf="$RUN_DIR/worker-$i.pid" pid=""

        # kill -0 sends no signal; it just asks whether that pid exists.
        [[ -f $pidf ]] && pid=$(cat "$pidf")
        if [[ -n $pid ]] && kill -0 "$pid" 2>/dev/null; then
            echo "worker $i already running (pid $pid)"; continue
        fi

        # WORKER_ID="w$i" prefixed to the command sets that variable for this
        # one invocation only, giving each worker a distinct tag in the logs.
        #
        # setsid    : new session, detached from this terminal
        # nohup     : ignore SIGHUP if the terminal goes away anyway
        # </dev/null: never block waiting on stdin
        # >>...out  : capture the worker's own log lines (stderr) per slot;
        #             per-genome container output goes to $LOG_DIR/<sample>.log
        WORKER_ID="w$i" setsid nohup "$WORKER" \
            >>"$LOG_DIR/worker-$i.out" 2>&1 < /dev/null &
        echo $! > "$pidf"
        echo "started worker $i (pid $!)"

        # Stagger: without it n workers all decompress a genome at the same
        # instant and thrash the disk before any of them reaches RepeatModeler.
        sleep 2
    done
}

#======================================================================== stop
# SIGTERM each live worker. The worker's own trap does the real work -- stop
# the container, release the claim, exit -- so there is nothing to clean up
# here beyond the pid files.
stop() {
    local pidf pid
    for pidf in "$RUN_DIR"/worker-*.pid; do
        [[ -f $pidf ]] || continue       # no matches: glob stays literal
        pid=$(cat "$pidf")
        if kill -0 "$pid" 2>/dev/null; then
            echo "stopping $(basename "$pidf" .pid) (pid $pid)"
            kill -TERM "$pid"
            # Don't remove the pid file until the worker has actually exited.
            # Containers take up to STOP_GRACE seconds to stop, and `stop`
            # itself is meant to return immediately -- if the pid file
            # disappeared right away, a `start` run in that window would see
            # a "free" slot and launch a second worker while the first is
            # still shutting down. Poll for exit in the background instead,
            # so `stop` still returns without waiting.
            ( while kill -0 "$pid" 2>/dev/null; do sleep 1; done; rm -f "$pidf" ) &
            disown
        else
            rm -f "$pidf"
        fi
    done
}

#====================================================================== status
# Two independent views, because they can legitimately disagree.
#
# The pid section says which worker PROCESSES are alive. The counts below say
# what the QUEUE looks like, read straight from the state directories -- the
# same source of truth the workers use, so it is accurate even for workers
# started by hand rather than through this script.
#
# A "dead (stale pidfile)" line means that worker exited without going through
# `stop`. If it was killed hard, its claim is still sitting in claimed/ and
# will be reaped the next time any worker starts.
status() {
    local pidf pid
    for pidf in "$RUN_DIR"/worker-*.pid; do
        [[ -f $pidf ]] || continue
        pid=$(cat "$pidf")
        if kill -0 "$pid" 2>/dev/null; then
            echo "$(basename "$pidf" .pid): running (pid $pid)"
        else
            echo "$(basename "$pidf" .pid): dead (stale pidfile)"
        fi
    done
    echo

    # queued is the TOTAL input count, not the remaining count. Remaining is
    # queued - done - failed - running. Uses $GLOB, same as worker.sh, so this
    # count matches what workers actually process even if GLOB is customized.
    echo "queued : $(find "$IN_DIR" -maxdepth 1 -name "$GLOB" | wc -l)"
    echo "running: $(find "$STATE_DIR/claimed" -maxdepth 1 -mindepth 1 -type d | wc -l)"
    echo "done   : $(find "$STATE_DIR/done"    -maxdepth 1 -type f | wc -l)"
    echo "failed : $(find "$STATE_DIR/failed"  -maxdepth 1 -type f | wc -l)"
    echo

    # Live containers, matched by the label worker.sh stamps on them so
    # nothing else running on this box gets listed.
    $DOCKER ps --filter label=rmworker.sample \
        --format '  container: {{.Names}}  {{.Status}}  {{.RunningFor}}' 2>/dev/null

    # Claimed genomes. A name here with no matching container usually means
    # the worker is decompressing, or the claim is stale.
    find "$STATE_DIR/claimed" -maxdepth 1 -mindepth 1 -type d -printf '  in progress: %f\n' 2>/dev/null
}

#=================================================================== dispatch
# Defaults to status, so a bare `./workers.sh` is always safe to run.
case "${1:-status}" in
    start)  start "${2:-4}" ;;
    stop)   stop ;;
    status) status ;;
    *) echo "usage: $0 {start [n]|stop|status}" >&2; exit 2 ;;
esac