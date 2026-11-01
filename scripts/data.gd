class_name GameData
extends RefCounted
## Todos os números do jogo num lugar só: classes, skills, inimigos, zonas e missões.
## Para balancear, mude aqui.

const MAX_LEVEL := 1000
## Último nível dos 4 mapas feitos à mão; depois dele vêm os mapas gerados (ver _static_init / _gen_maps).
const BASE_MAX_LEVEL := 60
## Menu de administrador (F1). Troque para false antes de lançar o jogo para os jogadores.
## Menu de administrador (F1) e mana extra de teste: ligados no editor/versão de teste e DESLIGADOS sozinhos no
## executável final (exportado como "release"). Para forçar desligado também nos testes, troque FORCE_RELEASE.
const FORCE_RELEASE := false
## Multiplicadores ligados pelo painel admin (servidor manda em Net._config).
static var XP_MULT := 1.0
static var GOLD_MULT := 1.0
static var DROP_MULT := 1.0
static var ADMIN_ENABLED: bool = OS.is_debug_build() and not FORCE_RELEASE
## Mana extra por segundo só para testes (todas as classes); 0 no jogo final.
static var TEST_MP_REGEN: float = 25.0 if (OS.is_debug_build() and not FORCE_RELEASE) else 0.0
## Recarga normal de mana por segundo: fixa + porcentagem da mana máxima.
const MP_REGEN_FLAT := 4.0
const MP_REGEN_PCT := 0.04
const MAX_SKILL_LEVEL := 10
## Nível do personagem necessário para aprender cada skill (até 10 por classe; teclas 1-9 e 0).
const SKILL_UNLOCK := [1, 3, 6, 10, 15, 20, 25, 30, 40, 50, 60, 70]
const MAX_SKILLS := 12
## Tecla de cada skill (a 11ª e a 12ª ficam no - e no =).
const SKILL_KEYS := ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "="]
## Multiplicador da área (raio "r") de todas as skills.
const AREA_MULT := 1.4

const CLASSES := {
	"assassino": {
		"name": "Assassino", "desc": "Alta mobilidade, dano crítico massivo e furtividade.",
		"hp": 160, "mp": 130, "atk": 25.0, "speed": 7.6,
		"basic": "melee", "range": 2.8, "dot": 0.3, "cd": 0.38, "skill_power": 1.17,
		"color": Color(0.3, 0.26, 0.24), "trim": Color(0.75, 0.55, 1.0),
	},
	"nautico": {
		"name": "Náutico", "desc": "Linha de frente com o poder das marés e a pressão da água.",
		"hp": 150, "mp": 140, "atk": 22.0, "speed": 7.3,
		"basic": "thrust", "range": 4.4, "dot": 0.85, "cd": 0.46, "skill_power": 1.4,
		"color": Color(0.2, 0.35, 0.55), "trim": Color(0.45, 0.85, 1.0),
	},
	"mecanico": {
		"name": "Mecânico", "desc": "Engenharia de combate, barreiras tecnológicas e dano em área.",
		"hp": 125, "mp": 150, "atk": 20.0, "speed": 7.6,
		"basic": "arrow", "range": 0.0, "dot": 0.0, "cd": 0.36,
		"color": Color(0.45, 0.42, 0.38), "trim": Color(0.4, 0.8, 1.0),
	},
	## Lanceiro: modelo inteiro feito por IA ("model"; tools/ai_rig.py) com o esqueleto e as animações do Náutico;
	## a lança é um modelo à parte ("weapon_model", tools/ai_weapon.py) presa no nó Weapon da mão.
	"lanceiro": {
		"name": "Lanceiro", "desc": "Cavaleiro de Vyndara: alcance longo, saltos e estocadas que atravessam fileiras.",
		"hp": 145, "mp": 130, "atk": 23.0, "speed": 7.5,
		"basic": "thrust", "basic_hits": 2, "range": 4.2, "dot": 0.85, "cd": 0.44, "skill_power": 1.2,
		"color": Color(0.22, 0.3, 0.45), "trim": Color(0.5, 0.75, 1.0), "model": "hero_lanceiro_ia",
		"weapon_model": "weapon_lanceiro_ia",
	},
	## Mago, Guerreiro e Arqueira: modelos de IA como o Lanceiro (Mago/Arqueira com a base da Druida, Guerreiro com a do Náutico).
	"mago": {
		"name": "Mago", "desc": "Mestre arcano: dano em área enorme à distância, gelo, raios e fogo.",
		"hp": 105, "mp": 170, "atk": 24.0, "speed": 7.2,
		"basic": "magic", "range": 0.0, "dot": 0.0, "cd": 0.55, "skill_power": 1.15,
		"color": Color(0.3, 0.3, 0.5), "trim": Color(0.6, 0.7, 1.0), "model": "hero_mago_ia", "weapon_model": "weapon_mago_ia",
	},
	"guerreiro": {
		"name": "Guerreiro", "desc": "Cavaleiro do Dragão: espada e escudo, muita vida e golpes em área.",
		"hp": 170, "mp": 110, "atk": 21.0, "speed": 7.3,
		"basic": "melee", "basic_fx": "crescent", "range": 3.2, "dot": 0.3, "cd": 0.42, "skill_power": 1.3,
		"color": Color(0.32, 0.3, 0.28), "trim": Color(0.6, 0.85, 1.0), "model": "hero_guerreiro_ia", "weapon_model": "weapon_guerreiro_ia",
	},
	"arqueira": {
		"name": "Arqueira", "desc": "Caçadora da floresta: flechas rápidas, armadilhas e muita mobilidade.",
		"hp": 115, "mp": 140, "atk": 22.0, "speed": 8.0,
		"basic": "bow", "range": 0.0, "dot": 0.0, "cd": 0.38, "skill_power": 1.15,
		"color": Color(0.4, 0.32, 0.22), "trim": Color(0.95, 0.85, 0.5), "model": "hero_arqueira_ia", "weapon_model": "weapon_arqueira_ia",
	},
	"druida": {
		"name": "Druida", "desc": "Controle de grupo, cura e suporte da natureza.",
		"hp": 110, "mp": 220, "atk": 27.0, "speed": 7.0,
		"basic": "magic", "range": 0.0, "dot": 0.0, "cd": 0.6,
		"color": Color(0.35, 0.28, 0.2), "trim": Color(0.55, 1.0, 0.5),
	},
}

