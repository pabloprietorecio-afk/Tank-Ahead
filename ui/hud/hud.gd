class_name Hud
extends Control
## HUD de la Fase 2: blindaje, puntuación, oleada, avisos, retícula, recarga,
## indicador del casco, destello de daño y pantalla de fin de partida.

@export var tank: Tank
@export var director: MatchDirector
var touch: TouchControls
var input_source: PlayerInputSource
var weather: Weather

var _info: Label
var _message: Label
var _over: Label
var _version: String = ""
var _message_time: float = 0.0
var _flash: float = 0.0
var _over_time: float = 0.0
var _panel: PanelContainer
var _release: Button



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

	var view_button := Button.new()
	view_button.text = "CÁM"
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
		_show_message(["VISTA CABINA", "VISTA TRASERA", "VISTA TRASERA LEJANA"][GameSettings.camera_view], false))
	add_child(view_button)
	tank.set_view.call_deferred(GameSettings.camera_view)

	_panel = PanelContainer.new()
	_panel.visible = false
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.position.y = 100.0
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	_panel.add_child(box)
	box.add_child(_make_toggle("Movimiento fácil (el tanque se alinea con el cañón)", GameSettings.easy_drive, func(on: bool) -> void:
		GameSettings.easy_drive = on
		GameSettings.save()))
	box.add_child(_make_toggle("Recentrar el cañón al frente (sin movimiento fácil)", GameSettings.auto_recenter, func(on: bool) -> void:
		GameSettings.auto_recenter = on
		GameSettings.save()))
	box.add_child(_make_toggle("Apuntado automático (cerca del enemigo)", GameSettings.aim_assist, func(on: bool) -> void:
		GameSettings.aim_assist = on
		GameSettings.save()))
	add_child(_panel)

	_release = Button.new()
	_release.text = "LIBERAR\nOBJETIVO"
	_release.add_theme_font_size_override("font_size", 24)
	_release.add_theme_color_override("font_color", VectorMaterials.ORANGE)
	_release.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_release.offset_left = -300.0
	_release.offset_top = -380.0
	_release.offset_right = -110.0
	_release.offset_bottom = -280.0
	_release.visible = false
	_release.pressed.connect(func() -> void:
		if input_source != null:
			input_source.release_lock())
	add_child(_release)
	if touch != null:
		touch.exclusions.append_array([gear, view_button, _panel, _release])


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
	_release.visible = tank.aim_lock != null and not director.is_over
	var sky: String = weather.display_name() if weather != null else ""
	_info.text = "v%s  %d FPS   %s\nPUNTOS %d   OLEADA %d   ENEMIGOS %d" % [_version, Engine.get_frames_per_second(), sky, director.score, director.wave, director.alive]
	queue_redraw()


func _draw() -> void:
	var center: Vector2 = size * 0.5
	var green: Color = VectorMaterials.GREEN
	var reticle: Color = VectorMaterials.ORANGE if (tank != null and tank.aim_lock != null) else green
	var aim: Vector2 = _aim_screen_point(center)
	if _flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 0.1, 0.05, _flash * 0.5), true)
	# Retícula
	draw_line(aim + Vector2(-18.0, 0.0), aim + Vector2(-6.0, 0.0), reticle, 2.0)
	draw_line(aim + Vector2(6.0, 0.0), aim + Vector2(18.0, 0.0), reticle, 2.0)
	draw_line(aim + Vector2(0.0, -18.0), aim + Vector2(0.0, -6.0), reticle, 2.0)
	draw_line(aim + Vector2(0.0, 6.0), aim + Vector2(0.0, 18.0), reticle, 2.0)
	if tank == null:
		return
	if tank.aim_lock != null and is_instance_valid(tank.aim_lock):
		var target: Tank = tank.aim_lock
		var font: Font = ThemeDB.fallback_font
		var label: String = "%s  %d m" % [target.stats.display_name, roundi(tank.global_position.distance_to(target.global_position))]
		draw_string(font, center + Vector2(-140.0, -52.0), label, HORIZONTAL_ALIGNMENT_CENTER, 280.0, 18, target.stats.color)
		var bar := Rect2(center + Vector2(-50.0, -44.0), Vector2(100.0, 5.0))
		draw_rect(bar, Color(target.stats.color, 0.3), false, 1.0)
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * target.health.fraction(), bar.size.y)), target.stats.color, true)
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
	# Icono del tanque visto desde arriba (norte arriba): casco y cañón con su orientación real.
	_draw_tank_icon(Vector2(center.x, 74.0), green)


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
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	var hit: Dictionary = tank.get_world_3d().direct_space_state.intersect_ray(query)
	var point: Vector3 = hit["position"] if not hit.is_empty() else to
	if tank.camera.is_position_behind(point):
		return center
	return tank.camera.unproject_position(point)
