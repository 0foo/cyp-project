# The three `compare_te_cyp_*` scripts in depth

| File | Lines | Restricts the gene set to |
|---|---|---|
| `compare_te_cyp_exposure 1 1.py` | 1186 | nothing — every Cyp gene |
| `compare_te_cyp_cncc 1 1.py` | 485 | Cyp genes near a predicted CncC:Maf-S site |
| `compare_te_cyp_xenobiotic 1 1.py` | 421 | a literature-curated gene list |

The statistics they share are covered separately in
[`05-statistics.md`](05-statistics.md). This document covers parsing, filtering, report
construction and the CLI.

> **They do not run as committed.** `compare_te_cyp_cncc.py` and `compare_te_cyp_xenobiotic.py`
> both do `import compare_te_cyp_exposure`, which cannot resolve against a module file named
> `compare_te_cyp_exposure 1 1.py`. Dropping the suffixes fixes it — verified: after renaming,
> both import cleanly and `--self-test` passes on all three.

---

## 1. Shape of the family

`compare_te_cyp_exposure.py` is the base. The other two **import it** rather than duplicating
its parsing and statistics:

```python
import compare_te_cyp_exposure as base
```

Each restricted script therefore consists of three things and nothing else:

1. a function that works out which genes survive its restriction,
2. a `build_*_report()` that mirrors `build_report()` but frames the numbers around that
   restriction,
3. a `main()` that calls the base parser, applies the filter, and hands the result to the base
   statistics.

That is a good structure — there is exactly one implementation of the GFF3 parser and one of
each test — but it does mean **all three must live in one directory** and the base module must
be importable under its plain name.

---

## 2. Parsing a species' GFF3

`parse_species_gff3()` (`compare_te_cyp_exposure 1 1.py:493-576`). One pass over the file,
building two things:

- `genes`: `symbol -> length_bp`, from `gene` features, keyed on the `Name=` attribute.
  Length is `end - start + 1`. A repeated symbol keeps the **longer** span rather than
  arbitrarily picking one.
- `te_counts_raw`: `symbol -> count`, from any row whose `Description` matches
  `Within range of (\S+)`.

Three decisions here are worth knowing about.

### TE-to-gene association is read, never recomputed

The link between a TE and a gene comes **entirely** from the
`Description=Within range of <symbol>` attribute that `build_tfbs_te_gff.py` stamps onto every
`mobile_genetic_element` record. No coordinates are compared at this stage.

The consequence is that **the ±3 kb containment rule from `Locate_TE.py` is already baked in**
by the time these scripts run, and cannot be adjusted here. Changing the window means re-running
stage 3 and stage 4.

### Matching on the attribute, not the feature type

```python
desc = attrs.get("Description", "")
m = _WITHIN_RANGE_RE.search(desc)
```

TE rows are identified by the `Description` text rather than by `ftype ==
"mobile_genetic_element"`. The comment explains why: some older, hand-built files carry the
same `Description` tag on rows with a blank or different type column. Matching the attribute
handles both, and is safe because ordinary `gene`/`mRNA`/`exon` records never carry that string
by coincidence.

The check is deliberately **not** an `elif` on the gene check above it, since one row could in
principle be both.

### `gene_name_pattern` exists for one specific failure

Optional per-species regex, matched with `.match()` (so anchored at the start) against `Name=`.
Without it, pointing the script at a **whole-genome** annotation rather than a Cyp-filtered one
would pull in ~17,000 genes for *D. melanogaster* against ~40-90 for every other species — and
that species would look dramatically TE-poor purely from the denominator.

`parse_species_gff3` returns `(rows, unmatched_te_genes, n_gene_rows_seen, n_gene_rows_kept)`.
The last two exist so the report can show how much the pattern filtered out, and
`unmatched_te_genes` lists symbols that TE records point at but which have no matching `gene`
record — a naming-drift diagnostic.

---

## 3. The config file

`load_species_config()` (`:584-644`). One `[section]` per species; `gff` and `exposure` are
required, `gene_name_pattern` optional. `exposure` must be exactly `high` or `low` after
lowercasing — anything else raises rather than being coerced.

Two details that will save you an afternoon:

- **Relative paths resolve against the config file's directory**, not the working directory, so
  a config and its data travel together.
- **One surrounding pair of quotes is stripped** (`_strip_quotes`, `:577-582`). `configparser`
  does not do this itself, and Windows paths with spaces — such as the ` 1 1` filenames in this
  very repository — are routinely quoted by editors. Without the strip, the quote character
  would become part of the path.

---

## 4. Per-species metrics

`compute_species_summary()` (`:646-662`). Seven numbers per species:

| Field | Definition |
|---|---|
| `n_cyp_genes` | count of gene rows kept |
| `n_genes_with_te` | how many have `te_count > 0` |
| `pct_genes_with_te` | the above as a percentage |
| `total_te_count` | sum of per-gene TE counts |
| `total_cyp_bp` | summed gene length |
| `te_per_kb` | `total_te_count / (total_cyp_bp / 1000)` |
| `te_per_gene` | `total_te_count / n_cyp_genes` |

The last two are the point of the exercise: a species with more, or longer, Cyp genes has more
sequence for a TE to land in and would otherwise look TE-rich for purely arithmetic reasons.

