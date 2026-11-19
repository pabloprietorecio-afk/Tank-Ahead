class_name Water
extends RefCounted
## Agua del campo: ríos (hondos: los tanques solo los cruzan por los puentes y los vados),
## arroyos (se vadean por cualquier sitio, más despacio) y ramblas secas del desierto.
##
## Como el relieve (Terrain), cada cauce es una línea conocida: no hace falta preguntar a la
## física dónde hay agua. `deep_at()` dice si un punto cae en agua honda (ahí no aparece ni se
## coloca nada) y `drag_at()` cuánto frena el agua a un tanque. Para que los tanques no entren
## en el río, cada tramo lleva una barrera invisible en la capa del límite del mapa, la que
## solo tocan ellos: los disparos y la vista pasan por encima del agua. La máquina la ve en su
## mapa de rutas (NavGrid) y con sus rayos, y cruza por donde hay paso.

enum Kind { RIVER, STREAM, WADI }

## Anchura media (m) de cada tipo de cauce, de orilla a orilla.
const HALF_WIDTH: Array[float] = [8.0, 3.2, 5.0]
## Lo que frena a un tanque: vado de un río, arroyo y rambla.
const FORD_DRAG: float = 0.55
const STREAM_DRAG: float = 0.7
const WADI_DRAG: float = 0.9
## Media anchura del paso de un puente y de un vado (a lo largo del río).
const BRIDGE_HALF: float = 7.0
const FORD_HALF: float = 10.0

static var _courses: Array[Course] = []


## Un cauce: la línea por la que corre y sus pasos.
class Course:
	var kind: int = Kind.RIVER
	var points: PackedVector2Array
	var half_width: float = 8.0
	## Pasos: {"at": centro, "dir": dirección del río ahí, "half": media anchura del paso,
	## "bridge": bool, "distance": metros desde el comienzo del cauce}.
	var crossings: Array[Dictionary] = []
	## Rectángulo que contiene el cauce entero (con su anchura): fuera de él no hay que mirar más.
	var bounds := Rect2()

	func measure() -> void:
		bounds = Rect2(points[0], Vector2.ZERO)
		for point in points:
			bounds = bounds.expand(point)
		bounds = bounds.grow(half_width + 1.0)

	## Añade un paso a `distance` metros del comienzo del cauce.
	func add_crossing(distance: float, bridge: bool) -> Dictionary:
		var crossing: Dictionary = {
			"at": Ribbon.point_at(points, distance), "dir": Ribbon.direction_at(points, distance),
			"half": Water.BRIDGE_HALF if bridge else Water.FORD_HALF, "bridge": bridge, "distance": distance,
		}
		crossings.append(crossing)
		return crossing

	## El paso en el que cae `point` (vacío si no cae en ninguno). `slack` ensancha el paso.
	func crossing_at(point: Vector2, slack: float = 0.0) -> Dictionary:
		for crossing in crossings:
			var offset: Vector2 = point - (crossing["at"] as Vector2)
			var dir: Vector2 = crossing["dir"]
			if absf(offset.dot(dir)) <= crossing["half"] + slack and absf(offset.dot(Vector2(-dir.y, dir.x))) <= half_width + 8.0:
				return crossing
		return {}


static func clear() -> void:
	_courses.clear()


static func courses() -> Array[Course]:
	return _courses


static func add(course: Course) -> void:
	course.measure()
	_courses.append(course)


## ¿Cae el punto en agua honda (un río, fuera de sus pasos)? `margin` aleja además de la orilla.
static func deep_at(x: float, z: float, margin: float = 0.0) -> bool:
	var point := Vector2(x, z)
	for course in _courses:
		if course.kind != Kind.RIVER or not course.bounds.grow(margin).has_point(point):
			continue
		if Ribbon.distance_to(course.points, point) < course.half_width + margin and course.crossing_at(point, -margin - 1.0).is_empty():
			return true
	return false


## Factor de velocidad de un tanque en ese punto: 1 en seco, menos metido en el agua.
static func drag_at(x: float, z: float) -> float:
	if _courses.is_empty():
		return 1.0
	var point := Vector2(x, z)
	for course in _courses:
		if not course.bounds.has_point(point) or Ribbon.distance_to(course.points, point) >= course.half_width:
			continue
		match course.kind:
			Kind.STREAM:
				return STREAM_DRAG
			Kind.WADI:
				return WADI_DRAG
			_:
				var crossing: Dictionary = course.crossing_at(point)
				if not crossing.is_empty() and not crossing["bridge"]:
					return FORD_DRAG
	return 1.0


## ¿Es este punto parte de un paso (puente o vado) por el que la máquina puede trazar ruta?
## Lo usa NavGrid para dar por libres esas celdas aunque rocen las barreras de los lados.
static func on_crossing(x: float, z: float) -> bool:
	var point := Vector2(x, z)
	for course in _courses:
		if course.kind != Kind.RIVER:
			continue
		for crossing in course.crossings:
			var offset: Vector2 = point - (crossing["at"] as Vector2)
			var dir: Vector2 = crossing["dir"]
			if absf(offset.dot(dir)) <= crossing["half"] - 3.4 and absf(offset.dot(Vector2(-dir.y, dir.x))) <= course.half_width + 7.0:
				return true
	return false


