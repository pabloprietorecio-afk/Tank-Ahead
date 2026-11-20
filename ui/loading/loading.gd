class_name Loading
extends CanvasLayer
## Pantalla de carga: tapa el cambio de escena mientras se monta el campo de batalla. Un tanque
## avanza por un terreno ondulado y una barra fina dice cuánto falta.
##
## Montar el campo ocupa al juego entero, así que la arena lo hace por pasos y cede un cuadro
## entre uno y otro (`await Loading.step(...)`): en cada cuadro la pantalla se repinta con el
## reloj de verdad, de modo que el tanque avanza aunque los cuadros lleguen a saltos. Mientras
## dura, el árbol está en pausa: nada de la partida echa a andar a medio montar. Sin pantalla de
## carga abierta (las pruebas) `step` no cede y la arena se monta de una vez, como siempre.

const FADE: float = 0.4

static var current: Loading

var title: String = ""
var _art: LoadingArt
var _fading: float = -1.0
## Con LOAD_TIMES en el entorno imprime lo que tarda cada paso.
var _mark: int = 0
var _trace: bool = false


## Abre la pantalla de carga y, cuando ya se ve, cambia a la escena `path`.
static func open(tree: SceneTree, path: String, heading: String = "") -> void:
	if current != null:
		return
	var screen := Loading.new()
	screen.title = heading
	tree.root.add_child(screen)
	tree.paused = true
	# Dos cuadros para que la pantalla esté pintada antes de que el juego se quede montando.
	await tree.process_frame
	await tree.process_frame
	tree.change_scene_to_file(path)


## Avisa de cuánto va montado (0..1) y cede un cuadro para que la pantalla se repinte.
static func step(progress: float, what: String = "") -> void:
	if current == null:
		return
	current._note(progress, what)
	await current.get_tree().process_frame


## Fin de la carga: deja pintar un par de cuadros del campo ya montado (ahí se preparan los
## materiales, y el tirón queda tapado) y se funde. Vuelve cuando empieza el fundido.
static func close() -> void:
	if current == null:
		return
	var screen: Loading = current
	screen._note(1.0, "fin")
	for i in 3:
		await screen.get_tree().process_frame
	current = null
	screen._fading = 0.0


func _enter_tree() -> void:
	current = self


func _exit_tree() -> void:
	if current == self:
		current = null


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_trace = OS.get_environment("LOAD_TIMES") != ""
	_mark = Time.get_ticks_msec()
	_art = LoadingArt.new()
	_art.title = title
	_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Se traga los toques: nada de lo de debajo los recibe mientras carga.
	_art.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_art)


func _note(progress: float, what: String) -> void:
	_art.goal = clampf(progress, 0.0, 1.0)
	if _trace:
		var now: int = Time.get_ticks_msec()
		print("CARGA paso «%s» hasta %.2f: %d ms" % [what, progress, now - _mark])
		_mark = now


func _process(delta: float) -> void:
	if _fading < 0.0:
		return
	_fading += delta
	_art.modulate.a = 1.0 - clampf(_fading / FADE, 0.0, 1.0)
	if _fading >= FADE:
		queue_free()
