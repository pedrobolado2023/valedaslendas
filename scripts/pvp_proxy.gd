class_name PvpProxy
extends Enemy
## Adversário do duelo: alvo invisível que segue o herói do outro jogador (as skills e o ataque básico acertam
## nele como num monstro). O dano vai para o servidor (Net.pvp_hit) e cai no outro jogador; aqui ele nunca morre.

var peer := 0


func _ready() -> void:
	super()
	add_to_group("pvp")
	if _vis != null:
		_vis.visible = false
	if _label != null:
		_label.visible = false
	max_hp = 999999999
	hp = max_hp


func _physics_process(_delta: float) -> void:
	var o: Dictionary = get_node("/root/Net").others.get(peer, {})
	if o.is_empty():
		return
	global_position = global_position.lerp(o["pos"], 0.5)


func take_damage(n: int, from: Vector3, crit: bool = false, tint: Color = Color(0, 0, 0, 0)) -> void:
	get_node("/root/Net").pvp_hit.rpc_id(1, n)
	Fx.damage_number(get_parent(), global_position + Vector3(0, 2.4, 0), str(maxi(1, int(n * 0.25))), Color(1.0, 0.4, 0.4) if not crit else Color(1.0, 0.85, 0.3), crit)


func apply_slow(_amount: float, _t: float) -> void:
	pass


func apply_stun(_t: float) -> void:
	pass


func knockback(_from: Vector3, _dist: float) -> void:
	pass


func pull_to(_target: Vector3, _time: float) -> void:
	pass
