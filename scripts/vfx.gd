class_name Vfx
extends RefCounted
## Efeitos especiais "bonitos" feitos 100% por código: as texturas (brilho, chama, fumaça, rachaduras, geada,
## queimado) são geradas uma vez no começo e os efeitos são montados em camadas (partículas com cor que muda
## com o tempo, decalques no chão, luzes, ondas de choque, raios em zigue-zague).
## Usado pelas skills (skills.gd). Os efeitos simples antigos continuam em fx.gd.

static var _tex := {}
static var _mats := {}

const ALL_TEX := ["soft", "dot", "ring", "beam", "smoke", "flame", "crack", "crack_glow", "crack_white", "frost", "scorch", "leaf"]


## Gera todas as texturas de uma vez (chamado ao entrar no jogo, para a primeira skill não travar).
static func warmup() -> void:
	for n in ALL_TEX:
		tex(n)


# =================================================================== texturas geradas por código

static func tex(name: String) -> Texture2D:
	if not _tex.has(name):
		_tex[name] = ImageTexture.create_from_image(_make(name))
	return _tex[name]


static func _make(name: String) -> Image:
	match name:
		"soft":
			return _radial(64, func(r: float) -> float: return exp(-r * r * 5.0))
		"dot":
			return _radial(32, func(r: float) -> float: return clampf(1.0 - r, 0.0, 1.0) ** 3.0)
		"ring":
			return _radial(256, func(r: float) -> float: return exp(-pow((r - 0.82) / 0.07, 2.0)) + 0.25 * exp(-pow((r - 0.7) / 0.18, 2.0)))
		"beam":
			return _beam()
		"smoke":
			return _cloud(128, 7, 0.55)
		"flame":
			return _flame()
		"crack":
			return _cracks(256, 0)
		"crack_glow":
			return _cracks(256, 1)
		"crack_white":
			return _cracks(256, 2)
		"leaf":
			return _leaf()
		"frost":
			return _ground(256, Color(0.55, 0.75, 0.9), 0.35, 11)
		"scorch":
			return _ground(256, Color(0.04, 0.03, 0.03), 0.85, 5)
	return _radial(16, func(r: float) -> float: return 1.0 - r)


static func _radial(n: int, f: Callable) -> Image:
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var dx := (x + 0.5) / n * 2.0 - 1.0
			var dy := (y + 0.5) / n * 2.0 - 1.0
			var a := clampf(float(f.call(sqrt(dx * dx + dy * dy))), 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return img


static func _beam() -> Image:
	# faixa para os raios: forte no meio da largura (U), suave nas pontas (V)
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var u := (x + 0.5) / 32.0 * 2.0 - 1.0
			img.set_pixel(x, y, Color(1, 1, 1, exp(-u * u * 6.0)))
	return img


## Nuvem/chama: ruído em camadas com borda suave (wisps = detalhe, hard = contraste).
static func _cloud(n: int, seed: int, hard: float) -> Image:
	var noise := FastNoiseLite.new()
	noise.seed = seed
	noise.frequency = 0.045
	noise.fractal_octaves = 4
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var dx := (x + 0.5) / n * 2.0 - 1.0
			var dy := (y + 0.5) / n * 2.0 - 1.0
			var r := sqrt(dx * dx + dy * dy)
			var v := noise.get_noise_2d(x, y) * 0.5 + 0.5
			var a := clampf((1.0 - r * 1.15) * 1.6, 0.0, 1.0) * clampf(lerpf(1.0, v * 1.7, hard), 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a * (3.0 - 2.0 * a)))
	return img


## Folha (ou pétala): elipse pontuda com nervura no meio.
static func _leaf() -> Image:
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var u := (x + 0.5) / n * 2.0 - 1.0
			var v := (y + 0.5) / n * 2.0 - 1.0
			var half := 0.55 * (1.0 - v * v)
			var a := clampf((half - absf(u)) * 12.0, 0.0, 1.0)
			var vein := 1.0 - 0.35 * exp(-u * u * 400.0)
			img.set_pixel(x, y, Color(vein, vein, vein, a))
	return img


## Labareda: gota (larga embaixo, ponta em cima) com ruído esticado na vertical. Usada em quads mais altos que largos.
static func _flame() -> Image:
	var noise := FastNoiseLite.new()
	noise.seed = 3
	noise.frequency = 0.06
	noise.fractal_octaves = 3
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var u := (x + 0.5) / n * 2.0 - 1.0          # -1..1 na largura
			var v := 1.0 - (y + 0.5) / n                  # 0 embaixo, 1 em cima
			var half := 0.85 * sqrt(clampf(1.0 - v, 0.0, 1.0)) * clampf(v * 4.0, 0.0, 1.0) + 0.05
			var edge := clampf(1.0 - absf(u) / half, 0.0, 1.0)
			var wisp := noise.get_noise_2d(x * 1.4, y * 0.5) * 0.5 + 0.5
			var a := clampf(edge * 1.6 - (1.0 - wisp) * 0.55 * v, 0.0, 1.0) * clampf((1.0 - v) * 3.0, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a * (3.0 - 2.0 * a)))
	return img


## Marca no chão (geada, queimado): mancha irregular com borda que se desfaz.
static func _ground(n: int, col: Color, strength: float, seed: int) -> Image:
	var noise := FastNoiseLite.new()
	noise.seed = seed
	noise.frequency = 0.03
	noise.fractal_octaves = 5
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var dx := (x + 0.5) / n * 2.0 - 1.0
			var dy := (y + 0.5) / n * 2.0 - 1.0
			var r := sqrt(dx * dx + dy * dy)
			var v := noise.get_noise_2d(x, y) * 0.5 + 0.5
			var a := clampf((1.0 - r) * 2.2 - (1.0 - v) * 1.1, 0.0, 1.0) * strength
			var c := col.lerp(Color(1, 1, 1) if col.v > 0.5 else Color(0.15, 0.08, 0.04), (1.0 - v) * 0.35)
			img.set_pixel(x, y, Color(c.r, c.g, c.b, a))
	return img


## Rachaduras saindo do centro com um buraco no meio. mode 0 = fendas escuras; 1 = brilho de lava; 2 = brilho branco
## (para tingir com a cor da skill, ex.: raízes verdes).
static func _cracks(n: int, mode: int) -> Image:
	var glow := mode > 0
	var white := mode == 2
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var c := Vector2(n, n) * 0.5
	# buraco central
	for y in n:
		for x in n:
			var d := Vector2(x, y).distance_to(c) / (n * 0.5)
			if d < 0.34:
				var k := clampf((0.34 - d) / 0.1, 0.0, 1.0)
				if glow:
					if not white:   # a versão branca (tingida) não tem miolo brilhante, só as fendas
						img.set_pixel(x, y, Color(0.9, 0.25, 0.05, 0.7 * k * clampf((0.24 - d) / 0.12, 0.0, 1.0)))
				else:
					img.set_pixel(x, y, Color(0.03, 0.02, 0.02, k))
	# fendas: caminhadas aleatórias com galhos
	var stack: Array = []
	for i in 11:
		var a := TAU * i / 11.0 + rng.randf_range(-0.2, 0.2)
		stack.append([c + Vector2(cos(a), sin(a)) * n * 0.14, a, n * rng.randf_range(0.26, 0.36), 3.2 * n / 512.0 + 0.9])
	while not stack.is_empty():
		var s: Array = stack.pop_back()
		var p: Vector2 = s[0]
		var ang: float = s[1]
		var left: float = s[2]
		var w: float = s[3]
		while left > 0.0 and w > 0.8:
			ang += rng.randf_range(-0.45, 0.45)
			var step := 3.0 * n / 512.0 + 0.5
			p += Vector2(cos(ang), sin(ang)) * step
			left -= step
			w *= 0.985
			_stamp(img, p, w, glow, white)
			if rng.randf() < 0.025:
				stack.append([p, ang + rng.randf_range(-1.0, 1.0), left * 0.5, w * 0.7])
	return img


static func _stamp(img: Image, p: Vector2, w: float, glow: bool, white: bool = false) -> void:
	var n := img.get_width()
	var r := int(ceil(w + 2.0))
	for y in range(int(p.y) - r, int(p.y) + r + 1):
		for x in range(int(p.x) - r, int(p.x) + r + 1):
			if x < 0 or y < 0 or x >= n or y >= n:
				continue
			var d := Vector2(x, y).distance_to(p)
			if glow:
				var a := clampf(1.0 - d / (w * 0.6 + 0.6), 0.0, 1.0)
				if a > img.get_pixel(x, y).a:
					img.set_pixel(x, y, Color(1, 1, 1, a) if white else Color(1.0, 0.3 + 0.25 * a, 0.06, a))
			else:
				var a2 := clampf(1.0 - (d - w) / 2.0, 0.0, 1.0)
				var old := img.get_pixel(x, y)
				if a2 > old.a:
					img.set_pixel(x, y, Color(0.03, 0.02, 0.02, a2))


# =================================================================== materiais

static func sprite_mat(tex_name: String, additive: bool = true) -> StandardMaterial3D:
	var key := tex_name + ("+" if additive else "")
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = tex(tex_name)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mats[key] = m
	return m


