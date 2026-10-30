extends Node
## Rede (autoload "Net"). O mesmo projeto roda como:
##  - SERVIDOR: `godot --headless --path . -- --server` (Docker/Easypanel). Escuta WebSocket na porta PORT (8080),
##    confere o login de cada jogador no Supabase, guarda/carrega o save com a chave secreta (SUPABASE_SERVICE_KEY),
##    manda para cada jogador quem mais está no mesmo mapa e controla a vida do boss global (todos batem no mesmo).
##  - CLIENTE (navegador/PC): depois do login, conecta em [server] url do res://supabase.cfg (wss://...).
## Sem servidor configurado, o jogo funciona sozinho como antes.

signal connected
signal loaded(save: Dictionary)
signal boss_hp(hp: int, max_hp: int)
signal boss_rank(top: Array)            # [[nome, dano], ...] top 6
signal boss_reward(rank: int, last_hit: bool, item: String)
signal boss_scheduled(delay: float, minutes: int)
# monstros do servidor (cliente)
signal enemies(map: String, snap: Dictionary)
signal enemy_attack(id: int, slam: bool, center: Vector3, r: float, wind: float)
signal enemy_dead(id: int, credit: bool, drop: String)
signal hurt(dmg: int, id: int)

const SNAP_HZ := 10.0

var is_server := false
var online := false            # cliente conectado e logado no servidor
var server_url := ""
var sb_url := ""
var sb_anon := ""
var sb_service := ""
var my_id := 0
var others: Dictionary = {}     # cliente: id -> {name, cls, gear, map, pos, rot, moving}

# servidor
var _players: Dictionary = {}   # peer -> {uid, name, cls, gear, map, pos, rot, moving, save}
var _boss := {"key": "", "hp": 0, "max": 0, "hits": {}, "atk": {}, "base": 0, "dead": false}
var _rank_t := 0.0
var _boss_dirty := false
var _boss_at := 0.0   # boss invocado pelo admin: começa neste horário Unix do servidor
var _t := 0.0
var _save_t := 0.0
var world: ServerWorld


func _ready() -> void:
	is_server = OS.has_feature("dedicated_server") or "--server" in OS.get_cmdline_user_args() or OS.get_environment("VALE_SERVER") != ""
	var c := ConfigFile.new()
	if c.load("res://supabase.cfg") == OK:
		sb_url = String(c.get_value("supabase", "url", "")).trim_suffix("/")
		sb_anon = String(c.get_value("supabase", "anon_key", ""))
		server_url = String(c.get_value("server", "url", ""))
	if OS.get_environment("SUPABASE_URL") != "":
		sb_url = OS.get_environment("SUPABASE_URL").trim_suffix("/")
	if OS.get_environment("SUPABASE_ANON_KEY") != "":
		sb_anon = OS.get_environment("SUPABASE_ANON_KEY")
	sb_service = OS.get_environment("SUPABASE_SERVICE_KEY")
	if OS.get_environment("VALE_SERVER_URL") != "":
		server_url = OS.get_environment("VALE_SERVER_URL")
	if is_server:
		_start_server()


# =================================================================== servidor

func _start_server() -> void:
	var port := int(OS.get_environment("PORT")) if OS.get_environment("PORT") != "" else 8080
	var peer := WebSocketMultiplayerPeer.new()
	var err := peer.create_server(port)
	if err != OK:
		push_error("Servidor: não abriu a porta %d (%d)" % [port, err])
		get_tree().quit(1)
		return
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_disconnected.connect(_on_left)
	world = ServerWorld.new()
	world.net = self
	add_child(world)
	print("[servidor] Vale das Lendas ouvindo na porta %d · Supabase %s · chave secreta %s" % [port, sb_url, "OK" if sb_service != "" else "FALTANDO"])


