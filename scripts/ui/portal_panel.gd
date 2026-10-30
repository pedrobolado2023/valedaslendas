class_name PortalPanel
extends CanvasLayer
## Portal de Viagem: todos os mapas em grade de 4 colunas com rolagem (do mais baixo ao mais alto), com o boss
## global e a masmorra no topo. Mapa bloqueado aparece apagado com o nível necessário; o mapa atual fica marcado.

var game: Node
var _grid: GridContainer
var _top: HBoxContainer
var _scroll: ScrollContainer


func setup(g: Node) -> void:
	game = g
	layer = 16
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UiTheme.get_theme()
	add_child(root)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.45)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.offset_left = -600
	panel.offset_right = 600
	panel.offset_top = -330
	panel.offset_bottom = 330
	panel.add_theme_stylebox_override("panel", Toon.ui_box(Color(0.04, 0.05, 0.08, 0.97), Color(0.55, 0.9, 1.0), 20, 10, 3))
	root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var t := UiTheme.title("Portal de Viagem", 28)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var close := Button.new()
	close.text = "Fechar (Esc)"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(func() -> void: visible = false)
	head.add_child(close)
	_top = HBoxContainer.new()
	_top.add_theme_constant_override("separation", 10)
	v.add_child(_top)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(_scroll)
	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	_scroll.add_child(_grid)
	visible = false


func open() -> void:
	visible = true
	refresh()


func refresh() -> void:
	for c in _top.get_children():
		c.queue_free()
	for c in _grid.get_children():
		c.queue_free()
	var p: Player = game.get("player")
	var cur := String(game.get("map_id"))
	var ev: WorldEvents = game.get("events")
	if ev != null and cur != String(GameData.GLOBAL_BOSS["map"]):
		var txt := "BOSS GLOBAL: Covil do Dragão  ·  termina em %d min" % ev.minutes_left() if ev.active() else ("Boss global em %d:%02d — ir e esperar" % [ev.seconds_to_next() / 60, ev.seconds_to_next() % 60] if ev.seconds_to_next() <= int(GameData.GLOBAL_BOSS["warn_minutes"]) * 60 else "Boss global: próximo às %s" % ev.next_text())
		var b := _btn(txt, Color(1.0, 0.55, 0.25), true)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.disabled = not ev.active() and ev.seconds_to_next() > int(GameData.GLOBAL_BOSS["warn_minutes"]) * 60
		b.pressed.connect(func() -> void: _go(String(GameData.GLOBAL_BOSS["map"]), true))
		_top.add_child(b)
	var dg: Dungeon = game.get("dungeon")
	if dg != null and cur != String(GameData.DUNGEON["map"]):
		var b2 := _btn("Masmorra Sombria  ·  %d/%d hoje" % [dg.runs_today(), int(GameData.DUNGEON["per_day"])], Color(0.6, 0.7, 1.0), true)
		b2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b2.pressed.connect(func() -> void:
			visible = false
			dg.enter())
		_top.add_child(b2)
	var focus: Control = null
	for id in GameData.MAP_ORDER:
		var md: Dictionary = GameData.MAPS[id]
		var locked := p.level < int(md["min_level"])
		var here := String(id) == cur
		var label := "%s\n%s%s" % [String(md["name"]), String(md["levels"]), "  · você está aqui" if here else ("  · nível %d" % int(md["min_level"]) if locked else "")]
		var col := Color(0.55, 0.9, 1.0) if here else (Color(0.5, 0.5, 0.5) if locked else Color(0.95, 0.9, 0.8))
		var b := _btn(label, col, false)
		b.disabled = locked or here
		var mid := String(id)
		b.pressed.connect(func() -> void: _go(mid, false))
		_grid.add_child(b)
		if String(id) == GameData.best_map(p.level):
			focus = b
	if focus != null:
		_scroll.ensure_control_visible.call_deferred(focus)


func _btn(text: String, col: Color, big: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0 if big else 282, 56)
	b.add_theme_font_size_override("font_size", 15 if big else 14)
	b.add_theme_color_override("font_color", col)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return b


func _go(id: String, ignore_level: bool) -> void:
	visible = false
	game.call("travel", id, ignore_level)
