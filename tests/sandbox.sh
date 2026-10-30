#!/usr/bin/env bash
# Runs the suite (or the named tests) in a private session that never touches the desktop it runs on:
#   bash tests/sandbox.sh                       every tests/test_*.sh (tests/run.sh)
#   bash tests/sandbox.sh test_island.sh ...    only these
#   bash tests/sandbox.sh --up                  start it and leave it up; prints `source <dir>/env`
#   bash tests/sandbox.sh --down <dir>          stop one started with --up
# Nothing is drawn on a real screen: a headless mutter (no outputs, GPU render node only) hosts a nested
# Hyprland whose two outputs SANDBOX-1/SANDBOX-2 (1920x1080) are headless too. Everything gets its own
# XDG_RUNTIME_DIR, session bus, HOME (copies of ~/.config/{hush,hypr,...}), PipeWire with null devices
# and a fake backlight, so `qs -c hush ipc`, hyprctl, grim, wpctl, notify-send, gsettings and the MPRIS
# fake resolve to the sandbox. Input goes through Wayland virtual-keyboard/pointer (tests/lib/input.sh)
# instead of uinput, which would reach the real compositor. Teardown kills every process that carries
# the sandbox's XDG_RUNTIME_DIR.
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
KEEP=0
sandbox_pids() { # every process started inside the sandbox (they all inherit its XDG_RUNTIME_DIR)
  local p
  for p in /proc/[0-9]*; do
    [[ "${p#/proc/}" == "$$" ]] && continue
    { tr '\0' '\n' <"$p/environ"; } 2>/dev/null | grep -qxF "XDG_RUNTIME_DIR=$RUN" && echo "${p#/proc/}"
  done
}
teardown() {
  [[ $KEEP == 1 ]] && return
  local i pids
  pids=$(sandbox_pids); [[ -n "$pids" ]] && kill $pids 2>/dev/null
  for ((i = 0; i < 30; i++)); do pids=$(sandbox_pids); [[ -z "$pids" ]] && break; sleep 0.1; done
  [[ -n "$pids" ]] && kill -KILL $pids 2>/dev/null
  rm -rf "$RUN"; [[ "${HUSH_SANDBOX_DEBUG:-0}" == 1 ]] && say "kept $SB" || rm -rf "$SB"
}
case "${1:-}" in
  --down)
    [[ -f "${2:-}/env" ]] || { echo "usage: sandbox.sh --down <dir printed by --up>" >&2; exit 2; }
    SB=$2; RUN=$(sed -n 's/^export XDG_RUNTIME_DIR=//p' "$SB/env"); [[ $RUN == /tmp/hs.* ]] || exit 1
    teardown; exit 0 ;;
  --up) KEEP=1; shift ;;
esac
REAL_HOME=$HOME
REAL_CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
SB=$(mktemp -d "${TMPDIR:-/tmp}/hush-sandbox.XXXXXX")
# Hyprland's socket path is $XDG_RUNTIME_DIR/hypr/<60-char signature>/.socket2.sock and must stay under
# 108 bytes, so the runtime dir gets a short name of its own.
RUN=$(mktemp -d /tmp/hs.XXXXXX); chmod 700 "$RUN"
H="$SB/home"
LOG="$SB/log"; mkdir -p "$LOG"

say() { printf '\033[1msandbox:\033[0m %s\n' "$*" >&2; }

trap teardown EXIT
trap 'exit 130' INT TERM

