class_name SearchState
extends EnemyState
## Va a la última posición conocida del jugador y mira alrededor.

var _time: float = 0.0


func enter(_previous: StringName) -> void:
	_time = 0.0


func update(delta: float) -> void:
	_time += delta
	if brain.perception.can_see:
		machine.change_to(&"Chase")
		return
	var point: Vector3 = brain.perception.last_known if brain.perception.has_last_known else brain.random_waypoint()
	var arrived: bool = brain.drive_to(point, 0.8, 8.0)
	brain.tank.turret_controller.aim_yaw(brain.tank.global_rotation.y + sin(_time * 1.5) * 1.2)
	if (arrived and _time > 3.0) or _time > 15.0:
		machine.change_to(&"Patrol")
