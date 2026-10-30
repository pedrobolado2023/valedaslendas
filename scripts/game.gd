extends Node3D
## Jogo principal: câmera isométrica 2.5D, mapas e portal, herói, NPC de história, quadro de missões
## (diárias/semanais/mensais), equipamentos com raridade, modo automático e salvamento.

const CAM_PITCH := -42.0
const CAM_YAW := 45.0

var world: World
var actors: Node3D
var player: Player
var npc: Npc
var hud: Hud
var dialog: DialogBox
var skill_panel: SkillPanel
var board_panel: MissionBoardPanel
var gear_panel: EquipmentPanel
var admin_panel: AdminPanel
var autopilot: Autopilot
var trail: RouteTrail
var cam: Camera3D
var cam_right := Vector3(1, 0, 0)
var cam_fwd := Vector3(0, 0, -1)
var zones := {}
var map_id := "vale"
var missions := MissionBook.new()
var events: WorldEvents          # boss global (horários, covil, recompensas)
var shop_panel: ShopPanel
var pet_panel: PetPanel
var rewards_panel: RewardsPanel
var portal_panel: PortalPanel
var chat: ChatBox
var social_panel: SocialPanel
var ranking_panel: RankingPanel
var market_panel: MarketPanel
var forge_panel: ForgePanel
var dungeon: Dungeon
var _new_name := ""   # nome digitado no menu (jogo novo)
var cloud: CloudSync
var remote: RemotePlayers
var settings_panel: SettingsPanel
var tutorial: Tutorial
var tutorial_done := false
var return_map := "vale"         # mapa para onde o herói volta ao sair de um mapa de evento (o save não guarda o covil)

var quest_index := 0
var quest_state := "none"      # none | kill | boss | done
var quest_kills := 0
var show_path := false
var focus := "story"           # o que a trilha e o automático seguem: "story" ou "diaria" / "semanal" / "mensal"
var auto_repeat := false       # missão automática: aceita a próxima sozinha até o limite

var _menu: ClassMenu
var _zoom := 22.0
var _cam_target := Vector3.ZERO
var _route := PackedVector3Array()
var _route_t := 0.0
var _zone_now := ""
var _ui_t := 0.0
var _save_t := 20.0
var _resume_auto := false
var _traveling := false
var _fade: ColorRect


func _ready() -> void:
	randomize()
	if get_node("/root/Net").is_server:   # servidor sem tela: só a rede (scripts/net.gd)
		set_process(false)
		set_physics_process(false)
		set_process_input(false)
		set_process_unhandled_input(false)
		return
	add_child(Sfx.new())
	actors = Node3D.new()
	add_child(actors)
	trail = RouteTrail.new()
	add_child(trail)
	_build_camera()
	_build_vignette()
	_build_map("vale", false)
	_cam_target = Vector3(0, 0, 6)
	_make_menu()
	_web_test.call_deferred()
	cloud = CloudSync.new()
	add_child(cloud)
	# save mais novo na nuvem (outro PC): refaz o menu com o "Continuar" certo
	cloud.need_login.connect(func() -> void:
		if player == null:
			var lp := LoginPanel.new()
			lp.cloud = cloud
			add_child(lp))
	remote = RemotePlayers.new()
	remote.game = self
	add_child(remote)
	var nm := NetMonsters.new()
	nm.game = self
	add_child(nm)
	# logado: conecta no servidor do jogo (se houver) e usa o save guardado lá se for mais novo
	cloud.ready_done.connect(func(_p: bool) -> void:
		if await get_node("/root/Net").connect_to_server(cloud.token):
			toast("Conectado ao servidor online", 2.0))
	get_node("/root/Net").loaded.connect(func(sv: Dictionary) -> void:
		if not sv.is_empty() and String(sv.get("saved_at", "")) > String(SaveGame.account().get("saved_at", "")):
			SaveGame.write_account(sv)
			if player == null and _menu != null:
				_menu.queue_free()
				_make_menu())
	cloud.ready_done.connect(func(pulled: bool) -> void:
		if pulled and player == null and _menu != null:
			_menu.queue_free()
			_make_menu())


