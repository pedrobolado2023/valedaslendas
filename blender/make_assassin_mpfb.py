"""
Assassino humanizado (MPFB2) nas 4 raridades: Comum, Rara, Épica e Lendária.
Mesmo processo da Druida (make_druid_mpfb.py), cujas ferramentas de roupa, capuz, capa e prévia são reaproveitadas.
Rode:  MH_DATA=<makehuman/data> python blender/make_assassin_mpfb.py [pasta_de_previas]
Saída: models/hero_assassino_<raridade>.glb
  - nó "Weapon" na mão direita: a adaga de make_heroes.py (weapon_assassino_<raridade>.glb) encaixa nele,
    com a lâmina saindo pelo lado do polegar (-Z do nó, igual ao modelo antigo);
  - a adaga da mão esquerda já vem no modelo (nó "AdagaEsquerda", preso ao osso hand_l).
"""
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mpfb_kit as K  # noqa: E402
import make_druid_mpfb as D  # noqa: E402

OUT = D.OUT
PREVIEW = D.PREVIEW
K.MH_DATA = os.environ.get("MH_DATA", K.MH_DATA)

GOLD = (1.0, 0.74, 0.22)
PURPLE = (0.75, 0.3, 1.0)
WHITE = (0.96, 0.96, 0.94)
DAGGER_SCALE = 0.5 / K.HERO_SCALE      # adaga ~0,6 de comprimento no jogo

# homem magro e ágil, mesma cabeça um pouco maior e olhos grandes da Druida (estilo do jogo)
MACROS = {"gender": 1.0, "age": 0.45, "muscle": 0.62, "weight": 0.36, "proportions": 1.0, "height": 0.55}
TARGETS = {"torso/measure-waist-circ-decr": 0.3, "neck/neck-scale-horiz-decr": 0.15}
for _ax in ("vert", "horiz", "depth"):
    TARGETS[f"head/head-scale-{_ax}-incr"] = 0.25
for _s in ("l", "r"):
    TARGETS[f"eyes/{_s}-eye-scale-incr"] = 0.45

TORSO, UPPER, LOWER, LEGS, FEET = D.TORSO, D.UPPER, D.LOWER, D.LEGS, D.FEET
X, Y, Z = D.X, D.Y, D.Z
piece, rigid, prim, belt = D.piece, D.rigid, D.prim, D.belt


def base(macros=None, targets=None, cls="assassino", skin=(0.86, 0.64, 0.5)):
    K.clear_scene()
    c = D.Ctx()
    c.body, c.arm, c.eyes = K.create_body(macros or MACROS, targets or TARGETS)
    c.tights, c.skirt, c.hairm = K.split_body(c.body)
    c.sc = c.body.scale.x
    c.parts = []
    c.skin = K.color_mat(cls + "_pele", skin, rough=0.6)
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
    c.dagger = None
    return c


# =================================================================== peças do assassino

def mask(c, mat):
    """Lenço/máscara cobrindo nariz, boca e pescoço (os olhos ficam de fora)."""
    s = (c.head_top - c.head).length
    o = K.duplicate(c.body, "Mascara")
    K.region(o, ["head", "neck_01"], 0.3, zmin=K.bone_head(c.arm, "neck_01").z - 0.03,
             keep_fn=lambda p: p.z < c.eye_z - s * 0.12)
    K.finish_piece(o, mat, 0.008 / c.sc, 2, 0.014 / c.sc)
    c.parts.append(o)
    return o


def helmet(c, mat, visor):
    """Elmo fechado: a cabeça inteira um pouco maior, com fenda brilhante na altura dos olhos."""
    h, s = c.head, (c.head_top - c.head).length
    o = K.duplicate(c.body, "Elmo")
    K.region(o, ["head"], 0.5, zmin=K.bone_head(c.arm, "neck_01").z)
    K.finish_piece(o, mat, 0.01 / c.sc, 1, 0.02 / c.sc)
    c.parts.append(o)
    v = prim("sphere", "Visor", visor, Vector((0, h.y - s * 0.74, c.eye_z)), (s * 0.62, 0.012, 0.02))
    rigid(c, v, "head")
    return o


