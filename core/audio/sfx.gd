class_name Sfx
## Efectos de sonido de un solo disparo. Cada sonido crea un reproductor que se borra al terminar.

const CANNON := preload("res://assets/audio/cannon.ogg")
const EXPLOSION := preload("res://assets/audio/explosion.ogg")
const HIT := preload("res://assets/audio/hit.ogg")
const HIT_TANK := preload("res://assets/audio/hit_tank.ogg")
const PICKUP := preload("res://assets/audio/pickup.ogg")
const BELL := preload("res://assets/audio/bell.ogg")
const ENGINE_PLANE := preload("res://assets/audio/plane.ogg")
const MISSILE := preload("res://assets/audio/missile.ogg")
const ALARM := preload("res://assets/audio/alarm.ogg")
const THUNDER := preload("res://assets/audio/thunder.wav")


static func play_at(host: Node, stream: AudioStream, point: Vector3, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.bus = AudioSetup.SFX
	player.volume_db = volume_db
	player.pitch_scale = pitch * randf_range(0.92, 1.08)
	# Atenuación suave: las explosiones cercanas suenan fuertes y las lejanas aún se oyen.
	player.unit_size = 22.0
	player.max_distance = 500.0
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	_root(host).add_child(player)
	player.global_position = point
	player.finished.connect(player.queue_free)
	player.play()


static func play_2d(host: Node, stream: AudioStream, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = AudioSetup.SFX
	player.volume_db = volume_db
	player.pitch_scale = pitch * randf_range(0.95, 1.05)
	_root(host).add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


static func _root(host: Node) -> Node:
	var tree: SceneTree = host.get_tree()
	return tree.current_scene if tree.current_scene != null else tree.root
