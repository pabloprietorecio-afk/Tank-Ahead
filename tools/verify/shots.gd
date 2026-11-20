extends Node
## Herramienta de verificación (no va en el APK): recorre escenas de muestra y partidas de
## cada frente y guarda capturas en res://shots_out. La usa el flujo .github/workflows/verify.yml
## para comprobar el aspecto del juego con un renderizador por software.


func _ready() -> void:
	var runner := Runner.new()
	runner.name = "ShotRunner"
	get_tree().root.add_child.call_deferred(runner)


class Runner extends Node:

	## Órdenes por voz: frases tal como las devuelve el reconocedor de Google (con sus errores) y la
	## orden que deben dar ("" = ninguna). Imprime «VOZ RESULT fallos: N».
	func _voice_orders() -> void:
		var saved: String = Loc.language
		var cases: Array = [
			["es", "Lanzarme sí", "missile"], ["es", "lanzar mi sí", "missile"], ["es", "lanza misil", "missile"],
			["es", "todo conmigo", "follow"], ["es", "atacara mi objetivo", "attack"],
			["es", "localiza objetivo", "locate"], ["es", "solicito bombero", "strike"],
			["es", "solicitó bombarde", "strike"], ["es", "Todos conmigo.", "follow"],
			["es", "hola qué tal", ""], ["es", "vamos a comer", ""], ["es", "lanzamiento", "missile"],
			["es", "está lloviendo mucho hoy en Madrid", ""], ["es", "lazarillo", ""], ["es", "ya está", ""],
			["en", "lunch missile", "missile"], ["en", "located target", "locate"],
			["en", "what's for lunch today", ""], ["en", "let's go home", ""],
			["de", "rakete abfeuer", "missile"], ["de", "ich gehe nach hause", ""],
			["fr", "lancer le missile", "missile"], ["pt", "lançar missel", "missile"],
			["ru", "пуск ракета", "missile"], ["ru", "пойдём домой", ""],
		]
		var failures: int = 0
		for item in cases:
			Loc.apply(item[0])
			var got: String = VoiceOrders.recognize(item[1], item[0], true)
			if got != item[2]:
				failures += 1
				print("VOZ FALLO [%s] «%s» → «%s» (esperado «%s»)" % [item[0], item[1], got, item[2]])
		Loc.apply(saved)
		print("VOZ RESULT fallos: %d de %d" % [failures, cases.size()])

	var _dir: String
	var _unreachable: int = 0
	var _camera: Camera3D
	var _stage: Node3D

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		# Con el renderizador por software todo va lento: que los efectos no se rebajen solos.
		Fx.governor = false
		# Las pruebas quieren la partida en marcha desde el primer instante (la entrada aérea
		# tiene su propia prueba, «intro»).
		GameSession.skip_intro = true
		# Y sin sortear costa en supervivencia y captura la bandera (su prueba es «costa»).
		GameSession.debug_coast = "none"
		_dir = ProjectSettings.globalize_path("res://shots_out")
		DirAccess.make_dir_recursive_absolute(_dir)
		_run.call_deferred()

	func _run() -> void:
		await _frames(2)
		_voice_orders()
		var only: String = OS.get_environment("SHOTS_ONLY")
		if only == "" or only.contains("tanks"):
			await _tanks()
		if only == "" or only.contains("boom"):
			await _explosions()
		if only == "" or only.contains("props"):
			await _props()
		if only == "" or only.contains("arena"):
			for front in 3:
				await _arena(front)
		if only == "" or only.contains("menu"):
			await _menu()
		if only.contains("flags"):
			await _flags()
		if only.contains("fit"):
			await _menu_fit()
		if only.contains("story"):
			_campaign()
			await _story(Fronts.Faction.ALLIES, Fronts.Id.NORMANDY, 6)
			await _story(Fronts.Faction.AXIS, Fronts.Id.KURSK, 6)
			await _story(Fronts.Faction.ALLIES, Fronts.Id.AFRICA, 5)
			await _story(Fronts.Faction.AXIS, Fronts.Id.AFRICA, 7)
			await _story(Fronts.Faction.ALLIES, Fronts.Id.AFRICA, 1)
			await _story(Fronts.Faction.ALLIES, Fronts.Id.KURSK, 1)
			await _story(Fronts.Faction.AXIS, Fronts.Id.NORMANDY, 5)
			await _story(Fronts.Faction.ALLIES, Fronts.Id.NORMANDY, 3)
			await _story(Fronts.Faction.AXIS, Fronts.Id.KURSK, 3)
			await _story(Fronts.Faction.ALLIES, Fronts.Id.KURSK, 4)
			print("REACH RESULT inaccesibles: ", _unreachable)
		if only.contains("mapas"):
			await _maps()
		if only.contains("rios"):
			await _rivers()
		if only.contains("asaltos"):
			await _assaults()
		if only.contains("vista_mapas"):
			await _map_shots()
		if only.contains("vista_frentes"):
			await _front_shots()
		if only.contains("intro"):
			await _intro()
		if only.contains("barcos"):
			await _ships()
		if only.contains("carga"):
			await _loading()
		if only.contains("seguir"):
			await _stay()
		if only.contains("aereo"):
			await _air_phase()
		if only.contains("costa"):
			await _coast()
		if only.contains("mira"):
			await _lock_reticle()
		if only.contains("sonido"):
			await _real_guns()
		if only.contains("nav"):
			await _nav()
		if only.contains("tutorial"):
			await _tutorial()
		if only == "" or only.contains("tutshots"):
			await _tutorial_shots()
		if only.contains("ai"):
			await _ai_reaction()
		if only.contains("ctf"):
			await _ctf()
		if only.contains("sky"):
			await _sky()
		if only == "" or only.contains("skyshots"):
			await _sky_shots()
		if only == "" or only.contains("ctfshot"):
			await _ctf_shot()
		if only.contains("storecover"):
			await _store_cover()
		elif only.contains("store"):
			await _store()
		if only.contains("lomas"):
			await _lomas()
		if only.contains("pausa"):
			await _pause_fit()
		if only.contains("tanques"):
			_player_tanks()
			await _casemate()
		if only.contains("aliados"):
			await _allies()
		if only.contains("halo"):
			await _halo()
		if only.contains("formacion"):
			await _formation()
		if only.contains("vista_formacion"):
			await _formation_shots()
		if only.contains("mapaformacion"):
			for front: int in [Fronts.Id.NORMANDY, Fronts.Id.AFRICA, Fronts.Id.KURSK]:
				if OS.get_environment("MAPA_FRENTE") in ["", str(front)]:
					await _formation_map(front)
		if _wants(only, "vista_clima"):
			await _weather_shots()
		if only.contains("vista_contraste"):
			await _contrast_shots()
		if only.contains("vista_mira"):
			await _reticle_shots()
		if _wants(only, "vista_loma"):
			await _mound_shots()
		if _wants(only, "vista_halo"):
			await _halo_shots()
		if _wants(only, "vista_sombra"):
			await _overlay_shadows()
		if _wants(only, "vista_ui"):
			await _ui_shots()
		print("SHOTS DONE")
		get_tree().quit()

	func _frames(count: int) -> void:
		for i in count:
			await get_tree().process_frame

	func _snap(shot: String) -> void:
		await _frames(3)
		if DisplayServer.get_name() == "headless":
			return
		await RenderingServer.frame_post_draw
		var image: Image = get_viewport().get_texture().get_image()
		image.save_jpg(_dir.path_join(shot + ".jpg"), 0.88)
		print("SHOT ", shot)

	func _look(eye: Vector3, target: Vector3, fov: float = 45.0) -> void:
		_camera.fov = fov
		_camera.global_transform = Transform3D(Basis.looking_at(target - eye, Vector3.UP), eye)
		_camera.current = true

	## Escenario neutro: cielo de atardecer, sol con sombras y suelo del frente indicado.
	func _new_stage(front: int) -> void:
		var old: Node = get_tree().current_scene
		if old != null:
			old.queue_free()
		await _frames(2)
		GameSession.front = front
		_stage = Node3D.new()
		get_tree().root.add_child(_stage)
		get_tree().current_scene = _stage
		var sky_material := ProceduralSkyMaterial.new()
		sky_material.sky_top_color = Color(0.2, 0.35, 0.6)
		sky_material.sky_horizon_color = Color(0.7, 0.68, 0.6)
		sky_material.ground_horizon_color = Color(0.5, 0.48, 0.42)
		sky_material.sky_cover = VectorMaterials.clouds()
		sky_material.sky_cover_modulate = Color(0.6, 0.6, 0.6)
		var sky := Sky.new()
		sky.sky_material = sky_material
		var env := Environment.new()
		env.background_mode = Environment.BG_SKY
		env.sky = sky
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		env.ambient_light_energy = 0.7
		env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		var world_env := WorldEnvironment.new()
		world_env.environment = env
		_stage.add_child(world_env)
		var sun := DirectionalLight3D.new()
		sun.rotation = Vector3(deg_to_rad(-35.0), deg_to_rad(-40.0), 0.0)
		sun.light_color = Color(1.0, 0.93, 0.82)
		sun.light_energy = 1.3
		sun.shadow_enabled = true
		sun.directional_shadow_max_distance = 80.0
		_stage.add_child(sun)
		# El humo y el polvo de los efectos se iluminan con la luz de este escenario.
		Fx.set_lighting(sun.global_basis.z, sun.light_color.srgb_to_linear() * sun.light_energy, sky_material.sky_top_color.lerp(sky_material.sky_horizon_color, 0.55).srgb_to_linear() * 0.6, 0.0)
		var fx: Fx = Fx.on(_stage)
		var dirt: Color = Fronts.ground_colors(front)[2]
		fx.soil = dirt.darkened(0.3).srgb_to_linear()
		fx.dust = dirt.lerp(Color(0.56, 0.53, 0.48), 0.4).srgb_to_linear()
		var ground_mat: ShaderMaterial = VectorMaterials.ground().duplicate()
		var colors: Array[Color] = Fronts.ground_colors(front)
		ground_mat.set_shader_parameter("grass", colors[0])
		ground_mat.set_shader_parameter("dry_grass", colors[1])
		ground_mat.set_shader_parameter("dirt", colors[2])
		ground_mat.set_shader_parameter("gravel", colors[3])
		ground_mat.set_shader_parameter("tint", 0.0)
		ground_mat.set_shader_parameter("wet", 0.0)
		var plane := PlaneMesh.new()
		plane.size = Vector2(400.0, 400.0)
		var ground := MeshInstance3D.new()
		ground.mesh = plane
		ground.material_override = ground_mat
		_stage.add_child(ground)
		_camera = Camera3D.new()
		_camera.far = 500.0
		_stage.add_child(_camera)

	func _tank(id: String, front: int, faction: int, pos: Vector3, yaw: float, player: bool = false) -> TankModel:
		var stats: TankStats = Fronts.tank(id)
		var holder := Node3D.new()
		holder.position = pos
		holder.rotation.y = yaw
		_stage.add_child(holder)
		return TankModel.build(holder, stats, Fronts.paint(front, faction, stats.nation), player)

	func _tanks() -> void:
		var allies: Array[String] = ["m4_sherman", "t34_76", "cromwell", "m10_wolverine", "churchill", "is2", "m26_pershing", "kv1", "t34_85", "su85", "crusader"]
		var axis: Array[String] = ["tiger1", "panther", "panzer4", "stug3", "tiger2", "panzer3", "elefant", "marder3"]
		var wheeled: Array[String] = ["m8_greyhound", "ba64", "puma"]
		await _new_stage(Fronts.Id.NORMANDY)
		for i in allies.size():
			_tank(allies[i], Fronts.Id.NORMANDY if i % 2 == 0 else Fronts.Id.KURSK, Fronts.Faction.ALLIES, Vector3(i * 8.0, 0.0, 0.0), deg_to_rad(-35.0))
		for i in axis.size():
			_tank(axis[i], Fronts.Id.NORMANDY if i % 2 == 0 else Fronts.Id.KURSK, Fronts.Faction.AXIS, Vector3(i * 9.0, 0.0, 14.0), deg_to_rad(-35.0))
		for i in wheeled.size():
			_tank(wheeled[i], Fronts.Id.AFRICA, Fronts.Faction.AXIS if i == 2 else Fronts.Faction.ALLIES, Vector3(i * 7.0, 0.0, 26.0), deg_to_rad(-35.0))
		var wreck: TankModel = _tank("panzer4", Fronts.Id.NORMANDY, Fronts.Faction.AXIS, Vector3(30.0, 0.0, 26.0), deg_to_rad(-60.0))
		for mesh in wreck.own:
			mesh.material_override = VectorMaterials.burnt(mesh.material_override)
		_tank("m4_sherman", Fronts.Id.AFRICA, Fronts.Faction.ALLIES, Vector3(40.0, 0.0, 26.0), deg_to_rad(-35.0), true)
		await get_tree().create_timer(1.5).timeout
		for i in allies.size():
			_look(Vector3(i * 8.0 - 6.5, 3.2, -7.5), Vector3(i * 8.0, 1.2, 0.0), 40.0)
			await _snap("tank_%s" % allies[i])
		for i in axis.size():
			_look(Vector3(i * 9.0 - 7.0, 3.4, 14.0 - 8.0), Vector3(i * 9.0, 1.3, 14.0), 40.0)
			await _snap("tank_%s" % axis[i])
		for i in wheeled.size():
			_look(Vector3(i * 7.0 - 5.0, 2.6, 26.0 - 6.0), Vector3(i * 7.0, 1.0, 26.0), 40.0)
			await _snap("tank_%s" % wheeled[i])
		_look(Vector3(30.0 - 6.0, 3.0, 26.0 - 7.0), Vector3(30.0, 1.0, 26.0), 40.0)
		await _snap("tank_wreck")
		# Otros ángulos: costado, zaga, cenital y primer plano del tren de rodaje.
		_look(Vector3(0.0, 1.6, -9.0), Vector3(0.0, 1.2, 0.0), 40.0)
		await _snap("angle_sherman_low")
		_look(Vector3(9.0, 1.4, 14.0 - 8.0), Vector3(0.0, 1.3, 14.0), 35.0)
		await _snap("angle_tiger_side")
		_look(Vector3(8.0 + 5.0, 4.0, 8.0), Vector3(8.0, 1.0, 0.0), 40.0)
		await _snap("angle_t34_rear")
		_look(Vector3(9.0, 11.0, 14.0 + 0.5), Vector3(9.0, 0.0, 14.0), 40.0)
		await _snap("angle_panther_top")
		_look(Vector3(-2.6, 0.9, 14.0 - 3.2), Vector3(-0.6, 0.6, 14.0 - 1.0), 40.0)
		await _snap("angle_tiger_tracks")
		_look(Vector3(40.0 + 5.0, 6.0, 26.0 + 9.0), Vector3(40.0, 1.0, 26.0), 40.0)
		await _snap("angle_player_rear")
		_look(Vector3(-10.0, 7.0, -14.0), Vector3(22.0, 0.0, 12.0), 60.0)
		await _snap("lineup")

	## Explosiones a cámara lenta: grande, impacto pequeño y derrumbe sin fuego.
	func _explosions() -> void:
		for front in [Fronts.Id.NORMANDY, Fronts.Id.AFRICA]:
			await _new_stage(front)
			_tank("panzer4", front, Fronts.Faction.AXIS, Vector3(-9.0, 0.0, -3.0), deg_to_rad(-50.0))
			_look(Vector3(2.0, 3.5, 17.0), Vector3(0.5, 2.8, 0.0), 50.0)
			await get_tree().create_timer(0.6).timeout
			Engine.time_scale = 0.3
			Explosion.spawn(_stage, Vector3(0.0, 0.5, 0.0), 1.6, VectorMaterials.ORANGE, true)
			Explosion.spawn(_stage, Vector3(7.5, 1.2, 2.0), 0.4, VectorMaterials.ORANGE, true)
			Explosion.spawn(_stage, Vector3(-6.0, 1.5, 4.0), 1.2, Color(0.5, 0.48, 0.45), true)
			for i in 9:
				await _snap("boom_%d_%d" % [front, i])
			Engine.time_scale = 1.0

	func _props() -> void:
		for front in 3:
			await _new_stage(front)
			PropFactory.mountain_color = Fronts.mountain_color(front)
			var props: Array[Node3D] = []
			match front:
				Fronts.Id.AFRICA:
					props = [PropFactory.desert_house(Vector3(7.0, 4.0, 7.0)), PropFactory.palm(8.0), PropFactory.desert_house(Vector3(5.0, 3.2, 6.0)), PropFactory.palm(9.5), PropFactory.sandbags(8.0), PropFactory.rock(2.2), PropFactory.barrel(), StructureFactory.flak_gun()]
				Fronts.Id.KURSK:
					props = [PropFactory.izba(Vector3(6.0, 3.5, 7.0)), PropFactory.birch(8.0), PropFactory.izba(Vector3(7.0, 3.8, 8.0)), PropFactory.tree(9.0), PropFactory.haystack(), PropFactory.hedgehog(), PropFactory.fence(10.0), StructureFactory.water_tower()]
				_:
					props = [PropFactory.house(Vector3(7.0, 4.5, 8.0)), PropFactory.apple_tree(5.5), PropFactory.house(Vector3(6.0, 4.0, 7.0)), PropFactory.hedgerow(20.0), PropFactory.ruin(12.0), PropFactory.lamp_post(), PropFactory.rock(1.8), StructureFactory.command_tent()]
			for i in props.size():
				props[i].position = Vector3((i % 4) * 13.0, 0.0, -(i / 4) * 16.0)
				_stage.add_child(props[i])
			if front == Fronts.Id.NORMANDY:
				var church := PropFactory.church()
				church.position = Vector3(20.0, 0.0, -45.0)
				_stage.add_child(church)
			for i in 5:
				var mountain := PropFactory.mountain(randf_range(45.0, 70.0), randf_range(18.0, 40.0), 10 if front == Fronts.Id.AFRICA else 7)
				mountain.position = Vector3(-120.0 + i * 70.0, 0.0, -170.0 - (i % 2) * 40.0)
				_stage.add_child(mountain)
			var hill := PropFactory.mountain(14.0, 9.0, 10 if front == Fronts.Id.AFRICA else 7)
			hill.position = Vector3(60.0, 0.0, -10.0)
			_stage.add_child(hill)
			# Casa bombardeada en llamas y árboles quemados (uno ardiendo y otro que solo humea).
			var bombed := PropFactory.bombed_house(Vector3(7.0, 4.4, 8.0), front)
			bombed.position = Vector3(-18.0, 0.0, -8.0)
			bombed.rotation.y = 0.5
			_stage.add_child(bombed)
			for i in 2:
				var burnt := PropFactory.burnt_tree(6.0 if front != Fronts.Id.AFRICA else 8.0, [0, 2, 1][front], i == 0)
				burnt.position = Vector3(-10.0 - i * 9.0, 0.0, 4.0 + i * 2.0)
				_stage.add_child(burnt)
			await get_tree().create_timer(1.0).timeout
			_look(Vector3(-6.0, 6.0, 20.0), Vector3(20.0, 2.0, -8.0), 60.0)
			await _snap("props_%d_wide" % front)
			_look(Vector3(-4.0, 3.0, 11.0), Vector3(3.0, 2.2, 0.0), 45.0)
			await _snap("props_%d_house" % front)
			_look(Vector3(20.0, 3.0, 10.0), Vector3(28.0, 2.0, -2.0), 50.0)
			await _snap("props_%d_right" % front)
			_look(Vector3(15.0, 2.5, -6.0), Vector3(22.0, 1.5, -16.0), 55.0)
			await _snap("props_%d_back" % front)
			_look(Vector3(40.0, 4.0, 14.0), Vector3(60.0, 4.0, -10.0), 50.0)
			await _snap("props_%d_hill" % front)
			await get_tree().create_timer(4.0).timeout
			_look(Vector3(-6.0, 3.5, 20.0), Vector3(-16.0, 4.5, -6.0), 58.0)
			await _snap("props_%d_fire" % front)
			# Derrumbe: la primera casa se viene abajo y el primer árbol cae y arde.
			_look(Vector3(-6.0, 6.0, 20.0), Vector3(8.0, 2.0, -4.0), 60.0)
			props[0].take_hit(9999.0, null, props[0].global_position + Vector3(2.0, 2.0, 6.0))
			props[1].take_hit(9999.0, null, props[1].global_position + Vector3(-1.0, 1.5, 3.0))
			await get_tree().create_timer(0.7).timeout
			await _snap("props_%d_collapse" % front)
			await get_tree().create_timer(5.0).timeout
			await _snap("props_%d_rubble" % front)

	func _arena(front: int) -> void:
		GameSession.mode = GameSession.Mode.SURVIVAL
		GameSession.front_choice = front
		GameSession.faction = Fronts.Faction.ALLIES if front != Fronts.Id.KURSK else Fronts.Faction.AXIS
		GameSettings.ensure_loaded()
		GameSettings.camera_view = 1
		get_tree().change_scene_to_file("res://levels/arena.tscn")
		await _frames(3)
		await get_tree().create_timer(3.0).timeout
		await _snap("arena_%d_chase" % front)
		var arena: Node = get_tree().current_scene
		var player: Node3D = null
		for tank in get_tree().get_nodes_in_group(&"tanks"):
			if tank.is_player:
				player = tank
		_camera = Camera3D.new()
		_camera.far = 700.0
		arena.add_child(_camera)
		var origin: Vector3 = player.global_position if player != null else Vector3.ZERO
		_look(origin + Vector3(14.0, 5.0, 16.0), origin + Vector3(0.0, 1.5, 0.0), 55.0)
		await _snap("arena_%d_player" % front)
		_look(origin + Vector3(0.0, 45.0, 60.0), origin + Vector3(0.0, 0.0, -30.0), 60.0)
		await _snap("arena_%d_high" % front)
		# Enemigos destacados con el borde amarillo, vistos de cerca.
		await get_tree().create_timer(5.0).timeout
		GameSettings.highlight_enemies = true
		for other in get_tree().get_nodes_in_group(&"tanks"):
			other.refresh_highlight()
			if not other.is_player and other.team != 0:
				var at: Vector3 = other.global_position
				_look(at + Vector3(9.0, 4.0, 11.0), at + Vector3(0.0, 1.2, 0.0), 45.0)
				await _snap("arena_%d_outline" % front)
				break
		GameSettings.highlight_enemies = false
		if front == 0:
			# Menú de opciones (pausa), la galería de vehículos y la vista con zoom.
			var hud: Hud = arena._hud
			hud._set_paused(true)
			await _snap("options_menu")
			hud._history_from_menu = true
			hud._pause_panel.visible = false
			hud._history_gallery.show_index(3)
			hud.move_child(hud._history_panel, -1)
			hud._history_panel.visible = true
			await _snap("options_vehicles")
			hud._set_paused(false)
			_camera.current = false
			player.camera.current = true
			player.set_binoculars(true)
			await _snap("zoom_buttons")
			player.set_binoculars(false)
			_camera.current = true
		for i in 4:
			var angle: float = TAU * i / 4.0 + 0.4
			_look(origin + Vector3(0.0, 3.0, 0.0), origin + Vector3(sin(angle) * 50.0, 4.0, cos(angle) * 50.0), 70.0)
			await _snap("arena_%d_view%d" % [front, i])

	## Cada página del menú principal debe caber en una pantalla de 720 de alto sin tener que
	## desplazarla. Las listas de misiones de una campaña son la excepción (son listas largas).
	func _menu_fit() -> void:
		get_tree().change_scene_to_file("res://levels/main_menu.tscn")
		await _frames(4)
		var menu: Control = get_tree().current_scene
		menu.fit_height = 720.0
		var pages: Array = [["modo", menu._page_mode], ["oferta del tutorial", menu._page_tutorial_offer], ["opciones", menu._page_audio], ["vehículos", menu._page_vehicles]]
		GameSession.mode = GameSession.Mode.STORY
		pages.append(["bando", menu._page_faction])
		for faction in [Fronts.Faction.ALLIES, Fronts.Faction.AXIS]:
			pages.append(["frente (bando %d)" % faction, func() -> void:
				GameSession.faction = faction
				menu._page_front()])
			for front in [Fronts.Id.NORMANDY, Fronts.Id.AFRICA, Fronts.Id.KURSK]:
				GameSession.faction = faction
				GameSession.front_choice = front
				for i in GameSession.missions().size():
					pages.append(["parte de misión %d (bando %d, frente %d)" % [i + 1, faction, front], func() -> void:
						GameSession.faction = faction
						GameSession.front_choice = front
						menu._page_briefing(i)])
		# Supervivencia y captura la bandera: pantalla previa con el clima.
		for mode: int in [GameSession.Mode.SURVIVAL, GameSession.Mode.CTF]:
			for front in [Fronts.Id.NORMANDY, Fronts.Id.AFRICA, Fronts.Id.KURSK]:
				pages.append(["inicio (modo %d, frente %d)" % [mode, front], func() -> void:
					GameSession.mode = mode
					GameSession.faction = Fronts.Faction.ALLIES
					GameSession.front_choice = front
					menu._page_start()])
		# Partes de misión ya superada con premium: llevan además el selector de tanque.
		var saved: Dictionary = _unlock_everything()
		for faction in [Fronts.Faction.ALLIES, Fronts.Faction.AXIS]:
			for front in [Fronts.Id.NORMANDY, Fronts.Id.AFRICA, Fronts.Id.KURSK]:
				for i in Campaign.PER_CAMPAIGN:
					pages.append(["parte de misión superada %d (bando %d, frente %d)" % [i + 1, faction, front], func() -> void:
						GameSession.mode = GameSession.Mode.STORY
						GameSession.faction = faction
						GameSession.front_choice = front
						menu._page_briefing(i)])
		var too_tall: int = 0
		var worst: float = 0.0
		for page: Array in pages:
			(page[1] as Callable).call()
			await _frames(5)
			var needed: float = menu.needed_height()
			worst = maxf(worst, needed)
			if needed > 720.0:
				too_tall += 1
				print("FIT MAL «%s» necesita %d de alto y la pantalla tiene 720" % [page[0], roundi(needed)])
		_restore_progress(saved)
		print("FIT RESULT páginas del menú que no caben en pantalla: %d de %d (la más alta: %d de 720)" % [too_tall, pages.size(), roundi(worst)])
		# Diagnóstico oculto de los anuncios: cinco toques seguidos en el título lo enseñan y otros
		# cinco lo quitan; cuatro no hacen nada. El texto dice el estado y cuándo toca el próximo.
		menu._page_mode()
		await _frames(2)
		var tap := InputEventMouseButton.new()
		tap.button_index = MOUSE_BUTTON_LEFT
		tap.pressed = true
		var bad_diag: int = 0
		for i in 4:
			menu._on_title_input(tap)
		if menu._ads_overlay != null:
			bad_diag += 1
		menu._on_title_input(tap)
		await _frames(2)
		if menu._ads_overlay == null or menu._ads_overlay.text != Ads.debug_status() or Ads.debug_status() == "":
			bad_diag += 1
		for i in 5:
			menu._on_title_input(tap)
		await _frames(2)
		if menu._ads_overlay != null:
			bad_diag += 1
		var status: String = Ads._status_text()
		if status.count("\n") < 2 or not status.contains(Ads.STATE_NAMES[Ads.state]) or not status.contains("próximo intersticial: tras"):
			bad_diag += 1
		print("ADS diagnóstico: «%s»" % status.replace("\n", " / "))
		print("ADS DIAG RESULT fallos del diagnóstico oculto de anuncios: ", bad_diag)

	## Para probar lo que solo se ve con todo superado y con premium: lo activa y devuelve lo que
	## había, para dejarlo luego como estaba con _restore_progress().
	func _unlock_everything() -> Dictionary:
		var saved: Dictionary = {"premium": Premium.is_premium(), "progress": FileAccess.get_file_as_string(GameSession.PROGRESS_PATH) if FileAccess.file_exists(GameSession.PROGRESS_PATH) else ""}
		Premium.set_premium(true)
		var cfg := ConfigFile.new()
		cfg.load(GameSession.PROGRESS_PATH)
		for faction in 2:
			for front in 3:
				cfg.set_value("campaign", "f%d_c%d" % [faction, front], Campaign.PER_CAMPAIGN)
		cfg.save(GameSession.PROGRESS_PATH)
		return saved

	func _restore_progress(saved: Dictionary) -> void:
		Premium.set_premium(saved["premium"])
		var file := FileAccess.open(GameSession.PROGRESS_PATH, FileAccess.WRITE)
		file.store_string(saved["progress"])
		file.close()

	func _menu() -> void:
		if not GameSession.tutorial_offered():
			# Primera vez que se abre el juego: se ofrece el tutorial.
			get_tree().change_scene_to_file("res://levels/main_menu.tscn")
			await _frames(3)
			await get_tree().create_timer(2.0).timeout
			await _snap("menu_oferta_tutorial")
			GameSession.mark_tutorial("offered")
		get_tree().change_scene_to_file("res://levels/main_menu.tscn")
		await _frames(3)
		await get_tree().create_timer(2.0).timeout
		await _snap("menu")

	## Bandera de idioma del menú: cerrada, con la lista abierta y con el menú en cada idioma.
	func _flags() -> void:
		GameSession.mark_tutorial("offered")
		get_tree().change_scene_to_file("res://levels/main_menu.tscn")
		await _frames(3)
		await get_tree().create_timer(1.5).timeout
		var menu: Node = get_tree().current_scene
		await _snap("flags_menu")
		menu._flag_list.visible = true
		await _frames(2)
		await _snap("flags_lista")
		for code: String in Loc.LANGUAGES:
			menu._pick_language(code)
			await _frames(3)
			await _snap("flags_menu_" + code)
			menu._page_audio()
			await _frames(3)
			await _snap("flags_opciones_" + code)
			menu._page_mode()
			await _frames(2)
		GameSettings.set_language("es")

	func _start_tutorial() -> TutorialMode:
		GameSession.mode = GameSession.Mode.TUTORIAL
		GameSession.faction = Fronts.Faction.ALLIES
		GameSession.front_choice = Fronts.Id.NORMANDY
		GameSettings.ensure_loaded()
		GameSettings.camera_view = 0
		get_tree().change_scene_to_file("res://levels/arena.tscn")
		await _frames(4)
		return get_tree().current_scene.get_node("GameMode") as TutorialMode

	## Recorre las quince lecciones haciendo en cada una la acción correcta. Falla si alguna
	## no se completa. Sin gráficos y a cámara rápida.
	func _tutorial() -> void:
		var before: Array = [GameSettings.easy_drive, GameSettings.aim_assist, GameSettings.auto_recenter]
		var mode: TutorialMode = await _start_tutorial()
		if mode == null:
			print("TUTORIAL RESULT lecciones sin completar: no arranca el modo")
			return
		var bot: Node = load("res://tools/verify/tutorial_bot.gd").new()
		add_child(bot)
		bot.setup(mode)
		Engine.time_scale = 4.0
		var waited: float = 0.0
		while is_instance_valid(mode) and not mode.finished and waited < 900.0:
			await get_tree().create_timer(1.0, true, false, true).timeout
			waited += 1.0
		Engine.time_scale = 1.0
		var missing: int = bot.done.count(false)
		print("TUTORIAL completado: ", mode.finished, " | guardado en el progreso: ", GameSession.tutorial_completed(), " | resumen visible: ", mode.overlay._end != null)
		bot.queue_free()
		get_tree().change_scene_to_file("res://levels/main_menu.tscn")
		await _frames(4)
		var restored: bool = before == [GameSettings.easy_drive, GameSettings.aim_assist, GameSettings.auto_recenter]
		print("TUTORIAL ajustes del jugador restaurados al salir: ", "OK" if restored else "MAL")
		if not mode_ok(missing, restored):
			missing = maxi(missing, 1)
		print("TUTORIAL RESULT lecciones sin completar: ", missing)

	func mode_ok(missing: int, restored: bool) -> bool:
		return missing == 0 and restored and GameSession.tutorial_completed()

	## Guerra en el cielo: muchas formaciones seguidas con un avión condenado en cada una.
	## Ningún derribado puede caer dentro del campo de batalla.
	func _sky() -> void:
		await _new_stage(Fronts.Id.KURSK)
		var sky := SkyWar.new()
		sky.front = Fronts.Id.KURSK
		_stage.add_child(sky)
		var models: Dictionary = {}
		# Tanques de pega repartidos por el campo: ningún derribo puede caerles encima.
		var rng := RandomNumberGenerator.new()
		rng.seed = 11
		for i in 14:
			var dummy := Node3D.new()
			dummy.add_to_group(&"tanks")
			_stage.add_child(dummy)
			dummy.global_position = Vector3(rng.randf_range(-170.0, 170.0), 0.0, rng.randf_range(-170.0, 170.0))
		Engine.time_scale = 6.0
		for i in 48:
			sky.front = i % 3
			sky.launch(i % 2, -1, true, 0)
			models[sky.last_model] = true
			await get_tree().create_timer(4.0).timeout
		await get_tree().create_timer(40.0).timeout
		Engine.time_scale = 1.0
		# Blancos de la fase antiaérea y aviones de bombardeo, de los dos bandos y en los tres frentes.
		var targets: Array[String] = []
		var strikes: Array[String] = []
		for front in 3:
			for faction in 2:
				GameSession.front = front
				GameSession.faction = faction
				for kind in 3:
					var target: AirTarget = AirTarget.spawn(_stage, kind, Vector3.ZERO)
					targets.append(target.model)
					target.health.apply_damage(1000.0, null)
				for hostile in [false, true]:
					strikes.append(Aircraft.fly_over(_stage, Vector3.ZERO, hostile).model)
		await get_tree().create_timer(6.0).timeout
		print("SKY blancos de la fase antiaérea: ", targets)
		print("SKY aviones de bombardeo: ", strikes)
		print("SKY modelos vistos: ", models.keys())
		print("SKY RESULT derribos sobre tanques: %d de %d (dentro del campo, a la vista: %d)" % [sky.crashes_on_tanks, sky.crashes, sky.crashes_inside])
		if sky.crashes < 20:
			print("SKY MAL: demasiado pocos derribos para dar la prueba por buena")
		print("SKY bombas sobre el terreno lejano: %d (dentro del campo: %d)" % [sky.bombs, sky.bombs_inside])
		if sky.bombs_inside > 0:
			print("SKY MAL: una bomba de los aviones de ambiente ha caído dentro del campo")
		if sky.bombs < 9:
			print("SKY MAL: los bombarderos casi no sueltan bombas")
		if sky.crashes_inside < 5:
			print("SKY MAL: casi ningún derribo cae dentro del campo, a la vista del jugador")

	## Una formación de bombarderos bajo el fuego antiaéreo y un avión cayendo.
	func _sky_shots() -> void:
		GameSession.mode = GameSession.Mode.SURVIVAL
		GameSession.front_choice = Fronts.Id.NORMANDY
		GameSession.faction = Fronts.Faction.ALLIES
		get_tree().change_scene_to_file("res://levels/arena.tscn")
		await _frames(4)
		var arena: Node = get_tree().current_scene
		var sky: SkyWar = arena.get_node("SkyWar")
		_camera = Camera3D.new()
		_camera.far = 900.0
		arena.add_child(_camera)
		for spec in [[Fronts.Faction.ALLIES, 4, "sky_b17"], [Fronts.Faction.AXIS, 0, "sky_bf109"]]:
			var formation: Dictionary = sky.launch(spec[0], spec[1], true, 1)
			formation["doom_at"] = -40.0
			var leader: Variant = formation["planes"][0]
			var dir: Vector3 = formation["dir"]
			while is_instance_valid(leader) and leader.global_position.dot(dir) < -150.0:
				await get_tree().create_timer(0.3).timeout
			if not is_instance_valid(leader):
				continue
			_look(Vector3(0.0, 3.0, 0.0), leader.global_position, 28.0)
			await _snap(spec[2] + "_formacion")
			var waited: float = 0.0
			var victim: Variant = formation["doomed"]
			while is_instance_valid(victim) and not victim.falling and waited < 12.0:
				await get_tree().create_timer(0.2).timeout
				waited += 0.2
			await get_tree().create_timer(1.6).timeout
			if is_instance_valid(victim):
				_look(Vector3(0.0, 3.0, 0.0), victim.global_position, 28.0)
				await _snap(spec[2] + "_derribo")
		# Fase antiaérea: un caza, un avión de ataque y un bombardero enemigos.
		var shown: Array[AirTarget] = []
		for kind in 3:
			var target: AirTarget = AirTarget.spawn(arena, kind, Vector3.ZERO)
			target._velocity = Vector3.ZERO
			target.global_position = Vector3(-22.0 + kind * 22.0, 30.0, -70.0)
			target.rotation = Vector3(0.0, PI * 0.5, 0.0)
			shown.append(target)
		_look(Vector3(0.0, 3.0, 0.0), Vector3(0.0, 30.0, -70.0), 50.0)
		await _snap("sky_fase_antiaerea")
		for target in shown:
			target.queue_free()
		var flight: Aircraft = Aircraft.fly_over(arena, Vector3(0.0, 0.0, -60.0), false)
		await get_tree().create_timer(2.6).timeout
		_look(Vector3(0.0, 3.0, 0.0), flight.global_position, 40.0)
		await _snap("sky_bombardeo_aliado")
		_look(Vector3(0.0, 3.0, 0.0), Vector3(0.0, 70.0, -200.0), 70.0)
		for i in 4:
			sky._distant_barrage()
		await get_tree().create_timer(1.3).timeout
		await _snap("sky_antiaerea_lejana")

	## Aspecto de varias lecciones, con la interfaz real.
	func _tutorial_shots() -> void:
		var mode: TutorialMode = await _start_tutorial()
		await get_tree().create_timer(2.0).timeout
		await _snap("tutorial_01_mover")
		for spec in [[2, "tutorial_03_torreta"], [3, "tutorial_04_disparo"], [6, "tutorial_07_radar"], [8, "tutorial_09_fijar"], [11, "tutorial_12_avion"], [13, "tutorial_14_dano"], [14, "tutorial_15_final"]]:
			mode.goto_lesson(spec[0])
			if spec[0] == 11:
				mode.player.set_binoculars(true)
			await get_tree().create_timer(1.5).timeout
			await _snap(spec[1])
		mode.player.set_binoculars(false)
		mode.goto_lesson(TutorialMode.LESSONS.size())
		await get_tree().create_timer(1.0).timeout
		await _snap("tutorial_resumen")

	## Datos de la campaña: todas las listas completas y con sus campos.
	func _campaign() -> void:
		var total: int = 0
		for faction in 2:
			for choice in 3:
				var list: Array[Dictionary] = Campaign.missions(faction, choice)
				var expected: int = Campaign.PER_CAMPAIGN
				if list.size() != expected:
					push_error("Campaña %d/%d: %d misiones, se esperaban %d" % [faction, choice, list.size(), expected])
				for mission in list:
					total += 1
					for key in ["title", "type", "briefing", "front"]:
						if not mission.has(key):
							push_error("Misión sin «%s»: %s" % [key, mission])
					if not mission["type"] in ["assault", "destroy", "sabotage", "defend", "boss", "liberate", "breakthrough", "sink"]:
						push_error("Tipo de misión desconocido: %s" % mission["type"])
		print("CAMPAIGN OK ", total)
		# Premium: en cada campaña, exactamente tres misiones gratuitas (por frente).
		var bad_premium: int = 0
		for size in [Campaign.PER_CAMPAIGN]:
			var free: int = 0
			for i in size:
				if Premium.mission_is_free(i):
					free += 1
			if free != Premium.FREE_MISSIONS_PER_FRONT:
				bad_premium += 1
		print("PREMIUM RESULT campañas con un reparto de gratuitas incorrecto: ", bad_premium)
		# Anuncios: el desbloqueo por recompensado abre solo esa misión y se puede retirar; sin Android
		# no hay anuncios y la pausa publicitaria termina enseguida, siempre una vez por llamada.
		var bad_ads: int = 0
		GameSession.faction = Fronts.Faction.ALLIES
		GameSession.front_choice = Fronts.Id.NORMANDY
		GameSession.clear_reward_unlock()
		if not Premium.is_premium():
			if not GameSession.mission_locked(4):
				bad_ads += 1
			GameSession.grant_reward_unlock(4)
			if GameSession.mission_locked(4) or not GameSession.mission_locked(5):
				bad_ads += 1
			GameSession.clear_reward_unlock()
			if not GameSession.mission_locked(4):
				bad_ads += 1
		var calls: Array[int] = [0]
		for i in 5:
			Ads.interstitial_then(func() -> void: calls[0] += 1)
		if calls[0] != 5 or Ads.active() or Ads.rewarded_offered():
			bad_ads += 1
		print("ADS RESULT fallos de anuncios y desbloqueo: ", bad_ads)

	## Trazados (sin gráficos): arranca las 48 misiones de la historia, cada una con su mapa, y
	## comprueba que todo sigue siendo accesible (objetivos, premios, tanques) con ríos, pueblos y
	## trincheras, y que nada ha quedado metido en un río.
	func _maps() -> void:
		var before: int = _unreachable
		var wet: int = 0
		var rivers: int = 0
		var towns: int = 0
		for faction in 2:
			for front in 3:
				for index in Campaign.PER_CAMPAIGN:
					GameSession.mode = GameSession.Mode.STORY
					GameSession.faction = faction
					GameSession.front_choice = front
					GameSession.mission_index = index
					GameSettings.ensure_loaded()
					get_tree().change_scene_to_file("res://levels/arena.tscn")
					await _frames(3)
					await get_tree().create_timer(2.0).timeout
					var arena: Node = get_tree().current_scene
					var mode: StoryMode = arena.get_node("GameMode") as StoryMode
					var houses: int = 0
					var sunk: int = 0
					for child in arena.get_children():
						if child is Destructible and not child.indestructible and child.size_hint >= 3.0:
							houses += 1
						if (child is Destructible or child is Tank) and absf(child.global_position.x) < 200.0 and absf(child.global_position.z) < 200.0 and Water.deep_at(child.global_position.x, child.global_position.z):
							sunk += 1
							print("MAPA MAL en el agua: ", child.name, " ", child.global_position)
					var crossings: int = 0
					for course in Water.courses():
						crossings += course.crossings.size()
						if course.kind == Water.Kind.RIVER:
							rivers += 1
					if houses >= 16:
						towns += 1
					wet += sunk
					print("MAPA %s | trazado «%s» | edificios %d | cauces %d, pasos %d | enemigos %d" % [mode.mission["title"], mode.map_layout(), houses, Water.courses().size(), crossings, mode.alive])
					_check_reach(mode)
		print("MAPAS RESULT inaccesibles: %d | en el agua: %d | misiones con río: %d | con pueblo: %d" % [_unreachable - before, wet, rivers, towns])
		_unreachable = before

	## Ríos (sin gráficos): en una misión con río, los aliados reciben la orden de ir al otro
	## lado y tienen que llegar todos por los puentes o el vado; y un tanque que empuja de frente
	## contra el río, lejos de todo paso, no puede cruzarlo.
	func _rivers() -> void:
		GameSession.debug_weather = Weather.Kind.SUNNY
		await _start_game(GameSession.Mode.STORY, Fronts.Id.KURSK, Fronts.Faction.AXIS, Weather.Kind.SUNNY, 1, 6)
		var arena: Node = get_tree().current_scene
		var mode: StoryMode = arena.get_node("GameMode") as StoryMode
		mode.set_process(false)
		mode.raid_interval = Vector2.ZERO
		var river: Water.Course = null
		for course in Water.courses():
			if course.kind == Water.Kind.RIVER:
				river = course
		if river == null:
			print("RIO RESULT fallos: la misión no tiene río")
			return
		# Fuera los enemigos (destruidos, no borrados: puede haber disparos suyos en el aire).
		for tank in get_tree().get_nodes_in_group(&"tanks"):
			if tank.team != GameMode.PLAYER_TEAM:
				tank.health.apply_damage(99999.0, null)
		await _frames(3)
		await get_tree().create_timer(1.5).timeout
		var river_z: float = Ribbon.point_at(river.points, Ribbon.lengths(river.points)[river.points.size() - 1] * 0.5).y
		var allies: Array = _allies_alive()
		for i in allies.size():
			var brain: AIBrain = (allies[i] as Tank).get_node("AIBrain")
			brain.hunt = false
			brain.focus_objective = true
			brain.objective = Vector3(-90.0 + i * 45.0, 0.0, river_z - 70.0)
			brain.objective_radius = 2.0
		# El jugador, sin nadie al mando, empuja hacia el norte hasta dar con el río lejos de los pasos.
		var pusher: Tank = mode.player
		var away: float = 0.0
		for x: float in [150.0, -150.0, 40.0, -40.0, 100.0, -100.0]:
			var clear: bool = true
			for crossing in river.crossings:
				if absf((crossing["at"] as Vector2).x - x) < 30.0:
					clear = false
			if clear:
				away = x
				break
		# El cauce junto a ese punto: su línea más al norte y más al sur.
		var bank_z: float = INF
		var south_z: float = -INF
		for point in river.points:
			if absf(point.x - away) < 25.0:
				bank_z = minf(bank_z, point.y)
				south_z = maxf(south_z, point.y)
		pusher.global_position = Vector3(away, 0.2, south_z + river.half_width + 7.0)
		pusher.rotation.y = 0.0
		arena.get_node("PlayerInputSource").set_process(false)
		arena.get_node("PlayerInputSource").set_physics_process(false)
		Engine.time_scale = 4.0
		var clock: float = 0.0
		var crossed: Dictionary = {}
		var pusher_min: float = INF
		while clock < 150.0 and crossed.size() < allies.size():
			await get_tree().physics_frame
			clock += get_physics_process_delta_time()
			pusher.drive_input = Vector2(0.0, 1.0)
			pusher_min = minf(pusher_min, pusher.global_position.z)
			for ally: Tank in allies:
				if is_instance_valid(ally) and not crossed.has(ally) and ally.global_position.z < river_z - 45.0:
					crossed[ally] = clock
		Engine.time_scale = 1.0
		for ally: Tank in allies:
			print("RIO %s: %s" % [ally.stats.display_name, ("cruza en %.0f s" % crossed[ally]) if crossed.has(ally) else ("NO CRUZA, se queda en %s" % _xz(ally.global_position))])
		var held: bool = pusher_min > bank_z - 2.0
		print("RIO el jugador empuja contra el río en x=%.0f desde z=%.1f: llega hasta z=%.1f (el cauce pasa entre z=%.1f y z=%.1f) %s" % [away, south_z + river.half_width + 7.0, pusher_min, bank_z, south_z, "y no pasa" if held else "Y LO CRUZA"])
		print("RIO RESULT fallos: %d" % ((allies.size() - crossed.size()) + (0 if held else 1) + (1 if allies.is_empty() else 0)))
		GameSession.debug_weather = -1

	## Asaltos (sin gráficos): en Operación Ciudadela, en INFERNO, el objetivo anuncia la cifra
	## real de blindados, hay tres carros atrincherados que no se mueven de su pozo y el resto
	## entra en oleadas: juntos y por el mismo lado.
	func _assaults() -> void:
		var bad: int = 0
		var old_difficulty: int = GameSettings.difficulty
		GameSettings.ensure_loaded()
		GameSettings.difficulty = 3
		await _start_game(GameSession.Mode.STORY, Fronts.Id.KURSK, Fronts.Faction.AXIS, Weather.Kind.SUNNY, 1, 0)
		var mode: StoryMode = get_tree().current_scene.get_node("GameMode") as StoryMode
		mode.raid_interval = Vector2.ZERO
		var expected: int = roundi(6 * 2 * 1.5) + 3
		if mode.remaining != expected or not mode._objective_line().contains(str(expected)):
			bad += 1
		var dug: Array[Tank] = []
		var start: Dictionary = {}
		for tank in get_tree().get_nodes_in_group(&"tanks"):
			if tank.team == GameMode.ENEMY_TEAM:
				dug.append(tank)
				start[tank] = tank.global_position
		if dug.size() != 3:
			bad += 1
		print("ASALTO objetivo: «%s» (se esperaban %d) | atrincherados al empezar: %d" % [mode._objective_line(), expected, dug.size()])
		Engine.time_scale = 4.0
		await get_tree().create_timer(6.0).timeout
		var wave: Array[Tank] = []
		for tank in get_tree().get_nodes_in_group(&"tanks"):
			if tank.team == GameMode.ENEMY_TEAM and not tank in dug:
				wave.append(tank)
		var spread: float = 0.0
		for a in wave:
			for b in wave:
				spread = maxf(spread, _flat_distance(a, b))
		if wave.size() != StoryMode.WAVE_SIZE[3] or spread > 90.0:
			bad += 1
		print("ASALTO primera oleada: %d carros, a %.0f m como mucho unos de otros" % [wave.size(), spread])
		await get_tree().create_timer(40.0).timeout
		Engine.time_scale = 1.0
		var moved: float = 0.0
		for tank in dug:
			if is_instance_valid(tank) and not tank.is_destroyed:
				moved = maxf(moved, (tank.global_position - (start[tank] as Vector3)).length())
		if moved > 3.0:
			bad += 1
		var alive: int = 0
		for tank in get_tree().get_nodes_in_group(&"tanks"):
			if tank.team == GameMode.ENEMY_TEAM and not tank.is_destroyed:
				alive += 1
		if alive > StoryMode.WAVE_ALIVE[3] + 3:
			bad += 1
		print("ASALTO a los 46 s: los atrincherados se han movido %.1f m como mucho | enemigos vivos %d (tope %d sueltos + 3 en posición)" % [moved, alive, StoryMode.WAVE_ALIVE[3]])
		print("ASALTO RESULT fallos: ", bad)
		GameSettings.difficulty = old_difficulty
		GameSession.debug_weather = -1

	## Pantalla de carga: al entrar en una partida como lo hace el menú, la pantalla tapa el
	## montaje del campo (por pasos, con el árbol en pausa), se retira al acabar y deja la
	## partida en marcha (o la entrada aérea, en la historia). Con gráficos (CARGA_FOTOS) guarda
	## la pantalla a tres tamaños.
	func _loading() -> void:
		var bad: int = 0
		if OS.get_environment("CARGA_FOTOS") != "":
			for shape: Vector2i in [Vector2i(1280, 720), Vector2i(2340, 1080), Vector2i(1024, 768)]:
				get_window().size = shape
				await _frames(3)
				var art := LoadingArt.new()
				art.title = "EL PUERTO DE TOBRUK"
				art.set_anchors_preset(Control.PRESET_FULL_RECT)
				var layer := CanvasLayer.new()
				layer.layer = 90
				get_tree().root.add_child(layer)
				layer.add_child(art)
				art.goal = 0.62
				for moment in 2:
					await get_tree().create_timer(1.1).timeout
					await _snap("carga_%dx%d_%d" % [shape.x, shape.y, moment])
				layer.queue_free()
			get_window().size = Vector2i(1280, 720)
			await _frames(3)
		for story: bool in [true, false]:
			GameSession.mode = GameSession.Mode.STORY if story else GameSession.Mode.SURVIVAL
			GameSession.front_choice = Fronts.Id.KURSK
			GameSession.faction = Fronts.Faction.ALLIES
			GameSession.mission_index = 1
			GameSession.debug_weather = Weather.Kind.SUNNY
			GameSession.skip_intro = false
			Loading.open(get_tree(), "res://levels/arena.tscn", "PRUEBA")
			await _frames(2)
			var shown: bool = Loading.current != null and get_tree().paused
			var frames: int = 0
			var steps: int = 0
			var last: float = -1.0
			while Loading.current != null and frames < 2000:
				if Loading.current._art.goal != last:
					last = Loading.current._art.goal
					steps += 1
				await _frames(1)
				frames += 1
			GameSession.skip_intro = true
			await _frames(3)
			var arena: Node = get_tree().current_scene
			var mode: GameMode = arena.get_node_or_null("GameMode")
			var built: bool = mode != null and mode.player != null and arena.get_node_or_null("TrackMarks") != null and arena._hud != null
			var intro: Node = arena.get_node_or_null("IntroFlight")
			# En la historia sigue en pausa con la entrada aérea; en los demás modos, ya se juega.
			var running: bool = (intro != null and get_tree().paused) if story else (intro == null and not get_tree().paused)
			if not shown or not built or not running or steps < 6:
				bad += 1
			print("CARGA %s: pantalla puesta y árbol en pausa: %s | pasos repintados: %d | campo montado: %s | %s: %s" % ["historia" if story else "supervivencia", "sí" if shown else "NO", steps, "sí" if built else "NO", "empieza la entrada aérea" if story else "la partida arranca", "sí" if running else "NO"])
			if intro != null:
				(intro as IntroFlight).finish()
			get_tree().paused = false
			await _frames(2)
		print("CARGA RESULT fallos: ", bad)
		GameSession.debug_weather = -1

	## Con un objetivo fijado y la cámara por detrás del tanque, la mira naranja queda sobre el
	## objetivo (no por encima de él, en lo que haya detrás) y no tiembla.
	## Cañonazo y explosión: con el ajuste encendido suenan las grabaciones reales y, apagado, los
	## de siempre; el interruptor de la pausa lo cambia, lo guarda y deja oír la muestra en pausa.
	func _real_guns() -> void:
		var bad: int = 0
		var was: bool = GameSettings.real_guns
		var hud: Hud = await _start_game(GameSession.Mode.SURVIVAL, Fronts.Id.KURSK, Fronts.Faction.ALLIES, Weather.Kind.SUNNY, 1)
		var lengths_ok: bool = absf(Sfx.CANNON_REAL.get_length() - 1.15) < 0.1 and absf(Sfx.EXPLOSION_REAL.get_length() - 2.8) < 0.1
		if not lengths_ok:
			bad += 1
		print("SONIDO duraciones: cañonazo real %.2f s, explosión real %.2f s: %s" % [Sfx.CANNON_REAL.get_length(), Sfx.EXPLOSION_REAL.get_length(), "bien" if lengths_ok else "MAL"])
		for on: bool in [true, false]:
			GameSettings.real_guns = on
			var before: int = get_tree().current_scene.get_child_count()
			Sfx.play_2d(hud, Sfx.CANNON)
			Sfx.play_at(hud, Sfx.EXPLOSION, Vector3.ZERO)
			Sfx.play_2d(hud, Sfx.HIT)
			var streams: Array = []
			for i: int in range(before, get_tree().current_scene.get_child_count()):
				streams.append(get_tree().current_scene.get_child(i).get("stream"))
			var want: Array = [Sfx.CANNON_REAL if on else Sfx.CANNON, Sfx.EXPLOSION_REAL if on else Sfx.EXPLOSION, Sfx.HIT]
			var ok: bool = streams == want
			if not ok:
				bad += 1
			print("SONIDO ajuste %s: cañonazo %s, explosión %s, impacto sin cambios %s: %s" % ["encendido" if on else "apagado", "real" if streams[0] == Sfx.CANNON_REAL else "de siempre", "real" if streams[1] == Sfx.EXPLOSION_REAL else "de siempre", "sí" if streams[2] == Sfx.HIT else "NO", "bien" if ok else "MAL"])
		# El interruptor del menú de pausa.
		var toggle: CheckButton = null
		for entry: Array in hud._menu_toggles:
			if (entry[0] as CheckButton).text == Loc.t("Cañón y explosiones reales (prueba)"):
				toggle = entry[0]
		GameSettings.real_guns = false
		if toggle != null:
			toggle.set_pressed_no_signal(false)
		hud._set_paused(true)
		await _frames(2)
		var shown: bool = toggle != null and toggle.is_visible_in_tree()
		var root_before: int = get_tree().root.get_child_count()
		if toggle != null:
			toggle.button_pressed = not toggle.button_pressed
		await _frames(3)
		var samples: int = 0
		var playing: int = 0
		for i: int in range(root_before, get_tree().root.get_child_count()):
			var node := get_tree().root.get_child(i) as AudioStreamPlayer
			if node != null and node.process_mode == Node.PROCESS_MODE_ALWAYS:
				samples += 1
				playing += int(node.playing)
		var cfg := ConfigFile.new()
		cfg.load(GameSettings.PATH)
		var saved: bool = cfg.get_value("audio", "real_guns", null) == GameSettings.real_guns
		var switch_ok: bool = shown and GameSettings.real_guns and samples == 2 and playing >= 1 and saved
		if not switch_ok:
			bad += 1
		print("SONIDO interruptor de la pausa: visible %s, lo enciende %s, guardado %s, muestras %d (sonando en pausa %d): %s" % ["sí" if shown else "NO", "sí" if GameSettings.real_guns else "NO", "sí" if saved else "NO", samples, playing, "bien" if switch_ok else "MAL"])
		hud._set_paused(false)
		GameSettings.real_guns = was
		GameSettings.save()
		print("SONIDO RESULT fallos: ", bad)
		GameSession.debug_weather = -1

	func _lock_reticle() -> void:
		var bad: int = 0
		for view: int in [1, 2]:
			var hud: Hud = await _start_game(GameSession.Mode.SURVIVAL, Fronts.Id.KURSK, Fronts.Faction.ALLIES, Weather.Kind.SUNNY, view)
			var mode: SurvivalMode = get_tree().current_scene.get_node("GameMode")
			mode.raid_interval = Vector2.ZERO
			mode.set_process(false)
			var player: Tank = mode.player
			player.health.invulnerable = true
			var enemy: Tank = mode.spawn_tank(Fronts.tank("panzer4"), GameMode.ENEMY_TEAM, Vector2(player.global_position.x + 7.0, player.global_position.z - 70.0), 1.1)
			enemy.get_node("AIBrain").queue_free()
			await _frames(3)
			GameSettings.aim_assist = false
			hud.input_source._voice_lock = true
			player.aim_lock = enemy
			await get_tree().create_timer(2.5).timeout
			var worst: float = 0.0
			var shake: float = 0.0
			var last: Vector2 = hud._reticle_at
			for i in 60:
				await _frames(1)
				var on_target: Vector2 = player.camera.unproject_position(enemy.global_position + Vector3.UP * 1.2 * enemy.stats.body_scale)
				worst = maxf(worst, hud._reticle_at.distance_to(on_target))
				shake = maxf(shake, hud._reticle_at.distance_to(last))
				last = hud._reticle_at
			# Como se calculaba antes (lo primero que tocaba la línea del cañón, sin contar los
			# tanques, o un punto a 250 m): solo para dejar constancia de cuánto se iba.
			var muzzle: Vector3 = player.muzzle.global_position
			var far: Vector3 = muzzle - player.muzzle.global_transform.basis.z * 250.0
			var old_hit: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(muzzle, far, 1 | Terrain.LAYER))
			var old_point: Vector3 = old_hit["position"] if not old_hit.is_empty() else far
			var before: float = player.camera.unproject_position(old_point).distance_to(player.camera.unproject_position(enemy.global_position + Vector3.UP * 1.2 * enemy.stats.body_scale))
			var ok: bool = worst < 26.0 and shake < 2.5
			if not ok:
				bad += 1
			print("MIRA vista %d: la mira fijada se separa del objetivo como mucho %.1f px y tiembla %.2f px por cuadro (con el cálculo de antes quedaba a %.0f px): %s" % [view, worst, shake, before, "bien" if ok else "MAL"])
		print("MIRA RESULT fallos: ", bad)
		GameSettings.aim_assist = true
		GameSession.debug_weather = -1

	## Supervivencia y captura la bandera junto al mar: el campo se monta con su playa, nadie
	## entra por el lado del agua y, en captura la bandera, el mar queda a un lado (las bases
	## siguen al norte y al sur). En Kursk no hay costa aunque se pida.
	func _coast() -> void:
		var bad: int = 0
		for case: Array in [[GameSession.Mode.SURVIVAL, Fronts.Id.NORMANDY, "s", Vector2(0.0, 1.0)], [GameSession.Mode.SURVIVAL, Fronts.Id.AFRICA, "n", Vector2(0.0, -1.0)], [GameSession.Mode.CTF, Fronts.Id.NORMANDY, "e", Vector2(1.0, 0.0)], [GameSession.Mode.CTF, Fronts.Id.AFRICA, "n", Vector2(1.0, 0.0)], [GameSession.Mode.SURVIVAL, Fronts.Id.KURSK, "s", Vector2.ZERO]]:
			GameSession.debug_coast = case[2]
			await _start_game(case[0], case[1], Fronts.Faction.ALLIES, Weather.Kind.SUNNY, 1)
			GameSession.debug_coast = "none"
			var arena: Node = get_tree().current_scene
			var mode: GameMode = arena.get_node("GameMode")
			var side: Vector2 = Backdrop.sea_side
			var wet: int = 0
			for i in 60:
				var point: Vector2 = mode.edge_point()
				if side != Vector2.ZERO and point.dot(side) > GameMode.EDGE - 2.0:
					wet += 1
			var sea_built: bool = (arena.get_node_or_null("Ambience/Sea") != null) == (side != Vector2.ZERO)
			var ok: bool = side == case[3] and wet == 0 and sea_built and mode.player != null
			if not ok:
				bad += 1
			print("COSTA %s en %s, pedida «%s»: mar hacia %s | entradas por el lado del mar: %d de 60 | %s" % ["supervivencia" if case[0] == GameSession.Mode.SURVIVAL else "captura la bandera", Fronts.NAMES[case[1]], case[2], str(side), wet, "bien" if ok else "MAL"])
		print("COSTA RESULT fallos: ", bad)
		GameSession.debug_weather = -1

	## Supervivencia: el ataque aéreo llega solo cada tres oleadas y no de golpe (hay un respiro
	## tras el «oleada superada»). Entonces la vista pasa del tanque a una batería antiaérea en
	## un sitio despejado, sin cámara lenta; sus disparos derriban los aviones; con tres
	## derribos se repone el bombardeo; al acabar, la vista vuelve al tanque. Con gráficos
	## (AEREO_FOTOS) guarda la batería, la vista del apuntador y un derribo.
	func _air_phase() -> void:
		var bad: int = 0
		var photos: bool = OS.get_environment("AEREO_FOTOS") != ""
		await _start_game(GameSession.Mode.SURVIVAL, Fronts.Id.NORMANDY, Fronts.Faction.ALLIES, Weather.Kind.SUNNY, 1)
		var arena: Node = get_tree().current_scene
		var mode: SurvivalMode = arena.get_node("GameMode")
		mode.raid_interval = Vector2.ZERO
		mode.player.health.invulnerable = true
		var phases: Array[int] = []
		for wave in range(1, 7):
			mode.wave = wave
			mode._wave_active = true
			mode.strikes = 0
			mode._end_wave()
			var at_once: bool = mode.air_phase
			await get_tree().create_timer(SurvivalMode.AIR_WARNING + 0.4).timeout
			if at_once:
				bad += 1
			if not mode.air_phase:
				continue
			phases.append(wave)
			var battery: AaBattery = mode._battery
			var placed: bool = battery != null and AaBattery.active == battery and Engine.time_scale == 1.0
			var gap: float = Vector2(battery.global_position.x - mode.player.global_position.x, battery.global_position.z - mode.player.global_position.z).length() if battery != null else 0.0
			# Nada pisa el pozo: ni un tanque ni un obstáculo del campo.
			var clear: bool = gap > AaBattery.RADIUS + 4.0 and absf(battery.global_position.x) < 180.0 and absf(battery.global_position.z) < 180.0
			await get_tree().create_timer(AaBattery.MOVE_IN + 0.3).timeout
			var seated: bool = battery.ready() and get_viewport().get_camera_3d() == battery.camera and battery.camera.global_position.distance_to(battery.global_position) < 4.0
			# Desde el puesto, el cañón se ve translúcido; y la palanca izquierda lo mueve.
			var glassy: bool = (battery._barrel.get_child(0) as MeshInstance3D).material_override == battery._ghost
			var touch: TouchControls = arena._hud.touch
			var yaw_before: float = battery._aim_yaw
			var pitch_before: float = battery._aim_pitch
			touch.move_vector = Vector2(0.8, 0.6)
			await get_tree().create_timer(0.4).timeout
			touch.move_vector = Vector2.ZERO
			var lever: bool = angle_difference(yaw_before, battery._aim_yaw) < -0.15 and battery._aim_pitch > pitch_before + 0.08
			if not glassy or not lever:
				bad += 1
				print("AEREO MAL: cañón translúcido %s | la palanca izquierda mueve la mira %s" % [glassy, lever])
			if photos and wave == 3:
				_camera = Camera3D.new()
				_camera.far = 2800.0
				arena.add_child(_camera)
				arena._hud.get_parent().visible = false
				_look(battery.global_position + Vector3(7.0, 3.2, 8.0), battery.global_position + Vector3.UP * 1.2, 50.0)
				await _snap("aereo_bateria")
				arena._hud.get_parent().visible = true
				battery.camera.current = true
				_camera.queue_free()
				await _frames(3)
			# El jugador apunta a un avión y mantiene el gatillo: los proyectiles lo derriban.
			# (La prueba lleva la mira y el gatillo en lugar de los mandos táctiles.)
			arena._hud.input_source.set_process(false)
			var plane: AirTarget = AirTarget.spawn(arena, AirTarget.Kind.BOMBER, battery.global_position, 0.6)
			var kills_before: int = mode._air_kills
			var clock: float = 0.0
			var snapped: bool = false
			while clock < 9.0 and is_instance_valid(plane) and not plane.is_destroyed:
				var to: Vector3 = plane.global_position + plane._velocity * 0.35 - battery._muzzle.global_position
				battery._aim_yaw = atan2(-to.x, -to.z)
				battery._aim_pitch = atan2(to.y, Vector2(to.x, to.z).length())
				# (Para la foto, primero sigue al avión un momento sin disparar.)
				battery.trigger = not (photos and wave == 3 and clock < 1.6)
				await _frames(1)
				clock += get_process_delta_time()
				if photos and wave == 3 and not snapped and clock > 1.2:
					snapped = true
					await _snap("aereo_mira")
			battery.trigger = false
			arena._hud.input_source.set_process(true)
			var shot_down: bool = mode._air_kills == kills_before + 1 and battery.shots > 3
			if photos and wave == 3:
				await get_tree().create_timer(0.5).timeout
				await _snap("aereo_derribo")
			# Con tres derribos se repone el bombardeo.
			while mode._air_kills < SurvivalMode.AIR_GOAL:
				mode.air_reward(Vector3.ZERO)
			var rewarded: bool = mode.strikes == 1
			mode._end_air_phase()
			await get_tree().create_timer(AaBattery.MOVE_OUT + 0.3).timeout
			var back: bool = AaBattery.active == null and get_viewport().get_camera_3d() == mode.player.camera and (battery._barrel.get_child(0) as MeshInstance3D).material_override != battery._ghost
			if not placed or not clear or not seated or not shot_down or not rewarded or not back:
				bad += 1
			print("AEREO oleada %d: batería %s a %.0f m del tanque, despejada: %s | la vista llega al apuntador: %s | derriba un avión a ráfagas (%d disparos): %s | 3 derribos reponen el bombardeo: %s | la vista vuelve al tanque: %s" % [wave, battery.gun_name, gap, "sí" if placed and clear else "NO", "sí" if seated else "NO", battery.shots, "sí" if shot_down else "NO", "sí" if rewarded else "NO", "sí" if back else "NO"])
		if phases != [3, 6]:
			bad += 1
		print("AEREO ataque aéreo tras las oleadas: %s (de 6) | nunca en el mismo instante que el fin de la oleada" % str(phases))
		print("AEREO RESULT fallos: ", bad)
		Engine.time_scale = 1.0
		GameSession.debug_weather = -1

	## Tras ganar, «SEGUIR EN EL CAMPO» cierra el menú de misión cumplida y deja jugar; el botón
	## de pausa lo devuelve, y también vuelve solo si destruyen el tanque del jugador.
	func _stay() -> void:
		var bad: int = 0
		var was_premium: bool = Premium.is_premium()
		# Sin premium, la opción sale marcada y lleva a la pantalla premium del menú.
		Premium.set_premium(false)
		await _start_game(GameSession.Mode.STORY, Fronts.Id.NORMANDY, Fronts.Faction.ALLIES, Weather.Kind.SUNNY, 1, 0)
		var free_mode: StoryMode = get_tree().current_scene.get_node("GameMode")
		var free_hud: Hud = get_tree().current_scene._hud
		free_mode.player.health.invulnerable = true
		free_mode._win("PRUEBA")
		await get_tree().create_timer(1.6).timeout
		var locked: Button = null
		for node: Node in free_hud._end_panel.find_children("*", "Button", true, false):
			if (node as Button).text == Loc.t("SEGUIR EN EL CAMPO (PREMIUM)"):
				locked = node
		GameSession.menu_page = ""
		var asked: String = ""
		var marked: bool = locked != null
		if locked != null:
			locked.pressed.emit()
			asked = GameSession.menu_page
		await _frames(4)
		# (El menú consume `menu_page` al abrirse: se mira lo que pidió el botón.)
		var to_premium: bool = marked and asked == "premium" and get_tree().current_scene.scene_file_path.ends_with("main_menu.tscn")
		if not to_premium:
			bad += 1
		print("SEGUIR sin premium la opción lleva a la pantalla premium: %s" % ("sí" if to_premium else "NO (botón %s, pide «%s», escena %s)" % [marked, asked, get_tree().current_scene.scene_file_path]))
		GameSession.menu_page = ""
		Premium.set_premium(true)
		await _start_game(GameSession.Mode.STORY, Fronts.Id.NORMANDY, Fronts.Faction.ALLIES, Weather.Kind.SUNNY, 1, 0)
		var arena: Node = get_tree().current_scene
		var mode: StoryMode = arena.get_node("GameMode")
		var hud: Hud = arena._hud
		mode.player.health.invulnerable = true
		mode._win("PRUEBA")
		await get_tree().create_timer(1.6).timeout
		var stay: Button = null
		for node: Node in hud._end_panel.find_children("*", "Button", true, false):
			if (node as Button).text == Loc.t("SEGUIR EN EL CAMPO"):
				stay = node
		var offered: bool = stay != null and hud._end_panel.visible
		if stay != null:
			stay.pressed.emit()
		await _frames(2)
		var closed: bool = not hud._end_panel.visible and not get_tree().paused
		await get_tree().create_timer(0.5).timeout
		hud._set_paused(true)
		await _frames(2)
		var back: bool = hud._end_panel.visible
		if stay != null:
			stay.pressed.emit()
		await _frames(2)
		mode.player.health.invulnerable = false
		mode.player.health.apply_damage(99999.0, null)
		await get_tree().create_timer(2.2).timeout
		var back_dead: bool = hud._end_panel.visible
		if not offered or not closed or not back or not back_dead:
			bad += 1
		print("SEGUIR la opción sale al ganar: %s | cierra el menú y la partida sigue: %s | la pausa lo devuelve: %s | vuelve solo si destruyen el tanque: %s" % ["sí" if offered else "NO", "sí" if closed else "NO", "sí" if back else "NO", "sí" if back_dead else "NO"])
		print("SEGUIR RESULT fallos: ", bad)
		Premium.set_premium(was_premium)
		GameSession.debug_weather = -1

	## La misión de hundir barcos (Tobruk): la flotilla está fondeada en el mar, fuera del campo y
	## a tiro desde la orilla; zarpan de uno en uno; los proyectiles del jugador los alcanzan y
	## los hunden; hundir los que se piden gana la misión, y dejar escapar demasiados la pierde.
	## Con gráficos (BARCOS_FOTOS) guarda la rada, un barco ardiendo y un disparo al agua.
	func _ships() -> void:
		var bad: int = 0
		var photos: bool = OS.get_environment("BARCOS_FOTOS") != ""
		var index: int = -1
		var list: Array = Campaign.DATA[Fronts.Id.AFRICA][Fronts.Faction.AXIS]
		for i in list.size():
			if list[i]["type"] == "sink":
				index = i
		if index < 0:
			print("BARCOS MAL: no hay misión de hundir barcos")
			print("BARCOS RESULT fallos: 1")
			return
		for round_kind: String in ["hundir", "escapar"]:
			await _start_game(GameSession.Mode.STORY, Fronts.Id.AFRICA, Fronts.Faction.AXIS, Weather.Kind.SUNNY, 1, index)
			var arena: Node = get_tree().current_scene
			var mode: StoryMode = arena.get_node("GameMode")
			mode.raid_interval = Vector2.ZERO
			var result: Array = [false, false]
			mode.ended.connect(func(victory: bool, _title: String, _detail: String) -> void:
				result[0] = true
				result[1] = victory)
			var fleet: Array = mode._fleet.duplicate()
			var needed: int = mode._ships_needed
			var afloat: int = 0
			for ship: Ship in fleet:
				if Backdrop.in_sea(ship.global_position.x, ship.global_position.z) and ship.global_position.z < -205.0:
					afloat += 1
			# Desde la orilla, por encima de la alambrada, se les ve y se les da: nada lo tapa.
			var space: PhysicsDirectSpaceState3D = arena.get_world_3d().direct_space_state
			var in_sight: int = 0
			for ship: Ship in fleet:
				var from := Vector3(ship.global_position.x * 0.6, 2.4, -190.0)
				var query := PhysicsRayQueryParameters3D.create(from, ship.global_position + Vector3.UP * 2.0, Projectile.MASK_WORLD | Projectile.MASK_HURTBOX | Terrain.LAYER)
				var hit: Dictionary = space.intersect_ray(query)
				if not hit.is_empty() and hit["collider"] == ship:
					in_sight += 1
			if afloat != fleet.size() or in_sight != fleet.size() or needed < 1 or needed > fleet.size():
				bad += 1
			print("BARCOS %s: %d barcos, hay que hundir %d | en el mar y fuera del campo: %d | a tiro desde la orilla: %d" % [round_kind, fleet.size(), needed, afloat, in_sight])
			var player: Tank = mode.player
			player.health.invulnerable = true
			if round_kind == "hundir":
				if photos:
					_camera = Camera3D.new()
					_camera.far = 2800.0
					arena.add_child(_camera)
					arena._hud.get_parent().visible = false
					_look(Vector3(-40.0, 9.0, -150.0), Vector3(20.0, 2.0, -330.0), 60.0)
					await _snap("barcos_rada")
				# Zarpan a su hora (se adelanta el reloj) y los proyectiles los hunden.
				mode._sail_timer = 0.2
				await get_tree().create_timer(1.0).timeout
				var first: Ship = fleet[0]
				var start: Vector3 = first.global_position
				await get_tree().create_timer(3.0).timeout
				var moved: float = first.global_position.distance_to(start)
				if not first.sailing or moved < 3.0:
					bad += 1
				print("BARCOS el primero zarpa y navega: %s (%.1f m en 3 s)" % ["sí" if first.sailing else "NO", moved])
				var sunk_by_shell: bool = false
				for n in fleet.size():
					var ship: Ship = fleet[n]
					if mode.is_over:
						break
					if n == 0:
						# Uno, a cañonazos de verdad: proyectiles desde la orilla hasta que se hunde.
						var gun := Vector3(ship.global_position.x, 2.4, -192.0)
						for shot in 30:
							if ship.is_destroyed:
								break
							var shell: Projectile = Projectile.acquire(Ship.SHELL, arena)
							shell.launch(gun, (ship.global_position + Vector3.UP * 1.5 - gun).normalized() * 180.0, 60.0, player, [], GameMode.PLAYER_TEAM)
							await get_tree().create_timer(0.9).timeout
						sunk_by_shell = ship.is_destroyed
						if photos:
							await get_tree().create_timer(2.5).timeout
							_look(Vector3(ship.global_position.x - 30.0, 7.0, -195.0), ship.global_position, 50.0)
							await _snap("barcos_hundido")
							var splash: Projectile = Projectile.acquire(Ship.SHELL, arena)
							splash.launch(gun, Vector3(0.3, -0.03, -1.0).normalized() * 180.0, 60.0, player, [], GameMode.PLAYER_TEAM)
							await get_tree().create_timer(0.75).timeout
							_look(Vector3(gun.x, 5.0, gun.z), gun + Vector3(0.3, -0.03, -1.0) * 100.0, 50.0)
							await _snap("barcos_agua")
					elif is_instance_valid(ship) and not ship.is_destroyed:
						ship.take_hit(9999.0, player, ship.global_position)
					await _frames(2)
				await _frames(4)
				if not sunk_by_shell or not result[0] or not result[1] or mode._sunk < needed:
					bad += 1
				print("BARCOS hundir: a cañonazos %s | hundidos %d | la misión acaba en victoria: %s | %s" % ["sí" if sunk_by_shell else "NO", mode._sunk, "sí" if result[0] and result[1] else "NO", mode.objective_lines()])
			else:
				# Nadie les dispara: zarpan todos (con el reloj y el andar adelantados) y escapan.
				for ship: Ship in fleet:
					ship.speed = 45.0
					ship.target = null
				mode._sail_timer = 0.1
				var waited: float = 0.0
				while not result[0] and waited < 60.0:
					mode._sail_timer = minf(mode._sail_timer, 0.3)
					await get_tree().create_timer(0.5).timeout
					waited += 0.5
				if not result[0] or result[1] or mode._escaped.size() <= fleet.size() - needed:
					bad += 1
				print("BARCOS escapar: escapados %d | la misión acaba en derrota: %s | %s" % [mode._escaped.size(), "sí" if result[0] and not result[1] else "NO", mode.objective_lines()])
			get_tree().paused = false
		print("BARCOS RESULT fallos: ", bad)
		GameSession.debug_weather = -1

	## Entrada de una misión: mientras la cámara baja desde lo alto la partida está en pausa y
	## la interfaz escondida; al acabar (sola, o al tocar la pantalla) todo vuelve a su sitio y
	## manda la cámara del tanque. Con gráficos (INTRO_FOTOS) guarda además tres momentos del vuelo.
	func _intro() -> void:
		var bad: int = 0
		for skip: bool in [false, true]:
			GameSession.skip_intro = false
			await _start_game(GameSession.Mode.STORY, Fronts.Id.NORMANDY, Fronts.Faction.ALLIES, Weather.Kind.SUNNY, 1, 0)
			GameSession.skip_intro = true
			var arena: Node = get_tree().current_scene
			var intro := arena.get_node_or_null("IntroFlight") as IntroFlight
			var hud_layer: CanvasLayer = arena._hud.get_parent()
			var player: Tank = arena.get_node("GameMode").player
			var started: bool = intro != null and get_tree().paused and not hud_layer.visible and get_viewport().get_camera_3d() != player.camera
			var height: float = get_viewport().get_camera_3d().global_position.y
			if OS.get_environment("INTRO_FOTOS") != "" and not skip:
				for moment: float in [1.2, 3.6, 5.6, 6.8]:
					await get_tree().create_timer(maxf(moment - intro._clock, 0.01)).timeout
					await _snap("intro_%02d" % roundi(moment * 10.0))
			if skip:
				await get_tree().create_timer(1.0).timeout
				var tap := InputEventScreenTouch.new()
				tap.pressed = true
				tap.position = Vector2(300.0, 300.0)
				Input.parse_input_event(tap)
				await _frames(3)
			else:
				await get_tree().create_timer(IntroFlight.DURATION + 0.6).timeout
			var ended: bool = not get_tree().paused and hud_layer.visible and get_viewport().get_camera_3d() == player.camera and arena.get_node_or_null("IntroFlight") == null
			if not started or not ended or height < 100.0:
				bad += 1
			print("INTRO %s: empieza en pausa y desde %.0f m de altura: %s | acaba con la partida en marcha y la cámara del tanque: %s" % ["saltada con un toque" if skip else "entera", height, "sí" if started else "NO", "sí" if ended else "NO"])
			get_tree().paused = false
		print("INTRO RESULT fallos: ", bad)
		GameSession.debug_weather = -1

	## Vistas del paisaje de cada frente: desde el centro del campo hacia los cuatro lados, a la
	## altura de la cámara del jugador, y una desde lo alto. FRENTE_SOLO = «bando_frente_misión»
	## (varias separadas por comas) y FRENTE_LADOS = «nesw» eligen qué se guarda.
	func _front_shots() -> void:
		var picks: Array = [[0, 0, 0], [1, 0, 1], [0, 0, 3], [1, 0, 6], [0, 1, 0], [1, 1, 0], [1, 1, 6], [0, 2, 0], [0, 2, 2], [0, 2, 7], [0, 2, 1]]
		var only: String = OS.get_environment("FRENTE_SOLO")
		if only != "":
			picks = []
			for item in only.split(","):
				picks.append([int(item.get_slice("_", 0)), int(item.get_slice("_", 1)), int(item.get_slice("_", 2))])
		var sides: String = OS.get_environment("FRENTE_LADOS")
		if sides == "":
			sides = "nesw"
		var weather: int = Weather.Kind.SUNNY if OS.get_environment("FRENTE_CLIMA") == "" else int(OS.get_environment("FRENTE_CLIMA"))
		for pick: Array in picks:
			var tag: String = "%d_%d_%d" % [pick[0], pick[1], pick[2]]
			await _start_game(GameSession.Mode.STORY, pick[1], pick[0], weather, 1, pick[2])
			var arena: Node = get_tree().current_scene
			arena.get_node("GameMode").set_process(false)
			arena.get_node("GameMode").raid_interval = Vector2.ZERO
			var hud: CanvasLayer = arena._hud.get_parent()
			hud.visible = false
			await get_tree().create_timer(1.0).timeout
			var camera := Camera3D.new()
			camera.far = 2800.0
			arena.add_child(camera)
			_camera = camera
			var eye := Vector3(0.0, 5.0, 60.0)
			for side in sides:
				var dir: Vector2 = Backdrop.SIDES[side]
				_look(eye, eye + Vector3(dir.x, 0.04, dir.y) * 100.0, 62.0)
				await _snap("frente_%s_%s" % [tag, side])
			if OS.get_environment("FRENTE_HUELLAS") != "":
				# El tanque del jugador da una vuelta y se mira el rastro que deja.
				var tank: Tank = arena.get_node("GameMode").player
				var from: Vector3 = tank.global_position
				var heading: float = 0.6
				for i in 110:
					heading += 0.012
					tank.global_position += Vector3(sin(heading), 0.0, cos(heading)) * 0.45
					tank.global_rotation.y = heading + PI
					await _frames(1)
				var back := Vector3(sin(heading), 0.0, cos(heading))
				_look(tank.global_position + back * 9.0 + Vector3.UP * 7.0, from.lerp(tank.global_position, 0.55), 62.0)
				await _snap("frente_%s_huellas" % tag)
				var marks: TrackMarks = arena.get_node("TrackMarks")
				print("HUELLAS %s: %d tramos" % [tag, marks.stamped])
			if OS.get_environment("FRENTE_ALTO") != "":
				_look(Vector3(0.0, 140.0, 330.0), Vector3(0.0, 0.0, -200.0), 60.0)
				await _snap("frente_%s_alto" % tag)
			hud.visible = true
		GameSession.debug_weather = -1

	## Vistas de los trazados nuevos: desde lo alto y a ras de suelo.
	func _map_shots() -> void:
		var picks: Array = [
			[Fronts.Faction.AXIS, Fronts.Id.NORMANDY, 5], [Fronts.Faction.ALLIES, Fronts.Id.NORMANDY, 2], [Fronts.Faction.AXIS, Fronts.Id.NORMANDY, 7],
			[Fronts.Faction.AXIS, Fronts.Id.KURSK, 0], [Fronts.Faction.AXIS, Fronts.Id.KURSK, 6], [Fronts.Faction.AXIS, Fronts.Id.KURSK, 5],
			[Fronts.Faction.ALLIES, Fronts.Id.KURSK, 5], [Fronts.Faction.ALLIES, Fronts.Id.AFRICA, 3], [Fronts.Faction.AXIS, Fronts.Id.AFRICA, 6],
			[Fronts.Faction.ALLIES, Fronts.Id.AFRICA, 1], [Fronts.Faction.ALLIES, Fronts.Id.NORMANDY, 5],
		]
		var only: String = OS.get_environment("MAPA_SOLO")
		for pick: Array in picks:
			var tag: String = "%d_%d_%d" % [pick[0], pick[1], pick[2]]
			if only != "" and only != tag:
				continue
			await _start_game(GameSession.Mode.STORY, pick[1], pick[0], Weather.Kind.SUNNY, 1, pick[2])
			var arena: Node = get_tree().current_scene
			arena.get_node("GameMode").set_process(false)
			arena.get_node("GameMode").raid_interval = Vector2.ZERO
			var hud: CanvasLayer = arena._hud.get_parent()
			hud.visible = false
			await get_tree().create_timer(1.0).timeout
			var camera := Camera3D.new()
			camera.far = 900.0
			arena.add_child(camera)
			_camera = camera
			_look(Vector3(0.0, 330.0, 150.0), Vector3(0.0, 0.0, 12.0), 62.0)
			await _snap("mapa_%s_alto" % tag)
			var focus := Vector3(0.0, 0.0, -10.0)
			for course in Water.courses():
				if not course.crossings.is_empty():
					var at: Vector2 = course.crossings[0]["at"]
					focus = Vector3(at.x, 0.0, at.y)
			_look(focus + Vector3(26.0, 9.0, 40.0), focus + Vector3(0.0, 2.0, 0.0), 60.0)
			await _snap("mapa_%s_cerca" % tag)
			# Un carro atrincherado en su pozo y, al lado, los restos de un avión derribado.
			for tank in get_tree().get_nodes_in_group(&"tanks"):
				if tank.has_meta(&"waiting"):
					var sky: SkyWar = arena.get_node("SkyWar")
					var plane: SkyWar.SkyPlane = SkyWar.make_plane(pick[1], Fronts.Faction.ALLIES, SkyWar.pick_model(pick[1], Fronts.Faction.ALLIES, ["attack", "fighter"]))
					plane.velocity = Vector3(40.0, -30.0, 25.0)
					var crash: Vector3 = tank.global_position + Vector3(16.0, 0.0, 6.0)
					sky._on_crash(crash, plane)
					plane.free()
					SkyWar.SmokeColumn.spawn(sky, crash)
					await get_tree().create_timer(2.0).timeout
					_look(tank.global_position + Vector3(-9.0, 5.0, 22.0), tank.global_position + Vector3(6.0, 1.0, 0.0), 60.0)
					await _snap("mapa_%s_pozo" % tag)
					break
			if OS.get_environment("MAPA_SUELO") != "":
				_look(Vector3(8.0, 3.2, 96.0), Vector3(0.0, 3.0, 0.0), 65.0)
				await _snap("mapa_%s_suelo" % tag)
			hud.visible = true
		GameSession.debug_weather = -1

	## Arranca una misión de la campaña y la deja correr unos segundos.
	func _story(faction: int, front: int, index: int) -> void:
		GameSession.mode = GameSession.Mode.STORY
		GameSession.faction = faction
		GameSession.front_choice = front
		GameSession.mission_index = index
		GameSettings.ensure_loaded()
		get_tree().change_scene_to_file("res://levels/arena.tscn")
		await _frames(3)
		await get_tree().create_timer(6.0).timeout
		var mode: GameMode = get_tree().current_scene.get_node("GameMode")
		var allies: int = 0
		var enemies: int = 0
		for tank in get_tree().get_nodes_in_group(&"tanks"):
			if tank.team == GameMode.PLAYER_TEAM:
				allies += 1
			else:
				enemies += 1
		print("STORY ", GameSession.current_mission()["title"], " | ", mode.status_text(), " | ", mode.objective_lines(), " | bando propio ", allies, " enemigos ", enemies)
		await _snap("story_%d_%d_%d" % [faction, front, index])
		_check_reach(mode as StoryMode)

	## Accesibilidad: desde el jugador tiene que haber ruta hasta cada objetivo, cada edificio
	## con premio, cada premio suelto y cada tanque, y nada puede quedar bajo una montaña ni
	## fuera del muro. Usa el mismo mapa de celdas con el que navegan los aliados.
	func _check_reach(mode: StoryMode) -> void:
		var arena: Node = get_tree().current_scene
		var grid := NavGrid.of(arena)
		var origin: Vector3 = mode.player.global_position
		var targets: Array[Node3D] = []
		for objective in mode._objectives:
			targets.append(objective)
		for node in get_tree().get_nodes_in_group(&"radar_marks"):
			if node is Destructible and not node in targets:
				targets.append(node)
		for tank in get_tree().get_nodes_in_group(&"tanks"):
			targets.append(tank)
		if mode.kind == "breakthrough":
			var exit_marker := Node3D.new()
			arena.add_child(exit_marker)
			exit_marker.position = StoryMode.EXIT_POINT
			targets.append(exit_marker)
		var mountains: Array[Destructible] = []
		for child in arena.get_children():
			if child is Destructible and child.indestructible:
				mountains.append(child)
		var bad: int = 0
		for target in targets:
			if target is Destructible and target.protected_area:
				continue
			# A los barcos no se llega: se les dispara desde la orilla (ver la prueba «barcos»).
			if target is Ship:
				continue
			var point: Vector3 = target.global_position
			var problem: String = ""
			if point.y < -1.0:
				problem = "hundido bajo el suelo"
			elif absf(point.x) > 196.0 or absf(point.z) > 196.0:
				problem = "fuera del muro"
			else:
				# Se puede llegar junto a él: hay ruta hasta algún punto a su alrededor (lo que
				# está pegado a un edificio o a una alambrada se alcanza por el lado libre).
				var reachable: bool = false
				for radius: float in [0.0, 8.0, 14.0, 22.0]:
					for i in (1 if radius == 0.0 else 8):
						var around: Vector3 = point + Vector3.FORWARD.rotated(Vector3.UP, TAU * i / 8.0) * radius
						var path: PackedVector3Array = grid.find_path(origin, around)
						if not path.is_empty():
							var end: Vector3 = path[path.size() - 2] if path.size() > 1 else path[0]
							if Vector2(end.x - point.x, end.z - point.z).length() <= 26.0:
								reachable = true
								break
					if reachable:
						break
				if not reachable:
					problem = "sin ruta"
			# Bajo la falda de una colina o montaña (salvo la propia).
			var space: PhysicsDirectSpaceState3D = arena.get_world_3d().direct_space_state
			var query := PhysicsRayQueryParameters3D.create(Vector3(point.x, 90.0, point.z), Vector3(point.x, 0.3, point.z), 1)
			var hit: Dictionary = space.intersect_ray(query)
			if not hit.is_empty() and hit["collider"] in mountains and hit["collider"] != target:
				problem = "dentro de una montaña"
			if problem != "":
				bad += 1
				print("REACH MAL ", target.name, " ", point, " ", problem)
		var outside: int = 0
		for mountain in mountains:
			var p: Vector3 = mountain.global_position
			if absf(p.x) > 200.0 or absf(p.z) > 200.0:
				# Montaña exterior: ningún punto del muro puede caer bajo su falda.
				for i in 81:
					var along: float = -200.0 + 5.0 * i
					for edge: Vector3 in [Vector3(along, 60.0, -199.0), Vector3(along, 60.0, 199.0), Vector3(-199.0, 60.0, along), Vector3(199.0, 60.0, along)]:
						var down := PhysicsRayQueryParameters3D.create(edge, Vector3(edge.x, 0.3, edge.z), 1)
						var found: Dictionary = arena.get_world_3d().direct_space_state.intersect_ray(down)
						if not found.is_empty() and found["collider"] == mountain:
							outside += 1
		_unreachable += bad + outside
		print("REACH ", GameSession.current_mission()["title"], ": ", targets.size(), " puntos comprobados, ", bad, " inaccesibles; ", mountains.size(), " montañas, ", outside, " puntos del muro bajo una montaña")

	## Prueba de navegación (sin gráficos): tanques que deben llegar al otro lado de un muro
	## largo, de un recinto en U y de un grupo de bloques. Compara la navegación con rodeo
	## (la de los aliados) con la antigua.
	func _nav() -> void:
		var old_scene: Node = get_tree().current_scene
		if old_scene != null:
			old_scene.queue_free()
		await _frames(2)
		# El escenario de esta prueba es llano: fuera las lomas y los ríos que haya dejado
		# registrados la partida anterior (un tanque subiría por ellas).
		Terrain.clear()
		Water.clear()
		Backdrop.sea_side = Vector2.ZERO
		var stage := Node3D.new()
		stage.name = "NavStage"
		get_tree().root.add_child(stage)
		var floor_body := StaticBody3D.new()
		floor_body.collision_layer = 1
		var floor_shape := CollisionShape3D.new()
		var floor_box := BoxShape3D.new()
		floor_box.size = Vector3(1200.0, 2.0, 1200.0)
		floor_shape.shape = floor_box
		floor_shape.position.y = -1.0
		floor_body.add_child(floor_shape)
		stage.add_child(floor_body)
		GameSession.mode = GameSession.Mode.SURVIVAL
		GameSession.front = Fronts.Id.NORMANDY
		GameSession.faction = Fronts.Faction.ALLIES
		var mode := GameMode.new()
		mode.set_physics_process(false)
		stage.add_child(mode)
		mode.world = stage
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		var cases: Array[String] = ["muro", "recinto en U", "bloques"]
		var runs: Array[Dictionary] = []
		for c in cases.size():
			for smart in [true, false]:
				var origin := Vector3(c * 130.0 - 130.0, 0.0, 0.0 if smart else 220.0)
				match c:
					0:
						_wall(stage, origin, Vector3(44.0, 3.0, 2.0))
					1:
						_wall(stage, origin + Vector3(0.0, 0.0, -6.0), Vector3(26.0, 3.0, 2.0))
						_wall(stage, origin + Vector3(-12.0, 0.0, 4.0), Vector3(2.0, 3.0, 18.0))
						_wall(stage, origin + Vector3(12.0, 0.0, 4.0), Vector3(2.0, 3.0, 18.0))
					_:
						rng.seed = 7
						for i in 14:
							_wall(stage, origin + Vector3(rng.randf_range(-16.0, 16.0), 0.0, rng.randf_range(-18.0, 18.0)), Vector3(4.0, 3.0, 4.0))
				for stats_id: String in ["m4_sherman", "churchill"]:
					var start: Vector3 = origin + Vector3(-4.0 if stats_id == "m4_sherman" else 5.0, 0.0, 34.0)
					var tank: Tank = mode.spawn_tank(Fronts.tank(stats_id), GameMode.PLAYER_TEAM, Vector2(start.x, start.z), 0.0)
					var brain: AIBrain = tank.get_node("AIBrain")
					brain.smart_nav = smart
					brain.hunt = false
					brain.objective = origin + Vector3(0.0, 0.0, -34.0)
					brain.objective_radius = 2.0
					runs.append({"case": cases[c], "smart": smart, "tank": tank, "brain": brain, "id": stats_id, "best": INF, "time": -1.0})
		# Colina: un tanque que empuja de frente contra ella no debe subirla.
		var hill := PropFactory.mountain(14.0, 9.0, 7)
		hill.position = Vector3(0.0, 0.0, -150.0)
		stage.add_child(hill)
		var dune := PropFactory.mountain(16.0, 5.0, 10)
		dune.position = Vector3(60.0, 0.0, -150.0)
		stage.add_child(dune)
		var climbers: Array[Tank] = []
		for x in [0.0, 60.0]:
			var climber: Tank = mode.spawn_tank(Fronts.tank("m4_sherman"), GameMode.PLAYER_TEAM, Vector2(x + 2.0, -120.0), 0.0)
			climber.get_node("AIBrain").queue_free()
			climbers.append(climber)
		var climb_height: float = 0.0
		Engine.time_scale = 4.0
		var clock: float = 0.0
		while clock < 60.0:
			await get_tree().physics_frame
			clock += get_physics_process_delta_time()
			for climber in climbers:
				if clock < 20.0:
					climber.drive_input = Vector2(0.0, 1.0)
				climb_height = maxf(climb_height, climber.global_position.y)
			for run in runs:
				var tank: Tank = run["tank"]
				var brain: AIBrain = run["brain"]
				var gap: Vector3 = brain.objective - tank.global_position
				gap.y = 0.0
				run["best"] = minf(run["best"], gap.length())
				if run["time"] < 0.0 and gap.length() <= 8.0:
					run["time"] = clock
		Engine.time_scale = 1.0
		var failures: int = 0
		for run in runs:
			var ok: bool = run["time"] >= 0.0
			if run["smart"] and not ok:
				failures += 1
			print("NAV %-13s %-10s %s  %s  mínima distancia %.1f m  desatascos %d" % [run["case"], run["id"], "CON RODEO" if run["smart"] else "ANTIGUA  ", ("llega en %.1f s" % run["time"]) if ok else "NO LLEGA", run["best"], run["brain"].unstuck_total])
		print("NAV RESULT fallos de la navegación con rodeo: ", failures)
		print("CLIMB RESULT altura máxima alcanzada empujando contra una colina y una duna: %.2f m (%s)" % [climb_height, "OK" if climb_height < 1.0 else "SUBE"])
		stage.queue_free()
		await _frames(2)

	## Reacción de un tanque enemigo al que le disparan sin que vea a quien lo hace:
	## a) tapado por una casa, tiene que rodearla; b) atacado desde más lejos de lo que alcanza a
	## ver, tiene que acercarse. En los dos casos debe acabar devolviendo el fuego. Un tercer
	## tanque, vecino del primero, debe darse por avisado.
	func _ai_reaction() -> void:
		var old_scene: Node = get_tree().current_scene
		if old_scene != null:
			old_scene.queue_free()
		await _frames(2)
		var stage := Node3D.new()
		stage.name = "AiStage"
		get_tree().root.add_child(stage)
		get_tree().current_scene = stage
		var floor_body := StaticBody3D.new()
		floor_body.collision_layer = 1
		var floor_shape := CollisionShape3D.new()
		var floor_box := BoxShape3D.new()
		floor_box.size = Vector3(1600.0, 2.0, 1600.0)
		floor_shape.shape = floor_box
		floor_shape.position.y = -1.0
		floor_body.add_child(floor_shape)
		stage.add_child(floor_body)
		GameSession.mode = GameSession.Mode.SURVIVAL
		GameSession.front = Fronts.Id.NORMANDY
		GameSession.faction = Fronts.Faction.ALLIES
		var mode := GameMode.new()
		mode.set_physics_process(false)
		stage.add_child(mode)
		mode.world = stage
		var cases: Array[Dictionary] = []
		for c in 2:
			var origin := Vector3(c * 500.0 - 250.0, 0.0, 0.0)
			var gap: float = 80.0 if c == 0 else 175.0
			if c == 0:
				_wall(stage, origin + Vector3(0.0, 0.0, -gap + 14.0), Vector3(16.0, 5.0, 10.0))
			var victim: Tank = mode.spawn_tank(Fronts.tank("m4_sherman"), GameMode.PLAYER_TEAM, Vector2(origin.x, origin.z), 0.0)
			victim.get_node("AIBrain").queue_free()
			victim.health.invulnerable = true
			var enemy: Tank = mode.spawn_tank(Fronts.tank("tiger2"), GameMode.ENEMY_TEAM, Vector2(origin.x, origin.z - gap), PI)
			var brain: AIBrain = enemy.get_node("AIBrain")
			brain.hunt = false
			brain.objective = enemy.global_position
			var buddy: Tank = mode.spawn_tank(Fronts.tank("panzer4"), GameMode.ENEMY_TEAM, Vector2(origin.x + 30.0, origin.z - gap - 10.0), PI)
			var buddy_brain: AIBrain = buddy.get_node("AIBrain")
			buddy_brain.hunt = false
			buddy_brain.objective = buddy.global_position
			var entry: Dictionary = {"name": "tapado por una casa" if c == 0 else "atacado desde 175 m", "victim": victim, "enemy": enemy, "brain": brain, "buddy": buddy_brain, "seen": -1.0, "fired": -1.0, "buddy_at": -1.0}
			enemy.weapon.fired.connect(func() -> void:
				if entry["fired"] < 0.0 and brain.target == victim:
					entry["fired"] = entry["t"])
			cases.append(entry)
		Engine.time_scale = 4.0
		await get_tree().create_timer(3.0).timeout
		var time: float = 0.0
		var hit_timer: float = 0.0
		while time < 75.0:
			await get_tree().physics_frame
			var delta: float = get_physics_process_delta_time()
			time += delta
			hit_timer -= delta
			for entry in cases:
				entry["t"] = time
				var brain: AIBrain = entry["brain"]
				if not is_instance_valid(entry["enemy"]):
					continue
				if hit_timer <= 0.0:
					# El «jugador» acierta un disparo cada 2,5 s.
					entry["enemy"].health.apply_damage(2.0, entry["victim"])
				if entry["seen"] < 0.0 and brain.target == entry["victim"] and brain.perception.can_see:
					entry["seen"] = time
				var buddy: AIBrain = entry["buddy"]
				if entry["buddy_at"] < 0.0 and is_instance_valid(buddy) and buddy.target == entry["victim"]:
					entry["buddy_at"] = time
			if hit_timer <= 0.0:
				hit_timer = 2.5
		Engine.time_scale = 1.0
		var failures: int = 0
		for entry in cases:
			var ok: bool = entry["seen"] >= 0.0 and entry["fired"] >= 0.0 and entry["buddy_at"] >= 0.0
			if not ok:
				failures += 1
			print("AI %-22s ve al atacante: %s | devuelve el fuego: %s | el vecino se da por avisado: %s | estado final %s" % [
				entry["name"], _secs(entry["seen"]), _secs(entry["fired"]), _secs(entry["buddy_at"]), entry["brain"].state_name() if is_instance_valid(entry["brain"]) else "-"])
		print("AI RESULT tanques que no reaccionan al fuego: ", failures)
		stage.queue_free()
		await _frames(2)

	## Captura la bandera jugada solo por la máquina (el jugador se queda parado en su base):
	## los dos bandos tienen que coger la bandera contraria y alguien tiene que capturar.
	func _ctf() -> void:
		var pickups: Array[int] = [0, 0]
		var captures: Array[int] = [0, 0]
		# Un trazado distinto en cada frente (o los que diga CTF_MAPAS, «frente:trazado» separados
		# por comas): la máquina tiene que saber capturar con trincheras, lomas y arroyos.
		var plan: Array = [[Fronts.Id.NORMANDY, "ridge"], [Fronts.Id.KURSK, "defences"], [Fronts.Id.AFRICA, "wadi"]]
		if OS.get_environment("CTF_MAPAS") != "":
			plan = []
			for item in OS.get_environment("CTF_MAPAS").split(","):
				plan.append([int(item.get_slice(":", 0)), item.get_slice(":", 1)])
		for entry: Array in plan:
			var front: int = entry[0]
			GameSession.debug_layout = entry[1]
			GameSession.mode = GameSession.Mode.CTF
			GameSession.front_choice = front
			GameSession.faction = Fronts.Faction.ALLIES
			GameSettings.ensure_loaded()
			GameSettings.difficulty = 1
			get_tree().change_scene_to_file("res://levels/arena.tscn")
			await _frames(4)
			var mode: CtfMode = get_tree().current_scene.get_node("GameMode") as CtfMode
			mode.raid_interval = Vector2.ZERO
			mode.player.health.invulnerable = true
			Engine.time_scale = 6.0
			var carried: Array[bool] = [false, false]
			var time: float = 0.0
			while time < 300.0 and not mode.is_over:
				await get_tree().create_timer(0.5).timeout
				time += 0.5
				for team in 2:
					# flags[team] es la bandera de ese bando: la coge el contrario.
					var now: bool = mode.flags[team].state == Flag.Status.CARRIED
					if now and not carried[team]:
						pickups[1 - team] += 1
					carried[team] = now
			Engine.time_scale = 1.0
			for team in 2:
				captures[team] += mode.captures[team]
			print("CTF %s («%s») en %d s: capturas aliadas %d, enemigas %d | banderas cogidas hasta ahora %d y %d" % [Fronts.NAMES[front], entry[1], roundi(time), mode.captures[0], mode.captures[1], pickups[0], pickups[1]])
		GameSession.debug_layout = ""
		print("CTF banderas cogidas: bando del jugador %d, bando enemigo %d | capturas %d y %d" % [pickups[0], pickups[1], captures[0], captures[1]])
		# Las capturas dependen de cómo vaya el combate; lo exigible es que los dos bandos lleguen
		# a coger la bandera contraria.
		var ok: bool = pickups[0] > 0 and pickups[1] > 0
		print("CTF RESULT la máquina juega a capturar: ", "OK" if ok else "NO")

	## Marcador de banderas en pantalla: una en su base y otra llevada por el jugador.
	func _ctf_shot() -> void:
		GameSession.mode = GameSession.Mode.CTF
		GameSession.front_choice = Fronts.Id.NORMANDY
		GameSession.faction = Fronts.Faction.ALLIES
		GameSettings.camera_view = 1
		get_tree().change_scene_to_file("res://levels/arena.tscn")
		await _frames(4)
		var mode: CtfMode = get_tree().current_scene.get_node("GameMode") as CtfMode
		mode.captures[0] = 1
		mode.captures[1] = 2
		mode.flags[1].pick_up(mode.player)
		await get_tree().create_timer(1.5).timeout
		await _snap("ctf_marcador")
		GameSettings.camera_view = 0

	## Capturas para la ficha de Play Store (se ejecuta a 1920x1080 en store-shots.yml): portada sin
	## menú, menú principal y partidas reales con la interfaz, sin la línea de versión y FPS.
	func _store() -> void:
		var old: Node = get_tree().current_scene
		if old != null:
			old.queue_free()
		await _frames(2)
		var stage := Node3D.new()
		get_tree().root.add_child(stage)
		get_tree().current_scene = stage
		stage.add_child(CoverDiorama.new())
		await get_tree().create_timer(3.0).timeout
		await _snap("store_portada_a")
		await get_tree().create_timer(7.0).timeout
		await _snap("store_portada_b")
		GameSession.mark_tutorial("offered")
		get_tree().change_scene_to_file("res://levels/main_menu.tscn")
		await _frames(3)
		get_tree().current_scene._version.visible = false
		await get_tree().create_timer(3.0).timeout
		await _snap("store_menu")
		GameSettings.ensure_loaded()
		# [frente, bando, clima, vista de cámara, nombre]
		var games: Array = [
			[Fronts.Id.NORMANDY, Fronts.Faction.ALLIES, Weather.Kind.CLEAR, 1, "normandia"],
			[Fronts.Id.AFRICA, Fronts.Faction.AXIS, Weather.Kind.CLEAR, 1, "africa"],
			[Fronts.Id.KURSK, Fronts.Faction.AXIS, Weather.Kind.RAIN, 1, "kursk_lluvia"],
			[Fronts.Id.NORMANDY, Fronts.Faction.ALLIES, Weather.Kind.FOG, 0, "normandia_cabina"],
			[Fronts.Id.KURSK, Fronts.Faction.ALLIES, Weather.Kind.SNOW, 2, "kursk_nieve"],
			[Fronts.Id.AFRICA, Fronts.Faction.ALLIES, Weather.Kind.FOG, 1, "africa_tormenta"],
		]
		for spec in games:
			GameSession.mode = GameSession.Mode.SURVIVAL
			GameSession.front_choice = spec[0]
			GameSession.faction = spec[1]
			GameSession.debug_weather = spec[2]
			GameSettings.camera_view = spec[3]
			get_tree().change_scene_to_file("res://levels/arena.tscn")
			await _frames(4)
			var arena: Node = get_tree().current_scene
			var hud: Hud = arena._hud
			hud._info.visible = false
			var player: Node3D = null
			for tank in get_tree().get_nodes_in_group(&"tanks"):
				if tank.is_player:
					player = tank
			await get_tree().create_timer(6.0).timeout
			# Un enemigo cerca y de frente, para que se vea combate y no un punto en el horizonte.
			var enemy: Node3D = null
			for tank in get_tree().get_nodes_in_group(&"tanks"):
				if player != null and not tank.is_player and tank.team != player.team:
					enemy = tank
					break
			if player != null and enemy != null:
				var fwd: Vector3 = -player.global_basis.z
				fwd.y = 0.0
				fwd = fwd.normalized()
				var right: Vector3 = fwd.cross(Vector3.UP)
				var spot: Vector3 = player.global_position + fwd * 32.0 + right * 6.0
				enemy.global_position = Vector3(spot.x, enemy.global_position.y + 0.5, spot.z)
				var face: Vector3 = player.global_position
				face.y = enemy.global_position.y
				enemy.look_at(face, Vector3.UP)
				await get_tree().create_timer(0.8).timeout
				await _snap("store_%s_a" % spec[4])
				player.weapon.fire()
				Engine.time_scale = 0.35
				await get_tree().create_timer(0.12).timeout
				Explosion.spawn(arena, enemy.global_position + Vector3(0.0, 1.4, 0.0), 1.3, VectorMaterials.ORANGE, true)
				await get_tree().create_timer(0.18).timeout
				await _snap("store_%s_impacto" % spec[4])
				await get_tree().create_timer(0.5).timeout
				await _snap("store_%s_impacto2" % spec[4])
				Engine.time_scale = 1.0
			await get_tree().create_timer(4.0).timeout
			await _snap("store_%s_b" % spec[4])
			if spec[4] == "normandia":
				hud._history_from_menu = true
				hud._history_gallery.show_index(3)
				hud.move_child(hud._history_panel, -1)
				hud._history_panel.visible = true
				await _snap("store_ficha_vehiculo")
				hud._history_panel.visible = false
		GameSession.debug_weather = -1
		GameSettings.camera_view = 1
		GameSession.mode = GameSession.Mode.CTF
		GameSession.front_choice = Fronts.Id.AFRICA
		GameSession.faction = Fronts.Faction.ALLIES
		get_tree().change_scene_to_file("res://levels/arena.tscn")
		await _frames(4)
		var ctf_scene: Node = get_tree().current_scene
		ctf_scene._hud._info.visible = false
		var mode: CtfMode = ctf_scene.get_node("GameMode") as CtfMode
		mode.captures[0] = 2
		mode.captures[1] = 1
		await get_tree().create_timer(8.0).timeout
		await _snap("store_bandera")
		GameSettings.camera_view = 0

	## Gráfico destacado (portada con el título, se recorta a 1024x500) y candidatos de icono.
	func _store_cover() -> void:
		var old: Node = get_tree().current_scene
		if old != null:
			old.queue_free()
		await _frames(2)
		var stage := Node3D.new()
		get_tree().root.add_child(stage)
		get_tree().current_scene = stage
		var cover := CoverDiorama.new()
		stage.add_child(cover)
		var layer := CanvasLayer.new()
		stage.add_child(layer)
		var box := VBoxContainer.new()
		box.position = Vector2(70.0, 150.0)
		box.add_theme_constant_override("separation", 0)
		layer.add_child(box)
		var title := Label.new()
		title.text = "A TANK STORY"
		title.add_theme_font_size_override("font_size", 104)
		title.add_theme_color_override("font_color", Color(0.96, 0.82, 0.5))
		title.add_theme_color_override("font_outline_color", Color(0.12, 0.08, 0.04))
		title.add_theme_constant_override("outline_size", 20)
		title.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.7))
		title.add_theme_constant_override("shadow_offset_x", 5)
		title.add_theme_constant_override("shadow_offset_y", 6)
		box.add_child(title)
		var era := Label.new()
		era.text = "1941 — 1945"
		era.add_theme_font_size_override("font_size", 40)
		era.add_theme_color_override("font_color", Color(0.95, 0.93, 0.86))
		era.add_theme_color_override("font_outline_color", Color.BLACK)
		era.add_theme_constant_override("outline_size", 10)
		box.add_child(era)
		await get_tree().create_timer(6.0).timeout
		await _snap("store_destacado_a")
		await get_tree().create_timer(5.0).timeout
		await _snap("store_destacado_b")
		layer.visible = false
		_camera = Camera3D.new()
		_camera.far = 500.0
		stage.add_child(_camera)
		var views: Array = [
			[Vector3(-1.0, 1.8, 13.0), Vector3(5.0, 1.4, 6.0), 40.0, "icono_sherman"],
			[Vector3(10.0, 2.0, 2.0), Vector3(17.0, 1.6, -6.0), 40.0, "icono_tiger"],
			[Vector3(1.0, 1.4, 15.0), Vector3(9.0, 1.6, 1.0), 45.0, "icono_ambos"],
			[Vector3(9.0, 1.2, 12.0), Vector3(5.0, 1.5, 6.0), 42.0, "icono_sherman_bajo"],
		]
		for view in views:
			_look(view[0], view[1], view[2])
			await _snap("store_" + view[3])

	func _wants(only: String, key: String) -> bool:
		return only == "" or only.contains("mejoras") or only.contains(key)

	## Escenario vacío con suelo firme para las pruebas sin gráficos (como el de la navegación).
	func _bare_stage(stage_name: String) -> GameMode:
		var old_scene: Node = get_tree().current_scene
		if old_scene != null:
			old_scene.queue_free()
		await _frames(2)
		var stage := Node3D.new()
		stage.name = stage_name
		get_tree().root.add_child(stage)
		get_tree().current_scene = stage
		var floor_body := StaticBody3D.new()
		floor_body.collision_layer = 1
		var floor_shape := CollisionShape3D.new()
		var floor_box := BoxShape3D.new()
		floor_box.size = Vector3(1200.0, 2.0, 1200.0)
		floor_shape.shape = floor_box
		floor_shape.position.y = -1.0
		floor_body.add_child(floor_shape)
		stage.add_child(floor_body)
		GameSession.mode = GameSession.Mode.SURVIVAL
		GameSession.front = Fronts.Id.NORMANDY
		GameSession.faction = Fronts.Faction.ALLIES
		var mode := GameMode.new()
		mode.set_physics_process(false)
		stage.add_child(mode)
		mode.world = stage
		return mode

	## Lomas (sin gráficos): un tanque que avanza recto contra una loma la sube, con el chasis
	## inclinado, y baja por el otro lado; un tanque de la máquina la cruza para ir a su destino
	## en vez de rodearla; la loma tapa la vista entre dos tanques y para los disparos; y el
	## cañón de un tanque inclinado sigue apuntando a donde se le manda.
	func _lomas() -> void:
		var mode: GameMode = await _bare_stage("LomaStage")
		var stage: Node3D = mode.world
		Terrain.clear()
		stage.add_child(Terrain.add_mound(Vector2.ZERO, 26.0, VectorMaterials.ground(), 0.37))
		var top: float = Terrain.height(0.0, 0.0)
		var driver: Tank = mode.spawn_tank(Fronts.tank("m4_sherman"), GameMode.PLAYER_TEAM, Vector2(0.0, 45.0), 0.0)
		driver.get_node("AIBrain").queue_free()
		var walker: Tank = mode.spawn_tank(Fronts.tank("churchill"), GameMode.PLAYER_TEAM, Vector2(7.0, 48.0), 0.0)
		var brain: AIBrain = walker.get_node("AIBrain")
		brain.hunt = false
		brain.objective = Vector3(4.0, 0.0, -46.0)
		brain.objective_radius = 2.0
		# Parado en plena ladera, apuntando a un blanco lejano en el llano.
		var gunner: Tank = mode.spawn_tank(Fronts.tank("m4_sherman"), GameMode.PLAYER_TEAM, Vector2(13.0, 3.0), 0.6)
		gunner.get_node("AIBrain").queue_free()
		# Otro parado en la ladera de enfrente, con la base del cuerpo un pelo fuera de escala: así
		# queda tras muchos minutos girando (rotate_y acumula el error). Se tiene que inclinar igual.
		var veteran: Tank = mode.spawn_tank(Fronts.tank("m4_sherman"), GameMode.PLAYER_TEAM, Vector2(-13.0, 3.0), -0.6)
		veteran.get_node("AIBrain").queue_free()
		veteran.global_basis = veteran.global_basis * Basis.from_scale(Vector3(1.00004, 1.0, 1.00004))
		var mark := Vector3(120.0, 1.2, -90.0)
		var peak: float = 0.0
		var tilt: float = 0.0
		var walker_peak: float = 0.0
		var walker_time: float = -1.0
		Engine.time_scale = 4.0
		var clock: float = 0.0
		while clock < 45.0:
			await get_tree().physics_frame
			clock += get_physics_process_delta_time()
			driver.drive_input = Vector2(0.0, 1.0) if driver.global_position.z > -46.0 else Vector2.ZERO
			peak = maxf(peak, driver.global_position.y)
			tilt = maxf(tilt, rad_to_deg(driver.chassis.basis.y.angle_to(Vector3.UP)))
			walker_peak = maxf(walker_peak, walker.global_position.y)
			gunner.turret_controller.aim_at(mark)
			var gap: Vector3 = brain.objective - walker.global_position
			gap.y = 0.0
			if walker_time < 0.0 and gap.length() <= 8.0:
				walker_time = clock
		Engine.time_scale = 1.0
		var crossed: bool = driver.global_position.z < -40.0 and driver.global_position.y < 0.3
		# Puntería del tanque inclinado: lo que se desvía el cañón del blanco, en grados.
		var gunner_tilt: float = rad_to_deg(gunner.chassis.basis.y.angle_to(Vector3.UP))
		var aim_error: float = rad_to_deg((-gunner.muzzle.global_basis.z).angle_to(mark - gunner.muzzle.global_position))
		var veteran_tilt: float = rad_to_deg(veteran.chassis.basis.y.angle_to(Vector3.UP))
		# Un enemigo al sur y el conductor al norte, con la loma en medio.
		var enemy: Tank = mode.spawn_tank(Fronts.tank("panzer4"), GameMode.ENEMY_TEAM, Vector2(0.0, 45.0), 0.0)
		enemy.get_node("AIBrain").queue_free()
		await _frames(3)
		await get_tree().physics_frame
		var hidden: bool = not Perception.new(enemy).line_of_sight(driver)
		var from: Vector3 = enemy.global_position + Vector3.UP * 1.9
		var query := PhysicsRayQueryParameters3D.create(from, driver.global_position + Vector3.UP * 1.2, Projectile.MASK_WORLD | Projectile.MASK_HURTBOX | Terrain.LAYER)
		query.collide_with_areas = true
		query.exclude = [enemy.hurtbox.get_rid()]
		var hit: Dictionary = stage.get_world_3d().direct_space_state.intersect_ray(query)
		var stopped: bool = not hit.is_empty() and (hit["collider"] as Node).is_in_group(&"terrain")
		var ok: bool = peak > top * 0.8 and crossed and tilt > 3.0 and tilt < 17.0 and walker_time >= 0.0 and walker_peak > 1.0 and hidden and stopped and gunner_tilt > 3.0 and aim_error < 1.5 and veteran_tilt > 3.0
		print("LOMA cima %.2f m | el tanque sube a %.2f m con el chasis inclinado hasta %.1f grados y %s por el otro lado" % [top, peak, tilt, "baja" if crossed else "NO BAJA"])
		print("LOMA la máquina la cruza: %s (sube a %.2f m) | tapa la vista: %s | para el disparo: %s" % [_secs(walker_time), walker_peak, hidden, stopped])
		print("LOMA puntería de un tanque inclinado %.1f grados: se desvía %.2f grados del blanco" % [gunner_tilt, aim_error])
		print("LOMA con la base del cuerpo fuera de escala, como tras mucho girar: el chasis se inclina %.1f grados" % veteran_tilt)
		print("LOMA RESULT los tanques suben y bajan las lomas: %s" % ("OK" if ok else "MAL"))
		Terrain.clear()
		stage.queue_free()
		await _frames(2)

	## El menú de opciones (pausa) tiene que caber entero, sin desplazarlo, en una pantalla de
	## 1280x720 y en una ancha de 1600x720, en los diez idiomas.
	func _pause_fit() -> void:
		var bad: int = 0
		var smallest: float = 9.0
		var screens: Array[Vector2] = [Vector2(1280.0, 720.0), Vector2(1600.0, 720.0)]
		for code: String in Loc.LANGUAGES:
			GameSettings.set_language(code)
			GameSession.mode = GameSession.Mode.SURVIVAL
			GameSession.front_choice = Fronts.Id.NORMANDY
			GameSession.faction = Fronts.Faction.ALLIES
			get_tree().change_scene_to_file("res://levels/arena.tscn")
			await _frames(4)
			var hud: Hud = get_tree().current_scene._hud
			var line: String = ""
			for screen in screens:
				hud._fit_pause_menu(screen)
				var needed: Vector2 = hud._pause_panel.get_combined_minimum_size()
				var fits: bool = needed.x <= screen.x - Hud.MENU_MARGIN.x * 2.0 and needed.y <= screen.y - Hud.MENU_MARGIN.y * 2.0
				if not fits:
					bad += 1
				smallest = minf(smallest, hud.menu_scale)
				line += "  %dx%d: escala %.2f, ocupa %dx%d%s" % [roundi(screen.x), roundi(screen.y), hud.menu_scale, roundi(needed.x), roundi(needed.y), "" if fits else " NO CABE"]
			print("PAUSA %s%s" % [code, line])
		GameSettings.set_language("es")
		print("PAUSA RESULT menús de opciones que no caben en pantalla: %d (escala mínima %.2f)" % [bad, smallest])

	## Tanques que el jugador puede elegir (premium) en cada frente y bando, con la potencia que
	## tienen en sus manos. El de serie debe conservar la de siempre.
	func _player_tanks() -> void:
		var bad: int = 0
		for front in [Fronts.Id.NORMANDY, Fronts.Id.AFRICA, Fronts.Id.KURSK]:
			for faction in [Fronts.Faction.ALLIES, Fronts.Faction.AXIS]:
				var standard: TankStats = Fronts.player_stats(front, faction)
				if not (is_equal_approx(standard.max_armor, 100.0) and is_equal_approx(standard.damage, 25.0) and is_equal_approx(standard.reload_time, 1.2) and is_equal_approx(standard.max_speed, 14.0) and is_equal_approx(standard.body_scale, 1.0)):
					bad += 1
				for id: String in Fronts.ROSTERS[front][faction]:
					var stats: TankStats = Fronts.player_stats(front, faction, id)
					if stats.max_armor < 60.0 or stats.max_armor > 260.0 or stats.max_speed < 8.0 or stats.max_speed > 24.0 or stats.damage < 15.0 or stats.damage > 42.0:
						bad += 1
					print("TANQUES %-16s %-10s %-14s blindaje %3d  ataque %2d  recarga %.2f s  %2d km/h  giro %.2f  escala %.2f%s" % [Fronts.NAMES[front], Fronts.FACTION_NAMES[faction], stats.display_name, roundi(stats.max_armor), roundi(stats.damage), stats.reload_time, roundi(stats.max_speed * 3.6), stats.hull_turn_speed, stats.body_scale, "  casamata" if stats.traverse_limit_deg > 0.0 else ""])
		print("TANQUES RESULT fichas de jugador fuera de lo previsto: ", bad)

	## Cazacarros de casamata en manos del jugador (el cañón apenas gira): al llevar la mira 90
	## grados a un lado, el casco tiene que girar solo hasta dejar el cañón apuntando ahí.
	func _casemate() -> void:
		var mode: GameMode = await _bare_stage("CasamataStage")
		var stage: Node3D = mode.world
		Terrain.clear()
		GameSession.faction = Fronts.Faction.AXIS
		var was_easy: bool = GameSettings.easy_drive
		var was_assist: bool = GameSettings.aim_assist
		GameSettings.easy_drive = false
		GameSettings.aim_assist = false
		var tank := Tank.new()
		tank.is_player = true
		tank.team = GameMode.PLAYER_TEAM
		tank.stats = Fronts.player_stats(Fronts.Id.NORMANDY, Fronts.Faction.AXIS, "stug3")
		tank.paint = Fronts.paint(Fronts.Id.NORMANDY, Fronts.Faction.AXIS, tank.stats.nation)
		tank.position = Vector3(0.0, 0.2, 0.0)
		stage.add_child(tank)
		var touch := TouchControls.new()
		stage.add_child(touch)
		var input := PlayerInputSource.new()
		input.tank = tank
		input.touch = touch
		stage.add_child(input)
		await _frames(5)
		var limit: float = tank.turret_controller.traverse_limit
		# Arrastre de la mira: 90 grados a la izquierda.
		touch._look_delta = Vector2(-(PI * 0.5) / input.look_sensitivity, 0.0)
		var widest: float = 0.0
		Engine.time_scale = 4.0
		var clock: float = 0.0
		while clock < 8.0:
			await get_tree().physics_frame
			clock += get_physics_process_delta_time()
			widest = maxf(widest, absf(tank.turret_controller.local_yaw))
		Engine.time_scale = 1.0
		var hull: float = rad_to_deg(angle_difference(0.0, tank.global_rotation.y))
		var gun: float = rad_to_deg(angle_difference(0.0, tank.turret_controller.world_yaw))
		var ok: bool = limit > 0.0 and absf(hull - 90.0) < 6.0 and absf(gun - 90.0) < 3.0 and widest <= limit + 0.01
		print("TANQUES casamata (StuG III, el cañón gira %.0f grados a cada lado): con la mira 90 grados a la izquierda el casco queda a %.1f y el cañón a %.1f; giro máximo usado %.1f: %s" % [rad_to_deg(limit), hull, gun, rad_to_deg(widest), "OK" if ok else "MAL"])
		print("TANQUES RESULT el casco de un cazacarros sigue a la mira: %s" % ("OK" if ok else "MAL"))
		GameSettings.easy_drive = was_easy
		GameSettings.aim_assist = was_assist
		GameSession.faction = Fronts.Faction.ALLIES
		stage.queue_free()
		await _frames(2)

	## Aliados de la historia: salen dos más de los que marca la misión, con el blindaje
	## reforzado, y por cada uno que cae entra un refuerzo por el sur hasta agotar la reserva.
	func _allies() -> void:
		var bad: int = 0
		GameSession.debug_bare = true
		await _start_game(GameSession.Mode.STORY, Fronts.Id.NORMANDY, Fronts.Faction.ALLIES, Weather.Kind.SUNNY, 1, 0)
		var mode: StoryMode = get_tree().current_scene.get_node("GameMode") as StoryMode
		# Sin enemigos: solo interesa lo que pasa con el bando propio.
		mode.set_process(false)
		var expected: int = int(mode.mission.get("allies", 0)) + StoryMode.EXTRA_ALLIES
		var allies: Array = _allies_alive()
		var sturdy: int = 0
		for ally: Tank in allies:
			if ally.health.max_health > Fronts.tank(ally.stats.id).max_armor:
				sturdy += 1
		if allies.size() != expected or mode.allies_reserve != expected or sturdy != allies.size():
			bad += 1
		print("ALIADOS al empezar: %d (la misión marca %d) | con blindaje reforzado: %d | refuerzos en reserva: %d" % [allies.size(), int(mode.mission.get("allies", 0)), sturdy, mode.allies_reserve])
		for i in 2:
			(allies[i] as Tank).health.apply_damage(99999.0, null)
		await _frames(2)
		var after_loss: int = _allies_alive().size()
		Engine.time_scale = 4.0
		await get_tree().create_timer(StoryMode.ALLY_REINFORCE_DELAY + 4.0).timeout
		Engine.time_scale = 1.0
		var now: Array = _allies_alive()
		var from_south: int = 0
		for ally: Tank in now:
			if not ally in allies and ally.global_position.z > 120.0:
				from_south += 1
		if after_loss != expected - 2 or now.size() != expected or from_south != 2 or mode.allies_reserve != expected - 2:
			bad += 1
		print("ALIADOS tras perder 2: quedan %d | al rato vuelven a ser %d, %d de ellos recién llegados por el sur | reserva: %d" % [after_loss, now.size(), from_south, mode.allies_reserve])
		# Agotada la reserva ya no llega nadie más.
		mode.allies_reserve = 0
		(now[0] as Tank).health.apply_damage(99999.0, null)
		Engine.time_scale = 4.0
		await get_tree().create_timer(StoryMode.ALLY_REINFORCE_DELAY + 4.0).timeout
		Engine.time_scale = 1.0
		if _allies_alive().size() != expected - 1:
			bad += 1
		print("ALIADOS sin reserva: cae otro y quedan %d" % _allies_alive().size())
		print("ALIADOS RESULT fallos de aliados y refuerzos: ", bad)
		GameSession.debug_bare = false
		GameSession.debug_weather = -1

	func _allies_alive() -> Array:
		var list: Array = []
		for tank in get_tree().get_nodes_in_group(&"tanks"):
			if tank.team == GameMode.PLAYER_TEAM and not tank.is_player and not tank.is_destroyed:
				list.append(tank)
		return list

	## Bordes de ayuda (sin gráficos): con «Destacar objetivos» cada pieza objetivo lleva el
	## borde azul y sin él no; lo destruido no deja el borde en sus restos; el comandante va de
	## azul aunque también se destaquen los enemigos; los enemigos van de amarillo con su ajuste
	## y, sin ajustes, todos los tanques de la máquina llevan solo el contorno fino.
	func _halo() -> void:
		var bad: int = 0
		var was_enemies: bool = GameSettings.highlight_enemies
		var was_objectives: bool = GameSettings.highlight_objectives
		GameSettings.highlight_enemies = false
		GameSettings.highlight_objectives = false
		var blue: Material = VectorMaterials.outline(VectorMaterials.OBJECTIVE_OUTLINE, 0.05, 1.8)
		await _start_game(GameSession.Mode.STORY, Fronts.Id.NORMANDY, Fronts.Faction.ALLIES, Weather.Kind.SUNNY, 1, 1)
		var arena: Node = get_tree().current_scene
		var mode: StoryMode = arena.get_node("GameMode") as StoryMode
		mode.set_process(false)
		var pieces: Array = mode._objectives.duplicate()
		var off: int = 0
		for piece: Node in pieces:
			off += _overlaid(piece, null)
		GameSettings.highlight_objectives = true
		get_tree().call_group(&"objectives", &"refresh_highlight")
		var on: int = 0
		var meshes: int = 0
		for piece: Node in pieces:
			on += _overlaid(piece, blue)
			meshes += piece.find_children("*", "MeshInstance3D", true, false).size()
		if off != meshes or on != meshes or meshes == 0:
			bad += 1
		print("HALO aeródromo: %d objetivos con %d mallas | sin ayuda, sin borde: %d | con ayuda, borde azul: %d" % [pieces.size(), meshes, off, on])
		# Un objetivo destruido: sus restos no conservan el borde.
		var before: int = _overlaid(arena, blue)
		var victim: Destructible = pieces[0]
		var victim_meshes: int = victim.find_children("*", "MeshInstance3D", true, false).size()
		victim.take_hit(99999.0, null, victim.global_position + Vector3.UP)
		await _frames(3)
		var after: int = _overlaid(arena, blue)
		if after != before - victim_meshes:
			bad += 1
		print("HALO al destruir un objetivo de %d mallas: de %d mallas con borde azul quedan %d" % [victim_meshes, before, after])
		# Comandante y escolta.
		GameSettings.highlight_enemies = false
		GameSettings.highlight_objectives = false
		await _start_game(GameSession.Mode.STORY, Fronts.Id.NORMANDY, Fronts.Faction.ALLIES, Weather.Kind.SUNNY, 1, 4)
		var boss_mode: StoryMode = get_tree().current_scene.get_node("GameMode") as StoryMode
		await get_tree().create_timer(4.0).timeout
		boss_mode.set_process(false)
		var commander: Tank = boss_mode._commander
		var escort: Tank = null
		var ally: Tank = null
		for tank: Tank in get_tree().get_nodes_in_group(&"tanks"):
			if tank.team == GameMode.ENEMY_TEAM and tank != commander:
				escort = tank
			elif tank.team == GameMode.PLAYER_TEAM and not tank.is_player:
				ally = tank
		var player: Tank = _player_tank()
		var contour: Material = VectorMaterials.contour()
		var yellow: Material = VectorMaterials.outline(VectorMaterials.ENEMY_OUTLINE, 0.03, 1.5)
		var boss_blue: Material = VectorMaterials.outline(VectorMaterials.OBJECTIVE_OUTLINE, 0.04, 1.8)
		var plain_ok: bool = _tank_overlay(commander) == contour and _tank_overlay(escort) == contour and _tank_overlay(ally) == contour and _tank_overlay(player) == null
		GameSettings.highlight_enemies = true
		GameSettings.highlight_objectives = true
		for tank: Tank in get_tree().get_nodes_in_group(&"tanks"):
			tank.refresh_highlight()
		var helped_ok: bool = _tank_overlay(commander) == boss_blue and _tank_overlay(escort) == yellow and _tank_overlay(ally) == contour and _tank_overlay(player) == null
		escort.health.apply_damage(99999.0, null)
		await _frames(2)
		var wreck_ok: bool = _tank_overlay(escort) == null
		if not (plain_ok and helped_ok and wreck_ok) or commander == null or escort == null or ally == null:
			bad += 1
		print("HALO tanques sin ayudas (contorno fino en los de la máquina, nada en el del jugador): %s | con ayudas (comandante azul, escolta amarilla, aliado con contorno): %s | destruido, sin borde: %s" % [plain_ok, helped_ok, wreck_ok])
		print("HALO RESULT fallos de los bordes de ayuda: ", bad)
		GameSession.debug_weather = -1
		GameSettings.highlight_enemies = was_enemies
		GameSettings.highlight_objectives = was_objectives

	## Cuántas mallas bajo `root` llevan `overlay` como material superpuesto.
	func _overlaid(root: Node, overlay: Material) -> int:
		var count: int = 0
		for node in root.find_children("*", "MeshInstance3D", true, false):
			if (node as MeshInstance3D).material_overlay == overlay:
				count += 1
		return count

	func _tank_overlay(tank: Tank) -> Material:
		return (tank._meshes[0] as MeshInstance3D).material_overlay if tank != null else null

	## Arranca una partida con el clima y la vista indicados y devuelve el HUD.
	func _start_game(mode: int, front: int, faction: int, weather: int, view: int, mission: int = 0) -> Hud:
		GameSession.mode = mode
		GameSession.front_choice = front
		GameSession.faction = faction
		GameSession.mission_index = mission
		GameSession.debug_weather = weather
		GameSettings.ensure_loaded()
		GameSettings.camera_view = view
		get_tree().change_scene_to_file("res://levels/arena.tscn")
		await _frames(4)
		return get_tree().current_scene._hud

	func _player_tank() -> Tank:
		for tank in get_tree().get_nodes_in_group(&"tanks"):
			if tank.is_player:
				return tank
		return null

	## Coloca un tanque de la máquina delante del jugador (a `ahead` metros y `aside` a un lado),
	## de costado, y le quita el cerebro para que se quede quieto.
	func _pose_tank(player: Tank, hostile: bool, ahead: float, aside: float, yaw_offset: float = 1.1) -> Tank:
		for tank in get_tree().get_nodes_in_group(&"tanks"):
			if tank.is_player or tank.has_meta(&"posed") or (tank.team != player.team) != hostile:
				continue
			var fwd: Vector3 = -player.global_basis.z
			fwd.y = 0.0
			fwd = fwd.normalized()
			var spot: Vector3 = player.global_position + fwd * ahead + fwd.cross(Vector3.UP) * aside
			tank.set_meta(&"posed", true)
			var brain: Node = tank.get_node_or_null("AIBrain")
			if brain != null:
				# Dormido, no borrado: el modo de juego sigue contando con él.
				brain.process_mode = Node.PROCESS_MODE_DISABLED
			tank.drive_input = Vector2.ZERO
			tank.trigger_held = false
			tank.global_position = Vector3(spot.x, tank.global_position.y + 0.3, spot.z)
			tank.rotation.y = player.rotation.y + yaw_offset
			return tank
		return null

	## Climas claros nuevos en los tres frentes, con el atardecer de siempre para comparar: la
	## partida tal como se ve y un enemigo y un aliado a media distancia, sin bordes de ayuda,
	## para juzgar cuánto destacan los tanques sobre el terreno.
	func _weather_shots() -> void:
		var was_enemies: bool = GameSettings.highlight_enemies
		GameSettings.highlight_enemies = false
		var games: Array = [
			[Fronts.Id.NORMANDY, Fronts.Faction.ALLIES, Weather.Kind.SUNNY, "normandia_soleado"],
			[Fronts.Id.NORMANDY, Fronts.Faction.ALLIES, Weather.Kind.CLOUDS, "normandia_nubes"],
			[Fronts.Id.NORMANDY, Fronts.Faction.ALLIES, Weather.Kind.CLEAR, "normandia_atardecer"],
			[Fronts.Id.AFRICA, Fronts.Faction.AXIS, Weather.Kind.SUNNY, "africa_soleado"],
			[Fronts.Id.AFRICA, Fronts.Faction.ALLIES, Weather.Kind.CLOUDS, "africa_nubes"],
			[Fronts.Id.KURSK, Fronts.Faction.ALLIES, Weather.Kind.SUNNY, "kursk_soleado"],
			[Fronts.Id.KURSK, Fronts.Faction.AXIS, Weather.Kind.CLOUDS, "kursk_nubes"],
		]
		for spec: Array in games:
			# En captura la bandera hay tanques de los dos bandos desde el primer momento.
			var hud: Hud = await _start_game(GameSession.Mode.CTF, spec[0], spec[1], spec[2], 1)
			hud._info.visible = false
			var player: Tank = _player_tank()
			await get_tree().create_timer(2.5).timeout
			_pose_tank(player, true, 45.0, -7.0)
			_pose_tank(player, true, 85.0, 9.0, 0.4)
			_pose_tank(player, false, 60.0, 16.0, 2.2)
			await get_tree().create_timer(1.0).timeout
			await _snap("clima_%s" % spec[3])
			GameSettings.camera_view = 0
			player.set_view(0)
			await _snap("clima_%s_cabina" % spec[3])
		GameSession.debug_weather = -1
		GameSettings.camera_view = 1
		GameSettings.highlight_enemies = was_enemies

	## La mira del cañón sobre cada cielo con el cañón alzado (18º, el máximo normal), fijando un
	## enemigo, y con el cañón a 60º en una vista exterior (fuera de la pantalla: debe quedarse en
	## el borde con una flecha). Imprime dónde cae la mira. Solo se lanza a mano (SHOTS_ONLY=vista_mira).
	func _reticle_shots() -> void:
		var skies: Array = [
			[Weather.Kind.SUNNY, "soleado"],
			[Weather.Kind.CLOUDS, "nubes"],
			[Weather.Kind.CLEAR, "atardecer"],
			[Weather.Kind.RAIN, "lluvia"],
		]
		var bad: int = 0
		for sky: Array in skies:
			var sky_hud: Hud = await _start_game(GameSession.Mode.CTF, Fronts.Id.NORMANDY, Fronts.Faction.ALLIES, sky[0], 1)
			var sky_player: Tank = _player_tank()
			await get_tree().create_timer(1.5).timeout
			sky_player.turret_controller.pitch = deg_to_rad(18.0)
			sky_player.turret_controller._target_pitch = deg_to_rad(18.0)
			await _frames(6)
			var aim: Vector2 = sky_hud._aim_screen_point(sky_hud.size * 0.5)
			print("MIRA %s cañón a 18º: mira en %d,%d de %dx%d" % [sky[1], roundi(aim.x), roundi(aim.y), roundi(sky_hud.size.x), roundi(sky_hud.size.y)])
			await _snap("mira_%s_arriba" % sky[1])
		var hud: Hud = await _start_game(GameSession.Mode.CTF, Fronts.Id.NORMANDY, Fronts.Faction.ALLIES, Weather.Kind.SUNNY, 1)
		var player: Tank = _player_tank()
		await get_tree().create_timer(1.5).timeout
		# Sin la ayuda de apuntado el jugador suelta el objetivo solo: se enciende para la captura.
		var was_assist: bool = GameSettings.aim_assist
		GameSettings.aim_assist = true
		var enemy: Tank = _pose_tank(player, true, 60.0, 0.0)
		player.aim_lock = enemy
		await _frames(8)
		print("MIRA objetivo fijado: %s" % (player.aim_lock == enemy))
		await _snap("mira_fijada")
		GameSettings.aim_assist = was_assist
		player.aim_lock = null
		player.turret_controller.max_pitch = deg_to_rad(60.0)
		player.turret_controller.pitch = deg_to_rad(60.0)
		player.turret_controller._target_pitch = deg_to_rad(60.0)
		await _frames(6)
		var far: Vector2 = hud._aim_screen_point(hud.size * 0.5)
		var outside: bool = not Rect2(Vector2.ZERO, hud.size).has_point(far)
		print("MIRA cañón a 60º en vista exterior: mira en %d,%d (fuera de pantalla: %s)" % [roundi(far.x), roundi(far.y), outside])
		await _snap("mira_fuera_de_pantalla")
		print("MIRA RESULT problemas: %d" % bad)

	## Tabla de contraste (solo para comparar, no va en la comprobación): en un campo sin
	## decorado, tanques de los dos bandos a 35, 70 y 120 m vistos desde la cabina. De izquierda
	## a derecha, tres enemigos y tres propios: sin ayudas, con sombra de contacto, y con sombra
	## y contorno.
	func _contrast_shots() -> void:
		GameSession.debug_bare = true
		var was_enemies: bool = GameSettings.highlight_enemies
		GameSettings.highlight_enemies = false
		for front in [Fronts.Id.NORMANDY, Fronts.Id.AFRICA, Fronts.Id.KURSK]:
			for weather: int in [Weather.Kind.SUNNY, Weather.Kind.CLOUDS, Weather.Kind.CLEAR, Weather.Kind.FOG]:
				var hud: Hud = await _start_game(GameSession.Mode.SURVIVAL, front, Fronts.Faction.ALLIES, weather, 0)
				hud.visible = false
				var arena: Node = get_tree().current_scene
				var mode: GameMode = arena.get_node("GameMode")
				mode.set_process(false)
				mode.set_physics_process(false)
				var rows: Array = [[35.0, 7.5], [70.0, 9.5], [120.0, 13.0]]
				for row: Array in rows:
					for column in 6:
						Tank.contact_shadow_enabled = column % 3 >= 1
						Tank.contour_enabled = column % 3 == 2
						var team: int = GameMode.ENEMY_TEAM if column < 3 else GameMode.PLAYER_TEAM
						var stats: TankStats = mode.roster(team)[1]
						var tank: Tank = mode.spawn_tank(stats, team, Vector2((column - 2.5) * row[1], -row[0]), PI * 0.5 + 0.35)
						tank.get_node("AIBrain").process_mode = Node.PROCESS_MODE_DISABLED
				Tank.contact_shadow_enabled = true
				Tank.contour_enabled = true
				await get_tree().create_timer(1.5).timeout
				await _snap("contraste_%d_%d" % [front, weather])
				var player: Tank = _player_tank()
				player.set_binoculars(true)
				await _snap("contraste_%d_%d_zoom" % [front, weather])
		GameSession.debug_bare = false
		GameSession.debug_weather = -1
		GameSettings.highlight_enemies = was_enemies

	## Una loma con tanques subiéndola: de lado (se ve la inclinación) y desde el del jugador.
	func _mound_shots() -> void:
		for front in [Fronts.Id.NORMANDY, Fronts.Id.AFRICA]:
			var hud: Hud = await _start_game(GameSession.Mode.CTF, front, Fronts.Faction.ALLIES, Weather.Kind.SUNNY, 1)
			hud._info.visible = false
			var arena: Node = get_tree().current_scene
			if Terrain.mounds().is_empty():
				print("LOMA SHOT: este campo no tiene lomas")
				continue
			var mound: Terrain.Mound = Terrain.mounds()[0]
			var player: Tank = _player_tank()
			await get_tree().create_timer(1.5).timeout
			# El jugador en la ladera sur, subiendo hacia la cima; un enemigo en la ladera de enfrente.
			player.global_position = Vector3(mound.x + 2.0, 1.0, mound.z + mound.radius * 0.55)
			player.rotation.y = 0.0
			var enemy: Tank = _pose_tank(player, true, mound.radius * 0.95, -5.0, 2.6)
			var ally: Tank = _pose_tank(player, false, mound.radius * 0.5, 9.0, 0.3)
			await get_tree().create_timer(1.2).timeout
			await _snap("loma_%d_jugador" % front)
			_camera = Camera3D.new()
			_camera.far = 700.0
			arena.add_child(_camera)
			var center := Vector3(mound.x, mound.height * 0.5, mound.z)
			_look(center + Vector3(mound.radius * 1.5, 5.0, mound.radius * 0.45), center, 50.0)
			await _snap("loma_%d_lado" % front)
			_look(player.global_position + Vector3(9.0, 2.2, 3.0), player.global_position + Vector3(0.0, 1.2, 0.0), 45.0)
			await _snap("loma_%d_cerca" % front)
			if enemy != null and ally != null:
				_look(center + Vector3(-mound.radius * 0.2, 26.0, mound.radius * 1.5), center, 55.0)
				await _snap("loma_%d_alto" % front)
		GameSession.debug_weather = -1

	## Bordes de ayuda: azul en los objetivos (edificios, comandante, bandera enemiga y salida) y
	## amarillo en los enemigos, de cerca y de lejos.
	func _halo_shots() -> void:
		var was_enemies: bool = GameSettings.highlight_enemies
		var was_objectives: bool = GameSettings.highlight_objectives
		GameSettings.highlight_enemies = true
		GameSettings.highlight_objectives = true
		# Aeródromo (sabotaje), comandante (jefe) y campo de prisioneros (alambradas).
		var games: Array = [
			[Fronts.Faction.ALLIES, Fronts.Id.NORMANDY, 1, Weather.Kind.SUNNY, "aerodromo"],
			[Fronts.Faction.ALLIES, Fronts.Id.NORMANDY, 4, Weather.Kind.CLOUDS, "comandante"],
			[Fronts.Faction.ALLIES, Fronts.Id.KURSK, 4, Weather.Kind.FOG, "alambradas"],
		]
		for spec: Array in games:
			var hud: Hud = await _start_game(GameSession.Mode.STORY, spec[1], spec[0], spec[3], 1, spec[2])
			hud._info.visible = false
			var arena: Node = get_tree().current_scene
			var mode: StoryMode = arena.get_node("GameMode") as StoryMode
			await get_tree().create_timer(2.0).timeout
			_camera = Camera3D.new()
			_camera.far = 700.0
			arena.add_child(_camera)
			var focus: Vector3 = StoryMode.TARGET_CENTER
			if mode.kind == "boss" and is_instance_valid(mode._commander):
				focus = mode._commander.global_position
				_look(focus + Vector3(12.0, 5.0, 16.0), focus + Vector3(0.0, 1.2, 0.0), 50.0)
				await _snap("halo_%s_cerca" % spec[4])
				_look(focus + Vector3(40.0, 14.0, 70.0), focus, 50.0)
			else:
				_look(focus + Vector3(30.0, 16.0, 62.0), focus + Vector3(0.0, 4.0, 0.0), 55.0)
				await _snap("halo_%s_cerca" % spec[4])
				_look(focus + Vector3(20.0, 9.0, 150.0), focus + Vector3(0.0, 4.0, 0.0), 45.0)
			await _snap("halo_%s_lejos" % spec[4])
		# Captura la bandera: la bandera enemiga.
		var ctf_hud: Hud = await _start_game(GameSession.Mode.CTF, Fronts.Id.AFRICA, Fronts.Faction.ALLIES, Weather.Kind.SUNNY, 1)
		ctf_hud._info.visible = false
		var ctf: CtfMode = get_tree().current_scene.get_node("GameMode") as CtfMode
		await get_tree().create_timer(1.5).timeout
		_camera = Camera3D.new()
		_camera.far = 700.0
		get_tree().current_scene.add_child(_camera)
		var flag_at: Vector3 = ctf.flags[1].global_position
		_look(flag_at + Vector3(10.0, 6.0, 24.0), flag_at + Vector3(0.0, 3.0, 0.0), 50.0)
		await _snap("halo_bandera")
		GameSession.debug_weather = -1
		GameSettings.highlight_enemies = was_enemies
		GameSettings.highlight_objectives = was_objectives

	## Los bordes de ayuda y el contorno de los tanques son el mismo modelo, hinchado: una ayuda
	## para la pantalla que no debe dar sombra. Se dibuja el mismo campo, parado y visto desde
	## arriba, con ellos y sin ellos, y se cuentan los píxeles que cambian lejos de los tanques,
	## donde solo hay suelo y sombras. (Con el grosor medido en píxeles, en la pasada de sombras
	## el modelo se hinchaba metros y metros y sus sombras cruzaban medio campo.)
	func _overlay_shadows() -> void:
		if DisplayServer.get_name() == "headless":
			return
		GameSession.debug_bare = true
		var was_enemies: bool = GameSettings.highlight_enemies
		var was_objectives: bool = GameSettings.highlight_objectives
		var hud: Hud = await _start_game(GameSession.Mode.SURVIVAL, Fronts.Id.NORMANDY, Fronts.Faction.ALLIES, Weather.Kind.SUNNY, 0)
		hud.visible = false
		var arena: Node = get_tree().current_scene
		var mode: GameMode = arena.get_node("GameMode")
		mode.set_process(false)
		mode.set_physics_process(false)
		# Un objetivo (borde azul), un enemigo (borde amarillo) y un aliado (contorno fino).
		var tanks: Array[Tank] = []
		for i in 3:
			var team: int = GameMode.PLAYER_TEAM if i == 2 else GameMode.ENEMY_TEAM
			var tank: Tank = mode.spawn_tank(mode.roster(team)[1], team, Vector2((i - 1) * 24.0, -60.0), 0.6 + i * 1.3)
			tank.get_node("AIBrain").process_mode = Node.PROCESS_MODE_DISABLED
			tanks.append(tank)
		tanks[0].is_objective = true
		await get_tree().create_timer(1.5).timeout
		_camera = Camera3D.new()
		_camera.far = 700.0
		arena.add_child(_camera)
		_look(Vector3(0.0, 75.0, -59.0), Vector3(0.0, 0.0, -60.0), 50.0)
		# Todo parado: entre una imagen y otra solo cambian los bordes.
		get_tree().paused = true
		var images: Array[Image] = []
		for with_overlays: bool in [true, false]:
			GameSettings.highlight_enemies = with_overlays
			GameSettings.highlight_objectives = with_overlays
			Tank.contour_enabled = with_overlays
			for tank in tanks:
				tank.refresh_highlight()
			await _frames(4)
			await RenderingServer.frame_post_draw
			var image: Image = get_viewport().get_texture().get_image()
			image.save_jpg(_dir.path_join("sombras_%s.jpg" % ("con_bordes" if with_overlays else "sin_bordes")), 0.88)
			images.append(image)
		# Píxeles que cambian a más de 8 m de cualquier tanque (el borde solo toca su silueta).
		var pixels := Vector2(images[0].get_size())
		var to_pixels: Vector2 = pixels / get_viewport().get_visible_rect().size
		var metre: float = pixels.y / (2.0 * 75.0 * tan(deg_to_rad(25.0)))
		var spots: Array[Vector2] = []
		for tank in get_tree().get_nodes_in_group(&"tanks"):
			spots.append(_camera.unproject_position(tank.global_position) * to_pixels)
		var stray: int = 0
		var near: int = 0
		for y in images[0].get_height():
			for x in images[0].get_width():
				var a: Color = images[0].get_pixel(x, y)
				var b: Color = images[1].get_pixel(x, y)
				if absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) < 0.12:
					continue
				var far_from_all: bool = true
				for spot in spots:
					if spot.distance_to(Vector2(x, y)) < 8.0 * metre:
						far_from_all = false
						break
				if far_from_all:
					stray += 1
				else:
					near += 1
		print("SOMBRAS píxeles que cambian junto a los tanques (los propios bordes): ", near)
		print("SOMBRAS RESULT píxeles que cambian lejos de los tanques al poner bordes y contornos: %d (%s)" % [stray, "OK" if stray <= 20 and near > 0 else "MAL"])
		get_tree().paused = false
		Tank.contour_enabled = true
		GameSession.debug_bare = false
		GameSession.debug_weather = -1
		GameSettings.highlight_enemies = was_enemies
		GameSettings.highlight_objectives = was_objectives

	## Menús: opciones de la pausa (letra grande), parte de misión con el clima y el tanque, la
	## pantalla previa de supervivencia, las opciones del menú y el final de una misión ganada.
	func _ui_shots() -> void:
		var saved: Dictionary = _unlock_everything()
		var hud: Hud = await _start_game(GameSession.Mode.STORY, Fronts.Id.NORMANDY, Fronts.Faction.ALLIES, Weather.Kind.SUNNY, 1, 0)
		await get_tree().create_timer(2.0).timeout
		hud._set_paused(true)
		print("UI menú de opciones a escala ", hud.menu_scale, " en una pantalla de ", hud.size)
		await _snap("ui_opciones_pausa")
		hud._set_paused(false)
		(get_tree().current_scene.get_node("GameMode") as StoryMode)._win("ZONA DESPEJADA")
		await get_tree().create_timer(1.6).timeout
		await _snap("ui_fin_victoria")
		GameSession.debug_weather = -1
		get_tree().paused = false
		get_tree().change_scene_to_file("res://levels/main_menu.tscn")
		await _frames(4)
		var menu: Control = get_tree().current_scene
		menu._version.visible = false
		GameSession.mode = GameSession.Mode.STORY
		GameSession.faction = Fronts.Faction.ALLIES
		GameSession.front_choice = Fronts.Id.NORMANDY
		menu._page_briefing(0)
		await _frames(4)
		await get_tree().create_timer(1.0).timeout
		await _snap("ui_mision")
		for picker in menu._content.find_children("*", "OptionButton", true, false):
			(picker as OptionButton).show_popup()
			await _frames(3)
			await _snap("ui_mision_lista_%d" % picker.get_index())
			(picker as OptionButton).get_popup().hide()
			await _frames(2)
		GameSession.mode = GameSession.Mode.SURVIVAL
		GameSession.front_choice = Fronts.Id.AFRICA
		menu._page_start()
		await _frames(4)
		await _snap("ui_inicio_supervivencia")
		menu._page_audio()
		await _frames(4)
		await _snap("ui_opciones_menu")
		_restore_progress(saved)

	## Formación de los aliados con la orden «todos conmigo» (sin gráficos). Un tanque sin cerebro
	## hace de jugador y recorre un circuito con paradas: recta, giro de 90 grados, media vuelta
	## pasando por donde venía la formación, avance corto y marcha atrás. En cada parada, ya
	## quietos, los aliados tienen que estar con él pero sin amontonarse: separados entre sí y de
	## él, y ninguno delante. Por el camino no pueden ir chocando unos con otros. Se repite en un
	## campo con casas, donde algún puesto de la formación cae dentro de un edificio.
	func _formation() -> void:
		var bad: int = 0
		# Los puestos sobre el papel, para cualquier número de aliados: separados entre sí y del
		# líder, ninguno por delante de él y la calle del centro (por donde recula o da media vuelta) libre.
		var tight: float = INF
		for count in range(1, 9):
			var slots: PackedVector2Array = Formation.layout(count)
			var fine: bool = slots.size() == count
			for i in slots.size():
				tight = minf(tight, slots[i].length())
				if slots[i].y < 10.0 or absf(slots[i].x) < 12.0:
					fine = false
				for j in range(i + 1, slots.size()):
					tight = minf(tight, slots[i].distance_to(slots[j]))
			if not fine or tight < 17.0:
				bad += 1
		print("FORMACION puestos para 1 a 8 aliados: separación mínima %.1f m, ninguno delante ni en la calle del centro  %s" % [tight, "OK" if bad == 0 else "MAL"])
		for field: String in ["campo abierto", "entre casas"]:
			bad += await _formation_run(field)
		print("FORMACION RESULT fallos de la formación de los aliados: ", bad)

	func _formation_run(field: String) -> int:
		var mode: GameMode = await _bare_stage("FormationStage")
		var stage: Node3D = mode.world
		if field == "entre casas":
			# Un pueblo a los dos lados del camino del líder y junto a sus paradas.
			for spot: Vector3 in [Vector3(-16.0, 0.0, 22.0), Vector3(17.0, 0.0, 24.0), Vector3(-22.0, 0.0, -2.0), Vector3(40.0, 0.0, 26.0), Vector3(76.0, 0.0, 24.0), Vector3(104.0, 0.0, 6.0), Vector3(74.0, 0.0, 78.0), Vector3(108.0, 0.0, 96.0), Vector3(60.0, 0.0, -8.0)]:
				_wall(stage, spot, Vector3(10.0, 4.0, 8.0))
		var leader := Tank.new()
		leader.name = "Leader"
		leader.team = GameMode.PLAYER_TEAM
		leader.stats = Fronts.player_stats(Fronts.Id.NORMANDY, Fronts.Faction.ALLIES)
		leader.position = Vector3(0.0, 0.2, 120.0)
		stage.add_child(leader)
		mode.start(leader, stage)
		mode.raid_interval = Vector2.ZERO
		mode.set_physics_process(true)
		var allies: Array[Tank] = []
		var ids: Array[String] = ["m4_sherman", "cromwell", "m10_wolverine", "m8_greyhound", "churchill"]
		for i in ids.size():
			# Como al empezar una misión: en abanico a los dos lados del jugador.
			var rank: int = i / 2 + 1
			var side: float = 1.0 if i % 2 == 0 else -1.0
			allies.append(mode.spawn_tank(Fronts.tank(ids[i]), GameMode.PLAYER_TEAM, Vector2(side * rank * 9.0, 126.0 + (rank - 1) * 4.0)))
		# El mapa de celdas tarda medio segundo en rellenarse.
		await get_tree().create_timer(1.0).timeout
		mode.toggle_follow()
		# Circuito: [destino, segundos de parada]. La última pareja es un avance corto y una marcha atrás.
		var legs: Array = [
			["recta", Vector3(0.0, 0.0, 10.0), 18.0], ["giro a la derecha", Vector3(90.0, 0.0, 10.0), 18.0],
			["otro giro", Vector3(90.0, 0.0, 100.0), 18.0], ["media vuelta", Vector3(90.0, 0.0, 10.0), 20.0],
			["avance corto", Vector3(90.0, 0.0, -4.0), 8.0], ["marcha atrás", Vector3.INF, 10.0]]
		var worst_pair: float = INF
		var worst_leader: float = INF
		var contact: float = 0.0
		var bad: int = 0
		# Con FORMACION_DEBUG=1 se apunta cada acercamiento, para ver de dónde viene.
		var debug: bool = OS.get_environment("FORMACION_DEBUG") != ""
		# Con FORMACION_TRACE=«campo/tramo» (por ejemplo «entre casas/media vuelta») se sigue a cada tanque en ese tramo.
		var trace: String = OS.get_environment("FORMACION_TRACE")
		Engine.time_scale = 4.0
		for leg: Array in legs:
			var target: Vector3 = leg[1]
			var clock: float = 0.0
			var hold: float = 0.0
			var reverse_left: float = 1.2
			while hold < leg[2] and clock < 90.0:
				await get_tree().physics_frame
				var delta: float = get_physics_process_delta_time()
				clock += delta
				if target == Vector3.INF:
					# Marcha atrás un momento y parada.
					reverse_left -= delta
					leader.drive_input = Vector2(0.0, -1.0) if reverse_left > 0.0 else Vector2.ZERO
					if reverse_left <= 0.0:
						hold += delta
				else:
					var to: Vector3 = target - leader.global_position
					to.y = 0.0
					if to.length() <= 3.0 or hold > 0.0:
						leader.drive_input = Vector2.ZERO
						hold += delta
					else:
						var angle: float = (-leader.global_transform.basis.z).signed_angle_to(to, Vector3.UP)
						leader.drive_input = Vector2(clampf(-angle * 2.5, -1.0, 1.0), 1.0 if absf(angle) < 0.5 else 0.0)
				if trace == field + "/" + leg[0] and fmod(clock, 0.25) < delta:
					print("FORMACION   t=%.2f líder %s rumbo %s vel %.1f  formación %s" % [clock, _xz(leader.global_position), _xz(-leader.global_transform.basis.z), Vector2(leader.velocity.x, leader.velocity.z).length(), _xz(mode.formation.heading) if mode.formation != null else "-"])
					for i in allies.size():
						var b: AIBrain = allies[i].get_node("AIBrain")
						print("FORMACION      %-13s en %s puesto %d %s  estado %s%s  mando (%.2f, %.2f) vel %.1f bloqueado %s" % [ids[i], _xz(allies[i].global_position), b.formation_slot, _xz(b.follow_point()) if b.follow != null else "-", b.state_name(), " LEJOS" if b.follow_far else "", allies[i].drive_input.x, allies[i].drive_input.y, Vector2(allies[i].velocity.x, allies[i].velocity.z).length(), str(b._nav_blocked)])
				# Por el camino: lo más que se acercan dos aliados entre sí y al líder, y cuánto rato van pegados.
				for i in allies.size():
					var from_leader: float = _flat_distance(allies[i], leader)
					worst_leader = minf(worst_leader, from_leader)
					if from_leader < 7.5:
						contact += delta
						if debug:
							print("FORMACION   cerca del líder: %s a %.1f m en «%s» t=%.1f  líder %s rumbo %s  aliado %s puesto %d" % [ids[i], from_leader, leg[0], clock, _xz(leader.global_position), _xz(-leader.global_transform.basis.z), _xz(allies[i].global_position), (allies[i].get_node("AIBrain") as AIBrain).formation_slot])
					for j in range(i + 1, allies.size()):
						var apart: float = _flat_distance(allies[i], allies[j])
						worst_pair = minf(worst_pair, apart)
						if apart < 6.5:
							contact += delta
							if debug:
								print("FORMACION   pegados: %s y %s a %.1f m en «%s» t=%.1f  %s %s  puestos %d y %d" % [ids[i], ids[j], apart, leg[0], clock, _xz(allies[i].global_position), _xz(allies[j].global_position), (allies[i].get_node("AIBrain") as AIBrain).formation_slot, (allies[j].get_node("AIBrain") as AIBrain).formation_slot])
			# Parados: la foto de la formación.
			var forward: Vector3 = -leader.global_transform.basis.z
			var nearest_pair: float = INF
			var nearest: float = INF
			var farthest: float = 0.0
			var ahead: int = 0
			var moving: int = 0
			for i in allies.size():
				var offset: Vector3 = allies[i].global_position - leader.global_position
				offset.y = 0.0
				nearest = minf(nearest, offset.length())
				farthest = maxf(farthest, offset.length())
				if offset.dot(forward) > 6.0:
					ahead += 1
				if Vector2(allies[i].velocity.x, allies[i].velocity.z).length() > 0.5:
					moving += 1
				for j in range(i + 1, allies.size()):
					nearest_pair = minf(nearest_pair, _flat_distance(allies[i], allies[j]))
			var ok: bool = nearest_pair >= 12.0 and nearest >= 12.0 and farthest <= 50.0 and ahead == 0 and moving == 0
			if not ok:
				bad += 1
			print("FORMACION %-13s %-17s entre aliados %.1f m | al líder de %.1f a %.1f m | delante %d | aún moviéndose %d  %s" % [field, leg[0], nearest_pair, nearest, farthest, ahead, moving, "OK" if ok else "MAL"])
		Engine.time_scale = 1.0
		var unstuck: int = 0
		for ally: Tank in allies:
			unstuck += (ally.get_node("AIBrain") as AIBrain).unstuck_total
		# Por el camino pueden cruzarse, pero no ir chocando: ni pegados más que un momento.
		var transit_ok: bool = contact <= 3.0 and worst_leader >= 5.0
		if not transit_ok:
			bad += 1
		print("FORMACION %-13s por el camino: mínimo entre aliados %.1f m, al líder %.1f m | pegados %.1f s | desatascos %d  %s" % [field, worst_pair, worst_leader, contact, unstuck, "OK" if transit_ok else "MAL"])
		stage.queue_free()
		await _frames(2)
		return bad

	## Los aliados siguiendo al jugador, vistos desde arriba: en marcha y ya parados. El jugador
	## avanza recto 80 m y se detiene. Solo se lanza a mano (SHOTS_ONLY=vista_formacion).
	func _formation_shots() -> void:
		GameSession.debug_bare = true
		var hud: Hud = await _start_game(GameSession.Mode.STORY, Fronts.Id.NORMANDY, Fronts.Faction.ALLIES, Weather.Kind.SUNNY, 1, 5)
		hud.visible = false
		var scene: Node = get_tree().current_scene
		# Sin interfaz: solo el campo.
		for child in scene.get_children():
			if child is CanvasLayer:
				(child as CanvasLayer).visible = false
		var mode: GameMode = scene.get_node("GameMode")
		mode.set_process(false)
		mode.raid_interval = Vector2.ZERO
		for tank in get_tree().get_nodes_in_group(&"tanks"):
			if tank.team != GameMode.PLAYER_TEAM:
				tank.get_node("AIBrain").process_mode = Node.PROCESS_MODE_DISABLED
				tank.process_mode = Node.PROCESS_MODE_DISABLED
				tank.remove_from_group(&"tanks")
				tank.global_position = Vector3(0.0, -200.0, 0.0)
		var leader: Tank = _player_tank()
		scene.get_node("PlayerInputSource").process_mode = Node.PROCESS_MODE_DISABLED
		_camera = Camera3D.new()
		_camera.far = 700.0
		scene.add_child(_camera)
		await get_tree().create_timer(1.0).timeout
		mode.toggle_follow()
		var clock: float = 0.0
		var start_z: float = leader.global_position.z
		var shot_moving: bool = false
		while clock < 26.0:
			await get_tree().physics_frame
			clock += get_physics_process_delta_time()
			var advanced: float = start_z - leader.global_position.z
			leader.drive_input = Vector2(0.0, 1.0) if advanced < 80.0 and clock > 2.0 else Vector2.ZERO
			if not shot_moving and advanced > 55.0:
				shot_moving = true
				await _formation_snap(leader, "formacion_en_marcha")
		await _formation_snap(leader, "formacion_parados")
		GameSession.debug_bare = false
		GameSession.debug_weather = -1

	func _formation_snap(leader: Tank, shot: String) -> void:
		var origin: Vector3 = leader.global_position
		_look(origin + Vector3(0.0, 62.0, 58.0), origin + Vector3(0.0, 0.0, 12.0), 50.0)
		await _snap(shot)
		var at: Vector2 = _camera.unproject_position(leader.global_position + Vector3.UP * 2.0)
		var spots: Array[String] = []
		for ally: Tank in _allies_alive():
			var p: Vector2 = _camera.unproject_position(ally.global_position + Vector3.UP * 2.0)
			spots.append("%d,%d" % [roundi(p.x), roundi(p.y)])
		print("SHOTPOS %s jugador %d,%d aliados %s" % [shot, roundi(at.x), roundi(at.y), " ".join(spots)])

	## La formación en un campo de verdad, con su decorado (pueblos, setos, colinas, lomas): una
	## misión de la campaña sin enemigos en la que un piloto automático lleva el tanque del
	## jugador por todo el mapa, con paradas. Es una prueba de exploración (el decorado cambia en
	## cada partida): no entra en la comprobación automática, se lanza con SHOTS_ONLY=mapaformacion.
	func _formation_map(front: int) -> void:
		await _start_game(GameSession.Mode.STORY, front, Fronts.Faction.ALLIES, Weather.Kind.SUNNY, 1, 5)
		var scene: Node = get_tree().current_scene
		var mode: StoryMode = scene.get_node("GameMode") as StoryMode
		# Sin enemigos ni bombardeos: solo interesa cómo se mueve el bando propio.
		mode.set_process(false)
		mode.raid_interval = Vector2.ZERO
		mode.allies_reserve = 0
		for tank in get_tree().get_nodes_in_group(&"tanks"):
			if tank.team != GameMode.PLAYER_TEAM:
				# Dormido y fuera del campo, no borrado: un proyectil suyo en vuelo aún lo nombra.
				tank.get_node("AIBrain").process_mode = Node.PROCESS_MODE_DISABLED
				tank.process_mode = Node.PROCESS_MODE_DISABLED
				tank.remove_from_group(&"tanks")
				tank.global_position = Vector3(0.0, -200.0, 0.0)
		var leader: Tank = _player_tank()
		scene.get_node("PlayerInputSource").process_mode = Node.PROCESS_MODE_DISABLED
		var pilot := AIBrain.new()
		pilot.name = "Pilot"
		leader.add_child(pilot)
		pilot.setup(leader)
		pilot.remove_from_group(&"ai_brains")
		pilot.smart_nav = true
		pilot.hunt = false
		await get_tree().create_timer(1.5).timeout
		var allies: Array = _allies_alive()
		mode.toggle_follow()
		var stops: Array[Vector3] = [Vector3(0.0, 0.0, 70.0), Vector3(-90.0, 0.0, 30.0), Vector3(-100.0, 0.0, -70.0), Vector3(0.0, 0.0, -110.0), Vector3(100.0, 0.0, -50.0), Vector3(80.0, 0.0, 60.0), Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.0, 120.0)]
		var contact: float = 0.0
		var worst_pair: float = INF
		var worst_leader: float = INF
		var bad_stops: int = 0
		var seen_unstuck: Dictionary = {}
		Engine.time_scale = 4.0
		for stop_index in stops.size():
			var target: Vector3 = stops[stop_index]
			var clock: float = 0.0
			var hold: float = 0.0
			pilot.process_mode = Node.PROCESS_MODE_INHERIT
			pilot.order(target, 2.0, true)
			while hold < 20.0 and clock < 110.0:
				await get_tree().physics_frame
				var delta: float = get_physics_process_delta_time()
				clock += delta
				var to: Vector3 = target - leader.global_position
				to.y = 0.0
				if hold > 0.0 or to.length() < 8.0 or clock > 70.0:
					# Parada: el piloto suelta los mandos.
					pilot.process_mode = Node.PROCESS_MODE_DISABLED
					leader.drive_input = Vector2.ZERO
					leader.trigger_held = false
					hold += delta
				for i in allies.size():
					var from_leader: float = _flat_distance(allies[i], leader)
					worst_leader = minf(worst_leader, from_leader)
					if from_leader < 7.5:
						contact += delta
					for j in range(i + 1, allies.size()):
						var apart: float = _flat_distance(allies[i], allies[j])
						worst_pair = minf(worst_pair, apart)
						if apart < 6.5:
							contact += delta
					# Cada atasco, con lo que tenía delante.
					var ab: AIBrain = allies[i].get_node("AIBrain")
					if ab.unstuck_total != seen_unstuck.get(allies[i], 0):
						seen_unstuck[allies[i]] = ab.unstuck_total
						var grid: NavGrid = NavGrid.of(scene)
						var goal_dir: Vector3 = ab.objective - allies[i].global_position
						goal_dir.y = 0.0
						var hits: Array[String] = []
						for angle: float in [0.0, 0.5, -0.5, 1.2, -1.2]:
							var from: Vector3 = allies[i].global_position + Vector3.UP * 0.6
							var query := PhysicsRayQueryParameters3D.create(from, from + goal_dir.normalized().rotated(Vector3.UP, angle) * 14.0, 3)
							query.exclude = [allies[i].get_rid()]
							var hit: Dictionary = allies[i].get_world_3d().direct_space_state.intersect_ray(query)
							hits.append("-" if hit.is_empty() else "%s/%s a %.1f m" % [hit["collider"].get_parent().name, hit["collider"].name, from.distance_to(hit["position"])])
						var cells: String = ""
						for dz in range(-2, 3):
							for dx in range(-2, 3):
								cells += "." if grid.is_free_at(allies[i].global_position + Vector3(dx * 4.0, 0.0, dz * 4.0)) else "#"
							cells += " "
						print("MAPAFORMACION    atasco %d de %s en %s yendo a %s (%.0f m): delante %s | celdas %s" % [ab.unstuck_total, allies[i].stats.id, _xz(allies[i].global_position), _xz(ab.objective), goal_dir.length(), str(hits), cells])
			var nearest_pair: float = INF
			var nearest: float = INF
			var farthest: float = 0.0
			var moving: int = 0
			var ahead: int = 0
			var forward: Vector3 = mode.formation.heading if mode.formation != null else -leader.global_transform.basis.z
			for i in allies.size():
				var offset: Vector3 = allies[i].global_position - leader.global_position
				offset.y = 0.0
				nearest = minf(nearest, offset.length())
				farthest = maxf(farthest, offset.length())
				if offset.dot(forward) > 6.0:
					ahead += 1
				if Vector2(allies[i].velocity.x, allies[i].velocity.z).length() > 0.5:
					moving += 1
					var b: AIBrain = allies[i].get_node("AIBrain")
					print("MAPAFORMACION    sigue moviéndose: %s en %s, puesto %d %s (a %.1f m), estado %s%s, mando (%.2f, %.2f), vel %.1f, bloqueado %s, desatascos %d, libre el puesto: %s" % [allies[i].stats.id, _xz(allies[i].global_position), b.formation_slot, _xz(b.follow_point()), Vector2(b.follow_point().x - allies[i].global_position.x, b.follow_point().z - allies[i].global_position.z).length(), b.state_name(), " LEJOS" if b.follow_far else "", allies[i].drive_input.x, allies[i].drive_input.y, Vector2(allies[i].velocity.x, allies[i].velocity.z).length(), str(b._nav_blocked), b.unstuck_total, str(NavGrid.of(scene).is_free_at(b.follow_point()))])
				for j in range(i + 1, allies.size()):
					nearest_pair = minf(nearest_pair, _flat_distance(allies[i], allies[j]))
			var ok: bool = nearest_pair >= 11.0 and nearest >= 11.0 and farthest <= 60.0 and ahead == 0 and moving == 0
			if not ok:
				bad_stops += 1
			print("MAPAFORMACION %-13s parada %d en %s (tardó %.0f s): entre aliados %.1f m | al líder de %.1f a %.1f m | delante %d | aún moviéndose %d  %s" % [Fronts.NAMES[front], stop_index + 1, _xz(leader.global_position), clock - hold, nearest_pair, nearest, farthest, ahead, moving, "OK" if ok else "MAL"])
		Engine.time_scale = 1.0
		var unstuck: int = pilot.unstuck_total
		var ally_unstuck: int = 0
		for ally: Tank in allies:
			if is_instance_valid(ally):
				ally_unstuck += (ally.get_node("AIBrain") as AIBrain).unstuck_total
		print("MAPAFORMACION %-13s %d aliados | paradas mal %d de %d | por el camino: mínimo entre aliados %.1f m, al líder %.1f m, pegados %.1f s | desatascos: aliados %d, piloto %d" % [Fronts.NAMES[front], allies.size(), bad_stops, stops.size(), worst_pair, worst_leader, contact, ally_unstuck, unstuck])
		GameSession.debug_weather = -1

	func _xz(v: Vector3) -> String:
		return "(%.0f, %.0f)" % [v.x, v.z] if v.length() > 1.5 else "(%.2f, %.2f)" % [v.x, v.z]

	func _flat_distance(a: Node3D, b: Node3D) -> float:
		return Vector2(a.global_position.x - b.global_position.x, a.global_position.z - b.global_position.z).length()

	func _secs(value: float) -> String:
		return "a los %.0f s" % value if value >= 0.0 else "NUNCA"

	func _wall(stage: Node3D, pos: Vector3, size: Vector3) -> void:
		var block := PropFactory.block(size)
		block.position = pos
		stage.add_child(block)
