class_name Tank
extends CharacterBody3D
## Tanque. Jugador, aliados y enemigos usan esta misma clase; solo cambia quién da las órdenes.
## El modelo lo construye TankModel a partir de la ficha (TankStats) y de la pintura del frente.

const LAYER_WORLD: int = 1
const LAYER_TANK: int = 2
const LAYER_HURTBOX: int = 4
## Barrera del límite del mapa: solo la tocan los tanques.
const LAYER_BOUNDARY: int = 8
## Pendiente máxima que sube un tanque. Colinas y montañas son más empinadas: hacen de pared.
const MAX_SLOPE_DEG: float = 10.0
## Capa visual de las piezas del propio jugador (la cámara en primera persona no las ve).
const VISUAL_LAYER_OWN: int = 2
## Distancia hacia atrás y altura de las vistas exteriores [cerca, lejos].
const CHASE_OFFSETS: Array[Vector2] = [Vector2(10.0, 4.5), Vector2(20.0, 9.0)]
const WRECK_TIME: float = 8.0

signal destroyed(tank: Tank, killer: Node)
signal damaged(amount: float, source: Node)

@export var stats: TankStats
@export var is_player: bool = false
## Equipo: 0 = el del jugador, 1 = el contrario.
@export var team: int = 0
## Pintura: {"base": Color, "mode": int, "a": Color, "b": Color} (ver TankModel).
var paint: Dictionary = {}

## Órdenes (las rellena PlayerInputSource o la IA).
var drive_input: Vector2 = Vector2.ZERO
var trigger_held: bool = false

var turret: Node3D
var gun_pivot: Node3D
var muzzle: Marker3D
var camera: Camera3D
var hurtbox: Hurtbox
var health: HealthComponent
var weapon: TankWeapon
var turret_controller: TurretController
var is_destroyed: bool = false
## Enemigo fijado por la ayuda de apuntado (solo jugador).
var aim_lock: Tank = null

var _scale_factor: float = 1.0
var _shake: float = 0.0
var _view: int = 0
var _meshes: Array[MeshInstance3D] = []
## Mejoras temporales activas: nombre → segundos restantes.
var buffs: Dictionary = {}
var _exhaust: GPUParticles3D
var _dust: GPUParticles3D
var _flash_light: OmniLight3D
var _flash_time: float = 0.0
var _materials: Array[Material] = []
## Material del modelo: con él se animan las orugas.
var _track_material: ShaderMaterial
var _track_scroll: Vector2 = Vector2.ZERO
var _last_yaw: float = 0.0
## Sonido: motor (sube de vueltas al acelerar) y golpeteo de las orugas al moverse.
var _engine_sound: AudioStreamPlayer3D
var _tracks_sound: AudioStreamPlayer3D
var _engine_pitch: float = 1.0
var _engine_level: float = 0.0
var _tracks_level: float = 0.0
## Borde azul que destaca a los enemigos (ajuste «Destacar enemigos»): el mismo modelo, un poco
## más gordo y dibujado solo por sus caras traseras, asoma alrededor de la silueta.
static var _outline: StandardMaterial3D


func _ready() -> void:
	if stats == null:
		stats = TankStats.new()
	if paint.is_empty():
		paint = TankModel.plain_paint(Color(0.33, 0.36, 0.22))
	_scale_factor = stats.body_scale
	add_to_group(&"tanks")
	collision_layer = LAYER_TANK
	collision_mask = LAYER_WORLD | LAYER_TANK | LAYER_BOUNDARY
	floor_max_angle = deg_to_rad(MAX_SLOPE_DEG)
	floor_block_on_wall = true
	_build_body()
	_build_components()
	_build_effects()
	_build_sound()
	refresh_highlight()
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)


## ¿Es enemigo de este otro tanque?
func is_hostile_to(other: Tank) -> bool:
	return other != null and other.team != team


