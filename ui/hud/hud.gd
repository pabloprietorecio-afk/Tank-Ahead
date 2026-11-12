class_name Hud
extends Control
## HUD: estado del modo, avisos, retícula, recarga, blindaje, ficha del objetivo (blindaje,
## ataque e historia), icono del tanque, pausa, ajustes y pantalla final.

@export var tank: Tank
@export var director: GameMode
## Retícula del cañón: rojo vivo con borde oscuro, brazos de 8 a 22 px y 4 px de grosor.
const RETICLE_COLOR := Color(1.0, 0.1, 0.08)
const RETICLE_EDGE := Color(0.0, 0.0, 0.0, 0.85)
const RETICLE_WIDTH: float = 4.0
const RETICLE_EDGE_EXTRA: float = 3.0
const RETICLE_INNER: float = 8.0
const RETICLE_OUTER: float = 22.0
const RETICLE_FRAME: float = 30.0

var touch: TouchControls
var input_source: PlayerInputSource
var weather: Weather

var _info: Label
var _message: Label
var _end_panel: PanelContainer
## Hay una pausa publicitaria en curso (evita pulsar dos veces).
var _ad_busy: bool = false
var _pause_panel: PanelContainer
var _history_panel: PanelContainer
var _history_button: Button
var _version: String = ""
var _message_time: float = 0.0
var _flash: float = 0.0
## Velo de pantalla: esquinas oscurecidas y bordes rojos al recibir un impacto.
var _overlay: ColorRect
var _release: Button
## Botones del HUD por nombre: gear, cam, zoom, missile, strike, release.
var controls: Dictionary = {}
## Con el foco activo (tutorial) solo responden los botones de `focus` y ⚙; el resto se atenúa.
var focus_active: bool = false
var focus: Array[String] = []
## Interruptores del menú de opciones por nombre: easy_drive, aim_assist.
var toggles: Dictionary = {}



func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_version = str(ProjectSettings.get_setting("application/config/version", "dev"))
	_info = _make_label(22, Vector2(24.0, 16.0))
	_message = _make_label(26, Vector2.ZERO)
	_message.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_message.position.y = 110.0
	_message.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_overlay = ColorRect.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.show_behind_parent = true
	var overlay_material := ShaderMaterial.new()
	overlay_material.shader = load("res://shaders/screen_overlay.gdshader")
	_overlay.material = overlay_material
	add_child(_overlay)
	tank.damaged.connect(func(amount: float, _s: Node) -> void: _flash = minf(_flash + amount / 40.0, 0.6))
	director.message.connect(_show_message)
	director.ended.connect(_on_ended)
	GameSettings.ensure_loaded()
	_build_settings()
	_build_pause_and_history()


func _build_settings() -> void:
	# ⚙ abre el menú de opciones, que pone el juego en pausa.
	var gear := Button.new()
	gear.text = "⚙"
	gear.add_theme_font_size_override("font_size", 40)
	gear.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	gear.position = Vector2(-90.0, 14.0)
	gear.size = Vector2(76.0, 76.0)
	gear.pressed.connect(func() -> void: _set_paused(not get_tree().paused))
	add_child(gear)

	var view_button := Button.new()
	view_button.text = Loc.t("CÁM")
	view_button.add_theme_font_size_override("font_size", 22)
	view_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	view_button.offset_left = -180.0
	view_button.offset_right = -100.0
	view_button.offset_top = 14.0
	view_button.offset_bottom = 90.0
	view_button.pressed.connect(func() -> void:
		GameSettings.camera_view = (GameSettings.camera_view + 1) % 3
		GameSettings.save()
		tank.set_view(GameSettings.camera_view)
		_show_message([Loc.t("VISTA CABINA"), Loc.t("VISTA TRASERA"), Loc.t("VISTA TRASERA LEJANA")][GameSettings.camera_view], false))
	add_child(view_button)
	tank.set_view.call_deferred(GameSettings.camera_view)

	_release = Button.new()
	_release.text = Loc.t("LIBERAR\nOBJETIVO")
	_release.add_theme_font_size_override("font_size", 24)
	_release.add_theme_color_override("font_color", VectorMaterials.ORANGE)
	_release.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_release.offset_left = -640.0
	_release.offset_top = -200.0
	_release.offset_right = -440.0
	_release.offset_bottom = -110.0
	_release.visible = false
	_release.pressed.connect(func() -> void:
		if input_source != null:
			input_source.release_lock())
	add_child(_release)
	controls["gear"] = gear
	controls["cam"] = view_button
	controls["release"] = _release
	if touch != null:
		touch.exclusions.append_array([gear, view_button, _release])


func _button(text: String, font_size: int = 26) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", font_size)
	button.custom_minimum_size = Vector2(260.0, 70.0)
	return button


## `alpha` es la opacidad del fondo (el panel de fin de partida es semitransparente).
func _centered_panel(alpha: float = 0.97) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.08, 0.07, alpha)
	style.border_color = Color(0.6, 0.5, 0.3)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", style)
	panel.visible = false
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)
	return panel


