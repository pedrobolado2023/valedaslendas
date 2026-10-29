"""
Náutico humanizado (MPFB2) nas 4 raridades: Comum, Rara, Épica e Lendária.
Mesmo processo das outras classes (reaproveita make_druid_mpfb.py, make_assassin_mpfb.py e make_mechanic_mpfb.py).
Rode:  MH_DATA=<makehuman/data> python blender/make_nautical_mpfb.py [pasta_de_previas]
Saída: models/hero_nautico_<raridade>.glb
  - nó "Weapon" na mão direita: o arpão / tridente de make_heroes.py (weapon_nautico_<raridade>.glb) encaixa nele
    e aponta para -Z (para frente e um pouco para baixo, pronto para a estocada, como no modelo antigo).
"""
import math
import os
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mpfb_kit as K  # noqa: E402
import skill_anims as SA  # noqa: E402
import make_druid_mpfb as D  # noqa: E402
import make_assassin_mpfb as A  # noqa: E402
import make_mechanic_mpfb as Mc  # noqa: E402

OUT = D.OUT
PREVIEW = D.PREVIEW
K.MH_DATA = os.environ.get("MH_DATA", K.MH_DATA)

GOLD = (1.0, 0.74, 0.22)
GOLD2 = (0.86, 0.58, 0.14)
WHITE = (0.96, 0.96, 0.94)
TRIDENT_SCALE = 0.55 / K.HERO_SCALE      # tridente com ~1,9 de comprimento no jogo
TRIDENT_DIR = Vector((0, -1, -0.22))     # frente (-Y) e um pouco para baixo

# marinheiro corpulento, ombros largos, um pouco mais velho
MACROS = {"gender": 1.0, "age": 0.62, "muscle": 0.62, "weight": 0.58, "proportions": 0.9, "height": 0.58}
TARGETS = {"neck/neck-scale-horiz-incr": 0.2}
for _ax in ("vert", "horiz", "depth"):
    TARGETS[f"head/head-scale-{_ax}-incr"] = 0.25
for _s in ("l", "r"):
    TARGETS[f"eyes/{_s}-eye-scale-incr"] = 0.4

TORSO, UPPER, LOWER, LEGS, FEET = D.TORSO, D.UPPER, D.LOWER, D.LEGS, D.FEET
X, Y, Z = D.X, D.Y, D.Z
piece, rigid, prim, belt = D.piece, D.rigid, D.prim, D.belt


def base():
    c = A.base(MACROS, TARGETS, "nautico", (0.86, 0.63, 0.48))
    c.after = []
    return c


# =================================================================== peças do náutico

def beard(c, mat):
    """Barba cheia: a parte de baixo do rosto do próprio corpo, inflada."""
    s = (c.head_top - c.head).length
    cy, rx, ry = Mc.head_ring(c, c.eye_z - s * 0.3)
    o = K.duplicate(c.body, "Barba")
    K.region(o, ["head", "neck_01"], 0.3, zmin=K.bone_head(c.arm, "neck_01").z,
             keep_fn=lambda p: p.z < c.eye_z - s * 0.28 and p.y < cy + ry * 0.25)
    K.finish_piece(o, mat, 0.01 / c.sc, 2, 0.02 / c.sc, smooth=6)
    c.parts.append(o)
    mus = prim("sphere", "Bigode", mat, Vector((0, cy - ry - 0.012, c.eye_z - s * 0.27)), (0.09, 0.03, 0.025), rot=(0.1, 0, 0))
    rigid(c, mus, "head")
    for side in (-1, 1):   # sobrancelhas grossas
        br = prim("sphere", "Sobrancelha", mat, Vector((side * rx * 0.42, cy - ry - 0.006, c.eye_z + s * 0.2)), (0.045, 0.014, 0.014), rot=(0, side * 0.15, 0))
        rigid(c, br, "head")


def stripes(c, mat, n=4):
    """Listras azuis em volta do tronco (camisa de marinheiro)."""
    z0 = c.hip_z + 0.12
    z1 = K.bone_head(c.arm, "spine_03").z + 0.04
    for k in range(n):
        z = z0 + (z1 - z0) * k / (n - 1)
        cy, rx, ry = Mc.torso_size(c, z)
        st = prim("torus", "Listra", mat, Vector((0, cy, z)), (2 * rx + 0.008, 2 * ry + 0.008, 0.22), minor=0.05)
        bone = "spine_01" if k == 0 else ("spine_02" if k < n - 1 else "spine_03")
        rigid(c, st, bone)


