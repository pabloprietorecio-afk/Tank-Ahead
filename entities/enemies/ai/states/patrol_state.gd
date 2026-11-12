class_name PatrolState
extends EnemyState
## Va hacia su orden (objetivo de la misión) o hacia el enemigo lejano si caza; si no, deambula.
## Con la orden «todos conmigo» ocupa su puesto en la formación del jugador y lo mantiene.

## Siguiendo al jugador: a esta distancia de su puesto se para (si el líder está parado)...
const STATION_ARRIVE: float = 3.0
## ...y no vuelve a arrancar hasta que el puesto se le va más lejos que esto.
const STATION_RESUME: float = 7.0
## Avance del líder (m/s) con el que se considera que la formación está en marcha.
const STATION_MARCH: float = 1.5
## Segundos de adelanto: conduce hacia donde va a estar su puesto, no hacia donde está.
const STATION_LOOKAHEAD: float = 1.0
## Si el puesto le queda detrás y a menos de esta distancia, recula en vez de dar media vuelta.
const REVERSE_REACH: float = 14.0
## Ángulos (rad) respecto al morro para empezar a recular y para dejar de hacerlo.
const REVERSE_FROM: float = 2.1
const REVERSE_UNTIL: float = 1.7

## El líder en marcha tiene preferencia: quien esté en su camino, a menos de estos segundos de
## que llegue (más un margen en metros), se aparta; y nadie se le cruza por delante. El camino
## es el ancho del líder más el largo de quien se aparta y este aire a cada lado (m).
const WAY_SPEED: float = 2.0
const WAY_TIME: float = 3.0
const WAY_MARGIN: float = 8.0
const WAY_CLEAR: float = 3.0

var _waypoint: Vector3
var _stuck: float = 0.0
## En su puesto y parado.
var _holding: bool = false
var _reversing: bool = false
var _scan: float = 0.0


func enter(_previous: StringName) -> void:
	_pick()
	_stuck = 0.0
	_holding = false
	_reversing = false


func _pick() -> void:
	if brain.objective == Vector3.INF and brain.hunt and brain.has_target():
		_waypoint = brain.target.global_position
	else:
		_waypoint = brain.patrol_point()


func exit() -> void:
	brain.tank.trigger_held = false


func update(delta: float) -> void:
	if brain.follow != null:
		_keep_station(delta)
		return
	if brain.focus_objective and brain.objective != Vector3.INF:
		# La orden es lo primero: a toda marcha hasta el punto exacto, disparando sobre la marcha.
		_stuck += delta
		if fmod(_stuck, 1.0) < delta:
			_waypoint = brain.patrol_point()
		brain.drive_to(_waypoint, 1.0, 1.5)
		if not brain.fire_on_the_move(delta):
			brain.tank.turret_controller.aim_yaw(brain.tank.global_rotation.y)
		return
	if brain.perception.can_see:
		machine.change_to(&"Chase")
		return
	_stuck += delta
	if fmod(_stuck, 3.0) < delta:
		_pick()
	var arrived: bool = brain.drive_to(_waypoint, 0.7, 6.0)
	brain.tank.turret_controller.aim_yaw(brain.tank.global_rotation.y)
	if arrived or _stuck > 20.0:
		machine.change_to(&"Idle")


## «Todos conmigo»: va a su puesto de la formación y lo mantiene. En marcha acompasa su
## velocidad a la del líder; con el líder parado se detiene en su puesto, encarado como la
## formación, y no vuelve a moverse hasta que el puesto se aleja (así no anda removiéndose).
## Lejos de su puesto va derecho a él sin entretenerse; cerca, si ve a un enemigo, sale a por él.
func _keep_station(delta: float) -> void:
	var tank: Tank = brain.tank
	var leader: Tank = brain.follow
	if not brain.follow_far and brain.perception.can_see:
		machine.change_to(&"Chase")
		return
	var slot: Vector3 = brain.follow_point()
	var lead_velocity := Vector3(leader.velocity.x, 0.0, leader.velocity.z)
	var marching: bool = lead_velocity.length() > STATION_MARCH
	var gap: float = Vector2(slot.x - tank.global_position.x, slot.z - tank.global_position.z).length()
	if _holding:
		if marching or gap > STATION_RESUME:
			_holding = false
	elif not marching and gap <= STATION_ARRIVE:
		_holding = true
	var heading: Vector3 = brain.follow_heading()
	var goal: Vector3 = slot + lead_velocity * STATION_LOOKAHEAD
	# Dónde está respecto al camino del líder: [metros por delante de él, metros a su derecha].
	var lane: float = _lane(leader)
	var ahead: Vector2 = _ahead_of(leader, lead_velocity, tank.global_position)
	var in_the_way: bool = ahead.x >= 0.0 and absf(ahead.y) <= lane
	if in_the_way:
		_holding = false
		_reversing = false
		_make_way(lead_velocity, ahead.y)
	elif _holding:
		_reversing = false
		# Parado en su puesto: se encara como la formación, listo para arrancar con ella.
		brain.face(tank.global_position + heading * 30.0, 0.2)
	elif ahead.x >= 0.0 and _crosses(_ahead_of(leader, lead_velocity, goal).y, ahead.y, lane):
		# Su sitio queda al otro lado del camino del líder: espera a que pase, no se le cruza.
		_reversing = false
		brain.stop()
	else:
		var top: float = maxf(tank.stats.max_speed * tank.speed_factor, 0.1)
		# La velocidad del líder más lo que haga falta para recortar el retraso.
		var speed: float = 1.0 if brain.follow_far else clampf(lead_velocity.length() / top + (gap - 2.0) / 12.0, 0.35, 1.0)
		if not _reverse_to(goal, speed):
			brain.drive_to(goal, speed * brain.crowding_brake(), 1.0)
	if not brain.fire_on_the_move(delta):
		# Sin nadie a tiro, el cañón barre el frente de la formación.
		_scan += delta
		tank.turret_controller.aim_yaw(atan2(-heading.x, -heading.z) + sin(_scan * 0.7) * 0.5)


