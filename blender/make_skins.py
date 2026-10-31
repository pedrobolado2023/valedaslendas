"""
Skins (só aparência) — mesmo corpo, esqueleto e animações das classes; cada skin exporta as peças por encaixe como
uma "raridade" com o id da skin: models/hero_<classe>_<id>_<encaixe>.glb (+ o modelo inteiro, usado só para a foto).
Rode:  MH_DATA=<makehuman/data> blender -b -P blender/make_skins.py -- sk_eloreth[,sk_outra]
Catálogo (nome, raridade, preço, requisitos) em GameData.SKINS (scripts/data.gd).
"""
import math
import os
import sys

from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mpfb_kit as K  # noqa: E402
import make_druid_mpfb as D  # noqa: E402
import make_mechanic_mpfb as Mc  # noqa: E402
import make_sete as SE  # noqa: E402

K.MH_DATA = os.environ.get("MH_DATA", K.MH_DATA)
TORSO, UPPER, LOWER, LEGS, FEET = D.TORSO, D.UPPER, D.LOWER, D.LEGS, D.FEET
piece, rigid, prim, leaf, belt = D.piece, D.rigid, D.prim, D.leaf, D.belt


def horn(name, mat, base, p1, p2, r0, rings=12, seg=10):
    """Chifre curvo: tubo que afina ao longo de uma curva de Bézier (base → p1 → ponta p2)."""
    import bpy
    verts, faces = [], []
    for i in range(rings + 1):
        t = i / rings
        a = base.lerp(p1, t)
        b = p1.lerp(p2, t)
        pt = a.lerp(b, t)
        d = ((p1 - base).lerp(p2 - p1, t)).normalized()
        side = d.cross(Vector((0, 0, 1)))
        if side.length < 1e-4:
            side = Vector((1, 0, 0))
        side.normalize()
        up = side.cross(d).normalized()
        r = r0 * (1.0 - t) ** 0.8 + 0.002
        for j in range(seg):
            ang = j / seg * math.tau
            verts.append(pt + side * math.cos(ang) * r + up * math.sin(ang) * r)
    for i in range(rings):
        for j in range(seg):
            a, b = i * seg + j, i * seg + (j + 1) % seg
            faces.append((a, b, b + seg, a + seg))
    faces.append(tuple(range(seg))[::-1])
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v) for v in verts], [], faces)
    o = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(o)
    for f in o.data.polygons:
        f.use_smooth = True
    o.data.materials.append(mat)
    return o


def petal_layer(c, m, z0, z1, r_bottom, r_top, n, tip, phase=0.0):
    """Camada de saia em cone com a barra recortada em pétalas (pontas para baixo), uma malha só."""
    import bpy
    segs, rings = n * 8, 6
    py = K.bone_head(c.arm, "pelvis").y + 0.01
    verts, faces = [], []
    for i in range(rings + 1):
        t = i / rings
        for j in range(segs):
            a = j / segs * math.tau
            r = r_top + (r_bottom - r_top) * t
            z = z0 + (z1 - z0) * t
            if i == rings:   # barra: ponta no meio de cada pétala, recorte entre elas
                w = abs(math.cos(a * n / 2 + phase))
                z -= tip * (w ** 0.6)
                r += tip * 0.3 * w
            elif i == rings - 1:
                z -= tip * 0.35 * abs(math.cos(a * n / 2 + phase)) ** 0.6
            verts.append((math.sin(a) * r, py - math.cos(a) * r * 0.82, z))
    for i in range(rings):
        for j in range(segs):
            a_, b_ = i * segs + j, i * segs + (j + 1) % segs
            faces.append((a_, b_, b_ + segs, a_ + segs))
    me = bpy.data.meshes.new("SaiaFolha")
    me.from_pydata(verts, [], faces)
    o = bpy.data.objects.new("SaiaFolha", me)
    bpy.context.collection.objects.link(o)
    for f in o.data.polygons:
        f.use_smooth = True
    o.data.materials.append(m)
    bpy.context.view_layer.objects.active = o
    md = o.modifiers.new("Esp", "SOLIDIFY")
    md.thickness = 0.01
    K.apply_modifiers(o, keep=())
    rigid(c, o, "pelvis")
    return o


def half_skirt(c, m, z0, z1, r_bottom, r_top, a0=0.0, a1=math.pi, name="Saia"):
    """Pedaço de saia em cone só entre os ângulos a0..a1 (0 = frente, +π/2 = esquerda da personagem)."""
    import bpy
    segs, rings = 24, 6
    py = K.bone_head(c.arm, "pelvis").y + 0.01
    verts, faces = [], []
    for i in range(rings + 1):
        t = i / rings
        r = r_top + (r_bottom - r_top) * t
        z = z0 + (z1 - z0) * t
        for j in range(segs + 1):
            a = a0 + (a1 - a0) * j / segs
            verts.append((math.sin(a) * r, py - math.cos(a) * r * 0.82, z))
    for i in range(rings):
        for j in range(segs):
            a_, b_ = i * (segs + 1) + j, i * (segs + 1) + j + 1
            faces.append((a_, b_, b_ + segs + 1, a_ + segs + 1))
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    o = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(o)
    for f in o.data.polygons:
        f.use_smooth = True
    o.data.materials.append(m)
    bpy.context.view_layer.objects.active = o
    md = o.modifiers.new("Esp", "SOLIDIFY")
    md.thickness = 0.01
    K.apply_modifiers(o, keep=())
    rigid(c, o, "pelvis")
    return o


def long_skirt(c, m, z0, z1, r_bottom, r_top):
    """Saia longa em cone presa à bacia (até os pés)."""
    import bpy
    bpy.ops.mesh.primitive_cone_add(vertices=40, radius1=r_bottom, radius2=r_top, depth=z0 - z1, end_fill_type="NOTHING")
    o = bpy.context.active_object
    o.name = "Saia"
    o.location = Vector((0, K.bone_head(c.arm, "pelvis").y + 0.01, (z0 + z1) / 2))
    o.scale = (1.0, 0.82, 1.0)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bpy.ops.object.shade_smooth()
    o.data.materials.append(m)
    md = o.modifiers.new("Esp", "SOLIDIFY")
    md.thickness = 0.012
    K.apply_modifiers(o, keep=())
    rigid(c, o, "pelvis")
    return o


# =================================================================== Druida

