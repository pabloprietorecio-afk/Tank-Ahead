# A Tank Story

Juego de tanques en primera persona (Godot 4.7, Android). Estética retro-vectorial.

## APK
Cada push a `main` compila un APK y lo publica en **Releases**. El `versionCode` es el número de ejecución del flujo, así que cada APK se instala encima del anterior. Todos se firman con `ci/debug.keystore` (clave de depuración, no de publicación).

## Voces
Frases pregeneradas con Kokoro (fuera del juego). Las locuciones del tutorial se generan con
`python3 tools/voice_gen/tutorial_voice.py MODELO.onnx VOCES.bin` (voz de radio «em_santa») y
se guardan en `assets/voice/tutorial`. Si falta alguna, el tutorial muestra solo el texto.

## Idiomas
Español (por defecto) e inglés; se elige en OPCIONES → «IDIOMA / LANGUAGE». El texto del código está en
español y es la clave de traducción: `Loc.t("TEXTO")` lo muestra tal cual en español y lo busca en
`core/i18n/english_table.gd` en inglés (si falta, se ve en español). Para un texto nuevo basta una línea
en esa tabla. Las voces en inglés están en `assets/voice_en` y se generan con
`python3 tools/voice_gen/voices_en.py MODELO.onnx VOCES.bin` (voces «am_michael» y «bm_george»).

## Tutorial
Modo propio (`levels/modes/tutorial`): diecisiete lecciones (las dos últimas antes del combate final enseñan las órdenes a los aliados) en un campo de prácticas. Se ofrece la
primera vez que se abre el juego y está siempre en el menú. Lo ofrecido y lo completado se
guardan en la sección `tutorial` de `user://progress.cfg`.

## Sonidos de motor
Los motores de tanque y de avión son grabaciones reales (ver `assets/audio/CREDITS.md`).
`tools/audio_fetch` las descarga de Wikimedia Commons desde GitHub Actions (rama `audio`) y
`python3 tools/sound_gen/real_loop.py` convierte un tramo estable en un bucle sin costura.

## Comprobación
Cada push a una rama que no sea `main` ejecuta `verify.yml`: prueba las misiones nuevas, la navegación de los tanques aliados y el tutorial completo
(un jugador automático hace la acción correcta en cada lección) sin gráficos, y guarda capturas y registros en la rama `verify-shots`.
