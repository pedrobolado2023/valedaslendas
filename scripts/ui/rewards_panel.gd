class_name RewardsPanel
extends CanvasLayer
## Recompensas (tecla O): calendário de login de 7 dias e conquistas com botão de resgatar.

var player: Player
var _days: HBoxContainer
var _list: VBoxContainer


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
	panel.offset_left = -480
	panel.offset_right = 480
	panel.offset_top = -320
	panel.offset_bottom = 320
	panel.add_theme_stylebox_override("panel", Toon.ui_box(Color(0.06, 0.035, 0.05, 0.97), UiTheme.GOLD, 20, 10, 3))
	root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var t := UiTheme.title("Recompensas", 28)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var close := Button.new()
	close.text = "Fechar (O)"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(func() -> void: visible = false)
	head.add_child(close)
	v.add_child(UiTheme.title("Login diário", 20))
	_days = HBoxContainer.new()
	_days.add_theme_constant_override("separation", 6)
	v.add_child(_days)
	v.add_child(UiTheme.title("Conquistas", 20))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_list)
	visible = false


func toggle() -> void:
	visible = not visible
	if visible:
		refresh()


func refresh() -> void:
	for c in _days.get_children():
		c.queue_free()
	var cur := int(player.login.get("day", 0))
	var can := Rewards.can_claim_daily(player)
	for i in Rewards.DAILY.size():
		var box := VBoxContainer.new()
		box.custom_minimum_size = Vector2(124, 0)
		var col := UiTheme.GOLD if i == cur and can else (Color(0.5, 0.8, 0.5) if i < cur or (i == cur - 1) else Color(0.7, 0.7, 0.7))
		box.add_child(UiTheme.label("Dia %d" % (i + 1), 15, col))
		var r := UiTheme.label(Rewards.reward_text(Rewards.DAILY[i]), 12, col)
		r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(r)
		if i == cur:
			var b := Button.new()
			b.focus_mode = Control.FOCUS_NONE
			b.text = "Resgatar" if can else "Volte amanhã"
			b.disabled = not can
			b.pressed.connect(func() -> void:
				Rewards.claim_daily(player)
				Sfx.play("legendary", -6.0)
				refresh())
			box.add_child(b)
		_days.add_child(box)
	for c in _list.get_children():
		c.queue_free()
	for a in Rewards.ACHIEVEMENTS:
		var row := HBoxContainer.new()
		var got := player.achieved.has(String(a["id"]))
		var ok := Rewards.done(player, a)
		var prog := mini(Rewards.progress(player, a), int(a["goal"]))
		var lab := UiTheme.label("%s — %s   (%d/%d)   %d gemas" % [String(a["name"]), String(a["desc"]), prog, int(a["goal"]), int(a["gems"])], 14,
			Color(0.55, 0.55, 0.55) if got else (UiTheme.GOLD if ok else Color(0.85, 0.82, 0.75)))
		lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lab)
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.text = "Resgatado" if got else ("Resgatar" if ok else "—")
		b.disabled = got or not ok
		var aa: Dictionary = a
		b.pressed.connect(func() -> void:
			if Rewards.claim(player, aa):
				Sfx.play("legendary", -6.0)
			refresh())
		row.add_child(b)
		_list.add_child(row)
