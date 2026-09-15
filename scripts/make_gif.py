"""Render the bonsai stages from lua/bonsai/init.lua into assets/bonsai.gif."""

import re
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "lua" / "bonsai" / "init.lua"
OUT = ROOT / "assets" / "bonsai.gif"

# Growth order, ending with the dead tree.
ORDER = ["smallest", "baby", "teen", "adult", "middle_aged", "old", "older"]

BG = (24, 24, 33)
LEAF = (140, 190, 100)
BLOOM = (220, 160, 190)
TRUNK = (180, 140, 100)
GROUND = (120, 120, 135)

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

    rows = max(len(f) for f in frames)
    cols = max(len(line) for f in frames for line in f)

    bbox = FONT.getbbox("M")
    char_w = bbox[2] - bbox[0]
    char_h = int(FONT.size * 1.2)
    pad = 24
    width = cols * char_w + 2 * pad
    height = rows * char_h + 2 * pad

    images = []
    for frame in frames:
        img = Image.new("RGB", (width, height), BG)
        draw = ImageDraw.Draw(img)
        # Anchor the ground line to the bottom so the tree grows upward,
        # and center each stage horizontally.
        top = rows - len(frame)
        left = (cols - max(len(line) for line in frame)) // 2
        for row, line in enumerate(frame):
            for col, ch in enumerate(line):
                if ch == " ":
                    continue
                x = pad + (left + col) * char_w
                y = pad + (top + row) * char_h
                draw.text((x, y), ch, font=FONT, fill=color_for(ch))
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
