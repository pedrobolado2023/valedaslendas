"""
Põe o esqueleto e as animações de um herói do jogo num modelo 3D de IA (malha única, já reduzida e pintada por
tools/ai_prep_glb.py).
  blender -b -P tools/ai_rig.py -- <hero_base.glb> <modelo_ia.glb> <saida.glb> [lado_da_arma=r]

Como funciona:
 1. Importa o esqueleto do herói (A, com todas as animações) e o modelo de IA (vira para +Y como os heróis).
 2. Copia o esqueleto (B) e move as juntas de B para dentro do modelo (tornozelos, joelhos, punhos, cotovelos medidos
    na própria malha).
 3. Pesa cada vértice nos ossos mais próximos de B (a arma longa e fina vai 100% para a mão; a capa para o tronco).
 4. Põe B na pose de descanso de A e "assa" a malha nessa pose: a malha fica com o formato de descanso de A.
 5. Prende a malha em A (mesmos nomes de osso) e exporta A + malha + todas as animações de A.
"""
import math
import sys

import bpy
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
base_path, mesh_path, out_path = args[0], args[1], args[2]
WSIDE = args[3] if len(args) > 3 else "r"
SPEAR_R = float(args[4]) if len(args) > 4 else 0.08   # raio da faixa da arma (enfeites mais grossos que a haste)
import os
SMOOTH = int(os.environ.get("AI_SMOOTH", "12"))   # passadas de suavização dos pesos
CAPE_AMP = float(os.environ.get("AI_CAPE", "0.35"))   # quanto do balanço da capa do herói base fica (0..1)
# Opções por variável de ambiente (arma que não é haste em pé):
#   AI_WTIP="x,y,z"  ponta da arma (mundo, modelo já virado para +Y); sem isto = topo da haste (z > 1,75)
#   AI_TMIN=-1.1     até onde a arma vai para trás da mão (em comprimentos mão→ponta; espada ~ -0,15)
#   AI_WSIGN=1       ponta da arma do herói base = +Z do nó Weapon (Druida) ou -1 = -Z (Assassino, Náutico)
#   AI_NOWEAPON=1    não alinha nem separa arma (ex.: arco)
#   AI_LOCK="osso:xmin,xmax,ymin,ymax,zmin,zmax;..."  vértices nessas caixas vão 100% para o osso (escudo, arco)
WTIP = Vector([float(x) for x in os.environ["AI_WTIP"].split(",")]) if os.environ.get("AI_WTIP") else None
TMIN = float(os.environ.get("AI_TMIN", "-1.1"))
WSIGN = float(os.environ.get("AI_WSIGN", "1"))
NOWEAPON = os.environ.get("AI_NOWEAPON", "") != ""
LOCKS = []
for part in filter(None, os.environ.get("AI_LOCK", "").split(";")):
    bn, bx = part.split(":")
    LOCKS.append((bn, [float(x) for x in bx.split(",")]))

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=base_path)
A = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]
for o in list(bpy.data.objects):          # só o esqueleto, as animações e o nó "Weapon" (encaixe da arma) do herói
    if o.type == "MESH" and not o.name.startswith("Weapon"):
        bpy.data.objects.remove(o, do_unlink=True)
before = set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=mesh_path)
M = [o for o in bpy.data.objects if o not in before and o.type == "MESH"][0]
M.parent = None
bpy.ops.object.select_all(action="DESELECT")
M.select_set(True)
bpy.context.view_layer.objects.active = M
M.rotation_mode = "XYZ"   # o importador deixa em quatérnio (aí o giro abaixo seria ignorado)
M.rotation_euler = (0, 0, M.rotation_euler.z + math.pi)   # o modelo de IA olha para o outro lado
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
bpy.context.view_layer.update()

AW = A.matrix_world
AWi = AW.inverted()
vs = [v.co.copy() for v in M.data.vertices]      # mundo (malha sem transformação)


def box_mean(pred):
    pts = [v for v in vs if pred(v)]
    if not pts:
        return None
    return sum(pts, Vector()) / len(pts)


def rest_world(name):
    b = A.data.bones[name]
    return AW @ b.head_local, AW @ b.tail_local


