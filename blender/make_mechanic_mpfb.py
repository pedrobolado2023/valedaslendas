"""
Mecânico humanizado (MPFB2) nas 4 raridades: Comum, Rara, Épica e Lendária.
Mesmo processo da Druida e do Assassino (reaproveita make_druid_mpfb.py e make_assassin_mpfb.py).
Rode:  MH_DATA=<makehuman/data> python blender/make_mechanic_mpfb.py [pasta_de_previas]
Saída: models/hero_mecanico_<raridade>.glb
  - nó "Weapon" na mão direita: a chave inglesa / garra / canhão de make_heroes.py (weapon_mecanico_<raridade>.glb)
    encaixa nele e aponta para -Z (para frente e um pouco para cima, como no modelo antigo);
  - Lendária: nó "Aureola" (engrenagem nas costas) que o jogo gira em volta do próprio eixo Z.
"""
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mpfb_kit as K  # noqa: E402
import skill_anims as SA  # noqa: E402
import make_druid_mpfb as D  # noqa: E402
import make_assassin_mpfb as A  # noqa: E402

OUT = D.OUT
PREVIEW = D.PREVIEW
K.MH_DATA = os.environ.get("MH_DATA", K.MH_DATA)

GOLD = (1.0, 0.74, 0.22)
GOLD2 = (0.86, 0.58, 0.14)
PURPLE = (0.75, 0.3, 1.0)
TOOL_SCALE = 0.55 / K.HERO_SCALE        # chave/canhão com ~0,7 de comprimento no jogo
TOOL_DIR = Vector((0, -1, 0.55))        # para onde a ferramenta aponta na pose parada (frente = -Y)

# homem forte e atarracado, mesma cabeça um pouco maior e olhos grandes do resto do elenco
MACROS = {"gender": 1.0, "age": 0.55, "muscle": 0.7, "weight": 0.62, "proportions": 0.9, "height": 0.42}
TARGETS = {"neck/neck-scale-horiz-incr": 0.3}
for _ax in ("vert", "horiz", "depth"):
    TARGETS[f"head/head-scale-{_ax}-incr"] = 0.25
for _s in ("l", "r"):
    TARGETS[f"eyes/{_s}-eye-scale-incr"] = 0.4

TORSO, UPPER, LOWER, LEGS, FEET = D.TORSO, D.UPPER, D.LOWER, D.LEGS, D.FEET
X, Y, Z = D.X, D.Y, D.Z
piece, rigid, prim, belt = D.piece, D.rigid, D.prim, D.belt


def base():
    c = A.base(MACROS, TARGETS, "mecanico", (0.88, 0.66, 0.52))
    c.after = []          # peças que dependem da pose (presas às mãos depois das animações)
    return c


# =================================================================== peças do mecânico

def gear(name, mat, hole, r, teeth=8, thick=0.08):
    """Engrenagem com o furo escuro no meio; o eixo dela fica no -Y local."""
    objs = [prim("cyl", name + "Disco", mat, Vector(), (r * 2, r * 2, thick), seg=16)]
    for k in range(teeth):
        a = k * math.tau / teeth
        objs.append(prim("box", f"{name}Dente{k}", mat, Vector((math.cos(a) * r, math.sin(a) * r, 0)), (r * 0.35, r * 0.35, thick), rot=(0, 0, a)))
    objs.append(prim("cyl", name + "Furo", hole, Vector(), (r * 0.6, r * 0.6, thick + 0.004), seg=10))
    g = A.join_parts(objs, name)
    g.data.transform(Matrix.Rotation(math.pi / 2, 4, "X"))
    return g


gloves = D.gloves


def head_ring(c, z, band=0.012):
    """Centro (y) e raios (x, y) da cabeça na altura z — para óculos, faixas e viseiras."""
    mw = c.body.matrix_world
    xs, ys = [], []
    for v in c.body.data.vertices:
        p = mw @ v.co
        if abs(p.z - z) < band and abs(p.x) < 0.15 and abs(p.y - c.head.y) < 0.16:
            xs.append(abs(p.x))
            ys.append(p.y)
    if not xs:
        return c.head.y, 0.09, 0.1
    return (max(ys) + min(ys)) / 2, max(xs), (max(ys) - min(ys)) / 2


