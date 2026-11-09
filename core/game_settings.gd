class_name GameSettings
extends RefCounted
## Ajustes del jugador, guardados en user://settings.cfg.

const PATH: String = "user://settings.cfg"

## Fija la torreta sobre el enemigo una vez que la mira lo ha encontrado.
static var aim_assist: bool = false
## Torreta libre: gira 360º independiente del casco. Desactivada = control clásico (cañón al frente).
static var turret_free: bool = false

static var _loaded: bool = false


static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		aim_assist = cfg.get_value("controls", "aim_assist", aim_assist)
		turret_free = cfg.get_value("controls", "turret_free", turret_free)


static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("controls", "aim_assist", aim_assist)
	cfg.set_value("controls", "turret_free", turret_free)
	cfg.save(PATH)
