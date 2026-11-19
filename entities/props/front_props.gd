class_name FrontProps
extends RefCounted
## Lo que solo hay en un frente. Estepa de Kursk: molinos de viento, girasoles, postes de
## telégrafo, pozos de cigüeñal, graneros de koljós y carros calcinados. Desierto: matorral
## reseco, acacias, sangars de piedra, jaimas, campos de minas cercados, camiones quemados y
## escarpes de roca. Normandía: granjas de piedra con palomar, cruceros, planeadores estrellados
## y las estacas contra planeadores («espárragos de Rommel»).

const STONE := Color(0.6, 0.57, 0.5)
const LOGS := Color(0.36, 0.27, 0.18)
const THATCH := Color(0.55, 0.47, 0.27)

static var _scrub_mesh: ArrayMesh
static var _scrub_material: ShaderMaterial


# ---------------------------------------------------------------- estepa

## Molino de viento de poste: cuerpo de tablas, caperuza y cuatro aspas que giran despacio.
## Da premio, como el campanario normando.
static func windmill() -> Destructible:
	var prop := PropFactory._base(180.0, LOGS, 5.0)
	prop.burns = 50.0
	prop.prize_points = 300
	prop.prize_name = Loc.t("MOLINO")
	var body := CylinderMesh.new()
	body.top_radius = 2.1
	body.bottom_radius = 3.3
	body.height = 9.5
	body.radial_segments = 8
	var tower := VectorMaterials.make_outlined(body, LOGS, LOGS.darkened(0.5), 6, 0.5)
	tower.position.y = 4.75
	prop.add_child(tower)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 2.7
	cone.height = 2.6
	cone.radial_segments = 8
	var cap := VectorMaterials.make_outlined(cone, THATCH.darkened(0.3), THATCH.darkened(0.6), 6, 0.3)
	cap.position.y = 10.8
	prop.add_child(cap)
	PropFactory._decor(prop, Vector3(1.3, 2.2, 0.14), Vector3(0.0, 1.1, 3.2), LOGS.darkened(0.3), 8, 0.8)
	var sails := Sails.new()
	sails.position = Vector3(0.0, 9.0, 2.6)
	prop.add_child(sails)
	var axle := VectorMaterials.make_box(Vector3(0.35, 0.35, 1.4), LOGS.darkened(0.35), 5, 0.4)
	axle.position.z = -0.5
	sails.add_child(axle)
	for i in 4:
		var arm := Node3D.new()
		arm.rotation.z = i * PI * 0.5
		sails.add_child(arm)
		var spar := VectorMaterials.make_box(Vector3(0.22, 7.2, 0.18), LOGS.darkened(0.2), 5, 0.4)
		spar.position.y = 3.6
		arm.add_child(spar)
		var lattice := VectorMaterials.make_box(Vector3(1.5, 5.6, 0.06), Color(0.72, 0.66, 0.5), 5, 0.5)
		lattice.position = Vector3(0.85, 4.3, 0.0)
		lattice.rotation.y = 0.2
		arm.add_child(lattice)
	PropFactory._add_box_shape(prop, Vector3(6.0, 11.0, 6.0), Vector3(0.0, 5.5, 0.0))
	PropFactory._mark_prize(prop)
	return prop


## Aspas de un molino: giran con el viento.
class Sails extends Node3D:
	var speed: float = 0.5

	func _ready() -> void:
		rotation.z = randf() * TAU
		speed = randf_range(0.35, 0.7)

	func _process(delta: float) -> void:
		rotation.z += speed * delta


