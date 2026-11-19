class_name TankMovement
extends Node
## Avance, retroceso y giro del casco. Lee `drive_input` del tanque (x = giro, y = avance).

const GRAVITY: float = 25.0
## Rapidez con la que el casco toma la inclinación del terreno (como una suspensión).
const TILT_SMOOTHING: float = 9.0

var _tank: Tank
## Está sobre una loma: la altura la pone el terreno (Terrain), no la gravedad.
var _lifted: bool = false
## Altura del cuerpo cuando descansa en el llano.
var _rest_y: float = 0.0
## Medias medidas del apoyo de las orugas (largo y ancho), para leer la pendiente.
var _half_length: float = 2.0
var _half_width: float = 1.4


func setup(tank: Tank) -> void:
	_tank = tank
	var k: float = tank.stats.body_scale
	_half_length = TankModel.HULL_SIZE.z * tank.stats.hull_proportions.z * k * 0.42
	_half_width = TankModel.HULL_SIZE.x * tank.stats.hull_proportions.x * k * 0.5


func _physics_process(delta: float) -> void:
	if _tank == null:
		return
	var stats: TankStats = _tank.stats
	_tank.rotate_y(-_tank.drive_input.x * stats.hull_turn_speed * delta)

	var forward: Vector3 = -_tank.global_transform.basis.z
	var current_speed: float = _tank.velocity.dot(forward)
	var target_speed: float = _tank.drive_input.y * stats.max_speed * _tank.speed_factor
	# Vadeando un arroyo o el vado de un río se va más despacio.
	target_speed *= Water.drag_at(_tank.global_position.x, _tank.global_position.z)
	current_speed = move_toward(current_speed, target_speed, stats.acceleration * delta)

	_tank.velocity.x = forward.x * current_speed
	_tank.velocity.z = forward.z * current_speed
	if _lifted or _tank.is_on_floor():
		_tank.velocity.y = 0.0
	else:
		_tank.velocity.y -= GRAVITY * delta
	_tank.move_and_slide()
	_settle(delta)
	for i in _tank.get_slide_collision_count():
		var collider: Object = _tank.get_slide_collision(i).get_collider()
		if collider is Destructible and collider.crushable and absf(current_speed) > 2.0:
			collider.crush(_tank)


## Posa el tanque en el relieve: sobre una loma lo sube a la altura del terreno e inclina el
## chasis con la pendiente; en el llano lo deja como siempre.
func _settle(delta: float) -> void:
	if Terrain.is_flat():
		return
	var pose: Transform3D = Terrain.rest(_tank.global_position, _tank.global_rotation.y, _half_length, _half_width)
	var tilt := Basis.IDENTITY
	_lifted = pose.origin.y > 0.002
	if _lifted:
		_tank.global_position.y = pose.origin.y + _rest_y
		# Inclinación respecto al cuerpo, que solo gira sobre sí mismo.
		tilt = _tank.global_basis.inverse() * pose.basis
	elif _tank.is_on_floor():
		_rest_y = _tank.global_position.y
	# Con cuaterniones sacados de bases ortonormalizadas, no con Basis.slerp: de tanto girar, la
	# base del cuerpo queda un pelo fuera de escala y Basis.slerp no la admite (en las
	# compilaciones de depuración da un error en ese fotograma y toma el giro por nulo).
	var from: Quaternion = _tank.chassis.basis.get_rotation_quaternion()
	var to: Quaternion = tilt.get_rotation_quaternion()
	_tank.chassis.basis = Basis(from.slerp(to, 1.0 - exp(-TILT_SMOOTHING * delta)))
