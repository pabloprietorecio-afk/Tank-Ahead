# A Tank Story

Juego de tanques en primera persona (Godot 4.7, Android). Estética retro-vectorial.

## APK
Cada push a `main` compila un APK y lo publica en **Releases**. El `versionCode` es el número de ejecución del flujo, así que cada APK se instala encima del anterior. Todos se firman con `ci/debug.keystore` (clave de depuración, no de publicación).

## Voces
Frases pregeneradas con Kokoro en `tools/voice_gen` (fuera del juego).

## Sonidos de motor
Los bucles de motor (tanques, orugas, aviones) se generan con `python3 tools/sound_gen/make_sounds.py`.

## Comprobación
Cada push a una rama que no sea `main` ejecuta `verify.yml`: prueba las misiones nuevas y la navegación de los tanques aliados sin gráficos, y guarda capturas y registros en la rama `verify-shots`.
