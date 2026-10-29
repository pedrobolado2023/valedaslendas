"""
Gera as texturas pintadas (estilo "hand-painted") e os ícones das skills.
Rode:  python tools/make_textures.py     (precisa de numpy, scipy e pillow)
Saída: textures/*.png e textures/icons/*.png
"""
import math
import os
import random
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy.ndimage import gaussian_filter

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
OUT = os.path.join(ROOT, "textures")
ICONS = os.path.join(OUT, "icons")
os.makedirs(ICONS, exist_ok=True)


def wrap_noise(size, sigma, seed):
    rng = np.random.default_rng(seed)
    n = gaussian_filter(rng.random((size, size)), sigma, mode="wrap")
    n -= n.min()
    return n / max(n.max(), 1e-6)


def fbm(size, seed, sigmas=(64, 24, 8, 3), weights=(0.5, 0.3, 0.15, 0.05)):
    out = np.zeros((size, size))
    for i, (s, w) in enumerate(zip(sigmas, weights)):
        out += wrap_noise(size, s, seed + i) * w
    out -= out.min()
    return out / out.max()


def palette(t, stops):
    """t em [0,1] -> cor interpolada entre stops [(pos,(r,g,b)), ...]"""
    t = np.clip(t, 0, 1)
    out = np.zeros(t.shape + (3,))
    for (p0, c0), (p1, c1) in zip(stops[:-1], stops[1:]):
        m = (t >= p0) & (t <= p1)
        k = ((t - p0) / max(p1 - p0, 1e-6))[m][:, None]
        out[m] = np.array(c0) * (1 - k) + np.array(c1) * k
    return out


def to_img(arr):
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))


def strokes(img, n, seed, color_fn, length=(6, 18), width=(2, 5), angle=None, alpha=(60, 160)):
    """Pinceladas curtas com repetição nas bordas (textura continua sem emenda)."""
    rng = random.Random(seed)
    size = img.size[0]
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for _ in range(n):
        x, y = rng.uniform(0, size), rng.uniform(0, size)
        a = rng.uniform(0, math.tau) if angle is None else angle + rng.uniform(-0.5, 0.5)
        L = rng.uniform(*length)
        w = int(rng.uniform(*width))
        col = color_fn(rng) + (int(rng.uniform(*alpha)),)
        dx, dy = math.cos(a) * L, math.sin(a) * L
        for ox in (-size, 0, size):
            for oy in (-size, 0, size):
                d.line([(x + ox, y + oy), (x + ox + dx, y + oy + dy)], fill=col, width=w)
                d.ellipse([x + ox + dx - w / 2, y + oy + dy - w / 2, x + ox + dx + w / 2, y + oy + dy + w / 2], fill=col)
    return Image.alpha_composite(img.convert("RGBA"), layer)


