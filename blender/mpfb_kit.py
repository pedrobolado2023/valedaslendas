"""
Ferramentas para criar personagens humanizados com o MPFB2 (MakeHuman Plugin For Blender, assets CC0).

Pré-requisitos (uma vez):
  1. Baixe o MPFB2: git clone https://github.com/makehumancommunity/mpfb2
  2. Instale como extensão do Blender (Edit > Preferences > Get Extensions > Install from disk,
     ou copie a pasta src/mpfb para <config do Blender>/extensions/user_default/mpfb e ative).
  3. Olhos: makehuman/data/eyes do repositório https://github.com/makehumancommunity/makehuman
     (defina a variável de ambiente MH_DATA apontando para essa pasta "data").

Convenções de saída (iguais às do resto do projeto):
  - personagem olhando para +Y no Blender (vira -Z no Godot), pés no chão, ~2,0 de altura;
  - animações "idle", "walk" e "attack" em faixas NLA;
  - nó "Weapon" preso à mão direita, com +Z apontando para onde a arma se estende.
"""
import importlib
import math
import os

import bpy  # noqa: F401  (carrega os módulos do Blender)
import addon_utils
import bmesh
import bpy
from mathutils import Matrix, Quaternion, Vector

MPFB = "bl_ext.user_default.mpfb"
MH_DATA = os.environ.get("MH_DATA", "")
HERO_SCALE = 1.25   # MPFB cria ~1,6 m; o herói do jogo tem ~2,0 unidades


def _svc(path, name):
    return getattr(importlib.import_module(MPFB + "." + path), name)


def enable():
    addon_utils.enable(MPFB, default_set=True)


def clear_scene():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for coll in (bpy.data.meshes, bpy.data.materials, bpy.data.armatures, bpy.data.actions, bpy.data.images):
        for d in list(coll):
            if d.users == 0:
                coll.remove(d)


def srgb_to_lin(c):
    return tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)


def color_mat(name, rgb, glow=0.0, rough=0.7, metal=0.0, tex=None):
    """Material com cor em sRGB (como num seletor de cores), convertida para linear."""
    rgb = srgb_to_lin(rgb)
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    if glow > 0.0:
        bsdf.inputs["Emission Color"].default_value = (*rgb, 1.0)
        bsdf.inputs["Emission Strength"].default_value = glow
    if tex:
        img = bpy.data.images.load(tex, check_existing=True)
        t = nt.nodes.new("ShaderNodeTexImage")
        t.image = img
        nt.links.new(t.outputs["Color"], bsdf.inputs["Base Color"])
    return m


# =================================================================== corpo

def create_body(macros, targets, rig="game_engine"):
    """Cria o humano, aplica formas (macros e alvos), esqueleto e olhos. Devolve (corpo, armadura, olhos)."""
    HS = _svc("services.humanservice", "HumanService")
    TS = _svc("services.targetservice", "TargetService")
    HOP = _svc("entities.objectproperties", "HumanObjectProperties")
    LS = _svc("services.locationservice", "LocationService")
    body = HS.create_human(detailed_helpers=True)
    for k, v in macros.items():
        HOP.set_value(k, v, entity_reference=body)
    TS.reapply_macro_details(body)
    troot = LS.get_mpfb_data("targets")
    for rel, w in targets.items():
        TS.load_target(body, os.path.join(troot, rel + ".target.gz"), weight=w)
    arm = HS.add_builtin_rig(body, rig)
    eyes = None
    mhclo = os.path.join(MH_DATA, "eyes", "high-poly", "high-poly.mhclo")
    if MH_DATA and os.path.exists(mhclo):
        eyes = HS.add_mhclo_asset(mhclo, body, asset_type="Eyes", subdiv_levels=0, material_type="MAKESKIN")
    return body, arm, eyes


def bake_shape_keys(obj):
    """Fixa o formato atual (todas as formas misturadas) e remove as shape keys."""
    if obj.data.shape_keys is None:
        return
    mix = obj.shape_key_add(name="__mix", from_mix=True)
    coords = [v.co.copy() for v in mix.data]
    obj.shape_key_clear()
    for v, c in zip(obj.data.vertices, coords):
        v.co = c


def _group_weights(obj, names):
    idx = {obj.vertex_groups[n].index for n in names if n in obj.vertex_groups}
    out = {}
    for v in obj.data.vertices:
        w = 0.0
        for g in v.groups:
            if g.group in idx:
                w = max(w, g.weight)
        out[v.index] = w
    return out


