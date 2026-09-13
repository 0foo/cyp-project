# Stage reference

One section per stage. Each gives the inputs, the exact command, the outputs, the runtime,
and what goes wrong. File formats are specified separately in
[`03-data-contracts.md`](03-data-contracts.md).

Legend: **✅ committed** — code is in this repository. **❌ missing** — the stage was run, but
its code was never committed and survives only in the archive photographs.

---

## Stage 0 — Preparing the inputs ❌

Before stage 1 can start, each species needs two things, and one of them requires work that
is not in this repository.

### 0a. Genome FASTA

Per-species assemblies, named by their NCBI accession — e.g.
`GCF_016746245.2_Prin_Dsan_1.1_genomic.fna` (*D. santomea*),
`Drosophila_ananassae.GCF_017639315.1` (*D. ananassae*).

Era 1 read these from `D:/CYP_Gene_Project/Dhakad_et_al_2025_Data_Analysis/12_species_genomes`,
described in the log as the *old* location superseded by `Spring26/` *(OCR doc 04)* — but the
JBrowse instructions and the handoff sketch both still point at the `Dhakad` tree *(OCR docs
02, 06)*, so the genome FASTAs appear never to have actually moved.

Era 2's `worker.sh` expects them **gzipped** in `IN_DIR`, matching `GLOB` (default `*.fna.gz`).

### 0b. Gene annotation GFF3 with *D. melanogaster* ortholog names ❌

This is the important one. Each species' annotation must have its gene names replaced with
the corresponding *D. melanogaster* ortholog symbols, producing files named
`*_withDmelNames.gff`. Without it, the same gene carries a different symbol in every species
and nothing can be compared across species — and the Cyp target list would match nothing.

**Two different scripts did this, by two different people, and neither is committed:**

| Dataset | Script | Author | Location | Date |
|---|---|---|---|---|
| Gff_Dataset#1 | `NEW_Step_5_Replace_gff_Names_with_Dmelanogaster_1_9.py` | Ayush (editing the log author's older scripts) | `CYP_Gene_Project/Spring26/Gff_Dataset#1` | 5/7/2026 |
| Gff_Dataset#2 | `ReVamp_Final.py` | Duy | `CYP_Gene_Project/Spring26/Gff_Dataset#2` | 7/9/2026 |

*(OCR doc 04; folder dates from OCR doc 03b.)*

Nothing in the log states which supersedes which. The lab notebook's step-by-step procedure
points at **Dataset #2**, so that is the one that was in active use as of August 2026
*(OCR doc 02)*. `Gff_Dataset#2` is only 278 KB and contains a single subfolder,
`Duy_New_Scripts` — it is a script folder, not a data folder, despite the name *(OCR doc 03b)*.

**If you need to rebuild this step**, you need the ortholog mapping as well as the code. The
committed example output shows what it produced: `dmel_orthologs=` and `hog=N1.HOG…`
attributes on mRNA records, so the mapping came from a hierarchical orthogroup assignment.

### 0c. The Cyp target list ✅

`pipeline-scripts-output/AnalysisForAll/Reg_Gene_Full.txt` — 96 lines, one gene symbol each.

Two of its properties are load-bearing and non-obvious: it contains five entries in
`Dvir\GJ21722` form which **both** stage 3 scripts silently skip (they skip every line
starting with `D`), and matching is *substring* matching, not exact — see
[`03-data-contracts.md`](03-data-contracts.md).

`pipeline-scripts-output/DA_Files/` also holds `Cyp_stable_genes_Good_et_al_2014.txt` and
`Cyp_unstable_genes_Good_et_al_2014.txt`, a literature-derived split of Cyp genes into
evolutionarily stable and unstable sets. Nothing in the committed code reads them.

---

## Stage 1 — Build the per-species repeat library ✅

**In:** one genome FASTA. **Out:** a classified TE consensus library. **Runtime:** 8-26 h
typical, 45 h observed with `-LTRStruct`.

