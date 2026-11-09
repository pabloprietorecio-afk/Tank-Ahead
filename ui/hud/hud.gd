class_name Hud
extends Control
## HUD mínimo de la Fase 1: versión, FPS, bajas, retícula, recarga e indicador del casco.

@export var tank: Tank

var kills: int = 0

var _label: Label
var _version: String = ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_version = str(ProjectSettings.get_setting("application/config/version", "dev"))
	_label = Label.new()
	_label.position = Vector2(24.0, 16.0)
	_label.add_theme_color_override("font_color", VectorMaterials.GREEN)
	_label.add_theme_font_size_override("font_size", 22)
	add_child(_label)


func _process(_delta: float) -> void:
	_label.text = "v%s   %d FPS\nBAJAS %d" % [_version, Engine.get_frames_per_second(), kills]
	queue_redraw()


func _draw() -> void:
	var center: Vector2 = size * 0.5
	var green: Color = VectorMaterials.GREEN
	# Retícula
	draw_line(center + Vector2(-18.0, 0.0), center + Vector2(-6.0, 0.0), green, 2.0)
	draw_line(center + Vector2(6.0, 0.0), center + Vector2(18.0, 0.0), green, 2.0)
	draw_line(center + Vector2(0.0, -18.0), center + Vector2(0.0, -6.0), green, 2.0)
	draw_line(center + Vector2(0.0, 6.0), center + Vector2(0.0, 18.0), green, 2.0)
	if tank == null:
		return
	# Barra de recarga bajo la retícula
	var ready_fraction: float = tank.weapon.ready_fraction()
	var bar_color: Color = green if ready_fraction >= 1.0 else VectorMaterials.ORANGE
	var bar_origin: Vector2 = center + Vector2(-30.0, 34.0)
	draw_rect(Rect2(bar_origin, Vector2(60.0, 6.0)), Color(bar_color, 0.3), false, 1.0)
	draw_rect(Rect2(bar_origin, Vector2(60.0 * ready_fraction, 6.0)), bar_color, true)
	# Indicador de orientación del casco (arriba = hacia donde mira la torreta)
	var gauge_center := Vector2(center.x, 70.0)
	draw_arc(gauge_center, 34.0, 0.0, TAU, 32, Color(green, 0.4), 2.0)
	var angle: float = tank.turret_controller.hull_relative_angle()
	var direction := Vector2(-sin(angle), -cos(angle))
	draw_line(gauge_center, gauge_center + direction * 34.0, green, 4.0)
	draw_line(gauge_center, gauge_center + Vector2(0.0, -34.0), Color(green, 0.35), 1.0)
