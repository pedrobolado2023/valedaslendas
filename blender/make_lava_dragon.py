"""Dragão de Lava (boss global) a partir do modelo do Gemini (dragon_boss.html).
1) A malha é extraída do HTML com Node (tools/dragon_extract: `node gen.mjs dragon_raw.glb`).
2) Este script reduz a malha, guarda a posição de repouso nos UVs (para o shader de lava do Godot desenhar as
   rachaduras presas ao corpo), cria o esqueleto pela forma do corpo, pesa e grava idle/walk/attack.
Rodar: blender -b -P blender/make_lava_dragon.py -- <dragon_raw.glb>
Saída: models/dragon_lava.glb (olha para +Y, pés em z=0, mesmo tamanho do dragon_ancient)."""
import math
import os
import sys

import bpy
from mathutils import Vector

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "models", "dragon_lava.glb")
SRC = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else os.path.join(ROOT, "dragon_raw.glb")

# tipo de cada peça -> (material, código do brilho no shader: 0 = sem lava)
KIND = [("Dragon_Body", "lava_body", 1.0), ("Spike", "lava_bone", 0.3), ("Horn", "lava_horn", 0.4),
        ("Membrane", "lava_wing", 0.8), ("WingArm", "lava_bone", 0.3), ("Wrist", "lava_bone", 0.3),
        ("Finger", "lava_bone", 0.3), ("Tooth", "dente", 0.0), ("Claw", "garra", 0.0), ("Eye", "olho", 0.0),
        ("MouthGlow", "boca", 0.0)]
COLORS = {"lava_body": (0.29, 0.25, 0.23), "lava_bone": (0.17, 0.14, 0.13), "lava_horn": (0.23, 0.18, 0.16),
          "lava_wing": (0.23, 0.07, 0.03), "dente": (0.9, 0.84, 0.72), "garra": (0.11, 0.09, 0.07),
          "olho": (1.0, 0.7, 0.12), "boca": (1.0, 0.42, 0.08)}


def kind_of(name):
    for k, m, g in KIND:
        if k in name:
            return m, g
    return "lava_bone", 0.3


