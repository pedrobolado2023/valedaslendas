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
signal chat_msg(channel: String, from: String, text: String)
signal party_changed(members: Array)
signal party_invited(from: String)
signal online_names(names: Array)
signal item_received(item: Dictionary, from: String)
signal gift_done(uid: int, ok: bool, msg: String)
signal ranking_list(rows: Array)
signal market_rows(rows: Array)
signal world_event(kind: String, map: String, pos: Vector3, text: String)
signal guild_info(info: Dictionary)
signal guild_invited(guild: String, from: String)
signal guild_rank(rows: Array)
signal market_event(kind: String, data: Dictionary)
signal duel_asked(from: String)
signal duel_started(peer: int, name: String)
signal duel_ended(winner: String)
signal pvp_hurt(dmg: int)
# monstros do servidor (cliente)
signal enemies(map: String, snap: Dictionary)
signal enemy_attack(id: int, slam: bool, center: Vector3, r: float, wind: float)
signal enemy_dead(id: int, credit: bool, drop: String)
signal hurt(dmg: int, id: int)
signal dungeon_event(kind: String, data: Dictionary)
signal war_info(crown: String, points: Dictionary, last: Dictionary)

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
## Painel admin (página /admin): configuração aplicada no jogo e comandos lidos da tabela admin_commands.
var cfg := {"xp_mult": 1.0, "gold_mult": 1.0, "drop_mult": 1.0, "motd": "", "maintenance": false}
var _adm_t := 0.0
var _adm_busy := false
var _st_t := 0.0
var _started := 0.0


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
	_market_load()
	_guild_load()
	_started = Time.get_unix_time_from_system()
	_config_load()
	_war_load()
	print("[servidor] Vale das Lendas ouvindo na porta %d · Supabase %s · chave secreta %s" % [port, sb_url, "OK" if sb_service != "" else "FALTANDO"])


func _process(delta: float) -> void:
	if not is_server:
		return
	_t += delta
	if _t >= 1.0 / SNAP_HZ:
		_t = 0.0
		_broadcast()
	_ev_t += delta
	if _ev_t >= float(GameData.WORLD_EVENT["every"]) and not _players.is_empty():
		_ev_t = 0.0
		_start_event("bau" if randf() < 0.6 else "invasao")
	_adm_t += delta
	if _adm_t >= 3.0 and not _adm_busy and _db():
		_adm_t = 0.0
		_admin_poll()
	_st_t += delta
	if _st_t >= 10.0 and _db():
		_st_t = 0.0
		_status_push()
	_rank_t += delta
	if _rank_t >= 0.25 and _boss_dirty:
		_rank_t = 0.0
		_boss_dirty = false
		_boss_all()
	_save_t += delta
	if _save_t > 60.0:
		_war_check()
		_war_save()
		for gk in _guilds:   # pontos de guilda: grava de minuto em minuto
			if _guilds[gk].get("dirty", false):
				_guilds[gk].erase("dirty")
				_guild_save(String(gk))   # grava os saves de todos a cada minuto (e sempre que alguém sai)
		_save_t = 0.0
		for id in _players:
			_store(int(id))


func _broadcast() -> void:
	var by_map := {}
	for id in _players:
		var p: Dictionary = _players[id]
		if not p.has("map"):
			continue
		var mk := map_key(int(id))
		if not by_map.has(mk):
			by_map[mk] = {}
		by_map[mk][id] = [p["name"], p["cls"], p["gear"], p["pos"], p["rot"], p["moving"], p.get("mount", ""), String(p.get("guild", "")), String(p.get("kingdom", ""))]
	for id in _players:
		if _players[id].has("map"):
			_snapshot.rpc_id(int(id), by_map.get(map_key(int(id)), {}))


func _on_left(id: int) -> void:
	if _players.has(id):
		_party_remove(id)
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
		_players[id] = {"uid": "dev-%d" % id, "name": token, "cls": "", "gear": {}, "save": {"chars": [], "cur": 0}, "admin": token.begins_with("admin")}
		_players[id]["save_t"] = Time.get_unix_time_from_system()
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
	save = SaveGame.normalize(save)   # conta com vários heróis
	var meta: Variant = user["json"].get("app_metadata", {})
	var is_adm: bool = meta is Dictionary and bool(meta.get("admin", false))
	var ban := await _sb("/rest/v1/bans?select=reason&user_id=eq." + uid, HTTPClient.METHOD_GET, null)
	var refuse := ""
	if ban["json"] is Array and not (ban["json"] as Array).is_empty():
		refuse = "Conta banida. " + String(ban["json"][0].get("reason", ""))
	elif bool(cfg["maintenance"]) and not is_adm:
		refuse = "Servidor em manutenção. Volte daqui a pouco!"
	if refuse != "":
		_world_ev.rpc_id(id, "expulso", "", Vector3.ZERO, refuse)
		_welcome.rpc_id(id, false, {})
		Fx.later(self, 1.0).connect(func() -> void: multiplayer.multiplayer_peer.disconnect_peer(id))
		return
	_players[id] = {"uid": uid, "name": mail.get_slice("@", 0), "cls": "", "gear": {}, "save": save, "admin": is_adm}
	print("[servidor] entrou: ", mail, " (", _players.size(), " online)")
	_players[id]["save_t"] = Time.get_unix_time_from_system()
	_welcome.rpc_id(id, true, save)
	_config.rpc_id(id, cfg)
	if String(cfg["motd"]) != "":
		_world_ev.rpc_id(id, "anuncio", "", Vector3.ZERO, String(cfg["motd"]))
	_market_payouts(id)
	_guild_join_online(id)
	_players[id]["kingdom"] = String(_cur_char(id).get("kingdom", ""))
	_war_check()
	_war_info.rpc_id(id, String(_war["crown"]), _war["points"], _war["last"])
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
	if String(p.get("inst", "")) != "":   # instância: chegou, saiu ou desistiu de ir
		if map == String(p["inst_map"]):
			p["inst_ok"] = true
		elif bool(p.get("inst_ok", false)) or Time.get_unix_time_from_system() - float(p["inst_t"]) > 40.0:
			p["inst"] = ""
	p["pos"] = pos
	p["rot"] = rot
	p["moving"] = moving
	p["cls"] = cls
	if hero != "":   # nome do herói (aparece em cima dele e no ranking do boss)
		p["name"] = GameData.clean_name(hero)
	p["gear"] = gear
	p["mount"] = mount
	p["alive"] = alive
	if not alive and int(p.get("duel", 0)) != 0:   # caiu no duelo
		pvp_dead_srv(id)


## Golpe num monstro do servidor.
@rpc("any_peer", "reliable")
func enemy_hit(id: int, dmg: int) -> void:
	var pid := multiplayer.get_remote_sender_id()
	if is_server and _players.has(pid) and world != null:
		world.hit(pid, map_key(pid), id, dmg)


## Skill aplicou lentidão/atordoamento num monstro do servidor.
@rpc("any_peer", "reliable")
func enemy_effect(id: int, kind: String, amount: float, t: float) -> void:
	var pid := multiplayer.get_remote_sender_id()
	if is_server and _players.has(pid) and world != null:
		world.effect(map_key(pid), id, kind, clampf(amount, 0.0, 0.9), clampf(t, 0.0, 6.0))


## Skill empurrou/puxou um monstro do servidor.
@rpc("any_peer", "reliable")
func enemy_move(id: int, to: Vector3) -> void:
	var pid := multiplayer.get_remote_sender_id()
	if is_server and _players.has(pid) and world != null:
		world.move(map_key(pid), id, to)


## Mapa "de verdade" do jogador no servidor: o mapa, ou "mapa#instância" na masmorra/boss da guilda.
func map_key(id: int) -> String:
	var p: Dictionary = _players.get(id, {})
	if String(p.get("inst", "")) != "":
		return String(p["inst_map"]) + "#" + String(p["inst"])
	return String(p.get("map", ""))


