class_name Backdrop
extends Node3D
## El paisaje de fuera del campo de batalla, hasta el horizonte: lo que hace que Normandía,
## el desierto y la estepa no se parezcan. Todo es dibujo (sin colisión ni sombras) y se funde
## con la bruma de la distancia.
##
## - Normandía: colinas suaves cuarteadas en prados con setos, bosquetes, hileras de chopos y
##   pueblos con su aguja. En la costa, el Canal con la flota de invasión y los globos cautivos.
## - Norte de África: escarpes y mesetas de cima plana, dunas tendidas, y en la costa el
##   Mediterráneo. En Túnez, djebeles de roca pelada.
## - Kursk: nada de montes. La estepa llana hasta el horizonte, con sus hojas de cultivo, las
##   franjas de árboles cortavientos, aldeas con molino de viento y columnas de humo.
##
## Cada misión puede pedir su fondo (`backdrop` en Campaign): el mar a un lado, una silueta
## (Caen, la acería de Colombelles, Járkov, Tobruk...) a otro, más o menos humo.

## Hacia dónde cae cada lado del mapa. El jugador suele salir del sur y avanzar al norte.
const SIDES: Dictionary = {"n": Vector2(0.0, -1.0), "s": Vector2(0.0, 1.0), "e": Vector2(1.0, 0.0), "w": Vector2(-1.0, 0.0)}
## Medio lado del campo y hasta dónde llega el paisaje (m).
const FIELD: float = 200.0
const REACH: float = 2600.0
## A qué distancia del centro queda la orilla del mar.
## Hacia dónde se lleva el viento el humo de los incendios lejanos.
const WIND := Vector2(0.94, 0.34)
const SHORE: float = 262.0

## Fondo de cada frente cuando la misión no pide otra cosa.
const DEFAULTS: Dictionary = {
	Fronts.Id.NORMANDY: {"relief": "bocage", "villages": 5, "smoke": 2},
	Fronts.Id.AFRICA: {"relief": "desert", "villages": 0, "smoke": 1},
	Fronts.Id.KURSK: {"relief": "plain", "villages": 6, "smoke": 4},
}

## Hacia dónde queda el mar en la partida en curso (cero si no hay): lo consultan los disparos
## que caen al agua y la misión de los barcos.
static var sea_side: Vector2 = Vector2.ZERO

var front: int = 0
var spec: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _sea_dir := Vector2.ZERO
var _busy: Array[Vector2] = []


## El fondo que toca: el del frente, con lo que pida la misión por encima.
## ¿Cae el punto en el mar?
static func in_sea(x: float, z: float) -> bool:
	return sea_side != Vector2.ZERO and Vector2(x, z).dot(sea_side) > SHORE + 1.0


## Punto del mar a `out` metros de la orilla y `along` metros a lo largo de ella (hacia el
## este si el mar queda al norte o al sur; hacia el sur si queda al este o al oeste).
static func sea_point(out: float, along: float) -> Vector2:
	var side := Vector2(absf(sea_side.y), absf(sea_side.x))
	return sea_side * (SHORE + out) + side * along


## Color de la arena de la playa en cada frente.
static func beach_sand(front_id: int) -> Color:
	return Color(0.7, 0.6, 0.43) if front_id == Fronts.Id.AFRICA else Color(0.66, 0.6, 0.46)


static func spec_for(front_id: int, mission: Dictionary) -> Dictionary:
	var result: Dictionary = (DEFAULTS.get(front_id, {}) as Dictionary).duplicate()
	result.merge(mission.get("backdrop", {}), true)
	return result


func build(front_id: int, backdrop_spec: Dictionary) -> void:
	front = front_id
	spec = backdrop_spec
	_rng.randomize()
	name = "Backdrop"
	var sea: String = spec.get("sea", "")
	if SIDES.has(sea):
		_sea_dir = SIDES[sea]
		_build_sea(spec.get("sea_extras", []))
	var skylines: Dictionary = spec.get("skyline", {})
	for side: String in skylines:
		_build_skyline(side, skylines[side])
	_build_relief(spec.get("relief", "bocage"))
	for i in int(spec.get("villages", 0)):
		_build_village()
	for i in int(spec.get("smoke", 0)):
		_build_smoke()