## Campo de girasoles: como el trigal, tapa el casco y la vista a ras de suelo sin frenar a
## nadie. Hileras verdes con las cabezas amarillas vueltas al sol.
static func sunflower_field(size: Vector2) -> Node3D:
	var key: String = "sunflower|%d|%d" % [roundi(size.x), roundi(size.y)]
	if not PropFactory._meshes.has(key):
		var row := BoxMesh.new()
		row.size = Vector3(size.x, 1.0, 0.45)
		var stalks: Array = []
		var heads: Array = []
		var rows: int = maxi(int(size.y / 1.3), 1)
		for i in rows:
			var tall: float = 1.35 + 0.25 * absf(sin(i * 2.1))
			var z: float = -size.y * 0.5 + (i + 0.5) * size.y / rows
			stalks.append([row, Transform3D(Basis.from_scale(Vector3(1.0, tall, 1.0)), Vector3(0.0, tall * 0.5, z))])
			heads.append([row, Transform3D(Basis(Vector3.RIGHT, -0.5) * Basis.from_scale(Vector3(1.0, 0.34, 1.1)), Vector3(0.0, tall + 0.12, z + 0.1))])
		PropFactory._meshes[key] = PropFactory._merge(stalks)
		PropFactory._meshes[key + "|heads"] = PropFactory._merge(heads)
	var field := Node3D.new()
	field.name = "Girasoles"
	var green := MeshInstance3D.new()
	green.mesh = PropFactory._meshes[key]
	green.material_override = VectorMaterials.organic(Color(0.22, 0.36, 0.12), Color(0.14, 0.24, 0.08), 2, 0.5, 0.0, 0.01)
	green.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	field.add_child(green)
	var yellow := MeshInstance3D.new()
	yellow.mesh = PropFactory._meshes[key + "|heads"]
	yellow.material_override = VectorMaterials.organic(Color(0.92, 0.72, 0.1), Color(0.36, 0.22, 0.08), 3, 1.6, 0.0, 0.01)
	yellow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	field.add_child(yellow)
	field.add_to_group(&"crop_fields")
	field.set_meta(&"size", size)
	return field


## Poste de telégrafo, con sus crucetas y aisladores. Un tanque lo tumba.
static func telegraph_pole() -> Destructible:
	var prop := PropFactory._base(12.0, LOGS, 1.0)
	prop.crushable = true
	prop.topples = true
	var pole := VectorMaterials.make_box(Vector3(0.24, 7.5, 0.24), LOGS.darkened(0.15), 5, 0.3)
	pole.position.y = 3.75
	prop.add_child(pole)
	for arm in 2:
		PropFactory._decor(prop, Vector3(1.8 - arm * 0.3, 0.12, 0.12), Vector3(0.0, 6.9 - arm * 0.6, 0.0), LOGS.darkened(0.3), 5, 0.3)
		for side: float in [-1.0, 1.0]:
			PropFactory._decor(prop, Vector3(0.1, 0.16, 0.1), Vector3(side * (0.75 - arm * 0.15), 7.04 - arm * 0.6, 0.0), Color(0.82, 0.86, 0.84), 0, 1.0)
	PropFactory._add_box_shape(prop, Vector3(0.4, 7.5, 0.4), Vector3(0.0, 3.75, 0.0))
	return prop


## Pozo de cigüeñal («zhuravl»): brocal de troncos, horquilla y la larga pértiga con su contrapeso.
static func sweep_well() -> Destructible:
	var prop := PropFactory._base(40.0, LOGS, 1.2)
	prop.burns = 12.0
	var curb := VectorMaterials.make_box(Vector3(1.8, 1.0, 1.8), LOGS, 11, 0.6)
	curb.position.y = 0.5
	prop.add_child(curb)
	PropFactory._decor(prop, Vector3(0.25, 4.6, 0.25), Vector3(2.6, 2.3, 0.0), LOGS.darkened(0.2), 5, 0.3)
	var sweep := PropFactory._decor(prop, Vector3(8.5, 0.16, 0.16), Vector3(1.6, 4.9, 0.0), LOGS.darkened(0.1), 5, 0.3)
	sweep.rotation.z = 0.42
	PropFactory._decor(prop, Vector3(0.06, 3.6, 0.06), Vector3(-2.2, 1.9, 0.0), Color(0.2, 0.18, 0.15), 0, 1.0)
	PropFactory._decor(prop, Vector3(0.5, 0.5, 0.5), Vector3(5.4, 6.6, 0.0), Color(0.4, 0.38, 0.35), 3, 0.5)
	PropFactory._add_box_shape(prop, Vector3(2.0, 1.2, 2.0), Vector3(0.0, 0.6, 0.0))
	return prop