## Só na versão de teste (debug) do navegador: ?mapa=m5&nivel=120 começa direto naquele mapa (para testar mapas).
func _web_test() -> void:
	if not OS.has_feature("web") or not OS.is_debug_build():
		return
	var q := String(JavaScriptBridge.eval("location.search", true))
	if not q.contains("mapa="):
		return
	var args := {}
	for part in q.trim_prefix("?").split("&"):
		var kv := part.split("=")
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	start_game(String(args.get("classe", "druida")), {})
	tutorial.visible = false
	player.level = int(args.get("nivel", "120"))
	player.recalc()
	if args.has("semparte"):
		ModelKit.debug_drop = String(args["semparte"]).split(",")
	if args.has("trocar"):   # trocar=dragon_whelp: monstros com esse modelo usam o modelo do imp
		var alvo := String(args["trocar"])
		for z in GameData.ZONES.values():
			for key in ["enemy", "boss"]:
				var ed: Dictionary = GameData.enemy(String(z.get(key, "")))
				if String(ed.get("model", "")) == alvo or (alvo == "dragon_whelp" and String(ed.get("model", "")) == "dragon_ancient"):
					ed["model"] = "imp"
		print("[teste] trocado ", alvo)
	for k in ["montaria", "pet"]:
		if args.has(k):
			var it := Shop.item(String(args[k]))
			player.purchases.append({"id": it["id"], "price": 0})
			Shop._apply(player, it)
	travel(String(args["mapa"]), true)
	await get_tree().create_timer(0.3).timeout
	while _traveling:
		await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout
	if args.has("zona"):   # zona=N: vai para o centro da zona N do mapa
		var zz: Dictionary = GameData.ZONES[GameData.MAPS[map_id]["zones"][int(args["zona"])]]
		player.global_position = zz["center"] + Vector3(0, 0.3, 0)
		print("[teste] na zona ", zz["name"])
		await get_tree().create_timer(2.0).timeout
	if args.has("so"):   # coloca um monstro deste tipo do lado do herói; sem=Peça1,Peça2 esconde peças dele
		var e := Enemy.new()
		e.setup(String(args["so"]), player.global_position + Vector3(3, 0, 0))
		actors.add_child(e)
		await get_tree().process_frame
		if args.has("sem"):
			for nm in String(args["sem"]).split(","):
				for mi in e.find_children(nm + "*", "MeshInstance3D", true, false):
					(mi as MeshInstance3D).visible = false
		print("[teste] colocado ", args["so"])
	if args.has("lista"):
		var i := 0
		for c in world.get_children():
			print("[teste] filho ", i, " ", c.name, " <", c.get_class(), "> filhos=", c.get_child_count())
			i += 1
	if args.has("esconder"):   # esconder=a-b (índices dos filhos do mundo)
		var ab: PackedStringArray = String(args["esconder"]).split("-")
		var kids := world.get_children()
		for i in range(int(ab[0]), mini(int(ab[1]) + 1, kids.size())):
			if kids[i] is Node3D:
				(kids[i] as Node3D).visible = false
			elif kids[i] is Light3D:
				pass
		print("[teste] escondidos ", ab)
	if args.has("tipo"):   # esconde só os monstros deste tipo (ex.: tipo=whelp)
		for e in get_tree().get_nodes_in_group("enemy"):
			if String(args["tipo"]) in String((e as Enemy).data.get("model", "")):
				(e as Node3D).visible = false
		print("[teste] escondido tipo ", args["tipo"])
	if args.has("nan"):
		var bad := 0
		for n in get_tree().root.find_children("*", "Node3D", true, false):
			var t: Transform3D = (n as Node3D).global_transform
			var ok := t.origin.is_finite() and t.basis.x.is_finite() and t.basis.y.is_finite() and t.basis.z.is_finite()
			if not ok or t.basis.determinant() == 0.0:
				bad += 1
				if bad < 15:
					print("[teste] RUIM ", n.get_path(), " ", t)
			if n is MultiMeshInstance3D and (n as MultiMeshInstance3D).multimesh != null:
				var mm := (n as MultiMeshInstance3D).multimesh
				for i in mm.instance_count:
					var it := mm.get_instance_transform(i)
					if not it.origin.is_finite() or not it.basis.x.is_finite():
						bad += 1
						if bad < 15:
							print("[teste] RUIM multimesh ", n.get_path(), " inst ", i, " ", it)
						break
		print("[teste] objetos com transform ruim: ", bad)
	if args.has("atores"):   # atores=0 esconde todos; atores=longe esconde os monstros longe do herói (>40)
		for c in actors.get_children():
			if c is Node3D and c != player:
				if String(args["atores"]) == "0" or (c as Node3D).global_position.distance_to(player.global_position) > 40.0:
					(c as Node3D).visible = false
		print("[teste] atores escondidos ", args["atores"])
	if args.has("semsombra"):
		for l in get_tree().root.find_children("*", "Light3D", true, false):
			(l as Light3D).shadow_enabled = false
		print("[teste] sombras desligadas")
	if args.has("semomni"):
		for l in get_tree().root.find_children("*", "OmniLight3D", true, false):
			(l as Light3D).visible = false
		print("[teste] omni desligadas")
	if args.has("skills"):   # usa todas as skills sem parar e mede a cena
		for i in player.skill_levels.size():
			player.skill_levels[i] = 10
		player.god_mode = true
		for loop in 20:
			for i in player.skill_count():
				player.skill_cd[i] = 0.0
				player.mp = player.max_mp
				player.cast_skill(i, player.global_position + Vector3(4, 0, 2))
				await get_tree().create_timer(0.3).timeout
			var mis := 0
			for n in get_tree().root.find_children("*", "MeshInstance3D", true, false):
				if (n as MeshInstance3D).is_visible_in_tree():
					mis += 1
			print("[teste] SKILLS volta ", loop, " malhas ", mis, " luzes ", get_tree().root.find_children("*", "Light3D", true, false).size(), " particulas ", get_tree().root.find_children("*", "GPUParticles3D", true, false).size() + get_tree().root.find_children("*", "CPUParticles3D", true, false).size())
	if args.has("contar"):
		var mis := 0
		var surf := 0
		var mm := 0
		for n in get_tree().root.find_children("*", "MeshInstance3D", true, false):
			var mi := n as MeshInstance3D
			if mi.is_visible_in_tree() and mi.mesh != null:
				mis += 1
				surf += mi.mesh.get_surface_count()
		for n in get_tree().root.find_children("*", "MultiMeshInstance3D", true, false):
			var mmi := n as MultiMeshInstance3D
			if mmi.multimesh != null:
				mm += mmi.multimesh.instance_count
		print("[teste] CONTA malhas ", mis, " superficies ", surf, " multimesh inst ", mm, " luzes ", get_tree().root.find_children("*", "Light3D", true, false).size())
	if args.has("info"):
		var c3 := get_viewport().get_camera_3d()
		print("[teste] camera atual ", c3.get_path() if c3 else "NENHUMA", " size ", c3.size if c3 else 0, " near ", c3.near if c3 else 0, " far ", c3.far if c3 else 0, " cull ", c3.cull_mask if c3 else 0)
		for we in get_tree().root.find_children("*", "WorldEnvironment", true, false):
			var en: Environment = (we as WorldEnvironment).environment
			print("[teste] env ", we.get_path(), " bg ", en.background_mode, " fog ", en.fog_enabled, " dens ", en.fog_density, " tonemap ", en.tonemap_mode, " exp ", en.tonemap_exposure, " adj ", en.adjustment_enabled)
		for l in get_tree().root.find_children("*", "DirectionalLight3D", true, false):
			print("[teste] sol ", l.get_path(), " energia ", (l as Light3D).light_energy, " sombra ", (l as Light3D).shadow_enabled)
		print("[teste] luzes omni ", get_tree().root.find_children("*", "OmniLight3D", true, false).size(), " decals ", get_tree().root.find_children("*", "Decal", true, false).size(), " gpu part ", get_tree().root.find_children("*", "GPUParticles3D", true, false).size(), " cpu part ", get_tree().root.find_children("*", "CPUParticles3D", true, false).size())
	if args.has("semglow"):
		for we in find_children("*", "WorldEnvironment", true, false):
			(we as WorldEnvironment).environment.glow_enabled = false
			print("[teste] glow desligado")
	for i in 3:
		await get_tree().create_timer(1.0).timeout
		print("[teste] fade ", _fade.color, " viajando ", _traveling, " mapa ", map_id, " herói ", player.global_position, " câmera ", cam.global_position, " chão ", player.is_on_floor())


func _make_menu() -> void:
	_menu = ClassMenu.new()
	var ch: Array = SaveGame.account()["chars"]
	for i in ch.size():
		_menu.slots.append(_summary_of(ch[i]))
	add_child(_menu)
	_menu.chosen.connect(_new_hero)
	_menu.continue_slot.connect(func(i: int) -> void:
		SaveGame.select(i)
		var d := SaveGame.read()
		start_game(_cls(String(d.get("class", "assassino"))), d))
	_menu.delete_slot.connect(func(i: int) -> void:
		SaveGame.remove(i)
		if get_node("/root/Net").online:
			get_node("/root/Net").delete_char.rpc_id(1, i)
		_menu.queue_free()
		_make_menu())


## Duelo: pedido aparece no chat/aviso (aceitar no Social, G); começa → alvo PvpProxy no adversário.
var duel_from := ""
var _duel_proxy: PvpProxy


func _hook_duel() -> void:
	var net := get_node("/root/Net")
	if net.duel_asked.is_connected(_on_duel_asked):
		return
	net.duel_asked.connect(_on_duel_asked)
	net.duel_started.connect(func(peer: int, nm: String) -> void:
		duel_from = ""
		if _duel_proxy != null and is_instance_valid(_duel_proxy):
			_duel_proxy.queue_free()
		_duel_proxy = PvpProxy.new()
		_duel_proxy.peer = peer
		_duel_proxy.setup("slime", player.global_position, "")
		actors.add_child(_duel_proxy)
		hud.banner("Duelo contra %s!" % nm, "Quem cair primeiro perde", 3.0)
		Sfx.play("boss", -6.0, 1.3))
	net.duel_ended.connect(func(w: String) -> void:
		if _duel_proxy != null and is_instance_valid(_duel_proxy):
			_duel_proxy.queue_free()
		_duel_proxy = null
		var won := w == player.hero_name
		hud.banner("Você venceu o duelo!" if won else "Você perdeu o duelo", "Vencedor: " + w, 3.5)
		if won:
			player.stat_add("duels"))
	net.pvp_hurt.connect(func(dmg: int) -> void:
		if player != null and player.alive:
			player.take_damage(dmg, _duel_proxy.global_position if _duel_proxy != null and is_instance_valid(_duel_proxy) else player.global_position))


