class_name SkyWar
extends Node3D
## La guerra en el cielo, de ambiente: formaciones de aviones de la época que cruzan muy por
## encima del campo con su ruido de motores, la antiaérea del bando contrario que les dispara
## (trazadoras que suben, fogonazo, nubecilla negra y el estampido que llega con retraso),
## duelos de artillería más allá del horizonte que encienden las nubes y, de vez en cuando, un
## avión tocado que cae envuelto en humo y se estrella: unas veces fuera del campo y otras
## dentro, a la vista, en un sitio despejado y lejos de los tanques (y si alguno se le acerca
## mientras cae, se desvía). También cazas y aviones de asalto en vuelo rasante, salvas de
## cohetes y bengalas. No afecta a la partida: nada de esto hace daño ni da puntos.

## Tipos de aparato: envergadura y largo (m), motores, velocidad de paso (m/s) y altura (m).
const TYPES: Dictionary = {
	"fighter": {"span": 11.0, "length": 9.5, "engines": 1, "speed": 95.0, "height": Vector2(110.0, 150.0), "group": Vector2i(2, 4)},
	"attack": {"span": 14.0, "length": 11.5, "engines": 1, "speed": 78.0, "height": Vector2(100.0, 140.0), "group": Vector2i(3, 3)},
	"medium": {"span": 22.0, "length": 16.5, "engines": 2, "speed": 70.0, "height": Vector2(150.0, 190.0), "group": Vector2i(3, 3)},
	"heavy": {"span": 31.0, "length": 22.5, "engines": 4, "speed": 64.0, "height": Vector2(180.0, 220.0), "group": Vector2i(3, 5)},
}

## Qué volaba en cada frente: [modelo, tipo, peso]. En Normandía (1944) el cielo era aliado y
## la Luftwaffe apenas aparecía; en África y en Kursk volaban los dos bandos.
const AIRCRAFT: Dictionary = {
	Fronts.Id.NORMANDY: {
		Fronts.Faction.ALLIES: [["P-51 MUSTANG", "fighter", 3.0], ["P-47 THUNDERBOLT", "fighter", 2.0], ["HAWKER TYPHOON", "attack", 2.0], ["B-26 MARAUDER", "medium", 2.0], ["B-17", "heavy", 2.0]],
		Fronts.Faction.AXIS: [["BF 109", "fighter", 2.0], ["FW 190", "fighter", 2.0], ["FW 190 F", "attack", 1.0], ["JU 88", "medium", 0.5]],
	},
	Fronts.Id.AFRICA: {
		Fronts.Faction.ALLIES: [["HURRICANE", "fighter", 3.0], ["SPITFIRE", "fighter", 2.0], ["P-40 KITTYHAWK", "fighter", 2.0], ["HURRICANE IID", "attack", 1.0], ["BLENHEIM", "medium", 2.0]],
		Fronts.Faction.AXIS: [["BF 109", "fighter", 3.0], ["JU 87 STUKA", "attack", 3.0], ["JU 88", "medium", 2.0]],
	},
	Fronts.Id.KURSK: {
		Fronts.Faction.ALLIES: [["IL-2 SHTURMOVIK", "attack", 4.0], ["YAK-9", "fighter", 2.0], ["LA-5", "fighter", 2.0], ["PE-2", "medium", 2.0]],
		Fronts.Faction.AXIS: [["JU 87 STUKA", "attack", 3.0], ["HE 111", "medium", 2.0], ["BF 109", "fighter", 2.0], ["FW 190", "fighter", 2.0]],
	},
}
## Probabilidad de que la formación que pasa sea aliada, por frente.
const ALLIED_SHARE: Array[float] = [0.85, 0.5, 0.5]
## Pintura por bando y frente: [lomo, panza].
const PAINT: Dictionary = {
	Fronts.Faction.ALLIES: [[Color(0.32, 0.35, 0.22), Color(0.6, 0.63, 0.62)], [Color(0.62, 0.52, 0.36), Color(0.5, 0.6, 0.7)], [Color(0.25, 0.33, 0.2), Color(0.5, 0.62, 0.72)]],
	Fronts.Faction.AXIS: [[Color(0.36, 0.4, 0.42), Color(0.55, 0.65, 0.72)], [Color(0.7, 0.6, 0.4), Color(0.55, 0.65, 0.75)], [Color(0.3, 0.36, 0.3), Color(0.55, 0.65, 0.72)]],
}

const FIELD: float = 215.0
const PASS_INTERVAL: Vector2 = Vector2(6.0, 13.0)
const DISTANT_INTERVAL: Vector2 = Vector2(1.4, 4.0)
const DOWN_CHANCE: float = 0.6
## Parte de las pasadas de cazas y aviones de asalto que van en vuelo rasante, y a qué altura (m).
const LOW_SHARE: float = 0.65
const LOW_HEIGHT: Vector2 = Vector2(48.0, 68.0)
## Parte de los derribos que caen dentro del campo, a la vista del jugador.
const INSIDE_SHARE: float = 0.6
## Un avión solo cae dentro si su punto de caída queda a esta distancia (m) de todo tanque; y
## mientras cae se aparta de los que se le acerquen a menos de AVOID_RADIUS.
const CRASH_CLEARANCE: float = 30.0
const AVOID_RADIUS: float = 20.0
## A menos de esto de un tanque, el derribo cuenta como caído encima (debe ser siempre 0).
const HIT_RADIUS: float = 8.0
## Restos de avión que se dejan en el campo a la vez (los más viejos se retiran).
const MAX_WRECKS: int = 4
## Parte de las formaciones de bombarderos (y de aviones de asalto que no van rasantes) que
## sueltan sus bombas al pasar. Caen siempre lejos, fuera del campo: como mínimo a BOMB_MARGIN
## metros del muro.
const BOMB_SHARE: float = 0.7
const BOMB_MARGIN: float = 90.0
const GRAVITY: float = 9.8
## Velocidad de las trazadoras antiaéreas (m/s) y color según quién dispara (lineal).
const TRACER_SPEED: float = 240.0
const TRACER_AXIS := Color(1.0, 0.62, 0.2)
const TRACER_ALLIES := Color(1.0, 0.2, 0.1)
const TRACER_SOVIET := Color(0.45, 1.0, 0.35)