var _dg_limits := {}   # "uid|herói" -> {"day", "count", "week"} (masmorras por dia, boss da guilda por semana)


## Entrar na masmorra (ou boss da guilda): o grupo que está no mesmo mapa vai junto; o servidor confere os limites.
@rpc("any_peer", "reliable")
func dungeon_enter(diff: String, guild: bool) -> void:
	var id := multiplayer.get_remote_sender_id()
	if not is_server or not _players.has(id) or world == null or String(_players[id].get("inst", "")) != "":
		return
	if not GameData.DUNGEON_DIFF.has(diff):
		diff = "normal"
	var lead: Dictionary = _players[id]
	var gk := String(lead.get("guild", "")).to_lower()
	if guild and gk == "":
		_dungeon_ev.rpc_id(id, "refused", {"why": "Entre em uma guilda para enfrentar o boss da guilda."})
		return
	var members: Array = []
	var wk := Dungeon.week_key()
	var today := Rewards.today()
	for mid in party_of(id):
		var q: Dictionary = _players[mid]
		if mid != id and (String(q.get("map", "")) != String(lead.get("map", "")) or String(q.get("inst", "")) != ""):
			continue
		var lk := "%s|%d" % [q["uid"], int(q["save"].get("cur", 0))]
		var lim: Dictionary = _dg_limits.get(lk, {})
		var why := ""
		if guild:
			if String(q.get("guild", "")).to_lower() != gk:
				why = "não é da guilda"
			elif int(lim.get("week", -1)) == wk:
				why = "já derrotou o boss da guilda esta semana"
		elif String(lim.get("day", "")) == today and int(lim.get("count", 0)) >= int(GameData.DUNGEON["per_day"]):
			why = "já fez as %d masmorras de hoje" % int(GameData.DUNGEON["per_day"])
		if why != "":
			if mid == id:
				_dungeon_ev.rpc_id(id, "refused", {"why": "Você " + why + "."})
				return
			_dungeon_ev.rpc_id(int(mid), "refused", {"why": "Seu grupo entrou na masmorra, mas você " + why + "."})
			continue
		if guild:
			lim["week"] = wk
		else:
			lim["count"] = (int(lim.get("count", 0)) if String(lim.get("day", "")) == today else 0) + 1
			lim["day"] = today
		_dg_limits[lk] = lim
		members.append(mid)
	world.start_dungeon(members, diff, guild, int(_cur_char(id).get("level", 1)))


@rpc("authority", "reliable")
func _dungeon_ev(kind: String, data: Dictionary) -> void:
	dungeon_event.emit(kind, data)


## Missão pediu o chefe da zona.
@rpc("any_peer", "reliable")
func request_boss(zid: String, type_id: String) -> void:
	var pid := multiplayer.get_remote_sender_id()
	if is_server and _players.has(pid) and world != null:
		world.spawn_boss(map_key(pid), zid, type_id)


## Save do jogador: o servidor guarda e grava no Supabase (o navegador não escreve direto no banco).
@rpc("any_peer", "reliable")
func push_save(data: Dictionary, slot: int = 0) -> void:
	var id := multiplayer.get_remote_sender_id()
	if not is_server or not _players.has(id):
		return
	var p: Dictionary = _players[id]
	slot = clampi(slot, 0, SaveGame.MAX_CHARS - 1)
	var acc: Dictionary = p["save"]
	var ch: Array = acc["chars"]
	if slot > ch.size():
		return
	var why := _save_check(p, data, ch[slot] if slot < ch.size() else {})
	if why != "":
		print("[servidor] save recusado de ", p["name"], ": ", why)
		_save_refused.rpc_id(id, why)
		return
	if slot < ch.size():
		ch[slot] = data
	else:
		ch.append(data)
	acc["cur"] = slot
	acc["saved_at"] = String(data.get("saved_at", ""))
	p["level"] = int(data.get("level", 1))
	p["kingdom"] = String(data.get("kingdom", ""))
	p["save_t"] = Time.get_unix_time_from_system()
	p["credit_gems"] = 0
	p["credit_gold"] = 0
	p["credit_items"] = 0


## Chat: geral (todos), mapa (mesmo mapa), privado (pelo nome do herói), grupo. 1 mensagem a cada 0,7 s.
@rpc("any_peer", "reliable")
func chat(ch: String, text: String, to: String) -> void:
	var id := multiplayer.get_remote_sender_id()
	if not is_server or not _players.has(id):
		return
	var p: Dictionary = _players[id]
	var now := Time.get_ticks_msec()
	if now - int(p.get("chat_t", 0)) < 700:
		return
	p["chat_t"] = now
	text = text.strip_edges().substr(0, 140)
	if text == "":
		return
	var from := String(p["name"])
	match ch:
		"mapa":
			for pid in _players:
				if String(_players[pid].get("map", "")) == String(p.get("map", "")):
					_chat_to.rpc_id(int(pid), "mapa", from, text)
		"privado":
			var found := false
			for pid in _players:
				if String(_players[pid]["name"]).to_lower() == to.to_lower():
					_chat_to.rpc_id(int(pid), "privado", from, text)
					found = true
			_chat_to.rpc_id(id, "privado" if found else "sistema", "para " + to if found else "", text if found else "%s não está online." % to)
		"grupo":
			for pid in party_of(id):
				_chat_to.rpc_id(int(pid), "grupo", from, text)
		"guilda":
			var gk := String(p.get("guild", "")).to_lower()
			if gk == "":
				_chat_to.rpc_id(id, "sistema", "", "Você não está numa guilda.")
				return
			for pid in _players:
				if String(_players[pid].get("guild", "")).to_lower() == gk:
					_chat_to.rpc_id(int(pid), "guilda", from, text)
		_:
			for pid in _players:
				_chat_to.rpc_id(int(pid), "geral", from, text)


@rpc("authority", "reliable")
func _chat_to(ch: String, from: String, text: String) -> void:
	chat_msg.emit(ch, from, text)


## ---------- grupo (até 5)
var _next_party := 1


func _find(nm: String) -> int:
	for pid in _players:
		if String(_players[pid]["name"]).to_lower() == nm.to_lower():
			return int(pid)
	return 0


@rpc("any_peer", "reliable")
func party_invite(nm: String) -> void:
	var id := multiplayer.get_remote_sender_id()
	var to := _find(nm)
	if not is_server or not _players.has(id):
		return
	if to == 0 or to == id:
		_chat_to.rpc_id(id, "sistema", "", "%s não está online." % nm)
		return
	if party_of(id).size() >= 5:
		_chat_to.rpc_id(id, "sistema", "", "Seu grupo está cheio (5).")
		return
	_players[to]["invite_from"] = id
	_party_invite_to.rpc_id(to, String(_players[id]["name"]))
	_chat_to.rpc_id(id, "sistema", "", "Convite enviado para %s." % nm)


@rpc("any_peer", "reliable")
func party_accept() -> void:
	var id := multiplayer.get_remote_sender_id()
	if not is_server or not _players.has(id):
		return
	var from := int(_players[id].get("invite_from", 0))
	if not _players.has(from):
		return
	_party_remove(id)
	if _players[from].get("party", null) == null:
		_players[from]["party"] = _next_party
		_next_party += 1
	_players[id]["party"] = _players[from]["party"]
	_party_sync(id)


@rpc("any_peer", "reliable")
func party_leave() -> void:
	var id := multiplayer.get_remote_sender_id()
	if is_server and _players.has(id):
		_party_remove(id)
		_party_list.rpc_id(id, [])


func _party_remove(id: int) -> void:
	var mates := party_of(id)
	_players[id]["party"] = null
	mates.erase(id)
	if mates.size() == 1:
		_players[mates[0]]["party"] = null
		_party_list.rpc_id(int(mates[0]), [])
	elif not mates.is_empty():
		_party_sync(int(mates[0]))


