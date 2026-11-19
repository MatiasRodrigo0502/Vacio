# -*- coding: utf-8 -*-
"""Herramientas de dibujo vectorial del castillo maldito (generar_castillo.py).

Un Lienzo junta un SVG (sus degradados y lo que se dibuja), lo pinta con
rsvg-convert al doble y lo reduce con buen filtro, como los magos
(generar_magos.reducir): el trazo sale limpio y el contorno no se mancha.

El estilo es el de los magos y los enemigos: contorno casi negro, colores
llenos y volumen con degradados, y algun brillo pequeno. Las piezas de aqui
(llamas, cadenas, velas, calaveras...) se repiten en varias zonas, por eso
estan aparte del castillo.

Necesita rsvg-convert (paquete librsvg2-bin).
"""
import math
import os
import subprocess
import tempfile

from PIL import Image

# El de los magos (#040605), algo mas calido para la piedra y la madera.
CONTORNO = "#0b0809"


# --- Color ------------------------------------------------------------------

def rgb(color):
    color = color.lstrip("#")
    return tuple(int(color[i:i + 2], 16) for i in (0, 2, 4))


def hexa(c):
    return "#%02x%02x%02x" % tuple(max(0, min(255, int(round(v)))) for v in c)


def mezclar(a, b, t):
    ca, cb = rgb(a), rgb(b)
    return hexa([ca[i] + (cb[i] - ca[i]) * t for i in range(3)])


def aclarar(c, t):
    return mezclar(c, "#ffffff", t)


def oscurecer(c, t):
    return mezclar(c, "#000000", t)


def luz(c):
    """Luminosidad (0-1), la misma cuenta que generar_rocas.luz_suelo."""
    r, g, b = rgb(c)
    return (0.299 * r + 0.587 * g + 0.114 * b) / 255.0


def f(x):
    return "%.2f" % x


# --- Lienzo -----------------------------------------------------------------