# --- HOME: the live hush state and the configs hush renders into, as copies (several are symlinks into
# other repos; a theme switch in the sandbox must not write through them) ------------------------------
mkdir -p "$H/.config" "$H/.cache" "$H/.local/share" "$H/.local/state" "$H/.local/bin" "$SB/bin"
dirs=()
for d in hush hypr kitty fastfetch Kvantum gtk-3.0 gtk-4.0 qt6ct waybar nvim; do [[ -e "$REAL_CFG/$d" ]] && dirs+=("$d"); done
tar -C "$REAL_CFG" -chf - --exclude=hypr/plugins --exclude=nvim/lazy-lock.json "${dirs[@]}" 2>/dev/null | tar -C "$H/.config" -xf -
mkdir -p "$H/.config/quickshell" "$H/.config/hush"
ln -sfn "$ROOT/quickshell/hush" "$H/.config/quickshell/hush"
ln -sfn "$ROOT/matugen" "$H/.config/matugen"
ln -sfn "$ROOT/hyprlock" "$H/.config/hyprlock"
ln -sfn "$ROOT/hypr/plugins.lua" "$H/.config/hush/plugins.lua"
for b in hush hush-wallgen hush-fonts hush-gtk; do ln -sfn "$ROOT/bin/$b" "$H/.local/bin/$b"; done
# read-only things the shell and the toolkits look up under HOME
for d in fonts icons themes bin dbus-1; do [[ -e "$REAL_HOME/.local/share/$d" ]] && ln -sfn "$REAL_HOME/.local/share/$d" "$H/.local/share/$d"; done
for d in .fonts .icons .themes; do [[ -e "$REAL_HOME/$d" ]] && ln -sfn "$REAL_HOME/$d" "$H/$d"; done
touch "$H/.zshrc" # else zsh runs its new-user wizard in every kitty, and kitty asks before closing
[[ -f "$REAL_HOME/.face" ]] && cp -f "$REAL_HOME/.face" "$H/.face"

# Hyprland: the user's modules and plugins (as ~/.config/hypr/hyprland.lua loads them) on two headless
# outputs; no autostart (it exports the environment to systemd) and no host window.
cat > "$H/.config/hypr/hyprland.lua" <<LUA
-- written by tests/sandbox.sh
local real = "$REAL_HOME"
for _, so in ipairs({ real .. "/.config/hypr/plugins/dynamic-cursors.so" }) do
    local f = io.open(so, "r")
    if f and hl.plugin and hl.plugin.load then f:close(); pcall(hl.plugin.load, so) end
end
hl.monitor({ output = "SANDBOX-1", mode = "1920x1080@60", position = "0x0", scale = 1 })
hl.monitor({ output = "SANDBOX-2", mode = "1920x1080@60", position = "1920x0", scale = 1 })
hl.monitor({ output = "WAYLAND-1", disabled = true })
for _, m in ipairs({ "env", "decorations", "layout", "misc", "input", "windowrules", "layerrules", "binds" }) do
    local ok, err = pcall(require, "modules." .. m)
    if not ok then print("sandbox: modules." .. m .. ": " .. tostring(err)) end
end
pcall(dofile, os.getenv("HOME") .. "/.config/hypr/hyprland-gui.lua")
hl.config({ misc = { disable_hyprland_logo = true, disable_splash_rendering = true, disable_watchdog_warning = true } })
LUA

# PipeWire with a null sink and source; WirePlumber without device monitors (they would claim the
# real sound card and Bluetooth endpoints).
mkdir -p "$H/.config/pipewire/pipewire.conf.d" "$H/.config/wireplumber/wireplumber.conf.d"
cat > "$H/.config/pipewire/pipewire.conf.d/sandbox.conf" <<'CONF'
context.objects = [
  { factory = adapter args = { factory.name = support.null-audio-sink node.name = "hush-sandbox-sink"
      node.description = "Sandbox speakers" media.class = Audio/Sink audio.position = [ FL FR ] } }
  { factory = adapter args = { factory.name = support.null-audio-sink node.name = "hush-sandbox-mic"
      node.description = "Sandbox microphone" media.class = Audio/Source audio.position = [ FL FR ] } }
]
CONF
cat > "$H/.config/wireplumber/wireplumber.conf.d/sandbox.conf" <<'CONF'
wireplumber.profiles = {
  main = {
    monitor.alsa = disabled
    monitor.alsa-midi = disabled
    monitor.bluez = disabled
    monitor.bluez-midi = disabled
    monitor.v4l2 = disabled
    monitor.libcamera = disabled
  }
}
CONF

