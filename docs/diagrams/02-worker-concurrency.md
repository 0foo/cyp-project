# Worker concurrency and genome state

## Every state a genome can be in

State lives entirely in **directory names** under `$STATE_DIR`. Nothing is ever read to
decide what to work on next, so there is no file for workers to disagree about.

```mermaid
stateDiagram-v2
    [*] --> Available: genome file exists in IN_DIR

    Available: <b>available</b><br/>has an unfinished stage, not claimed or failed<br/>(recomputed every pass, never recorded)
    Claimed: <b>claimed/&lt;sample&gt;/</b><br/>owner file records host + pid + container
    Done: <b>done/&lt;sample&gt;</b><br/>families file is in OUT_DIR<br/>still available for the mask stage
    Masked: <b>masked/&lt;sample&gt;</b><br/>sample.rm.out is in OUT_DIR
    Failed: <b>failed/&lt;sample&gt;</b><br/>scratch dir and log kept

    Available --> Claimed: mkdir succeeded<br/>(exactly one winner)
    Claimed --> Done: rc 0
    Claimed --> Failed: rc 1
    Claimed --> Available: rc 130 — SIGTERM<br/>no marker written
    Claimed --> Available: reap_stale_claims()<br/>owner pid is dead on this host

    Failed --> Available: RETRY_FAILED=1<br/>or rm failed/&lt;sample&gt;
    Done --> Masked: RUN_MASKER=1<br/>RepeatMasker succeeded
    Done --> Available: rm done/&lt;sample&gt;
    Masked --> Available: rm masked/&lt;sample&gt;<br/>re-masks, no re-modelling

    Done --> [*]
```

The fourth state has no marker of its own — **available is the absence of the other three**.
That is what makes `rm state/done/GCA_002110` a complete way to redo one genome — and
`rm state/masked/GCA_002110` a way to redo only its RepeatMasker run, keeping the library that
took 8-26 hours to build.

Note that a genome in `done/` is **not** necessarily finished. With `RUN_MASKER=1` it stays
available for the mask stage until `masked/` exists too, which is what lets you enable masking
after a modelling run and have the existing genomes picked up without re-modelling them.

## Why `mkdir` is the lock

```mermaid
sequenceDiagram
    autonumber
    participant W1 as worker A
    participant W2 as worker B
    participant K as kernel
    participant FS as STATE_DIR/claimed/

    Note over W1,W2: both shuffled to the same genome
    W1->>K: mkdir claimed/D_suzukii
    W2->>K: mkdir claimed/D_suzukii
    Note over K: the existence check and the create<br/>are one indivisible operation
    K-->>W1: exit 0
    K-->>W2: EEXIST
    W1->>FS: write owner (host, pid, container, start)
    Note over W2: `claim` returned 1 — move on to the next genome
    W1->>W1: process_one()
```

There is deliberately **no `if [ -d ... ]` test** before the `mkdir`. Adding one would
reintroduce exactly the race the design exists to avoid: between the test and the create,
another worker can win.

The `done/` and `failed/` checks in the main loop *are* allowed to be stale — they only
skip pointless `mkdir` attempts. The `mkdir` is the one step whose answer is authoritative.

> **`STATE_DIR` must be on a local filesystem.** `mkdir` atomicity is not dependable over
> NFS, and the entire scheme rests on it.

## One genome, start to finish

