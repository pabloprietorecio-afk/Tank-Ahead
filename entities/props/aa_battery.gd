class_name AaBattery
extends Node3D
## Batería antiaérea ligera en su pozo de sacos terreros: un cañón automático de 20-25 mm de
## la época (Flak 38 alemán, Oerlikon aliado, 72-K soviético) que el jugador maneja entre
## oleadas para derribar aviones. Tiene su propia cámara, a la altura del apuntador; al tomar
## el puesto la vista vuela desde el tanque hasta ella, y al dejarlo vuelve.
##
## Se apunta con el mismo mando que la torreta y dispara a ráfaga mientras se mantiene el
## gatillo. Los proyectiles son los del juego (trazadoras y espoleta de proximidad contra
## aviones) y cuentan como disparos del tanque del jugador.

const NAMES := {"DE": "FLAK 38 DE 2 cm", "IT": "FLAK 38 DE 2 cm", "SU": "72-K DE 25 mm", "UK": "OERLIKON DE 20 mm", "US": "OERLIKON DE 20 mm"}
const PAINT := {"DE": Color(0.36, 0.37, 0.36), "IT": Color(0.36, 0.37, 0.36), "SU": Color(0.2, 0.3, 0.18), "UK": Color(0.33, 0.36, 0.24), "US": Color(0.3, 0.33, 0.2)}
const SHELL := preload("res://entities/projectiles/shell.tscn")
## Segundos entre disparos, velocidad del proyectil (m/s) y daño de cada uno.
const FIRE_INTERVAL: float = 0.13
const SHELL_SPEED: float = 330.0
const DAMAGE: float = 12.0
const SPREAD: float = 0.006
const MIN_PITCH: float = deg_to_rad(-3.0)
const MAX_PITCH: float = deg_to_rad(86.0)
const TURN_SPEED: float = 2.6
## Giro y elevación (rad/s) con la palanca a fondo.
const LEVER_YAW: float = 1.7
const LEVER_PITCH: float = 1.1
## Opacidad del cañón visto desde el puesto del apuntador: queda como un cristal para que no
## tape el cielo.
const GHOST_ALPHA: float = 0.22
## Segundos que tarda la vista en ir del tanque a la batería y en volver.
const MOVE_IN: float = 1.3
const MOVE_OUT: float = 0.9
const RADIUS: float = 4.4

## La batería que maneja ahora el jugador (null si ninguna): la consultan los mandos y el HUD.
static var active: AaBattery

var gunner: Tank
var gun_name: String = ""
var trigger: bool = false
var camera: Camera3D
var shots: int = 0

var _yaw_node: Node3D
var _pitch_node: Node3D
var _barrel: Node3D
var _eye: Marker3D
var _muzzle: Marker3D
var _yaw: float = 0.0
var _pitch: float = 0.35
var _aim_yaw: float = 0.0
var _aim_pitch: float = 0.35
var _cooldown: float = 0.0
var _recoil: float = 0.0
var _fire_loop: AudioStreamPlayer3D
var _firing: bool = false
## Vuelo de la cámara: de dónde viene, cuánto lleva y si va (1) o vuelve (-1).
var _from: Transform3D
var _from_fov: float = 60.0
var _blend: float = 0.0
var _moving: int = 0
var _back_to: Camera3D
var _ghost: StandardMaterial3D
var _solid: Dictionary = {}


static func make(nation: String) -> AaBattery:
	var battery := AaBattery.new()
	battery.gun_name = NAMES.get(nation, NAMES["US"])
	battery._build(PAINT.get(nation, PAINT["US"]))
	return battery


