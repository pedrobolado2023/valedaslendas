class_name PetPanel
extends CanvasLayer
## Pets (tecla P): lista os mascotes, função, nível e XP; ativa o escolhido. Compra é na loja (L).

var player: Player
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
	panel.offset_left = -380
	panel.offset_right = 380
	panel.offset_top = -300
	panel.offset_bottom = 300
	panel.add_theme_stylebox_override("panel", Toon.ui_box(Color(0.06, 0.035, 0.05, 0.97), UiTheme.GOLD, 20, 10, 3))
	root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var t := UiTheme.title("Pets", 28)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var close := Button.new()
	close.text = "Fechar (P)"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(func() -> void: visible = false)
	head.add_child(close)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_list)
	v.add_child(UiTheme.label("O pet ativo ganha XP a cada monstro derrotado (até o nível %d) e fica 4%% mais forte por nível." % GameData.PET_MAX_LEVEL, 13, Color(0.75, 0.7, 0.62)))
	visible = false


func toggle() -> void:
	visible = not visible
	if visible:
		refresh()


func refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	for it in GameData.SHOP:
		if String(it["kind"]) != "pet":
			continue
		var id := String(it["id"])
		var owned := Shop.owned(player, id) > 0
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var lv: Array = player.pet_levels.get(id, [1, 0])
		var txt := "%s\n%s" % [String(it["name"]).trim_prefix("Mascote: "), String(it["desc"])]
		if owned:
			var full := int(lv[0]) >= GameData.PET_MAX_LEVEL
			txt += "\nNível %d%s" % [int(lv[0]), "  (máximo)" if full else "  ·  XP %d/%d" % [int(lv[1]), GameData.pet_xp_need(int(lv[0]))]]
		var lab := UiTheme.label(txt, 15, it["color"] if owned else Color(0.55, 0.55, 0.55))
		lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(lab)
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(150, 0)
		if not owned:
			b.text = "Loja (L): %d gemas" % int(it["price"])
			b.disabled = true
		elif player.pet == id:
			b.text = "Guardar"
			b.pressed.connect(func() -> void:
				player.pet = ""
				player.rebuild_visuals()
				refresh())
		else:
			b.text = "Ativar"
			b.pressed.connect(func() -> void:
				player.pet = id
				player.rebuild_visuals()
				refresh())
		row.add_child(b)
		_list.add_child(row)
