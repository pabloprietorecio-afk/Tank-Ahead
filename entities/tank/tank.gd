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

@export var stats: TankStats
@export var is_player: bool = false

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


func _ready() -> void:
	if stats == null:
		stats = TankStats.new()
	collision_layer = LAYER_TANK
	collision_mask = LAYER_WORLD | LAYER_TANK
	_build_body()
	_build_components()


func _physics_process(_delta: float) -> void:
	if trigger_held:
		weapon.fire()


func _build_body() -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(HULL_SIZE.x, 1.2, HULL_SIZE.z)
	shape.shape = box
	shape.position.y = 0.6
	add_child(shape)

	var hull := VectorMaterials.make_box(HULL_SIZE)
	hull.position.y = 0.45
	add_child(hull)

	turret = Node3D.new()
	turret.name = "Turret"
	turret.position = Vector3(0.0, 1.25, 0.2)
	add_child(turret)
	var turret_mesh := VectorMaterials.make_box(TURRET_SIZE)
	turret.add_child(turret_mesh)

	gun_pivot = Node3D.new()
	gun_pivot.name = "GunPivot"
	gun_pivot.position = Vector3(0.0, 0.1, 0.0)
	turret.add_child(gun_pivot)
	var barrel := VectorMaterials.make_box(BARREL_SIZE)
	barrel.position = Vector3(0.0, 0.0, -BARREL_SIZE.z * 0.5 - 0.6)
	gun_pivot.add_child(barrel)

	muzzle = Marker3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector3(0.0, 0.0, -BARREL_SIZE.z - 0.7)
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
	health = HealthComponent.new()
	health.name = "HealthComponent"
	health.max_health = stats.max_armor
	add_child(health)

	hurtbox = Hurtbox.new()
	hurtbox.name = "Hurtbox"
	hurtbox.collision_layer = LAYER_HURTBOX
	hurtbox.collision_mask = 0
	hurtbox.health = health
	var hurt_shape := CollisionShape3D.new()
	var hurt_box := BoxShape3D.new()
	hurt_box.size = Vector3(HULL_SIZE.x + 0.2, 2.2, HULL_SIZE.z + 0.2)
	hurt_shape.shape = hurt_box
	hurt_shape.position.y = 1.1
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
	add_child(weapon)
