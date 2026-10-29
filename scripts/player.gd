class_name Player
extends CharacterBody3D
## Herói: movimento (relativo à câmera isométrica), ataque básico, 6 skills, mana, buffs,
## escudo, XP e níveis (máx. 60) e pontos de skill (1 por nível, skill até nível 10).

signal stats_changed
signal leveled_up(level: int)
signal fell
signal message(text: String)

const LIMIT := 106.0

var class_key := "assassino"
var cdata: Dictionary = {}
var alive := true
var level := 1
var xp := 0
var gold := 0
var max_hp := 100
var hp := 100.0
var max_mp := 50
var mp := 50.0
var atk := 20.0
var speed := 7.0
var skill_levels: Array[int] = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0]
var skill_points := 0
var gems := 0                    # moeda premium da loja (Shop)
var shop_counts := {}            # id -> quantas vezes comprou
var shop_bonus := {}             # "atk"/"hp"/"mp"/"speed" -> bônus somado das runas
var pet := ""                    # mascote da loja ativo (id)
var pet_levels: Dictionary = {}  # id -> [nível, xp] de cada pet
var _pet_node: Pet
# montaria (loja): R monta/desmonta; atacar desmonta; fora de combate, andando, monta sozinho
var mount := ""
var riding := false
var _mount_kit: ModelKit
var _ride_t := 0.0
var _trail_t := 0.0
var xp_boost_until := 0.0        # horário Unix até quando o XP vale dobrado
var purchases: Array = []        # registro de compras/créditos (para o banco de dados)
var skill_cd: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var basic_cd := 0.0

var dmg_buff := 0.0
var _dmg_buff_t := 0.0
var speed_buff := 0.0
var _speed_buff_t := 0.0
var shield := 0.0
var _shield_t := 0.0
var invuln_t := 0.0
var _since_hit := 99.0

var facing := Vector3(0, 0, 1)
var aim_point := Vector3.ZERO      # ponto do mouse no chão (o jogo atualiza)
var mouse_held := false            # clique esquerdo segurado (o jogo atualiza)
var auto_dir := Vector3.ZERO       # direção pedida pelo modo automático
var manual_input := false
var cam_right := Vector3(1, 0, 0)
var cam_fwd := Vector3(0, 0, -1)

var _dash_vel := Vector3.ZERO
var _dash_t := 0.0
var _leaping := false
var _act_t := 0.0
var _skill_anim_t := 0.0
var _kit: ModelKit
var _vis: Node3D
var _buff_fx: Node3D
var _shield_fx: Node3D

# equipamentos: um item por encaixe (GameData.GEAR_SLOTS: arma, elmo, peitoral, calças, luvas, botas, colar,
# brincos e 2 anéis), cada um com raridade e refino +0..+15; e o inventário
var inventory: Array = []
var gear: Dictionary = {}
var weapon: Dictionary:
	get:
		return gear.get("weapon", {})
var armor: Dictionary:   # o peitoral (era a "armadura" antes das peças separadas)
	get:
		return gear.get("chest", {})
var defense := 0.0
var god_mode := false   # menu de administrador
# estados das skills das classes
var crit_next := false     # Passo das Sombras
var double_next := false   # Camuflagem Sombria
var stealth_t := 0.0
var poison_t := 0.0        # Adagas Envenenadas
var poison_mult := 0.0
var dodge_t := 0.0         # Manto do Vazio
var guard := 0.0           # Casca de Carvalho / Colosso: redução de dano
var _guard_t := 0.0
var cc_immune_t := 0.0     # Despertar Lendário
var heat := 0              # Sobrecarga de Vapor
var heat_t := 0.0
var shield_burst := {}     # Escudo de Conchas: explode ao quebrar
var _since_action := 99.0
var _giant_t := 0.0
var _uid := 0


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
	cdata = GameData.CLASSES[class_key]
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.45
	cap.height = 1.9
	cs.shape = cap
	cs.position.y = 0.95
	add_child(cs)
	# o herói já começa com todas as skins (Comum, Rara, Épica e Lendária) e usa a mais forte
	give_all_skins(gear.size() < GameData.GEAR_SLOTS.size())
	_vis = Node3D.new()
	add_child(_vis)
	_build_visuals()
	var shadow := Toon.glow_part(Toon.cyl(0.6, 0.6, 0.01, 20), Color(0, 0, 0), Vector3(0, 0.03, 0), 0.4)
	(shadow.material_override as StandardMaterial3D).blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	add_child(shadow)
	# luz suave acompanhando o herói (destaca o personagem no cenário escuro, como no Hades)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.85, 0.7)
	l.light_energy = 0.9
	l.omni_range = 7.0
	l.position = Vector3(0, 3.0, 1.0)
	add_child(l)
	recalc()
	hp = max_hp
	mp = max_mp


func recalc() -> void:
	var k := float(level - 1)
	max_hp = int(float(cdata["hp"]) * (1.0 + 0.12 * k))
	max_mp = int(float(cdata["mp"]) * (1.0 + 0.08 * k))
	atk = float(cdata["atk"]) * (1.0 + 0.10 * k)
	speed = float(cdata["speed"])
	max_hp = int(max_hp * (1.0 + float(shop_bonus.get("hp", 0.0))))
	max_mp = int(max_mp * (1.0 + float(shop_bonus.get("mp", 0.0))))
	atk *= 1.0 + float(shop_bonus.get("atk", 0.0))
	speed *= 1.0 + float(shop_bonus.get("speed", 0.0))
	var g := gear_stats()
	atk *= 1.0 + float(g.get("atk", 0.0))
	max_hp = int(max_hp * (1.0 + float(g.get("hp", 0.0))))
	max_mp = int(max_mp * (1.0 + float(g.get("mp", 0.0))))
	speed *= 1.0 + float(g.get("speed", 0.0))
	defense = minf(0.6, float(g.get("def", 0.0)))
	hp = minf(hp, max_hp)
	mp = minf(mp, max_mp)


