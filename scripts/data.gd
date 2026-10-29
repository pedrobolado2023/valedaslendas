class_name GameData
extends RefCounted
## Todos os números do jogo num lugar só: classes, skills, inimigos, zonas e missões.
## Para balancear, mude aqui.

const MAX_LEVEL := 60
## Menu de administrador (F1). Troque para false antes de lançar o jogo para os jogadores.
const ADMIN_ENABLED := true
const MAX_SKILL_LEVEL := 10
## Nível do personagem necessário para aprender cada skill (até 10 por classe; teclas 1-9 e 0).
const SKILL_UNLOCK := [1, 3, 6, 10, 15, 20, 25, 30, 40, 50]
const MAX_SKILLS := 10
## Multiplicador da área (raio "r") de todas as skills.
const AREA_MULT := 1.4

const CLASSES := {
	"assassino": {
		"name": "Assassino", "desc": "Alta mobilidade, dano crítico massivo e furtividade.",
		"hp": 160, "mp": 85, "atk": 25.0, "speed": 7.6,
		"basic": "melee", "range": 2.8, "dot": 0.3, "cd": 0.38,
		"color": Color(0.3, 0.26, 0.24), "trim": Color(0.75, 0.55, 1.0),
	},
	"nautico": {
		"name": "Náutico", "desc": "Linha de frente com o poder das marés e a pressão da água.",
		"hp": 150, "mp": 90, "atk": 22.0, "speed": 7.3,
		"basic": "thrust", "range": 4.4, "dot": 0.85, "cd": 0.46,
		"color": Color(0.2, 0.35, 0.55), "trim": Color(0.45, 0.85, 1.0),
	},
	"mecanico": {
		"name": "Mecânico", "desc": "Engenharia de combate, barreiras tecnológicas e dano em área.",
		"hp": 125, "mp": 100, "atk": 20.0, "speed": 7.6,
		"basic": "arrow", "range": 0.0, "dot": 0.0, "cd": 0.36,
		"color": Color(0.45, 0.42, 0.38), "trim": Color(0.4, 0.8, 1.0),
	},
	"druida": {
		"name": "Druida", "desc": "Controle de grupo, cura e suporte da natureza.",
		"hp": 110, "mp": 150, "atk": 27.0, "speed": 7.0,
		"basic": "magic", "range": 0.0, "dot": 0.0, "cd": 0.6,
		"color": Color(0.35, 0.28, 0.2), "trim": Color(0.55, 1.0, 0.5),
	},
}

const CLASS_ORDER := ["druida", "assassino", "mecanico", "nautico"]
## Classes antigas (saves de versões anteriores) → classes novas.
const OLD_CLASS := {"guerreiro": "assassino", "lanceiro": "nautico", "arqueiro": "mecanico", "mago": "druida"}