Every division is guarded against a zero denominator and returns `0.0` — so a species that
parsed to nothing produces zeroes rather than an exception. Worth remembering when reading a
report: a row of zeroes may mean "no TEs" or may mean "this file did not parse as expected".
The `n_gene_rows_seen` / `n_gene_rows_kept` figures in the report are what distinguish them.

---

## 5. The two restricted variants

### `compare_te_cyp_cncc.py`

`parse_cncc_associated_genes()` (`compare_te_cyp_cncc 1 1.py:94-134`) makes a second pass over
the same GFF3, looking only at `TF_binding_site` rows, and collects the gene symbols named in
`Description="…near <gene1>,<gene2>"`.

A hit counts as CncC if **either**:

```python
motif_source_id == "CncC_Maf_ARE"        # the literature motif's own tag
or re.search(r"\bcnc\b", Name, re.I)     # fallback
```

The primary test is unambiguous by construction: JASPAR hits carry `jaspar_matrix_id` instead,
so only the literature-derived motif ever sets `motif_source_id`. The `\bcnc\b` fallback exists
in case a future JASPAR release adds a genuine Cnc-family motif.

`restrict_to_cncc_genes()` (`:137-150`) then intersects those symbols with the species' known
gene rows and reports any that did not match.

**The data-gap distinction is the important part.** The function returns `n_tfbs_total`
alongside the CncC count specifically so the caller can tell apart:

- *this species has zero `TF_binding_site` records at all* → motif scanning was never run
  (`build_tfbs_te_gff.py --skip-tfbs`, or `fimo` unavailable). A **data gap**.
- *this species has TFBS records but none are CncC* → a genuine biological observation.

The report flags the first case explicitly. Without that split, a species processed with
`--skip-tfbs` would silently read as "no CncC sites near any Cyp gene", which is a conclusion
the data cannot support.

### `compare_te_cyp_xenobiotic.py`

`parse_gene_list()` (`compare_te_cyp_xenobiotic 1 1.py:73-95`) reads a plain-text file: one
symbol per line, `#` comments stripped, blanks ignored. It returns `UPPERCASE -> original case`
so matching is case-insensitive while the report can still print the symbol as written.

`restrict_to_gene_list()` (`:97-115`) filters on `symbol.upper() in targets` — **exact, not
substring**. Paralogs must be listed individually (`Cyp12d1-d` *and* `Cyp12d1-p`).

Note the inconsistency with stage 3: `repeatOpp.py` matches its gene list by *substring* against
the whole attribute column. The two ends of the pipeline disagree about what "on the list"
means.

The function also returns `missing_upper` — target genes not found at all in that species —
which is the practical diagnostic for cross-species naming drift, and is printed per species.

Unlike the CncC variant this needs no `TF_binding_site` records, so it works for every species
regardless of whether motif scanning ever ran.

---

## 6. Reports

`build_report()` (`compare_te_cyp_exposure 1 1.py:837-1033`) emits markdown containing the
per-species table, the 2×2 contingency table, both test results, the bootstrap section, the
species-level descriptive comparison, and the caveats. The two restricted scripts have their
own `build_*_report()` with the same skeleton plus their restriction-specific framing and
diagnostics.

**The caveats are generated, not optional.** Every report states the pseudoreplication problem
in plain language, and the CncC report states the data-gap distinction. Anyone extending these
scripts should keep that property: the limitation travels with the numbers rather than living
only in documentation someone may not read.

`maybe_write_plot()` (`:1035-1062`) is a bar plot, and degrades gracefully — if matplotlib is
absent it warns and continues rather than failing the run.

---

## 7. CLI

Shared by all three:

| Flag | Default |
|---|---|
| `--config` | *(required in practice)* |
| `--output-csv` | `te_cyp[_cncc\|_xenobiotic]_species_summary.csv` |
| `--per-gene-csv` | none — the pooled per-gene table the tests actually run on |
| `--output-report` | `te_cyp[_cncc\|_xenobiotic]_report.md` |
| `--alpha` | `0.05` |
| `--plot` / `--no-plot` | plotting on |
| `--plot-path` | `te_cyp[…]_by_species.png` |
| `--self-test` | run the statistics cross-validation and exit |

`compare_te_cyp_xenobiotic.py` adds `--gene-list`.

Note that `--plot` defaults to **true** (`action="store_true", default=True`), so the flag is
only meaningful as documentation; `--no-plot` is the one that changes behaviour.

---

## 8. Known issues

**The ` 1 1` suffixes break the imports.** Covered at the top. Two of three scripts do not run
as committed.

**The example config files do not exist.** All three reference
`te_cyp_species_config.example.ini`, and the xenobiotic script also references
`xenobiotic_resistance_cyp_genes.example.txt`. Neither is in the repository, and
`parse_gene_list` raises a `FileNotFoundError` that points at a file you cannot read. Formats
are documented in
[`../pipeline/detailed/03-data-contracts.md`](../pipeline/detailed/03-data-contracts.md).

**Repeat class is never consulted.** `parse_species_gff3` counts every row carrying a
`Within range of` description, regardless of its `repeat_class` attribute. In the committed
*D. ananassae* data about 69% of those rows are `Simple_repeat` or `Low_complexity` — not
transposable elements. See
[`../pipeline/detailed/04-gaps-and-provenance.md`](../pipeline/detailed/04-gaps-and-provenance.md).

**Five species is the real constraint.** Not a code defect, but it governs how the output should
be read — see [`05-statistics.md`](05-statistics.md).
