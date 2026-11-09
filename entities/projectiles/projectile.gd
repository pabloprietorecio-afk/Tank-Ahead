class_name Projectile
extends Node3D
## Proyecto recto. Cada tick lanza un rayo de la posición anterior a la nueva, así un
## proyectil rápido no atraviesa paredes finas. Solo conoce a `Hurtbox`.

const MASK_WORLD: int = 1
const MASK_HURTBOX: int = 4
const LIFETIME: float = 3.0

var velocity: Vector3 = Vector3.ZERO
var damage: float = 0.0
var shooter: Node = null

var _ignore: Array[RID] = []
var _life: float = LIFETIME


func _ready() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.2, 0.2, 1.6)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = VectorMaterials.flat(VectorMaterials.ORANGE)
	add_child(instance)


func launch(origin: Vector3, new_velocity: Vector3, new_damage: float, owner_node: Node, ignore: Array[RID]) -> void:
	global_position = origin
	velocity = new_velocity
	damage = new_damage
	shooter = owner_node
	_ignore = ignore
	look_at(origin + new_velocity, Vector3.UP)


func _physics_process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	var from: Vector3 = global_position
	var to: Vector3 = from + velocity * delta
	var query := PhysicsRayQueryParameters3D.create(from, to, MASK_WORLD | MASK_HURTBOX)
	query.collide_with_areas = true
	query.exclude = _ignore
	var result: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		global_position = to
		return
	var collider: Object = result["collider"]
	if collider is Hurtbox:
		(collider as Hurtbox).take_hit(damage, shooter)
	_impact(result["position"])
	queue_free()


func _impact(point: Vector3) -> void:
	var flash := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.6
	sphere.height = 1.2
	sphere.radial_segments = 8
	sphere.rings = 4
	flash.mesh = sphere
	flash.material_override = VectorMaterials.flat(VectorMaterials.ORANGE)
	var scene: Node = get_tree().current_scene
	(scene if scene != null else get_tree().root).add_child(flash)
	flash.global_position = point
	var tween: Tween = flash.create_tween()
	tween.tween_property(flash, "scale", Vector3.ONE * 3.0, 0.2)
	tween.tween_callback(flash.queue_free)
