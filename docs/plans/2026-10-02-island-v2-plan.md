# Hush Island v2 plan (0.2.0)

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development, MIN-COST MODE (one review per phase, Sonnet unless a task says Opus, terse prompts, ledger lines not essays). Steps use checkbox syntax.

**Goal:** Replace the v1 island and corners with the design in `docs/design/2026-10-02-hush-island-v2-design.md` (sections 2.1–2.10), approved by the maintainer on 2026-10-02 with all four decisions accepted (corners removed; reserve 40 px default; SDDM via one sudo run; workspace overview deferred to 0.3).

**Repo:** `~/hush` (branch main). Personal config stays in `~/dotfiles`; never commit there during this plan except the final cleanup phase.

**Stack:** Quickshell 0.3.1 (QtQuick, SpringAnimation, Variants, PanelWindow with WlrLayershell, Region masks, HyprlandFocusGrab, IpcHandler), Hyprland 0.56 Lua config, matugen 4.2, awww, hyprlock 0.9.6, SDDM (Qt6 greeter), bash tests under `tests/`, `qmltestrunner` for QML unit tests if `/usr/lib/qt6/bin/qmltestrunner` exists (else a headless `qs` config driven over IPC).

## Global constraints
- No sudo in agents; never hyprlock/hypridle/loginctl on the live session; never kill Hyprland; nested Hyprland for lock-screen tests.
- Live desktop stays usable: every task ends with `hush shell restart`, `ping` = pong, theme unchanged, island collapsed.
- Two monitors may be connected; nothing hardcodes a monitor name or a home path; `tests/test_no_personal.sh` must stay green.
- Commits: ONE per task, Conventional Commit with a body (what and why), tests green first (`bash tests/run_all.sh`), no fixup streams. Tag only at the end (v0.2.0).
- Evidence: screenshots (grim) into `~/.cache/hush/evidence/` (not committed) and a line per task in `docs/evidence/2026-10-02-island-v2.md`; the final README screenshots are committed under `assets/`.
- Ledger: `.superpowers/sdd/2026-10-02-island-v2/progress.md`, with `Ruling:` lines for every judgement call.

## Phase 1: island core

### Task 1: Settings singleton
`config/Settings.qml` (singleton): loads `~/.config/hush/settings.json` (FileView, watchChanges, hot reload), defaults from `config/settings.default.json` in the repo: island {width 140, height 36, radius 18, topGap 6, reserve 40, mode "reserve"|"overlay"|"autohide", hoverFace true, liveActivities true, reducedMotion false, clickLeft "cc", clickRight "notifs", clickMiddle "media", scroll "volume"}, modules {media, notifications, calendar, launcher, wallpapers, settings: true}, motion {hoverDwellMs 120, leaveGraceMs 300, armMs 500}. `Settings.set(path, value)` writes atomically. IPC `hush settingsGet(key)` / `settingsSet(key, json)`. Test `tests/test_settings.sh`: set width 160 over IPC, assert file and getter, restore. Commit `feat(settings): hot-reloaded settings.json with defaults`.

### Task 2 (Opus): Arbiter
`modules/island/Arbiter.qml`: pure QML object. API: `declare(name, priority, {sticky, holdMs, coalesce})`, `raise(name, payload)`, `lower(name)`, `current` (name), `queue` (list), signals `shown(name,payload)`, `hidden(name)`. Rules from design 2.3: highest priority wins; transients (hold > 0) lower than current are queued FIFO, deduped by `payload.key`; when current lowers, next queued raises; coalesce re-times from last raise; sticky never auto-lowers; `hoverArm` signal emitted when a transient ends while `pointerInside` is true. Priorities table in `config/Priorities.qml`: modal 90, expanded 80, critical 70, notification 60, osd 50, activity 30, hover 20, rest 0. Tests: `tests/qml/tst_arbiter.qml` table-driven (≥ 12 cases incl. queue resume, dedupe, coalesce, sticky, hover re-arm) run by `tests/test_arbiter.sh` via qmltestrunner or the headless fallback. Commit `feat(island): priority arbiter with a resuming queue`.

### Task 3 (Opus): Surface
Rewrite `modules/island/IslandWindow.qml`: one PanelWindow per screen (Variants), anchors left+right+top, fixed `implicitHeight: 360`, `exclusiveZone` = Settings.island.reserve in reserve mode, 0 in overlay/autohide, `mask: Region` bound to the pill's current rect (plus a full-surface catcher only when a modal surface is open), namespace `hush-island`. Focused-monitor ownership kept from 8b5882f (Ipc.pick, islandScreen), expanded island pinned until collapse. Fullscreen: `Hypr` exposes `fullscreenOnFocused`; when true the pill retracts (y = -height) and mask is empty. Auto-hide: 1 px reveal strip window per screen; pill shows on hover of the strip, workspace change, or any raise ≥ 50. Layer rule in `hypr` docs: blur for `hush-island`. Tests `tests/test_surface.sh`: `hyprctl layers -j` geometry constant across rest/expanded; click 2 px outside pill reaches a window (open kitty, `hyprctl activewindow` unchanged after `hl.dsp.cursor.move` + click); fullscreen kitty (`hl.dsp.window.fullscreen`) → islandState "hidden"; on both monitors if present. Commit `feat(island): fixed full-width surface with a live input mask`.

