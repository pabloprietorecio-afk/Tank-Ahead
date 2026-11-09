class_name TankModel
## Construye la malla de un tanque histórico a partir de su ficha (TankStats) y su pintura.
## Todo se genera por código con cajas, cilindros y texturas procedurales.

const HULL_SIZE := Vector3(3.2, 0.9, 4.6)
const TURRET_SIZE := Vector3(1.8, 0.7, 2.0)
const BARREL_SIZE := Vector3(0.22, 0.22, 2.6)

const DARK_METAL := Color(0.14, 0.13, 0.12)
const RUBBER := Color(0.08, 0.08, 0.08)

var tank: Node3D
var stats: TankStats
var paint: Dictionary
var k: float
var own: Array[MeshInstance3D] = []

var turret: Node3D
var gun_pivot: Node3D
var muzzle: Marker3D
var hull_size: Vector3
var hull_bottom: float
var deck: float


static func build(owner_tank: Node3D, tank_stats: TankStats, tank_paint: Dictionary, is_player: bool) -> TankModel:
	var model := TankModel.new()
	model.tank = owner_tank
	model.stats = tank_stats
	model.paint = tank_paint
	model.k = tank_stats.body_scale
	model._build(is_player)
	return model


## Pintura por defecto (verde oliva liso).
static func plain_paint(base: Color) -> Dictionary:
	return {"base": base, "mode": 0, "a": base, "b": base}


func _material(size: Vector3, color: Color, pattern: int, pattern_scale: float, camo: bool = true) -> ShaderMaterial:
	var mat: ShaderMaterial = VectorMaterials.box_edges(size, color, pattern, pattern_scale)
	if camo and paint.get("mode", 0) > 0:
		mat.set_shader_parameter("camo_mode", paint["mode"])
		mat.set_shader_parameter("camo_a", paint["a"])
		mat.set_shader_parameter("camo_b", paint["b"])
		mat.set_shader_parameter("camo_scale", 1.4 * k)
	return mat


func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, pattern: int = 0, pattern_scale: float = 1.0, camo: bool = true) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _material(size, color, pattern, pattern_scale, camo)
	instance.position = pos
	parent.add_child(instance)
	own.append(instance)
	return instance


func _cylinder(parent: Node3D, radius: float, height: float, pos: Vector3, color: Color, segments: int = 12, camo: bool = true) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 1
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	var mat: ShaderMaterial = VectorMaterials.textured(color, color.darkened(0.4), 4 if not camo else 0, 0.5).duplicate()
	if camo and paint.get("mode", 0) > 0:
		mat.set_shader_parameter("camo_mode", paint["mode"])
		mat.set_shader_parameter("camo_a", paint["a"])
		mat.set_shader_parameter("camo_b", paint["b"])
		mat.set_shader_parameter("camo_scale", 1.4 * k)
	instance.material_override = mat
	instance.position = pos
	parent.add_child(instance)
	own.append(instance)
	return instance


