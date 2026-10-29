"""
Gera os modelos 3D cartoon do Vale das Lendas (arquivos .glb para o Godot).

Como rodar:
  - Com o Blender instalado:   blender -b -P blender/make_models.py
  - Ou com o módulo Python:    pip install bpy   e depois   python blender/make_models.py

Os arquivos saem em ../models/. Para mudar o visual, edite as cores (CLASSES, MATERIAIS)
ou as formas de cada função build_*() e rode de novo.

Convenções (o Godot depende delas):
  - O personagem olha para +Y no Blender (vira -Z no Godot, a "frente" do jogo).
  - Animações com os nomes: idle, walk, attack (a do Golem também usa "attack" para a pancada).
  - Materiais com emissão viram partes brilhantes (olhos, runas, orbe, cristal).
"""
import math
import os
import random

import bpy
from mathutils import Vector

OUT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "models"))
FPS = 24
PI = math.pi

CLASSES = {
    "guerreiro": dict(cloth=(0.42, 0.47, 0.54), trim=(0.88, 0.69, 0.29), head="helm", kind="melee"),
    "lanceiro":  dict(cloth=(0.18, 0.42, 0.31), trim=(0.62, 0.88, 0.71), head="helm", kind="thrust"),
    "arqueiro":  dict(cloth=(0.37, 0.27, 0.15), trim=(0.85, 0.64, 0.25), head="hood", kind="arrow"),
    "mago":      dict(cloth=(0.29, 0.16, 0.48), trim=(0.71, 0.55, 1.00), head="hat",  kind="magic"),
}
SKIN = (0.88, 0.66, 0.47)
STEEL = (0.80, 0.84, 0.88)
WOOD = (0.42, 0.29, 0.17)
DARK = (0.10, 0.07, 0.06)
BOOT = (0.17, 0.11, 0.07)

# ---------------------------------------------------------------- base

_mats = {}
REST = {}


def srgb_to_lin(c):
    return tuple((v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4) for v in c)


def new_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = FPS
    _mats.clear()
    REST.clear()


def mat(name, rgb, glow=0.0):
    key = (name, rgb, glow)
    if key in _mats:
        return _mats[key]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    lin = srgb_to_lin(rgb) + (1.0,)
    b.inputs["Base Color"].default_value = lin
    b.inputs["Roughness"].default_value = 1.0
    if glow > 0.0:
        b.inputs["Emission Color"].default_value = lin
        b.inputs["Emission Strength"].default_value = glow
    _mats[key] = m
    return m


def empty(name, loc=(0, 0, 0), parent=None, rot=(0, 0, 0)):
    e = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(e)
    e.location = loc
    e.rotation_euler = rot
    e.parent = parent
    return e


def prim(kind, name, material, loc=(0, 0, 0), size=(1, 1, 1), rot=(0, 0, 0),
         parent=None, bevel=0.0, smooth=True, **kw):
    """Cria uma peça. size = dimensões finais (diâmetros), exceto em 'ico'/'torus' (escala)."""
    if kind == "box":
        bpy.ops.mesh.primitive_cube_add(size=1.0)
    elif kind == "sphere":
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.5, segments=kw.get("seg", 20), ring_count=kw.get("rings", 12))
    elif kind == "cyl":
        bpy.ops.mesh.primitive_cylinder_add(radius=0.5, depth=1.0, vertices=kw.get("seg", 16))
    elif kind == "cone":
        bpy.ops.mesh.primitive_cone_add(radius1=0.5, radius2=kw.get("r2", 0.0), depth=1.0, vertices=kw.get("seg", 16))
    elif kind == "torus":
        bpy.ops.mesh.primitive_torus_add(major_radius=0.5, minor_radius=kw.get("minor", 0.06),
                                         major_segments=24, minor_segments=8)
    elif kind == "ico":
        bpy.ops.mesh.primitive_ico_sphere_add(radius=0.5, subdivisions=kw.get("sub", 2))
    else:
        raise ValueError(kind)
    o = bpy.context.active_object
    o.name = name
    o.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel > 0.0:
        md = o.modifiers.new("Bevel", "BEVEL")
        md.width = bevel
        md.segments = 2
        md.limit_method = "ANGLE"
        bpy.ops.object.modifier_apply(modifier="Bevel")
    if smooth:
        bpy.ops.object.shade_smooth()
    o.data.materials.append(material)
    o.rotation_euler = rot
    o.location = loc
    o.parent = parent
    return o


# ---------------------------------------------------------------- animação

def _chan(j):
    return REST[j]


def register(*joints):
    for j in joints:
        REST[j] = dict(loc=tuple(j.location), rot=tuple(j.rotation_euler), scl=tuple(j.scale))


def cyc(length, steps, fn):
    """Chaves de um ciclo: do frame 1 ao 1+length, fn recebe t entre 0 e 1 (t=0 e t=1 iguais)."""
    return [(1 + round(i * length / steps), fn(i / steps)) for i in range(steps + 1)]


def write_anims(anims):
    """anims: {nome: {"length": n, "joints": {obj: {"rot"|"loc"|"scl": [(frame, valor)]}}}}"""
    used = {}
    for a in anims.values():
        for j, ch in a["joints"].items():
            used.setdefault(j, set()).update(ch.keys())
    for j in REST:
        used.setdefault(j, set()).add("rot")
    props = {"rot": "rotation_euler", "loc": "location", "scl": "scale"}
    for name, a in anims.items():
        end = 1 + a["length"]
        for j in REST:
            ad = j.animation_data_create()
            act = bpy.data.actions.new(f"{j.name}|{name}")
            ad.action = act
            spec = a["joints"].get(j, {})
            for k in sorted(used[j]):
                keys = spec.get(k) or [(1, REST[j][k]), (end, REST[j][k])]
                for frame, val in keys:
                    setattr(j, props[k], val)
                    j.keyframe_insert(data_path=props[k], frame=frame - 1)
            track = ad.nla_tracks.new()
            track.name = name
            strip = track.strips.new(name, 0, act)
            strip.name = name
            ad.action = None
    for j in REST:
        j.location = REST[j]["loc"]
        j.rotation_euler = REST[j]["rot"]
        j.scale = REST[j]["scl"]
    bpy.context.scene.frame_start = 0
    bpy.context.scene.frame_end = 48


def export(name, animated=True):
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name + ".glb")
    bpy.ops.object.select_all(action="SELECT")
    kwargs = dict(filepath=path, export_format="GLB", export_yup=True,
                  export_cameras=False, export_lights=False)
    if animated:
        kwargs.update(export_animations=True, export_animation_mode="NLA_TRACKS")
    else:
        kwargs.update(export_animations=False)
    bpy.ops.export_scene.gltf(**kwargs)
    print("OK", path)


# ---------------------------------------------------------------- heróis

