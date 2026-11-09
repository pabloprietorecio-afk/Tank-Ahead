class_name SearchState
extends EnemyState
## Va a la última posición conocida del enemigo y mira alrededor.

var _time: float = 0.0


func enter(_previous: StringName) -> void:
	_time = 0.0


func update(delta: float) -> void:
	_time += delta
	if brain.perception.can_see:
		machine.change_to(&"Chase")
		return
	if not brain.perception.has_last_known:
		machine.change_to(&"Patrol")
		return
	var arrived: bool = brain.drive_to(brain.perception.last_known, 0.8, 8.0)
	brain.tank.turret_controller.aim_yaw(brain.tank.global_rotation.y + sin(_time * 1.5) * 1.2)
	if (arrived and _time > 3.0) or _time > 15.0:
		brain.perception.forget()
		machine.change_to(&"Patrol")
