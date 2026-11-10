class_name CtfMode
extends GameMode
## Captura la bandera: 4 contra 4 (el jugador y 3 aliados de la máquina contra 4 enemigos).
## Coge la bandera enemiga y llévala a tu base con tu bandera en casa. Gana quien haga 3 capturas
## o quien vaya por delante al acabar el tiempo. Los tanques destruidos reaparecen en su base.

const CAPTURES_TO_WIN: int = 3
const TIME_LIMIT: float = 600.0
const BASE_Z: float = 160.0
const TOUCH_RADIUS: float = 6.0
const CAPTURE_RADIUS: float = 9.0
const TEAM_SIZE: int = 4
const RESPAWN_TIME: float = 6.0

var captures: Array[int] = [0, 0]
var flags: Array[Flag] = []
var time_left: float = TIME_LIMIT

## Rol de cada tanque de la máquina: "attack" o "defend".
var _roles: Dictionary = {}
var _order_timer: float = 0.0


func _init() -> void:
	super._init()
	raid_interval = Vector2(80.0, 110.0)
	raid_first = 90.0


func base_pos(team: int) -> Vector3:
	return Vector3(0.0, 0.0, BASE_Z if team == PLAYER_TEAM else -BASE_Z)


func player_spawn() -> Transform3D:
	return Transform3D(Basis(), base_pos(PLAYER_TEAM) + Vector3(0.0, 0.2, -12.0))


func reserved_zones() -> Array[Rect2]:
	var zones: Array[Rect2] = []
	for team in [PLAYER_TEAM, ENEMY_TEAM]:
		var p: Vector3 = base_pos(team)
		zones.append(Rect2(Vector2(p.x, p.z) - Vector2(30.0, 30.0), Vector2(60.0, 60.0)))
	return zones


func start(player_tank: Tank, world_root: Node3D) -> void:
	super.start(player_tank, world_root)
	for team in [PLAYER_TEAM, ENEMY_TEAM]:
		var flag := Flag.create(team, faction_of(team), base_pos(team))
		flag.set_radar_color(Color(0.35, 0.65, 1.0) if team == PLAYER_TEAM else Color(1.0, 0.2, 0.15))
		world.add_child(flag)
		flags.append(flag)
		_build_base(team)
	for team in [PLAYER_TEAM, ENEMY_TEAM]:
		var count: int = TEAM_SIZE - (1 if team == PLAYER_TEAM else 0)
		# Atacantes por bando: dos de los tres aliados; del enemigo, según la dificultad.
		var attackers: int = 2 if team == PLAYER_TEAM else [2, 3, 3, 4][GameSettings.difficulty]
		for i in count:
			_spawn_unit(team, "attack" if i < attackers else "defend")
	message.emit("CAPTURA LA BANDERA ENEMIGA Y TRÁELA A TU BASE", true)


func _build_base(team: int) -> void:
	var pad := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = CAPTURE_RADIUS
	mesh.bottom_radius = CAPTURE_RADIUS
	mesh.height = 0.08
	mesh.radial_segments = 32
	pad.mesh = mesh
	pad.material_override = VectorMaterials.paint(Color(0.2, 0.35, 0.7) if team == PLAYER_TEAM else Color(0.6, 0.15, 0.1))
	pad.position = base_pos(team) + Vector3.UP * 0.04
	world.add_child(pad)
	for side in [-1.0, 1.0]:
		var bags := PropFactory.sandbags(8.0)
		bags.position = base_pos(team) + Vector3(side * 14.0, 0.0, 0.0)
		bags.rotation.y = PI * 0.5
		world.add_child(bags)


func _spawn_unit(team: int, role: String) -> void:
	var pool: Array[TankStats] = roster(team)
	# Sin los más pesados para que el ritmo sea ágil.
	var options: Array[TankStats] = pool.filter(func(s: TankStats) -> bool: return s.tier <= 2)
	var stats: TankStats = options.pick_random()
	var base: Vector3 = base_pos(team)
	var point: Vector2 = free_point_near(Vector2(base.x, base.z), 8.0, 22.0)
	var tank: Tank = spawn_tank(stats, team, point, 0.0 if team == PLAYER_TEAM else PI)
	_roles[tank] = role
	var brain: AIBrain = tank.get_node("AIBrain")
	brain.hunt = false


func status_text() -> String:
	var minutes: int = int(time_left) / 60
	var seconds: int = int(time_left) % 60
	return "%s %d — %d %s   %d:%02d" % [Fronts.FACTION_NAMES[faction_of(PLAYER_TEAM)], captures[PLAYER_TEAM], captures[ENEMY_TEAM], Fronts.FACTION_NAMES[faction_of(ENEMY_TEAM)], minutes, seconds]


func _process(delta: float) -> void:
	if is_over:
		return
	time_left -= delta
	if time_left <= 0.0:
		_time_up()
		return
	_update_flags()
	_order_timer -= delta
	if _order_timer <= 0.0:
		_order_timer = 0.5
		_give_orders()


func _update_flags() -> void:
	for flag in flags:
		match flag.state:
			Flag.Status.CARRIED:
				if not is_instance_valid(flag.carrier) or flag.carrier.is_destroyed:
					flag.drop()
					message.emit("BANDERA %s CAÍDA" % ("ALIADA" if flag.team == PLAYER_TEAM else "ENEMIGA"), false)
				else:
					_check_capture(flag)
			_:
				for node in get_tree().get_nodes_in_group(&"tanks"):
					var tank: Tank = node as Tank
					if tank == null or tank.is_destroyed:
						continue
					if tank.global_position.distance_to(flag.global_position) > TOUCH_RADIUS:
						continue
					if tank.team != flag.team:
						flag.pick_up(tank)
						_announce_pickup(flag, tank)
						break
					elif flag.state == Flag.Status.DROPPED:
						flag.return_home()
						message.emit("BANDERA %s RECUPERADA" % ("ALIADA" if flag.team == PLAYER_TEAM else "ENEMIGA"), false)
						break