func _party_sync(id: int) -> void:
	var names: Array = []
	for pid in party_of(id):
		names.append(String(_players[pid]["name"]))
	for pid in party_of(id):
		_party_list.rpc_id(int(pid), names)


@rpc("authority", "reliable")
func _party_invite_to(from: String) -> void:
	party_invited.emit(from)


@rpc("authority", "reliable")
func _party_list(names: Array) -> void:
	party_changed.emit(names)


## ---------- amigos: quem está online agora
@rpc("any_peer", "reliable")
func who_online() -> void:
	var id := multiplayer.get_remote_sender_id()
	if is_server and _players.has(id):
		var names: Array = []
		for pid in _players:
			names.append(String(_players[pid]["name"]))
		_online_list.rpc_id(id, names)


@rpc("authority", "reliable")
func _online_list(names: Array) -> void:
	online_names.emit(names)


## ---------- enviar item para outro jogador online (o servidor confere se o item é mesmo de quem envia)
@rpc("any_peer", "reliable")
func send_item(to_name: String, uid: int) -> void:
	var id := multiplayer.get_remote_sender_id()
	if not is_server or not _players.has(id):
		return
	var to := _find(to_name)
	if to == 0 or to == id:
		_gift_result.rpc_id(id, uid, false, "%s não está online." % to_name)
		return
	var acc: Dictionary = _players[id]["save"]
	var cur := int(acc.get("cur", 0))
	var ch: Array = acc.get("chars", [])
	if cur >= ch.size():
		return
	var inv: Array = ch[cur].get("inventory", [])
	var gear: Dictionary = ch[cur].get("gear", {})
	for k in gear:
		if int(gear[k]) == uid:
			_gift_result.rpc_id(id, uid, false, "Tire o item do corpo antes de enviar.")
			return
	for i in inv.size():
		if int(inv[i].get("uid", -1)) == uid:
			var item: Dictionary = inv[i]
			inv.remove_at(i)
			_players[to]["credit_items"] = int(_players[to].get("credit_items", 0)) + 1
			_gift_in.rpc_id(to, item, String(_players[id]["name"]))
			_gift_result.rpc_id(id, uid, true, "Item enviado para %s." % to_name)
			print("[servidor] item ", uid, " de ", _players[id]["name"], " para ", to_name)
			return
	_gift_result.rpc_id(id, uid, false, "Salve o jogo e tente de novo (o servidor ainda não viu esse item).")


@rpc("authority", "reliable")
func _gift_in(item: Dictionary, from: String) -> void:
	item_received.emit(item, from)


@rpc("authority", "reliable")
func _gift_result(uid: int, ok: bool, msg: String) -> void:
	gift_done.emit(uid, ok, msg)


## ---------- guildas: {name_key: {name, leader(uid), members [{uid, name}], points}}
var _guilds := {}


func _guild_load() -> void:
	if not _db():
		return
	var r := await _sb("/rest/v1/guilds?select=*", HTTPClient.METHOD_GET, null)
	if r["json"] is Array:
		for row in r["json"]:
			_guilds[String(row["name_key"])] = {"name": String(row["name"]), "leader": String(row["leader"]), "members": row["members"], "points": int(row["points"])}


func _guild_save(key: String) -> void:
	if not _db():
		return
	if not _guilds.has(key):
		_sb("/rest/v1/guilds?name_key=eq." + key.uri_encode(), HTTPClient.METHOD_DELETE, null)
		return
	var g: Dictionary = _guilds[key]
	_sb("/rest/v1/guilds?on_conflict=name_key", HTTPClient.METHOD_POST, {"name_key": key, "name": g["name"], "leader": g["leader"], "members": g["members"], "points": g["points"]}, "", ["Prefer: resolution=merge-duplicates,return=minimal"])


func _guild_of_uid(uid: String) -> String:
	for k in _guilds:
		for m in _guilds[k]["members"]:
			if String(m["uid"]) == uid:
				return String(k)
	return ""


func _guild_join_online(id: int) -> void:
	var k := _guild_of_uid(String(_players[id]["uid"]))
	_players[id]["guild"] = String(_guilds[k]["name"]) if k != "" else ""
	_guild_send(id)


func _guild_send(id: int) -> void:
	var k := String(_players[id].get("guild", "")).to_lower()
	var info := {}
	if _guilds.has(k):
		var g: Dictionary = _guilds[k]
		var mem: Array = []
		for m in g["members"]:
			var on := false
			for pid in _players:
				on = on or String(_players[pid]["uid"]) == String(m["uid"])
			mem.append([String(m["name"]), on, String(m["uid"]) == String(g["leader"])])
		info = {"name": g["name"], "points": g["points"], "members": mem, "leader": String(g["leader"]) == String(_players[id]["uid"])}
	_guild_info_to.rpc_id(id, info)


func _guild_refresh(key: String) -> void:
	for pid in _players:
		if String(_players[pid].get("guild", "")).to_lower() == key:
			_guild_send(int(pid))


@rpc("any_peer", "reliable")
func guild_create(nm: String) -> void:
	var id := multiplayer.get_remote_sender_id()
	if not is_server or not _players.has(id):
		return
	nm = GameData.clean_name(nm).substr(0, 16)
	var key := nm.to_lower()
	var c := _cur_char(id)
	if nm.length() < 3:
		return _chat_to.rpc_id(id, "sistema", "", "Nome da guilda: 3 a 16 letras.")
	if String(_players[id].get("guild", "")) != "":
		return _chat_to.rpc_id(id, "sistema", "", "Saia da sua guilda antes de criar outra.")
	if _guilds.has(key):
		return _chat_to.rpc_id(id, "sistema", "", "Já existe uma guilda com esse nome.")
	if int(c.get("gems", 0)) < int(GameData.GUILD["cost"]):
		return _chat_to.rpc_id(id, "sistema", "", "Criar guilda custa %d gemas." % GameData.GUILD["cost"])
	c["gems"] = int(c.get("gems", 0)) - int(GameData.GUILD["cost"])
	_guilds[key] = {"name": nm, "leader": String(_players[id]["uid"]), "members": [{"uid": String(_players[id]["uid"]), "name": String(_players[id]["name"])}], "points": 0}
	_players[id]["guild"] = nm
	_guild_save(key)
	_guild_paid.rpc_id(id, int(GameData.GUILD["cost"]))
	_guild_send(id)


@rpc("any_peer", "reliable")
func guild_invite(nm: String) -> void:
	var id := multiplayer.get_remote_sender_id()
	if not is_server or not _players.has(id):
		return
	var k := String(_players[id].get("guild", "")).to_lower()
	var to := _find(nm)
	if k == "" or to == 0:
		return _chat_to.rpc_id(id, "sistema", "", "%s precisa estar online (e você numa guilda)." % nm)
	if (_guilds[k]["members"] as Array).size() >= int(GameData.GUILD["max_members"]):
		return _chat_to.rpc_id(id, "sistema", "", "Guilda cheia.")
	_players[to]["guild_invite"] = k
	_guild_inv.rpc_id(to, String(_guilds[k]["name"]), String(_players[id]["name"]))
	_chat_to.rpc_id(id, "sistema", "", "Convite da guilda enviado para %s." % nm)


@rpc("any_peer", "reliable")
func guild_accept() -> void:
	var id := multiplayer.get_remote_sender_id()
	if not is_server or not _players.has(id):
		return
	var k := String(_players[id].get("guild_invite", ""))
	if not _guilds.has(k) or String(_players[id].get("guild", "")) != "":
		return
	(_guilds[k]["members"] as Array).append({"uid": String(_players[id]["uid"]), "name": String(_players[id]["name"])})
	_players[id]["guild"] = String(_guilds[k]["name"])
	_guild_save(k)
	_guild_refresh(k)


