# -*- coding: utf-8 -*-
"""Dibuja la carga de la ulti del mago oscuro: lo que se forma delante de el
mientras se mantiene el boton, antes de soltar el agujero negro.

Pedido por Matias el 2026-11-09 («un asset del mago oscuro para cuando carga
la ulti»). El paquete de los magos (vacio_magos_y_hechizos.zip) solo traia la
carga del mago rojo (ultimate_carga, el sol que crece); la del oscuro se
pintaba por codigo, con una bola de luz lila (CargaAtaque._draw).

POR QUE ASI: es el mismo hechizo que sale al soltar, asi que se dibuja con lo
del agujero negro del paquete (agujero_abrir/bucle): nucleo negro con el borde
lila, un arco de luz por encima y un disco morado inclinado que le pasa por
delante. Empieza como la chispa de agujero_abrir y va tragando: hilos de
energia que se enroscan hacia el centro y motas que caen. En la ultima pose
ya es el agujero entero, con destellos y un resplandor, para que se lea «lista».

POR QUE 8 POSES Y COMO LA DEL ROJO: CargaAtaque elige la pose por lo cargado
(no por el reloj), asi que la hoja tiene que ir de vacia a llena en orden. Con
la misma medida (256 px, 4 x 2) que la del rojo, generar_magos.py la reduce
igual (0,42) y cabe dentro del arco que pinta CargaAtaque (radio 40).

Lo que sale: assets/magos_fuente/hechizos/vacio/agujero_carga.png, junto a las
hojas del paquete, para que generar_magos.py la trate como una mas. No es del
paquete: sale de aqui.

Necesita rsvg-convert, como generar_cofre.py.

    python herramientas/generar_carga_vacio.py
    python herramientas/generar_magos.py
"""
import math
import os
import random
import shutil
import subprocess
import sys
import tempfile

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from generar_magos import reducir  # noqa: E402

RAIZ = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SALIDA = os.path.join(RAIZ, "assets", "magos_fuente", "hechizos", "vacio", "agujero_carga.png")

LADO = 256          # cada pose de la hoja, como ultimate_carga del rojo
COLUMNAS = 4
POSES = 8
C = LADO / 2.0      # el centro de la pose: ahi va el centro del agujero (desfase 0)

# Los colores del agujero negro del paquete (medidos en agujero_orbe_vuelo y
# agujero_bucle): negro, morados y lila casi blanco, con un trazo muy oscuro.
NEGRO = "#05000c"
BORDE_NUCLEO = "#16052c"
MORADO_OSCURO = "#2a0a50"
MORADO = "#4a1290"
VIOLETA = "#8030e0"
LILA = "#c890f0"
LILA_CLARO = "#f0e0ff"
TRAZO = "#0a0018"

# Cada pose, de vacia (0) a cargada (7). Radios en px de la pose.
NUCLEO = [0, 5, 12, 18, 24, 30, 35, 40]          # lo negro
DISCO = [0, 0, 0, 44, 58, 70, 82, 92]            # el disco, de lado a lado / 2
CHISPA = [13, 17, 21, 0, 0, 0, 0, 0]             # la chispa del principio
HALO = [44, 56, 66, 76, 86, 96, 104, 112]
HALO_OPACIDAD = [0.30, 0.34, 0.38, 0.42, 0.46, 0.50, 0.54, 0.60]
HILOS_OPACIDAD = [0.55, 0.75, 0.90, 0.95, 0.90, 0.80, 0.68, 0.58]
HILOS_ANCHO = [7, 9, 10, 11, 11, 10, 9, 8]
# Por donde empiezan los hilos: al final ya queda poco que tragar, y el agujero
# tiene que mandar en el dibujo.
HILOS_FUERA = [118, 118, 118, 116, 112, 108, 104, 100]
GIRO_POSE = 24.0    # grados que avanza el remolino de una pose a la siguiente
INCLINACION = 0.36  # lo que se aplasta el disco (lo mismo que en agujero_bucle)
APLASTADO = 0.80    # los hilos y las motas, algo menos: vienen de todas partes

HILOS = 6
MOTAS = 16


def f(x):
    return "%.2f" % x


def suave(t):
    return t * t * (3.0 - 2.0 * t)


# --- Piezas ------------------------------------------------------------------

