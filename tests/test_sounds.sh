#!/usr/bin/env bash
# Every event in services/Sounds.qml has a WAV in quickshell/hush/sounds within its tier's length and peak.
source "$(dirname "$0")/lib.sh"
cd "$(dirname "$0")/.."
t_sounds() {
  local out; out=$(python3 - <<'EOF'
import re, wave, numpy as np
events = re.findall(r'"([a-z-]+)"', re.search(r"events: \[(.*?)\]", open("quickshell/hush/services/Sounds.qml").read(), re.S).group(1))
bad = []
for e in events:
    try:
        w = wave.open(f"quickshell/hush/sounds/{e}.wav")
        x = np.frombuffer(w.readframes(w.getnframes()), "<i2") / 32768
        peak, secs = 20 * np.log10(np.abs(x).max()), len(x) / w.getframerate()
        limit = -4 if "critical" in e else -8 if e in ("battery-low", "timer-done", "focus-end") else -12
        if w.getframerate() != 48000 or peak > limit + 0.1 or not 0.05 < secs < 2.5: bad.append(f"{e} {peak:.1f}dB {secs:.2f}s")
    except FileNotFoundError:
        bad.append(f"{e} missing")
print(len(events), ";".join(bad) or "ok")
EOF
)
  assert_eq "13 ok" "$out" "13 events, each with a 48 kHz WAV inside its peak and length"
}
run_test "sounds" t_sounds
finish
