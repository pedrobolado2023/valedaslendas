class_name BossCall
extends CanvasLayer
## Janela do boss global no meio da tela: contagem até o dragão despertar e botão "Ir para o Boss agora"
## (viaja direto para o Covil, sem procurar no portal). Fecha sozinha quando o evento acaba ou ao viajar.

var events: WorldEvents
var _title: Label
var _text: Label
var _go: Button
var _t := 0.0


func _ready() -> void:
	layer = 18
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UiTheme.get_theme()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.offset_left = -300
	panel.offset_right = 300
	panel.offset_top = 150
	panel.add_theme_stylebox_override("panel", Toon.ui_box(Color(0.12, 0.03, 0.02, 0.96), Color(1.0, 0.45, 0.15), 18, 10, 3))
	root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	_title = UiTheme.title("", 26)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_title)
	_text = UiTheme.label("", 16)
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_text)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 12)
	v.add_child(h)
	_go = Button.new()
	_go.text = "Ir para o Boss agora"
	_go.focus_mode = Control.FOCUS_NONE
	_go.pressed.connect(_travel)
	h.add_child(_go)
	var later := Button.new()
	later.text = "Agora não"
	later.focus_mode = Control.FOCUS_NONE
	later.pressed.connect(queue_free)
	h.add_child(later)
	_refresh()


func _travel() -> void:
	var g: Node = events.game
	if String(g.get("map_id")) != String(GameData.GLOBAL_BOSS["map"]):
		g.call("travel", String(GameData.GLOBAL_BOSS["map"]), true)
	queue_free()


func _process(delta: float) -> void:
	_t -= delta
	if _t <= 0.0:
		_t = 0.5
		_refresh()


func _refresh() -> void:
	if events == null or events.game == null:
		return
	if String(events.game.get("map_id")) == String(GameData.GLOBAL_BOSS["map"]):
		queue_free()
		return
	if events.active():
		_title.text = "O Dragão de Lava despertou!"
		_text.text = "Boss global no Covil do Dragão  ·  termina em %d min. Todos os jogadores batem no mesmo dragão." % events.minutes_left()
	else:
		var s := events.seconds_to_next()
		if s > int(GameData.GLOBAL_BOSS["warn_minutes"]) * 60 + 5:
			queue_free()   # evento acabou (ou foi cancelado)
			return
		_title.text = "Boss global em %d:%02d" % [s / 60, s % 60]
		_text.text = "O Dragão de Lava vai despertar no Covil do Dragão. Você pode ir agora e esperar lá."
