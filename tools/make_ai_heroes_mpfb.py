r"""
Gera os 4 heróis 3D de alta definição (Lanceiro, Guerreiro, Arqueira e Mago) usando o corpo, rosto esculpido,
olhos 3D e esqueleto humanizado de 53 ossos do MPFB2 (MakeHuman) + armaduras 3D esculpidas em múltiplas camadas
com materiais PBR metálicos, runas emissivas, capas com física de ossos e armas/escudo/arco 3D rígidos.

Rode:
  $env:MH_DATA="C:\Users\pedro\vale-tools\makehuman\makehuman\data"
  $env:PYTHONPATH="C:\Users\pedro\vale-tools\pylibs"
  & "C:\Users\pedro\vale-tools\blender-5.2.3-windows-x64\blender.exe" -b -P tools/make_ai_heroes_mpfb.py
"""
import math
import os
import sys

import bpy
from mathutils import Vector

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
import make_sete as SE  # noqa: E402

OUT = os.path.join(ROOT, "models")
K.MH_DATA = os.environ.get("MH_DATA", r"C:\Users\pedro\vale-tools\makehuman\makehuman\data")

TORSO, UPPER, LOWER, LEGS, FEET = D.TORSO, D.UPPER, D.LOWER, D.LEGS, D.FEET
X, Y, Z = D.X, D.Y, D.Z
piece, rigid, prim, leaf, belt = D.piece, D.rigid, D.prim, D.leaf, D.belt


# ==============================================================================
# 1. Utilitários de Armadura 3D Esculpida (Estilo Legend Online / Os Sete Reinos)
# ==============================================================================

def split_tassets(c, mat, trim_mat=None, zmin_off=-0.04, zmax_off=0.08):
    """Cria placas de quadril/saia de batalha 3D divididas por coxa (sem nunca esticar entre as pernas)."""
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
            offset=0.016,
            thick=0.010,
            thresh=0.05,
            zmin=z0,
            zmax=z1,
            keep_fn=pred,
        )
        if o is not None:
            panels.append(o)
    if trim_mat is not None:
        for side, bone in ((1, "thigh_l"), (-1, "thigh_r")):
            hd, tl = K.bone_head(c.arm, bone), K.bone_tail(c.arm, bone)
            for k in range(3):
                p = hd.lerp(tl, 0.22 + k * 0.20) + Vector((side * 0.095, -0.03, 0.0))
                pl = prim("box", f"PlacaCoxa{k}", trim_mat, p, (0.025, 0.09, 0.055), rot=(0, side * 0.18, 0))
                rigid(c, pl, bone)
    return panels


def knee_and_shin_guards(c, plate_mat, gem_mat=None):
    """Joelheiras e caneleiras 3D esculpidas presas às pernas (calf_l, calf_r)."""
    for side, bone in ((1, "calf_l"), (-1, "calf_r")):
        kn = K.bone_head(c.arm, bone)
        guard = prim(
            "cone",
            "Joelheira",
            plate_mat,
            kn + Vector((side * 0.005, -0.068, 0.01)),
            (0.085, 0.055, 0.11),
            rot=(0.15, 0, 0),
            seg=6,
            r2=0.02,
        )
        rigid(c, guard, bone)
        if gem_mat is not None:
            gm = prim("sphere", "GemaJoelho", gem_mat, kn + Vector((side * 0.005, -0.088, 0.01)), (0.022, 0.014, 0.028))
            rigid(c, gm, bone)


def chest_crest(c, metal_mat, glow_mat):
    """Brasão 3D em relevo no centro do peitoral (spine_03) com núcleo rúnico brilhante."""
    sp3 = K.bone_head(c.arm, "spine_03")
    plate = prim("cone", "BrasaoPeito", metal_mat, sp3 + Vector((0, -0.145, 0.02)), (0.14, 0.035, 0.16), rot=(math.pi, 0, 0), seg=6, r2=0.03)
    rigid(c, plate, "spine_03")
    core = prim("sphere", "RunaPeito", glow_mat, sp3 + Vector((0, -0.158, 0.03)), (0.038, 0.018, 0.052))
    rigid(c, core, "spine_03")
    for side in (-1, 1):
        wing = prim(
            "box",
            "AsaPeito",
            metal_mat,
            sp3 + Vector((side * 0.075, -0.138, 0.045)),
            (0.09, 0.022, 0.028),
            rot=(0, side * -0.42, side * 0.22),
        )
        rigid(c, wing, "spine_03")


def valkyrie_wings_back(c, feather_mat, glow_mat, span=0.52):
    """Par de Asas de Batalha 3D (estilo Legend Online) presas às costas (spine_03)."""
    sp3 = K.bone_head(c.arm, "spine_03")
    for side in (-1, 1):
        base = sp3 + Vector((side * 0.06, 0.11, 0.08))
        # Arco superior da asa
        strut = SK.horn(
            "AsaArco",
            feather_mat,
            base,
            base + Vector((side * span * 0.55, 0.10, 0.26)),
            base + Vector((side * span, 0.16, 0.12)),
            0.026,
        )
        rigid(c, strut, "spine_03")
        # Penas laminadas em leque
        for k in range(6):
            t = k / 5.0
            p = base + Vector((side * (0.10 + t * span * 0.85), 0.11 + t * 0.05, 0.18 - t * 0.14))
            ln = 0.28 - t * 0.08
            mat_use = glow_mat if k % 2 == 1 else feather_mat
            fth = prim(
                "cone",
                f"PenaAsa{k}",
                mat_use,
                p,
                (0.024, 0.048, ln),
                rot=(math.pi + 0.18, side * (-0.35 - t * 0.25), 0),
                seg=4,
            )
            rigid(c, fth, "spine_03")