## Tamaños de referencia del menú de opciones (a escala 1): ancho de la columna de acciones, alto
## de sus botones y alto de las filas de la derecha.
const MENU_ACTION_WIDTH: float = 400.0
const MENU_ACTION_HEIGHT: float = 76.0
const MENU_ROW_HEIGHT: float = 60.0
## Escalas que se prueban, de la más grande a la más pequeña (la última es la letra de antes).
const MENU_SCALES: Array[float] = [1.25, 1.18, 1.12, 1.06, 1.0, 0.94, 0.88, 0.82, 0.78]
## Margen que debe quedar entre el menú y los bordes de la pantalla.
const MENU_MARGIN := Vector2(20.0, 12.0)

## Piezas del menú de opciones que cambian con la escala: [control, tamaño de letra a escala 1],
## [control, tamaño mínimo a escala 1] e interruptores [botón, tamaño de letra a escala 1].
var _menu_fonts: Array = []
var _menu_sizes: Array = []
var _menu_toggles: Array = []
var _menu_sliders: VolumeSliders
var _menu_hint: Label
## Escala con la que se ha montado el menú (para pruebas y capturas).
var menu_scale: float = 1.0


func _menu_font(control: Control, font_size: int) -> void:
	_menu_fonts.append([control, font_size])
	control.add_theme_font_size_override("font_size", font_size)


func _menu_size(control: Control, minimum: Vector2) -> void:
	_menu_sizes.append([control, minimum])
	control.custom_minimum_size = minimum


func _menu_button(text: String, font_size: int, minimum: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	_menu_font(button, font_size)
	_menu_size(button, minimum)
	return button


## Menú de opciones (pausa): a la izquierda las acciones, a la derecha sonido, ayudas y gráficos.
## La letra y los interruptores van al mayor tamaño que quepa en la pantalla (_fit_pause_menu).
func _build_pause_and_history() -> void:
	_pause_panel = _centered_panel()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_pause_panel.add_child(box)
	var title := Label.new()
	title.text = Loc.t("OPCIONES — JUEGO EN PAUSA")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu_font(title, 34)
	box.add_child(title)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 26)
	box.add_child(columns)
	var actions := VBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	columns.add_child(actions)
	var options := VBoxContainer.new()
	options.add_theme_constant_override("separation", 4)
	columns.add_child(options)

	var action_size := Vector2(MENU_ACTION_WIDTH, MENU_ACTION_HEIGHT)
	var resume := _menu_button(Loc.t("CONTINUAR"), 30, action_size)
	resume.pressed.connect(func() -> void: _set_paused(false))
	actions.add_child(resume)
	# Dificultad: el botón la cambia y debajo va su explicación (en dos líneas como mucho).
	var difficulty := _menu_button("", 28, action_size)
	_menu_hint = Label.new()
	_menu_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_menu_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_menu_hint.add_theme_color_override("font_color", Color(0.82, 0.84, 0.78))
	_menu_font(_menu_hint, 20)
	var refresh: Callable = func() -> void:
		var parts: PackedStringArray = (Loc.t("DIFICULTAD: %s\n%s") % [Loc.t(GameSettings.DIFFICULTY_NAMES[GameSettings.difficulty]), Loc.t(GameSettings.DIFFICULTY_HINTS[GameSettings.difficulty])]).split("\n", true, 1)
		difficulty.text = parts[0]
		_menu_hint.text = parts[1] if parts.size() > 1 else ""
	difficulty.pressed.connect(func() -> void:
		GameSettings.difficulty = (GameSettings.difficulty + 1) % 4
		GameSettings.save()
		refresh.call())
	refresh.call()
	actions.add_child(difficulty)
	actions.add_child(_menu_hint)
	var vehicles := _menu_button(Loc.t("HISTORIA: VEHÍCULOS DEL JUEGO"), 24, action_size)
	vehicles.pressed.connect(func() -> void:
		_history_from_menu = true
		_pause_panel.visible = false
		_history_gallery.show_index(0)
		move_child(_history_panel, -1)
		_history_panel.visible = true)
	actions.add_child(vehicles)
	var restart := _menu_button(Loc.t("REINICIAR"), 30, action_size)
	restart.pressed.connect(_restart)
	actions.add_child(restart)
	var menu := _menu_button(Loc.t("ABANDONAR"), 30, action_size)
	menu.add_theme_color_override("font_color", VectorMaterials.ORANGE)
	menu.pressed.connect(_to_menu)
	actions.add_child(menu)

	_menu_sliders = VolumeSliders.create(2, 26, Vector2(220.0, 50.0))
	options.add_child(_menu_sliders)
	options.add_child(_make_toggle(Loc.t("Destacar enemigos (borde amarillo)"), GameSettings.highlight_enemies, func(on: bool) -> void:
		GameSettings.highlight_enemies = on
		GameSettings.save()
		for node in get_tree().get_nodes_in_group(&"tanks"):
			(node as Tank).refresh_highlight()))
	options.add_child(_make_toggle(Loc.t("Destacar objetivos (borde azul)"), GameSettings.highlight_objectives, func(on: bool) -> void:
		GameSettings.highlight_objectives = on
		GameSettings.save()
		get_tree().call_group(&"objectives", &"refresh_highlight")
		for node in get_tree().get_nodes_in_group(&"tanks"):
			(node as Tank).refresh_highlight()))
	toggles["easy_drive"] = _make_toggle(Loc.t("Movimiento fácil (el tanque se alinea con el cañón)"), GameSettings.easy_drive, func(on: bool) -> void:
		GameSettings.easy_drive = on
		GameSettings.save())
	options.add_child(toggles["easy_drive"])
	options.add_child(_make_toggle(Loc.t("Recentrar el cañón al frente (sin movimiento fácil)"), GameSettings.auto_recenter, func(on: bool) -> void:
		GameSettings.auto_recenter = on
		GameSettings.save()))
	toggles["aim_assist"] = _make_toggle(Loc.t("Apuntado automático (cerca del enemigo)"), GameSettings.aim_assist, func(on: bool) -> void:
		GameSettings.aim_assist = on
		GameSettings.save())
	options.add_child(toggles["aim_assist"])
	options.add_child(_make_toggle(Loc.t("Sombras (desactivar si va lento)"), GameSettings.shadows, func(on: bool) -> void:
		GameSettings.shadows = on
		GameSettings.save()
		var sun := get_tree().current_scene.get_node_or_null("Sun") as DirectionalLight3D
		if sun != null:
			sun.shadow_enabled = on))
	var effects := _menu_button("", 26, Vector2(0.0, MENU_ROW_HEIGHT))
	_refresh_effects = func() -> void:
		var text: String = Loc.t("EFECTOS GRÁFICOS: %s") % Loc.t(GameSettings.EFFECTS_NAMES[GameSettings.effects])
		var in_use: int = Fx.on(self).level()
		if in_use < GameSettings.effects:
			# El juego los ha bajado solo porque el teléfono no llegaba.
			text += Loc.t(" (ahora en %s: iba lento)") % Loc.t(GameSettings.EFFECTS_NAMES[in_use])
		effects.text = text
	effects.pressed.connect(func() -> void:
		# ALTOS → MEDIOS → BAJOS → ALTOS.
		GameSettings.effects = (GameSettings.effects + 2) % 3
		GameSettings.save()
		Fx.quality = GameSettings.effects
		Fx.on(self).set_level(GameSettings.effects)
		_refresh_effects.call())
	_refresh_effects.call()
	options.add_child(effects)

	# Botón HISTORIA junto a la ficha del objetivo fijado.
	_history_button = _button(Loc.t("HISTORIA"), 20)
	_history_button.custom_minimum_size = Vector2(130.0, 48.0)
	_history_button.set_anchors_preset(Control.PRESET_CENTER)
	_history_button.offset_left = 150.0
	_history_button.offset_right = 280.0
	_history_button.offset_top = -100.0
	_history_button.offset_bottom = -52.0
	_history_button.visible = false
	_history_button.pressed.connect(_show_history)
	add_child(_history_button)

	_history_panel = _centered_panel()
	_history_gallery = VehicleGallery.new()
	_history_panel.add_child(_history_gallery)
	_history_gallery.closed.connect(_close_history)

	_end_panel = _centered_panel(0.55)
	if touch != null:
		touch.exclusions.append_array([_pause_panel, _history_button, _history_panel, _end_panel])
	_build_arsenal()