## Só estes 4 são jogáveis. Druida/Assassino/Mecânico/Náutico continuam nos dados (modelos e animações dos heróis de IA
## vêm deles), mas saves dessas classes viram as novas pelo OLD_CLASS.
const CLASS_ORDER := ["guerreiro", "lanceiro", "mago", "arqueira"]
## Classes antigas (saves de versões anteriores) → classes novas.
const OLD_CLASS := {"arqueiro": "arqueira", "druida": "mago", "assassino": "arqueira", "mecanico": "guerreiro", "nautico": "lanceiro"}

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
		{"id": "as7", "name": "Leque de Adagas", "type": "dagger_fan", "cd": 7.0, "mp": 18, "mult": 1.1, "count": 7, "spread": 1.1, "speed": 30.0, "life": 0.6, "vuln": 0.15, "vuln_dur": 4.0,
			"color": Color(0.65, 0.4, 1.0), "sfx": "sk_slash",
			"desc": "Arremessa 7 adagas espectrais em leque que atravessam os inimigos: {dmg} de dano cada e +15% de dano recebido por 4 s."},
		{"id": "as8", "name": "Marca da Morte", "type": "death_mark", "cd": 12.0, "mp": 24, "mult": 3.2, "r": 3.5, "range": 14.0, "delay": 1.5,
			"color": Color(0.7, 0.25, 1.0), "sfx": "sk_magic",
			"desc": "Marca o inimigo mais perto da mira; depois de 1,5 s a marca explode em sombras: {dmg} de dano nele e em quem estiver num raio de {r} m."},
		{"id": "as9", "name": "Clones das Sombras", "type": "shadow_clones", "cd": 18.0, "mp": 30, "mult": 1.8, "range": 12.0, "count": 3,
			"color": Color(0.5, 0.25, 0.9), "sfx": "sk_dash",
			"desc": "Três clones feitos de sombra saltam nos inimigos próximos e cortam: {dmg} de dano por clone."},
		{"id": "as10", "name": "Eclipse Sangrento", "type": "eclipse", "cd": 28.0, "mp": 45, "mult": 0.8, "r": 6.0, "dur": 2.5, "every": 0.2, "final": 3.0,
			"color": Color(0.9, 0.1, 0.15), "sfx": "sk_slash",
			"desc": "Cobre a área com uma cúpula de escuridão por {dur} s: cortes vermelhos atingem todos lá dentro ({dmg} cada) e no fim tudo explode."},
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
		{"id": "me7", "name": "Enxame de Mísseis", "type": "missiles", "cd": 9.0, "mp": 24, "mult": 0.9, "count": 6, "blast": 2.2, "speed": 18.0,
			"color": Color(1.0, 0.6, 0.25), "sfx": "arrow",
			"desc": "Dispara 6 mini-mísseis teleguiados que perseguem os inimigos e explodem: {dmg} de dano por míssil."},
		{"id": "me8", "name": "Lança-Chamas a Vapor", "type": "flamethrower", "cd": 10.0, "mp": 26, "mult": 0.45, "len": 7.0, "half": 0.38, "dur": 1.6, "every": 0.2,
			"color": Color(1.0, 0.5, 0.15), "sfx": "sk_fire",
			"desc": "Jato de fogo contínuo à frente por {dur} s: {dmg} de dano a cada 0,2 s em quem estiver no cone."},
		{"id": "me9", "name": "Bombardeio Orbital", "type": "orbital", "cd": 24.0, "mp": 40, "mult": 0.7, "r": 4.0, "range": 16.0, "delay": 1.0, "dur": 1.4, "every": 0.2,
			"color": Color(0.45, 0.8, 1.0), "sfx": "sk_thunder",
			"desc": "Chama um satélite: depois de 1 s um feixe de energia cai do céu e queima a área ({r} m) por {dur} s, {dmg} de dano a cada 0,2 s."},
		{"id": "me10", "name": "Torre Tesla", "type": "tesla", "cd": 26.0, "mp": 42, "mult": 0.85, "range": 9.0, "dur": 9.0, "every": 0.6, "targets": 3,
			"color": Color(0.55, 0.8, 1.0), "sfx": "sk_thunder",
			"desc": "Monta uma torre Tesla por {dur} s: a cada 0,6 s ela solta raios em até 3 inimigos próximos ({dmg} de dano cada)."},
	],
	## Os 4 heróis jogáveis usam as listas de skills do dono (Guerreiro e Lanceiro 12 + ataque básico, Mago 12, Arqueira 6).
	## "anim": animação de skill do modelo (Guerreiro/Lanceiro usam as do Náutico na*, Mago/Arqueira as da Druida dr*).
	## Guerreiro: as skills da lista do dono (o Golpe de Crescente virou o ataque básico, "basic_fx": "crescent").
	"guerreiro": [
		{"id": "gu1", "name": "Golpe de Divisão", "type": "arc", "cd": 4.0, "mp": 10, "mult": 1.4, "r": 3.8, "half": 1.35, "stun": 0.5, "anim": "na1",
			"color": Color(0.95, 0.85, 0.6), "sfx": "sk_slash",
			"desc": "Um corte amplo em arco horizontal: {dmg} de dano e interrompe o que os inimigos estavam fazendo."},
		{"id": "gu2", "name": "Ataque de Ombro", "type": "charge", "cd": 7.0, "mp": 12, "mult": 1.5, "dist": 5.0, "stun": 1.3, "knock": 2.0, "anim": "na7",
			"color": Color(0.85, 0.8, 0.7), "sfx": "sk_dash",
			"desc": "Investida pesada com a armadura: {dmg} de dano, choque e atordoamento por 1,3 s."},
		{"id": "gu3", "name": "Golpe de Vácuo", "type": "wave", "cd": 6.0, "mp": 14, "mult": 1.6, "len": 14.0, "width": 2.6, "time": 0.4, "anim": "na7",
			"color": Color(0.75, 0.9, 1.0), "sfx": "sk_slash",
			"desc": "Dispara uma onda de força da espada em linha reta: {dmg} de dano em todos os alvos alinhados."},
		{"id": "gu4", "name": "Rugido do Leão", "type": "roar", "cd": 12.0, "mp": 16, "mult": 0.7, "r": 5.5, "stun": 1.2, "knock": 3.0, "anim": "na9",
			"color": Color(1.0, 0.75, 0.35), "sfx": "sk_buff",
			"desc": "Onda de choque sonora em volta ({r} m): {dmg} de dano, empurra, atordoa e provoca todos para atacarem você."},
		{"id": "gu5", "name": "Esmagamento Terrestre", "type": "leap", "cd": 9.0, "mp": 18, "mult": 2.0, "r": 4.2, "range": 10.0, "stun": 1.0, "lift": 0.8, "anim": "na10",
			"color": Color(0.9, 0.7, 0.45), "sfx": "sk_slam",
			"desc": "Salta e cai batendo a espada no chão: terremoto de {r} m com {dmg} de dano que derruba os inimigos."},
		{"id": "gu6", "name": "Corte de Vendaval", "type": "spin_multi", "cd": 10.0, "mp": 22, "mult": 0.6, "r": 4.0, "hits": 6, "anim": "na6",
			"color": Color(0.9, 0.9, 0.95), "sfx": "sk_slash",
			"desc": "Combo rápido e giratório: 6 cortes seguidos em volta do corpo, {dmg} de dano cada."},
		{"id": "gu7", "name": "Resposta", "type": "riposte", "cd": 12.0, "mp": 14, "mult": 2.4, "r": 4.0, "dur": 1.2, "anim": "na3",
			"color": Color(1.0, 0.9, 0.5), "sfx": "sk_shield",
			"desc": "Postura defensiva: bloqueia todos os ataques por {dur} s e revida na hora com um contra-ataque de {dmg} de dano."},
		{"id": "gu8", "name": "Manilha de Ferro", "type": "hook", "cd": 11.0, "mp": 18, "mult": 1.3, "range": 16.0, "count": 3, "stun": 1.8, "anim": "na2",
			"color": Color(0.7, 0.75, 0.8), "sfx": "sk_slam",
			"desc": "Lança correntes nos 3 inimigos mais distantes à frente e puxa todos até você: {dmg} de dano e imobilizados por 1,8 s."},
		{"id": "gu9", "name": "Berserk", "type": "berserk", "cd": 24.0, "mp": 20, "buff": 0.3, "buff_lv": 0.02, "dur": 10.0, "anim": "na5",
			"color": Color(1.0, 0.3, 0.2), "sfx": "sk_buff",
			"desc": "Fúria de combate por {dur} s: +{buff} de dano e +20% de velocidade; com menos da metade da vida o bônus de dano dobra."},
		{"id": "gu10", "name": "Carga Bárbara", "type": "charge", "cd": 14.0, "mp": 24, "mult": 2.0, "dist": 12.0, "stun": 1.5, "knock": 3.5, "lift": 0.7, "anim": "na7",
			"color": Color(1.0, 0.6, 0.3), "sfx": "sk_dash",
			"desc": "Avança com fúria rompendo as linhas inimigas: {dmg} de dano e derruba todos no caminho."},
		{"id": "gu11", "name": "Postura Inquebrável", "type": "guard", "visual": "shields", "cd": 22.0, "mp": 20, "buff": 0.6, "buff_lv": 0.02, "dur": 6.0, "anim": "na3",
			"color": Color(1.0, 0.85, 0.35), "sfx": "sk_shield",
			"desc": "Um redemoinho de defesa espiritual: recebe {buff} menos dano por {dur} s e não pode ser atordoado."},
		{"id": "gu12", "name": "Chama Suprema", "type": "inferno_cone", "cd": 30.0, "mp": 45, "mult": 3.6, "r": 10.0, "half": 0.6, "anim": "na9",
			"color": Color(1.0, 0.5, 0.15), "sfx": "sk_explosion",
			"desc": "Suprema: descarrega uma explosão massiva de energia flamejante à frente ({r} m): {dmg} de dano devastador e deixa queimando."},
	],
	## Lanceiro: as skills da lista do dono (o Golpe Duplo virou o ataque básico, "basic_hits": 2).
	"lanceiro": [
		{"id": "la1", "name": "Golpe Devastador", "type": "thrust3", "hits": 1, "cd": 3.5, "mp": 8, "mult": 1.6, "range": 5.0, "vuln": 0.2, "vuln_dur": 6.0, "anim": "na1",
			"color": Color(0.82, 0.92, 1.0), "sfx": "sk_slash",
			"desc": "Golpe inicial que destrói a força interior do alvo: {dmg} de dano e ele recebe 20% mais dano por 6 s (ótimo para começar o combo)."},
		{"id": "la2", "name": "Lança Ascendente", "type": "launch", "cd": 7.0, "mp": 14, "mult": 1.5, "r": 4.5, "half": 0.7, "lift": 1.5, "anim": "na2",
			"color": Color(0.6, 0.85, 1.0), "sfx": "sk_slash",
			"desc": "Joga os inimigos à frente para o ar: {dmg} de dano, perdem a estabilidade e ficam no ar por 1,5 s."},
		{"id": "la3", "name": "Chute Giratório", "type": "spin", "cd": 6.0, "mp": 10, "mult": 1.1, "r": 3.2, "knock": 3.5, "stun": 0.8, "anim": "na6",
			"color": Color(0.85, 0.9, 1.0), "sfx": "sk_slash",
			"desc": "Chute em giro para abrir espaço: {dmg} de dano em {r} m, empurra e atordoa."},
		{"id": "la4", "name": "Lança Perfurante", "type": "javelin", "cd": 8.0, "mp": 14, "mult": 2.0, "speed": 42.0, "life": 0.7, "slow": 0.5, "slow_dur": 3.0, "anim": "na1",
			"color": Color(0.7, 0.9, 1.0), "sfx": "sk_dash",
			"desc": "Arremessa uma lança de energia a longa distância para caçar quem foge: {dmg} de dano, atravessa e deixa lento."},
		{"id": "la5", "name": "Tempestade Arrebatadora", "type": "lance_storm", "cd": 12.0, "mp": 22, "mult": 0.55, "r": 5.0, "dur": 2.0, "every": 0.25, "anim": "na6",
			"color": Color(0.7, 0.85, 1.0), "sfx": "sk_slash",
			"desc": "Gira a lança em alta velocidade por {dur} s (dá para andar): {dmg} de dano a cada giro em todos a {r} m."},
		{"id": "la6", "name": "Varredura Longa", "type": "sweep", "cd": 9.0, "mp": 16, "mult": 1.3, "r": 6.5, "slow": 0.4, "slow_dur": 3.0, "stun": 0.8, "anim": "na6",
			"color": Color(0.55, 0.75, 1.0), "sfx": "sk_slash",
			"desc": "Varre uma zona grande à frente com a lança: {dmg} de dano, atordoa e deixa lento."},
		{"id": "la7", "name": "Golpe Esmagador", "type": "crush", "cd": 9.0, "mp": 18, "mult": 2.2, "r": 3.0, "range": 4.5, "stun": 1.0, "vuln": 0.3, "vuln_dur": 6.0, "weaken": 0.3, "anim": "na10",
			"color": Color(0.75, 0.8, 1.0), "sfx": "sk_slam",
			"desc": "Impacto vertical brutal: {dmg} de dano, atordoa, quebra a defesa (+30% de dano recebido) e reduz o ataque do inimigo em 30%."},
		{"id": "la8", "name": "Parede de Vento", "type": "wind_wall", "cd": 16.0, "mp": 18, "pct": 0.22, "pct_lv": 0.015, "dur": 6.0, "r": 4.0, "knock": 4.0, "anim": "na3",
			"color": Color(0.7, 1.0, 0.9), "sfx": "sk_shield",
			"desc": "Barreira de vento: empurra os inimigos e absorve {shield} da vida máxima em dano por {dur} s."},
		{"id": "la9", "name": "Absorção", "type": "leech", "cd": 12.0, "mp": 20, "mult": 1.6, "r": 5.0, "half": 0.5, "heal": 0.4, "anim": "na1",
			"color": Color(0.9, 0.3, 0.4), "sfx": "sk_magic",
			"desc": "Drena a vida dos inimigos à frente: {dmg} de dano e cura 40% do dano causado."},
		{"id": "la10", "name": "Lâmina Crescente", "type": "consume", "cd": 10.0, "mp": 20, "mult": 2.0, "r": 4.5, "half": 0.9, "anim": "na9",
			"color": Color(0.85, 0.75, 1.0), "sfx": "sk_slash",
			"desc": "Golpe finalizador: {dmg} de dano; em quem estiver lento, atordoado ou com a defesa quebrada, consome o efeito e causa crítico com +60% de dano."},
		{"id": "la11", "name": "Ataque Relâmpago", "type": "blitz", "cd": 11.0, "mp": 18, "mult": 1.8, "range": 16.0, "knock": 6.0, "anim": "na7",
			"color": Color(0.7, 0.8, 1.0), "sfx": "sk_thunder",
			"desc": "Investe num piscar de olhos contra o inimigo mais perto (até 16 m) e o arremessa para trás com a lança: {dmg} de dano."},
		{"id": "la12", "name": "Lança Celeste", "type": "finisher", "cd": 26.0, "mp": 40, "mult": 3.8, "len": 13.0, "width": 2.6, "anim": "na1",
			"color": Color(0.55, 0.8, 1.0), "sfx": "sk_explosion",
			"desc": "Suprema: concentra todo o poder na ponta da lança e desfere uma estocada mortal em linha: {dmg} de dano (o dobro com a defesa quebrada). Cada inimigo derrotado tira 4 s da recarga."},
	],
	"mago": [
		{"id": "ma1", "name": "Orbe de Chamas", "type": "projectile", "visual": "fireball", "cd": 2.6, "mp": 9, "mult": 1.4, "speed": 26.0, "life": 1.0, "explode": 2.6, "anim": "dr5",
			"color": Color(1.0, 0.55, 0.2), "sfx": "sk_fire",
			"desc": "Dispara uma esfera de fogo concentrada que explode no impacto: {dmg} de dano em área."},
		{"id": "ma2", "name": "Orbe de Gelo", "type": "frost_orb", "cd": 5.0, "mp": 12, "mult": 1.2, "speed": 22.0, "life": 1.1, "r": 2.4, "slow": 0.65, "slow_dur": 4.0, "anim": "dr5",
			"color": Color(0.6, 0.9, 1.0), "sfx": "sk_ice",
			"desc": "Lança uma esfera congelante: {dmg} de dano em volta do alvo e reduz muito a velocidade de quem for atingido (65% por 4 s)."},
		{"id": "ma3", "name": "Golpe de Chamas", "type": "flame_nova", "cd": 9.0, "mp": 16, "mult": 1.2, "r": 4.5, "knock": 5.0, "burn": 0.3, "anim": "dr6",
			"color": Color(1.0, 0.5, 0.15), "sfx": "sk_fire",
			"desc": "Uma tempestade de calor repentina em volta: {dmg} de dano e empurra para longe quem tenta se aproximar, deixando queimando."},
		{"id": "ma4", "name": "Raios em Cadeia", "type": "storm_chain", "cd": 6.0, "mp": 18, "mult": 1.3, "range": 14.0, "hops": 5, "jump": 8.0, "stun": 0.3, "anim": "dr8",
			"color": Color(0.65, 0.75, 1.0), "sfx": "sk_thunder",
			"desc": "Um relâmpago que salta de um alvo para o outro, eletrocutando até {n} inimigos: {dmg} de dano em cada."},
		{"id": "ma5", "name": "Bloco Congelado", "type": "ice_block", "cd": 18.0, "mp": 20, "mult": 0.8, "r": 4.0, "dur": 2.0, "stun": 2.0, "pct": 0.12, "pct_lv": 0.01, "anim": "dr4",
			"color": Color(0.7, 0.95, 1.0), "sfx": "sk_ice",
			"desc": "Envolve a maga em gelo: fica invulnerável por {dur} s e cura {shield} da vida; ao sair, congela os atacantes próximos ({dmg} de dano)."},
		{"id": "ma6", "name": "Imolação", "type": "immolate", "cd": 9.0, "mp": 22, "mult": 0.9, "r": 6.0, "range": 15.0, "count": 5, "ticks": 5, "every": 0.5, "anim": "dr1",
			"color": Color(1.0, 0.45, 0.15), "sfx": "sk_fire",
			"desc": "Invoca colunas de fogo do inferno sob até 5 inimigos na área mirada: {dmg} de dano de queima 5 vezes em cada."},
		{"id": "ma7", "name": "Nevasca", "type": "blizzard", "cd": 14.0, "mp": 28, "mult": 0.5, "r": 6.0, "range": 15.0, "dur": 4.0, "every": 0.4, "slow": 0.5, "freeze": 1.5, "anim": "dr7",
			"color": Color(0.75, 0.92, 1.0), "sfx": "sk_ice",
			"desc": "Uma tempestade de neve severa na área ({r} m) por {dur} s: {dmg} de dano a cada 0,4 s, desacelera e no fim congela todos por 1,5 s."},
		{"id": "ma8", "name": "Escudo Mágico", "type": "magic_shield", "cd": 22.0, "mp": 10, "pct": 0.6, "pct_lv": 0.03, "dur": 12.0, "anim": "dr4",
			"color": Color(0.5, 0.6, 1.0), "sfx": "sk_shield",
			"desc": "Uma barreira protetora por {dur} s: {shield} do dano recebido sai da mana em vez da vida (até a mana acabar)."},
		{"id": "ma9", "name": "Devorador de Almas", "type": "soul_drain", "cd": 8.0, "mp": 16, "mult": 0.9, "count": 4, "speed": 20.0, "mana": 4, "vuln": 0.15, "vuln_dur": 5.0, "anim": "dr5",
			"color": Color(0.55, 0.25, 0.9), "sfx": "sk_magic",
			"desc": "Dispara rajadas de energia negra que perseguem os inimigos: {dmg} de dano no espírito (ficam 15% mais frágeis) e rouba mana a cada acerto."},
		{"id": "ma10", "name": "Tempestade de Raios", "type": "sea_storm", "cd": 20.0, "mp": 36, "mult": 1.1, "r": 6.5, "range": 15.0, "dur": 4.0, "every": 0.25, "slow": 0.3, "slow_dur": 2.0, "anim": "dr8",
			"color": Color(0.65, 0.7, 1.0), "sfx": "sk_thunder",
			"desc": "Invoca trovões do céu, um atrás do outro, na área mirada por {dur} s: {dmg} de dano cada."},
		{"id": "ma11", "name": "Vórtice Sombrio", "type": "dark_vortex", "cd": 18.0, "mp": 30, "mult": 0.35, "r": 7.0, "range": 14.0, "dur": 3.0, "every": 0.3, "anim": "dr1",
			"color": Color(0.45, 0.2, 0.8), "sfx": "sk_magic",
			"desc": "Um buraco negro de vento no ponto mirado puxa os inimigos de {r} m para o centro por {dur} s ({dmg} de dano por puxão), agrupando todos."},
		{"id": "ma12", "name": "Tornado Elemental", "type": "tornado", "cd": 30.0, "mp": 45, "mult": 0.6, "r": 7.0, "range": 14.0, "ticks": 14, "every": 0.3, "anim": "dr6",
			"color": Color(0.75, 0.55, 1.0), "sfx": "sk_magic",
			"desc": "Suprema: invoca um redemoinho elemental gigante no ponto mirado que arrasta e estraçalha todos em {r} m: {dmg} de dano por giro."},
	],
	## Arqueira: as 6 skills da lista do dono.
	"arqueira": [
		{"id": "ar1", "name": "Salto e Disparo de Recuo", "type": "backstep", "cd": 6.0, "mp": 10, "mult": 1.1, "dist": 7.0, "r": 5.5, "half": 0.7, "knock": 4.5, "anim": "dr2",
			"color": Color(0.8, 0.95, 0.75), "sfx": "sk_dash",
			"desc": "Pula para trás atirando e empurra os inimigos à frente para manter a distância: {dmg} de dano."},
		{"id": "ar2", "name": "Chuva de Flechas", "type": "rain", "visual": "arrows", "cd": 9.0, "mp": 20, "mult": 0.6, "r": 6.0, "range": 18.0, "ticks": 6, "every": 0.4, "anim": "dr7",
			"color": Color(0.95, 0.85, 0.55), "sfx": "arrow",
			"desc": "Uma saraivada de flechas atirada para o céu cai sobre uma área grande ({r} m): {dmg} de dano a cada leva, 6 levas."},
		{"id": "ar3", "name": "Flechas Explosivas", "type": "blast_arrow", "cd": 6.0, "mp": 16, "mult": 1.8, "speed": 34.0, "life": 0.9, "explode": 3.2, "frags": 8, "anim": "dr5",
			"color": Color(1.0, 0.55, 0.25), "sfx": "sk_explosion",
			"desc": "Disparo carregado que explode no primeiro alvo ({dmg} de dano em volta) e espalha estilhaços que ferem quem está perto."},
		{"id": "ar4", "name": "Mira Estável", "type": "focus", "cd": 20.0, "mp": 16, "buff": 0.35, "buff_lv": 0.02, "dur": 10.0, "anim": "dr4",
			"color": Color(1.0, 0.9, 0.4), "sfx": "sk_buff",
			"desc": "Foco total por {dur} s: +{buff} de chance de crítico, +15% de dano e flechas com 40% mais alcance."},
		{"id": "ar5", "name": "Névoa", "type": "stealth", "cd": 16.0, "mp": 14, "dur": 4.0, "r": 6.0, "confuse": 2.0, "anim": "dr2",
			"color": Color(0.7, 0.75, 0.8), "sfx": "sk_magic",
			"desc": "Cortina de fumaça: fica invisível por {dur} s, os inimigos em {r} m ficam confusos por 2 s e o próximo golpe causa o dobro de dano."},
		{"id": "ar6", "name": "Assassinato", "type": "snipe", "cd": 14.0, "mp": 26, "mult": 3.6, "speed": 60.0, "life": 0.9, "charge": 0.5, "low": 0.35, "anim": "dr5",
			"color": Color(1.0, 0.85, 0.3), "sfx": "sk_slash",
			"desc": "Disparo cirúrgico que sempre é crítico: {dmg} de dano, o dobro em alvos com menos de 35% de vida ou que ainda não viram você."},
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
		{"id": "na7", "name": "Tsunami", "type": "tsunami", "cd": 12.0, "mp": 28, "mult": 1.8, "len": 13.0, "width": 6.0, "time": 0.9, "knock": 6.0,
			"color": Color(0.35, 0.7, 1.0), "sfx": "sk_ice",
			"desc": "Levanta uma onda gigante que avança e arrasta tudo à frente: {dmg} de dano e empurra os inimigos para longe."},
		{"id": "na8", "name": "Prisão de Bolhas", "type": "bubbles", "cd": 15.0, "mp": 26, "mult": 1.6, "r": 5.0, "dur": 2.2,
			"color": Color(0.55, 0.85, 1.0), "sfx": "sk_magic",
			"desc": "Prende os inimigos num raio de {r} m dentro de bolhas: eles flutuam presos por {dur} s e levam {dmg} de dano quando a bolha estoura."},
		{"id": "na9", "name": "Tempestade Marítima", "type": "sea_storm", "cd": 22.0, "mp": 38, "mult": 1.0, "r": 6.0, "range": 15.0, "dur": 3.5, "every": 0.3, "slow": 0.3, "slow_dur": 2.0,
			"color": Color(0.6, 0.75, 1.0), "sfx": "sk_thunder",
			"desc": "Chama uma tempestade sobre a área ({r} m) por {dur} s: chuva e raios caem nos inimigos, {dmg} de dano por raio e deixam lentos."},
		{"id": "na10", "name": "Fúria do Kraken", "type": "kraken", "cd": 28.0, "mp": 45, "mult": 3.0, "r": 7.0, "range": 14.0, "count": 6, "stun": 1.2,
			"color": Color(0.6, 0.3, 0.8), "sfx": "sk_slam",
			"desc": "Tentáculos gigantes do Kraken saem do chão e esmagam os inimigos da área ({r} m): {dmg} de dano e atordoa."},
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
	# boss global (ver GLOBAL_BOSS): vida e dano baixos de propósito enquanto o jogo é testado — aumentar depois
	"dragon_global": {"name": "Dragão de Lava", "model": "dragon_lava", "scale": 3.4, "hp": 6000, "dmg": 30, "speed": 3.2, "level": 50,
		"xp": 0, "gold": Vector2i(0, 0), "radius": 4.5, "height": 5.0, "bar": 11.0, "range": 7.5, "atk_cd": 2.4, "style": "melee",
		"boss": true, "outline": 0.012, "leash": 999.0, "aggro_r": 70.0},
	"dragon_hatchling": {"name": "Dragonete", "model": "dragon_whelp", "scale": 0.5, "hp": 220, "dmg": 10, "speed": 4.4, "level": 30,
		"xp": 300, "gold": Vector2i(10, 30), "radius": 1.0, "height": 1.0, "bar": 2.6, "range": 2.2, "atk_cd": 1.4, "style": "melee", "outline": 0.035,
		"leash": 999.0, "aggro_r": 60.0},
}