class Lienzo:
    """Un SVG de w x h unidades (los pixeles de la textura final)."""

    def __init__(self, w, h):
        self.w = w
        self.h = h
        self.defs = []
        self.cuerpo = []
        self._n = 0

    def nuevo_id(self, base):
        self._n += 1
        return "%s%d" % (base, self._n)

    def add(self, *partes):
        self.cuerpo.extend(partes)

    # Degradados: 'paradas' es una lista de (posicion, color) o (posicion, color, opacidad).
    def lineal(self, paradas, x1=0.0, y1=0.0, x2=0.0, y2=1.0, espacio=None):
        i = self.nuevo_id("l")
        unidades = ' gradientUnits="userSpaceOnUse"' if espacio else ""
        texto = "".join('<stop offset="%s" stop-color="%s" stop-opacity="%s"/>' % (
            f(p[0]), p[1], f(p[2] if len(p) > 2 else 1.0)) for p in paradas)
        self.defs.append('<linearGradient id="%s" x1="%s" y1="%s" x2="%s" y2="%s"%s>%s</linearGradient>' % (
            i, f(x1), f(y1), f(x2), f(y2), unidades, texto))
        return "url(#%s)" % i

    def radial(self, paradas, cx=0.5, cy=0.5, r=0.5, fx=None, fy=None, espacio=None):
        i = self.nuevo_id("r")
        foco = ' fx="%s" fy="%s"' % (f(fx), f(fy)) if fx is not None else ""
        unidades = ' gradientUnits="userSpaceOnUse"' if espacio else ""
        texto = "".join('<stop offset="%s" stop-color="%s" stop-opacity="%s"/>' % (
            f(p[0]), p[1], f(p[2] if len(p) > 2 else 1.0)) for p in paradas)
        self.defs.append('<radialGradient id="%s" cx="%s" cy="%s" r="%s"%s%s>%s</radialGradient>' % (
            i, f(cx), f(cy), f(r), foco, unidades, texto))
        return "url(#%s)" % i

    def difuso(self, radio):
        i = self.nuevo_id("d")
        self.defs.append('<filter id="%s" x="-60%%" y="-60%%" width="220%%" height="220%%">'
                         '<feGaussianBlur stdDeviation="%s"/></filter>' % (i, f(radio)))
        return "url(#%s)" % i

    def recorte(self, dentro):
        """Un clipPath con lo que se pase (SVG). Devuelve 'url(#..)'."""
        i = self.nuevo_id("c")
        self.defs.append('<clipPath id="%s">%s</clipPath>' % (i, dentro))
        return "url(#%s)" % i

    # Formas
    def forma(self, d, relleno, trazo=CONTORNO, ancho=3.0, extra=""):
        t = ' stroke="%s" stroke-width="%s" stroke-linejoin="round" stroke-linecap="round"' % (
            trazo, f(ancho)) if trazo else ""
        self.add('<path d="%s" fill="%s"%s %s/>' % (d, relleno, t, extra))

    def linea(self, d, color, ancho, opacidad=1.0, extra=""):
        self.add('<path d="%s" fill="none" stroke="%s" stroke-width="%s" stroke-linecap="round" '
                 'stroke-linejoin="round" opacity="%s" %s/>' % (d, color, f(ancho), f(opacidad), extra))

    def elipse(self, cx, cy, rx, ry, relleno, trazo=CONTORNO, ancho=3.0, extra=""):
        t = ' stroke="%s" stroke-width="%s"' % (trazo, f(ancho)) if trazo else ""
        self.add('<ellipse cx="%s" cy="%s" rx="%s" ry="%s" fill="%s"%s %s/>' % (
            f(cx), f(cy), f(rx), f(ry), relleno, t, extra))

    def rect(self, x, y, w, h, relleno, trazo=CONTORNO, ancho=3.0, r=0.0, extra=""):
        t = ' stroke="%s" stroke-width="%s" stroke-linejoin="round"' % (trazo, f(ancho)) if trazo else ""
        self.add('<rect x="%s" y="%s" width="%s" height="%s" rx="%s" fill="%s"%s %s/>' % (
            f(x), f(y), f(w), f(h), f(r), relleno, t, extra))

    # Pintar
    def svg(self, w_px=None, h_px=None, vista=None):
        w_px = w_px or self.w
        h_px = h_px or self.h
        x, y, w, h = vista or (0, 0, self.w, self.h)
        return ('<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" '
                'width="%d" height="%d" viewBox="%s %s %s %s"><defs>%s</defs>%s</svg>' % (
                    w_px, h_px, f(x), f(y), f(w), f(h), "".join(self.defs), "".join(self.cuerpo)))

    def imagen(self, escala=2):
        """La imagen de w x h, pintada a 'escala' veces y reducida."""
        grande = _pintar_svg(self.svg(self.w * escala, self.h * escala))
        return grande.convert("RGBa").resize((self.w, self.h), Image.LANCZOS).convert("RGBA")

    def mosaico(self, escala=2, margen=32):
        """La imagen como baldosa que se repite sin costuras: lo dibujado se
        repite en las ocho de alrededor (lo que se sale por un lado entra por
        el otro), se pinta con un margen y se recorta, para que el filtro al
        reducir no deje raya en el borde."""
        cuerpo = "".join(self.cuerpo)
        self.cuerpo = ['<g id="baldosa">%s</g>' % cuerpo]
        for dx in (-self.w, 0, self.w):
            for dy in (-self.h, 0, self.h):
                if dx or dy:
                    self.cuerpo.append('<use xlink:href="#baldosa" x="%d" y="%d"/>' % (dx, dy))
        w, h = self.w + margen * 2, self.h + margen * 2
        grande = _pintar_svg(self.svg(w * escala, h * escala, (-margen, -margen, w, h)))
        grande = grande.convert("RGBa").resize((w, h), Image.LANCZOS).convert("RGBA")
        return grande.crop((margen, margen, margen + self.w, margen + self.h))


def _pintar_svg(texto):
    with tempfile.TemporaryDirectory() as carpeta:
        ruta = os.path.join(carpeta, "pieza")
        with open(ruta + ".svg", "w", encoding="utf-8") as archivo:
            archivo.write(texto)
        subprocess.run(["rsvg-convert", ruta + ".svg", "-o", ruta + ".png"], check=True)
        return Image.open(ruta + ".png").convert("RGBA").copy()