static func ice_mat() -> StandardMaterial3D:
	if _mats.has("ice"):
		return _mats["ice"]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.72, 0.9, 1.0, 0.82)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = Color(0.35, 0.75, 1.0)
	m.emission_energy_multiplier = 0.8
	m.rim_enabled = true
	m.rim = 1.0
	m.rim_tint = 0.2
	m.roughness = 0.08
	m.metallic_specular = 1.0
	_mats["ice"] = m
	return m


static func lava_rock_mat() -> StandardMaterial3D:
	if _mats.has("lava"):
		return _mats["lava"]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.16, 0.08, 0.05)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.35, 0.05)
	m.emission_energy_multiplier = 1.6
	m.roughness = 0.9
	_mats["lava"] = m
	return m


static func rock_mat() -> StandardMaterial3D:
	if _mats.has("rock"):
		return _mats["rock"]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.25, 0.2, 0.17)
	m.roughness = 1.0
	_mats["rock"] = m
	return m


# =================================================================== peças básicas

static func _ok(host: Node) -> bool:
	return host != null and is_instance_valid(host) and host.is_inside_tree()


static func _grad(stops: Array) -> Gradient:
	var g := Gradient.new()
	var offs := PackedFloat32Array()
	var cols := PackedColorArray()
	for s in stops:
		offs.append(float(s[0]))
		cols.append(s[1])
	g.offsets = offs
	g.colors = cols
	return g


static func _curve(pts: Array) -> Curve:
	var c := Curve.new()
	for p in pts:
		c.add_point(Vector2(p[0], p[1]))
	return c


## Emissor de partículas configurável. cfg: tex, add, amount, life, shot, explode, size [min,max], curve [[t,s]...],
## colors [[t,Color]...], vel [min,max], dir, spread, gravity, shape ("point"/"sphere"/"ring"/"box"), r, box,
## damp [min,max], spin, local, dur (para emissores contínuos), mesh (malha em vez de sprite).
static func emit(host: Node, pos: Vector3, cfg: Dictionary) -> CPUParticles3D:
	if not _ok(host):
		return null
	var p := CPUParticles3D.new()
	p.amount = int(cfg.get("amount", 20))
	p.lifetime = float(cfg.get("life", 0.8))
	p.one_shot = bool(cfg.get("shot", true))
	p.explosiveness = float(cfg.get("explode", 1.0 if p.one_shot else 0.0))
	p.randomness = 0.4
	p.local_coords = bool(cfg.get("local", false))
	p.direction = cfg.get("dir", Vector3.UP)
	p.spread = float(cfg.get("spread", 180.0))
	p.gravity = cfg.get("gravity", Vector3.ZERO)
	var vel: Array = cfg.get("vel", [1.0, 3.0])
	p.initial_velocity_min = float(vel[0])
	p.initial_velocity_max = float(vel[1])
	var damp: Array = cfg.get("damp", [0.0, 0.0])
	p.damping_min = float(damp[0])
	p.damping_max = float(damp[1])
	var size: Array = cfg.get("size", [0.5, 1.0])
	p.scale_amount_min = float(size[0])
	p.scale_amount_max = float(size[1])
	p.scale_amount_curve = _curve(cfg.get("curve", [[0.0, 0.3], [0.2, 1.0], [1.0, 0.0]]))
	p.color_ramp = _grad(cfg.get("colors", [[0.0, Color(1, 1, 1, 1)], [1.0, Color(1, 1, 1, 0)]]))
	var spin := float(cfg.get("spin", 40.0))
	p.angle_min = 0.0
	p.angle_max = 360.0 if spin > 0.0 else 0.0   # spin 0 = sprites retos (chuva, colunas de luz)
	p.angular_velocity_min = -spin
	p.angular_velocity_max = spin
	match String(cfg.get("shape", "point")):
		"sphere":
			p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			p.emission_sphere_radius = float(cfg.get("r", 1.0))
		"ring":
			p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
			p.emission_ring_radius = float(cfg.get("r", 1.0))
			p.emission_ring_inner_radius = float(cfg.get("r_in", 0.0))
			p.emission_ring_height = 0.1
			p.emission_ring_axis = Vector3.UP
		"box":
			p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
			p.emission_box_extents = cfg.get("box", Vector3.ONE)
	if cfg.has("mesh"):
		p.mesh = cfg["mesh"]
	else:
		var q := QuadMesh.new()
		q.size = cfg.get("quad", Vector2.ONE)
		q.center_offset = Vector3(0, q.size.y * 0.35, 0) if cfg.has("quad") else Vector3.ZERO
		q.material = sprite_mat(String(cfg.get("tex", "soft")), bool(cfg.get("add", true)))
		p.mesh = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	host.add_child(p)
	p.global_position = pos
	p.emitting = true
	var total := float(cfg.get("dur", 0.0)) + p.lifetime + 0.3
	if not p.one_shot and cfg.has("dur"):
		host.get_tree().create_timer(float(cfg["dur"])).timeout.connect(func() -> void:
			if is_instance_valid(p):
				p.emitting = false)
	host.get_tree().create_timer(total).timeout.connect(func() -> void:
		if is_instance_valid(p):
			p.queue_free())
	return p


static func light(host: Node, pos: Vector3, col: Color, energy: float, rng: float, time: float, flicker: bool = false) -> OmniLight3D:
	if not _ok(host):
		return null
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	l.shadow_enabled = false
	host.add_child(l)
	l.global_position = pos
	var tw := l.create_tween()
	if flicker:
		var steps := int(time / 0.08)
		for i in steps:
			tw.tween_property(l, "light_energy", energy * randf_range(0.55, 1.15), 0.08)
	tw.tween_property(l, "light_energy", 0.0, 0.25 if flicker else time)
	tw.tween_callback(l.queue_free)
	return l


## Onda de choque: anel brilhante que se abre no chão.
static func shockwave(host: Node, pos: Vector3, col: Color, radius: float, time: float = 0.45) -> void:
	if not _ok(host):
		return
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(2, 2)
	mi.mesh = pm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.albedo_texture = tex("ring")
	m.albedo_color = Color(col.r * 0.8, col.g * 0.8, col.b * 0.8, 0.4)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	host.add_child(mi)
	mi.global_position = pos + Vector3(0, 0.08, 0)
	mi.scale = Vector3.ONE * radius * 0.15
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * radius, time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(m, "albedo_color:a", 0.0, time).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(mi.queue_free)


## Aviso discreto de área (anel que pulsa) — mais leve que o Fx.telegraph para as skills novas.
static func marker(host: Node, pos: Vector3, col: Color, radius: float, time: float) -> void:
	if not _ok(host):
		return
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(2, 2)
	mi.mesh = pm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.albedo_texture = tex("ring")
	m.albedo_color = Color(col.r, col.g, col.b, 0.0)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	host.add_child(mi)
	mi.global_position = pos + Vector3(0, 0.07, 0)
	mi.scale = Vector3.ONE * radius
	var tw := mi.create_tween()
	tw.tween_property(m, "albedo_color:a", 0.22, 0.15)
	tw.tween_property(m, "albedo_color:a", 0.1, maxf(0.05, time - 0.4))
	tw.tween_property(m, "albedo_color:a", 0.0, 0.25)
	tw.tween_callback(mi.queue_free)


## Marca no chão (Decal) que aparece, fica e some. emis = textura de brilho opcional (rachaduras em brasa).
static func ground_mark(host: Node, pos: Vector3, tex_name: String, size: float, life: float, emis_name: String = "", emis_energy: float = 3.0, grow: float = 0.0, tint: Color = Color(1, 1, 1)) -> Decal:
	if not _ok(host):
		return null
	var d := Decal.new()
	d.size = Vector3(size, 4.0, size)
	d.texture_albedo = tex(tex_name)
	if emis_name != "":
		d.texture_emission = tex(emis_name)
		d.emission_energy = emis_energy
	d.upper_fade = 0.3
	d.lower_fade = 0.3
	d.modulate = tint
	host.add_child(d)
	d.global_position = pos + Vector3(0, 0.5, 0)
	d.rotation.y = randf() * TAU
	var tw := d.create_tween()
	if grow > 0.0:
		d.scale = Vector3(0.1, 1, 0.1)
		tw.tween_property(d, "scale", Vector3.ONE, grow).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	tw.tween_interval(maxf(0.1, life - grow - 1.2))
	tw.tween_property(d, "modulate:a", 0.0, 1.2)
	if emis_name != "":
		tw.parallel().tween_property(d, "emission_energy", 0.0, 1.0)
	tw.tween_callback(d.queue_free)
	return d


# =================================================================== explosão de fogo

## fogo "de verdade": misturado (não somado), do amarelo ao vermelho escuro, para não virar uma bola branca de brilho
const FIRE := [[0.0, Color(1.0, 0.9, 0.55, 0.0)], [0.08, Color(1.0, 0.82, 0.35, 0.95)], [0.35, Color(1.0, 0.45, 0.1, 0.9)],
		[0.7, Color(0.6, 0.15, 0.05, 0.6)], [1.0, Color(0.15, 0.08, 0.06, 0.0)]]
## brilho somado só no miolo do fogo
const FIRE_CORE := [[0.0, Color(1.0, 0.7, 0.3, 0.0)], [0.15, Color(1.0, 0.6, 0.25, 0.18)], [1.0, Color(1.0, 0.3, 0.05, 0.0)]]
const SMOKE := [[0.0, Color(0.25, 0.2, 0.18, 0.0)], [0.15, Color(0.22, 0.18, 0.16, 0.55)], [1.0, Color(0.12, 0.1, 0.1, 0.0)]]
const EMBER := [[0.0, Color(1.0, 0.9, 0.5, 1.0)], [0.6, Color(1.0, 0.45, 0.1, 1.0)], [1.0, Color(0.6, 0.1, 0.0, 0.0)]]


