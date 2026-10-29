class_name Zone
extends Node3D
## Área de caça: mantém uma quantidade de monstros e faz renascer os que morrem.

signal killed(enemy: Enemy)

var zone_id := ""
var data: Dictionary = {}
var enemy_root: Node3D
var world: World
var _alive: Array[Enemy] = []
var boss: Enemy


func setup(id: String, root: Node3D, w: World) -> void:
	zone_id = id
	data = GameData.ZONES[id]
	enemy_root = root
	world = w


func _ready() -> void:
	for i in int(data["count"]):
		spawn_one()


func center() -> Vector3:
	return data["center"]


func spawn_one() -> void:
	var c: Vector3 = data["center"]
	var r := float(data["radius"])
	var pos := c
	for tries in 12:
		var a := randf() * TAU
		var d := sqrt(randf()) * r
		pos = c + Vector3(cos(a) * d, 0.2, sin(a) * d)
		if world == null or (world.road_dist(Vector2(pos.x, pos.z)) > 1.5 and not world._in_lake(Vector2(pos.x, pos.z), 1.0)):
			break
	var e := Enemy.new()
	e.setup(String(data["enemy"]), pos, zone_id)
	e.died.connect(_on_died)
	enemy_root.add_child(e)
	_alive.append(e)


func spawn_boss(type_id: String) -> Enemy:
	if boss != null and is_instance_valid(boss) and boss.alive:
		return boss
	var e := Enemy.new()
	e.setup(type_id, data["boss_pos"] + Vector3(0, 0.3, 0), zone_id)
	e.died.connect(_on_died)
	enemy_root.add_child(e)
	boss = e
	return e


func alive_enemies() -> Array[Enemy]:
	var out: Array[Enemy] = []
	for e in _alive:
		if is_instance_valid(e) and e.alive:
			out.append(e)
	return out


func _on_died(e: Enemy) -> void:
	_alive.erase(e)
	killed.emit(e)
	if e == boss:
		boss = null
		return
	get_tree().create_timer(7.0).timeout.connect(func() -> void:
		if is_inside_tree() and _alive.size() < int(data["count"]):
			spawn_one())