def definiciones():
    return f"""
<defs>
  <filter id="difuso" x="-50%" y="-50%" width="200%" height="200%">
    <feGaussianBlur stdDeviation="4"/>
  </filter>
  <filter id="muy_difuso" x="-50%" y="-50%" width="200%" height="200%">
    <feGaussianBlur stdDeviation="9"/>
  </filter>
  <radialGradient id="halo">
    <stop offset="0" stop-color="{VIOLETA}" stop-opacity="1"/>
    <stop offset="0.45" stop-color="{MORADO}" stop-opacity="0.55"/>
    <stop offset="1" stop-color="{MORADO_OSCURO}" stop-opacity="0"/>
  </radialGradient>
  <radialGradient id="chispa">
    <stop offset="0" stop-color="#ffffff"/>
    <stop offset="0.35" stop-color="{LILA_CLARO}"/>
    <stop offset="0.7" stop-color="{LILA}" stop-opacity="0.8"/>
    <stop offset="1" stop-color="{VIOLETA}" stop-opacity="0"/>
  </radialGradient>
  <radialGradient id="nucleo">
    <stop offset="0" stop-color="#000000"/>
    <stop offset="0.75" stop-color="{NEGRO}"/>
    <stop offset="1" stop-color="{BORDE_NUCLEO}"/>
  </radialGradient>
  <radialGradient id="disco">
    <stop offset="0" stop-color="{LILA_CLARO}"/>
    <stop offset="0.45" stop-color="{LILA}"/>
    <stop offset="0.68" stop-color="{VIOLETA}"/>
    <stop offset="0.88" stop-color="{MORADO}"/>
    <stop offset="1" stop-color="{MORADO_OSCURO}"/>
  </radialGradient>
  <clipPath id="delante">
    <rect x="0" y="{f(C)}" width="{LADO}" height="{f(C)}"/>
  </clipPath>
</defs>"""


def halo(k):
    return (f'<circle cx="{f(C)}" cy="{f(C)}" r="{f(HALO[k])}" fill="url(#halo)" '
            f'opacity="{f(HALO_OPACIDAD[k])}"/>')


def hilo(k, i):
    """Un hilo de energia que se enrosca hacia el centro: ancho en medio,
    en punta por fuera, y que se funde con el nucleo por dentro."""
    fase = math.radians(i * 360.0 / HILOS + k * GIRO_POSE)
    vuelta = math.radians(120.0)
    r_fuera = HILOS_FUERA[k]
    r_dentro = max(NUCLEO[k], CHISPA[k] * 0.6, 6.0) * 1.05
    ancho = HILOS_ANCHO[k]
    centro, normales = [], []
    pasos = 28
    for p in range(pasos + 1):
        s = p / pasos
        angulo = fase + vuelta * s
        r = r_fuera + (r_dentro - r_fuera) * (s ** 0.75)
        centro.append((C + math.cos(angulo) * r, C + math.sin(angulo) * r * APLASTADO))
    for p in range(pasos + 1):
        a = centro[max(p - 1, 0)]
        b = centro[min(p + 1, pasos)]
        dx, dy = b[0] - a[0], b[1] - a[1]
        largo = math.hypot(dx, dy) or 1.0
        normales.append((-dy / largo, dx / largo))
    izquierda, derecha = [], []
    for p in range(pasos + 1):
        s = p / pasos
        w = ancho * math.sin(math.pi * s * 0.86) * 0.5
        (x, y), (nx, ny) = centro[p], normales[p]
        izquierda.append((x + nx * w, y + ny * w))
        derecha.append((x - nx * w, y - ny * w))
    puntos = izquierda + derecha[::-1]
    d = "M " + " L ".join(f"{f(x)} {f(y)}" for x, y in puntos) + " Z"
    x0, y0 = centro[0]
    x1, y1 = centro[-1]
    gid = f"hilo_{i}"
    degradado = (f'<linearGradient id="{gid}" gradientUnits="userSpaceOnUse" '
                 f'x1="{f(x0)}" y1="{f(y0)}" x2="{f(x1)}" y2="{f(y1)}">'
                 f'<stop offset="0" stop-color="{MORADO}" stop-opacity="0"/>'
                 f'<stop offset="0.35" stop-color="{VIOLETA}" stop-opacity="0.9"/>'
                 f'<stop offset="0.8" stop-color="{LILA}"/>'
                 f'<stop offset="1" stop-color="{LILA_CLARO}"/></linearGradient>')
    op = HILOS_OPACIDAD[k]
    return (degradado
            + f'<path d="{d}" fill="{VIOLETA}" opacity="{f(op * 0.5)}" filter="url(#difuso)"/>'
            + f'<path d="{d}" fill="url(#{gid})" stroke="{TRAZO}" stroke-opacity="0.55" '
              f'stroke-width="1.6" stroke-linejoin="round" opacity="{f(op)}"/>')


