r"""
Gera os 4 heróis das artes 2D (Lanceiro, Guerreiro, Arqueira e Mago) usando o corpo e o esqueleto
humanizado de 53 ossos do MPFB2 (MakeHuman) + peças de armadura 3D separadas por membro + textura
projetada por região anatômica a partir de Assets/<Classe> Frame/frame_000.png + armas/escudo/arco
3D rígidos presos aos ossos (sem nunca deformar ou rasgar a malha ao andar, correr ou atacar).

Rode:
  $env:MH_DATA="C:\Users\pedro\vale-tools\makehuman\makehuman\data"
  $env:PYTHONPATH="C:\Users\pedro\vale-tools\pylibs"
  & "C:\Users\pedro\vale-tools\blender-5.2.3-windows-x64\blender.exe" -b -P tools/make_ai_heroes_mpfb.py
"""
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Euler, Matrix, Quaternion, Vector

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
BLENDER_DIR = os.path.join(ROOT, "blender")
if BLENDER_DIR not in sys.path:
    sys.path.insert(0, BLENDER_DIR)

import mpfb_kit as K  # noqa: E402
import skill_anims as SA  # noqa: E402
import make_druid_mpfb as D  # noqa: E402
import make_assassin_mpfb as A  # noqa: E402
import make_mechanic_mpfb as Mc  # noqa: E402
import make_nautical_mpfb as Na  # noqa: E402
import make_skins as SK  # noqa: E402

OUT = os.path.join(ROOT, "models")
ASSETS = os.path.join(ROOT, "Assets")
K.MH_DATA = os.environ.get("MH_DATA", r"C:\Users\pedro\vale-tools\makehuman\makehuman\data")

TORSO, UPPER, LOWER, LEGS, FEET = D.TORSO, D.UPPER, D.LOWER, D.LEGS, D.FEET
X, Y, Z = D.X, D.Y, D.Z
piece, rigid, prim, belt = D.piece, D.rigid, D.prim, D.belt


# ==============================================================================
# 1. Atlas de Textura Limpo [Frente | Costas Escurecida/Suave] a partir da Arte
# ==============================================================================

def _blur2d(arr, passes=45):
    b = arr.copy()
    for _ in range(passes):
        b = 0.2 * (
            b
            + np.roll(b, 1, 0)
            + np.roll(b, -1, 0)
            + np.roll(b, 1, 1)
            + np.roll(b, -1, 1)
        )
    return b


