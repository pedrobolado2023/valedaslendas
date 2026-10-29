class_name UiTheme
extends RefCounted
## Tema da interface: painéis escuros com borda dourada (inspirado no Hades).

const INK := Color(0.95, 0.9, 0.79)
const GOLD := Color(0.91, 0.72, 0.35)
const PANEL := Color(0.07, 0.045, 0.06, 0.93)
const EDGE := Color(0.62, 0.47, 0.2)

static var _theme: Theme


static func get_theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font_size = 18
	t.set_stylebox("normal", "Button", Toon.ui_box(Color(0.16, 0.08, 0.1, 0.96), Color(0.5, 0.36, 0.18), 10, 6))
	t.set_stylebox("hover", "Button", Toon.ui_box(Color(0.26, 0.12, 0.13, 0.98), GOLD, 10, 6))
	t.set_stylebox("pressed", "Button", Toon.ui_box(Color(0.36, 0.18, 0.12, 1.0), Color(1.0, 0.85, 0.45), 10, 6))
	t.set_stylebox("disabled", "Button", Toon.ui_box(Color(0.1, 0.08, 0.08, 0.8), Color(0.25, 0.2, 0.18), 10, 6))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", INK)
	t.set_color("font_hover_color", "Button", Color(1.0, 0.9, 0.6))
	t.set_color("font_pressed_color", "Button", Color(1.0, 0.95, 0.75))
	t.set_color("font_disabled_color", "Button", Color(0.5, 0.45, 0.4))
	t.set_stylebox("panel", "PanelContainer", Toon.ui_box(PANEL, EDGE, 14, 8))
	t.set_stylebox("panel", "Panel", Toon.ui_box(PANEL, EDGE, 0, 8))
	t.set_color("font_color", "Label", INK)
	t.set_color("font_outline_color", "Label", Color(0.03, 0.01, 0.02))
	t.set_constant("outline_size", "Label", 5)
	t.set_color("default_color", "RichTextLabel", INK)
	t.set_font_size("normal_font_size", "RichTextLabel", 19)
	_theme = t
	return t


static func title(text: String, size: int = 22, color: Color = GOLD) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", Toon.title_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 7)
	return l


static func label(text: String, size: int = 17, color: Color = INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func bar(color: Color, h: float = 18.0) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, h)
	b.add_theme_stylebox_override("background", Toon.ui_box(Color(0.05, 0.03, 0.04, 0.95), Color(0.02, 0.01, 0.01), 0, 4))
	var fill := Toon.ui_box(color, color.lightened(0.35), 0, 4, 1)
	fill.shadow_size = 0
	b.add_theme_stylebox_override("fill", fill)
	return b
