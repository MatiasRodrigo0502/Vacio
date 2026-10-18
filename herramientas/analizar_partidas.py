# -*- coding: utf-8 -*-
"""Resume los registros de partidas de Vacío para equilibrar la dificultad.

El juego guarda cada partida en un .json (scripts/registro_partida.gd). Este
script los lee todos y saca las medias: cómo acaban las partidas de cada mago,
en qué piso se muere, cuánto se tarda y cuánta vida se pierde en cada piso, qué
quita más vida y qué salas son las más duras.

Uso, desde la raíz del proyecto:

    python herramientas/analizar_partidas.py
    python herramientas/analizar_partidas.py carpeta_dani carpeta_matias
    python herramientas/analizar_partidas.py --con-trucos

Sin carpetas, lee las de este ordenador (la carpeta de datos del juego). Con
carpetas, lee todos los .json que haya dentro (también en subcarpetas): para
juntar las de todo el equipo, cada uno manda su carpeta y se pasan todas.

Las partidas con atajos de prueba (F1-F5) se dejan fuera, porque no son
partidas normales: con --con-trucos entran. Las cooperativas (más de un
jugador) también, porque los enemigos tienen más vida y hay compañeros: con
--con-cooperativo entran.

Solo usa la biblioteca estándar de Python.
"""
import argparse
import json
import os
import sys
from collections import Counter, defaultdict

# Para que las tildes salgan bien en la consola de Windows.
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

# Donde las guarda el juego en Windows, Linux y Mac (user://partidas de
# Godot, con el nombre del proyecto, "Vacio").
CARPETAS_DEL_JUEGO = [
    os.path.join(os.environ.get("APPDATA", ""), "Godot", "app_userdata", "Vacio", "partidas"),
    os.path.expanduser("~/.local/share/godot/app_userdata/Vacio/partidas"),
    os.path.expanduser("~/Library/Application Support/Godot/app_userdata/Vacio/partidas"),
]
# Cuántas filas se enseñan en las listas de "lo que más".
TOP = 8


def leer(carpetas):
    partidas = []
    for carpeta in carpetas:
        for raiz, _dirs, archivos in os.walk(carpeta):
            for nombre in sorted(archivos):
                if not nombre.endswith(".json"):
                    continue
                ruta = os.path.join(raiz, nombre)
                try:
                    with open(ruta, encoding="utf-8") as f:
                        partida = json.load(f)
                except (OSError, ValueError) as error:
                    print("No se puede leer %s: %s" % (ruta, error))
                    continue
                if isinstance(partida, dict) and "pisos" in partida:
                    partida["_archivo"] = ruta
                    partidas.append(partida)
    return partidas


