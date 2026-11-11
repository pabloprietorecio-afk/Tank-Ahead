extends Node
## Anuncios (Google AdMob), autoload «Ads».
##
## - Intersticial: al terminar una misión de la historia (en «Siguiente misión» y «Jugar otra vez») y
##   al acabar una partida de supervivencia. Nunca durante el combate, ni tras perder en la historia.
## - Recompensado: en la pantalla premium, para jugar una misión de pago una vez.
## - Nada de esto se muestra si el jugador es Premium o si no hay consentimiento (UMP).
##
## Solo funciona en Android con el plugin AdMob; en el ordenador y en los vídeos de comprobación
## no hace nada y las llamadas devuelven enseguida (ver interstitial_then).

## Resultado de un anuncio recompensado: true si el jugador lo vio entero.
signal rewarded_result(granted: bool)
## Cambió algo que la interfaz puede mostrar (estado de consentimiento, anuncio listo...).
signal changed

enum State { OFF, CONSENT, STARTING, READY }

## Política de frecuencia del intersticial.
## Pasos de partida (finales) sin anuncio al empezar la sesión.
const GRACE_ENDS: int = 2
## Como mucho un anuncio cada tantos finales.
const ENDS_PER_AD: int = 2
## Y nunca antes de que pasen tantos milisegundos desde el último (o desde abrir el juego).
const MIN_INTERVAL_MS: int = 180000
## Si un anuncio no llega a abrirse en este tiempo, se sigue sin él.
const SHOW_TIMEOUT_S: float = 4.0
## Reintentos de carga y de consentimiento.
const RETRY_S: float = 60.0
const MAX_RETRIES: int = 4
## Espera inicial para no pedir consentimiento a quien ya es Premium (la compra se consulta al abrir).
const START_DELAY_S: float = 5.0

var state: int = State.OFF

var _admob: Admob
var _ends: int = 0
var _since_ad: int = ENDS_PER_AD - 1
var _last_ad_ms: int = 0
var _after: Callable = Callable()
var _ad_open: bool = false
var _rewarded_open: bool = false
var _earned: bool = false
var _retries: int = 0
var _load_retries_i: int = 0
var _load_retries_r: int = 0
var _loading_i: bool = false
var _loading_r: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_last_ad_ms = Time.get_ticks_msec()
	if not AdsConfig.usable() or OS.get_name() != "Android" or not Engine.has_singleton("AdmobPlugin"):
		return
	PremiumStore.changed.connect(_on_premium_changed)
	get_tree().create_timer(START_DELAY_S).timeout.connect(_start)


## ¿Los anuncios están en marcha en este dispositivo? (No es lo mismo que haya uno cargado.)
func active() -> bool:
	return _admob != null and state == State.READY and not Premium.is_premium()


func rewarded_ready() -> bool:
	return active() and not _rewarded_open and _admob.is_rewarded_ad_loaded()


## ¿Se debe ofrecer el botón del anuncio recompensado? (Hay anuncios en este dispositivo.)
func rewarded_offered() -> bool:
	return active()


## ¿Hay un formulario de consentimiento que el jugador pueda reabrir? (Solo en regiones que lo exigen.)
func privacy_options_available() -> bool:
	if _admob == null or Premium.is_premium():
		return false
	var consent: UserConsent = _admob.get_consent_status()
	if consent == null or consent.status == UserConsent.Status.NOT_REQUIRED:
		return false
	return _admob.is_consent_form_available()


func show_privacy_options() -> void:
	if privacy_options_available():
		_admob.load_consent_form()


## Fin de una partida que admite intersticial. Llama a `done` cuando acabe la pausa publicitaria,
## haya salido un anuncio o no (siempre una sola vez). Si no toca anuncio, `done` se llama ya.
func interstitial_then(done: Callable) -> void:
	_ends += 1
	var due: bool = false
	if _ends > GRACE_ENDS:
		_since_ad += 1
		due = _since_ad >= ENDS_PER_AD and _interstitial_ok()
	if not due:
		done.call()
		return
	_since_ad = 0
	_after = done
	_ad_open = false
	_admob.show_interstitial_ad()
	# Red de seguridad: si el anuncio no llega a abrirse, la partida sigue.
	get_tree().create_timer(SHOW_TIMEOUT_S).timeout.connect(func() -> void:
		if not _ad_open:
			_finish())


