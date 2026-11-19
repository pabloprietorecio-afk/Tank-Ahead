class_name Layouts
extends RefCounted
## Trazados del campo de batalla. Cada misión de la historia nombra el suyo (`map` en Campaign),
## pensado para el sitio real en el que se libró; supervivencia y captura la bandera sortean uno
## de los abiertos de su frente. Un trazado es una lista de rasgos que la arena sabe montar:
##
## - `water`: "river_ew" o "river_ns" (río hondo, de lado a lado: solo se cruza por puentes y
##   vados), "stream" (arroyo vadeable), "wadi" (rambla seca) o "spring" (charca de oasis).
##   `river_at`: por dónde pasa el río (coordenada, m); `crossings`: pasos [coordenada a lo
##   largo, ¿puente?]; por defecto, dos puentes a los lados y un vado en el centro.
## - `town`: pueblo de verdad, con calles: "center" (alrededor del centro del mapa, que queda
##   libre como plaza), "north" (entre el jugador y el norte), "side" (a un lado) o "river"
##   (a caballo del río, con el puente en su calle mayor).
## - `rail`: "ew" o "ns", vía de tren que cruza el mapa; con `station`, estación y vagones.
## - `trenches`: líneas de trincheras con parapeto de tierra (de lado a lado del mapa).
## - `wheat`: trigales; `ridge`: lomas grandes en las que cubrirse.
## - Solo en Normandía: `bocage` (lado, en metros, de los prados cercados de setos), `farm`
##   (granjas de piedra), `gliders` (planeadores estrellados) y `asparagus` (prados con estacas
##   contra planeadores).
## - Solo en el desierto: `scarp` (escarpe de roca que cruza el mapa por esa z, con tres
##   collados), `dunes`, `outcrops` (afloramientos de roca) y `minefields`.
## - Solo en la estepa: `sunflowers` (campos de girasoles) y `hulks` (carros calcinados).
## - `villages`, `hedges`, `woods`, `hills`, `mounds`, `scatter`: cuánto hay del decorado de
##   siempre de ese frente (caseríos, setos, arboledas, colinas, lomas y objetos sueltos).

const TABLE: Dictionary = {
	Fronts.Id.NORMANDY: {
		"bocage": {"water": "stream", "bocage": 62.0, "hedges": 3},
		# Tras las playas del desembarco: el bocage y, a un lado, un pueblo de la costa.
		"coast": {"water": "stream", "bocage": 62.0, "hedges": 3, "town": "side", "villages": 1},
		"bocage_dense": {"bocage": 50.0, "hedges": 3, "woods": 7, "villages": 1},
		"town": {"town": "north", "villages": 0, "hedges": 8, "woods": 4},
		"town_center": {"town": "center", "villages": 0, "hedges": 9, "woods": 4},
		"river": {"water": "river_ew", "town": "river", "villages": 1, "hedges": 9},
		"bridge": {"water": "river_ew", "river_at": [-52.0, -58.0, -46.0], "crossings": [[0.0, true], [-125.0, true], [125.0, true], [-62.0, false], [62.0, false]], "villages": 1, "hedges": 9, "gliders": 3},
		"plain": {"wheat": 6, "hedges": 3, "woods": 2, "rail": "ew", "mounds": 2, "asparagus": 2},
		# La llanura de Caen: trigales, la vía y los pueblos de piedra que la salpican.
		"plain_village": {"wheat": 6, "hedges": 3, "woods": 2, "rail": "ew", "mounds": 2, "asparagus": 2, "town": "side", "villages": 2},
		"ridge": {"ridge": 6, "hedges": 7, "woods": 4, "villages": 2},
	},
	Fronts.Id.AFRICA: {
		"desert": {},
		"wadi": {"water": "wadi"},
		"oasis": {"water": "spring", "woods": 14, "villages": 1},
		"town": {"town": "north", "villages": 0, "woods": 4},
		"ridge": {"ridge": 3, "scarp": -52.0, "villages": 1, "dunes": 3},
		"box": {"trenches": 2, "villages": 0, "scatter": 16, "minefields": 5, "dunes": 3},
		# El Alamein: las cajas defensivas junto a la vía del ferrocarril de la costa.
		"alamein": {"trenches": 2, "villages": 0, "scatter": 16, "minefields": 5, "dunes": 3, "rail": "ew"},
		# El puerto: la ciudad a un lado y el llano despejado que baja hasta la rada.
		"harbour": {"town": "side", "villages": 0, "outcrops": 4, "dunes": 2},
		"djebel": {"water": "wadi", "town": "side", "ridge": 3, "villages": 0, "outcrops": 9},
	},
	Fronts.Id.KURSK: {
		"steppe": {"wheat": 4, "trenches": 1, "sunflowers": 3},
		"defences": {"trenches": 3, "wheat": 4, "sunflowers": 2, "villages": 2, "hulks": 4},
		"town": {"town": "north", "rail": "ew", "station": true, "villages": 0, "wheat": 3},
		"town_center": {"town": "center", "rail": "ns", "station": true, "villages": 0, "wheat": 3, "hulks": 5},
		"villages": {"town": "side", "villages": 2, "wheat": 4, "water": "stream", "sunflowers": 3},
		"river": {"water": "river_ew", "trenches": 1, "villages": 1, "wheat": 2},
		"woods": {"woods": 14, "water": "stream", "villages": 1, "scatter": 8},
		"ridge": {"ridge": 6, "trenches": 1, "wheat": 2, "villages": 2},
		"rails": {"rail": "ew", "wheat": 5, "sunflowers": 3, "villages": 2, "trenches": 1},
	},
}

## Trazados entre los que sortean supervivencia y captura la bandera: sin ríos hondos ni
## pueblos en mitad del campo, que estorbarían a las bases y a las oleadas.
const OPEN: Dictionary = {
	Fronts.Id.NORMANDY: ["bocage", "bocage_dense", "plain", "ridge", ""],
	Fronts.Id.AFRICA: ["desert", "wadi", "oasis", "ridge", ""],
	Fronts.Id.KURSK: ["steppe", "defences", "woods", "ridge", "rails", ""],
}


## Los rasgos del trazado `name` en ese frente. Con nombre vacío (o desconocido), el campo de
## siempre: solo el decorado suelto del frente.
static func get_layout(front: int, name: String) -> Dictionary:
	var table: Dictionary = TABLE.get(front, {})
	return table.get(name, {})


## Un trazado abierto al azar para ese frente.
static func random_open(front: int) -> String:
	var names: Array = OPEN.get(front, [""])
	return names.pick_random()