def sea_helm(c, mat, fin):
    """Capacete de marinheiro arredondado com barbatana no topo."""
    s = (c.head_top - c.head).length
    D.head_shell(c, "Elmo", mat, 0.026, lambda p: p.z > c.eye_z + s * 0.22, 0.012)
    f = prim("sphere", "Barbatana", fin, c.head_top + Vector((0, s * 0.1, s * 0.05)), (0.025, 0.2, 0.12), rot=(-0.25, 0, 0))
    rigid(c, f, "head")


def crest(c, mats, n=5, spread=0.3, tall=0.22, name="Coral"):
    """Leque de pontas no topo do capacete (coral na Épica, coroa de tridente na Lendária)."""
    s = (c.head_top - c.head).length
    for k in range(n):
        a = (k - n // 2) * spread
        h = tall - abs(k - n // 2) * tall * 0.18
        p = c.head_top + Vector((math.sin(a) * s * 0.45, s * 0.05, -s * 0.12 + h * 0.4))
        cn = prim("cone", name, mats[k % len(mats)], p, (0.035, 0.035, h), rot=(0, a * 0.8, 0), seg=5)
        rigid(c, cn, "head")


# =================================================================== raridades

def comum(c):
    shirt = K.color_mat("nautico_camisa", WHITE, rough=0.85)
    navy = K.color_mat("nautico_listra", (0.12, 0.16, 0.32), rough=0.85)
    pants = K.color_mat("nautico_calca", (0.14, 0.15, 0.22), rough=0.85)
    boot = K.color_mat("nautico_bota", (0.25, 0.16, 0.1), rough=0.8)
    hair = K.color_mat("nautico_barba", (0.2, 0.13, 0.08), rough=0.8)
    cap = K.color_mat("nautico_gorro", (0.1, 0.1, 0.12), rough=0.8)
    piece(c, c.tights, "Camisa", TORSO + UPPER + LOWER, shirt, offset=0.008, zmin=c.hip_z - 0.04,
          keep_fn=lambda p: p.z > c.elbow_z - 0.08 or abs(p.x) < 0.2)
    piece(c, c.tights, "Calca", ["pelvis"] + LEGS, pants, offset=0.006, zmin=c.ankle_z + 0.08)
    piece(c, c.tights, "Bota", ["calf_l", "calf_r"] + FEET, boot, offset=0.014, thresh=0.3, zmax=c.knee_z - 0.08)
    stripes(c, navy)
    beard(c, hair)
    Mc.short_hair(c, hair)
    Mc.cap(c, cap)
    belt(c, K.color_mat("nautico_corda", (0.75, 0.68, 0.5), rough=0.9), c.hip_z + 0.06)


def rara(c):
    shirt = K.color_mat("nautico_camisa2", (0.85, 0.85, 0.82), rough=0.85)
    vest = K.color_mat("nautico_colete", (0.15, 0.35, 0.6), rough=0.7)
    pants = K.color_mat("nautico_calca2", (0.25, 0.3, 0.42), rough=0.85)
    boot = K.color_mat("nautico_bota2", (0.25, 0.16, 0.1), rough=0.8)
    glove = K.color_mat("nautico_luva", (0.3, 0.2, 0.12), rough=0.8)
    grey = K.color_mat("nautico_barba_cinza", (0.55, 0.52, 0.5), rough=0.8)
    helm = K.color_mat("nautico_elmo", (0.25, 0.4, 0.6), metal=0.4, rough=0.45)
    fin = K.color_mat("nautico_barbatana", (0.35, 0.7, 0.9), rough=0.5)
    gold = K.color_mat("nautico_ouro_bussola", GOLD, metal=0.9, rough=0.3)
    piece(c, c.tights, "Camisa", TORSO + UPPER + LOWER, shirt, offset=0.008, zmin=c.hip_z - 0.04)
    piece(c, c.tights, "Colete", ["pelvis", "spine_01", "spine_02", "spine_03"], vest, offset=0.02, thresh=0.2, zmin=c.hip_z - 0.02,
          zmax=K.bone_head(c.arm, "neck_01").z - 0.04, keep_fn=lambda p: abs(p.x) < 0.2)
    piece(c, c.tights, "Calca", ["pelvis"] + LEGS, pants, offset=0.006, zmin=c.ankle_z + 0.08)
    piece(c, c.tights, "Bota", ["calf_l", "calf_r"] + FEET, boot, offset=0.014, thresh=0.3, zmax=c.knee_z - 0.04)
    Mc.gloves(c, glove)
    beard(c, grey)
    sea_helm(c, helm, fin)
    rx, ry = belt(c, K.color_mat("nautico_couro", (0.3, 0.2, 0.12)), c.hip_z + 0.06, buckle=gold)
    comp = prim("cyl", "Bussola", gold, Vector((rx * 0.75, c.head.y - ry - 0.01, c.hip_z + 0.04)), (0.07, 0.07, 0.02), rot=(math.pi / 2, 0, 0), seg=14)
    rigid(c, comp, "spine_01")
    face = prim("cyl", "BussolaVidro", K.color_mat("nautico_vidro", (0.75, 0.9, 1.0), glow=1.5),
                Vector((rx * 0.75, c.head.y - ry - 0.021, c.hip_z + 0.04)), (0.055, 0.055, 0.004), rot=(math.pi / 2, 0, 0), seg=14)
    rigid(c, face, "spine_01")


def epica(c):
    armor = K.color_mat("nautico_abismo", (0.1, 0.1, 0.16), metal=0.5, rough=0.45)
    suit = K.color_mat("nautico_traje", (0.08, 0.08, 0.12), rough=0.65)
    glow = K.color_mat("nautico_brilho", (0.7, 0.4, 1.0), glow=5.0)
    piece(c, c.tights, "Traje", TORSO + UPPER + LOWER + ["pelvis"] + LEGS, suit, offset=0.005, zmin=c.ankle_z + 0.05)
    piece(c, c.tights, "Peitoral", ["spine_02", "spine_03"], armor, offset=0.02, thresh=0.5)
    piece(c, c.tights, "Bota", ["calf_l", "calf_r"] + FEET, armor, offset=0.016, thresh=0.3, zmax=c.knee_z + 0.02)
    piece(c, c.tights, "Bracadeira", LOWER, armor, offset=0.016, thresh=0.5, zmax=c.elbow_z - 0.04)
    Mc.gloves(c, armor, 0.012)
    A.helmet(c, armor, glow)
    crest(c, [armor, glow], 5, 0.35, 0.26, "Coral")
    A.pauldrons(c, armor, armor, spikes=glow, size=0.15, gem=glow)
    gem = prim("sphere", "GemaPeito", glow, K.bone_head(c.arm, "spine_03") + Vector((0, -0.15, 0.02)), (0.045, 0.02, 0.045))
    rigid(c, gem, "spine_03")
    belt(c, armor, c.hip_z + 0.06, buckle=glow)
    D.cape(c, K.color_mat("nautico_capa_abismo", (0.12, 0.08, 0.2), rough=0.8), 1.05, 0.46)


def lendaria(c):
    gold = K.color_mat("nautico_ouro", GOLD, metal=0.9, rough=0.3)
    gold2 = K.color_mat("nautico_ouro2", GOLD2, metal=0.9, rough=0.35)
    sapphire = K.color_mat("nautico_safira", (0.25, 0.5, 1.0), glow=3.0)
    dark = K.color_mat("nautico_visor", (0.06, 0.05, 0.05), rough=0.4)
    piece(c, c.tights, "Traje", TORSO + UPPER + LOWER + ["pelvis"] + LEGS, gold2, offset=0.005, zmin=c.ankle_z + 0.05)
    piece(c, c.tights, "Peitoral", ["spine_01", "spine_02", "spine_03"], gold, offset=0.022, thresh=0.5)
    piece(c, c.tights, "Bota", ["calf_l", "calf_r"] + FEET, gold, offset=0.018, thresh=0.3, zmax=c.knee_z + 0.03)
    piece(c, c.tights, "Bracadeira", LOWER, gold, offset=0.016, thresh=0.5, zmax=c.elbow_z - 0.04)
    Mc.gloves(c, gold, 0.012)
    A.helmet(c, gold, dark)
    s = (c.head_top - c.head).length
    cy, rx, ry = Mc.head_ring(c, c.eye_z + s * 0.3)
    jewel = prim("sphere", "Joia", sapphire, Vector((0, cy - ry - 0.03, c.eye_z + s * 0.32)), (0.045, 0.025, 0.045))
    rigid(c, jewel, "head")
    crest(c, [gold], 5, 0.3, 0.2, "Coroa")
    A.pauldrons(c, gold, gold2, size=0.16, gem=sapphire)
    gem = prim("sphere", "GemaPeito", sapphire, K.bone_head(c.arm, "spine_03") + Vector((0, -0.16, 0.02)), (0.05, 0.024, 0.05))
    rigid(c, gem, "spine_03")
    belt(c, gold2, c.hip_z + 0.06, buckle=sapphire)
    D.cape(c, K.color_mat("nautico_capa_mar", (0.12, 0.3, 0.6), rough=0.6), 1.15, 0.5, gold)


# =================================================================== postura e animações
# Mesmas regras de sinal da Druida: braço/perna para frente = -X; joelho dobra = +X; tronco para frente = +X.

def build_base_pose(c):
    """Base firme, pés afastados, tridente na direita apontado para frente; esquerda solta, meio fechada."""
    pose = {
        "pelvis": [(Z, 0.08)],
        "spine_01": [(X, 0.03), (Z, -0.04)], "spine_03": [(Z, -0.04)],
        "neck_01": [(X, 0.02)], "head": [(Z, 0.1)],
        "clavicle_l": [(Y, 0.04)], "clavicle_r": [(Y, -0.03)],
        "upperarm_l": [(Y, 0.72), (X, -0.08)], "lowerarm_l": [(X, -0.4)],
        "upperarm_r": [(Y, -0.62), (X, 0.05)], "lowerarm_r": [(X, -0.75)],
        "thigh_l": [(X, -0.12), (Y, 0.1)], "calf_l": [(X, 0.1)], "foot_l": [(X, 0.02)],
        "thigh_r": [(X, 0.08), (Y, -0.1)], "calf_r": [(X, 0.08)], "foot_r": [(X, -0.16)],
    }
    for b, ops in D.fist("r", 1.0).items():
        pose.setdefault(b, []).extend(ops)
    for b, ops in D.fist("l", 0.6).items():
        pose.setdefault(b, []).extend(ops)
    Mc.align_wrist(c, pose, "r", TRIDENT_DIR)
    return pose


def anims(c):
    base_pose = build_base_pose(c)
    sin, cos, tau = math.sin, math.cos, math.tau

    def ease(x):
        x = min(max(x, 0.0), 1.0)
        return x * x * (3 - 2 * x)

    def legs(p, swing, knee, lift):
        """Ciclo de pernas; desfaz a base afastada (pose parada) para o passo ficar reto."""
        out = {}
        for side, ph in (("l", 0.0), ("r", math.pi)):
            s, c_ = sin(p + ph), cos(p + ph)
            thigh = -swing * s
            calf = 0.08 + knee * max(0.0, c_) ** 2
            foot = -(thigh + calf) * 0.85 + lift * max(0.0, -s) * max(0.0, -c_)
            undo = base_pose[f"thigh_{side}"]
            out[f"thigh_{side}"] = [(ax, -a) for ax, a in undo] + [(X, thigh)]
            out[f"calf_{side}"] = [(X, calf - base_pose[f"calf_{side}"][0][1])]
            out[f"foot_{side}"] = [(X, foot - base_pose[f"foot_{side}"][0][1])]
            out[f"ball_{side}"] = [(X, -0.35 * max(0.0, -s) * max(0.0, -c_))]
        return out

    def idle(t):
        # balanço de quem está no convés
        b = sin(t * tau)
        b2 = sin(t * tau * 2 + 0.6)
        return {"spine_02": [(X, -0.012 * b), (Y, 0.015 * b)], "spine_03": [(X, -0.02 * b), (Y, 0.02 * b)],
                "clavicle_l": [(Y, 0.015 * b)], "clavicle_r": [(Y, -0.015 * b)],
                "upperarm_l": [(Y, 0.02 * b)], "lowerarm_l": [(X, -0.04 * b)],
                "upperarm_r": [(X, 0.03 * b2)], "lowerarm_r": [(X, -0.04 * b)],
                "head": [(Z, 0.06 * sin(t * tau + 1.2)), (X, 0.015 * b)],
                "pelvis": [(Y, 0.02 * b)],
                "_loc": Vector((0.01 * b, 0, -0.006 * (1 - cos(t * tau))))}

    def walk(t):
        p = t * tau
        s = sin(p)
        o = legs(p, 0.42, 1.0, 0.42)
        o.update({"pelvis": [(Z, -0.08 - 0.09 * s), (Y, 0.04 * cos(2 * p))],
                  "spine_01": [(Z, 0.04 + 0.05 * s), (X, 0.03)], "spine_03": [(Z, 0.04 + 0.07 * s)],
                  "neck_01": [(Z, -0.05 * s)], "head": [(Z, -0.1 - 0.04 * s)],
                  "upperarm_l": [(X, 0.32 * s)], "lowerarm_l": [(X, -0.15 * max(0.0, -s))],
                  "upperarm_r": [(X, 0.1 * s)], "lowerarm_r": [(X, -0.04 * s)]})
        o["_loc"] = Vector((0.014 * s, 0, -0.03 + 0.022 * cos(2 * p)))
        return o

    def run(t):
        p = t * tau
        s = sin(p)
        o = legs(p, 0.7, 1.65, 0.65)
        o.update({"pelvis": [(Z, -0.08 - 0.12 * s), (X, 0.08)],
                  "spine_01": [(Z, 0.04 + 0.08 * s), (X, 0.12)], "spine_03": [(Z, 0.04 + 0.1 * s), (X, 0.06)],
                  "neck_01": [(X, -0.12), (Z, -0.08 * s)], "head": [(X, -0.06), (Z, -0.1)],
                  "upperarm_l": [(X, 0.7 * s), (Y, -0.15)], "lowerarm_l": [(X, -0.85 - 0.25 * max(0.0, -s))],
                  "upperarm_r": [(X, 0.3 * s)], "lowerarm_r": [(X, -0.15)]})
        o["_loc"] = Vector((0.016 * s, 0, -0.06 + 0.05 * abs(cos(p))))
        return o

    def attack(t):
        # estocada: puxa o tridente para trás (0-0,35), avança com tudo (0,35-0,5) e volta
        back = ease(t / 0.35) * (1 - ease((t - 0.35) / 0.12))
        hit = ease((t - 0.33) / 0.15) * (1 - ease((t - 0.6) / 0.4))
        return {"spine_01": [(Z, -0.2 * back + 0.3 * hit), (X, -0.04 * back + 0.12 * hit)],
                "spine_03": [(Z, -0.18 * back + 0.25 * hit), (X, 0.08 * hit)],
                "head": [(Z, 0.15 * back - 0.2 * hit)],
                "clavicle_r": [(Z, 0.1 * back - 0.15 * hit)],
                "upperarm_r": [(X, 0.55 * back - 0.75 * hit), (Y, 0.15 * back)],
                "lowerarm_r": [(X, -0.45 * back + 0.6 * hit)],
                "upperarm_l": [(X, -0.35 * back + 0.25 * hit), (Y, -0.2 * back)],
                "lowerarm_l": [(X, -0.5 * back)],
                "thigh_l": [(X, -0.4 * hit)], "calf_l": [(X, 0.35 * hit)], "foot_l": [(X, 0.05 * hit)],
                "thigh_r": [(X, 0.3 * hit)], "calf_r": [(X, 0.15 * hit)], "foot_r": [(X, -0.2 * hit)],
                "pelvis": [(Z, -0.12 * back + 0.15 * hit)],
                "_loc": Vector((0, 0.03 * back - 0.12 * hit, -0.06 * hit))}

    K.write_actions(c.arm, {"idle": (56, idle, True), "walk": (32, walk, True), "run": (20, run, True),
                            "attack": (18, attack, False), **SA.nautico()}, base_pose)


# =================================================================== montagem

def weapon_slot(c):
    me = bpy.data.meshes.new("Weapon")   # malha minúscula: o Godot descarta nós vazios presos a ossos
    me.from_pydata([(0, 0, 0), (0.001, 0, 0), (0, 0.001, 0)], [], [(0, 1, 2)])
    e = bpy.data.objects.new("Weapon", me)
    bpy.context.collection.objects.link(e)
    e.matrix_world = A.grip_matrix(c, "r", TRIDENT_SCALE)
    K.attach_to_bone(e, c.arm, "hand_r")
    c.parts.append(e)


def finalize(c, tier):
    for o in [c.body] + c.parts:
        if o.type == "MESH":
            K.apply_modifiers(o)
    anims(c)
    weapon_slot(c)
    for fn in c.after:
        fn()
    root = bpy.data.objects.new("Hero", None)
    bpy.context.collection.objects.link(root)
    c.arm.parent = root
    root.rotation_euler = (0, 0, math.pi)       # MPFB olha para -Y; o jogo espera +Y
    root.scale = (K.HERO_SCALE,) * 3
    objs = [root, c.arm, c.body] + c.parts + ([c.eyes] if c.eyes else [])
    if c.eyes is not None:
        K.apply_modifiers(c.eyes)
    for o in (c.tights, c.skirt, c.hairm):
        o.hide_render = True
    if PREVIEW:
        D.render(c, tier, root, "nautico")
    K.export_glb(os.path.join(OUT, f"hero_nautico_{tier}.glb"), objs)


def main():
    K.enable()
    only = os.environ.get("TIER")
    for tier, fn in (("comum", comum), ("rara", rara), ("epica", epica), ("lendaria", lendaria)):
        if only and tier != only:
            continue
        c = base()
        fn(c)
        finalize(c, tier)


if __name__ == "__main__":
    main()
