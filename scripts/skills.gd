class_name Skills
extends RefCounted
## Execução das skills. Cada skill de GameData.SKILLS tem um "type"; aqui está o efeito de cada tipo.
## Dano = ataque do herói × multiplicador da skill × bônus do nível da skill (+18% por nível).


static func level_mult(lvl: int) -> float:
	return 1.0 + 0.18 * float(maxi(lvl, 1) - 1)


static func cooldown(sk: Dictionary, lvl: int) -> float:
	return float(sk["cd"]) * (1.0 - 0.025 * float(maxi(lvl, 1) - 1))


static func mp_cost(sk: Dictionary, lvl: int) -> float:
	return float(sk["mp"]) * (1.0 + 0.05 * float(maxi(lvl, 1) - 1))


static func buff_amount(sk: Dictionary, lvl: int) -> float:
	return float(sk.get("buff", 0.0)) + float(sk.get("buff_lv", 0.0)) * float(maxi(lvl, 1) - 1)


static func shield_pct(sk: Dictionary, lvl: int) -> float:
	return float(sk.get("pct", 0.0)) + float(sk.get("pct_lv", 0.0)) * float(maxi(lvl, 1) - 1)


static func chain_hops(sk: Dictionary, lvl: int) -> int:
	return int(sk.get("hops", 0)) + (maxi(lvl, 1) - 1) / 3


static func describe(sk: Dictionary, lvl: int, power: float = 1.0) -> String:
	var s := String(sk["desc"])
	s = s.replace("{dmg}", "%d%%" % int(round(float(sk.get("mult", 1.0)) * level_mult(lvl) * power * 100.0)))
	s = s.replace("{r}", ("%.1f" % area(sk, 0.0)).replace(".", ","))
	s = s.replace("{buff}", "%d%%" % int(round(buff_amount(sk, lvl) * 100.0)))
	s = s.replace("{dur}", ("%.0f" % float(sk.get("dur", 0.0))))
	s = s.replace("{n}", str(chain_hops(sk, lvl)))
	s = s.replace("{shield}", "%d%%" % int(round(shield_pct(sk, lvl) * 100.0)))
	return s


## Raio da skill já com o aumento geral de área (GameData.AREA_MULT).
static func area(sk: Dictionary, fallback: float = 0.0) -> float:
	return float(sk.get("r", fallback)) * GameData.AREA_MULT


static func flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


static func enemies(tree: SceneTree) -> Array[Enemy]:
	var out: Array[Enemy] = []
	if tree == null:
		return out
	for n in tree.get_nodes_in_group("enemy"):
		var e := n as Enemy
		if e != null and e.alive:
			out.append(e)
	return out


static func in_radius(tree: SceneTree, c: Vector3, r: float) -> Array[Enemy]:
	var out: Array[Enemy] = []
	for e in enemies(tree):
		if flat(e.global_position - c).length() <= r + e.radius:
			out.append(e)
	return out


static func in_cone(tree: SceneTree, o: Vector3, dir: Vector3, r: float, cos_half: float) -> Array[Enemy]:
	var out: Array[Enemy] = []
	for e in enemies(tree):
		var to := flat(e.global_position - o)
		var d := to.length()
		if d <= r + e.radius and (d < 0.8 or dir.dot(to / d) >= cos_half):
			out.append(e)
	return out


