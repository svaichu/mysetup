#!/usr/bin/env bash
# Installs the core app set on a fresh Debian/Ubuntu + XFCE install.
set -euo pipefail

if [[ $EUID -eq 0 ]]; then
  echo "Run this as your normal user, not root (it uses sudo where needed)." >&2
  exit 1
fi

sudo apt-get update

# --- Plain apt packages -----------------------------------------------
APT_PACKAGES=(
  keepassxc
  wmctrl
  btop
  htop
  fastfetch
  gh
  redshift
  redshift-gtk
  fprintd
)
sudo apt-get install -y "${APT_PACKAGES[@]}"

# --- VS Code (Microsoft apt repo) --------------------------------------
if ! command -v code >/dev/null 2>&1; then
  sudo apt-get install -y wget gpg apt-transport-https
  wget -qO- https://packages.microsoft.com/keys/microsoft.asc \
    | gpg --dearmor > /tmp/packages.microsoft.gpg
  sudo install -D -o root -g root -m 644 /tmp/packages.microsoft.gpg \
    /etc/apt/keyrings/packages.microsoft.gpg
  echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
    | sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null
  rm -f /tmp/packages.microsoft.gpg
  sudo apt-get update
  sudo apt-get install -y code
fi

# --- Zotero (official tarball, installed to ~/.local/share) ------------
if ! command -v zotero >/dev/null 2>&1; then
  wget -qO /tmp/zotero.tar.bz2 "https://www.zotero.org/download/client/dl?platform=linux-x86_64&channel=release"
  mkdir -p "$HOME/.local/share/zotero"
  tar -xjf /tmp/zotero.tar.bz2 --strip-components=1 -C "$HOME/.local/share/zotero"
  rm -f /tmp/zotero.tar.bz2
  "$HOME/.local/share/zotero/set_launcher_icon"
  mkdir -p "$HOME/.local/share/applications"
  desktop-file-install --dir="$HOME/.local/share/applications" \
    --set-key=Exec --set-value="$HOME/.local/share/zotero/zotero -url %u" \
    "$HOME/.local/share/zotero/zotero.desktop" 2>/dev/null \
    || cp "$HOME/.local/share/zotero/zotero.desktop" "$HOME/.local/share/applications/"
  ln -sf "$HOME/.local/share/zotero/zotero" "$HOME/.local/bin/zotero" 2>/dev/null || true
fi

# --- Docker (official convenience script) -------------------------------
if ! command -v docker >/dev/null 2>&1; then
  curl -fsSL https://get.docker.com | sudo sh
  sudo usermod -aG docker "$USER"
  echo "Added $USER to the docker group — log out/in for it to take effect."
fi

# --- Claude Code (official installer) -----------------------------------
if ! command -v claude >/dev/null 2>&1; then
  curl -fsSL https://claude.ai/install.sh | bash
fi

# --- uv + uv tool installs ------------------------------------------------
if ! command -v uv >/dev/null 2>&1; then
  curl -LsSf https://astral.sh/uv/install.sh | sh
fi
UV_TOOLS=(
  huggingface-hub
  lightning-sdk
  matlab-proxy
  nbterm
  syncmymoodle
  take-me-cloud
  zotero-mcp-server
)
for tool in "${UV_TOOLS[@]}"; do
  "$HOME/.local/bin/uv" tool install "$tool"
done

# --- stretchly (break reminders, GitHub release .deb) --------------------
if ! command -v stretchly >/dev/null 2>&1; then
  STRETCHLY_URL="$(curl -fsSL https://api.github.com/repos/hovancik/stretchly/releases/latest \
    | grep -o '"browser_download_url": *"[^"]*amd64\.deb"' \
    | head -1 | cut -d'"' -f4)"
  wget -qO /tmp/stretchly.deb "$STRETCHLY_URL"
  sudo apt-get install -y /tmp/stretchly.deb
  rm -f /tmp/stretchly.deb
fi

echo "Done. Some apps (Zotero) may need a manual follow-up — see notes above."