var front: int = Fronts.Id.NORMANDY
## Aviones derribados que han caído dentro del campo (debe ser siempre 0; lo miran las pruebas).
var crashes_inside: int = 0
var crashes: int = 0
## Derribos caídos encima de un tanque (debe ser siempre 0; lo miran las pruebas).
var crashes_on_tanks: int = 0
## Bombas soltadas por las formaciones y cuántas han caído dentro del campo (debe ser siempre 0).
var bombs: int = 0
var bombs_inside: int = 0
## Callable(Vector2) -> bool: punto del campo libre de edificios y zonas reservadas.
var is_free_point: Callable = Callable()
var _wrecks: Array = []
## Última formación lanzada (para pruebas y capturas).
var last_model: String = ""

var _pass_timer: float = 12.0
var _distant_timer: float = 6.0
var _formations: Array[Dictionary] = []


func _process(delta: float) -> void:
	# En la fase antiaérea de supervivencia (cámara lenta) el cielo ya tiene lo suyo.
	if Engine.time_scale < 0.99:
		return
	_pass_timer -= delta
	if _pass_timer <= 0.0:
		_pass_timer = randf_range(PASS_INTERVAL.x, PASS_INTERVAL.y)
		launch()
	_distant_timer -= delta
	if _distant_timer <= 0.0:
		_distant_timer = randf_range(DISTANT_INTERVAL.x, DISTANT_INTERVAL.y)
		var roll: float = randf()
		if roll < 0.45:
			distant_guns()
		elif roll < 0.7:
			_distant_barrage()
		elif roll < 0.88:
			rocket_salvo()
		else:
			flare()
	for formation in _formations.duplicate():
		_update_formation(formation, delta)


## Lanza una formación. Sin argumentos se sortean bando y modelo según el frente.
## `low`: 1 fuerza el vuelo rasante, 0 lo impide y -1 lo sortea (solo cazas y aviones de asalto).
func launch(faction: int = -1, choice: int = -1, flak: bool = true, doomed: int = -1, low: int = -1) -> Dictionary:
	if faction < 0:
		faction = Fronts.Faction.ALLIES if randf() < ALLIED_SHARE[front] else Fronts.Faction.AXIS
	var options: Array = AIRCRAFT[front][faction]
	if choice < 0:
		var total: float = 0.0
		for option in options:
			total += option[2]
		var roll: float = randf() * total
		for i in options.size():
			roll -= options[i][2]
			if roll <= 0.0:
				choice = i
				break
	var model: Array = options[clampi(choice, 0, options.size() - 1)]
	var spec: Dictionary = TYPES[model[1]]
	last_model = model[0]
	var heading: float = randf() * TAU
	var dir := Vector3(sin(heading), 0.0, cos(heading))
	var right := Vector3(dir.z, 0.0, -dir.x)
	var height: float = randf_range(spec["height"].x, spec["height"].y)
	var rasant: bool = spec["engines"] == 1 and (low == 1 or (low < 0 and randf() < LOW_SHARE))
	if rasant:
		height = randf_range(LOW_HEIGHT.x, LOW_HEIGHT.y)
	# Los rasantes cruzan por encima mismo del campo; los altos pueden pasar más de lado.
	var aside: float = randf_range(-70.0, 70.0) if rasant else randf_range(-140.0, 140.0)
	var lead_pos: Vector3 = -dir * 540.0 + right * aside + Vector3.UP * height
	var count: int = randi_range(spec["group"].x, spec["group"].y)
	var planes: Array[SkyPlane] = []
	var paint: Array = PAINT[faction][front]
	for i in count:
		var plane := SkyPlane.new()
		add_child(plane)
		plane.build(model[0], spec, paint[0], paint[1], faction)
		# Formación en cuña: el jefe delante y los demás escalonados a los lados.
		var rank: int = (i + 1) / 2
		var side: float = -1.0 if i % 2 == 1 else 1.0
		var gap: float = spec["span"] * 1.6
		plane.global_position = lead_pos - dir * rank * gap * 0.9 + right * side * rank * gap + Vector3.UP * rank * 2.0
		plane.velocity = dir * spec["speed"]
		plane.look_at(plane.global_position + dir, Vector3.UP)
		planes.append(plane)
	var sound_stream: AudioStream = Sfx.PLANE_FIGHTER if spec["engines"] == 1 else Sfx.PLANE_BOMBER
	var sound := FlybySound.attach(planes[0], sound_stream, 7.0 + count + (5.0 if rasant else 0.0), 60.0, 900.0, 1.0 if spec["engines"] < 4 else 0.85)
	sound.source_velocity = planes[0].velocity
	if doomed < 0:
		doomed = randi() % count if flak and randf() < DOWN_CHANCE else -1
	# Dos cañones antiaéreos ligeros, fuera del campo y a los lados de la ruta, le tiran trazadoras.
	var guns: Array[Vector3] = []
	for side in [-1.0, 1.0]:
		guns.append(right * (lead_pos.dot(right) + side * randf_range(90.0, 180.0)) + dir * randf_range(-120.0, 120.0))
	for i in guns.size():
		var edge: float = maxf(absf(guns[i].x), absf(guns[i].z))
		if edge < FIELD + 30.0:
			guns[i] *= (FIELD + 30.0) / maxf(edge, 1.0)
	var formation: Dictionary = {
		"planes": Array(planes), "dir": dir, "flak": flak, "flak_timer": randf_range(0.5, 1.5), "sound": sound,
		"guns": guns, "burst_timer": randf_range(0.2, 1.0), "burst_left": 0, "burst_gun": 0, "burst_due": 0.0,
		"doomed": planes[doomed] if doomed >= 0 and doomed < count else null, "doom_at": randf_range(-230.0, 40.0), "faction": faction,
		"inside": randf() < INSIDE_SHARE, "low": rasant,
		"bombs": not rasant and model[1] != "fighter" and randf() < BOMB_SHARE,
	}
	_formations.append(formation)
	return formation