def build_art_material(cls_key, img_path, back_tint=(0.22, 0.24, 0.30)):
    """Carrega frame_000.png, remove 100% do fundo (transparente ou pergaminho/creme) e da borda de
    anti-aliasing extrapolando a cor exata da armadura/roupa vizinha para fora da silhueta, e monta
    um atlas [Frente (u=0..0.5) | Costas suave/escura (u=0.5..1.0)]."""
    im = bpy.data.images.load(img_path)
    W, H = im.size
    rgba = np.array(im.pixels[:], dtype=np.float32).reshape(H, W, 4)
    rgb = rgba[..., :3].copy()
    alpha = rgba[..., 3]
    bpy.data.images.remove(im)

    m = 14
    ring = np.zeros((H, W), bool)
    ring[m : m + 12, m : W - m] = True
    ring[H - m - 12 : H - m, m : W - m] = True
    ring[m : H - m, m : m + 12] = True
    ring[m : H - m, W - m - 12 : W - m] = True
    paper = np.median(rgb[ring], axis=0)

    sat = rgb.max(-1) - rgb.min(-1)
    val = rgb.mean(-1)
    # Protege apenas o miolo do rosto/olhos para não apagar brilhos claros da pele
    yy, xx = np.mgrid[0:H, 0:W]
    yn, xn = yy / float(H), xx / float(W)
    face_core = (xn > 0.43) & (xn < 0.57) & (yn > 0.75) & (yn < 0.89)
    # Detecta 100% do fundo creme/pergaminho/bege (val > 0.54 e baixa saturação, mais quente que azul)
    is_cream = (val > 0.54) & (sat < 0.32) & ((rgb[..., 0] - rgb[..., 2]) > -0.02)
    bg = (alpha < 0.88) | (is_cream & (~face_core))

    inner = np.zeros((H, W), bool)
    inner[m : H - m, m : W - m] = True
    bg |= ~inner

    # No Guerreiro, mascara também a lâmina azul brilhante que cruza as coxas/joelhos da imagem (u=0.20..0.56, v=0.30..0.58)
    if cls_key == "guerreiro":
        sword_mask = (xn > 0.20) & (xn < 0.56) & (yn > 0.28) & (yn < 0.58) & ((rgb[..., 2] - rgb[..., 0]) > 0.08)
        bg |= sword_mask

    # Expande a máscara de fundo em 4 pixels para comer 100% do halo creme de anti-aliasing da silhueta
    for _ in range(4):
        g = bg.copy()
        g[1:] |= bg[:-1]
        g[:-1] |= bg[1:]
        g[:, 1:] |= bg[:, :-1]
        g[:, :-1] |= bg[:, 1:]
        bg = g

    # Extrapola a cor real da borda da armadura/roupa para fora (wavefront dilation) sem nunca usar cor creme!
    fg = ~bg
    front = rgb.copy()
    shifts = ((-1, 0), (1, 0), (0, -1), (0, 1), (-1, -1), (-1, 1), (1, -1), (1, 1))
    for step in range(160):
        if fg.all():
            break
        acc = np.zeros_like(front)
        cnt = np.zeros((H, W, 1), dtype=np.float32)
        for dy, dx in shifts:
            s_fg = np.roll(np.roll(fg, dy, axis=0), dx, axis=1)
            s_rgb = np.roll(np.roll(front, dy, axis=0), dx, axis=1)
            m_nb = s_fg[:, :, None]
            acc += s_rgb * m_nb
            cnt += m_nb
        newly = (~fg) & (cnt[:, :, 0] > 0)
        if not newly.any():
            break
        decay = 0.994 if step < 25 else 0.988
        front[newly] = (acc[newly] / cnt[newly]) * decay
        fg |= newly
    if (~fg).any():
        front[~fg] = np.array(back_tint, dtype=np.float32)

    # Costas: versão borrada e escurecida da frente (sem rosto nem fivelas marcadas nas costas)
    back = _blur2d(front[:, ::-1, :], passes=65) * 0.42
    tint = np.array(back_tint, dtype=np.float32)[None, None, :]
    back = 0.72 * back + 0.28 * tint

    atlas = np.concatenate([front, back], axis=1)
    tex_img = bpy.data.images.new(f"{cls_key}_atlas", W * 2, H, alpha=False)
    tex_img.pixels[:] = np.concatenate(
        [atlas, np.ones((H, W * 2, 1), np.float32)], axis=-1
    ).ravel()
    tex_path = os.path.join(OUT, f"hero_{cls_key}_ia_tex.png")
    tex_img.filepath_raw = tex_path
    tex_img.file_format = "PNG"
    tex_img.save()
    tex_img.pack()

    mat = bpy.data.materials.new(f"{cls_key}_art_mat")
    mat.use_nodes = True
    mat["roupa"] = "art"  # evita sobrescrita por paint_clothes
    nt = mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    tn = nt.nodes.new("ShaderNodeTexImage")
    tn.image = tex_img
    nt.links.new(tn.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.55
    bsdf.inputs["Metallic"].default_value = 0.15
    return mat


# ==============================================================================
# 2. Mapeamento UV Anatômico por Peça (Rest Pose do MPFB2 -> Regiões da Arte)
# ==============================================================================

def map_box_uv(
    obj,
    mat,
    u_range,
    v_range,
    x_bounds=None,
    z_bounds=None,
    mirror_x=False,
    use_back_atlas=True,
):
    """Mapeia os vértices de `obj` (no espaço do mundo do MPFB2, onde o personagem olha para -Y)
    para a caixa (u_min..u_max, v_min..v_max) na metade esquerda do atlas (0..0.5 = Frente)."""
    me = obj.data
    me.materials.clear()
    me.materials.append(mat)
    for old in list(me.uv_layers):
        me.uv_layers.remove(old)
    uv_layer = me.uv_layers.new(name="UV")

    mw = obj.matrix_world
    nmat = mw.to_3x3()
    wcos = [mw @ v.co for v in me.vertices]
    if x_bounds is None:
        mnx = min(c.x for c in wcos)
        mxx = max(c.x for c in wcos)
    else:
        mnx, mxx = x_bounds
    if z_bounds is None:
        mnz = min(c.z for c in wcos)
        mxz = max(c.z for c in wcos)
    else:
        mnz, mxz = z_bounds

    u0, u1 = u_range
    v0, v1 = v_range
    dx = max(mxx - mnx, 1e-5)
    dz = max(mxz - mnz, 1e-5)

    for poly in me.polygons:
        wn = (nmat @ poly.normal).normalized()
        # No espaço MPFB2 antes do giro final: Frente = -Y (wn.y < 0), Costas = +Y (wn.y > 0)
        is_back = use_back_atlas and (wn.y > 0.22)
        for li in poly.loop_indices:
            vi = me.loops[li].vertex_index
            c = wcos[vi]
            # No MPFB2 olhando para -Y: direita da imagem (+u) é +X do mundo!
            tx = min(max((c.x - mnx) / dx, 0.0), 1.0)
            # Nas laterais da malha (|wn.y| pequeno), puxa tx levemente para dentro para nunca amostrar a borda da silhueta
            inward = 0.58 + 0.42 * min(abs(wn.y) * 1.4, 1.0)
            tx = 0.5 + (tx - 0.5) * inward
            tz = min(max((c.z - mnz) / dz, 0.0), 1.0)
            if mirror_x == "right":
                # Espelha a metade direita limpa da imagem (tx=0.5..1.0) para os dois lados
                tx = abs(tx - 0.5) * 2.0
                u_img = u0 + tx * (u1 - u0)
            elif mirror_x:
                # Espelha a metade esquerda limpa da imagem (tx=0..0.5) para os dois lados
                tx = abs(tx - 0.5) * 2.0
                u_img = u0 + (1.0 - tx) * (u1 - u0)
            else:
                u_img = u0 + tx * (u1 - u0)
            v_img = v0 + tz * (v1 - v0)
            if is_back:
                u_atlas = 0.5 + (1.0 - u_img) * 0.5
            else:
                u_atlas = u_img * 0.5
            uv_layer.data[li].uv = (u_atlas, v_img)


def map_arms_uv(obj, c, mat, u_range, v_range):
    """Mapeia mangas, braçadeiras e luvas ao longo do eixo do braço (ombro -> punho -> ponta dos dedos),
    para que mesmo na pose A de 45° a textura caia perfeitamente alinhada com o braço vertical da arte!"""
    me = obj.data
    me.materials.clear()
    me.materials.append(mat)
    for old in list(me.uv_layers):
        me.uv_layers.remove(old)
    uv_layer = me.uv_layers.new(name="UV")

    mw = obj.matrix_world
    nmat = mw.to_3x3()
    wcos = [mw @ v.co for v in me.vertices]

    sh_l = K.bone_head(c.arm, "upperarm_l")
    wr_l = K.bone_head(c.arm, "hand_l")
    ft_l = wr_l + (wr_l - sh_l).normalized() * 0.14

    sh_r = K.bone_head(c.arm, "upperarm_r")
    wr_r = K.bone_head(c.arm, "hand_r")
    ft_r = wr_r + (wr_r - sh_r).normalized() * 0.14

    u0, u1 = u_range
    v0, v1 = v_range  # v1 = topo da ombreira, v0 = punho/mão

    for poly in me.polygons:
        wn = (nmat @ poly.normal).normalized()
        is_back = wn.y > 0.25
        for li in poly.loop_indices:
            c_pos = wcos[me.loops[li].vertex_index]
            if c_pos.x >= 0:  # braço esquerdo (+X no MPFB2)
                sh, ft = sh_l, ft_l
            else:             # braço direito (-X no MPFB2)
                sh, ft = sh_r, ft_r
            ax = ft - sh
            L = max(ax.length, 1e-5)
            ax_n = ax / L
            rel = c_pos - sh
            t_arm = min(max(rel.dot(ax_n) / L, 0.0), 1.0)
            # Posição transversal no cilindro do braço
            perp = rel - ax_n * rel.dot(ax_n)
            s_arm = min(max((perp.y + 0.07) / 0.14, 0.0), 1.0)
            u_img = u0 + s_arm * (u1 - u0)
            v_img = v1 - t_arm * (v1 - v0)
            u_atlas = (0.5 + (1.0 - u_img) * 0.5) if is_back else (u_img * 0.5)
            uv_layer.data[li].uv = (u_atlas, v_img)


# ==============================================================================
# 3. Peças 3D Comuns: Saias/ Escamas Divididas por Perna (Zero Esticamento)
# ==============================================================================

def split_tassets(c, mat, u_range, v_range, zmin_off=-0.04, zmax_off=0.08, mirror_x=False):
    """Cria as placas de quadril/saia de batalha divididas ao meio (x < -0.012 e x > 0.012)
    para que cada coxa leve apenas o seu lado sem nunca esticar um triângulo entre as pernas."""
    z0 = c.knee_z + zmin_off
    z1 = c.hip_z + zmax_off
    panels = []
    for side_name, pred in (
        ("BarraL", lambda p: p.x > 0.012),
        ("BarraR", lambda p: p.x < -0.012),
    ):
        o = piece(
            c,
            c.skirt,
            side_name,
            ["pelvis", "thigh_l", "thigh_r"],
            mat,
            offset=0.015,
            thick=0.008,
            thresh=0.05,
            zmin=z0,
            zmax=z1,
            keep_fn=pred,
        )
        if o is not None:
            panels.append(o)
    for o in panels:
        map_box_uv(o, mat, u_range, v_range, x_bounds=(-0.24, 0.24), z_bounds=(z0, z1), mirror_x=mirror_x)
    return panels


# ==============================================================================
# 4. Construção das 4 Classes + Armas 3D Rígidas
# ==============================================================================

def build_lanceiro():
    """Lanceiro de Vyndara: armadura de escamas e aço azulado, elmo de Valquíria com asas 3D,
    runas ciano brilhantes, capa longa e lança rúnica presa no nó Weapon."""
    img_path = os.path.join(ASSETS, "Lanceiro Frame", "frame_000.png")
    c = A.base(Na.MACROS, Na.TARGETS, "lanceiro", (0.88, 0.68, 0.55))
    art = build_art_material("lanceiro", img_path, back_tint=(0.12, 0.18, 0.28))
    steel = K.color_mat("lanceiro_aco", (0.52, 0.58, 0.68), metal=0.85, rough=0.3)
    rune = K.color_mat("lanceiro_runa", (0.35, 0.85, 1.0), glow=4.5)
    cape_mat = K.color_mat("lanceiro_capa", (0.10, 0.18, 0.32), rough=0.75)

    # Rosto pintado pela arte
    map_box_uv(
        c.body,
        art,
        (0.44, 0.60),
        (0.75, 0.89),
        x_bounds=(-0.11, 0.11),
        z_bounds=(c.head.z - 0.05, c.head_top.z + 0.02),
    )

    # Calças e Botas (pernas separadas)
    calca = piece(
        c, c.tights, "Calca", ["pelvis"] + LEGS, art, offset=0.006, zmin=c.ankle_z + 0.06
    )
    bota = piece(
        c,
        c.tights,
        "Bota",
        ["calf_l", "calf_r"] + FEET,
        art,
        offset=0.016,
        thresh=0.3,
        zmax=c.knee_z + 0.04,
    )
    map_box_uv(calca, art, (0.35, 0.72), (0.14, 0.42), x_bounds=(-0.22, 0.22), z_bounds=(c.ankle_z + 0.06, c.hip_z + 0.05))
    map_box_uv(bota, art, (0.34, 0.73), (0.05, 0.33), x_bounds=(-0.22, 0.22), z_bounds=(0.0, c.knee_z + 0.04))

    # Mangas, Braçadeiras e Luvas mapeadas ao longo do braço
    mangas = piece(c, c.tights, "Gibao", UPPER + LOWER, art, offset=0.009)
    brac = piece(c, c.tights, "Bracadeira", LOWER, art, offset=0.016, thresh=0.45, zmax=c.elbow_z - 0.02)
    D.gloves(c, art, 0.011)
    luva = c.parts[-1]
    for arm_obj in (mangas, brac, luva):
        map_arms_uv(arm_obj, c, art, (0.64, 0.80), (0.44, 0.77))

    # Peitoral e Torso
    peito = piece(
        c,
        c.tights,
        "Peitoral",
        TORSO,
        art,
        offset=0.018,
        thick=0.01,
        zmin=c.hip_z - 0.04,
    )
    map_box_uv(peito, art, (0.37, 0.66), (0.50, 0.78), x_bounds=(-0.22, 0.22), z_bounds=(c.hip_z - 0.04, c.head.z))

    # Escamas da cintura divididas por coxa (sem esticar entre as pernas)
    split_tassets(c, art, (0.37, 0.69), (0.31, 0.52))

    # Ombreiras 3D com textura rúnica da arte + medalhões brilhantes
    for side, bone, u_pad in ((1, "upperarm_l", (0.56, 0.75)), (-1, "upperarm_r", (0.32, 0.46))):
        sh = K.bone_head(c.arm, bone)
        pad = prim(
            "sphere",
            "Ombreira",
            art,
            sh + Vector((side * 0.04, 0.0, 0.035)),
            (0.16, 0.16, 0.12),
            rot=(0, side * 0.35, 0),
        )
        map_box_uv(pad, art, u_pad, (0.66, 0.79))
        rigid(c, pad, bone)
        med = prim(
            "sphere",
            "GemaOmbro",
            rune,
            sh + Vector((side * 0.02, -0.075, 0.02)),
            (0.032, 0.016, 0.032),
        )
        rigid(c, med, bone)

    # Elmo de Valquíria 3D + Asas 3D esculpidas nas laterais
    h, s = c.head, (c.head_top - c.head).length
    neck_z = K.bone_head(c.arm, "neck_01").z
    elmo = D.head_shell(
        c,
        "Elmo",
        art,
        0.024,
        lambda p: p.z > neck_z and not (p.y < h.y - s * 0.18 and neck_z + 0.02 < p.z < c.eye_z + s * 0.05 and abs(p.x) < s * 0.38),
        0.012,
        2,
    )
    map_box_uv(elmo, art, (0.44, 0.60), (0.76, 0.89), x_bounds=(-0.12, 0.12), z_bounds=(neck_z, c.head_top.z + 0.03))
    gem_head = prim("sphere", "Joia", rune, Vector((0, h.y - s * 0.66, c.eye_z + s * 0.38)), (0.024, 0.015, 0.038))
    rigid(c, gem_head, "head")
    # Asas do elmo de Valquíria (4 lâminas de pena afiladas nas têmporas, varridas para trás/cima)
    for side in (-1, 1):
        for k in range(4):
            wing = prim(
                "cone",
                "Coroa",
                steel,
                c.head + Vector((side * (s * 0.56 + k * 0.014), s * (0.04 + k * 0.09), s * (0.36 + k * 0.14))),
                (0.022, 0.055 - k * 0.006, 0.24 - k * 0.025),
                rot=(-0.62 - k * 0.12, side * 0.42, side * 0.18),
                seg=4,
            )
            rigid(c, wing, "head")

    D.cape(c, cape_mat, 1.18, 0.50, steel)

    # Animações e nó Weapon do Náutico (guarda de lança, estocadas e skills)
    for o in [c.body] + c.parts:
        if o.type == "MESH":
            K.apply_modifiers(o)
    Na.anims(c)
    Na.weapon_slot(c)
    _export_single_hero(c, "hero_lanceiro_ia")
    build_lanceiro_weapon(art, steel, rune)


def build_lanceiro_weapon(art, steel, rune):
    """Lança rúnica de Vyndara presa no nó Weapon (aponta para -Z como o tridente do Náutico)."""
    K.clear_scene()
    root = bpy.data.objects.new("WeaponRoot", None)
    bpy.context.collection.objects.link(root)
    dark_steel = K.color_mat("lanca_haste", (0.16, 0.20, 0.28), metal=0.8, rough=0.35)
    silver = K.color_mat("lanca_ponta", (0.78, 0.84, 0.94), metal=0.92, rough=0.22)
    glow = K.color_mat("lanca_runa", (0.35, 0.88, 1.0), glow=5.5)

    # Haste longa (-Z é para onde a arma aponta no espaço do nó Weapon do Náutico)
    shaft = prim("cyl", "Haste", dark_steel, Vector((0, 0, -0.95)), (0.075, 0.075, 3.3), seg=10)
    shaft.parent = root
    # Guarda cônica acima da mão
    guard = prim("cone", "Guarda", silver, Vector((0, 0, -0.45)), (0.22, 0.22, 0.28), rot=(math.pi, 0, 0), seg=10, r2=0.05)
    guard.parent = root
    # Anéis rúnicos brilhantes ao longo da haste
    for k in range(5):
        rn = prim("torus", f"Runa{k}", glow, Vector((0, 0, -0.7 - k * 0.32)), (0.10, 0.10, 0.35), minor=0.035)
        rn.parent = root
    # Lâmina principal + aletas laterais
    blade = prim("cone", "Ponta", silver, Vector((0, 0, -2.95)), (0.18, 0.06, 0.78), rot=(math.pi, 0, 0), seg=6)
    blade.parent = root
    core = prim("box", "NucleoRuna", glow, Vector((0, 0, -2.52)), (0.045, 0.045, 0.32))
    core.parent = root
    for s in (-1, 1):
        wing = prim("cone", "Aleta", silver, Vector((s * 0.12, 0, -2.48)), (0.08, 0.04, 0.32), rot=(0, s * 2.35, 0), seg=4)
        wing.parent = root
    # Ponteira inferior (butt-spike)
    butt = prim("cone", "Calcanhar", silver, Vector((0, 0, 0.78)), (0.11, 0.11, 0.26), seg=8)
    butt.parent = root

    _export_weapon(root, "weapon_lanceiro_ia")


def build_guerreiro():
    """Guerreiro Cavaleiro do Dragão: armadura de escamas escuras, elmo de dragão com 4 chifres curvos,
    Escudo do Dragão 3D preso na mão esquerda (hand_l) com a textura do dragão da arte, e Espada Rúnica
    presa no nó Weapon da mão direita (hand_r)."""
    img_path = os.path.join(ASSETS, "Guerriero Frame", "frame_000.png")
    c = A.base(Na.MACROS, Na.TARGETS, "guerreiro", (0.86, 0.65, 0.52))
    art = build_art_material("guerreiro", img_path, back_tint=(0.14, 0.13, 0.12))
    dark_steel = K.color_mat("guerreiro_aco", (0.18, 0.17, 0.19), metal=0.88, rough=0.32)
    horn_mat = K.color_mat("guerreiro_chifre", (0.14, 0.13, 0.14), metal=0.65, rough=0.4)
    ice_glow = K.color_mat("guerreiro_gelo", (0.45, 0.88, 1.0), glow=4.5)

    # Rosto
    map_box_uv(
        c.body,
        art,
        (0.42, 0.59),
        (0.76, 0.89),
        x_bounds=(-0.11, 0.11),
        z_bounds=(c.head.z - 0.05, c.head_top.z + 0.02),
    )

    # Calças e Grevas/Botas mapeadas da metade direita limpa da arte (u=0.53..0.64, sem a espada!)
    calca = piece(c, c.tights, "Calca", ["pelvis"] + LEGS, art, offset=0.006, zmin=c.ankle_z + 0.06)
    bota = piece(c, c.tights, "Bota", ["calf_l", "calf_r"] + FEET, art, offset=0.017, thresh=0.3, zmax=c.knee_z + 0.04)
    map_box_uv(calca, art, (0.53, 0.64), (0.18, 0.48), x_bounds=(-0.22, 0.22), z_bounds=(c.ankle_z + 0.06, c.hip_z + 0.05), mirror_x="right")
    map_box_uv(bota, art, (0.52, 0.64), (0.04, 0.32), x_bounds=(-0.22, 0.22), z_bounds=(0.0, c.knee_z + 0.04), mirror_x="right")

    # Braços, Braçadeiras e Manoplas mapeados do braço direito limpo da arte (u=0.23..0.38)
    mangas = piece(c, c.tights, "Gibao", UPPER + LOWER, art, offset=0.009)
    brac = piece(c, c.tights, "Bracadeira", LOWER, art, offset=0.016, thresh=0.45, zmax=c.elbow_z - 0.02)
    D.gloves(c, art, 0.011)
    luva = c.parts[-1]
    for arm_obj in (mangas, brac, luva):
        map_arms_uv(arm_obj, c, art, (0.24, 0.38), (0.44, 0.78))

    # Peitoral de escamas espelhando a metade limpa (u=0.34..0.53) para não pintar o escudo no peito!
    peito = piece(c, c.tights, "Peitoral", TORSO, art, offset=0.019, thick=0.01, zmin=c.hip_z - 0.04)
    map_box_uv(peito, art, (0.34, 0.53), (0.50, 0.78), x_bounds=(-0.22, 0.22), z_bounds=(c.hip_z - 0.04, c.head.z), mirror_x=True)

    # Escamas da cintura divididas por coxa (espelhando o lado direito limpo da arte, sem a espada!)
    split_tassets(c, art, (0.52, 0.65), (0.34, 0.54), mirror_x="right")

    # Ombreiras de Dragão
    for side, bone in ((1, "upperarm_l"), (-1, "upperarm_r")):
        sh = K.bone_head(c.arm, bone)
        pad = prim("sphere", "Ombreira", art, sh + Vector((side * 0.04, 0.0, 0.035)), (0.17, 0.17, 0.13), rot=(0, side * 0.35, 0))
        map_box_uv(pad, art, (0.25, 0.42), (0.67, 0.79))
        rigid(c, pad, bone)

    # Elmo de Dragão + 4 Chifres Curvos 3D (SK.horn)
    h, s = c.head, (c.head_top - c.head).length
    neck_z = K.bone_head(c.arm, "neck_01").z
    elmo = D.head_shell(
        c,
        "Elmo",
        art,
        0.025,
        lambda p: p.z > neck_z and not (p.y < h.y - s * 0.18 and neck_z + 0.01 < p.z < c.eye_z - s * 0.08 and abs(p.x) < s * 0.32),
        0.013,
        2,
    )
    map_box_uv(elmo, art, (0.41, 0.61), (0.77, 0.90), x_bounds=(-0.12, 0.12), z_bounds=(neck_z, c.head_top.z + 0.03))
    for side in (-1, 1):
        # Chifre principal grande curvado para cima/dentro
        b0 = c.head_top + Vector((side * s * 0.38, -s * 0.05, -s * 0.12))
        p1 = b0 + Vector((side * s * 0.55, s * 0.08, s * 0.48))
        p2 = b0 + Vector((side * s * 0.25, s * 0.12, s * 0.95))
        h1 = SK.horn("ChifreDragao", horn_mat, b0, p1, p2, 0.034)
        rigid(c, h1, "head")
        # Chifre lateral menor
        b2 = c.head_top + Vector((side * s * 0.48, s * 0.02, -s * 0.28))
        h2 = SK.horn("Chifre", horn_mat, b2, b2 + Vector((side * s * 0.38, s * 0.08, s * 0.18)), b2 + Vector((side * s * 0.45, s * 0.14, s * 0.45)), 0.022)
        rigid(c, h2, "head")

    D.cape(c, K.color_mat("guerreiro_capa", (0.11, 0.10, 0.12), rough=0.8), 1.12, 0.48, dark_steel)

    # ESCUDO DO DRAGÃO 3D preso no antebraço/mão esquerda (lowerarm_l) com o brasão exato da arte!
    la = K.bone_head(c.arm, "lowerarm_l")
    ha = K.bone_head(c.arm, "hand_l")
    sh_center = la.lerp(ha, 0.65) + Vector((0.09, -0.09, -0.02))
    shield = _create_kite_shield("Escudo", art, sh_center, width=0.38, height=0.56, thick=0.022)
    map_box_uv(
        shield,
        art,
        (0.61, 0.92),
        (0.35, 0.70),
        x_bounds=(sh_center.x - 0.19, sh_center.x + 0.19),
        z_bounds=(sh_center.z - 0.28, sh_center.z + 0.28),
        use_back_atlas=True,
    )
    rigid(c, shield, "lowerarm_l")

    for o in [c.body] + c.parts:
        if o.type == "MESH":
            K.apply_modifiers(o)
    Na.anims(c)
    Na.weapon_slot(c)
    _export_single_hero(c, "hero_guerreiro_ia")
    build_guerreiro_weapon(dark_steel, ice_glow)


def _create_kite_shield(name, mat, center, width=0.38, height=0.56, thick=0.022):
    """Escudo aquecedor/pipa curvado (largo no topo, afunila na ponta de baixo) para o Cavaleiro do Dragão."""
    nx, nz = 12, 16
    verts, faces = [], []
    for iz in range(nz + 1):
        tz = iz / nz  # 0 = ponta de baixo, 1 = topo do escudo
        # Largura do escudo: afunila suavemente até a ponta inferior
        w_factor = (tz ** 0.55) * (1.0 - 0.08 * ((tz - 0.75) ** 2))
        half_w = 0.5 * width * max(w_factor, 0.04)
        z = (tz - 0.5) * height
        # Topo em arco leve
        if tz > 0.85:
            pass
        for ix in range(nx + 1):
            tx = (ix / nx) * 2.0 - 1.0  # -1..1
            x = tx * half_w
            # Curvatura convexa para a frente (-Y no MPFB2)
            curve_y = -0.045 * (1.0 - tx * tx)
            verts.append(center + Vector((x, curve_y, z)))
    for iz in range(nz):
        for ix in range(nx):
            a = iz * (nx + 1) + ix
            b = a + 1
            c_ = a + (nx + 1) + 1
            d = a + (nx + 1)
            faces.append((a, b, c_, d))
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v) for v in verts], [], faces)
    o = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(o)
    for p in o.data.polygons:
        p.use_smooth = True
    o.data.materials.append(mat)
    bpy.context.view_layer.objects.active = o
    md = o.modifiers.new("Esp", "SOLIDIFY")
    md.thickness = thick
    K.apply_modifiers(o, keep=())
    return o


