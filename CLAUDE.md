# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

A single-script tool (`omp-theme.sh`) for interactively selecting an [oh-my-posh](https://ohmyposh.dev/) theme with live preview in the terminal.

**Dependencies:** `fzf`, `oh-my-posh`

## Usage

```bash
./omp-theme.sh
```

The script selects the themes directory in priority order:
1. `--themes-dir DIR` — command-line override
2. `$POSH_THEMES_PATH` — environment override
3. `~/.poshthemes/` — user-managed themes
4. `$(oh-my-posh cache path)/themes` — curl/standard installs (Linux and macOS)
5. `$(brew --prefix oh-my-posh)/themes` — Homebrew (Linux and macOS)

Explicit overrides fail if they have no readable themes. Automatic discovery skips
missing or empty sources; filesystem errors are reported. Sources are not merged.
Entries are collected once, sorted, and include readable regular files and valid
file symlinks. Keep directory symlinks in the absolute paths, especially Homebrew's
stable `opt` path. Tabs/newlines in theme paths are rejected because entries use TSV.

fzf displays theme names (stripped of `.omp.{json,yaml,toml}`) with a live preview via
`oh-my-posh print preview --terminal-width "$FZF_PREVIEW_COLUMNS"`. `--force` adds
the upstream rendering flag. Previews use `/bin/sh`; a blinking cursor is appended
only after successful rendering. `Ctrl-/` cycles 40%, 80%, and hidden preview panes.
fzf no-match/interruption statuses (1/130) are successful cancellations; other
failures retain a nonzero exit status. The picker enforces single selection and
validates returned entries against the inventory.

On selection, it prints the config path and a safely quoted `eval` snippet for
Bash/Zsh, using the basename of `$SHELL` or `--shell bash|zsh`. Unknown/unset shells
receive a setup-guide link. `--print-path` emits only the absolute selected path;
cancellation emits no stdout and diagnostics go to stderr. `--help` runs without
dependencies. Nothing is written to disk automatically.

## Validation

- Keep the picker compatible with Bash 3.2; no new runtime dependencies.
- Run `python3 -m unittest discover -s tests -v` for isolated CLI regression tests.
- Run `shellcheck omp-theme.sh install.sh tests/smoke.sh` and `bash -n` on each script.
- Run `bash tests/smoke.sh THEMES_DIR` with real `oh-my-posh`, `fzf`, and `zsh`.
- `.github/workflows/compatibility.yml` checks Linux/macOS and pinned v31.9.1/latest
  stable Oh My Posh releases with matching theme bundles on push/PR/manual/weekly runs.

## Installation

`install.sh` is a curl-friendly installer. It downloads `omp-theme.sh` from the main branch and installs it as `omp-theme` in the user's PATH (`~/.local/bin` or `/usr/local/bin`). It warns (but does not abort) if `fzf` or `oh-my-posh` are missing, and prints the exact install path when done.
