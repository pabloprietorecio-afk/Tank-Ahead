class_name GameSettings
extends RefCounted
## Ajustes del jugador, guardados en user://settings.cfg.

const PATH: String = "user://settings.cfg"

## Fija la torreta sobre el enemigo una vez que la mira lo ha encontrado.
static var aim_assist: bool = false
## true: el joystick se interpreta respecto a la vista (la torreta); el casco gira solo.
## false: control clásico de tanque (arriba = avanzar, lados = girar el casco).
static var camera_relative: bool = false

static var _loaded: bool = false


static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		aim_assist = cfg.get_value("controls", "aim_assist", aim_assist)
		camera_relative = cfg.get_value("controls", "camera_relative", camera_relative)


static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("controls", "aim_assist", aim_assist)
	cfg.set_value("controls", "camera_relative", camera_relative)
	cfg.save(PATH)
