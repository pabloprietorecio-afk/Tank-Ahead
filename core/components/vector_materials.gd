class_name VectorMaterials
## Fábrica de materiales. Todos comparten una textura de ruido pequeña con la que los shaders
## generan sus texturas en relieve (ladrillo, planchas, corteza, tierra...).

const GREEN := Color(0.2, 1.0, 0.33)
const ORANGE := Color(1.0, 0.5, 0.1)

static var _ground: ShaderMaterial
static var _flat: Dictionary = {}


static var _noise: ImageTexture


## Textura de ruido blanco de 64x64 (cuatro canales independientes) que usan todos los shaders.
static func noise() -> ImageTexture:
	if _noise == null:
		var rng := RandomNumberGenerator.new()
		rng.seed = 1944
		var data := PackedByteArray()
		data.resize(64 * 64 * 4)
		for i in data.size():
			data[i] = rng.randi() & 255
		_noise = ImageTexture.create_from_image(Image.create_from_data(64, 64, false, Image.FORMAT_RGBA8, data))
	return _noise


static var _clouds: NoiseTexture2D


## Capa de nubes para el cielo (se suma al color del cielo; negro = despejado).
static func clouds() -> NoiseTexture2D:
	if _clouds == null:
		var source := FastNoiseLite.new()
		source.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		source.seed = 1944
		source.frequency = 0.009
		source.fractal_octaves = 5
		source.fractal_gain = 0.55
		var ramp := Gradient.new()
		ramp.offsets = PackedFloat32Array([0.0, 0.48, 0.72, 1.0])
		ramp.colors = PackedColorArray([Color(0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0), Color(0.45, 0.45, 0.45), Color(1.0, 1.0, 1.0)])
		_clouds = NoiseTexture2D.new()
		_clouds.width = 512
		_clouds.height = 256
		_clouds.seamless = true
		_clouds.noise = source
		_clouds.color_ramp = ramp
	return _clouds


static func _shader_material(path: String) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load(path)
	mat.set_shader_parameter("noise_tex", noise())
	return mat


static func ground() -> ShaderMaterial:
	if _ground == null:
		_ground = _shader_material("res://shaders/grid_ground.gdshader")
	return _ground


## Material de un vehículo (ver armor.gdshader): una sola malla lleva pintura, acero, goma...
## `scheme` es la pintura {"base", "mode", "a", "b"}; `dust` el color del polvo del frente.
static func armor(scheme: Dictionary, detail_scale: float, dust: Color) -> ShaderMaterial:
	var mat := _shader_material("res://shaders/armor.gdshader")
	mat.set_shader_parameter("camo_mode", scheme.get("mode", 0))
	mat.set_shader_parameter("camo_a", scheme.get("a", Color.BLACK))
	mat.set_shader_parameter("camo_b", scheme.get("b", Color.BLACK))
	mat.set_shader_parameter("camo_scale", 1.4 * detail_scale)
	mat.set_shader_parameter("detail_scale", detail_scale)
	mat.set_shader_parameter("dust_color", dust)
	return mat


## Versión calcinada de un material de vehículo (restos de un tanque destruido).
static func burnt(original: Material) -> Material:
	if original is ShaderMaterial and (original as ShaderMaterial).shader == load("res://shaders/armor.gdshader"):
		var mat: ShaderMaterial = original.duplicate()
		mat.set_shader_parameter("burnt", 1.0)
		return mat
	return paint(Color(0.06, 0.05, 0.05))


## Material iluminado y texturizado para una caja de tamaño `size`.
static func box_edges(size: Vector3, color: Color = GREEN, pattern: int = 0, pattern_scale: float = 2.0) -> ShaderMaterial:
	var mat := _shader_material("res://shaders/surface_box.gdshader")
	mat.set_shader_parameter("half_size", size * 0.5)
	mat.set_shader_parameter("base_color", color)
	mat.set_shader_parameter("pattern", pattern)
	mat.set_shader_parameter("pattern_scale", pattern_scale)
	if pattern == 3 or pattern == 4:
		mat.set_shader_parameter("metallic_value", 0.35)
		mat.set_shader_parameter("roughness_value", 0.6)
	return mat


## Follaje o roca: malla deformada con ruido (y mecida por el viento si `sway` > 0).
static func organic(base: Color, detail: Color, pattern: int, scale: float, lumpiness: float, sway: float = 0.0) -> ShaderMaterial:
	var key: String = "o|%s|%s|%d|%.2f|%.2f|%.3f" % [base.to_html(), detail.to_html(), pattern, scale, lumpiness, sway]
	if not _textured.has(key):
		var mat := _shader_material("res://shaders/textured_fill.gdshader")
		mat.set_shader_parameter("base_color", base)
		mat.set_shader_parameter("detail_color", detail)
		mat.set_shader_parameter("pattern", pattern)
		mat.set_shader_parameter("scale", scale)
		mat.set_shader_parameter("lumpiness", lumpiness)
		mat.set_shader_parameter("sway", sway)
		_textured[key] = mat
	return _textured[key]


