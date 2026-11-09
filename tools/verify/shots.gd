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
		if only == "" or only.contains("props"):
			await _props()
		if only == "" or only.contains("arena"):
			for front in 3:
				await _arena(front)
		if only == "" or only.contains("menu"):
			await _menu()
		print("SHOTS DONE")
		get_tree().quit()

	func _frames(count: int) -> void:
		for i in count:
			await get_tree().process_frame

	func _snap(shot: String) -> void:
		await _frames(3)
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
		for i in 4:
			var angle: float = TAU * i / 4.0 + 0.4
			_look(origin + Vector3(0.0, 3.0, 0.0), origin + Vector3(sin(angle) * 50.0, 4.0, cos(angle) * 50.0), 70.0)
			await _snap("arena_%d_view%d" % [front, i])

	func _menu() -> void:
		get_tree().change_scene_to_file("res://levels/main_menu.tscn")
		await _frames(3)
		await get_tree().create_timer(2.0).timeout
		await _snap("menu")
