# 01 — Terminal: `cat spinContainer.sh`

**Source:** `collected-docs/src/PXL_20260824_155714317.jpg`
**Type:** photograph of a monitor showing a WSL/Ubuntu terminal
**Legibility:** high — this is the cleanest source in the set

## Verbatim

The visible scrollback ends with a long `ls -l` listing whose columns are cut off at the
right edge of the photo. Every listed entry is owned `genomics genomics`; ten are
directories (`drwxrwxrwx`) and two are files (`-rwxrwxrwx`). Names and sizes are off-screen.

The prompt and command:

```
(base) genomics@DESKTOP-DJ2BL6F:/mnt/…er$ cat spinContainer.sh
```

The file contents, printed in full:

```bash
docker run -it --rm \
    -v $(pwd):/Spring26RepeatModeler \
    -w /Spring26RepeatModeler \
    dfam/tetools:latest bash
```

The prompt returned after the `cat` shows the tail of the working directory:

```
…spring26/spring26repeatmodeler$
```

## Notes

- **Host:** `DESKTOP-DJ2BL6F`, user `genomics`, conda `(base)` environment active. The
  `/mnt/…` prefix is WSL's mount of a Windows drive — consistent with the `Data (D:)`
  paths seen in the File Explorer screenshots (doc 03).
- **Two files** in the listing are almost certainly `spinContainer.sh` and `runMasker.sh`,
  the pair named in the Spring 2026 log (doc 04). The ten directories are the per-species
  folders.
- `runMasker.sh` was **never photographed**. Its contents are known only through the
  handwritten paraphrase in doc 02. [VERIFY]
- The flags in `spinContainer.sh` are worth reading carefully, because they explain a
  constraint the whole pipeline inherits:
  - `-it` + trailing `bash` — this container is **interactive**. It drops the user into a
    shell; it does not run RepeatModeler itself. Every subsequent command was typed by
    hand at that shell prompt.
  - `--rm` — the container is discarded on exit, so nothing survives outside the mount.
  - `-v $(pwd):/Spring26RepeatModeler` — only the *current species folder* is visible
    inside the container.
  - `-w /Spring26RepeatModeler` — the shell starts in that mount.

  Because the session is interactive and per-species, running a second species meant
  opening a second terminal and repeating the whole sequence by hand. This is precisely
  what `repeat-modeler-automation/worker.sh` was later written to replace: same image,
  same mount-at-identical-path convention, but non-interactive and claim-driven so N
  workers can share one queue.
