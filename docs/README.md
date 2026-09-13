# Documentation

Start here.

## Start here

- **Just want to run something?** → [`commands.md`](commands.md). Every command in the project
  on one page, with what it does and what it leaves behind.
- **New to the project?** → [`pipeline/simple/01-what-it-does.md`](pipeline/simple/01-what-it-does.md).
  The research question, and the whole pipeline on one flow chart.

## The two views

Documentation here is organised along two axes: **how deep** (simple vs detailed) and **what
it describes** (the pipeline as a whole vs individual scripts).

| | The pipeline as a whole | Individual scripts |
|---|---|---|
| **Just the commands** | [`commands.md`](commands.md) | |
| **Quick overview, with flow charts** | [`pipeline/simple/`](pipeline/simple/) | [`simple/`](simple/) |
| **Detailed reference** | [`pipeline/detailed/`](pipeline/detailed/) | [`deep/`](deep/) |
| **Diagrams** | [`diagrams/`](diagrams/) | |

**[`pipeline/`](pipeline/) is the current focus and the most complete.** It documents the path
a genome takes from raw FASTA to statistical verdict: the six stages, what each consumes and
produces, the formats that join them, and what is missing.

**[`deep/`](deep/) covers individual scripts** line by line — the worker automation, the
TE-locating scripts, the GFF3 builder, the comparison scripts and the statistics.

**[`../OCR docs/`](../OCR%20docs/)** holds transcriptions of the seventeen archive photographs
that record the stages which were never committed to code. Pipeline documentation cites these
by number, e.g. *(OCR doc 04)*.

## The short version of what you will find

- The pipeline has **six stages**; one preparatory step (relabelling gene annotations with
  *D. melanogaster* ortholog names) still has no code in this repository.
- Stage 1 takes **8-26 hours per genome**, which is why it looks like infrastructure while
  everything else looks like scripts.
- Everything funnels through **one small file format** between stages 3 and 4 — that is the
  place to join the pipeline if you are starting from your own data.
- There is a list of **known defects and unresolved questions** in
  [`pipeline/detailed/04-gaps-and-provenance.md`](pipeline/detailed/04-gaps-and-provenance.md).
  Read it before quoting any number this pipeline produces.
