class_name KingdomPanel
extends CanvasLayer
## Reino (tecla H): jurar lealdade a um dos sete reinos (bônus da especialidade do reino) e a Guerra dos Reinos da
## semana (pontos de todos os jogadores de cada reino; o vencedor da semana passada usa a Coroa: +XP).

var game: Node
var _top: VBoxContainer
var _list: VBoxContainer
var points := {}
var last := {}


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
	panel.offset_left = -440
	panel.offset_right = 440
	panel.offset_top = -330
	panel.offset_bottom = 330
	panel.add_theme_stylebox_override("panel", Toon.ui_box(Color(0.05, 0.04, 0.06, 0.97), UiTheme.GOLD, 20, 10, 3))
	root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var t := UiTheme.title("Os Sete Reinos", 28)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var close := Button.new()
	close.text = "Fechar (H)"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(func() -> void: visible = false)
	head.add_child(close)
	_top = VBoxContainer.new()
	v.add_child(_top)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)
	visible = false
	var net := get_node_or_null("/root/Net")
	if net != null:
		net.war_info.connect(func(crown: String, pts: Dictionary, prev: Dictionary) -> void:
			points = pts
			last = prev
			GameData.CROWN = crown
			game.call("apply_fragments")
			if visible:
				refresh())


func toggle() -> void:
	visible = not visible
	if visible:
		var net := get_node_or_null("/root/Net")
		if net != null and bool(net.get("online")):
			net.kingdom_rank.rpc_id(1)
		refresh()


func refresh() -> void:
	for c in _top.get_children():
		c.queue_free()
	for c in _list.get_children():
		c.queue_free()
	var p: Player = game.get("player")
	var cfg: Dictionary = GameData.KINGDOM_WAR
	var online := false
	var net := get_node_or_null("/root/Net")
	if net != null:
		online = bool(net.get("online"))
	var mine := p.kingdom
	var txt := "Você ainda não jurou lealdade a nenhum reino. Escolha um abaixo: o reino dá um bônus da sua especialidade e tudo o que você faz soma pontos para ele na Guerra dos Reinos."
	if mine != "":
		var kd: Dictionary = GameData.KINGDOMS[mine]
		txt = "Você é de %s (\"%s\") — bônus: %s%s." % [String(kd["name"]), String(kd["motto"]), GameData.bonus_text(GameData.KINGDOM_BONUS[mine]),
			("  ·  A COROA é sua esta semana: +%d%% XP" % int(float(cfg["crown_xp"]) * 100.0)) if GameData.CROWN == mine else ""]
	var l := UiTheme.label(txt, 15, Color(0.95, 0.88, 0.7))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_top.add_child(l)
	var crown := GameData.CROWN
	var war := "Guerra dos Reinos (semana): monstro %d · chefe %d · masmorra %d · duelo vencido contra outro reino %d pontos. O reino com mais pontos ganha a Coroa na semana seguinte (+%d%% XP para todos do reino). %s" % [
		int(cfg["kill"]), int(cfg["boss"]), int(cfg["dungeon"]), int(cfg["duel"]), int(float(cfg["crown_xp"]) * 100.0),
		("Coroa atual: %s." % String(GameData.KINGDOMS[crown]["name"])) if crown != "" else ""]
	if not online:
		war += "  (A guerra só conta jogando online.)"
	var wl := UiTheme.label(war, 13, Color(0.75, 0.75, 0.82))
	wl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_top.add_child(wl)
	var best := 1
	for k in points:
		best = maxi(best, int(points[k]))
	var order: Array = []
	for k in GameData.KINGDOM_ORDER:
		if GameData.KINGDOM_BONUS.has(k):
			order.append(String(k))
	order.sort_custom(func(a: String, b: String) -> bool: return int(points.get(a, 0)) > int(points.get(b, 0)))
	for kg in order:
		var kd: Dictionary = GameData.KINGDOMS[kg]
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", Toon.ui_box(Color(0.08, 0.06, 0.08, 0.9), kd["color"] if kg == mine else Color(0.3, 0.28, 0.3), 12, 8, 2))
		_list.add_child(row)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 12)
		row.add_child(hb)
		var pic := TextureRect.new()
		pic.custom_minimum_size = Vector2(54, 72)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		var who := GameData.speaker_for("", kg)
		if who != "":
			pic.texture = load("res://textures/portraits/%s.png" % who)
		hb.add_child(pic)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(col)
		col.add_child(UiTheme.title("%s%s  ·  %s" % ["♛ " if kg == crown else "", String(kd["name"]), String(kd["motto"])], 17, kd["color"]))
		col.add_child(UiTheme.label("Bônus: %s   ·   %s" % [GameData.bonus_text(GameData.KINGDOM_BONUS[kg]), String(kd["about"])], 12, Color(0.8, 0.78, 0.8)))
		var bar := ProgressBar.new()
		bar.max_value = best
		bar.value = int(points.get(kg, 0))
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 12)
		bar.modulate = kd["color"]
		col.add_child(bar)
		col.add_child(UiTheme.label("%d pontos esta semana%s" % [int(points.get(kg, 0)), ("   (semana passada: %d)" % int(last.get(kg, 0))) if last.has(kg) else ""], 12, Color(0.7, 0.7, 0.75)))
		if kg != mine:
			var b := Button.new()
			var cost := 0 if mine == "" else int(cfg["change_gems"])
			b.text = "Jurar lealdade" + (("\n%d gemas" % cost) if cost > 0 else "")
			b.focus_mode = Control.FOCUS_NONE
			b.custom_minimum_size = Vector2(150, 50)
			var key := String(kg)
			b.pressed.connect(func() -> void:
				game.call("swear_kingdom", key)
				refresh())
			hb.add_child(b)
