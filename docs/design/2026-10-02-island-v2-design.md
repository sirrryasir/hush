# Hush Island v2: comparison and design (2026-10-02)

Gate document. Nothing is built until the maintainer has read this. Evidence lives in the five studies next to this file:
`islands-code-study.md` (8 repos read, 2 run in a nested Hyprland), `islands-video-study.md` (7 videos, 2 with speech),
`islands-community.md` (Reddit + issue trackers), `pleamar-marea-study.md`, `hush-island-audit.md` (Hush v1 vs the findings).

## 1. Comparison

| | Rest | Open | Arbitration | Motion | Hide | Settings GUI | Multi-monitor | Notifs | Verdict |
|---|---|---|---|---|---|---|---|---|---|
| Tide-island (710★) | 140×38 clock | hover 350 ms / per-button click / auto on track | 16 string states, last wins, drops events | 400 ms OutQuint, no spring | slide off, on by default | separate app, live geometry, chip composer | per screen, panels follow focus | mirrors a daemon (needs SwayNC) | most complete; leaks, drops notifications while open, author moved on |
| impasto (288★) | clock pill 32 h | hover dwell 80 ms, click | one ranked binding (cleanest) | 380 ms presets | no | GUI → settings.json | one live island follows focus | own | best arbitration and fixed-surface mask |
| ChillPill (177★) | content+68 | click L/M/R, optional hover | ternary chain, real FIFO for notifs | 225/550 ms | hover-hide | jsonc + GUI | single window, breaks off 0,0 | own, dedupe | best low-GPU discipline (3% CPU on HD 4000) |
| k4 (119★) | idle ×34, wings | hover plugin, right-click panel | integer priorities per plugin | OutBack 440 ms | no | GUI with preview | pill on all, open on active | own, side band when busy | plugin API; best surface comment (never resize the layer) |
| Ukishima (73★) | 160×38, hidden | hover with 300 ms grace | ternary ladder, critical first | bezier 420/260 ms, reduce-motion | auto-hide default, 1 px strips | in-pill GUI | per screen, surface on focused | own, loses silently if taken | mask union and reserve-window tricks |
| DynamicGlacier (23★) | 104×24 bump | hover, no delay | last caller | OutCubic 300 ms | no | in-island | focused only | IPC only | exit-preview idea |
| openagentisland (18★) | 180×36 notch | click, auto on permission | fixed ladder | 330 ms bezier | no | config only | per screen | own | agent approvals; end-4 base |
| lunanoir (13★) | ≥320×54 | hover, 90 ms close + watchdog | rules + FIFO for device events | 380/260 ms | no | overlay GUI | per screen | IPC only | 8 px width grid, dismiss arming |
| saneAspect Dynamite V3 (video) | art circle, clock, status ring | hover lift 7 px, click | n/a | smooth, unquantified | option | GUI, tile editor | not shown | own | the look people copy; "balance and symmetry" |
| pleamar/marea (Rust) | ball with a face | click opens, hover previews | n/a | springs 420/40, 150/23 | sunk peek | scene files | n/a | card → colour drop → badge | timing ideas; platform too young |
| **Hush v1** | 320×36 + two corner pills | hover, IPC | request/release, drops preempted | spring body, hard content swap | no | none, readonly Theme | laptop screen hardcoded (fixed in 0.1.0) | own, unconditional | 6/35 behaviours complete, 10 missing |

What they share: no two islands share code. Tide lifted end-4's workspace overview without credit; that is the only real copy.
The "copy" accusations on Reddit are about looks: three different posts are called clones of saneAspect's layout.

What they all lack (code study §6): interruptible spring morphs, a queue that resumes lower-priority events, a live activity
at rest, hover that re-arms after a transient, tests of the state machine, accessibility, reduced motion, honest
notification ownership. Most-wanted by users (community §3): non-invasive install, auto-hide or dodge, notifications inside
the island, low CPU, deep settings in a GUI, smoother motion, launcher in the island, keyboard-first control.

