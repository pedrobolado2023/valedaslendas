class_name Loot
extends Node3D
## Item no chão. Moedas são puxadas pelo herói (ímã); itens raros têm feixe de luz.

signal picked(loot: Loot)

var kind := "gold"   # gold | crystal | legend | item
var item: Dictionary = {}
var value := 0
var title := ""
var _core: Node3D
var _t := 0.0
var _age := 0.0
var _vel := Vector3.ZERO


func _ready() -> void:
	add_to_group("loot")
	_core = Node3D.new()
	_core.position.y = 0.6
	add_child(_core)
	_vel = Vector3(randf_range(-2, 2), 5.0, randf_range(-2, 2))
	var col := Color(1.0, 0.82, 0.3)
	if kind == "gold":
		for i in 3:
			var c := Toon.part(Toon.cyl(0.22, 0.22, 0.07, 16), Color(1.0, 0.8, 0.25), Vector3(randf_range(-0.12, 0.12), i * 0.08, randf_range(-0.12, 0.12)), 0.015)
			_core.add_child(c)
	elif kind == "item":
		col = GameData.RARITY[item["rarity"]]["color"]
		if String(item["slot"]) == "weapon":
			var wk := ModelKit.load_kit("weapon_%s_%s" % [item["cls"], item["rarity"]], 0.02)
			if wk != null:
				wk.root.rotation_degrees = Vector3(90, 0, 35)
				wk.root.scale = Vector3.ONE * 0.75
				wk.root.position.y = 0.4
				_core.add_child(wk.root)
		else:
			_core.add_child(Toon.part(Toon.box(Vector3(0.9, 0.6, 0.6)), Color(0.4, 0.26, 0.14), Vector3(0, 0.1, 0), 0.03))
			_core.add_child(Toon.part(Toon.box(Vector3(0.95, 0.12, 0.65)), col, Vector3(0, 0.42, 0), 0.02))
			_core.add_child(Toon.glow_part(Toon.box(Vector3(0.2, 0.2, 0.05)), col, Vector3(0, 0.15, 0.31)))
	else:
		col = Color(0.75, 0.5, 1.0) if kind == "crystal" else Color(1.0, 0.6, 0.25)
		var kit := ModelKit.load_kit("loot_crystal" if kind == "crystal" else "loot_sword", 0.02)
		if kit != null:
			kit.root.scale = Vector3.ONE * (1.4 if kind == "legend" else 1.0)
			_core.add_child(kit.root)
	if kind != "gold":
		var beam := Toon.glow_part(Toon.cyl(0.08, 0.08, 6.0, 8), col, Vector3(0, 3.0, 0), 0.4, true)
		add_child(beam)
		var l := OmniLight3D.new()
		l.light_color = col
		l.light_energy = 2.0
		l.omni_range = 5.0
		l.position.y = 1.0
		add_child(l)


func _process(delta: float) -> void:
	_t += delta
	_age += delta
	if _vel != Vector3.ZERO:
		_vel.y -= 18.0 * delta
		position += _vel * delta
		if position.y <= 0.0:
			position.y = 0.0
			_vel = Vector3.ZERO
	_core.position.y = 0.6 + sin(_t * 3.0) * 0.1
	_core.rotation.y += delta * 2.5
	if _age < 0.5:
		return
	var p := get_tree().get_first_node_in_group("player") as Player
	if p == null or not p.alive:
		return
	var to := p.global_position - global_position
	to.y = 0.0
	var d := to.length()
	if d < 4.5:
		global_position += to.normalized() * minf(d, (16.0 - d * 2.0) * delta)
	if d < 0.9:
		set_process(false)
		picked.emit(self)
		queue_free()