func _process(delta: float) -> void:
	if not is_server:
		return
	_t += delta
	if _t >= 1.0 / SNAP_HZ:
		_t = 0.0
		_broadcast()
	_rank_t += delta
	if _rank_t >= 0.25 and _boss_dirty:
		_rank_t = 0.0
		_boss_dirty = false
		_boss_all()
	_save_t += delta
	if _save_t > 60.0:   # grava os saves de todos a cada minuto (e sempre que alguém sai)
		_save_t = 0.0
		for id in _players:
			_store(int(id))


func _broadcast() -> void:
	var by_map := {}
	for id in _players:
		var p: Dictionary = _players[id]
		if not p.has("map"):
			continue
		if not by_map.has(p["map"]):
			by_map[p["map"]] = {}
		by_map[p["map"]][id] = [p["name"], p["cls"], p["gear"], p["pos"], p["rot"], p["moving"], p.get("mount", "")]
	for id in _players:
		var m: Variant = _players[id].get("map", null)
		if m != null:
			_snapshot.rpc_id(int(id), by_map.get(m, {}))


func _on_left(id: int) -> void:
	if _players.has(id):
		_store(id)
		print("[servidor] saiu: ", _players[id]["name"])
		_players.erase(id)


## Cliente pede para entrar com o token do login do Supabase.
@rpc("any_peer", "reliable")
func hello(token: String) -> void:
	if not is_server:
		return
	var id := multiplayer.get_remote_sender_id()
	if OS.get_environment("VALE_DEV") != "":   # teste local sem Supabase: qualquer token entra
		_players[id] = {"uid": "dev-%d" % id, "name": token, "cls": "", "gear": {}, "save": {}, "admin": token.begins_with("admin")}
		_welcome.rpc_id(id, true, {})
		return
	var user := await _sb("/auth/v1/user", HTTPClient.METHOD_GET, null, token)
	if int(user["code"]) != 200 or not (user["json"] is Dictionary):
		_welcome.rpc_id(id, false, {})
		multiplayer.multiplayer_peer.disconnect_peer(id)
		return
	var uid := String(user["json"]["id"])
	var mail := String(user["json"].get("email", "Herói"))
	var row := await _sb("/rest/v1/saves?select=data&user_id=eq." + uid, HTTPClient.METHOD_GET, null)
	var save: Dictionary = {}
	if int(row["code"]) == 200 and row["json"] is Array and not (row["json"] as Array).is_empty():
		save = row["json"][0]["data"]
	var meta: Variant = user["json"].get("app_metadata", {})
	_players[id] = {"uid": uid, "name": mail.get_slice("@", 0), "cls": "", "gear": {}, "save": save,
		"admin": meta is Dictionary and bool(meta.get("admin", false))}
	print("[servidor] entrou: ", mail, " (", _players.size(), " online)")
	_welcome.rpc_id(id, true, save)
	_boss_send(id)
	var left := _boss_at - Time.get_unix_time_from_system()
	if left > -float(GameData.GLOBAL_BOSS["minutes"]) * 60.0 and _boss_at > 0.0:   # entrou durante o aviso/evento
		_boss_call.rpc_id(id, left, int(GameData.GLOBAL_BOSS["minutes"]))


## Estado do herói (10x por segundo, sem garantia de entrega).
@rpc("any_peer", "unreliable_ordered")
func state(map: String, pos: Vector3, rot: float, moving: bool, cls: String, gear: Dictionary, mount: String, alive: bool, hero: String) -> void:
	var id := multiplayer.get_remote_sender_id()
	if not is_server or not _players.has(id):
		return
	var p: Dictionary = _players[id]
	p["map"] = map
	p["pos"] = pos
	p["rot"] = rot
	p["moving"] = moving
	p["cls"] = cls
	if hero != "":   # nome do herói (aparece em cima dele e no ranking do boss)
		p["name"] = GameData.clean_name(hero)
	p["gear"] = gear
	p["mount"] = mount
	p["alive"] = alive


