class_name Fronts
## Frentes de batalla: Normandía (1944), Norte de África (1941-43) y Kursk (1943).
## Cada frente define terreno, cielo, objetos, climas posibles, camuflajes y plantillas de tanques.
## Las plantillas son una aproximación histórica: algunos modelos no coincidieron exactamente
## en ese frente, pero sí en la misma época.

enum Id { NORMANDY, AFRICA, KURSK }
enum Faction { ALLIES, AXIS }

const NAMES: Array[String] = ["NORMANDÍA 1944", "NORTE DE ÁFRICA", "KURSK 1943"]
const FACTION_NAMES: Array[String] = ["ALIADOS", "ALEMANIA"]

const ROSTERS: Dictionary = {
	Id.NORMANDY: {
		Faction.ALLIES: ["m8_greyhound", "m4_sherman", "cromwell", "m10_wolverine", "churchill", "m26_pershing"],
		Faction.AXIS: ["puma", "panzer4", "stug3", "tiger1", "panther", "tiger2"],
	},
	Id.AFRICA: {
		Faction.ALLIES: ["crusader", "m8_greyhound", "m4_sherman", "m10_wolverine", "churchill"],
		Faction.AXIS: ["puma", "panzer3", "panzer4", "marder3", "stug3", "tiger1"],
	},
	Id.KURSK: {
		Faction.ALLIES: ["ba64", "t34_76", "su85", "kv1", "t34_85", "is2"],
		Faction.AXIS: ["puma", "panzer3", "panzer4", "stug3", "tiger1", "panther", "elefant"],
	},
}

## Tanque del jugador por defecto en cada frente.
const PLAYER_TANK: Dictionary = {
	Id.NORMANDY: {Faction.ALLIES: "m4_sherman", Faction.AXIS: "panzer4"},
	Id.AFRICA: {Faction.ALLIES: "m4_sherman", Faction.AXIS: "panzer4"},
	Id.KURSK: {Faction.ALLIES: "t34_76", Faction.AXIS: "panzer4"},
}


static func roster(front: int, faction: int) -> Array[TankStats]:
	var list: Array[TankStats] = []
	for id in ROSTERS[front][faction]:
		list.append(load("res://data/tanks/%s.tres" % id))
	return list


static func tank(id: String) -> TankStats:
	return load("res://data/tanks/%s.tres" % id)


## Pintura según bando y frente.
static func paint(front: int, faction: int, nation: String) -> Dictionary:
	if faction == Faction.AXIS:
		match front:
			Id.AFRICA:
				return {"base": Color(0.62, 0.52, 0.34), "mode": 1, "a": Color(0.5, 0.45, 0.33), "b": Color(0.55, 0.47, 0.3)}
			Id.KURSK:
				return {"base": Color(0.6, 0.53, 0.33), "mode": 2, "a": Color(0.25, 0.3, 0.17), "b": Color(0.35, 0.22, 0.13)}
			_:
				return {"base": Color(0.62, 0.55, 0.36), "mode": 1, "a": Color(0.22, 0.28, 0.16), "b": Color(0.36, 0.22, 0.13)}
	match front:
		Id.AFRICA:
			return {"base": Color(0.66, 0.58, 0.42), "mode": 1, "a": Color(0.45, 0.42, 0.36), "b": Color(0.58, 0.5, 0.36)}
		Id.KURSK:
			return {"base": Color(0.27, 0.31, 0.18), "mode": 0, "a": Color.BLACK, "b": Color.BLACK}
		_:
			if nation == "UK":
				return {"base": Color(0.3, 0.31, 0.2), "mode": 1, "a": Color(0.2, 0.2, 0.15), "b": Color(0.28, 0.27, 0.2)}
			return {"base": Color(0.31, 0.32, 0.2), "mode": 0, "a": Color.BLACK, "b": Color.BLACK}


## Colores del terreno: [hierba, hierba seca, tierra, grava].
static func ground_colors(front: int) -> Array[Color]:
	match front:
		Id.AFRICA:
			return [Color(0.62, 0.5, 0.32), Color(0.7, 0.58, 0.38), Color(0.55, 0.42, 0.27), Color(0.5, 0.45, 0.38)]
		Id.KURSK:
			return [Color(0.32, 0.33, 0.14), Color(0.5, 0.45, 0.22), Color(0.3, 0.24, 0.15), Color(0.38, 0.36, 0.3)]
		_:
			return [Color(0.18, 0.3, 0.1), Color(0.28, 0.35, 0.14), Color(0.28, 0.22, 0.14), Color(0.4, 0.4, 0.38)]