func _physics_process(delta: float) -> void:
	if trigger_held and not is_destroyed:
		weapon.fire()
	if not buffs.is_empty():
		for kind in buffs.keys():
			buffs[kind] -= delta
			if buffs[kind] <= 0.0:
				buffs.erase(kind)
		_apply_buffs()


## Mejora temporal: "reload" (recarga x2), "damage" (daño x2), "shield" (daño recibido /2).
func add_buff(kind: String, duration: float) -> void:
	buffs[kind] = maxf(buffs.get(kind, 0.0), duration)
	_apply_buffs()


func _apply_buffs() -> void:
	weapon.reload_mult = 0.5 if buffs.has("reload") else 1.0
	weapon.damage_mult = 2.0 if buffs.has("damage") else 1.0
	hurtbox.damage_multiplier = 0.5 if buffs.has("shield") else 1.0


const ZOOM_FOV: float = 16.0
const NORMAL_FOV: float = 75.0
var binoculars: bool = false
var _view_before_zoom: int = 0


const AIR_FOV: float = 45.0
var air_mode: bool = false


## Modo antiaéreo: vista de cabina con zoom moderado y el cañón puede alzarse 60º.
func set_air_mode(on: bool) -> void:
	if camera == null or on == air_mode:
		return
	air_mode = on
	set_binoculars(false)
	turret_controller.max_pitch = deg_to_rad(60.0) if on else TurretController.MAX_PITCH
	if on:
		_view_before_zoom = _view
		set_view(0)
		camera.fov = AIR_FOV
	else:
		camera.fov = NORMAL_FOV
		set_view(_view_before_zoom)


## Prismáticos: vista desde la cabina con mucho aumento.
func set_binoculars(on: bool) -> void:
	if camera == null or on == binoculars:
		return
	binoculars = on
	if on:
		_view_before_zoom = _view
		set_view(0)
	camera.fov = ZOOM_FOV if on else NORMAL_FOV
	if not on:
		set_view(_view_before_zoom)


## 0 = cabina, 1 = detrás cerca, 2 = detrás lejos.
func set_view(view: int) -> void:
	if camera == null:
		return
	_view = view
	if view == 0:
		camera.top_level = false
		camera.transform = Transform3D(Basis(), Vector3(0.0, 0.35, 0.2))
		camera.cull_mask = 1
	else:
		camera.top_level = true
		camera.cull_mask = 1 | VISUAL_LAYER_OWN
		camera.global_transform = _chase_transform()


func _chase_transform() -> Transform3D:
	var offset: Vector2 = CHASE_OFFSETS[clampi(_view - 1, 0, 1)]
	var yaw: float = turret_controller.world_yaw
	var forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var eye: Vector3 = global_position - forward * offset.x + Vector3.UP * offset.y
	var look: Vector3 = global_position + forward * 25.0 + Vector3.UP * 1.5
	return Transform3D(Basis.looking_at(look - eye, Vector3.UP), eye)


func _process(delta: float) -> void:
	if _flash_time > 0.0:
		_flash_time -= delta
		if _flash_time <= 0.0:
			_flash_light.light_energy = 0.0
	if _dust != null:
		var moving: bool = not is_destroyed and velocity.length() > 3.0
		_dust.emitting = moving
		_exhaust.amount_ratio = 1.0 if moving else 0.4
		_exhaust.emitting = not is_destroyed
	_animate_tracks(delta)
	_update_sound(delta)
	if camera != null and _view > 0:
		var target: Transform3D = _chase_transform()
		var t: float = 1.0 - exp(-8.0 * delta)
		camera.global_transform = Transform3D(camera.global_basis.slerp(target.basis, t).orthonormalized(), camera.global_position.lerp(target.origin, t))
	if camera != null:
		_shake = maxf(_shake - delta * 2.5, 0.0)
		camera.h_offset = randf_range(-1.0, 1.0) * _shake * 0.25
		camera.v_offset = randf_range(-1.0, 1.0) * _shake * 0.25


