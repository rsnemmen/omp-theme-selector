#!/usr/bin/env bash
# Interactive oh-my-posh theme picker with live preview
# Requires: fzf, oh-my-posh
set -euo pipefail

die() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

usage() {
  printf '%s\n' 'Usage: omp-theme [options]

Browse local Oh My Posh themes with a live preview.

Options:
  --themes-dir DIR  Use this directory instead of automatic discovery
  --shell SHELL     Print setup instructions for bash or zsh
  --force           Preview all segments, regardless of current context
  --print-path      Print only the selected absolute config path
  -h, --help        Show this help

POSH_THEMES_PATH also overrides automatic theme directory discovery.
Enter selects; Esc/Ctrl-C cancels; Ctrl-/ enlarges or hides the preview.'
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "'$1' is required but was not found in PATH."
}

# Return 1 for an unavailable/empty source and 2 for a discovery error.
# Use a subshell so directory and glob settings do not affect the picker.
theme_entries() (
  local dir=$1 file name found=0
  [[ -d "$dir" ]] || return 1
  if [[ ! -r "$dir" || ! -x "$dir" ]]; then
    printf 'Error: cannot read themes directory: %s\n' "$dir" >&2
    return 2
  fi
  if [[ "$dir" == *$'\t'* || "$dir" == *$'\n'* ]]; then
    printf 'Error: theme paths cannot contain tabs or newlines: %q\n' "$dir" >&2
    return 2
  fi
  # Keep stable symlinks such as Homebrew's opt path across package upgrades.
  CDPATH='' cd -L -- "$dir" >/dev/null || return 2
  shopt -s nullglob dotglob
  for file in "$PWD"/*.omp.{json,yaml,toml}; do
    [[ -f "$file" && -r "$file" ]] || continue
    if [[ "$file" == *$'\t'* || "$file" == *$'\n'* ]]; then
      printf 'Error: theme paths cannot contain tabs or newlines: %q\n' "$file" >&2
      return 2
    fi
    name=${file##*/}
    name=${name%.omp.*}
    printf '%s\t%s\n' "$name" "$file"
    found=1
  done
  [[ "$found" == 1 ]]
)

try_themes_dir() {
  local status
  if entries=$(theme_entries "$1"); then
    return 0
  else
    status=$?
  fi
  [[ "$status" == 1 ]] || exit 1
  return 1
}

find_themes() {
  local cache_path brew_prefix

  if [[ -n "$themes_dir" ]]; then
    try_themes_dir "$themes_dir" || die "no readable oh-my-posh theme files found in $themes_dir."
    return
  fi
  if [[ -n "${POSH_THEMES_PATH:-}" ]]; then
    try_themes_dir "$POSH_THEMES_PATH" || die "no readable oh-my-posh theme files found in POSH_THEMES_PATH: $POSH_THEMES_PATH."
    return
  fi
  if [[ -n "${HOME:-}" ]] && try_themes_dir "$HOME/.poshthemes"; then
    return
  fi
  if cache_path=$(oh-my-posh cache path 2>/dev/null) && [[ -n "$cache_path" ]] && try_themes_dir "$cache_path/themes"; then
    return
  fi
  if command -v brew >/dev/null 2>&1 && brew_prefix=$(brew --prefix oh-my-posh 2>/dev/null) && [[ -n "$brew_prefix" ]] && try_themes_dir "$brew_prefix/themes"; then
    return
  fi
  die 'could not find readable oh-my-posh themes. Use --themes-dir DIR or set POSH_THEMES_PATH.'
}

shell_quote() {
  local escaped=${1//\'/\'\\\'\'}
  printf "'%s'" "$escaped"
}

themes_dir=''
target_shell=${SHELL:-}
target_shell=${target_shell##*/}
force=0
print_path=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --themes-dir|--shell)
      [[ $# -ge 2 && -n "$2" && "$2" != --* ]] || die "$1 requires a value. See --help."
      if [[ "$1" == --themes-dir ]]; then
        themes_dir=$2
      else
        case "$2" in
          bash|zsh) target_shell=$2 ;;
          *) die '--shell must be bash or zsh.' ;;
        esac
      fi
      shift 2
      ;;
    --force) force=1; shift ;;
    --print-path) print_path=1; shift ;;
    *) die "unknown option: $1. See --help." ;;
  esac
done

require_command fzf
require_command oh-my-posh
find_themes
entries=$(printf '%s\n' "$entries" | LC_ALL=C sort) || die 'could not sort themes.'

# fzf expands the pane width when it executes the preview.
# shellcheck disable=SC2016
preview='oh-my-posh print preview --config {2} --terminal-width "$FZF_PREVIEW_COLUMNS"'
if [[ "$force" == 1 ]]; then
  preview+=' --force'
fi
preview='if '"$preview"'; then printf "\033[5m▋\033[0m\n"; else printf "Unable to preview theme.\n" >&2; exit 1; fi'

if selected=$(SHELL=/bin/sh fzf \
    --prompt="Theme: " \
    --preview="$preview" \
    --preview-window=bottom:40% \
    --bind='ctrl-/:change-preview-window(bottom:80%|hidden|bottom:40%)' \
    --header='Enter: select | Esc: cancel | Ctrl-/: resize/hide preview' \
    --no-multi \
    --no-print-query \
    --no-expect \
    --no-read0 \
    --no-print0 \
    --ansi \
    --delimiter='\t' \
    --with-nth=1 <<< "$entries"); then
  :
else
  status=$?
  case "$status" in
    1|130) printf 'No theme selected.\n' >&2; exit 0 ;;
    *) printf 'Error: fzf failed (exit %s).\n' "$status" >&2; exit "$status" ;;
  esac
fi

if [[ -z "$selected" ]]; then
  printf 'No theme selected.\n' >&2
  exit 0
fi

# Reject output-changing fzf defaults or bindings instead of printing a bad path.
valid_selection=0
while IFS= read -r entry; do
  if [[ "$selected" == "$entry" ]]; then
    valid_selection=1
    break
  fi
done <<< "$entries"
[[ "$valid_selection" == 1 ]] || die 'unexpected fzf output. Check output-changing options in FZF_DEFAULT_OPTS or FZF_DEFAULT_OPTS_FILE.'

name=${selected%%$'\t'*}
selected=${selected#*$'\t'}

if [[ "$print_path" == 1 ]]; then
  printf '%s\n' "$selected"
  exit 0
fi

printf 'Selected theme: %s\nConfig path: %s\n\n' "$name" "$selected"
case "$target_shell" in
  bash|zsh)
    printf 'To apply permanently, replace your existing Oh My Posh init line\nor add this to ~/.%src:\n' "$target_shell"
    # Print literal command substitution for the user to run in their shell.
    # shellcheck disable=SC2016
    printf '  eval "$(oh-my-posh init %s --config %s)"\n' "$target_shell" "$(shell_quote "$selected")"
    ;;
  *)
    printf 'Use --shell bash or --shell zsh for setup instructions.\nFor other shells, see https://ohmyposh.dev/docs/installation/prompt\n'
    ;;
esac
