"""
Druida humanizada (MPFB2) nas 4 raridades: Comum, Rara, Épica e Lendária.
Rode:  MH_DATA=<makehuman/data> python blender/make_druid_mpfb.py [pasta_de_previas]
Saída: models/hero_druida_<raridade>.glb   (as armas continuam vindo de make_heroes.py)
"""
import math
import os
import random
import sys

import bpy
from mathutils import Euler, Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mpfb_kit as K  # noqa: E402

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
OUT = os.path.join(ROOT, "models")
PREVIEW = sys.argv[-1] if len(sys.argv) > 1 and os.path.isdir(sys.argv[-1]) else ""
K.MH_DATA = os.environ.get("MH_DATA", K.MH_DATA)

GOLD = (1.0, 0.72, 0.22)
GOLD_D = (0.78, 0.5, 0.12)
PURPLE = (0.72, 0.3, 1.0)

MACROS = {"gender": 0.0, "age": 0.42, "muscle": 0.5, "weight": 0.42, "proportions": 1.0, "height": 0.6}
TARGETS = {"neck/neck-scale-horiz-decr": 0.3, "torso/measure-waist-circ-decr": 0.4,
           "nose/nose-scale-horiz-decr": 0.3, "nose/nose-scale-vert-decr": 0.3, "chin/chin-width-decr": 0.3}
for _ax in ("vert", "horiz", "depth"):
    TARGETS[f"head/head-scale-{_ax}-incr"] = 0.35
for _s in ("l", "r"):
    TARGETS[f"eyes/{_s}-eye-scale-incr"] = 0.7
    TARGETS[f"eyes/{_s}-eye-height2-incr"] = 0.4

TORSO = ["pelvis", "spine_01", "spine_02", "spine_03", "clavicle_l", "clavicle_r"]
UPPER = ["upperarm_l", "upperarm_r"]
LOWER = ["lowerarm_l", "lowerarm_r"]
LEGS = ["thigh_l", "thigh_r", "calf_l", "calf_r"]
FEET = ["foot_l", "foot_r", "ball_l", "ball_r"]


class Ctx:
    pass


def base():
    K.clear_scene()
    c = Ctx()
    c.body, c.arm, c.eyes = K.create_body(MACROS, TARGETS)
    c.tights, c.skirt, c.hairm = K.split_body(c.body)
    c.sc = c.body.scale.x          # unidades locais do MPFB (0,1)
    c.parts = []
    c.skin = K.color_mat("druida_pele", (0.93, 0.72, 0.6), rough=0.6)
    c.body.data.materials.clear()
    c.body.data.materials.append(c.skin)
    for p in c.body.data.polygons:
        p.use_smooth = True
    if c.eyes is not None:
        for p in c.eyes.data.polygons:
            p.use_smooth = True
    c.head_top = K.bone_tail(c.arm, "head")
    c.head = K.bone_head(c.arm, "head")
    c.eye_z = K.vgroup_center(c.body, "head").z
    c.knee_z = K.bone_head(c.arm, "calf_l").z
    c.ankle_z = K.bone_head(c.arm, "foot_l").z
    c.hip_z = K.bone_head(c.arm, "thigh_l").z
    c.elbow_z = K.bone_head(c.arm, "lowerarm_l").z
    return c


def piece(c, src, name, bones, mat, offset=0.006, thick=0.006, subdiv=1, thresh=0.35, zmin=None, zmax=None, keep_fn=None):
    """Recorta uma peça de roupa de um molde (src), empurra para fora e prende no esqueleto."""
    o = K.duplicate(src, name)
    K.region(o, bones, thresh, zmin, zmax, keep_fn)
    if len(o.data.vertices) == 0:
        bpy.data.objects.remove(o, do_unlink=True)
        return None
    K.finish_piece(o, mat, thick / c.sc, subdiv, offset / c.sc)
    c.parts.append(o)
    return o


HAND_BONES = [f"hand_{s}" for s in ("l", "r")] + [f"{f}_{k}_{s}" for f in ("thumb", "index", "middle", "ring", "pinky")
                                                  for k in ("01", "02", "03") for s in ("l", "r")]


def gloves(c, mat, offset=0.008):
    """Luvas recortadas da própria mão do corpo (os moldes de roupa não cobrem as mãos)."""
    o = K.duplicate(c.body, "Luva")
    K.region(o, HAND_BONES, 0.3)
    K.finish_piece(o, mat, 0.004 / c.sc, 1, offset / c.sc)
    c.parts.append(o)


