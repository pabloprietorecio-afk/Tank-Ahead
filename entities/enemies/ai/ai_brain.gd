class_name AIBrain
extends Node
## Cerebro de un tanque controlado por la máquina (enemigo o aliado).
## Elige como objetivo al tanque hostil más cercano que pueda ver; si no hay ninguno,
## sigue su orden (`objective`) o, si `hunt` está activo, va a por el hostil más cercano.
## Da órdenes al Tank (drive_input, torreta, gatillo) igual que lo haría el jugador.

const WORLD_MASK: int = 1
const ARENA_LIMIT: float = 180.0
const RETARGET_INTERVAL: float = 0.6

var tank: Tank
var target: Tank
var perception: Perception
var machine: StateMachine
## Punto al que dirigirse cuando no hay combate (bandera, zona a defender...). Vector3.INF = ninguno.
var objective: Vector3 = Vector3.INF
## Si no ve a nadie, persigue al hostil más cercano aunque esté lejos (supervivencia).
var hunt: bool = true
## Distancia a la que se queda del objetivo al llegar (defensores: patrullan alrededor).
var objective_radius: float = 6.0

var _avoid_sign: float = 1.0
var _avoid_timer: float = 0.0
var _retarget_timer: float = 0.0


func setup(tank_ref: Tank, initial_target: Tank = null) -> void:
	tank = tank_ref
	perception = Perception.new(tank)
	machine = StateMachine.new()
	machine.name = "StateMachine"
	add_child(machine)
	for state_script: Script in [IdleState, PatrolState, SearchState, ChaseState, AttackState, RetreatState, DestroyedState]:
		var state: State = state_script.new()
		state.name = state_script.get_global_name().trim_suffix("State")
		machine.add_child(state)
	tank.damaged.connect(_on_tank_damaged)
	tank.destroyed.connect(_on_tank_destroyed)
	_set_target(initial_target)
	machine.start(&"Idle")


func _physics_process(delta: float) -> void:
	if tank == null or tank.is_destroyed:
		return
	_retarget_timer -= delta
	if _retarget_timer <= 0.0:
		_retarget_timer = RETARGET_INTERVAL
		_choose_target()
	perception.update(delta)
	_avoid_timer = maxf(_avoid_timer - delta, 0.0)


func has_target() -> bool:
	return is_instance_valid(target) and not target.is_destroyed


func _choose_target() -> void:
	var best: Tank = null
	var best_dist: float = INF
	var nearest_any: Tank = null
	var nearest_any_dist: float = INF
	for node in get_tree().get_nodes_in_group(&"tanks"):
		var other: Tank = node as Tank
		if other == null or other.is_destroyed or not tank.is_hostile_to(other):
			continue
		var dist: float = tank.global_position.distance_to(other.global_position)
		if dist < nearest_any_dist:
			nearest_any_dist = dist
			nearest_any = other
		# El objetivo actual tiene ventaja para no cambiar a cada momento.
		var score: float = dist * (0.7 if other == target else 1.0)
		if dist <= tank.stats.detect_range and score < best_dist and perception.line_of_sight(other):
			best_dist = score
			best = other
	if best == null and has_target() and perception.time_since_seen < 6.0:
		return
	if best == null and hunt:
		best = nearest_any
	_set_target(best)


func _set_target(new_target: Tank) -> void:
	target = new_target
	perception.set_target(new_target)


func state_name() -> StringName:
	return machine.current_name


func armor_fraction() -> float:
	return tank.health.fraction()


func target_point() -> Vector3:
	return target.global_position + Vector3.UP * 1.2 * target.stats.body_scale


## Punto de patrulla: la orden actual o un punto al azar.
func patrol_point() -> Vector3:
	if objective != Vector3.INF:
		var offset := Vector2.from_angle(randf() * TAU) * randf_range(0.0, objective_radius)
		return objective + Vector3(offset.x, 0.0, offset.y)
	return random_waypoint()


