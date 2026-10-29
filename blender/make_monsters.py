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


# =================================================================== bípedes (golems, yetis, esqueletos, diabretes)
# Sinais (ossos em pé, eixo do mundo): braço/perna para FRENTE = +X; joelho dobra (canela para trás) = -X;
# cotovelo dobra (antebraço para frente) = +X; tronco inclina para frente = -X; braço abre para o lado = ±Y.

def biped_bones(H, leg=0.45, torso=0.32, sw=0.16, hw=0.08, arm=0.4, rt=0.16, ra=0.06, rl=0.07, rh=0.09, hunch=0.0, neck=0.04):
    hip = leg * H
    chest_top = hip + torso * H
    sh_z = chest_top - 0.04 * H
    head_z = chest_top + neck * H
    hy = hunch * H
    b = [("root", V(0, 0, hip), V(0, 0.2 * H, hip), None, 0, 0),
         ("hips", V(0, 0, hip), V(0, hy * 0.3, hip + torso * H * 0.4), "root", rt * H * 0.9, rt * H),
         ("chest", V(0, hy * 0.3, hip + torso * H * 0.4), V(0, hy, chest_top), "hips", rt * H, rt * H * 0.75),
         ("head", V(0, hy, head_z), V(0, hy + 0.02 * H, head_z + 2 * rh * H), "chest", rh * H, rh * H * 0.9)]
    ua, fa = arm * H * 0.5, arm * H * 0.5
    for s, sn in ((1, "l"), (-1, "r")):
        sx = s * sw * H
        sh = V(sx, hy, sh_z)
        el = V(sx * 1.08, hy, sh_z - ua)
        wr = V(sx * 1.1, hy + 0.04 * H, sh_z - ua - fa)
        b += [(f"uarm_{sn}", sh, el, "chest", ra * H * 1.15, ra * H),
              (f"farm_{sn}", el, wr, f"uarm_{sn}", ra * H, ra * H * 1.1),
              (f"hand_{sn}", wr, wr + V(0, 0.02 * H, -0.08 * H), f"farm_{sn}", ra * H * 1.3, ra * H * 1.1)]
        hx = s * hw * H
        kn = V(hx * 1.05, 0.02 * H, hip * 0.5)
        an = V(hx * 1.05, 0.0, 0.04 * H)
        b += [(f"thigh_{sn}", V(hx, 0, hip), kn, "hips", rl * H * 1.3, rl * H),
              (f"shin_{sn}", kn, an, f"thigh_{sn}", rl * H * 0.95, rl * H * 0.8),
              (f"foot_{sn}", an, an + V(0, 0.12 * H, -0.02 * H), f"shin_{sn}", rl * H * 0.8, rl * H * 0.7)]
    return b


def biped_walk(t, swing=0.4, arm=0.35, bob=0.03, H=2.0):
    p = t * tau
    o = {}
    for sn, ph in (("l", 0.0), ("r", pi)):
        s, c = sin(p + ph), cos(p + ph)
        o[f"thigh_{sn}"] = [(X, swing * s)]
        o[f"shin_{sn}"] = [(X, -0.8 * swing * max(0.0, -c))]
        o[f"uarm_{sn}"] = [(X, -arm * s)]
        o[f"farm_{sn}"] = [(X, 0.25 + 0.1 * s)]
    o["chest"] = [(Z, 0.06 * sin(p))]
    o["hips"] = [(Z, -0.05 * sin(p))]
    o["_loc"] = V(0, 0, bob * H * abs(sin(p)))
    return o


def biped_idle(t, H=2.0, breathe=0.03):
    b = sin(t * tau)
    o = {"chest": [(X, -breathe * b)], "head": [(X, 0.03 * b), (Z, 0.06 * sin(t * tau * 0.5 + 1))]}
    for sn, sd in (("l", 1), ("r", -1)):
        o[f"uarm_{sn}"] = [(Y, sd * 0.06), (X, 0.03 * b)]
        o[f"farm_{sn}"] = [(X, 0.2)]
    o["_loc"] = V(0, 0, -0.008 * H * (1 - cos(t * tau)))
    return o