static func seg_dist(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := flat(b - a)
	var ap := flat(p - a)
	var t := clampf(ap.dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return (ap - ab * t).length()


static func hit(p: Player, e: Enemy, mult: float, from: Vector3, opts: Dictionary = {}) -> void:
	if e == null or not is_instance_valid(e) or not e.alive:
		return
	var crit := randf() < 0.15 + (p.crit_bonus if p.crit_bonus_t > 0.0 else 0.0) or p.crit_next or bool(opts.get("crit", false))
	p.crit_next = false
	# combo: vale para todos os golpes da skill (inclusive os atrasados) enquanto a janela estiver aberta
	var combo_boost := p.combo_active_boost if p.combo_boost_t > 0.0 else 1.0
	var dmg := p.atk * mult * combo_boost * randf_range(0.92, 1.08) * (1.0 + p.dmg_buff) * (1.8 if crit else 1.0)
	if p.double_next:
		p.double_next = false
		dmg *= 2.0
	if p._giant_t > 0.0:
		dmg *= 1.2
	if opts.has("low") and float(e.hp) / float(e.max_hp) < float(opts["low"]):   # Tiro do Caçador
		dmg *= 2.0
	if opts.has("vs_vuln") and e._vuln > 0.0:   # Lança do Firmamento: defesa quebrada
		dmg *= float(opts["vs_vuln"])
	var final := maxi(1, int(round(dmg)))
	e.take_damage(final, from, crit)
	if opts.has("heal"):   # roubo de vida
		p.heal(final * float(opts["heal"]))
	if opts.has("mana"):
		p.mp = minf(p.max_mp, p.mp + float(opts["mana"]))
	if e.alive:
		if opts.has("lift"):
			e.lift(float(opts["lift"]))
		if p.poison_t > 0.0:
			e.apply_poison(p.atk * p.poison_mult, 4.0, p)
			e.apply_slow(0.2, 4.0)
		if opts.has("vuln"):
			e.apply_vuln(float(opts["vuln"]), float(opts.get("vuln_dur", 5.0)))
		if opts.has("knock"):
			e.knockback(from, float(opts["knock"]))
		if opts.has("stun"):
			e.apply_stun(float(opts["stun"]))
		if opts.has("slow"):
			e.apply_slow(float(opts["slow"]), float(opts.get("slow_dur", 2.5)))


static func _later(node: Node, t: float, f: Callable) -> void:
	node.get_tree().create_timer(t).timeout.connect(f)


static func _ang(dir: Vector3) -> float:
	return atan2(dir.z, dir.x)


## Executa a skill i do herói em direção ao ponto (no chão).
static func cast(p: Player, i: int, point: Vector3) -> void:
	var sk: Dictionary = GameData.SKILLS[p.class_key][i]
	var lvl: int = p.skill_levels[i]
	var m := float(sk.get("mult", 1.0)) * level_mult(lvl) * float(p.cdata.get("skill_power", 1.0))   # balanceamento por classe
	var col: Color = sk["color"]
	var pos := p.global_position
	var dir := flat(point - pos)
	if dir.length() < 0.3:
		dir = p.facing
	dir = dir.normalized()
	p.face_dir(dir)
	var host := p.get_parent()
	var tree := p.get_tree()
	Sfx.play(String(sk["sfx"]), -2.0)
	var hand := pos + Vector3(0, 1.1, 0)
	match String(sk["type"]):
		"spin":
			var r := area(sk)
			Fx.slash(host, pos + Vector3(0, 1.0, 0), _ang(dir), r, 380.0, col, 1.1, 0.32)
			Fx.slash(host, pos + Vector3(0, 0.6, 0), _ang(dir) + PI, r * 0.75, 380.0, Color(1, 1, 1), 0.6, 0.3, true)
			Fx.ring(host, pos + Vector3(0, 0.1, 0), col, r, 0.3)
			for e in in_radius(tree, pos, r):
				hit(p, e, m, pos)
			p.spin_visual()
		"dash":
			var dist := float(sk["dist"])
			var end := pos + dir * dist
			p.start_dash(dir, dist, 0.2)
			Fx.streak(host, hand, end + Vector3(0, 1.1, 0), col, 1.0, 0.35)
			_later(p, 0.2, func() -> void:
				for e in enemies(tree):
					if seg_dist(e.global_position, pos, end) <= 1.8 + e.radius:
						hit(p, e, m, pos)
				Fx.ring(host, p.global_position + Vector3(0, 0.1, 0), col, 3.0, 0.3)
				Fx.shake(p, 0.15))
		"slam":
			var r2 := area(sk)
			p.attack_visual()
			Fx.ring(host, pos + Vector3(0, 0.1, 0), col, r2, 0.45, 0.1)
			Fx.disc(host, pos + Vector3(0, 0.05, 0), Color(0.15, 0.08, 0.05), r2 * 0.7, 1.2, 0.5)
			Fx.burst(host, pos + Vector3(0, 0.3, 0), Color(0.6, 0.45, 0.3), 30, 8.0, 0.14)
			Fx.light_flash(host, pos + Vector3(0, 1.5, 0), col, 6.0, 12.0, 0.4)
			Fx.shake(p, 0.4)
			for e in in_radius(tree, pos, r2):
				hit(p, e, m, pos, {"stun": float(sk["stun"])})
		"buff":
			p.add_dmg_buff(buff_amount(sk, lvl), float(sk["dur"]), col)
			Fx.ring(host, pos + Vector3(0, 0.1, 0), col, 4.0, 0.5)
			Fx.burst(host, pos + Vector3(0, 1.0, 0), col, 30, 5.0, 0.1, 0.8, 4.0)
			Fx.light_flash(host, pos + Vector3(0, 2, 0), col, 5.0, 10.0, 0.6)
		"cone":
			var r3 := area(sk)
			var half := float(sk["half"])
			p.attack_visual()
			Fx.slash(host, pos + Vector3(0, 1.0, 0), _ang(dir), r3 * 0.55, rad_to_deg(half * 2.0), Color(1.0, 0.85, 0.4), 1.2, 0.25)
			_flame_cone(host, pos + Vector3(0, 0.9, 0), dir, r3, half, col)
			Fx.light_flash(host, pos + dir * 3.0 + Vector3(0, 1.5, 0), col, 6.0, 12.0, 0.5)
			for e in in_cone(tree, pos, dir, r3, cos(half)):
				hit(p, e, m, pos)
		"strike":
			var r4 := area(sk)
			var target := pos + flat(point - pos).limit_length(float(sk["range"]))
			var delay := float(sk["delay"])
			if String(sk.get("visual", "")) == "sword":
				Vfx.sky_sword(host, target, r4, delay, col)
			else:
				Fx.telegraph(host, target, r4, col, delay)
				_falling(host, target, String(sk["visual"]), col, delay)
			_later(p, delay, func() -> void:
				if String(sk.get("visual", "")) != "sword":
					Fx.ring(host, target + Vector3(0, 0.1, 0), col, r4 * 1.2, 0.5, 0.1)
					Fx.disc(host, target + Vector3(0, 0.05, 0), col, r4, 0.5, 0.28)
					Fx.burst(host, target + Vector3(0, 0.5, 0), col, 40, 10.0, 0.16)
					Fx.light_flash(host, target + Vector3(0, 2, 0), col, 6.0, 16.0, 0.6)
					Fx.shake(p, 0.5)
					Sfx.play("sk_explosion", 0.0)
				for e in in_radius(tree, target, r4):
					hit(p, e, m, target, {"stun": 0.8}))
		"thrust3":
			var rng := float(sk["range"])
			var hits := int(sk["hits"])
			for k in hits:
				_later(p, 0.12 * k, func() -> void:
					if not is_instance_valid(p):
						return
					var o := p.global_position
					p.attack_visual()
					if p.class_key == "lanceiro":
						if p._vis != null:
							var lunge := p.create_tween()
							lunge.tween_property(p._vis, "position:z", -0.45, 0.05).set_ease(Tween.EASE_OUT)
							lunge.tween_property(p._vis, "position:z", 0.0, 0.06).set_ease(Tween.EASE_IN)
						Fx.slash(host, o + dir * 0.55 + Vector3(0, 1.05, 0), _ang(dir) + (k - 1) * 0.12, rng * 0.88, 72.0, col, 0.82, 0.18, k % 2 == 1)
						Vfx.sparks(host, o + dir * (rng * 0.78) + Vector3(0, 1.05, 0), 10, 4.0)
					else:
						var side := dir.cross(Vector3.UP) * (0.35 * (k - 1))
						Fx.streak(host, o + Vector3(0, 1.1, 0) + side, o + dir * rng + Vector3(0, 1.1, 0) + side, col, 0.45, 0.22)
						Vfx.emit(host, o + dir * rng * 0.5 + Vector3(0, 1.1, 0), {"tex": "smoke", "add": false, "amount": 14, "life": 0.5,
								"size": [0.6, 1.2], "shape": "box", "box": Vector3(0.3, 0.3, 0.3) + (dir * rng * 0.45).abs(), "vel": [1.0, 3.0],
								"colors": Vfx.FOAM, "spin": 40.0})
						Vfx.splash(host, o + dir * rng, 0.8)
					Sfx.play("swing", -5.0, 1.1 + 0.1 * k)
					for e in in_cone(tree, o, dir, rng, 0.82):
						hit(p, e, m, o, _opts(sk)))
		"leap":
			var r5 := area(sk)
			var target2 := pos + flat(point - pos).limit_length(float(sk["range"]))
			p.leap_to(target2, 0.45)
			Fx.telegraph(host, target2, r5, col, 0.45)
			_later(p, 0.45, func() -> void:
				Fx.ring(host, target2 + Vector3(0, 0.1, 0), col, r5, 0.4, 0.1)
				Fx.burst(host, target2 + Vector3(0, 0.4, 0), col, 30, 8.0, 0.12)
				Fx.light_flash(host, target2 + Vector3(0, 1.5, 0), col, 6.0, 12.0, 0.4)
				Fx.shake(p, 0.35)
				Sfx.play("sk_slam", -3.0, 1.2)
				for e in in_radius(tree, target2, r5):
					hit(p, e, m, target2, {"stun": 0.5}))
		"pull":
			var r6 := area(sk)
			Fx.slash(host, pos + Vector3(0, 1.0, 0), _ang(dir), r6, 400.0, col, 1.4, 0.4)
			Fx.slash(host, pos + Vector3(0, 0.7, 0), _ang(dir) + 1.0, r6 * 0.6, 400.0, Color(1, 1, 1), 0.7, 0.35)
			Vfx.emit(host, pos + Vector3(0, 0.4, 0), {"tex": "smoke", "add": false, "amount": 30, "life": 0.6, "size": [0.9, 1.8], "shape": "ring",
					"r": r6 * 0.9, "r_in": r6 * 0.6, "vel": [0.5, 1.5], "dir": Vector3.UP, "colors": Vfx.WATER, "spin": 60.0})
			Vfx.shockwave(host, pos, col, r6, 0.4)
			p.spin_visual()
			for e in in_radius(tree, pos, r6):
				var to := flat(e.global_position - pos)
				e.pull_to(pos + to.normalized() * 1.6, 0.25)
			_later(p, 0.25, func() -> void:
				for e in in_radius(tree, p.global_position, 3.0):
					hit(p, e, m, pos)
				Fx.ring(host, p.global_position + Vector3(0, 0.1, 0), col, 3.0, 0.3))
		"projectile":
			var count := int(sk.get("count", 1))
			var spread := float(sk.get("spread", 0.0))
			p.attack_visual()
			for k in count:
				var a := 0.0
				if count > 1:
					a = (float(k) / float(count - 1) - 0.5) * spread if spread < 6.0 else TAU * float(k) / float(count)
				var d2 := dir.rotated(Vector3.UP, a)
				var pr := Projectile.new()
				pr.player = p
				pr.dir = d2
				pr.speed = float(sk.get("speed", 24.0))
				pr.life = float(sk.get("life", 1.0))
				pr.mult = m
				pr.pierce = bool(sk.get("pierce", false))
				pr.explode_r = float(sk.get("explode", 0.0))
				pr.slow = float(sk.get("slow", 0.0))
				pr.slow_dur = float(sk.get("slow_dur", 0.0))
				pr.homing = bool(sk.get("homing", false))
				pr.visual = String(sk.get("visual", "arrow"))
				pr.color = col
				pr.extra = _opts(sk)
				pr._delay = 0.04 * k if pr.homing else 0.0
				host.add_child(pr)
				pr.global_position = hand + d2 * 0.8
		"spikes":
			var length := float(sk["len"])
			var n := int(length / 1.8)
			var done := {}
			for k in n:
				var at := pos + dir * (1.6 + 1.8 * k)
				_later(p, 0.06 * k, func() -> void:
					_spike(host, at, col)
					for e in in_radius(tree, at, 1.5):
						if not done.has(e):
							done[e] = true
							hit(p, e, m, pos, {"stun": float(sk["stun"])}))
		"rain":
			var r7 := area(sk)
			var target3 := pos + flat(point - pos).limit_length(float(sk["range"]))
			var ticks := int(sk["ticks"])
			var every := float(sk["every"])
			var vis := String(sk["visual"])
			Fx.telegraph(host, target3, r7, col, every * ticks + 0.2)
			for k in ticks:
				_later(p, 0.15 + every * k, func() -> void:
					_rain_tick(host, target3, r7, vis, col)
					for e in in_radius(tree, target3, r7):
						hit(p, e, m, target3))
		"roll":
			var rd := p.move_dir()
			if rd == Vector3.ZERO:
				rd = -dir
			p.start_dash(rd, float(sk["dist"]), 0.22)
			p.invuln_t = 0.4
			p.add_speed_buff(buff_amount(sk, lvl), float(sk["dur"]))
			Fx.streak(host, hand, hand + rd * float(sk["dist"]), col, 0.6, 0.3)
			Fx.burst(host, pos + Vector3(0, 0.3, 0), Color(0.7, 0.6, 0.45), 14, 4.0, 0.1)
		"trap":
			var at2 := pos + flat(point - pos).limit_length(float(sk["range"]))
			_trap(p, host, at2, area(sk), m, float(sk["stun"]), col)
		"chain":
			_chain(p, host, hand, point, float(sk["range"]), chain_hops(sk, lvl), m, col, float(sk.get("stun", 0.0)))
		"shield":
			p.add_shield(p.max_hp * shield_pct(sk, lvl), float(sk["dur"]), col)
			Vfx.shockwave(host, pos, col, 3.5, 0.4)
			Vfx.sparks(host, pos + Vector3(0, 1.2, 0), 26, 6.0)
			if sk.has("burst"):
				p.shield_burst = {"mult": float(sk["burst"]) * level_mult(lvl), "r": area(sk), "color": col}
			Vfx.splash(host, pos, 1.2)
		"nova":
			var r8 := area(sk)
			Fx.ring(host, pos + Vector3(0, 0.1, 0), col, r8, 0.45, 0.1)
			Fx.disc(host, pos + Vector3(0, 0.05, 0), Color(0.75, 0.95, 1.0), r8, 0.7, 0.25)
			for k in 12:
				var a2 := TAU * k / 12.0
				_ice_spike(host, pos + Vector3(cos(a2), 0, sin(a2)) * r8 * 0.75, col)
			Fx.burst(host, pos + Vector3(0, 0.8, 0), Color(0.8, 0.95, 1.0), 40, 9.0, 0.1, 0.7, -2.0)
			Fx.light_flash(host, pos + Vector3(0, 1.5, 0), col, 7.0, 14.0, 0.5)
			for e in in_radius(tree, pos, r8):
				hit(p, e, m, pos, {"slow": float(sk["slow"]), "slow_dur": float(sk["slow_dur"])})

		"zone":
			var rz := area(sk)
			var at := pos + flat(point - pos).limit_length(float(sk["range"]))
			var ticks := int(sk["ticks"])
			var every := float(sk["every"])
			Vfx.roots(host, at, rz, every * ticks)
			for k in 10:
				var a := TAU * k / 10.0 + randf() * 0.4
				_vine(host, at + Vector3(cos(a), 0, sin(a)) * rz * randf_range(0.3, 0.9), col, every * ticks)
			for k in ticks:
				_later(p, 0.1 + every * k, func() -> void:
					Vfx.leaves(host, at + Vector3(randf_range(-rz, rz) * 0.5, 0.3, randf_range(-rz, rz) * 0.5), 6, 3.0, 1.0)
					for e in in_radius(tree, at, rz):
						hit(p, e, m, at, {"stun": float(sk["stun"])}))
		"heal_zone":
			var rh := area(sk)
			var at2 := pos
			var amount := p.max_hp * shield_pct(sk, lvl)
			Vfx.heal_field(host, at2, rh, float(sk["dur"]))
			for k in int(sk["ticks"]):
				_later(p, float(sk["every"]) * (k + 1), func() -> void:
					if not is_instance_valid(p):
						return
					if flat(p.global_position - at2).length() <= rh:
						p.heal(amount)
						Vfx.heal_pulse(host, p.global_position)
						Fx.damage_number(host, p.global_position + Vector3(0, 2.6, 0), "+%d" % int(amount), Color(0.45, 1.0, 0.5)))
		"guard":
			p.add_guard(buff_amount(sk, lvl), float(sk["dur"]))
			if String(sk.get("visual", "")) == "shields":
				Vfx.golden_shield(p, float(sk["dur"]), col)
			else:
				_bark(p, col, float(sk["dur"]))
				Vfx.bark_aura(p, float(sk["dur"]))
		"awaken":
			var ra := area(sk)
			Vfx.radiance(host, pos, ra)
			Fx.shake(p, 0.35)
			p.add_dmg_buff(buff_amount(sk, lvl), float(sk["dur"]), col)
			p.cc_immune_t = float(sk["dur"])
			for e in in_radius(tree, pos, ra):
				hit(p, e, m, pos, {"stun": float(sk["stun"])})
		"blink":
			var tgt: Enemy = null
			var bd := float(sk["range"])
			for e in enemies(tree):
				var dd := flat(e.global_position - pos).length()
				if dd < bd:
					bd = dd
					tgt = e
			if tgt == null:
				p.start_dash(dir, 6.0, 0.12)
			else:
				var away := flat(tgt.global_position - pos).normalized()
				var dest := tgt.global_position + away * (tgt.radius + 1.2)
				Vfx.shadow_puff(host, pos, 1.0, col)
				p.global_position = Vector3(dest.x, pos.y, dest.z)
				p.face_dir(-away)
				Vfx.shadow_puff(host, p.global_position, 1.1, col)
			p.crit_next = true
		"poison_buff":
			p.poison_t = float(sk["dur"])
			p.poison_mult = m
			p.add_dmg_buff(p.dmg_buff, float(sk["dur"]), col)
			Vfx.poison_aura(p, float(sk["dur"]))
		"stealth":
			Vfx.shadow_puff(host, pos, 1.8, col)
			Vfx.emit(host, pos + Vector3(0, 0.6, 0), {"tex": "smoke", "add": false, "amount": 20, "life": 2.0, "size": [1.6, 3.0],
					"shape": "ring", "r": 1.2, "vel": [0.5, 1.5], "dir": Vector3.UP, "spread": 60.0, "colors": Vfx.SHADOW,
					"curve": [[0, 0.6], [1, 1.5]], "spin": 30.0})
			p.start_stealth(float(sk["dur"]))
		"spin_multi":
			var rs := area(sk)
			for k in int(sk["hits"]):
				_later(p, 0.14 * k, func() -> void:
					if not is_instance_valid(p):
						return
					var o := p.global_position
					Fx.slash(host, o + Vector3(0, 1.0, 0), _ang(dir) + k * 1.6, rs, 360.0, col, 0.9, 0.2, k % 2 == 1)
					Vfx.emit(host, o + Vector3(0, 1.0, 0), {"tex": "dot", "amount": 16, "life": 0.4, "size": [0.06, 0.14], "shape": "ring",
							"r": rs * 0.8, "r_in": rs * 0.6, "vel": [2.0, 5.0], "gravity": Vector3(0, -5, 0),
							"colors": [[0, Color(0.9, 0.8, 1.0, 0.9)], [1, Color(0.6, 0.3, 1.0, 0.0)]]})
					Vfx.shockwave(host, o, col, rs, 0.25)
					Sfx.play("swing", -6.0, 1.0 + 0.1 * k)
					p.spin_visual()
					for e in in_radius(tree, o, rs):
						hit(p, e, m, o))
		"dodge":
			p.dodge_t = float(sk["dur"])
			Vfx.shadow_puff(host, pos, 1.3, Color(0.45, 0.3, 0.7))
			Vfx.emit(p, pos + Vector3(0, 0.2, 0), {"tex": "smoke", "add": false, "shot": false, "local": true, "amount": 10, "life": 0.9,
					"dur": 1.6, "size": [0.8, 1.4], "shape": "ring", "r": 0.8, "vel": [0.5, 1.2], "dir": Vector3.UP, "spread": 20.0,
					"colors": Vfx.SHADOW})
		"execute":
			var tgt2: Enemy = null
			var low := 2.0
			for e in in_radius(tree, pos, area(sk)):
				var f := float(e.hp) / float(e.max_hp)
				if f < low:
					low = f
					tgt2 = e
			if tgt2 != null:
				var dest2 := tgt2.global_position + flat(pos - tgt2.global_position).normalized() * (tgt2.radius + 1.0)
				Fx.streak(host, hand, dest2 + Vector3(0, 1.1, 0), col, 0.8, 0.3)
				p.global_position = Vector3(dest2.x, pos.y, dest2.z)
				p.face_dir(flat(tgt2.global_position - dest2).normalized())
				p.attack_visual()
				var top := tgt2.global_position + Vector3(0, float(tgt2.data["height"]), 0)
				Vfx.bolt(host, top + Vector3(randf_range(-2, 2), 16, randf_range(-2, 2)), top, col, 0.8, 0.4, 4)
				Vfx.shockwave(host, tgt2.global_position, col, 5.0, 0.45)
				Vfx.emit(host, top, {"tex": "dot", "amount": 30, "life": 0.8, "size": [0.08, 0.18], "vel": [4.0, 9.0], "gravity": Vector3(0, -8, 0),
						"colors": [[0, Color(1.0, 0.95, 0.7, 1)], [1, Color(1.0, 0.6, 0.2, 0)]]})
				Fx.slash(host, top, _ang(dir), 2.4, 220.0, col, 1.3, 0.3)
				Fx.hitstop(p, 0.08)
				hit(p, tgt2, m, pos)
				if not tgt2.alive:
					for j in 6:
						if j != i:
							p.skill_cd[j] = 0.0
					Fx.damage_number(host, p.global_position + Vector3(0, 2.8, 0), "Recarga!", col)
		"turret":
			var at3 := pos + dir * 2.0
			_turret(p, host, at3, m, float(sk["range"]), float(sk["dur"]), float(sk["every"]), col)
		"repair_drone":
			_drone(p, p.max_hp * shield_pct(sk, lvl), float(sk["dur"]), col)
			Vfx.sparks(host, pos + Vector3(0.9, 2.6, 0.4), 20, 4.0)
		"colossus":
			var rc := area(sk)
			p.become_giant(float(sk["dur"]))
			p.add_guard(buff_amount(sk, lvl), float(sk["dur"]))
			_later(p, 0.35, func() -> void:
				if not is_instance_valid(p):
					return
				var o := p.global_position
				p.attack_visual()
				Vfx.ground_slam(host, o, rc, col)
				Fx.shake(p, 0.6)
				Sfx.play("sk_explosion", 0.0, 0.7)
				for e in in_radius(tree, o, rc):
					hit(p, e, m, o, {"stun": 0.8}))
		"companion":
			if String(sk.get("visual", "")) == "phoenix":
				Vfx.phoenix_flight(p, host, dir, float(sk["range"]), float(sk["dur"]), float(sk["every"]), col, m)
			else:
				_jelly(p, m, float(sk["range"]), float(sk["dur"]), float(sk["every"]), col)
		"ice_fall":
			var ri := area(sk)
			var center := pos + flat(point - pos).limit_length(float(sk["range"]))
			var count := int(sk["count"])
			var hit_r := float(sk["hit_r"]) * GameData.AREA_MULT
			Vfx.marker(host, center, col, ri, float(sk["spread_t"]) + 0.6)
			for k in count:
				var off := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).limit_length(1.0) * ri * (0.25 if k == 0 else 0.9)
				var at := center + off
				var fall := 0.55
				var start := 0.05 + float(sk["spread_t"]) * float(k) / count
				_later(p, start, func() -> void:
					Vfx.ice_fall(host, at, fall, randf_range(0.9, 1.3) if k > 0 else 1.6))
				_later(p, start + fall, func() -> void:
					if not is_instance_valid(p):
						return
					Sfx.play("sk_ice", -7.0, randf_range(0.9, 1.2))
					Fx.shake(p, 0.12)
					for e in in_radius(tree, at, hit_r):
						hit(p, e, m, at, {"slow": float(sk["slow"]), "slow_dur": float(sk["slow_dur"])}))
		"tsunami":
			var tlen := float(sk["len"]) * GameData.AREA_MULT
			var tw2 := float(sk["width"]) * GameData.AREA_MULT
			var ttime := float(sk["time"])
			var from := pos - dir * 1.0
			Vfx.wave(host, from, dir, tlen, ttime, tw2)
			Vfx.splash(host, pos + dir * 1.5, 1.5)
			var done2 := {}
			for k in 10:
				_later(p, ttime * (k + 1) / 10.0, func() -> void:
					if not is_instance_valid(p):
						return
					var front := from + dir * tlen * (k + 1) / 10.0
					for e in enemies(tree):
						if done2.has(e):
							continue
						var rel := flat(e.global_position - front)
						if absf(rel.dot(dir)) < 2.0 + e.radius and absf(rel.dot(dir.cross(Vector3.UP))) < tw2 * 0.5 + e.radius:
							done2[e] = true
							hit(p, e, m, front - dir * 3.0, {"knock": float(sk["knock"])})
							Vfx.splash(host, e.global_position, 0.7))
		"bubbles":
			var rb := area(sk)
			var bdur := float(sk["dur"])
			Vfx.shockwave(host, pos, col, rb, 0.5)
			for e in in_radius(tree, pos, rb):
				Vfx.bubble(e, float(e.data["height"]), bdur)
				e.apply_stun(bdur)
				e.lift(bdur)
			_later(p, bdur, func() -> void:
				if not is_instance_valid(p):
					return
				Sfx.play("sk_ice", -4.0, 1.4)
				for e in in_radius(tree, pos, rb + 2.0):
					hit(p, e, m, pos))
		"sea_storm":
			var rs2 := area(sk)
			var at6 := pos + flat(point - pos).limit_length(float(sk["range"]))
			var sdur := float(sk["dur"])
			Vfx.storm(host, at6, rs2, sdur)
			for k in int(sdur / float(sk["every"])):
				_later(p, 0.4 + float(sk["every"]) * k, func() -> void:
					if not is_instance_valid(p):
						return
					var inside := in_radius(tree, at6, rs2)
					var hitp := at6 + Vector3(randf_range(-rs2, rs2), 0, randf_range(-rs2, rs2)).limit_length(rs2)
					var vic: Enemy = null
					if not inside.is_empty():
						vic = inside[randi() % inside.size()]
						hitp = vic.global_position
					Vfx.bolt(host, hitp + Vector3(randf_range(-2, 2), 9, randf_range(-2, 2)), hitp + Vector3(0, 0.3, 0), col, 0.5, 0.3, 3)
					Vfx.shockwave(host, hitp, col, 2.5, 0.3)
					Sfx.play("sk_thunder", -10.0, randf_range(0.9, 1.2))
					if vic != null:
						hit(p, vic, m, hitp, {"slow": float(sk["slow"]), "slow_dur": float(sk["slow_dur"])}))
		"kraken":
			var rk := area(sk)
			var at7 := pos + flat(point - pos).limit_length(float(sk["range"]))
			var targets2: Array[Enemy] = []
			for e in in_radius(tree, at7, rk):
				if targets2.size() < int(sk["count"]):
					targets2.append(e)
			var spots: Array[Vector3] = []
			for e in targets2:
				spots.append(e.global_position)
			while spots.size() < 4:
				spots.append(at7 + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).limit_length(1.0) * rk * 0.8)
			Vfx.marker(host, at7, col, rk, 1.2)
			for k in spots.size():
				var sp: Vector3 = spots[k]
				var face := flat(sp - at7).normalized() if flat(sp - at7).length() > 0.3 else dir
				_later(p, 0.08 * k, func() -> void:
					Vfx.tentacle(host, sp + face * 1.6, randf_range(4.0, 5.5), face))
			_later(p, 0.75, func() -> void:
				if not is_instance_valid(p):
					return
				Fx.shake(p, 0.5)
				Sfx.play("sk_slam", -2.0, 0.8)
				for e in in_radius(tree, at7, rk):
					hit(p, e, m, at7, {"stun": float(sk["stun"])}))
		"missiles":
			var cnt2 := int(sk["count"])
			for k in cnt2:
				_later(p, 0.07 * k, func() -> void:
					if not is_instance_valid(p):
						return
					var side2: Vector3 = dir.cross(Vector3.UP) * (float(k) / float(maxi(1, cnt2 - 1)) - 0.5) * 2.0
					var d4: Vector3 = (dir * 0.4 + side2 + Vector3(0, 0.9, 0)).normalized()
					var mr := Projectile.new()
					mr.player = p
					mr.dir = Vector3(d4.x, 0, d4.z).normalized() if Vector3(d4.x, 0, d4.z).length() > 0.1 else dir
					mr.speed = float(sk["speed"])
					mr.life = 1.6
					mr.mult = m
					mr.homing = true
					mr.explode_r = float(sk["blast"]) * GameData.AREA_MULT
					mr.visual = String(sk.get("visual", "rocket"))
					mr.color = col
					host.add_child(mr)
					mr.global_position = p.global_position + Vector3(0, 1.6, 0) + side2 * 0.4
					Sfx.play("arrow", -10.0, 1.5))
		"flamethrower":
			var flen := float(sk["len"]) * GameData.AREA_MULT
			var fdur := float(sk["dur"])
			var fev := float(sk["every"])
			Vfx.flame_stream(p, dir, flen, fdur)
			for k in int(fdur / fev):
				_later(p, fev * (k + 1), func() -> void:
					if not is_instance_valid(p):
						return
					for e in in_cone(tree, p.global_position, p.facing, flen, cos(float(sk["half"]))):
						hit(p, e, m, p.global_position))
		"orbital":
			var ro := area(sk)
			var at5 := pos + flat(point - pos).limit_length(float(sk["range"]))
			var odelay := float(sk["delay"])
			var odur := float(sk["dur"])
			Vfx.orbital_beam(host, at5, ro, odelay, odur, col)
			_later(p, odelay, func() -> void:
				Sfx.play("sk_explosion", -2.0, 0.8)
				if is_instance_valid(p):
					Fx.shake(p, 0.5))
			for k in int(odur / float(sk["every"])):
				_later(p, odelay + float(sk["every"]) * k, func() -> void:
					if not is_instance_valid(p):
						return
					for e in in_radius(tree, at5, ro):
						hit(p, e, m, at5))
		"tesla":
			_tesla(p, host, pos + dir * 2.5, m, float(sk["range"]) * GameData.AREA_MULT, float(sk["dur"]), float(sk["every"]), int(sk["targets"]), col)
		"dagger_fan":
			var cnt := int(sk["count"])
			var spr := float(sk["spread"])
			for k in cnt:
				var d3 := dir.rotated(Vector3.UP, (float(k) / (cnt - 1) - 0.5) * spr)
				var pr2 := Projectile.new()
				pr2.player = p
				pr2.dir = d3
				pr2.speed = float(sk["speed"])
				pr2.life = float(sk["life"])
				pr2.mult = m
				pr2.pierce = true
				pr2.visual = "dagger"
				pr2.color = col
				pr2.extra = {"vuln": float(sk["vuln"]), "vuln_dur": float(sk["vuln_dur"])}
				host.add_child(pr2)
				pr2.global_position = hand + d3 * 0.6
			Vfx.shadow_puff(host, pos + dir * 0.8, 0.6, col)
		"death_mark":
			var mark := _closest(tree, pos + flat(point - pos).limit_length(float(sk["range"])), float(sk["range"]))
			if mark == null:
				Vfx.shadow_puff(host, pos, 0.7, col)
				return
			var hh := float(mark.data["height"])
			Vfx.sigil(mark, hh, col, float(sk["delay"]))
			var rd := area(sk)
			_later(p, float(sk["delay"]), func() -> void:
				if not is_instance_valid(p):
					return
				var at4 := mark.global_position if is_instance_valid(mark) else pos
				Vfx.shadow_burst(host, at4, rd, col)
				Fx.shake(p, 0.35)
				Sfx.play("sk_explosion", -3.0, 1.4)
				if is_instance_valid(mark) and mark.alive:
					p.crit_next = true
					hit(p, mark, m, at4)
				for e in in_radius(tree, at4, rd):
					if e != mark:
						hit(p, e, m * 0.6, at4))
		"shadow_clones":
			var targets: Array[Enemy] = []
			var pool := enemies(tree)
			pool.sort_custom(func(a: Enemy, b: Enemy) -> bool: return flat(a.global_position - pos).length() < flat(b.global_position - pos).length())
			for e in pool:
				if flat(e.global_position - pos).length() <= float(sk["range"]) and targets.size() < int(sk["count"]):
					targets.append(e)
			Vfx.shadow_puff(host, pos, 1.2, col)
			for k in targets.size():
				var tg := targets[k]
				_later(p, 0.1 + 0.12 * k, func() -> void:
					if is_instance_valid(p) and is_instance_valid(tg):
						_clone_strike(p, host, tg, m, col))
		"eclipse":
			var re := area(sk)
			var dur2 := float(sk["dur"])
			var ev := float(sk["every"])
			Vfx.dark_dome(host, pos, re, dur2)
			Vfx.shadow_puff(host, pos, 1.5, col)
			for k in int(dur2 / ev):
				_later(p, 0.25 + ev * k, func() -> void:
					if not is_instance_valid(p):
						return
					var inside := in_radius(tree, pos, re)
					if inside.is_empty():
						Vfx.blood_slash(host, pos + Vector3(randf_range(-re, re) * 0.6, 1.0, randf_range(-re, re) * 0.6), randf() * TAU, 2.0)
						return
					var vic: Enemy = inside[randi() % inside.size()]
					Vfx.blood_slash(host, vic.global_position + Vector3(0, float(vic.data["height"]) * 0.6, 0), randf() * TAU, 2.2)
					Sfx.play("swing", -9.0, randf_range(1.1, 1.4))
					hit(p, vic, m, pos))
			_later(p, dur2 + 0.1, func() -> void:
				if not is_instance_valid(p):
					return
				Vfx.shadow_burst(host, pos, re, Color(0.9, 0.1, 0.15))
				Fx.shake(p, 0.5)
				Sfx.play("sk_explosion", -2.0, 0.9)
				for e in in_radius(tree, pos, re):
					hit(p, e, m * float(sk["final"]), pos))
		"storm_chain":
			_storm_chain(p, host, point, float(sk["range"]), chain_hops(sk, lvl), float(sk["jump"]), m, col, float(sk["stun"]))
		"meteor_rain":
			var rr := area(sk)
			var center2 := pos + flat(point - pos).limit_length(float(sk["range"]))
			var blast := float(sk["blast"]) * GameData.AREA_MULT
			if String(sk.get("visual", "")) == "colossal":
				# um meteoro gigante só, com um golpe em toda a área
				Vfx.colossal_meteor(host, center2, 1.1, rr, blast * 1.5, col)
				_later(p, 1.1, func() -> void:
					if not is_instance_valid(p):
						return
					for e in in_radius(tree, center2, rr):
						hit(p, e, m, center2, {"knock": 3.5}))
			else:
				Vfx.marker(host, center2, col, rr, float(sk["spread_t"]) + 0.9)
				for k in int(sk["count"]):
					var off2 := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).limit_length(1.0) * rr * 0.8
					var at2 := center2 + off2
					var fall2 := 0.85
					var start2 := 0.1 + float(sk["spread_t"]) * float(k) / int(sk["count"])
					_later(p, start2, func() -> void:
						Vfx.meteor(host, at2, fall2, blast))
					_later(p, start2 + fall2, func() -> void:
						if not is_instance_valid(p):
							return
						Sfx.play("sk_explosion", -4.0, randf_range(0.8, 1.1))
						Fx.shake(p, 0.3)
						for e in in_radius(tree, at2, blast):
							hit(p, e, m, at2, {"knock": 2.0}))
		"fissure":
			var rf := area(sk)
			var dur := float(sk["dur"])
			var every3 := float(sk["every"])
			var burn := float(sk["burn"]) * level_mult(lvl)
			_later(p, 0.3, func() -> void:
				if not is_instance_valid(p):
					return
				var o := p.global_position
				Vfx.fissure(host, o, rf, dur)
				Fx.shake(p, 0.7)
				Fx.hitstop(p, 0.06)
				Sfx.play("sk_explosion", 0.0, 0.6)
				for e in in_radius(tree, o, rf):
					hit(p, e, m, o, {"stun": float(sk["stun"]), "knock": 2.5})
				for k in int(dur / every3):
					_later(p, every3 * (k + 1), func() -> void:
						if not is_instance_valid(p):
							return
						for e in in_radius(tree, o, rf * 0.85):
							hit(p, e, burn, o)))
		"maelstrom":
			var rm := area(sk)
			var ticks2 := int(sk["ticks"])
			var every2 := float(sk["every"])
			var whirl := _whirl(host, pos, rm, col, every2 * ticks2)
			Vfx.emit(host, pos + Vector3(0, 0.3, 0), {"tex": "smoke", "add": false, "shot": false, "amount": 50, "life": 0.9, "dur": every2 * ticks2,
					"size": [1.0, 2.2], "shape": "ring", "r": rm * 0.9, "r_in": rm * 0.3, "vel": [2.0, 5.0], "dir": Vector3.UP, "spread": 15.0,
					"gravity": Vector3(0, -4, 0), "colors": Vfx.WATER, "spin": 90.0})
			Vfx.splash(host, pos, 2.0)
			for k in ticks2:
				_later(p, 0.1 + every2 * k, func() -> void:
					if not is_instance_valid(p):
						return
					var o := whirl.global_position if is_instance_valid(whirl) else p.global_position
					for e in in_radius(tree, o, rm):
						var to := flat(e.global_position - o)
						if to.length() > 1.5:
							e.pull_to(o + to * 0.75, every2 * 0.8)
						if k == 0:
							e.lift(every2 * ticks2 * 0.6)
						hit(p, e, m, o, {"vuln": float(sk["vuln"]), "vuln_dur": float(sk["vuln_dur"])}))
		# ------------------------------------------------------------- Guerreiro
		"arc":
			var ra2 := area(sk)
			var half2 := float(sk["half"])
			p.attack_visual()
			Fx.slash(host, pos + Vector3(0, 1.0, 0), _ang(dir), ra2, rad_to_deg(half2 * 2.0), col, 1.3, 0.24)
			Fx.slash(host, pos + Vector3(0, 0.8, 0), _ang(dir), ra2 * 0.7, rad_to_deg(half2 * 2.0), Color(1, 1, 1), 0.6, 0.2, true)
			Vfx.sparks(host, pos + dir * ra2 * 0.7 + Vector3(0, 1.0, 0), 14, 6.0)
			for e in in_cone(tree, pos, dir, ra2, cos(half2)):
				hit(p, e, m, pos, {"stun": float(sk["stun"])})
		"charge":
			var cdist := float(sk["dist"])
			var cend := pos + dir * cdist
			p.start_dash(dir, cdist, 0.25)
			Fx.streak(host, hand, cend + Vector3(0, 1.1, 0), col, 1.4, 0.35)
			Vfx.emit(host, pos + Vector3(0, 0.3, 0), {"tex": "smoke", "add": false, "amount": 18, "life": 0.7, "size": [0.8, 1.6],
					"shape": "box", "box": Vector3(0.6, 0.2, 0.6) + (dir * cdist * 0.5).abs(), "vel": [0.5, 1.5], "colors": Vfx.SMOKE})
			_later(p, 0.25, func() -> void:
				if not is_instance_valid(p):
					return
				for e in enemies(tree):
					if seg_dist(e.global_position, pos, cend) <= 2.0 + e.radius:
						hit(p, e, m, pos, {"stun": float(sk["stun"]), "knock": 2.5})
				Vfx.shockwave(host, p.global_position, col, 3.5, 0.35)
				Fx.shake(p, 0.3))
		"roar":
			var rr2 := area(sk)
			p.spin_visual()
			Vfx.shockwave(host, pos, col, rr2, 0.5)
			Vfx.shockwave(host, pos, Color(1, 1, 1), rr2 * 0.6, 0.35)
			Fx.ring(host, pos + Vector3(0, 1.6, 0), col, rr2 * 0.5, 0.4, 0.12)
			Fx.light_flash(host, pos + Vector3(0, 2, 0), col, 5.0, 12.0, 0.4)
			Fx.shake(p, 0.4)
			for e in in_radius(tree, pos, rr2):
				hit(p, e, m, pos, _opts(sk))
		"wave":
			var wlen := float(sk["len"]) * GameData.AREA_MULT
			var ww := float(sk["width"]) * GameData.AREA_MULT
			var wtime := float(sk["time"])
			p.attack_visual()
			var hitw := {}
			for k in 8:
				_later(p, wtime * k / 8.0, func() -> void:
					var front := pos + dir * wlen * (k + 1) / 8.0
					Fx.slash(host, front + Vector3(0, 1.0, 0), _ang(dir), ww * 0.7, 130.0, col, 1.0, 0.16)
					for e in enemies(tree):
						if hitw.has(e):
							continue
						if seg_dist(e.global_position, pos, front) <= ww * 0.5 + e.radius:
							hitw[e] = true
							hit(p, e, m, pos, {"knock": 1.5}))
		"riposte":
			var rp := area(sk)
			var rdur := float(sk["dur"])
			p.invuln_t = rdur
			p.cc_immune_t = rdur
			Vfx.golden_shield(p, rdur, col)
			_later(p, rdur, func() -> void:
				if not is_instance_valid(p):
					return
				var o := p.global_position
				p.spin_visual()
				Fx.slash(host, o + Vector3(0, 1.0, 0), _ang(p.facing), rp, 360.0, col, 1.3, 0.3)
				Vfx.shockwave(host, o, col, rp, 0.4)
				Vfx.sparks(host, o + Vector3(0, 1.0, 0), 30, 9.0)
				Fx.hitstop(p, 0.06)
				Sfx.play("sk_slash", -2.0, 0.9)
				for e in in_radius(tree, o, rp):
					hit(p, e, m, o, {"knock": 2.0}))
		"hook":
			var far: Enemy = null
			var fd := 0.0
			for e in in_cone(tree, pos, dir, float(sk["range"]), cos(0.5)):
				var dd2 := flat(e.global_position - pos).length()
				if dd2 > fd:
					fd = dd2
					far = e
			if far == null:
				Fx.streak(host, hand, hand + dir * float(sk["range"]), col, 0.25, 0.3)
			else:
				var fe := far
				Fx.streak(host, hand, fe.global_position + Vector3(0, 1.0, 0), col, 0.3, 0.45)
				Vfx.sparks(host, fe.global_position + Vector3(0, 1.0, 0), 12, 5.0)
				fe.pull_to(pos + dir * (fe.radius + 1.4), 0.3)
				_later(p, 0.3, func() -> void:
					if is_instance_valid(p) and is_instance_valid(fe):
						hit(p, fe, m, p.global_position, {"stun": float(sk["stun"])})
						Fx.shake(p, 0.2))
		# ------------------------------------------------------------- Lanceiro
		"launch":
			var rl := area(sk)
			p.attack_visual()
			Fx.slash(host, pos + Vector3(0, 0.6, 0) + dir * 0.6, _ang(dir), rl, rad_to_deg(float(sk["half"]) * 2.0), col, 1.1, 0.25)
			Vfx.emit(host, pos + dir * rl * 0.5 + Vector3(0, 0.3, 0), {"tex": "dot", "amount": 24, "life": 0.6, "size": [0.08, 0.16],
					"shape": "ring", "r": rl * 0.5, "r_in": 0.2, "vel": [5.0, 9.0], "dir": Vector3.UP, "spread": 15.0,
					"colors": [[0, Color(col, 0.95)], [1, Color(col, 0.0)]]})
			for e in in_cone(tree, pos, dir, rl, cos(float(sk["half"]))):
				hit(p, e, m, pos, {"lift": float(sk["lift"]), "stun": float(sk["lift"])})
		"javelin":
			p.attack_visual()
			var jv := Projectile.new()
			jv.player = p
			jv.dir = dir
			jv.speed = float(sk["speed"])
			jv.life = float(sk["life"])
			jv.mult = m
			jv.pierce = true
			jv.slow = float(sk["slow"])
			jv.slow_dur = float(sk["slow_dur"])
			jv.visual = "spear"
			jv.color = col
			host.add_child(jv)
			jv.global_position = hand + dir * 0.8
			Fx.streak(host, hand, hand + dir * 3.0, col, 0.3, 0.2)
		"wind_wall":
			var rw := area(sk)
			p.add_shield(p.max_hp * shield_pct(sk, lvl), float(sk["dur"]), col)
			p.spin_visual()
			Vfx.emit(host, pos + Vector3(0, 0.4, 0), {"tex": "smoke", "add": false, "amount": 34, "life": 0.7, "size": [0.9, 1.8], "shape": "ring",
					"r": rw * 0.6, "r_in": rw * 0.3, "vel": [3.0, 6.0], "dir": Vector3.UP, "spread": 40.0,
					"colors": [[0, Color(0.85, 1.0, 0.95, 0.6)], [1, Color(0.7, 1.0, 0.9, 0.0)]], "spin": 120.0})
			Vfx.shockwave(host, pos, col, rw, 0.45)
			for e in in_radius(tree, pos, rw):
				e.knockback(pos, float(sk["knock"]))
		"sweep":
			var rsw := area(sk)
			p.spin_visual()
			Fx.slash(host, pos + Vector3(0, 0.7, 0), _ang(dir), rsw, 190.0, col, 1.4, 0.32)
			Fx.slash(host, pos + Vector3(0, 0.5, 0), _ang(dir), rsw * 0.8, 190.0, Color(1, 1, 1), 0.5, 0.28)
			Vfx.emit(host, pos + dir * rsw * 0.5 + Vector3(0, 0.2, 0), {"tex": "smoke", "add": false, "amount": 20, "life": 0.6, "size": [0.7, 1.4],
					"shape": "ring", "r": rsw * 0.8, "r_in": rsw * 0.4, "vel": [1.0, 2.5], "colors": Vfx.SMOKE, "spin": 60.0})
			for e in in_cone(tree, pos, dir, rsw, 0.0):
				hit(p, e, m, pos, {"slow": float(sk["slow"]), "slow_dur": float(sk["slow_dur"]), "knock": 1.2})
		"crush":
			var rcr := area(sk)
			var cat := pos + dir * float(sk["range"])
			p.attack_visual()
			_later(p, 0.18, func() -> void:
				if not is_instance_valid(p):
					return
				Vfx.ground_slam(host, cat, rcr, col)
				Fx.streak(host, cat + Vector3(0, 6, 0), cat, col, 0.6, 0.18)
				Fx.shake(p, 0.4)
				Fx.hitstop(p, 0.05)
				Sfx.play("sk_slam", -2.0, 0.9)
				for e in in_radius(tree, cat, rcr):
					hit(p, e, m, cat, _opts(sk)))
		"leech":
			var rle := area(sk)
			p.attack_visual()
			Fx.streak(host, hand, hand + dir * rle, col, 0.7, 0.25)
			for e in in_cone(tree, pos, dir, rle, cos(float(sk["half"]))):
				hit(p, e, m, pos, {"heal": float(sk["heal"])})
				Fx.streak(host, e.global_position + Vector3(0, 1.0, 0), hand, Color(1.0, 0.4, 0.45), 0.2, 0.5)
			Vfx.heal_pulse(host, pos)
		"blitz":
			var bt := _closest(tree, pos, float(sk["range"]))
			if bt == null:
				p.start_dash(dir, 6.0, 0.12)
			else:
				var bdir := flat(bt.global_position - pos).normalized()
				var bdest := bt.global_position - bdir * (bt.radius + 1.3)
				Vfx.bolt(host, hand, Vector3(bdest.x, hand.y, bdest.z), col, 0.6, 0.3, 2)
				p.global_position = Vector3(bdest.x, pos.y, bdest.z)
				p.face_dir(bdir)
				p.attack_visual()
				Vfx.shockwave(host, bt.global_position, col, 3.0, 0.3)
				Fx.hitstop(p, 0.05)
				hit(p, bt, m, p.global_position, {"knock": float(sk["knock"]), "stun": 0.6})
		"finisher":
			var flen2 := float(sk["len"]) * GameData.AREA_MULT
			var fwid := float(sk["width"]) * GameData.AREA_MULT
			var fend := pos + dir * flen2
			p.attack_visual()
			Vfx.cinematic_dim(host, 0.6, 0.35)
			Vfx._beam_column(host, pos + dir * 1.5, 0.8, Color(col, 0.9), 0.4)
			Fx.streak(host, hand, fend + Vector3(0, 1.1, 0), col, 1.6, 0.4)
			Fx.streak(host, hand, fend + Vector3(0, 1.1, 0), Color(1, 1, 1), 0.6, 0.3)
			Fx.shake(p, 0.5)
			Fx.hitstop(p, 0.07)
			for e in enemies(tree):
				if seg_dist(e.global_position, pos, fend) <= fwid * 0.5 + e.radius:
					var fe2 := e
					hit(p, fe2, m, pos, {"vs_vuln": 2.0, "knock": 2.0})
					Vfx.sparks(host, fe2.global_position + Vector3(0, 1.0, 0), 14, 7.0)
					if not fe2.alive:
						p.skill_cd[i] = maxf(0.0, p.skill_cd[i] - 3.0)
		# ------------------------------------------------------------- Mago
		"ice_block":
			var rib := area(sk)
			var idur := float(sk["dur"])
			p.invuln_t = idur
			p.cc_immune_t = idur
			p.heal(p.max_hp * shield_pct(sk, lvl))
			var block := Toon.glow_part(Toon.box(Vector3(1.6, 2.6, 1.6)), Color(0.7, 0.95, 1.0), Vector3(0, 1.3, 0), 0.45, true)
			p.add_child(block)
			Vfx.emit(host, pos + Vector3(0, 0.5, 0), {"tex": "dot", "amount": 30, "life": 0.8, "size": [0.06, 0.14], "shape": "ring",
					"r": 1.2, "r_in": 0.4, "vel": [1.0, 3.0], "dir": Vector3.UP, "colors": [[0, Color(0.9, 1.0, 1.0, 0.9)], [1, Color(0.6, 0.9, 1.0, 0.0)]]})
			_later(p, idur, func() -> void:
				if is_instance_valid(block):
					block.queue_free()
				if not is_instance_valid(p):
					return
				var o := p.global_position
				for k in 10:
					var a3 := TAU * k / 10.0
					_ice_spike(host, o + Vector3(cos(a3), 0, sin(a3)) * rib * 0.7, col)
				Vfx.shockwave(host, o, col, rib, 0.4)
				Sfx.play("sk_ice", -2.0, 0.9)
				for e in in_radius(tree, o, rib):
					hit(p, e, m, o, {"stun": float(sk["stun"])}))
		"immolate":
			var rim := area(sk)
			var iat := pos + flat(point - pos).limit_length(float(sk["range"]))
			var spots2: Array[Vector3] = []
			for e in in_radius(tree, iat, rim):
				if spots2.size() < int(sk["count"]):
					spots2.append(e.global_position)
			while spots2.size() < 3:
				spots2.append(iat + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).limit_length(1.0) * rim * 0.7)
			var ievery := float(sk["every"])
			var iticks := int(sk["ticks"])
			Vfx.marker(host, iat, col, rim, ievery * iticks + 0.3)
			for sp2 in spots2:
				var spot := sp2
				Vfx.ground_mark(host, spot, "scorch", 3.0, ievery * iticks + 2.0)
				_later(p, 0.15, func() -> void:
					Vfx.fire_column(host, spot, 6.0, ievery * iticks, 0.9))
				for k in iticks:
					_later(p, 0.2 + ievery * k, func() -> void:
						if not is_instance_valid(p):
							return
						for e in in_radius(tree, spot, 1.8):
							hit(p, e, m, spot))
		"flame_nova":
			var rfn := area(sk)
			var fburn := float(sk["burn"]) * level_mult(lvl)
			Vfx.explosion(host, pos, rfn * 0.6, false)
			Vfx.shockwave(host, pos, col, rfn, 0.45)
			Fx.light_flash(host, pos + Vector3(0, 1.5, 0), col, 6.0, 12.0, 0.4)
			Fx.shake(p, 0.35)
			var burned := in_radius(tree, pos, rfn)
			for e in burned:
				hit(p, e, m, pos, {"knock": float(sk["knock"])})
			for k in 4:
				_later(p, 0.5 * (k + 1), func() -> void:
					if not is_instance_valid(p):
						return
					for e in burned:
						if is_instance_valid(e) and e.alive:
							Vfx.sparks(host, e.global_position + Vector3(0, 0.8, 0), 4, 2.0)
							hit(p, e, fburn, e.global_position))
		"mana_shield":
			var spend := p.mp * shield_pct(sk, lvl)
			p.mp -= spend
			p.add_shield(spend * 3.0, float(sk["dur"]), col)
			Vfx.magic_rune_circle(host, pos, 2.2, Color(col, 0.9), 1.2, 1.2)
			Vfx.shockwave(host, pos, col, 3.0, 0.4)
			Fx.damage_number(host, pos + Vector3(0, 2.8, 0), "Escudo %d" % int(spend * 3.0), col)
		"soul_drain":
			p.attack_visual()
			for k in int(sk["count"]):
				var sd := Projectile.new()
				sd.player = p
				sd.dir = dir.rotated(Vector3.UP, (float(k) / maxf(1.0, float(sk["count"]) - 1.0) - 0.5) * 1.2)
				sd.speed = float(sk["speed"])
				sd.life = 1.4
				sd.mult = m
				sd.homing = true
				sd.visual = "orb"
				sd.color = col
				sd.extra = {"mana": float(sk["mana"])}
				sd._delay = 0.06 * k
				host.add_child(sd)
				sd.global_position = hand + sd.dir * 0.6
			Vfx.shadow_puff(host, hand, 0.6, col)
		"tornado":
			var rt := area(sk)
			var tlen2 := float(sk["len"])
			var tticks := int(sk["ticks"])
			var tevery := float(sk["every"])
			var ttotal := tticks * tevery
			var tw3 := _whirl(host, pos + dir * 2.0, rt, col, ttotal)
			var tw_move := tw3.create_tween()
			tw_move.tween_property(tw3, "global_position", pos + dir * (2.0 + tlen2), ttotal)
			Vfx.emit(tw3, Vector3(0, 0.5, 0), {"tex": "flame", "shot": false, "local": true, "amount": 40, "life": 0.8, "dur": ttotal,
					"size": [0.8, 1.8], "shape": "ring", "r": rt * 0.5, "r_in": rt * 0.2, "vel": [3.0, 7.0], "dir": Vector3.UP, "spread": 10.0,
					"colors": Vfx.FIRE, "spin": 200.0})
			Vfx.cinematic_dim(host, 0.8, 0.3)
			for k in tticks:
				_later(p, tevery * (k + 1), func() -> void:
					if not is_instance_valid(p) or not is_instance_valid(tw3):
						return
					var o := tw3.global_position
					for e in in_radius(tree, o, rt):
						var to2 := flat(e.global_position - o)
						if to2.length() > 1.2:
							e.pull_to(o + to2 * 0.6, tevery * 0.8)
						hit(p, e, m, o))
		# ------------------------------------------------------------- Arqueira
		"backstep":
			var bsd := float(sk["dist"])
			var rbs := area(sk)
			p.start_dash(-dir, bsd, 0.22)
			p.invuln_t = 0.3
			p.attack_visual()
			for k in 5:
				var bd2 := dir.rotated(Vector3.UP, (k / 4.0 - 0.5) * float(sk["half"]) * 2.0)
				Fx.streak(host, hand, hand + bd2 * rbs, col, 0.15, 0.25)
			Fx.burst(host, pos + Vector3(0, 0.3, 0), Color(0.7, 0.6, 0.45), 14, 4.0, 0.1)
			for e in in_cone(tree, pos, dir, rbs, cos(float(sk["half"]))):
				hit(p, e, m, pos, {"knock": float(sk["knock"])})
		"focus":
			p.crit_bonus = buff_amount(sk, lvl)
			p.crit_bonus_t = float(sk["dur"])
			p.add_dmg_buff(0.15, float(sk["dur"]), col)
			Vfx.magic_rune_circle(host, pos, 1.8, Color(col, 0.85), float(sk["dur"]) * 0.3, 0.6)
			Fx.ring(host, pos + Vector3(0, 0.1, 0), col, 3.0, 0.5)
			Fx.burst(host, pos + Vector3(0, 1.4, 0), col, 20, 3.0, 0.08, 0.8, 2.0)
		"blast_arrow":
			p.attack_visual()
			var brange := float(sk["speed"]) * float(sk["life"])
			var bfirst: Enemy = null
			var bbest := brange
			for e in enemies(tree):
				var along := flat(e.global_position - pos).dot(dir)
				if along > 0.0 and along < bbest and seg_dist(e.global_position, pos, pos + dir * brange) <= 1.0 + e.radius:
					bbest = along
					bfirst = e
			var bat := pos + dir * bbest
			if bfirst != null:
				bat = bfirst.global_position
			var bblast := float(sk["explode"]) * GameData.AREA_MULT
			Fx.streak(host, hand, bat + Vector3(0, 1.0, 0), col, 0.3, 0.2)
			_later(p, bbest / float(sk["speed"]), func() -> void:
				if not is_instance_valid(p):
					return
				Vfx.explosion(host, bat, bblast * 0.7)
				Fx.shake(p, 0.3)
				for e in in_radius(tree, bat, bblast):
					hit(p, e, m, bat, {"knock": 1.5})
				for k in int(sk["frags"]):
					var fr := Projectile.new()
					fr.player = p
					fr.dir = Vector3.FORWARD.rotated(Vector3.UP, TAU * k / float(sk["frags"]))
					fr.speed = 18.0
					fr.life = 0.35
					fr.mult = m * 0.35
					fr.visual = "arrow"
					fr.color = col
					host.add_child(fr)
					fr.global_position = bat + Vector3(0, 1.0, 0) + fr.dir * (bblast * 0.5))
		"snipe":
			var sdir := dir
			Vfx.magic_rune_circle(host, pos, 1.4, Color(col, 0.9), float(sk["charge"]) + 0.2, 2.0)
			Fx.streak(host, hand, hand + sdir * 20.0, Color(col, 0.5), 0.05, float(sk["charge"]))
			_later(p, float(sk["charge"]), func() -> void:
				if not is_instance_valid(p):
					return
				p.attack_visual()
				var sn := Projectile.new()
				sn.player = p
				sn.dir = sdir
				sn.speed = float(sk["speed"])
				sn.life = float(sk["life"])
				sn.mult = m
				sn.visual = "bigarrow"
				sn.color = col
				sn.extra = {"low": float(sk["low"]), "crit": true, "knock": 2.5}
				host.add_child(sn)
				sn.global_position = p.global_position + Vector3(0, 1.1, 0) + sdir * 0.8
				Fx.shake(p, 0.2)
				Sfx.play("arrow", 0.0, 0.7))


