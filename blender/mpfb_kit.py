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


def wrap_shell(name, body, center, radius, keep, offset, segs=40, rings=28):
    """Casca lisa em volta do corpo: esfera encolhida até a pele (com folga `offset`), recortada por keep(p_mundo).
    Fica lisa mesmo sobre nariz e boca (bom para máscaras, capacetes e bonés)."""
    bpy.ops.mesh.primitive_uv_sphere_add(radius=radius, location=center, segments=segs, ring_count=rings)
    o = bpy.context.active_object
    o.name = name
    o.data.name = name
    bm = bmesh.new()
    bm.from_mesh(o.data)
    mw = o.matrix_world
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not keep(mw @ v.co)], context="VERTS")
    bm.to_mesh(o.data)
    bm.free()
    md = o.modifiers.new("Encolher", "SHRINKWRAP")
    md.target = body
    md.wrap_method = "NEAREST_SURFACEPOINT"
    md.offset = offset
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.modifier_apply(modifier=md.name)
    return o


def inflate(obj, amount):
    """Empurra a peça para fora (ao longo das normais) para não atravessar o corpo."""
    obj.data.update()
    for v in obj.data.vertices:
        v.co += v.normal * amount


def hem_colors(obj, width=0.04, dark=0.55):
    """Barra da roupa: escurece os vértices perto das bordas abertas da peça (cor por vértice "Barra").
    A espessura e a suavização copiam essa cor, e o shader do jogo multiplica por ela."""
    import heapq
    mw = obj.matrix_world
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.verts.ensure_lookup_table()
    dist = [1e9] * len(bm.verts)
    heap = []
    for e in bm.edges:
        if len(e.link_faces) == 1:
            for v in e.verts:
                if dist[v.index] > 0:
                    dist[v.index] = 0.0
                    heapq.heappush(heap, (0.0, v.index))
    wpos = [mw @ v.co for v in bm.verts]
    while heap:
        d, i = heapq.heappop(heap)
        if d > dist[i] or d > width:
            continue
        for e in bm.verts[i].link_edges:
            j = e.other_vert(bm.verts[i]).index
            nd = d + (wpos[i] - wpos[j]).length
            if nd < dist[j]:
                dist[j] = nd
                heapq.heappush(heap, (nd, j))
    bm.free()
    attr = obj.data.color_attributes.get("Barra") or obj.data.color_attributes.new("Barra", "BYTE_COLOR", "POINT")
    for i, d in enumerate(dist):
        t = min(d / width, 1.0)
        k = dark + (1.0 - dark) * t * t * (3 - 2 * t)
        attr.data[i].color = (k, k, k, 1.0)
    obj.data.color_attributes.active_color = attr


def finish_piece(obj, mat, thick=0.004, subdiv=1, offset=0.0, smooth=0):
    """smooth > 0 alisa a peça (máscaras e capacetes copiados do rosto ficam sem nariz/lábios marcados)."""
    if offset:
        inflate(obj, offset)
    hem_colors(obj)
    if smooth > 0:
        md = obj.modifiers.new("Liso", "SMOOTH")
        md.factor = 0.6
        md.iterations = smooth
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


def add_chain(arm, names, top, bottom, parent):
    """Cria uma corrente de ossos (de top até bottom, no mundo) filha de parent — usada na capa."""
    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm.data.edit_bones
    inv = arm.matrix_world.inverted()
    prev = eb[parent]
    n = len(names)
    for i, name in enumerate(names):
        b = eb.new(name)
        b.head = inv @ top.lerp(bottom, i / n)
        b.tail = inv @ top.lerp(bottom, (i + 1) / n)
        b.roll = 0.0
        b.parent = prev
        b.use_connect = i > 0
        prev = b
    bpy.ops.object.mode_set(mode="OBJECT")


def bind_chain(obj, arm, names, top_z, bottom_z):
    """Pesa cada vértice nos ossos da corrente pela altura (em cima = 1º osso, embaixo = último) e liga no esqueleto."""
    n = len(names)
    groups = [obj.vertex_groups.new(name=nm) for nm in names]
    mw = obj.matrix_world
    for v in obj.data.vertices:
        t = min(max((top_z - (mw @ v.co).z) / max(top_z - bottom_z, 1e-6), 0.0), 1.0)
        s = t * n - 0.5                       # posição ao longo da corrente, em "ossos"
        ws = [max(0.0, 1.0 - abs(s - i)) for i in range(n)]
        if s <= 0:
            ws = [1.0] + [0.0] * (n - 1)
        elif s >= n - 1:
            ws = [0.0] * (n - 1) + [1.0]
        tot = sum(ws) or 1.0
        for g, w in zip(groups, ws):
            if w > 0:
                g.add([v.index], w / tot, "REPLACE")
    am = obj.modifiers.new("Esqueleto", "ARMATURE")
    am.object = arm
    keep = obj.matrix_world.copy()
    obj.parent = arm
    obj.matrix_world = keep


