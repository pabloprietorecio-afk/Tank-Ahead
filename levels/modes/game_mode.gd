class_name GameMode
extends Node
## Base de los modos de juego. Crea tanques de cada bando, lleva la puntuación y decide
## cuándo termina la partida. El HUD solo conoce esta interfaz.

signal message(text: String, urgent: bool)
signal ended(victory: bool, title: String, detail: String)

const PLAYER_TEAM: int = 0
const ENEMY_TEAM: int = 1

var player: Tank
var world: Node3D
var front: int
var is_over: bool = false
var score: int = 0
## Callable(Vector2) -> bool: punto libre de obstáculos.
var is_free_point: Callable = func(_p: Vector2) -> bool: return true

var _rosters: Dictionary = {}


func _init() -> void:
	front = GameSession.front
	_rosters[PLAYER_TEAM] = Fronts.roster(front, GameSession.faction)
	_rosters[ENEMY_TEAM] = Fronts.roster(front, GameSession.enemy_faction())


func roster(team: int) -> Array[TankStats]:
	return _rosters[team]


func faction_of(team: int) -> int:
	return GameSession.faction if team == PLAYER_TEAM else GameSession.enemy_faction()


## Dónde aparece el jugador.
func player_spawn() -> Transform3D:
	return Transform3D(Basis(), Vector3(0.0, 0.2, 0.0))


## Zonas que el escenario debe dejar libres (bases, posiciones a defender).
func reserved_zones() -> Array[Rect2]:
	return []


func start(player_tank: Tank, world_root: Node3D) -> void:
	player = player_tank
	world = world_root
	player.destroyed.connect(_on_player_destroyed)


func status_text() -> String:
	return "PUNTOS %d" % score


## Crea un tanque controlado por la máquina.
func spawn_tank(stats: TankStats, team: int, pos: Vector2, yaw: float = 0.0) -> Tank:
	var tank := Tank.new()
	tank.name = "Tank"
	tank.stats = stats
	tank.team = team
	tank.paint = Fronts.paint(front, faction_of(team), stats.nation)
	tank.position = Vector3(pos.x, 0.2, pos.y)
	tank.rotation.y = yaw
	world.add_child(tank)
	var brain := AIBrain.new()
	brain.name = "AIBrain"
	tank.add_child(brain)
	brain.setup(tank)
	tank.destroyed.connect(_on_tank_destroyed)
	return tank


## Punto libre cerca de `center` (radio entre min y max).
func free_point_near(center: Vector2, min_radius: float, max_radius: float) -> Vector2:
	var point := center
	for attempt in 30:
		point = center + Vector2.from_angle(randf() * TAU) * randf_range(min_radius, max_radius)
		point = point.clampf(-180.0, 180.0)
		if is_free_point.call(point):
			return point
	return point


func finish(victory: bool, title: String, detail: String) -> void:
	if is_over:
		return
	is_over = true
	ended.emit(victory, title, detail)


func _on_tank_destroyed(tank: Tank, killer: Node) -> void:
	if killer == player and tank.team != PLAYER_TEAM:
		score += tank.stats.score_value
		message.emit("%s DESTRUIDO  +%d" % [tank.stats.display_name, tank.stats.score_value], false)


func _on_player_destroyed(_tank: Tank, _killer: Node) -> void:
	finish(false, "TANQUE DESTRUIDO", "PUNTOS %d" % score)