def build_guerreiro_weapon(dark_steel, ice_glow):
    """Espada Longa Rúnica do Dragão presa no nó Weapon (aponta para -Z)."""
    K.clear_scene()
    root = bpy.data.objects.new("WeaponRoot", None)
    bpy.context.collection.objects.link(root)
    silver = K.color_mat("espada_lamina", (0.82, 0.88, 0.96), metal=0.95, rough=0.2)
    grip_mat = K.color_mat("espada_cabo", (0.22, 0.15, 0.11), rough=0.75)
    guard_mat = K.color_mat("espada_guarda", (0.35, 0.38, 0.44), metal=0.88, rough=0.28)
    gem_mat = K.color_mat("espada_safira", (0.25, 0.72, 1.0), glow=6.0)
    aura_mat = K.color_mat("espada_aura", (0.45, 0.88, 1.0), glow=4.5)

    # Cabo e pomo
    grip = prim("cyl", "Cabo", grip_mat, Vector((0, 0, 0.18)), (0.07, 0.07, 0.42), seg=10)
    grip.parent = root
    pommel = prim("sphere", "Pomo", guard_mat, Vector((0, 0, 0.42)), (0.13, 0.09, 0.13))
    pommel.parent = root
    # Guarda alada com safira central
    guard = prim("box", "Guarda", guard_mat, Vector((0, 0, -0.05)), (0.58, 0.09, 0.09))
    guard.parent = root
    for s in (-1, 1):
        wing = prim("cone", "GuardaAsa", guard_mat, Vector((s * 0.34, 0, -0.10)), (0.09, 0.06, 0.24), rot=(0, s * 1.9, 0), seg=4)
        wing.parent = root
    gem = prim("sphere", "GemaGuarda", gem_mat, Vector((0, 0, -0.05)), (0.12, 0.12, 0.14))
    gem.parent = root
    # Lâmina longa e fio brilhante azul-gelo
    blade = prim("box", "Lamina", silver, Vector((0, 0, -1.15)), (0.18, 0.038, 2.1))
    blade.parent = root
    tip = prim("cone", "Ponta", silver, Vector((0, 0, -2.35)), (0.18, 0.038, 0.32), rot=(math.pi, 0, 0), seg=4)
    tip.parent = root
    glow_edge = prim("box", "FioRunico", aura_mat, Vector((0, 0, -1.12)), (0.055, 0.048, 1.95))
    glow_edge.parent = root

    _export_weapon(root, "weapon_guerreiro_ia")


