class_name SocialPanel
extends CanvasLayer
## Social (tecla G): grupo (convidar pelo nome, aceitar, sair), amigos (online/offline, adicionar, remover) e enviar
## item para outro jogador online. Tudo passa pelo servidor (Net); amigos ficam no save (player.friends).

var game: Node
var _party: VBoxContainer
var _friends: VBoxContainer
var _invite_box: HBoxContainer
var _name: LineEdit
var _items: OptionButton
var _msg: Label
var _members: Array = []
var _online: Array = []
var _invite_from := ""
var _guild := {}
var _guild_box: VBoxContainer
var _guild_inv := ""


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
	panel.offset_left = -430
	panel.offset_right = 430
	panel.offset_top = -290
	panel.offset_bottom = 290
	panel.add_theme_stylebox_override("panel", Toon.ui_box(Color(0.05, 0.04, 0.06, 0.97), UiTheme.GOLD, 18, 10, 3))
	root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var t := UiTheme.title("Social", 28)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(_b("Fechar (G)", func() -> void: visible = false))
	var nr := HBoxContainer.new()
	nr.add_theme_constant_override("separation", 6)
	v.add_child(nr)
	_name = LineEdit.new()
	_name.placeholder_text = "Nome do herói"
	_name.custom_minimum_size = Vector2(260, 0)
	nr.add_child(_name)
	nr.add_child(_b("Convidar para o grupo", func() -> void: _net_call("party_invite", _name.text.strip_edges())))
	nr.add_child(_b("Adicionar amigo", _add_friend))
	nr.add_child(_b("Desafiar (duelo)", func() -> void:
		if game.call("gate", "duel"):
			_net_call("duel_request", _name.text.strip_edges())))
	_invite_box = HBoxContainer.new()
	_invite_box.visible = false
	v.add_child(_invite_box)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 24)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(cols)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(380, 0)
	cols.add_child(left)
	left.add_child(UiTheme.title("Grupo (XP e ouro divididos no mesmo mapa)", 16))
	_party = VBoxContainer.new()
	left.add_child(_party)
	left.add_child(_b("Sair do grupo", func() -> void: _net_call("party_leave")))
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)
	right.add_child(UiTheme.title("Amigos", 16))
	_friends = VBoxContainer.new()
	right.add_child(_friends)
	v.add_child(UiTheme.title("Guilda", 16))
	_guild_box = VBoxContainer.new()
	v.add_child(_guild_box)
	var ir := HBoxContainer.new()
	ir.visible = false   # trocado pelo Mercadinho do Jogo (B)
	v.add_child(ir)
	_items = OptionButton.new()
	_items.custom_minimum_size = Vector2(520, 0)
	ir.add_child(_items)
	ir.add_child(_b("Enviar", _gift))
	_msg = UiTheme.label("", 14, Color(1.0, 0.8, 0.5))
	v.add_child(_msg)
	var net := get_node("/root/Net")
	net.party_changed.connect(func(m: Array) -> void:
		_members = m
		_refresh_lists())
	net.online_names.connect(func(n: Array) -> void:
		_online = n
		_refresh_lists())
	net.guild_info.connect(func(info: Dictionary) -> void:
		_guild = info
		game.player.set_meta("guild", String(info.get("name", "")))
		_refresh_lists())
	net.guild_invited.connect(func(g: String, from: String) -> void:
		_guild_inv = g
		game.call("toast", "%s te convidou para a guilda %s — aperte G" % [from, g], 3.5)
		_refresh_lists())
	net.party_invited.connect(func(from: String) -> void:
		_invite_from = from
		game.call("toast", "%s te convidou para o grupo — aperte G" % from, 3.0)
		_refresh_lists())
	net.item_received.connect(func(item: Dictionary, from: String) -> void:
		var p: Player = game.get("player")
		var it := p.new_item(String(item["slot"]), String(item["rarity"]))
		it["cls"] = item.get("cls", p.class_key)
		it["refine"] = int(item.get("refine", 0))
		p.add_item(it)
		game.call("toast", "%s te enviou: %s" % [from, GameData.item_name(it)], 3.0)
		game.call("save_now"))
	net.gift_done.connect(func(uid: int, ok: bool, msg: String) -> void:
		_msg.text = msg
		if ok:
			var p: Player = game.get("player")
			for it in p.inventory.duplicate():
				if int(it["uid"]) == uid:
					p.inventory.erase(it)
			game.call("save_now")
		refresh())
	visible = false


