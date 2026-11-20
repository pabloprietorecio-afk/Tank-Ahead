class_name Ambience
extends Node
## Sonido de ambiente del campo, todo grabaciones reales (ver assets/audio/CREDITS.md):
## - Un fondo propio de cada frente: pájaros y brisa en el bocage normando, viento en el
##   desierto, grillos y pájaros en la estepa de Kursk. Con lluvia o nieve no hay pájaros ni
##   grillos (el viento del desierto sí sigue).
## - En las misiones con mar, el oleaje, que suena desde la orilla y más cuanto más cerca se
##   está, y de tarde en tarde una gaviota sobre el agua (patiamarilla en el Mediterráneo,
##   argéntea en el Canal).
## Va bajo: es el fondo sobre el que suenan motores y cañonazos.

const BEDS: Array[String] = ["res://assets/audio/amb_normandy.wav", "res://assets/audio/amb_africa.wav", "res://assets/audio/amb_kursk.wav"]
const BED_DB: Array[float] = [-5.0, -4.0, -5.0]
const SEA := "res://assets/audio/amb_sea.wav"
const GULLS: Array[String] = ["res://assets/audio/gull_herring.ogg", "res://assets/audio/gull_med.ogg", ""]
const GULL_GAP := Vector2(11.0, 30.0)

var player: Node3D
var front: int = 0
var weather: int = Weather.Kind.SUNNY
var sea_side: Vector2 = Vector2.ZERO

var _sea: AudioStreamPlayer3D
var _gull: AudioStream
var _gull_wait: float = 6.0


func _ready() -> void:
	var dry: bool = weather != Weather.Kind.RAIN and weather != Weather.Kind.SNOW
	if (dry or front == Fronts.Id.AFRICA) and ResourceLoader.exists(BEDS[front]):
		var bed := AudioStreamPlayer.new()
		bed.name = "Bed"
		bed.stream = load(BEDS[front])
		bed.bus = AudioSetup.SFX
		bed.volume_db = BED_DB[front]
		add_child(bed)
		bed.play(randf() * bed.stream.get_length())
	if sea_side == Vector2.ZERO:
		return
	if ResourceLoader.exists(SEA):
		_sea = AudioStreamPlayer3D.new()
		_sea.name = "Sea"
		_sea.stream = load(SEA)
		_sea.bus = AudioSetup.SFX
		_sea.volume_db = 7.0
		_sea.unit_size = 34.0
		_sea.max_distance = 520.0
		_sea.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(_sea)
		_sea.play(randf() * _sea.stream.get_length())
	if dry and GULLS[front] != "" and ResourceLoader.exists(GULLS[front]):
		_gull = load(GULLS[front])


func _process(delta: float) -> void:
	if sea_side == Vector2.ZERO or not is_instance_valid(player):
		return
	var here: Vector3 = player.global_position
	var along := Vector2(absf(sea_side.y), absf(sea_side.x))
	var slide: float = clampf(Vector2(here.x, here.z).dot(along), -260.0, 260.0)
	if _sea != null:
		# El oleaje suena desde el punto de la orilla más cercano al jugador.
		var shore: Vector2 = sea_side * (Backdrop.SHORE + 6.0) + along * slide
		_sea.global_position = Vector3(shore.x, 1.0, shore.y)
	if _gull == null:
		return
	_gull_wait -= delta
	if _gull_wait <= 0.0:
		_gull_wait = randf_range(GULL_GAP.x, GULL_GAP.y)
		var spot: Vector2 = sea_side * (Backdrop.SHORE + randf_range(10.0, 90.0)) + along * (slide + randf_range(-140.0, 140.0))
		Sfx.play_at(self, _gull, Vector3(spot.x, randf_range(12.0, 30.0), spot.y), 3.0, 1.0)
