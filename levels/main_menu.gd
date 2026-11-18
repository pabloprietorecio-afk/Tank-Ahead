extends Control
## Menú principal: modo de juego → bando → frente → (misión) → combate.

const GOLD := Color(0.96, 0.82, 0.5)
const AMBER := Color(1.0, 0.75, 0.35)
const GREEN := GOLD

## Color de cada categoría del menú principal.
const TINT_PLAY := Color(0.45, 0.72, 0.38)
const TINT_TUTORIAL := Color(0.36, 0.64, 0.95)
const TINT_OPTIONS := Color(0.72, 0.6, 0.9)
const TINT_HISTORY := Color(0.92, 0.55, 0.32)
## «◀ VOLVER»: color arena, distinto de todas las categorías, para que se vea a la primera.
const TINT_BACK := Color(0.86, 0.78, 0.56)

## Alto de fila normal y mínimo al que se encoge una página que no cabe en la pantalla.
const ROW_HEIGHT: float = 68.0
const ROW_MIN: float = 54.0
const ROW_GAP: int = 10
## Hueco que debe quedar bajo la última fila.
const BOTTOM_MARGIN: float = 12.0

## Alto de pantalla con el que se ajustan las páginas (0 = el de verdad; lo fijan las pruebas).
var fit_height: float = 0.0

var _content: VBoxContainer
## Bandera de idioma (arriba a la derecha) y su lista de idiomas.
var _flag: FlagButton
var _flag_list: PanelContainer
var _flag_rows: Dictionary = {}
var _on_options: bool = false
var _showing_premium: bool = false
## Anuncio recompensado en curso / terminado sin premio (pantalla premium).
var _reward_busy: bool = false
var _reward_failed: bool = false
var _center: MarginContainer
var _title: Label
var _subtitle: Label
var _era: Label
var _version: Label
## Estado de los anuncios (oculto): se enseña con TITLE_TAPS toques seguidos en el título.
const TITLE_TAPS: int = 5
const TITLE_TAP_GAP_MS: int = 1200
var _title_taps: int = 0
var _title_tap_ms: int = 0
var _ads_overlay: Label
var _radio: AudioStreamPlayer
var _radio_timer: Timer
## Partes de radio por bando: [aliados, alemanes].
var _bulletins: Array = []
var _radio_side: int = 0
## Grabaciones de época por bando (ver assets/audio/CREDITS.md). Aliados: Churchill,
## Eisenhower, Roosevelt, Chamberlain, la BBC y Levitán. Alemanes: cuatro partes militares
## (locutados para el juego) y cuatro extractos de discursos de Hitler.
const ALLIED_CLIPS: int = 9
const GERMAN_CLIPS: int = 8
## Volumen de la radio de fondo por bando: unos 7 dB por debajo de la música.
const RADIO_DB: Array[float] = [-4.0, -4.0]


func _ready() -> void:
	GameSettings.ensure_loaded()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if OS.is_debug_build() and OS.get_name() == "Android":
		_toggle_ads_overlay.call_deferred()
	# Portada en 3D detrás del menú y un velo oscuro para que se lea el texto.
	add_child(CoverDiorama.new())
	var veil := ColorRect.new()
	veil.color = Color(0.0, 0.0, 0.0, 0.45)
	veil.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	veil.offset_right = 720.0
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var center := MarginContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_theme_constant_override("margin_left", 50)
	center.add_theme_constant_override("margin_top", 14)
	scroll.add_child(center)
	_center = center
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.add_theme_constant_override("separation", 8)
	center.add_child(column)
	_title = _label("A TANK STORY", 72, GOLD)
	_title.add_theme_color_override("font_outline_color", Color(0.12, 0.08, 0.04))
	_title.add_theme_constant_override("outline_size", 14)
	_title.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.7))
	_title.add_theme_constant_override("shadow_offset_x", 4)
	_title.add_theme_constant_override("shadow_offset_y", 5)
	# Cinco toques seguidos en el título enseñan (o quitan) el estado de los anuncios: sirve para
	# ver, también en la versión de Google Play, por qué no sale publicidad.
	_title.mouse_filter = Control.MOUSE_FILTER_PASS
	_title.gui_input.connect(_on_title_input)
	column.add_child(_title)
	_era = _label("", 22, Color(0.9, 0.88, 0.8))
	_era.add_theme_color_override("font_outline_color", Color.BLACK)
	_era.add_theme_constant_override("outline_size", 6)
	column.add_child(_era)
	_subtitle = _label("", 26, AMBER)
	column.add_child(_subtitle)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", ROW_GAP)
	column.add_child(_content)
	_version = _label("", 16, Color(0.5, 0.6, 0.5))
	column.add_child(_version)
	_retranslate()
	_build_flag()
	_start_audio()
	PremiumStore.changed.connect(_on_store_changed)
	Ads.changed.connect(_on_store_changed)
	Ads.rewarded_result.connect(_on_rewarded_result)
	var page: String = GameSession.menu_page
	GameSession.menu_page = ""
	if page == "story":
		# Viene del final del tutorial: directo a la campaña (falta elegir bando y frente).
		_choose_mode(GameSession.Mode.STORY)
	elif page == "premium":
		# Viene del final de una misión cuya siguiente exige premium.
		_page_premium()
	elif page == "briefing":
		# Viene del final de una misión: repetirla (con otro tanque, si es premium).
		_page_briefing(GameSession.mission_index)
	elif not GameSession.tutorial_offered():
		_page_tutorial_offer()
	else:
		_page_mode()