func _on_duel_asked(from: String) -> void:
	duel_from = from
	toast("%s te desafiou para um duelo — aceite no Social (G)" % from, 3.5)


## Herói novo: o nome não pode repetir (na conta; online, em todo o jogo — o servidor reserva).
func _new_hero(k: String) -> void:
	var nm: String = _menu.hero_name()
	for d in SaveGame.account()["chars"]:
		if String(d.get("name", "")).to_lower() == nm.to_lower():
			_menu.error("Você já tem um herói chamado %s." % nm)
			return
	var net := get_node("/root/Net")
	if net.online:
		_menu.error("Conferindo o nome...")
		var ok: bool = await net.reserve_name(nm)
		if not ok:
			_menu.error("O nome \"%s\" já é de outro jogador. Escolha outro." % nm)
			return
	_new_name = nm
	SaveGame.select(SaveGame.count())   # vai para um encaixe novo da conta
	start_game(k, {})


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_now()


func _build_camera() -> void:
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = _zoom
	cam.near = 1.0
	cam.far = 500.0
	cam.rotation_degrees = Vector3(CAM_PITCH, CAM_YAW, 0.0)
	add_child(cam)
	cam.make_current()
	var b := cam.global_transform.basis
	cam_right = Vector3(b.x.x, 0, b.x.z).normalized()
	cam_fwd = Vector3(-b.z.x, 0, -b.z.z).normalized()
	_place_camera(Vector3(0, 0, 6))


func _place_camera(target: Vector3) -> void:
	cam.global_position = target + cam.global_transform.basis.z * 150.0


func _build_vignette() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	var g := Gradient.new()
	g.set_offset(0, 0.55)
	g.set_color(0, Color(0, 0, 0, 0))
	g.set_offset(1, 1.0)
	g.set_color(1, Color(0.02, 0.0, 0.03, 0.62))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.12, 0.5)
	gt.width = 256
	gt.height = 256
	var tr := TextureRect.new()
	tr.texture = gt
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(tr)
	var fl := CanvasLayer.new()
	fl.layer = 30
	add_child(fl)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fl.add_child(_fade)


# =================================================================== mapas

func _build_map(id: String, with_zones: bool) -> void:
	if world != null:
		world.queue_free()
		world = null
	for z in zones.values():
		(z as Node).queue_free()
	zones.clear()
	for c in actors.get_children():
		if c != player:
			c.queue_free()
	if npc != null:
		npc.queue_free()
		npc = null
	map_id = id
	world = World.new()
	add_child(world)
	world.build(id)
	Settings.apply_world(world)
	var md: Dictionary = GameData.MAPS[id]
	npc = Npc.new()
	npc.npc_name = String(md["npc"])
	npc.model_name = String(md["npc_model"])
	npc.position = world.npc_pos
	add_child(npc)
	_prop_label(world.portal_pos + Vector3(0, 5.6, 0), "Portal de Viagem", Color(0.55, 0.9, 1.0))
	_prop_label(world.board_pos + Vector3(0, 3.6, 0), "Quadro de Missões", Color(1.0, 0.85, 0.45))
	if with_zones:
		_spawn_zones()


func _spawn_zones() -> void:
	for zid in world.zone_ids():
		var z := Zone.new()
		z.setup(String(zid), actors, world)
		add_child(z)
		z.killed.connect(_on_killed)
		zones[zid] = z


func _prop_label(pos: Vector3, text: String, col: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.font = Toon.title_font()
	l.font_size = 34
	l.pixel_size = 0.015
	l.modulate = col
	l.outline_size = 10
	l.outline_modulate = Color(0.05, 0.02, 0.02)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = pos
	world.add_child(l)


func travel(id: String, ignore_level: bool = false) -> void:
	if _traveling or player == null:
		return
	var md: Dictionary = GameData.MAPS[id]
	if player.level < int(md["min_level"]) and not ignore_level:
		toast("%s libera no nível %d" % [String(md["name"]), int(md["min_level"])], 2.0)
		return
	_traveling = true
	dialog.close()
	if bool(md.get("event", false)) and not bool(GameData.MAPS[map_id].get("event", false)):
		return_map = map_id
	Sfx.play("portal", -2.0)
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.35)
	await tw.finished
	_build_map(id, true)
	player.global_position = world.spawn_pos + Vector3(0, 0.1, 0)
	_cam_target = player.global_position
	_place_camera(_cam_target)
	Sfx.music(String(md["music"]))
	_zone_now = ""
	_route_t = 0.0
	refresh_quest_ui()
	var tw2 := create_tween()
	tw2.tween_property(_fade, "color:a", 0.0, 0.5)
	hud.banner(String(md["name"]), "%s  ·  %s" % [String(md["levels"]), String(md["hub"])], 3.0)
	_traveling = false
	save_now()


# =================================================================== início e save

static func _cls(k: String) -> String:
	return String(GameData.OLD_CLASS.get(k, k)) if GameData.CLASSES.has(GameData.OLD_CLASS.get(k, k)) else "assassino"


func _save_summary() -> String:
	return _summary_of(SaveGame.read())


func _summary_of(d: Dictionary) -> String:
	if d.is_empty():
		return ""
	var cls := _cls(String(d.get("class", "assassino")))
	var mapn := String(GameData.MAPS.get(String(d.get("map", "vale")), GameData.MAPS["vale"])["name"])
	var nm := String(d.get("name", ""))
	return "%s%s  ·  Nível %d  ·  %s" % [nm + "  ·  " if nm != "" else "", String(GameData.CLASSES[cls]["name"]), int(d.get("level", 1)), mapn]


func start_game(key: String, save: Dictionary) -> void:
	if player != null:
		return
	if _menu != null:
		_menu.queue_free()
		_menu = null
	Vfx.warmup()
	player = Player.new()
	player.class_key = key
	player.hero_name = _new_name
	player.cam_right = cam_right
	player.cam_fwd = cam_fwd
	if not save.is_empty():
		_apply_save(save)
	else:
		player.gems = GameData.GEMS_START
	var start_map := String(save.get("map", "vale")) if not save.is_empty() else "vale"
	if not GameData.MAPS.has(start_map):
		start_map = "vale"
	_build_map(start_map, false)
	player.position = world.spawn_pos + Vector3(0, 0.1, 0)
	actors.add_child(player)
	if not save.is_empty():
		player.recalc()
		player.hp = player.max_hp
		player.mp = player.max_mp
	player.face_dir(-cam_fwd)
	player.leveled_up.connect(_on_level_up)
	player.fell.connect(_on_fell)
	player.message.connect(func(t: String) -> void: toast(t, 1.6))
	_cam_target = player.global_position

	_build_ui()
	if Rewards.can_claim_daily(player):
		toast("Recompensa diária disponível — aperte O", 4.0)

	events = WorldEvents.new()
	events.game = self
	events.defeated_key = String(save.get("boss_done", ""))
	add_child(events)
	get_node("/root/Net").boss_scheduled.connect(func(delay: float, minutes: int) -> void:
		if events != null:
			events.schedule(delay, minutes))
	dungeon = Dungeon.new()
	dungeon.game = self
	add_child(dungeon)

	autopilot = Autopilot.new()
	autopilot.game = self
	autopilot.player = player
	autopilot.world = world
	add_child(autopilot)
	autopilot.changed.connect(refresh_quest_ui)

	_spawn_zones()
	missions.refresh()
	Sfx.music(String(GameData.MAPS[map_id]["music"]))
	refresh_quest_ui()
	var md: Dictionary = GameData.MAPS[map_id]
	if save.is_empty():
		hud.banner(String(md["hub"]), "Fale com o %s (!) para receber uma missão" % String(md["npc"]))
	if not tutorial_done:
		start_tutorial(false)
	else:
		hud.banner("Bem-vindo de volta!", "%s  ·  Nível %d" % [String(md["name"]), player.level])
	save_now()