## Golpe num monstro do servidor.
@rpc("any_peer", "reliable")
func enemy_hit(id: int, dmg: int) -> void:
	var pid := multiplayer.get_remote_sender_id()
	if is_server and _players.has(pid) and world != null:
		world.hit(pid, String(_players[pid].get("map", "")), id, dmg)


## Skill aplicou lentidão/atordoamento num monstro do servidor.
@rpc("any_peer", "reliable")
func enemy_effect(id: int, kind: String, amount: float, t: float) -> void:
	var pid := multiplayer.get_remote_sender_id()
	if is_server and _players.has(pid) and world != null:
		world.effect(String(_players[pid].get("map", "")), id, kind, clampf(amount, 0.0, 0.9), clampf(t, 0.0, 6.0))


## Missão pediu o chefe da zona.
@rpc("any_peer", "reliable")
func request_boss(zid: String, type_id: String) -> void:
	var pid := multiplayer.get_remote_sender_id()
	if is_server and _players.has(pid) and world != null:
		world.spawn_boss(String(_players[pid].get("map", "")), zid, type_id)


## Save do jogador: o servidor guarda e grava no Supabase (o navegador não escreve direto no banco).
@rpc("any_peer", "reliable")
func push_save(data: Dictionary) -> void:
	var id := multiplayer.get_remote_sender_id()
	if not is_server or not _players.has(id):
		return
	var p: Dictionary = _players[id]
	var old: Dictionary = p["save"]
	# trava básica contra trapaça: o nível não pode pular de uma vez
	if not old.is_empty() and int(data.get("level", 1)) > int(old.get("level", 1)) + 20:
		print("[servidor] save recusado (nível pulou): ", p["name"])
		return
	p["save"] = data


func _store(id: int) -> void:
	var p: Dictionary = _players.get(id, {})
	if p.is_empty() or (p["save"] as Dictionary).is_empty() or sb_service == "":
		return
	var d: Dictionary = p["save"]
	var row := {"user_id": p["uid"], "data": d, "level": int(d.get("level", 1)), "class": String(d.get("class", "")),
		"saved_at": String(d.get("saved_at", "")), "updated_at": Time.get_datetime_string_from_system(true) + "Z"}
	var r := await _sb("/rest/v1/saves?on_conflict=user_id", HTTPClient.METHOD_POST, row, "", ["Prefer: resolution=merge-duplicates,return=minimal"])
	if int(r["code"]) >= 300:
		print("[servidor] erro ao gravar save de ", p["name"], ": ", r["code"])


## Admin invocou o boss: avisa todos os jogadores (começa em `delay` segundos).
@rpc("any_peer", "reliable")
func admin_boss(delay: float) -> void:
	var id := multiplayer.get_remote_sender_id()
	if not is_server or not _players.has(id) or not bool(_players[id].get("admin", false)):
		return
	delay = clampf(delay, 0.0, 3600.0)
	_boss_at = Time.get_unix_time_from_system() + delay
	_boss = {"key": "", "hp": 0, "max": 0, "hits": {}, "atk": {}, "base": 0, "dead": false}
	print("[servidor] boss global invocado por ", _players[id]["name"], " para daqui a ", int(delay), " s")
	for pid in _players:
		_boss_call.rpc_id(int(pid), delay, int(GameData.GLOBAL_BOSS["minutes"]))


@rpc("authority", "reliable")
func _boss_call(delay: float, minutes: int) -> void:
	boss_scheduled.emit(delay, minutes)


