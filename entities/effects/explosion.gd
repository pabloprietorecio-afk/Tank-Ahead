class_name Explosion
extends Node3D
## Explosión: destello, bola de fuego que se enfría y se deshace en humo, chispas, cascotes,
## polvo a ras de suelo y marca de quemado. Todo son mallas sencillas con un shader de
## fuego/humo compartido (fire_ball.gdshader); cada bocanada solo cambia sus parámetros
## de instancia, así que no se crean materiales ni partículas de GPU.

const GRAVITY: float = 14.0
const MAX_SCORCH: int = 40
const SMOKE := Color(0.075, 0.07, 0.065)

static var _sphere: SphereMesh
static var _spark_mesh: BoxMesh
static var _chunk_mesh: BoxMesh
static var _scorch_mesh: PlaneMesh

var _strength: float = 1.0
var _color: Color = VectorMaterials.ORANGE
var _time: float = 0.0
var _duration: float = 0.5
var _light: OmniLight3D
var _light_energy: float = 0.0
## Bocanadas: {node, velocity, from, to, life, delay, rise, drag}.
var _puffs: Array[Dictionary] = []
## Chispas y cascotes: {node, velocity, life, spark}.
var _bits: Array[Dictionary] = []


static func spawn(host: Node, point: Vector3, strength: float = 1.0, color: Color = VectorMaterials.ORANGE, silent: bool = false) -> void:
	var tree: SceneTree = host.get_tree()
	var root: Node = tree.current_scene if tree.current_scene != null else tree.root
	var explosion := Explosion.new()
	explosion._strength = strength
	explosion._color = color
	root.add_child(explosion)
	explosion.global_position = point
	explosion._build()
	if not silent:
		if strength < 0.8:
			Sfx.play_at(host, Sfx.HIT, point, 2.0)
		else:
			Sfx.play_at(host, Sfx.EXPLOSION, point, 6.0, 1.1 / clampf(strength, 0.8, 2.0))


