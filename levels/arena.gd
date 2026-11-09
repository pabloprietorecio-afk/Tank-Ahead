extends Node3D
## Arena de la Fase 2: suelo con rejilla, obstáculos, jugador y oleadas de enemigos.

const ARENA_HALF: float = 200.0
const OBSTACLE_COUNT: int = 14
const SAFE_RADIUS: float = 25.0

var _player: Tank
var _hud: Hud
var _director: MatchDirector
var _obstacle_rects: Array[Rect2] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 7
	_build_environment()
	_build_ground()
	_build_walls()
	_build_obstacles()
	_spawn_player()
	_build_director()
	_build_ui()


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	env.fog_enabled = true
	env.fog_light_color = Color(0.0, 0.06, 0.02)
	env.fog_density = 0.008
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)


func _build_ground() -> void:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(ARENA_HALF * 2.0 + 20.0, ARENA_HALF * 2.0 + 20.0)
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


func _add_block(center: Vector3, size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.position = center
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.add_child(VectorMaterials.make_box(size, color))
	add_child(body)


func _build_walls() -> void:
	var length: float = ARENA_HALF * 2.0
	var height: float = 8.0
	var thickness: float = 2.0
	_add_block(Vector3(0.0, height * 0.5, -ARENA_HALF), Vector3(length, height, thickness), VectorMaterials.GREEN)
	_add_block(Vector3(0.0, height * 0.5, ARENA_HALF), Vector3(length, height, thickness), VectorMaterials.GREEN)
	_add_block(Vector3(-ARENA_HALF, height * 0.5, 0.0), Vector3(thickness, height, length), VectorMaterials.GREEN)
	_add_block(Vector3(ARENA_HALF, height * 0.5, 0.0), Vector3(thickness, height, length), VectorMaterials.GREEN)


func _build_obstacles() -> void:
	var placed: int = 0
	while placed < OBSTACLE_COUNT:
		var size := Vector3(_rng.randf_range(4.0, 14.0), _rng.randf_range(3.0, 22.0), _rng.randf_range(4.0, 14.0))
		var pos := Vector2(_rng.randf_range(-ARENA_HALF + 15.0, ARENA_HALF - 15.0), _rng.randf_range(-ARENA_HALF + 15.0, ARENA_HALF - 15.0))
		if pos.length() < SAFE_RADIUS + size.x:
			continue
		_add_block(Vector3(pos.x, size.y * 0.5, pos.y), size, VectorMaterials.GREEN)
		_obstacle_rects.append(Rect2(pos - Vector2(size.x, size.z) * 0.5 - Vector2(4.0, 4.0), Vector2(size.x, size.z) + Vector2(8.0, 8.0)))
		placed += 1


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


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var touch := TouchControls.new()
	layer.add_child(touch)

	_hud = Hud.new()
	_hud.tank = _player
	_hud.director = _director
	layer.add_child(_hud)

	var input_source := PlayerInputSource.new()
	input_source.tank = _player
	input_source.touch = touch
	add_child(input_source)
