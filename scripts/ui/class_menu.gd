class_name ClassMenu
extends CanvasLayer
## Tela de escolha do herói (clique ou teclas 1 a 4), com o modelo 3D girando.

signal chosen(key: String)
signal continue_pressed
signal continue_slot(i: int)
signal delete_slot(i: int)

var save_info := ""
var slots: Array = []        # resumo de cada herói da conta (texto)
var _msg: Label
var name_edit: LineEdit


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
	# heróis da conta (até SaveGame.MAX_CHARS): continuar ou apagar
	for i in slots.size():
		var row0 := HBoxContainer.new()
		row0.add_theme_constant_override("separation", 8)
		v.add_child(row0)
		var cont := Button.new()
		cont.text = "Jogar:  " + String(slots[i])
		cont.focus_mode = Control.FOCUS_NONE
		cont.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cont.custom_minimum_size = Vector2(0, 46)
		cont.add_theme_font_size_override("font_size", 20)
		cont.add_theme_stylebox_override("normal", Toon.ui_box(Color(0.3, 0.16, 0.06, 0.97), UiTheme.GOLD, 12, 10, 3))
		var idx := i
		cont.pressed.connect(func() -> void: continue_slot.emit(idx))
		row0.add_child(cont)
		var del := Button.new()
		del.text = "Apagar"
		del.focus_mode = Control.FOCUS_NONE
		del.pressed.connect(func() -> void:
			if del.text == "Apagar":
				del.text = "Confirmar?"
			else:
				delete_slot.emit(idx))
		row0.add_child(del)
	var full := slots.size() >= SaveGame.MAX_CHARS
	var sub := UiTheme.label("Conta cheia (%d heróis): apague um para criar outro" % SaveGame.MAX_CHARS if full else ("Novo herói: dê um nome e escolha a classe" if not slots.is_empty() else "Dê um nome e escolha seu herói"), 22, Color(0.9, 0.85, 0.75))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	var nr := HBoxContainer.new()
	nr.alignment = BoxContainer.ALIGNMENT_CENTER
	nr.add_theme_constant_override("separation", 10)
	v.add_child(nr)
	nr.add_child(UiTheme.label("Nome do herói:", 20, UiTheme.GOLD))
	name_edit = LineEdit.new()
	name_edit.placeholder_text = "ex.: Lyra da Floresta"
	name_edit.max_length = GameData.HERO_NAME_MAX + 8   # espaços sobrando são limpos depois
	name_edit.custom_minimum_size = Vector2(380, 44)
	name_edit.add_theme_font_size_override("font_size", 20)
	nr.add_child(name_edit)
	name_edit.editable = not full
	_msg = UiTheme.label("", 16, Color(1.0, 0.55, 0.45))
	_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_msg)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	v.add_child(row)
	var i := 1
	for key in GameData.CLASS_ORDER:
		row.add_child(_card(String(key), i))
		i += 1


## Nome limpo (2 a HERO_NAME_MAX letras); vazio = pede o nome antes de começar.
func hero_name() -> String:
	return GameData.clean_name(name_edit.text) if name_edit != null else ""


func error(t: String) -> void:
	if _msg != null:
		_msg.text = t


func _choose(key: String) -> void:
	if slots.size() >= SaveGame.MAX_CHARS:
		error("Sua conta já tem %d heróis. Apague um para criar outro." % SaveGame.MAX_CHARS)
		return
	if hero_name().length() < 2:
		name_edit.placeholder_text = "Digite um nome (2 letras ou mais)"
		name_edit.grab_focus()
		name_edit.add_theme_color_override("font_placeholder_color", Color(1.0, 0.5, 0.4))
		return
	chosen.emit(key)


func _card(key: String, i: int) -> Control:
	var d: Dictionary = GameData.CLASSES[key]
	var b := Button.new()
	b.custom_minimum_size = Vector2(280, 500)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", Toon.ui_box(Color(0.1, 0.05, 0.07, 0.95), Color(0.4, 0.27, 0.15), 14, 10))
	b.add_theme_stylebox_override("hover", Toon.ui_box(Color(0.18, 0.09, 0.1, 0.98), UiTheme.GOLD, 14, 10, 3))
	b.add_theme_stylebox_override("pressed", Toon.ui_box(Color(0.25, 0.12, 0.1, 1.0), Color(1, 0.9, 0.5), 14, 10, 3))
	b.pressed.connect(func() -> void: _choose(key))
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
			_choose(GameData.CLASS_ORDER[idx])
