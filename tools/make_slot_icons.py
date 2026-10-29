"""Ícones das peças de equipamento (elmo, calças, luvas, botas, colar, brincos, anel) por raridade.
Gera textures/items/slot_<slot>_<raridade>.png (128x128). Rodar: python tools/make_slot_icons.py"""
import os

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "textures", "items")
RARITY = {"comum": (210, 210, 210), "rara": (90, 158, 255), "epica": (184, 107, 255), "lendaria": (255, 194, 66)}
METAL = {"comum": (150, 140, 128), "rara": (120, 160, 210), "epica": (150, 110, 200), "lendaria": (240, 190, 70)}
LINE = (20, 12, 10)


def frame(r):
    im = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    c = RARITY[r]
    d.rounded_rectangle((4, 4, 123, 123), 18, fill=(28, 20, 26, 235), outline=c, width=4)
    glow = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse((24, 24, 104, 104), fill=c + (70,))
    im.alpha_composite(glow.filter(ImageFilter.GaussianBlur(14)))
    return im, ImageDraw.Draw(im)


def helmet(d, m, c):
    d.chord((30, 26, 98, 100), 180, 360, fill=m, outline=LINE, width=4)
    d.rectangle((30, 62, 98, 74), fill=m, outline=LINE, width=4)
    d.rectangle((58, 62, 70, 96), fill=m, outline=LINE, width=4)
    d.polygon([(64, 14), (72, 30), (56, 30)], fill=c, outline=LINE)


def pants(d, m, c):
    d.polygon([(38, 28), (90, 28), (96, 106), (72, 106), (64, 56), (56, 106), (32, 106)], fill=m, outline=LINE, width=4)
    d.rectangle((38, 28, 90, 40), fill=c, outline=LINE, width=4)


def gloves(d, m, c):
    d.rounded_rectangle((40, 40, 88, 92), 12, fill=m, outline=LINE, width=4)
    for i in range(4):
        d.rounded_rectangle((42 + i * 12, 20, 52 + i * 12, 50), 5, fill=m, outline=LINE, width=3)
    d.rounded_rectangle((22, 56, 46, 70), 6, fill=m, outline=LINE, width=3)
    d.rectangle((40, 88, 88, 104), fill=c, outline=LINE, width=4)


def boots(d, m, c):
    d.polygon([(40, 20), (70, 20), (70, 78), (100, 86), (100, 104), (40, 104)], fill=m, outline=LINE, width=4)
    d.rectangle((38, 20, 72, 32), fill=c, outline=LINE, width=4)


def necklace(d, m, c):
    d.arc((26, 14, 102, 90), 20, 160, fill=LINE, width=8)
    d.arc((26, 14, 102, 90), 20, 160, fill=m, width=4)
    d.polygon([(64, 76), (80, 94), (64, 114), (48, 94)], fill=c, outline=LINE, width=4)


def earring(d, m, c):
    for x in (42, 86):
        d.ellipse((x - 12, 22, x + 12, 46), outline=LINE, width=8)
        d.ellipse((x - 12, 22, x + 12, 46), outline=m, width=4)
        d.polygon([(x, 50), (x + 12, 72), (x, 98), (x - 12, 72)], fill=c, outline=LINE, width=3)


def ring(d, m, c):
    d.ellipse((30, 42, 98, 110), outline=LINE, width=16)
    d.ellipse((34, 46, 94, 106), outline=m, width=8)
    d.polygon([(64, 14), (84, 34), (64, 54), (44, 34)], fill=c, outline=LINE, width=4)


DRAW = {"helmet": helmet, "pants": pants, "gloves": gloves, "boots": boots, "necklace": necklace, "earring": earring, "ring": ring}

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for slot, fn in DRAW.items():
        for r in RARITY:
            im, d = frame(r)
            fn(d, METAL[r], RARITY[r])
            im.save(os.path.join(OUT, f"slot_{slot}_{r}.png"))
    print("ok", len(DRAW) * len(RARITY), "ícones")
