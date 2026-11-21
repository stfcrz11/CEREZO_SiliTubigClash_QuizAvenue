"""Store-front pieces that tile, for windows of any width
(scenes/pixel_store.gd): the rooftop + brick band, the striped awnings, the
"BAWAL ANG UTANG" sign, the title planks and the water-drop icon.
Same drawing as store_top() in make_ui.py, cut into repeatable pieces and
saved at 1x (the game scales them by a whole number, nearest-neighbour).
Uses the palette and helpers from make_ui.py (only its definitions are
loaded, so the other UI pictures are NOT redrawn).

usage: python make_store_parts.py <project dir>
"""
import os

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
with open(os.path.join(HERE, "make_ui.py"), encoding="utf-8") as f:
    exec(f.read().split("\nmake_buttons()")[0])   # palette, rect(), put(), shade(), draw_small() ...

OUT_DIR = f"{UI}/store_parts"
os.makedirs(OUT_DIR, exist_ok=True)


def roof_band():
    """Rooftop parapet + brick wall, 8x32 (repeats sideways)."""
    w, h = 8, 32
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = im.load()
    rect(px, 0, 0, w, 2, OUT)
    rect(px, 0, 2, w, 3, HI)
    rect(px, 0, 3, w, 7, PARAPET)
    rect(px, 0, 7, w, 8, EDGE)
    rect(px, 0, 8, w, 32, BRICK)
    for y in range(8, 32):
        for x in range(w):
            row = (y - 8) // 4
            if (y - 8) % 4 == 3 or (x + (row % 2) * 4) % 8 == 0:
                put(px, x, y, BRICK_LO)
    return im


def awning(color):
    """Two awning stripes with the scalloped edge, 16x27 (repeats sideways)."""
    dark = shade(color, 0.6)
    w, h = 16, 27
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = im.load()
    for y in range(0, 20):
        for x in range(w):
            c = color if (x // 8) % 2 == 0 else AWN_WHITE
            if y < 2:
                c = shade(c, 0.8)
            put(px, x, y, c)
    for x in range(w):
        put(px, x, 0, AWN_LINE)
        depth = [2, 4, 5, 6, 6, 5, 4, 2][x % 8]
        c = color if (x // 8) % 2 == 0 else AWN_WHITE
        for y in range(20, 20 + depth):
            put(px, x, y, c if y < 19 + depth else dark)
        put(px, x, 20 + depth, AWN_LINE)
    return im


def sign():
    """The "BAWAL ANG UTANG" joke sign, 67x12."""
    im = Image.new("RGBA", (67, 12), (0, 0, 0, 0))
    px = im.load()
    rect(px, 0, 0, 67, 12, OUT)
    rect(px, 1, 1, 66, 11, WHITE)
    draw_small(px, 4, 3, "BAWAL ANG UTANG", AWN_RED)
    return im


def plank(fill, lo, hi):
    """Title plank as a 9-slice, 12x12 (margins 3)."""
    im = Image.new("RGBA", (12, 12), (0, 0, 0, 0))
    px = im.load()
    rect(px, 0, 0, 12, 12, OUT)
    rect(px, 1, 1, 11, 11, lo)
    rect(px, 2, 2, 10, 10, fill)
    rect(px, 2, 2, 10, 3, hi)
    return im


def drop():
    """Water drop for a Tubig win, 12x14, with a dark outline."""
    rows = [
        ".....#......",
        ".....##.....",
        "....###.....",
        "....####....",
        "...#####....",
        "...######...",
        "..##W#####..",
        "..#WW#####..",
        ".##W#######.",
        ".##W#######.",
        ".##########.",
        "..########..",
        "..#######...",
        "....####....",
    ]
    light, mid = (150, 214, 255), BLUE
    im = Image.new("RGBA", (12, 14), (0, 0, 0, 0))
    p = im.load()
    for y, row in enumerate(rows):
        for x, c in enumerate(row):
            if c == "#":
                p[x, y] = (mid if x > 5 or y < 6 else light) + (255,)
            elif c == "W":
                p[x, y] = WHITE + (255,)
    out = im.copy()
    po = out.load()
    for y in range(14):
        for x in range(12):
            if p[x, y][3] == 0 and any(0 <= x + dx < 12 and 0 <= y + dy < 14 and p[x + dx, y + dy][3]
                                       for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                po[x, y] = OUT + (255,)
    return out


roof_band().save(f"{OUT_DIR}/roof_band.png")
awning(AWN_RED).save(f"{OUT_DIR}/awning_red.png")
awning(BLUE).save(f"{OUT_DIR}/awning_blue.png")
sign().save(f"{OUT_DIR}/sign_utang.png")
plank(GOLD, GOLD_LO, GOLD_HI).save(f"{OUT_DIR}/plank_gold.png")
plank((52, 120, 210), (30, 72, 140), (120, 184, 250)).save(f"{OUT_DIR}/plank_blue.png")
plank((200, 54, 44), (130, 30, 24), (240, 120, 100)).save(f"{OUT_DIR}/plank_red.png")
drop().save(f"{OUT_DIR}/icon_drop.png")
print("store parts saved")