@rpc("any_peer", "reliable")
func guild_leave(kick_name: String = "") -> void:
	var id := multiplayer.get_remote_sender_id()
	if not is_server or not _players.has(id):
		return
	var k := String(_players[id].get("guild", "")).to_lower()
	if not _guilds.has(k):
		return
	var g: Dictionary = _guilds[k]
	var uid := String(_players[id]["uid"])
	var target := uid
	if kick_name != "":
		if String(g["leader"]) != uid:
			return
		for m in g["members"]:
			if String(m["name"]).to_lower() == kick_name.to_lower():
				target = String(m["uid"])
	var mem: Array = g["members"]
	for i in range(mem.size() - 1, -1, -1):
		if String(mem[i]["uid"]) == target:
			mem.remove_at(i)
	for pid in _players:
		if String(_players[pid]["uid"]) == target:
			_players[pid]["guild"] = ""
			_guild_send(int(pid))
	if mem.is_empty():
		_guilds.erase(k)
	elif String(g["leader"]) == target:
		g["leader"] = String(mem[0]["uid"])
	_guild_save(k)
	_guild_refresh(k)


# ------------------------------------------------------------------ Guerra dos Reinos (semanal)

var _war := {"week": -1, "points": {}, "last": {}, "crown": ""}
var _war_dirty := false


func _war_load() -> void:
	_war["week"] = Dungeon.week_key()
	if not _db():
		return
	var r := await _sb("/rest/v1/kingdom_war?select=data&id=eq.1", HTTPClient.METHOD_GET, null)
	if r["json"] is Array and not (r["json"] as Array).is_empty() and r["json"][0]["data"] is Dictionary:
		var d: Dictionary = r["json"][0]["data"]
		for k in ["week", "points", "last", "crown"]:
			if d.has(k):
				_war[k] = d[k]
	_war_check()


## Virou a semana: o reino com mais pontos ganha a Coroa e os pontos zeram.
func _war_check() -> void:
	var wk := Dungeon.week_key()
	if int(_war["week"]) == wk:
		return
	var best := ""
	var bp := 0
	for k in _war["points"]:
		if int(_war["points"][k]) > bp:
			bp = int(_war["points"][k])
			best = String(k)
	_war["crown"] = best
	_war["last"] = _war["points"]
	_war["points"] = {}
	_war["week"] = wk
	_war_dirty = true
	for pid in _players:
		_war_info.rpc_id(int(pid), best, {}, _war["last"])
	print("[servidor] nova semana da Guerra dos Reinos; coroa: ", best)


func kingdom_points(id: int, n: int) -> void:
	var kg := String(_players.get(id, {}).get("kingdom", ""))
	if kg == "" or n <= 0:
		return
	_war_check()
	_war["points"][kg] = int(_war["points"].get(kg, 0)) + n
	_war_dirty = true


func _war_save() -> void:
	if _war_dirty and _db():
		_war_dirty = false
		_sb("/rest/v1/kingdom_war?on_conflict=id", HTTPClient.METHOD_POST, {"id": 1, "data": _war}, "", ["Prefer: resolution=merge-duplicates,return=minimal"])


@rpc("any_peer", "reliable")
func kingdom_set(kg: String) -> void:
	var id := multiplayer.get_remote_sender_id()
	if is_server and _players.has(id) and GameData.KINGDOM_BONUS.has(kg):
		_players[id]["kingdom"] = kg


@rpc("any_peer", "reliable")
func kingdom_rank() -> void:
	var id := multiplayer.get_remote_sender_id()
	if is_server and _players.has(id):
		_war_check()
		_war_info.rpc_id(id, String(_war["crown"]), _war["points"], _war["last"])


@rpc("authority", "reliable")
func _war_info(crown: String, points: Dictionary, last: Dictionary) -> void:
	war_info.emit(crown, points, last)


## Pontos da guilda (monstros mortos, dano no boss).
func guild_points(id: int, n: int) -> void:
	var k := String(_players.get(id, {}).get("guild", "")).to_lower()
	if _guilds.has(k) and n > 0:
		_guilds[k]["points"] = int(_guilds[k]["points"]) + n
		_guilds[k]["dirty"] = true


@rpc("any_peer", "reliable")
func guild_ranking() -> void:
	var id := multiplayer.get_remote_sender_id()
	if not is_server or not _players.has(id):
		return
	var rows: Array = []
	for k in _guilds:
		rows.append([String(_guilds[k]["name"]), int(_guilds[k]["points"]), (_guilds[k]["members"] as Array).size()])
	rows.sort_custom(func(a, b) -> bool: return int(a[1]) > int(b[1]))
	_guild_rank_to.rpc_id(id, rows.slice(0, 20))


@rpc("authority", "reliable")
func _guild_info_to(info: Dictionary) -> void:
	guild_info.emit(info)


@rpc("authority", "reliable")
func _guild_inv(g: String, from: String) -> void:
	guild_invited.emit(g, from)


@rpc("authority", "reliable")
func _guild_rank_to(rows: Array) -> void:
	guild_rank.emit(rows)


@rpc("authority", "reliable")
func _guild_paid(gems: int) -> void:
	market_event.emit("guilda_paga", {"gems": gems})


## ---------- eventos no mundo
var _ev_t := 0.0
var _chest := {}   # {"map", "pos"} enquanto ninguém pegou


func _busy_map() -> String:
	var count := {}
	for pid in _players:
		var m := String(_players[pid].get("map", ""))
		if GameData.MAPS.has(m) and not bool(GameData.MAPS[m].get("event", false)):
			count[m] = int(count.get(m, 0)) + 1
	var best := "vale"
	for m in count:
		if int(count[m]) > int(count.get(best, 0)):
			best = m
	return best


func _start_event(kind: String) -> void:
	var m := _busy_map()
	var mname := String(GameData.MAPS[m]["name"])
	if kind == "bau":
		var a := randf() * TAU
		var pos := Vector3(cos(a), 0, sin(a)) * randf_range(25.0, 60.0)
		_chest = {"map": m, "pos": pos}
		for pid in _players:
			_world_ev.rpc_id(int(pid), "bau", m, pos, "Um Baú Dourado apareceu em %s! O primeiro a chegar leva." % mname)
	else:
		if world != null and world.maps.has(m):
			for zid in GameData.MAPS[m]["zones"]:
				for i in int(GameData.WORLD_EVENT["invasion_count"]) / 3:
					var e: Dictionary = world._spawn(m, String(zid), String(GameData.ZONES[zid]["enemy"]), false)
					var a2 := randf() * TAU
					e["pos"] = Vector3(cos(a2), 0, sin(a2)) * randf_range(10.0, 22.0)
					e["home"] = e["pos"]
		for pid in _players:
			_world_ev.rpc_id(int(pid), "invasao", m, Vector3.ZERO, "Invasão! Monstros atacam o acampamento de %s." % mname)
	print("[servidor] evento ", kind, " em ", mname)


## Admin: começa um evento agora (teste).
@rpc("any_peer", "reliable")
func admin_event(kind: String) -> void:
	var id := multiplayer.get_remote_sender_id()
	if is_server and _players.has(id) and bool(_players[id].get("admin", false)):
		_start_event(kind)


@rpc("any_peer", "reliable")
func chest_claim() -> void:
	var id := multiplayer.get_remote_sender_id()
	if not is_server or not _players.has(id) or _chest.is_empty():
		return
	var p: Dictionary = _players[id]
	if String(p.get("map", "")) != String(_chest["map"]) or Vector2((p["pos"] as Vector3).x - (_chest["pos"] as Vector3).x, (p["pos"] as Vector3).z - (_chest["pos"] as Vector3).z).length() > 5.0:
		return
	var m := String(_chest["map"])
	_chest = {}
	p["credit_gems"] = int(p.get("credit_gems", 0)) + int(GameData.WORLD_EVENT["chest_gems"])
	p["credit_gold"] = int(p.get("credit_gold", 0)) + 100000
	p["credit_items"] = int(p.get("credit_items", 0)) + 1
	for pid in _players:
		_world_ev.rpc_id(int(pid), "bau_fim", m, Vector3.ZERO, "%s pegou o Baú Dourado!" % p["name"])
	_world_ev.rpc_id(id, "bau_premio", m, Vector3.ZERO, "")


