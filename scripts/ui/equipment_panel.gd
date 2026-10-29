class_name EquipmentPanel
extends CanvasLayer
## Equipamento (tecla I): 10 encaixes (arma, elmo, peitoral, calças, luvas, botas, colar, brincos, 2 anéis),
## refino +1..+15, bônus de conjunto, poder total, inventário com filtro e prévia 3D do herói montado.

var player: Player
var _vp: SubViewport
var _pivot: Node3D
var _slots := {}
var _list: VBoxContainer
var _preview_tier := ""
var _stats: Label
var _filter := ""
var _filters: HBoxContainer


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
	panel.offset_left = -640
	panel.offset_right = 640
	panel.offset_top = -350
	panel.offset_bottom = 350
	panel.add_theme_stylebox_override("panel", Toon.ui_box(Color(0.06, 0.035, 0.05, 0.97), UiTheme.GOLD, 20, 10, 3))
	root.add_child(panel)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	panel.add_child(h)
	# esquerda: prévia 3D + galeria de skins
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	h.add_child(left)
	left.add_child(UiTheme.title("Equipamento", 28))
	left.add_child(_preview_box())
	var gal := UiTheme.label("Prévia das skins (só para ver):", 14, Color(0.8, 0.75, 0.65))
	left.add_child(gal)
	var tiers := HBoxContainer.new()
	tiers.add_theme_constant_override("separation", 6)
	left.add_child(tiers)
	for r in GameData.RARITIES:
		var b := Button.new()
		b.text = String(GameData.RARITY[r]["name"])
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_color_override("font_color", GameData.RARITY[r]["color"])
		var rr := String(r)
		b.pressed.connect(func() -> void:
			_preview_tier = rr
			_rebuild_preview())
		tiers.add_child(b)
	var mine := Button.new()
	mine.text = "Ver meu equipamento"
	mine.focus_mode = Control.FOCUS_NONE
	mine.pressed.connect(func() -> void:
		_preview_tier = ""
		_rebuild_preview())
	left.add_child(mine)
	# direita: equipados + inventário
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	h.add_child(right)
	var head := HBoxContainer.new()
	right.add_child(head)
	var t := UiTheme.title("Equipado", 22)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var close := Button.new()
	close.text = "Fechar (I)"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(func() -> void: visible = false)
	head.add_child(close)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 4)
	right.add_child(grid)
	for slot in GameData.GEAR_SLOTS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.custom_minimum_size = Vector2(400, 0)
		grid.add_child(row)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(40, 40)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		row.add_child(icon)
		var lab := UiTheme.label("", 13)
		lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lab)
		var rb := Button.new()
		rb.focus_mode = Control.FOCUS_NONE
		rb.add_theme_font_size_override("font_size", 12)
		var key := String(slot)
		rb.pressed.connect(func() -> void: _refine(key))
		row.add_child(rb)
		_slots[slot] = {"icon": icon, "label": lab, "refine": rb}
	_stats = UiTheme.label("", 15, Color(0.8, 0.9, 1.0))
	right.add_child(_stats)
	right.add_child(UiTheme.title("Inventário", 22))
	_filters = HBoxContainer.new()
	_filters.add_theme_constant_override("separation", 4)
	right.add_child(_filters)
	for f in [""] + Player.ITEM_SLOTS:
		var fb := Button.new()
		fb.text = "Todos" if f == "" else String(GameData.SLOT_INFO[f]["name"])
		fb.focus_mode = Control.FOCUS_NONE
		fb.add_theme_font_size_override("font_size", 12)
		var ff := String(f)
		fb.pressed.connect(func() -> void:
			_filter = ff
			refresh())
		_filters.add_child(fb)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 220)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)
	var hint := UiTheme.label("Itens caem dos monstros (raro), dos chefes e dos baús. Refino até +15 com ouro: do +4 em diante pode falhar e o item QUEBRA. Borda azul no +6, roxa no +9, dourada no +12. Conjunto: 2/4/6/10 peças da mesma raridade dão bônus.", 13, Color(0.75, 0.7, 0.62))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(hint)
	visible = false


