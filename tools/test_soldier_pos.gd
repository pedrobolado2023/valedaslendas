extends SceneTree

func _initialize() -> void:
	print("[TESTE SOLDADO] Testando Soldier ao lado do player...")
	var sc := Node3D.new()
	root.add_child(sc)
	
	var p := preload("res://scripts/player.gd").new()
	p.class_key = "lanceiro"
	sc.add_child(p)
	
	var s1 := preload("res://scripts/soldier.gd").new()
	sc.add_child(s1)
	s1.setup(p, -1.4, "lanceiro", 1)
	
	var s2 := preload("res://scripts/soldier.gd").new()
	sc.add_child(s2)
	s2.setup(p, 1.4, "lanceiro", 1)
	
	for i in 60:
		p.velocity = Vector3(0, 0, 5)
		await process_frame
		
	print("[TESTE SOLDADO] Sucesso! Posição S1: ", s1.global_position, " S2: ", s2.global_position)
	quit()