def bandolier(c, mat, buckle=None):
    """Correia atravessada no peito (do ombro esquerdo ao quadril direito)."""
    z = K.bone_head(c.arm, "spine_02").z
    rx = ry = 0.0
    for o in c.parts:
        if o.type != "MESH" or o.parent_type == "BONE" or o.get("capa"):
            continue
        for v in o.data.vertices:
            p = o.matrix_world @ v.co
            if abs(p.z - z) < 0.03 and abs(p.x) < 0.26 and abs(p.y - c.head.y) < 0.2:
                rx = max(rx, abs(p.x))
                ry = max(ry, abs(p.y - c.head.y))
    if rx == 0:
        rx, ry = 0.17, 0.12
    b = prim("torus", "Bandoleira", mat, Vector((0, c.head.y, z)), (2 * rx + 0.03, 2 * ry + 0.03, 1.4), rot=(0, 0.6, 0), minor=0.04)
    rigid(c, b, "spine_02")
    for k in range(3):   # facas de arremesso presas na correia
        t = -0.35 + k * 0.3
        p = Vector((t * rx * 1.6, c.head.y - ry - 0.02, z - t * rx * 1.1))
        kn = prim("box", "FacaArremesso", buckle or mat, p, (0.025, 0.012, 0.09), rot=(0, 0.6, 0))
        rigid(c, kn, "spine_02")


def sheaths(c, mat, metal):
    """Bainhas presas nas coxas."""
    for side, bone in ((1, "thigh_l"), (-1, "thigh_r")):
        hd, tl = K.bone_head(c.arm, bone), K.bone_tail(c.arm, bone)
        p = hd.lerp(tl, 0.45) + Vector((side * 0.085, 0.0, 0.0))
        sh = prim("box", "Bainha", mat, p, (0.035, 0.06, 0.2), rot=(0, side * 0.1, 0))
        rigid(c, sh, bone)
        cap = prim("box", "BainhaPonta", metal, p + Vector((0, 0, -0.105)), (0.04, 0.065, 0.025))
        rigid(c, cap, bone)


def pauldrons(c, mat, trim, spikes=None, size=0.14, gem=None):
    for side, bone in ((1, "upperarm_l"), (-1, "upperarm_r")):
        sh = K.bone_head(c.arm, bone)
        pad = prim("sphere", "Ombreira", mat, sh + Vector((side * 0.035, 0.0, 0.03)), (size, size, size * 0.7), rot=(0, side * 0.35, 0))
        rigid(c, pad, bone)
        rim = prim("torus", "OmbreiraBorda", trim, sh + Vector((side * 0.04, 0.0, 0.0)), (size * 0.95, size * 0.95, 1.0), rot=(0, side * 0.35, 0), minor=0.06)
        rigid(c, rim, bone)
        if gem is not None:
            g = prim("sphere", "GemaOmbro", gem, sh + Vector((side * 0.07, -0.05, 0.05)), (0.025, 0.025, 0.025))
            rigid(c, g, bone)
        if spikes is not None:
            for k in range(3):
                sp = prim("cone", "Espinho", spikes, sh + Vector((side * (0.04 + k * 0.025), -0.03 + k * 0.03, 0.08 - k * 0.01)),
                          (0.03, 0.03, 0.1 - k * 0.015), rot=(0.2 * (k - 1), side * 0.6, 0), seg=6)
                rigid(c, sp, bone)


# =================================================================== adagas

