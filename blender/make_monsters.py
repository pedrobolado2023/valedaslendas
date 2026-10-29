"""
Monstros no estilo novo (corpo orgânico com esqueleto), substituindo os modelos de peças rígidas.
Rode:  blender -b -P blender/make_monsters.py [nome1,nome2,...]     (sem nomes = todos)
Saída: models/<nome>.glb com animações idle, walk, attack (mesmos nomes de antes; o jogo não muda).
Sinais de rotação (eixo do mundo): osso apontando para baixo gira para FRENTE com +X; tronco/cabeça
inclina para BAIXO com +X; balanço lateral = Z.
"""
import math
import os
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import creature_kit as C  # noqa: E402

X, Y, Z = C.X, C.Y, C.Z
sin, cos, tau, pi = math.sin, math.cos, math.tau, math.pi
pulse = C.pulse


def V(x, y, z):
    return Vector((x, y, z))


# =================================================================== quadrúpede (lobos)

def quad_legs(bones, xf, yf, xb, yb, hip_z, leg_r, paw_r):
    for s, sn in ((-1, "l"), (1, "r")):
        x = s * xf
        bones += [(f"fup_{sn}", V(x, yf, hip_z), V(x * 1.05, yf + 0.05, hip_z * 0.5), "chest", leg_r * 1.3, leg_r),
                  (f"flo_{sn}", V(x * 1.05, yf + 0.05, hip_z * 0.5), V(x * 1.05, yf, 0.08), f"fup_{sn}", leg_r * 0.85, leg_r * 0.75),
                  (f"fpaw_{sn}", V(x * 1.05, yf, 0.08), V(x * 1.05, yf + 0.18, 0.04), f"flo_{sn}", paw_r, paw_r)]
        x = s * xb
        bones += [(f"bup_{sn}", V(x, yb, hip_z * 1.02), V(x * 1.06, yb - 0.15, hip_z * 0.52), "hips", leg_r * 1.6, leg_r * 1.05),
                  (f"blo_{sn}", V(x * 1.06, yb - 0.15, hip_z * 0.52), V(x * 1.06, yb, 0.08), f"bup_{sn}", leg_r * 0.8, leg_r * 0.7),
                  (f"bpaw_{sn}", V(x * 1.06, yb, 0.08), V(x * 1.06, yb + 0.17, 0.04), f"blo_{sn}", paw_r, paw_r)]


def quad_walk(t, swing=0.45, bob=0.05):
    p = t * tau
    o = {}
    for leg, ph in (("f", 0.0), ("b", pi)):
        for s, extra in (("l", 0.0), ("r", pi)):
            q = p + ph + extra
            o[f"{leg}up_{s}"] = [(X, swing * sin(q))]
            o[f"{leg}lo_{s}"] = [(X, (-0.5 if leg == "f" else 0.5) * max(0.0, cos(q)) * swing)]
    o["chest"] = [(Z, 0.04 * sin(p))]
    o["head"] = [(X, 0.05 * sin(2 * p))]
    o["tail1"] = [(Z, 0.3 * sin(2 * p))]
    o["tail2"] = [(Z, 0.3 * sin(2 * p - 0.8))]
    o["_loc"] = V(0, 0, bob * abs(sin(p)))
    return o


