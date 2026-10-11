# Island design

One black pill per monitor that everything grows out of. Section numbers match the
`design 2.x` comments in `quickshell/hush`. Sizes live in `config/Sizes.qml`, priorities in
`config/Priorities.qml`, timings and springs in `config/settings.default.json` (`motion`).

## 2.1 Rest

A pure black pill, 36 px tall, radius 18, `topGap` below the top edge, centred. Three symmetric
slots: the **activity circle** on the left (album art with a progress ring, recording dot,
countdown, charging bolt; it collapses when empty so the pill narrows), the **clock** in the middle
(Inter, tabular figures, width snapped to an 8 px grid so ticking never retriggers a morph) and the
**status ring** on the right (battery arc with a Wi-Fi, Bluetooth or mic glyph; red only when
critical). There are no corner widgets: workspaces live in the hover face and a switch OSD.

## 2.2 Interaction: click acts, hover previews

- Hover for `hoverDwellMs` (120) opens the **hover face** (320 x 44: workspaces, date, track and
  the chips in `layout.hover`); it closes `leaveGraceMs` (300) after the pointer leaves. No hover
  may start while the pill is still shrinking.
- Left, right and middle click map to `island.click*` (default control center, notification
  center, media); scroll maps to `island.scroll` (volume, with the OSD inside the pill).
- Every surface ignores clicks for `armMs` (500) after it appears, so a tap meant for the old
  shape never lands on the new one. Esc or a click outside closes.
- Hover re-arms: if the pointer is still inside when a transient ends, the hover face opens
  without leaving and re-entering.

## 2.3 Arbitration

`modules/island/Arbiter.qml` is a plain QML object and the single source of truth for what the
pill shows: the highest-priority active source wins (modal 90 > expanded 80 > critical 70 >
notification 60 > OSD 50 > hover 40 > activity 30 > rest 0). Lower-priority transients queue
FIFO, deduplicated by key, and play when the current one ends; an OSD coalesces and re-times from
its last change; critical notifications are sticky. `tests/qml/tst_arbiter.qml` is its
table-driven test.

## 2.4 Window strategy

One layer surface per monitor (`hush-island`), full width, fixed 360 px tall, never resized: only
the input `Region` mask follows the pill, so no configure round-trip ever paints a stretched
frame and clicks beside the pill reach the windows below. A full-surface catcher exists only while
a modal surface is open. Modes: `reserve` (40 px exclusive zone, default), `overlay` and
`autohide` (a 1 px reveal strip). A fullscreen window retracts the pill; OSDs then show on their
own layer (`hush-island-osd`). Only the island on the focused monitor expands, and an open island
stays put until it collapses.

## 2.5 Motion

Width, height and radius are interruptible `SpringAnimation`s that retarget without restarting
(`springQuick` for hover, `springCalm` for surfaces). Opening is staged: the shape morphs to the
size declared in `Sizes.qml` first, then the content fades in `contentInDelayMs` later; closing
fades the content out first. Reduced motion scales every duration by `reducedScale` (0.4) and
removes spring overshoot. Nothing animates while hidden or collapsed.

## 2.6 Surfaces

All grow out of the pill: **control center** (560 x 304, tiles from `layout.cc` with in-place
Wi-Fi and Bluetooth sub-pages, sliders, media card, theme strip, power row with a confirm step),
**media** (art, scrubber, controls, optional cava), **notification center** (grouped by app,
actions, clear all, DND), **calendar** (from the hover face), and the modal **launcher** (apps,
windows, calculator, clipboard), **wallpaper grid** and **settings** (live-preview geometry,
modes, click mapping, the Modules composer; writes `~/.config/hush/settings.json`).

## 2.7 Live activities

Shown at rest in the activity circle: now playing, countdown timer (`hush timer`), screen
recording (wf-recorder, OBS or gpu-screen-recorder), charging. Mic and camera use show in the status ring.

## Notifications, theming, lock and login

- Hush owns `org.freedesktop.Notifications` when the name is free; if another daemon holds it,
  settings shows a warning and Hush mirrors passively.
- `hush theme` and `hush wall` run matugen over `matugen/config.d/*.toml`; the wallpaper changes
  with an `awww` grow transition from the island (or the clicked tile) while the shell cross-fades
  its colours.
- Lock (hyprlock) and login (SDDM) share one layout spec, `lockscreen/layout.toml`; see
  [lockscreen.md](lockscreen.md).
- Nothing in the tree names a user, home path or monitor (`tests/test_no_personal.sh`), and
  `install.sh` never overwrites a real file.