func _update_formation(formation: Dictionary, delta: float) -> void:
	# Los aviones se liberan solos al estrellarse: primero se quitan de la lista los que ya no existen.
	var planes: Array = formation["planes"]
	for i in range(planes.size() - 1, -1, -1):
		if not is_instance_valid(planes[i]):
			planes.remove_at(i)
	var dir: Vector3 = formation["dir"]
	var alive: int = planes.size()
	var lead: SkyPlane = null
	for plane: SkyPlane in planes:
		if not plane.falling:
			lead = plane
			break
	if alive == 0:
		_formations.erase(formation)
		return
	if lead == null:
		return
	# Distancia recorrida respecto al punto más cercano al centro del campo.
	var along: float = lead.global_position.dot(dir)
	if along > 560.0:
		for plane: SkyPlane in planes:
			if not plane.falling:
				plane.queue_free()
		return
	if along > 430.0 and is_instance_valid(formation["sound"]):
		(formation["sound"] as FlybySound).fade_out()
	if formation["bombs"] and along > -60.0:
		_bomb_run(formation, planes)
	if not formation["flak"] or absf(along) > 330.0:
		return
	_fire_tracers(formation, planes, delta)
	formation["flak_timer"] -= delta
	if formation["flak_timer"] <= 0.0:
		formation["flak_timer"] = randf_range(0.25, 0.9)
		var target: SkyPlane = planes.pick_random()
		if not target.falling:
			var miss := Vector3(randf_range(-28.0, 28.0), randf_range(-16.0, 16.0), randf_range(-28.0, 28.0))
			FlakBurst.spawn(self, target.global_position + target.velocity * 0.4 + miss, 1.0)
	var doomed: Variant = formation["doomed"]
	if doomed != null and is_instance_valid(doomed) and along >= formation["doom_at"] and not doomed.falling:
		var plane: SkyPlane = doomed
		# Se le derriba cuando va a caer fuera del campo o, si le toca caer dentro, en un sitio
		# despejado y lejos de todos los tanques: nunca encima de ellos.
		var impact: Vector3 = plane.impact_point()
		var outside: bool = absf(impact.x) > FIELD + 25.0 or absf(impact.z) > FIELD + 25.0
		if (outside and not (formation["inside"] and along < -60.0)) or (formation["inside"] and crash_site_ok(impact)):
			FlakBurst.spawn(self, plane.global_position, 1.6)
			plane.shoot_down(self)
			formation["doomed"] = null


## Los bombarderos sueltan su carga sobre el terreno lejano: cada avión, una ristra de bombas
## que caen con su parábola y revientan más allá del campo. Solo cuando todas van a caer fuera.
func _bomb_run(formation: Dictionary, planes: Array) -> void:
	var targets: Array = []
	for plane: SkyPlane in planes:
		if plane.falling:
			continue
		var fall: float = sqrt(2.0 * maxf(plane.global_position.y, 1.0) / GRAVITY)
		for n in 3:
			var hit: Vector3 = plane.global_position + plane.velocity * (fall + 0.35 * n)
			if maxf(absf(hit.x), absf(hit.z)) < FIELD + BOMB_MARGIN:
				return
			targets.append([plane, 0.35 * n])
	formation["bombs"] = false
	for target: Array in targets:
		var plane: SkyPlane = target[0]
		get_tree().create_timer(target[1]).timeout.connect(func() -> void:
			if is_inside_tree() and is_instance_valid(plane) and not plane.falling:
				Bomb.drop(self, plane.global_position - Vector3.UP * 1.5, plane.velocity))


func _on_bomb(point: Vector3) -> void:
	bombs += 1
	if maxf(absf(point.x), absf(point.z)) < FIELD:
		bombs_inside += 1


## ¿Puede caer un avión en ese punto del campo? Dentro del muro, en suelo libre (ni edificios
## ni zonas de misión ni agua) y con todos los tanques lejos.
func crash_site_ok(point: Vector3) -> bool:
	if absf(point.x) > FIELD - 35.0 or absf(point.z) > FIELD - 35.0:
		return false
	if is_free_point.is_valid() and not is_free_point.call(Vector2(point.x, point.z)):
		return false
	if Water.deep_at(point.x, point.z, 4.0):
		return false
	return nearest_tank(point) >= CRASH_CLEARANCE


