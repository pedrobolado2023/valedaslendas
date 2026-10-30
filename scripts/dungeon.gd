class_name Dungeon
extends Node
## Masmorra Sombria (pelo Portal): 3 entradas por dia (data do PC). Dentro: 3 ondas de monstros do mapa do nível
## do herói e um chefe mais forte, com 10 minutos. Vencer dá ouro, gemas, XP e itens; morrer ou o tempo acabar
## devolve o herói ao mapa de antes. Números em GameData.DUNGEON.

var game: Node
var state := ""          # "" fora · "wait" entrando · "fight" onda · "boss" · "done"
var wave := 0
var time_left := 0.0
var _alive: Array = []
var _enemy := ""
var _boss := ""
var _map := "masmorra"
var _zone := "sala_masmorra"
var diff := "normal"
var guild := false        # boss semanal da guilda
var online_run := false   # online: o servidor cuida das ondas, do chefe e dos prêmios
var _total := 0
var _label: Label


func _ready() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 6
	add_child(cl)
	_label = UiTheme.title("", 22)
	_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_label.offset_top = 70
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cl.add_child(_label)
	var net := get_node_or_null("/root/Net")
	if net != null:
		net.dungeon_event.connect(_on_net)


func _net() -> Node:
	var net := get_node_or_null("/root/Net")
	return net if net != null and bool(net.get("online")) else null


func runs_today() -> int:
	var p: Player = game.player
	return int(p.stats.get("dg_count", 0)) if String(p.stats.get("dg_day", "")) == Rewards.today() else 0


## Escolher a dificuldade (janela do diálogo) e entrar.
func choose() -> void:
	var opts: Array = []
	for k in GameData.DUNGEON_DIFF:
		var d: Dictionary = GameData.DUNGEON_DIFF[k]
		var kk := String(k)
		opts.append(["%s  ·  monstros %sx  ·  prêmio %sx" % [String(d["name"]), str(d["power"]), str(d["reward"])], func() -> void:
			game.dialog.close()
			enter(kk)])
	opts.append(["Fechar", game.dialog.close])
	var mid := GameData.dungeon_map_for(String(game.best_open_map()))
	game.dialog.open(String(GameData.MAPS[mid]["name"]), "Escolha a dificuldade (%d/%d masmorras hoje). Quanto mais difícil, mais fortes os monstros e maior o prêmio." % [runs_today(), int(GameData.DUNGEON["per_day"])], opts)


static func week_key() -> int:
	return int((Time.get_unix_time_from_system() + 3 * 86400) / (7 * 86400))   # semanas a partir da segunda


func guild_done_week() -> bool:
	return int(game.player.stats.get("gb_week", -1)) == week_key()


## Boss semanal da guilda (botão no painel social G).
func enter_guild() -> void:
	var p: Player = game.player
	if String(p.get_meta("guild", "")) == "":
		game.toast("Entre em uma guilda para enfrentar o boss da guilda.", 2.5)
		return
	if guild_done_week():
		game.toast("Você já derrotou o boss da guilda esta semana. Volta na segunda!", 2.5)
		return
	enter("normal", true)


func enter(difficulty: String = "normal", guild_boss: bool = false) -> void:
	diff = difficulty if GameData.DUNGEON_DIFF.has(difficulty) else "normal"
	guild = guild_boss
	var cfg: Dictionary = GameData.DUNGEON
	if not guild and runs_today() >= int(cfg["per_day"]):
		game.toast("Você já fez as %d masmorras de hoje. Volte amanhã!" % int(cfg["per_day"]), 2.5)
		return
	var p: Player = game.player
	if _net() != null:   # online: o servidor abre a instância (o grupo no mesmo mapa vai junto)
		_net().dungeon_enter.rpc_id(1, diff, guild)
		game.toast("Abrindo a masmorra...", 2.0)
		return
	if not guild:
		p.stats["dg_day"] = Rewards.today()
		p.stats["dg_count"] = runs_today() + 1
	# monstros e chefe da zona mais alta que o herói alcança
	var bm := String(game.best_open_map())
	var zs: Array = GameData.MAPS[bm]["zones"]
	var best: Dictionary = GameData.ZONES[zs[0]]
	for z in zs:
		var zd: Dictionary = GameData.ZONES[z]
		if int(zd["lvl"].x) <= p.level:
			best = zd
	_enemy = String(best["enemy"])
	_boss = String(best.get("boss", _enemy))
	_map = GameData.dungeon_map_for(bm)
	_zone = String(GameData.MAPS[_map]["zones"][0])
	state = "wait"
	wave = 0
	time_left = float(GameData.GUILD_BOSS["minutes"] if guild else cfg["minutes"]) * 60.0
	game.travel(_map, true)