def slam_attack(t, H=2.0):
    """Ergue os dois braços e bate no chão (golens, yetis, chefes)."""
    up = pulse(t, 0.0, 0.4, 0.45, 0.55)
    hit = pulse(t, 0.5, 0.6, 0.75, 1.0)
    o = {"chest": [(X, 0.25 * up - 0.45 * hit)], "head": [(X, 0.2 * up - 0.1 * hit)]}
    for sn in ("l", "r"):
        o[f"uarm_{sn}"] = [(X, 2.7 * up + 1.2 * hit)]
        o[f"farm_{sn}"] = [(X, 0.5 * up + 0.2 * hit)]
        o[f"thigh_{sn}"] = [(X, 0.35 * hit)]
        o[f"shin_{sn}"] = [(X, -0.6 * hit)]
    o["_loc"] = V(0, 0.05 * H * hit, -0.08 * H * hit + 0.02 * H * up)
    return o


def swing_attack(t, H=2.0):
    """Golpe com o braço direito (espada/garra), com giro do tronco."""
    back = pulse(t, 0.0, 0.35, 0.38, 0.48)
    hit = pulse(t, 0.4, 0.55, 0.7, 1.0)
    return {"chest": [(Z, 0.4 * back - 0.5 * hit), (X, -0.1 * hit)], "hips": [(Z, 0.15 * back - 0.15 * hit)],
            "uarm_r": [(X, 2.2 * back + 0.3 * hit), (Y, -0.5 * back + 0.2 * hit)], "farm_r": [(X, 0.6 * back + 0.2 * hit)],
            "uarm_l": [(X, 0.4 * back - 0.3 * hit)],
            "thigh_l": [(X, 0.4 * hit)], "shin_l": [(X, -0.3 * hit)], "thigh_r": [(X, -0.25 * hit)],
            "_loc": V(0, 0.1 * H * hit, -0.03 * H * hit)}


def build_golem(name, rock, rock2, glow_c, crystal=None):
    C.new_scene()
    H = 3.7
    skin = C.mat(name + "_pedra", rock, rough=0.95)
    dark = C.mat(name + "_pedra2", rock2, rough=0.95)
    rune = C.mat(name + "_runa", glow_c, glow=4.0)
    bones = biped_bones(H, leg=0.3, torso=0.42, sw=0.27, hw=0.13, arm=0.52, rt=0.2, ra=0.1, rl=0.11, rh=0.1, hunch=0.12, neck=0.06)
    c = C.Creature(name, bones, skin, resolution=0.13)
    c.build_armature()
    hip = 0.3 * H
    c.build_body(extra_balls=[((sd * 0.26 * H, 0.12 * H, 0.68 * H), 0.14 * H) for sd in (-1, 1)])   # ombros enormes
    c.shade(belly=1.2, back=0.75, spots=lambda co: 0.82 + 0.18 * (math.sin(co.x * 7) * math.sin(co.y * 6) * math.sin(co.z * 5) > 0))
    c.bind()
    hz = 0.78 * H
    for sd in (-1, 1):
        c.part("sphere", "Olho", rune, V(sd * 0.04 * H, 0.12 * H + 0.075 * H, hz + 0.07 * H), (0.06 * H, 0.03 * H, 0.035 * H), bone="head")
        for k in range(3):   # pedras soltas nos ombros
            c.part("sphere", "Rocha", dark, V(sd * (0.25 + 0.04 * k) * H, (0.08 + 0.05 * k) * H, (0.8 - 0.02 * k) * H),
                   (0.09 * H, 0.08 * H, 0.07 * H), rot=(k, k * 0.7, 0), bone="chest", seg=6)
        if crystal is not None:
            cm = C.mat(name + "_cristal", crystal, glow=2.0)
            for k in range(3):
                c.part("cone", "Cristal", cm, V(sd * (0.2 + 0.05 * k) * H, (0.02 + 0.04 * k) * H, (0.84 + 0.02 * k) * H),
                       (0.05 * H, 0.05 * H, (0.18 - 0.03 * k) * H), rot=(-0.3, sd * (0.4 + 0.2 * k), 0), bone="chest", seg=6)
    c.part("sphere", "Runa", rune, V(0, 0.22 * H + 0.12 * H, 0.6 * H), (0.12 * H, 0.03 * H, 0.12 * H), bone="chest", seg=12)
    c.actions({"idle": (40, lambda t: biped_idle(t, H, 0.02)), "walk": (28, lambda t: biped_walk(t, 0.32, 0.3, 0.02, H)),
               "attack": (24, lambda t: slam_attack(t, H))})
    c.export()