# ------------------------------------------------------------------ skills

func skill(i: int) -> Dictionary:
	return GameData.SKILLS[class_key][i]


func skill_cost(i: int) -> float:
	return Skills.mp_cost(skill(i), skill_levels[i])


func is_passive(i: int) -> bool:
	return String(skill(i)["type"]) == "passive"


## Nível da skill passiva com esse nome (0 = não aprendida / não é dessa classe).
func passive_lvl(name: String) -> int:
	var list: Array = GameData.SKILLS[class_key]
	for i in list.size():
		if String(list[i].get("passive", "")) == name:
			return skill_levels[i]
	return 0


func passive_amount(name: String) -> float:
	var list: Array = GameData.SKILLS[class_key]
	for i in list.size():
		if String(list[i].get("passive", "")) == name and skill_levels[i] > 0:
			return Skills.buff_amount(list[i], skill_levels[i])
	return 0.0


func in_combat() -> bool:
	return _since_hit < 4.0 or _since_action < 4.0


## Quantas skills a classe tem (até GameData.MAX_SKILLS).
func skill_count() -> int:
	return mini(GameData.SKILLS[class_key].size(), GameData.MAX_SKILLS)


func skill_ready(i: int) -> bool:
	if i >= skill_count():
		return false
	if is_passive(i):
		return false
	return alive and skill_levels[i] >= 1 and skill_cd[i] <= 0.0 and mp >= skill_cost(i) and not _leaping


func cast_skill(i: int, point: Vector3) -> bool:
	if not alive or _leaping or i >= skill_count():
		return false
	set_riding(false)
	if skill_levels[i] < 1:
		var need: int = GameData.SKILL_UNLOCK[i]
		message.emit("%s: %s" % [skill(i)["name"], ("aprenda no painel de Skills (K)" if level >= need else "liberada no nível %d" % need)])
		return false
	if is_passive(i):
		message.emit("%s é passiva: já está ativa" % skill(i)["name"])
		return false
	if skill_cd[i] > 0.0:
		return false
	if mp < skill_cost(i):
		message.emit("Mana insuficiente")
		return false
	mp -= skill_cost(i)
	skill_cd[i] = Skills.cooldown(skill(i), skill_levels[i])
	_act_t = 0.35
	_since_action = 0.0
	_break_stealth()
	Skills.cast(self, i, point)
	play_skill(String(skill(i)["id"]))
	_add_heat()
	stats_changed.emit()
	return true


func can_learn(i: int) -> bool:
	return skill_points > 0 and skill_levels[i] < GameData.MAX_SKILL_LEVEL and level >= int(GameData.SKILL_UNLOCK[i])


func learn(i: int) -> bool:
	if not can_learn(i):
		return false
	skill_points -= 1
	skill_levels[i] += 1
	stats_changed.emit()
	return true


## Distribui os pontos sozinho: primeiro aprende as skills novas, depois sobe a de menor nível.
func auto_learn() -> void:
	var guard := 0
	while skill_points > 0 and guard < 100:
		guard += 1
		var best := -1
		for i in skill_count():
			if not can_learn(i):
				continue
			if best == -1 or skill_levels[i] < skill_levels[best] or (skill_levels[i] == skill_levels[best] and i > best):
				best = i
		if best == -1:
			break
		learn(best)


# ------------------------------------------------------------------ ataque básico

func basic_ready() -> bool:
	return alive and basic_cd <= 0.0 and not _leaping and _dash_t <= 0.0


func basic_attack(point: Vector3) -> void:
	if not basic_ready():
		return
	set_riding(false)
	basic_cd = float(cdata["cd"]) / (1.0 + (passive_amount("heat") if heat_t > 0.0 else 0.0))
	_act_t = 0.3
	_since_action = 0.0
	_break_stealth()
	var dir := Skills.flat(point - global_position)
	if dir.length() < 0.3:
		dir = facing
	dir = dir.normalized()
	face_dir(dir)
	_skill_anim_t = 0.0   # o ataque básico sempre aparece (interrompe a animação de skill)
	attack_visual()
	var host := get_parent()
	var trim: Color = cdata["trim"]
	if not weapon.is_empty() and String(weapon["rarity"]) != "comum":
		trim = GameData.RARITY[weapon["rarity"]]["color"]
	match String(cdata["basic"]):
		"melee":
			var r := float(cdata["range"])
			Fx.slash(host, global_position + Vector3(0, 1.0, 0), atan2(dir.z, dir.x), r, 150.0, trim, 1.0, 0.22, randf() < 0.5)
			Sfx.play("swing", -4.0)
			for e in Skills.in_cone(get_tree(), global_position, dir, r, float(cdata["dot"])):
				Skills.hit(self, e, 1.0, global_position)
		"thrust":
			var r2 := float(cdata["range"])
			Fx.streak(host, global_position + Vector3(0, 1.1, 0), global_position + dir * r2 + Vector3(0, 1.1, 0), trim, 0.5, 0.2)
			Sfx.play("swing", -5.0, 1.2)
			for e in Skills.in_cone(get_tree(), global_position, dir, r2, float(cdata["dot"])):
				Skills.hit(self, e, 1.0, global_position)
		"arrow":
			Sfx.play("arrow", -5.0)
			_shoot(dir, "bolt", 30.0, 0.75, trim)
		_:
			Sfx.play("sk_magic", -9.0, 1.4)
			var pr := _shoot(dir, "orb", 18.0, 0.8, trim)
			pr.explode_r = 1.6


