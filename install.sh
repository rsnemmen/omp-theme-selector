#!/usr/bin/env bash
set -euo pipefail

REPO="${REPO:-https://raw.githubusercontent.com/rsnemmen/omp-theme-selector/main}"
CMD_NAME="omp-theme"

die() {
  echo "Error: $*" >&2
  exit 1
}

echo "==> Installing $CMD_NAME..."

if ! command -v curl >/dev/null 2>&1; then
  die "'curl' is required to install $CMD_NAME."
fi

# Check dependencies (warn, don't abort)
for dep in fzf oh-my-posh; do
  if ! command -v "$dep" >/dev/null 2>&1; then
    echo "  Warning: '$dep' not found. Install it before running $CMD_NAME."
  fi
done

# Determine install directory
if [[ -n "${INSTALL_DIR:-}" ]]; then
  echo "==> Using custom install directory: $INSTALL_DIR"
elif [[ -d "$HOME/.local/bin" ]] && [[ ":$PATH:" == *":$HOME/.local/bin:"* ]]; then
  INSTALL_DIR="$HOME/.local/bin"
elif [[ -w "/usr/local/bin" ]]; then
  INSTALL_DIR="/usr/local/bin"
else
  INSTALL_DIR="$HOME/.local/bin"
fi

mkdir -p "$INSTALL_DIR" || die "could not create install directory: $INSTALL_DIR"
[[ -d "$INSTALL_DIR" ]] || die "install path is not a directory: $INSTALL_DIR"
[[ -w "$INSTALL_DIR" ]] || die "install directory is not writable: $INSTALL_DIR"

DEST="$INSTALL_DIR/$CMD_NAME"
tmp_file=$(mktemp "${TMPDIR:-/tmp}/$CMD_NAME.XXXXXX") || die "could not create temporary file."
trap 'rm -f "$tmp_file"' EXIT

echo "==> Downloading $CMD_NAME to $DEST..."
curl -fsSL "$REPO/omp-theme.sh" -o "$tmp_file" || die "download failed from $REPO/omp-theme.sh"

echo "==> Making $DEST executable..."
mv "$tmp_file" "$DEST"
chmod +x "$DEST"

echo ""
echo "    Installed: $DEST"
echo ""

# Warn if install dir is not in PATH
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
  echo "  Note: $INSTALL_DIR is not in your PATH."
  echo "  Add this to your shell init file (~/.bashrc, ~/.zshrc, etc.):"
  echo ""
  echo "    export PATH=\"\$PATH:$INSTALL_DIR\""
  echo ""
else
  echo "    Run it with: $CMD_NAME"
  echo ""
fi
