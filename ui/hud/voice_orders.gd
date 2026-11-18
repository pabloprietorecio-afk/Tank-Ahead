class_name VoiceOrders
extends Node
## Órdenes por voz a los aliados (botón del micrófono, debajo de los dos iconos de órdenes).
## Entiende cinco órdenes en los diez idiomas del juego (y, en todos ellos, también en inglés):
## «todos conmigo», «atacar a mi objetivo», «localizar objetivo» (la torreta apunta al enemigo a la
## vista más cercano), «lanzar misil» y «solicito bombardeo». Usa el reconocimiento de voz del
## propio Android (plugin SpeechCommands): si el móvil no tiene servicio de voz, o fuera de
## Android, no hay micrófono.
##
## Pulsar para hablar (siempre): una pulsación abre una ventana de unos segundos para dar una
## orden. Mientras dura, el sonido del juego baja con un fundido (AudioSetup.mic_duck), porque
## el micrófono tiene al lado el altavoz y el motor y los cañonazos tapan la voz. Al oír la
## orden, o al agotarse la ventana, el sonido vuelve solo.
##
## Micrófono siempre abierto (ajuste, apagado de serie): además escucha sin que se pulse,
## encadenando una sesión de reconocimiento tras otra (Android corta cada una tras un silencio).
## En este modo NO se toca el sonido: el reconocedor toma el propio ruido del juego por voz, y
## bajarlo cada vez que «oye» algo hacía subir y bajar el volumen sin parar. Va bien con
## auriculares (o con el volumen bajo); con el altavoz alto, para eso está la pulsación.
## Mientras habla la radio del juego no escucha, para no tomar por órdenes sus propias voces
## («¡Todos conmigo! Recibido…», «¡Fuego!»).

## Orden reconocida: "follow", "attack", "locate", "missile" o "strike".
signal order_heard(order: String)
## Ha cambiado lo que enseña el botón o el ajuste (ventana abierta o cerrada, siempre abierto).
signal state_changed
## Aviso para el jugador (se muestra en la línea de mensajes del HUD).
signal notice(text: String, urgent: bool)

const PERMISSION := "android.permission.RECORD_AUDIO"
## Siempre abierto: silencio de la radio antes de volver a escuchar (s).
const RADIO_GAP: float = 0.6
## Pausa tras una orden reconocida (la misma frase no se cuenta dos veces).
const AFTER_ORDER: float = 1.5
## Pulsar para hablar: segundos que se escucha tras una pulsación si no se oye nada. Si el
## reconocedor se rinde antes, se le vuelve a poner a escuchar mientras quede al menos TALK_RETRY;
## y si el jugador está hablando cuando se acaba, se le dejan TALK_FINISH segundos para terminar.
const TALK_WINDOW: float = 6.0
const TALK_RETRY: float = 1.5
const TALK_FINISH: float = 2.0
## Fundidos del sonido del juego al abrir y al cerrar esa ventana (s).
const DUCK_IN: float = 0.12
const DUCK_OUT: float = 0.3

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

## Qué hacer cuando Android conteste a la petición del permiso de micrófono.
enum Pending { NONE, TALK, ALWAYS_OPEN }

## Micrófono siempre abierto (ajuste del jugador, GameSettings.voice_always_open).
var always_open: bool = false
## Lo pone el HUD: el botón se ve y se puede usar (hay aliados, no está en pausa…).
var allowed: bool = false
## Hay una sesión de reconocimiento en marcha.
var listening: bool = false

var _plugin: Object = null
var _available: bool = false
var _handled: bool = false
var _pending: int = Pending.NONE
## Pulsar para hablar: segundos que quedan de ventana (0 = cerrada).
var _talk_left: float = 0.0
## Ya se ha avisado, en esta ventana, de que el micrófono escucha.
var _talk_announced: bool = false
## Segundos hasta poder abrir la siguiente sesión.
var _cooldown: float = 0.0
## Errores seguidos: alargan la espera entre intentos.
var _failures: int = 0
var _radio_quiet: float = 0.0
var _network_warned: bool = false
var _voice: VoiceManager = null
## Bajada del sonido del juego: la de ahora y a la que va (0 = normal, 1 = bajado del todo).
var _duck: float = 0.0
var _duck_target: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_name() == "Android" and Engine.has_singleton("SpeechCommands"):
		_plugin = Engine.get_singleton("SpeechCommands")
		_available = bool(_plugin.isAvailable())
		if _available:
			_plugin.connect("listening_started", _on_ready_to_listen, CONNECT_DEFERRED)
			_plugin.connect("partial_results", _on_partial, CONNECT_DEFERRED)
			_plugin.connect("final_results", _on_final, CONNECT_DEFERRED)
			_plugin.connect("speech_error", _on_error, CONNECT_DEFERRED)
			_plugin.connect("listening_ended", _on_ended, CONNECT_DEFERRED)
			get_tree().on_request_permissions_result.connect(_on_permission)
			GameSettings.ensure_loaded()
			# Sin permiso de micrófono (retirado en los ajustes de Android), el ajuste no vale.
			always_open = GameSettings.voice_always_open and _has_permission()


