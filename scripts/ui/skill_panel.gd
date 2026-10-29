class_name SkillPanel
extends CanvasLayer
## Painel de skills (tecla K): gaste os pontos ganhos a cada nível. Cada skill vai até o nível 10.

var player: Player
var _rows: Array = []
var _points: Label
var _title: Label


func setup(p: Player) -> void:
	player = p
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
	panel.custom_minimum_size = Vector2(820, 0)
	panel.offset_left = -410
	panel.offset_right = 410
	panel.offset_top = -330
	panel.offset_bottom = 330
	panel.add_theme_stylebox_override("panel", Toon.ui_box(Color(0.06, 0.035, 0.05, 0.97), UiTheme.GOLD, 20, 10, 3))
	root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	_title = UiTheme.title("Habilidades", 28)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	_points = UiTheme.title("", 20, Color(0.7, 1.0, 0.7))
	head.add_child(_points)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 500)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 10)
	scroll.add_child(rows)
	for i in player.skill_count():
		rows.add_child(_row(i))
	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_END
	foot.add_theme_constant_override("separation", 10)
	v.add_child(foot)
	var hint := UiTheme.label("1 ponto por nível · cada skill vai até o nível 10 · nível máximo 60", 15, Color(0.8, 0.75, 0.65))
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(hint)
	var auto := Button.new()
	auto.text = "Distribuir automático"
	auto.focus_mode = Control.FOCUS_NONE
	auto.pressed.connect(func() -> void:
		player.auto_learn()
		Sfx.play("levelup", -10.0, 1.4)
		refresh())
	foot.add_child(auto)
	var close := Button.new()
	close.text = "Fechar (K)"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(func() -> void: visible = false)
	foot.add_child(close)
	visible = false


func _row(i: int) -> Control:
	var sk: Dictionary = GameData.SKILLS[player.class_key][i]
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", Toon.ui_box(Color(0.12, 0.07, 0.08, 0.9), Color(0.35, 0.24, 0.13), 8, 8))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	box.add_child(h)
	var icon := TextureRect.new()
	icon.texture = load("res://textures/icons/%s.png" % sk["id"])
	icon.custom_minimum_size = Vector2(64, 64)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	h.add_child(icon)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 2)
	h.add_child(v)
	var name_l := UiTheme.title("", 19)
	v.add_child(name_l)
	var desc := UiTheme.label("", 15)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(desc)
	var info := UiTheme.label("", 13, Color(0.75, 0.7, 0.62))
	v.add_child(info)
	var pips := HBoxContainer.new()
	pips.add_theme_constant_override("separation", 3)
	for k in GameData.MAX_SKILL_LEVEL:
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(14, 8)
		pips.add_child(pip)
	v.add_child(pips)
	var plus := Button.new()
	plus.text = "+"
	plus.custom_minimum_size = Vector2(56, 56)
	plus.focus_mode = Control.FOCUS_NONE
	plus.add_theme_font_size_override("font_size", 28)
	plus.pressed.connect(func() -> void:
		if player.learn(i):
			Sfx.play("coin", -6.0, 1.2)
		refresh())
	h.add_child(plus)
	_rows.append({"name": name_l, "desc": desc, "info": info, "pips": pips, "plus": plus, "icon": icon})
	return box


func toggle() -> void:
	visible = not visible
	if visible:
		refresh()


func refresh() -> void:
	if player == null:
		return
	_title.text = "Habilidades — %s" % String(player.cdata["name"])
	_points.text = "Pontos: %d" % player.skill_points
	for i in _rows.size():
		var r: Dictionary = _rows[i]
		var sk: Dictionary = GameData.SKILLS[player.class_key][i]
		var lvl: int = player.skill_levels[i]
		var need: int = GameData.SKILL_UNLOCK[i]
		(r["name"] as Label).text = "%s   Nv %d/%d" % [String(sk["name"]), lvl, GameData.MAX_SKILL_LEVEL]
		var power := float(player.cdata.get("skill_power", 1.0))
		(r["desc"] as Label).text = Skills.describe(sk, maxi(lvl, 1), power)
		var extra := "Recarga %.1f s  ·  Mana %d" % [Skills.cooldown(sk, maxi(lvl, 1)), int(Skills.mp_cost(sk, maxi(lvl, 1)))]
		if player.level < need:
			extra += "   ·   Liberada no nível %d" % need
		elif lvl < GameData.MAX_SKILL_LEVEL and sk.has("mult"):
			extra += "   ·   Próximo nível: %d%% de dano" % int(round(float(sk["mult"]) * Skills.level_mult(lvl + 1) * power * 100.0))
		(r["info"] as Label).text = extra
		var pips: HBoxContainer = r["pips"]
		for k in pips.get_child_count():
			(pips.get_child(k) as ColorRect).color = Color(0.95, 0.75, 0.3) if k < lvl else Color(0.2, 0.15, 0.12)
		(r["plus"] as Button).disabled = not player.can_learn(i)
		(r["icon"] as TextureRect).modulate = Color(1, 1, 1) if lvl > 0 else Color(0.4, 0.4, 0.4)
