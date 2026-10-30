class_name Enemy
extends CharacterBody3D
## Inimigo genérico. O tipo (slime, lobo, golem, chefes) vem de GameData.ENEMIES.
## Comportamento: passeia perto de casa, persegue o herói quando ele chega perto ou ataca,
## volta para casa se for longe demais (leash). Chefes fazem golpe em área com aviso no chão.

signal died(enemy: Enemy)

var type_id := "slime"
var data: Dictionary = {}
var level := 1
var max_hp := 10
var crit_from_server := false   # dano vindo do servidor (boss global online): não reenvia
# online: monstro controlado pelo servidor (ServerWorld); aqui só desenha e manda os golpes
var net_id := 0
var net_pos := Vector3.ZERO
var net_moving := false
var net_face := 0.0
var net_credit := true
var net_drop := ""
var hp := 10
var dmg := 5
var speed := 3.0
var radius := 0.6
var boss := false
var alive := true
var aggro := false
var home := Vector3.ZERO
var zone_id := ""

var _kit: ModelKit
var _vis: Node3D
var _bar_fill: MeshInstance3D
var _label: Label3D
var _player: Player
var _cd := 1.0
var _attacking := 0.0
var _wander := Vector3.ZERO
var _wander_t := 0.0
var _slow := 0.0
var _slow_t := 0.0
var _stun_t := 0.0
var _stun_fx: Node3D
var _returning := false
var _vuln := 0.0        # quebra de defesa: dano extra recebido
var _vuln_t := 0.0
var _poison_dps := 0.0  # veneno do Assassino
var _poison_t := 0.0
var _poison_tick := 0.0
var _poison_src: Player


func setup(t: String, pos: Vector3, zone: String = "") -> void:
	type_id = t
	data = GameData.enemy(t)
	position = pos
	home = pos
	zone_id = zone


func _ready() -> void:
	add_to_group("enemy")
	collision_layer = 4
	collision_mask = 1
	level = int(data["level"])
	max_hp = int(data["hp"])
	hp = max_hp
	dmg = int(data["dmg"])
	speed = float(data["speed"])
	boss = bool(data.get("boss", false))
	var sc := float(data["scale"])
	radius = float(data["radius"])
	_cd = randf_range(0.5, 1.5)

	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius * 0.8
	cyl.height = float(data["height"]) * 1.6
	cs.shape = cyl
	cs.position.y = cyl.height * 0.5
	add_child(cs)

	_vis = Node3D.new()
	_vis.rotation.y = randf() * TAU
	add_child(_vis)
	_kit = ModelKit.load_kit(String(data["model"]), float(data.get("outline", 0.03)) / sc, 0.3)
	if _kit != null:
		_kit.root.scale = Vector3.ONE * sc
		_vis.add_child(_kit.root)
		_kit.play("idle")
		_reset_tint()
	else:
		_vis.add_child(Toon.part(Toon.sphere(radius), Color(0.4, 0.8, 0.4), Vector3(0, radius, 0)))
	if boss:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.4, 0.3)
		l.light_energy = 1.5
		l.omni_range = 7.0
		l.position = Vector3(0, float(data["height"]) * 1.5, 0)
		add_child(l)
	var shadow := Toon.glow_part(Toon.cyl(radius * 1.1, radius * 1.1, 0.01, 20), Color(0, 0, 0), Vector3(0, 0.03, 0), 0.35)
	(shadow.material_override as StandardMaterial3D).blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	add_child(shadow)
	_build_bar()


func _build_bar() -> void:
	var w := 3.2 if boss else 1.4
	var root := Node3D.new()
	root.position.y = float(data["bar"])
	add_child(root)
	root.add_child(_quad(Color(0.05, 0.02, 0.02, 0.85), Vector2(w + 0.12, 0.26), 0))
	_bar_fill = _quad(Color(0.92, 0.16, 0.2) if not boss else Color(1.0, 0.45, 0.1), Vector2(w, 0.16), 1)
	(_bar_fill.mesh as QuadMesh).center_offset = Vector3(w / 2.0, 0.0, 0.0)
	_bar_fill.position.x = -w / 2.0
	root.add_child(_bar_fill)
	_label = Label3D.new()
	_label.text = "%s  Nv %d" % [String(data["name"]), level]
	_label.font = Toon.title_font()
	_label.font_size = 40 if boss else 30
	_label.pixel_size = 0.013
	_label.modulate = Color(1.0, 0.82, 0.4) if boss else Color(0.95, 0.9, 0.85)
	_label.outline_size = 10
	_label.outline_modulate = Color(0.05, 0.02, 0.02)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.position.y = 0.38
	_label.visible = boss
	root.add_child(_label)


