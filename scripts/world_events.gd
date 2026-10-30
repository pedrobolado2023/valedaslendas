class_name WorldEvents
extends Node
## Agenda do boss global (GameData.GLOBAL_BOSS): avisa antes, abre o Covil do Dragão no portal nos horários fixos
## (hora do computador), faz o dragão nascer quando o herói chega lá, dá as recompensas e manda o dragão embora
## quando o horário acaba. O admin pode forçar o evento para testar. Sem servidor ainda: cada jogo tem o seu.

var game: Node
var cfg: Dictionary = GameData.GLOBAL_BOSS
var boss: WorldBoss
var defeated_key := ""        # janela (dia+hora) em que o dragão já foi derrotado
var _forced_from := 0.0       # evento invocado pelo admin: começa em (horário Unix)
var _forced_until := 0.0      # ... e termina em
var _forced_key := ""
var _warned := ""
var _started := ""
var _tick := 0.0


var rank_ui: BossRank
var _last_top: Array = []


var chest: Node3D
var _chest_pos := Vector3.ZERO
var _chest_map := ""
var _local_ev_t := 0.0
var _xp2_said := false


func _ready() -> void:
	var net := get_node("/root/Net")
	net.world_event.connect(_on_world_event)
	# online: a vida que vale é a do servidor (todos batem no mesmo dragão); ranking e prêmios vêm de lá
	net.boss_hp.connect(_on_net_hp)
	net.boss_rank.connect(func(top: Array) -> void:
		_last_top = top
		if rank_ui != null and is_instance_valid(rank_ui):
			rank_ui.show_top(top))
	net.boss_reward.connect(func(rank: int, last_hit: bool, item: String) -> void: _rank_reward(rank, last_hit, item))


func _on_net_hp(hp: int, mx: int) -> void:
	if boss == null or not is_instance_valid(boss) or not boss.alive:
		return
	if mx != boss.max_hp:
		boss.max_hp = mx
	if hp < boss.hp:
		boss.crit_from_server = true
		boss.take_damage(boss.hp - hp, boss.global_position)
		boss.crit_from_server = false
	elif hp > boss.hp:
		boss.hp = hp
	boss._update_bar()


## Vida do boss sozinho (offline): ataque × dps_k × target_secs, nunca menos que hp × hp_mult.
func boss_hp_for(atk_total: float, base_hp: int) -> int:
	return maxi(base_hp * int(cfg["hp_mult"]), int(atk_total * float(cfg["dps_k"]) * float(cfg["target_secs"])))


## Eventos no mundo (baú dourado / invasão), vindos do servidor — ou locais, sem servidor.
func _on_world_event(kind: String, m: String, pos: Vector3, text: String) -> void:
	match kind:
		"bau":
			_chest_map = m
			_chest_pos = pos
			_place_chest()
			game.hud.banner("Baú Dourado!", text, 4.0)
			Sfx.play("legendary", -6.0)
		"bau_fim":
			_chest_map = ""
			_remove_chest()
			game.toast(text, 3.0)
		"bau_premio":
			_chest_reward()
		"invasao":
			game.hud.banner("Invasão!", text, 4.0)
			Sfx.play("boss", -6.0)
		"anuncio":   # painel admin
			game.hud.banner("Aviso", text, 6.0)
			Sfx.play("legendary", -8.0)
		"expulso":
			game.hud.banner("Desconectado", text, 8.0)
		"presente":   # painel admin: {"gems", "gold", "items"}
			var g: Variant = JSON.parse_string(text)
			text = ""
			if g is Dictionary and game.player != null:
				var p: Player = game.player
				Shop.credit_gems(p, int(g.get("gems", 0)), "admin")
				p.gold += int(g.get("gold", 0))
				for i in int(g.get("items", 0)):
					game._drop_item(String(g.get("rarity", "lendaria")), p.global_position + Vector3(2.0 * (i - 0.5), 0, 2))
				game.hud.banner("Presente do administrador!", "+%d gemas   +%d ouro   %s" % [int(g.get("gems", 0)), int(g.get("gold", 0)), "+ itens no chão" if int(g.get("items", 0)) > 0 else ""], 5.0)
				Sfx.play("legendary", -4.0)
				p.stats_changed.emit()
	if text != "" and game.get("chat") != null:
		game.chat.add("sistema", "", text)