def build_wolf(name, fur, fur2, eye, size=1.0, mane=1.0, spikes=None):
    C.new_scene()
    s = size
    furm = C.mat(name + "_pelo", fur, rough=0.9)
    eyes = C.mat(name + "_olho", eye, glow=4.0)
    dark = C.mat(name + "_focinho", (0.08, 0.06, 0.06))
    white = C.mat(name + "_dente", (0.95, 0.93, 0.88))
    hip = 0.95 * s
    bones = [("root", V(0, 0, hip), V(0, 0.3 * s, hip), None, 0, 0),
             ("hips", V(0, -0.75 * s, hip + 0.05 * s), V(0, -0.05 * s, hip + 0.1 * s), "root", 0.4 * s, 0.44 * s),
             ("chest", V(0, -0.05 * s, hip + 0.1 * s), V(0, 0.6 * s, hip + 0.12 * s), "hips", 0.46 * s, 0.5 * s),
             ("neck", V(0, 0.6 * s, hip + 0.18 * s), V(0, 0.95 * s, hip + 0.45 * s), "chest", 0.34 * s, 0.27 * s),
             ("head", V(0, 0.95 * s, hip + 0.45 * s), V(0, 1.3 * s, hip + 0.42 * s), "neck", 0.37 * s, 0.3 * s),
             ("snout", V(0, 1.3 * s, hip + 0.38 * s), V(0, 1.62 * s, hip + 0.28 * s), "head", 0.21 * s, 0.13 * s),
             ("tail1", V(0, -0.75 * s, hip + 0.12 * s), V(0, -1.25 * s, hip + 0.2 * s), "hips", 0.15 * s, 0.13 * s),
             ("tail2", V(0, -1.25 * s, hip + 0.2 * s), V(0, -1.75 * s, hip + 0.02 * s), "tail1", 0.13 * s, 0.05 * s)]
    quad_legs(bones, 0.27 * s, 0.5 * s, 0.3 * s, -0.6 * s, hip, 0.17 * s, 0.15 * s)
    c = C.Creature(name, bones, furm, resolution=0.07 * s)
    c.build_armature()
    c.build_body(extra_balls=[((0, 0.4 * s, hip + 0.28 * s), 0.5 * s * mane), ((0, 0.7 * s, hip + 0.36 * s), 0.36 * s * mane)])
    c.shade(belly=1.35, back=0.75)
    c.bind()
    hz = hip + 0.45 * s
    for sd in (-1, 1):
        c.part("sphere", "Olho", eyes, V(sd * 0.16 * s, 1.2 * s, hz + 0.1 * s), (0.1 * s, 0.07 * s, 0.07 * s), bone="head")
        c.part("cone", "Orelha", furm, V(sd * 0.19 * s, 0.98 * s, hz + 0.32 * s), (0.2 * s, 0.12 * s, 0.34 * s), rot=(-0.25, sd * 0.25, 0), bone="head", seg=5)
        c.part("cone", "Presa", white, V(sd * 0.08 * s, 1.52 * s, hip + 0.2 * s), (0.05 * s, 0.05 * s, 0.13 * s), rot=(pi, 0, 0), bone="snout", seg=6)
    c.part("sphere", "Nariz", dark, V(0, 1.64 * s, hip + 0.31 * s), (0.12 * s, 0.1 * s, 0.09 * s), bone="snout")
    if spikes is not None:   # cristais de gelo nas costas (lobos de gelo): spikes = (cor, brilho)
        spikes = C.mat(name + "_cristal", spikes[0], glow=spikes[1])
        for k in range(6):
            yy = (-0.6 + k * 0.26) * s
            c.part("cone", "Cristal", spikes, V(0, yy, hip + 0.5 * s - abs(yy) * 0.1), (0.12 * s, 0.12 * s, (0.4 - abs(k - 2.5) * 0.04) * s),
                   rot=(-0.3, 0, 0), bone="chest" if yy > 0 else "hips", seg=5)

    def idle(t):
        b = sin(t * tau)
        return {"chest": [(X, 0.02 * b)], "neck": [(X, -0.03 * b)], "head": [(X, 0.04 * sin(t * tau + 1))],
                "tail1": [(Z, 0.25 * sin(t * tau))], "tail2": [(Z, 0.25 * sin(t * tau - 0.8))], "_loc": V(0, 0, 0.015 * s * b)}

    def walk(t):
        return quad_walk(t, 0.5, 0.06 * s)

    def attack(t):
        crouch = pulse(t, 0.0, 0.3, 0.32, 0.4)
        lunge = pulse(t, 0.35, 0.5, 0.65, 1.0)
        return {"hips": [(X, 0.15 * crouch - 0.1 * lunge)], "chest": [(X, 0.2 * crouch)], "neck": [(X, 0.3 * crouch - 0.4 * lunge)],
                "head": [(X, 0.2 * crouch - 0.3 * lunge)], "snout": [(X, -0.25 * lunge)],
                "fup_l": [(X, 0.9 * lunge)], "fup_r": [(X, 0.9 * lunge)], "bup_l": [(X, -0.4 * lunge)], "bup_r": [(X, -0.4 * lunge)],
                "_loc": V(0, (-0.3 * crouch + 0.9 * lunge) * s, (-0.15 * crouch + 0.2 * lunge) * s)}

    c.actions({"idle": (36, idle), "walk": (16, walk), "attack": (14, attack)})
    c.export()