func _flat(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = VectorMaterials.flat(color)
	instance.position = pos
	parent.add_child(instance)
	own.append(instance)
	return instance


func _build(is_player: bool) -> void:
	var base: Color = paint.get("base", Color(0.35, 0.38, 0.25))
	hull_size = HULL_SIZE * stats.hull_proportions * k
	hull_bottom = (0.55 if stats.wheels > 0 else 0.25) * k
	deck = hull_bottom + hull_size.y
	var front: float = -hull_size.z * 0.5
	var rear: float = hull_size.z * 0.5

	# Casco: cuerpo principal + frontal inclinado + parte trasera.
	var body_len: float = hull_size.z * (0.78 if stats.sloped else 0.88)
	_box(tank, Vector3(hull_size.x, hull_size.y, body_len), Vector3(0.0, hull_bottom + hull_size.y * 0.5, (hull_size.z - body_len) * 0.5), base, 4, 2.0 * k)
	var glacis_len: float = hull_size.z - body_len
	var glacis := _box(tank, Vector3(hull_size.x * 0.98, 0.16 * k, glacis_len / cos(deg_to_rad(55.0)) * 0.62 + 0.3 * k), Vector3.ZERO, base, 4, 1.5 * k)
	glacis.position = Vector3(0.0, hull_bottom + hull_size.y * 0.55, front + glacis_len * 0.55)
	glacis.rotation.x = deg_to_rad(-(60.0 if stats.sloped else 35.0))
	if stats.sloped:
		for side in [-1.0, 1.0]:
			var plate := _box(tank, Vector3(0.12 * k, hull_size.y * 0.7, body_len * 0.98), Vector3(side * hull_size.x * 0.5, deck - hull_size.y * 0.3, (hull_size.z - body_len) * 0.5), base, 4, 1.5 * k)
			plate.rotation.z = side * deg_to_rad(-25.0)

	# Tren de rodaje: orugas con ruedas, o ruedas de blindado.
	if stats.wheels > 0:
		var per_side: int = stats.wheels / 2
		for side in [-1.0, 1.0]:
			for i in per_side:
				var z: float = lerpf(front * 0.7, rear * 0.7, float(i) / maxf(per_side - 1, 1))
				var wheel := _cylinder(tank, 0.48 * k, 0.32 * k, Vector3(side * (hull_size.x * 0.5 + 0.05 * k), 0.48 * k, z), RUBBER, 12, false)
				wheel.rotation.z = PI * 0.5
	else:
		var track_size := Vector3(0.6 * k, 0.85 * k, hull_size.z * 1.02)
		for side in [-1.0, 1.0]:
			var x: float = side * (hull_size.x * 0.5 + track_size.x * 0.5 - 0.1 * k)
			_box(tank, track_size, Vector3(x, track_size.y * 0.5, 0.0), DARK_METAL, 3, 0.45 * k, false)
			# Guardabarros sobre la oruga.
			_box(tank, Vector3(track_size.x * 1.1, 0.06 * k, track_size.z * 1.02), Vector3(x, track_size.y + 0.04 * k, 0.0), base, 0, 1.0)
			_running_gear(x + side * (track_size.x * 0.5 + 0.02 * k), track_size, side)
			if stats.skirts:
				_box(tank, Vector3(0.06 * k, track_size.y * 0.75, track_size.z * 0.85), Vector3(side * (hull_size.x * 0.5 + track_size.x + 0.02 * k), track_size.y * 0.55, 0.05 * k), base, 4, 0.9 * k)

	_build_turret(base)
	_build_hull_details(base, is_player, front, rear)
	_build_extras(base, is_player, front, rear)
	_build_markings()


## Ruedas de rodaje visibles, rodillos de retorno, rueda motriz delante y tensora detrás.
func _running_gear(x: float, track_size: Vector3, side: float) -> void:
	var wheels: int = clampi(int(hull_size.z / (0.95 * k)), 4, 7)
	var span: float = track_size.z * 0.78
	for i in wheels:
		var z: float = -span * 0.5 + span * i / float(wheels - 1)
		var wheel := _cylinder(tank, 0.34 * k, 0.12 * k, Vector3(x, 0.36 * k, z), Color(0.2, 0.2, 0.19), 12, false)
		wheel.rotation.z = PI * 0.5
		var hub := _cylinder(tank, 0.12 * k, 0.14 * k, Vector3(x + side * 0.02 * k, 0.36 * k, z), Color(0.35, 0.33, 0.3), 8, false)
		hub.rotation.z = PI * 0.5
	for i in 3:
		var z: float = -span * 0.35 + span * 0.35 * i
		var roller := _cylinder(tank, 0.12 * k, 0.1 * k, Vector3(x, track_size.y - 0.12 * k, z), Color(0.2, 0.2, 0.19), 8, false)
		roller.rotation.z = PI * 0.5
	for end in [-1.0, 1.0]:
		var big := _cylinder(tank, 0.3 * k, 0.14 * k, Vector3(x, 0.5 * k, end * track_size.z * 0.46), Color(0.25, 0.24, 0.22), 10, false)
		big.rotation.z = PI * 0.5


func _build_turret(base: Color) -> void:
	var turret_size: Vector3 = TURRET_SIZE * stats.turret_scale * k
	turret = Node3D.new()
	turret.name = "Turret"
	if stats.casemate:
		# Casamata: superestructura ancha y baja integrada en el casco.
		turret_size = Vector3(hull_size.x * 0.95, hull_size.y * 0.8, hull_size.z * 0.55)
		turret.position = Vector3(0.0, deck + turret_size.y * 0.5, -hull_size.z * 0.08)
	else:
		turret.position = Vector3(0.0, deck + turret_size.y * 0.5, 0.15 * k)
	tank.add_child(turret)

	if stats.open_top:
		var t: float = 0.1 * k
		for side in [-1.0, 1.0]:
			_box(turret, Vector3(t, turret_size.y, turret_size.z), Vector3(side * turret_size.x * 0.5, 0.0, 0.0), base, 4, 0.8 * k)
			_box(turret, Vector3(turret_size.x, turret_size.y, t), Vector3(0.0, 0.0, side * turret_size.z * 0.5), base, 4, 0.8 * k)
		_box(turret, Vector3(turret_size.x * 0.9, 0.05, turret_size.z * 0.9), Vector3(0.0, -turret_size.y * 0.45, 0.0), DARK_METAL, 0, 1.0, false)
	elif stats.round_turret:
		var cyl := _cylinder(turret, 1.0, 1.0, Vector3.ZERO, base, 14)
		cyl.scale = Vector3(turret_size.x * 0.55, turret_size.y, turret_size.z * 0.5)
	elif stats.casemate:
		_box(turret, turret_size, Vector3.ZERO, base, 4, 1.4 * k)
		var slope := _box(turret, Vector3(turret_size.x, 0.14 * k, turret_size.y * 1.3), Vector3(0.0, 0.0, -turret_size.z * 0.5 - turret_size.y * 0.3), base, 4, 1.0 * k)
		slope.rotation.x = deg_to_rad(-50.0)
	else:
		_box(turret, turret_size, Vector3.ZERO, base, 4, 1.4 * k)

	if not stats.casemate and not stats.open_top:
		# Cesta trasera (marca la parte de atrás) y escotilla.
		_box(turret, Vector3(turret_size.x * 0.75, turret_size.y * 0.5, 0.45 * k), Vector3(0.0, -turret_size.y * 0.1, turret_size.z * 0.5 + 0.22 * k), base.darkened(0.15), 6, 0.15 * k)
		_box(turret, Vector3(0.55, 0.1, 0.55) * k, Vector3(-turret_size.x * 0.22, turret_size.y * 0.5 + 0.05 * k, turret_size.z * 0.15), base.darkened(0.2), 4, 0.3 * k)
	if stats.has_dome:
		_cylinder(turret, 0.32 * k, 0.32 * k, Vector3(turret_size.x * 0.22, turret_size.y * 0.5 + 0.16 * k, turret_size.z * 0.2), base.darkened(0.1), 10)
	if stats.has_antenna:
		_box(turret, Vector3(0.05, 2.6, 0.05) * k, Vector3(-turret_size.x * 0.4, turret_size.y * 0.5 + 1.3 * k, turret_size.z * 0.4), DARK_METAL, 0, 1.0, false)

	gun_pivot = Node3D.new()
	gun_pivot.name = "GunPivot"
	gun_pivot.position = Vector3(0.0, 0.05 * k, -turret_size.z * 0.5)
	turret.add_child(gun_pivot)
	_box(gun_pivot, Vector3(turret_size.x * (0.35 if stats.casemate else 0.5), turret_size.y * 0.6, 0.35 * k), Vector3(0.0, 0.0, -0.1 * k), base.darkened(0.15), 4, 0.4 * k)
	var barrel_size := Vector3(BARREL_SIZE.x * stats.barrel_thickness, BARREL_SIZE.y * stats.barrel_thickness, BARREL_SIZE.z * stats.barrel_length) * k
	var barrels: int = maxi(stats.barrel_count, 1)
	for b in barrels:
		var x: float = 0.0 if barrels == 1 else (b - (barrels - 1) * 0.5) * barrel_size.x * 2.0
		var barrel := _cylinder(gun_pivot, barrel_size.x * 0.5, barrel_size.z, Vector3(x, 0.0, -barrel_size.z * 0.5), base.darkened(0.25), 8, false)
		barrel.rotation.x = PI * 0.5
		if stats.muzzle_brake:
			_box(gun_pivot, Vector3(barrel_size.x * 1.8, barrel_size.y * 1.4, 0.4 * k), Vector3(x, 0.0, -barrel_size.z + 0.15 * k), DARK_METAL, 6, 0.12 * k, false)
	muzzle = Marker3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector3(0.0, 0.0, -barrel_size.z - 0.15 * k)
	gun_pivot.add_child(muzzle)
	if stats.traverse_limit_deg > 0.0:
		turret.set_meta("traverse_limit", deg_to_rad(stats.traverse_limit_deg))


func _build_hull_details(base: Color, is_player: bool, front: float, rear: float) -> void:
	for side in [-1.0, 1.0]:
		# Faros delanteros y pilotos traseros: dejan claro el frente y la cola.
		_flat(tank, Vector3(0.36, 0.22, 0.1) * k, Vector3(side * hull_size.x * 0.36, deck - 0.1 * k, front + 0.05 * k), Color(1.0, 0.95, 0.75))
		_flat(tank, Vector3(0.32, 0.16, 0.08) * k, Vector3(side * hull_size.x * 0.4, deck - 0.15 * k, rear + 0.04 * k), Color(1.0, 0.08, 0.05))
		_cylinder(tank, 0.12 * k, 0.45 * k, Vector3(side * hull_size.x * 0.25, deck + 0.05 * k, rear - 0.2 * k), DARK_METAL, 8, false).rotation.x = PI * 0.5
	_box(tank, Vector3(hull_size.x * 0.55, 0.05 * k, hull_size.z * 0.2), Vector3(0.0, deck + 0.025 * k, rear - hull_size.z * 0.16), DARK_METAL, 6, 0.12 * k, false)
	if stats.bow_mg:
		var mg := _cylinder(tank, 0.06 * k, 0.6 * k, Vector3(hull_size.x * 0.25, deck - 0.2 * k, front - 0.2 * k), DARK_METAL, 6, false)
		mg.rotation.x = PI * 0.5
	# Herramientas sobre la cubierta.
	_box(tank, Vector3(0.12, 0.1, hull_size.z * 0.4) * Vector3(k, k, 1.0), Vector3(hull_size.x * 0.4, deck + 0.05 * k, 0.1 * k), Color(0.35, 0.25, 0.15), 5, 0.2, false)
	if is_player:
		for side in [-1.0, 1.0]:
			var stripe := _flat(tank, Vector3(0.16 * k, 0.03 * k, hull_size.x * 0.38), Vector3(side * hull_size.x * 0.12, deck + 0.04 * k, front + hull_size.z * 0.12), Color(1.0, 0.85, 0.1))
			stripe.rotation.y = side * deg_to_rad(-38.0)


## Detalles de equipo: eslabones de repuesto, bidones, cajas, periscopios y el comandante.
func _build_extras(base: Color, is_player: bool, front: float, rear: float) -> void:
	# Eslabones de oruga de repuesto en el frontal.
	for side in [-1.0, 1.0]:
		var links := _box(tank, Vector3(0.55 * k, 0.08 * k, 0.7 * k), Vector3(side * hull_size.x * 0.22, deck - 0.05 * k, front + 0.35 * k), DARK_METAL, 3, 0.18 * k, false)
		links.rotation.x = deg_to_rad(-35.0)
	# Bidones en la parte trasera.
	var can_color: Color = Color(0.3, 0.33, 0.22) if stats.nation != "DE" else Color(0.35, 0.33, 0.28)
	for side in [-1.0, 1.0]:
		_box(tank, Vector3(0.22, 0.5, 0.36) * k, Vector3(side * hull_size.x * 0.42, deck + 0.25 * k, rear - 0.25 * k), can_color, 4, 0.25 * k, false)
	# Caja de herramientas en el guardabarros.
	_box(tank, Vector3(0.45, 0.35, 1.2) * k, Vector3(-hull_size.x * 0.42, deck + 0.17 * k, -0.4 * k), base.darkened(0.2), 5, 0.3 * k)
	if stats.casemate or stats.open_top:
		return
	var turret_size: Vector3 = TURRET_SIZE * stats.turret_scale * k
	# Cajas de estiba a los lados de la torreta.
	if not stats.round_turret:
		for side in [-1.0, 1.0]:
			_box(turret, Vector3(0.25 * k, turret_size.y * 0.5, turret_size.z * 0.4), Vector3(side * (turret_size.x * 0.5 + 0.13 * k), 0.0, turret_size.z * 0.15), base.darkened(0.15), 5, 0.2 * k)
	# Periscopios.
	for i in 2:
		_box(turret, Vector3(0.18, 0.14, 0.12) * k, Vector3((0.3 - i * 0.6) * turret_size.x * 0.5, turret_size.y * 0.5 + 0.07 * k, -turret_size.z * 0.3), Color(0.1, 0.12, 0.13), 0, 1.0, false)
	# Comandante asomado por la escotilla (no en el tanque propio, que se ve desde dentro).
	if not is_player:
		var hatch_pos := Vector3(turret_size.x * 0.22 if stats.has_dome else -turret_size.x * 0.2, turret_size.y * 0.5, turret_size.z * 0.18)
		var uniform: Color = Color(0.3, 0.3, 0.22) if stats.nation != "DE" else Color(0.22, 0.22, 0.24)
		_box(turret, Vector3(0.42, 0.45, 0.32) * k, hatch_pos + Vector3(0.0, 0.3 * k, 0.0), uniform, 0, 1.0, false)
		var head := MeshInstance3D.new()
		var head_mesh := SphereMesh.new()
		head_mesh.radius = 0.14 * k
		head_mesh.height = 0.28 * k
		head.mesh = head_mesh
		head.material_override = VectorMaterials.paint(Color(0.75, 0.58, 0.45))
		head.position = hatch_pos + Vector3(0.0, 0.66 * k, 0.0)
		turret.add_child(head)
		own.append(head)
		var cap := _box(turret, Vector3(0.34, 0.1, 0.34) * k, hatch_pos + Vector3(0.0, 0.8 * k, 0.0), Color(0.12, 0.12, 0.12), 0, 1.0, false)


## Distintivos nacionales en los laterales y en la cubierta trasera (identificación aérea).
func _build_markings() -> void:
	var size: float = 0.75 * k
	var turret_size: Vector3 = TURRET_SIZE * stats.turret_scale * k
	var side_parent: Node3D = turret if not stats.casemate else tank
	var side_x: float = (turret_size.x * (0.56 if stats.round_turret else 0.51)) if not stats.casemate else hull_size.x * 0.51
	var side_y: float = 0.05 * k if not stats.casemate else hull_bottom + hull_size.y * 0.5
	for side in [-1.0, 1.0]:
		var mark := _marking(size)
		mark.position = Vector3(side * (side_x + 0.03 * k), side_y, 0.0)
		mark.rotation.y = side * PI * 0.5
		side_parent.add_child(mark)
	var top := _marking(size * 1.4)
	top.position = Vector3(0.0, deck + 0.06 * k, hull_size.z * 0.3)
	top.rotation.x = -PI * 0.5
	tank.add_child(top)


func _marking(size: float) -> Node3D:
	var root := Node3D.new()
	match stats.nation:
		"DE":
			# Balkenkreuz: cruz negra con bordes blancos.
			for part in [[Color(0.95, 0.95, 0.95), 1.0, 0.0], [Color(0.05, 0.05, 0.05), 0.6, 0.01]]:
				var w: float = size * part[1]
				root.add_child(_decal(Vector3(w * 0.42, w * 1.6, 0.01), Vector3(0.0, 0.0, part[2]), part[0]))
				root.add_child(_decal(Vector3(w * 1.6, w * 0.42, 0.01), Vector3(0.0, 0.0, part[2]), part[0]))
		"SU":
			root.add_child(_star(size * 0.75, Color(0.85, 0.08, 0.06)))
		"UK":
			for ring in [[Color(0.1, 0.2, 0.55), 1.0, 0.0], [Color(0.95, 0.95, 0.95), 0.68, 0.01], [Color(0.75, 0.08, 0.06), 0.36, 0.02]]:
				var disc := MeshInstance3D.new()
				var mesh := CylinderMesh.new()
				mesh.top_radius = size * 0.5 * ring[1]
				mesh.bottom_radius = mesh.top_radius
				mesh.height = 0.01
				mesh.radial_segments = 20
				disc.mesh = mesh
				disc.material_override = VectorMaterials.paint(ring[0])
				disc.rotation.x = PI * 0.5
				disc.position.z = ring[2]
				root.add_child(disc)
				own.append(disc)
		_:
			root.add_child(_star(size * 0.75, Color(0.95, 0.95, 0.95)))
	return root


func _decal(size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = VectorMaterials.paint(color)
	instance.position = pos
	own.append(instance)
	return instance


func _star(radius: float, color: Color) -> MeshInstance3D:
	var verts := PackedVector3Array()
	var inner: float = radius * 0.4
	for i in 5:
		var a0: float = -PI * 0.5 + TAU * i / 5.0
		var a1: float = a0 + TAU / 10.0
		var a2: float = a0 + TAU / 5.0
		var outer := Vector3(cos(a0), -sin(a0), 0.0) * radius
		var mid := Vector3(cos(a1), -sin(a1), 0.0) * inner
		var next_mid := Vector3(cos(a0 - TAU / 10.0), -sin(a0 - TAU / 10.0), 0.0) * inner
		verts.append_array([Vector3.ZERO, next_mid, outer, Vector3.ZERO, outer, mid])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = VectorMaterials.paint(color)
	own.append(instance)
	return instance
