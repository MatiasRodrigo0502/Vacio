# -*- coding: utf-8 -*-
"""Genera el arte del castillo maldito: los 12 pisos, de los calabozos al salon
del trono. Pedido por Matias el 2026-11-19: «hazme assets para cambiar el mapa
completo, quiero un cambio radical», en vectorial como los magos, con otro tema
(eligio el castillo maldito) y salas de otras formas (FormaSala, en el juego).

Cuatro zonas de tres pisos, y en cada piso su suelo, su pared y su cara un poco
distintos (mas paja, mas limo, mas grietas malditas...):

    calabozos  1-3    piedra fria, paja, cadenas y antorchas
    cloacas    4-6    ladrillo, cantos mojados, charcos y limo verde
    cripta     7-9    marmol palido, nichos con calaveras y velas moradas
    trono     10-12   marmol negro y vino, oro, estandartes y grietas malditas

Lo que sale, en assets/castillo/:
- <zona>/: lo de toda la zona. Los obstaculos (roca_K, bloque_K, grupo_K,
  plataforma_K, cada uno con su _v para el movil en vertical: la misma pieza
  con los lados cambiados, ver Obstaculo), las piedrecitas del suelo (piedra_K),
  lo que va encima de las mesas (vegetacion_K), lo que crece en la pared
  (adorno_K) y cuelga de su cara (colgante_K), el pilar de las puertas, la
  bajada (abierta y tapada) y catalogo.tres (CatalogoObstaculos).
- piso_NN/: lo de cada piso. suelo.png, muro.png (la pared vista desde arriba),
  cara.png (la de arriba, de frente) y estilo_borde.tres (EstiloBorde).

LA LUZ SE MIDE: al acabar, cada obstaculo se compara con el suelo de sus pisos
(ver CLAUDE.md: «Las rocas se calibran contra el suelo de su piso»). Lo que
estorba tiene que leerse de un vistazo: su luminosidad entre la del suelo nunca
entre 0,45 y 1,6. Si una pieza cae ahi, se aclara u oscurece entera hasta salir.

Solo semillas fijas: volver a ejecutarlo da los mismos archivos.

    python herramientas/generar_castillo.py
"""
import math
import os
import random
import sys

from PIL import Image, ImageStat

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from castillo_svg import (CONTORNO, Lienzo, _pintar_svg, aclarar, antorcha, cadena, calavera, destello, f, hueso,  # noqa: E402
                          llama, luz, mezclar, oscurecer, piedra_irregular, poligono, redondeado, rgb,
                          sombra_suelo, vela)
import castillo_piezas as P  # noqa: E402

RAIZ = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SALIDA = os.path.join(RAIZ, "assets", "castillo")
RES = "res://assets/castillo"

SUELO = 512      # la baldosa del suelo
BALDOSA_CLOACAS = 1024   # la de las cloacas, el doble (suelo_cloacas)
MURO = 256       # la de la pared vista desde arriba
CARA_ANCHO = 512
ALTO_CARA = 72   # EstiloBorde.alto_cara: la cara de la pared de arriba
TRAZO = 4.5      # el contorno de los obstaculos, en pixeles de su textura

# --- Zonas ---------------------------------------------------------------------
# Cada zona: sus colores. 'suelo' es el color de las losas; el resto, lo que
# usan sus piezas. Los pisos de la zona cambian el suelo y la cara con su
# 'variante' (0, 1 o 2).
ZONAS = {
    "calabozos": {
        "pisos": [1, 2, 3],
        "suelo": "#3c4049", "junta": "#15161b", "suelo_luz": "#6a7080",
        "muro": "#33363f", "muro_junta": "#141519",
        "cara": "#5d6270", "cara_junta": "#1b1c22", "cara_pie": "#2a2c33",
        "luz": "#a9b0c2", "sombra": "#06060a",
        "madera": "#8a5a34", "madera_osc": "#5a3a22", "hierro": "#5c616c", "piedra": "#7b808e",
        "tela": "#b39a6a", "paja": "#d4ae55", "musgo": "#5d7d3c", "hueso": "#e2d7bb",
        "fuego": ("#fff4c0", "#ffc23a", "#ff6a1a", "#c0200a"),
        "tinte": (0.86, 0.9, 1.0),
    },
    "cloacas": {
        "pisos": [4, 5, 6],
        "suelo": "#3b3b2e", "junta": "#121410", "suelo_luz": "#6c6f4e",
        "muro": "#3b2f27", "muro_junta": "#150f0c",
        "cara": "#7a5240", "cara_junta": "#1d130f", "cara_pie": "#2e2a1c",
        "luz": "#c4ab88", "sombra": "#050504",
        "madera": "#6e5634", "madera_osc": "#443522", "hierro": "#6b5446", "piedra": "#6f7466",
        "tela": "#8b8a5a", "paja": "#a99a50", "musgo": "#6f9e3a", "hueso": "#d6ccae",
        "agua": "#1d3a3a", "agua_luz": "#7fc2b0", "limo": "#8ccc3e",
        "fuego": ("#f2ffd0", "#b6f05a", "#58c23a", "#1f6a1a"),
        "tinte": (0.84, 0.96, 0.82),
    },
    "cripta": {
        "pisos": [7, 8, 9],
        "suelo": "#3e3b46", "junta": "#18161d", "suelo_luz": "#77718a",
        "muro": "#2f2c37", "muro_junta": "#131117",
        "cara": "#6f6979", "cara_junta": "#1e1b24", "cara_pie": "#2c2933",
        "luz": "#c3bad6", "sombra": "#06050a",
        "madera": "#5e4632", "madera_osc": "#3a2a1e", "hierro": "#5a5866", "piedra": "#a29cae",
        "tela": "#6b3a6e", "paja": "#9b8a6a", "musgo": "#55684a", "hueso": "#e6dcc2",
        "fuego": ("#fbefff", "#d79cff", "#9a4ae0", "#4a1a8a"),
        "tinte": (0.9, 0.84, 1.0),
    },
    "trono": {
        "pisos": [10, 11, 12],
        "suelo": "#2f1d2a", "suelo_b": "#17131b", "junta": "#0c090d", "suelo_luz": "#6e4a64",
        "muro": "#271d2e", "muro_junta": "#0f0b12",
        "cara": "#3f3049", "cara_junta": "#140f18", "cara_pie": "#1c1522",
        "luz": "#e2c47a", "sombra": "#050307",
        "madera": "#6a3a2a", "madera_osc": "#3e2018", "hierro": "#4e4a5c", "piedra": "#9d97a8",
        "tela": "#9c1f2c", "paja": "#c9a04a", "musgo": "#4a3a5a", "hueso": "#e0d6c0",
        "oro": "#d8a93e", "maldito": "#b05cff",
        "fuego": ("#fff6d8", "#ffcf5a", "#ff8a2a", "#a8400a"),
        "tinte": (1.0, 0.9, 0.78),
    },
}

