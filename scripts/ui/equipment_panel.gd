class_name EquipmentPanel
extends CanvasLayer
## Equipamento (tecla I): arma e armadura com raridade, inventário e prévia 3D das skins.

var player: Player
var _vp: SubViewport
var _pivot: Node3D
var _slots := {}
var _list: VBoxContainer
var _preview_tier := ""
var _stats: Label


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
	panel.offset_top = -330
	panel.offset_bottom = 330
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
	for slot in ["weapon", "armor"]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		right.add_child(row)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(64, 64)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		row.add_child(icon)
		var lab := UiTheme.label("", 17)
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lab)
		_slots[slot] = {"icon": icon, "label": lab}
	_stats = UiTheme.label("", 15, Color(0.8, 0.9, 1.0))
	right.add_child(_stats)
	right.add_child(UiTheme.title("Inventário", 22))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 300)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)
	var hint := UiTheme.label("Itens caem dos monstros (raro), dos chefes e dos baús das missões. Lendárias são raríssimas.", 13, Color(0.75, 0.7, 0.62))
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
	var kit := ModelKit.load_kit("hero_%s_%s" % [player.class_key, a_r], 0.035)
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
	var path := "res://textures/items/%s_%s_%s.png" % [item["cls"], item["slot"], item["rarity"]]
	return load(path) if ResourceLoader.exists(path) else null


static func bonus_text(item: Dictionary) -> String:
	var r: Dictionary = GameData.RARITY[item["rarity"]]
	if String(item["slot"]) == "weapon":
		return "+%d%% de ataque" % int(round((float(r["atk"]) - 1.0) * 100.0))
	return "+%d%% de vida · %d%% menos dano" % [int(round((float(r["hp"]) - 1.0) * 100.0)), int(round(float(r["def"]) * 100.0))]


func refresh() -> void:
	if player == null:
		return
	for slot in ["weapon", "armor"]:
		var it: Dictionary = player.weapon if slot == "weapon" else player.armor
		var s: Dictionary = _slots[slot]
		(s["icon"] as TextureRect).texture = icon_for(it)
		var lab: Label = s["label"]
		lab.text = "%s — %s\n%s" % ["Arma" if slot == "weapon" else "Armadura", GameData.item_name(it), bonus_text(it)]
		lab.add_theme_color_override("font_color", GameData.RARITY[it["rarity"]]["color"])
	_stats.text = "Ataque %d  ·  Vida %d  ·  Redução de dano %d%%" % [int(player.atk), player.max_hp, int(player.defense * 100)]
	for c in _list.get_children():
		c.queue_free()
	var items := player.inventory.duplicate()
	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return GameData.RARITIES.find(String(a["rarity"])) > GameData.RARITIES.find(String(b["rarity"])))
	for it in items:
		var item: Dictionary = it
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(44, 44)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.texture = icon_for(item)
		row.add_child(icon)
		var cls_tag := "" if String(item["cls"]) == player.class_key else "  · " + String(GameData.CLASSES[item["cls"]]["name"])
		var lab := UiTheme.label("%s  (%s)%s\n%s" % [GameData.item_name(item), String(GameData.RARITY[item["rarity"]]["name"]), cls_tag, bonus_text(item)], 15, GameData.RARITY[item["rarity"]]["color"])
		lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lab)
		var b := Button.new()
		var equipped := int(item["uid"]) == int(player.weapon.get("uid", -1)) or int(item["uid"]) == int(player.armor.get("uid", -1))
		var other := String(item["cls"]) != player.class_key
		b.text = "Equipado" if equipped else ("Outra classe" if other else "Equipar")
		b.disabled = equipped or other
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func() -> void:
			player.equip(item)
			refresh())
		row.add_child(b)
		_list.add_child(row)
	_rebuild_preview()
