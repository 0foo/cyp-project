# 03 — File Explorer screenshots: directory layout

**Sources:**
- `collected-docs/src/PXL_20260831_174105078.jpg` — `Summer26\JBrowse_gff_creator`
- `collected-docs/src/PXL_20260904_193934568.jpg` — `Spring26`
- `collected-docs/src/PXL_20260904_194848577.jpg` — a RepeatModeler output directory

**Type:** photographs of Windows 10 File Explorer windows
**Legibility:** good for names, poor for the right-hand columns (size/type are cut off or
blurred in all three)

---

## 3a. `This PC > Data (D:) > CYP_Gene_Project > Summer26 > JBrowse_gff_creator`

Status bar: **29 items**, 1 item selected, 22.3 KB.

Name column, as visible (the list is scrolled; at least one entry is clipped at the top):

```
Lugracilis            [clipped at top edge; "Eugracilis" is the likely reading]
Helvetica
jaspar_cache
Mauritania
Melanogaster
Miranda
Old Scripts
Pandora
Santomea
Sechellia
Subpulchrella
Sulfirigaster
Sulfirigaster_albostrigata
Sulfirigaster_Bilimbata
Suzukii
Tropicalis
Willistoni
build_tfbs_te_gff - Copy.py
build_tfbs_te_gff.py
compare_te_cyp_cncc 1.py
compare_te_cyp_exposure 1.py
compare_te_cyp_xenobiotic 1.py
```

Date-modified values are legible for part of the list and span **7/15/2026 – 8/27/2026**.
The three `compare_te_cyp_*` files and `build_tfbs_te_gff.py` cluster at **7/28–7/29/2026**;
`build_tfbs_te_gff - Copy.py` is 8/20/2026 [?].

**Notes.**

- These are the **same four scripts committed to `analysis-pipeline/`** in this repository.
  The ` 1` suffix visible here (`compare_te_cyp_cncc 1.py`) is Windows' duplicate-file
  rename, not a version number. The committed copies carry it twice
  (`compare_te_cyp_cncc 1 1.py`) because they made a second round-trip through a
  zip/OneDrive export — `analysis-pipeline/OneDrive_1_9-1-2026.zip` is that export.

  This matters: `compare_te_cyp_cncc.py` and `compare_te_cyp_xenobiotic.py` both do
  `import compare_te_cyp_exposure`, which cannot resolve against a file named
  `compare_te_cyp_exposure 1 1.py`. The suffix has to be stripped before anything runs.

- `jaspar_cache/` is the on-disk cache directory `build_tfbs_te_gff.py` creates and reuses
  (`--jaspar-cache-dir`, default `./jaspar_cache`). Its presence confirms the JASPAR
  download step actually ran here.

- The per-species folders are the working directories for individual runs. Seventeen are
  visible; the sixteen species names among them overlap only partly with the "12 species"
  notebook list (doc 02) and with the 29 species in
  `pipeline-scripts-output/AnalysisForAll/output/`.

- `Old Scripts/` — contents not photographed.

---

## 3b. `This PC > Data (D:) > CYP_Gene_Project > Spring26`

Status bar: **10 items**, 1 item selected.

```
Name                                                          Date modified      Type
DuySpring26                                                   6/3/2026 11:26 AM  File folder
Gff_Dataset#1                                                 5/7/2026 2:11 PM   File folder
Gff_Dataset#2                            [selected]           7/9/2026 12:04 PM  File folder
RM2_RM_TFBS_Results                                           4/17/2026 10:41 AM File folder
spring26repeatmodeler                                         9/4/2026 2:17 PM   File folder
12species_andothers.txt                                       6/5/2026 11:54 AM  TXT File
Dmelanogaster_simulans_sechellia.jbrowse                      6/30/2026 1:36 PM  JBROWSE File
Drosophila_sulfurigaster_albostrigata.GCA_023558435.1.rm.fna.out
                                                              6/10/2026 2:32 PM  OUT File
GCF_016746245.2_Prin_Dsan_1.1_genomic.fna                     6/5/2026 11:03 AM  FASTA sequence file
TL Spring 2026 Log.docx                                       5/7/2026 2:40 PM   Microsoft Word D…
```

