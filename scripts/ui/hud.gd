class_name Hud
extends CanvasLayer
## Interface do jogo: vida/mana/XP, barra de skills, missão atual, minimapa, botões e avisos.

signal skill_clicked(i: int)
signal auto_combat_pressed
signal skills_pressed
signal map_pressed
signal music_pressed
signal path_pressed
signal auto_quest_pressed
signal missions_pressed
signal gear_pressed
signal admin_pressed
signal shop_pressed
signal pets_pressed
signal rewards_pressed
signal settings_pressed
signal social_pressed
signal ranking_pressed
signal market_pressed
signal forge_pressed
signal fragments_pressed
signal kingdom_pressed

var player: Player
var root: Control
var minimap: Minimap

var _name: Label
var _portrait: TextureRect
var _hp: ProgressBar
var _hp_t: Label
var _mp: ProgressBar
var _mp_t: Label
var _xp: ProgressBar
var _xp_t: Label
var _gold: Label
var _slots: Array = []
var _btn_auto: Button
var _btn_skills: Button
var _gear_btn: Button
var _gear_menu: PanelContainer
var _quest_box: PanelContainer
var _quest_title: Label
var _quest_obj: Label
var _quest_body: Array = []     # o que some ao minimizar o painel de missões
var _quest_min_btn: Button
var _btn_path: Button
var _btn_qauto: Button
var _missions: Label
var _toast: Label
var _toast_tw: Tween
var _banner: VBoxContainer
var _banner_t: Label
var _banner_s: Label
var _banner_tw: Tween
var _buffs: Label


func setup(p: Player, game: Node) -> void:
	player = p
	layer = 10
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiTheme.get_theme()
	add_child(root)
	_build_status()
	_build_skillbar()
	_build_right(game)
	_build_buttons()
	_build_toast()
	refresh()


func _build_status() -> void:
	var box := PanelContainer.new()
	box.position = Vector2(16, 16)
	box.custom_minimum_size = Vector2(400, 0)
	root.add_child(box)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	box.add_child(h)
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(84, 84)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.texture = load("res://textures/icons/%s.png" % GameData.SKILLS[player.class_key][0]["id"])
	h.add_child(_portrait)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 3)
	h.add_child(v)
	_name = UiTheme.title("", 21)
	v.add_child(_name)
	var r := _bar_row(v, Color(0.78, 0.13, 0.17), 20.0)
	_hp = r[0]
	_hp_t = r[1]
	r = _bar_row(v, Color(0.2, 0.42, 0.9), 16.0)
	_mp = r[0]
	_mp_t = r[1]
	r = _bar_row(v, Color(0.85, 0.65, 0.2), 11.0)
	_xp = r[0]
	_xp_t = r[1]
	_xp_t.add_theme_font_size_override("font_size", 11)
	var g := HBoxContainer.new()
	v.add_child(g)
	_gold = UiTheme.label("", 16, Color(1.0, 0.85, 0.4))
	g.add_child(_gold)
	_buffs = UiTheme.label("", 15, Color(0.7, 0.95, 1.0))
	_buffs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_buffs.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	g.add_child(_buffs)


func _bar_row(parent: Node, color: Color, h: float) -> Array:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(0, h)
	parent.add_child(holder)
	var b := UiTheme.bar(color, h)
	b.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(b)
	var t := UiTheme.label("", 14)
	t.set_anchors_preset(Control.PRESET_FULL_RECT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	holder.add_child(t)
	return [b, t]


func _build_skillbar() -> void:
	var wrap := VBoxContainer.new()
	wrap.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	wrap.grow_horizontal = Control.GROW_DIRECTION_BOTH
	wrap.grow_vertical = Control.GROW_DIRECTION_BEGIN
	wrap.offset_bottom = -14
	wrap.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(wrap)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Toon.ui_box(Color(0.05, 0.03, 0.05, 0.88), UiTheme.EDGE, 10, 12))
	wrap.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	for i in player.skill_count():
		row.add_child(_make_slot(i))
	var keys := "1-%d" % player.skill_count() if player.skill_count() < 10 else "1-9 e 0"
	var hint := UiTheme.label("Clique / Espaço: ataque básico   ·   %s: skills   ·   E: falar" % keys, 14, Color(0.8, 0.75, 0.65))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wrap.add_child(hint)


