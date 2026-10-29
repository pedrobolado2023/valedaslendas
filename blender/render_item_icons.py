"""Renderiza os ícones dos itens (arma e armadura de cada classe/raridade) em textures/items/."""
import math
import os
import bpy
from mathutils import Vector

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
M = os.path.join(ROOT, "models")
OUT = os.path.join(ROOT, "textures", "items")
os.makedirs(OUT, exist_ok=True)


def setup(sc):
    w = bpy.data.worlds.new("w")
    sc.world = w
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.5, 0.5, 0.6, 1)
    w.node_tree.nodes["Background"].inputs[1].default_value = 0.8
    bpy.ops.object.light_add(type="SUN", location=(4, 3, 8))
    sun = bpy.context.active_object
    sun.rotation_euler = (math.radians(40), 0, math.radians(140))
    sun.data.energy = 4.0
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 12
    sc.render.film_transparent = True
    sc.render.resolution_x = 128
    sc.render.resolution_y = 128
    sc.view_settings.view_transform = "Standard"


def frame(sc, objs, pad=1.15, view=(1.0, 1.4, 0.5)):
    pts = []
    for o in objs:
        if o.type == "MESH":
            pts += [o.matrix_world @ Vector(c) for c in o.bound_box]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    c = (lo + hi) / 2
    size = max(hi - lo) * pad
    bpy.ops.object.camera_add(location=c + Vector(view).normalized() * 20)
    cam = bpy.context.active_object
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = size
    cam.rotation_euler = (c - cam.location).to_track_quat("-Z", "Y").to_euler()
    sc.camera = cam


for cls in ["druida", "assassino", "mecanico", "nautico"]:
    for tier in ["comum", "rara", "epica", "lendaria"]:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        sc = bpy.context.scene
        bpy.ops.import_scene.gltf(filepath=os.path.join(M, f"weapon_{cls}_{tier}.glb"))
        objs = list(bpy.data.objects)
        for o in objs:
            o.rotation_mode = "XYZ"
            o.rotation_euler = (0.0, math.radians(45), 0.0) if cls != "zz" else (math.radians(45), 0.0, 0.0)
        bpy.context.view_layer.update()
        setup(sc)
        frame(sc, objs, 1.05, (0.0, 1.0, 0.12) if cls != "zz" else (1.0, 0.0, 0.12))
        sc.render.filepath = os.path.join(OUT, f"{cls}_weapon_{tier}.png")
        bpy.ops.render.render(write_still=True)
        bpy.ops.wm.read_factory_settings(use_empty=True)
        sc = bpy.context.scene
        bpy.ops.import_scene.gltf(filepath=os.path.join(M, f"hero_{cls}_{tier}.glb"))
        for o in bpy.data.objects:
            ad = o.animation_data
            if ad:
                for t in list(ad.nla_tracks):
                    ad.nla_tracks.remove(t)
                ad.action = bpy.data.actions.get("idle")
        sc.frame_set(1)
        bpy.context.view_layer.update()
        objs = [o for o in bpy.data.objects if o.type == "MESH"]
        setup(sc)
        frame(sc, objs, 1.0, (0.6, 1.0, 0.25))
        sc.render.filepath = os.path.join(OUT, f"{cls}_armor_{tier}.png")
        bpy.ops.render.render(write_still=True)
        print("ICON", cls, tier)
