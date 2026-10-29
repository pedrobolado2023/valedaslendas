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
var _boss := {"key": "", "hp": 0, "max": 0}
var _t := 0.0
var _save_t := 0.0


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
	print("[servidor] Vale das Lendas ouvindo na porta %d · Supabase %s · chave secreta %s" % [port, sb_url, "OK" if sb_service != "" else "FALTANDO"])


func _process(delta: float) -> void:
	if not is_server:
		return
	_t += delta
	if _t >= 1.0 / SNAP_HZ:
		_t = 0.0
		_broadcast()
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
		_players[id] = {"uid": "dev-%d" % id, "name": token, "cls": "", "gear": {}, "save": {}}
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
	_players[id] = {"uid": uid, "name": mail.get_slice("@", 0), "cls": "", "gear": {}, "save": save}
	print("[servidor] entrou: ", mail, " (", _players.size(), " online)")
	_welcome.rpc_id(id, true, save)
	_boss_send(id)


## Estado do herói (10x por segundo, sem garantia de entrega).
@rpc("any_peer", "unreliable_ordered")
func state(map: String, pos: Vector3, rot: float, moving: bool, cls: String, gear: Dictionary, mount: String) -> void:
	var id := multiplayer.get_remote_sender_id()
	if not is_server or not _players.has(id):
		return
	var p: Dictionary = _players[id]
	p["map"] = map
	p["pos"] = pos
	p["rot"] = rot
	p["moving"] = moving
	p["cls"] = cls
	p["gear"] = gear
	p["mount"] = mount


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


## Boss global: todos batem na mesma vida, que fica no servidor.
@rpc("any_peer", "reliable")
func boss_hit(key: String, dmg: int, max_hp: int) -> void:
	var id := multiplayer.get_remote_sender_id()
	if not is_server or not _players.has(id):
		return
	if String(_boss["key"]) != key:
		_boss = {"key": key, "hp": max_hp, "max": max_hp}
	# trava: no máximo 5% da vida do boss por golpe
	_boss["hp"] = maxi(0, int(_boss["hp"]) - clampi(dmg, 0, int(_boss["max"] * 0.05) + 1))
	for pid in _players:
		if String(_players[pid].get("map", "")) == String(GameData.GLOBAL_BOSS["map"]):
			_boss_send(int(pid))


func _boss_send(id: int) -> void:
	if String(_boss["key"]) != "":
		_boss_state.rpc_id(id, String(_boss["key"]), int(_boss["hp"]), int(_boss["max"]))


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


@rpc("authority", "reliable")
func _boss_state(key: String, hp: int, max_hp: int) -> void:
	boss_hp.emit(hp, max_hp)


func send_state(map: String, p: Player) -> void:
	if not online:
		return
	state.rpc_id(1, map, p.global_position, p.rotation.y, p.velocity.length() > 0.5, p.class_key, p.visual_rarities(), p.mount if p.riding else "")


func send_save(data: Dictionary) -> void:
	if online:
		push_save.rpc_id(1, data)