# ------------------------------------------------------------------ juntas medidas na malha
S = {"l": -1.0, "r": 1.0}                       # esquerda do herói = -X
_ys = sorted(v.y for v in vs if 0.9 < v.z < 1.3)
FRONT_Y = _ys[len(_ys) // 3]                     # 1/3 de trás é capa: ignora nas medidas de mãos e arma
J = {}
for sd, sg in S.items():
    ank = box_mean(lambda v, sg=sg: 0.05 < v.z < 0.16 and v.x * sg > 0.04 and abs(v.x) < 0.45)
    knee = box_mean(lambda v, sg=sg: 0.5 < v.z < 0.62 and v.x * sg > 0.03 and abs(v.x) < 0.42)
    J["calf_" + sd] = knee
    J["foot_" + sd] = ank
sh_l, _ = rest_world("upperarm_l")
sh_r, _ = rest_world("upperarm_r")
# punhos: a mão da arma (perto da haste) e a mão livre (mais baixa e para fora)
for sd, sg in S.items():
    hand = box_mean(lambda v, sg=sg: 0.85 < v.z < 1.12 and v.x * sg > 0.3 and v.y > FRONT_Y)
    J["hand_" + sd] = hand
    sh = sh_l if sd == "l" else sh_r
    el = sh.lerp(hand, 0.5)
    el += Vector((sg * 0.03, -0.04, 0.0))                  # cotovelo um pouco para fora e para trás
    J["lowerarm_" + sd] = el
print("juntas", {k: tuple(round(x, 2) for x in v) for k, v in J.items() if v is not None})

# ------------------------------------------------------------------ esqueleto B encaixado na malha
bpy.ops.object.select_all(action="DESELECT")
A.select_set(True)
bpy.context.view_layer.objects.active = A
bpy.ops.object.duplicate()
B = bpy.context.active_object
B.name = "Encaixe"
B.animation_data_clear()
CHILD_OF = {"thigh": "calf", "calf": "foot", "upperarm": "lowerarm", "lowerarm": "hand"}
bpy.ops.object.mode_set(mode="EDIT")
eb = B.data.edit_bones
order = []


def walk(b):
    order.append(b.name)
    for c in b.children:
        walk(c)


for b in eb:
    if b.parent is None:
        walk(b)
delta = {}
for name in order:
    b = eb[name]
    old_h, old_t = b.head.copy(), b.tail.copy()
    tgt = J.get(name)
    if tgt is not None:
        nh = AWi @ tgt
    elif b.parent is not None:
        nh = old_h + delta[b.parent.name]
    else:
        nh = old_h
    delta[name] = nh - old_h
    nt = old_t + delta[name]
    base_n, _, sd = name.rpartition("_")
    nxt = CHILD_OF.get(base_n)
    if nxt and J.get(nxt + "_" + sd) is not None:
        nt = AWi @ J[nxt + "_" + sd]
    if name.startswith("hand_") and J.get(name) is not None:   # mão segue a direção do antebraço
        d = (AWi @ J[name]) - (AWi @ J["lowerarm_" + sd])
        nt = nh + d.normalized() * (old_t - old_h).length
    b.head, b.tail = nh, nt
# mão da arma (e dedos): orientação escolhida para que, ao assar na descanso de A, a haste da IA fique no
# eixo do nó "Weapon" de A (onde o jogo põe a arma, em pé na pose parada)
Wn = next((o for o in bpy.data.objects if o.name.startswith("Weapon")), None)
_top = WTIP if WTIP is not None else box_mean(lambda v: v.z > 1.75 and v.x * S[WSIDE] > 0.3)
# cabo: "x,y,z", ou "box" = pé da haste perto do chão (lança/cajado em pé, como o Lanceiro)
_g = os.environ.get("AI_WGRIP", "")
if _g == "box":
    WGRIP = box_mean(lambda v: 0.15 < v.z < 0.3 and v.x * S[WSIDE] > 0.22 and v.y > FRONT_Y)
    TMIN = max(TMIN, -0.15)
else:
    WGRIP = Vector([float(x) for x in _g.split(",")]) if _g else None
_bot = WGRIP if WGRIP is not None else J["hand_" + WSIDE]
if Wn is not None and _top is not None and not NOWEAPON:
    from mathutils import Matrix
    A.data.pose_position = "REST"
    bpy.context.view_layer.update()
    WMa = AWi @ Wn.matrix_world                                  # nó Weapon no espaço do esqueleto
    A.data.pose_position = "POSE"
    w_axis = (WMa.to_3x3() @ Vector((0, 0, WSIGN))).normalized()
    w_grip = WMa.translation
    ax = (AWi.to_3x3() @ (_top - _bot)).normalized()
    hw = AWi @ J["hand_" + WSIDE]
    b0 = AWi @ _bot
    g_ai = b0 + ax * (hw - b0).dot(ax)                           # ponto da haste na mão (modelo de IA)
    T = Matrix.Translation(w_grip) @ ax.rotation_difference(w_axis).to_matrix().to_4x4() @ Matrix.Translation(-g_ai)
    Ti = T.inverted()
    hn = "hand_" + WSIDE
    chain = [hn] + [c.name for c in eb[hn].children_recursive]
    for n in chain:
        ln = eb[n].length
        eb[n].matrix = Ti @ A.data.bones[n].matrix_local
        eb[n].length = ln
    eb["lowerarm_" + WSIDE].tail = eb[hn].head.copy()
    print("mao da arma alinhada ao no Weapon")
bpy.ops.object.mode_set(mode="OBJECT")

# ------------------------------------------------------------------ pesos
MAIN = ["pelvis", "spine_01", "spine_02", "spine_03", "neck_01", "head", "clavicle_l", "clavicle_r",
        "upperarm_l", "lowerarm_l", "hand_l", "upperarm_r", "lowerarm_r", "hand_r",
        "thigh_l", "calf_l", "foot_l", "ball_l", "thigh_r", "calf_r", "foot_r", "ball_r"]
CAPE = [n for n in ("cape_01", "cape_02", "cape_03") if n in B.data.bones]
segs = {}
BW = B.matrix_world
for n in MAIN + CAPE:
    if n in B.data.bones:
        bb = B.data.bones[n]
        segs[n] = (BW @ bb.head_local, BW @ bb.tail_local)


def seg_dist(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-9)))
    return (p - (a + ab * t)).length


