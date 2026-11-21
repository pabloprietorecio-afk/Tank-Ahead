class_name CropTrample
extends Node
## Hace que un cultivo (trigal, girasoles) se aplaste al paso de los tanques y se quede aplastado.
##
## Lleva un mapa de lo pisado (una imagen de un byte por cada medio metro del campo). Cada décima
## de segundo estampa en él la huella de los tanques que hay dentro; el material del cultivo
## (`textured_fill.gdshader`) lee el mapa, baja las hileras donde está pisado y les cambia el color.
## El cambio se hace debajo del casco, así que no se ve el momento en que se tumban.

## Lado de cada celda del mapa (m).
const CELL: float = 0.5
## Cada cuánto se mira dónde están los tanques (s).
const STEP: float = 0.1
## Lo que tiene que moverse un tanque para volver a estampar su huella (m).
const MOVED: float = 0.3

## Tamaño del campo (m), centrado en el nodo padre.
var size: Vector2

var _field: Node3D
var _cells: Vector2i
var _data: PackedByteArray
var _image: Image
var _texture: ImageTexture
var _due: float = 0.0
## Última posición estampada de cada tanque (por id de instancia), en el plano del campo.
var _last: Dictionary = {}


## Cuelga del campo `field` (de tamaño `field_size`, centrado en él, con `rows` hileras a lo largo
## de Z de `row_width` m de ancho) y conecta sus materiales: cada elemento de `looks` es
## [material, altura a la que queda aplastado (fracción), color].
static func attach(field: Node3D, field_size: Vector2, rows: int, row_width: float, looks: Array) -> CropTrample:
	var trample := CropTrample.new()
	trample.name = "Pisadas"
	trample.size = field_size
	trample._field = field
	trample._cells = Vector2i(maxi(ceili(field_size.x / CELL), 1), maxi(ceili(field_size.y / CELL), 1))
	trample._data.resize(trample._cells.x * trample._cells.y)
	trample._image = Image.create_from_data(trample._cells.x, trample._cells.y, false, Image.FORMAT_R8, trample._data)
	trample._texture = ImageTexture.create_from_image(trample._image)
	for look: Array in looks:
		var material: ShaderMaterial = look[0]
		material.set_shader_parameter("trample", trample._texture)
		material.set_shader_parameter("trample_size", field_size)
		material.set_shader_parameter("trample_height", look[1])
		material.set_shader_parameter("trample_color", look[2])
		material.set_shader_parameter("trample_rows", float(rows))
		material.set_shader_parameter("trample_spread", field_size.y / rows / row_width * 1.03)
	field.add_child(trample)
	return trample


func _physics_process(delta: float) -> void:
	_due -= delta
	if _due > 0.0:
		return
	_due = STEP
	var changed: bool = false
	for node: Node in get_tree().get_nodes_in_group(&"tanks"):
		var tank := node as Tank
		if tank == null:
			continue
		var local: Vector3 = _field.to_local(tank.global_position)
		var reach: float = tank.footprint.length() * 0.5
		if absf(local.x) > size.x * 0.5 + reach or absf(local.z) > size.y * 0.5 + reach or absf(local.y) > 3.0:
			continue
		var at := Vector2(local.x, local.z)
		var id: int = tank.get_instance_id()
		if _last.has(id) and (_last[id] as Vector2).distance_to(at) < MOVED:
			continue
		_last[id] = at
		var ahead: Vector3 = _field.global_basis.inverse() * -tank.global_basis.z
		changed = stamp(at, Vector2(ahead.x, ahead.z), tank.footprint * 0.5) or changed
	if changed:
		_image.set_data(_cells.x, _cells.y, false, Image.FORMAT_R8, _data)
		_texture.update(_image)


## Aplasta el rectángulo centrado en `center` (plano del campo, m), orientado según `forward`, de
## medio ancho `half.x` y medio largo `half.y`. Devuelve si ha cambiado algo.
func stamp(center: Vector2, forward: Vector2, half: Vector2) -> bool:
	forward = forward.normalized() if forward.length_squared() > 0.0001 else Vector2(0.0, -1.0)
	var side := Vector2(-forward.y, forward.x)
	var reach: float = half.length()
	var from := Vector2i(((center - Vector2(reach, reach) + size * 0.5) / CELL).floor()).clamp(Vector2i.ZERO, _cells - Vector2i.ONE)
	var to := Vector2i(((center + Vector2(reach, reach) + size * 0.5) / CELL).floor()).clamp(Vector2i.ZERO, _cells - Vector2i.ONE)
	if center.x + reach < -size.x * 0.5 or center.x - reach > size.x * 0.5 or center.y + reach < -size.y * 0.5 or center.y - reach > size.y * 0.5:
		return false
	var changed: bool = false
	for y in range(from.y, to.y + 1):
		for x in range(from.x, to.x + 1):
			var index: int = y * _cells.x + x
			if _data[index] == 255:
				continue
			var offset: Vector2 = (Vector2(x, y) + Vector2(0.5, 0.5)) * CELL - size * 0.5 - center
			if absf(offset.dot(side)) <= half.x and absf(offset.dot(forward)) <= half.y:
				_data[index] = 255
				changed = true
	return changed


## Cuánto está aplastado el punto `at` del campo (plano del campo, m): 0 en pie, 1 tumbado.
func crushed_at(at: Vector2) -> float:
	var cell := Vector2i(((at + size * 0.5) / CELL).floor())
	if cell.x < 0 or cell.y < 0 or cell.x >= _cells.x or cell.y >= _cells.y:
		return 0.0
	return _data[cell.y * _cells.x + cell.x] / 255.0


## Parte del campo aplastada (0..1).
func crushed_share() -> float:
	return _data.count(255) / float(maxi(_data.size(), 1))