## Si el destino queda detrás y cerca, y no hay nada en medio, recula hacia él en vez de dar
## media vuelta. Devuelve si lo está haciendo.
func _reverse_to(goal: Vector3, speed: float) -> bool:
	var tank: Tank = brain.tank
	var to: Vector3 = goal - tank.global_position
	to.y = 0.0
	var distance: float = to.length()
	if brain.follow_far or distance < 1.0 or distance > REVERSE_REACH:
		_reversing = false
		return false
	var forward: Vector3 = -tank.global_transform.basis.z
	var off: float = absf(forward.signed_angle_to(to, Vector3.UP))
	if off < (REVERSE_UNTIL if _reversing else REVERSE_FROM) or not brain.is_clear(to / distance, distance):
		_reversing = false
		return false
	_reversing = true
	# La cola hacia el destino: el giro que alinea la trasera, no el morro.
	var tail: float = (-forward).signed_angle_to(to, Vector3.UP)
	tank.drive_input = Vector2(clampf(-tail * 2.0, -1.0, 1.0), -clampf(speed, 0.35, 0.8))
	return true


## Media anchura del camino del líder para este tanque: medio ancho del líder, medio largo
## propio (por si está atravesado) y el aire que se deja.
func _lane(leader: Tank) -> float:
	var own: TankStats = brain.tank.stats
	var lead: TankStats = leader.stats
	return TankModel.HULL_SIZE.x * lead.hull_proportions.x * lead.body_scale * 0.5 + TankModel.HULL_SIZE.z * own.hull_proportions.z * own.body_scale * 0.5 + WAY_CLEAR


## Posición de `point` respecto al avance del líder: x = metros por delante de él (negativo si
## el líder va despacio, si ya lo ha dejado atrás o si aún le queda lejos) e y = metros a su derecha.
func _ahead_of(leader: Tank, lead_velocity: Vector3, point: Vector3) -> Vector2:
	var speed: float = lead_velocity.length()
	if speed < WAY_SPEED:
		return Vector2(-1.0, 0.0)
	var dir: Vector3 = lead_velocity / speed
	var offset: Vector3 = point - leader.global_position
	offset.y = 0.0
	var along: float = offset.dot(dir)
	if along > speed * WAY_TIME + WAY_MARGIN:
		along = -1.0
	return Vector2(along, offset.dot(dir.cross(Vector3.UP)))


## ¿Hay que cruzar el camino del líder para ir de un lado (`from_side`) a un destino (`to_side`)?
func _crosses(to_side: float, from_side: float, lane: float) -> bool:
	return absf(to_side) < lane or to_side * from_side < 0.0


## El líder viene derecho hacia él: se aparta de su camino por el lado en el que ya está, sin
## esperar a que le empuje. Si el casco apunta de lado le basta con avanzar o recular; si está
## en línea con el líder, sale girando. `side` son los metros a los que está a la derecha del
## camino del líder.
func _make_way(lead_velocity: Vector3, side: float) -> void:
	var tank: Tank = brain.tank
	var across: Vector3 = lead_velocity.normalized().cross(Vector3.UP)
	var forward: Vector3 = -tank.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	# Cuánto de su propio avance le saca hacia la derecha del líder.
	var sideways: float = forward.dot(across)
	var out: float = signf(side) if absf(side) > 1.0 else (signf(sideways) if absf(sideways) > 0.05 else 1.0)
	var gear: float = 1.0 if sideways * out >= 0.0 else -1.0
	if absf(sideways) >= 0.35 and brain.is_clear(forward * gear, 3.0):
		# Corrige el rumbo hacia fuera mientras sale (el giro que mueve el morro mueve también la cola).
		var steer: float = (forward * gear).signed_angle_to(across * out, Vector3.UP)
		tank.drive_input = Vector2(clampf(-steer * 1.5, -1.0, 1.0), gear)
	else:
		brain.drive_to(tank.global_position + across * out * 12.0 + forward * 8.0, 1.0, 0.5)