static func explosion(host: Node, pos: Vector3, radius: float, scorch: bool = true) -> void:
	if not _ok(host):
		return
	var k := radius / 4.0
	light(host, pos + Vector3(0, 2.0, 0), Color(1.0, 0.6, 0.25), 2.2, radius * 2.2, 0.5)
	emit(host, pos + Vector3(0, 0.6, 0), {"tex": "smoke", "add": false, "amount": 30, "life": 0.8, "size": [1.4 * k, 2.6 * k],
			"vel": [radius * 0.8, radius * 1.8], "damp": [radius * 2.0, radius * 3.0], "gravity": Vector3(0, 4, 0),
			"colors": FIRE, "curve": [[0, 0.4], [0.25, 1.0], [1, 0.7]], "spin": 90.0})
	emit(host, pos + Vector3(0, 0.8, 0), {"tex": "soft", "amount": 8, "life": 0.45, "size": [1.0 * k, 1.8 * k],
			"vel": [radius * 0.4, radius * 1.0], "damp": [radius * 2.0, radius * 3.0], "colors": FIRE_CORE})
	emit(host, pos + Vector3(0, 0.8, 0), {"tex": "soft", "amount": 1, "life": 0.22, "size": [radius * 0.9, radius * 0.9],
			"vel": [0, 0], "colors": [[0, Color(1, 0.9, 0.7, 0.45)], [1, Color(1, 0.6, 0.2, 0)]], "curve": [[0, 0.5], [1, 1.0]]})
	emit(host, pos + Vector3(0, 1.0, 0), {"tex": "smoke", "add": false, "amount": 18, "life": 2.0, "size": [2.0 * k, 3.6 * k],
			"vel": [1.0, radius * 0.7], "damp": [1.5, 2.5], "gravity": Vector3(0, 1.6, 0), "colors": SMOKE,
			"curve": [[0, 0.4], [1, 1.2]], "spin": 20.0, "explode": 0.8})
	emit(host, pos + Vector3(0, 0.4, 0), {"tex": "dot", "amount": 40, "life": 1.3, "size": [0.12, 0.25],
			"vel": [radius * 1.2, radius * 2.6], "gravity": Vector3(0, -9, 0), "colors": EMBER, "spread": 75.0,
			"curve": [[0, 1], [1, 0.3]]})
	var rock := SphereMesh.new()
	rock.radius = 0.16
	rock.height = 0.26
	rock.radial_segments = 5
	rock.rings = 3
	rock.material = rock_mat()
	emit(host, pos + Vector3(0, 0.3, 0), {"mesh": rock, "amount": 16, "life": 1.1, "size": [0.6, 1.6],
			"vel": [radius * 1.2, radius * 2.2], "gravity": Vector3(0, -22, 0), "spread": 55.0, "spin": 300.0,
			"curve": [[0, 1], [0.85, 1], [1, 0]], "colors": [[0, Color(1, 1, 1)], [1, Color(1, 1, 1)]]})
	shockwave(host, pos, Color(1.0, 0.65, 0.3), radius * 1.3, 0.5)
	if scorch:
		ground_mark(host, pos, "scorch", radius * 2.3, 6.0)


# =================================================================== fogo contínuo

static func fire_column(host: Node, pos: Vector3, height: float, dur: float, width: float = 0.7) -> void:
	if not _ok(host):
		return
	emit(host, pos, {"tex": "flame", "add": false, "shot": false, "amount": 34, "life": 0.75, "dur": dur, "quad": Vector2(0.6, 1.1),
			"size": [width * 0.9, width * 1.6], "shape": "sphere", "r": width * 0.45, "vel": [height * 0.5, height * 1.0],
			"dir": Vector3.UP, "spread": 10.0, "gravity": Vector3(0, 1.5, 0), "colors": FIRE,
			"curve": [[0, 0.6], [0.3, 1.0], [1, 0.25]], "spin": 8.0})
	emit(host, pos + Vector3(0, height * 0.2, 0), {"tex": "soft", "shot": false, "amount": 6, "life": 0.5, "dur": dur,
			"size": [width * 1.6, width * 2.2], "vel": [0.2, 0.6], "colors": FIRE_CORE})
	emit(host, pos + Vector3(0, height * 0.6, 0), {"tex": "smoke", "add": false, "shot": false, "amount": 8, "life": 1.6,
			"dur": dur, "size": [width * 1.6, width * 2.6], "vel": [1.0, 2.0], "dir": Vector3.UP, "spread": 25.0,
			"colors": SMOKE, "curve": [[0, 0.5], [1, 1.3]], "spin": 15.0})
	emit(host, pos, {"tex": "dot", "shot": false, "amount": 10, "life": 1.4, "dur": dur, "size": [0.08, 0.16],
			"vel": [height * 1.5, height * 3.0], "dir": Vector3.UP, "spread": 30.0, "gravity": Vector3(0, -2, 0),
			"colors": EMBER, "curve": [[0, 1], [1, 0.2]]})


# =================================================================== raio

## Caminho em zigue-zague (deslocamento do ponto médio).
static func _zigzag(a: Vector3, b: Vector3, rough: float, depth: int) -> PackedVector3Array:
	var pts := PackedVector3Array([a, b])
	for d in depth:
		var out := PackedVector3Array()
		for i in pts.size() - 1:
			var p0 := pts[i]
			var p1 := pts[i + 1]
			var seg := p1 - p0
			var perp := seg.cross(Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5)).normalized()
			out.append(p0)
			out.append((p0 + p1) * 0.5 + perp * seg.length() * rough * randf_range(-1.0, 1.0))
		out.append(pts[pts.size() - 1])
		pts = out
	return pts


## Fita virada para a câmera ao longo dos pontos.
static func _ribbon(st: SurfaceTool, pts: PackedVector3Array, width: float, view: Vector3) -> void:
	for i in pts.size() - 1:
		var p0 := pts[i]
		var p1 := pts[i + 1]
		var side := (p1 - p0).cross(view).normalized() * width * 0.5
		var w0 := 1.0 - float(i) / pts.size() * 0.5
		var w1 := 1.0 - float(i + 1) / pts.size() * 0.5
		st.set_uv(Vector2(0, 0)); st.add_vertex(p0 - side * w0)
		st.set_uv(Vector2(1, 0)); st.add_vertex(p0 + side * w0)
		st.set_uv(Vector2(1, 1)); st.add_vertex(p1 + side * w1)
		st.set_uv(Vector2(0, 0)); st.add_vertex(p0 - side * w0)
		st.set_uv(Vector2(1, 1)); st.add_vertex(p1 + side * w1)
		st.set_uv(Vector2(0, 1)); st.add_vertex(p1 - side * w1)


