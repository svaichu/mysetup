# dell-audio

Diagnose and fix audio issues on the Dell 14 Plus 2-in-1 (Intel Core Ultra 5 Lunar Lake) running Xubuntu 25.10. Covers the full PipeWire + SOF + rt722 SoundWire stack.

| Field    | Value       |
|----------|-------------|
| Skill    | dell-audio  |
| Version  | 1.0.0       |
| Author   | vaishnavahari |

---

## Hardware

- **Machine**: Dell 14 Plus 2-in-1 (DB04250, service tag 0XWH0W)
- **Codec**: Realtek rt722-sdca (`sdw:0:0:025d:0722:01`)
- **Driver**: `sof-soundwire` (Sound Open Firmware + SoundWire)
- **Audio stack**: PipeWire 1.4.7 + WirePlumber + pipewire-pulse
- **Card name**: `DellInc.-Dell14Plus2_in_1DB04250--0XWH0W`
- **UCM card**: `sof-soundwire/rt722.conf`

### rt722 SDCA functions
- UAJ — Headphone/headset jack
- SmartMic — Built-in digital mic array (DMIC)
- SmartAmp — Built-in speakers
- HID — Hardware buttons

---

## Known Issues & Fixes

### 1. No audio at all (SOF topology ABI mismatch)

**Symptom**: `sof_pcm_setup_connected_widgets: pcm2 (Speaker), dir 0: Widget list set up failed` in kern.log. No sound from any device.

**Root cause**: `firmware-sof-signed` upgrade to `2025.05.1-1ubuntu0.1` introduces topology files with ABI 3:29:1, incompatible with kernel 6.17's ABI 3:23 support.

**Fix**: Downgrade and pin:
```bash
sudo apt install firmware-sof-signed=2025.05.1-1
sudo tee /etc/apt/preferences.d/firmware-sof-signed << 'EOF'
Package: firmware-sof-signed
Pin: version 2025.05.1-1
Pin-Priority: 1001
EOF
```
Then reboot.

**Verify pin is in place**:
```bash
cat /etc/apt/preferences.d/firmware-sof-signed
apt-cache policy firmware-sof-signed
```

---

### 2. Speaker Switch resets to off (UCM not activating Speaker device)

**Symptom**: Sound worked briefly then stopped. `amixer -c 0 get 'Speaker Switch'` shows `[off]`. Happens because WirePlumber's UCM integration finds empty `CardComponents`, never detects the rt722 codec, and never calls the UCM Speaker EnableSequence.

**Temporary fix** (run after each boot or whenever speaker stops):
```bash
alsaucm -c 'DellInc.-Dell14Plus2_in_1DB04250--0XWH0W' set _verb HiFi set _enadev Speaker
```

Or just the ALSA switch directly:
```bash
amixer -c 0 set 'Speaker Switch' on
```

**No persistent fix available** — WirePlumber CardComponents detection for this hardware is broken upstream.

---

### 3. Microphone capture switch off

**Symptom**: Mic not working. `amixer -c 0 cget numid=6` shows `values=off,off,off,off`.

**Fix**:
```bash
amixer -c 0 cset numid=6 on,on,on,on
```

Save persistently:
```bash
sudo alsactl store
```

---

### 4. Low speaker volume (rt722 FU06 not at max)

**Symptom**: Volume sounds low even at 100% in the mixer.

**Check**:
```bash
amixer -c 0 cget numid=5   # rt722 FU06 Playback Volume, max=87
```

**Fix**:
```bash
amixer -c 0 cset numid=5 87,87
sudo alsactl store
```

---

### 5. WirePlumber default sink lost on reboot

**Symptom**: Default audio output switches away from speakers after reboot (node IDs are dynamic and change each boot).

**Check current default**:
```bash
wpctl status | grep -A10 'Sinks'
```

**Set default by persistent name** (not node number — those change):
```bash
wpctl set-default $(wpctl status | grep 'Pro 2' | grep -v Filters | awk '{print $1}' | tr -d '.')
```

The persistent sink name in WirePlumber settings is:
`alsa_output.pci-0000_00_1f.3-platform-sof_sdw.pro-output-2`

---

## Volume Controls Reference

| Control | numid | What it controls | Max |
|---------|-------|-----------------|-----|
| `rt722 FU06 Playback Volume` | 5 | Speaker amplifier (codec level) | 87 |
| `rt722 FU05 Playback Volume` | 1 | Headphone amplifier | 87 |
| `rt722 FU0F Capture Volume` | 3 | Headset mic gain | 63 |
| `rt722 FU0F Capture Switch` | 2 | Headset mic mute | — |
| `rt722 FU1E Capture Volume` | 7 | Built-in DMIC array gain | 63 |
| `rt722 FU1E Capture Switch` | 6 | Built-in DMIC mute | — |
| `Post Mixer Speaker Playback Volume` | — | DSP post-mixer speaker | 45 |
| `Pre Mixer Speaker Playback Volume` | — | DSP pre-mixer speaker | 45 |
| `Speaker Switch` | — | Speaker hardware enable | on/off |

---

## WirePlumber Node Names (Pro numbers)

Pro numbers (node IDs) change every boot. Use `wpctl status` to find current IDs.

- **Pro 2** — Speaker output (main sink)
- **Pro 31** — Headphone/UAJ output  
- **Pro 1** — Built-in microphone (SmartMic, default source)
- **Pro 4** — Alternate capture node

---

## Useful Diagnostic Commands

```bash
# Full audio status
wpctl status

# Check SOF errors in kernel log
sudo grep -i 'sof\|soundwire\|rt722' /var/log/kern.log | tail -30

# List all ALSA mixer controls
amixer -c 0 contents

# Check firmware version
dpkg -l firmware-sof-signed

# Test speaker (requires PipeWire to be running — uses pw-play not ALSA direct)
pw-play /usr/share/sounds/alsa/Front_Center.wav

# Check VA-API (for Firefox hardware video)
vainfo --display drm --device /dev/dri/renderD128
```

---

## Firefox Hardware Video Acceleration

- Use **Firefox deb** (from Mozilla PPA), not snap — snap's seccomp sandbox blocks DRM ioctls needed for VA-API.
- Mozilla PPA pin: `/etc/apt/preferences.d/mozilla-firefox`
- VA-API driver: `iHD` (Intel media driver)
- Set in `~/.xprofile`:
  ```bash
  export LIBVA_DRIVER_NAME=iHD
  export MOZ_X11_EGL=1
  ```
- AppArmor fix for user namespace sandbox: `/etc/apparmor.d/local/firefox`
- Firefox prefs needed: `media.ffmpeg.vaapi.enabled=true`, `media.hardware-video-decoding.force-enabled=true`

---

## Files Modified

| File | Purpose |
|------|---------|
| `/etc/apt/preferences.d/firmware-sof-signed` | Pin broken firmware version |
| `/etc/apt/preferences.d/mozilla-firefox` | Pin Mozilla PPA Firefox |
| `~/.xprofile` | VA-API env vars for X11 session |
| `/etc/apparmor.d/local/firefox` | Allow Firefox user namespace sandbox |
| `/var/lib/alsa/asound.state` | Saved ALSA mixer state (via alsactl store) |
