# Stage 1 — Finding the repeats

**Folder:** `repeat-modeler-automation/`

## What it does

Takes a directory full of gzipped genome files. For each one, works out what repetitive DNA
families that genome contains, and writes them to a library file.

Think of it as building an index of the genome's repeats before you go looking for where
they are. This stage says *what* repeat families exist; a later tool (RepeatMasker) says
*where* each copy sits.

The actual work is done by **RepeatModeler**, a standard tool that ships inside a Docker
image called `dfam/tetools`. The two scripts here just drive it.

## Why it's more complicated than "run RepeatModeler"

One genome takes **8 to 26 hours**. With dozens of genomes and a machine that has enough
cores to do four at once, you immediately need answers to:

- How do four copies of the script agree on who takes which genome?
- What happens if the machine reboots halfway through?
- How do I stop it cleanly without losing the genome that was in flight?
- How do I see how far along it is?

These scripts answer all four, in about 950 lines of very heavily commented bash.

## The two scripts

**`worker.sh`** — does the work. Picks an unclaimed genome, runs RepeatModeler on it inside
the container, writes the result, repeats until nothing's left. Run as many copies as you
have cores for.

**`rm-manager.sh`** — convenience wrapper. Starts N workers, stops them, tells you how it's
going. That's all; the workers don't actually need it.

## How they avoid stepping on each other

There's no queue server and no coordinator. Instead, **claiming a genome is just creating a
directory**:

```
state/claimed/D_suzukii/     ← someone is working on this right now
state/done/D_suzukii         ← finished
state/failed/D_suzukii       ← blew up; the logs were kept
```

A genome that appears in none of those three is up for grabs. When two workers reach for the
same one, both try to create the same directory — and the operating system guarantees that
exactly one of them succeeds. The loser just moves on. No locks, no coordination, no way for
them to disagree.

A useful side effect: **the state is just files**, so you can drive it with ordinary
commands.

```bash
ls state/done | wc -l        # how many are finished
ls state/failed              # what broke
rm state/done/GCA_002110     # redo this one
rm state/failed/*            # retry everything that failed
```

> One rule: don't delete anything from `claimed/` while workers are running. That makes a
> live genome look available and a second worker will start a duplicate run on top of the
> first. Stop the worker instead.

## If something dies badly

A clean stop (`./rm-manager.sh stop`) releases the genome and writes no marker, so it just
looks untouched next time and gets picked up again.

A `kill -9`, an out-of-memory kill, or a power cut leaves the claim directory behind with
nobody alive to own it. The next worker to start finds those, kills any container they
orphaned, and releases them. Nothing gets permanently stuck.

## How to run it

```bash
# once
docker pull dfam/tetools:latest
cp rmodeler.conf.example rmodeler.conf
$EDITOR rmodeler.conf              # at minimum set IN_DIR, WORK_DIR, OUT_DIR, STATE_DIR

# try one worker in the foreground first
./worker.sh

# then, for real
./rm-manager.sh start
./rm-manager.sh status
./rm-manager.sh stop
```

## Configuration, and one thing that surprises people

Everything lives in `rmodeler.conf`. There are **no command-line options and no environment
variables** — `THREADS=2 ./worker.sh` does nothing at all, deliberately. Every setting must
be present or the script refuses to start.

That's stricter than it looks necessary, and the reason is worth knowing: several workers
share the same state and output directories, and they only behave if every one of them was
configured identically. One config file is the only way to guarantee that.

The settings you'll actually touch:

| Setting | What it's for |
|---|---|
| `IN_DIR` | where your `.fna.gz` genomes are |
| `WORK_DIR` | scratch space — needs **20–80 GB per genome in flight**, fast, and local |
| `OUT_DIR` | where the finished libraries land |
| `STATE_DIR` | progress tracking — **must be local disk, not NFS** |
| `WORKERS` | how many to run |
| `THREADS` | cores each one gets |

Total cores used is roughly `WORKERS × THREADS`. On a 24-core box, 4 workers × 6 threads is
a sensible start.

> **Disk is the real constraint, not memory.** A work directory with all rounds retained
> runs 20–80 GB per genome. Keep `KEEP_WORK=0`.

## What you get

For each genome: `<sample>-families.fa` in `OUT_DIR` — that's the TE library. Plus a full
log per genome in `LOG_DIR`, kept whether it succeeded or not.

## What happens next

The library goes to **RepeatMasker**, which scans the genome with it and produces a file
listing every repeat copy and its coordinates. That step has no code in this repository —
see [the end-to-end diagram](../diagrams/01-end-to-end.md) for exactly where the gap is.

---

**More detail:** [`docs/deep/01-repeat-modeler-automation.md`](../deep/01-repeat-modeler-automation.md)
· **Diagrams:** [`docs/diagrams/02-worker-concurrency.md`](../diagrams/02-worker-concurrency.md)
