class_name BossMech
extends Node
## Mecânicas do chefe de bioma (dados "mech" do inimigo). Filho do Enemy; a cada `every` s, se o herói estiver perto,
## faz uma: "meteoros" (círculos caindo em volta do herói), "anel" (onda de fogo que sai do chefe — pule para fora),
## "gelo" (estacas de gelo em linha até o herói), "veneno" (poças que ficam no chão) e "invocar" (ajudantes).
## Sempre com aviso no chão antes do dano. O dano é no herói deste jogo (também online).

var boss: Enemy
var mechs: Array = []
var every := 6.0
var _t := 3.0
var _k := 0


func _process(delta: float) -> void:
	if boss == null or not is_instance_valid(boss) or not boss.alive:
		queue_free()
		return
	var p := get_tree().get_first_node_in_group("player") as Player
	if p == null or not p.alive:
		return
	if Skills.flat(p.global_position - boss.global_position).length() > 22.0:
		return
	_t -= delta
	if _t > 0.0:
		return
	_t = every * (0.7 if float(boss.hp) / float(boss.max_hp) < 0.4 else 1.0)   # mais rápido com pouca vida
	var m := String(mechs[_k % mechs.size()])
	_k += 1
	call("_" + m, p)


func _hit(p: Player, center: Vector3, r: float, mult: float, delay: float) -> void:
	var dmg := int(boss.dmg * mult)
	Fx.later(self, delay).connect(func() -> void:
		if is_instance_valid(p) and p.alive and Skills.flat(p.global_position - center).length() <= r:
			p.take_damage(dmg, center, boss))


func _meteoros(p: Player) -> void:
	var host := boss.get_parent()
	for i in 5:
		var at := p.global_position + Vector3(randf_range(-6, 6), 0, randf_range(-6, 6)) if i > 0 else p.global_position
		Fx.telegraph(host, at, 2.6, Color(1.0, 0.35, 0.1), 1.4)
		Vfx.meteor(host, at, 1.4, 2.6)
		_hit(p, at, 2.6, 0.9, 1.4)


func _anel(p: Player) -> void:
	var host := boss.get_parent()
	var c := boss.global_position
	Fx.telegraph(host, c, 9.0, Color(1.0, 0.5, 0.15), 1.2)
	Fx.later(self, 1.2).connect(func() -> void:
		Fx.ring(host, c + Vector3(0, 0.2, 0), Color(1.0, 0.55, 0.2), 9.0, 0.6, 0.12)
		Sfx.play("sk_slam", -4.0, 0.7))
	_hit(p, c, 9.0, 1.1, 1.2)


func _gelo(p: Player) -> void:
	var host := boss.get_parent()
	var a := boss.global_position
	var b := p.global_position
	for i in 6:
		var at := a.lerp(b, (i + 1) / 6.0) + Vector3(randf_range(-0.8, 0.8), 0, randf_range(-0.8, 0.8))
		Fx.telegraph(host, at, 1.8, Color(0.5, 0.8, 1.0), 0.9 + i * 0.12)
		Vfx.ice_fall(host, at, 0.9 + i * 0.12, 0.9)
		_hit(p, at, 1.8, 0.6, 0.9 + i * 0.12)


func _veneno(p: Player) -> void:
	var host := boss.get_parent()
	for i in 3:
		var at := p.global_position + Vector3(randf_range(-4, 4), 0, randf_range(-4, 4)) if i > 0 else p.global_position
		var mark := Fx.telegraph(host, at, 2.4, Color(0.4, 1.0, 0.3), 1.0)
		for k in 5:   # a poça fica 4 s machucando quem pisar
			_hit(p, at, 2.4, 0.25, 1.0 + k * 0.8)
		Fx.later(self, 1.0).connect(func() -> void:
			Fx.burst(host, at + Vector3(0, 0.2, 0), Color(0.4, 1.0, 0.3), 24, 2.0, 0.15, 3.5, -0.5))


func _invocar(_p: Player) -> void:
	if boss.net_id > 0:   # online os monstros são do servidor
		_meteoros(_p)
		return
	var host := boss.get_parent()
	var minion := String(boss.data.get("minion", ""))
	if minion == "" or host == null:
		return
	for i in 3:
		var e := Enemy.new()
		e.setup(minion, boss.global_position + Vector3(randf_range(-4, 4), 0.2, randf_range(-4, 4)), boss.zone_id)
		host.add_child(e)
		var g := host.get_parent()
		if g != null and g.has_method("_on_killed"):
			e.died.connect(g._on_killed)
	Fx.damage_number(host, boss.global_position + Vector3(0, 4.0, 0), "Ajudantes!", Color(1.0, 0.7, 0.3), true)
