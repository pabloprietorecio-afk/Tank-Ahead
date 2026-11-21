class_name Loading
extends CanvasLayer
## Pantalla de carga: tapa el cambio de escena mientras se monta el campo de batalla. Un tanque
## avanza por un terreno ondulado y una barra fina dice cuánto falta.
##
## Montar el campo ocupa al juego entero, así que se hace a trocitos para que la animación vaya
## fluida: la escena se lee del disco en otro hilo y la arena y el modo de juego, en sus bucles,
## ceden un cuadro cada pocos milisegundos de trabajo (`await Loading.breathe()`), además de en
## cada paso grande (`await Loading.step(...)`, que mueve la barra). Mientras dura, el árbol está
## en pausa (nada de la partida echa a andar a medio montar) y el mundo 3D no se pinta (lo tapa
## esta pantalla y pintarlo en cada cuadro alargaría la carga); se pinta en los últimos cuadros,
## ya con todo montado, para que la tarjeta gráfica lo prepare antes de retirar la pantalla.
## Sin pantalla de carga abierta (las pruebas) nada cede y la arena se monta de una vez.

const FADE: float = 0.4
## Trabajo de montaje que cabe en un cuadro (ms) antes de ceder para repintar: deja sitio al
## pintado dentro de los 33 ms de un cuadro a 30 por segundo.
const BUDGET_MS: int = 10

static var current: Loading
## Cómo fue la última carga (cuadros, duración, el cuadro más largo): para el diagnóstico oculto
## del menú, que es donde se puede leer en un móvil.
static var last_report: String = ""

var title: String = ""
var _art: LoadingArt
var _fading: float = -1.0
## Con LOAD_TIMES en el entorno imprime lo que tarda cada paso.
var _mark: int = 0
var _trace: bool = false
## Cuándo empezó el cuadro en curso (ms) y, para la traza, lo que tardó cada cuadro.
var _frame_at: int = 0
var _gaps: PackedInt32Array = []
var _stage: String = ""


## Abre la pantalla de carga y, cuando ya se ve, cambia a la escena `path`. La escena se lee del
## disco en otro hilo: mientras, la pantalla sigue pintándose a su ritmo.
static func open(tree: SceneTree, path: String, heading: String = "") -> void:
	if current != null:
		return
	var screen := Loading.new()
	screen.title = heading
	tree.root.add_child(screen)
	tree.paused = true
	tree.root.disable_3d = true
	var threaded: bool = ResourceLoader.load_threaded_request(path) == OK
	# Dos cuadros para que la pantalla esté pintada antes de que el juego se ponga a montar.
	await tree.process_frame
	await tree.process_frame
	var packed: PackedScene = null
	if threaded:
		while ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			await tree.process_frame
		if ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_LOADED:
			packed = ResourceLoader.load_threaded_get(path) as PackedScene
	if current != null:
		current._note(0.02, "leer la escena")
	if packed != null:
		tree.change_scene_to_packed(packed)
	else:
		tree.change_scene_to_file(path)


## Avisa de cuánto va montado (0..1) y cede un cuadro para que la pantalla se repinte.
static func step(progress: float, what: String = "") -> void:
	if current == null:
		return
	current._note(progress, what)
	await current.get_tree().process_frame


## Para los bucles largos del montaje: cede un cuadro si el actual ya lleva BUDGET_MS de trabajo,
## y si no, sigue sin parar. Así la pantalla se repinta a su ritmo por largo que sea el bucle.
## Se llama con `await`; sin pantalla de carga abierta (las pruebas) nunca cede.
static func breathe() -> void:
	if current == null or Time.get_ticks_msec() - current._frame_at < BUDGET_MS:
		return
	await current.get_tree().process_frame


## Fin de la carga: deja pintar un par de cuadros del campo ya montado (ahí se preparan los
## materiales, y el tirón queda tapado) y se funde. Vuelve cuando empieza el fundido.
static func close() -> void:
	if current == null:
		return
	var screen: Loading = current
	screen._note(1.0, "fin")
	screen._report()
	screen.get_tree().root.disable_3d = false
	for i in 3:
		await screen.get_tree().process_frame
	last_report += " | %d ms en pintar el campo por primera vez" % (Time.get_ticks_msec() - screen._frame_at + (screen._gaps[-1] if not screen._gaps.is_empty() else 0) + (screen._gaps[-2] if screen._gaps.size() > 1 else 0))
	if screen._trace:
		print("CARGA ", last_report)
	current = null
	screen._fading = 0.0


func _enter_tree() -> void:
	current = self


func _exit_tree() -> void:
	if current == self:
		current = null
	if get_tree() != null:
		get_tree().root.disable_3d = false


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
	_stage = what
	if _trace:
		var now: int = Time.get_ticks_msec()
		print("CARGA paso «%s» hasta %.2f: %d ms" % [what, progress, now - _mark])
		_mark = now


## Cómo de fluida fue la carga: cuadros pintados y cuánto duraron (lo miran las pruebas).
func frame_times() -> PackedInt32Array:
	return _gaps


func _report() -> void:
	if _gaps.is_empty():
		return
	var sorted: Array = Array(_gaps)
	sorted.sort()
	var total: int = 0
	var slow: int = 0
	for gap: int in sorted:
		total += gap
		slow += int(gap > 50)
	last_report = "%d cuadros en %.1f s | el más largo %d ms | mediana %d ms | de más de 50 ms: %d" % [sorted.size(), total / 1000.0, sorted[-1], sorted[sorted.size() / 2], slow]


func _process(delta: float) -> void:
	var now: int = Time.get_ticks_msec()
	if _fading < 0.0 and _frame_at > 0:
		_gaps.append(now - _frame_at)
		if _trace and now - _frame_at > 20:
			print("CARGA cuadro largo: %d ms, pasado «%s» (%.2f)" % [now - _frame_at, _stage, _art.goal])
	_frame_at = now
	if _fading < 0.0:
		return
	_fading += delta
	_art.modulate.a = 1.0 - clampf(_fading / FADE, 0.0, 1.0)
	if _fading >= FADE:
		queue_free()