func _shoot(dir: Vector3, visual: String, spd: float, life: float, col: Color) -> Projectile:
	var pr := Projectile.new()
	pr.player = self
	pr.dir = dir
	pr.speed = spd
	pr.life = life
	pr.mult = 1.0
	pr.visual = visual
	pr.color = col
	get_parent().add_child(pr)
	pr.global_position = global_position + Vector3(0, 1.1, 0) + dir * 0.8
	return pr


func preferred_range() -> float:
	match String(cdata["basic"]):
		"melee":
			return 2.4
		"thrust":
			return 3.6
		_:
			return 9.0


# ------------------------------------------------------------------ movimento

func move_dir() -> Vector3:
	var ix := float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT))
	var iy := float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)) - float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN))
	var v := cam_right * ix + cam_fwd * iy
	v.y = 0.0
	return v.normalized() if v.length() > 0.01 else Vector3.ZERO


func face_dir(d: Vector3) -> void:
	d.y = 0.0
	if d.length() < 0.01:
		return
	facing = d.normalized()
	rotation.y = atan2(-facing.x, -facing.z)


func start_dash(dir: Vector3, dist: float, time: float) -> void:
	_dash_vel = dir.normalized() * dist / time
	_dash_t = time
	face_dir(dir)
	invuln_t = maxf(invuln_t, time)


func leap_to(target: Vector3, time: float) -> void:
	_leaping = true
	invuln_t = maxf(invuln_t, time)
	face_dir(target - global_position)
	var start := global_position
	target.x = clampf(target.x, -LIMIT, LIMIT)
	target.z = clampf(target.z, -LIMIT, LIMIT)
	var arc := func(t: float) -> void:
		var p := start.lerp(target, t)
		p.y = start.y + sin(t * PI) * 3.5
		global_position = p
	var land := func() -> void:
		global_position.y = start.y
		_leaping = false
	var tw := create_tween()
	tw.tween_method(arc, 0.0, 1.0, time)
	tw.tween_callback(land)
	if _kit != null and _skill_anim_t <= 0.0:
		_kit.play("attack", 0.8, true)


func spin_visual() -> void:
	var tw := create_tween()
	tw.tween_property(_vis, "rotation:y", TAU, 0.3).from(0.0)
	tw.tween_callback(func() -> void: _vis.rotation.y = 0.0)
	attack_visual()


## Animação própria da skill ("sk_<id>", feita em blender/skill_anims.py). Enquanto ela toca,
## os ataques chamados de dentro da skill (attack_visual) não a interrompem.
func play_skill(id: String) -> void:
	if _kit == null or not _kit.has_anim("sk_" + id):
		return
	var L := _kit.length("sk_" + id)
	_kit.play("sk_" + id, 1.0, true)
	_skill_anim_t = L
	_act_t = maxf(_act_t, minf(L, 0.7))


func attack_visual() -> void:
	if _kit != null and _skill_anim_t <= 0.0:
		var L := _kit.length("attack")
		_kit.play("attack", maxf(1.0, L / 0.32), true)
		_act_t = maxf(_act_t, minf(L, 0.32))


func _physics_process(delta: float) -> void:
	_timers(delta)
	if not alive:
		velocity = Vector3.ZERO
		return
	var input := move_dir()
	manual_input = input != Vector3.ZERO
	var dir := input if manual_input else auto_dir
	var spd := speed * (1.0 + speed_buff + (passive_amount("owl") if in_combat() else 0.0))
	_mount_tick(delta, input != Vector3.ZERO or auto_dir != Vector3.ZERO)
	if riding:
		spd *= 1.0 + float(Shop.item(mount).get("speed", 0.0))
	if _leaping:
		return
	if _dash_t > 0.0:
		velocity = _dash_vel
		_dash_t -= delta
	else:
		velocity.x = dir.x * spd
		velocity.z = dir.z * spd
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= 25.0 * delta
	move_and_slide()
	global_position.x = clampf(global_position.x, -LIMIT, LIMIT)
	global_position.z = clampf(global_position.z, -LIMIT, LIMIT)
	if dir != Vector3.ZERO and _act_t <= 0.0 and _dash_t <= 0.0:
		facing = facing.slerp(dir, minf(1.0, 14.0 * delta)).normalized()
		rotation.y = atan2(-facing.x, -facing.z)
	if _mount_kit != null:
		_mount_kit.play("walk" if dir != Vector3.ZERO else "idle", spd / 9.0 if dir != Vector3.ZERO else 1.0)
	if riding and _kit != null and _act_t <= 0.0:
		_kit.play("idle")
	elif _kit != null and _act_t <= 0.0:
		if dir != Vector3.ZERO:
			if _kit.has_anim("run") and spd > 6.0:
				_kit.play("run", spd / 7.5)   # personagens humanizados: corrida com o corpo inteiro
			else:
				_kit.play("walk", spd / 5.5)
		else:
			_kit.play("idle")
	# ataque básico segurando o clique ou a barra de espaço
	if basic_ready() and (mouse_held or Input.is_key_pressed(KEY_SPACE)):
		var target := aim_point if mouse_held else _nearest_enemy_point(10.0)
		basic_attack(target)


func _nearest_enemy_point(r: float) -> Vector3:
	var best := global_position + facing * 3.0
	var bd := r
	for e in Skills.enemies(get_tree()):
		var d := e.global_position.distance_to(global_position)
		if d < bd:
			bd = d
			best = e.global_position
	return best