def build_hero(key, spec=None, out=None):
    c = spec if spec is not None else CLASSES[key]
    new_scene()
    cloth = mat(key + "_roupa", c["cloth"])
    pants = mat(key + "_calca", tuple(v * 0.6 for v in c["cloth"]))
    trim = mat(key + "_detalhe", c["trim"])
    skin, boot, steel, wood, dark = mat("pele", SKIN), mat("bota", BOOT), mat("aco", STEEL), mat("madeira", WOOD), mat("escuro", DARK)
    glow = mat(key + "_brilho", c["trim"], glow=4.0)

    root = empty("Hero")
    hips = empty("Hips", (0, 0, 0.88), root)
    prim("box", "Torso", cloth, (0, 0, 0.36), (0.64, 0.42, 0.72), parent=hips, bevel=0.09)
    prim("box", "Cinto", trim, (0, 0, 0.1), (0.67, 0.45, 0.1), parent=hips, bevel=0.03)
    prim("sphere", "Ombro.L", trim if c["head"] != "hood" else cloth, (-0.38, 0, 0.66), (0.3, 0.3, 0.3), parent=hips)
    prim("sphere", "Ombro.R", trim if c["head"] != "hood" else cloth, (0.38, 0, 0.66), (0.3, 0.3, 0.3), parent=hips)
    if key == "mago" or c.get("robe"):
        prim("cone", "Manto", cloth, (0, 0, -0.12), (1.0, 1.0, 0.78), parent=hips, r2=0.3)
        prim("torus", "Barra", trim, (0, 0, -0.5), (1.0, 1.0, 0.8), parent=hips, minor=0.025)
    if key == "arqueiro":
        prim("box", "Aljava", wood, (-0.12, -0.26, 0.45), (0.2, 0.16, 0.6), rot=(0.25, 0, 0.3), parent=hips, bevel=0.03)
        for i, dx in enumerate((-0.04, 0.02, 0.08)):
            prim("cyl", f"FlechaA{i}", trim, (-0.12 + dx, -0.3, 0.82), (0.025, 0.025, 0.22), rot=(0.25, 0, 0.3), parent=hips)

    head = empty("Head", (0, 0, 0.95), hips)
    prim("sphere", "Rosto", skin, (0, 0, 0), (0.55, 0.52, 0.56), parent=head)
    prim("sphere", "EyeL", dark, (-0.1, 0.235, -0.02), (0.085, 0.06, 0.11), parent=head, seg=10, rings=6)
    prim("sphere", "EyeR", dark, (0.1, 0.235, -0.02), (0.085, 0.06, 0.11), parent=head, seg=10, rings=6)
    if c["head"] == "helm":
        prim("sphere", "Elmo", steel, (0, -0.03, 0.15), (0.6, 0.58, 0.46), parent=head)
        prim("box", "Crista", trim, (0, -0.02, 0.4), (0.07, 0.36, 0.22), parent=head, bevel=0.03)
    elif c["head"] == "hood":
        prim("sphere", "Capuz", cloth, (0, -0.07, 0.08), (0.68, 0.64, 0.56), parent=head)
        prim("cone", "PontaCapuz", cloth, (0, -0.3, 0.1), (0.3, 0.3, 0.4), rot=(-1.9, 0, 0), parent=head, r2=0.1)
    else:
        prim("cyl", "Aba", cloth, (0, 0, 0.2), (1.0, 1.0, 0.05), parent=head, bevel=0.015)
        prim("cone", "Chapeu", cloth, (0, -0.03, 0.62), (0.58, 0.58, 0.8), rot=(-0.18, 0, 0), parent=head, r2=0.03)
        prim("cyl", "Faixa", trim, (0, 0, 0.27), (0.6, 0.6, 0.08), parent=head, bevel=0.01)

    rest_l = {"melee": 0.2, "thrust": 0.25, "arrow": 0.35, "magic": 0.25}[c["kind"]]
    rest_r = {"melee": 1.4, "thrust": 1.4, "arrow": 1.5, "magic": 0.6}[c["kind"]]
    arm_l = empty("ArmL", (-0.44, 0, 0.62), hips, (rest_l, 0, 0))
    arm_r = empty("ArmR", (0.44, 0, 0.62), hips, (rest_r, 0, 0))
    for arm, side in ((arm_l, "L"), (arm_r, "R")):
        prim("cyl", f"Braco.{side}", cloth, (0, 0, -0.28), (0.17, 0.17, 0.56), parent=arm, bevel=0.04)
        prim("sphere", f"Mao.{side}", skin, (0, 0, -0.62), (0.2, 0.2, 0.2), parent=arm, seg=12, rings=8)
    leg_l = empty("LegL", (-0.17, 0, 0), hips)
    leg_r = empty("LegR", (0.17, 0, 0), hips)
    for leg, side in ((leg_l, "L"), (leg_r, "R")):
        prim("cyl", f"Perna.{side}", pants, (0, 0, -0.38), (0.22, 0.22, 0.76), parent=leg, bevel=0.04)
        prim("box", f"Bota.{side}", boot, (0, 0.06, -0.8), (0.26, 0.4, 0.17), parent=leg, bevel=0.05)

    weapon = empty("Weapon", (0, 0, -0.62), arm_r)
    kind = c["kind"]
    if kind == "melee":
        prim("cyl", "Cabo", wood, (0, 0, 0.02), (0.07, 0.07, 0.3), parent=weapon)
        prim("sphere", "Pomo", trim, (0, 0, 0.19), (0.13, 0.13, 0.13), parent=weapon, seg=10, rings=6)
        prim("box", "Guarda", trim, (0, 0, -0.14), (0.5, 0.09, 0.08), parent=weapon, bevel=0.02)
        prim("box", "Lamina", steel, (0, 0, -0.82), (0.13, 0.04, 1.34), parent=weapon, bevel=0.012)
        prim("cone", "PontaEspada", steel, (0, 0, -1.58), (0.17, 0.05, 0.22), rot=(PI, 0, 0), parent=weapon, seg=4)
        prim("cyl", "Escudo", steel, (-0.1, 0.12, -0.4), (0.66, 0.66, 0.07), rot=(0, PI / 2, 0), parent=arm_l, bevel=0.02, seg=24)
        prim("cyl", "EscudoAro", trim, (-0.13, 0.12, -0.4), (0.4, 0.4, 0.07), rot=(0, PI / 2, 0), parent=arm_l, bevel=0.02, seg=24)
        prim("sphere", "EscudoBoss", steel, (-0.17, 0.12, -0.4), (0.18, 0.18, 0.18), parent=arm_l, seg=12, rings=8)
    elif kind == "thrust":
        prim("cyl", "Haste", wood, (0, 0, -1.1), (0.07, 0.07, 3.1), parent=weapon)
        prim("cone", "Ponta", steel, (0, 0, -2.85), (0.15, 0.15, 0.55), rot=(PI, 0, 0), parent=weapon)
        prim("torus", "Anel", trim, (0, 0, -2.52), (0.2, 0.2, 0.7), parent=weapon, minor=0.07)
        prim("cyl", "FitaLanca", trim, (0.08, 0, -2.4), (0.05, 0.02, 0.3), parent=weapon)
        prim("cyl", "Escudinho", wood, (-0.1, 0.12, -0.4), (0.42, 0.42, 0.06), rot=(0, PI / 2, 0), parent=arm_l, bevel=0.02, seg=20)
        prim("cyl", "EscudinhoAro", trim, (-0.13, 0.12, -0.4), (0.22, 0.22, 0.06), rot=(0, PI / 2, 0), parent=arm_l, bevel=0.02, seg=20)
    elif kind == "arrow":
        prim("cyl", "ArcoCima", wood, (0, 0.31, -0.04), (0.065, 0.065, 0.66), rot=(-1.26, 0, 0), parent=weapon)
        prim("cyl", "ArcoBaixo", wood, (0, -0.31, -0.04), (0.065, 0.065, 0.66), rot=(1.26, 0, 0), parent=weapon)
        prim("box", "ArcoPunho", trim, (0, 0, -0.14), (0.09, 0.14, 0.16), parent=weapon, bevel=0.02)
        prim("box", "Corda", mat("corda", (0.94, 0.9, 0.82)), (0, 0, 0.06), (0.012, 1.24, 0.012), parent=weapon, smooth=False)
    else:
        weapon.rotation_euler = (-0.87, 0, 0)
        prim("cyl", "Cajado", wood, (0, 0, 0.25), (0.08, 0.08, 2.4), parent=weapon)
        prim("sphere", "Orbe", glow, (0, 0, 1.6), (0.34, 0.34, 0.34), parent=weapon, seg=16, rings=10)
        prim("torus", "Garra", trim, (0, 0, 1.6), (0.46, 0.46, 0.46), rot=(PI / 2, 0, 0), parent=weapon, minor=0.045)
        prim("cone", "PonteiraCajado", trim, (0, 0, -1.0), (0.12, 0.12, 0.2), rot=(PI, 0, 0), parent=weapon)

    register(hips, arm_l, arm_r, leg_l, leg_r)
    rl, rr = REST[arm_l]["rot"], REST[arm_r]["rot"]
    hz = 0.88

    def arm(rest, dx=0.0, dz=0.0):
        return (rest[0] + dx, rest[1], rest[2] + dz)

    def walk_arm_r(t):
        return arm(rr, 0.15 * math.cos(2 * PI * t))

    idle = dict(length=36, joints={
        hips: dict(loc=cyc(36, 4, lambda t: (0, 0, hz + 0.02 * (1 - math.cos(2 * PI * t)) / 2 * 2))),
        arm_l: dict(rot=cyc(36, 4, lambda t: arm(rl, 0.05 * math.cos(2 * PI * t)))),
        arm_r: dict(rot=cyc(36, 4, lambda t: arm(rr, 0.03 * math.cos(2 * PI * t)))),
    })
    walk = dict(length=24, joints={
        hips: dict(loc=cyc(24, 8, lambda t: (0, 0, 0.826 - 0.054 * math.cos(4 * PI * t)))),
        leg_l: dict(rot=cyc(24, 8, lambda t: (0.5 * math.cos(2 * PI * t), 0, 0))),
        leg_r: dict(rot=cyc(24, 8, lambda t: (-0.5 * math.cos(2 * PI * t), 0, 0))),
        arm_l: dict(rot=cyc(24, 8, lambda t: arm(rl, -0.45 * math.cos(2 * PI * t)))),
        arm_r: dict(rot=cyc(24, 8, walk_arm_r)),
    })
    if kind == "melee":
        atk = {
            hips: dict(rot=[(1, (0, 0, 0)), (4, (0, 0, 0.95)), (8, (0, 0, -1.05)), (13, (0, 0, 0))],
                       loc=[(1, (0, 0, hz)), (4, (0, -0.1, hz)), (8, (0, 0.3, hz)), (13, (0, 0, hz))]),
            arm_r: dict(rot=[(1, rr), (4, arm(rr, 0.2)), (8, arm(rr, -0.1)), (13, rr)]),
            arm_l: dict(rot=[(1, rl), (4, arm(rl, 0.3)), (8, arm(rl, 0.9)), (13, rl)]),
        }
    elif kind == "thrust":
        atk = {
            hips: dict(rot=[(1, (0, 0, 0)), (3, (0, 0, 0.3)), (5, (0, 0, -0.2)), (13, (0, 0, 0))],
                       loc=[(1, (0, 0, hz)), (3, (0, -0.18, hz)), (5, (0, 0.7, 0.8)), (13, (0, 0, hz))]),
            arm_r: dict(rot=[(1, rr), (3, arm(rr, 0.25)), (5, arm(rr, -0.05)), (13, rr)]),
            leg_l: dict(rot=[(1, (0, 0, 0)), (5, (0.55, 0, 0)), (13, (0, 0, 0))]),
            leg_r: dict(rot=[(1, (0, 0, 0)), (5, (-0.45, 0, 0)), (13, (0, 0, 0))]),
        }
    elif kind == "arrow":
        atk = {
            hips: dict(rot=[(1, (0, 0, 0)), (8, (0, 0, 0.2)), (13, (0, 0, 0))],
                       loc=[(1, (0, 0, hz)), (8, (0, -0.07, hz)), (9, (0, 0.04, hz)), (13, (0, 0, hz))]),
            arm_l: dict(rot=[(1, rl), (4, (1.35, 0, -0.55)), (8, (0.7, 0, -0.5)), (9, (1.0, 0, -0.2)), (13, rl)]),
        }
    else:
        atk = {
            hips: dict(rot=[(1, (0, 0, 0)), (4, (0.1, 0, 0.2)), (7, (-0.15, 0, -0.1)), (13, (0, 0, 0))],
                       loc=[(1, (0, 0, hz)), (4, (0, -0.1, hz)), (7, (0, 0.2, hz)), (13, (0, 0, hz))]),
            arm_r: dict(rot=[(1, rr), (4, arm(rr, -0.5)), (7, arm(rr, 1.0)), (13, rr)]),
            arm_l: dict(rot=[(1, rl), (4, arm(rl, 0.5)), (7, arm(rl, 0.9)), (13, rl)]),
        }
    write_anims({"idle": idle, "walk": walk, "attack": dict(length=12, joints=atk)})
    if c.get("beard"):
        prim("cone", "Barba", mat("barba", (0.92, 0.9, 0.86)), (0, 0.2, -0.22), (0.42, 0.3, 0.42), rot=(PI, 0, 0), parent=head, r2=0.05, seg=10)
        prim("sphere", "Bigode", mat("barba", (0.92, 0.9, 0.86)), (0, 0.25, -0.08), (0.34, 0.12, 0.1), parent=head, seg=10, rings=6)
    export(out or ("hero_" + key))


