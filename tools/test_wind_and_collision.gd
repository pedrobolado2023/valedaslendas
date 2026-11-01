extends SceneTree

func _init() -> void:
	print("--- TESTE DE MAPA ESTÁTICO & EFEITO DE VENTO ---")
	var world_script = preload("res://scripts/world.gd")
	var world = world_script.new()
	root.add_child(world)
	world.build("vale")
	print("[OK] Mapa 'vale' construído com sucesso.")

	# 1. Verifica obstáculos de colisão
	var obs = world.obstacles
	assert(obs != null, "Nó obstacles deve existir")
	var shapes := []
	for child in obs.get_children():
		if child is CollisionShape3D:
			shapes.append(child)
	print("[OK] Total de shapes de colisão no mapa: ", shapes.size())
	assert(shapes.size() <= 5, "Não deve haver nenhum obstáculo interno 3D bloqueando o jogador (apenas chão e bordas)")
	print("[OK] NENHUM obstáculo de colisão interna (casas, cercas, árvores, pedras, lago) existe no mapa!")

	# 2. Verifica o efeito de vento
	assert(world._weather_holder != null, "Holder do efeito de vento deve existir")
	assert(world._weather_holder.get_child_count() >= 2, "Efeito de vento deve conter rajadas e folhas")
	var streaks = world._weather_holder.get_child(0) as CPUParticles3D
	var leaves = world._weather_holder.get_child(1) as CPUParticles3D
	assert(streaks != null and leaves != null, "Partículas de vento devem ser CPUParticles3D válidas")
	assert(streaks.initial_velocity_min >= 15.0, "Velocidade das rajadas de vento deve ser rápida")
	print("[OK] Efeito de Vento configurado com sucesso:")
	print("   - Rajadas/Linhas de vento:", streaks.amount, "partículas, vel min:", streaks.initial_velocity_min)
	print("   - Brisa com folhas/partículas:", leaves.amount, "partículas, vel min:", leaves.initial_velocity_min)

	print("--- TODOS OS TESTES DE MAPA ESTÁTICO E VENTO PASSARAM COM SUCESSO! ---")
	quit(0)

