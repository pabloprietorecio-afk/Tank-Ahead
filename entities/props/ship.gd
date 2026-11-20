class_name Ship
extends Destructible
## Barco pequeño en la rada: un transporte costero o una cañonera. Se le dispara como a
## cualquier objetivo; cuando zarpa sigue su derrota hacia mar abierto y, si llega al final,
## escapa. Al destruirlo arde, se escora y se hunde de popa. La cañonera responde con su
## cañón automático cuando tiene al jugador a tiro.

signal escaped(ship: Ship)

enum Kind { TRANSPORT, GUNBOAT }

const HULL_DARK := Color(0.14, 0.15, 0.17)
const HULL_RED := Color(0.38, 0.12, 0.1)
const GREY := Color(0.44, 0.47, 0.5)
const WHITE := Color(0.78, 0.78, 0.74)
const WOOD := Color(0.42, 0.32, 0.2)
const SINK_TIME: float = 17.0
## Cañón automático de la cañonera: alcance (m), segundos entre ráfagas y disparos por ráfaga.
const GUN_RANGE: float = 300.0
const GUN_PAUSE: float = 3.6
const GUN_BURST: int = 5
const GUN_DAMAGE: float = 3.0
const SHELL := preload("res://entities/projectiles/shell.tscn")

var kind: int = Kind.TRANSPORT
## Derrota: puntos (x, z) por los que pasa hasta salir a mar abierto.
var course: PackedVector2Array = PackedVector2Array()
var speed: float = 3.0
var sailing: bool = false
## A quién dispara la cañonera.
var target: Tank
var has_escaped: bool = false

var _model: Node3D
var _wake: MeshInstance3D
var _leg: int = 0
var _leg_from: Vector2 = Vector2.INF
var _clock: float = 0.0
var _sink: float = -1.0
var _list_side: float = 1.0
var _smoke_due: float = 0.0
var _gun_wait: float = 2.0
var _burst_left: int = 0
var _burst_due: float = 0.0
var _muzzle: Vector3
var _length: float = 38.0


static func make(ship_kind: int) -> Ship:
	var ship := Ship.new()
	ship.kind = ship_kind
	ship._build()
	return ship