def motas(k):
    """Motas que caen hacia el agujero, cada una con su rastro hacia fuera.
    La misma semilla en todas las poses: de una a otra se ven bajar."""
    azar = random.Random(11)
    piezas = []
    for _ in range(MOTAS):
        angulo0 = azar.uniform(0, math.tau)
        r0 = azar.uniform(70, 124)
        velocidad = azar.uniform(9, 15)
        tam = azar.uniform(1.6, 3.2)
        r = r0 - velocidad * k
        dentro = max(NUCLEO[k], 8) + 6
        if r < dentro:
            r += 124 - dentro
        angulo = angulo0 + math.radians(GIRO_POSE * 0.8 * k) + (124 - r) / 160.0
        x = C + math.cos(angulo) * r
        y = C + math.sin(angulo) * r * APLASTADO
        # La estela, una gota que se afila hacia donde venia: con una linea y un
        # punto parecia un alfiler.
        cola = 12 + tam * 4
        xa = C + math.cos(angulo - 0.14) * (r + cola)
        ya = C + math.sin(angulo - 0.14) * (r + cola) * APLASTADO
        dx, dy = x - xa, y - ya
        largo = math.hypot(dx, dy) or 1.0
        nx, ny = -dy / largo * tam, dx / largo * tam
        gota = (f"M {f(xa)} {f(ya)} L {f(x + nx)} {f(y + ny)} "
                f"A {f(tam)} {f(tam)} 0 0 1 {f(x - nx)} {f(y - ny)} Z")
        brillo = 0.55 + 0.45 * (1.0 - (r - dentro) / 124.0)
        piezas.append(f'<circle cx="{f(x)}" cy="{f(y)}" r="{f(tam * 2.6)}" fill="{VIOLETA}" '
                      f'opacity="{f(brillo * 0.5)}" filter="url(#difuso)"/>')
        piezas.append(f'<path d="{gota}" fill="{LILA}" opacity="{f(brillo * 0.55)}"/>')
        piezas.append(f'<circle cx="{f(x)}" cy="{f(y)}" r="{f(tam)}" fill="{LILA_CLARO}" '
                      f'opacity="{f(brillo)}"/>')
    return "".join(piezas)


def anillo(r, inclinacion):
    """El disco: una elipse con agujero (dos elipses con evenodd)."""
    rd, ry = r, r * inclinacion
    rin = rd * 0.42
    return (f"M {f(C - rd)} {f(C)} A {f(rd)} {f(ry)} 0 1 0 {f(C + rd)} {f(C)} "
            f"A {f(rd)} {f(ry)} 0 1 0 {f(C - rd)} {f(C)} Z "
            f"M {f(C - rin)} {f(C)} A {f(rin)} {f(rin * inclinacion)} 0 1 0 {f(C + rin)} {f(C)} "
            f"A {f(rin)} {f(rin * inclinacion)} 0 1 0 {f(C - rin)} {f(C)} Z")


def disco(k, recorte=""):
    r = DISCO[k]
    if r <= 0:
        return ""
    clip = f' clip-path="url(#{recorte})"' if recorte else ""
    partes = [f'<g{clip}>']
    partes.append(f'<path d="{anillo(r * 1.08, INCLINACION)}" fill="{VIOLETA}" fill-rule="evenodd" '
                  f'opacity="0.5" filter="url(#difuso)"/>')
    partes.append(f'<path d="{anillo(r, INCLINACION)}" fill="url(#disco)" fill-rule="evenodd" '
                  f'stroke="{TRAZO}" stroke-width="2.4"/>')
    # Rayas que giran por el disco: arcos de elipse con trazo a trozos, que se
    # corren un poco en cada pose (el disco da vueltas mientras carga).
    for j, (fr, ancho, color, op) in enumerate([
            (0.86, 2.6, LILA, 0.75), (0.74, 3.2, LILA_CLARO, 0.8),
            (0.62, 2.4, LILA, 0.7), (0.52, 2.0, LILA_CLARO, 0.85)]):
        rx, ry = r * fr, r * fr * INCLINACION
        perimetro = math.pi * (3 * (rx + ry) - math.sqrt((3 * rx + ry) * (rx + 3 * ry)))
        trozo = perimetro / (5 + j)
        desplazar = -(k * 0.18 + j * 0.31) * perimetro
        partes.append(f'<ellipse cx="{f(C)}" cy="{f(C)}" rx="{f(rx)}" ry="{f(ry)}" fill="none" '
                      f'stroke="{color}" stroke-width="{f(ancho)}" stroke-linecap="round" '
                      f'stroke-dasharray="{f(trozo * 0.55)} {f(trozo * 0.45)}" '
                      f'stroke-dashoffset="{f(desplazar)}" opacity="{f(op)}"/>')
    partes.append("</g>")
    return "".join(partes)