```mermaid
flowchart TD
    A["find IN_DIR -name GLOB | shuf"] --> B{"SHUTDOWN?"}
    B -->|yes| Z["exit 143"]
    B -->|no| C["strip .gz/.fna/.fa/.fasta/.rm<br/>→ sample name"]
    C --> D{"nothing left to do?<br/>done/ and, if RUN_MASKER=1,<br/>masked/ both exist"}
    D -->|yes| A
    D -->|no| E{"failed/sample<br/>exists?"}
    E -->|"yes, RETRY_FAILED=0"| A
    E -->|"yes, RETRY_FAILED=1"| F["rm the marker"]
    E -->|no| G
    F --> G["claim: mkdir claimed/sample"]
    G -->|EEXIST| A
    G -->|"exit 0"| H["wipe + recreate WORK_DIR/sample"]
    H --> I["zcat on the HOST<br/>(IN_DIR is never mounted)"]
    I --> J{"SHUTDOWN?"}
    J -->|yes| R130
    J -->|no| K["docker run … BuildDatabase"]
    K -->|nonzero| J2{"SHUTDOWN?"}
    J2 -->|yes| R130
    J2 -->|no| R1
    K -->|ok| L{"SHUTDOWN?"}
    L -->|yes| R130
    L -->|no| M["docker run … RepeatModeler<br/>-threads N or -pa N/4"]
    M -->|nonzero| J3{"SHUTDOWN?"}
    J3 -->|yes| R130
    J3 -->|no| R1
    M -->|ok| N{"families.fa<br/>non-empty?"}
    N -->|no| R1["rc 1 → failed/<br/>keep scratch + logs"]
    N -->|yes| O["cp to OUT_DIR<br/>write done/ marker"]
    O --> MK{"RUN_MASKER=1<br/>and no masked/ marker?"}
    MK -->|no| R0
    MK -->|yes| MR["docker run … RepeatMasker<br/>-lib families.fa -pa N -xsmall"]
    MR -->|nonzero| J4{"SHUTDOWN?"}
    J4 -->|yes| R130
    J4 -->|no| R1
    MR -->|ok| MO{"sample.fa.out<br/>non-empty?"}
    MO -->|no| R1
    MO -->|yes| MC["cp to OUT_DIR as sample.rm.out<br/>write masked/ marker"]
    MC --> R0
    R0["rc 0 → all stages done<br/>delete scratch"]

    R130["rc 130 → no marker<br/>delete scratch<br/>genome looks untouched"]

    R0 --> P["unclaim"]
    R1 --> P
    R130 --> P
    P --> A

    style R0 fill:#e8f5e9,stroke:#388e3c
    style R1 fill:#ffebee,stroke:#c62828
    style R130 fill:#fff8e1,stroke:#f9a825
```

The three outcomes are handled differently on purpose, and the middle one is the subtle one:

- **success** → marker written, scratch deleted
- **failure** → marker written, scratch and log **kept** so you can see what happened
- **abort** (rc 130, a clean SIGTERM) → **no marker**, scratch deleted. The genome looks
  untouched and the next run picks it up.

Without the `(( SHUTDOWN )) && return 130` checks after each container call, every clean
shutdown would wrongly mark its in-flight genome *failed* — because stopping the container
makes `docker run` exit non-zero, which is indistinguishable from a real failure unless you
check whether *you* were the one who stopped it.

## Supervisor and workers

```mermaid
flowchart LR
    subgraph MGR["rm-manager.sh"]
        direction TB
        ST["start<br/>skip live slots, stagger 2 s"]
        SP["stop<br/>walk pid files, SIGTERM"]
        SS["status<br/>two independent views"]
    end

    subgraph RUN["RUN_DIR"]
        P1["worker-1.pid"]
        P2["worker-2.pid"]
        P3["worker-N.pid"]
    end

    subgraph WK["workers (no coordinator)"]
        W1["worker.sh"]
        W2["worker.sh"]
        W3["worker.sh"]
    end

    STATE[("STATE_DIR<br/>claimed/ done/ masked/ failed/")]

    ST --> P1 & P2 & P3
    ST --> W1 & W2 & W3
    SP --> P1 & P2 & P3
    P1 -.->|"kill -TERM"| W1
    P2 -.->|"kill -TERM"| W2
    P3 -.->|"kill -TERM"| W3

    W1 <--> STATE
    W2 <--> STATE
    W3 <--> STATE

    SS -->|"pid check"| RUN
    SS -->|"queue counts"| STATE
    SS -->|"docker ps --filter label=rmworker.sample"| DK[("Docker daemon")]

    W1 --> DK
    W2 --> DK
    W3 --> DK
```

`rm-manager.sh` holds no state beyond pid files. The workers coordinate with each other
through `$STATE_DIR` alone — which is why a worker you started by hand and one started by
the manager behave identically, and why `status`'s queue counts are accurate either way.

`status` deliberately reports **two views that can legitimately disagree**: which worker
*processes* are alive (from pid files) and what the *queue* looks like (from the state
directories). A "dead (stale pidfile)" line next to a non-zero `running` count means a
worker was killed hard and its claim is still sitting there, waiting to be reaped the next
time any worker starts.