@rpc("authority", "reliable")
func _world_ev(kind: String, m: String, pos: Vector3, text: String) -> void:
	world_event.emit(kind, m, pos, text)


## ---------- Mercadinho do Jogo (anúncios por gemas; imposto de GameData.market_tax; só itens "sell")
var _market: Array = []        # [{id, seller(uid), seller_name, item, price, payout}]
var _market_next := 1
var _dev_payouts := {}         # sem banco: uid -> gemas a receber


func _db() -> bool:
	return sb_service != "" and OS.get_environment("VALE_DEV") == ""


func _market_load() -> void:
	if not _db():
		return
	var r := await _sb("/rest/v1/market?select=*&order=id.desc&limit=500", HTTPClient.METHOD_GET, null)
	if r["json"] is Array:
		for row in r["json"]:
			_market.append({"id": int(row["id"]), "seller": String(row["seller"]), "seller_name": String(row["seller_name"]),
				"item": row["item"], "price": int(row["price"]), "payout": int(row["payout"])})
		print("[servidor] mercadinho: ", _market.size(), " anúncios")


func _cur_char(id: int) -> Dictionary:
	var acc: Dictionary = _players[id]["save"]
	var ch: Array = acc.get("chars", [])
	var cur := int(acc.get("cur", 0))
	return ch[cur] if cur < ch.size() else {}


@rpc("any_peer", "reliable")
func market_list() -> void:
	var id := multiplayer.get_remote_sender_id()
	if not is_server or not _players.has(id):
		return
	var rows: Array = []
	for l in _market.slice(0, 150):
		rows.append({"id": l["id"], "seller": l["seller_name"], "item": l["item"], "price": l["price"], "mine": l["seller"] == _players[id]["uid"]})
	_market_rows_to.rpc_id(id, rows)


@rpc("any_peer", "reliable")
func market_sell(uid: int, price: int) -> void:
	var id := multiplayer.get_remote_sender_id()
	if not is_server or not _players.has(id):
		return
	var cfg: Dictionary = GameData.MARKET
	var c := _cur_char(id)
	var p: Dictionary = _players[id]
	if price < int(cfg["min_price"]) or price > int(cfg["max_price"]):
		_market_reply(id, "erro", {"msg": "Preço entre %d e %d gemas." % [cfg["min_price"], cfg["max_price"]]})
		return
	var mine := 0
	for l in _market:
		mine += 1 if l["seller"] == p["uid"] else 0
	if mine >= int(cfg["max_listings"]):
		_market_reply(id, "erro", {"msg": "Máximo de %d anúncios." % cfg["max_listings"]})
		return
	for k in c.get("gear", {}):
		if int(c["gear"][k]) == uid:
			_market_reply(id, "erro", {"msg": "Tire o item do corpo antes de vender."})
			return
	var inv: Array = c.get("inventory", [])
	for i in inv.size():
		if int(inv[i].get("uid", -1)) == uid:
			var item: Dictionary = inv[i]
			if not bool(item.get("sell", false)):
				_market_reply(id, "erro", {"msg": "Esse item não pode ser vendido."})
				return
			inv.remove_at(i)
			var payout := int(price * (1.0 - GameData.market_tax(int(c.get("level", 1)))))
			var l := {"id": _market_next, "seller": p["uid"], "seller_name": p["name"], "item": item, "price": price, "payout": payout}
			_market_next += 1
			if _db():
				var r := await _sb("/rest/v1/market", HTTPClient.METHOD_POST, {"seller": p["uid"], "seller_name": p["name"], "item": item, "price": price, "payout": payout}, "", ["Prefer: return=representation"])
				if r["json"] is Array and not (r["json"] as Array).is_empty():
					l["id"] = int(r["json"][0]["id"])
			_market.push_front(l)
			_store(id)
			_market_reply(id, "vendendo", {"uid": uid, "price": price, "payout": payout})
			return
	_market_reply(id, "erro", {"msg": "Salve e tente de novo (o servidor ainda não viu esse item)."})


## Anunciar um lote de material da forja (o servidor confere se o jogador tem).
@rpc("any_peer", "reliable")
func market_sell_mat(mat: String, qty: int, price: int) -> void:
	var id := multiplayer.get_remote_sender_id()
	if not is_server or not _players.has(id) or not GameData.MATERIALS.has(mat):
		return
	var cfg: Dictionary = GameData.MARKET
	var c := _cur_char(id)
	var p: Dictionary = _players[id]
	var mats: Dictionary = c.get("mats", {})
	if qty < 1 or int(mats.get(mat, 0)) < qty:
		_market_reply(id, "erro", {"msg": "Você não tem esse tanto de material (salve e tente de novo)."})
		return
	if price < int(cfg["min_price"]) or price > int(cfg["max_price"]):
		_market_reply(id, "erro", {"msg": "Preço entre %d e %d gemas." % [cfg["min_price"], cfg["max_price"]]})
		return
	mats[mat] = int(mats[mat]) - qty
	c["mats"] = mats
	var item := {"slot": "material", "mat": mat, "qty": qty, "rarity": String(GameData.MATERIALS[mat]["rarity"]), "cls": "", "sell": true}
	var payout := int(price * (1.0 - GameData.market_tax(int(c.get("level", 1)))))
	var l := {"id": _market_next, "seller": p["uid"], "seller_name": p["name"], "item": item, "price": price, "payout": payout}
	_market_next += 1
	if _db():
		var r := await _sb("/rest/v1/market", HTTPClient.METHOD_POST, {"seller": p["uid"], "seller_name": p["name"], "item": item, "price": price, "payout": payout}, "", ["Prefer: return=representation"])
		if r["json"] is Array and not (r["json"] as Array).is_empty():
			l["id"] = int(r["json"][0]["id"])
	_market.push_front(l)
	_store(id)
	_market_reply(id, "vendendo_mat", {"mat": mat, "qty": qty, "price": price, "payout": payout})


@rpc("any_peer", "reliable")
func market_buy(lid: int) -> void:
	var id := multiplayer.get_remote_sender_id()
	if not is_server or not _players.has(id):
		return
	for i in _market.size():
		var l: Dictionary = _market[i]
		if int(l["id"]) != lid:
			continue
		var c := _cur_char(id)
		if l["seller"] == _players[id]["uid"]:
			_market_reply(id, "erro", {"msg": "Esse anúncio é seu (use Cancelar)."})
			return
		if int(c.get("gems", 0)) < int(l["price"]):
			_market_reply(id, "erro", {"msg": "Gemas insuficientes."})
			return
		_market.remove_at(i)
		c["gems"] = int(c.get("gems", 0)) - int(l["price"])
		_players[id]["credit_items"] = int(_players[id].get("credit_items", 0)) + 1
		if _db():
			_sb("/rest/v1/market?id=eq.%d" % lid, HTTPClient.METHOD_DELETE, null)
		_pay(String(l["seller"]), int(l["payout"]), "venda: " + GameData.item_name(l["item"]))
		_store(id)
		_market_reply(id, "comprou", {"item": l["item"], "price": l["price"]})
		return
	_market_reply(id, "erro", {"msg": "Alguém já comprou esse item."})


