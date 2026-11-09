class_name Tank
extends CharacterBody3D
## Tanque base. Jugador y enemigos usan esta misma clase; solo cambia quién da las órdenes.
## Las mallas se crean por código mientras no haya arte definitivo.

const LAYER_WORLD: int = 1
const LAYER_TANK: int = 2
const LAYER_HURTBOX: int = 4
## Capa visual de las piezas del propio jugador (la cámara en primera persona no las ve).
const VISUAL_LAYER_OWN: int = 2

const HULL_SIZE := Vector3(3.2, 0.9, 4.6)
const TURRET_SIZE := Vector3(1.8, 0.7, 2.0)
const BARREL_SIZE := Vector3(0.25, 0.25, 2.6)

signal destroyed(tank: Tank, killer: Node)
signal damaged(amount: float, source: Node)

@export var stats: TankStats
@export var is_player: bool = false
## 0 = jugador, 1 = enemigos.
@export var team: int = 0

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


func _ready() -> void:
	if stats == null:
		stats = TankStats.new()
	_scale_factor = stats.body_scale
	if team == 1:
		add_to_group(&"enemies")
	collision_layer = LAYER_TANK
	collision_mask = LAYER_WORLD | LAYER_TANK
	_build_body()
	_build_components()
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)


func _physics_process(_delta: float) -> void:
	if trigger_held and not is_destroyed:
		weapon.fire()


func _process(delta: float) -> void:
	if camera != null:
		_shake = maxf(_shake - delta * 2.5, 0.0)
		camera.h_offset = randf_range(-1.0, 1.0) * _shake * 0.25
		camera.v_offset = randf_range(-1.0, 1.0) * _shake * 0.25


func _on_fired() -> void:
	if is_player:
		Sfx.play_2d(self, Sfx.CANNON, -2.0)
		_shake = maxf(_shake, 0.35)
	else:
		Sfx.play_at(self, Sfx.CANNON, muzzle.global_position, 0.0, 1.0 / maxf(_scale_factor, 0.7))


func _on_damaged(amount: float, source: Node) -> void:
	if is_player:
		_shake = minf(_shake + amount / 25.0, 1.5)
	damaged.emit(amount, source)


func _on_died(source: Node) -> void:
	is_destroyed = true
	drive_input = Vector2.ZERO
	trigger_held = false
	hurtbox.set_deferred("monitorable", false)
	hurtbox.collision_layer = 0
	Explosion.spawn(self, global_position + Vector3.UP * 1.0, 1.0 * _scale_factor + 0.5)
	destroyed.emit(self, source)
	if is_player:
		_shake = 1.5
		for node in get_children():
			if node is MeshInstance3D:
				node.visible = false
		return
	queue_free()


func _build_body() -> void:
	var k: float = _scale_factor
	var color: Color = stats.color
	var hull_size: Vector3 = HULL_SIZE * stats.hull_proportions * k
	var own_meshes: Array[MeshInstance3D] = []
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(hull_size.x, 1.2 * k, hull_size.z)
	shape.shape = box
	shape.position.y = 0.6 * k
	add_child(shape)

	var hull := VectorMaterials.make_box(hull_size, color, 4, 1.2 * k)
	hull.position.y = 0.2 * k + hull_size.y * 0.5
	add_child(hull)
	own_meshes.append(hull)
	var top: float = 0.2 * k + hull_size.y

	if stats.has_tracks:
		var track_size := Vector3(0.55 * k, 0.75 * k, hull_size.z * 1.04)
		for side in [-1.0, 1.0]:
			var track := VectorMaterials.make_box(track_size, color.darkened(0.25), 3, 0.5 * k)
			track.position = Vector3(side * (hull_size.x * 0.5 + track_size.x * 0.5 - 0.05), track_size.y * 0.5, 0.0)
			add_child(track)
			own_meshes.append(track)

	var turret_size: Vector3 = TURRET_SIZE * stats.turret_scale * k
	turret = Node3D.new()
	turret.name = "Turret"
	turret.position = Vector3(0.0, top + turret_size.y * 0.5, 0.2 * k)
	add_child(turret)
	var turret_mesh := VectorMaterials.make_box(turret_size, color, 4, 0.8 * k)
	turret.add_child(turret_mesh)
	own_meshes.append(turret_mesh)

	if stats.has_dome:
		var dome := VectorMaterials.make_box(Vector3(0.7, 0.35, 0.7) * k, color.lightened(0.3))
		dome.position = Vector3(0.35 * k, turret_size.y * 0.5 + 0.17 * k, 0.35 * k)
		turret.add_child(dome)
		own_meshes.append(dome)
	if stats.has_antenna:
		var antenna := VectorMaterials.make_box(Vector3(0.06, 2.4, 0.06) * k, color.lightened(0.4))
		antenna.position = Vector3(-turret_size.x * 0.4, turret_size.y * 0.5 + 1.2 * k, turret_size.z * 0.4)
		turret.add_child(antenna)
		own_meshes.append(antenna)

	gun_pivot = Node3D.new()
	gun_pivot.name = "GunPivot"
	gun_pivot.position = Vector3(0.0, 0.1, 0.0) * k
	turret.add_child(gun_pivot)
	var barrel_size := Vector3(BARREL_SIZE.x * stats.barrel_thickness, BARREL_SIZE.y * stats.barrel_thickness, BARREL_SIZE.z * stats.barrel_length) * k
	var barrels: int = maxi(stats.barrel_count, 1)
	for b in barrels:
		var x: float = 0.0 if barrels == 1 else (b - (barrels - 1) * 0.5) * barrel_size.x * 1.8
		var barrel := VectorMaterials.make_box(barrel_size, color)
		barrel.position = Vector3(x, 0.0, -turret_size.z * 0.5 - barrel_size.z * 0.5 + 0.2 * k)
		gun_pivot.add_child(barrel)
		own_meshes.append(barrel)

	muzzle = Marker3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector3(0.0, 0.0, -turret_size.z * 0.5 - barrel_size.z - 0.1 * k)
	gun_pivot.add_child(muzzle)

	if is_player:
		for mesh in own_meshes:
			mesh.layers = VISUAL_LAYER_OWN
		camera = Camera3D.new()
		camera.name = "Camera"
		camera.fov = 75.0
		camera.near = 0.1
		camera.far = 600.0
		camera.cull_mask = 1
		camera.position = Vector3(0.0, 0.3, 0.2)
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
	hurt_box.size = Vector3(HULL_SIZE.x * stats.hull_proportions.x * k + 1.2 * k, 2.4 * k, HULL_SIZE.z * stats.hull_proportions.z * k + 0.2)
	hurt_shape.shape = hurt_box
	hurt_shape.position.y = 1.2 * k
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