func _apply_save(d: Dictionary) -> void:
	player.level = clampi(int(d.get("level", 1)), 1, GameData.MAX_LEVEL)
	player.xp = int(d.get("xp", 0))
	player.gold = int(d.get("gold", 0))
	player.skill_points = int(d.get("points", 0))
	player.gems = int(d.get("gems", GameData.GEMS_START))
	player.shop_counts = d.get("shop_counts", {})
	player.shop_bonus = d.get("shop_bonus", {})
	player.pet = String(d.get("pet", ""))
	player.mount = String(d.get("mount", ""))
	player.hero_name = String(d.get("name", ""))
	player.friends = d.get("friends", [])
	player.mats = d.get("mats", {})
	player.stats = d.get("stats", {})
	player.login = d.get("login", {})
	player.achieved = d.get("achieved", [])
	player.pet_levels = d.get("pet_levels", {})
	player.xp_boost_until = float(d.get("xp_boost_until", 0.0))
	player.purchases = d.get("purchases", [])
	tutorial_done = bool(d.get("tutorial_done", true))   # saves antigos: quem já jogava não precisa
	var sk: Array = d.get("skills", [1])
	for i in player.skill_levels.size():
		player.skill_levels[i] = int(sk[i]) if i < sk.size() else 0
	player.inventory = []
	player.gear = {}
	var eq: Dictionary = d.get("gear", {})
	if eq.is_empty():   # saves antigos: só arma e armadura (que virou o peitoral)
		eq = {"weapon": d.get("weapon_uid", -1), "chest": d.get("armor_uid", -1)}
	for it in d.get("inventory", []):
		var item := {"uid": int(it["uid"]), "cls": _cls(String(it["cls"])), "slot": String(it["slot"]), "rarity": String(it["rarity"]),
			"refine": int(it.get("refine", 0)), "sell": bool(it.get("sell", false))}
		player.add_item(item)
		for k in eq:
			if int(eq[k]) == int(item["uid"]):
				player.gear[String(k)] = item
	quest_index = int(d.get("quest_index", 0))
	quest_state = String(d.get("quest_state", "none"))
	quest_kills = int(d.get("quest_kills", 0))
	if quest_state == "boss":
		quest_state = "kill"
		quest_kills = maxi(0, int(current_quest().get("count", 1)) - 1)
	missions.from_dict(d.get("missions", {}))
	player.give_all_skins(player.gear.size() < GameData.GEAR_SLOTS.size())


func _gear_uids() -> Dictionary:
	var out := {}
	for k in player.gear:
		out[k] = int(player.gear[k].get("uid", -1))
	return out


func start_tutorial(_again: bool) -> void:
	if tutorial != null:
		tutorial.begin()


func save_now() -> void:
	if player == null:
		return
	var data := {
		"version": 2, "class": player.class_key, "level": player.level, "xp": player.xp, "gold": player.gold,
		"boss_done": events.defeated_key if events != null else "",
		"gems": player.gems, "shop_counts": player.shop_counts, "shop_bonus": player.shop_bonus, "pet": player.pet, "mount": player.mount, "name": player.hero_name, "friends": player.friends, "mats": player.mats, "stats": player.stats, "login": player.login, "achieved": player.achieved, "pet_levels": player.pet_levels,
		"xp_boost_until": player.xp_boost_until, "purchases": player.purchases, "tutorial_done": tutorial_done,
		"skills": player.skill_levels, "points": player.skill_points, "inventory": player.inventory,
		"gear": _gear_uids(),
		"map": return_map if bool(GameData.MAPS[map_id].get("event", false)) else map_id, "quest_index": quest_index, "quest_state": quest_state, "quest_kills": quest_kills,
		"missions": missions.to_dict(), "saved_at": Time.get_datetime_string_from_system(),
	}
	SaveGame.write(data)
	if get_node("/root/Net").online:
		get_node("/root/Net").send_save(data)   # online: o servidor grava no banco
	elif cloud != null:
		cloud.push(data)


func _build_ui() -> void:
	hud = Hud.new()
	add_child(hud)
	hud.setup(player, self)
	hud.skill_clicked.connect(func(i: int) -> void: player.cast_skill(i, _auto_aim()))
	hud.auto_combat_pressed.connect(toggle_auto_combat)
	hud.skills_pressed.connect(func() -> void: skill_panel.toggle())
	hud.map_pressed.connect(toggle_map)
	hud.music_pressed.connect(func() -> void: toast("Música ligada" if Sfx.toggle_music() else "Música desligada", 1.2))
	hud.path_pressed.connect(toggle_path)
	hud.auto_quest_pressed.connect(toggle_auto_quest)
	hud.missions_pressed.connect(func() -> void: board_panel.toggle())
	hud.gear_pressed.connect(func() -> void: gear_panel.toggle())
	hud.shop_pressed.connect(func() -> void: shop_panel.toggle())

	dialog = DialogBox.new()
	add_child(dialog)
	skill_panel = SkillPanel.new()
	add_child(skill_panel)
	skill_panel.setup(player)
	board_panel = MissionBoardPanel.new()
	add_child(board_panel)
	board_panel.setup(self)
	gear_panel = EquipmentPanel.new()
	add_child(gear_panel)
	gear_panel.setup(player)
	shop_panel = ShopPanel.new()
	add_child(shop_panel)
	shop_panel.setup(player)
	pet_panel = PetPanel.new()
	add_child(pet_panel)
	pet_panel.setup(player)
	rewards_panel = RewardsPanel.new()
	add_child(rewards_panel)
	rewards_panel.setup(player)
	portal_panel = PortalPanel.new()
	add_child(portal_panel)
	portal_panel.setup(self)
	forge_panel = ForgePanel.new()
	add_child(forge_panel)
	forge_panel.setup(self)
	market_panel = MarketPanel.new()
	add_child(market_panel)
	market_panel.setup(self)
	ranking_panel = RankingPanel.new()
	add_child(ranking_panel)
	ranking_panel.setup(self)
	social_panel = SocialPanel.new()
	add_child(social_panel)
	social_panel.setup(self)
	_hook_duel()
	add_child(TouchControls.new())
	chat = ChatBox.new()
	chat.game = self
	add_child(chat)
	settings_panel = SettingsPanel.new()
	add_child(settings_panel)
	settings_panel.setup(self)
	tutorial = Tutorial.new()
	add_child(tutorial)
	tutorial.setup(self)
	tutorial.finished.connect(func() -> void:
		tutorial_done = true
		save_now())
	hud.admin_pressed.connect(func() -> void: admin_panel.toggle())
	hud.pets_pressed.connect(func() -> void: pet_panel.toggle())
	hud.rewards_pressed.connect(func() -> void: rewards_panel.toggle())
	hud.settings_pressed.connect(func() -> void: settings_panel.toggle())
	hud.social_pressed.connect(func() -> void: social_panel.toggle())
	hud.ranking_pressed.connect(func() -> void: ranking_panel.toggle())
	hud.market_pressed.connect(func() -> void: market_panel.toggle())
	hud.forge_pressed.connect(func() -> void: forge_panel.toggle())
	admin_panel = AdminPanel.new()
	add_child(admin_panel)
	admin_panel.setup(self)


