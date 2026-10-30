class_name ServerWorld
extends Node
## Monstros no servidor (só roda no servidor, criado pelo Net). Para cada mapa com jogadores: mantém os monstros
## das zonas (quantidade, reaparecer em 7 s), escolhe o alvo (jogador mais perto), anda, ataca (manda o dano só
## para o jogador atingido), volta para casa se for longe demais. Recebe os golpes dos jogadores; quando o monstro
## morre, dá XP/ouro a quem bateu e sorteia o drop para quem mais bateu. Mapas de evento (covil, masmorra) ficam
## de fora: o boss global tem a vida no Net e a masmorra é individual.
## Tudo em dados (sem física): posições no plano XZ.

const TICK := 0.1

var net: Node
var maps: Dictionary = {}       # map -> {"enemies": {id: e}, "respawn": [[t, zone]], "boss_req": {}}
var _next_id := 1
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	if _t < TICK:
		return
	var dt := _t
	_t = 0.0
	var active := {}
	for pid in net._players:
		var m: Variant = net._players[pid].get("map", null)
		if m != null and GameData.MAPS.has(m) and not bool(GameData.MAPS[m].get("event", false)):
			active[m] = true
	for m in active:
		if not maps.has(m):
			_open(String(m))
	for m in maps.keys():
		if not active.has(m):
			maps.erase(m)   # ninguém no mapa: esquece (abre de novo cheio quando alguém voltar)
			continue
		_tick_map(String(m), dt)


func _open(m: String) -> void:
	maps[m] = {"enemies": {}, "respawn": []}
	for zid in GameData.MAPS[m]["zones"]:
		var z: Dictionary = GameData.ZONES[zid]
		for i in int(z["count"]):
			_spawn(m, String(zid), String(z["enemy"]), false)
		if m.begins_with("m") and z.has("boss"):   # mapas gerados: chefe da zona sempre presente
			_spawn(m, String(zid), String(z["boss"]), true)


func _spawn(m: String, zid: String, type_id: String, is_boss: bool) -> Dictionary:
	var z: Dictionary = GameData.ZONES[zid]
	var d: Dictionary = GameData.enemy(type_id)
	var pos: Vector3 = z["center"]
	if is_boss:
		pos = z["boss_pos"]
	else:
		var a := randf() * TAU
		pos += Vector3(cos(a), 0, sin(a)) * sqrt(randf()) * float(z["radius"])
	var e := {"id": _next_id, "type": type_id, "zone": zid, "pos": pos, "home": pos, "hp": int(d["hp"]), "max": int(d["hp"]),
		"boss": is_boss or bool(d.get("boss", false)), "target": 0, "cd": randf_range(0.5, 1.5), "busy": 0.0,
		"moving": false, "face": 0.0, "wander": Vector3.ZERO, "wt": 0.0, "back": false, "hits": {}}
	_next_id += 1
	maps[m]["enemies"][e["id"]] = e
	return e


func _tick_map(m: String, dt: float) -> void:
	var md: Dictionary = maps[m]
	var players := {}
	for pid in net._players:
		var p: Dictionary = net._players[pid]
		if String(p.get("map", "")) == m and bool(p.get("alive", true)) and p.has("pos"):
			players[pid] = p
	# reaparecer
	var keep: Array = []
	for r in md["respawn"]:
		r[0] -= dt
		if r[0] <= 0.0:
			var zr: Dictionary = GameData.ZONES[r[1]]
			var is_b: bool = r.size() > 2 and bool(r[2])
			_spawn(m, String(r[1]), String(zr["boss"] if is_b else zr["enemy"]), is_b)
		else:
			keep.append(r)
	md["respawn"] = keep
	var snap := {}
	for id in md["enemies"]:
		var e: Dictionary = md["enemies"][id]
		_ai(m, e, players, dt)
		snap[id] = [e["type"], e["zone"], e["pos"], e["hp"], e["max"], e["moving"], e["face"], e["boss"]]
	for pid in players:
		net._enemies.rpc_id(int(pid), m, snap)


## Lentidão e atordoamento vindos das skills dos jogadores.
func effect(m: String, id: int, kind: String, amount: float, t: float) -> void:
	if not maps.has(m) or not maps[m]["enemies"].has(id):
		return
	var e: Dictionary = maps[m]["enemies"][id]
	if kind == "stun":
		e["stun"] = maxf(float(e.get("stun", 0.0)), t * (0.35 if e["boss"] else 1.0))
	elif kind == "slow":
		e["slow"] = maxf(float(e.get("slow", 0.0)), amount)
		e["slow_t"] = maxf(float(e.get("slow_t", 0.0)), t)


