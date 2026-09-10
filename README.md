# lab-computer-worker-scripts

Shell scripts for running [RepeatModeler](https://www.repeatmasker.org/RepeatModeler/) (via the [Dfam TE Tools](https://github.com/Dfam-consortium/TETools) Docker image) over a directory of gzipped genome FASTAs, spread across as many parallel workers as the lab machine can handle.

There is no coordinator process or queue server. Workers claim genomes off the filesystem and coordinate purely through directory names — see [Concurrency model](#concurrency-model) below.

## Files

| File | Purpose |
|---|---|
| `worker.sh` | One worker. Walks `$IN_DIR`, claims one genome at a time, runs `BuildDatabase` + `RepeatModeler` on it inside the Dfam TE Tools container. |
| `workers.sh` | Supervisor. Launches N `worker.sh` daemons, stops them, and reports status. |

## Requirements

- Docker (or `podman`, or `sudo docker` — set via `$DOCKER`)
- The Dfam TE Tools image, pulled once ahead of time:
  ```bash
  docker pull dfam/tetools:latest
  ```
- `$STATE_DIR` on a **local filesystem** — the locking scheme relies on atomic `mkdir`, which is not dependable over NFS.

## Example input

`$IN_DIR` is expected to look like a flat directory of per-genome archives, e.g. a Diptera genome set:

```
Stomoxys_calcitrans.GCF_963082655.1.rm.fna.gz   307M
Tachina_grossa.GCA_949987645.1.rm.fna.gz        286M
Musca_domestica.nanopore.rm.fna.gz              205M
Drosophila_melanogaster.GCF_000001215.4.rm.fna.gz  44M
...
```

A real run here was ~19 GB across the archive, individual genomes ranging from ~35 MB to ~307 MB compressed, mixing RefSeq/GenBank assembly accessions with raw `nanopore` assemblies that have no accession.

`worker.sh` derives the sample name by stripping `.gz`, then one of `.fna`/`.fa`/`.fasta`, then a trailing `.rm` if present. So `Stomoxys_calcitrans.GCF_963082655.1.rm.fna.gz` becomes the sample `Stomoxys_calcitrans.GCF_963082655.1`, and every log file, state marker, and output (`...-families.fa`) is named from that — no `.rm` carried through.

## Quickstart

Single worker, foreground, for a first test run:

```bash
IN_DIR=/data/genomes THREADS=6 ./worker.sh
```

Several workers via the supervisor:

```bash
export IN_DIR=/data/genomes WORK_DIR=/scratch/rmodeler/work THREADS=6
./workers.sh start 4      # launch 4 workers
./workers.sh status       # pid check + queue counts (also the default)
./workers.sh stop         # SIGTERM all workers, gracefully
```

On a 24-core / 124 GB box, `start 4` with `THREADS=6` is a sane starting point. Total cores used is roughly `n * THREADS`; each container is also hard-capped with `--cpus`.

## Configuration

Every setting is `${VAR:-default}`, so anything can be overridden via the environment without editing the scripts. `workers.sh` exports its config so every worker it launches inherits the same values.

| Variable | Default | Meaning |
|---|---|---|
| `IN_DIR` | `/data/genomes` | Where the `*.fna.gz` genomes live |
| `WORK_DIR` | `/scratch/rmodeler/work` | Per-genome scratch space; needs to be big and fast |
| `OUT_DIR` | `/data/rmodeler/out` | Final `-families.fa` / `.stk` output |
| `STATE_DIR` | `/data/rmodeler/state` | `claimed/`, `done/`, `failed/` markers — must be local |
| `LOG_DIR` | `/data/rmodeler/logs` | One log per genome, plus one per worker |
| `RM_IMAGE` | `dfam/tetools:latest` | Docker image holding RepeatModeler |
| `DOCKER` | `docker` | Or `"sudo docker"` / `podman` |
| `THREADS` | `6` | Cores per genome; also the container `--cpus` ceiling |
| `MEM_LIMIT` | (unlimited) | e.g. `28g`; see the OOM note in `worker.sh` before setting |
| `ENGINE` | `ncbi` | `ncbi` (rmblast) or `abblast` |
| `GLOB` | `*.fna.gz` | Which files in `$IN_DIR` count as input |
| `LTRSTRUCT` | `0` | `1` adds `-LTRStruct`; roughly doubles wall time and disk |
| `KEEP_WORK` | `0` | `1` keeps the `RM_*` round directories after success |
| `RETRY_FAILED` | `0` | `1` re-attempts genomes previously marked failed |
| `STOP_GRACE` | `10` | Seconds Docker waits before SIGKILLing on shutdown |

`workers.sh`-only:

| Variable | Default | Meaning |
|---|---|---|
| `RUN_DIR` | `$STATE_DIR/run` | Where worker pid files are kept |

## Concurrency model

All run state lives in the **names of directories** under `$STATE_DIR`:

- `claimed/<sample>/owner` — in progress; owner file records host + pid
- `done/<sample>` — finished OK, output is in `$OUT_DIR`
- `failed/<sample>` — failed; scratch dir and log kept for inspection

A genome named in none of the three is available — that state is never recorded, it's recomputed from `$IN_DIR` on every pass.

Mutual exclusion is a single `mkdir`, which is atomic on a local filesystem: when N workers race for the same genome, exactly one gets exit status 0. There is deliberately no existence check before it.

## Crash recovery

- A clean stop (`SIGTERM`) releases the claim with no marker — the genome looks untouched next time.
- A `kill -9`, OOM kill, or reboot leaves an orphaned claim. Each worker's `reap_stale_claims()` runs at startup, finds claims recorded against its own host whose pid no longer exists, kills any orphaned container, and releases the claim.

Never `kill -9` a worker or `workers.sh stop` — always plain `SIGTERM` (what both scripts use by default). Hard kills are recoverable but leave things orphaned until the next startup reaps them.

## Operating it by hand

State is just files:

```bash
ls state/done | wc -l          # progress
ls -l state/claimed/           # what is running, and since when
ls state/failed                # what blew up
rm state/done/GCA_002110       # redo one genome
rm state/failed/*              # retry all failures on the next pass
```

Do **not** delete anything from `claimed/` while workers are running — that makes a live genome look available and a second worker will start a duplicate run in a job directory already in use. Stop the worker instead.

## Sizing

RepeatModeler spawns more threads than it's asked for, so `THREADS` is enforced with a `--cpus` ceiling on the container rather than trusted.

Disk, not RAM, is the real constraint: a work directory with all RECON rounds retained runs 20–80 GB per genome. Keep `KEEP_WORK=0` and put `$WORK_DIR` somewhere big and fast.

## Exit status (`worker.sh`)

| Code | Meaning |
|---|---|
| `0` | Queue exhausted, worker finished normally |
| `127` | Docker missing, or the image isn't present locally |
| `143` | Stopped by `SIGTERM` (128 + 15) |

For full implementation notes (why the mkdir has no existence check, why process substitution instead of a piped `while read`, why containers are stopped by name, etc.), see the comments at the top of `worker.sh` and `workers.sh` — they're written to be read.