def sk_eloreth(c):
    """Guardiã de Eloreth: vestido prateado em camadas, folhas de prata na cintura e nos ombros, tiara de folhas com
    um cristal, cabelo platinado solto e capa branca com barra verde."""
    silver = K.color_mat("ske_prata", (0.84, 0.87, 0.94), metal=0.7, rough=0.25)
    cloth = K.color_mat("ske_veste", (0.93, 0.95, 0.98), rough=0.6)
    dress = K.color_mat("ske_vestido", (0.88, 0.92, 0.96), metal=0.2, rough=0.4)
    sash = K.color_mat("ske_faixa", (0.36, 0.72, 0.58), rough=0.5)
    crystal = K.color_mat("ske_cristal", (0.3, 0.95, 0.68), glow=1.3)
    hair = K.color_mat("ske_cabelo", (0.92, 0.92, 0.96), rough=0.45)
    piece(c, c.tights, "Traje", TORSO + UPPER + LOWER + ["pelvis"] + LEGS, K.color_mat("ske_manga", (0.72, 0.84, 0.82), rough=0.6), offset=0.005, zmin=c.ankle_z + 0.05)
    piece(c, c.tights, "Tunica", TORSO, dress, offset=0.012, zmin=c.hip_z - 0.04)
    piece(c, c.skirt, "TunicaSaia", ["pelvis", "thigh_l", "thigh_r"], dress, offset=0.016, thresh=0.05, zmin=c.knee_z - 0.08)
    piece(c, c.tights, "Bota", ["calf_l", "calf_r"] + FEET, silver, offset=0.016, thresh=0.3, zmax=c.knee_z - 0.04)
    D.gloves(c, silver)
    K.card_asset(c, c.extra[0], "Cabelo", (0.93, 0.92, 0.96), 1.25)
    K.card_asset(c, c.extra[1], "Sobrancelha", (0.75, 0.74, 0.8), 1.0)
    # cinto fino de prata na medida da cintura, com folhas caindo sobre o quadril
    zb = c.hip_z + 0.07
    cy, rx, ry = Mc.torso_size(c, zb)
    band = prim("torus", "Cinto", silver, Vector((0, cy, zb)), (2 * rx + 0.01, 2 * ry + 0.01, 0.35), minor=0.045)
    rigid(c, band, "spine_01")
    for k in range(12):
        a = k / 12 * math.tau
        pos = Vector((math.sin(a) * (rx + 0.012), cy - math.cos(a) * (ry + 0.012), zb - 0.09))
        lf = leaf("SaiaFolha", silver if k % 2 else sash, pos, 0.2, 0.08, (math.pi + 0.12 * math.cos(a), -0.12 * math.sin(a), a))
        rigid(c, lf, "pelvis")
    front = prim("sphere", "CintoFivela", crystal, Vector((0, cy - ry - 0.012, zb)), (0.03, 0.012, 0.04))
    rigid(c, front, "spine_01")
    # faixa verde caindo na frente do vestido até perto do joelho, com uma folha de prata na ponta
    fl = c.knee_z + 0.02
    cy2, rx2, ry2 = Mc.torso_size(c, fl + 0.04)            # a saia abre para fora: a faixa acompanha
    top = Vector((0, cy - ry - 0.02, zb - 0.02))
    bot = Vector((0, cy2 - ry2 - 0.018, fl))
    mid = (top + bot) / 2
    band2 = prim("box", "Faixa", sash, mid, (0.07, 0.008, (top - bot).length), rot=(-math.atan2(top.y - bot.y, top.z - bot.z), 0, 0))
    rigid(c, band2, "pelvis")
    tipf = leaf("SaiaFolha", silver, bot + Vector((0, -0.006, -0.03)), 0.1, 0.07, (math.pi, 0, 0))
    rigid(c, tipf, "pelvis")
    # ombros: uma folha de prata larga e curva, com um cristal
    for side, bone in ((1, "upperarm_l"), (-1, "upperarm_r")):
        sh = K.bone_head(c.arm, bone)
        lf = leaf("Ombreira", silver, sh + Vector((side * 0.045, 0.0, 0.035)), 0.2, 0.15, (0.0, side * 1.25, 0.0))
        rigid(c, lf, bone)
        gem = prim("sphere", "GemaOmbro", crystal, sh + Vector((side * 0.07, -0.02, 0.06)), (0.016, 0.016, 0.022))
        rigid(c, gem, bone)
    # tiara: aro fino, leque de 3 folhas de prata na testa e um cristal em gota
    h, s = c.head, (c.head_top - c.head).length
    ring = prim("torus", "Coroa", silver, Vector((0, h.y + s * 0.02, c.eye_z + s * 0.42)), (s * 1.14, s * 1.24, 0.25), rot=(0.18, 0, 0), minor=0.05)
    rigid(c, ring, "head")
    fz = c.eye_z + s * 0.5
    fy = h.y - s * 0.6
    for k, ang in enumerate((-0.55, 0.0, 0.55)):
        lf = leaf("Galho", silver, Vector((math.sin(ang) * 0.045, fy, fz + 0.045 + (0.015 if k == 1 else 0.0))), 0.12 if k == 1 else 0.1, 0.05, (0.25, ang, 0))
        rigid(c, lf, "head")
    gem = prim("sphere", "Joia", crystal, Vector((0, fy - 0.008, fz)), (0.024, 0.014, 0.034))
    rigid(c, gem, "head")
    gem = prim("sphere", "GemaPeito", crystal, K.bone_head(c.arm, "spine_03") + Vector((0, -0.13, 0.02)), (0.025, 0.012, 0.032))
    rigid(c, gem, "spine_03")
    D.cape(c, K.color_mat("ske_capa", (0.92, 0.94, 0.97), rough=0.6), 1.15, 0.46, dress)


def sk_cinzas(c):
    """Xamã das Cinzas (Drakaris): couraça de escamas vermelho-escuras, chifres de obsidiana, brasas nos pulsos,
    colar de dentes de dragão, capa cor de cinza com barra em brasa e trança vermelho-escura."""
    leather = K.color_mat("skc_couro", (0.16, 0.09, 0.07), rough=0.6)
    scale = K.color_mat("skc_escama", (0.5, 0.12, 0.08), metal=0.35, rough=0.35)
    obsid = K.color_mat("skc_obsidiana", (0.07, 0.06, 0.08), metal=0.6, rough=0.18)
    bone = K.color_mat("skc_osso", (0.88, 0.82, 0.7), rough=0.5)
    ember = K.color_mat("skc_brasa", (1.0, 0.45, 0.12), glow=1.6)
    ash = K.color_mat("skc_cinza", (0.24, 0.22, 0.22), rough=0.85)
    hornm = K.color_mat("skc_chifre", (0.3, 0.12, 0.09), metal=0.4, rough=0.3)
    piece(c, c.tights, "Traje", TORSO + UPPER + LOWER + ["pelvis"] + LEGS, leather, offset=0.005, zmin=c.ankle_z + 0.05)
    piece(c, c.tights, "Tunica", TORSO, scale, offset=0.013, zmin=c.hip_z - 0.04)
    piece(c, c.skirt, "TunicaSaia", ["pelvis", "thigh_l", "thigh_r"], leather, offset=0.016, thresh=0.05, zmin=c.knee_z + 0.02)
    piece(c, c.tights, "Bota", ["calf_l", "calf_r"] + FEET, obsid, offset=0.016, thresh=0.3, zmax=c.knee_z - 0.04)
    D.gloves(c, leather)
    K.card_asset(c, c.extra[0], "Cabelo", (0.62, 0.16, 0.09), 1.9)
    K.card_asset(c, c.extra[1], "Sobrancelha", (0.25, 0.08, 0.06), 1.0)
    h, s = c.head, (c.head_top - c.head).length
    for side in (-1, 1):   # chifres de obsidiana: saem das têmporas, sobem e curvam para trás
        base_p = Vector((side * s * 0.4, h.y - s * 0.15, c.eye_z + s * 0.5))   # nasce na testa, junto ao cabelo
        hr = horn("ChifreDragao", hornm, base_p, base_p + Vector((side * 0.06, 0.04, 0.15)), base_p + Vector((side * 0.1, 0.3, 0.12)), 0.06)
        rigid(c, hr, "head")
    # escamas sobre os ombros (três placas sobrepostas)
    for side, bone_n in ((1, "upperarm_l"), (-1, "upperarm_r")):
        sh = K.bone_head(c.arm, bone_n)
        for k in range(3):
            pl = leaf("Ombreira", obsid if k % 2 == 0 else scale, sh + Vector((side * (0.04 + k * 0.022), 0.0, 0.045 - k * 0.03)), 0.12, 0.09,
                      (0.0, side * (1.35 + k * 0.1), 0.0))
            rigid(c, pl, bone_n)
    # colar de dentes de dragão
    neck = K.bone_head(c.arm, "neck_01")
    cy, rx, ry = Mc.torso_size(c, neck.z - 0.05)
    for k in range(9):
        a = (k - 4) * 0.28
        p = Vector((math.sin(a) * (rx + 0.01), cy - math.cos(a) * (ry + 0.012), neck.z - 0.05 - (4 - abs(k - 4)) * 0.012))
        th = prim("cone", "Espinho", bone, p + Vector((0, -0.006, -0.03)), (0.026, 0.02, 0.07), rot=(math.pi + 0.15, 0, 0), seg=8)
        rigid(c, th, "spine_03")
    # brasas acesas nos pulsos
    for side in ("l", "r"):
        wr = K.bone_head(c.arm, "hand_" + side)
        cuff = prim("torus", "Bracadeira", obsid, wr + Vector((0, 0, 0.015)), (0.075, 0.075, 0.5), minor=0.12)
        rigid(c, cuff, "lowerarm_" + side)
        for k in range(3):
            em = prim("sphere", "Faixas", ember, wr + Vector(((k - 1) * 0.024, -0.038, 0.025 + 0.008 * k)), (0.026, 0.026, 0.034))
            rigid(c, em, "lowerarm_" + side)
    zb = c.hip_z + 0.07
    cy, rx, ry = Mc.torso_size(c, zb)
    band = prim("torus", "Cinto", obsid, Vector((0, cy, zb)), (2 * rx + 0.01, 2 * ry + 0.01, 0.4), minor=0.05)
    rigid(c, band, "spine_01")
    gem = prim("sphere", "CintoFivela", ember, Vector((0, cy - ry - 0.012, zb)), (0.032, 0.012, 0.032))
    rigid(c, gem, "spine_01")
    D.cape(c, ash, 1.1, 0.46, ember)


