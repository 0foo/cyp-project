# `pipeline-scripts-output/` in depth

Three short scripts, ~110 lines total, run in sequence. They are the conceptual core of the
project and the least defensively written code in it. This document covers what each does,
and — because these scripts produced data that is committed here — what is demonstrably
wrong with them.

| Script | Lines | In → Out |
|---|---|---|
| `repeatOpp.py` | 37 | annotation GFF + Cyp name list → `filtered.gff` |
| `Locate_TE.py` | 41 | `filtered.gff` + RepeatMasker `.out` → `GenesAffectedByTEs.txt` |
| `CleanAnnasse.py` | 31 | `GenesAffectedByTEs.txt` + Cyp name list → `DAnasse_TE_Cyp.txt` |

All three take **no arguments**. Paths are module-scope string literals pointing at
`C:/Users/User/Documents/BioAtallah/…`. That is how they were meant to be used — see
[`docs/pipeline/detailed/04-gaps-and-provenance.md`](../pipeline/detailed/04-gaps-and-provenance.md).

---

## 1. `repeatOpp.py`

```python
import pandas as pd                      # never used

GFF   = "…/DROSOPHILA_ANANASSAE_final_withDmelNames.gff"
rgFile = "…/Reg_Gene_Full.txt"

with open(rgFile) as t:
    for gene in t:
        if gene.startswith('D'):
            continue
        regGene.append(gene.rstrip('\n'))

with open(GFF) as s:
    for line in s:
        if line.startswith("#"): continue
        fields = line.rstrip("\n").split("\t")
        for Rgene in regGene:
            if fields[2] == "gene" and Rgene in fields[8]:
                stripGFF.append(line)
```

Keeps annotation rows of type `gene` whose attribute column mentions any listed Cyp symbol.

### The `startswith('D')` filter

`Reg_Gene_Full.txt` is 96 lines: 92 Cyp symbols plus five ortholog identifiers of the form
`Dvir\GJ21722`, `Dmoj\GI21254`. The `D` test drops those.

It is blunt — it would also drop any Cyp symbol beginning with a capital `D` — but no such
symbol exists in these lists. Fine in practice, fragile by construction.

### Defect: rows are emitted once per matching name

There is **no `break`** after a match. A gene whose attribute column mentions *n* listed
symbols is appended *n* times.

This is not hypothetical. `filtered.gff` as committed:

```
166 lines total
 91 unique
```

**45% of the file is duplicate rows.** The cause is visible in the data — annotations that
merge tandem paralogs into one locus record:

```
Name=Cyp313a5,Cyp313a2,Cyp313a3,Cyp313a1;ID=gene-G00000000559;…
```

Four listed symbols in one attribute string, plus `Cyp313a` as a substring of all four, and
the row is written five times. 103 of the 166 rows carry a comma-separated `Name=`.

Those duplicates propagate: `GenesAffectedByTEs.txt` is 900 lines of which 521 are unique.

**Mitigated downstream, by accident.** `build_tfbs_te_gff.py:330-337` de-duplicates its
`--te-hits` input on `(seqid, gene, start, end, repeat_name, strand)`, and its comment says
"this input format commonly repeats identical rows" — the author observed the symptom
without tracing the cause. So the final GFF3 is not corrupted. But any count taken from
`filtered.gff` or `GenesAffectedByTEs.txt` directly is inflated.

**Fix:** add `break` after the append.

### Defect: substring matching

`Rgene in fields[8]` is a substring test against the whole attribute column, so it matches:

- **prefix collisions** — `Cyp4g1` matches `Name=Cyp4g15`. There are 13 such pairs in the
  92-symbol list: `Cyp4g1`/`Cyp4g15`, `Cyp4d2`/`Cyp4d20`/`Cyp4d21`, `Cyp6a2`/`Cyp6a20-23`,
  `Cyp4d1`/`Cyp4d14`, `Cyp313a`/`Cyp313a1-5`.
- **any attribute, not just the name** — `gene_synonym=` lists are long and contain historic
  symbols, so a gene can be kept because of a synonym rather than its name.

For `repeatOpp.py` this only over-collects (harmless for a filter whose job is to narrow to
Cyp genes). For `CleanAnnasse.py` the same flaw actually mislabels data — see below.

**Fix:** parse the attribute column into a dict and compare `attrs["Name"]` token by token
after splitting on commas.

### `import pandas as pd`

Unused. Removing it drops the script's only third-party dependency.

---

## 2. `Locate_TE.py`

```python
te_lines = [line.rstrip('\n') for line in te if line.strip()]

for gene in cyp:
    cypFields = gene.strip().split("\t")
    for ele in te_lines:
        eleFields = ele.split()
        if len(eleFields) <= 4: continue
        start = int(cypFields[3]) - 3000
        stop  = int(cypFields[4]) + 3000
        if cypFields[0] == eleFields[4] and (int(eleFields[6]) <= stop and int(eleFields[5]) >= start):
            out.write(f"{cypFields[0]}\t{cypFields[8]}\t{ele}\n")
```