# Los 12 pisos: zona, variante y nombre (DatosPiso.nombre_capa, el del HUD).
PISOS = {
    1: ("calabozos", 0, "Calabozo de la entrada"),
    2: ("calabozos", 1, "Celdas de los olvidados"),
    3: ("calabozos", 2, "Sala de tormentos"),
    4: ("cloacas", 0, "Cloacas del castillo"),
    5: ("cloacas", 1, "Canal de los desechos"),
    6: ("cloacas", 2, "Aljibe inundado"),
    7: ("cripta", 0, "Osario"),
    8: ("cripta", 1, "Cripta de los caballeros"),
    9: ("cripta", 2, "Catacumbas reales"),
    10: ("trono", 0, "Galería de los reyes"),
    11: ("trono", 1, "Antecámara maldita"),
    12: ("trono", 2, "Salón del trono maldito"),
}


def azar_de(*claves):
    return random.Random("|".join(str(c) for c in claves))


def variar(color, azar, cuanto):
    """El color un poco mas claro u oscuro, al azar."""
    t = azar.uniform(-cuanto, cuanto)
    return aclarar(color, t) if t > 0 else oscurecer(color, -t)


# --- Suelo ---------------------------------------------------------------------

def _losa(L, azar, x, y, w, h, color, junta, luz_borde, r=7.0, inset=3.0):
    """Una losa de piedra vista desde arriba: algo mas clara arriba a la
    izquierda (la luz), con el canto de luz y el de sombra, y alguna
    desportilladura."""
    x0, y0, x1, y1 = x + inset, y + inset, x + w - inset, y + h - inset
    base = variar(color, azar, 0.09)
    L.rect(x0, y0, x1 - x0, y1 - y0, L.lineal([(0, aclarar(base, 0.08)), (1, oscurecer(base, 0.1))],
                                             0, 0, 1, 1), trazo=None, r=r)
    L.linea("M %s %s L %s %s L %s %s" % (f(x0 + r), f(y1 - 1.5), f(x1 - 1.5), f(y1 - 1.5), f(x1 - 1.5), f(y0 + r)),
            oscurecer(base, 0.45), 2.4, 0.8)
    L.linea("M %s %s L %s %s L %s %s" % (f(x0 + 1.5), f(y1 - r), f(x0 + 1.5), f(y0 + 1.5), f(x1 - r), f(y0 + 1.5)),
            luz_borde, 1.6, 0.35)
    # Desportillado en alguna esquina.
    if azar.random() < 0.4:
        ex = x0 if azar.random() < 0.5 else x1
        ey = y0 if azar.random() < 0.5 else y1
        sx, sy = (1 if ex == x0 else -1), (1 if ey == y0 else -1)
        t = azar.uniform(6, 13)
        L.forma(poligono([(ex, ey), (ex + sx * t, ey), (ex + sx * t * 0.3, ey + sy * t * 0.4), (ex, ey + sy * t)]),
                junta, trazo=None)
    return base


def _grieta(L, azar, x, y, largo, color, ancho=1.8, opacidad=0.8):
    puntos = [(x, y)]
    ang = azar.uniform(0, math.tau)
    for _ in range(azar.randint(3, 6)):
        ang += azar.uniform(-0.8, 0.8)
        paso = largo / 5.0
        x += math.cos(ang) * paso
        y += math.sin(ang) * paso
        puntos.append((x, y))
    L.linea("M " + " L ".join("%s %s" % (f(a), f(b)) for a, b in puntos), color, ancho, opacidad)
    return puntos


