#!/usr/bin/env bash
# Restores claude/skills/ from this repo into ~/.claude/skills/ on a fresh install.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$REPO_DIR/claude/skills"
DEST="$HOME/.claude/skills"

if [[ ! -d "$SRC" ]]; then
  echo "No skills found at $SRC" >&2
  exit 1
fi

mkdir -p "$DEST"
cp -r "$SRC"/. "$DEST"/
echo "Skills installed to $DEST"
