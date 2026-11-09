class_name PatrolState
extends EnemyState
## Va hacia su orden (objetivo de la misión) o hacia el enemigo lejano si caza; si no, deambula.

var _waypoint: Vector3
var _stuck: float = 0.0


func enter(_previous: StringName) -> void:
	_pick()
	_stuck = 0.0


func _pick() -> void:
	if brain.objective == Vector3.INF and brain.hunt and brain.has_target():
		_waypoint = brain.target.global_position
	else:
		_waypoint = brain.patrol_point()


func update(delta: float) -> void:
	if brain.perception.can_see:
		machine.change_to(&"Chase")
		return
	_stuck += delta
	if fmod(_stuck, 3.0) < delta:
		_pick()
	var arrived: bool = brain.drive_to(_waypoint, 0.7, 6.0)
	brain.tank.turret_controller.aim_yaw(brain.tank.global_rotation.y)
	if arrived or _stuck > 20.0:
		machine.change_to(&"Idle")
