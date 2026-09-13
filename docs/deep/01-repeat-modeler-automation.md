# `repeat-modeler-automation/` in depth

Two standalone bash scripts and a mandatory config file. No shared library — the config
reader is duplicated verbatim between them, deliberately.

| File | Lines | Role |
|---|---|---|
| `worker.sh` | 664 | one worker: claim a genome, run the container, record the outcome |
| `rm-manager.sh` | 299 | supervisor: start/stop/status over N workers |
| `rmodeler.conf.example` | 53 | complete, working template |
| `rmodeler.conf` | 53 | the live config (committed; differs from the example — see below) |

Roughly half of `worker.sh` is comments. They are unusually good and explain *why* rather
than *what*; this document does not repeat them, it covers the structure and the
consequences.

---

## 1. Configuration

### The contract

`worker.sh:166-245`, duplicated at `rm-manager.sh:87-166`.

Sixteen recognised keys:

```
IN_DIR WORK_DIR OUT_DIR STATE_DIR LOG_DIR RUN_DIR
RM_IMAGE DOCKER THREADS MEM_LIMIT GLOB
LTRSTRUCT KEEP_WORK RETRY_FAILED STOP_GRACE WORKERS
```

Both scripts accept all sixteen even though each uses only a subset (`WORKERS` and `RUN_DIR`
are the manager's; the rest are mostly the worker's). One file serves both.

The reader enforces, in order (`worker.sh:190-224`):

1. every non-blank, non-comment line is `KEY=value` — otherwise `die`
2. the key matches `^[A-Za-z_][A-Za-z0-9_]*$` — otherwise `die`
3. the key is in `CONFIG_KEYS` — **an unknown key is a hard error, not a skipped line**
4. the key has not already been seen — duplicates `die`
5. one matching pair of surrounding quotes is stripped
6. after the file is read, every key in `CONFIG_KEYS` must have been seen

Point 3 is the one that earns its keep. A typo'd setting that is silently ignored looks
exactly like one that was applied, and you find out three hours into a run.

### Why environment variables are discarded

`worker.sh:186` unsets all sixteen names *before* reading the file. `THREADS=2 ./worker.sh`
does not override, and does not survive as a leftover either.

The reasoning (`worker.sh:152-157`): N workers share `$STATE_DIR`, `$OUT_DIR` and
`$WORK_DIR`, and only behave if all of them were configured identically. A per-invocation
override is precisely how two workers end up disagreeing about where the queue lives.

Note the interaction with `rm-manager.sh`: the manager `export`s every setting
(`rm-manager.sh:135`), so launched workers inherit them — but each worker then *re-reads and
unsets* them anyway. A worker started by hand and one started by the manager are configured
identically by construction.

### Not `source`

The reader is hand-rolled rather than `source rmodeler.conf` (`worker.sh:159-161`). The
config file therefore cannot execute shell commands — it can only set the sixteen names.

### Validation

`validate_config()` (`worker.sh:229-242`):

- nine path/name settings must be non-empty
- `THREADS`, `WORKERS` must match `^[1-9][0-9]*$`
- `LTRSTRUCT`, `KEEP_WORK`, `RETRY_FAILED` must be exactly `0` or `1`
- `STOP_GRACE` must be `^[0-9]+$` (zero permitted, unlike the two above)
- `IN_DIR` must exist

`MEM_LIMIT` is **not** validated and may be empty (meaning unlimited). It is passed through
to `docker run --memory` unchecked.

### The committed `rmodeler.conf`

It differs from the example in four values:

```diff
-IN_DIR=/data/genomes
+IN_DIR=/data/genomes/1_masked_datasets/genomes_dhakad
-WORK_DIR=/scratch/rmodeler/work
+WORK_DIR=/data/rmodeler/scratch/rmodeler/work
-WORKERS=4
+WORKERS=2
-THREADS=6
+THREADS=2
```

Two workers × 2 threads = 4 cores, versus the example's 24. This is a real machine's
config, not a template — and `genomes_dhakad` ties it to the `Dhakad_et_al_2025` dataset
named in the archive ([`OCR docs/04`](../../OCR%20docs/04-atallah-lab-spring-2026-log.md)).

> Committing a live `rmodeler.conf` means a fresh clone silently inherits someone else's
> paths. It contains no secrets, but `cp rmodeler.conf.example rmodeler.conf` — the
> documented first step — will refuse to overwrite without `-f`, so check what you have.

---

## 2. Concurrency

See [`docs/diagrams/02-worker-concurrency.md`](../diagrams/02-worker-concurrency.md) for the
state machine and the race sequence.

### State is directory names