## Las orugas corren según el avance y el giro del casco (una gira más que la otra al virar).
func _animate_tracks(delta: float) -> void:
	if _track_material == null or is_destroyed or delta <= 0.0:
		return
	var yaw: float = global_rotation.y
	var turn: float = angle_difference(_last_yaw, yaw) / delta
	_last_yaw = yaw
	var forward: float = velocity.dot(-global_basis.z)
	if absf(forward) < 0.01 and absf(turn) < 0.001:
		return
	var half_width: float = 1.7 * _scale_factor
	var link: float = 0.17 * _scale_factor
	_track_scroll.x = fposmod(_track_scroll.x - (forward - turn * half_width) * delta / link, 1.0)
	_track_scroll.y = fposmod(_track_scroll.y - (forward + turn * half_width) * delta / link, 1.0)
	_track_material.set_shader_parameter("track_offset", _track_scroll)


## Pone o quita el borde azul según el ajuste. Solo en tanques enemigos enteros.
func refresh_highlight() -> void:
	var on: bool = GameSettings.highlight_enemies and team != 0 and not is_player and not is_destroyed
	if on and _outline == null:
		_outline = StandardMaterial3D.new()
		_outline.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_outline.albedo_color = Color(0.25, 0.6, 1.0)
		_outline.cull_mode = BaseMaterial3D.CULL_FRONT
		_outline.grow = true
		_outline.grow_amount = 0.07
		_outline.disable_fog = true
	for mesh in _meshes:
		if is_instance_valid(mesh):
			mesh.material_overlay = _outline if on else null


## Motor y orugas. El tanque propio suena más bajo y sin apagarse al alejar la cámara; los
## demás se oyen según la distancia, así que se les oye llegar. Los pesados usan un motor más
## grave y los blindados de ruedas uno más agudo y sin orugas.
func _build_sound() -> void:
	var heavy: bool = _scale_factor >= 1.2 or stats.tier >= 3
	_engine_pitch = clampf(1.0 / sqrt(maxf(_scale_factor, 0.5)), 0.8, 1.2) * randf_range(0.96, 1.04)
	if stats.wheels > 0:
		_engine_pitch *= 1.2
	var reach: float = 60.0 if is_player else 170.0
	_engine_sound = Sfx.loop_player(Sfx.ENGINE_HEAVY if heavy else Sfx.ENGINE_TANK, 40.0 if is_player else 9.0, reach)
	_engine_sound.position.y = 1.2 * _scale_factor
	add_child(_engine_sound)
	if stats.wheels == 0:
		_tracks_sound = Sfx.loop_player(Sfx.TRACKS, 40.0 if is_player else 7.0, reach)
		_tracks_sound.position.y = 0.4
		_tracks_sound.volume_db = -60.0
		add_child(_tracks_sound)
	_update_sound(0.0)


func _update_sound(delta: float) -> void:
	if _engine_sound == null or is_destroyed:
		return
	var speed: float = clampf(velocity.length() / maxf(stats.max_speed, 1.0), 0.0, 1.0)
	var turning: float = clampf(absf(drive_input.x), 0.0, 1.0)
	# El motor sube de vueltas en cuanto se pisa el acelerador, antes de ganar velocidad.
	var throttle: float = clampf(maxf(absf(drive_input.y), turning * 0.6), 0.0, 1.0)
	_engine_level = move_toward(_engine_level, maxf(speed, throttle * 0.75), delta * 1.3)
	_engine_sound.pitch_scale = _engine_pitch * (0.8 + 0.7 * _engine_level)
	_engine_sound.volume_db = lerpf(-15.0, -8.0, _engine_level) if is_player else lerpf(-4.0, 3.0, _engine_level)
	if _tracks_sound == null:
		return
	_tracks_level = move_toward(_tracks_level, maxf(speed, turning * 0.45), delta * 2.5)
	var rolling: bool = _tracks_level > 0.04
	if _tracks_sound.stream_paused == rolling:
		_tracks_sound.stream_paused = not rolling
	if rolling:
		_tracks_sound.pitch_scale = 0.65 + 0.75 * _tracks_level
		_tracks_sound.volume_db = lerpf(-22.0, -9.0, _tracks_level) if is_player else lerpf(-14.0, 0.0, _tracks_level)