def blobs(img, n, seed, color_fn, radius=(2, 6), alpha=(140, 230), shade=True):
    rng = random.Random(seed)
    size = img.size[0]
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for _ in range(n):
        x, y = rng.uniform(0, size), rng.uniform(0, size)
        r = rng.uniform(*radius)
        col = color_fn(rng)
        a = int(rng.uniform(*alpha))
        for ox in (-size, 0, size):
            for oy in (-size, 0, size):
                cx, cy = x + ox, y + oy
                if shade:
                    d.ellipse([cx - r + 1, cy - r + 2, cx + r + 1, cy + r * 0.9 + 2], fill=(20, 14, 8, a // 2))
                d.ellipse([cx - r, cy - r * 0.85, cx + r, cy + r * 0.85], fill=col + (a,))
                if shade:
                    hl = tuple(min(255, int(c * 1.35 + 25)) for c in col)
                    d.ellipse([cx - r * 0.55, cy - r * 0.6, cx + r * 0.1, cy - r * 0.05], fill=hl + (a // 2,))
    return Image.alpha_composite(img.convert("RGBA"), layer)


# ------------------------------------------------------------------ grama
def make_grass():
    S = 1024
    n = fbm(S, 10)
    base = palette(n, [(0.0, (46, 92, 38)), (0.45, (70, 128, 48)), (0.75, (98, 150, 58)), (1.0, (132, 168, 70))])
    img = to_img(base)

    def blade(rng):
        k = rng.random()
        if k < 0.45:
            return (rng.randint(34, 56), rng.randint(78, 104), rng.randint(28, 42))
        if k < 0.9:
            return (rng.randint(96, 140), rng.randint(150, 186), rng.randint(56, 80))
        return (rng.randint(150, 180), rng.randint(176, 200), rng.randint(80, 100))

    img = strokes(img, 9000, 1, blade, length=(5, 14), width=(2, 4), angle=-math.pi / 2, alpha=(70, 170))
    img = strokes(img, 1500, 2, lambda r: (r.randint(26, 40), r.randint(60, 78), r.randint(24, 34)), length=(10, 26), width=(4, 8), alpha=(30, 70))
    img = blobs(img, 260, 3, lambda r: r.choice([(240, 226, 120), (250, 250, 240), (230, 140, 170), (200, 170, 240)]), radius=(1.2, 2.4), alpha=(170, 240), shade=False)
    img = img.filter(ImageFilter.GaussianBlur(0.6)).convert("RGB")
    img.save(os.path.join(OUT, "grass.png"))


# ------------------------------------------------------------------ terra da trilha
def make_dirt():
    S = 1024
    n = fbm(S, 20)
    base = palette(n, [(0.0, (104, 76, 48)), (0.5, (146, 110, 70)), (1.0, (178, 142, 96))])
    img = to_img(base)
    img = strokes(img, 5000, 4, lambda r: (r.randint(110, 170), r.randint(84, 124), r.randint(50, 80)), length=(8, 22), width=(3, 7), angle=0.0, alpha=(30, 90))
    img = strokes(img, 1200, 5, lambda r: (r.randint(70, 92), r.randint(50, 64), r.randint(32, 42)), length=(14, 34), width=(2, 4), angle=0.0, alpha=(40, 90))
    img = blobs(img, 900, 6, lambda r: (r.randint(120, 170), r.randint(110, 150), r.randint(96, 130)), radius=(2, 6))
    img = blobs(img, 140, 7, lambda r: (r.randint(130, 160), r.randint(128, 150), r.randint(120, 140)), radius=(6, 11))
    img = img.filter(ImageFilter.GaussianBlur(0.5)).convert("RGB")
    img.save(os.path.join(OUT, "dirt.png"))


# ------------------------------------------------------------------ pedra (ruínas)
def make_stone():
    S = 512
    n = fbm(S, 30)
    base = palette(n, [(0.0, (70, 74, 80)), (0.5, (104, 108, 112)), (1.0, (140, 140, 136))])
    img = Image.fromarray(base.astype(np.uint8))
    d = ImageDraw.Draw(img)
    rng = random.Random(8)
    rows = 8
    h = S // rows
    for r in range(rows):
        off = (r % 2) * (S // 8)
        x = -off
        while x < S:
            w = rng.randint(S // 6, S // 3)
            for ox in (-S, 0, S):
                d.rectangle([x + ox, r * h, x + ox + w, r * h + h], outline=(36, 36, 40), width=4)
                d.line([(x + ox + 3, r * h + 4), (x + ox + w - 4, r * h + 4)], fill=(170, 170, 162), width=2)
            x += w
    img = strokes(img.convert("RGBA"), 2500, 9, lambda r: (r.randint(80, 150),) * 3, length=(4, 12), width=(2, 4), alpha=(25, 60))
    img = blobs(img, 120, 10, lambda r: (70, 100, 60), radius=(3, 9), alpha=(80, 140), shade=False)
    img.filter(ImageFilter.GaussianBlur(0.6)).convert("RGB").save(os.path.join(OUT, "stone.png"))


# ------------------------------------------------------------------ detalhe de pincel (para os modelos)
def make_detail():
    S = 512
    n = fbm(S, 40, sigmas=(30, 10, 3), weights=(0.45, 0.35, 0.2))
    img = to_img((0.35 + n * 0.3) * 255)
    img = img.convert("RGBA")
    img = strokes(img, 2600, 11, lambda r: (r.randint(150, 230),) * 3, length=(6, 20), width=(3, 7), alpha=(40, 110))
    img = strokes(img, 2600, 12, lambda r: (r.randint(40, 110),) * 3, length=(6, 20), width=(3, 7), alpha=(40, 110))
    img = img.filter(ImageFilter.GaussianBlur(1.0)).convert("L")
    arr = np.asarray(img).astype(float)
    arr = (arr - arr.mean()) / (arr.std() + 1e-6) * 40 + 128
    to_img(arr).save(os.path.join(OUT, "detail.png"))


def make_noise():
    n = fbm(256, 50, sigmas=(24, 8, 3), weights=(0.6, 0.3, 0.1))
    to_img(n * 255).convert("L").save(os.path.join(OUT, "noise.png"))


# ------------------------------------------------------------------ tufo de grama e flor (com transparência)
def make_grass_blade():
    S = 256
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    rng = random.Random(13)
    for i in range(46):
        x0 = rng.uniform(30, S - 30)
        h = rng.uniform(S * 0.45, S * 0.95)
        lean = rng.uniform(-40, 40)
        w = rng.uniform(7, 14)
        g = rng.randint(150, 230)
        col_base = (int(g * 0.45), int(g * 0.8), int(g * 0.3), 255)
        col_tip = (int(g * 0.85), int(min(255, g * 1.05)), int(g * 0.45), 255)
        steps = 12
        for k in range(steps):
            t0, t1 = k / steps, (k + 1) / steps
            ww = w * (1 - t0) + 1
            xa = x0 + lean * t0 * t0
            xb = x0 + lean * t1 * t1
            ya = S - h * t0
            yb = S - h * t1
            c = tuple(int(col_base[j] * (1 - t0) + col_tip[j] * t0) for j in range(3)) + (255,)
            d.polygon([(xa - ww / 2, ya), (xa + ww / 2, ya), (xb + ww * 0.45, yb), (xb - ww * 0.45, yb)], fill=c)
    img.save(os.path.join(OUT, "grass_blade.png"))


def make_flower():
    S = 128
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.line([(64, 127), (66, 60)], fill=(70, 120, 50, 255), width=5)
    d.ellipse([40, 84, 64, 96], fill=(80, 140, 60, 255))
    for k in range(6):
        a = k * math.tau / 6
        cx, cy = 66 + math.cos(a) * 15, 46 + math.sin(a) * 15
        d.ellipse([cx - 12, cy - 12, cx + 12, cy + 12], fill=(250, 250, 250, 255))
    d.ellipse([56, 36, 76, 56], fill=(250, 200, 70, 255))
    img.save(os.path.join(OUT, "flower.png"))


# ------------------------------------------------------------------ ícones das skills
ICON_SPECS = {
    # classe: [(id, cor1, cor2, desenho)] — um desenho para cada skill da lista do projeto
    "druida": [("dr1", (150, 230, 90), (30, 70, 20), "spikes"), ("dr2", (150, 255, 160), (20, 90, 40), "nova"),
               ("dr3", (200, 160, 255), (60, 30, 110), "falcon"), ("dr4", (200, 150, 90), (80, 50, 20), "shield"),
               ("dr5", (200, 255, 220), (40, 90, 70), "dash"), ("dr6", (255, 220, 100), (120, 70, 10), "meteor"),
               ("dr7", (170, 230, 255), (20, 60, 110), "hail"), ("dr8", (190, 200, 255), (30, 30, 100), "chain"),
               ("dr9", (255, 150, 60), (110, 30, 10), "meteors"), ("dr10", (255, 120, 40), (60, 15, 5), "fissure")],
    "assassino": [("as1", (180, 120, 255), (40, 15, 80), "dash"), ("as2", (140, 255, 110), (20, 70, 20), "flame"),
                  ("as3", (150, 140, 190), (25, 20, 45), "nova"), ("as4", (210, 160, 255), (60, 20, 100), "spin"),
                  ("as5", (120, 110, 140), (20, 15, 30), "shield"), ("as6", (255, 220, 110), (110, 70, 10), "sword")],
    "mecanico": [("me1", (140, 220, 255), (30, 60, 90), "triple"), ("me2", (255, 190, 90), (100, 50, 10), "trap"),
                 ("me3", (130, 210, 255), (20, 60, 110), "shield"), ("me4", (255, 150, 60), (100, 30, 10), "flame"),
                 ("me5", (140, 255, 190), (20, 80, 50), "falcon"), ("me6", (255, 210, 90), (110, 70, 10), "quake")],
    "nautico": [("na1", (140, 230, 255), (20, 60, 100), "thrust"), ("na2", (100, 190, 255), (15, 50, 110), "pierce"),
                ("na3", (150, 220, 255), (20, 70, 120), "shield"), ("na4", (90, 130, 230), (10, 20, 70), "nova"),
                ("na5", (230, 150, 255), (70, 30, 110), "ice"), ("na6", (120, 220, 255), (10, 60, 110), "spin")],
}


def icon(path, c1, c2, kind):
    S = 128
    y, x = np.mgrid[0:S, 0:S]
    r = np.hypot(x - S * 0.45, y - S * 0.4) / (S * 0.85)
    t = np.clip(r, 0, 1)[..., None]
    arr = np.array(c1) * (1 - t) * 0.65 + np.array(c2) * (t + 0.35) * 0.75
    img = to_img(arr).convert("RGBA")
    d = ImageDraw.Draw(img)
    W = (255, 255, 255, 235)
    L = tuple(min(255, int(c * 1.1 + 40)) for c in c1) + (255,)
    D = (20, 12, 8, 200)
    m = S / 2

    def poly(pts, fill, outline=D, width=4):
        d.polygon(pts, fill=fill)
        d.line(pts + [pts[0]], fill=outline, width=width)

    if kind == "spin":
        for k in range(3):
            a0 = k * 120
            d.arc([18, 18, 110, 110], a0, a0 + 80, fill=L, width=12)
        d.ellipse([52, 52, 76, 76], fill=W)
    elif kind in ("dash",):
        for k, yy in enumerate((40, 64, 88)):
            d.line([(20 + k * 6, yy), (90 - k * 6, yy)], fill=L, width=8)
        poly([(84, 34), (112, 64), (84, 94)], W)
    elif kind == "quake":
        d.line([(10, 92), (118, 92)], fill=D, width=8)
        d.line([(64, 92), (52, 70), (70, 56), (58, 30)], fill=W, width=7)
        for k in range(5):
            d.ellipse([12 + k * 24, 96, 24 + k * 24, 108], fill=L)
    elif kind == "shout":
        d.ellipse([30, 30, 70, 98], fill=L, outline=D, width=4)
        for rr in (20, 34, 48):
            d.arc([60 - rr, 64 - rr, 60 + rr, 64 + rr], -50, 50, fill=W, width=6)
    elif kind == "flame":
        poly([(64, 12), (96, 60), (88, 104), (40, 104), (32, 60), (50, 70)], L)
        poly([(64, 48), (80, 82), (64, 100), (48, 82)], W)
    elif kind == "sword":
        poly([(58, 10), (70, 10), (70, 82), (64, 96), (58, 82)], W)
        d.rectangle([40, 82, 88, 92], fill=L, outline=D, width=3)
        d.rectangle([59, 92, 69, 118], fill=(90, 60, 30, 255))
        for k in range(4):
            a = k * math.pi / 2 + 0.6
            d.line([(64, 40), (64 + math.cos(a) * 46, 40 + math.sin(a) * 46)], fill=L[:3] + (120,), width=4)
    elif kind == "thrust":
        for k, yy in enumerate((40, 64, 88)):
            d.line([(14, yy), (92, yy)], fill=(120, 80, 40, 255), width=6)
            poly([(92, yy - 9), (116, yy), (92, yy + 9)], W, width=3)
    elif kind == "leap":
        d.arc([16, 26, 112, 122], 190, 350, fill=L, width=10)
        poly([(96, 52), (114, 82), (84, 74)], W)
        d.ellipse([20, 104, 108, 120], outline=W, width=4)
    elif kind == "spear":
        d.line([(16, 112), (96, 32)], fill=(120, 80, 40, 255), width=9)
        poly([(90, 26), (116, 12), (102, 38)], W)
    elif kind == "spikes":
        for k in range(4):
            x0 = 14 + k * 26
            poly([(x0, 110), (x0 + 12, 30 + (k % 2) * 20), (x0 + 24, 110)], W)
    elif kind == "bolt":
        poly([(70, 8), (34, 70), (60, 70), (46, 120), (96, 50), (68, 50), (86, 8)], (255, 245, 150, 255))
    elif kind == "triple":
        for a in (-0.4, 0, 0.4):
            x2, y2 = 64 + math.sin(a) * 52, 64 - math.cos(a) * 52
            d.line([(64, 112), (x2, y2)], fill=W, width=6)
            d.ellipse([x2 - 7, y2 - 7, x2 + 7, y2 + 7], fill=L)
    elif kind == "pierce":
        d.line([(10, 64), (110, 64)], fill=W, width=8)
        poly([(96, 46), (124, 64), (96, 82)], L)
        for k in range(3):
            d.ellipse([28 + k * 22, 50, 44 + k * 22, 78], outline=L, width=4)
    elif kind == "rain":
        for k in range(7):
            x0 = 14 + k * 16
            y0 = 14 + (k % 3) * 18
            d.line([(x0, y0), (x0 - 10, y0 + 46)], fill=W, width=5)
        d.ellipse([20, 100, 108, 120], outline=L, width=5)
    elif kind == "trap":
        d.ellipse([22, 50, 106, 106], fill=(70, 50, 30, 255), outline=D, width=4)
        for k in range(8):
            a = k * math.tau / 8
            d.line([(64, 78), (64 + math.cos(a) * 44, 78 + math.sin(a) * 30)], fill=L, width=5)
        d.ellipse([52, 66, 76, 90], fill=W)
    elif kind == "falcon":
        poly([(64, 30), (118, 50), (78, 62), (64, 96), (50, 62), (10, 50)], W)
        d.ellipse([58, 30, 70, 42], fill=L)
    elif kind == "fireball":
        d.ellipse([40, 40, 104, 104], fill=L)
        poly([(44, 60), (8, 30), (52, 46), (30, 10), (64, 40)], (255, 200, 90, 220))
        d.ellipse([58, 56, 90, 88], fill=W)
    elif kind == "ice":
        poly([(64, 6), (84, 64), (64, 122), (44, 64)], W)
        d.line([(64, 14), (64, 114)], fill=L, width=4)
        d.line([(30, 40), (98, 88)], fill=L, width=4)
        d.line([(98, 40), (30, 88)], fill=L, width=4)
    elif kind == "shield":
        poly([(64, 12), (106, 28), (100, 76), (64, 116), (28, 76), (22, 28)], L)
        poly([(64, 34), (86, 44), (82, 72), (64, 92), (46, 72), (42, 44)], W)
    elif kind == "nova":
        for k in range(10):
            a = k * math.tau / 10
            d.line([(64, 64), (64 + math.cos(a) * 54, 64 + math.sin(a) * 54)], fill=L, width=6)
        d.ellipse([40, 40, 88, 88], fill=W)
    elif kind == "meteor":
        d.line([(20, 20), (70, 70)], fill=(255, 200, 90, 200), width=26)
        d.ellipse([56, 56, 112, 112], fill=L, outline=D, width=4)
        d.ellipse([70, 66, 92, 88], fill=W)
    elif kind == "hail":
        for x0, y0, s in ((30, 14, 1.0), (70, 30, 1.25), (98, 10, 0.85)):
            poly([(x0, y0), (x0 + 9 * s, y0 + 26 * s), (x0, y0 + 64 * s), (x0 - 9 * s, y0 + 26 * s)], W, width=3)
            d.line([(x0, y0 + 4), (x0, y0 + 60 * s)], fill=L, width=3)
        d.ellipse([14, 104, 114, 120], outline=L, width=5)
    elif kind == "chain":
        pts = [(18, 20), (40, 52), (30, 58), (66, 74), (58, 80), (100, 100)]
        d.line(pts, fill=L, width=14, joint="curve")
        d.line(pts, fill=W, width=5, joint="curve")
        for cx, cy in ((22, 24), (64, 74), (100, 100)):
            d.ellipse([cx - 9, cy - 9, cx + 9, cy + 9], fill=(255, 255, 255, 255), outline=D, width=3)
    elif kind == "meteors":
        for x0, y0, rr in ((80, 76, 20), (38, 50, 13), (98, 30, 9)):
            d.line([(x0 - rr * 2.4, y0 - rr * 2.4), (x0, y0)], fill=(255, 200, 90, 190), width=int(rr * 1.4))
            d.ellipse([x0 - rr, y0 - rr, x0 + rr, y0 + rr], fill=L, outline=D, width=3)
            d.ellipse([x0 - rr * 0.4, y0 - rr * 0.5, x0 + rr * 0.3, y0 + rr * 0.2], fill=W)
    elif kind == "fissure":
        d.ellipse([12, 78, 116, 116], fill=(40, 20, 12, 255), outline=D, width=4)
        for pts in (((64, 96), (44, 88), (24, 94)), ((64, 96), (86, 86), (108, 92)), ((64, 96), (60, 110))):
            d.line(pts, fill=(255, 150, 50, 255), width=5)
        poly([(64, 14), (86, 56), (80, 92), (48, 92), (42, 56), (56, 62)], L)
        poly([(64, 50), (76, 76), (64, 90), (52, 76)], W)
    # moldura
    d.rounded_rectangle([2, 2, S - 3, S - 3], 18, outline=(20, 12, 8, 255), width=6)
    d.rounded_rectangle([7, 7, S - 8, S - 8], 14, outline=(225, 180, 90, 255), width=3)
    img.save(path)


# ------------------------------------------------------------------ areia, neve e cinzas (novos mapas)
def make_sand():
    S = 1024
    n = fbm(S, 60)
    base = palette(n, [(0.0, (176, 120, 72)), (0.5, (214, 160, 98)), (1.0, (236, 192, 128))])
    img = to_img(base)
    # ondulações das dunas
    img = strokes(img, 3500, 61, lambda r: (r.randint(150, 185), r.randint(100, 130), r.randint(60, 80)), length=(20, 50), width=(2, 4), angle=0.25, alpha=(30, 80))
    img = strokes(img, 3500, 62, lambda r: (r.randint(235, 250), r.randint(200, 220), r.randint(140, 165)), length=(18, 44), width=(2, 3), angle=0.25, alpha=(30, 80))
    img = blobs(img, 220, 63, lambda r: (r.randint(150, 190), r.randint(120, 150), r.randint(90, 110)), radius=(1.5, 3.5))
    img.filter(ImageFilter.GaussianBlur(0.7)).convert("RGB").save(os.path.join(OUT, "sand.png"))


def make_snow():
    S = 1024
    n = fbm(S, 70)
    base = palette(n, [(0.0, (176, 196, 222)), (0.5, (214, 228, 242)), (1.0, (246, 250, 255))])
    img = to_img(base)
    img = strokes(img, 3000, 71, lambda r: (r.randint(160, 190), r.randint(180, 205), r.randint(215, 235)), length=(14, 40), width=(4, 9), alpha=(30, 70))
    img = strokes(img, 2500, 72, lambda r: (255, 255, 255), length=(10, 30), width=(3, 7), alpha=(40, 90))
    img = blobs(img, 400, 73, lambda r: (255, 255, 255), radius=(0.8, 1.6), alpha=(180, 255), shade=False)
    img.filter(ImageFilter.GaussianBlur(0.8)).convert("RGB").save(os.path.join(OUT, "snow.png"))


def make_ash():
    S = 1024
    n = fbm(S, 80)
    base = palette(n, [(0.0, (34, 28, 30)), (0.5, (58, 48, 48)), (1.0, (86, 72, 66))])
    img = to_img(base)
    img = strokes(img, 4000, 81, lambda r: (r.randint(20, 40), r.randint(16, 30), r.randint(16, 28)), length=(8, 26), width=(2, 6), alpha=(50, 120))
    img = strokes(img, 1800, 82, lambda r: (r.randint(90, 120), r.randint(70, 90), r.randint(60, 80)), length=(6, 18), width=(2, 4), alpha=(30, 70))
    img = blobs(img, 500, 83, lambda r: (r.randint(50, 80), r.randint(40, 60), r.randint(40, 55)), radius=(2, 6))
    img.filter(ImageFilter.GaussianBlur(0.6)).convert("RGB").save(os.path.join(OUT, "ash.png"))


def main():
    if "--icons" in sys.argv:   # só os ícones das skills (não refaz as texturas do chão)
        for cls, specs in ICON_SPECS.items():
            for sid, c1, c2, kind in specs:
                icon(os.path.join(ICONS, sid + ".png"), c1, c2, kind)
        print("icones ok")
        return
    make_grass()
    make_dirt()
    make_stone()
    make_detail()
    make_noise()
    make_grass_blade()
    make_flower()
    make_sand()
    make_snow()
    make_ash()
    for cls, specs in ICON_SPECS.items():
        for sid, c1, c2, kind in specs:
            icon(os.path.join(ICONS, sid + ".png"), c1, c2, kind)
    print("texturas ok")


if __name__ == "__main__":
    main()
