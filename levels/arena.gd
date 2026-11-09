extends Node3D
## Campo de batalla: monta el escenario del frente elegido, el modo de juego, el jugador,
## el clima y la interfaz.

const ARENA_HALF: float = 200.0
const SAFE_RADIUS: float = 20.0

var _player: Tank
var _hud: Hud
var _mode: GameMode
var _env: Environment
var _sky_material: ProceduralSkyMaterial
var _sun: DirectionalLight3D
var _obstacle_rects: Array[Rect2] = []
var _rng := RandomNumberGenerator.new()
var _spawn_point: Vector2


func _ready() -> void:
	_rng.randomize()
	GameSettings.ensure_loaded()
	AudioSetup.ensure()
	GameSession.resolve_front()
	_mode = _create_mode()
	_mode.name = "GameMode"
	var spawn: Transform3D = _mode.player_spawn()
	_spawn_point = Vector2(spawn.origin.x, spawn.origin.z)
	_obstacle_rects.append_array(_mode.reserved_zones())
	_build_environment()
	_build_ground()
	_build_walls()
	_build_scenery()
	_spawn_player(spawn)
	_mode.is_free_point = func(p: Vector2) -> bool:
		for rect in _obstacle_rects:
			if rect.has_point(p):
				return false
		return true
	add_child(_mode)
	_build_weather()
	var spawner := PickupSpawner.new()
	spawner.name = "PickupSpawner"
	spawner.player = _player
	spawner.is_free_point = _mode.is_free_point
	add_child(spawner)
	_build_ui()
	var music := AudioSetup.music_player("res://assets/music/battle_theme.ogg")
	music.volume_db = -6.0
	add_child(music)
	_mode.start(_player, self)


func _create_mode() -> GameMode:
	match GameSession.mode:
		GameSession.Mode.CTF:
			return CtfMode.new()
		GameSession.Mode.STORY:
			return StoryMode.new()
		_:
			return SurvivalMode.new()


func _build_environment() -> void:
	_sky_material = ProceduralSkyMaterial.new()
	var sky := Sky.new()
	sky.sky_material = _sky_material
	_env = Environment.new()
	_env.background_mode = Environment.BG_SKY
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_env.ambient_light_energy = 0.6
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.fog_enabled = true
	_env.fog_sky_affect = 0.6
	_env.glow_enabled = true
	_env.glow_intensity = 0.6
	_env.glow_bloom = 0.05
	var world_env := WorldEnvironment.new()
	world_env.environment = _env
	add_child(world_env)

	_sun = DirectionalLight3D.new()
	_sun.name = "Sun"
	_sun.rotation = Vector3(deg_to_rad(-28.0), deg_to_rad(-35.0), 0.0)
	_sun.shadow_enabled = GameSettings.shadows
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	_sun.directional_shadow_max_distance = 120.0
	_sun.shadow_blur = 1.5
	add_child(_sun)


func _build_ground() -> void:
	var material: ShaderMaterial = VectorMaterials.ground()
	var colors: Array[Color] = Fronts.ground_colors(GameSession.front)
	material.set_shader_parameter("grass", colors[0])
	material.set_shader_parameter("dry_grass", colors[1])
	material.set_shader_parameter("dirt", colors[2])
	material.set_shader_parameter("gravel", colors[3])
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(ARENA_HALF * 2.0 + 400.0, ARENA_HALF * 2.0 + 400.0)
	var ground := MeshInstance3D.new()
	ground.mesh = mesh
	ground.material_override = material
	add_child(ground)

	var body := StaticBody3D.new()
	body.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(ARENA_HALF * 2.0 + 20.0, 2.0, ARENA_HALF * 2.0 + 20.0)
	shape.shape = box
	shape.position.y = -1.0
	body.add_child(shape)
	add_child(body)