### Era 1 — as originally run ❌ (documented for reference)

`spinContainer.sh`, transcribed in full from a terminal photograph *(OCR doc 01)*:

```bash
docker run -it --rm \
    -v $(pwd):/Spring26RepeatModeler \
    -w /Spring26RepeatModeler \
    dfam/tetools:latest bash
```

This starts an **interactive** shell — it does not run RepeatModeler. The operator then typed,
inside the container *(OCR doc 04)*:

```
BuildDatabase -name D_speciesname Species_genome_file.fa
RepeatModeler -database D_speciesname -threads 10 -LTRStruct
```

Because `-v $(pwd):...` mounts only the current species folder, running a second species meant
opening a second terminal and repeating the entire sequence. `--rm` means nothing survives
outside the mount.

### Era 2 — the committed automation ✅

`repeat-modeler-automation/`. Configuration is **entirely** in `rmodeler.conf`; there are no
command-line options and no environment variables, and inherited environment values are
discarded before the file is read. Both scripts exit 2 if the file is missing, if a setting is
missing, if a name is misspelled, or if a value is nonsense.

```bash
cp rmodeler.conf.example rmodeler.conf && $EDITOR rmodeler.conf
docker pull dfam/tetools:latest

./worker.sh                  # one worker, foreground — good for a first run
./rm-manager.sh start        # WORKERS workers as daemons
./rm-manager.sh status       # pid check + queue counts
./rm-manager.sh stop         # SIGTERM all of them
```

Per genome the worker performs, inside the container:

```
BuildDatabase -name <sample> <sample>.fa
RepeatModeler -database <sample> <thread flag> [-LTRStruct]
```

Differences from era 1 that matter:

- **No `-engine` flag**, on either call. Current RepeatModeler (checked against 2.0.9) removed
  the option from `BuildDatabase`, so passing it is a hard `Unknown option: engine` failure.
- **The thread flag is detected at runtime** (`-threads` vs the older `-pa`) rather than
  assumed.
- **Decompression happens on the host**, so `IN_DIR` is never mounted into the container — a
  container only ever sees one genome's scratch directory.
- **The result is verified, not assumed.** RepeatModeler can exit 0 having produced nothing
  usable, so the worker checks that `<sample>-families.fa` is non-empty before declaring
  success.

### Outputs

| Path | Meaning |
|---|---|
| `$OUT_DIR/<sample>-families.fa` (and `.stk`) | The library. The only artifact that leaves the stage |
| `$STATE_DIR/done/<sample>` | Finished successfully |
| `$STATE_DIR/failed/<sample>` | Failed; scratch dir and log kept for inspection |
| `$STATE_DIR/claimed/<sample>/owner` | In progress; records host + pid |
| `$LOG_DIR/<sample>.log` | Full BuildDatabase/RepeatModeler output |
| `$WORK_DIR/<sample>/` | Scratch; deleted on success unless `KEEP_WORK=1`, kept on failure |

Era 1's equivalent output was `consensi.fa.classified`, alongside `families.stk`, `rmod.log`,
`round-1`…`round-5`, `genome.2bit` and assorted `tmp*` files *(OCR doc 03c)*. Modern
RepeatModeler names the same artifact `<sample>-families.fa`. **Both names refer to the same
thing** — the classified consensus library — and downstream documentation uses them
interchangeably.

### Sizing and failure modes

Total cores ≈ `WORKERS × THREADS`; on a 24-core / 124 GB box, `WORKERS=4` / `THREADS=6` is the
documented starting point. `WORK_DIR` runs **20-80 GB per genome in flight**.

- `STATE_DIR`/`WORK_DIR` on NFS → claim races become possible. Use local disk.
- `LTRSTRUCT=1` roughly doubles wall time and disk.
- A cgroup OOM kill from `MEM_LIMIT` looks like an ordinary failure in the log — check `dmesg`
  before believing one.
- Never `kill -9` a worker: it orphans claims and containers. They are recoverable on the next
  startup, but `status` is misleading until then.

