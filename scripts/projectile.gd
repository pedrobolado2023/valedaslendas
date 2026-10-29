class_name Projectile
extends Node3D
## Projéteis: flecha, flecha carregada, lança, bola de fogo, lança de gelo, orbe mágico e flechas do falcão.
## Podem atravessar (pierce), explodir em área, deixar lento ou perseguir (homing).

var player: Player
var dir := Vector3.FORWARD
var speed := 22.0
var life := 1.0
var mult := 1.0
var pierce := false
var explode_r := 0.0
var slow := 0.0
var slow_dur := 0.0
var homing := false
var visual := "arrow"
var color := Color.WHITE
var extra := {}   # efeitos extras do acerto (empurrão, quebra de defesa...)
var _hit := {}
var _done := false
var _target: Enemy
var _delay := 0.0


func _ready() -> void:
	match visual:
		"bolt", "bolt_big", "drone":
			var big := visual == "bolt_big"
			if visual == "drone":
				add_child(Toon.part(Toon.box(Vector3(0.5, 0.14, 0.5)), Color(0.3, 0.32, 0.36), Vector3.ZERO, 0.02))
				for k in 4:
					var a := TAU * k / 4.0 + PI / 4.0
					add_child(Toon.glow_part(Toon.cyl(0.14, 0.14, 0.03, 10), color, Vector3(cos(a) * 0.32, 0.1, sin(a) * 0.32), 0.8, true))
			else:
				var b := Toon.glow_part(Toon.sphere(0.32 if big else 0.14, 10), color, Vector3.ZERO, 0.9, true)
				b.scale = Vector3(1, 1, 2.6)
				add_child(b)
				add_child(Toon.glow_part(Toon.sphere(0.12 if big else 0.06, 8), Color(1, 1, 1)))
			_light(color, 1.6)
			_trail(color, 0.12 if big else 0.06)
		"wind":
			for k in 3:
				var w := Toon.glow_part(Toon.cyl(0.9 - k * 0.2, 0.9 - k * 0.2, 0.08, 18), color, Vector3(0, 0, -k * 0.45), 0.25 - k * 0.06, true)
				w.rotation_degrees.x = 90.0
				add_child(w)
			_light(color, 0.8)
			_wind_fx.call_deferred()
		"dagger":
			add_child(Toon.part(Toon.box(Vector3(0.12, 0.03, 0.6)), Color(0.85, 0.88, 0.95), Vector3(0, 0, -0.1), 0.01))
			add_child(Toon.part(Toon.box(Vector3(0.3, 0.05, 0.06)), Color(0.3, 0.2, 0.35), Vector3(0, 0, 0.22), 0.0))
			_trail(color, 0.06)
		"fireball", "orb":
			var c := color
			add_child(Toon.glow_part(Toon.sphere(0.42 if visual == "fireball" else 0.3, 12), c, Vector3.ZERO, 0.85, true))
			add_child(Toon.glow_part(Toon.sphere(0.2, 10), Color(1, 0.95, 0.8)))
			_light(c, 2.5)
			_trail(c, 0.16)
		"ice":
			var ice := Toon.glow_part(Toon.sphere(0.25, 8), Color(0.7, 0.95, 1.0))
			ice.scale = Vector3(1, 1, 3.2)
			add_child(ice)
			_light(Color(0.5, 0.85, 1.0), 2.0)
			_trail(Color(0.6, 0.9, 1.0), 0.1)
		"spear":
			add_child(Toon.part(Toon.box(Vector3(0.09, 0.09, 3.0)), Color(0.45, 0.3, 0.17), Vector3.ZERO, 0.02))
			var tip := Toon.part(Toon.cyl(0.0, 0.16, 0.6, 8), Color(0.9, 0.95, 1.0), Vector3(0, 0, -1.7), 0.02)
			tip.rotation_degrees.x = -90.0
			add_child(tip)
			_trail(Color(0.8, 0.95, 1.0), 0.08)
		_:
			var big := visual == "bigarrow"
			var gold := visual == "falcon"
			var shaft_c := Color(1.0, 0.85, 0.35) if gold else Color(0.5, 0.35, 0.2)
			add_child(Toon.part(Toon.box(Vector3(0.06, 0.06, 1.1 if big else 0.9) * (1.6 if big else 1.0)), shaft_c, Vector3.ZERO, 0.0))
			add_child(Toon.glow_part(Toon.box(Vector3(0.14, 0.14, 0.24) * (1.6 if big else 1.0)), Color(1, 1, 0.9) if not gold else Color(1, 0.9, 0.4), Vector3(0, 0, -0.55 * (1.5 if big else 1.0))))
			if big or gold:
				_trail(color, 0.08)
	rotation.y = atan2(-dir.x, -dir.z)


