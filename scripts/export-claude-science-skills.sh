#!/usr/bin/env bash
# Re-captures custom Claude Science skills into claude-science/skills/.
#
# Claude Science stores skills per-org under ~/.claude-science/orgs/<org-id>/skills/,
# mixed in with the built-in skills that ship with the runtime (reinstalled
# automatically with the app, so not worth backing up). Only the skills that
# aren't also present in the runtime's own skills/ dir are custom, so those
# are the ones exported here.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="$REPO_DIR/claude-science/skills"

SCIENCE_DIR="$HOME/.claude-science"
ORG_SKILLS_DIR="$(find "$SCIENCE_DIR/orgs" -mindepth 2 -maxdepth 2 -type d -name skills 2>/dev/null | head -n1)"
RUNTIME_SKILLS_DIR="$(find "$SCIENCE_DIR/runtime" -mindepth 2 -maxdepth 2 -type d -name skills 2>/dev/null | sort | tail -n1)"

if [[ -z "$ORG_SKILLS_DIR" ]]; then
  echo "No Claude Science org skills found under $SCIENCE_DIR/orgs" >&2
  exit 1
fi

mkdir -p "$DEST"
rm -rf "${DEST:?}"/*

for skill_dir in "$ORG_SKILLS_DIR"/*/; do
  name="$(basename "$skill_dir")"
  if [[ -n "$RUNTIME_SKILLS_DIR" && -d "$RUNTIME_SKILLS_DIR/$name" ]]; then
    continue # ships with the runtime, not custom
  fi
  rsync -a --exclude '.catalog_stamp' --exclude '.sync-org' "$skill_dir" "$DEST/$name/"
  echo "Exported $name"
done

echo "Claude Science skills exported to $DEST"