## Boss global: aparece no Covil do Dragão nos horários abaixo (hora do computador) e fica `minutes` minutos.
## Pensado para vários jogadores (a vida vai crescer com o multiplayer); por enquanto é fraco para testar.
const GLOBAL_BOSS := {
	"enemy": "dragon_global", "map": "covil", "hours": [10, 16, 22], "minutes": 15, "warn_minutes": 5,
	"reward_gold": 3000, "reward_gems": 25, "reward_xp_levels": 0.5, "loot_rarity": "rara", "legendary_chance": 0.0,
	# vida: nunca menos que hp × hp_mult; com jogadores, soma (ataque × dps_k) de cada um × target_secs (~5 min batendo)
	"hp_mult": 100, "dps_k": 6.0, "target_secs": 300.0,
	# ranking de dano: prêmio extra do top 3 e de quem der o último golpe (item: 1% lendário, 2% épico, resto raro)
	"top_gems": [60, 40, 25], "top_gold": [15000, 9000, 6000], "last_gems": 80, "last_gold": 20000,
	"last_item": {"lendaria": 0.01, "epica": 0.02},
	# mecânicas (tempos em segundos, dano relativo ao "dmg" do boss)
	"breath_len": 16.0, "breath_half": 0.45, "breath_dur": 1.8, "breath_mult": 0.25,
	"meteor_count": 6, "meteor_blast": 3.5, "meteor_mult": 1.2,
	"dive_r": 7.0, "dive_mult": 1.5, "whelps": 4, "ring_mult": 0.8,
	"phase2": 0.6, "phase3": 0.3, "mech_every": 5.5,
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
	if _enemy_cache.has(id):
		return _enemy_cache[id]
	if BASE_ENEMIES.has(id):   # vida e dano feitos à mão; XP pela mesma fórmula dos outros (curva de XP)
		var bd: Dictionary = BASE_ENEMIES[id].duplicate()
		bd["xp"] = int(mob_xp(int(bd["level"])) * (15.0 if bool(bd.get("boss", false)) else 1.0))
		_enemy_cache[id] = bd
		return bd
	var d: Dictionary = (MOBS[id] if MOBS.has(id) else GEN_ENEMIES[id]).duplicate()
	var L := float(d["level"])
	var boss := bool(d.get("boss", false))
	# até o nível 60 a curva antiga; depois cresce em linha reta, no mesmo ritmo do herói (ataque e vida ~ nível)
	var Lc := minf(L, 60.0)
	var grow := maxf(1.0, L / 60.0)
	d["hp"] = int((10.0 * pow(Lc, 1.5) + 40.0) * grow * (6.0 if boss else 1.0) * float(d.get("hp_mult", 1.0)))
	d["dmg"] = int((4.0 + 1.3 * pow(Lc, 1.15)) * grow * (2.2 if boss else 1.0))
	d["xp"] = int(10.0 * pow(L, 1.55) * (15.0 if boss else 1.0))
	d["gold"] = Vector2i(int(L), int(L * 3.0)) * (20 if boss else 1)
	_enemy_cache[id] = d
	return d


# =================================================================== mapas gerados (níveis 61 a 1000)
# Cada mapa novo cobre 15 níveis, tem 3 zonas (monstro + chefe) e usa um dos 8 biomas abaixo, cada um com nomes,
# cores, vegetação, lago, luz e monstros próprios (modelos existentes com cor e nome novos). As posições de
# trilhas, zonas e lago mudam em cada mapa. Montados uma vez quando o jogo abre (_static_init).

static var MAPS := {}
static var ZONES := {}
static var MAP_ORDER: Array = []
static var GEN_ENEMIES := {}

const MAP_SPAN := 15

## mobs: [modelo_base, nome, cor, força_da_cor]; o 1º é o comum de cada zona, o chefe usa o modelo de chefe do par.
const BIOMES := [
	{"key": "encantada", "ground": "grass", "path": "dirt", "lake": "water", "music": "music_field", "npc_model": "npc_elder", "hub_style": "vila",
		"names": ["Floresta Encantada", "Bosque das Fadas", "Mata dos Sussurros", "Clareira Lunar", "Floresta Ancestral", "Bosque Eterno", "Selva Esmeralda", "Floresta dos Mil Olhos"],
		"hubs": ["Aldeia Lumen", "Refúgio das Fadas", "Vila do Orvalho", "Posto da Lua", "Aldeia das Raízes", "Bosque Velho", "Vila Esmeralda", "Torre da Vigília"],
		"ground_tint": Color(0.42, 0.55, 0.62), "forest_tint": Color(0.45, 0.42, 0.7), "path_tint": Color(0.62, 0.5, 0.6), "stone_tint": Color(0.5, 0.5, 0.7),
		"trees": {"tree_a": 0.4, "tree_c": 0.6}, "forest_trees": {"tree_pine": 0.5, "tree_c": 0.5}, "grass": Color(0.45, 0.65, 0.6), "forest_grass": Color(0.4, 0.45, 0.7),
		"grass_count": 18000, "flowers": 6000, "props": {"bush_a": 0.4, "bush_b": 0.3, "rock_a": 0.3}, "forest_props": {"mushroom": 1.0}, "glow_prop": "mushroom",
		"glow_color": Color(0.7, 0.4, 1.0), "sun": Color(0.9, 0.75, 1.0), "sun_energy": 0.95, "ambient": Color(0.45, 0.4, 0.75), "ambient_energy": 0.65, "houses": ["house_a", "house_b"],
		"mobs": [["wolf", "Lobo Fantasma", Color(0.6, 0.45, 1.0), 0.45], ["slime", "Gosma Encantada", Color(1.0, 0.5, 0.9), 0.55], ["golem_minion", "Guardião de Musgo", Color(0.4, 0.8, 0.4), 0.4]]},
	{"key": "pantano", "ground": "grass", "path": "dirt", "lake": "water", "music": "music_field", "npc_model": "npc_elder", "hub_style": "vila",
		"names": ["Pântano Sombrio", "Brejo dos Afogados", "Charco Venenoso", "Mangue Esquecido", "Lamaçal das Bruxas", "Pântano da Névoa", "Brejo Fétido", "Atoleiro Antigo"],
		"hubs": ["Palafita Velha", "Cabana da Bruxa", "Posto do Brejo", "Vila Úmida", "Aldeia do Junco", "Ponte Podre", "Casa de Pedra", "Abrigo do Pescador"],
		"ground_tint": Color(0.36, 0.42, 0.3), "forest_tint": Color(0.3, 0.38, 0.28), "path_tint": Color(0.42, 0.36, 0.28), "stone_tint": Color(0.4, 0.45, 0.38),
		"trees": {"dead_tree": 0.6, "tree_pine": 0.4}, "forest_trees": {"dead_tree": 0.5, "tree_b": 0.5}, "grass": Color(0.42, 0.5, 0.3), "forest_grass": Color(0.35, 0.42, 0.28),
		"grass_count": 16000, "flowers": 0, "props": {"bush_b": 0.4, "rock_b": 0.3, "bones": 0.3}, "forest_props": {"mushroom": 1.0}, "glow_prop": "mushroom",
		"glow_color": Color(0.5, 1.0, 0.4), "sun": Color(0.8, 0.9, 0.7), "sun_energy": 0.8, "ambient": Color(0.35, 0.45, 0.4), "ambient_energy": 0.65, "houses": ["house_dark", "house_a"],
		"mobs": [["scorpion", "Escorpião do Brejo", Color(0.35, 0.7, 0.3), 0.5], ["skeleton", "Afogado", Color(0.4, 0.7, 0.55), 0.45], ["slime", "Lodo Tóxico", Color(0.6, 0.9, 0.2), 0.6]]},
	{"key": "cristal", "ground": "sand", "path": "dirt", "lake": "oasis", "music": "music_desert", "npc_model": "npc_desert", "hub_style": "tendas",
		"names": ["Deserto de Cristal", "Dunas Prismáticas", "Vale dos Espelhos", "Areias Cintilantes", "Cânion de Quartzo", "Planície Ametista", "Deserto Arco-Íris", "Mar de Vidro"],
		"hubs": ["Oásis Prisma", "Tenda do Joalheiro", "Posto Cristal", "Acampamento Brilho", "Miragem Azul", "Tenda Ametista", "Oásis Raro", "Abrigo de Vidro"],
		"ground_tint": Color(0.85, 0.72, 0.8), "forest_tint": Color(0.7, 0.85, 0.85), "path_tint": Color(0.6, 0.5, 0.6), "stone_tint": Color(0.75, 0.65, 0.85),
		"trees": {"cactus_a": 0.5, "cactus_b": 0.5}, "forest_trees": {"palm": 1.0}, "grass": Color(0.8, 0.6, 0.75), "forest_grass": Color(0.5, 0.75, 0.7),
		"grass_count": 4000, "flowers": 0, "props": {"rock_a": 0.5, "sand_crystal": 0.5}, "forest_props": {"bush_a": 1.0}, "glow_prop": "sand_crystal",
		"glow_color": Color(1.0, 0.5, 1.0), "sun": Color(1.0, 0.8, 0.9), "sun_energy": 1.1, "ambient": Color(0.6, 0.45, 0.65), "ambient_energy": 0.6, "houses": ["tent", "tent"],
		"mobs": [["golem_sand", "Golem de Quartzo", Color(0.8, 0.5, 1.0), 0.5], ["scorpion", "Escorpião Prismático", Color(0.4, 0.9, 1.0), 0.5], ["skeleton", "Espectro de Vidro", Color(0.8, 0.9, 1.0), 0.4]]},
	{"key": "tundra", "ground": "snow", "path": "dirt", "lake": "ice", "music": "music_snow", "npc_model": "npc_ice", "hub_style": "cabanas", "glow_threshold": 1.4, "exposure": 0.92,
		"names": ["Tundra Eterna", "Geleira Uivante", "Picos da Aurora", "Vale Congelado", "Estepe Polar", "Montanhas Brancas", "Fiorde Gélido", "Coroa de Gelo"],
		"hubs": ["Forte da Aurora", "Cabana do Caçador", "Posto Polar", "Vila Branca", "Abrigo do Fiorde", "Refúgio da Coroa", "Cabana Gélida", "Forte Norte"],
		"ground_tint": Color(0.62, 0.68, 0.85), "forest_tint": Color(0.55, 0.62, 0.82), "path_tint": Color(0.5, 0.48, 0.55), "stone_tint": Color(0.55, 0.65, 0.85),
		"trees": {"pine_snow": 0.7, "dead_tree_frost": 0.3}, "forest_trees": {"pine_snow": 1.0}, "grass": Color(0.7, 0.8, 0.95), "forest_grass": Color(0.6, 0.7, 0.85),
		"grass_count": 0, "flowers": 0, "props": {"rock_a": 0.5, "rock_b": 0.5}, "forest_props": {"ice_crystal": 1.0}, "glow_prop": "ice_crystal",
		"glow_color": Color(0.4, 1.0, 0.8), "sun": Color(0.75, 0.85, 1.0), "sun_energy": 0.9, "ambient": Color(0.4, 0.5, 0.85), "ambient_energy": 0.6, "houses": ["house_snow", "house_snow"],
		"mobs": [["yeti", "Yeti da Aurora", Color(0.5, 1.0, 0.85), 0.35], ["wolf_ice", "Lobo Boreal", Color(0.4, 0.9, 0.8), 0.4], ["golem_ice", "Golem Glacial", Color(0.7, 0.6, 1.0), 0.4]]},
	{"key": "sombrias", "ground": "ash", "path": "stone", "lake": "lava", "music": "music_volcano", "npc_model": "npc_volcano", "hub_style": "fortaleza",
		"names": ["Terras Sombrias", "Necrópole Esquecida", "Campos do Pesadelo", "Vale das Almas", "Reino Assombrado", "Planície Morta", "Cemitério Sem Fim", "Trono das Sombras"],
		"hubs": ["Capela Negra", "Torre do Exorcista", "Forte Cinzento", "Abrigo da Vela", "Mosteiro Partido", "Portão das Almas", "Posto Funesto", "Bastião Final"],
		"ground_tint": Color(0.55, 0.5, 0.65), "forest_tint": Color(0.5, 0.4, 0.6), "path_tint": Color(0.42, 0.38, 0.48), "stone_tint": Color(0.4, 0.35, 0.5),
		"trees": {"dead_tree_burnt": 1.0}, "forest_trees": {"dead_tree_burnt": 1.0}, "grass": Color(0, 0, 0), "forest_grass": Color(0, 0, 0),
		"grass_count": 0, "flowers": 0, "props": {"bones": 0.5, "rock_a": 0.5}, "forest_props": {"ice_crystal": 1.0}, "glow_prop": "ice_crystal",
		"glow_color": Color(0.6, 0.4, 1.0), "sun": Color(0.6, 0.55, 0.85), "sun_energy": 0.7, "ambient": Color(0.38, 0.3, 0.5), "ambient_energy": 0.65, "houses": ["house_dark", "house_dark"],
		"mobs": [["skeleton", "Cavaleiro Sombrio", Color(0.5, 0.3, 0.8), 0.5], ["imp", "Diabrete Espectral", Color(0.5, 0.4, 1.0), 0.5], ["wolf", "Cão Infernal Sombrio", Color(0.3, 0.2, 0.5), 0.55]]},
	{"key": "celeste", "ground": "grass", "path": "stone", "lake": "water", "music": "music_field", "npc_model": "npc_elder", "hub_style": "vila",
		"names": ["Jardim Celeste", "Ilhas do Céu", "Campos Dourados", "Santuário Alado", "Planalto Solar", "Templo das Nuvens", "Pradaria Divina", "Cidadela do Alvorecer"],
		"hubs": ["Templo do Sol", "Vila das Nuvens", "Mirante Dourado", "Posto Alado", "Santuário Branco", "Torre do Sino", "Jardim do Monge", "Portão Solar"],
		"ground_tint": Color(0.75, 0.72, 0.5), "forest_tint": Color(0.8, 0.7, 0.45), "path_tint": Color(0.85, 0.8, 0.7), "stone_tint": Color(0.85, 0.82, 0.75),
		"trees": {"tree_b": 0.5, "tree_c": 0.5}, "forest_trees": {"tree_a": 1.0}, "grass": Color(0.8, 0.75, 0.45), "forest_grass": Color(0.75, 0.7, 0.4),
		"grass_count": 16000, "flowers": 8000, "props": {"rock_a": 0.4, "bush_a": 0.6}, "forest_props": {"mushroom": 1.0}, "glow_prop": "sand_crystal",
		"glow_color": Color(1.0, 0.85, 0.4), "sun": Color(1.0, 0.9, 0.7), "sun_energy": 1.1, "ambient": Color(0.6, 0.55, 0.5), "ambient_energy": 0.6, "houses": ["house_a", "house_b"],
		"mobs": [["golem_minion", "Guardião de Mármore", Color(1.0, 0.95, 0.85), 0.6], ["imp", "Querubim Caído", Color(1.0, 0.85, 0.5), 0.6], ["dragon_whelp", "Grifo Dourado", Color(1.0, 0.8, 0.35), 0.5]]},
	{"key": "estelar", "ground": "ash", "path": "stone", "lake": "ice", "music": "music_snow", "npc_model": "npc_ice", "hub_style": "fortaleza",
		"names": ["Abismo Estelar", "Vazio Cósmico", "Ruínas Astrais", "Nebulosa Caída", "Fenda do Infinito", "Mar de Estrelas", "Reino Eclipse", "Horizonte de Eventos"],
		"hubs": ["Observatório", "Âncora Astral", "Posto Lunar", "Torre Estelar", "Portal Cósmico", "Farol do Vazio", "Base Eclipse", "Santuário Final"],
		"ground_tint": Color(0.35, 0.38, 0.6), "forest_tint": Color(0.4, 0.3, 0.65), "path_tint": Color(0.3, 0.32, 0.5), "stone_tint": Color(0.35, 0.35, 0.6),
		"trees": {"dead_tree_frost": 1.0}, "forest_trees": {"dead_tree_frost": 1.0}, "grass": Color(0, 0, 0), "forest_grass": Color(0, 0, 0),
		"grass_count": 0, "flowers": 0, "props": {"rock_a": 0.5, "ice_crystal": 0.5}, "forest_props": {"ice_crystal": 1.0}, "glow_prop": "ice_crystal",
		"glow_color": Color(0.5, 0.6, 1.0), "sun": Color(0.6, 0.65, 1.0), "sun_energy": 0.75, "ambient": Color(0.35, 0.35, 0.7), "ambient_energy": 0.7, "houses": ["house_dark", "house_snow"],
		"mobs": [["imp", "Viajante do Vazio", Color(0.3, 0.5, 1.0), 0.55], ["golem_ice", "Colosso Estelar", Color(0.5, 0.3, 1.0), 0.5], ["dragon_whelp", "Serpe Cósmica", Color(0.3, 0.5, 1.0), 0.55]]},
	{"key": "brasas", "ground": "ash", "path": "stone", "lake": "lava", "music": "music_volcano", "npc_model": "npc_volcano", "hub_style": "fortaleza",
		"names": ["Vulcão Negro", "Terras em Brasa", "Forja dos Titãs", "Caldeira Rubra", "Inferno de Cinzas", "Rio de Magma", "Coração Ardente", "Trono de Fogo"],
		"hubs": ["Forja Anã", "Fortaleza Rubra", "Posto da Cinza", "Bastião Ardente", "Forte do Magma", "Cidadela Negra", "Abrigo da Brasa", "Trono Fortificado"],
		"ground_tint": Color(0.8, 0.62, 0.6), "forest_tint": Color(0.75, 0.5, 0.45), "path_tint": Color(0.45, 0.38, 0.38), "stone_tint": Color(0.42, 0.32, 0.32),
		"trees": {"dead_tree_burnt": 1.0}, "forest_trees": {"dead_tree_burnt": 1.0}, "grass": Color(0, 0, 0), "forest_grass": Color(0, 0, 0),
		"grass_count": 0, "flowers": 0, "props": {"rock_a": 0.5, "fire_crystal": 0.5}, "forest_props": {"fire_crystal": 1.0}, "glow_prop": "fire_crystal",
		"glow_color": Color(1.0, 0.35, 0.1), "sun": Color(1.0, 0.45, 0.3), "sun_energy": 0.8, "ambient": Color(0.5, 0.28, 0.32), "ambient_energy": 0.62, "houses": ["house_dark", "house_dark"],
		"mobs": [["golem_magma", "Titã de Obsidiana", Color(1.0, 0.4, 0.1), 0.35], ["imp", "Demônio de Brasa", Color(1.0, 0.3, 0.1), 0.45], ["dragon_whelp", "Dragão de Magma", Color(1.0, 0.25, 0.05), 0.4]]},
]

## Chefe de cada modelo comum (mesmo esqueleto, maior).
## Chefe único de cada bioma (o da última zona de cada mapa gerado): nome, mecânicas (BossMech) e tamanho.
const BIOME_BOSS := {
	"encantada": {"name": "Rainha das Raízes", "mech": ["veneno", "invocar"]},
	"pantano": {"name": "Hidra do Brejo", "mech": ["veneno", "anel"]},
	"cristal": {"name": "Colosso Prismático", "mech": ["gelo", "anel"]},
	"tundra": {"name": "Senhor do Inverno", "mech": ["gelo", "anel"]},
	"sombrias": {"name": "Ceifador Sombrio", "mech": ["invocar", "meteoros"]},
	"celeste": {"name": "Arcanjo Caído", "mech": ["anel", "meteoros"]},
	"estelar": {"name": "Devorador de Estrelas", "mech": ["meteoros", "gelo"]},
	"brasas": {"name": "Titã da Forja", "mech": ["meteoros", "anel"]},
}
const BOSS_OF := {"wolf": "wolf_alpha", "wolf_ice": "wolf_glacial", "slime": "slime_king", "golem_minion": "golem_boss", "golem_sand": "golem_sand_boss",
		"golem_ice": "golem_ice_boss", "golem_magma": "golem_magma_boss", "scorpion": "scorpion_queen", "skeleton": "skeleton_king",
		"yeti": "yeti_ancient", "imp": "imp_lord", "dragon_whelp": "dragon_ancient"}


static func _static_init() -> void:
	MAPS = BASE_MAPS.duplicate(true)
	ZONES = BASE_ZONES.duplicate(true)
	# masmorra de cada bioma: mesma sala, com o visual (chão, luz, vegetação) do bioma
	for b in BIOMES:
		var mid := "masmorra_" + String(b["key"])
		var md: Dictionary = MAPS["masmorra"].duplicate(true)
		md["name"] = "Masmorra: " + String(b["names"][0])
		md["zones"] = ["sala_" + String(b["key"])]
		var th: Dictionary = md["theme"]
		for key in ["ground", "path", "ground_tint", "forest_tint", "path_tint", "stone_tint", "trees", "forest_trees", "props", "forest_props", "glow_prop", "glow_color", "sun", "sun_energy", "ambient", "ambient_energy"]:
			if b.has(key):
				th[key] = b[key]
		th["grass_count"] = 0
		th["flowers"] = 0
		md["lake"]["type"] = String(b["lake"])
		md["biome"] = String(b["key"])
		MAPS[mid] = md
		var zd: Dictionary = ZONES["sala_masmorra"].duplicate(true)
		zd["map"] = mid
		ZONES["sala_" + String(b["key"])] = zd
	MAP_ORDER = BASE_MAP_ORDER.duplicate()
	_gen_maps()


static func _template(model_id: String) -> Dictionary:
	if BASE_ENEMIES.has(model_id):
		return BASE_ENEMIES[model_id]
	return MOBS[model_id]


static func _gen_maps() -> void:
	var count := int(ceil(float(MAX_LEVEL - BASE_MAX_LEVEL) / MAP_SPAN))
	for i in count:
		var bi := i % BIOMES.size()
		var b: Dictionary = BIOMES[bi]
		var round_n := i / BIOMES.size()            # 0..7: qual nome do bioma e quanto a cor muda
		var lo := BASE_MAX_LEVEL + 1 + i * MAP_SPAN
		var hi := mini(lo + MAP_SPAN - 1, MAX_LEVEL)
		var id := "m%d" % (i + 1)
		var rng := RandomNumberGenerator.new()
		rng.seed = 7919 * (i + 1)
		var base_ang := rng.randf() * TAU
		var zone_ids := []
		var centers := []
		for k in 3:
			var a := base_ang + TAU * k / 3.0 + rng.randf_range(-0.35, 0.35)
			var dist := rng.randf_range(56.0, 68.0)
			var c := Vector3(cos(a), 0, sin(a)) * dist
			centers.append(c)
			var mob: Array = b["mobs"][(k + round_n) % 3]
			var col: Color = mob[2]
			col = Color.from_hsv(fposmod(col.h + 0.07 * round_n, 1.0), col.s, col.v)
			var zl := lo + k * 5
			var zid := "%s_z%d" % [id, k]
			var mob_id := zid + "_m"
			var boss_id := zid + "_b"
			var tm := _template(String(mob[0])).duplicate()
			tm.merge({"name": String(mob[1]), "level": zl + 2, "tint": col, "tint_amt": float(mob[3])}, true)
			for key in ["hp", "dmg", "xp", "gold", "boss", "slam_r"]:
				tm.erase(key)
			GEN_ENEMIES[mob_id] = tm
			var tb := _template(String(BOSS_OF.get(String(mob[0]), mob[0]))).duplicate()
			tb.merge({"name": "%s Supremo" % String(mob[1]), "level": zl + 4, "tint": col, "tint_amt": float(mob[3]), "boss": true,
					"style": "slam", "slam_r": float(tb.get("slam_r", 5.5))}, true)
			if k == 2:   # última zona: chefe único do bioma, maior e com mecânicas
				var bb: Dictionary = BIOME_BOSS.get(String(b["key"]), {})
				if not bb.is_empty():
					tb["name"] = "%s %s" % [String(bb["name"]), ["", "II", "III", "IV", "V", "VI", "VII", "VIII"][round_n % 8]]
					tb["name"] = String(tb["name"]).strip_edges()
					tb["mech"] = bb["mech"]
					tb["minion"] = mob_id
					tb["scale"] = float(tb.get("scale", 1.0)) * 1.3
					tb["hp_mult"] = 1.6
			for key in ["hp", "dmg", "xp", "gold"]:
				tb.erase(key)
			GEN_ENEMIES[boss_id] = tb
			var zone_names := ["Arredores", "Coração", "Profundezas"]
			ZONES[zid] = {"map": id, "name": "%s · %s" % [_city(_kingdom_by_biome(String(b["key"])), round_n), zone_names[k]], "levels": "Nv %d-%d" % [zl, zl + 4],
					"lvl": Vector2i(zl, zl + 4), "center": c, "radius": 17.0, "enemy": mob_id, "boss": boss_id, "count": 11,
					"boss_pos": c + c.normalized() * 14.0, "color": col}
			zone_ids.append(zid)
		var lake_a := base_ang + TAU / 6.0 + rng.randf_range(-0.2, 0.2)
		var lake_c := Vector2(cos(lake_a), sin(lake_a)) * rng.randf_range(42.0, 52.0)
		var theme := {}
		for key in ["ground", "path", "ground_tint", "forest_tint", "path_tint", "stone_tint", "trees", "forest_trees", "grass", "forest_grass",
				"grass_count", "flowers", "props", "forest_props", "glow_prop", "glow_color", "sun", "sun_energy", "ambient", "ambient_energy", "houses"]:
			theme[key] = b[key]
		for key in ["glow_threshold", "exposure"]:
			if b.has(key):
				theme[key] = b[key]
		theme["tree_keep"] = 0.12
		theme["forest_keep"] = 0.7
		theme["lava"] = 1.0 if String(b["lake"]) == "lava" else 0.0
		var shift := 0.04 * round_n   # cada volta pelos biomas muda um pouco a cor
		for key in ["ground_tint", "forest_tint"]:
			var tc: Color = theme[key]
			theme[key] = Color.from_hsv(fposmod(tc.h + shift, 1.0), tc.s, tc.v)
		var c0: Vector3 = centers[0]
		var c2: Vector3 = centers[2]
		var kg := _kingdom_by_biome(String(b["key"]))
		MAPS[id] = {"name": _city(kg, round_n), "levels": "Nv %d-%d" % [lo, hi], "min_level": lo - 1, "kingdom": kg,
				"hub": String(b["hubs"][round_n % 8]), "hub_style": String(b["hub_style"]), "npc": "Emissário de %s" % String(KINGDOMS[kg]["name"]),
				"npc_model": String(b["npc_model"]), "music": String(b["music"]), "zones": zone_ids, "biome": String(b["key"]),
				"lake": {"c": lake_c, "r": Vector2(rng.randf_range(10, 15), rng.randf_range(7, 10)), "type": String(b["lake"])},
				"regions": [{"type": "forest", "c": Vector2(c0.x, c0.z), "r": 32.0}, {"type": "stone", "c": Vector2(c2.x, c2.z), "r": 18.0}],
				"theme": theme}
		MAP_ORDER.append(id)
	_build_campaign()


## Mapa mais alto que o herói já alcança (para o modo automático caçar onde rende mais).
static func best_map(level: int) -> String:
	var best := "vale"
	for id in MAP_ORDER:
		if level >= int(MAPS[id]["min_level"]):
			best = String(id)
	return best


## Mapas. Cada mapa tem 3 zonas de caça (cada uma com um chefe) e um acampamento com NPC, portal e quadro de missões.
const BASE_MAPS := {
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
		"theme": {"ground": "snow", "path": "dirt", "ground_tint": Color(0.7, 0.75, 0.86), "forest_tint": Color(0.62, 0.7, 0.84), "path_tint": Color(0.55, 0.52, 0.55), "stone_tint": Color(0.6, 0.72, 0.85),
			"trees": {"pine_snow": 0.7, "dead_tree_frost": 0.3}, "forest_trees": {"pine_snow": 1.0}, "tree_keep": 0.14, "forest_keep": 0.8,
			"grass": Color(0.75, 0.85, 0.95), "forest_grass": Color(0.6, 0.75, 0.8), "grass_count": 0, "flowers": 0,
			"props": {"rock_a": 0.5, "rock_b": 0.5}, "forest_props": {"ice_crystal": 1.0}, "glow_prop": "ice_crystal", "glow_color": Color(0.5, 0.85, 1.0),
			"sun": Color(0.85, 0.9, 1.0), "sun_energy": 0.95, "ambient": Color(0.45, 0.55, 0.82), "ambient_energy": 0.6, "lava": 0.0, "houses": ["house_snow", "house_snow"],
			"glow_threshold": 1.4, "exposure": 0.92}},
	"vulcao": {"name": "Abismo Vulcânico", "levels": "Nv 46-60", "min_level": 45, "hub": "Fortaleza de Obsidiana", "hub_style": "fortaleza",
		"npc": "Ferreiro Vulcan", "npc_model": "npc_volcano", "music": "music_volcano", "zones": ["fendas", "forja", "ninho"],
		"lake": {"c": Vector2(46, -50), "r": Vector2(17, 12), "type": "lava"},
		"regions": [{"type": "forest", "c": Vector2(52, 52), "r": 26.0}, {"type": "stone", "c": Vector2(-50, -50), "r": 20.0}, {"type": "stone", "c": Vector2(-30, 66), "r": 16.0}],
		"theme": {"ground": "ash", "path": "stone", "ground_tint": Color(0.85, 0.75, 0.75), "forest_tint": Color(0.8, 0.6, 0.6), "path_tint": Color(0.5, 0.42, 0.42), "stone_tint": Color(0.45, 0.35, 0.38),
			"trees": {"dead_tree_burnt": 1.0}, "forest_trees": {"dead_tree_burnt": 1.0}, "tree_keep": 0.08, "forest_keep": 0.45,
			"grass": Color(0, 0, 0), "forest_grass": Color(0, 0, 0), "grass_count": 0, "flowers": 0,
			"props": {"rock_a": 0.5, "rock_b": 0.3, "bones": 0.2}, "forest_props": {"fire_crystal": 1.0}, "glow_prop": "fire_crystal", "glow_color": Color(1.0, 0.4, 0.1),
			"sun": Color(1.0, 0.45, 0.3), "sun_energy": 0.8, "ambient": Color(0.48, 0.28, 0.38), "ambient_energy": 0.62, "lava": 1.0, "houses": ["house_dark", "house_dark"]}},
	# mapa do boss global (evento): uma arena grande para muitos jogadores, sem caça normal
	"covil": {"name": "Covil do Dragão", "levels": "Boss global", "min_level": 1, "hub": "Entrada do Covil", "hub_style": "fortaleza",
		"npc": "Arauto Kael", "npc_model": "npc_volcano", "music": "music_volcano", "zones": ["arena_dragao"], "event": true,
		"lake": {"c": Vector2(62, 58), "r": Vector2(10, 7), "type": "lava"},
		"regions": [{"type": "stone", "c": Vector2(0, -58), "r": 34.0}],
		"theme": {"ground": "ash", "path": "stone", "ground_tint": Color(0.8, 0.68, 0.66), "forest_tint": Color(0.75, 0.55, 0.55), "path_tint": Color(0.5, 0.42, 0.42), "stone_tint": Color(0.42, 0.32, 0.34),
			"trees": {"dead_tree_burnt": 1.0}, "forest_trees": {"dead_tree_burnt": 1.0}, "tree_keep": 0.03, "forest_keep": 0.1,
			"grass": Color(0, 0, 0), "forest_grass": Color(0, 0, 0), "grass_count": 0, "flowers": 0,
			"props": {"rock_a": 0.5, "bones": 0.5}, "forest_props": {"fire_crystal": 1.0}, "glow_prop": "fire_crystal", "glow_color": Color(1.0, 0.45, 0.15),
			"sun": Color(1.0, 0.5, 0.35), "sun_energy": 0.85, "ambient": Color(0.5, 0.3, 0.38), "ambient_energy": 0.62, "lava": 1.0, "houses": ["house_dark", "house_dark"]}},
	"masmorra": {"name": "Masmorra Sombria", "levels": "Masmorra", "min_level": 1, "hub": "Salão de Entrada", "hub_style": "fortaleza",
		"npc": "Guardiã Lira", "npc_model": "npc_volcano", "music": "music_ice", "zones": ["sala_masmorra"], "event": true,
		"lake": {"c": Vector2(62, 58), "r": Vector2(10, 7), "type": "lava"},
		"regions": [{"type": "stone", "c": Vector2(0, -58), "r": 34.0}],
		"theme": {"ground": "ash", "path": "stone", "ground_tint": Color(0.8, 0.68, 0.66), "forest_tint": Color(0.75, 0.55, 0.55), "path_tint": Color(0.5, 0.42, 0.42), "stone_tint": Color(0.42, 0.32, 0.34),
			"trees": {"dead_tree_burnt": 1.0}, "forest_trees": {"dead_tree_burnt": 1.0}, "tree_keep": 0.03, "forest_keep": 0.1,
			"grass": Color(0, 0, 0), "forest_grass": Color(0, 0, 0), "grass_count": 0, "flowers": 0,
			"props": {"rock_a": 0.5, "bones": 0.5}, "forest_props": {"ice_crystal": 1.0}, "glow_prop": "ice_crystal", "glow_color": Color(0.45, 0.6, 1.0),
			"sun": Color(0.55, 0.6, 1.0), "sun_energy": 0.85, "ambient": Color(0.3, 0.3, 0.5), "ambient_energy": 0.62, "lava": 0.0, "houses": ["house_dark", "house_dark"]}},
}