def head_shell(c, name, mat, offset, keep_fn, thick=0.01, subdiv=1, smooth=2):
    """Peça lisa em volta da cabeça (máscara, elmo, boné): casca encolhida até a pele, presa ao esqueleto."""
    s = (c.head_top - c.head).length
    center = c.head.lerp(c.head_top, 0.45)
    o = K.wrap_shell(name, c.body, center, s * 1.1, keep_fn, offset)
    K.bind_to_body(o, c.body, c.arm)
    K.finish_piece(o, mat, thick, subdiv, 0.0, smooth)
    c.parts.append(o)
    return o

def belt(c, mat, z, name="Cinto", buckle=None):
    """Cinto ajustado à roupa naquela altura (mede o maior contorno das peças)."""
    rx = ry = 0.0
    for o in c.parts:
        if o.type != "MESH" or o.parent_type == "BONE" or o.get("capa"):
            continue
        for v in o.data.vertices:
            p = o.matrix_world @ v.co
            if abs(p.z - z) < 0.03 and abs(p.x) < 0.24 and abs(p.y - c.head.y) < 0.2:
                rx = max(rx, abs(p.x))
                ry = max(ry, abs(p.y - c.head.y))
    if rx == 0:
        rx, ry = 0.16, 0.12
    b = prim("torus", name, mat, Vector((0, c.head.y, z)), (2 * rx + 0.02, 2 * ry + 0.02, 1.6), minor=0.035)
    rigid(c, b, "spine_01")
    if buckle is not None:
        bk = prim("box", name + "Fivela", buckle, Vector((0, c.head.y - ry - 0.018, z)), (0.06, 0.02, 0.05))
        rigid(c, bk, "spine_01")
    return rx, ry


def rigid(c, obj, bone):
    K.attach_to_bone(obj, c.arm, bone)
    c.parts.append(obj)
    return obj


def prim(kind, name, mat, loc, size, rot=(0, 0, 0), seg=16, r2=0.0, minor=0.08):
    if kind == "sphere":
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.5, segments=seg, ring_count=max(6, seg // 2))
    elif kind == "cone":
        bpy.ops.mesh.primitive_cone_add(radius1=0.5, radius2=r2, depth=1.0, vertices=seg)
    elif kind == "cyl":
        bpy.ops.mesh.primitive_cylinder_add(radius=0.5, depth=1.0, vertices=seg)
    elif kind == "torus":
        bpy.ops.mesh.primitive_torus_add(major_radius=0.5, minor_radius=minor, major_segments=seg * 2, minor_segments=8)
    else:
        bpy.ops.mesh.primitive_cube_add(size=1.0)
    o = bpy.context.active_object
    o.name = name
    o.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bpy.ops.object.shade_smooth()
    o.data.materials.append(mat)
    o.rotation_euler = rot
    o.location = loc
    return o


def leaf(name, mat, loc, length, width, rot):
    """Folha (losango curvado) — usada em ombreiras, saias e coroas."""
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.5, segments=12, ring_count=8)
    o = bpy.context.active_object
    o.name = name
    o.scale = (width, length * 0.12, length)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    for v in o.data.vertices:
        v.co.y += (v.co.z / length) ** 2 * length * 0.25     # curvatura
    bpy.ops.object.shade_smooth()
    o.data.materials.append(mat)
    o.rotation_euler = rot
    o.location = loc
    return o


# =================================================================== cabelo, capuz, capa

def hair_cap(c, mat, extra=0.01, back_long=0.0):
    """Cabelo: casca a partir do molde de cabelo + mechas."""
    o = K.duplicate(c.hairm, "Cabelo")
    h0, s0 = c.head, (c.head_top - c.head).length
    brow = c.eye_z + s0 * 0.22
    K.region(o, ["helper-hair"], 0.5, keep_fn=lambda p: not (p.y < h0.y - s0 * 0.1 and p.z < brow))
    K.finish_piece(o, mat, 0.012 / c.sc, 2, extra / c.sc)
    c.parts.append(o)
    h = c.head
    top = c.head_top
    s = (top - h).length
    # franja lateral e mechas
    for side in (-1, 1):   # mechas emoldurando o rosto
        m = prim("sphere", "MechaLado", mat, Vector((side * s * 0.5, h.y - s * 0.15, c.eye_z - s * 0.25)), (s * 0.2, s * 0.25, s * 0.9), rot=(0.1, side * 0.2, 0))
        rigid(c, m, "head")
    fr = prim("sphere", "Franja", mat, Vector((s * 0.15, h.y - s * 0.45, c.eye_z + s * 0.4)), (s * 0.95, s * 0.35, s * 0.28), rot=(0.3, 0, -0.25))
    rigid(c, fr, "head")
    if back_long > 0:
        tail = prim("cone", "Rabo", mat, h + Vector((0, s * 0.55, -back_long * 0.35)), (s * 0.55, s * 0.4, back_long), rot=(math.pi - 0.15, 0, 0), r2=0.12)
        rigid(c, tail, "head")
    return o


