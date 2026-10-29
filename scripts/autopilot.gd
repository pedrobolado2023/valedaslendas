class_name Autopilot
extends Node
## Modo automático, para quem tem pouco tempo:
## - "Missão automática": anda pela trilha até a missão, luta sozinho, enfrenta o chefe e volta ao NPC para entregar.
## - "Auto-combate": luta sozinho com quem estiver por perto (sem sair andando).
## Mexer o herói com WASD pausa a missão automática.

signal changed

var game: Node
var player: Player
var world: World
var questing := false
var auto_combat := false

var _route := PackedVector3Array()
var _wp := 0
var _goal := Vector3(INF, 0, INF)
var _route_t := 0.0
var _stuck_t := 0.0
var _last_pos := Vector3.ZERO
var _think := 0.0


func start_quest() -> void:
	questing = true
	_goal = Vector3(INF, 0, INF)
	changed.emit()


func stop_quest() -> void:
	if questing:
		questing = false
		if player != null:
			player.auto_dir = Vector3.ZERO
		changed.emit()


func set_auto_combat(on: bool) -> void:
	auto_combat = on
	changed.emit()


func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	player.auto_dir = Vector3.ZERO
	if not player.alive or bool(game.get("_traveling")):
		return
	world = game.get("world")
	if questing and player.manual_input:
		stop_quest()
		game.call("toast", "Missão automática pausada (você assumiu o controle)", 2.0)
		return
	if not (questing or auto_combat):
		return
	var target := _pick_target()
	if target != null:
		_fight(target)
		return
	if questing:
		var goal: Dictionary = game.call("quest_goal")
		if goal.is_empty():
			stop_quest()
			return
		var pos: Vector3 = goal["pos"]
		if _walk_to(pos, delta, float(goal.get("near", 2.0))):
			game.call("auto_arrived", String(goal["kind"]))


func _pick_target() -> Enemy:
	var r := 13.0 if questing else 10.0
	var best: Enemy = null
	var bd := r
	for e in Skills.enemies(get_tree()):
		var d := Skills.flat(e.global_position - player.global_position).length()
		if e.aggro:
			d -= 4.0
		if d < bd:
			bd = d
			best = e
	return best


func _fight(t: Enemy) -> void:
	var to := Skills.flat(t.global_position - player.global_position)
	var d := to.length()
	var want := player.preferred_range() + t.radius * 0.5
	if d > want:
		player.auto_dir = to / d
		return
	player.face_dir(to)
	_think -= get_physics_process_delta_time()
	if _think > 0.0:
		return
	_think = 0.12
	for i in [5, 4, 3, 2, 1, 0]:
		if player.skill_ready(i) and _useful(i, t, d):
			if player.cast_skill(i, t.global_position):
				return
	if player.basic_ready():
		player.basic_attack(t.global_position)


func _useful(i: int, t: Enemy, d: float) -> bool:
	var sk := player.skill(i)
	match String(sk["type"]):
		"roll":
			return player.hp < player.max_hp * 0.35
		"shield", "guard", "dodge":
			return player.hp < player.max_hp * 0.8 or t.boss
		"heal_zone", "repair_drone":
			return player.hp < player.max_hp * 0.7
		"spin_multi", "colossus", "maelstrom", "awaken":
			return d <= float(sk.get("r", 4.0)) + t.radius
		"stealth":
			return player.hp < player.max_hp * 0.5
		"buff":
			return true
		"spin", "slam", "nova", "pull":
			return d <= float(sk.get("r", 4.0)) + t.radius
		"cone":
			return d <= float(sk.get("r", 6.0))
		"dash":
			return d <= float(sk.get("dist", 8.0))
	return true


## Anda pela rota até o ponto. Retorna true quando chegou.
func _walk_to(goal: Vector3, delta: float, near: float) -> bool:
	var pos := player.global_position
	if Skills.flat(goal - pos).length() <= near:
		_route = PackedVector3Array()
		return true
	_route_t -= delta
	if Skills.flat(goal - _goal).length() > 2.0 or _route_t <= 0.0 or _route.is_empty():
		_goal = goal
		_route = world.route(pos, goal)
		_wp = 1
		_route_t = 3.0
	while _wp < _route.size() and Skills.flat(_route[_wp] - pos).length() < 1.8:
		_wp += 1
	var target := goal if _wp >= _route.size() else _route[_wp]
	var dir := Skills.flat(target - pos)
	if dir.length() > 0.01:
		player.auto_dir = dir.normalized()
	# destravar se ficar preso em algo
	_stuck_t += delta
	if _stuck_t > 1.0:
		if pos.distance_to(_last_pos) < 0.6:
			_wp = mini(_wp + 1, _route.size())
			player.auto_dir = player.auto_dir.rotated(Vector3.UP, randf_range(-1.2, 1.2))
		_last_pos = pos
		_stuck_t = 0.0
	return false


func current_route() -> PackedVector3Array:
	return _route