def short_hair(c, mat):
    """Cabelo curto: casca do molde de cabelo, acima da testa na frente e até a nuca atrás."""
    s = (c.head_top - c.head).length
    brow = c.eye_z + s * 0.28
    o = K.duplicate(c.hairm, "Cabelo")
    K.region(o, ["helper-hair"], 0.5, keep_fn=lambda p: p.z > (brow if p.y < c.head.y else brow - s * 0.5))
    K.finish_piece(o, mat, 0.008 / c.sc, 1, 0.004 / c.sc)
    c.parts.append(o)


def cap(c, mat):
    """Boné: o topo da cabeça um pouco maior e a aba na frente."""
    s = (c.head_top - c.head).length
    A.head_shell(c, "Bone", mat, 0.02, lambda p: p.z > c.eye_z + s * 0.3)
    cy, rx, ry = head_ring(c, c.eye_z + s * 0.32)
    brim = prim("sphere", "Aba", mat, Vector((0, cy - ry - 0.03, c.eye_z + s * 0.33)), (rx * 1.7, 0.1, 0.014), rot=(-0.12, 0, 0))
    rigid(c, brim, "head")


def goggles(c, strap, rim, lens):
    """Óculos de solda na testa, com a tira em volta da cabeça."""
    s = (c.head_top - c.head).length
    z = c.eye_z + s * 0.4
    cy, rx, ry = head_ring(c, z)
    band = prim("torus", "TiraOculos", strap, Vector((0, cy, z)), (2 * rx + 0.025, 2 * ry + 0.025, 1.0), minor=0.06)
    rigid(c, band, "head")
    for side in (-1, 1):
        p = Vector((side * rx * 0.45, cy - ry - 0.012, z + 0.005))
        ring = prim("cyl", "Oculos", rim, p, (0.05, 0.05, 0.03), rot=(math.pi / 2 - 0.35, 0, 0), seg=14)
        rigid(c, ring, "head")
        ln = prim("cyl", "Lente", lens, p + Vector((0, -0.014, 0.004)), (0.04, 0.04, 0.008), rot=(math.pi / 2 - 0.35, 0, 0), seg=14)
        rigid(c, ln, "head")


def gorget(c, mat):
    """Protetor de pescoço: fecha o vão entre o capacete e o peitoral."""
    neck = K.bone_head(c.arm, "neck_01")
    for k, (z, sx) in enumerate(((-0.02, 0.27), (0.03, 0.23))):
        g = prim("torus", "Gorjal", mat, neck + Vector((0, 0.005, z)), (sx, sx * 0.9, 0.5), rot=(0.12, 0, 0), minor=0.09)
        rigid(c, g, "spine_03" if k == 0 else "neck_01")


def robot_helmet(c, mat, ring_mat, eye):
    """Capacete fechado com um olho redondo brilhante no meio."""
    neck_z = K.bone_head(c.arm, "neck_01").z
    A.head_shell(c, "Capacete", mat, 0.022, lambda p: p.z > neck_z)
    s = (c.head_top - c.head).length
    ez = c.eye_z + s * 0.12
    cy, rx, ry = head_ring(c, ez)
    front = cy - ry - 0.022
    e = prim("cyl", "OlhoRobo", eye, Vector((0, front - 0.006, ez)), (0.07, 0.07, 0.012), rot=(math.pi / 2, 0, 0), seg=18)
    rigid(c, e, "head")
    rg = prim("torus", "AroOlho", ring_mat, Vector((0, front - 0.006, ez)), (0.085, 0.085, 1.0), rot=(math.pi / 2, 0, 0), minor=0.1)
    rigid(c, rg, "head")
    for side in (-1, 1):  # "orelhas" de parafuso
        bolt = prim("cyl", "Parafuso", ring_mat, Vector((side * (rx + 0.022), cy, c.eye_z)), (0.04, 0.04, 0.025), rot=(0, math.pi / 2, 0), seg=10)
        rigid(c, bolt, "head")


