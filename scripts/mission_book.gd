class_name MissionBook
extends RefCounted
## Missões repetíveis (diárias, semanais e mensais) com limites por período, usando a data real do computador.
## - Diárias: até 30 por dia (zera à meia-noite).
## - Semanais: até 150 por semana (zera na segunda-feira) — pode fazer todas no mesmo dia.
## - Mensais: até 900 por mês, liberadas 30 por dia (no dia 10 já dá para ter feito 300). Não dá para adiantar.

var done := {"diaria": 0, "semanal": 0, "mensal": 0}
var period := {"diaria": "", "semanal": "", "mensal": ""}
var active := {"diaria": {}, "semanal": {}, "mensal": {}}
var date_override := {}   # só para testes: {"year": 2026, "month": 10, "day": 28}


func today() -> Dictionary:
	var d: Dictionary
	if not date_override.is_empty():
		d = date_override.duplicate()
	else:
		d = Time.get_date_dict_from_system()
	var unix := Time.get_unix_time_from_datetime_dict({"year": int(d["year"]), "month": int(d["month"]), "day": int(d["day"]), "hour": 12, "minute": 0, "second": 0})
	var full := Time.get_datetime_dict_from_unix_time(unix)
	return {"year": int(full["year"]), "month": int(full["month"]), "day": int(full["day"]), "weekday": int(full["weekday"]), "unix": unix}


func _key(kind: String, d: Dictionary) -> String:
	match kind:
		"diaria":
			return "%04d-%02d-%02d" % [d["year"], d["month"], d["day"]]
		"semanal":
			var back := (int(d["weekday"]) + 6) % 7   # dias desde a segunda-feira
			var mon := Time.get_datetime_dict_from_unix_time(int(d["unix"]) - back * 86400)
			return "semana de %02d/%02d/%04d" % [mon["day"], mon["month"], mon["year"]]
		_:
			return "%04d-%02d" % [d["year"], d["month"]]


func refresh() -> void:
	var d := today()
	for kind in GameData.MISSION_KINDS:
		var k := _key(kind, d)
		if period[kind] != k:
			period[kind] = k
			done[kind] = 0
			active[kind] = {}


func limit_now(kind: String) -> int:
	refresh()
	var m: Dictionary = GameData.MISSION[kind]
	if kind == "mensal":
		return mini(int(m["limit"]), int(m["per_day"]) * int(today()["day"]))
	return int(m["limit"])


func remaining(kind: String) -> int:
	return maxi(0, limit_now(kind) - int(done[kind]))


func can_accept(kind: String) -> bool:
	return (active[kind] as Dictionary).is_empty() and remaining(kind) > 0


func accept(kind: String, player_level: int, map_id: String) -> Dictionary:
	if not can_accept(kind):
		return {}
	var zid := pick_zone(player_level, map_id)
	var z: Dictionary = GameData.ZONES[zid]
	var m: Dictionary = GameData.MISSION[kind]
	var enemy_id := String(z["enemy"])
	var en := GameData.enemy(enemy_id)
	var kills := int(m["kills"])
	var gold_v: Vector2i = en["gold"]
	var mis := {
		"kind": kind, "zone": zid, "enemy": enemy_id, "need": kills, "have": 0,
		"xp": int(GameData.xp_need(player_level) * float(m["xp_frac"])),
		"gold": int(gold_v.y * kills * float(m["gold"])),
	}
	active[kind] = mis
	return mis


## Zona mais alta do mapa que o herói já alcança (ou a primeira, se ainda estiver abaixo de todas).
func pick_zone(level: int, map_id: String) -> String:
	var zones: Array = GameData.MAPS[map_id]["zones"]
	var best := String(zones[0])
	for zid in zones:
		var lv: Vector2i = GameData.ZONES[zid]["lvl"]
		if level >= lv.x:
			best = String(zid)
	return best


## Conta a morte de um monstro. Devolve os tipos de missão que ficaram completas.
func on_kill(enemy_id: String, zone_id: String) -> Array[String]:
	var out: Array[String] = []
	for kind in GameData.MISSION_KINDS:
		var mis: Dictionary = active[kind]
		if mis.is_empty():
			continue
		if String(mis["enemy"]) == enemy_id and String(mis["zone"]) == zone_id and int(mis["have"]) < int(mis["need"]):
			mis["have"] = int(mis["have"]) + 1
			if int(mis["have"]) >= int(mis["need"]):
				out.append(kind)
	return out


func complete(kind: String) -> Dictionary:
	var mis: Dictionary = active[kind]
	if mis.is_empty():
		return {}
	done[kind] = int(done[kind]) + 1
	active[kind] = {}
	return mis


func to_dict() -> Dictionary:
	return {"done": done, "period": period, "active": active}


func from_dict(d: Dictionary) -> void:
	for kind in GameData.MISSION_KINDS:
		done[kind] = int((d.get("done", {}) as Dictionary).get(kind, 0))
		period[kind] = String((d.get("period", {}) as Dictionary).get(kind, ""))
		active[kind] = (d.get("active", {}) as Dictionary).get(kind, {})
	refresh()