# A backlight the shell can read and brightnessctl (stubbed) can write.
mkdir -p "$SB/backlight/sandbox"; echo 1000 > "$SB/backlight/sandbox/max_brightness"; echo 600 > "$SB/backlight/sandbox/brightness"
cat > "$SB/bin/brightnessctl" <<'SH'
#!/usr/bin/env bash
# brightnessctl for the test sandbox: get/set on $HUSH_BACKLIGHT_DIR/*/ (the subset hush and the tests use)
d=$(ls -d "$HUSH_BACKLIGHT_DIR"/*/ | head -1); max=$(cat "$d/max_brightness"); cur=$(cat "$d/brightness")
args=(); for a in "$@"; do case "$a" in -q|--quiet|-m|--machine-readable|--min-value=*) ;; *) args+=("$a") ;; esac; done
case "${args[0]:-}" in
  g|get) echo "$cur" ;;
  m|max) echo "$max" ;;
  s|set)
    v=${args[1]}; case "$v" in
      *%+) n=$((cur + max * ${v%\%+} / 100)) ;; *%-) n=$((cur - max * ${v%\%-} / 100)) ;;
      *%) n=$((max * ${v%\%} / 100)) ;; *+) n=$((cur + ${v%+})) ;; *-) n=$((cur - ${v%-})) ;; *) n=$v ;;
    esac
    ((n < 0)) && n=0; ((n > max)) && n=$max; echo "$n" > "$d/brightness" ;;
  *) echo "sandbox,backlight,$cur,$((cur * 100 / max))%,$max" ;;
esac
SH
chmod +x "$SB/bin/brightnessctl"

# --- environment ---------------------------------------------------------------------------------
ENVF="$SB/env"
{
  echo "unset DISPLAY WAYLAND_SOCKET SWAYSOCK PIPEWIRE_REMOTE PULSE_SERVER HYPRLAND_INSTANCE_SIGNATURE HUSH_WALL_DIRS"
  printf 'export %s=%q\n' HOME "$H" XDG_CONFIG_HOME "$H/.config" XDG_CACHE_HOME "$H/.cache" \
    XDG_DATA_HOME "$H/.local/share" XDG_STATE_HOME "$H/.local/state" XDG_RUNTIME_DIR "$RUN" \
    DBUS_SESSION_BUS_ADDRESS "unix:path=$RUN/bus" PATH "$SB/bin:$H/.local/bin:$PATH" \
    PYTHONUSERBASE "${PYTHONUSERBASE:-$REAL_HOME/.local}" HUSH_SANDBOX 1 \
    HUSH_BACKLIGHT_DIR "$SB/backlight" HUSH_EVIDENCE_DIR "$SB/evidence" \
    QT_NO_XDG_DESKTOP_PORTAL 1 # the sandbox bus activates a portal that refuses Qt's app-ID registration
} > "$ENVF"
# shellcheck disable=SC1090
source "$ENVF"

up() { # name cmd... : start a sandbox daemon, logging to $LOG/name.log
  local n=$1; shift
  setsid "$@" >"$LOG/$n.log" 2>&1 </dev/null &
}
die() { KEEP=0; say "$*"; [[ -n "${2:-}" ]] && tail -20 "$2" >&2; exit 1; }
wait_for() { # seconds test...
  local t=$1 i; shift
  for ((i = 0; i < t * 10; i++)); do "$@" >/dev/null 2>&1 && return 0; sleep 0.1; done
  return 1
}

say "dir $SB, runtime $RUN"
up dbus dbus-daemon --session --nofork --nopidfile --address="$DBUS_SESSION_BUS_ADDRESS"
wait_for 5 test -S "$RUN/bus" || die "session bus did not start" "$LOG/dbus.log"
up mutter mutter --headless --wayland --no-x11 --wayland-display=hs-host --virtual-monitor 1280x720
wait_for 10 test -S "$RUN/hs-host" || die "headless mutter did not start" "$LOG/mutter.log"
up pipewire pipewire
up wireplumber wireplumber
WAYLAND_DISPLAY=hs-host up hyprland Hyprland -c "$H/.config/hypr/hyprland.lua"
# hyprland.lock holds the pid and, once the Wayland socket is up, its name
lock_ready() { local l; l=$(compgen -G "$RUN/hypr/*/hyprland.lock" | head -1) && [[ -S "$(dirname "$l")/.socket.sock" && $(sed -n 2p "$l") == wayland-* ]]; }
wait_for 20 lock_ready || die "nested Hyprland did not start" "$LOG/hyprland.log"
lockf=$(compgen -G "$RUN/hypr/*/hyprland.lock" | head -1)
sig=$(basename "$(dirname "$lockf")"); wl=$(sed -n 2p "$lockf")
export HYPRLAND_INSTANCE_SIGNATURE=$sig WAYLAND_DISPLAY=$wl
wait_for 10 hyprctl version || die "hyprctl cannot reach the nested Hyprland" "$LOG/hyprland.log"
printf 'export %s=%q\n' HYPRLAND_INSTANCE_SIGNATURE "$sig" WAYLAND_DISPLAY "$wl" >> "$ENVF"
# The host has no input devices, so the seat starts with no pointer or keyboard and clients would never
# see hover or key focus: keep a virtual pointer and a virtual keyboard plugged in for the whole run.
source "$ROOT/tests/lib.sh"; source "$ROOT/tests/lib/input.sh"
_input_vpointer || die "cannot build tests/lib/vpointer (needs cc, wayland-scanner, wayland-client)"
up vpointer "$_INPUT_VP" hold seat
up keyboard wtype -s 2000000000
hyprctl output create headless SANDBOX-1 >/dev/null
hyprctl output create headless SANDBOX-2 >/dev/null
mons_ready() { [[ $(hyprctl -j monitors | python3 -c 'import json,sys; print(" ".join(sorted(m["name"] for m in json.load(sys.stdin))))') == "SANDBOX-1 SANDBOX-2" ]]; }
wait_for 10 mons_ready || die "headless outputs missing: $(hyprctl monitors | grep ^Monitor)"
wait_for 10 wpctl inspect @DEFAULT_AUDIO_SINK@ || die "sandbox PipeWire has no default sink" "$LOG/wireplumber.log"
up awww awww-daemon
wait_for 5 awww query || say "awww-daemon not answering (wallpaper checks will say so)"
hush reload >"$LOG/reload.log" 2>&1 || say "hush reload failed (see $LOG/reload.log)"
hush shell start >"$LOG/shell-start.log" 2>&1 || die "the sandbox shell did not start" "$H/.cache/hush/shell.log"
# A desktop has windows (the launcher's window list and the tiled-zone checks need some): one per output.
for m in SANDBOX-2 SANDBOX-1; do
  hyprctl dispatch "hl.dsp.focus({ monitor = \"$m\" })" >/dev/null
  hyprctl dispatch 'hl.dsp.exec_cmd("kitty --class hush-sandbox-term")' >/dev/null
  n_terms() { [[ $(hyprctl clients | grep -c 'class: hush-sandbox-term') -ge $1 ]]; }
  wait_for 10 n_terms $([[ $m == SANDBOX-2 ]] && echo 1 || echo 2) || say "kitty did not open on $m"
done
say "up: Hyprland $sig on $wl, outputs SANDBOX-1 SANDBOX-2, shell $(qs -c hush ipc call hush ping 2>/dev/null)"

if [[ $KEEP == 1 ]]; then
  say "left up. Use it with:  source $ENVF    stop it with:  bash $ROOT/tests/sandbox.sh --down $SB"
  exit 0
fi
cd "$ROOT/tests"
if (($# == 0)); then
  bash run.sh; rc=$?
else
  pass=0 failn=0 rc=0
  for t in "$@"; do
    t=$(basename "$t"); echo "=== $t ==="
    if bash "$t"; then pass=$((pass + 1)); else failn=$((failn + 1)); rc=1; fi
  done
  echo "$pass PASS $failn FAIL 0 SKIP"
fi
exit $rc
