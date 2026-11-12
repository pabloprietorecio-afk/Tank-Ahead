class_name UiKit
extends RefCounted
## Controles comunes de los menús, pensados para el dedo: interruptores grandes y desplegables de
## letra grande y filas altas. Los iconos se dibujan por código (no hay imágenes que escalar).

const PANEL_BG := Color(0.07, 0.08, 0.07, 0.98)
const PANEL_BORDER := Color(0.6, 0.5, 0.3)
const ROW_HOVER := Color(0.3, 0.26, 0.16)
const SWITCH_ON := Color(0.2, 0.62, 0.3)
const SWITCH_ON_EDGE := Color(0.5, 0.98, 0.6)
const SWITCH_OFF := Color(0.17, 0.18, 0.17)
const SWITCH_OFF_EDGE := Color(0.66, 0.68, 0.63)

static var _icons: Dictionary = {}


## Interruptor grande (CheckButton) con su texto a la izquierda. Avisa a `on_change(bool)`.
static func toggle(text: String, value: bool, on_change: Callable, font_size: int = 28) -> CheckButton:
	var button := CheckButton.new()
	button.text = text
	button.button_pressed = value
	style_toggle(button, font_size)
	button.toggled.connect(on_change)
	return button


## Pone la letra de `font_size` y un interruptor acorde a un CheckButton ya creado.
static func style_toggle(button: CheckButton, font_size: int) -> void:
	button.add_theme_font_size_override("font_size", font_size)
	var height: int = clampi(roundi(font_size * 1.5), 30, 54)
	for state: String in ["checked", "unchecked", "checked_disabled", "unchecked_disabled", "checked_mirrored", "unchecked_mirrored", "checked_disabled_mirrored", "unchecked_disabled_mirrored"]:
		button.add_theme_icon_override(state, _switch(state.begins_with("checked"), state.contains("disabled"), height))
	button.add_theme_constant_override("h_separation", 16)
	button.custom_minimum_size.y = height + 10.0


## Desplegable (OptionButton). `items` son los textos de la lista y `selected` el que sale
## elegido. `caption`, si se da, es un texto con un %s que rotula el botón («CLIMA: %s»); en la
## lista los elementos salen sin él. Avisa a `on_select(índice)`.
static func dropdown(items: Array, selected: int, on_select: Callable, font_size: int = 28, caption: String = "") -> OptionButton:
	var option := OptionButton.new()
	option.fit_to_longest_item = false
	option.alignment = HORIZONTAL_ALIGNMENT_CENTER
	option.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	option.add_theme_font_size_override("font_size", font_size)
	for item: String in items:
		option.add_item(item)
	var popup: PopupMenu = option.get_popup()
	popup.add_theme_font_size_override("font_size", font_size)
	popup.add_theme_constant_override("v_separation", roundi(font_size * 0.75))
	popup.add_theme_constant_override("h_separation", 14)
	popup.add_theme_constant_override("item_start_padding", 16)
	popup.add_theme_constant_override("item_end_padding", 24)
	option.add_theme_icon_override("arrow", _arrow(clampi(roundi(font_size * 0.7), 14, 28)))
	option.add_theme_constant_override("arrow_margin", 14)
	var mark: int = clampi(roundi(font_size * 0.95), 20, 40)
	popup.add_theme_icon_override("radio_checked", _radio(true, mark))
	popup.add_theme_icon_override("radio_unchecked", _radio(false, mark))
	var panel := StyleBoxFlat.new()
	panel.bg_color = PANEL_BG
	panel.border_color = PANEL_BORDER
	panel.set_border_width_all(2)
	panel.set_corner_radius_all(6)
	panel.set_content_margin_all(8)
	popup.add_theme_stylebox_override("panel", panel)
	var hover := StyleBoxFlat.new()
	hover.bg_color = ROW_HOVER
	hover.set_corner_radius_all(4)
	popup.add_theme_stylebox_override("hover", hover)
	var relabel: Callable = func(index: int) -> void:
		if caption != "" and index >= 0:
			option.text = caption % option.get_item_text(index)
	option.select(clampi(selected, 0, maxi(items.size() - 1, 0)))
	relabel.call(option.selected)
	option.item_selected.connect(func(index: int) -> void:
		relabel.call(index)
		on_select.call(index))
	return option


## Deslizador cómodo para el dedo: pista gruesa y un botón redondo grande. `height` es el alto
## de la zona que se puede tocar.
static func style_slider(slider: HSlider, height: float) -> void:
	var knob: int = clampi(roundi(height * 0.64), 22, 42)
	slider.add_theme_icon_override("grabber", _knob(knob, false))
	slider.add_theme_icon_override("grabber_highlight", _knob(knob, true))
	slider.add_theme_icon_override("grabber_disabled", _knob(knob, false))
	var thickness: float = maxf(knob * 0.28, 6.0)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.2, 0.21, 0.2)
	track.set_corner_radius_all(roundi(thickness * 0.5))
	track.content_margin_top = thickness * 0.5
	track.content_margin_bottom = thickness * 0.5
	slider.add_theme_stylebox_override("slider", track)
	for state: String in ["grabber_area", "grabber_area_highlight"]:
		var fill: StyleBoxFlat = track.duplicate()
		fill.bg_color = Color(0.56, 0.6, 0.52) if state == "grabber_area" else Color(0.66, 0.72, 0.6)
		slider.add_theme_stylebox_override(state, fill)


