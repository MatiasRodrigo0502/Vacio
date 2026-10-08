#!/usr/bin/env bash
# Exporta el juego a build/: Vacio.exe para Windows y Vacio.x86_64 para Linux.
# Cada uno es un solo archivo, con todo dentro, que se abre sin tener Godot.
#
# Lo lanzan solos los hooks de git (.githooks/) tras cada commit y cada pull,
# asi que siempre van con la ultima version. Tambien se puede lanzar a
# mano desde Git Bash:
#
#     bash herramientas/exportar.sh
#
# Necesita las plantillas de Windows y Linux de Godot instaladas una vez por
# ordenador:
#
#     python herramientas/instalar_plantillas.py

set -u

RAIZ="$(cd "$(dirname "$0")/.." && (pwd -W 2>/dev/null || pwd))"
BUILD="$RAIZ/build"
REGISTRO="$BUILD/exportar.log"
# Si llega otro commit mientras se exporta, no se lanza otro Godot a la vez
# (los dos escribirian el mismo archivo): se apunta en PENDIENTE y quien tiene
# el CANDADO repite la exportacion al acabar. Una rafaga de commits acaba en
# una sola vuelta mas, con lo ultimo.
CANDADO="$BUILD/.exportando"
PENDIENTE="$BUILD/.pendiente"

# Busca Godot como jugar.bat: la variable GODOT, el PATH o las rutas conocidas.
# Si otra persona del equipo lo tiene en otro sitio, puede definir GODOT o
# anadir su ruta a la lista.
buscar_godot() {
	if [ -n "${GODOT:-}" ] && [ -f "$GODOT" ]; then
		echo "$GODOT"
		return 0
	fi
	if command -v godot >/dev/null 2>&1; then
		command -v godot
		return 0
	fi
	# USERPROFILE solo existe en Windows; vacia en otro sistema, para que
	# set -u no corte el script.
	for ruta in \
		"${USERPROFILE:-}/OneDrive - vidalibarraquer.net/Escritorio/Godot_v4.7.2-stable_win64.exe" \
		"C:/Tools/Godot/Godot_v4.7.2-stable_win64.exe" \
		"${USERPROFILE:-}/Desktop/Godot_v4.7.2-stable_win64.exe"; do
		if [ -f "$ruta" ]; then
			echo "$ruta"
			return 0
		fi
	done
	return 1
}

mkdir -p "$BUILD"
# Que Godot no mire dentro de build/: si alguien deja ahi una imagen (una
# captura, por ejemplo), Godot la importa y acaba metida dentro del .exe. Paso
# con las capturas del 2026-10-08: el .exe crecio 5 MB.
touch "$BUILD/.gdignore"

# Un candado de hace mas de 15 minutos es de una exportacion que murio a medias
# (se apago el ordenador, se mato el proceso...): sin esto no se exportaria
# nunca mas.
if [ -d "$CANDADO" ] && [ -n "$(find "$CANDADO" -maxdepth 0 -mmin +15)" ]; then
	rmdir "$CANDADO"
fi
# mkdir es atomico: si dos commits llegan a la vez, solo uno lo consigue.
if ! mkdir "$CANDADO" 2>/dev/null; then
	touch "$PENDIENTE"
	echo "Ya hay una exportacion en marcha: se repetira al acabar."
	exit 0
fi
trap 'rmdir "$CANDADO" 2>/dev/null' EXIT

if ! GODOT_EXE="$(buscar_godot)"; then
	echo "No encuentro Godot. Define la variable GODOT con la ruta de tu" \
		"Godot_*.exe o anade la ruta en herramientas/exportar.sh." | tee "$REGISTRO"
	exit 1
fi

# En una copia recien clonada (la de GitHub, o la de alguien que acaba de
# bajarse el proyecto) aun no hay .godot/. Se importa todo antes: exportar sin
# importar puede dejar fuera recursos que todavia no se habian procesado.
if [ ! -d "$RAIZ/.godot" ]; then
	echo "Primera vez en esta copia: importando el proyecto..."
	"$GODOT_EXE" --headless --path "$RAIZ" --import >"$REGISTRO" 2>&1
fi

# Los sistemas para los que se exporta: el nombre del preset
# (export_presets.cfg) y el archivo que sale en build/. Uno mas es una linea
# mas aqui y un preset.
SISTEMAS=(
	"Windows Desktop|Vacio.exe"
	"Linux|Vacio.x86_64"
)