# =================================================================== dragão

def build_dragon(name, body_c, belly_c, wing_c, horn_c, eye_c, size=1.0, whelp=False):
    C.new_scene()
    s = size
    skin = C.mat(name + "_escamas", body_c, rough=0.6)
    wing = C.mat(name + "_asa", wing_c, rough=0.8)
    horn = C.mat(name + "_chifre", horn_c, rough=0.5)
    eyes = C.mat(name + "_olho", eye_c, glow=5.0)
    hip = 1.05 * s
    hs = 1.35 if whelp else 1.0   # filhote: cabeça maior
    bones = [("root", V(0, 0, hip), V(0, 0.3 * s, hip), None, 0, 0),
             ("hips", V(0, -0.9 * s, hip), V(0, -0.1 * s, hip + 0.1 * s), "root", 0.66 * s, 0.76 * s),
             ("chest", V(0, -0.1 * s, hip + 0.1 * s), V(0, 0.75 * s, hip + 0.3 * s), "hips", 0.78 * s, 0.68 * s),
             ("neck1", V(0, 0.75 * s, hip + 0.3 * s), V(0, 1.15 * s, hip + 0.85 * s), "chest", 0.5 * s, 0.38 * s),
             ("neck2", V(0, 1.15 * s, hip + 0.85 * s), V(0, 1.45 * s, hip + 1.35 * s), "neck1", 0.38 * s, 0.32 * s),
             ("head", V(0, 1.45 * s, hip + 1.35 * s), V(0, 1.95 * s, hip + 1.3 * s), "neck2", 0.4 * s * hs, 0.3 * s * hs),
             ("jaw", V(0, 1.6 * s, hip + 1.2 * s), V(0, 2.15 * s, hip + 1.12 * s), "head", 0.2 * s * hs, 0.14 * s * hs),
             ("tail1", V(0, -0.9 * s, hip + 0.05 * s), V(0, -1.6 * s, hip - 0.1 * s), "hips", 0.5 * s, 0.36 * s),
             ("tail2", V(0, -1.6 * s, hip - 0.1 * s), V(0, -2.3 * s, hip - 0.35 * s), "tail1", 0.36 * s, 0.22 * s),
             ("tail3", V(0, -2.3 * s, hip - 0.35 * s), V(0, -3.0 * s, hip - 0.5 * s), "tail2", 0.22 * s, 0.08 * s)]
    quad_legs(bones, 0.5 * s, 0.6 * s, 0.55 * s, -0.75 * s, hip, 0.24 * s, 0.2 * s)
    wing_span = (1.2 if whelp else 2.1) * s
    for sd, sn in ((-1, "l"), (1, "r")):
        sh = V(sd * 0.35 * s, 0.45 * s, hip + 0.55 * s)
        el = sh + V(sd * wing_span * 0.5, -0.2 * s, 0.4 * s)
        tip = el + V(sd * wing_span * 0.5, -0.5 * s, -0.05 * s)
        bones += [(f"wing1_{sn}", sh, el, "chest", 0.09 * s, 0.07 * s), (f"wing2_{sn}", el, tip, f"wing1_{sn}", 0.06 * s, 0.03 * s)]
    c = C.Creature(name, bones, skin, resolution=0.08 * s)
    c.build_armature()
    c.build_body(extra_balls=[((0, 0.1 * s, hip - 0.05 * s), 0.95 * s), ((0, -0.6 * s, hip), 0.85 * s)])
    c.shade(belly=1.4, back=0.7)
    c.bind()
    hz = hip + 1.35 * s
    for sd, sn in ((-1, "l"), (1, "r")):
        c.part("sphere", "Olho", eyes, V(sd * 0.2 * s * hs, 1.8 * s, hz + 0.08 * s * hs), (0.12 * s * hs, 0.08 * s, 0.07 * s * hs), bone="head")
        c.part("cone", "Chifre", horn, V(sd * 0.18 * s * hs, 1.5 * s, hz + 0.25 * s * hs), (0.1 * s, 0.1 * s, 0.55 * s * hs), rot=(-1.2, sd * 0.35, 0), bone="head", seg=8)
        c.part("cone", "Chifre2", horn, V(sd * 0.3 * s * hs, 1.6 * s, hz + 0.1 * s), (0.06 * s, 0.06 * s, 0.3 * s * hs), rot=(-1.4, sd * 0.8, 0), bone="head", seg=6)
        # pele das asas: do ombro, passando pelo cotovelo e a ponta, voltando pelas costas
        sh = V(sd * 0.35 * s, 0.45 * s, hip + 0.55 * s)
        el = sh + V(sd * wing_span * 0.5, -0.2 * s, 0.4 * s)
        tip = el + V(sd * wing_span * 0.5, -0.5 * s, -0.05 * s)
        c.membrane(f"Asa_{sn}", wing, [sh, el, tip, sh + V(sd * wing_span * 0.72, -1.15 * s, 0.05 * s),
                                       sh + V(sd * wing_span * 0.35, -1.25 * s, -0.1 * s), sh + V(sd * 0.15 * s, -1.1 * s, -0.25 * s)],
                   [f"wing1_{sn}", f"wing2_{sn}", "chest"])
        for k in range(3):   # garras
            for leg in ("fpaw", "bpaw"):
                y0 = (0.78 if leg == "fpaw" else -0.58) * s
                xx = sd * (0.44 if leg == "fpaw" else 0.48) * s + (k - 1) * 0.07 * s
                c.part("cone", "Garra", horn, V(xx, y0, 0.05 * s), (0.05 * s, 0.05 * s, 0.14 * s), rot=(-1.4, 0, 0), bone=f"{leg}_{sn}", seg=5)
    for k in range(8):   # espinhos nas costas e cauda
        yy = (0.6 - k * 0.45) * s
        bone = "chest" if yy > -0.1 * s else ("hips" if yy > -0.9 * s else ("tail1" if yy > -1.6 * s else "tail2"))
        zz = hip + (0.65 if yy > -0.9 * s else 0.4 - (abs(yy) - 0.9 * s) * 0.25) * s
        c.part("cone", "Espinho", horn, V(0, yy, zz), (0.12 * s, 0.2 * s, (0.4 - k * 0.03) * s), rot=(-0.5, 0, 0), bone=bone, seg=5)
    for k in range(4):
        c.part("cone", "Dente", horn, V((k - 1.5) * 0.06 * s * hs, (1.9 + 0.02 * k) * s, hip + 1.14 * s), (0.04 * s, 0.04 * s, 0.1 * s), rot=(pi, 0, 0), bone="jaw", seg=5)

    def flap(t, k=1.0):
        return {f"wing1_{sn}": [(Y, sd * (0.5 * sin(t * tau) - 0.1) * k)] for sd, sn in ((-1, "l"), (1, "r"))} | \
               {f"wing2_{sn}": [(Y, sd * 0.35 * sin(t * tau - 0.7) * k)] for sd, sn in ((-1, "l"), (1, "r"))}

    def idle(t):
        b = sin(t * tau)
        o = {"chest": [(X, 0.02 * b)], "neck1": [(X, -0.04 * b), (Z, 0.05 * sin(t * tau * 0.5 * 2))], "neck2": [(X, -0.03 * b)],
             "head": [(X, 0.05 * sin(t * tau + 1))], "jaw": [(X, -0.06 * max(0.0, sin(t * tau * 2)))],
             "tail1": [(Z, 0.15 * sin(t * tau))], "tail2": [(Z, 0.2 * sin(t * tau - 0.7))], "tail3": [(Z, 0.25 * sin(t * tau - 1.4))],
             "_loc": V(0, 0, 0.02 * s * b)}
        o.update(flap(t, 0.25))
        return o

    def walk(t):
        o = C_quad = quad_walk(t, 0.42, 0.06 * s)
        o["neck1"] = [(Z, 0.06 * sin(t * tau))]
        o["tail3"] = [(Z, 0.3 * sin(2 * t * tau - 1.6))]
        o.update(flap(t * 0.5, 0.2))
        return o

    def attack(t):
        rear = pulse(t, 0.0, 0.35, 0.4, 0.5)
        bite = pulse(t, 0.42, 0.55, 0.7, 1.0)
        o = {"hips": [(X, -0.25 * rear + 0.1 * bite)], "chest": [(X, -0.2 * rear + 0.15 * bite)],
             "neck1": [(X, -0.35 * rear + 0.5 * bite)], "neck2": [(X, -0.2 * rear + 0.3 * bite)],
             "head": [(X, -0.2 * rear + 0.2 * bite)], "jaw": [(X, -0.5 * rear + 0.45 * bite)],
             "fup_l": [(X, 0.7 * rear - 0.2 * bite)], "fup_r": [(X, 0.7 * rear - 0.2 * bite)],
             "_loc": V(0, 0.5 * bite * s, 0.25 * rear * s)}
        o.update(flap(t * 2.0, 0.6 * rear + 0.2))
        return o

    c.actions({"idle": (48, idle), "walk": (20, walk), "attack": (20, attack)})
    c.export()


