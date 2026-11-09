class_name VectorMaterials
## Fábrica de materiales del estilo vectorial. Todos son sin iluminación (baratos en móvil).

const GREEN := Color(0.2, 1.0, 0.33)
const ORANGE := Color(1.0, 0.5, 0.1)

static var _ground: ShaderMaterial
static var _flat: Dictionary = {}


static func ground() -> ShaderMaterial:
	if _ground == null:
		_ground = ShaderMaterial.new()
		_ground.shader = load("res://shaders/grid_ground.gdshader")
	return _ground


## Material de aristas para una caja de tamaño `size`. Cada tamaño necesita su instancia.
static func box_edges(size: Vector3, color: Color = GREEN, pattern: int = 0, pattern_scale: float = 2.0) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/vector_edges.gdshader")
	mat.set_shader_parameter("half_size", size * 0.5)
	mat.set_shader_parameter("line_color", color)
	mat.set_shader_parameter("fill_color", Color(color.r, color.g, color.b) * 0.04)
	mat.set_shader_parameter("pattern", pattern)
	mat.set_shader_parameter("pattern_scale", pattern_scale)
	return mat


static func flat(color: Color) -> ShaderMaterial:
	var key: String = color.to_html()
	if not _flat.has(key):
		var mat := ShaderMaterial.new()
		mat.shader = load("res://shaders/flat_color.gdshader")
		mat.set_shader_parameter("color", color)
		_flat[key] = mat
	return _flat[key]


## Crea una caja visible con aristas luminosas.
static func make_box(size: Vector3, color: Color = GREEN, pattern: int = 0, pattern_scale: float = 2.0) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = box_edges(size, color, pattern, pattern_scale)
	return instance


static var _edge_cache: Dictionary = {}


## Malla sólida oscura con sus aristas marcadas (cualquier forma: árboles, montañas, tejados).
static func make_outlined(mesh: Mesh, color: Color = GREEN, fill: Color = Color(0.0, 0.03, 0.01)) -> MeshInstance3D:
	var body := MeshInstance3D.new()
	body.mesh = mesh
	body.material_override = flat(fill)
	var lines := MeshInstance3D.new()
	lines.mesh = _feature_edges(mesh)
	lines.material_override = flat(color)
	lines.scale = Vector3.ONE * 1.01
	body.add_child(lines)
	return body


## Aristas "de silueta": las que separan caras con orientación distinta (> 20º).
static func _feature_edges(mesh: Mesh) -> ArrayMesh:
	if _edge_cache.has(mesh):
		return _edge_cache[mesh]
	var faces: PackedVector3Array = mesh.get_faces()
	var edges: Dictionary = {}
	for i in range(0, faces.size(), 3):
		var a: Vector3 = faces[i]
		var b: Vector3 = faces[i + 1]
		var c: Vector3 = faces[i + 2]
		var normal: Vector3 = (b - a).cross(c - a)
		if normal.length_squared() < 0.000001:
			continue
		normal = normal.normalized()
		for pair in [[a, b], [b, c], [c, a]]:
			var key: String = _edge_key(pair[0], pair[1])
			if not edges.has(key):
				edges[key] = [pair[0], pair[1], []]
			edges[key][2].append(normal)
	var points := PackedVector3Array()
	var threshold: float = cos(deg_to_rad(20.0))
	for key in edges:
		var entry: Array = edges[key]
		var normals: Array = entry[2]
		if normals.size() == 1 or (normals.size() >= 2 and normals[0].dot(normals[1]) < threshold):
			points.append(entry[0])
			points.append(entry[1])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	var result := ArrayMesh.new()
	if not points.is_empty():
		result.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	_edge_cache[mesh] = result
	return result


static func _edge_key(a: Vector3, b: Vector3) -> String:
	var ka: Vector3 = a.snapped(Vector3.ONE * 0.001)
	var kb: Vector3 = b.snapped(Vector3.ONE * 0.001)
	if str(ka) > str(kb):
		var tmp: Vector3 = ka
		ka = kb
		kb = tmp
	return str(ka) + str(kb)