---

## Stage 2 — Annotate TE locations genome-wide ❌

**In:** the stage 1 library + the genome FASTA. **Out:** a RepeatMasker `.out` table.

**No code for this stage is in the repository.** It ran as `runMasker.sh`, on a collaborator's
machine, and the script itself was never photographed. But the stage is *not* undocumented —
two independent sources describe it, one giving the command and the other the procedure.

### The command — lab notebook *(OCR doc 02, section 1)*

```
Repeatmasker:
• After repeat modeler RM file w/date  Data D.
• consensi.fa.classified
• RepeatMasker
• Copy & paste replace Drosophila_…  w/ file
• RepeatMasker -lib RM_#$date/consensi.fa.classified -pa 8  Drosophila_ .fna file
```

Reconstructed, that is:

```
RepeatMasker -lib <RM_dated_dir>/consensi.fa.classified -pa 8 <species>.fna
```

`RM_#$date` stands for the dated RepeatModeler output directory — the real thing looks like
`RM_235549.ThuJul92144222026` *(OCR doc 03c)* — and `-pa 8` is RepeatMasker's parallel
search-process count. *"Copy & paste replace Drosophila_… w/ file"* is an instruction to
substitute the actual species filename each time, which is the same hand-editing loop that
stage 3 uses.

**Treat the flag order as approximate.** It is a handwritten paraphrase and has never been
checked against the real script.

### The procedure — Kaur write-up *(OCR doc 05, pages 2-3)*

> 1.) Copy the RepeatModeler output (consensi.fa.classified) into the RepeatMasker folder (it
>     should already be there from when we ran RepeatModeler).
> 2.) Run RepeatMasker using the custom repeat library and the genome FASTA file.
> 3.) Save the output files for downstream analysis.

The parenthetical in step 1 is the operationally significant detail: **RepeatMasker ran in the
same per-species working directory as RepeatModeler**, so the library was already in place and
nothing was copied anywhere. This is consistent with era 1's container mount, which exposed
exactly one species folder *(OCR doc 01)*, and it is why the stage 1 library and the stage 2
`.out` file are siblings rather than living in separate trees.

The write-up also states the stage's contract plainly: RepeatMasker *"uses the repeat library
created by RepeatModeler to locate transposable elements throughout a genome"*, with
`consensi.fa.classified` *"used as the custom library for this step"* — confirming the library
is a **custom** `-lib`, not Dfam's stock database. That matters: the TEs found here are the
ones stage 1 discovered in that species, not a reference set.

### Which container did this run in?

**The same image, not a separate one.** `dfam/tetools:latest` is the Dfam TE Tools image and
bundles RepeatMasker alongside RepeatModeler, RECON, RepeatScout, TRF and rmblast. No second
image is named anywhere in the archive, and none is needed. This is what makes the write-up's
*"it should already be there from when we ran RepeatModeler"* true: same image, same mounted
species folder.

**A separate container instance, though, almost certainly.** `spinContainer.sh` runs with
`-it --rm … bash`, so the container is destroyed the moment the shell exits. With RepeatModeler
taking 8-26 hours and masking described as a subsequent step, any exit-and-return is a fresh
container off the same image. And per the log, RepeatMasker processing was handed to a
collaborator over OneDrive *(OCR doc 04)* — a different machine, so necessarily a different
container.

**Note that the committed automation has no masking container at all.** `worker.sh` makes
exactly two `docker_run` calls, `BuildDatabase` and `RepeatModeler`; the string "RepeatMasker"
does not appear anywhere in `repeat-modeler-automation/`.

> **Open question.** Whether `runMasker.sh` is its own `docker run` wrapper or a script executed
> *inside* a shell already started by `spinContainer.sh` is **not established**. The naming
> implies the latter division of labour — one script spins the container, the other runs the
> tool in it — and the mount is `-v $(pwd):/Spring26RepeatModeler`, only the current species
> folder, so a standalone `runMasker.sh` would have needed to set up its own mount. But the
> script was never photographed, and both files sit in the mounted directory where host and
> container see them alike, so nothing in the archive settles it. It matters if you rebuild
> this stage: the answer decides whether you write a container wrapper or just a command.