## Mercadinho do Jogo: imposto sobre cada venda (cai com o nível de quem vende), preço mínimo/máximo e anúncios por herói.
const MARKET := {"min_price": 5, "max_price": 100000, "max_listings": 10}


static func market_tax(level: int) -> float:
	if level >= 80:
		return 0.05
	if level >= 60:
		return 0.10
	return 0.20


## Guildas: criar custa gemas; até max_members; pontos com monstros (1) e boss global (dano/1000).
const GUILD := {"cost": 200, "max_members": 30}


## Forja: materiais (caem dos monstros/chefes), custo de fundir 3 → 1 de cima e o que desmontar devolve.
const MATERIALS := {"ferro": {"name": "Ferro", "rarity": "comum"}, "cristal": {"name": "Cristal", "rarity": "rara"},
	"essencia": {"name": "Essência", "rarity": "epica"}}
const FORGE := {
	"comum": {"to": "rara", "gold": 500, "mats": {"ferro": 5}},
	"rara": {"to": "epica", "gold": 5000, "mats": {"ferro": 10, "cristal": 3}},
	"epica": {"to": "lendaria", "gold": 50000, "mats": {"cristal": 10, "essencia": 2}},
}
const SALVAGE := {"comum": {"ferro": 1}, "rara": {"ferro": 3}, "epica": {"cristal": 2}, "lendaria": {"essencia": 1}}
## Chance de material por monstro (chefe sempre dá).
const MAT_DROP := {"mob": {"ferro": 0.18, "cristal": 0.02}, "boss": {"ferro": 3, "cristal": 2, "essencia": 0.15}}