# ==============================================================================
# 2. LANCEIRO (Paladino / Lanceiro Dragoon de Vyndara — 100% Melee de Lança)
# ==============================================================================

def build_lanceiro():
    """Lanceiro de Vyndara: rosto esculpido 3D, olhos 3D, armadura de placas azul-cobalto e prata polida,
    elmo aberto de Valquíria com 8 asas metálicas, ombreiras em camadas, capa real e Lança Rúnica."""
    c = SE.body(False, SE.FAIR, "kaeldryn")
    cobalt = K.color_mat("lanceiro_cobalto", (0.12, 0.24, 0.46), metal=0.55, rough=0.35)
    navy_cloth = K.color_mat("lanceiro_gibao", (0.08, 0.14, 0.26), rough=0.65)
    silver = K.color_mat("lanceiro_prata", (0.78, 0.84, 0.94), metal=0.90, rough=0.22)
    steel_dark = K.color_mat("lanceiro_aco_esc", (0.24, 0.30, 0.40), metal=0.80, rough=0.32)
    rune = K.color_mat("lanceiro_runa", (0.35, 0.88, 1.0), glow=5.0)
    hair_mat = K.color_mat("lanceiro_cabelo", (0.82, 0.85, 0.92), rough=0.5)
    leather = K.color_mat("lanceiro_couro", (0.20, 0.15, 0.12), rough=0.7)

    # Cabelo prateado e sobrancelhas 3D (rosto e olhos 3D totalmente visíveis!)
    SE.short_hair(c, hair_mat, seed=2, length=0.09, fringe=0.15)
    SE.brows(c, hair_mat, 1.15, 0.10)

    # Traje base, Peitoral de Placas Prateadas, Grevas e Manoplas
    piece(c, c.tights, "Calca", ["pelvis"] + LEGS, navy_cloth, offset=0.005, zmin=c.ankle_z + 0.06)
    piece(c, c.tights, "Gibao", TORSO + UPPER + LOWER, cobalt, offset=0.010, zmin=c.hip_z - 0.04)
    piece(c, c.tights, "Peitoral", ["spine_01", "spine_02", "spine_03"], silver, offset=0.022, thick=0.012, thresh=0.45)
    piece(c, c.tights, "Bota", ["calf_l", "calf_r"] + FEET, silver, offset=0.016, thresh=0.3, zmax=c.knee_z + 0.03)
    piece(c, c.tights, "Bracadeira", LOWER, silver, offset=0.016, thresh=0.45, zmax=c.elbow_z - 0.02)
    D.gloves(c, steel_dark, 0.011)

    # Saiote de placas dividido por perna + placas laterais de prata
    split_tassets(c, cobalt, trim_mat=silver)
    knee_and_shin_guards(c, silver, rune)
    chest_crest(c, silver, rune)
    A.bandolier(c, leather, silver)
    belt(c, leather, c.hip_z + 0.06, buckle=rune)

    # Ombreiras de Cavaleiro Dragoon com borda de prata e gemas rúnicas
    A.pauldrons(c, cobalt, silver, spikes=silver, size=0.16, gem=rune)

    # Elmo aberto de Valquíria (deixa olhos, nariz e queixo 3D livres!) + Asas nas têmporas
    h, s = c.head, (c.head_top - c.head).length
    neck_z = K.bone_head(c.arm, "neck_01").z
    D.head_shell(
        c,
        "Elmo",
        silver,
        0.024,
        lambda p: p.z > neck_z + 0.02 and not (p.y < h.y - s * 0.12 and p.z < c.eye_z + s * 0.16 and abs(p.x) < s * 0.44),
        0.012,
        2,
    )
    gem_head = prim("sphere", "JoiaTesta", rune, Vector((0, h.y - s * 0.65, c.eye_z + s * 0.36)), (0.026, 0.016, 0.040))
    rigid(c, gem_head, "head")
    for side in (-1, 1):
        # Protetor de bochecha estilizado + 4 penas metálicas aladas
        cheek = prim("box", "Faceira", silver, Vector((side * s * 0.48, h.y - s * 0.30, c.eye_z - s * 0.12)), (0.018, 0.055, 0.09), rot=(0.15, 0, side * 0.12))
        rigid(c, cheek, "head")
        for k in range(4):
            wing = prim(
                "cone",
                f"AsaElmo{k}",
                silver if k < 3 else rune,
                c.head + Vector((side * (s * 0.56 + k * 0.015), s * (0.02 + k * 0.09), s * (0.34 + k * 0.14))),
                (0.024, 0.058 - k * 0.006, 0.26 - k * 0.025),
                rot=(-0.62 - k * 0.12, side * 0.40, side * 0.18),
                seg=4,
            )
            rigid(c, wing, "head")

    D.cape(c, cobalt, 1.18, 0.52, silver)

    for o in [c.body] + c.parts:
        if o.type == "MESH":
            K.apply_modifiers(o)
    _lanceiro_anims(c)
    Na.weapon_slot(c)
    _export_single_hero(c, "hero_lanceiro_ia")
    build_lanceiro_weapon()