### What is actually missing

Not the command and not the procedure — those are recorded above. What is missing is
`runMasker.sh` itself, and with it: the exact flag order, whether any additional flags were
used (`-species`, `-xsmall`, `-gff`, output directory handling), whether it looped over species
or was invoked once per species by hand, and the container question above.

**Outputs** are named `<species>.<accession>.rm.fna.out`, e.g.
`Drosophila_ananassae.GCF_017639315.1.rm.fna.out` — 39 MB and 297,073 lines for *D. ananassae*.
Committed examples are in `pipeline-scripts-output/DA_Files/` and
`pipeline-scripts-output/AnalysisForAll/FilesFromMasker/`.

**This is the stage to rebuild first** if the pipeline is to run end to end again. It is a
single standard command; the difficulty is not the command but that the whole handoff around
it — zip, upload, collect — was human.

---

## Stage 3 — Pair Cyp genes with nearby TEs ✅

**In:** annotation GFF3 + Cyp symbol list + RepeatMasker `.out`.
**Out:** one table per species. **Runtime:** seconds.

Three scripts in `pipeline-scripts-output/`, run in order. All three currently carry
**hardcoded absolute Windows paths at module scope** and take no arguments — the paths are
edited before each run. This is the residue of the era 1 procedure and is the single biggest
obstacle to automating the stage.

### 3a. `repeatOpp.py` — restrict the annotation to Cyp genes

Reads the annotation GFF3 and `Reg_Gene_Full.txt`; keeps a row if `fields[2] == "gene"` and a
target symbol appears anywhere in the attributes column. Writes `filtered.gff`.

> **Defect — row duplication.** One row is emitted per *matching symbol*, not per gene. A gene
> annotated `Name=Cyp313a5,Cyp313a2,Cyp313a3,Cyp313a1` is written four times. Measured on the
> committed *D. ananassae* example: **166 rows, 91 unique, 57 distinct gene names**, from 117
> gene records in. The duplication multiplies through stage 3b.

### 3b. `Locate_TE.py` — the actual TE-to-gene association

For each gene row, scans every line of the `.out` file and emits a row where the repeat falls
within the gene's span extended by 3,000 bp on each side.

The test, exactly as implemented:

```python
start = int(cypFields[3]) - 3000
stop  = int(cypFields[4]) + 3000
if cypFields[0] == eleFields[4] and (int(eleFields[6]) <= stop and int(eleFields[5]) >= start):
```

Two semantics worth being explicit about, because everything downstream inherits them:

> **The window is containment, not overlap.** The repeat must lie *entirely* inside
> `[gene_start - 3000, gene_end + 3000]`. A long element that straddles the window boundary —
> one that begins 4 kb upstream and runs into the gene — is **not** counted. For TE work this
> is the wrong default; overlap is the usual criterion.

> **`start` can go negative** for genes within 3 kb of the start of a sequence. Harmless in
> practice (no coordinate is ever below 1, so the comparison still succeeds) but it means the
> window is silently asymmetric for those genes.

Output `GenesAffectedByTEs.txt`: `<seqid> TAB <full gene attribute blob> TAB <raw .out line>`.
900 rows for *D. ananassae*.

Complexity is `O(genes × repeats)` with the repeat file held in memory — 91 genes × 297,073
repeats here. Fine at this scale; it will not survive a whole-genome gene set.

### 3c. `CleanAnnasse.py` — make column 2 readable

Replaces the 200-character attribute blob with the bare matched gene symbol, using the same
`Reg_Gene_Full.txt`. Output `DAnasse_TE_Cyp.txt` — 900 rows, 50 distinct genes.