## Skills das classes (conforme a lista do projeto). O efeito de cada "type" está em skills.gd.
## Passivas ("passive") não precisam ser usadas: funcionam sozinhas depois de aprendidas.
## Sem multiplayer ainda, efeitos de "aliados" valem para o próprio herói.
const SKILLS := {
	"druida": [
		{"id": "dr1", "name": "Chamado das Raízes", "type": "zone", "cd": 9.0, "mp": 18, "mult": 0.45, "r": 4.5, "range": 12.0, "ticks": 6, "every": 0.5, "stun": 0.6, "visual": "roots",
			"color": Color(0.55, 0.85, 0.3), "sfx": "sk_slam",
			"desc": "Vinhas brotam do solo e prendem os inimigos na área, causando {dmg} de dano a cada 0,5 s por 3 s."},
		{"id": "dr2", "name": "Bênção da Flora", "type": "heal_zone", "cd": 16.0, "mp": 22, "pct": 0.03, "pct_lv": 0.004, "r": 5.0, "ticks": 12, "every": 0.5, "dur": 6.0,
			"color": Color(0.5, 1.0, 0.55), "sfx": "sk_buff",
			"desc": "Cria uma área de cura que recupera {shield} da sua vida a cada 0,5 s por {dur} s."},
		{"id": "dr3", "name": "Espírito da Coruja", "type": "passive", "passive": "owl", "cd": 0.0, "mp": 0, "buff": 0.15, "buff_lv": 0.02,
			"color": Color(0.7, 0.55, 1.0), "sfx": "sk_buff",
			"desc": "Passiva: em combate você ganha {buff} de velocidade e a mana recarrega 3x mais rápido."},
		{"id": "dr4", "name": "Casca de Carvalho", "type": "guard", "cd": 18.0, "mp": 20, "buff": 0.5, "buff_lv": 0.03, "dur": 6.0,
			"color": Color(0.7, 0.5, 0.25), "sfx": "sk_shield",
			"desc": "Armadura de madeira elemental: reduz em {buff} todo o dano recebido por {dur} s."},
		{"id": "dr5", "name": "Fúria dos Ventos", "type": "projectile", "visual": "wind", "cd": 8.0, "mp": 18, "mult": 1.8, "speed": 26.0, "life": 0.8, "pierce": true, "knock": 3.5, "vuln": 0.25, "vuln_dur": 5.0,
			"color": Color(0.8, 1.0, 0.9), "sfx": "sk_dash",
			"desc": "Rajada de vento em linha reta: {dmg} de dano, empurra e quebra a defesa (+25% de dano recebido por 5 s)."},
		{"id": "dr6", "name": "Despertar Lendário", "type": "awaken", "cd": 30.0, "mp": 40, "mult": 2.0, "r": 10.0, "stun": 2.5, "buff": 0.3, "buff_lv": 0.03, "dur": 6.0,
			"color": Color(1.0, 0.85, 0.35), "sfx": "levelup",
			"desc": "Energia solar máxima: {dmg} de dano e cega (atordoa) os inimigos num raio de {r} m; você fica imune a controle e com +{buff} de dano por {dur} s."},
		{"id": "dr7", "name": "Granizo Ancestral", "type": "ice_fall", "cd": 11.0, "mp": 26, "mult": 0.9, "r": 4.5, "range": 14.0, "count": 9, "spread_t": 1.4, "hit_r": 2.2, "slow": 0.45, "slow_dur": 3.0,
			"color": Color(0.6, 0.9, 1.0), "sfx": "sk_ice",
			"desc": "Estacas de gelo caem do céu numa área de {r} m: cada uma causa {dmg} de dano e deixa os inimigos 45% mais lentos."},
		{"id": "dr8", "name": "Fúria do Trovão", "type": "storm_chain", "cd": 7.0, "mp": 22, "mult": 1.4, "range": 14.0, "hops": 6, "jump": 8.0, "stun": 0.3,
			"color": Color(0.65, 0.75, 1.0), "sfx": "sk_thunder",
			"desc": "Um raio cai do céu e salta de inimigo em inimigo, atingindo até {n}: {dmg} de dano no primeiro (um pouco menos a cada salto)."},
		{"id": "dr9", "name": "Chuva de Meteoros", "type": "meteor_rain", "cd": 22.0, "mp": 38, "mult": 1.2, "r": 6.0, "range": 16.0, "count": 8, "spread_t": 2.4, "blast": 3.0,
			"color": Color(1.0, 0.5, 0.15), "sfx": "sk_fire",
			"desc": "Meteoros em chamas caem numa área de {r} m durante 3 s: cada explosão causa {dmg} de dano."},
		{"id": "dr10", "name": "Pisão da Morte", "type": "fissure", "cd": 26.0, "mp": 42, "mult": 2.6, "r": 5.0, "stun": 1.0, "dur": 5.0, "every": 0.5, "burn": 0.35,
			"color": Color(1.0, 0.4, 0.1), "sfx": "sk_slam",
			"desc": "Pisa com tanta força que o chão se abre: {dmg} de dano e atordoa num raio de {r} m; a fenda pega fogo e queima quem ficar nela por {dur} s."},
	],
	"assassino": [
		{"id": "as1", "name": "Passo das Sombras", "type": "blink", "cd": 6.0, "mp": 10, "mult": 1.0, "range": 14.0,
			"color": Color(0.55, 0.3, 0.95), "sfx": "sk_dash",
			"desc": "Teleporta para trás do inimigo mais próximo. O próximo ataque é sempre crítico."},
		{"id": "as2", "name": "Adagas Envenenadas", "type": "poison_buff", "cd": 14.0, "mp": 14, "mult": 0.35, "dur": 10.0,
			"color": Color(0.45, 1.0, 0.35), "sfx": "sk_magic",
			"desc": "Por {dur} s seus golpes envenenam: {dmg} de dano por segundo durante 4 s e o alvo fica mais lento."},
		{"id": "as3", "name": "Camuflagem Sombria", "type": "stealth", "cd": 16.0, "mp": 15, "dur": 4.0,
			"color": Color(0.35, 0.3, 0.5), "sfx": "sk_dash",
			"desc": "Fica invisível por {dur} s: os inimigos perdem você. O primeiro ataque saindo da invisibilidade causa o dobro de dano."},
		{"id": "as4", "name": "Dança das Lâminas", "type": "spin_multi", "cd": 6.0, "mp": 14, "mult": 0.7, "r": 3.6, "hits": 4,
			"color": Color(0.8, 0.6, 1.0), "sfx": "sk_slash",
			"desc": "Sequência de 4 cortes giratórios ao seu redor: {dmg} de dano por corte (raio {r} m)."},
		{"id": "as5", "name": "Manto do Vazio", "type": "dodge", "cd": 12.0, "mp": 10, "dur": 10.0,
			"color": Color(0.2, 0.15, 0.25), "sfx": "sk_shield",
			"desc": "Desvia sozinho do próximo ataque recebido nos próximos {dur} s, deixando fumaça negra."},
		{"id": "as6", "name": "Execução Celestial", "type": "execute", "cd": 24.0, "mp": 35, "mult": 5.0, "r": 10.0,
			"color": Color(1.0, 0.82, 0.3), "sfx": "sk_slash",
			"desc": "Golpe fatal no inimigo com menos vida na área: {dmg} de dano. Se ele morrer, suas outras skills recarregam na hora."},
	],
	"mecanico": [
		{"id": "me1", "name": "Disparo de Chave", "type": "chain", "visual": "wrench", "cd": 4.0, "mp": 10, "mult": 1.2, "range": 12.0, "hops": 3, "stun": 0.5,
			"color": Color(1.0, 0.75, 0.3), "sfx": "hit",
			"desc": "Chave inglesa energizada que ricocheteia entre {n} inimigos: {dmg} de dano e atordoamento leve."},
		{"id": "me2", "name": "Torreta Automática", "type": "turret", "cd": 15.0, "mp": 22, "mult": 0.45, "range": 12.0, "dur": 12.0, "every": 0.5,
			"color": Color(0.4, 0.85, 1.0), "sfx": "click",
			"desc": "Instala uma torreta que atira sozinha nos inimigos próximos por {dur} s: {dmg} de dano por tiro."},
		{"id": "me3", "name": "Campo de Força Magnético", "type": "shield", "visual": "dome", "cd": 18.0, "mp": 22, "pct": 0.35, "pct_lv": 0.02, "dur": 8.0,
			"color": Color(0.4, 0.75, 1.0), "sfx": "sk_shield",
			"desc": "Cúpula de energia que bloqueia dano: absorve {shield} da sua vida por {dur} s."},
		{"id": "me4", "name": "Sobrecarga de Vapor", "type": "passive", "passive": "heat", "cd": 0.0, "mp": 0, "buff": 0.5, "buff_lv": 0.04,
			"color": Color(1.0, 0.55, 0.2), "sfx": "sk_buff",
			"desc": "Passiva: a cada 4 skills usadas o calor chega ao limite e seus ataques básicos ficam {buff} mais rápidos por 4 s."},
		{"id": "me5", "name": "Drone de Reparo", "type": "repair_drone", "cd": 18.0, "mp": 20, "pct": 0.025, "pct_lv": 0.004, "dur": 10.0,
			"color": Color(0.5, 1.0, 0.7), "sfx": "click",
			"desc": "Um drone voador te segue e repara {shield} da vida a cada 0,5 s por {dur} s, removendo lentidão."},
		{"id": "me6", "name": "Colosso de Ouro", "type": "colossus", "cd": 30.0, "mp": 40, "mult": 3.5, "r": 7.0, "buff": 0.4, "buff_lv": 0.02, "dur": 8.0,
			"color": Color(1.0, 0.8, 0.3), "sfx": "sk_slam",
			"desc": "Vira um colosso gigante por {dur} s ({buff} menos dano) e esmaga o chão: {dmg} de dano (raio {r} m)."},
	],
	"nautico": [
		{"id": "na1", "name": "Estocada do Tridente", "type": "thrust3", "hits": 1, "cd": 3.0, "mp": 8, "mult": 1.6, "range": 6.0, "knock": 3.0, "vuln": 0.2, "vuln_dur": 5.0,
			"color": Color(0.5, 0.9, 1.0), "sfx": "sk_slash",
			"desc": "Perfuração rápida à frente: {dmg} de dano, joga os inimigos para trás e reduz a armadura deles (+20% de dano recebido)."},
		{"id": "na2", "name": "Correnteza Fluvial", "type": "pull", "cd": 9.0, "mp": 16, "mult": 1.0, "r": 11.0,
			"color": Color(0.35, 0.75, 1.0), "sfx": "sk_ice",
			"desc": "Uma onda puxa os inimigos distantes para perto de você: {dmg} de dano (raio {r} m)."},
		{"id": "na3", "name": "Escudo de Conchas", "type": "shield", "visual": "shell", "burst": 1.8, "r": 4.5, "cd": 16.0, "mp": 20, "pct": 0.3, "pct_lv": 0.02, "dur": 8.0,
			"color": Color(0.5, 0.85, 1.0), "sfx": "sk_shield",
			"desc": "Barreira de água que absorve {shield} da sua vida em dano; ao quebrar, explode em gotas cortantes ao redor."},
		{"id": "na4", "name": "Presença Abissal", "type": "passive", "passive": "abyss", "cd": 0.0, "mp": 0, "buff": 0.35, "buff_lv": 0.03,
			"color": Color(0.2, 0.4, 0.8), "sfx": "sk_ice",
			"desc": "Passiva: inimigos que te atacam ficam {buff} mais lentos, como sob forte pressão da água."},
		{"id": "na5", "name": "Companheiro das Profundezas", "type": "companion", "cd": 20.0, "mp": 25, "mult": 0.6, "range": 7.0, "dur": 15.0, "every": 0.7,
			"color": Color(0.75, 0.6, 1.0), "sfx": "sk_magic",
			"desc": "Invoca uma água-viva elemental que ataca e distrai os inimigos por {dur} s: {dmg} de dano por choque."},
		{"id": "na6", "name": "Fúria de Poseidon", "type": "maelstrom", "cd": 26.0, "mp": 40, "mult": 0.55, "r": 7.0, "ticks": 8, "every": 0.4, "vuln": 0.25, "vuln_dur": 6.0,
			"color": Color(0.4, 0.85, 1.0), "sfx": "sk_thunder",
			"desc": "Redemoinho gigante ao seu redor: levanta os inimigos, causa {dmg} de dano por giro (8 giros) e os deixa vulneráveis."},
	],
}