## Hay micrófono: Android con servicio de reconocimiento de voz.
func available() -> bool:
	return _available


## Está abierta la ventana de «pulsar para hablar» (el micrófono espera una orden).
func talking() -> bool:
	return _talk_left > 0.0


## Pulsación del micro: abre la ventana para dar una orden (otra pulsación la cierra).
func toggle() -> void:
	if not _available:
		return
	if _talk_left > 0.0:
		_close_window()
		return
	# La primera vez Android pregunta por el permiso; al concederlo se abre la ventana.
	if not _has_permission():
		_pending = Pending.TALK
		if not OS.request_permission(PERMISSION):
			return
		_pending = Pending.NONE
	_open_window()


## Ajuste «micrófono siempre abierto» (menú de opciones). Al activarlo sin permiso de micrófono,
## Android pregunta y el ajuste se pone al concederlo (`state_changed` avisa de cómo queda).
func set_always_open(value: bool) -> void:
	if not _available:
		return
	if value and not _has_permission():
		_pending = Pending.ALWAYS_OPEN
		if not OS.request_permission(PERMISSION):
			return
		_pending = Pending.NONE
	_apply_always_open(value)


func _has_permission() -> bool:
	return PERMISSION in OS.get_granted_permissions()


func _apply_always_open(value: bool) -> void:
	always_open = value
	_failures = 0
	_network_warned = false
	if not value and _talk_left <= 0.0:
		_cancel_session()
	if GameSettings.voice_always_open != value:
		GameSettings.voice_always_open = value
		GameSettings.save()
	state_changed.emit()


func _on_permission(permission: String, granted: bool) -> void:
	if permission != PERMISSION or _pending == Pending.NONE:
		return
	var wanted: int = _pending
	_pending = Pending.NONE
	if not granted:
		notice.emit(Loc.t("SIN PERMISO PARA USAR EL MICRÓFONO"), true)
		state_changed.emit()
	elif wanted == Pending.ALWAYS_OPEN:
		_apply_always_open(true)
	elif allowed and not get_tree().paused:
		_open_window()


func _open_window() -> void:
	_talk_left = TALK_WINDOW
	_talk_announced = false
	_failures = 0
	_network_warned = false
	_duck_target = 1.0
	# Con el micro siempre abierto puede haber una sesión en marcha, que ha oído el juego a todo
	# volumen: se descarta y se abre otra con el sonido ya bajado.
	if listening:
		_cancel_session()
	_cooldown = minf(_cooldown, 0.3)
	state_changed.emit()


func _close_window() -> void:
	_talk_left = 0.0
	_duck_target = 0.0
	_cancel_session()
	state_changed.emit()


func _process(delta: float) -> void:
	_fade_duck(delta)
	if not _available:
		return
	_cooldown = maxf(_cooldown - delta, 0.0)
	var usable: bool = allowed and not get_tree().paused
	if _talk_left > 0.0:
		# Ventana de «pulsar para hablar»: se escucha hasta oír algo o hasta que se agote.
		_talk_left -= delta
		if not usable:
			_close_window()
		elif _talk_left <= 0.0 or (not listening and _talk_left < TALK_RETRY):
			_close_window()
			notice.emit(Loc.t("NO TE HE OÍDO"), true)
		elif not listening and _cooldown <= 0.0:
			_start_session()
		return
	# Micrófono siempre abierto: una sesión tras otra, salvo mientras habla la radio.
	var radio: bool = _radio_talking()
	_radio_quiet = 0.0 if radio else _radio_quiet + delta
	var wanted: bool = always_open and usable
	if listening:
		# La radio empieza a hablar (o ya no toca escuchar): se descarta lo que se estaba oyendo.
		if radio or not wanted:
			_cancel_session()
		return
	if wanted and _cooldown <= 0.0 and _radio_quiet >= RADIO_GAP:
		_start_session()