## Muestra el anuncio recompensado; el resultado llega por rewarded_result.
func show_rewarded() -> void:
	if not rewarded_ready():
		rewarded_result.emit(false)
		return
	_rewarded_open = true
	_earned = false
	_ad_open = false
	_admob.show_rewarded_ad()
	get_tree().create_timer(SHOW_TIMEOUT_S).timeout.connect(func() -> void:
		if _rewarded_open and not _ad_open:
			_end_rewarded(false))


func _interstitial_ok() -> bool:
	if not active() or _ad_open or _after.is_valid():
		return false
	if Time.get_ticks_msec() - _last_ad_ms < MIN_INTERVAL_MS:
		return false
	return _admob.is_interstitial_ad_loaded()


# ---------------------------------------------------------------- arranque y consentimiento

func _start() -> void:
	if _admob != null or Premium.is_premium():
		return
	_admob = Admob.new()
	# Anuncios reales solo en compilaciones de publicación; en depuración, los de prueba de Google.
	_admob.is_real = AdsConfig.IS_REAL and not OS.is_debug_build()
	_admob.android_real_interstitial_id = AdsConfig.INTERSTITIAL_ID
	_admob.android_real_rewarded_id = AdsConfig.REWARDED_ID
	# Anuncios de hasta «Teen» (el juego es de guerra).
	_admob.max_ad_content_rating = AdmobConfig.ContentRating.T
	# Los anuncios de un solo uso se descartan al cerrarse; se carga otro después.
	_admob.remove_interstitial_ads_after_displayed = true
	add_child(_admob)
	_admob.consent_info_updated.connect(_on_consent_info_updated)
	_admob.consent_info_update_failed.connect(_on_consent_failed)
	_admob.consent_form_loaded.connect(_on_form_loaded)
	_admob.consent_form_failed_to_load.connect(_on_form_failed)
	_admob.consent_form_dismissed.connect(_on_form_dismissed)
	_admob.initialization_completed.connect(_on_initialized)
	_admob.interstitial_ad_loaded.connect(_on_interstitial_loaded)
	_admob.interstitial_ad_failed_to_load.connect(_on_interstitial_load_failed)
	_admob.interstitial_ad_showed_full_screen_content.connect(_on_ad_shown)
	_admob.interstitial_ad_dismissed_full_screen_content.connect(_on_interstitial_closed)
	_admob.interstitial_ad_failed_to_show_full_screen_content.connect(_on_interstitial_show_failed)
	_admob.rewarded_ad_loaded.connect(_on_rewarded_loaded)
	_admob.rewarded_ad_failed_to_load.connect(_on_rewarded_load_failed)
	_admob.rewarded_ad_showed_full_screen_content.connect(_on_ad_shown)
	_admob.rewarded_ad_user_earned_reward.connect(_on_reward_earned)
	_admob.rewarded_ad_dismissed_full_screen_content.connect(_on_rewarded_closed)
	_admob.rewarded_ad_failed_to_show_full_screen_content.connect(_on_rewarded_show_failed)
	_set_state(State.CONSENT)
	_admob.update_consent_info()


func _on_consent_info_updated() -> void:
	var consent: UserConsent = _admob.get_consent_status()
	if consent != null and consent.status == UserConsent.Status.REQUIRED and _admob.is_consent_form_available():
		_admob.load_consent_form()
	else:
		_after_consent()


func _on_consent_failed(_error: FormError) -> void:
	# Sin conexión o error del servicio: si ya hay un consentimiento guardado se sigue; si no, se reintenta.
	if _can_request_ads():
		_after_consent()
	elif _retries < MAX_RETRIES:
		_retries += 1
		get_tree().create_timer(RETRY_S).timeout.connect(func() -> void:
			if _admob != null and state == State.CONSENT:
				_admob.update_consent_info())
	else:
		_set_state(State.OFF)


