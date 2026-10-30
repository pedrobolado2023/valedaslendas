class_name ShopPanel
extends CanvasLayer
## Loja (tecla L): cartões com os itens de GameData.SHOP, preço em gemas e botão de comprar (Shop.buy).

var player: Player
var _gems: Label
var _cards := []
var _msg: Label


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
	panel.offset_left = -560
	panel.offset_right = 560
	panel.offset_top = -340
	panel.offset_bottom = 340
	panel.add_theme_stylebox_override("panel", Toon.ui_box(Color(0.06, 0.035, 0.05, 0.97), UiTheme.GOLD, 20, 10, 3))
	root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var t := UiTheme.title("Loja", 30)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	_gems = UiTheme.title("", 22, Color(0.55, 0.9, 1.0))
	head.add_child(_gems)
	var close := Button.new()
	close.text = "Fechar (L)"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(func() -> void: visible = false)
	head.add_child(close)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 520)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	for it in GameData.SHOP:
		grid.add_child(_card(it))
	for sk in GameData.SKINS:   # skins da classe do herói que já têm modelo
		if String(sk["cls"]) == player.class_key and GameData.skin_ready(sk):
			grid.add_child(_card(Shop.item(String(sk["id"]))))
	_msg = UiTheme.label("Gemas: 5 por nível, recompensa do boss global e, em breve, pacotes de gemas.", 14, Color(0.8, 0.75, 0.65))
	v.add_child(_msg)
	visible = false


## Imagem de um item da loja (ou "mat_ferro" etc. para materiais). null se não existir.
static func icon_of(id: String) -> Texture2D:
	var path := "res://textures/shop/%s.png" % id
	return load(path) if ResourceLoader.exists(path) else null


func _card(it: Dictionary) -> Control:
	var col: Color = it["color"]
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(400, 140)
	box.add_theme_stylebox_override("panel", Toon.ui_box(Color(0.12, 0.07, 0.08, 0.95), col.darkened(0.35), 10, 8, 2))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	box.add_child(hb)
	var icon := TextureRect.new()   # imagem do item (tools/make_shop_icons.py)
	icon.custom_minimum_size = Vector2(84, 84)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = ShopPanel.icon_of(String(it["id"]))
	if String(it["kind"]) == "skin":   # foto do herói com a skin (blender/make_skins.py)
		var sp := "res://textures/skins/%s.png" % String(it["id"])
		if ResourceLoader.exists(sp):
			icon.texture = load(sp)
		icon.custom_minimum_size = Vector2(96, 128)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(icon)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(v)
	v.add_child(UiTheme.title(String(it["name"]), 18, col))
	var d := UiTheme.label(String(it["desc"]), 14)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(d)
	var info := UiTheme.label("", 13, Color(0.75, 0.7, 0.62))
	v.add_child(info)
	var buy := Button.new()
	buy.focus_mode = Control.FOCUS_NONE
	var id := String(it["id"])
	buy.pressed.connect(func() -> void:
		var err := Shop.buy(player, id)
		if err == "":
			Sfx.play("legendary" if int(it["price"]) >= 250 else "coin", -4.0)
			_msg.text = "Comprado: %s" % String(it["name"])
		else:
			Sfx.play("click", -6.0)
			_msg.text = err
		refresh())
	v.add_child(buy)
	_cards.append({"it": it, "info": info, "buy": buy})
	return box


func toggle() -> void:
	visible = not visible
	if visible:
		refresh()


func refresh() -> void:
	if player == null:
		return
	_gems.text = "Gemas: %d   " % player.gems
	for c in _cards:
		var it: Dictionary = c["it"]
		var id := String(it["id"])
		var n := Shop.owned(player, id)
		var mx := int(it.get("max", 0))
		var info := "Comprado %d/%d" % [n, mx] if mx > 1 else ("Já tem" if mx == 1 and n > 0 else "")
		if String(it["kind"]) == "mount" and player.mount == id:
			info = "Em uso (R monta)"
		if String(it["kind"]) == "pet" and player.pet == id:
			info = "Ativo"
		if String(it["kind"]) == "xp_boost" and Time.get_unix_time_from_system() < player.xp_boost_until:
			info = "Ativo: mais %d min" % int(ceil((player.xp_boost_until - Time.get_unix_time_from_system()) / 60.0))
		(c["info"] as Label).text = info
		var b: Button = c["buy"]
		var why := Shop.why_not(player, id)
		b.text = "%d gemas" % int(it["price"]) if why == "" or why == "Gemas insuficientes" else why
		b.disabled = why != ""
		# mascote já comprado pode ser trocado de volta de graça
		if String(it["kind"]) == "mount" and n > 0 and player.mount != id:
			b.text = "Usar"
			b.disabled = false
			for conn in b.pressed.get_connections():
				b.pressed.disconnect(conn["callable"])
			b.pressed.connect(func() -> void:
				player.mount = id
				player.set_riding(true)
				refresh())
		if String(it["kind"]) == "skin" and id in player.skins_owned:
			var why_use := Shop.skin_why(player, it["skin"])
			b.text = "Tirar skin" if player.skin == id else ("Usar" if why_use == "" else why_use)
			b.disabled = player.skin != id and why_use != ""
			info = "Em uso" if player.skin == id else "Comprada"
			(c["info"] as Label).text = info
			for conn in b.pressed.get_connections():
				b.pressed.disconnect(conn["callable"])
			b.pressed.connect(func() -> void:
				player.skin = "" if player.skin == id else id
				player.rebuild_visuals()
				refresh())
		if String(it["kind"]) == "pet" and n > 0 and player.pet != id:
			b.text = "Usar"
			b.disabled = false
			for conn in b.pressed.get_connections():
				b.pressed.disconnect(conn["callable"])
			b.pressed.connect(func() -> void:
				player.pet = id
				player.rebuild_visuals()
				refresh())