@rpc("any_peer", "reliable")
func market_cancel(lid: int) -> void:
	var id := multiplayer.get_remote_sender_id()
	if not is_server or not _players.has(id):
		return
	for i in _market.size():
		var l: Dictionary = _market[i]
		if int(l["id"]) == lid and l["seller"] == _players[id]["uid"]:
			_market.remove_at(i)
			if _db():
				_sb("/rest/v1/market?id=eq.%d" % lid, HTTPClient.METHOD_DELETE, null)
			_players[id]["credit_items"] = int(_players[id].get("credit_items", 0)) + 1
			_market_reply(id, "voltou", {"item": l["item"]})
			return


## Paga o vendedor: online recebe na hora; offline fica guardado e entra quando ele entrar.
func _pay(uid: String, gems: int, note: String) -> void:
	for pid in _players:
		if String(_players[pid]["uid"]) == uid:
			_players[pid]["credit_gems"] = int(_players[pid].get("credit_gems", 0)) + gems
			_market_reply(int(pid), "pago", {"gems": gems, "note": note})
			return
	if _db():
		_sb("/rest/v1/market_payouts", HTTPClient.METHOD_POST, {"user_id": uid, "gems": gems, "note": note}, "", ["Prefer: return=minimal"])
	else:
		_dev_payouts[uid] = int(_dev_payouts.get(uid, 0)) + gems


func _market_payouts(id: int) -> void:
	var uid := String(_players[id]["uid"])
	var total := 0
	if _db():
		var r := await _sb("/rest/v1/market_payouts?select=gems&user_id=eq." + uid, HTTPClient.METHOD_GET, null)
		if r["json"] is Array:
			for row in r["json"]:
				total += int(row["gems"])
		if total > 0:
			await _sb("/rest/v1/market_payouts?user_id=eq." + uid, HTTPClient.METHOD_DELETE, null)
	else:
		total = int(_dev_payouts.get(uid, 0))
		_dev_payouts.erase(uid)
	if total > 0 and _players.has(id):
		_players[id]["credit_gems"] = int(_players[id].get("credit_gems", 0)) + total
		_market_reply(id, "pago", {"gems": total, "note": "vendas enquanto você estava fora"})


func _market_reply(id: int, kind: String, data: Dictionary) -> void:
	if _players.has(id):
		_market_ev.rpc_id(id, kind, data)


@rpc("authority", "reliable")
func _market_rows_to(rows: Array) -> void:
	market_rows.emit(rows)


@rpc("authority", "reliable")
func _market_ev(kind: String, data: Dictionary) -> void:
	market_event.emit(kind, data)


## ---------- ranking geral (top 20 por nível, do banco; sem banco: quem está online)
@rpc("any_peer", "reliable")
func ranking() -> void:
	var id := multiplayer.get_remote_sender_id()
	if not is_server or not _players.has(id):
		return
	var rows: Array = []
	if sb_service != "" and OS.get_environment("VALE_DEV") == "":
		var r := await _sb("/rest/v1/saves?select=class,level&order=level.desc&limit=20", HTTPClient.METHOD_GET, null)
		if r["json"] is Array:
			for row in r["json"]:
				rows.append([String(row["class"]), int(row["level"])])
	else:
		for pid in _players:
			rows.append([String(_players[pid]["name"]), int(_players[pid].get("level", 1))])
		rows.sort_custom(func(a, b) -> bool: return int(a[1]) > int(b[1]))
	if _players.has(id):
		_ranking_rows.rpc_id(id, rows.slice(0, 20))


@rpc("authority", "reliable")
func _ranking_rows(rows: Array) -> void:
	ranking_list.emit(rows)


## ---------- duelo 1x1 (mesmo mapa): o servidor repassa os golpes; quem cair perde
@rpc("any_peer", "reliable")
func duel_request(nm: String) -> void:
	var id := multiplayer.get_remote_sender_id()
	var to := _find(nm)
	if not is_server or not _players.has(id):
		return
	if to == 0 or to == id or String(_players[to].get("map", "")) != String(_players[id].get("map", "")):
		_chat_to.rpc_id(id, "sistema", "", "%s precisa estar online e no mesmo mapa." % nm)
		return
	if _players[to].get("duel", 0) != 0 or _players[id].get("duel", 0) != 0:
		_chat_to.rpc_id(id, "sistema", "", "Alguém já está em duelo.")
		return
	_players[to]["duel_from"] = id
	_duel_ask.rpc_id(to, String(_players[id]["name"]))
	_chat_to.rpc_id(id, "sistema", "", "Desafio enviado para %s." % nm)


@rpc("any_peer", "reliable")
func duel_accept() -> void:
	var id := multiplayer.get_remote_sender_id()
	if not is_server or not _players.has(id):
		return
	var from := int(_players[id].get("duel_from", 0))
	if not _players.has(from) or _players[from].get("duel", 0) != 0:
		return
	_players[id]["duel"] = from
	_players[from]["duel"] = id
	_duel_go.rpc_id(id, from, String(_players[from]["name"]))
	_duel_go.rpc_id(from, id, String(_players[id]["name"]))


## Golpe no adversário do duelo (dano de PvP = 25% do normal, no máximo 15% da vida dele por golpe).
@rpc("any_peer", "reliable")
func pvp_hit(dmg: int) -> void:
	var id := multiplayer.get_remote_sender_id()
	if not is_server or not _players.has(id):
		return
	var to := int(_players[id].get("duel", 0))
	if _players.has(to):
		_pvp_take.rpc_id(to, maxi(1, int(dmg * 0.25)))


@rpc("any_peer", "reliable")
func pvp_dead() -> void:
	var id := multiplayer.get_remote_sender_id()
	if is_server and _players.has(id):
		pvp_dead_srv(id)


func pvp_dead_srv(id: int) -> void:
	var to := int(_players[id].get("duel", 0))
	_players[id]["duel"] = 0
	if _players.has(to):
		_players[to]["duel"] = 0
		var w := String(_players[to]["name"])
		if String(_players[to].get("kingdom", "")) != String(_players[id].get("kingdom", "")):
			kingdom_points(to, int(GameData.KINGDOM_WAR["duel"]))
		_duel_end.rpc_id(to, w)
		_duel_end.rpc_id(id, w)
		for pid in _players:
			if String(_players[pid].get("map", "")) == String(_players[id].get("map", "")):
				_chat_to.rpc_id(int(pid), "sistema", "", "%s venceu o duelo contra %s!" % [w, _players[id]["name"]])


@rpc("authority", "reliable")
func _duel_ask(from: String) -> void:
	duel_asked.emit(from)


@rpc("authority", "reliable")
func _duel_go(peer: int, nm: String) -> void:
	duel_started.emit(peer, nm)


@rpc("authority", "reliable")
func _duel_end(winner: String) -> void:
	duel_ended.emit(winner)


@rpc("authority", "reliable")
func _pvp_take(dmg: int) -> void:
	pvp_hurt.emit(dmg)


## Grupo do jogador (lista de ids, inclui ele mesmo).
func party_of(id: int) -> Array:
	var pid: Variant = _players.get(id, {}).get("party", null)
	if pid == null:
		return [id]
	var out: Array = []
	for o in _players:
		if _players[o].get("party", null) == pid:
			out.append(o)
	return out


## Apagar um herói da conta.
@rpc("any_peer", "reliable")
func delete_char(i: int) -> void:
	var id := multiplayer.get_remote_sender_id()
	if not is_server or not _players.has(id):
		return
	var ch: Array = _players[id]["save"]["chars"]
	if i >= 0 and i < ch.size():
		ch.remove_at(i)
		_store(id)


## Reserva um nome de herói (único no jogo). Responde com _name_result.
var _dev_names := {}