func _quad(color: Color, size: Vector2, prio: int) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = size
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = color
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.no_depth_test = true
	m.render_priority = prio
	q.material = m
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Longe do herói o monstro não é desenhado (no navegador o WebGL deixa de desenhar o 3D inteiro quando
## há objetos demais: mapas com ~900 malhas ficavam com a tela azul/preta). A lógica continua rodando.
static var DRAW_DIST := 45.0 if OS.has_feature("web") else 60.0
var _draw_t := 0.0


func _update_draw(delta: float) -> void:
	_draw_t -= delta
	if _draw_t > 0.0:
		return
	_draw_t = 0.4 + randf() * 0.2
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var p := get_tree().get_first_node_in_group("player") as Node3D
	var ref: Vector3 = p.global_position if p != null else (cam.global_position if cam != null else global_position)
	var near := Vector2(global_position.x - ref.x, global_position.z - ref.z).length() < DRAW_DIST
	if _vis != null and _vis.visible != near:
		_vis.visible = near
	if _label != null and not near:
		_label.visible = false


func _physics_process(delta: float) -> void:
	if not alive:
		return
	_update_draw(delta)
	if net_id > 0:
		_net_process(delta)
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player
		if _player == null:
			return
	if not is_on_floor():
		velocity.y -= 25.0 * delta
	else:
		velocity.y = 0.0
	_slow_t -= delta
	if _slow_t <= 0.0 and _slow > 0.0:
		_slow = 0.0
		if _kit != null:
			_reset_tint()
	_stun_t -= delta
	if _stun_fx != null and _stun_t <= 0.0:
		_stun_fx.queue_free()
		_stun_fx = null
	_cd -= delta
	_attacking -= delta
	_vuln_t -= delta
	if _vuln_t <= 0.0:
		_vuln = 0.0
	if _poison_t > 0.0:
		_poison_t -= delta
		_poison_tick -= delta
		if _poison_tick <= 0.0:
			_poison_tick = 1.0
			take_damage(maxi(1, int(_poison_dps)), global_position, false, Color(0.5, 1.0, 0.35))
			if not alive:
				return
		if _poison_t <= 0.0 and _kit != null and _slow <= 0.0:
			_reset_tint()
	# herói invisível (Camuflagem Sombria): os inimigos perdem o alvo
	if _player.stealth_t > 0.0 and aggro:
		aggro = false

	var to := _player.global_position - global_position
	to.y = 0.0
	var d := to.length()
	var spd := speed * (1.0 - _slow)
	var move := Vector3.ZERO

	if _stun_t > 0.0 or not _player.alive:
		if not _player.alive:
			aggro = false
	elif _returning:
		var back := home - global_position
		back.y = 0.0
		if back.length() < 1.5:
			_returning = false
		else:
			move = back.normalized() * spd * 1.6
	else:
		var aggro_r := float(data.get("aggro_r", 15.0 if boss else 8.5))
		if not aggro and d < aggro_r:
			aggro = true
		if aggro and (global_position - home).length() > float(data.get("leash", 34.0 if boss else 24.0)):
			aggro = false
			_returning = true
			hp = max_hp
			_update_bar()
		if aggro:
			var reach := float(data["range"])
			if _attacking > 0.0:
				pass
			elif d > reach * 0.85:
				move = to / maxf(d, 0.01) * spd
			elif _cd <= 0.0:
				_start_attack(to, d)
		else:
			_wander_t -= delta
			if _wander_t <= 0.0:
				_wander_t = randf_range(1.5, 4.0)
				var off := Vector3(randf_range(-6, 6), 0, randf_range(-6, 6))
				_wander = (home + off - global_position)
				_wander.y = 0.0
				if randf() < 0.4:
					_wander = Vector3.ZERO
			if _wander.length() > 0.5:
				move = _wander.normalized() * spd * 0.4
				_wander -= move * delta

	velocity.x = move.x
	velocity.z = move.z
	move_and_slide()

	var face := to if (aggro and _attacking <= 0.0 and d > 0.1) else move
	if face.length() > 0.1 and _stun_t <= 0.0:
		_vis.rotation.y = lerp_angle(_vis.rotation.y, atan2(-face.x, -face.z), 8.0 * delta)
	if _kit != null and _attacking <= 0.0:
		if move.length() > 0.2:
			_kit.play("walk", clampf(move.length() / 3.0, 0.6, 1.8))
		else:
			_kit.play("idle")


func _start_attack(to: Vector3, d: float) -> void:
	_cd = float(data["atk_cd"]) * randf_range(0.9, 1.15)
	_vis.rotation.y = atan2(-to.x, -to.z)
	if String(data["style"]) == "slam":
		var r := float(data["slam_r"])
		var wind := 0.95
		_attacking = wind + 0.35
		var center := global_position
		Fx.telegraph(get_parent(), center, r, Color(1.0, 0.2, 0.12), wind)
		if _kit != null and _kit.has_anim("attack"):
			var L := _kit.length("attack")
			get_tree().create_timer(maxf(0.0, wind - L * 0.7)).timeout.connect(func() -> void:
				if alive and _kit != null:
					_kit.play("attack", 1.0, true))
		get_tree().create_timer(wind).timeout.connect(func() -> void: _slam_land(center, r))
	else:
		var wind2 := 0.32
		_attacking = wind2 + 0.3
		if _kit != null:
			_kit.play("attack", 1.0, true)
		get_tree().create_timer(wind2).timeout.connect(func() -> void:
			if not alive or _player == null or _stun_t > 0.0:
				return
			var dd := (_player.global_position - global_position)
			dd.y = 0.0
			if dd.length() <= float(data["range"]) + 0.6:
				_player.take_damage(int(dmg * _atk_mult()), global_position, self))


func _slam_land(center: Vector3, r: float) -> void:
	if not alive:
		return
	var host := get_parent()
	Fx.ring(host, center + Vector3(0, 0.1, 0), Color(1.0, 0.55, 0.25), r, 0.4)
	Fx.burst(host, center + Vector3(0, 0.3, 0), Color(0.75, 0.6, 0.45), 26, 7.0, 0.14)
	Fx.shake(self, 0.35)
	Sfx.play("sk_slam", -4.0, 0.8)
	if _player != null and _player.alive:
		var p := _player.global_position
		if Vector2(p.x - center.x, p.z - center.z).length() <= r:
			_player.take_damage(int(dmg * _atk_mult()), center, self)


func _atk_mult() -> float:
	# veneno reduz a força/velocidade de ataque do alvo
	return 0.75 if _poison_t > 0.0 else 1.0


## Cor própria do monstro (variantes dos mapas gerados) — volta para ela depois de lentidão/veneno.
func _reset_tint() -> void:
	if _kit == null:
		return
	if data.has("tint"):
		_kit.set_tint(data["tint"], float(data.get("tint_amt", 0.4)))
	else:
		_kit.set_tint(Color.WHITE, 0.0)


func apply_vuln(amount: float, t: float) -> void:
	_vuln = maxf(_vuln, amount)
	_vuln_t = maxf(_vuln_t, t)


func apply_poison(dps: float, t: float, src: Player) -> void:
	_poison_dps = maxf(_poison_dps, dps)
	_poison_t = t
	_poison_src = src
	if _kit != null:
		_kit.set_tint(Color(0.45, 1.0, 0.35), 0.4)
	if _cd < 0.4:
		_cd += 0.4   # ataques mais lentos


func knockback(from: Vector3, dist: float) -> void:
	if boss or not alive:
		return
	var away := global_position - from
	away.y = 0.0
	if away.length() < 0.01:
		return
	var tw := create_tween()
	tw.tween_property(self, "global_position", global_position + away.normalized() * dist, 0.2).set_ease(Tween.EASE_OUT)


func lift(t: float) -> void:
	if not alive or _vis == null:
		return
	var tw := _vis.create_tween()
	tw.tween_property(_vis, "position:y", 1.6 if not boss else 0.5, t * 0.4).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_vis, "rotation:y", _vis.rotation.y + TAU, t * 0.8)
	tw.tween_property(_vis, "position:y", 0.0, t * 0.4).set_ease(Tween.EASE_IN)


