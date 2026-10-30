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

K.MH_DATA = os.environ.get("MH_DATA", K.MH_DATA)
TORSO, UPPER, LOWER, LEGS, FEET = D.TORSO, D.UPPER, D.LOWER, D.LEGS, D.FEET
piece, rigid, prim, leaf, belt = D.piece, D.rigid, D.prim, D.leaf, D.belt


# =================================================================== Druida

def sk_eloreth(c):
    """Guardiã de Eloreth: vestes prateadas, folhas de cristal, coroa de galhos que brilha, cabelo platinado."""
    silver = K.color_mat("ske_prata", (0.86, 0.89, 0.96), metal=0.65, rough=0.28)
    cloth = K.color_mat("ske_veste", (0.9, 0.93, 0.97), rough=0.55)
    trim = K.color_mat("ske_barra", (0.55, 0.78, 0.7), rough=0.5)
    crystal = K.color_mat("ske_cristal", (0.55, 1.0, 0.82), glow=2.2)
    leafm = K.color_mat("ske_folha", (0.72, 0.95, 0.86), metal=0.45, rough=0.25)
    hair = K.color_mat("ske_cabelo", (0.9, 0.9, 0.95), rough=0.45)
    piece(c, c.tights, "Traje", TORSO + UPPER + LOWER + ["pelvis"] + LEGS, cloth, offset=0.005, zmin=c.ankle_z + 0.05)
    piece(c, c.tights, "Peitoral", ["spine_02", "spine_03"], silver, offset=0.02, thresh=0.5)
    piece(c, c.skirt, "Saia", ["pelvis", "thigh_l", "thigh_r"], cloth, offset=0.016, thresh=0.05, zmin=c.knee_z - 0.05)
    piece(c, c.tights, "Bota", ["calf_l", "calf_r"] + FEET, silver, offset=0.016, thresh=0.3, zmax=c.knee_z - 0.04)
    D.gloves(c, silver)
    D.hair_cap(c, hair, 0.008, back_long=0.75)
    # saia de folhas de cristal sobre a barra
    hip = K.bone_head(c.arm, "pelvis")
    for row, (z, ln, n) in enumerate(((-0.12, 0.36, 14), (-0.3, 0.42, 16))):   # duas fileiras de pétalas
        for k in range(n):
            a = (k + 0.5 * row) / n * math.tau
            m = (trim if row == 0 else leafm) if k % 3 else crystal
            lf = leaf("SaiaFolha", m, hip + Vector((math.sin(a) * (0.17 + row * 0.03), -math.cos(a) * (0.13 + row * 0.03), z)), ln, 0.13,
                      (math.cos(a) * 0.18 + math.pi, math.sin(a) * -0.18, a))
            rigid(c, lf, "pelvis")
    # ombreiras de folhas prateadas com um cristal
    for side, bone in ((1, "upperarm_l"), (-1, "upperarm_r")):
        sh = K.bone_head(c.arm, bone)
        for k in range(4):
            lf = leaf("Ombreira", silver if k % 2 else leafm, sh + Vector((side * (0.02 + k * 0.03), 0.0, 0.07 - k * 0.03)), 0.2, 0.1, (0.0, side * (1.1 + k * 0.15), 0.0))
            rigid(c, lf, bone)
        gem = prim("sphere", "GemaOmbro", crystal, sh + Vector((side * 0.06, -0.04, 0.05)), (0.022, 0.022, 0.03))
        rigid(c, gem, bone)
    # coroa: aro prateado com galhos e pontas de cristal
    h, s = c.head, (c.head_top - c.head).length
    ring = prim("torus", "Coroa", silver, Vector((0, h.y + s * 0.03, c.eye_z + s * 0.5)), (s * 1.18, s * 1.28, 0.45), rot=(0.12, 0, 0), minor=0.12)
    rigid(c, ring, "head")
    for k in range(7):
        a = (k - 3) * 0.42                       # leque na frente e nos lados
        base_p = Vector((math.sin(a) * s * 0.58, h.y - math.cos(a) * s * 0.58, c.eye_z + s * 0.52))
        tall = 0.16 if k == 3 else (0.12 if k in (2, 4) else 0.09)
        br = prim("cone", "Galho", silver, base_p + Vector((math.sin(a) * 0.02, -math.cos(a) * 0.02, tall / 2)),
                  (0.035, 0.03, tall), rot=(math.cos(a) * 0.35, math.sin(a) * -0.35, 0), seg=8, r2=0.25)
        rigid(c, br, "head")
        tip = prim("cone", "Joia", crystal, base_p + Vector((math.sin(a) * 0.045, -math.cos(a) * 0.045, tall + 0.02)), (0.026, 0.026, 0.06), rot=(math.cos(a) * 0.35, math.sin(a) * -0.35, 0), seg=6)
        rigid(c, tip, "head")
    gem = prim("sphere", "GemaPeito", crystal, K.bone_head(c.arm, "spine_03") + Vector((0, -0.14, 0.0)), (0.04, 0.02, 0.05))
    rigid(c, gem, "spine_03")
    belt(c, silver, c.hip_z + 0.06, buckle=crystal)
    D.cape(c, K.color_mat("ske_capa", (0.62, 0.84, 0.76), rough=0.5), 1.15, 0.5, silver)


SKINS = {"sk_eloreth": ("druida", D, sk_eloreth)}


def main():
    K.enable()
    ids = sys.argv[sys.argv.index("--") + 1].split(",") if "--" in sys.argv else list(SKINS)
    for sid in ids:
        cls, mod, fn = SKINS[sid]
        c = mod.base()
        fn(c)
        mod.finalize(c, sid)


if __name__ == "__main__":
    main()
