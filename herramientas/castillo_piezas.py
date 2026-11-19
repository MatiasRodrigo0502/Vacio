# -*- coding: utf-8 -*-
"""Las piezas del castillo maldito (generar_castillo.py): lo que estorba en las
salas (barriles, cajas, jaulas, lapidas, sarcofagos, columnas, estatuas...), las
mesas y losas, lo pequeno del suelo y de encima de las mesas, lo de la pared
(pilares de las puertas, lo que crece encima y lo que cuelga de su cara) y la
bajada al piso de abajo.

Todas con vista 3/4, como los magos: se ve la parte de arriba y la de delante,
con la luz desde arriba, contorno casi negro y volumen con degradados.

CADA PIEZA SE DIBUJA EN LA CAJA QUE LE DEN (x, y, w, h), y si la caja es mas
alta que ancha, las largas se ponen a lo hondo (una mesa vista a lo largo, un
tonel tumbado de cara). Asi la de vertical (_v, el movil de pie: la misma caja
del mundo con los lados cambiados, ver Obstaculo) sale de la misma funcion.
'p' son los colores de la zona (generar_castillo.ZONAS).
"""
import math
import random

from castillo_svg import (CONTORNO, aclarar, antorcha, cadena, calavera, destello, f, hueso, llama,
                          mezclar, oscurecer, piedra_irregular, poligono, redondeado, sombra_suelo, vela)

T = 4.5  # el contorno de las piezas grandes, en pixeles de su textura


def _vert(c):
    """Degradado de arriba (claro) a abajo (oscuro)."""
    return [(0, aclarar(c, 0.18)), (1, oscurecer(c, 0.18))]


def _cilindro(c):
    """De lado a lado, como un cilindro con la luz arriba a la izquierda."""
    return [(0, oscurecer(c, 0.35)), (0.35, aclarar(c, 0.22)), (0.7, c), (1, oscurecer(c, 0.45))]


def caja34(L, x0, y0, x1, y1, tapa, c_arriba, c_frente, t=T):
    """Un bloque visto en 3/4: la tapa (arriba, 'tapa' de alto) y el frente."""
    L.rect(x0, y0 + tapa, x1 - x0, y1 - y0 - tapa, L.lineal(_vert(c_frente)), trazo=None)
    L.rect(x0, y0, x1 - x0, tapa, L.lineal([(0, aclarar(c_arriba, 0.12)), (1, c_arriba)]), trazo=None)
    L.linea("M %s %s L %s %s" % (f(x0), f(y0 + tapa), f(x1), f(y0 + tapa)), CONTORNO, t * 0.6)
    L.linea("M %s %s L %s %s" % (f(x0 + 3), f(y0 + 3), f(x1 - 3), f(y0 + 3)), aclarar(c_arriba, 0.4), 2.0, 0.6)
    L.rect(x0, y0, x1 - x0, y1 - y0, "none", ancho=t, r=3)


# --- Obstaculos ------------------------------------------------------------------

def barril(L, x, y, w, h, p, oxido=False):
    cx, base = x + w / 2, y + h - 8
    sombra_suelo(L, cx, base, w * 0.47, h * 0.08)
    rx = w * 0.38
    ry = min(h * 0.12, rx * 0.42)
    top = y + 6 + ry
    abajo = base - ry * 0.5
    madera = p["madera"]

    def ancho_en(s):
        return rx * (1 + 0.14 * math.sin(math.pi * s))

    cuerpo = ("M %s %s C %s %s %s %s %s %s A %s %s 0 0 0 %s %s C %s %s %s %s %s %s Z" % (
        f(cx - rx), f(top), f(cx - rx * 1.2), f(top + (abajo - top) * 0.33), f(cx - rx * 1.2),
        f(top + (abajo - top) * 0.7), f(cx - rx), f(abajo), f(rx), f(ry), f(cx + rx), f(abajo),
        f(cx + rx * 1.2), f(top + (abajo - top) * 0.7), f(cx + rx * 1.2), f(top + (abajo - top) * 0.33),
        f(cx + rx), f(top)))
    L.forma(cuerpo, L.lineal(_cilindro(madera), 0, 0, 1, 0), ancho=T)
    for k in (-0.55, -0.15, 0.25, 0.62):
        L.linea("M %s %s Q %s %s %s %s" % (f(cx + k * rx), f(top + ry * 0.9), f(cx + k * rx * 1.2),
                                           f((top + abajo) / 2), f(cx + k * rx), f(abajo + ry * 0.8)),
                oscurecer(madera, 0.45), 2.0, 0.8)
    hierro = p["hierro"]
    for s in (0.22, 0.78):
        yy = top + (abajo - top) * s
        a = ancho_en(s)
        d = "M %s %s A %s %s 0 0 0 %s %s" % (f(cx - a), f(yy), f(a), f(ry), f(cx + a), f(yy))
        L.linea(d, CONTORNO, 9.5)
        L.linea(d, hierro, 6.0)
        L.linea(d, aclarar(hierro, 0.45), 1.6, 0.8)
    L.elipse(cx, top, rx, ry, L.radial([(0, aclarar(madera, 0.35)), (1, oscurecer(madera, 0.1))], 0.45, 0.4, 0.7),
             ancho=T)
    L.elipse(cx, top, rx * 0.8, ry * 0.75, "none", trazo=oscurecer(madera, 0.4), ancho=2.0)
    for k in (-0.35, 0.0, 0.35):
        L.linea("M %s %s L %s %s" % (f(cx + k * rx - rx * 0.15), f(top - ry * 0.55), f(cx + k * rx + rx * 0.15),
                                     f(top + ry * 0.55)), oscurecer(madera, 0.3), 1.4, 0.6)
    if oxido:
        limo = p["limo"]
        L.forma("M %s %s q %s %s %s %s q %s %s %s %s q %s %s %s %s Z" % (
            f(cx - rx * 0.5), f(top + ry * 0.4), f(2), f(ry * 2.2), f(rx * 0.12), f(ry * 2.6),
            f(rx * 0.12), f(-ry * 0.2), f(rx * 0.14), f(-ry * 1.6), f(rx * 0.25), f(ry * 2.6), f(rx * 0.3), f(-ry * 1.2)),
            limo, ancho=2.5)
        L.elipse(cx - rx * 0.1, top, rx * 0.55, ry * 0.5, limo, ancho=2.2)
        L.elipse(cx - rx * 0.2, top - ry * 0.15, rx * 0.2, ry * 0.15, aclarar(limo, 0.5), trazo=None)


def caja(L, x, y, w, h, p, rota=False):
    cx, base = x + w / 2, y + h - 8
    sombra_suelo(L, cx, base, w * 0.5, h * 0.07)
    x0, x1, y0 = x + 6, x + w - 6, y + 6
    tapa = (base - y0) * 0.34
    madera = p["madera"]
    caja34(L, x0, y0, x1, base, tapa, aclarar(madera, 0.1), oscurecer(madera, 0.08))
    for k in (1, 2):
        yy = y0 + tapa * k / 3
        L.linea("M %s %s L %s %s" % (f(x0 + 3), f(yy), f(x1 - 3), f(yy)), oscurecer(madera, 0.45), 2.0)
    marco = 9
    fy0, fy1 = y0 + tapa, base
    L.rect(x0 + marco, fy0 + marco, x1 - x0 - marco * 2, fy1 - fy0 - marco * 2, "none",
           trazo=oscurecer(madera, 0.5), ancho=2.5)
    L.forma(poligono([(x0 + marco, fy1 - marco - 6), (x0 + marco + 8, fy1 - marco),
                      (x1 - marco, fy0 + marco + 6), (x1 - marco - 8, fy0 + marco)]),
            L.lineal(_vert(aclarar(madera, 0.08))), trazo=oscurecer(madera, 0.55), ancho=2.0)
    for xx in (x0 + 4, x1 - 4):
        for yy in (fy0 + 5, fy1 - 5):
            L.elipse(xx, yy, 2.4, 2.4, p["hierro"], ancho=1.2)
    if rota:
        L.forma(poligono([(x0 + 14, y0 + 4), (x0 + 46, y0 + 4), (x0 + 40, y0 + tapa * 0.6), (x0 + 30, y0 + tapa * 0.4),
                          (x0 + 20, y0 + tapa * 0.66)]), "#0d0b08", ancho=2.0)


def saco(L, cx, base, w, h, p):
    tela = p["tela"]
    cuerpo = ("M %s %s C %s %s %s %s %s %s L %s %s C %s %s %s %s %s %s C %s %s %s %s %s %s Z" % (
        f(cx - w * 0.47), f(base - h * 0.08), f(cx - w * 0.55), f(base - h * 0.55), f(cx - w * 0.28),
        f(base - h * 0.78), f(cx - w * 0.12), f(base - h * 0.8), f(cx + w * 0.12), f(base - h * 0.8),
        f(cx + w * 0.28), f(base - h * 0.78), f(cx + w * 0.55), f(base - h * 0.55), f(cx + w * 0.47),
        f(base - h * 0.08), f(cx + w * 0.3), f(base + h * 0.04), f(cx - w * 0.3), f(base + h * 0.04),
        f(cx - w * 0.47), f(base - h * 0.08)))
    L.forma(cuerpo, L.radial([(0, aclarar(tela, 0.25)), (0.7, tela), (1, oscurecer(tela, 0.3))], 0.4, 0.35, 0.75),
            ancho=T * 0.85)
    L.forma("M %s %s L %s %s L %s %s L %s %s Z" % (f(cx - w * 0.12), f(base - h * 0.8), f(cx - w * 0.17),
                                                f(base - h), f(cx + w * 0.17), f(base - h), f(cx + w * 0.12),
                                                f(base - h * 0.8)),
            aclarar(tela, 0.1), ancho=T * 0.7)
    L.linea("M %s %s L %s %s" % (f(cx - w * 0.14), f(base - h * 0.82), f(cx + w * 0.14), f(base - h * 0.82)),
            oscurecer(p["madera"], 0.2), 4.0)
    L.linea("M %s %s q %s %s %s %s" % (f(cx - w * 0.2), f(base - h * 0.5), f(w * 0.1), f(h * 0.1), f(w * 0.25),
                                       f(h * 0.05)), oscurecer(tela, 0.35), 1.8, 0.8)


