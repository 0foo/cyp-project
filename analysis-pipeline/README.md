# atallah-pipeline

Scripts for testing whether Drosophila species with greater insecticide
exposure show more transposable element (TE) insertions in/near Cytochrome
P450 (Cyp) genes. Pipeline runs per-species, then compares across species.

## Pipeline order

```
 (per species, NOT included here — see "What's missing" below)
   genome FASTA
       -> gene annotation GFF3          (e.g. NCBI RefSeq, or BRAKER/MAKER)
       -> RepeatModeler + RepeatMasker  -> "genes affected by TE" table

                         |
                         v
1. build_tfbs_te_gff.py      per-species TE-hits table + annotation GFF3 + genome FASTA
                              -> one combined GFF3 (genes/exons/introns, TEs, predicted
                                 TF binding sites via JASPAR + MEME's fimo)
                         |
                         v
2. compare_te_cyp_exposure.py    combined GFF3s (all species) + config
                                  -> CSV + markdown report: TE burden vs. exposure group
                                     (Fisher's exact + Mann-Whitney U)
                         |
          +--------------+--------------+
          v                             v
3. compare_te_cyp_cncc.py      4. compare_te_cyp_xenobiotic.py
   same test, restricted to       same test, restricted to a literature-curated
   Cyp genes near a CncC:Maf-S    list of xenobiotic/insecticide-resistance
   antioxidant response motif     Cyp genes (e.g. Cyp6g1)
```

Scripts 3 and 4 both `import compare_te_cyp_exposure` for GFF3 parsing and
statistics, so all three must stay in the same directory.

### What's missing

These scripts do **not** start from a raw genome FASTA. `build_tfbs_te_gff.py`
only *parses* a pre-made RepeatMasker-style TE table and an existing gene
annotation GFF3 — it never runs gene annotation or RepeatModeler/RepeatMasker
itself. Those two artifacts have to be produced separately, per species,
before step 1 can run.

## 1. build_tfbs_te_gff.py

Builds the combined per-species GFF3 that everything downstream reads.

**Inputs**
- `--te-hits` (`--te-file`): RepeatMasker-derived "genes affected by TE"
  table (`<seqid> TAB <gene> TAB <RepeatMasker .out fields...>`)
- `--annotation-gff` (`--gff`): genome annotation GFF3 (gene/mRNA/exon)
- `--genome-fasta` (`--fasta`): genome FASTA, OR `--sequence-source ncbi`
  to fetch sequence windows from NCBI E-utils by accession instead

**Requires:** [MEME Suite](https://meme-suite.org) (`fimo`) on `PATH`, or
pass `--fimo-path`, or `--fimo-via-docker`. Use `--skip-tfbs` to skip motif
scanning entirely and just merge genes/exons/TEs.

```bash
python "build_tfbs_te_gff 1.py" \
    --te-file D_suzukiiGenesAffectedByTE.txt \
    --gff dsuzukii_annotation.gff3 \
    --fasta dsuzukii_genome.fa \
    --output combined_cyp_annotation.gff3
```

Multiple species can instead be defined as `[section]`s of one
`species_config.ini` (`te_hits=`, `annotation_gff=`, `genome_fasta=`, ...)
and selected with `--config species_config.ini --species suzukii`.

Optional `--bgzip-index` bgzip/tabix-indexes the output for loading into
JBrowse 2.

## 2. compare_te_cyp_exposure.py

Reads the combined GFF3 from step 1 for each species and tests whether TE
burden in Cyp genes correlates with exposure group.

**Config file** (`--config te_cyp_species_config.ini`), one `[section]` per
species:

```ini
[d_suzukii]
gff = combined_cyp_annotation_suzukii.gff3
exposure = high          ; must be "high" or "low"
gene_name_pattern = ^Cyp   ; optional, defaults to matching all `gene` records
```

```bash
python "compare_te_cyp_exposure 1 1.py" \
    --config te_cyp_species_config.ini \
    --output-csv te_cyp_summary.csv \
    --output-report te_cyp_report.md \
    --per-gene-csv te_cyp_per_gene.csv \
    --plot
```

Run `--self-test` to just cross-validate the stdlib-only Fisher's exact /
Mann-Whitney U implementations and exit.

**Caveat reported in the output:** pooling genes across species is
pseudoreplication (genes within a species aren't independent). A secondary,
purely descriptive species-level comparison is included but not treated as
a formal test.

## 3. compare_te_cyp_cncc.py

Same comparison as script 2, restricted to Cyp genes sitting near a
predicted CncC:Maf-S (Cap-n-Collar) antioxidant/xenobiotic response motif —
the master regulator of Cyp-mediated detoxification. Requires `TF_binding_site`
records in the GFF3, which only exist if step 1 was run *with* FIMO motif
scanning (not `--skip-tfbs`). Species with zero such records are reported as
a **data gap**, not a biological "no CncC sites" finding.

```bash
python "compare_te_cyp_cncc 1 1.py" --config te_cyp_species_config.ini --plot
```

## 4. compare_te_cyp_xenobiotic.py

Same comparison as script 2, restricted to a literature-curated gene list
(e.g. `Cyp6g1`, the classic Accord-TE-insertion DDT/neonicotinoid resistance
case) instead of every Cyp gene. Doesn't need `TF_binding_site` records, so
it works even for species run with `--skip-tfbs`.

```bash
python "compare_te_cyp_xenobiotic 1 1.py" \
    --config te_cyp_species_config.ini \
    --gene-list xenobiotic_resistance_cyp_genes.txt
```

The gene list is a plain-text file, one symbol per line, `# comment` allowed.
Matching is case-insensitive and exact — paralogs (e.g. `Cyp12d1-d` vs.
`Cyp12d1-p`) must be listed individually.

## Known gaps in this repo

- **No upstream annotation/repeat-masking step.** As noted above, the
  RepeatMasker table and annotation GFF3 that `build_tfbs_te_gff.py` needs
  are not produced by anything here.
- **Example config/list files referenced but not present.** All four
  scripts point to `species_config.example.ini`,
  `te_cyp_species_config.example.ini`, and
  `xenobiotic_resistance_cyp_genes.example.txt` for filled-in templates —
  none of these currently exist in this directory. You'll need to create
  your own following the formats documented above (or in each script's
  module docstring).
- Filenames currently have stray ` 1` / ` 1 1` suffixes (e.g.
  `build_tfbs_te_gff 1.py`) from how they were exported/zipped; rename to
  drop the suffixes if you want the plain import (`import
  compare_te_cyp_exposure`) used by scripts 3 and 4 to work without
  matching renames.
