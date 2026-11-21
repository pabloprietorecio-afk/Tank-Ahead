extends Node3D
## Campo de batalla: monta el escenario del frente elegido, el modo de juego, el jugador,
## el clima y la interfaz.

const ARENA_HALF: float = 200.0
const SAFE_RADIUS: float = 20.0

var _player: Tank
var _hud: Hud
var _mode: GameMode
var _env: Environment
var _sky_material: ProceduralSkyMaterial
var _sun: DirectionalLight3D
var _obstacle_rects: Array[Rect2] = []
## Sitios en los que no se coloca decorado pero sí se puede estar: caminos, calles, arroyos.
var _keep_clear: Array[Rect2] = []
## Hacia dónde queda el mar (cero si la misión no tiene) y a qué distancia del centro empieza
## la arena de la playa dentro del campo.
const BEACH_FROM: float = 128.0
var _beach_dir: Vector2 = Vector2.ZERO
## Rasgos del trazado de esta partida (ver Layouts).
var _layout: Dictionary = {}
## Montañas de fuera del muro: [nodo, radio de la falda].
var _far_mountains: Array = []
var _rng := RandomNumberGenerator.new()
var _spawn_point: Vector2


func _ready() -> void:
	_rng.randomize()
	Engine.time_scale = 1.0
	Terrain.clear()
	Water.clear()
	GameSettings.ensure_loaded()
	AudioSetup.ensure()
	GameSession.resolve_front()
	_mode = _create_mode()
	_mode.name = "GameMode"
	var spawn: Transform3D = _mode.player_spawn()
	_spawn_point = Vector2(spawn.origin.x, spawn.origin.z)
	_obstacle_rects.append_array(_mode.reserved_zones())
	var layout_name: String = _mode.map_layout()
	if layout_name == "*":
		layout_name = Layouts.random_open(GameSession.front) if GameSession.debug_layout == "" else GameSession.debug_layout
	_layout = Layouts.get_layout(GameSession.front, layout_name)
	_build_environment()
	await Loading.step(0.05, "entorno")
	var far_spec: Dictionary = Backdrop.spec_for(GameSession.front, _mode.backdrop())
	if Backdrop.SIDES.has(far_spec.get("sea", "")) and not GameSession.debug_bare:
		# Junto al mar, la última franja del campo es la playa: arena despejada.
		_beach_dir = Backdrop.SIDES[far_spec["sea"]]
		var inland: Vector2 = _beach_dir * (BEACH_FROM + 4.0)
		var along := Vector2(absf(_beach_dir.y), absf(_beach_dir.x)) * ARENA_HALF
		var far_corner: Vector2 = _beach_dir * ARENA_HALF + along
		var near_corner: Vector2 = inland - along
		_keep_clear.append(Rect2(Vector2(minf(near_corner.x, far_corner.x), minf(near_corner.y, far_corner.y)), (far_corner - near_corner).abs()))
	Backdrop.sea_side = _beach_dir
	_build_ground()
	await Loading.breathe()
	_build_walls(far_spec.get("sea", ""))
	await Loading.step(0.14, "suelo y borde")
	if not GameSession.debug_bare:
		# El paisaje de fuera del campo, hasta el horizonte.
		var backdrop := Backdrop.new()
		add_child(backdrop)
		await backdrop.build(GameSession.front, far_spec)
	await Loading.step(0.32, "horizonte")
	if _mode.wants_scenery() and not GameSession.debug_bare:
		await _build_scenery()
	await Loading.step(0.7, "decorado")
	_spawn_player(spawn)
	await Loading.breathe()
	Fx.on(self).player = _player
	_mode.is_free_point = func(p: Vector2) -> bool:
		for rect in _obstacle_rects:
			if rect.has_point(p):
				return false
		return true
	add_child(_mode)
	await Loading.breathe()
	_build_weather()
	await Loading.step(0.76, "jugador y clima")
	if _mode.wants_scenery() and not GameSession.debug_bare:
		# Aviones de paso, antiaérea y algún derribo lejano: solo ambiente.
		var sky := SkyWar.new()
		sky.name = "SkyWar"
		sky.front = GameSession.front
		sky.is_free_point = _mode.is_free_point
		add_child(sky)
	await Loading.breathe()
	if _mode.wants_pickups():
		var spawner := PickupSpawner.new()
		spawner.name = "PickupSpawner"
		spawner.player = _player
		spawner.is_free_point = _mode.is_free_point
		add_child(spawner)
	if _mode.wants_scenery() and not GameSession.debug_bare:
		# Fondo sonoro del frente (pájaros, viento, grillos) y, si hay mar, oleaje y gaviotas.
		var ambience := Ambience.new()
		ambience.name = "Ambience"
		ambience.player = _player
		ambience.front = GameSession.front
		ambience.weather = (get_node("Weather") as Weather).kind
		ambience.sea_side = _beach_dir
		add_child(ambience)
	await Loading.breathe()
	if not GameSession.debug_bare:
		# Las huellas de las orugas; junto al mar el suelo es arena de playa y se marcan más.
		var marks := TrackMarks.new()
		marks.name = "TrackMarks"
		add_child(marks)
		marks.build(GameSession.front, _beach_dir, BEACH_FROM)
	await Loading.breathe()
	_build_ui()
	await Loading.step(0.84, "interfaz")
	var voice := VoiceManager.new()
	voice.name = "VoiceManager"
	voice.player = _player
	add_child(voice)
	var music := AudioSetup.music_player("res://assets/music/battle_theme.ogg")
	music.volume_db = -6.0
	add_child(music)
	await Loading.step(0.88, "voz y música")
	await _mode.start(_player, self)
	var with_intro: bool = GameSession.mode == GameSession.Mode.STORY and not GameSession.skip_intro and not GameSession.debug_bare
	if Loading.current != null:
		# Con pantalla de carga: se retira cuando el campo ya está pintado debajo; la partida
		# (en pausa mientras se montaba) arranca entonces, o lo hace la entrada aérea.
		await Loading.close()
		if not with_intro:
			get_tree().paused = false
	if with_intro:
		# Entrada de la misión: barrido aéreo y picado hasta el tanque.
		var intro := IntroFlight.new()
		intro.name = "IntroFlight"
		intro.player = _player
		intro.ui_layer = _hud.get_parent() as CanvasLayer
		intro.title = Loc.t(GameSession.current_mission()["title"])
		intro.subtitle = "%s · %s" % [Loc.t(Fronts.NAMES[GameSession.front]), (get_node("Weather") as Weather).display_name()]
		add_child(intro)


func _create_mode() -> GameMode:
	match GameSession.mode:
		GameSession.Mode.CTF:
			return CtfMode.new()
		GameSession.Mode.STORY:
			return StoryMode.new()
		GameSession.Mode.TUTORIAL:
			return TutorialMode.new()
		_:
			return SurvivalMode.new()


func _build_environment() -> void:
	_sky_material = ProceduralSkyMaterial.new()
	var sky := Sky.new()
	sky.sky_material = _sky_material
	_env = Environment.new()
	_env.background_mode = Environment.BG_SKY
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_env.ambient_light_energy = 0.6
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.fog_enabled = true
	_env.fog_sky_affect = 0.6
	_env.glow_enabled = true
	_env.glow_intensity = 0.6
	_env.glow_bloom = 0.05
	_env.fog_aerial_perspective = 0.35
	_env.adjustment_enabled = true
	_env.adjustment_contrast = 1.06
	_env.adjustment_saturation = 1.08
	var world_env := WorldEnvironment.new()
	world_env.environment = _env
	add_child(world_env)

	_sun = DirectionalLight3D.new()
	_sun.name = "Sun"
	_sun.rotation = Vector3(deg_to_rad(-28.0), deg_to_rad(-35.0), 0.0)
	_sun.shadow_enabled = GameSettings.shadows
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	_sun.directional_shadow_max_distance = 130.0
	_sun.directional_shadow_blend_splits = true
	_sun.shadow_blur = 1.2
	_sun.light_angular_distance = 0.8
	add_child(_sun)


