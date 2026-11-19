class_name PropFactory
## Construye por código los objetos del escenario. Todos son `Destructible`.

const TREE_GREEN := Color(0.16, 0.32, 0.12)
const BRICK := Color(0.55, 0.3, 0.22)
const ROOF := Color(0.38, 0.16, 0.12)
const FENCE_COLOR := Color(0.45, 0.33, 0.2)
const ROCK_COLOR := Color(0.42, 0.4, 0.37)
const WOOD := Color(0.32, 0.22, 0.13)
const CONCRETE := Color(0.5, 0.5, 0.48)

## Distancia (m) a partir de la cual dejan de dibujarse las piezas de adorno (ventanas, puertas...).
const DECOR_RANGE: float = 170.0

static var _trunk: CylinderMesh
static var _roof: PrismMesh
static var _meshes: Dictionary = {}
## Color de las montañas del frente actual.
static var mountain_color: Color = Color(0.33, 0.31, 0.27)


static func block(size: Vector3) -> Destructible:
	var prop := _base(clampf(size.x * size.y * size.z * 0.15, 60.0, 400.0), Color(0.62, 0.6, 0.55), size.y * 0.3)
	_add_box_shape(prop, size, Vector3(0.0, size.y * 0.5, 0.0))
	# Edificios altos con plantas y ventanas; bloques bajos con paneles.
	var mesh := VectorMaterials.make_box(size, CONCRETE if size.y > 8.0 else CONCRETE.darkened(0.15), 1 if size.y > 8.0 else 0, 3.0 if size.y > 8.0 else 2.0)
	mesh.position.y = size.y * 0.5
	prop.add_child(mesh)
	return prop


static func tree(height: float) -> Destructible:
	var prop := _base(20.0, WOOD, 1.2)
	prop.crushable = true
	prop.topples = true
	prop.burns = 16.0
	var trunk := VectorMaterials.make_outlined(_trunk_mesh(), WOOD, WOOD.darkened(0.6), 1, 0.5)
	trunk.scale = Vector3(1.0, height * 0.4, 1.0)
	trunk.position.y = height * 0.2
	prop.add_child(trunk)
	# Abeto: tres pisos de ramas fundidos en una malla.
	var crown := MeshInstance3D.new()
	crown.mesh = _conifer_mesh()
	crown.material_override = VectorMaterials.organic(TREE_GREEN.darkened(0.15), Color(0.24, 0.4, 0.16), 2, 0.4, 0.22, 0.008)
	crown.scale = Vector3(height * 0.62, height * 0.8, height * 0.62)
	crown.position.y = height * 0.22
	crown.rotation.y = randf() * TAU
	crown.set_meta(&"foliage", true)
	prop.add_child(crown)
	_add_box_shape(prop, Vector3(0.8, height, 0.8), Vector3(0.0, height * 0.5, 0.0))
	return prop


static func house(size: Vector3) -> Destructible:
	if _roof == null:
		_roof = PrismMesh.new()
		_roof.size = Vector3.ONE
	var prop := _base(140.0, Color(0.6, 0.6, 0.55), size.y)
	prop.burns = 50.0
	_add_box_shape(prop, size, Vector3(0.0, size.y * 0.5, 0.0))
	# Mitad de las casas enlucidas (con desconchones) y mitad de ladrillo visto.
	var plastered: bool = randf() < 0.55
	var plaster: Color = [Color(0.8, 0.74, 0.6), Color(0.74, 0.7, 0.62), Color(0.78, 0.66, 0.52)][randi() % 3]
	var walls := VectorMaterials.make_box(size, plaster if plastered else BRICK, 9 if plastered else 2, 1.2)
	walls.position.y = size.y * 0.5
	prop.add_child(walls)
	var plinth := VectorMaterials.make_box(Vector3(size.x + 0.14, 0.55, size.z + 0.14), Color(0.48, 0.46, 0.42), 2, 2.0)
	plinth.position.y = 0.275
	prop.add_child(plinth)
	var roof_color: Color = ROOF if randf() < 0.7 else Color(0.27, 0.28, 0.31)
	var roof := VectorMaterials.make_outlined(_roof, roof_color, roof_color.darkened(0.5), 5, 0.6)
	roof.scale = Vector3(size.x * 1.14, size.y * 0.62, size.z * 1.1)
	roof.position.y = size.y + size.y * 0.31
	prop.add_child(roof)
	var chimney := VectorMaterials.make_box(Vector3(0.8, 2.4, 0.8), BRICK.darkened(0.2), 2, 0.8)
	chimney.position = Vector3(size.x * 0.28, size.y + 1.2, -size.z * 0.2)
	prop.add_child(chimney)
	_decor(prop, Vector3(1.0, 0.12, 1.0), Vector3(size.x * 0.28, size.y + 2.45, -size.z * 0.2), Color(0.4, 0.38, 0.35), 0, 1.0)
	# Puerta, ventanas con contraventanas en la fachada y ventanas en las otras caras.
	var shutter: Color = [Color(0.2, 0.32, 0.24), Color(0.25, 0.3, 0.42), Color(0.45, 0.2, 0.16)][randi() % 3]
	_decor(prop, Vector3(1.2, 2.1, 0.14), Vector3(0.0, 1.05, size.z * 0.5 + 0.04), shutter.darkened(0.2), 8, 0.8)
	_decor(prop, Vector3(1.5, 0.16, 0.3), Vector3(0.0, 0.08, size.z * 0.5 + 0.2), Color(0.5, 0.48, 0.44), 0, 1.0)
	var window_y: float = size.y * 0.6
	for side in [-1.0, 1.0]:
		var x: float = side * size.x * 0.3
		_decor(prop, Vector3(1.0, 1.15, 0.14), Vector3(x, window_y, size.z * 0.5 + 0.04), Color(0.25, 0.3, 0.35), 7, 0.9)
		_decor(prop, Vector3(1.2, 0.1, 0.24), Vector3(x, window_y - 0.62, size.z * 0.5 + 0.08), Color(0.55, 0.53, 0.48), 0, 1.0)
		for leaf in [-1.0, 1.0]:
			_decor(prop, Vector3(0.42, 1.15, 0.06), Vector3(x + leaf * 0.73, window_y, size.z * 0.5 + 0.05), shutter, 5, 0.5)
		_decor(prop, Vector3(1.0, 1.15, 0.14), Vector3(x, window_y, -size.z * 0.5 - 0.04), Color(0.25, 0.3, 0.35), 7, 0.9)
		_decor(prop, Vector3(0.14, 1.15, 1.0), Vector3(side * (size.x * 0.5 + 0.04), window_y, size.z * 0.15), Color(0.25, 0.3, 0.35), 7, 0.9)
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
	# Malla visible más fina y deformada con ruido: peñasco irregular de caras planas.
	var fine := SphereMesh.new()
	fine.radius = radius
	fine.height = mesh.height
	fine.radial_segments = 10
	fine.rings = 5
	var tone: Color = ROCK_COLOR.lerp(mountain_color, 0.25).lightened(snappedf(randf_range(-0.08, 0.08), 0.04))
	var visual := MeshInstance3D.new()
	visual.mesh = fine
	visual.material_override = VectorMaterials.organic(tone, tone.darkened(0.55), 3, 0.5, 0.5)
	visual.position.y = mesh.height * 0.3
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
	prop.burns = 14.0
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
	var pieces: int = 5
	var piece_length: float = length / pieces
	for i in pieces:
		var height: float = randf_range(1.0, 4.5)
		var piece := VectorMaterials.make_box(Vector3(piece_length, height, 0.8), Color(0.7, 0.66, 0.56) if i % 2 == 0 else BRICK.darkened(0.2), 9 if i % 2 == 0 else 2, 1.0)
		piece.position = Vector3(-length * 0.5 + piece_length * (i + 0.5), height * 0.5, 0.0)
		prop.add_child(piece)
		# Remate roto en escalón.
		if height > 2.0:
			var step := VectorMaterials.make_box(Vector3(piece_length * 0.5, 0.6, 0.8), BRICK.darkened(0.2), 2, 1.0)
			step.position = Vector3(piece.position.x - piece_length * 0.25, height + 0.3, 0.0)
			prop.add_child(step)
	# Cascotes al pie del muro.
	for i in 7:
		var size := Vector3(randf_range(0.4, 1.1), randf_range(0.25, 0.6), randf_range(0.4, 0.9))
		var chunk := _decor(prop, size, Vector3(randf_range(-length * 0.5, length * 0.5), size.y * 0.35, randf_range(0.7, 2.2) * (1.0 if i % 2 == 0 else -1.0)), BRICK.darkened(randf_range(0.1, 0.4)), 2, 0.9)
		chunk.rotation = Vector3(randf_range(-0.4, 0.4), randf() * TAU, randf_range(-0.4, 0.4))
	_add_box_shape(prop, Vector3(length, 3.0, 0.8), Vector3(0.0, 1.5, 0.0))
	return prop


