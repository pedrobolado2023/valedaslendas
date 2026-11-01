class_name SettingsPanel
extends CanvasLayer
## Configurações (Esc): volume, tela cheia, sincronia vertical, limite de FPS, qualidade, resolução 3D,
## tremor de tela e números de dano. Também mostra os atalhos e tem "Ver tutorial de novo" e "Sair do jogo".

var game: Node


func setup(g: Node) -> void:
	game = g
	layer = 20
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UiTheme.get_theme()
	add_child(root)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.5)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.offset_left = -470
	panel.offset_right = 470
	panel.offset_top = -320
	panel.offset_bottom = 320
	panel.add_theme_stylebox_override("panel", Toon.ui_box(Color(0.06, 0.035, 0.05, 0.97), UiTheme.GOLD, 20, 10, 3))
	root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	v.add_child(UiTheme.title("Configurações", 30))
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 30)
	v.add_child(cols)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(420, 0)
	left.add_theme_constant_override("separation", 8)
	cols.add_child(left)
	left.add_child(UiTheme.title("Som", 20))
	_slider(left, "Volume geral", "master")
	_slider(left, "Música", "music")
	_slider(left, "Efeitos", "sfx")
	left.add_child(UiTheme.title("Imagem", 20))
	_option(left, "Qualidade", "quality", Settings.QUALITY, true)
	_option(left, "Resolução 3D", "render_scale", ["50%", "75%", "100%"], true, [0.5, 0.75, 1.0])
	_option(left, "Limite de FPS", "fps", ["30", "60", "120", "Sem limite"], false, [30, 60, 120, 0])
	_check(left, "Tela cheia", "fullscreen")
	_check(left, "Sincronia vertical (V-Sync)", "vsync")
	_check(left, "Tremor de tela nos golpes", "shake")
	_check(left, "Números de dano", "damage_numbers")
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 6)
	cols.add_child(right)
	right.add_child(UiTheme.title("Atalhos", 20))
	var keys := "WASD / setas: andar\nClique / Espaço: ataque básico\n1-9, 0, - e =: skills\nE: falar / usar\nK: skills   I: equipamento\nJ: missões   L: loja   P: pets   R: montaria   O: recompensas
G: social e duelo   N: ranking   B: Mercadinho   U: Forja
Enter: chat\nM: mapa   T: auto-combate\nRoda do mouse: zoom\nEsc: este menu"
	right.add_child(UiTheme.label(keys, 15, Color(0.85, 0.8, 0.7)))
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 10)
	foot.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(foot)
	var tut := Button.new()
	tut.text = "Ver tutorial de novo"
	tut.focus_mode = Control.FOCUS_NONE
	tut.pressed.connect(func() -> void:
		visible = false
		game.call("start_tutorial", true))
	foot.add_child(tut)
	var quit := Button.new()
	quit.text = "Salvar e sair"
	quit.focus_mode = Control.FOCUS_NONE
	quit.pressed.connect(func() -> void:
		game.call("save_now")
		get_tree().quit())
	foot.add_child(quit)
	var close := Button.new()
	close.text = "Voltar ao jogo (Esc)"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(func() -> void: visible = false)
	foot.add_child(close)
	visible = false


func _row(parent: Node, label: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	var l := UiTheme.label(label, 15)
	l.custom_minimum_size = Vector2(190, 0)
	h.add_child(l)
	parent.add_child(h)
	return h


func _slider(parent: Node, label: String, key: String) -> void:
	var h := _row(parent, label)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = float(Settings.get_v(key))
	s.custom_minimum_size = Vector2(200, 24)
	s.focus_mode = Control.FOCUS_NONE
	s.value_changed.connect(func(x: float) -> void:
		Settings.set_v(key, x)
		Settings.apply_global(get_tree()))
	h.add_child(s)


func _option(parent: Node, label: String, key: String, names: Array, world: bool, values: Array = []) -> void:
	var h := _row(parent, label)
	var o := OptionButton.new()
	o.focus_mode = Control.FOCUS_NONE
	for n in names:
		o.add_item(String(n))
	var cur: Variant = Settings.get_v(key)
	o.selected = values.find(cur) if not values.is_empty() else int(cur)
	o.item_selected.connect(func(i: int) -> void:
		Settings.set_v(key, values[i] if not values.is_empty() else i)
		Settings.apply_global(get_tree())
		if world:
			Settings.apply_world(game.get("world")))
	h.add_child(o)


func _check(parent: Node, label: String, key: String) -> void:
	var c := CheckBox.new()
	c.text = label
	c.focus_mode = Control.FOCUS_NONE
	c.button_pressed = bool(Settings.get_v(key))
	c.toggled.connect(func(on: bool) -> void:
		Settings.set_v(key, on)
		Settings.apply_global(get_tree()))
	parent.add_child(c)


func toggle() -> void:
	visible = not visible
