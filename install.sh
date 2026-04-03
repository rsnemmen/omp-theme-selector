#!/usr/bin/env bash
set -euo pipefail

REPO="https://raw.githubusercontent.com/rsnemmen/omp-theme-selector/main"
CMD_NAME="omp-theme"

echo "==> Installing $CMD_NAME..."

# Check dependencies (warn, don't abort)
for dep in fzf oh-my-posh; do
  if ! command -v "$dep" &>/dev/null; then
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
  mkdir -p "$INSTALL_DIR"
fi

DEST="$INSTALL_DIR/$CMD_NAME"

echo "==> Downloading $CMD_NAME to $DEST..."
curl -fsSL "$REPO/omp-theme.sh" -o "$DEST"

echo "==> Making $DEST executable..."
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
