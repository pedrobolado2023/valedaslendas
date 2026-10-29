class_name ClassMenu
extends CanvasLayer
## Tela de escolha do herói (clique ou teclas 1 a 4), com o modelo 3D girando.

signal chosen(key: String)
signal continue_pressed

var save_info := ""


func _ready() -> void:
	layer = 20
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UiTheme.get_theme()
	add_child(root)
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.04, 0.72)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 22)
	center.add_child(v)
	var title := UiTheme.title("Vale das Lendas", 64)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	if save_info != "":
		var cont := Button.new()
		cont.text = "Continuar:  " + save_info
		cont.focus_mode = Control.FOCUS_NONE
		cont.custom_minimum_size = Vector2(0, 54)
		cont.add_theme_font_size_override("font_size", 22)
		cont.add_theme_stylebox_override("normal", Toon.ui_box(Color(0.3, 0.16, 0.06, 0.97), UiTheme.GOLD, 12, 10, 3))
		cont.pressed.connect(func() -> void: continue_pressed.emit())
		v.add_child(cont)
	var sub := UiTheme.label("Escolha seu herói" + ("  (escolher começa um jogo novo)" if save_info != "" else ""), 22, Color(0.9, 0.85, 0.75))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	v.add_child(row)
	var i := 1
	for key in GameData.CLASS_ORDER:
		row.add_child(_card(String(key), i))
		i += 1


func _card(key: String, i: int) -> Control:
	var d: Dictionary = GameData.CLASSES[key]
	var b := Button.new()
	b.custom_minimum_size = Vector2(280, 500)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", Toon.ui_box(Color(0.1, 0.05, 0.07, 0.95), Color(0.4, 0.27, 0.15), 14, 10))
	b.add_theme_stylebox_override("hover", Toon.ui_box(Color(0.18, 0.09, 0.1, 0.98), UiTheme.GOLD, 14, 10, 3))
	b.add_theme_stylebox_override("pressed", Toon.ui_box(Color(0.25, 0.12, 0.1, 1.0), Color(1, 0.9, 0.5), 14, 10, 3))
	b.pressed.connect(func() -> void: chosen.emit(key))
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 14
	col.offset_right = -14
	col.offset_top = 10
	col.offset_bottom = -12
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 4)
	b.add_child(col)
	var prev := _preview(key)
	if prev != null:
		col.add_child(prev)
	var name_l := UiTheme.title("[%d]  %s" % [i, String(d["name"])], 24)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(name_l)
	var desc := UiTheme.label(String(d["desc"]), 15)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(desc)
	var names := []
	for sk in GameData.SKILLS[key]:
		names.append(String(sk["name"]))
	var sks := UiTheme.label("Skills: " + ", ".join(names), 13, Color(0.8, 0.72, 0.55))
	sks.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sks.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(sks)
	return b


func _preview(key: String) -> Control:
	var all := {}
	for k in ModelKit.HERO_SLOTS:
		all[k] = "lendaria"
	var kit := ModelKit.load_hero(key, all)   # por peças (os modelos inteiros não vão na versão web)
	if kit == null:
		kit = ModelKit.load_kit("hero_%s_lendaria" % key, 0.035)
	if kit == null:
		return null
	Player.attach_weapon(kit, key, "lendaria")
	var box := SubViewportContainer.new()
	box.stretch = true
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.custom_minimum_size = Vector2(250, 270)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.size = Vector2i(250, 270)
	vp.msaa_3d = Viewport.MSAA_2X
	box.add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.48, 0.65)
	env.ambient_light_energy = 0.9
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40.0, 35.0, 0.0)
	sun.light_energy = 1.3
	sun.light_color = Color(1.0, 0.85, 0.7)
	vp.add_child(sun)
	var cam := Camera3D.new()
	cam.fov = 30.0
	cam.position = Vector3(0.0, 1.45, 6.2)
	cam.rotation_degrees = Vector3(-5.0, 0.0, 0.0)
	vp.add_child(cam)
	var pivot := Node3D.new()
	vp.add_child(pivot)
	pivot.add_child(kit.root)
	kit.play("idle")
	Player.add_gear_effects(pivot, kit, "lendaria", "lendaria", key)
	var tw := pivot.create_tween().set_loops()
	tw.tween_property(pivot, "rotation:y", TAU + 0.5, 9.0).from(0.5)
	return box


func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo:
		var idx: int = k.keycode - KEY_1
		if idx >= 0 and idx < GameData.CLASS_ORDER.size():
			chosen.emit(GameData.CLASS_ORDER[idx])