def build_arqueira():
    """Arqueira Caçadora da Floresta: capuz e armadura de couro trabalhado com cota de malha,
    aljava com flechas nas costas (spine_03), arco recurvo 3D na mão esquerda (hand_l) e flecha na mão direita."""
    img_path = os.path.join(ASSETS, "Arqueira Frame", "frame_000.png")
    c = A.base(D.MACROS, D.TARGETS, "arqueira", (0.92, 0.74, 0.62))
    art = build_art_material("arqueira", img_path, back_tint=(0.22, 0.16, 0.11))
    leather = K.color_mat("arqueira_couro", (0.30, 0.20, 0.13), rough=0.72)
    wood = K.color_mat("arqueira_madeira", (0.38, 0.24, 0.13), rough=0.65)
    feather = K.color_mat("arqueira_pena", (0.85, 0.80, 0.68), rough=0.8)
    steel = K.color_mat("arqueira_aco", (0.72, 0.75, 0.80), metal=0.85, rough=0.3)

    # Rosto feminino da arte
    map_box_uv(
        c.body,
        art,
        (0.40, 0.59),
        (0.77, 0.91),
        x_bounds=(-0.10, 0.10),
        z_bounds=(c.head.z - 0.05, c.head_top.z + 0.02),
    )

    # Calças verdes e Botas de couro de cano dobrado (100% livres na arte: v=0.04..0.36)
    calca = piece(c, c.tights, "Calca", ["pelvis"] + LEGS, art, offset=0.005, zmin=c.ankle_z + 0.06)
    bota = piece(c, c.tights, "Bota", ["calf_l", "calf_r"] + FEET, art, offset=0.015, thresh=0.3, zmax=c.knee_z + 0.03)
    map_box_uv(calca, art, (0.28, 0.70), (0.16, 0.37), x_bounds=(-0.21, 0.21), z_bounds=(c.ankle_z + 0.06, c.hip_z + 0.05))
    map_box_uv(bota, art, (0.25, 0.72), (0.04, 0.28), x_bounds=(-0.21, 0.21), z_bounds=(0.0, c.knee_z + 0.03))

    # Mangas e Braçadeiras mapeadas do braço esquerdo limpo da arte (u=0.60..0.76)
    mangas = piece(c, c.tights, "Gibao", UPPER + LOWER, art, offset=0.008)
    brac = piece(c, c.tights, "Bracadeira", LOWER, art, offset=0.014, thresh=0.45, zmax=c.elbow_z - 0.02)
    D.gloves(c, art, 0.009)
    luva = c.parts[-1]
    for arm_obj in (mangas, brac, luva):
        map_arms_uv(arm_obj, c, art, (0.60, 0.76), (0.46, 0.78))

    # Corpete/Peitoral de couro com correias em X (região limpa acima do antebraço: v=0.58..0.78)
    peito = piece(c, c.tights, "Peitoral", TORSO, art, offset=0.016, thick=0.008, zmin=c.hip_z - 0.03)
    map_box_uv(peito, art, (0.35, 0.63), (0.58, 0.78), x_bounds=(-0.20, 0.20), z_bounds=(c.hip_z - 0.03, c.head.z))

    # Abas da túnica de couro + cota de malha divididas por coxa
    split_tassets(c, art, (0.32, 0.67), (0.34, 0.44))

    # Ombreiras de couro em camadas
    for side, bone in ((1, "upperarm_l"), (-1, "upperarm_r")):
        sh = K.bone_head(c.arm, bone)
        pad = prim("sphere", "Ombreira", art, sh + Vector((side * 0.035, 0.0, 0.03)), (0.14, 0.14, 0.10), rot=(0, side * 0.35, 0))
        map_box_uv(pad, art, (0.58, 0.74), (0.68, 0.78))
        rigid(c, pad, bone)

    # Capuz de couro 3D + Gola mapeada no colarinho (sem duplicar o rosto!) + mechas de cabelo
    D.hood(c, art, point=True)
    for o in c.parts[-3:]:
        if o.type == "MESH":
            if o.name.startswith("Gola"):
                map_box_uv(o, art, (0.38, 0.62), (0.66, 0.74))
            else:
                map_box_uv(o, art, (0.37, 0.62), (0.76, 0.94))
    h, s = c.head, (c.head_top - c.head).length
    hair_mat = K.color_mat("arqueira_cabelo", (0.48, 0.35, 0.22), rough=0.65)
    for side in (-1, 1):
        lock = prim("sphere", "MechaLado", hair_mat, Vector((side * s * 0.44, h.y - s * 0.18, c.eye_z - s * 0.25)), (s * 0.16, s * 0.20, s * 0.75), rot=(0.1, side * 0.15, 0))
        rigid(c, lock, "head")

    # ALJAVA 3D com flechas nas costas (presa em spine_03)
    sp3 = K.bone_head(c.arm, "spine_03")
    quiver = prim("cyl", "Mochila", leather, sp3 + Vector((-0.08, 0.13, 0.08)), (0.09, 0.09, 0.42), rot=(0.15, 0.38, 0), seg=10)
    rigid(c, quiver, "spine_03")
    for k in range(5):
        off = Vector((-0.08 - 0.06 + (k - 2) * 0.018, 0.14 + (k % 2) * 0.012, 0.28))
        arr = prim("cyl", f"FlechaAljava{k}", wood, sp3 + off, (0.012, 0.012, 0.24), rot=(0.15, 0.38, 0), seg=6)
        rigid(c, arr, "spine_03")
        fth = prim("cone", f"PenaAljava{k}", feather, sp3 + off + Vector((-0.04, 0.02, 0.10)), (0.028, 0.012, 0.07), rot=(0.15, 0.38, 0), seg=4)
        rigid(c, fth, "spine_03")

    # ARCO RECURVO 3D preso na mão esquerda (hand_l) inclinado em 3D para aparecer de frente e de lado
    hl = K.bone_head(c.arm, "hand_l")
    bow = _create_recurve_bow("Arco", wood, steel, hl + Vector((0.02, -0.05, 0.0)))
    rigid(c, bow, "hand_l")

    for o in [c.body] + c.parts:
        if o.type == "MESH":
            K.apply_modifiers(o)
    _arqueira_anims(c)
    Na.weapon_slot(c)
    _export_single_hero(c, "hero_arqueira_ia")
    build_arqueira_weapon(wood, steel, feather)


