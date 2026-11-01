extends SceneTree
## Testa fúria/despertar, combo em chamas, tropas e as skills com visual novo dentro do jogo de verdade.
## VALE_TESTE=1 godot --headless --path . -s tools/test_combo_fury.gd

var _fails := 0


func check(ok: bool, what: String) -> void:
	print(("[OK] " if ok else "[FALHOU] ") + what)
	if not ok:
		_fails += 1


func game_cls(k: String) -> String:
	return load("res://scripts/game.gd")._cls(k)


func _initialize() -> void:
	check(OS.get_environment("VALE_TESTE") == "1", "rodando com VALE_TESTE=1 (não mexe no save do dono)")
	check(GameData.CLASS_ORDER == ["guerreiro", "lanceiro", "mago", "arqueira"], "só os 4 heróis jogáveis")
	check(game_cls("druida") == "mago" and game_cls("assassino") == "arqueira" and game_cls("mecanico") == "guerreiro" and game_cls("nautico") == "lanceiro", "saves antigos viram as classes novas")
	var owner := {}
	for cls in GameData.CLASS_ORDER:
		for sk in GameData.SKILLS[cls]:
			var t := String(sk["type"])
			if t != "projectile":
				check(not owner.has(t) or owner[t] == cls, "%s: tipo %s só nesta classe" % [sk["id"], t])
				owner[t] = cls
	check(GameData.BASE_MAPS["vale"]["name"] == "Vale das Lendas", "nome do mapa 1 original")
	for cls in ["mago", "guerreiro", "arqueira"]:
		for sk in GameData.SKILLS[cls]:
			check(not ("Legend" in String(sk["desc"]) or "Delphic" in String(sk["desc"])), "%s sem nome de outro jogo" % sk["id"])

	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game("guerreiro", {})
	for i in 20:
		await process_frame
	var p = game.player
	p.level = 60
	p.invuln_t = 999.0
	p.story_skills = 10
	for i in p.skill_count():
		p.skill_levels[i] = 5
	check(p.soldiers.size() == 2, "duas tropas ao lado do herói")

	# combo: a skill acesa aparece com chamas no HUD e dá +25% em todos os golpes dela
	p.combo_skill_idx = 1
	p.combo_timer = 4.0
	game.hud.refresh()
	check(game.hud._slots[1]["flame"].visible, "slot do combo pegando fogo no HUD")
	check(not game.hud._slots[0]["flame"].visible, "outro slot sem chamas")
	var fury0: float = p.fury
	p.mp = 9999
	p.skill_cd[1] = 0.0
	check(p.cast_skill(1, p.global_position + Vector3(0, 0, -5)), "skill do combo usada")
	check(p.combo_active_boost == 1.25 and p.combo_boost_t > 0.0, "bônus do combo ativo depois de usar")
	check(p.fury > fury0, "combo encheu a fúria")
	await create_timer(2.3).timeout
	check(p.combo_boost_t <= 0.0, "janela do bônus fecha sozinha")

	# despertar: só com a fúria cheia
	p.fury = 50.0
	check(not p.activate_awakening(), "não desperta com fúria pela metade")
	p.fury = p.max_fury
	check(p.activate_awakening(), "desperta com a fúria cheia")
	check(p.awakened and p.awakened_t > 15.0, "despertar dura 16 s")

	# todas as skills das 4 classes, numa zona com monstros (troca só a classe das skills; o modelo continua o do Guerreiro)
	var z = game.zones.values()[0]
	for cls in GameData.CLASS_ORDER:
		p.class_key = cls
		for i in p.skill_count():
			p.global_position = z.center() + Vector3(0, 0, 4)
			for e in z.alive_enemies():
				e.global_position = z.center() + Vector3(randf_range(-3, 3), 0.2, randf_range(-3, 3))
			p.mp = 9999
			p.skill_cd[i] = 0.0
			p.invuln_t = 999.0
			var id := String(p.skill(i)["id"])
			check(p.cast_skill(i, z.center()), "%s %s usada" % [id, p.skill(i)["name"]])
			await create_timer(0.6).timeout
		await create_timer(2.0).timeout
	await create_timer(3.0).timeout
	check(p.alive, "herói vivo depois das skills")

	print("--- %s ---" % ("TUDO CERTO" if _fails == 0 else "%d FALHAS" % _fails))
	quit(1 if _fails > 0 else 0)
