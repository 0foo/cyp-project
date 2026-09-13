# Stage 4 — The comparison

**Scripts:** `analysis-pipeline/compare_te_cyp_exposure.py`, `…_cncc.py`, `…_xenobiotic.py`

## What they do

Read the combined GFF3 for every species, count TEs per Cyp gene, split the species into
high- and low-insecticide-exposure groups, and test whether the two groups differ.

Output is a CSV, a markdown report, and a bar chart.

## Three scripts, one difference

They are the same analysis run on three different sets of genes:

| Script | Genes tested | Why |
|---|---|---|
| `compare_te_cyp_exposure.py` | **every** Cyp gene | the broad test — most statistical power |
| `compare_te_cyp_cncc.py` | Cyp genes near a **CncC binding site** | the ones actually under detox regulation |
| `compare_te_cyp_xenobiotic.py` | a **hand-curated list** of known resistance genes | e.g. *Cyp6g1* — the strongest prior evidence |

Broad to narrow. The first has the most genes and the least specificity; the third has a
handful of genes and the clearest biological rationale.

`cncc` and `xenobiotic` both `import compare_te_cyp_exposure` for the parsing and
statistics, so **all three files have to sit in the same directory**.

## Configuration

One INI file, shared by all three. One section per species:

```ini
[d_suzukii]
gff      = combined_cyp_annotation_suzukii.gff3
exposure = high

[d_sechellia]
gff      = combined_cyp_annotation_sechellia.gff3
exposure = low
```

`exposure` must be exactly `high` or `low`.

There's an optional third setting you'll need in one specific case:

```ini
gene_name_pattern = ^Cyp
```

Use it if a species' GFF3 is a *whole-genome* annotation rather than one already narrowed to
Cyp genes. Without it, thousands of irrelevant genes get counted and that species looks
artificially TE-poor. The script warns you if it sees more than 500 genes and no pattern set.

## How to run them

```bash
python compare_te_cyp_exposure.py \
    --config te_cyp_species_config.ini \
    --output-csv te_cyp_summary.csv \
    --output-report te_cyp_report.md \
    --per-gene-csv te_cyp_per_gene.csv

python compare_te_cyp_cncc.py --config te_cyp_species_config.ini

python compare_te_cyp_xenobiotic.py \
    --config te_cyp_species_config.ini \
    --gene-list xenobiotic_resistance_cyp_genes.txt
```

No dependencies beyond the standard library. `matplotlib` is used for the chart if present
and skipped silently if not.

> **Before you run anything:** the committed filenames have stray suffixes
> (`compare_te_cyp_exposure 1 1.py`). The imports can't resolve against those. Rename all
> three to drop the ` 1 1` first.

## What the statistics are

Two tests on the pooled gene table:

- **Fisher's exact test** — does having *any* TE depend on exposure group?
- **Mann-Whitney U** — does the *number* of TEs per gene differ between groups?

Plus a chi-square and a Welch's t-test reported alongside as familiar cross-checks. All
five are implemented from scratch in pure Python — no scipy, no numpy — and cross-validated
against a second, independently-coded implementation every single run. If that check fails,
the script refuses to report results at all.

You can run just the validation:

```bash
python compare_te_cyp_exposure.py --self-test
```

## Two things the reports will tell you, and you should listen

**"Pooling genes across species is pseudoreplication."** The test treats each gene as an
independent data point. They aren't — genes in one species share that species' entire
evolutionary history. A quirk of one genome's TE landscape can look exactly like an
exposure effect. Every report says this, unprompted, in its caveats section.

**A p-value of 1 might mean nothing at all.** If every Cyp gene in every species has at
least one nearby TE, then the yes/no table has no variation left in it and Fisher's test
returns 1 by construction. That's not evidence of no effect — it's the test having nothing
to work with. The report detects this and tells you to read the Mann-Whitney result
instead, which is comparing *counts* and still has signal.

## The bootstrap, and why five species is the problem

There's a third analysis in each report: resample whole species, with replacement, 10,000
times, and see how often high-exposure comes out ahead.

Here's why it's there. With 5 species split 3 against 2, a proper species-level test has
exactly C(5,3) = 10 possible arrangements. The smallest p-value it could ever produce is
1/10 = **0.10**. It can never reach 0.05, no matter how large the real effect is.

So the pipeline's tendency to report "inconclusive" is very likely a **ceiling imposed by
the number of species**, not a statement about the biology. The bootstrap sidesteps the
pass/fail question and reports something more honest: *"83% of resamples showed higher TE
burden in high-exposure species."* That's a direction with a confidence attached, which is
about as much as five species can support.

More species would fix this. Nothing else will.

---

**More detail:** [`docs/deep/04-comparison-scripts.md`](../deep/04-comparison-scripts.md)
and [`docs/deep/05-statistics.md`](../deep/05-statistics.md)
· **Diagram:** [`docs/diagrams/04-comparison-flow.md`](../diagrams/04-comparison-flow.md)
