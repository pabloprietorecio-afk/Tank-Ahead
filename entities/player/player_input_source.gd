class_name PlayerInputSource
extends Node
## Traduce los controles táctiles en órdenes para el tanque.
## Incluye la ayuda de apuntado opcional.

const LOCK_CONE: float = deg_to_rad(5.0)
const LOCK_RANGE: float = 150.0
## Tras liberar un objetivo, segundos sin volver a fijar automáticamente.
const RELOCK_DELAY: float = 2.0
const WORLD_MASK: int = 1

@export var tank: Tank
@export var touch: TouchControls
## Radianes de giro por píxel arrastrado.
@export var look_sensitivity: float = 0.004

## Modo clásico: máximo desvío del cañón respecto al casco y su recentrado.
const FINE_AIM_LIMIT: float = PI
const FINE_RECENTER_DELAY: float = 2.0
const FINE_RECENTER_SPEED: float = 0.5
## Suavizado del giro del casco (unidades de joystick por segundo).
const TURN_SMOOTHING: float = 5.0

var _fine_yaw: float = 0.0
var _idle_time: float = 0.0
var _turn: float = 0.0
var _relock_cooldown: float = 0.0
## El objetivo lo ha fijado una orden de voz («localizar objetivo»): se mantiene aunque la ayuda
## de apuntado esté apagada, hasta que muere o se libera.
var _voice_lock: bool = false
## Alcance de «localizar objetivo» (más que el de la ayuda de apuntado).
const LOCATE_RANGE: float = 300.0
## Movimiento fácil: rumbo del cañón en el mundo que elige el jugador.
var _aim_world: float = NAN
## Fuerza con la que el casco se alinea con el cañón al avanzar.
const ALIGN_GAIN: float = 2.2


func _process(delta: float) -> void:
	if tank == null or touch == null or tank.is_destroyed:
		return
	if AaBattery.active != null:
		# En la batería antiaérea: el mismo mando mueve su mira y el gatillo es el suyo; el
		# tanque se queda quieto.
		var sweep: Vector2 = touch.consume_look_delta()
		tank.trigger_held = false
		tank.drive_input = Vector2.ZERO
		if AaBattery.active.ready():
			AaBattery.active.aim(-sweep.x * look_sensitivity, -sweep.y * look_sensitivity)
			AaBattery.active.trigger = touch.fire_held
		return
	var stick: Vector2 = touch.move_vector
	_turn = move_toward(_turn, stick.x, TURN_SMOOTHING * delta)
	stick.x = _turn
	tank.trigger_held = touch.fire_held

	var look: Vector2 = touch.consume_look_delta()
	# Con prismáticos, el dedo mueve la mira mucho más fino.
	if tank.binoculars:
		look *= Tank.ZOOM_FOV / Tank.NORMAL_FOV
	_relock_cooldown = maxf(_relock_cooldown - delta, 0.0)
	if GameSettings.aim_assist:
		_update_lock()
	elif tank.aim_lock != null:
		if not _voice_lock or not is_instance_valid(tank.aim_lock) or tank.aim_lock.is_destroyed:
			release_lock()
	if tank.aim_lock == null:
		_voice_lock = false
	# Un cazacarros de casamata apenas gira el cañón: se apunta siempre como en el movimiento
	# fácil (la mira manda) y es el casco el que gira para seguirla, también parado.
	var casemate: bool = tank.turret_controller.traverse_limit > 0.0
	var world_aim: bool = GameSettings.easy_drive or casemate
	if is_nan(_aim_world) or tank.aim_lock != null or not world_aim:
		_aim_world = tank.turret_controller.world_yaw
	if world_aim:
		stick.x = _easy_turn(touch.move_vector, casemate)
	tank.drive_input = stick

	if tank.aim_lock != null:
		tank.turret_controller.aim_at(_lock_point(tank.aim_lock))
	elif world_aim:
		_aim_world = wrapf(_aim_world - look.x * look_sensitivity, -PI, PI)
		tank.turret_controller.aim_world_yaw(_aim_world, -look.y * look_sensitivity)
	elif GameSettings.auto_recenter:
		_classic_aim(look, delta)
	elif look != Vector2.ZERO:
		tank.turret_controller.add_aim(-look.x * look_sensitivity, -look.y * look_sensitivity)
	else:
		tank.turret_controller.hold_relative()


## Orden de voz «localizar objetivo»: fija el enemigo a la vista más cercano (la torreta gira
## sola hacia él). Devuelve el tanque fijado, o null si no hay ninguno a la vista.
func lock_nearest() -> Tank:
	if tank == null or tank.is_destroyed:
		return null
	var best: Tank = null
	var best_distance: float = LOCATE_RANGE
	for node in get_tree().get_nodes_in_group(&"tanks"):
		var enemy: Tank = node as Tank
		if enemy == null or enemy.is_destroyed or not tank.is_hostile_to(enemy):
			continue
		var distance: float = tank.global_position.distance_to(enemy.global_position)
		if distance < best_distance and _in_sight(enemy):
			best_distance = distance
			best = enemy
	if best != null:
		tank.aim_lock = best
		_voice_lock = true
		_relock_cooldown = 0.0
	return best