## Rastro de vento (precisa da posição final, por isso roda depois de entrar na cena).
func _wind_fx() -> void:
	Vfx.wind_trail(self, color)


func _light(c: Color, e: float) -> void:
	var l := OmniLight3D.new()
	l.light_color = c
	l.light_energy = e
	l.omni_range = 5.0
	add_child(l)


func _trail(c: Color, size: float) -> void:
	var p := CPUParticles3D.new()
	p.amount = 24
	p.lifetime = 0.3
	p.local_coords = false
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 0.2
	p.initial_velocity_max = 0.8
	p.gravity = Vector3.ZERO
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	var sm := SphereMesh.new()
	sm.radius = size
	sm.height = size * 2
	sm.radial_segments = 6
	sm.rings = 3
	sm.material = Toon.glow_mat(c, 0.9, true)
	p.mesh = sm
	add_child(p)


func _physics_process(delta: float) -> void:
	if _done:
		return
	if _delay > 0.0:
		_delay -= delta
		visible = _delay <= 0.0
		return
	if homing:
		if _target == null or not is_instance_valid(_target) or not _target.alive:
			_target = _nearest()
		if _target != null:
			var to := (_target.global_position + Vector3(0, 0.8, 0)) - global_position
			to.y *= 0.3
			dir = dir.lerp(to.normalized(), minf(1.0, 7.0 * delta)).normalized()
	global_position += dir * speed * delta
	rotation.y = atan2(-dir.x, -dir.z)
	life -= delta
	for e in Skills.enemies(get_tree()):
		if _hit.has(e):
			continue
		var c := e.global_position + Vector3(0, float(e.data["height"]), 0)
		var dd := global_position - c
		dd.y *= 0.5
		if dd.length() < 0.55 + e.radius:
			_hit[e] = true
			if explode_r > 0.0:
				_explode()
				return
			if player != null and is_instance_valid(player):
				var opts := extra.duplicate()
				if slow > 0.0:
					opts["slow"] = slow
					opts["slow_dur"] = slow_dur
				Skills.hit(player, e, mult, global_position - dir, opts)
			Fx.burst(get_parent(), global_position, color, 8, 4.0, 0.06)
			if not pierce:
				_done = true
				queue_free()
				return
	if life <= 0.0:
		if explode_r > 0.0:
			_explode()
		else:
			_done = true
			queue_free()


func _nearest() -> Enemy:
	var best: Enemy = null
	var bd := 18.0
	for e in Skills.enemies(get_tree()):
		var d := e.global_position.distance_to(global_position)
		if d < bd:
			bd = d
			best = e
	return best


func _explode() -> void:
	_done = true
	var host := get_parent()
	var pos := Vector3(global_position.x, 0.1, global_position.z)
	if player != null and is_instance_valid(player):
		for e in Skills.in_radius(get_tree(), pos, explode_r):
			Skills.hit(player, e, mult, pos)
	Fx.disc(host, pos, color, explode_r, 0.4, 0.28)
	Fx.ring(host, pos, Color(1.0, 0.85, 0.5), explode_r, 0.35)
	Fx.burst(host, global_position, color, 26, 7.0, 0.12)
	Fx.light_flash(host, global_position + Vector3(0, 1, 0), color, 6.0, 10.0, 0.35)
	Sfx.play("sk_explosion", -6.0, 1.3)
	queue_free()
