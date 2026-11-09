class_name AIBrain
extends Node
## Cerebro de un enemigo: percepción + máquina de estados + utilidades de conducción.
## Da órdenes al Tank (drive_input, torreta, gatillo) igual que lo haría el jugador.

const WORLD_MASK: int = 1
const ARENA_LIMIT: float = 180.0

var tank: Tank
var target: Tank
var perception: Perception
var machine: StateMachine

var _avoid_sign: float = 1.0
var _avoid_timer: float = 0.0


func setup(tank_ref: Tank, target_ref: Tank) -> void:
	tank = tank_ref
	target = target_ref
	perception = Perception.new(tank, target)
	machine = StateMachine.new()
	machine.name = "StateMachine"
	add_child(machine)
	for state_script: Script in [IdleState, PatrolState, SearchState, ChaseState, AttackState, RetreatState, DestroyedState]:
		var state: State = state_script.new()
		state.name = state_script.get_global_name().trim_suffix("State")
		machine.add_child(state)
	tank.damaged.connect(_on_tank_damaged)
	tank.destroyed.connect(_on_tank_destroyed)
	machine.start(&"Idle")


func _physics_process(delta: float) -> void:
	if tank == null or tank.is_destroyed:
		return
	perception.update(delta)
	_avoid_timer = maxf(_avoid_timer - delta, 0.0)


func state_name() -> StringName:
	return machine.current_name


func armor_fraction() -> float:
	return tank.health.fraction()


func target_point() -> Vector3:
	return target.global_position + Vector3.UP * 1.2


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


func stop() -> void:
	tank.drive_input = Vector2.ZERO


func strafe_point(around: Vector3, radius: float, side: float) -> Vector3:
	var from_target: Vector3 = tank.global_position - around
	from_target.y = 0.0
	var dir: Vector3 = from_target.normalized().rotated(Vector3.UP, side * 0.5)
	return around + dir * radius


func random_waypoint() -> Vector3:
	return Vector3(randf_range(-ARENA_LIMIT, ARENA_LIMIT), 0.0, randf_range(-ARENA_LIMIT, ARENA_LIMIT))


## Aim a un punto con predicción y error según las estadísticas.
func aim_with_error() -> void:
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
	var query := PhysicsRayQueryParameters3D.create(from, from + forward * reach, WORLD_MASK)
	if tank.get_world_3d().direct_space_state.intersect_ray(query).is_empty():
		return 0.0
	if _avoid_timer <= 0.0:
		_avoid_sign = 1.0 if randf() < 0.5 else -1.0
		_avoid_timer = 1.5
	return _avoid_sign


func _on_tank_damaged(_amount: float, _source: Node) -> void:
	perception.reveal()
	var current: StringName = machine.current_name
	if current == &"Idle" or current == &"Patrol":
		machine.change_to(&"Search")


func _on_tank_destroyed(_tank: Tank, _killer: Node) -> void:
	machine.change_to(&"Destroyed")
