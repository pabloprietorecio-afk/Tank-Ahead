class_name Weather
extends Node3D
## Clima de la partida: despejado, niebla, lluvia (con rayos) o nieve. Se elige al azar.
## Las partículas siguen al jugador, así solo se simulan las que se ven.

enum Kind { CLEAR, FOG, RAIN, SNOW }

const NAMES: Array[String] = ["DESPEJADO", "NIEBLA", "LLUVIA", "NIEVE"]

var kind: Kind = Kind.CLEAR
var environment: Environment
var follow: Node3D
var ground_material: ShaderMaterial

var _particles: GPUParticles3D
var sky: SkyDome
var _rain_loop: AudioStreamPlayer
var _lightning_timer: float = 10.0
var _flash: float = 0.0
var _base_background: Color = Color.BLACK


func setup(env: Environment, target: Node3D, ground: ShaderMaterial, forced: int = -1) -> void:
	environment = env
	follow = target
	ground_material = ground
	kind = (randi() % 4) as Kind if forced < 0 else forced as Kind
	_base_background = env.background_color
	ground_material.set_shader_parameter("tint", 0.0)
	sky = SkyDome.new()
	sky.follow = target
	add_child(sky)
	sky.visible = kind == Kind.CLEAR
	match kind:
		Kind.CLEAR:
			env.fog_density = 0.006
		Kind.FOG:
			env.fog_density = 0.022
			env.fog_light_color = Color(0.05, 0.12, 0.08)
		Kind.RAIN:
			env.fog_density = 0.012
			env.fog_light_color = Color(0.02, 0.06, 0.06)
			_make_particles(900, Vector3(0.03, 0.9, 0.03), Color(0.5, 0.8, 0.9, 0.7), Vector3(2.0, -38.0, 0.0), 0.9)
			_rain_loop = AudioStreamPlayer.new()
			_rain_loop.stream = load("res://assets/audio/rain.wav")
			_rain_loop.volume_db = -12.0
			_rain_loop.finished.connect(_rain_loop.play)
			add_child(_rain_loop)
			_rain_loop.play()
		Kind.SNOW:
			env.fog_density = 0.014
			env.fog_light_color = Color(0.1, 0.13, 0.13)
			ground_material.set_shader_parameter("tint", 0.35)
			_make_particles(700, Vector3(0.14, 0.14, 0.14), Color(0.9, 0.95, 1.0), Vector3(1.5, -4.0, 0.5), 7.0)


func display_name() -> String:
	return NAMES[kind]


func _make_particles(amount: int, drop: Vector3, color: Color, velocity: Vector3, lifetime: float) -> void:
	_particles = GPUParticles3D.new()
	_particles.amount = amount
	_particles.lifetime = lifetime
	_particles.preprocess = lifetime
	_particles.local_coords = false
	_particles.visibility_aabb = AABB(Vector3(-40.0, -30.0, -40.0), Vector3(80.0, 60.0, 80.0))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(35.0, 1.0, 35.0)
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
		_particles.global_position = Vector3(target.x, target.y + 22.0 if kind == Kind.RAIN else target.y + 18.0, target.z)
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
		environment.background_color = _base_background.lerp(Color(0.35, 0.45, 0.45), strength)
		environment.fog_light_color = Color(0.02, 0.06, 0.06).lerp(Color(0.3, 0.4, 0.4), strength)
