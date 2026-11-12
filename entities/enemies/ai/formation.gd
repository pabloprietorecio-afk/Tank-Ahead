class_name Formation
extends RefCounted
## Formación de los tanques que siguen al jugador con la orden «todos conmigo».
##
## Es una cuña abierta por detrás del líder: una pareja a sus costados, algo retrasada; la
## siguiente, más abierta y más atrás; y así, alternando, las demás. Cada puesto queda a 18 m o
## más de los otros y del líder, y nunca delante de él (no le tapa el paso ni el tiro). Tampoco
## hay puestos justo a su espalda: la calle del centro queda libre para que pueda dar marcha
## atrás o media vuelta sin encontrarse a nadie, y la cámara exterior no tiene un tanque delante.
##
## La formación no gira con el casco del líder sino con su rumbo de marcha, y poco a poco: si el
## jugador gira sobre sí mismo o da marcha atrás, los puestos no cambian de lado. Si el líder da
## media vuelta, la formación no barre por delante de él: se invierte de golpe (cada puesto pasa
## al otro lado del líder, por su mismo costado) y los tanques le dejan pasar por el centro.
## Un puesto que cae dentro de un edificio, de una colina o fuera del campo se corre al hueco
## libre más cercano. Y los puestos se reparten de modo que nadie tenga que cruzarse con nadie:
## cada tanque va al que le queda más a mano.

## Pareja de los costados: metros hacia fuera y hacia atrás del líder.
const FLANK := Vector2(14.0, 12.0)
## Segunda pareja de cada bloque: más abierta y más atrás.
const WING := Vector2(28.0, 24.0)
## Cada bloque de dos parejas va esta distancia por detrás del anterior.
const BLOCK_DEPTH: float = 26.0
## Avance del líder (m/s) a partir del cual su rumbo arrastra el de la formación.
const MARCH_SPEED: float = 1.5
## Giro máximo de la formación (rad/s), para que los puestos de fuera no barran más deprisa de
## lo que corre un tanque.
const TURN_RATE: float = 0.6
## Cambio de rumbo del líder (rad) a partir del cual la formación se invierte en vez de girar.
const FLIP_ANGLE: float = 2.1
## Los puestos no salen del campo (el muro está a 200 m).
const FIELD_LIMIT: float = 176.0
## Separación mínima que se respeta al correr un puesto a un hueco libre: con los demás puestos
## y con el líder.
const MIN_GAP: float = 13.0
const LEADER_GAP: float = 17.0
## Cada cuánto se revisa si los puestos están libres de obstáculos (s).
const CHECK_INTERVAL: float = 0.25
## Un reparto nuevo solo se adopta si recorta el camino total a menos de esta fracción: evita
## que dos tanques se pasen el rato cambiándose el puesto entre dos repartos parecidos.
const REASSIGN_GAIN: float = 0.7

var leader: Tank
## Hasta dónde llega el campo en cada eje, en metros desde el centro: los puestos no salen de ahí.
var field_limit: float = FIELD_LIMIT
## Rumbo de la formación: unitario y horizontal.
var heading: Vector3 = Vector3.FORWARD
## Quién ocupa cada puesto (members[i] va en el puesto i).
var members: Array[AIBrain] = []

var _slots := PackedVector2Array()
## Corrección de cada puesto para sacarlo de un obstáculo (se revisa cada CHECK_INTERVAL).
var _shift := PackedVector3Array()
var _points := PackedVector3Array()
var _check_timer: float = 0.0
var _grid: NavGrid


func _init(leader_tank: Tank) -> void:
	leader = leader_tank
	heading = _forward()


## Puestos para `count` seguidores: x = metros a la derecha del líder, y = metros por detrás.
static func layout(count: int) -> PackedVector2Array:
	var slots := PackedVector2Array()
	for slot in count:
		# Por parejas, de dentro afuera: izquierda y derecha. Si son impares, el último va sin pareja.
		var pair: int = slot / 2
		var base: Vector2 = FLANK if pair % 2 == 0 else WING
		slots.append(Vector2(-base.x if slot % 2 == 0 else base.x, base.y + BLOCK_DEPTH * (pair / 2)))
	return slots


## Lleva el rumbo de la formación hacia el de marcha del líder y pone al día los puestos.
func update(delta: float) -> void:
	if not is_instance_valid(leader):
		return
	var forward: Vector3 = _forward()
	var flipped: bool = false
	if leader.velocity.dot(forward) > MARCH_SPEED:
		var angle: float = heading.signed_angle_to(forward, Vector3.UP)
		if absf(angle) > FLIP_ANGLE:
			# Media vuelta: girando, los puestos de un costado barrerían por delante del líder.
			heading = -heading
			angle = heading.signed_angle_to(forward, Vector3.UP)
			flipped = true
		heading = heading.rotated(Vector3.UP, clampf(angle, -TURN_RATE * delta, TURN_RATE * delta)).normalized()
	_check_timer -= delta
	var check: bool = flipped or _check_timer <= 0.0
	if check:
		_check_timer = CHECK_INTERVAL
	_place(check)
	if flipped:
		# Los puestos han saltado de sitio: cada tanque se queda con el que ahora tiene más cerca.
		var present: Array[AIBrain] = []
		for brain in members:
			if is_instance_valid(brain) and is_instance_valid(brain.tank):
				present.append(brain)
		if present.size() == members.size():
			_assign(_best_order(present))