def backpack(c, mat, core=None, pipes=None):
    sp = K.bone_head(c.arm, "spine_03")
    cy, rx, ry = torso_size(c, sp.z - 0.05)
    p = Vector((0, cy + ry + 0.07, sp.z - 0.05))
    bag = prim("box", "Mochila", mat, p, (0.26, 0.12, 0.3))
    rigid(c, bag, "spine_03")
    if core is not None:
        cr = prim("sphere", "Nucleo", core, p + Vector((0, 0.065, 0.0)), (0.08, 0.02, 0.08))
        rigid(c, cr, "spine_03")
    if pipes is not None:
        for side in (-1, 1):
            ex = prim("cyl", "Exaustor", pipes, p + Vector((side * 0.09, 0.03, 0.2)), (0.055, 0.055, 0.18), seg=10)
            rigid(c, ex, "spine_03")
    return p


def torso_size(c, z):
    rx = ry = 0.0
    ys = []
    for o in c.parts + [c.body]:
        if o.type != "MESH" or o.parent_type == "BONE" or o.get("capa"):
            continue
        for v in o.data.vertices:
            pt = o.matrix_world @ v.co
            if abs(pt.z - z) < 0.03 and abs(pt.x) < 0.26 and abs(pt.y - c.head.y) < 0.22:
                rx = max(rx, abs(pt.x))
                ys.append(pt.y)
    if not ys:
        return c.head.y, 0.17, 0.12
    return (max(ys) + min(ys)) / 2, rx, (max(ys) - min(ys)) / 2


def halo(c, gold, glow, hole):
    """Auréola de engrenagem atrás da cabeça (o jogo gira o nó "Aureola" em volta do eixo Z dele)."""
    objs = [prim("cyl", "HaloDisco", gold, Vector(), (0.5, 0.5, 0.03), seg=24)]
    for k in range(16):
        a = k * math.tau / 16
        objs.append(prim("box", f"HaloDente{k}", gold, Vector((math.cos(a) * 0.25, math.sin(a) * 0.25, 0)), (0.06, 0.06, 0.03), rot=(0, 0, a)))
    objs.append(prim("cyl", "HaloFuro", hole, Vector(), (0.2, 0.2, 0.034), seg=16))
    for k in range(12):
        a = k * math.tau / 12
        objs.append(prim("cone", f"HaloRaio{k}", glow, Vector((math.cos(a) * 0.34, math.sin(a) * 0.34, 0)), (0.035, 0.035, 0.11), rot=(0, math.pi / 2, a), seg=4))
    h = A.join_parts(objs, "Aureola")
    h.data.transform(Matrix.Rotation(math.pi / 2, 4, "X"))     # eixo da engrenagem = -Y local (vira +Z no Godot)
    cy, rx, ry = torso_size(c, K.bone_head(c.arm, "spine_03").z)
    h.location = Vector((0, cy + ry + 0.2, c.eye_z + 0.05))
    rigid(c, h, "spine_03")


def hand_gear(c, mat, hole):
    """Engrenagem segura na mão esquerda (Comum)."""
    g = gear("EngrenagemMao", mat, hole, 0.16, teeth=8, thick=0.08)
    g.matrix_world = A.grip_matrix(c, "l", TOOL_SCALE) @ Matrix.Translation((0, 0, -0.16))
    K.attach_to_bone(g, c.arm, "hand_l")
    c.parts.append(g)


def wrist_gear(c, mat, hole):
    """Engrenagem grande em volta do pulso esquerdo (Lendária)."""
    pb = c.arm.pose.bones
    mw = c.arm.matrix_world
    a, b = mw @ pb["lowerarm_l"].head, mw @ pb["hand_l"].head
    g = gear("CanhaoL", mat, hole, 0.06, teeth=10, thick=0.03)
    rot = Vector((0, -1, 0)).rotation_difference((b - a).normalized()).to_matrix().to_4x4()
    g.matrix_world = Matrix.Translation(a.lerp(b, 0.8)) @ rot
    K.attach_to_bone(g, c.arm, "lowerarm_l")
    c.parts.append(g)


# =================================================================== raridades

