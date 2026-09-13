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
        E --> F["RepeatMasker<br/>-lib families.fa<br/>when RUN_MASKER=1"]
    end

    subgraph GAP["NOT IN THIS REPOSITORY"]
        direction TB
        G["Gene annotation<br/>NCBI RefSeq / BRAKER / MAKER"]
        H["Ortholog renaming<br/>to D. melanogaster symbols"]
    end

    F --> I[["sample.rm.out<br/>every repeat, located"]]
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

The dashed box is the important part of this diagram — and it is smaller than it used to be.

Stage 1 produces a TE *library*: a catalogue of repeat families found in a genome, which does
not say where in the genome they are. Turning that library into per-locus coordinates is
RepeatMasker's job, and **RepeatMasker is now run by the same workers**, as a second stage
gated on `RUN_MASKER=1`. A genome FASTA therefore reaches `sample.rm.out` without leaving this
repository. (The lab's own `runMasker.sh`, known from the archive photographs — see
`OCR docs/02` — was never committed, and is superseded rather than recovered.)

**One required step still has no code here**: the annotation GFF whose `Name=` attributes are
already *D. melanogaster* Cyp symbols. Producing that was the job of `ReVamp_Final.py` /
`NEW_Step_5_Replace_gff_Names_with_Dmelanogaster_1_9.py`, neither of which was committed.

So: with genomes alone you now get all the way to a located-repeat table. To go further you
also need a renamed `*.gff` for that species — existing species have one, a new species would
not.

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