func _free_ui() -> void:
	for n in [hud, dialog, skill_panel, board_panel, gear_panel, shop_panel, settings_panel, tutorial, admin_panel]:
		if n != null:
			(n as Node).queue_free()


# =================================================================== administrador

func admin_set_level(l: int) -> void:
	player.level = clampi(l, 1, GameData.MAX_LEVEL)
	player.xp = 0
	var used := 0
	for i in player.skill_levels.size():
		used += player.skill_levels[i]
	player.skill_points = maxi(0, player.level - used)
	player.recalc()
	player.hp = player.max_hp
	player.mp = player.max_mp
	player.stats_changed.emit()
	refresh_quest_ui()
	save_now()


func admin_change_class(key: String) -> void:
	if key == player.class_key:
		return
	player.class_key = key
	player.cdata = GameData.CLASSES[key]
	player.gear = {}
	player.give_all_skins(true)
	player.recalc()
	player.hp = player.max_hp
	player.mp = player.max_mp
	player._build_visuals()
	var was_open := admin_panel != null and admin_panel.visible
	_free_ui()
	_build_ui()
	if was_open:
		admin_panel.toggle()
	refresh_quest_ui()
	save_now()


func admin_complete_quest() -> void:
	if current_quest().is_empty():
		return
	quest_state = "done"
	quest_kills = int(current_quest()["count"])
	refresh_quest_ui()
	save_now()


func admin_skip_quest() -> void:
	if current_quest().is_empty():
		return
	quest_index += 1
	quest_state = "none"
	quest_kills = 0
	refresh_quest_ui()
	save_now()


# =================================================================== laço principal

func _process(delta: float) -> void:
	if player != null and is_instance_valid(player):
		_cam_target = _cam_target.lerp(player.global_position, 1.0 - exp(-7.0 * delta))
		player.aim_point = mouse_ground()
		_route_t -= delta
		if _route_t <= 0.0:
			_route_t = 0.35
			_update_route()
		_ui_t -= delta
		if _ui_t <= 0.0:
			_ui_t = 0.25
			_check_zone()
			if skill_panel.visible:
				skill_panel.refresh()
			if board_panel.visible:
				board_panel.refresh()
		_save_t -= delta
		if _save_t <= 0.0:
			_save_t = 20.0
			save_now()
		hud.refresh()
	_place_camera(_cam_target)


func mouse_ground() -> Vector3:
	var mp := get_viewport().get_mouse_position()
	var o := cam.project_ray_origin(mp)
	var n := cam.project_ray_normal(mp)
	if absf(n.y) < 0.0001:
		return player.global_position if player != null else Vector3.ZERO
	var t := -o.y / n.y
	return o + n * t


func _auto_aim() -> Vector3:
	var best := player.global_position + player.facing * 4.0
	var bd := 14.0
	for e in Skills.enemies(get_tree()):
		var d := e.global_position.distance_to(player.global_position)
		if d < bd:
			bd = d
			best = e.global_position
	return best


func _update_route() -> void:
	if (show_path or autopilot.questing) and not _traveling:
		var goal := quest_goal()
		if goal.is_empty():
			_route = PackedVector3Array()
			trail.clear()
			return
		_route = world.route(player.global_position, goal["pos"])
		trail.show_route(_route)
	else:
		_route = PackedVector3Array()
		trail.clear()


func display_route() -> PackedVector3Array:
	return _route


func _check_zone() -> void:
	var now := ""
	if player.global_position.length() < World.VILLAGE_R:
		now = "hub"
	for zid in world.zone_ids():
		var z: Dictionary = GameData.ZONES[zid]
		if Skills.flat(player.global_position - (z["center"] as Vector3)).length() < float(z["radius"]) + 6.0:
			now = String(zid)
	if now != _zone_now:
		_zone_now = now
		if now == "hub":
			hud.banner(String(GameData.MAPS[map_id]["hub"]), "Lugar seguro")
		elif now != "":
			var zd: Dictionary = GameData.ZONES[now]
			hud.banner(String(zd["name"]), String(zd["levels"]))


# =================================================================== entrada

func _input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed and player != null:
		player.mouse_held = false


func _unhandled_input(event: InputEvent) -> void:
	if player == null:
		return
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed:
		if mb.button_index == MOUSE_BUTTON_LEFT:
			var gp := mouse_ground()
			var what := _interactable_at(gp, 2.6)
			if what != "":
				_interact(what, true)
				return
			var vp := get_viewport().get_visible_rect().size
			if DisplayServer.is_touchscreen_available() and mb.position.x < vp.x * 0.4 and mb.position.y > vp.y * 0.35 and mb.position.y < vp.y - 110:
				return   # toque no joystick do celular não é ataque
			player.mouse_held = true
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom = clampf(_zoom - 2.0, 16.0, 48.0)
			cam.size = _zoom
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom = clampf(_zoom + 2.0, 16.0, 48.0)
			cam.size = _zoom
		return
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if (k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER) and chat != null:
		chat.open()
		get_viewport().set_input_as_handled()
		return
	if k.keycode >= KEY_1 and k.keycode <= KEY_9:
		player.cast_skill(k.keycode - KEY_1, player.aim_point)
	elif k.keycode == KEY_0:
		player.cast_skill(9, player.aim_point)
	match k.keycode:
		KEY_K:
			skill_panel.toggle()
		KEY_J:
			board_panel.toggle()
		KEY_I:
			gear_panel.toggle()
		KEY_R:
			player.toggle_ride()
		KEY_U:
			forge_panel.toggle()
		KEY_B:
			market_panel.toggle()
		KEY_N:
			ranking_panel.toggle()
		KEY_G:
			social_panel.toggle()
		KEY_O:
			rewards_panel.toggle()
		KEY_P:
			pet_panel.toggle()
		KEY_L:
			shop_panel.toggle()
		KEY_F1:
			if GameData.ADMIN_ENABLED:
				admin_panel.toggle()
		KEY_M:
			toggle_map()
		KEY_T:
			toggle_auto_combat()
		KEY_E:
			var what := _interactable_at(player.global_position, 5.0)
			if what != "":
				_interact(what, false)
		KEY_ESCAPE:
			var any_open := dialog.visible or skill_panel.visible or board_panel.visible or gear_panel.visible or shop_panel.visible or pet_panel.visible or rewards_panel.visible or portal_panel.visible or social_panel.visible or ranking_panel.visible or market_panel.visible or forge_panel.visible or admin_panel.visible
			dialog.close()
			skill_panel.visible = false
			board_panel.visible = false
			gear_panel.visible = false
			shop_panel.visible = false
			pet_panel.visible = false
			rewards_panel.visible = false
			portal_panel.visible = false
			social_panel.visible = false
			ranking_panel.visible = false
			market_panel.visible = false
			forge_panel.visible = false
			admin_panel.visible = false
			if not any_open:
				settings_panel.toggle()


func _interactable_at(p: Vector3, r: float) -> String:
	var best := ""
	var bd := r
	for pair in [["npc", npc.global_position], ["board", world.board_pos], ["portal", world.portal_pos]]:
		var d := Skills.flat(p - (pair[1] as Vector3)).length()
		if d < bd:
			bd = d
			best = String(pair[0])
	return best


