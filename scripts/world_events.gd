class_name WorldEvents
extends Node
## Agenda do boss global (GameData.GLOBAL_BOSS): avisa antes, abre o Covil do Dragão no portal nos horários fixos
## (hora do computador), faz o dragão nascer quando o herói chega lá, dá as recompensas e manda o dragão embora
## quando o horário acaba. O admin pode forçar o evento para testar. Sem servidor ainda: cada jogo tem o seu.

var game: Node
var cfg: Dictionary = GameData.GLOBAL_BOSS
var boss: WorldBoss
var defeated_key := ""        # janela (dia+hora) em que o dragão já foi derrotado
var _forced_until := 0.0      # evento forçado pelo admin (horário Unix)
var _forced_key := ""
var _warned := ""
var _started := ""
var _tick := 0.0


func _process(delta: float) -> void:
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 1.0
	if game == null or game.get("player") == null:
		return
	var key := window_key()
	# aviso alguns minutos antes
	var nk := _next_key_soon()
	if nk != "" and nk != _warned:
		_warned = nk
		game.hud.banner("Boss global em %d min" % _minutes_to_next(), "O Dragão Ancestral vai despertar no Covil do Dragão", 4.0)
		Sfx.play("boss", -8.0, 1.2)
	if key != "" and key != _started:
		_started = key
		if key != defeated_key:
			game.hud.banner("O Dragão Ancestral despertou!", "Use o Portal de Viagem: Covil do Dragão  ·  %d min" % minutes_left(), 5.0)
			Sfx.play("boss", -4.0)
	if key != "" and key != defeated_key and game.map_id == String(cfg["map"]) and (boss == null or not is_instance_valid(boss)):
		_spawn()
	if key == "" and boss != null and is_instance_valid(boss) and boss.alive:
		boss.depart()
		game.toast("O tempo acabou: o Dragão Ancestral voou para longe.", 3.0)


## Chave da janela ativa ("2026-10-29-16") ou "" se não houver evento agora.
func window_key() -> String:
	if Time.get_unix_time_from_system() < _forced_until:
		return _forced_key
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
	var d := Time.get_datetime_dict_from_system()
	var nh := (int(d["hour"]) + 1) % 24
	if nh in cfg["hours"] and int(d["minute"]) >= 60 - int(cfg["warn_minutes"]):
		return "%04d-%02d-%02d-%02d" % [d["year"], d["month"], d["day"], nh]
	return ""


func _minutes_to_next() -> int:
	return 60 - int(Time.get_datetime_dict_from_system()["minute"])


## Admin: começa um evento agora, durando `minutes` minutos.
func force(minutes: int) -> void:
	_forced_until = Time.get_unix_time_from_system() + minutes * 60.0
	_forced_key = "teste-%d" % int(_forced_until)
	_tick = 0.0


func _spawn() -> void:
	var z: Dictionary = GameData.ZONES["arena_dragao"]
	boss = WorldBoss.new()
	boss.setup(String(cfg["enemy"]), z["boss_pos"] + Vector3(0, 0.3, 0), "arena_dragao")
	game.actors.add_child(boss)
	boss.died.connect(_on_boss_died)
	boss.phase_changed.connect(func(p: int) -> void:
		var txt := {2: "O dragão levanta voo e chama os filhotes!", 3: "Fúria final: o chão pega fogo!"}
		game.hud.banner("Dragão Ancestral — fase %d" % p, String(txt.get(p, "")), 3.0))
	game.hud.banner("Dragão Ancestral", "Derrote o boss global antes que o tempo acabe (%d min)" % minutes_left(), 3.5)


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
	for k in 8:
		game._drop("gold", int(cfg["reward_gold"]) / 20, "Ouro", at + Vector3(randf_range(-4, 4), 0, randf_range(-4, 4)))
	Vfx.explosion(game.actors, at, 8.0)
	Fx.shake(p, 0.8)
	game.hud.banner("Dragão Ancestral derrotado!", "+%d XP   +%d de ouro   +%d gemas   ·   próximo boss global às %s" % [xp, int(cfg["reward_gold"]), int(cfg["reward_gems"]), next_text()], 5.0)
	p.stats_changed.emit()
	game.save_now()
