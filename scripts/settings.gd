class_name Settings
extends RefCounted
## Configurações do jogador (som, imagem, tela), guardadas em user://config.cfg (fora do save do personagem).

const PATH := "user://config.cfg"
const QUALITY := ["Baixa", "Média", "Alta"]

static var data := {
	"master": 0.9, "music": 0.7, "sfx": 0.9,
	"fullscreen": false, "vsync": true, "fps": 60,
	"quality": 2, "render_scale": 1.0, "shake": true, "damage_numbers": true,
}
static var _loaded := false


static func load_cfg() -> void:
	if _loaded:
		return
	_loaded = true
	var cf := ConfigFile.new()
	if cf.load(PATH) == OK:
		for k in data.keys():
			data[k] = cf.get_value("opcoes", k, data[k])
	elif OS.has_feature("web"):   # primeira vez no navegador: qualidade média (celular: baixa e resolução menor)
		var touch := DisplayServer.is_touchscreen_available()
		data["quality"] = 0 if touch else 1
		data["render_scale"] = 0.75 if touch else 1.0


static func save_cfg() -> void:
	var cf := ConfigFile.new()
	for k in data.keys():
		cf.set_value("opcoes", k, data[k])
	cf.save(PATH)


static func get_v(key: String) -> Variant:
	load_cfg()
	return data[key]


static func set_v(key: String, value: Variant) -> void:
	load_cfg()
	data[key] = value
	save_cfg()


static func _db(v: float) -> float:
	return linear_to_db(maxf(v, 0.0001))


## Som e tela (chamado ao abrir o jogo e quando algo muda no painel).
static func apply_global(tree: SceneTree) -> void:
	load_cfg()
	_ensure_buses()
	AudioServer.set_bus_volume_db(0, _db(float(data["master"])))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Musica"), _db(float(data["music"])))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Efeitos"), _db(float(data["sfx"])))
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if bool(data["fullscreen"]) else DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if bool(data["vsync"]) else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = int(data["fps"])
	if tree != null:
		tree.root.scaling_3d_scale = float(data["render_scale"])
		tree.root.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][int(data["quality"])]


## Qualidade do mapa atual: sombras, brilho e grama/vegetação extra.
static func apply_world(world: Node) -> void:
	load_cfg()
	if world == null:
		return
	var q := int(data["quality"])
	for n in world.get_children():
		if n is DirectionalLight3D:
			(n as DirectionalLight3D).shadow_enabled = q >= 1
			(n as DirectionalLight3D).directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL if q < 2 else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		elif n is WorldEnvironment:
			(n as WorldEnvironment).environment.glow_enabled = q >= 1
		elif n is MultiMeshInstance3D:
			var off := not (q >= 1 or (n as MultiMeshInstance3D).cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
			if off:
				n.set_meta("q_off", true)
				(n as MultiMeshInstance3D).visible = false
			elif n.has_meta("q_off"):
				n.remove_meta("q_off")


static func _ensure_buses() -> void:
	for name in ["Musica", "Efeitos"]:
		if AudioServer.get_bus_index(name) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, name)
			AudioServer.set_bus_send(i, "Master")
