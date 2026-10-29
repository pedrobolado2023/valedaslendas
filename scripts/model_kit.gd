class_name ModelKit
extends RefCounted
## Carrega um modelo .glb feito no Blender e troca os materiais pelo visual cartoon
## (shader toon + contorno + textura de pincel). Partes com emissão viram luz brilhante.
## Também entrega o mesh pronto para "MultiMesh" (árvores, grama, pedras em grande quantidade).

const DIR := "res://models/"

var root: Node3D
var anim: AnimationPlayer
var mats: Array[ShaderMaterial] = []
var current := ""

static var _mesh_cache := {}


static func _scene(model: String) -> PackedScene:
	var path := DIR + model + ".glb"
	if not ResourceLoader.exists(path):
		return null
	return load(path) as PackedScene


static func load_kit(model: String, outline: float = 0.03, detail: float = 0.3) -> ModelKit:
	var scene := _scene(model)
	if scene == null:
		return null
	var node := scene.instantiate() as Node3D
	if node == null:
		return null
	var kit := ModelKit.new()
	kit.root = node
	kit._convert(node, outline, detail)
	var found := node.find_children("*", "AnimationPlayer", true, false)
	if not found.is_empty():
		kit.anim = found[0] as AnimationPlayer
		for n in kit.anim.get_animation_list():
			var a := kit.anim.get_animation(n)
			if a != null and (n == "idle" or n == "walk" or n == "run"):
				a.loop_mode = Animation.LOOP_LINEAR
	return kit


## Mesh único (com materiais cartoon) de um modelo estático, para usar em MultiMesh.
static func static_mesh(model: String, outline: float = 0.04, detail: float = 0.3) -> ArrayMesh:
	var key := "%s|%.3f|%.2f" % [model, outline, detail]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var scene := _scene(model)
	if scene == null:
		return null
	var node := scene.instantiate()
	var mis := node.find_children("*", "MeshInstance3D", true, false)
	if mis.is_empty():
		node.free()
		return null
	var mi := mis[0] as MeshInstance3D
	var mesh := (mi.mesh as ArrayMesh).duplicate() as ArrayMesh
	for s in mesh.get_surface_count():
		mesh.surface_set_material(s, convert_material(mesh.surface_get_material(s), outline, detail, []))
	node.free()
	_mesh_cache[key] = mesh
	return mesh


static func convert_material(src_mat: Material, outline: float, detail: float, collect: Array) -> Material:
	var src := src_mat as BaseMaterial3D
	if src != null and src.emission_enabled:
		var e := src.emission
		var mx := maxf(e.r, maxf(e.g, e.b))
		if mx > 1.0:
			e = Color(e.r / mx, e.g / mx, e.b / mx)
		return Toon.glow_mat(e)
	var tex: Texture2D = src.albedo_texture if src != null else null
	if tex != null and "eye" in tex.resource_path.to_lower():
		outline = 0.0   # olhos sem contorno (roupas com textura de tecido mantêm o contorno)
	var sm := Toon.make(src.albedo_color if src != null else Color.WHITE, outline, tex, Vector2.ONE, detail)
	if collect != null:
		collect.append(sm)
	return sm


func _convert(n: Node, outline: float, detail: float) -> void:
	var mi := n as MeshInstance3D
	if mi != null and mi.mesh != null:
		# personagens humanizados (malha com esqueleto): contorno mais fino e menos textura de pincel na pele
		var skinned := mi.skin != null
		for s in mi.mesh.get_surface_count():
			var collected: Array = []
			var m := convert_material(mi.mesh.surface_get_material(s), outline * (0.6 if skinned else 1.0), detail * (0.35 if skinned else 1.0), collected)
			if skinned and m is ShaderMaterial:
				(m as ShaderMaterial).set_shader_parameter("use_vertex_color", true)
			for c in collected:
				mats.append(c as ShaderMaterial)
			mi.set_surface_override_material(s, m)
	for c in n.get_children():
		_convert(c, outline, detail)


func has_anim(n: String) -> bool:
	return anim != null and anim.has_animation(n)


func length(n: String) -> float:
	if has_anim(n):
		return anim.get_animation(n).length
	return 0.0


func play(n: String, speed: float = 1.0, restart: bool = false) -> void:
	if not has_anim(n):
		return
	if current != n or restart:
		current = n
		if restart:
			anim.stop()
		anim.play(n, 0.08)
	anim.speed_scale = speed


func flash(node: Node) -> void:
	if mats.is_empty():
		return
	_set_param("flash", 1.0)
	var tw := node.create_tween()
	tw.tween_method(func(v: float) -> void: _set_param("flash", v), 1.0, 0.0, 0.15)


func set_tint(c: Color, amount: float) -> void:
	for m in mats:
		m.set_shader_parameter("tint", c)
		m.set_shader_parameter("tint_amount", amount)


func _set_param(p: String, v: float) -> void:
	for m in mats:
		m.set_shader_parameter(p, v)