def hood(c, mat, point=True):
    h, s = c.head, (c.head_top - c.head).length
    chin = c.head.z - s * 0.6
    brow = c.eye_z + s * 0.3
    head_shell(c, "Capuz", mat, 0.035,
               lambda p: p.z > chin - 0.02 and not (p.y < h.y - s * 0.05 and chin < p.z < brow and abs(p.x) < s * 0.62),
               0.012, 2)
    if point:
        tip = prim("cone", "CapuzPonta", mat, h + Vector((0, s * 0.75, s * 0.55)), (s * 0.7, s * 0.6, s * 1.1), rot=(-2.1, 0, 0), r2=0.05)
        rigid(c, tip, "head")
    neck = K.bone_head(c.arm, "neck_01")
    collar = prim("torus", "Gola", mat, neck + Vector((0, 0.0, -0.01)), (0.3, 0.26, 0.9), rot=(0.15, 0, 0))
    rigid(c, collar, "spine_03")


def cape(c, mat, length=1.15, width=0.5, trim=None):
    """Capa presa nas costas (segue o tronco)."""
    neck = K.bone_head(c.arm, "neck_01")
    bpy.ops.mesh.primitive_grid_add(x_subdivisions=8, y_subdivisions=12, size=1.0)
    o = bpy.context.active_object
    o.name = "Capa"
    for v in o.data.vertices:
        x, y = v.co.x, v.co.y        # y: -0.5 (base) .. 0.5 (topo)
        t = 0.5 - y                  # 0 no topo, 1 embaixo
        v.co = Vector((x * width * (0.75 + 0.5 * t), 0.09 + 0.06 * t + 0.04 * (x * 2) ** 2, -t * length))
    o.location = neck + Vector((0, 0.03, -0.02))
    bpy.ops.object.shade_smooth()
    o.data.materials.append(mat)
    md = o.modifiers.new("Esp", "SOLIDIFY")
    md.thickness = 0.012
    md2 = o.modifiers.new("Suave", "SUBSURF")
    md2.levels = 1
    K.apply_modifiers(o, keep=())
    # capa com 3 ossos próprios (o balanço é gravado nas animações por mpfb_kit.cape_motion)
    top = o.location.copy()
    bottom = top + Vector((0, 0.06, -length))
    K.add_chain(c.arm, K.CAPE, top, bottom, "spine_03")
    K.bind_chain(o, c.arm, K.CAPE, top.z, bottom.z)
    o["capa"] = True        # fica fora das medidas do tronco (cinto, correias)
    c.parts.append(o)
    if trim is not None:
        b = prim("box", "CapaBarra", trim, neck + Vector((0, 0.17, -length + 0.02)), (width * 1.25, 0.02, 0.04))
        rigid(c, b, K.CAPE[-1])
    return o


# =================================================================== raridades

def comum(c):
    tunic = K.color_mat("druida_tunica", (0.66, 0.54, 0.34), rough=0.9)
    pants = K.color_mat("druida_calca", (0.2, 0.13, 0.08), rough=0.9)
    boot = K.color_mat("druida_bota", (0.16, 0.09, 0.05), rough=0.8)
    rope = K.color_mat("druida_corda", (0.55, 0.42, 0.26), rough=0.9)
    hair = K.color_mat("druida_cabelo", (0.16, 0.09, 0.05), rough=0.7)
    piece(c, c.tights, "Calca", ["pelvis"] + LEGS, pants, offset=0.004, zmin=c.ankle_z + 0.08)
    piece(c, c.tights, "Tunica", TORSO + UPPER, tunic, offset=0.01, zmin=c.hip_z - 0.02,
          keep_fn=lambda p, c=c: p.z > c.elbow_z + 0.04 or abs(p.x) < 0.2)
    piece(c, c.skirt, "TunicaSaia", ["pelvis", "thigh_l", "thigh_r"], tunic, offset=0.012, thresh=0.05, zmin=c.knee_z + 0.12)
    piece(c, c.tights, "Bota", ["calf_l", "calf_r"] + FEET, boot, offset=0.012, thresh=0.3, zmax=c.knee_z - 0.12)
    belt(c, rope, c.hip_z + 0.06)
    hair_cap(c, hair, 0.008, back_long=0.0)


