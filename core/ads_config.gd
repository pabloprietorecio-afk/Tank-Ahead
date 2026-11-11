class_name AdsConfig
extends RefCounted
## Configuración de los anuncios (Google AdMob).
##
## Los anuncios REALES solo salen en las compilaciones de publicación (AAB). Las de depuración (el APK
## de pruebas) usan siempre los bloques de prueba de Google aunque IS_REAL sea true, para no
## pinchar nunca anuncios reales propios (AdMob lo trata como tráfico no válido).
##
## Con IS_REAL = false se usan los anuncios y la aplicación de PRUEBA de Google: salen anuncios de
## ejemplo que no pagan. Para publicar de verdad hay que:
##   1. poner IS_REAL = true aquí y is_real=true en addons/AdmobPlugin/android_export.cfg,
##   2. poner en ese fichero el ID de aplicación real ([Release] app_id) y aquí los dos ID de
##      bloque de anuncios reales (intersticial y recompensado).
## Los ID de AdMob no son secretos (van dentro de la app).

## Interruptor general: con false no se carga nada de publicidad.
const ENABLED: bool = true
const IS_REAL: bool = true
const INTERSTITIAL_ID: String = "ca-app-pub-6179885431224418/2649253524"
const REWARDED_ID: String = "ca-app-pub-6179885431224418/3916047821"


## Con anuncios reales hacen falta los dos ID; si faltan, no se muestran anuncios.
static func usable() -> bool:
	if not ENABLED:
		return false
	return not IS_REAL or (INTERSTITIAL_ID != "" and REWARDED_ID != "")
