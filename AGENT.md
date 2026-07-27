# AGENT.md

## What this repo is

Reproduces this machine's Debian/Ubuntu + XFCE setup on a fresh install:
apps, XFCE settings (panel/theme/shortcuts/terminal), window management,
Claude skills, wallpaper, git config, ssh config, and bash aliases/functions.

## How it works — read this before changing anything

Every settings area follows the same two-way pattern:

- `scripts/export-*.sh` — pulls the **live machine's** current state into
  `config/` (or `claude/`, `claude-science/`). Run this after you change a
  setting on the machine, so the repo catches up.
- `scripts/install-*.sh` / `scripts/apply-*.sh` — pushes what's in the repo
  **onto the machine**. Run on a fresh install, or to restore a setting.
- `setup.sh` is the fresh-install entrypoint. It runs, in order:
  install-apps → apply-settings → install-claude-skills →
  install-claude-science-skills.

When asked to add a new setting/app to track: add both the export and the
apply/install side, and update the "Layout" list in `README.md`. Don't add
one without the other — an export with no apply path is dead weight, and
vice versa.

## Secrets — do not commit

`~/.bashrc`, `~/.ssh/`, and similar dotfiles on this machine contain live
API tokens and private keys (Lightning, HPC, Onshape, HuggingFace, GitLab,
SSH private keys, etc). None of that belongs in this repo:

- `config/bash/aliases.sh` is hand-curated — only aliases/functions, never
  the `export FOO=...` secret lines that sit next to them in the real
  `~/.bashrc`. It is *not* auto-exported from the live file for this
  reason; add to it by hand.
- `config/ssh/config` holds host aliases and `IdentityFile` *paths* only.
  The actual private keys are never copied into this repo — provision them
  separately on a fresh machine.
- Before running any `export-*.sh` script against a new file, check it for
  tokens/keys first — the pattern here is "copy is safe by default", which
  breaks the moment a dotfile mixes config with credentials.

## Files intentionally left alone

`fix-audio.sh` at the repo root is not part of this setup and should be
left untouched (not referenced by `setup.sh`, not documented in the
README) — per owner instruction, ignore additional files that show up in
the repo unless asked to incorporate them.

## Original request (for context)

1. Script for top apps — list lives in `agent/myapps.md`.
2. Script for top settings — XFCE (panel, themes, icons), keyboard
   shortcuts, terminal (colors, fonts).
3. Window management — keep the existing multi-workspace setup and panel
   as-is.
4. Collect Claude skills — Claude Code (`claude/skills/`), Claude Science
   custom skills only (`claude-science/skills/`).
5. Desktop background picture.

Target: latest Debian/Ubuntu-based + XFCE, kept up to date as the machine
changes (see "How it works" above) rather than a one-time snapshot.
