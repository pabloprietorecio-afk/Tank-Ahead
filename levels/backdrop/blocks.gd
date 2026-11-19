class_name Blocks
extends RefCounted
## Maquetas lejanas hechas de piezas simples (cajas, tejados, agujas, chimeneas, cúpulas) que se
## funden en una sola malla por color: un pueblo entero o una flota son media docena de mallas.
## Solo dibujo: sin colisión ni sombra. Las medidas van en metros y las posiciones son las de la
## base de cada pieza.

static var _box: BoxMesh
static var _prism: PrismMesh
static var _cyl: CylinderMesh
static var _spire4: CylinderMesh
static var _spire8: CylinderMesh
static var _ball: SphereMesh

var _parts: Dictionary = {}


func _init() -> void:
	if _box != null:
		return
	_box = BoxMesh.new()
	_prism = PrismMesh.new()
	_cyl = CylinderMesh.new()
	_cyl.top_radius = 0.5
	_cyl.bottom_radius = 0.5
	_cyl.height = 1.0
	_cyl.radial_segments = 8
	_cyl.rings = 1
	_spire4 = CylinderMesh.new()
	_spire4.top_radius = 0.0
	_spire4.bottom_radius = 0.5
	_spire4.height = 1.0
	_spire4.radial_segments = 4
	_spire4.rings = 1
	_spire8 = _spire4.duplicate()
	_spire8.radial_segments = 8
	_ball = SphereMesh.new()
	_ball.radius = 0.5
	_ball.height = 1.0
	_ball.radial_segments = 10
	_ball.rings = 5


func _add(color: Color, mesh: Mesh, xform: Transform3D) -> void:
	var key: String = color.to_html(false)
	if not _parts.has(key):
		_parts[key] = [color, []]
	(_parts[key][1] as Array).append([mesh, xform])


## Caja de `size` con la base centrada en `at`, girada `yaw` (y, si se quiere, ladeada `tilt`).
func box(color: Color, size: Vector3, at: Vector3, yaw: float = 0.0, tilt: float = 0.0) -> void:
	var basis: Basis = Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, tilt) * Basis.from_scale(size)
	_add(color, _box, Transform3D(basis, at + Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, tilt) * Vector3(0.0, size.y * 0.5, 0.0)))


## Tejado a dos aguas: `size.x` es el ancho (de alero a alero), `size.y` la altura y `size.z` el
## largo (la cumbrera va a lo largo de z antes de girar).
func roof(color: Color, size: Vector3, at: Vector3, yaw: float = 0.0) -> void:
	_add(color, _prism, Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(size), at + Vector3(0.0, size.y * 0.5, 0.0)))


## Cilindro (chimenea, depósito, torre redonda).
func tube(color: Color, radius: float, height: float, at: Vector3) -> void:
	_add(color, _cyl, Transform3D(Basis.from_scale(Vector3(radius * 2.0, height, radius * 2.0)), at + Vector3(0.0, height * 0.5, 0.0)))


## Aguja o tejado en punta, de 4 u 8 caras.
func spire(color: Color, radius: float, height: float, at: Vector3, sides: int = 4) -> void:
	var basis: Basis = Basis(Vector3.UP, PI * 0.25 if sides == 4 else 0.0) * Basis.from_scale(Vector3(radius * 2.0, height, radius * 2.0))
	_add(color, _spire4 if sides == 4 else _spire8, Transform3D(basis, at + Vector3(0.0, height * 0.5, 0.0)))


## Bola o cúpula centrada en `at` (con `size` distinto en cada eje, un elipsoide).
func ball(color: Color, size: Vector3, at: Vector3, yaw: float = 0.0) -> void:
	_add(color, _ball, Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(size), at))


## Casa: paredes y tejado a dos aguas (con `roof_color` transparente, azotea plana).
func house(wall: Color, roof_color: Color, size: Vector3, at: Vector3, yaw: float = 0.0) -> void:
	box(wall, size, at, yaw)
	if roof_color.a > 0.0:
		# La cumbrera, a lo largo del lado más largo.
		if size.z >= size.x:
			roof(roof_color, Vector3(size.x * 1.08, size.x * 0.45, size.z * 1.04), at + Vector3(0.0, size.y, 0.0), yaw)
		else:
			roof(roof_color, Vector3(size.z * 1.08, size.z * 0.45, size.x * 1.04), at + Vector3(0.0, size.y, 0.0), yaw + PI * 0.5)


## Funde las piezas y las cuelga de `parent`: una malla por color.
func commit(parent: Node3D) -> void:
	for key: String in _parts:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for part: Array in _parts[key][1]:
			st.append_from(part[0], 0, part[1])
		var instance := MeshInstance3D.new()
		instance.mesh = st.commit()
		instance.material_override = _material(_parts[key][0])
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(instance)
	_parts.clear()


static var _materials: Dictionary = {}


static func _material(color: Color) -> StandardMaterial3D:
	var key: String = color.to_html(false)
	if not _materials.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 1.0
		mat.metallic_specular = 0.1
		_materials[key] = mat
	return _materials[key]
