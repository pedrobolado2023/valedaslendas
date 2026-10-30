class_name Fx
extends RefCounted
## Efeitos visuais: rastros de golpe, raios, explosões, números de dano, avisos no chão e tremor de câmera.

const SLASH_SHADER := preload("res://shaders/slash.gdshader")


static func _valid(parent: Node) -> bool:
	return parent != null and is_instance_valid(parent) and parent.is_inside_tree()


static func burst(parent: Node, pos: Vector3, color: Color, amount: int = 14, speed: float = 5.0, size: float = 0.08, life: float = 0.55, gravity: float = -9.0) -> void:
	if not _valid(parent):
		return
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = amount
	p.lifetime = life
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector3(0.0, gravity, 0.0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	var sm := SphereMesh.new()
	sm.radius = size
	sm.height = size * 2.0
	sm.radial_segments = 6
	sm.rings = 3
	sm.material = Toon.glow_mat(color, 1.0, true)
	p.mesh = sm
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	parent.get_tree().create_timer(life + 0.4).timeout.connect(p.queue_free)


static func damage_number(parent: Node, pos: Vector3, text: String, color: Color, big: bool = false) -> void:
	if not _valid(parent) or not bool(Settings.get_v("damage_numbers")):
		return
	var l := Label3D.new()
	l.text = text
	l.font = Toon.title_font()
	l.font_size = 84 if big else 60
	l.pixel_size = 0.011
	l.modulate = color
	l.outline_size = 18
	l.outline_modulate = Color(0.05, 0.02, 0.02)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.render_priority = 10
	parent.add_child(l)
	l.global_position = pos + Vector3(randf_range(-0.4, 0.4), 0.0, randf_range(-0.4, 0.4))
	l.scale = Vector3.ONE * (1.6 if big else 1.2)
	var tw := l.create_tween()
	tw.tween_property(l, "scale", Vector3.ONE, 0.12)
	tw.parallel().tween_property(l, "position:y", l.position.y + 1.6, 0.75).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.35).set_delay(0.45)
	tw.tween_callback(l.queue_free)


static func ring(parent: Node, pos: Vector3, color: Color, radius: float, time: float = 0.35, thick: float = 0.05) -> void:
	if not _valid(parent):
		return
	var mi := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.9
	t.outer_radius = 1.0
	t.rings = 32
	t.ring_segments = 6
	mi.mesh = t
	var mat := Toon.glow_mat(color, 0.9, true)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = pos
	mi.scale = Vector3(0.2, 1.0 + thick * 10.0, 0.2)
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(radius, 1.0, radius), time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(mat, "albedo_color:a", 0.0, time)
	tw.chain().tween_callback(mi.queue_free)


static func disc(parent: Node, pos: Vector3, color: Color, radius: float, time: float = 0.4, alpha: float = 0.3) -> void:
	if not _valid(parent):
		return
	var mi := Toon.glow_part(Toon.cyl(1.0, 1.0, 0.02, 32), color, Vector3.ZERO, alpha, true)
	parent.add_child(mi)
	mi.global_position = pos
	mi.scale = Vector3(radius * 0.3, 1.0, radius * 0.3)
	var mat := mi.material_override as StandardMaterial3D
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(radius, 1.0, radius), time * 0.4)
	tw.tween_property(mat, "albedo_color:a", 0.0, time)
	tw.chain().tween_callback(mi.queue_free)


## Rastro em arco. angle = direção central (radianos, no plano XZ: cos=X, sin=Z). arc_deg = abertura.
static func slash(parent: Node, pos: Vector3, angle: float, radius: float, arc_deg: float, color: Color, width: float = 0.9, time: float = 0.28, reverse: bool = false) -> void:
	if not _valid(parent):
		return
	var half := deg_to_rad(arc_deg) * 0.5
	var a0 := angle - half
	var a1 := angle + half
	if reverse:
		var tmp := a0
		a0 = a1
		a1 = tmp
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := maxi(8, int(arc_deg / 8.0))
	var r_in := maxf(0.05, radius - width)
	for i in seg:
		var t0 := float(i) / seg
		var t1 := float(i + 1) / seg
		var b0 := lerpf(a0, a1, t0)
		var b1 := lerpf(a0, a1, t1)
		var p0i := Vector3(cos(b0) * r_in, 0.0, sin(b0) * r_in)
		var p0o := Vector3(cos(b0) * radius, 0.0, sin(b0) * radius)
		var p1i := Vector3(cos(b1) * r_in, 0.0, sin(b1) * r_in)
		var p1o := Vector3(cos(b1) * radius, 0.0, sin(b1) * radius)
		st.set_uv(Vector2(t0, 0.0)); st.add_vertex(p0i)
		st.set_uv(Vector2(t0, 1.0)); st.add_vertex(p0o)
		st.set_uv(Vector2(t1, 1.0)); st.add_vertex(p1o)
		st.set_uv(Vector2(t0, 0.0)); st.add_vertex(p0i)
		st.set_uv(Vector2(t1, 1.0)); st.add_vertex(p1o)
		st.set_uv(Vector2(t1, 0.0)); st.add_vertex(p1i)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mat := ShaderMaterial.new()
	mat.shader = SLASH_SHADER
	mat.set_shader_parameter("color", color)
	mat.set_shader_parameter("progress", 0.0)
	mat.set_shader_parameter("fade", 1.0)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = pos
	var tw := mi.create_tween()
	tw.tween_method(func(v: float) -> void: mat.set_shader_parameter("progress", v), 0.0, 1.25, time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_method(func(v: float) -> void: mat.set_shader_parameter("fade", v), 1.0, 0.0, time * 0.6).set_delay(time * 0.55)
	tw.tween_callback(mi.queue_free)


## Faixa brilhante reta de a até b (estocadas, investidas, raios).
static func streak(parent: Node, a: Vector3, b: Vector3, color: Color, width: float = 0.35, time: float = 0.25) -> void:
	if not _valid(parent):
		return
	var d := b - a
	var L := d.length()
	if L < 0.01:
		return
	var mi := Toon.glow_part(Toon.box(Vector3(width, width * 0.5, L)), color, Vector3.ZERO, 0.95, true)
	parent.add_child(mi)
	mi.global_position = (a + b) * 0.5
	mi.look_at(b, Vector3.UP if absf(d.normalized().y) < 0.99 else Vector3.RIGHT)
	var core := Toon.glow_part(Toon.box(Vector3(width * 0.35, width * 0.25, L)), Color(1, 1, 1), Vector3.ZERO, 0.95, true)
	mi.add_child(core)
	var mat := mi.material_override as StandardMaterial3D
	var cmat := core.material_override as StandardMaterial3D
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mat, "albedo_color:a", 0.0, time)
	tw.tween_property(cmat, "albedo_color:a", 0.0, time)
	tw.tween_property(mi, "scale:x", 0.2, time)
	tw.chain().tween_callback(mi.queue_free)