def rara(c):
    jerk = K.color_mat("druida_gibao", (0.36, 0.2, 0.09), rough=0.75)
    cloak = K.color_mat("druida_manto", (0.5, 0.33, 0.16), rough=0.9)
    pants = K.color_mat("druida_calca2", (0.14, 0.11, 0.09), rough=0.9)
    boot = K.color_mat("druida_bota2", (0.2, 0.11, 0.05), rough=0.8)
    glove = K.color_mat("druida_luva", (0.3, 0.19, 0.11), rough=0.8)
    rune = K.color_mat("druida_runa", (0.35, 0.8, 1.0), glow=4.0)
    gold = K.color_mat("druida_fivela", (0.8, 0.62, 0.3), metal=0.8, rough=0.35)
    piece(c, c.tights, "Calca", ["pelvis"] + LEGS, pants, offset=0.004, zmin=c.ankle_z + 0.08)
    piece(c, c.tights, "Gibao", TORSO + UPPER + LOWER, jerk, offset=0.01, zmin=c.hip_z - 0.05)
    piece(c, c.skirt, "Barra", ["pelvis", "thigh_l", "thigh_r"], jerk, offset=0.012, thresh=0.05, zmin=c.knee_z + 0.2)
    piece(c, c.tights, "Bota", ["calf_l", "calf_r"] + FEET, boot, offset=0.014, thresh=0.3, zmax=c.knee_z - 0.05)
    gloves(c, glove)
    hood(c, cloak)
    cape(c, cloak, 1.1, 0.46)
    rx, ry = belt(c, K.color_mat("druida_couro", (0.2, 0.11, 0.05)), c.hip_z + 0.06, buckle=gold)
    for side in (-1, 1):
        pouch = prim("box", "Bolsa", K.color_mat("druida_bolsa", (0.3, 0.17, 0.08)), Vector((side * rx * 0.85, c.head.y - ry * 0.6, c.hip_z + 0.0)), (0.07, 0.045, 0.09))
        rigid(c, pouch, "spine_01")
    h, s = c.head, (c.head_top - c.head).length
    for side in (-1, 1):  # pintura de runa no rosto
        mark = prim("box", "Runa", rune, Vector((side * s * 0.28, h.y - s * 0.62, c.eye_z - s * 0.02)), (0.008, 0.004, 0.035))
        rigid(c, mark, "head")


def epica(c):
    leaf_d = K.color_mat("druida_folha", (0.11, 0.27, 0.14), rough=0.6)
    leaf_l = K.color_mat("druida_folha2", (0.32, 0.6, 0.22), rough=0.6)
    suit = K.color_mat("druida_traje", (0.06, 0.09, 0.07), rough=0.6)
    bark = K.color_mat("druida_casca", (0.22, 0.14, 0.09), rough=0.8)
    glow = K.color_mat("druida_brilho", PURPLE, glow=5.0)
    piece(c, c.tights, "Traje", TORSO + UPPER + LOWER + ["pelvis"] + LEGS, suit, offset=0.005, zmin=c.ankle_z + 0.05)
    piece(c, c.tights, "Peitoral", ["spine_02", "spine_03"], leaf_l, offset=0.018, thresh=0.5)
    piece(c, c.tights, "Bota", ["calf_l", "calf_r"] + FEET, bark, offset=0.016, thresh=0.3, zmax=c.knee_z - 0.02)
    piece(c, c.tights, "Bracadeira", LOWER, bark, offset=0.016, thresh=0.6, zmax=c.elbow_z - 0.08)
    # máscara: parte de cima da cabeça do próprio corpo, um pouco maior
    head_shell(c, "Mascara", leaf_d, 0.014, lambda p: p.z > c.eye_z - 0.035, 0.008)
    h, s = c.head, (c.head_top - c.head).length
    for side in (-1, 1):
        eye = prim("sphere", "OlhoBrilho", glow, Vector((side * s * 0.21, h.y - s * 0.66, c.eye_z)), (0.05, 0.012, 0.016), rot=(0, side * -0.25, 0))
        rigid(c, eye, "head")
        ear = leaf("OrelhaFolha", leaf_l, h + Vector((side * s * 0.55, s * 0.1, s * 0.75)), 0.22, 0.07, (0.25, side * -0.7, 0))
        rigid(c, ear, "head")
    # ombreiras e saia de folhas
    for side, bone in ((1, "upperarm_l"), (-1, "upperarm_r")):
        sh = K.bone_head(c.arm, bone)
        for k in range(4):
            lf = leaf("Ombreira", leaf_d if k % 2 else leaf_l, sh + Vector((side * (0.02 + k * 0.03), 0.0, 0.07 - k * 0.035)), 0.22, 0.11, (0.0, side * (1.1 + k * 0.15), 0.0))
            rigid(c, lf, bone)
        gem = prim("sphere", "GemaOmbro", glow, sh + Vector((side * 0.06, -0.04, 0.05)), (0.025, 0.025, 0.025))
        rigid(c, gem, bone)
    hip = K.bone_head(c.arm, "pelvis")
    for k in range(14):
        a = k / 14 * math.tau
        lf = leaf("SaiaFolha", leaf_d if k % 2 else leaf_l, hip + Vector((math.sin(a) * 0.17, -math.cos(a) * 0.13, -0.16)), 0.42, 0.13, (math.cos(a) * 0.25 + math.pi, math.sin(a) * -0.25, a))
        rigid(c, lf, "pelvis")
    gem = prim("sphere", "GemaPeito", glow, K.bone_head(c.arm, "spine_03") + Vector((0, -0.13, 0.02)), (0.04, 0.02, 0.04))
    rigid(c, gem, "spine_03")
    cape(c, K.color_mat("druida_capa_folha", (0.08, 0.2, 0.11)), 1.05, 0.44)


