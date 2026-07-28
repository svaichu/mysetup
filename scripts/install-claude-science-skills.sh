#!/usr/bin/env bash
# Restores claude-science/skills/ from this repo into the current Claude
# Science org's skills dir on a fresh install.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$REPO_DIR/claude-science/skills"

if [[ ! -d "$SRC" ]] || [[ -z "$(ls -A "$SRC" 2>/dev/null)" ]]; then
  echo "No Claude Science skills found at $SRC, skipping" >&2
  exit 0
fi

ORG_SKILLS_DIR="$(find "$HOME/.claude-science/orgs" -mindepth 2 -maxdepth 2 -type d -name skills 2>/dev/null | head -n1 || true)"

if [[ -z "$ORG_SKILLS_DIR" ]]; then
  echo "Claude Science not set up yet (no ~/.claude-science/orgs/*/skills found), skipping" >&2
  exit 0
fi

cp -r "$SRC"/. "$ORG_SKILLS_DIR"/
echo "Claude Science skills installed to $ORG_SKILLS_DIR"