def _arqueira_anims(c):
    """Postura e animações de Arqueira: mão esquerda sustenta o arco à frente, mão direita puxa e dispara a flecha."""
    sin, cos, tau = math.sin, math.cos, math.tau
    base = {
        "clavicle_l": [(Y, -0.10)],
        "upperarm_l": [(Y, -0.45), (X, -0.48), (Z, 0.25)],
        "lowerarm_l": [(X, -0.35), (Y, 0.18)],
        "hand_l": [(Z, -0.25)],
        "clavicle_r": [(Y, 0.10)],
        "upperarm_r": [(Y, 0.48), (X, -0.32), (Z, -0.22)],
        "lowerarm_r": [(X, -0.68), (Y, -0.22)],
        "thigh_l": [(X, -0.06), (Z, -0.05)],
        "calf_l": [(X, 0.12)],
        "foot_l": [(X, -0.05)],
        "thigh_r": [(X, 0.04), (Z, 0.05)],
        "calf_r": [(X, 0.10)],
        "foot_r": [(X, -0.08)],
    }
    for f in ("index", "middle", "ring", "pinky"):
        for k, ang in (("01", 1.1), ("02", 1.3), ("03", 1.0)):
            base[f"{f}_{k}_l"] = [("L", "Z", -ang)]
            base[f"{f}_{k}_r"] = [("L", "Z", ang)]

    def legs(p, swing, knee, lift):
        out = {}
        for side, ph in (("l", 0.0), ("r", math.pi)):
            s, c_ = sin(p + ph), cos(p + ph)
            thigh = -swing * s
            calf = 0.08 + knee * max(0.0, c_) ** 2
            foot = -(thigh + calf) * 0.85 + lift * max(0.0, -s) * max(0.0, -c_)
            out[f"thigh_{side}"] = [(X, thigh)]
            out[f"calf_{side}"] = [(X, calf)]
            out[f"foot_{side}"] = [(X, foot)]
            out[f"ball_{side}"] = [(X, -0.35 * max(0.0, -s) * max(0.0, -c_))]
        return out

    def idle(t):
        b = sin(t * tau)
        b2 = sin(t * tau * 2 + 0.6)
        return {
            "spine_02": [(X, -0.012 * b)],
            "spine_03": [(X, -0.02 * b), (Z, 0.015 * b2)],
            "upperarm_l": [(Y, 0.02 * b), (X, 0.02 * b2)],
            "lowerarm_l": [(X, -0.03 * b)],
            "head": [(Z, 0.05 * sin(t * tau + 1.2)), (X, 0.015 * b)],
            "_loc": Vector((0.004 * b2, 0, -0.004 * (1 - cos(t * tau)))),
        }

    def walk(t):
        p = t * tau
        s = sin(p)
        o = legs(p, 0.42, 1.05, 0.45)
        o.update({
            "pelvis": [(Z, -0.09 * s), (Y, 0.035 * cos(2 * p))],
            "spine_01": [(Z, 0.05 * s), (X, 0.03)],
            "spine_03": [(Z, 0.07 * s), (X, 0.02)],
            "upperarm_l": [(X, 0.22 * s)],
            "upperarm_r": [(X, -0.18 * s)],
            "_loc": Vector((0.012 * s, 0, -0.03 + 0.022 * cos(2 * p))),
        })
        return o

    def run(t):
        p = t * tau
        s = sin(p)
        o = legs(p, 0.72, 1.7, 0.7)
        o.update({
            "pelvis": [(Z, -0.12 * s), (X, 0.08)],
            "spine_01": [(Z, 0.08 * s), (X, 0.12)],
            "spine_03": [(Z, 0.11 * s), (X, 0.08)],
            "upperarm_l": [(X, 0.45 * s)],
            "upperarm_r": [(X, -0.35 * s)],
            "_loc": Vector((0.015 * s, 0, -0.06 + 0.05 * abs(cos(p)))),
        })
        return o

    def archer_attack(t):
        draw = K.pulse(t, 0.0, 0.28, 0.58, 0.76)
        rel = K.pulse(t, 0.58, 0.68, 0.78, 0.98)
        return {
            "spine_01": [(Z, 0.32 * draw - 0.08 * rel), (X, 0.08 * draw)],
            "spine_02": [(Z, 0.28 * draw - 0.06 * rel)],
            "head": [(Z, -0.48 * draw + 0.08 * rel), (X, -0.06 * draw)],
            "upperarm_l": [(X, -0.82 * draw - 0.55 * rel), (Y, 0.22 * draw), (Z, 0.35 * draw)],
            "lowerarm_l": [(X, 0.22 * draw)],
            "upperarm_r": [(X, -0.95 * draw - 0.35 * rel), (Y, 0.35 * draw + 0.55 * rel), (Z, -0.45 * draw)],
            "lowerarm_r": [(X, -0.85 * draw + 0.35 * rel), (Z, -0.35 * draw)],
        }

    anims = {
        "idle": (48, idle, True),
        "walk": (32, walk, True),
        "run": (22, run, True),
        "attack": (24, archer_attack, False),
        **SA.druida(),
    }
    K.write_actions(c.arm, anims, base)


