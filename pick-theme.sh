#!/usr/bin/env bash
# Interactive oh-my-posh theme picker with live preview
# Requires: fzf, oh-my-posh

THEMES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

selected=$(find "$THEMES_DIR" -maxdepth 1 \( -name "*.omp.json" -o -name "*.omp.yaml" -o -name "*.omp.toml" \) \
  | sort \
  | fzf \
      --prompt="Theme: " \
      --preview="oh-my-posh print preview --config {}" \
      --preview-window=bottom:10 \
      --ansi \
      --delimiter='/' \
      --with-nth=-1)

if [[ -z "$selected" ]]; then
  echo "No theme selected." >&2
  exit 0
fi

name=$(basename "$selected" | sed 's/\.omp\.\(json\|yaml\|toml\)$//')
echo "Selected theme: $name"
echo "Config path: $selected"
echo ""
echo "To apply permanently, add to your shell init file:"
echo "  eval \"\$(oh-my-posh init \$SHELL --config '$selected')\""