def comum(c):
    shirt = K.color_mat("mecanico_camisa", (0.55, 0.5, 0.4), rough=0.9)
    overall = K.color_mat("mecanico_macacao", (0.4, 0.42, 0.46), rough=0.85)
    boot = K.color_mat("mecanico_bota", (0.28, 0.2, 0.14), rough=0.8)
    hair = K.color_mat("mecanico_cabelo", (0.3, 0.2, 0.12), rough=0.7)
    cap_m = K.color_mat("mecanico_bone", (0.42, 0.44, 0.48), rough=0.8)
    leather = K.color_mat("mecanico_couro", (0.3, 0.2, 0.12), rough=0.8)
    steel = K.color_mat("mecanico_aco", (0.62, 0.64, 0.68), metal=0.8, rough=0.35)
    dark = K.color_mat("mecanico_escuro", (0.06, 0.04, 0.04))
    piece(c, c.tights, "Camisa", TORSO + UPPER, shirt, offset=0.008, zmin=c.hip_z - 0.04,
          keep_fn=lambda p: p.z > c.elbow_z + 0.04 or abs(p.x) < 0.2)
    piece(c, c.tights, "Macacao", ["pelvis"] + LEGS, overall, offset=0.012, zmin=c.ankle_z + 0.08)
    chest_z = K.bone_head(c.arm, "spine_03").z + 0.03
    piece(c, c.tights, "Peitilho", ["pelvis", "spine_01", "spine_02", "spine_03"], overall, offset=0.018, thresh=0.2,
          zmin=c.hip_z - 0.02, zmax=chest_z, keep_fn=lambda p: p.y < c.head.y - 0.02 and abs(p.x) < 0.12)
    piece(c, c.tights, "Bota", ["calf_l", "calf_r"] + FEET, boot, offset=0.014, thresh=0.3, zmax=c.knee_z - 0.12)
    sp2 = K.bone_head(c.arm, "spine_02")
    cy, rx, ry = torso_size(c, sp2.z + 0.05)
    for side in (-1, 1):   # botões do peitilho
        bt = prim("sphere", "Botao", steel, Vector((side * 0.08, cy - ry - 0.012, sp2.z + 0.06)), (0.022, 0.012, 0.022))
        rigid(c, bt, "spine_02")
    short_hair(c, hair)
    cap(c, cap_m)
    belt(c, leather, c.hip_z + 0.06, buckle=steel)
    c.after.append(lambda: hand_gear(c, steel, dark))


def rara(c):
    shirt = K.color_mat("mecanico_camisa2", (0.6, 0.6, 0.62), rough=0.85)
    pants = K.color_mat("mecanico_calca2", (0.32, 0.33, 0.36), rough=0.85)
    boot = K.color_mat("mecanico_bota2", (0.26, 0.18, 0.12), rough=0.8)
    glove = K.color_mat("mecanico_luva", (0.3, 0.2, 0.12), rough=0.8)
    apron = K.color_mat("mecanico_avental", (0.42, 0.27, 0.15), rough=0.75)
    apron2 = K.color_mat("mecanico_avental2", (0.35, 0.22, 0.12), rough=0.75)
    hair = K.color_mat("mecanico_cabelo2", (0.3, 0.2, 0.12), rough=0.7)
    brass = K.color_mat("mecanico_latao", (0.75, 0.6, 0.3), metal=0.8, rough=0.35)
    lens = K.color_mat("mecanico_lente", (0.45, 0.8, 1.0), glow=2.0)
    strap = K.color_mat("mecanico_tira", (0.25, 0.18, 0.12), rough=0.8)
    piece(c, c.tights, "Camisa", TORSO + UPPER + LOWER, shirt, offset=0.008, zmin=c.hip_z - 0.04)
    piece(c, c.tights, "Calca", ["pelvis"] + LEGS, pants, offset=0.006, zmin=c.ankle_z + 0.08)
    piece(c, c.tights, "Bota", ["calf_l", "calf_r"] + FEET, boot, offset=0.014, thresh=0.3, zmax=c.knee_z - 0.06)
    gloves(c, glove)
    piece(c, c.tights, "Avental", ["pelvis", "spine_01", "spine_02", "thigh_l", "thigh_r"], apron, offset=0.022, thresh=0.3,
          zmin=c.knee_z + 0.04, keep_fn=lambda p: p.y < c.head.y - 0.03)
    short_hair(c, hair)
    s = (c.head_top - c.head).length
    for side in (-1, 1):   # costeletas
        cb = prim("sphere", "Costeleta", hair, Vector((side * s * 0.58, c.head.y - s * 0.05, c.eye_z - s * 0.12)), (0.025, 0.04, 0.07))
        rigid(c, cb, "head")
    goggles(c, strap, brass, lens)
    belt(c, K.color_mat("mecanico_couro2", (0.3, 0.2, 0.12)), c.hip_z + 0.06, buckle=brass)
    sp1 = K.bone_head(c.arm, "spine_01")
    cy, rx, ry = torso_size(c, sp1.z)
    pocket = prim("box", "Bolso", apron2, Vector((0, cy - ry - 0.008, sp1.z - 0.02)), (0.14, 0.015, 0.08))
    rigid(c, pocket, "spine_01")
    for side in (-1, 1):   # ferramentas no bolso
        tl = prim("cyl", "Ferramenta", brass, Vector((side * 0.035, cy - ry - 0.012, sp1.z + 0.04)), (0.012, 0.012, 0.09), seg=6)
        rigid(c, tl, "spine_01")