func _on_form_loaded() -> void:
	_admob.show_consent_form()


func _on_form_failed(_error: FormError) -> void:
	_after_consent()


func _on_form_dismissed(_error: FormError) -> void:
	_after_consent()


func _can_request_ads() -> bool:
	var consent: UserConsent = _admob.get_consent_status()
	if consent == null:
		return false
	return consent.status == UserConsent.Status.NOT_REQUIRED or consent.status == UserConsent.Status.OBTAINED


func _after_consent() -> void:
	if Premium.is_premium():
		_set_state(State.OFF)
		return
	if not _can_request_ads():
		# Consentimiento pendiente o denegado: sin anuncios (el jugador puede reabrirlo en Opciones).
		_set_state(State.OFF)
		return
	if state == State.READY or state == State.STARTING:
		return
	_set_state(State.STARTING)
	_admob.initialize()


func _on_initialized(_status: InitializationStatus) -> void:
	_set_state(State.READY)
	_load_interstitial()
	_load_rewarded()


func _on_premium_changed() -> void:
	if Premium.is_premium() and state != State.OFF:
		_set_state(State.OFF)


func _set_state(value: int) -> void:
	if state == value:
		return
	state = value
	changed.emit()


# ---------------------------------------------------------------- carga de anuncios

func _load_interstitial() -> void:
	if _admob == null or _loading_i or Premium.is_premium():
		return
	_loading_i = true
	_admob.load_interstitial_ad()


func _load_rewarded() -> void:
	if _admob == null or _loading_r or Premium.is_premium():
		return
	_loading_r = true
	_admob.load_rewarded_ad()


func _on_interstitial_loaded(_info: AdInfo, _response: ResponseInfo) -> void:
	_loading_i = false
	_load_retries_i = 0


func _on_interstitial_load_failed(_info: AdInfo, _error: LoadAdError) -> void:
	_loading_i = false
	if _load_retries_i < MAX_RETRIES:
		_load_retries_i += 1
		get_tree().create_timer(RETRY_S * _load_retries_i).timeout.connect(_load_interstitial)


func _on_rewarded_loaded(_info: AdInfo, _response: ResponseInfo) -> void:
	_loading_r = false
	_load_retries_r = 0
	changed.emit()


func _on_rewarded_load_failed(_info: AdInfo, _error: LoadAdError) -> void:
	_loading_r = false
	if _load_retries_r < MAX_RETRIES:
		_load_retries_r += 1
		get_tree().create_timer(RETRY_S * _load_retries_r).timeout.connect(_load_rewarded)


# ---------------------------------------------------------------- mostrar y cerrar

func _on_ad_shown(_info: AdInfo) -> void:
	_ad_open = true


func _on_interstitial_closed(_info: AdInfo) -> void:
	_last_ad_ms = Time.get_ticks_msec()
	_finish()
	_load_interstitial()


func _on_interstitial_show_failed(_info: AdInfo, _error: AdError) -> void:
	_finish()
	_load_interstitial()


## Cierra la pausa publicitaria y deja continuar a quien la pidió (una sola vez).
func _finish() -> void:
	_ad_open = false
	var done: Callable = _after
	_after = Callable()
	if done.is_valid():
		done.call()


func _on_reward_earned(_info: AdInfo, _reward: RewardItem) -> void:
	_earned = true


func _on_rewarded_closed(_info: AdInfo) -> void:
	_end_rewarded(_earned)


func _on_rewarded_show_failed(_info: AdInfo, _error: AdError) -> void:
	_end_rewarded(false)


func _end_rewarded(granted: bool) -> void:
	if not _rewarded_open:
		return
	_rewarded_open = false
	_ad_open = false
	_earned = false
	rewarded_result.emit(granted)
	_load_rewarded()
	changed.emit()