static func _opts(sk: Dictionary) -> Dictionary:
	var o := {}
	for key in ["knock", "vuln", "vuln_dur", "stun"]:
		if sk.has(key):
			o[key] = sk[key]
	return o


## Escudo de Conchas: quando quebra, explode em gotas cortantes.
static func shell_burst(p: Player, b: Dictionary) -> void:
	var host := p.get_parent()
	var o := p.global_position
	var col: Color = b["color"]
	var r := float(b["r"])
	Vfx.splash(host, o, 2.0)
	Vfx.shockwave(host, o, col, r * 1.2, 0.45)
	Sfx.play("sk_ice", -3.0, 1.2)
	for e in in_radius(p.get_tree(), o, r):
		hit(p, e, float(b["mult"]), o)


static func _vine(host: Node, at: Vector3, col: Color, t: float) -> void:
	var v := Node3D.new()
	host.add_child(v)
	v.global_position = at
	for k in 3:
		var seg := Toon.part(Toon.cyl(0.05, 0.14, 1.2, 6), Color(0.28, 0.5, 0.15).lerp(col, 0.3), Vector3(0, 0.5, 0), 0.03)
		seg.rotation = Vector3(randf_range(-0.5, 0.5), TAU * k / 3.0, randf_range(-0.5, 0.5))
		v.add_child(seg)
	v.scale = Vector3(1, 0.05, 1)
	var tw := v.create_tween()
	tw.tween_property(v, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK)
	tw.tween_interval(maxf(0.1, t - 0.4))
	tw.tween_property(v, "scale", Vector3(1, 0.05, 1), 0.2)
	tw.tween_callback(v.queue_free)


