class_name PlayerInputSource
extends Node
## Traduce los controles táctiles en órdenes para el tanque.
## Incluye la ayuda de apuntado opcional.

const LOCK_CONE: float = deg_to_rad(4.0)
const LOCK_RANGE: float = 140.0
## Arrastre (px en un frame) a partir del cual el jugador recupera el control de la torreta.
const BREAK_LOCK_PIXELS: float = 5.0
const WORLD_MASK: int = 1

@export var tank: Tank
@export var touch: TouchControls
## Radianes de giro por píxel arrastrado.
@export var look_sensitivity: float = 0.004


func _process(_delta: float) -> void:
	if tank == null or touch == null or tank.is_destroyed:
		return
	tank.drive_input = touch.move_vector
	tank.trigger_held = touch.fire_held

	var look: Vector2 = touch.consume_look_delta()
	if GameSettings.aim_assist:
		_update_lock(look)
	else:
		tank.aim_lock = null
	if tank.aim_lock != null:
		tank.turret_controller.aim_at(_lock_point(tank.aim_lock))
	elif look != Vector2.ZERO:
		tank.turret_controller.add_aim(-look.x * look_sensitivity, -look.y * look_sensitivity)
	else:
		tank.turret_controller.hold_relative()


func _update_lock(look: Vector2) -> void:
	var current: Tank = tank.aim_lock
	if current != null:
		if look.length() > BREAK_LOCK_PIXELS or not _lock_valid(current):
			tank.aim_lock = null
		return
	if look.length() > BREAK_LOCK_PIXELS:
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
