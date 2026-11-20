class_name Strafe
extends Node3D
## Pasada de ametrallamiento de un caza contra el tanque del jugador. Avisa marcando en el suelo
## un pasillo recto que pasa por donde está el tanque: dos rayas rojas que se cierran hacia el
## centro como cuenta atrás; a los pocos segundos el caza baja, enfila el pasillo y lo barre: una
## hilera doble de impactos lo cose de punta a punta y todo carro del bando atacado que siga
## dentro cuando le llegan las balas pierde blindaje. Se esquiva saliendo de lado.

signal finished

## Largo y ancho del pasillo (m).
const LENGTH: float = 170.0
const WIDTH: float = 12.0
## Segundos entre el aviso y las primeras balas. Un tanque gira despacio: por eso son más que
## los del bombardeo.
const WARNING: float = 5.0
const SPEED: float = 85.0
## Blindaje que quita una pasada a quien pilla dentro. La ametralladora de un caza rara vez
## acababa con un carro: castiga, no mata.
const DAMAGE: float = 30.0
## Altura (m) desde la que empieza a bajar y a la que hace la pasada.
const START_HEIGHT: float = 95.0
const PASS_HEIGHT: float = 24.0
## Las balas caen por delante del morro.
const LEAD: float = 42.0
const SEGMENTS: int = 34
## Cada cuántos metros cae una bala en cada una de las dos hileras, y lo que se separan.
const SPURT_STEP: float = 1.9
const ROW_OFFSET: float = 1.5
const TRACER_SPEED: float = 380.0
## De dónde puede venir: norte, este, sur u oeste (más un pequeño desvío).
const FROM: Array[Vector3] = [Vector3(0.0, 0.0, -1.0), Vector3(1.0, 0.0, 0.0), Vector3(0.0, 0.0, 1.0), Vector3(-1.0, 0.0, 0.0)]
const FROM_KEYS: Array[String] = ["n", "e", "s", "w"]

var hostile_to_player: bool = true
## Rumbo del caza (unitario, en planta) y lado del que viene (índice de FROM).
var direction: Vector3 = Vector3.FORWARD
var from_side: int = 0
var model: String = ""
## Carros alcanzados (lo miran las pruebas).
var hits: int = 0

var _time: float = 0.0
var _right: Vector3 = Vector3.RIGHT
var _plane: SkyWar.SkyPlane
var _sound: FlybySound
var _guns: AudioStreamPlayer3D
var _material: ShaderMaterial
var _strip: MeshInstance3D
var _hit: Dictionary = {}
var _front: float = -INF
var _next_spurt: float = 0.0
var _tracer_due: float = 0.0
var _tracer_color: Color = SkyWar.TRACER_AXIS
var _firing: bool = false
var _spent: bool = false


## `side`: de dónde viene (índice de FROM); -1 lo sortea.
static func launch(host: Node, target: Vector3, enemy_strafe: bool, side: int = -1) -> Strafe:
	var strafe := Strafe.new()
	strafe.hostile_to_player = enemy_strafe
	strafe.from_side = side if side >= 0 else randi() % FROM.size()
	strafe.direction = (-FROM[strafe.from_side]).rotated(Vector3.UP, randf_range(-0.3, 0.3))
	host.add_child(strafe)
	strafe.global_position = Vector3(target.x, 0.0, target.z)
	strafe._build()
	return strafe


## Clave del lado del que viene («n», «e», «s», «w»).
func from_key() -> String:
	return FROM_KEYS[from_side]


## Segundos que faltan para las primeras balas.
func time_left() -> float:
	return maxf(WARNING - _time, 0.0)


## Segundos que faltan para que las balas lleguen a la altura de `point` (0 si ya han pasado).
func time_to(point: Vector3) -> float:
	return maxf(WARNING + (along(point) + LENGTH * 0.5) / SPEED - _time, 0.0)


## ¿Sigue siendo peligroso el pasillo (aviso o pasada en curso)?
func is_live() -> bool:
	return not _spent


