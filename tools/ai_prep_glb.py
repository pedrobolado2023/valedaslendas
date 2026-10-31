# Modelo de IA (só forma) → modelo leve com TEXTURA pintada pelas imagens (projeção de cada vista nos UVs).
#   blender -b -P tools/ai_prep_glb.py -- forma.glb frente.png saida.glb [triangulos] [costas.png]
#   vistas extras por ambiente: AI_LEFT=lado_esq.png AI_BACK=costas.png AI_RIGHT=lado_dir.png
#   (lado esquerdo = vê o lado esquerdo do personagem, ele olha para a esquerda da imagem; mesma pose e escala)
# Textura = atlas com uma faixa por vista (fundo liso ou pergaminho trocado pela cor do personagem em volta). Cada
# face usa a vista que olha mais de frente para ela. Sem foto de costas, as costas usam a frente borrada e escura.
import os
import sys

import bpy
import numpy as np

args = sys.argv[sys.argv.index("--") + 1:]
src, img_path, out = args[0], args[1], args[2]
target = int(args[3]) if len(args) > 3 and args[3].isdigit() else 24000
back_path = args[4] if len(args) > 4 and args[4].lower().endswith((".png", ".jpg", ".jpeg")) else None
back_path = os.environ.get("AI_BACK") or back_path
side_l = os.environ.get("AI_LEFT")              # vista do lado esquerdo do personagem (olha para a esquerda)
side_r = os.environ.get("AI_RIGHT")             # vista do lado direito (olha para a direita)
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


def drop_floaters(obj):
    """Tira os pedaços soltos que a IA cria em volta do corpo (restos do fundo): ilhas pequenas (< 5% dos vértices)
    afastadas do corpo principal, e migalhas (< 0,6%) em qualquer lugar. Peças encostadas no corpo ficam."""
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.verts.ensure_lookup_table()
    seen, islands = set(), []
    for v in bm.verts:
        if v.index in seen:
            continue
        stack, comp = [v], []
        seen.add(v.index)
        while stack:
            x = stack.pop()
            comp.append(x)
            for e in x.link_edges:
                y = e.other_vert(x)
                if y.index not in seen:
                    seen.add(y.index)
                    stack.append(y)
        islands.append(comp)
    islands.sort(key=len, reverse=True)
    main = islands[0]
    from mathutils import kdtree
    kd = kdtree.KDTree(len(main))
    for k, v in enumerate(main):
        kd.insert(v.co, k)
    kd.balance()
    zs = [v.co.z for v in main]
    gap = 0.02 * (max(zs) - min(zs))            # longe do corpo = mais de 2% da altura
    total = len(bm.verts)
    kill = []
    for comp in islands[1:]:
        near = min(kd.find(v.co)[2] for v in comp[:: max(1, len(comp) // 40)])
        if (len(comp) < 0.05 * total and near > gap) or len(comp) < 0.006 * total:   # solto no ar, ou migalha
            kill.extend(comp)
    bmesh.ops.delete(bm, geom=kill, context="VERTS")
    bm.to_mesh(obj.data)
    bm.free()
    print("pedacos soltos removidos:", len(kill), "vertices de", total, "(ilhas:", len(islands), ")")


drop_floaters(o)


def load(path, size=None):
    im = bpy.data.images.load(path)
    if size is not None and tuple(im.size) != tuple(size):
        im.scale(size[0], size[1])            # todas as vistas no tamanho da frente (atlas lado a lado)
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
    if paper[0] < paper[2] + 0.12:              # fundo branco/cinza (não é pergaminho): só a enchente pela borda
        clear[:] = False
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


# vistas: (nome, imagem, caixa, direção da câmera em relação ao modelo original, que olha -Y; esquerda do
# personagem = +X). "left" = câmera do lado esquerdo do personagem (ele olha para a esquerda da imagem).
front, fbox = clean(load(img_path))
H, W = front.shape[:2]
VIEWS = [("front", front, fbox, (0.0, -1.0, 0.0), True)]
for key, path, d in (("left", side_l, (1.0, 0.0, 0.0)), ("back", back_path, (0.0, 1.0, 0.0)), ("right", side_r, (-1.0, 0.0, 0.0))):
    if path:
        a, b = clean(load(path, (W, H)))
        VIEWS.append((key, a, b, d, True))
if not back_path:
    # sem foto de costas: a frente borrada e escurecida (só as cores das roupas), só para faces bem viradas para trás
    VIEWS.append(("back", blur(front, 22) * 0.62, fbox, (0.0, 1.0, 0.0), False))
N = len(VIEWS)
atlas = np.concatenate([v[1] for v in VIEWS], axis=1)
AW = N * W
img = bpy.data.images.new("ia_tex", AW, H, alpha=False)
img.pixels[:] = np.concatenate([atlas, np.ones((H, AW, 1), np.float32)], -1).ravel()
tex_path = os.path.splitext(out)[0] + "_tex.png"
img.filepath_raw = tex_path
img.file_format = "PNG"
img.save()
img.pack()
print("vistas:", [v[0] + ("" if v[4] else " (borrada)") for v in VIEWS])

me = o.data
co = [v.co for v in me.vertices]
mnx, mxx = min(c.x for c in co), max(c.x for c in co)
mny, mxy = min(c.y for c in co), max(c.y for c in co)
mnz, mxz = min(c.z for c in co), max(c.z for c in co)


def horiz(key, c):
    """Posição horizontal 0..1 do ponto na imagem da vista (esquerda → direita da imagem)."""
    if key == "front":
        return (c.x - mnx) / (mxx - mnx)
    if key == "back":
        return (mxx - c.x) / (mxx - mnx)
    if key == "left":
        return (c.y - mny) / (mxy - mny)
    return (mxy - c.y) / (mxy - mny)


for old in list(me.uv_layers):               # UVs antigos (se a forma vier com algum) atrapalham a exportação
    me.uv_layers.remove(old)
uv = me.uv_layers.new(name="UV")
for poly in me.polygons:
    n = poly.normal
    best, score = 0, -9.0
    for k, (key, _a, _b, d, real) in enumerate(VIEWS):
        dot = n.x * d[0] + n.y * d[1] + n.z * d[2]
        if not real and dot < 0.35:          # costas inventadas só onde a face olha mesmo para trás
            continue
        if dot > score:
            best, score = k, dot
    key, _a, bx, _d, real = VIEWS[best]
    if not real:
        key = "front"                           # a frente borrada usa o mesmo mapeamento da frente
    for li in poly.loop_indices:
        c = me.vertices[me.loops[li].vertex_index].co
        px = bx[0] + horiz(key, c) * (bx[1] - bx[0])
        py = bx[2] + (c.z - mnz) / (mxz - mnz) * (bx[3] - bx[2])
        uv.data[li].uv = ((best + px / W) / N, py / H)
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
