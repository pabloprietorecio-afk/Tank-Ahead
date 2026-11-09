class_name Projectile
extends Node3D
## Proyectil recto. Cada tick lanza un rayo de la posición anterior a la nueva, así un
## proyectil rápido no atraviesa paredes finas. Solo conoce a `Hurtbox`.
## Se reutilizan mediante un pequeño pool para evitar crear y destruir nodos.

const MASK_WORLD: int = 1
const MASK_HURTBOX: int = 4
const LIFETIME: float = 3.0
const MAX_SKIPS: int = 4

static var _pool: Array[Projectile] = []

var velocity: Vector3 = Vector3.ZERO
var damage: float = 0.0
var shooter: Node = null
var team: int = 0

var _ignore: Array[RID] = []
var _life: float = LIFETIME
var _released: bool = false


static func acquire(scene: PackedScene, parent: Node) -> Projectile:
	while not _pool.is_empty():
		var pooled: Projectile = _pool.pop_back()
		if is_instance_valid(pooled):
			parent.add_child(pooled)
			return pooled
	var fresh: Projectile = scene.instantiate() as Projectile
	parent.add_child(fresh)
	return fresh


func _ready() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.2, 0.2, 1.6)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = VectorMaterials.flat(VectorMaterials.ORANGE)
	add_child(instance)


func launch(origin: Vector3, new_velocity: Vector3, new_damage: float, owner_node: Node, ignore: Array[RID], new_team: int) -> void:
	_released = false
	_life = LIFETIME
	visible = true
	set_physics_process(true)
	global_position = origin
	velocity = new_velocity
	damage = new_damage
	shooter = owner_node
	team = new_team
	_ignore = ignore.duplicate()
	look_at(origin + new_velocity, Vector3.UP)


func _physics_process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		_release()
		return
	var from: Vector3 = global_position
	var to: Vector3 = from + velocity * delta
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	for attempt in MAX_SKIPS:
		var query := PhysicsRayQueryParameters3D.create(from, to, MASK_WORLD | MASK_HURTBOX)
		query.collide_with_areas = true
		query.exclude = _ignore
		var result: Dictionary = space.intersect_ray(query)
		if result.is_empty():
			global_position = to
			return
		var collider: Object = result["collider"]
		if collider is Hurtbox:
			var hurtbox: Hurtbox = collider
			if hurtbox.team == team:
				_ignore.append(hurtbox.get_rid())
				continue
			hurtbox.take_hit(damage, shooter)
		Explosion.spawn(self, result["position"], 0.4)
		_release()
		return
	global_position = to


func _release() -> void:
	if _released:
		return
	_released = true
	set_physics_process(false)
	visible = false
	_return_to_pool.call_deferred()


func _return_to_pool() -> void:
	if get_parent() != null:
		get_parent().remove_child(self)
	_pool.append(self)