A tooltip hovering over `Gff_Dataset#2` reads:

```
Date created: 5/7/2026 2:11 PM
Size: 278 KB
Folders: Duy_New_Scripts
```

**Notes.**

- `Gff_Dataset#2` contains a single subfolder, `Duy_New_Scripts`, and is only 278 KB — so
  it is a *script* folder, not a data folder, despite the name. The log (doc 04) says
  Dataset #2 was produced by `ReVamp_Final.py`; this is presumably where that script lives.
- `12species_andothers.txt` is the likely home of the full twelve-species list that doc 02
  only partially captures. Not photographed. [VERIFY]
- `Dmelanogaster_simulans_sechellia.jbrowse` is the saved JBrowse session — three species,
  matching the three the log says results were produced for.
- `GCF_016746245.2_Prin_Dsan_1.1_genomic.fna` is *D. santomea* (`Dsan`), one of the two
  low-exposure species in the committed comparison config format.
- `TL Spring 2026 Log.docx` is the source document for doc 04.

---

## 3c. `… > Spring26 > spring26repeatmodeler > RM…` (a RepeatModeler output directory)

Status bar: **…0 items**, 1 item selected, 2.13 MB. The breadcrumb is cut off after
`spring26repeatmodeler > RI…`.

```
Name                                 Date modified
LTR_235549.ThuJul92144222026         7/10/2026 12:43 PM
round-1                              7/8/2026 6:33 PM
round-2                              7/8/2026 6:44 PM
round-3                              7/8/2026 7:57 PM
round-4                              7/9/2026 3:19 AM
round-5                              7/9/2026 4:43 PM
cd-hit-out.clstr                     7/10/2026 12:45 PM
consensi.fa                          7/10/2026 12:45 PM
consensi.fa.classified   [selected]  7/10/2026 1:14 PM
consensi.fa.recon_rscout_only        7/9/2026 4:41 PM
consensi.fa.with_[redundancy]        7/10/2026 12:43 PM
families.stk                         7/10/2026 12:45 PM
families.stk.recon[ciled]            7/9/2026 4:41 PM
families.stk.with_redundancy         7/10/2026 12:43 PM
families-classified.stk              7/10/2026 1:14 PM
genome.2bit                          7/8/2026 4:06 PM
rmod.log                             7/10/2026 1:14 PM
tmpConsensi.fa                       7/10/2026 12:46 PM
tmpInputSeq-ltrs.fa                  7/10/2026 12:43 PM
tmpInputSeq-ltrs.stk                 7/10/2026 12:43 PM
```

A tooltip over `consensi.fa.recon_rscout_only` reads:

```
Type: RECON_RSCOUT_ONLY File
Size: 1.76 MB
Date modified: 7/9/2026 4:41 PM
```

Two filenames are partially hidden behind that tooltip and are completed above in brackets
from RepeatModeler's known output naming.

**Notes.**

- **The timestamps date the run.** `genome.2bit` is written at the start
  (7/8 4:06 PM); `consensi.fa.classified` is written last (7/10 1:14 PM). That is
  **~45 hours wall-clock** — above the 8–26 hour range the log quotes (doc 04), consistent
  with `-LTRStruct` being enabled (the `LTR_235549.ThuJul92144222026` directory is the LTR
  pipeline's scratch space, and the committed `rmodeler.conf.example` warns that
  `LTRSTRUCT=1` "roughly doubles wall time and disk").
- **The round directories show the RECON/RepeatScout iteration**, and their spacing shows
  why: round-1 → round-2 took 11 minutes, round-4 → round-5 took 13 hours. Rounds get
  dramatically more expensive as they go.
- `consensi.fa.classified` is the one file that leaves this directory. Everything else is
  intermediate. The committed `worker.sh` reflects a newer RepeatModeler convention and
  collects `<sample>-families.fa` / `.stk` instead, but the principle is the same: one
  library file out, delete the rest unless `KEEP_WORK=1`.
