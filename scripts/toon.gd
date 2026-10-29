class_name Toon
extends RefCounted
## Materiais cartoon (shader toon + contorno), peças prontas, flash de dano e estilos de interface.

const TOON_SHADER := preload("res://shaders/toon.gdshader")
const OUTLINE_SHADER := preload("res://shaders/outline.gdshader")

static var _detail: Texture2D
static var _title_font: FontFile


static func detail_tex() -> Texture2D:
	if _detail == null:
		_detail = load("res://textures/detail.png") as Texture2D
	return _detail


static func title_font() -> Font:
	if _title_font == null:
		_title_font = load("res://fonts/Cinzel.ttf") as FontFile
	return _title_font


static func make(color: Color, outline_width: float = 0.03, tex: Texture2D = null, uv_scale: Vector2 = Vector2.ONE, detail: float = 0.28) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = TOON_SHADER
	m.set_shader_parameter("albedo", color)
	m.set_shader_parameter("uv_scale", uv_scale)
	if tex != null:
		m.set_shader_parameter("albedo_tex", tex)
	if detail > 0.0:
		m.set_shader_parameter("detail_tex", detail_tex())
		m.set_shader_parameter("detail_strength", detail)
	if outline_width > 0.0:
		var o := ShaderMaterial.new()
		o.shader = OUTLINE_SHADER
		o.set_shader_parameter("outline_width", outline_width)
		m.next_pass = o
	return m


static func glow_mat(color: Color, alpha: float = 1.0, additive: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(color.r, color.g, color.b, alpha)
	if alpha < 1.0 or additive:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.no_depth_test = false
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


static func part(mesh: Mesh, color: Color, pos: Vector3 = Vector3.ZERO, outline: float = 0.03) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = make(color, outline)
	return mi


static func glow_part(mesh: Mesh, color: Color, pos: Vector3 = Vector3.ZERO, alpha: float = 1.0, additive: bool = false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = glow_mat(color, alpha, additive)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


static func sphere(r: float, seg: int = 16) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = seg
	m.rings = maxi(4, seg / 2)
	return m


static func cyl(top: float, bottom: float, h: float, seg: int = 24) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = h
	m.radial_segments = seg
	return m


static func capsule(r: float, h: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = h
	return m


static func flash(node: Node, mat: ShaderMaterial) -> void:
	mat.set_shader_parameter("flash", 1.0)
	var tw := node.create_tween()
	tw.tween_method(func(v: float) -> void: mat.set_shader_parameter("flash", v), 1.0, 0.0, 0.15)


static func ui_box(bg: Color, border: Color, margin: float = 10.0, radius: int = 6, border_w: int = 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 6
	return sb
