"""White media icons for the full-screen player panel (the system font has no such glyphs).

Usage: python -I tools/media_icons.py roku-tv-livre/images
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw

out = Path(sys.argv[1])
S, K = 64, 4  # final size, supersampling factor


def icon(name, shapes):
    big = Image.new("RGBA", (S * K, S * K), (0, 0, 0, 0))
    d = ImageDraw.Draw(big)
    for kind, pts in shapes:
        pts = [(x * K, y * K) for x, y in pts]
        if kind == "poly":
            d.polygon(pts, fill=(255, 255, 255, 255))
        else:
            d.rectangle([pts[0], pts[1]], fill=(255, 255, 255, 255))
    big.resize((S, S), Image.LANCZOS).save(out / name)


icon("media_play.png", [("poly", [(20, 12), (52, 32), (20, 52)])])
icon("media_pause.png", [("rect", [(16, 12), (27, 52)]), ("rect", [(37, 12), (48, 52)])])
icon("media_ff.png", [("poly", [(8, 14), (32, 32), (8, 50)]), ("poly", [(32, 14), (56, 32), (32, 50)])])
icon("media_rew.png", [("poly", [(56, 14), (32, 32), (56, 50)]), ("poly", [(32, 14), (8, 32), (32, 50)])])
print("media icons ok")
