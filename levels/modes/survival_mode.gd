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

## Fase aérea: cada AIR_EVERY oleadas (tras la 3, la 6, la 9…) el jugador pasa a una batería
## antiaérea de su bando y tiene AIR_PHASE_TIME segundos para derribar aviones. No entra de
## golpe: tras el «oleada superada» hay AIR_WARNING segundos de respiro. Con AIR_GOAL derribos
## se repone el bombardeo; si no pasa ni un avión, además un misil.
const AIR_PHASE_TIME: float = 28.0
const AIR_EVERY: int = 3
const AIR_WARNING: float = 3.5
const AIR_GOAL: int = 3
## Los aviones de esta fase van más deprisa que los de paso (no hay cámara lenta).
const AIR_PACE: float = 1.6
const AIR_SPAWN_GAP: float = 2.6
var _air_warning: float = -1.0
var _battery: AaBattery
var _air_kills: int = 0
var _air_total: int = 0
var air_phase: bool = false
var _air_left: float = 0.0
var _air_spawn_timer: float = 0.0
var _air_spawned: int = 0


func start(player_tank: Tank, world_root: Node3D) -> void:
	super.start(player_tank, world_root)
	message.emit(Loc.t("%s — PREPÁRATE") % Loc.t(Fronts.NAMES[front]), false)


func backdrop() -> Dictionary:
	return coast_backdrop(["n", "s", "e", "w"])


func raids_active() -> bool:
	return wave >= 2 and not air_phase


func strafes_active() -> bool:
	return wave >= 3 and not air_phase


func _status_normal() -> String:
	return Loc.t("PUNTOS %d   OLEADA %d   ENEMIGOS %d") % [score, wave, alive]


func _process(delta: float) -> void:
	if is_over:
		if air_phase:
			_end_air_phase()
		return
	if air_phase:
		_update_air_phase(delta)
		return
	if _air_warning >= 0.0:
		_air_warning -= delta
		if _air_warning < 0.0:
			_air_warning = -1.0
			_start_air_phase()
		return
	if not _wave_active:
		_pause -= delta
		if _pause <= 0.0:
			_begin_wave()
		return
	_intro_timer -= delta
	if _intro_timer <= 0.0 and not _intro_queue.is_empty():
		var stats: TankStats = _intro_queue.pop_front()
		message.emit(Loc.t("NUEVO ENEMIGO: %s — %s") % [stats.display_name, Loc.t(stats.description)], true)
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
	# Dificultad: en fácil sale uno menos; en difícil e inferno, uno o dos más por oleada.
	var extra: int = GameSettings.batch_extra()
	if extra < 0 and list.size() > 1:
		list.pop_back()
	for i in maxi(extra, 0):
		var unlocked: Array[TankStats] = pool.filter(func(s: TankStats) -> bool: return s.unlock_wave <= n)
		if not unlocked.is_empty():
			list.append(unlocked.pick_random())
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
	message.emit(Loc.t("OLEADA %d — %d ENEMIGOS") % [wave, _pending.size()], true)
	get_tree().call_group(&"voice", &"say", "wave_start", VoiceManager.Priority.HIGH)


func _end_wave() -> void:
	_wave_active = false
	_pause = WAVE_PAUSE
	score += WAVE_BONUS
	player.health.heal(REPAIR_PER_WAVE)
	GameSession.record_wave(wave)
	message.emit(Loc.t("OLEADA %d SUPERADA  +%d  BLINDAJE REPARADO") % [wave, WAVE_BONUS], false)
	get_tree().call_group(&"voice", &"say", "wave_clear", VoiceManager.Priority.HIGH)
	if wave % AIR_EVERY == 0:
		_air_warning = AIR_WARNING
	# Cada 4 oleadas se repone el arsenal especial.
	if wave % 4 == 0:
		missiles = 2
		strikes = 1
		message.emit(Loc.t("ARSENAL REPUESTO: 2 MISILES Y 1 BOMBARDEO"), false)


func _start_air_phase() -> void:
	air_phase = true
	_air_left = AIR_PHASE_TIME
	# Los primeros aviones llegan cuando la vista ya está en la batería.
	_air_spawn_timer = AaBattery.MOVE_IN + 0.6
	_air_spawned = 0
	_air_kills = 0
	_air_total = mini(5 + wave / 3, 9)
	if _battery == null or not is_instance_valid(_battery):
		_battery = _emplace_battery()
	player.aim_lock = null
	player.set_binoculars(false)
	_battery.man(player, player.camera, Vector3.ZERO)
	message.emit(Loc.t("¡ATAQUE AÉREO! A LA BATERÍA: DERRIBA %d AVIONES Y REPÓN EL BOMBARDEO") % AIR_GOAL, true)
	get_tree().call_group(&"voice", &"say", "air_phase", VoiceManager.Priority.CRITICAL)