def sacos(L, x, y, w, h, p):
    sombra_suelo(L, x + w / 2, y + h - 8, w * 0.5, h * 0.08)
    if w >= h:
        saco(L, x + w * 0.5, y + h * 0.66, w * 0.42, h * 0.62, p)
        saco(L, x + w * 0.27, y + h - 10, w * 0.46, h * 0.64, p)
        saco(L, x + w * 0.73, y + h - 10, w * 0.46, h * 0.62, p)
    else:
        saco(L, x + w * 0.5, y + h * 0.5, w * 0.78, h * 0.42, p)
        saco(L, x + w * 0.5, y + h - 10, w * 0.86, h * 0.46, p)


def jaula(L, x, y, w, h, p):
    cx, base = x + w / 2, y + h - 10
    sombra_suelo(L, cx, base, w * 0.48, h * 0.08)
    rx = w * 0.42
    ry = rx * 0.32
    arriba = y + h * 0.3
    hierro = p["hierro"]
    L.elipse(cx, base, rx, ry, oscurecer(hierro, 0.45), ancho=T)
    calavera(L, cx - rx * 0.15, base - ry * 0.6, rx * 0.26, p["hueso"])
    hueso(L, cx + rx * 0.05, base - ry * 0.1, cx + rx * 0.6, base - ry * 0.5, 5, p["hueso"])
    barras = 9
    for fila in ("detras", "delante"):
        for k in range(barras):
            a = math.pi * k / (barras - 1)
            delante = fila == "delante"
            ang = a if delante else a + math.pi
            xx = cx + math.cos(ang) * rx
            dy = math.sin(ang) * ry
            ancho = 4.5 if delante else 3.0
            color = hierro if delante else oscurecer(hierro, 0.35)
            if delante:
                L.linea("M %s %s L %s %s" % (f(xx), f(arriba + dy), f(xx), f(base + dy)), CONTORNO, ancho + 3)
            L.linea("M %s %s L %s %s" % (f(xx), f(arriba + dy), f(xx), f(base + dy)), color, ancho)
        if fila == "detras":
            d = "M %s %s A %s %s 0 0 1 %s %s" % (f(cx - rx), f(arriba), f(rx), f(ry), f(cx + rx), f(arriba))
            L.linea(d, oscurecer(hierro, 0.3), 4.0)
    d = "M %s %s A %s %s 0 0 0 %s %s" % (f(cx - rx), f(arriba), f(rx), f(ry), f(cx + rx), f(arriba))
    L.linea(d, CONTORNO, 9)
    L.linea(d, hierro, 5.5)
    domo = "M %s %s Q %s %s %s %s Q %s %s %s %s" % (f(cx - rx), f(arriba), f(cx - rx * 0.9), f(y + 6),
                                                    f(cx), f(y + 8), f(cx + rx * 0.9), f(y + 6), f(cx + rx), f(arriba))
    L.linea(domo, CONTORNO, 8)
    L.linea(domo, hierro, 4.5)
    L.linea("M %s %s Q %s %s %s %s" % (f(cx), f(y + 8), f(cx), f(arriba - 6), f(cx), f(arriba + ry)), CONTORNO, 7)
    L.linea("M %s %s Q %s %s %s %s" % (f(cx), f(y + 8), f(cx), f(arriba - 6), f(cx), f(arriba + ry)), hierro, 3.5)
    L.elipse(cx, y + 8, 6, 5, "none", trazo=CONTORNO, ancho=5)
    L.elipse(cx, y + 8, 6, 5, "none", trazo=aclarar(hierro, 0.3), ancho=2.5)
    d = "M %s %s A %s %s 0 0 0 %s %s" % (f(cx - rx), f(base), f(rx), f(ry), f(cx + rx), f(base))
    L.linea(d, CONTORNO, 9)
    L.linea(d, hierro, 5.5)


def bloque_piedra(L, x, y, w, h, p, grilletes=False, rejilla=False):
    cx, base = x + w / 2, y + h - 8
    sombra_suelo(L, cx, base, w * 0.5, h * 0.07)
    x0, x1, y0 = x + 6, x + w - 6, y + 6
    tapa = (base - y0) * 0.36
    piedra = p["piedra"]
    caja34(L, x0, y0, x1, base, tapa, aclarar(piedra, 0.06), oscurecer(piedra, 0.18))
    azar = random.Random("bloque%d%d" % (w, h))
    fy = y0 + tapa
    mitad = (fy + base) / 2
    L.linea("M %s %s L %s %s" % (f(x0 + 3), f(mitad), f(x1 - 3), f(mitad)), oscurecer(piedra, 0.5), 2.0)
    for k in range(3):
        xx = x0 + (x1 - x0) * (0.25 + k * 0.28) + azar.uniform(-6, 6)
        y_a, y_b = (fy, mitad) if k % 2 == 0 else (mitad, base)
        L.linea("M %s %s L %s %s" % (f(xx), f(y_a + 2), f(xx), f(y_b - 2)), oscurecer(piedra, 0.5), 2.0)
    for _ in range(2):
        xx, yy = azar.uniform(x0 + 15, x1 - 15), azar.uniform(y0 + 6, y0 + tapa - 6)
        L.linea("M %s %s l %s %s l %s %s" % (f(xx), f(yy), f(azar.uniform(-12, 12)), f(4), f(azar.uniform(-10, 10)),
                                             f(-3)), oscurecer(piedra, 0.5), 1.6, 0.8)
    if grilletes:
        hierro = p["hierro"]
        L.elipse(cx, fy + 14, 8, 8, "none", trazo=CONTORNO, ancho=6)
        L.elipse(cx, fy + 14, 8, 8, "none", trazo=hierro, ancho=3)
        for s in (-1, 1):
            cadena(L, cx, fy + 20, cx + s * (x1 - x0) * 0.32, base - 10, 8, hierro, 2.4)
            L.elipse(cx + s * (x1 - x0) * 0.34, base - 6, 9, 6, "none", trazo=CONTORNO, ancho=6)
            L.elipse(cx + s * (x1 - x0) * 0.34, base - 6, 9, 6, "none", trazo=hierro, ancho=3)
    if rejilla:
        gx0, gx1 = x0 + 14, x1 - 14
        L.rect(gx0, fy + 10, gx1 - gx0, base - fy - 18, "#0a0d0b", ancho=3, r=2)
        n = 6
        for k in range(1, n):
            xx = gx0 + (gx1 - gx0) * k / n
            L.linea("M %s %s L %s %s" % (f(xx), f(fy + 11), f(xx), f(base - 9)), p["hierro"], 3.0)
        L.elipse(cx, base - 12, (gx1 - gx0) * 0.3, 4, p["limo"], trazo=None, extra='opacity="0.7"')


def tonel(L, x, y, w, h, p):
    """Un tonel tumbado: de lado si la caja es ancha, de cara si es alta."""
    madera, hierro = p["madera"], p["hierro"]
    cx, base = x + w / 2, y + h - 8
    sombra_suelo(L, cx, base, w * 0.48, h * 0.09)
    if w >= h:
        x0, x1 = x + 8, x + w - 8
        y0, y1 = y + 10, base - 2
        ry = (y1 - y0) / 2
        rx_tapa = ry * 0.45
        cy = (y0 + y1) / 2
        cuerpo = "M %s %s C %s %s %s %s %s %s L %s %s C %s %s %s %s %s %s Z" % (
            f(x0 + rx_tapa), f(y0), f(x0 + (x1 - x0) * 0.35), f(y0 - ry * 0.12), f(x0 + (x1 - x0) * 0.65),
            f(y0 - ry * 0.12), f(x1), f(y0 + ry * 0.04), f(x1), f(y1 - ry * 0.04), f(x0 + (x1 - x0) * 0.65),
            f(y1 + ry * 0.12), f(x0 + (x1 - x0) * 0.35), f(y1 + ry * 0.12), f(x0 + rx_tapa), f(y1))
        L.forma(cuerpo, L.lineal(_cilindro(madera), 0, 0, 0, 1), ancho=T)
        for s in (0.3, 0.6, 0.9):
            xx = x0 + rx_tapa + (x1 - x0 - rx_tapa) * s
            d = "M %s %s Q %s %s %s %s" % (f(xx), f(y0 - ry * 0.08), f(xx + 8), f(cy), f(xx), f(y1 + ry * 0.08))
            L.linea(d, CONTORNO, 9)
            L.linea(d, hierro, 5.5)
        L.elipse(x0 + rx_tapa, cy, rx_tapa, ry, L.radial([(0, aclarar(madera, 0.3)), (1, oscurecer(madera, 0.1))]),
                 ancho=T)
        L.elipse(x0 + rx_tapa, cy, rx_tapa * 0.75, ry * 0.8, "none", trazo=oscurecer(madera, 0.4), ancho=2)
        L.elipse(x0 + rx_tapa * 1.05, cy + ry * 0.35, rx_tapa * 0.18, ry * 0.12, oscurecer(madera, 0.6), ancho=1.5)
    else:
        rx = w * 0.42
        ry = rx * 0.95
        cy = base - ry * 0.95
        L.forma("M %s %s L %s %s L %s %s L %s %s Z" % (f(cx - rx * 0.92), f(cy), f(cx - rx * 0.85), f(y + 10),
                                                     f(cx + rx * 0.85), f(y + 10), f(cx + rx * 0.92), f(cy)),
                L.lineal(_cilindro(madera), 0, 0, 1, 0), ancho=T)
        for s in (0.3, 0.7):
            yy = y + 10 + (cy - y - 10) * s
            L.linea("M %s %s L %s %s" % (f(cx - rx * 0.9), f(yy), f(cx + rx * 0.9), f(yy)), CONTORNO, 9)
            L.linea("M %s %s L %s %s" % (f(cx - rx * 0.9), f(yy), f(cx + rx * 0.9), f(yy)), hierro, 5.5)
        L.elipse(cx, cy, rx, ry, L.radial([(0, aclarar(madera, 0.3)), (1, oscurecer(madera, 0.1))]), ancho=T)
        L.elipse(cx, cy, rx * 0.78, ry * 0.78, "none", trazo=oscurecer(madera, 0.4), ancho=2.0)
        L.elipse(cx, cy, rx, ry, "none", trazo=hierro, ancho=4.0)


