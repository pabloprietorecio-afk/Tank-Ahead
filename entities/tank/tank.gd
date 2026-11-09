class_name Tank
extends CharacterBody3D
## Tanque. Jugador, aliados y enemigos usan esta misma clase; solo cambia quién da las órdenes.
## El modelo lo construye TankModel a partir de la ficha (TankStats) y de la pintura del frente.

const LAYER_WORLD: int = 1
const LAYER_TANK: int = 2
const LAYER_HURTBOX: int = 4
## Capa visual de las piezas del propio jugador (la cámara en primera persona no las ve).
const VISUAL_LAYER_OWN: int = 2
## Distancia hacia atrás y altura de las vistas exteriores [cerca, lejos].
const CHASE_OFFSETS: Array[Vector2] = [Vector2(10.0, 4.5), Vector2(20.0, 9.0)]
const WRECK_TIME: float = 8.0

signal destroyed(tank: Tank, killer: Node)
signal damaged(amount: float, source: Node)

@export var stats: TankStats
@export var is_player: bool = false
## Equipo: 0 = el del jugador, 1 = el contrario.
@export var team: int = 0
## Pintura: {"base": Color, "mode": int, "a": Color, "b": Color} (ver TankModel).
var paint: Dictionary = {}

## Órdenes (las rellena PlayerInputSource o la IA).
var drive_input: Vector2 = Vector2.ZERO
var trigger_held: bool = false

var turret: Node3D
var gun_pivot: Node3D
var muzzle: Marker3D
var camera: Camera3D
var hurtbox: Hurtbox
var health: HealthComponent
var weapon: TankWeapon
var turret_controller: TurretController
var is_destroyed: bool = false
## Enemigo fijado por la ayuda de apuntado (solo jugador).
var aim_lock: Tank = null

var _scale_factor: float = 1.0
var _shake: float = 0.0
var _view: int = 0
var _meshes: Array[MeshInstance3D] = []
var _materials: Array[Material] = []


func _ready() -> void:
	if stats == null:
		stats = TankStats.new()
	if paint.is_empty():
		paint = TankModel.plain_paint(Color(0.33, 0.36, 0.22))
	_scale_factor = stats.body_scale
	add_to_group(&"tanks")
	collision_layer = LAYER_TANK
	collision_mask = LAYER_WORLD | LAYER_TANK
	_build_body()
	_build_components()
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)


## ¿Es enemigo de este otro tanque?
func is_hostile_to(other: Tank) -> bool:
	return other != null and other.team != team


func _physics_process(_delta: float) -> void:
	if trigger_held and not is_destroyed:
		weapon.fire()


## 0 = cabina, 1 = detrás cerca, 2 = detrás lejos.
func set_view(view: int) -> void:
	if camera == null:
		return
	_view = view
	if view == 0:
		camera.top_level = false
		camera.transform = Transform3D(Basis(), Vector3(0.0, 0.35, 0.2))
		camera.cull_mask = 1
	else:
		camera.top_level = true
		camera.cull_mask = 1 | VISUAL_LAYER_OWN
		camera.global_transform = _chase_transform()


func _chase_transform() -> Transform3D:
	var offset: Vector2 = CHASE_OFFSETS[clampi(_view - 1, 0, 1)]
	var yaw: float = turret_controller.world_yaw
	var forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var eye: Vector3 = global_position - forward * offset.x + Vector3.UP * offset.y
	var look: Vector3 = global_position + forward * 25.0 + Vector3.UP * 1.5
	return Transform3D(Basis.looking_at(look - eye, Vector3.UP), eye)


func _process(delta: float) -> void:
	if camera != null and _view > 0:
		var target: Transform3D = _chase_transform()
		var t: float = 1.0 - exp(-8.0 * delta)
		camera.global_transform = Transform3D(camera.global_basis.slerp(target.basis, t).orthonormalized(), camera.global_position.lerp(target.origin, t))
	if camera != null:
		_shake = maxf(_shake - delta * 2.5, 0.0)
		camera.h_offset = randf_range(-1.0, 1.0) * _shake * 0.25
		camera.v_offset = randf_range(-1.0, 1.0) * _shake * 0.25


func _on_fired() -> void:
	if is_player:
		Sfx.play_2d(self, Sfx.CANNON, 2.0)
		_shake = maxf(_shake, 0.35)
	else:
		Sfx.play_at(self, Sfx.CANNON, muzzle.global_position, 0.0, 1.0 / maxf(_scale_factor, 0.7))


