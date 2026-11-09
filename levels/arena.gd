extends Node3D
## Arena: terreno texturizado, montañas, pueblo con casas y vallas, bosquecillos,
## bloques, clima aleatorio, jugador y oleadas de enemigos.

const ARENA_HALF: float = 200.0
const SAFE_RADIUS: float = 25.0

var _player: Tank
var _hud: Hud
var _director: MatchDirector
var _env: Environment
var _obstacle_rects: Array[Rect2] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_build_environment()
	_build_ground()
	_build_walls()
	_build_scenery()
	_spawn_player()
	_build_director()
	_build_weather()
	_build_ui()


func _build_environment() -> void:
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = Color.BLACK
	_env.fog_enabled = true
	_env.fog_light_color = Color(0.0, 0.06, 0.02)
	_env.fog_density = 0.008
	var world_env := WorldEnvironment.new()
	world_env.environment = _env
	add_child(world_env)


func _build_ground() -> void:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(ARENA_HALF * 2.0 + 400.0, ARENA_HALF * 2.0 + 400.0)
	var ground := MeshInstance3D.new()
	ground.mesh = mesh
	ground.material_override = VectorMaterials.ground()
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
	body.add_child(VectorMaterials.make_box(size, Color(0.2, 1.0, 0.33, 0.6)))
	add_child(body)


func _build_walls() -> void:
	var length: float = ARENA_HALF * 2.0
	var height: float = 3.0
	var thickness: float = 2.0
	_add_wall(Vector3(0.0, height * 0.5, -ARENA_HALF), Vector3(length, height, thickness))
	_add_wall(Vector3(0.0, height * 0.5, ARENA_HALF), Vector3(length, height, thickness))
	_add_wall(Vector3(-ARENA_HALF, height * 0.5, 0.0), Vector3(thickness, height, length))
	_add_wall(Vector3(ARENA_HALF, height * 0.5, 0.0), Vector3(thickness, height, length))


## Busca un sitio libre de radio `radius`. Devuelve Vector2.INF si no lo encuentra.
func _free_spot(radius: float, margin: float = 15.0) -> Vector2:
	for attempt in 40:
		var pos := Vector2(_rng.randf_range(-ARENA_HALF + margin, ARENA_HALF - margin), _rng.randf_range(-ARENA_HALF + margin, ARENA_HALF - margin))
		if pos.length() < SAFE_RADIUS + radius:
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


func _build_scenery() -> void:
	# Cordillera lejana, fuera de la arena (indestructible, como decorado).
	for i in 14:
		var angle: float = TAU * i / 14.0 + _rng.randf_range(-0.1, 0.1)
		var dist: float = ARENA_HALF + _rng.randf_range(60.0, 140.0)
		var mountain := PropFactory.mountain(_rng.randf_range(35.0, 60.0), _rng.randf_range(25.0, 60.0), _rng.randi_range(5, 8))
		mountain.position = Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
		mountain.rotation.y = _rng.randf() * TAU
		add_child(mountain)
	# Colinas dentro de la arena.
	for i in 3:
		var radius: float = _rng.randf_range(10.0, 16.0)
		var pos := _free_spot(radius)
		if pos != Vector2.INF:
			_place(PropFactory.mountain(radius, _rng.randf_range(8.0, 16.0)), pos, radius, _rng.randf() * TAU)
	# Pueblos: casas con vallas alrededor.
	for village in 2:
		var center := _free_spot(30.0)
		if center == Vector2.INF:
			continue
		for h in 3:
			var size := Vector3(_rng.randf_range(5.0, 8.0), _rng.randf_range(3.5, 5.0), _rng.randf_range(6.0, 9.0))
			var offset := Vector2(_rng.randf_range(-18.0, 18.0), _rng.randf_range(-18.0, 18.0))
			_place(PropFactory.house(size), center + offset, 5.0, round(_rng.randf() * 4.0) * PI * 0.5)
		for l in 4:
			var lamp := PropFactory.lamp_post()
			lamp.position = Vector3(center.x + _rng.randf_range(-20.0, 20.0), 0.0, center.y + _rng.randf_range(-20.0, 20.0))
			lamp.rotation.y = _rng.randf() * TAU
			add_child(lamp)
		for f in 4:
			var angle: float = TAU * f / 4.0 + 0.4
			var spot: Vector2 = center + Vector2(cos(angle), sin(angle)) * 27.0
			var fence := PropFactory.fence(10.0)
			fence.position = Vector3(spot.x, 0.0, spot.y)
			fence.rotation.y = -angle + PI * 0.5
			add_child(fence)
	# Bosquecillos.
	for grove in 6:
		var center := _free_spot(12.0)
		if center == Vector2.INF:
			continue
		for t in _rng.randi_range(4, 8):
			var tree := PropFactory.tree(_rng.randf_range(5.0, 9.0))
			var offset := Vector2(_rng.randf_range(-10.0, 10.0), _rng.randf_range(-10.0, 10.0))
			tree.position = Vector3(center.x + offset.x, 0.0, center.y + offset.y)
			add_child(tree)
		_obstacle_rects.append(Rect2(center - Vector2.ONE * 13.0, Vector2.ONE * 26.0))
	# Ruinas con bidones de combustible (explotan y dañan lo que haya cerca).
	for r in 5:
		var pos := _free_spot(8.0)
		if pos == Vector2.INF:
			continue
		_place(PropFactory.ruin(_rng.randf_range(8.0, 14.0)), pos, 7.0, _rng.randf() * TAU)
		for b in _rng.randi_range(1, 3):
			var barrel := PropFactory.barrel()
			barrel.position = Vector3(pos.x + _rng.randf_range(-5.0, 5.0), 0.0, pos.y + _rng.randf_range(2.0, 5.0))
			add_child(barrel)
	# Rocas sueltas.
	for i in 18:
		var radius: float = _rng.randf_range(0.8, 2.5)
		var pos := _free_spot(radius)
		if pos != Vector2.INF:
			_place(PropFactory.rock(radius), pos, radius)
	# Bloques y torres.
	for i in 10:
		var size := Vector3(_rng.randf_range(4.0, 12.0), _rng.randf_range(3.0, 18.0), _rng.randf_range(4.0, 12.0))
		var pos := _free_spot(maxf(size.x, size.z) * 0.5)
		if pos != Vector2.INF:
			_place(PropFactory.block(size), pos, maxf(size.x, size.z) * 0.5)


func _spawn_player() -> void:
	_player = Tank.new()
	_player.name = "PlayerTank"
	_player.is_player = true
	_player.stats = load("res://data/tanks/player_basic.tres")
	_player.position = Vector3(0.0, 0.2, 0.0)
	add_child(_player)


func _build_director() -> void:
	_director = MatchDirector.new()
	_director.name = "MatchDirector"
	_director.is_free_point = func(p: Vector2) -> bool:
		for rect in _obstacle_rects:
			if rect.has_point(p):
				return false
		return true
	add_child(_director)
	_director.start(_player, self)


func _build_weather() -> void:
	var weather := Weather.new()
	weather.name = "Weather"
	add_child(weather)
	weather.setup(_env, _player, VectorMaterials.ground())


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
	_hud.director = _director
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
