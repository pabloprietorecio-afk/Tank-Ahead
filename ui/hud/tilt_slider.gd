class_name TiltSlider
extends Control
## Flecha vertical de doble sentido, encima del botón FIRE y pegada al borde derecho, con un
## marcador que indica el picado de la cámara exterior: arriba, la cámara sube y mira más desde lo
## alto; abajo, baja y mira más rasante. Se desliza con el dedo.
##
## Sigue los dedos por su índice (como `TouchControls`), así que funciona mientras otro dedo lleva
## el joystick o dispara. Solo responde a un toque que empiece sobre ella; `TouchControls` la tiene
## entre sus exclusiones para que ese toque no mueva además la torreta.

signal changed(value: float)
## El dedo se ha levantado (momento de guardar el ajuste).
signal released

const WIDTH: float = 64.0
## Lo que cabe entre el radar (arriba) y el botón FIRE (abajo) en una pantalla de 720 de alto.
const HEIGHT: float = 150.0
## Margen arriba y abajo hasta las puntas de la flecha.
const PAD: float = 16.0
const COLOR := Color(0.92, 0.9, 0.8)

## 0 = rasante (abajo), 1 = lo más picado (arriba).
var value: float = 0.0:
	set(v):
		value = clampf(v, 0.0, 1.0)
		queue_redraw()
## El tutorial la atenúa y bloquea hasta que toca enseñarla.
var locked: bool = false:
	set(v):
		locked = v
		if v:
			_finger = -1
		queue_redraw()

var _finger: int = -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(WIDTH, HEIGHT)
	visibility_changed.connect(func() -> void: _finger = -1)


func _input(event: InputEvent) -> void:
	if locked or not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		if touch.pressed and _finger == -1 and get_global_rect().has_point(touch.position):
			_finger = touch.index
			_follow(touch.position)
		elif not touch.pressed and touch.index == _finger:
			_finger = -1
			queue_redraw()
			released.emit()
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event
		if drag.index == _finger:
			_follow(drag.position)


## El marcador va a la altura del dedo.
func _follow(at: Vector2) -> void:
	var top: float = global_position.y + PAD
	var span: float = size.y - PAD * 2.0
	var next: float = clampf(1.0 - (at.y - top) / maxf(span, 1.0), 0.0, 1.0)
	if not is_equal_approx(next, value):
		value = next
		changed.emit(value)
	queue_redraw()


func _draw() -> void:
	var held: bool = _finger != -1
	var color := Color(COLOR, 0.15 if locked else (0.95 if held else 0.7))
	var x: float = size.x * 0.5
	var top: float = PAD
	var bottom: float = size.y - PAD
	# El astil y las dos puntas.
	draw_line(Vector2(x, top + 10.0), Vector2(x, bottom - 10.0), color, 4.0, true)
	draw_colored_polygon(PackedVector2Array([Vector2(x, top - 8.0), Vector2(x - 13.0, top + 12.0), Vector2(x + 13.0, top + 12.0)]), color)
	draw_colored_polygon(PackedVector2Array([Vector2(x, bottom + 8.0), Vector2(x - 13.0, bottom - 12.0), Vector2(x + 13.0, bottom - 12.0)]), color)
	# El marcador: un disco con borde, a la altura del picado actual.
	var at := Vector2(x, lerpf(bottom, top, value))
	draw_circle(at, 15.0 if held else 13.0, Color(0.05, 0.05, 0.04, color.a * 0.75))
	draw_arc(at, 15.0 if held else 13.0, 0.0, TAU, 32, color, 3.5, true)
	draw_line(at + Vector2(-22.0, 0.0), at + Vector2(-15.0, 0.0), color, 3.0)
	draw_line(at + Vector2(15.0, 0.0), at + Vector2(22.0, 0.0), color, 3.0)
