"""Ícones da loja, dos materiais da forja e do Mercadinho, desenhados por código (PIL).
Gera textures/shop/<id>.png (128x128) para cada item de GameData.SHOP e textures/shop/mat_<material>.png.
Rodar: python tools/make_shop_icons.py"""
import math
import os

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "textures", "shop")
L = (24, 14, 10)   # contorno


def base(col):
    im = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((4, 4, 123, 123), 20, fill=(26, 18, 24, 240), outline=col, width=4)
    g = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    ImageDraw.Draw(g).ellipse((22, 22, 106, 106), fill=col + (80,))
    im.alpha_composite(g.filter(ImageFilter.GaussianBlur(14)))
    return im, ImageDraw.Draw(im)


def star(d, cx, cy, r, col, n=5):
    pts = []
    for i in range(n * 2):
        a = -math.pi / 2 + i * math.pi / n
        rr = r if i % 2 == 0 else r * 0.45
        pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    d.polygon(pts, fill=col, outline=L)


def rune(d, col, sym):
    d.polygon([(64, 16), (100, 40), (94, 100), (34, 100), (28, 40)], fill=(90, 84, 92), outline=L, width=4)
    sym(d, col)


def sym_sword(d, col):
    d.polygon([(64, 30), (72, 40), (68, 80), (60, 80), (56, 40)], fill=col, outline=L, width=3)
    d.rectangle((50, 80, 78, 86), fill=col, outline=L, width=2)
    d.rectangle((61, 86, 67, 96), fill=col, outline=L, width=2)


def sym_heart(d, col):
    d.ellipse((42, 40, 66, 64), fill=col, outline=L, width=3)
    d.ellipse((62, 40, 86, 64), fill=col, outline=L, width=3)
    d.polygon([(44, 56), (84, 56), (64, 90)], fill=col)
    d.line([(44, 58), (64, 90), (84, 58)], fill=L, width=3)


def sym_swirl(d, col):
    for i, r in enumerate((26, 18, 10)):
        d.arc((64 - r, 62 - r, 64 + r, 62 + r), 30 + i * 60, 330 + i * 60, fill=col, width=6)


def draw_boot(d, col):
    d.polygon([(40, 26), (70, 26), (70, 80), (102, 88), (102, 104), (40, 104)], fill=col, outline=L, width=4)
    for y in (40, 56, 72):
        d.line([(14, y), (34, y)], fill=(220, 240, 255), width=4)


def draw_sword(d, col):
    d.polygon([(64, 12), (74, 26), (70, 86), (58, 86), (54, 26)], fill=col, outline=L, width=4)
    d.rectangle((40, 84, 88, 92), fill=(180, 120, 50), outline=L, width=3)
    d.rectangle((59, 92, 69, 112), fill=(110, 70, 40), outline=L, width=3)


def draw_chest(d, col):
    d.polygon([(30, 30), (50, 22), (64, 30), (78, 22), (98, 30), (92, 104), (36, 104)], fill=col, outline=L, width=4)
    d.line([(64, 30), (64, 104)], fill=L, width=3)
    star(d, 64, 58, 12, (255, 240, 180))


def draw_jewels(d, col):
    d.arc((26, 16, 102, 82), 20, 160, fill=L, width=8)
    d.arc((26, 16, 102, 82), 20, 160, fill=col, width=4)
    d.polygon([(64, 70), (78, 86), (64, 104), (50, 86)], fill=(120, 220, 255), outline=L, width=3)
    d.ellipse((80, 80, 110, 110), outline=L, width=8)
    d.ellipse((82, 82, 108, 108), outline=col, width=4)


def draw_shield(d, col):
    d.polygon([(64, 16), (102, 30), (96, 78), (64, 110), (32, 78), (26, 30)], fill=col, outline=L, width=4)
    d.polygon([(64, 32), (86, 40), (82, 72), (64, 92), (46, 72), (42, 40)], fill=(220, 240, 255), outline=L, width=3)


def draw_potion(d, col):
    d.rectangle((54, 18, 74, 40), fill=(200, 200, 210), outline=L, width=3)
    d.rectangle((50, 14, 78, 22), fill=(150, 100, 60), outline=L, width=3)
    d.ellipse((30, 36, 98, 106), fill=col, outline=L, width=4)
    d.ellipse((44, 50, 58, 62), fill=(255, 255, 255, 200))