def _create_recurve_bow(name, wood_mat, string_mat, grip_pos):
    """Arco recurvo 3D esculpido (curva dupla clássica + corda esticada, inclinado em 35° para boa leitura 3D)."""
    segs, rings = 8, 22
    verts, faces = [], []
    half_len = 0.50
    pts = []
    for i in range(rings + 1):
        u = (i / rings) * 2.0 - 1.0  # -1 (ponta de baixo) .. +1 (ponta de cima)
        z = u * half_len
        # Curva recurva inclinada em X e Y para aparecer de frente e na câmera isométrica
        arch = -0.12 * (1.0 - u * u) - 0.04 * (u ** 4)
        x = arch * 0.55 + u * 0.10
        y = arch * 0.85
        r = 0.022 * (1.0 - 0.50 * abs(u)) + 0.005
        pts.append((Vector((x, y, z)), r))
    for i, (pt, r) in enumerate(pts):
        for j in range(segs):
            ang = j / segs * math.tau
            verts.append(grip_pos + pt + Vector((math.cos(ang) * r, math.sin(ang) * r, 0)))
    for i in range(rings):
        for j in range(segs):
            a = i * segs + j
            b = i * segs + (j + 1) % segs
            faces.append((a, b, b + segs, a + segs))
    # Corda do arco ligando as duas pontas
    p_bot = grip_pos + pts[0][0] + Vector((0.01, 0.015, 0))
    p_top = grip_pos + pts[-1][0] + Vector((0.01, 0.015, 0))
    s_base = len(verts)
    for k, p_end in enumerate((p_bot, p_top)):
        for j in range(4):
            ang = j / 4 * math.tau
            verts.append(p_end + Vector((math.cos(ang) * 0.004, math.sin(ang) * 0.004, 0)))
    for j in range(4):
        jn = (j + 1) % 4
        faces.append((s_base + j, s_base + jn, s_base + 4 + jn, s_base + 4 + j))

    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v) for v in verts], [], faces)
    o = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(o)
    for p in o.data.polygons:
        p.use_smooth = True
    o.data.materials.append(wood_mat)
    return o