def minutos(segundos):
    return "%d:%02d" % (segundos // 60, segundos % 60)


def media(valores):
    return sum(valores) / len(valores) if valores else 0.0


def tabla(cabecera, filas, texto=()):
    """Una tabla de texto con las columnas alineadas: los numeros a la
    derecha y el texto (la primera columna y las de 'texto') a la izquierda."""
    filas = [[str(c) for c in fila] for fila in filas]
    anchos = [max(len(str(c)) for c in col) for col in zip(cabecera, *filas)]
    izquierda = {0, *texto}
    linea = lambda fila: "  ".join(c.ljust(a) if i in izquierda else c.rjust(a)
                                   for i, (c, a) in enumerate(zip(fila, anchos))).rstrip()
    print(linea(cabecera))
    print("  ".join("-" * a for a in anchos))
    for fila in filas:
        print(linea(fila))
    print()


def resumir(partidas):
    print("Partidas: %d  (%s)" % (len(partidas), ", ".join(
        "%d %s" % (n, r) for r, n in Counter(p["resultado"] for p in partidas).most_common())))
    print("Tiempo jugado: %s" % minutos(sum(p["segundos"] for p in partidas)))
    versiones = Counter(p.get("version", "?") for p in partidas)
    print("Versiones: %s" % ", ".join("%s (%d)" % v for v in sorted(versiones.items())))
    print()

    # --- Por mago ---------------------------------------------------------
    print("== POR MAGO ==")
    por_mago = defaultdict(list)
    for p in partidas:
        por_mago[p["mago"]].append(p)
    filas = []
    for mago, suyas in sorted(por_mago.items()):
        acabadas = [p for p in suyas if p["resultado"] in ("victoria", "derrota")]
        filas.append([
            mago, len(suyas),
            sum(p["resultado"] == "victoria" for p in suyas),
            sum(p["resultado"] == "derrota" for p in suyas),
            "%.1f" % media([p["piso_alcanzado"] for p in acabadas]) if acabadas else "-",
            max(p["piso_alcanzado"] for p in suyas),
            minutos(media([p["segundos"] for p in suyas])),
        ])
    tabla(["mago", "partidas", "victorias", "derrotas", "piso medio", "mejor", "duración"], filas)

    # --- Por piso -----------------------------------------------------------
    # Un piso cuenta si se llegó a jugar; "muertes" es cuántas de las que
    # llegaron acabaron ahí (la proporción es lo que dice si un piso es duro).
    print("== POR PISO ==")
    pisos = defaultdict(list)
    muertes = Counter()
    for p in partidas:
        for piso in p["pisos"]:
            pisos[piso["piso"]].append(piso)
        if p["resultado"] == "derrota" and p.get("muerte"):
            muertes[p["muerte"]["piso"]] += 1
    filas = []
    for numero in sorted(pisos):
        jugados = pisos[numero]
        perdida = [sum(g["vida"] for g in piso["golpes"]) for piso in jugados]
        de_que = Counter()
        for piso in jugados:
            for golpe in piso["golpes"]:
                de_que[golpe["por"]] += golpe["vida"]
        principal = ", ".join("%s %d" % d for d in de_que.most_common(2))
        filas.append([
            "%d %s" % (numero, jugados[0].get("capa", "")), len(jugados),
            "%d (%d%%)" % (muertes[numero], 100 * muertes[numero] / len(jugados)),
            minutos(media([piso["segundos"] for piso in jugados])),
            "%.1f" % media(perdida),
            "%.1f" % media([piso["vida_recuperada"] for piso in jugados]),
            "%d%%" % (100 * media([1 if piso["especial_usado"] else 0 for piso in jugados])),
            principal,
        ])
    tabla(["piso", "jugado", "muertes", "tiempo", "vida -", "vida +", "especial",
           "lo que más quita"], filas, texto=[7])

    # --- Lo que quita vida ------------------------------------------------
    print("== LO QUE MÁS VIDA QUITA ==")
    golpes = Counter()
    vida = Counter()
    mata = Counter(p["muerte"]["por"] for p in partidas
                   if p["resultado"] == "derrota" and p.get("muerte"))
    for p in partidas:
        for piso in p["pisos"]:
            for golpe in piso["golpes"]:
                # Lo que quita el veneno poco a poco no es un golpe.
                if not golpe.get("veneno"):
                    golpes[golpe["por"]] += 1
                vida[golpe["por"]] += golpe["vida"]
    tabla(["qué", "golpes", "vida", "muertes"],
          [[por, golpes[por], v, mata[por]] for por, v in vida.most_common(TOP)])

    # --- Salas ------------------------------------------------------------
    print("== SALAS MÁS DURAS (vida perdida de media) ==")
    salas = defaultdict(list)
    for p in partidas:
        for piso in p["pisos"]:
            for sala in piso["salas"]:
                salas[(piso["piso"], sala["sala"])].append(sala)
    filas = []
    for (numero, celda), peleas in salas.items():
        enemigos = peleas[0]["enemigos"]
        filas.append([
            "piso %d, sala %s" % (numero, celda), len(peleas),
            "%.1f" % media([s["vida_perdida"] for s in peleas]),
            minutos(media([s["segundos"] for s in peleas])),
            ", ".join("%s x%d" % e for e in sorted(enemigos.items())),
        ])
    filas.sort(key=lambda f: -float(f[2]))
    tabla(["sala", "peleas", "vida -", "tiempo", "enemigos"], filas[:TOP], texto=[4])

    # --- Objetos ----------------------------------------------------------
    objetos = Counter(o for p in partidas for piso in p["pisos"] for o in piso["objetos"])
    if objetos:
        print("== OBJETOS COGIDOS ==")
        tabla(["objeto", "veces"], objetos.most_common())


def main():
    analizador = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    analizador.add_argument("carpetas", nargs="*", help="carpetas con los .json")
    analizador.add_argument("--con-trucos", action="store_true",
                            help="contar también las partidas con atajos de prueba")
    analizador.add_argument("--con-cooperativo", action="store_true",
                            help="contar también las partidas de varios jugadores")
    opciones = analizador.parse_args()

    carpetas = opciones.carpetas or [c for c in CARPETAS_DEL_JUEGO if os.path.isdir(c)]
    if not carpetas:
        print("No hay partidas guardadas en este ordenador. Juega una, o pasa la carpeta.")
        return 1
    partidas = leer(carpetas)
    if not opciones.con_trucos:
        con_trucos = [p for p in partidas if p.get("trucos")]
        partidas = [p for p in partidas if not p.get("trucos")]
        if con_trucos:
            print("(%d partidas con atajos de prueba fuera; --con-trucos para verlas)\n"
                  % len(con_trucos))
    if not opciones.con_cooperativo:
        # Las de antes de la fase 2 no traen "jugadores": eran de uno.
        varios = [p for p in partidas if p.get("jugadores", 1) > 1]
        partidas = [p for p in partidas if p.get("jugadores", 1) <= 1]
        if varios:
            print("(%d partidas cooperativas fuera; --con-cooperativo para verlas)\n"
                  % len(varios))
    if not partidas:
        print("No hay partidas que resumir.")
        return 1
    resumir(partidas)
    return 0


if __name__ == "__main__":
    sys.exit(main())
