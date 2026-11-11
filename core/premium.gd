class_name Premium
extends RefCounted
## Nivel premium. En el modo historia, las tres primeras misiones de cada frente son gratuitas
## y el resto exige premium. Supervivencia, captura la bandera, tutorial y fichas históricas
## siguen libres. Premium también quita los anuncios (decidido; la publicidad aún no está
## integrada: cuando lo esté, no debe mostrarse nada si is_premium()).
##
## La compra real (Google Play Billing) todavía no está conectada: cuando lo esté, debe llamar a
## set_premium(true) al confirmar la compra y volver a consultar las compras al abrir el juego
## (set_premium(false) si ya no consta), porque este valor guardado solo es una caché.

const FREE_MISSIONS_PER_FRONT: int = 3
## Interruptor general: con false todo el juego queda abierto.
const PAYWALL_ENABLED: bool = true
const PATH: String = "user://premium.cfg"


static func is_premium() -> bool:
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	return cfg.get_value("premium", "active", false)


static func set_premium(active: bool) -> void:
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	cfg.set_value("premium", "active", active)
	cfg.save(PATH)


## ¿Se pueden comprar ya? (Pendiente de conectar con Google Play Billing.)
static func billing_available() -> bool:
	return false


## Solo en compilaciones de depuración (APK de pruebas): permite probar el flujo sin comprar.
static func debug_toggle_available() -> bool:
	return OS.is_debug_build()


## ¿La misión (posición en la campaña, desde 0) es de las gratuitas?
static func mission_is_free(index: int) -> bool:
	return index < FREE_MISSIONS_PER_FRONT


static func mission_locked(index: int) -> bool:
	return PAYWALL_ENABLED and not mission_is_free(index) and not is_premium()
