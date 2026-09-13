# Pipeline documentation

This directory documents **the pipeline as a whole** — the path a *Drosophila* genome takes
from a raw FASTA file to a statistical verdict about transposable elements and Cyp genes.

It deliberately does *not* document individual scripts. Where a stage is implemented by a
script, this documentation says what the stage consumes, what it produces, and what it
guarantees to the next stage. Line-by-line coverage of the scripts themselves belongs in
[`docs/deep/`](../deep/) and is a separate job.

## The two tiers

**[`simple/`](simple/) — read this first.** Three short documents with flow charts. Enough
to understand what the pipeline is for, what the stages are, and what a single genome's
journey through it looks like. No code, no file formats.

| Doc | Covers |
|---|---|
| [01-what-it-does.md](simple/01-what-it-does.md) | The research question and the whole pipeline on one flow chart |
| [02-the-pipeline-in-six-stages.md](simple/02-the-pipeline-in-six-stages.md) | Each stage in plain language, with its own small flow chart |
| [03-following-one-species.md](simple/03-following-one-species.md) | One real species end to end, with the real filenames and real numbers |

**[`detailed/`](detailed/) — the reference.** For someone who has to run, modify, repair or
extend the pipeline.

| Doc | Covers |
|---|---|
| [01-architecture.md](detailed/01-architecture.md) | Why the pipeline is shaped this way; the two eras it was built in; where the halves join |
| [02-stage-reference.md](detailed/02-stage-reference.md) | Every stage: exact commands, parameters, runtimes, outputs, failure modes |
| [03-data-contracts.md](detailed/03-data-contracts.md) | Every file format passed between stages, with real examples from this repository |
| [04-gaps-and-provenance.md](detailed/04-gaps-and-provenance.md) | What is missing, what is broken, what is unresolved — and the sources for all of it |

## Where the facts come from

Three kinds of source, and this documentation keeps them distinct:

- **Code in this repository** — `repeat-modeler-automation/`, `pipeline-scripts-output/`,
  `analysis-pipeline/`. Statements sourced here are checkable.
- **Real data in this repository** — the 29 completed species outputs and the *D. ananassae*
  worked example under `pipeline-scripts-output/`. Numbers quoted in these documents were
  measured from those files.
- **The archive photographs**, transcribed in [`OCR docs/`](../../OCR%20docs/). These are the
  only record of the stages that were never committed. Anything sourced from them is marked
  with the transcription document it came from, e.g. *(OCR doc 02)*.

Where a stage exists only in the photographs and has no code here, the documentation says so
rather than describing it as though you could run it.
