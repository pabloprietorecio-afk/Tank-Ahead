class_name PropFactory
## Construye por código los objetos del escenario. Todos son `Destructible`.

const TREE_GREEN := Color(0.16, 0.32, 0.12)
const BRICK := Color(0.55, 0.3, 0.22)
const ROOF := Color(0.38, 0.16, 0.12)
const FENCE_COLOR := Color(0.45, 0.33, 0.2)
const ROCK_COLOR := Color(0.42, 0.4, 0.37)
const WOOD := Color(0.32, 0.22, 0.13)
const CONCRETE := Color(0.5, 0.5, 0.48)

static var _trunk: CylinderMesh
static var _crown: CylinderMesh
static var _roof: PrismMesh
## Color de las montañas del frente actual.
static var mountain_color: Color = Color(0.33, 0.31, 0.27)


static func block(size: Vector3) -> Destructible:
	var prop := _base(clampf(size.x * size.y * size.z * 0.15, 60.0, 400.0), Color(0.4, 0.8, 0.45), size.y * 0.3)
	_add_box_shape(prop, size, Vector3(0.0, size.y * 0.5, 0.0))
	# Edificios altos con plantas y ventanas; bloques bajos con paneles.
	var mesh := VectorMaterials.make_box(size, CONCRETE if size.y > 8.0 else CONCRETE.darkened(0.15), 1 if size.y > 8.0 else 0, 3.0 if size.y > 8.0 else 2.0)
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
	var trunk := VectorMaterials.make_outlined(_trunk, WOOD, WOOD.darkened(0.6), 1, 0.5)
	trunk.scale = Vector3(1.0, height * 0.35, 1.0)
	trunk.position.y = height * 0.175
	prop.add_child(trunk)
	var crown := VectorMaterials.make_outlined(_crown, TREE_GREEN, Color(0.28, 0.45, 0.16), 2, 0.4)
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
	var walls := VectorMaterials.make_box(size, BRICK, 2, 1.2)
	walls.position.y = size.y * 0.5
	prop.add_child(walls)
	var roof := VectorMaterials.make_outlined(_roof, ROOF, ROOF.darkened(0.5), 5, 0.6)
	roof.scale = Vector3(size.x * 1.1, size.y * 0.6, size.z * 1.05)
	roof.position.y = size.y + size.y * 0.3
	prop.add_child(roof)
	var chimney := VectorMaterials.make_box(Vector3(0.8, 2.2, 0.8), BRICK.darkened(0.2), 2, 0.8)
	chimney.position = Vector3(size.x * 0.28, size.y + 1.1, -size.z * 0.2)
	prop.add_child(chimney)
	# Puerta y ventanas como pequeñas cajas en la fachada.
	var door := VectorMaterials.make_box(Vector3(1.2, 2.0, 0.1), WOOD, 5, 0.8)
	door.position = Vector3(0.0, 1.0, size.z * 0.5 + 0.06)
	prop.add_child(door)
	for side in [-1.0, 1.0]:
		var window := VectorMaterials.make_box(Vector3(1.0, 0.9, 0.1), Color(0.25, 0.3, 0.35), 1, 0.9)
		window.position = Vector3(side * size.x * 0.3, size.y * 0.62, size.z * 0.5 + 0.06)
		prop.add_child(window)
	return prop


static func fence(length: float) -> Destructible:
	var prop := _base(8.0, WOOD, 0.4)
	prop.crushable = true
	var posts: int = int(length / 2.0) + 1
	for i in posts:
		var post := VectorMaterials.make_box(Vector3(0.15, 1.3, 0.15), FENCE_COLOR, 5, 0.3)
		post.position = Vector3(-length * 0.5 + i * length / float(posts - 1), 0.65, 0.0)
		prop.add_child(post)
	for y in [0.45, 1.0]:
		var rail := VectorMaterials.make_box(Vector3(length, 0.1, 0.08), FENCE_COLOR, 5, 0.6)
		rail.position.y = y
		prop.add_child(rail)
	_add_box_shape(prop, Vector3(length, 1.3, 0.3), Vector3(0.0, 0.65, 0.0))
	return prop


static func rock(radius: float) -> Destructible:
	var prop := _base(45.0 * radius, ROCK_COLOR, radius)
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * randf_range(1.0, 1.5)
	mesh.radial_segments = 6
	mesh.rings = 3
	var visual := VectorMaterials.make_outlined(mesh, ROCK_COLOR, ROCK_COLOR.darkened(0.55), 3, 0.5)
	visual.position.y = mesh.height * 0.35
	visual.rotation = Vector3(randf() * 0.3, randf() * TAU, randf() * 0.3)
	prop.add_child(visual)
	var shape := CollisionShape3D.new()
	shape.shape = mesh.create_convex_shape()
	shape.position.y = mesh.height * 0.35
	prop.add_child(shape)
	return prop


