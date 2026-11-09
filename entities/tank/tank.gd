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

var _scale_factor: float = 1.0
var _shake: float = 0.0


func _ready() -> void:
	if stats == null:
		stats = TankStats.new()
	_scale_factor = stats.body_scale
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
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(HULL_SIZE.x, 1.2, HULL_SIZE.z) * k
	shape.shape = box
	shape.position.y = 0.6 * k
	add_child(shape)

	var hull := VectorMaterials.make_box(HULL_SIZE * k, color)
	hull.position.y = 0.45 * k
	add_child(hull)

	turret = Node3D.new()
	turret.name = "Turret"
	turret.position = Vector3(0.0, 1.25, 0.2) * k
	add_child(turret)
	var turret_mesh := VectorMaterials.make_box(TURRET_SIZE * k, color)
	turret.add_child(turret_mesh)

	gun_pivot = Node3D.new()
	gun_pivot.name = "GunPivot"
	gun_pivot.position = Vector3(0.0, 0.1, 0.0) * k
	turret.add_child(gun_pivot)
	var barrel := VectorMaterials.make_box(BARREL_SIZE * k, color)
	barrel.position = Vector3(0.0, 0.0, -BARREL_SIZE.z * 0.5 - 0.6) * k
	gun_pivot.add_child(barrel)

	muzzle = Marker3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector3(0.0, 0.0, -BARREL_SIZE.z - 0.7) * k
	gun_pivot.add_child(muzzle)

	if is_player:
		for mesh: MeshInstance3D in [hull, turret_mesh, barrel]:
			mesh.layers = VISUAL_LAYER_OWN
		camera = Camera3D.new()
		camera.name = "Camera"
		camera.fov = 75.0
		camera.near = 0.1
		camera.far = 500.0
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
	hurt_box.size = Vector3(HULL_SIZE.x * k + 0.2, 2.2 * k, HULL_SIZE.z * k + 0.2)
	hurt_shape.shape = hurt_box
	hurt_shape.position.y = 1.1 * k
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
	add_child(weapon)
