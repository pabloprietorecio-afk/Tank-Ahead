class_name Intro
extends Control
## Arranque del juego. Pone el vídeo de introducción (la pantalla de carga que se vuelve un carro
## de verdad, dispara y deja el título «A TANK STORY» a cañonazos) y, al acabar:
## - la primera vez, se queda en esa misma imagen del título y ofrece las banderas para elegir
##   idioma; el título se viste con la bandera elegida y «EMPEZAR LA BATALLA» lleva al menú;
## - las demás veces, pasa al menú.
## El vídeo se salta tocando la pantalla.

const VIDEO: String = "res://assets/video/intro.ogv"
const VIDEO_SIZE: Vector2 = Vector2(1280.0, 720.0)
const MENU: String = "res://levels/main_menu.tscn"
## Dónde queda el título al dejar sitio a las banderas (fracción del ancho) y cuánto se encoge.
const TITLE_AT: float = 0.24
const TITLE_SHRINK: float = 0.7
const PANEL_FROM: float = 0.455

enum Stage { VIDEO, LANGUAGE, LEAVING }

var stage: Stage = Stage.VIDEO
var title: TitleCard
var start_button: Button
var flags: Dictionary = {}

var _video: VideoStreamPlayer
var _hint: Label
var _panel: VBoxContainer
var _names: Dictionary = {}
var _clock: float = 0.0


func _ready() -> void:
	GameSettings.ensure_loaded()
	AudioSetup.ensure()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var look := ShaderMaterial.new()
	look.shader = load("res://shaders/intro_backdrop.gdshader")
	backdrop.material = look
	add_child(backdrop)
	title = TitleCard.new()
	title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(title)
	resized.connect(_layout)
	if ResourceLoader.exists(VIDEO):
		_video = VideoStreamPlayer.new()
		_video.stream = load(VIDEO)
		_video.expand = true
		_video.bus = AudioSetup.SFX
		_video.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_video.finished.connect(_after_video)
		add_child(_video)
		_hint = Label.new()
		_hint.text = Loc.t("TOCA PARA SALTAR")
		_hint.add_theme_font_size_override("font_size", 18)
		_hint.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.55))
		_hint.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.7))
		_hint.add_theme_constant_override("outline_size", 4)
		_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		_hint.offset_left = -330.0
		_hint.offset_top = -44.0
		_hint.offset_right = -22.0
		_hint.offset_bottom = -14.0
		_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_hint.modulate.a = 0.0
		add_child(_hint)
		_layout()
		_video.play()
	else:
		_layout()
		_after_video.call_deferred()


## El vídeo cubre la pantalla entera (se recorta lo que sobre) y el título se pone donde lo deja.
func _layout() -> void:
	var fit: float = maxf(size.x / VIDEO_SIZE.x, size.y / VIDEO_SIZE.y)
	if _video != null and is_instance_valid(_video):
		_video.size = VIDEO_SIZE * fit
		_video.position = (size - _video.size) * 0.5
	if stage == Stage.VIDEO:
		title.center = size * 0.5
		title.zoom = fit
	else:
		title.center = Vector2(size.x * TITLE_AT, size.y * 0.5)
		title.zoom = fit * TITLE_SHRINK
		_place_panel()


func _process(delta: float) -> void:
	_clock += delta
	if stage == Stage.VIDEO and _hint != null and _clock > 1.2:
		_hint.modulate.a = move_toward(_hint.modulate.a, 1.0, delta * 2.0)


func _unhandled_input(event: InputEvent) -> void:
	if stage != Stage.VIDEO:
		return
	var tap: bool = (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed) or event.is_action_pressed(&"ui_accept")
	if tap and _clock > 0.4:
		skip()


## Corta el vídeo y sigue como si hubiera acabado.
func skip() -> void:
	if stage == Stage.VIDEO:
		_after_video()


func _after_video() -> void:
	if stage != Stage.VIDEO:
		return
	if _hint != null:
		_hint.queue_free()
		_hint = null
	if _video != null:
		# El vídeo se funde sobre el título, que ya está debajo en el mismo sitio.
		var gone: VideoStreamPlayer = _video
		_video = null
		var fade: Tween = create_tween()
		fade.tween_property(gone, "modulate:a", 0.0, 0.3)
		fade.parallel().tween_property(gone, "volume_db", -40.0, 0.3)
		fade.tween_callback(gone.queue_free)
	if GameSession.language_chosen():
		_leave()
	else:
		_show_languages()


