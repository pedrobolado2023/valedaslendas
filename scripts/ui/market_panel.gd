class_name MarketPanel
extends CanvasLayer
## Mercadinho do Jogo (tecla B): comprar itens de outros jogadores por gemas e anunciar os seus itens "Vendável"
## (os que caem de monstros/chefes). Imposto sobre a venda: 20% até o nível 59, 10% do 60 ao 79, 5% do 80 em diante.
## Tudo pelo servidor (Net.market_*): ele guarda os anúncios, confere o item e paga o vendedor (mesmo offline).

var game: Node
var _buy: VBoxContainer
var _sell: VBoxContainer
var _msg: Label
var _tax: Label
var _rows: Array = []


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
	panel.offset_left = -620
	panel.offset_right = 620
	panel.offset_top = -330
	panel.offset_bottom = 330
	panel.add_theme_stylebox_override("panel", Toon.ui_box(Color(0.05, 0.04, 0.03, 0.97), Color(0.4, 0.85, 0.5), 18, 10, 3))
	root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var t := UiTheme.title("Mercadinho do Jogo", 28)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var upd := Button.new()
	upd.text = "Atualizar"
	upd.focus_mode = Control.FOCUS_NONE
	upd.pressed.connect(refresh)
	head.add_child(upd)
	var close := Button.new()
	close.text = "Fechar (B)"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(func() -> void: visible = false)
	head.add_child(close)
	_tax = UiTheme.label("", 14, Color(0.85, 0.8, 0.65))
	v.add_child(_tax)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 20)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(cols)
	_buy = _col(cols, "À venda")
	_sell = _col(cols, "Seus itens vendáveis (escolha o preço em gemas)")
	_msg = UiTheme.label("", 15, Color(1.0, 0.85, 0.45))
	v.add_child(_msg)
	var net := get_node("/root/Net")
	net.market_rows.connect(func(rows: Array) -> void:
		_rows = rows
		_draw())
	net.market_event.connect(_on_event)
	visible = false


func _col(parent: Node, title: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(box)
	box.add_child(UiTheme.title(title, 17))
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.custom_minimum_size = Vector2(580, 440)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(sc)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	sc.add_child(list)
	return list


func toggle() -> void:
	visible = not visible
	if visible:
		refresh()


func refresh() -> void:
	var net := get_node("/root/Net")
	var p: Player = game.get("player")
	_tax.text = "Gemas: %d   ·   Imposto das suas vendas: %d%% (nível %d — 20%% até o 59, 10%% do 60 ao 79, 5%% do 80 em diante)" % [p.gems, int(GameData.market_tax(p.level) * 100), p.level]
	if net.online:
		net.market_list.rpc_id(1)
	else:
		_msg.text = "O Mercadinho só funciona online."
	_draw()


func _draw() -> void:
	var p: Player = game.get("player")
	for c in _buy.get_children():
		c.queue_free()
	for c in _sell.get_children():
		c.queue_free()
	if _rows.is_empty():
		_buy.add_child(UiTheme.label("Nenhum item à venda agora.", 14, Color(0.7, 0.7, 0.7)))
	for r in _rows:
		var it: Dictionary = r["item"]
		var row := HBoxContainer.new()
		var lab := UiTheme.label("%s  (%s · %s)\n%s  ·  vendedor: %s" % [GameData.item_name(it), String(GameData.SLOT_INFO[it["slot"]]["name"]),
			String(GameData.RARITY[it["rarity"]]["name"]), EquipmentPanel.bonus_text(it), String(r["seller"])], 13, GameData.RARITY[it["rarity"]]["color"])
		lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lab)
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		var lid := int(r["id"])
		if bool(r.get("mine", false)):
			b.text = "Cancelar (%d)" % int(r["price"])
			b.pressed.connect(func() -> void: get_node("/root/Net").market_cancel.rpc_id(1, lid))
		else:
			b.text = "Comprar: %d gemas" % int(r["price"])
			b.disabled = p.gems < int(r["price"])
			b.pressed.connect(func() -> void: get_node("/root/Net").market_buy.rpc_id(1, lid))
		row.add_child(b)
		_buy.add_child(row)
	var any := false
	for it in p.inventory:
		if not bool(it.get("sell", false)) or p.is_equipped(it):
			continue
		any = true
		var row := HBoxContainer.new()
		var lab := UiTheme.label("%s  (%s)" % [GameData.item_name(it), String(GameData.RARITY[it["rarity"]]["name"])], 13, GameData.RARITY[it["rarity"]]["color"])
		lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lab)
		var price := SpinBox.new()
		price.min_value = GameData.MARKET["min_price"]
		price.max_value = GameData.MARKET["max_price"]
		price.value = {"comum": 10, "rara": 40, "epica": 150, "lendaria": 800}.get(String(it["rarity"]), 20)
		row.add_child(price)
		var b := Button.new()
		b.text = "Anunciar"
		b.focus_mode = Control.FOCUS_NONE
		var uid := int(it["uid"])
		b.pressed.connect(func() -> void:
			game.call("save_now")   # o servidor confere o item pelo save
			await get_tree().create_timer(0.5).timeout
			get_node("/root/Net").market_sell.rpc_id(1, uid, int(price.value)))
		row.add_child(b)
		_sell.add_child(row)
	if not any:
		_sell.add_child(UiTheme.label("Sem itens vendáveis. Itens que caem de monstros, chefes e masmorras podem ser vendidos.", 14, Color(0.7, 0.7, 0.7)))


func _on_event(kind: String, d: Dictionary) -> void:
	var p: Player = game.get("player")
	match kind:
		"erro":
			_msg.text = String(d["msg"])
		"vendendo":
			for it in p.inventory.duplicate():
				if int(it["uid"]) == int(d["uid"]):
					p.inventory.erase(it)
			_msg.text = "Anunciado por %d gemas (você recebe %d depois do imposto)." % [int(d["price"]), int(d["payout"])]
		"comprou":
			p.gems -= int(d["price"])
			_add(p, d["item"])
			_msg.text = "Comprado: %s" % GameData.item_name(d["item"])
			Sfx.play("legendary", -6.0)
		"voltou":
			_add(p, d["item"])
			_msg.text = "Anúncio cancelado: o item voltou para o inventário."
		"guilda_paga":
			p.gems -= int(d["gems"])
			game.call("toast", "Guilda criada! (-%d gemas)" % int(d["gems"]), 3.0)
		"pago":
			Shop.credit_gems(p, int(d["gems"]), "mercadinho")
			game.call("toast", "Mercadinho: +%d gemas (%s)" % [int(d["gems"]), String(d["note"])], 3.5)
	p.stats_changed.emit()
	game.call("save_now")
	if visible:
		refresh()


func _add(p: Player, item: Dictionary) -> void:
	var it := p.new_item(String(item["slot"]), String(item["rarity"]))
	it["cls"] = item.get("cls", p.class_key)
	it["refine"] = int(item.get("refine", 0))
	it["sell"] = true
	p.add_item(it)