## Inimigos do Vale (números feitos à mão). Os dos outros mapas usam a fórmula em enemy().
## style "melee" = mordida/pancada; "slam" = golpe em área com aviso no chão.
const BASE_ENEMIES := {
	"slime": {"name": "Slime", "model": "slime", "scale": 1.0, "hp": 45, "dmg": 7, "speed": 3.0, "level": 2,
		"xp": 24, "gold": Vector2i(1, 4), "radius": 0.6, "height": 0.6, "bar": 1.7, "range": 1.6, "atk_cd": 1.1, "style": "melee", "outline": 0.03},
	"slime_king": {"name": "Slime Rei", "model": "slime_king", "scale": 2.6, "hp": 900, "dmg": 24, "speed": 2.8, "level": 5,
		"xp": 600, "gold": Vector2i(60, 90), "radius": 1.5, "height": 1.4, "bar": 4.0, "range": 3.2, "atk_cd": 2.6, "style": "slam", "slam_r": 4.6, "boss": true, "outline": 0.02},
	"wolf": {"name": "Lobo", "model": "wolf", "scale": 0.85, "hp": 170, "dmg": 15, "speed": 5.2, "level": 7,
		"xp": 110, "gold": Vector2i(4, 10), "radius": 0.8, "height": 0.9, "bar": 2.4, "range": 2.0, "atk_cd": 1.2, "style": "melee", "outline": 0.035},
	"wolf_alpha": {"name": "Lobo Alfa", "model": "wolf_alpha", "scale": 1.7, "hp": 2600, "dmg": 38, "speed": 5.6, "level": 10,
		"xp": 2200, "gold": Vector2i(150, 240), "radius": 1.4, "height": 1.6, "bar": 4.2, "range": 3.0, "atk_cd": 2.4, "style": "slam", "slam_r": 5.0, "boss": true, "outline": 0.025},
	"golem_minion": {"name": "Golem de Pedra", "model": "golem", "scale": 0.55, "hp": 400, "dmg": 28, "speed": 2.8, "level": 12,
		"xp": 360, "gold": Vector2i(10, 24), "radius": 0.9, "height": 1.2, "bar": 2.9, "range": 2.4, "atk_cd": 1.6, "style": "melee", "outline": 0.06},
	"golem_boss": {"name": "Golem Guardião", "model": "golem", "scale": 1.15, "hp": 9000, "dmg": 70, "speed": 2.4, "level": 15,
		"xp": 7000, "gold": Vector2i(500, 800), "radius": 1.6, "height": 2.4, "bar": 5.4, "range": 3.6, "atk_cd": 2.6, "style": "slam", "slam_r": 5.5, "boss": true, "outline": 0.05},
}

