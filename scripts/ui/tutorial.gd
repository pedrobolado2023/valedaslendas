class_name Tutorial
extends CanvasLayer
## Tutorial inicial: dicas no alto da tela que avançam quando o jogador faz cada coisa (ou depois de um tempo).
## Aparece no primeiro personagem; dá para pular e rever em Configurações (Esc).

signal finished

var game: Node
var _box: PanelContainer
var _title: Label
var _text: Label
var _step := -1
var _t := 0.0
var _start_pos := Vector3.ZERO
var _steps: Array = []


func setup(g: Node) -> void:
	game = g
	layer = 12
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UiTheme.get_theme()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_box = PanelContainer.new()
	_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_box.offset_left = -300
	_box.offset_right = 300
	_box.offset_top = 120
	_box.add_theme_stylebox_override("panel", Toon.ui_box(Color(0.05, 0.03, 0.05, 0.92), UiTheme.GOLD, 14, 10, 2))
	root.add_child(_box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_box.add_child(v)
	_title = UiTheme.title("", 20)
	v.add_child(_title)
	_text = UiTheme.label("", 16)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_text)
	var skip := Button.new()
	skip.text = "Pular tutorial"
	skip.focus_mode = Control.FOCUS_NONE
	skip.size_flags_horizontal = Control.SIZE_SHRINK_END
	skip.pressed.connect(_finish)
	v.add_child(skip)
	var p: Player = game.get("player")
	_steps = [
		["Bem-vindo ao Vale das Lendas!", "Ande com W A S D (ou as setas). Experimente andar um pouco.",
			func() -> bool: return Skills.flat(p.global_position - _start_pos).length() > 4.0],
		["Atacar", "Clique com o mouse (ou aperte Espaço) para o ataque básico. Ele mira para onde o mouse aponta.",
			func() -> bool: return p.basic_cd > 0.0],
		["Skills", "Aperte 1 para usar sua primeira skill. As outras liberam com o nível (teclas 2 a 9 e 0).",
			func() -> bool: return p.skill_cd[0] > 0.0],
		["Pontos de skill", "Cada nível dá 1 ponto. Aperte K para ver suas skills e melhorar com o botão +.",
			func() -> bool: return (game.get("skill_panel") as CanvasLayer).visible],
		["Missões", "Fale com o personagem do (!) no acampamento: ande até ele e aperte E. Ele dá a missão da história.",
			func() -> bool: return String(game.get("quest_state")) != "none" or (game.get("dialog") as CanvasLayer).visible],
		["Menus", "I = equipamento e skins · L = loja (gemas) · J = missões diárias, semanais e mensais · M = mapa.",
			func() -> bool: return (game.get("gear_panel") as CanvasLayer).visible or (game.get("shop_panel") as CanvasLayer).visible or (game.get("board_panel") as CanvasLayer).visible or _t > 14.0],
		["Modo automático", "\"Ir automático\" (no painel da missão) faz a história sozinho; T liga o auto-combate. Esc abre as configurações.",
			func() -> bool: return _t > 9.0],
		["Boa aventura!", "O Portal de Viagem leva aos outros mapas. Às 10h, 16h e 22h aparece o boss global (Dragão Ancestral).",
			func() -> bool: return _t > 6.0],
	]
	visible = false


func begin() -> void:
	visible = true
	_go(0)


func _go(i: int) -> void:
	_step = i
	_t = 0.0
	if i >= _steps.size():
		_finish()
		return
	var p: Player = game.get("player")
	_start_pos = p.global_position
	_title.text = "%s   (%d/%d)" % [String(_steps[i][0]), i + 1, _steps.size()]
	_text.text = String(_steps[i][1])
	Sfx.play("quest", -10.0, 1.3)


func _process(delta: float) -> void:
	if not visible or _step < 0:
		return
	_t += delta
	var ok: Callable = _steps[_step][2]
	if _t > 0.6 and ok.call():
		_go(_step + 1)


func _finish() -> void:
	visible = false
	_step = -1
	finished.emit()
