class_name DialogBox
extends CanvasLayer
## Caixa de diálogo do NPC, com botões de escolha. `portrait` (chave de GameData.CHARACTERS) mostra o retrato do
## personagem no próximo `open` e depois some sozinho.

var _panel: PanelContainer
var _name: Label
var _text: RichTextLabel
var _buttons: HBoxContainer
var _pic: TextureRect
var _pic_box: VBoxContainer
var _pic_name: Label
var portrait := ""


func _ready() -> void:
	layer = 15
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiTheme.get_theme()
	add_child(root)
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel.offset_left = -430
	_panel.offset_right = 430
	_panel.offset_bottom = -150
	_panel.add_theme_stylebox_override("panel", Toon.ui_box(Color(0.06, 0.035, 0.05, 0.96), UiTheme.GOLD, 22, 10, 3))
	root.add_child(_panel)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 18)
	_panel.add_child(hb)
	_pic_box = VBoxContainer.new()
	_pic_box.add_theme_constant_override("separation", 4)
	hb.add_child(_pic_box)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", Toon.ui_box(Color(0, 0, 0, 0.6), UiTheme.GOLD, 10, 3, 2))
	_pic_box.add_child(frame)
	_pic = TextureRect.new()
	_pic.custom_minimum_size = Vector2(150, 200)
	_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	frame.add_child(_pic)
	_pic_name = UiTheme.label("", 14, UiTheme.GOLD)
	_pic_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pic_name.custom_minimum_size = Vector2(150, 0)
	_pic_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_pic_box.add_child(_pic_name)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(v)
	_name = UiTheme.title("", 26)
	v.add_child(_name)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.custom_minimum_size = Vector2(640, 60)
	_text.add_theme_font_size_override("normal_font_size", 19)
	_text.add_theme_font_size_override("bold_font_size", 19)
	v.add_child(_text)
	_buttons = HBoxContainer.new()
	_buttons.alignment = BoxContainer.ALIGNMENT_END
	_buttons.add_theme_constant_override("separation", 10)
	v.add_child(_buttons)
	visible = false


func open(npc_name: String, bbcode: String, options: Array) -> void:
	_name.text = npc_name
	_text.text = bbcode
	var path := "res://textures/portraits/%s.png" % portrait
	_pic_box.visible = portrait != "" and ResourceLoader.exists(path)
	if _pic_box.visible:
		_pic.texture = load(path)
		var c: Dictionary = GameData.CHARACTERS[portrait]
		_pic_name.text = "%s\n%s" % [String(c["name"]), String(c["title"])]
	portrait = ""
	for c in _buttons.get_children():
		c.queue_free()
	for o in options:
		var b := Button.new()
		b.text = String(o[0])
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(150, 44)
		var f: Callable = o[1]
		b.pressed.connect(func() -> void:
			Sfx.play("click", -6.0)
			f.call())
		_buttons.add_child(b)
	visible = true


func close() -> void:
	visible = false


func is_open() -> bool:
	return visible