## Música del menú y, de fondo y sin parar, la radio: partes aliados y alemanes intercalados,
## bajitos, como una emisora que alguien se ha dejado encendida.
func _start_audio() -> void:
	AudioSetup.ensure()
	add_child(AudioSetup.music_player("res://assets/music/menu_theme.ogg"))
	for side in [["al", ALLIED_CLIPS], ["de", GERMAN_CLIPS]]:
		var list: Array[String] = []
		for i in side[1]:
			list.append("res://assets/radio/radio_%s_%d.ogg" % [side[0], i])
		list.shuffle()
		_bulletins.append(list)
	_radio = AudioStreamPlayer.new()
	# Va por el bus de la música: es ambiente, no una orden, y así no hace bajar la música.
	_radio.bus = AudioSetup.MUSIC
	add_child(_radio)
	_radio_timer = Timer.new()
	_radio_timer.one_shot = true
	_radio_timer.timeout.connect(_play_bulletin)
	add_child(_radio_timer)
	_radio.finished.connect(func() -> void: _radio_timer.start(randf_range(1.5, 3.5)))
	_radio_timer.start(2.5)


## Siguiente parte: alterna bando (aliados, alemanes, aliados...) y no repite hasta agotarlos.
func _play_bulletin() -> void:
	var list: Array = _bulletins[_radio_side]
	_radio.volume_db = RADIO_DB[_radio_side]
	_radio_side = 1 - _radio_side
	var path: String = list.pop_front()
	list.append(path)
	_radio.stream = load(path)
	_radio.play()


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	label.add_theme_constant_override("outline_size", 6)
	return label


func _clear(subtitle: String) -> void:
	_subtitle.text = subtitle
	_on_options = false
	_showing_premium = false
	if not _reward_busy:
		_reward_failed = false
	if _flag_list != null:
		_flag_list.visible = false
	for child in _content.get_children():
		# Oculta deja de contar para el tamaño de la página ya, aunque se borre al acabar el fotograma.
		(child as Control).visible = false
		child.queue_free()
	_content.add_theme_constant_override("separation", ROW_GAP)
	# Cuando termine de montarse la página nueva (en este mismo fotograma), se ajusta.
	_fit.call_deferred()


## Alto que necesita la página que se está mostrando (título, filas y márgenes).
func needed_height() -> float:
	return _center.get_combined_minimum_size().y + BOTTOM_MARGIN


