class_name PropFactory
## Construye por código los objetos del escenario. Todos son `Destructible`.

const TREE_GREEN := Color(0.25, 0.85, 0.3)
const HOUSE_CYAN := Color(0.3, 0.9, 1.0)
const FENCE_COLOR := Color(0.7, 0.8, 0.4)
const ROCK_COLOR := Color(0.45, 0.6, 0.5)
const WOOD := Color(0.6, 0.45, 0.25)

static var _trunk: CylinderMesh
static var _crown: CylinderMesh
static var _roof: PrismMesh


static func block(size: Vector3) -> Destructible:
	var prop := _base(clampf(size.x * size.y * size.z * 0.15, 60.0, 400.0), Color(0.4, 0.8, 0.45), size.y * 0.3)
	_add_box_shape(prop, size, Vector3(0.0, size.y * 0.5, 0.0))
	var mesh := VectorMaterials.make_box(size)
	mesh.position.y = size.y * 0.5
	prop.add_child(mesh)
	return prop


static func tree(height: float) -> Destructible:
	if _trunk == null:
		_trunk = CylinderMesh.new()
		_trunk.top_radius = 0.25
		_trunk.bottom_radius = 0.35
		_trunk.height = 1.0
		_trunk.radial_segments = 6
		_trunk.rings = 0
		_crown = CylinderMesh.new()
		_crown.top_radius = 0.0
		_crown.bottom_radius = 1.0
		_crown.height = 1.0
		_crown.radial_segments = 6
		_crown.rings = 0
	var prop := _base(20.0, WOOD, 1.2)
	prop.crushable = true
	var trunk := VectorMaterials.make_outlined(_trunk, WOOD)
	trunk.scale = Vector3(1.0, height * 0.35, 1.0)
	trunk.position.y = height * 0.175
	prop.add_child(trunk)
	var crown := VectorMaterials.make_outlined(_crown, TREE_GREEN)
	crown.scale = Vector3(height * 0.3, height * 0.75, height * 0.3)
	crown.position.y = height * 0.35 + height * 0.375
	prop.add_child(crown)
	_add_box_shape(prop, Vector3(0.8, height, 0.8), Vector3(0.0, height * 0.5, 0.0))
	return prop


static func house(size: Vector3) -> Destructible:
	if _roof == null:
		_roof = PrismMesh.new()
		_roof.size = Vector3.ONE
	var prop := _base(140.0, Color(0.6, 0.6, 0.55), size.y)
	_add_box_shape(prop, size, Vector3(0.0, size.y * 0.5, 0.0))
	var walls := VectorMaterials.make_box(size, HOUSE_CYAN)
	walls.position.y = size.y * 0.5
	prop.add_child(walls)
	var roof := VectorMaterials.make_outlined(_roof, HOUSE_CYAN)
	roof.scale = Vector3(size.x * 1.1, size.y * 0.6, size.z * 1.05)
	roof.position.y = size.y + size.y * 0.3
	prop.add_child(roof)
	# Puerta y ventanas como pequeñas cajas en la fachada.
	var door := VectorMaterials.make_box(Vector3(1.2, 2.0, 0.1), HOUSE_CYAN)
	door.position = Vector3(0.0, 1.0, size.z * 0.5 + 0.06)
	prop.add_child(door)
	for side in [-1.0, 1.0]:
		var window := VectorMaterials.make_box(Vector3(1.0, 0.9, 0.1), HOUSE_CYAN)
		window.position = Vector3(side * size.x * 0.3, size.y * 0.62, size.z * 0.5 + 0.06)
		prop.add_child(window)
	return prop


static func fence(length: float) -> Destructible:
	var prop := _base(8.0, WOOD, 0.4)
	prop.crushable = true
	var posts: int = int(length / 2.0) + 1
	for i in posts:
		var post := VectorMaterials.make_box(Vector3(0.15, 1.3, 0.15), FENCE_COLOR)
		post.position = Vector3(-length * 0.5 + i * length / float(posts - 1), 0.65, 0.0)
		prop.add_child(post)
	for y in [0.45, 1.0]:
		var rail := VectorMaterials.make_box(Vector3(length, 0.1, 0.08), FENCE_COLOR)
		rail.position.y = y
		prop.add_child(rail)
	_add_box_shape(prop, Vector3(length, 1.3, 0.3), Vector3(0.0, 0.65, 0.0))
	return prop


static func mountain(radius: float, height: float, segments: int = 7) -> Destructible:
	var prop := _base(1.0, ROCK_COLOR, height * 0.2)
	prop.indestructible = true
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * randf_range(0.05, 0.25)
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 1
	var visual := VectorMaterials.make_outlined(mesh, Color(0.25, 0.8, 0.35))
	visual.position.y = height * 0.5
	prop.add_child(visual)
	var shape := CollisionShape3D.new()
	shape.shape = mesh.create_convex_shape()
	shape.position.y = height * 0.5
	prop.add_child(shape)
	return prop


static func _base(health: float, debris: Color, size_hint: float) -> Destructible:
	var prop := Destructible.new()
	prop.max_health = health
	prop.debris_color = debris
	prop.size_hint = size_hint
	return prop


static func _add_box_shape(prop: Node3D, size: Vector3, offset: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = offset
	prop.add_child(shape)