static func _bark(p: Player, col: Color, t: float) -> void:
	var node := Node3D.new()
	p.add_child(node)
	for k in 8:
		var a := TAU * k / 8.0
		var plank := Toon.part(Toon.box(Vector3(0.35, 1.5, 0.12)), Color(0.45, 0.3, 0.15), Vector3(cos(a) * 0.85, 1.0, sin(a) * 0.85), 0.03)
		plank.rotation.y = -a + PI / 2.0
		node.add_child(plank)
	node.add_child(Toon.glow_part(Toon.cyl(1.1, 1.1, 0.02, 24), col, Vector3(0, 0.05, 0), 0.4, true))
	node.scale = Vector3(1, 0.05, 1)
	var tw := node.create_tween()
	tw.tween_property(node, "scale", Vector3.ONE, 0.2)
	tw.tween_interval(maxf(0.1, t - 0.4))
	tw.tween_property(node, "scale", Vector3(1, 0.05, 1), 0.2)
	tw.tween_callback(node.queue_free)


static func _shoot_at(p: Player, host: Node, from: Vector3, e: Enemy, m: float, visual: String, col: Color) -> void:
	var pr := Projectile.new()
	pr.player = p
	pr.dir = flat(e.global_position - from).normalized()
	pr.speed = 30.0
	pr.life = 0.7
	pr.mult = m
	pr.visual = visual
	pr.color = col
	host.add_child(pr)
	pr.global_position = from