def escombros(L, x, y, w, h, p, color=None):
    cx, base = x + w / 2, y + h - 8
    sombra_suelo(L, cx, base, w * 0.5, h * 0.1)
    color = color or p["piedra"]
    azar = random.Random("escombros%d%d" % (w, h))
    piezas = []
    for _ in range(9):
        piezas.append((azar.uniform(x + w * 0.18, x + w * 0.82), azar.uniform(y + h * 0.35, base - h * 0.12),
                       azar.uniform(w * 0.1, w * 0.2)))
    piezas.sort(key=lambda t: t[1])
    if w > 80:
        L.forma(poligono([(x + w * 0.15, base - h * 0.45), (x + w * 0.85, base - h * 0.62),
                          (x + w * 0.86, base - h * 0.52), (x + w * 0.16, base - h * 0.35)]),
                L.lineal(_vert(p["madera"])), ancho=T * 0.8)
    for px, py, r in piezas:
        c = mezclar(color, oscurecer(color, 0.3), azar.random())
        L.forma(piedra_irregular(azar, px, py, r, r * 0.75, 7, 0.2),
                L.radial([(0, aclarar(c, 0.25)), (0.8, c), (1, oscurecer(c, 0.3))], 0.35, 0.3, 0.8), ancho=T * 0.8)


def tuberia(L, x, y, w, h, p):
    """Un trozo de tuberia grande, con su llave y limo."""
    hierro = p["hierro"]
    cx, base = x + w / 2, y + h - 8
    sombra_suelo(L, cx, base, w * 0.5, h * 0.09)
    if w >= h:
        y0, y1 = y + h * 0.35, base - 4
        L.rect(x + 8, y0, w - 16, y1 - y0, L.lineal(_cilindro(hierro), 0, 0, 0, 1), ancho=T, r=6)
        for xx in (x + 26, x + w - 26):
            L.rect(xx - 9, y0 - 6, 18, y1 - y0 + 12, L.lineal(_cilindro(aclarar(hierro, 0.1)), 0, 0, 0, 1),
                   ancho=T * 0.8, r=3)
        L.elipse(x + 12, (y0 + y1) / 2, 8, (y1 - y0) * 0.45, "#0a0d0b", ancho=3)
        L.forma("M %s %s q %s %s %s %s q %s %s %s %s Z" % (f(x + 8), f((y0 + y1) / 2), f(-6), f(10), f(-2), f(26),
                                                         f(6), f(-6), f(8), f(-24)), p["limo"], ancho=2)
        cy = y0 - 2
    else:
        rx = w * 0.4
        cyb = base - rx * 0.6
        L.rect(cx - rx, y + 20, rx * 2, cyb - y - 20, L.lineal(_cilindro(hierro), 0, 0, 1, 0), ancho=T, r=4)
        L.elipse(cx, cyb, rx, rx * 0.6, oscurecer(hierro, 0.1), ancho=T)
        L.elipse(cx, cyb, rx * 0.72, rx * 0.42, "#0a0d0b", ancho=2.5)
        L.elipse(cx, cyb + rx * 0.15, rx * 0.5, rx * 0.18, p["limo"], trazo=None, extra='opacity="0.85"')
        cy = y + 22
    # La llave: una rueda encima.
    L.linea("M %s %s L %s %s" % (f(cx), f(cy), f(cx), f(cy - 16)), CONTORNO, 8)
    L.linea("M %s %s L %s %s" % (f(cx), f(cy), f(cx), f(cy - 16)), hierro, 4)
    L.elipse(cx, cy - 18, 16, 7, "none", trazo=CONTORNO, ancho=8)
    L.elipse(cx, cy - 18, 16, 7, "none", trazo="#9a3a2a", ancho=4.5)
    for k in range(4):
        a = k * math.pi / 4
        L.linea("M %s %s L %s %s" % (f(cx - math.cos(a) * 15), f(cy - 18 - math.sin(a) * 6),
                                     f(cx + math.cos(a) * 15), f(cy - 18 + math.sin(a) * 6)), "#9a3a2a", 2.4)


def setas(L, x, y, w, h, p, brillo="#7fe8c8"):
    """Setas grandes que brillan, como las del limo de las cloacas."""
    cx, base = x + w / 2, y + h - 8
    sombra_suelo(L, cx, base, w * 0.48, h * 0.08)
    azar = random.Random("setas%d%d" % (w, h))
    halo = L.difuso(8)
    L.elipse(cx, base - h * 0.4, w * 0.45, h * 0.35, brillo, trazo=None, extra='opacity="0.25" filter="%s"' % halo)
    piezas = [(cx - w * 0.22, base - 4, h * 0.55), (cx + w * 0.2, base - 2, h * 0.68), (cx, base + 2, h * 0.38),
              (cx + w * 0.36, base, h * 0.3), (cx - w * 0.38, base, h * 0.28)]
    piezas.sort(key=lambda t: t[1] - t[2] * 0.01)
    for sx, sb, alto in piezas:
        sombrero = alto * 0.55
        L.rect(sx - alto * 0.08, sb - alto * 0.85, alto * 0.16, alto * 0.85,
               L.lineal([(0, "#e8e2c8"), (1, "#a49c80")], 0, 0, 1, 0), ancho=T * 0.7, r=3)
        d = "M %s %s Q %s %s %s %s Q %s %s %s %s Z" % (
            f(sx - sombrero * 0.7), f(sb - alto * 0.78), f(sx - sombrero * 0.6), f(sb - alto * 1.12), f(sx),
            f(sb - alto * 1.12), f(sx + sombrero * 0.6), f(sb - alto * 1.12), f(sx + sombrero * 0.7), f(sb - alto * 0.78))
        L.forma(d, L.radial([(0, aclarar(brillo, 0.5)), (0.6, brillo), (1, oscurecer(brillo, 0.45))], 0.4, 0.3, 0.8),
                ancho=T * 0.7)
        for _ in range(3):
            L.elipse(sx + azar.uniform(-sombrero * 0.4, sombrero * 0.4), sb - alto * azar.uniform(0.9, 1.02),
                     2.2, 1.6, "#ffffff", trazo=None, extra='opacity="0.8"')


def lapida(L, x, y, w, h, p, cruz=False):
    cx, base = x + w / 2, y + h - 8
    sombra_suelo(L, cx, base, w * 0.5, h * 0.08)
    piedra = p["piedra"]
    L.forma(piedra_irregular(random.Random("tierra%d" % w), cx, base - 6, w * 0.44, h * 0.09, 9, 0.15),
            oscurecer(p["madera"], 0.3), ancho=T * 0.7)
    if cruz:
        brazo = h * 0.22
        L.forma(poligono([(cx - w * 0.12, base - 6), (cx - w * 0.12, y + h * 0.42), (cx - w * 0.4, y + h * 0.42),
                          (cx - w * 0.4, y + h * 0.42 - brazo), (cx - w * 0.12, y + h * 0.42 - brazo),
                          (cx - w * 0.12, y + 8), (cx + w * 0.12, y + 8), (cx + w * 0.12, y + h * 0.42 - brazo),
                          (cx + w * 0.4, y + h * 0.42 - brazo), (cx + w * 0.4, y + h * 0.42),
                          (cx + w * 0.12, y + h * 0.42), (cx + w * 0.12, base - 6)]),
                L.lineal(_cilindro(piedra), 0, 0, 1, 0), ancho=T)
        L.elipse(cx, y + h * 0.42 - brazo / 2, w * 0.07, brazo * 0.3, oscurecer(piedra, 0.3), trazo=None)
    else:
        x0, x1 = cx - w * 0.36, cx + w * 0.36
        top = y + 8
        d = "M %s %s L %s %s A %s %s 0 0 1 %s %s L %s %s Z" % (
            f(x0), f(base - 6), f(x0), f(top + w * 0.36), f(w * 0.36), f(w * 0.36), f(x1), f(top + w * 0.36),
            f(x1), f(base - 6))
        L.forma(d, L.lineal(_vert(piedra)), ancho=T)
        # El canto de arriba de la losa: es fina, se ve poco.
        L.linea("M %s %s A %s %s 0 0 1 %s %s" % (f(x0 + 6), f(top + w * 0.36), f(w * 0.3), f(w * 0.3),
                                                 f(x1 - 6), f(top + w * 0.36)), aclarar(piedra, 0.4), 2.5, 0.7)
        L.linea("M %s %s L %s %s M %s %s L %s %s" % (f(cx), f(top + h * 0.22), f(cx), f(top + h * 0.48),
                                                     f(cx - w * 0.12), f(top + h * 0.31), f(cx + w * 0.12),
                                                     f(top + h * 0.31)), oscurecer(piedra, 0.5), 3.5)
        for k in range(3):
            yy = top + h * (0.55 + k * 0.08)
            L.linea("M %s %s L %s %s" % (f(cx - w * 0.2), f(yy), f(cx + w * 0.2 - k * 6), f(yy)),
                    oscurecer(piedra, 0.45), 2.0, 0.8)
    L.forma(piedra_irregular(random.Random("musgo%d" % w), cx - w * 0.2, base - 10, w * 0.14, h * 0.05, 7, 0.3),
            p["musgo"], trazo=None, extra='opacity="0.8"')


