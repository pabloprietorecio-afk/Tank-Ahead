#!/usr/bin/env bash
# Compila el plugin de reconocimiento de voz (SpeechCommands) como .aar, sin Gradle:
# javac contra android.jar y las clases de Godot de la plantilla de compilación de Android.
# Uso (desde la raíz del proyecto, con android/build ya instalado y el SDK de Android):
#   android_plugins/speech_commands/build.sh PLATAFORMA_ANDROID   (p. ej. 35)
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
PLATFORM="${1:?falta el número de plataforma de Android}"
ANDROID_JAR="$ANDROID_HOME/platforms/android-$PLATFORM/android.jar"
test -f "$ANDROID_JAR" || { echo "No está $ANDROID_JAR"; exit 1; }
GODOT_AAR=$(find "$ROOT/android/build/libs" -name "godot-lib*release*.aar" | head -1)
test -n "$GODOT_AAR" || { echo "No está la godot-lib de la plantilla en android/build/libs"; exit 1; }
WORK=$(mktemp -d)
unzip -q -o "$GODOT_AAR" classes.jar -d "$WORK/godot"
mkdir -p "$WORK/classes" "$WORK/aar"
javac -nowarn -encoding UTF-8 -source 11 -target 11 -bootclasspath "$ANDROID_JAR" \
  -classpath "$WORK/godot/classes.jar" -d "$WORK/classes" \
  $(find "$HERE/src" -name "*.java")
(cd "$WORK/classes" && jar cf "$WORK/aar/classes.jar" .)
cp "$HERE/AndroidManifest.xml" "$WORK/aar/AndroidManifest.xml"
: > "$WORK/aar/R.txt"
OUT="$ROOT/addons/SpeechCommands/bin"
mkdir -p "$OUT/debug" "$OUT/release"
(cd "$WORK/aar" && zip -q -r "$OUT/release/SpeechCommands-release.aar" AndroidManifest.xml classes.jar R.txt)
cp "$OUT/release/SpeechCommands-release.aar" "$OUT/debug/SpeechCommands-debug.aar"
unzip -l "$OUT/release/SpeechCommands-release.aar"
rm -rf "$WORK"