## Distancia (en planta) del punto al tanque más cercano; INF si no hay ninguno.
func nearest_tank(point: Vector3) -> float:
	var best: float = INF
	for node in get_tree().get_nodes_in_group(&"tanks"):
		var tank := node as Node3D
		if tank != null:
			best = minf(best, Vector2(tank.global_position.x - point.x, tank.global_position.z - point.z).length())
	return best


## Modelo [nombre, tipo] de un bando para los tipos pedidos, por orden de preferencia. Si en
## ese frente el bando no tiene ninguno de ese tipo, se toma el de otro frente.
static func pick_model(battle_front: int, faction: int, wanted: Array[String]) -> Array:
	for type in wanted:
		var found: Array = []
		for option in AIRCRAFT[battle_front][faction]:
			if option[1] == type:
				found.append(option)
		if found.is_empty():
			for other in AIRCRAFT:
				for option in AIRCRAFT[other][faction]:
					if option[1] == type:
						found.append(option)
		if not found.is_empty():
			return found.pick_random()
	return AIRCRAFT[battle_front][faction][0]


## Avión ya construido con la pintura de su bando en ese frente (sin añadir al árbol).
static func make_plane(battle_front: int, faction: int, model: Array) -> SkyPlane:
	var plane := SkyPlane.new()
	var paint: Array = PAINT[faction][battle_front]
	plane.build(model[0], TYPES[model[1]], paint[0], paint[1], faction)
	return plane


## Ráfagas de trazadoras de los cañones antiaéreos ligeros: suben hacia la formación, apuntando
## por delante de un avión y casi siempre fallando.
func _fire_tracers(formation: Dictionary, planes: Array, delta: float) -> void:
	if formation["burst_left"] <= 0:
		formation["burst_timer"] -= delta
		if formation["burst_timer"] > 0.0:
			return
		formation["burst_timer"] = randf_range(0.5, 1.6)
		formation["burst_left"] = randi_range(4, 9)
		formation["burst_gun"] = randi() % 2
		formation["burst_due"] = 0.0
	formation["burst_due"] -= delta
	if formation["burst_due"] > 0.0:
		return
	formation["burst_due"] = 0.11
	formation["burst_left"] -= 1
	var target: SkyPlane = planes.pick_random()
	var gun: Vector3 = formation["guns"][formation["burst_gun"]]
	# Punto futuro del avión, con el error del artillero.
	var lead: float = gun.distance_to(target.global_position) / TRACER_SPEED
	var aim: Vector3 = target.global_position + target.velocity * lead * randf_range(0.7, 1.25) + Vector3(randf_range(-14.0, 14.0), randf_range(-10.0, 10.0), randf_range(-14.0, 14.0))
	var color: Color = TRACER_AXIS
	if formation["faction"] == Fronts.Faction.AXIS:
		color = TRACER_SOVIET if front == Fronts.Id.KURSK else TRACER_ALLIES
	var from: Vector3 = gun + Vector3.UP * 2.0
	Fx.on(self).tracer(from, (aim - from).normalized() * TRACER_SPEED, color)


## Duelo de artillería más allá del horizonte: una salva de fogonazos que encienden desde abajo
## las nubes de esa parte del cielo y, segundos después, el retumbar sordo de los cañones.
func distant_guns() -> void:
	var heading: float = randf() * TAU
	var away := Vector3(sin(heading), 0.0, cos(heading))
	var distance: float = randf_range(1700.0, 3000.0)
	var at: float = 0.0
	for i in randi_range(4, 11):
		at += randf_range(0.08, 0.6)
		var point: Vector3 = away * distance + Vector3(randf_range(-400.0, 400.0), 0.0, randf_range(-400.0, 400.0))
		get_tree().create_timer(at).timeout.connect(func() -> void:
			if is_inside_tree():
				Fx.on(self).sky_flash(point, Color(1.0, 0.62, 0.32), randf_range(1.2, 2.0), randf_range(300.0, 420.0), randf_range(0.22, 0.42)))
		# El sonido viaja a 343 m/s: de tan lejos llega tarde y ya solo es un golpe grave.
		get_tree().create_timer(at + distance / 343.0).timeout.connect(func() -> void:
			if is_inside_tree():
				distant_report(away))


## El estampido de un cañón lejano, llegando desde `away`: una grabación real hecha de lejos.
func distant_report(away: Vector3) -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	var ear: Vector3 = camera.global_position if camera != null else Vector3.ZERO
	Sfx.play_at(self, Sfx.DISTANT_GUNS.pick_random(), ear + away * 260.0, 8.0, randf_range(0.88, 1.06))