func _build() -> void:
	var s: float = _strength
	var big: bool = s >= 0.8
	var on_ground: bool = global_position.y < 3.0
	var hot: bool = _color.r > _color.b + 0.25
	# Destello inicial, casi blanco.
	_puff(Vector3.ZERO, Vector3.ZERO, 0.35 * s, (2.3 if big else 1.6) * s, 0.16 if big else 0.1, 0.0, 2.2 if hot else 0.0, _color if not hot else SMOKE, 0.0, 0.0)
	# Sin fuego (derrumbes, impactos en piedra) la nube es de polvo del color del material.
	var cloud: Color = SMOKE if hot else _color.lerp(Color(0.45, 0.43, 0.4), 0.5)
	var fire_heat: float = 1.0 if hot else 0.0
	if big:
		# Bola de fuego: varias bocanadas que salen, suben y se enfrían.
		for i in 6:
			var dir := Vector3(randf_range(-1.0, 1.0), randf_range(0.1, 1.0), randf_range(-1.0, 1.0)).normalized()
			_puff(dir * 0.5 * s, dir * randf_range(2.0, 5.0) * s, 0.6 * s, randf_range(1.5, 2.3) * s, randf_range(0.6, 1.0) if hot else randf_range(1.2, 1.8), randf_range(0.0, 0.08), fire_heat, cloud, 2.5, 2.2)
		# Columna de humo negro que queda después.
		for i in 5:
			var side := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)) * 0.7 * s
			_puff(side + Vector3.UP * (0.6 + i * 0.35) * s, side * 0.6 + Vector3.UP * randf_range(2.0, 3.6), 0.9 * s, randf_range(2.4, 3.3) * s, randf_range(2.0, 3.0), 0.12 + i * 0.07, 0.0, cloud, 0.6, 0.7)
		if on_ground:
			# Polvo levantado a ras de suelo, en corona.
			var dust: Color = Fronts.ground_colors(GameSession.front)[2].lerp(Color(0.5, 0.47, 0.42), 0.35)
			for i in 8:
				var angle: float = TAU * i / 8.0 + randf_range(-0.3, 0.3)
				var out := Vector3(cos(angle), 0.0, sin(angle))
				_puff(out * 0.8 * s + Vector3.UP * 0.3, out * randf_range(6.0, 10.0) * s + Vector3.UP * 0.6, 0.5 * s, randf_range(1.5, 2.1) * s, randf_range(1.0, 1.5), 0.03, 0.0, dust, 0.3, 3.0)
			if hot:
				_scorch()
		if hot:
			_light = OmniLight3D.new()
			_light.light_color = Color(1.0, 0.62, 0.28)
			_light.omni_range = 16.0 * s
			_light_energy = 6.0
			_light.light_energy = _light_energy
			_light.position.y = 1.0
			add_child(_light)
	else:
		# Impacto pequeño o fogonazo: llamarada breve y una voluta de humo.
		if hot:
			for i in 2:
				var dir := Vector3(randf_range(-1.0, 1.0), randf_range(0.0, 1.0), randf_range(-1.0, 1.0)).normalized()
				_puff(dir * 0.2 * s, dir * 2.5 * s, 0.4 * s, 1.3 * s, 0.28, 0.0, 1.0, SMOKE, 1.0, 3.0)
		_puff(Vector3.ZERO, Vector3.UP * 1.2, 0.5 * s, 2.2 * s, 0.9, 0.05, 0.0, SMOKE.lerp(_color, 0.0 if hot else 0.6).lightened(0.12), 0.6, 1.5)

	# Chispas incandescentes (solo si la explosión es de fuego) y cascotes.
	var sparks: int = 0
	if hot:
		sparks = 14 if big else 5
	for i in sparks:
		var velocity: Vector3 = Vector3(randf_range(-1.0, 1.0), randf_range(0.25, 1.5), randf_range(-1.0, 1.0)).normalized() * randf_range(8.0, 20.0) * maxf(s, 0.5)
		_bit(velocity, randf_range(0.45, 1.0), true)
	for i in (7 if big else 3):
		var velocity: Vector3 = Vector3(randf_range(-1.0, 1.0), randf_range(0.6, 1.6), randf_range(-1.0, 1.0)).normalized() * randf_range(5.0, 11.0) * maxf(s, 0.5)
		_bit(velocity, randf_range(0.9, 1.5), false)


func _puff(pos: Vector3, velocity: Vector3, from: float, to: float, life: float, delay: float, heat: float, tint: Color, rise: float, drag: float) -> void:
	if _sphere == null:
		_sphere = SphereMesh.new()
		_sphere.radius = 0.5
		_sphere.height = 1.0
		_sphere.radial_segments = 16
		_sphere.rings = 8
	var node := MeshInstance3D.new()
	node.mesh = _sphere
	node.material_override = VectorMaterials.effect("res://shaders/fire_ball.gdshader")
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.position = pos
	node.scale = Vector3.ONE * from * 2.0
	node.rotation = Vector3(randf() * TAU, randf() * TAU, 0.0)
	node.visible = delay <= 0.0
	node.set_instance_shader_parameter("life", 0.0)
	node.set_instance_shader_parameter("seed", randf())
	node.set_instance_shader_parameter("heat", heat)
	node.set_instance_shader_parameter("tint", tint)
	add_child(node)
	_puffs.append({"node": node, "velocity": velocity, "from": from * 2.0, "to": to * 2.0, "life": life, "delay": delay, "rise": rise, "drag": drag})
	_duration = maxf(_duration, delay + life)


func _bit(velocity: Vector3, life: float, spark: bool) -> void:
	if _spark_mesh == null:
		_spark_mesh = BoxMesh.new()
		_spark_mesh.size = Vector3(0.05, 0.05, 0.55)
		_chunk_mesh = BoxMesh.new()
		_chunk_mesh.size = Vector3(0.28, 0.2, 0.34)
	var node := MeshInstance3D.new()
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if spark:
		node.mesh = _spark_mesh
		node.material_override = VectorMaterials.flat(Color(1.0, 0.82, 0.4) if randf() < 0.5 else Color(1.0, 0.55, 0.15))
	else:
		node.mesh = _chunk_mesh
		var hot: bool = _color.r > _color.b + 0.25
		node.material_override = VectorMaterials.paint(Color(0.07, 0.06, 0.055) if hot else _color.darkened(0.35))
		node.scale = Vector3(randf_range(0.3, 1.0), randf_range(0.2, 0.6), randf_range(0.3, 0.9)) * clampf(_strength, 0.5, 1.5)
		node.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
	add_child(node)
	_bits.append({"node": node, "velocity": velocity, "life": life, "spark": spark, "spin": Vector3(randf_range(-9.0, 9.0), randf_range(-9.0, 9.0), randf_range(-9.0, 9.0))})
	_duration = maxf(_duration, life)


