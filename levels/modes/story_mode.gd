class_name StoryMode
extends GameMode
## Modo historia: una misión de la campaña. Si destruyen al jugador, la misión fracasa.
## assault: destruir una fuerza enemiga · destroy: volar los depósitos · defend: resistir en
## la posición hasta que acabe el tiempo · boss: abatir al comandante y su escolta.

const ZONE_RADIUS: float = 22.0

var mission: Dictionary
var kind: String
var remaining: int = 0
var time_left: float = 0.0
var alive: int = 0

var _to_spawn: int = 0
var _spawn_timer: float = 3.0
var _commander: Tank
var _depot_points: Array[Vector2] = []
var _reinforce_timer: float = 40.0


func _init() -> void:
	super._init()
	mission = GameSession.current_mission()
	kind = mission["type"]


func player_spawn() -> Transform3D:
	if kind == "defend":
		return Transform3D(Basis(), Vector3(0.0, 0.2, 8.0))
	return Transform3D(Basis(), Vector3(0.0, 0.2, 150.0))


func reserved_zones() -> Array[Rect2]:
	var zones: Array[Rect2] = [Rect2(Vector2(-25.0, 125.0), Vector2(50.0, 50.0))]
	if kind == "defend":
		zones.append(Rect2(Vector2(-ZONE_RADIUS - 8.0, -ZONE_RADIUS - 8.0), Vector2.ONE * (ZONE_RADIUS + 8.0) * 2.0))
	if kind == "destroy":
		_depot_points = [Vector2(-110.0, -120.0), Vector2(0.0, -150.0), Vector2(110.0, -110.0)]
		for p in _depot_points:
			zones.append(Rect2(p - Vector2(15.0, 15.0), Vector2(30.0, 30.0)))
	return zones


func start(player_tank: Tank, world_root: Node3D) -> void:
	super.start(player_tank, world_root)
	message.emit("%s — %s" % [mission["title"], _objective_line()], true)
	for i in mission.get("allies", 0):
		var stats: TankStats = roster(PLAYER_TEAM).filter(func(s: TankStats) -> bool: return s.tier <= 2).pick_random()
		var spawn: Vector3 = player_spawn().origin
		spawn_tank(stats, PLAYER_TEAM, Vector2(spawn.x + (i + 1) * 9.0 * (1 if i % 2 == 0 else -1), spawn.z + 6.0))
	match kind:
		"assault":
			remaining = mission["count"]
			_to_spawn = remaining
		"destroy":
			for point in _depot_points:
				var depot := PropFactory.supply_depot()
				depot.position = Vector3(point.x, 0.0, point.y)
				world.add_child(depot)
				depot.destroyed.connect(_on_depot_destroyed)
				for g in 2:
					var guard: Tank = _spawn_enemy(free_point_near(point, 10.0, 20.0))
					var brain: AIBrain = guard.get_node("AIBrain")
					brain.hunt = false
					brain.objective = Vector3(point.x, 0.0, point.y)
					brain.objective_radius = 15.0
			remaining = _depot_points.size()
		"defend":
			time_left = mission["time"]
			_build_zone()
		"boss":
			var heaviest: TankStats = roster(ENEMY_TEAM)[0]
			for stats in roster(ENEMY_TEAM):
				if stats.max_armor > heaviest.max_armor:
					heaviest = stats
			var boss_stats: TankStats = heaviest.duplicate()
			boss_stats.max_armor *= 1.5
			boss_stats.display_name = "COMANDANTE (%s)" % heaviest.display_name
			boss_stats.score_value *= 3
			_commander = spawn_tank(boss_stats, ENEMY_TEAM, Vector2(randf_range(-60.0, 60.0), -150.0), 0.0)
			_commander.add_to_group(&"radar_marks")
			_commander.set_meta("radar_color", Color(0.85, 0.3, 1.0))
			_to_spawn = mission["count"]


func _objective_line() -> String:
	match kind:
		"assault":
			return "DESTRUYE %d BLINDADOS" % mission["count"]
		"destroy":
			return "DESTRUYE LOS DEPÓSITOS (MARCADOS EN EL RADAR)"
		"defend":
			return "RESISTE EN LA POSICIÓN %d s" % int(mission["time"])
		_:
			return "DESTRUYE AL COMANDANTE (MARCA VIOLETA EN EL RADAR)"


func status_text() -> String:
	match kind:
		"assault":
			return "%s   ENEMIGOS RESTANTES %d" % [mission["title"], remaining]
		"destroy":
			return "%s   DEPÓSITOS %d" % [mission["title"], remaining]
		"defend":
			return "%s   RESISTE %d s" % [mission["title"], ceili(time_left)]
		_:
			return "%s   COMANDANTE %d%%" % [mission["title"], roundi(_commander.health.fraction() * 100.0) if is_instance_valid(_commander) else 0]


