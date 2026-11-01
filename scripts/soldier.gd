class_name Soldier
extends Node3D
## Soldado da tropa do herói: em combate corre até o monstro mais perto (até 18 m do herói) e bate com a lança,
## ganhando fúria para o herói; sem monstros (ou fora de combate) volta para a formação ao lado dele.

var player: Player
var side_offset := 1.5   # -1.5 para esquerda, +1.5 para direita
var back_offset := 0.4
var troop_name := "Lanceiro da Guarda"
var troop_type := "lanceiro"
var level := 1
var hp := 250.0
var max_hp := 250.0
var atk := 18.0
var alive := true

var _kit: ModelKit
var _act_t := 0.0
var _attack_cd := 0.2
var _shadow: Node3D


func setup(p: Player, side: float, type_name: String = "lanceiro", lvl: int = 1) -> void:
	player = p
	side_offset = side
	troop_type = type_name
	level = lvl
	top_level = true
	recalc()

	# Posição inicial ao lado do herói
	var right_vec := Vector3(1, 0, 0)
	if p.facing.length() > 0.1:
		right_vec = p.facing.normalized().cross(Vector3.UP).normalized()
	var init_pos := p.global_position + right_vec * side_offset + Vector3(0, 0, back_offset)
	init_pos.y = p.global_position.y
	if is_inside_tree():
		global_position = init_pos
	else:
		position = init_pos

	# Modelo 3D humanizado do soldado da guarda
	var model_name := "hero_lanceiro_ia" if troop_type == "lanceiro" else "hero_guerreiro_ia"
	_kit = ModelKit.load_kit(model_name, 0.030)
	if _kit == null:
		_kit = ModelKit.load_kit("hero_lanceiro", 0.030)
	if _kit != null:
		_kit.root.scale = Vector3.ONE * 0.90
		add_child(_kit.root)
		_kit.play("idle")

		# Arma 3D da tropa
		var weapon_name := "weapon_lanceiro_ia" if troop_type == "lanceiro" else "weapon_guerreiro_ia"
		var wk := ModelKit.load_kit(weapon_name, 0.01)
		var slot := Player.weapon_slot(_kit)
		if wk != null and slot != null:
			slot.add_child(wk.root)

	# Sombra suave no chão
	_shadow = Toon.glow_part(Toon.cyl(0.5, 0.5, 0.01, 16), Color(0, 0, 0), Vector3(0, 0.02, 0), 0.35)
	if _shadow != null and _shadow.material_override is StandardMaterial3D:
		(_shadow.material_override as StandardMaterial3D).blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	add_child(_shadow)

	# Brilho sutil de tropa aliada
	var l := OmniLight3D.new()
	l.light_color = Color(0.65, 0.88, 1.0)
	l.light_energy = 0.4
	l.omni_range = 2.5
	l.position.y = 1.0
	add_child(l)


func recalc() -> void:
	if player == null:
		return
	max_hp = 180.0 + player.level * 35.0 + level * 40.0
	hp = max_hp
	atk = 16.0 + player.atk * 0.35 + level * 6.0


static func flat_dist(a: Vector3, b: Vector3) -> float:
	var dx := a.x - b.x
	var dz := a.z - b.z
	return sqrt(dx * dx + dz * dz)


func _find_combat_target() -> Enemy:
	var best: Enemy = null
	var bd := 16.0
	for e in Skills.enemies(get_tree()):
		if not is_instance_valid(e) or not e.alive:
			continue
		var dp := flat_dist(e.global_position, player.global_position)
		var ds := flat_dist(e.global_position, global_position)
		# Só foca em inimigos no raio de segurança de 18m do herói
		if dp <= 18.0 and ds < bd:
			bd = ds
			best = e
	return best