def epica(c):
    suit = K.color_mat("mecanico_traje", (0.12, 0.12, 0.15), rough=0.6)
    plate = K.color_mat("mecanico_placa", (0.22, 0.22, 0.26), metal=0.6, rough=0.4)
    glow = K.color_mat("mecanico_luz", PURPLE, glow=5.0)
    piece(c, c.tights, "Traje", TORSO + UPPER + LOWER + ["pelvis"] + LEGS, suit, offset=0.006, zmin=c.ankle_z + 0.05)
    piece(c, c.tights, "Peitoral", ["spine_02", "spine_03"], plate, offset=0.022, thresh=0.5)
    piece(c, c.tights, "Bota", ["calf_l", "calf_r"] + FEET, plate, offset=0.018, thresh=0.3, zmax=c.knee_z + 0.02)
    piece(c, c.tights, "Bracadeira", LOWER + ["hand_l", "hand_r"], plate, offset=0.018, thresh=0.5, zmax=c.elbow_z - 0.04)
    gloves(c, plate, 0.012)
    robot_helmet(c, plate, suit, glow)
    gorget(c, plate)
    A.pauldrons(c, plate, suit, size=0.15, gem=glow)
    for side, bone in ((1, "thigh_l"), (-1, "thigh_r")):   # faixas de luz nas coxas
        hd, tl = K.bone_head(c.arm, bone), K.bone_tail(c.arm, bone)
        p = hd.lerp(tl, 0.4)
        cy, rx, ry = torso_size(c, p.z)
        st = prim("box", "Faixa", glow, Vector((p.x, cy - ry - 0.004, p.z)), (0.018, 0.01, 0.14))
        rigid(c, st, bone)
    gem = prim("sphere", "GemaPeito", glow, K.bone_head(c.arm, "spine_03") + Vector((0, -0.15, 0.02)), (0.045, 0.02, 0.045))
    rigid(c, gem, "spine_03")
    belt(c, plate, c.hip_z + 0.06, buckle=glow)
    backpack(c, plate, core=glow)


def lendaria(c):
    gold = K.color_mat("mecanico_ouro", GOLD, metal=0.9, rough=0.3)
    gold2 = K.color_mat("mecanico_ouro2", GOLD2, metal=0.9, rough=0.35)
    glow = K.color_mat("mecanico_luz_lend", (1.0, 0.85, 0.4), glow=5.0)
    dark = K.color_mat("mecanico_visor", (0.06, 0.05, 0.05), rough=0.4)
    copper = K.color_mat("mecanico_cobre", (0.7, 0.4, 0.2), metal=0.8, rough=0.35)
    piece(c, c.tights, "Traje", TORSO + UPPER + LOWER + ["pelvis"] + LEGS, gold2, offset=0.006, zmin=c.ankle_z + 0.05)
    piece(c, c.tights, "Peitoral", ["spine_01", "spine_02", "spine_03"], gold, offset=0.024, thresh=0.5)
    piece(c, c.tights, "Bota", ["calf_l", "calf_r"] + FEET, gold, offset=0.02, thresh=0.3, zmax=c.knee_z + 0.03)
    piece(c, c.tights, "Bracadeira", LOWER + ["hand_l", "hand_r"], gold, offset=0.018, thresh=0.5, zmax=c.elbow_z - 0.04)
    gloves(c, gold, 0.012)
    A.helmet(c, gold, dark)
    gorget(c, gold2)
    s = (c.head_top - c.head).length
    cy, rx, ry = head_ring(c, c.eye_z)
    bar = prim("box", "VisorV", dark, Vector((0, cy - ry - 0.03, c.eye_z - s * 0.2)), (0.022, 0.012, s * 0.4))
    rigid(c, bar, "head")
    A.pauldrons(c, gold, gold2, size=0.17, gem=glow)
    gem = prim("sphere", "GemaPeito", glow, K.bone_head(c.arm, "spine_03") + Vector((0, -0.16, 0.02)), (0.05, 0.024, 0.05))
    rigid(c, gem, "spine_03")
    belt(c, gold2, c.hip_z + 0.06, buckle=glow)
    backpack(c, gold2, core=glow, pipes=copper)
    halo(c, gold, glow, dark)
    c.after.append(lambda: wrist_gear(c, gold2, dark))


