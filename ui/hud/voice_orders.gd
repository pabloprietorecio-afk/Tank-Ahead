class_name VoiceOrders
extends Node
## Órdenes por voz a los aliados (botón del micrófono, debajo de los dos iconos de órdenes).
## Entiende cinco órdenes en los diez idiomas del juego (y, en todos ellos, también en inglés):
## «todos conmigo», «atacar a mi objetivo», «localizar objetivo» (la torreta apunta al enemigo a la
## vista más cercano), «lanzar misil» y «solicito bombardeo». Usa el reconocimiento de voz del propio Android (plugin
## SpeechCommands): si el móvil no tiene servicio de voz, o fuera de Android, no hay micrófono.
##
## Micrófono abierto: una pulsación lo abre y se queda escuchando toda la partida (y las
## siguientes) hasta que se vuelve a pulsar. Android no escucha sin fin: cada sesión de
## reconocimiento acaba tras un silencio, así que se encadena una tras otra.
## Mientras habla la radio del juego no se escucha, para no tomar por órdenes sus propias voces
## («¡Todos conmigo! Recibido…», «¡Fuego!»).

## Orden reconocida: "follow", "attack", "locate", "missile" o "strike".
signal order_heard(order: String)
signal state_changed
## Aviso para el jugador (se muestra en la línea de mensajes del HUD).
signal notice(text: String, urgent: bool)

const PERMISSION := "android.permission.RECORD_AUDIO"
## Silencio de la radio antes de volver a escuchar (s).
const RADIO_GAP: float = 0.6
## Pausa tras una orden reconocida (la misma frase no se cuenta dos veces).
const AFTER_ORDER: float = 1.5
## Mientras hablas, el sonido del juego baja (dB): el motor y los cañonazos por el altavoz tapan la voz.
const DUCK_DB: float = -14.0

## Idioma del juego → idioma del reconocedor.
const LOCALES: Dictionary = {"es": "es-ES", "en": "en-US", "fr": "fr-FR", "it": "it-IT", "ja": "ja-JP",
		"pt": "pt-BR", "id": "id-ID", "hi": "hi-IN", "de": "de-DE", "ru": "ru-RU"}

## Frase de cada orden tal como se enseña (clave de traducción), en el orden en que se comprueban:
## las más concretas primero, porque «localizar objetivo» y «solicito bombardeo» contienen palabras
## de «atacar a mi objetivo» («objetivo», «ataque aéreo»…). Una frase da una sola orden.
const ORDERS: Array[String] = ["locate", "strike", "missile", "follow", "attack"]
const PHRASES: Dictionary = {"follow": "TODOS CONMIGO", "attack": "ATACAR A MI OBJETIVO",
		"locate": "LOCALIZAR OBJETIVO", "missile": "LANZAR MISIL", "strike": "SOLICITO BOMBARDEO"}