func take_damage(n: int, from: Vector3, crit: bool = false, tint: Color = Color(0, 0, 0, 0)) -> void:
	if not alive:
		return
	if _vuln > 0.0:
		n = int(round(n * (1.0 + _vuln)))
	if self is WorldBoss and not crit_from_server:
		(self as WorldBoss).my_dmg += mini(n, hp)
		if get_node("/root/Net").online:   # online: a vida do boss é do servidor
			get_node("/root/Net").boss_hit.rpc_id(1, (self as WorldBoss).net_key, n, int(data["hp"]))
	if net_id > 0:   # online: o servidor decide a vida e a morte
		get_node("/root/Net").enemy_hit.rpc_id(1, net_id, n)
		hp = maxi(1, hp - n)
	elif self is WorldBoss and get_node("/root/Net").online and not crit_from_server:
		hp = maxi(1, hp - n)   # boss global online: só morre quando o servidor mandar
	else:
		hp -= n
	aggro = true
	_returning = false
	if _kit != null:
		_kit.flash(self)
	var host := get_parent()
	var top := global_position + Vector3(0, float(data["bar"]) * 0.8, 0)
	var numc := Color(1.0, 0.82, 0.25) if crit else Color(1, 1, 1)
	if tint.a > 0.0:
		numc = tint
	Fx.damage_number(host, top, str(n), numc, crit)
	Fx.burst(host, global_position + Vector3(0, float(data["height"]), 0), Color(1.0, 0.75, 0.35) if not crit else Color(1.0, 0.95, 0.6), 10 if not crit else 18, 6.0, 0.07)
	Sfx.play("crit" if crit else "hit", -6.0 if not crit else -2.0)
	if crit:
		Fx.hitstop(self, 0.04)
	if not boss and _stun_t <= 0.0:
		var away := global_position - from
		away.y = 0.0
		if away.length() > 0.01:
			global_position += away.normalized() * 0.35
	_label.visible = true
	_update_bar()
	if hp <= 0:
		_die()


