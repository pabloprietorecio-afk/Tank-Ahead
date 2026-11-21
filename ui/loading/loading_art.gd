class_name LoadingArt
extends Control
## El dibujo de la pantalla de carga: un carro de perfil que avanza por un terreno ondulado, con
## las ruedas girando, los eslabones corriendo por la cadena y el casco cabeceando con la
## pendiente; detrás, dos líneas de colinas que pasan más despacio. Debajo, «CARGANDO…» y una
## barra fina. Todo son trazos y rellenos planos, a dos tintas, dibujados por código (no hay
## imagen que cargar: la pantalla aparece al instante y se ve nítida a cualquier tamaño).

const INK := Color(0.91, 0.88, 0.78)
const INK_SOFT := Color(0.91, 0.88, 0.78, 0.5)
const ACCENT := Color(1.0, 0.84, 0.3)
const SKY_TOP := Color(0.05, 0.06, 0.05)
const SKY_LOW := Color(0.12, 0.13, 0.1)
## Las colinas, más claras cuanto más lejos (la bruma); el suelo, lo más oscuro.
const HILL_FAR := Color(0.15, 0.17, 0.15)
const HILL_MID := Color(0.115, 0.135, 0.105)
const GROUND := Color(0.06, 0.07, 0.055)
## Velocidad del carro (píxeles por segundo a tamaño 1) y tamaño de diseño del dibujo.
const SPEED: float = 150.0
## Tamaño del carro respecto al terreno.
const SCALE: float = 1.45
const WHEEL_R: float = 12.5
const WHEELS: Array[float] = [-58.0, -29.0, 0.0, 29.0, 58.0]

var title: String = ""
## Hasta dónde debe llegar la barra (0..1); la barra se acerca a ese punto con suavidad.
var goal: float = 0.0

## Sin título, «CARGANDO…» ni barra: solo el carro y el paisaje (para filmar una lámina limpia).
var captions: bool = true
## Reloj propio (s) para filmar la pantalla cuadro a cuadro; negativo, el reloj de verdad.
var clock: float = -1.0
var _shown: float = 0.0
var _travel: float = 0.0
var _last: int = 0
var _font: Font
var _track: PackedVector2Array
var _track_length: float = 0.0


func _ready() -> void:
	_font = get_theme_default_font()
	_last = _now_msec()
	_track = _track_loop()
	for i in _track.size():
		_track_length += _track[i].distance_to(_track[(i + 1) % _track.size()])


func _process(_delta: float) -> void:
	# Con el reloj de verdad: aunque el juego esté ocupado montando el campo y los cuadros
	# lleguen a saltos, el carro ha avanzado lo que toca.
	var now: int = _now_msec()
	var passed: float = minf((now - _last) / 1000.0, 0.5)
	_last = now
	_travel += SPEED * passed
	_shown = move_toward(_shown, goal, passed * 0.9) if _shown < goal else goal
	queue_redraw()


func _now_msec() -> int:
	return int(clock * 1000.0) if clock >= 0.0 else Time.get_ticks_msec()


## Altura del terreno (píxeles hacia arriba, a tamaño 1) en el punto `x` del recorrido.
func _height(x: float) -> float:
	return sin(x * 0.011) * 13.0 + sin(x * 0.027 + 1.3) * 5.5 + sin(x * 0.0043 + 0.6) * 9.0


func _draw() -> void:
	var area: Vector2 = size
	var unit: float = clampf(minf(area.x / 1280.0, area.y / 720.0), 0.5, 2.5)
	# Fondo: degradado de arriba abajo.
	var corners := PackedVector2Array([Vector2.ZERO, Vector2(area.x, 0.0), area, Vector2(0.0, area.y)])
	draw_polygon(corners, PackedColorArray([SKY_TOP, SKY_TOP, SKY_LOW, SKY_LOW]))
	var ground_y: float = area.y * 0.56
	var center := Vector2(area.x * 0.5, ground_y)
	# Colinas lejanas: pasan más despacio que el suelo.
	_hills(area, ground_y - 128.0 * unit, 0.12, 0.0031, 44.0 * unit, HILL_FAR, unit)
	_hills(area, ground_y - 66.0 * unit, 0.3, 0.0052, 30.0 * unit, HILL_MID, unit)
	# Suelo: el perfil por el que rueda el carro.
	var profile := PackedVector2Array()
	var steps: int = 96
	for i in steps + 1:
		var x: float = area.x * i / steps
		profile.append(Vector2(x, ground_y - _height((x - center.x) / unit + _travel) * unit))
	var body: PackedVector2Array = profile.duplicate()
	body.append(Vector2(area.x, area.y))
	body.append(Vector2(0.0, area.y))
	draw_colored_polygon(body, GROUND)
	draw_polyline(profile, INK_SOFT, 2.0 * unit, true)
	_roadside(area, center, ground_y, unit)
	_tank(center, unit)
	if captions:
		_caption(area, ground_y, unit)


