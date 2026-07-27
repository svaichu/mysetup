#!/usr/bin/env bash
# Fix Dell 14 Plus 2-in-1 audio (rt722/SOF/PipeWire) per dell-audio skill known issues.
set -euo pipefail

CARD="DellInc.-Dell14Plus2_in_1DB04250--0XWH0W"

echo "== 1. Checking firmware-sof-signed pin =="
if [ -f /etc/apt/preferences.d/firmware-sof-signed ]; then
    echo "Pin already in place:"
    cat /etc/apt/preferences.d/firmware-sof-signed
else
    echo "Pin missing — installing known-good firmware and pinning it."
    sudo apt install -y firmware-sof-signed=2025.05.1-1
    sudo tee /etc/apt/preferences.d/firmware-sof-signed > /dev/null << 'EOF'
Package: firmware-sof-signed
Pin: version 2025.05.1-1
Pin-Priority: 1001
EOF
fi

echo "== 2. Enabling Speaker Switch (UCM workaround) =="
alsaucm -c "$CARD" set _verb HiFi set _enadev Speaker 2>/dev/null || true
# 'Speaker Switch' isn't exposed as a simple control on this hardware —
# name-based amixer set/get fails; use the raw numid instead.
amixer -c 0 cset numid=13 on >/dev/null

echo "== 3. Enabling mic capture switches =="
amixer -c 0 cset numid=6 on,on,on,on >/dev/null   # DMIC array
amixer -c 0 cset numid=2 on,on,on,on >/dev/null 2>&1 || true  # Headset mic

echo "== 4. Setting speaker/headphone volume to max =="
amixer -c 0 cset numid=5 87,87 >/dev/null   # Speaker amp
amixer -c 0 cset numid=1 87,87 >/dev/null 2>&1 || true  # Headphone amp

echo "== 5. Saving ALSA state =="
sudo alsactl store

echo "== 6. Setting WirePlumber default sink to speaker (Pro 2) =="
SPEAKER_ID=$(wpctl status | grep 'pro-output-2\|Pro 2' | grep -v Filters | head -1 | grep -oP '\d+(?=\.)' | head -1)
if [ -n "${SPEAKER_ID:-}" ]; then
    wpctl set-default "$SPEAKER_ID"
    echo "Default sink set to node $SPEAKER_ID (speaker)."
else
    echo "WARNING: could not find speaker (Pro 2) node in wpctl status — check manually."
fi

echo "== Done. Current status: =="
wpctl status | sed -n '/Sinks:/,/Sources:/p'
amixer -c 0 cget numid=13
