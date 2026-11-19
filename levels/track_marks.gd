class_name TrackMarks
extends Node3D
## Las huellas que dejan las orugas de los tanques: dos tiras de tramos pegados al suelo detrás
## de cada tanque, más marcadas en la arena que en la hierba. Se guardan en dos anillos (uno
## para el jugador, que conserva su rastro mucho más tiempo, y otro para todos los demás): al
## llenarse, los tramos nuevos van borrando los más viejos; además se van apagando con el tiempo.

## Cada cuántos metros de avance deja un tanque un tramo nuevo.
const STEP: float = 1.25
const PLAYER_MARKS: int = 1400
const OTHER_MARKS: int = 1800
## Segundos que tarda una huella en borrarse del todo.
const LIFE: float = 200.0
## Lo marcada que queda la huella en el suelo de cada frente (hierba, arena, tierra negra).
const STRENGTH: Array[float] = [0.55, 0.9, 0.68]
const LIFT: float = 0.04

static var current: TrackMarks

var _rings: Array[MultiMesh] = []
var _next: Array[int] = [0, 0]
var _material: ShaderMaterial
var _clock: float = 0.0
var _strength: float = 0.6
var _beach_dir: Vector2 = Vector2.ZERO
var _beach_from: float = 0.0
## Tramos dejados desde que empezó la partida (para las pruebas).
var stamped: int = 0


func _enter_tree() -> void:
	current = self


func _exit_tree() -> void:
	if current == self:
		current = null


func build(front: int, beach_dir: Vector2 = Vector2.ZERO, beach_from: float = 0.0) -> void:
	_strength = STRENGTH[front]
	_beach_dir = beach_dir
	_beach_from = beach_from
	_material = ShaderMaterial.new()
	_material.shader = load("res://shaders/track_marks.gdshader")
	var dirt: Color = Fronts.ground_colors(front)[2]
	_material.set_shader_parameter("tint", dirt * (0.62 if front == Fronts.Id.AFRICA else 0.5))
	_material.set_shader_parameter("life", LIFE)
	_material.render_priority = -1
	var quad := PlaneMesh.new()
	quad.size = Vector2(1.0, 1.0)
	for capacity: int in [PLAYER_MARKS, OTHER_MARKS]:
		var ring := MultiMesh.new()
		ring.transform_format = MultiMesh.TRANSFORM_3D
		ring.use_custom_data = true
		ring.mesh = quad
		ring.instance_count = capacity
		ring.custom_aabb = AABB(Vector3(-230.0, -2.0, -230.0), Vector3(460.0, 30.0, 460.0))
		var hidden := Transform3D(Basis.from_scale(Vector3.ZERO), Vector3(0.0, -50.0, 0.0))
		for i in capacity:
			ring.set_instance_transform(i, hidden)
			ring.set_instance_custom_data(i, Color(-1000.0, 0.0, 0.0, 0.0))
		var holder := MultiMeshInstance3D.new()
		holder.multimesh = ring
		holder.material_override = _material
		holder.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(holder)
		_rings.append(ring)


func _process(delta: float) -> void:
	_clock += delta
	if _material != null:
		_material.set_shader_parameter("now", _clock)


## Deja un tramo de huella bajo cada oruga. `frame` es el casco del tanque a mitad del tramo
## recorrido, `half_gauge` la distancia del eje a cada oruga, `width` el ancho de la oruga y
## `length` lo avanzado desde el tramo anterior.
func stamp(frame: Transform3D, half_gauge: float, width: float, length: float, from_player: bool) -> void:
	if _rings.is_empty():
		return
	var which: int = 0 if from_player else 1
	var ring: MultiMesh = _rings[which]
	var basis: Basis = frame.basis.orthonormalized()
	var shape := Basis(basis.x * width, basis.y, basis.z * (length + 0.12))
	# En la arena de la playa la huella queda mucho más honda que en la hierba.
	var strength: float = _strength
	if _beach_dir != Vector2.ZERO:
		var toward: float = Vector2(frame.origin.x, frame.origin.z).dot(_beach_dir)
		strength = lerpf(strength, maxf(strength, STRENGTH[1] + 0.05), smoothstep(_beach_from - 12.0, _beach_from + 10.0, toward))
	for side: float in [-1.0, 1.0]:
		var at: Vector3 = frame.origin + basis.x * half_gauge * side + basis.y * LIFT
		ring.set_instance_transform(_next[which], Transform3D(shape, at))
		ring.set_instance_custom_data(_next[which], Color(_clock, strength, 0.0, 0.0))
		_next[which] = (_next[which] + 1) % ring.instance_count
	stamped += 2
