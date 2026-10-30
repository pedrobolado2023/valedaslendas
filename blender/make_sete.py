"""
Os sete personagens principais (documento Os Sete Reinos) como NPCs humanos (MPFB2), no mesmo estilo dos heróis.
Rode:  MH_DATA=<makehuman/data> blender -b -P blender/make_sete.py [-- nome1,nome2]
Saída: models/npc_<nome>.glb  (só a animação "idle"; o jogo usa como NPC nas capitais dos reinos)
"""
import math
import os
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mpfb_kit as K  # noqa: E402
import make_druid_mpfb as D  # noqa: E402
import make_assassin_mpfb as A  # noqa: E402

OUT = D.OUT
K.MH_DATA = os.environ.get("MH_DATA", K.MH_DATA)
TORSO, UPPER, LOWER, LEGS, FEET = D.TORSO, D.UPPER, D.LOWER, D.LEGS, D.FEET
X, Y, Z = D.X, D.Y, D.Z
piece, rigid, prim, belt = D.piece, D.rigid, D.prim, D.belt

WOMAN = {"gender": 0.0, "age": 0.45, "muscle": 0.45, "weight": 0.42, "proportions": 1.0, "height": 0.6}
MAN = {"gender": 1.0, "age": 0.45, "muscle": 0.62, "weight": 0.46, "proportions": 1.0, "height": 0.66}
FACE_W = dict(D.TARGETS)
FACE_M = {"neck/neck-scale-horiz-incr": 0.1}
for _ax in ("vert", "horiz", "depth"):
    FACE_M[f"head/head-scale-{_ax}-incr"] = 0.2
for _s in ("l", "r"):
    FACE_M[f"eyes/{_s}-eye-scale-incr"] = 0.35

FAIR = (0.93, 0.74, 0.62)
TAN = (0.84, 0.62, 0.48)
PALE = (0.9, 0.76, 0.7)


def mat(name, col, metal=0.0, rough=0.7, glow=0.0):
    return K.color_mat("sete_" + name, col, metal=metal, rough=rough, glow=glow) if glow else K.color_mat("sete_" + name, col, metal=metal, rough=rough)


def body(woman, skin, key):
    c = A.base(WOMAN if woman else MAN, FACE_W if woman else FACE_M, "sete_" + key, skin)
    return c


def hair_shell(c, m, extra=0.012, nape=0.0):
    """Cabelo curto e liso: casca da cabeça (como os elmos) cobrindo o alto e a parte de trás, com a testa livre.
    nape > 0 desce mais na nuca."""
    h, s = c.head, (c.head_top - c.head).length
    brow = c.eye_z + s * 0.48
    o = D.head_shell(c, "Cabelo", m, extra,
                     lambda p: p.z > brow or (p.y > h.y + s * 0.05 and p.z > c.eye_z - s * (0.35 + nape)) or (abs(p.x) > s * 0.55 and p.z > c.eye_z - s * 0.1),
                     0.012, 2)
    return o


def long_hair(c, m, length=0.75, spread=0.1):
    """Cabelo solto até as costas: casca curva que abraça a parte de trás da cabeça e desce pelos ombros,
    presa aos ossos de cabelo (balança ao andar)."""
    hair_shell(c, m, 0.014)
    h, s = c.head, (c.head_top - c.head).length
    r0 = s * 0.62 + 0.02
    bpy.ops.mesh.primitive_grid_add(x_subdivisions=16, y_subdivisions=16, size=1.0)
    o = bpy.context.active_object
    o.name = "Cabelo"
    for v in o.data.vertices:
        x, y = v.co.x, v.co.y            # y: 0.5 topo .. -0.5 base
        t = 0.5 - y
        ang = x * (3.3 - 0.6 * t)        # envolve a nuca (abre um pouco embaixo)
        r = r0 * (1.0 + 0.35 * t) + spread * t
        back = 0.04 * t * t              # cai um pouco para trás nas costas
        v.co = Vector((math.sin(ang) * r, math.cos(ang) * r * 0.85 + back, -t * length))
    o.location = Vector((0, h.y, c.eye_z + s * 0.55))
    bpy.ops.object.shade_smooth()
    o.data.materials.append(m)
    md = o.modifiers.new("Esp", "SOLIDIFY")
    md.thickness = 0.025
    md2 = o.modifiers.new("Suave", "SUBSURF")
    md2.levels = 1
    K.apply_modifiers(o, keep=())
    top = o.location.copy()
    bottom = top + Vector((0, 0.05, -length))
    K.add_chain(c.arm, K.HAIR, top, bottom, "head")
    K.bind_chain(o, c.arm, K.HAIR, top.z, bottom.z)
    o["capa"] = True
    c.parts.append(o)