# ---------------------------------------------------------------- colocación

## ¿Cae el punto en el mar (o demasiado cerca de la orilla)?
func _in_sea(point: Vector2, margin: float = 60.0) -> bool:
	return _sea_dir != Vector2.ZERO and point.dot(_sea_dir) > SHORE - margin


## Un punto fuera del campo, entre `near` y `far` metros del muro, en tierra y apartado de lo
## ya colocado. Devuelve Vector2.INF si no lo encuentra.
func _spot(near: float, far: float, apart: float) -> Vector2:
	for attempt in 30:
		var angle: float = _rng.randf() * TAU
		var dir := Vector2(cos(angle), sin(angle))
		# El campo es cuadrado: la distancia al muro depende del rumbo.
		var wall: float = FIELD / maxf(absf(dir.x), absf(dir.y))
		var point: Vector2 = dir * (wall + _rng.randf_range(near, far))
		if _in_sea(point):
			continue
		var free: bool = true
		for other in _busy:
			if other.distance_to(point) < apart:
				free = false
				break
		if free:
			_busy.append(point)
			return point
	return Vector2.INF


## Nodo colocado en `point` y girado para que su +Z mire hacia fuera del campo.
func _anchor(point: Vector2, outward: Vector2) -> Node3D:
	var node := Node3D.new()
	node.position = Vector3(point.x, 0.0, point.y)
	node.rotation.y = atan2(outward.x, outward.y)
	add_child(node)
	return node


# ---------------------------------------------------------------- relieve

func _build_relief(kind: String) -> void:
	match kind:
		"plain", "forest":
			# Estepa: ondulaciones tan tendidas que apenas levantan, franjas de árboles y bosquetes.
			for i in 9:
				_ridge(_spot(260.0, 1500.0, 200.0), _rng.randf_range(600.0, 1100.0), _rng.randf_range(300.0, 480.0), _rng.randf_range(5.0, 13.0), 0, 0)
			for i in (26 if kind == "forest" else 16):
				_tree_belt(_spot(40.0, 900.0, 60.0), _rng.randf_range(90.0, 260.0), Color(0.13, 0.25, 0.1))
			if kind == "forest":
				# Bosque cerrado alrededor: una pared de árboles no muy lejos.
				for i in 12:
					_ridge(_spot(70.0, 420.0, 110.0), _rng.randf_range(260.0, 480.0), _rng.randf_range(90.0, 150.0), _rng.randf_range(15.0, 22.0), 2, 3)
		"desert", "flat":
			# Dunas tendidas por todas partes y, salvo en el desierto llano, escarpes y mesetas.
			for i in (5 if kind == "flat" else 12):
				_ridge(_spot(60.0, 1100.0, 120.0), _rng.randf_range(260.0, 620.0), _rng.randf_range(110.0, 200.0), _rng.randf_range(5.0, 9.0) if kind == "flat" else _rng.randf_range(8.0, 20.0), 0, 0)
			if kind == "desert":
				for i in 7:
					_ridge(_spot(240.0, 1100.0, 240.0), _rng.randf_range(520.0, 1100.0), _rng.randf_range(200.0, 320.0), _rng.randf_range(40.0, 80.0), 0, 1)
				# Algún cerro testigo, de roca, más cerca.
				for i in 3:
					_ridge(_spot(160.0, 600.0, 200.0), _rng.randf_range(120.0, 220.0), _rng.randf_range(100.0, 160.0), _rng.randf_range(28.0, 50.0), 1, 1)
		"djebel":
			# Túnez: sierras de roca pelada que cierran el llano, con sus estribaciones.
			for i in 9:
				_ridge(_spot(420.0, 1500.0, 240.0), _rng.randf_range(600.0, 1100.0), _rng.randf_range(320.0, 460.0), _rng.randf_range(110.0, 230.0), 1, 2)
			for i in 8:
				_ridge(_spot(120.0, 700.0, 150.0), _rng.randf_range(240.0, 460.0), _rng.randf_range(120.0, 200.0), _rng.randf_range(16.0, 40.0), 1, 2)
		_:
			# Normandía: colinas suaves cuarteadas en prados; más altas y boscosas con "hills".
			var high: bool = kind == "hills"
			for i in 14:
				_ridge(_spot(240.0, 1500.0, 190.0), _rng.randf_range(480.0, 900.0), _rng.randf_range(300.0, 460.0), _rng.randf_range(50.0, 95.0) if high else _rng.randf_range(18.0, 42.0), 0, 0)
			for i in (9 if high else 5):
				_ridge(_spot(120.0, 800.0, 140.0), _rng.randf_range(220.0, 420.0), _rng.randf_range(110.0, 170.0), _rng.randf_range(20.0, 34.0) if high else _rng.randf_range(12.0, 18.0), 2, 3)
			for i in 18:
				_tree_belt(_spot(30.0, 700.0, 50.0), _rng.randf_range(50.0, 150.0), Color(0.12, 0.26, 0.09), _rng.randf() < 0.3)


