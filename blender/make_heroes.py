"""
Heróis com skins por raridade (Comum, Rara, Épica, Lendária) para Druida, Assassino, Mecânico e Náutico,
no estilo da folha de referência do projeto. Também gera os mascotes (coruja e água-viva).
Gera:  models/hero_<classe>_<raridade>.glb   (corpo + armadura + mão secundária + animações, SEM a arma)
       models/weapon_<classe>_<raridade>.glb (arma; o jogo encaixa no nó "Weapon" da mão direita)
       models/pet_owl.glb, models/pet_jelly.glb, models/pet_fish.glb
Rode:  blender -b -P blender/make_heroes.py     ou   python blender/make_heroes.py  (com pip install bpy)
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_models import (PI, REST, cyc, empty, export, export_static, mat, new_scene, prim, register,  # noqa: E402
                         write_anims)

TIERS = ["comum", "rara", "epica", "lendaria"]
GOLD = (1.0, 0.74, 0.22)
GOLD2 = (0.86, 0.58, 0.14)
PURPLE = (0.75, 0.3, 1.0)
DARKM = (0.1, 0.09, 0.12)
SKIN = (0.93, 0.72, 0.56)
BOOT = (0.32, 0.2, 0.12)
WHITE = (0.96, 0.96, 0.94)
KIND = {"druida": "magic", "assassino": "melee", "mecanico": "melee", "nautico": "thrust"}


def M(tag, rgb, glow=0.0):
    """Material pelo nome; se já receber um material pronto, devolve ele mesmo."""
    if not isinstance(rgb, tuple):
        return rgb
    return mat(tag, rgb, glow=glow)


# =================================================================== corpo base

class Body:
    """Esqueleto padrão: Hips, Head, ArmL/ArmR, LegL/LegR, Weapon. Cada classe veste por cima."""

    def __init__(self, cls, tier, top, pants, boots=BOOT, gloves=None, skin=SKIN, bulky=1.0, skirt=None):
        self.cls, self.tier = cls, tier
        self.kind = KIND[cls]
        self.tag = f"{cls}_{tier}"
        self.top = M(self.tag + "_top", top)
        self.pants = M(self.tag + "_calca", pants)
        self.boots = M(self.tag + "_bota", boots)
        self.gloves = M(self.tag + "_luva", gloves) if gloves else self.boots
        self.skin = M("pele_" + cls, skin)
        self.dark = M("escuro", (0.06, 0.04, 0.04))
        self.white = M("branco", WHITE)
        b = bulky
        root = empty("Hero")
        self.hips = hips = empty("Hips", (0, 0, 0.95), root)
        prim("cyl", "Pelvis", self.pants, (0, 0, 0.02), (0.6 * b, 0.44 * b, 0.3), parent=hips, bevel=0.05, seg=14)
        prim("cone", "Tronco", self.top, (0, 0, 0.42), (0.66 * b, 0.48 * b, 0.64), r2=0.6, parent=hips, bevel=0.05, seg=16)
        if skirt:
            prim("cone", "Saia", M(self.tag + "_saia", skirt), (0, 0, -0.16), (0.8 * b, 0.64 * b, 0.62), r2=0.38, parent=hips, seg=16, bevel=0.03)
        prim("cyl", "Pescoco", self.skin, (0, 0, 0.78), (0.2, 0.2, 0.18), parent=hips, seg=10)
        self.head = head = empty("Head", (0, 0, 1.06), hips)
        self.face = prim("sphere", "Rosto", self.skin, (0, 0.01, 0), (0.56, 0.52, 0.6), parent=head)
        for s in (-1, 1):
            prim("sphere", "Orelha", self.skin, (s * 0.28, 0, 0.0), (0.08, 0.1, 0.14), parent=head, seg=8, rings=5)
        prim("sphere", "Nariz", self.skin, (0, 0.27, -0.06), (0.08, 0.07, 0.1), parent=head, seg=8, rings=5)
        rest_l = {"melee": 0.45, "thrust": 0.25, "magic": 0.25}[self.kind]
        rest_r = {"melee": 1.3, "thrust": 1.4, "magic": 0.12}[self.kind]
        self.arm_l = empty("ArmL", (-0.43 * b, 0, 0.66), hips, (rest_l, 0, 0))
        self.arm_r = empty("ArmR", (0.43 * b, 0, 0.66), hips, (rest_r, 0, 0))
        for arm, side in ((self.arm_l, "L"), (self.arm_r, "R")):
            prim("cyl", f"Manga.{side}", self.top, (0, 0, -0.2), (0.21 * b, 0.21 * b, 0.42), parent=arm, bevel=0.03, seg=10)
            prim("cyl", f"Luva.{side}", self.gloves, (0, 0, -0.47), (0.2 * b, 0.2 * b, 0.22), parent=arm, seg=10)
            prim("sphere", f"Mao.{side}", self.gloves, (0, 0, -0.63), (0.19, 0.19, 0.19), parent=arm, seg=12, rings=8)
        self.leg_l = empty("LegL", (-0.16 * b, 0, 0), hips)
        self.leg_r = empty("LegR", (0.16 * b, 0, 0), hips)
        for leg, side in ((self.leg_l, "L"), (self.leg_r, "R")):
            prim("cyl", f"Coxa.{side}", self.pants, (0, 0, -0.32), (0.25 * b, 0.25 * b, 0.62), parent=leg, bevel=0.03, seg=10)
            prim("box", f"Bota.{side}", self.boots, (0, 0.06, -0.82), (0.28 * b, 0.42, 0.18), parent=leg, bevel=0.05)
            prim("cyl", f"BotaCano.{side}", self.boots, (0, 0, -0.67), (0.29 * b, 0.29 * b, 0.2), parent=leg, seg=10)
        self.weapon = empty("Weapon", (0, 0, -0.63), self.arm_r)
        if self.kind == "magic":
            self.weapon.rotation_euler = (-0.1, 0, -0.12)
        self.cape = None

    # ---- peças comuns
    def eyes(self, color=None, glow=False, y=0.22):
        for s in (-1, 1):
            prim("sphere", "Olho", self.white, (s * 0.11, y, 0.0), (0.12, 0.06, 0.12), parent=self.head, seg=10, rings=6)
            pm = M(f"pupila_{self.tag}", color, glow=4.0) if glow else self.dark
            prim("sphere", "Pupila", pm, (s * 0.11, y + 0.03, -0.005), (0.06, 0.04, 0.08), parent=self.head, seg=8, rings=5)

    def brows(self, hair):
        for s in (-1, 1):
            prim("box", "Sobrancelha", hair, (s * 0.11, 0.24, 0.1), (0.13, 0.03, 0.03), rot=(0, s * 0.15, 0), parent=self.head)

    def mouth(self):
        prim("box", "Boca", M("boca", (0.55, 0.28, 0.25)), (0, 0.25, -0.16), (0.1, 0.02, 0.02), parent=self.head)

    def belt(self, m, buckle):
        prim("cyl", "Cinto", m, (0, 0, 0.13), (0.7, 0.52, 0.1), parent=self.hips, seg=16)
        prim("box", "Fivela", buckle, (0, 0.27, 0.13), (0.14, 0.04, 0.1), parent=self.hips, bevel=0.02)

    def pauldrons(self, m, size=0.34, trim=None, spikes=None):
        for s in (-1, 1):
            prim("sphere", "Ombreira", m, (s * 0.44, 0, 0.68), (size, size * 0.95, size * 0.75), parent=self.hips, seg=14, rings=8)
            if trim:
                prim("torus", "OmbreiraBorda", trim, (s * 0.44, 0, 0.6), (size * 1.02, size, 1.0), parent=self.hips, minor=0.025)
            if spikes:
                for k in range(2):
                    prim("cone", "Espinho", spikes, (s * (0.52 + k * 0.06), -0.02, 0.86 - k * 0.06), (0.09, 0.09, 0.26), rot=(0, s * 0.6, 0), parent=self.hips, seg=6)

    def chest(self, m, trim=None, gem=None):
        prim("cone", "Peitoral", m, (0, 0.03, 0.47), (0.72, 0.54, 0.48), r2=0.64, parent=self.hips, bevel=0.05, seg=16)
        if trim:
            prim("box", "PeitoralFaixa", trim, (0, 0.28, 0.47), (0.14, 0.05, 0.42), parent=self.hips, bevel=0.02)
        if gem:
            prim("sphere", "Gema", gem, (0, 0.3, 0.55), (0.14, 0.08, 0.14), parent=self.hips, seg=10, rings=6)

    def bracers(self, m):
        for arm in (self.arm_l, self.arm_r):
            prim("cyl", "Bracadeira", m, (0, 0, -0.45), (0.24, 0.24, 0.2), parent=arm, seg=10, bevel=0.02)

    def greaves(self, m, knee=None):
        for leg in (self.leg_l, self.leg_r):
            prim("cyl", "Grevas", m, (0, 0.02, -0.56), (0.29, 0.29, 0.26), parent=leg, seg=10, bevel=0.02)
            prim("sphere", "Joelheira", knee or m, (0, 0.11, -0.42), (0.17, 0.12, 0.15), parent=leg, seg=10, rings=6)

    def add_cape(self, m, width=0.66, length=1.2, trim=None):
        self.cape = cape = empty("Cape", (0, -0.27, 0.74), self.hips)
        prim("box", "Capa", m, (0, -0.04, -length / 2), (width, 0.05, length), rot=(0.14, 0, 0), parent=cape, bevel=0.02)
        if trim:
            prim("box", "CapaBarra", trim, (0, -0.12, -length + 0.04), (width + 0.02, 0.06, 0.08), rot=(0.14, 0, 0), parent=cape)

    def hood(self, m, point=True, scarf=None):
        prim("sphere", "Capuz", m, (0, -0.06, 0.06), (0.7, 0.68, 0.66), parent=self.head)
        if point:
            prim("cone", "PontaCapuz", m, (0, -0.32, 0.12), (0.32, 0.32, 0.42), rot=(-1.9, 0, 0), parent=self.head, r2=0.1)
        if scarf:
            prim("torus", "Cachecol", scarf, (0, 0.02, -0.28), (0.62, 0.58, 1.6), parent=self.head, minor=0.09)

    def finish(self):
        joints = [self.hips, self.arm_l, self.arm_r, self.leg_l, self.leg_r] + ([self.cape] if self.cape else [])
        register(*joints)
        _anims(self.kind, self.hips, self.arm_l, self.arm_r, self.leg_l, self.leg_r, self.cape)
        export(f"hero_{self.cls}_{self.tier}")


# =================================================================== DRUIDA

def druida(tier):
    new_scene()
    if tier == "comum":
        b = Body("druida", tier, (0.62, 0.52, 0.38), (0.36, 0.28, 0.2))
        hair = M("cabelo_druida", (0.12, 0.08, 0.05))
        b.eyes()
        b.brows(hair)
        b.mouth()
        prim("sphere", "Cabelo", hair, (0, -0.05, 0.08), (0.6, 0.58, 0.5), parent=b.head)
        poncho = M("druida_poncho", (0.55, 0.45, 0.32))
        prim("cone", "Poncho", poncho, (0, 0, 0.36), (0.9, 0.7, 0.9), r2=0.42, parent=b.hips, seg=8, bevel=0.02)
        b.belt(M("corda", (0.5, 0.38, 0.22)), M("corda_no", (0.45, 0.33, 0.2)))
    elif tier == "rara":
        b = Body("druida", tier, (0.42, 0.28, 0.16), (0.3, 0.22, 0.16), gloves=(0.28, 0.18, 0.1))
        cloak = M("druida_capa_rara", (0.45, 0.3, 0.17))
        b.eyes()
        b.mouth()
        b.hood(cloak)
        rune = M("runa_azul", (0.35, 0.8, 1.0), glow=4.0)
        for s in (-1, 1):
            prim("box", "Pintura", rune, (s * 0.13, 0.26, -0.06), (0.04, 0.02, 0.12), parent=b.head)
        b.add_cape(cloak, 0.78, 1.25)
        b.belt(M("couro", (0.3, 0.2, 0.12)), M("fivela", (0.75, 0.6, 0.3)))
        for s in (-1, 1):
            prim("box", "Bolsa", M("bolsa", (0.38, 0.25, 0.14)), (s * 0.26, 0.2, 0.05), (0.14, 0.1, 0.16), parent=b.hips, bevel=0.03)
    elif tier == "epica":
        leaf = M("folha_epica", (0.13, 0.3, 0.16))
        leaf2 = M("folha_epica2", (0.2, 0.42, 0.2))
        glow = M("brilho_druida_epico", PURPLE, glow=4.5)
        b = Body("druida", tier, (0.12, 0.26, 0.15), (0.1, 0.18, 0.12), boots=(0.1, 0.16, 0.1), gloves=(0.1, 0.18, 0.12))
        prim("sphere", "Mascara", leaf, (0, 0.0, 0.02), (0.64, 0.62, 0.68), parent=b.head)
        for s in (-1, 1):
            prim("box", "OlhoBrilho", glow, (s * 0.12, 0.31, 0.02), (0.13, 0.03, 0.05), rot=(0, s * -0.3, 0), parent=b.head)
            prim("cone", "OrelhaFolha", leaf2, (s * 0.3, -0.05, 0.3), (0.12, 0.08, 0.5), rot=(0.2, s * 0.6, 0), parent=b.head, seg=4)
        b.chest(leaf2, glow)
        for k in range(3):
            prim("cone", f"Folhas{k}", leaf if k % 2 else leaf2, (0, 0.06, 0.62 - k * 0.2), (0.74 - k * 0.04, 0.56, 0.22), r2=0.6, parent=b.hips, seg=8)
        b.pauldrons(leaf2, 0.36, glow)
        b.greaves(leaf2, glow)
        b.bracers(leaf2)
        b.add_cape(M("capa_folhas", (0.1, 0.22, 0.12)), 0.7, 1.15)
    else:
        gold = M("ouro_druida", GOLD)
        gold2 = M("ouro_druida2", GOLD2)
        sun = M("sol_druida", (1.0, 0.86, 0.4), glow=5.0)
        b = Body("druida", tier, GOLD2, GOLD2, boots=GOLD2, gloves=GOLD)
        prim("sphere", "Elmo", gold, (0, -0.01, 0.03), (0.66, 0.64, 0.7), parent=b.head)
        prim("box", "Viseira", sun, (0, 0.31, 0.03), (0.34, 0.04, 0.05), parent=b.head)
        for s in (-1, 1):  # chifres de cervo
            base = (s * 0.22, -0.02, 0.3)
            prim("cone", "Chifre", gold, (base[0] + s * 0.1, base[1], base[2] + 0.35), (0.09, 0.09, 0.8), rot=(0, s * 0.45, 0), parent=b.head, seg=6)
            for k in range(3):
                z = 0.42 + k * 0.17
                prim("cone", f"Galho{k}", gold, (s * (0.36 + k * 0.05), 0.04, z), (0.06, 0.06, 0.36), rot=(-0.3, s * (1.0 - k * 0.15), 0), parent=b.head, seg=6)
        b.chest(gold, M("detalhe_druida_lend", WHITE), sun)
        b.pauldrons(gold, 0.42, gold2)
        for s in (-1, 1):
            prim("cone", "FolhaOmbro", gold2, (s * 0.58, -0.04, 0.8), (0.1, 0.06, 0.4), rot=(0.3, s * 0.9, 0), parent=b.hips, seg=4)
        b.greaves(gold, sun)
        b.bracers(gold)
        b.belt(gold2, sun)
        b.add_cape(M("capa_druida_lend", (0.85, 0.65, 0.2)), 0.74, 1.2, gold)
    b.finish()


def druida_weapon(tier):
    new_scene()
    root = empty("WeaponRoot")
    wood = M("madeira_druida", (0.42, 0.28, 0.15))
    if tier == "comum":
        o = prim("cyl", "Galho", wood, (0, 0, 0.3), (0.09, 0.09, 2.5), parent=root, seg=7)
        prim("sphere", "No", wood, (0.04, 0, 1.4), (0.14, 0.12, 0.2), parent=root, seg=8, rings=5)
        prim("cyl", "Ponta", wood, (0.08, 0, 1.6), (0.07, 0.07, 0.4), rot=(0, 0.35, 0), parent=root, seg=6)
    elif tier == "rara":
        rune = M("runa_azul_arma", (0.4, 0.85, 1.0), glow=5.0)
        prim("cyl", "Cajado", M("madeira_rara", (0.5, 0.36, 0.2)), (0, 0, 0.3), (0.09, 0.09, 2.5), parent=root, seg=7)
        for k in range(3):
            a = k * 2.1
            prim("cyl", f"Garra{k}", wood, (math.cos(a) * 0.12, math.sin(a) * 0.12, 1.65), (0.05, 0.05, 0.5), rot=(math.sin(a) * 0.3, -math.cos(a) * 0.3, 0), parent=root, seg=6)
        prim("ico", "Pedra", rune, (0, 0, 1.68), (0.22, 0.22, 0.3), parent=root, sub=1)
        for k in range(4):
            prim("torus", f"Runa{k}", rune, (0, 0, 0.6 + k * 0.25), (0.13, 0.13, 0.4), parent=root, minor=0.04)
    elif tier == "epica":
        dark = M("madeira_sombria", (0.2, 0.12, 0.1))
        orb = M("orbe_roxo", PURPLE, glow=5.0)
        prim("cyl", "Cajado", dark, (0, 0, 0.3), (0.11, 0.11, 2.6), parent=root, seg=7)
        prim("cyl", "Torcido", dark, (0.05, 0.03, 0.4), (0.06, 0.06, 2.2), rot=(0, 0.05, 0), parent=root, seg=6)
        prim("torus", "Gancho", dark, (0.1, 0, 1.75), (0.55, 0.55, 0.55), rot=(PI / 2, 0, 0), parent=root, minor=0.09)
        prim("sphere", "Orbe", orb, (0.1, 0, 1.75), (0.3, 0.3, 0.3), parent=root, seg=14, rings=8)
        for k in range(3):
            prim("sphere", f"Vagalume{k}", orb, (0.1 + math.cos(k * 2.1) * 0.35, math.sin(k * 2.1) * 0.2, 1.9 + k * 0.08), (0.06, 0.06, 0.06), parent=root, seg=6, rings=4)
    else:
        gold = M("ouro_cajado", GOLD)
        sun = M("sol_cajado", (1.0, 0.9, 0.5), glow=7.0)
        prim("cyl", "Cajado", gold, (0, 0, 0.3), (0.1, 0.1, 2.6), parent=root, seg=8)
        prim("torus", "Anel", gold, (0, 0, 1.85), (0.9, 0.9, 0.9), rot=(PI / 2, 0, 0), parent=root, minor=0.05)
        prim("sphere", "Sol", sun, (0, 0, 1.85), (0.6, 0.6, 0.6), parent=root, seg=16, rings=10)
        for k in range(8):
            a = k * math.tau / 8
            prim("cone", f"Raio{k}", gold, (math.cos(a) * 0.55, 0, 1.85 + math.sin(a) * 0.55), (0.07, 0.04, 0.2), rot=(0, -a + PI / 2, 0), parent=root, seg=4)
        for s in (-1, 1):
            prim("cone", "Folha", gold, (s * 0.18, 0, 1.3), (0.1, 0.04, 0.4), rot=(0, s * 0.7, 0), parent=root, seg=4)
    export_static(f"weapon_druida_{tier}")


# =================================================================== ASSASSINO

def _dagger(parent, name, blade, grip, guard, length=0.7, curved=False, glow=None):
    prim("cyl", name + "Cabo", grip, (0, 0, 0.04), (0.07, 0.07, 0.26), parent=parent, seg=8)
    prim("box", name + "Guarda", guard, (0, 0, -0.12), (0.3, 0.07, 0.06), parent=parent, bevel=0.015)
    if curved:
        for k in range(4):
            prim("box", f"{name}Lamina{k}", blade, (0.03 * k * k, 0, -0.2 - k * length / 4), (0.13 - k * 0.015, 0.03, length / 4 + 0.03), rot=(0, 0.12 * k, 0), parent=parent, bevel=0.01)
    else:
        prim("box", name + "Lamina", blade, (0, 0, -0.15 - length / 2), (0.12, 0.03, length), parent=parent, bevel=0.01)
        prim("cone", name + "Ponta", blade, (0, 0, -0.15 - length - 0.07), (0.14, 0.04, 0.16), rot=(PI, 0, 0), parent=parent, seg=4)
    if glow:
        prim("box", name + "Fio", glow, (0, 0, -0.15 - length / 2), (0.035, 0.035, length * 0.9), parent=parent)


def _assassin_mats(tier):
    if tier == "comum":
        return M("adaga_comum", (0.78, 0.8, 0.84)), M("cabo_comum", (0.3, 0.2, 0.12)), M("guarda_comum", (0.45, 0.4, 0.35)), None, False
    if tier == "rara":
        return M("adaga_rara", (0.75, 0.88, 1.0)), M("cabo_raro", (0.15, 0.15, 0.2)), M("guarda_rara", (0.3, 0.45, 0.8)), M("fio_raro", (0.5, 0.8, 1.0), glow=3.0), False
    if tier == "epica":
        return M("adaga_epica", (0.55, 0.25, 0.85)), M("cabo_epico", (0.08, 0.06, 0.1)), M("guarda_epica", (0.2, 0.15, 0.25)), M("fio_epico", PURPLE, glow=5.0), True
    return M("adaga_lend", (1.0, 0.85, 0.4)), M("cabo_lend", (0.1, 0.08, 0.06)), M("guarda_lend", GOLD), M("fio_lend", (1.0, 0.9, 0.5), glow=5.0), False


def assassino(tier):
    new_scene()
    if tier == "comum":
        b = Body("assassino", tier, (0.28, 0.25, 0.22), (0.2, 0.18, 0.16))
        hood = M("capuz_assassino", (0.62, 0.55, 0.42))
        b.eyes()
        b.mouth()
        b.hood(hood, point=False, scarf=hood)
        b.belt(M("couro", (0.3, 0.2, 0.12)), M("fivela_escura", (0.4, 0.35, 0.3)))
    elif tier == "rara":
        b = Body("assassino", tier, (0.36, 0.24, 0.14), (0.16, 0.13, 0.12), boots=(0.22, 0.14, 0.08), gloves=(0.12, 0.1, 0.1))
        black = M("capuz_negro", (0.1, 0.09, 0.1))
        b.eyes()
        b.hood(black, point=True)
        prim("sphere", "Mascara", black, (0, 0.12, -0.14), (0.5, 0.4, 0.3), parent=b.head)
        b.add_cape(M("capa_azul", (0.15, 0.25, 0.55)), 0.72, 1.25)
        b.belt(M("couro", (0.3, 0.2, 0.12)), M("fivela", (0.7, 0.7, 0.75)))
        for k in range(3):
            prim("box", f"Correia{k}", M("couro2", (0.25, 0.16, 0.1)), (0.0, 0.25, 0.3 + k * 0.12), (0.62, 0.03, 0.04), rot=(0, 0.5, 0), parent=b.hips)
    elif tier == "epica":
        armor = M("armadura_sombria", (0.12, 0.1, 0.14))
        glow = M("brilho_assassino", PURPLE, glow=5.0)
        b = Body("assassino", tier, (0.1, 0.09, 0.12), (0.08, 0.07, 0.1), boots=DARKM, gloves=DARKM)
        prim("sphere", "Elmo", armor, (0, -0.01, 0.04), (0.64, 0.62, 0.68), parent=b.head)
        prim("box", "Visor", glow, (0, 0.31, 0.04), (0.36, 0.04, 0.06), parent=b.head)
        prim("cone", "Crista", armor, (0, -0.1, 0.38), (0.1, 0.4, 0.4), rot=(-0.5, 0, 0), parent=b.head, seg=4)
        b.chest(armor, glow)
        b.pauldrons(armor, 0.38, glow, spikes=armor)
        b.greaves(armor, glow)
        b.bracers(armor)
        b.add_cape(M("capa_rasgada", (0.06, 0.05, 0.08)), 0.7, 1.1)
    else:
        gold = M("ouro_assassino", GOLD)
        black = M("negro_assassino", (0.08, 0.07, 0.08))
        glow = M("brilho_assassino_lend", (1.0, 0.85, 0.4), glow=5.0)
        b = Body("assassino", tier, (0.12, 0.1, 0.1), (0.1, 0.08, 0.08), boots=black, gloves=gold)
        prim("sphere", "Elmo", gold, (0, -0.01, 0.04), (0.66, 0.64, 0.7), parent=b.head)
        prim("box", "Visor", glow, (0, 0.31, 0.03), (0.3, 0.04, 0.05), parent=b.head)
        for k in range(5):  # crista de dragão
            prim("cone", f"Escama{k}", gold, (0, -0.12 - k * 0.07, 0.36 - k * 0.04), (0.1, 0.18, 0.34 - k * 0.04), rot=(-0.7, 0, 0), parent=b.head, seg=4)
        for s in (-1, 1):
            prim("cone", "ChifreDragao", gold, (s * 0.26, -0.1, 0.28), (0.1, 0.1, 0.5), rot=(-0.6, s * 0.7, 0), parent=b.head, seg=6)
        b.chest(black, gold, glow)
        b.pauldrons(gold, 0.42, black, spikes=gold)
        b.greaves(gold, glow)
        b.bracers(gold)
        b.add_cape(M("capa_dourada", (0.85, 0.62, 0.18)), 0.82, 1.3, black)
    blade, grip, guard, glow, curved = _assassin_mats(tier)
    left = empty("OffhandDagger", (0, 0, -0.63), b.arm_l)
    _dagger(left, "AdagaL", blade, grip, guard, 0.6 if tier == "comum" else 0.72, curved, glow)
    b.finish()


def assassino_weapon(tier):
    new_scene()
    root = empty("WeaponRoot")
    blade, grip, guard, glow, curved = _assassin_mats(tier)
    _dagger(root, "Adaga", blade, grip, guard, 0.6 if tier == "comum" else 0.78, curved, glow)
    if tier == "lendaria":
        for s in (-1, 1):
            prim("box", "AsaGuarda", M("asa_branca", WHITE), (s * 0.24, 0, -0.06), (0.22, 0.03, 0.1), rot=(0, s * 0.6, 0), parent=root, bevel=0.01)
    export_static(f"weapon_assassino_{tier}")


# =================================================================== MECÂNICO

def _gear(parent, name, m, pos, r, rot=(0, 0, 0), teeth=8, thick=0.08):
    g = empty(name, pos, parent, rot)
    prim("cyl", name + "Disco", m, (0, 0, 0), (r * 2, r * 2, thick), parent=g, seg=16)
    for k in range(teeth):
        a = k * math.tau / teeth
        prim("box", f"{name}Dente{k}", m, (math.cos(a) * r, math.sin(a) * r, 0), (r * 0.35, r * 0.35, thick), rot=(0, 0, a), parent=g)
    prim("cyl", name + "Furo", M("escuro", (0.06, 0.04, 0.04)), (0, 0, 0), (r * 0.6, r * 0.6, thick + 0.01), parent=g, seg=10)
    return g


def mecanico(tier):
    new_scene()
    if tier == "comum":
        b = Body("mecanico", tier, (0.55, 0.5, 0.4), (0.4, 0.42, 0.46), boots=(0.28, 0.2, 0.14))
        hair = M("cabelo_mec", (0.3, 0.2, 0.12))
        b.eyes()
        b.brows(hair)
        b.mouth()
        cap = M("bone_mec", (0.42, 0.44, 0.48))
        prim("sphere", "Bone", cap, (0, -0.02, 0.18), (0.62, 0.62, 0.36), parent=b.head)
        prim("box", "Aba", cap, (0, 0.28, 0.12), (0.46, 0.22, 0.04), rot=(-0.15, 0, 0), parent=b.head, bevel=0.02)
        overall = M("macacao", (0.4, 0.42, 0.46))
        prim("box", "Peito", overall, (0, 0.24, 0.35), (0.4, 0.06, 0.36), parent=b.hips, bevel=0.03)
        for s in (-1, 1):
            prim("box", "Alca", overall, (s * 0.17, 0.0, 0.55), (0.08, 0.52, 0.04), rot=(PI / 2, 0, 0), parent=b.hips)
        _gear(b.arm_l, "EngrenagemMao", M("aco_mec", (0.62, 0.64, 0.68)), (0, 0.12, -0.7), 0.16, (PI / 2, 0, 0))
    elif tier == "rara":
        b = Body("mecanico", tier, (0.6, 0.6, 0.62), (0.32, 0.33, 0.36), boots=(0.26, 0.18, 0.12), gloves=(0.3, 0.2, 0.12))
        b.eyes()
        b.mouth()
        for s in (-1, 1):
            prim("sphere", "Costeleta", M("cabelo_mec", (0.3, 0.2, 0.12)), (s * 0.25, 0.02, -0.06), (0.1, 0.12, 0.24), parent=b.head, seg=8, rings=5)
        strap = M("tira_oculos", (0.25, 0.18, 0.12))
        lens = M("lente", (0.45, 0.8, 1.0), glow=2.0)
        prim("torus", "TiraOculos", strap, (0, 0, 0.16), (0.6, 0.56, 1.0), parent=b.head, minor=0.05)
        for s in (-1, 1):
            prim("cyl", "Oculos", M("aro_oculos", (0.7, 0.55, 0.3)), (s * 0.12, 0.26, 0.2), (0.17, 0.17, 0.08), rot=(PI / 2 - 0.4, 0, 0), parent=b.head, seg=12)
            prim("cyl", "Lente", lens, (s * 0.12, 0.29, 0.21), (0.13, 0.13, 0.02), rot=(PI / 2 - 0.4, 0, 0), parent=b.head, seg=12)
        apron = M("avental", (0.42, 0.27, 0.15))
        prim("box", "Avental", apron, (0, 0.27, 0.15), (0.5, 0.05, 0.85), parent=b.hips, bevel=0.03)
        prim("box", "Bolso", M("avental2", (0.35, 0.22, 0.12)), (0, 0.31, 0.15), (0.3, 0.03, 0.18), parent=b.hips)
        b.belt(M("couro", (0.3, 0.2, 0.12)), M("fivela", (0.75, 0.6, 0.3)))
    elif tier == "epica":
        suit = M("traje_robo", (0.12, 0.12, 0.15))
        plate = M("placa_robo", (0.22, 0.22, 0.26))
        glow = M("luz_robo", PURPLE, glow=5.0)
        b = Body("mecanico", tier, (0.12, 0.12, 0.15), (0.12, 0.12, 0.15), boots=(0.2, 0.2, 0.24), gloves=(0.2, 0.2, 0.24), bulky=1.08)
        prim("sphere", "Capacete", plate, (0, 0, 0.02), (0.68, 0.66, 0.7), parent=b.head)
        prim("cyl", "OlhoRobo", glow, (0, 0.33, 0.04), (0.22, 0.22, 0.04), rot=(PI / 2, 0, 0), parent=b.head, seg=16)
        prim("torus", "AroOlho", suit, (0, 0.33, 0.04), (0.26, 0.26, 0.6), rot=(PI / 2, 0, 0), parent=b.head, minor=0.05)
        b.chest(plate, glow, glow)
        b.pauldrons(plate, 0.4, glow)
        b.greaves(plate, glow)
        b.bracers(plate)
        for s in (-1, 1):
            prim("box", "Faixa", glow, (s * 0.2, 0.25, 0.25), (0.04, 0.04, 0.3), parent=b.hips)
        prim("box", "Mochila", plate, (0, -0.3, 0.45), (0.5, 0.25, 0.5), parent=b.hips, bevel=0.05)
    else:
        gold = M("ouro_mec", GOLD)
        gold2 = M("ouro_mec2", GOLD2)
        glow = M("luz_mec_lend", (1.0, 0.85, 0.4), glow=5.0)
        b = Body("mecanico", tier, GOLD2, GOLD2, boots=GOLD2, gloves=GOLD, bulky=1.18)
        prim("sphere", "Elmo", gold, (0, 0, 0.04), (0.7, 0.68, 0.72), parent=b.head)
        prim("box", "Visor", M("visor_escuro", (0.06, 0.05, 0.05)), (0, 0.32, 0.05), (0.4, 0.05, 0.08), parent=b.head)
        prim("box", "VisorV", M("visor_escuro", (0.06, 0.05, 0.05)), (0, 0.33, -0.08), (0.08, 0.05, 0.2), parent=b.head)
        b.chest(gold, gold2, glow)
        b.pauldrons(gold, 0.5, gold2)
        b.greaves(gold, glow)
        b.bracers(gold)
        prim("box", "Mochila", gold2, (0, -0.32, 0.5), (0.56, 0.28, 0.56), parent=b.hips, bevel=0.06)
        for s in (-1, 1):
            prim("cyl", "Exaustor", M("cobre", (0.7, 0.4, 0.2)), (s * 0.18, -0.45, 0.8), (0.12, 0.12, 0.4), parent=b.hips, seg=10)
        halo = empty("Aureola", (0, -0.55, 1.75), b.hips, (PI / 2, 0, 0))
        _gear(halo, "Halo", gold, (0, 0, 0), 0.62, teeth=16, thick=0.06)
        for k in range(12):
            a = k * math.tau / 12
            prim("cone", f"RaioHalo{k}", glow, (math.cos(a) * 0.85, math.sin(a) * 0.85, 0), (0.07, 0.07, 0.22), rot=(0, PI / 2, a), parent=halo, seg=4)
        _gear(b.arm_l, "CanhaoL", gold2, (0, 0.05, -0.62), 0.22, (PI / 2, 0, 0), teeth=10, thick=0.14)
    b.finish()


def mecanico_weapon(tier):
    new_scene()
    root = empty("WeaponRoot")
    if tier in ("comum", "rara"):
        steel = M("aco_chave" + tier, (0.66, 0.68, 0.72) if tier == "comum" else (0.75, 0.82, 0.9))
        prim("box", "Cabo", steel, (0, 0, -0.35), (0.1, 0.06, 0.8), parent=root, bevel=0.02)
        prim("torus", "Boca", steel, (0, 0, -0.85), (0.32, 0.32, 0.5), rot=(PI / 2, 0, 0), parent=root, minor=0.12)
        prim("box", "Abertura", M("escuro", (0.06, 0.04, 0.04)), (0, 0, -0.98), (0.12, 0.08, 0.14), parent=root)
        if tier == "rara":
            el = M("eletrico", (0.45, 0.85, 1.0), glow=6.0)
            for k in range(3):
                prim("torus", f"Bobina{k}", M("cobre", (0.75, 0.45, 0.2)), (0, 0, -0.15 - k * 0.12), (0.16, 0.16, 0.5), parent=root, minor=0.05)
            for k in range(4):
                a = k * math.tau / 4
                prim("cone", f"Faisca{k}", el, (math.cos(a) * 0.2, math.sin(a) * 0.2, -0.95), (0.05, 0.05, 0.24), rot=(math.sin(a) * 1.2, -math.cos(a) * 1.2, 0), parent=root, seg=4)
    elif tier == "epica":
        dark = M("garra_metal", (0.2, 0.2, 0.24))
        glow = M("plasma", PURPLE, glow=6.0)
        prim("cyl", "Corpo", dark, (0, 0, -0.3), (0.22, 0.22, 0.6), parent=root, seg=10, bevel=0.03)
        prim("sphere", "Nucleo", glow, (0, 0, -0.62), (0.22, 0.22, 0.22), parent=root, seg=12, rings=8)
        for k in range(3):
            a = k * math.tau / 3
            prim("cone", f"Garra{k}", dark, (math.cos(a) * 0.12, math.sin(a) * 0.12, -0.85), (0.07, 0.07, 0.4), rot=(math.sin(a) * -0.4, math.cos(a) * 0.4, 0), parent=root, seg=6)
            prim("cone", f"Raio{k}", glow, (math.cos(a) * 0.1, math.sin(a) * 0.1, -1.05), (0.04, 0.04, 0.3), rot=(math.sin(a) * -0.3, math.cos(a) * 0.3, 0), parent=root, seg=4)
    else:
        gold = M("ouro_canhao", GOLD)
        gold2 = M("ouro_canhao2", GOLD2)
        glow = M("canhao_luz", (1.0, 0.85, 0.4), glow=6.0)
        prim("cyl", "Cano", gold, (0, 0, -0.5), (0.3, 0.3, 1.0), parent=root, seg=14, bevel=0.03)
        prim("cyl", "Boca", glow, (0, 0, -1.02), (0.24, 0.24, 0.04), parent=root, seg=14)
        for z in (-0.25, -0.6, -0.9):
            prim("torus", "Aro", gold2, (0, 0, z), (0.36, 0.36, 0.6), parent=root, minor=0.05)
        _gear(root, "Engrenagem", gold2, (0.0, 0.0, -0.35), 0.28, (0, PI / 2, 0), teeth=10, thick=0.06)
    export_static(f"weapon_mecanico_{tier}")


# =================================================================== NÁUTICO

def nautico(tier):
    new_scene()
    if tier == "comum":
        b = Body("nautico", tier, WHITE, (0.14, 0.15, 0.22), boots=(0.25, 0.16, 0.1), skin=(0.88, 0.66, 0.5))
        hair = M("barba_nautico", (0.2, 0.13, 0.08))
        navy = M("listra_azul", (0.12, 0.16, 0.32))
        b.eyes()
        b.brows(hair)
        for k in range(4):  # camisa listrada
            prim("torus", f"Listra{k}", navy, (0, 0, 0.2 + k * 0.14), (0.6 - k * 0.02, 0.45, 1.0), parent=b.hips, minor=0.045)
        for arm in (b.arm_l, b.arm_r):
            prim("torus", "ListraBraco", navy, (0, 0, -0.18), (0.22, 0.22, 1.0), parent=arm, minor=0.04)
        prim("sphere", "Barba", hair, (0, 0.18, -0.2), (0.44, 0.3, 0.32), parent=b.head, seg=12, rings=8)
        cap = M("bone_nautico", (0.1, 0.1, 0.12))
        prim("sphere", "Gorro", cap, (0, -0.02, 0.18), (0.62, 0.62, 0.36), parent=b.head)
        prim("box", "Aba", cap, (0, 0.28, 0.12), (0.42, 0.2, 0.04), rot=(-0.15, 0, 0), parent=b.head, bevel=0.02)
    elif tier == "rara":
        b = Body("nautico", tier, (0.85, 0.85, 0.82), (0.25, 0.3, 0.42), boots=(0.25, 0.16, 0.1), gloves=(0.3, 0.2, 0.12), skin=(0.85, 0.62, 0.46))
        beard = M("barba_cinza", (0.55, 0.52, 0.5))
        vest = M("colete_azul", (0.15, 0.35, 0.6))
        b.eyes()
        b.brows(beard)
        prim("sphere", "Barba", beard, (0, 0.18, -0.2), (0.44, 0.3, 0.34), parent=b.head, seg=12, rings=8)
        prim("cone", "Colete", vest, (0, 0.02, 0.45), (0.72, 0.52, 0.56), r2=0.66, parent=b.hips, seg=16, bevel=0.03)
        prim("sphere", "Elmo", M("elmo_marinho", (0.25, 0.4, 0.6)), (0, -0.02, 0.14), (0.62, 0.62, 0.42), parent=b.head)
        prim("box", "Barbatana", M("barbatana", (0.35, 0.7, 0.9)), (0, -0.08, 0.38), (0.05, 0.4, 0.2), rot=(-0.3, 0, 0), parent=b.head)
        b.belt(M("couro", (0.3, 0.2, 0.12)), M("fivela", (0.75, 0.6, 0.3)))
        prim("cyl", "Bussola", M("ouro_bussola", GOLD), (0.25, 0.22, 0.02), (0.14, 0.14, 0.04), rot=(PI / 2, 0, 0), parent=b.hips, seg=12)
    elif tier == "epica":
        armor = M("armadura_abismo", (0.1, 0.1, 0.16))
        glow = M("brilho_abismo", (0.7, 0.4, 1.0), glow=5.0)
        b = Body("nautico", tier, (0.1, 0.1, 0.16), (0.08, 0.08, 0.12), boots=DARKM, gloves=DARKM, bulky=1.05)
        prim("sphere", "Elmo", armor, (0, -0.01, 0.04), (0.66, 0.64, 0.7), parent=b.head)
        prim("box", "Visor", glow, (0, 0.31, 0.04), (0.34, 0.04, 0.05), parent=b.head)
        for k in range(5):
            a = (k - 2) * 0.35
            prim("cone", f"Coral{k}", armor if k % 2 else glow, (math.sin(a) * 0.25, -0.05, 0.4), (0.08, 0.08, 0.5 - abs(k - 2) * 0.08), rot=(0, a, 0), parent=b.head, seg=5)
        b.chest(armor, glow, glow)
        b.pauldrons(armor, 0.42, glow, spikes=glow)
        b.greaves(armor, glow)
        b.bracers(armor)
        b.add_cape(M("capa_abismo", (0.12, 0.08, 0.2)), 0.72, 1.15)
    else:
        gold = M("ouro_nautico", GOLD)
        gold2 = M("ouro_nautico2", GOLD2)
        sapphire = M("safira", (0.25, 0.5, 1.0), glow=3.0)
        b = Body("nautico", tier, GOLD2, GOLD2, boots=GOLD2, gloves=GOLD, bulky=1.1)
        prim("sphere", "Elmo", gold, (0, -0.01, 0.04), (0.68, 0.66, 0.72), parent=b.head)
        prim("box", "Visor", M("visor_escuro", (0.06, 0.05, 0.05)), (0, 0.32, 0.03), (0.3, 0.05, 0.06), parent=b.head)
        prim("sphere", "Joia", sapphire, (0, 0.33, 0.2), (0.1, 0.06, 0.1), parent=b.head, seg=8, rings=5)
        for k in range(5):  # coroa de tridente
            a = (k - 2) * 0.3
            prim("cone", f"Coroa{k}", gold, (math.sin(a) * 0.24, 0.0, 0.42), (0.08, 0.08, 0.36 - abs(k - 2) * 0.06), rot=(0, a * 0.6, 0), parent=b.head, seg=4)
        b.chest(gold, gold2, sapphire)
        b.pauldrons(gold, 0.46, gold2)
        b.greaves(gold, sapphire)
        b.bracers(gold)
        b.belt(gold2, sapphire)
        b.add_cape(M("capa_mar", (0.12, 0.3, 0.6)), 0.78, 1.25, gold)
    b.finish()


def nautico_weapon(tier):
    new_scene()
    root = empty("WeaponRoot")
    if tier == "comum":
        wood = M("arpao_madeira", (0.42, 0.28, 0.15))
        steel = M("arpao_aco", (0.75, 0.78, 0.82))
        prim("cyl", "Haste", wood, (0, 0, -1.1), (0.08, 0.08, 3.0), parent=root, seg=8)
        prim("cone", "Ponta", steel, (0, 0, -2.85), (0.16, 0.16, 0.55), rot=(PI, 0, 0), parent=root, seg=6)
        for s in (-1, 1):
            prim("cone", "Farpa", steel, (s * 0.09, 0, -2.62), (0.06, 0.06, 0.22), rot=(0, s * 2.6, 0), parent=root, seg=4)
        prim("torus", "Corda", M("corda", (0.75, 0.68, 0.5)), (0, 0, -0.1), (0.14, 0.14, 0.6), parent=root, minor=0.04)
        export_static(f"weapon_nautico_{tier}")
        return
    shaft_c = {"rara": (0.45, 0.32, 0.2), "epica": (0.12, 0.1, 0.16), "lendaria": GOLD2}[tier]
    head_c = {"rara": (0.55, 0.75, 0.9), "epica": (0.2, 0.18, 0.26), "lendaria": GOLD}[tier]
    shaft = M("tridente_haste_" + tier, shaft_c)
    headm = M("tridente_ponta_" + tier, head_c)
    L = {"rara": 3.1, "epica": 3.2, "lendaria": 3.4}[tier]
    prim("cyl", "Haste", shaft, (0, 0, -L / 2 + 0.4), (0.09, 0.09, L), parent=root, seg=8)
    base_z = -L + 0.35
    prim("box", "Travessa", headm, (0, 0, base_z), (0.62, 0.08, 0.1), parent=root, bevel=0.02)
    for x in (-0.28, 0.0, 0.28):
        h = 0.7 if x == 0 else 0.55
        prim("cyl", "Dente", headm, (x, 0, base_z - h / 2), (0.07, 0.07, h), parent=root, seg=6)
        prim("cone", "PontaDente", headm, (x, 0, base_z - h - 0.1), (0.14, 0.06, 0.22), rot=(PI, 0, 0), parent=root, seg=4)
    if tier == "epica":
        el = M("raio_tridente", (0.75, 0.6, 1.0), glow=6.0)
        for x in (-0.28, 0.0, 0.28):
            prim("box", "Raio", el, (x, 0.04, base_z - 0.35), (0.03, 0.03, 0.55), parent=root)
        prim("sphere", "Nucleo", el, (0, 0, base_z + 0.1), (0.16, 0.16, 0.16), parent=root, seg=10, rings=6)
    if tier == "lendaria":
        sapphire = M("safira_tridente", (0.25, 0.5, 1.0), glow=4.0)
        prim("sphere", "Safira", sapphire, (0, 0, base_z + 0.12), (0.2, 0.2, 0.2), parent=root, seg=12, rings=8)
        for s in (-1, 1):
            prim("cone", "Asa", headm, (s * 0.38, 0, base_z + 0.1), (0.08, 0.06, 0.34), rot=(0, s * 2.2, 0), parent=root, seg=4)
    export_static(f"weapon_nautico_{tier}")


# =================================================================== mascotes

def pets():
    new_scene()
    feather = M("coruja_pena", (0.45, 0.25, 0.75), glow=1.5)
    light = M("coruja_brilho", (0.8, 0.55, 1.0), glow=4.0)
    eye = M("coruja_olho", (1.0, 0.9, 0.5), glow=5.0)
    prim("sphere", "Corpo", feather, (0, 0, 0.3), (0.5, 0.45, 0.6), seg=14, rings=8)
    prim("sphere", "Cabeca", feather, (0, 0.04, 0.68), (0.46, 0.42, 0.38), seg=14, rings=8)
    prim("sphere", "Barriga", light, (0, 0.17, 0.28), (0.32, 0.16, 0.42), seg=12, rings=8)
    for s in (-1, 1):
        prim("sphere", "Olho", eye, (s * 0.1, 0.2, 0.7), (0.12, 0.05, 0.12), seg=8, rings=5)
        prim("cone", "Orelha", feather, (s * 0.15, 0.0, 0.9), (0.08, 0.06, 0.2), rot=(0, s * 0.3, 0), seg=4)
        prim("box", "Asa", feather, (s * 0.3, -0.02, 0.32), (0.08, 0.32, 0.46), rot=(0, s * 0.3, 0), bevel=0.03)
    prim("cone", "Bico", M("bico", (0.9, 0.7, 0.3)), (0, 0.24, 0.62), (0.07, 0.07, 0.1), rot=(PI, 0, 0), seg=4)
    export_static("pet_owl")

    new_scene()
    bell = M("agua_viva", (0.85, 0.5, 1.0), glow=2.5)
    core = M("agua_viva_nucleo", (1.0, 0.75, 1.0), glow=5.0)
    prim("sphere", "Sino", bell, (0, 0, 0.7), (0.7, 0.7, 0.5), seg=18, rings=10)
    prim("sphere", "Nucleo", core, (0, 0, 0.66), (0.3, 0.3, 0.22), seg=12, rings=8)
    for k in range(8):
        a = k * math.tau / 8
        prim("cone", f"Tentaculo{k}", bell, (math.cos(a) * 0.2, math.sin(a) * 0.2, 0.15), (0.06, 0.06, 0.95), rot=(math.sin(a) * 0.15, -math.cos(a) * 0.15, 0), seg=5)
    export_static("pet_jelly")

    new_scene()
    fish = M("peixe_dourado", GOLD, glow=1.2)
    prim("sphere", "Corpo", fish, (0, 0, 0), (0.16, 0.36, 0.2), seg=10, rings=6)
    prim("cone", "Cauda", fish, (0, -0.22, 0), (0.16, 0.04, 0.16), rot=(PI / 2, 0, 0), seg=4)
    export_static("pet_fish")


# =================================================================== animações

def _anims(kind, hips, arm_l, arm_r, leg_l, leg_r, cape):
    rl, rr = REST[arm_l]["rot"], REST[arm_r]["rot"]
    hz = 0.95

    def arm(rest, dx=0.0, dz=0.0):
        return (rest[0] + dx, rest[1], rest[2] + dz)

    cape_idle = {cape: dict(rot=cyc(36, 4, lambda t: (0.05 * math.sin(2 * PI * t), 0, 0)))} if cape else {}
    cape_walk = {cape: dict(rot=cyc(24, 8, lambda t: (0.25 + 0.08 * math.sin(4 * PI * t), 0, 0)))} if cape else {}
    idle = dict(length=36, joints={
        hips: dict(loc=cyc(36, 4, lambda t: (0, 0, hz + 0.02 * (1 - math.cos(2 * PI * t))))),
        arm_l: dict(rot=cyc(36, 4, lambda t: arm(rl, 0.05 * math.cos(2 * PI * t)))),
        arm_r: dict(rot=cyc(36, 4, lambda t: arm(rr, 0.03 * math.cos(2 * PI * t)))),
        **cape_idle,
    })
    walk = dict(length=24, joints={
        hips: dict(loc=cyc(24, 8, lambda t: (0, 0, hz - 0.06 - 0.05 * math.cos(4 * PI * t)))),
        leg_l: dict(rot=cyc(24, 8, lambda t: (0.55 * math.cos(2 * PI * t), 0, 0))),
        leg_r: dict(rot=cyc(24, 8, lambda t: (-0.55 * math.cos(2 * PI * t), 0, 0))),
        arm_l: dict(rot=cyc(24, 8, lambda t: arm(rl, -0.4 * math.cos(2 * PI * t)))),
        arm_r: dict(rot=cyc(24, 8, lambda t: arm(rr, 0.15 * math.cos(2 * PI * t)))),
        **cape_walk,
    })
    if kind == "melee":
        atk = {
            hips: dict(rot=[(1, (0, 0, 0)), (4, (0, 0, 0.95)), (8, (0, 0, -1.05)), (13, (0, 0, 0))],
                       loc=[(1, (0, 0, hz)), (4, (0, -0.1, hz)), (8, (0, 0.3, hz)), (13, (0, 0, hz))]),
            arm_r: dict(rot=[(1, rr), (4, arm(rr, 0.2)), (8, arm(rr, -0.1)), (13, rr)]),
            arm_l: dict(rot=[(1, rl), (4, arm(rl, 0.3)), (8, arm(rl, 0.9)), (13, rl)]),
        }
    elif kind == "thrust":
        atk = {
            hips: dict(rot=[(1, (0, 0, 0)), (3, (0, 0, 0.3)), (5, (0, 0, -0.2)), (13, (0, 0, 0))],
                       loc=[(1, (0, 0, hz)), (3, (0, -0.18, hz)), (5, (0, 0.7, 0.82)), (13, (0, 0, hz))]),
            arm_r: dict(rot=[(1, rr), (3, arm(rr, 0.25)), (5, arm(rr, -0.05)), (13, rr)]),
            leg_l: dict(rot=[(1, (0, 0, 0)), (5, (0.55, 0, 0)), (13, (0, 0, 0))]),
            leg_r: dict(rot=[(1, (0, 0, 0)), (5, (-0.45, 0, 0)), (13, (0, 0, 0))]),
        }
    else:
        atk = {
            hips: dict(rot=[(1, (0, 0, 0)), (4, (0.1, 0, 0.2)), (7, (-0.15, 0, -0.1)), (13, (0, 0, 0))],
                       loc=[(1, (0, 0, hz)), (4, (0, -0.1, hz)), (7, (0, 0.2, hz)), (13, (0, 0, hz))]),
            arm_r: dict(rot=[(1, rr), (4, arm(rr, -0.5)), (7, arm(rr, 1.0)), (13, rr)]),
            arm_l: dict(rot=[(1, rl), (4, arm(rl, 0.5)), (7, arm(rl, 0.9)), (13, rl)]),
        }
    write_anims({"idle": idle, "walk": walk, "attack": dict(length=12, joints=atk)})


BUILD = {"druida": (druida, druida_weapon), "assassino": (assassino, assassino_weapon),
         "mecanico": (mecanico, mecanico_weapon), "nautico": (nautico, nautico_weapon)}


def main():
    only = os.environ.get("ONLY")
    for cls, (body, weapon) in BUILD.items():
        if only and cls != only:
            continue
        for tier in TIERS:
            # A Druida agora é humanizada pelo MPFB2 (blender/make_druid_mpfb.py); aqui só a arma dela.
            if cls != "druida":
                body(tier)
            weapon(tier)
    if not only:
        pets()


if __name__ == "__main__":
    main()
