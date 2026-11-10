extends Control
## Menú principal: modo de juego → bando → frente → (misión) → combate.

const GOLD := Color(0.96, 0.82, 0.5)
const AMBER := Color(1.0, 0.75, 0.35)
const GREEN := GOLD

## Alto de fila normal y mínimo al que se encoge una página que no cabe en la pantalla.
const ROW_HEIGHT: float = 68.0
const ROW_MIN: float = 54.0
const ROW_GAP: int = 10
## Hueco que debe quedar bajo la última fila.
const BOTTOM_MARGIN: float = 12.0

## Alto de pantalla con el que se ajustan las páginas (0 = el de verdad; lo fijan las pruebas).
var fit_height: float = 0.0

var _content: VBoxContainer
var _center: MarginContainer
var _title: Label
var _subtitle: Label
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
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	column.add_child(_title)
	var era := _label("SEGUNDA GUERRA MUNDIAL  ·  1941 — 1945", 22, Color(0.9, 0.88, 0.8))
	era.add_theme_color_override("font_outline_color", Color.BLACK)
	era.add_theme_constant_override("outline_size", 6)
	column.add_child(era)
	_subtitle = _label("", 26, AMBER)
	column.add_child(_subtitle)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", ROW_GAP)
	column.add_child(_content)
	var version := _label("versión %s" % str(ProjectSettings.get_setting("application/config/version", "dev")), 16, Color(0.5, 0.6, 0.5))
	column.add_child(version)
	_start_audio()
	var page: String = GameSession.menu_page
	GameSession.menu_page = ""
	if page == "story":
		# Viene del final del tutorial: directo a la campaña (falta elegir bando y frente).
		_choose_mode(GameSession.Mode.STORY)
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
	var rows: Array[Button] = []
	var shown: int = 0
	for child in _content.get_children():
		if not (child as Control).visible:
			continue
		shown += 1
		if child is Button:
			rows.append(child)
	var gap: int = ROW_GAP
	while gap > 5 and over > 0.0:
		gap -= 1
		over -= maxi(shown - 1, 0)
	_content.add_theme_constant_override("separation", gap)
	if over <= 0.0 or rows.is_empty():
		return
	var cut: float = ceilf(over / rows.size())
	for row in rows:
		var height: float = maxf(row.custom_minimum_size.y - cut, ROW_MIN)
		row.custom_minimum_size.y = height
		if height < 62.0 and row.get_theme_font_size("font_size") > 24:
			row.add_theme_font_size_override("font_size", 24)


func _button(text: String, action: Callable, enabled: bool = true) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(620.0, ROW_HEIGHT)
	button.add_theme_font_size_override("font_size", 28)
	button.disabled = not enabled
	button.modulate = Color(1.0, 1.0, 1.0, 0.92)
	button.pressed.connect(action)
	_content.add_child(button)
	return button


func _back(action: Callable) -> void:
	var button := _button("◀ VOLVER", action)
	button.add_theme_font_size_override("font_size", 22)
	button.custom_minimum_size.y = 56.0


func _page_mode() -> void:
	_clear("ELIGE MODO DE JUEGO")
	_button("%sTUTORIAL — aprende a manejar el tanque" % ("✔ " if GameSession.tutorial_completed() else ""), _play_tutorial)
	_button("HISTORIA — campañas con misiones", func() -> void: _choose_mode(GameSession.Mode.STORY))
	_button("CAPTURA LA BANDERA — 4 contra 4", func() -> void: _choose_mode(GameSession.Mode.CTF))
	_button("OPCIONES — dificultad, sonido y ayudas", _page_audio)
	_button("VEHÍCULOS — fichas históricas", _page_vehicles)
	var best: int = GameSession.best_wave()
	_button("SUPERVIVENCIA — oleadas sin fin%s" % ("  (récord: oleada %d)" % best if best > 0 else ""), func() -> void: _choose_mode(GameSession.Mode.SURVIVAL))


## Primera vez que se abre el juego: se ofrece el tutorial (solo una vez).
func _page_tutorial_offer() -> void:
	_clear("¿QUIERES APRENDER A MANEJAR EL TANQUE?")
	_button("SÍ — tutorial de prácticas", func() -> void:
		GameSession.mark_tutorial("offered")
		_play_tutorial())
	_button("AHORA NO", func() -> void:
		GameSession.mark_tutorial("offered")
		_page_mode())
	_content.add_child(_label("Podrás hacerlo cuando quieras desde el menú: TUTORIAL", 20, Color(0.85, 0.9, 0.85)))


