# A Tank Story

Juego de tanques en primera persona (Godot 4.7, Android). Estética retro-vectorial.

## APK
Cada push a `main` compila un APK y lo publica en **Releases**. El `versionCode` es el número de ejecución del flujo, así que cada APK se instala encima del anterior. Todos se firman con `ci/debug.keystore` (clave de depuración, no de publicación).

## Voces
Frases pregeneradas con Kokoro (fuera del juego). Las locuciones del tutorial se generan con
`python3 tools/voice_gen/tutorial_voice.py MODELO.onnx VOCES.bin` (voz de radio «em_santa») y
se guardan en `assets/voice/tutorial`. Si falta alguna, el tutorial muestra solo el texto.

## Idiomas
Diez idiomas: español (por defecto), inglés, francés, italiano, japonés, portugués de Brasil,
indonesio, hindi, alemán y ruso. Se eligen tocando la bandera vieja de arriba a la derecha del menú
principal o en OPCIONES → «IDIOMA / LANGUAGE». El texto del código está en español y es la clave de
traducción: `Loc.t("TEXTO")` lo muestra tal cual en español y lo busca en `core/i18n/<idioma>_table.gd`
en los demás (si falta, se ve en español). Para un texto nuevo basta una línea en cada tabla.

Fuentes: el japonés y el hindi llevan una fuente de respaldo (Noto Sans CJK JP en subconjunto y
Noto Sans Devanagari, ambas con licencia SIL OFL 1.1, en `assets/fonts`), que solo se activa en
esos idiomas. El cirílico y el resto de alfabetos latinos ya los trae la fuente por defecto.

Voces (`assets/voice_<idioma>`; si falta un clip se usa el español):
- Inglés, francés, italiano, japonés, portugués e hindi: Kokoro
  (`voices_en.py`, `voices_lang.py MODELO.onnx VOCES.bin CODIGO`). El francés solo tiene voz femenina.
- Indonesio, alemán y ruso: Supertonic 3 de Supertone Inc. con sherpa-onnx (`voices_supertonic.py`).
  El modelo tiene licencia BigScience Open RAIL-M: uso libre de regalías y sin derechos del autor
  sobre el audio generado, pero con restricciones de uso y la obligación de avisar de que el
  contenido está hecho por una máquina. **Ese aviso va en la ficha de Play Store: los textos, en
  los diez idiomas, están en `store/aviso_voces_ia.md` (hay que pegarlos al crear la ficha).**
  La voz indonesia de Piper (`id_ID-news_tts`) NO se usa: su conjunto de datos (INDspeech_NEWS_TTS)
  es CC BY-NC-SA, solo para uso no comercial. `voices_piper.py` (alemán y ruso con Piper, CC0) se
  conserva como alternativa, pero con el efecto de radio se entiende peor.
- Comprobación: `check_voices.py CARPETA_WHISPER CODIGO` transcribe las voces de un idioma con
  Whisper y las compara con el texto (1.00 = se oye lo escrito). Medias actuales: it 0,98; de 0,97;
  ru 0,97; pt 0,96; id 0,95; ja 0,92; hi 0,92; fr 0,90. Mide si se entiende, no si suena natural.
- Los textos de las voces de los idiomas nuevos están en `tools/voice_gen/lines/<idioma>.txt` y son
  traducciones propias, sin revisar por un nativo.

## Clima
Seis climas (`levels/weather/weather.gd`): soleado y nubes y claros (los días claros, con el sol alto),
atardecer, niebla (tormenta de arena en África), lluvia y nieve. Cada frente admite los suyos
(`Fronts.weathers`: África sin lluvia ni nieve, Normandía sin nieve) y al sortear salen más a menudo los
días claros. El jugador elige «aleatorio» o uno de los climas del frente con un desplegable: en la historia,
en el parte de la misión; en supervivencia y captura la bandera, en una pantalla previa (`_page_start`).
La elección se guarda (`GameSettings.weather`) y vale para las partidas siguientes. El tutorial es siempre
soleado.

## Relieve: lomas
`levels/terrain.gd`. Además de las colinas y montañas (empinadas: hacen de pared, como siempre), cada
campo lleva tres o cuatro lomas suaves, de unos 12 grados de pendiente como mucho, por las que suben y
bajan todos los tanques. Cada loma es una función de altura conocida: `TankMovement` posa el tanque en
ella e inclina su chasis (`Tank.chassis`), y `TurretController` compensa esa inclinación para que el cañón
apunte igual que en el llano. La máquina las trata como suelo llano (no cuentan como obstáculo en sus
rutas); para los disparos y la línea de visión llevan un cuerpo en la capa `Terrain.LAYER`, con la que los
tanques no chocan. Nada del decorado se coloca encima de una loma.

## Tanque del jugador
El de serie de cada frente y bando (`Fronts.PLAYER_TANK`) tiene siempre la misma potencia. Con premium,
una misión ya superada se puede repetir con cualquier otro tanque del bando en ese frente (desplegable en
el parte de la misión, o «REPETIR CON OTRO TANQUE» al ganar): `Fronts.player_stats(frente, bando, id)`
cambia la potencia según lo que ese vehículo es frente al de serie (los ligeros corren más y aguantan
menos; los pesados son lentos, duros y pegan más), con su tamaño real y, en los cazacarros de casamata, el
cañón casi fijo: entonces el casco gira solo hacia donde se apunta (`PlayerInputSource`).

## Aliados
En la historia salen dos aliados más de los que marca cada misión (`StoryMode.EXTRA_ALLIES`), con el
blindaje reforzado, y por cada uno que cae entra un refuerzo por el borde sur hasta agotar la reserva.
Supervivencia no tiene aliados; captura la bandera sigue siendo 4 contra 4.