func _ai(m: String, e: Dictionary, players: Dictionary, dt: float) -> void:
	var d: Dictionary = GameData.enemy(String(e["type"]))
	e["stun"] = float(e.get("stun", 0.0)) - dt
	e["slow_t"] = float(e.get("slow_t", 0.0)) - dt
	if float(e["slow_t"]) <= 0.0:
		e["slow"] = 0.0
	if float(e["stun"]) > 0.0:   # atordoado: não anda nem ataca
		e["moving"] = false
		return
	e["cd"] = float(e["cd"]) - dt
	e["busy"] = float(e["busy"]) - dt
	e["moving"] = false
	var pos: Vector3 = e["pos"]
	var spd := float(d["speed"]) * (1.0 - float(e.get("slow", 0.0)))
	# alvo: jogador mais perto dentro do raio de ataque (ou o que já estava perseguindo)
	var aggro_r := float(d.get("aggro_r", 15.0 if e["boss"] else 8.5))
	var leash := float(d.get("leash", 34.0 if e["boss"] else 24.0))
	var tgt: Dictionary = players.get(e["target"], {})
	if tgt.is_empty():
		e["target"] = 0
		var best := aggro_r
		for pid in players:
			var dd := _flat(players[pid]["pos"] - pos).length()
			if dd < best:
				best = dd
				e["target"] = pid
		tgt = players.get(e["target"], {})
	if bool(e["back"]):
		var back := _flat(e["home"] - pos)
		if back.length() < 1.5:
			e["back"] = false
		else:
			_move(e, back.normalized() * spd * 1.6, dt)
		return
	if tgt.is_empty():
		e["wt"] = float(e["wt"]) - dt
		if float(e["wt"]) <= 0.0:
			e["wt"] = randf_range(1.5, 4.0)
			e["wander"] = Vector3.ZERO if randf() < 0.4 else _flat(e["home"] + Vector3(randf_range(-6, 6), 0, randf_range(-6, 6)) - pos)
		var w: Vector3 = e["wander"]
		if w.length() > 0.5:
			var step := w.normalized() * spd * 0.4
			_move(e, step, dt)
			e["wander"] = w - step * dt
		return
	if _flat(pos - e["home"]).length() > leash:
		e["target"] = 0
		e["back"] = true
		e["hp"] = e["max"]
		e["hits"] = {}
		return
	var to := _flat(tgt["pos"] - pos)
	var dist := to.length()
	var reach := float(d["range"])
	if float(e["busy"]) > 0.0:
		return
	e["face"] = atan2(-to.x, -to.z)
	if dist > reach * 0.85:
		_move(e, to / maxf(dist, 0.01) * spd, dt)
	elif float(e["cd"]) <= 0.0:
		_attack(m, e, d, players)


func _move(e: Dictionary, v: Vector3, dt: float) -> void:
	e["pos"] = (e["pos"] as Vector3) + v * dt
	e["moving"] = v.length() > 0.2
	if v.length() > 0.1:
		e["face"] = atan2(-v.x, -v.z)


func _attack(m: String, e: Dictionary, d: Dictionary, players: Dictionary) -> void:
	e["cd"] = float(d["atk_cd"]) * randf_range(0.9, 1.15)
	var slam := String(d["style"]) == "slam"
	var wind := 0.95 if slam else 0.32
	e["busy"] = wind + (0.35 if slam else 0.3)
	var center: Vector3 = e["pos"]
	var r := float(d.get("slam_r", 0.0))
	for pid in players:
		net._enemy_attack.rpc_id(int(pid), int(e["id"]), slam, center, r, wind)
	var dmg := int(d["dmg"])
	var target := int(e["target"])
	Fx.later(self, wind).connect(func() -> void:
		if not maps.has(m) or not maps[m]["enemies"].has(e["id"]):
			return
		for pid in net._players:
			var p: Dictionary = net._players[pid]
			if String(p.get("map", "")) != m or not p.has("pos"):
				continue
			var hit := false
			if slam:
				hit = _flat(p["pos"] - center).length() <= r
			else:
				hit = int(pid) == target and _flat(p["pos"] - (e["pos"] as Vector3)).length() <= float(d["range"]) + 0.6
			if hit:
				net._hurt.rpc_id(int(pid), dmg, int(e["id"])))


## Golpe de um jogador. Trava: no máximo a vida cheia do monstro por golpe.
func hit(pid: int, m: String, id: int, dmg: int) -> void:
	if not maps.has(m) or not maps[m]["enemies"].has(id):
		return
	var e: Dictionary = maps[m]["enemies"][id]
	dmg = clampi(dmg, 0, int(e["max"]))
	e["hp"] = int(e["hp"]) - dmg
	e["hits"][pid] = int(e["hits"].get(pid, 0)) + dmg
	if int(e["target"]) == 0:
		e["target"] = pid
	if int(e["hp"]) <= 0:
		_kill(m, e)


func _kill(m: String, e: Dictionary) -> void:
	maps[m]["enemies"].erase(e["id"])
	var table := "boss" if e["boss"] else "mob"
	var top := 0
	var best := -1
	for pid in e["hits"]:
		if int(e["hits"][pid]) > best:
			best = int(e["hits"][pid])
			top = int(pid)
	var drop := GameData.roll_rarity(table) if randf() < float(GameData.DROP_CHANCE[table]) else ""
	for pid in net._players:
		if String(net._players[pid].get("map", "")) == m:
			var credit: bool = e["hits"].has(pid)
			if not credit:   # grupo: quem está no mesmo mapa ganha junto se alguém do grupo bateu
				for mate in net.party_of(int(pid)):
					if e["hits"].has(mate):
						credit = true
			net._enemy_dead.rpc_id(int(pid), int(e["id"]), credit, drop if int(pid) == top else "")
			if e["hits"].has(pid):
				net.guild_points(int(pid), 5 if e["boss"] else 1)
	if not e["boss"]:
		maps[m]["respawn"].append([7.0, e["zone"]])
	elif m.begins_with("m") and String(e["type"]) == String(GameData.ZONES[e["zone"]].get("boss", "")):
		maps[m]["respawn"].append([180.0, e["zone"], true])


## Chefe de missão: nasce uma vez por zona (se já existir, nada).
func spawn_boss(m: String, zid: String, type_id: String) -> void:
	if not maps.has(m) or not GameData.ZONES.has(zid):
		return
	for id in maps[m]["enemies"]:
		if String(maps[m]["enemies"][id]["type"]) == type_id:
			return
	_spawn(m, zid, type_id, true)


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0, v.z)
