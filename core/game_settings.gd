class_name GameSettings
extends RefCounted
## Ajustes del jugador, guardados en user://settings.cfg.

const PATH: String = "user://settings.cfg"

## Fija la torreta sobre el enemigo una vez que la mira lo ha encontrado.
static var aim_assist: bool = false
## La torreta gira 360º siempre. Si está activo, vuelve sola al frente al dejar de moverla.
static var auto_recenter: bool = false

static var _loaded: bool = false


static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		aim_assist = cfg.get_value("controls", "aim_assist", aim_assist)
		auto_recenter = cfg.get_value("controls", "auto_recenter", auto_recenter)


static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("controls", "aim_assist", aim_assist)
	cfg.set_value("controls", "auto_recenter", auto_recenter)
	cfg.save(PATH)
