#!/usr/bin/env bash
# Lo ejecuta el hook PreCompact de .claude/settings.json, justo antes de que
# Claude Code comprima el contexto de la conversacion.
#
# Hace dos cosas:
#   1. Deja por escrito el estado MECANICO del proyecto (commits, archivos sin
#      guardar, sincronizacion con GitHub) en .claude/estado-sesion.md. Esto es
#      automatico y siempre correcto, no depende de que nadie se acuerde.
#   2. Devuelve un JSON pidiendole a Claude que actualice CLAUDE.md, que es
#      donde vive la parte narrativa: en que estabamos y que queda pendiente.
set -u

# La raiz del proyecto se deduce de donde esta este script, no se escribe a
# mano: asi sigue funcionando cuando otra persona clone el repo en otra ruta.
PROYECTO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SALIDA="$PROYECTO/.claude/estado-sesion.md"

cd "$PROYECTO" 2>/dev/null || exit 0

{
	echo "# Estado de la sesion (generado automaticamente)"
	echo
	echo "Escrito el $(date '+%Y-%m-%d a las %H:%M') justo antes de comprimir el contexto."
	echo "Lo genera .claude/estado-sesion.sh. No editar a mano: se sobreescribe."
	echo
	echo "## Ultimos commits"
	echo '```'
	git log --oneline -8 2>/dev/null
	echo '```'
	echo
	echo "## Cambios sin guardar"
	echo '```'
	if [ -n "$(git status --short 2>/dev/null)" ]; then
		git status --short
	else
		echo "(nada, arbol limpio)"
	fi
	echo '```'
	echo
	echo "## Sincronizacion con GitHub"
	echo '```'
	git status -sb 2>/dev/null | head -1
	echo "commits sin subir a origin: $(git log origin/main..main --oneline 2>/dev/null | wc -l)"
	echo '```'
} > "$SALIDA" 2>&1

cat <<'JSON'
{"systemMessage":"Contexto casi lleno. He guardado el estado mecanico en .claude/estado-sesion.md y le he pedido a Claude que repase CLAUDE.md.","hookSpecificOutput":{"hookEventName":"PreCompact","additionalContext":"El contexto se va a comprimir. Antes de continuar, actualiza el CLAUDE.md del proyecto: la fecha de la cabecera, la seccion 'Estado actual' y la de 'Pendiente', para que la proxima sesion sepa en que ibamos sin tener que preguntarlo. El estado mecanico (commits, archivos sin guardar) ya esta en .claude/estado-sesion.md."}}
JSON