The filename is hardcoded and species-specific; era 1 renamed the result by hand to
`D_<species>GenesAffectedByTE.txt` *(OCR doc 02, Step 3)*. The 29 files in
`AnalysisForAll/output/` are those renamings — including three hand-typing errors
(`D_secheliaGenesAffectedByT.txt`, `D_athabascaGenesAfffectedByTE.txt`,
`D_arawakanaGenesAffectedByTe.txt`).

### The era 1 procedure, for the record

From the lab notebook *(OCR doc 02)*, confirmed independently by the write-up *(OCR doc 05)*:

1. Open the script in VS Code, drag the species file in, paste the GFF path onto the
   highlighted line, convert Windows `\` to `/`, save, click run.
2. Copy the relative path of the RepeatMasker file, paste onto row 5, save, run again.
3. Right-click the output, name it `D_<species>GenesAffectedByTE.txt`, paste its relative path
   onto row 4, save, run again.

Three edit-save-run cycles per species, twenty-nine species.

---

## Stage 4 — Build the combined annotation ✅

**In:** stage 3 table + annotation GFF3 + genome sequence. **Out:** one combined GFF3 per
species. **Runtime:** minutes.

`analysis-pipeline/build_tfbs_te_gff 1.py`. Six internal phases:

1. Parse the stage 3 TE table into records, **de-duplicating** (compensating for the stage 3a
   defect above).
2. Parse the annotation GFF3, pulling `gene`, `mRNA` and `exon` features for the named genes.
3. Build scan windows: a promoter window around each TSS (`--upstream` / `--downstream`), and
   each TE interval ± `--te-flank`.
4. Extract sequence for those windows — from a local FASTA via a built-in dependency-free
   random-access reader, or from NCBI E-utils by accession (`--sequence-source ncbi`), which
   avoids downloading whole genomes.
5. Download or reuse the **JASPAR CORE Insects** non-redundant motif set, add the
   literature-derived **CncC:Maf-S** ARE motif, and run MEME Suite's `fimo` over the windows.
6. Remap FIMO's window-local coordinates back to absolute genome coordinates and write one
   sorted GFF3: `gene` → `mRNA` → `exon`/`intron`, plus `mobile_genetic_element` and
   `TF_binding_site`.

```bash
python "build_tfbs_te_gff 1.py" \
    --te-file D_suzukiiGenesAffectedByTE.txt \
    --gff dsuzukii_annotation.gff3 \
    --fasta dsuzukii_genome.fa \
    --output combined_cyp_annotation.gff3
```

Multiple species can instead be sections of one `species_config.ini`, selected with
`--config … --species suzukii`.

**External requirements and their fallbacks:**

| Need | Options |
|---|---|
| `fimo` (MEME Suite) | on `PATH`, or `--fimo-path`, or `--fimo-via-docker`, or `--skip-tfbs` to omit motif scanning |
| Genome sequence | local FASTA, or `--sequence-source ncbi` |
| `bgzip`/`tabix` | only for `--bgzip-index`; local or `--bgzip-via-docker` |

**`--skip-tfbs` has a downstream consequence**: the output then contains no `TF_binding_site`
records, and the CncC comparison in stage 6 has nothing to filter on for that species. The
`jaspar_cache/` directory visible in `Summer26/JBrowse_gff_creator/` *(OCR doc 03a)* confirms
the JASPAR download step really ran in era 1.

---

## Stage 5 — Visualise in JBrowse ✅ (manual)

**In:** combined GFF3 + genome FASTA. **Out:** a genome browser view. No script.

From the lab notebook *(OCR doc 02)* and write-up *(OCR doc 05)*:

1. Open new genome; adapter type **FastaAdapter**; genome from the `Dhakad → genomes` tree.
2. **Name the assembly after the species, nothing else.** A track can only attach to an
   assembly whose name matches, so this convention is load-bearing.
3. Add a track using the processed annotation file; select the matching assembly; load.

`build_tfbs_te_gff.py --bgzip-index` produces a bgzipped, tabix-indexed file loadable directly
as a JBrowse 2 GFF3Tabix track.

Saved sessions exist for three species only — `Dmelanogaster_simulans_sechellia.jbrowse`
*(OCR doc 03b)*.

---

## Stage 6 — Cross-species comparison ✅

**In:** one combined GFF3 per species + a config INI. **Out:** CSV, markdown report, plot.
**Runtime:** seconds.

Three scripts, same machinery, progressively narrower gene sets. Scripts 2 and 3 `import
compare_te_cyp_exposure`, so all three must sit in one directory **under importable names** —
see the filename caveat in [`04-gaps-and-provenance.md`](04-gaps-and-provenance.md).

```mermaid
flowchart TD
    CFG["te_cyp_species_config.ini"] --> A
    A["compare_te_cyp_exposure.py<br/>ALL Cyp genes"]
    A --> B["compare_te_cyp_cncc.py<br/>Cyp genes near a CncC:Maf-S site"]
    A --> C["compare_te_cyp_xenobiotic.py<br/>curated resistance gene list"]