def keep_only(obj, groups, thresh=0.5, extra=None):
    """Apaga todos os vértices que não estão nos grupos (extra(v) pode decidir também)."""
    w = _group_weights(obj, groups)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.verts.ensure_lookup_table()
    kill = [v for v in bm.verts if w[v.index] < thresh or (extra and not extra(v))]
    bmesh.ops.delete(bm, geom=kill, context="VERTS")
    bm.to_mesh(obj.data)
    bm.free()


def delete_groups(obj, groups, thresh=0.5):
    w = _group_weights(obj, groups)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.verts.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if w[v.index] >= thresh], context="VERTS")
    bm.to_mesh(obj.data)
    bm.free()


def duplicate(obj, name):
    d = obj.copy()
    d.data = obj.data.copy()
    d.name = name
    d.data.name = name
    bpy.context.collection.objects.link(d)
    return d


def dominant_bone(obj, v, bones):
    best, bw = None, 0.0
    names = {obj.vertex_groups[i].name for i in range(len(obj.vertex_groups))}
    for g in v.groups:
        n = obj.vertex_groups[g.group].name
        if n in bones and g.weight > bw:
            best, bw = n, g.weight
    return best


def split_body(body):
    """Separa os moldes de roupa (tights e saia) e limpa o corpo das geometrias auxiliares."""
    for m in list(body.modifiers):
        if m.type == "MASK":
            body.modifiers.remove(m)
    bake_shape_keys(body)
    tights = duplicate(body, "Molde_Roupa")
    keep_only(tights, ["helper-tights"])
    skirt = duplicate(body, "Molde_Saia")
    keep_only(skirt, ["helper-skirt"])
    hairm = duplicate(body, "Molde_Cabelo")
    keep_only(hairm, ["helper-hair"])
    delete_groups(body, ["HelperGeometry", "JointCubes"])
    return tights, skirt, hairm


def region(obj, bones, thresh=0.35, zmin=None, zmax=None, keep_fn=None):
    """Recorta uma peça do molde: mantém vértices cujo peso somado nos ossos >= thresh (e dentro da faixa de altura)."""
    w = _group_weights(obj, bones)
    mw = obj.matrix_world
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.verts.ensure_lookup_table()
    kill = []
    for v in bm.verts:
        z = (mw @ v.co).z
        ok = w[v.index] >= thresh
        if zmin is not None and z < zmin:
            ok = False
        if zmax is not None and z > zmax:
            ok = False
        if keep_fn is not None and not keep_fn(mw @ v.co):
            ok = False
        if not ok:
            kill.append(v)
    bmesh.ops.delete(bm, geom=kill, context="VERTS")
    bm.to_mesh(obj.data)
    bm.free()


def inflate(obj, amount):
    """Empurra a peça para fora (ao longo das normais) para não atravessar o corpo."""
    obj.data.update()
    for v in obj.data.vertices:
        v.co += v.normal * amount


def finish_piece(obj, mat, thick=0.004, subdiv=1, offset=0.0):
    if offset:
        inflate(obj, offset)
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    for poly in obj.data.polygons:
        poly.use_smooth = True
    if thick > 0:
        md = obj.modifiers.new("Espessura", "SOLIDIFY")
        md.thickness = thick
        md.offset = 1.0
    if subdiv > 0:
        md = obj.modifiers.new("Suave", "SUBSURF")
        md.levels = subdiv
        md.render_levels = subdiv
    # mantém o modificador de esqueleto por último
    arm_mods = [m for m in obj.modifiers if m.type == "ARMATURE"]
    for m in arm_mods:
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_move_to_index(modifier=m.name, index=len(obj.modifiers) - 1)


def apply_modifiers(obj, keep=("ARMATURE",)):
    bpy.context.view_layer.objects.active = obj
    for m in list(obj.modifiers):
        if m.type in keep:
            continue
        try:
            bpy.ops.object.modifier_apply(modifier=m.name)
        except RuntimeError:
            obj.modifiers.remove(m)