var _zoom_button: Button
## Pone al día el texto del botón EFECTOS (el nivel puede haber bajado solo durante la partida).
var _refresh_effects: Callable
var _missile_button: Button
var _strike_button: Button
var _follow_button: CommandButton
var _focus_button: CommandButton
var _binocular_mask: ColorRect
var _history_gallery: VehicleGallery
## La ficha se abrió desde el menú de opciones: al cerrarla se vuelve a él.
var _history_from_menu: bool = false


## Prismáticos (arriba, lejos de la zona donde se arrastra para mover la torreta) y, solo con
## ellos puestos, misil guiado y bombardeo aliado (al borde derecho, sobre FIRE).
func _build_arsenal() -> void:
	_binocular_mask = ColorRect.new()
	_binocular_mask.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_binocular_mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/binoculars.gdshader")
	_binocular_mask.material = mat
	_binocular_mask.visible = false
	# La máscara va por debajo de los controles táctiles y del resto de la interfaz, para que
	# el botón FIRE y los demás se sigan viendo con los prismáticos puestos.
	_place_mask.call_deferred()
	_zoom_button = _button("ZOOM", 22)
	_zoom_button.custom_minimum_size = Vector2.ZERO
	_zoom_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_zoom_button.offset_left = -300.0
	_zoom_button.offset_right = -190.0
	_zoom_button.offset_top = 14.0
	_zoom_button.offset_bottom = 90.0
	add_child(_zoom_button)
	var specs: Array = [[Loc.t("MISIL"), -430.0], [Loc.t("AVIÓN"), -345.0]]
	var buttons: Array[Button] = [_zoom_button]
	for spec in specs:
		var button := _button(spec[0], 22)
		button.custom_minimum_size = Vector2.ZERO
		button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		button.offset_left = -196.0
		button.offset_right = -14.0
		button.offset_top = spec[1]
		button.offset_bottom = spec[1] + 75.0
		button.visible = false
		add_child(button)
		buttons.append(button)
	_missile_button = buttons[1]
	_strike_button = buttons[2]
	controls["zoom"] = _zoom_button
	controls["missile"] = _missile_button
	controls["strike"] = _strike_button
	_zoom_button.pressed.connect(func() -> void: tank.set_binoculars(not tank.binoculars))
	_missile_button.pressed.connect(func() -> void: director.fire_missile())
	_strike_button.pressed.connect(func() -> void: director.call_air_strike())
	# Órdenes a los aliados: iconos a la izquierda, a media altura (sin texto).
	_follow_button = CommandButton.create(CommandButton.Kind.FOLLOW)
	_focus_button = CommandButton.create(CommandButton.Kind.FOCUS)
	var offsets: Array = [-104.0, 16.0]
	for pair in [[_follow_button, offsets[0]], [_focus_button, offsets[1]]]:
		var icon: CommandButton = pair[0]
		icon.set_anchors_preset(Control.PRESET_CENTER_LEFT)
		icon.offset_left = 22.0
		icon.offset_right = 110.0
		icon.offset_top = pair[1]
		icon.offset_bottom = pair[1] + 88.0
		icon.visible = false
		add_child(icon)
		buttons.append(icon)
	controls["follow"] = _follow_button
	controls["focus"] = _focus_button
	_follow_button.pressed.connect(func() -> void: director.toggle_follow())
	_focus_button.pressed.connect(func() -> void: director.focus_fire())
	if touch != null:
		touch.exclusions.append_array(buttons)