static func _closest(tree: SceneTree, o: Vector3, r: float) -> Enemy:
	var best: Enemy = null
	var bd := r
	for e in enemies(tree):
		var d := flat(e.global_position - o).length()
		if d < bd:
			bd = d
			best = e
	return best


static func _turret(p: Player, host: Node, at: Vector3, m: float, rng: float, dur: float, every: float, col: Color) -> void:
	var t := Node3D.new()
	host.add_child(t)
	t.global_position = at
	t.add_child(Toon.part(Toon.cyl(0.55, 0.7, 0.4, 10), Color(0.32, 0.34, 0.38), Vector3(0, 0.2, 0), 0.03))
	var head := Node3D.new()
	head.position.y = 0.75
	t.add_child(head)
	head.add_child(Toon.part(Toon.box(Vector3(0.6, 0.45, 0.6)), Color(0.75, 0.55, 0.2), Vector3.ZERO, 0.03))
	var barrel := Toon.part(Toon.cyl(0.09, 0.09, 0.8, 8), Color(0.2, 0.2, 0.24), Vector3(0, 0.05, -0.5), 0.02)
	barrel.rotation_degrees.x = 90.0
	head.add_child(barrel)
	head.add_child(Toon.glow_part(Toon.sphere(0.1, 8), col, Vector3(0, 0.3, 0)))
	t.scale = Vector3.ONE * 0.1
	t.create_tween().tween_property(t, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK)
	var timer := Timer.new()
	timer.wait_time = every
	timer.autostart = true
	t.add_child(timer)
	var state := {"left": dur}
	timer.timeout.connect(func() -> void:
		state["left"] = float(state["left"]) - every
		if float(state["left"]) <= 0.0 or not is_instance_valid(p):
			Fx.burst(host, at + Vector3(0, 0.7, 0), Color(0.5, 0.5, 0.55), 14, 3.0, 0.1)
			t.queue_free()
			return
		var e := _closest(t.get_tree(), at, rng)
		if e == null:
			return
		var to := flat(e.global_position - at)
		head.rotation.y = atan2(-to.x, -to.z)
		Sfx.play("arrow", -12.0, 1.4)
		_shoot_at(p, host, at + Vector3(0, 0.8, 0) + to.normalized() * 0.6, e, m, "bolt", col))


