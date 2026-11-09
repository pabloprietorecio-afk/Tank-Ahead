class_name PatrolState
extends EnemyState
## Recorre puntos aleatorios de la arena.

var _waypoint: Vector3
var _stuck: float = 0.0


func enter(_previous: StringName) -> void:
	_waypoint = brain.random_waypoint()
	_stuck = 0.0


func update(delta: float) -> void:
	if brain.perception.can_see:
		machine.change_to(&"Chase")
		return
	_stuck += delta
	var arrived: bool = brain.drive_to(_waypoint, 0.6, 6.0)
	brain.tank.turret_controller.aim_yaw(brain.tank.global_rotation.y)
	if arrived or _stuck > 20.0:
		machine.change_to(&"Idle")
