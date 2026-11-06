# -*- coding: utf-8 -*-
"""Genera el cofre de la sala secreta: una tira con la tapa en cada momento de
abrirse, de cerrada a abierta del todo.

Pedido por Matias el 2026-11-05 («el cofre es muy basico»). Hasta entonces se
pintaba por codigo con rectangulos, y se abria de golpe: de un fotograma al
otro la tapa aparecia echada hacia atras.

Esta hecho en 3D sencillo y luego proyectado: una caja con una tapa abombada
que gira sobre la bisagra de atras, vista desde delante y arriba (ELEVACION) y
un poco girada (GIRO), para que se vea el costado y la curva de la tapa. Asi,
en cada fotograma la tapa esta de verdad donde tiene que estar: al levantarse
se ve cada vez menos su cara de fuera y, pasados los 38 grados, la de dentro; y
por la abertura, el tesoro.

Cada cara plana se dibuja en sus propias coordenadas (como si se mirara de
frente) y se lleva a su sitio con una matriz: la proyeccion es afin, asi que
una cara plana se queda plana y sus adornos (tablas, bandas, la cerradura) van
pegados a ella.

Lo que se mueve (el brillo que late, la luz que sale, las chispas y las monedas
que saltan) lo pinta el juego (scripts/cofre.gd).

Lo que sale: assets/cofre/cofre.png, una tira de casillas de LADO px, una por
cada angulo de ANGULOS. El suelo del cofre (su centro) queda en ORIGEN de cada
casilla, pasado a LADO: el juego lo pone en el sitio del nodo (Cofre.PIES).

Necesita rsvg-convert, como magos_vectorial.py.

    python herramientas/generar_cofre.py
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
DESTINO = os.path.join(RAIZ, "assets", "cofre")

# La tapa en cada casilla, en grados. 0 cerrada; luego se abre, se pasa un poco
# (114) y vuelve a donde se queda (106), como una tapa pesada de verdad.
ANGULOS = [0, 8, 22, 42, 64, 86, 104, 114, 106]
LADO = 192            # px de cada casilla en la tira
LIENZO = 256          # el SVG; se pinta al doble y se reduce, que sale mas fino
ORIGEN = (128.0, 192.0)   # donde va el centro del suelo, en el lienzo

# Medidas (en el lienzo): media anchura, media profundidad, alto de la caja, lo
# que sube la cupula de la tapa y el grueso de las paredes.
W, D, H, ALTO_TAPA, PARED = 70.0, 34.0, 54.0, 26.0, 6.0
ELEVACION = math.radians(38.0)
CZ, CY = math.cos(ELEVACION), math.sin(ELEVACION)
# Girado hacia la derecha: se ve el costado derecho y la curva de la tapa.
GIRO = math.radians(-24.0)
CG, SG = math.cos(GIRO), math.sin(GIRO)
# De donde viene la luz (izquierda, delante y arriba), ya girado como la camara.
_l = (-0.45, -0.55, 0.72)
LUZ = tuple(v / math.sqrt(sum(c * c for c in _l)) for v in _l)

TRAZO = "#140a06"
MADERA = ("#2a1408", "#6a3a1a", "#b8743a")
MADERA_DENTRO = ("#140803", "#3a200e", "#6a3e1e")
ORO = ("#5a3408", "#d8a030", "#fff2b0")
TIRAS = 18
BANDAS = ((-0.64, -0.5), (0.5, 0.64))   # las bandas de oro, en fracciones de W


def fp(p):
    return f"{p[0]:.1f},{p[1]:.1f}"


def girar(x, y, z):
    return x * CG - y * SG, x * SG + y * CG, z


def proyectar(p):
    """Un punto del cofre (x a la derecha, y hacia atras, z hacia arriba) en el lienzo."""
    x, y, z = girar(*p)
    return ORIGEN[0] + x, ORIGEN[1] - (z * CZ + y * CY)


def mira(n):
    """Cuanto mira a la camara una cara con normal n (positivo, se ve)."""
    x, y, z = girar(*n)
    largo = math.sqrt(x * x + y * y + z * z) or 1.0
    return (-y * CZ + z * CY) / largo


def luz(n):
    x, y, z = girar(*n)
    largo = math.sqrt(x * x + y * y + z * z) or 1.0
    return max(0.0, (x * LUZ[0] + y * LUZ[1] + z * LUZ[2]) / largo)


def mezclar(colores, t):
    t = min(max(t, 0.0), 1.0) * (len(colores) - 1)
    i = min(int(t), len(colores) - 2)
    k = t - i
    a = [int(colores[i][j:j + 2], 16) for j in (1, 3, 5)]
    b = [int(colores[i + 1][j:j + 2], 16) for j in (1, 3, 5)]
    return "#%02x%02x%02x" % tuple(round(a[n] + (b[n] - a[n]) * k) for n in range(3))


def poligono(puntos, relleno, ancho=2.5, trazo=TRAZO, extra=""):
    d = "M" + " L".join(fp(proyectar(p)) for p in puntos) + " Z"
    borde = f' stroke="{trazo}" stroke-width="{ancho}" stroke-linejoin="round"' if ancho else ""
    return f'<path d="{d}" fill="{relleno}"{borde}{extra}/>'


def en_cara(origen, eje_u, eje_v, contenido):
    """Lo de 'contenido', dibujado en coordenadas de una cara (u a lo ancho, v hacia
    abajo, en px del cofre), llevado a su sitio."""
    o = proyectar(origen)
    u = proyectar(tuple(origen[i] + eje_u[i] for i in range(3)))
    v = proyectar(tuple(origen[i] + eje_v[i] for i in range(3)))
    m = (u[0] - o[0], u[1] - o[1], v[0] - o[0], v[1] - o[1], o[0], o[1])
    return f'<g transform="matrix({" ".join(f"{c:.4f}" for c in m)})">{contenido}</g>'


def remache(x, y, r=2.6):
    return (f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{r}" fill="{ORO[1]}" stroke="{TRAZO}" stroke-width="1.3"/>'
            f'<circle cx="{x - r * .3:.1f}" cy="{y - r * .3:.1f}" r="{r * .35:.1f}" fill="#fff8d0"/>')


def degradados():
    return (f'<defs>'
            f'<linearGradient id="oroV" x1="0" x2="0" y1="0" y2="1"><stop offset="0" stop-color="{ORO[2]}"/>'
            f'<stop offset=".5" stop-color="{ORO[1]}"/><stop offset="1" stop-color="{ORO[0]}"/></linearGradient>'
            f'<linearGradient id="oroH" x1="0" x2="1"><stop offset="0" stop-color="{ORO[1]}"/>'
            f'<stop offset=".45" stop-color="{ORO[2]}"/><stop offset="1" stop-color="{ORO[0]}"/></linearGradient>'
            f'<radialGradient id="sombra"><stop offset="0" stop-color="#000" stop-opacity=".6"/>'
            f'<stop offset="1" stop-color="#000" stop-opacity="0"/></radialGradient>'
            f'</defs>')


# --------------------------------------------------------------- la caja ---
def frente():
    """La cara de delante, en sus coordenadas (u de 0 a 2W, v de 0 a H): tablas,
    veta, bandas y esquinas de oro, remaches y la cerradura."""
    n = (0.0, -1.0, 0.0)
    madera = mezclar(MADERA, 0.35 + 0.6 * luz(n))
    ancho, alto = 2 * W, H
    out = (f'<defs><linearGradient id="frente" x1="0" x2="0" y1="0" y2="1"><stop offset="0" stop-color="{madera}"/>'
           f'<stop offset="1" stop-color="{mezclar(MADERA, 0.15)}"/></linearGradient></defs>'
           f'<rect x="0" y="0" width="{ancho}" height="{alto}" fill="url(#frente)" stroke="{TRAZO}" stroke-width="3.2" stroke-linejoin="round"/>')
    for k in range(1, 6):
        x = k * ancho / 6
        out += f'<path d="M{x:.1f},2 L{x:.1f},{alto - 2}" stroke="{TRAZO}" stroke-width="1.5" opacity=".5"/>'
    azar = random.Random(7)
    for k in range(10):
        x, y = 6 + azar.random() * (ancho - 20), 6 + azar.random() * (alto - 16)
        out += f'<path d="M{x:.1f},{y:.1f} q4,-3 8,0 t8,0" fill="none" stroke="{MADERA[0]}" stroke-width="1.1" opacity=".55"/>'
    out += f'<rect x="0" y="{alto - 9}" width="{ancho}" height="9" fill="url(#oroV)" stroke="{TRAZO}" stroke-width="2.2"/>'
    for a, b in BANDAS:
        x0, x1 = W + a * W, W + b * W
        out += f'<rect x="{x0:.1f}" y="0" width="{x1 - x0:.1f}" height="{alto}" fill="url(#oroH)" stroke="{TRAZO}" stroke-width="2.2"/>'
        for y in (7, alto / 2, alto - 15):
            out += remache((x0 + x1) / 2, y)
    for x, lado in ((0, 1), (ancho, -1)):
        for y, sube in ((0, 1), (alto, -1)):
            out += (f'<path d="M{x},{y} L{x + lado * 18},{y} L{x + lado * 18},{y + sube * 5} L{x + lado * 5},{y + sube * 5} '
                    f'L{x + lado * 5},{y + sube * 18} L{x},{y + sube * 18} Z" fill="url(#oroV)" stroke="{TRAZO}" stroke-width="2" '
                    f'stroke-linejoin="round"/>')
    cx, y0 = W, 4
    out += (f'<path d="M{cx - 16},{y0} L{cx + 16},{y0} L{cx + 16},{y0 + 17} Q{cx + 16},{y0 + 29} {cx},{y0 + 35} '
            f'Q{cx - 16},{y0 + 29} {cx - 16},{y0 + 17} Z" fill="url(#oroV)" stroke="{TRAZO}" stroke-width="2.6" stroke-linejoin="round"/>'
            f'<path d="M{cx - 11},{y0 + 4} L{cx + 11},{y0 + 4} L{cx + 11},{y0 + 16} Q{cx + 11},{y0 + 25} {cx},{y0 + 29} '
            f'Q{cx - 11},{y0 + 25} {cx - 11},{y0 + 16} Z" fill="none" stroke="{ORO[0]}" stroke-width="1.3"/>'
            f'<circle cx="{cx}" cy="{y0 + 15}" r="7" fill="#ffcf5a" opacity=".45"/>'
            f'<circle cx="{cx}" cy="{y0 + 14}" r="3.6" fill="{TRAZO}"/>'
            f'<path d="M{cx - 2.4},{y0 + 15} L{cx + 2.4},{y0 + 15} L{cx + 1.4},{y0 + 23} L{cx - 1.4},{y0 + 23} Z" fill="{TRAZO}"/>'
            f'<circle cx="{cx}" cy="{y0 + 14}" r="1.4" fill="#ffe9a0"/>')
    return out


def costado():
    """El costado derecho (u de 0 a 2D, de delante a atras; v de 0 a H): mas oscuro,
    con sus esquinas, una banda y el asa."""
    n = (1.0, 0.0, 0.0)
    madera = mezclar(MADERA, 0.2 + 0.55 * luz(n))
    ancho, alto = 2 * D, H
    out = (f'<rect x="0" y="0" width="{ancho}" height="{alto}" fill="{madera}" stroke="{TRAZO}" stroke-width="3.2" stroke-linejoin="round"/>'
           f'<rect x="0" y="0" width="{ancho}" height="{alto}" fill="#000" opacity=".12"/>')
    for k in range(1, 3):
        x = k * ancho / 3
        out += f'<path d="M{x:.1f},2 L{x:.1f},{alto - 2}" stroke="{TRAZO}" stroke-width="1.5" opacity=".5"/>'
    out += f'<rect x="0" y="{alto - 9}" width="{ancho}" height="9" fill="{mezclar(ORO, 0.45)}" stroke="{TRAZO}" stroke-width="2.2"/>'
    for x, lado in ((0, 1), (ancho, -1)):
        for y, sube in ((0, 1), (alto, -1)):
            out += (f'<path d="M{x},{y} L{x + lado * 14},{y} L{x + lado * 14},{y + sube * 5} L{x + lado * 5},{y + sube * 5} '
                    f'L{x + lado * 5},{y + sube * 14} L{x},{y + sube * 14} Z" fill="{mezclar(ORO, 0.5)}" stroke="{TRAZO}" '
                    f'stroke-width="2" stroke-linejoin="round"/>')
    # El asa: una argolla de oro colgando de una placa.
    cx, cy = D, alto * 0.42
    out += (f'<rect x="{cx - 8}" y="{cy - 6}" width="16" height="10" rx="2" fill="{mezclar(ORO, 0.5)}" stroke="{TRAZO}" stroke-width="2"/>'
            f'<path d="M{cx - 9},{cy + 2} Q{cx - 10},{cy + 17} {cx},{cy + 17} Q{cx + 10},{cy + 17} {cx + 9},{cy + 2}" fill="none" '
            f'stroke="{TRAZO}" stroke-width="5.5" stroke-linecap="round"/>'
            f'<path d="M{cx - 9},{cy + 2} Q{cx - 10},{cy + 17} {cx},{cy + 17} Q{cx + 10},{cy + 17} {cx + 9},{cy + 2}" fill="none" '
            f'stroke="{mezclar(ORO, 0.65)}" stroke-width="2.8" stroke-linecap="round"/>')
    return out


def patas():
    out = ""
    for x, y in ((-W + 11, -D), (W - 11, -D), (W, D - 11)):
        base = [(x - 8, y, 0), (x + 8, y, 0), (x + 6, y, -7), (x - 6, y, -7)] if y == -D else \
               [(x, y - 8, 0), (x, y + 8, 0), (x, y + 6, -7), (x, y - 6, -7)]
        out += poligono(base, ORO[0], 2.2)
    return out


def caja():
    return (patas()
            + en_cara((-W, -D, H), (1, 0, 0), (0, 0, -1), frente())
            + en_cara((W, -D, H), (0, 1, 0), (0, 0, -1), costado()))


# ---------------------------------------------------------- por dentro ---
def tesoro():
    """Un monton de monedas con alguna joya, de atras hacia delante."""
    azar = random.Random(11)
    piezas = []
    for i in range(110):
        x = (azar.random() * 2 - 1) * (W - PARED - 5)
        y = (azar.random() * 2 - 1) * (D - PARED - 3)
        alto = (H - 12) * max(0.0, 1 - (x / (W - PARED)) ** 2 * 0.7 - (y / (D - PARED)) ** 2 * 0.35)
        z = PARED + alto * (0.75 + 0.25 * azar.random())
        _, yy, zz = girar(x, y, z)
        piezas.append((yy * CZ - zz * CY, (x, y, z), "joya" if i % 12 == 0 else "moneda", azar.random()))
    out = ""
    for _, p, tipo, r in sorted(piezas, reverse=True):
        px, py = proyectar(p)
        if tipo == "moneda":
            giro = (r - 0.5) * 50 + math.degrees(GIRO) * 0.6
            out += (f'<g transform="rotate({giro:.0f} {px:.1f} {py:.1f})"><ellipse cx="{px:.1f}" cy="{py:.1f}" rx="7" ry="3.2" '
                    f'fill="{ORO[1]}" stroke="{TRAZO}" stroke-width="1.2"/><ellipse cx="{px - 1:.1f}" cy="{py - .6:.1f}" rx="4.4" '
                    f'ry="1.7" fill="{ORO[2]}"/></g>')
        else:
            color = ("#ff4a6a", "#4ac8ff", "#7aff6a", "#c070ff")[int(r * 4) % 4]
            out += (f'<path d="M{px:.1f},{py - 7:.1f} L{px + 6:.1f},{py - 1:.1f} L{px:.1f},{py + 6:.1f} L{px - 6:.1f},{py - 1:.1f} Z" '
                    f'fill="{color}" stroke="{TRAZO}" stroke-width="1.3"/>'
                    f'<path d="M{px:.1f},{py - 7:.1f} L{px + 6:.1f},{py - 1:.1f} L{px:.1f},{py - 1:.1f} Z" fill="#ffffff" opacity=".55"/>')
    return out


def dentro():
    """Lo que se ve por la abertura: las paredes de dentro, el suelo, el tesoro y
    su luz, recortado a la abertura."""
    i0, i1, j0, j1 = -W + PARED, W - PARED, -D + PARED, D - PARED
    abertura = [(i0, j0, H), (i1, j0, H), (i1, j1, H), (i0, j1, H)]
    recorte = "M" + " L".join(fp(proyectar(p)) for p in abertura) + " Z"
    fondo = poligono([(i0, j1, PARED), (i1, j1, PARED), (i1, j1, H), (i0, j1, H)], mezclar(MADERA_DENTRO, 0.45), 0)
    izquierda = poligono([(i0, j0, PARED), (i0, j1, PARED), (i0, j1, H), (i0, j0, H)], mezclar(MADERA_DENTRO, 0.6), 0)
    suelo = poligono([(i0, j0, PARED), (i1, j0, PARED), (i1, j1, PARED), (i0, j1, PARED)], mezclar(MADERA_DENTRO, 0.2), 0)
    luz_c = proyectar((0, 0, H * 0.8))
    brillo = (f'<radialGradient id="brilloDentro" gradientUnits="userSpaceOnUse" cx="{luz_c[0]:.1f}" cy="{luz_c[1]:.1f}" r="{W:.1f}">'
              f'<stop offset="0" stop-color="#fff2b0" stop-opacity=".9"/><stop offset=".5" stop-color="#ffb030" stop-opacity=".35"/>'
              f'<stop offset="1" stop-color="#ff8a10" stop-opacity="0"/></radialGradient>')
    return (f'<defs><clipPath id="abertura"><path d="{recorte}"/></clipPath>{brillo}</defs>'
            f'<g clip-path="url(#abertura)">{fondo}{izquierda}{suelo}{tesoro()}'
            f'<rect x="0" y="0" width="{LIENZO}" height="{LIENZO}" fill="url(#brilloDentro)"/></g>')


def cantos():
    """Lo de arriba de las paredes, que se ve con la tapa levantada."""
    i0, i1, j0, j1 = -W + PARED, W - PARED, -D + PARED, D - PARED
    out = ""
    for puntos, k in (([(-W, j1, H), (W, j1, H), (W, D, H), (-W, D, H)], 0.5),
                      ([(-W, j0, H), (i0, j0, H), (i0, j1, H), (-W, j1, H)], 0.55),
                      ([(i1, j0, H), (W, j0, H), (W, j1, H), (i1, j1, H)], 0.7),
                      ([(-W, -D, H), (W, -D, H), (W, j0, H), (-W, j0, H)], 0.8)):
        out += poligono(puntos, mezclar(ORO, k), 2.0)
    return out


# ----------------------------------------------------------- la tapa ---
def en_tapa(p, angulo):
    """Un punto de la tapa cerrada, girado sobre la bisagra (y = D, z = H)."""
    x, y, z = p
    dy, dz = y - D, z - H
    c, s = math.cos(angulo), math.sin(angulo)
    return x, D + dy * c + dz * s, H - dy * s + dz * c


def normal_tapa(n, angulo):
    x, y, z = n
    c, s = math.cos(angulo), math.sin(angulo)
    return x, y * c + z * s, -y * s + z * c


def cupula(x, f):
    """Un punto de la cupula (cerrada): f = 0 delante, pi atras."""
    return x, -D * math.cos(f), H + ALTO_TAPA * math.sin(f)


def normal_cupula(f):
    return 0.0, -math.cos(f) / D, math.sin(f) / ALTO_TAPA


def tapa(angulo):
    out = ""
    girada = lambda p: en_tapa(p, angulo)  # noqa: E731
    # La cara de dentro (plana): se ve pasados los 38 grados (la elevacion).
    n = normal_tapa((0, 0, -1), angulo)
    if mira(n) > 0:
        k = 0.3 + 0.45 * luz(n)
        contenido = f'<rect x="0" y="0" width="{2 * W}" height="{2 * D}" fill="{mezclar(MADERA_DENTRO, k)}" stroke="{TRAZO}" stroke-width="3"/>'
        for j in range(1, 4):
            contenido += f'<path d="M3,{j * D / 2:.1f} L{2 * W - 3},{j * D / 2:.1f}" stroke="{TRAZO}" stroke-width="1.4" opacity=".6"/>'
        for a, b in BANDAS:
            contenido += (f'<rect x="{W + a * W:.1f}" y="0" width="{(b - a) * W:.1f}" height="{2 * D}" fill="{mezclar(ORO, k + 0.1)}" '
                          f'stroke="{TRAZO}" stroke-width="1.8"/>')
        o = girada((-W, -D, H))
        u = tuple(girada((-W + 1, -D, H))[i] - o[i] for i in range(3))
        v = tuple(girada((-W, -D + 1, H))[i] - o[i] for i in range(3))
        out += en_cara(o, u, v, contenido)
    # La cupula, en tiras, con su luz.
    for i in range(TIRAS):
        f0, f1 = math.pi * i / TIRAS, math.pi * (i + 1) / TIRAS
        n = normal_tapa(normal_cupula((f0 + f1) / 2), angulo)
        if mira(n) <= 0:
            continue
        brillo = 0.22 + 0.78 * luz(n)
        color = mezclar(ORO, brillo) if i in (0, TIRAS - 1) else mezclar(MADERA, brillo)
        tira = [girada(cupula(-W, f0)), girada(cupula(W, f0)), girada(cupula(W, f1)), girada(cupula(-W, f1))]
        # Sin borde, pero con un trazo fino del mismo color: si no, entre tira y
        # tira se ve una raya del fondo.
        out += poligono(tira, color, 0.8, trazo=color)
        if i % 5 == 3 and 0 < i < TIRAS - 1:
            out += f'<path d="M{fp(proyectar(tira[3]))} L{fp(proyectar(tira[2]))}" stroke="{TRAZO}" stroke-width="1.1" opacity=".3"/>'
        for a, b in BANDAS:
            banda = [girada(cupula(a * W, f0)), girada(cupula(b * W, f0)), girada(cupula(b * W, f1)), girada(cupula(a * W, f1))]
            oro = mezclar(ORO, brillo)
            out += poligono(banda, oro, 0.8, trazo=oro)
    # Bordes de las bandas y remaches, donde la cupula mira a la camara.
    for a, b in BANDAS:
        for x in (a * W, b * W):
            pts = [girada(cupula(x, math.pi * i / 24)) for i in range(25)
                   if mira(normal_tapa(normal_cupula(math.pi * i / 24), angulo)) > -0.05]
            if len(pts) > 1:
                out += f'<path d="M{" L".join(fp(proyectar(p)) for p in pts)}" fill="none" stroke="{TRAZO}" stroke-width="1.8"/>'
        for f in (0.55, 1.5, 2.45):
            n = normal_tapa(normal_cupula(f), angulo)
            if mira(n) > 0.15:
                out += remache(*proyectar(girada(cupula((a + b) / 2 * W, f))), 2.3)
    # El costado de la tapa (derecho): media elipse con su ribete de oro.
    n = normal_tapa((1, 0, 0), angulo)
    if mira(n) > 0:
        perfil = [girada(cupula(W, math.pi * i / 24)) for i in range(25)]
        out += poligono(perfil, mezclar(MADERA, 0.15 + 0.5 * luz(n)), 3.0)
        dentro_p = [girada((W, -(D - 5) * math.cos(math.pi * i / 24), H + 2 + (ALTO_TAPA - 5) * math.sin(math.pi * i / 24)))
                    for i in range(25)]
        out += (f'<path d="M{" L".join(fp(proyectar(p)) for p in dentro_p)}" fill="none" stroke="{mezclar(ORO, 0.5)}" '
                f'stroke-width="3.2" stroke-linejoin="round"/>')
    # El contorno de toda la cupula, de una vez.
    contorno = [girada(cupula(-W, math.pi * i / 24)) for i in range(25)]
    contorno += [girada(cupula(W, math.pi * (24 - i) / 24)) for i in range(25)]
    out += f'<path d="M{" L".join(fp(proyectar(p)) for p in contorno)} Z" fill="none" stroke="{TRAZO}" stroke-width="3.2" stroke-linejoin="round"/>'
    # El emblema de arriba: una runa en un disco, pegada a la cupula.
    f = 1.5
    n = normal_tapa(normal_cupula(f), angulo)
    if mira(n) > 0.25:
        o = girada(cupula(0, f))
        u = tuple(girada(cupula(1, f))[i] - o[i] for i in range(3))
        t = (0.0, D * math.sin(f), ALTO_TAPA * math.cos(f))     # la tangente, hacia atras
        largo = math.sqrt(sum(c * c for c in t))
        t2 = tuple(girada((0, cupula(0, f)[1] - t[1] / largo, cupula(0, f)[2] - t[2] / largo))[i] - o[i] for i in range(3))
        emblema = (f'<circle r="12" fill="url(#oroV)" stroke="{TRAZO}" stroke-width="2.2"/>'
                   f'<path d="M0,-8 L2.2,-2.2 L8,0 L2.2,2.2 L0,8 L-2.2,2.2 L-8,0 L-2.2,-2.2 Z" fill="#fff4c0" stroke="{ORO[0]}" stroke-width="1"/>')
        out += en_cara(o, u, t2, emblema)
    return out


def cierre(angulo):
    """La lengueta de oro que cuelga del borde de delante de la tapa, encima de la
    cerradura. Va la ultima: esta por fuera de todo."""
    girada = lambda p: en_tapa(p, angulo)  # noqa: E731
    n = normal_tapa((0, -1, 0), angulo)
    if mira(n) <= 0:
        return ""
    o = girada((-8, -D - 1.5, H + 3))
    u = tuple(girada((-7, -D - 1.5, H + 3))[i] - o[i] for i in range(3))
    v = tuple(girada((-8, -D - 1.5, H + 2))[i] - o[i] for i in range(3))
    forma = (f'<path d="M0,0 L16,0 L16,12 L8,19 L0,12 Z" fill="url(#oroV)" stroke="{TRAZO}" stroke-width="2.3" stroke-linejoin="round"/>'
             f'<circle cx="8" cy="9" r="2.2" fill="{TRAZO}"/>')
    return en_cara(o, u, v, forma)


def sombra():
    cx, cy = proyectar((0, 0, 0))
    return f'<ellipse cx="{cx:.1f}" cy="{cy + 3:.1f}" rx="{W + 26:.1f}" ry="{(D + 14) * CY + 10:.1f}" fill="url(#sombra)"/>'


def svg(grados):
    angulo = math.radians(grados)
    # De atras a delante: por dentro y los cantos (si esta abierta), la tapa, la
    # caja y la lengueta del cierre.
    capas = degradados() + sombra()
    if grados > 0:
        capas += dentro() + cantos()
    capas += tapa(angulo) + caja() + cierre(angulo)
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {LIENZO} {LIENZO}" width="{LIENZO}" height="{LIENZO}">'
            f'{capas}</svg>')


def main():
    os.makedirs(DESTINO, exist_ok=True)
    tmp = tempfile.mkdtemp(prefix="cofre_")
    try:
        tira = Image.new("RGBA", (LADO * len(ANGULOS), LADO))
        for i, grados in enumerate(ANGULOS):
            ruta = os.path.join(tmp, "c%d" % i)
            with open(ruta + ".svg", "w", encoding="utf-8") as f:
                f.write(svg(grados))
            subprocess.run(["rsvg-convert", "-w", str(LIENZO * 2), "-h", str(LIENZO * 2), ruta + ".svg", "-o", ruta + ".png"],
                           check=True)
            tira.alpha_composite(reducir(Image.open(ruta + ".png").convert("RGBA"), (LADO, LADO)), (i * LADO, 0))
        tira.save(os.path.join(DESTINO, "cofre.png"))
    finally:
        shutil.rmtree(tmp)
    print("Listo: %d cuadros de %d px; el suelo en %s" % (len(ANGULOS), LADO,
          (ORIGEN[0] * LADO / LIENZO, ORIGEN[1] * LADO / LIENZO)))


if __name__ == "__main__":
    main()