# arma longa: reta pelo topo e pela base da haste do lado da arma
sg = S[WSIDE]
hand_w = J["hand_" + WSIDE]
top = None if NOWEAPON else (WTIP if WTIP is not None else box_mean(lambda v: v.z > 1.75 and v.x * sg > 0.3))
bot = WGRIP if WGRIP is not None else hand_w
print("arma ponta", top, "mao", bot, "frente_y", FRONT_Y)
back_y = box_mean(lambda v: 1.2 < v.z < 1.45 and abs(v.x) < 0.12)


def is_spear(p):
    if top is None or bot is None:
        return False
    ax = top - bot
    L = ax.length
    t = (p - bot).dot(ax) / (L * L)
    return TMIN < t < 1.12 and (p - (bot + ax * t)).length < SPEAR_R


def lock_bone(p):
    for bn, b in LOCKS:
        if b[0] < p.x < b[1] and b[2] < p.y < b[3] and b[4] < p.z < b[5]:
            return bn
    return None


# ------------------------------------------------------------------ arma longa: corta as faces que ligam a haste ao corpo
import bmesh
bm = bmesh.new()
bm.from_mesh(M.data)
sp_set = {v.index for v in bm.verts if is_spear(v.co)}
near_hand = {v.index for v in bm.verts if (Vector(v.co) - hand_w).length < 0.1}
bad = [f for f in bm.faces if any(v.index in sp_set for v in f.verts) and any(v.index not in sp_set and v.index not in near_hand for v in f.verts)]
lk_of = {v.index: lock_bone(v.co) for v in bm.verts} if LOCKS else {}
if LOCKS:                                  # peças presas (escudo, arco): solta das partes que não vão junto
    bad += [f for f in bm.faces if f not in bad and len({lk_of[v.index] for v in f.verts}) > 1]