static func lightning(parent: Node, a: Vector3, b: Vector3, color: Color, time: float = 0.25) -> void:
	if not _valid(parent):
		return
	var pts: Array[Vector3] = [a]
	var n := 6
	var side := (b - a).cross(Vector3.UP).normalized()
	if side.length() < 0.1:
		side = Vector3.RIGHT
	for i in range(1, n):
		var t := float(i) / n
		var off := side * randf_range(-0.7, 0.7) + Vector3(0, randf_range(-0.4, 0.4), 0)
		pts.append(a.lerp(b, t) + off)
	pts.append(b)
	for i in pts.size() - 1:
		streak(parent, pts[i], pts[i + 1], color, 0.22, time)


## Luzes dos efeitos: no navegador (WebGL) há um limite de luzes na cena; acima de WEB_LIGHTS as novas ficam
## desligadas (o efeito continua, só sem a luz). Toda luz de efeito entra no grupo "fx_light".
const WEB_LIGHTS := 10


static func budget_light(l: OmniLight3D) -> void:
	l.add_to_group("fx_light")
	if OS.has_feature("web") and l.is_inside_tree() and l.get_tree().get_node_count_in_group("fx_light") > WEB_LIGHTS:
		l.visible = false


static func light_flash(parent: Node, pos: Vector3, color: Color, energy: float = 4.0, rng: float = 10.0, time: float = 0.35) -> void:
	if not _valid(parent):
		return
	if OS.has_feature("web") and parent.get_tree().get_node_count_in_group("fx_light") >= WEB_LIGHTS:
		return
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = rng
	parent.add_child(l)
	l.global_position = pos
	budget_light(l)
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, time)
	tw.tween_callback(l.queue_free)


## Aviso no chão (círculo que enche) — devolve o nó para quem quiser apagar antes.
static func telegraph(parent: Node, pos: Vector3, radius: float, color: Color, time: float) -> Node3D:
	if not _valid(parent):
		return null
	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = pos + Vector3(0, 0.06, 0)
	var edge := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = radius * 0.95
	t.outer_radius = radius
	t.rings = 48
	t.ring_segments = 4
	edge.mesh = t
	edge.scale = Vector3(1, 0.05, 1)
	edge.material_override = Toon.glow_mat(color, 0.9, true)
	root.add_child(edge)
	var fill := Toon.glow_part(Toon.cyl(radius, radius, 0.02, 40), color, Vector3.ZERO, 0.2, true)
	fill.scale = Vector3(0.05, 1, 0.05)
	root.add_child(fill)
	var tw := root.create_tween()
	tw.tween_property(fill, "scale", Vector3.ONE, time)
	tw.tween_callback(root.queue_free)
	return root


static func shake(node: Node, strength: float = 0.15) -> void:
	if node == null or not node.is_inside_tree() or not bool(Settings.get_v("shake")):
		return
	var cam := node.get_viewport().get_camera_3d()
	if cam == null:
		return
	var tw := cam.create_tween()
	for i in 5:
		var k := 1.0 - float(i) / 5.0
		tw.tween_property(cam, "h_offset", randf_range(-strength, strength) * k, 0.035)
		tw.tween_property(cam, "v_offset", randf_range(-strength, strength) * k, 0.035)
	tw.tween_property(cam, "h_offset", 0.0, 0.04)
	tw.tween_property(cam, "v_offset", 0.0, 0.04)


static func hitstop(node: Node, time: float = 0.05) -> void:
	if node == null or not node.is_inside_tree():
		return
	Engine.time_scale = 0.08
	node.get_tree().create_timer(time, true, false, true).timeout.connect(func() -> void: Engine.time_scale = 1.0)