## Inimigos dos mapas novos: vida, dano, XP e ouro saem da fórmula pelo nível (ver enemy()).
const MOBS := {
	"scorpion": {"name": "Escorpião", "model": "scorpion", "scale": 0.75, "level": 18, "speed": 4.2, "radius": 0.9, "height": 0.6, "bar": 1.9, "range": 2.2, "atk_cd": 1.2, "style": "melee", "outline": 0.035},
	"scorpion_queen": {"name": "Rainha Escorpião", "model": "scorpion_queen", "scale": 1.6, "level": 21, "speed": 4.0, "radius": 1.6, "height": 1.2, "bar": 3.2, "range": 3.2, "atk_cd": 2.4, "style": "slam", "slam_r": 5.0, "boss": true, "outline": 0.02},
	"skeleton": {"name": "Esqueleto", "model": "skeleton", "scale": 1.0, "level": 23, "speed": 3.6, "radius": 0.6, "height": 1.0, "bar": 2.6, "range": 2.0, "atk_cd": 1.1, "style": "melee", "outline": 0.03},
	"skeleton_king": {"name": "Rei Esqueleto", "model": "skeleton_king", "scale": 1.7, "level": 26, "speed": 3.4, "radius": 1.0, "height": 1.7, "bar": 4.2, "range": 3.0, "atk_cd": 2.4, "style": "slam", "slam_r": 5.0, "boss": true, "outline": 0.02},
	"golem_sand": {"name": "Golem de Areia", "model": "golem_sand", "scale": 0.6, "level": 28, "speed": 2.8, "radius": 0.9, "height": 1.3, "bar": 3.0, "range": 2.4, "atk_cd": 1.6, "style": "melee", "outline": 0.06},
	"golem_sand_boss": {"name": "Colosso de Areia", "model": "golem_sand", "scale": 1.25, "level": 31, "speed": 2.4, "radius": 1.7, "height": 2.6, "bar": 5.8, "range": 3.6, "atk_cd": 2.6, "style": "slam", "slam_r": 5.8, "boss": true, "outline": 0.05},
	"wolf_ice": {"name": "Lobo de Gelo", "model": "wolf_ice", "scale": 0.9, "level": 33, "speed": 5.4, "radius": 0.8, "height": 0.9, "bar": 2.4, "range": 2.0, "atk_cd": 1.2, "style": "melee", "outline": 0.035},
	"wolf_glacial": {"name": "Lobo Glacial", "model": "wolf_glacial", "scale": 1.8, "level": 36, "speed": 5.6, "radius": 1.4, "height": 1.6, "bar": 4.2, "range": 3.0, "atk_cd": 2.4, "style": "slam", "slam_r": 5.2, "boss": true, "outline": 0.025},
	"yeti": {"name": "Yeti", "model": "yeti", "scale": 0.8, "level": 38, "speed": 3.4, "radius": 1.0, "height": 1.4, "bar": 3.2, "range": 2.6, "atk_cd": 1.5, "style": "melee", "outline": 0.035},
	"yeti_ancient": {"name": "Yeti Ancião", "model": "yeti_ancient", "scale": 1.4, "level": 41, "speed": 3.2, "radius": 1.6, "height": 2.4, "bar": 4.8, "range": 3.4, "atk_cd": 2.5, "style": "slam", "slam_r": 5.6, "boss": true, "outline": 0.025},
	"golem_ice": {"name": "Golem de Gelo", "model": "golem_ice", "scale": 0.6, "level": 43, "speed": 2.8, "radius": 0.9, "height": 1.3, "bar": 3.0, "range": 2.4, "atk_cd": 1.6, "style": "melee", "outline": 0.06},
	"golem_ice_boss": {"name": "Golem de Cristal", "model": "golem_ice", "scale": 1.25, "level": 46, "speed": 2.4, "radius": 1.7, "height": 2.6, "bar": 5.8, "range": 3.6, "atk_cd": 2.6, "style": "slam", "slam_r": 5.8, "boss": true, "outline": 0.05},
	"imp": {"name": "Diabrete", "model": "imp", "scale": 0.8, "level": 48, "speed": 4.6, "radius": 0.7, "height": 1.2, "bar": 2.6, "range": 2.0, "atk_cd": 1.0, "style": "melee", "outline": 0.035},
	"imp_lord": {"name": "Senhor dos Diabretes", "model": "imp_lord", "scale": 1.6, "level": 51, "speed": 4.2, "radius": 1.2, "height": 2.0, "bar": 4.4, "range": 3.0, "atk_cd": 2.3, "style": "slam", "slam_r": 5.2, "boss": true, "outline": 0.02},
	"golem_magma": {"name": "Golem de Magma", "model": "golem_magma", "scale": 0.6, "level": 53, "speed": 2.8, "radius": 0.9, "height": 1.3, "bar": 3.0, "range": 2.4, "atk_cd": 1.6, "style": "melee", "outline": 0.06},
	"golem_magma_boss": {"name": "Titã de Magma", "model": "golem_magma", "scale": 1.3, "level": 56, "speed": 2.4, "radius": 1.8, "height": 2.7, "bar": 6.0, "range": 3.8, "atk_cd": 2.6, "style": "slam", "slam_r": 6.0, "boss": true, "outline": 0.05},
	"dragon_whelp": {"name": "Dragão Filhote", "model": "dragon_whelp", "scale": 0.7, "level": 58, "speed": 4.0, "radius": 1.3, "height": 1.4, "bar": 3.4, "range": 3.0, "atk_cd": 1.6, "style": "melee", "outline": 0.035},
	"dragon_ancient": {"name": "Dragão Ancestral", "model": "dragon_ancient", "scale": 1.7, "level": 62, "speed": 3.6, "radius": 2.6, "height": 3.0, "bar": 7.0, "range": 4.6, "atk_cd": 2.6, "style": "slam", "slam_r": 6.8, "boss": true, "outline": 0.02},
}