func _interact(what: String, from_click: bool) -> void:
	var pos: Vector3 = npc.global_position
	if what == "board":
		pos = world.board_pos
	elif what == "portal":
		pos = world.portal_pos
	if from_click and Skills.flat(player.global_position - pos).length() > 6.0:
		toast("Chegue mais perto (ou use \"Ir automático\")", 1.8)
		return
	match what:
		"npc":
			talk()
		"board":
			board_panel.toggle()
		"portal":
			open_portal()


func open_portal(_page: int = -1) -> void:
	dialog.close()
	portal_panel.open()


func toggle_map() -> void:
	hud.minimap.big = not hud.minimap.big
	hud.minimap.custom_minimum_size = Vector2(640, 640) if hud.minimap.big else Vector2(300, 300)


func toggle_auto_combat() -> void:
	autopilot.set_auto_combat(not autopilot.auto_combat)
	toast("Auto-combate ligado: o herói luta sozinho com quem chegar perto" if autopilot.auto_combat else "Auto-combate desligado", 2.0)


func toggle_path() -> void:
	focus = "story"
	show_path = not show_path
	_route_t = 0.0
	refresh_quest_ui()


func toggle_auto_quest() -> void:
	if autopilot.questing:
		autopilot.stop_quest()
		toast("Modo automático pausado", 1.6)
	else:
		start_auto("")
	_route_t = 0.0
	refresh_quest_ui()


## Liga o modo automático completo. "prefer" = tipo de missão do quadro para começar (ou "" para seguir a história).
func start_auto(prefer: String) -> void:
	show_path = true
	auto_repeat = true
	player.auto_learn()
	dialog.close()
	if not autopilot.questing:
		autopilot.start_quest()
	_auto_next(prefer)
	toast("Automático ligado: aceita, faz, entrega e segue para a próxima missão sozinho", 2.6)


## Decide a próxima tarefa do modo automático, em ordem:
## 1) missão de história (aceita sozinho, inclusive viajando pelo portal),
## 2) missões do quadro (diária → semanal → mensal, aceitando a próxima sozinho),
## 3) se tudo acabou: caçar monstros na melhor área para o nível.
func _auto_next(prefer: String = "") -> void:
	if not autopilot.questing or player == null:
		return
	_route_t = 0.0
	if prefer != "" and prefer != "story":
		if mission_accept(prefer, true):
			focus = prefer
			refresh_quest_ui()
			return
	var q := current_quest()
	if not q.is_empty():
		if quest_state != "none" or player.level >= int(q["min_level"]):
			focus = "story"
			refresh_quest_ui()
			return
	for kind in GameData.MISSION_KINDS:
		if mission_accept(kind, true):
			focus = kind
			refresh_quest_ui()
			return
	focus = "farm"
	refresh_quest_ui()


func toast(t: String, secs: float = 2.5) -> void:
	if hud != null:
		hud.toast(t, secs)


# =================================================================== metas (história e missões)

func current_quest() -> Dictionary:
	if quest_index < GameData.QUESTS.size():
		return GameData.QUESTS[quest_index]
	return {}


func quest_goal() -> Dictionary:
	if player == null or world == null:
		return {}
	if focus != "story":
		var g := _mission_goal(focus)
		if not g.is_empty():
			return g
	return _story_goal()


func _portal_goal(target_map: String) -> Dictionary:
	return {"pos": world.portal_pos, "kind": "portal", "near": 4.5, "map": target_map}


func _hunt_goal(zid: String, enemy_id: String) -> Dictionary:
	var z: Zone = zones.get(zid)
	if z == null:
		return {}
	var c := z.center()
	if Skills.flat(player.global_position - c).length() < float(z.data["radius"]) + 4.0:
		var best: Enemy = null
		var bd := 999.0
		for e in z.alive_enemies():
			if e.type_id != enemy_id:
				continue
			var d := e.global_position.distance_to(player.global_position)
			if d < bd:
				bd = d
				best = e
		if best != null:
			return {"pos": best.global_position, "kind": "hunt", "near": 3.0}
	return {"pos": c, "kind": "zone", "near": 4.0}


func _story_goal() -> Dictionary:
	var q := current_quest()
	if q.is_empty():
		return {}
	var qmap := GameData.quest_map(q)
	if qmap != map_id:
		return _portal_goal(qmap)
	match quest_state:
		"none", "done":
			return {"pos": npc.global_position, "kind": "npc", "near": 2.6}
		"kill":
			return _hunt_goal(String(q["zone"]), GameData.quest_kill(q))
		"boss":
			var z2: Zone = zones.get(String(q["zone"]))
			if z2 == null:
				return {}
			var bp: Vector3 = z2.data["boss_pos"]
			var zb: Enemy = z2.find_boss()
			if zb != null:
				bp = zb.global_position
			return {"pos": bp, "kind": "boss", "near": 4.0}
	return {}


func _mission_goal(kind: String) -> Dictionary:
	if kind == "farm":
		# masmorras do dia antes de caçar (3 por dia)
		if GameData.is_dungeon(map_id):
			var best: Enemy = null
			for e in get_tree().get_nodes_in_group("enemy"):
				var en := e as Enemy
				if en != null and en.alive and (best == null or en.global_position.distance_to(player.global_position) < best.global_position.distance_to(player.global_position)):
					best = en
			if best != null:
				return {"pos": best.global_position, "kind": "hunt", "near": 3.0}
			return {"pos": GameData.ZONES[String(GameData.MAPS[map_id]["zones"][0])]["center"], "kind": "zone", "near": 4.0}
		if dungeon != null and dungeon.state == "" and dungeon.runs_today() < int(GameData.DUNGEON["per_day"]) and not _traveling:
			dungeon.enter()
			return {}
		var bm := GameData.best_map(player.level)   # caça no mapa mais alto que já alcança
		if bm != map_id and not bool(GameData.MAPS[map_id].get("event", false)):
			return _portal_goal(bm)
		var zid := missions.pick_zone(player.level, map_id)
		return _hunt_goal(zid, String(GameData.ZONES[zid]["enemy"]))
	var mis: Dictionary = missions.active[kind]
	if mis.is_empty():
		return {}
	var zmap := String(GameData.ZONES[mis["zone"]]["map"])
	if zmap != map_id:
		return _portal_goal(zmap)
	return _hunt_goal(String(mis["zone"]), String(mis["enemy"]))


func auto_arrived(kind: String) -> void:
	if kind == "npc":
		var q := current_quest()
		if quest_state == "done":
			turn_in()
		elif quest_state == "none" and not q.is_empty() and player.level >= int(q["min_level"]) and GameData.quest_map(q) == map_id:
			accept_quest(false)
		_auto_next()
	elif kind == "portal":
		var g := quest_goal()
		if String(g.get("kind", "")) == "portal":
			travel(String(g["map"]))


