#!/usr/bin/env python3
"""Composite the 12 individual variant PNGs into a single labeled grid
that highlights how the watch face varies with the three settings.

Layout: 3 rows × 4 columns.
  - Rows are the GraphNumberColor variants (default / hidden / gray).
  - Columns are the (BackgroundColor, TimeColor) variants, grouped so
    the two bg=black columns sit next to each other and the two bg=white
    columns sit next to each other. Within each pair, tc=default comes
    before tc=gray.

This puts each background in a contiguous pair so the bg change reads
as the biggest visual chunk, while the tc + gn variations are clear
along their own axes.

Output: output/combined.png
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

import settings_code

SCRIPT_DIR = Path(__file__).resolve().parent
OUTPUT_DIR = SCRIPT_DIR / "output"

DEFAULTS = {
    "HRMin": 40, "HRMax": 100, "HRStep": 10, "PaletteIndex": 0,
    "GraphBandPixels": 10, "HeartGraphMinutes": 3, "MinimalMode": False,
}

# (label, GraphNumberColor value) — row order
GN_ROWS = [
    ("numbers: default", -2),
    ("numbers: hidden",  -3),
    ("numbers: gray",    0xAAAAAA),
]

# (label, BackgroundColor, TimeColor) — column order, bg-grouped
BG_TC_COLS = [
    ("black bg\ntime: default", 0x000000, -2),
    ("black bg\ntime: gray",    0x000000, 0x555555),
    ("white bg\ntime: default", 0xFFFFFF, -2),
    ("white bg\ntime: gray",    0xFFFFFF, 0x555555),
]

CELL = 540          # source images are already 540x540
PAD = 16            # gap between cells
TOP_LABEL_H = 80    # space above the grid for column labels
LEFT_LABEL_W = 200  # space left of the grid for row labels
MARGIN = 24         # outer padding


def code_for(bg, gn, tc):
    full = dict(DEFAULTS)
    full.update({"BackgroundColor": bg, "GraphNumberColor": gn, "TimeColor": tc})
    return settings_code.encode_settings(full)


def load_font(size):
    # Walk a few common macOS font paths so the script doesn't depend on
    # PIL's default bitmap font (which is tiny + ugly at 24pt).
    for path in [
        "/System/Library/Fonts/SFNS.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
        "/Library/Fonts/Arial.ttf",
    ]:
        if Path(path).exists():
            try:
                return ImageFont.truetype(path, size)
            except OSError:
                continue
    return ImageFont.load_default()


def main():
    rows = len(GN_ROWS)
    cols = len(BG_TC_COLS)

    canvas_w = LEFT_LABEL_W + cols * CELL + (cols - 1) * PAD + 2 * MARGIN
    canvas_h = TOP_LABEL_H + rows * CELL + (rows - 1) * PAD + 2 * MARGIN
    canvas = Image.new("RGB", (canvas_w, canvas_h), (245, 245, 245))
    draw = ImageDraw.Draw(canvas)

    label_font = load_font(28)
    code_font = load_font(18)

    # Column headers (top)
    for ci, (label, _, _) in enumerate(BG_TC_COLS):
        x = MARGIN + LEFT_LABEL_W + ci * (CELL + PAD) + CELL // 2
        # multi-line center-anchored text
        draw.multiline_text(
            (x, MARGIN + TOP_LABEL_H // 2),
            label,
            fill=(40, 40, 40),
            font=label_font,
            anchor="mm",
            align="center",
            spacing=4,
        )

    # Row labels (left)
    for ri, (label, _) in enumerate(GN_ROWS):
        y = MARGIN + TOP_LABEL_H + ri * (CELL + PAD) + CELL // 2
        draw.text(
            (MARGIN + LEFT_LABEL_W // 2, y),
            label,
            fill=(40, 40, 40),
            font=label_font,
            anchor="mm",
        )

    # Cells
    missing = []
    for ri, (_, gn) in enumerate(GN_ROWS):
        for ci, (_, bg, tc) in enumerate(BG_TC_COLS):
            code = code_for(bg, gn, tc)
            path = OUTPUT_DIR / f"{code}.png"
            if not path.exists():
                missing.append(code)
                continue
            img = Image.open(path).convert("RGB")
            if img.size != (CELL, CELL):
                img = img.resize((CELL, CELL))
            x = MARGIN + LEFT_LABEL_W + ci * (CELL + PAD)
            y = MARGIN + TOP_LABEL_H + ri * (CELL + PAD)
            canvas.paste(img, (x, y))
            # Small code caption inside the cell (bottom-left), so the
            # composite remains self-describing if someone shares just it.
            draw.text(
                (x + 8, y + CELL - 24),
                code,
                fill=(255, 255, 255),
                font=code_font,
                stroke_width=2,
                stroke_fill=(0, 0, 0),
            )

    if missing:
        print(f"warning: missing {len(missing)} image(s): {', '.join(missing)}")
        print("        run `python3 generate.py` first")

    out = OUTPUT_DIR / "combined.png"
    canvas.save(out, "PNG")
    print(f"wrote {out} ({canvas_w}x{canvas_h})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
