class_name Hud
extends Control
## HUD de la Fase 2: blindaje, puntuación, oleada, avisos, retícula, recarga,
## indicador del casco, destello de daño y pantalla de fin de partida.

@export var tank: Tank
@export var director: MatchDirector

var _info: Label
var _message: Label
var _over: Label
var _version: String = ""
var _message_time: float = 0.0
var _flash: float = 0.0
var _over_time: float = 0.0
var _panel: PanelContainer



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
	_over = _make_label(40, Vector2.ZERO)
	_over.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_over.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_over.grow_vertical = Control.GROW_DIRECTION_BOTH
	_over.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_over.visible = false
	tank.damaged.connect(func(amount: float, _s: Node) -> void: _flash = minf(_flash + amount / 40.0, 0.6))
	director.message.connect(_show_message)
	director.game_over.connect(_on_game_over)
	GameSettings.ensure_loaded()
	_build_settings()


func _build_settings() -> void:
	var gear := Button.new()
	gear.text = "⚙"
	gear.add_theme_font_size_override("font_size", 40)
	gear.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	gear.position = Vector2(-90.0, 14.0)
	gear.size = Vector2(76.0, 76.0)
	gear.pressed.connect(func() -> void: _panel.visible = not _panel.visible)
	add_child(gear)

	_panel = PanelContainer.new()
	_panel.visible = false
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.position.y = 100.0
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	_panel.add_child(box)
	box.add_child(_make_toggle("Ayuda de apuntado (fija al enemigo)", GameSettings.aim_assist, func(on: bool) -> void:
		GameSettings.aim_assist = on
		GameSettings.save()))
	add_child(_panel)


func _make_toggle(text: String, value: bool, on_change: Callable) -> CheckButton:
	var toggle := CheckButton.new()
	toggle.text = text
	toggle.button_pressed = value
	toggle.add_theme_font_size_override("font_size", 24)
	toggle.toggled.connect(on_change)
	return toggle


func _make_label(font_size: int, pos: Vector2) -> Label:
	var label := Label.new()
	label.position = pos
	label.add_theme_color_override("font_color", VectorMaterials.GREEN)
	label.add_theme_font_size_override("font_size", font_size)
	add_child(label)
	return label


func _show_message(text: String, urgent: bool) -> void:
	_message.text = text
	_message.add_theme_color_override("font_color", VectorMaterials.ORANGE if urgent else VectorMaterials.GREEN)
	_message_time = 3.5


func _on_game_over(score: int, wave: int) -> void:
	_over.text = "TANQUE DESTRUIDO\nPUNTOS %d   OLEADA %d\n\nTOCA PARA REINICIAR" % [score, wave]
	_over.visible = true
	_over_time = 0.0


func _input(event: InputEvent) -> void:
	if director.is_over and _over_time > 1.2 and event is InputEventScreenTouch and event.pressed:
		get_tree().reload_current_scene()


func _process(delta: float) -> void:
	_message_time = maxf(_message_time - delta, 0.0)
	_message.modulate.a = clampf(_message_time, 0.0, 1.0)
	_flash = maxf(_flash - delta * 1.5, 0.0)
	if director.is_over:
		_over_time += delta
	_info.text = "v%s  %d FPS\nPUNTOS %d   OLEADA %d   ENEMIGOS %d" % [_version, Engine.get_frames_per_second(), director.score, director.wave, director.alive]
	queue_redraw()


func _draw() -> void:
	var center: Vector2 = size * 0.5
	var green: Color = VectorMaterials.GREEN
	var reticle: Color = VectorMaterials.ORANGE if (tank != null and tank.aim_lock != null) else green
	if _flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 0.1, 0.05, _flash * 0.5), true)
	# Retícula
	draw_line(center + Vector2(-18.0, 0.0), center + Vector2(-6.0, 0.0), reticle, 2.0)
	draw_line(center + Vector2(6.0, 0.0), center + Vector2(18.0, 0.0), reticle, 2.0)
	draw_line(center + Vector2(0.0, -18.0), center + Vector2(0.0, -6.0), reticle, 2.0)
	draw_line(center + Vector2(0.0, 6.0), center + Vector2(0.0, 18.0), reticle, 2.0)
	if tank == null:
		return
	# Barra de recarga bajo la retícula
	var ready_fraction: float = tank.weapon.ready_fraction()
	var bar_color: Color = green if ready_fraction >= 1.0 else VectorMaterials.ORANGE
	var bar_origin: Vector2 = center + Vector2(-30.0, 34.0)
	draw_rect(Rect2(bar_origin, Vector2(60.0, 6.0)), Color(bar_color, 0.3), false, 1.0)
	draw_rect(Rect2(bar_origin, Vector2(60.0 * ready_fraction, 6.0)), bar_color, true)
	# Blindaje (abajo al centro)
	var armor: float = tank.health.fraction()
	var armor_color: Color = green if armor > 0.35 else VectorMaterials.ORANGE
	var armor_origin := Vector2(center.x - 120.0, size.y - 46.0)
	draw_rect(Rect2(armor_origin, Vector2(240.0, 14.0)), Color(armor_color, 0.3), false, 2.0)
	draw_rect(Rect2(armor_origin, Vector2(240.0 * armor, 14.0)), armor_color, true)
	# Brújula: la marca fija es el norte del mapa; la aguja gira con el rumbo del tanque.
	var gauge_center := Vector2(center.x, 70.0)
	draw_arc(gauge_center, 34.0, 0.0, TAU, 32, Color(green, 0.4), 2.0)
	draw_line(gauge_center + Vector2(0.0, -34.0), gauge_center + Vector2(0.0, -42.0), Color(green, 0.7), 2.0)
	draw_string(ThemeDB.fallback_font, gauge_center + Vector2(-6.0, -46.0), "N", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color(green, 0.7))
	var heading: float = tank.global_rotation.y
	var direction := Vector2(-sin(heading), -cos(heading))
	draw_line(gauge_center, gauge_center + direction * 34.0, green, 4.0)
	draw_line(gauge_center, gauge_center - direction * 12.0, Color(green, 0.35), 2.0)