def urna(L, x, y, w, h, p, color=None, adorno=None):
    """Una urna o un jarron grande, con su tapa."""
    color = color or p["piedra"]
    cx, base = x + w / 2, y + h - 8
    sombra_suelo(L, cx, base, w * 0.44, h * 0.08)
    r = w * 0.4
    d = ("M %s %s C %s %s %s %s %s %s C %s %s %s %s %s %s L %s %s C %s %s %s %s %s %s "
         "C %s %s %s %s %s %s Z" % (
             f(cx - r * 0.45), f(base - 2), f(cx - r * 1.15), f(base - h * 0.2), f(cx - r * 1.1), f(base - h * 0.6),
             f(cx - r * 0.42), f(y + h * 0.26), f(cx - r * 0.3), f(y + h * 0.22), f(cx - r * 0.45), f(y + h * 0.16),
             f(cx - r * 0.5), f(y + h * 0.13), f(cx + r * 0.5), f(y + h * 0.13), f(cx + r * 0.45), f(y + h * 0.16),
             f(cx + r * 0.3), f(y + h * 0.22), f(cx + r * 0.42), f(y + h * 0.26), f(cx + r * 1.1), f(base - h * 0.6),
             f(cx + r * 1.15), f(base - h * 0.2), f(cx + r * 0.45), f(base - 2)))
    L.forma(d, L.lineal(_cilindro(color), 0, 0, 1, 0), ancho=T)
    banda = adorno or oscurecer(color, 0.35)
    for s in (0.45, 0.62):
        yy = base - h * s
        L.linea("M %s %s Q %s %s %s %s" % (f(cx - r * 1.0), f(yy), f(cx), f(yy + 8), f(cx + r * 1.0), f(yy)),
                banda, 3.5, 0.9)
    L.elipse(cx, y + h * 0.13, r * 0.52, r * 0.16, L.lineal(_vert(aclarar(color, 0.15))), ancho=T * 0.8)
    L.elipse(cx, y + h * 0.08, r * 0.14, r * 0.12, aclarar(color, 0.2), ancho=T * 0.7)
    L.linea("M %s %s Q %s %s %s %s" % (f(cx - r * 0.65), f(base - h * 0.62), f(cx - r * 0.75), f(base - h * 0.4),
                                       f(cx - r * 0.55), f(base - h * 0.2)), aclarar(color, 0.55), 3.0, 0.55)


def monton_huesos(L, x, y, w, h, p):
    cx, base = x + w / 2, y + h - 8
    sombra_suelo(L, cx, base, w * 0.5, h * 0.1)
    azar = random.Random("huesos%d%d" % (w, h))
    for _ in range(7):
        x0 = azar.uniform(x + w * 0.12, x + w * 0.88)
        y0 = azar.uniform(y + h * 0.45, base - 6)
        a = azar.uniform(-0.9, 0.9)
        largo = azar.uniform(w * 0.25, w * 0.4)
        hueso(L, x0 - math.cos(a) * largo / 2, y0 - math.sin(a) * largo / 2, x0 + math.cos(a) * largo / 2,
              y0 + math.sin(a) * largo / 2, 7, p["hueso"])
    calavera(L, cx + w * 0.05, y + h * 0.45, min(w, h) * 0.17, p["hueso"])
    calavera(L, cx - w * 0.25, base - h * 0.2, min(w, h) * 0.12, oscurecer(p["hueso"], 0.08))


def sarcofago(L, x, y, w, h, p):
    piedra = p["piedra"]
    cx, base = x + w / 2, y + h - 8
    sombra_suelo(L, cx, base, w * 0.52, h * 0.08)
    x0, x1, y0 = x + 6, x + w - 6, y + 6
    if w >= h:
        tapa = (base - y0) * 0.55
    else:
        tapa = (base - y0) * 0.74
    caja34(L, x0, y0, x1, base, tapa, aclarar(piedra, 0.05), oscurecer(piedra, 0.2))
    # Relieve de la tapa: una espada.
    if w >= h:
        L.linea("M %s %s L %s %s" % (f(x0 + 22), f(y0 + tapa / 2), f(x1 - 40), f(y0 + tapa / 2)), oscurecer(piedra, 0.4), 6)
        L.linea("M %s %s L %s %s" % (f(x1 - 40), f(y0 + tapa * 0.2), f(x1 - 40), f(y0 + tapa * 0.8)),
                oscurecer(piedra, 0.4), 6)
        L.elipse(x1 - 26, y0 + tapa / 2, 6, 6, oscurecer(piedra, 0.4), trazo=None)
    else:
        L.linea("M %s %s L %s %s" % (f(cx), f(y0 + 16), f(cx), f(y0 + tapa - 30)), oscurecer(piedra, 0.4), 6)
        L.linea("M %s %s L %s %s" % (f(cx - 16), f(y0 + tapa - 30), f(cx + 16), f(y0 + tapa - 30)),
                oscurecer(piedra, 0.4), 6)
    for k in range(3):
        xx = x0 + (x1 - x0) * (k + 0.5) / 3
        L.rect(xx - (x1 - x0) / 7, y0 + tapa + 7, (x1 - x0) * 2 / 7, base - y0 - tapa - 14, "none",
               trazo=oscurecer(piedra, 0.45), ancho=2.0, r=2)


def candelabro(L, x, y, w, h, p, metal=None, fuego=None):
    """Un candelabro de pie con tres velas."""
    metal = metal or p["hierro"]
    cx, base = x + w / 2, y + h - 8
    sombra_suelo(L, cx, base, w * 0.4, h * 0.07)
    for s in (-1, 0, 1):
        L.linea("M %s %s L %s %s" % (f(cx), f(base - h * 0.18), f(cx + s * w * 0.3), f(base - 2)), CONTORNO, 8)
        L.linea("M %s %s L %s %s" % (f(cx), f(base - h * 0.18), f(cx + s * w * 0.3), f(base - 2)), metal, 4)
    L.linea("M %s %s L %s %s" % (f(cx), f(base - h * 0.18), f(cx), f(y + h * 0.42)), CONTORNO, 10)
    L.linea("M %s %s L %s %s" % (f(cx), f(base - h * 0.18), f(cx), f(y + h * 0.42)), metal, 5.5)
    brazos = "M %s %s Q %s %s %s %s M %s %s Q %s %s %s %s" % (
        f(cx), f(y + h * 0.5), f(cx - w * 0.32), f(y + h * 0.55), f(cx - w * 0.3), f(y + h * 0.36),
        f(cx), f(y + h * 0.5), f(cx + w * 0.32), f(y + h * 0.55), f(cx + w * 0.3), f(y + h * 0.36))
    L.linea(brazos, CONTORNO, 9)
    L.linea(brazos, metal, 4.5)
    for xx, yy in ((cx - w * 0.3, y + h * 0.36), (cx, y + h * 0.42), (cx + w * 0.3, y + h * 0.36)):
        L.elipse(xx, yy, 9, 3.5, metal, ancho=2.5)
        vela(L, xx, yy, h * 0.3, fuego=fuego)


def columna(L, x, y, w, h, p, rota=False, oro=None):
    piedra = p["piedra"]
    cx, base = x + w / 2, y + h - 8
    sombra_suelo(L, cx, base, w * 0.5, h * 0.08)
    x0, x1 = x + 6, x + w - 6
    zocalo = h * 0.2
    caja34(L, x0, base - zocalo, x1, base, zocalo * 0.4, aclarar(piedra, 0.05), oscurecer(piedra, 0.2))
    r = w * 0.3
    arriba = y + (h * 0.32 if rota else 26)
    if rota:
        azar = random.Random("rota%d" % w)
        mella = [(cx - r, arriba + 10)]
        for k in range(5):
            mella.append((cx - r + 2 * r * (k + 1) / 6, arriba + azar.uniform(-12, 12)))
        mella.append((cx + r, arriba + 4))
        cuerpo = [(cx + r, base - zocalo + 4), (cx - r, base - zocalo + 4)] + mella
        L.forma(poligono(cuerpo), L.lineal(_cilindro(piedra), 0, 0, 1, 0), ancho=T)
        L.forma(poligono(mella + [(cx + r * 0.6, arriba + 16), (cx - r * 0.6, arriba + 18)]),
                aclarar(piedra, 0.25), ancho=T * 0.6)
        escombros(L, x + w * 0.55, base - h * 0.28, w * 0.45, h * 0.3, p)
    else:
        L.rect(cx - r, arriba + 10, r * 2, base - zocalo - arriba - 6, L.lineal(_cilindro(piedra), 0, 0, 1, 0),
               ancho=T)
        capitel = oro or aclarar(piedra, 0.1)
        caja34(L, cx - r * 1.45, arriba - 4, cx + r * 1.45, arriba + 16, 9, aclarar(capitel, 0.1), capitel)
    for k in (-0.5, 0.0, 0.5):
        L.linea("M %s %s L %s %s" % (f(cx + k * r), f(arriba + 22), f(cx + k * r), f(base - zocalo - 2)),
                oscurecer(piedra, 0.35), 2.0, 0.7)
    if oro:
        L.rect(x0 + 2, base - zocalo + zocalo * 0.4 - 2, x1 - x0 - 4, 5, oro, ancho=1.8)


def estatua(L, x, y, w, h, p):
    """Un caballero de piedra sobre su pedestal, con la espada clavada delante."""
    piedra = p["piedra"]
    cx, base = x + w / 2, y + h - 8
    sombra_suelo(L, cx, base, w * 0.5, h * 0.08)
    ped = h * 0.3
    caja34(L, x + 8, base - ped, x + w - 8, base, ped * 0.38, aclarar(piedra, 0.05), oscurecer(piedra, 0.22))
    pie = base - ped + 8
    cuerpo = poligono([(cx - w * 0.2, pie), (cx - w * 0.24, y + h * 0.36), (cx - w * 0.16, y + h * 0.27),
                       (cx + w * 0.16, y + h * 0.27), (cx + w * 0.24, y + h * 0.36), (cx + w * 0.2, pie)])
    L.forma(cuerpo, L.lineal(_cilindro(piedra), 0, 0, 1, 0), ancho=T)
    for s in (-1, 1):
        L.elipse(cx + s * w * 0.22, y + h * 0.31, w * 0.11, h * 0.06, L.lineal(_vert(aclarar(piedra, 0.1))), ancho=T * 0.8)
    L.rect(cx - w * 0.11, y + 8, w * 0.22, h * 0.21, L.lineal(_cilindro(aclarar(piedra, 0.05)), 0, 0, 1, 0),
           ancho=T, r=w * 0.08)
    L.linea("M %s %s L %s %s" % (f(cx - w * 0.07), f(y + h * 0.15), f(cx + w * 0.07), f(y + h * 0.15)), CONTORNO, 3.5)
    # La espada, punta abajo, con las manos en el pomo.
    L.forma(poligono([(cx - 4, y + h * 0.42), (cx + 4, y + h * 0.42), (cx + 3, pie - 4), (cx, pie + 2),
                      (cx - 3, pie - 4)]), L.lineal(_cilindro(aclarar(piedra, 0.2)), 0, 0, 1, 0), ancho=3)
    L.rect(cx - w * 0.16, y + h * 0.4, w * 0.32, 6, aclarar(piedra, 0.1), ancho=3, r=2)
    L.elipse(cx, y + h * 0.36, w * 0.1, h * 0.045, aclarar(piedra, 0.05), ancho=3)