def _lanceiro_anims(c):
    """Animações 100% corpo-a-corpo (Melee) de Lanceiro:
    - Em guarda a lança aponta para a frente (-Y no MPFB / +Z no jogo).
    - No ataque ('attack'), o Lanceiro avança o tronco e estoca/varre a lança diretamente para a frente!"""
    sin, cos, tau = math.sin, math.cos, math.tau
    ease = K.ease
    base_pose = Na.build_base_pose(c)
    # Ajusta o braço direito para apontar a lança diretamente à frente do corpo (sem entortar para a lateral)
    base_pose["upperarm_r"] = [(Y, -0.52), (X, -0.58), (Z, -0.08)]
    base_pose["lowerarm_r"] = [(X, -0.52), (Y, -0.10)]
    base_pose["hand_r"] = [(X, 0.12), (Z, 0.0)]
    base_pose["upperarm_l"] = [(Y, 0.58), (X, -0.35), (Z, 0.18)]
    base_pose["lowerarm_l"] = [(X, -0.65)]

    def legs(p, swing, knee, lift):
        out = {}
        for side, ph in (("l", 0.0), ("r", math.pi)):
            s, c_ = sin(p + ph), cos(p + ph)
            thigh = -swing * s
            calf = 0.08 + knee * max(0.0, c_) ** 2
            foot = -(thigh + calf) * 0.85 + lift * max(0.0, -s) * max(0.0, -c_)
            undo = base_pose[f"thigh_{side}"]
            out[f"thigh_{side}"] = [(ax, -a) for ax, a in undo] + [(X, thigh)]
            out[f"calf_{side}"] = [(X, calf - base_pose[f"calf_{side}"][0][1])]
            out[f"foot_{side}"] = [(X, foot - base_pose[f"foot_{side}"][0][1])]
            out[f"ball_{side}"] = [(X, -0.35 * max(0.0, -s) * max(0.0, -c_))]
        return out

    def idle(t):
        b = sin(t * tau)
        b2 = sin(t * tau * 2 + 0.6)
        return {
            "spine_02": [(X, -0.015 * b)],
            "spine_03": [(X, -0.02 * b)],
            "clavicle_l": [(Y, 0.015 * b)],
            "clavicle_r": [(Y, -0.015 * b)],
            "upperarm_l": [(Y, 0.02 * b)],
            "lowerarm_l": [(X, -0.04 * b)],
            "upperarm_r": [(X, 0.03 * b2)],
            "lowerarm_r": [(X, -0.04 * b)],
            "head": [(Z, 0.04 * sin(t * tau + 1.2)), (X, 0.015 * b)],
            "_loc": Vector((0.006 * b, 0, -0.006 * (1 - cos(t * tau)))),
        }

    def walk(t):
        p = t * tau
        s = sin(p)
        o = legs(p, 0.44, 1.02, 0.44)
        o.update({
            "pelvis": [(Z, -0.06 * s), (Y, 0.035 * cos(2 * p))],
            "spine_01": [(Z, 0.04 * s), (X, 0.04)],
            "spine_03": [(Z, 0.05 * s), (X, 0.03)],
            "upperarm_l": [(X, 0.28 * s)],
            "upperarm_r": [(X, -0.14 * s)],
            "_loc": Vector((0.012 * s, 0, -0.03 + 0.022 * cos(2 * p))),
        })
        return o

    def run(t):
        p = t * tau
        s = sin(p)
        o = legs(p, 0.72, 1.65, 0.65)
        o.update({
            "pelvis": [(Z, -0.08 * s), (X, 0.08)],
            "spine_01": [(Z, 0.06 * s), (X, 0.12)],
            "spine_03": [(Z, 0.08 * s), (X, 0.08)],
            "upperarm_l": [(X, 0.55 * s)],
            "upperarm_r": [(X, -0.22 * s)],
            "_loc": Vector((0.014 * s, 0, -0.06 + 0.05 * abs(cos(p)))),
        })
        return o

    def spear_melee_attack(t):
        # Estocada física direta para a frente: prepara puxando o braço para trás (0..0.28) e crava a lança à frente (0.28..0.55)
        back = ease(t / 0.28) * (1.0 - ease((t - 0.28) / 0.10))
        hit = ease((t - 0.26) / 0.16) * (1.0 - ease((t - 0.56) / 0.44))
        return {
            "pelvis": [(X, -0.05 * back + 0.14 * hit), (Z, -0.06 * back + 0.04 * hit)],
            "spine_01": [(X, -0.06 * back + 0.18 * hit), (Z, -0.08 * back + 0.05 * hit)],
            "spine_03": [(X, -0.06 * back + 0.16 * hit), (Z, -0.06 * back + 0.04 * hit)],
            "head": [(X, 0.06 * back - 0.14 * hit)],
            "clavicle_r": [(X, 0.08 * back - 0.18 * hit)],
            # Braço direito estende reto para a frente (-X na pose local levanta o braço à frente e o antebraço estica!)
            "upperarm_r": [(X, 0.48 * back - 0.88 * hit), (Y, 0.12 * back - 0.10 * hit), (Z, -0.05 * hit)],
            "lowerarm_r": [(X, -0.38 * back + 0.48 * hit)],
            "hand_r": [(X, -0.15 * back + 0.32 * hit)],
            "upperarm_l": [(X, -0.25 * back + 0.35 * hit), (Y, -0.15 * hit)],
            "lowerarm_l": [(X, -0.35 * back)],
            "thigh_l": [(X, -0.45 * hit)],
            "calf_l": [(X, 0.42 * hit)],
            "thigh_r": [(X, 0.35 * hit)],
            "calf_r": [(X, 0.15 * hit)],
            "_loc": Vector((0, 0.05 * back - 0.18 * hit, -0.06 * hit)),
        }

    K.write_actions(
        c.arm,
        {
            "idle": (56, idle, True),
            "walk": (32, walk, True),
            "run": (20, run, True),
            "attack": (18, spear_melee_attack, False),
            **SA.nautico(),
        },
        base_pose,
    )