static var _enemy_cache := {}


## Dados completos de um inimigo (vida, dano, XP e ouro calculados pelo nível nos mapas novos).
static func enemy(id: String) -> Dictionary:
	if BASE_ENEMIES.has(id):
		return BASE_ENEMIES[id]
	if _enemy_cache.has(id):
		return _enemy_cache[id]
	var d: Dictionary = MOBS[id].duplicate()
	var L := float(d["level"])
	var boss := bool(d.get("boss", false))
	d["hp"] = int((10.0 * pow(L, 1.5) + 40.0) * (6.0 if boss else 1.0))
	d["dmg"] = int((4.0 + 1.3 * pow(L, 1.15)) * (2.2 if boss else 1.0))
	d["xp"] = int(10.0 * pow(L, 1.55) * (15.0 if boss else 1.0))
	d["gold"] = Vector2i(int(L), int(L * 3.0)) * (20 if boss else 1)
	_enemy_cache[id] = d
	return d


## Mapas. Cada mapa tem 3 zonas de caça (cada uma com um chefe) e um acampamento com NPC, portal e quadro de missões.
const MAPS := {
	"vale": {"name": "Vale das Lendas", "levels": "Nv 1-15", "min_level": 1, "hub": "Vila Aurora", "hub_style": "vila",
		"npc": "Ancião Bóris", "npc_model": "npc_elder", "music": "music_field", "zones": ["campo", "floresta", "ruinas"],
		"lake": {"c": Vector2(-56, 44), "r": Vector2(16, 11), "type": "water"},
		"regions": [{"type": "forest", "c": Vector2(-60, -44), "r": 40.0}, {"type": "open", "c": Vector2(58, 32), "r": 15.0}, {"type": "stone", "c": Vector2(48, -58), "r": 21.0}],
		"theme": {"ground": "grass", "path": "dirt", "ground_tint": Color(0.46, 0.6, 0.54), "forest_tint": Color(0.42, 0.55, 0.66), "path_tint": Color(0.74, 0.6, 0.52), "stone_tint": Color(0.55, 0.56, 0.64),
			"trees": {"tree_a": 0.42, "tree_b": 0.38, "tree_c": 0.2}, "forest_trees": {"tree_pine": 0.6, "tree_a": 0.4}, "tree_keep": 0.16, "forest_keep": 0.75,
			"grass": Color(0.5, 0.68, 0.52), "forest_grass": Color(0.36, 0.56, 0.58), "grass_count": 22000, "flowers": 5000,
			"props": {"bush_a": 0.3, "bush_b": 0.2, "rock_a": 0.15, "rock_b": 0.15}, "forest_props": {"mushroom": 1.0}, "glow_prop": "mushroom", "glow_color": Color(0.3, 1.0, 0.9),
			"sun": Color(1.0, 0.7, 0.52), "sun_energy": 1.0, "ambient": Color(0.4, 0.42, 0.68), "ambient_energy": 0.62, "lava": 0.0, "houses": ["house_a", "house_b"]}},
	"deserto": {"name": "Deserto Escarlate", "levels": "Nv 16-30", "min_level": 15, "hub": "Acampamento Miragem", "hub_style": "tendas",
		"npc": "Nômade Zara", "npc_model": "npc_desert", "music": "music_desert", "zones": ["dunas", "cemiterio", "templo"],
		"lake": {"c": Vector2(-50, -46), "r": Vector2(13, 9), "type": "oasis"},
		"regions": [{"type": "forest", "c": Vector2(-50, -46), "r": 24.0}, {"type": "stone", "c": Vector2(8, 72), "r": 20.0}, {"type": "stone", "c": Vector2(-56, 36), "r": 13.0}],
		"theme": {"ground": "sand", "path": "dirt", "ground_tint": Color(0.86, 0.72, 0.62), "forest_tint": Color(0.75, 0.85, 0.7), "path_tint": Color(0.6, 0.46, 0.4), "stone_tint": Color(0.82, 0.7, 0.58),
			"trees": {"cactus_a": 0.5, "cactus_b": 0.35, "dead_tree": 0.15}, "forest_trees": {"palm": 1.0}, "tree_keep": 0.07, "forest_keep": 0.55,
			"grass": Color(0.8, 0.66, 0.38), "forest_grass": Color(0.45, 0.65, 0.35), "grass_count": 6000, "flowers": 0,
			"props": {"rock_a": 0.4, "rock_b": 0.3, "bones": 0.3}, "forest_props": {"bush_a": 1.0}, "glow_prop": "sand_crystal", "glow_color": Color(0.4, 1.0, 0.85),
			"sun": Color(1.0, 0.72, 0.5), "sun_energy": 1.15, "ambient": Color(0.55, 0.42, 0.52), "ambient_energy": 0.6, "lava": 0.0, "houses": ["tent", "tent"]}},
	"gelo": {"name": "Picos Gelados", "levels": "Nv 31-45", "min_level": 30, "hub": "Refúgio do Norte", "hub_style": "cabanas",
		"npc": "Guardiã Freya", "npc_model": "npc_ice", "music": "music_snow", "zones": ["tundra", "cavernas", "glaciar"],
		"lake": {"c": Vector2(56, -30), "r": Vector2(15, 10), "type": "ice"},
		"regions": [{"type": "forest", "c": Vector2(-42, 42), "r": 36.0}, {"type": "stone", "c": Vector2(20, -72), "r": 20.0}],
		"theme": {"ground": "snow", "path": "dirt", "ground_tint": Color(0.82, 0.86, 0.95), "forest_tint": Color(0.7, 0.78, 0.9), "path_tint": Color(0.55, 0.52, 0.55), "stone_tint": Color(0.6, 0.72, 0.85),
			"trees": {"pine_snow": 0.7, "dead_tree_frost": 0.3}, "forest_trees": {"pine_snow": 1.0}, "tree_keep": 0.14, "forest_keep": 0.8,
			"grass": Color(0.75, 0.85, 0.95), "forest_grass": Color(0.6, 0.75, 0.8), "grass_count": 0, "flowers": 0,
			"props": {"rock_a": 0.5, "rock_b": 0.5}, "forest_props": {"ice_crystal": 1.0}, "glow_prop": "ice_crystal", "glow_color": Color(0.5, 0.85, 1.0),
			"sun": Color(0.85, 0.9, 1.0), "sun_energy": 1.0, "ambient": Color(0.45, 0.55, 0.82), "ambient_energy": 0.72, "lava": 0.0, "houses": ["house_snow", "house_snow"]}},
	"vulcao": {"name": "Abismo Vulcânico", "levels": "Nv 46-60", "min_level": 45, "hub": "Fortaleza de Obsidiana", "hub_style": "fortaleza",
		"npc": "Ferreiro Vulcan", "npc_model": "npc_volcano", "music": "music_volcano", "zones": ["fendas", "forja", "ninho"],
		"lake": {"c": Vector2(46, -50), "r": Vector2(17, 12), "type": "lava"},
		"regions": [{"type": "forest", "c": Vector2(52, 52), "r": 26.0}, {"type": "stone", "c": Vector2(-50, -50), "r": 20.0}, {"type": "stone", "c": Vector2(-30, 66), "r": 16.0}],
		"theme": {"ground": "ash", "path": "stone", "ground_tint": Color(0.85, 0.75, 0.75), "forest_tint": Color(0.8, 0.6, 0.6), "path_tint": Color(0.5, 0.42, 0.42), "stone_tint": Color(0.45, 0.35, 0.38),
			"trees": {"dead_tree_burnt": 1.0}, "forest_trees": {"dead_tree_burnt": 1.0}, "tree_keep": 0.08, "forest_keep": 0.45,
			"grass": Color(0, 0, 0), "forest_grass": Color(0, 0, 0), "grass_count": 0, "flowers": 0,
			"props": {"rock_a": 0.5, "rock_b": 0.3, "bones": 0.2}, "forest_props": {"fire_crystal": 1.0}, "glow_prop": "fire_crystal", "glow_color": Color(1.0, 0.4, 0.1),
			"sun": Color(1.0, 0.45, 0.3), "sun_energy": 0.8, "ambient": Color(0.48, 0.28, 0.38), "ambient_energy": 0.62, "lava": 1.0, "houses": ["house_dark", "house_dark"]}},
}

