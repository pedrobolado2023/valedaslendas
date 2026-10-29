"""
Monstros, chefes, NPCs e cenários dos mapas Deserto Escarlate, Picos Gelados e Abismo Vulcânico.
Rode:  blender -b -P blender/make_maps.py     ou   python blender/make_maps.py  (com pip install bpy)
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_models import (PI, DARK, empty, export, export_static, jitter, mat, new_scene, prim, register, cyc,  # noqa: E402
                         write_anims, build_golem, build_wolf, build_hero, build_house, REST)


def _r(o):
    return REST[o]["rot"]


# =================================================================== escorpião

def build_scorpion(name, body_c, dark_c, glow_c, scale_tail=1.0):
    new_scene()
    shell = mat(name + "_casca", body_c)
    shell2 = mat(name + "_casca2", dark_c)
    eyes = mat(name + "_olhos", glow_c, glow=4.0)
    sting = mat(name + "_ferrao", glow_c, glow=2.5)
    root = empty("Scorpion")
    body = empty("Body", (0, 0, 0.55), root)
    prim("sphere", "Cefalo", shell, (0, 0.45, 0.0), (1.0, 0.9, 0.5), parent=body, seg=16, rings=10)
    for k in range(4):
        prim("sphere", f"Seg{k}", shell if k % 2 == 0 else shell2, (0, -0.1 - k * 0.32, 0.02), (1.05 - k * 0.12, 0.42, 0.48 - k * 0.04), parent=body, seg=14, rings=8)
    for s in (-1, 1):
        prim("sphere", "Olho", eyes, (s * 0.15, 0.85, 0.15), (0.1, 0.08, 0.08), parent=body, seg=8, rings=5)
    legs = []
    for side in (-1, 1):
        for k in range(3):
            lg = empty(f"Leg{side}{k}", (side * 0.45, 0.25 - k * 0.35, -0.05), body)
            prim("cyl", "Perna", shell2, (side * 0.3, 0, -0.1), (0.1, 0.1, 0.7), rot=(0, side * 1.1, 0), parent=lg, seg=6)
            prim("cyl", "Pe", shell2, (side * 0.62, 0, -0.38), (0.08, 0.08, 0.5), rot=(0, side * 0.25, 0), parent=lg, seg=6)
            legs.append(lg)
    claws = []
    for s in (-1, 1):
        cl = empty("Claw", (s * 0.45, 0.85, 0.0), body, (0, 0, s * 0.3))
        prim("cyl", "BracoPinca", shell, (s * 0.15, 0.3, 0), (0.18, 0.18, 0.6), rot=(-1.2, 0, 0), parent=cl, seg=8)
        prim("sphere", "Pinca", shell2, (s * 0.2, 0.75, 0.05), (0.45, 0.55, 0.32), parent=cl, seg=12, rings=8)
        prim("cone", "Dedo", shell, (s * 0.32, 1.05, 0.05), (0.14, 0.14, 0.4), rot=(-PI / 2, 0, s * 0.3), parent=cl, seg=6)
        claws.append(cl)
    tail = empty("Tail", (0, -1.25, 0.1), body, (0.9, 0, 0))
    t2 = tail
    for k in range(4):
        prim("sphere", f"Cauda{k}", shell if k % 2 else shell2, (0, -0.0, 0.25), (0.36 * scale_tail, 0.36 * scale_tail, 0.5), parent=t2, seg=10, rings=6)
        nxt = empty(f"Tail{k}", (0, 0, 0.42), t2, (0.45, 0, 0))
        t2 = nxt
    prim("cone", "Ferrao", sting, (0, 0.1, 0.25), (0.22, 0.22, 0.5), rot=(0.9, 0, 0), parent=t2, seg=8)
    register(body, tail, *legs, *claws)
    lg_l = legs[:3]
    lg_r = legs[3:]
    walk_j = {body: dict(loc=cyc(16, 8, lambda t: (0, 0, 0.55 + 0.03 * abs(math.sin(2 * PI * t)))))}
    for i, lg in enumerate(legs):
        ph = (i % 2) * PI + (0 if i < 3 else PI)
        walk_j[lg] = dict(rot=cyc(16, 8, lambda t, ph=ph: (0, 0, 0.35 * math.sin(2 * PI * t + ph))))
    idle = dict(length=36, joints={
        tail: dict(rot=cyc(36, 4, lambda t: (0.9 + 0.12 * math.sin(2 * PI * t), 0, 0))),
        claws[0]: dict(rot=cyc(36, 4, lambda t: (0, 0, -0.3 + 0.1 * math.sin(2 * PI * t)))),
        claws[1]: dict(rot=cyc(36, 4, lambda t: (0, 0, 0.3 - 0.1 * math.sin(2 * PI * t)))),
    })
    walk = dict(length=16, joints=walk_j)
    atk = dict(length=14, joints={
        tail: dict(rot=[(1, (0.9, 0, 0)), (5, (0.5, 0, 0)), (8, (1.9, 0, 0)), (15, (0.9, 0, 0))]),
        body: dict(loc=[(1, (0, 0, 0.55)), (8, (0, 0.3, 0.5)), (15, (0, 0, 0.55))]),
        claws[0]: dict(rot=[(1, (0, 0, -0.3)), (6, (0, 0, -0.8)), (9, (0, 0, 0.1)), (15, (0, 0, -0.3))]),
        claws[1]: dict(rot=[(1, (0, 0, 0.3)), (6, (0, 0, 0.8)), (9, (0, 0, -0.1)), (15, (0, 0, 0.3))]),
    })
    write_anims({"idle": idle, "walk": walk, "attack": atk})
    export(name)


# =================================================================== esqueleto

def build_skeleton(name, bone_c, armor_c, eye_c, crown=False):
    new_scene()
    bone = mat(name + "_osso", bone_c)
    armor = mat(name + "_armadura", armor_c)
    eyes = mat(name + "_olhos", eye_c, glow=5.0)
    dark = mat("escuro", DARK)
    rust = mat(name + "_ferrugem", (0.45, 0.32, 0.22))
    root = empty("Skeleton")
    hips = empty("Hips", (0, 0, 0.95), root)
    prim("sphere", "Pelve", bone, (0, 0, 0.0), (0.42, 0.3, 0.2), parent=hips, seg=10, rings=6)
    prim("cyl", "Coluna", bone, (0, -0.02, 0.35), (0.1, 0.1, 0.6), parent=hips, seg=8)
    for k in range(4):
        prim("torus", f"Costela{k}", bone, (0, 0.02, 0.32 + k * 0.1), (0.5 - k * 0.03, 0.36, 0.7), parent=hips, minor=0.03)
    prim("box", "Peitoral", armor, (0, 0.05, 0.44), (0.56, 0.3, 0.3), parent=hips, bevel=0.04)
    prim("box", "Tanga", rust, (0, 0.08, -0.15), (0.4, 0.06, 0.32), parent=hips, bevel=0.02)
    head = empty("Head", (0, 0.02, 0.95), hips)
    prim("sphere", "Cranio", bone, (0, 0, 0), (0.5, 0.52, 0.5), parent=head, seg=14, rings=8)
    prim("box", "Mandibula", bone, (0, 0.12, -0.2), (0.3, 0.26, 0.12), parent=head, bevel=0.03)
    for s in (-1, 1):
        prim("sphere", "Orbita", dark, (s * 0.1, 0.2, 0.0), (0.14, 0.08, 0.14), parent=head, seg=8, rings=5)
        prim("sphere", "Brilho", eyes, (s * 0.1, 0.24, 0.0), (0.06, 0.04, 0.06), parent=head, seg=8, rings=5)
    if crown:
        gold = mat(name + "_coroa", (0.95, 0.72, 0.25))
        prim("cyl", "Coroa", gold, (0, 0, 0.24), (0.46, 0.46, 0.14), parent=head, seg=12)
        for k in range(6):
            a = k * math.tau / 6
            prim("cone", f"Ponta{k}", gold, (math.cos(a) * 0.2, math.sin(a) * 0.2, 0.38), (0.1, 0.1, 0.2), parent=head, seg=4)
    else:
        prim("sphere", "Elmo", rust, (0, -0.02, 0.1), (0.54, 0.54, 0.38), parent=head, seg=12, rings=6)
    arm_l = empty("ArmL", (-0.32, 0, 0.62), hips, (0.3, 0, 0))
    arm_r = empty("ArmR", (0.32, 0, 0.62), hips, (1.3, 0, 0))
    for arm in (arm_l, arm_r):
        prim("cyl", "Umero", bone, (0, 0, -0.22), (0.09, 0.09, 0.44), parent=arm, seg=6)
        prim("cyl", "Ulna", bone, (0, 0, -0.5), (0.08, 0.08, 0.3), parent=arm, seg=6)
        prim("sphere", "Mao", bone, (0, 0, -0.66), (0.13, 0.13, 0.13), parent=arm, seg=8, rings=5)
    w = empty("Weapon", (0, 0, -0.66), arm_r)
    prim("box", "Espada", rust, (0, 0, -0.65), (0.1, 0.03, 1.1), parent=w, bevel=0.01)
    prim("box", "Guarda", rust, (0, 0, -0.08), (0.36, 0.06, 0.06), parent=w)
    prim("cyl", "Escudo", armor, (-0.08, 0.1, -0.4), (0.55, 0.55, 0.05), rot=(0, PI / 2, 0), parent=arm_l, seg=16)
    leg_l = empty("LegL", (-0.13, 0, -0.05), hips)
    leg_r = empty("LegR", (0.13, 0, -0.05), hips)
    for lg in (leg_l, leg_r):
        prim("cyl", "Femur", bone, (0, 0, -0.25), (0.1, 0.1, 0.5), parent=lg, seg=6)
        prim("cyl", "Tibia", bone, (0, 0, -0.62), (0.09, 0.09, 0.4), parent=lg, seg=6)
        prim("box", "Pe", bone, (0, 0.08, -0.86), (0.14, 0.3, 0.07), parent=lg)
    register(hips, arm_l, arm_r, leg_l, leg_r, head)
    rl, rr = _r(arm_l), _r(arm_r)
    idle = dict(length=36, joints={
        hips: dict(loc=cyc(36, 4, lambda t: (0, 0, 0.95 + 0.02 * math.sin(2 * PI * t)))),
        head: dict(rot=cyc(36, 4, lambda t: (0, 0, 0.12 * math.sin(2 * PI * t)))),
    })
    walk = dict(length=24, joints={
        hips: dict(loc=cyc(24, 8, lambda t: (0, 0, 0.9 - 0.04 * math.cos(4 * PI * t)))),
        leg_l: dict(rot=cyc(24, 8, lambda t: (0.5 * math.cos(2 * PI * t), 0, 0))),
        leg_r: dict(rot=cyc(24, 8, lambda t: (-0.5 * math.cos(2 * PI * t), 0, 0))),
        arm_l: dict(rot=cyc(24, 8, lambda t: (rl[0] - 0.4 * math.cos(2 * PI * t), 0, 0))),
    })
    atk = dict(length=12, joints={
        arm_r: dict(rot=[(1, rr), (4, (2.6, 0, 0)), (7, (0.4, 0, 0)), (13, rr)]),
        hips: dict(rot=[(1, (0, 0, 0)), (4, (-0.15, 0, 0.3)), (7, (0.2, 0, -0.2)), (13, (0, 0, 0))]),
    })
    write_anims({"idle": idle, "walk": walk, "attack": atk})
    export(name)


# =================================================================== yeti

def build_yeti(name, fur_c, face_c, horn_c):
    new_scene()
    fur = mat(name + "_pelo", fur_c)
    face = mat(name + "_rosto", face_c)
    horn = mat(name + "_chifre", horn_c)
    eyes = mat(name + "_olhos", (0.4, 0.85, 1.0), glow=4.0)
    dark = mat("escuro", DARK)
    root = empty("Yeti")
    hips = empty("Hips", (0, 0, 1.1), root)
    o = prim("ico", "Corpo", fur, (0, 0, 0.55), (1.7, 1.3, 1.8), parent=hips, sub=2)
    jitter(o, 0.05, 2)
    prim("ico", "Barriga", face, (0, 0.42, 0.4), (1.0, 0.6, 1.1), parent=hips, sub=2)
    head = empty("Head", (0, 0.3, 1.45), hips)
    o = prim("ico", "Cabeca", fur, (0, 0, 0), (0.95, 0.85, 0.85), parent=head, sub=2)
    jitter(o, 0.04, 3)
    prim("sphere", "Face", face, (0, 0.32, -0.05), (0.62, 0.3, 0.5), parent=head, seg=12, rings=8)
    for s in (-1, 1):
        prim("sphere", "Olho", eyes, (s * 0.14, 0.45, 0.05), (0.1, 0.06, 0.08), parent=head, seg=8, rings=5)
        prim("cone", "Chifre", horn, (s * 0.38, 0, 0.3), (0.2, 0.2, 0.55), rot=(0.3, s * 0.8, 0), parent=head, seg=8)
    prim("box", "Boca", dark, (0, 0.45, -0.22), (0.3, 0.05, 0.08), parent=head)
    arm_l = empty("ArmL", (-0.85, 0, 0.95), hips, (0.15, 0, 0))
    arm_r = empty("ArmR", (0.85, 0, 0.95), hips, (0.15, 0, 0))
    for arm in (arm_l, arm_r):
        o = prim("ico", "Braco", fur, (0, 0, -0.55), (0.6, 0.6, 1.3), parent=arm, sub=2)
        jitter(o, 0.04, 5)
        prim("ico", "Punho", face, (0, 0.05, -1.25), (0.6, 0.6, 0.55), parent=arm, sub=2)
    leg_l = empty("LegL", (-0.4, 0, -0.15), hips)
    leg_r = empty("LegR", (0.4, 0, -0.15), hips)
    for lg in (leg_l, leg_r):
        prim("ico", "Perna", fur, (0, 0, -0.45), (0.6, 0.6, 0.9), parent=lg, sub=2)
        prim("sphere", "Pe", face, (0, 0.12, -0.9), (0.55, 0.7, 0.25), parent=lg, seg=10, rings=6)
    register(hips, head, arm_l, arm_r, leg_l, leg_r)
    idle = dict(length=40, joints={
        hips: dict(loc=cyc(40, 4, lambda t: (0, 0, 1.1 + 0.04 * math.sin(2 * PI * t)))),
        arm_l: dict(rot=cyc(40, 4, lambda t: (0.15 + 0.08 * math.sin(2 * PI * t), 0, 0))),
        arm_r: dict(rot=cyc(40, 4, lambda t: (0.15 + 0.08 * math.sin(2 * PI * t), 0, 0))),
    })
    walk = dict(length=28, joints={
        hips: dict(loc=cyc(28, 8, lambda t: (0, 0, 1.05 - 0.06 * math.cos(4 * PI * t))),
                   rot=cyc(28, 8, lambda t: (0, 0.1 * math.cos(2 * PI * t), 0))),
        leg_l: dict(rot=cyc(28, 8, lambda t: (0.45 * math.cos(2 * PI * t), 0, 0))),
        leg_r: dict(rot=cyc(28, 8, lambda t: (-0.45 * math.cos(2 * PI * t), 0, 0))),
        arm_l: dict(rot=cyc(28, 8, lambda t: (0.15 - 0.4 * math.cos(2 * PI * t), 0, 0))),
        arm_r: dict(rot=cyc(28, 8, lambda t: (0.15 + 0.4 * math.cos(2 * PI * t), 0, 0))),
    })
    atk = dict(length=18, joints={
        arm_l: dict(rot=[(1, (0.15, 0, 0)), (9, (2.9, 0, 0.2)), (12, (0.9, 0, 0)), (19, (0.15, 0, 0))]),
        arm_r: dict(rot=[(1, (0.15, 0, 0)), (9, (2.9, 0, -0.2)), (12, (0.9, 0, 0)), (19, (0.15, 0, 0))]),
        hips: dict(rot=[(1, (0, 0, 0)), (9, (-0.25, 0, 0)), (12, (0.3, 0, 0)), (19, (0, 0, 0))]),
    })
    write_anims({"idle": idle, "walk": walk, "attack": atk})
    export(name)


# =================================================================== diabrete

def build_imp(name, skin_c, wing_c, glow_c, crown=False):
    new_scene()
    skin = mat(name + "_pele", skin_c)
    wingm = mat(name + "_asa", wing_c)
    eyes = mat(name + "_olhos", glow_c, glow=5.0)
    horn = mat(name + "_chifre", (0.15, 0.1, 0.1))
    root = empty("Imp")
    body = empty("Body", (0, 0, 1.2), root)
    prim("sphere", "Corpo", skin, (0, 0, 0), (0.6, 0.5, 0.7), parent=body, seg=14, rings=8)
    prim("sphere", "Cabeca", skin, (0, 0.08, 0.55), (0.55, 0.5, 0.5), parent=body, seg=14, rings=8)
    for s in (-1, 1):
        prim("sphere", "Olho", eyes, (s * 0.12, 0.3, 0.6), (0.11, 0.06, 0.08), parent=body, seg=8, rings=5)
        prim("cone", "Chifre", horn, (s * 0.2, 0.0, 0.85), (0.12, 0.12, 0.32), rot=(-0.3, s * 0.4, 0), parent=body, seg=8)
        prim("cone", "Orelha", skin, (s * 0.3, 0.02, 0.6), (0.08, 0.12, 0.26), rot=(0, s * 1.2, 0), parent=body, seg=6)
    prim("box", "Sorriso", mat("boca_imp", (0.2, 0.02, 0.02)), (0, 0.32, 0.45), (0.2, 0.04, 0.04), parent=body)
    if crown:
        gold = mat(name + "_coroa", (1.0, 0.7, 0.2))
        prim("torus", "Coroa", gold, (0, 0.05, 0.82), (0.4, 0.4, 1.0), parent=body, minor=0.05)
    wings = []
    for s in (-1, 1):
        wg = empty("Wing", (s * 0.22, -0.25, 0.25), body)
        prim("box", "Membrana", wingm, (s * 0.45, -0.05, 0.1), (0.9, 0.04, 0.6), rot=(0, s * -0.3, 0), parent=wg, bevel=0.02)
        prim("cyl", "Osso", horn, (s * 0.45, -0.04, 0.38), (0.05, 0.05, 0.9), rot=(0, s * -1.3, 0), parent=wg, seg=6)
        wings.append(wg)
    for s in (-1, 1):
        prim("cone", "Garra", horn, (s * 0.35, 0.25, -0.15), (0.1, 0.1, 0.3), rot=(-1.0, 0, 0), parent=body, seg=6)
        prim("cyl", "Perna", skin, (s * 0.15, 0, -0.45), (0.12, 0.12, 0.35), parent=body, seg=6)
    tail = empty("Tail", (0, -0.3, -0.2), body, (-0.8, 0, 0))
    prim("cone", "Rabo", skin, (0, -0.4, 0), (0.12, 0.12, 0.8), rot=(PI / 2, 0, 0), r2=0.02, parent=tail, seg=6)
    prim("cone", "PontaRabo", horn, (0, -0.85, 0), (0.18, 0.06, 0.2), rot=(PI / 2, 0, 0), parent=tail, seg=4)
    register(body, tail, *wings)
    flap = lambda s: (lambda t: (0, 0, s * 0.6 * math.sin(2 * PI * t)))
    idle = dict(length=16, joints={
        body: dict(loc=cyc(16, 8, lambda t: (0, 0, 1.2 + 0.15 * math.sin(2 * PI * t)))),
        wings[0]: dict(rot=cyc(16, 8, flap(-1))),
        wings[1]: dict(rot=cyc(16, 8, flap(1))),
        tail: dict(rot=cyc(16, 4, lambda t: (-0.8, 0, 0.4 * math.sin(2 * PI * t)))),
    })
    walk = dict(length=12, joints={
        body: dict(loc=cyc(12, 6, lambda t: (0, 0, 1.25 + 0.1 * math.sin(2 * PI * t))), rot=cyc(12, 6, lambda t: (0.3, 0, 0))),
        wings[0]: dict(rot=cyc(12, 6, flap(-1.3))),
        wings[1]: dict(rot=cyc(12, 6, flap(1.3))),
    })
    atk = dict(length=12, joints={
        body: dict(loc=[(1, (0, 0, 1.2)), (5, (0, -0.4, 1.5)), (8, (0, 0.9, 0.9)), (13, (0, 0, 1.2))],
                   rot=[(1, (0, 0, 0)), (5, (-0.4, 0, 0)), (8, (0.6, 0, 0)), (13, (0, 0, 0))]),
        wings[0]: dict(rot=[(1, (0, 0, 0)), (5, (0, 0, 0.8)), (8, (0, 0, -0.6)), (13, (0, 0, 0))]),
        wings[1]: dict(rot=[(1, (0, 0, 0)), (5, (0, 0, -0.8)), (8, (0, 0, 0.6)), (13, (0, 0, 0))]),
    })
    write_anims({"idle": idle, "walk": walk, "attack": atk})
    export(name)


# =================================================================== dragão

def build_dragon(name, scale_c, belly_c, wing_c, horn_c, eye_c):
    new_scene()
    sc = mat(name + "_escamas", scale_c)
    belly = mat(name + "_barriga", belly_c)
    wingm = mat(name + "_asa", wing_c)
    horn = mat(name + "_chifre", horn_c)
    eyes = mat(name + "_olhos", eye_c, glow=5.0)
    fire = mat(name + "_fogo", (1.0, 0.5, 0.1), glow=4.0)
    root = empty("Dragon")
    body = empty("Body", (0, 0, 1.3), root)
    prim("sphere", "Tronco", sc, (0, 0, 0), (1.4, 2.4, 1.3), parent=body, seg=18, rings=10)
    prim("sphere", "Barriga", belly, (0, 0.1, -0.3), (1.1, 2.0, 0.8), parent=body, seg=16, rings=8)
    for k in range(5):
        prim("cone", f"Crista{k}", horn, (0, 0.8 - k * 0.45, 0.62), (0.18, 0.3, 0.4), rot=(-0.3, 0, 0), parent=body, seg=4)
    neck = empty("Neck", (0, 1.0, 0.4), body, (-0.7, 0, 0))
    prim("cyl", "Pescoco", sc, (0, 0, 0.55), (0.6, 0.6, 1.2), parent=neck, seg=12)
    head = empty("Head", (0, 0.1, 1.2), neck, (0.9, 0, 0))
    prim("sphere", "Cranio", sc, (0, 0.1, 0), (0.75, 0.9, 0.6), parent=head, seg=14, rings=8)
    prim("box", "Focinho", sc, (0, 0.62, -0.08), (0.5, 0.7, 0.32), parent=head, bevel=0.08)
    jaw = empty("Jaw", (0, 0.3, -0.22), head)
    prim("box", "Mandibula", belly, (0, 0.3, -0.04), (0.44, 0.65, 0.14), parent=jaw, bevel=0.05)
    for s in (-1, 1):
        prim("sphere", "Olho", eyes, (s * 0.25, 0.32, 0.15), (0.14, 0.1, 0.1), parent=head, seg=8, rings=5)
        prim("cone", "Chifre", horn, (s * 0.25, -0.25, 0.3), (0.18, 0.18, 0.7), rot=(-1.0, s * 0.3, 0), parent=head, seg=8)
        for k in range(3):
            prim("cone", "Dente", mat("dente_dragao", (0.95, 0.93, 0.85)), (s * 0.15, 0.6 + k * 0.12, -0.25), (0.06, 0.06, 0.12), rot=(PI, 0, 0), parent=head, seg=4)
    wings = []
    for s in (-1, 1):
        wg = empty("Wing", (s * 0.6, 0.3, 0.45), body)
        prim("cyl", "OssoAsa", horn, (s * 1.0, 0, 0.3), (0.12, 0.12, 2.1), rot=(0, s * -1.25, 0), parent=wg, seg=8)
        prim("box", "Membrana", wingm, (s * 1.1, -0.75, 0.05), (2.4, 1.7, 0.06), rot=(0.2, 0, s * 0.1), parent=wg, bevel=0.02)
        prim("cone", "Garra", horn, (s * 2.0, 0, 0.55), (0.12, 0.12, 0.3), parent=wg, seg=6)
        wings.append(wg)
    legs = []
    for nm, x, y in (("LegFL", -0.6, 0.8), ("LegFR", 0.6, 0.8), ("LegBL", -0.65, -0.8), ("LegBR", 0.65, -0.8)):
        lg = empty(nm, (x, y, -0.4), body)
        prim("cyl", "Perna", sc, (0, 0, -0.35), (0.42, 0.42, 0.8), parent=lg, seg=10)
        prim("sphere", "Pata", belly, (0, 0.12, -0.8), (0.5, 0.6, 0.25), parent=lg, seg=10, rings=6)
        legs.append(lg)
    tail = empty("Tail", (0, -1.2, 0.0), body, (0.3, 0, 0))
    t2 = tail
    for k in range(4):
        prim("cone", f"Cauda{k}", sc, (0, -0.45, 0), (0.6 - k * 0.12, 0.6 - k * 0.12, 0.95), rot=(PI / 2, 0, 0), r2=0.35, parent=t2, seg=10)
        t2 = empty(f"Tail{k}", (0, -0.85, 0), t2, (0.05, 0, 0))
    prim("cone", "PontaCauda", horn, (0, -0.3, 0), (0.5, 0.15, 0.6), rot=(PI / 2, 0, 0), parent=t2, seg=4)
    flame = empty("Flame", (0, 1.0, -0.1), head)
    prim("cone", "Chama", fire, (0, 0.6, 0), (0.6, 0.6, 1.4), rot=(-PI / 2, 0, 0), r2=0.0, parent=flame, seg=10)
    flame.scale = (0.01, 0.01, 0.01)
    register(body, neck, head, jaw, tail, flame, *wings, *legs)
    fl, fr, bl, br = legs
    flap = lambda s, a: (lambda t: (0, s * a * math.sin(2 * PI * t), 0))
    idle = dict(length=40, joints={
        body: dict(loc=cyc(40, 4, lambda t: (0, 0, 1.3 + 0.05 * math.sin(2 * PI * t)))),
        neck: dict(rot=cyc(40, 4, lambda t: (-0.7 + 0.08 * math.sin(2 * PI * t), 0, 0))),
        wings[0]: dict(rot=cyc(40, 8, flap(1, 0.25))),
        wings[1]: dict(rot=cyc(40, 8, flap(-1, 0.25))),
        tail: dict(rot=cyc(40, 4, lambda t: (0.3, 0, 0.25 * math.sin(2 * PI * t)))),
    })
    walk = dict(length=28, joints={
        body: dict(loc=cyc(28, 8, lambda t: (0, 0, 1.25 + 0.06 * abs(math.sin(2 * PI * t))))),
        fl: dict(rot=cyc(28, 8, lambda t: (0.45 * math.sin(2 * PI * t), 0, 0))),
        br: dict(rot=cyc(28, 8, lambda t: (0.45 * math.sin(2 * PI * t), 0, 0))),
        fr: dict(rot=cyc(28, 8, lambda t: (-0.45 * math.sin(2 * PI * t), 0, 0))),
        bl: dict(rot=cyc(28, 8, lambda t: (-0.45 * math.sin(2 * PI * t), 0, 0))),
        wings[0]: dict(rot=cyc(28, 8, flap(1, 0.15))),
        wings[1]: dict(rot=cyc(28, 8, flap(-1, 0.15))),
        tail: dict(rot=cyc(28, 8, lambda t: (0.3, 0, 0.35 * math.sin(2 * PI * t)))),
    })
    atk = dict(length=22, joints={
        neck: dict(rot=[(1, (-0.7, 0, 0)), (8, (-0.2, 0, 0)), (12, (-1.1, 0, 0)), (23, (-0.7, 0, 0))]),
        jaw: dict(rot=[(1, (0, 0, 0)), (10, (0.6, 0, 0)), (18, (0.6, 0, 0)), (23, (0, 0, 0))]),
        flame: dict(scl=[(1, (0.01, 0.01, 0.01)), (11, (0.01, 0.01, 0.01)), (13, (1.2, 1.2, 1.6)), (18, (1.0, 1.0, 1.3)), (21, (0.01, 0.01, 0.01)), (23, (0.01, 0.01, 0.01))]),
        wings[0]: dict(rot=[(1, (0, 0, 0)), (8, (0, 0.6, 0)), (12, (0, -0.4, 0)), (23, (0, 0, 0))]),
        wings[1]: dict(rot=[(1, (0, 0, 0)), (8, (0, -0.6, 0)), (12, (0, 0.4, 0)), (23, (0, 0, 0))]),
        body: dict(loc=[(1, (0, 0, 1.3)), (8, (0, -0.3, 1.5)), (12, (0, 0.4, 1.25)), (23, (0, 0, 1.3))]),
    })
    write_anims({"idle": idle, "walk": walk, "attack": atk})
    export(name)


# =================================================================== cenário

def build_cactus(name, seed):
    new_scene()
    rng = random.Random(seed)
    g = mat("cacto", (0.3, 0.5, 0.28))
    g2 = mat("cacto_claro", (0.42, 0.6, 0.32))
    flower = mat("cacto_flor", (1.0, 0.4, 0.55))
    h = rng.uniform(2.2, 3.0)
    prim("cyl", "Tronco", g, (0, 0, h / 2), (0.6, 0.6, h), seg=10, bevel=0.1)
    prim("sphere", "Topo", g, (0, 0, h), (0.6, 0.6, 0.5), seg=10, rings=6)
    for s in (-1, 1):
        if rng.random() < 0.8:
            z = rng.uniform(0.9, h * 0.7)
            ah = rng.uniform(0.6, 1.1)
            prim("cyl", "BracoH", g2, (s * 0.45, 0, z), (0.36, 0.36, 0.6), rot=(0, PI / 2, 0), seg=8)
            prim("cyl", "BracoV", g2, (s * 0.75, 0, z + ah / 2), (0.36, 0.36, ah), seg=8, bevel=0.08)
            prim("sphere", "BracoTopo", g2, (s * 0.75, 0, z + ah), (0.36, 0.36, 0.3), seg=8, rings=5)
    prim("sphere", "Flor", flower, (0.1, 0.1, h + 0.25), (0.25, 0.25, 0.15), seg=8, rings=5)
    export_static(name)


def build_palm():
    new_scene()
    bark = mat("palmeira_tronco", (0.45, 0.33, 0.2))
    leaf = mat("palmeira_folha", (0.25, 0.55, 0.25))
    leaf2 = mat("palmeira_folha2", (0.35, 0.65, 0.28))
    for k in range(7):
        prim("cyl", f"Seg{k}", bark, (k * 0.08, 0, 0.35 + k * 0.6), (0.42 - k * 0.025, 0.42 - k * 0.025, 0.62), rot=(0, 0.08, 0), seg=8, bevel=0.04)
    top = (0.56, 0, 4.4)
    for k in range(7):
        a = k * math.tau / 7
        prim("box", f"Folha{k}", leaf if k % 2 else leaf2, (top[0] + math.cos(a) * 1.1, math.sin(a) * 1.1, top[2] - 0.2), (2.4, 0.5, 0.05), rot=(0.0, 0.45, a), bevel=0.02)
    for k in range(3):
        prim("sphere", f"Coco{k}", mat("coco", (0.35, 0.22, 0.12)), (top[0] + math.cos(k * 2.1) * 0.25, math.sin(k * 2.1) * 0.25, top[2] - 0.35), (0.25, 0.25, 0.25), seg=8, rings=5)
    export_static("palm")


def build_dead_tree(name, bark_c, glow_c=None):
    new_scene()
    rng = random.Random(len(name))
    bark = mat(name + "_casca", bark_c)
    prim("cone", "Tronco", bark, (0, 0, 1.4), (0.8, 0.8, 2.8), r2=0.18, seg=8)
    for k in range(5):
        a = k * math.tau / 5 + rng.uniform(-0.3, 0.3)
        z = rng.uniform(1.6, 2.6)
        prim("cone", f"Galho{k}", bark, (math.cos(a) * 0.45, math.sin(a) * 0.45, z + 0.45), (0.22, 0.22, 1.5), rot=(math.sin(a) * 0.9, -math.cos(a) * 0.9, 0), r2=0.02, seg=6)
    if glow_c:
        g = mat(name + "_brasa", glow_c, glow=3.0)
        for k in range(4):
            prim("box", f"Brasa{k}", g, (0, 0.33 - k * 0.02, 0.5 + k * 0.5), (0.06, 0.03, 0.3), rot=(0, 0.3 * k, 0))
    export_static(name)


def build_pine_snow():
    new_scene()
    bark = mat("casca", (0.26, 0.17, 0.11))
    dark = mat("pinho_frio", (0.1, 0.24, 0.24))
    snow = mat("neve", (0.92, 0.95, 1.0))
    prim("cyl", "Tronco", bark, (0, 0, 0.8), (0.42, 0.42, 1.6), seg=8)
    z = 1.2
    for i in range(4):
        r = 3.2 - i * 0.65
        o = prim("cone", f"Camada{i}", dark, (0, 0, z + 0.9), (r, r, 2.2), r2=0.0, seg=9)
        jitter(o, 0.05, 11 + i)
        o2 = prim("cone", f"Neve{i}", snow, (0, 0, z + 1.35), (r * 0.62, r * 0.62, 1.2), r2=0.0, seg=9)
        jitter(o2, 0.04, 21 + i)
        z += 1.15
    export_static("pine_snow")


def build_crystal(name, col, n=5):
    new_scene()
    rng = random.Random(n + len(name))
    g = mat(name + "_cristal", col, glow=3.0)
    base = mat(name + "_base", (0.25, 0.25, 0.3))
    prim("ico", "Base", base, (0, 0, 0.15), (1.4, 1.2, 0.5), sub=1)
    for k in range(n):
        a = k * math.tau / n + rng.uniform(-0.3, 0.3)
        h = rng.uniform(1.0, 2.2)
        r = 0.6 if k else 0.0
        prim("cone", f"Cristal{k}", g, (math.cos(a) * r * 0.5, math.sin(a) * r * 0.5, h / 2 + 0.1), (0.4, 0.4, h), rot=(math.sin(a) * 0.4 * (r > 0), -math.cos(a) * 0.4 * (r > 0), 0), r2=0.0, seg=6)
    export_static(name)


def build_tent():
    new_scene()
    cloth = mat("tenda", (0.75, 0.32, 0.22))
    cloth2 = mat("tenda2", (0.9, 0.78, 0.55))
    pole = mat("tenda_poste", (0.35, 0.22, 0.12))
    glowm = mat("tenda_luz", (1.0, 0.7, 0.35), glow=3.0)
    prim("cone", "Tenda", cloth, (0, 0, 1.5), (5.0, 5.0, 3.0), r2=0.0, seg=8, bevel=0.03)
    prim("cone", "Faixa", cloth2, (0, 0, 0.5), (5.1, 5.1, 1.0), r2=0.335, seg=8)
    prim("cyl", "Mastro", pole, (0, 0, 3.3), (0.14, 0.14, 1.2), seg=6)
    prim("box", "Bandeira", mat("bandeira", (0.9, 0.2, 0.15)), (0.35, 0, 3.7), (0.6, 0.04, 0.35))
    prim("box", "Entrada", glowm, (0, 2.12, 0.75), (1.0, 0.1, 1.4))
    export_static("tent")


def build_portal():
    new_scene()
    stone = mat("portal_pedra", (0.32, 0.32, 0.38))
    gold = mat("portal_ouro", (0.85, 0.65, 0.25))
    glow = mat("portal_brilho", (0.45, 0.85, 1.0), glow=4.0)
    prim("cyl", "Base", stone, (0, 0, 0.2), (4.2, 4.2, 0.4), seg=20, bevel=0.06)
    prim("cyl", "Degrau", stone, (0, 0, 0.5), (3.4, 3.4, 0.25), seg=20, bevel=0.05)
    prim("torus", "Anel", stone, (0, 0, 2.6), (3.6, 3.6, 3.6), rot=(PI / 2, 0, 0), minor=0.1)
    prim("torus", "AnelOuro", gold, (0, 0, 2.6), (3.3, 3.3, 3.3), rot=(PI / 2, 0, 0), minor=0.05)
    prim("cyl", "Espelho", glow, (0, 0, 2.6), (2.9, 2.9, 0.05), rot=(PI / 2, 0, 0), seg=24)
    for s in (-1, 1):
        prim("box", "Pilar", stone, (s * 1.95, 0, 1.2), (0.5, 0.6, 2.0), bevel=0.05)
        prim("sphere", "Gema", glow, (s * 1.95, 0.32, 1.9), (0.22, 0.12, 0.22), seg=8, rings=5)
    export_static("portal")


def build_board():
    new_scene()
    wood = mat("quadro_madeira", (0.4, 0.26, 0.14))
    paper = mat("quadro_papel", (0.92, 0.86, 0.7))
    red = mat("quadro_selo", (0.8, 0.15, 0.12))
    for s in (-1, 1):
        prim("box", "Poste", wood, (s * 1.3, 0, 1.3), (0.22, 0.22, 2.6), smooth=False)
    prim("box", "Painel", wood, (0, 0, 1.75), (2.8, 0.15, 1.6), bevel=0.04)
    prim("box", "Telhado", mat("quadro_telhado", (0.5, 0.18, 0.14)), (0, 0, 2.75), (3.2, 0.8, 0.14), rot=(0.25, 0, 0), bevel=0.03)
    for k, (x, z) in enumerate([(-0.85, 2.0), (-0.2, 1.75), (0.55, 2.05), (0.95, 1.5), (-0.7, 1.35)]):
        prim("box", f"Papel{k}", paper, (x, 0.09, z), (0.5, 0.02, 0.6), rot=(0, (k - 2) * 0.06, 0))
        prim("sphere", f"Selo{k}", red, (x, 0.11, z + 0.22), (0.08, 0.03, 0.08), seg=8, rings=5)
    export_static("board")


def build_bones():
    new_scene()
    bone = mat("osso", (0.88, 0.84, 0.72))
    prim("sphere", "Cranio", bone, (0, 0, 0.3), (0.6, 0.65, 0.5), seg=12, rings=8)
    prim("sphere", "Olho1", mat("escuro", DARK), (-0.12, 0.26, 0.32), (0.14, 0.08, 0.14), seg=8, rings=5)
    prim("sphere", "Olho2", mat("escuro", DARK), (0.12, 0.26, 0.32), (0.14, 0.08, 0.14), seg=8, rings=5)
    for k in range(4):
        prim("cyl", f"Osso{k}", bone, (0.6 + k * 0.1, -0.3 + k * 0.25, 0.08), (0.12, 0.12, 0.9), rot=(PI / 2, 0, k * 0.7), seg=6)
    for k in range(3):
        prim("torus", f"Costela{k}", bone, (-0.7, -0.2 + k * 0.2, 0.2), (0.6, 0.4, 1.0), rot=(PI / 2, 0, 0), minor=0.04)
    export_static("bones")


def main():
    # monstros e chefes
    build_scorpion("scorpion", (0.72, 0.36, 0.18), (0.45, 0.2, 0.12), (1.0, 0.85, 0.3))
    build_scorpion("scorpion_queen", (0.55, 0.12, 0.18), (0.25, 0.06, 0.1), (0.4, 1.0, 0.5), 1.2)
    build_skeleton("skeleton", (0.88, 0.84, 0.72), (0.4, 0.38, 0.36), (0.3, 1.0, 0.6))
    build_skeleton("skeleton_king", (0.9, 0.86, 0.75), (0.3, 0.2, 0.35), (1.0, 0.3, 0.3), crown=True)
    build_golem("golem_sand", (0.68, 0.52, 0.34), (0.82, 0.66, 0.44), (0.3, 0.9, 1.0), (0.55, 0.4, 0.25))
    build_wolf("wolf_ice", (0.8, 0.86, 0.92), (0.95, 0.97, 1.0), (0.4, 0.85, 1.0))
    build_wolf("wolf_glacial", (0.4, 0.55, 0.75), (0.75, 0.85, 0.95), (0.3, 1.0, 1.0))
    build_yeti("yeti", (0.88, 0.9, 0.95), (0.55, 0.65, 0.8), (0.75, 0.7, 0.6))
    build_yeti("yeti_ancient", (0.55, 0.65, 0.8), (0.3, 0.35, 0.55), (0.9, 0.85, 0.7))
    build_golem("golem_ice", (0.55, 0.72, 0.85), (0.75, 0.88, 0.95), (0.4, 0.9, 1.0), (0.85, 0.92, 1.0))
    build_imp("imp", (0.8, 0.2, 0.15), (0.35, 0.08, 0.08), (1.0, 0.85, 0.2))
    build_imp("imp_lord", (0.35, 0.08, 0.3), (0.15, 0.02, 0.1), (1.0, 0.3, 0.2), crown=True)
    build_golem("golem_magma", (0.18, 0.12, 0.12), (0.3, 0.2, 0.18), (1.0, 0.45, 0.08), (1.0, 0.35, 0.05))
    build_dragon("dragon_whelp", (0.75, 0.25, 0.12), (0.95, 0.75, 0.45), (0.55, 0.12, 0.08), (0.25, 0.18, 0.15), (1.0, 0.9, 0.3))
    build_dragon("dragon_ancient", (0.12, 0.08, 0.1), (0.5, 0.15, 0.1), (0.35, 0.05, 0.05), (0.95, 0.75, 0.3), (1.0, 0.3, 0.1))
    # NPCs de cada mapa
    build_hero("npc", dict(cloth=(0.85, 0.55, 0.25), trim=(0.3, 0.75, 0.8), head="hood", kind="magic", robe=True, beard=False), out="npc_desert")
    build_hero("npc", dict(cloth=(0.35, 0.55, 0.75), trim=(0.95, 0.95, 1.0), head="hood", kind="magic", robe=True, beard=True), out="npc_ice")
    build_hero("npc", dict(cloth=(0.25, 0.12, 0.1), trim=(1.0, 0.5, 0.15), head="helm", kind="melee", robe=False, beard=True), out="npc_volcano")
    # cenário
    build_cactus("cactus_a", 1)
    build_cactus("cactus_b", 4)
    build_palm()
    build_dead_tree("dead_tree", (0.35, 0.28, 0.24))
    build_dead_tree("dead_tree_frost", (0.55, 0.6, 0.68))
    build_dead_tree("dead_tree_burnt", (0.12, 0.09, 0.08), (1.0, 0.4, 0.08))
    build_pine_snow()
    build_crystal("ice_crystal", (0.55, 0.9, 1.0))
    build_crystal("fire_crystal", (1.0, 0.35, 0.12))
    build_crystal("sand_crystal", (0.4, 1.0, 0.85), 3)
    build_tent()
    build_portal()
    build_board()
    build_bones()
    build_house("house_snow", (0.6, 0.48, 0.38), (0.92, 0.95, 1.0), 6.0, 3)
    build_house("house_dark", (0.25, 0.2, 0.22), (0.35, 0.12, 0.1), 6.5, 4)


if __name__ == "__main__":
    main()