func _on_damaged(amount: float, source: Node) -> void:
	if is_player:
		_shake = minf(_shake + amount / 25.0, 1.5)
		# Impacto en nuestro propio blindaje: golpe metálico seco y fuerte.
		Sfx.play_2d(self, Sfx.HIT_TANK, 4.0, clampf(1.2 - amount / 60.0, 0.8, 1.2))
	damaged.emit(amount, source)


func _on_died(source: Node) -> void:
	is_destroyed = true
	drive_input = Vector2.ZERO
	trigger_held = false
	remove_from_group(&"tanks")
	hurtbox.set_deferred("monitorable", false)
	hurtbox.collision_layer = 0
	Explosion.spawn(self, global_position + Vector3.UP * 1.0, 1.0 * _scale_factor + 0.5)
	destroyed.emit(self, source)
	if is_player:
		_shake = 1.5
	# Queda un casco calcinado unos segundos.
	var burnt := VectorMaterials.paint(Color(0.06, 0.05, 0.05))
	for mesh in _meshes:
		if is_instance_valid(mesh):
			mesh.material_override = burnt
	if turret != null:
		turret.rotation += Vector3(randf_range(-0.2, 0.2), randf_range(-0.6, 0.6), randf_range(-0.3, 0.3))
	if not is_player:
		get_tree().create_timer(WRECK_TIME).timeout.connect(queue_free)


## Reaparece (solo el jugador: los tanques de la máquina se crean de nuevo).
func revive(spawn: Transform3D) -> void:
	health.revive()
	is_destroyed = false
	add_to_group(&"tanks")
	hurtbox.collision_layer = LAYER_HURTBOX
	hurtbox.set_deferred("monitorable", true)
	for i in _meshes.size():
		if is_instance_valid(_meshes[i]):
			_meshes[i].material_override = _materials[i]
	turret.rotation = Vector3.ZERO
	turret_controller.setup(self)
	global_transform = spawn
	velocity = Vector3.ZERO
	aim_lock = null


func _build_body() -> void:
	var model: TankModel = TankModel.build(self, stats, paint, is_player)
	turret = model.turret
	gun_pivot = model.gun_pivot
	muzzle = model.muzzle
	_meshes = model.own
	for mesh in _meshes:
		_materials.append(mesh.material_override)
	var k: float = _scale_factor
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(model.hull_size.x + 1.0 * k, 1.4 * k, model.hull_size.z)
	shape.shape = box
	shape.position.y = 0.75 * k
	add_child(shape)

	if is_player:
		for mesh in _meshes:
			mesh.layers = VISUAL_LAYER_OWN
		camera = Camera3D.new()
		camera.name = "Camera"
		camera.fov = 75.0
		camera.near = 0.1
		camera.far = 600.0
		camera.cull_mask = 1
		camera.position = Vector3(0.0, 0.35, 0.2)
		gun_pivot.add_child(camera)
		camera.current = true


func _build_components() -> void:
	var k: float = _scale_factor
	health = HealthComponent.new()
	health.name = "HealthComponent"
	health.max_health = stats.max_armor
	add_child(health)

	hurtbox = Hurtbox.new()
	hurtbox.name = "Hurtbox"
	hurtbox.collision_layer = LAYER_HURTBOX
	hurtbox.collision_mask = 0
	hurtbox.health = health
	hurtbox.team = team
	var hurt_shape := CollisionShape3D.new()
	var hurt_box := BoxShape3D.new()
	hurt_box.size = Vector3(TankModel.HULL_SIZE.x * stats.hull_proportions.x * k + 1.2 * k, 2.6 * k, TankModel.HULL_SIZE.z * stats.hull_proportions.z * k + 0.2)
	hurt_shape.shape = hurt_box
	hurt_shape.position.y = 1.3 * k
	hurtbox.add_child(hurt_shape)
	add_child(hurtbox)

	var movement := TankMovement.new()
	movement.name = "TankMovement"
	add_child(movement)
	movement.setup(self)

	turret_controller = TurretController.new()
	turret_controller.name = "TurretController"
	add_child(turret_controller)
	turret_controller.setup(self)

	weapon = TankWeapon.new()
	weapon.name = "TankWeapon"
	weapon.projectile_scene = load("res://entities/projectiles/shell.tscn")
	weapon.projectile_speed = stats.projectile_speed
	weapon.damage = stats.damage
	weapon.reload_time = stats.reload_time
	weapon.muzzle = muzzle
	weapon.ignore_rids = [hurtbox.get_rid()]
	weapon.team = team
	weapon.fired.connect(_on_fired)
	add_child(weapon)