CAPE = ("cape_01", "cape_02", "cape_03")


def cape_motion(anim, t):
    """Balanço da capa em cada animação (positivo em X = ponta da capa vai para trás)."""
    p = t * math.tau
    s = math.sin
    if anim == "idle":
        lift, amp, side, waves = (0.03, 0.02, 0.03), 0.04, 0.02, 1
    elif anim == "walk":
        lift, amp, side, waves = (0.12, 0.1, 0.08), 0.06, 0.03, 2
    elif anim == "run":
        lift, amp, side, waves = (0.35, 0.18, 0.14), 0.1, 0.04, 2
    else:   # ataque: a capa chicoteia uma vez e assenta
        k = math.sin(math.pi * t) ** 2
        return {b: [(Vector((1, 0, 0)), (0.25, 0.2, 0.15)[i] * k), (Vector((0, 1, 0)), 0.06 * s(p) * (i + 1))]
                for i, b in enumerate(CAPE)}
    out = {}
    for i, b in enumerate(CAPE):
        ph = p * waves - i * 0.9                    # a onda desce pela capa
        out[b] = [(Vector((1, 0, 0)), lift[i] + amp * s(ph)), (Vector((0, 1, 0)), side * s(p + i * 0.6))]
    return out


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
            if CAPE[0] in arm.pose.bones:
                for b, ops in cape_motion(name, t).items():
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


# =================================================================== texturas pintadas das roupas
# Texturas cinzas que se repetem (o jogo multiplica pela cor do material). Ficam em textures/roupa_<tipo>.png.

TEX_DIR = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "textures"))
TEX_SIZE = 512
TEX_TILE = {"tecido": 0.6, "couro": 0.7, "metal": 0.9}     # tamanho de uma repetição, em unidades do jogo
LEATHER = ("couro", "bota", "luva", "cinto", "correia", "bolsa", "bainha", "avental", "gibao", "casca", "tira")
NO_TEX = ("pele", "olho", "eye", "cabelo", "barba", "bigode", "sobrancelha", "costeleta", "folha", "brilho", "runa",
          "luz", "lente", "vidro", "_prev")


def _noise(rng, n, kc, aniso=1.0):
    """Ruído que se repete nas bordas (filtrado na frequência)."""
    import numpy as np
    f = np.fft.fftfreq(n) * n
    kx, ky = np.meshgrid(f, f)
    filt = np.exp(-((kx * aniso) ** 2 + ky ** 2) / (kc * kc))
    out = np.real(np.fft.ifft2(np.fft.fft2(rng.standard_normal((n, n))) * filt))
    out -= out.min()
    return out / max(out.max(), 1e-9)


def _cloth_pixels(kind):
    import numpy as np
    n = TEX_SIZE
    rng = np.random.default_rng({"tecido": 11, "couro": 23, "metal": 37}[kind])
    y, x = np.mgrid[0:n, 0:n] / n
    # escala pensada para a câmera do jogo (~1 cm por pixel): manchas de pincel de 5-15 cm, detalhes de 2-3 cm
    if kind == "tecido":
        f = 22                                   # trama grossa (cada fio ~2,5 cm), bem suave
        u, v = x * f, y * f
        over = (np.floor(u) + np.floor(v)) % 2
        thread = np.where(over > 0, np.sin(np.pi * (v % 1.0)), np.sin(np.pi * (u % 1.0)))
        folds = _noise(rng, n, 5, aniso=2.5)     # pinceladas compridas na vertical (dobras do pano)
        blot = _noise(rng, n, 3)
        val = 0.95 + 0.05 * (np.sqrt(np.clip(thread, 0, 1)) - 0.8) + 0.13 * (folds - 0.5) + 0.07 * (blot - 0.5)
    elif kind == "couro":
        blot = _noise(rng, n, 4)
        wear = _noise(rng, n, 7)                              # couro gasto: partes mais claras
        scuff = _noise(rng, n, 30)
        val = 0.95 + 0.13 * (blot - 0.5) + 0.06 * np.clip(wear - 0.6, 0, 1) + 0.06 * (scuff - 0.5)
    else:
        brushed = _noise(rng, n, 40, aniso=10.0)  # riscos de lixa numa direção
        dents = _noise(rng, n, 4)
        scratch = np.abs(_noise(rng, n, 12, aniso=6.0) - 0.5) < 0.012
        val = 0.95 + 0.07 * (brushed - 0.5) + 0.11 * (dents - 0.5) + 0.08 * scratch
    val = np.clip(val, 0, 1)
    rgba = np.ones((n, n, 4), dtype=np.float32)
    rgba[..., 0] = rgba[..., 1] = rgba[..., 2] = val
    return rgba


