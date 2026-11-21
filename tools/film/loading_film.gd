extends Node
## Filma la pantalla de carga cuadro a cuadro (con su reloj propio, para que salga fluida aunque
## el renderizador vaya despacio) y guarda los cuadros en PNG. Uso:
##   FILM_OUT=/ruta FILM_TITLE="TRAS LA PLAYA" FILM_SECONDS=8 FILM_FPS=30 godot --path . res://tools/film/loading_film.tscn
## Con FILM_CLEAN=1 sale sin título ni barra (solo el carro y el paisaje).

func _ready() -> void:
	var out: String = OS.get_environment("FILM_OUT")
	var seconds: float = float(OS.get_environment("FILM_SECONDS")) if OS.get_environment("FILM_SECONDS") != "" else 8.0
	var fps: int = int(OS.get_environment("FILM_FPS")) if OS.get_environment("FILM_FPS") != "" else 30
	var art := LoadingArt.new()
	art.title = OS.get_environment("FILM_TITLE")
	art.clock = 0.0
	art.captions = OS.get_environment("FILM_CLEAN") == ""
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	var layer := CanvasLayer.new()
	add_child(layer)
	layer.add_child(art)
	await get_tree().process_frame
	await get_tree().process_frame
	var frames: int = int(seconds * fps)
	for i in frames:
		art.clock = float(i) / fps
		# La barra avanza como en una carga de verdad: a tirones y sin llegar al final hasta el último instante.
		var t: float = float(i) / frames
		art.goal = clampf(floorf(t * 9.0) / 8.0, 0.05, 1.0)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/f_%04d.png" % [out, i])
	get_tree().quit()