## Monta la batería antiaérea del bando del jugador en un sitio despejado cerca de su tanque:
## llano, fuera del agua y sin nada encima. Se queda ahí el resto de la partida.
func _emplace_battery() -> AaBattery:
	var battery := AaBattery.make(player.stats.nation)
	battery.name = "AaBattery"
	var here := Vector2(player.global_position.x, player.global_position.z)
	var spot: Vector2 = here + Vector2(0.0, 16.0)
	var found: bool = false
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var probe := CylinderShape3D.new()
	probe.radius = AaBattery.RADIUS + 2.0
	probe.height = 2.4
	for ring: float in [28.0, 38.0, 50.0, 64.0, 80.0, 100.0]:
		for step in 12:
			var angle: float = TAU * step / 12.0 + ring
			var at: Vector2 = here + Vector2(cos(angle), sin(angle)) * ring
			if absf(at.x) > 176.0 or absf(at.y) > 176.0 or not is_free_point.call(at):
				continue
			if Water.deep_at(at.x, at.y, 8.0) or Water.drag_at(at.x, at.y) < 1.0 or Backdrop.in_sea(at.x, at.y):
				continue
			var bumpy: bool = false
			for corner: Vector2 in [Vector2.ZERO, Vector2(5.0, 0.0), Vector2(-5.0, 0.0), Vector2(0.0, 5.0), Vector2(0.0, -5.0)]:
				if absf(Terrain.height(at.x + corner.x, at.y + corner.y)) > 0.25:
					bumpy = true
			if bumpy:
				continue
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = probe
			query.transform = Transform3D(Basis(), Vector3(at.x, 1.9, at.y))
			query.collision_mask = 1 | 2
			if not space.intersect_shape(query, 1).is_empty():
				continue
			spot = at
			found = true
			break
		if found:
			break
	battery.position = Vector3(spot.x, 0.0, spot.y)
	battery.rotation.y = randf() * TAU
	world.add_child(battery)
	return battery


func _update_air_phase(delta: float) -> void:
	_air_left -= delta
	if _air_left <= 0.0:
		_end_air_phase()
		return
	_air_spawn_timer -= delta
	if _air_spawn_timer <= 0.0 and _air_spawned < _air_total:
		_air_spawn_timer = AIR_SPAWN_GAP
		_air_spawned += 1
		var kind: int = AirTarget.Kind.FIGHTER
		if _air_spawned % 3 == 0:
			kind = AirTarget.Kind.ATTACK
		elif _air_spawned == 2:
			kind = AirTarget.Kind.BOMBER
		AirTarget.spawn(world, kind, _battery.global_position, AIR_PACE)
	elif _air_spawned >= _air_total and _air_spawn_timer < -1.5 and get_tree().get_nodes_in_group(&"air_targets").is_empty():
		# Ya han pasado (o caído) todos: no hace falta esperar al reloj.
		_end_air_phase()


## Un avión derribado. En la batería cuenta para el objetivo de la fase; fuera de ella (los
## ataques aéreos sueltos) da el premio de siempre.
func air_reward(where: Vector3) -> void:
	if not air_phase:
		super.air_reward(where)
		return
	score += 200
	_air_kills += 1
	get_tree().call_group(&"voice", &"say", "shot_down", VoiceManager.Priority.HIGH)
	if _air_kills == AIR_GOAL:
		strikes = maxi(strikes, 1)
		message.emit(Loc.t("¡%d AVIONES DERRIBADOS! BOMBARDEO REPUESTO") % _air_kills, true)
	elif _air_kills == _air_total:
		missiles += 1
		message.emit(Loc.t("¡NO HA PASADO NI UNO! +1 MISIL"), true)
	else:
		message.emit(Loc.t("AVIÓN DERRIBADO  %d / %d") % [_air_kills, AIR_GOAL if _air_kills < AIR_GOAL else _air_total], false)


func air_seconds_left() -> float:
	return maxf(_air_left, 0.0)


func _end_air_phase() -> void:
	air_phase = false
	if _battery != null and is_instance_valid(_battery):
		_battery.leave()
	for node in get_tree().get_nodes_in_group(&"air_targets"):
		(node as AirTarget).leave()
	if not is_over:
		if _air_kills >= AIR_GOAL:
			message.emit(Loc.t("CIELO DESPEJADO — VUELVES AL TANQUE CON EL BOMBARDEO REPUESTO"), false)
		else:
			message.emit(Loc.t("CIELO DESPEJADO — VUELVES AL TANQUE"), false)
		get_tree().call_group(&"voice", &"say", "air_clear", VoiceManager.Priority.NORMAL)


func status_text() -> String:
	if air_phase:
		return Loc.t("PUNTOS %d   OLEADA %d   AVIONES %d / %d   %d s") % [score, wave, _air_kills, AIR_GOAL, ceili(air_seconds_left())]
	return _status_normal()


func _spawn(stats: TankStats) -> void:
	# Entran por los límites del mapa, de cara al jugador.
	var origin := Vector2(player.global_position.x, player.global_position.z)
	var point: Vector2 = edge_point()
	spawn_tank(stats, ENEMY_TEAM, point, yaw_towards(point, origin))
	alive += 1


func _on_tank_destroyed(tank: Tank, killer: Node) -> void:
	super._on_tank_destroyed(tank, killer)
	if tank.team == ENEMY_TEAM:
		alive -= 1


func _on_player_destroyed(_tank: Tank, _killer: Node) -> void:
	GameSession.record_wave(wave)
	finish(false, Loc.t("TANQUE DESTRUIDO"), Loc.t("PUNTOS %d   OLEADA %d   (RÉCORD %d)") % [score, wave, GameSession.best_wave()])
