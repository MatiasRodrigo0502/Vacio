#!/usr/bin/env bash
# Exporta el juego a build/Vacio.exe: un solo archivo, con todo dentro, que
# se abre con doble clic sin tener Godot.
#
# Lo lanzan solos los hooks de git (.githooks/) tras cada commit y cada pull,
# asi que el .exe siempre va con la ultima version. Tambien se puede lanzar a
# mano desde Git Bash:
#
#     bash herramientas/exportar.sh
#
# Necesita la plantilla de Windows de Godot instalada una vez por ordenador:
#
#     python herramientas/instalar_plantilla_windows.py

set -u

RAIZ="$(cd "$(dirname "$0")/.." && (pwd -W 2>/dev/null || pwd))"
BUILD="$RAIZ/build"
EXE="$BUILD/Vacio.exe"
NUEVO="$BUILD/Vacio.nuevo.exe"
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
	for ruta in \
		"$USERPROFILE/OneDrive - vidalibarraquer.net/Escritorio/Godot_v4.7.2-stable_win64.exe" \
		"C:/Tools/Godot/Godot_v4.7.2-stable_win64.exe" \
		"$USERPROFILE/Desktop/Godot_v4.7.2-stable_win64.exe"; do
		if [ -f "$ruta" ]; then
			echo "$ruta"
			return 0
		fi
	done
	return 1
}

mkdir -p "$BUILD"

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

resultado=0
while :; do
	rm -f "$PENDIENTE" "$NUEVO"
	# Copias viejas de vueltas anteriores (ver mas abajo). Si alguna sigue
	# abierta, Windows no deja borrarla: se queda para la proxima.
	rm -f "$BUILD"/Vacio.viejo.*.exe 2>/dev/null

	commit="$(git -C "$RAIZ" log -1 --format='%h %s' 2>/dev/null)"
	{
		echo "Exportando desde: $commit"
		echo "Fecha: $(date '+%Y-%m-%d %H:%M:%S')"
		echo
	} >"$REGISTRO"
	"$GODOT_EXE" --headless --path "$RAIZ" --export-release "Windows Desktop" "$NUEVO" \
		>>"$REGISTRO" 2>&1
	codigo=$?

	if [ $codigo -eq 0 ] && [ -s "$NUEVO" ]; then
		# Se exporta a un archivo aparte y se cambia al final: si falla a
		# medias, el Vacio.exe de antes sigue sirviendo.
		#
		# Windows no deja sobrescribir ni borrar un .exe abierto, pero si
		# renombrarlo. Asi se puede actualizar aunque se este jugando: el
		# abierto pasa a llamarse Vacio.viejo.*.exe y el nuevo ocupa su sitio.
		if [ -e "$EXE" ]; then
			mv -f "$EXE" "$BUILD/Vacio.viejo.$(date +%s).exe"
		fi
		mv -f "$NUEVO" "$EXE"
		rm -f "$BUILD"/Vacio.viejo.*.exe 2>/dev/null
		echo "Listo: build/Vacio.exe ($commit)" | tee -a "$REGISTRO"
		resultado=0
	else
		echo "La exportacion ha fallado (codigo $codigo). Detalles en build/exportar.log." \
			| tee -a "$REGISTRO"
		resultado=1
	fi

	if [ ! -e "$PENDIENTE" ]; then
		break
	fi
done
exit $resultado
