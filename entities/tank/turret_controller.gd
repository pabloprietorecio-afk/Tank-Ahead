class_name TurretController
extends Node
## Torreta independiente del casco: mantiene su rumbo en el mundo aunque el casco gire.

const MAX_LEAD: float = 1.0
const MIN_PITCH: float = deg_to_rad(-6.0)
const MAX_PITCH: float = deg_to_rad(18.0)

var world_yaw: float = 0.0
var pitch: float = 0.0

var _tank: Tank
var _target_yaw: float = 0.0
var _target_pitch: float = 0.0


func setup(tank: Tank) -> void:
	_tank = tank
	world_yaw = tank.global_rotation.y
	_target_yaw = world_yaw


## Desplazamiento deseado en radianes. Se aplica con velocidad limitada.
func add_aim(delta_yaw: float, delta_pitch: float) -> void:
	_target_yaw = clampf(_target_yaw + delta_yaw, world_yaw - MAX_LEAD, world_yaw + MAX_LEAD)
	_target_pitch = clampf(_target_pitch + delta_pitch, MIN_PITCH, MAX_PITCH)


## Ángulo del casco respecto a hacia donde mira la torreta (positivo = casco girado a la izquierda).
func hull_relative_angle() -> float:
	return wrapf(_tank.global_rotation.y - world_yaw, -PI, PI)


func _process(delta: float) -> void:
	if _tank == null:
		return
	var max_step: float = _tank.stats.turret_turn_speed * delta
	world_yaw += clampf(_target_yaw - world_yaw, -max_step, max_step)
	pitch += clampf(_target_pitch - pitch, -max_step, max_step)
	_tank.turret.rotation.y = world_yaw - _tank.global_rotation.y
	_tank.gun_pivot.rotation.x = pitch
