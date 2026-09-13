# The three comparisons

## Shared skeleton, three gene filters

All three scripts read the same combined GFF3 files, through the same config file, and run
the same statistics. The **only** thing that differs is which Cyp genes survive into the
pooled table.

```mermaid
flowchart TD
    CFG["te_cyp_species_config.ini<br/>one [section] per species<br/>gff= exposure=high|low<br/>gene_name_pattern= (optional)"]
    CFG --> LOAD["load_species_config"]

    LOAD --> PARSE["parse_species_gff3<br/>per species"]
    GFF[("combined GFF3<br/>per species")] --> PARSE

    PARSE --> P1["gene features → symbol, length_bp<br/>(filtered by gene_name_pattern)"]
    PARSE --> P2["rows carrying<br/>Description='Within range of X'<br/>→ te_count per symbol"]

    P1 --> ROWS[["per-gene rows<br/>symbol, length_bp, te_count"]]
    P2 --> ROWS

    ROWS --> FILT{"which script?"}

    FILT -->|exposure| FA["no filter<br/>every Cyp gene"]
    FILT -->|cncc| FB["keep genes named in a<br/>TF_binding_site whose<br/>motif_source_id=CncC_Maf_ARE"]
    FILT -->|xenobiotic| FC["keep genes in --gene-list<br/>case-insensitive exact match"]

    FA --> POOL["pooled gene-level table"]
    FB --> POOL
    FC --> POOL

    POOL --> ST1["Fisher's exact, two-tailed<br/>2x2: exposure x has-TE"]
    POOL --> ST2["chi-square, Yates-corrected<br/>(cross-check only)"]
    POOL --> ST3["Mann-Whitney U<br/>on per-gene TE counts"]
    POOL --> ST4["Welch's t<br/>(familiar reference point)"]
    POOL --> ST5["species-cluster bootstrap<br/>10,000 resamples of WHOLE SPECIES"]

    ST1 --> OUT
    ST2 --> OUT
    ST3 --> OUT
    ST4 --> OUT
    ST5 --> OUT

    OUT[["per-species CSV<br/>markdown report<br/>optional per-gene CSV<br/>optional PNG bar chart"]]

    style FB fill:#fff6ee
    style FC fill:#f0ffee
```

## Import relationship

```mermaid
flowchart LR
    E["compare_te_cyp_exposure.py"]
    C["compare_te_cyp_cncc.py"]
    X["compare_te_cyp_xenobiotic.py"]

    C -->|"import compare_te_cyp_exposure as base"| E
    X -->|"import compare_te_cyp_exposure as base"| E

    E -.- N1["_gff3_feature_iter<br/>parse_species_gff3<br/>load_species_config<br/>compute_species_summary<br/>run_pooled_tests<br/>bootstrap_species_cluster_ci<br/>format_bootstrap_section<br/>validate_stats<br/>maybe_write_plot"]

    style N1 fill:#f5f5f5,stroke-dasharray: 3 3
```

> The three files as committed are named `compare_te_cyp_exposure 1 1.py`,
> `compare_te_cyp_cncc 1 1.py` and `compare_te_cyp_xenobiotic 1 1.py`. **The imports cannot
> resolve against those names.** Rename them to drop the suffix before running anything.

## Verdict logic

Both the significance calls and the direction call feed one decision. Direction is judged
from **mean per-gene TE burden**, never from the 2×2 table — because that table can be
fully saturated and would then cross-multiply to a meaningless direction.

