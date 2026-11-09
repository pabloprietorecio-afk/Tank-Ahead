class_name Weather
extends Node3D
## Clima de la partida: atardecer despejado, niebla, tormenta (lluvia y rayos) o nieve.
## Ajusta cielo, sol, niebla y partículas. Las partículas siguen al jugador.

enum Kind { CLEAR, FOG, RAIN, SNOW }

const NAMES: Array[String] = ["DESPEJADO", "NIEBLA", "LLUVIA", "NIEVE"]

var kind: Kind = Kind.CLEAR
var environment: Environment
var sky_material: ProceduralSkyMaterial
var sun: DirectionalLight3D
var follow: Node3D
var ground_material: ShaderMaterial
var sky: SkyDome

var _particles: GPUParticles3D
var _rain_loop: AudioStreamPlayer
var _lightning_timer: float = 10.0
var _flash: float = 0.0
var _sun_energy: float = 1.0
var _front: int = 0


func setup(env: Environment, sky_mat: ProceduralSkyMaterial, sun_light: DirectionalLight3D, target: Node3D, ground: ShaderMaterial, forced: int = -1, front: int = 0) -> void:
	environment = env
	_front = front
	sky_material = sky_mat
	sun = sun_light
	follow = target
	ground_material = ground
	kind = (randi() % 4) as Kind if forced < 0 else forced as Kind
	ground_material.set_shader_parameter("tint", 0.0)
	ground_material.set_shader_parameter("wet", 0.0)
	# Nubes: encendidas por el sol poniente si está despejado, plomizas con mal tiempo.
	var cloud_tints: Array[Color] = [Color(0.85, 0.5, 0.36), Color(0.22, 0.23, 0.23), Color(0.16, 0.17, 0.19), Color(0.3, 0.31, 0.33)]
	sky_material.sky_cover_modulate = cloud_tints[kind]
	sky = SkyDome.new()
	sky.follow = target
	add_child(sky)
	sky.visible = kind == Kind.CLEAR
	match kind:
		Kind.CLEAR:
			# Atardecer: cielo azul profundo, horizonte cálido, sol bajo.
			_apply(Color(0.05, 0.08, 0.2), Color(0.85, 0.45, 0.25), Color(1.0, 0.75, 0.5), 1.3, 0.004, Color(0.55, 0.4, 0.35))
		Kind.FOG:
			if front == Fronts.Id.AFRICA:
				# Tormenta de arena: niebla ocre y arena volando en horizontal.
				_apply(Color(0.55, 0.42, 0.25), Color(0.75, 0.58, 0.35), Color(1.0, 0.8, 0.55), 0.6, 0.02, Color(0.7, 0.55, 0.35))
				_make_particles(600, Vector3(0.6, 0.04, 0.04), Color(0.8, 0.65, 0.4), Vector3(30.0, -2.0, 6.0), 1.5)
			else:
				_apply(Color(0.35, 0.38, 0.4), Color(0.55, 0.58, 0.58), Color(0.85, 0.88, 0.9), 0.5, 0.025, Color(0.55, 0.58, 0.58))
		Kind.RAIN:
			_apply(Color(0.08, 0.09, 0.11), Color(0.22, 0.25, 0.28), Color(0.6, 0.7, 0.8), 0.35, 0.012, Color(0.2, 0.23, 0.26))
			_make_particles(900, Vector3(0.03, 0.9, 0.03), Color(0.6, 0.7, 0.8), Vector3(2.0, -38.0, 0.0), 0.9)
			ground_material.set_shader_parameter("wet", 1.0)
			_rain_loop = AudioStreamPlayer.new()
			_rain_loop.stream = load("res://assets/audio/rain.wav")
			_rain_loop.volume_db = -12.0
			_rain_loop.bus = AudioSetup.SFX
			add_child(_rain_loop)
			_rain_loop.play()
		Kind.SNOW:
			_apply(Color(0.45, 0.5, 0.58), Color(0.75, 0.78, 0.82), Color(0.9, 0.93, 1.0), 0.7, 0.014, Color(0.72, 0.75, 0.8))
			ground_material.set_shader_parameter("tint", 0.8)
			_make_particles(700, Vector3(0.14, 0.14, 0.14), Color(0.95, 0.97, 1.0), Vector3(1.5, -4.0, 0.5), 7.0)


func display_name() -> String:
	if kind == Kind.FOG and _front == Fronts.Id.AFRICA:
		return "TORMENTA DE ARENA"
	return NAMES[kind]


func _apply(top: Color, horizon: Color, light: Color, energy: float, fog: float, fog_color: Color) -> void:
	sky_material.sky_top_color = top
	sky_material.sky_horizon_color = horizon
	sky_material.ground_horizon_color = horizon.darkened(0.3)
	sky_material.ground_bottom_color = top.darkened(0.5)
	sky_material.sun_angle_max = 20.0
	sun.light_color = light
	sun.light_energy = energy
	_sun_energy = energy
	environment.fog_density = fog
	environment.fog_light_color = fog_color


func _make_particles(amount: int, drop: Vector3, color: Color, velocity: Vector3, lifetime: float) -> void:
	_particles = GPUParticles3D.new()
	_particles.amount = amount
	_particles.lifetime = lifetime
	_particles.preprocess = lifetime
	_particles.local_coords = false
	_particles.visibility_aabb = AABB(Vector3(-40.0, -30.0, -40.0), Vector3(80.0, 60.0, 80.0))
	_particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(35.0, 4.0 if kind == Kind.FOG else 1.0, 35.0)
	process.direction = velocity.normalized()
	process.spread = 4.0
	process.initial_velocity_min = velocity.length() * 0.85
	process.initial_velocity_max = velocity.length() * 1.15
	process.gravity = Vector3.ZERO
	_particles.process_material = process
	var mesh := BoxMesh.new()
	mesh.size = drop
	mesh.material = VectorMaterials.flat(color)
	_particles.draw_pass_1 = mesh
	add_child(_particles)


func _process(delta: float) -> void:
	if follow != null and is_instance_valid(follow) and _particles != null:
		var target: Vector3 = follow.global_position
		_particles.global_position = Vector3(target.x - (30.0 if kind == Kind.FOG else 0.0), target.y + (22.0 if kind == Kind.RAIN else (3.0 if kind == Kind.FOG else 18.0)), target.z)
	if kind != Kind.RAIN:
		return
	_lightning_timer -= delta
	if _lightning_timer <= 0.0:
		_lightning_timer = randf_range(8.0, 20.0)
		_flash = 1.0
		Sfx.play_2d(self, Sfx.THUNDER, -6.0)
	if _flash > 0.0:
		_flash = maxf(_flash - delta * 4.0, 0.0)
		var strength: float = _flash * (0.6 + 0.4 * sin(_flash * 40.0))
		sun.light_energy = _sun_energy + strength * 3.0
		environment.ambient_light_energy = 0.6 + strength * 2.0