def build_lanceiro_weapon():
    """Lança Rúnica de Vyndara presa no nó Weapon (aponta para -Z)."""
    K.clear_scene()
    root = bpy.data.objects.new("WeaponRoot", None)
    bpy.context.collection.objects.link(root)
    dark_steel = K.color_mat("lanca_haste", (0.16, 0.22, 0.34), metal=0.82, rough=0.32)
    silver = K.color_mat("lanca_ponta", (0.84, 0.89, 0.98), metal=0.95, rough=0.18)
    gold = K.color_mat("lanca_ouro", (0.95, 0.76, 0.32), metal=0.90, rough=0.25)
    glow = K.color_mat("lanca_runa", (0.35, 0.88, 1.0), glow=5.5)

    shaft = prim("cyl", "Haste", dark_steel, Vector((0, 0, -0.95)), (0.075, 0.075, 3.35), seg=10)
    shaft.parent = root
    guard = prim("cone", "Guarda", gold, Vector((0, 0, -0.45)), (0.24, 0.24, 0.30), rot=(math.pi, 0, 0), seg=10, r2=0.05)
    guard.parent = root
    for k in range(5):
        rn = prim("torus", f"Runa{k}", glow, Vector((0, 0, -0.7 - k * 0.32)), (0.10, 0.10, 0.35), minor=0.035)
        rn.parent = root
    blade = prim("cone", "Ponta", silver, Vector((0, 0, -2.98)), (0.20, 0.065, 0.85), rot=(math.pi, 0, 0), seg=6)
    blade.parent = root
    core = prim("box", "NucleoRuna", glow, Vector((0, 0, -2.52)), (0.05, 0.05, 0.36))
    core.parent = root
    for s in (-1, 1):
        wing = prim("cone", "Aleta", silver, Vector((s * 0.14, 0, -2.48)), (0.09, 0.04, 0.36), rot=(0, s * 2.35, 0), seg=4)
        wing.parent = root
    butt = prim("cone", "Calcanhar", gold, Vector((0, 0, 0.78)), (0.11, 0.11, 0.26), seg=8)
    butt.parent = root

    _export_weapon(root, "weapon_lanceiro_ia")


# ==============================================================================
# 3. GUERREIRO (Cavaleiro do Dragão — Espada Rúnica + Escudo do Dragão 3D)
# ==============================================================================

def build_guerreiro():
    """Guerreiro Cavaleiro do Dragão: rosto esculpido 3D, armadura de placas negra-obsidiana e ouro velho,
    elmo aberto de Dragão com 4 chifres curvos 3D, Escudo do Dragão 3D com brasão em alto-relevo na mão esquerda
    e Espada Rúnica na mão direita."""
    c = SE.body(False, SE.TAN, "darius")
    obsidian = K.color_mat("guerreiro_obsidiana", (0.11, 0.11, 0.14), metal=0.82, rough=0.30)
    charcoal = K.color_mat("guerreiro_traje", (0.07, 0.07, 0.09), rough=0.65)
    gold = K.color_mat("guerreiro_ouro", (0.90, 0.68, 0.24), metal=0.90, rough=0.25)
    crimson = K.color_mat("guerreiro_capa", (0.48, 0.06, 0.08), rough=0.72)
    horn_mat = K.color_mat("guerreiro_chifre", (0.18, 0.16, 0.15), metal=0.55, rough=0.42)
    ice_glow = K.color_mat("guerreiro_gelo", (0.38, 0.86, 1.0), glow=5.0)
    hair_mat = K.color_mat("guerreiro_cabelo", (0.06, 0.05, 0.05), rough=0.6)

    # Cabelo curto, sobrancelhas fechadas e barba curta 3D
    SE.short_hair(c, hair_mat, seed=3, length=0.09, fringe=0.2)
    SE.brows(c, hair_mat, 1.3, 0.12)

    # Traje, Peitoral de Placas de Dragão com bordas douradas, Grevas e Manoplas
    piece(c, c.tights, "Calca", ["pelvis"] + LEGS, charcoal, offset=0.005, zmin=c.ankle_z + 0.06)
    piece(c, c.tights, "Gibao", TORSO + UPPER + LOWER, charcoal, offset=0.010, zmin=c.hip_z - 0.04)
    piece(c, c.tights, "Peitoral", ["spine_01", "spine_02", "spine_03"], obsidian, offset=0.022, thick=0.013, thresh=0.45)
    piece(c, c.tights, "Bota", ["calf_l", "calf_r"] + FEET, obsidian, offset=0.017, thresh=0.3, zmax=c.knee_z + 0.03)
    piece(c, c.tights, "Bracadeira", LOWER, obsidian, offset=0.016, thresh=0.45, zmax=c.elbow_z - 0.02)
    D.gloves(c, obsidian, 0.011)

    split_tassets(c, obsidian, trim_mat=gold)
    knee_and_shin_guards(c, gold, ice_glow)
    chest_crest(c, gold, ice_glow)
    A.bandolier(c, gold, obsidian)
    belt(c, gold, c.hip_z + 0.06, buckle=ice_glow)

    # Ombreiras de Dragão com espinhos dourados e gema de gelo
    A.pauldrons(c, obsidian, gold, spikes=gold, size=0.17, gem=ice_glow)

    # Elmo aberto de Dragão + 4 Chifres Curvos 3D (SK.horn)
    h, s = c.head, (c.head_top - c.head).length
    neck_z = K.bone_head(c.arm, "neck_01").z
    D.head_shell(
        c,
        "Elmo",
        obsidian,
        0.025,
        lambda p: p.z > neck_z + 0.02 and not (p.y < h.y - s * 0.12 and p.z < c.eye_z + s * 0.14 and abs(p.x) < s * 0.42),
        0.013,
        2,
    )
    crown_trim = prim("torus", "CoroaElmo", gold, Vector((0, h.y, c.eye_z + s * 0.28)), (s * 1.12, s * 1.18, 0.18), rot=(0.12, 0, 0), minor=0.05)
    rigid(c, crown_trim, "head")
    for side in (-1, 1):
        b0 = c.head_top + Vector((side * s * 0.38, -s * 0.05, -s * 0.12))
        p1 = b0 + Vector((side * s * 0.55, s * 0.08, s * 0.48))
        p2 = b0 + Vector((side * s * 0.25, s * 0.12, s * 0.95))
        h1 = SK.horn("ChifreDragao", horn_mat, b0, p1, p2, 0.036)
        rigid(c, h1, "head")
        b2 = c.head_top + Vector((side * s * 0.48, s * 0.02, -s * 0.28))
        h2 = SK.horn("ChifreMenor", gold, b2, b2 + Vector((side * s * 0.38, s * 0.08, s * 0.18)), b2 + Vector((side * s * 0.45, s * 0.14, s * 0.45)), 0.022)
        rigid(c, h2, "head")

    D.cape(c, crimson, 1.18, 0.50, gold)

    # ESCUDO DO DRAGÃO 3D esculpido em alto-relevo preso ao antebraço esquerdo (lowerarm_l)
    la = K.bone_head(c.arm, "lowerarm_l")
    ha = K.bone_head(c.arm, "hand_l")
    sh_center = la.lerp(ha, 0.65) + Vector((0.09, -0.10, -0.02))
    shield = _create_kite_shield("Escudo", obsidian, gold, ice_glow, sh_center, width=0.38, height=0.56, thick=0.024)
    rigid(c, shield, "lowerarm_l")

    for o in [c.body] + c.parts:
        if o.type == "MESH":
            K.apply_modifiers(o)
    Na.anims(c)
    Na.weapon_slot(c)
    _export_single_hero(c, "hero_guerreiro_ia")
    build_guerreiro_weapon()


