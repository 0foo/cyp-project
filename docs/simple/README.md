# The project in five minutes

## The question

Fruit flies get sprayed with insecticide. Some species — the ones that live on crops — get
sprayed a lot. Others, living on wild fruit on remote islands, essentially never do.

Insects break down insecticides using a family of enzymes called **cytochrome P450s**, or
**Cyp genes** for short. Roughly: more Cyp activity, more resistance.

**Transposable elements** ("TEs", or jumping genes) are stretches of DNA that copy
themselves around a genome. When one lands in or near a gene, it can change how much that
gene is expressed — sometimes dramatically. The textbook case is *Cyp6g1* in *D.
melanogaster*: an element called *Accord* inserted into its promoter, the gene got
over-expressed, and the fly became DDT-resistant. That happened in the wild, and it spread
worldwide.

So the question is: **do heavily-sprayed species carry more TEs in and around their Cyp
genes than lightly-sprayed ones?**

## How you would answer it

You need, for each species, a list of every Cyp gene and every TE sitting in or near one.
Then you compare the two groups.

Getting that list is the hard part, and it takes four stages:

| Stage | What it does | Where |
|---|---|---|
| **1** | Find every repeat family in a genome | [`repeat-modeler-automation/`](01-repeat-libraries.md) |
| **2** | Work out which Cyp genes have TEs nearby | [`pipeline-scripts-output/`](02-finding-tes-near-genes.md) |
| **3** | Merge genes + TEs + regulatory motifs into one annotation file | [`analysis-pipeline/`](03-building-the-gff3.md) |
| **4** | Run the actual comparison and report a verdict | [`analysis-pipeline/`](04-the-comparisons.md) |

## Why it's four stages and not one script

Because stage 1 takes **8 to 26 hours per genome**, and there are dozens of genomes.

That single fact shapes everything. You can't sit and watch it. You can't lose a day's work
to a reboot. You need several genomes running at once without them tripping over each
other. So stage 1 is a small piece of crash-tolerant infrastructure rather than a script —
which is why it looks so different from the rest of the project.

Stages 3 and 4 are fast (seconds to minutes) and are ordinary analysis code.

## The honest state of things

Two things are worth knowing before you dig in.

**There's a hole in the middle.** Between stage 1 and stage 2, two steps have to happen that
have no code here: running RepeatMasker, and labelling each species' genes with standard *D.
melanogaster* names. Those were done by scripts that were never committed. If you're
starting from raw genomes, you will get through stage 1 and then stop.

**Five species is not many.** The comparison pools individual genes to get enough
observations to test, and then says so, loudly, in every report it writes — because genes
within one species aren't really independent of each other. With only five species there's
no statistically clean way around this. The code handles it about as well as it can be
handled, and is candid about the limits.

## Where everything is

```
repeat-modeler-automation/   stage 1 — two shell scripts + a config file
pipeline-scripts-output/     stage 2 — three short Python scripts, plus real data
analysis-pipeline/           stages 3 and 4 — four larger Python scripts
collected-docs/              photos of the original lab notebooks and write-ups
OCR docs/                    those photos, transcribed
docs/                        this documentation
```

## Next

- **Just want to run it?** Each simple page has a "how to run it" section.
- **Want the detail?** [`docs/deep/`](../deep/) covers every script line by line.
- **Want the picture?** [`docs/diagrams/`](../diagrams/) has the flow charts.