## Boss global: todos batem na mesma vida, que fica no servidor.
## Jogador chegou no boss: entra na conta da vida (ataque × dps_k × target_secs; nunca menos que base × hp_mult).
@rpc("any_peer", "reliable")
func boss_join(key: String, atk: float, base_hp: int) -> void:
	var id := multiplayer.get_remote_sender_id()
	if not is_server or not _players.has(id):
		return
	_boss_window(key, base_hp)
	if bool(_boss["dead"]):
		_boss_send(id)
		return
	_boss["atk"][id] = clampf(atk, 1.0, 1.0e9)
	var cfg: Dictionary = GameData.GLOBAL_BOSS
	var want := 0.0
	for pid in _boss["atk"]:
		want += float(_boss["atk"][pid]) * float(cfg["dps_k"]) * float(cfg["target_secs"])
	var new_max := maxi(int(_boss["base"]) * int(cfg["hp_mult"]), int(want))
	if new_max > int(_boss["max"]):   # chegou mais gente: a vida cresce junto (sem curar o que já foi tirado)
		_boss["hp"] = int(_boss["hp"]) + new_max - int(_boss["max"])
		_boss["max"] = new_max
	_boss_all()


func _boss_window(key: String, base_hp: int) -> void:
	# evento invocado/forçado: cada jogo gera a chave com o próprio relógio; no servidor é um evento só
	if not key.is_valid_int() and not key.contains("-") or key.begins_with("invocado") or key.begins_with("teste"):
		key = "evento-%d" % int(_boss_at)
	if String(_boss["key"]) != key:
		var m := base_hp * int(GameData.GLOBAL_BOSS["hp_mult"])
		_boss = {"key": key, "hp": m, "max": m, "hits": {}, "atk": {}, "base": base_hp, "dead": false}


@rpc("any_peer", "reliable")
func boss_hit(key: String, dmg: int, base_hp: int) -> void:
	var id := multiplayer.get_remote_sender_id()
	if not is_server or not _players.has(id):
		return
	_boss_window(key, base_hp)
	if bool(_boss["dead"]):
		return
	# trava: no máximo 2% da vida do boss por golpe
	dmg = clampi(dmg, 0, int(_boss["max"] * 0.02) + 1)
	dmg = mini(dmg, int(_boss["hp"]))
	_boss["hp"] = int(_boss["hp"]) - dmg
	_boss["hits"][id] = int(_boss["hits"].get(id, 0)) + dmg
	if int(_boss["hp"]) <= 0:
		_boss_dead(id)
		_boss_all()
	else:
		_boss_dirty = true   # manda vida e ranking 4x por segundo (não a cada golpe)


func _boss_dead(last: int) -> void:
	_boss["dead"] = true
	var order: Array = _boss["hits"].keys()
	order.sort_custom(func(a, b) -> bool: return int(_boss["hits"][a]) > int(_boss["hits"][b]))
	var odds: Dictionary = GameData.GLOBAL_BOSS["last_item"]
	for i in order.size():
		var pid := int(order[i])
		if not _players.has(pid):
			continue
		var item := ""
		if pid == last:
			var r := randf()
			item = "lendaria" if r < float(odds["lendaria"]) else ("epica" if r < float(odds["lendaria"]) + float(odds["epica"]) else "rara")
		_boss_reward.rpc_id(pid, i + 1, pid == last, item)
	print("[servidor] boss global derrotado · último golpe: ", _players.get(last, {}).get("name", "?"), " · ", order.size(), " participantes")


func _boss_top() -> Array:
	var order: Array = _boss["hits"].keys()
	order.sort_custom(func(a, b) -> bool: return int(_boss["hits"][a]) > int(_boss["hits"][b]))
	var top: Array = []
	for pid in order.slice(0, 6):
		top.append([String(_players.get(pid, {}).get("name", "?")), int(_boss["hits"][pid])])
	return top


func _boss_all() -> void:
	for pid in _players:
		if String(_players[pid].get("map", "")) == String(GameData.GLOBAL_BOSS["map"]):
			_boss_send(int(pid))


func _boss_send(id: int) -> void:
	if String(_boss["key"]) != "":
		_boss_state.rpc_id(id, String(_boss["key"]), int(_boss["hp"]), int(_boss["max"]), _boss_top())


