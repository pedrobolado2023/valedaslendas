class_name WorldBoss
extends Enemy
## Boss global (Dragão Ancestral). Além da mordida normal do Enemy, a cada poucos segundos faz uma mecânica:
##   fase 1 (100%-60%): sopro de fogo em cone e chuva de meteoros (com aviso no chão);
##   fase 2 (60%-30%): + voo e queda em cima de um jogador, e chama dragonetes;
##   fase 3 (<30%): + anel de fogo que se espalha, tudo mais rápido.
## Mira em todos os jogadores do grupo "player" (pronto para o multiplayer). Números em GameData.GLOBAL_BOSS.

signal phase_changed(phase: int)
signal departed

var cfg: Dictionary = GameData.GLOBAL_BOSS
var phase := 1
var _mech_t := 4.0
var _rot := 0
var _flying := false
var _whelp_cd := 0.0


func _physics_process(delta: float) -> void:
	if not alive:
		return
	if _flying:
		return
	super(delta)
	if not alive:
		return
	_whelp_cd -= delta
	var ratio := float(hp) / float(max_hp)
	var p := 3 if ratio <= float(cfg["phase3"]) else (2 if ratio <= float(cfg["phase2"]) else 1)
	if p != phase:
		phase = p
		_roar()
		phase_changed.emit(phase)
		if phase >= 2:
			_whelps()
	_mech_t -= delta
	if _mech_t <= 0.0 and aggro and _attacking <= 0.0 and _stun_t <= 0.0:
		_mech_t = float(cfg["mech_every"]) * (0.7 if phase == 3 else 1.0)
		_do_mech()


func _targets() -> Array[Player]:
	var out: Array[Player] = []
	for n in get_tree().get_nodes_in_group("player"):
		var pl := n as Player
		if pl != null and pl.alive and (pl.global_position - global_position).length() < 70.0:
			out.append(pl)
	return out


func _do_mech() -> void:
	var list := ["breath", "meteors"]
	if phase >= 2:
		list = ["breath", "dive", "meteors"]
	if phase >= 3:
		list = ["ring", "breath", "dive", "meteors"]
	var m: String = list[_rot % list.size()]
	_rot += 1
	if phase >= 2 and _whelp_cd <= 0.0 and randf() < 0.35:
		_whelps()
	var tg := _targets()
	if tg.is_empty():
		return
	match m:
		"breath":
			_breath(tg[randi() % tg.size()])
		"meteors":
			_meteors(tg)
		"dive":
			_dive(tg[randi() % tg.size()])
		"ring":
			_fire_ring()


func _roar() -> void:
	Sfx.play("boss", -2.0, 0.8)
	Fx.shake(self, 0.5)
	Vfx.shockwave(get_parent(), global_position, Color(1.0, 0.5, 0.2), 14.0, 0.6)
	if _kit != null:
		_kit.play("attack", 0.7, true)


## Sopro de fogo em cone na direção de um jogador.
func _breath(t: Player) -> void:
	var dir := t.global_position - global_position
	dir.y = 0.0
	dir = dir.normalized()
	var length := float(cfg["breath_len"])
	var half := float(cfg["breath_half"])
	var dur := float(cfg["breath_dur"])
	_attacking = 0.9 + dur
	_vis.rotation.y = atan2(-dir.x, -dir.z)
	var host := get_parent()
	for k in 4:   # aviso: círculos ao longo do cone
		var d := length * (0.25 + 0.22 * k)
		Fx.telegraph(host, global_position + dir * d, d * tan(half) + 0.8, Color(1.0, 0.35, 0.1), 0.85)
	if _kit != null:
		_kit.play("attack", 0.8, true)
	get_tree().create_timer(0.85).timeout.connect(func() -> void:
		if not alive:
			return
		Vfx.flame_stream(self, dir, length, dur, 4.2, 2.2)
		Sfx.play("sk_fire", -2.0, 0.7)
		for k in int(dur / 0.2):
			get_tree().create_timer(0.2 * k).timeout.connect(func() -> void:
				if not alive:
					return
				for pl in _targets():
					var to := pl.global_position - global_position
					to.y = 0.0
					var dd := to.length()
					if dd <= length and (dd < 2.0 or dir.dot(to / dd) >= cos(half)):
						pl.take_damage(maxi(1, int(dmg * float(cfg["breath_mult"]))), global_position, self)))


