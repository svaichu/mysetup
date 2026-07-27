#!/usr/bin/env bash
# Entry point: reproduce this machine's setup on a fresh Debian/Ubuntu + XFCE install.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"$DIR/scripts/install-apps.sh"
"$DIR/scripts/apply-settings.sh"
"$DIR/scripts/install-claude-skills.sh"
"$DIR/scripts/install-claude-science-skills.sh"

echo
echo "Setup complete. Log out and back in for all XFCE settings to take effect."
