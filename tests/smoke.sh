#!/usr/bin/env bash
# Exercise the installed Oh My Posh and fzf without opening an interactive UI.
set -euo pipefail

repo_dir=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
themes_dir=${1:?Usage: bash tests/smoke.sh THEMES_DIR}
themes_dir=$(CDPATH='' cd -L -- "$themes_dir" && pwd)
test_dir=$(mktemp -d "${TMPDIR:-/tmp}/omp-selector-smoke.XXXXXX")
trap 'rm -rf "$test_dir"' EXIT
export OMP_CACHE_DIR="$test_dir"
export TERM=xterm-256color

oh-my-posh version
fzf --version
"$BASH" --version | head -n 1

# The CLI must override defaults that alter fzf's output protocol.
selected=$(FZF_DEFAULT_OPTS='--filter=^agnoster$ --multi --print-query --expect=ctrl-a --read0 --print0' \
  FZF_DEFAULT_OPTS_FILE='' \
  "$BASH" "$repo_dir/omp-theme.sh" --themes-dir "$themes_dir" --print-path)
[[ "$selected" == "$themes_dir/agnoster.omp.json" ]]

# A literal marker catches silent configuration fallback as well as CLI errors.
cat > "$test_dir/marker.omp.json" <<'JSON'
{"version":3,"blocks":[{"type":"prompt","alignment":"left","segments":[{"type":"text","style":"plain","template":"OMP_SELECTOR_SMOKE_OK"}]}]}
JSON
for config in "$selected" "$test_dir/marker.omp.json"; do
  for shell in bash zsh; do
    oh-my-posh init "$shell" --config "$config" --print > "$test_dir/init.$shell"
    [[ -s "$test_dir/init.$shell" ]]
    "$shell" -n "$test_dir/init.$shell"
  done
  for width in 40 100; do
    oh-my-posh print preview --config "$config" --terminal-width "$width" > "$test_dir/preview"
    [[ -s "$test_dir/preview" ]]
    if [[ "$config" == "$test_dir/marker.omp.json" ]]; then
      [[ "$(cat "$test_dir/preview")" == *OMP_SELECTOR_SMOKE_OK* ]]
    fi
  done
done
printf 'Oh My Posh/fzf smoke checks passed.\n'