func _build_ground() -> void:
	var material: ShaderMaterial = VectorMaterials.ground()
	var colors: Array[Color] = Fronts.ground_colors(GameSession.front)
	material.set_shader_parameter("grass", colors[0])
	material.set_shader_parameter("dry_grass", colors[1])
	material.set_shader_parameter("dirt", colors[2])
	material.set_shader_parameter("gravel", colors[3])
	material.set_shader_parameter("arena_half", ARENA_HALF)
	material.set_shader_parameter("beach_dir", _beach_dir)
	material.set_shader_parameter("beach_from", BEACH_FROM)
	material.set_shader_parameter("beach_color", Backdrop.beach_sand(GameSession.front))
	Fronts.apply_fields(material, GameSession.front)
	# El suelo sigue hasta el horizonte: fuera del campo son las parcelas lejanas del frente.
	var mesh := PlaneMesh.new()
	mesh.size = Vector2.ONE * Backdrop.REACH * 2.4
	var ground := MeshInstance3D.new()
	ground.mesh = mesh
	ground.material_override = material
	add_child(ground)

	# El suelo es un bloque muy grueso: si algo empuja a un tanque hacia abajo, la física lo
	# devuelve arriba en vez de dejarlo atravesar una losa fina y caer al vacío.
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	# Bastante más ancho que el campo: los disparos que salen de él también dan en tierra.
	box.size = Vector3(ARENA_HALF * 2.0 + 1000.0, 100.0, ARENA_HALF * 2.0 + 1000.0)
	shape.shape = box
	shape.position.y = -50.0
	body.add_child(shape)
	add_child(body)


## Límite infranqueable para los tanques: una barrera alta e invisible en cada borde, en una
## capa que solo ellos tocan (los disparos y los aviones la atraviesan).
func _add_boundary(center: Vector3, size: Vector3, layer: int = Tank.LAYER_BOUNDARY) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	body.position = center
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	add_child(body)


## El borde del campo, distinto en cada frente: en Normandía, el seto alto sobre talud que
## cerraba cada prado del bocage; en la estepa, alambradas con los carteles de los campos de
## minas, que dejan ver el paisaje (también hacia el mar, `sea_side`, en Normandía). En el
## desierto no hay nada: la arena sigue hasta las dunas (`Backdrop.open_border`).
func _build_walls(sea_side: String = "") -> void:
	var length: float = ARENA_HALF * 2.0
	for side in [-1.0, 1.0]:
		_add_boundary(Vector3(0.0, 40.0, side * (ARENA_HALF + 2.0)), Vector3(length + 20.0, 80.0, 6.0))
		_add_boundary(Vector3(side * (ARENA_HALF + 2.0), 40.0, 0.0), Vector3(6.0, 80.0, length + 20.0))
	var hedges: bool = GameSession.front == Fronts.Id.NORMANDY
	for key: String in Backdrop.SIDES:
		var dir: Vector2 = Backdrop.SIDES[key]
		var edge := Node3D.new()
		edge.name = "Borde" + key.to_upper()
		edge.position = Vector3(dir.x, 0.0, dir.y) * ARENA_HALF
		# El eje X del borde corre a lo largo del lado.
		edge.rotation.y = 0.0 if dir.x == 0.0 else PI * 0.5
		add_child(edge)
		var along: Vector3 = Vector3(length, 0.0, 2.0) if dir.x == 0.0 else Vector3(2.0, 0.0, length)
		if hedges and key != sea_side:
			edge.add_child(_hedge_edge(length))
			# El seto para los disparos, como un muro.
			var body := StaticBody3D.new()
			body.collision_layer = 1
			body.position = edge.position + Vector3(0.0, 1.6, 0.0)
			var shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = along + Vector3(0.0, 3.2, 0.0)
			shape.shape = box
			body.add_child(shape)
			add_child(body)
		else:
			if not Backdrop.open_border(GameSession.front):
				_wire_edge(edge, length)
			# La alambrada no para los disparos, pero la máquina tiene que verla (también donde
			# no se pinta) para no empeñarse en cruzar el límite: va en la capa de las barreras
			# que solo tocan los tanques.
			_add_boundary(edge.position + Vector3(0.0, 2.0, 0.0), along + Vector3(0.0, 4.0, 0.0), Tank.LAYER_WATER)


## Seto del bocage a lo largo de un borde: talud de tierra y, encima, la maraña de espino y
## avellano, con algún árbol que sobresale.
func _hedge_edge(length: float) -> Node3D:
	var root := Node3D.new()
	var bank := VectorMaterials.make_box(Vector3(length, 1.3, 3.0), Color(0.3, 0.24, 0.15), 0, 1.0)
	bank.position.y = 0.65
	root.add_child(bank)
	root.add_child(PropFactory.hedge_foliage(length, 1.25))
	var x: float = -length * 0.5 + _rng.randf_range(8.0, 30.0)
	while x < length * 0.5 - 8.0:
		var tree: Node3D = PropFactory.apple_tree(_rng.randf_range(7.0, 10.0))
		tree.position = Vector3(x, 0.8, _rng.randf_range(-0.4, 0.4))
		tree.rotation.y = _rng.randf() * TAU
		root.add_child(tree)
		x += _rng.randf_range(16.0, 44.0)
	return root


## Alambrada a lo largo de un borde: piquetes, tres hilos de espino y, cada tanto, el cartel
## de un campo de minas.
func _wire_edge(edge: Node3D, length: float) -> void:
	var b := Blocks.new()
	var wood := Color(0.34, 0.27, 0.18)
	var steel := Color(0.2, 0.19, 0.18)
	var posts: int = int(length / 6.0)
	for i in posts + 1:
		var x: float = -length * 0.5 + i * length / posts
		b.box(wood.lightened(_rng.randf() * 0.12), Vector3(0.16, 1.5 + _rng.randf() * 0.15, 0.16), Vector3(x, 0.0, 0.0), 0.0, _rng.randf_range(-0.08, 0.08))
		# Un segundo piquete, más bajo, por fuera: la alambrada es doble y en pendiente.
		b.box(wood, Vector3(0.14, 0.8, 0.14), Vector3(x + 3.0, 0.0, 1.6))
	for strand in 3:
		b.box(steel, Vector3(length, 0.035, 0.035), Vector3(0.0, 0.45 + strand * 0.45, 0.0))
		b.box(steel, Vector3(length, 0.035, 0.035), Vector3(0.0, 0.25 + strand * 0.2, 0.8 + strand * 0.3), 0.0, 0.0)
	# Carteles de minas: tablilla clara con el triángulo rojo.
	var signs: int = int(length / 45.0)
	for i in signs:
		var x: float = -length * 0.5 + (i + 0.5) * length / signs + _rng.randf_range(-6.0, 6.0)
		b.box(Color(0.86, 0.84, 0.76), Vector3(0.9, 0.6, 0.05), Vector3(x, 1.0, -0.12))
		b.roof(Color(0.7, 0.12, 0.1), Vector3(0.5, 0.4, 0.07), Vector3(x, 1.1, -0.16))
	b.commit(edge)


## Busca un sitio libre de radio `radius`. Devuelve Vector2.INF si no lo encuentra.
func _free_spot(radius: float, margin: float = 15.0) -> Vector2:
	# Nada asoma por encima del muro: el borde del objeto queda al menos a 8 m de él.
	margin = maxf(margin, radius + 8.0)
	for attempt in 40:
		var pos := Vector2(_rng.randf_range(-ARENA_HALF + margin, ARENA_HALF - margin), _rng.randf_range(-ARENA_HALF + margin, ARENA_HALF - margin))
		if pos.distance_to(_spawn_point) < SAFE_RADIUS + radius:
			continue
		var rect := Rect2(pos - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)
		if _is_clear(rect):
			return pos
	return Vector2.INF


## ¿Queda el rectángulo fuera de todo lo ocupado o reservado (y de caminos y cauces)?
func _is_clear(rect: Rect2, roads_too: bool = true) -> bool:
	for other in _obstacle_rects:
		if other.intersects(rect):
			return false
	if roads_too:
		for other in _keep_clear:
			if other.intersects(rect):
				return false
	return true


func _place(prop: Node3D, pos: Vector2, radius: float, yaw: float = 0.0) -> void:
	prop.position = Vector3(pos.x, 0.0, pos.y)
	prop.rotation.y = yaw
	add_child(prop)
	_obstacle_rects.append(Rect2(pos - Vector2.ONE * (radius + 3.0), Vector2.ONE * (radius + 3.0) * 2.0))


## Coloca varios objetos alrededor de un centro sin registrar obstáculos individuales. Con
## `burnt`, los dos primeros son árboles alcanzados por el fuego (y el primero sigue ardiendo).
func _scatter(center: Vector2, count: int, spread: float, factory: Callable, burnt: Callable = Callable()) -> void:
	for i in count:
		var prop: Node3D = burnt.call(i == 0) if burnt.is_valid() and i < 2 else factory.call()
		var offset := Vector2(_rng.randf_range(-spread, spread), _rng.randf_range(-spread, spread))
		prop.position = Vector3(center.x + offset.x, 0.0, center.y + offset.y)
		prop.rotation.y = _rng.randf() * TAU
		add_child(prop)
	_obstacle_rects.append(Rect2(center - Vector2.ONE * (spread + 3.0), Vector2.ONE * (spread + 3.0) * 2.0))


