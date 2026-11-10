extends Node
## Herramienta de verificación (no va en el APK): recorre escenas de muestra y partidas de
## cada frente y guarda capturas en res://shots_out. La usa el flujo .github/workflows/verify.yml
## para comprobar el aspecto del juego con un renderizador por software.


func _ready() -> void:
	var runner := Runner.new()
	runner.name = "ShotRunner"
	get_tree().root.add_child.call_deferred(runner)


class Runner extends Node:

	var _dir: String
	var _unreachable: int = 0
	var _camera: Camera3D
	var _stage: Node3D

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		_dir = ProjectSettings.globalize_path("res://shots_out")
		DirAccess.make_dir_recursive_absolute(_dir)
		_run.call_deferred()

	func _run() -> void:
		await _frames(2)
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
		if only.contains("nav"):
			await _nav()
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
		# Enemigos destacados con el borde azul, vistos de cerca.
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

	func _menu() -> void:
		get_tree().change_scene_to_file("res://levels/main_menu.tscn")
		await _frames(3)
		await get_tree().create_timer(2.0).timeout
		await _snap("menu")

	## Datos de la campaña: todas las listas completas y con sus campos.
	func _campaign() -> void:
		var total: int = 0
		for faction in 2:
			for choice in 4:
				var list: Array[Dictionary] = Campaign.missions(faction, choice)
				var expected: int = Campaign.PER_CAMPAIGN * (3 if choice == GameSession.FRONT_MIXED else 1)
				if list.size() != expected:
					push_error("Campaña %d/%d: %d misiones, se esperaban %d" % [faction, choice, list.size(), expected])
				for mission in list:
					total += 1
					for key in ["title", "type", "briefing", "front"]:
						if not mission.has(key):
							push_error("Misión sin «%s»: %s" % [key, mission])
					if not mission["type"] in ["assault", "destroy", "sabotage", "defend", "boss", "liberate", "breakthrough"]:
						push_error("Tipo de misión desconocido: %s" % mission["type"])
		print("CAMPAIGN OK ", total)

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
			var point: Vector3 = target.global_position
			var problem: String = ""
			if absf(point.x) > 196.0 or absf(point.z) > 196.0:
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

	func _wall(stage: Node3D, pos: Vector3, size: Vector3) -> void:
		var block := PropFactory.block(size)
		block.position = pos
		stage.add_child(block)
