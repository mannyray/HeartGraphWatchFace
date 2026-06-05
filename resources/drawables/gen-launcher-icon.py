#!/usr/bin/env python3
"""Regenerate the 40x40 launcher icon (resources/drawables/launcher_icon.png).

Run by hand when the icon design changes. Output is checked into the repo
since it's binary and not deterministically reproducible from settings (the
Garmin build doesn't run Python). Requires Pillow (`pip install Pillow`).

Concept: red heart in the upper portion, five ascending palette-colored
bars across the bottom — visually communicates "heart rate displayed as
a colored bar graph" which is exactly what the watch face does.
"""
import os
from PIL import Image, ImageDraw

SIZE = 40
OUT_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "launcher_icon.png")

img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
d = ImageDraw.Draw(img, "RGBA")

# Heart: two ellipses + a triangle, with a rectangle to cover the seam.
RED = (220, 30, 40, 255)
d.ellipse((10, 4, 22, 16), fill=RED)
d.ellipse((18, 4, 30, 16), fill=RED)
d.polygon([(10, 12), (30, 12), (20, 26)], fill=RED)
d.rectangle((16, 9, 24, 14), fill=RED)

# Ascending bars in the Default palette colors (green → yellow → red).
BAR_COLORS = [
    (0, 170, 0),     # 0x00AA00 — calm
    (170, 170, 0),   # gold
    (255, 170, 0),   # orange
    (255, 85, 0),    # red-orange
    (255, 0, 0),     # 0xFF0000 — critical
]
for i, c in enumerate(BAR_COLORS):
    x = 4 + i * 7
    h = 4 + i * 2
    d.rectangle((x, 38 - h, x + 5, 38), fill=c + (255,))

img.save(OUT_PATH, "PNG")
print(f"wrote {OUT_PATH} ({SIZE}x{SIZE})")