def _create_kite_shield(name, body_mat, trim_mat, gem_mat, center, width=0.38, height=0.56, thick=0.024):
    """Escudo pipa/aquecedor 3D com borda metálica dourada e brasão de dragão 3D em relevo."""
    nx, nz = 12, 16
    verts, faces = [], []
    for iz in range(nz + 1):
        tz = iz / nz
        w_factor = (tz ** 0.55) * (1.0 - 0.08 * ((tz - 0.75) ** 2))
        half_w = 0.5 * width * max(w_factor, 0.04)
        z = (tz - 0.5) * height
        for ix in range(nx + 1):
            tx = (ix / nx) * 2.0 - 1.0
            x = tx * half_w
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
    o.data.materials.append(body_mat)
    bpy.context.view_layer.objects.active = o
    md = o.modifiers.new("Esp", "SOLIDIFY")
    md.thickness = thick
    K.apply_modifiers(o, keep=())

    # Brasão 3D em relevo na face frontal do escudo (ouro + núcleo de safira)
    boss = prim("cone", "EscudoBrasao", trim_mat, center + Vector((0, -0.058, 0.03)), (0.16, 0.035, 0.24), rot=(math.pi, 0, 0), seg=6, r2=0.03)
    gem = prim("sphere", "EscudoGema", gem_mat, center + Vector((0, -0.072, 0.04)), (0.048, 0.024, 0.065))
    rim_top = prim("box", "EscudoTopo", trim_mat, center + Vector((0, -0.042, height * 0.46)), (width * 0.86, 0.032, 0.032))
    parts = [o, boss, gem, rim_top]
    for side in (-1, 1):
        w = prim("cone", f"EscudoAsa{side}", trim_mat, center + Vector((side * 0.09, -0.052, 0.06)), (0.04, 0.025, 0.18), rot=(0, side * -0.55, 0), seg=4)
        parts.append(w)
    return SE._join(parts, name)