static func _bolt_mesh(a: Vector3, b: Vector3, width: float, view: Vector3, branches: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var main := _zigzag(a, b, 0.22, 5)
	_ribbon(st, main, width, view)
	for i in branches:
		var k := randi_range(4, main.size() - 6)
		var from := main[k]
		var dir := (b - a).normalized().rotated(Vector3.UP, randf_range(-1.2, 1.2)) + Vector3(0, -0.3, 0)
		var to := from + dir.normalized() * (a.distance_to(b) * randf_range(0.15, 0.35))
		_ribbon(st, _zigzag(from, to, 0.3, 3), width * 0.55, view)
	return st.commit()


## Raio de a até b: brilho largo colorido + núcleo branco, com galhos, piscando e sumindo.
static func bolt(host: Node, a: Vector3, b: Vector3, col: Color, width: float = 0.5, time: float = 0.35, branches: int = 3) -> void:
	if not _ok(host):
		return
	var cam := host.get_viewport().get_camera_3d()
	var view := -cam.global_transform.basis.z if cam != null else Vector3(0.5, -0.7, -0.5).normalized()
	var root := Node3D.new()
	host.add_child(root)
	var layers := []
	for li in 2:
		var mi := MeshInstance3D.new()
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.albedo_texture = tex("beam")
		m.albedo_color = col * Color(0.75, 0.75, 0.8, 0.85) if li == 0 else Color(1.0, 1.0, 1.05, 1.0)
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
		layers.append([mi, m, width * (2.2 if li == 0 else 0.55)])
	var regen := func() -> void:
		if not is_instance_valid(root):
			return
		seed(randi())
		var s := randi()
		for L in layers:
			seed(s)   # os dois tons seguem o mesmo caminho
			(L[0] as MeshInstance3D).mesh = _bolt_mesh(a, b, float(L[2]), view, branches)
	regen.call()
	var tw := root.create_tween()
	for i in 3:
		tw.tween_interval(time * 0.18)
		tw.tween_callback(regen)
	for L in layers:
		tw.parallel().tween_property(L[1], "albedo_color:a", 0.0, time * 0.45).set_delay(time * 0.4)
	tw.tween_callback(root.queue_free)
	emit(host, b, {"tex": "dot", "amount": 18, "life": 0.45, "size": [0.08, 0.18], "vel": [4.0, 9.0], "gravity": Vector3(0, -6, 0),
			"colors": [[0, Color(1, 1, 1, 1)], [0.4, col], [1, Color(col.r, col.g, col.b, 0)]], "curve": [[0, 1], [1, 0]]})
	emit(host, b, {"tex": "soft", "amount": 1, "life": 0.2, "size": [1.6, 1.6], "vel": [0, 0],
			"colors": [[0, Color(1, 1, 1, 0.55)], [1, Color(col.r, col.g, col.b, 0)]], "curve": [[0, 0.6], [1, 1.0]]})
	light(host, b + Vector3(0, 1.0, 0), col, 2.0, 6.0, time)


# =================================================================== gelo

## Estaca de gelo que cai do céu, estilhaça e deixa geada.
static func ice_fall(host: Node, target: Vector3, delay: float, size: float = 1.0) -> void:
	if not _ok(host):
		return
	var node := Node3D.new()
	host.add_child(node)
	var shard := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = 0.45 * size
	cm.height = 2.6 * size
	cm.radial_segments = 6
	cm.rings = 1
	shard.mesh = cm
	shard.material_override = ice_mat()
	shard.rotation_degrees.x = 180.0       # ponta para baixo
	node.add_child(shard)
	for k in 3:   # cristais menores grudados
		var small := MeshInstance3D.new()
		var c2 := CylinderMesh.new()
		c2.top_radius = 0.0
		c2.bottom_radius = 0.2 * size
		c2.height = 1.2 * size
		c2.radial_segments = 5
		small.mesh = c2
		small.material_override = ice_mat()
		small.position = Vector3(cos(k * 2.1) * 0.3, 0.5, sin(k * 2.1) * 0.3) * size
		small.rotation = Vector3(PI + randf_range(-0.5, 0.5), 0, randf_range(-0.5, 0.5))
		node.add_child(small)
	var start := target + Vector3(randf_range(-2.5, 2.5), 18.0, randf_range(-2.5, 2.5))
	node.global_position = start
	node.look_at(target, Vector3.FORWARD)
	node.rotate_object_local(Vector3.RIGHT, -PI / 2.0)
	var trail := emit(host, start, {"tex": "smoke", "add": false, "shot": false, "amount": 24, "life": 0.5, "dur": delay,
			"size": [0.6 * size, 1.1 * size], "vel": [0.2, 0.8], "local": false,
			"colors": [[0, Color(0.6, 0.72, 0.85, 0.0)], [0.2, Color(0.6, 0.72, 0.85, 0.3)], [1, Color(0.5, 0.65, 0.8, 0.0)]]})
	var fall := func(t: float) -> void:
		var p := start.lerp(target + Vector3(0, 0.6, 0), t * t)
		node.global_position = p
		if is_instance_valid(trail):
			trail.global_position = p
	var hit := func() -> void:
		node.queue_free()
		_ice_impact(host, target, size)
	var tw := node.create_tween()
	tw.tween_method(fall, 0.0, 1.0, delay)
	tw.tween_callback(hit)


static func _ice_impact(host: Node, at: Vector3, size: float) -> void:
	if not _ok(host):
		return
	var piece := CylinderMesh.new()
	piece.top_radius = 0.0
	piece.bottom_radius = 0.12
	piece.height = 0.45
	piece.radial_segments = 4
	piece.material = ice_mat()
	emit(host, at + Vector3(0, 0.4, 0), {"mesh": piece, "amount": 22, "life": 0.9, "size": [0.6 * size, 1.4 * size],
			"vel": [4.0, 9.0], "gravity": Vector3(0, -20, 0), "spread": 70.0, "spin": 400.0,
			"curve": [[0, 1], [0.8, 1], [1, 0]], "colors": [[0, Color(1, 1, 1)], [1, Color(1, 1, 1)]]})
	emit(host, at + Vector3(0, 0.5, 0), {"tex": "smoke", "add": false, "amount": 9, "life": 1.1, "size": [1.4 * size, 2.4 * size],
			"vel": [2.0, 5.0], "damp": [2.5, 4.0], "spread": 80.0, "gravity": Vector3(0, 0.5, 0),
			"colors": [[0, Color(0.62, 0.74, 0.86, 0.0)], [0.1, Color(0.6, 0.72, 0.85, 0.3)], [1, Color(0.5, 0.65, 0.8, 0.0)]],
			"curve": [[0, 0.5], [1, 1.3]], "spin": 25.0})
	emit(host, at + Vector3(0, 0.6, 0), {"tex": "dot", "amount": 26, "life": 0.7, "size": [0.06, 0.14], "vel": [3.0, 8.0],
			"gravity": Vector3(0, -4, 0), "colors": [[0, Color(1, 1, 1, 1)], [1, Color(0.6, 0.85, 1.0, 0)]], "curve": [[0, 1], [1, 0]]})
	shockwave(host, at, Color(0.6, 0.9, 1.0), 3.5 * size, 0.4)
	light(host, at + Vector3(0, 1.5, 0), Color(0.55, 0.85, 1.0), 1.6, 5.0 * size, 0.4)
	ground_mark(host, at, "frost", 2.6 * size, 4.0)


# =================================================================== meteoro

static func meteor(host: Node, target: Vector3, delay: float, radius: float) -> void:
	if not _ok(host):
		return
	var node := Node3D.new()
	host.add_child(node)
	var core := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.7
	sm.height = 1.3
	sm.radial_segments = 8
	sm.rings = 5
	core.mesh = sm
	core.material_override = lava_rock_mat()
	node.add_child(core)
	var glow := emit(node, Vector3.ZERO, {"tex": "soft", "shot": false, "amount": 4, "life": 0.25, "dur": delay + 0.1,
			"size": [3.2, 3.8], "vel": [0, 0], "local": true,
			"colors": [[0, Color(1.0, 0.7, 0.3, 0.8)], [1, Color(1.0, 0.4, 0.1, 0.0)]], "curve": [[0, 1], [1, 1]]})
	var start := target + Vector3(-10.0 + randf_range(-2, 2), 22.0, -10.0 + randf_range(-2, 2))
	node.global_position = start
	var fire := emit(host, start, {"tex": "smoke", "add": false, "shot": false, "amount": 40, "life": 0.55, "dur": delay,
			"size": [1.2, 2.2], "shape": "sphere", "r": 0.4, "vel": [0.5, 2.0], "colors": FIRE, "spin": 90.0,
			"curve": [[0, 1], [1, 0.3]]})
	var smoke := emit(host, start, {"tex": "smoke", "add": false, "shot": false, "amount": 20, "life": 1.4, "dur": delay,
			"size": [1.2, 2.2], "vel": [0.2, 0.8], "colors": SMOKE, "curve": [[0, 0.6], [1, 1.4]], "spin": 20.0})
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.55, 0.2)
	l.light_energy = 1.2
	l.omni_range = 6.0
	node.add_child(l)
	var fall := func(t: float) -> void:
		var p := start.lerp(target + Vector3(0, 0.5, 0), t * t)
		node.global_position = p
		core.rotation += Vector3(0.2, 0.3, 0.1)
		for e in [fire, smoke]:
			if is_instance_valid(e):
				(e as Node3D).global_position = p
	var hit := func() -> void:
		if is_instance_valid(glow):
			glow.queue_free()
		node.queue_free()
		explosion(host, target, radius)
	var tw := node.create_tween()
	tw.tween_method(fall, 0.0, 1.0, delay)
	tw.tween_callback(hit)


# =================================================================== pisão da morte (fenda em chamas)

static func fissure(host: Node, at: Vector3, radius: float, dur: float) -> void:
	if not _ok(host):
		return
	shockwave(host, at, Color(1.0, 0.55, 0.25), radius * 1.4, 0.55)
	emit(host, at + Vector3(0, 0.3, 0), {"tex": "smoke", "add": false, "amount": 30, "life": 1.2, "size": [1.5, 3.0],
			"shape": "ring", "r": radius * 0.4, "vel": [radius * 1.2, radius * 2.0], "damp": [radius * 1.5, radius * 2.2],
			"dir": Vector3.UP, "spread": 85.0, "colors": [[0, Color(0.5, 0.42, 0.35, 0.0)], [0.15, Color(0.45, 0.38, 0.32, 0.6)], [1, Color(0.3, 0.26, 0.22, 0.0)]],
			"curve": [[0, 0.5], [1, 1.3]], "spin": 25.0})
	var rock := BoxMesh.new()
	rock.size = Vector3(0.35, 0.25, 0.3)
	rock.material = rock_mat()
	emit(host, at, {"mesh": rock, "amount": 26, "life": 1.2, "size": [0.6, 1.5], "shape": "ring", "r": radius * 0.5,
			"vel": [6.0, 11.0], "dir": Vector3.UP, "spread": 25.0, "gravity": Vector3(0, -24, 0), "spin": 360.0,
			"curve": [[0, 1], [0.85, 1], [1, 0]], "colors": [[0, Color(1, 1, 1)], [1, Color(1, 1, 1)]]})
	ground_mark(host, at, "crack", radius * 2.4, dur + 1.5, "crack_glow", 0.7, 0.35)
	light(host, at + Vector3(0, 1.2, 0), Color(1.0, 0.45, 0.15), 1.8, radius * 1.6, dur, true)
	fire_column(host, at, 2.2, dur, 1.4)
	for i in 7:
		var a := TAU * i / 7.0 + randf_range(-0.2, 0.2)
		var p := at + Vector3(cos(a), 0, sin(a)) * radius * randf_range(0.35, 0.8)
		host.get_tree().create_timer(0.1 + i * 0.05).timeout.connect(func() -> void:
			fire_column(host, p, randf_range(1.0, 1.8), dur - 0.2, 0.7))


