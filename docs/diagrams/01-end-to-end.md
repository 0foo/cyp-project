# End to end

## The whole pipeline

```mermaid
flowchart TD
    subgraph S1["Stage 1 — repeat-modeler-automation/"]
        direction TB
        A["Genome FASTA, gzipped<br/>one per species"]
        A --> B["worker.sh<br/>claims one genome"]
        B --> C["BuildDatabase<br/>(in dfam/tetools container)"]
        C --> D["RepeatModeler<br/>8-26 h per genome"]
        D --> E[["sample-families.fa<br/>de novo TE library"]]
    end

    subgraph GAP["NOT IN THIS REPOSITORY"]
        direction TB
        F["RepeatMasker<br/>-lib families.fa"]
        G["Gene annotation<br/>NCBI RefSeq / BRAKER / MAKER"]
        H["Ortholog renaming<br/>to D. melanogaster symbols"]
    end

    E --> F
    F --> I[["species.rm.fna.out<br/>every repeat, located"]]
    G --> H
    H --> J[["annotation.gff<br/>Cyp symbols in Name="]]

    subgraph S2["Stage 2 — pipeline-scripts-output/"]
        direction TB
        K["repeatOpp.py<br/>keep only Cyp gene rows"]
        L["Locate_TE.py<br/>overlap within +/-3 kb"]
        M["CleanAnnasse.py<br/>collapse attrs to bare symbol"]
        K --> L --> M
    end

    J --> K
    I --> L
    M --> N[["D_species GenesAffectedByTE.txt<br/>seqid TAB gene TAB RepeatMasker fields"]]

    subgraph S3["Stage 3 — analysis-pipeline/"]
        direction TB
        O["build_tfbs_te_gff.py"]
        P["FIMO + JASPAR + CncC:Maf-S ARE"]
        O --> P
    end

    N --> O
    J --> O
    A --> O
    P --> Q[["combined.gff3<br/>gene / mRNA / exon / intron<br/>mobile_genetic_element<br/>TF_binding_site"]]

    Q --> R["JBrowse 2<br/>GFF3Tabix track"]

    subgraph S4["Stage 4 — analysis-pipeline/"]
        direction TB
        S["compare_te_cyp_exposure.py<br/>all Cyp genes"]
        T["compare_te_cyp_cncc.py<br/>CncC-proximal subset"]
        U["compare_te_cyp_xenobiotic.py<br/>curated resistance list"]
        S -.->|"imports parsing + stats"| T
        S -.->|"imports parsing + stats"| U
    end

    Q --> S
    Q --> T
    Q --> U
    S --> V[["CSV + markdown report + PNG"]]
    T --> V
    U --> V

    style GAP stroke-dasharray: 6 4
    style S1 fill:#eef6ff,stroke:#4a7fb5
    style S2 fill:#fff6ee,stroke:#b5814a
    style S3 fill:#f0ffee,stroke:#5ab54a
    style S4 fill:#f6eeff,stroke:#8a4ab5
```

## The seam

The dashed box is the important part of this diagram. **Two required steps have no code in
this repository**: RepeatMasker, and gene annotation with ortholog renaming.

Stage 1 produces a TE *library* — a catalogue of repeat families found in a genome. It does
not say where in the genome they are. Turning a library into per-locus coordinates is
RepeatMasker's job, and RepeatMasker is invoked here only by `runMasker.sh`, a file known
from the archive photographs (see `OCR docs/02`) but never committed.

Likewise, Stage 2 needs an annotation GFF whose `Name=` attributes are already *D.
melanogaster* Cyp symbols. Producing that was the job of `ReVamp_Final.py` /
`NEW_Step_5_Replace_gff_Names_with_Dmelanogaster_1_9.py`, also not committed.

So the pipeline as committed is two working halves with a manual bridge between them. If
you have a `*.rm.fna.out` and a renamed `*.gff`, everything downstream runs. If you only
have genomes, Stage 1 will run and then you will stop.

## Where the data in this repository sits on that path

```mermaid
flowchart LR
    A["repeat-modeler-automation/<br/>scripts only, no data"]
    B["pipeline-scripts-output/DA_Files/<br/>D. ananassae inputs"]
    C["pipeline-scripts-output/<br/>filtered.gff, GenesAffectedByTEs.txt,<br/>DAnasse_TE_Cyp.txt"]
    D["AnalysisForAll/output/<br/>29 species, TE-hits tables"]
    E["analysis-pipeline/<br/>scripts only, no data"]

    B -->|"worked example"| C
    C -->|"same 3 steps, batched"| D
    D -.->|"would feed"| E

    style A fill:#eef6ff
    style E fill:#f0ffee
```

The repository contains **one fully worked example** (*D. ananassae*, every intermediate
preserved) and **29 finished TE-hits tables**, but no combined GFF3 and no comparison
output. Stage 3 and Stage 4 have never been run on the committed data — their inputs are
present, their outputs are not.
