# CYP Gene Project — TE Analysis Pipeline: Detailed Documentation

**Sources this was reconstructed from** (17 photos, no source code files were available directly):
- Terminal screenshot of `spinContainer.sh` contents
- Two shots of a handwritten lab notebook page (RepeatMasker steps, 12-species list, GFF/VS Code
  steps, JBrowse steps)
- File Explorer screenshots of: `JBrowse_gff_creator`, `Spring26` folder, a RepeatModeler
  per-species output folder
- A 5-page typed "Atallah Lab Spring 2026 Log" (monthly narrative, Jan–May 2026)
- A 5-page formal write-up, *"Development and Use of Bioinformatics Scripts for Transposable
  Element Analysis in Drosophila,"* by Diljot Kaur
- A handwritten notebook page validating RepeatModeler against the Flynn et al. reference paper
- A whiteboard-style notebook sketch summarizing the RepeatModeler→RepeatMasker file handoff

**Caveat:** several items below are transcribed from handwriting that was partly illegible,
crossed out, or photographed at an angle. These are marked **[VERIFY]**. Treat exact command
flags, filenames, and species spellings as "best reconstruction," not verified ground truth —
confirm against the live scripts/folders before relying on this for an actual run.

---

## 1. Project goal

From D. Kaur's write-up: identify and compare transposable elements (TEs) across 300+
*Drosophila* genomes and determine whether TEs are located within or near cytochrome P450 (CYP)
genes, and whether those TEs contain/introduce transcription factor binding sites (TFBS) that
could affect CYP gene expression/regulation.

## 2. People and script ownership (from the Spring 2026 log)

