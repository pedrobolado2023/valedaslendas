class_name World
extends Node3D
## Monta um mapa aberto a partir de GameData.MAPS: chão pintado com trilhas, acampamento (NPC, portal, quadro),
## zonas de caça, lago/oásis/gelo/lava e vegetação. Também guarda a rede de trilhas (route()) usada pela
## seta-guia e pelo modo automático.

const SIZE := 300.0
const HALF := 108.0
const MASK_RES := 1024
const GRID_CELL := 2.0
const VILLAGE_R := 21.0

## Trilhas feitas à mão do Vale (os outros mapas geram as trilhas sozinhos a partir das zonas).
const VALE_ROADS := [
	[Vector2(0, 0), Vector2(10, 4), Vector2(22, 8), Vector2(34, 14), Vector2(46, 24), Vector2(58, 32), Vector2(70, 42)],
	[Vector2(0, 0), Vector2(-8, -6), Vector2(-18, -14), Vector2(-30, -22), Vector2(-44, -30), Vector2(-58, -40), Vector2(-70, -52)],
	[Vector2(0, 0), Vector2(4, -12), Vector2(12, -24), Vector2(24, -36), Vector2(36, -48), Vector2(48, -58), Vector2(60, -72)],
	[Vector2(0, 0), Vector2(-10, 8), Vector2(-22, 16), Vector2(-34, 26), Vector2(-40, 32)],
]

var map_id := "vale"
var map: Dictionary = {}
var theme: Dictionary = {}
var dense_roads: Array[PackedVector2Array] = []
var obstacles: StaticBody3D
var npc_pos := Vector3(4, 0, 7)
var portal_pos := Vector3(-9, 0, -2)
var board_pos := Vector3(8, 0, -2)
var spawn_pos := Vector3(0, 0, 10)
var lake_c := Vector2.ZERO
var lake_r := Vector2.ONE
var lake_type := "water"

var _astar := AStar3D.new()
var _grid := PackedFloat32Array()
var _grid_n := 0
var _rng := RandomNumberGenerator.new()
var _road_angles: Array[float] = []
var _used_angles: Array[float] = []


func build(id: String) -> void:
	map_id = id
	map = GameData.MAPS[id]
	theme = map["theme"]
	_rng.seed = hash(id) & 0x7fffffff
	var lake: Dictionary = map["lake"]
	lake_c = lake["c"]
	lake_r = lake["r"]
	lake_type = String(lake["type"])
	_make_roads()
	_build_road_grid()
	_build_nav()
	_plan_hub()
	_build_environment()
	obstacles = StaticBody3D.new()
	obstacles.collision_layer = 1
	add_child(obstacles)
	_build_ground()
	_build_bounds()
	_build_hub()
	_build_stone_ruins()
	_build_lake()
	_build_vegetation()
	_build_zone_markers()
	_build_weather()


func zone_ids() -> Array:
	return map["zones"]


func regions() -> Array:
	return map["regions"]


# =================================================================== trilhas

func _make_roads() -> void:
	var raw: Array = []
	if map_id == "vale":
		raw = VALE_ROADS.duplicate()
	else:
		var i := 0
		for zid in map["zones"]:
			var z: Dictionary = GameData.ZONES[zid]
			var c: Vector3 = z["center"]
			var b: Vector3 = z["boss_pos"]
			raw.append(_auto_road(Vector2(c.x, c.z), Vector2(b.x, b.z), 100 + i))
			i += 1
		var edge := lake_c - lake_c.normalized() * (lake_r.x + 4.0)
		raw.append(_auto_road(edge, edge, 200).slice(0, 5))
	dense_roads.clear()
	for r in raw:
		dense_roads.append(_densify(r))


