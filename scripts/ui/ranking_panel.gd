class_name RankingPanel
extends CanvasLayer
## Ranking geral (tecla N): top 20 heróis por nível, pedido ao servidor (Net.ranking). Top 3 em ouro/prata/bronze.

var game: Node
var _list: VBoxContainer


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
	panel.offset_left = -260
	panel.offset_right = 260
	panel.offset_top = -300
	panel.offset_bottom = 300
	panel.add_theme_stylebox_override("panel", Toon.ui_box(Color(0.05, 0.04, 0.06, 0.97), UiTheme.GOLD, 18, 10, 3))
	root.add_child(panel)
	var v := VBoxContainer.new()
	panel.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var t := UiTheme.title("Ranking geral", 28)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var close := Button.new()
	close.text = "Fechar (N)"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(func() -> void: visible = false)
	head.add_child(close)
	var tabs := HBoxContainer.new()
	v.add_child(tabs)
	for pair in [["Heróis", false], ["Guildas", true]]:
		var b := Button.new()
		b.text = String(pair[0])
		b.focus_mode = Control.FOCUS_NONE
		var gg: bool = pair[1]
		b.pressed.connect(func() -> void: _ask(gg))
		tabs.add_child(b)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 4)
	v.add_child(_list)
	get_node("/root/Net").ranking_list.connect(_show)
	get_node("/root/Net").guild_rank.connect(func(rows: Array) -> void:
		var out: Array = []
		for r in rows:
			out.append(["<%s>  %d membros" % [r[0], r[2]], r[1]])
		_guilds = true
		_show(out))
	visible = false


var _guilds := false


func _ask(guilds: bool) -> void:
	var net := get_node("/root/Net")
	_guilds = guilds
	if net.online:
		if guilds:
			net.guild_ranking.rpc_id(1)
		else:
			net.ranking.rpc_id(1)
	_show([])


func toggle() -> void:
	visible = not visible
	if not visible:
		return
	var net := get_node("/root/Net")
	if net.online:
		_ask(false)
	else:
		_show([[String(game.player.hero_name) if game.player.hero_name != "" else "Você", game.player.level]])


func _show(rows: Array) -> void:
	for c in _list.get_children():
		c.queue_free()
	if rows.is_empty():
		_list.add_child(UiTheme.label("Carregando...", 16, Color(0.7, 0.7, 0.7)))
		return
	for i in rows.size():
		var col: Color = BossRank.MEDAL[i] if i < 3 else Color(0.9, 0.86, 0.78)
		var mine := String(rows[i][0]) == String(game.player.hero_name)
		_list.add_child(UiTheme.label("%2d.  %s%s   ·   %s %d" % [i + 1, String(rows[i][0]), "  (você)" if mine else "", "Pontos" if _guilds else "Nível", int(rows[i][1])], 18 if i < 3 else 15, col))