def sk_inverno(c):
    """Druida do Inverno (Valdrath): túnica azul-gelo, manto de pele branca com gola grossa, capuz de pele, botas
    forradas, cristais de gelo nos ombros e na testa, cabelo curto castanho-claro."""
    wool = K.color_mat("ski_la", (0.42, 0.58, 0.72), rough=0.8)
    fur = K.color_mat("ski_pele", (0.95, 0.95, 0.96), rough=0.95)
    leather = K.color_mat("ski_couro", (0.33, 0.24, 0.18), rough=0.7)
    ice = K.color_mat("ski_gelo", (0.6, 0.9, 1.0), glow=1.2)
    silver = K.color_mat("ski_prata", (0.78, 0.84, 0.9), metal=0.7, rough=0.3)
    piece(c, c.tights, "Traje", TORSO + UPPER + LOWER + ["pelvis"] + LEGS, wool, offset=0.005, zmin=c.ankle_z + 0.05)
    piece(c, c.tights, "Tunica", TORSO, K.color_mat("ski_tunica", (0.3, 0.45, 0.6), rough=0.75), offset=0.012, zmin=c.hip_z - 0.04)
    piece(c, c.skirt, "TunicaSaia", ["pelvis", "thigh_l", "thigh_r"], wool, offset=0.016, thresh=0.05, zmin=c.knee_z - 0.04)
    piece(c, c.tights, "Bota", ["calf_l", "calf_r"] + FEET, leather, offset=0.016, thresh=0.3, zmax=c.knee_z - 0.04)
    D.gloves(c, leather)
    K.card_asset(c, c.extra[0], "Cabelo", (0.55, 0.4, 0.28), 1.5)
    K.card_asset(c, c.extra[1], "Sobrancelha", (0.4, 0.28, 0.2), 1.0)
    for side in ("l", "r"):   # bordas de pele nas botas
        kn = K.bone_head(c.arm, "calf_" + side)
        cuff = prim("torus", "Bota", fur, kn + Vector((0, 0.005, -0.07)), (0.12, 0.12, 0.45), minor=0.16)
        rigid(c, cuff, "calf_" + side)
    # gola de pele grossa (sobre os ombros)
    neck = K.bone_head(c.arm, "neck_01")
    for k in range(2):
        g = prim("torus", "Gola", fur, neck + Vector((0, 0.015, -0.035 - k * 0.035)), (0.3 + k * 0.05, 0.27 + k * 0.04, 0.55), minor=0.14)
        rigid(c, g, "spine_03")
    # cristais de gelo nos ombros
    for side, bone_n in ((1, "upperarm_l"), (-1, "upperarm_r")):
        sh = K.bone_head(c.arm, bone_n)
        for k, (dx, ln) in enumerate(((0.0, 0.09), (0.03, 0.06), (-0.025, 0.05))):
            cr = prim("cone", "GemaOmbro", ice, sh + Vector((side * (0.05 + dx), 0.02, 0.07 + ln / 2)), (0.03, 0.03, ln), rot=(0.2 * k, side * -0.35, 0), seg=6)
            rigid(c, cr, bone_n)
    # tiara de prata com cristal de gelo na testa
    h, s = c.head, (c.head_top - c.head).length
    ring = prim("torus", "Coroa", silver, Vector((0, h.y + s * 0.02, c.eye_z + s * 0.42)), (s * 1.14, s * 1.24, 0.25), rot=(0.18, 0, 0), minor=0.05)
    rigid(c, ring, "head")
    fz, fy = c.eye_z + s * 0.5, h.y - s * 0.6
    for k, (dx, ln) in enumerate(((0.0, 0.09), (-0.03, 0.055), (0.03, 0.055))):
        cr = prim("cone", "Joia", ice, Vector((dx, fy, fz + ln / 2)), (0.026, 0.02, ln), rot=(0.15, dx * 6, 0), seg=6)
        rigid(c, cr, "head")
    zb = c.hip_z + 0.07
    cy, rx, ry = Mc.torso_size(c, zb)
    band = prim("torus", "Cinto", leather, Vector((0, cy, zb)), (2 * rx + 0.01, 2 * ry + 0.01, 0.4), minor=0.06)
    rigid(c, band, "spine_01")
    gem = prim("sphere", "CintoFivela", ice, Vector((0, cy - ry - 0.012, zb)), (0.03, 0.012, 0.034))
    rigid(c, gem, "spine_01")
    D.cape(c, fur, 1.15, 0.52, K.color_mat("ski_barra", (0.42, 0.58, 0.72), rough=0.8))


def sk_areias(c):
    """Oráculo das Areias (Seryth): túnica longa de linho creme, faixa e peitoral dourados com hieróglifos (barras
    gravadas), véu de seda sobre o cabelo preso, olho de turquesa na testa, braceletes de ouro."""
    linen = K.color_mat("ska_linho", (0.93, 0.86, 0.72), rough=0.75)
    gold = K.color_mat("ska_ouro", (0.95, 0.72, 0.28), metal=0.85, rough=0.3)
    turq = K.color_mat("ska_turquesa", (0.2, 0.8, 0.78), glow=1.1)
    veil = K.color_mat("ska_veu", (0.78, 0.25, 0.2), rough=0.6)
    sand = K.color_mat("ska_sandalia", (0.45, 0.3, 0.17), rough=0.7)
    piece(c, c.tights, "Traje", TORSO + UPPER + LOWER + ["pelvis"] + LEGS, linen, offset=0.005, zmin=c.ankle_z + 0.05)
    long_skirt(c, linen, c.hip_z + 0.06, c.ankle_z + 0.03, 0.34, 0.2)
    piece(c, c.tights, "Bota", FEET, sand, offset=0.012, thresh=0.3, zmax=c.ankle_z + 0.05)
    D.gloves(c, K.color_mat("ska_pele_luva", (0.84, 0.66, 0.5), rough=0.6), offset=0.003)
    K.card_asset(c, c.extra[0], "Cabelo", (0.12, 0.08, 0.06), 1.4)
    K.card_asset(c, c.extra[1], "Sobrancelha", (0.1, 0.07, 0.05), 1.0)
    # peitoral dourado em gola larga (colar egípcio): três aros com barras gravadas
    neck = K.bone_head(c.arm, "neck_01")
    for k in range(3):   # colar largo deitado sobre o peito (mais baixo na frente)
        g = prim("torus", "Gorjal", gold if k != 1 else turq, neck + Vector((0, -0.01 - k * 0.012, -0.045 - k * 0.022)),
                 (0.27 + k * 0.05, 0.25 + k * 0.045, 0.3), rot=(0.42, 0, 0), minor=0.1 if k != 1 else 0.07)
        rigid(c, g, "spine_03")
    # faixa dourada na cintura com "hieróglifos" (placas) caindo na frente
    zb = c.hip_z + 0.07
    cy, rx, ry = Mc.torso_size(c, zb)
    band = prim("torus", "Cinto", gold, Vector((0, cy, zb)), (2 * rx + 0.012, 2 * ry + 0.012, 0.6), minor=0.09)
    rigid(c, band, "spine_01")
    fl = c.knee_z - 0.05
    z0s, z1s = c.hip_z + 0.06, c.ankle_z + 0.03          # mesma saia em cone (frente: raio × 0,82)
    py = K.bone_head(c.arm, "pelvis").y + 0.01
    rz = lambda z: (0.2 + (0.34 - 0.2) * (z0s - z) / (z0s - z1s)) * 0.82
    top = Vector((0, py - rz(zb - 0.05) - 0.012, zb - 0.05))
    bot = Vector((0, py - rz(fl) - 0.012, fl))
    tilt = -math.atan2(top.y - bot.y, top.z - bot.z)
    band2 = prim("box", "Faixa", gold, (top + bot) / 2, (0.09, 0.008, (top - bot).length), rot=(tilt, 0, 0))
    rigid(c, band2, "pelvis")
    for k in range(4):   # hieróglifos em turquesa ao longo da faixa
        t = (k + 0.7) / 5
        gl = prim("box", "Faixa", turq, top.lerp(bot, t) + Vector((0, -0.006, 0)), (0.045, 0.006, 0.022 if k % 2 else 0.035), rot=(tilt, 0, 0))
        rigid(c, gl, "pelvis")
    # braceletes de ouro
    for side in ("l", "r"):
        wr = K.bone_head(c.arm, "hand_" + side)
        for k in range(2):
            cu = prim("torus", "Bracadeira", gold, wr + Vector((0, 0, 0.03 + k * 0.035)), (0.072, 0.072, 0.4), minor=0.1)
            rigid(c, cu, "lowerarm_" + side)
    # tiara com olho de turquesa e véu caindo pelas costas
    h, s2 = c.head, (c.head_top - c.head).length
    ring = prim("torus", "Coroa", gold, Vector((0, h.y + s2 * 0.02, c.eye_z + s2 * 0.42)), (s2 * 1.14, s2 * 1.24, 0.3), rot=(0.18, 0, 0), minor=0.06)
    rigid(c, ring, "head")
    eye = prim("sphere", "Joia", turq, Vector((0, h.y - s2 * 0.61, c.eye_z + s2 * 0.5)), (0.03, 0.012, 0.02))
    rigid(c, eye, "head")
    for side in (-1, 1):
        dr = prim("sphere", "Joia", gold, Vector((side * s2 * 0.6, h.y - s2 * 0.05, c.eye_z - s2 * 0.42)), (0.016, 0.016, 0.04))
        rigid(c, dr, "head")
    D.cape(c, veil, 1.25, 0.42, gold)