## El tutorial se juega siempre con el Sherman en Normandía.
func _play_tutorial() -> void:
	GameSession.mode = GameSession.Mode.TUTORIAL
	GameSession.faction = Fronts.Faction.ALLIES
	GameSession.front_choice = Fronts.Id.NORMANDY
	_play()


func _page_audio() -> void:
	_clear("OPCIONES")
	GameSettings.ensure_loaded()
	var difficulty: Button = _button("", func() -> void: pass)
	var refresh: Callable = func() -> void:
		difficulty.text = "DIFICULTAD: %s\n%s" % [GameSettings.DIFFICULTY_NAMES[GameSettings.difficulty], GameSettings.DIFFICULTY_HINTS[GameSettings.difficulty]]
	difficulty.custom_minimum_size.y = 96.0
	difficulty.pressed.connect(func() -> void:
		GameSettings.difficulty = (GameSettings.difficulty + 1) % 4
		GameSettings.save()
		refresh.call())
	refresh.call()
	var highlight := CheckButton.new()
	highlight.text = "Destacar enemigos (borde azul)"
	highlight.button_pressed = GameSettings.highlight_enemies
	highlight.add_theme_font_size_override("font_size", 26)
	highlight.toggled.connect(func(on: bool) -> void:
		GameSettings.highlight_enemies = on
		GameSettings.save())
	_content.add_child(highlight)
	_content.add_child(VolumeSliders.create())
	_back(_page_mode)


## Fichas históricas de todos los vehículos del juego.
func _page_vehicles() -> void:
	_clear("VEHÍCULOS DEL JUEGO")
	var gallery := VehicleGallery.new()
	gallery.compact()
	gallery.closed.connect(_page_mode)
	_content.add_child(gallery)
	gallery.show_index(0)


func _choose_mode(mode: int) -> void:
	GameSession.mode = mode
	_page_faction()


func _page_faction() -> void:
	_clear("%s — ELIGE BANDO" % GameSession.MODE_NAMES[GameSession.mode])
	_button("ALIADOS — Estados Unidos, Reino Unido y Unión Soviética", func() -> void: _choose_faction(Fronts.Faction.ALLIES))
	_button("ALEMANIA — Wehrmacht", func() -> void: _choose_faction(Fronts.Faction.AXIS))
	_back(_page_mode)


func _choose_faction(faction: int) -> void:
	GameSession.faction = faction
	_page_front()


func _page_front() -> void:
	_clear("%s — %s — ELIGE FRENTE" % [GameSession.MODE_NAMES[GameSession.mode], Fronts.FACTION_NAMES[GameSession.faction]])
	for front in [Fronts.Id.NORMANDY, Fronts.Id.AFRICA, Fronts.Id.KURSK]:
		var tank_name: String = Fronts.tank(Fronts.PLAYER_TANK[front][GameSession.faction]).display_name
		_button("%s  ·  tu tanque: %s" % [Fronts.NAMES[front], tank_name], _choose_front.bind(front))
	_button("MEZCLA — todos los frentes", _choose_front.bind(GameSession.FRONT_MIXED))
	_back(_page_faction)


func _choose_front(front: int) -> void:
	GameSession.front_choice = front
	if GameSession.mode == GameSession.Mode.STORY:
		_page_missions()
	else:
		_play()


func _page_missions() -> void:
	_clear("CAMPAÑA — %s — %s" % [Fronts.FACTION_NAMES[GameSession.faction], "MEZCLA" if GameSession.front_choice == GameSession.FRONT_MIXED else Fronts.NAMES[GameSession.front_choice]])
	var done: int = GameSession.completed_missions()
	var list: Array[Dictionary] = GameSession.missions()
	for i in list.size():
		var mission: Dictionary = list[i]
		var unlocked: bool = i <= done
		var mark: String = "✔ " if i < done else ("" if unlocked else "🔒 ")
		_button("%s%d. %s  ·  %s" % [mark, i + 1, mission["title"], Fronts.NAMES[mission["front"]]], _page_briefing.bind(i), unlocked)
	_back(_page_front)


func _page_briefing(index: int) -> void:
	GameSession.mission_index = index
	var mission: Dictionary = GameSession.current_mission()
	_clear("MISIÓN %d — %s" % [index + 1, mission["title"]])
	var text := _label(mission["briefing"], 26, Color(0.85, 0.9, 0.85))
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(760.0, 0.0)
	_content.add_child(text)
	_content.add_child(_label("Frente: %s" % Fronts.NAMES[mission["front"]], 22, AMBER))
	_button("▶ COMENZAR", _play)
	_back(_page_missions)


func _play() -> void:
	get_tree().change_scene_to_file("res://levels/arena.tscn")
