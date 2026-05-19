#!/usr/bin/env bash
# vmap installer.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/eanzhao/vibe-map/main/install.sh | bash
#   ./install.sh                              # latest release from GitHub
#   ./install.sh --version v0.5.0             # pin a specific release tag
#   ./install.sh --local /path/to/vibe-map    # install from a local repo build (dogfood)
#
# Outcome:
#   ~/.local/bin/vmap           binary
#   ~/.vmap/skills/             SKILL.md + cheatsheet.md + vibe-map-bootstrap.md + playbooks/

set -euo pipefail

REPO="eanzhao/vibe-map"
INSTALL_BIN="${HOME}/.local/bin"
INSTALL_SKILLS="${HOME}/.vmap/skills"

LOCAL_REPO=""
VERSION_TAG=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --local)
      [[ $# -ge 2 ]] || { echo "--local needs a path"; exit 2; }
      LOCAL_REPO="$2"; shift 2 ;;
    --version)
      [[ $# -ge 2 ]] || { echo "--version needs a tag"; exit 2; }
      VERSION_TAG="$2"; shift 2 ;;
    -h|--help)
      grep '^#' "$0" | sed 's|^# \?||'
      exit 0 ;;
    *)
      echo "unknown argument: $1" >&2
      echo "run with --help for usage" >&2
      exit 2 ;;
  esac
done

# Detect platform
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)
case "$OS-$ARCH" in
  darwin-arm64)    TARGET=darwin-arm64 ;;
  darwin-x86_64)   TARGET=darwin-x86_64 ;;
  linux-x86_64)    TARGET=linux-x86_64 ;;
  linux-aarch64)   TARGET=linux-arm64 ;;
  *)
    echo "unsupported platform: $OS-$ARCH" >&2
    echo "supported: darwin-arm64 / darwin-x86_64 / linux-x86_64 / linux-arm64" >&2
    exit 1 ;;
esac

mkdir -p "$INSTALL_BIN"
mkdir -p "$(dirname "$INSTALL_SKILLS")"

if [[ -n "$LOCAL_REPO" ]]; then
  # --- Local build path (dogfood / pre-release) ---
  LOCAL_REPO=$(cd "$LOCAL_REPO" && pwd)
  echo "[vmap] installing from local repo: $LOCAL_REPO"
  BIN_SRC="$LOCAL_REPO/_build/native/release/build/cmd/vmap/vmap.exe"
  SKILLS_SRC="$LOCAL_REPO/skills"

  if [[ ! -x "$BIN_SRC" ]]; then
    echo "  release binary not found: $BIN_SRC" >&2
    echo "  build it first: cd $LOCAL_REPO && moon build --target native --release" >&2
    exit 1
  fi
  if [[ ! -d "$SKILLS_SRC" ]]; then
    echo "  skills directory not found: $SKILLS_SRC" >&2
    exit 1
  fi

  install -m 755 "$BIN_SRC" "$INSTALL_BIN/vmap"
  rm -rf "$INSTALL_SKILLS"
  cp -R "$SKILLS_SRC" "$INSTALL_SKILLS"

  VERSION_INFO="(local build from $LOCAL_REPO)"
else
  # --- Production path: GitHub Releases ---
  if [[ -z "$VERSION_TAG" ]]; then
    echo "[vmap] resolving latest release for $REPO..."
    VERSION_TAG=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" \
      | grep -m1 '"tag_name"' | cut -d'"' -f4 || true)
    if [[ -z "$VERSION_TAG" ]]; then
      echo "  could not resolve latest tag (network? rate limit?)." >&2
      echo "  pass --version <tag> explicitly, or check https://github.com/${REPO}/releases" >&2
      exit 1
    fi
  fi
  echo "[vmap] downloading $VERSION_TAG for $TARGET..."

  ARCHIVE="vmap-${TARGET}.tar.gz"
  URL="https://github.com/${REPO}/releases/download/${VERSION_TAG}/${ARCHIVE}"
  TMP=$(mktemp -d)
  trap 'rm -rf "$TMP"' EXIT

  if ! curl -fsSL "$URL" -o "$TMP/$ARCHIVE"; then
    echo "  download failed: $URL" >&2
    echo "  if you're in mainland China, try the jsdelivr mirror or set HTTPS_PROXY" >&2
    exit 1
  fi
  tar xzf "$TMP/$ARCHIVE" -C "$TMP"

  EXTRACTED="$TMP/vmap-${TARGET}"
  install -m 755 "$EXTRACTED/vmap" "$INSTALL_BIN/vmap"
  rm -rf "$INSTALL_SKILLS"
  cp -R "$EXTRACTED/skills" "$INSTALL_SKILLS"

  VERSION_INFO="$VERSION_TAG"
fi

echo
echo "✓ installed vmap   → $INSTALL_BIN/vmap   $VERSION_INFO"
echo "✓ installed skills → $INSTALL_SKILLS/"

# PATH check
case ":$PATH:" in
  *":$INSTALL_BIN:"*)
    ;;
  *)
    echo
    echo "⚠  $INSTALL_BIN is not in your PATH."
    echo "   add this line to ~/.zshrc (or ~/.bashrc / ~/.profile):"
    echo
    echo "     export PATH=\"\$HOME/.local/bin:\$PATH\""
    echo
    echo "   then open a new shell, or run:  source ~/.zshrc"
    ;;
esac

echo
echo "next steps:"
echo "  vmap --version"
echo "  cat $INSTALL_SKILLS/SKILL.md"
echo "  cd <your-project> && vmap init --name '<project>'"
echo
echo "to bootstrap a coding agent:  cat $INSTALL_SKILLS/vibe-map-bootstrap.md"
