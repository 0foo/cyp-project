# In-depth documentation

Written for someone who has to modify, debug or extend this code — not for someone deciding
whether to use it. For that, start with [`docs/simple/`](../simple/).

| Doc | Covers |
|---|---|
| [01-repeat-modeler-automation.md](01-repeat-modeler-automation.md) | `worker.sh`, `rm-manager.sh`, `rmodeler.conf` — concurrency, crash recovery, signal handling, container flags |
| [02-te-locating-scripts.md](02-te-locating-scripts.md) | `repeatOpp.py`, `Locate_TE.py`, `CleanAnnasse.py` — line by line, with the bugs |
| [03-build-tfbs-te-gff.md](03-build-tfbs-te-gff.md) | `build_tfbs_te_gff.py` — all six stages, the FASTA indexer, the CncC motif, GFF3 emission |
| `04-comparison-scripts.md` | the three `compare_te_cyp_*` scripts — parsing, filtering, report construction — **not yet written** |
| `05-statistics.md` | every test implemented, why it was chosen, how it is validated, and what the design cannot answer — **not yet written** |
| `06-data-formats.md` | every file format the pipeline reads or writes, with real examples — **not yet written** |
| `07-provenance-and-history.md` | how this code came to look the way it does, sourced from the archive photographs — **not yet written** |

Pipeline-level material that these per-script documents defer to lives in
[`docs/pipeline/`](../pipeline/): [`03-data-contracts.md`](../pipeline/detailed/03-data-contracts.md)
covers the file formats, and
[`04-gaps-and-provenance.md`](../pipeline/detailed/04-gaps-and-provenance.md) covers provenance
and the known defects.

## Conventions

- Line references are `file.py:123` and point at the files as committed, **including the
  ` 1` / ` 1 1` filename suffixes**.
- Where behaviour is inferred rather than read directly from code, it says so.
- Known defects are called out in place rather than collected at the end, so you meet them
  where you'd hit them.