const MAP_ORDER := ["vale", "deserto", "gelo", "vulcao"]

## Zonas de caça. "center" e "boss_pos" ficam nas pontas das trilhas.
const ZONES := {
	"campo": {"map": "vale", "name": "Campo das Flores", "levels": "Nv 1-5", "lvl": Vector2i(1, 5), "center": Vector3(58, 0, 32), "radius": 17.0,
		"enemy": "slime", "boss": "slime_king", "count": 12, "boss_pos": Vector3(70, 0, 42), "color": Color(0.55, 0.85, 0.45)},
	"floresta": {"map": "vale", "name": "Floresta Sombria", "levels": "Nv 6-10", "lvl": Vector2i(6, 10), "center": Vector3(-58, 0, -40), "radius": 18.0,
		"enemy": "wolf", "boss": "wolf_alpha", "count": 10, "boss_pos": Vector3(-70, 0, -52), "color": Color(0.35, 0.7, 0.75)},
	"ruinas": {"map": "vale", "name": "Ruínas Antigas", "levels": "Nv 11-15", "lvl": Vector2i(11, 15), "center": Vector3(48, 0, -58), "radius": 16.0,
		"enemy": "golem_minion", "boss": "golem_boss", "count": 8, "boss_pos": Vector3(60, 0, -72), "color": Color(0.6, 0.65, 0.75)},
	"dunas": {"map": "deserto", "name": "Dunas Ferventes", "levels": "Nv 16-20", "lvl": Vector2i(16, 20), "center": Vector3(62, 0, -20), "radius": 17.0,
		"enemy": "scorpion", "boss": "scorpion_queen", "count": 12, "boss_pos": Vector3(78, 0, -30), "color": Color(0.9, 0.6, 0.3)},
	"cemiterio": {"map": "deserto", "name": "Cemitério de Areia", "levels": "Nv 21-25", "lvl": Vector2i(21, 25), "center": Vector3(-56, 0, 36), "radius": 16.0,
		"enemy": "skeleton", "boss": "skeleton_king", "count": 11, "boss_pos": Vector3(-72, 0, 48), "color": Color(0.8, 0.75, 0.6)},
	"templo": {"map": "deserto", "name": "Templo Soterrado", "levels": "Nv 26-30", "lvl": Vector2i(26, 30), "center": Vector3(8, 0, 66), "radius": 16.0,
		"enemy": "golem_sand", "boss": "golem_sand_boss", "count": 9, "boss_pos": Vector3(10, 0, 84), "color": Color(0.85, 0.7, 0.45)},
	"tundra": {"map": "gelo", "name": "Tundra Uivante", "levels": "Nv 31-35", "lvl": Vector2i(31, 35), "center": Vector3(-60, 0, -20), "radius": 17.0,
		"enemy": "wolf_ice", "boss": "wolf_glacial", "count": 11, "boss_pos": Vector3(-78, 0, -28), "color": Color(0.7, 0.85, 1.0)},
	"cavernas": {"map": "gelo", "name": "Cavernas dos Yetis", "levels": "Nv 36-40", "lvl": Vector2i(36, 40), "center": Vector3(56, 0, 44), "radius": 17.0,
		"enemy": "yeti", "boss": "yeti_ancient", "count": 9, "boss_pos": Vector3(72, 0, 56), "color": Color(0.6, 0.75, 0.95)},
	"glaciar": {"map": "gelo", "name": "Glaciar de Cristal", "levels": "Nv 41-45", "lvl": Vector2i(41, 45), "center": Vector3(20, 0, -66), "radius": 16.0,
		"enemy": "golem_ice", "boss": "golem_ice_boss", "count": 9, "boss_pos": Vector3(24, 0, -84), "color": Color(0.55, 0.9, 1.0)},
	"fendas": {"map": "vulcao", "name": "Fendas Ardentes", "levels": "Nv 46-50", "lvl": Vector2i(46, 50), "center": Vector3(62, 0, 18), "radius": 17.0,
		"enemy": "imp", "boss": "imp_lord", "count": 11, "boss_pos": Vector3(78, 0, 24), "color": Color(1.0, 0.45, 0.3)},
	"forja": {"map": "vulcao", "name": "Forja de Magma", "levels": "Nv 51-55", "lvl": Vector2i(51, 55), "center": Vector3(-50, 0, -50), "radius": 16.0,
		"enemy": "golem_magma", "boss": "golem_magma_boss", "count": 9, "boss_pos": Vector3(-64, 0, -66), "color": Color(1.0, 0.5, 0.1)},
	"ninho": {"map": "vulcao", "name": "Ninho do Dragão", "levels": "Nv 56-60", "lvl": Vector2i(56, 60), "center": Vector3(-30, 0, 62), "radius": 16.0,
		"enemy": "dragon_whelp", "boss": "dragon_ancient", "count": 8, "boss_pos": Vector3(-36, 0, 82), "color": Color(0.9, 0.3, 0.2)},
}