# ---------------------------------------------------------------- slime

def build_slime():
    new_scene()
    gel = mat("slime_gel", (0.3, 0.85, 0.4))
    gel2 = mat("slime_brilho", (0.62, 0.95, 0.68))
    white, dark = mat("branco", (1, 1, 1)), mat("escuro", DARK)
    root = empty("Slime")
    body = empty("Body", (0, 0, 0), root)
    prim("sphere", "Corpo", gel, (0, 0, 0.5), (1.1, 1.1, 1.0), parent=body, seg=24, rings=16)
    prim("sphere", "Brilho", gel2, (-0.22, 0.2, 0.86), (0.22, 0.14, 0.12), rot=(0.4, 0, 0.3), parent=body, seg=10, rings=6)
    for s, n in ((-1, "L"), (1, "R")):
        prim("sphere", "Olho." + n, white, (s * 0.2, 0.43, 0.62), (0.24, 0.2, 0.26), parent=body, seg=12, rings=8)
        prim("sphere", "Pupila." + n, dark, (s * 0.2, 0.52, 0.62), (0.11, 0.08, 0.13), parent=body, seg=8, rings=6)
    register(body)
    idle = dict(length=36, joints={body: dict(scl=cyc(36, 4, lambda t: (1 + 0.03 * math.cos(2 * PI * t),) * 2 + (1 - 0.05 * math.cos(2 * PI * t),)))})
    walk = dict(length=20, joints={body: dict(
        loc=cyc(20, 8, lambda t: (0, 0, 0.14 - 0.14 * math.cos(2 * PI * t))),
        scl=cyc(20, 8, lambda t: (1 + 0.1 * math.cos(2 * PI * t),) * 2 + (1 - 0.18 * math.cos(2 * PI * t),)))})
    atk = dict(length=12, joints={body: dict(
        loc=[(1, (0, 0, 0)), (4, (0, -0.15, 0)), (7, (0, 0.55, 0.15)), (13, (0, 0, 0))],
        scl=[(1, (1, 1, 1)), (4, (1.15, 1.15, 0.75)), (7, (0.85, 0.85, 1.2)), (13, (1, 1, 1))])})
    write_anims({"idle": idle, "walk": walk, "attack": atk})
    export("slime")