## Una elevación alargada en `point`, tendida de costado al campo. `kind` es el material (ver
## far_land: 0 parcelas y roca, 1 roca pelada, 2 bosque) y `shape` el perfil: 0 loma, 1 meseta
## de cima plana con el escarpe hacia el campo, 2 sierra dentada, 3 masa de bosque.
func _ridge(point: Vector2, length: float, width: float, height: float, kind: int, shape: int) -> void:
	if point == Vector2.INF:
		return
	var steps_u: int = 30
	var steps_v: int = 12
	var phase: Array[float] = [_rng.randf() * TAU, _rng.randf() * TAU, _rng.randf() * TAU, _rng.randf() * TAU]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in steps_u + 1:
		var u: float = float(i) / steps_u * 2.0 - 1.0
		for j in steps_v + 1:
			var v: float = float(j) / steps_v * 2.0 - 1.0
			var wobble: float = sin(u * 4.0 + phase[0]) * 0.5 + sin(u * 9.0 + phase[1]) * 0.3 + sin(u * 17.0 + phase[2]) * 0.2
			var along: float = pow(maxf(cos(u * PI * 0.5), 0.0), 0.8)
			var across: float = pow(maxf(cos(v * PI * 0.5), 0.0), 1.6)
			var h: float = along * across * (0.8 + wobble * 0.2)
			match shape:
				1:
					# Meseta: cima plana, talud abrupto hacia el campo (v < 0) y tendido por detrás.
					var front_face: float = smoothstep(-1.0, -0.72, v)
					var back_face: float = 1.0 - smoothstep(0.1, 1.0, v)
					var ends: float = smoothstep(1.0, 0.88, absf(u))
					h = front_face * back_face * ends * (0.9 + wobble * 0.1) * (0.85 + 0.15 * sin(u * 23.0 + phase[3]))
				2:
					# Sierra: picos y collados.
					var peaks: float = 0.55 + 0.45 * absf(sin(u * 5.5 + phase[0]) * 0.6 + sin(u * 11.0 + phase[1]) * 0.4)
					h = along * pow(maxf(1.0 - absf(v), 0.0), 1.25) * peaks
				3:
					# Bosque: un bloque de copas, de borde casi vertical.
					h = smoothstep(1.0, 0.86, absf(v)) * smoothstep(1.0, 0.94, absf(u)) * (0.82 + 0.18 * sin(u * 31.0 + v * 7.0 + phase[2]))
			var lateral: float = sin(u * 3.0 + phase[3]) * width * 0.08
			st.add_vertex(Vector3(u * length * 0.5, h * height - 0.6, v * width * 0.5 + lateral))
	for i in steps_u:
		for j in steps_v:
			var a: int = i * (steps_v + 1) + j
			var b: int = a + 1
			var c: int = a + steps_v + 1
			var d: int = c + 1
			# Caras hacia arriba.
			for index: int in [a, c, b, b, c, d]:
				st.add_index(index)
	st.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.mesh = st.commit()
	mesh.material_override = _land_material(kind, height)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# De costado al campo, con el lado v < 0 mirándolo.
	var outward: Vector2 = point.normalized()
	mesh.position = Vector3(point.x, 0.0, point.y)
	mesh.rotation.y = atan2(outward.x, outward.y) + _rng.randf_range(-0.3, 0.3)
	add_child(mesh)