func _build() -> void:
	_model = Node3D.new()
	add_child(_model)
	debris_color = Color(0.4, 0.42, 0.45)
	if kind == Kind.GUNBOAT:
		_length = 46.0
		max_health = 240.0
		size_hint = 7.0
		_piece(Vector3(46.0, 3.4, 6.6), Vector3(0.0, -0.9, 0.0), GREY.darkened(0.12))
		_piece(Vector3(5.0, 3.0, 4.4), Vector3(25.0, -0.7, 0.0), GREY.darkened(0.12))
		_piece(Vector3(13.0, 2.6, 5.0), Vector3(-2.0, 2.5, 0.0), GREY)
		_piece(Vector3(5.0, 2.2, 4.2), Vector3(1.5, 5.1, 0.0), GREY.lightened(0.06))
		_tube(1.0, 3.6, Vector3(-5.0, 5.1, 0.0), GREY.darkened(0.25))
		_piece(Vector3(0.3, 9.0, 0.3), Vector3(2.5, 7.3, 0.0), HULL_DARK)
		# Cañón de proa y montaje automático a popa.
		_piece(Vector3(2.6, 1.5, 2.6), Vector3(13.0, 2.5, 0.0), GREY.darkened(0.2))
		_piece(Vector3(4.6, 0.36, 0.36), Vector3(16.0, 3.2, 0.0), HULL_DARK)
		_piece(Vector3(2.0, 1.2, 2.0), Vector3(-14.0, 2.5, 0.0), GREY.darkened(0.2))
		_piece(Vector3(2.4, 0.3, 0.9), Vector3(-15.4, 3.4, 0.0), HULL_DARK)
		_muzzle = Vector3(-15.0, 3.8, 0.0)
		_hit_box(Vector3(50.0, 5.0, 6.8), Vector3(1.0, 0.0, 0.0))
		_hit_box(Vector3(14.0, 5.0, 5.0), Vector3(-1.0, 4.8, 0.0))
	else:
		_length = 38.0
		max_health = 150.0
		size_hint = 6.0
		_piece(Vector3(36.0, 4.4, 7.4), Vector3(0.0, -1.2, 0.0), HULL_DARK)
		_piece(Vector3(36.2, 1.0, 7.5), Vector3(0.0, -1.3, 0.0), HULL_RED)
		_piece(Vector3(4.0, 3.8, 5.0), Vector3(19.6, -0.8, 0.0), HULL_DARK)
		# Bodega con su escotilla y los puntales de carga; puente y chimenea a popa.
		_piece(Vector3(11.0, 0.7, 4.6), Vector3(4.0, 3.2, 0.0), WOOD)
		_piece(Vector3(0.35, 8.0, 0.35), Vector3(11.5, 3.2, 0.0), WOOD.darkened(0.3))
		_piece(Vector3(8.0, 0.25, 0.25), Vector3(8.0, 8.4, 0.0), WOOD.darkened(0.3))
		_piece(Vector3(8.0, 3.0, 6.0), Vector3(-11.0, 3.2, 0.0), WHITE)
		_piece(Vector3(4.6, 2.2, 4.6), Vector3(-10.0, 6.2, 0.0), WHITE.darkened(0.06))
		_tube(1.2, 4.4, Vector3(-13.5, 6.2, 0.0), HULL_DARK)
		_tube(1.25, 0.9, Vector3(-13.5, 8.6, 0.0), HULL_RED)
		_hit_box(Vector3(40.0, 5.6, 7.6), Vector3(1.0, 0.0, 0.0))
		_hit_box(Vector3(9.0, 5.4, 6.2), Vector3(-11.0, 5.4, 0.0))
	# Estela: una lengua de espuma a popa que solo se ve cuando navega.
	var foam := PlaneMesh.new()
	foam.size = Vector2(_length * 0.9, 5.0)
	var foam_mat := StandardMaterial3D.new()
	foam_mat.albedo_color = Color(0.9, 0.95, 0.96, 0.45)
	foam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	foam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_wake = MeshInstance3D.new()
	_wake.mesh = foam
	_wake.material_override = foam_mat
	_wake.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_wake.position = Vector3(-_length * 0.85, 0.12, 0.0)
	_wake.visible = false
	add_child(_wake)
	_list_side = 1.0 if randf() < 0.5 else -1.0


func _piece(size: Vector3, base: Vector3, color: Color) -> void:
	var mesh := VectorMaterials.make_box(size, color, 0, 2.0)
	mesh.position = base + Vector3(0.0, size.y * 0.5, 0.0)
	_model.add_child(mesh)


func _tube(radius: float, height: float, base: Vector3, color: Color) -> void:
	var shape := CylinderMesh.new()
	shape.top_radius = radius
	shape.bottom_radius = radius
	shape.height = height
	shape.radial_segments = 10
	shape.rings = 1
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	var mesh := MeshInstance3D.new()
	mesh.mesh = shape
	mesh.material_override = mat
	mesh.position = base + Vector3(0.0, height * 0.5, 0.0)
	_model.add_child(mesh)


