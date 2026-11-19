class_name Ribbon
extends RefCounted
## Cintas a ras de suelo que siguen una línea quebrada: el agua de un río, sus orillas, un
## camino, la calle de un pueblo, el balasto de una vía. Son solo dibujo (sin colisión): van
## unos centímetros por encima del llano, cada capa a su altura para que no parpadeen entre sí.

## Alturas de cada capa (m sobre el llano).
const Y_BANK: float = 0.05
const Y_ROAD: float = 0.07
const Y_WATER: float = 0.1
const Y_DECK: float = 0.16


## Suaviza una línea quebrada redondeando las esquinas (Chaikin), sin mover los extremos.
static func smooth(points: PackedVector2Array, rounds: int = 2) -> PackedVector2Array:
	var line: PackedVector2Array = points
	for r in rounds:
		if line.size() < 3:
			break
		var next := PackedVector2Array([line[0]])
		for i in line.size() - 1:
			var a: Vector2 = line[i]
			var b: Vector2 = line[i + 1]
			if i > 0:
				next.append(a.lerp(b, 0.25))
			if i < line.size() - 2:
				next.append(a.lerp(b, 0.75))
		next.append(line[line.size() - 1])
		line = next
	return line


## Longitud acumulada hasta cada punto de la línea.
static func lengths(points: PackedVector2Array) -> PackedFloat32Array:
	var out := PackedFloat32Array([0.0])
	for i in range(1, points.size()):
		out.append(out[i - 1] + points[i - 1].distance_to(points[i]))
	return out


## Punto de la línea a `distance` metros de su comienzo.
static func point_at(points: PackedVector2Array, distance: float) -> Vector2:
	var run: float = 0.0
	for i in range(1, points.size()):
		var step: float = points[i - 1].distance_to(points[i])
		if run + step >= distance and step > 0.0:
			return points[i - 1].lerp(points[i], (distance - run) / step)
		run += step
	return points[points.size() - 1]


## Dirección de la línea (unitaria) a `distance` metros de su comienzo.
static func direction_at(points: PackedVector2Array, distance: float) -> Vector2:
	var run: float = 0.0
	for i in range(1, points.size()):
		var step: float = points[i - 1].distance_to(points[i])
		if run + step >= distance and step > 0.0:
			return (points[i] - points[i - 1]) / step
		run += step
	var last: int = points.size() - 1
	return (points[last] - points[last - 1]).normalized()


## Distancia de un punto a la línea.
static func distance_to(points: PackedVector2Array, point: Vector2) -> float:
	var best: float = INF
	for i in range(1, points.size()):
		best = minf(best, point.distance_to(Geometry2D.get_closest_point_to_segment(point, points[i - 1], points[i])))
	return best


## Malla de una cinta de `half_width` metros a cada lado de la línea, a la altura `y`.
static func mesh(points: PackedVector2Array, half_width: float, y: float) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var run: float = 0.0
	var count: int = points.size()
	for i in count:
		var before: Vector2 = points[maxi(i - 1, 0)]
		var after: Vector2 = points[mini(i + 1, count - 1)]
		var dir: Vector2 = (after - before).normalized()
		var side := Vector2(-dir.y, dir.x)
		if i > 0:
			run += points[i - 1].distance_to(points[i])
		for edge: float in [-1.0, 1.0]:
			var at: Vector2 = points[i] + side * edge * half_width
			tool.set_normal(Vector3.UP)
			tool.set_uv(Vector2(edge * 0.5 + 0.5, run))
			tool.add_vertex(Vector3(at.x, y, at.y))
	for i in count - 1:
		var a: int = i * 2
		# Caras hacia arriba.
		for index: int in [a, a + 2, a + 1, a + 1, a + 2, a + 3]:
			tool.add_index(index)
	return tool.commit()


## Cinta ya montada como nodo, con el material de `strip()` o el que se le pase.
static func node(points: PackedVector2Array, half_width: float, y: float, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh(points, half_width, y)
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.add_to_group(&"ground_strips")
	return instance


## Material de una cinta de suelo (ver ground_strip.gdshader para los patrones).
static func strip(base: Color, detail: Color, pattern: int, width: float, ragged: float = 0.6) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/ground_strip.gdshader")
	mat.set_shader_parameter("noise_tex", VectorMaterials.noise())
	mat.set_shader_parameter("base_color", base)
	mat.set_shader_parameter("detail_color", detail)
	mat.set_shader_parameter("pattern", pattern)
	mat.set_shader_parameter("width", width)
	mat.set_shader_parameter("ragged", ragged)
	return mat
