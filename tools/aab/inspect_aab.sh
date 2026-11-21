#!/usr/bin/env bash
# Comprueba un AAB antes de subirlo a Google Play y escribe un informe en Markdown.
# Uso: inspect_aab.sh FICHERO.aab [HUELLA_SHA256_ESPERADA]
# Sale con error si: es depurable, no apunta a API 36 o más, pide permisos inesperados,
# tiene librerías nativas sin alineación de 16 KB, o no está firmado.
set -uo pipefail
# Nota: no usar «echo ... | grep -q» con pipefail (SIGPIPE da falsos errores); usar <<< en su lugar.
AAB="$1"; EXPECTED_FP="${2:-}"
BT="${BUNDLETOOL_JAR:-bundletool.jar}"
FAIL=0
say() { echo "$@"; }
bad() { echo "- ❌ $*"; FAIL=1; }
ok()  { echo "- ✅ $*"; }

say "# Informe del AAB"
say
say "Fichero: \`$(basename "$AAB")\` — $(du -h "$AAB" | cut -f1)"
say
say "## Manifiesto"
MANIFEST=$(java -jar "$BT" dump manifest --bundle="$AAB" 2>&1)
echo '```xml'; echo "$MANIFEST" | head -60; echo '```'

PKG=$(echo "$MANIFEST" | grep -o 'package="[^"]*"' | head -1)
TARGET=$(echo "$MANIFEST" | grep -o 'android:targetSdkVersion="[0-9]*"' | head -1 | grep -o '[0-9]*')
MINSDK=$(echo "$MANIFEST" | grep -o 'android:minSdkVersion="[0-9]*"' | head -1 | grep -o '[0-9]*')
say
say "## Comprobaciones"
ok "$PKG, minSdk=$MINSDK"
if [ -n "$TARGET" ] && [ "$TARGET" -ge 36 ]; then ok "targetSdk=$TARGET (Google Play exige 36 o más)"; else bad "targetSdk=${TARGET:-?} (Google Play exige 36 o más)"; fi
if grep -q 'android:debuggable="true"' <<<"$MANIFEST"; then bad "El AAB es depurable (android:debuggable=true)"; else ok "No es depurable"; fi
PERMS=$(echo "$MANIFEST" | grep -o 'uses-permission[^>]*android:name="[^"]*"' | grep -o 'android.permission.[A-Z_]*\|com.android.vending.[A-Z_]*\|com.google[A-Za-z_.]*' | sort -u)
say "- Permisos declarados: $(echo $PERMS | tr '\n' ' ')"
UNEXPECTED=$(echo "$PERMS" | grep -v -E '^(android.permission.(INTERNET|VIBRATE|ACCESS_NETWORK_STATE|WAKE_LOCK|ACCESS_ADSERVICES_ATTRIBUTION|ACCESS_ADSERVICES_AD_ID|ACCESS_ADSERVICES_TOPICS|AD_ID|FOREGROUND_SERVICE|RECORD_AUDIO)|com.android.vending.BILLING|com.google.android.gms.permission.AD_ID)$' || true)
if [ -n "$UNEXPECTED" ]; then bad "Permisos no previstos: $(echo $UNEXPECTED | tr '\n' ' ')"; else ok "Solo permisos previstos"; fi
# Hardware que Google Play daría por obligatorio (y dejaría fuera dispositivos) si no se declara opcional.
for FEATURE in android.hardware.microphone android.hardware.screen.landscape; do
  LINE=$(echo "$MANIFEST" | grep "uses-feature" | grep "android:name=\"$FEATURE\"" | head -1 || true)
  if grep -q 'android:required="false"' <<<"$LINE"; then ok "$FEATURE declarado como opcional"; else bad "$FEATURE no está declarado como opcional: Google Play excluirá dispositivos"; fi
done

say
say "## Librerías nativas (alineación 16 KB)"
TMP=$(mktemp -d); unzip -q -o "$AAB" 'base/lib/*' -d "$TMP" 2>/dev/null || true
NSO=0
for so in $(find "$TMP" -name '*.so' 2>/dev/null); do
  NSO=$((NSO+1))
  ALIGN=$(readelf -lW "$so" | awk '$1=="LOAD"{print $NF}' | sort -u | tr '\n' ' ')
  # Alineación válida para 16 KB: 0x4000 o múltiplos. Se evalúa sobre la variable (sin tuberías con grep -q).
  BADALIGN=$(tr ' ' '\n' <<<"$ALIGN" | grep -v -E '^(0x(4000|8000|10000|20000|40000|100000|200000))?$' || true)
  if [ -n "$BADALIGN" ]; then
    bad "$(echo "$so" | sed "s#$TMP/##") alineación: $ALIGN"
  else
    ok "$(echo "$so" | sed "s#$TMP/##") alineación: $ALIGN"
  fi
done
[ "$NSO" -eq 0 ] && bad "No se encontraron librerías nativas en base/lib"
say
say "## Configuración del bundle"
java -jar "$BT" dump config --bundle="$AAB" 2>&1 | grep -v JAVA_TOOL | head -40 | sed 's/^/    /'

say
say "## Firma"
VER=$(jarsigner -verify -certs "$AAB" 2>&1 | grep -v JAVA_TOOL)
if grep -q "jar verified" <<<"$VER"; then ok "Firma verificada"; else bad "El AAB no está firmado o la firma no es válida"; fi
FP=$(keytool -printcert -jarfile "$AAB" 2>/dev/null | grep -m1 "SHA256:" | sed 's/.*SHA256: *//')
say "- Huella SHA-256 del certificado de subida: \`${FP:-no encontrada}\`"
if [ -n "$EXPECTED_FP" ]; then
  if [ "$FP" = "$EXPECTED_FP" ]; then ok "Coincide con la huella esperada"; else bad "No coincide con la huella esperada ($EXPECTED_FP)"; fi
fi
say
if [ $FAIL -eq 0 ]; then say "**Resultado: correcto**"; else say "**Resultado: HAY PROBLEMAS**"; fi
exit $FAIL