# ---------------------------------------------------------------- golem

def build_golem(name="golem", c1=(0.30, 0.29, 0.34), c2=(0.40, 0.39, 0.45), rune=(1.0, 0.48, 0.24), moss_c=(0.25, 0.42, 0.22)):
    new_scene()
    rock = mat(name + "_pedra", c1)
    rock2 = mat(name + "_pedra_clara", c2)
    glow = mat(name + "_runa", rune, glow=5.0)
    root = empty("Golem")
    hips = empty("Hips", (0, 0, 1.0), root)
    prim("box", "Torso", rock, (0, 0, 0.9), (1.9, 1.3, 1.9), parent=hips, bevel=0.14)
    prim("box", "Pelve", rock, (0, 0, 0.0), (1.4, 1.0, 0.5), parent=hips, bevel=0.1)
    prim("box", "Cabeca", rock2, (0, 0.08, 2.25), (1.0, 0.9, 0.8), parent=hips, bevel=0.1)
    prim("box", "Queixo", rock, (0, 0.28, 1.95), (0.7, 0.4, 0.25), parent=hips, bevel=0.06)
    prim("sphere", "OlhoE", glow, (-0.25, 0.5, 2.28), (0.3, 0.12, 0.22), parent=hips, seg=10, rings=6)
    prim("sphere", "OlhoD", glow, (0.25, 0.5, 2.28), (0.3, 0.12, 0.22), parent=hips, seg=10, rings=6)
    prim("box", "RunaV", glow, (0, 0.67, 1.1), (0.1, 0.05, 0.9), parent=hips)
    prim("box", "RunaH", glow, (0, 0.67, 1.25), (0.6, 0.05, 0.1), parent=hips)
    prim("box", "RunaDiag", glow, (0.38, 0.67, 0.6), (0.4, 0.05, 0.08), rot=(0, 0.7, 0), parent=hips)
    prim("ico", "PedraOmbroE", rock2, (-1.05, 0, 1.85), (0.8, 0.7, 0.6), parent=hips, sub=1)
    prim("ico", "PedraOmbroD", rock2, (1.05, 0, 1.85), (0.8, 0.7, 0.6), parent=hips, sub=1)
    prim("ico", "Musgo", mat(name + "_musgo", moss_c), (0.3, -0.5, 1.8), (0.7, 0.5, 0.3), parent=hips, sub=1)
    arm_l = empty("ArmL", (-1.3, 0, 1.75), hips)
    arm_r = empty("ArmR", (1.3, 0, 1.75), hips)
    for arm, s in ((arm_l, "L"), (arm_r, "R")):
        prim("box", f"Braco.{s}", rock, (0, 0, -0.75), (0.65, 0.7, 1.5), parent=arm, bevel=0.1)
        prim("box", f"Punho.{s}", rock2, (0, 0, -1.6), (0.95, 0.95, 0.85), parent=arm, bevel=0.12)
    leg_l = empty("LegL", (-0.5, 0, -0.1), hips)
    leg_r = empty("LegR", (0.5, 0, -0.1), hips)
    for leg, s in ((leg_l, "L"), (leg_r, "R")):
        prim("box", f"Perna.{s}", rock, (0, 0, -0.45), (0.8, 0.85, 0.9), parent=leg, bevel=0.1)
        prim("box", f"Pe.{s}", rock2, (0, 0.1, -0.88), (0.95, 1.15, 0.28), parent=leg, bevel=0.08)
    register(hips, arm_l, arm_r, leg_l, leg_r)
    hz = 1.0
    idle = dict(length=48, joints={
        hips: dict(loc=cyc(48, 4, lambda t: (0, 0, hz + 0.04 * (1 - math.cos(2 * PI * t)) / 2 * 2)),
                   rot=cyc(48, 4, lambda t: (0.02 * math.cos(2 * PI * t), 0, 0))),
        arm_l: dict(rot=cyc(48, 4, lambda t: (0.06 * math.cos(2 * PI * t), 0, 0))),
        arm_r: dict(rot=cyc(48, 4, lambda t: (0.06 * math.cos(2 * PI * t), 0, 0))),
    })
    walk = dict(length=32, joints={
        hips: dict(loc=cyc(32, 8, lambda t: (0, 0, 0.94 - 0.06 * math.cos(4 * PI * t))),
                   rot=cyc(32, 8, lambda t: (0, 0.07 * math.cos(2 * PI * t), 0))),
        leg_l: dict(rot=cyc(32, 8, lambda t: (0.4 * math.cos(2 * PI * t), 0, 0))),
        leg_r: dict(rot=cyc(32, 8, lambda t: (-0.4 * math.cos(2 * PI * t), 0, 0))),
        arm_l: dict(rot=cyc(32, 8, lambda t: (-0.3 * math.cos(2 * PI * t), 0, 0))),
        arm_r: dict(rot=cyc(32, 8, lambda t: (0.3 * math.cos(2 * PI * t), 0, 0))),
    })
    slam = dict(length=22, joints={
        hips: dict(rot=[(1, (0, 0, 0)), (14, (0.28, 0, 0)), (16, (-0.4, 0, 0)), (22, (0, 0, 0))],
                   loc=[(1, (0, 0, hz)), (14, (0, 0, 1.06)), (16, (0, 0.2, 0.82)), (22, (0, 0, hz))]),
        arm_l: dict(rot=[(1, (0, 0, 0)), (14, (2.85, 0, 0)), (15, (2.9, 0, 0)), (16, (0.9, 0, 0)), (22, (0, 0, 0))]),
        arm_r: dict(rot=[(1, (0, 0, 0)), (14, (2.85, 0, 0)), (15, (2.9, 0, 0)), (16, (0.9, 0, 0)), (22, (0, 0, 0))]),
    })
    write_anims({"idle": idle, "walk": walk, "attack": slam})
    export(name)


# ---------------------------------------------------------------- cenário

