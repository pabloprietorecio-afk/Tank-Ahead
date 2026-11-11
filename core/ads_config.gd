class_name AdsConfig
extends RefCounted
## Configuración de los anuncios (Google AdMob).
##
## Con IS_REAL = false se usan los anuncios y la aplicación de PRUEBA de Google: salen anuncios de
## ejemplo que no pagan. Para publicar de verdad hay que:
##   1. poner IS_REAL = true aquí y is_real=true en addons/AdmobPlugin/android_export.cfg,
##   2. poner en ese fichero el ID de aplicación real ([Release] app_id) y aquí los dos ID de
##      bloque de anuncios reales (intersticial y recompensado).
## Los ID de AdMob no son secretos (van dentro de la app).

## Interruptor general: con false no se carga nada de publicidad.
const ENABLED: bool = true
const IS_REAL: bool = false
const INTERSTITIAL_ID: String = ""
const REWARDED_ID: String = ""


## Con anuncios reales hacen falta los dos ID; si faltan, no se muestran anuncios.
static func usable() -> bool:
	if not ENABLED:
		return false
	return not IS_REAL or (INTERSTITIAL_ID != "" and REWARDED_ID != "")
