class_name VolumeSliders
extends GridContainer
## Deslizadores de volumen (general, música, efectos, radio) que se guardan al soltarlos.
## Van en una rejilla de pares rótulo + deslizador: `layout()` decide cuántos pares por fila y
## con qué tamaños (uno por fila en el menú principal antiguo, dos o cuatro en los menús nuevos).

var _labels: Array[Label] = []
var _sliders: Array[HSlider] = []


## `per_row` pares por fila, letra de `font_size` y deslizadores de `slider_size`.
static func create(per_row: int = 1, font_size: int = 24, slider_size: Vector2 = Vector2(360.0, 48.0)) -> VolumeSliders:
	GameSettings.ensure_loaded()
	var box := VolumeSliders.new()
	box._row(Loc.t("GENERAL"), GameSettings.master_volume, func(v: float) -> void: GameSettings.master_volume = v)
	box._row(Loc.t("MÚSICA"), GameSettings.music_volume, func(v: float) -> void: GameSettings.music_volume = v)
	box._row(Loc.t("EFECTOS"), GameSettings.sfx_volume, func(v: float) -> void: GameSettings.sfx_volume = v)
	box._row(Loc.t("RADIO"), GameSettings.voice_volume, func(v: float) -> void: GameSettings.voice_volume = v)
	box.layout(per_row, font_size, slider_size)
	return box


func layout(per_row: int, font_size: int, slider_size: Vector2) -> void:
	columns = per_row * 2
	add_theme_constant_override("h_separation", 12)
	add_theme_constant_override("v_separation", 4)
	for i in _labels.size():
		_labels[i].add_theme_font_size_override("font_size", font_size)
		# Entre un par y el siguiente de la misma fila, un poco de aire.
		var title: String = _labels[i].get_meta("title")
		_labels[i].text = title if i % per_row == 0 else "   " + title
		_sliders[i].custom_minimum_size = slider_size
		UiKit.style_slider(_sliders[i], slider_size.y)


func _row(title: String, value: float, setter: Callable) -> void:
	var label := Label.new()
	label.text = title
	label.set_meta("title", title)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(label)
	_labels.append(label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.value_changed.connect(func(v: float) -> void:
		setter.call(v)
		AudioSetup.apply_volumes())
	slider.drag_ended.connect(func(_changed: bool) -> void: GameSettings.save())
	add_child(slider)
	_sliders.append(slider)
