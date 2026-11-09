#!/usr/bin/env bash
# Exporta el juego para el navegador: build/web/ (index.html, el .wasm, el .pck...).
#
# Lo usa GitHub al publicar (.github/workflows/publicar.yml), que lo sube a
# GitHub Pages: https://matiasrodrigo0502.github.io/Vacio/. Asi se juega desde el
# movil sin instalar nada, tambien en iPhone, donde instalar una app pide firmarla
# (Matias, 2026-11-06). No va en exportar.sh, que corre en cada commit: nadie
# necesita esto en su ordenador, y ahi se quedaria viejo.
#
# Necesita:
#   GODOT          el binario de Godot
#   VERSION_JUEGO  el numero de la version (0.N)
#   la plantilla   python3 herramientas/instalar_plantillas.py --web
#
# Para probarlo en el ordenador hace falta servirlo por http (abierto como archivo
# el navegador no lo deja arrancar):
#   python -m http.server 8060 -d build/web
set -euo pipefail

RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$RAIZ/build"
WEB="$BUILD/web"
REGISTRO="$BUILD/exportar_web.log"
mkdir -p "$BUILD"
# Lo exportado no es parte del proyecto: si Godot lo viera al escanear, acabaria
# dentro del propio juego (exportar.sh hace lo mismo).
touch "$BUILD/.gdignore"
: >"$REGISTRO"

: "${GODOT:?Falta GODOT, el binario de Godot}"
: "${VERSION_JUEGO:?Falta VERSION_JUEGO}"

# El numero va dentro del juego, como en las demas (exportar.sh).
printf '%s' "$VERSION_JUEGO" >"$RAIZ/version.txt"

echo "=== Importar ===" >>"$REGISTRO"
"$GODOT" --headless --path "$RAIZ" --import >>"$REGISTRO" 2>&1 || true
echo "=== Web ===" >>"$REGISTRO"
rm -rf "$WEB"
mkdir -p "$WEB"
if ! "$GODOT" --headless --path "$RAIZ" --export-release "Web" "$WEB/index.html" >>"$REGISTRO" 2>&1 \
		|| [ ! -s "$WEB/index.html" ] || [ ! -s "$WEB/index.pck" ] || [ ! -s "$WEB/index.wasm" ]; then
	echo "No ha salido la version web. Lo ultimo del registro:"
	tail -n 60 "$REGISTRO"
	exit 1
fi
echo "Listo: build/web ($VERSION_JUEGO, $(du -sh "$WEB" | cut -f1))"
