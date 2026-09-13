# Commands

Everything you can actually run in this repository, what it does, and what it leaves behind.
One page. If you want the reasoning behind any of it, follow the links at the bottom.

**Quick orientation.** The project turns fly genomes into an answer about transposable
elements near Cyp genes. It does that in three groups of commands: one that chews on genomes
for hours (`repeat-modeler-automation/`), one that pairs TEs with genes
(`pipeline-scripts-output/`), and one that merges and compares (`analysis-pipeline/`).

---

## 1. The genome workers — `repeat-modeler-automation/`

Runs RepeatModeler and then RepeatMasker over a directory of gzipped genomes. This is the
slow part: **8–26 hours per genome**, sometimes longer. Everything here is configured by
`rmodeler.conf` — there are no command-line options and no environment variables.

### Setting up, once

```bash
cd repeat-modeler-automation
cp rmodeler.conf.example rmodeler.conf
$EDITOR rmodeler.conf              # set IN_DIR, WORK_DIR, OUT_DIR, STATE_DIR, LOG_DIR
docker pull dfam/tetools:latest    # pull before starting workers, not during
```

### Running it

| Command | What it does |
|---|---|
| `./worker.sh` | Runs **one** worker in the foreground. Use this first — you see errors immediately |
| `./rm-manager.sh start` | Launches `WORKERS` workers as background daemons |
| `./rm-manager.sh status` | Who is running, how far along the queue is, which containers are live |
| `./rm-manager.sh stop` | Stops every worker gracefully |
| `./rm-manager.sh` | Same as `status` — the safe default |
| `./worker.sh --help` | Prints the usage block from the top of the script |

`start` is safe to run again: slots already running are left alone and only dead ones are
refilled. Raising `WORKERS` and re-running `start` just adds workers.

### Stopping

```bash
./rm-manager.sh stop     # SIGTERM — the right way
kill <pid>               # same thing, for a worker you started by hand
```

**Never `kill -9` a worker.** A graceful stop finishes cleanly: it stops the container,
releases the genome without marking it failed, and that genome is simply picked up again next
time. A hard kill orphans claims and containers — recoverable on the next startup, but
`status` lies to you until then.

`stop` returns as soon as the signals are sent. Containers take up to `STOP_GRACE` seconds to
actually disappear; watch `docker ps` if you need to know when the machine is idle.

### Watching progress

```bash
./rm-manager.sh status                 # the summary
tail -f $LOG_DIR/<sample>.log          # RepeatModeler output for one genome
tail -f $LOG_DIR/<sample>.masker.log   # RepeatMasker output for one genome
docker ps --filter label=rmworker.sample
```

### Redoing work

All progress is recorded as **empty files whose names are genome names**, so you manage it
with `ls` and `rm`:

```bash
ls $STATE_DIR/done    | wc -l     # genomes modelled
ls $STATE_DIR/masked  | wc -l     # genomes masked
ls $STATE_DIR/failed              # what went wrong
ls -l $STATE_DIR/claimed          # what is running right now, and since when

rm $STATE_DIR/masked/<sample>     # redo only the RepeatMasker run (keeps the library)
rm $STATE_DIR/done/<sample> $STATE_DIR/masked/<sample>    # redo the genome from scratch
rm $STATE_DIR/failed/*            # retry everything that failed, on the next pass
```

> **Do not delete anything from `claimed/` while workers are running.** That makes a live
> genome look available and a second worker will start a duplicate run in a directory already
> in use. Stop the workers first.

### What you get

| File | What it is |
|---|---|
| `$OUT_DIR/<sample>-families.fa` | The repeat library for that species |
| `$OUT_DIR/<sample>.rm.out` | **The TE annotation table — this is what the rest of the pipeline needs** |
| `$OUT_DIR/<sample>.rm.tbl` | RepeatMasker's summary |
| `$OUT_DIR/<sample>.rm.masked.fa` | Soft-masked genome, only when `KEEP_MASKED_FASTA=1` |

### The settings you will actually change

| Setting | Meaning |
|---|---|
| `IN_DIR` | Where the `*.fna.gz` genomes are |
| `OUT_DIR` / `STATE_DIR` / `LOG_DIR` / `WORK_DIR` | Where results, progress, logs and scratch go. `STATE_DIR` and `WORK_DIR` **must be local disk, not NFS** |
| `WORKERS` / `THREADS` | Total cores used ≈ `WORKERS × THREADS`. On a 24-core box, 4 × 6 is sane |
| `RUN_MASKER` | `1` = run RepeatMasker after RepeatModeler. Safe to turn on later — already-modelled genomes are re-masked without being re-modelled |
| `LTRSTRUCT` | `1` adds `-LTRStruct`. Roughly doubles wall time and disk |
| `RETRY_FAILED` | `1` = re-attempt genomes marked failed |
| `KEEP_WORK` | `1` = keep the scratch directories on success (they run 20–80 GB per genome) |

Both scripts refuse to start (exit 2) if `rmodeler.conf` is missing, if a setting is missing,
if a name is misspelled, or if a value is nonsense. That is deliberate — workers share
directories and must agree about them.

---

## 2. Pairing TEs with Cyp genes — `pipeline-scripts-output/`

Three short Python scripts, run in order. **They take no arguments.** File paths are
hardcoded at the top of each file and must be edited before each run — open the script, change
the paths, run it.