# --- Geometria ----------------------------------------------------------------

def poligono(puntos):
    return "M " + " L ".join("%s %s" % (f(x), f(y)) for x, y in puntos) + " Z"


def redondeado(puntos, radio):
    """Un poligono con las esquinas redondeadas (curvas por los puntos medios)."""
    n = len(puntos)
    d = []
    for i in range(n):
        a = puntos[i - 1]
        b = puntos[i]
        c = puntos[(i + 1) % n]
        la = math.hypot(b[0] - a[0], b[1] - a[1]) or 1.0
        lc = math.hypot(c[0] - b[0], c[1] - b[1]) or 1.0
        ra = min(radio, la * 0.45)
        rc = min(radio, lc * 0.45)
        p1 = (b[0] + (a[0] - b[0]) * ra / la, b[1] + (a[1] - b[1]) * ra / la)
        p2 = (b[0] + (c[0] - b[0]) * rc / lc, b[1] + (c[1] - b[1]) * rc / lc)
        d.append(("M" if i == 0 else "L") + " %s %s Q %s %s %s %s" % (
            f(p1[0]), f(p1[1]), f(b[0]), f(b[1]), f(p2[0]), f(p2[1])))
    return " ".join(d) + " Z"


def piedra_irregular(azar, cx, cy, rx, ry, lados=8, rugosidad=0.18):
    """Un contorno de piedra redondeada alrededor de (cx, cy)."""
    puntos = []
    giro = azar.uniform(0, math.tau)
    for k in range(lados):
        a = giro + k * math.tau / lados
        m = 1.0 + azar.uniform(-rugosidad, rugosidad)
        puntos.append((cx + math.cos(a) * rx * m, cy + math.sin(a) * ry * m))
    return redondeado(puntos, min(rx, ry) * 0.45)


# --- Piezas que se repiten ------------------------------------------------------

def llama(L, cx, base, alto, colores=("#fff4c0", "#ffc23a", "#ff6a1a", "#c0200a"), resplandor=True):
    """Una llama de pie con la base en (cx, base)."""
    ancho = alto * 0.52
    if resplandor:
        L.elipse(cx, base - alto * 0.45, alto * 0.95, alto * 0.8, L.radial([
            (0.0, colores[1], 0.55), (0.5, colores[2], 0.2), (1.0, colores[2], 0.0)]), trazo=None)
    fuera = ("M %s %s C %s %s %s %s %s %s C %s %s %s %s %s %s Z" % (
        f(cx), f(base), f(cx - ancho * 0.75), f(base - alto * 0.05), f(cx - ancho * 0.55), f(base - alto * 0.55),
        f(cx + ancho * 0.05), f(base - alto), f(cx + ancho * 0.25), f(base - alto * 0.6),
        f(cx + ancho * 0.8), f(base - alto * 0.2), f(cx), f(base)))
    L.forma(fuera, L.lineal([(0, colores[0]), (0.45, colores[1]), (1, colores[2])], 0, 1, 0, 0),
            trazo=colores[3], ancho=max(1.2, alto * 0.05))
    dentro = ("M %s %s C %s %s %s %s %s %s C %s %s %s %s %s %s Z" % (
        f(cx), f(base - alto * 0.06), f(cx - ancho * 0.35), f(base - alto * 0.1), f(cx - ancho * 0.25),
        f(base - alto * 0.42), f(cx + ancho * 0.02), f(base - alto * 0.62), f(cx + ancho * 0.12),
        f(base - alto * 0.38), f(cx + ancho * 0.4), f(base - alto * 0.15), f(cx), f(base - alto * 0.06)))
    L.forma(dentro, colores[0], trazo=None)