func _make_slot(i: int) -> Control:
	var sk: Dictionary = GameData.SKILLS[player.class_key][i]
	var b := Button.new()
	b.custom_minimum_size = Vector2(78, 78)
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = String(sk["name"])
	b.add_theme_stylebox_override("normal", Toon.ui_box(Color(0, 0, 0, 0.6), Color(0.3, 0.22, 0.12), 0, 8))
	b.add_theme_stylebox_override("hover", Toon.ui_box(Color(0, 0, 0, 0.6), UiTheme.GOLD, 0, 8))
	b.add_theme_stylebox_override("pressed", Toon.ui_box(Color(0, 0, 0, 0.6), Color(1, 1, 1), 0, 8))
	b.pressed.connect(func() -> void: skill_clicked.emit(i))
	var icon := TextureRect.new()
	icon.texture = load("res://textures/icons/%s.png" % sk["id"])
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 4
	icon.offset_top = 4
	icon.offset_right = -4
	icon.offset_bottom = -4
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(icon)
	var cd := ColorRect.new()
	cd.color = Color(0, 0, 0, 0.68)
	cd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cd.position = Vector2(4, 4)
	cd.size = Vector2(70, 0)
	b.add_child(cd)
	var cd_t := UiTheme.label("", 24)
	cd_t.set_anchors_preset(Control.PRESET_FULL_RECT)
	cd_t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cd_t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cd_t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(cd_t)
	var key := UiTheme.label(str((i + 1) % 10), 15, Color(1.0, 0.9, 0.6))
	key.position = Vector2(6, 2)
	key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(key)
	var lv := UiTheme.label("", 13, Color(0.75, 1.0, 0.75))
	lv.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	lv.position = Vector2(42, 56)
	lv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(lv)
	_slots.append({"btn": b, "icon": icon, "cd": cd, "cd_t": cd_t, "lv": lv})
	return b


func _build_right(game: Node) -> void:
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	col.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	col.offset_left = -316
	col.offset_right = -16
	col.offset_top = 16
	col.add_theme_constant_override("separation", 10)
	root.add_child(col)
	minimap = Minimap.new()
	minimap.game = game
	minimap.custom_minimum_size = Vector2(300, 300)
	col.add_child(minimap)
	_quest_box = PanelContainer.new()
	col.add_child(_quest_box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_quest_box.add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	_quest_title = UiTheme.title("", 19)
	_quest_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_quest_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_quest_title)
	_quest_min_btn = Button.new()   # minimizar / abrir o painel (fica salvo nas configurações)
	_quest_min_btn.focus_mode = Control.FOCUS_NONE
	_quest_min_btn.custom_minimum_size = Vector2(34, 30)
	_quest_min_btn.tooltip_text = "Minimizar / abrir o painel de missões"
	_quest_min_btn.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_quest_min_btn.pressed.connect(func() -> void: set_quest_min((_quest_body[0] as Control).visible))
	top.add_child(_quest_min_btn)
	_quest_obj = UiTheme.label("", 16)
	_quest_obj.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_quest_obj)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	v.add_child(h)
	_btn_path = Button.new()
	_btn_path.text = "Mostrar caminho"
	_btn_path.toggle_mode = true
	_btn_path.focus_mode = Control.FOCUS_NONE
	_btn_path.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_path.pressed.connect(func() -> void: path_pressed.emit())
	h.add_child(_btn_path)
	_btn_qauto = Button.new()
	_btn_qauto.text = "Ir automático"
	_btn_qauto.toggle_mode = true
	_btn_qauto.focus_mode = Control.FOCUS_NONE
	_btn_qauto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_qauto.pressed.connect(func() -> void: auto_quest_pressed.emit())
	h.add_child(_btn_qauto)
	var sep := HSeparator.new()
	v.add_child(sep)
	_missions = UiTheme.label("", 14, Color(0.85, 0.82, 0.72))
	_missions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_missions)
	_quest_body = [_quest_obj, h, sep, _missions]
	var cfg := ConfigFile.new()
	cfg.load("user://config.cfg")
	set_quest_min(bool(cfg.get_value("hud", "quest_min", false)))


## Minimiza (só o título fica) ou abre o painel de missões.
func set_quest_min(on: bool) -> void:
	for n in _quest_body:
		(n as Control).visible = not on
	_quest_min_btn.text = "+" if on else "–"
	var cfg := ConfigFile.new()
	cfg.load("user://config.cfg")
	cfg.set_value("hud", "quest_min", on)
	cfg.save("user://config.cfg")