static func lamp_post() -> Destructible:
	var prop := _base(10.0, Color(0.7, 0.7, 0.6), 0.6)
	prop.crushable = true
	prop.topples = true
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
	prop.topples = true
	prop.burns = 16.0
	var trunk := VectorMaterials.make_outlined(_trunk_mesh(), WOOD, WOOD.darkened(0.6), 1, 0.5)
	trunk.scale = Vector3(1.1, height * 0.5, 1.1)
	trunk.position.y = height * 0.25
	prop.add_child(trunk)
	var crown := MeshInstance3D.new()
	crown.mesh = _crown_mesh(randi() % 3)
	crown.material_override = VectorMaterials.organic(Color(0.2, 0.35, 0.12), Color(0.33, 0.46, 0.15), 2, 0.25, 0.45, 0.012)
	crown.scale = Vector3(height * 0.72, height * 0.62, height * 0.72)
	crown.position.y = height * 0.7
	crown.rotation.y = randf() * TAU
	crown.set_meta(&"foliage", true)
	prop.add_child(crown)
	_add_box_shape(prop, Vector3(0.8, height, 0.8), Vector3(0.0, height * 0.5, 0.0))
	return prop


## Abedul de la estepa: tronco blanco y fino.
static func birch(height: float) -> Destructible:
	var prop := _base(15.0, Color(0.85, 0.85, 0.8), 1.0)
	prop.crushable = true
	prop.topples = true
	prop.burns = 14.0
	var trunk := VectorMaterials.make_outlined(_trunk_mesh(), Color(0.85, 0.84, 0.78), Color(0.1, 0.1, 0.1), 1, 0.25)
	trunk.scale = Vector3(0.6, height * 0.72, 0.6)
	trunk.position.y = height * 0.36
	prop.add_child(trunk)
	var crown := MeshInstance3D.new()
	crown.mesh = _crown_mesh(randi() % 3)
	crown.material_override = VectorMaterials.organic(Color(0.3, 0.42, 0.14), Color(0.45, 0.5, 0.16), 2, 0.3, 0.5, 0.018)
	crown.scale = Vector3(height * 0.4, height * 0.58, height * 0.4)
	crown.position.y = height * 0.76
	crown.rotation.y = randf() * TAU
	crown.set_meta(&"foliage", true)
	prop.add_child(crown)
	_add_box_shape(prop, Vector3(0.5, height, 0.5), Vector3(0.0, height * 0.5, 0.0))
	return prop


## Palmera del desierto: tronco alto y hojas en estrella.
static func palm(height: float) -> Destructible:
	var prop := _base(18.0, WOOD, 1.0)
	prop.crushable = true
	prop.topples = true
	prop.burns = 14.0
	var trunk := VectorMaterials.make_outlined(_trunk_mesh(), Color(0.45, 0.35, 0.22), Color(0.2, 0.15, 0.08), 1, 0.15)
	trunk.scale = Vector3(0.7, height, 0.7)
	trunk.position.y = height * 0.5
	var lean: float = randf_range(-0.12, 0.12)
	trunk.rotation.z = lean
	prop.add_child(trunk)
	# Penacho de hojas arqueadas, fundido en una sola malla.
	var crown := MeshInstance3D.new()
	crown.mesh = _palm_mesh()
	crown.material_override = VectorMaterials.organic(Color(0.24, 0.4, 0.12), Color(0.4, 0.5, 0.16), 2, 0.12, 0.0, 0.01)
	crown.scale = Vector3.ONE * height
	crown.position = Vector3(-sin(lean) * height * 0.5, height - 0.15, 0.0)
	crown.rotation.y = randf() * TAU
	crown.set_meta(&"foliage", true)
	prop.add_child(crown)
	_add_box_shape(prop, Vector3(0.6, height, 0.6), Vector3(0.0, height * 0.5, 0.0))
	return prop


## Seto de bocage normando: muro de tierra con vegetación, resistente.
static func hedgerow(length: float) -> Destructible:
	var prop := _base(90.0, Color(0.3, 0.4, 0.15), 1.5)
	prop.burns = 10.0
	var bank := VectorMaterials.make_box(Vector3(length, 1.2, 2.2), Color(0.3, 0.24, 0.15), 0, 1.0)
	bank.position.y = 0.6
	prop.add_child(bank)
	var count: int = int(length / 2.5)
	for i in count:
		var bush := MeshInstance3D.new()
		bush.mesh = _crown_mesh(i % 3)
		bush.material_override = VectorMaterials.organic(Color(0.16, 0.3, 0.1), Color(0.26, 0.4, 0.13), 2, 0.4, 0.4, 0.006)
		bush.scale = Vector3(randf_range(2.8, 3.6), randf_range(2.2, 3.2), 2.8)
		bush.position = Vector3(-length * 0.5 + (i + 0.5) * length / count, 2.0, 0.0)
		bush.rotation.y = randf() * TAU
		prop.add_child(bush)
	_add_box_shape(prop, Vector3(length, 3.0, 2.4), Vector3(0.0, 1.5, 0.0))
	return prop