## Chamada ao Supabase (com a chave secreta, ou com o token do jogador).
func _sb(path: String, method: int, body: Variant, user_token: String = "", extra: Array = []) -> Dictionary:
	var h := HTTPRequest.new()
	h.timeout = 15.0
	add_child(h)
	var k := sb_service if sb_service != "" else sb_anon
	var headers := PackedStringArray(["apikey: " + (sb_anon if user_token != "" else k), "Content-Type: application/json",
		"Authorization: Bearer " + (user_token if user_token != "" else k)])
	for e in extra:
		headers.append(String(e))
	if h.request(sb_url + path, headers, method, JSON.stringify(body) if body != null else "") != OK:
		h.queue_free()
		return {"code": 0, "json": null}
	var res: Array = await h.request_completed
	h.queue_free()
	var txt := (res[3] as PackedByteArray).get_string_from_utf8()
	return {"code": int(res[1]), "json": JSON.parse_string(txt) if txt != "" else null}


# =================================================================== cliente

func connect_to_server(token: String) -> bool:
	if server_url == "" or is_server:
		return false
	# aceita o endereço do Easypanel como https:// (vira wss://, o WebSocket seguro)
	if server_url.begins_with("https://"):
		server_url = "wss://" + server_url.trim_prefix("https://")
	elif server_url.begins_with("http://"):
		server_url = "ws://" + server_url.trim_prefix("http://")
	var peer := WebSocketMultiplayerPeer.new()
	if peer.create_client(server_url) != OK:
		return false
	multiplayer.multiplayer_peer = peer
	var ok: bool = await _wait_connected()
	if not ok:
		multiplayer.multiplayer_peer = null
		return false
	my_id = multiplayer.get_unique_id()
	hello.rpc_id(1, token)
	return true


func _wait_connected() -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 8000:
		var st := multiplayer.multiplayer_peer.get_connection_status()
		if st == MultiplayerPeer.CONNECTION_CONNECTED:
			return true
		if st == MultiplayerPeer.CONNECTION_DISCONNECTED:
			return false
		await get_tree().process_frame
	return false


@rpc("authority", "reliable")
func _welcome(ok: bool, save: Dictionary) -> void:
	online = ok
	if ok:
		connected.emit()
		loaded.emit(save)


@rpc("authority", "unreliable_ordered")
func _snapshot(players: Dictionary) -> void:
	others = {}
	for id in players:
		if int(id) == my_id:
			continue
		var a: Array = players[id]
		others[int(id)] = {"name": a[0], "cls": a[1], "gear": a[2], "pos": a[3], "rot": a[4], "moving": a[5], "mount": a[6]}


@rpc("authority", "unreliable_ordered")
func _enemies(map: String, snap: Dictionary) -> void:
	enemies.emit(map, snap)


@rpc("authority", "reliable")
func _enemy_attack(id: int, slam: bool, center: Vector3, r: float, wind: float) -> void:
	enemy_attack.emit(id, slam, center, r, wind)


@rpc("authority", "reliable")
func _enemy_dead(id: int, credit: bool, drop: String) -> void:
	enemy_dead.emit(id, credit, drop)


@rpc("authority", "reliable")
func _hurt(dmg: int, id: int) -> void:
	hurt.emit(dmg, id)


@rpc("authority", "unreliable_ordered")
func _boss_state(key: String, hp: int, max_hp: int, top: Array) -> void:
	boss_hp.emit(hp, max_hp)
	boss_rank.emit(top)


@rpc("authority", "reliable")
func _boss_reward(rank: int, last_hit: bool, item: String) -> void:
	boss_reward.emit(rank, last_hit, item)


func send_state(map: String, p: Player) -> void:
	if not online:
		return
	state.rpc_id(1, map, p.global_position, p.rotation.y, p.velocity.length() > 0.5, p.class_key, p.visual_rarities(), p.mount if p.riding else "", p.alive, p.hero_name)


func send_save(data: Dictionary) -> void:
	if online:
		push_save.rpc_id(1, data)
