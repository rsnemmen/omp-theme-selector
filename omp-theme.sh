#!/usr/bin/env bash
# Interactive oh-my-posh theme picker with live preview
# Requires: fzf, oh-my-posh
set -euo pipefail

die() {
  echo "Error: $*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "'$1' is required but was not found in PATH."
}

find_themes_dir() {
  local cache_themes
  local brew_prefix

  if [[ -d "$HOME/.poshthemes" ]]; then
    printf '%s\n' "$HOME/.poshthemes"
  elif cache_themes=$(oh-my-posh cache path 2>/dev/null) && [[ -d "$cache_themes/themes" ]]; then
    printf '%s\n' "$cache_themes/themes"
  elif command -v brew >/dev/null 2>&1 && brew_prefix=$(brew --prefix oh-my-posh 2>/dev/null) && [[ -d "$brew_prefix/themes" ]]; then
    printf '%s\n' "$brew_prefix/themes"
  else
    return 1
  fi
}

theme_entries() {
  find "$THEMES_DIR" -maxdepth 1 \( -name "*.omp.json" -o -name "*.omp.yaml" -o -name "*.omp.toml" \) -print \
    | sort \
    | awk -F'/' '{name=$NF; sub(/\.omp\.(json|yaml|toml)$/, "", name); print name "\t" $0}'
}

require_command fzf
require_command oh-my-posh

THEMES_DIR=$(find_themes_dir) || die "could not find oh-my-posh themes directory. Install oh-my-posh via Homebrew, curl installer, or create ~/.poshthemes/."

if [[ -z "$(theme_entries)" ]]; then
  die "no oh-my-posh theme files found in $THEMES_DIR."
fi

if ! selected=$(theme_entries | fzf \
    --prompt="Theme: " \
    --preview='oh-my-posh print preview --config {2}; printf "\033[5m▋\033[0m\n"' \
    --preview-window=bottom:10 \
    --ansi \
    --delimiter='\t' \
    --with-nth=1); then
  echo "No theme selected." >&2
  exit 0
fi

if [[ -z "$selected" ]]; then
  echo "No theme selected." >&2
  exit 0
fi

name=${selected%%$'\t'*}
selected=${selected#*$'\t'}

echo "Selected theme: $name"
echo "Config path: $selected"
echo ""
echo "To apply permanently, add to your shell init file:"
echo "  eval \"\$(oh-my-posh init \$SHELL --config '$selected')\""