func _build(paint: Color) -> void:
	# Pozo de sacos terreros: dos hiladas en corro, con una entrada por detrás.
	var bag := Color(0.62, 0.55, 0.4)
	for row in 2:
		for i in 13:
			var angle: float = TAU * (i + row * 0.5) / 14.0 + 0.25
			var sack := VectorMaterials.make_box(Vector3(1.75, 0.46, 0.85), bag.darkened(0.06 * ((i + row) % 3)), 10, 0.9)
			sack.position = Vector3(sin(angle) * 3.7, 0.23 + row * 0.45, cos(angle) * 3.7)
			sack.rotation.y = angle
			add_child(sack)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var ring := CylinderShape3D.new()
	ring.radius = RADIUS
	ring.height = 1.6
	shape.shape = ring
	shape.position.y = 0.8
	body.add_child(shape)
	add_child(body)
	# Afuste: cruz de apoyo, pivote y plataforma que gira con el cañón.
	var dark: Color = paint.darkened(0.35)
	for turn: float in [0.0, PI * 0.5]:
		var leg := VectorMaterials.make_box(Vector3(3.4, 0.16, 0.34), dark, 0, 2.0)
		leg.position.y = 0.1
		leg.rotation.y = turn + PI * 0.25
		add_child(leg)
	_add_tube(self, 0.3, 0.55, Vector3(0.0, 0.2, 0.0), dark)
	_yaw_node = Node3D.new()
	_yaw_node.position.y = 0.75
	add_child(_yaw_node)
	_add_tube(_yaw_node, 0.95, 0.08, Vector3(0.0, 0.0, 0.0), paint)
	for side: float in [-1.0, 1.0]:
		# Gualderas que sostienen la cuna y asientos de los sirvientes.
		var cheek := VectorMaterials.make_box(Vector3(0.08, 0.8, 0.7), paint, 0, 2.0)
		cheek.position = Vector3(0.36 * side, 0.45, 0.0)
		_yaw_node.add_child(cheek)
		var seat := VectorMaterials.make_box(Vector3(0.34, 0.06, 0.34), dark, 0, 2.0)
		seat.position = Vector3(0.7 * side, 0.32, 0.75)
		_yaw_node.add_child(seat)
		var back := VectorMaterials.make_box(Vector3(0.34, 0.3, 0.05), dark, 0, 2.0)
		back.position = Vector3(0.7 * side, 0.5, 0.92)
		_yaw_node.add_child(back)
	# Escudo partido a los lados del cañón.
	for side: float in [-1.0, 1.0]:
		var plate := VectorMaterials.make_box(Vector3(0.62, 0.95, 0.04), paint, 0, 2.0)
		plate.position = Vector3(0.52 * side, 0.72, -0.42)
		plate.rotation.x = -0.18
		_yaw_node.add_child(plate)
	_pitch_node = Node3D.new()
	_pitch_node.position = Vector3(0.0, 0.78, 0.0)
	_yaw_node.add_child(_pitch_node)
	# Cuna con el cajón de mecanismos y el cargador encima.
	var cradle := VectorMaterials.make_box(Vector3(0.3, 0.26, 1.15), paint, 0, 2.0)
	cradle.position = Vector3(0.0, 0.0, 0.1)
	_pitch_node.add_child(cradle)
	var magazine := VectorMaterials.make_box(Vector3(0.1, 0.34, 0.36), dark, 0, 2.0)
	magazine.position = Vector3(0.2, 0.06, 0.1)
	_pitch_node.add_child(magazine)
	_barrel = Node3D.new()
	_pitch_node.add_child(_barrel)
	var tube := _add_tube(_barrel, 0.045, 1.9, Vector3(0.0, 0.0, -1.4), dark)
	tube.rotation.x = PI * 0.5
	var sleeve := _add_tube(_barrel, 0.075, 0.6, Vector3(0.0, 0.0, -0.75), paint)
	sleeve.rotation.x = PI * 0.5
	# Apagallamas cónico en la boca.
	var hider := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.085
	cone.bottom_radius = 0.045
	cone.height = 0.24
	cone.radial_segments = 8
	hider.mesh = cone
	hider.material_override = VectorMaterials.flat(dark.darkened(0.3))
	hider.rotation.x = -PI * 0.5
	hider.position = Vector3(0.0, 0.0, -2.42)
	_barrel.add_child(hider)
	# Mira de anillos, delante del apuntador.
	var sight := MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.085
	ring_mesh.outer_radius = 0.095
	ring_mesh.rings = 20
	ring_mesh.ring_segments = 4
	sight.mesh = ring_mesh
	sight.material_override = VectorMaterials.flat(Color(0.05, 0.05, 0.05))
	sight.rotation.x = PI * 0.5
	sight.position = Vector3(0.0, 0.34, -0.5)
	_pitch_node.add_child(sight)
	_muzzle = Marker3D.new()
	_muzzle.position = Vector3(0.0, 0.0, -2.6)
	_pitch_node.add_child(_muzzle)
	# El ojo del apuntador: detrás del cajón, un poco por encima del eje del cañón.
	_eye = Marker3D.new()
	_eye.position = Vector3(0.0, 0.34, 1.05)
	_pitch_node.add_child(_eye)
	camera = Camera3D.new()
	camera.top_level = true
	camera.near = 0.12
	camera.far = 2800.0
	camera.fov = 62.0
	camera.cull_mask = 1 | Tank.VISUAL_LAYER_OWN
	add_child(camera)
	_fire_loop = AudioStreamPlayer3D.new()
	_fire_loop.stream = Sfx.AA_FIRE
	_fire_loop.bus = AudioSetup.SFX
	_fire_loop.unit_size = 30.0
	_fire_loop.max_distance = 600.0
	_fire_loop.volume_db = 2.0
	_pitch_node.add_child(_fire_loop)
	_apply_aim()


