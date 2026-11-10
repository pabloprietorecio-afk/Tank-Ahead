class_name AirStrike
extends Node3D
## Bombardeo aéreo sobre una zona circular. Avisa con una zona coloreada y una cuenta atrás;
## después los aviones sueltan sus bombas y todo lo que esté dentro recibe daño.

signal finished

const BOMBS: int = 9

var radius: float = 14.0
var warning_time: float = 4.0
var damage: float = 55.0
## Quién lo ha pedido (para la puntuación y para no contar el daño como propio).
var caller: Node = null
var hostile_to_player: bool = true

var _time: float = 0.0
var _zone: MeshInstance3D
var _ring: MeshInstance3D
var _dropping: bool = false
var _bombs_left: int = BOMBS
var _bomb_timer: float = 0.0
var _hit: Dictionary = {}


static func launch(host: Node, center: Vector3, enemy_strike: bool, by: Node = null) -> AirStrike:
	var strike := AirStrike.new()
	strike.hostile_to_player = enemy_strike
	strike.caller = by
	if not enemy_strike:
		strike.radius = 18.0
		strike.damage = 140.0
		strike.warning_time = 3.0
	host.add_child(strike)
	strike.global_position = Vector3(center.x, 0.05, center.z)
	return strike


func _ready() -> void:
	add_to_group(&"air_strikes")
	var color: Color = Color(1.0, 0.1, 0.05) if hostile_to_player else Color(1.0, 0.6, 0.1)
	_zone = _disc(radius, Color(color, 0.45))
	_ring = _disc(radius, Color(color.lightened(0.3), 0.95))
	_ring.position.y = 0.06
	var glow := OmniLight3D.new()
	glow.light_color = color
	glow.omni_range = radius * 1.3
	glow.light_energy = 2.5
	glow.position.y = 4.0
	add_child(glow)
	_ring.scale = Vector3(1.0, 1.0, 1.0)
	add_to_group(&"radar_marks")
	set_meta("radar_color", color)
	set_meta("radar_shape", "zone")
	set_meta("radar_radius", radius)
	Aircraft.fly_over(get_parent(), global_position, hostile_to_player, 60.0)


func _disc(r: float, color: Color) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = r
	mesh.bottom_radius = r
	mesh.height = 0.1
	mesh.radial_segments = 40
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	mat.no_depth_test = false
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = mat
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return instance


## Segundos que faltan para que caigan las bombas.
func time_left() -> float:
	return maxf(warning_time - _time, 0.0)


func contains(point: Vector3) -> bool:
	return Vector2(point.x - global_position.x, point.z - global_position.z).length() <= radius


func _process(delta: float) -> void:
	_time += delta
	if not _dropping:
		# Anillo que se cierra hacia el centro como cuenta atrás.
		var t: float = clampf(_time / warning_time, 0.0, 1.0)
		_ring.scale = Vector3(1.0 - t * 0.95, 1.0, 1.0 - t * 0.95)
		_zone.visible = fmod(_time, 0.5) < 0.35
		if _time >= warning_time:
			_dropping = true
			_zone.visible = true
			_ring.visible = false
		return
	_bomb_timer -= delta
	if _bomb_timer <= 0.0 and _bombs_left > 0:
		_bomb_timer = 0.12
		_bombs_left -= 1
		var offset := Vector2.from_angle(randf() * TAU) * sqrt(randf()) * radius
		Explosion.spawn(self, global_position + Vector3(offset.x, 0.5, offset.y), 1.6)
		if _bombs_left == BOMBS - 1:
			_apply_damage()
	if _bombs_left == 0 and _bomb_timer <= -0.8:
		finished.emit()
		queue_free()


func _apply_damage() -> void:
	for node in get_tree().get_nodes_in_group(&"tanks"):
		var tank := node as Tank
		if tank == null or tank.is_destroyed or not contains(tank.global_position):
			continue
		tank.health.apply_damage(damage, caller if caller != tank else null)
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis(), global_position)
	query.collision_mask = 1
	for hit in get_world_3d().direct_space_state.intersect_shape(query, 48):
		var collider: Object = hit["collider"]
		if collider is Destructible and not collider.protected_area:
			collider.take_hit(damage, caller, (collider as Node3D).global_position + Vector3.UP)