## Pone al día quién sigue al líder. Si cambia el grupo se reparten los puestos de nuevo; si
## no, solo se cambia el reparto cuando otro ahorra bastante camino.
func set_members(brains: Array[AIBrain]) -> void:
	var same: bool = brains.size() == members.size()
	if same:
		for brain in brains:
			if not brain in members:
				same = false
				break
	if not same:
		_slots = layout(brains.size())
		_shift.resize(_slots.size())
		_shift.fill(Vector3.ZERO)
		_points.resize(_slots.size())
		_place(true)
		_assign(_best_order(brains))
	else:
		var best: Array[AIBrain] = _best_order(members)
		if _cost(best) < _cost(members) * REASSIGN_GAIN:
			_assign(best)


func _assign(order: Array[AIBrain]) -> void:
	members = order
	for slot in members.size():
		members[slot].formation = self
		members[slot].formation_slot = slot


## Dónde está ahora mismo el puesto `slot`.
func point(slot: int) -> Vector3:
	if slot < 0 or slot >= _points.size():
		return leader.global_position
	return _points[slot]


func _forward() -> Vector3:
	var forward: Vector3 = -leader.global_transform.basis.z
	forward.y = 0.0
	return forward.normalized() if forward.length() > 0.001 else Vector3.FORWARD


func _place(check: bool) -> void:
	var origin: Vector3 = leader.global_position
	origin.y = 0.0
	var right: Vector3 = heading.cross(Vector3.UP)
	for i in _slots.size():
		var ideal: Vector3 = origin + right * _slots[i].x - heading * _slots[i].y
		if check:
			_shift[i] = _free_spot(ideal, i, origin) - ideal
		_points[i] = ideal + _shift[i]


## El propio puesto si está dentro del campo, libre y separado de los ya colocados; si no, el
## hueco libre más cercano que lo cumpla.
func _free_spot(ideal: Vector3, index: int, origin: Vector3) -> Vector3:
	var spot := Vector3(clampf(ideal.x, -field_limit, field_limit), 0.0, clampf(ideal.z, -field_limit, field_limit))
	if _grid == null:
		_grid = NavGrid.of(leader.get_parent())
	if not _grid.ready_once:
		return spot
	var accept: Callable = func(candidate: Vector3) -> bool:
		if candidate.distance_to(origin) < LEADER_GAP or absf(candidate.x) > field_limit or absf(candidate.z) > field_limit:
			return false
		for other in index:
			if candidate.distance_to(_points[other]) < MIN_GAP:
				return false
		return true
	if _grid.is_free_at(spot) and accept.call(spot):
		return spot
	var moved: Vector3 = _grid.free_point_near(spot, accept)
	return moved if moved != Vector3.INF else spot


## Reparto de puestos con el menor camino: primero cada puesto se queda con el tanque que tiene
## más cerca y después se cambian de puesto las parejas a las que les sale a cuenta.
func _best_order(brains: Array[AIBrain]) -> Array[AIBrain]:
	var left: Array[AIBrain] = []
	left.assign(brains)
	var order: Array[AIBrain] = []
	for slot in _points.size():
		if left.is_empty():
			break
		var pick: int = 0
		var best: float = INF
		for k in left.size():
			var gap: float = _gap(left[k], slot)
			if gap < best:
				best = gap
				pick = k
		order.append(left[pick])
		left.remove_at(pick)
	var improved: bool = true
	var rounds: int = 0
	while improved and rounds < 6:
		improved = false
		rounds += 1
		for a in order.size():
			for b in range(a + 1, order.size()):
				if _gap(order[a], b) + _gap(order[b], a) + 0.01 < _gap(order[a], a) + _gap(order[b], b):
					var swap: AIBrain = order[a]
					order[a] = order[b]
					order[b] = swap
					improved = true
	return order


func _cost(order: Array[AIBrain]) -> float:
	var total: float = 0.0
	for slot in order.size():
		total += _gap(order[slot], slot)
	return total


## Cuadrado de la distancia en planta de un tanque a un puesto.
func _gap(brain: AIBrain, slot: int) -> float:
	var at: Vector3 = brain.tank.global_position
	return Vector2(at.x - _points[slot].x, at.z - _points[slot].z).length_squared()