static func barrel() -> Destructible:
	var prop := _base(6.0, Color(1.0, 0.6, 0.2), 1.8)
	prop.blast_radius = 12.0
	prop.blast_damage = 60.0
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.5
	mesh.bottom_radius = 0.5
	mesh.height = 1.3
	mesh.radial_segments = 8
	mesh.rings = 2
	var visual := VectorMaterials.make_outlined(mesh, Color(0.6, 0.12, 0.08), Color(0.2, 0.18, 0.15), 4, 0.5)
	visual.position.y = 0.65
	prop.add_child(visual)
	_add_box_shape(prop, Vector3(1.0, 1.3, 1.0), Vector3(0.0, 0.65, 0.0))
	return prop


## Muro en ruinas: tramos de ladrillo de alturas irregulares.
static func ruin(length: float) -> Destructible:
	var prop := _base(70.0, Color(0.6, 0.55, 0.45), 2.0)
	var pieces: int = 4
	var piece_length: float = length / pieces
	for i in pieces:
		var height: float = randf_range(1.0, 4.5)
		var piece := VectorMaterials.make_box(Vector3(piece_length * 0.95, height, 0.8), BRICK.darkened(0.2), 2, 1.0)
		piece.position = Vector3(-length * 0.5 + piece_length * (i + 0.5), height * 0.5, 0.0)
		prop.add_child(piece)
	_add_box_shape(prop, Vector3(length, 3.0, 0.8), Vector3(0.0, 1.5, 0.0))
	return prop


static func lamp_post() -> Destructible:
	var prop := _base(10.0, Color(0.7, 0.7, 0.6), 0.6)
	prop.crushable = true
	var pole := VectorMaterials.make_box(Vector3(0.18, 5.0, 0.18), Color(0.25, 0.27, 0.28), 4, 0.8)
	pole.position.y = 2.5
	prop.add_child(pole)
	var arm := VectorMaterials.make_box(Vector3(1.4, 0.12, 0.12), Color(0.25, 0.27, 0.28))
	arm.position = Vector3(0.6, 5.0, 0.0)
	prop.add_child(arm)
	var lamp := MeshInstance3D.new()
	var bulb := BoxMesh.new()
	bulb.size = Vector3(0.45, 0.2, 0.3)
	lamp.mesh = bulb
	lamp.material_override = VectorMaterials.flat(Color(1.0, 0.95, 0.6))
	lamp.position = Vector3(1.2, 4.85, 0.0)
	prop.add_child(lamp)
	_add_box_shape(prop, Vector3(0.4, 5.0, 0.4), Vector3(0.0, 2.5, 0.0))
	return prop


## Manzano de Normandía: copa redonda.
static func apple_tree(height: float) -> Destructible:
	var prop := _base(20.0, WOOD, 1.0)
	prop.crushable = true
	var trunk := VectorMaterials.make_outlined(_trunk_mesh(), WOOD, WOOD.darkened(0.6), 1, 0.5)
	trunk.scale = Vector3(1.0, height * 0.45, 1.0)
	trunk.position.y = height * 0.225
	prop.add_child(trunk)
	var crown_mesh := SphereMesh.new()
	crown_mesh.radial_segments = 10
	crown_mesh.rings = 6
	var crown := VectorMaterials.make_outlined(crown_mesh, Color(0.2, 0.35, 0.12), Color(0.3, 0.42, 0.14), 2, 0.25)
	crown.scale = Vector3.ONE * height * 0.7
	crown.position.y = height * 0.7
	prop.add_child(crown)
	_add_box_shape(prop, Vector3(0.8, height, 0.8), Vector3(0.0, height * 0.5, 0.0))
	return prop


## Abedul de la estepa: tronco blanco y fino.
static func birch(height: float) -> Destructible:
	var prop := _base(15.0, Color(0.85, 0.85, 0.8), 1.0)
	prop.crushable = true
	var trunk := VectorMaterials.make_outlined(_trunk_mesh(), Color(0.85, 0.84, 0.78), Color(0.1, 0.1, 0.1), 1, 0.25)
	trunk.scale = Vector3(0.6, height * 0.7, 0.6)
	trunk.position.y = height * 0.35
	prop.add_child(trunk)
	var crown_mesh := SphereMesh.new()
	crown_mesh.radial_segments = 8
	crown_mesh.rings = 5
	var crown := VectorMaterials.make_outlined(crown_mesh, Color(0.32, 0.42, 0.14), Color(0.2, 0.28, 0.1), 2, 0.3)
	crown.scale = Vector3(height * 0.35, height * 0.55, height * 0.35)
	crown.position.y = height * 0.78
	prop.add_child(crown)
	_add_box_shape(prop, Vector3(0.5, height, 0.5), Vector3(0.0, height * 0.5, 0.0))
	return prop


