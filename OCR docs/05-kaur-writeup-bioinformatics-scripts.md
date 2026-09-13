# 05 — Diljot Kaur, "Development and Use of Bioinformatics Scripts for Transposable Element Analysis in *Drosophila*"

**Sources:** `collected-docs/src/PXL_20260910_180237566.jpg` (p1),
`…180244049.jpg` (p2), `…180250348.jpg` (p3), `…180256463.jpg` (p4, shot at a steep angle),
`…180259530.jpg` (p5, only four lines of text, rest of page blank)
**Type:** printed formal write-up, 5 pages, numbered
**Legibility:** high on pages 1–3 and 5; page 4 is photographed at an angle and its text is
rotated ~100°, but readable

Typos below (`grom`, `demonstarates`, `libraires`, `transp0osable`, `consenus`, `repat`,
`withing`, `sies`) are reproduced as printed.

---

## Page 1 — Introduction

> Modern genomics projects, such as this one, generate extremely large datasets that cannot
> be analyzed efficiently by hand. The goal of this project is to identify and compare
> transposable elements (TEs) across more than 300 *Drosophila* genomes and determine how
> these elements may influence the regulation and evolution of cytochrome P450 (CYP) genes.
> Specifically, we are interested in whether TEs are located within or near CYP genes and
> whether they contain or introduce transcription factor binding sites (TFBS) that could
> affect gene expression. Because each genome contains millions of DNA base pairs and
> thousands of repetitive elements, analyzing hundreds of genomes produces an enormous
> amount of data that requires computational methods for efficient analysis.
>
> As a result, bioinformatics scripts have become an essential part of genomic research
> because they automate repetitive tasks, organize data, and connect multiple software tools
> into a single analysis pipeline. In this project, as a series of shell scripts and Python
> scripts were used to process different species of *Drosophila* genome assemblies, identify
> transposable elements (TEs), generate TE libraries, create genome annotation files, and
> prepare results for visualization in JBrowse and downstream motif analyses.
>
> Rather than performing each step manually for every species, the scripts standardize the
> workflow so that the same analysis is carried out consistently across multiple genomes.
> This reduces human error, improves reproducibility, and makes it possible to analyze large
> datasets in a reasonable amount of time. Several command line utilities, including Linux
> shell (more specifically Ubuntu) commands such as ls, were used to navigate directories and
> manage files, while scripts such as BuildDatabase, RepeatModeler, RepeatMasker, and custom
> Python programs automated different stages of the pipeline.
>
> An equally important purpose of these scripts is to ensure that the output from one program
> is correctly formatted for the next. One small error can interfere with the entire script
> and prevent it from running properly. Genome FASTA files, annotation (GFF) files, repeat
> libraires, and processed result files all serve as inputs and outputs for different parts of
> the workflow. Custom scripts (composed by Duy, Terry, Charles, and previous students in the
> lab) were used to modify file formats, replace paths, organize output files, and generate
> annotation tracks that could be visualized in JBrowse. Together, these scripts create a
> complete computational pipeline that transforms raw genome sequences into organized datasets
> suitable for biological interpretation and comparative analysis of transposable elements
> across multiple *Drosophila* species.

---

## Page 2 — Linux/Shell Basics, RepeatModeler, RepeatMasker

> **Linux/Shell Basics**
>
> Before running any scripts, it is important to know how to navigate the Linux terminal. The
> terminal is used to move between folders, locate files, and execute scripts. Some of the
> most commonly used commands include:
>
> - ls – lists the files and folders in the current directory.
> - cd – stands for current directory. It helps you change to any directory in the list from ls.
> - cd .. - exits the current directory that you are in.
>
> Understanding these basic commands is necessary because each script must be run from the
> correct folder. Running a script from the wrong directory or using the wrong file paths can
> cause errors or prevent the program from finding the required input files.
>
> **RepeatModeler**
>
> RepeatModeler is used to identify and build a library of repetitive DNA sequences, also
> called transposable elements (TEs), from a genome. Before running RepeatModeler, the genome
> FASTA file must first be converted into a searchable database using the BuildDatabase
> command. After the database is created, RepeatModeler is run on that database. Depending on
> the size of the genome, the analysis can take several hours to complete. Once finished,
> RepeatModeler generates a consenus library (consensi.fa.classified) containing the predicted
> repat sequences. This file serves as the input for RepeatMasker, which uses the library to
> identify and annotate repetitive elements throughout the genome.
>
> The basic workflow is:
>
> 1.) Navigate to RepeatModeler working directory.
> 2.) Build a database from the genome FASTA file using BuildDatabase.
> 3.) Run RepeatModeler on the database.
> 4.) Save the output files, especially consensi.fa.classified, for use in the next step of the
>     pipeline (RepeatMasker).
>
> **RepeatMasker**
>
> RepeatMasker uses the repeat library created by RepeatModeler to locate transposable elements
> (TEs) throughout a genome. The consensi.fa.classified file generated by RepeatModeler is used
> as the custom library for this step. After RepeatMasker is run, it produces several output
> files that describe the location and classification of repetitive elements within the genome.
> These files are then used in later steps of the pipeline, including Python scripts for data
> processing and visualization in JBrowse.

---

## Page 3 — RepeatMasker workflow, Python scripts, JBrowse