# =================================================================== postura e animações
# Mesmas regras de sinal da Druida: braço/perna para frente = -X; joelho dobra = +X; tronco para frente = +X.

def align_wrist(c, pose, side, target):
    """Gira o pulso para o "túnel" da mão fechada (lado do polegar) apontar para target."""
    K.apply_pose(c.arm, pose)
    pb = c.arm.pose.bones
    hand = pb[f"hand_{side}"]
    axis = (pb[f"middle_01_{side}"].matrix.to_3x3() @ Vector((1, 0, 0))).normalized()
    if axis.dot(pb[f"index_01_{side}"].head - pb[f"pinky_01_{side}"].head) < 0:
        axis = -axis
    delta = axis.rotation_difference(target.normalized())
    head = hand.head.copy()
    hand.matrix = Matrix.Translation(head) @ delta.to_matrix().to_4x4() @ Matrix.Translation(-head) @ hand.matrix
    bpy.context.view_layer.update()
    pose[f"hand_{side}"] = [("Q", hand.rotation_quaternion.copy())]
    K.apply_pose(c.arm, pose)


def build_base_pose(c):
    """De pé, firme: ferramenta na mão direita apontando para frente; mão esquerda solta, meio fechada."""
    pose = {
        "pelvis": [(Y, -0.02)],
        "spine_01": [(X, 0.02)], "spine_03": [(Y, 0.02)],
        "neck_01": [(X, 0.03)], "head": [(Z, 0.05)],
        "clavicle_l": [(Y, 0.04)], "clavicle_r": [(Y, -0.03)],
        "upperarm_l": [(Y, 0.75), (X, -0.05)], "lowerarm_l": [(X, -0.45)],
        "upperarm_r": [(Y, -0.6), (X, -0.12)], "lowerarm_r": [(X, -0.8)],
        "thigh_l": [(Y, 0.05)], "thigh_r": [(Y, -0.05)],
    }
    for b, ops in D.fist("r", 1.0).items():
        pose.setdefault(b, []).extend(ops)
    for b, ops in D.fist("l", 0.7).items():
        pose.setdefault(b, []).extend(ops)
    align_wrist(c, pose, "r", TOOL_DIR)
    return pose