func talk() -> void:
	var q := current_quest()
	var nm := npc.npc_name
	if q.is_empty():
		dialog.open(nm, "Você salvou o reino! Continue fortalecendo seu herói com as missões do quadro.", [["Fechar", dialog.close]])
		return
	var qmap := GameData.quest_map(q)
	if qmap != map_id:
		var mn := String(GameData.MAPS[qmap]["name"])
		dialog.open(nm, "Sua próxima missão, [color=#e8b75a]%s[/color], está em %s. Use o Portal de Viagem do acampamento." % [String(q["title"]), mn],
			[["Ir automático", _go_auto], ["Mostrar caminho", _go_walking], ["Fechar", dialog.close]])
		return
	var enemy_name := String(GameData.enemy(GameData.quest_kill(q))["name"])
	var boss_name := String(GameData.enemy(GameData.quest_boss(q))["name"])
	match quest_state:
		"none":
			if player.level < int(q["min_level"]):
				dialog.open(nm, "Ainda é perigoso demais para você. Volte quando estiver no [color=#e8b75a]nível %d[/color].\nDica: o automático faz as missões do quadro até você chegar lá." % int(q["min_level"]), [["Upar no automático", _go_auto], ["Abrir quadro de missões", func() -> void:
					dialog.close()
					board_panel.toggle()], ["Fechar", dialog.close]])
			else:
				var zone_name := String(GameData.ZONES[q["zone"]]["name"])
				var xp_now := GameData.quest_xp(q)
				var txt := "[b][color=#e8b75a]%s[/color][/b]\n%s\n\n[color=#e8b75a]Objetivo:[/color] derrotar %d × %s e o chefe %s (%s).\n[color=#e8b75a]Recompensa:[/color] %d XP e %d de ouro." % [String(q["title"]), String(q["text"]), int(q["count"]), enemy_name, boss_name, zone_name, xp_now, int(q["gold"])]
				dialog.open(nm, txt, [["Aceitar missão", accept_quest], ["Agora não", dialog.close]])
		"kill", "boss":
			var left := "Faltam %d × %s." % [int(q["count"]) - quest_kills, enemy_name] if quest_state == "kill" else "Derrote o chefe %s!" % boss_name
			dialog.open(nm, "%s\nQuer ajuda para chegar lá?" % left, _travel_options())
		"done":
			dialog.open(nm, "Incrível, viajante! Aqui está a sua recompensa.", [["Receber recompensa", turn_in]])


func _travel_options() -> Array:
	return [["Ir andando (mostrar caminho)", _go_walking], ["Ir automático", _go_auto], ["Fechar", dialog.close]]


func _go_walking() -> void:
	focus = "story"
	show_path = true
	_route_t = 0.0
	dialog.close()
	refresh_quest_ui()


func _go_auto() -> void:
	dialog.close()
	if not autopilot.questing:
		start_auto("")
	else:
		_auto_next()


func accept_quest(show_dialog: bool = true) -> void:
	var q := current_quest()
	quest_state = "kill"
	quest_kills = 0
	focus = "story"
	Sfx.play("quest", -2.0)
	hud.banner("Missão aceita", String(q["title"]))
	var zone_name := String(GameData.ZONES[q["zone"]]["name"])
	if not show_dialog:
		refresh_quest_ui()
		save_now()
		return
	dialog.open(npc.npc_name, "Boa sorte! Como você quer ir até [color=#e8b75a]%s[/color]?\n[i]Andando:[/i] setas douradas no chão mostram a trilha.  [i]Automático:[/i] o herói vai sozinho, luta e volta para entregar." % zone_name, _travel_options())
	refresh_quest_ui()
	save_now()


func turn_in() -> void:
	var q := current_quest()
	if q.is_empty() or quest_state != "done":
		dialog.close()
		return
	dialog.close()
	player.add_gold(int(q["gold"]))
	player.stat_add("quests")
	var got := player.gain_xp(GameData.quest_xp(q))
	Sfx.play("quest", 0.0, 1.2)
	Sfx.play("coin", -4.0)
	hud.banner("Recompensa recebida!", "+%d XP   +%d de ouro" % [got, int(q["gold"])], 3.0)
	if autopilot.questing:
		call_deferred("_auto_next")
	quest_index += 1
	quest_state = "none"
	quest_kills = 0
	if not autopilot.questing:
		show_path = false
	refresh_quest_ui()
	save_now()


# =================================================================== missões do quadro

func mission_accept(kind: String, quiet: bool = false) -> bool:
	missions.refresh()
	if not (missions.active[kind] as Dictionary).is_empty():
		return true
	if missions.remaining(kind) <= 0:
		if not quiet:
			toast("Limite de missões %s atingido por agora" % String(GameData.MISSION[kind]["name"]).to_lower(), 2.2)
		return false
	var mis := missions.accept(kind, player.level, map_id)
	if mis.is_empty():
		return false
	if not quiet:
		Sfx.play("quest", -6.0, 1.3)
		toast("Missão %s: derrote %d × %s" % [String(GameData.MISSION[kind]["name"]).to_lower().trim_suffix("s"), int(mis["need"]), String(GameData.enemy(String(mis["enemy"]))["name"])], 2.2)
	refresh_quest_ui()
	return true


func mission_path(kind: String) -> void:
	if (missions.active[kind] as Dictionary).is_empty():
		return
	focus = kind
	show_path = true
	_route_t = 0.0
	refresh_quest_ui()


func mission_auto(kind: String) -> void:
	if not mission_accept(kind, true):
		toast("Sem missões %s disponíveis agora — o automático segue com as outras" % String(GameData.MISSION[kind]["name"]).to_lower(), 2.0)
	start_auto(kind)


func _mission_done(kind: String) -> void:
	var mis := missions.complete(kind)
	if mis.is_empty():
		return
	player.stat_add("quests")
	var got := player.gain_xp(int(mis["xp"]))
	player.add_gold(int(mis["gold"]))
	Sfx.play("quest", -3.0, 1.15)
	var m: Dictionary = GameData.MISSION[kind]
	hud.banner("Missão %s concluída!" % String(m["name"]).to_lower().trim_suffix("s"), "+%d XP  +%d de ouro   (%d / %d)" % [got, int(mis["gold"]), int(missions.done[kind]), int(m["limit"])], 2.2)
	if randf() < float(m["chest"]):
		_drop_item(GameData.roll_rarity("chest"), player.global_position + Vector3(1, 0, 1))
		toast("Você ganhou um baú de recompensa!", 2.0)
	if autopilot.questing:
		# segue a mesma categoria enquanto houver limite; senão passa para a próxima tarefa
		var q := current_quest()
		var story_ready := not q.is_empty() and quest_state == "none" and player.level >= int(q["min_level"])
		if focus == kind and not story_ready and mission_accept(kind, true):
			pass
		else:
			if focus == kind and missions.remaining(kind) <= 0:
				toast("Missões %s: limite atingido — seguindo para a próxima" % String(m["name"]).to_lower(), 2.4)
			_auto_next()
	elif focus == kind:
		focus = "story"
	refresh_quest_ui()
	save_now()


# =================================================================== mortes, drops

