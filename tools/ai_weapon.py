# Arma feita por IA (só forma, gerada sozinha) → modelo leve e pintado, pronto para o nó "Weapon" da mão do herói.
#   blender -b -P tools/ai_weapon.py -- arma.glb arma.png saida.glb comprimento [sinal=1] [cabo=0.12] [inverter=0]
# - comprimento: tamanho final no espaço do nó Weapon (cajado da Druida ~3,5; tridente do Náutico ~4,4).
# - sinal: 1 = ponta em +Z (como o cajado da Druida); -1 = ponta em -Z (Assassino, Náutico, Guerreiro).
# - cabo: onde a mão segura, em fração do comprimento a partir da ponta de baixo (0 = na ponta, 0,5 = no meio: arco).
# - a ponta de baixo é achada sozinha (o lado mais fino: cabo da espada, pé do cajado); inverter=1 troca.
# Pintura: a imagem da arma de frente projetada (mesmo recorte de fundo do ai_prep_glb).
import sys

import bpy
import numpy as np
from mathutils import Matrix, Vector

args = sys.argv[sys.argv.index("--") + 1:]
src, img_path, out = args[0], args[1], args[2]
LENGTH = float(args[3])
SIGN = float(args[4]) if len(args) > 4 else 1.0
GRIP = float(args[5]) if len(args) > 5 else 0.12
FLIP = len(args) > 6 and args[6] == "1"

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
o = [x for x in bpy.data.objects if x.type == "MESH"][0]
bpy.context.view_layer.objects.active = o
o.select_set(True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
md = o.modifiers.new("Leve", "DECIMATE")
md.ratio = min(1.0, 5000 / max(1, len(o.data.polygons)))
bpy.ops.object.modifier_apply(modifier=md.name)
me = o.data
for old in list(me.uv_layers):
    me.uv_layers.remove(old)
for a in list(me.color_attributes):
    me.color_attributes.remove(a)

# --- pintura de frente (como a forma veio da IA: olhando -Y, imagem = plano X/Z)
im = bpy.data.images.load(img_path)
W, H = im.size
rgb = np.array(im.pixels[:], dtype=np.float32).reshape(H, W, 4)[..., :3]
bpy.data.images.remove(im)
m = 12
ring = np.zeros((H, W), bool)
ring[m:m + 10, m:W - m] = ring[H - m - 10:H - m, m:W - m] = ring[m:H - m, m:m + 10] = ring[m:H - m, W - m - 10:W - m] = True
paper = np.median(rgb[ring], axis=0)
# fundo: cor da borda, ou claro e sem cor (branco liso e o xadrez falso de "transparência" das IAs de imagem)
sat = rgb.max(-1) - rgb.min(-1)
near = (np.linalg.norm(rgb - paper, axis=-1) < 0.2) | ((sat < 0.07) & (rgb.mean(-1) > 0.72))
bg = near & ring
for _ in range(3000):
    g = bg.copy()
    g[1:] |= bg[:-1]
    g[:-1] |= bg[1:]
    g[:, 1:] |= bg[:, :-1]
    g[:, :-1] |= bg[:, 1:]
    g &= near
    if (g == bg).all():
        break
    bg = g
inner = np.zeros((H, W), bool)
inner[m:H - m, m:W - m] = True
bg |= ~inner
ys, xs = np.nonzero(~bg)
box = (np.percentile(xs, 0.2), np.percentile(xs, 99.8), np.percentile(ys, 0.2), np.percentile(ys, 99.8))
tex = rgb.copy()
tex[bg] = np.median(rgb[~bg], axis=0)          # fundo = cor média da arma (a borda não fica branca)
img = bpy.data.images.new("arma_tex", W, H, alpha=False)
img.pixels[:] = np.concatenate([tex, np.ones((H, W, 1), np.float32)], -1).ravel()
img.filepath_raw = out[:-4] + "_tex.png"     # imagem gerada só vai para o .glb depois de salva
img.file_format = "PNG"
img.save()
img.pack()
co = [v.co for v in me.vertices]
mnx, mxx = min(c.x for c in co), max(c.x for c in co)
mnz, mxz = min(c.z for c in co), max(c.z for c in co)
uv = me.uv_layers.new(name="UV")
for poly in me.polygons:
    for li in poly.loop_indices:
        c = me.vertices[me.loops[li].vertex_index].co
        u = (c.x - mnx) / max(mxx - mnx, 1e-6)
        px = box[0] + u * (box[1] - box[0])    # verso pega o mesmo ponto da frente (fica espelhado, como deve)
        py = box[2] + (c.z - mnz) / max(mxz - mnz, 1e-6) * (box[3] - box[2])
        uv.data[li].uv = (px / W, py / H)
mat = bpy.data.materials.new("arma_ia")
mat.use_nodes = True
tn = mat.node_tree.nodes.new("ShaderNodeTexImage")
tn.image = img
bs = mat.node_tree.nodes["Principled BSDF"]
mat.node_tree.links.new(tn.outputs["Color"], bs.inputs["Base Color"])
bs.inputs["Roughness"].default_value = 0.5
me.materials.clear()
me.materials.append(mat)
for p in me.polygons:
    p.use_smooth = True

# --- eixo da arma = direção mais comprida; a ponta de baixo é o lado mais fino
P = np.array([tuple(c) for c in co])
ctr = P.mean(0)
_, _, vt = np.linalg.svd(P - ctr, full_matrices=False)
axis = Vector(vt[0])
t = (P - ctr) @ vt[0]
lo, hi = t.min(), t.max()
L = hi - lo


def width_at(a, b):
    sel = (t >= a) & (t <= b)
    if sel.sum() < 3:
        return 0.0
    q = P[sel] - ctr - np.outer(t[sel], vt[0])
    return float(np.linalg.norm(q, axis=1).mean())


if width_at(lo, lo + 0.12 * L) > width_at(hi - 0.12 * L, hi):
    axis = -axis                               # o lado de baixo (t mínimo) tem de ser o mais fino
    lo, hi = -hi, -lo
if FLIP:
    axis = -axis
    lo, hi = -hi, -lo
grip = Vector(ctr) + axis * (lo + GRIP * L)
R = axis.rotation_difference(Vector((0, 0, SIGN))).to_matrix().to_4x4()
s = LENGTH / L
o.data.transform(Matrix.Scale(s, 4) @ R @ Matrix.Translation(-grip))
o.data.update()
o.name = "ArmaIA"
bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", use_selection=False, export_image_format="JPEG",
                          export_image_quality=90)
print("OK", out, "comprimento", round(L, 3), "-> escala", round(s, 3))
