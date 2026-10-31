class_name RemotePlayers
extends Node3D
## Desenha os outros jogadores do mesmo mapa (dados de get_node("/root/Net").others): herói montado por peças, nome em cima,
## andar/parado e montaria. Posição suavizada entre os pacotes do servidor.

var game: Node
var _nodes: Dictionary = {}     # id -> {root, kit, key, target, rot}
var _send_t := 0.0


func _process(delta: float) -> void:
	if not get_node("/root/Net").online or game.player == null:
		return
	_send_t += delta
	if _send_t >= 1.0 / 10.0:
		_send_t = 0.0
		get_node("/root/Net").send_state(String(game.map_id), game.player)
	for id in _nodes.keys():
		if not get_node("/root/Net").others.has(id):
			(_nodes[id]["root"] as Node).queue_free()
			_nodes.erase(id)
	for id in get_node("/root/Net").others:
		var o: Dictionary = get_node("/root/Net").others[id]
		var key := "%s|%s|%s" % [o["cls"], str(o["gear"]), o["mount"]]
		if not _nodes.has(id) or String(_nodes[id]["key"]) != key:
			if _nodes.has(id):
				(_nodes[id]["root"] as Node).queue_free()
			_nodes[id] = _make(o, key)
		var n: Dictionary = _nodes[id]
		var root: Node3D = n["root"]
		root.global_position = root.global_position.lerp(o["pos"], minf(1.0, delta * 10.0))
		root.rotation.y = lerp_angle(root.rotation.y, float(o["rot"]), minf(1.0, delta * 10.0))
		var kit: ModelKit = n["kit"]
		if kit != null:
			kit.play("run" if bool(o["moving"]) and kit.has_anim("run") else ("walk" if bool(o["moving"]) else "idle"))


func _make(o: Dictionary, key: String) -> Dictionary:
	var root := Node3D.new()
	add_child(root)
	root.global_position = o["pos"]
	var kit := ModelKit.load_class(String(o["cls"]), o["gear"]) if String(o["cls"]) != "" else null
	if kit != null:
		root.add_child(kit.root)
		Player.attach_weapon(kit, String(o["cls"]), String((o["gear"] as Dictionary).get("offhand", "comum")))
	var l := Label3D.new()
	var kg := String(o.get("kingdom", ""))
	var tag := ("<%s>" % String(o["guild"])) if String(o.get("guild", "")) != "" else ""
	if GameData.KINGDOMS.has(kg):
		tag = (tag + "  " if tag != "" else "") + "[%s]" % String(GameData.KINGDOMS[kg]["name"])
	l.text = (tag + "\n" if tag != "" else "") + String(o["name"])
	l.font = Toon.title_font()
	l.font_size = 30
	l.pixel_size = 0.012
	l.modulate = Color(0.6, 0.9, 1.0)
	l.outline_size = 8
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position.y = 2.7
	root.add_child(l)
	return {"root": root, "kit": kit, "key": key}