func _on_killed(e: Enemy) -> void:
	if player == null:
		return
	if e.net_id > 0 and not e.net_credit:   # online: outro jogador matou sem você bater
		return
	player.gain_xp(int(e.data["xp"]))
	player.stat_add("kills")
	if e.boss:
		player.stat_add("global" if String(e.data.get("name", "")) == String(GameData.enemy("dragon_global")["name"]) else "bosses")
	if player.pet_gain():
		toast("Seu pet subiu para o nível %d!" % player.pet_level(), 2.0)
	var g: Vector2i = e.data["gold"]
	_drop("gold", randi_range(g.x, g.y), "Ouro", e.global_position)
	var table := "boss" if e.boss else "mob"
	_drop_mats(table)
	if e.net_id > 0:   # online: o servidor sorteou o drop (para quem mais bateu)
		if e.net_drop != "":
			_drop_item(e.net_drop, e.global_position + Vector3(1, 0, 0))
	elif randf() < float(GameData.DROP_CHANCE[table]) * GameData.DROP_MULT:
		_drop_item(GameData.roll_rarity(table), e.global_position + Vector3(1, 0, 0))
	var q := current_quest()
	if not q.is_empty() and e.zone_id == String(q["zone"]):
		if quest_state == "kill" and e.type_id == GameData.quest_kill(q):
			quest_kills += 1
			if quest_kills >= int(q["count"]):
				quest_state = "boss"
				if get_node("/root/Net").online and not bool(GameData.MAPS[map_id].get("event", false)):
					get_node("/root/Net").request_boss.rpc_id(1, String(q["zone"]), GameData.quest_boss(q))
				else:
					var z: Zone = zones[q["zone"]]
					z.spawn_boss(GameData.quest_boss(q))
				Sfx.play("boss", -1.0)
				hud.banner(String(GameData.enemy(GameData.quest_boss(q))["name"]), "O chefe apareceu!", 3.0)
				_route_t = 0.0
		elif quest_state == "boss" and e.type_id == GameData.quest_boss(q):
			quest_state = "done"
			Sfx.play("quest", 0.0)
			hud.banner("Missão concluída!", "Volte ao %s para receber a recompensa" % npc.npc_name, 3.5)
			_route_t = 0.0
			save_now()
	for kind in missions.on_kill(e.type_id, e.zone_id):
		_mission_done(kind)
	refresh_quest_ui()


func _drop(kind: String, value: int, title: String, at: Vector3) -> void:
	var l := Loot.new()
	l.kind = kind
	l.value = value
	l.title = title
	l.position = Vector3(at.x, 0.0, at.z)
	l.picked.connect(_on_loot)
	actors.add_child(l)


## Materiais da forja: chance por monstro; chefe sempre dá alguns.
func _drop_mats(table: String) -> void:
	var got := []
	for k in GameData.MAT_DROP[table]:
		var v := float(GameData.MAT_DROP[table][k])
		var n := int(v) if v >= 1.0 else (1 if randf() < v else 0)
		if n > 0:
			player.mats[k] = int(player.mats.get(k, 0)) + n
			got.append("+%d %s" % [n, String(GameData.MATERIALS[k]["name"])])
	if not got.is_empty():
		Fx.damage_number(actors, player.global_position + Vector3(0, 3.2, 0), " ".join(got), Color(1.0, 0.75, 0.4))


func _drop_item(rarity: String, at: Vector3) -> void:
	var item := player.new_item(String(Player.ITEM_SLOTS.pick_random()), rarity)
	item["sell"] = true   # item que cai pode ir para o Mercadinho
	var l := Loot.new()
	l.kind = "item"
	l.item = item
	l.position = Vector3(at.x, 0.0, at.z)
	l.picked.connect(_on_loot)
	actors.add_child(l)


func _on_loot(l: Loot) -> void:
	if l.kind == "gold":
		player.add_gold(l.value)
		Sfx.play("coin", -10.0)
	elif l.kind == "item":
		player.inventory.append(l.item)
		var rn := String(GameData.RARITY[l.item["rarity"]]["name"])
		var nm := GameData.item_name(l.item)
		if String(l.item["rarity"]) == "lendaria" or String(l.item["rarity"]) == "epica":
			Sfx.play("legendary", -2.0)
			hud.banner("Item %s!" % rn, nm + "  —  aperte I para equipar", 3.5)
		else:
			Sfx.play("equip", -6.0)
			toast("Você encontrou: %s (%s) — aperte I" % [nm, rn], 2.5)
		if gear_panel.visible:
			gear_panel.refresh()
		save_now()
	else:
		Sfx.play("levelup", -6.0, 1.5)
		toast("Você encontrou: %s" % l.title, 2.5)


# =================================================================== interface

func refresh_quest_ui() -> void:
	if hud == null:
		return
	var q := current_quest()
	var title := ""
	var obj := ""
	if q.is_empty():
		title = "História concluída"
		obj = "Use o Quadro de Missões para continuar evoluindo."
	else:
		var qmap := GameData.quest_map(q)
		match quest_state:
			"none":
				if player.level < int(q["min_level"]):
					title = "Próxima missão no nível %d" % int(q["min_level"])
					obj = "Faça missões do quadro (J) para ganhar XP."
				else:
					title = "Nova missão disponível"
					obj = "Fale com %s (!)" % String(GameData.MAPS[qmap]["npc"])
			"kill":
				title = String(q["title"])
				obj = "Derrote %s: %d / %d\nLocal: %s" % [String(GameData.enemy(GameData.quest_kill(q))["name"]), quest_kills, int(q["count"]), String(GameData.ZONES[q["zone"]]["name"])]
			"boss":
				title = String(q["title"])
				obj = "Derrote o chefe: %s" % String(GameData.enemy(GameData.quest_boss(q))["name"])
			"done":
				title = String(q["title"])
				obj = "Concluída! Volte ao %s para entregar." % String(GameData.MAPS[qmap]["npc"])
		if qmap != map_id:
			obj += "\n(em %s — use o portal)" % String(GameData.MAPS[qmap]["name"])
	hud.set_quest(title, obj, true, show_path, autopilot.questing)
	var lines: Array = []
	for kind in GameData.MISSION_KINDS:
		var mis: Dictionary = missions.active[kind]
		var m: Dictionary = GameData.MISSION[kind]
		var head := "%s %d/%d" % [String(m["name"]), int(missions.done[kind]), int(m["limit"])]
		if not mis.is_empty():
			head += ":  %s %d/%d" % [String(GameData.enemy(String(mis["enemy"]))["name"]), int(mis["have"]), int(mis["need"])]
			if autopilot.questing and focus == kind:
				head += "  [fazendo]"
		lines.append(head)
	if autopilot.questing:
		var doing := "história" if focus == "story" else ("caçando na melhor área" if focus == "farm" else "missões %s" % String(GameData.MISSION[focus]["name"]).to_lower())
		lines.append("Automático: " + doing)
	hud.set_missions("\n".join(lines))
	hud.set_auto_combat(autopilot.auto_combat)
	var marker := ""
	if not q.is_empty() and GameData.quest_map(q) == map_id:
		if quest_state == "done":
			marker = "?"
		elif quest_state == "none" and player.level >= int(q["min_level"]):
			marker = "!"
	npc.set_marker(marker)


func _on_level_up(l: int) -> void:
	var sub := "+1 ponto de skill — aperte K para melhorar suas habilidades"
	if l == 31:
		sub = "A partir de agora o XP vale 10x menos: subir de nível fica mais difícil!"
	hud.banner("Nível %d!" % l, sub, 3.0)
	if autopilot.questing or autopilot.auto_combat:
		player.auto_learn()
	if autopilot.questing and focus != "story":
		var q := current_quest()
		if not q.is_empty() and quest_state == "none" and l >= int(q["min_level"]) and (focus == "farm" or (missions.active[focus] as Dictionary).is_empty()):
			_auto_next()
	refresh_quest_ui()
	save_now()


func _on_fell() -> void:
	_resume_auto = autopilot.questing
	autopilot.stop_quest()
	hud.banner("Você caiu!", "Voltando para o acampamento...", 2.5)
	Fx.later(self, 3.0).connect(func() -> void:
		player.revive(world.spawn_pos + Vector3(0, 0.1, 0))
		_cam_target = player.global_position
		if _resume_auto:
			autopilot.start_quest())