def anims(c):
    base_pose = build_base_pose(c)
    sin, cos, tau = math.sin, math.cos, math.tau

    def ease(x):
        x = min(max(x, 0.0), 1.0)
        return x * x * (3 - 2 * x)

    def legs(p, swing, knee, lift):
        out = {}
        for side, ph in (("l", 0.0), ("r", math.pi)):
            s, c_ = sin(p + ph), cos(p + ph)
            thigh = -swing * s
            calf = 0.08 + knee * max(0.0, c_) ** 2
            foot = -(thigh + calf) * 0.85 + lift * max(0.0, -s) * max(0.0, -c_)
            out[f"thigh_{side}"] = [(X, thigh)]
            out[f"calf_{side}"] = [(X, calf)]
            out[f"foot_{side}"] = [(X, foot)]
            out[f"ball_{side}"] = [(X, -0.35 * max(0.0, -s) * max(0.0, -c_))]
        return out

    def idle(t):
        b = sin(t * tau)
        b2 = sin(t * tau * 2 + 0.6)
        return {"spine_02": [(X, -0.012 * b)], "spine_03": [(X, -0.02 * b), (Z, 0.02 * b2)],
                "clavicle_l": [(Y, 0.015 * b)], "clavicle_r": [(Y, -0.015 * b)],
                "upperarm_l": [(Y, 0.02 * b)], "lowerarm_l": [(X, -0.04 * b)],
                "upperarm_r": [(X, 0.03 * b2)], "lowerarm_r": [(X, -0.05 * b)],
                "head": [(Z, 0.08 * sin(t * tau + 1.2)), (X, 0.015 * b)],
                "pelvis": [(Y, 0.012 * b2)],
                "_loc": Vector((0.005 * b2, 0, -0.005 * (1 - cos(t * tau))))}

    def walk(t):
        # passo pesado, ombros balançando
        p = t * tau
        s = sin(p)
        o = legs(p, 0.4, 1.0, 0.4)
        o.update({"pelvis": [(Z, -0.1 * s), (Y, 0.045 * cos(2 * p))],
                  "spine_01": [(Z, 0.06 * s), (X, 0.03)], "spine_03": [(Z, 0.08 * s), (Y, -0.03 * cos(2 * p))],
                  "neck_01": [(Z, -0.06 * s)], "head": [(Z, -0.04 * s)],
                  "upperarm_l": [(X, 0.32 * s)], "lowerarm_l": [(X, -0.15 * max(0.0, -s))],
                  "upperarm_r": [(X, 0.12 * s)], "lowerarm_r": [(X, -0.05 * s)]})
        o["_loc"] = Vector((0.014 * s, 0, -0.03 + 0.024 * cos(2 * p)))
        return o

    def run(t):
        p = t * tau
        s = sin(p)
        o = legs(p, 0.68, 1.6, 0.65)
        o.update({"pelvis": [(Z, -0.12 * s), (X, 0.08)],
                  "spine_01": [(Z, 0.08 * s), (X, 0.12)], "spine_03": [(Z, 0.1 * s), (X, 0.06)],
                  "neck_01": [(X, -0.12), (Z, -0.08 * s)], "head": [(X, -0.06)],
                  "upperarm_l": [(X, 0.7 * s), (Y, -0.15)], "lowerarm_l": [(X, -0.85 - 0.25 * max(0.0, -s))],
                  "upperarm_r": [(X, 0.35 * s)], "lowerarm_r": [(X, -0.2)]})
        o["_loc"] = Vector((0.016 * s, 0, -0.06 + 0.05 * abs(cos(p))))
        return o

    def attack(t):
        # marretada: ergue a ferramenta acima da cabeça (0-0,4), desce com tudo (0,4-0,55) e volta
        up = ease(t / 0.4) * (1 - ease((t - 0.4) / 0.15))
        hit = ease((t - 0.4) / 0.15) * (1 - ease((t - 0.62) / 0.38))
        return {"spine_01": [(X, -0.1 * up + 0.2 * hit), (Z, 0.12 * up - 0.1 * hit)],
                "spine_03": [(X, -0.08 * up + 0.15 * hit), (Z, 0.1 * up - 0.08 * hit)],
                "neck_01": [(X, 0.06 * up - 0.12 * hit)],
                "upperarm_r": [(X, -1.7 * up - 0.55 * hit), (Y, 0.3 * up)],
                "lowerarm_r": [(X, -0.5 * up + 0.55 * hit)],
                "upperarm_l": [(X, -0.25 * up + 0.2 * hit), (Y, -0.15 * up)],
                "lowerarm_l": [(X, -0.3 * up)],
                "thigh_l": [(X, -0.3 * hit)], "calf_l": [(X, 0.35 * hit)], "foot_l": [(X, -0.05 * hit)],
                "thigh_r": [(X, 0.15 * hit)], "calf_r": [(X, 0.3 * hit)], "foot_r": [(X, -0.2 * hit)],
                "_loc": Vector((0, -0.05 * hit, 0.01 * up - 0.07 * hit))}

    K.write_actions(c.arm, {"idle": (48, idle, True), "walk": (32, walk, True), "run": (20, run, True),
                            "attack": (20, attack, False), **SA.mecanico()}, base_pose)


# =================================================================== montagem

def weapon_slot(c):
    me = bpy.data.meshes.new("Weapon")   # malha minúscula: o Godot descarta nós vazios presos a ossos
    me.from_pydata([(0, 0, 0), (0.001, 0, 0), (0, 0.001, 0)], [], [(0, 1, 2)])
    e = bpy.data.objects.new("Weapon", me)
    bpy.context.collection.objects.link(e)
    e.matrix_world = A.grip_matrix(c, "r", TOOL_SCALE)
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
        D.render(c, tier, root, "mecanico")
    K.export_split(OUT, "mecanico", tier, root, c.arm, objs)


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