## Granero de koljós: nave larga de troncos con cubierta de paja y portón.
static func barn() -> Destructible:
	var size := Vector3(9.0, 4.2, randf_range(18.0, 24.0))
	var prop := PropFactory._base(170.0, LOGS, size.y)
	prop.burns = 60.0
	var walls := VectorMaterials.make_box(size, LOGS, 11, 1.2)
	walls.position.y = size.y * 0.5
	prop.add_child(walls)
	var prism := PrismMesh.new()
	var roof := VectorMaterials.make_outlined(prism, THATCH, THATCH.darkened(0.5), 6, 0.35)
	roof.scale = Vector3(size.x * 1.14, 3.6, size.z * 1.05)
	roof.position.y = size.y + 1.8
	prop.add_child(roof)
	PropFactory._decor(prop, Vector3(3.4, 3.2, 0.14), Vector3(0.0, 1.6, size.z * 0.5 + 0.04), LOGS.darkened(0.35), 8, 1.2)
	PropFactory._add_box_shape(prop, Vector3(size.x, size.y + 2.0, size.z), Vector3(0.0, size.y * 0.5 + 1.0, 0.0))
	return prop


## Carro destruido hace días: el casco calcinado de un modelo de este frente, con la torreta
## descolocada. Cubre como una roca.
static func tank_hulk(stats: TankStats) -> Destructible:
	var prop := PropFactory._base(600.0, Color(0.12, 0.11, 0.1), 1.6)
	var holder := Node3D.new()
	prop.add_child(holder)
	var model: TankModel = TankModel.build(holder, stats, TankModel.plain_paint(Color(0.16, 0.14, 0.12)), false)
	for mesh in model.own:
		mesh.material_override = VectorMaterials.burnt(mesh.material_override)
	if model.turret != null:
		model.turret.rotation.y = randf_range(-2.4, 2.4)
		if randf() < 0.35:
			# La explosión de la munición le saltó la torreta.
			model.turret.position += Vector3(randf_range(-0.5, 0.5), -0.05, randf_range(-0.5, 0.5))
			model.turret.rotation.z = randf_range(-0.18, 0.18)
	if model.gun_pivot != null:
		model.gun_pivot.rotation.x = randf_range(0.02, 0.12)
	holder.rotation = Vector3(randf_range(-0.04, 0.04), 0.0, randf_range(-0.07, 0.07))
	var k: float = stats.body_scale
	PropFactory._add_box_shape(prop, Vector3(model.hull_size.x, 2.2 * k, model.hull_size.z), Vector3(0.0, 1.1 * k, 0.0))
	return prop


# ---------------------------------------------------------------- desierto

## Matorral reseco del desierto: todas las matas de un campo en un solo dibujo. No estorba.
static func scrub(points: PackedVector3Array) -> MultiMeshInstance3D:
	if _scrub_mesh == null:
		var blob := SphereMesh.new()
		blob.radius = 0.5
		blob.height = 0.7
		blob.radial_segments = 6
		blob.rings = 3
		var parts: Array = []
		for i in 4:
			parts.append([blob, Transform3D(Basis.from_scale(Vector3(randf_range(0.8, 1.3), randf_range(0.7, 1.2), randf_range(0.8, 1.3))), Vector3(randf_range(-0.45, 0.45), 0.25, randf_range(-0.45, 0.45)))])
		_scrub_mesh = PropFactory._merge(parts)
		_scrub_material = VectorMaterials.organic(Color(0.36, 0.36, 0.2), Color(0.5, 0.44, 0.26), 2, 0.5, 0.25, 0.006)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = _scrub_mesh
	multi.instance_count = points.size()
	for i in points.size():
		var k: float = randf_range(0.7, 1.7)
		multi.set_instance_transform(i, Transform3D(Basis(Vector3.UP, randf() * TAU) * Basis.from_scale(Vector3(k, k * randf_range(0.6, 1.0), k)), points[i]))
	var node := MultiMeshInstance3D.new()
	node.name = "Matorral"
	node.multimesh = multi
	node.material_override = _scrub_material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


