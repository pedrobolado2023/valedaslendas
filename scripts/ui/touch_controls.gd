class_name TouchControls
extends CanvasLayer
## Celular/tablet (só aparece em tela de toque): joystick à esquerda (andar) e botão de ataque à direita.
## As skills continuam na barra (toque nelas). Player.touch_dir e Player.touch_attack.

var _base: Control
var _knob: Control
var _finger := -1
var _center := Vector2.ZERO
const R := 90.0


func _ready() -> void:
	layer = 7
	visible = DisplayServer.is_touchscreen_available()
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	# joystick acima da engrenagem/barra de skills, com folga da borda
	_base = _circle(R, Color(1, 1, 1, 0.14))
	_base.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_base.offset_left = 120
	_base.offset_right = 120 + R * 2
	_base.offset_top = -190 - R * 2
	_base.offset_bottom = -190
	root.add_child(_base)
	_knob = _circle(42, Color(1, 0.85, 0.5, 0.45))
	_base.add_child(_knob)
	_knob.position = Vector2(R - 42, R - 42)
	var atk := Button.new()
	atk.text = "Atacar"
	atk.focus_mode = Control.FOCUS_NONE
	atk.custom_minimum_size = Vector2(150, 150)
	atk.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	atk.offset_left = -230
	atk.offset_top = -340
	atk.offset_right = -70
	atk.offset_bottom = -180
	atk.add_theme_font_size_override("font_size", 24)
	atk.button_down.connect(func() -> void: Player.touch_attack = true)
	atk.button_up.connect(func() -> void: Player.touch_attack = false)
	root.add_child(atk)


func _circle(r: float, col: Color) -> Panel:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(r * 2, r * 2)
	p.size = Vector2(r * 2, r * 2)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(int(r))
	p.add_theme_stylebox_override("panel", sb)
	return p


func _input(e: InputEvent) -> void:
	if not visible:
		return
	var vp := get_viewport().get_visible_rect().size
	if e is InputEventScreenTouch:
		var t := e as InputEventScreenTouch
		if t.pressed and _finger < 0 and t.position.x < vp.x * 0.4 and t.position.y > vp.y * 0.35 and t.position.y < vp.y - 110:
			_finger = t.index
			_center = t.position
		elif not t.pressed and t.index == _finger:
			_finger = -1
			Player.touch_dir = Vector2.ZERO
			_knob.position = Vector2(R - 42, R - 42)
	elif e is InputEventScreenDrag and (e as InputEventScreenDrag).index == _finger:
		var d: Vector2 = (e as InputEventScreenDrag).position - _center
		if d.length() > R:
			d = d.normalized() * R
		Player.touch_dir = d / R
		_knob.position = Vector2(R - 42, R - 42) + d
