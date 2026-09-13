# Stage 2 — Which Cyp genes have TEs nearby?

**Folder:** `pipeline-scripts-output/`

## What it does

You arrive at this stage with two files per species:

- an **annotation** listing every gene and where it sits
- a **RepeatMasker output** listing every repeat and where it sits

Three short Python scripts turn those into a single table: *this Cyp gene, this TE, these
coordinates*. Run in order, they are:

```
repeatOpp.py     →  keep only the Cyp genes
Locate_TE.py     →  find TEs within 3,000 bp of one
CleanAnnasse.py  →  tidy the gene name column
```

Each is 30–40 lines. Together they are the conceptual heart of the project, and they're
short enough to read in five minutes.

## 1. `repeatOpp.py` — narrow to Cyp genes

An annotation file has every gene in the genome — 17,000-odd for a fruit fly. You want
roughly 90 of them.

The script reads a list of Cyp gene names and keeps only annotation rows that mention one.

**In:** annotation GFF + `Reg_Gene_Full.txt` (the Cyp name list)
**Out:** `filtered.gff`

## 2. `Locate_TE.py` — the actual overlap test

For every Cyp gene, widen its span by 3,000 bp on each side, then scan the entire
RepeatMasker file for repeats that fall inside that window and sit on the same sequence.

That ±3 kb padding is the definition of "near" for this whole project. It's meant to catch
promoter-region insertions — which is where an element like *Accord* has to land to change
a gene's expression.

**In:** `filtered.gff` + the RepeatMasker `.out` file
**Out:** `GenesAffectedByTEs.txt`

> **Fair warning: this is slow.** It re-scans every repeat in the genome for every gene.
> That's ~90 genes × ~1 million repeats. Minutes, not seconds. For 90 genes it doesn't
> matter; don't reuse the approach at genome scale.

## 3. `CleanAnnasse.py` — fix the gene column

Step 2 copies the gene's entire annotation blob into column 2, which looks like this:

```
Name=Cyp12e1;ID=gene-G00000000064;Name_old=LOC6500252;dbxref=GeneID:6500252;gbkey=Gene;…
```

Three hundred characters where you wanted seven. This script swaps it for the bare symbol:

```
NC_057927.1	Cyp12e1	   13   28.7  1.4  4.5  NC_057927.1    846413   846481 …
```

Column 1 is the sequence, column 2 is the gene, everything after is RepeatMasker's own
output verbatim. **That format is what stage 3 expects**, so this step isn't cosmetic.

**In:** `GenesAffectedByTEs.txt` + `Reg_Gene_Full.txt`
**Out:** `DAnasse_TE_Cyp.txt`

## How to run it

You can't, not as committed. All three scripts have paths like this hardcoded at the top:

```python
cypGene = "C:/Users/User/Documents/BioAtallah/RepeatMasker/RepeatOpp/filtered.gff"
```

That isn't an oversight — it's how they were designed to be used. The lab notebook
([`OCR docs/02`](../../OCR%20docs/02-lab-notebook-pipeline-page.md)) spells out the ritual:
open the script in VS Code, paste a path onto the highlighted line, fix the slashes, save,
click run. Three times, once per path, for each species.

To run them now, edit the paths at the top of each file — or take ten minutes and convert
them to `argparse`. [The deep doc](../deep/02-te-locating-scripts.md) suggests exactly how.

## What's actually in this folder

More than just the scripts — it's the only place in the repository with **real data**:

| | |
|---|---|
| `DA_Files/` | *D. ananassae* inputs: annotation, RepeatMasker output, Cyp gene lists |
| `filtered.gff`, `GenesAffectedByTEs.txt`, `DAnasse_TE_Cyp.txt` | that species, worked all the way through |
| `AnalysisForAll/output/` | **29 species**, finished TE-hits tables |

The *D. ananassae* chain is genuinely useful: you can open the three files side by side and
see exactly what each script did. When the code is this terse, the worked example is the
better specification.

## What happens next

`DAnasse_TE_Cyp.txt` (and its 29 siblings) become the `--te-hits` input to
[stage 3](03-building-the-gff3.md).

---

**More detail:** [`docs/deep/02-te-locating-scripts.md`](../deep/02-te-locating-scripts.md)
· **Diagram:** [`docs/diagrams/05-data-lineage.md`](../diagrams/05-data-lineage.md)
