# 06 — Handwritten sketch: the file handoff chain

**Source:** `collected-docs/src/PXL_20260910_180342882.jpg`
**Type:** handwritten pencil sketch on a lined legal pad, drawn as a serpentine
(boustrophedon) flow with hand-drawn arrows connecting each step to the next
**Legibility:** moderate — the writing is small and light, several words are approximate

## Verbatim, following the arrows

```
Dhakad files    →    spinContainer.sh
                          |
    ┌─────────────────────┘
    ↓
→  Run_Maske.sh                    [i.e. runMasker.sh]
     classified file
     final_final.gff                [?]
                          |
    ┌─────────────────────┘
    ↓
→  masker.
   .out file that goes into duys step 2
   step 1 gets .gff
                          |
    ┌─────────────────────┘
    ↓
→  .txt
```

`Run_Maske.sh` is written without the `r` — the file is `runMasker.sh` everywhere else in
the archive. `final_final.gff` is the least certain reading on the page [?]; it may be a
specific filename or a generic label for "the finished GFF".

## Notes

This is the whole pipeline compressed onto one page, drawn as a data-flow rather than a
procedure. It is the only source in the set that shows the **handoff boundaries** rather
than the steps, and it resolves something none of the other documents state outright.

Read as a chain:

| Stage | Artifact produced | Consumed by |
|---|---|---|
| Dhakad files (genome FASTAs) | — | `spinContainer.sh` |
| `spinContainer.sh` → RepeatModeler | `consensi.fa.classified` ("classified file") | `runMasker.sh` |
| `runMasker.sh` → RepeatMasker | `.out` file | "duy's step 2" |
| the annotation side | `.gff` | "step 1" |
| Python scripts | `.txt` | downstream |

The two lines that matter are:

> `.out file that goes into duys step 2`
> `step 1 gets .gff`

These name the **two inputs of the manual VS Code procedure** and say which script line
each goes on — matching notebook doc 02 exactly, where Step 1 pastes the GFF path and
Step 2 pastes the RepeatMasker path. The sketch is the mental model; doc 02 is the
keystroke-level version of the same thing.

That two-input, one-output shape is preserved in the committed code:
`pipeline-scripts-output/Locate_TE.py` opens exactly a `.gff` and a `.rm.fna.out` and writes
exactly a `.txt`. The sketch is a picture of that script's signature, drawn before the
script had a stable name.

"Dhakad files" as the entry point corroborates the JBrowse genome path in doc 02 — raw
genome FASTAs really were still being read out of the older
`Dhakad_et_al_2025_Data_Analysis` tree even after `Spring26/` became the working directory
for everything else.
