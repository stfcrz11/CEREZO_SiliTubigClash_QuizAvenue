"""Bitmap font from the same 5x7 pixel letters as the buttons (make_ui.py),
saved as a BMFont (.fnt + .png) that Godot imports as a normal Font. Used for
titles, plaques, headlines and the countdown so they match the pixel art.

Each font pixel is drawn 2x2, so the font is 16 px tall (letters 14 px).
Use font sizes that are multiples of 16 (16, 32, 48 ...) for the sharpest look.
Lower-case letters use the capital shapes.

usage: python make_pixel_font.py <project dir>
"""
import os
import sys

from PIL import Image

sys.argv = [sys.argv[0], sys.argv[1]]
ROOT = sys.argv[1]
# only the FONT table is needed: read it without running the UI generator
src = open(os.path.join(os.path.dirname(__file__), "make_ui.py"), encoding="utf-8").read()
font_src = src[src.index("FONT = {"):src.index("}\n", src.index("FONT = {")) + 2]
ns = {}
exec(font_src, ns)
FONT = dict(ns["FONT"])
FONT.update({
    ",": [".....", ".....", ".....", ".....", ".....", "..#..", ".#..."],
    "(": ["...#.", "..#..", ".#...", ".#...", ".#...", "..#..", "...#."],
    ")": [".#...", "..#..", "...#.", "...#.", "...#.", "..#..", ".#..."],
    "+": [".....", "..#..", "..#..", "#####", "..#..", "..#..", "....."],
    "%": ["##..#", "##..#", "...#.", "..#..", ".#...", "#..##", "#..##"],
    '"': [".#.#.", ".#.#.", ".....", ".....", ".....", ".....", "....."],
    "#": [".#.#.", "#####", ".#.#.", ".#.#.", "#####", ".#.#.", "....."],
    "&": [".##..", "#..#.", ".##..", ".#..#", "#.##.", "#..#.", ".##.#"],
    "=": [".....", ".....", "#####", ".....", "#####", ".....", "....."],
    "<": ["...#.", "..#..", ".#...", "#....", ".#...", "..#..", "...#."],
    ">": [".#...", "..#..", "...#.", "....#", "...#.", "..#..", ".#..."],
    "*": [".....", "#.#.#", ".###.", "#####", ".###.", "#.#.#", "....."],
})
ALIASES = {"—": "-", "–": "-", "·": ".", "Ñ": "N", "ñ": "N", "×": "X", "’": "'"}

S = 2                     # font pixel -> 2x2 image pixels
GW, GH = 5 * S, 7 * S     # glyph size
ADV = GW + S              # 1 font pixel of spacing
LINE = 16
COLS = 16

chars = sorted(FONT)
rows = (len(chars) + COLS - 1) // COLS
img = Image.new("RGBA", (COLS * (GW + 2), rows * (GH + 2)), (0, 0, 0, 0))
px = img.load()
pos = {}
for i, ch in enumerate(chars):
    ox, oy = (i % COLS) * (GW + 2) + 1, (i // COLS) * (GH + 2) + 1
    pos[ch] = (ox, oy)
    for y, row in enumerate(FONT[ch]):
        for x, c in enumerate(row):
            if c == "#":
                for dy in range(S):
                    for dx in range(S):
                        px[ox + x * S + dx, oy + y * S + dy] = (255, 255, 255, 255)

os.makedirs(f"{ROOT}/assets/fonts", exist_ok=True)
img.save(f"{ROOT}/assets/fonts/pixel5x7.png")

entries = []


def add(code, ch):
    x, y = pos[ch]
    entries.append(f"char id={code} x={x} y={y} width={GW} height={GH} xoffset=0 yoffset=1 xadvance={ADV} page=0 chnl=15")


for ch in chars:
    add(ord(ch), ch)
    if ch.isalpha():
        add(ord(ch.lower()), ch)
for a, b in ALIASES.items():
    add(ord(a), b)
entries.append(f"char id=32 x=0 y=0 width=0 height=0 xoffset=0 yoffset=0 xadvance={3 * S} page=0 chnl=15")
fnt = [
    'info face="Pixel5x7" size=16 bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=0 aa=1 padding=0,0,0,0 spacing=0,0',
    f"common lineHeight={LINE} base={GH} scaleW={img.width} scaleH={img.height} pages=1 packed=0",
    'page id=0 file="pixel5x7.png"',
    f"chars count={len(entries)}",
] + entries
open(f"{ROOT}/assets/fonts/pixel5x7.fnt", "w", encoding="utf-8", newline="\n").write("\n".join(fnt) + "\n")
print("font saved:", len(entries), "characters")
