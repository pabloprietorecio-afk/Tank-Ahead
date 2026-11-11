class_name Premium
extends RefCounted
## Nivel premium. En el modo historia, las tres primeras misiones de cada frente son gratuitas
## y el resto exige premium. Supervivencia, captura la bandera, tutorial y fichas históricas
## siguen libres. Premium también quita los anuncios (la publicidad aún no está integrada:
## cuando lo esté, no debe mostrarse nada si is_premium()).
##
## La compra la gestiona PremiumStore (Google Play Billing), que activa o quita Premium con
## set_premium() según las compras de la cuenta; el valor guardado aquí es una caché para jugar
## sin conexión.

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


## ¿Hay compras en este dispositivo? (Android con Google Play; en el ordenador no.)
static func billing_available() -> bool:
	return PremiumStore.available()


## Solo en compilaciones de depuración (APK de pruebas): permite probar el flujo sin comprar.
static func debug_toggle_available() -> bool:
	return OS.is_debug_build()


## ¿La misión (posición en la campaña, desde 0) es de las gratuitas?
static func mission_is_free(index: int) -> bool:
	return index < FREE_MISSIONS_PER_FRONT


static func mission_locked(index: int) -> bool:
	return PAYWALL_ENABLED and not mission_is_free(index) and not is_premium()
