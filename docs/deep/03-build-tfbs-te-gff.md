# `build_tfbs_te_gff.py` in depth

1,800 lines, standard library only. Merges a TE-hits table, a genome annotation and a genome
FASTA into one sorted GFF3 carrying genes, transcripts, exons, introns, transposable
elements and predicted transcription-factor binding sites.

Committed as `analysis-pipeline/build_tfbs_te_gff 1.py`.

The module docstring (lines 2–129) is genuinely good and doubles as the `--help` epilog.
This document covers structure, algorithms and consequences rather than restating it.

---

## Stage 1 — `parse_te_hits` (lines 258–337)

Input line shape: `<seqid> TAB <gene symbol> TAB <RepeatMasker .out fields, whitespace>`.

Split on tab first (max 3 fields effectively), then re-join everything after the second tab
and split on whitespace. Requires ≥14 RepeatMasker fields; warns and skips otherwise.

Field extraction, with the ones deliberately ignored:

| Index | Used as | Note |
|---|---|---|
| 0–3 | `sw_score`, `pct_div`, `pct_del`, `pct_ins` | |
| 4 | — | query seqid, **ignored** — column 1 already has it |
| 5, 6 | `start`, `end` | swapped if reversed (line 311) |
| 7 | — | bases left in query, ignored |
| 8 | `strand` | `C` → `-`, anything else → `+` |
| 9, 10 | `repeat_name`, `repeat_class` | |
| 11–13 | `rep_pos` tuple | via `_strip_parens` |
| 14 | `rm_id` | falls back to `f"L{lineno}"` |
| 15 | `overlaps_other` | `True` if `*` |

`_strip_parens` (line 250) removes the parentheses RepeatMasker wraps some numeric fields in
(`(18868207)`) and a trailing `*`.

### De-duplication

```python
key = (r["seqid"], r["gene"], r["start"], r["end"], r["repeat_name"], r["strand"])
seen.setdefault(key, r)
```

An `OrderedDict`, so first occurrence wins and input order is preserved. The comment says
"this input format commonly repeats identical rows 2-3x".

That is true, and [`02-te-locating-scripts.md`](02-te-locating-scripts.md) explains why: a
missing `break` in `repeatOpp.py` emits each gene row once per matching symbol. The
committed `DAnasse_TE_Cyp.txt` is 900 lines, 465 unique. This de-duplication is what keeps
the corruption from reaching the GFF3.

**Output:** TE records, plus `sorted({t["gene"] for t in te_records})` — the target symbol
set that drives everything downstream.

---

## Stage 2 — `parse_annotation_gff3` (lines 422–564)

**Three full passes** over the annotation file. Deliberate: one pass would require holding
the whole annotation in memory, and these files are large.

```
pass 1  gene features matching a target symbol
pass 2  mRNA / transcript / primary_transcript whose Parent is one of those genes
pass 3  exon features whose Parent is one of those mRNAs
```

### Attribute parsing

`_gff3_line_iter` (line 362) uses `split("\t", 8)` with **maxsplit=8**, not a plain split.
Real-world GFF3 exports — especially ones that have been text-processed — contain literal
tabs inside free-text attribute values (`model_evidence` notes, `Dbxref` lists). GFF3
guarantees exactly nine columns with attributes last, so everything after the eighth tab is
the attributes field. Also strips `\r` for CRLF files.

### Merged paralog loci

`_attr_tokens` (line 396) yields every comma-separated token across
`ID`, `gene`, `gene_name`, `Name`, `locus_tag`. This handles annotations where several
paralogs share one locus record:

```
ID=Cyp4e2,Cyp4e3,Cyp4e1
```

Child `mRNA`/`exon` features then reuse that same comma-joined string as their `Parent`, so
registration and matching both proceed **token by token**.

`mrna_id_to_symbols` is a `defaultdict(set)` rather than a 1:1 dict specifically so one
physical transcript shared by several merged paralogs contributes its exons to all of them.