func _process(delta: float) -> void:
	if _label != null:
		_label.text = hud_text()
	if state == "" or game.player == null:
		return
	if online_run:
		if String(game.map_id) != _map and state != "wait":
			online_run = false
			state = ""
		elif state in ["fight", "boss"]:
			time_left -= delta
		return
	if String(game.map_id) != _map:
		if state != "wait":
			state = ""
		return
	if game.get("_traveling"):
		return
	if state == "wait":
		_next_wave()
		return
	if state == "done":
		return
	time_left -= delta
	if time_left <= 0.0 or not game.player.alive:
		_fail("O tempo acabou!" if time_left <= 0.0 else "Você caiu na masmorra.")
		return
	_alive = _alive.filter(func(e) -> bool: return is_instance_valid(e) and (e as Enemy).alive)
	if _alive.is_empty():
		if state == "boss":
			_win()
		else:
			_next_wave()


func hud_text() -> String:
	if online_run and state == "fight":
		return "Masmorra · onda %d/%d · %d inimigos · %d:%02d" % [wave, _total, get_tree().get_nodes_in_group("enemy").size(), maxi(0, int(time_left)) / 60, maxi(0, int(time_left)) % 60]
	if guild and state == "boss":
		return "Boss da Guilda · %d:%02d" % [int(time_left) / 60, int(time_left) % 60]
	if state in ["fight", "boss"]:
		return "Masmorra · %s · %d inimigos · %d:%02d" % ["CHEFE" if state == "boss" else "onda %d/%d" % [wave, GameData.DUNGEON["waves"].size()],
			_alive.size(), int(time_left) / 60, int(time_left) % 60]
	return ""


func _spawn(type_id: String, at: Vector3) -> Enemy:
	var e := Enemy.new()
	e.setup(type_id, at, _zone)
	e.died.connect(game._on_killed)
	game.actors.add_child(e)
	var pw := float(GameData.GUILD_BOSS["power"] if guild else GameData.DUNGEON_DIFF[diff]["power"])   # dificuldade: vida e dano
	e.max_hp = int(e.max_hp * pw)
	e.hp = e.max_hp
	e.dmg = int(e.dmg * pw)
	_alive.append(e)
	return e


func _next_wave() -> void:
	var waves: Array = (GameData.DUNGEON["waves"] as Array).duplicate()
	for i in int(GameData.DUNGEON_DIFF[diff]["extra_wave"]):
		waves.append(int(waves[-1]) + 4)
	var z: Dictionary = GameData.ZONES[_zone]
	var c: Vector3 = z["center"]
	wave += 1
	if wave > waves.size() or guild:
		state = "boss"
		var b := _spawn(_boss, z["boss_pos"] + Vector3(0, 0.3, 0))
		b.max_hp = int(b.max_hp * float(GameData.GUILD_BOSS["hp_mult"] if guild else GameData.DUNGEON["boss_hp_mult"]))
		b.hp = b.max_hp
		if guild:
			b.scale *= 1.5
		game.hud.banner("Boss da Guilda" if guild else "Chefe da Masmorra", String(b.data["name"]), 2.5)
		return
	state = "fight"
	for i in int(waves[wave - 1]):
		var a := randf() * TAU
		_spawn(_enemy, c + Vector3(cos(a), 0, sin(a)) * randf_range(6.0, 16.0) + Vector3(0, 0.2, 0))
	game.hud.banner("Onda %d de %d" % [wave, waves.size()], "Derrote todos os monstros", 2.0)


func _win() -> void:
	state = "done"
	if guild:
		_win_guild()
		return
	var cfg: Dictionary = GameData.DUNGEON
	var p: Player = game.player
	var rw := float(GameData.DUNGEON_DIFF[diff]["reward"])
	var xp := int(GameData.xp_need(p.level) * float(cfg["reward_xp_levels"]) * rw)
	var gems := int(int(cfg["reward_gems"]) * rw)
	p.gain_xp(xp)
	Shop.credit_gems(p, gems, "masmorra")
	p.stat_add("dungeons")
	for k in GameData.MAT_DROP["boss"]:   # materiais da forja, mais na dificuldade alta
		p.mats[k] = int(p.mats.get(k, 0)) + int(ceil(float(GameData.MAT_DROP["boss"][k]) * rw))
	for i in int(cfg["items"]) * int(rw):
		game._drop_item(GameData.roll_rarity("boss"), p.global_position + Vector3(2.0 * (i - 0.5), 0, 2))
	game.hud.banner("Masmorra %s concluída!" % String(GameData.DUNGEON_DIFF[diff]["name"]), "+%d XP   +%d gemas   + materiais   ·   itens no chão   ·   saindo em 8 s" % [xp, gems], 5.0)
	Sfx.play("legendary", -2.0)
	game.quest_event("dungeon", 1)
	_leave(8.0)


