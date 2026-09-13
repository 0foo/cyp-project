# Gaps, defects and provenance

What is missing from the pipeline, what is wrong with it, what is unresolved — and where each
of those claims comes from. Nothing here is speculation; anything inferred says so.

---

## Part 1 — Gaps: the stages with no code

### G1. RepeatMasker (stage 2) — the blocking gap

`runMasker.sh` was never photographed and never committed.

The stage is well described, though — the command is paraphrased in the lab notebook
*(OCR doc 02)* and the procedure is set out independently in the write-up *(OCR doc 05)*,
both reproduced in
[`02-stage-reference.md`](02-stage-reference.md#stage-2--annotate-te-locations-genome-wide-):

```
RepeatMasker -lib <RM_dated_dir>/consensi.fa.classified -pa 8 <species>.fna
```

What is genuinely lost is the script: the exact flag order, any additional flags, and whether
it looped over species or was run once per species by hand.

**Impact:** the pipeline cannot be run end to end from raw genomes. Stage 1 completes and
then stops.

**Severity: low to fix, high to ignore.** This is one standard command against a standard tool.
Rebuilding it as a second worker in `repeat-modeler-automation/` — same claim-based pattern,
same container image — is the obvious move, since RepeatMasker is also slow and also per-species.

### G2. Gene renaming (stage 0b) — the subtler gap

Neither `ReVamp_Final.py` (Duy, Dataset #2) nor
`NEW_Step_5_Replace_gff_Names_with_Dmelanogaster_1_9.py` (Ayush, Dataset #1) is committed
*(OCR doc 04)*.

**Impact:** you cannot add a new species to the study. Every existing species' annotation was
already renamed; a new one cannot be, so it will match nothing in `Reg_Gene_Full.txt`.

**Severity: harder than G1.** It needs both the code and the ortholog assignment behind it.
The committed output shows the mapping came from hierarchical orthogroups (`hog=N1.HOG…`), so
it is reproducible in principle, but not by copying a one-line command.

**Also unresolved:** which dataset supersedes the other. The log describes both without
ranking them; the lab notebook's procedure points at Dataset #2, which is the only evidence
of which was current *(OCR doc 02)*.

### G3. Files referenced but absent

- `species_config.example.ini`, `te_cyp_species_config.example.ini` and
  `xenobiotic_resistance_cyp_genes.example.txt` are referenced by all four scripts in
  `analysis-pipeline/` and by its README. **None exist.** Formats are documented in
  [`03-data-contracts.md`](03-data-contracts.md); the templates have to be written by hand.
- `12species_andothers.txt` — the full twelve-species list. Seen in a File Explorer window
  *(OCR doc 03b)*, not photographed open. The lab notebook's list gives only six of the twelve,
  three of them illegible *(OCR doc 02)*.
- **A fourth log page listing per-species family counts and runtimes.** Its existence is
  visible as mirror-image show-through on the back of log page 3 — `Families:` and `Runtime:`
  lines against species names — but the page itself was never photographed *(OCR doc 04)*.
  This is the only place per-species TE family counts were recorded.
- `TEandTFdata.xls`, the era 1 results spreadsheet *(OCR doc 04)*.
- `Old Scripts/`, contents unphotographed *(OCR doc 03a)*.

---

## Part 2 — Defects in the code that is here

Ordered by how much they affect a result you might publish.

### D1. Simple repeats are counted as transposable elements

RepeatMasker reports every repeat, not only TEs. Nothing in the pipeline filters on repeat
class: stage 3b keeps every hit in the window, stage 4 records the class faithfully as
`repeat_class=` and then never uses it, and none of the three comparison scripts mention it.

Measured on the committed *D. ananassae* result (900 rows):

| Class | Rows | Actually a TE? |
|---|---|---|
| `Simple_repeat` | 502 | no |
| `Low_complexity` | 118 | no |
| `Unknown` | 136 | unclassified |
| `RC/Helentron`, `LTR/Gypsy`, `LINE/CR1`, `RC/Helitron`, `DNA/TcMar-Tc1`, other | 144 | yes |

**About 69% of what the pipeline calls "TE burden" is microsatellite and low-complexity
sequence.** If simple-repeat density is uniform across species this adds noise; if it varies
with genome assembly quality or GC content — which it does — it adds bias, and in a comparison
between species groups that is exactly the wrong kind of error.

**Fix:** filter on `repeat_class` (field 10 of the `.out` line). The cleanest place is stage 3b,
but stage 4 already parses the class and could expose a `--repeat-class-exclude` option
without disturbing the narrow-waist format. **Whichever is chosen, it should be a deliberate,
recorded decision rather than the current silent inclusion.**

### D2. Row duplication in `filtered.gff`

`repeatOpp.py` emits one row per *matching symbol* rather than per gene, so a gene annotated
with four Cyp names is written four times. Measured: **166 rows, 91 unique, 57 distinct
genes**, from 117 input gene records.

Stage 4 de-duplicates on the way in, so the final GFF3 is correct — but any count taken from
`filtered.gff`, `GenesAffectedByTEs.txt` or `D_*GenesAffectedByTE.txt` directly is inflated by
roughly 80%. The `AnalysisForAll/` intermediate files have this property.

### D3. The TE window tests containment, not overlap

`Locate_TE.py` requires the repeat to lie *entirely* within `[gene_start − 3000,
gene_end + 3000]`. An element straddling the window edge is dropped.

This is the wrong default for TE work — overlap is the standard criterion — and it biases
against exactly the long elements most likely to matter. The *Accord* insertion upstream of
*Cyp6g1*, the case that motivates the whole project, is ~7 kb; an element that size sitting in
a promoter would be excluded by this test unless it happened to fall wholly inside the window.

Because stage 4 writes the association into `Description=Within range of …` and stage 6 reads
it from there, **this rule is fixed at stage 3 and cannot be revisited downstream.**

Related, minor: `start` goes negative for genes within 3 kb of the start of a sequence. Harmless
in practice, but the window is silently asymmetric for those genes.

### D4. The `D`-prefix skip drops five real entries

Both `repeatOpp.py` and `CleanAnnasse.py` skip every line of `Reg_Gene_Full.txt` beginning with
`D`. Five genuine entries are discarded: `Dvir\GJ21722`, `Dmoj\GI21254`, `Dvir\GJ21709`,
`Dvir\GJ22648`, `Dvir\GJ20586`. The effective target list is **91 symbols, not 96**.

### D5. Substring matching in stage 3, exact matching in stage 6

Stage 3 matches with `Rgene in fields[8]` — a substring test against the whole attribute
column. Stage 6's xenobiotic list matches exactly and case-insensitively. The two stages
therefore disagree about what "this gene is on the list" means, and a short symbol in
`Reg_Gene_Full.txt` will match longer unrelated symbols.

### D6. The ` 1 1` filename suffixes break the imports

`compare_te_cyp_cncc.py` and `compare_te_cyp_xenobiotic.py` both do
`import compare_te_cyp_exposure`, which cannot resolve against a file named
`compare_te_cyp_exposure 1 1.py`. **As committed, two of the three comparison scripts do not
run.** Rename all four to drop the suffixes.

The suffixes are Windows duplicate-file renames acquired on round trips through zip and
OneDrive — ` 1` in the Summer 2026 working folder *(OCR doc 03a)*, doubled to ` 1 1` by a
further export, of which `analysis-pipeline/OneDrive_1_9-1-2026.zip` is one.

### D7. Stage 3 has hardcoded absolute paths and no arguments

All three scripts carry `C:/Users/User/Documents/BioAtallah/...` literals at module scope and
must be edited before each run. This is the direct cause of the twenty-nine hand-typed output
filenames, three of which are misspelled (`D_secheliaGenesAffectedByT.txt`,
`D_athabascaGenesAfffectedByTE.txt`, `D_arawakanaGenesAffectedByTe.txt`).

**This is the highest-value automation target left in the project.** Stage 1 has already been
industrialised; stage 3 has not, and it is the stage that gets run once per species by hand.

### D8. Scaling

`Locate_TE.py` is `O(genes × repeats)` with the entire `.out` file held in memory — 91 genes ×
297,073 repeats for *D. ananassae*. Adequate for a Cyp-only gene set; it will not survive being
pointed at a whole-genome annotation.

---

## Part 3 — Unresolved scientific questions

### U1. The Flynn et al. benchmark shortfall

Rerunning *D. melanogaster* on the same genome with the same stated parameters
(`-LTRStruct`, `-srand 1570222393`, `-LTRMaxSeqLen 10000`) produced **471 families against the
published 734** — a 36% shortfall. Runtime 12:39:21. The corresponding authors were emailed to
ask about further parameters; the log records *"Awaiting response"* and nothing after
*(OCR doc 04, page 3)*.

**This is unresolved and it is material.** Until it is closed out, per-species family counts
from this pipeline should be treated as a lower bound rather than a measurement. Note also
that `-srand` is not a documented RepeatModeler option as transcribed — it may be
version-specific or a transcription artefact, and it has not been verified against
`RepeatModeler --help`.

### U2. Pseudoreplication

The comparison pools individual Cyp genes across species and treats each as an independent
observation. Genes within a species share a genome and a phylogeny, so they are not. With only
a handful of species there is no clean alternative: a species-level test would have almost no
power.

The code handles this about as well as it can be handled — it states the caveat in every
generated report, runs a bootstrap over species clusters for a more honest confidence
interval, and labels the species-level comparison as descriptive rather than inferential. **The
caveat should never be removed from the report template**, and results should not be quoted
without it.

### U3. How many species is this study actually about?

Four different numbers appear, and they are not contradictory — they are ambition, target,
completed and visualised. Quote the right one:

| Number | What it is | Source |
|---|---|---|
| 300+ | the stated ambition | write-up introduction *(OCR doc 05)* |
| 12 | the target batch | lab notebook heading, though only six are listed *(OCR doc 02)* |
| 17 | per-species working folders in the Summer 2026 analysis directory | *(OCR doc 03a)* |
| 29 | species with a completed stage 3 table | `AnalysisForAll/output/`, counted |
| 5 | species in the comparison configuration | the stage 6 script docstrings |
| 3 | species with saved JBrowse sessions | *(OCR docs 03b, 04)* |

The "300+" figure should not be read as a count of anything that exists.

---

## Part 4 — Provenance

### Who did what

From the Spring 2026 log and the write-up *(OCR docs 04, 05)*:

| Person | Contribution |
|---|---|
| Diljot Kaur (log author, write-up author) | Fixed the gene-renaming code; ran RepeatModeler2 and RepeatMasker; kept the log; wrote the procedural write-up; made the LBRN poster |
| Duy | `ReVamp_Final.py` → Gff_Dataset#2; co-developed the March pipeline; ran RepeatMasker processing |
| Ayush | Winter-break edits producing `NEW_Step_5_Replace_gff_Names_with_Dmelanogaster_1_9.py` → Gff_Dataset#1 |
| Charles | Co-developed the March pipeline; downstream RepeatMasker/TFBS result processing |
| Terry | Custom scripts, named in the write-up only |

The pipeline itself is dated: *"March — Developed pipeline for RepeatModeler2 → RepeatMasker →
TFBS/Motif Analysis with Duy and Charles"* *(OCR doc 04)*.

### Why the code looks the way it does

Nearly every oddity in this repository traces to a documented fact about how the work was
actually done:

| Observation | Explanation | Source |
|---|---|---|
| Stage 1 is crash-tolerant infrastructure; everything else is plain scripts | 8-26 h per genome; 45 h observed | *OCR docs 04, 03c* |
| Hardcoded Windows paths at the top of the stage 3 scripts | They were run by hand in VS Code, pasting one path per run, three runs per species | *OCR docs 02, 05, 06* |
| ` 1` and ` 1 1` filename suffixes | Windows duplicate-rename on round trips through zip/OneDrive | *OCR doc 03a* |
| No end-to-end driver script exists | No single machine ever ran the whole pipeline — stage 2 happened on a collaborator's machine, reached via OneDrive | *OCR doc 04* |
| Zero third-party Python dependencies | Code had to run on whatever machine received the zip | inferred from the above |
| Genome FASTAs still read from the older `Dhakad` tree | Apparently never moved when `Spring26/` became the working directory | *OCR docs 02, 04, 06* |

### The archive itself

Seventeen photographs in `collected-docs/src/`, transcribed in [`OCR docs/`](../../../OCR%20docs/):
a terminal window, two shots of one lab-notebook page, three File Explorer windows, a typed
three-page monthly log, a five-page student write-up, and a handwritten data-flow sketch.
`Photos-1-001.zip` contains no unique images.

All seventeen have been read and their transcriptions verified against the images. What the
photographs establish that no file in the repository does: the container invocation, the
RepeatModeler command and its parameters, the 8-26 hour runtime, the manual VS Code procedure,
the OneDrive handoff, the Flynn benchmark shortfall, and who wrote which script.
