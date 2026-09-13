# 04 — Atallah Lab Spring 2026 Log

**Sources:**
- page 1 — `collected-docs/src/PXL_20260910_180224777.jpg` (primary),
  `…180311619.jpg` (duplicate re-shoot, angled)
- page 2 — `collected-docs/src/PXL_20260910_180230890.jpg` (primary),
  `…180314998.jpg` (duplicate re-shoot, angled)
- page 3 — `collected-docs/src/PXL_20260910_180319215.jpg`

**Type:** printed Word document (`TL Spring 2026 Log.docx`, seen in doc 03b), bulleted
monthly narrative
**Legibility:** high on pages 1–2; page 3's printed text is clear, its handwritten
additions less so

---

## Page 1 — verbatim

> **Atallah Lab Spring 2026 Log**
>
> - January
>   - Fixed previous semester's code to replace gene names in each species annotation files
>     with D. melanogaster ortholog names
>   - Worked with Duy and Ayush, incorporating their work from the winter break
>     - Dataset #1 was produced using Ayush's edits to my old scripts
>       - Dataset in: CYP_Gene_Project/Spring26/Gff_Dataset#1
>       - Used NEW_Step_5_Replace_gff_Names_with_Dmelanogaster_1_9.py
>     - Dataset #2 was produced using Duy's scripts
>       - Dataset in CYP_Gene_Project/Spring/Gff_Dataset#2
>       - Used ReVamp_Final.py
>   - Made LBRN Poster for 24 January 2026 Meeting
> - February
>   - Began working to develop RepeatModeler2 procedure
>   - Attempted to replicate D. melanogaster TE library construction via RepeatModeler2 to
>     compare against Flynn et al paper results
> - March
>   - Developed pipeline for RepeatModeler2 -> RepeatMasker -> TFBS/Motif Analysis with Duy
>     and Charles
>     - RepeatModeler2
>       - Old: D:/CYP_Gene_Project/Dhakad_et_al_2025_Data_Analysis/12_species_genomes
>       - Main folder: CYP_Gene_Project/Spring26/Spring26RepeatModeler
>       - Shell scripting used to run RepeatModeler2 package for each species individually
>         - spinContainer.sh and runMasker.sh
>       - Generated folder for each species containing their genome file
>       - Once inside sh, used following commands:

Followed by a two-row boxed table:

```
BuildDatabase -name D_speciesname Species_genome_file.fa
RepeatModeler -database D_speciesname -threads 10 -LTRStruct
```

(`D_speciesname` and `Species_genome_file.fa` are italicised in the original — they are
placeholders.)

---

## Page 2 — verbatim

> - RepeatModeler2 runs could last anywhere from 8-26 hours, depending on the size of the
>   genome file
> - After completion, the new annotation file for that species ("_withDmelNames.gff") with
>   replaced D. melanogaster names for orthologs, was also placed in the folder ("For
>   RepeatMasker"), compressed, and sent to Duy/uploaded to OneDrive for RepeatMasker
>   processing
>
> - April & May
>   - Continued to develop pipeline and process data as analysis was completed
>   - Processed into individual folders, once uploaded to OneDrive (compressed, with gff)
>     for Duy, put into /For RepeatMasker
>   - Used various small scripts to clean up data and process into counts of relevant TEs
>   - Moved results from Duy and Charles into
>     D:/CYP_Gene_Proect/Spring26/RM2_RM_TFBS_Results
>     - excels (TEandTFdata.xls) for processed counts, others contain files for JBrowse for
>       D.melanogaster, D.sechellia, and D.simulans

(`CYP_Gene_Proect` is a typo in the original.)

---

## Page 3 — verbatim (printed portion)

> - *Drosophila melanogaster* standard
>   - Reran utilizing the same genome as Flynn et al paper, with the same parameters
>     (-LTRStruct, -srand 1570222393, -LTRMaxSeqLen 10000)
>   - Obtained 471 families
>   - Runtime: 12:39:21 (hh:mm:ss)
>   - Emailed corresponding authors of Flynn et al paper to inquire about any further
>     parameters used to obtain their total family count of 734
>     - Awaiting response
> - Due to backlog of RepeatModeler and processing of RepeatMasker files, I was not able to
>   get Charles any finished data for him to work on this week.

### Page 3 — handwritten additions

In black ink, mid-page, a four-item list:

```
annahassae
D mel
Simulans
Sechellia
```

In blue ink, lower left, two words that could not be read with confidence:

```
LSI maga   [?]
```

`annahassae` is *D. ananassae*. The blue annotation is illegible — it may be a name, a
note, or a signature. Do not guess at it.

### Page 3 — show-through

Page 3 is thin enough that the sheet behind it is faintly visible in mirror image. Several
`Families: <number>` lines and species names can be partly made out (`Drosophila
willistoni`, `Drosophila …`, values in the 400–1000 range, and further `Runtime:` lines in
`hh:mm:ss` form), which implies **a fourth log page exists listing per-species family
counts and runtimes**. That page was not photographed. [VERIFY — recover it if
per-species TE family counts are ever needed.]

---

## Notes

**People and ownership.** The log names five contributors and attributes specific artifacts:

| Person | Attributed work |
|---|---|
| (log author, i.e. Diljot Kaur — see doc 05) | Fixed the gene-renaming code; ran RepeatModeler2/RepeatMasker; kept this log; made the LBRN poster |
| Ayush | Winter-break edits to the author's older scripts → `NEW_Step_5_Replace_gff_Names_with_Dmelanogaster_1_9.py` → **Gff_Dataset#1** |
| Duy | `ReVamp_Final.py` → **Gff_Dataset#2**; co-developed the March pipeline; ran RepeatMasker processing |
| Charles | Co-developed the March pipeline; downstream RepeatMasker/TFBS result processing |
| Terry | Custom scripts (named in doc 05, role not detailed) |

**Two gene-renaming datasets exist, by two authors, months apart.** Nothing in the log says
which supersedes which. The notebook (doc 02) points its Step 1 at **Gff_Dataset#2**, so
that is the one in active use as of August 2026.

**The 8–26 hour figure is the load-bearing fact in this whole archive.** It is why the
committed `repeat-modeler-automation/` exists at all, and it explains every design choice
in `worker.sh`: if a genome takes a day, you cannot babysit it, you must survive a reboot
without losing the run, and a clean shutdown must leave the genome retryable rather than
marked failed. The observed 45-hour run in doc 03c suggests the upper bound is optimistic
when `-LTRStruct` is on.

**The handoff was OneDrive, not a shared filesystem.** Annotation GFFs were renamed to
`*_withDmelNames.gff`, dropped in a `For RepeatMasker` folder, zipped, and uploaded for a
collaborator to collect. This is the origin of `analysis-pipeline/OneDrive_1_9-1-2026.zip`
and of the doubled ` 1 1` filename suffixes discussed in doc 03a. It also means there was
never a single machine on which the whole pipeline ran end to end.

**The Flynn et al. benchmark is unresolved and material.** Same genome, same stated
parameters, **471 families against a published 734** — a 36% shortfall. The authors were
emailed; no response is recorded. Until that is closed out, per-species family counts from
this pipeline should be treated as a lower bound, not a measurement. Note also that
`-srand` is not a documented RepeatModeler flag as transcribed; it may be version-specific
or a transcription error. [VERIFY against `RepeatModeler --help` in the actual image.]