```mermaid
flowchart TD
    A["high_mean_te vs low_mean_te"] --> B{"equal?"}
    B -->|yes| V0["<b>Inconclusive (tied)</b><br/>no directional signal"]
    B -->|"high > low"| C["direction supports"]
    B -->|"high < low"| D["direction contradicts"]

    C --> E{"Fisher p &lt; alpha<br/>AND<br/>Mann-Whitney p &lt; alpha?"}
    E -->|both| V1["<b>Supports the hypothesis</b>"]
    E -->|one| V2["<b>Partially supports</b><br/>suggestive, not conclusive"]
    E -->|neither| V4

    D --> F{"either test<br/>significant?"}
    F -->|yes| V3["<b>Contradicts the hypothesis</b><br/>significant in the OPPOSITE direction"]
    F -->|no| V4["<b>Inconclusive</b><br/>no clear support either way"]

    style V1 fill:#e8f5e9,stroke:#388e3c
    style V2 fill:#f1f8e9,stroke:#689f38
    style V3 fill:#ffebee,stroke:#c62828
    style V0 fill:#f5f5f5
    style V4 fill:#f5f5f5
```

### The saturated-table case

```mermaid
flowchart LR
    A{"high_no_te == 0<br/>AND<br/>low_no_te == 0?"} -->|yes| B["every gene in every species<br/>has at least one TE"]
    B --> C["the presence/absence table<br/>has NO VARIANCE to test"]
    C --> D["Fisher p = 1 and chi-square p = 1<br/>are ARTIFACTS of saturation,<br/>not evidence of no effect"]
    D --> E["report prints an explicit note;<br/>Mann-Whitney on TE COUNTS<br/>is the test carrying signal"]

    style D fill:#fff8e1,stroke:#f9a825
```

This is not a hypothetical. Cyp genes in *Drosophila* are frequently TE-adjacent, and a
±3 kb proximity rule (Stage 2) catches simple repeats and low-complexity regions as well as
real transposons — so "does this gene have ≥1 TE?" saturates easily. The count-based test
is the one that discriminates.

## Why the bootstrap exists

```mermaid
flowchart TD
    A["5 species, split 3 high / 2 low"]
    A --> B["exact species-level test:<br/>C(5,3) = 10 possible assignments"]
    B --> C["smallest achievable p = 1/10 = 0.10"]
    C --> D["can NEVER clear alpha = 0.05<br/>regardless of true effect size"]

    A --> E["pooled per-gene test:<br/>plenty of power…"]
    E --> F["…but pseudoreplicated —<br/>genes in one species are not independent"]

    D --> G["<b>species-cluster bootstrap</b><br/>resample WHOLE SPECIES with replacement,<br/>within each exposure group"]
    F --> G
    G --> H["species stays the unit of replication,<br/>but you get a smooth interval<br/>instead of a pass/fail call"]
    H --> I[["CI for difference (high - low)<br/>CI for ratio (high / low)<br/>% of resamples where high &gt; low"]]

    style D fill:#ffebee,stroke:#c62828
    style F fill:#ffebee,stroke:#c62828
    style I fill:#e8f5e9,stroke:#388e3c
```

The "inconclusive" verdicts this pipeline tends to produce are very likely a consequence of
that 0.10 floor, not of a small effect. The bootstrap reports a **directional confidence
statement** ("83.4% of 10,000 species-resamples showed higher TE/gene in high-exposure
species") which is honest about what five species can and cannot tell you.

## CncC data gap versus real zero

```mermaid
flowchart TD
    A["count TF_binding_site records<br/>in this species' GFF3"] --> B{"n_tfbs_total"}
    B -->|"== 0"| C["<b>DATA GAP</b><br/>this species was never run<br/>through FIMO motif scanning"]
    B -->|"&gt; 0"| D{"any with<br/>motif_source_id=CncC_Maf_ARE?"}
    D -->|no| E["genuine: no CncC sites called<br/>near this species' Cyp genes"]
    D -->|yes| F["collect genes from<br/>Description='…near g1,g2,…'"]

    C --> G["report prints a<br/>'Data gap, not biology' banner<br/>and flags the row '(no TFBS data)'"]
    E --> H["counted as a real zero"]
    F --> I["restrict per-gene rows to those genes"]

    style C fill:#fff8e1,stroke:#f9a825
    style G fill:#fff8e1,stroke:#f9a825
```

Distinguishing these two is the reason `parse_cncc_associated_genes` returns
`n_tfbs_total` alongside the gene set. Without that count, "0 CncC-proximal genes" would be
indistinguishable from "we never looked".