def lendaria(c):
    gold = K.color_mat("druida_ouro", GOLD, metal=0.9, rough=0.3)
    gold_d = K.color_mat("druida_ouro2", GOLD_D, metal=0.9, rough=0.35)
    white = K.color_mat("druida_branco", (0.96, 0.94, 0.88), rough=0.5)
    sun = K.color_mat("druida_sol", (1.0, 0.86, 0.45), glow=6.0)
    piece(c, c.tights, "Traje", TORSO + UPPER + LOWER + ["pelvis"] + LEGS, gold_d, offset=0.005, zmin=c.ankle_z + 0.05)
    piece(c, c.tights, "Peitoral", ["spine_01", "spine_02", "spine_03"], gold, offset=0.02, thresh=0.5)
    piece(c, c.tights, "Bota", ["calf_l", "calf_r"] + FEET, gold, offset=0.018, thresh=0.3, zmax=c.knee_z + 0.03)
    piece(c, c.tights, "Bracadeira", LOWER + ["hand_l", "hand_r"], gold, offset=0.014, thresh=0.5, zmax=c.elbow_z - 0.05)
    piece(c, c.skirt, "Saia", ["pelvis", "thigh_l", "thigh_r"], white, offset=0.014, thresh=0.05, zmin=c.knee_z)
    head_shell(c, "Elmo", gold, 0.018, lambda p: p.z > c.eye_z - 0.035)
    h, s = c.head, (c.head_top - c.head).length
    visor = prim("sphere", "Visor", sun, Vector((0, h.y - s * 0.7, c.eye_z)), (s * 0.7, 0.01, 0.018))
    rigid(c, visor, "head")
    # chifres de cervo dourados
    for side in (-1, 1):
        base_p = c.head_top + Vector((side * s * 0.32, s * 0.05, -s * 0.15))
        trunk = prim("cone", "Chifre", gold, base_p + Vector((side * 0.1, 0.03, 0.24)), (0.045, 0.045, 0.55), rot=(0.2, side * 0.45, 0), seg=8, r2=0.3)
        rigid(c, trunk, "head")
        for k in range(4):
            z = 0.14 + k * 0.11
            br = prim("cone", "Galho", gold, base_p + Vector((side * (0.1 + k * 0.05), 0.01 + k * 0.025, z)), (0.028, 0.028, 0.24 - k * 0.03), rot=(-0.25, side * (1.15 - k * 0.15), 0), seg=6, r2=0.2)
            rigid(c, br, "head")
    for side, bone in ((1, "upperarm_l"), (-1, "upperarm_r")):
        sh = K.bone_head(c.arm, bone)
        pad = prim("sphere", "Ombreira", gold, sh + Vector((side * 0.035, 0.0, 0.03)), (0.15, 0.15, 0.1), rot=(0, side * 0.35, 0))
        rigid(c, pad, bone)
        for k in range(3):
            lf = leaf("FolhaOuro", gold_d, sh + Vector((side * (0.08 + k * 0.02), 0.02 * k, 0.07)), 0.14, 0.05, (0.3, side * (1.3 + k * 0.2), 0))
            rigid(c, lf, bone)
    gem = prim("sphere", "Sol", sun, K.bone_head(c.arm, "spine_03") + Vector((0, -0.14, 0.02)), (0.05, 0.025, 0.05))
    rigid(c, gem, "spine_03")
    belt(c, gold, c.hip_z + 0.06, buckle=sun)
    cape(c, K.color_mat("druida_capa_ouro", (0.86, 0.62, 0.18), metal=0.3, rough=0.5), 1.2, 0.5, gold)


