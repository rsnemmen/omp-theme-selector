# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

A single-script tool (`omp-theme.sh`) for interactively selecting an [oh-my-posh](https://ohmyposh.dev/) theme with live preview in the terminal.

**Dependencies:** `fzf`, `oh-my-posh`

## Usage

```bash
./omp-theme.sh
```

The script auto-detects the themes directory in priority order:
1. `~/.poshthemes/` — user-managed override
2. `$(oh-my-posh cache path)/themes` — curl/standard installs (Linux and macOS)
3. `$(brew --prefix oh-my-posh)/themes` — Homebrew (macOS)

fzf displays theme names (stripped of `.omp.{json,yaml,toml}`) with a live preview via `oh-my-posh print preview`. A blinking cursor is appended after the preview output to show cursor placement.

On selection, it prints the config path and the `eval` snippet needed to apply the theme permanently in a shell init file. Nothing is written to disk automatically.