# =================================================================== lista

BUILD = {
    "wolf": lambda: build_wolf("wolf", (0.42, 0.38, 0.36), (0.6, 0.55, 0.5), (1.0, 0.75, 0.2)),
    "wolf_alpha": lambda: build_wolf("wolf_alpha", (0.2, 0.17, 0.2), (0.42, 0.36, 0.38), (1.0, 0.25, 0.15), mane=1.25),
    "wolf_ice": lambda: build_wolf("wolf_ice", (0.75, 0.84, 0.95), (0.9, 0.95, 1.0), (0.4, 0.85, 1.0), spikes=((0.55, 0.85, 1.0), 1.5)),
    "wolf_glacial": lambda: build_wolf("wolf_glacial", (0.55, 0.68, 0.9), (0.85, 0.92, 1.0), (0.3, 0.7, 1.0), mane=1.3, spikes=((0.45, 0.8, 1.0), 2.0)),
    "dragon_ancient": lambda: build_dragon("dragon_ancient", (0.42, 0.08, 0.07), (0.85, 0.55, 0.3), (0.3, 0.06, 0.06), (0.92, 0.85, 0.7), (1.0, 0.8, 0.2)),
    "dragon_whelp": lambda: build_dragon("dragon_whelp", (0.85, 0.35, 0.1), (1.0, 0.75, 0.4), (0.65, 0.2, 0.08), (0.95, 0.9, 0.75), (1.0, 0.9, 0.3), whelp=True),
}


def main():
    names = sys.argv[-1].split(",") if len(sys.argv) > 1 and not sys.argv[-1].endswith(".py") else list(BUILD.keys())
    for n in names:
        BUILD[n]()


if __name__ == "__main__":
    main()