def assassin_mats(tier):
    """(lâmina, cabo, guarda, fio brilhante, curva) — as mesmas cores das adagas de make_heroes.py."""
    if tier == "comum":
        return (K.color_mat("adaga_comum", (0.78, 0.8, 0.84), metal=0.8, rough=0.35), K.color_mat("cabo_comum", (0.3, 0.2, 0.12)),
                K.color_mat("guarda_comum", (0.45, 0.4, 0.35), metal=0.5), None, False)
    if tier == "rara":
        return (K.color_mat("adaga_rara", (0.75, 0.88, 1.0), metal=0.8, rough=0.3), K.color_mat("cabo_raro", (0.15, 0.15, 0.2)),
                K.color_mat("guarda_rara", (0.3, 0.45, 0.8), metal=0.6), K.color_mat("fio_raro", (0.5, 0.8, 1.0), glow=3.0), False)
    if tier == "epica":
        return (K.color_mat("adaga_epica", (0.55, 0.25, 0.85), metal=0.6, rough=0.3), K.color_mat("cabo_epico", (0.08, 0.06, 0.1)),
                K.color_mat("guarda_epica", (0.2, 0.15, 0.25), metal=0.5), K.color_mat("fio_epico", PURPLE, glow=5.0), True)
    return (K.color_mat("adaga_lend", (1.0, 0.85, 0.4), metal=0.9, rough=0.25), K.color_mat("cabo_lend", (0.1, 0.08, 0.06)),
            K.color_mat("guarda_lend", GOLD, metal=0.9, rough=0.3), K.color_mat("fio_lend", (1.0, 0.9, 0.5), glow=5.0), False)


def dagger(name, tier):
    """Adaga montada no espaço da arma (cabo em +Z, lâmina para -Z), como _dagger() de make_heroes.py."""
    blade, grip, guard, glow, curved = assassin_mats(tier)
    length = 0.6 if tier == "comum" else 0.72
    objs = [prim("cyl", name + "Cabo", grip, Vector((0, 0, 0.04)), (0.07, 0.07, 0.26), seg=8),
            prim("box", name + "Guarda", guard, Vector((0, 0, -0.12)), (0.3, 0.07, 0.06))]
    if curved:
        for k in range(4):
            objs.append(prim("box", f"{name}Lamina{k}", blade, Vector((0.03 * k * k, 0, -0.2 - k * length / 4)),
                             (0.13 - k * 0.015, 0.03, length / 4 + 0.03), rot=(0, 0.12 * k, 0)))
    else:
        objs.append(prim("box", name + "Lamina", blade, Vector((0, 0, -0.15 - length / 2)), (0.12, 0.03, length)))
        objs.append(prim("cone", name + "Ponta", blade, Vector((0, 0, -0.15 - length - 0.07)), (0.14, 0.04, 0.16), rot=(math.pi, 0, 0), seg=4))
    if glow is not None:
        objs.append(prim("box", name + "Fio", glow, Vector((0, 0, -0.15 - length / 2)), (0.035, 0.035, length * 0.9)))
    if tier == "lendaria":
        wing = K.color_mat("asa_branca", WHITE)
        for s in (-1, 1):
            objs.append(prim("box", "AsaGuarda", wing, Vector((s * 0.24, 0, -0.06)), (0.22, 0.03, 0.1), rot=(0, s * 0.6, 0)))
    return join_parts(objs, name)


def join_parts(objs, name):
    """Junta peças soltas (cada uma com sua posição) numa malha só, com a origem no zero."""
    for o in objs:
        o.data.transform(o.matrix_basis)
        o.matrix_basis = Matrix.Identity(4)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    d = bpy.context.active_object
    d.name = name
    return d


def grip_matrix(c, side, scale=DAGGER_SCALE):
    """Matriz da pegada: centro da mão fechada, -Z saindo pelo lado do polegar (para onde vai a lâmina)."""
    bpy.context.view_layer.update()
    mw = c.arm.matrix_world
    pb = c.arm.pose.bones
    pts = []
    for f in ("index", "middle", "ring"):
        for k in ("01", "02", "03"):
            pts.append(mw @ pb[f"{f}_{k}_{side}"].head)
        pts.append(mw @ pb[f"{f}_03_{side}"].tail)
    grip = sum(pts, Vector()) / len(pts)
    axis = (mw.to_3x3() @ pb[f"middle_01_{side}"].matrix.to_3x3() @ Vector((1, 0, 0))).normalized()
    thumb = (mw @ pb[f"index_01_{side}"].head) - (mw @ pb[f"pinky_01_{side}"].head)
    if axis.dot(thumb) < 0:
        axis = -axis
    rot = Vector((0, 0, -1)).rotation_difference(axis).to_matrix().to_4x4()
    return Matrix.Translation(grip) @ rot @ Matrix.Scale(scale, 4)