func _add_wall(center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.position = center
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.add_child(VectorMaterials.make_box(size, Color(0.45, 0.43, 0.4), 2, 2.0))
	add_child(body)


func _build_walls() -> void:
	var length: float = ARENA_HALF * 2.0
	var height: float = 2.5
	var thickness: float = 2.0
	_add_wall(Vector3(0.0, height * 0.5, -ARENA_HALF), Vector3(length, height, thickness))
	_add_wall(Vector3(0.0, height * 0.5, ARENA_HALF), Vector3(length, height, thickness))
	_add_wall(Vector3(-ARENA_HALF, height * 0.5, 0.0), Vector3(thickness, height, length))
	_add_wall(Vector3(ARENA_HALF, height * 0.5, 0.0), Vector3(thickness, height, length))


## Busca un sitio libre de radio `radius`. Devuelve Vector2.INF si no lo encuentra.
func _free_spot(radius: float, margin: float = 15.0) -> Vector2:
	for attempt in 40:
		var pos := Vector2(_rng.randf_range(-ARENA_HALF + margin, ARENA_HALF - margin), _rng.randf_range(-ARENA_HALF + margin, ARENA_HALF - margin))
		if pos.distance_to(_spawn_point) < SAFE_RADIUS + radius:
			continue
		var rect := Rect2(pos - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)
		var blocked: bool = false
		for other in _obstacle_rects:
			if other.intersects(rect):
				blocked = true
				break
		if not blocked:
			return pos
	return Vector2.INF


func _place(prop: Node3D, pos: Vector2, radius: float, yaw: float = 0.0) -> void:
	prop.position = Vector3(pos.x, 0.0, pos.y)
	prop.rotation.y = yaw
	add_child(prop)
	_obstacle_rects.append(Rect2(pos - Vector2.ONE * (radius + 3.0), Vector2.ONE * (radius + 3.0) * 2.0))


## Coloca varios objetos alrededor de un centro sin registrar obstáculos individuales.
func _scatter(center: Vector2, count: int, spread: float, factory: Callable) -> void:
	for i in count:
		var prop: Node3D = factory.call()
		var offset := Vector2(_rng.randf_range(-spread, spread), _rng.randf_range(-spread, spread))
		prop.position = Vector3(center.x + offset.x, 0.0, center.y + offset.y)
		prop.rotation.y = _rng.randf() * TAU
		add_child(prop)
	_obstacle_rects.append(Rect2(center - Vector2.ONE * (spread + 3.0), Vector2.ONE * (spread + 3.0) * 2.0))


func _build_scenery() -> void:
	var front: int = GameSession.front
	PropFactory.mountain_color = Fronts.mountain_color(front)
	# Relieve lejano fuera de la arena.
	var desert: bool = front == Fronts.Id.AFRICA
	for i in 14:
		var angle: float = TAU * i / 14.0 + _rng.randf_range(-0.1, 0.1)
		var dist: float = ARENA_HALF + _rng.randf_range(60.0, 140.0)
		var height: float = _rng.randf_range(12.0, 30.0) if desert or front == Fronts.Id.KURSK else _rng.randf_range(20.0, 45.0)
		var mountain := PropFactory.mountain(_rng.randf_range(45.0, 70.0), height, _rng.randi_range(6, 9))
		mountain.position = Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
		mountain.rotation.y = _rng.randf() * TAU
		add_child(mountain)
	# Colinas o dunas dentro.
	for i in (5 if desert else 3):
		var radius: float = _rng.randf_range(10.0, 18.0)
		var pos := _free_spot(radius)
		if pos != Vector2.INF:
			_place(PropFactory.mountain(radius, _rng.randf_range(4.0, 7.0) if desert else _rng.randf_range(7.0, 13.0), 10 if desert else 7), pos, radius, _rng.randf() * TAU)
	match front:
		Fronts.Id.AFRICA:
			_scenery_africa()
		Fronts.Id.KURSK:
			_scenery_kursk()
		_:
			_scenery_normandy()
	# Ruinas con bidones, rocas y depósitos de combustible abandonados en todos los frentes.
	for r in 4:
		var pos := _free_spot(8.0)
		if pos == Vector2.INF:
			continue
		_place(PropFactory.ruin(_rng.randf_range(8.0, 14.0)), pos, 7.0, _rng.randf() * TAU)
		for b in _rng.randi_range(1, 3):
			var barrel := PropFactory.barrel()
			barrel.position = Vector3(pos.x + _rng.randf_range(-5.0, 5.0), 0.0, pos.y + _rng.randf_range(2.0, 5.0))
			add_child(barrel)
	# Edificios con premio (anillo verde en el radar).
	var prizes: Array[Callable] = [StructureFactory.radio_mast, StructureFactory.water_tower, StructureFactory.flak_gun, StructureFactory.flak_gun, StructureFactory.command_tent]
	for factory in prizes:
		var pos := _free_spot(6.0)
		if pos != Vector2.INF:
			_place(factory.call(), pos, 6.0, _rng.randf() * TAU)
	for i in (25 if desert else 12):
		var radius: float = _rng.randf_range(0.8, 2.5)
		var pos := _free_spot(radius)
		if pos != Vector2.INF:
			_place(PropFactory.rock(radius), pos, radius)


func _village(center: Vector2, houses: int, house_factory: Callable) -> void:
	for h in houses:
		var offset := Vector2(_rng.randf_range(-20.0, 20.0), _rng.randf_range(-20.0, 20.0))
		var prop: Node3D = house_factory.call()
		prop.position = Vector3(center.x + offset.x, 0.0, center.y + offset.y)
		prop.rotation.y = round(_rng.randf() * 4.0) * PI * 0.5
		add_child(prop)
	_obstacle_rects.append(Rect2(center - Vector2(28.0, 28.0), Vector2(56.0, 56.0)))


func _house_size() -> Vector3:
	return Vector3(_rng.randf_range(5.0, 8.0), _rng.randf_range(3.5, 5.0), _rng.randf_range(6.0, 9.0))


func _scenery_normandy() -> void:
	for v in 2:
		var center := _free_spot(30.0)
		if center == Vector2.INF:
			continue
		if v == 0:
			var church := PropFactory.church()
			church.position = Vector3(center.x, 0.0, center.y)
			add_child(church)
			_village(center + Vector2(0.0, 22.0), 2, func() -> Node3D: return PropFactory.house(_house_size()))
		else:
			_village(center, 4, func() -> Node3D: return PropFactory.house(_house_size()))
		for l in 3:
			var lamp := PropFactory.lamp_post()
			lamp.position = Vector3(center.x + _rng.randf_range(-20.0, 20.0), 0.0, center.y + _rng.randf_range(-20.0, 20.0))
			add_child(lamp)
	# Setos del bocage.
	for i in 12:
		var length: float = _rng.randf_range(18.0, 34.0)
		var pos := _free_spot(length * 0.5)
		if pos != Vector2.INF:
			_place(PropFactory.hedgerow(length), pos, length * 0.5, round(_rng.randf() * 2.0) * PI * 0.5)
	# Huertos de manzanos.
	for o in 5:
		var center := _free_spot(12.0)
		if center != Vector2.INF:
			_scatter(center, _rng.randi_range(5, 9), 10.0, func() -> Node3D: return PropFactory.apple_tree(_rng.randf_range(4.0, 6.0)))
	for f in 6:
		var pos := _free_spot(6.0)
		if pos != Vector2.INF:
			_place(PropFactory.fence(12.0), pos, 6.0, _rng.randf() * TAU)


func _scenery_africa() -> void:
	for v in 2:
		var center := _free_spot(30.0)
		if center == Vector2.INF:
			continue
		_village(center, 4, func() -> Node3D: return PropFactory.desert_house(Vector3(_rng.randf_range(5.0, 8.0), _rng.randf_range(3.0, 4.5), _rng.randf_range(5.0, 8.0))))
		_scatter(center + Vector2(32.0, 0.0), 6, 8.0, func() -> Node3D: return PropFactory.palm(_rng.randf_range(7.0, 10.0)))
	for i in 10:
		var pos := _free_spot(5.0)
		if pos != Vector2.INF:
			_place(PropFactory.sandbags(_rng.randf_range(6.0, 10.0)), pos, 5.0, _rng.randf() * TAU)
	for i in 6:
		var pos := _free_spot(4.0)
		if pos != Vector2.INF:
			_scatter(pos, 3, 4.0, func() -> Node3D: return PropFactory.palm(_rng.randf_range(6.0, 9.0)))


func _scenery_kursk() -> void:
	for v in 2:
		var center := _free_spot(30.0)
		if center == Vector2.INF:
			continue
		_village(center, 5, func() -> Node3D: return PropFactory.izba(Vector3(_rng.randf_range(5.0, 7.0), _rng.randf_range(3.0, 4.0), _rng.randf_range(6.0, 8.0))))
		for f in 3:
			var fence := PropFactory.fence(10.0)
			fence.position = Vector3(center.x + _rng.randf_range(-25.0, 25.0), 0.0, center.y + _rng.randf_range(-25.0, 25.0))
			fence.rotation.y = _rng.randf() * TAU
			add_child(fence)
	for g in 7:
		var center := _free_spot(12.0)
		if center != Vector2.INF:
			_scatter(center, _rng.randi_range(5, 9), 10.0, func() -> Node3D: return PropFactory.birch(_rng.randf_range(7.0, 11.0)))
	for i in 16:
		var pos := _free_spot(3.0)
		if pos != Vector2.INF:
			_place(PropFactory.haystack(), pos, 3.0)
	# Líneas de erizos antitanque.
	for line in 4:
		var start := _free_spot(14.0)
		if start == Vector2.INF:
			continue
		var dir := Vector2.from_angle(_rng.randf() * TAU)
		for i in 6:
			var p: Vector2 = start + dir * (i - 2.5) * 4.5
			var hog := PropFactory.hedgehog()
			hog.position = Vector3(p.x, 0.0, p.y)
			hog.rotation.y = _rng.randf() * TAU
			add_child(hog)
		_obstacle_rects.append(Rect2(start - Vector2(15.0, 15.0), Vector2(30.0, 30.0)))


func _spawn_player(spawn: Transform3D) -> void:
	_player = Tank.new()
	_player.name = "PlayerTank"
	_player.is_player = true
	_player.team = GameMode.PLAYER_TEAM
	_player.stats = Fronts.player_stats(GameSession.front, GameSession.faction)
	_player.paint = Fronts.paint(GameSession.front, GameSession.faction, _player.stats.nation)
	_player.transform = spawn
	add_child(_player)


func _build_weather() -> void:
	var weather := Weather.new()
	weather.name = "Weather"
	add_child(weather)
	var options: Array[int] = Fronts.weathers(GameSession.front)
	weather.setup(_env, _sky_material, _sun, _player, VectorMaterials.ground(), options[_rng.randi() % options.size()], GameSession.front)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var touch := TouchControls.new()
	layer.add_child(touch)

	var input_source := PlayerInputSource.new()
	input_source.name = "PlayerInputSource"
	input_source.tank = _player
	input_source.touch = touch
	add_child(input_source)

	_hud = Hud.new()
	_hud.tank = _player
	_hud.director = _mode
	_hud.touch = touch
	_hud.input_source = input_source
	_hud.weather = get_node("Weather")
	layer.add_child(_hud)

	var radar := Radar.new()
	radar.player = _player
	radar.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	radar.offset_left = -206.0
	radar.offset_right = -18.0
	radar.offset_top = 104.0
	radar.offset_bottom = 292.0
	layer.add_child(radar)
