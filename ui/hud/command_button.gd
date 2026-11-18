class_name CommandButton
extends Button
## Icono redondo para dar una orden a los aliados, dibujado por código (sin texto):
## FOLLOW = «todos conmigo» (el líder y dos tanques en formación detrás);
## FOCUS = «todos al mismo objetivo» (una mira con dos tanques apuntando al centro);
## MIC = órdenes por voz (un micrófono; rojo y latiendo mientras escucha una orden y, con
## `standby`, en verde: micrófono siempre abierto).
## `active` lo ilumina: la orden está en vigor.

enum Kind { FOLLOW, FOCUS, MIC }

const IDLE := Color(0.78, 0.85, 0.78)
const ON := Color(0.45, 1.0, 0.5)
const FOCUS_ON := Color(1.0, 0.62, 0.2)
const MIC_ON := Color(1.0, 0.25, 0.2)

var kind: int = Kind.FOLLOW
var active: bool = false:
	set(value):
		if value != active:
			active = value
			queue_redraw()
			set_process(kind == Kind.MIC and active)

## Solo MIC: el micrófono está siempre abierto (escucha sin pulsarlo).
var standby: bool = false:
	set(value):
		if value != standby:
			standby = value
			queue_redraw()

var _pulse: float = 0.0


static func create(icon_kind: int) -> CommandButton:
	var button := CommandButton.new()
	button.kind = icon_kind
	return button


func _init() -> void:
	custom_minimum_size = Vector2(88.0, 88.0)
	focus_mode = Control.FOCUS_NONE
	text = ""
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	set_process(false)


func _process(delta: float) -> void:
	_pulse = fmod(_pulse + delta * 2.5, TAU)
	queue_redraw()


func _draw() -> void:
	var center: Vector2 = size * 0.5
	var radius: float = minf(size.x, size.y) * 0.5 - 3.0
	var on_color: Color = FOCUS_ON if kind == Kind.FOCUS else (MIC_ON if kind == Kind.MIC else ON)
	var color: Color = on_color if active else (ON if standby else IDLE)
	var held: bool = get_draw_mode() == DRAW_PRESSED
	draw_circle(center, radius, Color(0.05, 0.07, 0.05, 0.8 if held else 0.55))
	draw_arc(center, radius, 0.0, TAU, 48, color, 4.0 if active or standby else 2.5, true)
	if kind == Kind.MIC:
		if active:
			# Escuchando: un anillo que late alrededor.
			var beat: float = 0.5 + 0.5 * sin(_pulse)
			draw_arc(center, radius - 5.0 - beat * 4.0, 0.0, TAU, 48, Color(color, 0.35 + 0.4 * beat), 2.0, true)
		# Cápsula del micrófono, horquilla y pie.
		var w: float = radius * 0.2
		var top: float = center.y - radius * 0.5
		var bottom: float = center.y + radius * 0.02
		draw_circle(Vector2(center.x, top + w), w, color)
		draw_circle(Vector2(center.x, bottom - w), w, color)
		draw_rect(Rect2(center.x - w, top + w, w * 2.0, bottom - top - w * 2.0), color)
		draw_arc(Vector2(center.x, bottom - w * 1.2), w * 1.75, 0.15, PI - 0.15, 16, color, 2.5, true)
		draw_line(Vector2(center.x, bottom - w * 1.2 + w * 1.75), Vector2(center.x, center.y + radius * 0.48), color, 2.5)
		draw_line(Vector2(center.x - w * 1.3, center.y + radius * 0.48), Vector2(center.x + w * 1.3, center.y + radius * 0.48), color, 2.5)
	elif kind == Kind.FOLLOW:
		# Formación en V: el líder delante, grande; dos tanques detrás, más pequeños.
		_arrow(center + Vector2(0.0, -radius * 0.2), 0.0, radius * 0.3, color)
		_arrow(center + Vector2(-radius * 0.45, radius * 0.38), 0.0, radius * 0.2, color.darkened(0.15))
		_arrow(center + Vector2(radius * 0.45, radius * 0.38), 0.0, radius * 0.2, color.darkened(0.15))
	else:
		# Mira con dos tanques que apuntan al centro.
		draw_arc(center, radius * 0.38, 0.0, TAU, 32, color, 2.5, true)
		for tick in 4:
			var dir := Vector2.from_angle(tick * PI * 0.5)
			draw_line(center + dir * radius * 0.26, center + dir * radius * 0.56, color, 2.5)
		draw_circle(center, radius * 0.07, color)
		_arrow(center + Vector2(-radius * 0.56, radius * 0.5), PI * 0.25, radius * 0.17, color.darkened(0.15))
		_arrow(center + Vector2(radius * 0.56, radius * 0.5), -PI * 0.25, radius * 0.17, color.darkened(0.15))


## Flecha (triángulo) en `at`, apuntando hacia arriba girada `angle` radianes.
func _arrow(at: Vector2, angle: float, length: float, color: Color) -> void:
	var points := PackedVector2Array([Vector2(0.0, -length), Vector2(length * 0.8, length * 0.8), Vector2(0.0, length * 0.35), Vector2(-length * 0.8, length * 0.8)])
	for i in points.size():
		points[i] = at + points[i].rotated(angle)
	draw_colored_polygon(points, color)