## Primera vez: el título se aparta a la izquierda y salen las banderas.
func _show_languages() -> void:
	stage = Stage.LANGUAGE
	# De entrada, el idioma del móvil si el juego lo habla.
	var device: String = OS.get_locale_language()
	if not FileAccess.file_exists(GameSettings.PATH) and device in Loc.LANGUAGES:
		GameSettings.set_language(device)
	var fit: float = maxf(size.x / VIDEO_SIZE.x, size.y / VIDEO_SIZE.y)
	var move: Tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	move.tween_property(title, "center", Vector2(size.x * TITLE_AT, size.y * 0.5), 0.6)
	move.tween_property(title, "zoom", fit * TITLE_SHRINK, 0.6)
	_build_panel()
	_panel.modulate.a = 0.0
	# Las rayas, las motas y el parpadeo de la película siguen por encima, como en el vídeo.
	var film := ColorRect.new()
	film.name = "Pelicula"
	film.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	film.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var damage := ShaderMaterial.new()
	damage.shader = load("res://shaders/old_film.gdshader")
	film.material = damage
	add_child(film)
	move.tween_property(_panel, "modulate:a", 1.0, 0.5).set_delay(0.35)
	title.wear(GameSettings.language, 0.9)


func _build_panel() -> void:
	_panel = VBoxContainer.new()
	_panel.alignment = BoxContainer.ALIGNMENT_CENTER
	_panel.add_theme_constant_override("separation", 26)
	add_child(_panel)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 14)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_panel.add_child(grid)
	for code: String in Loc.LANGUAGES:
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 0)
		var icon := FlagButton.create(code, false)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon.pressed.connect(pick.bind(code))
		cell.add_child(icon)
		var caption := Button.new()
		caption.flat = true
		caption.focus_mode = Control.FOCUS_NONE
		caption.text = Loc.LANGUAGE_NAMES[code]
		caption.add_theme_font_size_override("font_size", 17)
		caption.custom_minimum_size = Vector2(118.0, 30.0)
		caption.pressed.connect(pick.bind(code))
		cell.add_child(caption)
		grid.add_child(cell)
		flags[code] = icon
		_names[code] = caption
	start_button = Button.new()
	start_button.focus_mode = Control.FOCUS_NONE
	start_button.custom_minimum_size = Vector2(470.0, 76.0)
	start_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	start_button.add_theme_font_size_override("font_size", 30)
	start_button.add_theme_color_override("font_color", UiKit.FEATURED)
	start_button.add_theme_color_override("font_hover_color", UiKit.FEATURED)
	start_button.add_theme_color_override("font_pressed_color", Color.WHITE)
	for state: String in ["normal", "hover", "pressed"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.2, 0.16, 0.05, 0.92) if state != "pressed" else Color(0.42, 0.33, 0.1, 0.95)
		box.border_color = UiKit.FEATURED
		box.set_border_width_all(2)
		box.set_corner_radius_all(6)
		box.set_content_margin_all(12.0)
		start_button.add_theme_stylebox_override(state, box)
	start_button.pressed.connect(begin)
	_panel.add_child(start_button)
	_refresh_language()
	_place_panel()


func _place_panel() -> void:
	if _panel == null:
		return
	_panel.position = Vector2(size.x * PANEL_FROM, 0.0)
	_panel.size = Vector2(size.x * (1.0 - PANEL_FROM) - 18.0, size.y)


func _refresh_language() -> void:
	for code: String in flags:
		var current: bool = code == GameSettings.language
		(flags[code] as FlagButton).current = current
		(_names[code] as Button).add_theme_color_override("font_color", UiKit.FEATURED if current else Color(0.8, 0.8, 0.74))
	start_button.text = Loc.t("EMPEZAR LA BATALLA")


## Elige idioma: cambia los textos y viste el título con su bandera.
func pick(code: String) -> void:
	if stage != Stage.LANGUAGE:
		return
	GameSettings.set_language(code)
	_refresh_language()
	title.wear(code)


## «EMPEZAR LA BATALLA»: queda elegido el idioma y se pasa al menú.
func begin() -> void:
	if stage != Stage.LANGUAGE:
		return
	GameSession.mark_language_chosen()
	GameSettings.save()
	_leave()


func _leave() -> void:
	stage = Stage.LEAVING
	var veil := ColorRect.new()
	veil.color = Color(0.0, 0.0, 0.0, 0.0)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(veil)
	var fade: Tween = create_tween()
	fade.tween_property(veil, "color:a", 1.0, 0.4)
	fade.tween_callback(func() -> void: get_tree().change_scene_to_file(MENU))