func _announce_pickup(flag: Flag, tank: Tank) -> void:
	if tank == player:
		message.emit("¡TIENES LA BANDERA ENEMIGA! VUELVE A TU BASE", true)
		get_tree().call_group(&"voice", &"say", "flag_taken", VoiceManager.Priority.HIGH)
	elif flag.team == PLAYER_TEAM:
		message.emit("¡EL ENEMIGO TIENE NUESTRA BANDERA!", true)
		get_tree().call_group(&"voice", &"say", "flag_lost", VoiceManager.Priority.HIGH)
	else:
		message.emit("UN ALIADO TIENE LA BANDERA ENEMIGA: ESCÓLTALO", false)


func _check_capture(flag: Flag) -> void:
	var carrier: Tank = flag.carrier
	var own_flag: Flag = flags[carrier.team]
	if own_flag.state != Flag.Status.HOME:
		return
	if carrier.global_position.distance_to(base_pos(carrier.team)) > CAPTURE_RADIUS:
		return
	flag.return_home()
	captures[carrier.team] += 1
	if carrier == player:
		score += 1000
	var ours: bool = carrier.team == PLAYER_TEAM
	if ours:
		get_tree().call_group(&"voice", &"say", "flag_capture", VoiceManager.Priority.HIGH)
	message.emit("¡CAPTURA %s!  %d — %d" % ["ALIADA" if ours else "ENEMIGA", captures[PLAYER_TEAM], captures[ENEMY_TEAM]], true)
	if captures[carrier.team] >= CAPTURES_TO_WIN:
		if ours:
			finish(true, "¡VICTORIA!", "CAPTURAS %d — %d" % [captures[PLAYER_TEAM], captures[ENEMY_TEAM]])
		else:
			finish(false, "DERROTA", "CAPTURAS %d — %d" % [captures[PLAYER_TEAM], captures[ENEMY_TEAM]])


## Reparte órdenes a los tanques de la máquina de los dos bandos. Prioridades de cada equipo:
## 1. quien lleva la bandera enemiga la trae a casa sin entretenerse;
## 2. si el contrario lleva la nuestra, todos los demás van a por su portador;
## 3. si la nuestra está caída, el más cercano va a tocarla para devolverla;
## 4. los atacantes van directos a la bandera enemiga (o escoltan al compañero que la lleva);
## 5. los defensores vigilan la base.
func _give_orders() -> void:
	for team in [PLAYER_TEAM, ENEMY_TEAM]:
		var own_flag: Flag = flags[team]
		var enemy_flag: Flag = flags[1 - team]
		var units: Array[Tank] = []
		for tank: Variant in _roles.keys():
			if is_instance_valid(tank) and not tank.is_destroyed and tank.team == team:
				units.append(tank)
		var rescuer: Tank = null
		if own_flag.state == Flag.Status.DROPPED:
			rescuer = _nearest(units, own_flag.global_position, enemy_flag.carrier)
		for tank in units:
			var brain: AIBrain = tank.get_node("AIBrain")
			var attacker: bool = _roles[tank] == "attack"
			if enemy_flag.carrier == tank:
				brain.order(base_pos(team), 1.0, true)
			elif own_flag.state == Flag.Status.CARRIED:
				brain.order(own_flag.global_position, 4.0, false, own_flag.carrier)
			elif tank == rescuer:
				brain.order(own_flag.global_position, 1.0, true)
			elif attacker and enemy_flag.state == Flag.Status.CARRIED and enemy_flag.carrier.team == team:
				# Escolta: cerca del compañero que trae la bandera, peleando con quien se acerque.
				brain.order(enemy_flag.global_position, 12.0)
			elif attacker:
				brain.order(enemy_flag.global_position, 1.0, true)
			else:
				brain.order(own_flag.home, 18.0)


func _nearest(units: Array[Tank], point: Vector3, except: Tank) -> Tank:
	var best: Tank = null
	for tank in units:
		if tank == except:
			continue
		if best == null or tank.global_position.distance_to(point) < best.global_position.distance_to(point):
			best = tank
	return best


func _time_up() -> void:
	var detail: String = "CAPTURAS %d — %d" % [captures[PLAYER_TEAM], captures[ENEMY_TEAM]]
	if captures[PLAYER_TEAM] > captures[ENEMY_TEAM]:
		finish(true, "¡VICTORIA POR TIEMPO!", detail)
	elif captures[PLAYER_TEAM] < captures[ENEMY_TEAM]:
		finish(false, "DERROTA POR TIEMPO", detail)
	else:
		finish(false, "EMPATE", detail)


func _on_tank_destroyed(tank: Tank, killer: Node) -> void:
	super._on_tank_destroyed(tank, killer)
	if not _roles.has(tank):
		return
	var role: String = _roles[tank]
	_roles.erase(tank)
	var team: int = tank.team
	get_tree().create_timer(RESPAWN_TIME).timeout.connect(func() -> void:
		if not is_over:
			_spawn_unit(team, role))


func _on_player_destroyed(_tank: Tank, _killer: Node) -> void:
	message.emit("TANQUE DESTRUIDO — REAPARECES EN %d s" % int(RESPAWN_TIME), true)
	get_tree().create_timer(RESPAWN_TIME).timeout.connect(func() -> void:
		if not is_over:
			player.revive(player_spawn())
			message.emit("DE VUELTA AL COMBATE", false))