### Task 4 (Opus): Morph
`modules/island/Pill.qml`: Rectangle whose width/height/radius are driven by `SpringAnimation` (stiffness/damping from Settings.motion, defaults mapped from design 2.5: hover 420/40 → spring 4.6 damping 0.36 … tune on screen and record), interruptible (`Behavior` with SpringAnimation, no restart); width snapped to 8 px; declared sizes per state in `config/Sizes.qml`; staged content: `SurfaceLoader` cross-fades (open: shell first, content opacity 0→1 after 90 ms; close: content 50 ms then shell); reduced motion multiplies durations by 0.4 and sets spring damping 1. Test `tests/test_morph.sh`: frame-sequence capture (grim every 40 ms for 600 ms) on expand, then reverse at 50 % and assert no frame where width jumps > 40 px between consecutive frames; a `reducedMotion` run finishes within 150 ms. Commit `feat(island): spring morph with staged content`.

### Task 5: Rest cluster, corners removed
`modules/island/rest/{ActivityCircle,Clock,StatusRing}.qml`: activity circle (album art with progress ring from Media, recording dot, timer, charging bolt; slot collapses when empty), clock (Inter 13, tabular, 8 px grid), status ring (battery arc, glyph Wi-Fi/BT/mic). Delete `modules/corners/` and its layer rules; update `shell.qml`, tests (`test_corners.sh` removed), README. Screenshot at rest on each theme. Commit `feat(island): rest cluster; corners removed`.

### Task 6: Hover face and input
**Added (main ruling after Task 4):** retune the calm spring so the control center opens in <= 350 ms (uncap or raise the velocity cap); change tests/test_morph.sh to a velocity-continuity gate (per-frame jump <= 2 x previous jump + 8 px, no overshoot beyond target + 4 px) instead of the absolute 40 px rule.
HoverHandler with dwell/grace/re-arm (Settings.motion), hover face 320×44 (workspaces dots, date, media title), click mapping (left cc, right notifs, middle media, scroll volume with OSD), arming window on surfaces, Esc and click-outside close, keyboard entry bind `Super+Backspace` already present. Tests `tests/test_hover.sh`: cursor move onto pill → islandState hover after ≤ 200 ms; move away → rest after ≥ 300 ms; OSD then hover → hover within 350 ms after OSD ends; click 100 ms after a surface opened on a button position does nothing. Commit `feat(island): hover face, click mapping, arming`.

### Task 7: OSD and notifications through the arbiter
Migrate Osd and NotifState to `raise/lower` with payload keys; OSD coalesce 1100 ms; notification hold 5000, paused on hover, critical sticky; queue resume test (notify while expanded → shows ≤ 300 ms after collapse); notification server ownership: try to own, else `Notifs.passive = true` and a settings warning. Remove `modules/drawer/` (replaced in Phase 2 Task 10; keep until then behind a flag). Commit `feat(island): OSD and notifications arbitrated and queued`.

**Phase 1 review (Sonnet):** against design 2.1–2.5 and code-study §9 items 1–11, 14–17, 19. Screenshots of every state on harbor and paper to `docs/evidence`.

## Phase 2: surfaces

### Task 8: Control center with sub-pages
`modules/island/surfaces/ControlCenter.qml` 560×320: toggles (Wi-Fi, Bluetooth, DND, Night light) with in-place sub-pages (network list via `Net.scan`, device list via `Bt`), volume/brightness sliders, media mini-card, theme strip + Wallpapers button, power row with a confirm step (lock → `hyprlock` only via `hush lock`, never in tests). Test extends `test_control_center.sh` with sub-page open/close and both monitors. Commit `feat(cc): control center with in-place sub-pages`.

### Task 9: Media surface
420×180: tinted art, scrubber (seek via Mpris), controls, optional cava gated to visibility (process only while shown). Test: play fake MPRIS player from tests (`tests/fakempris.py`), assert surface, assert cava process absent after close. Commit `feat(media): media surface with gated spectrum`.

### Task 10: Notification center surface
480×300 grouped by app, actions, clear all, DND; delete `modules/drawer/`. Tests migrate from `test_notifications.sh`. Commit `feat(notifs): notification center inside the island`.

### Task 11: Calendar surface
From hover face: month grid, today, `khal list` if present. Commit `feat(calendar): calendar surface`.

### Task 12: Launcher as modal surface
Move `modules/launcher/sources/*` under the island; surface 520×300 with HyprlandFocusGrab; delete LauncherWindow. Tests migrate. Commit `feat(launcher): launcher grows out of the island`.

