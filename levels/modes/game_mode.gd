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

## Arsenal especial por misión/partida.
var missiles: int = 2
var strikes: int = 1
## Bombardeos enemigos sobre la posición del jugador (0 = desactivados).
var raid_interval: Vector2 = Vector2(55.0, 85.0)
var raid_first: float = 45.0

var _rosters: Dictionary = {}
var _raid_timer: float = 45.0


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


## ¿Monta la arena el decorado del frente (pueblos, colinas, edificios con premio)?
func wants_scenery() -> bool:
	return true


## ¿Reparte la arena premios al azar por el terreno?
func wants_pickups() -> bool:
	return true


## Clima obligado (Weather.Kind) o -1 para sortearlo entre los del frente.
func forced_weather() -> int:
	return -1


## La arena entrega aquí la interfaz ya montada, antes de start().
func bind_ui(_hud: Hud, _touch: TouchControls, _radar: Radar, _input: PlayerInputSource) -> void:
	pass


## Zonas que el escenario debe dejar libres (bases, posiciones a defender).
func reserved_zones() -> Array[Rect2]:
	return []


func start(player_tank: Tank, world_root: Node3D) -> void:
	player = player_tank
	world = world_root
	add_to_group(&"game_mode")
	player.destroyed.connect(_on_player_destroyed)
	_raid_timer = raid_first


func _physics_process(delta: float) -> void:
	if is_over or raid_interval == Vector2.ZERO or not raids_active():
		return
	_raid_timer -= delta
	if _raid_timer <= 0.0:
		_raid_timer = randf_range(raid_interval.x, raid_interval.y)
		enemy_air_raid()


## ¿Hay bombardeos enemigos ahora? (Supervivencia los activa a partir de la oleada 2.)
func raids_active() -> bool:
	return true


## Bombardeo enemigo sobre la posición actual del jugador: hay 4 s para salir de la zona.
func enemy_air_raid() -> void:
	if player == null or player.is_destroyed:
		return
	AirStrike.launch(world, player.global_position, true)
	get_tree().call_group(&"voice", &"say", "raid", VoiceManager.Priority.CRITICAL)
	message.emit("¡BOMBARDEO ENEMIGO! SAL DE LA ZONA ROJA", true)


## Premio por derribar un avión enemigo: blindaje, misil o bombardeo.
func air_reward(_where: Vector3) -> void:
	score += 200
	get_tree().call_group(&"voice", &"say", "shot_down", VoiceManager.Priority.HIGH)
	match randi() % 3:
		0:
			player.health.heal(40.0)
			message.emit("¡DERRIBADO! +40 DE BLINDAJE", false)
		1:
			missiles += 1
			message.emit("¡DERRIBADO! +1 MISIL", false)
		_:
			strikes += 1
			message.emit("¡DERRIBADO! +1 BOMBARDEO", false)


## Misil guiado: va a por el objetivo fijado (si lo hay).
func fire_missile() -> bool:
	if missiles <= 0 or is_over or player.is_destroyed:
		return false
	missiles -= 1
	Missile.fire(player, player.aim_lock)
	get_tree().call_group(&"voice", &"say", "missile", VoiceManager.Priority.NORMAL)
	message.emit("MISIL LANZADO — QUEDAN %d" % missiles, false)
	return true


## Bombardeo aliado sobre el punto al que apunta el cañón (o el objetivo fijado).
func call_air_strike() -> bool:
	if strikes <= 0 or is_over or player.is_destroyed:
		return false
	var point: Vector3
	if is_instance_valid(player.aim_lock):
		point = player.aim_lock.global_position
	else:
		var from: Vector3 = player.muzzle.global_position
		var to: Vector3 = from - player.muzzle.global_transform.basis.z * 300.0
		to.y = minf(to.y, 0.0)
		var query := PhysicsRayQueryParameters3D.create(from, to, 1)
		var hit: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(query)
		point = hit["position"] if not hit.is_empty() else from - player.muzzle.global_transform.basis.z * 150.0
	if Vector2(point.x - player.global_position.x, point.z - player.global_position.z).length() < 30.0:
		message.emit("DEMASIADO CERCA PARA BOMBARDEAR: APUNTA MÁS LEJOS", true)
		get_tree().call_group(&"voice", &"say", "strike_denied", VoiceManager.Priority.HIGH)
		return false
	strikes -= 1
	AirStrike.launch(world, point, false, player)
	get_tree().call_group(&"voice", &"say", "strike", VoiceManager.Priority.HIGH)
	message.emit("BOMBARDEO ALIADO EN CAMINO", false)
	return true


## Llamado por premios y edificios destruidos (vía grupo "game_mode").
func add_score(points: int) -> void:
	if not is_over:
		score += points


func announce(text: String, urgent: bool) -> void:
	message.emit(text, urgent)


## Líneas de objetivos para el HUD (vacío si el modo no tiene objetivos concretos).
func objective_lines() -> Array[String]:
	return []


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
	# Todos los tanques, de los dos bandos, rodean los obstáculos y se desatascan solos.
	brain.smart_nav = true
	# El mapa de rutas empieza a rellenarse ya, antes de que haga falta.
	NavGrid.of(world)
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


## Distancia del centro a la línea por la que entran los refuerzos (el muro está a 200 m).
const EDGE: float = 186.0


## Punto libre en el límite del mapa, a `min_distance` o más del jugador: los enemigos entran
## desde fuera en vez de aparecer de la nada. Con `north_only` solo por el lado norte.
func edge_point(min_distance: float = 110.0, north_only: bool = false) -> Vector2:
	var origin := Vector2.ZERO
	if is_instance_valid(player):
		origin = Vector2(player.global_position.x, player.global_position.z)
	var best := Vector2(0.0, -EDGE)
	var best_distance: float = -1.0
	for attempt in 40:
		var along: float = randf_range(-EDGE, EDGE)
		var point := Vector2(along, -EDGE)
		if not north_only:
			match randi() % 4:
				1:
					point = Vector2(along, EDGE)
				2:
					point = Vector2(-EDGE, along)
				3:
					point = Vector2(EDGE, along)
		if not is_free_point.call(point):
			continue
		var distance: float = point.distance_to(origin)
		if distance >= min_distance:
			return point
		if distance > best_distance:
			best_distance = distance
			best = point
	return best


## Giro con el que un tanque situado en `from` queda mirando hacia `to`.
func yaw_towards(from: Vector2, to: Vector2) -> float:
	var dir: Vector2 = to - from
	return atan2(-dir.x, -dir.y)


func finish(victory: bool, title: String, detail: String) -> void:
	if is_over:
		return
	is_over = true
	get_tree().call_group(&"voice", &"say", "mission_win" if victory else "mission_fail", VoiceManager.Priority.CRITICAL)
	ended.emit(victory, title, detail)


func _on_tank_destroyed(tank: Tank, killer: Node) -> void:
	if tank.team != PLAYER_TEAM and killer is Tank and (killer as Tank).team == PLAYER_TEAM:
		get_tree().call_group(&"voice", &"say", "kill", VoiceManager.Priority.NORMAL)
	if killer == player and tank.team != PLAYER_TEAM:
		score += tank.stats.score_value
		message.emit("%s DESTRUIDO  +%d" % [tank.stats.display_name, tank.stats.score_value], false)


func _on_player_destroyed(_tank: Tank, _killer: Node) -> void:
	finish(false, "TANQUE DESTRUIDO", "PUNTOS %d" % score)
