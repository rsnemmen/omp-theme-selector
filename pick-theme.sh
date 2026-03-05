#!/usr/bin/env bash
# Interactive oh-my-posh theme picker with live preview
# Requires: fzf, oh-my-posh

if [[ -d "$HOME/.poshthemes" ]]; then
  THEMES_DIR="$HOME/.poshthemes"
elif cache_themes=$(oh-my-posh cache path 2>/dev/null) && [[ -d "$cache_themes/themes" ]]; then
  THEMES_DIR="$cache_themes/themes"
elif brew_prefix=$(brew --prefix oh-my-posh 2>/dev/null) && [[ -d "$brew_prefix/themes" ]]; then
  THEMES_DIR="$brew_prefix/themes"
else
  echo "Error: could not find oh-my-posh themes directory." >&2
  echo "Install oh-my-posh via Homebrew, curl installer, or create ~/.poshthemes/" >&2
  exit 1
fi

selected=$(find "$THEMES_DIR" -maxdepth 1 \( -name "*.omp.json" -o -name "*.omp.yaml" -o -name "*.omp.toml" \) \
  | sort \
  | awk -F'/' '{name=$NF; sub(/\.omp\.(json|yaml|toml)$/, "", name); print name "\t" $0}' \
  | fzf \
      --prompt="Theme: " \
      --preview="oh-my-posh print preview --config {2}" \
      --preview-window=bottom:10 \
      --ansi \
      --delimiter='\t' \
      --with-nth=1)

if [[ -z "$selected" ]]; then
  echo "No theme selected." >&2
  exit 0
fi

name=$(cut -f1 <<< "$selected")
selected=$(cut -f2 <<< "$selected")
echo "Selected theme: $name"
echo "Config path: $selected"
echo ""
echo "To apply permanently, add to your shell init file:"
echo "  eval \"\$(oh-my-posh init \$SHELL --config '$selected')\""