func _hit_box(size: Vector3, base: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = base + Vector3(0.0, size.y * 0.5, 0.0)
	add_child(shape)


## Proa hacia `heading` (x, z). El modelo tiene la proa en +X.
func face(heading: Vector2) -> void:
	if heading.length_squared() > 0.0001:
		rotation.y = atan2(-heading.y, heading.x)


func _process(delta: float) -> void:
	_clock += delta
	if _sink >= 0.0:
		_go_down(delta)
		return
	# Cabeceo y balanceo de la mar.
	_model.position.y = sin(_clock * 0.9 + position.x * 0.05) * 0.12
	_model.rotation.x = sin(_clock * 0.7 + position.z * 0.03) * 0.025
	_model.rotation.z = sin(_clock * 0.55) * 0.012
	if sailing:
		_sail(delta)
	if kind == Kind.GUNBOAT:
		_shoot(delta)


func _sail(delta: float) -> void:
	_wake.visible = true
	if _leg >= course.size():
		sailing = false
		has_escaped = true
		collision_layer = 0
		remove_from_group(&"radar_marks")
		escaped.emit(self)
		queue_free()
		return
	var here := Vector2(position.x, position.z)
	if _leg_from == Vector2.INF:
		_leg_from = here
	var to: Vector2 = course[_leg] - here
	# Punto alcanzado: al llegar a él o al rebasarlo (vira despacio y puede pasar de largo).
	if to.length() < 6.0 or to.dot(course[_leg] - _leg_from) <= 0.0:
		_leg_from = course[_leg]
		_leg += 1
		return
	var heading: Vector2 = to.normalized()
	# Vira despacio hacia el rumbo.
	var bow := Vector2(cos(rotation.y), -sin(rotation.y))
	face(bow.slerp(heading, clampf(delta * 0.35, 0.0, 1.0)))
	bow = Vector2(cos(rotation.y), -sin(rotation.y))
	position += Vector3(bow.x, 0.0, bow.y) * speed * delta


## Ráfagas del cañón automático contra el jugador, con mucha dispersión: hostigan, no fulminan.
func _shoot(delta: float) -> void:
	if _burst_left > 0:
		_burst_due -= delta
		if _burst_due <= 0.0:
			_burst_due = 0.24
			_burst_left -= 1
			_fire()
		return
	_gun_wait -= delta
	if _gun_wait > 0.0:
		return
	_gun_wait = GUN_PAUSE * randf_range(0.8, 1.3)
	if is_instance_valid(target) and not target.is_destroyed and target.global_position.distance_to(global_position) < GUN_RANGE:
		_burst_left = GUN_BURST
		# Una ráfaga del cañón automático (dura lo que tardan en salir los disparos).
		Sfx.play_at(self, Sfx.AA_BURST, global_transform * _muzzle, 7.0, 1.0)


func _fire() -> void:
	if not is_instance_valid(target):
		return
	var from: Vector3 = global_transform * _muzzle
	var aim: Vector3 = target.global_position + Vector3.UP * 1.4 + Vector3(randf_range(-5.0, 5.0), randf_range(-1.0, 2.5), randf_range(-5.0, 5.0))
	var scene: Node = get_tree().current_scene
	var shell: Projectile = Projectile.acquire(SHELL, scene if scene != null else get_tree().root)
	shell.launch(from, (aim - from).normalized() * 190.0, GUN_DAMAGE, self, [], GameMode.ENEMY_TEAM)
	Fx.on(self).pop(from, 0.7)


func _destroy() -> void:
	is_destroyed = true
	refresh_highlight()
	collision_layer = 0
	sailing = false
	_wake.visible = false
	var center: Vector3 = global_position + Vector3.UP * 3.0
	Fx.on(self).fuel_blast(center, 2.2)
	Sfx.play_at(self, Sfx.EXPLOSION, center, 9.0, 0.75)
	destroyed.emit(self)
	remove_from_group(&"radar_marks")
	_sink = 0.0


## Arde, se escora y se va a pique de popa.
func _go_down(delta: float) -> void:
	_sink += delta
	var t: float = _sink / SINK_TIME
	var fx: Fx = Fx.on(self)
	_smoke_due += delta * lerpf(6.0, 2.0, t)
	while _smoke_due >= 1.0:
		_smoke_due -= 1.0
		var at: Vector3 = global_transform * Vector3(randf_range(-_length * 0.35, _length * 0.3), randf_range(2.0, 5.0), randf_range(-2.0, 2.0))
		fx.black_smoke(at, Vector3(randf_range(-0.6, 0.6), randf_range(4.0, 7.0), randf_range(-0.6, 0.6)), randf_range(3.5, 6.5), randf_range(5.0, 8.0))
		if t < 0.7:
			fx.flame(at, Vector3.ZERO, randf_range(2.5, 4.5), 1.2)
	var lean: float = smoothstep(0.0, 0.55, t)
	_model.rotation.x = _list_side * lean * 0.5
	_model.rotation.z = lean * 0.26
	_model.position.y = -smoothstep(0.25, 1.0, t) * 9.5
	if _sink >= SINK_TIME:
		# Lo último, un borbollón de espuma donde estaba.
		fx.shell_water(global_position, 2.2)
		Sfx.play_at(self, Sfx.SPLASH, global_position, 8.0, 0.8)
		queue_free()
