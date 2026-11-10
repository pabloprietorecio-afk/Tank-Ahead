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
## Si > 0, al destruirse daña lo que tenga alrededor (bidones de combustible).
@export var blast_radius: float = 0.0
@export var blast_damage: float = 0.0

## Premio por destruirlo (puntos). 0 = sin premio.
@export var prize_points: int = 0
@export var prize_name: String = ""
## Si es objetivo de misión: nombre que aparece en la lista de objetivos.
var objective_name: String = ""
## Zona protegida (barracones con prisioneros): dispararle penaliza al jugador.
var protected_area: bool = false
## Sonido especial al destruirlo (p. ej. la campana del campanario).
var destroy_sound: AudioStream

var health: float
var is_destroyed: bool = false
var _last_source: Node


func _ready() -> void:
	health = max_health
	collision_layer = 1
	collision_mask = 0


func take_hit(amount: float, _source: Node = null, point: Vector3 = Vector3.ZERO) -> void:
	if is_destroyed:
		return
	if protected_area and _source is Tank and (_source as Tank).is_player:
		get_tree().call_group(&"game_mode", &"penalize", _source)
	if point == Vector3.ZERO:
		point = global_position + Vector3.UP
	# Polvo y astillas del material, que saltan hacia fuera del objeto.
	var away: Vector3 = point - (global_position + Vector3.UP * size_hint * 0.5)
	away.y = maxf(away.y, 0.0)
	Fx.on(self).chips(point, away.normalized() if away.length_squared() > 0.01 else Vector3.UP, debris_color, clampf(size_hint * 0.5, 0.6, 1.3))
	if indestructible:
		return
	_last_source = _source
	health -= amount
	if health <= 0.0:
		_destroy()


func _destroy() -> void:
	is_destroyed = true
	collision_layer = 0
	var strength: float = clampf(size_hint * 0.6, 0.5, 2.0)
	var center: Vector3 = global_position + Vector3.UP * size_hint * 0.5
	if blast_radius > 0.0:
		# Combustible: revienta con fuego.
		Fx.on(self).fuel_blast(center, maxf(strength, 1.0))
	else:
		# Lo demás se viene abajo entre polvo y cascotes de su material.
		Fx.on(self).rubble(center, size_hint, debris_color)
	if strength < 0.8 and blast_radius <= 0.0:
		Sfx.play_at(self, Sfx.HIT, center, 2.0)
	else:
		Sfx.play_at(self, Sfx.EXPLOSION, center, 6.0, 1.1 / clampf(strength, 0.8, 2.0))
	destroyed.emit(self)
	remove_from_group(&"radar_marks")
	if destroy_sound != null:
		Sfx.play_at(self, destroy_sound, global_position + Vector3.UP * size_hint, 8.0)
	var by_player: bool = _last_source is Tank and (_last_source as Tank).is_player
	if prize_points > 0 and by_player:
		get_tree().call_group(&"game_mode", &"add_score", prize_points)
		get_tree().call_group(&"voice", &"say", "bonus", VoiceManager.Priority.NORMAL)
		get_tree().call_group(&"game_mode", &"announce", "%s DESTRUIDO  +%d" % [prize_name, prize_points], false)
		# Además suelta un premio en el sitio.
		get_tree().call_group(&"pickup_spawner", &"spawn", Pickup.random_kind(), Vector2(global_position.x, global_position.z) + Vector2(4.0, 4.0))
	if blast_radius > 0.0:
		_blast.call_deferred()
	# Se derrumba: se aplasta hacia el suelo y desaparece.
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3(1.15, 0.05, 1.15), 0.45).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)


func _blast() -> void:
	var sphere := SphereShape3D.new()
	sphere.radius = blast_radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis(), global_position + Vector3.UP)
	query.collision_mask = 1 | 4
	query.collide_with_areas = true
	var hits: Array[Dictionary] = get_world_3d().direct_space_state.intersect_shape(query, 32)
	for hit in hits:
		var collider: Object = hit["collider"]
		if collider == self or not collider.has_method("take_hit"):
			continue
		var target: Node3D = collider as Node3D
		var falloff: float = 1.0 - clampf(target.global_position.distance_to(global_position) / blast_radius, 0.0, 0.8)
		collider.take_hit(blast_damage * falloff, self, target.global_position + Vector3.UP)