@rpc("any_peer", "reliable")
func reserve_name_srv(nm: String) -> void:
	var id := multiplayer.get_remote_sender_id()
	if not is_server or not _players.has(id):
		return
	nm = GameData.clean_name(nm)
	var key := nm.to_lower()
	var uid := String(_players[id]["uid"])
	var ok := nm.length() >= 2
	if ok and (OS.get_environment("VALE_DEV") != "" or sb_service == ""):
		ok = not _dev_names.has(key) or _dev_names[key] == uid
		if ok:
			_dev_names[key] = uid
	elif ok:
		var r := await _sb("/rest/v1/hero_names", HTTPClient.METHOD_POST, {"name_key": key, "name": nm, "user_id": uid}, "", ["Prefer: return=minimal"])
		if int(r["code"]) == 409:   # já existe: vale se for do mesmo jogador
			var g := await _sb("/rest/v1/hero_names?select=user_id&name_key=eq." + key.uri_encode(), HTTPClient.METHOD_GET, null)
			ok = g["json"] is Array and not (g["json"] as Array).is_empty() and String(g["json"][0]["user_id"]) == uid
		elif int(r["code"]) >= 300:
			print("[servidor] tabela hero_names indisponível (rodar supabase/seguranca.sql): ", r["code"])
	if _players.has(id):
		_name_result.rpc_id(id, nm, ok)


signal name_checked(nm: String, ok: bool)


@rpc("authority", "reliable")
func _name_result(nm: String, ok: bool) -> void:
	name_checked.emit(nm, ok)


## Cliente: pede o nome ao servidor e espera a resposta (até 8 s; sem resposta, deixa passar).
func reserve_name(nm: String) -> bool:
	if not online:
		return true
	reserve_name_srv.rpc_id(1, nm)
	var t0 := Time.get_ticks_msec()
	var res := [null]
	var cb := func(n: String, ok: bool) -> void:
		if n.to_lower() == GameData.clean_name(nm).to_lower():
			res[0] = ok
	name_checked.connect(cb)
	while res[0] == null and Time.get_ticks_msec() - t0 < 8000:
		await get_tree().process_frame
	name_checked.disconnect(cb)
	return true if res[0] == null else bool(res[0])


## Confere se o save novo é possível a partir do anterior (contra trapaça). Devolve "" se estiver ok.
## Generoso de propósito: quem joga normal nunca é barrado; quem edita o jogo para se dar milhões é.
func _save_check(p: Dictionary, data: Dictionary, old: Dictionary) -> String:
	if bool(p.get("admin", false)):
		return ""
	if old.is_empty():   # herói novo: tem que começar do começo
		var legs := 0
		for it in data.get("inventory", []):
			legs += 1 if String(it.get("rarity", "")) == "lendaria" else 0
		if int(data.get("level", 1)) > 5 or int(data.get("gems", 0)) > GameData.GEMS_START + 300 or int(data.get("gold", 0)) > 50000 or legs > 16:
			return "herói novo já começou forte demais"
		return ""
	var hours := maxf((Time.get_unix_time_from_system() - float(p.get("save_t", Time.get_unix_time_from_system() - 60.0))) / 3600.0, 1.0 / 60.0)
	var lv0 := int(old.get("level", 1))
	var lv1 := int(data.get("level", 1))
	if lv1 > lv0 + maxi(20, int(hours * 30.0 * maxf(1.0, float(cfg["xp_mult"])))):
		return "nível subiu rápido demais"
	var gem_cap := 150 + 5 * maxi(0, lv1 - lv0) + int(hours * 400.0) + int(p.get("credit_gems", 0))
	if int(data.get("gems", 0)) - int(old.get("gems", 0)) > gem_cap:
		return "gemas a mais (%d)" % (int(data.get("gems", 0)) - int(old.get("gems", 0)))
	var gold_cap := 50000 + int(hours * 3600.0 * (200.0 + lv1 * 60.0) * maxf(1.0, float(cfg["gold_mult"]))) + int(p.get("credit_gold", 0))
	if int(data.get("gold", 0)) - int(old.get("gold", 0)) > gold_cap:
		return "ouro a mais"
	var leg0 := 0
	var leg1 := 0
	var ref0 := 0
	var ref1 := 0
	for it in old.get("inventory", []):
		leg0 += 1 if String(it.get("rarity", "")) == "lendaria" else 0
		ref0 += int(it.get("refine", 0))
	for it in data.get("inventory", []):
		leg1 += 1 if String(it.get("rarity", "")) == "lendaria" else 0
		ref1 += int(it.get("refine", 0))
	if leg1 - leg0 > 10 + int(hours * 2.0) + int(p.get("credit_items", 0)):   # loja (conjuntos) + drops raros
		return "itens lendários a mais"
	if (data.get("inventory", []) as Array).size() - (old.get("inventory", []) as Array).size() > 60 + int(hours * 120.0):
		return "itens a mais"
	if ref1 - ref0 > 30 + int(hours * 60.0):
		return "refino rápido demais"
	return ""