func _build_scenery() -> void:
	var front: int = GameSession.front
	PropFactory.mountain_color = Fronts.mountain_color(front)
	var desert: bool = front == Fronts.Id.AFRICA
	# Lo que da forma al campo (río, vía, pueblo, trincheras) va lo primero: lo demás se
	# reparte por los huecos que deja.
	_build_layout()
	await Loading.step(0.42, "trazado")
	# Lomas suaves: relieve por el que los tanques sí suben. Van antes que el decorado suelto,
	# que nunca se coloca encima de ellas. En el desierto son dunas y crestas alargadas; en la
	# estepa y en Normandía, ondulaciones redondas del terreno.
	for i in int(_layout.get("ridge", 0)):
		await Loading.breathe()
		_add_relief(_rng.randf_range(30.0, 42.0), _rng.randf_range(1.6, 2.4) if desert else 1.0)
	for i in int(_layout.get("mounds", 2 if desert else 3)):
		await Loading.breathe()
		_add_relief(_rng.randf_range(21.0, 30.0), 1.0)
	for i in int(_layout.get("dunes", 5 if desert else 0)):
		await Loading.breathe()
		_add_relief(_rng.randf_range(12.0, 18.0), _rng.randf_range(2.2, 3.4))
	match front:
		Fronts.Id.AFRICA:
			await _scenery_africa()
		Fronts.Id.KURSK:
			await _scenery_kursk()
		_:
			await _scenery_normandy()
	await Loading.step(0.62, "paisaje del frente")
	# Ruinas con bidones, rocas y depósitos de combustible abandonados en todos los frentes.
	for r in 4:
		await Loading.breathe()
		var pos := _free_spot(8.0)
		if pos == Vector2.INF:
			continue
		var ruin := PropFactory.ruin(_rng.randf_range(8.0, 14.0))
		_place(ruin, pos, 7.0, _rng.randf() * TAU)
		if r < 2:
			# Un par de ellas aún humean.
			var vent := FxVent.new()
			vent.rate = 1.8
			vent.size = 1.3
			vent.rise = 1.8
			vent.color = Color(Fx.GREY_SMOKE.r, Fx.GREY_SMOKE.g, Fx.GREY_SMOKE.b, 0.55)
			vent.position = Vector3(_rng.randf_range(-3.0, 3.0), 0.6, 1.2)
			ruin.add_child(vent)
		for b in _rng.randi_range(1, 3):
			await Loading.breathe()
			var barrel := PropFactory.barrel()
			barrel.position = Vector3(pos.x + _rng.randf_range(-5.0, 5.0), 0.0, pos.y + _rng.randf_range(2.0, 5.0))
			add_child(barrel)
	# Edificios con premio (anillo verde en el radar).
	var prizes: Array[Callable] = [StructureFactory.radio_mast, StructureFactory.water_tower, StructureFactory.flak_gun, StructureFactory.flak_gun, StructureFactory.command_tent]
	for factory in prizes:
		await Loading.breathe()
		var pos := _free_spot(6.0)
		if pos != Vector2.INF:
			_place(factory.call(), pos, 6.0, _rng.randf() * TAU)
	for i in int(_layout.get("scatter", 25 if desert else 12)):
		await Loading.breathe()
		var radius: float = _rng.randf_range(0.8, 2.5)
		var pos := _free_spot(radius)
		if pos != Vector2.INF:
			_place(PropFactory.rock(radius), pos, radius)


## Pueblo: `houses` casas en torno a `center`. Una de ellas, la que da `bombed_factory`, está
## bombardeada y sigue ardiendo.
func _village(center: Vector2, houses: int, house_factory: Callable, bombed_factory: Callable = Callable()) -> void:
	var bombed: int = _rng.randi() % houses if bombed_factory.is_valid() else -1
	for h in houses:
		var offset := Vector2(_rng.randf_range(-20.0, 20.0), _rng.randf_range(-20.0, 20.0))
		var prop: Node3D = bombed_factory.call() if h == bombed else house_factory.call()
		prop.position = Vector3(center.x + offset.x, 0.0, center.y + offset.y)
		prop.rotation.y = round(_rng.randf() * 4.0) * PI * 0.5
		add_child(prop)
	_obstacle_rects.append(Rect2(center - Vector2(28.0, 28.0), Vector2(56.0, 56.0)))


func _house_size() -> Vector3:
	return Vector3(_rng.randf_range(5.0, 8.0), _rng.randf_range(3.5, 5.0), _rng.randf_range(6.0, 9.0))


## Loma de medio ancho `radius`; con `stretch` > 1, alargada (duna, cresta) y de rumbo al azar.
func _add_relief(radius: float, stretch: float) -> void:
	var pos := _free_spot(radius * stretch)
	if pos == Vector2.INF:
		return
	var yaw: float = _rng.randf() * PI
	add_child(Terrain.add_mound(pos, radius, VectorMaterials.ground(), _rng.randf(), Terrain.HEIGHT_RATIO, stretch, yaw))
	# El rectángulo que ocupa, girado: basta con la caja que lo envuelve.
	var half := Vector2(absf(cos(yaw)) * radius * stretch + absf(sin(yaw)) * radius, absf(sin(yaw)) * radius * stretch + absf(cos(yaw)) * radius) * 1.1
	_obstacle_rects.append(Rect2(pos - half, half * 2.0))


## Normandía: el bocage (prados cerrados por setos altos sobre talud), granjas de piedra con su
## palomar, huertos de manzanos, cruceros en los caminos.
func _scenery_normandy() -> void:
	for v in int(_layout.get("villages", 2)):
		await Loading.breathe()
		# El pueblo de la iglesia ocupa más: las casas van desplazadas respecto al templo.
		var center := _free_spot(48.0 if v == 0 else 30.0)
		if center == Vector2.INF:
			continue
		if v == 0:
			var church := PropFactory.church()
			church.position = Vector3(center.x, 0.0, center.y)
			add_child(church)
			_obstacle_rects.append(Rect2(center - Vector2(14.0, 14.0), Vector2(28.0, 28.0)))
			_village(center + Vector2(0.0, 22.0), 2, func() -> Node3D: return PropFactory.house(_house_size()), func() -> Node3D: return PropFactory.bombed_house(_house_size(), 0))
		else:
			_village(center, 4, func() -> Node3D: return PropFactory.house(_house_size()), func() -> Node3D: return PropFactory.bombed_house(_house_size(), 0))
		for l in 3:
			await Loading.breathe()
			var lamp := PropFactory.lamp_post()
			lamp.position = Vector3(center.x + _rng.randf_range(-20.0, 20.0), 0.0, center.y + _rng.randf_range(-20.0, 20.0))
			add_child(lamp)
	for f in int(_layout.get("farm", 1)):
		await Loading.breathe()
		var pos := _free_spot(24.0)
		if pos != Vector2.INF:
			_place(FrontProps.stone_farm(), pos, 20.0, round(_rng.randf() * 4.0) * PI * 0.5)
	# Planeadores estrellados (los que tomaron los puentes) y estacas contra ellos en los prados.
	for g in int(_layout.get("gliders", 0)):
		await Loading.breathe()
		var pos := _free_spot(12.0)
		if pos != Vector2.INF:
			_place(FrontProps.glider_wreck(), pos, 10.0, _rng.randf() * TAU)
	for a in int(_layout.get("asparagus", 0)):
		await Loading.breathe()
		var size := Vector2(_rng.randf_range(50.0, 80.0), _rng.randf_range(40.0, 60.0))
		var pos := _free_spot(maxf(size.x, size.y) * 0.5)
		if pos != Vector2.INF:
			var stakes: Node3D = FrontProps.asparagus(size)
			stakes.position = Vector3(pos.x, 0.0, pos.y)
			add_child(stakes)
			_keep_clear.append(Rect2(pos - size * 0.5, size))
	# El bocage: una cuadrícula de setos con portillos. Los sueltos de siempre, además.
	if _layout.has("bocage"):
		await _build_bocage(float(_layout["bocage"]))
	for i in int(_layout.get("hedges", 12)):
		await Loading.breathe()
		var length: float = _rng.randf_range(18.0, 34.0)
		var pos := _free_spot(length * 0.5)
		if pos != Vector2.INF:
			_place(PropFactory.hedgerow(length), pos, length * 0.5, round(_rng.randf() * 2.0) * PI * 0.5)
	# Huertos de manzanos.
	for o in int(_layout.get("woods", 5)):
		await Loading.breathe()
		var center := _free_spot(12.0)
		if center != Vector2.INF:
			_scatter(center, _rng.randi_range(5, 9), 10.0, func() -> Node3D: return PropFactory.apple_tree(_rng.randf_range(4.0, 6.0)),
					(func(burning: bool) -> Node3D: return PropFactory.burnt_tree(_rng.randf_range(4.0, 6.0), 0, burning)) if o < 2 else Callable())
	for f in 4:
		await Loading.breathe()
		var pos := _free_spot(6.0)
		if pos != Vector2.INF:
			_place(PropFactory.fence(12.0), pos, 6.0, _rng.randf() * TAU)
	for c in 2:
		await Loading.breathe()
		var pos := _free_spot(2.0)
		if pos != Vector2.INF:
			_place(FrontProps.calvary(), pos, 1.5, _rng.randf() * TAU)