## Salva de cohetes desde detrás del horizonte (Katiusha, Nebelwerfer): una ristra de estelas
## que suben en abanico y se pierden a lo lejos, con el cielo encendido donde caen.
func rocket_salvo() -> void:
	var heading: float = randf() * TAU
	var away := Vector3(sin(heading), 0.0, cos(heading))
	var side := Vector3(away.z, 0.0, -away.x)
	var base: Vector3 = away * randf_range(300.0, 380.0)
	# Vuelan de lado, siguiendo el horizonte, para que se vea toda la parábola.
	var flight: Vector3 = (side * (1.0 if randf() < 0.5 else -1.0) + away * 0.35).normalized()
	var color := Color(1.0, 0.72, 0.4)
	var count: int = randi_range(8, 16)
	for i in count:
		var from: Vector3 = base + side * randf_range(-30.0, 30.0) + Vector3.UP * 3.0
		var velocity: Vector3 = (flight * randf_range(0.9, 1.1) + Vector3.UP * randf_range(0.55, 0.75)).normalized() * randf_range(150.0, 190.0)
		get_tree().create_timer(0.18 * i + randf_range(0.0, 0.08)).timeout.connect(func() -> void:
			if is_inside_tree():
				Fx.on(self).tracer(from, velocity, color)
				Fx.on(self).sky_flash(from, color, 0.5, 160.0, 0.25))
	# Donde caen, segundos después, el horizonte arde.
	var target: Vector3 = base + flight * randf_range(1400.0, 2200.0)
	for i in count / 2:
		get_tree().create_timer(5.0 + 0.3 * i + randf_range(0.0, 0.5)).timeout.connect(func() -> void:
			if is_inside_tree():
				Fx.on(self).sky_flash(target + Vector3(randf_range(-300.0, 300.0), 0.0, randf_range(-300.0, 300.0)), Color(1.0, 0.55, 0.25), randf_range(1.4, 2.2), randf_range(320.0, 440.0), randf_range(0.3, 0.5)))


## Bengala de iluminación sobre el frente: sube, estalla y alumbra un rato esa parte del cielo.
func flare() -> void:
	var heading: float = randf() * TAU
	var point: Vector3 = Vector3(sin(heading), 0.0, cos(heading)) * randf_range(330.0, 520.0) + Vector3.UP * randf_range(120.0, 190.0)
	var tint: Color = [Color(1.0, 0.95, 0.8), Color(0.75, 1.0, 0.7), Color(1.0, 0.5, 0.4)].pick_random()
	for i in 14:
		get_tree().create_timer(0.35 * i).timeout.connect(func() -> void:
			if is_inside_tree():
				Fx.on(self).sky_flash(point - Vector3.UP * 5.0 * i, tint, 0.9 - 0.04 * i, 260.0, 0.5))


## Fogonazos de baterías antiaéreas lejanas, cerca del horizonte.
func _distant_barrage() -> void:
	var heading: float = randf() * TAU
	var centre := Vector3(sin(heading), 0.0, cos(heading)) * randf_range(400.0, 470.0)
	for i in randi_range(3, 7):
		var point: Vector3 = centre + Vector3(randf_range(-70.0, 70.0), randf_range(70.0, 170.0), randf_range(-70.0, 70.0))
		get_tree().create_timer(randf_range(0.0, 2.4)).timeout.connect(func() -> void:
			if is_inside_tree():
				FlakBurst.spawn(self, point, 5.0))


func _on_crash(point: Vector3, plane: SkyPlane = null) -> void:
	crashes += 1
	if absf(point.x) >= FIELD or absf(point.z) >= FIELD:
		return
	crashes_inside += 1
	if nearest_tank(point) < HIT_RADIUS:
		crashes_on_tanks += 1
	if plane == null:
		return
	# Los restos se quedan ardiendo donde ha caído (solo se ven: no estorban ni hacen daño).
	var wreck := PlaneWreck.new()
	add_child(wreck)
	wreck.build(plane, point)
	# Fuera de la lista los que ya se retiraron solos (se borran al acabar su tiempo).
	_wrecks = _wrecks.filter(func(item: Variant) -> bool: return is_instance_valid(item))
	_wrecks.append(wreck)
	while _wrecks.size() > MAX_WRECKS:
		var old: Variant = _wrecks.pop_front()
		if is_instance_valid(old):
			(old as Node).queue_free()