func _preview_box() -> Control:
	var box := SubViewportContainer.new()
	box.stretch = true
	box.custom_minimum_size = Vector2(360, 420)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	_vp.size = Vector2i(360, 420)
	_vp.msaa_3d = Viewport.MSAA_2X
	box.add_child(_vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.48, 0.65)
	env.ambient_light_energy = 0.9
	env.glow_enabled = true
	env.glow_hdr_threshold = 0.9
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40.0, 35.0, 0.0)
	sun.light_energy = 1.3
	sun.light_color = Color(1.0, 0.85, 0.7)
	_vp.add_child(sun)
	var cam := Camera3D.new()
	cam.fov = 30.0
	cam.position = Vector3(0.0, 1.5, 6.6)
	cam.rotation_degrees = Vector3(-6.0, 0.0, 0.0)
	_vp.add_child(cam)
	_pivot = Node3D.new()
	_vp.add_child(_pivot)
	var tw := _pivot.create_tween().set_loops()
	tw.tween_property(_pivot, "rotation:y", TAU + 0.5, 10.0).from(0.5)
	return box


func _rebuild_preview() -> void:
	for c in _pivot.get_children():
		c.queue_free()
	var a_r := _preview_tier if _preview_tier != "" else String(player.armor.get("rarity", "comum"))
	var w_r := _preview_tier if _preview_tier != "" else String(player.weapon.get("rarity", "comum"))
	var holder := Node3D.new()
	_pivot.add_child(holder)
	var rars := player.visual_rarities()
	if _preview_tier != "":
		for k in rars:
			rars[k] = _preview_tier
	var kit := ModelKit.load_hero(player.class_key, rars)
	if kit == null:
		kit = ModelKit.load_kit("hero_%s_%s" % [player.class_key, a_r], 0.035)
	if kit == null:
		return
	holder.add_child(kit.root)
	kit.play("idle")
	Player.attach_weapon(kit, player.class_key, w_r)
	Player.add_gear_effects(holder, kit, w_r, a_r, player.class_key)


func toggle() -> void:
	visible = not visible
	if visible:
		_preview_tier = ""
		refresh()


static func icon_for(item: Dictionary) -> Texture2D:
	if item.is_empty():
		return null
	var slot := String(item["slot"])
	var path := "res://textures/items/%s_%s_%s.png" % [item["cls"], "armor" if slot == "chest" else slot, item["rarity"]]
	if not ResourceLoader.exists(path):   # peças sem ícone da classe: ícone geral do tipo
		path = "res://textures/items/slot_%s_%s.png" % [slot, item["rarity"]]
	return load(path) if ResourceLoader.exists(path) else null


const STAT_NAMES := {"atk": "ataque", "hp": "vida", "mp": "mana", "def": "defesa", "speed": "velocidade"}


static func stats_text(stats: Dictionary) -> String:
	var parts: Array = []
	for k in stats:
		parts.append("+%.1f%% %s" % [float(stats[k]) * 100.0, String(STAT_NAMES.get(k, k))])
	return " · ".join(parts)


static func bonus_text(item: Dictionary) -> String:
	return stats_text(GameData.item_stats(item))


## Moldura do ícone na cor do refino (azul +6, roxo +9, dourado +12).
static func _border(icon: TextureRect, item: Dictionary) -> void:
	for c in icon.get_children():
		c.queue_free()
	var col := GameData.refine_color(item) if not item.is_empty() else Color(0, 0, 0, 0)
	if col.a <= 0.0:
		return
	var p := Panel.new()
	p.set_anchors_preset(Control.PRESET_FULL_RECT)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.set_border_width_all(4)
	sb.border_color = col
	sb.set_corner_radius_all(8)
	sb.shadow_color = Color(col.r, col.g, col.b, 0.5)
	sb.shadow_size = 6
	p.add_theme_stylebox_override("panel", sb)
	icon.add_child(p)


func _refine(key: String) -> void:
	var it: Dictionary = player.gear.get(key, {})
	if it.is_empty():
		return
	var r := player.refine(it)
	var g: Node = player.get_parent()
	while g != null and not g.has_method("toast"):
		g = g.get_parent()
	if g != null:
		var msg: String = {0: "Refino falhou (só o ouro foi gasto).", 2: "O item QUEBROU no refino!", 3: "Falhou, mas a Pedra de Proteção salvou o item!", -1: "Sem ouro suficiente."}.get(r, "%s refinado!" % GameData.item_name(it))
		g.call("toast", msg, 2.0)
	refresh()