# =================================================================== natureza (skills antigas da Druida)

const LEAF := [[0.0, Color(0.55, 0.85, 0.3, 0.0)], [0.1, Color(0.5, 0.8, 0.28, 1.0)], [0.8, Color(0.35, 0.6, 0.2, 1.0)], [1.0, Color(0.3, 0.5, 0.15, 0.0)]]


## Folhas voando (redemoinho que sobe e cai).
static func leaves(host: Node, pos: Vector3, amount: int = 24, speed: float = 5.0, life: float = 1.6, cols: Array = LEAF) -> void:
	emit(host, pos, {"tex": "leaf", "add": false, "amount": amount, "life": life, "size": [0.25, 0.45], "vel": [speed * 0.5, speed],
			"gravity": Vector3(0, -3.5, 0), "damp": [1.0, 2.0], "spread": 70.0, "spin": 360.0, "colors": cols,
			"curve": [[0, 1], [1, 0.8]], "explode": 0.85})


## Chamado das Raízes: fendas verdes no chão, poeira, folhas e brilho verde subindo enquanto dura.
static func roots(host: Node, at: Vector3, r: float, dur: float) -> void:
	if not _ok(host):
		return
	ground_mark(host, at, "crack", r * 2.2, dur + 1.0, "crack_white", 0.28, 0.3, Color(0.45, 0.85, 0.3))
	shockwave(host, at, Color(0.45, 0.8, 0.3), r * 1.2, 0.45)
	emit(host, at + Vector3(0, 0.3, 0), {"tex": "smoke", "add": false, "amount": 16, "life": 1.1, "size": [1.2, 2.4],
			"shape": "ring", "r": r * 0.5, "vel": [1.5, 3.5], "dir": Vector3.UP, "spread": 70.0, "damp": [1.5, 2.5],
			"colors": [[0, Color(0.45, 0.36, 0.26, 0.0)], [0.15, Color(0.42, 0.34, 0.25, 0.5)], [1, Color(0.3, 0.25, 0.2, 0.0)]],
			"curve": [[0, 0.5], [1, 1.3]], "spin": 25.0})
	leaves(host, at + Vector3(0, 0.4, 0), 30, 6.0, 1.8)
	emit(host, at + Vector3(0, 0.2, 0), {"tex": "dot", "shot": false, "amount": 26, "life": 1.4, "dur": dur, "size": [0.08, 0.16],
			"shape": "sphere", "r": r * 0.8, "vel": [0.6, 1.6], "dir": Vector3.UP, "spread": 15.0,
			"colors": [[0, Color(0.5, 0.85, 0.3, 0.0)], [0.3, Color(0.5, 0.85, 0.3, 0.8)], [1, Color(0.4, 0.7, 0.2, 0.0)]]})
	light(host, at + Vector3(0, 1.0, 0), Color(0.5, 0.9, 0.35), 0.6, r * 1.2, dur, true)


## Bênção da Flora: círculo de luz verde no chão, luzinhas subindo e pétalas caindo enquanto dura.
static func heal_field(host: Node, at: Vector3, r: float, dur: float) -> void:
	if not _ok(host):
		return
	marker(host, at, Color(0.5, 1.0, 0.55), r, dur)
	shockwave(host, at, Color(0.5, 1.0, 0.55), r, 0.6)
	emit(host, at + Vector3(0, 0.1, 0), {"tex": "dot", "shot": false, "amount": 46, "life": 1.8, "dur": dur, "size": [0.08, 0.2],
			"shape": "ring", "r": r * 0.9, "r_in": 0.0, "vel": [1.0, 2.4], "dir": Vector3.UP, "spread": 8.0,
			"colors": [[0, Color(0.6, 1.0, 0.6, 0.0)], [0.2, Color(0.55, 0.95, 0.55, 0.75)], [1, Color(0.8, 1.0, 0.7, 0.0)]]})
	emit(host, at + Vector3(0, 4.5, 0), {"tex": "leaf", "add": false, "shot": false, "amount": 20, "life": 3.2, "dur": dur,
			"size": [0.18, 0.3], "shape": "box", "box": Vector3(r * 0.8, 0.2, r * 0.8), "vel": [0.2, 0.6], "dir": Vector3.DOWN,
			"gravity": Vector3(0, -1.2, 0), "spin": 200.0,
			"colors": [[0, Color(1.0, 0.8, 0.9, 0.0)], [0.1, Color(1.0, 0.8, 0.9, 0.9)], [0.85, Color(0.95, 0.75, 0.85, 0.9)], [1, Color(1, 0.8, 0.9, 0.0)]]})
	light(host, at + Vector3(0, 1.5, 0), Color(0.5, 1.0, 0.55), 0.5, r * 1.2, dur)


## Pulso de cura no herói (a cada tique da Bênção).
static func heal_pulse(host: Node, at: Vector3) -> void:
	shockwave(host, at, Color(0.5, 1.0, 0.55), 1.6, 0.35)
	emit(host, at + Vector3(0, 1.0, 0), {"tex": "dot", "amount": 8, "life": 0.7, "size": [0.1, 0.2], "shape": "sphere", "r": 0.5,
			"vel": [1.0, 2.0], "dir": Vector3.UP, "spread": 30.0,
			"colors": [[0, Color(0.7, 1.0, 0.7, 0.9)], [1, Color(0.5, 1.0, 0.5, 0.0)]]})


## Casca de Carvalho: lascas de madeira voando e folhas girando em volta do herói enquanto dura.
static func bark_aura(p: Node3D, dur: float) -> void:
	if not _ok(p):
		return
	var host := p.get_parent()
	var chip := BoxMesh.new()
	chip.size = Vector3(0.16, 0.06, 0.1)
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0.5, 0.33, 0.17)
	chip.material = cm
	emit(host, p.global_position + Vector3(0, 1.0, 0), {"mesh": chip, "amount": 22, "life": 0.9, "size": [0.7, 1.4], "vel": [4.0, 8.0],
			"gravity": Vector3(0, -16, 0), "spin": 500.0, "curve": [[0, 1], [0.8, 1], [1, 0]],
			"colors": [[0, Color(1, 1, 1)], [1, Color(1, 1, 1)]]})
	shockwave(host, p.global_position, Color(0.75, 0.55, 0.3), 3.0, 0.4)
	var e := emit(p, p.global_position + Vector3(0, 0.2, 0), {"tex": "leaf", "add": false, "shot": false, "local": true, "amount": 18,
			"life": 1.4, "dur": dur, "size": [0.22, 0.36], "shape": "ring", "r": 1.15, "r_in": 1.0, "vel": [0.6, 1.4],
			"dir": Vector3.UP, "spread": 10.0, "spin": 250.0, "colors": LEAF})
	if e != null:
		e.tangential_accel_min = 6.0
		e.tangential_accel_max = 9.0


## Fúria dos Ventos: rajada que acompanha o projétil (redemoinhos claros + folhas).
static func wind_trail(proj: Node3D, col: Color) -> void:
	emit(proj, proj.global_position, {"tex": "smoke", "shot": false, "amount": 40, "life": 0.45, "size": [0.9, 1.7],
			"shape": "sphere", "r": 0.5, "vel": [0.2, 1.0], "spin": 220.0,
			"colors": [[0, Color(col.r, col.g, col.b, 0.0)], [0.2, Color(col.r * 0.7, col.g * 0.75, col.b * 0.7, 0.35)], [1, Color(col.r, col.g, col.b, 0.0)]],
			"curve": [[0, 0.4], [1, 1.4]]})
	emit(proj, proj.global_position, {"tex": "leaf", "add": false, "shot": false, "amount": 14, "life": 0.7, "size": [0.2, 0.32],
			"shape": "sphere", "r": 0.7, "vel": [0.5, 2.0], "spin": 500.0, "colors": LEAF})


## Despertar Lendário: coluna de luz dourada, duas ondas de choque, faíscas de sol subindo e marca dourada no chão.
static func radiance(host: Node, at: Vector3, r: float) -> void:
	if not _ok(host):
		return
	var gold := Color(1.0, 0.82, 0.35)
	emit(host, at + Vector3(0, 0.2, 0), {"tex": "beam", "amount": 3, "life": 1.0, "quad": Vector2(2.6, 18.0), "size": [1.0, 1.3],
			"vel": [0, 0], "spin": 0.0, "colors": [[0, Color(1, 0.85, 0.45, 0.0)], [0.15, Color(0.8, 0.65, 0.3, 0.7)], [1, Color(0.8, 0.6, 0.2, 0.0)]],
			"curve": [[0, 0.3], [0.2, 1.0], [1, 1.2]]})
	shockwave(host, at, gold, r, 0.6)
	host.get_tree().create_timer(0.18).timeout.connect(func() -> void: shockwave(host, at, Color(1.0, 0.95, 0.7), r * 0.6, 0.5))
	emit(host, at + Vector3(0, 0.3, 0), {"tex": "dot", "amount": 70, "life": 1.6, "size": [0.1, 0.22], "shape": "sphere", "r": r * 0.5,
			"vel": [2.0, 6.0], "dir": Vector3.UP, "spread": 25.0, "damp": [0.5, 1.5],
			"colors": [[0, Color(1.0, 0.95, 0.7, 1.0)], [0.5, Color(1.0, 0.75, 0.3, 0.9)], [1, Color(1.0, 0.6, 0.2, 0.0)]]})
	marker(host, at, gold, r, 1.4)
	light(host, at + Vector3(0, 3.0, 0), gold, 1.6, r * 1.4, 0.8)

