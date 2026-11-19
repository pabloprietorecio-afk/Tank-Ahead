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
	_build_ground()
	_build_walls()
	if _mode.wants_scenery() and not GameSession.debug_bare:
		_build_scenery()
	_spawn_player(spawn)
	Fx.on(self).player = _player
	_mode.is_free_point = func(p: Vector2) -> bool:
		for rect in _obstacle_rects:
			if rect.has_point(p):
				return false
		return true
	add_child(_mode)
	_build_weather()
	if _mode.wants_scenery() and not GameSession.debug_bare:
		# Aviones de paso, antiaérea y algún derribo lejano: solo ambiente.
		var sky := SkyWar.new()
		sky.name = "SkyWar"
		sky.front = GameSession.front
		sky.is_free_point = _mode.is_free_point
		add_child(sky)
	if _mode.wants_pickups():
		var spawner := PickupSpawner.new()
		spawner.name = "PickupSpawner"
		spawner.player = _player
		spawner.is_free_point = _mode.is_free_point
		add_child(spawner)
	_build_ui()
	var voice := VoiceManager.new()
	voice.name = "VoiceManager"
	voice.player = _player
	add_child(voice)
	var music := AudioSetup.music_player("res://assets/music/battle_theme.ogg")
	music.volume_db = -6.0
	add_child(music)
	_mode.start(_player, self)


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
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(ARENA_HALF * 2.0 + 400.0, ARENA_HALF * 2.0 + 400.0)
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
	box.size = Vector3(ARENA_HALF * 2.0 + 20.0, 100.0, ARENA_HALF * 2.0 + 20.0)
	shape.shape = box
	shape.position.y = -50.0
	body.add_child(shape)
	add_child(body)