## Avión de ambiente. La silueta sale del tipo (caza, ataque, bimotor, cuatrimotor).
class SkyPlane extends Node3D:
	const FALL_ACCEL: float = 11.0

	var velocity: Vector3
	var falling: bool = false
	var model: String = ""
	var _props: Array[Node3D] = []
	var _fx: Fx
	var _trail_due: float = 0.0
	var _span: float = 11.0
	var _owner_sky: Node
	var _roll_rate: float = 0.0
	## Colores y medidas, para los restos que deja si cae dentro del campo.
	var top_color: Color
	var span: float = 11.0
	var length: float = 9.5

	func build(model_name: String, spec: Dictionary, top: Color, belly: Color, faction: int) -> void:
		model = model_name
		span = spec["span"]
		_span = span
		length = spec["length"]
		top_color = top
		var top_mat: ShaderMaterial = VectorMaterials.textured(top, top.darkened(0.35), 4, 0.5)
		var fuselage := MeshInstance3D.new()
		var body := CylinderMesh.new()
		body.top_radius = length * 0.035
		body.bottom_radius = length * 0.075
		body.height = length
		body.radial_segments = 10
		fuselage.mesh = body
		fuselage.material_override = top_mat
		fuselage.rotation.x = PI * 0.5
		add_child(fuselage)
		var chord: float = span * (0.2 if spec["engines"] == 1 else 0.16)
		# El Stuka se reconoce por su ala en gaviota invertida y su tren fijo carenado.
		var gull: bool = model_name.contains("STUKA")
		for side in [-1.0, 1.0]:
			var wing := VectorMaterials.make_box(Vector3(span * 0.5, length * 0.02, chord), top, 4, 1.2)
			wing.position = Vector3(side * span * 0.25, -length * 0.02, -length * 0.08)
			wing.rotation.z = side * (0.09 if not gull else 0.2)
			add_child(wing)
			var under := VectorMaterials.make_box(Vector3(span * 0.5, 0.05, chord * 0.98), belly, 0, 1.0)
			under.position = wing.position + Vector3(0.0, -length * 0.012, 0.0)
			under.rotation.z = wing.rotation.z
			add_child(under)
			if gull:
				var leg := VectorMaterials.make_box(Vector3(0.45, 1.5, 1.4), top.darkened(0.2), 4, 0.6)
				leg.position = Vector3(side * span * 0.16, -1.1, -length * 0.1)
				add_child(leg)
			# Insignia en el ala: estrella o escarapela aliada, cruz alemana (un simple distintivo).
			var mark := VectorMaterials.make_box(Vector3(chord * 0.45, 0.04, chord * 0.45), Color(0.9, 0.9, 0.88) if faction == Fronts.Faction.ALLIES else Color(0.08, 0.08, 0.08))
			mark.position = Vector3(side * span * 0.36, length * 0.02 + side * 0.0, -length * 0.08)
			mark.rotation.z = wing.rotation.z
			add_child(mark)
		var tail := VectorMaterials.make_box(Vector3(span * 0.32, length * 0.015, chord * 0.55), top, 4, 1.0)
		tail.position = Vector3(0.0, length * 0.03, length * 0.45)
		add_child(tail)
		var fin := VectorMaterials.make_box(Vector3(length * 0.015, length * 0.16, chord * 0.6), top, 4, 1.0)
		fin.position = Vector3(0.0, length * 0.1, length * 0.45)
		add_child(fin)
		var canopy := VectorMaterials.make_box(Vector3(length * 0.07, length * 0.05, length * 0.16), Color(0.3, 0.42, 0.5), 1, 0.5)
		canopy.position = Vector3(0.0, length * 0.07, -length * 0.12)
		add_child(canopy)
		var engine_x: Array[float] = [0.0]
		if spec["engines"] == 2:
			engine_x = [-span * 0.17, span * 0.17]
		elif spec["engines"] == 4:
			engine_x = [-span * 0.3, -span * 0.14, span * 0.14, span * 0.3]
		for x in engine_x:
			var nose_z: float = -length * 0.5 if spec["engines"] == 1 else -length * 0.22
			if spec["engines"] > 1:
				var nacelle := MeshInstance3D.new()
				var cyl := CylinderMesh.new()
				cyl.top_radius = length * 0.03
				cyl.bottom_radius = length * 0.035
				cyl.height = length * 0.24
				cyl.radial_segments = 8
				nacelle.mesh = cyl
				nacelle.material_override = top_mat
				nacelle.rotation.x = PI * 0.5
				nacelle.position = Vector3(x, -length * 0.02, nose_z + length * 0.1)
				add_child(nacelle)
			var prop := Node3D.new()
			prop.position = Vector3(x, 0.0 if spec["engines"] == 1 else -length * 0.02, nose_z - 0.1)
			add_child(prop)
			prop.add_child(VectorMaterials.make_box(Vector3(length * 0.3, 0.14, 0.05), Color(0.12, 0.12, 0.12)))
			_props.append(prop)

	## Dónde tocaría el suelo si le dieran ahora mismo.
	func impact_point() -> Vector3:
		var fall_time: float = sqrt(2.0 * maxf(global_position.y, 1.0) / FALL_ACCEL)
		return global_position + Vector3(velocity.x, 0.0, velocity.z) * fall_time * 0.92

	func shoot_down(sky: Node) -> void:
		falling = true
		_owner_sky = sky
		_roll_rate = randf_range(0.6, 1.4) * (1.0 if randf() < 0.5 else -1.0)
		_fx = Fx.on(self)
		_fx.airburst(global_position, 1.3)
		Sfx.play_at(self, Sfx.EXPLOSION, global_position, 16.0, 0.9)

	func _process(delta: float) -> void:
		for prop in _props:
			prop.rotation.z += delta * 45.0
		if falling:
			velocity.y -= FALL_ACCEL * delta
			_steer_clear(delta)
			rotation.z += _roll_rate * delta
			if velocity.length() > 1.0:
				var heading: Vector3 = velocity.normalized()
				var roll: float = rotation.z
				look_at(global_position + heading, Vector3.UP)
				rotation.z = roll
		global_position += velocity * delta
		if falling and is_instance_valid(_fx):
			# Cae envuelto en llamas, dejando una estela de humo negro.
			var size: float = _span * 0.16
			_trail_due += delta * 26.0
			while _trail_due >= 1.0:
				_trail_due -= 1.0
				var at: Vector3 = global_position - velocity * delta * randf() + Fx.ball() * size * 0.4
				_fx.flame(at, velocity * 0.75, size * 1.3, 1.4)
				_fx.black_smoke(at, velocity * 0.25 + Vector3.UP * 1.5, size * 1.5, randf_range(4.0, 6.5))
		if falling and global_position.y <= 1.0:
			var point := Vector3(global_position.x, 0.5, global_position.z)
			Explosion.spawn(self, point, 3.0, VectorMaterials.ORANGE, true)
			Sfx.play_at(self, Sfx.EXPLOSION, point, 22.0, 0.7)
			if is_instance_valid(_owner_sky):
				_owner_sky._on_crash(point, self)
				SmokeColumn.spawn(_owner_sky, point)
			queue_free()

	## Mientras cae, si algún tanque queda cerca de donde va a estrellarse, se desvía de él.
	func _steer_clear(delta: float) -> void:
		if global_position.y < 2.0:
			return
		var time_left: float = (velocity.y + sqrt(maxf(velocity.y * velocity.y + 2.0 * FALL_ACCEL * global_position.y, 0.0))) / FALL_ACCEL
		var impact: Vector3 = global_position + Vector3(velocity.x, 0.0, velocity.z) * time_left
		if absf(impact.x) > SkyWar.FIELD + 20.0 or absf(impact.z) > SkyWar.FIELD + 20.0:
			return
		var push := Vector3.ZERO
		for node in get_tree().get_nodes_in_group(&"tanks"):
			var tank := node as Node3D
			if tank == null:
				continue
			var off := Vector3(impact.x - tank.global_position.x, 0.0, impact.z - tank.global_position.z)
			var distance: float = off.length()
			if distance < SkyWar.AVOID_RADIUS:
				push += (off / distance if distance > 0.5 else Vector3(velocity.z, 0.0, -velocity.x).normalized()) * (1.0 - distance / SkyWar.AVOID_RADIUS)
		if push != Vector3.ZERO:
			# Cuanto menos tiempo queda, más fuerte el viraje: tiene que apartar el punto de caída.
			velocity += push.normalized() * minf(60.0 / maxf(time_left, 0.4), 90.0) * delta