def bind_to_body(obj, body, arm):
    """Copia os pesos do corpo para a peça (por proximidade) e liga no esqueleto."""
    for g in body.vertex_groups:
        if g.name not in obj.vertex_groups:
            obj.vertex_groups.new(name=g.name)
    dt = obj.modifiers.new("Pesos", "DATA_TRANSFER")
    dt.object = body
    dt.use_vert_data = True
    dt.data_types_verts = {"VGROUP_WEIGHTS"}
    dt.vert_mapping = "POLYINTERP_NEAREST"
    dt.layers_vgroup_select_src = "ALL"
    dt.layers_vgroup_select_dst = "NAME"
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=dt.name)
    am = obj.modifiers.new("Esqueleto", "ARMATURE")
    am.object = arm
    obj.parent = arm


def attach_to_bone(obj, arm, bone):
    """Prende uma peça rígida a um osso, mantendo a posição atual no mundo."""
    bpy.context.view_layer.update()
    mw = obj.matrix_world.copy()
    obj.parent = arm
    obj.parent_type = "BONE"
    obj.parent_bone = bone
    bpy.context.view_layer.update()
    obj.matrix_world = mw


def bone_head(arm, name):
    return arm.matrix_world @ arm.data.bones[name].head_local


def bone_tail(arm, name):
    return arm.matrix_world @ arm.data.bones[name].tail_local


def vgroup_center(obj, group, thresh=0.5):
    w = _group_weights(obj, [group])
    pts = [obj.matrix_world @ v.co for v in obj.data.vertices if w[v.index] >= thresh]
    if not pts:
        return Vector()
    return sum(pts, Vector()) / len(pts)


# =================================================================== animação (esqueleto game_engine)

def _q(arm, bone, axis, angle):
    """Rotação em torno de um eixo do mundo (pose de descanso) convertida para o espaço local do osso."""
    r = arm.data.bones[bone].matrix_local.to_quaternion()
    return r.inverted() @ Quaternion(axis, angle) @ r


AXES = {"X": Vector((1, 0, 0)), "Y": Vector((0, 1, 0)), "Z": Vector((0, 0, 1))}


def pose_rot(arm, bone, ops):
    """ops: lista de ("W", eixo_mundo, ângulo) | ("L", "X"/"Y"/"Z", ângulo) | ("Q", Quaternion local)
    (tuplas antigas (eixo, ângulo) valem como "W")."""
    q = Quaternion()
    for op in ops:
        if not isinstance(op[0], str):
            op = ("W",) + tuple(op)
        kind = op[0]
        if kind == "W":
            q = _q(arm, bone, op[1], op[2]) @ q
        elif kind == "L":
            q = Quaternion(AXES[op[1]], op[2]) @ q
        else:
            q = op[1] @ q
    return q


def apply_pose(arm, pose):
    for pb in arm.pose.bones:
        pb.rotation_mode = "QUATERNION"
        pb.rotation_quaternion = pose_rot(arm, pb.name, pose.get(pb.name, []))
    bpy.context.view_layer.update()


def write_actions(arm, anims, base_pose):
    """anims: {nome: (frames, fn(t) -> {osso: [ops...], "_loc": Vector}, loop)}; base_pose: {osso: [ops...]}"""
    ad = arm.animation_data_create()
    for name, (length, fn, loop) in anims.items():
        act = bpy.data.actions.new(name)
        ad.action = act
        steps = length
        for i in range(steps + 1):
            t = i / steps
            frame = i
            pose = {b: list(v) for b, v in base_pose.items()}
            extra = fn(t)
            loc = extra.pop("_loc", Vector((0, 0, 0)))
            for b, ops in extra.items():
                pose.setdefault(b, []).extend(ops)
            for pb in arm.pose.bones:
                pb.rotation_mode = "QUATERNION"
                pb.rotation_quaternion = pose_rot(arm, pb.name, pose.get(pb.name, []))
                pb.keyframe_insert("rotation_quaternion", frame=frame)
            root = arm.pose.bones["pelvis"]
            root.location = arm.data.bones["pelvis"].matrix_local.to_quaternion().inverted() @ loc
            root.keyframe_insert("location", frame=frame)
        tr = ad.nla_tracks.new()
        tr.name = name
        st = tr.strips.new(name, 0, act)
        st.name = name
        ad.action = None
    apply_pose(arm, base_pose)
    for pb in arm.pose.bones:
        pb.location = (0, 0, 0)


def export_glb(path, objs):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_yup=True,
                              export_cameras=False, export_lights=False, export_animations=True,
                              export_animation_mode="NLA_TRACKS", export_skins=True, export_apply=False)
    print("OK", path)
