class_name IntroFlight
extends Node
## Entrada de una misión: la cámara sobrevuela el campo en un barrido amplio, baja en picado y
## acaba justo en la cámara del tanque del jugador. Mientras dura, la partida está en pausa (no
## pasa nada que el jugador no vea) y la interfaz, escondida; se salta tocando la pantalla.
## El barrido se ve como una película de guerra antigua (shaders/film_view.gdshader), igual que
## el vídeo de introducción; ese aire se va poco a poco durante el picado y al llegar al tanque
## la imagen es ya la del juego.

## Duración del vuelo (s) y parte de ella en la que todavía no se puede saltar (para que el
## toque con el que se entra a la misión no lo corte nada más empezar).
const DURATION: float = 7.5
const SKIP_AFTER: float = 0.5
## Altura y distancia al centro del campo al empezar el barrido (m), y lo que gira (radianes).
const START_HEIGHT: float = 210.0
const START_RADIUS: float = 330.0
const SWEEP: float = 2.2
## Tramo del vuelo (0..1) en el que se va el aire de película antigua: el picado hacia el tanque.
const FILM_FADE := Vector2(0.5, 0.93)

var player: Tank
var ui_layer: CanvasLayer
var title: String = ""
var subtitle: String = ""

var _camera: Camera3D
var _goal: Camera3D
var _clock: float = 0.0
var _end_angle: float = 0.0
var _end_radius: float = 0.0
var _turn: float = 1.0
var _overlay: CanvasLayer
var _texts: Control
var _film: ShaderMaterial
var _done: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_goal = player.camera
	if _goal == null:
		queue_free()
		return
	_camera = Camera3D.new()
	_camera.near = 0.5
	_camera.far = 2800.0
	# El jugador ve su propio tanque desde fuera.
	_camera.cull_mask = 1 | Tank.VISUAL_LAYER_OWN
	add_child(_camera)
	_camera.current = true
	# El barrido acaba detrás del tanque, del lado de fuera: el picado llega por su espalda.
	var behind: Vector3 = _goal.global_basis.z
	var flat := Vector2(behind.x, behind.z)
	if flat.length() < 0.1:
		flat = Vector2(0.0, 1.0)
	var out: Vector2 = Vector2(player.global_position.x, player.global_position.z) + flat.normalized() * 70.0
	_end_angle = atan2(out.y, out.x)
	_end_radius = maxf(out.length(), 80.0)
	_turn = 1.0 if randf() < 0.5 else -1.0
	if ui_layer != null:
		ui_layer.visible = false
	_build_overlay()
	get_tree().paused = true
	_place(0.0)


func _build_overlay() -> void:
	_overlay = CanvasLayer.new()
	_overlay.layer = 20
	add_child(_overlay)
	_texts = VBoxContainer.new()
	_texts.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_texts.offset_top = -190.0
	_texts.offset_bottom = -40.0
	_texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(_texts)
	for line: Array in [[title, 54, UiKit.FEATURED], [subtitle, 26, Color(0.92, 0.92, 0.88)]]:
		var label := Label.new()
		label.text = line[0]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", line[1])
		label.add_theme_color_override("font_color", line[2])
		label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
		label.add_theme_constant_override("outline_size", 8)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_texts.add_child(label)
	var hint := Label.new()
	hint.text = Loc.t("TOCA PARA SALTAR")
	hint.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	hint.offset_left = -420.0
	hint.offset_right = -28.0
	hint.offset_top = 22.0
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.add_theme_font_size_override("font_size", 20)
	hint.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.7))
	hint.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.7))
	hint.add_theme_constant_override("outline_size", 5)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(hint)
	# Por encima de todo, títulos incluidos, la película antigua.
	var reel := CanvasLayer.new()
	reel.layer = 21
	add_child(reel)
	var view := ColorRect.new()
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_film = ShaderMaterial.new()
	_film.shader = load("res://shaders/film_view.gdshader")
	view.material = _film
	reel.add_child(view)


func _process(delta: float) -> void:
	if _done:
		return
	_clock += delta
	if _clock >= DURATION or not is_instance_valid(_goal):
		finish()
		return
	_place(_clock / DURATION)


## Coloca la cámara en el punto `t` (0..1) del vuelo.
func _place(t: float) -> void:
	var goal: Transform3D = _goal.global_transform
	var tank: Vector3 = player.global_position
	# Barrido: una espiral que se cierra y baja alrededor del campo.
	var ease_all: float = t * t * (3.0 - 2.0 * t)
	var angle: float = _end_angle + _turn * SWEEP * (1.0 - ease_all)
	var radius: float = lerpf(START_RADIUS, _end_radius, ease_all)
	var height: float = lerpf(START_HEIGHT, 95.0, smoothstep(0.0, 0.7, t))
	var orbit := Vector3(cos(angle) * radius, height, sin(angle) * radius)
	# Picado: en el último tramo la espiral se funde con la cámara del tanque.
	var dive: float = smoothstep(0.52, 1.0, t)
	dive = dive * dive * (3.0 - 2.0 * dive)
	var eye: Vector3 = orbit.lerp(goal.origin, dive)
	# Mira primero al campo entero y luego al tanque; al final, a donde mira el tanque.
	var target: Vector3 = Vector3(0.0, 0.0, 0.0).lerp(tank + Vector3.UP * 1.5, smoothstep(0.15, 0.7, t))
	target = target.lerp(goal.origin - goal.basis.z * 60.0, smoothstep(0.72, 1.0, t))
	var aim := Transform3D(Basis(), eye).looking_at(target if eye.distance_to(target) > 0.5 else eye - goal.basis.z, Vector3.UP)
	var settle: float = smoothstep(0.86, 1.0, t)
	_camera.global_transform = Transform3D(aim.basis.slerp(goal.basis.orthonormalized(), settle).orthonormalized(), eye)
	_camera.fov = lerpf(58.0, _goal.fov, smoothstep(0.6, 1.0, t))
	# Las nubes siguen a la cámara que mira (su nodo está en pausa, como todo lo demás).
	var clouds := get_tree().current_scene.get_node_or_null("Weather/CloudDome") as Node3D
	if clouds != null:
		clouds.global_position = Vector3(eye.x, 0.0, eye.z)
	_film.set_shader_parameter("strength", film_strength(t))
	# El título entra al principio y se va antes del picado.
	_texts.modulate.a = smoothstep(0.03, 0.14, t) * (1.0 - smoothstep(0.6, 0.74, t))


## Cuánto aire de película antigua lleva la imagen en el punto `t` del vuelo (1 entero, 0 nada).
static func film_strength(t: float) -> float:
	return 1.0 - smoothstep(FILM_FADE.x, FILM_FADE.y, t)


func _input(event: InputEvent) -> void:
	if _done or _clock < SKIP_AFTER:
		return
	var pressed: bool = (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed) or (event is InputEventKey and event.pressed)
	if pressed:
		get_viewport().set_input_as_handled()
		finish()


## Acaba el vuelo (o lo corta): devuelve la vista al tanque, enseña la interfaz y sigue la partida.
func finish() -> void:
	if _done:
		return
	_done = true
	if is_instance_valid(_goal):
		_goal.current = true
	if ui_layer != null and is_instance_valid(ui_layer):
		ui_layer.visible = true
	get_tree().paused = false
	queue_free()