## Nome do herói: até HERO_NAME_MAX letras; tira espaços repetidos e caracteres de controle.
const HERO_NAME_MAX := 18


static func clean_name(s: String) -> String:
	var out := ""
	for ch in s.strip_edges():
		if ch.unicode_at(0) >= 32 and not (ch == " " and out.ends_with(" ")):
			out += ch
	return out.substr(0, HERO_NAME_MAX).strip_edges()


## Masmorras: 3 por dia; 3 ondas e um chefe com os monstros do mapa do nível do herói; 10 minutos.
const DUNGEON := {"map": "masmorra", "zone": "sala_masmorra", "per_day": 3, "waves": [8, 10, 12], "minutes": 10,
	"boss_hp_mult": 3.0, "reward_gold_levels": 0.0, "reward_gems": 10, "reward_xp_levels": 0.35, "items": 2}

## Boss semanal da guilda: 1 vez por semana por herói (semana começa na segunda), só o chefe, bem mais forte.
const GUILD_BOSS := {"hp_mult": 12.0, "power": 1.5, "minutes": 10, "gems": 60, "mat_mult": 5.0, "items": 3,
	"table": "boss", "guild_points": 500, "xp_levels": 1.0}

## Dificuldades da masmorra: força dos monstros, prêmio e ondas extras.
const DUNGEON_DIFF := {
	"normal": {"name": "Normal", "power": 1.0, "reward": 1.0, "extra_wave": 0, "table": "boss"},
	"dificil": {"name": "Difícil", "power": 2.5, "reward": 2.0, "extra_wave": 0, "table": "boss"},
	"pesadelo": {"name": "Pesadelo", "power": 6.0, "reward": 4.0, "extra_wave": 1, "table": "boss"},
}


## Mapa da masmorra do bioma (masmorra_<bioma>; os mapas base usam "masmorra").
static func dungeon_map_for(map_id: String) -> String:
	var b := String(MAPS.get(map_id, {}).get("biome", ""))
	return "masmorra_" + b if b != "" and MAPS.has("masmorra_" + b) else "masmorra"


static func is_dungeon(map_id: String) -> bool:
	return map_id.begins_with("masmorra")


## Loja (tecla L). Preços em gemas (moeda premium). Depois o banco de dados/pagamento credita as gemas
## (ver scripts/shop.gd: toda compra passa por Shop.buy). "max" = quantas vezes dá para comprar (0 = sem limite).
const SHOP := [
	{"id": "runa_forca", "name": "Runa da Força", "desc": "+5% de ataque para sempre", "price": 120, "kind": "bonus", "stat": "atk", "amount": 0.05, "max": 20, "color": Color(1.0, 0.45, 0.3)},
	{"id": "runa_vigor", "name": "Runa do Vigor", "desc": "+5% de vida máxima para sempre", "price": 120, "kind": "bonus", "stat": "hp", "amount": 0.05, "max": 20, "color": Color(0.45, 1.0, 0.45)},
	{"id": "runa_mente", "name": "Runa da Mente", "desc": "+5% de mana máxima para sempre", "price": 90, "kind": "bonus", "stat": "mp", "amount": 0.05, "max": 20, "color": Color(0.45, 0.7, 1.0)},
	{"id": "botas_vento", "name": "Botas do Vento", "desc": "+3% de velocidade para sempre", "price": 100, "kind": "bonus", "stat": "speed", "amount": 0.03, "max": 10, "color": Color(0.8, 1.0, 0.95)},
	{"id": "arma_lendaria", "name": "Arma Lendária", "desc": "Arma lendária da sua classe (o melhor ataque)", "price": 350, "kind": "item", "slot": "weapon", "rarity": "lendaria", "max": 0, "color": Color(1.0, 0.8, 0.3)},
	{"id": "armadura_lendaria", "name": "Conjunto Lendário", "desc": "Elmo, peitoral, calças, luvas e botas lendários da sua classe", "price": 600, "kind": "item", "slot": "armor_set", "rarity": "lendaria", "max": 0, "color": Color(1.0, 0.8, 0.3)},
	{"id": "joias_lendarias", "name": "Joias Lendárias", "desc": "Colar, brincos e 2 anéis lendários", "price": 450, "kind": "item", "slot": "jewel_set", "rarity": "lendaria", "max": 0, "color": Color(1.0, 0.85, 0.45)},
	{"id": "pedra_protecao", "name": "Pedra de Proteção ×5", "desc": "Se o refino falhar, a pedra quebra no lugar do item (usa sozinha)", "price": 60, "kind": "stone", "amount": 5, "max": 0, "color": Color(0.6, 0.85, 1.0)},
	{"id": "pocao_sabedoria", "name": "Poção de Sabedoria", "desc": "Sobe 1 nível na hora", "price": 80, "kind": "level", "amount": 1, "max": 0, "color": Color(0.8, 0.5, 1.0)},
	{"id": "pergaminho_xp", "name": "Pergaminho de XP em Dobro", "desc": "XP em dobro por 30 minutos", "price": 60, "kind": "xp_boost", "minutes": 30, "max": 0, "color": Color(1.0, 0.9, 0.4)},
	{"id": "saco_ouro", "name": "Saco de Ouro", "desc": "+10.000 de ouro", "price": 40, "kind": "gold", "amount": 10000, "max": 0, "color": Color(1.0, 0.82, 0.3)},
	{"id": "pet_coruja", "name": "Mascote: Coruja Mística", "desc": "Atira raios mágicos no inimigo mais perto. +5% de XP", "price": 250, "kind": "pet", "model": "pet_owl", "func": "attack", "cd": 1.6, "dmg": 0.35, "xp": 0.05, "max": 1, "color": Color(0.75, 0.6, 1.0)},
	{"id": "pet_aguaviva", "name": "Mascote: Água-viva", "desc": "Cura você quando a vida cai. +5% de XP", "price": 250, "kind": "pet", "model": "pet_jelly", "func": "heal", "cd": 4.0, "heal": 0.06, "xp": 0.05, "max": 1, "color": Color(0.5, 0.85, 1.0)},
	{"id": "pet_peixe", "name": "Mascote: Peixe Dourado", "desc": "Puxa ouro e itens de longe. +8% de XP", "price": 400, "kind": "pet", "model": "pet_fish", "func": "loot", "cd": 1.0, "xp": 0.08, "max": 1, "color": Color(1.0, 0.75, 0.3)},
	{"id": "pet_lobinho", "name": "Mascote: Lobinho", "desc": "Corre e morde os inimigos. +5% de XP", "price": 300, "kind": "pet", "model": "wolf", "scale": 0.35, "fly": false, "func": "bite", "cd": 1.2, "dmg": 0.45, "xp": 0.05, "max": 1, "color": Color(0.8, 0.8, 0.85)},
	{"id": "pet_dragaozinho", "name": "Mascote: Dragãozinho", "desc": "Cospe bolas de fogo em área. +8% de XP", "price": 500, "kind": "pet", "model": "dragon_whelp", "scale": 0.3, "func": "fire", "cd": 3.5, "dmg": 0.6, "xp": 0.08, "max": 1, "color": Color(1.0, 0.5, 0.2)},
	{"id": "mount_lobo", "name": "Montaria: Lobo Alfa", "desc": "+40% de velocidade montado", "price": 300, "kind": "mount", "model": "wolf_alpha", "height": 1.5, "speed": 0.4, "max": 1, "color": Color(0.75, 0.75, 0.8)},
	{"id": "mount_escorpiao", "name": "Montaria: Escorpião Rubi", "desc": "+50% de velocidade e recupera 2% de vida/s montado", "price": 500, "kind": "mount", "model": "scorpion_queen", "height": 1.1, "seat": 0.4, "speed": 0.5, "regen": 0.02, "max": 1, "color": Color(1.0, 0.35, 0.3)},
	{"id": "mount_golem", "name": "Montaria: Golem de Magma", "desc": "+45% de velocidade e 15% menos dano montado", "price": 600, "kind": "mount", "model": "golem_magma", "height": 1.9, "speed": 0.45, "def": 0.15, "max": 1, "color": Color(1.0, 0.55, 0.2)},
	{"id": "mount_dragao", "name": "Montaria: Dragão de Lava", "desc": "Voa! +70% de velocidade e deixa um rastro de fogo que queima os inimigos", "price": 900, "kind": "mount", "model": "dragon_lava", "height": 1.8, "seat": 0.4, "speed": 0.7, "fly": 1.2, "trail": 0.25, "max": 1, "color": Color(1.0, 0.45, 0.1)},
	{"id": "pet_slime", "name": "Mascote: Slime Guardião", "desc": "Cria um escudo em você no combate. +5% de XP", "price": 350, "kind": "pet", "model": "slime", "scale": 0.4, "fly": false, "func": "shield", "cd": 12.0, "heal": 0.1, "xp": 0.05, "max": 1, "color": Color(0.4, 1.0, 0.6)},
]
## Gemas grátis dadas pelo jogo (para testar a loja sem pagamento).
const GEMS_START := 300
const GEMS_PER_LEVEL := 5

const BASE_MAP_ORDER := ["vale", "deserto", "gelo", "vulcao"]

