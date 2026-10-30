class_name AdminPanel
extends CanvasLayer
## Menu de administrador (F1): coloca qualquer item no personagem e ajusta nível, ouro, skills, mapas e missões.
## Some sozinho no executável final (release); ver GameData.ADMIN_ENABLED em scripts/data.gd.

var game: Node
var _cls: OptionButton
var _slot: OptionButton
var _rar: OptionButton
var _qty: SpinBox
var _level: SpinBox
var _class_to: OptionButton
var _god: CheckBox
var _msg: Label


func setup(g: Node) -> void:
	game = g
	layer = 16
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UiTheme.get_theme()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.offset_left = -600
	panel.offset_right = 600
	panel.offset_top = -320
	panel.offset_bottom = 320
	panel.add_theme_stylebox_override("panel", Toon.ui_box(Color(0.04, 0.05, 0.08, 0.97), Color(0.95, 0.35, 0.3), 20, 10, 3))
	root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var t := UiTheme.title("Menu de Administrador", 28, Color(1.0, 0.55, 0.45))
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var close := Button.new()
	close.text = "Fechar (F1)"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(func() -> void: visible = false)
	head.add_child(close)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 18)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(cols)
	cols.add_child(_items_col())
	cols.add_child(_hero_col())
	cols.add_child(_world_col())
	_msg = UiTheme.label("", 16, Color(0.6, 1.0, 0.7))
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_msg)
	visible = false


func _col(title: String) -> VBoxContainer:
	var box := PanelContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_stylebox_override("panel", Toon.ui_box(Color(0.1, 0.08, 0.1, 0.95), Color(0.35, 0.25, 0.2), 12, 8))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 7)
	box.add_child(v)
	v.add_child(UiTheme.title(title, 20))
	v.set_meta("box", box)
	return v


func _row(parent: Node, label: String, ctrl: Control) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var l := UiTheme.label(label, 15)
	l.custom_minimum_size = Vector2(110, 0)
	h.add_child(l)
	ctrl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(ctrl)
	parent.add_child(h)


func _btn(parent: Node, text: String, f: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func() -> void:
		f.call()
		Sfx.play("click", -6.0))
	parent.add_child(b)
	return b


func _opt(items: Array) -> OptionButton:
	var o := OptionButton.new()
	o.focus_mode = Control.FOCUS_NONE
	for it in items:
		o.add_item(String(it))
	return o


func _items_col() -> Control:
	var v := _col("Itens")
	var names: Array = []
	for k in GameData.CLASS_ORDER:
		names.append(GameData.CLASSES[k]["name"])
	_cls = _opt(names)
	_row(v, "Classe", _cls)
	var slot_names: Array = []
	for sl in Player.ITEM_SLOTS:
		slot_names.append(String(GameData.SLOT_INFO[sl]["name"]))
	slot_names.append("Conjunto inteiro")
	_slot = _opt(slot_names)
	_slot.selected = slot_names.size() - 1
	_row(v, "Tipo", _slot)
	var rn: Array = []
	for r in GameData.RARITIES:
		rn.append(GameData.RARITY[r]["name"])
	rn.append("Todas")
	_rar = _opt(rn)
	_rar.selected = 3
	_row(v, "Raridade", _rar)
	_qty = SpinBox.new()
	_qty.min_value = 1
	_qty.max_value = 20
	_qty.value = 1
	_row(v, "Quantidade", _qty)
	_btn(v, "Adicionar ao inventário", func() -> void: _give(false))
	_btn(v, "Adicionar e equipar", func() -> void: _give(true))
	_btn(v, "Todas as skins de todas as classes", func() -> void:
		var n := 0
		for k in GameData.CLASS_ORDER:
			for slot in Player.ITEM_SLOTS:
				for r in GameData.RARITIES:
					_add(String(k), slot, String(r))
					n += 1
		_done("%d itens adicionados (todas as classes e raridades)." % n))
	return v.get_meta("box")


