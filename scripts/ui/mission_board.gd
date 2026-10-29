class_name MissionBoardPanel
extends CanvasLayer
## Quadro de Missões (tecla J ou o quadro no acampamento): diárias, semanais e mensais.

var game: Node
var _cards := {}
var _rules: Label


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
	panel.offset_left = -560
	panel.offset_right = 560
	panel.offset_top = -300
	panel.offset_bottom = 300
	panel.add_theme_stylebox_override("panel", Toon.ui_box(Color(0.06, 0.035, 0.05, 0.97), UiTheme.GOLD, 20, 10, 3))
	root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var t := UiTheme.title("Quadro de Missões", 30)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var close := Button.new()
	close.text = "Fechar (J)"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(func() -> void: visible = false)
	head.add_child(close)
	_rules = UiTheme.label("", 15, Color(0.85, 0.8, 0.7))
	_rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_rules)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(row)
	for kind in GameData.MISSION_KINDS:
		row.add_child(_card(String(kind)))
	visible = false


func _card(kind: String) -> Control:
	var m: Dictionary = GameData.MISSION[kind]
	var col: Color = m["color"]
	var box := PanelContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_stylebox_override("panel", Toon.ui_box(Color(0.12, 0.07, 0.08, 0.95), col.darkened(0.3), 14, 10, 2))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	box.add_child(v)
	var title := UiTheme.title("Missões " + String(m["name"]), 22, col)
	v.add_child(title)
	var count := UiTheme.title("", 30, Color(1, 0.95, 0.85))
	v.add_child(count)
	var period := UiTheme.label("", 14, Color(0.75, 0.7, 0.62))
	period.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(period)
	var desc := UiTheme.label("", 16)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(0, 80)
	v.add_child(desc)
	var bar := UiTheme.bar(col, 14)
	v.add_child(bar)
	var reward := UiTheme.label("", 14, Color(1.0, 0.85, 0.45))
	reward.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(reward)
	var b1 := Button.new()
	b1.focus_mode = Control.FOCUS_NONE
	b1.pressed.connect(func() -> void:
		game.call("mission_accept", kind)
		refresh())
	v.add_child(b1)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	v.add_child(h)
	var b2 := Button.new()
	b2.text = "Mostrar caminho"
	b2.focus_mode = Control.FOCUS_NONE
	b2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b2.pressed.connect(func() -> void:
		game.call("mission_path", kind)
		visible = false)
	h.add_child(b2)
	var b3 := Button.new()
	b3.text = "Automático"
	b3.focus_mode = Control.FOCUS_NONE
	b3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b3.tooltip_text = "O herói faz as missões sozinho, uma atrás da outra, até acabar o limite."
	b3.pressed.connect(func() -> void:
		game.call("mission_auto", kind)
		visible = false)
	h.add_child(b3)
	_cards[kind] = {"count": count, "period": period, "desc": desc, "bar": bar, "reward": reward, "accept": b1, "path": b2, "auto": b3}
	return box


func toggle() -> void:
	visible = not visible
	if visible:
		refresh()


func refresh() -> void:
	var book: MissionBook = game.get("missions")
	var player: Player = game.get("player")
	if book == null or player == null:
		return
	book.refresh()
	_rules.text = "Diárias: até 30 por dia.  Semanais: até 150 por semana (pode fazer todas de uma vez, até na segunda-feira).  Mensais: até 900 por mês, liberadas 30 por dia — não dá para fazer todas de uma vez."
	for kind in GameData.MISSION_KINDS:
		var c: Dictionary = _cards[kind]
		var m: Dictionary = GameData.MISSION[kind]
		var done := int(book.done[kind])
		var lim := book.limit_now(kind)
		var total := int(m["limit"])
		(c["count"] as Label).text = "%d / %d" % [done, total]
		var per := ""
		match String(kind):
			"diaria":
				per = "Hoje (%s). Restam %d." % [String(book.period[kind]), book.remaining(kind)]
			"semanal":
				per = "Esta %s. Restam %d." % [String(book.period[kind]), book.remaining(kind)]
			_:
				per = "Mês %s. Liberadas até hoje: %d. Disponíveis agora: %d." % [String(book.period[kind]), lim, book.remaining(kind)]
		(c["period"] as Label).text = per
		var mis: Dictionary = book.active[kind]
		var bar: ProgressBar = c["bar"]
		var accept: Button = c["accept"]
		if mis.is_empty():
			(c["desc"] as Label).text = "Nenhuma missão ativa." if book.remaining(kind) > 0 else "Limite atingido. Volte quando o período virar."
			bar.max_value = 1
			bar.value = 0
			(c["reward"] as Label).text = ""
			accept.text = "Aceitar missão"
			accept.disabled = book.remaining(kind) <= 0
		else:
			var z: Dictionary = GameData.ZONES[mis["zone"]]
			var en := GameData.enemy(String(mis["enemy"]))
			var where := String(z["name"])
			if String(z["map"]) != String(game.get("map_id")):
				where += " (%s — use o portal)" % String(GameData.MAPS[z["map"]]["name"])
			(c["desc"] as Label).text = "Derrote %d × %s\nLocal: %s" % [int(mis["need"]), String(en["name"]), where]
			bar.max_value = int(mis["need"])
			bar.value = int(mis["have"])
			var xp_now := int(round(int(mis["xp"]) * GameData.xp_gain_mult(player.level)))
			(c["reward"] as Label).text = "Recompensa: %d XP  ·  %d de ouro  ·  chance de baú" % [xp_now, int(mis["gold"])]
			accept.text = "Em andamento (%d/%d)" % [int(mis["have"]), int(mis["need"])]
			accept.disabled = true
		(c["path"] as Button).disabled = mis.is_empty()
		(c["auto"] as Button).disabled = mis.is_empty() and book.remaining(kind) <= 0