def sk_ninfa(c):
    """Ninfa das Cachoeiras (Thalyss): vestido azul-água em camadas, escamas turquesa nos braços e ombros, gotas de
    água brilhando no cabelo solto azul-escuro, conchas no cinto e tiara de conchas."""
    water = K.color_mat("skn_agua", (0.3, 0.68, 0.82), rough=0.35)
    deep = K.color_mat("skn_fundo", (0.18, 0.45, 0.66), rough=0.45)
    scale = K.color_mat("skn_escama", (0.25, 0.85, 0.75), metal=0.5, rough=0.25)
    drop = K.color_mat("skn_gota", (0.6, 0.95, 1.0), glow=1.3)
    shell = K.color_mat("skn_concha", (0.98, 0.86, 0.8), rough=0.4)
    piece(c, c.tights, "Traje", TORSO + UPPER + LOWER + ["pelvis"] + LEGS, deep, offset=0.005, zmin=c.ankle_z + 0.05)
    piece(c, c.tights, "Tunica", TORSO, water, offset=0.012, zmin=c.hip_z - 0.04)
    long_skirt(c, deep, c.hip_z + 0.06, c.ankle_z + 0.06, 0.32, 0.2)
    piece(c, c.tights, "Bota", FEET, shell, offset=0.012, thresh=0.3, zmax=c.ankle_z + 0.05)
    D.gloves(c, K.color_mat("skn_pele_luva", (0.86, 0.68, 0.56), rough=0.6), offset=0.003)
    K.card_asset(c, c.extra[0], "Cabelo", (0.12, 0.32, 0.5), 1.6)
    K.card_asset(c, c.extra[1], "Sobrancelha", (0.1, 0.22, 0.35), 1.0)
    # escamas em fileiras nos braços (de ombro a cotovelo) e nos ombros
    for side, up_b in ((1, "upperarm_l"), (-1, "upperarm_r")):
        sh = K.bone_head(c.arm, up_b)
        el = K.bone_head(c.arm, "lowerarm_" + ("l" if side == 1 else "r"))
        for k in range(6):
            t = k / 6
            p = sh.lerp(el, t) + Vector((side * 0.045, -0.02, 0.0))
            sc = leaf("Ombreira", scale, p, 0.1, 0.085, (0.0, side * 1.4, 0.0))
            rigid(c, sc, up_b)
    # segunda saia (camada de "cascata") mais curta, azul escuro, com gotas na barra
    long_skirt(c, water, c.hip_z + 0.07, c.knee_z - 0.02, 0.27, 0.205)
    for k in range(10):
        a = k / 10 * math.tau
        z = c.knee_z - 0.04
        r = 0.205 + (0.27 - 0.205) * ((c.hip_z + 0.07 - z) / (c.hip_z + 0.07 - (c.knee_z - 0.02))) + 0.008
        py = K.bone_head(c.arm, "pelvis").y + 0.01
        dp = prim("sphere", "Barra", drop, Vector((math.sin(a) * r, py - math.cos(a) * r * 0.82, z)), (0.02, 0.02, 0.03))
        rigid(c, dp, "pelvis")
    zb = c.hip_z + 0.07
    cy, rx, ry = Mc.torso_size(c, zb)
    band = prim("torus", "Cinto", scale, Vector((0, cy, zb)), (2 * rx + 0.01, 2 * ry + 0.01, 0.4), minor=0.05)
    rigid(c, band, "spine_01")
    for k in range(5):   # conchas no cinto
        a = (k - 2) * 0.45
        cs = prim("sphere", "CintoFivela", shell, Vector((math.sin(a) * (rx + 0.015), cy - math.cos(a) * (ry + 0.015), zb)), (0.03, 0.012, 0.03))
        rigid(c, cs, "spine_01")
    # tiara de conchas e gotas no cabelo
    h, s2 = c.head, (c.head_top - c.head).length
    ring = prim("torus", "Coroa", shell, Vector((0, h.y + s2 * 0.02, c.eye_z + s2 * 0.42)), (s2 * 1.14, s2 * 1.24, 0.25), rot=(0.18, 0, 0), minor=0.05)
    rigid(c, ring, "head")
    for k in range(3):
        ang = (k - 1) * 0.5
        cs = prim("sphere", "Joia", shell, Vector((math.sin(ang) * 0.06, h.y - s2 * 0.58 + abs(k - 1) * 0.02, c.eye_z + s2 * 0.5)), (0.035, 0.012, 0.03), rot=(0, 0, ang))
        rigid(c, cs, "head")
    import random
    rnd = random.Random(3)
    for k in range(9):   # gotas espalhadas no cabelo
        az = rnd.uniform(0.6, math.pi * 2 - 0.6)
        el = rnd.uniform(-0.2, 0.9)
        d = Vector((math.sin(az) * math.cos(el), -math.cos(az) * math.cos(el), math.sin(el)))
        dp = prim("sphere", "Joia", drop, c.head.lerp(c.head_top, 0.45) + d * s2 * 0.7, (0.016, 0.016, 0.024))
        rigid(c, dp, "head")
    D.cape(c, K.color_mat("skn_veu", (0.55, 0.85, 0.92), rough=0.3), 1.2, 0.48, scale)