def build_pillar():
    new_scene()
    stone = mat("coluna_pedra", (0.42, 0.48, 0.52))
    stone2 = mat("coluna_base", (0.3, 0.35, 0.38))
    gold = mat("coluna_ouro", (0.85, 0.65, 0.25))
    root = empty("Pillar")
    prim("box", "Base", stone2, (0, 0, 0.125), (1.8, 1.8, 0.25), parent=root, bevel=0.05)
    prim("cone", "Fuste", stone, (0, 0, 1.95), (1.6, 1.6, 3.4), parent=root, r2=0.44, seg=14, bevel=0.05)
    for i, z in enumerate((0.9, 2.2)):
        r = 0.8 - 0.1 * (z - 0.25) / 3.4
        prim("torus", f"Faixa{i}", gold, (0, 0, z), (2 * r + 0.04, 2 * r + 0.04, 1.0), parent=root, minor=0.035)
    prim("torus", "AnelOuro", gold, (0, 0, 3.64), (1.62, 1.62, 1.0), parent=root, minor=0.08)
    prim("box", "Capitel", stone2, (0, 0, 3.82), (1.75, 1.75, 0.3), parent=root, bevel=0.06)
    prim("box", "Topo", stone, (0, 0, 4.0), (1.95, 1.95, 0.12), parent=root, bevel=0.04)
    export("pillar", animated=False)


def build_rock(name, seed):
    new_scene()
    rng = random.Random(seed)
    rock = mat("pedra", (0.37, 0.36, 0.34))
    moss = mat("pedra_musgo", (0.28, 0.4, 0.24))
    root = empty("Rock")
    o = prim("ico", "Pedra", rock, (0, 0, 0.32), (1.1, 0.9, 0.75), parent=root, sub=2)
    for v in o.data.vertices:
        v.co += Vector((rng.uniform(-0.07, 0.07), rng.uniform(-0.07, 0.07), rng.uniform(-0.05, 0.05)))
    prim("ico", "Musgo", moss, (0.12, -0.05, 0.62), (0.55, 0.45, 0.2), parent=root, sub=1)
    export(name, animated=False)


def build_loot():
    new_scene()
    glow = mat("cristal", (0.69, 0.49, 1.0), glow=4.0)
    root = empty("Crystal")
    prim("cone", "CristalCima", glow, (0, 0, 0.3), (0.5, 0.5, 0.6), parent=root, seg=6)
    prim("cone", "CristalBaixo", glow, (0, 0, -0.3), (0.5, 0.5, 0.6), rot=(PI, 0, 0), parent=root, seg=6)
    export("loot_crystal", animated=False)

    new_scene()
    blade = mat("espada_laminas", (1.0, 0.6, 0.25), glow=3.0)
    gold = mat("espada_ouro", (0.9, 0.7, 0.28))
    wood = mat("espada_cabo", WOOD)
    root = empty("Sword")
    prim("box", "Lamina", blade, (0, 0, 0.3), (0.16, 0.05, 1.0), parent=root, bevel=0.015)
    prim("cone", "Ponta", blade, (0, 0, 0.9), (0.2, 0.06, 0.2), parent=root, seg=4)
    prim("box", "Guarda", gold, (0, 0, -0.22), (0.5, 0.09, 0.08), parent=root, bevel=0.02)
    prim("cyl", "Cabo", wood, (0, 0, -0.38), (0.07, 0.07, 0.3), parent=root)
    prim("sphere", "Pomo", gold, (0, 0, -0.55), (0.14, 0.14, 0.14), parent=root, seg=10, rings=6)
    export("loot_sword", animated=False)


# ---------------------------------------------------------------- utilidades para modelos estáticos

def jitter(o, amount, seed):
    """Deforma levemente os vértices para um visual orgânico (folhas, pedras)."""
    rng = random.Random(seed)
    for v in o.data.vertices:
        v.co += v.normal * rng.uniform(-amount, amount) + Vector((rng.uniform(-amount, amount) * 0.5,) * 3)


