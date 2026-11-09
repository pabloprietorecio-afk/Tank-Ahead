class_name CoverDiorama
extends Node3D
## Portada del menú: un Sherman y un Tiger frente a frente en un campo normando al atardecer,
## con humo, fuego, explosiones lejanas y la cámara girando despacio.

var _camera: Camera3D
var _time: float = 0.0
var _fire_light: OmniLight3D
var _boom_timer: float = 2.0


func _ready() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.08, 0.1, 0.22)
	sky_material.sky_horizon_color = Color(0.95, 0.5, 0.25)
	sky_material.ground_horizon_color = Color(0.6, 0.35, 0.2)
	sky_material.ground_bottom_color = Color(0.05, 0.05, 0.05)
	sky_material.sun_angle_max = 25.0
	var sky := Sky.new()
	sky.sky_material = sky_material
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_density = 0.006
	env.fog_light_color = Color(0.6, 0.38, 0.25)
	env.fog_sky_affect = 0.5
	env.glow_enabled = true
	env.glow_intensity = 0.8
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-12.0), deg_to_rad(-70.0), 0.0)
	sun.light_color = Color(1.0, 0.7, 0.45)
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 80.0
	add_child(sun)

	var ground_mat: ShaderMaterial = VectorMaterials.ground().duplicate()
	var colors: Array[Color] = Fronts.ground_colors(Fronts.Id.NORMANDY)
	ground_mat.set_shader_parameter("grass", colors[0])
	ground_mat.set_shader_parameter("dry_grass", colors[1])
	ground_mat.set_shader_parameter("dirt", colors[2])
	ground_mat.set_shader_parameter("gravel", colors[3])
	ground_mat.set_shader_parameter("grid_strength", 0.0)
	var plane := PlaneMesh.new()
	plane.size = Vector2(600.0, 600.0)
	var ground := MeshInstance3D.new()
	ground.mesh = plane
	ground.material_override = ground_mat
	add_child(ground)

	_tank("m4_sherman", Fronts.Faction.ALLIES, Vector3(5.0, 0.0, 6.0), deg_to_rad(-65.0), deg_to_rad(5.0))
	_tank("tiger1", Fronts.Faction.AXIS, Vector3(17.0, 0.0, -6.0), deg_to_rad(125.0), deg_to_rad(-12.0))
	var wreck := _tank("panzer4", Fronts.Faction.AXIS, Vector3(-14.0, 0.0, -38.0), deg_to_rad(30.0), 0.6)
	for child in wreck.get_children():
		if child is MeshInstance3D:
			child.material_override = VectorMaterials.paint(Color(0.07, 0.06, 0.05))
	_smoke(Vector3(-14.0, 2.0, -38.0))
	_fire_light = OmniLight3D.new()
	_fire_light.light_color = Color(1.0, 0.5, 0.15)
	_fire_light.omni_range = 16.0
	_fire_light.position = Vector3(-14.0, 2.5, -38.0)
	add_child(_fire_light)

	var church := PropFactory.church()
	church.position = Vector3(30.0, 0.0, -60.0)
	church.rotation.y = 0.4
	add_child(church)
	for i in 3:
		var house := PropFactory.house(Vector3(6.0, 4.0, 7.0))
		house.position = Vector3(-35.0 + i * 11.0, 0.0, -55.0 - i * 4.0)
		house.rotation.y = 0.2 * i
		add_child(house)
	var hedge := PropFactory.hedgerow(40.0)
	hedge.position = Vector3(-5.0, 0.0, -35.0)
	add_child(hedge)
	for i in 8:
		var tree := PropFactory.apple_tree(randf_range(4.0, 6.0))
		tree.position = Vector3(randf_range(-40.0, 40.0), 0.0, randf_range(-50.0, -30.0))
		add_child(tree)
	var ruin := PropFactory.ruin(10.0)
	ruin.position = Vector3(30.0, 0.0, -15.0)
	ruin.rotation.y = -0.6
	add_child(ruin)

	_camera = Camera3D.new()
	_camera.fov = 55.0
	_camera.far = 500.0
	add_child(_camera)
	_camera.current = true


func _tank(id: String, faction: int, pos: Vector3, yaw: float, turret_yaw: float) -> Node3D:
	var stats: TankStats = Fronts.tank(id)
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation.y = yaw
	add_child(holder)
	var model: TankModel = TankModel.build(holder, stats, Fronts.paint(Fronts.Id.NORMANDY, faction, stats.nation), false)
	model.turret.rotation.y = turret_yaw
	return holder


func _smoke(at: Vector3) -> void:
	var particles := GPUParticles3D.new()
	particles.amount = 60
	particles.lifetime = 6.0
	particles.preprocess = 6.0
	particles.position = at
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(0.2, 1.0, 0.0)
	process.spread = 12.0
	process.initial_velocity_min = 1.5
	process.initial_velocity_max = 2.5
	process.gravity = Vector3(0.4, 0.3, 0.0)
	process.scale_min = 1.0
	process.scale_max = 3.5
	particles.process_material = process
	var mesh := SphereMesh.new()
	mesh.radius = 0.8
	mesh.height = 1.6
	mesh.radial_segments = 6
	mesh.rings = 3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.11, 0.1, 0.55)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = mat
	particles.draw_pass_1 = mesh
	add_child(particles)


func _process(delta: float) -> void:
	_time += delta
	var sway: float = sin(_time * 0.06)
	_camera.position = Vector3(-4.0 + sway * 3.0, 4.2, 20.0)
	_camera.look_at(Vector3(-3.0 + sway * 2.0, 2.2, -4.0))
	_fire_light.light_energy = 3.0 + sin(_time * 13.0) * 0.8 + sin(_time * 7.3) * 0.6
	_boom_timer -= delta
	if _boom_timer <= 0.0:
		_boom_timer = randf_range(3.0, 7.0)
		Explosion.spawn(self, Vector3(randf_range(-60.0, 60.0), 1.0, randf_range(-90.0, -60.0)), 1.6, VectorMaterials.ORANGE, true)