func _b(text: String, f: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(f)
	return b


func _net_call(m: String, arg: Variant = null) -> void:
	var net := get_node("/root/Net")
	if not net.online:
		_msg.text = "Precisa estar online."
		return
	if arg == null:
		net.rpc_id(1, m)
	else:
		net.rpc_id(1, m, arg)


func _draw_guild() -> void:
	for c in _guild_box.get_children():
		c.queue_free()
	if _guild_inv != "":
		var r := HBoxContainer.new()
		r.add_child(UiTheme.label("Convite da guilda %s  " % _guild_inv, 15, Color(0.75, 0.6, 1.0)))
		r.add_child(_b("Entrar", func() -> void:
			_net_call("guild_accept")
			_guild_inv = ""
			_refresh_lists()))
		_guild_box.add_child(r)
	if not game.call("feature_on", "guild"):
		_guild_box.add_child(UiTheme.label("Guildas: libera na campanha principal.", 14, Color(0.7, 0.7, 0.7)))
		return
	if _guild.is_empty():
		var r2 := HBoxContainer.new()
		r2.add_child(UiTheme.label("Sem guilda. Digite o nome acima e crie (%d gemas)  " % GameData.GUILD["cost"], 14, Color(0.7, 0.7, 0.7)))
		r2.add_child(_b("Criar guilda", func() -> void: _net_call("guild_create", _name.text.strip_edges())))
		_guild_box.add_child(r2)
		return
	var names: Array = []
	for m in _guild["members"]:
		names.append(("★ " if m[2] else "") + String(m[0]) + (" ●" if m[1] else ""))
	_guild_box.add_child(UiTheme.label("<%s>  ·  %d pontos  ·  %d membros  ·  chat: /c" % [_guild["name"], int(_guild["points"]), names.size()], 15, Color(0.75, 0.6, 1.0)))
	var ml := UiTheme.label(", ".join(names), 13, Color(0.85, 0.8, 0.95))
	ml.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_guild_box.add_child(ml)
	var r3 := HBoxContainer.new()
	var dg: Dungeon = game.get("dungeon")
	if dg != null:
		r3.add_child(_b("Boss da guilda (já feito esta semana)" if dg.guild_done_week() else "Boss da guilda (semanal)", func() -> void:
			visible = false
			dg.enter_guild()))
	r3.add_child(_b("Convidar o nome acima", func() -> void: _net_call("guild_invite", _name.text.strip_edges())))
	if bool(_guild.get("leader", false)):
		r3.add_child(_b("Expulsar o nome acima", func() -> void: _net_call("guild_leave", _name.text.strip_edges())))
	r3.add_child(_b("Sair da guilda", func() -> void: _net_call("guild_leave", "")))
	_guild_box.add_child(r3)


func _add_friend() -> void:
	var p: Player = game.get("player")
	var nm := GameData.clean_name(_name.text)
	if nm.length() >= 2 and not p.friends.has(nm):
		p.friends.append(nm)
		game.call("save_now")
	refresh()


func _gift() -> void:
	if _items.selected < 0 or _name.text.strip_edges() == "":
		_msg.text = "Escolha o item e digite o nome de quem vai receber."
		return
	game.call("save_now")   # o servidor confere o item pelo save
	var uid := _items.get_item_id(_items.selected)
	await get_tree().create_timer(0.6).timeout
	var net := get_node("/root/Net")
	if net.online:
		net.send_item.rpc_id(1, _name.text.strip_edges(), uid)
		_msg.text = "Enviando..."


func toggle() -> void:
	visible = not visible
	if visible:
		refresh()


func refresh() -> void:
	var net := get_node("/root/Net")
	if net.online:
		net.who_online.rpc_id(1)
	var p: Player = game.get("player")
	_items.clear()
	for it in p.inventory:
		if not p.is_equipped(it):
			_items.add_item("%s (%s)" % [GameData.item_name(it), String(GameData.RARITY[it["rarity"]]["name"])], int(it["uid"]))
	_refresh_lists()


func _refresh_lists() -> void:
	for c in _party.get_children():
		c.queue_free()
	for c in _friends.get_children():
		c.queue_free()
	for c in _invite_box.get_children():
		c.queue_free()
	_invite_box.visible = _invite_from != "" or String(game.get("duel_from")) != ""
	if String(game.get("duel_from")) != "":
		_invite_box.add_child(UiTheme.label("%s te desafiou para um duelo  " % game.get("duel_from"), 15, Color(1.0, 0.5, 0.4)))
		_invite_box.add_child(_b("Aceitar duelo", func() -> void:
			_net_call("duel_accept")
			game.set("duel_from", "")
			_refresh_lists()))
	if _invite_from != "":
		_invite_box.add_child(UiTheme.label("%s te convidou para o grupo  " % _invite_from, 15, Color(0.55, 1.0, 0.6)))
		_invite_box.add_child(_b("Aceitar", func() -> void:
			_net_call("party_accept")
			_invite_from = ""
			_refresh_lists()))
		_invite_box.add_child(_b("Recusar", func() -> void:
			_invite_from = ""
			_refresh_lists()))
	_draw_guild()
	if _members.is_empty():
		_party.add_child(UiTheme.label("Sem grupo. Convide alguém pelo nome.", 14, Color(0.7, 0.7, 0.7)))
	for m in _members:
		_party.add_child(UiTheme.label("• " + String(m), 15, Color(0.55, 1.0, 0.6)))
	var p: Player = game.get("player")
	if p.friends.is_empty():
		_friends.add_child(UiTheme.label("Nenhum amigo ainda.", 14, Color(0.7, 0.7, 0.7)))
	for f in p.friends.duplicate():
		var row := HBoxContainer.new()
		var on := _online.has(f)
		row.add_child(UiTheme.label(("● " if on else "○ ") + String(f) + ("  (online)" if on else ""), 15, Color(0.55, 1.0, 0.6) if on else Color(0.7, 0.7, 0.7)))
		var nm := String(f)
		row.add_child(_b("Convidar", func() -> void: _net_call("party_invite", nm)))
		row.add_child(_b("Remover", func() -> void:
			p.friends.erase(nm)
			game.call("save_now")
			_refresh_lists()))
		_friends.add_child(row)