## Posición a lo largo del pasillo (0 en el centro, positiva hacia donde va el caza).
func along(point: Vector3) -> float:
	return (point - global_position).dot(direction)


func contains(point: Vector3) -> bool:
	var offset: Vector3 = point - global_position
	return absf(offset.dot(direction)) <= LENGTH * 0.5 and absf(offset.dot(_right)) <= WIDTH * 0.5


func _build() -> void:
	add_to_group(&"strafes")
	_right = Vector3(direction.z, 0.0, -direction.x)
	var color := Color(1.0, 0.1, 0.05)
	_build_strip(color)
	add_to_group(&"radar_marks")
	set_meta("radar_color", color)
	set_meta("radar_shape", "strip")
	set_meta("radar_along", direction)
	set_meta("radar_length", LENGTH)
	# El caza: uno del bando contrario, de los que de verdad atacaban a ras de suelo.
	var faction: int = GameSession.enemy_faction() if hostile_to_player else GameSession.faction
	var choice: Array = SkyWar.pick_model(GameSession.front, faction, ["fighter", "attack"])
	model = choice[0]
	_plane = SkyWar.make_plane(GameSession.front, faction, choice)
	add_child(_plane)
	_plane.top_level = true
	_tracer_color = SkyWar.TRACER_ALLIES if faction == Fronts.Faction.ALLIES else SkyWar.TRACER_AXIS
	if faction == Fronts.Faction.ALLIES and GameSession.front == Fronts.Id.KURSK:
		_tracer_color = SkyWar.TRACER_SOVIET
	_sound = FlybySound.attach(_plane, Sfx.PLANE_FIGHTER, 17.0, 60.0, 900.0, 1.05)
	_guns = AudioStreamPlayer3D.new()
	_guns.stream = Sfx.AA_FIRE
	_guns.bus = AudioSetup.SFX
	_guns.unit_size = 70.0
	_guns.max_distance = 900.0
	_guns.volume_db = 12.0
	_guns.pitch_scale = 1.12
	_plane.add_child(_guns)
	_place_plane()


## El pasillo, pegado al terreno: una tira partida a lo largo que sigue las lomas.
func _build_strip(color: Color) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in SEGMENTS + 1:
		var s: float = -LENGTH * 0.5 + LENGTH * i / SEGMENTS
		for j in 3:
			var point: Vector3 = global_position + direction * s + _right * WIDTH * 0.5 * (j - 1.0)
			tool.set_uv(Vector2(j * 0.5, float(i) / SEGMENTS))
			tool.add_vertex(Vector3(point.x, Terrain.height(point.x, point.z) + 0.14, point.z) - global_position)
	for i in SEGMENTS:
		for j in 2:
			var a: int = i * 3 + j
			var b: int = a + 3
			for index: int in [a, b, a + 1, a + 1, b, b + 1]:
				tool.add_index(index)
	_material = ShaderMaterial.new()
	_material.shader = load("res://shaders/strafe_lane.gdshader")
	_material.set_shader_parameter("color", color)
	_material.set_shader_parameter("lane", Vector2(WIDTH, LENGTH))
	_material.set_shader_parameter("warning", WARNING)
	_material.set_shader_parameter("speed", SPEED)
	_material.render_priority = 1
	_strip = MeshInstance3D.new()
	_strip.mesh = tool.commit()
	_strip.material_override = _material
	_strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_strip)


## Por dónde va el morro del caza a lo largo del pasillo en el instante `time`.
func _plane_along(time: float) -> float:
	return -LENGTH * 0.5 - LEAD - SPEED * (WARNING - time)


