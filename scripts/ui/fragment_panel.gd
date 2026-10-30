class_name FragmentPanel
extends CanvasLayer
## Fragmentos (tecla Y): um por reino, ganho na campanha (chefe final da primeira cidade do reino) e mais forte a cada
## cidade do reino concluída. Encaixes: 1 no começo, 2 a partir do Ato II (GameData.fragment_slots).

var game: Node
var _list: VBoxContainer
var _info: Label


func setup(g: Node) -> void:
	game = g
	layer = 14
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UiTheme.get_theme()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.offset_left = -420
	panel.offset_right = 420
	panel.offset_top = -320
	panel.offset_bottom = 320
	panel.add_theme_stylebox_override("panel", Toon.ui_box(Color(0.05, 0.035, 0.07, 0.97), Color(0.75, 0.6, 1.0), 20, 10, 3))
	root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var t := UiTheme.title("Fragmentos dos Reinos", 28, Color(0.82, 0.7, 1.0))
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var close := Button.new()
	close.text = "Fechar (Y)"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(func() -> void: visible = false)
	head.add_child(close)
	_info = UiTheme.label("", 14, Color(0.8, 0.78, 0.9))
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_info)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_list)
	visible = false


func toggle() -> void:
	visible = not visible
	if visible:
		refresh()


func refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	var p: Player = game.get("player")
	var lv: Dictionary = game.call("fragment_levels")
	var slots := int(game.call("fragment_slots"))
	_info.text = "Os sete fragmentos guardam a magia dos reinos — e prendem A Origem. Equipados: %d / %d encaixes (o 2º libera no Ato II). Cada cidade concluída do reino deixa o fragmento mais forte (até o nível %d)." % [p.fragments.size(), slots, GameData.FRAGMENT_MAX]
	for kg in GameData.KINGDOM_ORDER:
		var f: Dictionary = GameData.FRAGMENTS[kg]
		var kd: Dictionary = GameData.KINGDOMS[kg]
		var n := int(lv.get(kg, 0))
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", Toon.ui_box(Color(0.08, 0.06, 0.1, 0.9), kd["color"] if n > 0 else Color(0.3, 0.3, 0.3), 12, 8, 2))
		_list.add_child(row)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 12)
		row.add_child(hb)
		var gem := ColorRect.new()   # cristal do fragmento na cor do reino
		gem.custom_minimum_size = Vector2(26, 40)
		gem.color = kd["color"] if n > 0 else Color(0.25, 0.25, 0.28)
		gem.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(gem)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(col)
		col.add_child(UiTheme.title("%s%s" % [String(f["name"]), ("  ·  nível %d" % n) if n > 0 else ""], 17, kd["color"] if n > 0 else Color(0.55, 0.55, 0.6)))
		var desc := "%s  —  %s" % [GameData.fragment_text(kg, maxi(n, 1)), String(f["lore"])]
		if n == 0:
			desc = "Travado: vença o chefe final da primeira cidade de %s na campanha.  (%s)" % [String(kd["name"]), GameData.fragment_text(kg, 1)]
		var dl := UiTheme.label(desc, 13, Color(0.8, 0.78, 0.86))
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(dl)
		if n > 0:
			var on := String(kg) in p.fragments
			var b := Button.new()
			b.text = "Tirar" if on else "Equipar"
			b.focus_mode = Control.FOCUS_NONE
			b.custom_minimum_size = Vector2(110, 40)
			b.disabled = not on and p.fragments.size() >= slots
			var key := String(kg)
			b.pressed.connect(func() -> void:
				if key in p.fragments:
					p.fragments.erase(key)
				elif p.fragments.size() < slots:
					p.fragments.append(key)
				game.call("apply_fragments")
				game.call("save_now")
				refresh())
			hb.add_child(b)