def armadura(L, x, y, w, h, p):
    metal = p["hierro"]
    cx, base = x + w / 2, y + h - 8
    sombra_suelo(L, cx, base, w * 0.45, h * 0.08)
    madera = p["madera_osc"]
    for s in (-1, 1):
        L.linea("M %s %s L %s %s" % (f(cx), f(base - h * 0.25), f(cx + s * w * 0.3), f(base - 2)), CONTORNO, 8)
        L.linea("M %s %s L %s %s" % (f(cx), f(base - h * 0.25), f(cx + s * w * 0.3), f(base - 2)), madera, 4.5)
    L.linea("M %s %s L %s %s" % (f(cx), f(base - 2), f(cx), f(y + h * 0.3)), CONTORNO, 9)
    L.linea("M %s %s L %s %s" % (f(cx), f(base - 2), f(cx), f(y + h * 0.3)), madera, 5)
    brillo = [(0, oscurecer(metal, 0.3)), (0.35, aclarar(metal, 0.55)), (0.6, metal), (1, oscurecer(metal, 0.5))]
    peto = "M %s %s Q %s %s %s %s L %s %s Q %s %s %s %s Z" % (
        f(cx - w * 0.26), f(y + h * 0.3), f(cx - w * 0.3), f(y + h * 0.55), f(cx - w * 0.14), f(y + h * 0.68),
        f(cx + w * 0.14), f(y + h * 0.68), f(cx + w * 0.3), f(y + h * 0.55), f(cx + w * 0.26), f(y + h * 0.3))
    L.forma(peto, L.lineal(brillo, 0, 0, 1, 0), ancho=T)
    L.linea("M %s %s L %s %s" % (f(cx), f(y + h * 0.33), f(cx), f(y + h * 0.64)), oscurecer(metal, 0.4), 2.5)
    for s in (-1, 1):
        L.elipse(cx + s * w * 0.28, y + h * 0.31, w * 0.13, h * 0.07, L.lineal(brillo, 0, 0, 1, 0), ancho=T * 0.8)
    L.rect(cx - w * 0.13, y + 10, w * 0.26, h * 0.2, L.lineal(brillo, 0, 0, 1, 0), ancho=T, r=w * 0.1)
    L.linea("M %s %s L %s %s" % (f(cx - w * 0.09), f(y + h * 0.17), f(cx + w * 0.09), f(y + h * 0.17)), CONTORNO, 3.5)
    L.forma("M %s %s Q %s %s %s %s Q %s %s %s %s Z" % (f(cx - 3), f(y + 12), f(cx + w * 0.05), f(y - 2),
                                                     f(cx + w * 0.3), f(y + 8), f(cx + w * 0.1), f(y + 6), f(cx + 4),
                                                     f(y + 14)),
            p["tela"], ancho=2.5)


def brasero(L, x, y, w, h, p, metal=None):
    metal = metal or p.get("oro", p["hierro"])
    cx, base = x + w / 2, y + h - 8
    sombra_suelo(L, cx, base, w * 0.45, h * 0.08)
    cuenco_y = y + h * 0.5
    for s in (-1, 0, 1):
        L.linea("M %s %s L %s %s" % (f(cx + s * w * 0.18), f(cuenco_y), f(cx + s * w * 0.32), f(base - 2)), CONTORNO, 9)
        L.linea("M %s %s L %s %s" % (f(cx + s * w * 0.18), f(cuenco_y), f(cx + s * w * 0.32), f(base - 2)),
                oscurecer(metal, 0.15), 5)
    r = w * 0.38
    L.forma("M %s %s Q %s %s %s %s Q %s %s %s %s Z" % (f(cx - r), f(cuenco_y - 8), f(cx - r * 0.8), f(cuenco_y + r * 0.55),
                                                     f(cx), f(cuenco_y + r * 0.55), f(cx + r * 0.8),
                                                     f(cuenco_y + r * 0.55), f(cx + r), f(cuenco_y - 8)),
            L.lineal(_cilindro(metal), 0, 0, 1, 0), ancho=T)
    L.elipse(cx, cuenco_y - 8, r, r * 0.28, "#2a0c06", ancho=T * 0.8)
    L.elipse(cx, cuenco_y - 6, r * 0.8, r * 0.18, "#ff7a2a", trazo=None, extra='opacity="0.8"')
    for k, alto in ((-0.35, 0.45), (0.0, 0.62), (0.35, 0.42)):
        llama(L, cx + k * r, cuenco_y - 6, h * alto * 0.55, p["fuego"], resplandor=(k == 0.0))


def pedestal(L, x, y, w, h, p):
    piedra = p["piedra"]
    cx, base = x + w / 2, y + h - 8
    sombra_suelo(L, cx, base, w * 0.45, h * 0.08)
    caja34(L, x + 14, base - h * 0.45, x + w - 14, base, h * 0.12, aclarar(piedra, 0.06), oscurecer(piedra, 0.2))
    oro = p.get("oro", p["hierro"])
    L.rect(x + 16, base - h * 0.2, w - 32, 6, oro, ancho=2)
    urna(L, x + w * 0.18, y, w * 0.64, h * 0.62, p, color=oro, adorno=p["tela"])


# --- Mesas y losas (plataformas) ------------------------------------------------------

def mesa(L, x, y, w, h, p, mantel=None, oro=None):
    madera = p["madera"]
    cx, base = x + w / 2, y + h - 6
    sombra_suelo(L, cx, base - 4, w * 0.5, h * 0.12)
    x0, x1 = x + 10, x + w - 10
    ancha = w >= h
    tablero = (base - y) * (0.62 if ancha else 0.78)
    canto = (base - y) * 0.1
    patas = base - y - tablero - canto
    for xx in (x0 + 14, x1 - 14):
        L.rect(xx - 8, y + tablero + canto - 4, 16, patas, L.lineal(_cilindro(madera), 0, 0, 1, 0), ancho=T * 0.8)
    L.rect(x0, y + tablero, x1 - x0, canto, oscurecer(madera, 0.25), ancho=T)
    L.rect(x0, y + 4, x1 - x0, tablero - 4, L.lineal(_vert(aclarar(madera, 0.08))), ancho=T, r=4)
    if ancha:
        for k in range(1, 4):
            yy = y + 4 + (tablero - 4) * k / 4
            L.linea("M %s %s L %s %s" % (f(x0 + 4), f(yy), f(x1 - 4), f(yy)), oscurecer(madera, 0.4), 2.0)
    else:
        for k in range(1, 3):
            xx = x0 + (x1 - x0) * k / 3
            L.linea("M %s %s L %s %s" % (f(xx), f(y + 8), f(xx), f(y + tablero - 2)), oscurecer(madera, 0.4), 2.0)
    if mantel:
        m0, m1 = x0 + (x1 - x0) * 0.08, x1 - (x1 - x0) * 0.08
        L.rect(m0, y + 4, m1 - m0, tablero - 4, L.lineal(_vert(mantel)), ancho=T * 0.8)
        L.forma("M %s %s L %s %s L %s %s Q %s %s %s %s Q %s %s %s %s Z" % (
            f(m0), f(y + tablero), f(m1), f(y + tablero), f(m1), f(y + tablero + canto * 2.2),
            f((m0 + m1) * 0.75 - m0 * 0.25), f(y + tablero + canto * 1.4), f((m0 + m1) / 2), f(y + tablero + canto * 2.2),
            f((m0 + m1) * 0.25 + m0 * 0.25), f(y + tablero + canto * 1.4), f(m0), f(y + tablero + canto * 2.2)),
            oscurecer(mantel, 0.2), ancho=T * 0.8)
        if oro:
            L.rect(m0 + 6, y + 10, m1 - m0 - 12, tablero - 16, "none", trazo=oro, ancho=2.5, extra='opacity="0.9"')


def camastro(L, x, y, w, h, p):
    madera, paja = p["madera_osc"], p["paja"]
    cx, base = x + w / 2, y + h - 6
    sombra_suelo(L, cx, base - 4, w * 0.5, h * 0.12)
    x0, x1, y0 = x + 8, x + w - 8, y + 8
    caja34(L, x0, y0, x1, base - 6, (base - 6 - y0) * 0.72, madera, oscurecer(madera, 0.2))
    azar = random.Random("paja%d%d" % (w, h))
    ancha = w >= h
    colchon = (x0 + 12, y0 + 10, x1 - 12, y0 + (base - 6 - y0) * 0.72 - 6)
    L.rect(colchon[0], colchon[1], colchon[2] - colchon[0], colchon[3] - colchon[1],
           L.lineal(_vert(paja)), ancho=T * 0.8, r=12)
    for _ in range(40):
        xx = azar.uniform(colchon[0] + 6, colchon[2] - 6)
        yy = azar.uniform(colchon[1] + 6, colchon[3] - 6)
        a = azar.uniform(-0.6, 0.6) + (0 if ancha else math.pi / 2)
        L.linea("M %s %s l %s %s" % (f(xx), f(yy), f(math.cos(a) * 14), f(math.sin(a) * 14)),
                oscurecer(paja, 0.3), 1.6, 0.7)
    manta = p["tela"]
    if ancha:
        L.rect(colchon[0] + (colchon[2] - colchon[0]) * 0.45, colchon[1] - 4, (colchon[2] - colchon[0]) * 0.5,
               colchon[3] - colchon[1] + 8, L.lineal(_vert(manta)), ancho=T * 0.8, r=8)
    else:
        L.rect(colchon[0] - 4, colchon[1] + (colchon[3] - colchon[1]) * 0.45, colchon[2] - colchon[0] + 8,
               (colchon[3] - colchon[1]) * 0.5, L.lineal(_vert(manta)), ancho=T * 0.8, r=8)


