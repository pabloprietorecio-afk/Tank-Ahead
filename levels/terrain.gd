class_name Terrain
extends RefCounted
## Relieve suave del campo: lomas (dunas en el desierto) de pendiente baja por las que los tanques
## suben y bajan. Las colinas y montañas de PropFactory son otra cosa: empinadas, hacen de pared.
##
## Cada loma es una función de altura conocida, así que no hace falta preguntar a la física: los
## tanques se apoyan en `height()` y se inclinan con el terreno (ver TankMovement y Tank), y lo
## que se pone en el suelo sabe a qué altura queda. La máquina las trata como suelo llano: no
## cuentan como obstáculo ni para las rutas ni para los rayos con los que esquiva.
## Para los disparos y la línea de visión cada loma lleva un cuerpo en la capa LAYER, con la que
## los tanques no chocan.

## Capa de colisión del relieve: la miran los proyectiles, la línea de visión y la mira.
const LAYER: int = 16
## Lo que se hunde el borde de la malla bajo el llano, para que no parpadee con él.
const SINK: float = 0.05
## Altura de una loma respecto a su radio: con esto la pendiente máxima ronda los 12 grados.
const HEIGHT_RATIO: float = 0.105

static var _mounds: Array[Mound] = []


## Una loma: bulto redondeado de contorno algo irregular, llano en la cima y en el borde.
class Mound:
	var x: float
	var z: float
	var radius: float
	var height: float
	## Radio más allá del cual seguro que no hay loma.
	var reach: float
	## Alargamiento: 1 es redonda; más, una loma tendida (duna, cresta) de eje `yaw`.
	var stretch: float = 1.0
	var yaw: float = 0.0
	var _phase_a: float
	var _phase_b: float
	var _cos: float = 1.0
	var _sin: float = 0.0

	func _init(center: Vector2, mound_radius: float, mound_height: float, seed_value: float, mound_stretch: float = 1.0, mound_yaw: float = 0.0) -> void:
		x = center.x
		z = center.y
		radius = mound_radius
		height = mound_height
		stretch = maxf(mound_stretch, 1.0)
		yaw = mound_yaw
		_cos = cos(yaw)
		_sin = sin(yaw)
		reach = mound_radius * 1.17 * stretch
		_phase_a = seed_value * TAU
		_phase_b = seed_value * 17.3

	## Radio del borde en la dirección `angle`: algo ovalada y con un entrante suave.
	func rim(angle: float) -> float:
		return radius * (1.0 + 0.12 * sin(angle * 2.0 + _phase_a) + 0.05 * sin(angle * 3.0 + _phase_b))

	## Altura de la superficie a `s` radios del centro (0 = cima, 1 = borde), sin recortar: en el
	## borde queda SINK por debajo del llano.
	func profile(s: float) -> float:
		var k: float = 1.0 - s * s
		return height * k * k - Terrain.SINK

	## Altura sobre el llano en un punto dado por su desplazamiento desde el centro.
	func at(dx: float, dz: float) -> float:
		if stretch > 1.0:
			# A sus propios ejes, y encogida a lo largo: el resto es una loma redonda.
			var along: float = (dx * _cos + dz * _sin) / stretch
			dz = -dx * _sin + dz * _cos
			dx = along
		var d2: float = dx * dx + dz * dz
		if d2 >= radius * radius * 1.37:
			return 0.0
		var edge: float = rim(atan2(dz, dx))
		var s2: float = d2 / (edge * edge)
		if s2 >= 1.0:
			return 0.0
		var k: float = 1.0 - s2
		return maxf(height * k * k - Terrain.SINK, 0.0)


## Olvida el relieve (al montar un campo nuevo: los datos son estáticos y sobreviven a la escena).
static func clear() -> void:
	_mounds.clear()


static func is_flat() -> bool:
	return _mounds.is_empty()


static func mounds() -> Array[Mound]:
	return _mounds


## Altura del terreno (m sobre el llano) en un punto del mapa.
static func height(x: float, z: float) -> float:
	var top: float = 0.0
	for mound in _mounds:
		var dx: float = x - mound.x
		var dz: float = z - mound.z
		if absf(dx) < mound.reach and absf(dz) < mound.reach:
			top = maxf(top, mound.at(dx, dz))
	return top