## Acacia de copa plana, el único árbol que aguanta fuera de los oasis.
static func acacia(height: float) -> Destructible:
	var prop := PropFactory._base(18.0, PropFactory.WOOD, 1.0)
	prop.crushable = true
	prop.topples = true
	prop.burns = 12.0
	var trunk := VectorMaterials.make_outlined(PropFactory._trunk_mesh(), Color(0.34, 0.27, 0.2), Color(0.15, 0.12, 0.08), 1, 0.3)
	trunk.scale = Vector3(0.6, height * 0.7, 0.6)
	trunk.position.y = height * 0.35
	trunk.rotation.z = randf_range(-0.15, 0.15)
	prop.add_child(trunk)
	var crown := MeshInstance3D.new()
	crown.mesh = PropFactory._crown_mesh(randi() % 3)
	crown.material_override = VectorMaterials.organic(Color(0.3, 0.36, 0.16), Color(0.42, 0.44, 0.2), 2, 0.3, 0.4, 0.008)
	crown.scale = Vector3(height * 0.95, height * 0.24, height * 0.95)
	crown.position.y = height * 0.8
	crown.rotation.y = randf() * TAU
	crown.set_meta(&"foliage", true)
	prop.add_child(crown)
	PropFactory._add_box_shape(prop, Vector3(0.5, height, 0.5), Vector3(0.0, height * 0.5, 0.0))
	return prop


## Sangar: parapeto de piedra seca en herradura, lo que se levantaba donde la roca no dejaba
## cavar. Abierto por detrás (+Z).
static func sangar() -> Destructible:
	var tone: Color = PropFactory.mountain_color.lerp(STONE, 0.5)
	var prop := PropFactory._base(150.0, tone, 1.0)
	for part: Array in [[Vector3(0.0, 0.0, -2.6), 0.0, 5.6], [Vector3(-2.9, 0.0, -0.3), PI * 0.5 - 0.3, 4.4], [Vector3(2.9, 0.0, -0.3), PI * 0.5 + 0.3, 4.4]]:
		var size := Vector3(part[2], randf_range(1.0, 1.25), 1.0)
		var wall := VectorMaterials.make_box(size, tone.lightened(randf() * 0.08), 2, 0.7)
		wall.position = (part[0] as Vector3) + Vector3(0.0, size.y * 0.5, 0.0)
		wall.rotation.y = part[1]
		prop.add_child(wall)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		shape.position = wall.position
		shape.rotation.y = part[1]
		prop.add_child(shape)
	return prop


