class_name ChatBox
extends CanvasLayer
## Chat (Enter abre/envia, Esc fecha): "texto" = geral, "/m texto" = mapa, "/p Nome texto" = privado,
## "/g texto" = grupo. Mostra as últimas mensagens (somem depois de um tempo quando o chat está fechado).
## Enquanto digita, o herói não anda (Player.typing).

const KEEP := 40
const COLORS := {"geral": Color(0.95, 0.92, 0.85), "mapa": Color(0.6, 0.9, 1.0), "privado": Color(1.0, 0.6, 0.95),
	"grupo": Color(0.55, 1.0, 0.6), "sistema": Color(1.0, 0.8, 0.4)}

var game: Node
var _log: RichTextLabel
var _edit: LineEdit
var _panel: PanelContainer
var _fade := 0.0


func _ready() -> void:
	layer = 8
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UiTheme.get_theme()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel.offset_left = 96
	_panel.offset_right = 96 + 460
	_panel.offset_bottom = -16
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_theme_stylebox_override("panel", Toon.ui_box(Color(0.03, 0.02, 0.03, 0.55), Color(0.4, 0.3, 0.2, 0.6), 10, 6, 1))
	root.add_child(_panel)
	if DisplayServer.is_touchscreen_available():   # celular: chat no alto à esquerda (embaixo fica o joystick)
		_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_panel.grow_vertical = Control.GROW_DIRECTION_END
		_panel.offset_left = 16
		_panel.offset_right = 16 + 400
		_panel.offset_top = 180
		_panel.offset_bottom = 180 + 150
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(v)
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.fit_content = false
	_log.custom_minimum_size = Vector2(380, 100) if DisplayServer.is_touchscreen_available() else Vector2(440, 150)
	_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_log.add_theme_font_size_override("normal_font_size", 14)
	v.add_child(_log)
	_edit = LineEdit.new()
	_edit.placeholder_text = "Enter: falar · /m mapa · /p Nome privado · /g grupo"
	_edit.max_length = 140
	_edit.visible = false
	_edit.text_submitted.connect(_send)
	v.add_child(_edit)
	var net := get_node("/root/Net")
	net.chat_msg.connect(func(ch: String, from: String, text: String) -> void: add(ch, from, text))
	add("sistema", "", "Enter para conversar." + ("" if net.online else " (sem servidor: o chat só funciona online)"))


func typing() -> bool:
	return _edit.visible and _edit.has_focus()


func open() -> void:
	_edit.visible = true
	_edit.grab_focus()
	_fade = 0.0
	_panel.modulate.a = 1.0


func close() -> void:
	_edit.text = ""
	_edit.release_focus()
	_edit.visible = false
	_fade = 8.0


func add(ch: String, from: String, text: String) -> void:
	var col: Color = COLORS.get(ch, Color.WHITE)
	var tag: String = {"geral": "", "mapa": "[Mapa] ", "privado": "[Privado] ", "grupo": "[Grupo] ", "sistema": ""}.get(ch, "")
	var line := "[color=#%s]%s%s%s[/color]" % [col.to_html(false), tag, ("[b]%s:[/b] " % _esc(from)) if from != "" else "", _esc(text)]
	_log.append_text(line + "\n")
	if _log.get_paragraph_count() > KEEP:
		_log.remove_paragraph(0)
	_panel.modulate.a = 1.0
	_fade = 10.0


func _send(t: String) -> void:
	t = t.strip_edges()
	close()
	if t == "":
		return
	var net := get_node("/root/Net")
	if not net.online:
		add("sistema", "", "Sem conexão com o servidor.")
		return
	var ch := "geral"
	var to := ""
	if t.begins_with("/m "):
		ch = "mapa"
		t = t.substr(3)
	elif t.begins_with("/g "):
		ch = "grupo"
		t = t.substr(3)
	elif t.begins_with("/p "):
		var rest := t.substr(3).strip_edges()
		ch = "privado"
		to = rest.get_slice(" ", 0)
		t = rest.substr(to.length()).strip_edges()
		if t == "":
			add("sistema", "", "Uso: /p Nome mensagem")
			return
	net.chat.rpc_id(1, ch, t, to)


func _process(delta: float) -> void:
	Player.typing = typing()
	if _edit.visible:
		if Input.is_key_pressed(KEY_ESCAPE):
			close()
		return
	_fade -= delta
	_panel.modulate.a = clampf(_fade / 2.0, 0.25, 1.0)


static func _esc(s: String) -> String:
	return s.replace("[", "(").replace("]", ")")