```

### How TEs are tied to genes here

Not by recomputing coordinate overlap. Stage 4 writes `Description=Within range of <symbol>`
onto every `mobile_genetic_element` record, and stage 6 reads the association straight out of
that attribute. **The 3 kb containment rule from stage 3b is therefore baked in** by the time
these scripts see the data, and cannot be changed here.

### Metrics computed per species

`n_cyp_genes`, `n_genes_with_te`, `pct_genes_with_te`, `total_te_count`, `total_cyp_bp`,
`te_per_kb`, `te_per_gene`. The last two exist to stop a species with more or longer Cyp genes
from appearing TE-rich merely by having more sequence to hit.

### Tests

Every individual Cyp gene, pooled across species, is one observation:

1. **Fisher's exact (two-tailed)** on `exposure group × gene has ≥1 TE` — tests TE *presence*.
2. **Mann-Whitney U** (normal approximation, tie-corrected) on per-gene TE *counts* — tests TE
   *burden*.

Both are pure-stdlib implementations, cross-validated against a second independently-coded
path by `--self-test`. A bootstrap over species clusters provides a confidence interval that
partially addresses the pooling problem.

```bash
python "compare_te_cyp_exposure 1 1.py" \
    --config te_cyp_species_config.ini \
    --output-csv te_cyp_summary.csv \
    --output-report te_cyp_report.md \
    --per-gene-csv te_cyp_per_gene.csv --plot

python "compare_te_cyp_exposure 1 1.py" --self-test     # stats validation only
```

### The two restricted variants

**`compare_te_cyp_cncc.py`** keeps only Cyp genes near a predicted CncC:Maf-S site — CncC is
the master regulator of Cyp-mediated detoxification, so this is the subset most directly
implicated in the hypothesis. It identifies those sites by `motif_source_id=CncC_Maf_ARE`
(unambiguous, since JASPAR hits carry `jaspar_matrix_id` instead), falling back to a `Name`
containing `cnc`. **Requires stage 4 to have run with motif scanning.** A species with zero
such records is reported as a **data gap**, explicitly, so it is not misread as "this species
has no CncC sites".

**`compare_te_cyp_xenobiotic.py`** keeps only genes on a plain-text, literature-curated list
(`--gene-list`) — the classic member being *Cyp6g1*. Matching is case-insensitive and **exact,
not partial**, so paralogs such as `Cyp12d1-d` and `Cyp12d1-p` must each be listed. It needs no
`TF_binding_site` records, so it works for species processed with `--skip-tfbs`. It also
reports which target genes were not found at all, which is the practical diagnostic for
cross-species naming mismatches.

### The caveat that is printed in every report

Pooling genes across species is **pseudoreplication** — genes within a species share a
phylogenetic and genomic background and are not independent observations. A species-level
comparison is also reported but, with a handful of species, is explicitly labelled descriptive
and exploratory rather than a formal test. This is stated in the generated output, not only
here.