def sk_bruxa(c):
    """Bruxa do Pântano Sombrio (Sombras): manto roxo-escuro com capuz pontudo, saia longa rasgada em tiras, cogumelos
    roxos brilhando nos ombros e no cinto, olhos roxos brilhando, colar de ossinhos e cabelo preto solto."""
    robe = K.color_mat("skb_manto", (0.22, 0.13, 0.28), rough=0.85)
    dark = K.color_mat("skb_escuro", (0.1, 0.08, 0.12), rough=0.8)
    moss = K.color_mat("skb_musgo", (0.25, 0.32, 0.16), rough=0.9)
    glow = K.color_mat("skb_brilho", (0.75, 0.35, 1.0), glow=1.4)
    cap = K.color_mat("skb_chapeu", (0.5, 0.2, 0.6), rough=0.5)
    stem = K.color_mat("skb_talo", (0.85, 0.8, 0.72), rough=0.6)
    bone = K.color_mat("skb_osso", (0.88, 0.84, 0.74), rough=0.5)
    piece(c, c.tights, "Traje", TORSO + UPPER + LOWER + ["pelvis"] + LEGS, dark, offset=0.005, zmin=c.ankle_z + 0.05)
    piece(c, c.tights, "Tunica", TORSO + UPPER, robe, offset=0.012, zmin=c.hip_z - 0.04)
    long_skirt(c, robe, c.hip_z + 0.06, c.knee_z - 0.05, 0.27, 0.2)
    # tiras rasgadas descendo da saia até perto do pé (barra irregular)
    import random
    rnd = random.Random(5)
    py = K.bone_head(c.arm, "pelvis").y + 0.01
    z_top, z_bot = c.knee_z + 0.06, c.ankle_z + 0.06
    for k in range(28):
        a = k / 28 * math.tau
        ln = rnd.uniform(0.65, 1.0) * (z_top - z_bot)
        r = 0.25 + 0.012
        tr = leaf("Barra", robe if k % 4 else moss, Vector((math.sin(a) * r, py - math.cos(a) * r * 0.82, z_top - ln / 2)), ln, 0.055,
                  (math.pi + 0.08 * math.cos(a), -0.08 * math.sin(a), a))
        rigid(c, tr, "pelvis")
    piece(c, c.tights, "Bota", ["calf_l", "calf_r"] + FEET, dark, offset=0.014, thresh=0.3, zmax=c.knee_z - 0.06)
    D.gloves(c, dark)
    K.card_asset(c, c.extra[0], "Cabelo", (0.06, 0.05, 0.07), 1.6)
    K.card_asset(c, c.extra[1], "Sobrancelha", (0.08, 0.06, 0.09), 1.0)
    hd, sh2 = c.head, (c.head_top - c.head).length   # capuz pontudo (sem a gola grossa do hood padrão)
    chin, brow = c.head.z - sh2 * 0.6, c.eye_z + sh2 * 0.3
    D.head_shell(c, "Capuz", robe, 0.035, lambda p: p.z > chin - 0.02 and not (p.y < hd.y - sh2 * 0.05 and chin < p.z < brow and abs(p.x) < sh2 * 0.62), 0.012, 2)
    tip = prim("cone", "CapuzPonta", robe, hd + Vector((0, sh2 * 0.75, sh2 * 0.55)), (sh2 * 0.7, sh2 * 0.6, sh2 * 1.1), rot=(-2.1, 0, 0), r2=0.05)
    rigid(c, tip, "head")
    h, s2 = c.head, (c.head_top - c.head).length
    for side in (-1, 1):   # olhos roxos brilhando (por cima das íris)
        eye = prim("sphere", "OlhoBrilho", glow, Vector((side * s2 * 0.2, h.y - s2 * 0.66, c.eye_z + 0.004)), (0.018, 0.005, 0.008))
        rigid(c, eye, "head")

    def mushroom(pos, size, bone_n):
        st = prim("cyl", "Bolsa", stem, pos + Vector((0, 0, size * 0.5)), (size * 0.35, size * 0.35, size), seg=8)
        rigid(c, st, bone_n)
        cp = prim("sphere", "Bolsa", cap, pos + Vector((0, 0, size * 1.05)), (size * 1.4, size * 1.4, size * 0.7), seg=12)
        rigid(c, cp, bone_n)
        for j in range(3):
            dt = prim("sphere", "Bolsa", glow, pos + Vector((math.cos(j * 2.1) * size * 0.45, math.sin(j * 2.1) * size * 0.45, size * 1.3)), (size * 0.25,) * 3, seg=6)
            rigid(c, dt, bone_n)

    for side, bone_n in ((1, "upperarm_l"), (-1, "upperarm_r")):   # cogumelos nos ombros
        sh = K.bone_head(c.arm, bone_n)
        pad = leaf("Ombreira", moss, sh + Vector((side * 0.04, 0.0, 0.04)), 0.16, 0.13, (0.0, side * 1.25, 0.0))
        rigid(c, pad, bone_n)
        mushroom(sh + Vector((side * 0.06, 0.0, 0.07)), 0.07, bone_n)
        mushroom(sh + Vector((side * 0.11, 0.04, 0.05)), 0.045, bone_n)
    zb = c.hip_z + 0.07
    cy, rx, ry = Mc.torso_size(c, zb)
    band = prim("torus", "Cinto", K.color_mat("skb_corda", (0.35, 0.27, 0.18), rough=0.9), Vector((0, cy, zb)), (2 * rx + 0.01, 2 * ry + 0.01, 0.4), minor=0.05)
    rigid(c, band, "spine_01")
    mushroom(Vector((rx * 0.75, cy - ry * 0.6, zb - 0.02)), 0.05, "spine_01")
    # colar de ossinhos com uma gema roxa
    neck = K.bone_head(c.arm, "neck_01")
    cy3, rx3, ry3 = Mc.torso_size(c, neck.z - 0.05)
    for k in range(7):
        a = (k - 3) * 0.3
        p = Vector((math.sin(a) * (rx3 + 0.01), cy3 - math.cos(a) * (ry3 + 0.012), neck.z - 0.05 - (3 - abs(k - 3)) * 0.012))
        b = prim("cyl", "Espinho", bone, p + Vector((0, -0.004, -0.015)), (0.012, 0.012, 0.035), rot=(0.2, 0, 0), seg=6)
        rigid(c, b, "spine_03")
    gm = prim("sphere", "GemaPeito", glow, Vector((0, cy3 - ry3 - 0.02, neck.z - 0.11)), (0.03, 0.014, 0.036))
    rigid(c, gm, "spine_03")
    D.cape(c, robe, 1.2, 0.48, moss)


def wing(name, m, pts, thick=0.006):
    """Asa plana (borboleta/fada): polígono pelos pontos do contorno (x, z) num plano, com espessura."""
    import bpy
    verts = [(0.0, 0.0, 0.0)] + [(x, 0.0, z) for x, z in pts]
    faces = [(0, i, i + 1) for i in range(1, len(pts))]
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    o = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(o)
    o.data.materials.append(m)
    bpy.context.view_layer.objects.active = o
    md = o.modifiers.new("Esp", "SOLIDIFY")
    md.thickness = thick
    K.apply_modifiers(o, keep=())
    return o


def wing_shape(upper, lower, n=14):
    """Contorno de asa de borboleta (lado +x): lóbulo de cima e lóbulo de baixo."""
    pts = []
    for i in range(n + 1):
        t = math.radians(100 - 110 * i / n)
        r = upper * (0.75 + 0.25 * math.sin(t * 2))
        pts.append((math.cos(t) * r, math.sin(t) * r * 0.85))
    for i in range(1, n + 1):
        t = math.radians(-10 - 85 * i / n)
        r = lower * (0.8 + 0.2 * math.sin(-t * 2))
        pts.append((math.cos(t) * r, math.sin(t) * r))
    return pts