func _add_tube(parent: Node3D, radius: float, height: float, at: Vector3, color: Color) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.top_radius = radius
	shape.bottom_radius = radius
	shape.height = height
	shape.radial_segments = 10
	shape.rings = 1
	var mesh := MeshInstance3D.new()
	mesh.mesh = shape
	mesh.material_override = VectorMaterials.flat(color)
	mesh.position = at + Vector3(0.0, height * 0.5 if parent != _barrel else 0.0, 0.0)
	parent.add_child(mesh)
	return mesh


func _exit_tree() -> void:
	if active == self:
		active = null


## El jugador toma el puesto: la vista vuela desde `from` (la cámara del tanque) hasta la del
## apuntador, con el cañón mirando hacia `toward`.
func man(player: Tank, from: Camera3D, toward: Vector3) -> void:
	gunner = player
	_back_to = from
	_from = from.global_transform
	_from_fov = from.fov
	var flat := Vector2(toward.x - global_position.x, toward.z - global_position.z)
	if flat.length() > 1.0:
		_aim_yaw = atan2(-flat.x, -flat.y)
	_yaw = _aim_yaw
	_aim_pitch = 0.42
	_pitch = _aim_pitch
	_apply_aim()
	_blend = 0.0
	_moving = 1
	camera.global_transform = _from
	camera.fov = _from_fov
	camera.current = true
	active = self
	trigger = false


## El jugador deja el puesto: la vista vuelve a la cámara del tanque.
func leave() -> void:
	if active != self:
		return
	trigger = false
	_stop_fire()
	_set_ghost(false)
	_moving = -1
	_blend = 1.0


## Desde el puesto del apuntador el cañón (todo lo que gira con él) se ve translúcido; desde
## fuera, macizo.
func _set_ghost(on: bool) -> void:
	if _ghost == null:
		_ghost = StandardMaterial3D.new()
		_ghost.albedo_color = Color(0.82, 0.86, 0.8, GHOST_ALPHA)
		_ghost.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_ghost.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_ghost.cull_mode = BaseMaterial3D.CULL_BACK
	for node: Node in _yaw_node.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if on:
			if not _solid.has(mesh):
				_solid[mesh] = mesh.material_override
			mesh.material_override = _ghost
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		elif _solid.has(mesh):
			mesh.material_override = _solid[mesh]
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


