# CYP Gene Project Pipeline — Simple Overview

## What this pipeline is for

The lab wants to know: **do "jumping genes" (transposable elements, or TEs) sit inside or near
CYP genes in fruit flies, and could they be carrying regulatory switches (transcription factor
binding sites, TFBS) that affect how those genes turn on and off?** Answering this for one genome
is doable by hand. Answering it for 300+ *Drosophila* genomes is not — so the lab built a chain of
scripts that does the same set of steps to every genome, one at a time.

Think of it as an assembly line. Each station takes the output of the previous station as its
input, does one job, and hands off a new file to the next station.

## The five stations

**1. Find the repeats — RepeatModeler**
Feed in one species' raw genome (a FASTA file). A tool called RepeatModeler chews on it for
8–26 hours and produces a "TE library" — a list of every repeat/transposon family it found in
that genome (`consensi.fa.classified`).

**2. Mark them on the map — RepeatMasker**
Take that TE library and the same genome, and run RepeatMasker. This produces a file that says,
for every TE, exactly where it sits along the chromosome.

**3. Connect TEs to genes — Python scripts in VS Code**
A set of Python scripts takes the RepeatMasker results and the gene annotation file (GFF) and
lines them up — figuring out which genes are near or overlapped by which TEs, and relabeling
genes with their fruit-fly-standard (*D. melanogaster*) names so results are comparable across
species. Someone runs this by hand in VS Code: paste in the right file paths, save, click run —
three times, once per input file needed. The output is a per-species text file listing genes
affected by TEs.

**4. Look at it — JBrowse**
The genome and its new annotations get loaded into JBrowse, a genome browser, so a person can
visually check where the TEs, genes, and binding sites line up rather than reading raw text
files.

**5. Check for regulatory switches — TFBS/motif scripts**
A last set of scripts compares the TE locations against a database of known transcription factor
binding motifs (JASPAR) to see whether TEs sitting near CYP genes could plausibly be introducing
or disrupting regulatory switches. Results land in a spreadsheet (`TEandTFdata.xls`).

## Why it's built this way

- **One genome can take over a day to process**, so the heavy lifting (RepeatModeler/RepeatMasker)
  runs unattended in a Docker container while people work on other species in parallel.
- **File paths have to be hand-edited for each species** in the Python/VS Code step — this is the
  most manual and error-prone part of the pipeline (see the detailed doc for exactly what has to
  be changed).
- **Multiple people (Diljot, Duy, Ayush, Charles, Terry) contributed different scripts** at
  different times, so naming isn't fully consistent (e.g., two "GFF datasets" exist, made by two
  different scripts, months apart). This is normal for an active research pipeline, not a design
  goal — see the detailed doc for which one is current.

## One-paragraph version

Raw fly genome → RepeatModeler finds the repetitive/transposon DNA and builds a library →
RepeatMasker uses that library to mark exactly where those repeats sit in the genome → Python
scripts cross-reference those locations against the gene map to see which genes are near or
inside a transposon, relabeling everything with standard fly gene names → the result is loaded
into JBrowse so people can see it → a final round of scripts checks whether the transposons carry
known regulatory DNA motifs that could affect nearby CYP genes.
