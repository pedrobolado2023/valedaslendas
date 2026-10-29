class_name Minimap
extends Control
## Minimapa redondo (gira junto com a câmera). Mostra trilhas, regiões, lago, NPC, objetivo, rota e inimigos.
## No modo grande (tecla M) mostra o mapa inteiro com os nomes das regiões.

var game: Node
var big := false
var _t := 0.0
var _content: Control
var _frame: Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	_content = Control.new()
	_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.draw.connect(_draw_content)
	add_child(_content)
	_frame = Control.new()
	_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.draw.connect(_draw_frame)
	add_child(_frame)


func _process(delta: float) -> void:
	_t += delta
	_content.queue_redraw()
	_frame.queue_redraw()


func _draw() -> void:
	# máscara redonda (os filhos só aparecem dentro deste círculo)
	var r := minf(size.x, size.y) * 0.5
	draw_circle(size * 0.5, r, Color(0.05, 0.06, 0.07, 0.94))


func _map(p: Vector3, center: Vector3, scale: float, origin: Vector2) -> Vector2:
	var right: Vector3 = game.get("cam_right")
	var fwd: Vector3 = game.get("cam_fwd")
	var d := p - center
	return origin + Vector2(d.x * right.x + d.z * right.z, -(d.x * fwd.x + d.z * fwd.z)) * scale


func _draw_content() -> void:
	if game == null:
		return
	var player: Player = game.get("player")
	if player == null:
		return
	var c := _content
	var origin := size * 0.5
	var radius := minf(size.x, size.y) * 0.5
	var view := 125.0 if big else 70.0
	var scale := radius / view
	var center := Vector3.ZERO if big else player.global_position
	var world: World = game.get("world")
	if world == null:
		return
	c.draw_rect(Rect2(Vector2.ZERO, size), world.ground_color())
	for reg in world.minimap_regions():
		c.draw_circle(_map(reg["c"], center, scale, origin), float(reg["r"]) * scale, reg["color"])
	for road in world.dense_roads:
		var pts := PackedVector2Array()
		for i in range(0, road.size(), 2):
			pts.append(_map(Vector3(road[i].x, 0, road[i].y), center, scale, origin))
		pts.append(_map(Vector3(road[road.size() - 1].x, 0, road[road.size() - 1].y), center, scale, origin))
		c.draw_polyline(pts, Color(0.8, 0.64, 0.42), 4.0 if big else 3.0, true)
	var route: PackedVector3Array = game.call("display_route")
	if route.size() > 1:
		var rp := PackedVector2Array()
		for p in route:
			rp.append(_map(p, center, scale, origin))
		c.draw_polyline(rp, Color(1.0, 0.86, 0.3), 3.0, true)
	for e in Skills.enemies(get_tree()):
		c.draw_circle(_map(e.global_position, center, scale, origin), 5.0 if e.boss else 2.5, Color(1.0, 0.22, 0.18) if e.boss else Color(0.95, 0.38, 0.32))
	var npc: Npc = game.get("npc")
	if npc != null:
		var np := _map(npc.global_position, center, scale, origin)
		c.draw_circle(np, 6.0, Color(1.0, 0.8, 0.2))
	c.draw_circle(_map(world.portal_pos, center, scale, origin), 6.0, Color(0.45, 0.85, 1.0))
	c.draw_rect(Rect2(_map(world.board_pos, center, scale, origin) - Vector2(4, 4), Vector2(8, 8)), Color(1.0, 0.85, 0.45))
	var goal: Dictionary = game.call("quest_goal")
	if not goal.is_empty():
		var gp := _map(goal["pos"], center, scale, origin)
		if gp.distance_to(origin) > radius - 12.0:
			gp = origin + (gp - origin).normalized() * (radius - 12.0)
		var pulse := 7.0 + sin(_t * 5.0) * 2.0
		c.draw_circle(gp, pulse + 4.0, Color(1.0, 0.85, 0.3, 0.3))
		_star(c, gp, pulse, Color(1.0, 0.85, 0.3))
	var pp := _map(player.global_position, center, scale, origin)
	var f := _map(player.global_position + player.facing, center, scale, origin) - pp
	f = f.normalized() if f.length() > 0.001 else Vector2.UP
	var side := Vector2(-f.y, f.x)
	c.draw_colored_polygon(PackedVector2Array([pp + f * 9.0, pp - f * 6.0 + side * 6.0, pp - f * 2.5, pp - f * 6.0 - side * 6.0]), Color(1, 1, 1))
	if big:
		var font := Toon.title_font()
		for zid in world.zone_ids():
			var z: Dictionary = GameData.ZONES[zid]
			var zp := _map(z["center"], center, scale, origin)
			c.draw_string_outline(font, zp + Vector2(-80, -12), String(z["name"]), HORIZONTAL_ALIGNMENT_CENTER, 160, 16, 4, Color(0, 0, 0))
			c.draw_string(font, zp + Vector2(-80, -12), String(z["name"]), HORIZONTAL_ALIGNMENT_CENTER, 160, 16, Color(1, 0.93, 0.78))
		var vp := _map(Vector3.ZERO, center, scale, origin)
		var hub := String(world.map["hub"])
		c.draw_string_outline(font, vp + Vector2(-90, -26), hub, HORIZONTAL_ALIGNMENT_CENTER, 180, 16, 4, Color(0, 0, 0))
		c.draw_string(font, vp + Vector2(-90, -26), hub, HORIZONTAL_ALIGNMENT_CENTER, 180, 16, Color(1, 0.93, 0.78))


func _draw_frame() -> void:
	var origin := size * 0.5
	var radius := minf(size.x, size.y) * 0.5
	_frame.draw_arc(origin, radius - 2.0, 0, TAU, 96, UiTheme.EDGE, 4.0, true)
	_frame.draw_arc(origin, radius - 6.0, 0, TAU, 96, Color(0.15, 0.08, 0.05), 2.0, true)


func _star(c: Control, at: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2.0 + TAU * i / 10.0
		pts.append(at + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else r * 0.45))
	c.draw_colored_polygon(pts, col)