func _win_guild() -> void:
	var g: Dictionary = GameData.GUILD_BOSS
	var p: Player = game.player
	p.stats["gb_week"] = week_key()
	var xp := int(GameData.xp_need(p.level) * float(g["xp_levels"]))
	p.gain_xp(xp)
	Shop.credit_gems(p, int(g["gems"]), "boss_guilda")
	for k in GameData.MAT_DROP["boss"]:
		p.mats[k] = int(p.mats.get(k, 0)) + int(ceil(float(GameData.MAT_DROP["boss"][k]) * float(g["mat_mult"])))
	for i in int(g["items"]):
		game._drop_item(GameData.roll_rarity(String(g["table"])), p.global_position + Vector3(2.0 * (i - 1), 0, 2))
	game.hud.banner("Boss da Guilda derrotado!", "+%d XP   +%d gemas   +%d pontos para a guilda   ·   saindo em 8 s" % [xp, int(g["gems"]), int(g["guild_points"])], 5.0)
	Sfx.play("legendary", -2.0)
	game.call("save_now")
	_leave(8.0)


## Mensagens do servidor (online).
func _on_net(kind: String, d: Dictionary) -> void:
	var p: Player = game.player
	if p == null:
		return
	match kind:
		"refused":
			game.toast(String(d["why"]), 3.0)
		"go":
			online_run = true
			diff = String(d["diff"])
			guild = bool(d["guild"])
			_map = String(d["map"])
			state = "wait"
			wave = 0
			time_left = float(d["time"])
			if guild:
				p.stats["gb_week"] = week_key()
			else:
				p.stats["dg_day"] = Rewards.today()
				p.stats["dg_count"] = runs_today() + 1
			game.travel(_map, true)
			if int(d["members"]) > 1:
				game.toast("Masmorra em grupo: %d heróis" % int(d["members"]), 3.0)
		"wave":
			state = "fight"
			wave = int(d["n"])
			_total = int(d["total"])
			time_left = float(d["time"])
			game.hud.banner("Onda %d de %d" % [wave, _total], "Derrote todos os monstros", 2.0)
		"boss":
			state = "boss"
			time_left = float(d["time"])
			game.hud.banner("Boss da Guilda" if guild else "Chefe da Masmorra", String(d["name"]), 2.5)
		"win":
			state = "done"
			var xp := int(GameData.xp_need(p.level) * float(d["xp_levels"]))
			p.gain_xp(xp)
			Shop.credit_gems(p, int(d["gems"]), "boss_guilda" if guild else "masmorra")
			if not guild:
				p.stat_add("dungeons")
			for k in GameData.MAT_DROP["boss"]:
				p.mats[k] = int(p.mats.get(k, 0)) + int(ceil(float(GameData.MAT_DROP["boss"][k]) * float(d["mat_mult"])))
			var rs: Array = d["rarities"]
			for i in rs.size():
				game._drop_item(String(rs[i]), p.global_position + Vector3(2.0 * (i - 0.5), 0, 2))
			var title := "Boss da Guilda derrotado!" if guild else "Masmorra %s concluída!" % String(GameData.DUNGEON_DIFF[diff]["name"])
			game.hud.banner(title, "+%d XP   +%d gemas%s   ·   itens no chão   ·   saindo em 8 s" % [xp, int(d["gems"]), "   +%d pontos da guilda" % int(d["points"]) if guild else ""], 5.0)
			Sfx.play("legendary", -2.0)
			if not guild:
				game.quest_event("dungeon", 1)
			game.call("save_now")
			_leave(8.0)
		"fail":
			_fail(String(d["why"]))


func _fail(why: String) -> void:
	state = "done"
	for e in _alive:
		if is_instance_valid(e):
			(e as Node).queue_free()
	_alive.clear()
	game.hud.banner("Masmorra perdida", why, 3.0)
	_leave(3.0)


func _leave(secs: float) -> void:
	await get_tree().create_timer(secs).timeout
	state = ""
	guild = false
	online_run = false
	if GameData.is_dungeon(String(game.map_id)):
		game.travel(String(game.return_map), true)