func _place_mask() -> void:
	var layer: Node = get_parent()
	layer.add_child(_binocular_mask)
	layer.move_child(_binocular_mask, 0)


## Abrir el menú de opciones pone el juego en pausa; cerrarlo lo reanuda.
func _set_paused(paused: bool) -> void:
	if director.is_over:
		return
	get_tree().paused = paused
	if paused and _refresh_effects.is_valid():
		_refresh_effects.call()
	if paused:
		_fit_pause_menu()
	move_child(_pause_panel, -1)
	_pause_panel.visible = paused
	_history_panel.visible = false


func _show_history() -> void:
	var target: Tank = tank.aim_lock
	if target == null or not is_instance_valid(target):
		return
	_history_from_menu = false
	_history_gallery.show_stats(target.stats, target.paint)
	move_child(_history_panel, -1)
	_history_panel.visible = true
	get_tree().paused = true


func _close_history() -> void:
	_history_panel.visible = false
	if _history_from_menu:
		_history_from_menu = false
		move_child(_pause_panel, -1)
		_pause_panel.visible = true
	else:
		get_tree().paused = false


## Ejecuta `action` tras la pausa publicitaria (si toca; ver Ads.interstitial_then). Un solo toque.
func _with_ad(action: Callable, with_ad: bool) -> void:
	if not with_ad:
		action.call()
		return
	if _ad_busy:
		return
	_ad_busy = true
	Ads.interstitial_then(action)


func _restart() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()


func _to_menu() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file("res://levels/main_menu.tscn")


func _on_ended(victory: bool, title_text: String, detail: String) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	_end_panel.add_child(box)
	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", VectorMaterials.GREEN if victory else VectorMaterials.ORANGE)
	box.add_child(title)
	var info := Label.new()
	info.text = detail
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_font_size_override("font_size", 24)
	box.add_child(info)
	# Anuncio intersticial: al pasar a la siguiente partida tras ganar una misión de la historia o
	# al acabar una de supervivencia. Nunca tras perder en la historia ni antes de la pantalla premium.
	var story_win: bool = victory and director is StoryMode
	var ad_after: bool = story_win or director is SurvivalMode
	if story_win:
		# El desbloqueo por anuncio recompensado vale hasta superar la misión.
		GameSession.clear_reward_unlock()
	if story_win and (director as StoryMode).has_next_mission():
		var next_locked: bool = GameSession.mission_locked(GameSession.mission_index + 1)
		var next := _button(Loc.t("SIGUIENTE MISIÓN (PREMIUM)") if next_locked else Loc.t("SIGUIENTE MISIÓN"))
		next.pressed.connect(func() -> void:
			GameSession.mission_index += 1
			if next_locked:
				GameSession.menu_page = "premium"
				_to_menu()
			else:
				_with_ad(_restart, ad_after))
		box.add_child(next)
	var replay_locked: bool = story_win and GameSession.mission_locked(GameSession.mission_index)
	var retry_text: String = Loc.t("REINTENTAR")
	if victory:
		retry_text = Loc.t("JUGAR OTRA VEZ (PREMIUM)") if replay_locked else Loc.t("JUGAR OTRA VEZ")
	var retry := _button(retry_text)
	retry.pressed.connect(func() -> void:
		if replay_locked:
			GameSession.menu_page = "premium"
			_to_menu()
		else:
			_with_ad(_restart, ad_after))
	box.add_child(retry)
	if story_win:
		# Repetir la misión recién superada con otro tanque del bando (premium): se elige en el
		# parte de la misión. Sin premium lleva a la pantalla que lo explica.
		var premium: bool = Premium.is_premium()
		var other := _button(Loc.t("REPETIR CON OTRO TANQUE") if premium else Loc.t("REPETIR CON OTRO TANQUE (PREMIUM)"))
		other.pressed.connect(func() -> void:
			GameSession.menu_page = "briefing" if premium else "premium"
			_to_menu())
		box.add_child(other)
	var menu := _button(Loc.t("MENÚ PRINCIPAL"))
	# En supervivencia el anuncio sale también al volver al menú (es el final de la partida).
	menu.pressed.connect(func() -> void:
		_with_ad(_to_menu, director is SurvivalMode))
	box.add_child(menu)
	# Deja ver la escena unos instantes antes de mostrar el panel.
	get_tree().create_timer(1.2).timeout.connect(func() -> void:
		move_child(_end_panel, -1)
		_end_panel.visible = true)