def weapon_slots(c, tier):
    me = bpy.data.meshes.new("Weapon")   # malha minúscula: o Godot descarta nós vazios presos a ossos
    me.from_pydata([(0, 0, 0), (0.001, 0, 0), (0, 0.001, 0)], [], [(0, 1, 2)])
    e = bpy.data.objects.new("Weapon", me)
    bpy.context.collection.objects.link(e)
    e.matrix_world = grip_matrix(c, "r")
    K.attach_to_bone(e, c.arm, "hand_r")
    c.parts.append(e)
    left = dagger("AdagaEsquerda", tier)
    left.matrix_world = grip_matrix(c, "l")
    K.attach_to_bone(left, c.arm, "hand_l")
    c.parts.append(left)


# =================================================================== raridades

def comum(c):
    hood_m = K.color_mat("assassino_capuz", (0.62, 0.55, 0.42), rough=0.9)
    tunic = K.color_mat("assassino_tunica", (0.28, 0.25, 0.22), rough=0.9)
    pants = K.color_mat("assassino_calca", (0.2, 0.18, 0.16), rough=0.9)
    boot = K.color_mat("assassino_bota", (0.18, 0.12, 0.08), rough=0.8)
    wrap = K.color_mat("assassino_faixa", (0.55, 0.48, 0.36), rough=0.9)
    leather = K.color_mat("assassino_couro", (0.3, 0.2, 0.12), rough=0.8)
    metal = K.color_mat("assassino_fivela", (0.4, 0.35, 0.3), metal=0.6, rough=0.4)
    piece(c, c.tights, "Calca", ["pelvis"] + LEGS, pants, offset=0.004, zmin=c.ankle_z + 0.08)
    piece(c, c.tights, "Tunica", TORSO + UPPER, tunic, offset=0.01, zmin=c.hip_z - 0.06)
    piece(c, c.tights, "Faixas", LOWER + ["hand_l", "hand_r"], wrap, offset=0.008, thresh=0.5, zmax=c.elbow_z - 0.06)
    piece(c, c.tights, "Bota", ["calf_l", "calf_r"] + FEET, boot, offset=0.012, thresh=0.3, zmax=c.knee_z - 0.1)
    D.hood(c, hood_m, point=False)
    mask(c, hood_m)
    belt(c, leather, c.hip_z + 0.06, buckle=metal)
    sheaths(c, leather, metal)


def rara(c):
    jerk = K.color_mat("assassino_gibao", (0.36, 0.24, 0.14), rough=0.75)
    black = K.color_mat("assassino_negro", (0.1, 0.09, 0.1), rough=0.85)
    pants = K.color_mat("assassino_calca2", (0.16, 0.13, 0.12), rough=0.9)
    boot = K.color_mat("assassino_bota2", (0.22, 0.14, 0.08), rough=0.8)
    glove = K.color_mat("assassino_luva", (0.12, 0.1, 0.1), rough=0.8)
    strap = K.color_mat("assassino_correia", (0.25, 0.16, 0.1), rough=0.8)
    steel = K.color_mat("assassino_aco", (0.7, 0.7, 0.75), metal=0.8, rough=0.35)
    piece(c, c.tights, "Calca", ["pelvis"] + LEGS, pants, offset=0.004, zmin=c.ankle_z + 0.08)
    piece(c, c.tights, "Gibao", TORSO + UPPER + LOWER, jerk, offset=0.01, zmin=c.hip_z - 0.06)
    piece(c, c.tights, "Bota", ["calf_l", "calf_r"] + FEET, boot, offset=0.014, thresh=0.3, zmax=c.knee_z - 0.04)
    D.gloves(c, glove)
    D.hood(c, black, point=True)
    mask(c, black)
    D.cape(c, K.color_mat("assassino_capa_azul", (0.15, 0.25, 0.55), rough=0.8), 1.05, 0.44)
    belt(c, strap, c.hip_z + 0.06, buckle=steel)
    bandolier(c, strap, steel)
    sheaths(c, strap, steel)


