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
## - `villages`, `hedges`, `woods`, `hills`, `mounds`, `scatter`: cuánto hay del decorado de
##   siempre de ese frente (caseríos, setos, arboledas, colinas, lomas y objetos sueltos).

const TABLE: Dictionary = {
	Fronts.Id.NORMANDY: {
		"bocage": {"water": "stream"},
		"bocage_dense": {"hedges": 22, "woods": 8, "villages": 1},
		"town": {"town": "north", "villages": 0, "hedges": 8, "woods": 4},
		"town_center": {"town": "center", "villages": 0, "hedges": 9, "woods": 4},
		"river": {"water": "river_ew", "town": "river", "villages": 1, "hedges": 9},
		"bridge": {"water": "river_ew", "river_at": [-52.0, -58.0, -46.0], "crossings": [[0.0, true], [-125.0, true], [125.0, true], [-62.0, false], [62.0, false]], "villages": 1, "hedges": 9},
		"plain": {"wheat": 6, "hedges": 3, "woods": 2, "rail": "ew", "hills": 1, "mounds": 2},
		"ridge": {"ridge": 6, "hedges": 7, "woods": 4, "villages": 1, "hills": 4},
	},
	Fronts.Id.AFRICA: {
		"desert": {},
		"wadi": {"water": "wadi"},
		"oasis": {"water": "spring", "woods": 14, "villages": 1},
		"town": {"town": "north", "villages": 0, "woods": 4},
		"ridge": {"ridge": 6, "hills": 7, "villages": 1},
		"box": {"trenches": 2, "villages": 0, "hills": 3, "scatter": 16},
		"djebel": {"water": "wadi", "town": "side", "ridge": 4, "villages": 0},
	},
	Fronts.Id.KURSK: {
		"steppe": {"wheat": 4, "trenches": 1},
		"defences": {"trenches": 3, "wheat": 5, "villages": 1},
		"town": {"town": "north", "rail": "ew", "station": true, "villages": 0, "wheat": 3},
		"town_center": {"town": "center", "rail": "ns", "station": true, "villages": 0, "wheat": 3},
		"villages": {"town": "side", "villages": 2, "wheat": 4, "water": "stream"},
		"river": {"water": "river_ew", "trenches": 1, "villages": 1, "wheat": 2},
		"woods": {"woods": 14, "water": "stream", "villages": 1, "scatter": 8},
		"ridge": {"ridge": 6, "trenches": 1, "wheat": 2, "villages": 1},
		"rails": {"rail": "ew", "wheat": 6, "villages": 1, "trenches": 1},
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