## Jaima beduina: tienda baja de pelo de cabra, oscura, con sus vientos.
static func tent() -> Destructible:
	var cloth: Color = [Color(0.2, 0.17, 0.14), Color(0.3, 0.24, 0.18), Color(0.24, 0.2, 0.2)].pick_random()
	var prop := PropFactory._base(25.0, cloth, 1.2)
	prop.burns = 14.0
	var prism := PrismMesh.new()
	var roof := VectorMaterials.make_outlined(prism, cloth, cloth.lightened(0.25), 8, 0.6)
	roof.scale = Vector3(5.2, 1.5, 8.0)
	roof.position.y = 1.55
	prop.add_child(roof)
	for side: float in [-1.0, 1.0]:
		var flap := VectorMaterials.make_box(Vector3(0.08, 0.9, 7.6), cloth.lightened(0.12), 6, 0.6)
		flap.position = Vector3(side * 2.5, 0.45, 0.0)
		prop.add_child(flap)
		for z: float in [-3.6, 0.0, 3.6]:
			PropFactory._decor(prop, Vector3(0.1, 1.9, 0.1), Vector3(side * 0.02, 0.95, z), LOGS, 5, 0.3)
	PropFactory._decor(prop, Vector3(1.6, 0.05, 2.4), Vector3(0.0, 0.03, 5.4), Color(0.55, 0.2, 0.16), 6, 0.3)
	PropFactory._add_box_shape(prop, Vector3(5.0, 1.8, 7.6), Vector3(0.0, 0.9, 0.0))
	return prop


## Campo de minas cercado («jardines del diablo»): alambre bajo en todo el perímetro y los
## carteles de la calavera. Solo dibujo: dentro no hay minas que hagan daño.
static func minefield(size: Vector2) -> Node3D:
	var root := Node3D.new()
	root.name = "CampoDeMinas"
	var b := Blocks.new()
	var wood := Color(0.36, 0.3, 0.2)
	var steel := Color(0.2, 0.19, 0.18)
	var half: Vector2 = size * 0.5
	for edge in 4:
		var horizontal: bool = edge < 2
		var length: float = size.x if horizontal else size.y
		var offset: float = (half.y if horizontal else half.x) * (1.0 if edge % 2 == 0 else -1.0)
		var posts: int = maxi(int(length / 5.0), 1)
		for i in posts + 1:
			var along: float = -length * 0.5 + i * length / posts
			b.box(wood, Vector3(0.12, 0.9, 0.12), Vector3(along, 0.0, offset) if horizontal else Vector3(offset, 0.0, along))
		b.box(steel, Vector3(length, 0.03, 0.03) if horizontal else Vector3(0.03, 0.03, length), Vector3(0.0, 0.7, offset) if horizontal else Vector3(offset, 0.7, 0.0))
		# Cartel: tabla negra con la calavera clara.
		var sign_at: Vector3 = Vector3(0.0, 0.0, offset) if horizontal else Vector3(offset, 0.0, 0.0)
		var yaw: float = 0.0 if horizontal else PI * 0.5
		b.box(wood, Vector3(0.1, 1.5, 0.1), sign_at)
		b.box(Color(0.1, 0.1, 0.1), Vector3(0.9, 0.6, 0.05), sign_at + Vector3(0.0, 1.0, 0.0), yaw)
		b.ball(Color(0.88, 0.86, 0.78), Vector3(0.3, 0.3, 0.09), sign_at + Vector3(0.0, 1.36, 0.0), yaw)
		b.box(Color(0.88, 0.86, 0.78), Vector3(0.5, 0.07, 0.07), sign_at + Vector3(0.0, 1.1, 0.0), yaw, 0.5)
		b.box(Color(0.88, 0.86, 0.78), Vector3(0.5, 0.07, 0.07), sign_at + Vector3(0.0, 1.1, 0.0), yaw, -0.5)
	# Tierra removida donde se enterraron.
	for i in int(size.x * size.y / 60.0):
		b.ball(Color(0.5, 0.4, 0.27), Vector3(1.1, 0.16, 1.1), Vector3(randf_range(-half.x + 2.0, half.x - 2.0), 0.02, randf_range(-half.y + 2.0, half.y - 2.0)))
	b.commit(root)
	return root