## Ajusta la página recién montada para que quepa entera en la pantalla sin desplazarla: si no
## cabe, junta las filas y las hace más bajas, lo justo y hasta un mínimo cómodo para el dedo.
## Las listas largas (las misiones de una campaña) siguen pudiendo desplazarse.
func _fit() -> void:
	var screen: float = fit_height if fit_height > 0.0 else size.y
	var over: float = needed_height() - screen
	if over <= 0.0:
		return
	# Cada fila es un botón o varios puestos en horizontal (que se encogen a la vez).
	var rows: Array[Array] = []
	var shown: int = 0
	for child in _content.get_children():
		if not (child as Control).visible:
			continue
		shown += 1
		if child is Button:
			rows.append([child])
		elif child is HBoxContainer:
			var group: Array = child.get_children().filter(func(item: Node) -> bool: return item is Button)
			if not group.is_empty():
				rows.append(group)
	var gap: int = ROW_GAP
	while gap > 5 and over > 0.0:
		gap -= 1
		over -= maxi(shown - 1, 0)
	_content.add_theme_constant_override("separation", gap)
	# Se reparte el recorte entre las filas que aún pueden encogerse (varias pasadas: las que
	# llegan al mínimo dejan su parte a las demás).
	for step in 4:
		var loose: Array[Array] = rows.filter(func(row: Array) -> bool: return _row_height(row) > ROW_MIN)
		if over <= 0.0 or loose.is_empty():
			break
		var cut: float = ceilf(over / loose.size())
		for row in loose:
			var before: float = _row_height(row)
			var height: float = maxf(before - cut, ROW_MIN)
			over -= before - height
			for button: Button in row:
				button.custom_minimum_size.y = minf(button.custom_minimum_size.y, height)
				if height < 62.0 and button.get_theme_font_size("font_size") > 24:
					button.add_theme_font_size_override("font_size", 24)


## Alto de una fila de botones (el del más alto).
func _row_height(row: Array) -> float:
	var height: float = 0.0
	for button: Button in row:
		height = maxf(height, button.custom_minimum_size.y)
	return height


## Fila de la categoría `tint`: fondo y borde izquierdo del color, y letra clara del mismo tono.
func _tint_button(button: Button, tint: Color) -> void:
	var states := {"normal": 0.22, "hover": 0.34, "pressed": 0.45, "focus": 0.22, "disabled": 0.12}
	for state in states:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(tint.r * 0.5, tint.g * 0.5, tint.b * 0.5, 0.35 + float(states[state]))
		box.border_color = tint
		box.border_width_left = 10
		box.set_corner_radius_all(3)
		box.content_margin_left = 16.0
		box.content_margin_right = 16.0
		button.add_theme_stylebox_override(state, box)
	var text_color: Color = tint.lerp(Color.WHITE, 0.55)
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(color_name, text_color)


## Separación entre grupos de categorías.
func _group_gap() -> void:
	var gap := Control.new()
	gap.custom_minimum_size.y = 6.0
	_content.add_child(gap)


func _button(text: String, action: Callable, enabled: bool = true, tint: Color = Color(0.0, 0.0, 0.0, 0.0)) -> Button:
	var button := Button.new()
	button.text = text
	if tint.a > 0.0:
		_tint_button(button, tint)
	button.custom_minimum_size = Vector2(620.0, ROW_HEIGHT)
	button.add_theme_font_size_override("font_size", 28)
	button.disabled = not enabled
	button.modulate = Color(1.0, 1.0, 1.0, 0.92)
	button.pressed.connect(action)
	_content.add_child(button)
	return button


func _back(action: Callable) -> void:
	var button := _button(Loc.t("◀ VOLVER"), action, true, TINT_BACK)
	button.add_theme_font_size_override("font_size", 22)
	button.custom_minimum_size.y = 56.0


## Fila de controles en horizontal dentro de la página.
func _row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", ROW_GAP)
	_content.add_child(row)
	return row


## Pie de página: «volver» estrecho a la izquierda y la acción principal ocupando el resto.
func _footer(back_action: Callable, text: String, action: Callable) -> void:
	var footer := _row()
	var back: Button = _button(Loc.t("◀ VOLVER"), back_action, true, TINT_BACK)
	back.reparent(footer)
	back.add_theme_font_size_override("font_size", 22)
	back.custom_minimum_size = Vector2(210.0, ROW_HEIGHT)
	var main: Button = _button(text, action, true, TINT_PLAY)
	main.reparent(footer)
	main.custom_minimum_size = Vector2(400.0, ROW_HEIGHT)
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL


## Desplegable del clima de la partida: «aleatorio» o uno de los del frente. Lo elegido se guarda
## y vale también para las partidas siguientes, mientras ese clima exista en su frente.
func _weather_picker(front: int) -> OptionButton:
	GameSettings.ensure_loaded()
	var kinds: Array[int] = Fronts.weather_choices(front)
	var names: Array = [Loc.t("ALEATORIO")]
	for kind in kinds:
		names.append(Weather.name_of(kind, front))
	var picker: OptionButton = UiKit.dropdown(names, kinds.find(GameSettings.weather) + 1, func(index: int) -> void:
		GameSettings.weather = -1 if index == 0 else kinds[index - 1]
		GameSettings.save(), 26, Loc.t("CLIMA: %s"))
	picker.custom_minimum_size = Vector2(370.0, ROW_HEIGHT)
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return picker


## Tanque con el que repetir una misión ya superada: los del bando en ese frente (premium). Sin
## premium es un botón que lleva a la pantalla premium; si la misión aún no se ha superado no
## hay nada que elegir (devuelve null). `note` muestra los datos del tanque elegido.
func _tank_picker(index: int, note: Label) -> Control:
	if not GameSession.mission_completed(index):
		return null
	if not Premium.is_premium():
		var locked := Button.new()
		locked.text = Loc.t("★ OTRO TANQUE (PREMIUM)")
		locked.add_theme_font_size_override("font_size", 24)
		locked.custom_minimum_size = Vector2(370.0, ROW_HEIGHT)
		locked.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		locked.modulate = Color(1.0, 1.0, 1.0, 0.92)
		locked.pressed.connect(_page_premium.bind(index))
		return locked
	var front: int = GameSession.front_choice
	var faction: int = GameSession.faction
	var ids: Array = Fronts.ROSTERS[front][faction]
	var standard: String = Fronts.PLAYER_TANK[front][faction]
	var names: Array = []
	for id: String in ids:
		names.append(Fronts.tank(id).display_name)
	var describe: Callable = func(id: String) -> void:
		var stats: TankStats = Fronts.player_stats(front, faction, id)
		note.text = Loc.t("BLINDAJE %d   ATAQUE %d   VELOCIDAD %d km/h") % [roundi(stats.max_armor), roundi(stats.damage), roundi(stats.max_speed * 3.6)]
	var current: String = GameSession.tank_choice if GameSession.tank_choice in ids else standard
	describe.call(current)
	var picker: OptionButton = UiKit.dropdown(names, ids.find(current), func(choice: int) -> void:
		GameSession.tank_choice = "" if ids[choice] == standard else ids[choice]
		describe.call(ids[choice]), 26, Loc.t("TANQUE: %s"))
	picker.custom_minimum_size = Vector2(370.0, ROW_HEIGHT)
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return picker


func _page_mode() -> void:
	_clear(Loc.t("ELIGE MODO DE JUEGO"))
	# Jugables, tutorial, opciones y fichas históricas: cada grupo con su color.
	_button(Loc.t("HISTORIA — campañas con misiones"), func() -> void: _choose_mode(GameSession.Mode.STORY), true, TINT_PLAY)
	_button(Loc.t("CAPTURA LA BANDERA — 4 contra 4"), func() -> void: _choose_mode(GameSession.Mode.CTF), true, TINT_PLAY)
	var best: int = GameSession.best_wave()
	_button(Loc.t("SUPERVIVENCIA — oleadas sin fin%s") % (Loc.t("  (récord: oleada %d)") % best if best > 0 else ""), func() -> void: _choose_mode(GameSession.Mode.SURVIVAL), true, TINT_PLAY)
	_group_gap()
	_button(Loc.t("%sTUTORIAL — aprende a manejar el tanque") % ("✔ " if GameSession.tutorial_completed() else ""), _play_tutorial, true, TINT_TUTORIAL)
	_group_gap()
	_button(Loc.t("OPCIONES — dificultad, sonido y ayudas"), _page_audio, true, TINT_OPTIONS)
	_group_gap()
	_button(Loc.t("VEHÍCULOS — fichas históricas"), _page_vehicles, true, TINT_HISTORY)


## Primera vez que se abre el juego: se ofrece el tutorial (solo una vez).
func _page_tutorial_offer() -> void:
	_clear(Loc.t("¿QUIERES APRENDER A MANEJAR EL TANQUE?"))
	_button(Loc.t("SÍ — tutorial de prácticas"), func() -> void:
		GameSession.mark_tutorial("offered")
		_play_tutorial())
	_button(Loc.t("AHORA NO"), func() -> void:
		GameSession.mark_tutorial("offered")
		_page_mode())
	_content.add_child(_label(Loc.t("Podrás hacerlo cuando quieras desde el menú: TUTORIAL"), 20, Color(0.85, 0.9, 0.85)))


