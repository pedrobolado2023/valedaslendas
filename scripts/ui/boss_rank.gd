class_name BossRank
extends CanvasLayer
## Ranking de dano do boss global (lado esquerdo da tela, no covil): top 6, com o top 3 em ouro/prata/bronze.
## Online os dados vêm do servidor (Net.boss_rank); sozinho mostra só o seu dano.

const MEDAL := [Color(1.0, 0.82, 0.25), Color(0.82, 0.85, 0.9), Color(0.85, 0.55, 0.3)]

var _list: VBoxContainer
var _foot: Label


func _ready() -> void:
	layer = 9
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UiTheme.get_theme()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var panel := PanelContainer.new()
	panel.position = Vector2(18, 200)
	panel.custom_minimum_size = Vector2(300, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", Toon.ui_box(Color(0.1, 0.03, 0.02, 0.85), Color(1.0, 0.45, 0.15), 12, 8, 2))
	root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	panel.add_child(v)
	v.add_child(UiTheme.title("Ranking de dano", 18))
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 2)
	v.add_child(_list)
	_foot = UiTheme.label("Top 3 e último golpe ganham prêmios extras", 12, Color(0.85, 0.75, 0.6))
	_foot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_foot)


func show_top(top: Array) -> void:
	if _list == null:
		return
	var me := ""
	var g := get_parent()
	if g != null and g.get("player") != null and String(g.get("player").hero_name) != "":
		me = String(g.get("player").hero_name)
	elif g != null and g.get("cloud") != null:
		me = String(g.get("cloud").email).get_slice("@", 0)
	for c in _list.get_children():
		c.queue_free()
	var total := 0
	for e in top:
		total += int(e[1])
	for i in top.size():
		var nm := String(top[i][0])
		var dmg := int(top[i][1])
		var col: Color = MEDAL[i] if i < 3 else Color(0.85, 0.82, 0.75)
		var mine := nm == me or nm == "Você"
		var l := UiTheme.label("%d. %s%s   %s  (%d%%)" % [i + 1, nm, "  (você)" if mine and nm != "Você" else "", _short(dmg), int(100.0 * dmg / maxf(total, 1))], 16 if i < 3 else 14, col)
		if mine:
			l.add_theme_color_override("font_outline_color", Color(1.0, 1.0, 1.0, 0.6))
			l.add_theme_constant_override("outline_size", 3)
		_list.add_child(l)


func finish(rank: int, last_hit: bool) -> void:
	if _foot != null:
		_foot.text = "Você ficou em %dº lugar%s" % [rank, "  ·  ÚLTIMO GOLPE!" if last_hit else ""]
	get_tree().create_timer(20.0).timeout.connect(func() -> void:
		if is_instance_valid(self):
			queue_free())


static func _short(n: int) -> String:
	if n >= 1000000:
		return "%.1fM" % (n / 1000000.0)
	if n >= 1000:
		return "%.1fk" % (n / 1000.0)
	return str(n)