## Cuadrícula del bocage: setos a lo largo de las lindes de prados de unos `cell` metros, cada
## uno con su portillo (por ahí pasan los tanques) y alguna linde abierta del todo.
func _build_bocage(cell: float) -> void:
	var lines: int = int((ARENA_HALF * 2.0 - 40.0) / cell)
	var start: float = -lines * cell * 0.5
	var shift := Vector2(_rng.randf_range(-8.0, 8.0), _rng.randf_range(-8.0, 8.0))
	for horizontal: bool in [true, false]:
		await Loading.breathe()
		for i in range(1, lines):
			await Loading.breathe()
			for j in lines:
				await Loading.breathe()
				if _rng.randf() < 0.26:
					continue
				var gate: float = _rng.randf_range(13.0, 17.0)
				var length: float = cell - gate
				# El portillo queda en un extremo o en el otro.
				var along: float = start + j * cell + (length * 0.5 if _rng.randf() < 0.5 else gate + length * 0.5)
				var across: float = start + i * cell + _rng.randf_range(-3.0, 3.0)
				var centre: Vector2 = (Vector2(along, across) if horizontal else Vector2(across, along)) + shift
				var half: Vector2 = Vector2(length * 0.5, 1.6) if horizontal else Vector2(1.6, length * 0.5)
				var rect := Rect2(centre - half, half * 2.0)
				if centre.distance_to(_spawn_point) < 32.0 or not _is_clear(rect.grow(1.5)):
					continue
				var hedge: Destructible = PropFactory.hedgerow(length)
				hedge.position = Vector3(centre.x, 0.0, centre.y)
				hedge.rotation.y = 0.0 if horizontal else PI * 0.5
				add_child(hedge)
				_obstacle_rects.append(rect)


## Norte de África: casi nada. Matorral reseco, alguna acacia, afloramientos de roca, sangars de
## piedra, jaimas, camiones quemados en la pista y campos de minas cercados.
func _scenery_africa() -> void:
	for v in int(_layout.get("villages", 1)):
		await Loading.breathe()
		# Sitio para el pueblo y para su palmeral, que va a un lado.
		var center := _free_spot(44.0)
		if center == Vector2.INF:
			continue
		_village(center, 4, func() -> Node3D: return PropFactory.desert_house(Vector3(_rng.randf_range(5.0, 8.0), _rng.randf_range(3.0, 4.5), _rng.randf_range(5.0, 8.0))),
				func() -> Node3D: return PropFactory.bombed_house(Vector3(_rng.randf_range(5.0, 8.0), _rng.randf_range(3.0, 4.5), _rng.randf_range(5.0, 8.0)), 1))
		_scatter(center + Vector2(32.0, 0.0), 6, 8.0, func() -> Node3D: return PropFactory.palm(_rng.randf_range(7.0, 10.0)),
				func(burning: bool) -> Node3D: return PropFactory.burnt_tree(_rng.randf_range(7.0, 10.0), 2, burning))
	# Afloramientos: peñascos grandes apiñados, la única cobertura del llano.
	for o in int(_layout.get("outcrops", 5)):
		await Loading.breathe()
		var pos := _free_spot(9.0)
		if pos == Vector2.INF:
			continue
		for r in _rng.randi_range(3, 5):
			await Loading.breathe()
			var rock: Destructible = PropFactory.rock(_rng.randf_range(2.4, 4.6))
			rock.position = Vector3(pos.x + _rng.randf_range(-6.0, 6.0), 0.0, pos.y + _rng.randf_range(-6.0, 6.0))
			add_child(rock)
		_obstacle_rects.append(Rect2(pos - Vector2(11.0, 11.0), Vector2(22.0, 22.0)))
	for i in 5:
		await Loading.breathe()
		var pos := _free_spot(5.0)
		if pos != Vector2.INF:
			_place(FrontProps.sangar(), pos, 4.0, _rng.randf() * TAU)
	for i in 5:
		await Loading.breathe()
		var pos := _free_spot(5.0)
		if pos != Vector2.INF:
			_place(PropFactory.sandbags(_rng.randf_range(6.0, 10.0)), pos, 5.0, _rng.randf() * TAU)
	# Campamento beduino.
	var camp := _free_spot(16.0)
	if camp != Vector2.INF:
		for t in 3:
			await Loading.breathe()
			var tent: Destructible = FrontProps.tent()
			tent.position = Vector3(camp.x + (t - 1) * 9.0 + _rng.randf_range(-1.5, 1.5), 0.0, camp.y + _rng.randf_range(-5.0, 5.0))
			tent.rotation.y = _rng.randf_range(-0.3, 0.3)
			add_child(tent)
		_obstacle_rects.append(Rect2(camp - Vector2(17.0, 12.0), Vector2(34.0, 24.0)))
	for i in 3:
		await Loading.breathe()
		var pos := _free_spot(5.0)
		if pos != Vector2.INF:
			_place(FrontProps.truck_wreck(), pos, 4.0, _rng.randf() * TAU)
	for i in int(_layout.get("minefields", 2)):
		await Loading.breathe()
		var size := Vector2(_rng.randf_range(30.0, 52.0), _rng.randf_range(20.0, 34.0))
		var pos := _free_spot(maxf(size.x, size.y) * 0.5)
		if pos != Vector2.INF:
			var mines: Node3D = FrontProps.minefield(size)
			mines.position = Vector3(pos.x, 0.0, pos.y)
			add_child(mines)
			_keep_clear.append(Rect2(pos - size * 0.5, size).grow(1.0))
	# Palmeras solo donde hay agua (los oasis piden más); fuera, acacias sueltas.
	for i in int(_layout.get("woods", 2)):
		await Loading.breathe()
		var pos := _free_spot(4.0)
		if pos != Vector2.INF:
			_scatter(pos, 3, 4.0, func() -> Node3D: return PropFactory.palm(_rng.randf_range(6.0, 9.0)))
	for i in 9:
		await Loading.breathe()
		var pos := _free_spot(3.0)
		if pos != Vector2.INF:
			_place(FrontProps.acacia(_rng.randf_range(4.0, 6.5)), pos, 1.0, _rng.randf() * TAU)
	# Matorral: muchas matas, un solo dibujo. No se ponen en caminos ni dentro de nada.
	var tufts := PackedVector3Array()
	for i in 260:
		await Loading.breathe()
		var p := Vector2(_rng.randf_range(-ARENA_HALF + 6.0, ARENA_HALF - 6.0), _rng.randf_range(-ARENA_HALF + 6.0, ARENA_HALF - 6.0))
		if _is_clear(Rect2(p - Vector2(0.8, 0.8), Vector2(1.6, 1.6))):
			tufts.append(Vector3(p.x, Terrain.height(p.x, p.y), p.y))
	add_child(FrontProps.scrub(tufts))


