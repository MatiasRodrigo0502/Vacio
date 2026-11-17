#!/usr/bin/env bash
# Lo que hace Vercel al construir la version del navegador (vercel.json): baja la
# de la ultima version publicada (Vacio-web.tar.gz, la empaqueta GitHub en
# .github/workflows/publicar.yml) y la deja en build/web, que es lo que sirve.
#
# POR QUE NO SE SUBE DESDE GITHUB: Vercel gratis no deja subirle mas de 100 MB de
# una vez, y la version web pasa de 100 (el .pck y el .wasm). Lo que se crea al
# construir no tiene ese limite.
#
# CUANDO: GitHub avisa a Vercel al publicar cada version (secreto
# VERCEL_DEPLOY_HOOK). Los push a main no la rehacen por su cuenta (vercel.json,
# "deploymentEnabled"): en ese momento la version nueva aun no esta publicada.
set -euo pipefail

URL="https://github.com/MatiasRodrigo0502/Vacio/releases/latest/download/Vacio-web.tar.gz"
DESTINO="build/web"

rm -rf "$DESTINO"
mkdir -p "$DESTINO"
curl -fsSL --retry 3 "$URL" | tar -xz -C "$DESTINO"
if [ ! -s "$DESTINO/index.html" ] || [ ! -s "$DESTINO/index.pck" ] || [ ! -s "$DESTINO/index.wasm" ]; then
	echo "La version web bajada no esta completa"
	exit 1
fi
echo "Listo: $DESTINO ($(du -sh "$DESTINO" | cut -f1))"