def build_arqueira_weapon(wood=None, steel=None, feather=None):
    """Flecha de caça pronta na mão direita (aponta para -Z no espaço do nó Weapon)."""
    K.clear_scene()
    root = bpy.data.objects.new("WeaponRoot", None)
    bpy.context.collection.objects.link(root)
    wood_m = K.color_mat("flecha_madeira", (0.38, 0.24, 0.13), rough=0.65)
    steel_m = K.color_mat("flecha_aco", (0.72, 0.75, 0.80), metal=0.85, rough=0.3)
    feather_m = K.color_mat("flecha_pena", (0.85, 0.80, 0.68), rough=0.8)
    shaft = prim("cyl", "HasteFlecha", wood_m, Vector((0, 0, -0.45)), (0.025, 0.025, 1.15), seg=6)
    shaft.parent = root
    tip = prim("cone", "PontaFlecha", steel_m, Vector((0, 0, -1.08)), (0.06, 0.025, 0.18), rot=(math.pi, 0, 0), seg=4)
    tip.parent = root
    fth = prim("cone", "PenaFlecha", feather_m, Vector((0, 0, 0.08)), (0.065, 0.02, 0.16), rot=(math.pi, 0, 0), seg=4)
    fth.parent = root
    _export_weapon(root, "weapon_arqueira_ia")


