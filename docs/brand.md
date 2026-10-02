# Hush brand

One mark, one wordmark, one stroke. Everything lives in `assets/brand/` and is rebuilt by
`python3 assets/brand/src/build.py` (needs `inkscape` and `rsvg-convert`).

![Hush lockup](../assets/brand/png/hush-lockup-black-1200.png)

## The mark: Breath

The island pill and one dot, a quiet gap apart: the island splitting the way it does when it comes
alive. A pause, then a breath. It identifies Hush; it does not draw a terminal, a prompt or an `H`.

| Part | Geometry (256 grid) |
| --- | --- |
| Pill | 152 x 76, fully round ends (radius 38), 2 : 1 |
| Dot | 76 x 76, same height as the pill |
| Gap | 16 |
| Small cut (16 to 24 px) | pill 128 x 64, gap 32, dot 64: snaps to 8 x 4, 2, 4 px at 16 px |
| Reversed (white on dark) | pill 144 x 72, gap 20, dot 72: 2 units thinner against irradiation |

## The wordmark

`hush`, lowercase, drawn from the same round-ended stroke as the mark (no font): x-height 96,
stroke 26, ascender 140, letter width 80, arches are half-pills, every end is round. The pill sits
centred on the x-height in the horizontal lockup.

## Files

| Need | File |
| --- | --- |
| Symbol, wordmark, horizontal and stacked lockups | `assets/brand/svg/hush-{symbol,symbol-small,wordmark,lockup,lockup-stacked}-{black,white,accent}.svg` |
| PNG ladder 16 to 1024 | `assets/brand/png/` |
| Favicon, PNG icon set, webmanifest, head snippet | `assets/brand/web/` |
| App icon (squircle) 512 / 1024, dark and light | `assets/brand/app/` |
| README header 1200 x 300, social preview 1280 x 640 (dark, light) | `assets/brand/social/` |
| Avatar 512, banner 1500 x 500 | `assets/brand/social/avatar-512.png`, `banner-1500x500.png` |
| hyprlock / SDDM face 256 | `assets/brand/shell/face-256.png` |
| Quickshell tray 24 / 48 (black, white) | `assets/brand/shell/tray-*.png`, `tray-*.svg` |
| fastfetch | `matugen/templates/fastfetch-logo.{svg,txt}`; previews per theme in `assets/brand/fastfetch/` |
| Hush for Arch Linux | `assets/brand/cobrand/hush-for-arch-linux-{dark,light}.{svg,png}` |

## Colour

The mark is pure black on light and pure white on dark, like the island itself. The accent is optional
and comes from the theme; the default (harbor) accent is `#7fb3a3`.

| Theme | Mode | Primary (fastfetch tint) |
| --- | --- | --- |
| dusk | dark | `#dcb9f8` |
| ember | dark | `#ffb690` |
| fog | light | `#236488` |
| harbor | dark | `#9cd1c1` |
| moss | dark | `#96d5a6` |
| paper | light | `#35675a` |

## Clear space and sizes

- Clear space on every side: the dot's diameter.
- Minimum size: symbol 16 px (use the small cut up to 24 px); horizontal lockup 96 px wide.
- App icon: the mark spans 60 % of the squircle tile.

## fastfetch

`hush theme` renders `~/.config/fastfetch/hush-logo.svg` in the theme primary and converts it to
`hush-logo.png`, which fastfetch shows through the kitty graphics protocol. In terminals without kitty
graphics use the 14-column text logo:
`fastfetch --logo-type file --logo ~/.config/fastfetch/logo.txt --logo-color-1 <hex>`.

## Hush for Arch Linux

The Arch Linux logo is the official file from archlinux.org/art (`assets/brand/cobrand/arch/`), used
unmodified: only placed and scaled, never recoloured, redrawn or merged with the Hush mark. The wording is
"Hush for Arch Linux", the form the Arch Linux trademark policy gives for software built for Arch.
Do not write "Hush x Arch", "Arch Hush" or anything that implies endorsement. The Arch logos are
trademarks of the Arch Linux project and are not covered by this repository's license.

## Don'ts

- Don't recolour the pill and the dot differently, add gradients, shadows or outlines.
- Don't change the gap, the 2 : 1 pill or the dot size; don't rotate or stack them vertically.
- Don't set "hush" in a font; use the drawn wordmark.
- Don't add a `$`, a chevron or a cursor: Hush is not the hush shell.
- Don't put the white mark on mid-tones; use black on light and white on dark.
