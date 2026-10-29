class_name Skills
extends RefCounted
## Execução das 24 skills. Cada skill de GameData.SKILLS tem um "type"; aqui está o efeito de cada tipo.
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


static func describe(sk: Dictionary, lvl: int) -> String:
	var s := String(sk["desc"])
	s = s.replace("{dmg}", "%d%%" % int(round(float(sk.get("mult", 1.0)) * level_mult(lvl) * 100.0)))
	s = s.replace("{r}", ("%.1f" % float(sk.get("r", 0.0))).replace(".", ","))
	s = s.replace("{buff}", "%d%%" % int(round(buff_amount(sk, lvl) * 100.0)))
	s = s.replace("{dur}", ("%.0f" % float(sk.get("dur", 0.0))))
	s = s.replace("{n}", str(chain_hops(sk, lvl)))
	s = s.replace("{shield}", "%d%%" % int(round(shield_pct(sk, lvl) * 100.0)))
	return s


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
	var crit := randf() < 0.15 or p.crit_next
	p.crit_next = false
	var dmg := p.atk * mult * randf_range(0.92, 1.08) * (1.0 + p.dmg_buff) * (1.8 if crit else 1.0)
	if p.double_next:
		p.double_next = false
		dmg *= 2.0
	if p._giant_t > 0.0:
		dmg *= 1.2
	e.take_damage(maxi(1, int(round(dmg))), from, crit)
	if e.alive:
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
	var m := float(sk.get("mult", 1.0)) * level_mult(lvl)
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
			var r := float(sk["r"])
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
			var r2 := float(sk["r"])
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
			var r3 := float(sk["r"])
			var half := float(sk["half"])
			p.attack_visual()
			Fx.slash(host, pos + Vector3(0, 1.0, 0), _ang(dir), r3 * 0.55, rad_to_deg(half * 2.0), Color(1.0, 0.85, 0.4), 1.2, 0.25)
			_flame_cone(host, pos + Vector3(0, 0.9, 0), dir, r3, half, col)
			Fx.light_flash(host, pos + dir * 3.0 + Vector3(0, 1.5, 0), col, 6.0, 12.0, 0.5)
			for e in in_cone(tree, pos, dir, r3, cos(half)):
				hit(p, e, m, pos)
		"strike":
			var r4 := float(sk["r"])
			var target := pos + flat(point - pos).limit_length(float(sk["range"]))
			var delay := float(sk["delay"])
			Fx.telegraph(host, target, r4, col, delay)
			_falling(host, target, String(sk["visual"]), col, delay)
			_later(p, delay, func() -> void:
				Fx.ring(host, target + Vector3(0, 0.1, 0), col, r4 * 1.2, 0.5, 0.1)
				Fx.disc(host, target + Vector3(0, 0.05, 0), col, r4, 0.5, 0.28)
				Fx.burst(host, target + Vector3(0, 0.5, 0), col, 40, 10.0, 0.16)
				Fx.light_flash(host, target + Vector3(0, 2, 0), col, 6.0, 16.0, 0.6)
				Fx.shake(p, 0.5)
				Sfx.play("sk_explosion", 0.0)
				for e in in_radius(tree, target, r4):
					hit(p, e, m, target, {"stun": 0.6}))
		"thrust3":
			var rng := float(sk["range"])
			var hits := int(sk["hits"])
			for k in hits:
				_later(p, 0.12 * k, func() -> void:
					if not is_instance_valid(p):
						return
					var o := p.global_position
					p.attack_visual()
					var side := dir.cross(Vector3.UP) * (0.35 * (k - 1))
					Fx.streak(host, o + Vector3(0, 1.1, 0) + side, o + dir * rng + Vector3(0, 1.1, 0) + side, col, 0.45, 0.22)
					Sfx.play("swing", -6.0, 1.1 + 0.1 * k)
					for e in in_cone(tree, o, dir, rng, 0.82):
						hit(p, e, m, o, _opts(sk)))
		"leap":
			var r5 := float(sk["r"])
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
			var r6 := float(sk["r"])
			Fx.slash(host, pos + Vector3(0, 1.0, 0), _ang(dir), r6, 400.0, col, 1.4, 0.4)
			Fx.slash(host, pos + Vector3(0, 0.7, 0), _ang(dir) + 1.0, r6 * 0.6, 400.0, Color(1, 1, 1), 0.7, 0.35)
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
			var r7 := float(sk["r"])
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
			_trap(p, host, at2, float(sk["r"]), m, float(sk["stun"]), col)
		"chain":
			_chain(p, host, hand, point, float(sk["range"]), chain_hops(sk, lvl), m, col, float(sk.get("stun", 0.0)))
		"shield":
			p.add_shield(p.max_hp * shield_pct(sk, lvl), float(sk["dur"]), col)
			if sk.has("burst"):
				p.shield_burst = {"mult": float(sk["burst"]) * level_mult(lvl), "r": float(sk["r"]), "color": col}
			Fx.ring(host, pos + Vector3(0, 0.1, 0), col, 3.0, 0.4)
			Fx.light_flash(host, pos + Vector3(0, 1.5, 0), col, 4.0, 8.0, 0.5)
		"nova":
			var r8 := float(sk["r"])
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
			var rz := float(sk["r"])
			var at := pos + flat(point - pos).limit_length(float(sk["range"]))
			var ticks := int(sk["ticks"])
			var every := float(sk["every"])
			Fx.disc(host, at + Vector3(0, 0.05, 0), Color(0.25, 0.4, 0.12), rz, every * ticks, 0.4)
			for k in 10:
				var a := TAU * k / 10.0 + randf() * 0.4
				_vine(host, at + Vector3(cos(a), 0, sin(a)) * rz * randf_range(0.3, 0.9), col, every * ticks)
			for k in ticks:
				_later(p, 0.1 + every * k, func() -> void:
					Fx.burst(host, at + Vector3(0, 0.2, 0), Color(0.45, 0.35, 0.2), 6, 3.0, 0.08)
					for e in in_radius(tree, at, rz):
						hit(p, e, m, at, {"stun": float(sk["stun"])}))
		"heal_zone":
			var rh := float(sk["r"])
			var at2 := pos
			var amount := p.max_hp * shield_pct(sk, lvl)
			Fx.disc(host, at2 + Vector3(0, 0.05, 0), col, rh, float(sk["dur"]), 0.25)
			Fx.ring(host, at2 + Vector3(0, 0.1, 0), col, rh, 0.6)
			for k in int(sk["ticks"]):
				_later(p, float(sk["every"]) * (k + 1), func() -> void:
					if not is_instance_valid(p):
						return
					Fx.burst(host, at2 + Vector3(randf_range(-rh, rh) * 0.6, 0.3, randf_range(-rh, rh) * 0.6), col, 6, 2.0, 0.08, 1.0, 3.0)
					if flat(p.global_position - at2).length() <= rh:
						p.heal(amount)
						Fx.damage_number(host, p.global_position + Vector3(0, 2.6, 0), "+%d" % int(amount), Color(0.45, 1.0, 0.5)))
		"guard":
			p.add_guard(buff_amount(sk, lvl), float(sk["dur"]))
			_bark(p, col, float(sk["dur"]))
			Fx.burst(host, pos + Vector3(0, 1.0, 0), Color(0.55, 0.38, 0.2), 24, 4.0, 0.12)
		"awaken":
			var ra := float(sk["r"])
			Fx.light_flash(host, pos + Vector3(0, 3, 0), col, 14.0, 24.0, 0.9)
			Fx.disc(host, pos + Vector3(0, 0.05, 0), Color(1.0, 0.95, 0.7), ra, 0.7, 0.5)
			Fx.ring(host, pos + Vector3(0, 0.1, 0), col, ra, 0.6, 0.15)
			Fx.burst(host, pos + Vector3(0, 2.5, 0), col, 60, 10.0, 0.12, 1.0, 2.0)
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
				Fx.burst(host, pos + Vector3(0, 1.0, 0), Color(0.15, 0.08, 0.25), 24, 3.0, 0.2)
				p.global_position = Vector3(dest.x, pos.y, dest.z)
				p.face_dir(-away)
				Fx.burst(host, p.global_position + Vector3(0, 1.0, 0), col, 24, 4.0, 0.15)
			p.crit_next = true
		"poison_buff":
			p.poison_t = float(sk["dur"])
			p.poison_mult = m
			p.add_dmg_buff(p.dmg_buff, float(sk["dur"]), col)
			Fx.burst(host, pos + Vector3(0, 1.0, 0), col, 26, 3.0, 0.1, 0.9, 1.0)
		"stealth":
			Fx.burst(host, pos + Vector3(0, 1.0, 0), Color(0.12, 0.1, 0.16), 34, 4.0, 0.28, 1.0, 1.0)
			p.start_stealth(float(sk["dur"]))
		"spin_multi":
			var rs := float(sk["r"])
			for k in int(sk["hits"]):
				_later(p, 0.14 * k, func() -> void:
					if not is_instance_valid(p):
						return
					var o := p.global_position
					Fx.slash(host, o + Vector3(0, 1.0, 0), _ang(dir) + k * 1.6, rs, 360.0, col, 0.9, 0.2, k % 2 == 1)
					Sfx.play("swing", -6.0, 1.0 + 0.1 * k)
					p.spin_visual()
					for e in in_radius(tree, o, rs):
						hit(p, e, m, o))
		"dodge":
			p.dodge_t = float(sk["dur"])
			Fx.burst(host, pos + Vector3(0, 1.0, 0), Color(0.1, 0.08, 0.14), 30, 3.0, 0.25, 1.0, 1.0)
			Fx.ring(host, pos + Vector3(0, 0.1, 0), col, 2.5, 0.4)
		"execute":
			var tgt2: Enemy = null
			var low := 2.0
			for e in in_radius(tree, pos, float(sk["r"])):
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
				Fx.lightning(host, top + Vector3(0, 10, 0), top, col, 0.3)
				Fx.light_flash(host, top, col, 10.0, 12.0, 0.5)
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
		"colossus":
			var rc := float(sk["r"])
			p.become_giant(float(sk["dur"]))
			p.add_guard(buff_amount(sk, lvl), float(sk["dur"]))
			_later(p, 0.35, func() -> void:
				var o := p.global_position
				p.attack_visual()
				Fx.ring(host, o + Vector3(0, 0.1, 0), col, rc, 0.5, 0.15)
				Fx.disc(host, o + Vector3(0, 0.05, 0), Color(0.2, 0.12, 0.05), rc * 0.8, 1.0, 0.6)
				Fx.burst(host, o + Vector3(0, 0.4, 0), Color(0.7, 0.55, 0.3), 50, 11.0, 0.18)
				Fx.light_flash(host, o + Vector3(0, 2, 0), col, 10.0, 16.0, 0.5)
				Fx.shake(p, 0.6)
				Sfx.play("sk_explosion", 0.0, 0.7)
				for e in in_radius(tree, o, rc):
					hit(p, e, m, o, {"stun": 0.8}))
		"companion":
			_jelly(p, m, float(sk["range"]), float(sk["dur"]), float(sk["every"]), col)
		"maelstrom":
			var rm := float(sk["r"])
			var ticks2 := int(sk["ticks"])
			var every2 := float(sk["every"])
			var whirl := _whirl(host, pos, rm, col, every2 * ticks2)
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
	Fx.ring(host, o + Vector3(0, 0.1, 0), col, r, 0.4, 0.1)
	Fx.burst(host, o + Vector3(0, 1.0, 0), col, 50, 10.0, 0.1, 0.8, -6.0)
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
			Fx.lightning(host, j.global_position, top, col, 0.18)
			Sfx.play("sk_thunder", -14.0, 1.6)
			hit(p, e, m, j.global_position, {"slow": 0.35, "slow_dur": 1.5}))


static func _whirl(host: Node, at: Vector3, r: float, col: Color, t: float) -> Node3D:
	var w := Node3D.new()
	host.add_child(w)
	w.global_position = at
	for k in 4:
		var ring := Toon.glow_part(Toon.cyl(r * (0.35 + 0.2 * k), r * (0.25 + 0.2 * k), 0.8 + k * 0.7, 24), col.lerp(Color(1, 1, 1), 0.15 * k), Vector3(0, 0.4 + k * 0.6, 0), 0.25 - k * 0.04, true)
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
	Fx.light_flash(host, at + Vector3(0, 2, 0), col, 6.0, 14.0, t)
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
		Fx.lightning(host, hand, hand + Skills.flat(point - p.global_position).normalized() * 6.0, col, 0.2)
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
				Fx.lightning(host, from, to, col, 0.25)
				Fx.light_flash(host, to, col, 4.0, 6.0, 0.25)
				hit(p, e, dm, from, {"stun": stun} if stun > 0.0 else {}))
		prev = to