## Casa del desierto: encalada, de azotea plana con pretil.
static func desert_house(size: Vector3) -> Destructible:
	var prop := _base(120.0, Color(0.85, 0.8, 0.7), size.y)
	prop.burns = 24.0
	_add_box_shape(prop, size, Vector3(0.0, size.y * 0.5, 0.0))
	var wall_color: Color = [Color(0.84, 0.8, 0.7), Color(0.8, 0.72, 0.58), Color(0.86, 0.84, 0.78)][randi() % 3]
	var walls := VectorMaterials.make_box(size, wall_color, 9, 1.5)
	walls.position.y = size.y * 0.5
	prop.add_child(walls)
	# Pretil de la azotea: cuatro muretes.
	for side in [-1.0, 1.0]:
		_decor(prop, Vector3(size.x, 0.5, 0.25), Vector3(0.0, size.y + 0.25, side * (size.z * 0.5 - 0.125)), wall_color.darkened(0.06), 9, 1.5)
		_decor(prop, Vector3(0.25, 0.5, size.z), Vector3(side * (size.x * 0.5 - 0.125), size.y + 0.25, 0.0), wall_color.darkened(0.06), 9, 1.5)
	# Vigas de madera que asoman bajo la azotea.
	var beams: int = int(size.x / 1.1)
	for i in beams:
		_decor(prop, Vector3(0.16, 0.16, 0.5), Vector3(-size.x * 0.5 + (i + 0.5) * size.x / beams, size.y - 0.35, size.z * 0.5 + 0.2), WOOD, 5, 0.3)
	_decor(prop, Vector3(1.2, 2.0, 0.14), Vector3(0.0, 1.0, size.z * 0.5 + 0.04), Color(0.2, 0.35, 0.5), 8, 0.8)
	for side in [-1.0, 1.0]:
		_decor(prop, Vector3(0.8, 0.9, 0.14), Vector3(side * size.x * 0.3, size.y * 0.6, size.z * 0.5 + 0.04), Color(0.1, 0.12, 0.14), 7, 0.9)
		_decor(prop, Vector3(0.14, 0.9, 0.8), Vector3(side * (size.x * 0.5 + 0.04), size.y * 0.6, 0.0), Color(0.1, 0.12, 0.14), 7, 0.9)
	# Toldo de lona junto a la puerta.
	if randf() < 0.5:
		var awning := _decor(prop, Vector3(2.4, 0.06, 1.6), Vector3(size.x * 0.1, 2.3, size.z * 0.5 + 0.8), Color(0.6, 0.3, 0.2), 6, 0.3)
		awning.rotation.x = 0.25
	return prop


## Isba rusa de troncos con tejado a dos aguas.
static func izba(size: Vector3) -> Destructible:
	if _roof == null:
		_roof = PrismMesh.new()
		_roof.size = Vector3.ONE
	var prop := _base(100.0, WOOD, size.y)
	prop.burns = 70.0
	_add_box_shape(prop, size, Vector3(0.0, size.y * 0.5, 0.0))
	var walls := VectorMaterials.make_box(size, Color(0.42, 0.3, 0.18), 11, 1.6)
	walls.position.y = size.y * 0.5
	prop.add_child(walls)
	var roof := VectorMaterials.make_outlined(_roof, Color(0.36, 0.33, 0.28), Color(0.2, 0.18, 0.15), 5, 0.6)
	roof.scale = Vector3(size.x * 1.18, size.y * 0.7, size.z * 1.12)
	roof.position.y = size.y + size.y * 0.35
	prop.add_child(roof)
	var chimney := VectorMaterials.make_box(Vector3(0.7, 1.8, 0.7), BRICK.darkened(0.25), 2, 0.8)
	chimney.position = Vector3(-size.x * 0.2, size.y + 1.2, size.z * 0.1)
	prop.add_child(chimney)
	_decor(prop, Vector3(1.0, 1.9, 0.14), Vector3(size.x * 0.05, 0.95, -size.z * 0.5 - 0.04), Color(0.3, 0.22, 0.14), 8, 0.8)
	# Ventanas con marcos tallados pintados.
	var trim: Color = [Color(0.5, 0.65, 0.4), Color(0.4, 0.55, 0.7), Color(0.85, 0.85, 0.8)][randi() % 3]
	for side in [-1.0, 1.0]:
		var x: float = side * size.x * 0.28
		_decor(prop, Vector3(1.05, 1.2, 0.08), Vector3(x, size.y * 0.55, size.z * 0.5 + 0.03), trim, 5, 0.4)
		_decor(prop, Vector3(0.8, 0.95, 0.14), Vector3(x, size.y * 0.55, size.z * 0.5 + 0.04), Color(0.25, 0.3, 0.35), 7, 0.4)
		_decor(prop, Vector3(0.14, 0.95, 0.8), Vector3(side * (size.x * 0.5 + 0.04), size.y * 0.55, 0.0), Color(0.25, 0.3, 0.35), 7, 0.4)
	return prop


## Iglesia de pueblo normando: nave y campanario (con premio: la campana) por separado.
static func church() -> Node3D:
	if _roof == null:
		_roof = PrismMesh.new()
		_roof.size = Vector3.ONE
	var root := Node3D.new()
	var stone := Color(0.55, 0.53, 0.48)
	var nave := _base(250.0, Color(0.6, 0.58, 0.52), 6.0)
	nave.burns = 60.0
	var walls := VectorMaterials.make_box(Vector3(8.0, 7.0, 16.0), stone, 2, 1.8)
	walls.position.y = 3.5
	nave.add_child(walls)
	var roof := VectorMaterials.make_outlined(_roof, Color(0.25, 0.27, 0.3), Color(0.15, 0.16, 0.18), 5, 0.6)
	roof.scale = Vector3(8.6, 4.0, 16.4)
	roof.position.y = 9.0
	nave.add_child(roof)
	_decor(nave, Vector3(2.0, 3.2, 0.16), Vector3(0.0, 1.6, -8.05), Color(0.3, 0.2, 0.12), 8, 0.8)
	for side in [-1.0, 1.0]:
		for i in 4:
			_decor(nave, Vector3(0.16, 2.8, 0.9), Vector3(side * 4.05, 4.2, -5.4 + i * 3.6), Color(0.3, 0.35, 0.55), 7, 0.9)
			# Contrafuertes.
			var buttress := VectorMaterials.make_box(Vector3(0.7, 5.5, 0.8), stone.darkened(0.08), 2, 1.8)
			buttress.position = Vector3(side * 4.3, 2.75, -7.2 + i * 3.6)
			nave.add_child(buttress)
	_add_box_shape(nave, Vector3(8.0, 9.0, 16.0), Vector3(0.0, 4.5, 0.0))
	root.add_child(nave)

	var tower := _base(160.0, Color(0.6, 0.58, 0.52), 5.0)
	tower.prize_points = 400
	tower.prize_name = Loc.t("CAMPANARIO")
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
	prop.burns = 20.0
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
		var bags := VectorMaterials.make_box(Vector3(length - row * 0.5, 0.45, 1.0 - row * 0.15), Color(0.62, 0.55, 0.4), 10, 0.9)
		bags.position.y = 0.22 + row * 0.44
		prop.add_child(bags)
	_add_box_shape(prop, Vector3(length, 1.35, 1.0), Vector3(0.0, 0.67, 0.0))
	return prop


## Depósito de suministros (objetivo de misión): cajas y bidones bajo una lona.
static func supply_depot() -> Destructible:
	var prop := _base(160.0, Color(1.0, 0.6, 0.2), 3.0)
	prop.blast_radius = 14.0
	prop.blast_damage = 50.0
	prop.burns = 30.0
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


