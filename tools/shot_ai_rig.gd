extends SceneTree
## Herói de IA com esqueleto: 4 cópias em idle / walk / run / attack, congeladas num quadro, + vista de lado.
func _initialize() -> void:
	root.size = Vector2i(1700, 900)
	var sc := Node3D.new()
	root.add_child(sc)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.16, 0.15, 0.2)
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.7)
	env.environment.ambient_light_energy = 0.8
	sc.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 35, 0)
	sun.light_energy = 1.3
	sc.add_child(sun)
	var anims := OS.get_environment("ANIMS").split(",")
	var t := float(OS.get_environment("T"))
	var kits: Array = []
	for i in anims.size():
		var kit := ModelKit.load_kit(OS.get_environment("MODEL"), float(OS.get_environment("OUT")))
		sc.add_child(kit.root)
		for m in kit.mats:
			m.set_shader_parameter("use_vertex_color", true)
			m.set_shader_parameter("rim_strength", float(OS.get_environment("RIM")))
		kit.root.position = Vector3((i - (anims.size() - 1) / 2.0) * 1.7, 0, 0)
		kit.root.rotation.y = PI + float(OS.get_environment("YAW"))
		kit.play(anims[i])
		kits.append(kit)
	var cam := Camera3D.new()
	sc.add_child(cam)
	cam.look_at_from_position(Vector3(0, 1.15, 6.6), Vector3(0, 1.0, 0))
	cam.fov = 42
	await process_frame
	for k in kits:
		for ap in k.root.find_children("*", "AnimationPlayer", true, false):
			var p := ap as AnimationPlayer
			p.seek(t * p.current_animation_length, true)
			p.pause()
	for f in 10:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOT"))
	quit()