## Climas posibles (Weather.Kind) al sortear. Los repetidos salen más a menudo: más de la mitad
## de las partidas tocan un día claro (soleado o con nubes y claros).
static func weathers(front: int) -> Array[int]:
	var sunny: int = Weather.Kind.SUNNY
	var clouds: int = Weather.Kind.CLOUDS
	match front:
		Id.AFRICA:
			return [sunny, sunny, sunny, clouds, Weather.Kind.CLEAR, Weather.Kind.FOG]
		Id.KURSK:
			return [sunny, sunny, clouds, clouds, Weather.Kind.CLEAR, Weather.Kind.FOG, Weather.Kind.RAIN, Weather.Kind.SNOW]
		_:
			return [sunny, sunny, clouds, clouds, Weather.Kind.CLEAR, Weather.Kind.FOG, Weather.Kind.RAIN]


## Climas que el jugador puede elegir en este frente, en el orden del selector.
static func weather_choices(front: int) -> Array[int]:
	var possible: Array[int] = weathers(front)
	var list: Array[int] = []
	for kind in Weather.MENU_ORDER:
		if kind in possible:
			list.append(kind)
	return list


static func mountain_color(front: int) -> Color:
	match front:
		Id.AFRICA:
			return Color(0.6, 0.47, 0.3)
		Id.KURSK:
			return Color(0.36, 0.38, 0.22)
		_:
			return Color(0.26, 0.36, 0.18)


## Potencia de combate del tanque de serie del jugador (la de siempre).
const PLAYER_ARMOR: float = 100.0
const PLAYER_RELOAD: float = 1.2
const PLAYER_DAMAGE: float = 25.0
const PLAYER_SHELL_SPEED: float = 150.0
const PLAYER_SPEED: float = 14.0
const PLAYER_ACCELERATION: float = 18.0
const PLAYER_HULL_TURN: float = 1.3
const PLAYER_TURRET_TURN: float = 3.0


## Ficha del tanque del jugador. Con `id` vacío es el de serie del frente: el modelo histórico
## con la potencia de combate del jugador. Con otro `id` (repetir una misión con otro tanque,
## premium) esa potencia cambia según lo que ese vehículo es frente al de serie: un blindado de
## exploración corre más y aguanta menos; un carro pesado es lento, duro y pega más fuerte. La
## diferencia se suaviza (raíz) para que todos se puedan jugar. El tamaño y, en los cazacarros
## de casamata, el giro limitado del cañón son los del vehículo.
static func player_stats(front: int, faction: int, id: String = "") -> TankStats:
	var standard: TankStats = tank(PLAYER_TANK[front][faction])
	var chosen: TankStats = standard
	if id != "" and id != standard.id and id in ROSTERS[front][faction]:
		chosen = tank(id)
	var stats: TankStats = chosen.duplicate()
	stats.max_armor = roundf(PLAYER_ARMOR * pow(chosen.max_armor / standard.max_armor, 0.4))
	stats.reload_time = PLAYER_RELOAD * sqrt(chosen.reload_time / standard.reload_time)
	stats.damage = roundf(PLAYER_DAMAGE * sqrt(chosen.damage / standard.damage))
	stats.projectile_speed = PLAYER_SHELL_SPEED * sqrt(chosen.projectile_speed / standard.projectile_speed)
	stats.max_speed = PLAYER_SPEED * sqrt(chosen.max_speed / standard.max_speed)
	stats.acceleration = PLAYER_ACCELERATION * sqrt(chosen.acceleration / standard.acceleration)
	stats.hull_turn_speed = PLAYER_HULL_TURN * sqrt(chosen.hull_turn_speed / standard.hull_turn_speed)
	stats.turret_turn_speed = PLAYER_TURRET_TURN * sqrt(chosen.turret_turn_speed / standard.turret_turn_speed)
	if chosen == standard:
		stats.body_scale = 1.0
		stats.traverse_limit_deg = 0.0
	return stats