## Palmera del desierto: tronco alto y hojas en estrella.
static func palm(height: float) -> Destructible:
	var prop := _base(18.0, WOOD, 1.0)
	prop.crushable = true
	var trunk := VectorMaterials.make_outlined(_trunk_mesh(), Color(0.45, 0.35, 0.22), Color(0.2, 0.15, 0.08), 1, 0.15)
	trunk.scale = Vector3(0.7, height, 0.7)
	trunk.position.y = height * 0.5
	trunk.rotation.z = randf_range(-0.12, 0.12)
	prop.add_child(trunk)
	for i in 7:
		var leaf := VectorMaterials.make_box(Vector3(0.5, 0.06, height * 0.42), Color(0.25, 0.4, 0.12), 6, 0.15)
		var angle: float = TAU * i / 7.0
		leaf.position = Vector3(sin(angle), 0.0, cos(angle)) * height * 0.18 + Vector3.UP * (height - 0.2)
		leaf.rotation = Vector3(deg_to_rad(25.0), angle, 0.0)
		prop.add_child(leaf)
	_add_box_shape(prop, Vector3(0.6, height, 0.6), Vector3(0.0, height * 0.5, 0.0))
	return prop


## Seto de bocage normando: muro de tierra con vegetación, resistente.
static func hedgerow(length: float) -> Destructible:
	var prop := _base(90.0, Color(0.3, 0.4, 0.15), 1.5)
	var bank := VectorMaterials.make_box(Vector3(length, 1.2, 2.2), Color(0.3, 0.24, 0.15), 0, 1.0)
	bank.position.y = 0.6
	prop.add_child(bank)
	var bush_mesh := SphereMesh.new()
	bush_mesh.radial_segments = 8
	bush_mesh.rings = 4
	var count: int = int(length / 2.5)
	for i in count:
		var bush := VectorMaterials.make_outlined(bush_mesh, Color(0.16, 0.3, 0.1), Color(0.1, 0.2, 0.06), 2, 0.4)
		bush.scale = Vector3(randf_range(2.4, 3.2), randf_range(2.0, 3.0), 2.4)
		bush.position = Vector3(-length * 0.5 + (i + 0.5) * length / count, 2.0, 0.0)
		prop.add_child(bush)
	_add_box_shape(prop, Vector3(length, 3.0, 2.4), Vector3(0.0, 1.5, 0.0))
	return prop


## Casa del desierto: encalada, de azotea plana con pretil.
static func desert_house(size: Vector3) -> Destructible:
	var prop := _base(120.0, Color(0.85, 0.8, 0.7), size.y)
	_add_box_shape(prop, size, Vector3(0.0, size.y * 0.5, 0.0))
	var walls := VectorMaterials.make_box(size, Color(0.82, 0.78, 0.68), 0, 1.5)
	walls.position.y = size.y * 0.5
	prop.add_child(walls)
	var parapet := VectorMaterials.make_box(Vector3(size.x, 0.5, size.z), Color(0.78, 0.74, 0.64), 0, 1.0)
	parapet.position.y = size.y + 0.25
	prop.add_child(parapet)
	var door := VectorMaterials.make_box(Vector3(1.2, 2.0, 0.1), Color(0.2, 0.35, 0.5), 5, 0.8)
	door.position = Vector3(0.0, 1.0, size.z * 0.5 + 0.06)
	prop.add_child(door)
	for side in [-1.0, 1.0]:
		var window := VectorMaterials.make_box(Vector3(0.8, 0.8, 0.1), Color(0.15, 0.15, 0.15))
		window.position = Vector3(side * size.x * 0.3, size.y * 0.6, size.z * 0.5 + 0.06)
		prop.add_child(window)
	return prop