func _timers(delta: float) -> void:
	for i in skill_cd.size():
		skill_cd[i] = maxf(0.0, skill_cd[i] - delta)
	basic_cd -= delta
	_act_t -= delta
	_skill_anim_t -= delta
	invuln_t -= delta
	_since_hit += delta
	_since_action += delta
	if not alive:
		return
	var regen := (GameData.MP_REGEN_FLAT + max_mp * GameData.MP_REGEN_PCT + GameData.TEST_MP_REGEN) * delta
	if in_combat() and passive_lvl("owl") > 0:
		regen *= 3.0
	mp = minf(max_mp, mp + regen)
	if stealth_t > 0.0:
		stealth_t -= delta
		if stealth_t <= 0.0:
			_set_ghost(false)
	poison_t -= delta
	dodge_t -= delta
	cc_immune_t -= delta
	heat_t -= delta
	if _guard_t > 0.0:
		_guard_t -= delta
		if _guard_t <= 0.0:
			guard = 0.0
	if _giant_t > 0.0:
		_giant_t -= delta
		if _giant_t <= 0.0 and _vis != null:
			_vis.create_tween().tween_property(_vis, "scale", Vector3.ONE, 0.4)
	if _since_hit > 5.0:
		hp = minf(max_hp, hp + max_hp * 0.02 * delta)
	if _dmg_buff_t > 0.0:
		_dmg_buff_t -= delta
		if _dmg_buff_t <= 0.0:
			dmg_buff = 0.0
			if _buff_fx != null:
				_buff_fx.queue_free()
				_buff_fx = null
	if _speed_buff_t > 0.0:
		_speed_buff_t -= delta
		if _speed_buff_t <= 0.0:
			speed_buff = 0.0
	if _shield_t > 0.0:
		_shield_t -= delta
		if _shield_t <= 0.0 or shield <= 0.0:
			shield = 0.0
			_shield_t = 0.0
			shield_burst = {}
			if _shield_fx != null:
				_shield_fx.queue_free()
				_shield_fx = null


# ------------------------------------------------------------------ buffs

func add_dmg_buff(amount: float, dur: float, col: Color) -> void:
	dmg_buff = amount
	_dmg_buff_t = dur
	if _buff_fx == null:
		_buff_fx = Node3D.new()
		add_child(_buff_fx)
		var ring := Toon.glow_part(Toon.cyl(1.1, 1.1, 0.02, 32), col, Vector3(0, 0.05, 0), 0.35, true)
		_buff_fx.add_child(ring)
		var p := CPUParticles3D.new()
		p.amount = 24
		p.lifetime = 0.9
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
		p.emission_ring_radius = 0.9
		p.emission_ring_inner_radius = 0.6
		p.emission_ring_height = 0.1
		p.emission_ring_axis = Vector3.UP
		p.direction = Vector3.UP
		p.spread = 10.0
		p.initial_velocity_min = 1.5
		p.initial_velocity_max = 3.0
		p.gravity = Vector3.ZERO
		var sm := SphereMesh.new()
		sm.radius = 0.07
		sm.height = 0.14
		sm.radial_segments = 6
		sm.rings = 3
		sm.material = Toon.glow_mat(col, 1.0, true)
		p.mesh = sm
		_buff_fx.add_child(p)


func add_speed_buff(amount: float, dur: float) -> void:
	speed_buff = amount
	_speed_buff_t = dur


func add_shield(amount: float, dur: float, col: Color) -> void:
	shield = amount
	_shield_t = dur
	if _shield_fx == null:
		_shield_fx = Toon.glow_part(Toon.sphere(1.5, 20), col, Vector3(0, 1.0, 0), 0.22, true)
		add_child(_shield_fx)
		var tw := _shield_fx.create_tween().set_loops()
		tw.tween_property(_shield_fx, "scale", Vector3.ONE * 1.06, 0.6)
		tw.tween_property(_shield_fx, "scale", Vector3.ONE, 0.6)


# ------------------------------------------------------------------ vida, XP, ouro

func take_damage(n: int, from: Vector3 = Vector3.ZERO, attacker: Node = null) -> void:
	if not alive or invuln_t > 0.0 or god_mode:
		return
	# Presença Abissal: quem ataca o Náutico fica lento
	var ab := passive_amount("abyss")
	if ab > 0.0 and attacker != null and attacker is Enemy:
		(attacker as Enemy).apply_slow(minf(ab, 0.7), 3.0)
	# Manto do Vazio: desvia do próximo ataque
	if dodge_t > 0.0:
		dodge_t = 0.0
		Fx.burst(get_parent(), global_position + Vector3(0, 1.0, 0), Color(0.08, 0.06, 0.1), 30, 4.0, 0.25, 1.0, 1.0)
		Fx.damage_number(get_parent(), global_position + Vector3(0, 2.6, 0), "Desviou!", Color(0.75, 0.6, 1.0))
		Sfx.play("sk_dash", -6.0, 1.3)
		return
	var dmg := float(n) * (1.0 - defense) * (1.0 - guard)
	if riding:
		dmg *= 1.0 - float(Shop.item(mount).get("def", 0.0))
	if shield > 0.0:
		var absorbed := minf(shield, dmg)
		shield -= absorbed
		dmg -= absorbed
		if absorbed > 0.0:
			Fx.damage_number(get_parent(), global_position + Vector3(0, 2.6, 0), "%d" % int(absorbed), Color(0.75, 0.6, 1.0))
		if shield <= 0.0 and not shield_burst.is_empty():
			var b := shield_burst
			shield_burst = {}
			Skills.shell_burst(self, b)
	if dmg <= 0.0:
		stats_changed.emit()
		return
	hp -= dmg
	_since_hit = 0.0
	if _kit != null:
		_kit.flash(self)
	Fx.shake(self, 0.18)
	Fx.damage_number(get_parent(), global_position + Vector3(0, 2.6, 0), "-%d" % int(dmg), Color(1.0, 0.35, 0.35))
	Sfx.play("hurt", -4.0)
	if hp <= 0.0:
		hp = 0.0
		alive = false
		velocity = Vector3.ZERO
		if _kit != null:
			_kit.play("idle")
		var tw := create_tween()
		tw.tween_property(_vis, "rotation:x", -PI / 2.0, 0.4)
		fell.emit()
	stats_changed.emit()