func _process(delta: float) -> void:
	if is_over:
		return
	_spawn_timer -= delta
	match kind:
		"assault", "boss":
			if _to_spawn > 0 and alive < 3 and _spawn_timer <= 0.0:
				_spawn_timer = 4.0
				_to_spawn -= 1
				var center := Vector2(0.0, -120.0) if kind == "assault" else Vector2(_commander.global_position.x, _commander.global_position.z) if is_instance_valid(_commander) else Vector2(0.0, -120.0)
				_spawn_enemy(free_point_near(center, 10.0, 60.0))
		"destroy":
			_reinforce_timer -= delta
			if _reinforce_timer <= 0.0 and alive < 4:
				_reinforce_timer = 40.0
				_spawn_enemy(free_point_near(Vector2(0.0, -150.0), 5.0, 40.0))
		"defend":
			time_left -= delta
			if time_left <= 0.0:
				finish(true, "¡MISIÓN CUMPLIDA!", "%s — POSICIÓN DEFENDIDA" % mission["title"])
				_complete()
				return
			var elapsed: float = mission["time"] - time_left
			if alive < 2 + int(elapsed / 50.0) and _spawn_timer <= 0.0:
				_spawn_timer = 6.0
				var angle: float = randf_range(-PI * 0.8, -PI * 0.2)
				var tank: Tank = _spawn_enemy(free_point_near(Vector2.from_angle(angle) * 150.0, 0.0, 20.0))
				var brain: AIBrain = tank.get_node("AIBrain")
				brain.hunt = false
				brain.objective = Vector3.ZERO
				brain.objective_radius = ZONE_RADIUS


func _spawn_enemy(point: Vector2) -> Tank:
	var pool: Array[TankStats] = roster(ENEMY_TEAM)
	var index: int = GameSession.mission_index
	# Cuanto más avanzada la misión, más pesados pueden salir.
	var max_tier: int = 1 if index < 2 else (2 if index < 6 else 3)
	var options: Array[TankStats] = pool.filter(func(s: TankStats) -> bool: return s.tier <= max_tier)
	alive += 1
	return spawn_tank(options.pick_random(), ENEMY_TEAM, point, PI)


func _build_zone() -> void:
	for i in 16:
		var angle: float = TAU * i / 16.0
		var post := VectorMaterials.make_box(Vector3(0.3, 1.5, 0.3), Color(0.9, 0.75, 0.2), 0, 1.0)
		post.position = Vector3(cos(angle) * ZONE_RADIUS, 0.75, sin(angle) * ZONE_RADIUS)
		world.add_child(post)
	var marker := Node3D.new()
	marker.add_to_group(&"radar_marks")
	marker.set_meta("radar_color", Color(0.3, 0.9, 1.0))
	world.add_child(marker)
	for side in [-1.0, 1.0]:
		var bags := PropFactory.sandbags(10.0)
		bags.position = Vector3(side * 12.0, 0.0, -10.0)
		bags.rotation.y = side * 0.4
		world.add_child(bags)


func _on_depot_destroyed(_prop: Destructible) -> void:
	remaining -= 1
	score += 500
	message.emit("DEPÓSITO DESTRUIDO — QUEDAN %d" % remaining, true)
	if remaining <= 0:
		finish(true, "¡MISIÓN CUMPLIDA!", "%s — DEPÓSITOS DESTRUIDOS" % mission["title"])
		_complete()


func _on_tank_destroyed(tank: Tank, killer: Node) -> void:
	super._on_tank_destroyed(tank, killer)
	if tank.team != ENEMY_TEAM:
		return
	alive -= 1
	if tank == _commander:
		_commander.remove_from_group(&"radar_marks")
		finish(true, "¡MISIÓN CUMPLIDA!", "%s — COMANDANTE ABATIDO" % mission["title"])
		_complete()
	elif kind == "assault":
		remaining -= 1
		if remaining <= 0:
			finish(true, "¡MISIÓN CUMPLIDA!", "%s — ZONA DESPEJADA" % mission["title"])
			_complete()


func _complete() -> void:
	GameSession.mark_mission_completed(GameSession.mission_index)


func _on_player_destroyed(_tank: Tank, _killer: Node) -> void:
	finish(false, "MISIÓN FRACASADA", "%s — TU TANQUE HA SIDO DESTRUIDO" % mission["title"])


func has_next_mission() -> bool:
	return GameSession.mission_index + 1 < GameSession.missions().size()