## Isba rusa de troncos con tejado a dos aguas.
static func izba(size: Vector3) -> Destructible:
	if _roof == null:
		_roof = PrismMesh.new()
		_roof.size = Vector3.ONE
	var prop := _base(100.0, WOOD, size.y)
	_add_box_shape(prop, size, Vector3(0.0, size.y * 0.5, 0.0))
	var walls := VectorMaterials.make_box(size, Color(0.4, 0.28, 0.17), 5, 1.6)
	walls.position.y = size.y * 0.5
	prop.add_child(walls)
	var roof := VectorMaterials.make_outlined(_roof, Color(0.3, 0.3, 0.28), Color(0.2, 0.2, 0.18), 6, 0.5)
	roof.scale = Vector3(size.x * 1.15, size.y * 0.7, size.z * 1.1)
	roof.position.y = size.y + size.y * 0.35
	prop.add_child(roof)
	for side in [-1.0, 1.0]:
		var window := VectorMaterials.make_box(Vector3(0.8, 0.9, 0.1), Color(0.5, 0.65, 0.4), 4, 0.4)
		window.position = Vector3(side * size.x * 0.28, size.y * 0.55, size.z * 0.5 + 0.06)
		prop.add_child(window)
	return prop


## Iglesia de pueblo normando: nave y campanario (con premio: la campana) por separado.
static func church() -> Node3D:
	if _roof == null:
		_roof = PrismMesh.new()
		_roof.size = Vector3.ONE
	var root := Node3D.new()
	var stone := Color(0.55, 0.53, 0.48)
	var nave := _base(250.0, Color(0.6, 0.58, 0.52), 6.0)
	var walls := VectorMaterials.make_box(Vector3(8.0, 7.0, 16.0), stone, 2, 1.8)
	walls.position.y = 3.5
	nave.add_child(walls)
	var roof := VectorMaterials.make_outlined(_roof, Color(0.25, 0.27, 0.3), Color(0.15, 0.16, 0.18), 5, 0.6)
	roof.scale = Vector3(8.6, 4.0, 16.4)
	roof.position.y = 9.0
	nave.add_child(roof)
	_add_box_shape(nave, Vector3(8.0, 9.0, 16.0), Vector3(0.0, 4.5, 0.0))
	root.add_child(nave)

	var tower := _base(160.0, Color(0.6, 0.58, 0.52), 5.0)
	tower.prize_points = 400
	tower.prize_name = "CAMPANARIO"
	tower.destroy_sound = Sfx.BELL
	tower.position = Vector3(0.0, 0.0, 9.5)
	var shaft := VectorMaterials.make_box(Vector3(4.0, 12.0, 4.0), stone, 2, 1.8)
	shaft.position.y = 6.0
	tower.add_child(shaft)
	# Campanario abierto con la campana de bronce.
	for x in [-1.7, 1.7]:
		for z in [-1.7, 1.7]:
			var pillar := VectorMaterials.make_box(Vector3(0.6, 3.0, 0.6), stone, 2, 1.0)
			pillar.position = Vector3(x, 13.5, z)
			tower.add_child(pillar)
	var bell_mesh := CylinderMesh.new()
	bell_mesh.top_radius = 0.45
	bell_mesh.bottom_radius = 0.9
	bell_mesh.height = 1.3
	bell_mesh.radial_segments = 12
	var bell := VectorMaterials.make_outlined(bell_mesh, Color(0.7, 0.5, 0.2), Color(0.4, 0.3, 0.1), 4, 0.4)
	bell.position.y = 13.4
	tower.add_child(bell)
	var cap := VectorMaterials.make_box(Vector3(4.2, 0.5, 4.2), stone, 0, 1.0)
	cap.position.y = 15.2
	tower.add_child(cap)
	var spire_mesh := CylinderMesh.new()
	spire_mesh.top_radius = 0.0
	spire_mesh.bottom_radius = 2.8
	spire_mesh.height = 6.0
	spire_mesh.radial_segments = 4
	var spire := VectorMaterials.make_outlined(spire_mesh, Color(0.25, 0.27, 0.3), Color(0.15, 0.16, 0.18), 5, 0.6)
	spire.position.y = 18.4
	spire.rotation.y = PI * 0.25
	tower.add_child(spire)
	_add_box_shape(tower, Vector3(4.0, 16.0, 4.0), Vector3(0.0, 8.0, 0.0))
	_mark_prize(tower)
	root.add_child(tower)
	return root


static func _mark_prize(prop: Destructible) -> void:
	prop.add_to_group(&"radar_marks")
	prop.set_meta("radar_color", Color(0.4, 1.0, 0.5))
	prop.set_meta("radar_shape", "ring")