def cloth_image(kind):
    name = "roupa_" + kind
    img = bpy.data.images.get(name)
    if img is not None:
        return img
    path = os.path.join(TEX_DIR, name + ".png")
    if os.path.exists(path):
        img = bpy.data.images.load(path)
    else:
        img = bpy.data.images.new(name, TEX_SIZE, TEX_SIZE, alpha=False)
        img.pixels.foreach_set(_cloth_pixels(kind).ravel())
        img.filepath_raw = path
        img.file_format = "PNG"
        img.save()
    img.name = name
    return img


def cloth_kind(mat):
    """Qual textura o material recebe (ou None): metal, couro ou tecido."""
    if mat.get("roupa"):
        return mat["roupa"]            # já texturizado (material reaproveitado de outra raridade)
    n = mat.name.lower()
    if any(k in n for k in NO_TEX) or not mat.use_nodes:
        return None
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf is None or bsdf.inputs["Base Color"].is_linked or bsdf.inputs["Emission Strength"].default_value > 0:
        return None
    if bsdf.inputs["Metallic"].default_value >= 0.5:
        return "metal"
    if any(k in n for k in LEATHER):
        return "couro"
    return "tecido"


def texture_material(mat, kind):
    if mat.get("roupa"):
        return
    mat["roupa"] = kind
    nt = mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    t = nt.nodes.new("ShaderNodeTexImage")
    t.image = cloth_image(kind)
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.blend_type = "MULTIPLY"
    mix.inputs["Factor"].default_value = 1.0
    mix.inputs["B"].default_value = tuple(bsdf.inputs["Base Color"].default_value)
    nt.links.new(t.outputs["Color"], mix.inputs["A"])
    nt.links.new(mix.outputs["Result"], bsdf.inputs["Base Color"])


def unwrap_to_density(obj, tile):
    """Desdobra a malha (UV) e ajusta a escala para a textura repetir a cada `tile` unidades em todas as peças."""
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.01, scale_to_bounds=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    me = obj.data
    uv = me.uv_layers.active.data
    s = obj.matrix_world.to_scale()
    sc2 = ((abs(s.x) + abs(s.y) + abs(s.z)) / 3) ** 2
    world_a = sum(p.area for p in me.polygons) * sc2
    uv_a = 0.0
    for p in me.polygons:
        pts = [uv[i].uv for i in p.loop_indices]
        uv_a += abs(sum(pts[i].x * pts[i - 1].y - pts[i - 1].x * pts[i].y for i in range(len(pts)))) / 2
    if uv_a <= 0 or world_a <= 0:
        return
    k = math.sqrt(world_a / uv_a) / tile
    for d in uv:
        d.uv = d.uv * k


def paint_clothes(objs):
    """Põe as texturas de tecido/couro/metal nas peças e desdobra cada uma na mesma densidade."""
    done = set()
    for o in objs:
        if o.type != "MESH" or not o.data.materials:
            continue
        kinds = [cloth_kind(m) for m in o.data.materials if m is not None]
        kinds = [k for k in kinds if k]
        if not kinds:
            continue
        for m in o.data.materials:
            k = cloth_kind(m) if m is not None else None
            if k and m.name not in done:
                texture_material(m, k)
                done.add(m.name)
        unwrap_to_density(o, TEX_TILE[kinds[0]])


def export_glb(path, objs):
    paint_clothes(objs)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_yup=True,
                              export_cameras=False, export_lights=False, export_animations=True,
                              export_animation_mode="NLA_TRACKS", export_skins=True, export_apply=False,
                              export_vertex_color="ACTIVE")
    print("OK", path)