## El tutorial se juega siempre con el Sherman en Normandía.
func _play_tutorial() -> void:
	GameSession.mode = GameSession.Mode.TUTORIAL
	GameSession.faction = Fronts.Faction.ALLIES
	GameSession.front_choice = Fronts.Id.NORMANDY
	_play()


## Bandera vieja arriba a la derecha: al tocarla se despliega la lista de idiomas.
func _build_flag() -> void:
	_flag = FlagButton.create(GameSettings.language, true)
	_flag.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_flag.offset_right = -16.0
	_flag.offset_left = -16.0 - _flag.custom_minimum_size.x
	_flag.offset_top = 14.0
	_flag.offset_bottom = 14.0 + _flag.custom_minimum_size.y
	_flag.pressed.connect(func() -> void: _flag_list.visible = not _flag_list.visible)
	add_child(_flag)
	_flag_list = PanelContainer.new()
	_flag_list.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.08, 0.05, 0.88)
	style.border_color = Color(0.55, 0.42, 0.2)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8.0)
	_flag_list.add_theme_stylebox_override("panel", style)
	var column := GridContainer.new()
	column.columns = 2
	column.add_theme_constant_override("h_separation", 6)
	column.add_theme_constant_override("v_separation", 2)
	_flag_list.add_child(column)
	for code: String in Loc.LANGUAGES:
		var row := Button.new()
		row.flat = true
		row.focus_mode = Control.FOCUS_NONE
		row.custom_minimum_size = Vector2(250.0, 76.0)
		var box := HBoxContainer.new()
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_theme_constant_override("separation", 6)
		box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		row.add_child(box)
		var icon := FlagButton.create(code, false)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.scale = Vector2(0.78, 0.78)
		icon.custom_minimum_size *= 0.78
		box.add_child(icon)
		var name_label := _label(Loc.LANGUAGE_NAMES[code], 24, Color(0.92, 0.88, 0.76))
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		box.add_child(name_label)
		row.pressed.connect(_pick_language.bind(code))
		column.add_child(row)
		_flag_rows[code] = icon
	add_child(_flag_list)
	# Tamaño fijo: 2 columnas de filas de 250 x 76 (+ separaciones y el margen del panel).
	var list_width: float = 2.0 * 250.0 + 6.0 + 16.0
	var list_height: float = ceilf(Loc.LANGUAGES.size() / 2.0) * 76.0 + (ceilf(Loc.LANGUAGES.size() / 2.0) - 1.0) * 2.0 + 16.0
	_flag_list.anchor_left = 1.0
	_flag_list.anchor_right = 1.0
	_flag_list.anchor_top = 0.0
	_flag_list.anchor_bottom = 0.0
	_flag_list.offset_right = -16.0
	_flag_list.offset_left = -16.0 - list_width
	_flag_list.offset_top = 112.0
	_flag_list.offset_bottom = 112.0 + list_height
	_refresh_flags()


func _refresh_flags() -> void:
	for code: String in _flag_rows:
		(_flag_rows[code] as FlagButton).current = code == GameSettings.language


## Cambia de idioma desde la bandera: si se estaba en Opciones se vuelve a pintar esa página y,
## si no, se vuelve a la primera (sus textos, ya traducidos, la dejan lista).
func _pick_language(code: String) -> void:
	_flag_list.visible = false
	if code == GameSettings.language:
		return
	GameSettings.set_language(code)
	_flag.set_code(code)
	_refresh_flags()
	_retranslate()
	if _on_options:
		_page_audio()
	else:
		_page_mode()


## Vuelve a poner los textos fijos de la portada en el idioma activo.
func _retranslate() -> void:
	_era.text = Loc.t("SEGUNDA GUERRA MUNDIAL  ·  1941 — 1945")
	_version.text = Loc.t("versión %s") % str(ProjectSettings.get_setting("application/config/version", "dev"))