```
$STATE_DIR/claimed/<sample>/owner    in progress
$STATE_DIR/done/<sample>             finished OK
$STATE_DIR/failed/<sample>           failed, scratch + log kept
```

A genome named in none of the three is available. **That fourth state is not recorded
anywhere** — it is the absence of the other three, recomputed from `$IN_DIR` on every pass
(`worker.sh:634-661`).

Nothing is ever *read* to decide what to work on next. There is no file for workers to
disagree about and nothing to keep in sync.

### `claim()` — the whole lock

```bash
claim() {
    mkdir "$STATE_DIR/claimed/$1" 2>/dev/null || return 1
    printf 'host=%s\npid=%s\nworker=%s\ncontainer=%s\nstart=%s\n' … > …/owner
}
```

`worker.sh:437-442`. On a local filesystem `mkdir` is atomic: the kernel performs the
does-it-exist check and the create as one indivisible operation. N workers racing for one
genome produce exactly one exit status 0 and N-1 `EEXIST`.

There is deliberately **no `if [ -d … ]` test** before it. That would reintroduce the
test-and-set window the design exists to avoid.

The `done/`/`failed/` checks at `worker.sh:647-651` are an optimisation only — they skip
pointless `mkdir` attempts and are *allowed to be stale*. The `mkdir` is the only
authoritative step.

> **`STATE_DIR` must be local.** `mkdir` atomicity is not dependable over NFS. This is the
> single assumption the whole scheme rests on, and violating it produces duplicate runs in
> a shared job directory, not an error message.

### `unclaim()`

```bash
unclaim() { rm -rf "${STATE_DIR:?}/claimed/${1:?}"; }
```

`worker.sh:450`. The `${VAR:?}` expansions make an unset or empty variable a loud failure
rather than an expansion to nothing — a bug can never turn this into `rm -rf /claimed/`.

Called for **every** outcome, because it is the `done/` or `failed/` marker, not the claim,
that keeps a genome from being picked up again.

### `reap_stale_claims()`

`worker.sh:461-486`, runs once at startup, before the main loop.

For each `claimed/*/`:

- no `owner` file → **skip and log**. A worker died between the `mkdir` and the write. The
  script refuses to guess; clear it by hand once you are sure nothing is running.
- `host` != this host → **skip**. Pid 4823 here tells you nothing about pid 4823 elsewhere,
  and releasing it would return a genome another box is actively working to the pool.
- `kill -0 $pid` fails → **reap**: `docker rm -f "${cname}-db" "${cname}-rm"`, then unclaim.

Note the suffixes. The owner file records the *base* container name; `run_pipeline` always
launches `<base>-db` and `<base>-rm`, never the bare base. Both are removed; whichever
doesn't exist errors harmlessly under the redirect.

### `shuf` is not cosmetic

`worker.sh:661`:

```bash
done < <(find "$IN_DIR" -maxdepth 1 -name "$GLOB" -type f | shuf)
```

Without `shuf`, every worker walks the identical list in the identical order. Workers 2..N
lose the race on genome 1, then on genome 2, then on genome 3 — hundreds of wasted `mkdir`
calls before they find open work. Shuffling scatters them so collisions are rare.

It is a process substitution rather than `find … | while read` because a pipeline runs the
loop body in a **subshell**, where `processed` would be discarded at the end and the traps
would not behave.

---

## 3. Signals and shutdown

### `set -uo pipefail`, no `-e`

`worker.sh:127`. Unset variables are fatal; a pipeline fails if any stage failed.
`-e` is deliberately absent: **one genome failing must not kill the worker.**

### The trap

`on_term()` (`worker.sh:278-295`) does two things: set `SHUTDOWN=1` so the main loop stops
taking new work, and stop the running container.

The container is stopped **by name**, not by killing `$CHILD_PID`. The container is a child
of the Docker daemon, not of this script — killing the `docker run` client would leave
RepeatModeler running and chewing cores with nothing watching it.

There is a retry loop around `docker stop`, because `CURRENT_CONTAINER` is set just *before*
`docker run` launches and the container may not exist in the daemon yet if the signal lands
in that window. Up to 20 attempts at 0.25 s, with an early exit if the client process is
already gone.

`SIGHUP` is swallowed (`worker.sh:300`) so closing the terminal doesn't kill a worker
started without `nohup`.

### Why `docker_run` loops around `wait`

`worker.sh:363-368`:

```bash
while :; do
    wait "$CHILD_PID"; rc=$?
    if (( rc > 128 )) && kill -0 "$CHILD_PID" 2>/dev/null; then continue; fi
    break
done
```

