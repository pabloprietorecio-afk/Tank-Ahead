class_name Radar
extends Control
## Radar circular. Arriba = hacia donde mira la torreta (la vista del jugador).
## No conoce ningún tipo de enemigo: dibuja todo nodo Node3D del grupo "enemies".

const RADIUS: float = 90.0
const RANGE: float = 260.0
const SWEEP_PERIOD: float = 2.5

@export var player: Tank

var _time: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2.ONE * RADIUS * 2.0 + Vector2(8.0, 8.0)
	size = custom_minimum_size


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var c := Vector2(RADIUS + 4.0, RADIUS + 4.0)
	var green: Color = VectorMaterials.GREEN
	draw_circle(c, RADIUS, Color(0.0, 0.12, 0.03, 0.55))
	draw_arc(c, RADIUS, 0.0, TAU, 48, Color(green, 0.7), 2.0)
	draw_arc(c, RADIUS * 0.5, 0.0, TAU, 32, Color(green, 0.25), 1.0)
	draw_line(c + Vector2(-RADIUS, 0.0), c + Vector2(RADIUS, 0.0), Color(green, 0.2), 1.0)
	draw_line(c + Vector2(0.0, -RADIUS), c + Vector2(0.0, RADIUS), Color(green, 0.2), 1.0)
	var sweep: float = fmod(_time / SWEEP_PERIOD, 1.0) * TAU
	draw_line(c, c + Vector2(sin(sweep), -cos(sweep)) * RADIUS, Color(green, 0.35), 2.0)
	draw_colored_polygon(PackedVector2Array([c + Vector2(0.0, -9.0), c + Vector2(-6.0, 7.0), c + Vector2(6.0, 7.0)]), green)
	if player == null or player.is_destroyed:
		return
	var yaw: float = player.turret_controller.world_yaw
	var origin: Vector3 = player.global_position
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as Node3D
		if enemy == null:
			continue
		var offset: Vector3 = enemy.global_position - origin
		# Rotamos el desplazamiento para que "arriba" sea el rumbo de la torreta.
		var local := Vector2(offset.x, offset.z).rotated(yaw)
		var distance: float = local.length()
		var out_of_range: bool = distance > RANGE
		var pos: Vector2 = c + local.limit_length(RANGE) / RANGE * (RADIUS - 6.0)
		var color: Color = Color(1.0, 0.5, 0.1, 0.5 if out_of_range else 1.0)
		draw_circle(pos, 4.0 if out_of_range else 6.0, color)