func _page_audio() -> void:
	_clear(Loc.t("OPCIONES"))
	_on_options = true
	GameSettings.ensure_loaded()
	var difficulty: Button = _button("", func() -> void: pass)
	var refresh: Callable = func() -> void:
		difficulty.text = Loc.t("DIFICULTAD: %s\n%s") % [Loc.t(GameSettings.DIFFICULTY_NAMES[GameSettings.difficulty]), Loc.t(GameSettings.DIFFICULTY_HINTS[GameSettings.difficulty])]
	difficulty.custom_minimum_size.y = 96.0
	difficulty.pressed.connect(func() -> void:
		GameSettings.difficulty = (GameSettings.difficulty + 1) % 4
		GameSettings.save()
		refresh.call())
	refresh.call()
	var effects: Button = _button("", func() -> void: pass)
	var refresh_effects: Callable = func() -> void:
		effects.text = Loc.t("EFECTOS GRÁFICOS: %s") % Loc.t(GameSettings.EFFECTS_NAMES[GameSettings.effects])
	effects.pressed.connect(func() -> void:
		# ALTOS → MEDIOS → BAJOS → ALTOS.
		GameSettings.effects = (GameSettings.effects + 2) % 3
		GameSettings.save()
		Fx.quality = GameSettings.effects
		Fx.on(self).set_level(GameSettings.effects)
		refresh_effects.call())
	refresh_effects.call()
	_content.add_child(UiKit.toggle(Loc.t("Destacar enemigos (borde amarillo)"), GameSettings.highlight_enemies, func(on: bool) -> void:
		GameSettings.highlight_enemies = on
		GameSettings.save(), 26))
	_content.add_child(UiKit.toggle(Loc.t("Destacar objetivos (borde azul)"), GameSettings.highlight_objectives, func(on: bool) -> void:
		GameSettings.highlight_objectives = on
		GameSettings.save(), 26))
	_content.add_child(VolumeSliders.create(2, 24, Vector2(180.0, 46.0)))
	if Ads.privacy_options_available():
		_button(Loc.t("PRIVACIDAD DE LOS ANUNCIOS"), Ads.show_privacy_options)
	# Pie: idioma y volver en la misma fila (así la página cabe en pantallas bajas). El idioma se
	# rotula en los dos idiomas para encontrarlo aunque se haya cambiado sin querer.
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", ROW_GAP)
	_content.add_child(footer)
	var language: Button = _button("IDIOMA / LANGUAGE: %s" % Loc.LANGUAGE_NAMES[GameSettings.language], func() -> void:
		var next: int = (Loc.LANGUAGES.find(GameSettings.language) + 1) % Loc.LANGUAGES.size()
		GameSettings.set_language(Loc.LANGUAGES[next])
		_flag.set_code(GameSettings.language)
		_refresh_flags()
		_retranslate()
		_page_audio())
	language.reparent(footer)
	language.add_theme_font_size_override("font_size", 22)
	language.custom_minimum_size = Vector2(400.0, 56.0)
	var back: Button = _button(Loc.t("◀ VOLVER"), _page_mode, true, TINT_BACK)
	back.reparent(footer)
	back.add_theme_font_size_override("font_size", 22)
	back.custom_minimum_size = Vector2(210.0, 56.0)


## Fichas históricas de todos los vehículos del juego.
func _page_vehicles() -> void:
	_clear(Loc.t("VEHÍCULOS DEL JUEGO"))
	var gallery := VehicleGallery.new()
	gallery.compact()
	gallery.closed.connect(_page_mode)
	_content.add_child(gallery)
	gallery.show_index(0)


func _choose_mode(mode: int) -> void:
	GameSession.mode = mode
	_page_faction()


func _page_faction() -> void:
	_clear(Loc.t("%s — ELIGE BANDO") % Loc.t(GameSession.MODE_NAMES[GameSession.mode]))
	_button(Loc.t("ALIADOS — Estados Unidos, Reino Unido y Unión Soviética"), func() -> void: _choose_faction(Fronts.Faction.ALLIES))
	_button(Loc.t("ALEMANIA — Wehrmacht"), func() -> void: _choose_faction(Fronts.Faction.AXIS))
	_back(_page_mode)


func _choose_faction(faction: int) -> void:
	GameSession.faction = faction
	_page_front()