## Conduce hacia un punto. `speed` en 0..1. Devuelve true al llegar (radio `arrive`).
func drive_to(point: Vector3, speed: float = 1.0, arrive: float = 4.0) -> bool:
	var to: Vector3 = point - tank.global_position
	to.y = 0.0
	var dist: float = to.length()
	if dist <= arrive:
		tank.drive_input = Vector2.ZERO
		return true
	var forward: Vector3 = -tank.global_transform.basis.z
	var angle: float = forward.signed_angle_to(to, Vector3.UP)
	var turn: float = clampf(-angle * 2.0, -1.0, 1.0)
	var advance: float = speed * clampf(1.0 - absf(angle) / 1.2, 0.0, 1.0)
	var avoid: float = _avoidance()
	if avoid != 0.0:
		turn = clampf(turn + avoid, -1.0, 1.0)
		advance *= 0.5
	tank.drive_input = Vector2(turn, advance)
	return false


## Gira el casco en el sitio hacia un punto (cazacarros de casamata). True si ya está encarado.
func face(point: Vector3, tolerance: float = 0.08) -> bool:
	var to: Vector3 = point - tank.global_position
	to.y = 0.0
	var forward: Vector3 = -tank.global_transform.basis.z
	var angle: float = forward.signed_angle_to(to, Vector3.UP)
	if absf(angle) <= tolerance:
		tank.drive_input = Vector2.ZERO
		return true
	tank.drive_input = Vector2(clampf(-angle * 2.5, -1.0, 1.0), 0.0)
	return false


func stop() -> void:
	tank.drive_input = Vector2.ZERO


func strafe_point(around: Vector3, radius: float, side: float) -> Vector3:
	var from_target: Vector3 = tank.global_position - around
	from_target.y = 0.0
	var dir: Vector3 = from_target.normalized().rotated(Vector3.UP, side * 0.5)
	return around + dir * radius


func random_waypoint() -> Vector3:
	return Vector3(randf_range(-ARENA_LIMIT, ARENA_LIMIT), 0.0, randf_range(-ARENA_LIMIT, ARENA_LIMIT))


## Apunta con predicción y error según las estadísticas.
func aim_with_error() -> void:
	if not has_target():
		return
	var stats: TankStats = tank.stats
	var point: Vector3 = target_point()
	var dist: float = tank.global_position.distance_to(point)
	point += target.velocity * (dist / stats.projectile_speed) * stats.lead_factor
	var error: float = dist * tan(deg_to_rad(stats.aim_error_deg))
	point += Vector3(randf_range(-error, error), randf_range(-error, error) * 0.3, randf_range(-error, error))
	tank.turret_controller.aim_at(point)


func _avoidance() -> float:
	var forward: Vector3 = -tank.global_transform.basis.z
	var from: Vector3 = tank.global_position + Vector3.UP * 1.0
	var reach: float = 9.0 * tank.stats.body_scale
	var query := PhysicsRayQueryParameters3D.create(from, from + forward * reach, WORLD_MASK | Tank.LAYER_TANK)
	query.exclude = [tank.get_rid()]
	if tank.get_world_3d().direct_space_state.intersect_ray(query).is_empty():
		return 0.0
	if _avoid_timer <= 0.0:
		_avoid_sign = 1.0 if randf() < 0.5 else -1.0
		_avoid_timer = 1.5
	return _avoid_sign


func _on_tank_damaged(_amount: float, source: Node) -> void:
	var attacker: Tank = source as Tank
	if attacker != null and tank.is_hostile_to(attacker) and not attacker.is_destroyed:
		_set_target(attacker)
		perception.reveal(attacker.global_position)
	var current: StringName = machine.current_name
	if current == &"Idle" or current == &"Patrol":
		machine.change_to(&"Search")


func _on_tank_destroyed(_tank: Tank, _killer: Node) -> void:
	machine.change_to(&"Destroyed")