## Botão de engrenagem (canto de baixo à esquerda): abre o menu com todas as funções (as teclas continuam valendo).
func _build_buttons() -> void:
	_gear_btn = Button.new()
	_gear_btn.icon = load("res://textures/ui/gear.png")
	_gear_btn.expand_icon = true
	_gear_btn.custom_minimum_size = Vector2(64, 64)
	_gear_btn.focus_mode = Control.FOCUS_NONE
	_gear_btn.tooltip_text = "Menu"
	_gear_btn.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_gear_btn.offset_left = 16
	_gear_btn.offset_top = -80
	_gear_btn.offset_right = 80
	_gear_btn.offset_bottom = -16
	_gear_btn.pressed.connect(func() -> void: _gear_menu.visible = not _gear_menu.visible)
	root.add_child(_gear_btn)
	_gear_menu = PanelContainer.new()
	_gear_menu.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_gear_menu.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_gear_menu.offset_left = 16
	_gear_menu.offset_bottom = -88
	_gear_menu.add_theme_stylebox_override("panel", Toon.ui_box(Color(0.06, 0.035, 0.05, 0.96), UiTheme.GOLD, 12, 8, 2))
	_gear_menu.visible = false
	root.add_child(_gear_menu)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_gear_menu.add_child(v)
	_btn_auto = _button(v, "Auto-combate (T)", func() -> void: auto_combat_pressed.emit())
	_btn_auto.toggle_mode = true
	_btn_auto.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_btn_auto.custom_minimum_size = Vector2(240, 40)
	_btn_skills = _menu_btn(v, "Skills (K)", skills_pressed)
	_menu_btn(v, "Missões (J)", missions_pressed)
	_menu_btn(v, "Equipamento (I)", gear_pressed)
	_menu_btn(v, "Pets (P)", pets_pressed)
	_menu_btn(v, "Fragmentos dos Reinos (Y)", fragments_pressed)
	_menu_btn(v, "Reino e Guerra dos Reinos (H)", kingdom_pressed)
	_menu_btn(v, "Recompensas (O)", rewards_pressed)
	_menu_btn(v, "Social: grupo, amigos, duelo (G)", social_pressed)
	_menu_btn(v, "Ranking geral (N)", ranking_pressed)
	_menu_btn(v, "Loja (L)", shop_pressed)
	_menu_btn(v, "Mercadinho do Jogo (B)", market_pressed)
	_menu_btn(v, "Forja (U)", forge_pressed)
	_menu_btn(v, "Mapa (M)", map_pressed)
	_menu_btn(v, "Música", music_pressed)
	_menu_btn(v, "Configurações (Esc)", settings_pressed)
	if GameData.ADMIN_ENABLED:
		var ab := _menu_btn(v, "Admin (F1)", admin_pressed)
		ab.add_theme_color_override("font_color", Color(1.0, 0.6, 0.5))


func _menu_btn(parent: Node, text: String, sig: Signal) -> Button:
	var b := _button(parent, text, func() -> void:
		_gear_menu.visible = false
		sig.emit())
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(240, 40)
	return b


func _button(parent: Node, text: String, f: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(f)
	parent.add_child(b)
	return b


func _build_toast() -> void:
	_toast = UiTheme.title("", 24, Color(1.0, 0.88, 0.55))
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.offset_left = -420
	_toast.offset_right = 420
	_toast.offset_top = 150
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.modulate.a = 0.0
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_toast)
	_banner = VBoxContainer.new()
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.offset_left = -500
	_banner.offset_right = 500
	_banner.offset_top = 60
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.modulate.a = 0.0
	root.add_child(_banner)
	_banner_t = UiTheme.title("", 46)
	_banner_t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_child(_banner_t)
	_banner_s = UiTheme.label("", 20, Color(0.9, 0.85, 0.75))
	_banner_s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_child(_banner_s)


func toast(text: String, secs: float = 2.5) -> void:
	_toast.text = text
	_toast.modulate.a = 1.0
	if _toast_tw != null and _toast_tw.is_valid():
		_toast_tw.kill()
	_toast_tw = create_tween()
	_toast_tw.tween_interval(secs)
	_toast_tw.tween_property(_toast, "modulate:a", 0.0, 0.5)


