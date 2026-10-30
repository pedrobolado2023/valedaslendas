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
	_market_load()
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
	_players[id] = {"uid": uid, "name": mail.get_slice("@", 0), "cls": "", "gear": {}, "save": save,
		"admin": meta is Dictionary and bool(meta.get("admin", false))}
	print("[servidor] entrou: ", mail, " (", _players.size(), " online)")
	_players[id]["save_t"] = Time.get_unix_time_from_system()
	_welcome.rpc_id(id, true, save)
	_market_payouts(id)
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
	if not alive and int(p.get("duel", 0)) != 0:   # caiu no duelo
		pvp_dead_srv(id)


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
	if lv1 > lv0 + maxi(20, int(hours * 30.0)):
		return "nível subiu rápido demais"
	var gem_cap := 150 + 5 * maxi(0, lv1 - lv0) + int(hours * 400.0) + int(p.get("credit_gems", 0))
	if int(data.get("gems", 0)) - int(old.get("gems", 0)) > gem_cap:
		return "gemas a mais (%d)" % (int(data.get("gems", 0)) - int(old.get("gems", 0)))
	var gold_cap := 50000 + int(hours * 3600.0 * (200.0 + lv1 * 60.0)) + int(p.get("credit_gold", 0))
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