func _place_plane() -> void:
	var s: float = _plane_along(_time)
	var height: float = PASS_HEIGHT
	var climb: float = 0.0
	if _time < WARNING:
		# Baja en picado suave hasta la altura de la pasada.
		var t: float = _time / WARNING
		height = lerpf(START_HEIGHT, PASS_HEIGHT, t * t * (3.0 - 2.0 * t))
		climb = (PASS_HEIGHT - START_HEIGHT) * 6.0 * t * (1.0 - t) / WARNING
	else:
		# Acabada la pasada, tira de la palanca y se va hacia arriba.
		var after: float = maxf(s + LEAD - LENGTH * 0.5, 0.0) / SPEED
		height = PASS_HEIGHT + 14.0 * after * after
		climb = 28.0 * after
	var velocity: Vector3 = direction * SPEED + Vector3.UP * climb
	_plane.global_position = global_position + direction * s + Vector3.UP * height
	_plane.look_at(_plane.global_position + velocity, Vector3.UP)
	_sound.source_velocity = velocity


func _process(delta: float) -> void:
	_time += delta
	_place_plane()
	var front: float = _plane_along(_time) + LEAD
	if not _spent:
		_material.set_shader_parameter("elapsed", _time)
		_material.set_shader_parameter("swept", clampf(front / LENGTH + 0.5, 0.0, 1.0))
	if _time >= WARNING and not _spent:
		if not _firing:
			_firing = true
			_front = -LENGTH * 0.5
			_next_spurt = _front
			_guns.play()
		_fire(minf(front, LENGTH * 0.5), delta)
		if front >= LENGTH * 0.5:
			_spent = true
			_firing = false
			_guns.stop()
			Sfx.play_at(self, Sfx.AA_TAIL, _plane.global_position, 12.0, 1.1)
			_strip.visible = false
			remove_from_group(&"radar_marks")
	if _time > WARNING + LENGTH / SPEED + 1.2:
		_sound.fade_out()
	if _time > WARNING + LENGTH / SPEED + 4.0:
		finished.emit()
		queue_free()


## Las balas avanzan hasta `front`: dos hileras de impactos que cosen el suelo, las trazadoras
## que bajan desde las alas y daño a los carros a los que les llegan dentro del pasillo.
func _fire(front: float, delta: float) -> void:
	var fx: Fx = Fx.on(self)
	while _next_spurt <= front:
		for side: float in [-1.0, 1.0]:
			fx.bullet_ground(global_position + direction * (_next_spurt + randf_range(-0.5, 0.5)) + _right * (side * ROW_OFFSET + randf_range(-0.45, 0.45)))
		_next_spurt += SPURT_STEP
	# Una de cada pocas balas es trazadora: salen de las dos alas y convergen en el suelo.
	_tracer_due += delta * 26.0
	while _tracer_due >= 1.0:
		_tracer_due -= 1.0
		var side: float = 1.0 if randf() < 0.5 else -1.0
		var muzzle: Vector3 = _plane.global_position + _right * side * 2.4 - Vector3.UP * 0.5 + direction * 1.5
		var target: Vector3 = global_position + direction * (front + randf_range(-4.0, 2.0)) + _right * (side * ROW_OFFSET + randf_range(-0.6, 0.6))
		target.y = Terrain.height(target.x, target.z)
		fx.strafe_tracer(muzzle, target, TRACER_SPEED, _tracer_color)
		fx.glow(Fx.Glow.STAR, muzzle, Vector3.ZERO, 1.1, 0.05, Fx.FLASH, 0.8)
	var team: int = GameMode.PLAYER_TEAM if hostile_to_player else GameMode.ENEMY_TEAM
	for node in get_tree().get_nodes_in_group(&"tanks"):
		var tank := node as Tank
		if tank == null or tank.is_destroyed or tank.team != team or _hit.has(tank):
			continue
		var offset: Vector3 = tank.global_position - global_position
		var s: float = offset.dot(direction)
		if s > front or s <= _front or absf(offset.dot(_right)) > WIDTH * 0.5 + 0.6:
			continue
		_hit[tank] = true
		hits += 1
		tank.health.apply_damage(DAMAGE, null)
		Sfx.play_at(self, Sfx.HIT_TANK, tank.global_position, 6.0)
		for i in 6:
			fx.bullet_armor(tank.global_position + Vector3(randf_range(-1.3, 1.3), randf_range(1.3, 2.3), randf_range(-1.6, 1.6)))
	_front = front