def antorcha(L, cx, cy, alto, madera="#6a4428", hierro="#3c3a40", fuego=None):
    """Una antorcha en su soporte de pared, con el soporte en (cx, cy)."""
    palo = alto * 0.55
    L.forma(poligono([(cx - alto * 0.07, cy - palo * 0.15), (cx + alto * 0.07, cy - palo * 0.15),
                      (cx + alto * 0.04, cy + palo * 0.85), (cx - alto * 0.04, cy + palo * 0.85)]),
            L.lineal([(0, aclarar(madera, 0.2)), (1, oscurecer(madera, 0.3))], 0, 0, 1, 0), ancho=2.2)
    L.forma(poligono([(cx - alto * 0.13, cy - palo * 0.22), (cx + alto * 0.13, cy - palo * 0.22),
                      (cx + alto * 0.09, cy - palo * 0.02), (cx - alto * 0.09, cy - palo * 0.02)]),
            hierro, ancho=2.0)
    L.rect(cx - alto * 0.16, cy + palo * 0.35, alto * 0.32, alto * 0.08, hierro, ancho=2.0, r=2)
    if fuego:
        llama(L, cx, cy - palo * 0.2, alto * 0.5, fuego)
    else:
        llama(L, cx, cy - palo * 0.2, alto * 0.5)


def cadena(L, x0, y0, x1, y1, eslabon=7.0, color="#55555e", ancho=2.0):
    """Una cadena de (x0, y0) a (x1, y1): eslabones alternos de frente y de canto."""
    largo = math.hypot(x1 - x0, y1 - y0)
    n = max(1, int(largo / (eslabon * 0.8)))
    ang = math.degrees(math.atan2(y1 - y0, x1 - x0))
    for k in range(n):
        t = (k + 0.5) / n
        x = x0 + (x1 - x0) * t
        y = y0 + (y1 - y0) * t
        if k % 2 == 0:
            L.add('<ellipse cx="%s" cy="%s" rx="%s" ry="%s" fill="none" stroke="%s" stroke-width="%s" '
                  'transform="rotate(%s %s %s)"/>' % (f(x), f(y), f(eslabon * 0.6), f(eslabon * 0.36),
                                                    CONTORNO, f(ancho + 2.0), f(ang), f(x), f(y)))
            L.add('<ellipse cx="%s" cy="%s" rx="%s" ry="%s" fill="none" stroke="%s" stroke-width="%s" '
                  'transform="rotate(%s %s %s)"/>' % (f(x), f(y), f(eslabon * 0.6), f(eslabon * 0.36),
                                                    color, f(ancho), f(ang), f(x), f(y)))
        else:
            L.add('<line x1="%s" y1="%s" x2="%s" y2="%s" stroke="%s" stroke-width="%s" stroke-linecap="round" '
                  'transform="rotate(%s %s %s)"/>' % (f(x - eslabon * 0.55), f(y), f(x + eslabon * 0.55), f(y),
                                                    CONTORNO, f(ancho + 2.4), f(ang), f(x), f(y)))
            L.add('<line x1="%s" y1="%s" x2="%s" y2="%s" stroke="%s" stroke-width="%s" stroke-linecap="round" '
                  'transform="rotate(%s %s %s)"/>' % (f(x - eslabon * 0.5), f(y), f(x + eslabon * 0.5), f(y),
                                                    aclarar(color, 0.25), f(ancho * 0.8), f(ang), f(x), f(y)))


def vela(L, cx, base, alto, cera="#e8dcc0", fuego=None, ancho=None):
    """Una vela de pie, encendida, con la base en (cx, base)."""
    ancho = ancho or alto * 0.32
    cuerpo = alto * 0.62
    L.rect(cx - ancho * 0.5, base - cuerpo, ancho, cuerpo,
           L.lineal([(0, aclarar(cera, 0.25)), (0.6, cera), (1, oscurecer(cera, 0.25))], 0, 0, 1, 0),
           ancho=2.0, r=ancho * 0.2)
    # Cera derretida por el borde.
    L.forma("M %s %s q %s %s %s %s q %s %s %s %s" % (
        f(cx - ancho * 0.5), f(base - cuerpo + ancho * 0.1), f(ancho * 0.1), f(ancho * 0.7),
        f(ancho * 0.25), f(ancho * 0.25), f(ancho * 0.1), f(-ancho * 0.6), f(ancho * 0.3), f(-ancho * 0.25)),
        aclarar(cera, 0.35), trazo=None)
    L.linea("M %s %s L %s %s" % (f(cx), f(base - cuerpo), f(cx), f(base - cuerpo - alto * 0.06)), CONTORNO, 1.6)
    llama(L, cx, base - cuerpo - alto * 0.04, alto * 0.36, fuego or ("#fffbe0", "#ffd25a", "#ff8a2a", "#a83a0a"))


