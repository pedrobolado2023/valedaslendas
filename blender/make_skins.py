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


SKINS = {"sk_eloreth": ("druida", D, sk_eloreth), "sk_cinzas": ("druida", D, sk_cinzas)}
## Cabelo e sobrancelha do MakeHuman de cada skin (carregados com o corpo).
EXTRAS = {"sk_eloreth": [("hair/long01/long01.mhclo", "Hair"), ("eyebrows/eyebrow001/eyebrow001.mhclo", "Eyebrows")],
          "sk_cinzas": [("hair/braid01/braid01.mhclo", "Hair"), ("eyebrows/eyebrow006/eyebrow006.mhclo", "Eyebrows")]}


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