var _land_materials: Dictionary = {}


func _land_material(kind: int, crest: float) -> ShaderMaterial:
	var key: String = "%d|%d" % [kind, roundi(crest / 20.0)]
	if _land_materials.has(key):
		return _land_materials[key]
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/far_land.gdshader")
	mat.set_shader_parameter("noise_tex", VectorMaterials.noise())
	mat.set_shader_parameter("kind", kind)
	mat.set_shader_parameter("crest", crest)
	mat.set_shader_parameter("rock_color", Fronts.rock_color(front))
	Fronts.apply_fields(mat, front)
	_land_materials[key] = mat
	return mat


## Franja de árboles (cortavientos de la estepa, seto alto o bosquete normando). Con `poplars`,
## una hilera de chopos.
func _tree_belt(point: Vector2, length: float, tone: Color, poplars: bool = false) -> void:
	if point == Vector2.INF:
		return
	var b := Blocks.new()
	if poplars:
		Skylines.poplars(b, _rng, Vector3(-length * 0.5, 0.0, 0.0), int(length / 7.0))
	else:
		var count: int = int(length / 6.5)
		for i in count:
			var size := Vector3(_rng.randf_range(9.0, 13.0), _rng.randf_range(9.0, 15.0), _rng.randf_range(9.0, 13.0))
			b.ball(tone.lightened(_rng.randf() * 0.1), size, Vector3(-length * 0.5 + i * 6.5, size.y * 0.5, _rng.randf_range(-3.0, 3.0)))
	var node := Node3D.new()
	node.position = Vector3(point.x, 0.0, point.y)
	node.rotation.y = _rng.randf() * TAU
	add_child(node)
	b.commit(node)


# ---------------------------------------------------------------- pueblos y siluetas

## Aldea suelta en el paisaje, con la iglesia (y el molino o las palmeras) de su frente.
func _build_village() -> void:
	var point: Vector2 = _spot(120.0, 620.0, 260.0)
	if point == Vector2.INF:
		return
	var b := Blocks.new()
	Skylines.village(b, _rng, [0, 1, 2][front], _rng.randf_range(110.0, 180.0), _rng.randi_range(9, 15))
	b.commit(_anchor(point, point.normalized()))


## Silueta con nombre (una ciudad, una fábrica, un puerto) en mitad de un lado del mapa.
func _build_skyline(side: String, skyline: String) -> void:
	if not SIDES.has(side):
		return
	var dir: Vector2 = SIDES[side]
	var far: float = {"caen": 620.0, "kharkov": 760.0, "orel": 680.0, "steelworks": 520.0, "stlo": 430.0, "tobruk": 300.0, "bunkers": 232.0, "fort": 420.0}.get(skyline, 380.0)
	var slide: float = _rng.randf_range(-90.0, 90.0)
	var point: Vector2 = dir * far + Vector2(-dir.y, dir.x) * slide
	_busy.append(point)
	# Que nada más se le ponga delante ni encima.
	for step in 5:
		_busy.append(dir * (far - 80.0 + step * 70.0) + Vector2(-dir.y, dir.x) * (slide + (step - 2) * 130.0))
	var b := Blocks.new()
	Skylines.build(skyline, b, _rng)
	b.commit(_anchor(point, dir))
	# Las ciudades del frente arden: columnas de humo sobre ellas.
	var fires: int = {"caen": 4, "stlo": 5, "kharkov": 5, "orel": 3, "steelworks": 2, "tobruk": 3}.get(skyline, 0)
	for i in fires:
		_smoke_at(point + Vector2(-dir.y, dir.x) * _rng.randf_range(-260.0, 260.0) + dir * _rng.randf_range(20.0, 120.0), _rng.randf_range(0.7, 1.2))