def draw_scroll(d, col):
    d.rectangle((30, 30, 98, 96), fill=(240, 225, 180), outline=L, width=4)
    d.ellipse((22, 22, 42, 42), fill=(210, 190, 140), outline=L, width=3)
    d.ellipse((86, 84, 106, 104), fill=(210, 190, 140), outline=L, width=3)
    d.text((46, 46), "XP", fill=(120, 70, 20))
    for y in (68, 78):
        d.line([(42, y), (86, y)], fill=(150, 110, 60), width=3)
    star(d, 84, 46, 10, col)


def draw_bag(d, col):
    d.polygon([(48, 30), (80, 30), (72, 40), (98, 70), (94, 104), (34, 104), (30, 70), (56, 40)], fill=(150, 100, 50), outline=L, width=4)
    d.ellipse((50, 60, 78, 88), fill=col, outline=L, width=3)
    d.text((59, 66), "$", fill=L)


def draw_owl(d, col):
    d.ellipse((30, 26, 98, 108), fill=col, outline=L, width=4)
    for x in (50, 78):
        d.ellipse((x - 13, 46, x + 13, 72), fill=(255, 255, 230), outline=L, width=3)
        d.ellipse((x - 5, 54, x + 5, 64), fill=L)
    d.polygon([(58, 74), (70, 74), (64, 86)], fill=(240, 180, 60), outline=L)
    d.polygon([(34, 30), (44, 14), (50, 32)], fill=col, outline=L)
    d.polygon([(94, 30), (84, 14), (78, 32)], fill=col, outline=L)


def draw_jelly(d, col):
    d.chord((26, 20, 102, 88), 180, 360, fill=col, outline=L, width=4)
    d.line([(26, 54), (102, 54)], fill=L, width=4)
    for x in (38, 52, 66, 80, 92):
        d.line([(x, 56), (x + 4, 76), (x - 2, 96), (x + 2, 110)], fill=col, width=5)


def draw_fish(d, col):
    d.ellipse((24, 40, 92, 88), fill=col, outline=L, width=4)
    d.polygon([(88, 64), (110, 44), (110, 84)], fill=col, outline=L, width=3)
    d.ellipse((38, 54, 50, 66), fill=(255, 255, 255), outline=L, width=2)


def draw_wolf(d, col):
    d.polygon([(64, 104), (30, 70), (26, 26), (48, 44), (64, 38), (80, 44), (102, 26), (98, 70)], fill=col, outline=L, width=4)
    for x in (50, 78):
        d.ellipse((x - 6, 58, x + 6, 68), fill=(255, 220, 80), outline=L, width=2)
    d.polygon([(56, 84), (72, 84), (64, 96)], fill=L)


def draw_dragon(d, col):
    d.polygon([(20, 60), (50, 30), (90, 40), (108, 64), (84, 72), (92, 96), (60, 84), (36, 96)], fill=col, outline=L, width=4)
    d.polygon([(50, 32), (42, 12), (60, 30)], fill=(230, 220, 190), outline=L)
    d.polygon([(70, 34), (70, 12), (82, 36)], fill=(230, 220, 190), outline=L)
    d.ellipse((74, 48, 86, 58), fill=(255, 220, 60), outline=L, width=2)
    d.polygon([(108, 64), (122, 58), (116, 70)], fill=(255, 140, 40))


def draw_slime(d, col):
    d.chord((22, 34, 106, 120), 180, 360, fill=col, outline=L, width=4)
    d.rectangle((22, 76, 106, 104), fill=col)
    d.line([(22, 104), (106, 104)], fill=L, width=4)
    d.line([(22, 76), (22, 104)], fill=L, width=4)
    d.line([(106, 76), (106, 104)], fill=L, width=4)
    for x in (48, 80):
        d.ellipse((x - 8, 64, x + 8, 82), fill=(255, 255, 255), outline=L, width=2)
        d.ellipse((x - 3, 70, x + 3, 78), fill=L)