## 2. Design: one black pill that everything grows out of

### 2.1 Rest (per monitor)
- Pure black pill, 140×36, radius 18, 6 px below the top edge, centred. Reserve 40 px by default.
- Three slots, symmetric (saneAspect V3 idea, Hush palette): **activity circle** left (album art with a thin progress ring,
  or a recording dot, timer, charging bolt; empty slot collapses so the pill narrows), **clock** centre (Inter, 13 px,
  tabular digits, width snapped to an 8 px grid so the second hand never retriggers the morph), **status circle** right
  (battery ring with the glyph for Wi-Fi/Bluetooth/mic-in-use inside; muted colours from the theme, red only for critical).
- The two corner widgets of v1 are removed. Workspaces move into the hover face and a 900 ms switch OSD. Window title is
  gone; it was the "basic label" the maintainer rejected.

### 2.2 Interaction (click acts, hover previews)
- Hover 120 ms dwell → **hover face**: the pill grows to 320×44 and shows workspaces as dots with the active one as a pill,
  date, and the media title if playing. Leave grace 300 ms. No glance may start while the pill is shrinking.
- Left click → **control center**. Right click → **notification center**. Middle click → **media**. Scroll on the pill →
  volume with the OSD drawn inside the pill. Super+Backspace toggles the control center; Esc or a click outside closes.
  Every button has an arming window of 500 ms after it appears (no accidental taps on a surface that just morphed in).
- Hover re-arms: if the pointer is still inside when a transient ends, the hover face opens without re-entry.

### 2.3 States and arbitration (one pure function)
Priority table: modal surface (launcher, wallpapers, settings) 90 › expanded (control center, media, notifications,
calendar) 80 › critical notification 70, sticky › notification 60 › OSD 50 › live activity 30 › hover 20 › rest 0.
The shown state is the highest-priority active source. Lower-priority transients queue (FIFO, deduped by app and summary)
and play after the current one ends; an OSD coalesces and re-times from its last change. Critical notifications never time
out. The arbiter is a plain QML object with a table-driven TestCase.

