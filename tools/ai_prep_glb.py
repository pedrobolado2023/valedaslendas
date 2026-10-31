# Modelo de IA (só forma) → modelo leve com TEXTURA pintada pela imagem de frente (projeção de frente nos UVs).
#   blender -b -P tools/ai_prep_glb.py -- forma.glb frente.png saida.glb [triangulos] [costas.png]
# Textura = atlas com 2 metades: esquerda = imagem de frente (pergaminho trocado pela cor do personagem mais perto),
# direita = costas: a imagem de costas se existir, senão a de frente borrada e escurecida (só as cores das roupas).
# Faces viradas para trás (normal +Y no modelo original, que olha -Y) usam a metade direita.
import os
import sys

import bpy
import numpy as np

args = sys.argv[sys.argv.index("--") + 1:]
src, img_path, out = args[0], args[1], args[2]
target = int(args[3]) if len(args) > 3 and args[3].isdigit() else 24000
back_path = args[4] if len(args) > 4 and args[4].lower().endswith((".png", ".jpg", ".jpeg")) else None
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


def load(path):
    im = bpy.data.images.load(path)
    w, h = im.size
    a = np.array(im.pixels[:], dtype=np.float32).reshape(h, w, 4)   # linha 0 = embaixo
    bpy.data.images.remove(im)
    return a


def shift(m, dy, dx):
    r = np.roll(np.roll(m, dy, 0), dx, 1)
    if dy > 0:
        r[:dy] = 0
    elif dy < 0:
        r[dy:] = 0
    if dx > 0:
        r[:, :dx] = 0
    elif dx < 0:
        r[:, dx:] = 0
    return r


def clean(a):
    """Tira o pergaminho: fundo = pixels parecidos com o papel ligados à borda. Devolve (imagem preenchida, caixa)."""
    h, w = a.shape[:2]
    rgb = a[..., :3]
    m = 14
    ring = np.zeros((h, w), bool)
    ring[m:m + 12, m:w - m] = ring[h - m - 12:h - m, m:w - m] = True
    ring[m:h - m, m:m + 12] = ring[m:h - m, w - m - 12:w - m] = True
    paper = np.median(rgb[ring], axis=0)
    lum = rgb @ np.array([0.3, 0.59, 0.11], np.float32)
    r_, g_, b_ = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    # papel claro em qualquer lugar (também dentro do arco, entre as pernas): claro, creme (verde perto do vermelho,
    # pele tem verde bem menor) e quente; manchas mais escuras do papel só quando ligadas à borda
    clear = (lum > 0.62) & (g_ > 0.86 * r_) & (r_ > b_ + 0.05)
    near = (np.linalg.norm(rgb - paper, axis=-1) < 0.28) | clear
    bg = near & ring
    for _ in range(2000):                      # enchente a partir da borda
        g = bg | (near & (shift(bg, 1, 0) | shift(bg, -1, 0) | shift(bg, 0, 1) | shift(bg, 0, -1)))
        if (g == bg).all():
            break
        bg = g
    inner = np.zeros((h, w), bool)
    inner[m:h - m, m:w - m] = True
    bg |= clear
    bg |= ~inner                               # moldura preta da imagem também é fundo
    ch = ~bg
    ys, xs = np.nonzero(ch)
    box = (np.percentile(xs, 0.3), np.percentile(xs, 99.7), np.percentile(ys, 0.3), np.percentile(ys, 99.7))
    if paper @ np.array([0.3, 0.59, 0.11]) < 0.35:
        # cenário escuro (ex.: Mago): não dá para separar do manto escuro; usa a imagem como está
        print("fundo escuro: imagem sem recorte")
        return rgb.copy(), box
    # fundo = média borrada das cores do personagem em volta (sem riscos de pixels claros da borda)
    out = rgb.copy()
    mask = ch.astype(np.float32)[..., None]
    fill = np.zeros_like(rgb)
    done = np.zeros((h, w), bool)
    for r in (10, 30, 90):
        num = blur(rgb * mask, r)
        den = blur(mask, r)[..., 0]
        ok = (den > 0.02) & ~done
        fill[ok] = num[ok] / den[ok][:, None]
        done |= ok
    fill[~done] = np.median(rgb[ch], axis=0)
    out[bg] = fill[bg] * 0.85
    print("papel", paper.round(2), "caixa", [int(v) for v in box])
    return out, box


def blur(a, r):
    k = 2 * r + 1
    for ax in (0, 1):
        c = np.cumsum(np.pad(a, [(r + 1, r) if i == ax else (0, 0) for i in range(3)], mode="edge"), axis=ax)
        a = (np.take(c, range(k, c.shape[ax]), axis=ax) - np.take(c, range(0, c.shape[ax] - k), axis=ax)) / k
    return a


front, fbox = clean(load(img_path))
H, W = front.shape[:2]
if back_path:
    back, bbox = clean(load(back_path))
    if back.shape != front.shape:
        back, bbox = front.copy(), fbox
else:
    back, bbox = blur(front, 22) * 0.62, fbox
atlas = np.concatenate([front, back], axis=1)
AW = 2 * W
img = bpy.data.images.new("ia_tex", AW, H, alpha=False)
img.pixels[:] = np.concatenate([atlas, np.ones((H, AW, 1), np.float32)], -1).ravel()
tex_path = os.path.splitext(out)[0] + "_tex.png"
img.filepath_raw = tex_path
img.file_format = "PNG"
img.save()
img.pack()

me = o.data
xs = [v.co.x for v in me.vertices]
zs = [v.co.z for v in me.vertices]
mnx, mxx, mnz, mxz = min(xs), max(xs), min(zs), max(zs)
uv = me.uv_layers.new(name="UV")
for poly in me.polygons:
    is_back = poly.normal.y > 0.35            # frente do modelo original = -Y
    bx = bbox if is_back else fbox
    for li in poly.loop_indices:
        v = me.vertices[me.loops[li].vertex_index].co
        u = (v.x - mnx) / (mxx - mnx)
        t = (v.z - mnz) / (mxz - mnz)
        px = bx[0] + u * (bx[1] - bx[0])
        if is_back and back_path:              # a foto de costas está espelhada em relação à frente
            px = bx[0] + (1.0 - u) * (bx[1] - bx[0])
        py = bx[2] + t * (bx[3] - bx[2])
        uv.data[li].uv = ((px / W) * 0.5 + (0.5 if is_back else 0.0), py / H)
me.uv_layers.active = uv
for a in list(me.color_attributes):
    me.color_attributes.remove(a)
mat = bpy.data.materials.new("ia_pintado")
mat.use_nodes = True
nt = mat.node_tree
tn = nt.nodes.new("ShaderNodeTexImage")
tn.image = img
bs = nt.nodes["Principled BSDF"]
nt.links.new(tn.outputs["Color"], bs.inputs["Base Color"])
bs.inputs["Roughness"].default_value = 0.6
bs.inputs["Metallic"].default_value = 0.0
me.materials.clear()
me.materials.append(mat)
for p in me.polygons:
    p.use_smooth = True
# altura do jogo (~2,0) com os pés no chão, olhando +Y como os heróis
h = mxz - mnz
o.scale = (2.0 / h,) * 3
o.location = (0, 0, -mnz * 2.0 / h)
o.rotation_euler = (0, 0, 3.14159)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
o.name = "HeroiIA"
bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", use_selection=False, export_image_format="JPEG",
                          export_image_quality=90)
print("OK", out)
