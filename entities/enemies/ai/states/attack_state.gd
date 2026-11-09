class_name AttackState
extends EnemyState
## Dispara al jugador mientras se mueve en círculo para no ser un blanco fácil.

var _aim_timer: float = 0.0
var _side: float = 1.0
var _blind: float = 0.0


func enter(_previous: StringName) -> void:
	_side = 1.0 if randf() < 0.5 else -1.0
	_aim_timer = 0.0
	_blind = 0.0


func exit() -> void:
	brain.tank.trigger_held = false


func update(delta: float) -> void:
	var perception: Perception = brain.perception
	var stats: TankStats = brain.tank.stats
	if stats.retreat_fraction > 0.0 and brain.armor_fraction() <= stats.retreat_fraction:
		machine.change_to(&"Retreat")
		return
	_blind = 0.0 if perception.can_see else _blind + delta
	if _blind > 1.5 or perception.distance > stats.attack_range * 1.25:
		machine.change_to(&"Chase")
		return
	_aim_timer -= delta
	if _aim_timer <= 0.0:
		_aim_timer = 0.6
		brain.aim_with_error()
		if randf() < 0.3:
			_side = -_side
	var spot: Vector3 = brain.strafe_point(brain.target.global_position, perception.distance, _side)
	brain.drive_to(spot, 0.5, 2.0)
	var cone: float = deg_to_rad(stats.fire_cone_deg)
	brain.tank.trigger_held = perception.can_see and brain.tank.turret_controller.is_aligned(cone)