When a trapped signal arrives while bash is blocked in `wait`, bash abandons the wait, runs
the trap, and has `wait` return 128+signum — **but the child is often still alive**, because
`docker stop` takes up to `STOP_GRACE` seconds. Returning while the container still runs
would let the caller move on and start a second container in the same job directory.

So: if the status is above 128 *and* the process still exists, wait again. `kill -0` sends
no signal, it only tests existence.

### rc 130 — "aborted, not failed"

The script's private convention (`worker.sh:494`). After **each** container call,
`run_pipeline` checks `(( SHUTDOWN ))` before treating a non-zero exit as failure
(`worker.sh:535`, `:550`), and also before committing to BuildDatabase after decompression
(`worker.sh:518`) and between the two stages (`worker.sh:540`).

Without those checks, every clean shutdown would wrongly mark its in-flight genome
**failed** — because stopping a container makes `docker run` exit non-zero, which is
indistinguishable from a genuine failure unless you check whether you were the one who
stopped it.

`process_one` then handles the three outcomes differently (`worker.sh:589-599`):

| rc | marker | scratch | log |
|---|---|---|---|
| 0 | `done/` | deleted unless `KEEP_WORK=1` | kept |
| 130 | **none** | deleted | kept |
| other | `failed/` | **kept** | kept |

rc 130 writing no marker is what makes an interrupted genome look untouched on the next
pass.

### Exit codes

| Code | Meaning |
|---|---|
| 0 | queue exhausted, finished normally |
| 2 | configuration problem |
| 127 | docker missing, or image not present locally |
| 143 | stopped by SIGTERM (128+15) |

---

## 4. The container invocation

`docker_run()` (`worker.sh:331-373`). Every flag is there for a reason:

| Flag | Why |
|---|---|
| `--rm` | 300 genomes × 2 stages would otherwise leave 600 dead containers |
| `--init` | a real pid 1 to reap zombies; RepeatModeler forks heavily |
| `--name` | so `on_term` can stop it, and so a stale claim's orphan can be found |
| `--label rmworker.sample=…` | lets `docker ps --filter` list only our containers |
| `--user $(id -u):$(id -g)` | without it every output file is owned by root |
| `--cpus $THREADS` | a **hard ceiling** — RepeatModeler ignores thread counts in places |
| `-v $jobdir:$jobdir` | mounted at the **identical host path** |
| `-w $jobdir` | start there |
| `-e HOME=$jobdir` | `--user` leaves the container with no valid home |

The identical-path mount (same convention `dfam-tetools.sh` uses) matters because
RepeatModeler writes **absolute paths into its round logs and errors**. Matching paths mean
a trace you can follow on the host without translating.

`safe_name()` (`worker.sh:381`) reduces a sample name to `[A-Za-z0-9_.-]`, capped at 100
chars to leave room for the `-db`/`-rm` suffixes. It uses `printf` rather than a here-string
because a here-string appends its own newline, which `tr -c` would transliterate into a
trailing `_` on every generated name.

### `MEM_LIMIT` and the OOM trap

If set, `--memory` and `--memory-swap` are both applied. **A cgroup OOM kill surfaces as an
ordinary non-zero exit**, so a genome killed that way lands in `failed/` with a truncated
log and no obvious cause. If one fails suspiciously fast, check `dmesg` before believing
the log. This is documented at `worker.sh:328-330` and in the config example.

### `-threads` vs `-pa`

`detect_thread_flag()` (`worker.sh:398-420`). `-pa` was deprecated in RepeatModeler 2.0.4 in
favour of `-threads`. Rather than assume, the worker runs `RepeatModeler -help` once and
greps for `-threads`.

The answer is a property of `$RM_IMAGE`, not of the worker, so it is cached at
`$STATE_DIR/.thread_flag_mode` — with N workers sharing one image, only the first to ask
launches a probe container. A lost race just means two probe instead of one. Harmless.

On an old build, `-pa` counted 4-core BLAST jobs rather than cores, so the requested thread
count is divided by four (floor 1).

The result is stored in an **array**, so it expands to two separate arguments rather than
one string containing a space.

### No `-engine`

`worker.sh:520-525`. Current RepeatModeler (checked against 2.0.9) dropped AB-Blast support
and removed `-engine` from `BuildDatabase`'s argument list — passing it is a hard "Unknown
option: engine" failure. RepeatModeler itself still parses it but hardcodes rmblast and
ignores the value. The flag is gone from both calls.

### Decompression happens on the host

`worker.sh:507`. `zcat "$gz" > "$jobdir/$sample.fa"`. This means `$IN_DIR` is **never
mounted into the container** — the container only ever sees one genome's scratch directory.

### Output is verified, not assumed