## Kursk: la estepa. Aldeas de isbas con su granero y su pozo de cigüeñal, un molino de viento,
## girasoles, bosquetes de abedul, almiares, erizos antitanque, carros calcinados y una pista
## de tierra con su línea de telégrafo.
func _scenery_kursk() -> void:
	for v in int(_layout.get("villages", 2)):
		await Loading.breathe()
		var center := _free_spot(34.0)
		if center == Vector2.INF:
			continue
		_village(center, 5, func() -> Node3D: return PropFactory.izba(Vector3(_rng.randf_range(5.0, 7.0), _rng.randf_range(3.0, 4.0), _rng.randf_range(6.0, 8.0))),
				func() -> Node3D: return PropFactory.bombed_house(Vector3(_rng.randf_range(5.0, 7.0), _rng.randf_range(3.0, 4.0), _rng.randf_range(6.0, 8.0)), 2))
		for f in 3:
			await Loading.breathe()
			var fence := PropFactory.fence(10.0)
			fence.position = Vector3(center.x + _rng.randf_range(-25.0, 25.0), 0.0, center.y + _rng.randf_range(-25.0, 25.0))
			fence.rotation.y = _rng.randf() * TAU
			add_child(fence)
		var well: Destructible = FrontProps.sweep_well()
		well.position = Vector3(center.x + _rng.randf_range(-6.0, 6.0), 0.0, center.y + _rng.randf_range(-6.0, 6.0))
		well.rotation.y = _rng.randf() * TAU
		add_child(well)
		var barn: Destructible = FrontProps.barn()
		barn.position = Vector3(center.x + (30.0 if v % 2 == 0 else -30.0), 0.0, center.y + _rng.randf_range(-8.0, 8.0))
		barn.rotation.y = round(_rng.randf() * 2.0) * PI * 0.5
		add_child(barn)
		_obstacle_rects.append(Rect2(center - Vector2(46.0, 30.0), Vector2(92.0, 60.0)))
	var mill := _free_spot(8.0)
	if mill != Vector2.INF:
		_place(FrontProps.windmill(), mill, 6.0, _rng.randf() * TAU)
	for i in int(_layout.get("sunflowers", 2)):
		await Loading.breathe()
		var size := Vector2(snappedf(_rng.randf_range(30.0, 46.0), 4.0), snappedf(_rng.randf_range(24.0, 38.0), 4.0))
		var pos := _free_spot(maxf(size.x, size.y) * 0.5)
		if pos != Vector2.INF:
			var field: Node3D = FrontProps.sunflower_field(size)
			field.position = Vector3(pos.x, 0.0, pos.y)
			add_child(field)
			_keep_clear.append(Rect2(pos - size * 0.5, size).grow(2.0))
	# Carros de los combates de los días anteriores.
	var models: Array[TankStats] = []
	for faction in 2:
		await Loading.breathe()
		models.append_array(_mode.roster(faction))
	for i in int(_layout.get("hulks", 3)):
		await Loading.breathe()
		var pos := _free_spot(5.0)
		if pos != Vector2.INF and not models.is_empty():
			_place(FrontProps.tank_hulk(models.pick_random()), pos, 4.0, _rng.randf() * TAU)
	for g in int(_layout.get("woods", 7)):
		await Loading.breathe()
		var center := _free_spot(12.0)
		if center != Vector2.INF:
			_scatter(center, _rng.randi_range(5, 9), 10.0, func() -> Node3D: return PropFactory.birch(_rng.randf_range(7.0, 11.0)),
					(func(burning: bool) -> Node3D: return PropFactory.burnt_tree(_rng.randf_range(7.0, 11.0), 1, burning)) if g < 2 else Callable())
	for i in 16:
		await Loading.breathe()
		var pos := _free_spot(3.0)
		if pos != Vector2.INF:
			_place(PropFactory.haystack(), pos, 3.0)
	# Líneas de erizos antitanque.
	for line in 3:
		await Loading.breathe()
		var start := _free_spot(14.0)
		if start == Vector2.INF:
			continue
		var dir := Vector2.from_angle(_rng.randf() * TAU)
		for i in 6:
			await Loading.breathe()
			var p: Vector2 = start + dir * (i - 2.5) * 4.5
			var hog := PropFactory.hedgehog()
			hog.position = Vector3(p.x, 0.0, p.y)
			hog.rotation.y = _rng.randf() * TAU
			add_child(hog)
		_obstacle_rects.append(Rect2(start - Vector2(15.0, 15.0), Vector2(30.0, 30.0)))


## Línea de telégrafo de `from` a `to`: postes cada 28 m, a un lado, con sus hilos. Cada poste
## lleva los hilos hasta el siguiente: si un tanque lo tumba, se van con él.
func _telegraph(from: Vector2, to: Vector2, aside: float = 6.5) -> void:
	var dir: Vector2 = (to - from).normalized()
	var side := Vector2(-dir.y, dir.x) * aside
	var count: int = int(from.distance_to(to) / 28.0)
	var wire_material: StandardMaterial3D = VectorMaterials.paint(Color(0.1, 0.1, 0.1))
	for i in count + 1:
		var spot: Vector2 = from + dir * i * 28.0 + side
		if absf(spot.x) > ARENA_HALF - 4.0 or absf(spot.y) > ARENA_HALF - 4.0 or not _is_clear(Rect2(spot - Vector2(0.6, 0.6), Vector2(1.2, 1.2)), false):
			continue
		var pole: Destructible = FrontProps.telegraph_pole()
		pole.position = Vector3(spot.x, 0.0, spot.y)
		# Las crucetas, atravesadas a la línea.
		pole.rotation.y = atan2(dir.x, dir.y)
		add_child(pole)
		if i < count:
			for offset: float in [-0.7, 0.7]:
				var wire := MeshInstance3D.new()
				var strand := BoxMesh.new()
				strand.size = Vector3(0.03, 0.03, 28.0)
				wire.mesh = strand
				wire.material_override = wire_material
				wire.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				wire.position = Vector3(offset, 6.85, 14.0)
				pole.add_child(wire)


## Escarpe del desierto: un farallón de roca que cruza el mapa de oeste a este por z = `base`,
## en tramos, con tres collados por los que se pasa (en el centro y a los lados).
func _build_scarp(base: float) -> void:
	var phase: float = _rng.randf() * TAU
	var passes: Array[float] = [-118.0 + _rng.randf_range(-12.0, 12.0), _rng.randf_range(-14.0, 14.0), 118.0 + _rng.randf_range(-12.0, 12.0)]
	var x: float = -ARENA_HALF + 14.0
	while x < ARENA_HALF - 30.0:
		var length: float = _rng.randf_range(26.0, 40.0)
		var centre_x: float = x + length * 0.5
		var open: bool = false
		for pass_x in passes:
			if absf(centre_x - pass_x) < length * 0.5 + 9.0:
				open = true
		var z0: float = base + 16.0 * sin(x * 0.018 + phase)
		var z1: float = base + 16.0 * sin((x + length) * 0.018 + phase)
		var centre := Vector2(centre_x, (z0 + z1) * 0.5)
		var rect := Rect2(centre - Vector2(length * 0.5, 6.0), Vector2(length, 12.0))
		if not open and centre.distance_to(_spawn_point) > 36.0 and _is_clear(rect.grow(1.0)):
			var rock: Destructible = FrontProps.scarp(length + 3.0, _rng.randf_range(5.5, 8.5))
			rock.position = Vector3(centre.x, 0.0, centre.y)
			rock.rotation.y = -atan2(z1 - z0, length)
			add_child(rock)
			_obstacle_rects.append(rect)
		x += length - 1.0


# ------------------------------------------------------------------ trazado del campo

## Monta los rasgos del trazado de esta partida (ver Layouts): río o arroyo, vía de tren,
## pueblo con calles, líneas de trincheras y trigales.
func _build_layout() -> void:
	if _layout.is_empty():
		return
	var town_kind: String = _layout.get("town", "")
	var town_at := Vector2.INF
	if town_kind != "":
		town_at = _town_site(town_kind)
	var water: String = _layout.get("water", "")
	if water != "":
		var crossed: Vector2 = _build_water(water, town_at if town_kind == "river" else Vector2.INF)
		if town_kind == "river":
			# El pueblo va donde de verdad ha cabido el río (o donde estaba, si no hay río).
			town_at = crossed if crossed != Vector2.INF else town_at
	var rail: String = _layout.get("rail", "")
	var rail_line: float = INF
	if rail != "":
		rail_line = _build_rail(rail == "ew", town_at, 64.0 if town_kind == "center" else 50.0)
	if town_at != Vector2.INF:
		# El pueblo del río queda casi todo en la orilla sur, con el puente al final de su calle.
		_build_town(town_at + (Vector2(0.0, 34.0) if town_kind == "river" else Vector2.ZERO), town_kind, rail == "ew", rail_line)
	if int(_layout.get("trenches", 0)) > 0:
		_build_trenches(int(_layout["trenches"]))
	if _layout.has("scarp"):
		_build_scarp(float(_layout["scarp"]))
	if GameSession.front == Fronts.Id.KURSK:
		# La línea de telégrafo sigue la vía; si no hay, una pista de tierra que cruza la estepa.
		if rail_line != INF:
			var along_rail: Vector2 = Vector2(ARENA_HALF, 0.0) if rail == "ew" else Vector2(0.0, ARENA_HALF)
			var on_rail: Vector2 = Vector2(0.0, rail_line) if rail == "ew" else Vector2(rail_line, 0.0)
			_telegraph(on_rail - along_rail, on_rail + along_rail, 7.0)
		elif town_at == Vector2.INF and water == "":
			var z: float = _rng.randf_range(-120.0, 90.0)
			var from := Vector2(-ARENA_HALF - 15.0, z + _rng.randf_range(-40.0, 40.0))
			var to := Vector2(ARENA_HALF + 15.0, z + _rng.randf_range(-40.0, 40.0))
			_road(from, to)
			_telegraph(from, to)
	var ripe: Color = Color(0.74, 0.6, 0.26) if GameSession.front == Fronts.Id.KURSK else Color(0.66, 0.6, 0.3)
	for i in int(_layout.get("wheat", 0)):
		var size := Vector2(snappedf(_rng.randf_range(30.0, 46.0), 4.0), snappedf(_rng.randf_range(24.0, 38.0), 4.0))
		var pos := _free_spot(maxf(size.x, size.y) * 0.5)
		if pos == Vector2.INF:
			continue
		var field: MeshInstance3D = PropFactory.wheat_field(size, ripe)
		field.position = Vector3(pos.x, 0.0, pos.y)
		add_child(field)
		_keep_clear.append(Rect2(pos - size * 0.5, size).grow(2.0))