def short_hair(c, m):
    hair_shell(c, m, 0.016)


def braid(c, m, length=0.8):
    hair_shell(c, m, 0.012)
    h, s = c.head, (c.head_top - c.head).length
    D.ponytail(c, m, h + Vector((0, s * 0.62, s * 0.1)), length, s * 0.2)


def shoulders(c, m, size=0.15):
    for side, bone in ((1, "upperarm_l"), (-1, "upperarm_r")):
        sh = K.bone_head(c.arm, bone)
        pad = prim("sphere", "Ombreira", m, sh + Vector((side * 0.035, 0.0, 0.03)), (size, size, size * 0.65), rot=(0, side * 0.35, 0))
        rigid(c, pad, bone)


def earrings(c, m):
    h, s = c.head, (c.head_top - c.head).length
    for side in (-1, 1):
        e = prim("sphere", "Joia", m, Vector((side * s * 0.6, h.y - s * 0.05, c.eye_z - s * 0.45)), (0.018, 0.018, 0.03))
        rigid(c, e, "head")


def tiara(c, m, gem=None):
    h, s = c.head, (c.head_top - c.head).length
    t = prim("torus", "Coroa", m, Vector((0, h.y + s * 0.02, c.eye_z + s * 0.5)), (s * 1.08, s * 1.18, 0.25), rot=(0.12, 0, 0), minor=0.06)
    rigid(c, t, "head")
    if gem is not None:
        g = prim("sphere", "Joia", gem, Vector((0, h.y - s * 0.62, c.eye_z + s * 0.62)), (0.025, 0.012, 0.03))
        rigid(c, g, "head")


def gown(c, top, skirt_m, sleeves=True):
    """Vestido: corpete justo + saia longa (cone preso à bacia; o NPC fica parado)."""
    piece(c, c.tights, "Vestido", TORSO + (UPPER + LOWER if sleeves else []), top, offset=0.008, zmin=c.hip_z - 0.05)
    z0, z1 = c.hip_z + 0.08, c.ankle_z - 0.03
    bpy.ops.mesh.primitive_cone_add(vertices=40, radius1=0.36, radius2=0.17, depth=z0 - z1, end_fill_type="NOTHING")
    o = bpy.context.active_object
    o.name = "Saia"
    o.location = Vector((0, K.bone_head(c.arm, "pelvis").y + 0.01, (z0 + z1) / 2))
    o.scale = (1.0, 0.8, 1.0)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bpy.ops.object.shade_smooth()
    o.data.materials.append(skirt_m)
    md = o.modifiers.new("Esp", "SOLIDIFY")
    md.thickness = 0.012
    K.apply_modifiers(o, keep=())
    rigid(c, o, "pelvis")


def armor(c, coat, chest, pants, boots, coat_skirt=None):
    piece(c, c.tights, "Calca", ["pelvis"] + LEGS, pants, offset=0.005, zmin=c.ankle_z + 0.08)
    piece(c, c.tights, "Gibao", TORSO + UPPER + LOWER, coat, offset=0.011, zmin=c.hip_z - 0.05)
    piece(c, c.tights, "Peitoral", ["spine_02", "spine_03"], chest, offset=0.022, thresh=0.5)
    piece(c, c.tights, "Bota", ["calf_l", "calf_r"] + FEET, boots, offset=0.014, thresh=0.3, zmax=c.knee_z - 0.04)
    if coat_skirt is not None:
        piece(c, c.skirt, "Barra", ["pelvis", "thigh_l", "thigh_r"], coat_skirt, offset=0.014, thresh=0.05, zmin=c.knee_z - 0.05)


# =================================================================== os sete