def calavera(L, cx, cy, r, hueso="#e6dcc0", vacio="#1a1014"):
    """Una calavera de frente centrada en (cx, cy), de radio r."""
    craneo = ("M %s %s C %s %s %s %s %s %s C %s %s %s %s %s %s L %s %s L %s %s Z" % (
        f(cx - r), f(cy + r * 0.15), f(cx - r * 1.05), f(cy - r * 1.1), f(cx + r * 1.05), f(cy - r * 1.1),
        f(cx + r), f(cy + r * 0.15), f(cx + r * 0.95), f(cy + r * 0.5), f(cx + r * 0.6), f(cy + r * 0.55),
        f(cx + r * 0.55), f(cy + r * 0.85), f(cx + r * 0.55), f(cy + r * 0.95), f(cx - r * 0.55), f(cy + r * 0.95)))
    L.forma(craneo + " M %s %s C %s %s %s %s %s %s Z" % (
        f(cx - r * 0.55), f(cy + r * 0.95), f(cx - r * 0.6), f(cy + r * 0.55), f(cx - r * 0.95), f(cy + r * 0.5),
        f(cx - r), f(cy + r * 0.15)),
        L.radial([(0, aclarar(hueso, 0.3)), (0.7, hueso), (1, oscurecer(hueso, 0.25))], 0.4, 0.3, 0.8),
        ancho=max(1.6, r * 0.12))
    for s in (-1, 1):
        L.elipse(cx + s * r * 0.38, cy + r * 0.05, r * 0.26, r * 0.3, vacio, trazo=None)
    L.forma(poligono([(cx, cy + r * 0.35), (cx - r * 0.12, cy + r * 0.58), (cx + r * 0.12, cy + r * 0.58)]),
            vacio, trazo=None)
    for k in range(3):
        x = cx + (k - 1) * r * 0.22
        L.linea("M %s %s L %s %s" % (f(x), f(cy + r * 0.72), f(x), f(cy + r * 0.92)), vacio, max(1.0, r * 0.08))


def hueso(L, x0, y0, x1, y1, grosor, color="#e2d6b8"):
    """Un hueso largo de (x0, y0) a (x1, y1)."""
    ang = math.atan2(y1 - y0, x1 - x0)
    nx, ny = -math.sin(ang) * grosor * 0.5, math.cos(ang) * grosor * 0.5
    L.forma(poligono([(x0 + nx, y0 + ny), (x1 + nx, y1 + ny), (x1 - nx, y1 - ny), (x0 - nx, y0 - ny)]),
            color, ancho=2.0)
    for x, y in ((x0, y0), (x1, y1)):
        for s in (-1, 1):
            L.elipse(x + nx * s * 0.9, y + ny * s * 0.9, grosor * 0.55, grosor * 0.55, color, ancho=2.0)
    L.forma(poligono([(x0 + nx * 0.8, y0 + ny * 0.8), (x1 + nx * 0.8, y1 + ny * 0.8),
                      (x1 - nx * 0.8, y1 - ny * 0.8), (x0 - nx * 0.8, y0 - ny * 0.8)]), color, trazo=None)


def destello(L, cx, cy, tam, color="#ffffff", opacidad=0.9):
    """Una estrella de cuatro puntas, para lo que brilla."""
    fino = tam * 0.22
    L.forma(poligono([(cx, cy - tam), (cx + fino, cy - fino), (cx + tam, cy), (cx + fino, cy + fino),
                      (cx, cy + tam), (cx - fino, cy + fino), (cx - tam, cy), (cx - fino, cy - fino)]),
            color, trazo=None, extra='opacity="%s"' % f(opacidad))


def sombra_suelo(L, cx, cy, rx, ry, fuerza=0.45):
    """La sombra de algo de pie sobre el suelo: una elipse que se apaga."""
    L.elipse(cx, cy, rx, ry, L.radial([(0, "#000000", fuerza), (0.7, "#000000", fuerza * 0.6),
                                       (1, "#000000", 0.0)]), trazo=None)
