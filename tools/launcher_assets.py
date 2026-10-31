# Images for the launcher screen (LauncherView).
# Uso: python -I tools/launcher_assets.py <wallpaper-origem> <pasta-images>
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

src, out = Path(sys.argv[1]), Path(sys.argv[2])
W, H = 1920, 1080


def font(size, bold=True):
    name = "segoeuib.ttf" if bold else "segoeui.ttf"
    try:
        return ImageFont.truetype(name, size)
    except OSError:
        return ImageFont.load_default()


def wallpaper():
    im = Image.open(src).convert("RGB")
    scale = max(W / im.width, H / im.height)
    im = im.resize((round(im.width * scale), round(im.height * scale)), Image.LANCZOS)
    left, top = (im.width - W) // 2, (im.height - H) // 2
    im.crop((left, top, left + W, top + H)).save(out / "launcher_wallpaper.jpg", quality=86, optimize=True)


def shade():
    # Dark band behind the carousel; transparent at the top, ~88% at the bottom.
    h = 560
    im = Image.new("RGBA", (W, h))
    px = im.load()
    for y in range(h):
        t = y / (h - 1)
        a = round(225 * (t ** 1.6))
        for x in range(W):
            px[x, y] = (6, 10, 20, a)
    im.save(out / "launcher_shade.png")


def gradient_card(w, h, c1, c2):
    im = Image.new("RGB", (w, h))
    d = ImageDraw.Draw(im)
    for y in range(h):
        t = y / (h - 1)
        d.line([(0, y), (w, y)], fill=tuple(round(a + (b - a) * t) for a, b in zip(c1, c2)))
    return im


def label(d, w, y, text, size):
    f = font(size)
    tw = d.textlength(text, font=f)
    d.text(((w - tw) / 2, y), text, font=f, fill=(255, 255, 255))


def card_inputs():
    w, h = 480, 360
    im = gradient_card(w, h, (40, 52, 84), (14, 18, 32))
    d = ImageDraw.Draw(im)
    # Screen with an arrow coming in from the left (same idea as a TV "Source" key).
    d.rounded_rectangle([170, 80, 330, 190], radius=14, outline=(255, 255, 255), width=10)
    d.line([(110, 135), (235, 135)], fill=(155, 93, 229), width=14)
    d.polygon([(235, 105), (275, 135), (235, 165)], fill=(155, 93, 229))
    d.line([(215, 205), (285, 205)], fill=(255, 255, 255), width=10)
    label(d, w, 248, "Conexões", 52)
    im.save(out / "card_inputs.png")


def card_store():
    w, h = 480, 360
    im = gradient_card(w, h, (110, 48, 170), (36, 14, 66))
    d = ImageDraw.Draw(im)
    s, g, x0, y0 = 50, 16, 182, 70
    for r in range(2):
        for c in range(2):
            x, y = x0 + c * (s + g), y0 + r * (s + g)
            if r == 0 and c == 1:
                # Plus sign in one slot: "add a channel".
                d.line([(x + 6, y + s / 2), (x + s - 6, y + s / 2)], fill=(255, 255, 255), width=10)
                d.line([(x + s / 2, y + 6), (x + s / 2, y + s - 6)], fill=(255, 255, 255), width=10)
            else:
                d.rounded_rectangle([x, y, x + s, y + s], radius=10, fill=(255, 255, 255))
    label(d, w, 228, "Central de Apps", 46)
    label(d, w, 290, "Loja de canais Roku", 26)
    im.save(out / "card_store.png")


def nine_patch(name, size, radius, draw_fn):
    # Android-style 9-patch: 1px border, black marks = stretchable middle.
    body = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw_fn(ImageDraw.Draw(body), size, radius)
    im = Image.new("RGBA", (size + 2, size + 2), (0, 0, 0, 0))
    im.paste(body, (1, 1))
    px = im.load()
    for i in range(radius + 2, size - radius):
        px[i, 0] = (0, 0, 0, 255)
        px[0, i] = (0, 0, 0, 255)
    im.save(out / name)


def arrow(name, left):
    # White triangle used beside the card in move mode (the system font has no arrow glyphs).
    s, k = 48, 4
    big = Image.new("RGBA", (s * k, s * k), (0, 0, 0, 0))
    pts = [(14, 6), (38, 24), (14, 42)]
    if left:
        pts = [(s - x, y) for x, y in pts]
    ImageDraw.Draw(big).polygon([(x * k, y * k) for x, y in pts], fill=(255, 255, 255, 255))
    big = big.resize((s, s), Image.LANCZOS)
    big.save(out / name)
    return big


def circle():
    s = 4
    big = Image.new("RGBA", (96 * s, 96 * s), (0, 0, 0, 0))
    ImageDraw.Draw(big).ellipse([0, 0, 96 * s - 1, 96 * s - 1], fill=(255, 255, 255, 255))
    big.resize((96, 96), Image.LANCZOS).save(out / "circle.png")
    # Selection outline for the round gear button.
    big = Image.new("RGBA", (120 * s, 120 * s), (0, 0, 0, 0))
    ImageDraw.Draw(big).ellipse([0, 0, 120 * s - 1, 120 * s - 1], outline=(255, 255, 255, 255), width=5 * s)
    big.resize((120, 120), Image.LANCZOS).save(out / "circle_ring.png")


wallpaper()
shade()
card_inputs()
card_store()
nine_patch("ring.9.png", 32, 6, lambda d, s, r: d.rounded_rectangle([0, 0, s - 1, s - 1], radius=r, outline=(255, 255, 255, 255), width=5))
arrow("arrow_left.png", True)
# Down arrow for the season combobox (series screen).
arrow("arrow_right.png", False).rotate(-90).save(out / "arrow_down.png")
nine_patch("panel.9.png", 64, 20, lambda d, s, r: d.rounded_rectangle([0, 0, s - 1, s - 1], radius=r, fill=(255, 255, 255, 255)))
circle()
print("launcher assets ok")