static func _drone(p: Player, amount: float, dur: float, col: Color) -> void:
	var d := Node3D.new()
	p.add_child(d)
	d.position = Vector3(0.9, 2.6, 0.4)
	d.add_child(Toon.part(Toon.box(Vector3(0.5, 0.16, 0.5)), Color(0.85, 0.88, 0.92), Vector3.ZERO, 0.02))
	for k in 4:
		var a := TAU * k / 4.0 + PI / 4.0
		d.add_child(Toon.glow_part(Toon.cyl(0.15, 0.15, 0.03, 10), col, Vector3(cos(a) * 0.34, 0.1, sin(a) * 0.34), 0.7, true))
	d.add_child(Toon.glow_part(Toon.sphere(0.1, 8), Color(0.4, 1.0, 0.5), Vector3(0, -0.12, 0)))
	var bob := d.create_tween().set_loops()
	bob.tween_property(d, "position:y", 2.85, 0.5).set_trans(Tween.TRANS_SINE)
	bob.tween_property(d, "position:y", 2.6, 0.5).set_trans(Tween.TRANS_SINE)
	var timer := Timer.new()
	timer.wait_time = 0.5
	timer.autostart = true
	d.add_child(timer)
	var state := {"left": dur}
	timer.timeout.connect(func() -> void:
		state["left"] = float(state["left"]) - 0.5
		if float(state["left"]) <= 0.0:
			d.queue_free()
			return
		if p.hp < p.max_hp:
			p.heal(amount)
			Fx.streak(p.get_parent(), d.global_position, p.global_position + Vector3(0, 1.0, 0), Color(0.4, 1.0, 0.5), 0.12, 0.2)
		p.speed_buff = maxf(p.speed_buff, 0.0))