func _net_process(delta: float) -> void:
	_attacking -= delta
	_stun_t -= delta
	if _stun_fx != null and _stun_t <= 0.0:
		_stun_fx.queue_free()
		_stun_fx = null
	_slow_t -= delta
	if _slow_t <= 0.0 and _slow > 0.0:
		_slow = 0.0
		if _kit != null:
			_reset_tint()
	var to := net_pos - global_position
	to.y = 0.0
	if to.length() > 8.0:
		global_position = Vector3(net_pos.x, global_position.y, net_pos.z)
	else:
		global_position += to * minf(1.0, delta * 10.0)
	_vis.rotation.y = lerp_angle(_vis.rotation.y, net_face, 8.0 * delta)
	if _kit != null and _attacking <= 0.0:
		_kit.play("walk" if net_moving else "idle")


## Servidor avisou o ataque: mostra a animação (e o aviso no chão no pisão).
func net_attack(slam: bool, center: Vector3, r: float, wind: float) -> void:
	if not alive:
		return
	_attacking = wind + 0.3
	if slam:
		Fx.telegraph(get_parent(), center, r, Color(1.0, 0.2, 0.12), wind)
		get_tree().create_timer(wind).timeout.connect(func() -> void:
			if alive:
				Fx.ring(get_parent(), center + Vector3(0, 0.1, 0), Color(1.0, 0.55, 0.25), r, 0.4)
				Sfx.play("sk_slam", -4.0, 0.8))
	if _kit != null and _kit.has_anim("attack"):
		_kit.play("attack", 1.0, true)


## Servidor mandou a vida.
func net_set_hp(v: int) -> void:
	if v < hp:
		hp = v
	elif v > hp + max_hp * 0.2:   # voltou para casa e curou
		hp = v
	_update_bar()


func net_die(credit: bool, drop: String) -> void:
	net_credit = credit
	net_drop = drop
	hp = 0
	_update_bar()
	_die()


func _update_bar() -> void:
	_bar_fill.scale.x = maxf(float(hp) / float(max_hp), 0.001)


func apply_stun(t: float) -> void:
	if not alive:
		return
	if boss:
		t *= 0.35
	_stun_t = maxf(_stun_t, t)
	_attacking = 0.0
	if _stun_fx == null:
		_stun_fx = Node3D.new()
		_stun_fx.position.y = float(data["bar"]) - 0.4
		add_child(_stun_fx)
		for i in 3:
			var star := Toon.glow_part(Toon.sphere(0.12, 8), Color(1.0, 0.9, 0.3))
			var a := TAU * i / 3.0
			star.position = Vector3(cos(a) * 0.5, 0, sin(a) * 0.5)
			_stun_fx.add_child(star)
		var tw := _stun_fx.create_tween().set_loops()
		tw.tween_property(_stun_fx, "rotation:y", TAU, 0.8).from(0.0)


func apply_slow(amount: float, t: float) -> void:
	if not alive:
		return
	_slow = maxf(_slow, amount)
	_slow_t = maxf(_slow_t, t)
	if _kit != null:
		_kit.set_tint(Color(0.55, 0.85, 1.0), 0.45)


func pull_to(target: Vector3, time: float) -> void:
	if boss or not alive:
		return
	var tw := create_tween()
	tw.tween_property(self, "global_position", Vector3(target.x, global_position.y, target.z), time).set_ease(Tween.EASE_OUT)


func _die() -> void:
	alive = false
	remove_from_group("enemy")
	collision_layer = 0
	Sfx.play("slime_die" if type_id.begins_with("slime") else "hit", -3.0, 0.7 if boss else 1.0)
	Fx.burst(get_parent(), global_position + Vector3(0, float(data["height"]), 0), Color(1.0, 0.85, 0.5), 30 if boss else 16, 7.0, 0.1)
	if boss:
		Fx.ring(get_parent(), global_position + Vector3(0, 0.1, 0), Color(1.0, 0.8, 0.4), 8.0, 0.8)
		Fx.light_flash(get_parent(), global_position + Vector3(0, 2, 0), Color(1.0, 0.8, 0.5), 8.0, 16.0, 0.8)
	died.emit(self)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3(1.25, 0.05, 1.25), 0.3).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)