def build_yeti(name, fur, face, eye, horns=False):
    C.new_scene()
    H = 3.1
    skin = C.mat(name + "_pelo", fur, rough=0.95)
    facem = C.mat(name + "_cara", face, rough=0.8)
    eyes = C.mat(name + "_olho", eye, glow=3.0)
    bones = biped_bones(H, leg=0.36, torso=0.38, sw=0.22, hw=0.11, arm=0.5, rt=0.21, ra=0.09, rl=0.1, rh=0.12, hunch=0.1, neck=0.05)
    c = C.Creature(name, bones, skin, resolution=0.1)
    c.build_armature()
    c.build_body(extra_balls=[((0, 0.06 * H, 0.55 * H), 0.24 * H)] + [((sd * 0.2 * H, 0.08 * H, 0.7 * H), 0.12 * H) for sd in (-1, 1)])
    c.shade(belly=1.15, back=0.85)
    c.bind()
    hz = 0.79 * H + 0.12 * H
    c.part("sphere", "Cara", facem, V(0, 0.1 * H + 0.09 * H, hz), (0.14 * H, 0.05 * H, 0.12 * H), bone="head")
    for sd in (-1, 1):
        c.part("sphere", "Olho", eyes, V(sd * 0.035 * H, 0.1 * H + 0.11 * H, hz + 0.02 * H), (0.03 * H, 0.015 * H, 0.025 * H), bone="head")
        c.part("cone", "Presa", C.mat(name + "_dente", (0.95, 0.93, 0.88)), V(sd * 0.03 * H, 0.1 * H + 0.11 * H, hz - 0.045 * H),
               (0.018 * H, 0.018 * H, 0.04 * H), rot=(pi, 0, 0), bone="head", seg=6)
        if horns:
            c.part("cone", "Chifre", C.mat(name + "_chifre", (0.85, 0.8, 0.7)), V(sd * 0.09 * H, 0.08 * H, hz + 0.1 * H),
                   (0.04 * H, 0.04 * H, 0.2 * H), rot=(-0.6, sd * 0.9, 0), bone="head", seg=8)
    c.actions({"idle": (40, lambda t: biped_idle(t, H, 0.04)), "walk": (24, lambda t: biped_walk(t, 0.38, 0.45, 0.03, H)),
               "attack": (22, lambda t: slam_attack(t, H))})
    c.export()