func _place_chest() -> void:
	_remove_chest()
	if _chest_map != game.map_id or game.world == null:
		return
	chest = Node3D.new()
	game.actors.add_child(chest)
	chest.global_position = _chest_pos
	var kit := ModelKit.load_kit("loot_crystal", 0.03)
	if kit != null:
		kit.root.scale = Vector3.ONE * 1.6
		chest.add_child(kit.root)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.8, 0.3)
	l.light_energy = 2.5
	l.omni_range = 8.0
	l.position.y = 1.5
	chest.add_child(l)
	var lab := Label3D.new()
	lab.text = "Baú Dourado"
	lab.font = Toon.title_font()
	lab.font_size = 36
	lab.pixel_size = 0.014
	lab.modulate = Color(1.0, 0.85, 0.35)
	lab.outline_size = 8
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.position.y = 3.0
	chest.add_child(lab)


func _remove_chest() -> void:
	if chest != null and is_instance_valid(chest):
		chest.queue_free()
	chest = null


func _chest_reward() -> void:
	var p = game.player
	var cfgw: Dictionary = GameData.WORLD_EVENT
	var gold := int(GameData.xp_need(p.level) * 0.0) + int(800 + p.level * 120)
	Shop.credit_gems(p, int(cfgw["chest_gems"]), "bau_dourado")
	p.gold += gold
	game._drop_item(GameData.roll_rarity("chest"), p.global_position + Vector3(1.5, 0, 0))
	game.hud.banner("Você pegou o Baú Dourado!", "+%d gemas   +%d de ouro   + um item" % [int(cfgw["chest_gems"]), gold], 4.0)
	Sfx.play("legendary", -2.0)
	p.stats_changed.emit()
	game.save_now()


func _process(delta: float) -> void:
	# baú dourado: chegar perto pega (online o servidor decide quem chegou primeiro)
	if chest == null and _chest_map != "" and _chest_map == game.map_id and game.world != null:
		_place_chest()
	if chest != null and is_instance_valid(chest) and game.player != null:
		chest.rotation.y += delta
		if Skills.flat(game.player.global_position - chest.global_position).length() < 3.0:
			var net := get_node("/root/Net")
			if net.online:
				net.chest_claim.rpc_id(1)
				_chest_map = ""
				_remove_chest()
			else:
				_chest_map = ""
				_remove_chest()
				_chest_reward()
	# sem servidor: baú no próprio mapa a cada 20 min
	if not get_node("/root/Net").online and game.player != null and not bool(GameData.MAPS[game.map_id].get("event", false)):
		_local_ev_t += delta
		if _local_ev_t >= float(GameData.WORLD_EVENT["every"]):
			_local_ev_t = 0.0
			var a := randf() * TAU
			_on_world_event("bau", game.map_id, Vector3(cos(a), 0, sin(a)) * randf_range(20.0, 45.0), "Um Baú Dourado apareceu perto do acampamento!")
	# XP em dobro (avisa uma vez quando começa)
	if GameData.xp_double() != _xp2_said and game.get("hud") != null:
		_xp2_said = GameData.xp_double()
		if _xp2_said:
			game.hud.banner("XP em dobro!", "Até as %dh: todo monstro e missão dá o dobro de XP" % (int(GameData.XP_DOUBLE_HOURS[0]) + 1), 4.0)
	if rank_ui != null and is_instance_valid(rank_ui) and boss != null and is_instance_valid(boss) and not get_node("/root/Net").online:
		rank_ui.show_top([["Você", boss.my_dmg]])
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 1.0
	if game == null or game.get("player") == null:
		return
	var key := window_key()
	# aviso 5 minutos antes (com a janela "Ir para o Boss")
	var nk := _next_key_soon()
	if nk != "" and nk != _warned:
		_warned = nk
		game.hud.banner("Boss global em %d min" % (seconds_to_next() / 60 + 1), "O Dragão de Lava vai despertar no Covil do Dragão", 4.0)
		Sfx.play("boss", -8.0, 1.2)
		_popup()
	if key != "" and key != _started:
		_started = key
		if key != defeated_key:
			game.hud.banner("O Dragão de Lava despertou!", "Vá para o Covil do Dragão  ·  %d min" % minutes_left(), 5.0)
			Sfx.play("boss", -4.0)
			_popup()
	if key != "" and key != defeated_key and game.map_id == String(cfg["map"]) and (boss == null or not is_instance_valid(boss)):
		_spawn()
	if key == "" and boss != null and is_instance_valid(boss) and boss.alive:
		boss.depart()
		game.toast("O tempo acabou: o Dragão de Lava voou para longe.", 3.0)


