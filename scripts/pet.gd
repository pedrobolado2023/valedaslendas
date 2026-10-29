class_name Pet
extends Node3D
## Mascote ativo: segue o herói (top_level, anda sozinho) e usa a função dele a cada `cd` segundos.
## Funções (campo "func" do item em GameData.SHOP): attack (raio mágico), bite (mordida corpo a corpo),
## fire (explosão de fogo em área), heal (cura), shield (escudo), loot (puxa os drops de longe).
## Fica mais forte com o nível do pet (Player.pet_levels), que sobe com as mortes.

var player: Player
var data: Dictionary
var _kit: ModelKit
var _cd := 1.0
var _t := 0.0
var _side := 1.0


func setup(p: Player, it: Dictionary) -> void:
	player = p
	data = it
	top_level = true
	_kit = ModelKit.load_kit(String(it.get("model", "pet_owl")), 0.02, 0.0)
	if _kit != null:
		_kit.root.scale = Vector3.ONE * float(it.get("scale", 0.7))
		if it.has("tint"):
			_kit.set_tint(it["tint"], 0.45)
		add_child(_kit.root)
		_kit.play("idle")
	var l := OmniLight3D.new()
	l.light_color = it.get("color", Color(0.8, 0.55, 1.0))
	l.light_energy = 1.0
	l.omni_range = 3.0
	l.position.y = 0.5
	add_child(l)


func _ready() -> void:
	if player != null:
		global_position = player.global_position + Vector3(1.2, 0, 0)


## Força do pet: 1,0 no nível 1, +4% por nível.
func power() -> float:
	return 1.0 + 0.04 * (player.pet_level() - 1)


func _flying() -> bool:
	return bool(data.get("fly", true))


func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	_t += delta
	var back := -player.facing.normalized() if player.facing.length() > 0.1 else Vector3.BACK
	var side := back.cross(Vector3.UP).normalized() * _side
	var goal := player.global_position + back * 1.1 + side * 1.0
	goal.y = player.global_position.y + (1.9 + sin(_t * 2.2) * 0.25 if _flying() else 0.0)
	var to := goal - global_position
	global_position += to * minf(1.0, delta * 4.0)
	var flat := Vector3(to.x, 0, to.z)
	if flat.length() > 0.05:
		rotation.y = lerp_angle(rotation.y, atan2(flat.x, flat.z), delta * 6.0)
	if _kit != null:
		_kit.play("walk" if flat.length() > 0.6 and not _flying() else "idle")
	if not player.alive:
		return
	_cd -= delta
	if _cd <= 0.0:
		_cd = float(data.get("cd", 3.0))
		if not _act():
			_cd = 0.5


func _nearest(r: float) -> Enemy:
	var best: Enemy = null
	var bd := r
	for n in get_tree().get_nodes_in_group("enemy"):
		var e := n as Enemy
		if e == null:
			continue
		var d := e.global_position.distance_to(player.global_position)
		if d < bd:
			bd = d
			best = e
	return best


func _act() -> bool:
	var host := player.get_parent()
	var col: Color = data.get("color", Color.WHITE)
	var dmg := int(player.atk * float(data.get("dmg", 0.3)) * power())
	match String(data.get("func", "attack")):
		"attack":
			var e := _nearest(14.0)
			if e == null:
				return false
			Vfx.bolt(host, global_position, e.global_position + Vector3(0, 1.0, 0), col, 0.25, 0.25, 1)
			e.take_damage(dmg, global_position)
			Sfx.play("sk_bolt", -12.0, 1.4)
		"bite":
			var e := _nearest(9.0)
			if e == null:
				return false
			global_position = e.global_position + (global_position - e.global_position).normalized() * 1.0
			Fx.burst(host, e.global_position + Vector3(0, 0.8, 0), col, 12, 4.0, 0.08, 0.4)
			e.take_damage(dmg, global_position)
			Sfx.play("hit", -10.0, 1.3)
		"fire":
			var e := _nearest(12.0)
			if e == null:
				return false
			var at := e.global_position
			Fx.burst(host, at + Vector3(0, 0.5, 0), col, 30, 6.0, 0.14, 0.7, 2.0)
			for n in get_tree().get_nodes_in_group("enemy"):
				if (n as Enemy) != null and (n as Enemy).global_position.distance_to(at) < 3.5:
					(n as Enemy).take_damage(dmg, at)
			Sfx.play("sk_fire", -10.0, 1.2)
		"heal":
			if player.hp >= player.max_hp * 0.9:
				return false
			var h := player.max_hp * float(data.get("heal", 0.05)) * power()
			player.hp = minf(player.max_hp, player.hp + h)
			Fx.burst(host, player.global_position + Vector3(0, 1.2, 0), col, 20, 3.0, 0.1, 0.8, -2.0)
			Fx.damage_number(host, player.global_position + Vector3(0, 2.8, 0), "+%d" % int(h), Color(0.4, 1.0, 0.5))
			player.stats_changed.emit()
		"shield":
			if _nearest(12.0) == null or player.shield > 0.0:
				return false
			player.shield = player.max_hp * float(data.get("heal", 0.08)) * power()
			Fx.burst(host, player.global_position + Vector3(0, 1.2, 0), col, 24, 3.5, 0.12, 0.8, 0.0)
			player.stats_changed.emit()
		"loot":
			var any := false
			for n in get_tree().get_nodes_in_group("loot"):
				var l := n as Node3D
				if l != null and l.global_position.distance_to(player.global_position) < 18.0:
					l.global_position = player.global_position + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
					any = true
			return any
	return true