def build_skeleton(name, bone_c, eye_c, king=False):
    C.new_scene()
    H = 2.15
    skin = C.mat(name + "_osso", bone_c, rough=0.7)
    eyes = C.mat(name + "_olho", eye_c, glow=4.0)
    rusty = C.mat(name + "_ferro", (0.45, 0.42, 0.4), metal=0.7, rough=0.5)
    bones = biped_bones(H, leg=0.47, torso=0.3, sw=0.14, hw=0.07, arm=0.42, rt=0.05, ra=0.022, rl=0.026, rh=0.0, hunch=0.03, neck=0.05)
    c = C.Creature(name, bones, skin, resolution=0.035)
    c.build_armature()
    c.build_body(extra_balls=[((0, 0.03 * H, 0.47 * H), 0.06 * H)], decimate_to=5000)
    c.shade(belly=1.0, back=0.85)
    c.bind()
    hz = 0.47 * H + 0.3 * H + 0.05 * H
    c.part("sphere", "Cranio", skin, V(0, 0.03 * H, hz + 0.08 * H), (0.17 * H, 0.18 * H, 0.17 * H), bone="head", seg=14)
    c.part("box", "Mandibula", skin, V(0, 0.08 * H, hz + 0.01 * H), (0.1 * H, 0.08 * H, 0.04 * H), bone="head")
    for sd in (-1, 1):
        c.part("sphere", "Olho", eyes, V(sd * 0.035 * H, 0.03 * H + 0.085 * H, hz + 0.09 * H), (0.035 * H, 0.015 * H, 0.03 * H), bone="head")
    for k in range(4):   # costelas
        zz = 0.47 * H + (0.12 + 0.045 * k) * H
        c.part("cyl", "Costela", skin, V(0, 0.03 * H, zz), (0.19 * H - k * 0.01 * H, 0.13 * H, 0.012 * H), bone="chest", seg=12)
    c.part("box", "Espada", rusty, V(-0.15 * H, 0.15 * H, 0.47 * H - 0.08 * H), (0.025 * H, 0.012 * H, 0.42 * H), rot=(0.4, 0, 0), bone="hand_r")
    if king:
        gold = C.mat(name + "_coroa", (1.0, 0.75, 0.25), metal=0.9, rough=0.3)
        c.part("cyl", "Coroa", gold, V(0, 0.03 * H, hz + 0.17 * H), (0.17 * H, 0.17 * H, 0.05 * H), bone="head", seg=12)
        for k in range(5):
            a = k / 5 * tau
            c.part("cone", "Ponta", gold, V(math.cos(a) * 0.08 * H, 0.03 * H + math.sin(a) * 0.08 * H, hz + 0.22 * H),
                   (0.03 * H, 0.03 * H, 0.06 * H), bone="head", seg=4)
        c.part("box", "Manto", C.mat(name + "_manto", (0.35, 0.08, 0.12), rough=0.9), V(0, -0.06 * H, 0.62 * H),
               (0.3 * H, 0.02 * H, 0.42 * H), rot=(0.1, 0, 0), bone="chest")
    c.actions({"idle": (36, lambda t: biped_idle(t, H, 0.03)), "walk": (24, lambda t: biped_walk(t, 0.45, 0.4, 0.025, H)),
               "attack": (18, lambda t: swing_attack(t, H))})
    c.export()