def sk_primavera(c):
    """Avatar da Primavera (Lendária): vestido longo branco com sobressaia de pétalas rosadas, corpete rosa com folhas
    douradas, grandes asas de fada (borboleta) nas costas, coroa de flores e borboletas pousadas, cabelo dourado."""
    white = K.color_mat("skp_branco", (0.98, 0.95, 0.96), rough=0.45)
    pink = K.color_mat("skp_rosa", (0.97, 0.66, 0.78), rough=0.45)
    rose = K.color_mat("skp_rosa2", (0.92, 0.45, 0.62), rough=0.45)
    gold = K.color_mat("skp_ouro", (1.0, 0.82, 0.35), metal=0.75, rough=0.28)
    leafg = K.color_mat("skp_folha", (0.55, 0.8, 0.42), rough=0.5)
    wing_m = K.color_mat("skp_asa", (0.82, 0.95, 1.0), glow=0.55)
    wing_e = K.color_mat("skp_asa_borda", (1.0, 0.72, 0.35), glow=0.9)
    piece(c, c.tights, "Traje", TORSO + UPPER + LOWER + ["pelvis"] + LEGS, white, offset=0.005, zmin=c.ankle_z + 0.05)
    piece(c, c.tights, "Tunica", TORSO, pink, offset=0.012, zmin=c.hip_z - 0.04)
    long_skirt(c, K.color_mat("skp_rosa3", (0.99, 0.84, 0.88), rough=0.45), c.hip_z + 0.06, c.ankle_z + 0.03, 0.34, 0.2)
    z0s, z1s = c.hip_z + 0.06, c.ankle_z + 0.03
    rz = lambda z: 0.2 + (0.34 - 0.2) * (z0s - z) / (z0s - z1s)
    zk = c.knee_z + 0.02    # sobressaia de pétalas rosadas até o joelho (duas camadas) e barra de pétalas no pé
    petal_layer(c, pink, z0s + 0.01, zk, rz(zk) + 0.03, rz(z0s) + 0.03, 10, 0.12, 0.0)
    petal_layer(c, rose, z0s - 0.02, zk + 0.1, rz(zk + 0.1) + 0.045, rz(z0s) + 0.045, 8, 0.1, 0.6)
    petal_layer(c, white, zk + 0.02, z1s + 0.02, rz(z1s) + 0.02, rz(zk) + 0.02, 14, 0.07, 0.3)
    piece(c, c.tights, "Bota", FEET, gold, offset=0.012, thresh=0.3, zmax=c.ankle_z + 0.05)
    D.gloves(c, white, offset=0.004)
    K.card_asset(c, c.extra[0], "Cabelo", (0.98, 0.84, 0.55), 1.5)
    K.card_asset(c, c.extra[1], "Sobrancelha", (0.7, 0.55, 0.35), 1.0)
    def flower(pos, size, bone_n, m):
        for j in range(5):
            ang = j / 5 * math.tau
            pe = prim("sphere", "Joia", m, pos + Vector((math.cos(ang) * size * 0.55, 0, math.sin(ang) * size * 0.55)), (size * 0.62, size * 0.2, size * 0.42), rot=(0, ang, 0))
            rigid(c, pe, bone_n)
        ce = prim("sphere", "Joia", gold, pos + Vector((0, -size * 0.12, 0)), (size * 0.4, size * 0.25, size * 0.4))
        rigid(c, ce, bone_n)

    zb = c.hip_z + 0.07
    cy, rx, ry = Mc.torso_size(c, zb)
    band = prim("torus", "Cinto", gold, Vector((0, cy, zb)), (2 * rx + 0.01, 2 * ry + 0.01, 0.3), minor=0.045)
    rigid(c, band, "spine_01")
    flower(Vector((0, cy - ry - 0.02, zb)), 0.05, "spine_01", white)

    for side, bone_n in ((1, "upperarm_l"), (-1, "upperarm_r")):
        sh = K.bone_head(c.arm, bone_n)
        for k in range(2):
            lf = leaf("Ombreira", leafg, sh + Vector((side * (0.035 + k * 0.025), 0.0, 0.045 - k * 0.02)), 0.12, 0.06, (0.0, side * (1.2 + k * 0.25), 0.0))
            rigid(c, lf, bone_n)
        flower(sh + Vector((side * 0.05, -0.05, 0.06)), 0.045, bone_n, pink)
    h, s2 = c.head, (c.head_top - c.head).length
    ring = prim("torus", "Coroa", leafg, Vector((0, h.y + s2 * 0.02, c.eye_z + s2 * 0.42)), (s2 * 1.14, s2 * 1.24, 0.3), rot=(0.18, 0, 0), minor=0.05)
    rigid(c, ring, "head")
    for k in range(9):
        ang = (k - 4) * 0.42
        pos = Vector((math.sin(ang) * s2 * 0.6, h.y - math.cos(ang) * s2 * 0.6 + 0.01, c.eye_z + s2 * 0.47))
        flower(pos, 0.034 if k % 2 == 0 else 0.026, "head", pink if k % 3 else white)
    # asas de fada grandes nas costas (com borda dourada)
    sp = K.bone_head(c.arm, "spine_03")
    cy3, rx3, ry3 = Mc.torso_size(c, sp.z)
    root = Vector((0, cy3 + ry3 + 0.03, sp.z - 0.02))
    for side in (-1, 1):
        pts = [(side * x, z) for x, z in wing_shape(0.42, 0.26)]
        w = wing("Capa", wing_m, pts)
        w.location = root + Vector((side * 0.02, 0, 0.04))
        w.rotation_euler = (0.12, 0, side * -0.3)
        rigid(c, w, "spine_03")
        edge = wing("Capa", wing_e, [(side * x * 1.06, z * 1.06) for x, z in wing_shape(0.42, 0.26)], 0.004)
        edge.location = root + Vector((side * 0.02, 0.008, 0.04))
        edge.rotation_euler = (0.12, 0, side * -0.3)
        rigid(c, edge, "spine_03")

    def butterfly(pos, size, bone_n, m, yaw=0.0):
        for side in (-1, 1):
            bw = wing("Joia", m, [(side * x, z) for x, z in wing_shape(size, size * 0.7, 8)], 0.003)
            bw.location = pos
            bw.rotation_euler = (0.2, 0, yaw + side * -0.5)
            rigid(c, bw, bone_n)
        bd = prim("sphere", "Joia", K.color_mat("skp_corpo", (0.2, 0.12, 0.1)), pos, (size * 0.15, size * 0.15, size * 0.8))
        rigid(c, bd, bone_n)

    butterfly(Vector((s2 * 0.55, h.y + s2 * 0.1, c.eye_z + s2 * 0.75)), 0.07, "head", K.color_mat("skp_bt1", (1.0, 0.6, 0.25), glow=0.9), 0.4)
    sh = K.bone_head(c.arm, "upperarm_r")
    butterfly(sh + Vector((-0.07, 0.0, 0.11)), 0.06, "upperarm_r", K.color_mat("skp_bt2", (0.5, 0.8, 1.0), glow=0.9), -0.3)


