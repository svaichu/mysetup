# mysetup

Reproduces my Debian/Ubuntu + XFCE setup on a fresh install.

## Usage

On a fresh machine:

```sh
git clone <this-repo> mysetup
cd mysetup
./setup.sh
```

This runs, in order:

1. `scripts/install-apps.sh` — installs the apps listed in
   `agent/myapps.md` (VS Code, Zotero, KeePassXC, Docker, wmctrl, btop,
   htop, fastfetch, GitHub CLI, redshift, fprintd, Claude Code, stretchly,
   and uv with its full tool list: huggingface-hub, lightning-sdk,
   matlab-proxy, nbterm, syncmymoodle, take-me-cloud, zotero-mcp-server)
   via apt / official installers.
2. `scripts/apply-settings.sh` — restores XFCE panel, window manager
   (workspaces), keyboard shortcuts, terminal, and theme/icon settings from
   `config/xfce4/`, plus the redshift config from `config/redshift/`.
3. `scripts/install-claude-skills.sh` — restores custom Claude Code skills
   from `claude/skills/` into `~/.claude/skills/`.
4. `scripts/install-claude-science-skills.sh` — restores custom Claude
   Science skills from `claude-science/skills/` into the current org's
   `~/.claude-science/orgs/<org-id>/skills/` (no-op if Claude Science isn't
   set up yet).

Log out and back in afterwards so XFCE picks up all the restored settings.

## Keeping the repo in sync

After tweaking panel layout, shortcuts, theme, or terminal colors on the
live machine, re-capture them:

```sh
./scripts/export-settings.sh
git diff
git add -A && git commit -m "Update xfce settings"
```

After adding/editing a Claude Code skill:

```sh
./scripts/export-claude-skills.sh
git diff
git add -A && git commit -m "Update claude skills"
```

After adding/editing a custom Claude Science skill:

```sh
./scripts/export-claude-science-skills.sh
git diff
git add -A && git commit -m "Update claude science skills"
```

## Layout

- `agent/myapps.md` — source list of apps to install.
- `scripts/install-apps.sh` — app install script.
- `scripts/export-settings.sh` — captures live XFCE settings into `config/`.
- `scripts/apply-settings.sh` — restores `config/` settings onto the machine.
- `config/xfce4/xfconf/xfce-perchannel-xml/` — raw xfconf channel exports
  (panel, xfwm4 window manager/workspaces, keyboard shortcuts, terminal,
  xsettings theme/icons, keyboard layout).
- `config/redshift/redshift.conf`, `config/autostart/redshift-gtk.desktop` —
  redshift color-temperature config and its autostart entry.
- `config/wallpaper/bg.png` — desktop background, restored to
  `~/Downloads/bg.png` (the path `xfce4-desktop.xml` points at).
- `claude/skills/` — custom Claude Code skills, mirrored from
  `~/.claude/skills/`.
- `scripts/export-claude-skills.sh` / `scripts/install-claude-skills.sh` —
  sync skills between this repo and `~/.claude/skills/`.
- `claude-science/skills/` — custom Claude Science skills (not the built-in
  ones bundled with the runtime), mirrored from
  `~/.claude-science/orgs/<org-id>/skills/`.
- `scripts/export-claude-science-skills.sh` /
  `scripts/install-claude-science-skills.sh` — sync Claude Science skills
  between this repo and `~/.claude-science/orgs/<org-id>/skills/`.
