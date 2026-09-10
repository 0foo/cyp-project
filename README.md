# repeat-modeler-automation

Runs RepeatModeler (via the Dfam TE Tools Docker image) over a directory of gzipped genome FASTAs, spread across parallel workers.

## Commands

```bash
# one-time: pull the image
docker pull dfam/tetools:latest

# single worker, foreground -- good for a first test run
IN_DIR=/data/genomes THREADS=6 ./worker.sh

# multiple workers via the supervisor
export IN_DIR=/data/genomes WORK_DIR=/scratch/rmodeler/work THREADS=6
./workers.sh start 4      # launch 4 workers
./workers.sh status       # check progress (also runs if you pass nothing)
./workers.sh stop         # stop all workers gracefully
```

### Or skip the env vars: use a config file

Copy `rmodeler.conf.example` to `rmodeler.conf` (same directory as the scripts), uncomment and edit whatever you want set permanently, then just run:

```bash
./worker.sh
./workers.sh start 4
```

no env vars needed. A setting you *do* pass inline (e.g. `THREADS=2 ./worker.sh`) still overrides the config file; the config file overrides the built-in defaults. Use a config file at a different path with `CONFIG_FILE=/path/to/file`.

## Inputs needed

- Docker installed (or `podman` / `sudo docker` -- set via `$DOCKER`), with `dfam/tetools:latest` already pulled
- `$IN_DIR`: a directory of gzipped genome FASTAs (`*.fna.gz` by default, change with `$GLOB`)
- `$STATE_DIR` and `$WORK_DIR` on a local filesystem, not NFS

Variables you'll typically set (all optional -- defaults shown), via env var or in `rmodeler.conf`:

| Variable | Default | Meaning |
|---|---|---|
| `IN_DIR` | `/data/genomes` | Where the genome `.fna.gz` files live |
| `WORK_DIR` | `/scratch/rmodeler/work` | Per-genome scratch space; needs to be big and fast |
| `OUT_DIR` | `/data/rmodeler/out` | Where the final output lands |
| `STATE_DIR` | `/data/rmodeler/state` | Progress tracking; must be local disk |
| `LOG_DIR` | `/data/rmodeler/logs` | Logs |
| `THREADS` | `6` | Cores per genome |

`rmodeler.conf.example` lists the rest (`RM_IMAGE`, `DOCKER`, `MEM_LIMIT`, `ENGINE`, `GLOB`, `LTRSTRUCT`, `KEEP_WORK`, `RETRY_FAILED`, `STOP_GRACE`, `RUN_DIR`).

## Artifacts generated

- `$OUT_DIR/<sample>-families.fa` (and `.stk` if produced) -- the RepeatModeler result, one per genome
- `$STATE_DIR/done/<sample>` -- marker: genome finished successfully
- `$STATE_DIR/failed/<sample>` -- marker: genome failed (scratch dir + log kept for inspection)
- `$STATE_DIR/claimed/<sample>/` -- marker: genome currently being worked on
- `$LOG_DIR/<sample>.log` -- full BuildDatabase/RepeatModeler output for that genome
- `$LOG_DIR/worker-N.out` -- one per worker, only when launched via `workers.sh`
- `$WORK_DIR/<sample>/` -- scratch working directory; deleted automatically on success (unless `KEEP_WORK=1`), kept on failure for debugging

For everything else (full variable list, concurrency model, crash recovery), see the comments at the top of `worker.sh` and `workers.sh`.