def build_guerreiro_weapon():
    """Espada Longa Rúnica do Dragão presa no nó Weapon (aponta para -Z)."""
    K.clear_scene()
    root = bpy.data.objects.new("WeaponRoot", None)
    bpy.context.collection.objects.link(root)
    silver = K.color_mat("espada_lamina", (0.85, 0.90, 0.98), metal=0.95, rough=0.18)
    grip_mat = K.color_mat("espada_cabo", (0.22, 0.14, 0.10), rough=0.72)
    gold_mat = K.color_mat("espada_guarda", (0.92, 0.70, 0.24), metal=0.90, rough=0.24)
    gem_mat = K.color_mat("espada_safira", (0.25, 0.78, 1.0), glow=6.0)
    aura_mat = K.color_mat("espada_aura", (0.45, 0.88, 1.0), glow=4.5)

    grip = prim("cyl", "Cabo", grip_mat, Vector((0, 0, 0.18)), (0.07, 0.07, 0.42), seg=10)
    grip.parent = root
    pommel = prim("sphere", "Pomo", gold_mat, Vector((0, 0, 0.42)), (0.13, 0.09, 0.13))
    pommel.parent = root
    guard = prim("box", "Guarda", gold_mat, Vector((0, 0, -0.05)), (0.58, 0.09, 0.09))
    guard.parent = root
    for s in (-1, 1):
        wing = prim("cone", "GuardaAsa", gold_mat, Vector((s * 0.34, 0, -0.10)), (0.09, 0.06, 0.24), rot=(0, s * 1.9, 0), seg=4)
        wing.parent = root
    gem = prim("sphere", "GemaGuarda", gem_mat, Vector((0, 0, -0.05)), (0.12, 0.12, 0.14))
    gem.parent = root
    blade = prim("box", "Lamina", silver, Vector((0, 0, -1.15)), (0.18, 0.038, 2.1))
    blade.parent = root
    tip = prim("cone", "Ponta", silver, Vector((0, 0, -2.35)), (0.18, 0.038, 0.32), rot=(math.pi, 0, 0), seg=4)
    tip.parent = root
    glow_edge = prim("box", "FioRunico", aura_mat, Vector((0, 0, -1.12)), (0.055, 0.048, 1.95))
    glow_edge.parent = root

    _export_weapon(root, "weapon_guerreiro_ia")


# ==============================================================================
# 4. ARQUEIRA (Caçadora Élfica Real — Arco Recurvo Dourado + Aljava 3D)
# ==============================================================================

def build_arqueira():
    """Arqueira Caçadora Élfica: rosto feminino 3D esculpido (emberlyn), olhos 3D grandes, trança longa,
    armadura élfica verde-esmeralda, couro nobre e ouro, capuz aberto com tiara, aljava 3D com flechas nas costas
    e Arco Recurvo Élfico na mão esquerda."""
    c = SE.body(True, SE.FAIR, "emberlyn")
    emerald = K.color_mat("arqueira_esmeralda", (0.10, 0.32, 0.20), rough=0.58)
    leather = K.color_mat("arqueira_couro", (0.28, 0.18, 0.11), rough=0.65)
    dark_leather = K.color_mat("arqueira_calca", (0.14, 0.11, 0.09), rough=0.70)
    gold = K.color_mat("arqueira_ouro", (0.92, 0.72, 0.28), metal=0.88, rough=0.25)
    wood = K.color_mat("arqueira_madeira", (0.42, 0.26, 0.14), rough=0.60)
    feather = K.color_mat("arqueira_pena", (0.92, 0.88, 0.76), rough=0.75)
    steel = K.color_mat("arqueira_aco", (0.80, 0.84, 0.90), metal=0.88, rough=0.25)
    jade_glow = K.color_mat("arqueira_jade", (0.35, 0.95, 0.62), glow=4.5)
    hair_mat = K.color_mat("arqueira_cabelo", (0.36, 0.20, 0.10), rough=0.55)

    # Cabelo com trança longa, sobrancelhas, brincos e tiara dourada (rosto 3D limpo e expressivo!)
    SE.braid(c, hair_mat, 0.78)
    SE.brows(c, hair_mat, 0.85, 0.0)
    SE.earrings(c, gold)
    SE.tiara(c, gold, jade_glow)

    # Calças, Gibão esmeralda, Corpete de couro e ouro, Botas de cano alto e Braçadeiras
    piece(c, c.tights, "Calca", ["pelvis"] + LEGS, dark_leather, offset=0.005, zmin=c.ankle_z + 0.06)
    piece(c, c.tights, "Gibao", TORSO + UPPER + LOWER, emerald, offset=0.009, zmin=c.hip_z - 0.04)
    piece(c, c.tights, "Peitoral", ["spine_01", "spine_02", "spine_03"], leather, offset=0.018, thick=0.010, thresh=0.45)
    piece(c, c.tights, "Bota", ["calf_l", "calf_r"] + FEET, leather, offset=0.016, thresh=0.3, zmax=c.knee_z + 0.03)
    piece(c, c.tights, "Bracadeira", LOWER, gold, offset=0.015, thresh=0.45, zmax=c.elbow_z - 0.02)
    D.gloves(c, leather, 0.009)

    split_tassets(c, emerald, trim_mat=gold)
    knee_and_shin_guards(c, gold, jade_glow)
    chest_crest(c, gold, jade_glow)
    A.bandolier(c, gold, leather)
    belt(c, gold, c.hip_z + 0.06, buckle=jade_glow)

    # Ombreiras Élficas em formato de folha dourada
    A.pauldrons(c, emerald, gold, size=0.13, gem=jade_glow)

    # Capuz Élfico aberto (emoldura o rosto sem cobrir os olhos!)
    D.hood(c, emerald, point=True)

    # ALJAVA 3D com flechas nas costas (spine_03)
    sp3 = K.bone_head(c.arm, "spine_03")
    quiver = prim("cyl", "Mochila", leather, sp3 + Vector((-0.08, 0.13, 0.08)), (0.09, 0.09, 0.42), rot=(0.15, 0.38, 0), seg=10)
    rigid(c, quiver, "spine_03")
    q_rim = prim("torus", "BordaAljava", gold, sp3 + Vector((-0.14, 0.15, 0.25)), (0.10, 0.10, 0.18), rot=(0.15, 0.38, 0), minor=0.04)
    rigid(c, q_rim, "spine_03")
    for k in range(5):
        off = Vector((-0.08 - 0.06 + (k - 2) * 0.018, 0.14 + (k % 2) * 0.012, 0.28))
        arr = prim("cyl", f"FlechaAljava{k}", wood, sp3 + off, (0.012, 0.012, 0.24), rot=(0.15, 0.38, 0), seg=6)
        rigid(c, arr, "spine_03")
        fth = prim("cone", f"PenaAljava{k}", feather, sp3 + off + Vector((-0.04, 0.02, 0.10)), (0.028, 0.012, 0.07), rot=(0.15, 0.38, 0), seg=4)
        rigid(c, fth, "spine_03")

    # ARCO RECURVO ÉLFICO 3D preso na mão esquerda (hand_l)
    hl = K.bone_head(c.arm, "hand_l")
    bow = _create_recurve_bow("Arco", wood, gold, jade_glow, hl + Vector((0.02, -0.05, 0.0)))
    rigid(c, bow, "hand_l")

    for o in [c.body] + c.parts:
        if o.type == "MESH":
            K.apply_modifiers(o)
    _arqueira_anims(c)
    Na.weapon_slot(c)
    _export_single_hero(c, "hero_arqueira_ia")
    build_arqueira_weapon()


