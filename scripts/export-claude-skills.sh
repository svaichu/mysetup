#!/usr/bin/env bash
# Re-captures ~/.claude/skills/ into claude/skills/ so custom skills survive a reinstall.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$HOME/.claude/skills"
DEST="$REPO_DIR/claude/skills"

mkdir -p "$DEST"
rsync -a --delete "$SRC/" "$DEST/"
echo "Skills exported to $DEST"
