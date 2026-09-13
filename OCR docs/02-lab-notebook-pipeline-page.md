# 02 — Lab notebook: RepeatMasker → VS Code → JBrowse

**Source:** `collected-docs/src/PXL_20260824_163729437.jpg` (flat, in focus — primary)
and `collected-docs/src/PXL_20260824_162859737.jpg` (same page, held up at an angle,
with a monitor and a whiteboard visible behind it)
**Type:** handwritten, graph-ruled spiral notebook, one page, four sections
**Legibility:** mixed — headings and structure are clear, several species names and
command fragments are not

The two photographs are of the same page. The angled shot adds only context: the monitor
behind it shows a `dfam-tetools /Spring26RepeatModeler)` prompt and the tail of the Dfam
banner ("please contribute de-novo or curated families to … the Dfam open database … visit
http://dfam.org or contact help@dfam.org"), confirming the notebook was written at the
machine while a container session was open.

## Section 1 — RepeatMasker

```
Repeatmasker:
• After repeat modeler RM file w/date  Data D.
• [struck through, illegible]   consensi.fa.classified
• RepeatMasker
• Copy & paste replace Drosophila_…  w/ file
• RepeatMasker -lib RM_#$date/consensi.fa.classified -pa 8
  Drosophila_ .fna file
```

A small caret insertion above `replace` reads approximately `copied` [?].

**Notes.** The intended command is `RepeatMasker -lib <RM_dated_dir>/consensi.fa.classified
-pa 8 <species>.fna`, where `RM_#$date` is a placeholder for the dated RepeatModeler output
directory (the real thing looks like `RM_235549.ThuJul92144222026`, doc 03). The bullet
"Copy & paste replace Drosophila_… w/ file" is an instruction to the reader: substitute the
actual species filename into the command each time. `-pa 8` is RepeatMasker's parallel
search-process count. [VERIFY exact flag order against `runMasker.sh`, which was never
photographed.]

## Section 2 — 12 species

```
12 species:
• [struck through: "SIM"]  Simulen
• Sushulid
• erecta
• uculoa
• annaesar
• pseudobscura
```

**Notes.** The heading says twelve; six are listed. The remaining six are not on this page
and were not photographed. Reading the six against known *Drosophila* names:

| As written | Almost certainly |
|---|---|
| `Simulen` | *D. simulans* |
| `Sushulid` | *D. suzukii* [?] |
| `erecta` | *D. erecta* |
| `uculoa` | *D. yakuba* [?] |
| `annaesar` | *D. ananassae* [?] |
| `pseudobscura` | *D. pseudoobscura* |

The three marked `[?]` are genuinely hard to read; the handwriting is cursive and the
photograph is at an angle. Do not treat these as confirmed. A separate handwritten list on
doc 04 page 3 gives a different, shorter set — *ananassae, D. mel, simulans, sechellia* —
which is the validation set, not this one.

## Section 3 — Step 1 / Step 2 / Step 3 (the manual VS Code procedure)

```
Step 1:
- Open Visual Studio Code     → Data(D:) → Cyp → Spring26 → GFF #2, Duy
- Gff Files: GFF Dataset # 2, revamp - Duy
- Drag species to Visual Studio Code (VSC)
- Copy from left side & paste onto blue GFF.
- Change slashes / creases [?] to be like this)
- File save
- Click little arrow to run.

Step 2:
- Go to sources copy relative path remasker file
- 5 row: Chang slashes.
- Save
- Click arrow to run again.

Step 3:
- Right click output & make new file name: D_ species
  GenesAffectedByTE.txt
- Copy Relative path
- 4th row scroll till blue & paste
- save file
- Click arrow to run
• all completed files are in output folder
```

The path fragment after "Open Visual Studio Code" is written in blue ink, inserted above
the line.

**Notes.** This is the single most important page in the set, because it documents a step
that exists in this repository only as residue.

The procedure is: open the script in VS Code, paste a path onto a specific line, save, click
run — **three times**, pasting a different path each time (line ~4, line ~5, and the GFF
line, each apparently highlighted "blue" in the editor). The three paths are the annotation
GFF, the RepeatMasker `.out` file, and the output filename.

Compare the top of `pipeline-scripts-output/Locate_TE.py`:

```python
cypGene = "C:/Users/User/Documents/BioAtallah/RepeatMasker/RepeatOpp/filtered.gff"
TEs = 'C:/Users/User/Documents/BioAtallah/RepeatMasker/RepeatOpp/DA_Files/Drosophila_ananassae.GCF_017639315.1.rm.fna.out'
```

Two absolute Windows paths, hardcoded at module scope, one per input — exactly the shape
this notebook page describes. "Change slashes" is the instruction to convert Windows `\`
to `/` after pasting, which is why these literals use forward slashes despite being
`C:/…` paths. The `D_<species>GenesAffectedByTE.txt` filename in Step 3 matches the 29
files in `pipeline-scripts-output/AnalysisForAll/output/`.

The underscore placement in the output filename is ambiguous in the handwriting — the line
wraps between `D_ species` and `GenesAffectedByTE.txt`. The committed files resolve it:
`D_melanogasterGenesAffectedByTE.txt`, no second underscore. (The directory also contains
several one-off misspellings — `D_secheliaGenesAffectedByT.txt`,
`D_athabascaGenesAfffectedByTE.txt` — which is what hand-typing a filename 29 times
produces.)

## Section 4 — JBrowse

```
JBrowse:
• open new Genome
• Type: FastaAdapter
• (D:) Drive → Cyp → Dhakad → Dhakad → genomes
• Name assembly: just do species name
```

**Notes.** The genome path points into the **`Dhakad_et_al_2025_Data_Analysis`** tree, which
the Spring 2026 log (doc 04) explicitly calls the *old* location superseded by `Spring26/`.
Either the raw genome FASTAs were deliberately never moved, or this line is stale guidance.
[VERIFY]

"Name assembly: just do species name" is a convention that matters downstream: a JBrowse
track can only be attached to an assembly whose name matches.