For each Cyp gene, widen its span by 3,000 bp each way and emit every RepeatMasker hit on
the same sequence that overlaps that window.

### The ±3 kb window

This is **the operative definition of "near a gene"** for the entire project. Every TE count
in every downstream report traces back to it. It is not configurable, not documented
anywhere in the code, and not recorded in any output file.

`compare_te_cyp_exposure.py` is explicit that it inherits this rule without re-deriving it:

> "TE-to-gene assignment here is inherited as-is from the `Within range of <gene>`
> annotation already written by build_tfbs_te_gff.py (i.e. whatever flanking-distance /
> overlap rule that pipeline used) … this script does not re-derive or second-guess that
> call."

3 kb is a reasonable promoter-scale choice for *Drosophila*. The point is that it is a
scientific parameter hardcoded as a magic number two stages upstream of where it is
interpreted.

### The overlap test is correct

`te_end <= gene_stop AND te_start >= gene_start` — a containment test, not a general
overlap. A TE that straddles the window boundary is **excluded**. Whether that is intended
is unclear; standard interval overlap would be `te_start <= stop AND te_end >= start`.

Given 3 kb of padding on each side, the practical difference is small (only elements
crossing the outer edge of the padded window are affected), but it means "within 3 kb" is
really "entirely within 3 kb".

### Not strand-aware

The padding is symmetric. `build_tfbs_te_gff.py:571-592` later computes promoter windows
that *are* strand-aware — for a minus-strand gene, upstream means increasing coordinates.
The two stages therefore use different notions of "upstream" and the inconsistency is not
flagged anywhere.

### RepeatMasker field indices

`.out` files are whitespace-separated with a two-line header:

| Index | Field |
|---|---|
| 0–3 | SW score, % div, % del, % ins |
| **4** | **query sequence** ← matched against the GFF seqid |
| **5, 6** | **query begin, end** ← the interval test |
| 7 | bases left in query, parenthesised |
| 8 | strand (`+`, or `C` for complement) |
| 9, 10 | repeat name, class/family |
| 11–13 | position in repeat |
| 14 | RepeatMasker record ID |
| 15 | optional `*` |

The indices are right.

### The header lines survive, harmlessly

`te_lines` includes the two header rows (only the blank third line is dropped). Header line
1 splits to 14 tokens with `eleFields[4] == "query"`; line 2 gives `"sequence"`. Neither
ever equals a real seqid, so `cypFields[0] == eleFields[4]` is False and Python's `and`
short-circuits before `int(eleFields[6])` is reached.

It works by luck. `int("in")` would raise.

### Defect: the guard is too weak

`if len(eleFields) <= 4: continue` protects index 4, but the code then reads indices 5 and
6. A line with 5 or 6 tokens *and* a matching seqid raises `IndexError`. Should be `<= 6`.

### Defect: window recomputed inside the inner loop

`start` and `stop` depend only on `cypFields`, but are recomputed for every TE line —
roughly 90 genes × ~1 million lines = 90 million redundant `int()` calls and subtractions.
Hoisting them above the inner loop is a one-line change.

### Complexity

O(genes × te_lines) with no indexing. For ~90 genes against a fly genome's RepeatMasker
output this is minutes, which is why it was never a problem. Do not reuse the approach at
genome scale — sort both sides by `(seqid, start)` and sweep, or bucket TEs by seqid first.

### Column 2 is the whole attribute blob

`cypFields[8]` is GFF column 9. The output's second column is therefore ~300 characters of
`Name=…;ID=…;dbxref=…`. Fixing that is the next script's only job.

---

## 3. `CleanAnnasse.py`

```python
for name in nameList:
    if name in fields[1]:
        fields[1] = name
        break
```

Replaces the attribute blob with the first listed Cyp symbol found inside it.

Before:

```
NC_057927.1	Name=Cyp12e1;ID=gene-G00000000064;Name_old=LOC6500252;dbxref=…	   13   28.7 …
```

After:

```
NC_057927.1	Cyp12e1	   13   28.7  1.4  4.5  NC_057927.1    846413   846481 …
```

That second form is exactly what `build_tfbs_te_gff.py --te-hits` parses:
`<seqid> TAB <gene> TAB <RepeatMasker fields>`. This step is structural, not cosmetic.

### Defect: first substring match wins, and list order decides

Unlike `repeatOpp.py` this one *does* `break` — which makes the substring flaw worse, not
better, because now exactly one name is chosen and it may be the wrong one. The winner is
whichever colliding symbol appears **earlier in `Reg_Gene_Full.txt`**.

Working through the 13 collisions against the committed list order, five mislabel:

