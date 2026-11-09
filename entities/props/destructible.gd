class_name Destructible
extends StaticBody3D
## Objeto del escenario que recibe disparos: árboles, casas, vallas, bloques, montañas.
## Las montañas son indestructibles: solo sueltan una pequeña explosión de roca.

signal destroyed(prop: Destructible)

@export var max_health: float = 50.0
@export var indestructible: bool = false
## Los tanques lo derriban al pasar por encima (vallas, árboles).
@export var crushable: bool = false
@export var debris_color: Color = Color(0.55, 0.5, 0.4)
## Tamaño aproximado: escala la explosión final.
@export var size_hint: float = 1.0

var health: float
var is_destroyed: bool = false


func _ready() -> void:
	health = max_health
	collision_layer = 1
	collision_mask = 0


func take_hit(amount: float, _source: Node = null, point: Vector3 = Vector3.ZERO) -> void:
	if is_destroyed:
		return
	if point == Vector3.ZERO:
		point = global_position + Vector3.UP
	Explosion.spawn(self, point, 0.35, debris_color, true)
	if indestructible:
		return
	health -= amount
	if health <= 0.0:
		_destroy()


func _destroy() -> void:
	is_destroyed = true
	collision_layer = 0
	Explosion.spawn(self, global_position + Vector3.UP * size_hint, clampf(size_hint * 0.6, 0.5, 2.0), debris_color)
	destroyed.emit(self)
	# Se derrumba: se aplasta hacia el suelo y desaparece.
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3(1.15, 0.05, 1.15), 0.45).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)