def draw_scorpion(d, col):
    d.ellipse((32, 56, 96, 96), fill=col, outline=L, width=4)
    d.arc((60, 14, 112, 76), 180, 330, fill=L, width=10)
    d.arc((60, 14, 112, 76), 180, 330, fill=col, width=6)
    d.polygon([(100, 22), (112, 14), (110, 30)], fill=(255, 220, 80), outline=L)
    for x in (24, 104):
        d.ellipse((x - 10, 62, x + 10, 80), fill=col, outline=L, width=3)


def draw_golem(d, col):
    d.rectangle((40, 30, 88, 92), fill=col, outline=L, width=4)
    d.rectangle((50, 14, 78, 36), fill=col, outline=L, width=4)
    d.rectangle((20, 40, 40, 82), fill=col, outline=L, width=4)
    d.rectangle((88, 40, 108, 82), fill=col, outline=L, width=4)
    for x in (58, 70):
        d.rectangle((x - 3, 22, x + 3, 28), fill=(255, 200, 60))
    for (x, y) in ((56, 52), (70, 66), (60, 78)):
        d.line([(x, y), (x + 10, y + 6)], fill=(255, 120, 30), width=3)


def saddle(d):
    d.rounded_rectangle((44, 98, 84, 112), 6, fill=(150, 60, 40), outline=L, width=3)


def draw_ingot(d, col):
    d.polygon([(26, 84), (40, 50), (88, 50), (102, 84)], fill=col, outline=L, width=4)
    d.polygon([(40, 50), (50, 38), (98, 38), (88, 50)], fill=tuple(min(255, c + 40) for c in col), outline=L, width=3)


def draw_crystal(d, col):
    d.polygon([(64, 14), (88, 46), (78, 108), (50, 108), (40, 46)], fill=col, outline=L, width=4)
    d.line([(64, 14), (64, 108)], fill=(255, 255, 255, 160), width=2)


def draw_essence(d, col):
    d.ellipse((30, 30, 98, 98), fill=col, outline=L, width=4)
    d.ellipse((46, 44, 62, 60), fill=(255, 255, 255, 200))
    for a in range(0, 360, 45):
        r = math.radians(a)
        d.line([(64 + 40 * math.cos(r), 64 + 40 * math.sin(r)), (64 + 52 * math.cos(r), 64 + 52 * math.sin(r))], fill=col, width=4)


GOLD = (255, 196, 70)
ICONS = {
    "runa_forca": ((240, 90, 70), lambda d, c: rune(d, c, sym_sword)),
    "runa_vigor": ((90, 220, 110), lambda d, c: rune(d, c, sym_heart)),
    "runa_mente": ((90, 160, 255), lambda d, c: rune(d, c, sym_swirl)),
    "botas_vento": ((190, 240, 230), draw_boot),
    "arma_lendaria": (GOLD, draw_sword),
    "armadura_lendaria": (GOLD, draw_chest),
    "joias_lendarias": (GOLD, draw_jewels),
    "pedra_protecao": ((120, 200, 255), draw_shield),
    "pocao_sabedoria": ((190, 120, 255), draw_potion),
    "pergaminho_xp": ((255, 220, 90), draw_scroll),
    "saco_ouro": (GOLD, draw_bag),
    "pet_coruja": ((190, 150, 255), draw_owl),
    "pet_aguaviva": ((120, 210, 255), draw_jelly),
    "pet_peixe": ((255, 190, 70), draw_fish),
    "pet_lobinho": ((200, 200, 210), draw_wolf),
    "pet_dragaozinho": ((255, 130, 50), draw_dragon),
    "pet_slime": ((100, 255, 150), draw_slime),
    "mount_lobo": ((190, 190, 205), lambda d, c: (draw_wolf(d, c), saddle(d))),
    "mount_escorpiao": ((255, 90, 80), lambda d, c: (draw_scorpion(d, c), saddle(d))),
    "mount_golem": ((255, 140, 50), lambda d, c: (draw_golem(d, c), saddle(d))),
    "mount_dragao": ((255, 110, 30), lambda d, c: (draw_dragon(d, c), saddle(d))),
    "mat_ferro": ((170, 175, 185), draw_ingot),
    "mat_cristal": ((130, 220, 255), draw_crystal),
    "mat_essencia": ((210, 110, 255), draw_essence),
}

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for k, (col, fn) in ICONS.items():
        im, d = base(col)
        fn(d, col)
        im.save(os.path.join(OUT, k + ".png"))
    print("ok", len(ICONS), "ícones")