## Missões de história (em ordem). O NPC de cada mapa entrega as missões do seu mapa.
const QUESTS := [
	{"id": "q1", "title": "Praga no Campo", "zone": "campo", "count": 10, "min_level": 1, "xp": 450, "gold": 120,
		"text": "Viajante! Os slimes tomaram o Campo das Flores, a leste da vila. Derrote 10 deles e o Slime Rei vai aparecer. Acabe com ele e volte aqui."},
	{"id": "q2", "title": "Uivos na Floresta", "zone": "floresta", "count": 12, "min_level": 4, "xp": 2600, "gold": 400,
		"text": "Os lobos da Floresta Sombria, a noroeste, estão atacando os viajantes. Derrote 12 lobos e enfrente o Lobo Alfa."},
	{"id": "q3", "title": "O Guardião das Ruínas", "zone": "ruinas", "count": 10, "min_level": 8, "xp": 9000, "gold": 1200,
		"text": "Algo despertou nas Ruínas Antigas, ao norte. Destrua 10 golens de pedra e derrote o Golem Guardião antes que ele chegue à vila."},
	{"id": "q4", "title": "Ferrões nas Dunas", "zone": "dunas", "count": 12, "min_level": 15, "xp": 30000, "gold": 2500,
		"text": "Bem-vindo ao Deserto Escarlate. Escorpiões gigantes cercam as Dunas Ferventes. Derrote 12 e a Rainha Escorpião sairá da toca."},
	{"id": "q5", "title": "O Cemitério de Areia", "zone": "cemiterio", "count": 12, "min_level": 20, "xp": 60000, "gold": 3500,
		"text": "Os mortos se levantaram no Cemitério de Areia. Derrube 12 esqueletos e enfrente o Rei Esqueleto."},
	{"id": "q6", "title": "O Colosso Soterrado", "zone": "templo", "count": 10, "min_level": 25, "xp": 110000, "gold": 5000,
		"text": "O Templo Soterrado acordou. Destrua 10 golens de areia e derrote o Colosso que guarda o templo."},
	{"id": "q7", "title": "Uivos Gelados", "zone": "tundra", "count": 12, "min_level": 30, "xp": 300000, "gold": 8000,
		"text": "Nos Picos Gelados, matilhas de lobos de gelo vagam pela tundra. Derrote 12 e o Lobo Glacial virá atrás de você."},
	{"id": "q8", "title": "A Fúria dos Yetis", "zone": "cavernas", "count": 10, "min_level": 35, "xp": 420000, "gold": 11000,
		"text": "Os yetis desceram das cavernas e estão destruindo as trilhas. Derrote 10 yetis e o Yeti Ancião."},
	{"id": "q9", "title": "O Coração de Cristal", "zone": "glaciar", "count": 10, "min_level": 40, "xp": 560000, "gold": 15000,
		"text": "No Glaciar de Cristal, golens de gelo protegem um coração mágico. Destrua 10 golens e o Golem de Cristal."},
	{"id": "q10", "title": "A Praga dos Diabretes", "zone": "fendas", "count": 12, "min_level": 45, "xp": 750000, "gold": 20000,
		"text": "O Abismo Vulcânico está infestado de diabretes. Derrote 12 deles e enfrente o Senhor dos Diabretes."},
	{"id": "q11", "title": "A Forja de Magma", "zone": "forja", "count": 10, "min_level": 50, "xp": 950000, "gold": 26000,
		"text": "Golens de magma tomaram a antiga forja. Destrua 10 golens e derrote o Titã de Magma."},
	{"id": "q12", "title": "O Dragão Ancestral", "zone": "ninho", "count": 10, "min_level": 55, "xp": 1200000, "gold": 40000,
		"text": "O último desafio: o Ninho do Dragão. Derrote 10 dragões filhotes e enfrente o Dragão Ancestral para salvar o reino."},
]