## Ayudas para ver mejor
- Opciones «Destacar enemigos (borde amarillo)» y «Destacar objetivos (borde azul)»: edificios objetivo,
  comandante enemigo, bandera enemiga y salida de las misiones de ruptura (`shaders/outline.gdshader`; el
  borde nunca baja de un píxel y medio de grosor, para que se vea de lejos).
- Siempre: los tanques de la máquina llevan un contorno oscuro de un píxel (`shaders/contour.gdshader`) y
  todos una sombra de contacto bajo el casco (`shaders/contact_shadow.gdshader`), que los separan de un
  terreno de color parecido.
- El menú de opciones de la partida se monta a la mayor escala que cabe en la pantalla
  (`Hud._fit_pause_menu`), con interruptores y deslizadores grandes (`ui/ui_kit.gd`).

## Tutorial
Modo propio (`levels/modes/tutorial`): diecisiete lecciones (las dos últimas antes del combate final enseñan las órdenes a los aliados) en un campo de prácticas. Se ofrece la
primera vez que se abre el juego y está siempre en el menú. Lo ofrecido y lo completado se
guardan en la sección `tutorial` de `user://progress.cfg`.

## Sonidos de motor
Los motores de tanque y de avión son grabaciones reales (ver `assets/audio/CREDITS.md`).
`tools/audio_fetch` las descarga de Wikimedia Commons desde GitHub Actions (rama `audio`) y
`python3 tools/sound_gen/real_loop.py` convierte un tramo estable en un bucle sin costura.

## Anuncios (AdMob)

- Intersticial: al pasar a la siguiente partida tras ganar una misión de la historia y al acabar una de
  supervivencia. Nunca durante el combate ni tras perder en la historia. Política: ninguno en los dos
  primeros finales de la sesión, luego como mucho uno cada dos finales y siempre con 3 minutos de margen.
- Recompensado: en la pantalla premium, «Ver un anuncio y jugar esta misión» abre esa misión de pago una
  vez (hasta superarla). Solo se ofrece para la siguiente misión por jugar.
- Premium quita todos los anuncios. Sin consentimiento (UMP) tampoco se piden; en las regiones que lo exigen
  hay un botón «Privacidad de los anuncios» en Opciones.
- Hoy usa anuncios de **prueba** de Google. Para publicar: `IS_REAL = true` y los dos ID de bloque en
  `core/ads_config.gd`, y `is_real=true` más el ID de aplicación real en
  `addons/AdmobPlugin/android_export.cfg` (la verificación comprueba que ambos coinciden).
- Plugin oficial `godot-sdk-integrations/godot-admob` v7.0 (paquete Android ya compilado, ver
  `addons/AdmobPlugin/ORIGEN.txt`).

## Nivel premium

En el modo historia, las tres primeras misiones de cada frente son gratuitas y el resto exige premium
(`core/premium.gd`). Premium también quita los anuncios. Supervivencia, captura la bandera,
tutorial y fichas siguen libres. La compra con Google Play Billing aún no está conectada: en el APK de
pruebas hay un botón «[PRUEBAS] Activar premium» en la pantalla premium.

## Publicar en Google Play (AAB firmado)
Workflow `build-aab.yml` (Actions > *Build AAB (Google Play)* > *Run workflow*, o una etiqueta `aab-N`).
1. Una sola vez, crear en GitHub (*Settings > Secrets and variables > Actions*) tres secretos:
   `RELEASE_KEYSTORE_BASE64` (la clave de subida en base64), `RELEASE_KEYSTORE_PASSWORD` y `RELEASE_KEY_ALIAS`.
   La misma contraseña protege el almacén y la clave. Sin ellos el workflow compila con una clave
   desechable («modo prueba») solo para validar; ese AAB **no** se publica y **no** sirve para Google Play.
2. El AAB firmado queda en la release privada **aab-latest** (solo se conserva el último). El `versionCode`
   es el número de ejecución de este workflow y `versionName` es `0.2.N` (los APK de pruebas son `0.1.x`).
3. Cada ejecución comprueba el AAB (`tools/aab/inspect_aab.sh`): `targetSdk` ≥ 36, no depurable, permisos
   previstos, librerías nativas alineadas a 16 KB y firma. El informe queda en la rama `aab-report`.
4. Subir el AAB a Play Console. Se usa **Play App Signing**: la clave de este repositorio es solo la de
   *subida* (si se pierde, Google permite restablecerla). El nombre de paquete `com.pabloprieto.tankahead`
   es **permanente** en cuanto se sube el primer AAB.
5. Los textos de la ficha (incluido el aviso de voces IA, obligatorio por la licencia de Supertonic) están en `store/`.

## Comprobación
Cada push a una rama que no sea `main` ejecuta `verify.yml`: prueba las misiones nuevas, la navegación de los tanques aliados y el tutorial completo
(un jugador automático hace la acción correcta en cada lección) sin gráficos, y guarda capturas y registros en la rama `verify-shots`.
También comprueba que los tanques suben y bajan las lomas (y siguen sin poder subir a las colinas), que el menú de opciones cabe en
pantalla en los diez idiomas, las fichas de los tanques que puede llevar el jugador, los refuerzos aliados y los bordes de ayuda.
Y, ya con gráficos, que los bordes de ayuda y el contorno de los tanques no cambian las sombras del campo: son el modelo hinchado y en la
pasada de sombras se reducen a un punto (`IN_SHADOW_PASS`), porque ahí el grosor «en píxeles» sale de metros.