# ---------------------------------------------------------------- humo

func _build_smoke() -> void:
	var point: Vector2 = _spot(320.0, 1300.0, 160.0)
	if point != Vector2.INF:
		_smoke_at(point, _rng.randf_range(0.8, 1.6))


## Columna de humo de un incendio lejano.
func _smoke_at(point: Vector2, size: float) -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(260.0, 420.0) * size
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/far_smoke.gdshader")
	mat.set_shader_parameter("noise_tex", VectorMaterials.noise())
	mat.set_shader_parameter("seed", _rng.randf())
	# Todas las columnas se tuercen con el mismo viento (del oeste), se miren desde donde se miren.
	var yaw: float = atan2(point.x, point.y)
	var across: float = Vector2(cos(yaw), -sin(yaw)).dot(WIND)
	mat.set_shader_parameter("lean", _rng.randf_range(0.35, 0.6) * across)
	mat.set_shader_parameter("opacity", _rng.randf_range(0.55, 0.85))
	mat.render_priority = -2
	var panel := MeshInstance3D.new()
	panel.mesh = quad
	panel.material_override = mat
	panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	panel.position = Vector3(point.x, quad.size.y * 0.5 - 4.0, point.y)
	panel.rotation.y = yaw
	add_child(panel)


# ---------------------------------------------------------------- mar