## Interruptor del menú de opciones (su tamaño lo pone _apply_menu_scale).
func _make_toggle(text: String, value: bool, on_change: Callable) -> CheckButton:
	var toggle: CheckButton = UiKit.toggle(text, value, on_change, 30)
	_menu_toggles.append([toggle, 30])
	return toggle


## Monta el menú de opciones a la mayor escala con la que cabe entero en la pantalla, sin
## desplazarlo: prueba de la más grande a la más pequeña, con los cuatro volúmenes en una fila
## (pantallas anchas) o en dos. `screen` es el tamaño de pantalla a usar (cero = el de verdad).
func _fit_pause_menu(screen: Vector2 = Vector2.ZERO) -> void:
	var room: Vector2 = (screen if screen != Vector2.ZERO else size) - MENU_MARGIN * 2.0
	for scale: float in MENU_SCALES:
		for per_row: int in [4, 2]:
			_apply_menu_scale(scale, per_row)
			var needed: Vector2 = _pause_panel.get_combined_minimum_size()
			if needed.x <= room.x and needed.y <= room.y:
				return


func _apply_menu_scale(scale: float, sliders_per_row: int) -> void:
	menu_scale = scale
	for entry: Array in _menu_fonts:
		(entry[0] as Control).add_theme_font_size_override("font_size", roundi(entry[1] * scale))
	for entry: Array in _menu_sizes:
		(entry[0] as Control).custom_minimum_size = (entry[1] as Vector2) * scale
	for entry: Array in _menu_toggles:
		UiKit.style_toggle(entry[0], roundi(entry[1] * scale))
		(entry[0] as Control).custom_minimum_size.y = maxf((entry[0] as Control).custom_minimum_size.y, MENU_ROW_HEIGHT * scale)
	_menu_sliders.layout(sliders_per_row, roundi(26.0 * scale), Vector2((200.0 if sliders_per_row == 4 else 240.0) * scale, 50.0 * scale))
	# La explicación de la dificultad reserva sitio para la más larga de las cuatro, para que el
	# menú no cambie de tamaño al cambiar de dificultad.
	var font: Font = _menu_hint.get_theme_font("font")
	var font_size: int = roundi(20.0 * scale)
	var width: float = MENU_ACTION_WIDTH * scale
	var height: float = 0.0
	for hint: String in GameSettings.DIFFICULTY_HINTS:
		height = maxf(height, font.get_multiline_string_size(Loc.t(hint), HORIZONTAL_ALIGNMENT_CENTER, width, font_size).y)
	_menu_hint.custom_minimum_size = Vector2(width, height)


func _make_label(font_size: int, pos: Vector2) -> Label:
	var label := Label.new()
	label.position = pos
	label.add_theme_color_override("font_color", VectorMaterials.GREEN)
	label.add_theme_font_size_override("font_size", font_size)
	# Con borde oscuro: el verde se pierde sobre un cielo claro o un suelo soleado.
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	label.add_theme_constant_override("outline_size", 6)
	add_child(label)
	return label


func _show_message(text: String, urgent: bool) -> void:
	_message.text = text
	_message.add_theme_color_override("font_color", VectorMaterials.ORANGE if urgent else VectorMaterials.GREEN)
	_message_time = 3.5


func _process(delta: float) -> void:
	_message_time = maxf(_message_time - delta, 0.0)
	_message.modulate.a = clampf(_message_time, 0.0, 1.0)
	_flash = maxf(_flash - delta * 1.5, 0.0)
	# Las esquinas oscurecidas solo se pintan con los efectos altos; el rojo del impacto, siempre.
	var vignette: bool = Fx.on(self).level() >= 2
	_overlay.visible = vignette or _flash > 0.0
	if _overlay.visible:
		(_overlay.material as ShaderMaterial).set_shader_parameter("hurt", _flash)
		(_overlay.material as ShaderMaterial).set_shader_parameter("vignette", 0.3 if vignette else 0.0)
	_release.visible = tank.aim_lock != null and not director.is_over
	_history_button.visible = _release.visible and not get_tree().paused
	_missile_button.text = Loc.t("MISIL %d") % director.missiles
	_missile_button.disabled = director.missiles <= 0
	_strike_button.text = Loc.tc("AVIÓN %d", "boton") % director.strikes
	_strike_button.disabled = director.strikes <= 0
	_zoom_button.text = "NORMAL" if tank.binoculars else "ZOOM"
	# Misil y aviación solo se ofrecen con los prismáticos puestos.
	_missile_button.visible = tank.binoculars and not director.is_over
	_strike_button.visible = tank.binoculars and not director.is_over
	# Órdenes a los aliados: solo si los hay (y no en el tutorial).
	var commands: bool = director.wants_commands() and director.allies_alive > 0 and not director.is_over
	_follow_button.visible = commands
	_focus_button.visible = commands
	_follow_button.active = director.follow_me
	_focus_button.active = director.focus_target != null
	if focus_active:
		_apply_focus()
	_binocular_mask.visible = tank.binoculars
	if _binocular_mask.visible:
		(_binocular_mask.material as ShaderMaterial).set_shader_parameter("screen_size", size)
	var sky: String = weather.display_name() if weather != null else ""
	_info.text = "v%s  %d FPS   %s   %s\n%s" % [_version, Engine.get_frames_per_second(), Loc.t(Fronts.NAMES[director.front]), sky, director.status_text()]
	queue_redraw()