## Restos de un avión estrellado dentro del campo: fuselaje partido, un ala clavada y la cola,
## calcinados. Solo dibujo: los tanques pasan por encima. Se hunden y desaparecen al rato.
class PlaneWreck extends Node3D:
	const TIME: float = 150.0

	var _life: float = TIME

	func build(plane: SkyPlane, point: Vector3) -> void:
		global_position = Terrain.on_ground(point)
		rotation.y = atan2(-plane.velocity.x, -plane.velocity.z)
		var burnt: Color = plane.top_color.darkened(0.6)
		var soot := Color(0.06, 0.055, 0.05)
		var length: float = plane.length
		var span: float = plane.span
		var body := CylinderMesh.new()
		body.top_radius = length * 0.05
		body.bottom_radius = length * 0.075
		body.height = length * 0.55
		body.radial_segments = 8
		var fuselage := MeshInstance3D.new()
		fuselage.mesh = body
		fuselage.material_override = VectorMaterials.textured(burnt, soot, 4, 0.5)
		fuselage.rotation = Vector3(PI * 0.5 - 0.22, 0.0, 0.3)
		fuselage.position = Vector3(0.0, length * 0.09, length * 0.2)
		add_child(fuselage)
		var wing := VectorMaterials.make_box(Vector3(span * 0.42, length * 0.02, span * 0.18), burnt, 4, 1.2)
		wing.position = Vector3(span * 0.16, span * 0.1, -length * 0.1)
		wing.rotation = Vector3(0.2, 0.5, 0.75)
		add_child(wing)
		var stub := VectorMaterials.make_box(Vector3(span * 0.3, length * 0.02, span * 0.17), soot.lightened(0.08), 4, 1.2)
		stub.position = Vector3(-span * 0.3, 0.15, -length * 0.3)
		stub.rotation.y = -0.6
		add_child(stub)
		var fin := VectorMaterials.make_box(Vector3(length * 0.02, length * 0.2, span * 0.12), burnt, 4, 1.0)
		fin.position = Vector3(0.0, length * 0.2, length * 0.46)
		fin.rotation.z = 0.25
		add_child(fin)
		for i in 5:
			var scrap := VectorMaterials.make_box(Vector3(randf_range(0.5, 1.6), 0.08, randf_range(0.4, 1.2)), soot.lightened(randf_range(0.0, 0.12)), 4, 0.6)
			scrap.position = Vector3(randf_range(-span * 0.5, span * 0.5), 0.06, randf_range(-length * 0.7, length * 0.5))
			scrap.rotation = Vector3(randf_range(-0.2, 0.2), randf() * TAU, randf_range(-0.2, 0.2))
			scrap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(scrap)
		# Tierra quemada alrededor: varias manchas de las de las explosiones, solapadas.
		var fx: Fx = Fx.on(self)
		for i in 5:
			fx.mark(global_position + Vector3(randf_range(-span * 0.4, span * 0.4), 0.0, randf_range(-length * 0.6, length * 0.6)), randf_range(span * 0.3, span * 0.5), i == 0)

	func _process(delta: float) -> void:
		_life -= delta
		if _life < 6.0:
			position.y -= delta * 0.5
		if _life <= 0.0:
			queue_free()


## Columna de humo negro donde ha caído un avión: arde un rato y se va apagando.
class SmokeColumn extends Node3D:
	const TIME: float = 30.0

	var _life: float = TIME
	var _due: float = 0.0
	var _fx: Fx

	static func spawn(host: Node, point: Vector3) -> void:
		var column := SmokeColumn.new()
		host.add_child(column)
		column.global_position = point

	func _process(delta: float) -> void:
		_life -= delta
		if _life <= 0.0:
			queue_free()
			return
		if not is_instance_valid(_fx):
			_fx = Fx.on(self)
		var burn: float = clampf(_life / (TIME * 0.5), 0.0, 1.0)
		_due += delta * 5.0 * maxf(burn, 0.3)
		while _due >= 1.0:
			_due -= 1.0
			var at: Vector3 = global_position + Vector3(randf_range(-3.0, 3.0), randf_range(1.0, 3.0), randf_range(-3.0, 3.0))
			_fx.black_smoke(at, Vector3(randf_range(-0.5, 0.5), randf_range(5.0, 8.0), randf_range(-0.5, 0.5)), randf_range(4.5, 7.5), randf_range(7.0, 9.0))
			if burn > 0.3:
				_fx.flame(at, Vector3.ZERO, randf_range(3.0, 5.0) * burn, 1.3)


