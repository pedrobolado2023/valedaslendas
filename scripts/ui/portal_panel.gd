class_name PortalPanel
extends CanvasLayer
## Portal de Viagem: os mapas agrupados pelos Sete Reinos (+ Aetherion), cada reino com as suas cidades em grade de
## 4 colunas (do nível mais baixo ao mais alto), com rolagem; boss global e masmorra no topo. Mapa bloqueado aparece apagado com o nível necessário; o mapa atual fica marcado.

var game: Node
var _list: VBoxContainer
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
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	_scroll.add_child(_list)
	visible = false


func open() -> void:
	visible = true
	refresh()


func refresh() -> void:
	for c in _top.get_children():
		c.queue_free()
	for c in _list.get_children():
		c.queue_free()
	var p: Player = game.get("player")
	var cur := String(game.get("map_id"))
	var ev: WorldEvents = game.get("events")
	if ev != null and cur != String(GameData.GLOBAL_BOSS["map"]) and game.call("feature_on", "global_boss"):
		var txt := "BOSS GLOBAL: Covil do Dragão  ·  termina em %d min" % ev.minutes_left() if ev.active() else ("Boss global em %d:%02d — ir e esperar" % [ev.seconds_to_next() / 60, ev.seconds_to_next() % 60] if ev.seconds_to_next() <= int(GameData.GLOBAL_BOSS["warn_minutes"]) * 60 else "Boss global: próximo às %s" % ev.next_text())
		var b := _btn(txt, Color(1.0, 0.55, 0.25), true)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.disabled = not ev.active() and ev.seconds_to_next() > int(GameData.GLOBAL_BOSS["warn_minutes"]) * 60
		b.pressed.connect(func() -> void: _go(String(GameData.GLOBAL_BOSS["map"]), true))
		_top.add_child(b)
	var dg: Dungeon = game.get("dungeon")
	if dg != null and not GameData.is_dungeon(cur) and game.call("feature_on", "dungeon"):
		var b2 := _btn("Masmorra do bioma (Normal, Difícil, Pesadelo)  ·  %d/%d hoje" % [dg.runs_today(), int(GameData.DUNGEON["per_day"])], Color(0.6, 0.7, 1.0), true)
		b2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b2.pressed.connect(func() -> void:
			visible = false
			dg.choose())
		_top.add_child(b2)
	var focus: Control = null
	var by_kingdom := {}
	for id in GameData.MAP_ORDER:
		var kg := GameData.kingdom_of(String(id))
		if not by_kingdom.has(kg):
			by_kingdom[kg] = []
		by_kingdom[kg].append(id)
	var cur_kg := GameData.kingdom_of(cur)
	for kg in GameData.KINGDOM_ORDER:
		if not by_kingdom.has(kg):
			continue
		var kd: Dictionary = GameData.KINGDOMS[kg]
		var head := UiTheme.title("%s  ·  %s%s" % [String(kd["name"]), String(kd["motto"]), ("   —   %s, %s" % [String(kd["ruler"]), String(kd["title"])]) if String(kd["ruler"]) != "???" else ""], 18, kd["color"])
		_list.add_child(head)
		var about := UiTheme.label(String(kd["about"]) + ("   (você está aqui)" if kg == cur_kg else ""), 13, Color(0.75, 0.75, 0.8))
		_list.add_child(about)
		var grid := GridContainer.new()
		grid.columns = 4
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		_list.add_child(grid)
		for id in by_kingdom[kg]:
			var b := _map_btn(String(id), p, cur)
			grid.add_child(b)
			if String(id) == String(game.call("best_open_map")):
				focus = b
	if focus != null:
		_scroll.ensure_control_visible.call_deferred(focus)


func _map_btn(id: String, p: Player, cur: String) -> Button:
	var md: Dictionary = GameData.MAPS[id]
	var by_story: bool = not game.call("map_open", id)
	var low := p.level < int(md["min_level"])
	var here := id == cur
	var tag := "  · você está aqui" if here else ("  · nível %d" % int(md["min_level"]) if low else ("  · campanha" if by_story else ""))
	var col := Color(0.55, 0.9, 1.0) if here else (Color(0.5, 0.5, 0.5) if low or by_story else Color(0.95, 0.9, 0.8))
	var b := _btn("%s\n%s%s" % [String(md["name"]), String(md["levels"]), tag], col, false)
	b.disabled = low or by_story or here
	b.pressed.connect(func() -> void: _go(id, false))
	return b


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