## Palabras que disparan cada orden, ya normalizadas (minúsculas, sin tildes). Salvo en japonés,
## cuentan si empiezan una palabra: «ataca» vale para «atacad», «atacar» y «ataca».
const LOCATE_WORDS: Dictionary = {
	"es": ["localiza", "mas cercano", "mas proximo", "busca"],
	"en": ["locate", "nearest", "closest", "find"],
	"fr": ["localise", "plus proche", "trouve", "cherche"],
	"it": ["localizza", "piu vicino", "trova", "cerca"],
	"ja": ["探せ", "探して", "探す", "近い敵", "見つけ"],
	"pt": ["localiz", "mais proximo", "encontr", "procur"],
	"id": ["cari", "terdekat", "temukan", "lacak"],
	"hi": ["ढूंढ", "ढूँढ", "खोज", "नज़दीक", "नजदीक"],
	"de": ["erfass", "lokalisier", "nachste", "finde", "such"],
	"ru": ["найд", "найти", "ближайш", "обнаруж", "локализ"],
}
const STRIKE_WORDS: Dictionary = {
	"es": ["bombarde", "apoyo aereo", "ataque aereo", "artilleria"],
	"en": ["air strike", "airstrike", "air support", "bomb", "artillery"],
	"fr": ["bombard", "frappe aerienne", "soutien aerien", "artillerie"],
	"it": ["bombard", "attacco aereo", "supporto aereo", "artiglieria"],
	"ja": ["爆撃", "空爆", "砲撃"],
	"pt": ["bombarde", "ataque aereo", "apoio aereo", "artilharia"],
	"id": ["bom", "serangan udara", "dukungan udara", "artileri"],
	"hi": ["बमबारी", "हवाई हमला", "हवाई सहायता", "तोपखान"],
	"de": ["bombard", "luftangriff", "luftschlag", "luftunterstutzung", "artillerie"],
	"ru": ["бомб", "авиаудар", "авиаподдерж", "артиллер", "удар с воздуха"],
}
const MISSILE_WORDS: Dictionary = {
	"es": ["misil"],
	"en": ["missile"],
	"fr": ["missile"],
	"it": ["missile"],
	"ja": ["ミサイル"],
	"pt": ["missil", "misseis"],
	"id": ["rudal", "misil"],
	"hi": ["मिसाइल"],
	"de": ["rakete", "flugkorper"],
	"ru": ["ракет"],
}
const FOLLOW_WORDS: Dictionary = {
	"es": ["conmigo", "seguidme", "sigueme", "siganme", "venid", "en formacion"],
	"en": ["follow", "with me", "on me", "form up", "regroup"],
	"fr": ["avec moi", "suivez", "suis moi", "rassemblement"],
	"it": ["con me", "seguitemi", "seguimi", "seguite"],
	"ja": ["ついて", "付いて", "続け", "集合"],
	"pt": ["comigo", "sigam", "siga me", "venham"],
	"id": ["ikut", "bersamaku", "bersama aku", "kumpul"],
	"hi": ["मेरे साथ", "साथ चलो", "मेरे पीछे", "पीछे आओ"],
	"de": ["mir nach", "zu mir", "mit mir", "folgt", "folg mir", "sammeln"],
	"ru": ["за мной", "ко мне", "со мной", "следуй"],
}
const ATTACK_WORDS: Dictionary = {
	"es": ["ataca", "ataque", "fuego", "objetivo"],
	"en": ["attack", "fire", "target", "engage"],
	"fr": ["attaque", "feu", "cible"],
	"it": ["attacca", "fuoco", "obiettivo", "bersaglio"],
	"ja": ["攻撃", "撃て", "うて", "目標"],
	"pt": ["ataca", "ataque", "fogo", "alvo"],
	"id": ["serang", "tembak", "sasaran", "target"],
	"hi": ["हमला", "निशान", "फायर", "आक्रमण"],
	"de": ["angriff", "greif", "feuer", "ziel"],
	"ru": ["атак", "огонь", "цель"],
}
const ACCENTS: Dictionary = {"á": "a", "à": "a", "â": "a", "ä": "a", "ã": "a", "é": "e", "è": "e", "ê": "e",
		"ë": "e", "í": "i", "ì": "i", "î": "i", "ï": "i", "ó": "o", "ò": "o", "ô": "o", "ö": "o", "õ": "o",
		"ú": "u", "ù": "u", "û": "u", "ü": "u", "ç": "c", "ñ": "n", "ß": "ss", "ё": "е"}
const PUNCTUATION: String = ".,;:!?¡¿\"'«»()[]-–—…、。！？「」"

## Códigos de error de android.speech.SpeechRecognizer.
const ERROR_NETWORK_TIMEOUT := 1
const ERROR_NETWORK := 2
const ERROR_SERVER := 4
const ERROR_SPEECH_TIMEOUT := 6
const ERROR_NO_MATCH := 7
const ERROR_INSUFFICIENT_PERMISSIONS := 9
const ERROR_LANGUAGE_NOT_SUPPORTED := 12
const ERROR_LANGUAGE_UNAVAILABLE := 13

## El jugador ha abierto el micrófono (se guarda en los ajustes).
var enabled: bool = false
## Lo pone el HUD: el botón se ve y se puede usar (hay aliados, no está en pausa…).
var allowed: bool = false
## Hay una sesión de reconocimiento en marcha.
var listening: bool = false