## Chave da janela ativa ("2026-10-29-16") ou "" se não houver evento agora.
func window_key() -> String:
	var now := Time.get_unix_time_from_system()
	if now >= _forced_from and now < _forced_until:
		return _forced_key
	if now < _forced_from:
		return ""
	var d := Time.get_datetime_dict_from_system()
	if int(d["hour"]) in cfg["hours"] and int(d["minute"]) < int(cfg["minutes"]):
		return "%04d-%02d-%02d-%02d" % [d["year"], d["month"], d["day"], d["hour"]]
	return ""


func active() -> bool:
	return window_key() != "" and window_key() != defeated_key


func minutes_left() -> int:
	if Time.get_unix_time_from_system() < _forced_until:
		return int(ceil((_forced_until - Time.get_unix_time_from_system()) / 60.0))
	var d := Time.get_datetime_dict_from_system()
	return maxi(1, int(cfg["minutes"]) - int(d["minute"]))


## Texto do próximo horário ("16h") para mostrar no portal.
func next_text() -> String:
	var h := int(Time.get_datetime_dict_from_system()["hour"])
	for k in range(1, 25):
		var hh := (h + k) % 24
		if hh in cfg["hours"]:
			return "%dh" % hh
	return "?"


func _next_key_soon() -> String:
	var now := Time.get_unix_time_from_system()
	if now < _forced_from and _forced_from - now <= float(cfg["warn_minutes"]) * 60.0 + 1.0:
		return _forced_key
	var d := Time.get_datetime_dict_from_system()
	var nh := (int(d["hour"]) + 1) % 24
	if nh in cfg["hours"] and int(d["minute"]) >= 60 - int(cfg["warn_minutes"]):
		return "%04d-%02d-%02d-%02d" % [d["year"], d["month"], d["day"], nh]
	return ""


## Segundos até o próximo boss começar (invocado ou do horário fixo).
func seconds_to_next() -> int:
	var now := Time.get_unix_time_from_system()
	if now < _forced_from:
		return int(_forced_from - now)
	var d := Time.get_datetime_dict_from_system()
	return (59 - int(d["minute"])) * 60 + (60 - int(d["second"]))


## Boss começa daqui a `delay` segundos e dura `minutes` (admin ou servidor avisando todos).
func schedule(delay: float, minutes: int) -> void:
	_forced_from = Time.get_unix_time_from_system() + delay
	_forced_until = _forced_from + minutes * 60.0
	_forced_key = "invocado-%d" % int(_forced_from)
	defeated_key = ""
	_tick = 0.0


func _roll_last_item() -> String:
	var odds: Dictionary = cfg["last_item"]
	var r := randf()
	return "lendaria" if r < float(odds["lendaria"]) else ("epica" if r < float(odds["lendaria"]) + float(odds["epica"]) else "rara")


