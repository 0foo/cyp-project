# In-depth documentation

Written for someone who has to modify, debug or extend this code — not for someone deciding
whether to use it. For that, start with [`docs/simple/`](../simple/).

| Doc | Covers |
|---|---|
| [01-repeat-modeler-automation.md](01-repeat-modeler-automation.md) | `worker.sh`, `rm-manager.sh`, `rmodeler.conf` — concurrency, crash recovery, signal handling, container flags |
| [02-te-locating-scripts.md](02-te-locating-scripts.md) | `repeatOpp.py`, `Locate_TE.py`, `CleanAnnasse.py` — line by line, with the bugs |
| [03-build-tfbs-te-gff.md](03-build-tfbs-te-gff.md) | `build_tfbs_te_gff.py` — all six stages, the FASTA indexer, the CncC motif, GFF3 emission |
| [04-comparison-scripts.md](04-comparison-scripts.md) | the three `compare_te_cyp_*` scripts — parsing, filtering, the two restricted variants, report construction |
| [05-statistics.md](05-statistics.md) | every test implemented, why it was chosen, how it is validated, and what the design cannot answer |

Two further documents were once planned here and are deliberately **not** written, because
they would duplicate pipeline-level material that already exists:

- *data formats* → [`pipeline/detailed/03-data-contracts.md`](../pipeline/detailed/03-data-contracts.md)
- *provenance and history* → [`pipeline/detailed/04-gaps-and-provenance.md`](../pipeline/detailed/04-gaps-and-provenance.md)

Formats and provenance are properties of the pipeline, not of any one script, so they belong
there rather than here.

## Conventions

- Line references are `file.py:123` and point at the files as committed, **including the
  ` 1` / ` 1 1` filename suffixes**.
- Where behaviour is inferred rather than read directly from code, it says so.
- Known defects are called out in place rather than collected at the end, so you meet them
  where you'd hit them.