| Person | Contribution |
|---|---|
| Diljot Kaur | Wrote up the pipeline; maintained/fixed gene-renaming scripts; ran RepeatModeler2/RepeatMasker for most species; kept the Spring 2026 log |
| Duy | Wrote `ReVamp_Final.py` (produced Gff_Dataset#2); co-developed the RepeatModeler2→RepeatMasker→TFBS pipeline in March; processed RepeatMasker results into TE counts |
| Ayush | Edited Diljot's older scripts over winter break → became `NEW_Step_5_Replace_gff_Names_with_Dmelanogaster_1_9.py` (produced Gff_Dataset#1) |
| Charles | Co-developed the pipeline in March; worked on RepeatMasker/TFBS result processing |
| Terry | Contributed custom scripts (per write-up, role not detailed further) |

## 3. Species processed

Handwritten list of 12 target species (notebook page 1) **[VERIFY spellings]**:
1. D. simulans
2. D. suzukii (written "sushkid") **[VERIFY]**
3. D. erecta
4. D. yakuba (written "ucuba") **[VERIFY]**
5. D. ananassae (written "annaesar"/"ananaesar") **[VERIFY]**
6. D. pseudoobscura

(Notebook lists ~6 clearly, with "12 species" as the heading — the remaining 6 were not captured
in the photos.)

Separately, a validation/benchmark run (see §7) lists: D. ananassae **[VERIFY]**, D. melanogaster,
D. simulans, D. sechellia, and an illegible fifth entry transcribed as "LSI moga" **[VERIFY —
likely a mis-transcription; could not be confidently read]**.

The eventual JBrowse/TFBS results folder (`RM2_RM_TFBS_Results`) contains files specifically for
**D. melanogaster, D. sechellia, and D. simulans**.

## 4. Folder structure (as seen in File Explorer screenshots)

```
Data (D:)
└── CYP_Gene_Project/
    ├── Dhakad_et_al_2025_Data_Analysis/
    │   └── 12_species_genomes/        (OLD RepeatModeler input location, pre-Spring26)
    ├── Spring26/
    │   ├── DuySpring26/
    │   ├── Gff_Dataset#1/             (built by NEW_Step_5_Replace_gff_Names_with_Dmelanogaster_1_9.py)
    │   ├── Gff_Dataset#2/             (built by ReVamp_Final.py — this is the CURRENT dataset per Jan log & notebook Step 1)
    │   ├── RM2_RM_TFBS_Results/
    │   │   ├── TEandTFdata.xls        (processed TE/TF counts)
    │   │   └── JBrowse files for D.melanogaster, D.sechellia, D.simulans
    │   ├── spring26repeatmodeler/     (MAIN RepeatModeler2 working directory)
    │   │   └── <species>/
    │   │       ├── spinContainer.sh
    │   │       ├── runMasker.sh
    │   │       └── RM_<date>/         (or similarly dated folder)
    │   │           ├── round-1/ … round-5/
    │   │           ├── cd-hit-out.clstr
    │   │           ├── consensi.fa
    │   │           ├── consensi.fa.classified      ← key output, feeds RepeatMasker
    │   │           ├── consensi.fa.recon_rscout_only
    │   │           ├── consensi.fa.with_redundancy (or similar name, partially obscured)
    │   │           ├── families.stk
    │   │           ├── families.stk.reconciled
    │   │           ├── families.stk.with_redundancy
    │   │           ├── families-classified.stk
    │   │           ├── genome.2bit
    │   │           ├── rmod.log
    │   │           ├── tmpConsensi.fa
    │   │           ├── tmpInputSeq-ltrs.fa
    │   │           └── tmpInputSeq-ltrs.stk
    │   ├── 12species_andothers.txt
    │   ├── Dmelanogaster_simulans_sechellia.jbrowse
    │   ├── GCF_016746245.2_Prin_Dsan_1.1_genomic.fna   (example genome FASTA)
    │   ├── Drosophila_sulfurigaster_albostrigata.GCA_023558435.1.rm.fna.out  (example RepeatMasker output)
    │   └── TL Spring 2026 Log.docx    (source of the typed monthly log)
    └── Summer26/
        └── JBrowse_gff_creator/
            ├── build_tfbs_te_gff.py
            ├── build_tfbs_te_gff - Copy.py
            ├── compare_te_cyp_cncc 1.py
            ├── compare_te_cyp_exposure 1.py
            ├── compare_te_cyp_xenobiotic 1.py
            ├── jaspar_cache/          (cached JASPAR transcription-factor motif database)
            ├── Old Scripts/
            └── per-species working folders:
                Helvetica, Lugracilis[?], Mauritania, Melanogaster, Miranda, Pandora,
                Santomea, Sechellia, Subpulchrella, Sulfirigaster,
                Sulfirigaster_albostrigata, Sulfirigaster_Bilimbata, Suzukii,
                Tropicalis, Willistoni
```

Notes:
- `Dhakad_et_al_2025_Data_Analysis` is explicitly called out in the log as the **old**
  location that Spring26 work replaced — don't treat it as current.
- `Summer26/JBrowse_gff_creator` looks like a **later reorganization** (dated file timestamps
  June–September 2026) of the GFF/TFBS scripts vs. the Spring26 folder — the `compare_te_cyp_*.py`
  scripts (CNCC, exposure, xenobiotic) appear here but are not mentioned by name in the Spring log,
  suggesting they were added/renamed after May 2026. **[VERIFY current vs. legacy script set with
  whoever maintains the repo now.]**

## 5. Stage 1 — RepeatModeler2 (build the TE library)

**Working directory:** `CYP_Gene_Project/Spring26/spring26repeatmodeler/<species>/`

**Step 1 — spin up the tool container** (`spinContainer.sh`, contents verified via `cat`):
```bash
docker run -it --rm \
    -v $(pwd):/Spring26RepeatModeler \
    -w /Spring26RepeatModeler \
    dfam/tetools:latest bash
```
This mounts the current directory into the `dfam/tetools` Docker image (which bundles
RepeatModeler/RepeatMasker/RECON/RepeatScout etc.) and drops into a bash shell inside it.

**Step 2 — build a searchable database from the genome:**
```bash
BuildDatabase -name D_speciesname Species_genome_file.fa
```
(`D_speciesname` is a per-run label, e.g. `D_erecta`; `Species_genome_file.fa` is that species'
genome FASTA, placed in the same folder beforehand.)

**Step 3 — run RepeatModeler2 on that database:**
```bash
RepeatModeler -database D_speciesname -threads 10 -LTRStruct
```
- `-threads 10`: parallelism.
- `-LTRStruct`: enables the LTR structural-analysis pipeline (finds long-terminal-repeat
  retrotransposons in addition to the standard RECON/RepeatScout repeat search).
- **Runtime:** 8–26 hours depending on genome size (per log).

**Outputs**, all in a dated subfolder (e.g. `RM_<date>/`):
- `consensi.fa.classified` — **the key deliverable**: the classified TE consensus library. This is
  the single file that gets carried into Stage 2.
- Working/intermediate files: `round-1` … `round-5` (iterative rounds of RECON/RepeatScout),
  `families.stk` and variants, `consensi.fa` (pre-classification), `cd-hit-out.clstr`,
  `genome.2bit`, `rmod.log` (run log), `tmpConsensi.fa`, `tmpInputSeq-ltrs.*`.

**Handoff:** `consensi.fa.classified` is copied/renamed with the run date and moved into the
RepeatMasker working area for that species (per notebook: *"After repeat modeler RM file w/date
Data D. … consensi.fa.classified"*).

## 6. Stage 2 — RepeatMasker (annotate TE locations on the genome)

**Basic workflow (per D. Kaur's write-up, §"RepeatMasker"):**
1. Copy the RepeatModeler output (`consensi.fa.classified`) into the RepeatMasker folder (it's
   already there from Stage 1 if working in the same species folder).
2. Run RepeatMasker using that custom library against the genome FASTA:
   ```bash
   RepeatMasker -lib RM_<date>/consensi.fa.classified -pa 8 <species_genome>.fna
   ```
   **[VERIFY exact flag order/spelling]** — reconstructed from a handwritten line that read
   approximately: *"RepeatMasker -lib RM_#$date/consensi.fa.classified -pa 8 Drosophila_...fna
   file"* with a note to copy/paste-replace the placeholder species name into the command each
   time. `-pa 8` sets parallel search processes to 8.
3. Save the output files for downstream analysis.

**Output:** a `.out` file describing every masked repeat's location, class/family, and
coordinates in the genome — e.g. the example file seen:
`Drosophila_sulfurigaster_albostrigata.GCA_023558435.1.rm.fna.out`.

Per the log (April/May): after RepeatMasker + gene-renaming is done for a species, the new
annotation file (named with suffix `_withDmelNames.gff`) is compressed and placed in a
`For RepeatMasker` folder, then uploaded to OneDrive for a collaborator (Duy) to pick up.

## 7. RepeatModeler2 validation run (QC step, not part of the per-species production pipeline)

To sanity-check the pipeline, RepeatModeler2 was re-run on the *D. melanogaster* reference genome
using the same genome and parameters as the Flynn et al. published TE-library paper, to compare
family counts:
```
Parameters: -LTRStruct -srand 1570222393 -LTRMaxSeqLen 10000
```
**[VERIFY `-srand`]** — not a standard documented RepeatModeler flag as transcribed; may be a
random-seed argument specific to the installed version, or a transcription error for a different
flag. Confirm against `RepeatModeler --help` in the actual container before reusing.

- Result: **471 families** obtained vs. Flynn et al.'s reported **734 families**.
- Runtime: 12:39:21 (hh:mm:ss).
- Corresponding authors of the Flynn et al. paper were emailed to ask what additional parameters
  produced their 734-family count; response was pending as of the log entry.
- **Implication:** current default parameters likely under-count TE families relative to the
  published benchmark — worth resolving before treating per-species family counts as final.

## 8. Stage 3 — Python GFF / gene-TE linking scripts (run manually in VS Code)

**Purpose (per write-up):** RepeatMasker's raw output isn't formatted for direct analysis. These
scripts merge RepeatMasker TE-location data with the gene annotation (GFF) file, relabel each
species' genes with their *D. melanogaster* ortholog names (for cross-species comparability), and
identify which genes are affected by nearby/overlapping TEs.

**Known scripts (two generations):**
- `NEW_Step_5_Replace_gff_Names_with_Dmelanogaster_1_9.py` — Ayush's edit of Diljot's older script;
  produced **Gff_Dataset#1**.
- `ReVamp_Final.py` — Duy's script; produced **Gff_Dataset#2**; per the notebook's Step 1, this is
  the version pointed to by the current workflow (`Data(D:) → Cyp → Spring26 → GFF #2, Duy`).
- `build_tfbs_te_gff.py` (and a `- Copy.py` duplicate) — found in the later
  `Summer26/JBrowse_gff_creator` folder; likely a further-evolved/renamed version of the same
  gene↔TE↔GFF merging logic, now scoped toward TFBS output specifically. **[VERIFY relationship
  to ReVamp_Final.py — could be a successor or a parallel branch.]**

**Manual run procedure, transcribed directly from the lab notebook (3 steps, repeated per
species):**

> **Step 1**
> - Open Visual Studio Code.
> - GFF files come from: `Data(D:) → Cyp → Spring26 → GFF #2, Duy` (i.e. Gff_Dataset#2).
> - Drag the species' GFF file into VS Code.
> - Copy the file path from the left-hand file panel and paste it onto the highlighted ("blue")
>   GFF path variable in the script.
> - Fix slash direction (Windows `\` vs. the script's expected `/`).
> - Save the file.
> - Click the small "run" arrow in VS Code to execute the script.
>
> **Step 2**
> - In VS Code's "Sources" panel, copy the relative path of the RepeatMasker output file.
> - Paste it into "row 5" of the script (the RepeatMasker-file path variable).
> - Fix slashes again.
> - Save.
> - Click the run arrow again.
>
> **Step 3**
> - Right-click the output area/folder and create a new file named:
>   `D_<species>GenesAffectedByTE.txt`
> - Copy that new file's relative path.
> - Paste it into "row 4" of the script (scroll to the highlighted "blue" line).
> - Save the file.
> - Click the run arrow to execute.
>
> All completed files land in the script's designated **output folder**.

This is the most manual, most error-prone stage of the pipeline — three separate file paths must
be hand-edited per species, per run, directly inside the script source before each execution.

**Output:** `D_<species>_GenesAffectedByTE.txt` per species (naming per notebook; underscore
placement not fully legible — **[VERIFY exact filename format]**).

## 9. Stage 4 — JBrowse visualization

**Loading a new genome assembly** (from notebook):
1. Open JBrowse → "Open new Genome."
2. Type: **FastaAdapter**.
3. Genome file location: `(D:) Drive → Cyp → Dhakad → Dhakad → genomes` **[VERIFY — this path
   references the OLD `Dhakad_et_al_2025_Data_Analysis` tree, not Spring26; may be intentional if
   raw genome FASTAs were never moved, or may be stale guidance]**.
4. Name the assembly using just the species name (no extra suffixes).

**Adding an annotation track** (from write-up):
1. Open JBrowse.
2. Add a new track using the processed annotation file (output of Stage 3).
3. Select the correct genome assembly (must match the genome loaded above).
4. Load the track and examine TE locations relative to CYP genes and TFBS.

**Output:** a saved JBrowse session/config, e.g. `Dmelanogaster_simulans_sechellia.jbrowse`,
letting a researcher visually inspect TE / CYP-gene / TFBS overlap for that species combination.

## 10. Stage 5 — Transcription Factor Binding Site (TFBS) / motif analysis

**Purpose (per write-up):** identify potential DNA regions where transcription factors may bind,
and check whether those predicted binding sites are located within or near TEs associated with
CYP genes — i.e., whether a TE could plausibly be introducing or disrupting a regulatory switch
near a CYP gene.

**Inputs:** the processed annotation files from Stage 3, plus a transcription-factor motif
database — the `jaspar_cache/` folder (cached data from the JASPAR TF binding-motif database)
found alongside the `compare_te_cyp_*.py` scripts.

**Scripts (folder: `Summer26/JBrowse_gff_creator/`):**
- `compare_te_cyp_cncc 1.py`
- `compare_te_cyp_exposure 1.py`
- `compare_te_cyp_xenobiotic 1.py`

The three-part naming (CNCC / exposure / xenobiotic) suggests each script checks TE↔CYP-gene
relationships against a different biological category of CYP gene function — **[VERIFY exact
distinction; not explained in the source materials]**.

**Basic workflow (per write-up):**
1. Prepare the required input files (Stage 3 output + JASPAR data).
2. Run the TFBS analysis script.
3. Generate output files.
4. Compare/interpret predicted TFBS locations against TE and CYP-gene locations.

**Output:** results consolidated in
`CYP_Gene_Project/Spring26/RM2_RM_TFBS_Results/`, including:
- `TEandTFdata.xls` — processed TE/TF counts.
- Per-species JBrowse files for **D. melanogaster, D. sechellia, D. simulans**.

## 11. Timeline (from the typed Spring 2026 log)

| Month | Milestone |
|---|---|
| January | Fixed prior semester's gene-renaming code; produced Gff_Dataset#1 (Ayush's script) and Gff_Dataset#2 (Duy's `ReVamp_Final.py`); made LBRN poster (24 Jan 2026 meeting) |
| February | Began developing the RepeatModeler2 procedure; attempted to replicate the *D. melanogaster* TE library from Flynn et al. for comparison |
| March | Built the full RepeatModeler2 → RepeatMasker → TFBS/Motif pipeline (with Duy and Charles); wrote `spinContainer.sh` / `runMasker.sh`; standardized `BuildDatabase` / `RepeatModeler` commands |
| April–May | Continued running the pipeline across species; processed and uploaded results to OneDrive for collaborators; consolidated results into `RM2_RM_TFBS_Results/` |
| (undated, in log) | RepeatModeler2 validation against Flynn et al. benchmark — 471 vs. 734 families; emailed paper authors for clarification, awaiting response |

## 12. Open items to verify before treating this as authoritative

1. Exact contents of `runMasker.sh` (only paraphrased from handwriting — never seen via `cat`).
2. Exact contents of `ReVamp_Final.py`, `NEW_Step_5_Replace_gff_Names_with_Dmelanogaster_1_9.py`,
   `build_tfbs_te_gff.py`, and the three `compare_te_cyp_*.py` scripts (names known, logic not
   inspected).
3. Whether `Summer26/JBrowse_gff_creator` scripts are the **current** production pipeline or a
   parallel/experimental branch relative to the Spring26 folder.
4. Full 12-species list (only ~6 were legible in the notebook photo).
5. The `-srand` RepeatModeler flag from the validation run (§7).
6. Resolution of the 471-vs-734 TE family count discrepancy with Flynn et al.
7. Exact output filename format for Stage 3 (`D_<species>GenesAffectedByTE.txt` vs. an
   underscore-separated variant).
