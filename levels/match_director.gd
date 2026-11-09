class_name MatchDirector
extends Node
## Dirige la partida: oleadas, puntuación, avisos y fin de juego.
## No conoce los detalles de la IA: solo crea tanques y escucha sus señales.

signal score_changed(score: int)
signal wave_changed(wave: int)
signal message(text: String, urgent: bool)
signal game_over(score: int, wave: int)

const MAX_ALIVE: int = 5
const WAVE_PAUSE: float = 4.0
const SPAWN_MIN: float = 80.0
const SPAWN_MAX: float = 150.0
const REPAIR_PER_WAVE: float = 30.0
const WAVE_BONUS: int = 250

const LIGHT := preload("res://data/tanks/light_tank.tres")
const HEAVY := preload("res://data/tanks/heavy_tank.tres")
const SCOUT := preload("res://data/tanks/scout.tres")

var player: Tank
var world: Node
## Callable(Vector2) -> bool. Indica si un punto de la arena es libre.
var is_free_point: Callable = func(_p: Vector2) -> bool: return true

var score: int = 0
var wave: int = 0
var is_over: bool = false
var alive: int = 0

var _pending: Array[TankStats] = []
var _pause: float = 2.0
var _wave_active: bool = false


func start(player_tank: Tank, world_root: Node) -> void:
	player = player_tank
	world = world_root
	player.destroyed.connect(_on_player_destroyed)
	score_changed.emit(score)
	message.emit("SECTOR LIMPIO. PREPÁRATE", false)


func _process(delta: float) -> void:
	if is_over:
		return
	if not _wave_active:
		_pause -= delta
		if _pause <= 0.0:
			_begin_wave()
		return
	while alive < MAX_ALIVE and not _pending.is_empty():
		_spawn(_pending.pop_back())
	if alive == 0 and _pending.is_empty():
		_end_wave()


func wave_composition(n: int) -> Array[TankStats]:
	var list: Array[TankStats] = []
	for i in 1 + n:
		list.append(LIGHT)
	for i in n / 2:
		list.append(SCOUT)
	for i in (n - 1) / 2:
		list.append(HEAVY)
	list.shuffle()
	return list


func _begin_wave() -> void:
	wave += 1
	_pending = wave_composition(wave)
	_wave_active = true
	wave_changed.emit(wave)
	message.emit("OLEADA %d — %d ENEMIGOS" % [wave, _pending.size()], true)


func _end_wave() -> void:
	_wave_active = false
	_pause = WAVE_PAUSE
	score += WAVE_BONUS
	score_changed.emit(score)
	player.health.heal(REPAIR_PER_WAVE)
	message.emit("OLEADA %d SUPERADA  +%d  BLINDAJE REPARADO" % [wave, WAVE_BONUS], false)


func _spawn(stats: TankStats) -> void:
	var enemy := Tank.new()
	enemy.name = "Enemy"
	enemy.stats = stats
	enemy.team = 1
	enemy.position = Vector3(0.0, 0.2, 0.0)
	var point := _find_spawn_point()
	enemy.position = Vector3(point.x, 0.2, point.y)
	enemy.rotation.y = randf() * TAU
	world.add_child(enemy)
	var brain := AIBrain.new()
	brain.name = "AIBrain"
	enemy.add_child(brain)
	brain.setup(enemy, player)
	enemy.destroyed.connect(_on_enemy_destroyed)
	alive += 1


func _find_spawn_point() -> Vector2:
	var origin := Vector2(player.global_position.x, player.global_position.z)
	var point := origin
	for attempt in 30:
		var angle: float = randf() * TAU
		point = origin + Vector2(cos(angle), sin(angle)) * randf_range(SPAWN_MIN, SPAWN_MAX)
		point = point.clampf(-175.0, 175.0)
		if point.distance_to(origin) >= SPAWN_MIN * 0.6 and is_free_point.call(point):
			break
	return point


func _on_enemy_destroyed(tank: Tank, killer: Node) -> void:
	alive -= 1
	if killer == player:
		score += tank.stats.score_value
		score_changed.emit(score)
		message.emit("%s DESTRUIDO  +%d" % [tank.stats.display_name, tank.stats.score_value], false)


func _on_player_destroyed(_tank: Tank, _killer: Node) -> void:
	is_over = true
	message.emit("TANQUE DESTRUIDO", true)
	game_over.emit(score, wave)