def _arqueira_anims(c):
    """Postura e animações de Arqueira: mão esquerda ergue o arco à frente no disparo e mão direita puxa a corda."""
    sin, cos, tau = math.sin, math.cos, math.tau
    base = Na.build_base_pose(c)
    base["upperarm_l"] = [(Y, 0.62), (X, -0.42), (Z, 0.18)]
    base["lowerarm_l"] = [(X, -0.52), (Y, 0.12)]
    base["upperarm_r"] = [(Y, -0.52), (X, -0.28)]
    base["lowerarm_r"] = [(X, -0.82), (Z, -0.18)]

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


def _create_recurve_bow(name, wood_mat, gold_mat, gem_mat, grip_pos):
    """Arco recurvo élfico 3D com empunhadura dourada e gema de jade."""
    segs, rings = 8, 22
    verts, faces = [], []
    half_len = 0.52
    pts = []
    for i in range(rings + 1):
        u = (i / rings) * 2.0 - 1.0
        z = u * half_len
        arch = -0.13 * (1.0 - u * u) - 0.04 * (u ** 4)
        x = arch * 0.55 + u * 0.10
        y = arch * 0.85
        r = 0.024 * (1.0 - 0.50 * abs(u)) + 0.006
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
    p_bot = grip_pos + pts[0][0] + Vector((0.01, 0.015, 0))
    p_top = grip_pos + pts[-1][0] + Vector((0.01, 0.015, 0))
    s_base = len(verts)
    for p_end in (p_bot, p_top):
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
    grip_ring = prim("cyl", "EmpunhaduraArco", gold_mat, grip_pos + pts[rings // 2][0], (0.058, 0.058, 0.16), seg=8)
    gem = prim("sphere", "GemaArco", gem_mat, grip_pos + pts[rings // 2][0] + Vector((0, -0.032, 0)), (0.035, 0.025, 0.045))
    return SE._join([o, grip_ring, gem], name)


def build_arqueira_weapon():
    """Flecha Élfica pronta na mão direita (aponta para -Z no espaço do nó Weapon)."""
    K.clear_scene()
    root = bpy.data.objects.new("WeaponRoot", None)
    bpy.context.collection.objects.link(root)
    wood_m = K.color_mat("flecha_madeira", (0.42, 0.26, 0.14), rough=0.6)
    gold_m = K.color_mat("flecha_ponta", (0.92, 0.74, 0.28), metal=0.9, rough=0.22)
    feather_m = K.color_mat("flecha_pena", (0.35, 0.95, 0.62), glow=3.5)
    shaft = prim("cyl", "HasteFlecha", wood_m, Vector((0, 0, -0.45)), (0.025, 0.025, 1.15), seg=6)
    shaft.parent = root
    tip = prim("cone", "PontaFlecha", gold_m, Vector((0, 0, -1.08)), (0.065, 0.028, 0.20), rot=(math.pi, 0, 0), seg=4)
    tip.parent = root
    fth = prim("cone", "PenaFlecha", feather_m, Vector((0, 0, 0.08)), (0.068, 0.022, 0.18), rot=(math.pi, 0, 0), seg=4)
    fth.parent = root
    _export_weapon(root, "weapon_arqueira_ia")


# ==============================================================================
# 5. MAGO (Arquimago Arcano — Vestes Imperiais + Orbe + Cajado de Cristal)
# ==============================================================================

def build_mago():
    """Mago Arcano: rosto 3D esculpido (rhaegar), olhos 3D, cabelo prateado, túnica imperial roxo-astral
    com bordados e placas de ouro/prata, capuz aberto com coroa e diamante astral, Orbe Arcano flutuando
    na mão esquerda e Cajado de Cristal Retorcido na mão direita."""
    c = SE.body(False, SE.PALE, "rhaegar")
    astral_violet = K.color_mat("mago_violeta", (0.16, 0.09, 0.32), rough=0.58)
    deep_indigo = K.color_mat("mago_indigo", (0.09, 0.06, 0.18), rough=0.68)
    gold = K.color_mat("mago_ouro", (0.94, 0.74, 0.28), metal=0.90, rough=0.22)
    silver = K.color_mat("mago_prata", (0.82, 0.86, 0.96), metal=0.90, rough=0.22)
    crystal = K.color_mat("mago_cristal", (0.35, 0.88, 1.0), glow=5.5)
    arcane_purple = K.color_mat("mago_runa_roxa", (0.75, 0.38, 1.0), glow=4.5)
    hair_mat = K.color_mat("mago_cabelo", (0.88, 0.90, 0.96), rough=0.5)

    # Cabelo prateado e sobrancelhas 3D
    SE.short_hair(c, hair_mat, seed=4, length=0.10, fringe=0.15)
    SE.brows(c, hair_mat, 1.05, 0.08)

    # Calças, Túnica Arcana, Peitoral acolchoado com detalhes dourados, Botas e Manoplas
    piece(c, c.tights, "Calca", ["pelvis"] + LEGS, deep_indigo, offset=0.005, zmin=c.ankle_z + 0.06)
    piece(c, c.tights, "Gibao", TORSO + UPPER + LOWER, astral_violet, offset=0.009, zmin=c.hip_z - 0.04)
    piece(c, c.tights, "Peitoral", ["spine_01", "spine_02", "spine_03"], deep_indigo, offset=0.019, thick=0.011, thresh=0.45)
    piece(c, c.tights, "Bota", ["calf_l", "calf_r"] + FEET, gold, offset=0.016, thresh=0.3, zmax=c.knee_z + 0.03)
    piece(c, c.tights, "Bracadeira", LOWER, gold, offset=0.016, thresh=0.45, zmax=c.elbow_z - 0.02)
    D.gloves(c, deep_indigo, 0.010)

    # Robe de Batalha dividido por perna até a canela + placas arcanas douradas
    split_tassets(c, astral_violet, trim_mat=gold, zmin_off=-0.12, zmax_off=0.08)
    knee_and_shin_guards(c, gold, crystal)
    chest_crest(c, gold, crystal)
    belt(c, gold, c.hip_z + 0.06, buckle=crystal)

    # Ombreiras Imperiais de Arquimago com orbes flutuantes
    A.pauldrons(c, astral_violet, gold, spikes=crystal, size=0.16, gem=arcane_purple)

    # Capuz Arcano aberto + Coroa de Prata/Ouro + Diamante Astral na testa
    D.hood(c, astral_violet, point=True)
    h, s = c.head, (c.head_top - c.head).length
    crown = prim("torus", "Coroa", gold, Vector((0, h.y - s * 0.05, c.eye_z + s * 0.38)), (s * 1.12, s * 1.18, 0.22), rot=(0.15, 0, 0), minor=0.055)
    rigid(c, crown, "head")
    gem = prim("sphere", "Joia", crystal, Vector((0, h.y - s * 0.68, c.eye_z + s * 0.42)), (0.028, 0.018, 0.042))
    rigid(c, gem, "head")

    D.cape(c, deep_indigo, 1.22, 0.54, gold)

    # Orbe de Cristal Arcano + Anel Astral na mão esquerda (hand_l)
    hl = K.bone_head(c.arm, "hand_l")
    orb = prim("sphere", "OrbeArcano", crystal, hl + Vector((0.04, -0.10, -0.02)), (0.085, 0.085, 0.085))
    rigid(c, orb, "hand_l")
    orb_ring = prim("torus", "AnelOrbe", gold, hl + Vector((0.04, -0.10, -0.02)), (0.12, 0.12, 0.12), rot=(0.4, 0.3, 0), minor=0.04)
    rigid(c, orb_ring, "hand_l")

    for o in [c.body] + c.parts:
        if o.type == "MESH":
            K.apply_modifiers(o)
    D.anims(c)
    D.weapon_slot(c)
    _export_single_hero(c, "hero_mago_ia")
    build_mago_weapon()


def build_mago_weapon():
    """Cajado Arcano Retorcido com Cristal de Gelo Brilhante no topo (+Z no espaço do nó Weapon da Druida)."""
    K.clear_scene()
    root = bpy.data.objects.new("WeaponRoot", None)
    bpy.context.collection.objects.link(root)
    dark_wood = K.color_mat("cajado_mago_haste", (0.16, 0.12, 0.24), metal=0.65, rough=0.35)
    gold_m = K.color_mat("cajado_mago_ouro", (0.94, 0.74, 0.28), metal=0.92, rough=0.22)
    crystal_m = K.color_mat("cajado_mago_cristal", (0.35, 0.88, 1.0), glow=6.0)

    shaft = prim("cyl", "Cajado", dark_wood, Vector((0, 0, 0.35)), (0.085, 0.085, 2.65), seg=10)
    shaft.parent = root
    for k in range(3):
        ang = k * math.tau / 3
        spiral = prim(
            "cyl",
            f"Espiral{k}",
            gold_m,
            Vector((math.cos(ang) * 0.11, math.sin(ang) * 0.11, 1.62)),
            (0.048, 0.048, 0.58),
            rot=(math.sin(ang) * 0.28, -math.cos(ang) * 0.28, 0),
            seg=6,
        )
        spiral.parent = root
    cr_top = prim("cone", "CristalTopo", crystal_m, Vector((0, 0, 1.98)), (0.28, 0.22, 0.48), seg=6)
    cr_top.parent = root
    cr_bot = prim("cone", "CristalBase", crystal_m, Vector((0, 0, 1.66)), (0.28, 0.22, 0.32), rot=(math.pi, 0, 0), seg=6)
    cr_bot.parent = root
    butt = prim("cone", "PonteiraBase", gold_m, Vector((0, 0, -1.02)), (0.10, 0.10, 0.24), rot=(math.pi, 0, 0), seg=6)
    butt.parent = root

    _export_weapon(root, "weapon_mago_ia")


# ==============================================================================
# 6. Exportação para o Jogo (models/hero_<cls>_ia.glb & weapon_<cls>_ia.glb)
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