## Dónde va el pueblo: el primer sitio de los de su tipo que no pisa nada reservado.
func _town_site(kind: String) -> Vector2:
	var options: Array[Vector2] = [Vector2(0.0, -15.0), Vector2(0.0, -45.0), Vector2(35.0, -20.0), Vector2(-35.0, -20.0), Vector2(0.0, 30.0)]
	var start: int = 0
	match kind:
		"center":
			return Vector2.ZERO
		"side":
			options = [Vector2(-100.0, 15.0), Vector2(100.0, 15.0), Vector2(-105.0, -35.0), Vector2(105.0, -35.0)]
			start = _rng.randi() % options.size()
		"river":
			options = [Vector2(0.0, -20.0), Vector2(0.0, 25.0), Vector2(-40.0, -10.0), Vector2(40.0, -10.0)]
	for i in options.size():
		var spot: Vector2 = options[(start + i) % options.size()]
		if _is_clear(Rect2(spot - Vector2(22.0, 22.0), Vector2(44.0, 44.0))):
			return spot
	return Vector2.INF


## Río, arroyo, rambla o charca. `through`: punto por el que debe pasar el río (el pueblo que
## lo cruza), o Vector2.INF.
## Devuelve el punto por el que ha acabado pasando (puede correrse si ahí no cabe), o INF.
func _build_water(kind: String, through: Vector2) -> Vector2:
	var front: int = GameSession.front
	var course := Water.Course.new()
	var river: bool = kind.begins_with("river")
	course.kind = Water.Kind.RIVER if river else (Water.Kind.WADI if kind == "wadi" else Water.Kind.STREAM)
	course.half_width = Water.HALF_WIDTH[course.kind]
	var ew: bool = kind == "river_ew" or (not river and _rng.randf() < 0.5)
	var bases: Array = _layout.get("river_at", [])
	var found: bool = false
	var pinned: Vector2 = through
	for attempt in 18:
		var raw := PackedVector2Array()
		if kind == "spring":
			var centre := _free_spot(30.0)
			if centre == Vector2.INF:
				continue
			var dir := Vector2.from_angle(_rng.randf() * TAU)
			var side := Vector2(-dir.y, dir.x)
			raw = PackedVector2Array([centre - dir * 24.0, centre - dir * 8.0 + side * _rng.randf_range(-6.0, 6.0), centre + dir * 8.0 + side * _rng.randf_range(-6.0, 6.0), centre + dir * 24.0])
			course.half_width = 6.5
		else:
			var base: float = _rng.randf_range(-110.0, 110.0)
			if through != Vector2.INF:
				# Si por el sitio del pueblo no cabe, se prueba más al sur y más al norte.
				var shift: float = [0.0, 42.0, -42.0, 78.0, -78.0, 112.0][attempt / 3]
				var moved: Vector2 = through + (Vector2(0.0, shift) if ew else Vector2(shift, 0.0))
				if shift != 0.0 and not _is_clear(Rect2(moved - Vector2(22.0, 22.0), Vector2(44.0, 44.0))):
					continue
				base = moved.y if ew else moved.x
				pinned = moved
			elif attempt < bases.size():
				base = bases[attempt]
			var sway: float = 15.0 if river else 32.0
			var tilt: float = 0.0 if river else _rng.randf_range(-0.3, 0.3)
			var along: float = -300.0
			while along <= 300.0:
				var offset: float = base + along * tilt + _rng.randf_range(-sway, sway)
				# Por el pueblo el río pasa derecho, para que el puente quede en su calle.
				if through != Vector2.INF and absf(along - (through.x if ew else through.y)) < 50.0:
					offset = base
				raw.append(Vector2(along, offset) if ew else Vector2(offset, along))
				along += _rng.randf_range(42.0, 60.0)
		course.points = Ribbon.smooth(raw, 2)
		if _course_fits(course):
			found = true
			break
	if not found:
		return Vector2.INF
	through = pinned
	if river:
		var list: Array = _layout.get("crossings", [])
		if list.is_empty():
			var mid: float = _rng.randf_range(-25.0, 25.0)
			if through != Vector2.INF:
				mid = through.x if ew else through.y
			# Un paso por el centro (puente si es el del pueblo; si no, vado) y un puente a cada lado.
			list = [[mid, through != Vector2.INF], [mid - _rng.randf_range(95.0, 120.0), true], [mid + _rng.randf_range(95.0, 120.0), true]]
			if through != Vector2.INF:
				list.append([mid + (58.0 if _rng.randf() < 0.5 else -58.0), false])
		for item: Array in list:
			course.add_crossing(_course_distance(course.points, clampf(item[0], -172.0, 172.0), ew), item[1])
	add_child(Water.build(course, front))
	# El valle del río sigue más allá del muro: las montañas de fuera que le caen encima se quitan.
	for entry: Array in _far_mountains:
		var mountain: Node3D = entry[0]
		if is_instance_valid(mountain) and Ribbon.distance_to(course.points, Vector2(mountain.position.x, mountain.position.z)) < float(entry[1]) + course.half_width + 6.0:
			mountain.free()
	_keep_clear.append_array(Water.rects(course, 4.0))
	if not river:
		return through
	_obstacle_rects.append_array(Water.rects(course, 1.5))
	for crossing in course.crossings:
		var at: Vector2 = crossing["at"]
		var dir: Vector2 = crossing["dir"]
		var over := Vector2(-dir.y, dir.x)
		var mark := Node3D.new()
		mark.position = Vector3(at.x, 0.0, at.y)
		mark.add_to_group(&"radar_marks")
		mark.set_meta("radar_shape", "crossing")
		mark.set_meta("radar_color", Color(0.9, 0.93, 1.0) if crossing["bridge"] else Color(0.45, 0.85, 1.0))
		add_child(mark)
		if crossing["bridge"]:
			var bridge: Node3D = PropFactory.bridge(course.half_width * 2.0 + 7.0, Water.BRIDGE_HALF * 2.0 - 1.6, 1 if front == Fronts.Id.KURSK else 0)
			bridge.position = Vector3(at.x, 0.0, at.y)
			bridge.rotation.y = atan2(over.x, over.y)
			add_child(bridge)
			# Un camino de lado a lado del mapa pasa por cada puente.
			_road(at - over * _reach(at, -over), at + over * _reach(at, over))
		else:
			# Vado: estacas a las dos orillas marcan por dónde se cruza.
			for bank: float in [-1.0, 1.0]:
				for edge: float in [-1.0, 1.0]:
					var stake := VectorMaterials.make_box(Vector3(0.22, 1.9, 0.22), Color(0.4, 0.3, 0.18), 5, 0.3)
					var spot: Vector2 = at + over * bank * (course.half_width + 1.5) + dir * edge * (Water.FORD_HALF - 1.5)
					stake.position = Vector3(spot.x, 0.95, spot.y)
					stake.rotation.z = _rng.randf_range(-0.12, 0.12)
					add_child(stake)
	return through


## Metros desde `from` en la dirección `dir` hasta salir del campo.
func _reach(from: Vector2, dir: Vector2) -> float:
	var limit: float = ARENA_HALF + 15.0
	var best: float = 600.0
	if absf(dir.x) > 0.001:
		best = minf(best, (limit * signf(dir.x) - from.x) / dir.x)
	if absf(dir.y) > 0.001:
		best = minf(best, (limit * signf(dir.y) - from.y) / dir.y)
	return maxf(best, 0.0)


## ¿Cabe el cauce sin pisar zonas reservadas ni pasar pegado a donde aparece el jugador?
func _course_fits(course: Water.Course) -> bool:
	var field := Rect2(Vector2(-ARENA_HALF, -ARENA_HALF), Vector2(ARENA_HALF, ARENA_HALF) * 2.0)
	var home := Rect2(_spawn_point - Vector2(26.0, 26.0), Vector2(52.0, 52.0))
	for rect in Water.rects(course, 6.0):
		if not rect.intersects(field):
			continue
		if rect.intersects(home) or not _is_clear(rect, false):
			return false
	return true


## Metros desde el comienzo del cauce hasta donde pasa por la coordenada `value` (la x en un
## cauce de oeste a este; la z en uno de norte a sur).
func _course_distance(points: PackedVector2Array, value: float, ew: bool) -> float:
	var run: float = 0.0
	for i in range(1, points.size()):
		var a: float = points[i - 1].x if ew else points[i - 1].y
		var b: float = points[i].x if ew else points[i].y
		var step: float = points[i - 1].distance_to(points[i])
		if value >= a and value <= b and b > a:
			return run + step * (value - a) / (b - a)
		run += step
	return run * 0.5