func _hills(area: Vector2, base: float, parallax: float, wave: float, tall: float, color: Color, unit: float) -> void:
	var points := PackedVector2Array()
	var steps: int = 64
	for i in steps + 1:
		var x: float = area.x * i / steps
		var at: float = x / unit + _travel * parallax
		points.append(Vector2(x, base - (sin(at * wave) * 0.6 + sin(at * wave * 2.3 + 2.0) * 0.4) * tall))
	points.append(Vector2(area.x, area.y))
	points.append(Vector2(0.0, area.y))
	draw_colored_polygon(points, color)


## Lo que pasa junto al camino y da la sensación de avance: postes de telégrafo con su cable,
## matas y piedras.
func _roadside(area: Vector2, center: Vector2, ground_y: float, unit: float) -> void:
	var gap: float = 230.0
	var first: float = floorf((_travel - area.x * 0.5 / unit) / gap) * gap
	var previous := Vector2.INF
	var along: float = first
	while along < _travel + area.x * 0.5 / unit + gap:
		var x: float = center.x + (along - _travel) * unit
		var foot := Vector2(x, ground_y - _height(along) * unit)
		var top: Vector2 = foot - Vector2(0.0, 84.0 * unit)
		draw_line(foot, top, INK_SOFT, 2.0 * unit, true)
		draw_line(top + Vector2(-9.0, 8.0) * unit, top + Vector2(9.0, 8.0) * unit, INK_SOFT, 2.0 * unit, true)
		if previous != Vector2.INF:
			# El cable, con su comba.
			var wire := PackedVector2Array()
			for n in 13:
				var t: float = n / 12.0
				wire.append(previous.lerp(top, t) + Vector2(0.0, (8.0 + sin(t * PI) * 16.0) * unit))
			draw_polyline(wire, Color(INK, 0.22), 1.2 * unit, true)
		previous = top
		# Entre poste y poste, una mata y una piedra.
		for extra: Array in [[0.37, 0], [0.71, 1]]:
			var at: float = along + gap * extra[0]
			var spot := Vector2(center.x + (at - _travel) * unit, ground_y - _height(at) * unit)
			if extra[1] == 0:
				for blade: float in [-0.5, 0.0, 0.45]:
					draw_line(spot, spot + Vector2(blade * 9.0, -9.0 - absf(blade) * 3.0) * unit, INK_SOFT, 1.6 * unit, true)
			else:
				draw_arc(spot + Vector2(0.0, 1.0) * unit, 5.0 * unit, PI, TAU, 8, INK_SOFT, 1.6 * unit, true)
		along += gap


## Recorrido de la cadena alrededor de las ruedas (en el sistema del carro, y hacia abajo).
func _track_loop() -> PackedVector2Array:
	var loop := PackedVector2Array()
	var rear := Vector2(-84.0, -15.0)
	var front := Vector2(84.0, -15.0)
	var radius: float = 13.5
	# Tramo de arriba (de atrás adelante), con una ligera comba entre los rodillos.
	for n in 9:
		var t: float = n / 8.0
		loop.append(Vector2(lerpf(rear.x, front.x, t), rear.y - radius + sin(t * PI * 3.0) * 1.2))
	# Rueda tractora, delante.
	for n in 7:
		var angle: float = -PI * 0.5 + (n + 1) * (PI * 0.72) / 7.0
		loop.append(front + Vector2(cos(angle), sin(angle)) * radius)
	# Tramo de abajo, bajo las ruedas de rodaje.
	loop.append(Vector2(WHEELS[4] + 9.0, WHEEL_R))
	loop.append(Vector2(WHEELS[0] - 9.0, WHEEL_R))
	# Rueda tensora, detrás.
	for n in 7:
		var angle: float = PI * 0.78 + n * (PI * 0.72) / 7.0
		loop.append(rear + Vector2(cos(angle), sin(angle)) * radius)
	return loop