func _in_sight(enemy: Tank) -> bool:
	var origin: Vector3 = tank.muzzle.global_position
	var query := PhysicsRayQueryParameters3D.create(origin, _lock_point(enemy), WORLD_MASK | Terrain.LAYER)
	return tank.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## Libera el objetivo fijado (botón LIBERAR del HUD).
func release_lock() -> void:
	_voice_lock = false
	if tank.aim_lock == null:
		return
	tank.aim_lock = null
	_relock_cooldown = RELOCK_DELAY
	_fine_yaw = clampf(tank.turret_controller.local_yaw, -FINE_AIM_LIMIT, FINE_AIM_LIMIT)
	_idle_time = 0.0


## Una vez fijado, el objetivo no se pierde hasta que muere o el jugador lo libera.
func _update_lock() -> void:
	var current: Tank = tank.aim_lock
	if current != null:
		if not is_instance_valid(current) or current.is_destroyed:
			tank.aim_lock = null
			_fine_yaw = clampf(tank.turret_controller.local_yaw, -FINE_AIM_LIMIT, FINE_AIM_LIMIT)
			_idle_time = 0.0
		return
	if _relock_cooldown > 0.0:
		return
	var origin: Vector3 = tank.muzzle.global_position
	var aim_dir: Vector3 = -tank.muzzle.global_transform.basis.z
	var best: Tank = null
	var best_angle: float = LOCK_CONE
	for node in get_tree().get_nodes_in_group(&"tanks"):
		var enemy: Tank = node as Tank
		if enemy == null or not tank.is_hostile_to(enemy) or not _lock_valid(enemy):
			continue
		var angle: float = aim_dir.angle_to(_lock_point(enemy) - origin)
		if angle < best_angle:
			best_angle = angle
			best = enemy
	if best != null:
		get_tree().call_group(&"voice", &"say", "locked", VoiceManager.Priority.LOW)
	tank.aim_lock = best


func _lock_valid(enemy: Tank) -> bool:
	if not is_instance_valid(enemy) or enemy.is_destroyed:
		return false
	var origin: Vector3 = tank.muzzle.global_position
	var point: Vector3 = _lock_point(enemy)
	if origin.distance_to(point) > LOCK_RANGE:
		return false
	var query := PhysicsRayQueryParameters3D.create(origin, point, WORLD_MASK | Terrain.LAYER)
	return tank.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _lock_point(enemy: Tank) -> Vector3:
	var point: Vector3 = enemy.global_position + Vector3.UP * 1.2 * enemy.stats.body_scale
	var travel: float = tank.global_position.distance_to(point) / maxf(tank.weapon.projectile_speed, 1.0)
	return point + enemy.velocity * travel


## Cañón fijo al casco; el arrastre solo permite un ajuste fino y se recentra al soltar.
func _classic_aim(look: Vector2, delta: float) -> void:
	if look != Vector2.ZERO:
		_idle_time = 0.0
		_fine_yaw = wrapf(_fine_yaw - look.x * look_sensitivity, -FINE_AIM_LIMIT, FINE_AIM_LIMIT)
		tank.turret_controller.aim_local(_fine_yaw, -look.y * look_sensitivity)
		return
	_idle_time += delta
	if _idle_time > FINE_RECENTER_DELAY:
		_fine_yaw = move_toward(_fine_yaw, 0.0, FINE_RECENTER_SPEED * delta)
	tank.turret_controller.aim_local(_fine_yaw)


## Movimiento fácil: si el jugador no gira a mano, el casco gira hacia donde apunta el cañón
## mientras el tanque avanza o retrocede, hasta quedar alineados. Con `casemate` (cañón casi
## fijo) el casco gira hacia donde se quiere apuntar, aunque el tanque esté parado.
func _easy_turn(raw: Vector2, casemate: bool = false) -> float:
	if absf(raw.x) > 0.35:
		# Giro manual: el cañón mantiene su rumbo en el mundo.
		return _turn
	if casemate:
		var off: float = angle_difference(tank.global_rotation.y, tank.turret_controller.desired_world_yaw())
		return 0.0 if absf(off) < deg_to_rad(1.5) else clampf(-off * ALIGN_GAIN, -1.0, 1.0)
	if absf(raw.y) < 0.1:
		return 0.0
	var diff: float = angle_difference(tank.global_rotation.y, tank.turret_controller.world_yaw)
	if absf(diff) < deg_to_rad(1.5):
		return 0.0
	return clampf(-diff * ALIGN_GAIN, -1.0, 1.0)