static func quest_kill(q: Dictionary) -> String:
	return String(ZONES[q["zone"]]["enemy"])


static func quest_boss(q: Dictionary) -> String:
	return String(ZONES[q["zone"]]["boss"])


static func quest_map(q: Dictionary) -> String:
	return String(ZONES[q["zone"]]["map"])


# =================================================================== experiência

## XP base para passar do nível L para o L+1.
static func xp_need(level: int) -> int:
	return int(round(60.0 * pow(float(level), 1.75)))


## A partir do nível 31, todo XP ganho vale 10 vezes menos (subir fica bem mais demorado).
static func xp_gain_mult(level: int) -> float:
	return 1.0 if level <= 30 else 0.1


# =================================================================== equipamentos e raridades

const RARITIES := ["comum", "rara", "epica", "lendaria"]
const RARITY := {
	"comum": {"name": "Comum", "color": Color(0.82, 0.82, 0.82), "atk": 1.0, "hp": 1.0, "def": 0.0},
	"rara": {"name": "Rara", "color": Color(0.35, 0.62, 1.0), "atk": 1.25, "hp": 1.2, "def": 0.06},
	"epica": {"name": "Épica", "color": Color(0.72, 0.42, 1.0), "atk": 1.6, "hp": 1.5, "def": 0.12},
	"lendaria": {"name": "Lendária", "color": Color(1.0, 0.76, 0.26), "atk": 2.2, "hp": 2.0, "def": 0.2},
}
const GEAR_NAMES := {
	"assassino": {"weapon": ["Adagas de Ferro", "Adagas da Lua Azul", "Lâminas do Vazio", "Adagas do Sol Dourado"],
		"armor": ["Capuz de Viajante", "Manto Noturno", "Armadura das Sombras", "Armadura do Dragão Dourado"]},
	"nautico": {"weapon": ["Arpão de Pescador", "Tridente das Marés", "Tridente da Tempestade", "Tridente de Poseidon"],
		"armor": ["Camisa Listrada", "Colete do Capitão", "Armadura do Abismo", "Armadura do Rei dos Mares"]},
	"mecanico": {"weapon": ["Chave Inglesa", "Chave Elétrica", "Garra de Plasma", "Canhão de Engrenagens"],
		"armor": ["Macacão de Oficina", "Avental do Inventor", "Traje Robótico", "Armadura Mecânica Dourada"]},
	"druida": {"weapon": ["Cajado de Galho", "Cajado das Runas", "Cajado do Bosque Sombrio", "Cajado do Sol Eterno"],
		"armor": ["Túnica de Linho", "Manto do Andarilho", "Armadura de Folhas", "Armadura do Cervo Dourado"]},
}
## Chance de cair equipamento (escasso de propósito) e chance de cada raridade quando cai.
const DROP_CHANCE := {"mob": 0.03, "boss": 0.5}
const DROP_RARITY := {"mob": [0.78, 0.18, 0.035, 0.005], "boss": [0.0, 0.6, 0.32, 0.08], "chest": [0.55, 0.33, 0.1, 0.02]}


static func item_name(item: Dictionary) -> String:
	var idx := RARITIES.find(String(item["rarity"]))
	return String(GEAR_NAMES[item["cls"]][item["slot"]][idx])


static func roll_rarity(table: String) -> String:
	var r := randf()
	var acc := 0.0
	var probs: Array = DROP_RARITY[table]
	for i in probs.size():
		acc += float(probs[i])
		if r < acc:
			return RARITIES[i]
	return RARITIES[0]


# =================================================================== missões repetíveis

## Limites: diárias 30 por dia; semanais 150 por semana (podem ser feitas todas de uma vez);
## mensais 900 por mês, liberadas 30 por dia (acumulam os dias passados, não dá para adiantar).
const MISSION_KINDS := ["diaria", "semanal", "mensal"]
const MISSION := {
	"diaria": {"name": "Diárias", "limit": 30, "kills": 5, "xp_frac": 0.05, "gold": 1.0, "chest": 0.02, "color": Color(0.55, 0.85, 0.45)},
	"semanal": {"name": "Semanais", "limit": 150, "kills": 8, "xp_frac": 0.08, "gold": 1.6, "chest": 0.05, "color": Color(0.4, 0.7, 1.0)},
	"mensal": {"name": "Mensais", "limit": 900, "per_day": 30, "kills": 10, "xp_frac": 0.12, "gold": 2.2, "chest": 0.08, "color": Color(1.0, 0.72, 0.3)},
}
