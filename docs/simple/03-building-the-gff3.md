# Stage 3 — Building the combined annotation

**Script:** `analysis-pipeline/build_tfbs_te_gff.py`

## What it does

Takes three files for one species and merges them into a single annotation file that a
genome browser can open and the comparison scripts can read.

```
TE-hits table  ─┐
annotation GFF ─┼──►  combined.gff3
genome FASTA   ─┘
```

The output contains, all sorted together by position:

- **genes** — the Cyp genes, with their transcript and exon structure
- **introns** — worked out from the gaps between exons
- **TEs** — every transposable element found near one of those genes
- **TF binding sites** — predicted regulatory switches (see below)

## The interesting part: predicted binding sites

A transcription factor is a protein that latches onto a specific short DNA sequence to turn
a gene up or down. Those sequences are catalogued: **JASPAR** is the standard public
database of them.

This script downloads the JASPAR insect collection, then uses a tool called **FIMO** to scan
for matches in two places:

1. each gene's **promoter** (default: 1,000 bp before the start, 200 bp after)
2. each **TE**, plus 50 bp of surrounding context

The second one is the point. If a TE has landed near a Cyp gene and *carries a binding site
inside it*, that's a concrete mechanism for the TE changing the gene's expression — not just
proximity.

### The one motif JASPAR doesn't have

There's a protein called **CncC** which, paired with Maf-S, is the master switch for
detoxification in insects. Poison the fly, CncC turns on, Cyp genes fire up. For this
project it is *the* most relevant transcription factor there is.

JASPAR's insect collection doesn't contain it. Not under CncC, not Nrf2, not cnc, not Maf-S
— the 2026 release has 129 motifs and none of them is this one.

So the script builds the motif itself, from the consensus sequence published in the
literature, and splices it into the file FIMO scans. Hits from it are tagged differently in
the output (`FIMO/literature-ARE` rather than `FIMO/JASPAR`) so you can always tell which
kind of hit you're looking at.

That distinction matters, and the script is careful about it: a JASPAR motif is fitted to
real experimental binding data, while this one is hand-built from a published consensus
string. Treat its hits as *candidates worth following up*, not confirmed binding events.

## How to run it

The simplest form — three files, nothing else:

```bash
python build_tfbs_te_gff.py \
    --te-file D_suzukiiGenesAffectedByTE.txt \
    --gff dsuzukii_annotation.gff3 \
    --fasta dsuzukii_genome.fa
```

Everything else auto-detects. It finds FIMO (or Docker), downloads and caches JASPAR,
derives the output filename, and indexes the result for JBrowse if it can.

Doing several species? Put each one in a section of an INI file:

```bash
python build_tfbs_te_gff.py --config species_config.ini --species suzukii
```

Any flag you pass on the command line still overrides the file.

## What you need installed

**Nothing, for the basic merge** — it's pure Python standard library, including the FASTA
random-access reader, which is written from scratch specifically to avoid needing samtools
or pyfaidx.

**For the binding-site scan** you need FIMO, from the MEME Suite:

```bash
conda install -c bioconda meme        # easiest
```

Or let it use Docker, which it'll try first anyway. Or skip the scan entirely with
`--skip-tfbs`.

**For JBrowse indexing**, `bgzip` and `tabix` from htslib — again optional, again with a
Docker fallback.

## If a dependency is missing

It warns and carries on. You get a valid GFF3 either way; it just won't have the parts that
needed the missing tool.

> **But watch out for this.** A GFF3 built without FIMO contains **zero binding-site
> records**. Feed that into `compare_te_cyp_cncc.py` and it'll report zero CncC-proximal
> genes for that species — which looks like a finding and is actually just "we never
> scanned". The cncc script detects this case and labels it a data gap, but only if you
> read the warning.

## What you get

| File | What it's for |
|---|---|
| `<name>_combined.gff3` | everything, merged and sorted |
| `<name>_combined.transposable_elements.gff3` | TEs only — load as a second JBrowse track so you can colour them separately |
| `.gff3.gz` + `.gff3.gz.tbi` | the indexed versions, if bgzip/tabix were available |

## What happens next

The combined GFF3 goes into [stage 4](04-the-comparisons.md), and into JBrowse if you want
to look at it.

---

**More detail:** [`docs/deep/03-build-tfbs-te-gff.md`](../deep/03-build-tfbs-te-gff.md)
· **Diagram:** [`docs/diagrams/03-gff3-build.md`](../diagrams/03-gff3-build.md)