func _auto_road(target: Vector2, boss: Vector2, s: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = s + (hash(map_id) & 0xffff)
	var pts := [Vector2.ZERO]
	var L := target.length()
	var dir := target / L
	var perp := Vector2(-dir.y, dir.x)
	for k in [0.18, 0.4, 0.62, 0.82]:
		pts.append(dir * L * k + perp * rng.randf_range(-7.0, 7.0) * sin(k * PI))
	pts.append(target)
	if boss.distance_to(target) > 1.0:
		pts.append(boss)
	return pts


static func _catmull(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)


func _densify(pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := pts.size()
	for i in n - 1:
		var p0: Vector2 = pts[maxi(i - 1, 0)]
		var p1: Vector2 = pts[i]
		var p2: Vector2 = pts[i + 1]
		var p3: Vector2 = pts[mini(i + 2, n - 1)]
		var steps := maxi(2, int(p1.distance_to(p2) / 1.5))
		for k in steps:
			out.append(_catmull(p0, p1, p2, p3, float(k) / steps))
	out.append(pts[n - 1])
	return out


func _build_road_grid() -> void:
	_grid_n = int(SIZE / GRID_CELL)
	_grid.resize(_grid_n * _grid_n)
	_grid.fill(99.0)
	for road in dense_roads:
		for i in road.size() - 1:
			var a := road[i]
			var b := road[i + 1]
			var lo := Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2(10, 10)
			var hi := Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2(10, 10)
			var c0 := _cell(lo)
			var c1 := _cell(hi)
			for cy in range(c0.y, c1.y + 1):
				for cx in range(c0.x, c1.x + 1):
					var p := Vector2((cx + 0.5) * GRID_CELL - SIZE / 2.0, (cy + 0.5) * GRID_CELL - SIZE / 2.0)
					var d := _seg_dist2(p, a, b)
					var idx := cy * _grid_n + cx
					if d < _grid[idx]:
						_grid[idx] = d


func _cell(p: Vector2) -> Vector2i:
	return Vector2i(clampi(int((p.x + SIZE / 2.0) / GRID_CELL), 0, _grid_n - 1), clampi(int((p.y + SIZE / 2.0) / GRID_CELL), 0, _grid_n - 1))


static func _seg_dist2(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


func road_dist(p: Vector2) -> float:
	var c := _cell(p)
	return _grid[c.y * _grid_n + c.x]


func _build_nav() -> void:
	var ids := {}
	var next := 0
	for road in dense_roads:
		var prev := -1
		for i in road.size():
			if i % 3 != 0 and i != road.size() - 1:
				continue
			var p := road[i]
			var key := Vector2i(int(round(p.x * 2.0)), int(round(p.y * 2.0)))
			var id: int
			if ids.has(key):
				id = ids[key]
			else:
				id = next
				next += 1
				ids[key] = id
				_astar.add_point(id, Vector3(p.x, 0, p.y))
			if prev >= 0 and prev != id:
				_astar.connect_points(prev, id)
			prev = id


func route(from: Vector3, to: Vector3) -> PackedVector3Array:
	var out := PackedVector3Array()
	var a := _astar.get_closest_point(Vector3(from.x, 0, from.z))
	var b := _astar.get_closest_point(Vector3(to.x, 0, to.z))
	var direct := Vector2(from.x - to.x, from.z - to.z).length()
	var via := _astar.get_point_position(a).distance_to(from) + _astar.get_point_position(b).distance_to(to)
	if direct < 14.0 or direct < via:
		out.append(from)
		out.append(to)
		return out
	out.append(from)
	var path := _astar.get_point_path(a, b)
	for i in path.size():
		var p := path[i]
		if i == 0 and path.size() > 1 and p.distance_to(to) > path[1].distance_to(to) and from.distance_to(path[1]) < from.distance_to(p) + 2.0:
			continue
		out.append(p)
	out.append(to)
	return out


# =================================================================== acampamento (NPC, portal, quadro)

func _plan_hub() -> void:
	_road_angles.clear()
	for road in dense_roads:
		for p in road:
			if p.length() > 7.0:
				_road_angles.append(atan2(p.y, p.x))
				break
	_used_angles.clear()
	var a_npc := _free_angle(9.0)
	npc_pos = Vector3(cos(a_npc), 0, sin(a_npc)) * 6.5
	var a_board := _free_angle(9.0)
	board_pos = Vector3(cos(a_board), 0, sin(a_board)) * 7.5
	var a_portal := _free_angle(9.0)
	portal_pos = Vector3(cos(a_portal), 0, sin(a_portal)) * 12.0
	spawn_pos = npc_pos * 0.45


func _ang_dist(a: float, b: float) -> float:
	return absf(wrapf(a - b, -PI, PI))


func _free_angle(min_road_deg: float) -> float:
	var best := 0.0
	var best_score := -1.0
	for k in 72:
		var a := TAU * k / 72.0
		var score := 99.0
		for r in _road_angles:
			score = minf(score, _ang_dist(a, r))
		for u in _used_angles:
			score = minf(score, _ang_dist(a, u) * 0.9)
		if score > best_score:
			best_score = score
			best = a
	_used_angles.append(best)
	return best


# =================================================================== ambiente e luz

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.04, 0.07)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = theme["ambient"]
	env.ambient_light_energy = float(theme["ambient_energy"])
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = float(theme.get("exposure", 1.05))
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_strength = 1.1
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = float(theme.get("glow_threshold", 0.85))   # neve: mais alto, senão o chão inteiro brilha
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.16
	env.adjustment_saturation = 1.12
	env.adjustment_brightness = 0.96
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42.0, 120.0, 0.0)
	sun.light_color = theme["sun"]
	sun.light_energy = float(theme["sun_energy"])
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.85
	sun.directional_shadow_max_distance = 90.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	add_child(sun)


# =================================================================== chão

func _brush(size: int, col: Color, hard: float) -> Image:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := (size - 1) / 2.0
	for y in size:
		for x in size:
			var d := Vector2(x - c, y - c).length() / c
			var a := clampf((1.0 - d) / (1.0 - hard), 0.0, 1.0)
			img.set_pixel(x, y, Color(col.r, col.g, col.b, a * a * (3.0 - 2.0 * a)))
	return img


func _stamp(mask: Image, brush: Image, at: Vector2) -> void:
	var s := brush.get_width()
	var px := int((at.x + SIZE / 2.0) / SIZE * MASK_RES) - s / 2
	var py := int((at.y + SIZE / 2.0) / SIZE * MASK_RES) - s / 2
	mask.blend_rect(brush, Rect2i(0, 0, s, s), Vector2i(px, py))


func _build_ground() -> void:
	var mask := Image.create(MASK_RES, MASK_RES, false, Image.FORMAT_RGBA8)
	mask.fill(Color(0, 0, 0, 1))
	var ppu := MASK_RES / SIZE
	for reg in regions():
		if String(reg["type"]) != "forest":
			continue
		var c: Vector2 = reg["c"]
		var r := float(reg["r"])
		_stamp(mask, _brush(int(r * 2.2 * ppu), Color(0, 1, 0), 0.4), c)
		var fb2 := _brush(int(r * 0.65 * ppu), Color(0, 1, 0), 0.3)
		for i in 6:
			_stamp(mask, fb2, c + Vector2(_rng.randf_range(-r, r), _rng.randf_range(-r, r)) * 0.85)
	var rb := _brush(int(6.2 * ppu), Color(1, 0, 0), 0.45)
	for road in dense_roads:
		for i in road.size():
			_stamp(mask, rb, road[i])
			if i < road.size() - 1:
				_stamp(mask, rb, (road[i] + road[i + 1]) * 0.5)
	_stamp(mask, _brush(int(20 * ppu), Color(0, 0, 1), 0.7), Vector2.ZERO)
	for reg in regions():
		if String(reg["type"]) != "stone":
			continue
		var c2: Vector2 = reg["c"]
		var r2 := float(reg["r"])
		var sb := _brush(int(r2 * 0.75 * ppu), Color(0, 0, 1), 0.35)
		for i in 14:
			_stamp(mask, sb, c2 + Vector2(_rng.randf_range(-r2, r2), _rng.randf_range(-r2, r2)) * 0.7)
	var tex := ImageTexture.create_from_image(mask)

	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/terrain.gdshader")
	mat.set_shader_parameter("grass_tex", load("res://textures/%s.png" % String(theme["ground"])))
	mat.set_shader_parameter("dirt_tex", load("res://textures/%s.png" % String(theme["path"])))
	mat.set_shader_parameter("path_scale", 1.2 if String(theme["path"]) == "dirt" else 1.6)
	mat.set_shader_parameter("stone_tex", load("res://textures/stone.png"))
	mat.set_shader_parameter("noise_tex", load("res://textures/noise.png"))
	mat.set_shader_parameter("mask_tex", tex)
	mat.set_shader_parameter("world_size", SIZE)
	mat.set_shader_parameter("grass_tint", theme["ground_tint"])
	mat.set_shader_parameter("forest_tint", theme["forest_tint"])
	mat.set_shader_parameter("dirt_tint", theme["path_tint"])
	mat.set_shader_parameter("stone_tint", theme["stone_tint"])
	mat.set_shader_parameter("lava_amount", float(theme["lava"]))
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(SIZE, SIZE)
	mi.mesh = pm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(SIZE, 1.0, SIZE)
	cs.shape = box
	cs.position.y = -0.5
	obstacles.add_child(cs)


func _build_bounds() -> void:
	for w in [[Vector3(SIZE, 6, 2), Vector3(0, 3, -HALF - 1)], [Vector3(SIZE, 6, 2), Vector3(0, 3, HALF + 1)],
			[Vector3(2, 6, SIZE), Vector3(-HALF - 1, 3, 0)], [Vector3(2, 6, SIZE), Vector3(HALF + 1, 3, 0)]]:
		var cs := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = w[0]
		cs.shape = b
		cs.position = w[1]
		obstacles.add_child(cs)


func _solid(pos: Vector3, r: float) -> void:
	var cs := CollisionShape3D.new()
	var c := CylinderShape3D.new()
	c.radius = r
	c.height = 4.0
	cs.shape = c
	cs.position = pos + Vector3(0, 2.0, 0)
	obstacles.add_child(cs)


func _solid_box(pos: Vector3, size: Vector3, rot_y: float) -> void:
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
	cs.position = pos + Vector3(0, size.y * 0.5, 0)
	cs.rotation.y = rot_y
	obstacles.add_child(cs)


func _place(model: String, pos: Vector3, rot_y: float = 0.0, s: float = 1.0, outline: float = 0.04) -> Node3D:
	var mesh := ModelKit.static_mesh(model, outline)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation.y = rot_y
	mi.scale = Vector3.ONE * s
	add_child(mi)
	return mi


func _lamp_light(pos: Vector3, col: Color, energy: float = 2.2, rng: float = 9.0) -> void:
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	l.position = pos
	add_child(l)


static func _facing_center(pos: Vector3) -> float:
	var d := -pos
	return atan2(-d.x, -d.z)


## Ângulo para uma casa no círculo do acampamento: mede a distância real das trilhas no centro e nos cantos
## da casa (as trilhas fazem curva, então só o ângulo de saída delas não basta) e foge das outras casas.
func _house_angle(radius: float, half: Vector2) -> float:
	var best := 0.0
	var best_score := -INF
	for k in 72:
		var a := TAU * k / 72.0
		var c := Vector2(cos(a), sin(a)) * radius
		var ry := _facing_center(Vector3(c.x, 0, c.y))
		var clear := road_dist(c)
		for rs in [ry, -ry]:   # os dois sentidos de giro (mais seguro que acertar a convenção do _solid_box)
			for sx in [-1.0, 0.0, 1.0]:
				for sz in [-1.0, 0.0, 1.0]:
					var corner := Vector2(sx * half.x, sz * half.y).rotated(rs)
					clear = minf(clear, road_dist(c + corner))
		var sep := 99.0
		for u in _used_angles:
			sep = minf(sep, _ang_dist(a, u))
		# primeiro garante folga da trilha (4 m além da parede); depois espalha as casas
		var score := minf(clear - 4.0, 0.0) * 10.0 + minf(sep - 0.62, 0.0) * 40.0 + minf(sep, 1.0)   # casas não se encostam
		if score > best_score:
			best_score = score
			best = a
	_used_angles.append(best)
	return best


func _build_hub() -> void:
	var houses: Array = theme["houses"]
	for i in 5:
		var model := String(houses[i % houses.size()])
		var half := Vector2(2.3, 2.3) if model == "tent" else Vector2((7.0 if model != "house_b" else 8.2) * 0.5, 2.6)
		var a := _house_angle(16.5, half)
		var pos := Vector3(cos(a), 0, sin(a)) * 16.5
		var ry := _facing_center(pos)
		_place(model, pos, ry)
		if model == "tent":
			_solid(pos, 2.3)
		else:
			_solid_box(pos, Vector3(7.0 if model != "house_b" else 8.2, 4.0, 5.2), ry)
		var side := Vector3(cos(a + 0.4), 0, sin(a + 0.4)) * 15.0
		if road_dist(Vector2(side.x, side.z)) > 3.0:
			_place("barrel" if i % 2 == 0 else "crate", side, _rng.randf() * TAU)
			_solid(side, 0.5)
	if map_id == "vale" or map_id == "gelo":
		var a2 := _free_angle(9.0)
		var wp := Vector3(cos(a2), 0, sin(a2)) * 5.5
		_place("well", wp, 0.4)
		_solid(wp, 1.2)
	for i in 6:
		var a3 := TAU * i / 6.0 + 0.5
		var lp := Vector3(cos(a3), 0, sin(a3)) * 10.5
		if road_dist(Vector2(lp.x, lp.z)) < 3.0:
			lp *= 1.18
		_place("lamp", lp, _facing_center(lp) + PI / 2.0)
		_lamp_light(lp + Vector3(0, 2.8, 0), Color(1.0, 0.68, 0.32), 3.2, 12.0)
		_solid(lp, 0.35)
	if map_id != "deserto":
		for i in 44:
			var a4 := TAU * i / 44.0
			var fp := Vector3(cos(a4), 0, sin(a4)) * 23.0
			if road_dist(Vector2(fp.x, fp.z)) < 5.0:
				continue
			_place("fence", fp, -a4 - PI / 2.0)
	# portal de viagem e quadro de missões
	_place("portal", portal_pos, _facing_center(portal_pos), 1.0, 0.05)
	_solid(portal_pos, 2.0)
	_lamp_light(portal_pos + Vector3(0, 2.6, 0), Color(0.45, 0.85, 1.0), 3.0, 10.0)
	_place("board", board_pos, _facing_center(board_pos), 1.0, 0.04)
	_solid_box(board_pos, Vector3(3.0, 3.0, 0.6), _facing_center(board_pos))


func _build_stone_ruins() -> void:
	for reg in regions():
		if String(reg["type"]) != "stone":
			continue
		var c2: Vector2 = reg["c"]
		var c := Vector3(c2.x, 0, c2.y)
		var r := float(reg["r"])
		var arch := "ruin_arch"
		for i in 3:
			var a := _rng.randf() * TAU
			var p := c + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(r * 0.35, r * 0.75)
			if road_dist(Vector2(p.x, p.z)) < 5.0:
				continue
			var ry := _rng.randf() * PI
			_place(arch, p, ry, 1.0, 0.05)
			var off := Vector3(cos(-ry), 0, sin(-ry)) * 2.4
			_solid(p + off, 0.7)
			_solid(p - off, 0.7)
		for i in 10:
			var a2 := _rng.randf() * TAU
			var p2 := c + Vector3(cos(a2), 0, sin(a2)) * _rng.randf_range(r * 0.3, r)
			if road_dist(Vector2(p2.x, p2.z)) < 3.5:
				continue
			_place("ruin_pillar", p2, _rng.randf() * TAU, _rng.randf_range(0.8, 1.3), 0.05)
			_solid(p2, 0.7)
		for i in 3:
			var a3 := TAU * i / 3.0 + 0.4
			_lamp_light(c + Vector3(cos(a3), 0, sin(a3)) * r * 0.5 + Vector3(0, 2.0, 0), theme["glow_color"], 2.5, 12.0)


func in_lake(p: Vector2, margin: float = 0.0) -> bool:
	var q := (p - lake_c) / (lake_r + Vector2(margin, margin))
	return q.length() < 1.0


func _in_lake(p: Vector2, margin: float = 0.0) -> bool:
	return in_lake(p, margin)


func _build_lake() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/water.gdshader")
	mat.set_shader_parameter("noise_tex", load("res://textures/noise.png"))
	var light := Color(0.4, 0.8, 1.0)
	match lake_type:
		"oasis":
			mat.set_shader_parameter("deep", Color(0.02, 0.18, 0.22))
			mat.set_shader_parameter("shallow", Color(0.1, 0.45, 0.45))
			mat.set_shader_parameter("foam", Color(0.85, 0.82, 0.65))
		"ice":
			mat.set_shader_parameter("deep", Color(0.45, 0.62, 0.78))
			mat.set_shader_parameter("shallow", Color(0.7, 0.85, 0.95))
			mat.set_shader_parameter("sky", Color(1.0, 1.0, 1.0))
			mat.set_shader_parameter("foam", Color(0.95, 0.98, 1.0))
		"lava":
			mat.set_shader_parameter("deep", Color(0.55, 0.06, 0.0))
			mat.set_shader_parameter("shallow", Color(1.0, 0.38, 0.04))
			mat.set_shader_parameter("sky", Color(1.0, 0.85, 0.35))
			mat.set_shader_parameter("foam", Color(0.15, 0.05, 0.03))
			light = Color(1.0, 0.4, 0.1)
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = lake_r * 2.0
	mi.mesh = pm
	mi.material_override = mat
	mi.position = Vector3(lake_c.x, 0.04, lake_c.y)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	for i in 10:
		var t := (float(i) / 9.0 - 0.5) * 1.8
		var cs := CollisionShape3D.new()
		var b := CylinderShape3D.new()
		b.radius = lake_r.y * sqrt(maxf(0.0, 1.0 - t * t * 0.95)) * 0.9
		b.height = 3.0
		cs.shape = b
		cs.position = Vector3(lake_c.x + t * lake_r.x * 0.95, 1.5, lake_c.y)
		obstacles.add_child(cs)
	_lamp_light(Vector3(lake_c.x, 2.5, lake_c.y), light, 2.4 if lake_type == "lava" else 1.6, 20.0)


# =================================================================== vegetação

func _card_mesh(w: float, h: float, planes: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in planes:
		var a := PI * k / planes
		var dx := cos(a) * w * 0.5
		var dz := sin(a) * w * 0.5
		var p0 := Vector3(-dx, 0, -dz)
		var p1 := Vector3(dx, 0, dz)
		var p2 := Vector3(dx, h, dz)
		var p3 := Vector3(-dx, h, -dz)
		for v in [[p0, Vector2(0, 1)], [p1, Vector2(1, 1)], [p2, Vector2(1, 0)], [p0, Vector2(0, 1)], [p2, Vector2(1, 0)], [p3, Vector2(0, 0)]]:
			st.set_normal(Vector3.UP)
			st.set_uv(v[1])
			st.add_vertex(v[0])
	return st.commit()


## Pedaços do mapa (lotes de vegetação) e quem está perto do herói: só esses são desenhados.
## No navegador o raio é menor e os pedaços são maiores (menos lotes = menos trabalho para o WebGL).
var _chunks: Array = []        # [MultiMeshInstance3D, centro Vector2]
var _cull_t := 0.0
static var CHUNK := 64.0 if OS.has_feature("web") else 48.0
static var DRAW_R := 62.0 if OS.has_feature("web") else 90.0


func _process(delta: float) -> void:
	_cull_t -= delta
	if _cull_t > 0.0:
		return
	_cull_t = 0.3
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p == null:
		return
	var at := Vector2(p.global_position.x, p.global_position.z)
	# raio pelo zoom da câmera (o que a tela mostra) + folga do tamanho do pedaço
	var cam := get_viewport().get_camera_3d()
	var r := minf(DRAW_R, (cam.size * 1.25 if cam != null and cam.projection == Camera3D.PROJECTION_ORTHOGONAL else DRAW_R)) + CHUNK * 0.75
	for c in _chunks:
		var mmi: MultiMeshInstance3D = c[0]
		var near := at.distance_to(c[1]) < r
		var show := near and not mmi.has_meta("q_off")
		if mmi.visible != show:
			mmi.visible = show
	if _weather_holder != null:
		_weather_holder.global_position = Vector3(p.global_position.x, 0.0, p.global_position.z)


func _add_instances(mesh: Mesh, xforms: Array, colors: Array = [], customs: Array = [], shadow: bool = true, chunk: float = -1.0) -> void:
	if mesh == null or xforms.is_empty():
		return
	chunk = CHUNK if chunk < 0.0 else maxf(chunk, CHUNK * 0.75)
	var buckets := {}
	for i in xforms.size():
		var t: Transform3D = xforms[i]
		var key := Vector2i(floori(t.origin.x / chunk), floori(t.origin.z / chunk))
		if not buckets.has(key):
			buckets[key] = []
		(buckets[key] as Array).append(i)
	for key in buckets:
		var idx: Array = buckets[key]
		var center := Vector2((key.x + 0.5) * chunk, (key.y + 0.5) * chunk)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = not colors.is_empty()
		mm.use_custom_data = not customs.is_empty()
		mm.mesh = mesh
		mm.instance_count = idx.size()
		for j in idx.size():
			var i: int = idx[j]
			var tr: Transform3D = xforms[i]
			tr.origin -= Vector3(center.x, 0.0, center.y)   # lote no centro do pedaço
			mm.set_instance_transform(j, tr)
			if mm.use_colors:
				mm.set_instance_color(j, colors[i])
			if mm.use_custom_data:
				mm.set_instance_custom_data(j, customs[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.position = Vector3(center.x, 0.0, center.y)
		if not shadow:
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
		_chunks.append([mmi, center])


## Liga o vento nos materiais de um modelo de vegetação (árvore/arbusto); 0 = parado (pedras).
func _windy(mesh: Mesh, amount: float) -> Mesh:
	if mesh == null or amount <= 0.0:
		return mesh
	for s in mesh.get_surface_count():
		var m := mesh.surface_get_material(s) as ShaderMaterial
		if m != null:
			m.set_shader_parameter("wind", amount)
			if m.next_pass is ShaderMaterial:
				(m.next_pass as ShaderMaterial).set_shader_parameter("wind", amount)
	return mesh


## Clima do bioma: folhas, neve, cinzas ou areia passando com o vento (acompanha o herói).
var _weather: CPUParticles3D


func _build_weather() -> void:
	var ground := String(theme["ground"])
	var kind: String = {"snow": "neve", "ash": "cinza", "sand": "areia"}.get(ground, "folha")
	if bool(GameData.MAPS[map_id].get("event", false)) and kind == "folha":
		return
	var p := CPUParticles3D.new()
	p.amount = 28 if OS.has_feature("web") else 60
	p.lifetime = 7.0
	p.preprocess = 7.0
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(38, 6, 30)
	p.position = Vector3(0, 7, 0)
	var q := QuadMesh.new()
	q.size = Vector2(0.18, 0.18) if kind != "folha" else Vector2(0.28, 0.16)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	q.material = mat
	p.mesh = q
	match kind:
		"neve":
			p.color = Color(1, 1, 1, 0.85)
			p.direction = Vector3(0.4, -1, 0.2)
			p.initial_velocity_min = 1.2
			p.initial_velocity_max = 2.2
			p.gravity = Vector3(0.4, -0.6, 0)
		"cinza":
			p.color = Color(0.55, 0.5, 0.5, 0.7)
			p.direction = Vector3(1, 0.2, 0.3)
			p.initial_velocity_min = 1.0
			p.initial_velocity_max = 2.5
			p.gravity = Vector3(0.3, 0.15, 0)
		"areia":
			p.color = Color(0.9, 0.75, 0.5, 0.55)
			p.direction = Vector3(1, 0.05, 0.2)
			p.initial_velocity_min = 3.0
			p.initial_velocity_max = 5.0
			p.gravity = Vector3(0.6, -0.1, 0)
		_:
			p.color = (theme["forest_tint"] as Color).lerp(Color(0.9, 0.7, 0.3), 0.4)
			p.direction = Vector3(1, -0.3, 0.4)
			p.initial_velocity_min = 1.0
			p.initial_velocity_max = 2.0
			p.gravity = Vector3(0.5, -0.4, 0)
			p.angular_velocity_min = -120.0
			p.angular_velocity_max = 120.0
	p.spread = 25.0
	var holder := Node3D.new()
	add_child(holder)
	holder.add_child(p)
	_weather = p
	_weather_holder = holder


var _weather_holder: Node3D


func _xf(p: Vector2, s: float, rot: float = -1.0) -> Transform3D:
	var r := rot if rot >= 0.0 else _rng.randf() * TAU
	return Transform3D(Basis(Vector3.UP, r).scaled(Vector3.ONE * s), Vector3(p.x, 0, p.y))


func _region_at(p: Vector2) -> String:
	for reg in regions():
		var c: Vector2 = reg["c"]
		if p.distance_to(c) < float(reg["r"]):
			return String(reg["type"])
	return ""


func _blocked(p: Vector2, road_m: float) -> bool:
	if road_dist(p) < road_m:
		return true
	if p.length() < VILLAGE_R + 3.0:
		return true
	if in_lake(p, 3.0):
		return true
	if _region_at(p) == "stone":
		return true
	for zid in map["zones"]:
		var bp: Vector3 = GameData.ZONES[zid]["boss_pos"]
		if p.distance_to(Vector2(bp.x, bp.z)) < 9.0:
			return true
	return false


func _pick(weights: Dictionary) -> String:
	var total := 0.0
	for k in weights:
		total += float(weights[k])
	var r := _rng.randf() * total
	for k in weights:
		r -= float(weights[k])
		if r <= 0.0:
			return String(k)
	return String(weights.keys()[0])


func _build_vegetation() -> void:
	var trees := {}
	for i in 4200:
		var p := Vector2(_rng.randf_range(-145, 145), _rng.randf_range(-145, 145))
		var border := absf(p.x) > HALF - 3.0 or absf(p.y) > HALF - 3.0
		if not border and _blocked(p, 6.0):
			continue
		var reg := _region_at(p)
		if not border and reg == "open":
			continue
		var forest := reg == "forest"
		var keep := float(theme["tree_keep"])
		if border:
			keep = 0.9 if map_id != "deserto" else 0.35
		elif forest:
			keep = float(theme["forest_keep"])
		if _rng.randf() > keep:
			continue
		var t := _pick(theme["forest_trees"] if (forest or border) else theme["trees"])
		if not trees.has(t):
			trees[t] = []
		var s := _rng.randf_range(0.85, 1.4)
		(trees[t] as Array).append(_xf(p, s))
		if not border:
			_solid(Vector3(p.x, 0, p.y), 0.42 * s)
	for t in trees:
		_add_instances(_windy(ModelKit.static_mesh(String(t), 0.05), 0.012), trees[t])

	var props := {}
	var glow: Array = []
	for i in 1300:
		var p2 := Vector2(_rng.randf_range(-HALF, HALF), _rng.randf_range(-HALF, HALF))
		if _blocked(p2, 4.0):
			continue
		var forest2 := _region_at(p2) == "forest"
		if _rng.randf() < 0.55:
			continue
		var k := _pick(theme["forest_props"] if forest2 else theme["props"])
		var s2 := _rng.randf_range(0.6, 1.5)
		if k == String(theme["glow_prop"]):
			glow.append(_xf(p2, s2))
			continue
		if not props.has(k):
			props[k] = []
		(props[k] as Array).append(_xf(p2, s2))
		if k.begins_with("rock") and s2 > 1.2:
			_solid(Vector3(p2.x, 0, p2.y), 0.5 * s2)
	for k in props:
		_add_instances(_windy(ModelKit.static_mesh(String(k), 0.04), 0.03 if String(k).begins_with("bush") else 0.0), props[k])
	_add_instances(ModelKit.static_mesh(String(theme["glow_prop"]), 0.03), glow, [], [], false)
	for i in mini(10, glow.size()):
		var t2: Transform3D = glow[i * glow.size() / mini(10, glow.size())]
		_lamp_light(t2.origin + Vector3(0, 1.2, 0), theme["glow_color"], 1.8, 7.0)

	var gcount := int(theme["grass_count"])
	if gcount > 0:
		var gmat := ShaderMaterial.new()
		gmat.shader = load("res://shaders/foliage_card.gdshader")
		gmat.set_shader_parameter("tex", load("res://textures/grass_blade.png"))
		var gmesh := _card_mesh(1.1, 0.9, 3)
		gmesh.surface_set_material(0, gmat)
		var gx: Array = []
		var gc: Array = []
		var gd: Array = []
		var base: Color = theme["grass"]
		var fbase: Color = theme["forest_grass"]
		for i in gcount:
			var p3 := Vector2(_rng.randf_range(-HALF, HALF), _rng.randf_range(-HALF, HALF))
			if road_dist(p3) < 3.2 or p3.length() < 11.0 or in_lake(p3, 0.5):
				continue
			var reg3 := _region_at(p3)
			if reg3 == "stone" and _rng.randf() < 0.85:
				continue
			gx.append(_xf(p3, _rng.randf_range(0.6, 1.35)))
			var v := _rng.randf_range(0.75, 1.1)
			var col: Color = fbase if reg3 == "forest" else base
			gc.append(Color(col.r * v, col.g * v, col.b * v))
			gd.append(Color(_rng.randf() * TAU, 0, 0, 0))
		_add_instances(gmesh, gx, gc, gd, false, 30.0)

	var fcount := int(theme["flowers"])
	if fcount > 0:
		var fmat := ShaderMaterial.new()
		fmat.shader = load("res://shaders/foliage_card.gdshader")
		fmat.set_shader_parameter("tex", load("res://textures/flower.png"))
		fmat.set_shader_parameter("tint_whites", 1.0)
		fmat.set_shader_parameter("sway", 0.06)
		var fmesh := _card_mesh(0.45, 0.5, 2)
		fmesh.surface_set_material(0, fmat)
		var fx: Array = []
		var fc: Array = []
		var fd: Array = []
		var palette := [Color(1.0, 0.85, 0.3), Color(1.0, 0.5, 0.65), Color(0.75, 0.6, 1.0), Color(1, 1, 1), Color(0.5, 0.85, 1.0)]
		var open_c := Vector2.ZERO
		for reg in regions():
			if String(reg["type"]) == "open":
				open_c = reg["c"]
		for i in fcount:
			var p4: Vector2
			if i < fcount * 0.64:
				p4 = open_c + Vector2(_rng.randf_range(-30, 30), _rng.randf_range(-30, 30))
			else:
				p4 = Vector2(_rng.randf_range(-HALF, HALF), _rng.randf_range(-HALF, HALF))
			if road_dist(p4) < 3.0 or p4.length() < 11.0 or in_lake(p4, 0.5) or _region_at(p4) == "forest":
				continue
			fx.append(_xf(p4, _rng.randf_range(0.7, 1.3)))
			fc.append(palette[_rng.randi() % palette.size()])
			fd.append(Color(_rng.randf() * TAU, 0, 0, 0))
		_add_instances(fmesh, fx, fc, fd, false, 30.0)


func _build_zone_markers() -> void:
	for zid in map["zones"]:
		var bp: Vector3 = GameData.ZONES[zid]["boss_pos"]
		var col := Color(0.9, 0.25, 0.15)
		add_child(Toon.glow_part(Toon.cyl(5.0, 5.0, 0.02, 48), col, bp + Vector3(0, 0.05, 0), 0.05, true))
		var edge := MeshInstance3D.new()
		var t := TorusMesh.new()
		t.inner_radius = 4.8
		t.outer_radius = 5.0
		t.rings = 48
		t.ring_segments = 4
		edge.mesh = t
		edge.scale = Vector3(1, 0.05, 1)
		edge.position = bp + Vector3(0, 0.06, 0)
		edge.material_override = Toon.glow_mat(col, 0.35, true)
		add_child(edge)


## Regiões para o minimapa: [{c, r, color}]
func minimap_regions() -> Array:
	var out: Array = []
	var g: Color = theme["ground_tint"]
	for reg in regions():
		var c: Vector2 = reg["c"]
		var col := Color(0.1, 0.28, 0.27)
		match String(reg["type"]):
			"forest":
				col = Color(g.r * 0.3, g.g * 0.45, g.b * 0.45)
			"open":
				col = Color(0.3, 0.44, 0.2)
			"stone":
				col = Color(0.34, 0.36, 0.42)
		out.append({"c": Vector3(c.x, 0, c.y), "r": float(reg["r"]), "color": col})
	var lc := Color(0.15, 0.4, 0.56)
	if lake_type == "lava":
		lc = Color(0.9, 0.35, 0.1)
	elif lake_type == "ice":
		lc = Color(0.7, 0.85, 0.95)
	out.append({"c": Vector3(lake_c.x, 0, lake_c.y), "r": lake_r.x * 0.85, "color": lc})
	out.append({"c": Vector3.ZERO, "r": VILLAGE_R, "color": Color(0.42, 0.33, 0.23)})
	return out


func ground_color() -> Color:
	var g: Color = theme["ground_tint"]
	match String(theme["ground"]):
		"sand":
			return Color(0.55, 0.4, 0.26)
		"snow":
			return Color(0.6, 0.66, 0.75)
		"ash":
			return Color(0.18, 0.13, 0.13)
	return Color(g.r * 0.25, g.g * 0.35, g.b * 0.3)