def kaeldryn():
    c = body(False, FAIR, "kaeldryn")
    steel = mat("k_aco", (0.09, 0.1, 0.13), metal=0.7, rough=0.35)
    coat = mat("k_casaco", (0.06, 0.06, 0.08), rough=0.6)
    ice = mat("k_gelo", (0.55, 0.85, 1.0), glow=3.0)
    armor(c, coat, steel, mat("k_calca", (0.05, 0.05, 0.06)), mat("k_bota", (0.04, 0.04, 0.05), rough=0.5), coat)
    shoulders(c, steel, 0.16)
    short_hair(c, mat("k_cabelo", (0.04, 0.035, 0.035), rough=0.6))
    belt(c, steel, c.hip_z + 0.06, buckle=ice)
    D.cape(c, mat("k_capa", (0.05, 0.07, 0.12), rough=0.8), 1.15, 0.5, steel)
    return c


def lysara():
    c = body(True, FAIR, "lysara")
    silver = mat("l_prata", (0.78, 0.82, 0.95), metal=0.45, rough=0.3)
    gown(c, silver, mat("l_saia", (0.68, 0.74, 0.9), metal=0.3, rough=0.35), sleeves=False)
    long_hair(c, mat("l_cabelo", (0.12, 0.07, 0.05), rough=0.6), 0.75, 0.1)
    earrings(c, mat("l_joia", (0.85, 0.9, 1.0), metal=0.9, rough=0.2))
    return c


def darius():
    c = body(False, TAN, "darius")
    leather = mat("d_couro", (0.07, 0.05, 0.05), rough=0.55)
    steel = mat("d_aco", (0.12, 0.08, 0.08), metal=0.6, rough=0.4)
    red = mat("d_capa", (0.5, 0.04, 0.06), rough=0.7)
    armor(c, leather, steel, mat("d_calca", (0.05, 0.04, 0.04)), mat("d_bota", (0.05, 0.03, 0.03)))
    short_hair(c, mat("d_cabelo", (0.05, 0.035, 0.03), rough=0.6))
    neck = K.bone_head(c.arm, "neck_01")
    sash = prim("torus", "Gola", red, neck + Vector((0, 0.0, -0.04)), (0.3, 0.26, 0.6), rot=(0.15, 0, 0.25))
    rigid(c, sash, "spine_03")
    D.cape(c, red, 1.2, 0.48)
    belt(c, steel, c.hip_z + 0.06, buckle=mat("d_brasa", (1.0, 0.4, 0.15), glow=3.0))
    return c


def emberlyn():
    c = body(True, FAIR, "emberlyn")
    leather = mat("e_couro", (0.08, 0.07, 0.07), rough=0.5)
    gold = mat("e_ouro", (0.85, 0.62, 0.28), metal=0.85, rough=0.3)
    armor(c, leather, mat("e_peito", (0.1, 0.09, 0.09), metal=0.5, rough=0.4), mat("e_calca", (0.06, 0.05, 0.05)), mat("e_bota", (0.07, 0.05, 0.04)))
    shoulders(c, leather, 0.13)
    hair = mat("e_cabelo", (0.3, 0.18, 0.1), rough=0.6)
    braid(c, hair, 0.8)   # trança longa
    earrings(c, gold)
    belt(c, gold, c.hip_z + 0.06, buckle=gold)
    return c


def rhaegar():
    c = body(False, FAIR, "rhaegar")
    steel = mat("r_aco", (0.1, 0.1, 0.12), metal=0.65, rough=0.4)
    fur = mat("r_pele", (0.86, 0.85, 0.82), rough=0.95)
    armor(c, mat("r_casaco", (0.07, 0.07, 0.08)), steel, mat("r_calca", (0.06, 0.06, 0.07)), mat("r_bota", (0.05, 0.05, 0.05)))
    short_hair(c, mat("r_cabelo", (0.86, 0.7, 0.42), rough=0.55))
    neck = K.bone_head(c.arm, "neck_01")
    for k in range(2):   # gola de pele
        f = prim("torus", "Gola", fur, neck + Vector((0, 0.015, -0.035 - k * 0.035)), (0.3 + k * 0.05, 0.27 + k * 0.04, 0.55), rot=(0.12, 0, 0), minor=0.14)
        rigid(c, f, "spine_03")
    D.cape(c, mat("r_capa", (0.16, 0.16, 0.18), rough=0.9), 1.2, 0.56, fur)
    belt(c, steel, c.hip_z + 0.06)
    return c


