class_name Rewards
extends RefCounted
## Recompensa diária de login (ciclo de 7 dias, pela data do PC) e conquistas com prêmio.
## Estado no herói: player.stats (contadores), player.login {"last": "AAAA-MM-DD", "day": 0..6}, player.achieved [ids].

const DAILY := [
	{"gold": 300}, {"gems": 10}, {"gold": 800}, {"xp_levels": 0.3}, {"gems": 20}, {"gold": 2000},
	{"gems": 50, "item": "epica"},
]

## stat: contador (ou "level", "refine", "pet", "mounts" calculados); goal; prêmio em gemas.
const ACHIEVEMENTS := [
	{"id": "k100", "name": "Caçador", "desc": "Derrote 100 monstros", "stat": "kills", "goal": 100, "gems": 10},
	{"id": "k1000", "name": "Exterminador", "desc": "Derrote 1.000 monstros", "stat": "kills", "goal": 1000, "gems": 30},
	{"id": "k10000", "name": "Lenda da Caça", "desc": "Derrote 10.000 monstros", "stat": "kills", "goal": 10000, "gems": 100},
	{"id": "b5", "name": "Matador de Chefes", "desc": "Derrote 5 chefes", "stat": "bosses", "goal": 5, "gems": 15},
	{"id": "b50", "name": "Terror dos Chefes", "desc": "Derrote 50 chefes", "stat": "bosses", "goal": 50, "gems": 50},
	{"id": "g1", "name": "Caçador de Dragões", "desc": "Derrote o Dragão de Lava (boss global)", "stat": "global", "goal": 1, "gems": 40},
	{"id": "q10", "name": "Aventureiro", "desc": "Complete 10 missões", "stat": "quests", "goal": 10, "gems": 10},
	{"id": "q100", "name": "Herói do Povo", "desc": "Complete 100 missões", "stat": "quests", "goal": 100, "gems": 40},
	{"id": "l10", "name": "Primeiros Passos", "desc": "Chegue ao nível 10", "stat": "level", "goal": 10, "gems": 10},
	{"id": "l30", "name": "Veterano", "desc": "Chegue ao nível 30", "stat": "level", "goal": 30, "gems": 25},
	{"id": "l60", "name": "Mestre do Vale", "desc": "Chegue ao nível 60", "stat": "level", "goal": 60, "gems": 50},
	{"id": "l200", "name": "Além do Abismo", "desc": "Chegue ao nível 200", "stat": "level", "goal": 200, "gems": 100},
	{"id": "l1000", "name": "Lenda Eterna", "desc": "Chegue ao nível 1000", "stat": "level", "goal": 1000, "gems": 500},
	{"id": "r10", "name": "Ferreiro", "desc": "Refine uma peça até +10", "stat": "refine", "goal": 10, "gems": 30},
	{"id": "r15", "name": "Perfeição", "desc": "Refine uma peça até +15", "stat": "refine", "goal": 15, "gems": 80},
	{"id": "p10", "name": "Melhor Amigo", "desc": "Leve um pet ao nível 10", "stat": "pet", "goal": 10, "gems": 20},
	{"id": "m1", "name": "Cavaleiro", "desc": "Tenha uma montaria", "stat": "mounts", "goal": 1, "gems": 10},
	{"id": "d7", "name": "Fiel", "desc": "Entre 7 dias", "stat": "logins", "goal": 7, "gems": 20},
	{"id": "d30", "name": "Morador do Vale", "desc": "Entre 30 dias", "stat": "logins", "goal": 30, "gems": 60},
]


static func today() -> String:
	return Time.get_date_string_from_system()


static func can_claim_daily(p: Player) -> bool:
	return String(p.login.get("last", "")) != today()


## Dá o prêmio do dia e avança o ciclo (perder um dia não zera: só não ganha naquele dia).
static func claim_daily(p: Player) -> Dictionary:
	if not can_claim_daily(p):
		return {}
	var day := int(p.login.get("day", 0)) % DAILY.size()
	var r: Dictionary = DAILY[day]
	if r.has("gold"):
		p.gold += int(r["gold"])
	if r.has("gems"):
		Shop.credit_gems(p, int(r["gems"]), "login_dia_%d" % (day + 1))
	if r.has("xp_levels") and p.level < GameData.MAX_LEVEL:
		p.gain_xp_raw(int(GameData.xp_need(p.level) * float(r["xp_levels"])))
	if r.has("item"):
		p.add_item(p.new_item(String(Player.ITEM_SLOTS.pick_random()), String(r["item"])))
	p.login = {"last": today(), "day": (day + 1) % DAILY.size()}
	p.stat_add("logins")
	p.stats_changed.emit()
	return r


static func reward_text(r: Dictionary) -> String:
	var parts: Array = []
	if r.has("gold"):
		parts.append("%d ouro" % int(r["gold"]))
	if r.has("gems"):
		parts.append("%d gemas" % int(r["gems"]))
	if r.has("xp_levels"):
		parts.append("%d%% de um nível" % int(float(r["xp_levels"]) * 100))
	if r.has("item"):
		parts.append("item %s" % String(GameData.RARITY[r["item"]]["name"]))
	return " + ".join(parts)


static func progress(p: Player, a: Dictionary) -> int:
	match String(a["stat"]):
		"level":
			return p.level
		"refine":
			var m := 0
			for it in p.inventory:
				m = maxi(m, int(it.get("refine", 0)))
			return m
		"pet":
			var m := 0
			for k in p.pet_levels:
				m = maxi(m, int(p.pet_levels[k][0]))
			return m
		"mounts":
			var n := 0
			for it in GameData.SHOP:
				if String(it["kind"]) == "mount" and Shop.owned(p, String(it["id"])) > 0:
					n += 1
			return n
	return int(p.stats.get(String(a["stat"]), 0))


static func done(p: Player, a: Dictionary) -> bool:
	return progress(p, a) >= int(a["goal"])


static func claimable(p: Player) -> int:
	var n := 1 if can_claim_daily(p) else 0
	for a in ACHIEVEMENTS:
		if done(p, a) and not p.achieved.has(String(a["id"])):
			n += 1
	return n


static func claim(p: Player, a: Dictionary) -> bool:
	if not done(p, a) or p.achieved.has(String(a["id"])):
		return false
	p.achieved.append(String(a["id"]))
	Shop.credit_gems(p, int(a["gems"]), "conquista_" + String(a["id"]))
	p.stats_changed.emit()
	return true