## Mueve la mira (radianes): la llaman los mandos del jugador.
func aim(delta_yaw: float, delta_pitch: float) -> void:
	_aim_yaw = wrapf(_aim_yaw + delta_yaw, -PI, PI)
	_aim_pitch = clampf(_aim_pitch + delta_pitch, MIN_PITCH, MAX_PITCH)


## Punto al que apunta el cañón a `reach` metros (para la retícula del HUD).
func aim_point(reach: float = 300.0) -> Vector3:
	return _muzzle.global_position - _pitch_node.global_transform.basis.z * reach


func ready() -> bool:
	return active == self and _moving == 0


## `_yaw` es el rumbo del cañón en el mundo: se le descuenta el giro con que está puesto el pozo.
func _apply_aim() -> void:
	_yaw_node.rotation.y = _yaw - rotation.y
	_pitch_node.rotation.x = _pitch


func _process(delta: float) -> void:
	# El cañón sigue a la mira con la rapidez de sus volantes.
	_yaw = rotate_toward(_yaw, _aim_yaw, TURN_SPEED * delta)
	_pitch = move_toward(_pitch, _aim_pitch, TURN_SPEED * delta)
	_apply_aim()
	_recoil = move_toward(_recoil, 0.0, delta * 1.6)
	_barrel.position.z = _recoil
	if active != self:
		return
	var eye: Transform3D = _eye.global_transform
	if _moving != 0:
		_blend = clampf(_blend + delta * (1.0 / MOVE_IN if _moving > 0 else -1.0 / MOVE_OUT), 0.0, 1.0)
		if _moving < 0 and is_instance_valid(_back_to):
			_from = _back_to.global_transform
			_from_fov = _back_to.fov
		var weight: float = _blend * _blend * (3.0 - 2.0 * _blend)
		var pose: Transform3D = _from.interpolate_with(eye, weight)
		# El vuelo sube un poco por el camino, para pasar por encima de lo que haya.
		pose.origin.y += sin(weight * PI) * 9.0
		camera.global_transform = pose
		camera.fov = lerpf(_from_fov, 62.0, weight)
		if _moving > 0 and _blend >= 1.0:
			_moving = 0
			_set_ghost(true)
		elif _moving < 0 and _blend <= 0.0:
			_moving = 0
			active = null
			if is_instance_valid(_back_to):
				_back_to.current = true
			camera.current = false
		return
	camera.global_transform = eye
	_cooldown -= delta
	if trigger:
		if not _firing:
			_firing = true
			_fire_loop.play()
		while _cooldown <= 0.0:
			_cooldown += FIRE_INTERVAL
			_fire()
	else:
		_cooldown = maxf(_cooldown, 0.0)
		_stop_fire()


func _stop_fire() -> void:
	if not _firing:
		return
	_firing = false
	_fire_loop.stop()
	Sfx.play_at(self, Sfx.AA_TAIL, _muzzle.global_position, 2.0, 1.0)


func _fire() -> void:
	var from: Vector3 = _muzzle.global_position
	var forward: Vector3 = -_pitch_node.global_transform.basis.z
	var side: Vector3 = _pitch_node.global_transform.basis.x
	var up: Vector3 = _pitch_node.global_transform.basis.y
	var direction: Vector3 = (forward + side * randf_range(-SPREAD, SPREAD) + up * randf_range(-SPREAD, SPREAD)).normalized()
	var scene: Node = get_tree().current_scene
	var shell: Projectile = Projectile.acquire(SHELL, scene if scene != null else get_tree().root)
	shell.launch(from, direction * SHELL_SPEED, DAMAGE, gunner, [], GameMode.PLAYER_TEAM)
	Fx.on(self).pop(from, 0.55)
	_recoil = 0.14
	shots += 1
