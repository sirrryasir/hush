# Phase 3 + 4 review (island v2), 2026-10-02

Scope: plan Tasks 15-20 plus follow-ups (Settings controls, keyboard sliders, Phase 1+2 fixes) against design 2.4, 2.5, 2.7-2.10, and the Phase 1+2 review (`2026-10-02-phase1-2-review.md`). HEAD `4ac29c9`, shell restarted at the start. Screens (not committed): `~/.cache/hush/evidence/review34-*.png` (34 files; `paper-sheet.png` and `harbor-sheet.png` are contact sheets). The machine had two monitors; checks ran on the focused one.

## 1. Test run

`bash tests/run_all.sh`: 10 min, one group red, everything else green (`test_perf` table all within gates: idle 0.2 %, reduced-motion open 35 ms).

- **test_hover.sh, groups `overview` and `log` (2 failures), still red on the single rerun.** Cause 1 (both runs): `WARN scene: surfaces/Media.qml[18:5]: Unable to assign [undefined] to bool` in the shell log; `canSeek` returns `undefined` when `Svc.Media.player` is a dying player object (the test kills the fake MPRIS player while the media surface exists), see Important 1. Cause 2 (rerun only): ~70 `qt.svg: Cannot open file ~/.config/hush/icons/vol/vol-NN.svg` warnings; no repo file names that path, but `~/dotfiles/bin/volumecontrol.sh:46,139` and `brightnesscontrol.sh:75` build exactly it, and the HyDE-leftover cleanup removed the icons (see Nice 5).
- Not in `run_all.sh` (list-based): test_activity, test_calendar_surface, test_cc_surface, test_launcher_surface, test_media_surface, test_notif_center, test_settings_surface, test_wallpapers_surface, test_transition, test_sddm. Run by hand once with `QS_DISABLE_CRASH_HANDLER=1`: all 10 green.
- `tests/test_no_personal.sh` PASS. Grep for home paths, user names and monitor names over quickshell, bin, sddm, hyprlock, matugen, hypr, install.sh: no hits (only the guard test's own pattern).
- `hyprctl layers` at rest: `hush-island` (1920x360) per output plus `awww-daemon`, nothing else. Auto-hide adds `hush-island-reveal` (1 px); fullscreen shows `hush-island` and the reveal strip on the Overlay level; `hush-island-osd` only while an OSD shows.

## 2. Live checks

| Check | Result |
| --- | --- |
| Media at rest | A playing player gives the 136 px pill with the art circle (`media-rest-circle.png`); no capsule. Click on the circle opens the media surface (test_hover). |
| Critical marker | Red ring, red dot and `priority_high` glyph on the card (`critical.png`); stays up (sticky) while a later normal notification waits behind it. A click on the card opens the notification center and clears it. |
| Outside-click arming | CC opened over IPC, click outside 100 ms later: still open; click 1.5 s later: closed. |
| Auto-hide | Workspace change reveals the pill (state `rest`), hidden again after ~3 s; a notification reveals it; hidden again after the card ends. |
| Fullscreen | Kitty fullscreen: state `hidden`, island on Overlay; pointer to y=0: `rest` within ~150 ms (incl. IPC), pill over the window (`fs-reveal.png`); leaving hides it; `osd volume` shows the pill on `hush-island-osd` for ~1.1 s (`fs-osd.png`, `osdOverlayVisible` true then false). |
| Keyboard | CC via IPC, Tab x10 reaches the volume slider (ring around it, `kb-volume-focused.png`); Right: 0.42 -> 0.47 -> 0.52, Left: 0.47, Shift+Right: +0.5 (10 steps). `Island.navAdjust` works live; history shows `@adjust`. Up/Down/Tab still move focus. |
| Settings, Behaviour | Switches Now playing OSD, Fullscreen reveal, Fullscreen OSD and the Reveal time slider (500-5000 ms) are present and the page fills the surface (`settings-behaviour-harbor.png`). |
| Reduced motion | Toggled via `settingsSet island.reducedMotion`: CC open measured from outside ~650 ms vs ~320 ms (both include ~10 qs IPC spawns; in-shell numbers are in test_perf). |
| Themes | harbor and paper each: rest, CC, settings, wallpapers, launcher, notification center, calendar, media (`paper-sheet.png`, `harbor-sheet.png`). All readable. |
| `hush plugins status` | gloview and dynamic-cursors: loaded yes, installed yes. |
| `hush overview` | exits 0, prints `ok`, second call toggles it back. |
| Timer | `hush timer 1m` widens the pill (176 px), `hush timer stop` returns to 104. |

## 3. Light-theme contrast on live surfaces

paper, grim crops of the real layer, panel background pure black (0,0,0): brightest ink 15.7-21.0:1 on rest, CC, settings, wallpapers, launcher, notification center and calendar (11.0:1 on the notification rows' own container); dimmest frequent ink on the calendar (out-of-month days) 4.7:1. No dark-on-black text is left anywhere. Visually confirmed in `paper-sheet.png`. The gate (`test_island_contrast`) is green over six themes.

## 4. Phase 1+2 follow-ups

| Item | Now |
| --- | --- |
| Critical 1: dark ink on black in light themes | Fixed (dark island roles; paper readable on every surface). |
| Critical 2: square media corners | Fixed (`harbor-media.png`, `paper-media.png` rounded to the pill radius). |
| Important 1: media capsule at rest | Fixed (activity circle; 1.1 s now-playing card only on track change). |
| Important 2: critical looks normal | Fixed (see table). |
| Important 3: outside click during morph | Fixed (arming applies to outside clicks). |
| Important 4: wallpapers dead space / dim tiles | Fixed (2x3 tiles, 1 px outline; ember and moss visible). |
| Important 5: settings / notification center half empty | Fixed (pages fill; empty state centred). |

## Critical

None.

## Important

1. `quickshell/hush/modules/island/surfaces/Media.qml:18`: `canSeek` evaluates to `undefined` (not `bool`) when the player object has gone away, logging a QML WARN on every such change; this alone keeps `test_hover` red and the log check red for any user whose player quits with the surface open. Use `!!player && player.canSeek === true && ...`.
2. `tests/run_all.sh:4`: 10 test files are never run by the suite (listed in section 1), including every surface harness test, `test_transition` and `test_sddm`. "run_all green" therefore does not cover Tasks 8-14, 18 or 20. Add them (or glob `test_*.sh`).
3. `README.md:45-55` Commands table omits `hush list`, `hush timer`, `hush lock`, `hush settings`, `hush overview`, `hush plugins` (plugins and overview appear only in the Plugins section, timer, lock, settings and list nowhere), `hush sddm sync` (prose only) and `hush wall --mode`. `bin/hush --help` has all of them. Keyboard navigation (Tab, arrows, Shift = 10 steps), live activities and the new settings keys (`island.nowPlayingOsd`, `fullscreenReveal`, `fullscreenOsd`, `motion.revealMs`) are undocumented. Task 21 says README is part of the release.
4. `quickshell/hush/modules/island/surfaces/Settings.qml:192` offers `brightness` for "Scroll", but `Island.qml:141` only acts on `volume`; picking it silently disables the wheel. README says `volume` or `none`. Drop the option or implement it.

## Nice

1. Settings "Width 140 px" while the rest pill is 104 px (ruled: width is computed from the slots); the slider reads as a lie. Relabel or remove.
2. A sticky critical notification blocks every later notification until clicked (queued normal card never showed; opening the center then drops it as seen). Probably intended; worth one line in the README.
3. `cc/ThemeStrip.qml`: the sixth tile (paper) is cut off at the CC's right edge (`harbor-cc.png`, `paper-cc.png`); a scroll affordance or tighter tiles would read as intentional.
4. Media surface shows `5:13 / 2:00` with the fake player (position past length): clamp the label to the length for misbehaving players.
5. `~/dotfiles/bin/volumecontrol.sh:139` and `brightnesscontrol.sh:75` still point at `~/.config/hush/icons/vol/`, removed with the HyDE leftovers; notifications from those scripts carry a dead icon path and spam the shell log (outside this repo).
6. During the `window.fullscreen` probe, the user's own kitty ended fullscreen (mode 2) after the probe window was closed (cause not found, possibly Hyprland moving the state; I toggled it back). Worth a look in `tests/test_modes.sh` which uses the same dance.
7. `integrations/nvim/hush-theme.lua` shows `MM` in `git status`, not from this review (another agent's work); left untouched.
8. README screenshots (`assets/themes/*.png`) predate v2; Task 21 will replace them.

## README accuracy

Every command and key in the README exists: `hush theme|wall|reload|status|check|fallback|shell|generated|track|plugins|overview|--version` (all in `bin/hush` case list and `--help`), `--from`, `HUSH_REDUCED_MOTION`, IPC calls toggleControlCenter, toggleLauncher, toggleDrawer, toggleWallpapers, showLauncher; click mappings `cc|notifs|media|calendar|launcher|none` match `Island.act`; `island.mode` values and the `hush-island` / `hush-island-reveal` namespaces match `hyprctl layers`. `~/dotfiles/hypr/modules/binds.lua` carries the same binds (lines 14, 39, 46, 154-156) plus SPACE, SHIFT+Tab and `clearNotifications`; there is no Super+Tab bind for `hush overview` (README says "for example", so not an error).

## Verdict

Not yet ready for 0.2.0, but close: no Criticals, every Phase 3/4 behaviour works live (activities, arming, critical marker, auto-hide, fullscreen reveal and OSD layer, keyboard sliders, transitions, SDDM/lock tests green). Fix Importants 1-4 (a few lines each), get `run_all` green with the missing tests included, then ready for 0.2.0.
