extends Node
## Compra de Premium (pago único) con Google Play Billing. Es un autoload («PremiumStore»).
##
## El producto debe existir en Play Console (Monetizar > Productos > Productos de un solo pago)
## con el ID PRODUCT_ID. Al abrir el juego se consultan las compras de la cuenta de Google: si
## consta la compra se activa Premium y, si ya no consta (reembolso), se quita. Sin conexión se
## usa el valor guardado (Premium.is_premium()).
## Fuera de Android (o sin el plugin) no hay compras: available() es false.

signal changed

const PRODUCT_ID: String = "premium"

enum State { UNAVAILABLE, CONNECTING, READY, BUSY }

var state: int = State.UNAVAILABLE
## Precio con formato de Google Play y moneda del usuario (por ejemplo «2,99 €»); vacío si aún no se conoce.
var price: String = ""
## Último aviso para el jugador (texto en español, se traduce con Loc.t al mostrarlo).
var message: String = ""

var _client: BillingClient
var _details_ready: bool = false
var _restoring: bool = false


func _ready() -> void:
	if not OS.has_feature("android") or not Engine.has_singleton("GodotGooglePlayBilling"):
		return
	_client = BillingClient.new()
	add_child(_client)
	_client.connected.connect(_on_connected)
	_client.disconnected.connect(_on_disconnected)
	_client.connect_error.connect(_on_connect_error)
	_client.query_product_details_response.connect(_on_product_details)
	_client.query_purchases_response.connect(_on_purchases_queried)
	_client.on_purchase_updated.connect(_on_purchase_updated)
	_client.acknowledge_purchase_response.connect(_on_acknowledged)
	_connect()


## ¿Hay compras en este dispositivo? (Android con el plugin y Google Play respondiendo.)
func available() -> bool:
	return _client != null and state != State.UNAVAILABLE


func can_buy() -> bool:
	return state == State.READY and _details_ready


## Lanza el pago de Google Play.
func buy() -> void:
	if not available():
		return
	if not _details_ready:
		_notify("Premium no está disponible ahora mismo en Google Play.")
		_connect()
		return
	message = ""
	var result: Dictionary = _client.purchase(PRODUCT_ID)
	if result.get("response_code", BillingClient.BillingResponseCode.ERROR) == BillingClient.BillingResponseCode.OK:
		_set_state(State.BUSY)
	else:
		_notify("No se ha podido completar la compra. Inténtalo de nuevo más tarde.")


## Vuelve a consultar las compras de la cuenta (botón «Restaurar compra»).
func restore() -> void:
	if not available():
		return
	message = ""
	_restoring = true
	if _client.is_ready():
		_set_state(State.BUSY)
		_client.query_purchases(BillingClient.ProductType.INAPP)
	else:
		_connect()


func _connect() -> void:
	if _client.get_connection_state() == BillingClient.ConnectionState.CONNECTING:
		return
	_set_state(State.CONNECTING)
	_client.start_connection()


func _on_connected() -> void:
	_set_state(State.READY)
	_client.query_purchases(BillingClient.ProductType.INAPP)
	_client.query_product_details(PackedStringArray([PRODUCT_ID]), BillingClient.ProductType.INAPP)


func _on_disconnected() -> void:
	_details_ready = false
	_set_state(State.UNAVAILABLE)


func _on_connect_error(_code: int, _debug: String) -> void:
	_details_ready = false
	_set_state(State.UNAVAILABLE)
	if _restoring:
		_restoring = false
		_notify("No se ha podido completar la compra. Inténtalo de nuevo más tarde.")


func _on_product_details(response: Dictionary) -> void:
	_details_ready = false
	if response.get("response_code", -1) == BillingClient.BillingResponseCode.OK:
		for details in response.get("product_details", []):
			if details.get("product_id", "") != PRODUCT_ID:
				continue
			_details_ready = true
			var offers: Variant = details.get("one_time_purchase_offer_details_list")
			if offers is Array and not (offers as Array).is_empty():
				price = str((offers as Array)[0].get("formatted_price", ""))
	changed.emit()


func _on_purchases_queried(response: Dictionary) -> void:
	if state == State.BUSY:
		_set_state(State.READY)
	if response.get("response_code", -1) != BillingClient.BillingResponseCode.OK:
		# Sin respuesta fiable (por ejemplo, sin red): se conserva lo guardado.
		if _restoring:
			_restoring = false
			_notify("No se ha podido completar la compra. Inténtalo de nuevo más tarde.")
		return
	var owned: bool = _check_purchases(response.get("purchases", []))
	if _restoring:
		_restoring = false
		if not owned and message == "":
			_notify("No se ha encontrado ninguna compra anterior.")
	# Respuesta fiable: si la compra ya no consta (reembolso), se quita Premium.
	_apply(owned)


func _on_purchase_updated(response: Dictionary) -> void:
	if state == State.BUSY:
		_set_state(State.READY)
	match int(response.get("response_code", -1)):
		BillingClient.BillingResponseCode.OK:
			if _check_purchases(response.get("purchases", [])):
				_apply(true)
		BillingClient.BillingResponseCode.USER_CANCELED:
			_notify("Compra cancelada.")
		BillingClient.BillingResponseCode.ITEM_ALREADY_OWNED:
			# Ya la tenía comprada: se recupera como una restauración.
			_restoring = true
			_client.query_purchases(BillingClient.ProductType.INAPP)
		_:
			_notify("No se ha podido completar la compra. Inténtalo de nuevo más tarde.")


## Revisa una lista de compras: reconoce las nuevas (si no se reconocen en 3 días, Google las
## reembolsa) y devuelve si Premium está pagado. Las pendientes no activan nada todavía.
func _check_purchases(purchases: Array) -> bool:
	var owned: bool = false
	for purchase in purchases:
		if not PRODUCT_ID in purchase.get("product_ids", PackedStringArray()):
			continue
		var purchase_state: int = int(purchase.get("purchase_state", BillingClient.PurchaseState.UNSPECIFIED_STATE))
		if purchase_state == BillingClient.PurchaseState.PENDING:
			_notify("Compra pendiente: se activará cuando Google Play la confirme.")
		elif purchase_state == BillingClient.PurchaseState.PURCHASED:
			owned = true
			if not purchase.get("is_acknowledged", false):
				_client.acknowledge_purchase(purchase.get("purchase_token", ""))
	return owned


func _on_acknowledged(_response: Dictionary) -> void:
	# Si falla, la compra seguirá sin reconocer y se reintentará al abrir el juego.
	pass


func _apply(owned: bool) -> void:
	if Premium.is_premium() != owned:
		Premium.set_premium(owned)
	changed.emit()


func _notify(text: String) -> void:
	message = text
	changed.emit()


func _set_state(new_state: int) -> void:
	if state != new_state:
		state = new_state
		changed.emit()