## El punto `point` puesto a ras de suelo.
static func on_ground(point: Vector3, lift: float = 0.0) -> Vector3:
	return Vector3(point.x, height(point.x, point.z) + lift, point.z)


## Normal del terreno en un punto (hacia arriba en el llano).
static func normal(x: float, z: float) -> Vector3:
	if _mounds.is_empty():
		return Vector3.UP
	var e: float = 0.6
	var slope_x: float = (height(x + e, z) - height(x - e, z)) / (2.0 * e)
	var slope_z: float = (height(x, z + e) - height(x, z - e)) / (2.0 * e)
	return Vector3(-slope_x, 1.0, -slope_z).normalized()


## Orientación de algo posado en el suelo en `point` y mirando con rumbo `yaw`: la base de sus
## ejes inclinada con el terreno. `half_length` y `half_width` son las medias medidas del apoyo.
## Devuelve también la altura a la que queda su centro.
static func rest(point: Vector3, yaw: float, half_length: float, half_width: float) -> Transform3D:
	var forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	var front: Vector3 = point + forward * half_length
	var back: Vector3 = point - forward * half_length
	var side_r: Vector3 = point + right * half_width
	var side_l: Vector3 = point - right * half_width
	var h_front: float = height(front.x, front.z)
	var h_back: float = height(back.x, back.z)
	var h_right: float = height(side_r.x, side_r.z)
	var h_left: float = height(side_l.x, side_l.z)
	var axis_z: Vector3 = Vector3(-forward.x * half_length * 2.0, h_back - h_front, -forward.z * half_length * 2.0).normalized()
	var axis_x: Vector3 = Vector3(right.x * half_width * 2.0, h_right - h_left, right.z * half_width * 2.0).normalized()
	var axis_y: Vector3 = axis_z.cross(axis_x).normalized()
	axis_x = axis_y.cross(axis_z).normalized()
	# En una cresta se apoya en el centro; en una vaguada, en los extremos.
	var ground: float = maxf(height(point.x, point.z), (h_front + h_back + h_right + h_left) * 0.25)
	return Transform3D(Basis(axis_x, axis_y, axis_z), Vector3(point.x, ground, point.z))


## Crea una loma en `center` y devuelve el nodo que hay que añadir al campo: la malla (con el
## mismo material que el suelo, para que sea una ondulación del propio terreno) y el cuerpo con
## el que chocan los disparos. `material` es el del suelo.
## Con `stretch` > 1 es una loma alargada (duna, cresta): `radius` es su medio ancho, mide
## `stretch` veces más de largo y su eje sigue el rumbo `yaw`.
static func add_mound(center: Vector2, radius: float, material: Material, seed_value: float, height_ratio: float = HEIGHT_RATIO, stretch: float = 1.0, yaw: float = 0.0) -> Node3D:
	var mound := Mound.new(center, radius, radius * height_ratio, seed_value, stretch, yaw)
	_mounds.append(mound)
	var rings: int = 12
	var segments: int = 36
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in rings + 1:
		var s: float = float(i) / rings
		for j in segments:
			var angle: float = TAU * j / segments
			var reach_here: float = mound.rim(angle) * s
			tool.add_vertex(Vector3(cos(angle) * reach_here * mound.stretch, mound.profile(s), sin(angle) * reach_here))
	for i in rings:
		for j in segments:
			var a: int = i * segments + j
			var b: int = i * segments + (j + 1) % segments
			var c: int = (i + 1) * segments + (j + 1) % segments
			var d: int = (i + 1) * segments + j
			# Caras hacia arriba (sentido de las agujas visto desde encima).
			for index: int in [a, c, b, a, d, c]:
				tool.add_index(index)
	tool.generate_normals()
	var mesh: ArrayMesh = tool.commit()
	var body := StaticBody3D.new()
	body.name = "Loma"
	body.position = Vector3(center.x, 0.0, center.y)
	body.rotation.y = -mound.yaw
	body.collision_layer = LAYER
	body.collision_mask = 0
	body.add_to_group(&"terrain")
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = material
	# No da sombra: es más tendida que el sol más bajo (28°), así que nunca proyecta ninguna de
	# verdad, y fuera del mapa de sombras tampoco puede oscurecerse a sí misma por falta de
	# precisión cuando el sol le da rasante por la cara opuesta.
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(visual)
	var shape := CollisionShape3D.new()
	shape.shape = mesh.create_trimesh_shape()
	body.add_child(shape)
	return body