## Camino de tierra de `from` a `to` (solo dibujo): nada del decorado se le pone encima.
func _road(from: Vector2, to: Vector2, half_width: float = 3.6, pattern: int = 0, color: Color = Color(-1.0, 0.0, 0.0)) -> void:
	var length: float = from.distance_to(to)
	if length < 4.0:
		return
	var steps: int = maxi(ceili(length / 18.0), 1)
	var points := PackedVector2Array()
	for i in steps + 1:
		points.append(from.lerp(to, float(i) / steps))
	var dirt: Color = Fronts.ground_colors(GameSession.front)[2].lightened(0.08) if color.r < 0.0 else color
	add_child(Ribbon.node(points, half_width, Ribbon.Y_ROAD, Ribbon.strip(dirt, dirt.darkened(0.4), pattern, half_width * 2.0, 0.0 if pattern == 1 else 0.6)))
	for i in steps:
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		_keep_clear.append(Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (b - a).abs()).grow(half_width + 1.5))


## Vía de tren recta de lado a lado del mapa. Devuelve la coordenada por la que pasa (z si va
## de oeste a este, x si va de norte a sur), o INF si no cabe.
func _build_rail(ew: bool, town_at: Vector2, town_gap: float = 50.0) -> float:
	var options: Array[float] = [-64.0, 46.0, 92.0, -100.0]
	if town_at != Vector2.INF:
		# Junto al pueblo: por el norte, o por el este si va de norte a sur.
		options = [(town_at.y - town_gap) if ew else (town_at.x + town_gap), (town_at.y + town_gap) if ew else (town_at.x - town_gap)]
	var line: float = INF
	for option in options:
		var strip: Rect2 = Rect2(Vector2(-ARENA_HALF, option - 6.0), Vector2(ARENA_HALF * 2.0, 12.0)) if ew else Rect2(Vector2(option - 6.0, -ARENA_HALF), Vector2(12.0, ARENA_HALF * 2.0))
		if _is_clear(strip, false):
			line = option
			break
	if line == INF:
		return INF
	var reach: float = ARENA_HALF + 15.0
	var from: Vector2 = Vector2(-reach, line) if ew else Vector2(line, -reach)
	var to: Vector2 = Vector2(reach, line) if ew else Vector2(line, reach)
	_road(from, to, 3.0, 3, Color(0.45, 0.43, 0.4))
	var sleepers: MeshInstance3D = Ribbon.node(PackedVector2Array([from, to]), 1.35, Ribbon.Y_ROAD + 0.04, Ribbon.strip(Color(0.26, 0.2, 0.14), Color(0.1, 0.09, 0.08), 6, 2.7, 0.0))
	add_child(sleepers)
	for side: float in [-0.75, 0.75]:
		var rail := MeshInstance3D.new()
		var bar := BoxMesh.new()
		bar.size = Vector3(reach * 2.0, 0.16, 0.12) if ew else Vector3(0.12, 0.16, reach * 2.0)
		rail.mesh = bar
		rail.material_override = VectorMaterials.paint(Color(0.2, 0.2, 0.22))
		rail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		rail.position = Vector3(0.0, 0.26, line + side) if ew else Vector3(line + side, 0.26, 0.0)
		add_child(rail)
	# Vagones parados en la vía, en uno o dos cortes.
	for group in 2:
		var along: float = _rng.randf_range(-150.0, 130.0)
		for i in _rng.randi_range(1, 3):
			var pos: Vector2 = Vector2(along + i * 9.6, line) if ew else Vector2(line, along + i * 9.6)
			var rect: Rect2 = Rect2(pos - (Vector2(4.8, 2.0) if ew else Vector2(2.0, 4.8)), Vector2(9.6, 4.0) if ew else Vector2(4.0, 9.6))
			if not _is_clear(rect.grow(2.0), false) or pos.distance_to(_spawn_point) < 30.0:
				break
			var wagon: Destructible = PropFactory.wagon()
			wagon.position = Vector3(pos.x, 0.0, pos.y)
			wagon.rotation.y = PI * 0.5 if ew else 0.0
			add_child(wagon)
			_obstacle_rects.append(rect.grow(1.0))
	return line


## Pueblo de verdad: calle mayor (de norte a sur) y travesía con las casas alineadas a los dos
## lados y dando a la calle, plaza con pozo, iglesia o morabito, huertos detrás y caminos que
## salen hacia los cuatro lados del mapa. `kind` "center": el centro del mapa queda libre como
## plaza (la posición que se defiende) y las casas empiezan más allá.
func _build_town(origin: Vector2, kind: String, rail_ew: bool, rail_line: float) -> void:
	var front: int = GameSession.front
	var style: int = [0, 1, 2][front]
	var central: bool = kind == "center"
	var small: bool = kind == "side"
	var main_half: float = 78.0 if central else (48.0 if small else 66.0)
	var cross_half: float = 66.0 if central else (32.0 if small else 46.0)
	var square: float = 32.0 if central else 14.0
	var street_half: float = 6.5
	var along := Vector2(0.0, 1.0)
	var across := Vector2(1.0, 0.0)
	# Lo singular va primero, para que las casas le dejen sitio.
	var landmark_at: Vector2 = origin - along * (square + 14.0) - across * (street_half + 9.0)
	var landmark_rect := Rect2(landmark_at - Vector2(7.0, 12.0), Vector2(14.0, 27.0))
	if not _is_clear(landmark_rect):
		landmark_at = origin + along * (square + 14.0) + across * (street_half + 9.0)
		landmark_rect = Rect2(landmark_at - Vector2(7.0, 12.0), Vector2(14.0, 27.0))
	if _is_clear(landmark_rect):
		var landmark: Node3D
		match style:
			0:
				landmark = PropFactory.church()
			1:
				landmark = PropFactory.koubba()
			_:
				landmark = PropFactory.orthodox_church()
		landmark.position = Vector3(landmark_at.x, 0.0, landmark_at.y)
		add_child(landmark)
		_obstacle_rects.append(landmark_rect.grow(1.5))
	if _layout.get("station", false) and rail_line != INF:
		_build_station(origin, rail_ew, rail_line)
	if not central:
		var well: Destructible = PropFactory.well()
		well.position = Vector3(origin.x, 0.0, origin.y)
		add_child(well)
		_obstacle_rects.append(Rect2(origin - Vector2(2.5, 2.5), Vector2(5.0, 5.0)))
	for side: float in [-1.0, 1.0]:
		_street_lots(origin, along, across, -main_half, -square - 1.0, side, street_half, style)
		_street_lots(origin, along, across, square + 1.0, main_half, side, street_half, style)
		_street_lots(origin, across, along, -cross_half, -square - 1.0, side, street_half, style)
		_street_lots(origin, across, along, square + 1.0, cross_half, side, street_half, style)
	if not central and not small:
		# Dos callejas traseras, paralelas a la calle mayor, con su hilera de casas dando a ella.
		for side: float in [-1.0, 1.0]:
			var lane: Vector2 = origin + across * side * 39.0
			_street_lots(lane, along, across, -52.0, -square - 1.0, -side, 4.0, style)
			_street_lots(lane, along, across, square + 1.0, 52.0, -side, 4.0, style)
			_road(lane - along * 56.0, lane + along * 56.0, 3.4, 1 if style == 0 else 0, Color(0.43, 0.42, 0.4) if style == 0 else Fronts.ground_colors(front)[2].lightened(0.1))
	# Calles, plaza y caminos que salen del pueblo.
	var cobbles: bool = style == 0
	var paving: Color = Color(0.43, 0.42, 0.4) if cobbles else Fronts.ground_colors(front)[2].lightened(0.1)
	_road(origin - along * (main_half + 8.0), origin + along * (main_half + 8.0), street_half - 0.3, 1 if cobbles else 0, paving)
	_road(origin - across * (cross_half + 8.0), origin + across * (cross_half + 8.0), street_half - 0.3, 1 if cobbles else 0, paving)
	_road(origin - along * square, origin + along * square, square, 1 if cobbles else 0, paving)
	for dir: Vector2 in [along, -along, across, -across]:
		var edge: float = main_half if dir.x == 0.0 else cross_half
		_road(origin + dir * (edge + 8.0), origin + dir * _reach(origin, dir))
	# Huertos y corrales detrás de las casas.
	for i in 14:
		var spot: Vector2 = origin + along * _rng.randf_range(-main_half, main_half) + across * (1.0 if _rng.randf() < 0.5 else -1.0) * (street_half + _rng.randf_range(14.0, 22.0))
		if spot.distance_to(origin) < square + 8.0 or not _is_clear(Rect2(spot - Vector2(1.5, 1.5), Vector2(3.0, 3.0))):
			continue
		var plant: Node3D
		match style:
			0:
				plant = PropFactory.apple_tree(_rng.randf_range(4.0, 6.0)) if i % 3 > 0 else PropFactory.fence(8.0)
			1:
				plant = PropFactory.palm(_rng.randf_range(6.0, 9.0))
			_:
				plant = PropFactory.birch(_rng.randf_range(7.0, 10.0)) if i % 3 > 0 else PropFactory.fence(8.0)
		plant.position = Vector3(spot.x, 0.0, spot.y)
		plant.rotation.y = _rng.randf() * TAU
		add_child(plant)
	if cobbles:
		for i in 6:
			var lamp := PropFactory.lamp_post()
			var spot: Vector2 = origin + along * (square + 4.0 + (i / 2) * 22.0) * (1.0 if i % 2 == 0 else -1.0) + across * (street_half + 0.4) * (1.0 if i % 4 < 2 else -1.0)
			if not _is_clear(Rect2(spot - Vector2(0.5, 0.5), Vector2.ONE), false):
				lamp.free()
				continue
			lamp.position = Vector3(spot.x, 0.0, spot.y)
			add_child(lamp)
	_keep_clear.append(Rect2(origin - Vector2(cross_half + 6.0, main_half + 6.0), Vector2(cross_half + 6.0, main_half + 6.0) * 2.0))


