class_name PlayerInputSource
extends Node
## Traduce los controles táctiles en órdenes para el tanque.

@export var tank: Tank
@export var touch: TouchControls
## Radianes de giro por píxel arrastrado.
@export var look_sensitivity: float = 0.004


func _process(_delta: float) -> void:
	if tank == null or touch == null:
		return
	tank.drive_input = touch.move_vector
	tank.trigger_held = touch.fire_held
	var look: Vector2 = touch.consume_look_delta()
	if look != Vector2.ZERO:
		tank.turret_controller.add_aim(-look.x * look_sensitivity, -look.y * look_sensitivity)
