"""
Troca as animações de um herói de IA (feito por tools/ai_rig.py) pelas de outro herói do jogo, corrigindo a mão da
arma para a arma do modelo seguir a direção da arma do outro herói.
  blender -b -P tools/ai_anims.py -- <heroi_ia.glb> <fonte_das_animacoes.glb> <saida.glb> [inverter_arma=1]

Ex.: Lanceiro (esqueleto e pose da Druida, lança em pé) com as animações do Náutico (tridente para a frente,
estocadas): a rotação de cada quadro da mão direita ganha um giro fixo Q que leva o eixo da lança (nó "Weapon" do
Lanceiro, +Z) até o eixo do tridente (nó "Weapon" do Náutico, a ponta é -Z).
"""
import sys

import bpy
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
hero_path, src_path, out_path = args[0], args[1], args[2]
FLIP_SRC = (args[3] != "0") if len(args) > 3 else True       # a ponta da arma da fonte é -Z do nó Weapon
HAND = "hand_r"


def weapon_dir_in_hand(arm, sign):
    """Direção da ponta da arma (eixo Z do nó Weapon × sign) no espaço local do osso da mão, na pose de descanso."""
    w = next(o for o in bpy.data.objects if o.name.startswith("Weapon") and o.parent == arm)
    arm.data.pose_position = "REST"
    bpy.context.view_layer.update()
    wm = w.matrix_world.to_3x3().normalized()
    hm = (arm.matrix_world @ arm.data.bones[HAND].matrix_local).to_3x3().normalized()
    arm.data.pose_position = "POSE"
    return (hm.inverted() @ (wm @ Vector((0, 0, sign)))).normalized()


bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=hero_path)
A = next(o for o in bpy.data.objects if o.type == "ARMATURE")
d_hero = weapon_dir_in_hand(A, 1.0)
if A.animation_data:
    A.animation_data.action = None
for act in list(bpy.data.actions):          # tira as animações antigas (da Druida)
    bpy.data.actions.remove(act)
hero_objs = set(bpy.data.objects)

bpy.ops.import_scene.gltf(filepath=src_path)
N = next(o for o in bpy.data.objects if o.type == "ARMATURE" and o not in hero_objs)
d_src = weapon_dir_in_hand(N, -1.0 if FLIP_SRC else 1.0)
Q = d_hero.rotation_difference(d_src)
print("giro da mão:", tuple(round(x, 3) for x in Q))
for o in [o for o in bpy.data.objects if o not in hero_objs]:
    bpy.data.objects.remove(o, do_unlink=True)

path = 'pose.bones["%s"].rotation_quaternion' % HAND


def all_fcurves(act):
    """Curvas da ação (Blender 5: ficam dentro de camadas/faixas/"channelbags")."""
    if hasattr(act, "fcurves") and act.fcurves:
        return list(act.fcurves)
    out = []
    for layer in getattr(act, "layers", []):
        for strip in layer.strips:
            for bag in getattr(strip, "channelbags", []):
                out.extend(bag.fcurves)
    return out
from mathutils import Quaternion
for act in bpy.data.actions:
    act.use_fake_user = True
    fcs = sorted((fc for fc in all_fcurves(act) if fc.data_path == path), key=lambda f: f.array_index)
    if len(fcs) != 4:
        continue
    n = len(fcs[0].keyframe_points)
    for k in range(n):
        q = Quaternion([fcs[i].keyframe_points[k].co[1] for i in range(4)])
        q2 = q @ Q
        for i in range(4):
            fcs[i].keyframe_points[k].co[1] = q2[i]
            fcs[i].keyframe_points[k].handle_left[1] = q2[i]
            fcs[i].keyframe_points[k].handle_right[1] = q2[i]
    for fc in fcs:
        fc.update()
# balanço da capa reduzido como no ai_rig.py (AI_CAPE)
import os
CAPE_AMP = float(os.environ.get("AI_CAPE", "0.35"))
for act in bpy.data.actions:
    for bn in ("cape_01", "cape_02", "cape_03"):
        q = sorted((f for f in all_fcurves(act) if f.data_path == 'pose.bones["%s"].rotation_quaternion' % bn), key=lambda f: f.array_index)
        if len(q) != 4:
            continue
        for k in range(len(q[0].keyframe_points)):
            r = Quaternion().slerp(Quaternion([q[j].keyframe_points[k].co[1] for j in range(4)]), CAPE_AMP)
            for j in range(4):
                kp = q[j].keyframe_points[k]
                kp.co[1] = kp.handle_left[1] = kp.handle_right[1] = r[j]
        for f in q:
            f.update()
print("animacoes:", sorted(a.name for a in bpy.data.actions))
A.animation_data_create()
A.animation_data.action = bpy.data.actions.get("idle")
bpy.ops.object.select_all(action="DESELECT")
for o in bpy.data.objects:
    o.select_set(True)
bpy.ops.export_scene.gltf(filepath=out_path, export_format="GLB", use_selection=True, export_animations=True,
                          export_animation_mode="ACTIONS", export_skins=True, export_vertex_color="ACTIVE")
print("OK", out_path)