## Rectángulos que ocupa el cauce (uno por tramo), para que el decorado no se le ponga encima.
static func rects(course: Course, margin: float = 3.0) -> Array[Rect2]:
	var list: Array[Rect2] = []
	var reach: float = course.half_width + margin
	for i in range(1, course.points.size()):
		var a: Vector2 = course.points[i - 1]
		var b: Vector2 = course.points[i]
		var rect := Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (b - a).abs())
		list.append(rect.grow(reach))
	return list


## Monta el cauce en el campo: el agua (o el lecho seco), las orillas, las barreras del río y
## sus vados. Los puentes los pone PropFactory.bridge() sobre cada paso (ver Arena).
static func build(course: Course, front: int) -> Node3D:
	course.measure()
	_courses.append(course)
	var root := Node3D.new()
	root.name = "Cauce"
	var desert: bool = front == Fronts.Id.AFRICA
	var width: float = course.half_width * 2.0
	if course.kind == Kind.WADI:
		var sand: Color = Fronts.ground_colors(front)[2]
		root.add_child(Ribbon.node(course.points, course.half_width + 1.5, Ribbon.Y_BANK, Ribbon.strip(sand.darkened(0.12), sand.darkened(0.4), 5, width + 3.0, 0.9)))
		return root
	var mud: Color = Fronts.ground_colors(front)[2].darkened(0.15)
	root.add_child(Ribbon.node(course.points, course.half_width + 2.2, Ribbon.Y_BANK, Ribbon.strip(mud, mud.darkened(0.5), 2, width + 4.4, 0.8)))
	var water := ShaderMaterial.new()
	water.shader = load("res://shaders/water.gdshader")
	water.set_shader_parameter("noise_tex", VectorMaterials.noise())
	water.set_shader_parameter("width", width)
	if desert:
		water.set_shader_parameter("deep_color", Color(0.1, 0.2, 0.2))
		water.set_shader_parameter("shallow_color", Color(0.4, 0.42, 0.3))
	if course.kind == Kind.STREAM:
		water.set_shader_parameter("shallows", 0.75)
		water.set_shader_parameter("flow", 1.8)
	var surface: MeshInstance3D = Ribbon.node(course.points, course.half_width, Ribbon.Y_WATER, water)
	surface.add_to_group(&"water_surfaces")
	root.add_child(surface)
	if course.kind != Kind.RIVER:
		return root
	# Vados: un tramo de agua clara y baja, con piedras que asoman.
	var shallow: ShaderMaterial = water.duplicate()
	shallow.set_shader_parameter("shallows", 1.0)
	shallow.set_shader_parameter("shallow_color", Color(0.42, 0.44, 0.33))
	shallow.set_shader_parameter("flow", 2.4)
	for crossing in course.crossings:
		if crossing["bridge"]:
			continue
		var from: float = crossing["distance"] - crossing["half"]
		var patch := PackedVector2Array()
		for step in 6:
			patch.append(Ribbon.point_at(course.points, from + crossing["half"] * 2.0 * step / 5.0))
		var ford: MeshInstance3D = Ribbon.node(patch, course.half_width - 0.3, Ribbon.Y_WATER + 0.03, shallow)
		ford.add_to_group(&"water_surfaces")
		root.add_child(ford)
	# Barreras: una caja por tramo, cortada donde hay paso.
	var marks: PackedFloat32Array = Ribbon.lengths(course.points)
	for i in range(1, course.points.size()):
		var spans: Array = [[marks[i - 1], marks[i]]]
		for crossing in course.crossings:
			var low: float = crossing["distance"] - crossing["half"]
			var high: float = crossing["distance"] + crossing["half"]
			var cut: Array = []
			for span: Array in spans:
				if high <= span[0] or low >= span[1]:
					cut.append(span)
					continue
				if low > span[0]:
					cut.append([span[0], low])
				if high < span[1]:
					cut.append([high, span[1]])
			spans = cut
		var a: Vector2 = course.points[i - 1]
		var b: Vector2 = course.points[i]
		var length: float = marks[i] - marks[i - 1]
		if length <= 0.0:
			continue
		for span: Array in spans:
			if span[1] - span[0] < 0.3:
				continue
			var from: Vector2 = a.lerp(b, (span[0] - marks[i - 1]) / length)
			var to: Vector2 = a.lerp(b, (span[1] - marks[i - 1]) / length)
			root.add_child(_barrier(from, to, course.half_width))
	return root


## Barrera invisible de un tramo de río: solo la tocan los tanques.
static func _barrier(from: Vector2, to: Vector2, half_width: float) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Rio"
	body.collision_layer = Tank.LAYER_BOUNDARY
	body.collision_mask = 0
	var middle: Vector2 = (from + to) * 0.5
	var dir: Vector2 = to - from
	body.position = Vector3(middle.x, 2.0, middle.y)
	body.rotation.y = atan2(-dir.y, dir.x)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	# Un poco más larga que el tramo, para que no queden rendijas en las curvas.
	box.size = Vector3(dir.length() + 1.2, 4.0, maxf(half_width * 2.0 - 1.6, 1.0))
	shape.shape = box
	body.add_child(shape)
	return body