func _hero_col() -> Control:
	var v := _col("Personagem")
	_level = SpinBox.new()
	_level.min_value = 1
	_level.max_value = GameData.MAX_LEVEL
	_level.value = 60
	_row(v, "Nível", _level)
	_btn(v, "Definir nível", func() -> void:
		var p: Player = game.get("player")
		game.call("admin_set_level", int(_level.value))
		_done("Nível definido: %d (pontos de skill: %d)" % [p.level, p.skill_points]))
	_btn(v, "+1000 gemas (testar a loja)", func() -> void:
		Shop.credit_gems(game.get("player"), 1000, "admin")
		_done("+1000 gemas."))
	_btn(v, "Invocar boss global (todos avisados, começa em 5 min)", func() -> void:
		var net: Node = get_node("/root/Net")
		if net.online:
			net.admin_boss.rpc_id(1, float(GameData.GLOBAL_BOSS["warn_minutes"]) * 60.0)
		else:
			(game.get("events") as WorldEvents).schedule(float(GameData.GLOBAL_BOSS["warn_minutes"]) * 60.0, int(GameData.GLOBAL_BOSS["minutes"]))
		_done("Boss global invocado: todos os jogadores foram avisados (começa em 5 min)."))
	_btn(v, "Evento: Baú Dourado agora", func() -> void:
		var net: Node = get_node("/root/Net")
		if net.online:
			net.admin_event.rpc_id(1, "bau")
		else:
			var ev: WorldEvents = game.get("events")
			ev._local_ev_t = 999999.0
		_done("Baú Dourado chamado."))
	_btn(v, "Evento: Invasão agora (online)", func() -> void:
		var net: Node = get_node("/root/Net")
		if net.online:
			net.admin_event.rpc_id(1, "invasao")
		_done("Invasão chamada." if net.online else "Invasão só funciona online."))
	_btn(v, "Boss global: começar agora (15 min)", func() -> void:
		var ev: WorldEvents = game.get("events")
		ev.force(int(GameData.GLOBAL_BOSS["minutes"]))
		ev.defeated_key = ""
		_done("Boss global liberado: use o Portal de Viagem (Covil do Dragão)."))
	_btn(v, "Todas as skills no nível 10", func() -> void:
		var p: Player = game.get("player")
		for i in p.skill_count():
			p.skill_levels[i] = GameData.MAX_SKILL_LEVEL
		p.stats_changed.emit()
		_done("Todas as skills no nível máximo."))
	_btn(v, "+100.000 de ouro", func() -> void:
		var p: Player = game.get("player")
		p.add_gold(100000)
		_done("Ouro: %d" % p.gold))
	_btn(v, "Vida e mana cheias", func() -> void:
		var p: Player = game.get("player")
		p.hp = p.max_hp
		p.mp = p.max_mp
		_done("Vida e mana restauradas."))
	_god = CheckBox.new()
	_god.text = "Imortal (não toma dano)"
	_god.focus_mode = Control.FOCUS_NONE
	_god.toggled.connect(func(on: bool) -> void:
		var p: Player = game.get("player")
		p.god_mode = on
		_done("Imortal: " + ("ligado" if on else "desligado")))
	v.add_child(_god)
	var names: Array = []
	for k in GameData.CLASS_ORDER:
		names.append(GameData.CLASSES[k]["name"])
	_class_to = _opt(names)
	_row(v, "Trocar classe", _class_to)
	_btn(v, "Trocar para esta classe", func() -> void:
		var key := String(GameData.CLASS_ORDER[_class_to.selected])
		game.call("admin_change_class", key)
		_done("Agora você é %s (nível e progresso mantidos)." % String(GameData.CLASSES[key]["name"])))
	return v.get_meta("box")


func _world_col() -> Control:
	var v := _col("Mundo e missões")
	v.add_child(UiTheme.label("Viajar (sem limite de nível):", 14, Color(0.8, 0.75, 0.65)))
	for id in GameData.BASE_MAP_ORDER:
		var mid := String(id)
		_btn(v, String(GameData.MAPS[mid]["name"]), func() -> void:
			visible = false
			game.call("travel", mid, true))
	_btn(v, "Mapas novos (nível 61+): use o portal", func() -> void:
		visible = false
		game.call("open_portal"))
	_btn(v, "Concluir missão de história atual", func() -> void:
		game.call("admin_complete_quest")
		_done("Missão marcada como concluída: entregue ao NPC."))
	_btn(v, "Pular para a próxima missão", func() -> void:
		game.call("admin_skip_quest")
		_done("Missão de história pulada."))
	_btn(v, "Campanha: liberar tudo (pular até o fim)", func() -> void:
		game.call("admin_finish_campaign")
		_done("Campanha concluída: tudo liberado."))
	_btn(v, "Zerar limites das missões do quadro", func() -> void:
		var book: MissionBook = game.get("missions")
		for kind in GameData.MISSION_KINDS:
			book.done[kind] = 0
		game.call("refresh_quest_ui")
		_done("Limites zerados (diárias, semanais e mensais)."))
	_btn(v, "Derrotar inimigos por perto", func() -> void:
		var p: Player = game.get("player")
		var n := 0
		for e in Skills.in_radius(get_tree(), p.global_position, 20.0):
			e.take_damage(e.hp + 1, p.global_position, false)
			n += 1
		_done("%d inimigos derrotados." % n))
	_btn(v, "Salvar agora", func() -> void:
		game.call("save_now")
		_done("Jogo salvo."))
	return v.get_meta("box")


func _add(cls: String, slot: String, rarity: String) -> Dictionary:
	var p: Player = game.get("player")
	var item := p.new_item(slot, rarity)
	item["cls"] = cls
	p.inventory.append(item)
	return item


func _give(equip: bool) -> void:
	var p: Player = game.get("player")
	var cls := String(GameData.CLASS_ORDER[_cls.selected])
	var slots: Array = Player.ITEM_SLOTS + ["ring"] if _slot.selected >= Player.ITEM_SLOTS.size() else [Player.ITEM_SLOTS[_slot.selected]]
	var rars: Array = GameData.RARITIES if _rar.selected == 4 else [GameData.RARITIES[_rar.selected]]
	var n := 0
	var last := {}
	for k in int(_qty.value):
		for slot in slots:
			for r in rars:
				last["%s%d" % [slot, last.size()]] = _add(cls, String(slot), String(r))
				n += 1
	var msg := "%d item(ns) de %s adicionado(s)." % [n, String(GameData.CLASSES[cls]["name"])]
	if equip:
		if cls != p.class_key:
			msg += " Não equipei: o item é de outra classe (troque de classe ao lado)."
		else:
			for slot in last:
				p.equip(last[slot])
			msg += " Equipado!"
	game.call("save_now")
	_done(msg)


func _done(text: String) -> void:
	_msg.text = text
	var gp: EquipmentPanel = game.get("gear_panel")
	if gp != null and gp.visible:
		gp.refresh()


func toggle() -> void:
	visible = not visible
	if visible:
		var p: Player = game.get("player")
		_cls.selected = GameData.CLASS_ORDER.find(p.class_key)
		_class_to.selected = GameData.CLASS_ORDER.find(p.class_key)
		_level.value = p.level
		_god.set_pressed_no_signal(p.god_mode)
		_msg.text = "Itens de outra classe ficam no inventário; para usar, troque de classe."
