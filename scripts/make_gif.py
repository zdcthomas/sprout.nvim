"""Render the bonsai stages from lua/sprout/sets/bonsai.lua into assets/bonsai.gif.

Each frame shows a mock start-screen dashboard: the tree as the header, a
clock for the hour that stage covers, a small menu, and a footer.
"""

import os
import re
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

# SPROUT_ROOT overrides the repo root. The nix package needs this, because
# there the script runs from the store, not from scripts/.
ROOT = Path(os.environ.get("SPROUT_ROOT") or Path(__file__).resolve().parent.parent)
SOURCE = ROOT / "lua" / "sprout" / "sets" / "bonsai.lua"
OUT = ROOT / "assets" / "bonsai.gif"

# Growth order, ending with the dead tree.
ORDER = ["smallest", "baby", "teen", "adult", "middle_aged", "old", "older"]
# First hour of the window each stage covers (6 stages, 4 hours each).
# The dead tree is a joke frame, so it gets the last minute of the day.
HOURS = ["00:00", "04:00", "08:00", "12:00", "16:00", "20:00", "23:59"]

MENU = [
    "[e] New file",
    "[o] Recent files",
    "[l] Lazy",
    "[q] Quit",
]
FOOTER = "Neovim loaded 42/97 plugins in 23ms"

BG = (24, 24, 33)
LEAF = (140, 190, 100)
BLOOM = (220, 160, 190)
TRUNK = (180, 140, 100)
GROUND = (120, 120, 135)
CLOCK = (120, 120, 135)
MENU_KEY = (140, 190, 100)
MENU_TEXT = (150, 160, 180)
FOOTER_TEXT = (100, 105, 125)

FONT = ImageFont.truetype("/System/Library/Fonts/Menlo.ttc", 22)

FRAME_MS = 900
LAST_FRAME_MS = 1800


def color_for(ch):
    if ch in "&":
        return LEAF
    if ch in "*@":
        return BLOOM
    if ch in "=-~^.":
        return GROUND
    return TRUNK


def parse_trees():
    text = SOURCE.read_text()
    trees = {}
    for match in re.finditer(r"local (\w+) = \[\[\n(.*?)\]\]", text, re.DOTALL):
        name, body = match.groups()
        lines = [line.replace("\t", "") for line in body.splitlines()]
        trees[name] = lines
    return trees


def main():
    trees = parse_trees()
    frames = [trees[name] for name in ORDER]

    tree_rows = max(len(f) for f in frames)
    cols = max(len(line) for f in frames for line in f)
    cols = max(cols, max(len(line) for line in MENU), len(FOOTER))

    # Dashboard rows below the tree: gap, clock, gap, menu, gap, footer.
    dash = [""] + ["{clock}"] + [""] + MENU + [""] + [FOOTER]
    rows = tree_rows + len(dash)

    bbox = FONT.getbbox("M")
    char_w = bbox[2] - bbox[0]
    char_h = int(FONT.size * 1.2)
    pad = 24
    width = cols * char_w + 2 * pad
    height = rows * char_h + 2 * pad

    def draw_text(draw, row, text, color, key_cols=0):
        left = (cols - len(text)) // 2
        for col, ch in enumerate(text):
            if ch == " ":
                continue
            x = pad + (left + col) * char_w
            y = pad + row * char_h
            fill = MENU_KEY if key_cols and col < key_cols else color
            draw.text((x, y), ch, font=FONT, fill=fill)

    images = []
    for frame, clock in zip(frames, HOURS):
        img = Image.new("RGB", (width, height), BG)
        draw = ImageDraw.Draw(img)
        # Anchor the ground line to the bottom of the tree area so the tree
        # grows upward, and center each stage horizontally.
        top = tree_rows - len(frame)
        left = (cols - max(len(line) for line in frame)) // 2
        for row, line in enumerate(frame):
            for col, ch in enumerate(line):
                if ch == " ":
                    continue
                x = pad + (left + col) * char_w
                y = pad + (top + row) * char_h
                draw.text((x, y), ch, font=FONT, fill=color_for(ch))

        for i, line in enumerate(dash):
            row = tree_rows + i
            if line == "{clock}":
                draw_text(draw, row, clock, CLOCK)
            elif line == FOOTER:
                draw_text(draw, row, line, FOOTER_TEXT)
            elif line:
                draw_text(draw, row, line, MENU_TEXT, key_cols=3)
        images.append(img)

    durations = [FRAME_MS] * (len(images) - 1) + [LAST_FRAME_MS]
    OUT.parent.mkdir(exist_ok=True)
    images[0].save(
        OUT,
        save_all=True,
        append_images=images[1:],
        duration=durations,
        loop=0,
    )
    print(f"wrote {OUT} ({width}x{height}, {len(images)} frames)")


if __name__ == "__main__":
    main()
