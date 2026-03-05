# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

A single-script tool (`pick-theme.sh`) for interactively selecting an [oh-my-posh](https://ohmyposh.dev/) theme with live preview in the terminal.

**Dependencies:** `fzf`, `oh-my-posh`

## Usage

```bash
# Run the theme picker (theme config files must be in the same directory as the script)
./pick-theme.sh
```

Place `.omp.json`, `.omp.yaml`, or `.omp.toml` theme files alongside `pick-theme.sh`. The script lists them via `fzf` with a live preview using `oh-my-posh print preview --config {}`.

On selection, it prints the config path and the `eval` snippet needed to apply the theme permanently in a shell init file.