func _page_front() -> void:
	_clear(Loc.t("%s — %s — ELIGE FRENTE") % [Loc.t(GameSession.MODE_NAMES[GameSession.mode]), Loc.t(Fronts.FACTION_NAMES[GameSession.faction])])
	for front in [Fronts.Id.NORMANDY, Fronts.Id.AFRICA, Fronts.Id.KURSK]:
		var tank_name: String = Fronts.tank(Fronts.PLAYER_TANK[front][GameSession.faction]).display_name
		_button(Loc.t("%s  ·  tu tanque: %s") % [Loc.t(Fronts.NAMES[front]), tank_name], _choose_front.bind(front))
	_back(_page_faction)


func _choose_front(front: int) -> void:
	GameSession.front_choice = front
	if GameSession.mode == GameSession.Mode.STORY:
		_page_missions()
	else:
		_page_start()


## Supervivencia y captura la bandera: última pantalla antes del combate, con el clima.
func _page_start() -> void:
	var front: int = GameSession.front_choice
	_clear("%s — %s" % [Loc.t(GameSession.MODE_NAMES[GameSession.mode]), Loc.t(Fronts.NAMES[front])])
	var tank_name: String = Fronts.tank(Fronts.PLAYER_TANK[front][GameSession.faction]).display_name
	_content.add_child(_label(Loc.t("%s  ·  tu tanque: %s") % [Loc.t(Fronts.FACTION_NAMES[GameSession.faction]), tank_name], 24, Color(0.85, 0.9, 0.85)))
	var picker: OptionButton = _weather_picker(front)
	picker.custom_minimum_size.x = 620.0
	_content.add_child(picker)
	_footer(_page_front, Loc.t("▶ COMENZAR"), _play)


func _page_missions() -> void:
	_clear(Loc.t("CAMPAÑA — %s — %s") % [Loc.t(Fronts.FACTION_NAMES[GameSession.faction]), Loc.t(Fronts.NAMES[GameSession.front_choice])])
	var done: int = GameSession.completed_missions()
	var list: Array[Dictionary] = GameSession.missions()
	for i in list.size():
		var mission: Dictionary = list[i]
		var premium_locked: bool = GameSession.mission_locked(i)
		var unlocked: bool = i <= done
		var mark: String = "✔ " if i < done else ("" if unlocked else "🔒 ")
		if premium_locked:
			mark = "★ "
		var title: String = "%s%d. %s  ·  %s" % [mark, i + 1, Loc.t(mission["title"]), Loc.t(Fronts.NAMES[mission["front"]])]
		# Las de premium se pueden tocar siempre: llevan a la pantalla que explica el nivel premium.
		_button(title, _page_premium.bind(i) if premium_locked else _page_briefing.bind(i), unlocked or premium_locked)
	_back(_page_front)


## Pantalla del nivel premium (se llega al tocar una misión de pago o al acabar la anterior).
func _page_premium(index: int = -1) -> void:
	if index >= 0:
		GameSession.mission_index = index
	if Premium.is_premium():
		# Ya es premium (compra confirmada o botón de pruebas): vuelve a la campaña.
		_page_missions()
		return
	_clear(Loc.t("NIVEL PREMIUM"))
	_showing_premium = true
	var text := _label(Loc.t("Las tres primeras misiones de cada frente son gratuitas. Hazte Premium para jugar el resto de la campaña, repetir las misiones superadas con cualquier otro tanque y quitar los anuncios."), 26, Color(0.85, 0.9, 0.85))
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(760.0, 0.0)
	_content.add_child(text)
	var buy_text: String = Loc.t("HAZTE PREMIUM")
	if PremiumStore.price != "":
		buy_text += "  ·  " + PremiumStore.price
	var idle: bool = PremiumStore.state == PremiumStore.State.READY
	_button(buy_text, PremiumStore.buy, idle and PremiumStore.can_buy(), TINT_PLAY)
	_button(Loc.t("RESTAURAR COMPRA"), PremiumStore.restore, idle)
	# Anuncio recompensado: abre esta misión una vez (solo la siguiente por jugar, no saltándose ninguna).
	var reward_note: String = ""
	# No se ofrece si se ha llegado aquí desde una misión gratuita (para cambiar de tanque).
	if GameSession.mission_index >= 0 and GameSession.mission_index <= GameSession.completed_missions() and Premium.mission_locked(GameSession.mission_index) and Ads.rewarded_offered():
		var ready_ad: bool = Ads.rewarded_ready() and not _reward_busy
		_button(Loc.t("VER UN ANUNCIO Y JUGAR ESTA MISIÓN"), _watch_ad, ready_ad)
		if _reward_busy:
			reward_note = Loc.t("Abriendo el anuncio…")
		elif not ready_ad:
			reward_note = Loc.t("Cargando el anuncio…")
	if _reward_failed:
		reward_note = Loc.t("No se ha completado el anuncio.")
	var note_text: String = reward_note
	if note_text == "":
		if not Premium.billing_available():
			note_text = Loc.t("Las compras no están disponibles en este dispositivo.")
		elif PremiumStore.message != "":
			note_text = Loc.t(PremiumStore.message)
		elif PremiumStore.state == PremiumStore.State.CONNECTING:
			note_text = Loc.t("Conectando con Google Play…")
	if note_text != "":
		var note := _label(note_text, 20, AMBER)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.custom_minimum_size = Vector2(760.0, 0.0)
		_content.add_child(note)
	if Premium.debug_toggle_available():
		_button("[PRUEBAS] Activar premium", func() -> void:
			Premium.set_premium(true)
			_page_missions())
	_back(_page_missions)


