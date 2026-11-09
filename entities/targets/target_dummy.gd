class_name TargetDummy
extends StaticBody3D
## Blanco de práctica para la Fase 1. Se sustituirá por enemigos con IA.

signal destroyed(target: TargetDummy)

const SIZE := Vector3(3.0, 2.4, 4.5)

@export var max_health: float = 50.0

var _health: HealthComponent


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0

	var mesh := VectorMaterials.make_box(SIZE, VectorMaterials.ORANGE)
	mesh.position.y = SIZE.y * 0.5
	add_child(mesh)

	var body_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = SIZE
	body_shape.shape = box
	body_shape.position.y = SIZE.y * 0.5
	add_child(body_shape)

	_health = HealthComponent.new()
	_health.max_health = max_health
	add_child(_health)
	_health.died.connect(_on_died)

	var hurtbox := Hurtbox.new()
	hurtbox.collision_layer = 4
	hurtbox.collision_mask = 0
	hurtbox.health = _health
	var hurt_shape := CollisionShape3D.new()
	var hurt_box := BoxShape3D.new()
	hurt_box.size = SIZE + Vector3(0.2, 0.2, 0.2)
	hurt_shape.shape = hurt_box
	hurt_shape.position.y = SIZE.y * 0.5
	hurtbox.add_child(hurt_shape)
	add_child(hurtbox)


func _on_died(_source: Node) -> void:
	destroyed.emit(self)
	queue_free()