## Tutorial: atenúa y bloquea los botones que aún no se han enseñado.
func _apply_focus() -> void:
	for key in controls:
		var button: Button = controls[key]
		var on: bool = key == "gear" or focus.has(key)
		button.modulate.a = 1.0 if on else 0.25
		if not on:
			button.disabled = true
		elif key != "missile" and key != "strike":
			button.disabled = false


func _draw() -> void:
	var center: Vector2 = size * 0.5
	var green: Color = VectorMaterials.GREEN
	var locked: bool = tank != null and tank.aim_lock != null
	_draw_reticle(_aim_screen_point(center), locked)
	if tank == null:
		return
	if tank.aim_lock != null and is_instance_valid(tank.aim_lock):
		var target: Tank = tank.aim_lock
		var font: Font = ThemeDB.fallback_font
		var label: String = "%s  %d m" % [target.stats.display_name, roundi(tank.global_position.distance_to(target.global_position))]
		draw_string(font, center + Vector2(-140.0, -60.0), label, HORIZONTAL_ALIGNMENT_CENTER, 280.0, 18, target.stats.color)
		# Blindaje restante y potencia de ataque del objetivo.
		var armor_bar := Rect2(center + Vector2(-60.0, -46.0), Vector2(120.0, 6.0))
		draw_string(font, armor_bar.position + Vector2(-78.0, 7.0), Loc.t("BLINDAJE"), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color(0.8, 0.9, 0.8))
		draw_rect(armor_bar, Color(0.3, 1.0, 0.4, 0.3), false, 1.0)
		draw_rect(Rect2(armor_bar.position, Vector2(armor_bar.size.x * target.health.fraction(), armor_bar.size.y)), Color(0.3, 1.0, 0.4), true)
		var attack_bar := Rect2(center + Vector2(-60.0, -36.0), Vector2(120.0, 6.0))
		draw_string(font, attack_bar.position + Vector2(-78.0, 7.0), Loc.t("ATAQUE"), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color(0.9, 0.8, 0.8))
		draw_rect(attack_bar, Color(1.0, 0.3, 0.2, 0.3), false, 1.0)
		var power: float = clampf(target.stats.damage / 25.0, 0.0, 1.0)
		draw_rect(Rect2(attack_bar.position, Vector2(attack_bar.size.x * power, attack_bar.size.y)), Color(1.0, 0.3, 0.2), true)
		draw_string(font, attack_bar.position + Vector2(126.0, 7.0), "%d" % roundi(target.stats.damage), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color(1.0, 0.5, 0.4))
	# Barra de recarga bajo la retícula
	var ready_fraction: float = tank.weapon.ready_fraction()
	var bar_color: Color = green if ready_fraction >= 1.0 else VectorMaterials.ORANGE
	var bar_origin: Vector2 = center + Vector2(-30.0, 34.0)
	draw_rect(Rect2(bar_origin, Vector2(60.0, 6.0)), Color(bar_color, 0.3), false, 1.0)
	draw_rect(Rect2(bar_origin, Vector2(60.0 * ready_fraction, 6.0)), bar_color, true)
	_draw_armor(center)
	_draw_objectives()
	_draw_flag_board()
	_draw_raid_warning(center)
	# Icono del tanque visto desde arriba (norte arriba): casco y cañón con su orientación real.
	_draw_tank_icon(Vector2(center.x, 74.0), green)