## Como `organic`, pero un material propio para cada cultivo: lleva su mapa de lo pisado
## (`CropTrample`), así que no se puede compartir entre campos.
static func crop(base: Color, detail: Color, pattern: int, scale: float, sway: float) -> ShaderMaterial:
	var mat := _shader_material("res://shaders/textured_fill.gdshader")
	mat.set_shader_parameter("base_color", base)
	mat.set_shader_parameter("detail_color", detail)
	mat.set_shader_parameter("pattern", pattern)
	mat.set_shader_parameter("scale", scale)
	mat.set_shader_parameter("lumpiness", 0.0)
	mat.set_shader_parameter("sway", sway)
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
static var _textured: Dictionary = {}


## Superficie iluminada y texturizada (ver textured_fill.gdshader para los patrones).
static func textured(base: Color, detail: Color, pattern: int, scale: float = 1.0) -> ShaderMaterial:
	var key: String = "%s|%s|%d|%.2f" % [base.to_html(), detail.to_html(), pattern, scale]
	if not _textured.has(key):
		var mat := _shader_material("res://shaders/textured_fill.gdshader")
		mat.set_shader_parameter("base_color", base)
		mat.set_shader_parameter("detail_color", detail)
		mat.set_shader_parameter("pattern", pattern)
		mat.set_shader_parameter("scale", scale)
		_textured[key] = mat
	return _textured[key]


## Malla iluminada con textura: `color` es el color base y `detail` el de las vetas/grietas.
static func make_outlined(mesh: Mesh, color: Color = GREEN, detail: Color = Color(0.1, 0.1, 0.1), pattern: int = 0, pattern_scale: float = 1.0) -> MeshInstance3D:
	var body := MeshInstance3D.new()
	body.mesh = mesh
	body.material_override = textured(color, detail, pattern, pattern_scale)
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


## Colores de los bordes que destacan cosas: enemigos en amarillo, objetivos en azul.
const ENEMY_OUTLINE := Color(1.0, 0.9, 0.1)
const OBJECTIVE_OUTLINE := Color(0.16, 0.6, 1.0)

static var _outlines: Dictionary = {}


## Material de borde (ver outline.gdshader) para poner como `material_overlay` de una malla.
## `width` es el grosor en metros y `min_pixels` el mínimo en pantalla cuando está lejos.
static func outline(color: Color, width: float = 0.03, min_pixels: float = 1.5) -> ShaderMaterial:
	var key: String = "%s|%.3f|%.2f" % [color.to_html(), width, min_pixels]
	if not _outlines.has(key):
		var mat := ShaderMaterial.new()
		mat.shader = load("res://shaders/outline.gdshader")
		mat.set_shader_parameter("color", color)
		mat.set_shader_parameter("width", width)
		mat.set_shader_parameter("min_pixels", min_pixels)
		_outlines[key] = mat
	return _outlines[key]


static var _contour: ShaderMaterial
static var _contact_shadow: ShaderMaterial


## Contorno oscuro de un píxel que recorta la silueta de un vehículo contra el terreno (ver
## contour.gdshader). Se pone como `material_overlay`, igual que el borde de ayuda.
static func contour() -> ShaderMaterial:
	if _contour == null:
		_contour = ShaderMaterial.new()
		_contour.shader = load("res://shaders/contour.gdshader")
	return _contour


## Material de la sombra de contacto de los vehículos (ver contact_shadow.gdshader).
static func contact_shadow() -> ShaderMaterial:
	if _contact_shadow == null:
		_contact_shadow = ShaderMaterial.new()
		_contact_shadow.shader = load("res://shaders/contact_shadow.gdshader")
		# Sobre el suelo y sus marcas; por debajo del humo y el polvo.
		_contact_shadow.render_priority = -4
	return _contact_shadow


## Pone (o quita, con `color` transparente) el borde a todas las mallas que cuelgan de `root`.
static func set_outline(root: Node, color: Color, width: float = 0.05, min_pixels: float = 1.8) -> void:
	var overlay: Material = outline(color, width, min_pixels) if color.a > 0.0 else null
	for node in root.find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).material_overlay = overlay
	if root is MeshInstance3D:
		(root as MeshInstance3D).material_overlay = overlay


static var _paint: Dictionary = {}


## Pintura lisa iluminada, visible por ambas caras (distintivos, calcomanías).
static func paint(color: Color) -> StandardMaterial3D:
	var key: String = color.to_html()
	if not _paint.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 0.8
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_paint[key] = mat
	return _paint[key]