# El nombre de esta version del juego.
#
# Las versiones con numero (0.1, 0.2...) las pone GitHub al publicar, con una
# etiqueta v0.N en el commit (ver .github/workflows/publicar.yml), y se lo pasa
# aqui en VERSION_JUEGO. En cada ordenador se saca de esas etiquetas: si el
# commit es justo el de una version, ese numero; si hay cambios despues, "0.N +
# cambios" y el commit, porque ese .exe todavia no es ninguna version publicada.
numero_de_version() {
	if [ -n "${VERSION_JUEGO:-}" ]; then
		echo "$VERSION_JUEGO"
		return
	fi
	local corto etiqueta
	corto="$(git -C "$RAIZ" rev-parse --short HEAD 2>/dev/null)"
	etiqueta="$(git -C "$RAIZ" describe --tags --abbrev=0 --match 'v0.*' 2>/dev/null)"
	if [ -z "$etiqueta" ]; then
		echo "en desarrollo ($corto)"
	elif git -C "$RAIZ" describe --tags --exact-match --match 'v0.*' HEAD >/dev/null 2>&1; then
		echo "${etiqueta#v}"
	else
		echo "${etiqueta#v} + cambios ($corto)"
	fi
}

# Exporta para un sistema y lo pone en su sitio. Devuelve 0 si ha salido bien.
exportar_sistema() {
	local preset="$1" archivo="$2"
	local base="${archivo%.*}" extension="${archivo##*.}"
	local destino="$BUILD/$archivo"
	local nuevo="$BUILD/$base.nuevo.$extension"
	rm -f "$nuevo"
	echo "=== $preset ===" >>"$REGISTRO"
	"$GODOT_EXE" --headless --path "$RAIZ" --export-release "$preset" "$nuevo" \
		>>"$REGISTRO" 2>&1
	local codigo=$?
	if [ $codigo -ne 0 ] || [ ! -s "$nuevo" ]; then
		echo "$archivo ha fallado (codigo $codigo). Detalles en build/exportar.log." \
			| tee -a "$REGISTRO"
		return 1
	fi
	# Se exporta a un archivo aparte y se cambia al final: si falla a medias,
	# el de antes sigue sirviendo.
	#
	# Windows no deja sobrescribir ni borrar un .exe abierto, pero si
	# renombrarlo. Asi se puede actualizar aunque se este jugando: el abierto
	# pasa a llamarse Vacio.viejo.*.exe y el nuevo ocupa su sitio.
	if [ -e "$destino" ]; then
		mv -f "$destino" "$BUILD/$base.viejo.$(date +%s).$extension"
	fi
	mv -f "$nuevo" "$destino"
	# Linux necesita el permiso de ejecucion para abrirlo.
	chmod +x "$destino" 2>/dev/null
	rm -f "$BUILD"/"$base".viejo.* 2>/dev/null
	echo "Listo: build/$archivo ($commit)" | tee -a "$REGISTRO"
	return 0
}

resultado=0
while :; do
	rm -f "$PENDIENTE"
	# Copias viejas de vueltas anteriores (ver exportar_sistema). Si alguna
	# sigue abierta, Windows no deja borrarla: se queda para la proxima.
	rm -f "$BUILD"/Vacio.viejo.* 2>/dev/null

	commit="$(git -C "$RAIZ" log -1 --format='%h %s' 2>/dev/null)"
	{
		echo "Exportando desde: $commit"
		echo "Fecha: $(date '+%Y-%m-%d %H:%M:%S')"
		echo
	} >"$REGISTRO"
	# El numero de version va dentro del juego (version.txt, que el preset
	# mete en el .exe con include_filter) y el menu lo ensena.
	version_juego="$(numero_de_version)"
	printf '%s' "$version_juego" >"$RAIZ/version.txt"
	echo "Version: $version_juego" | tee -a "$REGISTRO"
	resultado=0
	# Si un sistema falla se sigue con los demas: que Linux falle no es motivo
	# para quedarse sin el .exe nuevo.
	for sistema in "${SISTEMAS[@]}"; do
		exportar_sistema "${sistema%%|*}" "${sistema##*|}" || resultado=1
	done

	if [ ! -e "$PENDIENTE" ]; then
		break
	fi
done
exit $resultado
