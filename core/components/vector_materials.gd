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
static func box_edges(size: Vector3, color: Color = GREEN) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/vector_edges.gdshader")
	mat.set_shader_parameter("half_size", size * 0.5)
	mat.set_shader_parameter("line_color", color)
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
static func make_box(size: Vector3, color: Color = GREEN) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = box_edges(size, color)
	return instance
