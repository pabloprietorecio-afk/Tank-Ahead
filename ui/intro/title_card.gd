class_name TitleCard
extends Control
## El título «A / TANK / STORY» a máquina, tal como queda al final del vídeo de introducción
## (mismas letras, mismo tamaño y mismo sitio), para seguir desde ahí sin que se note el corte.
## Puede moverse y encogerse, y vestirse con la bandera de un idioma (ver title_flag.gdshader).

const WORDS: Array[String] = ["A", "TANK", "STORY"]
const FONT_PATH: String = "res://assets/fonts/SpecialElite-Regular.ttf"
## Medidas del título en el vídeo (1280 × 720): cuerpo de la letra y separación entre renglones.
const SIZE: float = 176.0
const LINE: float = 172.0
## Del centro de la tinta de un renglón a su línea base, en cuerpos de letra (medido en la fuente).
const BASELINE: float = 0.345
## Ancho y alto del bloque entero, en píxeles del vídeo (lo ocupa «STORY» y los tres renglones).
const BLOCK: Vector2 = Vector2(540.0, 478.0)
## La tinta crema del vídeo, tal como queda en él tras el desgaste y la compresión.
const INK := Color(0.8, 0.775, 0.69)

## Centro del bloque (en este control) y píxeles de pantalla por píxel del vídeo.
var center: Vector2 = Vector2.ZERO:
	set(value):
		center = value
		_refresh()
var zoom: float = 1.0:
	set(value):
		zoom = value
		_refresh()
## Idioma cuya bandera viste («» si va en tinta).
var flag: String = ""

var _font: Font
var _material: ShaderMaterial
var _tween: Tween
var _tint: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = load(FONT_PATH)
	_material = ShaderMaterial.new()
	_material.shader = load("res://shaders/title_flag.gdshader")
	_material.set_shader_parameter("ink", INK)
	var blank: ImageTexture = FlagButton.texture("")
	_material.set_shader_parameter("flag_from", blank)
	_material.set_shader_parameter("flag_to", blank)
	material = _material
	_refresh()


func _refresh() -> void:
	if _material == null:
		return
	var size_px: Vector2 = BLOCK * zoom
	_material.set_shader_parameter("block", Vector4(center.x - size_px.x * 0.5, center.y - size_px.y * 0.5, size_px.x, size_px.y))
	queue_redraw()


## Viste el título con la bandera de `code`, pasando poco a poco de la que llevara.
func wear(code: String, seconds: float = 0.45) -> void:
	if code == flag:
		return
	var showing: Variant = _material.get_shader_parameter("flag_to")
	flag = code
	_material.set_shader_parameter("flag_from", showing)
	_material.set_shader_parameter("flag_to", FlagButton.texture(code))
	_material.set_shader_parameter("blend", 0.0)
	if _tween != null:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_method(func(v: float) -> void: _material.set_shader_parameter("blend", v), 0.0, 1.0, seconds)
	_tween.tween_method(_set_tint, _tint, 1.0, seconds)


func _set_tint(value: float) -> void:
	_tint = value
	_material.set_shader_parameter("tint", value)


## Cuánto de bandera lleva ahora mismo (0 tinta, 1 bandera): lo miran las pruebas.
func tint() -> float:
	return _tint


func _draw() -> void:
	var font_size: int = maxi(int(round(SIZE * zoom)), 8)
	var rim: int = maxi(int(round(5.0 * zoom)), 2)
	for pass_fill: bool in [false, true]:
		for i in WORDS.size():
			var word: String = WORDS[i]
			var width: float = _font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
			var at := Vector2(center.x - width * 0.5, center.y + (i - 1) * LINE * zoom + BASELINE * font_size)
			if pass_fill:
				draw_string(_font, at, word, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color.WHITE)
			else:
				# En negro: el sombreador lo pinta como perfil claro (y solo cuando lleva bandera).
				draw_string_outline(_font, at, word, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, rim, Color(0.0, 0.0, 0.0, 1.0))
