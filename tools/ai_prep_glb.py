# Modelo de IA (só forma) → modelo leve e pintado com a imagem de frente (cor por vértice).
# blender -b -P ai_prep.py -- forma.glb frente.png saida.glb [triangulos]
import sys

import bpy
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
src, img_path, out = args[0], args[1], args[2]
target = int(args[3]) if len(args) > 3 else 24000
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
o = [x for x in bpy.data.objects if x.type == "MESH"][0]
bpy.context.view_layer.objects.active = o
o.select_set(True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
n = len(o.data.polygons)
md = o.modifiers.new("Leve", "DECIMATE")
md.ratio = min(1.0, target / n)
bpy.ops.object.modifier_apply(modifier=md.name)
print("triangulos", n, "->", len(o.data.polygons))

# caixa do personagem na imagem: pixels que não são pergaminho
img = bpy.data.images.load(img_path)
W, H = img.size
px = list(img.pixels)


def at(x, y):
    i = (y * W + x) * 4
    return px[i], px[i + 1], px[i + 2], px[i + 3]


def is_char(r, g, b, a):
    if a < 0.5:
        return False
    lum = 0.3 * r + 0.59 * g + 0.11 * b
    return lum < 0.45 or b > r + 0.04


xs, ys = [], []
for y in range(0, H, 3):
    for x in range(0, W, 3):
        if is_char(*at(x, y)):
            xs.append(x)
            ys.append(y)
# corta 1% dos extremos (manchas da borda do pergaminho)
xs.sort()
ys.sort()
k = len(xs) // 100
ix0, ix1, iy0, iy1 = xs[k], xs[-k], ys[k], ys[-k]
print("caixa na imagem", ix0, ix1, iy0, iy1, "de", W, H)

mn = Vector((min(v.co.x for v in o.data.vertices), 0, min(v.co.z for v in o.data.vertices)))
mx = Vector((max(v.co.x for v in o.data.vertices), 0, max(v.co.z for v in o.data.vertices)))
navy = (0.07, 0.1, 0.18)


def sample(x, z):
    u = (x - mn.x) / (mx.x - mn.x)
    v = (z - mn.z) / (mx.z - mn.z)
    px_ = int(ix0 + u * (ix1 - ix0))
    py_ = int(iy0 + v * (iy1 - iy0))          # pixels do Blender: y = 0 embaixo
    best = None
    for dy in range(0, 12, 2):                 # se cair no pergaminho, procura o personagem perto
        for dx in (0, -dy, dy):
            qx, qy = min(W - 1, max(0, px_ + dx)), min(H - 1, max(0, py_ + dy))
            c = at(qx, qy)
            if is_char(*c):
                return c[:3]
            if best is None:
                best = c[:3]
    return (best[0] * 0.35, best[1] * 0.35, best[2] * 0.4)


me = o.data
col = me.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
for poly in me.polygons:
    facing_back = poly.normal.y > 0.35        # frente = -Y
    for li in poly.loop_indices:
        v = me.vertices[me.loops[li].vertex_index].co
        r, g, b = sample(v.x, v.z)
        if facing_back:                        # costas: capa azul-marinho com um pouco do desenho
            r, g, b = r * 0.35 + navy[0] * 0.65, g * 0.35 + navy[1] * 0.65, b * 0.35 + navy[2] * 0.65
        col.data[li].color = (r, g, b, 1.0)
me.color_attributes.active_color = col
mat = bpy.data.materials.new("lanceiro_ia")
mat.use_nodes = True
nt = mat.node_tree
vc = nt.nodes.new("ShaderNodeVertexColor")
vc.layer_name = "Col"
bs = nt.nodes["Principled BSDF"]
nt.links.new(vc.outputs["Color"], bs.inputs["Base Color"])
bs.inputs["Roughness"].default_value = 0.5
bs.inputs["Metallic"].default_value = 0.3
me.materials.clear()
me.materials.append(mat)
for p in me.polygons:
    p.use_smooth = True
# altura do jogo (~2,0) com os pés no chão, olhando +Y como os heróis
h = mx.z - mn.z
o.scale = (2.0 / h,) * 3
o.location = (0, 0, -mn.z * 2.0 / h)
o.rotation_euler = (0, 0, 3.14159)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
o.name = "Lanceiro"
bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", use_selection=False, export_vertex_color="ACTIVE")
print("OK", out)