def build_imp(name, skin_c, wing_c, eye_c, lord=False):
    C.new_scene()
    H = 1.45 * (1.15 if lord else 1.0)
    skin = C.mat(name + "_pele", skin_c, rough=0.7)
    wing = C.mat(name + "_asa", wing_c, rough=0.8)
    eyes = C.mat(name + "_olho", eye_c, glow=4.0)
    horn = C.mat(name + "_chifre", (0.18, 0.12, 0.1), rough=0.6)
    bones = biped_bones(H, leg=0.36, torso=0.3, sw=0.15, hw=0.08, arm=0.4, rt=0.15, ra=0.05, rl=0.06, rh=0.15, hunch=0.06, neck=0.0)
    hz = 0.36 * H + 0.3 * H
    for sd, sn in ((1, "l"), (-1, "r")):
        sh = V(sd * 0.08 * H, -0.08 * H, hz - 0.05 * H)
        el = sh + V(sd * 0.45 * H, -0.15 * H, 0.35 * H)
        tip = el + V(sd * 0.4 * H, -0.1 * H, -0.2 * H)
        bones += [(f"wing1_{sn}", sh, el, "chest", 0.02 * H, 0.015 * H), (f"wing2_{sn}", el, tip, f"wing1_{sn}", 0.015 * H, 0.01 * H)]
    bones += [("tail1", V(0, -0.05 * H, 0.36 * H), V(0, -0.35 * H, 0.25 * H), "hips", 0.04 * H, 0.03 * H),
              ("tail2", V(0, -0.35 * H, 0.25 * H), V(0, -0.6 * H, 0.35 * H), "tail1", 0.03 * H, 0.015 * H)]
    c = C.Creature(name, bones, skin, resolution=0.045)
    c.build_armature()
    c.build_body()
    c.shade(belly=1.3, back=0.75)
    c.bind()
    for sd, sn in ((1, "l"), (-1, "r")):
        c.part("sphere", "Olho", eyes, V(sd * 0.06 * H, 0.06 * H + 0.13 * H, hz + 0.17 * H), (0.06 * H, 0.03 * H, 0.04 * H), bone="head")
        c.part("cone", "Chifre", horn, V(sd * 0.09 * H, 0.04 * H, hz + 0.3 * H), (0.04 * H, 0.04 * H, (0.22 if lord else 0.14) * H),
               rot=(-0.3, sd * 0.45, 0), bone="head", seg=8)
        sh = V(sd * 0.08 * H, -0.08 * H, hz - 0.05 * H)
        el = sh + V(sd * 0.45 * H, -0.15 * H, 0.35 * H)
        tip = el + V(sd * 0.4 * H, -0.1 * H, -0.2 * H)
        c.membrane(f"Asa_{sn}", wing, [sh, el, tip, sh + V(sd * 0.55 * H, -0.2 * H, -0.25 * H), sh + V(sd * 0.15 * H, -0.12 * H, -0.3 * H)],
                   [f"wing1_{sn}", f"wing2_{sn}", "chest"])
        for k in range(3):
            c.part("cone", "Garra", horn, V(sd * 0.17 * H + (k - 1) * 0.02 * H, 0.1 * H, 0.08 * H), (0.015 * H, 0.015 * H, 0.06 * H),
                   rot=(-1.2, 0, 0), bone=f"hand_{sn}", seg=4)
    c.part("cone", "Ponta", horn, V(0, -0.62 * H, 0.37 * H), (0.07 * H, 0.03 * H, 0.1 * H), rot=(-0.6, 0, 0), bone="tail2", seg=4)
    if lord:
        c.part("cyl", "Coroa", C.mat(name + "_ouro", (1.0, 0.7, 0.2), metal=0.9, rough=0.3), V(0, 0.06 * H, hz + 0.3 * H),
               (0.2 * H, 0.2 * H, 0.05 * H), bone="head", seg=10)
    lift = 0.42 * H   # voa um pouco acima do chão, batendo as asas

    def wings(t, k=1.0):
        return {f"wing1_{sn}": [(Y, sd * (0.55 * sin(t * tau)) * k)] for sd, sn in ((1, "l"), (-1, "r"))} | \
               {f"wing2_{sn}": [(Y, sd * 0.4 * sin(t * tau - 0.8) * k)] for sd, sn in ((1, "l"), (-1, "r"))}

    def idle(t):
        o = biped_idle(t, H)
        o.update(wings(t * 2))
        for sn in ("l", "r"):
            o[f"thigh_{sn}"] = [(X, 0.3)]
            o[f"shin_{sn}"] = [(X, -0.5)]
        o["tail1"] = [(Z, 0.3 * sin(t * tau))]
        o["_loc"] = V(0, 0, lift + 0.05 * H * sin(t * tau * 2))
        return o

    def walk(t):
        o = biped_walk(t, 0.2, 0.3, 0.0, H)
        o.update(wings(t * 2))
        o["chest"] = [(X, -0.25)]
        o["tail1"] = [(Z, 0.4 * sin(t * tau))]
        o["_loc"] = V(0, 0, lift + 0.06 * H * sin(t * tau * 2))
        return o

    def attack(t):
        o = swing_attack(t, H)
        o.update(wings(t * 3, 1.3))
        back = pulse(t, 0.0, 0.35, 0.38, 0.48)
        hit = pulse(t, 0.4, 0.55, 0.7, 1.0)
        o["uarm_l"] = [(X, 2.0 * back + 0.4 * hit), (Y, 0.4 * back)]
        o["_loc"] = V(0, 0.15 * H * hit, lift + 0.1 * H * back - 0.1 * H * hit)
        return o

    c.actions({"idle": (24, idle), "walk": (16, walk), "attack": (16, attack)})
    c.export()


# =================================================================== slimes e escorpiões

