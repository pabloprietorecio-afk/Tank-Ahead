class_name GameSession
## Elecciones del menú (modo, bando, frente, misión) y progreso de la campaña.

enum Mode { SURVIVAL, CTF, STORY, TUTORIAL }

const MODE_NAMES: Array[String] = ["SUPERVIVENCIA", "CAPTURA LA BANDERA", "HISTORIA", "TUTORIAL"]
const PROGRESS_PATH: String = "user://progress.cfg"

static var mode: int = Mode.SURVIVAL
static var faction: int = Fronts.Faction.ALLIES
## Frente elegido en el menú.
static var front_choice: int = Fronts.Id.NORMANDY
static var mission_index: int = 0
## Frente de la partida en curso (resuelto a partir de front_choice).
static var front: int = Fronts.Id.NORMANDY
## Página con la que debe abrirse el menú principal la próxima vez ("" = la normal).
static var menu_page: String = ""
## Clima forzado para pruebas y capturas (Weather.Kind); -1 = el que toque.
static var debug_weather: int = -1


static func enemy_faction() -> int:
	return Fronts.Faction.AXIS if faction == Fronts.Faction.ALLIES else Fronts.Faction.ALLIES


## Decide el frente de esta partida (en el modo historia, el de la misión).
static func resolve_front() -> void:
	if mode == Mode.TUTORIAL:
		front = Fronts.Id.NORMANDY
	elif mode == Mode.STORY:
		front = current_mission().get("front", Fronts.Id.NORMANDY)
	else:
		front = front_choice


static func missions() -> Array[Dictionary]:
	return Campaign.missions(faction, front_choice)


static func current_mission() -> Dictionary:
	var list: Array[Dictionary] = missions()
	return list[clampi(mission_index, 0, list.size() - 1)]


## Misión de pago desbloqueada una vez viendo un anuncio recompensado («frente/bando/posición»).
## Solo vive en memoria: dura hasta superar esa misión o cerrar el juego.
static var reward_unlock: String = ""


static func _reward_key(index: int) -> String:
	return "f%d_c%d_m%d" % [faction, front_choice, index]


## ¿La misión exige premium y aún no se tiene? (El anuncio recompensado la abre una vez.)
static func mission_locked(index: int) -> bool:
	return Premium.mission_locked(index) and reward_unlock != _reward_key(index)


static func grant_reward_unlock(index: int) -> void:
	reward_unlock = _reward_key(index)


static func clear_reward_unlock() -> void:
	reward_unlock = ""


static func _campaign_key() -> String:
	return "f%d_c%d" % [faction, front_choice]


## Número de misiones superadas en la campaña elegida.
static func completed_missions() -> int:
	var cfg := ConfigFile.new()
	cfg.load(PROGRESS_PATH)
	return cfg.get_value("campaign", _campaign_key(), 0)


static func mark_mission_completed(index: int) -> void:
	var cfg := ConfigFile.new()
	cfg.load(PROGRESS_PATH)
	var current: int = cfg.get_value("campaign", _campaign_key(), 0)
	cfg.set_value("campaign", _campaign_key(), maxi(current, index + 1))
	cfg.save(PROGRESS_PATH)


static func best_wave() -> int:
	var cfg := ConfigFile.new()
	cfg.load(PROGRESS_PATH)
	return cfg.get_value("survival", "best_wave", 0)


static func record_wave(wave: int) -> void:
	var cfg := ConfigFile.new()
	cfg.load(PROGRESS_PATH)
	if wave > cfg.get_value("survival", "best_wave", 0):
		cfg.set_value("survival", "best_wave", wave)
		cfg.save(PROGRESS_PATH)


## Tutorial: si ya se ofreció al abrir el juego y si se ha completado alguna vez.
static func tutorial_offered() -> bool:
	var cfg := ConfigFile.new()
	cfg.load(PROGRESS_PATH)
	return cfg.get_value("tutorial", "offered", false)


static func tutorial_completed() -> bool:
	var cfg := ConfigFile.new()
	cfg.load(PROGRESS_PATH)
	return cfg.get_value("tutorial", "completed", false)


static func mark_tutorial(key: String) -> void:
	var cfg := ConfigFile.new()
	cfg.load(PROGRESS_PATH)
	if cfg.get_value("tutorial", key, false):
		return
	cfg.set_value("tutorial", key, true)
	cfg.save(PROGRESS_PATH)
