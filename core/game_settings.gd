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

## Sombras en tiempo real (desactivar en móviles lentos).
static var shadows: bool = true

## Volúmenes (0..1). La música va bajita por defecto.
static var music_volume: float = 0.3
static var sfx_volume: float = 1.0
static var voice_volume: float = 0.9
## Volumen general: sube o baja todo a la vez.
static var master_volume: float = 1.0

## Dificultad: 0 fácil, 1 normal, 2 difícil, 3 inferno.
const DIFFICULTY_NAMES: Array[String] = ["FÁCIL", "NORMAL", "DIFÍCIL", "INFERNO"]
const DIFFICULTY_HINTS: Array[String] = [
	"Aparecen pocos enemigos nuevos en cada misión",
	"Los enemigos de siempre",
	"Un enemigo más en cada tanda de refuerzos",
	"Dos enemigos más en cada tanda de refuerzos",
]
static var difficulty: int = 1

## Dibuja un borde azul alrededor de los tanques enemigos para verlos mejor.
static var highlight_enemies: bool = false

static var _loaded: bool = false


static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		aim_assist = cfg.get_value("controls", "aim_assist", aim_assist)
		camera_view = cfg.get_value("controls", "camera_view", camera_view)
		shadows = cfg.get_value("graphics", "shadows", shadows)
		music_volume = cfg.get_value("audio", "music", music_volume)
		sfx_volume = cfg.get_value("audio", "sfx", sfx_volume)
		voice_volume = cfg.get_value("audio", "voice", voice_volume)
		master_volume = cfg.get_value("audio", "master", master_volume)
		difficulty = clampi(cfg.get_value("game", "difficulty", difficulty), 0, 3)
		highlight_enemies = cfg.get_value("game", "highlight_enemies", highlight_enemies)
		easy_drive = cfg.get_value("controls", "easy_drive", easy_drive)
		auto_recenter = cfg.get_value("controls", "auto_recenter", auto_recenter)


static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("controls", "aim_assist", aim_assist)
	cfg.set_value("controls", "camera_view", camera_view)
	cfg.set_value("graphics", "shadows", shadows)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("audio", "voice", voice_volume)
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("game", "difficulty", difficulty)
	cfg.set_value("game", "highlight_enemies", highlight_enemies)
	cfg.set_value("controls", "easy_drive", easy_drive)
	cfg.set_value("controls", "auto_recenter", auto_recenter)
	cfg.save(PATH)


## Enemigos de más (o de menos) en cada tanda de refuerzos: -1, 0, +1 o +2.
static func batch_extra() -> int:
	ensure_loaded()
	return difficulty - 1


## Tamaño de una tanda de `base` enemigos con la dificultad actual (nunca menos de uno).
static func batch(base: int) -> int:
	return maxi(base + batch_extra(), 1)


## Factor para el total de enemigos de una misión y, en fácil, para espaciar los refuerzos.
static func total_factor() -> float:
	ensure_loaded()
	return [0.6, 1.0, 1.25, 1.5][difficulty]
