"""
Kit para criar monstros orgânicos (estilo novo) por código no Blender:
  esqueleto de verdade -> corpo de "argila" (metaballs em volta dos ossos) -> malha limpa (remesh) ->
  pele presa aos ossos (pesos automáticos) -> detalhes rígidos (olhos, chifres, dentes) -> cores por vértice
  (barriga clara, costas escuras) -> animações de corpo inteiro -> .glb.
Convenções iguais às dos modelos antigos: olha para +Y, pés no chão (z=0), animações "idle", "walk", "attack".
"""
import math
import os

import bmesh
import bpy
from mathutils import Matrix, Quaternion, Vector

OUT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "models"))
X, Y, Z = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))


def srgb(c):
    return tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)


def new_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = 24


def mat(name, rgb, glow=0.0, rough=0.7, metal=0.0):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    lin = srgb(rgb)
    b.inputs["Base Color"].default_value = (*lin, 1.0)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if glow > 0:
        b.inputs["Emission Color"].default_value = (*lin, 1.0)
        b.inputs["Emission Strength"].default_value = glow
    return m


class Creature:
    """bones: [(nome, cabeça, cauda, pai, raio_cabeça, raio_cauda)] — raio 0 = osso sem carne (só esqueleto)."""

    def __init__(self, name, bones, skin_mat, resolution=0.09):
        self.name = name
        self.spec = bones
        self.skin = skin_mat
        self.res = resolution
        self.parts = []
        self.arm = None
        self.body = None

    # ------------------------------------------------------------ esqueleto
    def build_armature(self):
        data = bpy.data.armatures.new(self.name + "_esq")
        arm = bpy.data.objects.new(self.name + "_Esqueleto", data)
        bpy.context.collection.objects.link(arm)
        bpy.context.view_layer.objects.active = arm
        arm.select_set(True)
        bpy.ops.object.mode_set(mode="EDIT")
        eb = data.edit_bones
        for nm, h, t, par, _r0, _r1 in self.spec:
            b = eb.new(nm)
            b.head = Vector(h)
            b.tail = Vector(t)
            if par:
                b.parent = eb[par]
                b.use_connect = (eb[par].tail - b.head).length < 1e-4
        bpy.ops.object.mode_set(mode="OBJECT")
        self.arm = arm
        return arm

    # ------------------------------------------------------------ corpo de argila
    def build_body(self, extra_balls=(), decimate_to=6000):
        mb = bpy.data.metaballs.new(self.name + "_argila")
        mb.resolution = self.res
        mb.render_resolution = self.res
        obj = bpy.data.objects.new(self.name + "_argila", mb)
        bpy.context.collection.objects.link(obj)
        for nm, h, t, par, r0, r1 in self.spec:
            if r0 <= 0 and r1 <= 0:
                continue
            h, t = Vector(h), Vector(t)
            L = (t - h).length
            n = max(2, int(L / (max(0.05, min(r0, r1)) * 0.6)) + 1)
            for i in range(n):
                k = i / (n - 1)
                el = mb.elements.new()
                el.co = h.lerp(t, k)
                el.radius = r0 + (r1 - r0) * k
                el.stiffness = 2.0
        for co, r in extra_balls:
            el = mb.elements.new()
            el.co = Vector(co)
            el.radius = r
            el.stiffness = 2.0
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.convert(target="MESH")
        body = bpy.context.active_object
        body.name = self.name + "_Corpo"
        # malha limpa e leve
        rm = body.modifiers.new("Remesh", "REMESH")
        rm.mode = "VOXEL"
        rm.voxel_size = self.res * 0.7
        bpy.ops.object.modifier_apply(modifier=rm.name)
        sm = body.modifiers.new("Liso", "SMOOTH")
        sm.factor = 0.6
        sm.iterations = 3
        bpy.ops.object.modifier_apply(modifier=sm.name)
        faces = len(body.data.polygons)
        if faces > decimate_to:
            dm = body.modifiers.new("Leve", "DECIMATE")
            dm.ratio = decimate_to / faces
            bpy.ops.object.modifier_apply(modifier=dm.name)
        for p in body.data.polygons:
            p.use_smooth = True
        body.data.materials.clear()
        body.data.materials.append(self.skin)
        self.body = body
        return body

    def shade(self, belly=1.25, back=0.72, spots=None):
        """Cores por vértice: barriga mais clara, costas mais escuras (o jogo multiplica pela cor do material)."""
        me = self.body.data
        me.calc_loop_triangles()
        attr = me.color_attributes.new("Barra", "BYTE_COLOR", "POINT")
        zs = [v.co.z for v in me.vertices]
        zmin, zmax = min(zs), max(zs)
        for v in me.vertices:
            up = v.normal.z
            k = 1.0 + (back - 1.0) * max(0.0, up) + (belly - 1.0) * max(0.0, -up)
            if spots is not None:
                k *= spots(v.co)
            k = max(0.0, min(1.0, k * 0.8))
            attr.data[v.index].color = (k, k, k, 1.0)
        me.color_attributes.active_color = attr

    # ------------------------------------------------------------ pele e detalhes
    def bind(self):
        bpy.ops.object.select_all(action="DESELECT")
        self.body.select_set(True)
        self.arm.select_set(True)
        bpy.context.view_layer.objects.active = self.arm
        bpy.ops.object.parent_set(type="ARMATURE_AUTO")

    def part(self, kind, name, material, loc, size, rot=(0, 0, 0), bone=None, seg=10, r2=0.0):
        if kind == "sphere":
            bpy.ops.mesh.primitive_uv_sphere_add(radius=0.5, segments=seg, ring_count=max(5, seg // 2))
        elif kind == "cone":
            bpy.ops.mesh.primitive_cone_add(radius1=0.5, radius2=r2, depth=1.0, vertices=seg)
        elif kind == "cyl":
            bpy.ops.mesh.primitive_cylinder_add(radius=0.5, depth=1.0, vertices=seg)
        else:
            bpy.ops.mesh.primitive_cube_add(size=1.0)
        o = bpy.context.active_object
        o.name = name
        o.scale = size
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        bpy.ops.object.shade_smooth()
        o.data.materials.append(material)
        o.rotation_euler = rot
        o.location = loc
        if bone:
            self.attach(o, bone)
        self.parts.append(o)
        return o

    def attach(self, obj, bone):
        bpy.context.view_layer.update()
        mw = obj.matrix_world.copy()
        obj.parent = self.arm
        obj.parent_type = "BONE"
        obj.parent_bone = bone
        bpy.context.view_layer.update()
        obj.matrix_world = mw

    def membrane(self, name, material, pts, bones):
        """Pele fina (asa): polígono pelos pontos, cada vértice preso ao osso mais perto."""
        me = bpy.data.meshes.new(name)
        n = len(pts)
        me.from_pydata([Vector(p) for p in pts], [], [list(range(n))])
        o = bpy.data.objects.new(name, me)
        bpy.context.collection.objects.link(o)
        bpy.ops.object.select_all(action="DESELECT")
        o.select_set(True)
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.mesh.subdivide(number_cuts=4)
        bpy.ops.object.mode_set(mode="OBJECT")
        sol = o.modifiers.new("Esp", "SOLIDIFY")
        sol.thickness = 0.05
        bpy.ops.object.modifier_apply(modifier=sol.name)
        o.data.materials.append(material)
        for p in o.data.polygons:
            p.use_smooth = True
        groups = {b: o.vertex_groups.new(name=b) for b in bones}
        for v in o.data.vertices:
            best, bd = None, 1e9
            for b in bones:
                bb = self.arm.data.bones[b]
                d = _seg_dist(v.co, bb.head_local, bb.tail_local)
                if d < bd:
                    best, bd = b, d
            groups[best].add([v.index], 1.0, "REPLACE")
        md = o.modifiers.new("Esqueleto", "ARMATURE")
        md.object = self.arm
        o.parent = self.arm
        self.parts.append(o)
        return o

    # ------------------------------------------------------------ animações
    def actions(self, anims, root="root"):
        """anims: {nome: (quadros, fn(t) -> {osso: [(eixo_mundo, ângulo)...], "_loc": Vector})}."""
        ad = self.arm.animation_data_create()
        for name, (length, fn) in anims.items():
            act = bpy.data.actions.new(name)
            ad.action = act
            for i in range(length + 1):
                t = i / length
                pose = fn(t)
                loc = pose.pop("_loc", Vector((0, 0, 0)))
                for pb in self.arm.pose.bones:
                    pb.rotation_mode = "QUATERNION"
                    q = Quaternion()
                    r = pb.bone.matrix_local.to_quaternion()
                    for axis, ang in pose.get(pb.name, []):
                        q = (r.inverted() @ Quaternion(axis, ang) @ r) @ q
                    pb.rotation_quaternion = q
                    pb.keyframe_insert("rotation_quaternion", frame=i)
                if root in self.arm.pose.bones:
                    rb = self.arm.pose.bones[root]
                    rb.location = rb.bone.matrix_local.to_quaternion().inverted() @ loc
                    rb.keyframe_insert("location", frame=i)
            tr = ad.nla_tracks.new()
            tr.name = name
            tr.strips.new(name, 0, act)
            ad.action = None
        for pb in self.arm.pose.bones:
            pb.rotation_quaternion = Quaternion()
            pb.location = (0, 0, 0)

    def export(self, name=None):
        path = os.path.join(OUT, (name or self.name) + ".glb")
        bpy.ops.object.select_all(action="DESELECT")
        for o in [self.arm, self.body] + self.parts:
            o.select_set(True)
        bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_yup=True,
                                  export_cameras=False, export_lights=False, export_animations=True,
                                  export_animation_mode="NLA_TRACKS", export_skins=True, export_vertex_color="ACTIVE")
        print("OK", path)


def _seg_dist(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-9)))
    return (p - (a + ab * t)).length


def pulse(t, a, b, c, d):
    def e(x):
        x = max(0.0, min(1.0, x))
        return x * x * (3 - 2 * x)
    return e((t - a) / max(b - a, 1e-6)) * (1 - e((t - c) / max(d - c, 1e-6)))
