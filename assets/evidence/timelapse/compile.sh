#!/usr/bin/env bash
# Compile the Hush build timelapse. Drops frames with mean luminance < 8/255 (lock screen, DPMS black).
cd "$(dirname "$0")" || exit 1
OUT=..; K=frames-kept
rm -rf "$K"; mkdir -p "$K"
python3 - "$K" <<'PY'
import sys, glob, os
from PIL import Image, ImageStat
k = sys.argv[1]; n = 0
for f in sorted(glob.glob("frame-*.jpg")):
    im = Image.open(f).convert("L")
    if ImageStat.Stat(im).mean[0] < 8:
        continue
    os.symlink(os.path.abspath(f), f"{k}/{n:05d}.jpg"); n += 1
print(f"kept {n} frames")
PY
n=$(ls "$K" | wc -l)
if command -v ffmpeg >/dev/null; then
  # few frames: show each for 0.5 s, then duplicate up to 12 fps so the clip has enough video frames
  in=12; [ "$n" -lt 60 ] && in=2
  ffmpeg -y -loglevel error -framerate "$in" -i "$K/%05d.jpg" -vf scale=1280:-2 -r 12 -c:v libx264 -pix_fmt yuv420p "$OUT/hush-build-timelapse.mp4"
  ffmpeg -y -loglevel error -framerate "$in" -i "$K/%05d.jpg" -vf "select='not(mod(n,4))',scale=640:-1" -loop 0 "$OUT/hush-build-timelapse.gif" 2>/dev/null || true
else
  python3 - "$K" "$OUT/hush-build-timelapse.png" <<'PY'
import sys, glob
from PIL import Image
fs = sorted(glob.glob(sys.argv[1] + "/*.jpg")); w = 320; cols = 6
ims = [Image.open(f).convert("RGB") for f in fs]
h = int(ims[0].height * w / ims[0].width); rows = (len(ims) + cols - 1) // cols
sheet = Image.new("RGB", (cols * w, rows * h))
for i, im in enumerate(ims): sheet.paste(im.resize((w, h)), ((i % cols) * w, (i // cols) * h))
sheet.save(sys.argv[2])
PY
fi
ls -la "$OUT"/hush-build-timelapse.* 2>/dev/null