> The Basic workflow is:
>
> 1.) Copy the RepeatModeler output (consensi.fa.classified) into the RepeatMasker folder (it
>     should already be there from when we ran RepeatModeler).
> 2.) Run RepeatMasker using the custom repeat library and the genome FASTA file.
> 3.) Save the output files for downstream analysis.
>
> **Python Data Processing Scripts**
>
> After RepeatMasker finishes, several Python scripts are used to organize and process the
> output files for downstream analysis. These scripts convert and combine data from multiple
> files, identify genes that are affected by nearby transposable elements, and generate
> annotation files that can be visualized in JBrowse. Processing these files is necessary
> because the raw RepeatMasker output is not formatted for direct analysis or visualization. By
> reorganizing and standardizing the data, the scripts make it possible to identify transposable
> elements located withing or nearby CYP genes and prepare the files for transcription factor
> binding sites (TFBS) analysis.
>
> The scripts are run in Visual Studio Code (VSC) by editing the required file paths and then
> executing the script. Once completed, the processed output files are saved and used in
> JBrowse.
>
> The basic workflow is:
>
> 1.) Open the Python scripts in Visual Studio Code.
> 2.) Update the required file paths.
> 3.) Run the scripts to process and organize the output files.
> 4.) Save the processed output files for the next step of the pipeline.
>
> **JBrowse Visualization**
>
> JBrowse is used to visualize the processed genome and annotation files. After the Python
> scripts generate the required output files, they are loaded into JBrowse as new tracks.
> Visualizing these files allows researchers to examine the locations of transposable elements
> relative to CYP genes and nearby transcription factors binding sites. Viewing the data in a
> genome browser also makes it easier to identify patterns, verify that the annotation files
> were generated correctly, and compare genomic features across different *Drosophila* species.
>
> To add a new track, the appropriate annotation file is selected, the correct assembly is
> chosen, and the track is loaded into the genome browser.
>
> The basic workflow is:

---

## Page 4 — JBrowse steps, TFBS analysis, Conclusion

> 1.) Open JBrowse.
> 2.) Add a new track using the processed annotation file.
> 3.) Select the correct genome assembly.
> 4.) Load the track and examine the locations of transp0osable elements, CYP genes, and
>     transcription factor binding sites.
>
> **Transcription Factor Binding Site (TFBS) Analysis**
>
> After the genome annotation files are prepared and visualized, transcription factor binding
> site (TFBS) analysis is performed. This step identifies potential DNA regions where
> transcription factors may bind and examine whether these binding sites are located within or
> near transposable elements that are associated with CYP genes. By comparing predicted binding
> sites across different *Drosophila* species, researchers can investigate whether transposable
> elements may contribute to changes in gene regulation and how these regulatory patterns have
> evolved over time.
>
> The analysis uses the processed annotation files and transcription factor database to identify
> potential binding sites within the genomic regions of interest. The resulting data provide
> insight into the possible regulatory roles of transposable elements and their relationship to
> nearby CYP genes.
>
> The basic workflow is:
>
> 1.) Prepare the required input files.
> 2.) Run the TFBS analysis script.
> 3.) Generate the output files.
> 4.) Compare and interpret the predicted transcription factor binding sites near transposable
>     elements and CYP genes.
>
> **Conclusion**
>
> This workflow uses a series of bioinformatics scripts to process genome data from multiple
> *Drosophila* species. Each program and script has a specific role, grom identifying
> transposable elements within RepeatModeler and RepeatMasker to processing the results with
> Python scripts, visualizing the data in JBrowse, and identifying potential transcription
> factor binding sites near CYP genes. Working through each step of the pipeline demonstarates
> how large genomic datasets can be transformed into organized information that can be used to
> study the relationship between transposable elements, gene regulation, and genome evolution.
>
> By automating the analysis of hundreds of *Drosophila* genomes, these scripts make it possible
> to efficiently identify transposable elements, determine their locations relative to CYP
> [genes…]

---

## Page 5 — end of the Conclusion

The page carries only the tail of the final sentence; the left margin is cut off by the
photograph's framing, so each line is missing its first word or two.

> […genes], and investigate whether they introduce or occur near transcription factor binding
> sies that [in]fluence gene expression. Without these computational tools, processing and
> comparing [a] large amount of genomic data would be extremely time consuming and susceptible
> to [huma]n error. Together, the scripts create a reproducible and organized workflow that
> allows [resea]rchers to compare results across species and gain a better understanding of how
> [trans]posable elements may contribute to the evolution and regulation of CYP genes.

---

## Notes

**This is the project's statement of purpose**, and it is worth stating plainly because no
file in this repository says it: the question is whether TEs sit inside or near CYP genes,
and whether they carry or introduce transcription-factor binding sites that change how those
genes are expressed — across 300+ *Drosophila* genomes.

The committed `analysis-pipeline/` narrows this to a testable form (does *insecticide
exposure* predict TE burden in Cyp genes?), but the broader framing here is the parent
question.

**"more than 300 genomes" versus what is actually present.** The write-up claims 300+;
the notebook lists 12 targets; `pipeline-scripts-output/AnalysisForAll/output/` holds 29
species; the JBrowse results cover 3. These are not contradictory — they are the ambition,
the current batch, the completed batch, and the visualized subset respectively — but the
300 figure should not be read as a count of anything that exists.

**The write-up is procedural, not technical.** Each section ends in a 3–4 step "basic
workflow" that describes *what to click*, not what the code does. There is no mention of
the statistical tests, the FIMO/JASPAR motif scan, the CncC:Maf-S consensus motif, or the
GFF3 schema — all of which exist in `analysis-pipeline/`. That gap is the reason the
`docs/deep/` documents in this repository were written.

**It confirms the manual VS Code step independently of doc 02.** "The scripts are run in
Visual Studio Code (VSC) by editing the required file paths and then executing the script" —
two separate sources, one handwritten and one typed, describing the same hand-editing loop.

**Attribution.** Custom scripts are credited to "Duy, Terry, Charles, and previous students
in the lab." Terry appears here and nowhere else in the archive.