# =================================================================== sombras (Assassino)

const SHADOW := [[0.0, Color(0.12, 0.05, 0.18, 0.0)], [0.12, Color(0.1, 0.04, 0.16, 0.75)], [1.0, Color(0.05, 0.02, 0.08, 0.0)]]


## Nuvem de sombra (teleporte, clones, invisibilidade).
static func shadow_puff(host: Node, pos: Vector3, s: float = 1.0, col: Color = Color(0.55, 0.3, 0.95)) -> void:
	if not _ok(host):
		return
	emit(host, pos + Vector3(0, 0.9, 0), {"tex": "smoke", "add": false, "amount": int(14 * s), "life": 0.9, "size": [1.0 * s, 2.0 * s],
			"shape": "sphere", "r": 0.5 * s, "vel": [1.0, 3.0 * s], "damp": [2.0, 3.0], "colors": SHADOW,
			"curve": [[0, 0.5], [1, 1.3]], "spin": 60.0})
	emit(host, pos + Vector3(0, 1.0, 0), {"tex": "dot", "amount": int(16 * s), "life": 0.6, "size": [0.08, 0.16], "shape": "sphere", "r": 0.6 * s,
			"vel": [2.0, 5.0], "colors": [[0, Color(col.r, col.g, col.b, 0.9)], [1, Color(col.r * 0.5, col.g * 0.3, col.b * 0.6, 0.0)]]})
	shockwave(host, pos, col, 1.8 * s, 0.3)


## Explosão de sombra (Marca da Morte, fim do Eclipse).
static func shadow_burst(host: Node, pos: Vector3, r: float, col: Color = Color(0.6, 0.25, 1.0)) -> void:
	if not _ok(host):
		return
	emit(host, pos + Vector3(0, 0.8, 0), {"tex": "smoke", "add": false, "amount": 26, "life": 1.2, "size": [1.4, 2.8],
			"shape": "sphere", "r": 0.6, "vel": [r * 0.8, r * 1.6], "damp": [r * 1.4, r * 2.0], "colors": SHADOW,
			"curve": [[0, 0.5], [1, 1.4]], "spin": 70.0})
	emit(host, pos + Vector3(0, 0.9, 0), {"tex": "soft", "amount": 18, "life": 0.5, "size": [0.8, 1.6], "vel": [r * 0.6, r * 1.4],
			"damp": [r * 1.5, r * 2.0], "colors": [[0, Color(col.r * 0.8, col.g * 0.6, col.b * 0.85, 0.7)], [1, Color(col.r * 0.4, 0.05, col.b * 0.5, 0.0)]]})
	var shard := CylinderMesh.new()
	shard.top_radius = 0.0
	shard.bottom_radius = 0.1
	shard.height = 0.6
	shard.radial_segments = 4
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.08, 0.04, 0.12)
	sm.emission_enabled = true
	sm.emission = col * 0.6
	shard.material = sm
	emit(host, pos + Vector3(0, 0.6, 0), {"mesh": shard, "amount": 14, "life": 0.8, "size": [0.7, 1.4], "vel": [r * 1.2, r * 2.2],
			"gravity": Vector3(0, -14, 0), "spread": 70.0, "spin": 400.0, "curve": [[0, 1], [0.8, 1], [1, 0]],
			"colors": [[0, Color(1, 1, 1)], [1, Color(1, 1, 1)]]})
	shockwave(host, pos, col, r * 1.3, 0.45)
	ground_mark(host, pos, "scorch", r * 1.8, 4.0)
	light(host, pos + Vector3(0, 1.5, 0), col, 1.8, r * 1.6, 0.4)


## Sigilo girando sobre a cabeça do alvo (fica preso nele).
static func sigil(target: Node3D, height: float, col: Color, time: float) -> void:
	if not _ok(target):
		return
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(2.2, 2.2)
	mi.mesh = pm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.no_depth_test = true
	m.albedo_texture = tex("ring")
	m.albedo_color = Color(col.r * 0.8, col.g * 0.6, col.b * 0.85, 0.0)
	mi.material_override = m
	target.add_child(mi)
	mi.position = Vector3(0, height + 0.8, 0)
	var spin := mi.create_tween().set_loops()
	spin.tween_property(mi, "rotation:y", TAU, 0.8).from(0.0)
	var tw := mi.create_tween()
	tw.tween_property(m, "albedo_color:a", 0.9, 0.15)
	tw.parallel().tween_property(mi, "scale", Vector3.ONE * 0.45, time).from(Vector3.ONE * 1.3)
	tw.tween_callback(mi.queue_free)
	emit(target, target.global_position + Vector3(0, height + 0.8, 0), {"tex": "dot", "shot": false, "local": true, "amount": 10, "life": 0.5,
			"dur": time, "size": [0.06, 0.12], "shape": "ring", "r": 0.9, "vel": [0.2, 0.6], "dir": Vector3.DOWN,
			"colors": [[0, Color(col.r, col.g, col.b, 0.9)], [1, Color(col.r, col.g, col.b, 0.0)]]})


## Corte vermelho (Eclipse) com respingos.
static func blood_slash(host: Node, pos: Vector3, angle: float, r: float) -> void:
	if not _ok(host):
		return
	Fx.slash(host, pos, angle, r, 160.0, Color(0.85, 0.08, 0.12), 0.7, 0.22, randf() < 0.5)
	emit(host, pos, {"tex": "dot", "add": false, "amount": 12, "life": 0.6, "size": [0.08, 0.18], "vel": [3.0, 7.0],
			"gravity": Vector3(0, -14, 0), "spread": 80.0, "colors": [[0, Color(0.6, 0.02, 0.05, 1)], [1, Color(0.35, 0.0, 0.02, 0)]]})


## Cúpula de escuridão (Eclipse Sangrento).
static func dark_dome(host: Node, pos: Vector3, r: float, dur: float) -> void:
	if not _ok(host):
		return
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 1.2
	sm.radial_segments = 32
	sm.rings = 12
	mi.mesh = sm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.albedo_color = Color(0.06, 0.01, 0.06, 0.0)
	m.rim_enabled = false
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	host.add_child(mi)
	mi.global_position = pos
	mi.scale = Vector3.ONE * 0.2
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.parallel().tween_property(m, "albedo_color:a", 0.5, 0.3)
	tw.tween_interval(maxf(0.1, dur - 0.6))
	tw.tween_property(m, "albedo_color:a", 0.0, 0.3)
	tw.tween_callback(mi.queue_free)
	marker(host, pos, Color(0.9, 0.1, 0.15), r, dur)
	emit(host, pos + Vector3(0, 0.3, 0), {"tex": "dot", "shot": false, "amount": 40, "life": 1.2, "dur": dur, "size": [0.06, 0.14],
			"shape": "ring", "r": r * 0.95, "r_in": 0.0, "vel": [0.5, 2.0], "dir": Vector3.UP, "spread": 20.0,
			"colors": [[0, Color(0.9, 0.1, 0.15, 0.0)], [0.3, Color(0.8, 0.08, 0.12, 0.8)], [1, Color(0.4, 0.0, 0.05, 0.0)]]})


## Veneno nas lâminas: bolhas verdes subindo e gotas caindo em volta do herói.
static func poison_aura(p: Node3D, dur: float) -> void:
	if not _ok(p):
		return
	emit(p, p.global_position + Vector3(0, 1.0, 0), {"tex": "dot", "shot": false, "local": true, "amount": 16, "life": 0.9, "dur": dur,
			"size": [0.08, 0.18], "shape": "sphere", "r": 0.6, "vel": [0.4, 1.2], "dir": Vector3.UP, "spread": 30.0,
			"colors": [[0, Color(0.5, 1.0, 0.3, 0.0)], [0.3, Color(0.45, 0.95, 0.3, 0.75)], [1, Color(0.3, 0.7, 0.15, 0.0)]]})
	emit(p, p.global_position + Vector3(0, 1.1, 0), {"tex": "dot", "add": false, "shot": false, "local": true, "amount": 8, "life": 0.7,
			"dur": dur, "size": [0.06, 0.12], "shape": "sphere", "r": 0.5, "vel": [0.0, 0.3], "gravity": Vector3(0, -6, 0),
			"colors": [[0, Color(0.35, 0.85, 0.2, 0.9)], [1, Color(0.25, 0.6, 0.1, 0.0)]]})
	emit(p.get_parent(), p.global_position + Vector3(0, 0.8, 0), {"tex": "smoke", "add": false, "amount": 12, "life": 1.0, "size": [1.0, 1.8],
			"shape": "sphere", "r": 0.5, "vel": [1.0, 2.5], "damp": [1.5, 2.5],
			"colors": [[0, Color(0.3, 0.6, 0.15, 0.0)], [0.15, Color(0.28, 0.55, 0.14, 0.45)], [1, Color(0.2, 0.4, 0.1, 0.0)]]})


