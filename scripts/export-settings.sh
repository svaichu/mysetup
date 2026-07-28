#!/usr/bin/env bash
# Re-captures the current machine's XFCE settings into config/xfce4/.
# Run this after you tweak panel/theme/shortcuts/terminal settings, so the
# repo stays in sync with what's actually on your machine.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$HOME/.config/xfce4/xfconf/xfce-perchannel-xml"
DEST="$REPO_DIR/config/xfce4/xfconf/xfce-perchannel-xml"

CHANNELS=(
  xfce4-panel
  xfce4-desktop
  xfwm4
  xfce4-keyboard-shortcuts
  xfce4-terminal
  xsettings
  keyboard-layout
)

mkdir -p "$DEST"
for ch in "${CHANNELS[@]}"; do
  cp "$SRC/${ch}.xml" "$DEST/${ch}.xml"
  echo "exported $ch"
done

mkdir -p "$REPO_DIR/config/redshift" "$REPO_DIR/config/autostart"
cp "$HOME/.config/redshift.conf" "$REPO_DIR/config/redshift/redshift.conf"
cp "$HOME/.config/autostart/redshift-gtk.desktop" "$REPO_DIR/config/autostart/redshift-gtk.desktop"
echo "exported redshift"

mkdir -p "$REPO_DIR/config/devilspie2"
cp "$HOME/.config/devilspie2/"*.lua "$REPO_DIR/config/devilspie2/"
cp "$HOME/.config/autostart/devilspie2.desktop" "$REPO_DIR/config/autostart/devilspie2.desktop"
echo "exported devilspie2"

WALLPAPER="$HOME/Downloads/bg.png"
if [[ -f "$WALLPAPER" ]]; then
  mkdir -p "$REPO_DIR/config/wallpaper"
  cp "$WALLPAPER" "$REPO_DIR/config/wallpaper/bg.png"
  echo "exported wallpaper"
fi

mkdir -p "$REPO_DIR/config/git"
cp "$HOME/.gitconfig" "$REPO_DIR/config/git/gitconfig"
cp "$HOME/.config/git/ignore" "$REPO_DIR/config/git/ignore"
echo "exported gitconfig"

mkdir -p "$REPO_DIR/config/ssh"
cp "$HOME/.ssh/config" "$REPO_DIR/config/ssh/config"
echo "exported ssh config"

echo "Settings captured into $REPO_DIR/config"
echo "Review with: git -C \"$REPO_DIR\" diff"