`worker.sh:555-557`. RepeatModeler can exit 0 having produced nothing usable, so
`<sample>-families.fa` is checked for non-emptiness before the run is called a success.

---

## 5. `rm-manager.sh`

Three subcommands. That is the entire interface; extra arguments are rejected rather than
ignored (`rm-manager.sh:293`) because `start 4` used to mean "four workers" and must not now
be silently read as `start`.

### `start`

`rm-manager.sh:175-214`. Pulls the image if absent (once, here, rather than letting four
workers each start the same download — the workers themselves *refuse* rather than pull).

Then for slots 1..`WORKERS`: skip any whose pid file names a live process, otherwise

```bash
setsid nohup "$WORKER" >>"$LOG_DIR/worker-$i.out" 2>&1 </dev/null &
echo $! > "$pidf"
sleep 2
```

- **idempotent** — run it again after one worker dies and only the dead slot is refilled
- **raising `WORKERS` is safe** — edit the config, run `start` again; running slots are left
  alone and a new worker just joins in
- **the 2 s stagger** stops all workers decompressing a genome at the same instant and
  thrashing the disk before any reaches RepeatModeler

### `stop`

`rm-manager.sh:223-244`. Walks **pid files**, not 1..`WORKERS`, so lowering `WORKERS` can
never strand a running worker with nothing to stop it.

The pid file is not removed immediately. A background subshell polls until the process
actually exits, then removes it:

```bash
( while kill -0 "$pid" 2>/dev/null; do sleep 1; done; rm -f "$pidf" ) &
disown
```

If the pid file vanished right away, a `start` run in that window would see a free slot and
launch a second worker while the first is still shutting down. `stop` still returns
immediately.

> **Never `kill -9` here.** A hard kill orphans claims and containers. They are recoverable
> — the next worker startup reaps them — but you lose the graceful container shutdown and
> `status` is misleading until then.

### `status`

`rm-manager.sh:257-287`. **Two independent views that can legitimately disagree:**

- which worker *processes* are alive, from pid files
- what the *queue* looks like, read straight from the state directories — the same source of
  truth the workers use, so it is accurate even for workers started by hand

Plus live containers filtered by the `rmworker.sample` label, and the contents of
`claimed/`.

> `queued` is the **total** input count, not the remaining count. Remaining is
> `queued - done - failed - running`.

A claimed genome with no matching container usually means the worker is decompressing — or
the claim is stale.

---

## 6. Operating it

```bash
ls state/done | wc -l                 # progress
ls -l state/claimed/                  # what is running, and since when
ls state/failed                       # what blew up
cat logs/<sample>.log                 # why it blew up
rm state/done/GCA_002110              # redo one genome
rm state/failed/*                     # retry all failures on the next pass
```

> **Do not delete anything from `claimed/` while workers are running.** That makes a live
> genome look available and a second worker will start a duplicate run in a job directory
> already in use. Stop the worker instead.

### Sizing

Total cores ≈ `WORKERS × THREADS`, capped per container by `--cpus`. On 24 cores / 124 GB,
4 × 6 is the documented starting point.

**Disk is the real constraint, not RAM.** A work directory with all RECON rounds retained
runs 20–80 GB per genome. Keep `KEEP_WORK=0` and put `$WORK_DIR` somewhere big, fast and
local.

`LTRSTRUCT=1` roughly doubles wall time and disk. The archive's observed run with it enabled
took ~45 hours ([`OCR docs/03`](../../OCR%20docs/03-file-explorer-screenshots.md)), against
the 8–26 hour range quoted for runs generally.

---

## 7. Observations

**The duplicated config reader.** ~80 identical lines in both files, called out as
deliberate at `rm-manager.sh:81-86`: "these are two standalone scripts with no shared
library." That is a defensible trade — each file can be copied somewhere and still work —
but it is a real maintenance hazard. A fix to the parser has to be applied twice. If you
change one, change both, and consider adding a test that diffs the two blocks.

**`usage()` parses its own source.** `worker.sh:136` does
`sed -n '3,34p' "${BASH_SOURCE[0]}"`. Editing the header comment silently changes the help
output, and inserting lines above line 3 breaks it.

**No per-worker `--cpus` affinity.** `--cpus` caps total CPU time but does not pin cores.
Four workers at 6 threads on 24 cores will contend rather than partition. In practice
RepeatModeler is I/O-bound enough in places that this hasn't mattered, but it is not the
same as `--cpuset-cpus`.

**`$LOG_DIR/<sample>.log` is truncated on retry.** `process_one` does `: > "$logf"`
(`worker.sh:585`). A retried genome loses the previous attempt's log. If you are debugging
an intermittent failure, copy it aside before retrying.