func revive(at: Vector3) -> void:
	alive = true
	hp = max_hp
	mp = max_mp
	_vis.rotation = Vector3.ZERO
	global_position = at
	invuln_t = 2.0
	stats_changed.emit()


## Ganha XP. A partir do nível 31 todo XP vale 10x menos. Devolve quanto XP entrou de fato.
func gain_xp(n: int) -> int:
	if level >= GameData.MAX_LEVEL:
		return 0
	n = maxi(1, int(round(n * GameData.xp_gain_mult(level) * Shop.xp_mult(self))))
	return gain_xp_raw(n)


## XP sem multiplicadores (poção da loja, admin).
func gain_xp_raw(n: int) -> int:
	if level >= GameData.MAX_LEVEL:
		return 0
	xp += n
	while level < GameData.MAX_LEVEL and xp >= GameData.xp_need(level):
		xp -= GameData.xp_need(level)
		level += 1
		skill_points += 1
		recalc()
		hp = max_hp
		mp = max_mp
		gems += GameData.GEMS_PER_LEVEL
		leveled_up.emit(level)
		var host := get_parent()
		Fx.ring(host, global_position + Vector3(0, 0.1, 0), Color(1.0, 0.85, 0.35), 4.0, 0.7)
		Fx.burst(host, global_position + Vector3(0, 1.0, 0), Color(1.0, 0.85, 0.35), 40, 6.0, 0.1, 1.0, 3.0)
		Fx.light_flash(host, global_position + Vector3(0, 2, 0), Color(1.0, 0.85, 0.4), 6.0, 12.0, 1.0)
		var pillar := Toon.glow_part(Toon.cyl(0.9, 1.2, 12.0, 20), Color(1.0, 0.85, 0.4), Vector3(0, 6, 0), 0.4, true)
		add_child(pillar)
		var tw := pillar.create_tween()
		tw.tween_property(pillar, "scale", Vector3(0.05, 1, 0.05), 0.9).set_ease(Tween.EASE_IN)
		tw.tween_callback(pillar.queue_free)
		Sfx.play("levelup", -2.0)
	if level >= GameData.MAX_LEVEL:
		xp = 0
	stats_changed.emit()
	return n


func add_gold(n: int) -> void:
	gold += n
	stats_changed.emit()


# ------------------------------------------------------------------ equipamentos e skins

func new_item(slot: String, rarity: String) -> Dictionary:
	_uid += 1
	return {"uid": _uid, "cls": class_key, "slot": slot, "rarity": rarity}


## Tipos de item (anel vale para os dois encaixes de anel).
const ITEM_SLOTS := ["weapon", "helmet", "chest", "pants", "gloves", "boots", "necklace", "earring", "ring"]


## Garante uma peça de cada tipo e raridade da classe no inventário (2 anéis de cada). Com equip_best, veste a lendária nos encaixes vazios.
func give_all_skins(equip_best: bool) -> void:
	for slot in ITEM_SLOTS:
		for r in GameData.RARITIES:
			var n := 0
			for it in inventory:
				if String(it["cls"]) == class_key and String(it["slot"]) == slot and String(it["rarity"]) == String(r):
					n += 1
			for i in (2 if slot == "ring" else 1) - n:
				inventory.append(new_item(slot, String(r)))
	if equip_best:
		for it in inventory:
			if String(it["cls"]) != class_key or String(it["rarity"]) != "lendaria":
				continue
			var key := slot_key_for(it)
			if not gear.has(key):   # só preenche encaixes vazios (não troca o que o jogador escolheu)
				gear[key] = it
		recalc()


## Encaixe onde o item vai: anel vai no 1º encaixe vazio (ou no 1º, trocando).
func slot_key_for(item: Dictionary) -> String:
	var slot := String(item["slot"])
	if slot != "ring":
		return slot
	for k in ["ring1", "ring2"]:
		if not gear.has(k) or int(gear[k].get("uid", -1)) == int(item["uid"]):
			return k
	return "ring1"


func is_equipped(item: Dictionary) -> bool:
	for k in gear:
		if int(gear[k].get("uid", -1)) == int(item.get("uid", -2)):
			return true
	return false


## Soma dos atributos das peças + bônus de conjunto.
func gear_stats() -> Dictionary:
	var out := {}
	for k in gear:
		var st := GameData.item_stats(gear[k])
		for s in st:
			out[s] = float(out.get(s, 0.0)) + float(st[s])
	var sb := set_bonus()
	for s in sb["stats"]:
		out[s] = float(out.get(s, 0.0)) + float(sb["stats"][s])
	return out


## Conjunto: a melhor raridade com mais peças equipadas daquela raridade ou melhor.
## Devolve {rarity, pieces, stats} (stats somados de todas as faixas fechadas, × força da raridade).
func set_bonus() -> Dictionary:
	var best := {"rarity": "", "pieces": 0, "stats": {}}
	for ri in range(GameData.RARITIES.size() - 1, 0, -1):
		var n := 0
		for k in gear:
			if GameData.RARITIES.find(String(gear[k]["rarity"])) >= ri:
				n += 1
		if n < 2:
			continue
		var stats := {}
		var mult := float(ri) / 1.5
		for tier in GameData.SET_BONUS:
			if n >= int(tier["pieces"]):
				for s in tier["stats"]:
					stats[s] = float(stats.get(s, 0.0)) + float(tier["stats"][s]) * mult
		return {"rarity": GameData.RARITIES[ri], "pieces": n, "stats": stats}
	return best


## Poder total (número para comparar heróis): ataque, vida, mana, defesa, nível, refinos.
func power() -> int:
	var refines := 0
	for k in gear:
		refines += int(gear[k].get("refine", 0))
	return int(atk * 12.0 + max_hp * 0.6 + max_mp * 0.3 + defense * 3000.0 + level * 25 + refines * 40)


