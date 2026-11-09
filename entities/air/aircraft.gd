class_name Aircraft
extends Node3D
## Avión de paso (solo visual): cruza el cielo en línea recta y desaparece.

const SPEED: float = 70.0

var direction: Vector3 = Vector3.FORWARD
var _life: float = 9.0


static func fly_over(host: Node, target: Vector3, color: Color, height: float = 55.0) -> Aircraft:
	var plane := Aircraft.new()
	var dir := Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU)
	plane.direction = dir
	host.add_child(plane)
	plane.global_position = target - dir * SPEED * 3.0 + Vector3.UP * height
	plane.look_at(plane.global_position + dir, Vector3.UP)
	plane._build(color)
	var sound := AudioStreamPlayer3D.new()
	sound.stream = Sfx.ENGINE_PLANE
	sound.bus = AudioSetup.SFX
	sound.unit_size = 40.0
	sound.max_distance = 600.0
	sound.volume_db = 6.0
	plane.add_child(sound)
	sound.play()
	return plane


func _build(color: Color) -> void:
	var body := MeshInstance3D.new()
	var fuselage := CylinderMesh.new()
	fuselage.top_radius = 0.5
	fuselage.bottom_radius = 0.9
	fuselage.height = 11.0
	fuselage.radial_segments = 10
	body.mesh = fuselage
	body.material_override = VectorMaterials.textured(color, color.darkened(0.4), 4, 0.6)
	body.rotation.x = PI * 0.5
	add_child(body)
	for part in [[Vector3(16.0, 0.2, 2.4), Vector3(0.0, 0.0, -0.5)], [Vector3(5.0, 0.15, 1.4), Vector3(0.0, 0.3, 5.0)], [Vector3(0.15, 2.0, 1.4), Vector3(0.0, 1.1, 5.0)]]:
		var mesh := VectorMaterials.make_box(part[0], color, 4, 1.2)
		mesh.position = part[1]
		add_child(mesh)
	for x in [-3.5, 3.5]:
		var engine := MeshInstance3D.new()
		var nacelle := CylinderMesh.new()
		nacelle.top_radius = 0.45
		nacelle.bottom_radius = 0.45
		nacelle.height = 2.4
		nacelle.radial_segments = 8
		engine.mesh = nacelle
		engine.material_override = VectorMaterials.textured(color.darkened(0.3), Color(0.1, 0.1, 0.1), 4, 0.4)
		engine.rotation.x = PI * 0.5
		engine.position = Vector3(x, -0.2, -1.6)
		add_child(engine)


func _process(delta: float) -> void:
	global_position += direction * SPEED * delta
	_life -= delta
	if _life <= 0.0:
		queue_free()
