class_name SurvivalMode
extends GameMode
## Supervivencia: oleadas sin fin que crecen poco a poco. Termina cuando destruyen al jugador.

const MAX_ALIVE_LIMIT: int = 5
const WAVE_PAUSE: float = 4.0
const SPAWN_MIN: float = 80.0
const SPAWN_MAX: float = 150.0
const REPAIR_PER_WAVE: float = 40.0
const WAVE_BONUS: int = 250

var wave: int = 0
var alive: int = 0

var _pending: Array[TankStats] = []
var _pause: float = 2.0
var _wave_active: bool = false
var _seen_types: Dictionary = {}
var _intro_queue: Array[TankStats] = []
var _intro_timer: float = 0.0


func start(player_tank: Tank, world_root: Node3D) -> void:
	super.start(player_tank, world_root)
	message.emit("%s — PREPÁRATE" % Fronts.NAMES[front], false)


func raids_active() -> bool:
	return wave >= 2


func status_text() -> String:
	return "PUNTOS %d   OLEADA %d   ENEMIGOS %d" % [score, wave, alive]


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
	var pool: Array[TankStats] = roster(ENEMY_TEAM)
	# El tipo recién desbloqueado aparece siempre en su primera oleada.
	for stats in pool:
		if stats.unlock_wave == n and stats.cost <= budget:
			list.append(stats)
			budget -= stats.cost
	while budget > 0:
		var options: Array[TankStats] = []
		var weights: Array[float] = []
		for stats in pool:
			if stats.unlock_wave <= n and stats.cost <= budget:
				options.append(stats)
				weights.append(1.0 + float(stats.unlock_wave) / 4.0)
		if options.is_empty():
			break
		var pick: TankStats = options[_weighted_index(weights)]
		list.append(pick)
		budget -= pick.cost
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
		if not _seen_types.has(stats.id):
			_seen_types[stats.id] = true
			_intro_queue.append(stats)
	_intro_timer = 3.0
	_wave_active = true
	message.emit("OLEADA %d — %d ENEMIGOS" % [wave, _pending.size()], true)


func _end_wave() -> void:
	_wave_active = false
	_pause = WAVE_PAUSE
	score += WAVE_BONUS
	player.health.heal(REPAIR_PER_WAVE)
	GameSession.record_wave(wave)
	message.emit("OLEADA %d SUPERADA  +%d  BLINDAJE REPARADO" % [wave, WAVE_BONUS], false)
	# Cada 4 oleadas se repone el arsenal especial.
	if wave % 4 == 0:
		missiles = 2
		strikes = 1
		message.emit("ARSENAL REPUESTO: 2 MISILES Y 1 BOMBARDEO", false)


func _spawn(stats: TankStats) -> void:
	var origin := Vector2(player.global_position.x, player.global_position.z)
	var point: Vector2 = free_point_near(origin, SPAWN_MIN, SPAWN_MAX)
	spawn_tank(stats, ENEMY_TEAM, point, randf() * TAU)
	alive += 1


func _on_tank_destroyed(tank: Tank, killer: Node) -> void:
	super._on_tank_destroyed(tank, killer)
	if tank.team == ENEMY_TEAM:
		alive -= 1


func _on_player_destroyed(_tank: Tank, _killer: Node) -> void:
	GameSession.record_wave(wave)
	finish(false, "TANQUE DESTRUIDO", "PUNTOS %d   OLEADA %d   (RÉCORD %d)" % [score, wave, GameSession.best_wave()])