## Casa bombardeada que sigue ardiendo: sin tejado, con los muros rotos a distintas alturas
## (más bajos hacia la esquina donde cayó la bomba), los huecos de las ventanas ennegrecidos,
## vigas carbonizadas caídas dentro, la chimenea aún en pie y cascotes alrededor.
## `style`: 0 casa de pueblo, 1 casa del desierto, 2 isba de troncos (queda la estufa de ladrillo).
static func bombed_house(size: Vector3, style: int = 0) -> Destructible:
	var wall_color: Color = [Color(0.56, 0.5, 0.42), Color(0.7, 0.64, 0.52), Color(0.2, 0.15, 0.1)][style]
	var pattern: int = 11 if style == 2 else 9
	var prop := _base(90.0, Color(0.5, 0.47, 0.42), size.y * 0.75)
	prop.burns = 35.0
	_add_box_shape(prop, Vector3(size.x, size.y * 0.75, size.z), Vector3(0.0, size.y * 0.375, 0.0))
	var thick: float = 0.45
	var hit := Vector2(size.x * (0.5 if randf() < 0.5 else -0.5), size.z * (0.5 if randf() < 0.5 else -0.5))
	var diagonal: float = Vector2(size.x, size.z).length()
	var soot: Color = Fx.CHARRED * 1.5
	# Las piezas menudas (tiznones, vigas, cascotes) van juntas en una sola malla.
	var bits: Array = []
	for wall in 4:
		var along_x: bool = wall < 2
		var side: float = -1.0 if wall % 2 == 0 else 1.0
		# Los muros cortos van entre los largos, para que no se pisen en las esquinas.
		var length: float = size.x if along_x else size.z - thick * 2.0
		var pieces: int = maxi(roundi(length / 2.0), 2)
		var piece: float = length / pieces
		for i in pieces:
			var offset: float = -length * 0.5 + piece * (i + 0.5)
			var at: Vector2 = Vector2(offset, side * (size.z - thick) * 0.5) if along_x else Vector2(side * (size.x - thick) * 0.5, offset)
			var tall: float = size.y * clampf(0.1 + 1.2 * at.distance_to(hit) / diagonal + randf_range(-0.12, 0.12), 0.1, 1.0)
			var block := VectorMaterials.make_box(Vector3(piece, tall, thick) if along_x else Vector3(thick, tall, piece), wall_color.darkened(randf_range(0.0, 0.3)), pattern, 1.3)
			block.position = Vector3(at.x, tall * 0.5, at.y)
			prop.add_child(block)
			if tall > size.y * 0.72 and i % 2 == 1:
				# Hueco de ventana, negro de humo, con el tiznón que dejó la llama al salir.
				bits.append([Transform3D(Basis.from_scale(Vector3(0.9, 1.0, thick + 0.08) if along_x else Vector3(thick + 0.08, 1.0, 0.9)), Vector3(at.x, size.y * 0.52, at.y)), soot])
				bits.append([Transform3D(Basis.from_scale(Vector3(1.1, 0.5, thick + 0.04) if along_x else Vector3(thick + 0.04, 0.5, 1.1)), Vector3(at.x, minf(size.y * 0.52 + 0.78, tall - 0.26), at.y)), wall_color.darkened(0.72).srgb_to_linear()])
	var back := Vector2(-signf(hit.x), -signf(hit.y))
	if style != 1:
		# La chimenea (o la estufa de ladrillo de la isba) aguanta en pie.
		var stack := VectorMaterials.make_box(Vector3(0.9, size.y + 2.0, 0.9), BRICK.darkened(0.4), 2, 0.8)
		stack.position = Vector3(back.x * (size.x * 0.5 - 1.0), (size.y + 2.0) * 0.5, back.y * (size.z * 0.5 - 1.0) * 0.5)
		prop.add_child(stack)
	# Vigas del tejado, carbonizadas, caídas hacia dentro desde los muros que quedan altos.
	for i in 5:
		var length: float = minf(size.x, size.z) * randf_range(0.55, 0.9)
		var lean := Basis.from_euler(Vector3(randf_range(0.35, 0.8), randf() * TAU, randf_range(-0.2, 0.2)))
		bits.append([Transform3D(lean * Basis.from_scale(Vector3(0.2, 0.2, length)), Vector3(back.x * randf_range(0.0, 0.3) * size.x, randf_range(0.5, 0.75) * size.y * 0.5, back.y * randf_range(0.0, 0.3) * size.z)), Fx.CHARRED * randf_range(1.5, 3.0)])
	# Cascotes dentro y, sobre todo, fuera por donde reventó.
	for i in 12:
		var chunk_size := Vector3(randf_range(0.4, 1.0), randf_range(0.25, 0.6), randf_range(0.4, 0.9))
		var where: Vector2 = Vector2(randf_range(-0.4, 0.4) * size.x, randf_range(-0.4, 0.4) * size.z) if i < 5 else hit + Vector2(randf_range(-2.6, 2.6), randf_range(-2.6, 2.6))
		var tumbled := Basis.from_euler(Vector3(randf_range(-0.4, 0.4), randf() * TAU, randf_range(-0.4, 0.4)))
		bits.append([Transform3D(tumbled * Basis.from_scale(chunk_size), Vector3(where.x, chunk_size.y * 0.35, where.y)), (BRICK if i % 3 == 0 else wall_color).darkened(randf_range(0.2, 0.5)).srgb_to_linear()])
	prop.add_child(Remains.pile(bits))
	var blaze := Blaze.new()
	# Arde por dentro de arriba abajo: las llamas asoman por encima de los muros.
	blaze.extent = Vector3(size.x * 0.32, size.y * 0.4, size.z * 0.32)
	blaze.power = clampf(size.y * 0.5, 1.7, 2.4)
	blaze.smoke = 1.1
	blaze.lights_sky = true
	blaze.position = Vector3(back.x * size.x * 0.06, size.y * 0.45, back.y * size.z * 0.06)
	prop.add_child(blaze)
	return prop


## Árbol alcanzado por el fuego: el tronco carbonizado con unas pocas ramas peladas. Con
## `burning` sigue en llamas; si no, solo humea.
## `kind`: 0 frutal, 1 abedul, 2 palmera, 3 abeto.
static func burnt_tree(height: float, kind: int = 0, burning: bool = true) -> Destructible:
	var prop := _base(12.0, Color(0.12, 0.1, 0.08), 1.0)
	prop.crushable = true
	prop.topples = true
	var girth: float = [1.1, 0.6, 0.7, 1.0][kind]
	var tall: float = height * [0.8, 0.85, 0.9, 0.8][kind]
	# Tronco y ramas peladas (la palmera se queda en el puro tronco), fundidos en una malla.
	var parts: Array = [[_trunk_mesh(), Transform3D(Basis.from_scale(Vector3(girth, tall, girth)), Vector3(0.0, tall * 0.5, 0.0))]]
	for i in (0 if kind == 2 else randi_range(3, 5)):
		var length: float = height * randf_range(0.2, 0.36)
		var yaw: float = randf() * TAU
		var tilt: float = randf_range(0.55, 1.1)
		var dir := Vector3(sin(tilt) * cos(yaw), cos(tilt), sin(tilt) * sin(yaw))
		parts.append([_trunk_mesh(), Transform3D(Basis(Quaternion(Vector3.UP, dir)) * Basis.from_scale(Vector3(girth * 0.35, length, girth * 0.35)), Vector3(0.0, tall * randf_range(0.5, 0.95), 0.0) + dir * length * 0.5)])
	var wood := MeshInstance3D.new()
	wood.mesh = _merge(parts)
	wood.material_override = VectorMaterials.textured(Remains.CHARRED_WOOD, Color(0.02, 0.02, 0.02), 1, 0.5)
	prop.add_child(wood)
	if burning:
		var blaze := Blaze.new()
		blaze.extent = Vector3(0.45, tall * 0.3, 0.45)
		blaze.power = randf_range(0.75, 0.95)
		blaze.smoke = 0.6
		blaze.position.y = tall * 0.62
		prop.add_child(blaze)
	else:
		var vent := FxVent.new()
		vent.rate = 1.4
		vent.size = 0.9
		vent.rise = 1.6
		vent.life = 4.0
		vent.color = Color(Fx.GREY_SMOKE.r, Fx.GREY_SMOKE.g, Fx.GREY_SMOKE.b, 0.5)
		vent.position.y = tall
		prop.add_child(vent)
	_add_box_shape(prop, Vector3(0.6, tall, 0.6), Vector3(0.0, tall * 0.5, 0.0))
	return prop