func _process(delta: float) -> void:
	_time += delta
	if _time >= _duration:
		queue_free()
		return
	if _light != null:
		_light.light_energy = _light_energy * maxf(1.0 - _time / 0.45, 0.0)
	for puff in _puffs:
		var node: MeshInstance3D = puff["node"]
		var t: float = (_time - puff["delay"]) / puff["life"]
		if t < 0.0:
			continue
		if t >= 1.0:
			node.visible = false
			continue
		node.visible = true
		var velocity: Vector3 = puff["velocity"]
		velocity *= exp(-puff["drag"] * delta)
		velocity.y += puff["rise"] * delta
		puff["velocity"] = velocity
		node.position += velocity * delta
		# Crece deprisa al principio y luego se frena.
		var grow: float = 1.0 - pow(1.0 - t, 3.0)
		node.scale = Vector3.ONE * lerpf(puff["from"], puff["to"], grow)
		node.set_instance_shader_parameter("life", t)
	var floor_y: float = 0.08 - global_position.y
	for bit in _bits:
		var node: MeshInstance3D = bit["node"]
		if not node.visible:
			continue
		var t: float = _time / bit["life"]
		if t >= 1.0:
			node.visible = false
			continue
		var velocity: Vector3 = bit["velocity"]
		velocity.y -= GRAVITY * delta
		node.position += velocity * delta
		if bit["spark"]:
			# La chispa se estira en la dirección en que vuela y se apaga.
			if node.position.y < floor_y:
				node.visible = false
				continue
			var dir: Vector3 = velocity.normalized()
			var thin: float = 1.0 - t * 0.8
			node.basis = Basis.looking_at(dir, Vector3.RIGHT if absf(dir.y) > 0.98 else Vector3.UP) * Basis.from_scale(Vector3(thin, thin, clampf(velocity.length() * 0.08, 0.3, 1.6) * thin))
		else:
			if node.position.y < floor_y and velocity.y < 0.0:
				# Un rebote amortiguado y se queda rodando.
				node.position.y = floor_y
				velocity = Vector3(velocity.x * 0.5, -velocity.y * 0.3, velocity.z * 0.5)
				bit["spin"] = (bit["spin"] as Vector3) * 0.4
			node.rotation += (bit["spin"] as Vector3) * delta
			if t > 0.75:
				node.scale *= maxf(1.0 - delta * 5.0, 0.0)
		bit["velocity"] = velocity


## Marca de quemado en el suelo que dura un rato.
func _scorch() -> void:
	var marks: Array[Node] = get_tree().get_nodes_in_group(&"scorch")
	if marks.size() >= MAX_SCORCH:
		marks[0].queue_free()
	if _scorch_mesh == null:
		_scorch_mesh = PlaneMesh.new()
		_scorch_mesh.size = Vector2(1.0, 1.0)
	var mark := MeshInstance3D.new()
	mark.mesh = _scorch_mesh
	mark.material_override = VectorMaterials.effect("res://shaders/scorch.gdshader")
	mark.set_instance_shader_parameter("seed", randf())
	mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mark.scale = Vector3(1.0, 1.0, 1.0) * 6.0 * _strength
	mark.add_to_group(&"scorch")
	get_parent().add_child(mark)
	mark.global_position = Vector3(global_position.x, 0.04, global_position.z)
	mark.rotation.y = randf() * TAU
	get_tree().create_timer(40.0).timeout.connect(mark.queue_free)