## Zonas de caça. "center" e "boss_pos" ficam nas pontas das trilhas.
const BASE_ZONES := {
	"sala_masmorra": {"map": "masmorra", "name": "Salão Sombrio", "levels": "Masmorra", "lvl": Vector2i(1, 1000), "center": Vector3(0, 0, -50), "radius": 26.0,
		"enemy": "dragon_hatchling", "boss": "dragon_hatchling", "count": 0, "boss_pos": Vector3(0, 0, -56), "color": Color(0.5, 0.6, 1.0)},
	"arena_dragao": {"map": "covil", "name": "Ninho do Dragão Ancestral", "levels": "Boss global", "lvl": Vector2i(1, 60), "center": Vector3(0, 0, -56), "radius": 30.0,
		"enemy": "dragon_hatchling", "boss": "dragon_global", "count": 0, "boss_pos": Vector3(0, 0, -62), "color": Color(1.0, 0.45, 0.15)},
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

## Os Sete Reinos (+ Aetherion, o reino esquecido). Cada mapa é uma cidade de um reino: os 4 mapas base pelo
## `BASE_KINGDOM` e os gerados pelo bioma (`biome`). Cidades dos mapas gerados: `cities[volta]`.
const KINGDOM_ORDER := ["eloreth", "seryth", "valdrath", "drakaris", "thalyss", "vyndara", "sombras", "aetherion"]
const KINGDOMS := {
	"eloreth": {"name": "Eloreth", "motto": "A beleza é força", "ruler": "Lysara", "title": "Rainha de Eloreth", "biome": "encantada",
		"color": Color(0.45, 0.9, 0.55), "about": "Florestas encantadas e natureza consciente. Cura e manipulação da natureza.",
		"cities": ["Bosque de Lysara", "Clareira das Vozes", "Raízes Antigas", "Jardim de Prata", "Vale dos Salgueiros", "Coração Verde", "Trono de Folhas", "Árvore-Mãe"]},
	"seryth": {"name": "Seryth", "motto": "O conhecimento liberta", "ruler": "Selene", "title": "Herdeira de Seryth", "biome": "cristal",
		"color": Color(1.0, 0.8, 0.45), "about": "Desertos, cidades antigas e bibliotecas de conhecimento proibido.",
		"cities": ["Biblioteca de Areia", "Oásis das Profecias", "Arquivo Proibido", "Torre dos Registros", "Dunas de Cristal", "Cidade dos Escribas", "Observatório de Selene", "Cripta do Saber"]},
	"valdrath": {"name": "Valdrath", "motto": "O poder é lei", "ruler": "Kaeldryn", "title": "Príncipe de Valdrath", "biome": "tundra",
		"color": Color(0.6, 0.85, 1.0), "about": "Gelo, montanhas e fortalezas. Estratégia, defesa e resistência.",
		"cities": ["Fortaleza de Gelo", "Passo Branco", "Cidadela Norte", "Muralha Eterna", "Forte Kaeldryn", "Bastião Congelado", "Torre do Inverno", "Trono de Gelo"]},
	"drakaris": {"name": "Drakaris", "motto": "O fogo nos guia", "ruler": "Darius", "title": "Príncipe de Drakaris", "biome": "brasas",
		"color": Color(1.0, 0.45, 0.25), "about": "Vulcões, cidades de pedra negra e linhagens ligadas aos dragões.",
		"cities": ["Ninho Rubro", "Cidade de Pedra Negra", "Forja dos Dragões", "Picos de Cinza", "Rio de Magma", "Arena de Darius", "Covil Ancestral", "Coroa de Fogo"]},
	"thalyss": {"name": "Thalyss", "motto": "A liberdade é vida", "ruler": "Emberlyn", "title": "General de Thalyss", "biome": "pantano",
		"color": Color(0.4, 0.8, 0.95), "about": "Rios, cachoeiras e comunidades independentes. Magia elemental e mobilidade.",
		"cities": ["Vila das Cachoeiras", "Margem Livre", "Delta Rebelde", "Ponte dos Barqueiros", "Lagoa das Brumas", "Acampamento de Emberlyn", "Queda d'Água Sagrada", "Foz da Liberdade"]},
	"vyndara": {"name": "Vyndara", "motto": "A honra nos mantém", "ruler": "Rhaegar", "title": "Príncipe de Vyndara", "biome": "celeste",
		"color": Color(0.92, 0.92, 1.0), "about": "Montanhas, muralhas e fortalezas quase impenetráveis. Cavalaria e guerreiros de elite.",
		"cities": ["Muralha Alta", "Picos da Honra", "Fortaleza Celeste", "Quartel dos Cavaleiros", "Passo da Espada", "Cidadela de Mármore", "Salão de Rhaegar", "Pico Inalcançável"]},
	"sombras": {"name": "Sombras", "motto": "O caos é eterno", "ruler": "Nyx", "title": "Senhor das Sombras", "biome": "sombrias",
		"color": Color(0.7, 0.5, 1.0), "about": "Terras ocultas e cidades envoltas em mistério. Ilusão, espionagem e magia proibida.",
		"cities": ["Fronteira Velada", "Cidade das Máscaras", "Bosque Sem Lua", "Labirinto de Nyx", "Mercado Oculto", "Torre dos Sussurros", "Vale do Esquecimento", "Trono Vazio"]},
	"aetherion": {"name": "Aetherion", "motto": "O reino esquecido", "ruler": "???", "title": "Aquele que ainda vive lá", "biome": "estelar",
		"color": Color(0.85, 0.75, 1.0), "about": "Não aparece em nenhum mapa. Foi escondido da realidade — e alguém ainda vive lá.",
		"cities": ["Fenda de Aetherion", "Ruínas Sem Nome", "Céu Partido", "Ponte do Vazio", "Santuário Apagado", "Eco Estelar", "Portão Esquecido", "Coração de Aetherion"]},
}
## Os sete personagens principais (retratos em textures/portraits/<chave>.png, recortados do documento do dono).
const CHARACTERS := {
	"kaeldryn": {"name": "Kaeldryn", "title": "Príncipe de Valdrath", "kingdom": "valdrath"},
	"lysara": {"name": "Lysara", "title": "Rainha de Eloreth", "kingdom": "eloreth"},
	"darius": {"name": "Darius", "title": "Príncipe de Drakaris", "kingdom": "drakaris"},
	"emberlyn": {"name": "Emberlyn", "title": "General de Thalyss", "kingdom": "thalyss"},
	"rhaegar": {"name": "Rhaegar", "title": "Príncipe de Vyndara", "kingdom": "vyndara"},
	"selene": {"name": "Selene", "title": "Herdeira de Seryth", "kingdom": "seryth"},
	"nyx": {"name": "Nyx", "title": "Senhor das Sombras", "kingdom": "sombras"},
}


## Skins (só aparência: troca elmo, peitoral, calças, luvas e botas; os atributos continuam vindo do equipamento).
## Vendidas na loja (L) por gemas; as mais raras pedem requisitos para comprar E para usar. Modelo de cada uma:
## blender/make_skins.py → models/hero_<classe>_<id>_<encaixe>.glb; foto da loja em textures/skins/<id>.png.
## Só aparecem na loja as que já têm modelo.
const SKIN_RARITY := {
	"rara": {"name": "Rara", "price": 400, "level": 10, "color": Color(0.35, 0.62, 1.0)},
	"epica": {"name": "Épica", "price": 1000, "level": 40, "color": Color(0.72, 0.42, 1.0)},
	"lendaria": {"name": "Lendária", "price": 2500, "level": 100, "loyal": true, "color": Color(1.0, 0.76, 0.26)},
	"mitica": {"name": "Mítica", "price": 6000, "level": 250, "loyal": true, "fragments": 4, "color": Color(1.0, 0.35, 0.45)},
}
## Reino da skin: com "loyal" na raridade, só quem jurou lealdade a esse reino compra/usa. Sem reino = sem essa exigência.
const SKINS := [
	{"id": "sk_eloreth", "cls": "druida", "name": "Guardiã de Eloreth", "rarity": "epica", "kingdom": "eloreth", "desc": "Vestes prateadas com folhas de cristal e uma coroa de galhos que brilha."},
	{"id": "sk_cinzas", "cls": "druida", "name": "Xamã das Cinzas", "rarity": "rara", "kingdom": "drakaris", "desc": "Pele de dragão, chifres de obsidiana e brasas nas mãos."},
	{"id": "sk_inverno", "cls": "druida", "name": "Druida do Inverno", "rarity": "rara", "kingdom": "valdrath", "desc": "Manto de pele branca e cajado de gelo."},
	{"id": "sk_areias", "cls": "druida", "name": "Oráculo das Areias", "rarity": "epica", "kingdom": "seryth", "desc": "Túnica dourada com hieróglifos e véu."},
	{"id": "sk_ninfa", "cls": "druida", "name": "Ninfa das Cachoeiras", "rarity": "rara", "kingdom": "thalyss", "desc": "Roupa azul-água, cabelo com gotas e escamas nos braços."},
	{"id": "sk_bruxa", "cls": "druida", "name": "Bruxa do Pântano Sombrio", "rarity": "epica", "kingdom": "sombras", "desc": "Capuz rasgado, cogumelos brilhantes e olhos roxos."},
	{"id": "sk_primavera", "cls": "druida", "name": "Avatar da Primavera", "rarity": "lendaria", "kingdom": "", "desc": "Vestido de pétalas com borboletas em volta."},
	{"id": "sk_estelar_dr", "cls": "druida", "name": "Druida Estelar", "rarity": "mitica", "kingdom": "", "desc": "Manto de céu noturno com constelações que piscam."},
	{"id": "sk_corrompida", "cls": "druida", "name": "Rainha Corrompida", "rarity": "mitica", "kingdom": "", "desc": "Metade viva, metade podre, com veias roxas d'A Origem."},
	{"id": "sk_colheita", "cls": "druida", "name": "Colheita Dourada", "rarity": "lendaria", "kingdom": "", "desc": "Chapéu de palha, lanterna de abóbora e folhas de outono."},
	{"id": "sk_corvo", "cls": "assassino", "name": "Lâmina das Sombras", "rarity": "epica", "kingdom": "sombras", "desc": "Couraça preta, máscara de corvo e fumaça roxa."},
	{"id": "sk_ninja_deserto", "cls": "assassino", "name": "Ninja do Deserto", "rarity": "rara", "kingdom": "seryth", "desc": "Turbante, lenço vermelho e adagas curvas."},
	{"id": "sk_cacador", "cls": "assassino", "name": "Caçador de Valdrath", "rarity": "rara", "kingdom": "valdrath", "desc": "Capa de lobo branco e lâminas de gelo."},
	{"id": "sk_escamas", "cls": "assassino", "name": "Escamas de Dragão", "rarity": "epica", "kingdom": "drakaris", "desc": "Armadura de escamas vermelhas e adagas como dentes."},
	{"id": "sk_ladrao", "cls": "assassino", "name": "Ladrão de Thalyss", "rarity": "rara", "kingdom": "thalyss", "desc": "Pirata elegante: chapéu de pena e brinco de ouro."},
	{"id": "sk_ordem", "cls": "assassino", "name": "Espectro da Ordem", "rarity": "lendaria", "kingdom": "", "desc": "Túnica branca manchada, máscara de porcelana e runas de sangue."},
	{"id": "sk_samurai", "cls": "assassino", "name": "Samurai da Lua", "rarity": "epica", "kingdom": "vyndara", "desc": "Armadura laminada azul-marinho com meia-lua nas costas."},
	{"id": "sk_arlequim", "cls": "assassino", "name": "Arlequim", "rarity": "lendaria", "kingdom": "", "desc": "Losangos pretos e vermelhos, máscara sorridente e guizos."},
	{"id": "sk_cosmico", "cls": "assassino", "name": "Assassino Cósmico", "rarity": "mitica", "kingdom": "", "desc": "Corpo escuro com nebulosa por dentro e lâminas de luz."},
	{"id": "sk_ceifador", "cls": "assassino", "name": "Ceifador", "rarity": "mitica", "kingdom": "", "desc": "Capuz, foice dupla e caveira brilhante."},
	{"id": "sk_engenheiro", "cls": "mecanico", "name": "Engenheiro de Drakaris", "rarity": "epica", "kingdom": "drakaris", "desc": "Armadura de bronze com caldeira acesa nas costas."},
	{"id": "sk_inventor", "cls": "mecanico", "name": "Inventor de Seryth", "rarity": "rara", "kingdom": "seryth", "desc": "Óculos de latão, mochila de pergaminhos e engrenagens douradas."},
	{"id": "sk_exotraje", "cls": "mecanico", "name": "Exotraje de Valdrath", "rarity": "epica", "kingdom": "valdrath", "desc": "Armadura pesada branca e azul com vapor gelado."},
	{"id": "sk_sucateiro", "cls": "mecanico", "name": "Sucateiro", "rarity": "rara", "kingdom": "", "desc": "Peças remendadas, ferrugem e um pequeno robô no ombro."},
	{"id": "sk_mecha", "cls": "mecanico", "name": "Mecha Real de Vyndara", "rarity": "lendaria", "kingdom": "vyndara", "desc": "Cavaleiro mecânico com elmo de crista e escudo hidráulico."},
	{"id": "sk_louco", "cls": "mecanico", "name": "Cientista Louco", "rarity": "epica", "kingdom": "sombras", "desc": "Jaleco rasgado, tanques de líquido verde e raios."},
	{"id": "sk_piloto", "cls": "mecanico", "name": "Piloto de Dirigível", "rarity": "rara", "kingdom": "thalyss", "desc": "Jaqueta de couro, cachecol e hélice nas costas."},
	{"id": "sk_ciborgue", "cls": "mecanico", "name": "Ciborgue da Origem", "rarity": "mitica", "kingdom": "", "desc": "Placas de cristal roxo e olho brilhando."},
	{"id": "sk_golem_dourado", "cls": "mecanico", "name": "Golem Dourado", "rarity": "mitica", "kingdom": "", "desc": "Corpo de ouro polido com um núcleo de sol no peito."},
	{"id": "sk_natal", "cls": "mecanico", "name": "Natal a Vapor", "rarity": "lendaria", "kingdom": "", "desc": "Gorro vermelho, renas de lata e neve mecânica."},
	{"id": "sk_almirante", "cls": "nautico", "name": "Almirante de Thalyss", "rarity": "epica", "kingdom": "thalyss", "desc": "Casaca azul com dragonas de ouro e chapéu tricórnio."},
	{"id": "sk_pirata", "cls": "nautico", "name": "Pirata das Sombras", "rarity": "epica", "kingdom": "sombras", "desc": "Tapa-olho, casaco preto e caveira roxa."},
	{"id": "sk_baleeiro", "cls": "nautico", "name": "Baleeiro de Valdrath", "rarity": "rara", "kingdom": "valdrath", "desc": "Capa de pele de foca e barba congelada."},
	{"id": "sk_mares", "cls": "nautico", "name": "Senhor das Marés", "rarity": "lendaria", "kingdom": "", "desc": "Armadura de coral e conchas, com um polvo no ombro."},
	{"id": "sk_corsario", "cls": "nautico", "name": "Corsário do Deserto", "rarity": "rara", "kingdom": "seryth", "desc": "Marinheiro das dunas com lenço de areia e âncora dourada."},
	{"id": "sk_kraken", "cls": "nautico", "name": "Kraken Desperto", "rarity": "mitica", "kingdom": "", "desc": "Tentáculos nas costas, pele azul-escura e olhos de abismo."},
	{"id": "sk_fantasma", "cls": "nautico", "name": "Capitão Fantasma", "rarity": "lendaria", "kingdom": "", "desc": "Translúcido verde-azulado, com correntes e lanterna."},
	{"id": "sk_tritao", "cls": "nautico", "name": "Tritão Dourado", "rarity": "mitica", "kingdom": "", "desc": "Escamas douradas e coroa de tridente."},
	{"id": "sk_navegador", "cls": "nautico", "name": "Navegador Estelar", "rarity": "epica", "kingdom": "vyndara", "desc": "Casaco de astrolábio e bússola flutuante."},
	{"id": "sk_surfista", "cls": "nautico", "name": "Surfista de Verão", "rarity": "rara", "kingdom": "", "desc": "Bermuda florida, prancha nas costas e óculos escuros."},
]


static func skin(id: String) -> Dictionary:
	for s in SKINS:
		if String(s["id"]) == id:
			return s
	return {}


## A skin já tem modelo (só essas aparecem na loja).
static func skin_ready(s: Dictionary) -> bool:
	return ResourceLoader.exists("res://models/hero_%s_%s_chest.glb" % [String(s["cls"]), String(s["id"])])


## Requisitos da skin ("" = cumpre). frag_count = quantos fragmentos o herói tem.
static func skin_why_not(s: Dictionary, cls: String, level: int, kingdom: String, frag_count: int) -> String:
	var r: Dictionary = SKIN_RARITY[String(s["rarity"])]
	if String(s["cls"]) != cls:
		return "Skin de outra classe"
	if level < int(r["level"]):
		return "Precisa do nível %d" % int(r["level"])
	var kg := String(s.get("kingdom", ""))
	if bool(r.get("loyal", false)) and kg != "" and kingdom != kg:
		return "Precisa ser leal a %s" % String(KINGDOMS[kg]["name"])
	if frag_count < int(r.get("fragments", 0)):
		return "Precisa de %d fragmentos" % int(r["fragments"])
	return ""


static func skin_req_text(s: Dictionary) -> String:
	var r: Dictionary = SKIN_RARITY[String(s["rarity"])]
	var parts: Array = ["nível %d" % int(r["level"])]
	var kg := String(s.get("kingdom", ""))
	if bool(r.get("loyal", false)) and kg != "":
		parts.append("lealdade a %s" % String(KINGDOMS[kg]["name"]))
	if int(r.get("fragments", 0)) > 0:
		parts.append("%d fragmentos" % int(r["fragments"]))
	return "Requisitos: " + ", ".join(parts)


## Lealdade a um reino (tecla H): bônus da especialidade do reino; trocar custa gemas e só 1 vez a cada 7 dias.
## Guerra dos Reinos (online, semanal): pontos por monstro/chefe/masmorra/duelo; o 1º da semana ganha a Coroa (+XP).
const KINGDOM_BONUS := {"eloreth": {"hp": 0.05}, "seryth": {"xp": 0.05}, "valdrath": {"def": 0.02}, "drakaris": {"atk": 0.05},
	"thalyss": {"speed": 0.03, "mp": 0.03}, "vyndara": {"atk": 0.025, "hp": 0.025}, "sombras": {"gold": 0.05, "mp": 0.03}}
const KINGDOM_WAR := {"change_gems": 200, "change_days": 7, "kill": 1, "boss": 10, "dungeon": 50, "duel": 30, "crown_xp": 0.10}
static var CROWN := ""   # reino com a Coroa nesta semana (o servidor manda)


static func bonus_text(b: Dictionary) -> String:
	var parts: Array = []
	for k in b:
		parts.append("+%s%% %s" % [str(snappedf(float(b[k]) * 100.0, 0.1)), String(BONUS_NAMES.get(k, k))])
	return ", ".join(parts)


## Fragmentos dos reinos (tecla Y): bônus por nível do fragmento (nível = cidades do reino concluídas na campanha).
const FRAGMENT_MAX := 9
const FRAGMENTS := {
	"eloreth": {"name": "Fragmento de Eloreth", "bonus": {"hp": 0.03}, "lore": "a vida das florestas ancestrais"},
	"seryth": {"name": "Fragmento de Seryth", "bonus": {"xp": 0.03}, "lore": "o saber das bibliotecas proibidas"},
	"valdrath": {"name": "Fragmento de Valdrath", "bonus": {"def": 0.012}, "lore": "a resistência das fortalezas de gelo"},
	"drakaris": {"name": "Fragmento de Drakaris", "bonus": {"atk": 0.03}, "lore": "o fogo dos dragões"},
	"thalyss": {"name": "Fragmento de Thalyss", "bonus": {"speed": 0.015, "mp": 0.02}, "lore": "a liberdade dos rios"},
	"vyndara": {"name": "Fragmento de Vyndara", "bonus": {"atk": 0.015, "hp": 0.015}, "lore": "a honra dos cavaleiros de elite"},
	"sombras": {"name": "Fragmento das Sombras", "bonus": {"mp": 0.04, "gold": 0.03}, "lore": "os segredos guardados no escuro"},
	"aetherion": {"name": "Fragmento de Aetherion", "bonus": {"atk": 0.01, "hp": 0.01, "def": 0.005, "xp": 0.01}, "lore": "todos os elementos ao mesmo tempo"},
}
const BONUS_NAMES := {"hp": "vida", "mp": "mana", "atk": "ataque", "def": "defesa", "speed": "velocidade", "xp": "XP", "gold": "ouro"}


static func fragment_bonus(kg: String, n: int) -> Dictionary:
	var out := {}
	for k in FRAGMENTS[kg]["bonus"]:
		out[k] = float(FRAGMENTS[kg]["bonus"][k]) * clampi(n, 0, FRAGMENT_MAX)
	return out


static func fragment_text(kg: String, n: int) -> String:
	var parts: Array = []
	var b := fragment_bonus(kg, n)
	for k in b:
		parts.append("+%s%% %s" % [str(snappedf(float(b[k]) * 100.0, 0.1)), String(BONUS_NAMES.get(k, k))])
	return ", ".join(parts)


## O que cada um diz ao herói na sua capital (modelo 3D em models/npc_<chave>.glb, feito por blender/make_sete.py).
const CHARACTER_LINES := {
	"kaeldryn": "Valdrath não pede ajuda — mas também não recusa um bom guerreiro. O fragmento do meu reino sumiu, e eu vou descobrir quem o levou. Mostre que posso confiar em você.",
	"lysara": "As árvores ancestrais falam comigo, viajante. Elas dizem que os fragmentos estão enfraquecendo... e que algo está acordando. Eloreth precisa de você mais do que admite.",
	"darius": "Meus dragões não enlouqueceram. Eles estão com medo — e um dragão com medo é a coisa mais perigosa deste mundo. Se for lutar por Drakaris, lute sem hesitar.",
	"emberlyn": "Em Thalyss ninguém ganha nada por nascer nobre. Eu conquistei minha patente com a espada — e você vai conquistar o respeito do mesmo jeito.",
	"rhaegar": "Honra é fazer o que é certo mesmo quando ninguém está olhando. Vyndara guarda segredos que me envergonham... mas a guerra que vem é maior que eles.",
	"selene": "Eu vejo pedaços do futuro, e cada visão me custa uma lembrança. Numa delas, os sete reinos caem. Em outra, você está ao nosso lado. Escolha bem o seu caminho.",
	"nyx": "Todos acham que as Sombras escondem o mal. Nós escondemos a verdade — porque os outros reinos não aguentariam ouvi-la. Ainda não é hora de você saber tudo.",
}


## Personagem que fica na capital do reino deste mapa: a cidade base do reino ou a primeira cidade gerada dele.
static func royal_of(map_id: String) -> String:
	var kg := kingdom_of(map_id)
	if kg == "":
		return ""
	var seat := ""
	for b in BASE_KINGDOM:
		if String(BASE_KINGDOM[b]) == kg:
			seat = String(b)
	if seat == "":
		for id in MAP_ORDER:
			if kingdom_of(String(id)) == kg:
				seat = String(id)
				break
	if seat != map_id:
		return ""
	for k in CHARACTERS:
		if String(CHARACTERS[k]["kingdom"]) == kg:
			return String(k)
	return ""


## Quem "fala" numa missão: o primeiro personagem citado no texto; senão o soberano do reino ("" em Aetherion).
static func speaker_for(text: String, kingdom: String) -> String:
	var best := ""
	var at := 1 << 30
	for k in CHARACTERS:
		var i := text.find(String(CHARACTERS[k]["name"]))
		if i >= 0 and i < at:
			at = i
			best = String(k)
	if best == "":
		for k in CHARACTERS:
			if String(CHARACTERS[k]["kingdom"]) == kingdom:
				best = String(k)
	return best


const BASE_KINGDOM := {"vale": "eloreth", "deserto": "seryth", "gelo": "valdrath", "vulcao": "drakaris"}


static func _kingdom_by_biome(biome: String) -> String:
	for k in KINGDOMS:
		if String(KINGDOMS[k]["biome"]) == biome:
			return String(k)
	return "eloreth"


static func _city(kg: String, round_n: int) -> String:
	return String(KINGDOMS[kg]["cities"][round_n % 8])


static func kingdom_of(map_id: String) -> String:
	var md: Dictionary = MAPS.get(map_id, {})
	return String(md.get("kingdom", BASE_KINGDOM.get(map_id, "")))


## A história: 5 atos pela faixa de nível (o último mapa base termina o Ato I).
const ACTS := [
	{"to": 60, "name": "Ato I — O Despertar"},
	{"to": 300, "name": "Ato II — A Aliança dos Inimigos"},
	{"to": 550, "name": "Ato III — Os Dragões e a Guerra das Coroas"},
	{"to": 800, "name": "Ato IV — A Verdade dos Sete Fragmentos"},
	{"to": 1000, "name": "Ato V — O Último Reino"},
]


static func act_of(level: int) -> int:
	for i in ACTS.size():
		if level <= int(ACTS[i]["to"]):
			return i
	return ACTS.size() - 1


## Ato I (mapas base): falas de cada zona [caçada, coleta, chefe].
const STORY_BASE := {
	"campo": ["Viajante, algo terrível aconteceu esta noite: o fragmento de Valdrath desapareceu, e as florestas de Eloreth começaram a adoecer. Até os slimes do Campo das Flores enlouqueceram. Ajude a vila: derrote-os.",
		"A Rainha Lysara pediu amostras da gosma: ela diz que a doença das árvores está nela. Recolha a gosma dos slimes.",
		"A gosma vem de um só lugar: o Slime Rei cresceu com a magia que vaza do fragmento perdido. Acabe com ele."],
	"floresta": ["Lysara ouve as árvores ancestrais, e elas gritam. Os lobos da Floresta Sombria atacam qualquer um. Abra caminho.",
		"As presas dos lobos estão negras, como as raízes que apodrecem. Recolha-as para os sábios de Eloreth.",
		"O Lobo Alfa carrega uma marca estranha no pescoço: um símbolo de sangue. Derrote-o e descubra de onde ele veio."],
	"ruinas": ["As Ruínas Antigas eram um templo da primeira guerra. Os golens de pedra acordaram sozinhos. Derrube-os.",
		"Os núcleos dos golens brilham com a mesma luz do fragmento perdido. Recolha-os: Selene, de Seryth, vai querer vê-los.",
		"O Golem Guardião protege uma mensagem gravada: \"Quando o sétimo fragmento se apagar, aquilo que foi enterrado voltará a caminhar entre os vivos.\" Derrote-o e leve a mensagem a Seryth."],
	"dunas": ["Bem-vindo a Seryth. Selene recebeu a sua mensagem e convocou os sete reinos para uma reunião. Mas os escorpiões cercam as dunas — limpe a estrada para os emissários.",
		"Os ferrões dos escorpiões guardam um veneno que só existe nos registros da primeira guerra. Selene precisa deles.",
		"A Rainha Escorpião foi enviada para impedir a reunião. Alguém não quer que os reinos se unam. Derrote-a."],
	"cemiterio": ["No Cemitério de Areia descansam os soldados da primeira guerra — e eles se levantaram. Derrube os esqueletos.",
		"Os ossos antigos têm runas de uma ordem secreta: a Ordem do Primeiro Sangue. Recolha-os para Selene decifrar.",
		"O Rei Esqueleto foi um soberano da primeira guerra. Selene diz que ele sabe onde os fragmentos foram escondidos. Derrote-o."],
	"templo": ["A reunião dos sete aconteceu, mas Kaeldryn e Darius brigaram pela liderança. Enquanto isso, o Templo Soterrado acordou. Destrua os golens de areia.",
		"Os núcleos de areia guardam pedaços de um mapa antigo. Recolha-os: ele mostra o caminho até Valdrath.",
		"O Colosso guarda a passagem para o norte. Derrote-o e siga para Valdrath, onde o primeiro fragmento sumiu."],
	"tundra": ["Valdrath, o reino do gelo. Kaeldryn não confia em estranhos, mas precisa de ajuda: as matilhas de lobos de gelo cercam as fortalezas.",
		"As presas dos lobos de gelo guardam rastros de magia: alguém passou por aqui com o fragmento. Recolha-as.",
		"O Lobo Glacial segue o cheiro do ladrão. Derrote-o e Kaeldryn vai ouvir você."],
	"cavernas": ["Kaeldryn acredita que Nyx, Senhor das Sombras, roubou o fragmento. Antes de acusá-lo, investigue as cavernas dos yetis.",
		"O pelo dos yetis está coberto de cinza vulcânica — o ladrão veio do sul, de Drakaris, não das Sombras. Recolha as provas.",
		"O Yeti Ancião guarda a entrada do glaciar. Derrote-o e convença Kaeldryn a não declarar guerra."],
	"glaciar": ["No Glaciar de Cristal, os golens de gelo protegem o lugar onde o fragmento ficava. Destrua-os.",
		"Os núcleos de gelo guardam o último eco do fragmento. Recolha-os: com eles, Selene pode rastreá-lo.",
		"O Golem de Cristal tenta apagar o rastro. Derrote-o: o fragmento foi levado para Drakaris."],
	"fendas": ["Drakaris, o reino do fogo. Darius jura que os dragões enlouqueceram. As fendas estão tomadas por diabretes — abra caminho.",
		"Os chifres dos diabretes têm o símbolo da Ordem do Primeiro Sangue. A Ordem está aqui. Recolha as provas.",
		"O Senhor dos Diabretes serve à Ordem. Derrote-o e descubra o que ela quer em Drakaris."],
	"forja": ["A antiga forja de Drakaris foi tomada por golens de magma. A Ordem quer usar a forja para fundir os fragmentos. Impeça.",
		"Os núcleos de magma guardam pedaços do fragmento de Valdrath, já derretido pela Ordem. Recupere-os.",
		"O Titã de Magma protege a forja. Derrote-o e salve o que resta do fragmento."],
	"ninho": ["Darius descobriu a verdade: os dragões não enlouqueceram — estão fugindo de algo. Os filhotes estão em pânico no Ninho. Acalme-os à força.",
		"As escamas dos filhotes estão marcadas por algo muito mais antigo que eles. Recolha-as.",
		"O Dragão Ancestral foi tomado pela mesma força. Derrote-o. O Ato I termina aqui: nas profundezas de Drakaris, algo mais antigo que os dragões está acordando."],
}
## Atos II a V nos mapas gerados: abertura da cidade (por reino) e falas por tipo de missão.
const STORY_ACT := [
	{},
	{"intro": "Os sete formaram uma aliança frágil para caçar a Ordem do Primeiro Sangue. %s pede ajuda em %s: ",
		"kill": "agentes da Ordem corromperam %s — derrote 12 × %s.",
		"collect": "a Ordem esconde mensagens nas criaturas daqui: cada %s pode deixar cair %s. Recolha 8 e descubra quem são os traidores das famílias reais.",
		"boss": "%s lidera a Ordem nesta região. Acabe com essa ameaça."},
	{"intro": "A guerra das coroas começou: Valdrath marchou contra as Sombras, e a aliança está ruindo. %s defende %s: ",
		"kill": "a guerra espalhou %s por toda parte — derrote 12 × %s.",
		"collect": "cada %s pode deixar cair %s — provas de que o fragmento não foi roubado por Nyx. Recolha 8.",
		"boss": "%s aproveita a guerra para tomar o território. Acabe com essa ameaça."},
	{"intro": "Selene decifrou os registros: os fragmentos são pedaços de uma entidade, A Origem. %s protege %s: ",
		"kill": "a energia d'A Origem transforma %s — derrote 12 × %s.",
		"collect": "cada %s pode deixar cair um %s. Recolha 8 antes que A Origem os absorva.",
		"boss": "%s foi tomado pela vontade d'A Origem. Liberte esta terra."},
	{"intro": "O último reino se revelou: Aetherion. Os sete precisam decidir o destino dos fragmentos. %s luta em %s: ",
		"kill": "as criaturas d'A Origem invadem %s — derrote 12 × %s.",
		"collect": "cada %s pode deixar cair %s. Recolha 8: cada pedaço devolve um pouco de magia aos reinos.",
		"boss": "%s é um dos generais d'A Origem. Acabe com essa ameaça."},
]
const STORY_SPECIAL := {
	"forge": "Os ferreiros de Eloreth descobriram que a forja pode purificar o que a doença tocou. Abra a Forja (U) e funda 3 itens iguais ou desmonte um item que não usa.",
	"refine": "Lysara quer você forte para o que vem. Na tela de Equipamentos (I), aprimore qualquer item até +3 — até o +3 o refino nunca quebra.",
	"dungeon": "Sob as Ruínas existe uma masmorra da primeira guerra, selada com magia dos fragmentos. Entre pelo Portal de Viagem e vença as ondas e o chefe.",
}
const STORY_END := "Este é o último confronto. Derrote %s e a vontade d'A Origem será contida — por enquanto. Os sete reinos sobreviveram... mas a história ainda não acabou."


## Campanha principal (missões de história): em ordem, entregues pelo NPC de cada mapa. Cada missão tem um objetivo
## ("type") e pode liberar partes do jogo ("unlock"); sem ela a função ou o mapa fica travado, mesmo com o nível.
## Tipos: kill (N × monstro da zona), collect (N itens que caem desse monstro), boss (chefe da zona), forge (usar a
## Forja), refine (algum item com refino +N), dungeon (masmorras concluídas). Montada em `_build_campaign`.
## Liberações: "skill:N" (até N skills), "board", "pets", "forge", "refine", "dungeon", "market", "mounts", "guild",
## "global_boss", "duel", "map:<id>". A história com falas entra depois (o dono está escrevendo).
static var QUESTS: Array = []
const FEATURE_NAMES := {"board": "Quadro de Missões (J)", "pets": "Pets (P)", "forge": "Forja (U)", "refine": "Refino de itens (I)",
	"dungeon": "Masmorras (Portal)", "market": "Mercadinho (B)", "mounts": "Montarias (R)", "guild": "Guildas (G)",
	"global_boss": "Boss global", "duel": "Duelos (G)", "kingdom": "Lealdade a um Reino (H)"}
## O que cada etapa libera nos mapas base: zona → [na caçada, na coleta, no chefe]. Nos mapas gerados o chefe da
## última zona libera o mapa seguinte.
const CAMPAIGN_UNLOCKS := {
	"campo": [["skill:2"], ["board"], ["skill:3", "pets"]],
	"floresta": [[], ["forge"], ["skill:4"]],
	"ruinas": [["dungeon"], ["market"], ["skill:5", "map:deserto"]],
	"dunas": [["kingdom"], ["mounts"], ["skill:6"]],
	"cemiterio": [[], [], ["skill:7", "guild"]],
	"templo": [[], [], ["skill:8", "map:gelo"]],
	"tundra": [[], ["global_boss"], []],
	"cavernas": [[], [], ["duel"]],
	"glaciar": [[], [], ["skill:9", "map:vulcao"]],
	"fendas": [[], [], []],
	"forja": [[], [], ["skill:10"]],
	"ninho": [[], ["skill:11"], ["skill:12", "map:m1"]],
}
## Missões que ensinam uma função, logo depois de uma etapa da zona: zona → [[etapa (0 caçada, 1 coleta, 2 chefe), missão]].
const CAMPAIGN_EXTRA := {
	"floresta": [[1, {"type": "forge", "count": 1, "title": "A Forja", "unlock": ["refine"],
			"text": "Abra a Forja (U) e funda 3 itens iguais ou desmonte um item que não usa."}],
		[1, {"type": "refine", "count": 3, "title": "Aprimorar o equipamento",
			"text": "Na tela de Equipamentos (I), aprimore qualquer item até +3. Até o +3 o refino nunca quebra o item."}]],
	"ruinas": [[0, {"type": "dungeon", "count": 1, "title": "A Masmorra",
			"text": "Uma masmorra se abriu sob as ruínas. Entre pelo Portal de Viagem e vença as ondas e o chefe."}]],
}
## Fração de um nível de XP que cada tipo de missão dá, e a chance de o item de coleta cair.
const QUEST_FRAC := {"kill": 0.6, "collect": 0.6, "boss": 1.2, "forge": 0.4, "refine": 0.4, "dungeon": 0.8}
const QUEST_DROP := 0.55
## Nome do item de coleta pelo tipo do monstro (palavra no modelo).
const QUEST_ITEM := {"slime": "Gosma", "wolf": "Presa", "golem": "Núcleo", "scorp": "Ferrão", "skel": "Osso Antigo",
	"yeti": "Pelo", "imp": "Chifre", "dragon": "Escama", "bat": "Asa", "spider": "Seda", "ghost": "Ectoplasma"}


static func quest_item(enemy_id: String) -> String:
	var d := enemy(enemy_id)
	var key := (String(d.get("model", "")) + " " + enemy_id).to_lower()
	for k in QUEST_ITEM:
		if key.contains(k):
			return "%s de %s" % [QUEST_ITEM[k], String(d["name"])]
	return "Relíquia de %s" % String(d["name"])


static func _quest(type: String, map: String, zone: String, lv: int, title: String, text: String, count: int, unlock: Array) -> Dictionary:
	var L := float(maxi(1, lv))
	return {"id": "%s_%s_%d" % [zone if zone != "" else map, type, QUESTS.size()], "type": type, "map": map, "zone": zone, "min_level": lv,
		"title": title, "text": text, "count": count, "unlock": unlock,
		"xp": int(60.0 * pow(L, 1.75) * float(QUEST_FRAC[type])), "gold": 100 + lv * 50}


static func _build_campaign() -> void:
	QUESTS = []
	var last_map := String(MAP_ORDER[-1])
	for mid in MAP_ORDER:
		var md: Dictionary = MAPS[mid]
		var zs: Array = md["zones"]
		var kg := kingdom_of(String(mid))
		var kd: Dictionary = KINGDOMS.get(kg, KINGDOMS["eloreth"])
		for zi in zs.size():
			var zid := String(zs[zi])
			var z: Dictionary = ZONES[zid]
			var lo := int(z["lvl"].x)
			var span := maxi(1, int(z["lvl"].y) - lo + 1)
			var mob := String(enemy(String(z["enemy"]))["name"])
			var chefe := String(enemy(String(z["boss"]))["name"])
			var zn := String(z["name"])
			var act := act_of(lo)
			var unl: Array = CAMPAIGN_UNLOCKS.get(zid, [[], [], []])
			var last_unlock: Array = (unl[2] as Array).duplicate()
			if md.has("biome") and zi == zs.size() - 1:   # mapa gerado: o chefe final libera o próximo mapa
				var i := MAP_ORDER.find(mid)
				if i + 1 < MAP_ORDER.size():
					last_unlock.append("map:" + String(MAP_ORDER[i + 1]))
			var item := quest_item(String(z["enemy"]))
			if act >= 3:   # Ato IV em diante: os itens de coleta são estilhaços dos fragmentos
				item = "Estilhaço do Fragmento de %s" % String(kd["name"])
			var texts: Array
			if STORY_BASE.has(zid):
				texts = STORY_BASE[zid]
			else:
				var st: Dictionary = STORY_ACT[act]
				var intro := String(st["intro"]) % ["%s, %s," % [String(kd["ruler"]), String(kd["title"])] if String(kd["ruler"]) != "???" else "Uma voz sem rosto", String(md["name"])] if zi == 0 else ""
				texts = [intro + String(st["kill"]) % [zn, mob], String(st["collect"]) % [mob, item], String(st["boss"]) % chefe]
				if String(mid) == last_map and zi == zs.size() - 1:
					texts[2] = STORY_END % chefe
				for ti in texts.size():
					texts[ti] = String(texts[ti]).left(1).to_upper() + String(texts[ti]).substr(1)
			var head := "[i]%s · %s[/i]\n" % [String(ACTS[act]["name"]), String(kd["name"])]
			var steps := [
				_quest("kill", mid, zid, lo, "%s: Caçada" % zn, head + String(texts[0]), 12, unl[0]),
				_quest("collect", mid, zid, lo + span / 3, "%s: Coleta" % zn, head + String(texts[1]), 8, unl[1]),
				_quest("boss", mid, zid, lo + span * 2 / 3, "%s: %s" % [zn, chefe], head + String(texts[2]), 1, last_unlock),
			]
			steps[1]["item"] = item
			for k in 3:
				QUESTS.append(steps[k])
				for ex in CAMPAIGN_EXTRA.get(zid, []):
					if int(ex[0]) == k:
						var e: Dictionary = ex[1]
						QUESTS.append(_quest(String(e["type"]), mid, "", int(steps[k]["min_level"]), String(e["title"]),
							head + String(STORY_SPECIAL.get(String(e["type"]), e["text"])), int(e["count"]), e.get("unlock", [])))


## Primeira missão da campanha para um herói deste nível (usada para consertar saves com a campanha "terminada" cedo).
static func quest_index_for_level(level: int) -> int:
	for i in QUESTS.size():
		if int(QUESTS[i]["min_level"]) >= level and String(QUESTS[i]["type"]) == "kill":
			return maxi(0, i - 3) if int(QUESTS[i]["min_level"]) > level + 4 else i
	return QUESTS.size()


## Tudo o que as missões antes de `index` já liberaram (chave → true). Fim da campanha libera tudo.
static func story_unlocks(index: int) -> Dictionary:
	var out := {}
	for i in mini(index, QUESTS.size()):
		for u in QUESTS[i]["unlock"]:
			out[String(u)] = true
	if index >= QUESTS.size():
		out["all"] = true
	return out


## Índice da missão em que um save antigo (12 missões + 3 por mapa gerado, por zona) está agora.
static func legacy_quest_index(old: int) -> int:
	var zone := ""
	var base := ["campo", "floresta", "ruinas", "dunas", "cemiterio", "templo", "tundra", "cavernas", "glaciar", "fendas", "forja", "ninho"]
	if old < base.size():
		zone = base[old]
	else:
		var gi := (old - base.size()) / 3
		var maps_gen: Array = MAP_ORDER.slice(BASE_MAP_ORDER.size())
		if gi >= maps_gen.size():
			return QUESTS.size()
		zone = String(MAPS[maps_gen[gi]]["zones"][(old - base.size()) % 3])
	for i in QUESTS.size():
		if String(QUESTS[i]["zone"]) == zone:
			return i
	return 0


static func quest_kill(q: Dictionary) -> String:
	return String(ZONES[q["zone"]]["enemy"])


static func quest_boss(q: Dictionary) -> String:
	return String(ZONES[q["zone"]]["boss"])


static func quest_map(q: Dictionary) -> String:
	return String(q["map"])


# =================================================================== experiência

## Ritmo escolhido pelo dono: nv 60 em ~30 h e nv 1000 em ~1500 h só caçando (missões e história aceleram).
## XP para subir = (monstros por nível) × (XP de um monstro do nível). Ajustado com a simulação de balanceamento.
const XP_KILLS_C := 178.75
const XP_KILLS_P := 0.25


## Quantos monstros do próprio nível são precisos para subir do nível L (curva suave, começo mais rápido).
static func kills_per_level(level: int) -> float:
	var L := float(level)
	return XP_KILLS_C * pow(L, XP_KILLS_P) * clampf(L / 20.0, 0.15, 1.0)


## XP que um monstro comum do nível L dá (a mesma conta de enemy()).
static func mob_xp(level: int) -> float:
	return 10.0 * pow(float(level), 1.55)


## XP para passar do nível L para o L+1.
static func xp_need(level: int) -> int:
	return int(round(kills_per_level(level) * mob_xp(level)))


## Multiplicador de XP por nível (o antigo "10x menos a partir do 31" foi trocado pela curva suave acima).
## XP em dobro todo dia nestes horários (hora do computador/servidor).
const XP_DOUBLE_HOURS := [20]
## Eventos no mundo (a cada `every` segundos, um deles): baú dourado e invasão no acampamento.
const WORLD_EVENT := {"every": 1200.0, "chest_gems": 30, "chest_gold_levels": 0.15, "invasion_count": 16, "invasion_mins": 8}


static func xp_double() -> bool:
	return int(Time.get_datetime_dict_from_system()["hour"]) in XP_DOUBLE_HOURS


static func xp_gain_mult(_level: int) -> float:
	return 2.0 if xp_double() else 1.0


## XP da missão de história: o valor da tabela era para a curva antiga; mantém a mesma fração de um nível.
## Falas por bioma: a primeira abre a campanha de cada mapa gerado ({hub} = acampamento).
const STORY_TEXT := {
	"encantada": ["As fadas de {hub} pedem socorro: a floresta adoeceu.", "Algo corrompeu a magia daqui", "a própria floresta chora"],
	"pantano": ["O brejo de {hub} sobe a cada noite, e com ele os afogados.", "O lodo esconde segredos antigos", "o pântano está engolindo as trilhas"],
	"cristal": ["Os cristais de {hub} cantam uma música estranha.", "Alguém quebrou o Cristal-Mãe", "a luz dos cristais virou contra nós"],
	"tundra": ["O inverno em {hub} não acaba mais.", "Uma tempestade eterna desceu das montanhas", "o gelo está avançando sobre o refúgio"],
	"sombrias": ["Em {hub} as velas apagam sozinhas.", "As almas não descansam", "a escuridão tem um dono"],
	"celeste": ["Os sinos de {hub} tocaram sem ninguém tocar.", "Os guardiões do céu enlouqueceram", "um anjo caiu e trouxe a guerra"],
	"estelar": ["As estrelas sobre {hub} estão sumindo uma a uma.", "O vazio abriu uma fenda", "algo devora a luz"],
	"brasas": ["As forjas de {hub} nunca esfriam — e agora transbordam.", "O magma ganhou vontade própria", "o coração do vulcão bate cada vez mais forte"],
}


static func quest_xp(q: Dictionary) -> int:
	var L := float(maxi(1, int(q["min_level"])))
	return int(float(q["xp"]) / (60.0 * pow(L, 1.75)) * xp_need(int(L)))


# =================================================================== equipamentos e raridades

const RARITIES := ["comum", "rara", "epica", "lendaria"]
const RARITY := {
	"comum": {"name": "Comum", "color": Color(0.82, 0.82, 0.82), "atk": 1.0, "hp": 1.0, "def": 0.0},
	"rara": {"name": "Rara", "color": Color(0.35, 0.62, 1.0), "atk": 1.25, "hp": 1.2, "def": 0.06},
	"epica": {"name": "Épica", "color": Color(0.72, 0.42, 1.0), "atk": 1.6, "hp": 1.5, "def": 0.12},
	"lendaria": {"name": "Lendária", "color": Color(1.0, 0.76, 0.26), "atk": 2.2, "hp": 2.0, "def": 0.2},
}
## Encaixes do equipamento (anéis: dois encaixes, ring1 e ring2, para itens de slot "ring").
const GEAR_SLOTS := ["weapon", "helmet", "chest", "pants", "gloves", "boots", "necklace", "earring", "ring1", "ring2"]
const SLOT_INFO := {
	"weapon": {"name": "Arma", "stats": {"atk": 0.25}},
	"helmet": {"name": "Elmo", "stats": {"hp": 0.05, "def": 0.01}},
	"chest": {"name": "Peitoral", "stats": {"hp": 0.10, "def": 0.02}},
	"pants": {"name": "Calças", "stats": {"hp": 0.07, "def": 0.015}},
	"gloves": {"name": "Luvas", "stats": {"atk": 0.05, "def": 0.005}},
	"boots": {"name": "Botas", "stats": {"hp": 0.03, "speed": 0.02}},
	"necklace": {"name": "Colar", "stats": {"atk": 0.05, "mp": 0.06}},
	"earring": {"name": "Brincos", "stats": {"mp": 0.05, "def": 0.01}},
	"ring": {"name": "Anel", "stats": {"atk": 0.04, "hp": 0.02}},
}
## Pets: nível máximo e mortes para subir (cada morte dá 1 XP de pet).
const PET_MAX_LEVEL := 50


static func pet_xp_need(lvl: int) -> int:
	return 20 + lvl * 10


## Quanto cada raridade multiplica os atributos da peça.
const RARITY_MULT := {"comum": 1.0, "rara": 1.6, "epica": 2.5, "lendaria": 4.0}
## Refino +1 a +15: cada + soma 6% dos atributos da peça. Custo em ouro e chance de sucesso (falhar não perde nada).
const REFINE_MAX := 15
const REFINE_STEP := 0.06


static func refine_cost(item: Dictionary) -> int:
	var r := int(item.get("refine", 0)) + 1
	return int(60 * r * r * (1 + RARITIES.find(String(item["rarity"]))))


## Chance de subir para +1..+15 (tabela do dono). A partir do +4, falhar QUEBRA o item (some do inventário).
const REFINE_CHANCE := [1.0, 1.0, 1.0, 0.8, 0.6, 0.5, 0.35, 0.2, 0.15, 0.15, 0.15, 0.15, 0.1, 0.1, 0.1]
const REFINE_SAFE := 3


static func refine_chance(item: Dictionary) -> float:
	var r := int(item.get("refine", 0)) + 1
	return float(REFINE_CHANCE[clampi(r, 1, REFINE_CHANCE.size()) - 1])


## Cor da borda pelo refino: +6..+8 azul, +9..+11 roxo, +12..+15 dourado (sem borda antes do +6).
static func refine_color(item: Dictionary) -> Color:
	var r := int(item.get("refine", 0))
	if r >= 12:
		return Color(1.0, 0.78, 0.25)
	if r >= 9:
		return Color(0.72, 0.4, 1.0)
	if r >= 6:
		return Color(0.3, 0.6, 1.0)
	return Color(0, 0, 0, 0)


## Bônus de conjunto: peças equipadas da mesma raridade (ou melhor). Vale o maior que fechar.
const SET_BONUS := [
	{"pieces": 2, "stats": {"hp": 0.03}},
	{"pieces": 4, "stats": {"atk": 0.05}},
	{"pieces": 6, "stats": {"def": 0.03, "mp": 0.05}},
	{"pieces": 10, "stats": {"atk": 0.10, "hp": 0.10}},
]


## Atributos de uma peça (raridade × refino), em frações (0,25 = +25%).
static func item_stats(item: Dictionary) -> Dictionary:
	var slot := String(item["slot"])
	var base: Dictionary = SLOT_INFO.get(slot, SLOT_INFO["chest"])["stats"]
	var m := float(RARITY_MULT[String(item["rarity"])]) * (1.0 + REFINE_STEP * int(item.get("refine", 0)))
	var out := {}
	for k in base:
		out[k] = float(base[k]) * m
	return out


## Nome da peça: armas e peitorais têm nomes próprios por classe; o resto é "<peça> <tema da raridade>".
const GEAR_NAMES := {
	"assassino": {"weapon": ["Adagas de Ferro", "Adagas da Lua Azul", "Lâminas do Vazio", "Adagas do Sol Dourado"],
		"chest": ["Capuz de Viajante", "Manto Noturno", "Armadura das Sombras", "Armadura do Dragão Dourado"],
		"theme": ["de Viajante", "Noturno", "das Sombras", "do Dragão Dourado"]},
	"nautico": {"weapon": ["Arpão de Pescador", "Tridente das Marés", "Tridente da Tempestade", "Tridente de Poseidon"],
		"chest": ["Camisa Listrada", "Colete do Capitão", "Armadura do Abismo", "Armadura do Rei dos Mares"],
		"theme": ["de Pescador", "do Capitão", "do Abismo", "do Rei dos Mares"]},
	"mecanico": {"weapon": ["Chave Inglesa", "Chave Elétrica", "Garra de Plasma", "Canhão de Engrenagens"],
		"chest": ["Macacão de Oficina", "Avental do Inventor", "Traje Robótico", "Armadura Mecânica Dourada"],
		"theme": ["de Oficina", "do Inventor", "Robótico", "Mecânico Dourado"]},
	"mago": {"weapon": ["Cajado de Aprendiz", "Cajado Arcano", "Cajado Rúnico", "Cajado do Arquimago"],
		"chest": ["Túnica de Lã", "Manto Arcano", "Manto Rúnico", "Manto do Arquimago"],
		"theme": ["de Aprendiz", "Arcano", "Rúnico", "do Arquimago"]},
	"guerreiro": {"weapon": ["Espada de Ferro", "Espada do Cavaleiro", "Espada Rúnica", "Lâmina do Dragão"],
		"chest": ["Cota de Malha", "Armadura do Cavaleiro", "Armadura Rúnica", "Armadura do Dragão"],
		"theme": ["de Ferro", "do Cavaleiro", "Rúnico", "do Dragão"]},
	"arqueira": {"weapon": ["Arco Curto", "Arco Élfico", "Arco Rúnico", "Arco da Lua"],
		"chest": ["Gibão de Couro", "Gibão Élfico", "Gibão Rúnico", "Gibão da Lua"],
		"theme": ["de Couro", "Élfico", "Rúnico", "da Lua"]},
	"lanceiro": {"weapon": ["Lança de Ferro", "Lança de Vyndara", "Lança Rúnica", "Lança do Cavaleiro Celeste"],
		"chest": ["Cota de Malha", "Armadura de Vyndara", "Armadura Rúnica", "Armadura do Cavaleiro Celeste"],
		"theme": ["de Ferro", "de Vyndara", "Rúnico", "Celeste"]},
	"druida": {"weapon": ["Cajado de Galho", "Cajado das Runas", "Cajado do Bosque Sombrio", "Cajado do Sol Eterno"],
		"chest": ["Túnica de Linho", "Manto do Andarilho", "Armadura de Folhas", "Armadura do Cervo Dourado"],
		"theme": ["de Linho", "do Andarilho", "de Folhas", "do Cervo Dourado"]},
}
## Chance de cair equipamento (escasso de propósito) e chance de cada raridade quando cai.
const DROP_CHANCE := {"mob": 0.03, "boss": 0.5}
const DROP_RARITY := {"mob": [0.78, 0.18, 0.035, 0.005], "boss": [0.0, 0.6, 0.32, 0.08], "chest": [0.55, 0.33, 0.1, 0.02]}


static func item_name(item: Dictionary) -> String:
	if String(item.get("slot", "")) == "material":   # lote de material do Mercadinho
		return "%d × %s" % [int(item.get("qty", 1)), String(MATERIALS[String(item["mat"])]["name"])]
	var idx := RARITIES.find(String(item["rarity"]))
	var names: Dictionary = GEAR_NAMES[item["cls"]]
	var slot := String(item["slot"])
	var n := String(names[slot][idx]) if names.has(slot) else "%s %s" % [String(SLOT_INFO[slot]["name"]), String(names["theme"][idx])]
	var r := int(item.get("refine", 0))
	return n + (" +%d" % r if r > 0 else "")


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
