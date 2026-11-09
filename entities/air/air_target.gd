class_name AirTarget
extends Node3D
## Avión o helicóptero enemigo que cruza el cielo y se puede derribar a cañonazos.
## Al derribarlo da un premio (blindaje, misil o bombardeo) a quien lo derriba.

enum Kind { PLANE, HELICOPTER, AIRSHIP }

const PLANE_SPEED: float = 24.0
const HELI_SPEED: float = 9.0
const AIRSHIP_SPEED: float = 4.5
## Distancia a la que estalla un proyectil cerca del aparato.
const PROXIMITY: float = 7.0

var kind: Kind = Kind.PLANE
var health: HealthComponent
var hurtbox: Hurtbox
var is_destroyed: bool = false
var _velocity: Vector3
var _rotor: Node3D
var _life: float = 40.0
var _falling: bool = false
var _wobble: float = randf() * TAU
var _sound: FlybySound


static func spawn(host: Node, aircraft_kind: Kind, center: Vector3) -> AirTarget:
	var target := AirTarget.new()
	target.kind = aircraft_kind
	host.add_child(target)
	var dir := Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU)
	var speed: float = [PLANE_SPEED, HELI_SPEED, AIRSHIP_SPEED][aircraft_kind]
	var height: float = [randf_range(28.0, 42.0), randf_range(18.0, 28.0), randf_range(40.0, 55.0)][aircraft_kind]
	var start_dist: float = [160.0, 70.0, 50.0][aircraft_kind]
	target.global_position = center - dir * start_dist + dir.cross(Vector3.UP) * randf_range(-40.0, 40.0) + Vector3.UP * height
	target._velocity = dir * speed
	target.look_at(target.global_position + dir, Vector3.UP)
	return target


func _ready() -> void:
	add_to_group(&"air_targets")
	add_to_group(&"radar_marks")
	set_meta("radar_color", Color(1.0, 0.4, 0.9))
	set_meta("radar_shape", "star")
	health = HealthComponent.new()
	health.max_health = [30.0, 45.0, 20.0][kind]
	add_child(health)
	health.died.connect(_on_died)
	hurtbox = Hurtbox.new()
	hurtbox.team = 1
	hurtbox.health = health
	hurtbox.collision_layer = 4
	hurtbox.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	# Caja de impacto algo generosa para que se pueda acertar.
	box.size = [Vector3(12.0, 4.0, 11.0), Vector3(7.0, 5.0, 10.0), Vector3(10.0, 10.0, 34.0)][kind]
	shape.shape = box
	hurtbox.add_child(shape)
	add_child(hurtbox)
	match kind:
		Kind.PLANE:
			_build_plane()
		Kind.HELICOPTER:
			_build_helicopter()
		_:
			_build_airship()
	match kind:
		Kind.PLANE:
			_sound = FlybySound.attach(self, Sfx.PLANE_FIGHTER, 6.0, 32.0, 450.0)
		Kind.HELICOPTER:
			_sound = FlybySound.attach(self, Sfx.HELICOPTER, 6.0, 28.0, 380.0)
		_:
			# Dirigible: motores lentos y graves.
			_sound = FlybySound.attach(self, Sfx.PLANE_BOMBER, 2.0, 30.0, 350.0, 0.62)


func _build_plane() -> void:
	var color := Color(0.35, 0.37, 0.33)
	var body := MeshInstance3D.new()
	var fuselage := CylinderMesh.new()
	fuselage.top_radius = 0.35
	fuselage.bottom_radius = 0.7
	fuselage.height = 8.0
	fuselage.radial_segments = 10
	body.mesh = fuselage
	body.material_override = VectorMaterials.textured(color, color.darkened(0.4), 4, 0.5)
	body.rotation.x = PI * 0.5
	add_child(body)
	for part in [[Vector3(11.0, 0.15, 1.8), Vector3(0.0, -0.1, -0.6)], [Vector3(3.6, 0.12, 1.0), Vector3(0.0, 0.25, 3.6)], [Vector3(0.12, 1.4, 1.0), Vector3(0.0, 0.9, 3.6)], [Vector3(0.7, 0.45, 1.2), Vector3(0.0, 0.6, -0.8)]]:
		var mesh := VectorMaterials.make_box(part[0], color if part[0].y < 0.4 else Color(0.3, 0.42, 0.48), 4, 1.0)
		mesh.position = part[1]
		add_child(mesh)
	_rotor = Node3D.new()
	_rotor.position = Vector3(0.0, 0.0, -4.1)
	add_child(_rotor)
	var blade := VectorMaterials.make_box(Vector3(2.6, 0.18, 0.06), Color(0.15, 0.15, 0.15))
	_rotor.add_child(blade)


