class_name NetMonsters
extends Node
## Cliente online: cria e atualiza os monstros que o servidor simula (ServerWorld), como nós Enemy comuns
## com net_id (as skills e o ataque básico acertam neles do mesmo jeito). Mortes, ataques e dano no herói
## chegam pelo Net. Offline este nó não faz nada (as Zones criam os monstros locais).

var game: Node
var _by_id: Dictionary = {}     # net_id -> Enemy


func _ready() -> void:
	var net := get_node("/root/Net")
	net.enemies.connect(_on_snap)
	net.enemy_attack.connect(func(id: int, slam: bool, center: Vector3, r: float, wind: float) -> void:
		var e: Enemy = _find(id)
		if e != null:
			e.net_attack(slam, center, r, wind))
	net.enemy_dead.connect(func(id: int, credit: bool, drop: String) -> void:
		var e: Enemy = _find(id)
		_by_id.erase(id)
		if e != null:
			e.net_die(credit, drop))
	net.hurt.connect(func(dmg: int, id: int) -> void:
		var p: Player = game.player
		if p == null:
			return
		var e: Enemy = _find(id)
		p.take_damage(dmg, e.global_position if e != null else p.global_position, e))


func _find(id: int) -> Enemy:
	var e: Variant = _by_id.get(id, null)
	return e as Enemy if e != null and is_instance_valid(e) else null


func _on_snap(map: String, snap: Dictionary) -> void:
	if game.player == null or map != String(game.map_id):
		return
	for id in _by_id.keys():   # saiu da lista sem morrer (mapa trocado, servidor esqueceu): some
		if not snap.has(id):
			var old: Enemy = _find(id)
			if old != null and old.alive:
				old.queue_free()
			_by_id.erase(id)
	for id in snap:
		var a: Array = snap[id]
		var e: Enemy = _find(int(id))
		if e == null:
			e = Enemy.new()
			e.setup(String(a[0]), a[2], String(a[1]))
			e.net_id = int(id)
			e.net_pos = a[2]
			e.died.connect(game._on_killed)
			game.actors.add_child(e)
			_by_id[int(id)] = e
		e.net_pos = a[2]
		e.net_moving = bool(a[5])
		e.net_face = float(a[6])
		e.max_hp = int(a[4])
		e.net_set_hp(int(a[3]))
