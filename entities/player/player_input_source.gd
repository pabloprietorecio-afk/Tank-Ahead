class_name PlayerInputSource
extends Node
## Traduce los controles táctiles en órdenes para el tanque.
## Incluye la ayuda de apuntado opcional.

const LOCK_CONE: float = deg_to_rad(7.0)
const LOCK_RANGE: float = 260.0
## Tras liberar un objetivo, segundos sin volver a fijar automáticamente.
const RELOCK_DELAY: float = 2.0
const WORLD_MASK: int = 1

@export var tank: Tank
@export var touch: TouchControls
## Radianes de giro por píxel arrastrado.
@export var look_sensitivity: float = 0.004

## Modo clásico: máximo desvío del cañón respecto al casco y su recentrado.
const FINE_AIM_LIMIT: float = deg_to_rad(45.0)
const FINE_RECENTER_DELAY: float = 2.0
const FINE_RECENTER_SPEED: float = 0.5
## Suavizado del giro del casco (unidades de joystick por segundo).
const TURN_SMOOTHING: float = 5.0

var _fine_yaw: float = 0.0
var _idle_time: float = 0.0
var _turn: float = 0.0
var _relock_cooldown: float = 0.0


func _process(delta: float) -> void:
	if tank == null or touch == null or tank.is_destroyed:
		return
	var stick: Vector2 = touch.move_vector
	if not GameSettings.turret_free:
		_turn = move_toward(_turn, stick.x, TURN_SMOOTHING * delta)
		stick.x = _turn
	tank.drive_input = stick
	tank.trigger_held = touch.fire_held

	var look: Vector2 = touch.consume_look_delta()
	_relock_cooldown = maxf(_relock_cooldown - delta, 0.0)
	if GameSettings.aim_assist:
		_update_lock()
	elif tank.aim_lock != null:
		release_lock()
	if tank.aim_lock != null:
		tank.turret_controller.aim_at(_lock_point(tank.aim_lock))
	elif not GameSettings.turret_free:
		_classic_aim(look, delta)
	elif look != Vector2.ZERO:
		tank.turret_controller.add_aim(-look.x * look_sensitivity, -look.y * look_sensitivity)
	else:
		tank.turret_controller.hold_relative()


## Libera el objetivo fijado (botón LIBERAR del HUD).
func release_lock() -> void:
	if tank.aim_lock == null:
		return
	tank.aim_lock = null
	_relock_cooldown = RELOCK_DELAY
	_fine_yaw = clampf(tank.turret_controller.local_yaw, -FINE_AIM_LIMIT, FINE_AIM_LIMIT)
	_idle_time = 0.0


## Una vez fijado, el objetivo no se pierde hasta que muere o el jugador lo libera.
func _update_lock() -> void:
	var current: Tank = tank.aim_lock
	if current != null:
		if not is_instance_valid(current) or current.is_destroyed:
			tank.aim_lock = null
			_fine_yaw = clampf(tank.turret_controller.local_yaw, -FINE_AIM_LIMIT, FINE_AIM_LIMIT)
			_idle_time = 0.0
		return
	if _relock_cooldown > 0.0:
		return
	var origin: Vector3 = tank.muzzle.global_position
	var aim_dir: Vector3 = -tank.muzzle.global_transform.basis.z
	var best: Tank = null
	var best_angle: float = LOCK_CONE
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy: Tank = node as Tank
		if enemy == null or not _lock_valid(enemy):
			continue
		var angle: float = aim_dir.angle_to(_lock_point(enemy) - origin)
		if angle < best_angle:
			best_angle = angle
			best = enemy
	tank.aim_lock = best


func _lock_valid(enemy: Tank) -> bool:
	if not is_instance_valid(enemy) or enemy.is_destroyed:
		return false
	var origin: Vector3 = tank.muzzle.global_position
	var point: Vector3 = _lock_point(enemy)
	if origin.distance_to(point) > LOCK_RANGE:
		return false
	var query := PhysicsRayQueryParameters3D.create(origin, point, WORLD_MASK)
	return tank.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _lock_point(enemy: Tank) -> Vector3:
	var point: Vector3 = enemy.global_position + Vector3.UP * 1.2 * enemy.stats.body_scale
	var travel: float = tank.global_position.distance_to(point) / maxf(tank.weapon.projectile_speed, 1.0)
	return point + enemy.velocity * travel


## Cañón fijo al casco; el arrastre solo permite un ajuste fino y se recentra al soltar.
func _classic_aim(look: Vector2, delta: float) -> void:
	if look != Vector2.ZERO:
		_idle_time = 0.0
		_fine_yaw = clampf(_fine_yaw - look.x * look_sensitivity, -FINE_AIM_LIMIT, FINE_AIM_LIMIT)
		tank.turret_controller.aim_local(_fine_yaw, -look.y * look_sensitivity)
		return
	_idle_time += delta
	if _idle_time > FINE_RECENTER_DELAY:
		_fine_yaw = move_toward(_fine_yaw, 0.0, FINE_RECENTER_SPEED * delta)
	tank.turret_controller.aim_local(_fine_yaw)
