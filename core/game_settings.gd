class_name GameSettings
extends RefCounted
## Ajustes del jugador, guardados en user://settings.cfg.

const PATH: String = "user://settings.cfg"

## Fija la torreta sobre el enemigo una vez que la mira lo ha encontrado.
static var aim_assist: bool = false
## La torreta gira 360º siempre. Si está activo, vuelve sola al frente al dejar de moverla.
static var auto_recenter: bool = false

## Movimiento fácil: el cañón se apunta libre en el mundo y el casco se alinea con él al avanzar.
static var easy_drive: bool = true

## Vista: 0 = cabina, 1 = detrás cerca, 2 = detrás lejos.
static var camera_view: int = 0

static var _loaded: bool = false


static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		aim_assist = cfg.get_value("controls", "aim_assist", aim_assist)
		camera_view = cfg.get_value("controls", "camera_view", camera_view)
		easy_drive = cfg.get_value("controls", "easy_drive", easy_drive)
		auto_recenter = cfg.get_value("controls", "auto_recenter", auto_recenter)


static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("controls", "aim_assist", aim_assist)
	cfg.set_value("controls", "camera_view", camera_view)
	cfg.set_value("controls", "easy_drive", easy_drive)
	cfg.set_value("controls", "auto_recenter", auto_recenter)
	cfg.save(PATH)