def sk_estelar_dr(c):
    """Druida Estelar (Mítica): vestido longo azul-noite salpicado de estrelas que brilham, constelações em linhas
    douradas, tiara de lua crescente, auréola de estrelas atrás da cabeça, ombreiras de lua e cabelo prateado."""
    import random
    night = K.color_mat("skx_noite", (0.08, 0.1, 0.28), rough=0.5)
    deep = K.color_mat("skx_fundo", (0.14, 0.12, 0.4), rough=0.5)
    star = K.color_mat("skx_estrela", (1.0, 0.95, 0.75), glow=1.6)
    star2 = K.color_mat("skx_estrela2", (0.7, 0.85, 1.0), glow=1.4)
    gold = K.color_mat("skx_ouro", (1.0, 0.85, 0.45), metal=0.8, rough=0.25)
    silver = K.color_mat("skx_prata", (0.85, 0.88, 0.96), metal=0.75, rough=0.25)
    piece(c, c.tights, "Traje", TORSO + UPPER + LOWER + ["pelvis"] + LEGS, deep, offset=0.005, zmin=c.ankle_z + 0.05)
    piece(c, c.tights, "Tunica", TORSO, night, offset=0.012, zmin=c.hip_z - 0.04)
    z0s, z1s = c.hip_z + 0.06, c.ankle_z + 0.03
    long_skirt(c, night, z0s, z1s, 0.34, 0.2)
    petal_layer(c, deep, c.knee_z - 0.18, z1s + 0.005, 0.355, 0.3, 14, 0.04, 0.0)
    piece(c, c.tights, "Bota", FEET, silver, offset=0.012, thresh=0.3, zmax=c.ankle_z + 0.05)
    D.gloves(c, deep, offset=0.004)
    K.card_asset(c, c.extra[0], "Cabelo", (0.88, 0.9, 0.98), 1.6)
    K.card_asset(c, c.extra[1], "Sobrancelha", (0.7, 0.72, 0.8), 1.0)
    py = K.bone_head(c.arm, "pelvis").y + 0.01
    rz = lambda z: (0.2 + (0.34 - 0.2) * (z0s - z) / (z0s - z1s)) + 0.004
    rnd = random.Random(11)
    pts = []
    for k in range(64):   # estrelas espalhadas na saia
        a = rnd.uniform(0, math.tau)
        z = rnd.uniform(z1s + 0.05, z0s - 0.04)
        r = rz(z)
        p_ = Vector((math.sin(a) * r, py - math.cos(a) * r * 0.82, z))
        sz = rnd.choice((0.014, 0.018, 0.024, 0.032))
        st = prim("sphere", "SaiaFolha", star if k % 3 else star2, p_, (sz, sz, sz), seg=6)
        rigid(c, st, "pelvis")
        if math.cos(a) > 0.4:
            pts.append(p_)
    # constelação (linhas finas douradas ligando estrelas da frente)
    pts.sort(key=lambda v: v.z)
    for i in range(0, min(len(pts) - 1, 8)):
        a_, b_ = pts[i], pts[i + 1]
        d = b_ - a_
        if d.length > 0.25:
            continue
        mid = (a_ + b_) / 2
        ln = prim("cyl", "SaiaFolha", gold, mid, (0.004, 0.004, d.length), seg=4)
        ln.rotation_mode = "QUATERNION"
        ln.rotation_quaternion = d.normalized().to_track_quat("Z", "Y")
        rigid(c, ln, "pelvis")
    # estrelas no corpete
    zb = c.hip_z + 0.07
    for k in range(10):
        z = rnd.uniform(zb + 0.04, K.bone_head(c.arm, "spine_03").z)
        cy, rx, ry = Mc.torso_size(c, z)
        a = rnd.uniform(-1.2, 1.2)
        st = prim("sphere", "Peitilho", star, Vector((math.sin(a) * (rx + 0.008), cy - math.cos(a) * (ry + 0.008), z)), (0.02,) * 3, seg=6)
        rigid(c, st, "spine_02")
    cy, rx, ry = Mc.torso_size(c, zb)
    band = prim("torus", "Cinto", gold, Vector((0, cy, zb)), (2 * rx + 0.01, 2 * ry + 0.01, 0.3), minor=0.045)
    rigid(c, band, "spine_01")
    ms = prim("sphere", "CintoFivela", star2, Vector((0, cy - ry - 0.015, zb)), (0.035, 0.014, 0.035))
    rigid(c, ms, "spine_01")

    def crescent(pos, size, bone_n, m, rot=(0, 0, 0)):
        """Lua crescente: anel de toro cortado (só um lado)."""
        o = prim("torus", "Joia", m, Vector((0, 0, 0)), (size, size * 0.4, size), rot=(math.pi / 2, 0, 0), minor=0.18)
        import bpy
        bpy.ops.object.select_all(action="DESELECT")
        o.select_set(True)
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
        keep = [v.index for v in o.data.vertices if v.co.x > -size * 0.15]
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="DESELECT")
        bpy.ops.object.mode_set(mode="OBJECT")
        for v in o.data.vertices:
            v.select = v.index not in keep
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.delete(type="VERT")
        bpy.ops.object.mode_set(mode="OBJECT")
        o.location = pos
        o.rotation_euler = rot
        rigid(c, o, bone_n)
        return o

    for side, bone_n in ((1, "upperarm_l"), (-1, "upperarm_r")):   # ombreiras de lua prateada
        sh = K.bone_head(c.arm, bone_n)
        pad = leaf("Ombreira", silver, sh + Vector((side * 0.045, 0.0, 0.035)), 0.18, 0.13, (0.0, side * 1.25, 0.0))
        rigid(c, pad, bone_n)
        crescent(sh + Vector((side * 0.075, -0.02, 0.07)), 0.05, bone_n, gold, (0, side * 0.6, 0.4 * side))
    # tiara de lua crescente e auréola de estrelas
    h, s2 = c.head, (c.head_top - c.head).length
    ring = prim("torus", "Coroa", silver, Vector((0, h.y + s2 * 0.02, c.eye_z + s2 * 0.42)), (s2 * 1.14, s2 * 1.24, 0.25), rot=(0.18, 0, 0), minor=0.05)
    rigid(c, ring, "head")
    for k in range(4):   # estrela de 4 pontas na testa
        ray = prim("cone", "Joia", star, Vector((0, h.y - s2 * 0.64, c.eye_z + s2 * 0.55)), (0.02, 0.012, 0.09 if k % 2 == 0 else 0.06), rot=(math.pi / 2, k * math.pi / 2, 0), seg=4)
        ray.rotation_euler = (math.pi / 2 + 0.0, 0, 0)
        ray.rotation_mode = "XYZ"
        ray.rotation_euler = (0, k * math.pi / 2, 0)
        rigid(c, ray, "head")
    core = prim("sphere", "Joia", star2, Vector((0, h.y - s2 * 0.66, c.eye_z + s2 * 0.55)), (0.028, 0.016, 0.028))
    rigid(c, core, "head")
    cen = Vector((0, h.y + s2 * 0.75, c.eye_z + s2 * 0.4))
    for k in range(12):
        a = k / 12 * math.tau
        sz = 0.03 if k % 3 == 0 else 0.02
        st = prim("sphere", "Joia", star if k % 2 else star2, cen + Vector((math.cos(a) * s2 * 0.95, 0, math.sin(a) * s2 * 0.95)), (sz,) * 3, seg=6)
        rigid(c, st, "head")
    D.cape(c, night, 1.25, 0.5, star2)


