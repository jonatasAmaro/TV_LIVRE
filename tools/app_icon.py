# Channel icon: white outline TV + TV box on teal, "TV LIVRE" on the screen.
# Uso: python -I tools/app_icon.py <pasta-images>
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

out = Path(sys.argv[1])
BG = (85, 128, 129)
WHITE = (255, 255, 255)


def draw(w, h):
    k = 4  # supersampling
    W, H = w * k, h * k
    im = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(im)
    # Drawing is laid out on the reference art's grid (TV at x 125-445, y 175-425)
    # and scaled to ~68% of the icon height, centered.
    s = H * 0.68 / 250
    ox = (W - 320 * s) / 2 - 125 * s
    oy = (H - 250 * s) / 2 - 175 * s

    def p(x, y):
        return (ox + x * s, oy + y * s)

    def box(x0, y0, x1, y1):
        return [p(x0, y0), p(x1, y1)]

    line = round(11 * s)
    d.rounded_rectangle(box(125, 175, 445, 360), radius=16 * s, outline=WHITE, width=line)
    d.rectangle(box(256, 355, 314, 380), fill=WHITE)
    # Base bar with the cable turning down on the left.
    d.rounded_rectangle(box(212, 375, 330, 388), radius=6 * s, fill=WHITE)
    d.rounded_rectangle(box(210, 375, 222, 416), radius=6 * s, fill=WHITE)
    # TV box in front of the stand.
    d.rounded_rectangle(box(318, 368, 447, 427), radius=26 * s, fill=BG)
    d.rounded_rectangle(box(322, 372, 443, 423), radius=24 * s, outline=WHITE, width=round(10 * s))
    d.rectangle(box(403, 393, 414, 404), fill=WHITE)

    font = ImageFont.truetype("segoeui.ttf", round(50 * s))
    text = "TV LIVRE"
    tw = d.textlength(text, font=font)
    cx, cy = p(285, 268)
    top = font.getbbox(text)[1]
    bottom = font.getbbox(text)[3]
    d.text((cx - tw / 2, cy - (top + bottom) / 2), text, font=font, fill=WHITE)
    return im.resize((w, h), Image.LANCZOS)


draw(290, 218).save(out / "icon_hd.png")
draw(540, 405).save(out / "icon_fhd.png")
print("app icon ok")