## Retícula del cañón: roja y gruesa, con un borde oscuro para que se vea igual sobre el cielo
## claro, el atardecer o el campo. Con un objetivo fijado se vuelve naranja y se rodea de un
## marco (la forma distingue el estado aunque el color se confunda). Si apunta fuera de la
## pantalla (cañón muy alzado en una vista exterior) se queda en el borde con una flecha.
func _draw_reticle(aim: Vector2, locked: bool) -> void:
	var color: Color = VectorMaterials.ORANGE if locked else RETICLE_COLOR
	# Arriba deja libre el icono del tanque (y su N), que ocupa hasta unos 100 px (y la flecha sale por encima de la mira).
	var margin: float = 46.0
	var top: float = 150.0
	var inside := Rect2(Vector2(margin, top), Vector2(size.x - margin * 2.0, size.y - top - margin))
	var pointer := Vector2.ZERO
	if not inside.has_point(aim):
		var edge := Vector2(clampf(aim.x, inside.position.x, inside.end.x), clampf(aim.y, inside.position.y, inside.end.y))
		pointer = (aim - edge).normalized()
		aim = edge
	var arms: Array = [
		[Vector2(-RETICLE_OUTER, 0.0), Vector2(-RETICLE_INNER, 0.0)],
		[Vector2(RETICLE_INNER, 0.0), Vector2(RETICLE_OUTER, 0.0)],
		[Vector2(0.0, -RETICLE_OUTER), Vector2(0.0, -RETICLE_INNER)],
		[Vector2(0.0, RETICLE_INNER), Vector2(0.0, RETICLE_OUTER)],
	]
	# Primero el borde oscuro (algo más ancho y largo) y encima el color.
	for pass_index in 2:
		var dark: bool = pass_index == 0
		var line_color: Color = RETICLE_EDGE if dark else color
		var width: float = RETICLE_WIDTH + (RETICLE_EDGE_EXTRA if dark else 0.0)
		var grow: float = RETICLE_EDGE_EXTRA * 0.5 if dark else 0.0
		for arm: Array in arms:
			var from: Vector2 = arm[0]
			var to: Vector2 = arm[1]
			var along: Vector2 = (to - from).normalized()
			draw_line(aim + from - along * grow, aim + to + along * grow, line_color, width, true)
		if locked:
			var half: float = RETICLE_FRAME
			var corner: float = RETICLE_FRAME * 0.4
			for sx in [-1.0, 1.0]:
				for sy in [-1.0, 1.0]:
					var c := aim + Vector2(sx * (half + grow), sy * (half + grow))
					draw_line(c, c - Vector2(sx * (corner + grow * 2.0), 0.0), line_color, width, true)
					draw_line(c, c - Vector2(0.0, sy * (corner + grow * 2.0)), line_color, width, true)
		if pointer != Vector2.ZERO:
			var tip: Vector2 = aim + pointer * (RETICLE_OUTER + 14.0 + grow)
			var side := Vector2(-pointer.y, pointer.x)
			var base: Vector2 = tip - pointer * (18.0 + grow)
			draw_colored_polygon(PackedVector2Array([tip, base + side * (11.0 + grow), base - side * (11.0 + grow)]), line_color)


func _draw_tank_icon(origin: Vector2, green: Color) -> void:
	draw_string(ThemeDB.fallback_font, origin + Vector2(-6.0, -46.0), "N", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color(green, 0.6))
	draw_line(origin + Vector2(0.0, -40.0), origin + Vector2(0.0, -34.0), Color(green, 0.6), 2.0)
	# Casco: rumbo del tanque (yaw 0 = mira al norte, hacia -Z).
	var hull_yaw: float = -tank.global_rotation.y
	draw_set_transform(origin, hull_yaw, Vector2.ONE)
	draw_rect(Rect2(-14.0, -20.0, 28.0, 40.0), Color(green, 0.15), true)
	draw_rect(Rect2(-14.0, -20.0, 28.0, 40.0), green, false, 2.0)
	for side in [-1.0, 1.0]:
		draw_rect(Rect2(side * 17.0 - 3.0, -22.0, 6.0, 44.0), Color(green, 0.7), false, 1.5)
	draw_line(Vector2(-6.0, -20.0), Vector2(0.0, -26.0), green, 2.0)
	draw_line(Vector2(6.0, -20.0), Vector2(0.0, -26.0), green, 2.0)
	# Torreta y cañón: rumbo real de la torreta en el mundo.
	var turret_yaw: float = -tank.turret_controller.world_yaw
	draw_set_transform(origin, turret_yaw, Vector2.ONE)
	draw_circle(Vector2.ZERO, 9.0, Color(0.0, 0.0, 0.0, 0.8))
	draw_arc(Vector2.ZERO, 9.0, 0.0, TAU, 16, VectorMaterials.ORANGE, 2.0)
	draw_line(Vector2.ZERO, Vector2(0.0, -34.0), VectorMaterials.ORANGE, 4.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## En las vistas exteriores la retícula marca dónde caerá el disparo (proyectado en pantalla).
func _aim_screen_point(center: Vector2) -> Vector2:
	if tank == null or GameSettings.camera_view == 0 or tank.camera == null:
		return center
	var from: Vector3 = tank.muzzle.global_position
	var to: Vector3 = from - tank.muzzle.global_transform.basis.z * 250.0
	var query := PhysicsRayQueryParameters3D.create(from, to, 1 | Terrain.LAYER)
	var hit: Dictionary = tank.get_world_3d().direct_space_state.intersect_ray(query)
	var point: Vector3 = hit["position"] if not hit.is_empty() else to
	if tank.camera.is_position_behind(point):
		return center
	return tank.camera.unproject_position(point)


## Barra de vida grande, con número y aviso cuando queda poco.
func _draw_armor(center: Vector2) -> void:
	var font: Font = ThemeDB.fallback_font
	var armor: float = tank.health.fraction()
	var color: Color = Color(0.25, 0.95, 0.35)
	if armor < 0.6:
		color = Color(1.0, 0.8, 0.2)
	if armor < 0.3:
		color = Color(1.0, 0.2, 0.15)
		if fmod(Time.get_ticks_msec() / 1000.0, 0.6) < 0.3:
			color = color.lightened(0.4)
	var bar := Rect2(Vector2(center.x - 230.0, size.y - 64.0), Vector2(460.0, 26.0))
	draw_rect(Rect2(bar.position - Vector2(4.0, 4.0), bar.size + Vector2(8.0, 8.0)), Color(0.0, 0.0, 0.0, 0.55), true)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * armor, bar.size.y)), color, true)
	draw_rect(bar, Color.WHITE, false, 2.0)
	for i in range(1, 10):
		var x: float = bar.position.x + bar.size.x * i / 10.0
		draw_line(Vector2(x, bar.position.y), Vector2(x, bar.position.y + 6.0), Color(1.0, 1.0, 1.0, 0.4), 1.0)
	var text: String = Loc.t("BLINDAJE %d / %d") % [roundi(tank.health.current), roundi(tank.health.max_health)]
	draw_string(font, Vector2(bar.position.x, bar.position.y + 20.0), text, HORIZONTAL_ALIGNMENT_CENTER, bar.size.x, 20, Color.BLACK)
	# Mejoras activas encima de la barra.
	var buff_names: Dictionary = {"reload": Loc.t("RECARGA RÁPIDA"), "damage": Loc.t("CAÑÓN PESADO"), "shield": Loc.t("BLINDAJE EXTRA")}
	var x0: float = bar.position.x
	for kind in tank.buffs:
		var label: String = "%s %d s" % [buff_names.get(kind, kind), ceili(tank.buffs[kind])]
		draw_string(font, Vector2(x0, bar.position.y - 12.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, Color(0.5, 0.9, 1.0))
		x0 += font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18).x + 24.0


