class_name Npc
extends Node3D
## NPC que dá as missões. Mostra "!" quando tem missão nova e "?" quando a missão está pronta para entregar.

var npc_name := "Ancião Bóris"
var model_name := "npc_elder"
var _marker: Label3D
var _prompt: Label3D
var _model: Node3D
var _kit: ModelKit
var _t := 0.0


func _ready() -> void:
	_model = Node3D.new()
	add_child(_model)
	_kit = ModelKit.load_kit(model_name, 0.035)
	if _kit != null:
		_model.add_child(_kit.root)
		_kit.play("idle")
	var shadow := Toon.glow_part(Toon.cyl(0.65, 0.65, 0.01, 20), Color(0, 0, 0), Vector3(0, 0.03, 0), 0.4)
	(shadow.material_override as StandardMaterial3D).blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	add_child(shadow)
	var glow := Toon.glow_part(Toon.cyl(1.2, 1.2, 0.02, 32), Color(1.0, 0.8, 0.35), Vector3(0, 0.04, 0), 0.18, true)
	add_child(glow)
	var name_l := Label3D.new()
	name_l.text = npc_name
	name_l.font = Toon.title_font()
	name_l.font_size = 34
	name_l.pixel_size = 0.015
	name_l.modulate = Color(1.0, 0.85, 0.5)
	name_l.outline_size = 10
	name_l.outline_modulate = Color(0.05, 0.02, 0.02)
	name_l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_l.position.y = 3.3
	add_child(name_l)
	_marker = Label3D.new()
	_marker.font = Toon.title_font()
	_marker.font_size = 130
	_marker.pixel_size = 0.016
	_marker.modulate = Color(1.0, 0.8, 0.2)
	_marker.outline_size = 22
	_marker.outline_modulate = Color(0.15, 0.05, 0.0)
	_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_marker.position.y = 4.6
	add_child(_marker)
	_prompt = Label3D.new()
	_prompt.text = "E / clique — Falar"
	_prompt.font_size = 30
	_prompt.pixel_size = 0.014
	_prompt.outline_size = 8
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.position.y = 2.6
	_prompt.visible = false
	add_child(_prompt)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.8, 0.5)
	l.light_energy = 1.4
	l.omni_range = 6.0
	l.position = Vector3(0, 3.0, 1.0)
	add_child(l)


func set_marker(kind: String) -> void:
	_marker.text = kind
	_marker.visible = kind != ""
	_marker.modulate = Color(1.0, 0.8, 0.2) if kind == "!" else Color(0.5, 1.0, 0.6)


func _process(delta: float) -> void:
	_t += delta
	_marker.position.y = 4.6 + sin(_t * 3.0) * 0.18
	var p := get_tree().get_first_node_in_group("player") as Player
	if p == null:
		return
	var to := p.global_position - global_position
	to.y = 0.0
	var near := to.length() < 6.0
	_prompt.visible = to.length() < 3.8
	if near and to.length() > 0.3:
		_model.rotation.y = lerp_angle(_model.rotation.y, atan2(-to.x, -to.z), 4.0 * delta)