def build_slime(name, col, eye_c, king=False):
    C.new_scene()
    H = 1.3 if king else 0.95
    skin = C.mat(name + "_gel", col, rough=0.25)
    bones = [("root", V(0, 0, 0), V(0, 0.2, 0), None, 0, 0), ("body", V(0, 0, 0.02), V(0, 0, H), "root", 0, 0)]
    c = C.Creature(name, bones, skin, resolution=0.05)
    c.build_armature()
    c.build_body(extra_balls=[((0, 0, H * 0.4), H * 0.7), ((0, 0.04 * H, H * 0.6), H * 0.48)], decimate_to=4000)
    c.shade(belly=1.0, back=1.15)
    bpy.ops.object.select_all(action="DESELECT")   # todo o corpo preso ao osso "body"
    g = c.body.vertex_groups.new(name="body")
    g.add(list(range(len(c.body.data.vertices))), 1.0, "REPLACE")
    md = c.body.modifiers.new("Esqueleto", "ARMATURE")
    md.object = c.arm
    c.body.parent = c.arm
    eyes = C.mat(name + "_olho", (1, 1, 1))
    pupil = C.mat(name + "_pupila", eye_c)
    for sd in (-1, 1):
        c.part("sphere", "Olho", eyes, V(sd * 0.15 * H, 0.4 * H, 0.55 * H), (0.17 * H, 0.1 * H, 0.21 * H), bone="body")
        c.part("sphere", "Pupila", pupil, V(sd * 0.15 * H, 0.45 * H, 0.55 * H), (0.08 * H, 0.05 * H, 0.1 * H), bone="body")
    if king:
        gold = C.mat(name + "_coroa", (1.0, 0.78, 0.25), metal=0.9, rough=0.3)
        c.part("cyl", "Coroa", gold, V(0, 0, 0.98 * H), (0.36 * H, 0.36 * H, 0.12 * H), bone="body", seg=12)
        for k in range(5):
            a = k / 5 * tau
            c.part("cone", "Ponta", gold, V(math.cos(a) * 0.15 * H, math.sin(a) * 0.15 * H, 1.08 * H), (0.07 * H, 0.07 * H, 0.14 * H), bone="body", seg=4)

    def idle(t):
        k = sin(t * tau)
        return {"_scale": {"body": (1 + 0.04 * k, 1 + 0.04 * k, 1 - 0.06 * k)}}

    def walk(t):
        k = sin(t * tau)
        hop = max(0.0, k)
        return {"_scale": {"body": (1 - 0.08 * hop + 0.1 * max(0.0, -k), 1 - 0.08 * hop, 1 + 0.15 * hop - 0.15 * max(0.0, -k))},
                "_loc": V(0, 0, 0.25 * H * hop)}

    def attack(t):
        squash = pulse(t, 0.0, 0.35, 0.38, 0.45)
        jump = pulse(t, 0.4, 0.55, 0.65, 1.0)
        return {"_scale": {"body": (1 + 0.25 * squash - 0.1 * jump, 1 + 0.25 * squash - 0.1 * jump, 1 - 0.35 * squash + 0.25 * jump)},
                "_loc": V(0, 0.6 * H * jump, 0.4 * H * jump)}

    c.actions({"idle": (30, idle), "walk": (20, walk), "attack": (18, attack)})
    c.export()