## El mar a un lado del mapa: playa, agua hasta el horizonte y lo que flote en ella.
## `extras`: "fleet" (flota de invasión), "balloons" (globos cautivos), "mulberry" (puerto
## artificial), "harbor" (barcos en la rada, alguno hundido) y "landing" (lanchas en la playa).
func _build_sea(extras: Array) -> void:
	var dir: Vector2 = _sea_dir
	var side := Vector2(-dir.y, dir.x)
	var mediterranean: bool = front == Fronts.Id.AFRICA
	# Agua: un rectángulo de la orilla al horizonte. UV.y = 0 en la playa.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var corners: Array[Vector3] = [Vector3(-REACH, 0.0, 0.0), Vector3(REACH, 0.0, 0.0), Vector3(REACH, 0.0, REACH), Vector3(-REACH, 0.0, REACH)]
	var uvs: Array[Vector2] = [Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0)]
	for index: int in [0, 1, 2, 0, 2, 3]:
		st.set_normal(Vector3.UP)
		st.set_uv(uvs[index])
		st.add_vertex(corners[index])
	var water := ShaderMaterial.new()
	water.shader = load("res://shaders/sea.gdshader")
	water.set_shader_parameter("noise_tex", VectorMaterials.noise())
	water.set_shader_parameter("reach", REACH)
	if mediterranean:
		water.set_shader_parameter("deep_color", Color(0.04, 0.2, 0.42))
		water.set_shader_parameter("shore_color", Color(0.2, 0.62, 0.62))
	else:
		water.set_shader_parameter("deep_color", Color(0.12, 0.22, 0.27))
		water.set_shader_parameter("shore_color", Color(0.34, 0.42, 0.38))
	var sea := MeshInstance3D.new()
	sea.mesh = st.commit()
	sea.material_override = water
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var holder: Node3D = _anchor(dir * SHORE, dir)
	sea.position.y = 0.4
	holder.add_child(sea)
	# Playa: arena de la orilla hacia dentro.
	var sand: Color = beach_sand(front)
	var beach: MeshInstance3D = Ribbon.node(PackedVector2Array([dir * (SHORE - 22.0) - side * REACH, dir * (SHORE - 22.0) + side * REACH]), 30.0, 0.2, Ribbon.strip(sand, sand.darkened(0.3), 5, 60.0, 0.5))
	beach.remove_from_group(&"ground_strips")
	add_child(beach)
	var b := Blocks.new()
	if extras.has("fleet"):
		# Flota de invasión: transportes fondeados, destructores de escolta y algún acorazado.
		for i in 26:
			var kind: int = 0 if i % 3 != 2 else 1
			Skylines.ship(b, Vector3(_rng.randf_range(-1300.0, 1300.0), 0.0, _rng.randf_range(380.0, 1500.0)), _rng.randf_range(-0.4, 0.4), kind)
		for i in 3:
			Skylines.ship(b, Vector3(-900.0 + i * 800.0 + _rng.randf_range(-150.0, 150.0), 0.0, _rng.randf_range(1500.0, 2000.0)), _rng.randf_range(-0.3, 0.3), 2)
	if extras.has("landing"):
		for i in 12:
			Skylines.ship(b, Vector3(_rng.randf_range(-700.0, 700.0), 0.0, _rng.randf_range(4.0, 60.0)), PI * 0.5 + _rng.randf_range(-0.2, 0.2), 3)
	if extras.has("harbor"):
		for i in 5:
			Skylines.ship(b, Vector3(_rng.randf_range(-420.0, 420.0), 0.0, _rng.randf_range(260.0 if extras.has("quay") else 160.0, 620.0)), _rng.randf() * TAU, i % 2)
		# Cascos hundidos en la rada, escorados, con media obra muerta fuera del agua.
		Skylines.ship(b, Vector3(-150.0, -5.0, 290.0 if extras.has("quay") else 150.0), 0.5, 0, 5.0)
		Skylines.ship(b, Vector3(210.0, -3.0, 330.0 if extras.has("quay") else 240.0), -0.9, 1, -4.0)
		if extras.has("quay"):
			# Muelle a lo largo de la orilla (la rada queda libre para los barcos que zarpan).
			b.box(Skylines.CONCRETE, Vector3(300.0, 2.4, 14.0), Vector3(0.0, 0.0, 8.0))
			for i in 3:
				b.box(Skylines.SOOT.lightened(0.1), Vector3(2.0, 20.0, 2.0), Vector3(-110.0 + i * 110.0, 2.4, 6.0))
				b.box(Skylines.SOOT.lightened(0.1), Vector3(1.6, 1.6, 22.0), Vector3(-110.0 + i * 110.0, 21.0, 14.0))
		else:
			# Espigón y grúas del muelle.
			b.box(Skylines.CONCRETE, Vector3(16.0, 3.0, 200.0), Vector3(40.0, 0.0, 100.0))
			for i in 3:
				b.box(Skylines.SOOT.lightened(0.1), Vector3(2.0, 22.0, 2.0), Vector3(40.0, 3.0, 40.0 + i * 55.0))
				b.box(Skylines.SOOT.lightened(0.1), Vector3(24.0, 1.6, 1.6), Vector3(50.0, 24.0, 40.0 + i * 55.0), 0.0, 0.2)
	if extras.has("mulberry"):
		Skylines.mulberry(b, _rng, 0.0)
		for i in 9:
			Skylines.ship(b, Vector3(_rng.randf_range(-600.0, 600.0), 0.0, _rng.randf_range(250.0, 700.0)), _rng.randf_range(-0.3, 0.3), 0)
	if extras.has("balloons"):
		for i in 16:
			Skylines.balloon(b, Vector3(_rng.randf_range(-1000.0, 1000.0), _rng.randf_range(90.0, 190.0), _rng.randf_range(40.0, 700.0)), _rng.randf_range(-0.5, 0.5))
	b.commit(holder)