func _add_wall(center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.position = center
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.add_child(VectorMaterials.make_box(size, Color(0.45, 0.43, 0.4), 2, 2.0))
	add_child(body)


## Límite infranqueable para los tanques: una barrera alta e invisible sobre cada muro, en una
## capa que solo ellos tocan (los disparos y los aviones la atraviesan).
func _add_boundary(center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = Tank.LAYER_BOUNDARY
	body.collision_mask = 0
	body.position = center
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	add_child(body)


func _build_walls() -> void:
	var length: float = ARENA_HALF * 2.0
	for side in [-1.0, 1.0]:
		_add_boundary(Vector3(0.0, 40.0, side * (ARENA_HALF + 2.0)), Vector3(length + 20.0, 80.0, 6.0))
		_add_boundary(Vector3(side * (ARENA_HALF + 2.0), 40.0, 0.0), Vector3(6.0, 80.0, length + 20.0))
	var height: float = 2.5
	var thickness: float = 2.0
	_add_wall(Vector3(0.0, height * 0.5, -ARENA_HALF), Vector3(length, height, thickness))
	_add_wall(Vector3(0.0, height * 0.5, ARENA_HALF), Vector3(length, height, thickness))
	_add_wall(Vector3(-ARENA_HALF, height * 0.5, 0.0), Vector3(thickness, height, length))
	_add_wall(Vector3(ARENA_HALF, height * 0.5, 0.0), Vector3(thickness, height, length))


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
	# Relieve lejano fuera de la arena.
	var desert: bool = front == Fronts.Id.AFRICA
	for i in 14:
		var angle: float = TAU * i / 14.0 + _rng.randf_range(-0.1, 0.1)
		var height: float = _rng.randf_range(12.0, 30.0) if desert or front == Fronts.Id.KURSK else _rng.randf_range(20.0, 45.0)
		var base_radius: float = _rng.randf_range(45.0, 70.0)
		# Toda la falda queda fuera del muro (que es cuadrado: en las esquinas está más lejos),
		# para que ninguna montaña tape objetivos ni sirva de rampa para salir del mapa.
		var toward_wall: float = maxf(absf(cos(angle)), absf(sin(angle)))
		var dist: float = (ARENA_HALF + base_radius + 12.0) / toward_wall + _rng.randf_range(0.0, 60.0)
		var mountain := PropFactory.mountain(base_radius, height, _rng.randi_range(6, 9))
		mountain.position = Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
		mountain.rotation.y = _rng.randf() * TAU
		add_child(mountain)
		_far_mountains.append([mountain, base_radius])
	# Lo que da forma al campo (río, vía, pueblo, trincheras) va lo primero: lo demás se
	# reparte por los huecos que deja.
	_build_layout()
	# Lomas suaves (dunas tendidas en el desierto): relieve por el que los tanques sí suben. Van
	# antes que el decorado suelto, que nunca se coloca encima de ellas.
	for i in int(_layout.get("ridge", 0)):
		var radius: float = _rng.randf_range(30.0, 42.0)
		var pos := _free_spot(radius)
		if pos != Vector2.INF:
			add_child(Terrain.add_mound(pos, radius, VectorMaterials.ground(), _rng.randf()))
			_obstacle_rects.append(Rect2(pos - Vector2.ONE * (radius + 2.0), Vector2.ONE * (radius + 2.0) * 2.0))
	for i in int(_layout.get("mounds", 4 if desert else 3)):
		var radius: float = _rng.randf_range(21.0, 30.0)
		var pos := _free_spot(radius)
		if pos != Vector2.INF:
			add_child(Terrain.add_mound(pos, radius, VectorMaterials.ground(), _rng.randf()))
			_obstacle_rects.append(Rect2(pos - Vector2.ONE * (radius + 2.0), Vector2.ONE * (radius + 2.0) * 2.0))
	# Colinas o dunas dentro.
	for i in int(_layout.get("hills", 5 if desert else 3)):
		var radius: float = _rng.randf_range(10.0, 18.0)
		var pos := _free_spot(radius)
		if pos != Vector2.INF:
			_place(PropFactory.mountain(radius, _rng.randf_range(4.0, 7.0) if desert else _rng.randf_range(7.0, 13.0), 10 if desert else 7), pos, radius, _rng.randf() * TAU)
	match front:
		Fronts.Id.AFRICA:
			_scenery_africa()
		Fronts.Id.KURSK:
			_scenery_kursk()
		_:
			_scenery_normandy()
	# Ruinas con bidones, rocas y depósitos de combustible abandonados en todos los frentes.
	for r in 4:
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
			var barrel := PropFactory.barrel()
			barrel.position = Vector3(pos.x + _rng.randf_range(-5.0, 5.0), 0.0, pos.y + _rng.randf_range(2.0, 5.0))
			add_child(barrel)
	# Edificios con premio (anillo verde en el radar).
	var prizes: Array[Callable] = [StructureFactory.radio_mast, StructureFactory.water_tower, StructureFactory.flak_gun, StructureFactory.flak_gun, StructureFactory.command_tent]
	for factory in prizes:
		var pos := _free_spot(6.0)
		if pos != Vector2.INF:
			_place(factory.call(), pos, 6.0, _rng.randf() * TAU)
	for i in int(_layout.get("scatter", 25 if desert else 12)):
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


func _scenery_normandy() -> void:
	for v in int(_layout.get("villages", 2)):
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
			var lamp := PropFactory.lamp_post()
			lamp.position = Vector3(center.x + _rng.randf_range(-20.0, 20.0), 0.0, center.y + _rng.randf_range(-20.0, 20.0))
			add_child(lamp)
	# Setos del bocage.
	for i in int(_layout.get("hedges", 12)):
		var length: float = _rng.randf_range(18.0, 34.0)
		var pos := _free_spot(length * 0.5)
		if pos != Vector2.INF:
			_place(PropFactory.hedgerow(length), pos, length * 0.5, round(_rng.randf() * 2.0) * PI * 0.5)
	# Huertos de manzanos.
	for o in int(_layout.get("woods", 5)):
		var center := _free_spot(12.0)
		if center != Vector2.INF:
			_scatter(center, _rng.randi_range(5, 9), 10.0, func() -> Node3D: return PropFactory.apple_tree(_rng.randf_range(4.0, 6.0)),
					(func(burning: bool) -> Node3D: return PropFactory.burnt_tree(_rng.randf_range(4.0, 6.0), 0, burning)) if o < 2 else Callable())
	for f in 6:
		var pos := _free_spot(6.0)
		if pos != Vector2.INF:
			_place(PropFactory.fence(12.0), pos, 6.0, _rng.randf() * TAU)


func _scenery_africa() -> void:
	for v in int(_layout.get("villages", 2)):
		# Sitio para el pueblo y para su palmeral, que va a un lado.
		var center := _free_spot(44.0)
		if center == Vector2.INF:
			continue
		_village(center, 4, func() -> Node3D: return PropFactory.desert_house(Vector3(_rng.randf_range(5.0, 8.0), _rng.randf_range(3.0, 4.5), _rng.randf_range(5.0, 8.0))),
				func() -> Node3D: return PropFactory.bombed_house(Vector3(_rng.randf_range(5.0, 8.0), _rng.randf_range(3.0, 4.5), _rng.randf_range(5.0, 8.0)), 1))
		_scatter(center + Vector2(32.0, 0.0), 6, 8.0, func() -> Node3D: return PropFactory.palm(_rng.randf_range(7.0, 10.0)),
				func(burning: bool) -> Node3D: return PropFactory.burnt_tree(_rng.randf_range(7.0, 10.0), 2, burning))
	for i in 10:
		var pos := _free_spot(5.0)
		if pos != Vector2.INF:
			_place(PropFactory.sandbags(_rng.randf_range(6.0, 10.0)), pos, 5.0, _rng.randf() * TAU)
	for i in int(_layout.get("woods", 6)):
		var pos := _free_spot(4.0)
		if pos != Vector2.INF:
			_scatter(pos, 3, 4.0, func() -> Node3D: return PropFactory.palm(_rng.randf_range(6.0, 9.0)))


func _scenery_kursk() -> void:
	for v in int(_layout.get("villages", 2)):
		var center := _free_spot(30.0)
		if center == Vector2.INF:
			continue
		_village(center, 5, func() -> Node3D: return PropFactory.izba(Vector3(_rng.randf_range(5.0, 7.0), _rng.randf_range(3.0, 4.0), _rng.randf_range(6.0, 8.0))),
				func() -> Node3D: return PropFactory.bombed_house(Vector3(_rng.randf_range(5.0, 7.0), _rng.randf_range(3.0, 4.0), _rng.randf_range(6.0, 8.0)), 2))
		for f in 3:
			var fence := PropFactory.fence(10.0)
			fence.position = Vector3(center.x + _rng.randf_range(-25.0, 25.0), 0.0, center.y + _rng.randf_range(-25.0, 25.0))
			fence.rotation.y = _rng.randf() * TAU
			add_child(fence)
	for g in int(_layout.get("woods", 7)):
		var center := _free_spot(12.0)
		if center != Vector2.INF:
			_scatter(center, _rng.randi_range(5, 9), 10.0, func() -> Node3D: return PropFactory.birch(_rng.randf_range(7.0, 11.0)),
					(func(burning: bool) -> Node3D: return PropFactory.burnt_tree(_rng.randf_range(7.0, 11.0), 1, burning)) if g < 2 else Callable())
	for i in 16:
		var pos := _free_spot(3.0)
		if pos != Vector2.INF:
			_place(PropFactory.haystack(), pos, 3.0)
	# Líneas de erizos antitanque.
	for line in 4:
		var start := _free_spot(14.0)
		if start == Vector2.INF:
			continue
		var dir := Vector2.from_angle(_rng.randf() * TAU)
		for i in 6:
			var p: Vector2 = start + dir * (i - 2.5) * 4.5
			var hog := PropFactory.hedgehog()
			hog.position = Vector3(p.x, 0.0, p.y)
			hog.rotation.y = _rng.randf() * TAU
			add_child(hog)
		_obstacle_rects.append(Rect2(start - Vector2(15.0, 15.0), Vector2(30.0, 30.0)))


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