var _plugin: Object = null
var _available: bool = false
var _handled: bool = false
var _waiting_permission: bool = false
## Segundos hasta poder abrir la siguiente sesión.
var _cooldown: float = 0.0
## Errores seguidos: alargan la espera entre intentos.
var _failures: int = 0
var _radio_quiet: float = 0.0
var _network_warned: bool = false
var _voice: VoiceManager = null
var _ducked: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_name() == "Android" and Engine.has_singleton("SpeechCommands"):
		_plugin = Engine.get_singleton("SpeechCommands")
		_available = bool(_plugin.isAvailable())
		if _available:
			_plugin.connect("partial_results", _on_partial, CONNECT_DEFERRED)
			_plugin.connect("final_results", _on_final, CONNECT_DEFERRED)
			_plugin.connect("speech_error", _on_error, CONNECT_DEFERRED)
			_plugin.connect("listening_ended", _on_ended, CONNECT_DEFERRED)
			_plugin.connect("speech_begun", _on_speech_begun, CONNECT_DEFERRED)
			get_tree().on_request_permissions_result.connect(_on_permission)
			GameSettings.ensure_loaded()
			# Si lo dejó abierto en la partida anterior (y sigue habiendo permiso), sigue abierto.
			enabled = GameSettings.voice_orders and _has_permission()


## Hay micrófono: Android con servicio de reconocimiento de voz.
func available() -> bool:
	return _available


## Pulsación del micro: lo abre (y se queda abierto) o lo cierra.
func toggle() -> void:
	if not _available:
		return
	if enabled:
		_set_enabled(false)
		notice.emit(Loc.t("MICRÓFONO CERRADO"), false)
		return
	# La primera vez Android pregunta por el permiso; al concederlo se abre.
	if not _has_permission():
		_waiting_permission = true
		if not OS.request_permission(PERMISSION):
			return
		_waiting_permission = false
	_open()


func _has_permission() -> bool:
	return PERMISSION in OS.get_granted_permissions()


func _open() -> void:
	_set_enabled(true)
	_failures = 0
	_cooldown = 0.0
	_network_warned = false
	notice.emit(Loc.t("MICRÓFONO ABIERTO: DA TUS ÓRDENES EN VOZ ALTA"), false)


func _set_enabled(value: bool) -> void:
	enabled = value
	if not value:
		_cancel_session()
	if GameSettings.voice_orders != value:
		GameSettings.voice_orders = value
		GameSettings.save()
	state_changed.emit()


func _on_permission(permission: String, granted: bool) -> void:
	if permission != PERMISSION or not _waiting_permission:
		return
	_waiting_permission = false
	if granted:
		_open()
	else:
		notice.emit(Loc.t("SIN PERMISO PARA USAR EL MICRÓFONO"), true)


func _process(delta: float) -> void:
	if not _available:
		return
	_cooldown = maxf(_cooldown - delta, 0.0)
	var talking: bool = _radio_talking()
	_radio_quiet = 0.0 if talking else _radio_quiet + delta
	var wanted: bool = enabled and allowed and not get_tree().paused
	if listening:
		# La radio empieza a hablar (o ya no toca escuchar): se descarta lo que se estaba oyendo.
		if talking or not wanted:
			_cancel_session()
		return
	if wanted and _cooldown <= 0.0 and _radio_quiet >= RADIO_GAP:
		_start_session()


func _radio_talking() -> bool:
	if _voice == null or not is_instance_valid(_voice):
		_voice = get_tree().get_first_node_in_group(&"voice") as VoiceManager
	return _voice != null and _voice.is_talking()


func _start_session() -> void:
	_handled = false
	listening = true
	var hints := PackedStringArray()
	for order in ORDERS:
		hints.append(Loc.t(PHRASES[order]).to_lower())
	_plugin.startListening(LOCALES.get(Loc.language, "es-ES"), hints)


func _cancel_session() -> void:
	if listening and _plugin != null:
		_plugin.cancel()
	listening = false
	_cooldown = maxf(_cooldown, 0.3)
	_duck(false)