This is the correct handling of a problem that
[`CleanAnnasse.py` gets wrong two stages earlier](02-te-locating-scripts.md#3-cleanannassepy)
— by the time this code runs, merged loci have often already been collapsed to one symbol
upstream.

### The ID fallback

Lines 460–465. Some annotations use an opaque `ID` (`gene-G00000000064`) with the symbol
only in `Name`/`gene`/`gene_name`. If the raw ID matched nothing itself, it is registered
pointing at `next(iter(matched_symbols))` so `Parent` linkage still resolves.

> `next(iter(...))` on a **set** — with multiple matches the choice is arbitrary and not
> reproducible across runs. Rare, and only affects which symbol an opaque-ID gene's
> transcripts attach to, but it is non-determinism in a pipeline that is otherwise careful.

### Representative transcript selection

```python
def _mrna_key(mid):
    return (len(mrna_exons.get(mid, [])), mrna_records[mid]["end"] - mrna_records[mid]["start"])
best_mid = max(mids, key=_mrna_key)
```

Most exons, tie-broken by longest span. One flattened model per gene keeps the
gene/exon/intron/strand structure unambiguous for display, rather than merging exons across
every isoform.

It is a display choice, not a biological one. If a downstream question depends on isoform
structure, this is where that information is discarded.

### Intron derivation

Exons are sorted by start and de-duplicated on `(seqid, start, end, strand)`. Introns are
the gaps:

```python
gap_start = exons[i]["end"] + 1
gap_end   = exons[i + 1]["start"] - 1
if gap_end >= gap_start: …
```

Zero-length and negative gaps (overlapping exons) are skipped.

---

## Stage 3 — Scan regions (lines 571–636)

### Promoter windows — strand-aware

```python
if gene_rec["strand"] == "-":
    tss = gene_rec["end"];  start = max(1, tss - downstream); end = tss + upstream
else:
    tss = gene_rec["start"]; start = max(1, tss - upstream);  end = tss + downstream
```

GFF3 coordinates always run left-to-right on the plus strand regardless of gene
orientation, so "the start of the gene record" is only the TSS for plus-strand genes. For
minus-strand genes the TSS is at the **higher** coordinate and "upstream" means increasing
coordinates.

Getting this wrong would scan the 3' end of every minus-strand gene — roughly half of them
— and is the single most common coordinate bug in this kind of code. It is handled
correctly here.

> Note the inconsistency with Stage 2, where `Locate_TE.py` pads symmetrically and is not
> strand-aware. The two stages use different notions of "near the promoter".

Defaults: 1000 bp upstream, 200 bp downstream. Start clamped to ≥ 1.

### TE windows

`compute_te_region` pads each TE by `--te-flank` (default 50 bp) so FIMO sees some context —
motifs can straddle the edge of a RepeatMasker call.

### De-duplication

Regions are keyed on `(seqid, start, end)`; identical windows from different genes merge and
accumulate a `genes` set. Each gets a `region_id` of the form `region_<n>`, which is both
the FASTA header and FIMO's `sequence_name`, and therefore the join key for remapping.

---

## Stage 4a — Sequence extraction

### The built-in FASTA indexer (lines 649–728)

A dependency-free reimplementation of samtools-style `faidx` random access, kept in memory
rather than written to disk.

**Why it works.** Every wrapped line of a FASTA record has the same number of bases except
the last. So four numbers per sequence — start byte offset, total length, bases per line,
bytes per line — let you compute the byte offset of any base directly.

```python
index[seqid] = (seq_start_offset, seq_len, line_bases, line_bytes)
```

`line_bytes` minus `line_bases` is the line terminator width, which handles `\n` and `\r\n`
without special-casing.

Lookup (`fetch_fasta_region`, line 699):

```python
start_line     = start0 // line_bases
start_line_pos = start0 %  line_bases
byte_offset    = seq_start_offset + start_line * line_bytes + start_line_pos
length_to_read = n_bases + (n_bases // line_bases + 2) * (line_bytes - line_bases)
```

Seek, read a generous over-estimate covering embedded newlines, strip them, trim to exactly
`n_bases`. The `+ 2` is slack for partial lines at both ends.

The docstring states it was validated byte-for-byte against a real 140 MB repeat-masked dm6
FASTA with plain `>NC_004354.4` headers.

**Caveat.** It assumes uniform line width within a record. That is true of every FASTA
produced by standard tools. A hand-edited or concatenated file with ragged line lengths
would return silently wrong sequence — no checksum, no error. If you ever suspect this, spot
check a region against `samtools faidx`.

It re-`open()`s the file per region rather than holding a handle. Irrelevant at these
volumes.

### NCBI fallback (lines 761–783)

`efetch` by accession and coordinate range, `time.sleep(0.35)` between calls (~3 req/s, the
unauthenticated E-utils limit). `--ncbi-api-key` raises it; `--ncbi-email` is politeness.

Failures warn and skip — a partial scan set, not an abort.

> Sequential and rate-limited: hundreds of regions take minutes to tens of minutes. Only
> works if your seqids are resolvable NCBI accessions.

Selection is implicit: `args.sequence_source or ("fasta" if args.genome_fasta else "ncbi")`.

---

## Stage 4b — Motifs

### JASPAR retrieval (lines 803–837)

Downloads `JASPAR<release>_CORE_insects_non-redundant_pfms_meme.txt` from
`jaspar.elixir.no`, into a **persistent** cache directory (default `./jaspar_cache`,
overridable). The same release is valid for every species, so it is fetched once ever. A
download failure raises with manual-download instructions naming the exact expected path.

### The CncC:Maf-S ARE motif (lines 840–913)

The most interesting design decision in the file, and the one carrying the most scientific
weight.

**The problem.** CncC (Cap-n-Collar isoform C) paired with Maf-S is the master regulator of
Cyp-mediated xenobiotic and insecticide detoxification in insects — the single most relevant
transcription factor to this project's hypothesis. JASPAR's insect collection does not
contain it. The comment records the check: the 2026 CORE insects non-redundant release has
129 motifs, none of them CncC, Nrf2, cnc or Maf-S.

**The response.** Build the PFM from the published consensus and splice it into the same
MEME file FIMO scans, reusing the promoter and TE windows already built.

```
consensus: TMAnnRTGAYnnnGCRwwww     (IUPAC)
```

The antioxidant response element (ARE) / Maf recognition element (MARE). Sourced to Veraksa
et al. 2000 for Cnc:Maf-S, and to Misra, Horner, Lam & Thummel, *Genes Dev* 2011;25(17):
1796-806 (doi:10.1101/gad.17280911) for it being necessary and sufficient for
xenobiotic-inducible *Cyp6a2* transcription.

**Construction.** Defined IUPAC positions get 0.85 probability, two-fold ambiguous positions
split 0.45/0.45, `N` is uniform 0.25.

```python
"A": (0.85, 0.05, 0.05, 0.05),
"M": (0.45, 0.45, 0.05, 0.05),   # A or C
"N": (0.25, 0.25, 0.25, 0.25),
```

`add_cncc_maf_are_motif` writes the combined file into `work_dir`, never modifying the
cached JASPAR file in place.

**The caveat, stated by the code itself.** This is a hand-built consensus PFM, *not* an
empirically-fit PWM from ChIP-seq or SELEX the way JASPAR motifs are. The real element is
known to tolerate substantial sequence variability. Hits are candidates worth follow-up, not
observed binding.

That caveat is carried into the data, not just the comments — see the emission rules below.
On by default (`include_cncc_maf_motif: True`); `--no-cncc-maf-motif` disables it.

---

## Stage 4c — FIMO

`run_fimo` (line 928) invokes the local binary with `--oc`, `--thresh`, `--verbosity 1`.
`run_fimo_docker` (line 953) does the same inside `memesuite/memesuite`, which expects the
working directory bind-mounted at `/home/meme` — so the motif file and scan FASTA are copied
into `work_dir` if they are not already under it.

Default threshold 1e-4.

`parse_fimo_tsv` (line 1000) reads the header row, then stops at the first row whose field
count differs — FIMO appends trailing comment and blank lines.

### Remapping (lines 1021–1049)

```python
genome_start = region["start"] + local_start - 1
genome_end   = region["start"] + local_stop  - 1
```

FIMO reports 1-based coordinates local to each extracted window; `region["start"]` is the
1-based genome coordinate of that window's first base. The `- 1` converts between the two
1-based frames. Hits whose `sequence_name` doesn't resolve to a known region are dropped.

The remapped hit carries `genes` — every gene associated with that window.

> Because promoter and TE windows are de-duplicated and can serve several genes, one FIMO
> hit can be attributed to several genes. `compare_te_cyp_cncc.py` reads that comma-joined
> list back out and counts every named gene as CncC-proximal.

---

## Stage 5 — GFF3 emission (lines 1056–1328)

### Escaping

`_gff3_escape` (line 1056) percent-encodes `;` `=` `,` and replaces tabs with a space, so
free-text values cannot be misparsed as extra attributes.

> Applied to values, not to keys, and not to the `matched_sequence` field
> (`build_tfbs_te_gff 1.py:1229`) — which is DNA and therefore safe in practice.

### Feature types and their attributes

| Type | `source` | Key attributes |
|---|---|---|
| `gene` | annotation's own | `ID`, `Name=<symbol>`, `gene_biotype`, plus `Dbxref`/`Note`/`locus_tag`/`gene_synonym`/`cyt_map` where present |
| `mRNA` | annotation's own | `ID`, `Parent=<gene id>`, `Name=<symbol>-RA`, `gene` |
| `exon` | annotation's own | `ID=exon-<symbol>-<n>`, `Parent`, `gene` |
| `intron` | annotation's own | `ID=intron-<symbol>-<n>`, `Parent`, `gene` |
| `mobile_genetic_element` | `RepeatMasker` | `ID=TE_<n>`, `Name=<repeat>`, `repeat_class`, `pct_div/del/ins`, **`Description=Within range of <gene>`** |
| `TF_binding_site` | `FIMO/JASPAR` **or** `FIMO/literature-ARE` | `ID=TFBS_<n>`, `Name`, `jaspar_matrix_id` **or** `motif_source_id`, `pvalue`, `qvalue`, `matched_sequence`, `Description=…near <genes>` |

`_extract_gene_annotation_attrs` (line 1072) reads keys **case-insensitively** — real
annotations vary (`dbxref` vs GFF3's reserved `Dbxref`) — and only emits what is present.
Gnomon-predicted *D. suzukii* genes have `Dbxref`/`gene_synonym` but no `description`;
RefSeq-curated *D. melanogaster* genes have all of them.

### Two attributes downstream code depends on

**`Description=Within range of <gene>`** is the TE→gene link.
`compare_te_cyp_exposure.py` reads it with a regex and never recomputes overlap from
coordinates. Change this string and every comparison silently reports zero TEs.

**`motif_source_id=CncC_Maf_ARE`** is how the literature motif is distinguished from JASPAR
hits. Literature hits get a different `source` column, a different attribute key
(`motif_source_id` rather than `jaspar_matrix_id`), and a `Description` that spells out the
caveat:

> "…literature consensus motif (Veraksa 2000; Misra et al. 2011 Genes Dev), not an empirical
> JASPAR PWM; candidate site, not experimentally validated at this locus"

The provenance distinction is carried in the data, so it survives into JBrowse and into any
downstream reader. `compare_te_cyp_cncc.py` keys on exactly that attribute.

### Sorting and headers

Body lines accumulate as `(seqid, start, line)` and sort on the first two — the order tabix
requires. One `##sequence-region` line per seqid, giving the min/max coordinates *used by
features*, not true chromosome lengths. Browsers don't require the real length here.

### The split TE track

`write_te_only_gff3` (line 1292) writes `<output>.transposable_elements.gff3` alongside the
combined file. Rationale: in one JBrowse track, TEs blend into the same rendering and colour
as everything else. A separate file means a separate track with its own colour. On by
default.

---

## Stage 6 — Indexing (lines 1341–1438)

`bgzip -f -k` then `tabix -f -p gff`, locally or in a biocontainers htslib image. The output
is already sorted by `(seqid, start)`, so no re-sort is needed.

If neither engine is available it warns, **prints the exact commands to run by hand**, and
returns `None` — the un-indexed GFF3 is still valid and already written.

---

## Dependency resolution

Three resolvers, same philosophy, opposite preferences:

| | forced on | forced off | auto |
|---|---|---|---|
| `resolve_fimo_engine` | Docker, no fallback | local `fimo`, no fallback | **Docker first**, then local |
| `resolve_bgzip_engine` | Docker, no fallback | local, no fallback | **local first**, then Docker |

FIMO prefers Docker because compiling MEME Suite natively on Windows is painful and MEME's
own docs recommend Docker or WSL there. bgzip prefers local because htslib is small and
usually already present, so pulling an image would be slower.

The tri-state is expressed as `True` / `False` / `None` on one argparse dest, with paired
`--x` / `--no-x` flags.

### The failure mode that matters

A run with no FIMO engine:

```
[warn] no fimo engine available (Docker: …; local fimo: …)
[warn] continuing without TFBS scanning (genes/exons/TEs will still be written)
```

…**exits 0** and writes a valid GFF3 with **zero `TF_binding_site` records**.

That file then flows into `compare_te_cyp_cncc.py`, which reports zero CncC-proximal genes
for that species. The cncc script detects and labels this (it counts `n_tfbs_total`
separately precisely for this reason — see
[`04-comparison-scripts.md`](04-comparison-scripts.md)), but only a reader who notices the
banner is protected.

> **Suggestion:** if you extend this script, write a `##pipeline-tfbs-scanned false` pragma
> into the GFF3 header when scanning was skipped. Right now "we didn't scan" and "we scanned
> and found nothing" are indistinguishable from the file alone.

---

## Argument resolution

`ARG_DEFAULTS` (line 1511) holds every optional setting's built-in fallback in one dict
rather than scattered across `default=` kwargs, so the three-way precedence is a single
auditable merge:

```
explicit CLI flag  >  --config [species] section  >  ARG_DEFAULTS
```

Most argparse flags default to `None`, which is what lets `resolve_args` distinguish "not
passed" from "passed a default-looking value" (lines 1547–1552). `None` in `ARG_DEFAULTS`
means "auto-derived at runtime", not "off".

Config keys are typed by membership in `CONFIG_PATH_KEYS` / `CONFIG_BOOL_KEYS` /
`CONFIG_INT_KEYS` / `CONFIG_FLOAT_KEYS`; unknown keys pass through as strings. Path-typed
keys resolve **relative to the config file's directory**, so a config and its data travel
together. Hyphens in keys are normalised to underscores.

Only `--te-hits` and `--annotation-gff` are truly required, and the check happens after the
config merge. Output defaults to `<te-hits stem>_combined.gff3`.

---

## Observations

**Three passes over the annotation** is a deliberate memory/IO trade. For a large annotation
and many species this is the dominant cost of stage 2. If it ever matters, one pass building
`type → records` dicts would work at the cost of holding the relevant subset in memory.

**`next(iter(set))`** at line 465 is non-deterministic across runs. Worth making
deterministic (`sorted(...)[0]`) even though it rarely fires.

**Broad `except Exception`** around the JASPAR fetch (line 1756) and the FIMO run (line
1776). Intentional — both are "warn and degrade" paths — but they will also swallow
programming errors during development. `--keep-work-dir` is your friend when debugging.

**No validation that TE seqids exist in the annotation.** They are matched independently, so
a species whose TE table and annotation use different naming conventions (`NC_004354.4` vs
`chr3R`) produces genes with no TEs and TEs with no genes, silently. The FASTA path does
warn about unknown seqids (line 755); the annotation path does not.