def aros_de_fuera(k):
    """Los aros finos de fuera de agujero_bucle, desde que el disco es grande."""
    if DISCO[k] < 70:
        return ""
    r = DISCO[k] * 1.22
    op = 0.25 + 0.1 * (k - 5)
    return (f'<ellipse cx="{f(C)}" cy="{f(C)}" rx="{f(r)}" ry="{f(r * INCLINACION)}" fill="none" '
            f'stroke="{VIOLETA}" stroke-width="1.6" opacity="{f(op)}"/>')


def chispa(k):
    r = CHISPA[k]
    if r <= 0:
        return ""
    # Una estrella de cuatro puntas encima de la bola de luz, como el arranque
    # de agujero_abrir.
    largo, fino = r * 2.4, r * 0.28
    estrella = (f"M {f(C)} {f(C - largo)} L {f(C + fino)} {f(C - fino)} L {f(C + largo)} {f(C)} "
                f"L {f(C + fino)} {f(C + fino)} L {f(C)} {f(C + largo)} L {f(C - fino)} {f(C + fino)} "
                f"L {f(C - largo)} {f(C)} L {f(C - fino)} {f(C - fino)} Z")
    return (f'<circle cx="{f(C)}" cy="{f(C)}" r="{f(r * 1.8)}" fill="url(#chispa)" opacity="0.65"/>'
            f'<circle cx="{f(C)}" cy="{f(C)}" r="{f(r)}" fill="url(#chispa)"/>'
            f'<path d="{estrella}" fill="{LILA_CLARO}" opacity="0.85"/>')


def rayos(k):
    """Dos rayitos en zigzag al abrirse, como en agujero_abrir."""
    if k not in (1, 2, 3):
        return ""
    azar = random.Random(30 + k)
    piezas = []
    for lado in (-1, 1):
        x, y = C + lado * (NUCLEO[k] + 10), C - 4
        puntos = [(x, y)]
        for _ in range(4):
            x += lado * azar.uniform(5, 9)
            y += azar.uniform(-9, 9)
            puntos.append((x, y))
        d = "M " + " L ".join(f"{f(a)} {f(b)}" for a, b in puntos)
        op = {1: 0.9, 2: 0.75, 3: 0.45}[k]
        piezas.append(f'<path d="{d}" fill="none" stroke="{VIOLETA}" stroke-width="5" '
                      f'stroke-linejoin="round" opacity="{f(op * 0.6)}" filter="url(#difuso)"/>')
        piezas.append(f'<path d="{d}" fill="none" stroke="{LILA_CLARO}" stroke-width="2" '
                      f'stroke-linejoin="round" stroke-linecap="round" opacity="{f(op)}"/>')
    return "".join(piezas)


