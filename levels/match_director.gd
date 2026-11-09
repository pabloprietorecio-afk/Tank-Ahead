class_name MatchDirector
extends Node
## Dirige la partida: oleadas, puntuación, avisos y fin de juego.
## No conoce los detalles de la IA: solo crea tanques y escucha sus señales.

signal score_changed(score: int)
signal wave_changed(wave: int)
signal message(text: String, urgent: bool)
signal game_over(score: int, wave: int)

const MAX_ALIVE_LIMIT: int = 5
const WAVE_PAUSE: float = 4.0
const SPAWN_MIN: float = 80.0
const SPAWN_MAX: float = 150.0
const REPAIR_PER_WAVE: float = 40.0
const WAVE_BONUS: int = 250

## Catálogo de enemigos: [ficha, coste en el presupuesto de la oleada, primera oleada en que aparece].
const ROSTER: Array = [
	[preload("res://data/tanks/scout.tres"), 1, 1],
	[preload("res://data/tanks/light_tank.tres"), 1, 1],
	[preload("res://data/tanks/sniper.tres"), 2, 3],
	[preload("res://data/tanks/heavy_tank.tres"), 3, 4],
	[preload("res://data/tanks/hunter.tres"), 2, 6],
	[preload("res://data/tanks/juggernaut.tres"), 5, 8],
]

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
var _seen_types: Dictionary = {}
var _intro_queue: Array[TankStats] = []
var _intro_timer: float = 0.0


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
	_intro_timer -= delta
	if _intro_timer <= 0.0 and not _intro_queue.is_empty():
		var stats: TankStats = _intro_queue.pop_front()
		message.emit("NUEVO ENEMIGO: %s — %s" % [stats.display_name, stats.description], true)
		_intro_timer = 4.0
	while alive < max_alive() and not _pending.is_empty():
		_spawn(_pending.pop_back())
	if alive == 0 and _pending.is_empty():
		_end_wave()


## Enemigos simultáneos: 2 al principio, sube de uno en uno cada 3 oleadas.
func max_alive() -> int:
	return mini(2 + (wave - 1) / 3, MAX_ALIVE_LIMIT)


## Presupuesto de amenaza que crece despacio: 2, 3, 3, 4, 4, 5...
func wave_budget(n: int) -> int:
	return 2 + n / 2


func wave_composition(n: int) -> Array[TankStats]:
	var list: Array[TankStats] = []
	var budget: int = wave_budget(n)
	# El tipo recién desbloqueado aparece siempre en su primera oleada.
	for entry in ROSTER:
		if entry[2] == n and entry[1] <= budget:
			list.append(entry[0])
			budget -= entry[1]
	while budget > 0:
		var options: Array = []
		var weights: Array[float] = []
		for entry in ROSTER:
			if entry[2] <= n and entry[1] <= budget:
				options.append(entry)
				# Los enemigos más recientes salen algo más a menudo que los básicos.
				weights.append(1.0 + float(entry[2]) / 4.0)
		if options.is_empty():
			break
		var pick: Array = options[_weighted_index(weights)]
		list.append(pick[0])
		budget -= pick[1]
	list.shuffle()
	return list


func _weighted_index(weights: Array[float]) -> int:
	var total: float = 0.0
	for w in weights:
		total += w
	var roll: float = randf() * total
	for i in weights.size():
		roll -= weights[i]
		if roll <= 0.0:
			return i
	return weights.size() - 1


func _begin_wave() -> void:
	wave += 1
	_pending = wave_composition(wave)
	for stats in _pending:
		if not _seen_types.has(stats.display_name):
			_seen_types[stats.display_name] = true
			_intro_queue.append(stats)
	_intro_timer = 3.0
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
