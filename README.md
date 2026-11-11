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

## Tutorial
Modo propio (`levels/modes/tutorial`): diecisiete lecciones (las dos últimas antes del combate final enseñan las órdenes a los aliados) en un campo de prácticas. Se ofrece la
primera vez que se abre el juego y está siempre en el menú. Lo ofrecido y lo completado se
guardan en la sección `tutorial` de `user://progress.cfg`.

## Sonidos de motor
Los motores de tanque y de avión son grabaciones reales (ver `assets/audio/CREDITS.md`).
`tools/audio_fetch` las descarga de Wikimedia Commons desde GitHub Actions (rama `audio`) y
`python3 tools/sound_gen/real_loop.py` convierte un tramo estable en un bucle sin costura.

## Nivel premium

En el modo historia, las tres primeras misiones de cada frente son gratuitas y el resto exige premium
(`core/premium.gd`). Supervivencia, captura la bandera,
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
