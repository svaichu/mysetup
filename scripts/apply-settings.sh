#!/usr/bin/env bash
# Restores XFCE settings (panel, workspaces/window manager, keyboard
# shortcuts, terminal, theme) from config/xfce4/ onto this machine.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$REPO_DIR/config/xfce4/xfconf/xfce-perchannel-xml"
DEST="$HOME/.config/xfce4/xfconf/xfce-perchannel-xml"
BACKUP="$HOME/.config/xfce4/xfconf/xfce-perchannel-xml.bak.$(date +%Y%m%d%H%M%S)"

if [[ ! -d "$SRC" ]]; then
  echo "No exported settings found at $SRC" >&2
  exit 1
fi

mkdir -p "$DEST"
if [[ -n "$(ls -A "$DEST" 2>/dev/null)" ]]; then
  echo "Backing up existing settings to $BACKUP"
  cp -r "$DEST" "$BACKUP"
fi

# xfconfd caches values in memory, so edit files on disk then kill it —
# it respawns on demand and re-reads from disk.
pkill xfconfd 2>/dev/null || true

for f in "$SRC"/*.xml; do
  cp "$f" "$DEST/"
  echo "applied $(basename "$f")"
done

mkdir -p "$HOME/.config/autostart"
cp "$REPO_DIR/config/redshift/redshift.conf" "$HOME/.config/redshift.conf"
cp "$REPO_DIR/config/autostart/redshift-gtk.desktop" "$HOME/.config/autostart/redshift-gtk.desktop"
echo "applied redshift.conf"

if [[ -f "$REPO_DIR/config/wallpaper/bg.png" ]]; then
  mkdir -p "$HOME/Downloads"
  cp "$REPO_DIR/config/wallpaper/bg.png" "$HOME/Downloads/bg.png"
  echo "applied wallpaper (bg.png)"
fi

mkdir -p "$HOME/.config/git"
cp "$REPO_DIR/config/git/gitconfig" "$HOME/.gitconfig"
cp "$REPO_DIR/config/git/ignore" "$HOME/.config/git/ignore"
echo "applied gitconfig"

mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
if [[ -f "$HOME/.ssh/config" ]]; then
  cp "$HOME/.ssh/config" "$HOME/.ssh/config.bak.$(date +%Y%m%d%H%M%S)"
fi
cp "$REPO_DIR/config/ssh/config" "$HOME/.ssh/config"
chmod 600 "$HOME/.ssh/config"
echo "applied ssh config (note: referenced IdentityFiles like id_ed25519_rwth_hpc and lightning_rsa are private keys — copy those in separately, they are not in this repo)"

SOURCE_LINE=". \"$REPO_DIR/config/bash/aliases.sh\""
if [[ -f "$REPO_DIR/config/bash/aliases.sh" ]] && ! grep -qF "$SOURCE_LINE" "$HOME/.bashrc" 2>/dev/null; then
  { echo ""; echo "# mysetup aliases/functions"; echo "$SOURCE_LINE"; } >> "$HOME/.bashrc"
  echo "applied bash aliases (sourced from ~/.bashrc)"
fi

echo "Done. Log out and back in (or run: xfce4-panel -r) to pick everything up."