## Camión quemado, abandonado en la pista.
static func truck_wreck() -> Destructible:
	var soot := Color(0.1, 0.09, 0.08)
	var rust := Color(0.3, 0.17, 0.1)
	var prop := PropFactory._base(110.0, soot, 1.5)
	var chassis := VectorMaterials.make_box(Vector3(2.1, 0.4, 6.0), soot, 4, 0.8)
	chassis.position.y = 0.9
	prop.add_child(chassis)
	var cab := VectorMaterials.make_box(Vector3(2.0, 1.5, 1.6), rust.darkened(0.3), 4, 0.9)
	cab.position = Vector3(0.0, 1.85, -1.3)
	prop.add_child(cab)
	var hood := VectorMaterials.make_box(Vector3(1.5, 0.9, 1.5), rust, 4, 0.9)
	hood.position = Vector3(0.0, 1.55, -2.7)
	prop.add_child(hood)
	for side: float in [-1.0, 1.0]:
		var board := VectorMaterials.make_box(Vector3(0.08, 0.7, 3.2), soot.lightened(0.06), 5, 0.6)
		board.position = Vector3(side * 1.0, 1.45, 1.4)
		board.rotation.z = side * randf_range(0.0, 0.3)
		prop.add_child(board)
	for i in 3:
		PropFactory._decor(prop, Vector3(0.1, 1.3, 0.1), Vector3(-0.9 + i * 0.9, 1.75, 1.4 + (i - 1) * 1.2), soot, 4, 0.5)
	var wheel := CylinderMesh.new()
	wheel.top_radius = 0.5
	wheel.bottom_radius = 0.5
	wheel.height = 0.3
	wheel.radial_segments = 8
	for spot: Vector3 in [Vector3(-1.05, 0.5, -2.4), Vector3(1.05, 0.5, -2.4), Vector3(-1.05, 0.5, 1.9), Vector3(1.05, 0.5, 1.9)]:
		var tyre := MeshInstance3D.new()
		tyre.mesh = wheel
		tyre.material_override = VectorMaterials.paint(Color(0.05, 0.05, 0.05))
		tyre.position = spot
		tyre.rotation.z = PI * 0.5
		tyre.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		prop.add_child(tyre)
	prop.rotation.z = randf_range(-0.04, 0.04)
	PropFactory._add_box_shape(prop, Vector3(2.2, 2.4, 6.2), Vector3(0.0, 1.2, 0.0))
	return prop


## Tramo de escarpe: un farallón de roca en estratos, alargado a lo largo de X. No se puede
## subir ni romper: se pasa por los collados que deja entre tramo y tramo.
static func scarp(length: float, height: float, width: float = 9.0) -> Destructible:
	var prop := PropFactory._base(1.0, PropFactory.ROCK_COLOR, height * 0.3)
	prop.indestructible = true
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps: int = maxi(int(length / 3.0), 3)
	var ring: Array[Vector2] = [Vector2(-1.0, 0.0), Vector2(-0.82, 0.55), Vector2(-0.5, 0.92), Vector2(0.0, 1.0), Vector2(0.45, 0.8), Vector2(0.8, 0.4), Vector2(1.0, 0.0)]
	var phase: float = randf() * TAU
	for i in steps + 1:
		var x: float = -length * 0.5 + i * length / steps
		var end: float = minf(1.0, minf(i, steps - i) * 0.5 + 0.15)
		var tall: float = (0.72 + 0.28 * absf(sin(i * 0.9 + phase)) + randf() * 0.12) * end
		var fat: float = (0.85 + randf() * 0.3) * (0.6 + 0.4 * end)
		for point in ring:
			st.add_vertex(Vector3(x, point.y * height * tall - 0.1, point.x * width * 0.5 * fat))
	for i in steps:
		for j in ring.size() - 1:
			var a: int = i * ring.size() + j
			var c: int = a + ring.size()
			for index: int in [a, c, a + 1, a + 1, c, c + 1]:
				st.add_index(index)
	st.generate_normals()
	var visual := MeshInstance3D.new()
	visual.mesh = st.commit()
	var tone: Color = PropFactory.mountain_color
	visual.material_override = VectorMaterials.textured(tone, tone.lerp(PropFactory.ROCK_COLOR, 0.5).darkened(0.4), 7, 2.2)
	prop.add_child(visual)
	PropFactory._add_box_shape(prop, Vector3(length - 2.0, height * 0.8, width * 0.7), Vector3(0.0, height * 0.4, 0.0))
	return prop