## Rastro roxo das adagas arremessadas.
static func dagger_trail(proj: Node3D, col: Color) -> void:
	emit(proj, proj.global_position, {"tex": "soft", "shot": false, "amount": 24, "life": 0.25, "size": [0.25, 0.45], "vel": [0, 0.2],
			"colors": [[0, Color(col.r * 0.8, col.g * 0.6, col.b * 0.85, 0.7)], [1, Color(col.r * 0.4, 0.05, col.b * 0.5, 0.0)]],
			"curve": [[0, 1], [1, 0.1]]})

# =================================================================== tecnologia (Mecânico)

const SPARK := [[0.0, Color(0.9, 0.95, 1.0, 1.0)], [0.4, Color(0.45, 0.75, 1.0, 0.9)], [1.0, Color(0.2, 0.4, 1.0, 0.0)]]


## Rastro de míssil: chama curta atrás + fumaça cinza que fica no ar.
static func rocket_trail(proj: Node3D) -> void:
	emit(proj, proj.global_position, {"tex": "soft", "shot": false, "amount": 30, "life": 0.18, "size": [0.35, 0.6], "vel": [0, 0.3],
			"colors": [[0, Color(1.0, 0.8, 0.4, 0.8)], [1, Color(1.0, 0.35, 0.1, 0.0)]], "curve": [[0, 1], [1, 0.2]]})
	emit(proj, proj.global_position, {"tex": "smoke", "add": false, "shot": false, "amount": 30, "life": 0.9, "size": [0.45, 0.9],
			"vel": [0.1, 0.5], "spin": 40.0, "colors": [[0, Color(0.55, 0.52, 0.5, 0.0)], [0.1, Color(0.5, 0.48, 0.46, 0.55)], [1, Color(0.4, 0.38, 0.36, 0.0)]],
			"curve": [[0, 0.5], [1, 1.6]]})


## Faíscas elétricas (curto-circuito, choque).
static func sparks(host: Node, pos: Vector3, amount: int = 18, speed: float = 7.0) -> void:
	emit(host, pos, {"tex": "dot", "amount": amount, "life": 0.45, "size": [0.06, 0.14], "vel": [speed * 0.5, speed],
			"gravity": Vector3(0, -10, 0), "colors": SPARK, "curve": [[0, 1], [1, 0.2]]})


## Jato de lança-chamas saindo do herói na direção dir por `dur` segundos (segue o herói).
static func flame_stream(p: Node3D, dir: Vector3, length: float, dur: float) -> void:
	if not _ok(p):
		return
	var host := p.get_parent()
	var node := Node3D.new()
	p.add_child(node)
	node.position = Vector3(0, 1.1, 0)
	node.look_at(node.global_position + dir, Vector3.UP)
	var speed := length / 0.45
	var e1 := emit(node, node.global_position, {"tex": "flame", "add": false, "shot": false, "amount": 80, "life": 0.5, "dur": dur,
			"size": [0.6, 1.8], "vel": [speed * 0.8, speed], "dir": Vector3.FORWARD, "spread": 9.0, "damp": [speed * 0.6, speed * 0.9],
			"gravity": Vector3(0, 2.5, 0), "curve": [[0, 0.3], [0.3, 1.0], [1, 1.3]], "spin": 120.0,
			"colors": [[0.0, Color(1.0, 0.75, 0.35, 0.0)], [0.08, Color(1.0, 0.55, 0.15, 0.95)], [0.4, Color(0.85, 0.25, 0.05, 0.9)],
					[0.75, Color(0.5, 0.12, 0.05, 0.55)], [1.0, Color(0.12, 0.07, 0.05, 0.0)]]})
	var e2 := emit(node, node.global_position, {"tex": "soft", "shot": false, "amount": 30, "life": 0.3, "dur": dur, "size": [0.4, 1.0],
			"vel": [speed * 0.9, speed], "dir": Vector3.FORWARD, "spread": 5.0, "damp": [speed * 0.8, speed],
			"colors": FIRE_CORE, "curve": [[0, 0.4], [1, 1.2]]})
	for e in [e1, e2]:
		if e != null:
			(e as CPUParticles3D).local_coords = false
	emit(node, node.global_position, {"tex": "smoke", "add": false, "shot": false, "amount": 18, "life": 1.2, "dur": dur, "size": [1.0, 2.0],
			"vel": [speed * 0.4, speed * 0.6], "dir": Vector3.FORWARD, "spread": 14.0, "damp": [speed * 0.4, speed * 0.5],
			"gravity": Vector3(0, 1.5, 0), "colors": SMOKE, "curve": [[0, 0.3], [1, 1.4]], "spin": 30.0})
	light(host, p.global_position + Vector3(0, 1.2, 0) + dir * length * 0.5, Color(1.0, 0.55, 0.2), 1.4, length * 1.2, dur, true)
	p.get_tree().create_timer(dur + 1.5).timeout.connect(func() -> void:
		if is_instance_valid(node):
			node.queue_free())


## Feixe orbital: aviso, depois uma coluna de energia desce do céu e queima o chão.
static func orbital_beam(host: Node, at: Vector3, r: float, delay: float, dur: float, col: Color) -> void:
	if not _ok(host):
		return
	marker(host, at, col, r, delay + dur)
	emit(host, at + Vector3(0, 0.1, 0), {"tex": "dot", "shot": false, "amount": 20, "life": 0.6, "dur": delay, "size": [0.06, 0.12],
			"shape": "ring", "r": r, "r_in": r * 0.9, "vel": [0.2, 0.6], "dir": Vector3.UP,
			"colors": [[0, Color(col.r, col.g, col.b, 0.0)], [0.3, Color(col.r * 0.8, col.g * 0.8, col.b * 0.85, 0.8)], [1, Color(col.r, col.g, col.b, 0.0)]]})
	host.get_tree().create_timer(delay).timeout.connect(func() -> void:
		if not _ok(host):
			return
		_beam_column(host, at, r * 0.55, Color(col.r * 0.6, col.g * 0.6, col.b * 0.75, 0.3), dur)
		_beam_column(host, at, r * 0.18, Color(0.85, 0.9, 1.0, 0.6), dur)
		sparks(host, at + Vector3(0, 0.3, 0), 50, 12.0)
		shockwave(host, at, col, r * 1.5, 0.5)
		emit(host, at + Vector3(0, 0.4, 0), {"tex": "smoke", "add": false, "amount": 22, "life": 1.5, "size": [1.4, 2.8], "shape": "ring", "r": r * 0.6,
				"vel": [r * 0.8, r * 1.5], "damp": [r * 1.2, r * 1.8], "dir": Vector3.UP, "spread": 80.0, "colors": SMOKE,
				"curve": [[0, 0.5], [1, 1.3]], "spin": 30.0})
		ground_mark(host, at, "scorch", r * 2.3, 6.0)
		light(host, at + Vector3(0, 2.0, 0), col, 2.5, r * 2.5, dur, true))


## Coluna de energia (cilindro aditivo) que surge do céu, pulsa e some.
static func _beam_column(host: Node, at: Vector3, radius: float, col: Color, dur: float) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = 40.0
	cm.radial_segments = 20
	cm.rings = 1
	cm.cap_top = false
	cm.cap_bottom = false
	mi.mesh = cm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(col.r, col.g, col.b, 0.0)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	host.add_child(mi)
	mi.global_position = at + Vector3(0, 20.0, 0)
	mi.scale = Vector3(0.2, 1, 0.2)
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE, 0.12).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(m, "albedo_color:a", col.a, 0.12)
	for i in int(dur / 0.1):
		tw.tween_property(mi, "scale", Vector3(randf_range(0.85, 1.1), 1, randf_range(0.85, 1.1)), 0.1)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.25)
	tw.parallel().tween_property(mi, "scale", Vector3(0.05, 1, 0.05), 0.25)
	tw.tween_callback(mi.queue_free)


## Pancada no chão (Colosso): poeira, pedras e onda de choque, sem fogo.
static func ground_slam(host: Node, at: Vector3, r: float, col: Color) -> void:
	if not _ok(host):
		return
	shockwave(host, at, col, r * 1.3, 0.5)
	shockwave(host, at, Color(1, 1, 1), r * 0.7, 0.35)
	emit(host, at + Vector3(0, 0.3, 0), {"tex": "smoke", "add": false, "amount": 28, "life": 1.3, "size": [1.4, 2.8], "shape": "ring", "r": r * 0.4,
			"vel": [r * 1.2, r * 2.0], "damp": [r * 1.5, r * 2.2], "dir": Vector3.UP, "spread": 85.0,
			"colors": [[0, Color(0.5, 0.42, 0.35, 0.0)], [0.15, Color(0.45, 0.38, 0.32, 0.55)], [1, Color(0.3, 0.26, 0.22, 0.0)]],
			"curve": [[0, 0.5], [1, 1.3]], "spin": 25.0})
	var rock := BoxMesh.new()
	rock.size = Vector3(0.35, 0.25, 0.3)
	rock.material = rock_mat()
	emit(host, at, {"mesh": rock, "amount": 24, "life": 1.1, "size": [0.6, 1.4], "shape": "ring", "r": r * 0.4, "vel": [6.0, 11.0],
			"dir": Vector3.UP, "spread": 30.0, "gravity": Vector3(0, -24, 0), "spin": 360.0,
			"curve": [[0, 1], [0.85, 1], [1, 0]], "colors": [[0, Color(1, 1, 1)], [1, Color(1, 1, 1)]]})
	ground_mark(host, at, "crack", r * 1.8, 4.0)
	light(host, at + Vector3(0, 1.5, 0), col, 1.6, r * 1.6, 0.4)