# =================================================================== postura, pegada e animações
# Eixos do mundo aqui (antes do giro final): X = esquerda da personagem, -Y = frente, Z = cima.
# Regras de sinal (medidas nos ossos): braço/perna para frente = rotação negativa em X;
# joelho dobrando = positiva em X; tronco inclinando para frente = positiva em X; pé apontando para baixo = positiva em X.

X, Y, Z = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))
CURL = float(os.environ.get("CURL_SIGN", "1"))
FINGERS = ("index", "middle", "ring", "pinky")


def fist(side, amount=1.0):
    """Dedos fechados (amount 1 = segurando firme, 0,25 = mão relaxada)."""
    ops = {}
    for f in FINGERS:
        ops[f"{f}_01_{side}"] = [("L", "X", CURL * 1.15 * amount)]
        ops[f"{f}_02_{side}"] = [("L", "X", CURL * 1.45 * amount)]
        ops[f"{f}_03_{side}"] = [("L", "X", CURL * 0.9 * amount)]
    ops[f"thumb_01_{side}"] = [("L", "Z", -CURL * 0.35 * amount if side == "r" else CURL * 0.35 * amount)]
    ops[f"thumb_02_{side}"] = [("L", "X", CURL * 0.7 * amount)]
    ops[f"thumb_03_{side}"] = [("L", "X", CURL * 0.6 * amount)]
    return ops


def build_base_pose(c):
    """Pose relaxada: peso na perna esquerda, braço esquerdo solto, mão direita segurando o cajado em pé."""
    pose = {
        "pelvis": [(Y, 0.035)],
        "spine_01": [(Y, -0.02), (X, 0.02)], "spine_03": [(Y, -0.02), (X, -0.02)],
        "neck_01": [(X, 0.05)], "head": [(Y, 0.04), (Z, -0.06)],
        "clavicle_l": [(Y, 0.05)], "clavicle_r": [(Y, -0.05)],
        "upperarm_l": [(Y, 0.78), (X, 0.06)], "lowerarm_l": [(X, -0.28)],
        "upperarm_r": [(Y, -0.42), (X, -0.28)], "lowerarm_r": [(X, -0.95)],
        "thigh_l": [(Y, 0.02)], "thigh_r": [(X, -0.08), (Y, -0.06)], "calf_r": [(X, 0.18)], "foot_r": [(X, -0.08)],
    }
    for b, ops in fist("r", 1.0).items():
        pose.setdefault(b, []).extend(ops)
    for b, ops in fist("l", 0.28).items():
        pose.setdefault(b, []).extend(ops)
    # gira o pulso para o "túnel" dos dedos fechados ficar na vertical (o cajado fica em pé)
    K.apply_pose(c.arm, pose)
    pb = c.arm.pose.bones["hand_r"]
    mid = c.arm.pose.bones["middle_01_r"]
    axis = (mid.matrix.to_3x3() @ Vector((1, 0, 0))).normalized()
    target = Z if axis.z >= 0 else -Z
    delta = axis.rotation_difference(target)
    head = pb.head.copy()
    pb.matrix = Matrix.Translation(head) @ delta.to_matrix().to_4x4() @ Matrix.Translation(-head) @ pb.matrix
    bpy.context.view_layer.update()
    pose["hand_r"] = [("Q", pb.rotation_quaternion.copy())]
    c.staff_up = 1.0 if target.z > 0 else -1.0
    K.apply_pose(c.arm, pose)
    return pose


def weapon_slot(c):
    """Nó "Weapon": no centro da mão fechada, com +Z para cima, ao longo do túnel dos dedos.
    Chamado com o esqueleto na pose relaxada; o nó é preso ao osso da mão."""
    bpy.context.view_layer.update()
    # centro do "túnel" formado pelos dedos fechados: média das juntas de cada dedo curvado
    mw = c.arm.matrix_world
    pts = []
    for f in ("index", "middle", "ring"):
        for k in ("01", "02", "03"):
            pb = c.arm.pose.bones[f"{f}_{k}_r"]
            pts.append(mw @ pb.head)
        pts.append(mw @ c.arm.pose.bones[f"{f}_03_r"].tail)
    grip = sum(pts, Vector()) / len(pts)
    mid = c.arm.pose.bones["middle_01_r"]
    axis = (c.arm.matrix_world.to_3x3() @ mid.matrix.to_3x3() @ Vector((1, 0, 0))).normalized() * c.staff_up
    rot = Vector((0, 0, 1)).rotation_difference(axis).to_matrix().to_4x4()
    me = bpy.data.meshes.new("Weapon")   # malha minúscula: o Godot descarta nós vazios presos a ossos
    me.from_pydata([(0, 0, 0), (0.001, 0, 0), (0, 0.001, 0)], [], [(0, 1, 2)])
    e = bpy.data.objects.new("Weapon", me)
    bpy.context.collection.objects.link(e)
    e.matrix_world = Matrix.Translation(grip) @ rot @ Matrix.Scale(0.62 / K.HERO_SCALE, 4)
    K.attach_to_bone(e, c.arm, "hand_r")
    c.parts.append(e)