func refresh() -> void:
	if player == null:
		return
	for slot in GameData.GEAR_SLOTS:
		var it: Dictionary = player.gear.get(slot, {})
		var s: Dictionary = _slots[slot]
		(s["icon"] as TextureRect).texture = icon_for(it)
		_border(s["icon"], it)
		var lab: Label = s["label"]
		var rb: Button = s["refine"]
		var info_key := "ring" if String(slot).begins_with("ring") else String(slot)
		if it.is_empty():
			lab.text = "%s — vazio" % String(GameData.SLOT_INFO[info_key]["name"])
			lab.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
			rb.visible = false
			continue
		lab.text = "%s\n%s" % [GameData.item_name(it), bonus_text(it)]
		lab.add_theme_color_override("font_color", GameData.RARITY[it["rarity"]]["color"])
		rb.visible = true
		if int(it.get("refine", 0)) >= GameData.REFINE_MAX:
			rb.text = "Máx."
			rb.disabled = true
		else:
			var risk := " · quebra" if int(it.get("refine", 0)) >= GameData.REFINE_SAFE else ""
			rb.text = "Refinar\n%d ouro · %d%%%s" % [GameData.refine_cost(it), int(GameData.refine_chance(it) * 100.0), risk]
			rb.disabled = player.gold < GameData.refine_cost(it)
	var sb := player.set_bonus()
	var set_txt := "Sem bônus de conjunto (2+ peças da mesma raridade)"
	if int(sb["pieces"]) >= 2:
		set_txt = "Conjunto %s (%d peças): %s" % [String(GameData.RARITY[sb["rarity"]]["name"]), int(sb["pieces"]), stats_text(sb["stats"])]
	set_txt += "   ·   Pedras de Proteção: %d (loja L)" % int(player.stats.get("stones", 0))
	_stats.text = "PODER %d   ·   Ataque %d · Vida %d · Mana %d · Redução de dano %d%% · Ouro %d\n%s" % [
		player.power(), int(player.atk), player.max_hp, player.max_mp, int(player.defense * 100), player.gold, set_txt]
	for c in _list.get_children():
		c.queue_free()
	var items := player.inventory.duplicate()
	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return GameData.RARITIES.find(String(a["rarity"])) > GameData.RARITIES.find(String(b["rarity"])))
	for it in items:
		var item: Dictionary = it
		if _filter != "" and String(item["slot"]) != _filter:
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(44, 44)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.texture = icon_for(item)
		row.add_child(icon)
		_border(icon, item)
		var cls_tag := "" if String(item["cls"]) == player.class_key else "  · " + String(GameData.CLASSES[item["cls"]]["name"])
		var lab := UiTheme.label("%s  (%s · %s)%s\n%s" % [GameData.item_name(item), String(GameData.SLOT_INFO[item["slot"]]["name"]), String(GameData.RARITY[item["rarity"]]["name"]), cls_tag, bonus_text(item)], 14, GameData.RARITY[item["rarity"]]["color"])
		lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lab)
		var b := Button.new()
		var equipped := player.is_equipped(item)
		var other := String(item["cls"]) != player.class_key
		b.text = "Equipado" if equipped else ("Outra classe" if other else "Equipar")
		b.disabled = equipped or other
		b.focus_mode = Control.FOCUS_NONE
		var ring := String(item["slot"]) == "ring"
		if ring and not equipped:
			b.text = "Anel 1"
		b.pressed.connect(func() -> void:
			player.equip(item, "ring1" if ring else "")
			refresh())
		row.add_child(b)
		if ring and not equipped and not other:   # anel: escolher o encaixe
			var b2 := Button.new()
			b2.text = "Anel 2"
			b2.focus_mode = Control.FOCUS_NONE
			b2.pressed.connect(func() -> void:
				player.equip(item, "ring2")
				refresh())
			row.add_child(b2)
		_list.add_child(row)
	_rebuild_preview()