def losa(L, x, y, w, h, p, musgo=0.0, rejilla=False, grabado=None):
    piedra = p["piedra"]
    cx, base = x + w / 2, y + h - 6
    sombra_suelo(L, cx, base - 4, w * 0.5, h * 0.1)
    x0, x1, y0 = x + 8, x + w - 8, y + 8
    tapa = (base - y0) * 0.68
    caja34(L, x0, y0, x1, base - 4, tapa, aclarar(piedra, 0.0), oscurecer(piedra, 0.25))
    azar = random.Random("losa%d%d%d" % (w, h, int(musgo * 10)))
    for _ in range(4):
        _rajita(L, azar, azar.uniform(x0 + 20, x1 - 20), azar.uniform(y0 + 10, y0 + tapa - 10), oscurecer(piedra, 0.5))
    if rejilla:
        gw, gh = (x1 - x0) * 0.3, tapa * 0.5
        gx, gy = cx - gw / 2, y0 + tapa * 0.25
        L.rect(gx, gy, gw, gh, "#0a0d0b", ancho=3, r=3)
        for k in range(1, 6):
            L.linea("M %s %s L %s %s" % (f(gx + gw * k / 6), f(gy + 2), f(gx + gw * k / 6), f(gy + gh - 2)),
                    p["hierro"], 3)
    if grabado:
        L.rect(x0 + 18, y0 + 12, x1 - x0 - 36, tapa - 24, "none", trazo=grabado, ancho=2.2, extra='opacity="0.6"')
    for _ in range(int(musgo * 8)):
        L.forma(piedra_irregular(azar, azar.uniform(x0 + 10, x1 - 10), azar.uniform(y0 + 6, base - 10),
                                 azar.uniform(10, 26), azar.uniform(6, 12), 8, 0.3), p["musgo"], trazo=None,
                extra='opacity="0.85"')


def _rajita(L, azar, x, y, color):
    puntos = [(x, y)]
    ang = azar.uniform(0, math.tau)
    for _ in range(4):
        ang += azar.uniform(-0.7, 0.7)
        x += math.cos(ang) * 9
        y += math.sin(ang) * 9
        puntos.append((x, y))
    L.linea("M " + " L ".join("%s %s" % (f(a), f(b)) for a, b in puntos), color, 1.8, 0.8)


def tarima(L, x, y, w, h, p):
    """Una tarima de dos escalones con alfombra roja y canto de oro."""
    piedra, tela, oro = p["piedra"], p["tela"], p["oro"]
    cx, base = x + w / 2, y + h - 6
    sombra_suelo(L, cx, base - 4, w * 0.5, h * 0.1)
    x0, x1, y0 = x + 8, x + w - 8, y + 8
    alto = base - 4 - y0
    caja34(L, x0, y0 + alto * 0.18, x1, base - 4, alto * 0.5, oscurecer(piedra, 0.25), oscurecer(piedra, 0.45))
    caja34(L, x0 + (x1 - x0) * 0.1, y0, x1 - (x1 - x0) * 0.1, y0 + alto * 0.62, alto * 0.42,
           oscurecer(piedra, 0.15), oscurecer(piedra, 0.35))
    if w >= h:
        L.rect(cx - (x1 - x0) * 0.16, y0, (x1 - x0) * 0.32, alto - 2, L.lineal(_vert(tela)), ancho=T * 0.8)
        for s in (-1, 1):
            L.linea("M %s %s L %s %s" % (f(cx + s * (x1 - x0) * 0.13), f(y0 + 4), f(cx + s * (x1 - x0) * 0.13),
                                         f(base - 8)), oro, 2.5)
    else:
        L.rect(x0 + (x1 - x0) * 0.25, y0, (x1 - x0) * 0.5, alto - 2, L.lineal(_vert(tela)), ancho=T * 0.8)
    L.linea("M %s %s L %s %s" % (f(x0), f(y0 + alto * 0.68), f(x1), f(y0 + alto * 0.68)), oro, 3.0, 0.9)


# --- Grupos ------------------------------------------------------------------------------

def grupo(L, x, y, w, h, p, piezas):
    """Varias piezas juntas: una al lado de otra si la caja es ancha, una detras de
    otra si es alta. Las de detras primero, para que las tapen las de delante."""
    n = len(piezas)
    if w >= h:
        ancho = w / n * 1.3
        sitios = []
        for k, pieza in enumerate(piezas):
            px = x + (w - ancho) * (k / max(1, n - 1))
            atras = (k % 2 == 1)
            sitios.append((atras, pieza, px, y + (0 if atras else h * 0.16), ancho, h * 0.84))
        sitios.sort(key=lambda s: not s[0])
    else:
        alto = h / n * 1.35
        sitios = []
        for k, pieza in enumerate(piezas):
            py = y + (h - alto) * (k / max(1, n - 1))
            lado = (w * 0.1) * (1 if k % 2 else -1)
            sitios.append((k, pieza, x + w * 0.06 + lado, py, w * 0.88, alto))
        sitios.sort(key=lambda s: s[0])
    for _, (funcion, extra), px, py, pw, ph in sitios:
        funcion(L, px, py, pw, ph, p, **extra)


# --- Lo pequeno: encima de las mesas y por el suelo ---------------------------------------

def botella(L, x, y, w, h, p, color="#3f7a4a"):
    cx, base = x + w / 2, y + h - 4
    L.forma("M %s %s L %s %s Q %s %s %s %s L %s %s L %s %s L %s %s Q %s %s %s %s L %s %s Z" % (
        f(cx - w * 0.22), f(base), f(cx - w * 0.22), f(base - h * 0.45), f(cx - w * 0.22), f(base - h * 0.6),
        f(cx - w * 0.07), f(base - h * 0.66), f(cx - w * 0.07), f(base - h * 0.88), f(cx + w * 0.07), f(base - h * 0.88),
        f(cx + w * 0.07), f(base - h * 0.66), f(cx + w * 0.22), f(base - h * 0.6), f(cx + w * 0.22), f(base - h * 0.45),
        f(cx + w * 0.22), f(base)), L.lineal(_cilindro(color), 0, 0, 1, 0), ancho=2.5)
    L.rect(cx - w * 0.08, base - h * 0.97, w * 0.16, h * 0.1, "#8a6a44", ancho=2)
    L.linea("M %s %s L %s %s" % (f(cx - w * 0.12), f(base - h * 0.5), f(cx - w * 0.12), f(base - h * 0.12)),
            "#ffffff", 2.0, 0.6)


def jarra(L, x, y, w, h, p):
    cx, base = x + w / 2, y + h - 4
    metal = p["hierro"]
    L.linea("M %s %s q %s %s %s %s" % (f(cx + w * 0.22), f(base - h * 0.6), f(w * 0.25), f(h * 0.05), f(0), f(h * 0.35)),
            CONTORNO, 6)
    L.linea("M %s %s q %s %s %s %s" % (f(cx + w * 0.22), f(base - h * 0.6), f(w * 0.25), f(h * 0.05), f(0), f(h * 0.35)),
            metal, 3)
    L.rect(cx - w * 0.25, base - h * 0.7, w * 0.5, h * 0.7, L.lineal(_cilindro(metal), 0, 0, 1, 0), ancho=2.5, r=3)
    L.elipse(cx, base - h * 0.7, w * 0.25, h * 0.08, oscurecer(metal, 0.4), ancho=2)


def copa(L, x, y, w, h, p, metal=None):
    metal = metal or p.get("oro", p["hierro"])
    cx, base = x + w / 2, y + h - 4
    L.elipse(cx, base - 3, w * 0.22, h * 0.06, metal, ancho=2.2)
    L.rect(cx - 3, base - h * 0.5, 6, h * 0.46, metal, ancho=2)
    L.forma("M %s %s Q %s %s %s %s Q %s %s %s %s Z" % (f(cx - w * 0.28), f(base - h * 0.88), f(cx - w * 0.26),
                                                     f(base - h * 0.45), f(cx), f(base - h * 0.48), f(cx + w * 0.26),
                                                     f(base - h * 0.45), f(cx + w * 0.28), f(base - h * 0.88)),
            L.lineal(_cilindro(metal), 0, 0, 1, 0), ancho=2.5)
    L.elipse(cx, base - h * 0.88, w * 0.28, h * 0.07, "#5a0e18", ancho=2.2)
    destello(L, cx - w * 0.12, base - h * 0.7, 4)


def monedas(L, x, y, w, h, p, oro=None):
    oro = oro or p.get("oro", "#d8a93e")
    azar = random.Random("monedas%d%d" % (w, h))
    for _ in range(9):
        cx = azar.uniform(x + w * 0.2, x + w * 0.8)
        cy = azar.uniform(y + h * 0.45, y + h - 6)
        L.elipse(cx, cy, w * 0.13, h * 0.08, L.lineal(_vert(oro)), ancho=2.0)
        L.elipse(cx, cy - 1, w * 0.07, h * 0.04, aclarar(oro, 0.35), trazo=None)
    destello(L, x + w * 0.62, y + h * 0.45, 5)


def corona(L, x, y, w, h, p):
    oro = p["oro"]
    cx, base = x + w / 2, y + h - 6
    puntas = [(cx - w * 0.38, base), (cx - w * 0.4, base - h * 0.55), (cx - w * 0.22, base - h * 0.3),
              (cx, base - h * 0.7), (cx + w * 0.22, base - h * 0.3), (cx + w * 0.4, base - h * 0.55),
              (cx + w * 0.38, base)]
    L.forma(poligono(puntas), L.lineal(_vert(oro)), ancho=2.5)
    for xx, c in ((cx - w * 0.2, "#c0203a"), (cx, "#3a6ad0"), (cx + w * 0.2, "#c0203a")):
        L.elipse(xx, base - h * 0.15, 3.5, 3.5, c, ancho=1.5)
    destello(L, cx + w * 0.1, base - h * 0.5, 4)


def vela_suelta(L, x, y, w, h, p, fuego=None):
    cx, base = x + w / 2, y + h - 4
    L.elipse(cx, base - 2, w * 0.3, h * 0.07, p["hierro"], ancho=2)
    vela(L, cx, base - 3, h * 0.85, fuego=fuego)


def calavera_suelta(L, x, y, w, h, p):
    calavera(L, x + w / 2, y + h * 0.5, min(w, h) * 0.36, p["hueso"])


def setas_pequenas(L, x, y, w, h, p, brillo="#7fe8c8"):
    setas(L, x, y, w, h, p, brillo)


def matojo(L, x, y, w, h, p, color=None, tiras=7):
    """Una mata de paja o de musgo: tiras que salen de abajo."""
    color = color or p["paja"]
    cx, base = x + w / 2, y + h - 2
    azar = random.Random("matojo%s%d" % (color, w))
    for k in range(tiras):
        a = -math.pi / 2 + azar.uniform(-0.9, 0.9)
        largo = h * azar.uniform(0.55, 0.95)
        d = "M %s %s Q %s %s %s %s" % (f(cx + azar.uniform(-w * 0.25, w * 0.25)), f(base),
                                       f(cx + math.cos(a) * largo * 0.4), f(base + math.sin(a) * largo * 0.6),
                                       f(cx + math.cos(a) * largo), f(base + math.sin(a) * largo))
        L.linea(d, CONTORNO, 4.5)
        L.linea(d, variar_color(color, azar), 2.4)