| Gene in the annotation | Labelled as | Why |
|---|---|---|
| `Cyp4g15` | **`Cyp4g1`** | `Cyp4g1` is at line 2, `Cyp4g15` at line 8 |
| `Cyp4d20` | **`Cyp4d2`** | line 31 beats line 47 |
| `Cyp4d21` | **`Cyp4d2`** | line 31 beats line 48 |
| `Cyp313a2`, `Cyp313a3`, `Cyp313a5` | **`Cyp313a`** | line 85 beats lines 86–88 |

The other eight collisions happen to be ordered safely (`Cyp6a22` precedes `Cyp6a2`, etc.).
**The correctness of this script depends on the sort order of a plain text file.**

### Defect: merged loci collapse to one paralog

Where the annotation packs several paralogs into one record, the `break` keeps only the
first listed. In the committed data:

```
Name=Cyp313a5,Cyp313a2,Cyp313a3,Cyp313a1;…   →   Cyp313a1
```

`Cyp313a1` is at line 84, ahead of `Cyp313a` at 85, so it wins — and **145 TE rows in
`DAnasse_TE_Cyp.txt` are attributed to `Cyp313a1`**, the single largest gene bucket in the
file. Those TEs belong to a four-paralog locus, not to one gene.

`build_tfbs_te_gff.py` handles merged loci properly — `_attr_tokens()` and
`_symbol_matches()` split comma-separated attribute values and register every token
(`build_tfbs_te_gff 1.py:396-419`). The handling is correct one stage too late: by the time
the TE-hits table is written, the paralogs have already been collapsed.

**Fix:** parse `Name=` out of the attribute string, split on commas, and emit one output row
per symbol (or pick deterministically and record which). Either way, stop searching for
substrings.

### Malformed lines pass through

```python
if len(fields) < 2:
    container.append(fields)
    continue
```

Short lines are kept verbatim rather than dropped. `build_tfbs_te_gff.py` will warn and skip
them (`[warn] te-hits line N: expected >=3 tab fields`), so nothing breaks; it just moves
the complaint downstream.

---

## 4. What the committed data tells you

`pipeline-scripts-output/` is the only place in the repository with real inputs *and* real
outputs, which makes it the best available specification of Stage 2 — you can diff the files
and see exactly what happened.

| Path | What it is |
|---|---|
| `DA_Files/DROSOPHILA_ANANASSAE_final_withDmelNames.gff` | annotation, Cyp symbols already substituted for `LOC…` IDs |
| `DA_Files/Drosophila_ananassae.GCF_017639315.1.rm.fna.out` | RepeatMasker output |
| `DA_Files/Cyp_{stable,unstable}_genes_Good_et_al_2014.txt` | 29 + 46 symbols, from Good et al. 2014 |
| `AnalysisForAll/Reg_Gene_Full.txt` | 96 lines: the merged list plus 5 ortholog IDs |
| `filtered.gff` | step 1 output (166 lines, 91 unique) |
| `GenesAffectedByTEs.txt` | step 2 output (900 lines, 521 unique) |
| `DAnasse_TE_Cyp.txt` | step 3 output (900 lines, 465 unique) |
| `AnalysisForAll/step1Temp.gff`, `step2GenesAffectedByTEs.txt` | the same two intermediates from the *D. melanogaster* batch run |
| `AnalysisForAll/output/*.txt` | **29 species**, finished TE-hits tables |

Note the unique count *drops* from 521 to 465 at step 3: collapsing paralog names merges
rows that were previously distinct.

`Cyp_stable` / `Cyp_unstable` refer to Good et al. 2014's classification of Cyp copy-number
stability across *Drosophila*. Both are merged for filtering; **no committed script uses the
distinction**, which is a loose end — it is plausibly a more interesting split than exposure
group.

---

## 5. If you are going to run these

The minimum viable modernisation, in rough order of value:

1. **`break` after the append in `repeatOpp.py`.** One line, removes 45% of the output.
2. **Replace substring matching with parsed `Name=` token comparison** in both
   `repeatOpp.py` and `CleanAnnasse.py`. Removes the mislabelling.
3. **Emit one row per paralog** for merged loci, instead of collapsing.
4. `argparse` instead of module-scope literals — three `add_argument` calls each.
5. Hoist the window computation out of `Locate_TE.py`'s inner loop; fix the guard to `<= 6`.
6. Make the ±3000 a named constant, then a flag, and write it into the output header.

Items 1–3 change results. Do them on a copy and diff against `DAnasse_TE_Cyp.txt` so you can
see exactly what moved.

---

**Diagram:** [`docs/diagrams/05-data-lineage.md`](../diagrams/05-data-lineage.md)
· **Formats:** [`docs/pipeline/detailed/03-data-contracts.md`](../pipeline/detailed/03-data-contracts.md)