## Chuva de meteoros: um em cima de cada jogador e o resto espalhado.
func _meteors(tg: Array[Player]) -> void:
	var host := get_parent()
	var blast := float(cfg["meteor_blast"])
	var spots: Array[Vector3] = []
	for pl in tg:
		spots.append(pl.global_position)
	while spots.size() < int(cfg["meteor_count"]):
		spots.append(global_position + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).limit_length(1.0) * 20.0)
	_roar()
	for k in spots.size():
		var at := Vector3(spots[k].x, 0.0, spots[k].z)
		var delay := 1.3 + 0.12 * k
		Fx.telegraph(host, at, blast, Color(1.0, 0.3, 0.1), delay)
		get_tree().create_timer(delay - 1.0).timeout.connect(func() -> void: Vfx.meteor(host, at, 1.0, blast))
		get_tree().create_timer(delay).timeout.connect(func() -> void:
			if not alive:
				return
			Sfx.play("sk_explosion", -6.0, 0.9)
			for pl in _targets():
				if Vector2(pl.global_position.x - at.x, pl.global_position.z - at.z).length() <= blast:
					pl.take_damage(int(dmg * float(cfg["meteor_mult"])), at, self))


## Voo e queda: some no céu, marca um jogador e cai em cima dele.
func _dive(t: Player) -> void:
	_flying = true
	_attacking = 99.0
	remove_from_group("enemy")
	collision_layer = 0
	var host := get_parent()
	var r := float(cfg["dive_r"])
	Sfx.play("boss", -4.0, 1.1)
	var tw := _vis.create_tween()
	tw.tween_property(_vis, "position:y", 16.0, 0.7).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(func() -> void:
		var spot := t.global_position if is_instance_valid(t) else global_position
		spot.y = global_position.y
		Fx.telegraph(host, spot, r, Color(1.0, 0.2, 0.1), 1.6)
		get_tree().create_timer(1.3).timeout.connect(func() -> void:
			if not alive:
				return
			global_position = spot
			var tw2 := _vis.create_tween()
			tw2.tween_property(_vis, "position:y", 0.0, 0.3).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
			tw2.tween_callback(func() -> void:
				_flying = false
				_attacking = 0.6
				add_to_group("enemy")
				collision_layer = 4
				Vfx.ground_slam(host, spot, r, Color(1.0, 0.5, 0.2))
				Fx.shake(self, 0.7)
				Sfx.play("sk_slam", 0.0, 0.6)
				for pl in _targets():
					if Vector2(pl.global_position.x - spot.x, pl.global_position.z - spot.z).length() <= r:
						pl.take_damage(int(dmg * float(cfg["dive_mult"])), spot, self))))


## Chama dragonetes em volta.
func _whelps() -> void:
	_whelp_cd = 25.0
	var host := get_parent()
	for i in int(cfg["whelps"]):
		var a := TAU * i / float(cfg["whelps"]) + randf() * 0.5
		var at := global_position + Vector3(cos(a), 0, sin(a)) * 8.0
		var e := Enemy.new()
		e.setup("dragon_hatchling", at + Vector3(0, 0.3, 0), zone_id)
		host.add_child(e)
		Vfx.explosion(host, at, 2.0, false)


## Anel de fogo que sai do dragão e se espalha (fase 3): só não pega quem estiver longe ou bem colado nele.
func _fire_ring() -> void:
	var host := get_parent()
	_attacking = 1.2
	_roar()
	var hit := {}
	var steps := 10
	for k in steps:
		var rr := 3.0 + 20.0 * float(k + 1) / steps
		get_tree().create_timer(0.6 + 0.12 * k).timeout.connect(func() -> void:
			if not alive:
				return
			Vfx.emit(host, global_position + Vector3(0, 0.3, 0), {"tex": "flame", "add": false, "amount": int(rr * 3), "life": 0.6,
					"quad": Vector2(0.6, 1.1), "size": [1.0, 1.8], "shape": "ring", "r": rr, "r_in": rr - 0.6, "vel": [1.0, 3.0],
					"dir": Vector3.UP, "spread": 15.0, "colors": Vfx.FIRE, "spin": 0.0})
			for pl in _targets():
				if hit.has(pl):
					continue
				var dd := Vector2(pl.global_position.x - global_position.x, pl.global_position.z - global_position.z).length()
				if absf(dd - rr) < 1.4:
					hit[pl] = true
					pl.take_damage(int(dmg * float(cfg["ring_mult"])), global_position, self))


## Fim do horário do evento: o dragão levanta voo e vai embora.
func depart() -> void:
	if not alive:
		return
	alive = false
	remove_from_group("enemy")
	collision_layer = 0
	Sfx.play("boss", -3.0, 0.7)
	var tw := _vis.create_tween()
	tw.tween_property(_vis, "position:y", 30.0, 2.0).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		departed.emit()
		queue_free())