def variar_color(c, azar):
    t = azar.uniform(-0.15, 0.15)
    return aclarar(c, t) if t > 0 else oscurecer(c, -t)


def guijarros(L, x, y, w, h, p, color=None):
    color = color or p["piedra"]
    azar = random.Random("guijarros%s" % color)
    for _ in range(3):
        cx, cy = azar.uniform(x + w * 0.2, x + w * 0.8), azar.uniform(y + h * 0.35, y + h * 0.75)
        r = azar.uniform(w * 0.1, w * 0.18)
        L.forma(piedra_irregular(azar, cx, cy, r, r * 0.75, 7, 0.2),
                L.radial([(0, aclarar(color, 0.25)), (1, oscurecer(color, 0.25))], 0.4, 0.3, 0.8), ancho=2.0)


def charco(L, x, y, w, h, p):
    azar = random.Random("charco%d" % w)
    L.forma(piedra_irregular(azar, x + w / 2, y + h / 2, w * 0.42, h * 0.36, 10, 0.2), p["agua"],
            trazo=oscurecer(p["agua"], 0.4), ancho=2.0)
    L.linea("M %s %s q %s %s %s %s" % (f(x + w * 0.3), f(y + h * 0.42), f(w * 0.1), f(-h * 0.1), f(w * 0.25), f(-h * 0.05)),
            p["agua_luz"], 2.0, 0.7)


def eslabon(L, x, y, w, h, p):
    cadena(L, x + w * 0.15, y + h * 0.6, x + w * 0.85, y + h * 0.4, 9, p["hierro"], 2.4)


def hueso_suelto(L, x, y, w, h, p):
    hueso(L, x + w * 0.2, y + h * 0.65, x + w * 0.8, y + h * 0.35, 6, p["hueso"])


def cera(L, x, y, w, h, p):
    azar = random.Random("cera%d" % w)
    for _ in range(3):
        cx, cy = azar.uniform(x + w * 0.2, x + w * 0.8), azar.uniform(y + h * 0.3, y + h * 0.7)
        L.forma(piedra_irregular(azar, cx, cy, w * 0.14, h * 0.18, 9, 0.3), "#e8dcc0", ancho=1.8)


def petalos(L, x, y, w, h, p):
    azar = random.Random("petalos")
    for _ in range(5):
        cx, cy = azar.uniform(x + w * 0.15, x + w * 0.85), azar.uniform(y + h * 0.25, y + h * 0.75)
        a = azar.uniform(0, 180)
        L.add('<ellipse cx="%s" cy="%s" rx="%s" ry="%s" fill="#b0182a" stroke="%s" stroke-width="1.4" '
              'transform="rotate(%s %s %s)"/>' % (f(cx), f(cy), f(w * 0.1), f(h * 0.08), CONTORNO, f(a), f(cx), f(cy)))


def cristal(L, x, y, w, h, p, color=None):
    color = color or p.get("maldito", "#b05cff")
    cx, base = x + w / 2, y + h - 3
    halo = L.difuso(4)
    L.elipse(cx, base - h * 0.4, w * 0.4, h * 0.4, color, trazo=None, extra='opacity="0.35" filter="%s"' % halo)
    for dx, alto, inclina in ((-w * 0.18, 0.6, -0.25), (w * 0.15, 0.85, 0.12), (0, 0.45, 0.0)):
        bx = cx + dx
        punta = (bx + inclina * h * alto, base - h * alto)
        L.forma(poligono([(bx - w * 0.1, base), punta, (bx + w * 0.1, base)]),
                L.lineal([(0, aclarar(color, 0.55)), (1, oscurecer(color, 0.35))], 0, 0, 1, 0), ancho=2.2)
    destello(L, cx + w * 0.1, base - h * 0.62, 4)


def gema(L, x, y, w, h, p):
    cristal(L, x, y, w, h, p, "#3ac0d0")


def astillas(L, x, y, w, h, p, color=None):
    """Astillas o paja por el suelo, segun el color."""
    color = color or p["madera"]
    azar = random.Random("astillas%s" % color)
    for _ in range(4):
        cx, cy = azar.uniform(x + w * 0.2, x + w * 0.8), azar.uniform(y + h * 0.3, y + h * 0.7)
        a = azar.uniform(0, math.pi)
        largo = azar.uniform(w * 0.2, w * 0.35)
        d = "M %s %s L %s %s" % (f(cx - math.cos(a) * largo / 2), f(cy - math.sin(a) * largo / 2),
                                 f(cx + math.cos(a) * largo / 2), f(cy + math.sin(a) * largo / 2))
        L.linea(d, CONTORNO, 6)
        L.linea(d, color, 3)


# --- La pared: pilares, adornos y colgantes ---------------------------------------

def pilar(L, x, y, w, h, p, zona):
    """El pilar de los lados de las puertas, de frente, con su fuego encima."""
    piedra = p["cara"]
    cx = x + w / 2
    base = y + h - 2
    arriba = y + h * 0.3
    caja34(L, x + 4, base - 14, x + w - 4, base, 5, aclarar(piedra, 0.1), oscurecer(piedra, 0.15), 3.5)
    L.rect(x + 9, arriba + 8, w - 18, base - 14 - arriba - 8, L.lineal(_cilindro(piedra), 0, 0, 1, 0), ancho=3.5)
    for k in range(1, 4):
        yy = arriba + 8 + (base - 22 - arriba) * k / 4
        L.linea("M %s %s L %s %s" % (f(x + 11), f(yy), f(x + w - 11), f(yy)), oscurecer(piedra, 0.5), 1.8)
    capitel = p.get("oro", aclarar(piedra, 0.15)) if zona == "trono" else aclarar(piedra, 0.12)
    caja34(L, x + 2, arriba, x + w - 2, arriba + 12, 5, aclarar(capitel, 0.1), capitel, 3.5)
    fuego = p["fuego"]
    if zona == "calabozos":
        L.forma("M %s %s Q %s %s %s %s Z" % (f(cx - 14), f(arriba - 2), f(cx), f(arriba + 12), f(cx + 14), f(arriba - 2)),
                p["hierro"], ancho=3)
        llama(L, cx, arriba - 2, h * 0.3, fuego)
    elif zona == "cloacas":
        L.rect(cx - 9, arriba - 24, 18, 22, "#1a2a18", ancho=3, r=3)
        L.elipse(cx, arriba - 13, 6, 8, L.radial([(0, fuego[0]), (0.6, fuego[1]), (1, fuego[2])]), trazo=None)
        halo = L.difuso(5)
        L.elipse(cx, arriba - 13, 14, 14, fuego[1], trazo=None, extra='opacity="0.4" filter="%s"' % halo)
        for k in range(3):
            L.linea("M %s %s L %s %s" % (f(cx - 6 + k * 6), f(arriba - 24), f(cx - 6 + k * 6), f(arriba - 2)),
                    p["hierro"], 1.8)
    elif zona == "cripta":
        calavera(L, cx, (arriba + base) / 2, w * 0.2, p["hueso"])
        vela(L, cx, arriba, h * 0.3, fuego=fuego)
    else:
        L.forma("M %s %s Q %s %s %s %s Z" % (f(cx - 15), f(arriba - 2), f(cx), f(arriba + 14), f(cx + 15), f(arriba - 2)),
                p["oro"], ancho=3)
        llama(L, cx, arriba - 2, h * 0.32, fuego)


def colgante_estandarte(L, x, y, w, h, p, tela, emblema=None):
    oro = p.get("oro", "#d8a93e")
    L.rect(x + 2, y + 2, w - 4, 5, oro, ancho=2, r=2)
    L.forma(poligono([(x + 6, y + 6), (x + w - 6, y + 6), (x + w - 6, y + h - 4), (x + w / 2, y + h - 14),
                      (x + 6, y + h - 4)]), L.lineal(_cilindro(tela), 0, 0, 1, 0), ancho=3)
    L.linea("M %s %s L %s %s" % (f(x + 9), f(y + 9), f(x + 9), f(y + h - 10)), oro, 1.8)
    L.linea("M %s %s L %s %s" % (f(x + w - 9), f(y + 9), f(x + w - 9), f(y + h - 10)), oro, 1.8)
    cx, cy = x + w / 2, y + h * 0.42
    if emblema == "corona":
        L.forma(poligono([(cx - 8, cy + 6), (cx - 9, cy - 5), (cx - 4, cy), (cx, cy - 8), (cx + 4, cy), (cx + 9, cy - 5),
                          (cx + 8, cy + 6)]), oro, ancho=1.6)
    else:
        L.forma(poligono([(cx, cy - 9), (cx + 7, cy), (cx, cy + 9), (cx - 7, cy)]), oro, ancho=1.6)


def colgante_telarana(L, x, y, w, h, p):
    cx = x + w / 2
    color = "#d8d4e0"
    radios = 7
    centro = (cx, y + h * 0.35)
    for k in range(radios):
        a = math.pi * k / (radios - 1)
        L.linea("M %s %s L %s %s" % (f(centro[0]), f(centro[1]), f(centro[0] + math.cos(a) * w * 0.48),
                                     f(centro[1] + math.sin(a) * h * 0.6 - h * 0.25)), color, 1.2, 0.7)
    for r in (0.25, 0.5, 0.75):
        puntos = []
        for k in range(radios):
            a = math.pi * k / (radios - 1)
            puntos.append((centro[0] + math.cos(a) * w * 0.48 * r, centro[1] + (math.sin(a) * h * 0.6 - h * 0.25) * r))
        L.linea("M " + " L ".join("%s %s" % (f(a), f(b)) for a, b in puntos), color, 1.1, 0.6)
    L.linea("M %s %s L %s %s" % (f(cx), f(y), f(cx), f(y + h * 0.9)), color, 1.0, 0.7)
    L.elipse(cx, y + h * 0.9, 3, 3.5, "#1a1418", ancho=1.2)