static func _trunk_mesh() -> CylinderMesh:
	if _trunk == null:
		_trunk = CylinderMesh.new()
		_trunk.top_radius = 0.22
		_trunk.bottom_radius = 0.38
		_trunk.height = 1.0
		_trunk.radial_segments = 8
		_trunk.rings = 1
	return _trunk


## Pieza pequeña de adorno (ventana, puerta, viga...): caja texturizada que no proyecta sombra.
static func _decor(prop: Node3D, size: Vector3, pos: Vector3, color: Color, pattern: int, pattern_scale: float) -> MeshInstance3D:
	var mesh := VectorMaterials.make_box(size, color, pattern, pattern_scale)
	mesh.position = pos
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# De lejos no se distinguen: fuera de DECOR_RANGE no se dibujan (un pueblo entero tiene
	# cientos de estas piezas).
	mesh.visibility_range_end = DECOR_RANGE
	mesh.visibility_range_end_margin = 12.0
	prop.add_child(mesh)
	return mesh


## Funde varias mallas en una sola: `parts` es una lista de [malla, transformación].
static func _merge(parts: Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for part in parts:
		st.append_from(part[0], 0, part[1])
	return st.commit()


## Copa de árbol de hoja ancha: varios bultos fundidos (hay tres variantes).
static func _crown_mesh(variant: int) -> ArrayMesh:
	var key: String = "crown%d" % variant
	if not _meshes.has(key):
		var rng := RandomNumberGenerator.new()
		rng.seed = 100 + variant
		var blob := SphereMesh.new()
		blob.radius = 0.5
		blob.height = 1.0
		blob.radial_segments = 10
		blob.rings = 5
		var parts: Array = [[blob, Transform3D(Basis().scaled(Vector3(0.8, 0.72, 0.8)), Vector3.ZERO)]]
		for i in 5:
			var angle: float = TAU * i / 5.0 + rng.randf_range(-0.4, 0.4)
			var size: float = rng.randf_range(0.42, 0.6)
			var offset := Vector3(cos(angle) * 0.3, rng.randf_range(-0.18, 0.22), sin(angle) * 0.3)
			parts.append([blob, Transform3D(Basis().scaled(Vector3(size, size * 0.85, size)), offset)])
		_meshes[key] = _merge(parts)
	return _meshes[key]


## Abeto: tres pisos cónicos de ramas.
static func _conifer_mesh() -> ArrayMesh:
	if not _meshes.has("conifer"):
		var parts: Array = []
		var tiers: Array = [[0.5, 0.5, 0.25], [0.38, 0.42, 0.52], [0.24, 0.36, 0.82]]
		for tier in tiers:
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = tier[0]
			cone.height = tier[1]
			cone.radial_segments = 9
			cone.rings = 2
			parts.append([cone, Transform3D(Basis(), Vector3(0.0, tier[2], 0.0))])
		_meshes["conifer"] = _merge(parts)
	return _meshes["conifer"]


## Penacho de palmera: hojas de dos tramos (uno hacia arriba y otro que cae) y cocos.
static func _palm_mesh() -> ArrayMesh:
	if not _meshes.has("palm"):
		var parts: Array = []
		var inner := BoxMesh.new()
		inner.size = Vector3(0.075, 0.008, 0.22)
		var outer := BoxMesh.new()
		outer.size = Vector3(0.055, 0.008, 0.22)
		for i in 9:
			var yaw := Basis(Vector3.UP, TAU * i / 9.0 + (0.2 if i % 2 == 0 else 0.0))
			var rise: float = -0.45 if i % 2 == 0 else -0.2
			var first: Basis = yaw * Basis(Vector3.RIGHT, rise)
			var tip: Vector3 = first * Vector3(0.0, 0.0, 0.22)
			var second: Basis = yaw * Basis(Vector3.RIGHT, rise + 0.75)
			parts.append([inner, Transform3D(first, first * Vector3(0.0, 0.0, 0.11))])
			parts.append([outer, Transform3D(second, tip + second * Vector3(0.0, 0.0, 0.105))])
		var coconut := SphereMesh.new()
		coconut.radius = 0.025
		coconut.height = 0.05
		coconut.radial_segments = 6
		coconut.rings = 3
		for i in 3:
			var angle: float = TAU * i / 3.0
			parts.append([coconut, Transform3D(Basis(), Vector3(cos(angle) * 0.035, -0.02, sin(angle) * 0.035))])
		_meshes["palm"] = _merge(parts)
	return _meshes["palm"]


## Monte o duna: malla radial con crestas, vaguadas y cima irregular. `gentle` = duna suave.
static func _mound_mesh(radius: float, height: float, top_radius: float, gentle: bool) -> ArrayMesh:
	var rings: int = 7
	var segments: int = 18
	var phases: Array[float] = [randf() * TAU, randf() * TAU, randf() * TAU, randf() * TAU]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in rings + 1:
		var t: float = float(i) / rings
		for j in segments:
			var a: float = TAU * j / segments
			# Crestas: el contorno entra y sale según el ángulo, más marcado a media ladera.
			var ridge: float = sin(a * 3.0 + phases[0]) * 0.2 + sin(a * 5.0 + phases[1]) * 0.12 + sin(a * 9.0 + phases[2]) * 0.06
			var bite: float = 0.3 if gentle else 1.0
			var r: float = lerpf(radius, top_radius * 0.4, pow(t, 0.75 if gentle else 0.9)) * (1.0 + ridge * bite * (0.35 + sin(t * PI) * 0.9))
			var crest: float = 1.0 + (sin(a * 2.0 + phases[3]) * 0.12 + ridge * 0.5) * bite * t
			# Perfil de campana: falda tendida, ladera empinada y cima redondeada.
			var y: float = height * (sin(t * PI * 0.5) if gentle else pow(0.5 - 0.5 * cos(t * PI), 0.85)) * crest
			if i == rings:
				r = 0.0
				y = height
			st.set_uv(Vector2(float(j) / segments, t))
			st.add_vertex(Vector3(cos(a) * r, y, sin(a) * r))
	for i in rings:
		for j in segments:
			var a: int = i * segments + j
			var b: int = i * segments + (j + 1) % segments
			var c: int = (i + 1) * segments + (j + 1) % segments
			var d: int = (i + 1) * segments + j
			for index in [a, b, c, a, c, d]:
				st.add_index(index)
	st.generate_normals()
	return st.commit()


static func mountain(radius: float, height: float, segments: int = 7) -> Destructible:
	var prop := _base(1.0, ROCK_COLOR, height * 0.2)
	prop.indestructible = true
	# La colisión sigue siendo un cono sencillo; la malla visible tiene crestas y vaguadas.
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * randf_range(0.05, 0.25)
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 1
	var visual := MeshInstance3D.new()
	visual.mesh = _mound_mesh(radius, height, mesh.top_radius, segments >= 10)
	# Las dunas son todo arena; los montes enseñan la roca en lo escarpado.
	var gentle: bool = segments >= 10
	var rock_tone: Color = mountain_color.darkened(0.45) if gentle else mountain_color.lerp(ROCK_COLOR, 0.6).darkened(0.35)
	visual.material_override = VectorMaterials.textured(mountain_color, rock_tone, 7, 3.0)
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


# ---------------------------------------------------------------- obras de tierra y cultivos

## Malla de un talud de tierra: sección en trapecio, extremos en rampa.
static func _bank_mesh(length: float, height: float, width: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half: float = length * 0.5
	var top: float = width * 0.22
	var base: float = width * 0.5
	var slope: float = minf(height * 1.2, half * 0.5)
	# Ocho esquinas: cuatro de la base y cuatro de la coronación (más corta por las rampas).
	var corners: Array[Vector3] = [
		Vector3(-half, 0.0, -base), Vector3(half, 0.0, -base), Vector3(half, 0.0, base), Vector3(-half, 0.0, base),
		Vector3(-half + slope, height, -top), Vector3(half - slope, height, -top), Vector3(half - slope, height, top), Vector3(-half + slope, height, top),
	]
	for quad: Array in [[4, 5, 6, 7], [0, 1, 5, 4], [2, 3, 7, 6], [1, 2, 6, 5], [3, 0, 4, 7]]:
		for index: int in [0, 1, 2, 0, 2, 3]:
			st.add_vertex(corners[quad[index]])
	st.generate_normals()
	return st.commit()


## Talud de tierra (parapeto de trinchera, terraplén): cubre el casco de un tanque y para los
## disparos; hay que rodearlo. Muy duro, pero la artillería acaba abriéndolo.
static func earth_bank(length: float, height: float = 1.6, width: float = 3.4, soil: Color = Color(0.3, 0.24, 0.15)) -> Destructible:
	var prop := _base(320.0, soil, height)
	var key: String = "bank|%.1f|%.1f|%.1f" % [length, height, width]
	if not _meshes.has(key):
		_meshes[key] = _bank_mesh(length, height, width)
	var visual := MeshInstance3D.new()
	visual.mesh = _meshes[key]
	# Hierba arriba y tierra en los taludes (patrón de ladera).
	visual.material_override = VectorMaterials.textured(mountain_color.lerp(soil, 0.35), soil.darkened(0.45), 7, 1.2)
	prop.add_child(visual)
	_add_box_shape(prop, Vector3(length - height, height, width * 0.6), Vector3(0.0, height * 0.5, 0.0))
	return prop


## Pozo de tirador para un carro: tres taludes bajos en U, abiertos por detrás (hacia -Z mira
## el frente). El carro asoma la torreta por encima; el casco queda cubierto.
static func revetment(soil: Color = Color(0.3, 0.24, 0.15)) -> Node3D:
	var root := Node3D.new()
	root.name = "PozoDeCarro"
	var front := earth_bank(10.0, 1.05, 3.0, soil)
	front.position = Vector3(0.0, 0.0, -5.2)
	root.add_child(front)
	for side in [-1.0, 1.0]:
		var flank := earth_bank(7.0, 1.05, 3.0, soil)
		flank.position = Vector3(side * 4.6, 0.0, -0.8)
		flank.rotation.y = PI * 0.5
		root.add_child(flank)
	return root


## Trigal alto: no frena a los tanques ni para los disparos, pero tapa el casco y la vista a
## ras de suelo. Una sola malla de surcos mecidos por el viento.
static func wheat_field(size: Vector2, ripe: Color = Color(0.74, 0.6, 0.26)) -> MeshInstance3D:
	var key: String = "wheat|%d|%d" % [roundi(size.x), roundi(size.y)]
	if not _meshes.has(key):
		var row := BoxMesh.new()
		row.size = Vector3(size.x, 1.25, 1.3)
		var parts: Array = []
		var rows: int = maxi(int(size.y / 2.1), 1)
		for i in rows:
			parts.append([row, Transform3D(Basis(), Vector3(0.0, 0.62, -size.y * 0.5 + (i + 0.5) * size.y / rows))])
		_meshes[key] = _merge(parts)
	var field := MeshInstance3D.new()
	field.name = "Trigal"
	field.mesh = _meshes[key]
	field.material_override = VectorMaterials.organic(ripe, ripe.darkened(0.35), 6, 0.35, 0.0, 0.012)
	field.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return field


# ---------------------------------------------------------------- pueblos

## Casa de pueblo de dos plantas, entre medianeras: fachada con hileras de ventanas (las pinta
## el propio material), tejado, chimenea y portal. `style`: 0 normanda, 1 del desierto (azotea),
## 2 rusa de ladrillo encalado.
static func townhouse(size: Vector3, style: int = 0) -> Destructible:
	if _roof == null:
		_roof = PrismMesh.new()
		_roof.size = Vector3.ONE
	var plaster: Color = [
		[Color(0.78, 0.72, 0.6), Color(0.7, 0.66, 0.6), Color(0.74, 0.62, 0.5), Color(0.62, 0.56, 0.5)],
		[Color(0.86, 0.82, 0.72), Color(0.8, 0.72, 0.58), Color(0.88, 0.86, 0.8)],
		[Color(0.8, 0.8, 0.76), Color(0.7, 0.62, 0.5), Color(0.62, 0.36, 0.28)],
	][style].pick_random()
	var prop := _base(200.0, plaster.darkened(0.2), size.y)
	prop.burns = 55.0 if style != 1 else 26.0
	_add_box_shape(prop, size, Vector3(0.0, size.y * 0.5, 0.0))
	var walls := VectorMaterials.make_box(size, plaster, 1, 3.0)
	walls.position.y = size.y * 0.5
	prop.add_child(walls)
	if style == 1:
		for side in [-1.0, 1.0]:
			_decor(prop, Vector3(size.x, 0.5, 0.25), Vector3(0.0, size.y + 0.25, side * (size.z * 0.5 - 0.125)), plaster.darkened(0.06), 9, 1.5)
			_decor(prop, Vector3(0.25, 0.5, size.z), Vector3(side * (size.x * 0.5 - 0.125), size.y + 0.25, 0.0), plaster.darkened(0.06), 9, 1.5)
	else:
		var roof_color: Color = [ROOF, Color(0.27, 0.28, 0.31), Color(0.42, 0.2, 0.14)].pick_random() if style == 0 else [Color(0.3, 0.36, 0.3), Color(0.4, 0.2, 0.16), Color(0.33, 0.33, 0.35)].pick_random()
		var roof := VectorMaterials.make_outlined(_roof, roof_color, roof_color.darkened(0.5), 5, 0.6)
		roof.scale = Vector3(size.x * 1.06, size.y * 0.42, size.z * 1.1)
		roof.position.y = size.y + size.y * 0.21
		prop.add_child(roof)
		var chimney := VectorMaterials.make_box(Vector3(0.9, 2.6, 0.9), BRICK.darkened(0.2), 2, 0.8)
		chimney.position = Vector3(size.x * randf_range(-0.3, 0.3), size.y + 1.3, -size.z * 0.22)
		prop.add_child(chimney)
	# Portal y escaparate o portón en la fachada (+Z).
	var door: Color = [Color(0.2, 0.32, 0.24), Color(0.25, 0.3, 0.42), Color(0.45, 0.2, 0.16), Color(0.3, 0.22, 0.14)].pick_random()
	_decor(prop, Vector3(1.3, 2.3, 0.14), Vector3(-size.x * 0.25, 1.15, size.z * 0.5 + 0.04), door, 8, 0.8)
	if randf() < 0.5 and style != 1:
		_decor(prop, Vector3(size.x * 0.34, 1.7, 0.14), Vector3(size.x * 0.2, 1.35, size.z * 0.5 + 0.04), Color(0.22, 0.27, 0.32), 7, 1.4)
		var awning := _decor(prop, Vector3(size.x * 0.4, 0.06, 1.1), Vector3(size.x * 0.2, 2.5, size.z * 0.5 + 0.5), door.lightened(0.15), 6, 0.3)
		awning.rotation.x = 0.3
	return prop


## Pozo o fuente de la plaza.
static func well() -> Destructible:
	var prop := _base(80.0, Color(0.55, 0.53, 0.48), 1.2)
	var ring := CylinderMesh.new()
	ring.top_radius = 1.5
	ring.bottom_radius = 1.6
	ring.height = 1.0
	ring.radial_segments = 10
	var curb := VectorMaterials.make_outlined(ring, Color(0.55, 0.53, 0.48), Color(0.3, 0.29, 0.27), 3, 0.5)
	curb.position.y = 0.5
	prop.add_child(curb)
	for side in [-1.0, 1.0]:
		_decor(prop, Vector3(0.2, 2.4, 0.2), Vector3(side * 1.3, 1.2, 0.0), WOOD, 5, 0.3)
	_decor(prop, Vector3(3.2, 0.14, 1.4), Vector3(0.0, 2.5, 0.0), ROOF.darkened(0.2), 5, 0.4)
	_add_box_shape(prop, Vector3(3.0, 1.2, 3.0), Vector3(0.0, 0.6, 0.0))
	return prop


## Iglesia ortodoxa rusa de pueblo: nave encalada, tejado verde y torre con cúpula de cebolla
## (con premio, como el campanario normando).
static func orthodox_church() -> Destructible:
	if _roof == null:
		_roof = PrismMesh.new()
		_roof.size = Vector3.ONE
	var white := Color(0.84, 0.84, 0.8)
	var prop := _base(260.0, Color(0.7, 0.7, 0.66), 6.0)
	prop.burns = 60.0
	prop.prize_points = 400
	prop.prize_name = Loc.t("CAMPANARIO")
	prop.destroy_sound = Sfx.BELL
	var nave := VectorMaterials.make_box(Vector3(8.0, 6.0, 13.0), white, 9, 2.0)
	nave.position.y = 3.0
	prop.add_child(nave)
	var roof := VectorMaterials.make_outlined(_roof, Color(0.22, 0.4, 0.3), Color(0.12, 0.22, 0.17), 5, 0.6)
	roof.scale = Vector3(8.6, 3.0, 13.4)
	roof.position.y = 7.5
	prop.add_child(roof)
	var tower := VectorMaterials.make_box(Vector3(4.2, 11.0, 4.2), white, 9, 2.0)
	tower.position = Vector3(0.0, 5.5, 8.0)
	prop.add_child(tower)
	var blue := Color(0.2, 0.36, 0.55)
	for spot: Array in [[Vector3(0.0, 11.0, 8.0), 1.0], [Vector3(0.0, 9.0, -3.0), 0.62]]:
		var k: float = spot[1]
		var drum := CylinderMesh.new()
		drum.top_radius = 1.3 * k
		drum.bottom_radius = 1.3 * k
		drum.height = 1.8 * k
		drum.radial_segments = 10
		var neck := VectorMaterials.make_outlined(drum, white, white.darkened(0.3), 0, 1.0)
		neck.position = (spot[0] as Vector3) + Vector3.UP * 0.9 * k
		prop.add_child(neck)
		var bulb := SphereMesh.new()
		bulb.radius = 2.1 * k
		bulb.height = 3.6 * k
		bulb.radial_segments = 12
		bulb.rings = 6
		var onion := VectorMaterials.make_outlined(bulb, blue, blue.darkened(0.4), 4, 0.5)
		onion.position = (spot[0] as Vector3) + Vector3.UP * 3.3 * k
		prop.add_child(onion)
		var tip := CylinderMesh.new()
		tip.top_radius = 0.0
		tip.bottom_radius = 1.0 * k
		tip.height = 2.4 * k
		tip.radial_segments = 10
		var point := VectorMaterials.make_outlined(tip, blue, blue.darkened(0.4), 4, 0.5)
		point.position = (spot[0] as Vector3) + Vector3.UP * 5.6 * k
		prop.add_child(point)
		_decor(prop, Vector3(0.12, 1.6 * k, 0.12), (spot[0] as Vector3) + Vector3.UP * 7.4 * k, Color(0.8, 0.68, 0.25), 0, 1.0)
		_decor(prop, Vector3(0.8 * k, 0.12, 0.12), (spot[0] as Vector3) + Vector3.UP * 7.6 * k, Color(0.8, 0.68, 0.25), 0, 1.0)
	_decor(prop, Vector3(1.8, 2.8, 0.16), Vector3(0.0, 1.4, 10.15), Color(0.3, 0.2, 0.12), 8, 0.8)
	for side in [-1.0, 1.0]:
		for i in 3:
			_decor(prop, Vector3(0.16, 2.2, 0.9), Vector3(side * 4.05, 3.4, -4.0 + i * 3.6), Color(0.25, 0.3, 0.45), 7, 0.9)
	_add_box_shape(prop, Vector3(8.0, 7.5, 13.0), Vector3(0.0, 3.75, 0.0))
	_add_box_shape(prop, Vector3(4.2, 13.0, 4.2), Vector3(0.0, 6.5, 8.0))
	_mark_prize(prop)
	return prop


## Morabito: santuario encalado del desierto, un cubo blanco con su cúpula.
static func koubba() -> Destructible:
	var white := Color(0.9, 0.88, 0.82)
	var prop := _base(180.0, Color(0.85, 0.8, 0.7), 4.0)
	var walls := VectorMaterials.make_box(Vector3(7.0, 4.5, 7.0), white, 9, 2.2)
	walls.position.y = 2.25
	prop.add_child(walls)
	var cap := SphereMesh.new()
	cap.radius = 3.0
	cap.height = 3.0
	cap.is_hemisphere = true
	cap.radial_segments = 14
	cap.rings = 6
	var dome := VectorMaterials.make_outlined(cap, white, white.darkened(0.25), 0, 1.0)
	dome.position.y = 4.5
	prop.add_child(dome)
	for x in [-3.2, 3.2]:
		for z in [-3.2, 3.2]:
			_decor(prop, Vector3(0.6, 0.9, 0.6), Vector3(x, 4.95, z), white, 9, 1.0)
	_decor(prop, Vector3(1.4, 2.4, 0.14), Vector3(0.0, 1.2, 3.54), Color(0.2, 0.35, 0.5), 8, 0.8)
	_add_box_shape(prop, Vector3(7.0, 6.0, 7.0), Vector3(0.0, 3.0, 0.0))
	return prop


## Tapia de adobe (pueblos del desierto) o muro de piedra (Normandía).
static func wall(length: float, color: Color = Color(0.8, 0.72, 0.58), pattern: int = 9) -> Destructible:
	var prop := _base(70.0, color.darkened(0.15), 1.2)
	var mesh := VectorMaterials.make_box(Vector3(length, 1.7, 0.6), color, pattern, 1.5)
	mesh.position.y = 0.85
	prop.add_child(mesh)
	_add_box_shape(prop, Vector3(length, 1.7, 0.6), Vector3(0.0, 0.85, 0.0))
	return prop


# ---------------------------------------------------------------- puentes y ferrocarril

## Puente sobre un río: el tablero va a ras de suelo (el paso es llano) y lo que se ve y cubre
## son los pretiles. El eje Z cruza el río; `span` es el largo y `width` el ancho libre.
## `style`: 0 de piedra (Normandía), 1 de madera, de pontoneros (frente del Este).
static func bridge(span: float, width: float, style: int = 0) -> Node3D:
	var root := Node3D.new()
	root.name = "Puente"
	var stone := Color(0.52, 0.5, 0.45)
	var timber := Color(0.36, 0.26, 0.16)
	var deck := Ribbon.node(PackedVector2Array([Vector2(0.0, -span * 0.5), Vector2(0.0, span * 0.5)]), width * 0.5, Ribbon.Y_DECK,
			Ribbon.strip(stone.darkened(0.1), stone.darkened(0.55), 1, width, 0.0) if style == 0 else Ribbon.strip(timber, timber.darkened(0.6), 6, width, 0.0))
	root.add_child(deck)
	for side in [-1.0, 1.0]:
		var rail := _base(1.0, stone if style == 0 else timber, 1.0)
		rail.indestructible = true
		rail.position = Vector3(side * (width * 0.5 + 0.35), 0.0, 0.0)
		if style == 0:
			var parapet := VectorMaterials.make_box(Vector3(0.7, 1.15, span), stone, 2, 1.4)
			parapet.position.y = 0.575
			rail.add_child(parapet)
			var coping := VectorMaterials.make_box(Vector3(0.9, 0.16, span + 0.3), stone.lightened(0.08), 0, 1.0)
			coping.position.y = 1.23
			coping.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			rail.add_child(coping)
			for end in [-1.0, 1.0]:
				var pier := VectorMaterials.make_box(Vector3(1.3, 1.7, 1.3), stone.darkened(0.05), 2, 1.4)
				pier.position = Vector3(0.0, 0.85, end * span * 0.5)
				rail.add_child(pier)
			# Tajamares: asoman al agua a los lados, como los pilares de un puente de arcos.
			for i in 2:
				var cutwater := VectorMaterials.make_box(Vector3(1.6, 0.7, 2.2), stone.darkened(0.12), 2, 1.4)
				cutwater.position = Vector3(side * 0.9, 0.35, (i - 0.5) * span * 0.36)
				cutwater.rotation.y = PI * 0.25
				rail.add_child(cutwater)
		else:
			var posts: int = maxi(int(span / 3.5), 2)
			for i in posts + 1:
				var post := VectorMaterials.make_box(Vector3(0.3, 1.5, 0.3), timber, 5, 0.4)
				post.position = Vector3(0.0, 0.75, -span * 0.5 + i * span / posts)
				rail.add_child(post)
			for y in [0.6, 1.25]:
				var bar := VectorMaterials.make_box(Vector3(0.14, 0.2, span), timber.lightened(0.06), 5, 0.6)
				bar.position.y = y
				rail.add_child(bar)
			var beam := VectorMaterials.make_box(Vector3(0.5, 0.4, span + 1.0), timber.darkened(0.15), 5, 0.6)
			beam.position.y = 0.2
			rail.add_child(beam)
			# Pilotes clavados en el cauce.
			for i in 3:
				var pile := VectorMaterials.make_box(Vector3(0.45, 1.3, 0.45), timber.darkened(0.25), 5, 0.4)
				pile.position = Vector3(side * 0.9, 0.5, (i - 1.0) * span * 0.3)
				pile.rotation.z = side * -0.25
				rail.add_child(pile)
		_add_box_shape(rail, Vector3(0.7, 1.4, span), Vector3(0.0, 0.7, 0.0))
		root.add_child(rail)
	return root


## Vagón de mercancías parado en la vía.
static func wagon() -> Destructible:
	var planks: Color = [Color(0.4, 0.2, 0.15), Color(0.3, 0.3, 0.26), Color(0.36, 0.27, 0.17)].pick_random()
	var prop := _base(120.0, planks, 3.0)
	prop.burns = 40.0
	var box := VectorMaterials.make_box(Vector3(3.0, 2.6, 8.5), planks, 5, 0.9)
	box.position.y = 2.2
	prop.add_child(box)
	var top := VectorMaterials.make_box(Vector3(3.2, 0.2, 8.8), Color(0.2, 0.2, 0.2), 6, 0.6)
	top.position.y = 3.6
	prop.add_child(top)
	var frame := VectorMaterials.make_box(Vector3(2.6, 0.5, 8.9), Color(0.14, 0.14, 0.14), 4, 0.8)
	frame.position.y = 0.75
	prop.add_child(frame)
	_decor(prop, Vector3(0.1, 2.0, 2.2), Vector3(1.52, 2.1, 0.0), planks.darkened(0.25), 8, 1.0)
	_decor(prop, Vector3(0.1, 2.0, 2.2), Vector3(-1.52, 2.1, 0.0), planks.darkened(0.25), 8, 1.0)
	_add_box_shape(prop, Vector3(3.0, 3.6, 8.8), Vector3(0.0, 1.8, 0.0))
	return prop


## Estación de ferrocarril: edificio de viajeros de ladrillo con marquesina sobre el andén.
## La fachada (+Z) da a la vía.
static func station() -> Destructible:
	if _roof == null:
		_roof = PrismMesh.new()
		_roof.size = Vector3.ONE
	var brick := Color(0.58, 0.34, 0.26)
	var prop := _base(320.0, brick.darkened(0.2), 6.0)
	prop.burns = 60.0
	var hall := VectorMaterials.make_box(Vector3(22.0, 6.0, 8.0), brick, 1, 3.0)
	hall.position.y = 3.0
	prop.add_child(hall)
	var roof := VectorMaterials.make_outlined(_roof, Color(0.3, 0.3, 0.32), Color(0.16, 0.16, 0.18), 5, 0.6)
	roof.scale = Vector3(23.0, 2.6, 9.0)
	roof.position.y = 7.3
	prop.add_child(roof)
	var middle := VectorMaterials.make_box(Vector3(7.0, 8.5, 8.6), brick.lightened(0.05), 1, 3.0)
	middle.position.y = 4.25
	prop.add_child(middle)
	var gable := VectorMaterials.make_outlined(_roof, Color(0.3, 0.3, 0.32), Color(0.16, 0.16, 0.18), 5, 0.6)
	gable.scale = Vector3(7.6, 2.4, 9.4)
	gable.position.y = 9.7
	prop.add_child(gable)
	_decor(prop, Vector3(1.6, 1.6, 0.14), Vector3(0.0, 7.0, 4.36), Color(0.9, 0.88, 0.8), 0, 1.0)
	# Marquesina y andén.
	_decor(prop, Vector3(22.0, 0.16, 3.6), Vector3(0.0, 3.6, 5.8), Color(0.25, 0.25, 0.27), 6, 0.5)
	for i in 6:
		_decor(prop, Vector3(0.22, 3.6, 0.22), Vector3(-10.0 + i * 4.0, 1.8, 7.3), Color(0.2, 0.26, 0.22), 4, 0.4)
	_decor(prop, Vector3(30.0, 0.35, 5.0), Vector3(0.0, 0.17, 6.5), CONCRETE, 0, 2.0)
	for x in [-7.5, 7.5]:
		_decor(prop, Vector3(1.5, 2.4, 0.14), Vector3(x, 1.2, 4.04), Color(0.25, 0.2, 0.14), 8, 0.8)
	_add_box_shape(prop, Vector3(22.0, 8.0, 8.0), Vector3(0.0, 4.0, 0.0))
	return prop