func _store(id: int) -> void:
	var p: Dictionary = _players.get(id, {})
	if p.is_empty() or (p["save"] as Dictionary).is_empty() or sb_service == "":
		return
	var d: Dictionary = p["save"]
	var top := {}
	for c in d.get("chars", []):
		if top.is_empty() or int(c.get("level", 1)) > int(top.get("level", 1)):
			top = c
	if top.is_empty():
		return
	var row := {"user_id": p["uid"], "data": d, "level": int(top.get("level", 1)), "class": String(top.get("name", top.get("class", ""))),
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
	_summon_boss(delay, String(_players[id]["name"]))


func _summon_boss(delay: float, by: String) -> void:
	delay = clampf(delay, 0.0, 3600.0)
	_boss_at = Time.get_unix_time_from_system() + delay
	_boss = {"key": "", "hp": 0, "max": 0, "hits": {}, "atk": {}, "base": 0, "dead": false}
	print("[servidor] boss global invocado por ", by, " para daqui a ", int(delay), " s")
	for pid in _players:
		_boss_call.rpc_id(int(pid), delay, int(GameData.GLOBAL_BOSS["minutes"]))


# ------------------------------------------------------------------ painel admin

## Configuração salva no banco (multiplicadores, mensagem do dia, manutenção).
func _config_load() -> void:
	if not _db():
		return
	var r := await _sb("/rest/v1/game_config?select=key,value", HTTPClient.METHOD_GET, null)
	if r["json"] is Array:
		for row in r["json"]:
			if cfg.has(String(row["key"])):
				cfg[String(row["key"])] = row["value"]
	_config_apply()


func _config_apply() -> void:
	GameData.XP_MULT = clampf(float(cfg["xp_mult"]), 0.1, 10.0)
	GameData.GOLD_MULT = clampf(float(cfg["gold_mult"]), 0.1, 10.0)
	GameData.DROP_MULT = clampf(float(cfg["drop_mult"]), 0.1, 10.0)


@rpc("authority", "reliable")
func _config(c: Dictionary) -> void:
	for k in c:
		cfg[k] = c[k]
	_config_apply()


func _admin_poll() -> void:
	_adm_busy = true
	var r := await _sb("/rest/v1/admin_commands?select=id,cmd,args&done=eq.false&order=id.asc&limit=20", HTTPClient.METHOD_GET, null)
	if r["json"] is Array:
		for row in r["json"]:
			var a: Variant = row.get("args", {})
			var res := await _admin_run(String(row["cmd"]), a if a is Dictionary else {})
			print("[admin] ", row["cmd"], " → ", res)
			await _sb("/rest/v1/admin_commands?id=eq.%d" % int(row["id"]), HTTPClient.METHOD_PATCH, {"done": true, "result": res})
	_adm_busy = false


## Jogador online pelo nome do herói ou da conta (sem maiúsculas). 0 se não estiver.
func _peer_by_name(nm: String) -> int:
	nm = nm.strip_edges().to_lower()
	for pid in _players:
		if String(_players[pid]["name"]).to_lower() == nm:
			return int(pid)
	return 0


## Dono (user_id) de um nome de herói: online ou pela tabela hero_names.
func _uid_by_name(nm: String) -> String:
	var pid := _peer_by_name(nm)
	if pid != 0:
		return String(_players[pid]["uid"])
	var r := await _sb("/rest/v1/hero_names?select=user_id&name_key=eq." + nm.strip_edges().to_lower().uri_encode(), HTTPClient.METHOD_GET, null)
	if r["json"] is Array and not (r["json"] as Array).is_empty():
		return String(r["json"][0]["user_id"])
	return ""


func _admin_run(cmd: String, a: Dictionary) -> String:
	match cmd:
		"anuncio":
			var text := String(a.get("text", "")).strip_edges().left(200)
			for pid in _players:
				_world_ev.rpc_id(int(pid), "anuncio", "", Vector3.ZERO, text)
			return "aviso enviado para %d jogadores" % _players.size()
		"boss":
			_summon_boss(float(a.get("minutes", 5)) * 60.0, "painel")
			return "boss global em %d min" % int(a.get("minutes", 5))
		"evento":
			_start_event("bau" if String(a.get("kind", "bau")) == "bau" else "invasao")
			return "evento começou"
		"dar":
			var nm := String(a.get("name", ""))
			var gems := clampi(int(a.get("gems", 0)), 0, 1000000)
			var gold := clampi(int(a.get("gold", 0)), 0, 1000000000)
			var items := clampi(int(a.get("items", 0)), 0, 10)
			var pid := _peer_by_name(nm)
			if pid != 0:
				var p: Dictionary = _players[pid]
				p["credit_gems"] = int(p.get("credit_gems", 0)) + gems
				p["credit_gold"] = int(p.get("credit_gold", 0)) + gold
				p["credit_items"] = int(p.get("credit_items", 0)) + items
				_world_ev.rpc_id(pid, "presente", "", Vector3.ZERO, JSON.stringify({"gems": gems, "gold": gold, "items": items, "rarity": String(a.get("rarity", "lendaria"))}))
				return "entregue para %s (online)" % nm
			if gems <= 0:
				return "%s está offline: offline só dá para mandar gemas" % nm
			var uid := await _uid_by_name(nm)
			if uid == "":
				return "herói %s não encontrado" % nm
			await _sb("/rest/v1/market_payouts", HTTPClient.METHOD_POST, {"user_id": uid, "gems": gems, "note": "Presente do administrador"})
			return "%d gemas guardadas para %s (entra no próximo login)" % [gems, nm]
		"expulsar":
			var pid := _peer_by_name(String(a.get("name", "")))
			if pid == 0:
				return "não está online"
			_world_ev.rpc_id(pid, "expulso", "", Vector3.ZERO, String(a.get("reason", "Você foi desconectado pelo administrador.")))
			Fx.later(self, 1.0).connect(func() -> void: multiplayer.multiplayer_peer.disconnect_peer(pid))
			return "expulso"
		"banir":
			var nm := String(a.get("name", ""))
			var uid := await _uid_by_name(nm)
			if uid == "":
				return "herói %s não encontrado" % nm
			await _sb("/rest/v1/bans", HTTPClient.METHOD_POST, {"user_id": uid, "name": nm.to_lower(), "reason": String(a.get("reason", ""))}, "", ["Prefer: resolution=merge-duplicates"])
			var pid := _peer_by_name(nm)
			if pid != 0:
				_world_ev.rpc_id(pid, "expulso", "", Vector3.ZERO, "Conta banida. " + String(a.get("reason", "")))
				Fx.later(self, 1.0).connect(func() -> void: multiplayer.multiplayer_peer.disconnect_peer(pid))
			return "%s banido" % nm
		"desbanir":
			await _sb("/rest/v1/bans?name=eq." + String(a.get("name", "")).strip_edges().to_lower().uri_encode(), HTTPClient.METHOD_DELETE, null)
			return "desbanido"
		"config":
			var rows: Array = []
			for k in a:
				if cfg.has(k):
					cfg[k] = a[k]
					rows.append({"key": k, "value": a[k]})
			_config_apply()
			if not rows.is_empty():
				await _sb("/rest/v1/game_config", HTTPClient.METHOD_POST, rows, "", ["Prefer: resolution=merge-duplicates"])
			for pid in _players:
				_config.rpc_id(int(pid), cfg)
			if bool(cfg["maintenance"]):   # manutenção: tira quem não é admin
				for pid in _players.keys():
					if not bool(_players[pid].get("admin", false)):
						_world_ev.rpc_id(int(pid), "expulso", "", Vector3.ZERO, "Servidor em manutenção. Volte daqui a pouco!")
						var kp := int(pid)
						Fx.later(self, 1.0).connect(func() -> void: multiplayer.multiplayer_peer.disconnect_peer(kp))
			return "configuração aplicada"
		"salvar":
			for pid in _players:
				_store(int(pid))
			return "saves gravados"
	return "comando desconhecido"


## Estado do servidor para o painel (a cada 10 s).
func _status_push() -> void:
	var list: Array = []
	var maps := {}
	for pid in _players:
		var p: Dictionary = _players[pid]
		var c := _cur_char(int(pid))
		var m := String(p.get("map", ""))
		maps[m] = int(maps.get(m, 0)) + 1
		list.append({"name": p["name"], "level": int(c.get("level", 1)), "cls": String(p.get("cls", "")),
			"map": String(GameData.MAPS[m]["name"]) if GameData.MAPS.has(m) else m, "guild": String(p.get("guild", "")), "admin": bool(p.get("admin", false))})
	var data := {"online": _players.size(), "players": list, "uptime": int(Time.get_unix_time_from_system() - _started),
		"boss_in": int(_boss_at - Time.get_unix_time_from_system()) if _boss_at > 0.0 else null, "cfg": cfg,
		"market": _market.size(), "guilds": _guilds.size(), "war": _war["points"], "crown": _war["crown"], "time": Time.get_datetime_string_from_system()}
	await _sb("/rest/v1/server_status", HTTPClient.METHOD_POST, {"id": 1, "data": data, "updated_at": Time.get_datetime_string_from_system(true) + "Z"}, "", ["Prefer: resolution=merge-duplicates"])


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
		guild_points(pid, int(_boss["hits"][pid]) / 1000)
		kingdom_points(pid, int(GameData.KINGDOM_WAR["boss"]) * 3)
		# o que o servidor deu entra na conta do próximo save (não conta como trapaça)
		var cfg2: Dictionary = GameData.GLOBAL_BOSS
		_players[pid]["credit_gems"] = int(_players[pid].get("credit_gems", 0)) + int(cfg2["reward_gems"]) + (int(cfg2["top_gems"][i]) if i < 3 else 0) + (int(cfg2["last_gems"]) if pid == last else 0)
		_players[pid]["credit_gold"] = int(_players[pid].get("credit_gold", 0)) + int(cfg2["reward_gold"]) * 2 + (int(cfg2["top_gold"][i]) if i < 3 else 0) + (int(cfg2["last_gold"]) if pid == last else 0)
		_players[pid]["credit_items"] = int(_players[pid].get("credit_items", 0)) + 2
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
		others[int(id)] = {"name": a[0], "cls": a[1], "gear": a[2], "pos": a[3], "rot": a[4], "moving": a[5], "mount": a[6], "guild": a[7] if a.size() > 7 else "", "kingdom": a[8] if a.size() > 8 else ""}


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
func _save_refused(why: String) -> void:
	push_warning("Servidor recusou o save: " + why)


@rpc("authority", "reliable")
func _boss_reward(rank: int, last_hit: bool, item: String) -> void:
	boss_reward.emit(rank, last_hit, item)


func send_state(map: String, p: Player) -> void:
	if not online:
		return
	state.rpc_id(1, map, p.global_position, p.rotation.y, p.velocity.length() > 0.5, p.class_key, p.visual_rarities(), p.mount if p.riding else "", p.alive, p.hero_name)


func send_save(data: Dictionary) -> void:
	if online:
		push_save.rpc_id(1, data, SaveGame.cur)