def build_mago():
    """Mago Arcano: capuz e túnica roxo-obsidiana com detalhes prateados, tiara com cristal azul na testa,
    adaga ritual na mão esquerda (hand_l) e Cajado de Cristal Retorcido no nó Weapon (hand_r).
    Como usamos a malha anatômica do MPFB2, toda a fumaça mágica do fundo da imagem é 100% ignorada!"""
    img_path = os.path.join(ASSETS, "Mago Frame", "frame_000.png")
    c = A.base(Na.MACROS, Na.TARGETS, "mago", (0.86, 0.68, 0.58))
    art = build_art_material("mago", img_path, back_tint=(0.14, 0.10, 0.24))
    silver = K.color_mat("mago_prata", (0.72, 0.76, 0.88), metal=0.9, rough=0.25)
    crystal = K.color_mat("mago_cristal", (0.35, 0.85, 1.0), glow=5.5)
    robe_back = K.color_mat("mago_capa", (0.14, 0.10, 0.25), rough=0.75)

    # Rosto do Mago
    map_box_uv(
        c.body,
        art,
        (0.42, 0.61),
        (0.76, 0.89),
        x_bounds=(-0.11, 0.11),
        z_bounds=(c.head.z - 0.05, c.head_top.z + 0.02),
    )

    # Calças e Botas arcanas gravadas
    calca = piece(c, c.tights, "Calca", ["pelvis"] + LEGS, art, offset=0.006, zmin=c.ankle_z + 0.06)
    bota = piece(c, c.tights, "Bota", ["calf_l", "calf_r"] + FEET, art, offset=0.016, thresh=0.3, zmax=c.knee_z + 0.03)
    map_box_uv(calca, art, (0.33, 0.72), (0.16, 0.42), x_bounds=(-0.22, 0.22), z_bounds=(c.ankle_z + 0.06, c.hip_z + 0.05))
    map_box_uv(bota, art, (0.31, 0.46), (0.06, 0.34), x_bounds=(-0.22, 0.22), z_bounds=(0.0, c.knee_z + 0.03), mirror_x=True)

    # Mangas, Braçadeiras de Prata e Luvas mapeadas do braço esquerdo limpo (u=0.62..0.78)
    mangas = piece(c, c.tights, "Gibao", UPPER + LOWER, art, offset=0.009)
    brac = piece(c, c.tights, "Bracadeira", LOWER, art, offset=0.016, thresh=0.45, zmax=c.elbow_z - 0.02)
    D.gloves(c, art, 0.010)
    luva = c.parts[-1]
    for arm_obj in (mangas, brac, luva):
        map_arms_uv(arm_obj, c, art, (0.62, 0.78), (0.46, 0.78))

    # Peitoral Arcano e Túnica
    peito = piece(c, c.tights, "Peitoral", TORSO, art, offset=0.018, thick=0.01, zmin=c.hip_z - 0.04)
    map_box_uv(peito, art, (0.36, 0.65), (0.52, 0.78), x_bounds=(-0.22, 0.22), z_bounds=(c.hip_z - 0.04, c.head.z))

    # Robe de Batalha dividido por perna com bordados prateados (v=0.22..0.52)
    split_tassets(c, art, (0.34, 0.69), (0.22, 0.52), zmin_off=-0.12, zmax_off=0.08)

    # Ombreiras Arcanas + Fivelas de Prata
    for side, bone, u_pad in ((1, "upperarm_l", (0.58, 0.75)), (-1, "upperarm_r", (0.31, 0.46))):
        sh = K.bone_head(c.arm, bone)
        pad = prim("sphere", "Ombreira", art, sh + Vector((side * 0.04, 0.0, 0.035)), (0.16, 0.16, 0.12), rot=(0, side * 0.35, 0))
        map_box_uv(pad, art, u_pad, (0.66, 0.78))
        rigid(c, pad, bone)
        clasp = prim("sphere", "GemaOmbro", silver, sh + Vector((side * 0.015, -0.075, 0.02)), (0.03, 0.015, 0.03))
        rigid(c, clasp, bone)

    # Capuz Arcano + Gola mapeada no colarinho (sem duplicar o rosto!) + Tiara de Prata + Diamante Azul
    D.hood(c, art, point=True)
    for o in c.parts[-3:]:
        if o.type == "MESH":
            if o.name.startswith("Gola"):
                map_box_uv(o, art, (0.40, 0.63), (0.64, 0.73))
            else:
                map_box_uv(o, art, (0.40, 0.63), (0.76, 0.91))
    h, s = c.head, (c.head_top - c.head).length
    crown = prim("torus", "Coroa", silver, Vector((0, h.y - s * 0.05, c.eye_z + s * 0.38)), (s * 1.12, s * 1.18, 0.22), rot=(0.15, 0, 0), minor=0.055)
    rigid(c, crown, "head")
    gem = prim("sphere", "Joia", crystal, Vector((0, h.y - s * 0.68, c.eye_z + s * 0.42)), (0.028, 0.018, 0.042))
    rigid(c, gem, "head")

    D.cape(c, robe_back, 1.22, 0.54, silver)

    # Adaga Ritual na mão esquerda (hand_l)
    hl = K.bone_head(c.arm, "hand_l")
    dag = prim("cone", "AdagaEsquerda", silver, hl + Vector((0.02, -0.14, -0.04)), (0.035, 0.015, 0.24), rot=(math.pi / 2, 0, 0), seg=4)
    rigid(c, dag, "hand_l")

    for o in [c.body] + c.parts:
        if o.type == "MESH":
            K.apply_modifiers(o)
    D.anims(c)
    D.weapon_slot(c)
    _export_single_hero(c, "hero_mago_ia")
    build_mago_weapon(silver, crystal)


def build_mago_weapon(silver=None, crystal=None):
    """Cajado Arcano Retorcido com Cristal de Gelo Brilhante no topo (+Z no espaço do nó Weapon da Druida)."""
    K.clear_scene()
    root = bpy.data.objects.new("WeaponRoot", None)
    bpy.context.collection.objects.link(root)
    dark_wood = K.color_mat("cajado_mago_haste", (0.16, 0.13, 0.20), metal=0.6, rough=0.4)
    silver_m = K.color_mat("cajado_mago_prata", (0.72, 0.76, 0.88), metal=0.9, rough=0.25)
    crystal_m = K.color_mat("cajado_mago_cristal", (0.35, 0.85, 1.0), glow=5.5)

    # Haste principal (+Z aponta para cima no nó Weapon da Druida)
    shaft = prim("cyl", "Cajado", dark_wood, Vector((0, 0, 0.35)), (0.085, 0.085, 2.65), seg=10)
    shaft.parent = root
    # Galhos espirais prateados envolvendo o cristal no topo
    for k in range(3):
        ang = k * math.tau / 3
        spiral = prim(
            "cyl",
            f"Espiral{k}",
            silver_m,
            Vector((math.cos(ang) * 0.11, math.sin(ang) * 0.11, 1.62)),
            (0.045, 0.045, 0.58),
            rot=(math.sin(ang) * 0.28, -math.cos(ang) * 0.28, 0),
            seg=6,
        )
        spiral.parent = root
    # Cristal azul facetado brilhante no topo
    cr_top = prim("cone", "CristalTopo", crystal_m, Vector((0, 0, 1.98)), (0.28, 0.22, 0.48), seg=6)
    cr_top.parent = root
    cr_bot = prim("cone", "CristalBase", crystal_m, Vector((0, 0, 1.66)), (0.28, 0.22, 0.32), rot=(math.pi, 0, 0), seg=6)
    cr_bot.parent = root
    butt = prim("cone", "PonteiraBase", silver_m, Vector((0, 0, -1.02)), (0.10, 0.10, 0.24), rot=(math.pi, 0, 0), seg=6)
    butt.parent = root

    _export_weapon(root, "weapon_mago_ia")


# ==============================================================================
# 5. Exportação para o Jogo (models/hero_<cls>_ia.glb & weapon_<cls>_ia.glb)
# ==============================================================================

def _export_single_hero(c, model_name):
    root = bpy.data.objects.new("Hero", None)
    bpy.context.collection.objects.link(root)
    c.arm.parent = root
    root.rotation_euler = (0, 0, math.pi)  # MPFB olha para -Y; o jogo espera +Y
    root.scale = (K.HERO_SCALE,) * 3
    if c.eyes is not None:
        K.apply_modifiers(c.eyes)
    for o in (c.tights, c.skirt, c.hairm):
        o.hide_render = True
    objs = [root, c.arm, c.body] + c.parts + ([c.eyes] if c.eyes else [])
    K.lighten(objs)
    out_path = os.path.join(OUT, f"{model_name}.glb")
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=out_path,
        export_format="GLB",
        use_selection=True,
        export_yup=True,
        export_cameras=False,
        export_lights=False,
        export_animations=True,
        export_animation_mode="NLA_TRACKS",
        export_skins=True,
        export_apply=False,
        export_vertex_color="ACTIVE",
    )
    print("OK HERO:", out_path)


def _export_weapon(root, weapon_name):
    objs = [root] + list(root.children_recursive)
    out_path = os.path.join(OUT, f"{weapon_name}.glb")
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=out_path,
        export_format="GLB",
        use_selection=True,
        export_yup=True,
        export_cameras=False,
        export_lights=False,
        export_animations=False,
    )
    print("OK WEAPON:", out_path)


def main():
    K.enable()
    build_lanceiro()
    build_guerreiro()
    build_arqueira()
    build_mago()


if __name__ == "__main__":
    main()