## Refina +1 pagando ouro. Devolve 1 (subiu), 0 (falhou, perdeu só o ouro), -1 (sem ouro ou já +15).
func refine(item: Dictionary) -> int:
	if int(item.get("refine", 0)) >= GameData.REFINE_MAX:
		return -1
	var cost := GameData.refine_cost(item)
	if gold < cost:
		return -1
	gold -= cost
	if randf() >= GameData.refine_chance(item):
		Sfx.play("hit", -6.0, 0.6)
		stats_changed.emit()
		return 0
	item["refine"] = int(item.get("refine", 0)) + 1
	var frac := hp / float(max_hp)
	recalc()
	hp = max_hp * frac
	Sfx.play("legendary" if int(item["refine"]) % 5 == 0 else "equip", -4.0)
	stats_changed.emit()
	return 1


func add_item(item: Dictionary) -> void:
	if String(item.get("slot", "")) == "armor":   # saves antigos: a armadura virou o peitoral
		item["slot"] = "chest"
	_uid = maxi(_uid, int(item.get("uid", 0)))
	inventory.append(item)


func equip(item: Dictionary, key: String = "") -> void:
	if String(item.get("cls", "")) != class_key:
		return
	var frac := hp / float(max_hp)
	if key == "":
		key = slot_key_for(item)
	for k in gear.keys():   # o mesmo anel não fica nos dois encaixes
		if int(gear[k].get("uid", -1)) == int(item["uid"]):
			gear.erase(k)
	gear[key] = item
	recalc()
	hp = max_hp * frac
	_build_visuals()
	Sfx.play("legendary" if String(item["rarity"]) == "lendaria" else "equip", -4.0)
	stats_changed.emit()


## Raridade visível de cada parte do corpo (peça vazia = comum).
func visual_rarities() -> Dictionary:
	var out := {}
	for k in ["helmet", "chest", "pants", "gloves", "boots"]:
		out[k] = String(gear.get(k, {}).get("rarity", "comum"))
	out["offhand"] = String(weapon.get("rarity", "comum"))
	return out


func _build_visuals() -> void:
	for c in _vis.get_children():
		c.queue_free()
	var a_r := String(armor.get("rarity", "comum"))
	var w_r := String(weapon.get("rarity", "comum"))
	_kit = ModelKit.load_hero(class_key, visual_rarities())
	if _kit == null:
		_kit = ModelKit.load_kit("hero_%s_%s" % [class_key, a_r], 0.035)
	if _kit == null:
		_kit = ModelKit.load_kit("hero_" + class_key, 0.035)
	if _kit == null:
		_vis.add_child(Toon.part(Toon.capsule(0.4, 1.8), cdata["color"], Vector3(0, 0.9, 0)))
		return
	_vis.add_child(_kit.root)
	_kit.play("idle")
	attach_weapon(_kit, class_key, w_r)
	add_gear_effects(_vis, _kit, w_r, a_r, class_key)
	_mount_kit = null
	if riding and mount != "":
		var it := Shop.item(mount)
		_mount_kit = ModelKit.load_kit(String(it["model"]), 0.03)
		if _mount_kit != null:
			var mh := Node3D.new()
			mh.position.y = float(it.get("fly", 0.0))
			mh.add_child(_mount_kit.root)
			_vis.add_child(mh)
			_mount_kit.play("idle")
			# tamanho pela altura pedida ("height"); sela a 55% da altura ("seat")
			var top := 0.01
			for m in _mount_kit.root.find_children("*", "MeshInstance3D", true, false):
				var mi := m as MeshInstance3D
				top = maxf(top, (mi.global_transform * mi.get_aabb()).end.y if mi.is_inside_tree() else mi.get_aabb().end.y)
			mh.scale = Vector3.ONE * float(it.get("height", 1.4)) / top
			_kit.root.position.y = mh.position.y + float(it.get("height", 1.4)) * float(it.get("seat", 0.55))
			for m in _mount_kit.mats:
				_kit.mats.append(m)
	if _pet_node != null:
		_pet_node.queue_free()
		_pet_node = null
	if pet != "":
		_pet_node = Pet.new()
		_pet_node.setup(self, Shop.item(pet))
		add_child(_pet_node)


func pet_level(id: String = "") -> int:
	return int(pet_levels.get(pet if id == "" else id, [1, 0])[0])


## Cada morte dá 1 XP ao pet ativo. Devolve true se subiu de nível.
func pet_gain(n: int = 1) -> bool:
	if pet == "":
		return false
	var lv: Array = pet_levels.get(pet, [1, 0])
	if int(lv[0]) >= GameData.PET_MAX_LEVEL:
		return false
	lv = [int(lv[0]), int(lv[1]) + n]
	var up := false
	while int(lv[0]) < GameData.PET_MAX_LEVEL and int(lv[1]) >= GameData.pet_xp_need(int(lv[0])):
		lv = [int(lv[0]) + 1, int(lv[1]) - GameData.pet_xp_need(int(lv[0]))]
		up = true
	pet_levels[pet] = lv
	return up


func set_riding(on: bool) -> void:
	on = on and mount != "" and alive
	_ride_t = 0.0
	if on == riding and not on:
		return
	riding = on   # montado de novo (ou trocou de montaria): redesenha
	if _vis != null:
		_build_visuals()
	if on:
		Sfx.play("sk_dash", -8.0, 0.8)


func toggle_ride() -> void:
	set_riding(not riding)