func _build_helicopter() -> void:
	var color := Color(0.32, 0.36, 0.28)
	var cabin := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.6
	sphere.height = 3.0
	cabin.mesh = sphere
	cabin.material_override = VectorMaterials.textured(color, color.darkened(0.4), 0, 0.5)
	add_child(cabin)
	var glass := VectorMaterials.make_box(Vector3(1.6, 1.0, 0.1), Color(0.3, 0.42, 0.48), 1, 0.5)
	glass.position = Vector3(0.0, 0.3, -1.5)
	add_child(glass)
	var boom := VectorMaterials.make_box(Vector3(0.4, 0.4, 6.0), color, 4, 1.0)
	boom.position = Vector3(0.0, 0.3, 4.0)
	add_child(boom)
	var fin := VectorMaterials.make_box(Vector3(0.1, 1.4, 0.8), color, 4, 0.5)
	fin.position = Vector3(0.0, 0.9, 6.8)
	add_child(fin)
	for x in [-1.0, 1.0]:
		var skid := VectorMaterials.make_box(Vector3(0.12, 0.12, 3.6), Color(0.2, 0.2, 0.2))
		skid.position = Vector3(x, -1.8, 0.0)
		add_child(skid)
	var mast := VectorMaterials.make_box(Vector3(0.2, 0.8, 0.2), Color(0.2, 0.2, 0.2))
	mast.position.y = 1.8
	add_child(mast)
	_rotor = Node3D.new()
	_rotor.position.y = 2.2
	add_child(_rotor)
	for angle in [0.0, PI * 0.5]:
		var blade := VectorMaterials.make_box(Vector3(11.0, 0.08, 0.35), Color(0.15, 0.15, 0.15))
		blade.rotation.y = angle
		_rotor.add_child(blade)


## Dirigible de patrulla: enorme, lento y el más fácil de derribar.
func _build_airship() -> void:
	var envelope := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 4.5
	mesh.height = 32.0
	mesh.radial_segments = 16
	mesh.rings = 6
	envelope.mesh = mesh
	envelope.material_override = VectorMaterials.textured(Color(0.6, 0.6, 0.58), Color(0.45, 0.45, 0.43), 4, 1.2)
	envelope.rotation.x = PI * 0.5
	add_child(envelope)
	var gondola := VectorMaterials.make_box(Vector3(2.2, 1.6, 6.0), Color(0.3, 0.32, 0.3), 1, 0.6)
	gondola.position = Vector3(0.0, -5.2, -2.0)
	add_child(gondola)
	for fin in [[Vector3(0.2, 5.0, 4.0), Vector3(0.0, 2.8, 14.0)], [Vector3(0.2, 5.0, 4.0), Vector3(0.0, -2.8, 14.0)], [Vector3(5.0, 0.2, 4.0), Vector3(2.8, 0.0, 14.0)], [Vector3(5.0, 0.2, 4.0), Vector3(-2.8, 0.0, 14.0)]]:
		var piece := VectorMaterials.make_box(fin[0], Color(0.5, 0.5, 0.48), 4, 0.8)
		piece.position = fin[1]
		add_child(piece)
	_rotor = Node3D.new()
	_rotor.position = Vector3(0.0, -5.2, 1.2)
	add_child(_rotor)
	_rotor.add_child(VectorMaterials.make_box(Vector3(1.8, 0.12, 0.05), Color(0.15, 0.15, 0.15)))


func _process(delta: float) -> void:
	_life -= delta
	if _sound != null:
		_sound.source_velocity = _velocity
		if _falling:
			# Al caer derribado, el motor se embala.
			_sound.base_pitch = move_toward(_sound.base_pitch, 1.7, delta * 0.5)
	if _rotor != null:
		if kind != Kind.HELICOPTER:
			_rotor.rotation.z += delta * 40.0
		else:
			_rotor.rotation.y += delta * 25.0
	if _falling:
		_velocity += Vector3.DOWN * 18.0 * delta
		rotation.z += delta * 2.5
		global_position += _velocity * delta
		if global_position.y <= 0.5:
			Explosion.spawn(self, Vector3(global_position.x, 0.5, global_position.z), 2.0)
			queue_free()
		return
	if kind == Kind.HELICOPTER:
		# Vuelo errático: se balancea y cambia de rumbo poco a poco.
		_wobble += delta
		_velocity = _velocity.rotated(Vector3.UP, sin(_wobble * 0.7) * delta * 0.6)
		global_position.y += sin(_wobble * 1.3) * delta * 1.5
		look_at(global_position + _velocity, Vector3.UP)
	global_position += _velocity * delta
	if _life <= 0.0 or absf(global_position.x) > 320.0 or absf(global_position.z) > 320.0:
		queue_free()


## Se aleja sin más (al acabar la fase aérea).
func leave() -> void:
	_life = minf(_life, 4.0)
	_velocity = _velocity.normalized() * PLANE_SPEED * 2.0 + Vector3.UP * 6.0


func _on_died(source: Node) -> void:
	is_destroyed = true
	_falling = true
	remove_from_group(&"radar_marks")
	remove_from_group(&"air_targets")
	hurtbox.set_deferred("monitorable", false)
	hurtbox.collision_layer = 0
	Explosion.spawn(self, global_position, 1.2)
	if source is Tank and (source as Tank).is_player:
		get_tree().call_group(&"game_mode", &"air_reward", global_position)