func banner(title: String, sub: String = "", secs: float = 2.6) -> void:
	_banner_t.text = title
	_banner_s.text = sub
	if _banner_tw != null and _banner_tw.is_valid():
		_banner_tw.kill()
	_banner_tw = create_tween()
	_banner_tw.tween_property(_banner, "modulate:a", 1.0, 0.3)
	_banner_tw.tween_interval(secs)
	_banner_tw.tween_property(_banner, "modulate:a", 0.0, 0.8)


func set_quest(title: String, objective: String, can_act: bool, path_on: bool, auto_on: bool) -> void:
	_quest_title.text = title
	_quest_obj.text = objective
	_btn_path.disabled = not can_act
	_btn_qauto.disabled = not can_act
	_btn_path.set_pressed_no_signal(path_on)
	_btn_qauto.set_pressed_no_signal(auto_on)
	_btn_qauto.text = "Automático: ON" if auto_on else "Ir automático"


func set_missions(text: String) -> void:
	_missions.text = text


func set_auto_combat(on: bool) -> void:
	_btn_auto.set_pressed_no_signal(on)
	_btn_auto.text = "Auto-combate: ON" if on else "Auto-combate (T)"


func refresh() -> void:
	if player == null:
		return
	var p := player
	_name.text = "%s  ·  %s  ·  Nv %d" % [p.hero_name, String(p.cdata["name"]), p.level] if p.hero_name != "" else "%s  ·  Nv %d" % [String(p.cdata["name"]), p.level]
	_hp.max_value = p.max_hp
	_hp.value = p.hp
	_hp_t.text = "%d / %d" % [int(ceil(p.hp)), p.max_hp] + ("  (+%d escudo)" % int(p.shield) if p.shield > 0.0 else "")
	_mp.max_value = p.max_mp
	_mp.value = p.mp
	_mp_t.text = "%d / %d" % [int(p.mp), p.max_mp]
	if p.level >= GameData.MAX_LEVEL:
		_xp.max_value = 1
		_xp.value = 1
		_xp_t.text = "NÍVEL MÁXIMO"
	else:
		_xp.max_value = GameData.xp_need(p.level)
		_xp.value = p.xp
		_xp_t.text = "XP %d / %d" % [p.xp, GameData.xp_need(p.level)] 
	_gold.text = "Ouro  %d    Gemas  %d" % [p.gold, p.gems]
	var b := []
	if p.dmg_buff > 0.0:
		b.append("Fúria +%d%%" % int(p.dmg_buff * 100))
	if p.speed_buff > 0.0:
		b.append("Veloz")
	if p.shield > 0.0:
		b.append("Escudo")
	_buffs.text = "  ".join(b)
	_btn_skills.text = "Skills (K)" + ("  +%d" % p.skill_points if p.skill_points > 0 else "")
	_gear_btn.text = "+%d" % p.skill_points if p.skill_points > 0 else ""   # aviso de pontos de skill no botão
	for i in _slots.size():
		var s: Dictionary = _slots[i]
		var lvl: int = p.skill_levels[i]
		var sk: Dictionary = GameData.SKILLS[p.class_key][i]
		var cd_rect: ColorRect = s["cd"]
		var cd_t: Label = s["cd_t"]
		var icon: TextureRect = s["icon"]
		var lv_l: Label = s["lv"]
		if lvl < 1:
			icon.modulate = Color(0.3, 0.3, 0.3)
			cd_rect.size.y = 70
			var need: int = GameData.SKILL_UNLOCK[i]
			cd_t.text = "Nv %d" % need if p.level < need else ("Missão" if i >= p.story_skills else "K")
			cd_t.add_theme_font_size_override("font_size", 16)
			lv_l.text = ""
			continue
		lv_l.text = "%d" % lvl
		if String(sk["type"]) == "passive":
			icon.modulate = Color(1, 1, 1)
			cd_rect.size.y = 0.0
			cd_t.add_theme_font_size_override("font_size", 14)
			cd_t.text = "PASSIVA"
			continue
		var total := maxf(0.01, Skills.cooldown(sk, lvl))
		var rem := p.skill_cd[i]
		var no_mp := p.mp < p.skill_cost(i)
		icon.modulate = Color(0.55, 0.6, 1.0) if no_mp else Color(1, 1, 1)
		cd_rect.size.y = 70.0 * clampf(rem / total, 0.0, 1.0)
		cd_t.add_theme_font_size_override("font_size", 24)
		cd_t.text = ("%.0f" % ceil(rem)) if rem > 0.05 else ""