func _mount_tick(delta: float, moving: bool) -> void:
	if mount == "":
		return
	if not riding:
		_ride_t = _ride_t + delta if moving and not in_combat() else 0.0
		if _ride_t > 2.0:
			set_riding(true)
		return
	var it := Shop.item(mount)
	if it.has("regen"):
		hp = minf(max_hp, hp + max_hp * float(it["regen"]) * delta)
	if it.has("trail"):
		_trail_t -= delta
		if _trail_t <= 0.0 and moving:
			_trail_t = 0.4
			Fx.burst(get_parent(), global_position + Vector3(0, 0.3, 0), Color(1.0, 0.45, 0.1), 10, 2.0, 0.12, 0.8, 1.0)
			for n in get_tree().get_nodes_in_group("enemy"):
				var e := n as Enemy
				if e != null and e.global_position.distance_to(global_position) < 3.0:
					e.take_damage(int(atk * float(it["trail"])), global_position)


func rebuild_visuals() -> void:
	_build_visuals()


## Encaixa a arma (.glb) na mão do modelo e soma os materiais dela ao flash de dano.
## Ponto de encaixe da arma. Nos personagens humanizados ele fica dentro de um BoneAttachment3D da mão.
static func weapon_slot(kit: ModelKit) -> Node3D:
	var found := kit.root.find_children("Weapon*", "", true, false)
	for n in found:
		if not (n is BoneAttachment3D):
			return n as Node3D
	return (found[0] as Node3D) if not found.is_empty() else null


static func attach_weapon(kit: ModelKit, cls: String, rarity: String) -> void:
	var slot := weapon_slot(kit)
	if slot == null:
		return
	var wk := ModelKit.load_kit("weapon_%s_%s" % [cls, rarity], 0.02)
	if wk == null:
		return
	slot.add_child(wk.root)
	for m in wk.mats:
		kit.mats.append(m)


## Efeitos especiais de cada skin (cor da raridade + elementos de cada classe, como na folha de referência):
## Druida Épica: coruja roxa voando ao lado · Druida Lendária: sol dourado e faíscas
## Assassino Épica: fumaça negra nos pés · Assassino Lendária: faíscas douradas nas adagas
## Mecânico Rara/Épica: faíscas elétricas na ferramenta · Mecânico Lendária: auréola de engrenagem girando
## Náutico Rara: respingos de água · Náutico Épica: água-viva e raios · Náutico Lendária: redemoinho com peixes e bolhas
static func add_gear_effects(vis: Node3D, kit: ModelKit, w_r: String, a_r: String, cls: String = "") -> void:
	var slot := weapon_slot(kit)
	if slot != null and (w_r == "epica" or w_r == "lendaria"):
		var col: Color = GameData.RARITY[w_r]["color"]
		var l := OmniLight3D.new()
		l.light_color = col
		l.light_energy = 1.6 if w_r == "lendaria" else 1.0
		l.omni_range = 3.5
		l.position = Vector3(0, 0, -0.6) if cls != "druida" else Vector3(0, 0, 1.8)
		slot.add_child(l)
		var sp := _particles(26 if w_r == "lendaria" else 12, 0.8, col, 0.05, Vector3.UP, 40.0, 0.3, 1.0, Vector3(0, 0.5, 0))
		sp.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		sp.emission_box_extents = Vector3(0.08, 0.08, 0.5)
		sp.position = Vector3(0, 0, 1.6) if cls == "druida" else Vector3(0, 0, -0.6)
		slot.add_child(sp)
	if a_r == "epica" or a_r == "lendaria":
		var col2: Color = GameData.RARITY[a_r]["color"]
		vis.add_child(Toon.glow_part(Toon.cyl(1.0, 1.0, 0.02, 32), col2 * 0.7, Vector3(0, 0.04, 0), 0.1 if a_r == "lendaria" else 0.06, true))
	var key := cls + "_" + a_r
	match key:
		"druida_epica":
			_pet(vis, "pet_owl", Vector3(-1.0, 2.4, -0.3), 0.75)
		"druida_lendaria":
			var rays := _particles(20, 1.2, Color(1.0, 0.85, 0.4), 0.06, Vector3.UP, 180.0, 0.4, 1.2, Vector3.ZERO)
			rays.position = Vector3(0, 1.6, 0)
			vis.add_child(rays)
		"assassino_epica":
			var smoke := _particles(30, 1.6, Color(0.05, 0.03, 0.07), 0.28, Vector3.UP, 30.0, 0.2, 0.7, Vector3(0, 0.3, 0), false)
			smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
			smoke.emission_ring_radius = 0.7
			smoke.emission_ring_inner_radius = 0.2
			smoke.emission_ring_height = 0.05
			smoke.emission_ring_axis = Vector3.UP
			smoke.position.y = 0.1
			vis.add_child(smoke)
		"assassino_lendaria":
			var gold := _particles(18, 1.4, Color(1.0, 0.8, 0.35), 0.05, Vector3.UP, 10.0, 0.8, 1.6, Vector3.ZERO)
			gold.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
			gold.emission_ring_radius = 0.9
			gold.emission_ring_inner_radius = 0.7
			gold.emission_ring_height = 0.05
			gold.emission_ring_axis = Vector3.UP
			vis.add_child(gold)
		"mecanico_rara", "mecanico_epica":
			if slot != null:
				var el := _particles(16, 0.25, Color(0.45, 0.85, 1.0) if a_r == "rara" else Color(0.8, 0.4, 1.0), 0.04, Vector3.UP, 180.0, 1.5, 3.5, Vector3.ZERO)
				el.position = Vector3(0, 0, -0.9)
				slot.add_child(el)
		"mecanico_lendaria":
			var halo := kit.root.find_child("Aureola", true, false) as Node3D
			if halo != null:
				var tw := halo.create_tween().set_loops()
				tw.tween_property(halo, "rotation:z", TAU, 6.0).as_relative()
		"nautico_rara":
			var splash := _particles(18, 0.6, Color(0.45, 0.8, 1.0), 0.06, Vector3.UP, 35.0, 1.5, 2.6, Vector3(0, -8.0, 0))
			splash.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
			splash.emission_ring_radius = 0.6
			splash.emission_ring_inner_radius = 0.4
			splash.emission_ring_height = 0.02
			splash.emission_ring_axis = Vector3.UP
			vis.add_child(splash)
		"nautico_epica":
			_pet(vis, "pet_jelly", Vector3(-1.1, 1.2, -0.4), 0.8)
			var zap := _particles(10, 0.15, Color(0.75, 0.6, 1.0), 0.05, Vector3.UP, 180.0, 2.0, 4.0, Vector3.ZERO)
			zap.position.y = 1.4
			zap.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			zap.emission_sphere_radius = 0.6
			vis.add_child(zap)
		"nautico_lendaria":
			var swirl := Node3D.new()
			vis.add_child(swirl)
			for k in 3:
				var t := TorusMesh.new()
				t.inner_radius = 0.9 + k * 0.25
				t.outer_radius = 1.0 + k * 0.25
				t.rings = 40
				t.ring_segments = 4
				var ring := MeshInstance3D.new()
				ring.mesh = t
				ring.position.y = 0.2 + k * 0.45
				ring.scale = Vector3(1, 0.15, 1)
				ring.material_override = Toon.glow_mat(Color(0.55, 0.85, 1.0), 0.35 - k * 0.07, true)
				ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				swirl.add_child(ring)
			for k in 4:
				var a := TAU * k / 4.0
				var fk := ModelKit.load_kit("pet_fish", 0.0, 0.0)
				if fk != null:
					fk.root.position = Vector3(cos(a) * 1.2, 0.6 + 0.3 * (k % 2), sin(a) * 1.2)
					fk.root.rotation.y = -a
					fk.root.scale = Vector3.ONE * 0.8
					swirl.add_child(fk.root)
			var spin := swirl.create_tween().set_loops()
			spin.tween_property(swirl, "rotation:y", TAU, 3.0).as_relative()
			var bubbles := _particles(16, 1.6, Color(0.75, 0.92, 1.0), 0.06, Vector3.UP, 15.0, 0.6, 1.2, Vector3.ZERO)
			bubbles.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
			bubbles.emission_ring_radius = 1.1
			bubbles.emission_ring_inner_radius = 0.6
			bubbles.emission_ring_height = 0.1
			bubbles.emission_ring_axis = Vector3.UP
			vis.add_child(bubbles)


