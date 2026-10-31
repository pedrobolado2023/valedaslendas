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
static var debug_drop: PackedStringArray = []   # teste: peças (prefixo do nome) removidas ao carregar


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
	for pre in debug_drop:
		for n in node.find_children(pre + "*", "MeshInstance3D", true, false):
			n.free()
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


## Herói montado por peças: corpo base (hero_<cls>_base, com as animações) + uma peça por slot
## (hero_<cls>_<raridade>_<slot>), cada uma da raridade que estiver equipada. As malhas das peças passam
## para o esqueleto do corpo (os ossos têm os mesmos nomes). Sem o corpo base, devolve null.
const HERO_SLOTS := ["helmet", "chest", "pants", "gloves", "boots", "offhand"]


const HAIR_SHADER := preload("res://shaders/toon_hair.gdshader")


## Herói de uma classe: por peças (load_hero) ou, se a classe tem "model" (modelo inteiro feito por IA), esse modelo
## com a textura pintada pela arte (tools/ai_prep_glb.py): luz suave (sem faixas), sem a textura de detalhe e pouco
## brilho de borda (armadura escura fica bege com o brilho normal).
static func load_class(cls: String, rarities: Dictionary, outline: float = 0.035) -> ModelKit:
	var cd: Dictionary = GameData.CLASSES.get(cls, {})
	if not cd.has("model"):
		return load_hero(cls, rarities, outline)
	var kit := load_kit(String(cd["model"]), outline * 0.5, 0.0)
	if kit != null:
		for m in kit.mats:
			m.set_shader_parameter("soft", 1.0)
			m.set_shader_parameter("rim_strength", 0.05)
	return kit


static func load_hero(cls: String, rarities: Dictionary, outline: float = 0.035) -> ModelKit:
	var kit := load_kit("hero_%s_base" % cls, outline)
	if kit == null:
		return null
	var skels := kit.root.find_children("*", "Skeleton3D", true, false)
	if skels.is_empty():
		return kit
	var skel := skels[0] as Skeleton3D
	for slot in HERO_SLOTS:
		var piece := load_kit("hero_%s_%s_%s" % [cls, String(rarities.get(slot, "comum")), slot], outline)
		if piece == null:
			continue
		var ps := piece.root.find_children("*", "Skeleton3D", true, false)
		if ps.is_empty():
			piece.root.free()
			continue
		var src := ps[0] as Skeleton3D
		# ossos só da peça (cada peça rígida tem um osso próprio): copia para o esqueleto do corpo
		for b in src.get_bone_count():
			var bn := src.get_bone_name(b)
			if skel.find_bone(bn) >= 0:
				continue
			var nb := skel.add_bone(bn)
			var par := src.get_bone_parent(b)
			if par >= 0:
				skel.set_bone_parent(nb, skel.find_bone(src.get_bone_name(par)))
			skel.set_bone_rest(nb, src.get_bone_rest(b))
			skel.set_bone_pose(nb, src.get_bone_rest(b))
		for c in src.get_children():
			_unown(c)
			if c is MeshInstance3D:
				c.reparent(skel, false)
				(c as MeshInstance3D).skeleton = NodePath("..")
				c.name = "%s_%s" % [slot, c.name]
			elif c is BoneAttachment3D:
				# peça rígida: um encaixe novo no mesmo osso do corpo (o índice do osso muda entre esqueletos)
				var ba := BoneAttachment3D.new()
				ba.name = "%s_%s" % [slot, c.name]
				ba.bone_name = (c as BoneAttachment3D).bone_name
				skel.add_child(ba)
				for g in c.get_children():
					g.reparent(ba, false)
		kit.mats.append_array(piece.mats)
		piece.root.free()
	return kit


static func _unown(n: Node) -> void:
	n.owner = null
	for c in n.get_children():
		_unown(c)


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
	if src_mat != null and src_mat.resource_name.begins_with("lava_"):   # Dragão de Lava: rachaduras brilhando
		var lm := ShaderMaterial.new()
		lm.shader = preload("res://shaders/lava_rock.gdshader")
		lm.set_shader_parameter("albedo", src.albedo_color if src != null else Color.WHITE)
		lm.set_shader_parameter("crack_scale", 5.0 if src_mat.resource_name == "lava_wing" else 10.0)
		lm.set_shader_parameter("fill", 0.12 if src_mat.resource_name == "lava_wing" else 0.0)
		lm.set_shader_parameter("use_vertex_color", src_mat.resource_name == "lava_body")
		if collect != null:
			collect.append(lm)
		return lm
	if src != null and src.emission_enabled:
		var e := src.emission
		var mx := maxf(e.r, maxf(e.g, e.b))
		if mx > 1.0:
			e = Color(e.r / mx, e.g / mx, e.b / mx)
		return Toon.glow_mat(e)
	var tex: Texture2D = src.albedo_texture if src != null else null
	if tex != null and "eye" in tex.resource_path.to_lower():
		outline = 0.0   # olhos sem contorno (roupas com textura de tecido mantêm o contorno)
	var cards := src != null and src.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	if cards:
		outline = 0.0   # cabelo/sobrancelha do MakeHuman: recorte de transparência, sem contorno
	var sm := Toon.make(src.albedo_color if src != null else Color.WHITE, outline, tex, Vector2.ONE, 0.0 if cards else detail)
	if cards:
		sm.shader = HAIR_SHADER
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