def material(name):
    if name in bpy.data.materials:
        return bpy.data.materials[name]
    m = bpy.data.materials.new(name)
    c = COLORS[name]
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    lin = tuple(x ** 2.2 for x in c)
    b.inputs["Base Color"].default_value = lin + (1.0,)
    if name in ("olho", "boca"):
        b.inputs["Emission Color"].default_value = lin + (1.0,)
        b.inputs["Emission Strength"].default_value = 4.0
    return m


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    # tamanho do dragão antigo (o jogo usa escala 3,4 nele)
    bpy.ops.import_scene.gltf(filepath=os.path.join(ROOT, "models", "dragon_ancient.glb"))
    old = [o for o in bpy.data.objects if o.type == "MESH"]
    zs = [(o.matrix_world @ Vector(c)).z for o in old for c in o.bound_box]
    old_h = max(zs) - min(zs)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()
    bpy.ops.import_scene.gltf(filepath=SRC)
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    for o in meshes:
        bpy.context.view_layer.objects.active = o
        o.select_set(True)
        bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
        o.select_set(False)
    for o in list(bpy.data.objects):
        if o.type != "MESH":
            bpy.data.objects.remove(o)
    for o in meshes:   # peças repetidas dividem a mesma malha: cada uma ganha a sua
        o.data = o.data.copy()
    # gira para olhar +Y (o Gemini olha +X) e escala para a altura do antigo
    zs = [(o.matrix_world @ Vector(c)).z for o in meshes for c in o.bound_box]
    s = old_h / (max(zs) - min(zs))
    for o in meshes:
        o.matrix_world = __import__("mathutils").Matrix.Rotation(math.pi / 2, 4, "Z") @ __import__("mathutils").Matrix.Scale(s, 4) @ o.matrix_world
        bpy.context.view_layer.objects.active = o
        o.select_set(True)
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        o.select_set(False)
    # reduz o corpo (63 mil triângulos)
    for o in meshes:
        if "Dragon_Body" in o.name:
            md = o.modifiers.new("Dec", "DECIMATE")
            md.ratio = 0.22
            bpy.context.view_layer.objects.active = o
            bpy.ops.object.modifier_apply(modifier="Dec")
    # material por tipo + posição de repouso nos UVs (UV0 = x,y; UV1 = z, brilho) + grupo da asa
    wing_parts = {"L": [], "R": []}
    for o in meshes:
        mname, glow = kind_of(o.name)
        o.data.materials.clear()
        o.data.materials.append(material(mname))
        me = o.data
        while me.uv_layers:
            me.uv_layers.remove(me.uv_layers[0])
        u0 = me.uv_layers.new(name="UVMap")
        u1 = me.uv_layers.new(name="Rest")
        for loop in me.loops:
            co = me.vertices[loop.vertex_index].co
            u0.data[loop.index].uv = (co.x, co.y)
            u1.data[loop.index].uv = (co.z, glow)
        if not me.color_attributes:
            ca = me.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
            for d in ca.data:
                d.color = (1, 1, 1, 1)
        for p in me.polygons:
            p.use_smooth = True
        cx = sum((v.co.x for v in me.vertices)) / max(1, len(me.vertices))
        is_wing = any(k in o.name for k in ("Membrane", "WingArm", "Wrist", "Finger", "ThumbClaw")) or (
            "Claw" in o.name and abs(cx) > 1.0 and sum(v.co.z for v in me.vertices) / len(me.vertices) > 2.0)
        if is_wing:
            side = "L" if cx > 0 else "R"
            wing_parts[side].append(o)
            g = o.vertex_groups.new(name="wing_" + side)
            g.add(list(range(len(me.vertices))), 1.0, "REPLACE")
    body = next(o for o in meshes if "Dragon_Body" in o.name)
    bverts = [v.co.copy() for v in body.data.vertices]
    ymin = min(v.y for v in bverts)
    ymax = max(v.y for v in bverts)
    L = ymax - ymin

    def spine_at(y, low):
        sl = [v for v in bverts if abs(v.y - y) < L * 0.03 and abs(v.x) < L * 0.05 and v.z > low]
        if not sl:
            sl = [v for v in bverts if abs(v.y - y) < L * 0.05]
        zs_ = sorted(v.z for v in sl)
        return Vector((0.0, y, (zs_[0] + zs_[-1]) * 0.5))

    # pés: vértices baixos agrupados por lado (x) e frente/trás (y)
    low = [v for v in bverts if v.z < (max(v.z for v in bverts)) * 0.12]
    ymed = sorted(v.y for v in low)[len(low) // 2]
    feet = {}
    for side in ("L", "R"):
        for fb in ("F", "B"):
            g = [v for v in low if (v.x > 0) == (side == "L") and (v.y > ymed) == (fb == "F")]
            c = sum(g, Vector()) / len(g)
            feet[fb + side] = Vector((c.x, c.y, 0.05))
    leg_z = max(f.y for f in feet.values())
    hip_low = (max(v.z for v in bverts)) * 0.3

    arm_data = bpy.data.armatures.new("DragonRig")
    arm = bpy.data.objects.new("DragonRig", arm_data)
    bpy.context.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    arm.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm_data.edit_bones
    rootb = eb.new("root")
    rootb.head = Vector((0, 0, 0))
    rootb.tail = Vector((0, L * 0.08, 0))

    def chain(names, pts, parent):
        prev = parent
        for i, n in enumerate(names):
            b = eb.new(n)
            b.head, b.tail = pts[i], pts[i + 1]
            b.parent = prev
            b.use_connect = i > 0
            prev = b
        return prev

    yb = feet["BL"].y
    yf = feet["FL"].y
    y_neck = yf + (ymax - yf) * 0.25
    y_head = ymax - L * 0.12
    sp_pts = [spine_at(yb + (y_neck - yb) * t, hip_low) for t in (0, 0.33, 0.66, 1.0)]
    pelvis = eb.new("pelvis")
    pelvis.head = sp_pts[0] + Vector((0, -L * 0.04, 0))
    pelvis.tail = sp_pts[0]
    pelvis.parent = rootb
    chain(["spine1", "spine2", "spine3"], sp_pts, pelvis)
    nk = [sp_pts[-1]] + [spine_at(y_neck + (y_head - y_neck) * t, hip_low) for t in (0.33, 0.66, 1.0)]
    chain(["neck1", "neck2", "neck3"], nk, eb["spine3"])
    hd = eb.new("head")
    hd.head = nk[-1]
    hd.tail = spine_at(ymax - L * 0.01, 0.0)
    hd.parent = eb["neck3"]
    tl = [sp_pts[0] + Vector((0, -L * 0.04, 0))] + [spine_at(yb - L * 0.04 - (yb - ymin) * t, -99) for t in (0.2, 0.4, 0.6, 0.8, 0.98)]
    chain(["tail1", "tail2", "tail3", "tail4", "tail5"], tl, pelvis)
    for key, f in feet.items():
        side = key[1]
        par = eb["spine3"] if key[0] == "F" else pelvis
        top = spine_at(f.y, hip_low)
        hip = Vector((f.x * 0.55, f.y, top.z - (top.z - f.z) * 0.15))
        knee = hip.lerp(f, 0.5) + Vector((0, L * 0.03 * (1 if key[0] == "F" else -1), 0))
        chain(["thigh_" + key, "shin_" + key], [hip, knee, f], par)
    for side, parts in wing_parts.items():
        if not parts:
            continue
        pts = [p.matrix_world @ v.co for p in parts for v in p.data.vertices]
        sg = 1 if side == "L" else -1
        rootp = min(pts, key=lambda p: abs(p.x))
        tip = max(pts, key=lambda p: p.x * sg + p.z * 0.3)
        mid = rootp.lerp(tip, 0.5) + Vector((0, 0, L * 0.02))
        chain(["wing1_" + side, "wing2_" + side], [rootp, mid, tip], eb["spine3"])
    for b in eb:
        b.roll = 0.0
    bones = {b.name: (b.head.copy(), b.tail.copy()) for b in eb if b.name != "root"}
    bpy.ops.object.mode_set(mode="OBJECT")

    # junta tudo e pesa: peças da asa só nos ossos da asa; o resto nos ossos do corpo (2 mais perto)
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.join()
    dragon = body
    dragon.name = "Dragon"

    def seg_d(p, a, b):
        ab = b - a
        t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-9)))
        return (a + ab * t - p).length

    groups = {n: dragon.vertex_groups.new(name=n) for n in bones}
    wl = dragon.vertex_groups.get("wing_L")
    wr = dragon.vertex_groups.get("wing_R")
    body_b = [n for n in bones if not n.startswith("wing")]
    for v in dragon.data.vertices:
        side = None
        for g in v.groups:
            if wl is not None and g.group == wl.index:
                side = "L"
            if wr is not None and g.group == wr.index:
                side = "R"
        cand = ["wing1_" + side, "wing2_" + side] if side and ("wing1_" + side) in bones else body_b
        near_legs = feet["BL"].y - L * 0.08 < v.co.y < feet["FL"].y + L * 0.08
        if v.co.z < hip_low * 1.1 and side is None and near_legs:   # perto do chão, entre as patas: só pernas
            cand = [n for n in body_b if n.startswith(("thigh", "shin"))] or body_b
        ds = sorted((seg_d(v.co, *bones[n]), n) for n in cand)[:2]
        w = [1.0 / max(d, 1e-3) ** 4 for d, _ in ds]
        tot = sum(w)
        for (d, n), wi in zip(ds, w):
            groups[n].add([v.index], wi / tot, "REPLACE")
    for n in ("wing_L", "wing_R"):
        g = dragon.vertex_groups.get(n)
        if g is not None:
            dragon.vertex_groups.remove(g)
    dragon.parent = arm
    am = dragon.modifiers.new("Rig", "ARMATURE")
    am.object = arm

    # ------------------------------------------------ animações
    arm.animation_data_create()
    pb = arm.pose.bones
    for b in pb:
        b.rotation_mode = "XYZ"

    def act(name, frames, fn):
        a = bpy.data.actions.new(name)
        arm.animation_data.action = a
        for f in range(0, frames + 1, 2):
            t = f / frames
            for b in pb:
                b.rotation_euler = (0, 0, 0)
                b.location = (0, 0, 0)
            fn(t)
            for b in pb:
                b.keyframe_insert("rotation_euler", frame=f)
                b.keyframe_insert("location", frame=f)
        tr = arm.animation_data.nla_tracks.new()
        tr.name = name
        tr.strips.new(name, 0, a)
        arm.animation_data.action = None

    def R(n, x=0.0, y=0.0, z=0.0):
        if n in pb:
            pb[n].rotation_euler = (x, y, z)

    TAU = math.tau

    def tail_sway(t, amp, sp=1):
        for i in range(1, 6):
            R("tail%d" % i, 0.03 * math.sin(TAU * t * sp), 0, amp * math.sin(TAU * t * sp - i * 0.6))

    def idle(t):
        br = math.sin(TAU * t)
        R("spine2", 0.03 * br)
        R("neck1", -0.05 * br, 0, 0.06 * math.sin(TAU * t))
        R("neck3", 0.05 * br)
        R("head", 0.04 * br, 0, -0.05 * math.sin(TAU * t))
        tail_sway(t, 0.12)
        for s, sg in (("L", 1), ("R", -1)):
            R("wing1_" + s, 0, 0.12 * br * sg)
            R("wing2_" + s, 0, 0.08 * math.sin(TAU * t - 0.5) * sg)

    def walk(t):
        ph = TAU * t
        for key, off in (("FL", 0), ("BR", 0), ("FR", math.pi), ("BL", math.pi)):
            R("thigh_" + key, 0.45 * math.sin(ph + off))
            R("shin_" + key, -0.35 * max(0.0, math.sin(ph + off + 1.2)))
        pb["pelvis"].location = (0, 0.03 * abs(math.sin(ph)) * L, 0)
        R("spine2", 0, 0, 0.05 * math.sin(ph))
        R("neck1", 0.05 * math.sin(2 * ph), 0, -0.06 * math.sin(ph))
        R("head", -0.05 * math.sin(2 * ph))
        tail_sway(t, 0.18)
        for s, sg in (("L", 1), ("R", -1)):
            R("wing1_" + s, 0, 0.1 * math.sin(2 * ph) * sg)

    def attack(t):
        # empina (0-0,45), bote para frente (0,45-0,6), volta
        up = math.sin(min(t / 0.45, 1.0) * math.pi / 2) if t < 0.45 else max(0.0, 1.0 - (t - 0.45) / 0.15)
        hit = max(0.0, math.sin(max(0.0, t - 0.45) / 0.55 * math.pi)) if t > 0.45 else 0.0
        R("spine1", -0.12 * up + 0.06 * hit)
        R("neck1", -0.35 * up + 0.45 * hit)
        R("neck2", -0.2 * up + 0.3 * hit)
        R("neck3", 0.15 * up - 0.2 * hit)
        R("head", 0.25 * up - 0.3 * hit)
        for s, sg in (("L", 1), ("R", -1)):
            R("wing1_" + s, 0, 0.6 * up * sg)
            R("wing2_" + s, 0, 0.4 * up * sg)
        R("thigh_FL", -0.25 * up)
        R("thigh_FR", -0.25 * up)
        tail_sway(t, 0.15, 2)

    act("idle", 48, idle)
    act("walk", 32, walk)
    act("attack", 30, attack)

    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True)
    dragon.select_set(True)
    bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True, export_yup=True,
                              export_animations=True, export_animation_mode="NLA_TRACKS", export_skins=True,
                              export_apply=False, export_vertex_color="ACTIVE", export_texcoords=True)
    print("OK", OUT, len(dragon.data.polygons), "faces", len(bones), "ossos")


main()
