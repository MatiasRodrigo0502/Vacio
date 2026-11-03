#!/usr/bin/env bash
# Exporta el juego para Android: build/Vacio-android.apk.
#
# Lo usa GitHub al publicar (.github/workflows/publicar.yml), en una maquina
# Linux que ya trae el SDK de Android. En los ordenadores del equipo haria
# falta el SDK de Android y Java 17, que no estan: por eso no va en
# exportar.sh, que es el que corre en cada commit.
#
# Necesita:
#   GODOT          el binario de Godot
#   ANDROID_HOME   el SDK de Android (en GitHub ya esta puesto)
#   JAVA_HOME      Java 17
#   VERSION_JUEGO  el numero de la version (0.N)
#   la plantilla   python3 herramientas/instalar_plantillas.py --android
#
# LA FIRMA: Android solo instala un .apk firmado, y solo deja instalar una
# version encima de otra si las dos van firmadas con la misma clave. La clave
# NO esta en el proyecto (con ella, cualquiera podria firmar un .apk como si
# fuera nuestro): GitHub la guarda como secretos del repositorio y se la pasa
# a este script (ANDROID_CLAVE_BASE64, el .keystore en base64, y
# ANDROID_CLAVE_ALIAS y ANDROID_CLAVE_CONTRASENA). Sin ellos, se crea una
# clave nueva solo para esta version: el .apk se instala, pero para
# actualizar hay que desinstalar antes el de la anterior.
set -euo pipefail

RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$RAIZ/build"
REGISTRO="$BUILD/exportar_android.log"
APK="$BUILD/Vacio-android.apk"
mkdir -p "$BUILD"
: >"$REGISTRO"

: "${GODOT:?Falta GODOT, el binario de Godot}"
: "${ANDROID_HOME:?Falta ANDROID_HOME, el SDK de Android}"
: "${JAVA_HOME:?Falta JAVA_HOME, Java 17}"
: "${VERSION_JUEGO:?Falta VERSION_JUEGO}"

# El numero va dentro del juego, como en las demas (exportar.sh).
printf '%s' "$VERSION_JUEGO" >"$RAIZ/version.txt"

# Android decide si una version es mas nueva por un numero entero (el
# "version code"): la N de 0.N. El nombre que se ensena es el de siempre.
# Se cambian en el preset solo aqui, en la maquina de GitHub: en el proyecto
# se quedan en 1 y 0.0.
codigo="${VERSION_JUEGO#0.}"
[[ "$codigo" =~ ^[0-9]+$ ]] || codigo=1
sed -i -e "s|^version/code=.*|version/code=$codigo|" \
	-e "s|^version/name=.*|version/name=\"$VERSION_JUEGO\"|" "$RAIZ/export_presets.cfg"

# Donde estan el SDK y Java: Godot lo lee de sus ajustes de editor. El nombre
# del archivo cambia de una version de Godot a otra; se escriben los dos.
ajustes="${XDG_CONFIG_HOME:-$HOME/.config}/godot"
mkdir -p "$ajustes"
for archivo in editor_settings-4.tres editor_settings-4.7.tres; do
	cat >"$ajustes/$archivo" <<FIN
[gd_resource type="EditorSettings" format=3]

[resource]
export/android/android_sdk_path = "$ANDROID_HOME"
export/android/java_sdk_path = "$JAVA_HOME"
FIN
done

# La clave va fuera del proyecto, en la carpeta temporal de la maquina: si
# no, Godot la veria al escanear y podria acabar dentro del .apk.
clave="${RUNNER_TEMP:-/tmp}/vacio.keystore"
if [ -n "${ANDROID_CLAVE_BASE64:-}" ]; then
	printf '%s' "$ANDROID_CLAVE_BASE64" | base64 -d >"$clave"
	alias_clave="${ANDROID_CLAVE_ALIAS:?Falta ANDROID_CLAVE_ALIAS}"
	contrasena="${ANDROID_CLAVE_CONTRASENA:?Falta ANDROID_CLAVE_CONTRASENA}"
	echo "Firmando con la clave guardada en GitHub."
else
	echo "AVISO: no hay clave guardada en GitHub (ANDROID_CLAVE_BASE64): se firma con una"
	echo "nueva, solo para esta version. Para actualizar habra que desinstalar la anterior."
	alias_clave="vacio"
	contrasena="$(head -c 24 /dev/urandom | base64 | tr -dc 'A-Za-z0-9')"
	rm -f "$clave"
	"$JAVA_HOME/bin/keytool" -genkeypair -keystore "$clave" -storetype PKCS12 \
		-storepass "$contrasena" -alias "$alias_clave" -keypass "$contrasena" \
		-keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Vacio, O=Vacio, C=ES" >/dev/null 2>&1
fi
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$clave"
export GODOT_ANDROID_KEYSTORE_RELEASE_USER="$alias_clave"
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="$contrasena"

echo "=== Importar ===" >>"$REGISTRO"
"$GODOT" --headless --path "$RAIZ" --import >>"$REGISTRO" 2>&1 || true
echo "=== Android ===" >>"$REGISTRO"
rm -f "$APK"
if ! "$GODOT" --headless --path "$RAIZ" --export-release "Android" "$APK" >>"$REGISTRO" 2>&1 \
		|| [ ! -s "$APK" ]; then
	echo "No ha salido el .apk. Lo ultimo del registro:"
	tail -n 60 "$REGISTRO"
	exit 1
fi

# Que va firmado (si no, Android no lo instala) y con que numero.
herramientas_sdk="$(ls -d "$ANDROID_HOME"/build-tools/* | sort -V | tail -1)"
"$herramientas_sdk/apksigner" verify --print-certs "$APK" | head -3
"$herramientas_sdk/aapt" dump badging "$APK" | head -1
rm -f "$clave"
echo "Listo: build/Vacio-android.apk ($VERSION_JUEGO, codigo $codigo, $(du -h "$APK" | cut -f1))"