static func _jelly(p: Player, m: float, rng: float, dur: float, every: float, col: Color) -> void:
	var host := p.get_parent()
	var j := Node3D.new()
	host.add_child(j)
	j.global_position = p.global_position + Vector3(1.2, 1.8, 0)
	var bell := Toon.glow_part(Toon.sphere(0.5, 14), col, Vector3.ZERO, 0.65, true)
	bell.scale = Vector3(1, 0.7, 1)
	j.add_child(bell)
	for k in 5:
		var a := TAU * k / 5.0
		j.add_child(Toon.glow_part(Toon.cyl(0.03, 0.06, 0.9, 5), col.lightened(0.3), Vector3(cos(a) * 0.25, -0.6, sin(a) * 0.25), 0.6, true))
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = 1.4
	l.omni_range = 4.0
	j.add_child(l)
	Fx.budget_light(l)
	var timer := Timer.new()
	timer.wait_time = every
	timer.autostart = true
	j.add_child(timer)
	var state := {"left": dur, "t": 0.0}
	timer.timeout.connect(func() -> void:
		state["left"] = float(state["left"]) - every
		if float(state["left"]) <= 0.0 or not is_instance_valid(p):
			Fx.burst(host, j.global_position, col, 16, 3.0, 0.1)
			j.queue_free()
			return
		var e := _closest(j.get_tree(), p.global_position, rng + 3.0)
		var goal := p.global_position + Vector3(1.2, 1.8, 0)
		if e != null:
			goal = e.global_position + Vector3(0.8, 1.8, 0.8)
		j.create_tween().tween_property(j, "global_position", goal, every * 0.8).set_trans(Tween.TRANS_SINE)
		if e != null and flat(e.global_position - j.global_position).length() < rng:
			var top := e.global_position + Vector3(0, float(e.data["height"]), 0)
			Vfx.bolt(host, j.global_position, top, col, 0.3, 0.25, 1)
			Sfx.play("sk_thunder", -14.0, 1.6)
			hit(p, e, m, j.global_position, {"slow": 0.35, "slow_dur": 1.5}))


static func _whirl(host: Node, at: Vector3, r: float, col: Color, t: float) -> Node3D:
	var w := Node3D.new()
	host.add_child(w)
	w.global_position = at
	for k in 4:
		var ring := Toon.glow_part(Toon.cyl(r * (0.35 + 0.2 * k), r * (0.25 + 0.2 * k), 0.8 + k * 0.7, 24), col.lerp(Color(1, 1, 1), 0.15 * k) * 0.6, Vector3(0, 0.4 + k * 0.6, 0), 0.1 - k * 0.015, true)
		w.add_child(ring)
	var p := CPUParticles3D.new()
	p.amount = 60
	p.lifetime = 1.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_radius = r
	p.emission_ring_inner_radius = r * 0.3
	p.emission_ring_height = 0.2
	p.emission_ring_axis = Vector3.UP
	p.direction = Vector3.UP
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 6.0
	p.orbit_velocity_min = 0.6
	p.orbit_velocity_max = 1.0
	p.gravity = Vector3.ZERO
	var sm := SphereMesh.new()
	sm.radius = 0.12
	sm.height = 0.24
	sm.radial_segments = 6
	sm.rings = 3
	sm.material = Toon.glow_mat(Color(0.8, 0.95, 1.0), 0.9, true)
	p.mesh = sm
	w.add_child(p)
	var spin := w.create_tween().set_loops()
	spin.tween_property(w, "rotation:y", TAU, 0.6).from(0.0)
	Fx.light_flash(host, at + Vector3(0, 2, 0), col, 1.5, 10.0, t)
	host.get_tree().create_timer(t + 0.2).timeout.connect(w.queue_free)
	return w


# ------------------------------------------------------------- peças de efeito

static func _flame_cone(host: Node, at: Vector3, dir: Vector3, r: float, half: float, col: Color) -> void:
	for layer in 2:
		var p := CPUParticles3D.new()
		p.one_shot = true
		p.amount = 70 if layer == 0 else 40
		p.lifetime = 0.6
		p.explosiveness = 0.7
		p.direction = dir
		p.spread = rad_to_deg(half) * (1.0 if layer == 0 else 0.7)
		p.flatness = 0.7
		p.initial_velocity_min = r * 1.1
		p.initial_velocity_max = r * 1.9
		p.damping_min = r * 1.2
		p.damping_max = r * 1.8
		p.gravity = Vector3(0, 3.0, 0)
		var curve := Curve.new()
		curve.add_point(Vector2(0, 0.4))
		curve.add_point(Vector2(0.25, 1.0))
		curve.add_point(Vector2(1, 0))
		p.scale_amount_curve = curve
		p.scale_amount_min = 1.0
		p.scale_amount_max = 2.0
		var sm := SphereMesh.new()
		sm.radius = 0.38 if layer == 0 else 0.22
		sm.height = sm.radius * 2.0
		sm.radial_segments = 6
		sm.rings = 3
		sm.material = Toon.glow_mat(col if layer == 0 else Color(1.0, 0.9, 0.5), 0.85, true)
		p.mesh = sm
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		host.add_child(p)
		p.global_position = at
		p.emitting = true
		host.get_tree().create_timer(1.3).timeout.connect(p.queue_free)


static func _falling(host: Node, target: Vector3, visual: String, col: Color, delay: float) -> void:
	var node := Node3D.new()
	host.add_child(node)
	var start := target + Vector3(0, 22, 0)
	if visual == "meteor":
		start = target + Vector3(-9, 20, -9)
		node.add_child(Toon.glow_part(Toon.sphere(1.3, 14), col, Vector3.ZERO, 0.9, true))
		node.add_child(Toon.glow_part(Toon.sphere(0.8, 12), Color(1, 0.9, 0.6)))
		var p := CPUParticles3D.new()
		p.amount = 40
		p.lifetime = 0.5
		p.local_coords = false
		p.spread = 180.0
		p.initial_velocity_max = 1.0
		p.gravity = Vector3.ZERO
		var sm := SphereMesh.new()
		sm.radius = 0.5
		sm.height = 1.0
		sm.radial_segments = 6
		sm.rings = 3
		sm.material = Toon.glow_mat(col, 0.8, true)
		p.mesh = sm
		node.add_child(p)
	else:
		var kit := ModelKit.load_kit("loot_sword", 0.01)
		if kit != null:
			kit.root.scale = Vector3.ONE * 4.0
			kit.root.rotation_degrees.x = 180.0
			kit.root.position.y = 2.0
			node.add_child(kit.root)
		node.add_child(Toon.glow_part(Toon.cyl(0.3, 0.3, 30.0, 10), col, Vector3(0, 15, 0), 0.35, true))
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = 3.0
	l.omni_range = 8.0
	node.add_child(l)
	Fx.budget_light(l)
	node.global_position = start
	var tw := node.create_tween()
	tw.tween_property(node, "global_position", target + Vector3(0, 0.5, 0), delay).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(node.queue_free)


static func _spike(host: Node, at: Vector3, col: Color) -> void:
	var s := Toon.part(Toon.cyl(0.0, 0.32, 2.4, 8), Color(0.82, 0.86, 0.92), Vector3.ZERO, 0.03)
	host.add_child(s)
	s.global_position = at + Vector3(0, -1.2, 0)
	s.rotation = Vector3(randf_range(-0.2, 0.2), 0, randf_range(-0.2, 0.2))
	Fx.burst(host, at + Vector3(0, 0.2, 0), Color(0.6, 0.5, 0.4), 8, 4.0, 0.08)
	Fx.disc(host, at + Vector3(0, 0.05, 0), col, 1.4, 0.4, 0.5)
	var tw := s.create_tween()
	tw.tween_property(s, "global_position:y", 1.0, 0.1).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.5)
	tw.tween_property(s, "global_position:y", -1.4, 0.25)
	tw.tween_callback(s.queue_free)


static func _ice_spike(host: Node, at: Vector3, col: Color) -> void:
	var s := Toon.glow_part(Toon.cyl(0.0, 0.3, 1.8, 6), Color(0.7, 0.95, 1.0), Vector3.ZERO, 0.85, true)
	host.add_child(s)
	s.global_position = at
	s.scale = Vector3(1, 0.05, 1)
	var tw := s.create_tween()
	tw.tween_property(s, "scale", Vector3.ONE, 0.12)
	tw.tween_interval(0.35)
	tw.tween_property(s, "scale", Vector3(1, 0.05, 1), 0.25)
	tw.tween_callback(s.queue_free)


static func _rain_tick(host: Node, center: Vector3, r: float, vis: String, col: Color) -> void:
	if vis == "lightning":
		var at := center + Vector3(randf_range(-r, r) * 0.5, 0, randf_range(-r, r) * 0.5)
		Fx.lightning(host, at + Vector3(randf_range(-2, 2), 16, randf_range(-2, 2)), at, col, 0.22)
		Fx.light_flash(host, at + Vector3(0, 3, 0), col, 8.0, 14.0, 0.25)
		Fx.ring(host, at + Vector3(0, 0.1, 0), col, r * 0.6, 0.25)
		Sfx.play("sk_thunder", -8.0, randf_range(0.9, 1.2))
	else:
		for k in 7:
			var a := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).limit_length(1.0) * r
			var at2 := center + a
			Fx.streak(host, at2 + Vector3(1.0, 6.0, 1.0), at2 + Vector3(0, 0.2, 0), col, 0.12, 0.18)
			Fx.burst(host, at2 + Vector3(0, 0.2, 0), Color(0.7, 0.6, 0.4), 3, 2.0, 0.05)