def export_static(name):
    """Junta todas as peças num único mesh (vários materiais) com origem nos pés, e exporta."""
    bpy.context.view_layer.update()
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    for o in meshes:
        mw = o.matrix_world.copy()
        o.parent = None
        o.matrix_world = mw
    for o in list(bpy.context.scene.objects):
        if o.type != "MESH":
            bpy.data.objects.remove(o, do_unlink=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.join()
    o = bpy.context.view_layer.objects.active
    o.name = name
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.context.scene.cursor.location = (0, 0, 0)
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    export(name, animated=False)


# ---------------------------------------------------------------- vegetação

def build_tree_round(name, seed, greens):
    new_scene()
    rng = random.Random(seed)
    bark = mat("casca", (0.3, 0.2, 0.13))
    leaf = [mat(f"folha{i}", g) for i, g in enumerate(greens)]
    h = rng.uniform(2.2, 2.8)
    t = prim("cone", "Tronco", bark, (0, 0, h / 2), (0.7, 0.7, h), r2=0.22, seg=10, bevel=0.03)
    jitter(t, 0.03, seed)
    for k in range(2):
        a = rng.uniform(0, math.tau)
        prim("cone", f"Galho{k}", bark, (math.cos(a) * 0.35, math.sin(a) * 0.35, h * 0.75), (0.22, 0.22, 1.2), rot=(math.sin(a) * 0.9, -math.cos(a) * 0.9, 0), r2=0.06, seg=8)
    blobs = [(0, 0, h + 1.0, 2.6)] + [(math.cos(a) * 1.0, math.sin(a) * 1.0, h + rng.uniform(0.3, 1.2), rng.uniform(1.6, 2.1)) for a in [rng.uniform(0, math.tau) + i * 2.1 for i in range(4)]]
    blobs.append((rng.uniform(-0.4, 0.4), rng.uniform(-0.4, 0.4), h + 2.0, 1.7))
    for i, (x, y, z, r) in enumerate(blobs):
        o = prim("ico", f"Copa{i}", leaf[i % len(leaf)], (x, y, z), (r, r, r * 0.86), sub=2)
        jitter(o, 0.09, seed * 10 + i)
    export_static(name)


def build_tree_pine(name, seed):
    new_scene()
    rng = random.Random(seed)
    bark = mat("casca", (0.26, 0.17, 0.11))
    dark = mat("pinho_escuro", (0.1, 0.26, 0.2))
    mid = mat("pinho", (0.15, 0.36, 0.26))
    prim("cyl", "Tronco", bark, (0, 0, 0.8), (0.42, 0.42, 1.6), seg=8)
    z = 1.2
    for i in range(4):
        r = 3.2 - i * 0.65
        o = prim("cone", f"Camada{i}", dark if i % 2 == 0 else mid, (0, 0, z + 0.9), (r, r, 2.2), r2=0.0, seg=9)
        jitter(o, 0.06, seed * 7 + i)
        z += 1.15
    export_static(name)


def build_bush(name, seed):
    new_scene()
    rng = random.Random(seed)
    g1, g2 = mat("arbusto", (0.18, 0.4, 0.22)), mat("arbusto_claro", (0.28, 0.52, 0.26))
    for i in range(4):
        r = rng.uniform(0.7, 1.1)
        o = prim("ico", f"B{i}", g1 if i % 2 else g2, (rng.uniform(-0.6, 0.6), rng.uniform(-0.6, 0.6), r * 0.45), (r, r, r * 0.8), sub=2)
        jitter(o, 0.06, seed + i)
    if seed % 2 == 0:
        berry = mat("fruta", (0.85, 0.2, 0.3), glow=0.6)
        for i in range(5):
            prim("sphere", f"F{i}", berry, (rng.uniform(-0.6, 0.6), rng.uniform(-0.6, 0.6), rng.uniform(0.6, 0.9)), (0.12, 0.12, 0.12), seg=8, rings=5)
    export_static(name)


def build_mushroom_glow():
    new_scene()
    stem = mat("cogu_pe", (0.85, 0.82, 0.75))
    cap = mat("cogu_chapeu", (0.35, 0.9, 0.85), glow=2.5)
    for i, (x, y, s) in enumerate([(0, 0, 1.0), (0.45, 0.2, 0.7), (-0.35, 0.3, 0.55)]):
        prim("cyl", f"Pe{i}", stem, (x, y, 0.3 * s), (0.16 * s, 0.16 * s, 0.6 * s), seg=8)
        prim("sphere", f"Chapeu{i}", cap, (x, y, 0.62 * s), (0.6 * s, 0.6 * s, 0.38 * s), seg=12, rings=8)
    export_static("mushroom")


# ---------------------------------------------------------------- vila

def build_house(name, wall_c, roof_c, length=6.0, seed=1):
    new_scene()
    stone = mat("casa_pedra", (0.32, 0.31, 0.33))
    wall = mat("casa_parede", wall_c)
    beam = mat("casa_viga", (0.22, 0.14, 0.09))
    roof = mat("casa_telhado", roof_c)
    glass = mat("casa_janela", (1.0, 0.72, 0.35), glow=3.0)
    W, D = length, 4.6
    prim("box", "Base", stone, (0, 0, 0.35), (W + 0.3, D + 0.3, 0.7), bevel=0.08)
    prim("box", "Parede", wall, (0, 0, 2.0), (W, D, 2.6), bevel=0.04)
    for x in (-W / 2, W / 2):
        for y in (-D / 2, D / 2):
            prim("box", "Coluna", beam, (x, y, 2.0), (0.32, 0.32, 2.7), smooth=False)
    prim("box", "VigaFrente", beam, (0, D / 2, 3.25), (W + 0.2, 0.3, 0.26), smooth=False)
    prim("box", "VigaTras", beam, (0, -D / 2, 3.25), (W + 0.2, 0.3, 0.26), smooth=False)
    ang = 0.62
    rw = (D / 2 + 0.6) / math.cos(ang)
    for s in (-1, 1):
        prim("box", "Telhado", roof, (0, s * (D / 4 + 0.15), 3.35 + math.tan(ang) * D / 4), (W + 0.9, rw, 0.26), rot=(-s * ang, 0, 0), bevel=0.05)
    gable_h = math.tan(ang) * D / 2
    z0 = 3.38
    verts = [(-W / 2, -D / 2, z0), (-W / 2, D / 2, z0), (-W / 2, 0, z0 + gable_h),
             (W / 2, -D / 2, z0), (W / 2, D / 2, z0), (W / 2, 0, z0 + gable_h)]
    faces = [(0, 2, 1), (3, 4, 5), (0, 1, 4, 3), (1, 2, 5, 4), (2, 0, 3, 5)]
    me = bpy.data.meshes.new("Frontao")
    me.from_pydata(verts, [], faces)
    me.update()
    g = bpy.data.objects.new("Frontao", me)
    bpy.context.collection.objects.link(g)
    me.materials.append(wall)
    prim("box", "Chamine", stone, (W * 0.3, -D * 0.2, 4.6), (0.7, 0.7, 2.0), bevel=0.05)
    prim("box", "Porta", beam, (0, D / 2 + 0.05, 1.45), (1.1, 0.12, 1.9), bevel=0.03)
    prim("sphere", "Macaneta", mat("ouro", (0.85, 0.65, 0.25)), (0.35, D / 2 + 0.14, 1.4), (0.1, 0.1, 0.1), seg=8, rings=5)
    for x in (-W / 2 + 1.2, W / 2 - 1.2):
        prim("box", "Janela", glass, (x, D / 2 + 0.04, 2.2), (0.9, 0.1, 0.8))
        prim("box", "Moldura", beam, (x, D / 2 + 0.08, 2.2), (1.05, 0.06, 0.12), smooth=False)
        prim("box", "Moldura2", beam, (x, D / 2 + 0.08, 2.2), (0.12, 0.06, 0.95), smooth=False)
    prim("box", "JanelaLado", glass, (W / 2 + 0.04, 0, 2.2), (0.1, 0.9, 0.8))
    export_static(name)


def build_well():
    new_scene()
    stone = mat("poco_pedra", (0.38, 0.38, 0.4))
    wood = mat("poco_madeira", (0.3, 0.2, 0.12))
    roof = mat("poco_telhado", (0.5, 0.16, 0.14))
    water = mat("poco_agua", (0.2, 0.55, 0.7), glow=0.8)
    prim("cyl", "Anel", stone, (0, 0, 0.5), (2.2, 2.2, 1.0), seg=16, bevel=0.06)
    prim("cyl", "Agua", water, (0, 0, 0.92), (1.7, 1.7, 0.05), seg=16)
    for x in (-0.95, 0.95):
        prim("box", "Poste", wood, (x, 0, 1.6), (0.18, 0.18, 2.2), smooth=False)
    prim("cyl", "Eixo", wood, (0, 0, 2.2), (0.15, 0.15, 2.0), rot=(0, PI / 2, 0), seg=8)
    for s in (-1, 1):
        prim("box", "Telhado", roof, (0, s * 0.5, 2.95), (2.6, 1.3, 0.12), rot=(-s * 0.6, 0, 0), bevel=0.03)
    prim("cyl", "Balde", wood, (0.2, 0, 1.6), (0.35, 0.35, 0.4), seg=10)
    export_static("well")


def build_fence():
    new_scene()
    wood = mat("cerca", (0.36, 0.25, 0.15))
    for x in (-1.5, 1.5):
        prim("box", "Poste", wood, (x, 0, 0.6), (0.22, 0.22, 1.2), smooth=False)
        prim("cone", "Ponta", wood, (x, 0, 1.3), (0.3, 0.3, 0.2), seg=4, rot=(0, 0, PI / 4))
    for z in (0.45, 0.9):
        prim("box", "Travessa", wood, (0, 0, z), (3.2, 0.12, 0.18), smooth=False)
    export_static("fence")


def build_lamp():
    new_scene()
    iron = mat("lampiao_ferro", (0.12, 0.12, 0.14))
    glow = mat("lampiao_luz", (1.0, 0.75, 0.35), glow=5.0)
    prim("cyl", "Base", iron, (0, 0, 0.15), (0.6, 0.6, 0.3), seg=10)
    prim("cyl", "Haste", iron, (0, 0, 1.6), (0.14, 0.14, 3.0), seg=8)
    prim("box", "Braco", iron, (0.35, 0, 3.0), (0.8, 0.1, 0.1))
    prim("box", "Lanterna", glow, (0.7, 0, 2.6), (0.38, 0.38, 0.5))
    prim("cone", "Topo", iron, (0.7, 0, 2.95), (0.55, 0.55, 0.25), seg=4, rot=(0, 0, PI / 4))
    export_static("lamp")


def build_props():
    new_scene()
    wood = mat("caixa", (0.42, 0.29, 0.16))
    dark = mat("caixa_escura", (0.25, 0.16, 0.1))
    prim("box", "Caixa", wood, (0, 0, 0.5), (1, 1, 1), bevel=0.05)
    prim("box", "Tira1", dark, (0, 0.51, 0.5), (1.02, 0.04, 0.16), rot=(0, 0.78, 0))
    prim("box", "Tira2", dark, (0, 0.51, 0.5), (1.02, 0.04, 0.16), rot=(0, -0.78, 0))
    export_static("crate")
    new_scene()
    wood = mat("barril", (0.45, 0.28, 0.15))
    iron = mat("barril_aro", (0.18, 0.18, 0.2))
    prim("cyl", "Barril", wood, (0, 0, 0.6), (1.0, 1.0, 1.2), seg=14, bevel=0.04)
    for z in (0.25, 0.95):
        prim("torus", "Aro", iron, (0, 0, z), (1.02, 1.02, 1.0), minor=0.04)
    export_static("barrel")
    new_scene()
    wood = mat("placa", (0.4, 0.27, 0.15))
    prim("box", "Poste", wood, (0, 0, 1.1), (0.2, 0.2, 2.2), smooth=False)
    prim("box", "Placa1", wood, (0.6, 0, 1.8), (1.4, 0.1, 0.4), rot=(0, 0, 0.1), bevel=0.02)
    prim("box", "Placa2", wood, (-0.5, 0, 1.3), (1.2, 0.1, 0.36), rot=(0, 0, -0.15), bevel=0.02)
    export_static("signpost")


# ---------------------------------------------------------------- ruínas

def build_ruins():
    new_scene()
    stone = mat("ruina_pedra", (0.3, 0.33, 0.35))
    dark = mat("ruina_escura", (0.2, 0.22, 0.24))
    gold = mat("ruina_ouro", (0.7, 0.52, 0.2))
    rune = mat("ruina_runa", (0.3, 1.0, 0.55), glow=3.0)
    for x in (-2.4, 2.4):
        prim("box", "Base", dark, (x, 0, 0.3), (1.6, 1.6, 0.6), bevel=0.06)
        prim("cyl", "Coluna", stone, (x, 0, 2.6), (1.1, 1.1, 4.0), seg=12, bevel=0.04)
        prim("torus", "Aro", gold, (x, 0, 4.3), (1.25, 1.25, 1.0), minor=0.07)
        prim("box", "Runa", rune, (x, 0.56, 2.6), (0.3, 0.05, 0.6))
    o = prim("box", "Viga", stone, (0, 0, 5.0), (6.8, 1.4, 0.9), bevel=0.08)
    jitter(o, 0.03, 3)
    prim("box", "Lasca", stone, (2.9, 0.6, 0.25), (0.8, 0.6, 0.5), rot=(0.3, 0.2, 0.5), bevel=0.05)
    export_static("ruin_arch")
    new_scene()
    stone = mat("ruina_pedra", (0.3, 0.33, 0.35))
    dark = mat("ruina_escura", (0.2, 0.22, 0.24))
    gold = mat("ruina_ouro", (0.7, 0.52, 0.2))
    prim("box", "Base", dark, (0, 0, 0.3), (1.7, 1.7, 0.6), bevel=0.06)
    o = prim("cyl", "Coluna", stone, (0, 0, 1.6), (1.15, 1.15, 2.2), seg=12)
    for v in o.data.vertices:
        if v.co.z > 0.3:
            v.co.z += random.Random(int(v.co.x * 100 + v.co.y * 37)).uniform(-0.5, 0.35)
    prim("torus", "Aro", gold, (0, 0, 1.2), (1.22, 1.22, 1.0), minor=0.06)
    for i in range(3):
        prim("box", f"Pedaco{i}", stone, (1.2 + i * 0.4, -0.8 + i * 0.6, 0.2), (0.6, 0.5, 0.4), rot=(i, i * 0.5, i * 0.7), bevel=0.05)
    export_static("ruin_pillar")


# ---------------------------------------------------------------- lobo (animado)

def build_wolf(name, fur, fur2, eye):
    new_scene()
    furm, fur2m = mat(name + "_pelo", fur), mat(name + "_pelo2", fur2)
    eyes = mat(name + "_olho", eye, glow=4.0)
    dark = mat("focinho", (0.08, 0.06, 0.06))
    white = mat("dente", (0.95, 0.93, 0.88))
    root = empty("Wolf")
    body = empty("Body", (0, 0, 0.95), root)
    prim("sphere", "Tronco", furm, (0, -0.1, 0), (0.95, 1.9, 0.95), parent=body, seg=16, rings=10)
    prim("sphere", "Peito", fur2m, (0, 0.6, -0.05), (0.85, 0.9, 0.9), parent=body, seg=14, rings=8)
    prim("sphere", "Juba", furm, (0, 0.55, 0.25), (1.1, 0.9, 0.85), parent=body, seg=14, rings=8)
    head = empty("Head", (0, 1.05, 0.45), body)
    prim("sphere", "Cabeca", furm, (0, 0, 0), (0.75, 0.8, 0.65), parent=head, seg=14, rings=8)
    prim("cone", "Focinho", fur2m, (0, 0.55, -0.1), (0.42, 0.42, 0.6), rot=(-PI / 2, 0, 0), r2=0.12, parent=head, seg=10)
    prim("sphere", "Nariz", dark, (0, 0.86, -0.06), (0.16, 0.12, 0.12), parent=head, seg=8, rings=5)
    for s in (-1, 1):
        prim("cone", "Orelha", furm, (s * 0.24, -0.1, 0.38), (0.24, 0.16, 0.42), rot=(-0.2, s * 0.25, 0), parent=head, seg=4)
        prim("sphere", "Olho", eyes, (s * 0.2, 0.33, 0.1), (0.13, 0.08, 0.1), parent=head, seg=8, rings=5)
        prim("cone", "Presa", white, (s * 0.1, 0.72, -0.28), (0.06, 0.06, 0.14), rot=(PI, 0, 0), parent=head, seg=6)
    tail = empty("Tail", (0, -1.0, 0.15), body, (-0.6, 0, 0))
    prim("cone", "Rabo", furm, (0, -0.45, 0), (0.36, 0.36, 1.1), rot=(PI / 2, 0, 0), r2=0.05, parent=tail, seg=8)
    legs = []
    for nm, x, y in (("LegFL", -0.3, 0.6), ("LegFR", 0.3, 0.6), ("LegBL", -0.3, -0.75), ("LegBR", 0.3, -0.75)):
        lg = empty(nm, (x, y, -0.2), body)
        prim("cyl", "Perna", fur2m if "F" in nm else furm, (0, 0, -0.38), (0.24, 0.24, 0.8), parent=lg, seg=8, bevel=0.03)
        prim("sphere", "Pata", dark, (0, 0.06, -0.78), (0.28, 0.34, 0.16), parent=lg, seg=8, rings=5)
        legs.append(lg)
    fl, fr, bl, br = legs
    register(body, head, tail, fl, fr, bl, br)
    bz = 0.95
    idle = dict(length=36, joints={
        body: dict(loc=cyc(36, 4, lambda t: (0, 0, bz + 0.03 * math.sin(2 * PI * t)))),
        head: dict(rot=cyc(36, 4, lambda t: (0.06 * math.sin(2 * PI * t), 0, 0))),
        tail: dict(rot=cyc(36, 4, lambda t: (-0.6, 0, 0.3 * math.sin(2 * PI * t)))),
    })
    walk = dict(length=16, joints={
        body: dict(loc=cyc(16, 8, lambda t: (0, 0, bz + 0.07 * abs(math.sin(2 * PI * t))))),
        fl: dict(rot=cyc(16, 8, lambda t: (0.6 * math.sin(2 * PI * t), 0, 0))),
        br: dict(rot=cyc(16, 8, lambda t: (0.6 * math.sin(2 * PI * t), 0, 0))),
        fr: dict(rot=cyc(16, 8, lambda t: (-0.6 * math.sin(2 * PI * t), 0, 0))),
        bl: dict(rot=cyc(16, 8, lambda t: (-0.6 * math.sin(2 * PI * t), 0, 0))),
        tail: dict(rot=cyc(16, 8, lambda t: (-0.4, 0, 0.35 * math.sin(4 * PI * t)))),
    })
    atk = dict(length=14, joints={
        body: dict(loc=[(1, (0, 0, bz)), (5, (0, -0.35, bz - 0.15)), (8, (0, 0.9, bz + 0.25)), (15, (0, 0, bz))],
                   rot=[(1, (0, 0, 0)), (5, (-0.15, 0, 0)), (8, (0.2, 0, 0)), (15, (0, 0, 0))]),
        head: dict(rot=[(1, (0, 0, 0)), (6, (0.3, 0, 0)), (8, (-0.35, 0, 0)), (15, (0, 0, 0))]),
        fl: dict(rot=[(1, (0, 0, 0)), (8, (-0.9, 0, 0)), (15, (0, 0, 0))]),
        fr: dict(rot=[(1, (0, 0, 0)), (8, (-0.9, 0, 0)), (15, (0, 0, 0))]),
    })
    write_anims({"idle": idle, "walk": walk, "attack": atk})
    export(name)


def build_slime_king():
    new_scene()
    gel = mat("rei_gel", (0.55, 0.3, 0.9))
    gel2 = mat("rei_brilho", (0.8, 0.65, 1.0))
    white, dark = mat("branco", (1, 1, 1)), mat("escuro", DARK)
    gold = mat("coroa", (0.95, 0.75, 0.25))
    gem = mat("joia", (1.0, 0.25, 0.35), glow=3.0)
    root = empty("SlimeKing")
    body = empty("Body", (0, 0, 0), root)
    prim("sphere", "Corpo", gel, (0, 0, 0.5), (1.1, 1.1, 1.0), parent=body, seg=24, rings=16)
    prim("sphere", "Brilho", gel2, (-0.22, 0.2, 0.86), (0.22, 0.14, 0.12), rot=(0.4, 0, 0.3), parent=body, seg=10, rings=6)
    for s, n in ((-1, "L"), (1, "R")):
        prim("sphere", "Olho." + n, white, (s * 0.2, 0.43, 0.62), (0.24, 0.2, 0.26), parent=body, seg=12, rings=8)
        prim("sphere", "Pupila." + n, dark, (s * 0.2, 0.52, 0.6), (0.11, 0.08, 0.1), parent=body, seg=8, rings=6)
        prim("box", "Sobrancelha." + n, dark, (s * 0.2, 0.46, 0.82), (0.24, 0.05, 0.05), rot=(0, s * 0.35, 0), parent=body)
    prim("cyl", "Coroa", gold, (0, 0, 1.08), (0.6, 0.6, 0.22), parent=body, seg=12)
    for k in range(5):
        a = k * math.tau / 5
        prim("cone", f"Ponta{k}", gold, (math.cos(a) * 0.26, math.sin(a) * 0.26, 1.3), (0.16, 0.16, 0.26), parent=body, seg=4)
    prim("sphere", "Joia", gem, (0, 0.3, 1.1), (0.12, 0.06, 0.12), parent=body, seg=8, rings=5)
    register(body)
    idle = dict(length=36, joints={body: dict(scl=cyc(36, 4, lambda t: (1 + 0.03 * math.cos(2 * PI * t),) * 2 + (1 - 0.05 * math.cos(2 * PI * t),)))})
    walk = dict(length=24, joints={body: dict(
        loc=cyc(24, 8, lambda t: (0, 0, 0.12 - 0.12 * math.cos(2 * PI * t))),
        scl=cyc(24, 8, lambda t: (1 + 0.08 * math.cos(2 * PI * t),) * 2 + (1 - 0.14 * math.cos(2 * PI * t),)))})
    atk = dict(length=16, joints={body: dict(
        loc=[(1, (0, 0, 0)), (6, (0, 0, 0.0)), (10, (0, 0, 0.9)), (14, (0, 0, 0)), (17, (0, 0, 0))],
        scl=[(1, (1, 1, 1)), (6, (1.25, 1.25, 0.65)), (10, (0.85, 0.85, 1.2)), (14, (1.3, 1.3, 0.6)), (17, (1, 1, 1))])})
    write_anims({"idle": idle, "walk": walk, "attack": atk})
    export("slime_king")


def main():
    for key in CLASSES:
        build_hero(key)
    build_slime()
    build_golem()
    build_pillar()
    build_rock("rock_a", 3)
    build_rock("rock_b", 8)
    build_loot()
    build_hero("npc", dict(cloth=(0.45, 0.2, 0.18), trim=(0.95, 0.75, 0.3), head="hood", kind="magic", robe=True, beard=True), out="npc_elder")
    build_wolf("wolf", (0.42, 0.42, 0.46), (0.62, 0.6, 0.58), (1.0, 0.85, 0.3))
    build_wolf("wolf_alpha", (0.16, 0.13, 0.16), (0.32, 0.26, 0.28), (1.0, 0.25, 0.2))
    build_slime_king()
    build_tree_round("tree_a", 1, [(0.16, 0.4, 0.24), (0.22, 0.5, 0.26), (0.13, 0.33, 0.22)])
    build_tree_round("tree_b", 2, [(0.42, 0.5, 0.2), (0.55, 0.58, 0.22), (0.32, 0.42, 0.18)])
    build_tree_round("tree_c", 5, [(0.5, 0.22, 0.3), (0.62, 0.3, 0.36), (0.4, 0.16, 0.26)])
    build_tree_pine("tree_pine", 3)
    build_bush("bush_a", 2)
    build_bush("bush_b", 5)
    build_mushroom_glow()
    build_house("house_a", (0.76, 0.6, 0.44), (0.55, 0.18, 0.15), 6.0, 1)
    build_house("house_b", (0.66, 0.56, 0.46), (0.2, 0.3, 0.5), 7.5, 2)
    build_well()
    build_fence()
    build_lamp()
    build_props()
    build_ruins()


if __name__ == "__main__":
    main()
