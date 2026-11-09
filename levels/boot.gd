extends Control
## Pantalla de arranque de prueba: confirma que el APK se instala y muestra
## la versión y los FPS. Se sustituirá por el menú principal.

@onready var _info: Label = $Info


func _process(_delta: float) -> void:
	var version: String = ProjectSettings.get_setting("application/config/version", "dev")
	_info.text = "TANK AHEAD\nversión %s\n%d FPS" % [version, Engine.get_frames_per_second()]