def nucleo(k):
    r = NUCLEO[k]
    if r <= 0:
        return ""
    t = (k - 1) / (POSES - 2)
    borde = 1.6 + 2.6 * t
    piezas = [
        # El brillo de detras: lo que dice que esto absorbe luz y no es un agujero
        # cualquiera.
        f'<circle cx="{f(C)}" cy="{f(C)}" r="{f(r * 1.25)}" fill="none" stroke="{VIOLETA}" '
        f'stroke-width="{f(r * 0.35)}" opacity="0.7" filter="url(#difuso)"/>',
        f'<circle cx="{f(C)}" cy="{f(C)}" r="{f(r)}" fill="url(#nucleo)" stroke="{TRAZO}" stroke-width="2.4"/>',
        f'<circle cx="{f(C)}" cy="{f(C)}" r="{f(r + borde * 0.3)}" fill="none" stroke="{LILA}" '
        f'stroke-width="{f(borde)}" opacity="{f(0.65 + 0.35 * t)}"/>',
    ]
    if r >= 12:
        # El arco de luz por encima (el disco de detras, doblado por el agujero).
        ra = r * 1.2
        a0, a1 = math.radians(196), math.radians(344)
        d = (f"M {f(C + math.cos(a0) * ra)} {f(C + math.sin(a0) * ra)} "
             f"A {f(ra)} {f(ra)} 0 0 1 {f(C + math.cos(a1) * ra)} {f(C + math.sin(a1) * ra)}")
        op = 0.35 + 0.65 * t
        piezas.append(f'<path d="{d}" fill="none" stroke="{LILA}" stroke-width="{f(3 + 4 * t)}" '
                      f'stroke-linecap="round" opacity="{f(op * 0.7)}" filter="url(#difuso)"/>')
        piezas.append(f'<path d="{d}" fill="none" stroke="{LILA_CLARO}" stroke-width="{f(1.8 + 1.6 * t)}" '
                      f'stroke-linecap="round" opacity="{f(op)}"/>')
        # Un brillo blanco arriba a la izquierda del borde, el del orbe que vuela.
        rb = r * 0.86
        b0, b1 = math.radians(205), math.radians(245)
        d = (f"M {f(C + math.cos(b0) * rb)} {f(C + math.sin(b0) * rb)} "
             f"A {f(rb)} {f(rb)} 0 0 1 {f(C + math.cos(b1) * rb)} {f(C + math.sin(b1) * rb)}")
        piezas.append(f'<path d="{d}" fill="none" stroke="#ffffff" stroke-width="{f(1.4 + 1.2 * t)}" '
                      f'stroke-linecap="round" opacity="0.7"/>')
    return "".join(piezas)


def lista(k):
    """Solo en la ultima pose: destellos y un resplandor blanco, la senal de
    «lista». Sin aro con borde: el que dice que ya esta lo pinta CargaAtaque
    encima (radio 40 en el juego), y con este saldrian dos."""
    if k != POSES - 1:
        return ""
    piezas = [f'<circle cx="{f(C)}" cy="{f(C)}" r="96" fill="none" stroke="{LILA_CLARO}" '
              f'stroke-width="10" opacity="0.30" filter="url(#muy_difuso)"/>']
    for angulo, distancia, tam in [(-58, 66, 9), (32, 74, 7), (148, 70, 8), (218, 60, 6)]:
        a = math.radians(angulo)
        x, y = C + math.cos(a) * distancia, C + math.sin(a) * distancia * APLASTADO
        fino = tam * 0.22
        d = (f"M {f(x)} {f(y - tam)} L {f(x + fino)} {f(y - fino)} L {f(x + tam)} {f(y)} "
             f"L {f(x + fino)} {f(y + fino)} L {f(x)} {f(y + tam)} L {f(x - fino)} {f(y + fino)} "
             f"L {f(x - tam)} {f(y)} L {f(x - fino)} {f(y - fino)} Z")
        piezas.append(f'<path d="{d}" fill="#ffffff" opacity="0.9"/>')
    return "".join(piezas)


def svg(k):
    hilos = "".join(hilo(k, i) for i in range(HILOS))
    capas = [
        definiciones(),
        halo(k),
        aros_de_fuera(k),
        hilos,
        motas(k),
        disco(k),                 # el disco entero, por detras del nucleo
        chispa(k),
        nucleo(k),
        disco(k, "delante"),      # y la mitad de delante, por encima
        rayos(k),
        lista(k),
    ]
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{LADO}" height="{LADO}" '
            f'viewBox="0 0 {LADO} {LADO}">' + "".join(capas) + "</svg>")


def main():
    if shutil.which("rsvg-convert") is None:
        sys.exit("Falta rsvg-convert (paquete librsvg2-bin)")
    filas = (POSES + COLUMNAS - 1) // COLUMNAS
    hoja = Image.new("RGBA", (LADO * COLUMNAS, LADO * filas))
    with tempfile.TemporaryDirectory() as carpeta:
        for k in range(POSES):
            ruta = os.path.join(carpeta, "pose_%d" % k)
            with open(ruta + ".svg", "w", encoding="utf-8") as archivo:
                archivo.write(svg(k))
            # Al doble y reducida: los trazos finos salen mas limpios.
            subprocess.run(["rsvg-convert", "-w", str(LADO * 2), "-h", str(LADO * 2),
                            ruta + ".svg", "-o", ruta + ".png"], check=True)
            pose = reducir(Image.open(ruta + ".png").convert("RGBA"), (LADO, LADO))
            hoja.alpha_composite(pose, ((k % COLUMNAS) * LADO, (k // COLUMNAS) * LADO))
    hoja.save(SALIDA)
    print("Listo:", os.path.relpath(SALIDA, RAIZ))


if __name__ == "__main__":
    main()