# ---------------------------------------------------------------- Normandía

## Granja normanda de piedra: la casa, dos naves formando patio y el palomar redondo. Devuelve
## las piezas ya colocadas en torno al origen (el patio abre hacia +Z); ocupa unos 34 × 30 m.
static func stone_farm() -> Node3D:
	var root := Node3D.new()
	root.name = "Granja"
	var house: Destructible = PropFactory.townhouse(Vector3(15.0, 6.6, 7.5), 0)
	house.position = Vector3(0.0, 0.0, -10.0)
	root.add_child(house)
	for side: float in [-1.0, 1.0]:
		var shed: Destructible = PropFactory.house(Vector3(6.5, 4.2, 16.0))
		shed.position = Vector3(side * 12.5, 0.0, 2.0)
		shed.rotation.y = -side * PI * 0.5
		root.add_child(shed)
	# Tapia del patio, con el portón en medio.
	for side: float in [-1.0, 1.0]:
		var wall: Destructible = PropFactory.wall(6.5, STONE, 2)
		wall.position = Vector3(side * 6.4, 0.0, 11.0)
		root.add_child(wall)
		var pier := PropFactory.wall(1.0, STONE.lightened(0.06), 2)
		pier.position = Vector3(side * 3.0, 0.0, 11.0)
		pier.scale.y = 1.5
		root.add_child(pier)
	# Palomar: torre redonda con tejado en punta.
	var cote := PropFactory._base(160.0, STONE, 4.0)
	var drum := CylinderMesh.new()
	drum.top_radius = 2.6
	drum.bottom_radius = 2.8
	drum.height = 7.5
	drum.radial_segments = 10
	var tower := VectorMaterials.make_outlined(drum, STONE, STONE.darkened(0.4), 3, 0.7)
	tower.position.y = 3.75
	cote.add_child(tower)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 3.1
	cone.height = 3.6
	cone.radial_segments = 10
	var cap := VectorMaterials.make_outlined(cone, Color(0.27, 0.28, 0.31), Color(0.14, 0.14, 0.16), 5, 0.5)
	cap.position.y = 9.3
	cote.add_child(cap)
	PropFactory._add_box_shape(cote, Vector3(5.0, 9.0, 5.0), Vector3(0.0, 4.5, 0.0))
	cote.position = Vector3(-19.5, 0.0, -11.0)
	root.add_child(cote)
	return root


## Crucero de piedra en un cruce de caminos.
static func calvary() -> Destructible:
	var prop := PropFactory._base(60.0, STONE, 1.0)
	prop.topples = true
	for step in 3:
		var slab := VectorMaterials.make_box(Vector3(2.4 - step * 0.6, 0.35, 2.4 - step * 0.6), STONE.darkened(step * 0.04), 2, 0.8)
		slab.position.y = 0.17 + step * 0.35
		prop.add_child(slab)
	PropFactory._decor(prop, Vector3(0.3, 3.4, 0.3), Vector3(0.0, 2.75, 0.0), STONE.lightened(0.05), 0, 1.0)
	PropFactory._decor(prop, Vector3(1.4, 0.28, 0.28), Vector3(0.0, 3.7, 0.0), STONE.lightened(0.05), 0, 1.0)
	PropFactory._add_box_shape(prop, Vector3(1.8, 4.2, 1.8), Vector3(0.0, 2.1, 0.0))
	return prop


