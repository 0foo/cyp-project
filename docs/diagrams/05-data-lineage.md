# Data lineage

Every data file committed to this repository, and what produced it.

## The *D. ananassae* worked example

`pipeline-scripts-output/` preserves one species end to end — every intermediate, in order.
It is the best available specification of what Stage 2 does, because you can diff the files.

```mermaid
flowchart TD
    A[("DA_Files/<br/>DROSOPHILA_ANANASSAE_final_withDmelNames.gff<br/>annotation, Cyp symbols already in Name=")]
    B[("AnalysisForAll/Reg_Gene_Full.txt<br/>96 lines — Cyp symbols<br/>+ 5 Dvir\/Dmoj\ ortholog IDs")]
    C[("DA_Files/<br/>Drosophila_ananassae.GCF_017639315.1.rm.fna.out<br/>RepeatMasker output")]

    A --> S1["<b>repeatOpp.py</b><br/>keep gene rows whose attrs<br/>contain a Cyp symbol"]
    B --> S1
    S1 --> D[("filtered.gff<br/>Cyp gene rows only")]

    D --> S2["<b>Locate_TE.py</b><br/>seqid match AND<br/>overlap within +/-3000 bp"]
    C --> S2
    S2 --> E[("GenesAffectedByTEs.txt<br/>col 2 = the whole GFF attribute blob")]

    E --> S3["<b>CleanAnnasse.py</b><br/>replace col 2 with the bare symbol"]
    B --> S3
    S3 --> F[("DAnasse_TE_Cyp.txt<br/>seqid TAB Cyp12e1 TAB RepeatMasker fields")]

    F -.->|"this is the --te-hits format"| G["build_tfbs_te_gff.py"]

    style F fill:#e8f5e9,stroke:#388e3c
```

The transformation `CleanAnnasse.py` performs is visible in one line. Before:

```
NC_057927.1	Name=Cyp12e1;ID=gene-G00000000064;Name_old=LOC6500252;dbxref=…	   13   28.7  1.4  4.5  NC_057927.1    846413   846481 …
```

After:

```
NC_057927.1	Cyp12e1	   13   28.7  1.4  4.5  NC_057927.1    846413   846481 …
```

That is the whole point of the third script: collapse a 300-character attribute string into
the bare gene symbol, because `build_tfbs_te_gff.py` reads column 2 as a symbol.

## The 29-species batch

`AnalysisForAll/` is the same three steps applied across species, with the *D. melanogaster*
intermediates left in place as the reference run.

```mermaid
flowchart LR
    subgraph REF["D. melanogaster reference run"]
        R1[("GFF/ + FilesFromMasker/")] --> R2[("step1Temp.gff")]
        R2 --> R3[("step2GenesAffectedByTEs.txt")]
        R3 --> R4[("output/D_melanogasterGenesAffectedByTE.txt")]
    end

    subgraph BATCH["output/ — 29 species"]
        O1["D_simulans…"]
        O2["D_sechelia…"]
        O3["D_willistoni…"]
        O4["… 26 more"]
    end

    R4 --- BATCH

    style R2 fill:#f5f5f5
    style R3 fill:#f5f5f5
```

`step1Temp.gff` and `step2GenesAffectedByTEs.txt` are the same artifacts as `filtered.gff`
and `GenesAffectedByTEs.txt` above, under batch-run names — confirming the three-step shape
was stable across both runs.

## Reference gene lists

```mermaid
flowchart TD
    A[("Cyp_stable_genes_Good_et_al_2014.txt<br/>29 symbols")]
    B[("Cyp_unstable_genes_Good_et_al_2014.txt<br/>46 symbols")]
    C[("Reg_Gene_Full.txt<br/>96 lines")]

    A --> C
    B --> C
    C -->|"used as the gene filter"| D["repeatOpp.py<br/>CleanAnnasse.py"]

    note["29 + 46 = 75, but Reg_Gene_Full has 96 lines.<br/>The extra ~21 include 5 ortholog IDs<br/>(Dvir\GJ21722, Dmoj\GI21254, …)<br/>which both scripts skip via startswith('D')"]
    C -.- note

    style note fill:#fff8e1,stroke-dasharray: 3 3
```

The `startswith("D")` skip in `repeatOpp.py` and `CleanAnnasse.py` exists to drop those
`Dvir\`/`Dmoj\` prefixed ortholog identifiers. It is a blunt instrument — it would also
silently drop any Cyp symbol beginning with a capital D — but no such symbol exists in
these lists.

"Stable" and "unstable" refer to Good et al. 2014's classification of Cyp gene copy-number
stability across *Drosophila*. Both lists are merged for filtering; the distinction is not
used by any committed script.

## What is missing

```mermaid
flowchart LR
    A["analysis-pipeline/"] -.->|"needs"| B["species_config.example.ini"]
    A -.->|"needs"| C["te_cyp_species_config.example.ini"]
    A -.->|"needs"| D["xenobiotic_resistance_cyp_genes.example.txt"]

    style B fill:#ffebee,stroke:#c62828,stroke-dasharray: 4 3
    style C fill:#ffebee,stroke:#c62828,stroke-dasharray: 4 3
    style D fill:#ffebee,stroke:#c62828,stroke-dasharray: 4 3
```

All four scripts reference these three example files by name in their docstrings, help text
and error messages. **None of them exist in the repository.** Formats are documented in
`docs/deep/06-data-formats.md`; you will need to write your own.