def build_scorpion(name, shell, shell2, sting_c, queen=False):
    C.new_scene()
    s = 1.0
    skin = C.mat(name + "_casca", shell, rough=0.45)
    dark = C.mat(name + "_casca2", shell2, rough=0.45)
    sting = C.mat(name + "_ferrao", sting_c, glow=3.0 if queen else 1.0)
    hz = 0.6
    bones = [("root", V(0, 0, hz), V(0, 0.3, hz), None, 0, 0),
             ("thorax", V(0, -0.5, hz), V(0, 0.4, hz + 0.05), "root", 0.55, 0.52),
             ("head", V(0, 0.4, hz + 0.05), V(0, 0.85, hz), "thorax", 0.4, 0.3),
             ("abdo", V(0, -0.5, hz), V(0, -1.2, hz + 0.05), "thorax", 0.5, 0.4)]
    prev, p0 = "abdo", V(0, -1.2, hz + 0.05)
    for k in range(5):   # cauda curvada por cima
        a = 0.5 + k * 0.42
        p1 = p0 + V(0, -0.42 * math.cos(a), 0.42 * math.sin(a))
        bones.append((f"tail{k}", p0, p1, prev, 0.2 - 0.025 * k, 0.18 - 0.025 * k))
        prev, p0 = f"tail{k}", p1
    for sd, sn in ((1, "l"), (-1, "r")):
        for k in range(4):   # 4 pares de patas
            yy = 0.3 - k * 0.35
            hip_p = V(sd * 0.35, yy, hz)
            knee = V(sd * 0.85, yy + 0.05, hz + 0.25)
            foot = V(sd * 1.15, yy - 0.05 + 0.05 * k, 0.02)
            bones += [(f"leg{k}a_{sn}", hip_p, knee, "thorax", 0.08, 0.07), (f"leg{k}b_{sn}", knee, foot, f"leg{k}a_{sn}", 0.07, 0.04)]
        sh = V(sd * 0.3, 0.7, hz)
        el = V(sd * 0.7, 1.2, hz + 0.05)
        cl = V(sd * 0.55, 1.75, hz + 0.05)
        bones += [(f"arm_{sn}", sh, el, "head", 0.11, 0.1), (f"claw_{sn}", el, cl, f"arm_{sn}", 0.15, 0.1)]
    c = C.Creature(name, bones, skin, resolution=0.06)
    c.build_armature()
    c.build_body(extra_balls=[(V(sd * 0.62, 1.55, hz + 0.05), 0.22) for sd in (-1, 1)], decimate_to=7000)
    c.shade(belly=1.35, back=0.75, spots=lambda co: 0.85 + 0.15 * (math.sin(co.y * 9) > 0.3))
    c.bind()
    c.part("cone", "Ferrao", sting, p0 + V(0, 0.12, 0.05), (0.14, 0.14, 0.4), rot=(-2.4, 0, 0), bone="tail4", seg=8)
    for sd in (-1, 1):
        c.part("sphere", "Olho", C.mat(name + "_olho", (1.0, 0.25, 0.15), glow=3.0), V(sd * 0.1, 0.8, hz + 0.18), (0.07, 0.06, 0.06), bone="head")
        c.part("cone", "Pinca", dark, V(sd * 0.48, 1.9, hz + 0.05), (0.12, 0.12, 0.4), rot=(-pi / 2, 0, sd * 0.3), bone=f"claw_{sn}" if False else ("claw_l" if sd > 0 else "claw_r"), seg=6)
    if queen:
        gold = C.mat(name + "_coroa", (1.0, 0.78, 0.3), metal=0.9, rough=0.3)
        for k in range(4):
            c.part("cone", "Espinho", gold, V((k - 1.5) * 0.12, 0.6, hz + 0.32), (0.06, 0.06, 0.2), bone="head", seg=4)

    def legs(t, amp):
        o = {}
        for sd, sn in ((1, "l"), (-1, "r")):
            for k in range(4):
                ph = t * tau + k * pi / 2 + (0 if sd > 0 else pi)
                o[f"leg{k}a_{sn}"] = [(Z, amp * sin(ph)), (Y, sd * 0.2 * amp * max(0.0, cos(ph)))]
        return o

    def idle(t):
        o = legs(t, 0.03)
        for k in range(5):
            o[f"tail{k}"] = [(X, 0.04 * sin(t * tau - k * 0.5))]
        o["arm_l"] = [(Z, 0.08 * sin(t * tau))]
        o["arm_r"] = [(Z, -0.08 * sin(t * tau))]
        return o

    def walk(t):
        o = legs(t * 2, 0.35)
        for k in range(5):
            o[f"tail{k}"] = [(X, 0.05 * sin(t * tau * 2 - k * 0.6)), (Z, 0.05 * sin(t * tau * 2))]
        o["_loc"] = V(0, 0, 0.03 * abs(sin(t * tau * 2)))
        return o

    def attack(t):
        back = pulse(t, 0.0, 0.35, 0.38, 0.48)
        hit = pulse(t, 0.42, 0.55, 0.7, 1.0)
        o = legs(t, 0.05)
        for k in range(5):
            o[f"tail{k}"] = [(X, 0.12 * back + 0.35 * hit)]
        for sn, sd in (("l", 1), ("r", -1)):
            o[f"arm_{sn}"] = [(Z, sd * (0.3 * back - 0.3 * hit))]
        o["_loc"] = V(0, 0.15 * hit, 0)
        return o

    c.actions({"idle": (30, idle), "walk": (16, walk), "attack": (18, attack)})
    c.export()