func _on_speech_begun() -> void:
	if listening:
		_duck(true)


func _duck(on: bool) -> void:
	if on == _ducked:
		return
	_ducked = on
	var master: int = AudioServer.get_bus_index(&"Master")
	if on:
		AudioServer.set_bus_volume_db(master, AudioServer.get_bus_volume_db(master) + DUCK_DB)
	else:
		AudioSetup.apply_volumes()


func _on_partial(text: String) -> void:
	if listening and not _handled and _dispatch(text):
		# Orden reconocida antes de terminar la frase: no hace falta esperar más.
		_cancel_session()
		_cooldown = AFTER_ORDER


func _on_final(text: String) -> void:
	if listening and not _handled:
		if _dispatch(text):
			_cooldown = AFTER_ORDER
		else:
			# Se ha entendido algo, pero no es una orden: se enseña, para saber qué ha oído.
			var heard: String = text.get_slice("\n", 0).strip_edges()
			if heard != "":
				notice.emit(Loc.t("HE OÍDO «%s»: NO ES UNA ORDEN") % heard, true)
	_failures = 0
	listening = false
	_duck(false)


func _on_error(code: int) -> void:
	if not listening:
		return
	listening = false
	_duck(false)
	match code:
		ERROR_NO_MATCH, ERROR_SPEECH_TIMEOUT:
			# Silencio o ruido: lo normal con el micro abierto; se vuelve a escuchar enseguida.
			_failures = 0
			_cooldown = 0.2
		ERROR_INSUFFICIENT_PERMISSIONS:
			_set_enabled(false)
			notice.emit(Loc.t("SIN PERMISO PARA USAR EL MICRÓFONO"), true)
		ERROR_NETWORK, ERROR_NETWORK_TIMEOUT, ERROR_SERVER, ERROR_LANGUAGE_NOT_SUPPORTED, ERROR_LANGUAGE_UNAVAILABLE:
			if not _network_warned:
				_network_warned = true
				notice.emit(Loc.t("RECONOCIMIENTO DE VOZ NO DISPONIBLE: COMPRUEBA LA CONEXIÓN"), true)
			_backoff()
		_:
			_backoff()


## Tras errores seguidos se espera cada vez más (hasta 8 s) para no machacar el servicio de voz.
func _backoff() -> void:
	_failures += 1
	_cooldown = minf(0.5 * pow(2.0, _failures - 1), 8.0)


func _on_ended() -> void:
	listening = false
	_duck(false)


## Busca una orden en lo oído (todas las alternativas). Devuelve si ha reconocido alguna.
func _dispatch(text: String) -> bool:
	var order: String = recognize(text, Loc.language)
	if order == "":
		return false
	_handled = true
	order_heard.emit(order)
	return true


## Orden que contiene el texto (alternativas separadas por saltos de línea), o "" si ninguna.
static func recognize(text: String, language: String) -> String:
	var tables: Dictionary = {"locate": LOCATE_WORDS, "strike": STRIKE_WORDS, "missile": MISSILE_WORDS,
			"follow": FOLLOW_WORDS, "attack": ATTACK_WORDS}
	for alternative in text.split("\n", false):
		var clean: String = normalize(alternative)
		for order in ORDERS:
			if matches(clean, language, tables[order]) or matches(clean, "en", tables[order]):
				return order
	return ""


static func normalize(text: String) -> String:
	var out: String = text.to_lower()
	for accent in ACCENTS:
		out = out.replace(accent, ACCENTS[accent])
	for mark in PUNCTUATION:
		out = out.replace(mark, " ")
	while out.contains("  "):
		out = out.replace("  ", " ")
	return " " + out.strip_edges() + " "


## ¿Contiene `clean` (ya normalizado) alguna de las palabras de la orden en ese idioma?
static func matches(clean: String, language: String, words: Dictionary) -> bool:
	for word in words.get(language, []):
		var needle: String = word if language == "ja" else " " + word
		if clean.contains(needle):
			return true
	return false


func _exit_tree() -> void:
	_cancel_session()
	_duck(false)