def colgante_farol(L, x, y, w, h, p, fuego):
    cx = x + w / 2
    L.linea("M %s %s L %s %s" % (f(cx), f(y), f(cx), f(y + h * 0.3)), CONTORNO, 4)
    L.linea("M %s %s L %s %s" % (f(cx), f(y), f(cx), f(y + h * 0.3)), p["hierro"], 2)
    halo = L.difuso(6)
    L.elipse(cx, y + h * 0.62, w * 0.6, h * 0.35, fuego[1], trazo=None, extra='opacity="0.4" filter="%s"' % halo)
    L.forma(poligono([(cx - w * 0.3, y + h * 0.36), (cx + w * 0.3, y + h * 0.36), (cx + w * 0.36, y + h * 0.88),
                      (cx - w * 0.36, y + h * 0.88)]), "#140e14", ancho=3)
    L.elipse(cx, y + h * 0.62, w * 0.18, h * 0.16, L.radial([(0, fuego[0]), (0.5, fuego[1]), (1, fuego[2])]), trazo=None)
    for k in (-1, 0, 1):
        L.linea("M %s %s L %s %s" % (f(cx + k * w * 0.16), f(y + h * 0.38), f(cx + k * w * 0.19), f(y + h * 0.86)),
                p["hierro"], 2)
    L.forma(poligono([(cx - w * 0.38, y + h * 0.36), (cx, y + h * 0.26), (cx + w * 0.38, y + h * 0.36)]),
            p["hierro"], ancho=2.5)


def colgante_limo(L, x, y, w, h, p):
    """Una boca de tuberia de la que cae limo."""
    hierro = p["hierro"]
    L.rect(x + w * 0.15, y, w * 0.7, h * 0.28, L.lineal(_cilindro(hierro), 0, 0, 1, 0), ancho=3, r=3)
    L.elipse(x + w / 2, y + h * 0.28, w * 0.33, h * 0.07, "#0a0d0b", ancho=2.5)
    limo = p["limo"]
    L.forma("M %s %s Q %s %s %s %s Q %s %s %s %s Q %s %s %s %s Z" % (
        f(x + w * 0.35), f(y + h * 0.28), f(x + w * 0.3), f(y + h * 0.7), f(x + w * 0.48), f(y + h * 0.95),
        f(x + w * 0.56), f(y + h * 0.6), f(x + w * 0.6), f(y + h * 0.75), f(x + w * 0.68), f(y + h * 0.4),
        f(x + w * 0.65), f(y + h * 0.28)), L.lineal([(0, aclarar(limo, 0.2)), (1, limo)]), ancho=2.5)


def colgante_raices(L, x, y, w, h, p, color=None):
    color = color or p["musgo"]
    azar = random.Random("raices%s" % color)
    for _ in range(5):
        x0 = azar.uniform(x + w * 0.1, x + w * 0.9)
        largo = h * azar.uniform(0.5, 0.95)
        d = "M %s %s Q %s %s %s %s" % (f(x0), f(y), f(x0 + azar.uniform(-8, 8)), f(y + largo * 0.5),
                                       f(x0 + azar.uniform(-6, 6)), f(y + largo))
        L.linea(d, CONTORNO, 5)
        L.linea(d, color, 2.6)


def colgante_grillete(L, x, y, w, h, p):
    hierro = p["hierro"]
    cx = x + w / 2
    L.elipse(cx, y + 6, 5, 5, "none", trazo=CONTORNO, ancho=5)
    L.elipse(cx, y + 6, 5, 5, "none", trazo=hierro, ancho=2.5)
    cadena(L, cx, y + 10, cx, y + h - 14, 7, hierro, 2.2)
    L.elipse(cx, y + h - 9, w * 0.32, 6, "none", trazo=CONTORNO, ancho=6)
    L.elipse(cx, y + h - 9, w * 0.32, 6, "none", trazo=hierro, ancho=3)


def colgante_antorcha(L, x, y, w, h, p, madera=None, hierro=None):
    antorcha(L, x + w / 2, y + h * 0.55, h * 0.7, madera or p["madera"], hierro or p["hierro"], p["fuego"])


# --- La bajada ------------------------------------------------------------------------------

def bajada(L, p, zona, tapada):
    """La bajada al piso de abajo: un marco de piedra y unas escaleras que se
    pierden en lo oscuro. Tapada, con su trampilla, reja o losa (en el castillo,
    mientras haya enemigos en la sala)."""
    W = L.w
    m = W * 0.14
    piedra = p["cara"]
    L.rect(4, 4, W - 8, W - 8, L.lineal(_vert(aclarar(piedra, 0.05))), ancho=T, r=10)
    for k in range(4):
        a = 4 + (W - 8) * k / 4
        L.linea("M %s %s L %s %s" % (f(a), f(4), f(a), f(m)), oscurecer(piedra, 0.5), 2)
        L.linea("M %s %s L %s %s" % (f(a), f(W - m), f(a), f(W - 4)), oscurecer(piedra, 0.5), 2)
    x0, y0, x1, y1 = m, m, W - m, W - m
    if not tapada:
        L.rect(x0, y0, x1 - x0, y1 - y0, "#050406", ancho=3.5, r=4)
        peldanos = 6
        for k in range(peldanos):
            t0 = k / peldanos
            t1 = (k + 1) / peldanos
            ya = y1 - (y1 - y0) * t1
            yb = y1 - (y1 - y0) * t0
            estrecha = (x1 - x0) * 0.06 * t1
            luz = 1.0 - t1 * 0.95
            huella = mezclar("#050406", aclarar(piedra, 0.1), luz)
            contrahuella = mezclar("#050406", oscurecer(piedra, 0.35), luz)
            alto = yb - ya
            L.rect(x0 + 4 + estrecha, ya + alto * 0.45, x1 - x0 - 8 - estrecha * 2, alto * 0.55, contrahuella, trazo=None)
            L.rect(x0 + 4 + estrecha, ya, x1 - x0 - 8 - estrecha * 2, alto * 0.45, huella, trazo=None)
            L.linea("M %s %s L %s %s" % (f(x0 + 4 + estrecha), f(ya + alto * 0.45), f(x1 - 4 - estrecha),
                                         f(ya + alto * 0.45)), "#050406", 1.6, 0.8)
        L.rect(x0, y0, x1 - x0, (y1 - y0) * 0.5, L.lineal([(0, "#050406", 1.0), (1, "#050406", 0.0)]), trazo=None)
        for s in (-1, 1):
            borde = x0 if s < 0 else x1
            L.forma(poligono([(borde, y0), (borde - s * (x1 - x0) * 0.08, y0), (borde, y1)]), "#08070a", trazo=None)
        L.rect(x0, y0, x1 - x0, y1 - y0, "none", ancho=3.5, r=4)
        return
    if zona == "calabozos":
        madera = p["madera"]
        L.rect(x0, y0, x1 - x0, y1 - y0, L.lineal(_vert(madera)), ancho=3.5, r=3)
        for k in range(1, 4):
            xx = x0 + (x1 - x0) * k / 4
            L.linea("M %s %s L %s %s" % (f(xx), f(y0 + 2), f(xx), f(y1 - 2)), oscurecer(madera, 0.45), 2.4)
        for yy in (y0 + (y1 - y0) * 0.22, y1 - (y1 - y0) * 0.22):
            L.rect(x0 - 2, yy - 6, x1 - x0 + 4, 12, p["hierro"], ancho=2.5, r=2)
        cx, cy = W / 2, W / 2
        L.elipse(cx, cy, 11, 11, "none", trazo=CONTORNO, ancho=7)
        L.elipse(cx, cy, 11, 11, "none", trazo=aclarar(p["hierro"], 0.2), ancho=3.5)
    elif zona == "cloacas":
        L.rect(x0, y0, x1 - x0, y1 - y0, "#071009", ancho=3.5, r=3)
        halo = L.difuso(8)
        L.elipse(W / 2, W / 2, (x1 - x0) * 0.35, (y1 - y0) * 0.3, p["limo"], trazo=None,
                 extra='opacity="0.35" filter="%s"' % halo)
        for k in range(1, 7):
            xx = x0 + (x1 - x0) * k / 7
            L.linea("M %s %s L %s %s" % (f(xx), f(y0 + 2), f(xx), f(y1 - 2)), CONTORNO, 7)
            L.linea("M %s %s L %s %s" % (f(xx), f(y0 + 2), f(xx), f(y1 - 2)), p["hierro"], 3.5)
        for yy in (y0 + (y1 - y0) / 3, y0 + (y1 - y0) * 2 / 3):
            L.linea("M %s %s L %s %s" % (f(x0 + 2), f(yy), f(x1 - 2), f(yy)), CONTORNO, 7)
            L.linea("M %s %s L %s %s" % (f(x0 + 2), f(yy), f(x1 - 2), f(yy)), p["hierro"], 3.5)
    elif zona == "cripta":
        losa_color = p["piedra"]
        L.rect(x0, y0, x1 - x0, y1 - y0, L.lineal(_vert(losa_color)), ancho=3.5, r=3)
        calavera(L, W / 2, W / 2 - 4, (x1 - x0) * 0.18, oscurecer(losa_color, 0.35), vacio=oscurecer(losa_color, 0.7))
        L.rect(x0 + 8, y0 + 8, x1 - x0 - 16, y1 - y0 - 16, "none", trazo=oscurecer(losa_color, 0.45), ancho=2)
    else:
        L.rect(x0, y0, x1 - x0, y1 - y0, L.lineal(_vert(p["madera_osc"])), ancho=3.5, r=3)
        L.rect(x0 + 6, y0 + 6, x1 - x0 - 12, y1 - y0 - 12, "none", trazo=p["oro"], ancho=3)
        cx, cy = W / 2, W / 2
        L.forma(poligono([(cx - 14, cy + 9), (cx - 16, cy - 8), (cx - 7, cy), (cx, cy - 13), (cx + 7, cy),
                          (cx + 16, cy - 8), (cx + 14, cy + 9)]), L.lineal(_vert(p["oro"])), ancho=2.5)
        halo = L.difuso(4)
        L.elipse(cx, cy + 24, 9, 9, p["maldito"], trazo=None, extra='opacity="0.6" filter="%s"' % halo)
        L.elipse(cx, cy + 24, 5, 5, p["maldito"], ancho=2)