def anims(c):
    base_pose = build_base_pose(c)
    sin, cos, tau = math.sin, math.cos, math.tau

    def legs(p, swing, knee, lift):
        """Ciclo de pernas: p = fase (0..2π); perna esquerda à frente quando sin(p) > 0."""
        out = {}
        for side, ph in (("l", 0.0), ("r", math.pi)):
            s, c_ = sin(p + ph), cos(p + ph)
            thigh = -swing * s
            calf = 0.08 + knee * max(0.0, c_) ** 2           # joelho dobra quando a perna passa por baixo
            foot = -(thigh + calf) * 0.85 + lift * max(0.0, -s) * max(0.0, -c_)   # pé plano no apoio, ponta no impulso
            out[f"thigh_{side}"] = [(X, thigh)]
            out[f"calf_{side}"] = [(X, calf)]
            out[f"foot_{side}"] = [(X, foot)]
            out[f"ball_{side}"] = [(X, -0.35 * max(0.0, -s) * max(0.0, -c_))]
        return out

    def idle(t):
        b = sin(t * tau)
        b2 = sin(t * tau * 2 + 0.6)
        return {"spine_02": [(X, -0.012 * b)], "spine_03": [(X, -0.02 * b), (Z, 0.015 * b2)],
                "clavicle_l": [(Y, 0.015 * b)], "clavicle_r": [(Y, -0.015 * b)],
                "upperarm_l": [(Y, 0.02 * b), (X, 0.02 * b2)], "lowerarm_l": [(X, -0.03 * b)],
                "head": [(Z, 0.05 * sin(t * tau + 1.2)), (X, 0.015 * b)],
                "pelvis": [(Y, 0.01 * b2)],
                "_loc": Vector((0.004 * b2, 0, -0.004 * (1 - cos(t * tau))))}

    def walk(t):
        p = t * tau
        s = sin(p)
        o = legs(p, 0.42, 1.05, 0.45)
        o.update({"pelvis": [(Z, -0.09 * s), (Y, 0.035 * cos(2 * p))],
                  "spine_01": [(Z, 0.05 * s), (X, 0.03)], "spine_03": [(Z, 0.07 * s), (X, 0.02)],
                  "neck_01": [(Z, -0.05 * s)], "head": [(Z, -0.04 * s)],
                  "upperarm_l": [(X, 0.32 * s)], "lowerarm_l": [(X, -0.18 * max(0.0, -s))],
                  "upperarm_r": [(X, -0.12 * s)], "lowerarm_r": [(X, 0.05 * s)],
                  "clavicle_l": [(Z, 0.04 * s)], "clavicle_r": [(Z, 0.04 * s)]})
        o["_loc"] = Vector((0.012 * s, 0, -0.03 + 0.022 * cos(2 * p)))
        return o

    def run(t):
        p = t * tau
        s = sin(p)
        o = legs(p, 0.72, 1.7, 0.7)
        o.update({"pelvis": [(Z, -0.12 * s), (X, 0.08)],
                  "spine_01": [(Z, 0.08 * s), (X, 0.12)], "spine_03": [(Z, 0.11 * s), (X, 0.08)],
                  "neck_01": [(X, -0.12), (Z, -0.08 * s)], "head": [(X, -0.06)],
                  "upperarm_l": [(X, 0.75 * s), (Y, -0.15)], "lowerarm_l": [(X, -0.9 - 0.25 * max(0.0, -s))],
                  "upperarm_r": [(X, -0.3 * s)], "lowerarm_r": [(X, -0.15)]})
        o["_loc"] = Vector((0.015 * s, 0, -0.06 + 0.05 * abs(cos(p))))
        return o

    def attack(t):
        # 0-0,35 prepara (ergue o cajado e gira o tronco para trás); 0,35-0,55 golpe/conjuração; 0,55-1 volta
        def ease(x):
            x = min(max(x, 0.0), 1.0)
            return x * x * (3 - 2 * x)
        up = ease(t / 0.35) * (1 - ease((t - 0.35) / 0.2))
        hit = ease((t - 0.35) / 0.2) * (1 - ease((t - 0.6) / 0.4))
        return {"spine_01": [(Z, 0.25 * up - 0.3 * hit), (X, -0.06 * up + 0.12 * hit)],
                "spine_03": [(Z, 0.2 * up - 0.25 * hit), (X, -0.08 * up + 0.1 * hit)],
                "head": [(Z, -0.2 * up + 0.2 * hit)],
                "upperarm_r": [(X, -1.25 * up - 0.75 * hit), (Y, 0.25 * up)],
                "lowerarm_r": [(X, 0.45 * up + 0.55 * hit)],
                "upperarm_l": [(X, -0.2 * up - 1.25 * hit), (Y, -0.35 * hit)],
                "lowerarm_l": [(X, -0.5 * up + 0.2 * hit)],
                "thigh_l": [(X, -0.35 * hit)], "calf_l": [(X, 0.25 * hit)], "foot_l": [(X, 0.1 * hit)],
                "thigh_r": [(X, 0.25 * hit)], "calf_r": [(X, 0.1 * hit)],
                "pelvis": [(Z, 0.12 * up - 0.15 * hit)],
                "_loc": Vector((0, -0.06 * hit, -0.05 * hit - 0.015 * up))}

    K.write_actions(c.arm, {"idle": (48, idle, True), "walk": (32, walk, True), "run": (20, run, True),
                            "attack": (18, attack, False)}, base_pose)


