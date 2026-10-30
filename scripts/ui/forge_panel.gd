class_name ForgePanel
extends CanvasLayer
## Forja (tecla U): fundir 3 itens iguais (mesma classe, tipo e raridade, fora do corpo) em 1 da raridade de cima,
## pagando ouro e materiais; desmontar um item em materiais. Materiais (player.mats) caem dos monstros e chefes.
## Item fundido só é "Vendável" se os 3 eram.

var game: Node
var _list: VBoxContainer
var _mats: Label
var _msg: Label


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
	panel.offset_left = -520
	panel.offset_right = 520
	panel.offset_top = -320
	panel.offset_bottom = 320
	panel.add_theme_stylebox_override("panel", Toon.ui_box(Color(0.07, 0.04, 0.03, 0.97), Color(1.0, 0.55, 0.2), 18, 10, 3))
	root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var t := UiTheme.title("Forja", 28)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var close := Button.new()
	close.text = "Fechar (U)"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(func() -> void: visible = false)
	head.add_child(close)
	_mats = UiTheme.label("", 16, Color(1.0, 0.8, 0.5))
	v.add_child(_mats)
	v.add_child(UiTheme.label("Fundir: 3 itens iguais (mesmo tipo e raridade) viram 1 da raridade de cima.  Desmontar: item vira material.", 13, Color(0.8, 0.75, 0.65)))
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 4)
	sc.add_child(_list)
	_msg = UiTheme.label("", 15, Color(1.0, 0.85, 0.45))
	v.add_child(_msg)
	visible = false


func toggle() -> void:
	visible = not visible
	if visible:
		refresh()


static func mats_text(m: Dictionary) -> String:
	var parts: Array = []
	for k in GameData.MATERIALS:
		parts.append("%s %d" % [String(GameData.MATERIALS[k]["name"]), int(m.get(k, 0))])
	return "   ·   ".join(parts)


func refresh() -> void:
	var p: Player = game.get("player")
	_mats.text = "Materiais:  " + mats_text(p.mats) + "     ·     Ouro %d" % p.gold
	for c in _list.get_children():
		c.queue_free()
	# grupos de itens iguais (fora do corpo)
	var groups := {}
	for it in p.inventory:
		if p.is_equipped(it) or String(it["cls"]) != p.class_key:
			continue
		var key := "%s|%s" % [it["slot"], it["rarity"]]
		if not groups.has(key):
			groups[key] = []
		(groups[key] as Array).append(it)
	var keys := groups.keys()
	keys.sort()
	for key in keys:
		var items: Array = groups[key]
		var sample: Dictionary = items[0]
		var r := String(sample["rarity"])
		var row := HBoxContainer.new()
		var lab := UiTheme.label("%s  (%s · %s)   ×%d" % [GameData.item_name(sample).get_slice(" +", 0), String(GameData.SLOT_INFO[sample["slot"]]["name"]), String(GameData.RARITY[r]["name"]), items.size()], 14, GameData.RARITY[r]["color"])
		lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lab)
		if GameData.FORGE.has(r):
			var cost: Dictionary = GameData.FORGE[r]
			var fb := Button.new()
			fb.focus_mode = Control.FOCUS_NONE
			fb.text = "Fundir 3 → %s  (%d ouro, %s)" % [String(GameData.RARITY[cost["to"]]["name"]), int(cost["gold"]), _cost_text(cost["mats"])]
			fb.disabled = items.size() < 3 or p.gold < int(cost["gold"]) or not _has(p, cost["mats"])
			fb.pressed.connect(func() -> void: _fuse(items.slice(0, 3)))
			row.add_child(fb)
		var db := Button.new()
		db.focus_mode = Control.FOCUS_NONE
		db.text = "Desmontar 1 (+%s)" % _cost_text(GameData.SALVAGE[r])
		db.pressed.connect(func() -> void: _salvage(items[items.size() - 1]))
		row.add_child(db)
		_list.add_child(row)
	if keys.is_empty():
		_list.add_child(UiTheme.label("Nenhum item fora do corpo.", 14, Color(0.7, 0.7, 0.7)))


static func _cost_text(m: Dictionary) -> String:
	var parts: Array = []
	for k in m:
		parts.append("%d %s" % [int(m[k]), String(GameData.MATERIALS[k]["name"])])
	return ", ".join(parts)


static func _has(p: Player, m: Dictionary) -> bool:
	for k in m:
		if int(p.mats.get(k, 0)) < int(m[k]):
			return false
	return true


func _fuse(items: Array) -> void:
	var p: Player = game.get("player")
	var r := String(items[0]["rarity"])
	var cost: Dictionary = GameData.FORGE[r]
	if items.size() < 3 or p.gold < int(cost["gold"]) or not _has(p, cost["mats"]):
		return
	p.gold -= int(cost["gold"])
	for k in cost["mats"]:
		p.mats[k] = int(p.mats.get(k, 0)) - int(cost["mats"][k])
	var all_sell := true
	for it in items:
		all_sell = all_sell and bool(it.get("sell", false))
		p.inventory.erase(it)
	var nw := p.new_item(String(items[0]["slot"]), String(cost["to"]))
	nw["sell"] = all_sell
	p.add_item(nw)
	_msg.text = "Forjado: %s!" % GameData.item_name(nw)
	game.call("quest_event", "forge", 1)
	Sfx.play("legendary" if String(cost["to"]) == "lendaria" else "equip", -4.0)
	p.stats_changed.emit()
	game.call("save_now")
	refresh()


func _salvage(it: Dictionary) -> void:
	var p: Player = game.get("player")
	var got: Dictionary = GameData.SALVAGE[String(it["rarity"])]
	p.inventory.erase(it)
	for k in got:
		p.mats[k] = int(p.mats.get(k, 0)) + int(got[k])
	_msg.text = "Desmontado: +" + _cost_text(got)
	game.call("quest_event", "forge", 1)
	Sfx.play("hit", -6.0, 0.8)
	game.call("save_now")
	refresh()