## Casas a un lado de una calle, de `from` a `to` metros del centro del pueblo. `along` es la
## dirección de la calle y `across` la perpendicular; `side` (±1), el lado.
func _street_lots(origin: Vector2, along: Vector2, across: Vector2, from: float, to: float, side: float, street_half: float, style: int) -> void:
	var at: float = from + _rng.randf_range(0.0, 2.0)
	while at < to:
		var width: float = _rng.randf_range(6.5, 10.0)
		var depth: float = _rng.randf_range(6.5, 8.5)
		if at + width > to:
			break
		var centre: Vector2 = origin + along * (at + width * 0.5) + across * side * (street_half + 1.5 + depth * 0.5)
		var half: Vector2 = along.abs() * width * 0.5 + across.abs() * depth * 0.5
		var rect := Rect2(centre - half, half * 2.0)
		at += width + (_rng.randf_range(0.6, 2.5) if style == 0 else _rng.randf_range(2.0, 6.0))
		if _rng.randf() < 0.12:
			# Algún callejón entre casas.
			at += 4.5
		if not _is_clear(rect.grow(0.25)) or centre.distance_to(_spawn_point) < SAFE_RADIUS + 8.0:
			continue
		var roll: float = _rng.randf()
		var tall: bool = _rng.randf() < [0.55, 0.35, 0.2][style]
		var house: Destructible
		if roll < 0.12:
			house = PropFactory.bombed_house(Vector3(width, _rng.randf_range(4.2, 5.5), depth), style)
		elif tall:
			house = PropFactory.townhouse(Vector3(width, _rng.randf_range(6.4, 8.0), depth), style)
		elif style == 0:
			house = PropFactory.house(Vector3(width, _rng.randf_range(3.6, 4.8), depth))
		elif style == 1:
			house = PropFactory.desert_house(Vector3(width, _rng.randf_range(3.2, 4.4), depth))
		else:
			house = PropFactory.izba(Vector3(width, _rng.randf_range(3.0, 4.0), depth))
		# La fachada (+Z de la casa) da a la calle.
		var facing: Vector2 = -across * side
		house.position = Vector3(centre.x, 0.0, centre.y)
		house.rotation.y = atan2(facing.x, facing.y)
		add_child(house)
		# Sin holgura: las casas de una calle van casi pared con pared.
		_obstacle_rects.append(rect)


## Estación junto a la vía, del lado del pueblo, con su depósito de agua.
func _build_station(town_at: Vector2, rail_ew: bool, rail_line: float) -> void:
	var toward: float = signf((town_at.y if rail_ew else town_at.x) - rail_line)
	if toward == 0.0:
		toward = 1.0
	var slide: float = (town_at.x if rail_ew else town_at.y) + 24.0
	var centre: Vector2 = Vector2(slide, rail_line + toward * 15.0) if rail_ew else Vector2(rail_line + toward * 15.0, slide)
	var half: Vector2 = Vector2(16.0, 6.0) if rail_ew else Vector2(6.0, 16.0)
	var rect := Rect2(centre - half, half * 2.0)
	if not _is_clear(rect, false):
		return
	var station: Destructible = PropFactory.station()
	station.position = Vector3(centre.x, 0.0, centre.y)
	# La fachada con el andén (+Z) mira a la vía.
	var facing: Vector2 = Vector2(0.0, -toward) if rail_ew else Vector2(-toward, 0.0)
	station.rotation.y = atan2(facing.x, facing.y)
	add_child(station)
	_obstacle_rects.append(rect)
	var tower_at: Vector2 = centre + (Vector2(-26.0, 0.0) if rail_ew else Vector2(0.0, -26.0))
	var tower_rect := Rect2(tower_at - Vector2(5.0, 5.0), Vector2(10.0, 10.0))
	if _is_clear(tower_rect, false):
		var tower: Destructible = StructureFactory.water_tower()
		tower.position = Vector3(tower_at.x, 0.0, tower_at.y)
		add_child(tower)
		_obstacle_rects.append(tower_rect)


## Líneas de trincheras de lado a lado del mapa: tramos de parapeto de tierra en zigzag, con
## pasos entre uno y otro, y el fondo de la zanja detrás.
func _build_trenches(lines: int) -> void:
	var soil: Color = Fronts.ground_colors(GameSession.front)[2]
	var rows: Array = [[15.0], [50.0, -45.0], [72.0, 8.0, -58.0]][clampi(lines, 1, 3) - 1]
	for row: float in rows:
		var z: float = row + _rng.randf_range(-10.0, 10.0)
		var x: float = -178.0 + _rng.randf_range(0.0, 10.0)
		var index: int = 0
		while x < 168.0:
			var length: float = snappedf(_rng.randf_range(16.0, 26.0), 2.0)
			var centre := Vector2(x + length * 0.5, z + (3.0 if index % 2 == 0 else -3.0))
			var rect := Rect2(centre - Vector2(length * 0.5, 2.4), Vector2(length, 4.8))
			if centre.distance_to(_spawn_point) > 34.0 and _is_clear(rect.grow(1.0)):
				var bank: Destructible = PropFactory.earth_bank(length, 1.6, 3.4, soil)
				bank.position = Vector3(centre.x, 0.0, centre.y)
				bank.rotation.y = _rng.randf_range(-0.06, 0.06)
				add_child(bank)
				_obstacle_rects.append(rect.grow(0.8))
				var floor_from := Vector2(x + 1.0, centre.y - 3.3)
				add_child(Ribbon.node(PackedVector2Array([floor_from, floor_from + Vector2(length - 2.0, 0.0)]), 1.3, Ribbon.Y_BANK, Ribbon.strip(soil.darkened(0.25), soil.darkened(0.65), 4, 2.6, 0.5)))
			x += length + _rng.randf_range(11.0, 17.0)
			index += 1


func _spawn_player(spawn: Transform3D) -> void:
	_player = Tank.new()
	_player.name = "PlayerTank"
	_player.is_player = true
	_player.team = GameMode.PLAYER_TEAM
	_player.stats = Fronts.player_stats(GameSession.front, GameSession.faction, GameSession.player_tank_id())
	_player.paint = Fronts.paint(GameSession.front, GameSession.faction, _player.stats.nation)
	_player.transform = spawn
	add_child(_player)


func _build_weather() -> void:
	var weather := Weather.new()
	weather.name = "Weather"
	add_child(weather)
	var options: Array[int] = Fronts.weathers(GameSession.front)
	var kind: int = _mode.forced_weather()
	if kind < 0:
		# El que eligió el jugador al empezar (o -1: aleatorio).
		kind = GameSession.chosen_weather(GameSession.front)
	if GameSession.debug_weather >= 0:
		kind = GameSession.debug_weather
	if kind < 0:
		kind = options[_rng.randi() % options.size()]
	weather.setup(_env, _sky_material, _sun, _player, VectorMaterials.ground(), kind, GameSession.front)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var touch := TouchControls.new()
	layer.add_child(touch)

	var input_source := PlayerInputSource.new()
	input_source.name = "PlayerInputSource"
	input_source.tank = _player
	input_source.touch = touch
	add_child(input_source)

	var radar := Radar.new()
	radar.player = _player
	radar.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	radar.offset_left = -206.0
	radar.offset_right = -18.0
	radar.offset_top = 104.0
	radar.offset_bottom = 292.0
	layer.add_child(radar)

	_hud = Hud.new()
	_hud.tank = _player
	_hud.director = _mode
	_hud.touch = touch
	_hud.input_source = input_source
	_hud.weather = get_node("Weather")
	layer.add_child(_hud)
	_mode.bind_ui(_hud, touch, radar, input_source)