## Bomba de aviación: cae con su parábola y revienta en el terreno lejano: fogonazo que
## alumbra el cielo, surtidor de tierra y humo, y el estampido, que llega con su retraso.
class Bomb extends Node3D:
	static var _mesh: Mesh
	static var _material: StandardMaterial3D

	var velocity: Vector3
	var _host: SkyWar

	static func drop(host: SkyWar, from: Vector3, speed: Vector3) -> void:
		if _mesh == null:
			var body := CapsuleMesh.new()
			body.radius = 0.32
			body.height = 2.0
			body.radial_segments = 5
			body.rings = 1
			_mesh = body
			_material = StandardMaterial3D.new()
			_material.albedo_color = Color(0.13, 0.14, 0.12)
		var bomb := Bomb.new()
		bomb._host = host
		bomb.velocity = speed
		bomb.position = from
		var shape := MeshInstance3D.new()
		shape.mesh = _mesh
		shape.material_override = _material
		shape.rotation.x = PI * 0.5
		shape.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bomb.add_child(shape)
		host.add_child(bomb)

	func _process(delta: float) -> void:
		velocity.y -= SkyWar.GRAVITY * delta
		global_position += velocity * delta
		if velocity.length_squared() > 1.0:
			look_at(global_position + velocity, Vector3.UP)
		if global_position.y > 0.5:
			return
		var point := Vector3(global_position.x, 0.0, global_position.z)
		if is_instance_valid(_host):
			_host._on_bomb(point)
		BombBlast.spawn(get_parent(), point)
		queue_free()


## Explosión de una bomba a lo lejos.
class BombBlast extends Node3D:
	const TIME: float = 7.0

	var _time: float = 0.0
	var _boom_at: float = 0.0
	var _boomed: bool = false
	var _due: float = 0.0

	static func spawn(host: Node, point: Vector3) -> void:
		var blast := BombBlast.new()
		blast.position = point
		host.add_child(blast)

	func _ready() -> void:
		var fx := Fx.on(self)
		fx.sky_flash(global_position + Vector3.UP * 12.0, Color(1.0, 0.62, 0.3), randf_range(1.5, 2.3), randf_range(240.0, 330.0), randf_range(0.25, 0.4))
		fx.explosion(global_position, 4.5)
		for i in 7:
			# Surtidor de tierra y humo, grande para que se vea desde el campo.
			var up := Vector3(randf_range(-3.0, 3.0), randf_range(9.0, 22.0), randf_range(-3.0, 3.0))
			fx.black_smoke(global_position + Vector3(randf_range(-6.0, 6.0), randf_range(2.0, 10.0), randf_range(-6.0, 6.0)), up, randf_range(13.0, 22.0), randf_range(5.0, 8.0))
		var camera: Camera3D = get_viewport().get_camera_3d()
		if camera != null:
			_boom_at = camera.global_position.distance_to(global_position) / 343.0

	func _process(delta: float) -> void:
		_time += delta
		if not _boomed and _time >= _boom_at:
			_boomed = true
			# De lejos el estampido llega grave y sordo.
			# (Sfx deja de oírse a 500 m: suena desde su dirección, pero más cerca.)
			var camera: Camera3D = get_viewport().get_camera_3d()
			var ear: Vector3 = camera.global_position if camera != null else Vector3.ZERO
			var reach: Vector3 = global_position - ear
			Sfx.play_at(self, Sfx.EXPLOSION, ear + reach.limit_length(280.0), 14.0, randf_range(0.55, 0.7))
		if _time < TIME * 0.6:
			_due += delta * 2.0
			while _due >= 1.0:
				_due -= 1.0
				Fx.on(self).black_smoke(global_position + Vector3(randf_range(-7.0, 7.0), randf_range(3.0, 9.0), randf_range(-7.0, 7.0)), Vector3(randf_range(-1.0, 1.0), randf_range(5.0, 9.0), randf_range(-1.0, 1.0)), randf_range(12.0, 18.0), randf_range(6.0, 8.0))
		if _time >= TIME:
			queue_free()


## Estallido de un proyectil antiaéreo: fogonazo, metralla y nubecilla negra que se queda
## flotando (los pone Fx), y el estampido, que llega más tarde cuanto más lejos está (el sonido
## viaja a 343 m/s).
class FlakBurst extends Node3D:
	var _time: float = 0.0
	var _size: float = 1.0
	var _boom_at: float = 0.0

	static func spawn(host: Node, point: Vector3, size: float) -> void:
		var burst := FlakBurst.new()
		burst._size = size
		# Antes de entrar en el árbol: _ready ya necesita saber dónde estalla.
		burst.position = point
		host.add_child(burst)

	func _ready() -> void:
		Fx.on(self).airburst(global_position, _size)
		var camera: Camera3D = get_viewport().get_camera_3d()
		if camera != null:
			_boom_at = camera.global_position.distance_to(global_position) / 343.0

	func _process(delta: float) -> void:
		_time += delta
		if _time >= _boom_at:
			var distance: float = _boom_at * 343.0
			# Estampido seco de cerca, sordo y grave de lejos.
			Sfx.play_at(self, Sfx.FLAK, global_position, 14.0 if distance < 320.0 else 20.0, 1.0 if distance < 320.0 else 0.7)
			queue_free()
