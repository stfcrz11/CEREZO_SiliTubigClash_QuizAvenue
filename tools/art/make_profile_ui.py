"""Pixel art for the title screen's profile card and rename window:
the SAVE button, the little avatar head and the gold pencil.
Uses the palette, pixel font and button() from make_ui.py (only its
definitions are loaded, so the other UI pictures are NOT redrawn).

usage: python make_profile_ui.py <project dir>
"""
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
with open(os.path.join(HERE, "make_ui.py"), encoding="utf-8") as f:
    src = f.read()
exec(src.split("\nmake_buttons()")[0])   # palette, font, button(), scaled() ...

# SAVE matches CANCEL (same size, gold like the other "yes" buttons)
button("SAVE", GOLD, (420, 112), DARK_TEXT).save(f"{UI}/button_save.png")

SKIN = (234, 182, 138)
HAIR = (78, 50, 34)
EYE = DARK_TEXT

PICTURES = {
    # 12x12 grid, drawn x4, with a dark outline like the result icons
    "icon_avatar": ({"H": HAIR, "S": SKIN, "E": EYE, "B": BLUE, "b": shade(BLUE, 0.7)}, [
        "...HHHHHH...",
        "..HHHHHHHH..",
        ".HHHHHHHHHH.",
        ".HHSSSSSSHH.",
        ".HSSSSSSSSH.",
        ".HSESSSSESH.",
        "..SSSSSSSS..",
        "...SSSSSS...",
        "....SSSS....",
        "..BBBBBBBB..",
        ".BBBBBBBBBB.",
        ".BBbBBBBbBB."]),
    "icon_pencil": ({"P": (232, 120, 130), "M": GRAY, "G": GOLD, "g": GOLD_LO, "W": WOOD_HI, "D": DARK_TEXT}, [
        "............",
        "........PP..",
        ".......PPPP.",
        "......MMPPP.",
        ".....GGMMP..",
        "....GGGgM...",
        "...GGGgg....",
        "..GGGgg.....",
        ".WWGgg......",
        ".WWWg.......",
        ".DW.........",
        "............"]),
}
for name, (colors, rows) in PICTURES.items():
    im = Image.new("RGBA", (12, 12), (0, 0, 0, 0))
    p = im.load()
    for y, row in enumerate(rows):
        for x, c in enumerate(row):
            if c in colors:
                p[x, y] = colors[c] + (255,)
    out = im.copy()
    po = out.load()
    for y in range(12):
        for x in range(12):
            if p[x, y][3] == 0 and any(0 <= x + dx < 12 and 0 <= y + dy < 12 and p[x + dx, y + dy][3]
                                       for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                po[x, y] = OUT + (255,)
    scaled(out, 4).save(f"{UI}/{name}.png")
print("profile ui saved")