### Task 13: Wallpapers as modal surface
Grid surface; selecting a tile runs `hush wall <path> --from X,Y` (Task 18 adds the transition). Delete WallpapersWindow. Commit `feat(wallpapers): wallpaper grid inside the island`.

### Task 14: Settings surface
560×320 GUI over Task 1 keys with live preview; `hush settings` opens it over IPC. Test: drag width slider via `hyprctl` cursor + click emulation or IPC `settingsSet`, assert pill width changes live. Commit `feat(settings): settings surface with live preview`.

**Phase 2 review (Sonnet):** every surface reachable by IPC and screenshot-able; sizes declared; no stray windows left (`hyprctl layers` shows only hush-island and reveal strips).

## Phase 3: behaviours

### Task 15: Live activities
Media ring, timer/pomodoro (`hush timer 25m` IPC), recording (wf-recorder/obs process watch), charging bolt 2 s (UPower), mic/camera (PipeWire PwObjectTracker). Tests per activity. Commit `feat(island): live activities at rest`.

### Task 16: Modes, fullscreen overlay, multi-monitor, keyboard
**Added 2026-10-02 (the maintainer):** while the pill is retracted for a fullscreen window, the top-edge reveal strip stays active: pointer at the top edge reveals the pill over the fullscreen window (same mechanism as auto-hide), it hides again after the leave grace. Test: fullscreen kitty, cursor to y=0, islandState leaves "hidden" within 300 ms.
Overlay and auto-hide polished (reveal on workspace change), separate `OsdOverlay` for fullscreen, keyboard navigation inside surfaces (arrows, Tab, Esc), `Accessible.role/name`. Tests: mode switch via settings, fullscreen OSD overlay visible, both monitors. Commit `feat(island): modes, fullscreen overlay, keyboard navigation`.

### Task 17: Performance and contrast gates
Idle CPU < 1 % with media playing and surfaces closed; `/proc/<qs>/status` voluntary ctxt switches < 50/s idle; contrast audit (`tests/contrast.py`) over six themes for pill text and surfaces; reduced motion run. Commit `test(island): performance and contrast gates`.

**Phase 3 review (Sonnet).**

## Phase 4: transitions, lock, login

### Task 18: Transitions
`hush wall --from X,Y` → `awww img --transition-type grow --transition-pos X,Y --transition-duration 0.9 --transition-fps 60 --transition-bezier .16,1,.3,1`; default pos = island centre on the focused monitor; `hush theme` same; shell cross-fades `Colors` over 400 ms (ColorAnimation on every role, gated by reduced motion). Test: `hush wall` from the island → awww query shows the new image; shell colours animate (sample primary at 0/200/400 ms). Commit `feat(theme): circle-reveal wallpaper and colour cross-fade`.

### Task 19: hyprlock, Apple style
`hyprlock/layouts/layout_default.conf` rewritten: blurred (`blur_passes 2`) dimmed wallpaper, Inter 96 light clock, date, avatar circle (`~/.face` if present), pill input with accent outline, fingerprint hint (fprintd), media label when playing (`playerctl` cmd label). Colours via the existing template. Tested in a nested Hyprland (`hyprlock --immediate` inside it, screenshot via headless output); never on the live session. Commit `feat(lock): Apple-style hyprlock layout per theme`.

### Task 20: SDDM
`sddm/hush/` Qt6 QML theme mirroring the lock screen; `hush sddm sync` writes `~/.cache/hush/sddm/{wallpaper.png,colors.conf}` world-readable and checks `$HOME` is `o+x`; `sddm/install.sh` (run by the maintainer with sudo once) copies the theme to `/usr/share/sddm/themes/hush`, writes `/etc/sddm.conf.d/hush.conf` `Current=hush`, and symlinks the cache dir. Test: `sddm-greeter-qt6 --test-mode --theme sddm/hush` screenshot in the nested Hyprland. Commit `feat(sddm): Hush login theme that follows the current theme`.

**Phase 4 review (Sonnet).**

## Phase 5: release and cleanup

### Task 21: Release 0.2.0
README (screenshots of every state on a clean workspace, keybinds, settings keys, SDDM step), CHANGELOG 0.2.0, VERSION, `git tag -a v0.2.0`, push main and the tag. Commit `docs: 0.2.0 release notes and screenshots`.

### Task 22: dotfiles cleanup and push (confirm the force-push with the maintainer first)
In `~/dotfiles`: remove reference clones (Tide-island, caelestia, any other vendored repo), HyDE leftovers, old wallpapers, dead configs; dotfiles `install.sh` clones `~/hush`; then rewrite history: orphan branch with 3–5 curated commits (base config, hyprland lua, terminal and shell, editor, hush integration), `git push --force origin master` (origin is still at the initial commit). Evidence log final section; memory file updated.