def sk_corrompida(c):
    """Rainha Corrompida (Mítica): vestido de rainha negro-arroxeado com sobressaia de pétalas e barra brilhando roxo,
    coroa alta de espinhos com cristais, cristais d'A Origem crescendo no ombro direito, uma última trepadeira dourada
    (o que restou de vida) cruzando o peito, cabelo branco e capa com rachaduras brilhantes."""
    import random
    rnd = random.Random(21)
    black = K.color_mat("skr_preto", (0.07, 0.05, 0.09), rough=0.45)
    plum = K.color_mat("skr_ameixa", (0.3, 0.12, 0.36), rough=0.45)
    glow = K.color_mat("skr_brilho", (0.8, 0.35, 1.0), glow=1.3)
    crys = K.color_mat("skr_cristal", (0.62, 0.28, 0.95), glow=0.8)
    gold = K.color_mat("skr_ouro", (1.0, 0.8, 0.35), metal=0.85, rough=0.25)
    leafg = K.color_mat("skr_folha", (0.85, 0.7, 0.3), metal=0.6, rough=0.3)
    piece(c, c.tights, "Traje", TORSO + UPPER + LOWER + ["pelvis"] + LEGS, black, offset=0.005, zmin=c.ankle_z + 0.05)
    piece(c, c.tights, "Tunica", TORSO, plum, offset=0.012, zmin=c.hip_z - 0.04)
    z0s, z1s = c.hip_z + 0.06, c.ankle_z + 0.03
    long_skirt(c, black, z0s, z1s, 0.36, 0.2)
    rz = lambda z: 0.2 + (0.36 - 0.2) * (z0s - z) / (z0s - z1s)
    zk = c.knee_z - 0.02
    petal_layer(c, plum, z0s + 0.01, zk, rz(zk) + 0.035, rz(z0s) + 0.035, 9, 0.13, 0.0)
    petal_layer(c, glow, z1s + 0.04, z1s - 0.005, rz(z1s) + 0.012, rz(z1s + 0.04) + 0.012, 18, 0.03, 0.2)
    piece(c, c.tights, "Bota", FEET, black, offset=0.012, thresh=0.3, zmax=c.ankle_z + 0.05)
    D.gloves(c, black, offset=0.004)
    K.card_asset(c, c.extra[0], "Cabelo", (0.93, 0.92, 0.97), 1.6)
    K.card_asset(c, c.extra[1], "Sobrancelha", (0.75, 0.72, 0.8), 1.0)
    # gola alta de espinhos atrás do pescoço (rainha)
    neck = K.bone_head(c.arm, "neck_01")
    for k in range(9):
        a = (k - 4) * 0.32
        sp = prim("cone", "Gorjal", black if k % 2 else plum, neck + Vector((math.sin(a) * 0.1, 0.05 + math.cos(a) * 0.04, 0.02)),
                  (0.035, 0.02, 0.16 - abs(k - 4) * 0.02), rot=(-0.35, a * 0.6, 0), seg=4)
        rigid(c, sp, "spine_03")
    # trepadeira dourada (o que restou de vida) cruzando o peito do ombro esquerdo até o quadril direito
    top_z, bot_z = K.bone_head(c.arm, "spine_03").z + 0.04, c.hip_z + 0.08
    for k in range(10):
        t = k / 9
        z = top_z + (bot_z - top_z) * t
        cy, rx, ry = Mc.torso_size(c, z)
        a = 0.9 - 1.8 * t
        pos = Vector((math.sin(a) * (rx + 0.012), cy - math.cos(a) * (ry + 0.014), z))
        lf = leaf("Peitilho", leafg, pos, 0.07, 0.035, (0.0, 0.0, (0.6 if k % 2 else -0.6) + a))
        rigid(c, lf, "spine_02")
        if k in (2, 6):
            fl = prim("sphere", "Peitilho", gold, pos + Vector((0, -0.01, 0)), (0.03, 0.015, 0.03))
            rigid(c, fl, "spine_02")
    zb = c.hip_z + 0.07
    cy, rx, ry = Mc.torso_size(c, zb)
    band = prim("torus", "Cinto", gold, Vector((0, cy, zb)), (2 * rx + 0.01, 2 * ry + 0.01, 0.3), minor=0.045)
    rigid(c, band, "spine_01")
    gm = prim("sphere", "CintoFivela", glow, Vector((0, cy - ry - 0.015, zb)), (0.035, 0.014, 0.04))
    rigid(c, gm, "spine_01")

    def cluster(pos, n, size, bone_n, spread=0.04):
        for k in range(n):
            d = Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(0.3, 1.0))).normalized()
            ln = size * rnd.uniform(0.6, 1.2)
            cr = prim("cone", "Espinho", crys, pos + d * spread * 0.5 + d * ln * 0.45, (ln * 0.32, ln * 0.32, ln), seg=5)
            cr.rotation_mode = "QUATERNION"
            cr.rotation_quaternion = d.to_track_quat("Z", "Y")
            rigid(c, cr, bone_n)

    # ombro esquerdo: ombreira de ouro simples; ombro direito: cristais d'A Origem crescendo
    shl = K.bone_head(c.arm, "upperarm_l")
    pl = leaf("Ombreira", gold, shl + Vector((0.045, 0.0, 0.035)), 0.17, 0.12, (0.0, 1.25, 0.0))
    rigid(c, pl, "upperarm_l")
    shr = K.bone_head(c.arm, "upperarm_r")
    pr = leaf("Ombreira", black, shr + Vector((-0.045, 0.0, 0.035)), 0.18, 0.13, (0.0, -1.25, 0.0))
    rigid(c, pr, "upperarm_r")
    cluster(shr + Vector((-0.06, 0.0, 0.07)), 9, 0.17, "upperarm_r", 0.06)
    # cristais crescendo na barra da saia (lado direito)
    py = K.bone_head(c.arm, "pelvis").y + 0.01
    for a in (-1.2, -1.9, -2.4):
        r = rz(z1s) + 0.02
        cluster(Vector((math.sin(a) * r, py - math.cos(a) * r * 0.82, z1s + 0.02)), 4, 0.14, "pelvis", 0.03)
    # coroa alta de espinhos negros com cristais nas pontas
    h, s2 = c.head, (c.head_top - c.head).length
    ring = prim("torus", "Coroa", black, Vector((0, h.y + s2 * 0.02, c.eye_z + s2 * 0.45)), (s2 * 1.16, s2 * 1.26, 0.35), rot=(0.18, 0, 0), minor=0.07)
    rigid(c, ring, "head")
    for k in range(9):
        ang = (k - 4) * 0.36
        tall = 0.17 - abs(k - 4) * 0.025
        base_p = Vector((math.sin(ang) * s2 * 0.6, h.y - math.cos(ang) * s2 * 0.6 + 0.01, c.eye_z + s2 * 0.5))
        sp = prim("cone", "Chifre", black, base_p + Vector((0, 0, tall / 2)), (0.032, 0.026, tall), rot=(0.18, -ang * 0.25, 0), seg=5)
        rigid(c, sp, "head")
        if k % 2 == 0:
            tip = prim("sphere", "Joia", glow, base_p + Vector((0, -0.005, tall + 0.005)), (0.016, 0.016, 0.024))
            rigid(c, tip, "head")
    gem = prim("sphere", "Joia", glow, Vector((0, h.y - s2 * 0.64, c.eye_z + s2 * 0.52)), (0.026, 0.012, 0.034))
    rigid(c, gem, "head")
    D.cape(c, plum, 1.25, 0.52, glow)


SKINS = {"sk_eloreth": ("druida", D, sk_eloreth), "sk_cinzas": ("druida", D, sk_cinzas), "sk_inverno": ("druida", D, sk_inverno),
         "sk_areias": ("druida", D, sk_areias), "sk_ninfa": ("druida", D, sk_ninfa),
         "sk_bruxa": ("druida", D, sk_bruxa), "sk_primavera": ("druida", D, sk_primavera),
         "sk_estelar_dr": ("druida", D, sk_estelar_dr), "sk_corrompida": ("druida", D, sk_corrompida)}
## Cabelo e sobrancelha do MakeHuman de cada skin (carregados com o corpo).
EXTRAS = {"sk_eloreth": [("hair/long01/long01.mhclo", "Hair"), ("eyebrows/eyebrow001/eyebrow001.mhclo", "Eyebrows")],
          "sk_cinzas": [("hair/braid01/braid01.mhclo", "Hair"), ("eyebrows/eyebrow006/eyebrow006.mhclo", "Eyebrows")],
          "sk_inverno": [("hair/bob02/bob02.mhclo", "Hair"), ("eyebrows/eyebrow003/eyebrow003.mhclo", "Eyebrows")],
          "sk_areias": [("hair/ponytail01/ponytail01.mhclo", "Hair"), ("eyebrows/eyebrow010/eyebrow010.mhclo", "Eyebrows")],
          "sk_ninfa": [("hair/long01/long01.mhclo", "Hair"), ("eyebrows/eyebrow002/eyebrow002.mhclo", "Eyebrows")],
          "sk_bruxa": [("hair/long01/long01.mhclo", "Hair"), ("eyebrows/eyebrow008/eyebrow008.mhclo", "Eyebrows")],
          "sk_primavera": [("hair/long01/long01.mhclo", "Hair"), ("eyebrows/eyebrow001/eyebrow001.mhclo", "Eyebrows")],
          "sk_estelar_dr": [("hair/long01/long01.mhclo", "Hair"), ("eyebrows/eyebrow002/eyebrow002.mhclo", "Eyebrows")],
          "sk_corrompida": [("hair/long01/long01.mhclo", "Hair"), ("eyebrows/eyebrow008/eyebrow008.mhclo", "Eyebrows")]}


def main():
    K.enable()
    ids = sys.argv[sys.argv.index("--") + 1].split(",") if "--" in sys.argv else list(SKINS)
    for sid in ids:
        cls, mod, fn = SKINS[sid]
        K.EXTRA = EXTRAS.get(sid, [])
        c = mod.base()
        c.extra = list(K.LAST_EXTRA)
        fn(c)
        mod.finalize(c, sid)


if __name__ == "__main__":
    main()