func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player) or not alive:
		return

	_act_t -= delta
	_attack_cd -= delta

	if not player.alive:
		if _kit != null:
			_kit.play("idle")
		return

	# Calcula posição ideal de formação ao lado do herói
	var fwd := player.facing.normalized() if player.facing.length() > 0.1 else Vector3.FORWARD
	var right := fwd.cross(Vector3.UP).normalized()
	var ideal_pos := player.global_position + right * side_offset + (-fwd) * back_offset
	ideal_pos.y = player.global_position.y

	# Se o herói teletransportou ou correu muito longe (> 28m), puxa de imediato
	var dist_to_player := global_position.distance_to(player.global_position)
	if dist_to_player > 28.0:
		global_position = ideal_pos
		return

	# Verifica se há monstros no campo
	var target: Enemy = _find_combat_target()

	# Se o jogador NÃO está em combate e o monstro está longe (> 12m), mantém formação
	if target != null and not player.in_combat():
		if flat_dist(target.global_position, player.global_position) > 12.0:
			target = null

	# ===================================================================
	# 1. ESTADO DE BATALHA: Sai do lado do herói e vai pra cima dos bichos!
	# ===================================================================
	if target != null and is_instance_valid(target) and target.alive:
		var to_enemy := target.global_position - global_position
		to_enemy.y = 0.0
		var d_enemy := to_enemy.length()
		var melee_range := 2.8 + float(target.data.get("radius", 0.6))   # alcance da lança

		if d_enemy > melee_range:
			# Avança correndo até o monstro
			var charge_dir := to_enemy.normalized()
			var charge_speed := maxf(player.speed * 1.30, 9.5)
			global_position += charge_dir * charge_speed * delta
			global_position.y = player.global_position.y
			rotation.y = lerp_angle(rotation.y, atan2(-charge_dir.x, -charge_dir.z), delta * 14.0)
			if _act_t <= 0.0 and _kit != null:
				_kit.play("run", 1.3)
		else:
			# Está no alcance corpo a corpo: encara o bicho e bate com a lança!
			rotation.y = lerp_angle(rotation.y, atan2(-to_enemy.x, -to_enemy.z), delta * 16.0)
			if _attack_cd <= 0.0:
				_do_attack(target, to_enemy.normalized())
			elif _act_t <= 0.0 and _kit != null:
				_kit.play("idle")
		return

	# ===================================================================
	# 2. ESTADO DE FORMAÇÃO: Nenhum monstro em combate -> volta para o lado do herói
	# ===================================================================
	var dist_to_formation := global_position.distance_to(ideal_pos)
	if dist_to_formation > 0.45:
		# Corre de volta para o lado do herói
		var return_dir := (ideal_pos - global_position).normalized()
		var return_spd := maxf(player.speed * 1.35, 9.0) if dist_to_formation > 3.0 else maxf(player.speed, 6.5)
		global_position += return_dir * return_spd * delta
		global_position.y = player.global_position.y
		rotation.y = lerp_angle(rotation.y, atan2(-return_dir.x, -return_dir.z), delta * 12.0)
		if _act_t <= 0.0 and _kit != null:
			_kit.play("run" if return_spd > 6.0 else "walk", return_spd / 6.0)
	else:
		# Já está ao lado do herói em formação perfeita
		global_position = global_position.lerp(ideal_pos, delta * 10.0)
		global_position.y = player.global_position.y
		rotation.y = lerp_angle(rotation.y, atan2(-fwd.x, -fwd.z), delta * 10.0)
		if _act_t <= 0.0 and _kit != null:
			var hero_moving := player.velocity.length() > 0.5
			if hero_moving:
				var spd := player.speed
				_kit.play("run" if spd > 6.0 else "walk", spd / 6.0)
			else:
				_kit.play("idle")


func _do_attack(enemy: Enemy, dir: Vector3) -> void:
	_attack_cd = randf_range(0.75, 1.05)
	_act_t = 0.38
	if _kit != null:
		_kit.play("attack", 1.5, true)
		# Avanço físico de estocada da lança
		if _kit.root != null:
			var tw := create_tween()
			tw.tween_property(_kit.root, "position:z", -0.4, 0.08).set_ease(Tween.EASE_OUT)
			tw.tween_property(_kit.root, "position:z", 0.0, 0.12).set_ease(Tween.EASE_IN)

	var host := get_parent()
	var spear_tip := global_position + dir * 1.8 + Vector3(0, 1.0, 0)

	# Efeito físico de corte/estocada da lança
	Fx.slash(host, global_position + dir * 0.9 + Vector3(0, 1.0, 0), atan2(dir.z, dir.x), 3.4, 75.0, Color(0.8, 0.92, 1.0), 0.85, 0.22)
	Fx.streak(host, global_position + Vector3(0, 1.0, 0), spear_tip, Color(0.9, 0.95, 1.0), 0.3, 0.18)
	Vfx.sparks(host, spear_tip, 16, 5.0)
	Sfx.play("swing", -5.0, 1.3)

	# dano da tropa (o número aparece em azul pelo próprio inimigo)
	var dmg := maxi(1, int(atk * randf_range(0.92, 1.08)))
	enemy.take_damage(dmg, global_position, false, Color(0.7, 0.9, 1.0))

	# os golpes da tropa enchem a fúria do herói
	if player != null and is_instance_valid(player):
		player.add_fury(6.0)


func take_damage(n: int) -> void:
	if not alive:
		return
	hp -= n
	if _kit != null:
		_kit.flash(self)
	Fx.damage_number(get_parent(), global_position + Vector3(0, 2.2, 0), "-%d" % n, Color(1.0, 0.5, 0.5))
	if hp <= 0.0:
		hp = 0.0
		alive = false
		visible = false
		# Soldado se recompõe após 8 segundos
		get_tree().create_timer(8.0).timeout.connect(func() -> void:
			if player != null and is_instance_valid(player):
				alive = true
				hp = max_hp
				visible = true
				if player.facing.length() > 0.1:
					var r := player.facing.normalized().cross(Vector3.UP).normalized()
					global_position = player.global_position + r * side_offset
				global_position.y = player.global_position.y
				Fx.burst(get_parent(), global_position + Vector3(0, 1, 0), Color(0.6, 0.85, 1.0), 20, 4.0, 0.1)
		)