bmesh.ops.delete(bm, geom=bad, context="FACES_ONLY")
bm.to_mesh(M.data)
bm.free()
print("faces cortadas entre arma e corpo:", len(bad))
groups = {n: M.vertex_groups.new(name=n) for n in segs}
spear = cape = 0
import numpy as np
names = list(segs)
col_of = {n: k for k, n in enumerate(names)}
Wt = np.zeros((len(vs), len(names)), np.float32)
pinned = np.zeros(len(vs), bool)
for i, p in enumerate(vs):
    ws = {}
    on_spear = is_spear(p) or (top is not None and (p - hand_w).length < 0.07)
    lk = lock_bone(p)
    if lk is not None:
        ws = {lk: 1.0}
    elif on_spear:
        ws = {"hand_" + WSIDE: 1.0}
        spear += 1
    else:
        is_cape = CAPE and p.y < back_y.y - 0.1 and 0.15 < p.z < 1.55 and abs(p.x) < 0.42
        cand = CAPE + ["spine_03", "spine_02"] if is_cape else MAIN
        if is_cape:
            cape += 1
        dl = sorted(((seg_dist(p, *segs[n]), n) for n in cand if n in segs))[:4]
        tot = 0.0
        for d, n in dl:
            w = 1.0 / (d + 0.03) ** 3
            ws[n] = w
            tot += w
        ws = {n: w / tot for n, w in ws.items()}
    pinned[i] = lk is not None or on_spear   # arma e peças presas não entram na suavização
    for n, w in ws.items():
        Wt[i, col_of[n]] = w

# pesos suaves: média com os vizinhos da malha várias vezes (peso que muda de repente = pele/roupa esticando)
ev = np.array([(e.vertices[0], e.vertices[1]) for e in M.data.edges], np.int64)
deg = np.bincount(ev.ravel(), minlength=len(vs)).astype(np.float32)
for _ in range(SMOOTH):
    acc = np.zeros_like(Wt)
    np.add.at(acc, ev[:, 0], Wt[ev[:, 1]])
    np.add.at(acc, ev[:, 1], Wt[ev[:, 0]])
    nb = deg > 0
    new = Wt.copy()
    new[nb] = 0.5 * Wt[nb] + 0.5 * acc[nb] / deg[nb][:, None]
    new[pinned] = Wt[pinned]
    Wt = new
for i in range(len(vs)):
    row = Wt[i]
    top4 = np.argsort(row)[-4:]
    tot = float(row[top4].sum())
    for k in top4:
        if row[k] > 1e-4:
            groups[names[k]].add([i], float(row[k]) / tot, "REPLACE")
print("vertices", len(vs), "arma", spear, "capa", cape, "suavizacao", SMOOTH)

# ------------------------------------------------------------------ assa a malha na pose de descanso de A
md = M.modifiers.new("Encaixe", "ARMATURE")
md.object = B
bpy.ops.object.select_all(action="DESELECT")
B.select_set(True)
bpy.context.view_layer.objects.active = B
bpy.ops.object.mode_set(mode="POSE")
for name in order:
    pb = B.pose.bones[name]
    pb.matrix = A.data.bones[name].matrix_local.copy()
    bpy.context.view_layer.update()
bpy.ops.object.mode_set(mode="OBJECT")
bpy.context.view_layer.objects.active = M
bpy.ops.object.modifier_apply(modifier=md.name)
bpy.data.objects.remove(B, do_unlink=True)
md2 = M.modifiers.new("Esqueleto", "ARMATURE")
md2.object = A
M.parent = A
M.matrix_parent_inverse = AW.inverted()
M.name = "Corpo"

# balanço da capa do herói base é forte demais para roupa grudada no corpo: chega cada quadro perto do repouso
from mathutils import Quaternion
for act in bpy.data.actions:
    fcs = []
    for layer in getattr(act, "layers", []):
        for strip in layer.strips:
            for bag in getattr(strip, "channelbags", []):
                fcs.extend(bag.fcurves)
    if not fcs and hasattr(act, "fcurves"):
        fcs = list(act.fcurves)
    for bn in CAPE:
        q = sorted((f for f in fcs if f.data_path == 'pose.bones["%s"].rotation_quaternion' % bn), key=lambda f: f.array_index)
        if len(q) != 4:
            continue
        for k in range(len(q[0].keyframe_points)):
            cur = Quaternion([q[j].keyframe_points[k].co[1] for j in range(4)])
            r = Quaternion().slerp(cur, CAPE_AMP)
            for j in range(4):
                kp = q[j].keyframe_points[k]
                kp.co[1] = kp.handle_left[1] = kp.handle_right[1] = r[j]
        for f in q:
            f.update()
bpy.ops.object.select_all(action="DESELECT")
for o in bpy.data.objects:
    o.select_set(True)
bpy.ops.export_scene.gltf(filepath=out_path, export_format="GLB", use_selection=True, export_animations=True,
                          export_animation_mode="ACTIONS", export_skins=True, export_vertex_color="ACTIVE")
print("OK", out_path)