func _on_title_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	var now: int = Time.get_ticks_msec()
	if now - _title_tap_ms > TITLE_TAP_GAP_MS:
		_title_taps = 0
	_title_tap_ms = now
	_title_taps += 1
	if _title_taps >= TITLE_TAPS:
		_title_taps = 0
		_toggle_ads_overlay()


## Estado de los anuncios en una esquina del menú. Siempre a la vista en las compilaciones de
## depuración en Android; en las demás, con cinco toques seguidos en el título.
func _toggle_ads_overlay() -> void:
	if _ads_overlay != null:
		_ads_overlay.queue_free()
		_ads_overlay = null
		return
	var diag := Label.new()
	diag.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	diag.grow_vertical = Control.GROW_DIRECTION_BEGIN
	diag.offset_left = 6.0
	diag.offset_bottom = -4.0
	diag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	diag.add_theme_font_size_override("font_size", 13)
	diag.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	diag.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	diag.add_theme_constant_override("outline_size", 5)
	diag.text = Ads.debug_status()
	add_child(diag)
	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(func() -> void: diag.text = Ads.debug_status())
	diag.add_child(timer)
	_ads_overlay = diag


func _watch_ad() -> void:
	_reward_busy = true
	_reward_failed = false
	_page_premium()
	Ads.show_rewarded()


func _on_rewarded_result(granted: bool) -> void:
	_reward_busy = false
	if granted:
		_reward_failed = false
		GameSession.grant_reward_unlock(GameSession.mission_index)
		_page_briefing(GameSession.mission_index)
	else:
		_reward_failed = true
		if _showing_premium:
			_page_premium()


## Cambió algo en la compra (precio, aviso, estado o Premium): redibuja la pantalla si está abierta.
func _on_store_changed() -> void:
	if _showing_premium:
		_page_premium()


func _page_briefing(index: int) -> void:
	if GameSession.mission_locked(index):
		_page_premium(index)
		return
	GameSession.mission_index = index
	var mission: Dictionary = GameSession.current_mission()
	_clear(Loc.t("MISIÓN %d — %s") % [index + 1, Loc.t(mission["title"])])
	var text := _label(Loc.t(mission["briefing"]), 26, Color(0.85, 0.9, 0.85))
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(760.0, 0.0)
	_content.add_child(text)
	_content.add_child(_label(Loc.t("Frente: %s") % Loc.t(Fronts.NAMES[mission["front"]]), 22, AMBER))
	# El clima de la partida y, en las misiones ya superadas, el tanque con el que repetirla.
	var choices := _row()
	choices.add_child(_weather_picker(mission["front"]))
	var tank_note := _label("", 20, Color(0.85, 0.9, 0.85))
	var tank_picker: Control = _tank_picker(index, tank_note)
	if tank_picker != null:
		choices.add_child(tank_picker)
	if tank_note.text != "":
		_content.add_child(tank_note)
	else:
		tank_note.free()
	_footer(_page_missions, Loc.t("▶ COMENZAR"), _play)


func _play() -> void:
	get_tree().change_scene_to_file("res://levels/arena.tscn")