# =================================================================== água (Náutico)

const WATER := [[0.0, Color(0.3, 0.6, 0.85, 0.0)], [0.12, Color(0.25, 0.55, 0.82, 0.75)], [1.0, Color(0.15, 0.4, 0.7, 0.0)]]
const FOAM := [[0.0, Color(0.75, 0.88, 0.95, 0.0)], [0.12, Color(0.72, 0.86, 0.94, 0.7)], [1.0, Color(0.6, 0.78, 0.9, 0.0)]]
const DROP := [[0.0, Color(0.7, 0.88, 1.0, 0.95)], [1.0, Color(0.4, 0.7, 0.95, 0.0)]]


## Respingo de água (acertos, bolhas estourando, tentáculos).
static func splash(host: Node, pos: Vector3, s: float = 1.0) -> void:
	if not _ok(host):
		return
	emit(host, pos + Vector3(0, 0.3, 0), {"tex": "dot", "add": false, "amount": int(26 * s), "life": 0.8, "size": [0.08 * s, 0.2 * s],
			"vel": [3.0 * s, 7.0 * s], "dir": Vector3.UP, "spread": 50.0, "gravity": Vector3(0, -16, 0), "colors": DROP, "curve": [[0, 1], [1, 0.6]]})
	emit(host, pos + Vector3(0, 0.3, 0), {"tex": "smoke", "add": false, "amount": int(10 * s), "life": 0.7, "size": [0.8 * s, 1.6 * s],
			"vel": [1.5 * s, 3.0 * s], "damp": [2.0, 3.0], "spread": 70.0, "colors": FOAM, "curve": [[0, 0.5], [1, 1.2]], "spin": 40.0})
	shockwave(host, pos, Color(0.45, 0.8, 1.0), 2.2 * s, 0.35)


## Tsunami: parede de água que avança de `from` na direção `dir`.
static func wave(host: Node, from: Vector3, dir: Vector3, dist: float, time: float, width: float) -> void:
	if not _ok(host):
		return
	var node := Node3D.new()
	host.add_child(node)
	node.global_position = from
	node.look_at(from + dir, Vector3.UP)
	var box := Vector3(width * 0.5, 0.3, 0.4)
	emit(node, from + Vector3(0, 0.6, 0), {"tex": "smoke", "add": false, "shot": false, "amount": 90, "life": 0.55, "dur": time,
			"size": [1.2, 2.4], "shape": "box", "box": box, "vel": [2.0, 5.0], "dir": Vector3.UP, "spread": 25.0,
			"gravity": Vector3(0, -6, 0), "colors": WATER, "curve": [[0, 0.5], [0.3, 1.0], [1, 0.8]], "spin": 30.0})
	emit(node, from + Vector3(0, 1.6, 0), {"tex": "smoke", "add": false, "shot": false, "amount": 60, "life": 0.45, "dur": time,
			"size": [0.8, 1.6], "shape": "box", "box": box, "vel": [3.0, 6.0], "dir": Vector3.UP, "spread": 30.0,
			"gravity": Vector3(0, -9, 0), "colors": FOAM, "curve": [[0, 0.4], [1, 1.0]], "spin": 40.0})
	emit(node, from + Vector3(0, 1.8, 0), {"tex": "dot", "add": false, "shot": false, "amount": 60, "life": 0.7, "dur": time,
			"size": [0.08, 0.18], "shape": "box", "box": box, "vel": [4.0, 8.0], "dir": Vector3.UP, "spread": 40.0,
			"gravity": Vector3(0, -14, 0), "colors": DROP})
	var tw := node.create_tween()
	tw.tween_property(node, "global_position", from + dir * dist, time)
	tw.tween_interval(0.8)
	tw.tween_callback(node.queue_free)


## Bolha que prende o inimigo (fica presa nele) e estoura no fim.
static func bubble(target: Node3D, height: float, dur: float) -> void:
	if not _ok(target):
		return
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = maxf(0.9, height * 0.8)
	sm.height = sm.radius * 2.0
	sm.radial_segments = 24
	sm.rings = 12
	mi.mesh = sm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.55, 0.8, 1.0, 0.18)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.rim_enabled = true
	m.rim = 1.0
	m.rim_tint = 0.0
	m.emission_enabled = true
	m.emission = Color(0.2, 0.45, 0.7)
	m.emission_energy_multiplier = 0.5
	m.roughness = 0.05
	m.metallic_specular = 1.0
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	target.add_child(mi)
	mi.position = Vector3(0, height * 0.6, 0)
	mi.scale = Vector3.ONE * 0.2
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK)
	for i in int(dur / 0.4):
		tw.tween_property(mi, "scale", Vector3(1.05, 0.95, 1.05), 0.2)
		tw.tween_property(mi, "scale", Vector3(0.95, 1.05, 0.95), 0.2)
	tw.tween_callback(func() -> void:
		splash(target.get_parent(), mi.global_position - Vector3(0, 0.6, 0), 1.1)
		mi.queue_free())
	emit(target, target.global_position + Vector3(0, height * 0.3, 0), {"tex": "dot", "shot": false, "local": true, "amount": 8,
			"life": 0.9, "dur": dur, "size": [0.06, 0.14], "shape": "sphere", "r": 0.5, "vel": [0.5, 1.2], "dir": Vector3.UP,
			"colors": [[0, Color(0.8, 0.95, 1.0, 0.0)], [0.3, Color(0.75, 0.9, 1.0, 0.8)], [1, Color(0.6, 0.85, 1.0, 0.0)]]})


## Tempestade: nuvem escura no alto e chuva caindo na área enquanto dura.
static func storm(host: Node, at: Vector3, r: float, dur: float) -> void:
	if not _ok(host):
		return
	emit(host, at + Vector3(0, 9.0, 0), {"tex": "smoke", "add": false, "shot": false, "amount": 40, "life": 1.8, "dur": dur,
			"size": [3.5, 6.0], "shape": "box", "box": Vector3(r, 0.6, r), "vel": [0.2, 0.6], "spin": 10.0,
			"colors": [[0, Color(0.15, 0.17, 0.22, 0.0)], [0.2, Color(0.14, 0.16, 0.21, 0.7)], [0.8, Color(0.12, 0.14, 0.18, 0.7)], [1, Color(0.1, 0.1, 0.14, 0.0)]]})
	emit(host, at + Vector3(0, 8.0, 0), {"tex": "beam", "add": false, "shot": false, "amount": 120, "life": 0.5, "dur": dur, "quad": Vector2(0.05, 0.9),
			"size": [1.0, 1.0], "shape": "box", "box": Vector3(r, 0.2, r), "vel": [16.0, 18.0], "dir": Vector3.DOWN, "spread": 3.0, "spin": 0.0,
			"colors": [[0, Color(0.6, 0.75, 0.9, 0.0)], [0.1, Color(0.6, 0.75, 0.9, 0.5)], [1, Color(0.6, 0.75, 0.9, 0.5)]], "curve": [[0, 1], [1, 1]]})
	marker(host, at, Color(0.4, 0.6, 1.0), r, dur)


## Tentáculo do Kraken: sai do chão, se ergue e bate.
static func tentacle(host: Node, at: Vector3, height: float, face: Vector3) -> void:
	if not _ok(host):
		return
	var root := Node3D.new()
	host.add_child(root)
	root.global_position = at
	root.rotation.y = atan2(-face.x, -face.z)
	var segs := 7
	var parent: Node3D = root
	var skin := Color(0.35, 0.15, 0.45)
	var joints: Array[Node3D] = []
	for i in segs:
		var j := Node3D.new()
		j.position = Vector3(0, height / segs if i > 0 else 0.0, 0)
		parent.add_child(j)
		var rad_b := lerpf(0.5, 0.08, float(i) / segs)
		var rad_t := lerpf(0.5, 0.08, float(i + 1) / segs)
		j.add_child(Toon.part(Toon.cyl(rad_t, rad_b, height / segs, 10), skin, Vector3(0, height / segs * 0.5, 0), 0.025))
		if i % 2 == 0 and i < segs - 1:   # ventosas
			j.add_child(Toon.part(Toon.sphere(rad_b * 0.35, 8), Color(0.85, 0.65, 0.75), Vector3(0, height / segs * 0.5, -rad_b * 0.9), 0.0))
		joints.append(j)
		parent = j
	splash(host, at, 1.3)
	ground_mark(host, at, "crack", 3.0, 3.0)
	root.scale = Vector3(1, 0.05, 1)
	var curl := func(k: float) -> void:   # enrola para trás (preparando)
		for j in joints:
			j.rotation.x = 0.18 * k
	var whip := func(k: float) -> void:   # chicoteia para frente
		for j in joints:
			j.rotation.x = 0.18 - 0.42 * k
	var slam := func() -> void:
		splash(host, at - Vector3(sin(root.rotation.y), 0, cos(root.rotation.y)) * height * 0.8, 1.4)
	var tw := root.create_tween()
	tw.tween_property(root, "scale", Vector3.ONE, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_method(curl, 0.0, 1.0, 0.3)
	tw.tween_method(whip, 0.0, 1.0, 0.15)
	tw.tween_callback(slam)
	tw.tween_interval(0.4)
	tw.tween_property(root, "scale", Vector3(1, 0.05, 1), 0.3).set_ease(Tween.EASE_IN)
	tw.tween_callback(root.queue_free)