def epica(c):
    armor = K.color_mat("assassino_armadura", (0.12, 0.1, 0.14), metal=0.5, rough=0.45)
    suit = K.color_mat("assassino_traje", (0.08, 0.07, 0.1), rough=0.7)
    glow = K.color_mat("assassino_brilho", PURPLE, glow=5.0)
    piece(c, c.tights, "Traje", TORSO + UPPER + LOWER + ["pelvis"] + LEGS, suit, offset=0.005, zmin=c.ankle_z + 0.05)
    piece(c, c.tights, "Peitoral", ["spine_02", "spine_03"], armor, offset=0.02, thresh=0.5)
    piece(c, c.tights, "Bota", ["calf_l", "calf_r"] + FEET, armor, offset=0.016, thresh=0.3, zmax=c.knee_z + 0.02)
    piece(c, c.tights, "Bracadeira", LOWER, armor, offset=0.014, thresh=0.5, zmax=c.elbow_z - 0.05)
    D.gloves(c, armor, 0.01)
    helmet(c, armor, glow)
    h, s = c.head, (c.head_top - c.head).length
    crest = prim("cone", "Crista", armor, c.head_top + Vector((0, s * 0.25, -s * 0.05)), (0.05, 0.22, 0.24), rot=(-0.5, 0, 0), seg=4)
    rigid(c, crest, "head")
    pauldrons(c, armor, armor, spikes=armor, gem=glow)
    gem = prim("sphere", "GemaPeito", glow, K.bone_head(c.arm, "spine_03") + Vector((0, -0.14, 0.02)), (0.04, 0.02, 0.04))
    rigid(c, gem, "spine_03")
    belt(c, armor, c.hip_z + 0.06, buckle=glow)
    D.cape(c, K.color_mat("assassino_capa_rasgada", (0.06, 0.05, 0.08), rough=0.8), 0.95, 0.42)


def lendaria(c):
    gold = K.color_mat("assassino_ouro", GOLD, metal=0.9, rough=0.3)
    black = K.color_mat("assassino_negro_lend", (0.08, 0.07, 0.08), rough=0.6)
    glow = K.color_mat("assassino_brilho_lend", (1.0, 0.85, 0.4), glow=5.0)
    piece(c, c.tights, "Traje", TORSO + UPPER + LOWER + ["pelvis"] + LEGS, black, offset=0.005, zmin=c.ankle_z + 0.05)
    piece(c, c.tights, "Peitoral", ["spine_01", "spine_02", "spine_03"], gold, offset=0.02, thresh=0.5)
    piece(c, c.tights, "Bota", ["calf_l", "calf_r"] + FEET, gold, offset=0.018, thresh=0.3, zmax=c.knee_z + 0.03)
    piece(c, c.tights, "Bracadeira", LOWER, gold, offset=0.014, thresh=0.5, zmax=c.elbow_z - 0.05)
    D.gloves(c, gold, 0.01)
    helmet(c, gold, glow)
    h, s = c.head, (c.head_top - c.head).length
    for k in range(5):  # crista de dragão, da testa até a nuca
        sc = prim("cone", "Escama", gold, c.head_top + Vector((0, -s * 0.15 + k * s * 0.17, -k * s * 0.09)),
                  (0.04, 0.1, 0.17 - k * 0.02), rot=(-0.7, 0, 0), seg=4)
        rigid(c, sc, "head")
    for side in (-1, 1):
        horn = prim("cone", "ChifreDragao", gold, c.head_top + Vector((side * s * 0.4, s * 0.15, -s * 0.2)),
                    (0.05, 0.05, 0.26), rot=(-0.6, side * 0.7, 0), seg=6)
        rigid(c, horn, "head")
    pauldrons(c, gold, black, spikes=gold, size=0.16)
    gem = prim("sphere", "GemaPeito", glow, K.bone_head(c.arm, "spine_03") + Vector((0, -0.15, 0.02)), (0.045, 0.022, 0.045))
    rigid(c, gem, "spine_03")
    belt(c, gold, c.hip_z + 0.06, buckle=glow)
    D.cape(c, K.color_mat("assassino_capa_dourada", (0.85, 0.62, 0.18), metal=0.3, rough=0.5), 1.15, 0.48, black)


