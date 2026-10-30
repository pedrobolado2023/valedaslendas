class_name LoginPanel
extends CanvasLayer
## Tela de login (aparece por cima do menu quando o Supabase está ligado e não há sessão salva):
## e-mail + senha, Entrar / Criar conta, ou jogar sem conta (só no PC, sem nuvem).

var cloud: CloudSync
var _mail: LineEdit
var _pass: LineEdit
var _msg: Label
var _btns: Array[Button] = []


func _ready() -> void:
	layer = 30
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UiTheme.get_theme()
	add_child(root)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.75)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.offset_left = -240
	panel.offset_right = 240
	panel.offset_top = -210
	panel.offset_bottom = 210
	panel.add_theme_stylebox_override("panel", Toon.ui_box(Color(0.06, 0.035, 0.05, 0.97), UiTheme.GOLD, 20, 10, 3))
	root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	v.add_child(UiTheme.title("Entrar na conta", 30))
	_mail = LineEdit.new()
	_mail.placeholder_text = "E-mail"
	v.add_child(_mail)
	_pass = LineEdit.new()
	_pass.placeholder_text = "Senha (mínimo 6)"
	_pass.secret = true
	_pass.text_submitted.connect(func(_t: String) -> void: _go(false))
	v.add_child(_pass)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	v.add_child(h)
	for pair in [["Entrar", false], ["Criar conta", true]]:
		var b := Button.new()
		b.text = String(pair[0])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var criar: bool = pair[1]
		b.pressed.connect(func() -> void: _go(criar))
		h.add_child(b)
		_btns.append(b)
	_msg = UiTheme.label("O progresso fica salvo na sua conta e abre em qualquer computador ou navegador.", 14, Color(0.8, 0.75, 0.65))
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_msg)
	var forgot := Button.new()
	forgot.text = "Esqueci a senha"
	forgot.flat = true
	forgot.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	forgot.pressed.connect(func() -> void:
		var mail := _mail.text.strip_edges()
		if not "@" in mail:
			_msg.text = "Digite o seu e-mail acima e clique de novo em \"Esqueci a senha\"."
			return
		_msg.text = "Enviando..."
		var err: String = await cloud.recover(mail)
		_msg.text = err if err != "" else "Pronto! Veja o seu e-mail (e o spam): o link cria uma senha nova.")
	v.add_child(forgot)
	var off := Button.new()
	off.text = "Jogar sem conta (só neste computador)"
	off.pressed.connect(queue_free)
	v.add_child(off)
	_mail.grab_focus()


func _go(criar: bool) -> void:
	var mail := _mail.text.strip_edges()
	if not "@" in mail or _pass.text.length() < 6:
		_msg.text = "Digite um e-mail válido e uma senha com pelo menos 6 letras/números."
		return
	for b in _btns:
		b.disabled = true
	_msg.text = "Conectando..."
	var err := await cloud.login(mail, _pass.text, criar)
	for b in _btns:
		b.disabled = false
	if err == "":
		queue_free()
	else:
		_msg.text = err