func _set_sound_running(running: bool) -> void:
	for sound: AudioStreamPlayer3D in [_engine_sound, _tracks_sound]:
		if sound == null:
			continue
		if running and not sound.playing:
			sound.play(randf() * 1.5)
		elif not running:
			sound.stop()
	_engine_level = 0.0
	_tracks_level = 0.0


func _build_effects() -> void:
	var rear: float = TankModel.HULL_SIZE.z * stats.hull_proportions.z * _scale_factor * 0.5
	_exhaust = _puffs(Color(0.2, 0.2, 0.2, 0.45), 14, 1.6, Vector3(0.0, 1.4 * _scale_factor, rear), Vector3(0.0, 1.0, 0.6))
	_dust = _puffs(Color(0.45, 0.38, 0.28, 0.4), 18, 1.2, Vector3(0.0, 0.3, rear * 0.9), Vector3(0.0, 0.6, 1.0))
	_dust.emitting = false
	_flash_light = OmniLight3D.new()
	_flash_light.light_color = Color(1.0, 0.75, 0.4)
	_flash_light.omni_range = 9.0
	_flash_light.light_energy = 0.0
	muzzle.add_child(_flash_light)


func _puffs(color: Color, amount: int, lifetime: float, pos: Vector3, direction: Vector3) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.amount = amount
	particles.lifetime = lifetime
	particles.local_coords = false
	particles.position = pos
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var process := ParticleProcessMaterial.new()
	process.direction = direction
	process.spread = 25.0
	process.initial_velocity_min = 0.8
	process.initial_velocity_max = 1.8
	process.gravity = Vector3(0.0, 0.5, 0.0)
	process.scale_min = 0.6
	process.scale_max = 1.6 * _scale_factor
	particles.process_material = process
	var mesh := SphereMesh.new()
	mesh.radius = 0.35
	mesh.height = 0.7
	mesh.radial_segments = 6
	mesh.rings = 3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mat
	particles.draw_pass_1 = mesh
	if is_player:
		particles.layers = VISUAL_LAYER_OWN
	add_child(particles)
	return particles


func _on_fired() -> void:
	_flash_time = 0.08
	_flash_light.light_energy = 6.0
	Explosion.spawn(self, muzzle.global_position, 0.3, Color(1.0, 0.85, 0.5), true)
	if is_player:
		Sfx.play_2d(self, Sfx.CANNON, 2.0)
		_shake = maxf(_shake, 0.35)
	else:
		Sfx.play_at(self, Sfx.CANNON, muzzle.global_position, 0.0, 1.0 / maxf(_scale_factor, 0.7))


func _on_damaged(amount: float, source: Node) -> void:
	if is_player:
		_shake = minf(_shake + amount / 25.0, 1.5)
		# Impacto en nuestro propio blindaje: golpe metálico seco y fuerte.
		Sfx.play_2d(self, Sfx.HIT_TANK, 4.0, clampf(1.2 - amount / 60.0, 0.8, 1.2))
	damaged.emit(amount, source)