# =================================================================== postura e animações
# Mesmas regras de sinal da Druida: braço/perna para frente = -X; joelho dobra = +X; tronco para frente = +X.

def build_base_pose(c):
    """Guarda de combate: tronco um pouco inclinado, as duas mãos fechadas nas adagas à frente do corpo."""
    pose = {
        "spine_01": [(X, 0.06)], "spine_03": [(X, 0.04)],
        "neck_01": [(X, -0.04)], "head": [(X, -0.04)],
        "clavicle_l": [(Y, 0.04)], "clavicle_r": [(Y, -0.04)],
        "upperarm_l": [(Y, 0.6), (X, -0.32)], "lowerarm_l": [(X, -1.2)],
        "upperarm_r": [(Y, -0.6), (X, -0.32)], "lowerarm_r": [(X, -1.2)],
    }
    for side in ("l", "r"):
        for b, ops in D.fist(side, 1.0).items():
            pose.setdefault(b, []).extend(ops)
    K.apply_pose(c.arm, pose)
    return pose


def anims(c):
    base_pose = build_base_pose(c)
    sin, cos, tau = math.sin, math.cos, math.tau

    def ease(x):
        x = min(max(x, 0.0), 1.0)
        return x * x * (3 - 2 * x)

    def legs(p, swing, knee, lift, bend=0.0):
        """Ciclo de pernas (igual ao da Druida) com joelhos um pouco dobrados (bend) o tempo todo."""
        out = {}
        for side, ph in (("l", 0.0), ("r", math.pi)):
            s, c_ = sin(p + ph), cos(p + ph)
            thigh = -swing * s - bend
            calf = 0.08 + 2 * bend + knee * max(0.0, c_) ** 2
            foot = -(thigh + calf) * 0.85 + lift * max(0.0, -s) * max(0.0, -c_)
            out[f"thigh_{side}"] = [(X, thigh)]
            out[f"calf_{side}"] = [(X, calf)]
            out[f"foot_{side}"] = [(X, foot)]
            out[f"ball_{side}"] = [(X, -0.35 * max(0.0, -s) * max(0.0, -c_))]
        return out

    def idle(t):
        # agachado e balançando de leve, como quem espera o bote
        b = sin(t * tau)
        b2 = sin(t * tau * 2 + 0.6)
        o = {"thigh_l": [(X, -0.32), (Y, 0.06)], "calf_l": [(X, 0.55)], "foot_l": [(X, -0.23)],
             "thigh_r": [(X, -0.12), (Y, -0.08)], "calf_r": [(X, 0.4)], "foot_r": [(X, -0.28)],
             "pelvis": [(Z, 0.12)], "spine_01": [(Z, -0.06), (X, -0.012 * b)], "spine_03": [(Z, -0.05), (X, -0.02 * b)],
             "head": [(Z, 0.1), (Z, 0.04 * sin(t * tau + 1.2))],
             "upperarm_l": [(X, -0.03 * b)], "upperarm_r": [(X, 0.03 * b2)],
             "lowerarm_l": [(X, -0.04 * b)], "lowerarm_r": [(X, -0.04 * b2)]}
        o["_loc"] = Vector((0, 0, -0.045 - 0.008 * (1 - cos(t * tau))))
        return o

    def walk(t):
        p = t * tau
        s = sin(p)
        o = legs(p, 0.4, 1.0, 0.45, 0.06)
        o.update({"pelvis": [(Z, -0.09 * s), (Y, 0.03 * cos(2 * p))],
                  "spine_01": [(Z, 0.05 * s), (X, 0.04)], "spine_03": [(Z, 0.06 * s)],
                  "neck_01": [(Z, -0.05 * s)], "head": [(Z, -0.04 * s)],
                  "upperarm_l": [(X, 0.22 * s)], "upperarm_r": [(X, 0.22 * s)],
                  "lowerarm_l": [(X, -0.1 * max(0.0, -s))], "lowerarm_r": [(X, -0.1 * max(0.0, s))]})
        o["_loc"] = Vector((0.012 * s, 0, -0.035 + 0.02 * cos(2 * p)))
        return o

    def run(t):
        # corrida baixa e inclinada, braços bombeando com as adagas
        p = t * tau
        s = sin(p)
        o = legs(p, 0.75, 1.8, 0.75, 0.08)
        o.update({"pelvis": [(Z, -0.12 * s), (X, 0.12)],
                  "spine_01": [(Z, 0.08 * s), (X, 0.18)], "spine_03": [(Z, 0.1 * s), (X, 0.1)],
                  "neck_01": [(X, -0.16), (Z, -0.08 * s)], "head": [(X, -0.1)],
                  "upperarm_l": [(X, 0.7 * s)], "upperarm_r": [(X, 0.7 * s)],
                  "lowerarm_l": [(X, -0.25 * max(0.0, -s))], "lowerarm_r": [(X, -0.25 * max(0.0, s))]})
        o["_loc"] = Vector((0.015 * s, 0, -0.08 + 0.05 * abs(cos(p))))
        return o

    def attack(t):
        # golpe duplo: corte da direita (0,1-0,4) e estocada da esquerda (0,4-0,65), com avanço do corpo
        wind = ease(t / 0.15) * (1 - ease((t - 0.15) / 0.15))
        cut = ease((t - 0.12) / 0.16) * (1 - ease((t - 0.45) / 0.4))
        stab = ease((t - 0.38) / 0.14) * (1 - ease((t - 0.62) / 0.38))
        lunge = ease(t / 0.3) * (1 - ease((t - 0.6) / 0.4))
        return {"spine_01": [(Z, 0.22 * wind - 0.28 * cut + 0.3 * stab), (X, 0.1 * lunge)],
                "spine_03": [(Z, 0.18 * wind - 0.22 * cut + 0.25 * stab), (X, 0.06 * lunge)],
                "head": [(Z, -0.15 * wind + 0.15 * cut - 0.2 * stab)],
                "upperarm_r": [(Y, 0.7 * wind - 0.2 * cut), (X, 0.25 * wind - 1.0 * cut)],
                "lowerarm_r": [(X, 0.5 * wind + 0.6 * cut)],
                "upperarm_l": [(X, 0.2 * wind - 1.05 * stab), (Y, -0.25 * stab)],
                "lowerarm_l": [(X, 1.05 * stab)],
                "thigh_l": [(X, -0.45 * lunge)], "calf_l": [(X, 0.4 * lunge)], "foot_l": [(X, 0.05 * lunge)],
                "thigh_r": [(X, 0.3 * lunge)], "calf_r": [(X, 0.2 * lunge)], "foot_r": [(X, -0.2 * lunge)],
                "pelvis": [(Z, 0.1 * wind - 0.12 * cut + 0.12 * stab)],
                "_loc": Vector((0, -0.1 * lunge, -0.06 * lunge))}

    K.write_actions(c.arm, {"idle": (48, idle, True), "walk": (32, walk, True), "run": (18, run, True),
                            "attack": (16, attack, False)}, base_pose)


# =================================================================== montagem

def finalize(c, tier):
    for o in [c.body] + c.parts:
        if o.type == "MESH":
            K.apply_modifiers(o)
    anims(c)
    weapon_slots(c, tier)
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
        D.render(c, tier, root, "assassino")
    K.export_glb(os.path.join(OUT, f"hero_assassino_{tier}.glb"), objs)


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