static func _particles(amount: int, life: float, col: Color, size: float, dir: Vector3, spread: float, v0: float, v1: float, grav: Vector3, additive: bool = true) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.local_coords = false
	p.direction = dir
	p.spread = spread
	p.initial_velocity_min = v0
	p.initial_velocity_max = v1
	p.gravity = grav
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.6 if not additive else 1.0))
	curve.add_point(Vector2(0.4, 1.0))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	var sm := SphereMesh.new()
	sm.radius = size
	sm.height = size * 2.0
	sm.radial_segments = 6
	sm.rings = 3
	var m := Toon.glow_mat(col, 1.0 if additive else 0.55, additive)
	sm.material = m
	p.mesh = sm
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


## Mascote que flutua ao lado do herói, subindo e descendo devagar.
static func _pet(vis: Node3D, model: String, at: Vector3, s: float) -> void:
	var pk := ModelKit.load_kit(model, 0.02, 0.0)
	if pk == null:
		return
	var holder := Node3D.new()
	holder.position = at
	vis.add_child(holder)
	pk.root.scale = Vector3.ONE * s
	holder.add_child(pk.root)
	var l := OmniLight3D.new()
	l.light_color = Color(0.8, 0.55, 1.0)
	l.light_energy = 1.2
	l.omni_range = 3.0
	l.position.y = 0.5
	holder.add_child(l)
	var tw := holder.create_tween().set_loops()
	tw.tween_property(holder, "position:y", at.y + 0.25, 1.1).set_trans(Tween.TRANS_SINE)
	tw.tween_property(holder, "position:y", at.y - 0.1, 1.1).set_trans(Tween.TRANS_SINE)


# ------------------------------------------------------------------ estados das skills

func _add_heat() -> void:
	if passive_lvl("heat") <= 0:
		return
	heat += 1
	if heat >= 4:
		heat = 0
		heat_t = 4.0
		Fx.burst(get_parent(), global_position + Vector3(0, 1.4, 0), Color(1.0, 0.6, 0.25), 30, 5.0, 0.12, 0.9, 3.0)
		Fx.damage_number(get_parent(), global_position + Vector3(0, 2.8, 0), "Sobrecarga!", Color(1.0, 0.6, 0.25))
		Sfx.play("sk_buff", -4.0, 0.8)


func start_stealth(t: float) -> void:
	stealth_t = t
	double_next = true
	_set_ghost(true)


func _break_stealth() -> void:
	if stealth_t > 0.0:
		stealth_t = 0.0
		_set_ghost(false)


func _set_ghost(on: bool) -> void:
	if _vis == null:
		return
	for n in _vis.find_children("*", "GeometryInstance3D", true, false):
		(n as GeometryInstance3D).transparency = 0.75 if on else 0.0


func add_guard(amount: float, dur: float) -> void:
	guard = clampf(amount, 0.0, 0.85)
	_guard_t = dur


func become_giant(t: float) -> void:
	_giant_t = t
	if _vis != null:
		_vis.create_tween().tween_property(_vis, "scale", Vector3.ONE * 1.6, 0.35).set_trans(Tween.TRANS_BACK)


func heal(amount: float) -> void:
	if not alive:
		return
	hp = minf(max_hp, hp + amount)
	stats_changed.emit()