static func _trap(p: Player, host: Node, at: Vector3, r: float, m: float, stun: float, col: Color) -> void:
	var trap := Node3D.new()
	host.add_child(trap)
	trap.global_position = at
	trap.add_child(Toon.part(Toon.cyl(0.6, 0.7, 0.18, 12), Color(0.35, 0.25, 0.15), Vector3(0, 0.09, 0), 0.02))
	var core := Toon.glow_part(Toon.sphere(0.2, 8), col, Vector3(0, 0.25, 0))
	trap.add_child(core)
	for k in 6:
		var a := TAU * k / 6.0
		var tooth := Toon.part(Toon.cyl(0.0, 0.08, 0.35, 4), Color(0.85, 0.85, 0.9), Vector3(cos(a) * 0.55, 0.3, sin(a) * 0.55), 0.0)
		trap.add_child(tooth)
	var light := OmniLight3D.new()
	light.light_color = col
	light.light_energy = 1.5
	light.omni_range = 3.0
	light.position.y = 0.5
	trap.add_child(light)
	Fx.budget_light(light)
	var blink := trap.create_tween().set_loops()
	blink.tween_property(light, "light_energy", 0.2, 0.25)
	blink.tween_property(light, "light_energy", 1.5, 0.25)
	var timer := Timer.new()
	timer.wait_time = 0.1
	timer.autostart = true
	trap.add_child(timer)
	var state := {"t": 0.0, "done": false}
	timer.timeout.connect(func() -> void:
		if state["done"]:
			return
		state["t"] = float(state["t"]) + 0.1
		var tree := trap.get_tree()
		var near := false
		if float(state["t"]) > 0.4:
			for e in enemies(tree):
				if flat(e.global_position - at).length() < 1.6 + e.radius:
					near = true
					break
		if near or float(state["t"]) > 8.0:
			state["done"] = true
			Fx.ring(host, at + Vector3(0, 0.1, 0), col, r, 0.4, 0.1)
			Fx.disc(host, at + Vector3(0, 0.05, 0), col, r, 0.45, 0.3)
			Fx.burst(host, at + Vector3(0, 0.6, 0), col, 36, 9.0, 0.14)
			Fx.light_flash(host, at + Vector3(0, 1.5, 0), col, 8.0, 12.0, 0.4)
			Fx.shake(trap, 0.3)
			Sfx.play("sk_explosion", -2.0)
			if is_instance_valid(p):
				for e in in_radius(tree, at, r):
					hit(p, e, m, at, {"stun": stun})
			trap.queue_free())


## Torre Tesla: bobina no chão que solta raios nos inimigos perto até o tempo acabar.
static func _tesla(p: Player, host: Node, at: Vector3, m: float, rng: float, dur: float, every: float, n: int, col: Color) -> void:
	var t := Node3D.new()
	host.add_child(t)
	t.global_position = at
	t.add_child(Toon.part(Toon.cyl(0.55, 0.75, 0.35, 10), Color(0.3, 0.3, 0.34), Vector3(0, 0.18, 0), 0.03))
	t.add_child(Toon.part(Toon.cyl(0.14, 0.2, 2.2, 8), Color(0.75, 0.5, 0.25), Vector3(0, 1.4, 0), 0.03))
	for k in 4:
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.22
		tm.outer_radius = 0.34 - k * 0.02
		ring.mesh = tm
		ring.material_override = Toon.make(Color(0.8, 0.55, 0.3), 0.02)
		ring.position = Vector3(0, 0.8 + k * 0.4, 0)
		t.add_child(ring)
	var orb := Toon.glow_part(Toon.sphere(0.32, 14), Color(0.55, 0.8, 1.0), Vector3(0, 2.75, 0), 0.9, true)
	t.add_child(orb)
	var top := at + Vector3(0, 2.75, 0)
	Vfx.emit(t, top, {"tex": "dot", "shot": false, "local": true, "amount": 14, "life": 0.35, "dur": dur, "size": [0.05, 0.1],
			"shape": "sphere", "r": 0.4, "vel": [1.0, 3.0], "colors": Vfx.SPARK})
	Vfx.ground_slam(host, at, 2.0, col)
	t.scale = Vector3(1, 0.05, 1)
	t.create_tween().tween_property(t, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK)
	var timer := Timer.new()
	timer.wait_time = every
	timer.autostart = true
	t.add_child(timer)
	var state := {"left": dur}
	timer.timeout.connect(func() -> void:
		state["left"] = float(state["left"]) - every
		if float(state["left"]) <= 0.0 or not is_instance_valid(p):
			Vfx.sparks(host, top, 40, 9.0)
			Vfx.shockwave(host, at, col, 3.0, 0.3)
			t.queue_free()
			return
		var near: Array[Enemy] = []
		for e in enemies(t.get_tree()):
			if flat(e.global_position - at).length() <= rng:
				near.append(e)
		near.sort_custom(func(a: Enemy, b: Enemy) -> bool: return flat(a.global_position - at).length() < flat(b.global_position - at).length())
		if near.is_empty():
			if randf() < 0.5:
				var a := randf() * TAU
				Vfx.bolt(host, top, at + Vector3(cos(a), 0, sin(a)) * randf_range(1.5, 3.0), col, 0.25, 0.2, 0)
			return
		Sfx.play("sk_thunder", -14.0, 1.6)
		for k in mini(n, near.size()):
			var e: Enemy = near[k]
			var to := e.global_position + Vector3(0, float(e.data["height"]) * 0.6, 0)
			Vfx.bolt(host, top, to, col, 0.4, 0.3, 2)
			hit(p, e, m, at, {"stun": 0.15}))


## Clone de sombra: cópia escura do herói que surge, salta no inimigo, corta e se desfaz.
static func _clone_strike(p: Player, host: Node, tg: Enemy, m: float, col: Color) -> void:
	var start := p.global_position + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
	var to := flat(tg.global_position - start)
	var dest := tg.global_position - to.normalized() * (tg.radius + 0.9)
	dest.y = p.global_position.y
	var clone := Node3D.new()
	host.add_child(clone)
	clone.global_position = start
	clone.rotation.y = atan2(-to.x, -to.z)
	var kit := ModelKit.load_hero("assassino", p.visual_rarities(), 0.02)
	if kit == null:
		kit = ModelKit.load_kit("hero_assassino_%s" % String(p.armor.get("rarity", "comum")), 0.02)
	if kit != null:
		clone.add_child(kit.root)
		kit.set_tint(Color(0.12, 0.04, 0.22), 0.85)
		kit.play("sk_as1", 1.4, true)
	Vfx.emit(host, start, {"tex": "smoke", "add": false, "shot": false, "amount": 30, "life": 0.5, "dur": 0.45, "size": [0.8, 1.4],
			"shape": "sphere", "r": 0.5, "vel": [0.2, 0.8], "colors": Vfx.SHADOW})
	var tw := clone.create_tween()
	tw.tween_property(clone, "global_position", dest, 0.18).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		if is_instance_valid(tg) and is_instance_valid(p):
			Vfx.blood_slash(host, tg.global_position + Vector3(0, float(tg.data["height"]) * 0.6, 0), randf() * TAU, 2.0)
			Sfx.play("sk_slash", -8.0, randf_range(1.0, 1.3))
			hit(p, tg, m, dest))
	tw.tween_interval(0.25)
	tw.tween_callback(func() -> void:
		Vfx.shadow_puff(host, clone.global_position, 0.8, col)
		clone.queue_free())


## Fúria do Trovão: raio do céu no inimigo mais perto do ponto e depois saltos para os vizinhos.
static func _storm_chain(p: Player, host: Node, point: Vector3, rng: float, hops: int, jump: float, m: float, col: Color, stun: float) -> void:
	var tree := p.get_tree()
	var first: Enemy = null
	var best := 999.0
	for e in enemies(tree):
		if flat(e.global_position - p.global_position).length() > rng:
			continue
		var score := flat(e.global_position - point).length()
		if score < best:
			best = score
			first = e
	var hand := p.global_position + Vector3(0, 2.2, 0)
	if first == null:
		var at := p.global_position + flat(point - p.global_position).limit_length(rng)
		Vfx.bolt(host, at + Vector3(randf_range(-2, 2), 18, randf_range(-2, 2)), at, col, 0.6, 0.4, 4)
		Vfx.shockwave(host, at, col, 3.0, 0.35)
		return
	var chain: Array[Enemy] = [first]
	var cur := first
	for k in hops - 1:
		var nxt: Enemy = null
		var bd := jump * GameData.AREA_MULT
		for e in enemies(tree):
			if chain.has(e):
				continue
			var d := flat(e.global_position - cur.global_position).length()
			if d < bd:
				bd = d
				nxt = e
		if nxt == null:
			break
		chain.append(nxt)
		cur = nxt
	Vfx.bolt(host, hand, hand + Vector3(0, 6, 0), col, 0.4, 0.3, 1)
	var prev := Vector3.ZERO
	for k in chain.size():
		var e := chain[k]
		var to := e.global_position + Vector3(0, float(e.data["height"]) * 0.6, 0)
		var from := (to + Vector3(randf_range(-3, 3), 20, randf_range(-3, 3))) if k == 0 else prev
		var dm := m * pow(0.92, k)
		_later(p, 0.12 + 0.09 * k, func() -> void:
			if not is_instance_valid(e):
				return
			Vfx.bolt(host, from, to, col, 0.7 if k == 0 else 0.45, 0.35, 4 if k == 0 else 2)
			if k == 0:
				Vfx.shockwave(host, e.global_position, col, 4.0, 0.35)
				Fx.shake(p, 0.25)
			Sfx.play("sk_thunder", -8.0 - k, 1.0 + 0.06 * k)
			hit(p, e, dm, from, {"stun": stun}))
		prev = to


static func _chain(p: Player, host: Node, hand: Vector3, point: Vector3, rng: float, hops: int, m: float, col: Color, stun: float = 0.0) -> void:
	var tree := p.get_tree()
	var first: Enemy = null
	var best := 999.0
	for e in enemies(tree):
		var dp := flat(e.global_position - p.global_position).length()
		if dp > rng:
			continue
		var score := flat(e.global_position - point).length()
		if score < best:
			best = score
			first = e
	if first == null:
		Vfx.bolt(host, hand, hand + Skills.flat(point - p.global_position).normalized() * 6.0, col, 0.35, 0.25, 1)
		return
	var chain: Array[Enemy] = [first]
	var cur := first
	for k in hops - 1:
		var nxt: Enemy = null
		var bd := 7.0
		for e in enemies(tree):
			if chain.has(e):
				continue
			var d := flat(e.global_position - cur.global_position).length()
			if d < bd:
				bd = d
				nxt = e
		if nxt == null:
			break
		chain.append(nxt)
		cur = nxt
	var prev := hand
	for k in chain.size():
		var e := chain[k]
		var to := e.global_position + Vector3(0, float(e.data["height"]), 0)
		var from := prev
		var dm := m * pow(0.88, k)
		_later(p, 0.07 * k, func() -> void:
			if is_instance_valid(e):
				Vfx.bolt(host, from, to, col, 0.4, 0.3, 2)
				hit(p, e, dm, from, {"stun": stun} if stun > 0.0 else {}))
		prev = to