# =================================================================== lista

BUILD = {
    "wolf": lambda: build_wolf("wolf", (0.42, 0.38, 0.36), (0.6, 0.55, 0.5), (1.0, 0.75, 0.2)),
    "wolf_alpha": lambda: build_wolf("wolf_alpha", (0.2, 0.17, 0.2), (0.42, 0.36, 0.38), (1.0, 0.25, 0.15), mane=1.25),
    "wolf_ice": lambda: build_wolf("wolf_ice", (0.75, 0.84, 0.95), (0.9, 0.95, 1.0), (0.4, 0.85, 1.0), spikes=((0.55, 0.85, 1.0), 1.5)),
    "wolf_glacial": lambda: build_wolf("wolf_glacial", (0.55, 0.68, 0.9), (0.85, 0.92, 1.0), (0.3, 0.7, 1.0), mane=1.3, spikes=((0.45, 0.8, 1.0), 2.0)),
    "dragon_ancient": lambda: build_dragon("dragon_ancient", (0.42, 0.08, 0.07), (0.85, 0.55, 0.3), (0.3, 0.06, 0.06), (0.92, 0.85, 0.7), (1.0, 0.8, 0.2)),
    "dragon_whelp": lambda: build_dragon("dragon_whelp", (0.85, 0.35, 0.1), (1.0, 0.75, 0.4), (0.65, 0.2, 0.08), (0.95, 0.9, 0.75), (1.0, 0.9, 0.3), whelp=True),
    "golem": lambda: build_golem("golem", (0.42, 0.4, 0.44), (0.3, 0.29, 0.33), (1.0, 0.5, 0.24)),
    "golem_ice": lambda: build_golem("golem_ice", (0.62, 0.74, 0.86), (0.45, 0.56, 0.7), (0.4, 0.85, 1.0), crystal=(0.55, 0.88, 1.0)),
    "golem_magma": lambda: build_golem("golem_magma", (0.22, 0.15, 0.14), (0.14, 0.1, 0.1), (1.0, 0.45, 0.1), crystal=(1.0, 0.4, 0.08)),
    "golem_sand": lambda: build_golem("golem_sand", (0.78, 0.62, 0.42), (0.6, 0.47, 0.32), (0.4, 1.0, 0.85)),
    "yeti": lambda: build_yeti("yeti", (0.88, 0.9, 0.95), (0.45, 0.55, 0.68), (0.4, 0.8, 1.0)),
    "yeti_ancient": lambda: build_yeti("yeti_ancient", (0.7, 0.78, 0.9), (0.3, 0.38, 0.52), (0.3, 0.65, 1.0), horns=True),
    "skeleton": lambda: build_skeleton("skeleton", (0.9, 0.86, 0.76), (0.4, 0.9, 1.0)),
    "skeleton_king": lambda: build_skeleton("skeleton_king", (0.82, 0.78, 0.68), (1.0, 0.35, 0.25), king=True),
    "imp": lambda: build_imp("imp", (0.75, 0.2, 0.15), (0.4, 0.1, 0.1), (1.0, 0.85, 0.2)),
    "imp_lord": lambda: build_imp("imp_lord", (0.5, 0.1, 0.18), (0.25, 0.05, 0.1), (1.0, 0.5, 0.15), lord=True),
    "slime": lambda: build_slime("slime", (0.45, 0.85, 0.45), (0.1, 0.15, 0.1)),
    "slime_king": lambda: build_slime("slime_king", (0.4, 0.7, 0.95), (0.08, 0.1, 0.2), king=True),
    "scorpion": lambda: build_scorpion("scorpion", (0.6, 0.35, 0.18), (0.4, 0.22, 0.12), (0.8, 0.9, 0.3)),
    "scorpion_queen": lambda: build_scorpion("scorpion_queen", (0.35, 0.12, 0.3), (0.22, 0.08, 0.2), (0.9, 0.4, 1.0), queen=True),
}


def main():
    names = sys.argv[-1].split(",") if len(sys.argv) > 1 and not sys.argv[-1].endswith(".py") else list(BUILD.keys())
    for n in names:
        BUILD[n]()


if __name__ == "__main__":
    main()