# =================================================================== montagem

def finalize(c, tier):
    # aplica modificadores (exceto esqueleto) e junta peças por material para exportar leve
    for o in [c.body] + c.parts:
        if o.type == "MESH":
            K.apply_modifiers(o)
    anims(c)
    weapon_slot(c)
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
        render(c, tier, root)
    K.export_glb(os.path.join(OUT, f"hero_druida_{tier}.glb"), objs)


def render(c, tier, root, cls="druida"):
    sc = bpy.context.scene
    w = bpy.data.worlds.get("prev") or bpy.data.worlds.new("prev")
    sc.world = w
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.05, 0.04, 0.07, 1)
    w.node_tree.nodes["Background"].inputs[1].default_value = 1.0
    for o in list(bpy.data.objects):
        if o.name.startswith("_prev"):
            bpy.data.objects.remove(o, do_unlink=True)
    bpy.ops.mesh.primitive_plane_add(size=30)
    fl = bpy.context.active_object
    fl.name = "_prev_chao"
    fl.data.materials.append(K.color_mat("_prev_chao", (0.12, 0.1, 0.14)))
    bpy.ops.object.light_add(type="SUN")
    sun = bpy.context.active_object
    sun.name = "_prev_sol"
    sun.rotation_euler = (math.radians(45), 0, math.radians(150))
    sun.data.energy = 3.5
    sun.data.color = (1.0, 0.85, 0.72)
    bpy.ops.object.light_add(type="AREA", location=(-3, -3, 3))
    rim = bpy.context.active_object
    rim.name = "_prev_aro"
    rim.data.energy = 250
    rim.data.color = (0.6, 0.7, 1.0)
    rim.rotation_euler = (math.radians(60), 0, math.radians(-135))
    # arma no preview
    wp = os.path.join(OUT, f"weapon_{cls}_{tier}.glb")
    if os.path.exists(wp):
        before = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=wp)
        slot = bpy.data.objects["Weapon"]
        for o in set(bpy.data.objects) - before:
            o.name = "_prev_" + o.name
            if o.parent is None:
                o.parent = slot
                o.matrix_parent_inverse = Matrix.Identity(4)
                o.location = (0, 0, 0)
                o.rotation_mode = "XYZ"
                o.rotation_euler = (0, 0, 0)
                o.scale = (1, 1, 1)
    ad = c.arm.animation_data
    ad.action = bpy.data.actions.get("idle")
    for tr in ad.nla_tracks:
        tr.mute = True
    sc.frame_set(1)
    bpy.ops.object.camera_add(location=(2.6, 4.4, 2.2))
    cam = bpy.context.active_object
    cam.name = "_prev_cam"
    cam.rotation_euler = (Vector((0, 0, 1.15)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    cam.data.lens = 50
    sc.camera = cam
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 24
    sc.render.resolution_x = 380
    sc.render.resolution_y = 460
    sc.view_settings.view_transform = "Standard"
    sc.render.filepath = os.path.join(PREVIEW, f"{cls}_{tier}.png")
    bpy.ops.render.render(write_still=True)
    for o in list(bpy.data.objects):
        if o.name.startswith("_prev"):
            bpy.data.objects.remove(o, do_unlink=True)
    ad.action = None
    for tr in ad.nla_tracks:
        tr.mute = False


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