## Almiar de heno (estepa): se atraviesa con el tanque.
static func haystack() -> Destructible:
	var prop := _base(8.0, Color(0.75, 0.65, 0.3), 1.2)
	prop.crushable = true
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.3
	mesh.bottom_radius = 1.8
	mesh.height = 3.2
	mesh.radial_segments = 10
	var hay := VectorMaterials.make_outlined(mesh, Color(0.72, 0.6, 0.28), Color(0.55, 0.45, 0.2), 6, 0.2)
	hay.position.y = 1.6
	prop.add_child(hay)
	_add_box_shape(prop, Vector3(2.6, 3.0, 2.6), Vector3(0.0, 1.5, 0.0))
	return prop


## Erizo checo antitanque: tres vigas cruzadas, muy duro.
static func hedgehog() -> Destructible:
	var prop := _base(150.0, Color(0.3, 0.28, 0.26), 0.8)
	for axis in 3:
		var beam := VectorMaterials.make_box(Vector3(0.25, 0.25, 2.6), Color(0.2, 0.19, 0.18), 4, 0.5)
		beam.position.y = 0.9
		beam.rotation = [Vector3(0.6, 0.0, 0.0), Vector3(-0.6, PI * 0.5, 0.0), Vector3(0.0, 0.0, PI * 0.5 - 0.4)][axis]
		prop.add_child(beam)
	_add_box_shape(prop, Vector3(2.0, 1.8, 2.0), Vector3(0.0, 0.9, 0.0))
	return prop


## Parapeto de sacos terreros.
static func sandbags(length: float) -> Destructible:
	var prop := _base(60.0, Color(0.65, 0.58, 0.42), 0.8)
	for row in 3:
		var bags := VectorMaterials.make_box(Vector3(length - row * 0.3, 0.45, 1.0 - row * 0.15), Color(0.62, 0.55, 0.4), 2, 0.9)
		bags.position.y = 0.22 + row * 0.44
		prop.add_child(bags)
	_add_box_shape(prop, Vector3(length, 1.35, 1.0), Vector3(0.0, 0.67, 0.0))
	return prop


## Depósito de suministros (objetivo de misión): cajas y bidones bajo una lona.
static func supply_depot() -> Destructible:
	var prop := _base(160.0, Color(1.0, 0.6, 0.2), 3.0)
	prop.blast_radius = 14.0
	prop.blast_damage = 50.0
	for i in 6:
		var crate := VectorMaterials.make_box(Vector3(1.4, 1.1, 1.4), Color(0.4, 0.33, 0.2), 5, 0.6)
		crate.position = Vector3((i % 3 - 1) * 1.6, 0.55 + (i / 3) * 1.1, -1.5)
		prop.add_child(crate)
	var drum_mesh := CylinderMesh.new()
	drum_mesh.top_radius = 0.45
	drum_mesh.bottom_radius = 0.45
	drum_mesh.height = 1.2
	drum_mesh.radial_segments = 8
	for i in 8:
		var drum := VectorMaterials.make_outlined(drum_mesh, Color(0.25, 0.3, 0.2), Color(0.12, 0.12, 0.1), 4, 0.5)
		drum.position = Vector3(-2.2 + (i % 4) * 1.0, 0.6, 1.0 + (i / 4) * 1.0)
		prop.add_child(drum)
	var tarp := VectorMaterials.make_box(Vector3(6.0, 0.1, 6.5), Color(0.3, 0.32, 0.22), 6, 0.4)
	tarp.position.y = 3.0
	prop.add_child(tarp)
	for x in [-2.8, 2.8]:
		for z in [-3.0, 3.0]:
			var post := VectorMaterials.make_box(Vector3(0.15, 3.0, 0.15), WOOD)
			post.position = Vector3(x, 1.5, z)
			prop.add_child(post)
	_add_box_shape(prop, Vector3(5.5, 2.4, 5.5), Vector3(0.0, 1.2, 0.0))
	prop.add_to_group(&"radar_marks")
	prop.set_meta("radar_color", Color(1.0, 0.75, 0.1))
	return prop


static func _trunk_mesh() -> CylinderMesh:
	if _trunk == null:
		_trunk = CylinderMesh.new()
		_trunk.top_radius = 0.25
		_trunk.bottom_radius = 0.35
		_trunk.height = 1.0
		_trunk.radial_segments = 6
		_trunk.rings = 0
	return _trunk


static func mountain(radius: float, height: float, segments: int = 7) -> Destructible:
	var prop := _base(1.0, ROCK_COLOR, height * 0.2)
	prop.indestructible = true
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * randf_range(0.05, 0.25)
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 1
	var visual := VectorMaterials.make_outlined(mesh, mountain_color, mountain_color.darkened(0.45), 3, 3.0)
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