func _on_died(source: Node) -> void:
	is_destroyed = true
	drive_input = Vector2.ZERO
	trigger_held = false
	remove_from_group(&"tanks")
	_set_sound_running(false)
	refresh_highlight()
	hurtbox.set_deferred("monitorable", false)
	hurtbox.collision_layer = 0
	Explosion.spawn(self, global_position + Vector3.UP * 1.0, 1.0 * _scale_factor + 0.5)
	destroyed.emit(self, source)
	if is_player:
		_shake = 1.5
	# Queda un casco calcinado unos segundos.
	for i in _meshes.size():
		if is_instance_valid(_meshes[i]):
			_meshes[i].material_override = VectorMaterials.burnt(_materials[i])
	if turret != null:
		turret.rotation += Vector3(randf_range(-0.2, 0.2), randf_range(-0.6, 0.6), randf_range(-0.3, 0.3))
	if not is_player:
		get_tree().create_timer(WRECK_TIME).timeout.connect(queue_free)


## Reaparece (solo el jugador: los tanques de la máquina se crean de nuevo).
func revive(spawn: Transform3D) -> void:
	health.revive()
	is_destroyed = false
	_set_sound_running(true)
	add_to_group(&"tanks")
	hurtbox.collision_layer = LAYER_HURTBOX
	hurtbox.set_deferred("monitorable", true)
	for i in _meshes.size():
		if is_instance_valid(_meshes[i]):
			_meshes[i].material_override = _materials[i]
	turret.rotation = Vector3.ZERO
	turret_controller.setup(self)
	global_transform = spawn
	velocity = Vector3.ZERO
	aim_lock = null


func _build_body() -> void:
	var model: TankModel = TankModel.build(self, stats, paint, is_player)
	turret = model.turret
	gun_pivot = model.gun_pivot
	muzzle = model.muzzle
	_meshes = model.own
	_track_material = model.material
	_last_yaw = global_rotation.y
	for mesh in _meshes:
		_materials.append(mesh.material_override)
	var k: float = _scale_factor
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(model.hull_size.x + 1.0 * k, 1.4 * k, model.hull_size.z)
	shape.shape = box
	shape.position.y = 0.75 * k
	add_child(shape)

	if is_player:
		for mesh in _meshes:
			mesh.layers = VISUAL_LAYER_OWN
		camera = Camera3D.new()
		camera.name = "Camera"
		camera.fov = 75.0
		camera.near = 0.1
		camera.far = 600.0
		camera.cull_mask = 1
		camera.position = Vector3(0.0, 0.35, 0.2)
		gun_pivot.add_child(camera)
		camera.current = true


func _build_components() -> void:
	var k: float = _scale_factor
	health = HealthComponent.new()
	health.name = "HealthComponent"
	health.max_health = stats.max_armor
	add_child(health)

	hurtbox = Hurtbox.new()
	hurtbox.name = "Hurtbox"
	hurtbox.collision_layer = LAYER_HURTBOX
	hurtbox.collision_mask = 0
	hurtbox.health = health
	hurtbox.team = team
	var hurt_shape := CollisionShape3D.new()
	var hurt_box := BoxShape3D.new()
	hurt_box.size = Vector3(TankModel.HULL_SIZE.x * stats.hull_proportions.x * k + 1.2 * k, 2.6 * k, TankModel.HULL_SIZE.z * stats.hull_proportions.z * k + 0.2)
	hurt_shape.shape = hurt_box
	hurt_shape.position.y = 1.3 * k
	hurtbox.add_child(hurt_shape)
	add_child(hurtbox)

	var movement := TankMovement.new()
	movement.name = "TankMovement"
	add_child(movement)
	movement.setup(self)

	turret_controller = TurretController.new()
	turret_controller.name = "TurretController"
	add_child(turret_controller)
	turret_controller.setup(self)

	weapon = TankWeapon.new()
	weapon.name = "TankWeapon"
	weapon.projectile_scene = load("res://entities/projectiles/shell.tscn")
	weapon.projectile_speed = stats.projectile_speed
	weapon.damage = stats.damage
	weapon.reload_time = stats.reload_time
	weapon.muzzle = muzzle
	weapon.ignore_rids = [hurtbox.get_rid()]
	weapon.team = team
	weapon.fired.connect(_on_fired)
	add_child(weapon)