## Lleva el sonido del juego, con un fundido, a como debe estar (bajado solo durante la ventana).
func _fade_duck(delta: float) -> void:
	if is_equal_approx(_duck, _duck_target):
		return
	_duck = move_toward(_duck, _duck_target, delta / (DUCK_IN if _duck_target > _duck else DUCK_OUT))
	AudioSetup.mic_duck = _duck
	AudioSetup.apply_volumes()


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


## Deja de escuchar. La siguiente sesión espera un momento: así los avisos de la que se cancela
## (llegan con unos fotogramas de retraso) no se confunden con los de la nueva.
func _cancel_session() -> void:
	if listening and _plugin != null:
		_plugin.cancel()
	listening = false
	_cooldown = maxf(_cooldown, 0.3)


## El reconocedor ya escucha: en la ventana de «pulsar para hablar» se avisa al jugador.
func _on_ready_to_listen() -> void:
	if listening and _talk_left > 0.0 and not _talk_announced:
		_talk_announced = true
		notice.emit(Loc.t("TE ESCUCHO: DA TU ORDEN"), false)


func _on_partial(text: String) -> void:
	if not listening or _handled:
		return
	if _dispatch(text):
		# Orden reconocida antes de terminar la frase: no hace falta esperar más.
		_after_order()
	elif _talk_left > 0.0:
		# Está hablando: la ventana no se cierra a media frase.
		_talk_left = maxf(_talk_left, TALK_FINISH)


func _on_final(text: String) -> void:
	if not listening or _handled:
		return
	if _dispatch(text):
		_after_order()
		return
	listening = false
	_failures = 0
	_cooldown = maxf(_cooldown, 0.2)
	# Se ha entendido algo, pero no es una orden: se enseña, para saber qué ha oído, y la ventana
	# se cierra (sin texto, en cambio, se sigue escuchando hasta que se agote).
	var heard: String = text.get_slice("\n", 0).strip_edges()
	if heard != "":
		notice.emit(Loc.t("HE OÍDO «%s»: NO ES UNA ORDEN") % heard, true)
		if _talk_left > 0.0:
			_close_window()


## Tras una orden: se cierra la ventana (el sonido vuelve) y no se escucha durante un momento,
## para que la misma frase no cuente dos veces.
func _after_order() -> void:
	_failures = 0
	if _talk_left > 0.0:
		_close_window()
	else:
		_cancel_session()
	_cooldown = AFTER_ORDER


func _on_error(code: int) -> void:
	if not listening:
		return
	listening = false
	match code:
		ERROR_NO_MATCH, ERROR_SPEECH_TIMEOUT:
			# Silencio o ruido: se vuelve a escuchar enseguida (en la ventana, hasta que se agote).
			_failures = 0
			_cooldown = maxf(_cooldown, 0.2)
		ERROR_INSUFFICIENT_PERMISSIONS:
			notice.emit(Loc.t("SIN PERMISO PARA USAR EL MICRÓFONO"), true)
			if _talk_left > 0.0:
				_close_window()
			_apply_always_open(false)
		ERROR_NETWORK, ERROR_NETWORK_TIMEOUT, ERROR_SERVER, ERROR_LANGUAGE_NOT_SUPPORTED, ERROR_LANGUAGE_UNAVAILABLE:
			if not _network_warned:
				_network_warned = true
				notice.emit(Loc.t("RECONOCIMIENTO DE VOZ NO DISPONIBLE: COMPRUEBA LA CONEXIÓN"), true)
			if _talk_left > 0.0:
				_close_window()
			_backoff()
		_:
			_backoff()


## Tras errores seguidos se espera cada vez más (hasta 8 s) para no machacar el servicio de voz.
func _backoff() -> void:
	_failures += 1
	_cooldown = minf(0.5 * pow(2.0, _failures - 1), 8.0)


func _on_ended() -> void:
	listening = false


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
	# El sonido no puede quedarse bajado al salir de la partida.
	_duck = 0.0
	_duck_target = 0.0
	if AudioSetup.mic_duck != 0.0:
		AudioSetup.mic_duck = 0.0
		AudioSetup.apply_volumes()
