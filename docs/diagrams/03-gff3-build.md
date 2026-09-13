# Inside `build_tfbs_te_gff.py`

## The six stages

```mermaid
flowchart TD
    subgraph IN["inputs — only three are required"]
        A1["--te-hits<br/>D_species GenesAffectedByTE.txt"]
        A2["--annotation-gff<br/>genome annotation GFF3"]
        A3["--genome-fasta<br/>or --sequence-source ncbi"]
    end

    A1 --> B["<b>1. parse_te_hits</b><br/>split on TAB, then whitespace<br/>de-duplicate on<br/>(seqid, gene, start, end, name, strand)"]
    B --> B2[["TE records<br/>+ the set of Cyp symbols"]]

    A2 --> C["<b>2. parse_annotation_gff3</b><br/>three passes"]
    B2 --> C
    C --> C1["pass 1: gene features<br/>matching a target symbol"]
    C1 --> C2["pass 2: mRNA whose<br/>Parent is one of those"]
    C2 --> C3["pass 3: exons whose<br/>Parent is one of those mRNAs"]
    C3 --> C4["pick ONE representative transcript<br/>(most exons, tie-break longest span)<br/>derive introns from exon gaps"]

    C4 --> D["<b>3. build_scan_regions</b>"]
    B2 --> D
    D --> D1["promoter window<br/>TSS -upstream / +downstream<br/>strand-aware"]
    D --> D2["TE window<br/>TE +/- te-flank"]
    D1 --> D3[["de-duplicated regions,<br/>each with a region_id"]]
    D2 --> D3

    D3 --> E{"sequence source"}
    A3 --> E
    E -->|fasta| E1["built-in faidx-style indexer<br/>seek + read, no samtools"]
    E -->|ncbi| E2["E-utils efetch by accession<br/>0.35 s between calls"]
    E1 --> F[["scan_regions.fa"]]
    E2 --> F

    F --> G["<b>4. FIMO</b>"]
    G1["JASPAR CORE insects<br/>non-redundant, MEME format<br/>cached in ./jaspar_cache"] --> G
    G2["+ CncC:Maf-S ARE consensus<br/>hand-built PFM, appended"] --> G
    G --> H[["fimo.tsv<br/>window-local coordinates"]]

    H --> I["<b>5. remap + write</b><br/>genome_start = region.start + local_start - 1"]
    C4 --> I
    B2 --> I
    I --> J[["combined.gff3<br/>sorted by (seqid, start)"]]
    I --> J2[["…transposable_elements.gff3<br/>TE-only, own JBrowse track"]]

    J --> K["<b>6. bgzip + tabix</b><br/>optional"]
    J2 --> K
    K --> L[["gff3.gz + .gff3.gz.tbi<br/>JBrowse 2 GFF3Tabix"]]

    style G1 fill:#eef6ff
    style G2 fill:#fff6ee
```

## Engine auto-detection

Every optional dependency degrades rather than aborts. Three separate resolvers implement
the same philosophy:

```mermaid
flowchart TD
    subgraph FIMO["resolve_fimo_engine"]
        F0{"--fimo-via-docker"}
        F0 -->|"True (forced)"| F1{"docker present?"}
        F1 -->|yes| FD["docker"]
        F1 -->|no| FN["None"]
        F0 -->|"False (--no-fimo-docker)"| F2{"fimo on PATH?"}
        F2 -->|yes| FL["local fimo"]
        F2 -->|no| FN
        F0 -->|"None (auto)"| F3{"docker present?"}
        F3 -->|yes| FD
        F3 -->|no| F4{"fimo on PATH?"}
        F4 -->|yes| FL
        F4 -->|no| FN
    end

    FN --> FW["warn + continue<br/>genes/exons/TEs still written,<br/>zero TF_binding_site records"]

    style FN fill:#fff8e1,stroke:#f9a825
    style FW fill:#fff8e1,stroke:#f9a825
```

```mermaid
flowchart TD
    subgraph BG["resolve_bgzip_engine"]
        B0{"--bgzip-via-docker"}
        B0 -->|"None (auto)"| B1{"bgzip AND tabix<br/>on PATH?"}
        B1 -->|yes| BL["local<br/>(preferred: no image pull)"]
        B1 -->|no| B2{"docker present?"}
        B2 -->|yes| BD["docker htslib image"]
        B2 -->|no| BN["None"]
    end

    BN --> BW["warn, print the exact<br/>bgzip/tabix commands to run by hand,<br/>keep the un-indexed GFF3"]

    style BN fill:#fff8e1,stroke:#f9a825
    style BW fill:#fff8e1,stroke:#f9a825
```

Note the preference is **inverted** between the two: FIMO tries Docker *first* (compiling
MEME Suite natively on Windows is painful, and MEME's own docs recommend Docker there),
while bgzip tries local binaries *first* (htslib is small and usually already installed, so
pulling an image would be the slower path).

> **Consequence worth knowing.** A run with no FIMO engine still succeeds, still writes a
> valid GFF3, and still exits 0 — it just contains **no `TF_binding_site` records at all**.
> That file then flows downstream and makes `compare_te_cyp_cncc.py` report zero
> CncC-proximal genes for that species. That is a data gap, not biology, and the cncc
> script flags it explicitly. See [04-comparison-flow.md](04-comparison-flow.md).

## Option precedence

```mermaid
flowchart LR
    A["ARG_DEFAULTS<br/>built-in fallbacks"] --> B["--config INI<br/>[species] section"]
    B --> C["explicit CLI flag"]
    C --> D[["SimpleNamespace<br/>handed to main()"]]

    style A fill:#f5f5f5
    style C fill:#e8f5e9
```

Most argparse flags default to `None` rather than their real default. That is what lets
`resolve_args()` distinguish *"the user did not pass this flag"* from *"the user passed the
same value as the default"* — without it, a config file could never be overridden by a CLI
flag set to a default-looking value, and a CLI flag could never fail to override a config
file.

Relative paths inside a config section resolve against **the config file's own directory**,
not the current working directory, so a species' config and its data files can be moved
around together.
