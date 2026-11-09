class_name Explosion
extends Node3D
## Explosión barata: un destello esférico y fragmentos que caen. Sin partículas de GPU.

const DURATION: float = 0.9
const FLASH_TIME: float = 0.35
const GRAVITY: float = 14.0

var _strength: float = 1.0
var _time: float = 0.0
var _flash: MeshInstance3D
var _fragments: Array[MeshInstance3D] = []
var _velocities: Array[Vector3] = []


static func spawn(host: Node, point: Vector3, strength: float = 1.0) -> void:
	var tree: SceneTree = host.get_tree()
	var root: Node = tree.current_scene if tree.current_scene != null else tree.root
	var explosion := Explosion.new()
	explosion._strength = strength
	root.add_child(explosion)
	explosion.global_position = point


func _ready() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 8
	sphere.rings = 4
	_flash = MeshInstance3D.new()
	_flash.mesh = sphere
	_flash.material_override = VectorMaterials.flat(VectorMaterials.ORANGE)
	_flash.scale = Vector3.ONE * 0.5 * _strength
	add_child(_flash)

	var count: int = 4 if _strength < 0.8 else 10
	var box := BoxMesh.new()
	box.size = Vector3(0.35, 0.35, 0.35) * maxf(_strength, 0.5)
	for i in count:
		var fragment := MeshInstance3D.new()
		fragment.mesh = box
		fragment.material_override = VectorMaterials.flat(VectorMaterials.ORANGE if i % 2 == 0 else Color(1.0, 0.9, 0.4))
		add_child(fragment)
		_fragments.append(fragment)
		_velocities.append(Vector3(randf_range(-1.0, 1.0), randf_range(0.6, 1.6), randf_range(-1.0, 1.0)).normalized() * randf_range(5.0, 11.0) * _strength)


func _process(delta: float) -> void:
	_time += delta
	if _time >= DURATION:
		queue_free()
		return
	var flash_t: float = clampf(_time / FLASH_TIME, 0.0, 1.0)
	_flash.visible = _time < FLASH_TIME
	_flash.scale = Vector3.ONE * lerpf(0.5, 3.5, flash_t) * _strength
	var shrink: float = 1.0 - _time / DURATION
	for i in _fragments.size():
		_velocities[i].y -= GRAVITY * delta
		_fragments[i].position += _velocities[i] * delta
		_fragments[i].scale = Vector3.ONE * shrink