## Planeador Horsa estrellado: fuselaje de madera partido, con las franjas de invasión, un ala
## en el suelo y la cola levantada.
static func glider_wreck() -> Destructible:
	var dark := Color(0.14, 0.15, 0.13)
	var prop := PropFactory._base(70.0, dark, 2.0)
	prop.burns = 20.0
	var tube := CylinderMesh.new()
	tube.top_radius = 1.25
	tube.bottom_radius = 1.25
	tube.height = 1.0
	tube.radial_segments = 10
	# Fuselaje en tres tramos; el del medio lleva las franjas blancas y negras.
	for part: Array in [[Vector3(0.0, 1.5, -6.5), 5.5, dark, 0.0], [Vector3(0.0, 1.5, -2.5), 2.5, Color(0.88, 0.88, 0.84), 0.0], [Vector3(0.3, 1.9, 4.2), 9.0, dark, 0.14]]:
		var section := MeshInstance3D.new()
		section.mesh = tube
		section.material_override = VectorMaterials.textured(part[2], (part[2] as Color).darkened(0.5), 4, 1.0)
		section.scale = Vector3(1.0, part[1], 1.0)
		section.position = part[0]
		section.rotation = Vector3(PI * 0.5 - float(part[3]), 0.0, 0.0)
		prop.add_child(section)
	for stripe in 2:
		PropFactory._decor(prop, Vector3(2.56, 2.56, 0.5), Vector3(0.0, 1.5, -3.0 + stripe * 1.0), Color(0.06, 0.06, 0.06), 0, 1.0)
	var nose := SphereMesh.new()
	nose.radius = 1.25
	nose.height = 2.6
	nose.radial_segments = 10
	nose.rings = 5
	var cockpit := VectorMaterials.make_outlined(nose, Color(0.3, 0.36, 0.38), dark, 0, 1.0)
	cockpit.position = Vector3(0.0, 1.5, -9.3)
	prop.add_child(cockpit)
	# Ala alta: una mitad sigue en su sitio y la otra, arrancada, apoya la punta en tierra.
	var wing := VectorMaterials.make_box(Vector3(12.5, 0.3, 3.0), dark.lightened(0.06), 4, 1.5)
	wing.position = Vector3(-7.4, 2.9, -3.4)
	wing.rotation.z = 0.05
	prop.add_child(wing)
	var torn := VectorMaterials.make_box(Vector3(11.5, 0.3, 3.0), dark.lightened(0.06), 4, 1.5)
	torn.position = Vector3(6.6, 1.5, -2.4)
	torn.rotation = Vector3(0.0, -0.3, -0.24)
	prop.add_child(torn)
	var fin := VectorMaterials.make_box(Vector3(0.25, 3.4, 2.6), dark, 4, 1.2)
	fin.position = Vector3(0.9, 4.6, 8.0)
	prop.add_child(fin)
	var tail := VectorMaterials.make_box(Vector3(6.5, 0.2, 1.9), dark.lightened(0.06), 4, 1.2)
	tail.position = Vector3(0.9, 3.6, 8.0)
	prop.add_child(tail)
	PropFactory._add_box_shape(prop, Vector3(2.6, 3.0, 17.0), Vector3(0.0, 1.5, -1.0))
	return prop


## Estacas contra planeadores («espárragos de Rommel») plantadas en un prado: postes altos a
## trechos regulares. Solo dibujo.
static func asparagus(size: Vector2) -> Node3D:
	var root := Node3D.new()
	root.name = "Estacas"
	var b := Blocks.new()
	var x: float = -size.x * 0.5
	while x <= size.x * 0.5:
		var z: float = -size.y * 0.5
		while z <= size.y * 0.5:
			b.box(Color(0.3, 0.24, 0.17), Vector3(0.2, randf_range(2.8, 3.6), 0.2), Vector3(x + randf_range(-0.8, 0.8), 0.0, z + randf_range(-0.8, 0.8)), 0.0, randf_range(-0.06, 0.06))
			z += 9.0
		x += 9.0
	b.commit(root)
	return root