```bash
cd pipeline-scripts-output
python3 repeatOpp.py        # annotation GFF + Cyp gene list  -> filtered.gff
python3 Locate_TE.py        # filtered.gff + RepeatMasker .out -> GenesAffectedByTEs.txt
python3 CleanAnnasse.py     # tidies column 2                  -> DAnasse_TE_Cyp.txt
```

| Script | Edit these lines before running |
|---|---|
| `repeatOpp.py` | `GFF` (the species annotation), `rgFile` (the Cyp gene list) |
| `Locate_TE.py` | `cypGene` (the `filtered.gff` just produced), `TEs` (the RepeatMasker `.out`) |
| `CleanAnnasse.py` | `toClean` (the file just produced), `aliasToFind` (the Cyp gene list) |

Rename the final output to `D_<species>GenesAffectedByTE.txt` — that is the name the next
stage expects, and the 29 completed species in `AnalysisForAll/output/` follow it.

A TE counts as affecting a gene if it falls inside the gene's span **extended by 3,000 bp at
each end**. That number is hardcoded in `Locate_TE.py`.

---

## 3. Merging and comparing — `analysis-pipeline/`

> **Rename the files first.** They are committed as `build_tfbs_te_gff 1.py`,
> `compare_te_cyp_exposure 1 1.py` and so on. Two of the comparison scripts do
> `import compare_te_cyp_exposure`, which cannot resolve against a name with spaces in it —
> **as committed, they do not run.** Drop the ` 1` / ` 1 1` suffixes and everything works.

### Build one combined annotation per species

```bash
python3 build_tfbs_te_gff.py \
    --te-file  D_suzukiiGenesAffectedByTE.txt \
    --gff      dsuzukii_annotation.gff3 \
    --fasta    dsuzukii_genome.fa \
    --output   combined_cyp_annotation_suzukii.gff3
```

| Option | Use it when |
|---|---|
| `--skip-tfbs` | You have no MEME Suite, or don't need motif scanning. **Note:** the CncC comparison below will then have nothing to work with for this species |
| `--fimo-path /path/to/fimo` | `fimo` is installed but not on `PATH` |
| `--fimo-via-docker` | You would rather not install MEME Suite at all |
| `--sequence-source ncbi` | You don't have the genome FASTA locally — sequence windows are fetched from NCBI by accession |
| `--bgzip-index` | You want to load the result into JBrowse 2 |
| `--config species_config.ini --species suzukii` | You'd rather keep per-species paths in a file than on the command line |

Needs `fimo` (MEME Suite) unless you pass `--skip-tfbs`:
`conda install -c bioconda meme`, then check with `fimo --version`.

### Run the comparisons

All three read the same config file — one `[section]` per species, each with `gff =` and
`exposure = high|low`.

```bash
# every Cyp gene
python3 compare_te_cyp_exposure.py --config te_cyp_species_config.ini \
    --output-csv te_cyp_summary.csv --output-report te_cyp_report.md --plot

# only Cyp genes near a CncC:Maf-S site  (needs motif scanning to have been run)
python3 compare_te_cyp_cncc.py --config te_cyp_species_config.ini

# only a curated resistance gene list
python3 compare_te_cyp_xenobiotic.py --config te_cyp_species_config.ini \
    --gene-list xenobiotic_resistance_cyp_genes.txt
```

Shared options: `--output-csv`, `--per-gene-csv`, `--output-report`, `--plot` / `--no-plot`,
`--plot-path`, `--alpha` (default 0.05).

```bash
python3 compare_te_cyp_exposure.py --self-test
```

Runs the statistics against a second, independently written implementation and exits. Worth
doing once on a new machine — it checks the Fisher's exact and Mann-Whitney U code, which is
written from scratch here rather than taken from scipy.

**The example config files these scripts reference do not exist in this repository.** You have
to write your own; the formats are in
[`pipeline/detailed/03-data-contracts.md`](pipeline/detailed/03-data-contracts.md).

---

## The shortest possible version

```bash
# 1. genomes -> repeat libraries and TE annotation tables   (hours per genome)
cd repeat-modeler-automation && ./rm-manager.sh start
./rm-manager.sh status                       # check back later

# 2. TE table + gene annotation -> "which Cyp genes have TEs"   (seconds, manual)
cd ../pipeline-scripts-output
python3 repeatOpp.py && python3 Locate_TE.py && python3 CleanAnnasse.py

# 3. merge, then compare the species                        (minutes)
cd ../analysis-pipeline
python3 build_tfbs_te_gff.py --te-file … --gff … --fasta … --output combined.gff3
python3 compare_te_cyp_exposure.py --config te_cyp_species_config.ini
```

Step 2 needs a gene annotation whose names are already *D. melanogaster* ortholog symbols.
**No code in this repository produces one** — that step was never committed. Existing species
have one; a new species would not.

---

## Where to read more

- **What the pipeline is for, with pictures** — [`pipeline/simple/`](pipeline/simple/)
- **Every stage in detail** — [`pipeline/detailed/02-stage-reference.md`](pipeline/detailed/02-stage-reference.md)
- **File formats** — [`pipeline/detailed/03-data-contracts.md`](pipeline/detailed/03-data-contracts.md)
- **Known defects — read before quoting any number** — [`pipeline/detailed/04-gaps-and-provenance.md`](pipeline/detailed/04-gaps-and-provenance.md)
- **The scripts line by line** — [`deep/`](deep/)
