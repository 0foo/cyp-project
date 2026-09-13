# Flow charts

Mermaid diagrams. GitHub, GitLab and most Markdown previewers render these inline; VS Code
needs the *Markdown Preview Mermaid Support* extension.

| Diagram | Scope |
|---|---|
| [01-end-to-end.md](01-end-to-end.md) | Genome FASTA → published result. The whole project on one page, with the seam where it breaks in two. |
| [02-worker-concurrency.md](02-worker-concurrency.md) | How `worker.sh` claims work, and every state a genome can be in. |
| [03-gff3-build.md](03-gff3-build.md) | Inside `build_tfbs_te_gff.py`: the six stages and their fallbacks. |
| [04-comparison-flow.md](04-comparison-flow.md) | The three `compare_te_cyp_*` scripts and the statistics they share. |
| [05-data-lineage.md](05-data-lineage.md) | Which file becomes which, for every file committed to this repository. |