### 2.4 Window strategy
- One layer surface per monitor, full width, fixed 360 px height, never resized. Only the input Region mask changes, so no
  configure round-trip paints a stretched frame (k4's lesson). Transparent pixels never take clicks; a full-surface
  catcher exists only while a modal surface is open.
- Modes in settings: **reserve** (default, 40 px exclusive zone), **overlay** (no reserve, windows run under the pill),
  **auto-hide** (hidden behind a 1 px reveal strip, shows on workspace change and on events).
- Fullscreen window on the focused workspace: the pill retracts and the mask empties. OSDs still show for 1.1 s on a
  separate overlay surface.
- Only the island on the focused monitor expands and receives OSD and notifications; an open island stays where it is until
  it collapses (shipped today for the control center).

### 2.5 Motion
- Width, height and radius are SpringAnimations, interruptible, no restart on retarget. Starting constants mapped from
  pleamar: quick 420/40 for hover, calm 150/23 for open; tuned on screen, recorded as numbers in the evidence log.
- Open is staged: shell 290 ms, then content fades in 90 ms later. Close: content out 50 ms, shell 210 ms. Panel sizes
  are declared up front so the shape morphs before the content loads.
- Reduced-motion flag scales every duration by 0.4. Nothing animates while hidden or collapsed (cava, shimmer, timers).

### 2.6 Surfaces (all grow out of the pill)
- **Control center** (560×320): Wi-Fi, Bluetooth, DND, Night light toggles with in-place sub-pages (network list, device
  list); volume and brightness sliders; media mini-card; theme strip and a wallpapers button; power row with confirm.
- **Media** (420×180): accent-tinted art, title, progress scrubber, controls, optional cava spectrum gated to visibility.
- **Notification center**: grouped by app, actions, clear all, DND, scroll; a single notification shows as a wide pill
  with icon, summary, body, and click → action or center.
- **Calendar** from the hover face: month grid, today, upcoming from `khal` if present (optional).
- **Launcher** and **wallpaper grid** become modal surfaces of the island (keyboard focus grabbed while open), replacing the
  separate windows. Wallpaper selection triggers the circle reveal from the island's centre.
- **Settings** (Tide's winning feature): geometry sliders with live preview (width, height, radius, top gap, reserve), mode,
  hover and click mapping, modules on/off, theme, reduced motion. Writes `~/.config/hush/settings.json`, hot-reloaded.
  Opened with `hush settings` or from the control center.
- Deferred to 0.3: workspace overview with ScreencopyView (memory leaks in Tide #6), weather, agent approvals.

### 2.7 Live activities at rest
Media (art + ring), timer/pomodoro, screen recording (wf-recorder or OBS detected), charging (bolt pulse for 2 s when
plugged), mic or camera in use (PipeWire), downloads if a browser exposes them later.

### 2.8 Notifications, settings, install
Own `org.freedesktop.Notifications` when free; if another daemon holds it, show a warning in settings and mirror
passively. No hardcoded paths or monitor names; a guard test greps the repo for them. Install never overwrites a user file.

### 2.9 Transitions, lock, login
- **Wallpaper**: `awww img --transition-type grow --transition-pos <x,y>` from the island centre (or the clicked tile),
  900 ms, 60 fps, bezier ease-out. **Theme**: the shell cross-fades every colour over 400 ms in sync with the wallpaper.
- **hyprlock, Apple style**: blurred and dimmed wallpaper, thin Inter 96 clock, date under it, round avatar, a pill
  password field with the accent outline, fingerprint hint, media line when playing. Templated per theme. Tested only in a
  nested Hyprland during the build; never on the live session.
- **SDDM**: a Hush QML theme matching the lock screen. The theme dir is root-owned, so install needs sudo once; per-theme
  sync writes the current wallpaper and colours to a world-readable `~/.cache/hush/sddm/` that the greeter reads.
  If the home directory is not world-executable this needs a sudoers rule for one script. Decision needed.

### 2.10 Tests (evidence, not vibes)
Table-driven arbiter TestCase; queue resume; hover re-arm; click 2 px outside the pill does nothing; constant layer geometry
across states; frame-sequence capture with a reversal at 50 % and no jump; fullscreen retract; both monitors; idle CPU
under 1 % and flat context switches; contrast audit on all six themes; no-personal grep. Every surface reachable by IPC and
screenshot-able headless.

## 3. Repos, versions, commits
- the `hush` repo (product) and the maintainer's dotfiles (personal). Conventional commits with bodies, one per coherent
  change, tests green first, no fixup streams. v0.1.0 is today's shell; v0.2.0 is this design complete and reviewed.
- Dotfiles is pushed only after v0.2.0, after removing the reference clones, HyDE leftovers and old wallpapers, with a
  rewritten curated history.

## 4. Plan outline (each phase ends in a review and a screenshot set)
1. Island core: surface strategy, arbiter and queue, spring morph, rest cluster, hover face, OSD, notifications; corners
   removed. Tests above.
2. Surfaces: control center, media, notification center, calendar, launcher and wallpapers as modal surfaces, settings GUI.
3. Behaviours: live activities, modes (reserve, overlay, auto-hide), fullscreen, multi-monitor, keyboard, reduced motion.
4. Transitions, hyprlock, SDDM.
5. Polish, README screenshots, v0.2.0; then the dotfiles cleanup and push.

## 5. Decisions for the maintainer
1. Corners removed; workspaces live in the hover face and the switch OSD. (Recommended: yes.)
2. Default mode: reserve 40 px, with overlay and auto-hide selectable in settings. (Recommended: reserve.)
3. SDDM needs one sudo run, possibly a sudoers rule. (Recommended: do it; prepared script, you run it once.)
4. Workspace overview deferred to 0.3. (Recommended: yes.)