def suelo_calabozos(z, v):
    L = Lienzo(SUELO, SUELO)
    azar = azar_de("suelo", "calabozos", v)
    L.rect(0, 0, SUELO, SUELO, z["junta"], trazo=None)
    alto = 128
    for fila in range(SUELO // alto):
        desfase = 64 if fila % 2 else 0
        # Cada fila llena justo un ancho de baldosa (de -desfase a SUELO - desfase): lo
        # que se sale por la izquierda lo pone la baldosa de al lado (mosaico). Antes
        # llegaba hasta pasar de SUELO, y en la junta de dos baldosas las losas se
        # pisaban: una raya en el suelo cada 512 px (Matias, 2026-11-19, piso 4).
        x = -desfase
        while x < SUELO - desfase:
            ancho = 128 if azar.random() < 0.7 and x + 128 <= SUELO - desfase else 64
            _losa(L, azar, x, fila * alto, ancho, alto, z["suelo"], z["junta"], z["suelo_luz"])
            x += ancho
    for _ in range(9 + v * 4):
        _grieta(L, azar, azar.uniform(0, SUELO), azar.uniform(0, SUELO), azar.uniform(30, 70), z["junta"])
    # Paja por el suelo (mas en las celdas) y musgo en las juntas.
    for _ in range(14 + v * 22):
        x, y = azar.uniform(0, SUELO), azar.uniform(0, SUELO)
        a = azar.uniform(0, math.tau)
        largo = azar.uniform(8, 18)
        L.linea("M %s %s L %s %s" % (f(x), f(y), f(x + math.cos(a) * largo), f(y + math.sin(a) * largo)),
                variar(z["paja"], azar, 0.15), 2.0, 0.55)
    for _ in range(v * 10):
        x, y = azar.choice(range(0, SUELO, 64)), azar.uniform(0, SUELO)
        L.elipse(x, y, azar.uniform(5, 12), azar.uniform(3, 6), z["musgo"], trazo=None, extra='opacity="0.55"')
    # La sala de tormentos: manchas de oxido.
    for _ in range(v * v * 2):
        cx, cy = azar.uniform(0, SUELO), azar.uniform(0, SUELO)
        L.forma(piedra_irregular(azar, cx, cy, azar.uniform(14, 30), azar.uniform(9, 18), 9, 0.35),
                "#5a2418", trazo=None, extra='opacity="0.35"')
    return L.mosaico()


def suelo_cloacas(z, v):
    # La baldosa, el doble que las demas (BALDOSA_CLOACAS): sus charcos son lo que mas
    # se ve, y a 512 los mismos tres salian en cuadricula por toda la sala (Matias,
    # 2026-11-19: «los assets del suelo del piso 4 se ven muy mal»). A 1024 se repiten
    # una vez por sala como mucho. La sala pinta el suelo con el tamano que tenga.
    lado_baldosa = BALDOSA_CLOACAS
    L = Lienzo(lado_baldosa, lado_baldosa)
    azar = azar_de("suelo", "cloacas", v)
    L.rect(0, 0, lado_baldosa, lado_baldosa, z["junta"], trazo=None)
    lado = 64
    for fila in range(lado_baldosa // lado):
        desfase = lado // 2 if fila % 2 else 0
        # Una piedra por hueco, solo los de dentro de la baldosa: las que asoman por un
        # lado las pone la baldosa de al lado (mosaico). Con una columna de mas a cada
        # lado, en la junta salian dos piedras distintas una encima de otra y se veia
        # un corte recto en cada junta (Matias, 2026-11-19).
        for col in range(lado_baldosa // lado):
            cx = col * lado + desfase + lado * 0.5 + azar.uniform(-3, 3)
            cy = fila * lado + lado * 0.5 + azar.uniform(-3, 3)
            base = variar(z["suelo"], azar, 0.12)
            # Casi tocandose: con mas junta parecian puntos sobre un suelo negro.
            d = piedra_irregular(azar, cx, cy, lado * 0.53, lado * 0.5, 9, 0.1)
            L.forma(d, L.radial([(0, aclarar(base, 0.14)), (0.75, base), (1, oscurecer(base, 0.25))],
                                0.4, 0.35, 0.7), trazo=oscurecer(z["junta"], 0.2), ancho=1.5)
    # Charcos (mas en el aljibe) y limo. Con cuatro veces la superficie, el doble de
    # charcos que en una baldosa de 512: la mitad por metro, que llenaban el suelo.
    for _ in range((3 + v * 3) * 2):
        cx, cy = azar.uniform(0, lado_baldosa), azar.uniform(0, lado_baldosa)
        rx, ry = azar.uniform(26, 60), azar.uniform(16, 34)
        d = piedra_irregular(azar, cx, cy, rx, ry, 11, 0.25)
        L.forma(d, z["agua"], trazo=oscurecer(z["agua"], 0.4), ancho=2.0, extra='opacity="0.88"')
        L.linea("M %s %s q %s %s %s %s" % (f(cx - rx * 0.5), f(cy - ry * 0.25), f(rx * 0.3), f(-ry * 0.3),
                                         f(rx * 0.6), f(-ry * 0.1)), z["agua_luz"], 2.2, 0.55)
    for _ in range((6 + v * 6) * 4):
        cx, cy = azar.uniform(0, lado_baldosa), azar.uniform(0, lado_baldosa)
        L.forma(piedra_irregular(azar, cx, cy, azar.uniform(6, 14), azar.uniform(4, 9), 7, 0.3),
                z["limo"], trazo=None, extra='opacity="0.4"')
    return L.mosaico()


def suelo_cripta(z, v):
    L = Lienzo(SUELO, SUELO)
    azar = azar_de("suelo", "cripta", v)
    L.rect(0, 0, SUELO, SUELO, z["junta"], trazo=None)
    lado = 128
    for i in range(4):
        for j in range(4):
            color = z["suelo"] if (i + j) % 2 == 0 else oscurecer(z["suelo"], 0.08)
            base = _losa(L, azar, i * lado, j * lado, lado, lado, color, z["junta"], z["suelo_luz"], r=3.0,
                         inset=2.5)
            # Vetas del marmol.
            for _ in range(2):
                y = j * lado + azar.uniform(15, lado - 15)
                L.linea("M %s %s C %s %s %s %s %s %s" % (
                    f(i * lado + 6), f(y), f(i * lado + 40), f(y + azar.uniform(-25, 25)),
                    f(i * lado + 85), f(y + azar.uniform(-25, 25)), f(i * lado + lado - 6), f(y + azar.uniform(-12, 12))),
                    aclarar(base, 0.22), 1.3, 0.35)
            # Losas grabadas: un circulo de runas.
            if v >= 1 and azar.random() < 0.08 + 0.06 * v:
                cx, cy = i * lado + lado / 2, j * lado + lado / 2
                L.elipse(cx, cy, 36, 36, "none", trazo="#7d5fae", ancho=2.0, extra='opacity="0.4"')
                L.elipse(cx, cy, 26, 26, "none", trazo="#7d5fae", ancho=1.2, extra='opacity="0.35"')
                for k in range(6):
                    a = k * math.tau / 6 + azar.uniform(0, 0.3)
                    L.linea("M %s %s l %s %s" % (f(cx + math.cos(a) * 29), f(cy + math.sin(a) * 29),
                                                 f(math.cos(a + 1.2) * 6), f(math.sin(a + 1.2) * 6)),
                            "#9a7ad0", 1.6, 0.4)
    for _ in range(10 + v * 6):
        _grieta(L, azar, azar.uniform(0, SUELO), azar.uniform(0, SUELO), azar.uniform(25, 60), z["junta"], 1.6)
    # Polvo de hueso.
    for _ in range(18):
        L.elipse(azar.uniform(0, SUELO), azar.uniform(0, SUELO), azar.uniform(1.5, 3.5), azar.uniform(1, 2.5),
                 z["hueso"], trazo=None, extra='opacity="0.35"')
    if v == 2:
        _grietas_malditas(L, azar, 4, z.get("maldito", "#a86aff"))
    return L.mosaico()


def _grietas_malditas(L, azar, cuantas, color):
    """Grietas que brillan: la maldicion del castillo asomando por el suelo."""
    halo = L.difuso(5)
    for _ in range(cuantas):
        x, y = azar.uniform(0, SUELO), azar.uniform(0, SUELO)
        puntos = _grieta(L, azar, x, y, azar.uniform(70, 130), color, 2.4, 0.0)
        d = "M " + " L ".join("%s %s" % (f(a), f(b)) for a, b in puntos)
        L.linea(d, color, 8.0, 0.55, extra='filter="%s"' % halo)
        L.linea(d, CONTORNO, 3.5, 0.9)
        L.linea(d, aclarar(color, 0.45), 1.6, 0.95)


def suelo_trono(z, v):
    L = Lienzo(SUELO, SUELO)
    azar = azar_de("suelo", "trono", v)
    L.rect(0, 0, SUELO, SUELO, z["junta"], trazo=None)
    lado = 128
    for i in range(4):
        for j in range(4):
            color = z["suelo"] if (i + j) % 2 == 0 else z["suelo_b"]
            base = _losa(L, azar, i * lado, j * lado, lado, lado, color, z["junta"], z["suelo_luz"], r=2.0,
                         inset=2.0)
            for _ in range(3):
                y = j * lado + azar.uniform(10, lado - 10)
                L.linea("M %s %s C %s %s %s %s %s %s" % (
                    f(i * lado + 4), f(y), f(i * lado + 45), f(y + azar.uniform(-30, 30)),
                    f(i * lado + 80), f(y + azar.uniform(-30, 30)), f(i * lado + lado - 4), f(y + azar.uniform(-15, 15))),
                    aclarar(base, 0.3), 1.2, 0.3)
    # Rombos de oro en los cruces.
    for i in range(5):
        for j in range(5):
            cx, cy = i * lado, j * lado
            L.forma(poligono([(cx, cy - 11), (cx + 11, cy), (cx, cy + 11), (cx - 11, cy)]),
                    L.lineal([(0, aclarar(z["oro"], 0.35)), (1, oscurecer(z["oro"], 0.3))], 0, 0, 1, 1),
                    trazo=CONTORNO, ancho=1.6)
    if v >= 1:
        _grietas_malditas(L, azar, 2 + v * 2, z["maldito"])
    return L.mosaico()


SUELOS = {"calabozos": suelo_calabozos, "cloacas": suelo_cloacas, "cripta": suelo_cripta, "trono": suelo_trono}


# --- Pared vista desde arriba ---------------------------------------------------

def muro(nombre, z, v):
    """La roca de encima de la pared y del fondo: sillares vistos desde arriba.
    Oscura: es el marco de la sala, y lo que se mira es lo de dentro."""
    L = Lienzo(MURO, MURO)
    azar = azar_de("muro", nombre, v)
    L.rect(0, 0, MURO, MURO, z["muro_junta"], trazo=None)
    if nombre == "cloacas":
        alto, ancho = 32, 64
    elif nombre == "cripta":
        alto, ancho = 64, 128
    else:
        alto, ancho = 64, 128
    for fila in range(MURO // alto):
        desfase = ancho // 2 if fila % 2 else 0
        x = -desfase
        while x < MURO:
            base = _losa(L, azar, x, fila * alto, ancho, alto, z["muro"], z["muro_junta"],
                         aclarar(z["muro"], 0.35), r=4.0, inset=2.5)
            if nombre == "cloacas" and azar.random() < 0.15:
                L.elipse(x + azar.uniform(10, ancho - 10), fila * alto + alto / 2, azar.uniform(8, 18), 6,
                         z["musgo"], trazo=None, extra='opacity="0.5"')
            x += ancho
    if nombre == "trono":
        for fila in range(MURO // alto + 1):
            L.linea("M 0 %s L %s %s" % (f(fila * alto), f(MURO), f(fila * alto)), z["oro"], 1.6, 0.45)
    return L.mosaico()


# --- Cara de la pared de arriba -----------------------------------------------

def _hilada(L, azar, y, alto, color, junta, minimo, maximo):
    """Una hilada de sillares a lo ancho de la cara, que empalma por los lados."""
    x = -azar.uniform(0, maximo)
    while x < CARA_ANCHO:
        ancho = azar.uniform(minimo, maximo)
        base = variar(color, azar, 0.08)
        L.rect(x + 1.5, y + 1.5, ancho - 3, alto - 3,
               L.lineal([(0, aclarar(base, 0.12)), (1, oscurecer(base, 0.12))], 0, 0, 0, 1),
               trazo=None, r=2.5)
        L.linea("M %s %s L %s %s" % (f(x + 3), f(y + 2.5), f(x + ancho - 3), f(y + 2.5)),
                aclarar(base, 0.3), 1.3, 0.5)
        x += ancho


def cara(nombre, z, v):
    """La cara de la pared de arriba, de frente: el labio arriba (le da la luz),
    las hiladas de sillares o ladrillos y el zocalo oscuro al pie. Se repite a lo
    ancho."""
    L = Lienzo(CARA_ANCHO, ALTO_CARA)
    azar = azar_de("cara", nombre, v)
    L.rect(0, 0, CARA_ANCHO, ALTO_CARA, z["cara_junta"], trazo=None)
    labio = 9
    pie = 7
    cuerpo = ALTO_CARA - labio - pie
    if nombre == "cloacas":
        hiladas = 4
        tam = (34, 52)
    elif nombre == "trono":
        hiladas = 2
        tam = (90, 140)
    else:
        hiladas = 2
        tam = (60, 120)
    alto = cuerpo / hiladas
    for k in range(hiladas):
        _hilada(L, azar, labio + k * alto, alto, z["cara"], z["cara_junta"], *tam)
    # El labio (coronacion) y el zocalo.
    L.rect(0, 0, CARA_ANCHO, labio, L.lineal([(0, aclarar(z["cara"], 0.35)), (1, z["cara"])]), trazo=None)
    L.linea("M 0 %s L %s %s" % (f(labio), f(CARA_ANCHO), f(labio)), CONTORNO, 2.0, 0.8)
    L.rect(0, ALTO_CARA - pie, CARA_ANCHO, pie, z["cara_pie"], trazo=None)
    L.linea("M 0 %s L %s %s" % (f(ALTO_CARA - pie), f(CARA_ANCHO), f(ALTO_CARA - pie)), CONTORNO, 1.6, 0.7)
    if nombre == "calabozos":
        _cara_calabozos(L, azar, z, v, labio)
    elif nombre == "cloacas":
        _cara_cloacas(L, azar, z, v, labio)
    elif nombre == "cripta":
        _cara_cripta(L, azar, z, v, labio)
    else:
        _cara_trono(L, azar, z, v, labio)
    # Musgo al pie, en las de abajo.
    if nombre in ("calabozos", "cloacas") and v >= 1:
        for _ in range(6 + v * 3):
            x = azar.uniform(0, CARA_ANCHO)
            L.forma(piedra_irregular(azar, x, ALTO_CARA - pie, azar.uniform(8, 18), azar.uniform(4, 8), 8, 0.3),
                    z["musgo"], trazo=None, extra='opacity="0.75"')
    return _cara_imagen(L)


def _cara_imagen(L):
    """La cara solo empalma a lo ancho: se pinta con lo de los lados repetido y
    se recorta, como el mosaico, pero sin repetir hacia arriba ni hacia abajo."""
    cuerpo = "".join(L.cuerpo)
    L.cuerpo = ['<g id="baldosa">%s</g>' % cuerpo,
                '<use xlink:href="#baldosa" x="%d" y="0"/>' % -L.w,
                '<use xlink:href="#baldosa" x="%d" y="0"/>' % L.w]
    margen = 24
    w = L.w + margen * 2
    grande = _pintar_svg(L.svg(w * 2, L.h * 2, (-margen, 0, w, L.h)))
    grande = grande.convert("RGBa").resize((w, L.h), Image.LANCZOS).convert("RGBA")
    return grande.crop((margen, 0, margen + L.w, L.h))


def _cara_calabozos(L, azar, z, v, labio):
    # Una argolla con su cadena, y en la sala de tormentos, grilletes.
    for k in range(1 + (v >= 1)):
        x = 120 + k * 260 + azar.uniform(-30, 30)
        y = labio + 18
        L.elipse(x, y, 7, 7, "none", trazo=CONTORNO, ancho=5)
        L.elipse(x, y, 7, 7, "none", trazo=z["hierro"], ancho=2.6)
        if v == 2:
            cadena(L, x, y + 6, x + 22, y + 30, 6, z["hierro"])
            L.elipse(x + 24, y + 33, 6, 4, "none", trazo=CONTORNO, ancho=4.5)
            L.elipse(x + 24, y + 33, 6, 4, "none", trazo=z["hierro"], ancho=2.2)
    # Un ventanuco con barrotes en las celdas.
    if v >= 1:
        x = 390
        L.rect(x, labio + 8, 34, 22, "#0a0b0e", trazo=CONTORNO, ancho=2.5, r=3)
        for k in range(4):
            L.linea("M %s %s L %s %s" % (f(x + 5 + k * 8), f(labio + 9), f(x + 5 + k * 8), f(labio + 29)),
                    z["hierro"], 2.4)


def _cara_cloacas(L, azar, z, v, labio):
    # Un desague en arco con su reja, y el limo que cae de el.
    x = 256
    boca = 30
    arco = "M %s %s L %s %s A %s %s 0 0 1 %s %s L %s %s Z" % (
        f(x - boca), f(ALTO_CARA - 7), f(x - boca), f(labio + 26), f(boca), f(boca * 0.8),
        f(x + boca), f(labio + 26), f(x + boca), f(ALTO_CARA - 7))
    L.forma(arco, "#0a0d0b", trazo=CONTORNO, ancho=3)
    for k in range(5):
        xx = x - boca + 8 + k * 11
        L.linea("M %s %s L %s %s" % (f(xx), f(labio + 14), f(xx), f(ALTO_CARA - 7)), z["hierro"], 2.6)
    L.linea("M %s %s L %s %s" % (f(x - boca + 4), f(labio + 30), f(x + boca - 4), f(labio + 30)), z["hierro"], 2.4)
    for _ in range(2 + v):
        xx = azar.uniform(20, CARA_ANCHO - 20)
        largo = azar.uniform(18, 40)
        L.forma("M %s %s q %s %s %s %s q %s %s %s %s Z" % (
            f(xx - 5), f(labio), f(-2), f(largo * 0.6), f(4), f(largo), f(6), f(-largo * 0.4), f(6), f(-largo)),
            z["limo"], trazo=None, extra='opacity="0.6"')


def _cara_cripta(L, azar, z, v, labio):
    # Nichos con calaveras, como un osario.
    for k in range(2):
        x = 128 + k * 256
        nicho = "M %s %s L %s %s A 18 16 0 0 1 %s %s L %s %s Z" % (
            f(x - 18), f(ALTO_CARA - 12), f(x - 18), f(labio + 22), f(x + 18), f(labio + 22),
            f(x + 18), f(ALTO_CARA - 12))
        L.forma(nicho, "#0c0a10", trazo=CONTORNO, ancho=3)
        if k == 0 or v >= 1:
            calavera(L, x, ALTO_CARA - 24, 9, z["hueso"])
        else:
            vela(L, x, ALTO_CARA - 13, 26, fuego=z["fuego"])
    # Grietas.
    for _ in range(3 + v * 2):
        _grieta(L, azar, azar.uniform(0, CARA_ANCHO), azar.uniform(labio + 4, ALTO_CARA - 10), 22, z["cara_junta"],
                1.5, 0.8)


def _cara_trono(L, azar, z, v, labio):
    # Pilastras con capitel de oro y una cenefa de oro bajo el labio.
    L.rect(0, labio + 1, CARA_ANCHO, 5, L.lineal([(0, aclarar(z["oro"], 0.3)), (1, oscurecer(z["oro"], 0.3))]),
           trazo=None)
    for x in (0, 256):
        L.rect(x - 15, labio, 30, ALTO_CARA - labio - 7,
               L.lineal([(0, oscurecer(z["cara"], 0.15)), (0.5, aclarar(z["cara"], 0.18)),
                         (1, oscurecer(z["cara"], 0.25))], 0, 0, 1, 0), ancho=2.5)
        L.rect(x - 18, labio, 36, 9, L.lineal([(0, aclarar(z["oro"], 0.35)), (1, oscurecer(z["oro"], 0.3))]),
               ancho=2.2, r=2)
        L.rect(x - 18, ALTO_CARA - 15, 36, 8, oscurecer(z["oro"], 0.15), ancho=2.2, r=2)
    # Paneles con marco de oro entre las pilastras.
    for x in (128,):
        for xx in (x, x + 256):
            L.rect(xx - 70, labio + 12, 140, ALTO_CARA - labio - 26, "none", trazo=z["oro"], ancho=1.6,
                   extra='opacity="0.6"')
    if v >= 1:
        _grieta(L, azar, azar.uniform(60, 200), labio + 20, 30, z["maldito"], 2.0, 0.7)


# --- Lo que va en cada zona ------------------------------------------------------
# Cada pieza: (archivo, funcion, (ancho, alto), argumentos). Las de las familias
# grandes (rocas, bloques, grupos, plataformas) llevan su _v, con la misma
# funcion en la caja con los lados cambiados.

def _g(*piezas):
    return {"piezas": [(funcion, extra) for funcion, extra in piezas]}


def piezas_de(nombre, p):
    if nombre == "calabozos":
        props = {
            "barril": (P.barril, (120, 136), {}),
            "caja": (P.caja, (132, 128), {}),
            "sacos": (P.sacos, (164, 120), {}),
            "jaula": (P.jaula, (128, 150), {}),
            "grilletes": (P.bloque_piedra, (142, 124), {"grilletes": True}),
            "tonel": (P.tonel, (172, 116), {}),
            "cajas": (P.grupo, (184, 140), _g((P.caja, {}), (P.caja, {"rota": True}))),
            "barriles": (P.grupo, (196, 134), _g((P.barril, {}), (P.barril, {}), (P.barril, {}))),
            "sacos_caja": (P.grupo, (188, 134), _g((P.sacos, {}), (P.caja, {}))),
            "tonel_barril": (P.grupo, (196, 132), _g((P.tonel, {}), (P.barril, {}))),
            "mesa": (P.mesa, (480, 200), {}),
            "camastro": (P.camastro, (470, 190), {}),
            "banco": (P.mesa, (500, 168), {}),
        }
        familias = {"rocas": ["barril", "caja", "sacos", "jaula", "grilletes", "tonel"],
                    "bloques": ["jaula", "grilletes", "caja", "barril"],
                    "grupos": ["cajas", "barriles", "sacos_caja", "tonel_barril"],
                    "plataformas": ["mesa", "camastro", "banco"]}
        vegetacion = [("vela", P.vela_suelta, (40, 64), {}), ("botella", P.botella, (34, 64), {}),
                      ("jarra", P.jarra, (48, 52), {}), ("calavera", P.calavera_suelta, (52, 52), {})]
        piedras = [("guijarros", P.guijarros, (48, 32), {}), ("paja", P.astillas, (48, 32), {"color": p["paja"]}),
                   ("hueso", P.hueso_suelto, (48, 32), {}), ("eslabon", P.eslabon, (48, 32), {}),
                   ("astillas", P.astillas, (48, 32), {})]
        adornos = [("paja", P.matojo, (44, 30), {}), ("escombro", P.guijarros, (44, 30), {}),
                   ("vela", P.vela_suelta, (26, 42), {}), ("calavera", P.calavera_suelta, (30, 30), {})]
        colgantes = [("grillete", P.colgante_grillete, (26, 60), {}), ("antorcha", P.colgante_antorcha, (34, 64), {}),
                     ("raices", P.colgante_raices, (36, 40), {})]
    elif nombre == "cloacas":
        props = {
            "barril": (P.barril, (120, 136), {"oxido": True}),
            "caja": (P.caja, (132, 124), {"rota": True}),
            "escombros": (P.escombros, (164, 112), {}),
            "tuberia": (P.tuberia, (168, 124), {}),
            "setas": (P.setas, (144, 132), {}),
            "rejilla": (P.bloque_piedra, (142, 124), {"rejilla": True}),
            "escombros_barril": (P.grupo, (196, 132), _g((P.escombros, {}), (P.barril, {"oxido": True}))),
            "tuberias": (P.grupo, (196, 132), _g((P.tuberia, {}), (P.tuberia, {}))),
            "cajas": (P.grupo, (184, 136), _g((P.caja, {"rota": True}), (P.caja, {}))),
            "setas_escombros": (P.grupo, (190, 132), _g((P.setas, {}), (P.escombros, {}))),
            "losa": (P.losa, (480, 190), {"musgo": 0.8}),
            "desague": (P.losa, (480, 180), {"rejilla": True, "musgo": 0.4}),
            "tablas": (P.mesa, (470, 168), {}),
        }
        familias = {"rocas": ["barril", "caja", "escombros", "tuberia", "setas", "rejilla"],
                    "bloques": ["rejilla", "tuberia", "barril", "caja"],
                    "grupos": ["escombros_barril", "tuberias", "cajas", "setas_escombros"],
                    "plataformas": ["losa", "desague", "tablas"]}
        vegetacion = [("setas", P.setas_pequenas, (52, 52), {}), ("musgo", P.matojo, (50, 40), {"color": p["musgo"]}),
                      ("setas_luz", P.setas_pequenas, (52, 52), {"brillo": "#c8f05a"}),
                      ("botella", P.botella, (34, 64), {"color": "#4a6a3a"})]
        piedras = [("guijarros", P.guijarros, (48, 32), {}), ("charco", P.charco, (52, 34), {}),
                   ("algas", P.matojo, (48, 32), {"color": p["limo"]}), ("hueso", P.hueso_suelto, (48, 32), {}),
                   ("eslabon", P.eslabon, (48, 32), {})]
        adornos = [("setas", P.setas_pequenas, (40, 36), {}), ("musgo", P.matojo, (44, 30), {"color": p["musgo"]}),
                   ("setas_luz", P.setas_pequenas, (40, 36), {"brillo": "#c8f05a"}),
                   ("escombro", P.guijarros, (44, 30), {})]
        colgantes = [("limo", P.colgante_limo, (34, 64), {}), ("algas", P.colgante_raices, (36, 46), {"color": p["limo"]}),
                     ("farol", P.colgante_farol, (32, 60), {"fuego": p["fuego"]}),
                     ("grillete", P.colgante_grillete, (26, 56), {})]
    elif nombre == "cripta":
        props = {
            "lapida": (P.lapida, (116, 136), {}),
            "cruz": (P.lapida, (116, 148), {"cruz": True}),
            "urna": (P.urna, (110, 136), {}),
            "huesos": (P.monton_huesos, (160, 116), {}),
            "sarcofago": (P.sarcofago, (180, 124), {}),
            "candelabro": (P.candelabro, (116, 146), {"fuego": p["fuego"]}),
            "lapidas": (P.grupo, (190, 140), _g((P.lapida, {}), (P.lapida, {"cruz": True}))),
            "urnas": (P.grupo, (186, 140), _g((P.urna, {}), (P.urna, {}), (P.urna, {}))),
            "huesos_urna": (P.grupo, (196, 134), _g((P.monton_huesos, {}), (P.urna, {}))),
            "sarcofago_vela": (P.grupo, (204, 136), _g((P.sarcofago, {}), (P.candelabro, {"fuego": p["fuego"]}))),
            "altar": (P.losa, (470, 190), {"grabado": "#9a7ad0"}),
            "osario": (P.losa, (480, 180), {"musgo": 0.3}),
            "ofrendas": (P.mesa, (470, 176), {"mantel": p["tela"]}),
        }
        familias = {"rocas": ["lapida", "cruz", "urna", "huesos", "sarcofago", "candelabro"],
                    "bloques": ["sarcofago", "lapida", "urna", "cruz"],
                    "grupos": ["lapidas", "urnas", "huesos_urna", "sarcofago_vela"],
                    "plataformas": ["altar", "osario", "ofrendas"]}
        vegetacion = [("vela", P.vela_suelta, (40, 64), {"fuego": p["fuego"]}), ("calavera", P.calavera_suelta, (52, 52), {}),
                      ("caliz", P.copa, (44, 56), {"metal": "#b8b8c8"}), ("hueso", P.hueso_suelto, (56, 40), {})]
        piedras = [("hueso", P.hueso_suelto, (48, 32), {}), ("cera", P.cera, (44, 32), {}),
                   ("guijarros", P.guijarros, (48, 32), {}), ("eslabon", P.eslabon, (48, 32), {}),
                   ("polvo", P.guijarros, (44, 30), {"color": p["hueso"]})]
        adornos = [("vela", P.vela_suelta, (26, 42), {"fuego": p["fuego"]}), ("calavera", P.calavera_suelta, (30, 30), {}),
                   ("urna", P.urna, (28, 40), {}), ("hueso", P.hueso_suelto, (40, 28), {})]
        colgantes = [("telarana", P.colgante_telarana, (40, 52), {}),
                     ("farol", P.colgante_farol, (32, 60), {"fuego": p["fuego"]}),
                     ("cadena", P.colgante_grillete, (26, 60), {}), ("raices", P.colgante_raices, (36, 44), {})]
    else:
        props = {
            "columna": (P.columna, (116, 150), {"oro": p["oro"]}),
            "columna_rota": (P.columna, (124, 132), {"rota": True}),
            "estatua": (P.estatua, (124, 150), {}),
            "armadura": (P.armadura, (116, 148), {}),
            "brasero": (P.brasero, (124, 132), {}),
            "pedestal": (P.pedestal, (112, 144), {}),
            "columnas": (P.grupo, (196, 140), _g((P.columna, {"rota": True}), (P.columna, {"rota": True}))),
            "braseros": (P.grupo, (190, 134), _g((P.brasero, {}), (P.pedestal, {}))),
            "guardia": (P.grupo, (196, 146), _g((P.armadura, {}), (P.estatua, {}))),
            "jarrones": (P.grupo, (186, 140), _g((P.pedestal, {}), (P.urna, {"color": p["oro"], "adorno": p["tela"]}))),
            "banquete": (P.mesa, (480, 200), {"mantel": p["tela"], "oro": p["oro"]}),
            "tarima": (P.tarima, (480, 180), {}),
            "sitial": (P.mesa, (470, 168), {"mantel": "#5a2a7a", "oro": p["oro"]}),
        }
        # Columnas primero y dos veces: de aqui salen tambien los cuatro pilares de
        # la sala del jefe (Piso._pilares_jefe), y en un salon del trono lo que mas
        # hay son columnas.
        familias = {"rocas": ["columna", "columna_rota", "estatua", "armadura", "brasero", "pedestal"],
                    "bloques": ["columna", "columna_rota", "columna", "columna_rota", "estatua", "armadura",
                                "brasero", "pedestal"],
                    "grupos": ["columnas", "braseros", "guardia", "jarrones"],
                    "plataformas": ["banquete", "tarima", "sitial"]}
        vegetacion = [("copa", P.copa, (44, 56), {}), ("candelabro", P.candelabro, (60, 72), {}),
                      ("monedas", P.monedas, (56, 40), {}), ("corona", P.corona, (52, 40), {})]
        piedras = [("monedas", P.monedas, (48, 32), {}), ("petalos", P.petalos, (48, 32), {}),
                   ("cristal", P.cristal, (36, 40), {}), ("gema", P.gema, (34, 38), {}),
                   ("guijarros", P.guijarros, (48, 32), {})]
        adornos = [("candelabro", P.candelabro, (40, 52), {}), ("cristal", P.cristal, (34, 44), {}),
                   ("copa", P.copa, (28, 38), {}), ("vela", P.vela_suelta, (26, 42), {})]
        colgantes = [("estandarte", P.colgante_estandarte, (40, 66), {"tela": p["tela"], "emblema": "corona"}),
                     ("estandarte_morado", P.colgante_estandarte, (36, 60), {"tela": "#5a2a7a"}),
                     ("antorcha", P.colgante_antorcha, (34, 64), {"hierro": p["oro"]})]
    return props, familias, vegetacion, piedras, adornos, colgantes


# --- Pintar y medir --------------------------------------------------------------------

def pintar(funcion, w, h, p, extra):
    L = Lienzo(w, h)
    funcion(L, 0, 0, w, h, p, **extra)
    return L.imagen()


def luz_media(imagen):
    """Luminosidad media (0-1) de lo opaco de una pieza."""
    alfa = imagen.getchannel("A").point(lambda a: 255 if a > 200 else 0)
    return ImageStat.Stat(imagen.convert("RGB").convert("L"), mask=alfa).mean[0] / 255.0


def calibrar(imagen, suelo):
    """Si la pieza se funde con el suelo (su luz entre 0,45 y 1,6 veces la del
    suelo), la aclara (u oscurece) entera hasta salir de ahi. Devuelve la imagen y
    la relacion final."""
    relacion = luz_media(imagen) / suelo
    if 0.45 < relacion < 1.6:
        objetivo = 1.75 if relacion >= 0.85 else 0.42
        factor = objetivo / relacion
        rgb_ = imagen.convert("RGB").point(lambda v: int(max(0, min(255, v * factor))))
        rgb_.putalpha(imagen.getchannel("A"))
        imagen = rgb_
        relacion = luz_media(imagen) / suelo
    return imagen, relacion


def color_godot(c, alfa=1.0):
    if isinstance(c, tuple):
        r, g, b = c
    else:
        r, g, b = [v / 255.0 for v in rgb(c)]
    return "Color(%.3f, %.3f, %.3f, %.3f)" % (r, g, b, alfa)


def guardar(imagen, ruta):
    os.makedirs(os.path.dirname(ruta), exist_ok=True)
    imagen.save(ruta)


def escribir_tres(ruta, clase, script, campos, texturas):
    """Un .tres con sus texturas como ext_resource. 'campos' es una lista de
    (nombre, valor) donde el valor puede llevar {N} = ExtResource de la textura N."""
    lineas = ['[gd_resource type="Resource" script_class="%s" load_steps=%d format=3]' % (clase, len(texturas) + 2), "",
              '[ext_resource type="Script" path="%s" id="1_script"]' % script]
    for i, t in enumerate(texturas):
        lineas.append('[ext_resource type="Texture2D" path="%s" id="%d_t"]' % (t, i + 2))
    lineas += ["", "[resource]", 'script = ExtResource("1_script")']
    for nombre, valor in campos:
        lineas.append("%s = %s" % (nombre, valor))
    with open(ruta, "w", encoding="utf-8", newline="\n") as archivo:
        archivo.write("\n".join(lineas) + "\n")


def lista(texturas, rutas):
    return "Array[Texture2D]([%s])" % ", ".join('ExtResource("%d_t")' % (texturas.index(r) + 2) for r in rutas)


# --- Todo -------------------------------------------------------------------------------

def generar_zona(nombre, z):
    print("==", nombre)
    carpeta = os.path.join(SALIDA, nombre)
    # Los suelos de sus pisos, primero: las piezas se miden contra ellos.
    suelos = {}
    for numero in z["pisos"]:
        variante = PISOS[numero][1]
        suelos[numero] = SUELOS[nombre](z, variante)
    luz_suelo = sum(luz_media(s) for s in suelos.values()) / len(suelos)
    print("   luz del suelo %.3f" % luz_suelo)

    props, familias, vegetacion, piedras, adornos, colgantes = piezas_de(nombre, z)
    rutas = {}
    usados = set(sum(familias.values(), []))
    for clave in sorted(usados):
        funcion, (w, h), extra = props[clave]
        for vertical in (False, True):
            ancho, alto = (h, w) if vertical else (w, h)
            imagen, relacion = calibrar(pintar(funcion, ancho, alto, z, extra), luz_suelo)
            archivo = "%s%s.png" % (clave, "_v" if vertical else "")
            guardar(imagen, os.path.join(carpeta, archivo))
            rutas[(clave, vertical)] = "%s/%s/%s" % (RES, nombre, archivo)
            if not vertical:
                print("   %-18s %3dx%-3d  luz %.2f del suelo" % (clave, w, h, relacion))
    sueltas = {}
    for grupo_, lista_ in (("vegetacion", vegetacion), ("piedra", piedras), ("adorno", adornos),
                           ("colgante", colgantes)):
        sueltas[grupo_] = []
        for clave, funcion, (w, h), extra in lista_:
            archivo = "%s_%s.png" % (grupo_, clave)
            guardar(pintar(funcion, w, h, z, extra), os.path.join(carpeta, archivo))
            sueltas[grupo_].append("%s/%s/%s" % (RES, nombre, archivo))
    L = Lienzo(52, 108)
    P.pilar(L, 0, 0, 52, 108, z, nombre)
    guardar(L.imagen(), os.path.join(carpeta, "pilar.png"))
    for tapada in (False, True):
        L = Lienzo(128, 128)
        P.bajada(L, z, nombre, tapada)
        guardar(L.imagen(), os.path.join(carpeta, "bajada%s.png" % ("_tapada" if tapada else "")))

    # El catalogo de la zona.
    texturas = []
    def apuntar(r):
        if r not in texturas:
            texturas.append(r)
        return r
    campos = []
    for campo, claves in (("rocas", familias["rocas"]), ("bloques", familias["bloques"]),
                          ("grupos", familias["grupos"]), ("plataformas", familias["plataformas"])):
        normales = [apuntar(rutas[(c, False)]) for c in claves]
        verticales = [apuntar(rutas[(c, True)]) for c in claves]
        campos.append((campo, normales))
        campos.append((campo + "_vertical", verticales))
    piedras_r = [apuntar(r) for r in sueltas["piedra"]]
    vegetacion_r = [apuntar(r) for r in sueltas["vegetacion"]]
    salida = [("piedras", lista(texturas, piedras_r))]
    for campo, rs in campos:
        salida.append((campo, lista(texturas, rs)))
    salida += [("vegetacion", lista(texturas, vegetacion_r)), ("colores_propios", "true")]
    escribir_tres(os.path.join(carpeta, "catalogo.tres"), "CatalogoObstaculos", "res://scripts/catalogo_obstaculos.gd",
                  salida, texturas)

    # Cada piso: su suelo, su muro, su cara y su estilo.
    for numero, suelo in suelos.items():
        variante = PISOS[numero][1]
        cpiso = os.path.join(SALIDA, "piso_%02d" % numero)
        guardar(suelo, os.path.join(cpiso, "suelo.png"))
        guardar(muro(nombre, z, variante), os.path.join(cpiso, "muro.png"))
        guardar(cara(nombre, z, variante), os.path.join(cpiso, "cara.png"))
        base = "%s/piso_%02d" % (RES, numero)
        texturas = ["%s/muro.png" % base, "%s/cara.png" % base, "%s/%s/pilar.png" % (RES, nombre),
                    "%s/suelo.png" % base, "%s/%s/bajada.png" % (RES, nombre), "%s/%s/bajada_tapada.png" % (RES, nombre)]
        texturas += sueltas["adorno"] + sueltas["colgante"]
        media = ImageStat.Stat(suelo.convert("RGB")).mean
        campos = [
            ("muro", 'ExtResource("2_t")'), ("cara", 'ExtResource("3_t")'), ("pilar", 'ExtResource("4_t")'),
            ("adornos", lista(texturas, sueltas["adorno"])), ("colgantes", lista(texturas, sueltas["colgante"])),
            ("salientes", "Array[Texture2D]([])"),
            ("color_luz", color_godot(z["luz"])), ("color_sombra", color_godot(z["sombra"])),
            ("suelo", 'ExtResource("5_t")'),
            ("color_suelo", color_godot(tuple(v / 255.0 for v in media))),
            ("color_detalle", color_godot(aclarar(z["cara"], 0.25))),
            ("bajada", 'ExtResource("6_t")'), ("bajada_tapada", 'ExtResource("7_t")'),
            ("tinte_peligros", color_godot(z["tinte"])),
            ("recta", "true"), ("alto_cara", "%.1f" % ALTO_CARA), ("entrada", "22.0"), ("ondulacion", "0.0"),
            ("adornos_cada", "90.0"), ("colgantes_cada", "130.0"), ("salientes_por_sala", "0"),
        ]
        escribir_tres(os.path.join(cpiso, "estilo_borde.tres"), "EstiloBorde", "res://scripts/estilo_borde.gd",
                      campos, texturas)


def main():
    import shutil
    if shutil.which("rsvg-convert") is None:
        sys.exit("Falta rsvg-convert (paquete librsvg2-bin)")
    zonas = sys.argv[1:] or list(ZONAS)
    for nombre in zonas:
        generar_zona(nombre, ZONAS[nombre])
    print("Listo:", os.path.relpath(SALIDA, RAIZ))


if __name__ == "__main__":
    main()