func _tank(center: Vector2, unit: float) -> void:
	# El carro se apoya en el terreno bajo su primera y su última rueda: de ahí su altura y su
	# cabeceo. Un pelo de balanceo de la suspensión lo hace vivo.
	var rear_h: float = _height(_travel - 70.0 * SCALE)
	var front_h: float = _height(_travel + 70.0 * SCALE)
	var pitch: float = -atan2(front_h - rear_h, 140.0 * SCALE)
	var sway: float = sin(_travel * 0.05) * 0.012
	var lift: float = (rear_h + front_h) * 0.5 + sin(_travel * 0.085) * 0.7
	var scale_now: float = unit * SCALE
	var at: Vector2 = center + Vector2(0.0, -lift * unit - (WHEEL_R + 1.7) * scale_now)
	_dust(center, unit)
	draw_set_transform(at, pitch + sway, Vector2(scale_now, scale_now))
	# Cadena: el lazo y los eslabones que corren por él.
	var closed: PackedVector2Array = _track.duplicate()
	closed.append(_track[0])
	draw_polyline(closed, INK, 3.4, true)
	var spacing: float = 8.0
	var links: int = int(_track_length / spacing)
	var shift: float = fposmod(_travel / SCALE, spacing)
	for i in links:
		var where: Array = _along_track(i * spacing + shift)
		var point: Vector2 = where[0]
		var normal: Vector2 = where[1]
		draw_line(point - normal * 1.2, point + normal * 3.4, INK, 1.5, true)
	# Ruedas de rodaje con su radio (gira con lo recorrido), tractora y tensora.
	var spin: float = _travel / SCALE / WHEEL_R
	for x: float in WHEELS:
		_wheel(Vector2(x, 0.0), WHEEL_R - 2.2, spin, false)
	_wheel(Vector2(84.0, -15.0), 9.5, spin * 1.2, true)
	_wheel(Vector2(-84.0, -15.0), 9.5, spin * 1.2, false)
	for x: float in [-43.5, 0.0, 43.5]:
		draw_circle(Vector2(x, -26.0), 2.6, INK)
	# Casco, con el frontal inclinado, y el guardabarros.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-101.0, -35.0), Vector2(-97.0, -57.0), Vector2(46.0, -58.0), Vector2(88.0, -46.0), Vector2(106.0, -35.0)]), INK)
	draw_line(Vector2(-106.0, -32.0), Vector2(110.0, -32.0), INK, 2.4, true)
	# Torreta, cúpula, mantelete y cañón con su freno de boca.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-46.0, -61.0), Vector2(-39.0, -84.0), Vector2(16.0, -86.0), Vector2(36.0, -76.0), Vector2(40.0, -61.0)]), INK)
	draw_rect(Rect2(-27.0, -92.0, 19.0, 6.0), INK)
	draw_rect(Rect2(33.0, -80.0, 9.0, 13.0), INK)
	draw_line(Vector2(40.0, -73.5), Vector2(128.0, -77.0), INK, 5.0, true)
	draw_rect(Rect2(124.0, -81.5, 11.0, 9.0), INK)
	# Antena, que cimbrea, y la caja de herramientas de atrás.
	var whip: float = sin(_travel * 0.06) * 5.0
	draw_polyline(PackedVector2Array([Vector2(-36.0, -84.0), Vector2(-39.0 - whip * 0.3, -104.0), Vector2(-44.0 - whip, -124.0)]), INK, 1.4, true)
	draw_rect(Rect2(-95.0, -65.0, 25.0, 9.0), INK)
	# Detalles en hueco sobre el relleno: escotilla, visor y tapa del motor.
	draw_line(Vector2(-12.0, -78.0), Vector2(6.0, -78.5), GROUND, 1.6, true)
	draw_rect(Rect2(58.0, -50.0, 12.0, 3.0), GROUND)
	for x: float in [-84.0, -76.0, -68.0]:
		draw_line(Vector2(x, -53.0), Vector2(x, -42.0), GROUND, 1.6, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Rueda: llanta, disco y seis taladros de aligeramiento que giran con ella. La tractora lleva
## además los dientes que arrastran la cadena.
func _wheel(at: Vector2, radius: float, spin: float, toothed: bool) -> void:
	draw_arc(at, radius, 0.0, TAU, 28, INK, 2.2, true)
	draw_circle(at, radius * 0.34, INK)
	for n in 6:
		var angle: float = spin + TAU * n / 6.0
		var out := Vector2(cos(angle), sin(angle))
		draw_circle(at + out * radius * 0.64, 1.25, INK)
		if toothed:
			draw_line(at + out * radius, at + out * (radius + 2.6), INK, 1.6, true)


## Punto y normal (hacia fuera) de la cadena a `distance` píxeles de su inicio.
func _along_track(distance: float) -> Array:
	var left: float = fposmod(distance, _track_length)
	for i in _track.size():
		var a: Vector2 = _track[i]
		var b: Vector2 = _track[(i + 1) % _track.size()]
		var length: float = a.distance_to(b)
		if left <= length:
			var direction: Vector2 = (b - a) / maxf(length, 0.001)
			return [a.lerp(b, left / maxf(length, 0.001)), Vector2(direction.y, -direction.x)]
		left -= length
	return [_track[0], Vector2.UP]


## Polvo que levanta la cadena por detrás: bocanadas que nacen junto al suelo, suben, crecen y
## se deshacen. Salen de lo recorrido, así que no hace falta guardar nada.
func _dust(center: Vector2, unit: float) -> void:
	var gap: float = 34.0
	var tail: float = 104.0 * SCALE
	for i in 7:
		var born: float = floorf(_travel / gap) * gap - i * gap
		var age: float = (_travel - born) / (gap * 7.0)
		if age < 0.0 or age > 1.0:
			continue
		var wobble: float = sin(born * 12.9898) * 43758.5453
		wobble = wobble - floorf(wobble)
		# Nace junto a la cadena y el carro la va dejando atrás (el aire la arrastra un poco).
		var behind: float = tail + (_travel - born) * 0.62
		var x: float = center.x - behind * unit
		var y: float = center.y - (_height(_travel - behind) + 5.0 + age * (24.0 + wobble * 22.0)) * unit
		draw_circle(Vector2(x, y), (5.0 + age * 17.0 + wobble * 4.0) * unit, Color(INK, 0.2 * (1.0 - age) * (1.0 - age)))


func _caption(area: Vector2, ground_y: float, unit: float) -> void:
	var middle: float = area.x * 0.5
	if title != "":
		var title_size: int = int(30.0 * unit)
		var title_width: float = _font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1.0, title_size).x
		draw_string(_font, Vector2(middle - title_width * 0.5, area.y * 0.2), title, HORIZONTAL_ALIGNMENT_LEFT, -1.0, title_size, ACCENT)
	# «CARGANDO» con las letras separadas y tres puntos que se van encendiendo.
	var word: String = Loc.t("CARGANDO…").replace("…", "").replace("...", "")
	var font_size: int = int(22.0 * unit)
	# Letras separadas solo en alfabetos de letras sueltas: en los demás (devanagari, japonés)
	# separar rompería la escritura.
	var loose: bool = true
	for i in word.length():
		if word.unicode_at(i) >= 0x0530:
			loose = false
	var spread: float = 7.0 * unit if loose else 0.0
	if not loose:
		var whole: float = _font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
		var start := Vector2(middle - (whole + 3.0 * 13.0 * unit) * 0.5, ground_y + 128.0 * unit)
		draw_string(_font, start, word, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, INK)
		_dots(start + Vector2(whole + 4.0 * unit, 0.0), unit)
		_bar(middle, ground_y, unit)
		return
	var width: float = 0.0
	for i in word.length():
		width += _font.get_string_size(word[i], HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x + spread
	var dots_width: float = 3.0 * 13.0 * unit
	var pen := Vector2(middle - (width + dots_width) * 0.5, ground_y + 128.0 * unit)
	for i in word.length():
		draw_string(_font, pen, word[i], HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, INK)
		pen.x += _font.get_string_size(word[i], HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x + spread
	_dots(pen, unit)
	_bar(middle, ground_y, unit)


func _dots(pen: Vector2, unit: float) -> void:
	var beat: float = fposmod(_now_msec() / 1000.0 * 1.6, 4.0)
	for i in 3:
		draw_circle(pen + Vector2((i + 0.5) * 13.0 * unit, -2.5 * unit), 2.4 * unit, Color(INK, 1.0 if beat > i + 1.0 else 0.25))


## Barra de avance.
func _bar(middle: float, ground_y: float, unit: float) -> void:
	var bar_width: float = 330.0 * unit
	var bar := Vector2(middle - bar_width * 0.5, ground_y + 152.0 * unit)
	draw_line(bar, bar + Vector2(bar_width, 0.0), Color(INK, 0.18), 3.0 * unit, true)
	if _shown > 0.002:
		draw_line(bar, bar + Vector2(bar_width * _shown, 0.0), ACCENT, 3.0 * unit, true)
		draw_circle(bar + Vector2(bar_width * _shown, 0.0), 3.4 * unit, ACCENT)
