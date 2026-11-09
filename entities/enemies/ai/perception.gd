class_name Perception
extends RefCounted
## Percepción del enemigo: distancia, línea de visión y última posición conocida del objetivo.
## No depende de ningún tipo de enemigo concreto.

const WORLD_MASK: int = 1
const INTERVAL: float = 0.2

var distance: float = INF
var can_see: bool = false
var last_known: Vector3 = Vector3.ZERO
var has_last_known: bool = false
var time_since_seen: float = INF

var _owner: Tank
var _target: Tank
var _timer: float = randf() * INTERVAL


func _init(owner_tank: Tank, target_tank: Tank) -> void:
	_owner = owner_tank
	_target = target_tank


func update(delta: float) -> void:
	time_since_seen += delta
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = INTERVAL
	if not is_instance_valid(_target) or _target.is_destroyed:
		can_see = false
		distance = INF
		return
	distance = _owner.global_position.distance_to(_target.global_position)
	can_see = distance <= _owner.stats.detect_range and _line_of_sight()
	if can_see:
		time_since_seen = 0.0
		last_known = _target.global_position
		has_last_known = true


## Un golpe recibido revela la posición del atacante aunque no lo viéramos.
func reveal() -> void:
	if is_instance_valid(_target):
		last_known = _target.global_position
		has_last_known = true
		time_since_seen = minf(time_since_seen, 1.0)


func _line_of_sight() -> bool:
	var from: Vector3 = _owner.global_position + Vector3.UP * 1.6
	var to: Vector3 = _target.global_position + Vector3.UP * 1.2
	var query := PhysicsRayQueryParameters3D.create(from, to, WORLD_MASK)
	return _owner.get_world_3d().direct_space_state.intersect_ray(query).is_empty()