## Captura la bandera: capturas de cada bando y quién tiene cada bandera, bajo el texto de estado.
func _draw_flag_board() -> void:
	var board: Dictionary = director.flag_board()
	if board.is_empty():
		return
	var font: Font = ThemeDB.fallback_font
	var origin := Vector2(18.0, 82.0)
	var rows: Array = board["flags"]
	draw_rect(Rect2(origin, Vector2(430.0, 34.0 + rows.size() * 34.0)), Color(0.0, 0.0, 0.0, 0.5), true)
	draw_string(font, origin + Vector2(10.0, 24.0), Loc.t("CAPTURAS"), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 17, Color(1.0, 0.85, 0.1))
	draw_string(font, origin + Vector2(110.0, 26.0), board["score"], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 24, Color.WHITE)
	var blink: bool = fmod(Time.get_ticks_msec() / 1000.0, 0.7) < 0.45
	for i in rows.size():
		var row: Dictionary = rows[i]
		var at: Vector2 = origin + Vector2(12.0, 40.0 + i * 34.0)
		var color: Color = row["color"]
		# Iconito de bandera: mástil y paño del color del bando; parpadea si no está en su base.
		if not row["alert"] or blink:
			draw_line(at, at + Vector2(0.0, 26.0), Color(0.85, 0.85, 0.85), 2.0)
			draw_colored_polygon(PackedVector2Array([at + Vector2(1.0, 1.0), at + Vector2(22.0, 7.0), at + Vector2(1.0, 14.0)]), color)
		draw_string(font, at + Vector2(32.0, 13.0), row["title"], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, color.lightened(0.3))
		draw_string(font, at + Vector2(32.0, 29.0), row["state"], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, Color(1.0, 0.9, 0.5) if row["alert"] else Color(0.9, 0.92, 0.9))


## Lista de objetivos de la misión, bajo el texto de estado.
func _draw_objectives() -> void:
	var lines: Array[String] = director.objective_lines()
	if lines.is_empty():
		return
	var font: Font = ThemeDB.fallback_font
	var y: float = 100.0
	draw_rect(Rect2(Vector2(18.0, y - 22.0), Vector2(330.0, 26.0 + lines.size() * 24.0)), Color(0.0, 0.0, 0.0, 0.45), true)
	draw_string(font, Vector2(26.0, y), Loc.t("OBJETIVOS"), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, Color(1.0, 0.85, 0.1))
	for line in lines:
		y += 24.0
		var done: bool = line.begins_with("✔")
		draw_string(font, Vector2(26.0, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 17, Color(0.5, 0.9, 0.5) if done else Color(1.0, 1.0, 1.0))


## Aviso grande si el jugador está dentro de una zona de bombardeo enemigo.
func _draw_raid_warning(center: Vector2) -> void:
	for node in get_tree().get_nodes_in_group(&"air_strikes"):
		var strike := node as AirStrike
		if strike == null or not strike.hostile_to_player or strike.time_left() <= 0.0:
			continue
		if not strike.contains(tank.global_position):
			continue
		var font: Font = ThemeDB.fallback_font
		var text: String = Loc.t("¡BOMBARDEO! SAL DE LA ZONA  %d") % ceili(strike.time_left())
		var pulse: float = 0.6 + 0.4 * sin(Time.get_ticks_msec() / 80.0)
		draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 0.0, 0.0, 0.12 * pulse), true)
		draw_string(font, Vector2(0.0, center.y - 120.0), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 40, Color(1.0, 0.25, 0.2, pulse))
		return