## Prêmio do ranking (top 3) e do último golpe (ouro, gemas e um item: 1% lendário, 2% épico, resto raro).
func _rank_reward(rank: int, last_hit: bool, item: String) -> void:
	var p = game.player
	if p == null:
		return
	var gems := 0
	var gold := 0
	var parts: Array = []
	if rank >= 1 and rank <= 3:
		gems += int(cfg["top_gems"][rank - 1])
		gold += int(cfg["top_gold"][rank - 1])
		parts.append("Top %d no dano" % rank)
	if last_hit:
		gems += int(cfg["last_gems"])
		gold += int(cfg["last_gold"])
		parts.append("Último golpe!")
	if gems > 0:
		Shop.credit_gems(p, gems, "boss_global_rank")
	p.gold += gold
	if item != "":
		var it: Dictionary = p.new_item(String(Player.ITEM_SLOTS.pick_random()), item)
		it["sell"] = true
		p.add_item(it)
		parts.append("%s (%s)" % [GameData.item_name(it), String(GameData.RARITY[item]["name"])])
	if not parts.is_empty():
		Sfx.play("legendary", -2.0)
		game.hud.banner(" · ".join(parts), "+%d gemas   +%d de ouro%s" % [gems, gold, "   · item no inventário (I)" if item != "" else ""], 6.0)
	p.stats_changed.emit()
	if rank_ui != null and is_instance_valid(rank_ui):
		rank_ui.finish(rank, last_hit)
	game.save_now()


## Admin: começa um evento agora, durando `minutes` minutos.
func force(minutes: int) -> void:
	schedule(0.0, minutes)


## Janela no meio da tela: contagem e botão para ir direto ao Covil.
func _popup() -> void:
	if game.map_id == String(cfg["map"]) or not game.call("feature_on", "global_boss"):
		return
	var old: Node = game.get_node_or_null("BossCall")
	if old != null:
		old.queue_free()
	var pop := BossCall.new()
	pop.name = "BossCall"
	pop.events = self
	game.add_child(pop)


func _spawn() -> void:
	var z: Dictionary = GameData.ZONES["arena_dragao"]
	boss = WorldBoss.new()
	boss.setup(String(cfg["enemy"]), z["boss_pos"] + Vector3(0, 0.3, 0), "arena_dragao")
	boss.net_key = window_key()
	game.actors.add_child(boss)
	boss.died.connect(_on_boss_died)
	var base := int(boss.data["hp"])
	boss.max_hp = boss_hp_for(game.player.atk, base)
	boss.hp = boss.max_hp
	boss._update_bar()
	var net := get_node("/root/Net")
	if net.online:
		net.boss_join.rpc_id(1, boss.net_key, game.player.atk, base)
	if rank_ui != null and is_instance_valid(rank_ui):
		rank_ui.queue_free()
	rank_ui = BossRank.new()
	game.add_child(rank_ui)
	boss.phase_changed.connect(func(p: int) -> void:
		var txt := {2: "O dragão levanta voo e chama os filhotes!", 3: "Fúria final: o chão pega fogo!"}
		game.hud.banner("Dragão de Lava — fase %d" % p, String(txt.get(p, "")), 3.0))
	game.hud.banner("Dragão de Lava", "Derrote o boss global antes que o tempo acabe (%d min)" % minutes_left(), 3.5)


func _on_boss_died(e: Enemy) -> void:
	defeated_key = window_key()
	var p = game.player
	var xp := int(GameData.xp_need(p.level) * float(cfg["reward_xp_levels"]))
	p.gain_xp(xp)
	p.gold += int(cfg["reward_gold"])
	Shop.credit_gems(p, int(cfg["reward_gems"]), "boss_global")
	var at := e.global_position
	game._drop_item(String(cfg["loot_rarity"]), at + Vector3(2, 0, 0))
	if randf() < float(cfg["legendary_chance"]):
		game._drop_item("lendaria", at + Vector3(-2, 0, 0))
	if not get_node("/root/Net").online:   # sozinho: você é o top 1 e deu o último golpe
		_rank_reward(1, true, _roll_last_item())
	for k in 8:
		game._drop("gold", int(cfg["reward_gold"]) / 20, "Ouro", at + Vector3(randf_range(-4, 4), 0, randf_range(-4, 4)))
	Vfx.explosion(game.actors, at, 8.0)
	Fx.shake(p, 0.8)
	game.hud.banner("Dragão de Lava derrotado!", "+%d XP   +%d de ouro   +%d gemas   ·   próximo boss global às %s" % [xp, int(cfg["reward_gold"]), int(cfg["reward_gems"]), next_text()], 5.0)
	p.stats_changed.emit()
	game.save_now()