## Botón redondo de un deslizador.
static func _knob(size: int, highlight: bool) -> ImageTexture:
	var key: String = "k|%s|%d" % [highlight, size]
	if not _icons.has(key):
		var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
		var center := Vector2(size * 0.5, size * 0.5)
		var radius: float = size * 0.5 - 1.0
		var body: Color = Color(1.0, 1.0, 0.97) if highlight else Color(0.9, 0.91, 0.87)
		for y in size:
			for x in size:
				var d: float = Vector2(x + 0.5, y + 0.5).distance_to(center) - radius
				var color: Color = body.lerp(Color(0.3, 0.32, 0.3), clampf(d + 2.5, 0.0, 1.0))
				color.a = clampf(0.5 - d, 0.0, 1.0)
				image.set_pixel(x, y, color)
		_icons[key] = ImageTexture.create_from_image(image)
	return _icons[key]


## Interruptor dibujado: pista redondeada con su borde y el botón a un lado u otro.
static func _switch(on: bool, disabled: bool, height: int) -> ImageTexture:
	var key: String = "s|%s|%s|%d" % [on, disabled, height]
	if not _icons.has(key):
		var width: int = roundi(height * 1.9)
		var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
		var half: float = height * 0.5
		var radius: float = half - 1.0
		var left := Vector2(half, half)
		var right := Vector2(width - half, half)
		var knob_at: Vector2 = right if on else left
		var knob_radius: float = radius - maxf(height * 0.11, 3.0)
		var track: Color = SWITCH_ON if on else SWITCH_OFF
		var edge: Color = SWITCH_ON_EDGE if on else SWITCH_OFF_EDGE
		var knob: Color = Color(0.97, 0.98, 0.95) if on else Color(0.74, 0.75, 0.72)
		var border: float = maxf(height * 0.055, 2.0)
		for y in height:
			for x in width:
				var p := Vector2(x + 0.5, y + 0.5)
				var d: float = Geometry2D.get_closest_point_to_segment(p, left, right).distance_to(p) - radius
				var color: Color = track.lerp(edge, clampf(d + border + 0.5, 0.0, 1.0))
				color.a = clampf(0.5 - d, 0.0, 1.0)
				var k: float = clampf(0.5 - (p.distance_to(knob_at) - knob_radius), 0.0, 1.0)
				if k > 0.0:
					color = Color(color.r, color.g, color.b, maxf(color.a, k)).lerp(Color(knob.r, knob.g, knob.b, 1.0), k)
				if disabled:
					color.a *= 0.4
				image.set_pixel(x, y, color)
		_icons[key] = ImageTexture.create_from_image(image)
	return _icons[key]


## Flecha hacia abajo de un desplegable.
static func _arrow(size: int) -> ImageTexture:
	var key: String = "a|%d" % size
	if not _icons.has(key):
		var height: int = roundi(size * 0.62)
		var image := Image.create(size, height, false, Image.FORMAT_RGBA8)
		for y in height:
			for x in size:
				# Parte del píxel que cae dentro del triángulo (nueve muestras).
				var inside: int = 0
				for sy in 3:
					for sx in 3:
						var px: float = (x + (sx + 0.5) / 3.0) / size
						var py: float = (y + (sy + 0.5) / 3.0) / height
						if absf(px - 0.5) * 2.0 <= 1.0 - py:
							inside += 1
				image.set_pixel(x, y, Color(0.92, 0.9, 0.82, inside / 9.0))
		_icons[key] = ImageTexture.create_from_image(image)
	return _icons[key]


## Marca de elemento elegido en un desplegable: aro, relleno si es el activo.
static func _radio(on: bool, size: int) -> ImageTexture:
	var key: String = "r|%s|%d" % [on, size]
	if not _icons.has(key):
		var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
		var center := Vector2(size * 0.5, size * 0.5)
		var radius: float = size * 0.5 - 2.0
		var ring: float = maxf(size * 0.09, 2.0)
		for y in size:
			for x in size:
				var d: float = Vector2(x + 0.5, y + 0.5).distance_to(center)
				var alpha: float = clampf(0.5 - absf(d - (radius - ring * 0.5)) + ring * 0.5, 0.0, 1.0)
				var color := Color(SWITCH_OFF_EDGE.r, SWITCH_OFF_EDGE.g, SWITCH_OFF_EDGE.b, alpha)
				if on:
					var dot: float = clampf(0.5 - (d - radius * 0.5), 0.0, 1.0)
					color = Color(SWITCH_ON_EDGE.r, SWITCH_ON_EDGE.g, SWITCH_ON_EDGE.b, maxf(alpha, dot))
				image.set_pixel(x, y, color)
		_icons[key] = ImageTexture.create_from_image(image)
	return _icons[key]