def selene():
    c = body(True, FAIR, "selene")
    gold = mat("s_ouro", (0.86, 0.66, 0.3), metal=0.6, rough=0.35)
    gown(c, gold, mat("s_saia", (0.8, 0.62, 0.32), metal=0.4, rough=0.4), sleeves=True)
    long_hair(c, mat("s_cabelo", (0.1, 0.06, 0.045), rough=0.6), 0.7, 0.12)
    jewel = mat("s_joia", (1.0, 0.85, 0.45), metal=0.95, rough=0.2)
    tiara(c, jewel, mat("s_gema", (1.0, 0.7, 0.3), glow=3.0))
    earrings(c, jewel)
    belt(c, jewel, c.hip_z + 0.1)
    return c


def nyx():
    c = body(False, PALE, "nyx")
    black = mat("n_preto", (0.03, 0.03, 0.04), rough=0.5)
    armor(c, black, mat("n_peito", (0.06, 0.05, 0.08), metal=0.5, rough=0.35), mat("n_calca", (0.03, 0.03, 0.035)), mat("n_bota", (0.03, 0.03, 0.03)), black)
    shoulders(c, black, 0.15)
    hair_shell(c, mat("n_cabelo", (0.03, 0.03, 0.035), rough=0.6), 0.03, nape=0.25)   # cabelo bagunçado até a nuca
    D.cape(c, mat("n_capa", (0.04, 0.03, 0.06), rough=0.8), 1.25, 0.52)
    belt(c, black, c.hip_z + 0.06, buckle=mat("n_fivela", (0.55, 0.35, 0.9), glow=1.5))
    return c


CHARS = {"kaeldryn": kaeldryn, "lysara": lysara, "darius": darius, "emberlyn": emberlyn, "rhaegar": rhaegar, "selene": selene, "nyx": nyx}


# =================================================================== pose, idle e exportação

def base_pose():
    """Em pé, braços soltos ao lado do corpo, mãos relaxadas."""
    pose = {"spine_03": [(X, -0.02)], "neck_01": [(X, 0.03)],
            "upperarm_l": [(Y, 0.82), (X, 0.04)], "lowerarm_l": [(X, -0.08)],
            "upperarm_r": [(Y, -0.82), (X, 0.04)], "lowerarm_r": [(X, -0.08)],
            "thigh_l": [(Y, 0.02)], "thigh_r": [(Y, -0.02)]}
    for side in ("l", "r"):
        for b, ops in D.fist(side, 0.3).items():
            pose.setdefault(b, []).extend(ops)
    return pose


def idle(t):
    sin, tau = math.sin, math.tau
    b = sin(t * tau)
    return {"spine_02": [(X, -0.01 * b)], "spine_03": [(X, -0.018 * b)],
            "clavicle_l": [(Y, 0.012 * b)], "clavicle_r": [(Y, -0.012 * b)],
            "upperarm_l": [(Y, 0.015 * b)], "upperarm_r": [(Y, -0.015 * b)],
            "head": [(Z, 0.05 * sin(t * tau + 1.2)), (X, 0.012 * b)]}


def finalize(c, key):
    for o in [c.body] + c.parts:
        if o.type == "MESH":
            K.apply_modifiers(o)
    pose = base_pose()
    K.apply_pose(c.arm, pose)
    K.write_actions(c.arm, {"idle": (64, idle, True)}, pose)
    root = bpy.data.objects.new("Hero", None)
    bpy.context.collection.objects.link(root)
    c.arm.parent = root
    root.rotation_euler = (0, 0, math.pi)       # MPFB olha para -Y; o jogo espera +Y
    root.scale = (K.HERO_SCALE,) * 3
    if c.eyes is not None:
        K.apply_modifiers(c.eyes)
    for o in (c.tights, c.skirt, c.hairm):
        o.hide_render = True
    objs = [root, c.arm, c.body] + c.parts + ([c.eyes] if c.eyes else [])
    K.export_glb(os.path.join(OUT, f"npc_{key}.glb"), objs)


def main():
    K.enable()
    only = sys.argv[sys.argv.index("--") + 1].split(",") if "--" in sys.argv else list(CHARS)
    for key in only:
        c = CHARS[key]()
        finalize(c, key)


if __name__ == "__main__":
    main()
