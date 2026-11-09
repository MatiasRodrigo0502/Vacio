# -*- coding: utf-8 -*-
"""Redibuja los once enemigos de antes (resources/enemigos_antiguos/) como los
nuevos: vectoriales, en las ocho direcciones y con sus cuatro animaciones
(caminar, atacar, dano y muerte).

Pedido por Matias el 2026-11-06 («mejora los assets de los enemigos
antiguos»). Hasta entonces cada uno era una sola tira de 10 poses que el juego
volteaba al girarse. Matias quiere verlos antes de decidir si vuelven a salir:
por eso esto solo hace el arte y apunta a el sus .tres de enemigos_antiguos,
que no lee la mecanica de enemigos.

LA TECNICA es la de los enemigos del paquete (assets/enemigos_fuente/): cada
pieza vive en un angulo alrededor del cuerpo (phi) y, al girar el cuerpo
(theta), se proyecta con seno y coseno; su profundidad dice si va delante o
detras. Theta 0 mira a la camara (abajo), 90 a la derecha, 180 de espaldas.
Las filas, en el orden de Jugador.LADOS (theta_de_fila).

LO QUE SALE, por enemigo, en assets/criaturas/<id>/: una hoja por animacion
(8 filas, una por direccion) y animaciones.tres, con caminar_abajo,
atacar_abajo..., como los del paquete (generar_enemigos.py). Cada hoja se pinta
al doble y se reduce: no es pixel art.

EL TAMANO de cada uno sale de su 'alto' de siempre (el de su .tres): se mide
cuanto ocupa el cuerpo en el dibujo (de frente, quieto) y la casilla se reduce
para que mida eso. Asi chocan como antes.

Necesita rsvg-convert (como magos_vectorial.py) y los scripts del paquete, que
estan en assets/enemigos_fuente/del_paquete/.

    python herramientas/generar_antiguos.py [slime_verde escorpion ...]
"""
import importlib.util
import math
import os
import random
import re
import shutil
import subprocess
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor

from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)
from generar_magos import DIRECCIONES, animacion, guardar_texto, reducir  # noqa: E402

RAIZ = os.path.join(AQUI, "..")
PAQUETE = os.path.join(RAIZ, "assets", "enemigos_fuente", "del_paquete")
DESTINO = os.path.join(RAIZ, "assets", "criaturas")
RECURSOS = os.path.join(RAIZ, "resources", "enemigos_antiguos")


def _cargar(nombre, archivo):
    """Un script del paquete, por su ruta: el paquete tiene tambien un
    generar_magos.py, y con import a secas se confundiria con el nuestro."""
    spec = importlib.util.spec_from_file_location(nombre, os.path.join(PAQUETE, archivo))
    modulo = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(modulo)
    return modulo


gh = _cargar("paquete_hechizos", "generar_hechizos.py")
P, TAU, blob_d, suave = gh.P, gh.TAU, gh.blob_d, gh.suave
PROF = 0.2          # lo que se aplasta la profundidad (como PROF_Y en el paquete)
PIES = 0.42         # lo que se aplasta el suelo: un circulo en el suelo se ve asi de alto


def sc(theta, phi=0.0):
    a = math.radians(theta + phi)
    return math.sin(a), math.cos(a)


def cil(theta, phi, r, cx, y):
    """Un punto en un cilindro alrededor del cuerpo -> (x, y, z)."""
    s, z = sc(theta, phi)
    return cx + r * s, y + z * r * PROF, z


def theta_de_fila(k):
    return 90 - 45 * k


def en_suelo(cx, cy, theta, adelante, lado=0.0):
    """Un punto del suelo, delante (y al lado) del cuerpo, segun hacia donde mira."""
    s, c = sc(theta)
    return cx + adelante * s + lado * c, cy + (adelante * c - lado * s) * PIES


DEFS_COMUN = """
  <filter id="blanco"><feColorMatrix type="matrix" values=".45 0 0 0 .55  0 .45 0 0 .55  0 0 .45 0 .55  0 0 0 1 0"/></filter>
  <radialGradient id="sombraE"><stop offset="0" stop-color="#000" stop-opacity=".5"/><stop offset="1" stop-color="#000" stop-opacity="0"/></radialGradient>
  <radialGradient id="escleraE" cx=".4" cy=".35" r=".7"><stop offset="0" stop-color="#ffffff"/><stop offset="1" stop-color="#d8d0c8"/></radialGradient>
"""


def lienzo(w, h, contenido, defs=""):
    return gh.svg(w, h, contenido, DEFS_COMUN + defs)


def degradado(ident, colores, radial=False, cx=.38, cy=.32, r=.8, x2=0.0, y2=1.0):
    paradas = "".join(f'<stop offset="{i / (len(colores) - 1):.2f}" stop-color="{c}"/>' for i, c in enumerate(colores))
    if radial:
        return f'<radialGradient id="{ident}" cx="{cx}" cy="{cy}" r="{r}">{paradas}</radialGradient>'
    return f'<linearGradient id="{ident}" x1="0" y1="0" x2="{x2}" y2="{y2}">{paradas}</linearGradient>'


def sombra(cx, cy, rx, ry, op=1.0):
    return f'<ellipse cx="{cx:.1f}" cy="{cy:.1f}" rx="{rx:.1f}" ry="{ry:.1f}" fill="url(#sombraE)" opacity="{op:.2f}"/>'


def con_flash(contenido, flash):
    return f'<g filter="url(#blanco)">{contenido}</g>' if flash else contenido


def ojo(x, y, k, r, iris, borde, mira=(0.0, 0.0), parpado=0.0, brillo=None, enfadado=0.0, lado=1, piel=None):
    """Un ojo redondo (esclera, iris y brillo) aplastado de lado (k, de 0 a 1),
    con el parpado (de su piel) que baja y una ceja enfadada."""
    if k <= 0.05:
        return ""
    rx, ry = r * k, r
    out = f'<ellipse cx="{x:.1f}" cy="{y:.1f}" rx="{rx + 1.2:.1f}" ry="{ry + 1.2:.1f}" fill="{borde}"/>'
    if parpado >= 0.95:
        return out + f'<path d="M{x - rx:.1f},{y:.1f} L{x + rx:.1f},{y:.1f}" stroke="{borde}" stroke-width="2.4" stroke-linecap="round"/>'
    out += f'<ellipse cx="{x:.1f}" cy="{y:.1f}" rx="{rx:.1f}" ry="{ry:.1f}" fill="url(#escleraE)"/>'
    ix, iy = x + mira[0] * rx * .35, y + mira[1] * ry * .3
    out += f'<ellipse cx="{ix:.1f}" cy="{iy:.1f}" rx="{rx * .58:.1f}" ry="{ry * .62:.1f}" fill="{iris}"/>'
    out += f'<ellipse cx="{ix:.1f}" cy="{iy:.1f}" rx="{rx * .28:.1f}" ry="{ry * .34:.1f}" fill="#0a0606"/>'
    if brillo:
        # Una brasa en el iris, no un halo alrededor del ojo: grande y clara,
        # de lado parecian unas gafas.
        out += f'<circle cx="{ix:.1f}" cy="{iy:.1f}" r="{r * .55:.1f}" fill="{brillo}" opacity=".6" filter="url(#brillo)"/>'
    out += f'<circle cx="{ix - rx * .25:.1f}" cy="{iy - ry * .3:.1f}" r="{r * .2:.1f}" fill="#ffffff"/>'
    if parpado > 0:
        # El parpado, de su piel y con el borde abajo: negro entero parecian gafas.
        yb = y - ry + 2 * ry * parpado
        out += (f'<path d="M{x - rx - 1:.1f},{y - ry - 1:.1f} L{x + rx + 1:.1f},{y - ry - 1:.1f} L{x + rx + 1:.1f},{yb:.1f} '
                f'L{x - rx - 1:.1f},{yb:.1f} Z" fill="{piel or borde}"/>'
                f'<path d="M{x - rx:.1f},{yb:.1f} L{x + rx:.1f},{yb:.1f}" stroke="{borde}" stroke-width="2" stroke-linecap="round"/>')
    if enfadado:
        out += (f'<path d="M{x - rx * 1.1:.1f},{y - ry - 2 - enfadado * lado * 3:.1f} L{x + rx * 1.1:.1f},{y - ry - 2 + enfadado * lado * 3:.1f}" '
                f'stroke="{borde}" stroke-width="3" stroke-linecap="round"/>')
    return out


# ======================================================== 1. SLIMES ===
# Lienzo de 192. El suelo, en y = 168. Un bulto de gelatina que va a saltos: se
# aplasta al caer y se estira al subir, sin despegar la base del suelo salvo en
# el aire.
S_SUELO = 168
TEMAS_SLIME = {
    "slime_verde": dict(cuerpo=("#d8ff9a", "#5ad02a", "#1e6a10"), borde="#0c2a06", iris="#2a6a10", brillo="#eaffb0",
                        dentro="#3aa018", extra="burbujas"),
    "slime_naranja": dict(cuerpo=("#ffe0a0", "#e88a2a", "#7a3a0c"), borde="#2a1004", iris="#7a2a04", brillo="#fff0c0",
                          dentro="#c86a1a", extra="pinchos"),
    "slime_magma": dict(cuerpo=("#fff0a0", "#ff7a1a", "#9a1a06"), borde="#2a0602", iris="#ffe060", brillo="#fff4c0",
                        dentro="#ff4a0a", extra="costra"),
}
PINCHOS_SLIME = [(phi, alto) for phi, alto in zip(range(-160, 200, 40), (.9, .7, 1.0, .8, .95, .75, 1.0, .85, .8))]
PLACAS_SLIME = [(55, 0), (55, 72), (55, 144), (55, 216), (55, 288), (80, 30), (30, 36), (30, 108), (30, 180), (30, 252), (30, 324)]


def pose_slime(anim, f):
    p = dict(aplasta=0.0, sube=0.0, avance=0.0, boca=0.0, flash=False, ojos=1.0, parpado=0.0, temblor=0.0,
             charco=None, gotas=0.0, enfado=0.0)
    if anim == "caminar":
        p["aplasta"], p["sube"] = [.16, -.1, -.04, .08][f], [0, 9, 15, 3][f]
    elif anim == "atacar":
        # Se encoge, salta hacia delante con la boca abierta y cae aplastado.
        p.update(aplasta=[.26, .34, -.18, -.08, .3, .1][f], sube=[0, 0, 14, 20, 0, 0][f],
                 avance=[0, -2, 10, 20, 24, 12][f], boca=[0, .2, 1, 1, .4, 0][f], enfado=[.5, 1, 1, 1, .6, .3][f])
    elif anim == "dano":
        p.update(flash=f == 0, aplasta=[-.12, .14, -.04][f], temblor=[4, -3, 1][f], parpado=[.6, .3, 0][f])
    elif anim == "muerte":
        if f < 3:
            p.update(flash=f == 0, aplasta=[.1, -.1, .3][f], temblor=[3, -4, 2][f], parpado=[.5, .8, 1][f])
        else:
            p.update(charco=(f - 3) / 4, ojos=0.0)
    return p


def svg_slime(nombre, anim, theta, f):
    t = TEMAS_SLIME[nombre]
    p = pose_slime(anim, f)
    s, c = sc(theta)
    defs = (degradado("gelatina", t["cuerpo"], True, .36, .28, .85)
            + degradado("dentroS", [t["dentro"], t["cuerpo"][2]], True, .5, .6, .7))
    out = ""
    ax, ay = en_suelo(96, S_SUELO, theta, p["avance"])
    if p["charco"] is not None:
        # Revienta: un charco que se extiende y se seca, y gotas que saltan.
        q = p["charco"]
        out += sombra(96, S_SUELO, 56 + 20 * q, 13, 1 - q * .5)
        rx = 50 + 26 * suave(q, 1.4)
        out += (f'<path d="{blob_d(96, S_SUELO - 4, rx, q * 3, 7, .12, achatar=.26)}" fill="url(#gelatina)" '
                f'stroke="{t["borde"]}" stroke-width="2.5" opacity="{1 - max(0, q - .6) / .4 * .8:.2f}"/>')
        for i in range(8):
            a = math.radians(i * 45 + 20)
            d = 30 + 70 * suave(q, 1.2)
            gx, gy = 96 + math.cos(a) * d, S_SUELO - 10 - math.sin(a * .5 + 1) * 40 * math.sin(q * math.pi) + math.sin(a) * d * .3
            out += (f'<circle cx="{gx:.1f}" cy="{gy:.1f}" r="{6 * (1 - q) + 2:.1f}" fill="url(#gelatina)" stroke="{t["borde"]}" '
                    f'stroke-width="1.6" opacity="{1 - q:.2f}"/>')
        return lienzo(192, 192, out, defs)
    out += sombra(ax, S_SUELO, 54 - p["sube"] * .8, 13 - p["sube"] * .2, 1 - p["sube"] / 30)
    rx, ry = 52 * (1 + p["aplasta"]), 44 * (1 - p["aplasta"])
    cx, base = ax + p["temblor"], S_SUELO - 2 - p["sube"]
    cy = base - ry
    cuerpo = ""
    if t["extra"] == "pinchos":       # los de detras, primero
        cuerpo += _pinchos_slime(t, theta, cx, cy, rx, ry, detras=True)
    # La gelatina: un bulto con la base plana.
    gelatina = (f'M{cx - rx:.1f},{base:.1f} C{cx - rx:.1f},{cy - ry * .2:.1f} {cx - rx * .55:.1f},{cy - ry:.1f} '
                f'{cx:.1f},{cy - ry:.1f} C{cx + rx * .55:.1f},{cy - ry:.1f} {cx + rx:.1f},{cy - ry * .2:.1f} {cx + rx:.1f},{base:.1f} '
                f'Q{cx:.1f},{base + 6:.1f} {cx - rx:.1f},{base:.1f} Z')
    cuerpo += f'<path d="{gelatina}" fill="url(#gelatina)" stroke="{t["borde"]}" stroke-width="3"/>'
    # Lo de dentro: un nucleo mas oscuro y, en el verde, burbujas que suben.
    cuerpo += f'<ellipse cx="{cx - 4 * s:.1f}" cy="{cy + ry * .35:.1f}" rx="{rx * .5:.1f}" ry="{ry * .38:.1f}" fill="url(#dentroS)" opacity=".45"/>'
    if t["extra"] == "burbujas":
        for i in range(5):
            ph = (i / 5 + f / 4) % 1 if anim == "caminar" else i / 5
            bx = cx + (i - 2) * rx * .3 + 4 * math.sin(i * 2.1)
            by = base - 6 - ph * ry * 1.4
            cuerpo += f'<circle cx="{bx:.1f}" cy="{by:.1f}" r="{2 + i % 3:.1f}" fill="none" stroke="#f0ffd0" stroke-width="1.3" opacity="{.7 * (1 - ph):.2f}"/>'
    elif t["extra"] == "costra":
        # Recortada por la gelatina: las placas van sobre una esfera, y el
        # slime es mas bajo que ancho; las de arriba flotaban por encima.
        cuerpo += (f'<clipPath id="dentroGelatina"><path d="{gelatina}"/></clipPath>'
                   f'<g clip-path="url(#dentroGelatina)">{_costra_slime(t, theta, cx, cy, rx, ry, f)}</g>')
    # Brillo de arriba a la izquierda, como si fuera de cristal.
    cuerpo += (f'<ellipse cx="{cx - rx * .38:.1f}" cy="{cy - ry * .55:.1f}" rx="{rx * .26:.1f}" ry="{ry * .14:.1f}" fill="#ffffff" '
               f'opacity=".55" transform="rotate(-25 {cx - rx * .38:.1f} {cy - ry * .55:.1f})"/>'
               f'<circle cx="{cx - rx * .62:.1f}" cy="{cy - ry * .18:.1f}" r="3" fill="#ffffff" opacity=".5"/>')
    # La cara: mira hacia theta; de espaldas no se ve.
    if p["ojos"] > 0:
        cuerpo += _cara_slime(t, theta, cx, cy, rx, ry, p)
    if t["extra"] == "pinchos":
        cuerpo += _pinchos_slime(t, theta, cx, cy, rx, ry, detras=False)
    out += con_flash(cuerpo, p["flash"])
    return lienzo(192, 192, out, defs)


def _cara_slime(t, theta, cx, cy, rx, ry, p):
    out = ""
    for phi, lado in ((-24, -1), (24, 1)):
        se, z = sc(theta, phi)
        if z < .15:
            continue
        x, k = cx + rx * .82 * se, z ** .6
        out += ojo(x, cy + ry * .05, k, 10.0, t["iris"], t["borde"], mira=(sc(theta)[0], .2), parpado=p["parpado"],
                   brillo="#ffb030" if t["extra"] == "costra" else None, enfadado=p["enfado"], lado=lado,
                   piel=t["cuerpo"][1])
    s, c = sc(theta)
    if c > .2:
        mx, my, k = cx + rx * .6 * s, cy + ry * .42, c ** .7
        if p["boca"] > 0:
            alto = 4 + 12 * p["boca"]
            out += (f'<ellipse cx="{mx:.1f}" cy="{my:.1f}" rx="{11 * k:.1f}" ry="{alto:.1f}" fill="{t["borde"]}"/>'
                    f'<ellipse cx="{mx:.1f}" cy="{my + alto * .45:.1f}" rx="{6 * k:.1f}" ry="{alto * .35:.1f}" fill="#c8304a"/>')
        else:
            out += f'<path d="M{mx - 7 * k:.1f},{my:.1f} Q{mx:.1f},{my + 5:.1f} {mx + 7 * k:.1f},{my:.1f}" fill="none" stroke="{t["borde"]}" stroke-width="2.6" stroke-linecap="round"/>'
    return out


def _pinchos_slime(t, theta, cx, cy, rx, ry, detras):
    """Pinchos que salen de la gelatina del naranja: giran con el cuerpo."""
    out = ""
    for phi, alto in PINCHOS_SLIME:
        s_, z = sc(theta, phi)
        if (z < 0) != detras:
            continue
        for fila, (sube, largo) in enumerate(((.15, 1.0), (.6, .75))):
            bx = cx + rx * .92 * s_ * (1 - sube * .35)
            by = cy - ry * sube + z * rx * PROF
            tx = bx + s_ * 18 * alto * largo
            ty = by - 16 * alto * largo - 6 * (1 - abs(s_))
            n = (-(ty - by), tx - bx)
            ln = math.hypot(*n) or 1
            n = (n[0] / ln * 4.5, n[1] / ln * 4.5)
            out += (f'<path d="M{bx + n[0]:.1f},{by + n[1]:.1f} Q{(bx + tx) / 2 + n[0] * .3:.1f},{(by + ty) / 2:.1f} {tx:.1f},{ty:.1f} '
                    f'Q{(bx + tx) / 2 - n[0] * .3:.1f},{(by + ty) / 2:.1f} {bx - n[0]:.1f},{by - n[1]:.1f} Z" fill="#5a3a1a" '
                    f'stroke="{t["borde"]}" stroke-width="1.8" stroke-linejoin="round"/>')
    return out


def _costra_slime(t, theta, cx, cy, rx, ry, f):
    """Placas de costra oscura por encima del de magma, con lava entre ellas."""
    out = ""
    for lat, lon in PLACAS_SLIME:
        x, y, z = gh.proyectar_esfera(cx, cy + ry * .15, rx * .92, lat, lon + theta)
        if z < .05:
            continue
        k = .35 + .65 * z
        tam = (11 if lat < 60 else 9) * (ry / 44)
        forma = [(TAU * v / 6 + (lon % 7) * .1, .8 + .2 * ((v + lon) % 3) / 2) for v in range(6)]
        pts = " L".join(P(x + tam * rr * math.cos(b) * (k if abs(math.cos(b)) > .3 else 1), y + tam * rr * math.sin(b) * .7)
                        for b, rr in forma)
        out += f'<path d="M{pts} Z" fill="#3a1208" stroke="#1a0402" stroke-width="1.6" stroke-linejoin="round"/>'
        out += f'<path d="M{pts} Z" fill="none" stroke="{t["cuerpo"][0]}" stroke-width=".9" opacity="{.4 + .3 * math.sin(f * 1.6 + lon):.2f}"/>'
    return out


# ===================================================== COSAS EN EL SUELO ===
# Para los que andan a cuatro patas o se arrastran: cada pieza esta a una
# distancia hacia delante (t), a un lado (u) y a una altura (h) del centro de
# sus pies. Mirando a theta, delante se ve hacia (sin, cos * PIES) en la
# pantalla; un lado, hacia (cos, -sin * PIES). Lo que queda mas abajo en el
# suelo esta mas cerca, y se pinta despues.
class Cuerpo:
    def __init__(self, theta, x, y):
        self.s, self.c = sc(theta)
        self.x, self.y = x, y
        self.piezas = []

    def punto(self, t, u=0.0, h=0.0):
        return (self.x + t * self.s + u * self.c, self.y + (t * self.c - u * self.s) * PIES - h)

    def hondo(self, t, u=0.0):
        return (t * self.c - u * self.s) * PIES

    def poner(self, t, u, svg_pieza, extra=0.0):
        self.piezas.append((self.hondo(t, u) + extra, len(self.piezas), svg_pieza))

    def pintar(self):
        return "".join(p for _, _, p in sorted(self.piezas))

    def elipsoide(self, largo, ancho, alto):
        """La silueta de un elipsoide con esos semiejes (adelante, de lado, de
        alto), vista desde aqui: (rx, ry, giro en grados)."""
        f = (largo * self.s, largo * self.c * PIES)
        l = (ancho * self.c, -ancho * self.s * PIES)
        a = f[0] ** 2 + l[0] ** 2
        b = f[0] * f[1] + l[0] * l[1]
        d = f[1] ** 2 + l[1] ** 2 + alto ** 2
        media, dif = (a + d) / 2, math.sqrt(((a - d) / 2) ** 2 + b * b)
        giro = math.degrees(0.5 * math.atan2(2 * b, a - d))
        return math.sqrt(media + dif), math.sqrt(max(media - dif, 1.0)), giro


def elipse(x, y, rx, ry, giro, relleno, borde, ancho=2.4, extra=""):
    return (f'<ellipse cx="{x:.1f}" cy="{y:.1f}" rx="{rx:.1f}" ry="{ry:.1f}" transform="rotate({giro:.1f} {x:.1f} {y:.1f})" '
            f'fill="{relleno}" stroke="{borde}" stroke-width="{ancho}"{extra}/>')


def tubo(puntos, ancho, color, borde, ancho_borde=2.2, extra=""):
    """Una linea gruesa con borde: cola, cuello, tallo."""
    d = "M" + " L".join(P(x, y) for x, y in puntos)
    return (f'<path d="{d}" fill="none" stroke="{borde}" stroke-width="{ancho + ancho_borde * 2:.1f}" stroke-linecap="round" stroke-linejoin="round"/>'
            f'<path d="{d}" fill="none" stroke="{color}" stroke-width="{ancho:.1f}" stroke-linecap="round" stroke-linejoin="round"{extra}/>')


def tubo_afilado(puntos, ancho0, ancho1, color, borde):
    """Una linea que se afila (los dedos de las pinzas): tramos cada vez mas finos."""
    out = ""
    for capa, (col, mas) in enumerate(((borde, 2.2), (color, 0.0))):
        for i in range(len(puntos) - 1):
            k = i / max(1, len(puntos) - 2)
            w = ancho0 + (ancho1 - ancho0) * k + mas * 2
            out += (f'<path d="M{P(*puntos[i])} L{P(*puntos[i + 1])}" stroke="{col}" stroke-width="{w:.1f}" '
                    f'stroke-linecap="round"/>')
    return out


# ===================================================== 2. ESCORPION ===
# Lienzo de 192, el suelo en y = 160. En lugar de la rata (Matias, 2026-11-06:
# «cambia el asset de la rata por un escorpion»): ocho patas, dos pinzas y la
# cola curvada por encima del lomo con el aguijon encendido. Corre en zigzag,
# como la rata; al atacar abre las pinzas y clava el aguijon por encima de la
# cabeza.
E_SUELO = 160
ESCORPION = dict(caparazon=("#e8a850", "#8e4214", "#2a0e04"), borde="#140804", luz="#ffd890", pata="#5e2a0c",
                 ojo="#ff4a2a", veneno="#c8ff4a")
# Las patas de cada lado: donde salen (adelante) y hacia donde apuntan.
E_PATAS = [(7, 22), (2, 6), (-3, -8), (-8, -22)]
# La cola, de la base a la punta, en el espacio del cuerpo (adelante, alto):
# sube hacia atras y se curva hacia delante por encima del lomo.
E_COLA = [(-22, 6), (-32, 12), (-37, 24), (-33, 36), (-23, 43), (-12, 42)]
E_COLA_ATACA = [(-22, 7), (-28, 18), (-26, 32), (-14, 42), (0, 42), (12, 34)]


def pose_escorpion(anim, f):
    p = dict(paso=f * math.pi / 2, anda=1.0, bob=[0, -1, 0, -1][f % 4], avance=0.0, cola=0.0, abre=.15,
             pinzas=0.0, flash=False, tumbado=None, ojos=1.0, agacha=0.0)
    if anim == "atacar":
        # Echa la cola atras, abre las pinzas y clava: la pose 3 es el golpe.
        p.update(anda=0.0, cola=[0, -.35, -.5, 1, .6, .1][f], abre=[.15, .7, 1, .1, .2, .15][f],
                 pinzas=[0, 4, 6, 8, 4, 1][f], avance=[0, -2, -4, 7, 4, 1][f], agacha=[0, .2, .35, 0, 0, 0][f])
    elif anim == "dano":
        p.update(anda=0.0, flash=f == 0, avance=[-6, -4, -1][f], cola=[-.3, -.15, 0][f], abre=[.8, .4, .15][f],
                 ojos=[.3, .6, 1][f])
    elif anim == "muerte":
        if f < 3:
            p.update(anda=1.5, flash=f == 0, avance=[-5, -6, -6][f], cola=[-.4, .2, -.2][f], abre=[1, .6, .9][f],
                     ojos=[.5, .2, 0][f])
        else:
            p.update(tumbado=(f - 3) / 4, ojos=0.0)
    return p


def _cola(p):
    """Los puntos de la cola entre la de reposo y la del golpe (cola > 0) o
    echada atras (cola < 0: el aguijon se va mas arriba y mas atras)."""
    q = p["cola"]
    if q >= 0:
        return [(a[0] + (b[0] - a[0]) * q, a[1] + (b[1] - a[1]) * q) for a, b in zip(E_COLA, E_COLA_ATACA)]
    return [(t - 8 * -q * i / 5, h + 6 * -q * i / 5) for i, (t, h) in enumerate(E_COLA)]


def svg_escorpion(anim, theta, f):
    t = ESCORPION
    p = pose_escorpion(anim, f)
    defs = degradado("quitina", t["caparazon"], True, .38, .28, .85)
    k = Cuerpo(theta, 96, E_SUELO)
    k.x, k.y = k.punto(p["avance"])
    out = sombra(k.x - 8 * k.s, E_SUELO + 2 - 3 * k.c, 46, 14)
    if p["tumbado"] is not None:
        return lienzo(192, 192, out + _escorpion_tumbado(k, t, p["tumbado"]), defs)
    alto = 9 - 3 * p["agacha"] + p["bob"]
    # Las ocho patas: cada una con su rodilla alta, a pares que se alternan.
    for lado in (-1, 1):
        for i, (tp, apunta) in enumerate(E_PATAS):
            fase = p["paso"] + i * math.pi / 2 + (0 if lado > 0 else math.pi)
            paso = 4 * math.sin(fase) * p["anda"]
            sube = max(0.0, math.cos(fase)) * 3 * p["anda"]
            cadera = k.punto(tp, lado * 7, alto - 1)
            # Cortas y con la rodilla baja: largas y altas parecia una arana.
            rodilla = k.punto(tp + apunta * .3 + paso * .5, lado * 15, alto + 4 + sube)
            pie = k.punto(tp + apunta * .55 + paso, lado * 20, sube * .4)
            k.poner(tp, lado * 20, tubo([cadera, rodilla, pie], 2.6, t["pata"], t["borde"], 1.3), -1)
    # El abdomen: siete placas de atras hacia delante, cada una algo mayor.
    for i in range(6):
        tt = -20 + i * 4.2
        rx, ry, giro = k.elipsoide(5.5, 9 + i * .5, 5)
        x, y = k.punto(tt, 0, alto)
        placa = elipse(x, y, rx, ry, giro, "url(#quitina)", t["borde"], 1.8)
        lx, ly = k.punto(tt + 1, 0, alto + 3)
        placa += elipse(lx, ly, rx * .55, ry * .3, giro, t["luz"], "none", 0, ' opacity=".22"')
        k.poner(tt, 0, placa)
    # La cabeza (el caparazon de delante), con los ojos encima.
    cx, cy = k.punto(8, 0, alto + 1)
    rx, ry, giro = k.elipsoide(10, 11, 6)
    cabeza = elipse(cx, cy, rx, ry, giro, "url(#quitina)", t["borde"], 2.2)
    lx, ly = k.punto(9, 0, alto + 5)
    cabeza += elipse(lx, ly, rx * .5, ry * .28, giro, t["luz"], "none", 0, ' opacity=".4"')
    if p["ojos"] > 0:
        for lado in (-1, 1):
            ex, ey = k.punto(13, lado * 3, alto + 6)
            cabeza += (f'<circle cx="{ex:.1f}" cy="{ey:.1f}" r="3.2" fill="{t["ojo"]}" opacity="{.35 * p["ojos"]:.2f}" filter="url(#brillo)"/>'
                       f'<circle cx="{ex:.1f}" cy="{ey:.1f}" r="1.7" fill="{t["ojo"]}" stroke="{t["borde"]}" stroke-width=".8" opacity="{p["ojos"]:.2f}"/>')
    k.poner(8, 0, cabeza, .2)
    # Las pinzas: brazo, codo y la pinza, con sus dos dedos que se abren.
    for lado in (-1, 1):
        hombro = k.punto(14, lado * 6, alto)
        codo = k.punto(19 + p["pinzas"] * .4, lado * 15, alto + 2 + p["pinzas"] * .3)
        mano_t = 27 + p["pinzas"]
        mano = k.punto(mano_t, lado * 11, alto + 3 + p["pinzas"] * .4)
        brazo = tubo([hombro, codo, mano], 3.4, t["pata"], t["borde"], 1.4)
        # La pinza, grande: es lo que lo distingue de lejos.
        rx, ry, giro = k.elipsoide(8, 5.5, 5)
        brazo += elipse(mano[0], mano[1], rx, ry, giro, "url(#quitina)", t["borde"], 1.8)
        for dedo in (-1, 1):
            abre = p["abre"] * (0.6 if dedo > 0 else 1.0)
            base = k.punto(mano_t + 4, lado * (11 + dedo * 2.2), alto + 3)
            punta = k.punto(mano_t + 14 - 3 * abre, lado * (11 + dedo * (2 + 8 * abre)), alto + 3 + dedo * abre)
            brazo += tubo_afilado([base, punta], 4.0, 1.0, t["caparazon"][1], t["borde"])
        k.poner(mano_t - 4, lado * 12, brazo, .4)
    # La cola, tramo a tramo, cada uno a su profundidad (en vertical tapa o
    # queda detras del cuerpo segun hacia donde mire), y el aguijon.
    cola = _cola(p)
    sway = 2 * math.sin(p["paso"]) * p["anda"]
    pts = [k.punto(tt, sway * i / 5, alto + hh - 4) for i, (tt, hh) in enumerate(cola)]
    for i in range(len(pts) - 1):
        w = 7.5 - i * .6
        tramo = tubo([pts[i], pts[i + 1]], w, t["caparazon"][1], t["borde"], 1.6)
        tramo += f'<circle cx="{pts[i + 1][0]:.1f}" cy="{pts[i + 1][1]:.1f}" r="{w * .55:.1f}" fill="url(#quitina)" stroke="{t["borde"]}" stroke-width="1.4"/>'
        tm, hm = (cola[i][0] + cola[i + 1][0]) / 2, (cola[i][1] + cola[i + 1][1]) / 2
        k.poner(tm, 0, tramo, hm * .08)
    # El aguijon: la bola del veneno y la punta, que apunta hacia donde va la cola.
    (t4, h4), (t5, h5) = cola[-2], cola[-1]
    fx, fy = pts[-1]
    dt, dh = t5 - t4, h5 - h4
    largo = math.hypot(dt, dh) or 1
    punta = k.punto(t5 + dt / largo * 9, sway, alto + h5 - 4 + dh / largo * 9 - 4)
    aguijon = (f'<circle cx="{fx:.1f}" cy="{fy:.1f}" r="6.5" fill="url(#quitina)" stroke="{t["borde"]}" stroke-width="1.8"/>'
               f'<path d="M{fx - 2.5:.1f},{fy:.1f} L{punta[0]:.1f},{punta[1]:.1f} L{fx + 2.5:.1f},{fy + 1:.1f} Z" fill="#2a1206" stroke="{t["borde"]}" stroke-width="1" stroke-linejoin="round"/>'
               f'<circle cx="{punta[0]:.1f}" cy="{punta[1]:.1f}" r="{3.5 + 2.5 * max(0, p["cola"]):.1f}" fill="{t["veneno"]}" opacity=".55" filter="url(#brillo)"/>'
               f'<circle cx="{punta[0]:.1f}" cy="{punta[1]:.1f}" r="1.4" fill="{t["veneno"]}"/>')
    k.poner(t5, 0, aguijon, h5 * .08 + .1)
    out += con_flash(k.pintar(), p["flash"])
    return lienzo(192, 192, out, defs)


def _escorpion_tumbado(k, t, q):
    """Panza arriba, con las patas encogidas al aire, y se va apagando."""
    op = 1 - max(0, q - .5) / .5
    out = ""
    cola = [k.punto(-22 - i * 7, 1.5 * math.sin(i), 3 + 2 * math.sin(i * .9)) for i in range(6)]
    out += tubo(cola, 6, t["caparazon"][2], t["borde"], 1.4)
    for i in range(6):
        x, y = k.punto(-20 + i * 4.2, 0, 5)
        rx, ry, giro = k.elipsoide(5.5, 9 + i * .5, 4)
        out += elipse(x, y, rx, ry, giro, t["caparazon"][2], t["borde"], 1.6)
    x, y = k.punto(8, 0, 6)
    rx, ry, giro = k.elipsoide(10, 11, 5)
    out += elipse(x, y, rx, ry, giro, "#5a3016", t["borde"], 2)
    for lado in (-1, 1):
        for i, (tp, _) in enumerate(E_PATAS):
            base = k.punto(tp, lado * 7, 8)
            tiembla = 2.5 * math.sin(q * 18 + i + lado) * (1 - q)
            arriba = (base[0] + lado * 4 * k.c + tiembla, base[1] - 10 - 2 * (i % 2))
            out += tubo([base, arriba], 2.4, t["pata"], t["borde"], 1.1)
        mano = k.punto(26, lado * 10, 6)
        out += elipse(mano[0], mano[1] - 2, 5, 3.5, 0, t["caparazon"][2], t["borde"], 1.4)
    return f'<g opacity="{op:.2f}">{out}</g>'


# ===================================================== 3. SERPIENTE ===
# Lienzo de 192, el suelo en y = 160. Repta con el cuello levantado y escupe
# veneno; al atacar abre la capucha, como una cobra.
SERP = dict(cuerpo=("#a8d050", "#5a8a2a", "#22380e"), borde="#0c1406", luz="#86b444", mancha="#1e3410",
            ojo="#f4e040", veneno="#9aff3a")


def pose_serpiente(anim, f):
    p = dict(fase=f * math.pi / 2, ct=16.0, ch=30.0, boca=0.0, capucha=0.0, lengua=f % 2 == 1, flash=False,
             escupe=-1, ojos=1.0, caida=0.0, op=1.0, amp=1.0)
    if anim == "caminar":
        p["ch"] += [0, -1.5, 0, -1.5][f]
    elif anim == "atacar":
        p.update(fase=0.0, ct=16 + [0, -6, -10, 8, 6, 0][f], ch=30 + [0, 4, 8, -2, 0, 0][f],
                 boca=[0, .2, .5, 1, .6, 0][f], capucha=[.2, .7, 1, 1, .7, .3][f], lengua=False,
                 escupe=[-1, -1, -1, 0, 1, -1][f])
    elif anim == "dano":
        p.update(flash=f == 0, ct=16 + [-8, -5, -2][f], ch=30 + [-6, -3, 0][f], lengua=False, ojos=[.4, .7, 1][f])
    elif anim == "muerte":
        q = max(0, f - 2) / 5
        p.update(flash=f == 0, fase=.4, lengua=False, ct=16 - [6, 8, 8][min(f, 2)] * (1 - q),
                 ch=30 - [4, 8, 12][min(f, 2)] - 14 * q, caida=q, ojos=max(0, 1 - f / 2.0),
                 op=1 - max(0, f - 5) / 3, amp=1 - .6 * q, boca=.3 if f >= 3 else 0)
    return p


def svg_serpiente(anim, theta, f):
    t = SERP
    p = pose_serpiente(anim, f)
    defs = degradado("escamas", t["cuerpo"], True, .4, .3, .8)
    k = Cuerpo(theta, 96, 160)
    out = sombra(96 - 20 * k.s, 162 - 4 * k.c, 50, 13)
    # El cuerpo en el suelo: una S que se arrastra hacia atras, cada vez mas
    # fina. La onda corre hacia la cola (fase - i), que es como repta.
    pts = []
    for i in range(14):
        amp = 9 * min(1, i / 3) * p["amp"]
        pts.append((4 - i * 5.0, amp * math.sin(p["fase"] - i * .75), 5 - i * .25))
    cuerpo = [k.punto(*q) for q in pts]
    k.poner(-30, 0, tubo_afilado_brillo(cuerpo, 11, 2, "url(#escamas)", t["borde"], t["luz"], (2, t["mancha"])))
    # El cuello sube del primer tramo y la cabeza mira hacia delante.
    ct, ch = p["ct"], p["ch"]
    cuello = [k.punto(*q) for q in bezier((4, 0, 5), (4 + (ct - 4) * .1, 0, ch * .95), (ct - 2, 0, ch), 6)]
    parte = tubo_afilado_brillo(cuello, 11, 9, "url(#escamas)", t["borde"], t["luz"], (3, t["mancha"]))
    if p["capucha"] > 0:
        # La capucha es un elipsoide plano detras de la cabeza: de frente se ve
        # ancha y de lado casi desaparece.
        rx, ry, giro = k.elipsoide(3, 6 + 10 * p["capucha"], 11)
        hx, hy = k.punto(ct - 4, 0, ch - 8)
        dentro = k.elipsoide(2, (6 + 10 * p["capucha"]) * .55, 7)
        parte += elipse(hx, hy, rx, ry, giro, "url(#escamas)", t["borde"], 2.2)
        if k.c > -.2:
            parte += elipse(hx, hy + 1, dentro[0], dentro[1], dentro[2], t["luz"], "none", 0, ' opacity=".45"')
            parte += elipse(hx, hy - 2, 2.4 * p["capucha"], 3 * p["capucha"], 0, t["mancha"], "none", 0, ' opacity=".8"')
    parte += _cabeza_serpiente(k, t, p, ct, ch)
    k.poner(ct, 0, parte, .1)
    dibujo = con_flash(k.pintar(), p["flash"])
    if p["escupe"] >= 0:
        dibujo += _escupitajo(k, t, ct + 18 + p["escupe"] * 14, ch - 3, p["escupe"])
    return lienzo(192, 192, f'<g opacity="{p["op"]:.2f}">{dibujo}</g>', defs)


def _cabeza_serpiente(k, t, p, ct, ch):
    hx, hy = k.punto(ct + 3, 0, ch)
    rx, ry, giro = k.elipsoide(10, 7.5, 6)
    piezas = [(0, elipse(hx, hy, rx, ry, giro, "url(#escamas)", t["borde"], 2.2))]
    if k.c < -.05:
        # La nuca, con su dibujo de rombos, para que de espaldas no sea una bola.
        nx, ny = k.punto(ct - 1, 0, ch + 4)
        op = min(1, -k.c * 2)
        piezas.append((.05, f'<path d="M{nx:.1f},{ny - 5:.1f} L{nx + 4:.1f},{ny:.1f} L{nx:.1f},{ny + 5:.1f} L{nx - 4:.1f},{ny:.1f} Z '
                            f'M{nx - 6:.1f},{ny - 1:.1f} L{nx - 3:.1f},{ny + 4:.1f} M{nx + 6:.1f},{ny - 1:.1f} L{nx + 3:.1f},{ny + 4:.1f}" '
                            f'fill="{t["mancha"]}" stroke="{t["mancha"]}" stroke-width="1.6" stroke-linecap="round" opacity="{op:.2f}"/>'))
    if p["boca"] > 0:
        # La mandibula de abajo cae y se ve la boca, con los colmillos.
        bx, by = k.punto(ct + 7, 0, ch - 3)
        piezas.append((.2, elipse(bx, by + 2 * p["boca"], rx * .7, 2 + 5 * p["boca"], giro, "#3a0a10", t["borde"], 1.4)))
        for lado in (-1, 1):
            fx, fy = k.punto(ct + 9, lado * 3, ch - 2)
            if k.c > -.3:
                piezas.append((.3, f'<path d="M{fx - 1:.1f},{fy:.1f} L{fx:.1f},{fy + 3 + 3 * p["boca"]:.1f} L{fx + 1:.1f},{fy:.1f} Z" fill="#ffffff"/>'))
    if p["lengua"]:
        a, b = k.punto(ct + 12, 0, ch - 1), k.punto(ct + 21, 0, ch - 2)
        c1, c2 = k.punto(ct + 25, 2.5, ch - 1), k.punto(ct + 25, -2.5, ch - 3)
        piezas.append((-.1 if k.c < 0 else .3, f'<path d="M{P(*a)} L{P(*b)} L{P(*c1)} M{P(*b)} L{P(*c2)}" fill="none" stroke="#e8304a" stroke-width="1.6" stroke-linecap="round"/>'))
    for lado in (-1, 1):
        ex, ey = k.punto(ct + 6, lado * 4.5, ch + 3)
        mira = .5 * k.c - .85 * lado * k.s
        if mira > .15 and p["ojos"] > 0:
            esc = 3.2 * min(1, .5 + mira)
            piezas.append((.4, f'<circle cx="{ex:.1f}" cy="{ey:.1f}" r="5" fill="{t["ojo"]}" opacity=".3" filter="url(#brillo)"/>'
                               f'<ellipse cx="{ex:.1f}" cy="{ey:.1f}" rx="{esc:.1f}" ry="{3.2 * p["ojos"]:.1f}" fill="{t["ojo"]}" stroke="{t["borde"]}" stroke-width="1.1"/>'
                               f'<ellipse cx="{ex:.1f}" cy="{ey:.1f}" rx=".8" ry="{2.6 * p["ojos"]:.1f}" fill="#100800"/>'
                               # la ceja de escama, que le da mala cara
                               f'<path d="M{ex - 3.5:.1f},{ey - 2.5 + lado * k.s:.1f} L{ex + 3.5:.1f},{ey - 4.2 - lado * k.s:.1f}" stroke="{t["borde"]}" stroke-width="1.8" stroke-linecap="round"/>'))
        elif mira > .15:
            piezas.append((.4, f'<path d="M{ex - 2.5:.1f},{ey - 2.5:.1f} l5,5 M{ex + 2.5:.1f},{ey - 2.5:.1f} l-5,5" stroke="{t["borde"]}" stroke-width="1.6"/>'))
    return "".join(x for _, x in sorted(piezas, key=lambda q: q[0]))


def _escupitajo(k, t, adelante, alto, paso):
    x, y = k.punto(adelante, 0, alto)
    r = 6 - paso
    out = f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{r + 5:.1f}" fill="{t["veneno"]}" opacity=".35" filter="url(#brillo)"/>'
    out += f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{r:.1f}" fill="{t["veneno"]}" stroke="#2a5a0a" stroke-width="1.4"/>'
    out += f'<circle cx="{x - r * .3:.1f}" cy="{y - r * .35:.1f}" r="{r * .35:.1f}" fill="#ffffff" opacity=".7"/>'
    for i in range(3):
        gx, gy = k.punto(adelante - 6 - i * 5, (i - 1) * 3, alto - 1 - i)
        out += f'<circle cx="{gx:.1f}" cy="{gy:.1f}" r="{2 - i * .5:.1f}" fill="{t["veneno"]}" opacity="{.8 - i * .2:.2f}"/>'
    return out


# =============================================== 4. PLANTA VENENOSA ===
# Lienzo de 192, el suelo en y = 164. Un bulbo con raices y una corona de hojas
# que cuelgan; arriba, la boca por la que suelta el anillo de veneno. Tres ojos
# en la cara del bulbo dicen hacia donde mira.
PLANTA_V = dict(bulbo=("#b8e070", "#4e8a28", "#1a3a10"), hoja=("#4e9030", "#163e0e"), borde="#081206",
                veneno="#b0ff4a", boca="#2a0a20", ojo="#e8ff6a", nervio="#d8f0a0")
PV_ALTO = 46


def pose_planta_v(anim, f):
    p = dict(squash=0.0, caida=0.0, abre=0.15, hojas=0.0, onda=f * math.pi / 2, inclina=0.0, flash=False,
             anillo=-1, marchita=0.0, ojos=1.0, op=1.0, raices=f)
    if anim == "caminar":
        p.update(squash=[0, .04, 0, -.04][f], inclina=[0, 2, 0, -2][f])
    elif anim == "atacar":
        # Se encoge, levanta las hojas y revienta hacia arriba soltando el anillo.
        p.update(squash=[0, .14, .22, -.16, -.06, 0][f], hojas=[0, .3, .6, 1, .7, .2][f],
                 abre=[.15, .25, .4, 1, .7, .3][f], anillo=[-1, -1, -1, 0, 1, -1][f], onda=0)
    elif anim == "dano":
        p.update(flash=f == 0, inclina=[-8, -5, -2][f], squash=[.1, .05, 0][f], hojas=[.4, -.2, 0][f], ojos=[.3, .6, 1][f])
    elif anim == "muerte":
        q = f / 7
        p.update(flash=f == 0, marchita=q, squash=.1 + .5 * q, hojas=-1.2 * q, abre=.15 * (1 - q), ojos=max(0, 1 - f / 2),
                 op=1 - max(0, f - 5) / 3, onda=0)
    return p


def _mezcla(a, b, q):
    a, b = a.lstrip("#"), b.lstrip("#")
    return "#" + "".join(f"{round(int(a[i:i + 2], 16) * (1 - q) + int(b[i:i + 2], 16) * q):02x}" for i in (0, 2, 4))


def hoja_colgante(tres, ancho, colores, borde, nervio):
    """Una hoja de la base a la punta por una curva (tres puntos de pantalla):
    ancha en medio y en punta. Rellena de color liso: con un degradado de
    objectBoundingBox, una hoja que cae recta tiene caja de ancho 0 y sale negra."""
    (x0, y0), (x1, y1), (x2, y2) = tres
    izq, der, medio = [], [], []
    for j in range(11):
        q = j / 10
        x = (1 - q) ** 2 * x0 + 2 * (1 - q) * q * x1 + q * q * x2
        y = (1 - q) ** 2 * y0 + 2 * (1 - q) * q * y1 + q * q * y2
        dx = 2 * (1 - q) * (x1 - x0) + 2 * q * (x2 - x1)
        dy = 2 * (1 - q) * (y1 - y0) + 2 * q * (y2 - y1)
        L = math.hypot(dx, dy) or 1
        w = ancho * math.sin(math.pi * min(1, q * 1.05)) ** .7 * (1 - .15 * q)
        izq.append((x - dy / L * w, y + dx / L * w))
        der.append((x + dy / L * w, y - dx / L * w))
        medio.append((x, y))
    d = "M" + " L".join(P(*q) for q in izq + list(reversed(der))) + " Z"
    return (f'<path d="{d}" fill="{colores[0]}" stroke="{borde}" stroke-width="2" stroke-linejoin="round"/>'
            f'<path d="M{" L".join(P(*q) for q in der[1:-1])}" fill="none" stroke="{colores[1]}" stroke-width="{ancho * .6:.1f}" opacity=".6"/>'
            f'<path d="M{" L".join(P(*q) for q in medio[:9])}" fill="none" stroke="{nervio}" stroke-width="1.2" opacity=".8"/>')


def svg_planta_venenosa(anim, theta, f):
    t = PLANTA_V
    p = pose_planta_v(anim, f)
    seca = p["marchita"]
    # Al morir se seca: los verdes van hacia el marron.
    bulbo = [_mezcla(c, m, seca * .8) for c, m in zip(t["bulbo"], ("#c8a868", "#6a4a24", "#2a1a0a"))]
    hoja = [_mezcla(c, m, seca * .8) for c, m in zip(t["hoja"], ("#a88a48", "#4a3018"))]
    defs = degradado("bulboV", bulbo, True, .38, .3, .85) + degradado("hojaV", hoja, x2=0, y2=1)
    k = Cuerpo(theta, 96, 164)
    out = sombra(96, 166, 44, 12)
    alto = PV_ALTO * (1 - p["squash"])
    ancho = 21 * (1 + p["squash"] * .8)
    inc = p["inclina"]
    # Raices por el suelo, alrededor del pie.
    for i in range(6):
        phi = i * 60 + 15
        r1 = 30 + 4 * math.sin(p["raices"] * 1.6 + i)
        a, b = math.radians(phi), math.radians(phi + 18)
        puntos = [k.punto(14 * math.cos(a), 14 * math.sin(a), 2), k.punto(r1 * .7 * math.cos(a + .2), r1 * .7 * math.sin(a + .2), 0),
                  k.punto(r1 * math.cos(b), r1 * math.sin(b), 0)]
        k.poner(-40, 0, tubo_afilado(puntos, 3.4, .8, hoja[1], t["borde"]))
    # El bulbo: un jarron que se ensancha y se cierra arriba.
    cx, base = k.x + inc * .5, k.y
    perfil = []
    for j in range(13):
        h = alto * j / 12
        w = ancho * (.55 + .45 * math.sin(math.pi * (.12 + .78 * j / 12))) * (1 - .25 * (j / 12) ** 3)
        perfil.append((w, h, inc * j / 12))
    lado_d = [(cx + w + d, base - h) for w, h, d in perfil]
    lado_i = [(cx - w + d, base - h) for w, h, d in reversed(perfil)]
    d = "M" + " L".join(P(*q) for q in lado_d + lado_i) + " Z"
    cuerpo = f'<path d="{d}" fill="url(#bulboV)" stroke="{t["borde"]}" stroke-width="2.6" stroke-linejoin="round"/>'
    # Nervios verticales: giran con el cuerpo, asi se ve que gira.
    for i in range(8):
        phi = math.radians(i * 45 + 22.5)
        z = math.cos(math.radians(theta) + phi)
        if z < .1:
            continue
        xs = math.sin(math.radians(theta) + phi)
        pts = [P(cx + w * xs + dd, base - h - z * w * PROF) for w, h, dd in perfil[1:-1]]
        cuerpo += f'<path d="M{" L".join(pts)}" fill="none" stroke="{t["nervio"]}" stroke-width="{1.6 * z:.1f}" opacity="{.5 * z:.2f}"/>'
    # Pustulas moradas: lo que avisa de que es venenosa.
    for phi, h, r in ((70, .35, 3.6), (130, .6, 3), (200, .3, 4), (250, .62, 3.2), (305, .4, 3.4), (160, .2, 2.6)):
        z = math.cos(math.radians(theta + phi))
        if z > .05:
            w = ancho * .9
            gx = cx + w * math.sin(math.radians(theta + phi)) + inc * h
            gy = base - alto * h - z * w * PROF
            cuerpo += (f'<ellipse cx="{gx:.1f}" cy="{gy:.1f}" rx="{r * (.3 + .7 * z):.1f}" ry="{r:.1f}" fill="#8a3a9a" stroke="{t["borde"]}" stroke-width="1"/>'
                       f'<circle cx="{gx - r * .3 * z:.1f}" cy="{gy - r * .35:.1f}" r="{r * .35:.1f}" fill="#e0a0f0" opacity=".8"/>')
    # Los ojos, en la cara: tres, en triangulo.
    for phi, h, r in ((-20, .52, 4.2), (20, .52, 4.2), (0, .34, 3.4)):
        z = math.cos(math.radians(theta + phi))
        if z > .15 and p["ojos"] > 0:
            w = ancho * .92
            ex = cx + w * math.sin(math.radians(theta + phi)) + inc * h
            ey = base - alto * h - z * w * PROF
            cuerpo += (f'<circle cx="{ex:.1f}" cy="{ey:.1f}" r="{r + 4:.1f}" fill="{t["ojo"]}" opacity="{.3 * z:.2f}" filter="url(#brillo)"/>'
                       f'<ellipse cx="{ex:.1f}" cy="{ey:.1f}" rx="{r * z:.1f}" ry="{r * p["ojos"]:.1f}" fill="{t["ojo"]}" stroke="{t["borde"]}" stroke-width="1.2"/>'
                       f'<ellipse cx="{ex:.1f}" cy="{ey:.1f}" rx="{r * .3 * z:.1f}" ry="{r * .8 * p["ojos"]:.1f}" fill="#0a1a04"/>')
    k.poner(0, 0, cuerpo)
    # La boca de arriba: un agujero con dientes, que se abre para disparar.
    tx, ty = cx + inc, base - alto
    rb = 11 * (.5 + .5 * p["abre"])
    boca = elipse(tx, ty, rb + 3, (rb + 3) * PIES, 0, bulbo[1], t["borde"], 2.2)
    boca += elipse(tx, ty, rb, rb * PIES, 0, t["boca"], "none", 0)
    boca += elipse(tx, ty + 1, rb * .6, rb * .6 * PIES, 0, t["veneno"], "none", 0, f' opacity="{.4 + .5 * p["abre"]:.2f}" filter="url(#brillo)"')
    for i in range(10):
        a = math.radians(i * 36)
        x0, y0 = tx + (rb + 1) * math.cos(a), ty + (rb + 1) * math.sin(a) * PIES
        x1, y1 = tx + (rb - 3 * (1 - p["abre"] * .5)) * math.cos(a), ty + (rb - 3) * math.sin(a) * PIES
        boca += f'<path d="M{x0 - 1.4:.1f},{y0:.1f} L{x1:.1f},{y1:.1f} L{x0 + 1.4:.1f},{y0:.1f} Z" fill="#f0f0d8"/>'
    k.poner(0, 0, boca, .2)
    # La corona de hojas, que cuelgan desde el borde de la boca. Ninguna por
    # delante: taparia los ojos, que son lo que dice hacia donde mira.
    for i, grados in enumerate((62, 100, 140, 180, 220, 260, 298)):
        phi = math.radians(grados)
        sube = p["hojas"]
        cae = 30 - 40 * sube
        largo = 30 + 5 * (i % 2)
        ond = 3 * math.sin(p["onda"] + i * 1.3)
        tres = []
        for r, de, h in ((11, 0, alto + 1), (25, ond, alto + 8 + 6 * sube), (largo + 3, ond * 2, alto - cae)):
            tt, uu = r * math.cos(phi) - de * math.sin(phi), r * math.sin(phi) + de * math.cos(phi)
            x, y = k.punto(tt, uu, max(2, h))
            tres.append((x + inc, y))
        hondo = k.hondo(24 * math.cos(phi), 24 * math.sin(phi))
        k.poner(24 * math.cos(phi), 24 * math.sin(phi), hoja_colgante(tres, 7.5, hoja, t["borde"], t["nervio"]),
                .3 if hondo > 0 else -.1)
    dibujo = con_flash(k.pintar(), p["flash"])
    if p["anillo"] >= 0:
        dibujo += _anillo_veneno(tx, ty, p["anillo"], t)
    return lienzo(192, 192, f'<g opacity="{p["op"]:.2f}">{dibujo}</g>', defs)


def _anillo_veneno(x, y, paso, t):
    """Lo que sale por la boca: una nube y gotas hacia todos lados."""
    r = 16 + paso * 18
    out = f'<path d="{blob_d(x, y - 6 - paso * 4, 12 + paso * 6, paso + 3, 7, .2)}" fill="{t["veneno"]}" opacity="{.45 - paso * .2:.2f}" filter="url(#brillo)"/>'
    for i in range(8):
        a = math.radians(i * 45)
        gx, gy = x + r * math.cos(a), y - 4 + r * math.sin(a) * PIES - (6 - paso * 3)
        out += (f'<circle cx="{gx:.1f}" cy="{gy:.1f}" r="4.5" fill="{t["veneno"]}" opacity=".35" filter="url(#brillo)"/>'
                f'<circle cx="{gx:.1f}" cy="{gy:.1f}" r="{3 - paso * .6:.1f}" fill="{t["veneno"]}" stroke="#2a5a0a" stroke-width="1"/>')
    return out


# ==================================================== 5. MURCIELAGO ===
# Ya hay un murcielago dibujado asi (el del paquete, en tres capas): este es el
# mismo dibujo con el morado y los ojos rojos del de antes. Hacer otro distinto
# seria tener dos murcielagos que se dibujan de dos maneras.
def _paquete_enemigos():
    """El generar_enemigos.py del paquete hace 'import generar_magos', que aqui
    seria el nuestro: se le dan sus modulos mientras se carga y luego se dejan
    como estaban."""
    gm_paquete = _cargar("paquete_magos", "generar_magos.py")
    antes = {n: sys.modules.get(n) for n in ("generar_magos", "generar_hechizos")}
    sys.modules["generar_magos"], sys.modules["generar_hechizos"] = gm_paquete, gh
    try:
        return _cargar("paquete_enemigos", "generar_enemigos.py")
    finally:
        for n, m in antes.items():
            if m is None:
                sys.modules.pop(n, None)
            else:
                sys.modules[n] = m


ge = _paquete_enemigos()
TEMA_MURCIELAGO = dict(ge.TEMAS["corteza"], membrana=("#6a3a8a", "#24102e"), pelo=("#8a5aa8", "#2a1238"),
                       ojo="#ff3a3a", contorno="#0e0614", extra="musgo")


def svg_murcielago(anim, theta, f):
    texto = ge.svg_murcielago(TEMA_MURCIELAGO, anim, theta, f)
    return texto.replace("#8a7064", "#c8a0e0")      # los huesos del ala, lila y no marrones


# =================================================== 6. GOLEM DE ROCA ===
# Lienzo de 192, el suelo en y = 166. Un cono de roca oscura con los ojos y una
# grieta de lava encendidos, dos punos que flotan a los lados y dos pies
# cortos. Ataca con un pisoton: salta y, al caer, sale la onda.
GOLEM_R = dict(roca=("#8a7a72", "#3e3432", "#141010"), contorno="#0a0606", grieta="#ff8a1a", grieta2="#ffe08a",
               ojo="#ffc83a", polvo="#6a5a52")
GR_ALTO, GR_ANCHO = 64, 36
# La grieta, en la superficie del cono: (angulo alrededor, altura de 0 a 1).
GR_GRIETAS = [[(-30, .15), (-22, .3), (-28, .42), (-14, .55)], [(-22, .3), (-6, .26)], [(150, .2), (165, .4), (158, .58)],
              [(40, .1), (48, .24)]]
GR_ARISTAS = [20, 95, 160, 230, 300]
GR_TROZOS = [(phi, h, r) for phi, h, r in ((-60, .2, 13), (40, .25, 12), (180, .3, 14), (110, .55, 10), (-120, .5, 11),
                                           (0, .78, 9), (250, .15, 12), (70, .05, 11))]


def pose_golem_roca(anim, f):
    p = dict(squash=0.0, salto=0.0, inclina=0.0, paso=0.0, punos=0.0, puno_baja=0.0, flash=False, onda=-1,
             grietas=.75, roto=None, ojos=1.0, astillas=False)
    if anim == "caminar":
        p.update(inclina=[3, 0, -3, 0][f], paso=[1, 0, -1, 0][f], salto=[0, 2, 0, 2][f])
    elif anim == "atacar":
        p.update(squash=[0, .12, -.08, .18, .06, 0][f], salto=[0, 0, 18, 0, 0, 0][f], punos=[0, .6, 1, -.4, -.2, 0][f],
                 puno_baja=[0, 0, 0, 1, .6, 0][f], onda=[-1, -1, -1, 0, 1, -1][f], grietas=[.75, .9, 1, 1, .9, .8][f])
    elif anim == "dano":
        p.update(flash=f == 0, inclina=[-7, -4, -1][f], squash=[.06, .02, 0][f], astillas=f < 2, ojos=[.4, .7, 1][f])
    elif anim == "muerte":
        if f < 3:
            p.update(flash=f == 0, inclina=[-6, -3, 0][f], grietas=[1, 1.3, 1.6][f], ojos=[.6, .4, .3][f], squash=[.04, .02, 0][f])
        else:
            p.update(roto=(f - 3) / 4, ojos=0.0)
    return p


def piedra(x, y, r, semilla, achatar=1.0, lados=7):
    """Un canto de roca: un poligono irregular con las esquinas redondeadas.
    (blob_d, con pocos lados, sale con puntas de estrella.)"""
    azar = random.Random(semilla)
    pts = []
    for i in range(lados):
        a = TAU * i / lados + azar.uniform(-.25, .25)
        rr = r * azar.uniform(.8, 1.05)
        pts.append((x + rr * math.cos(a), y + rr * math.sin(a) * achatar))
    d = ""
    for i in range(lados):
        a, b, c = pts[i - 1], pts[i], pts[(i + 1) % lados]
        m1 = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
        m2 = ((b[0] + c[0]) / 2, (b[1] + c[1]) / 2)
        d += (f"M{P(*m1)} " if i == 0 else "") + f"Q{P(*b)} {P(*m2)} "
    return d + "Z"


def _ancho_cono(h01):
    return GR_ANCHO * (1 - h01) ** .75 + 5 * (1 - abs(h01 - .5))


def svg_golem_roca(anim, theta, f):
    t = GOLEM_R
    p = pose_golem_roca(anim, f)
    defs = degradado("rocaG", t["roca"], True, .36, .28, .85) + degradado("rocaP", t["roca"], True, .4, .3, .7)
    cx, suelo = 96, 166
    out = sombra(cx, suelo + 2, 44 - p["salto"] * .6, 13 - p["salto"] * .2)
    if p["onda"] >= 0:
        out += _onda_pisoton(cx, suelo, p["onda"], t)
    if p["roto"] is not None:
        return lienzo(192, 192, out + _golem_roto(theta, p["roto"], t), defs)
    s, c = sc(theta)
    alto = GR_ALTO * (1 - p["squash"])
    escx = 1 + p["squash"] * .7
    base = suelo - 6 - p["salto"]
    piezas = []
    # Los pies: dos, cortos, delante.
    for lado in (-1, 1):
        x, y, z = cil(theta, lado * 40, 20 * escx, cx, suelo - 3 - p["salto"])
        y -= max(0, p["paso"] * lado) * 4
        x += p["paso"] * lado * 3 * s
        piezas.append((z - .5, f'<path d="{piedra(x, y, 10, lado + 2, .6)}" fill="url(#rocaP)" stroke="{t["contorno"]}" stroke-width="2.2"/>'))
    # El cono.
    perfil = [(_ancho_cono(j / 14) * escx, alto * j / 14) for j in range(15)]
    der = [(cx + w + p["inclina"] * h / alto, base - h) for w, h in perfil]
    izq = [(cx - w + p["inclina"] * h / alto, base - h) for w, h in reversed(perfil)]
    w0 = perfil[0][0]
    abajo = [(cx + w0 * math.cos(math.radians(a)), base + w0 * PIES * .5 * math.sin(math.radians(a))) for a in range(180, 0, -15)]
    d = "M" + " L".join(P(*q) for q in der + izq + abajo) + " Z"
    cono = f'<path d="{d}" fill="url(#rocaG)" stroke="{t["contorno"]}" stroke-width="2.8" stroke-linejoin="round"/>'

    def en_cono(phi, h01, dentro=1.0):
        w = _ancho_cono(h01) * escx * dentro
        a = math.radians(theta + phi)
        return (cx + w * math.sin(a) + p["inclina"] * h01, base - alto * h01 - w * math.cos(a) * PROF, math.cos(a))
    # Aristas: giran con el cuerpo y dicen hacia donde mira.
    for phi in GR_ARISTAS:
        pts = [en_cono(phi, h) for h in (.04, .3, .6, .9)]
        if pts[0][2] > .1:
            cono += (f'<path d="M{" L".join(P(x, y) for x, y, _ in pts)}" fill="none" stroke="{t["contorno"]}" '
                     f'stroke-width="1.6" opacity="{.6 * pts[0][2]:.2f}"/>')
    for linea in GR_GRIETAS:
        pts = [en_cono(phi, h) for phi, h in linea]
        if min(z for _, _, z in pts) > .05:
            cono += ge.trazo_grieta([(x, y) for x, y, _ in pts], t, 2.2 * min(1.6, p["grietas"]), min(1, p["grietas"]))
    # La cara: la sombra de la frente, que cae sobre los ojos, y los ojos,
    # rasgados hacia el centro (enfadados).
    if c > -.3:
        for lado in (-1, 1):
            ex, ey, z = en_cono(lado * 21, .56, .93)
            if z > .1 and p["ojos"] > 0:
                ab = 3.4 * p["ojos"]
                cono += (f'<path d="M{ex - 9 * z:.1f},{ey - 7 + lado * 3:.1f} L{ex + 9 * z:.1f},{ey - 7 - lado * 3:.1f} L{ex + 8 * z:.1f},{ey - 1:.1f} L{ex - 8 * z:.1f},{ey - 1:.1f} Z" fill="{t["roca"][2]}" opacity=".7"/>'
                         f'<ellipse cx="{ex:.1f}" cy="{ey + 1:.1f}" rx="10" ry="6" fill="{t["ojo"]}" opacity="{.4 * z:.2f}" filter="url(#brillo)"/>'
                         f'<path d="M{ex - 7 * z:.1f},{ey - 1 + lado * 2:.1f} L{ex + 7 * z:.1f},{ey - 1 - lado * 2:.1f} '
                         f'L{ex + 5 * z:.1f},{ey + ab:.1f} L{ex - 5 * z:.1f},{ey + ab:.1f} Z" fill="{t["ojo"]}" stroke="{t["contorno"]}" stroke-width="1.2" stroke-linejoin="round"/>'
                         f'<path d="M{ex - 3 * z:.1f},{ey + .5:.1f} L{ex + 3 * z:.1f},{ey + .5:.1f}" stroke="#fff8d0" stroke-width="1.6" stroke-linecap="round"/>')
    piezas.append((0, cono))
    # Los punos, que flotan a los lados.
    for lado in (-1, 1):
        h = 22 + 26 * max(0, p["punos"]) - 20 * p["puno_baja"] + [0, 2, 0, -2][f % 4] * lado * (p["punos"] == 0)
        adelante = 60 + 10 * p["paso"] * -lado
        x, y, z = cil(theta, lado * adelante, 44 * escx, cx, base)
        y -= h
        if p["puno_baja"] > .5:
            y = min(y, suelo - 10)
        puno = f'<path d="{piedra(x, y, 13, lado + 5, .9)}" fill="url(#rocaP)" stroke="{t["contorno"]}" stroke-width="2.4"/>'
        puno += f'<path d="M{x - 6:.1f},{y - 3:.1f} l4,-1 M{x - 2:.1f},{y - 5:.1f} l4,0 M{x + 2:.1f},{y - 4:.1f} l4,1" stroke="{t["contorno"]}" stroke-width="1.4" opacity=".7"/>'
        puno += f'<circle cx="{x + 2:.1f}" cy="{y + 4:.1f}" r="2" fill="{t["grieta"]}" opacity=".8" filter="url(#brillo)"/>'
        piezas.append((z * 1.2, puno))
    cuerpo = "".join(x for _, x in sorted(piezas, key=lambda q: q[0]))
    out += con_flash(cuerpo, p["flash"])
    if p["astillas"]:
        for i in range(5):
            a = math.radians(-150 + i * 30 + f * 10)
            r = 34 + f * 10
            out += f'<path d="{piedra(cx + r * math.cos(a), base - 40 + r * math.sin(a) * .6, 4, i, .8, 5)}" fill="{t["roca"][1]}" stroke="{t["contorno"]}" stroke-width="1"/>'
    return lienzo(192, 192, out, defs)


def _onda_pisoton(cx, suelo, paso, t):
    r = 34 + paso * 26
    op = .9 - paso * .4
    out = (f'<ellipse cx="{cx}" cy="{suelo:.1f}" rx="{r:.1f}" ry="{r * PIES:.1f}" fill="none" stroke="{t["grieta"]}" '
           f'stroke-width="{6 - paso * 2:.1f}" opacity="{op:.2f}" filter="url(#brillo)"/>'
           f'<ellipse cx="{cx}" cy="{suelo:.1f}" rx="{r:.1f}" ry="{r * PIES:.1f}" fill="none" stroke="{t["grieta2"]}" stroke-width="1.6" opacity="{op:.2f}"/>')
    for i in range(7):
        a = math.radians(i * 51 + 10)
        x, y = cx + (r + 4) * math.cos(a), suelo + (r + 4) * math.sin(a) * PIES - 4 - 6 * (1 - paso)
        out += f'<path d="{piedra(x, y, 4.5 - paso, i, .8, 5)}" fill="{t["polvo"]}" stroke="{t["contorno"]}" stroke-width="1" opacity="{op:.2f}"/>'
    return out


def _golem_roto(theta, q, t):
    """Se parte en trozos que caen, se apagan y se van."""
    out = ""
    cx, suelo = 96, 166
    op = 1 - max(0, q - .5) / .5
    for i, (phi, h, r) in enumerate(GR_TROZOS):
        a = math.radians(theta + phi)
        lejos = 14 + 26 * min(1, q * 1.6)
        x = cx + math.sin(a) * lejos
        y0 = suelo - 10 - GR_ALTO * h
        y = y0 + (suelo - 8 - y0) * min(1, q * 1.8) + math.cos(a) * lejos * PIES
        brilla = max(0, 1 - q * 1.5)
        out += f'<path d="{piedra(x, y, r, i + 11, .8)}" fill="url(#rocaP)" stroke="{t["contorno"]}" stroke-width="2"/>'
        if brilla > 0:
            out += f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{r * .45:.1f}" fill="{t["grieta"]}" opacity="{.8 * brilla:.2f}" filter="url(#brillo)"/>'
    if q < .5:
        out += f'<path d="{blob_d(cx, suelo - 14, 30 + q * 30, 3, 7, .2, achatar=.5)}" fill="{t["polvo"]}" opacity="{.5 - q:.2f}" filter="url(#difuso)"/>'
    return f'<g opacity="{op:.2f}">{out}</g>'


# ==================================================== 7. CRISTAL VIVO ===
# Lienzo de 192, el suelo en y = 162. Un racimo de amatistas sobre una roca, con
# un ojo en el cristal grande. Se teletransporta y dispara un rayo: al atacar el
# ojo se abre, el racimo se enciende y suelta el rayo hacia delante.
CRISTAL = dict(cara=("#f4dcff", "#b47af0"), sombra=("#7a3ac8", "#2e0c56"), contorno="#14061e", brillo="#e8b0ff",
               roca=("#6a5a70", "#2e2434", "#100a14"), iris="#ff4ad8", rayo="#ffb0f8")
# (angulo, distancia al centro, largo, ancho, inclinacion hacia fuera en grados)
CR_RACIMO = [(40, 12, 40, 9, 22), (-45, 12, 36, 8, 25), (110, 14, 30, 8, 35), (-115, 14, 32, 8, 35), (180, 10, 46, 10, 16),
             (150, 17, 24, 6, 45), (-160, 17, 26, 6, 45), (75, 19, 18, 5, 55), (-80, 19, 18, 5, 55), (0, 20, 14, 5, 60)]


def pose_cristal(anim, f):
    p = dict(bob=[0, -1.5, -2, -1.5][f % 4], brillo=.5 + .15 * math.sin(f * math.pi / 2), ojo=1.0, mira=(0.0, 0.0),
             carga=0.0, rayo=-1, flash=False, grieta=0.0, roto=None, tiembla=0.0, op=1.0)
    if anim == "caminar":
        p["mira"] = [(0, 0), (.4, 0), (0, 0), (-.4, 0)][f]
    elif anim == "atacar":
        p.update(bob=0, ojo=[1, 1.25, 1.3, 1.1, 1, 1][f], brillo=[.5, .8, 1, 1.2, .8, .5][f],
                 carga=[0, .3, .8, 0, 0, 0][f], rayo=[-1, -1, -1, 0, 1, -1][f])
    elif anim == "dano":
        p.update(flash=f == 0, tiembla=[3, -2, 1][f], grieta=.6, ojo=[.2, .5, .9][f])
    elif anim == "muerte":
        if f < 3:
            p.update(flash=f == 0, tiembla=[3, -3, 2][f], grieta=[.7, 1, 1.4][f], brillo=[.8, 1.1, 1.4][f], ojo=[.6, .3, .1][f])
        else:
            p.update(roto=(f - 3) / 4)
    return p


def amatista(bx, by, tx, ty, w, giro, t, brillo, z=1.0):
    """Un cristal de la base a la punta. La arista del medio se corre con el
    giro (giro: angulo del cristal respecto a la camara), asi el racimo se ve
    girar: una cara con luz, la otra en sombra."""
    dx, dy = tx - bx, ty - by
    L = math.hypot(dx, dy) or 1
    nx, ny = -dy / L, dx / L
    m = (bx + dx * .68, by + dy * .68)
    i, d = (m[0] - nx * w, m[1] - ny * w), (m[0] + nx * w, m[1] + ny * w)
    bi, bd = (bx - nx * w * .85, by - ny * w * .85), (bx + nx * w * .85, by + ny * w * .85)
    k = math.sin(math.radians(giro)) * .7
    arista_m = (m[0] + nx * w * k, m[1] + ny * w * k)
    arista_b = (bx + nx * w * .85 * k, by + ny * w * .85 * k)
    luz = f"M{P(*bi)} L{P(*i)} L{P(tx, ty)} L{P(*arista_m)} L{P(*arista_b)} Z"
    osc = f"M{P(*arista_b)} L{P(*arista_m)} L{P(tx, ty)} L{P(*d)} L{P(*bd)} Z"
    todo = f"M{P(*bi)} L{P(*i)} L{P(tx, ty)} L{P(*d)} L{P(*bd)} Z"
    op_luz = .55 + .45 * max(0, math.cos(math.radians(giro + 40)))
    return (f'<path d="{todo}" fill="url(#cristalS)" stroke="{t["contorno"]}" stroke-width="2" stroke-linejoin="round"/>'
            f'<path d="{luz}" fill="url(#cristalC)" opacity="{op_luz:.2f}"/>'
            f'<path d="{todo}" fill="{t["brillo"]}" opacity="{.18 * brillo:.2f}"/>'
            f'<path d="M{P(*arista_b)} L{P(*arista_m)} L{P(tx, ty)}" fill="none" stroke="#ffffff" stroke-width="1.1" opacity=".55"/>'
            f'<path d="{todo}" fill="none" stroke="{t["contorno"]}" stroke-width="2" stroke-linejoin="round"/>')


def svg_cristal_vivo(anim, theta, f):
    t = CRISTAL
    p = pose_cristal(anim, f)
    defs = (degradado("cristalC", t["cara"]) + degradado("cristalS", t["sombra"]) + degradado("rocaC", t["roca"], True, .4, .3, .8)
            + f'<radialGradient id="auraC"><stop offset="0" stop-color="{t["iris"]}" stop-opacity=".5"/><stop offset="1" stop-color="{t["iris"]}" stop-opacity="0"/></radialGradient>')
    cx, suelo = 96 + p["tiembla"], 162
    out = sombra(96, suelo + 2, 40, 12)
    out += f'<ellipse cx="96" cy="{suelo - 30}" rx="{46 + 10 * p["brillo"]:.1f}" ry="{40 + 8 * p["brillo"]:.1f}" fill="url(#auraC)" opacity="{.5 * p["brillo"]:.2f}"/>'
    if p["roto"] is not None:
        return lienzo(192, 192, out + _cristal_roto(theta, p["roto"], t), defs)
    base = suelo - 8 + p["bob"]
    piezas = [(-5, f'<path d="{piedra(cx, base + 2, 26, 4, .45, 8)}" fill="url(#rocaC)" stroke="{t["contorno"]}" stroke-width="2.4"/>')]
    for i, (phi, r, largo, ancho, inc) in enumerate(CR_RACIMO):
        a = math.radians(theta + phi)
        x, y, z = cil(theta, phi, r, cx, base)
        fuera = largo * math.sin(math.radians(inc))
        tx = x + math.sin(a) * fuera
        ty = y - largo * math.cos(math.radians(inc)) + math.cos(a) * fuera * PROF
        piezas.append((z, amatista(x, y, tx, ty, ancho, theta + phi, t, p["brillo"])))
    # El grande, con el ojo.
    alto = 64
    grande = amatista(cx, base, cx + 2 * math.sin(math.radians(theta)), base - alto, 15, theta, t, p["brillo"])
    c = math.cos(math.radians(theta))
    if c > .05:
        ex, ey = cx + 7 * math.sin(math.radians(theta)), base - 36
        ab = 6 * min(1.3, p["ojo"])
        grande += (f'<ellipse cx="{ex:.1f}" cy="{ey:.1f}" rx="{9 * c:.1f}" ry="{max(.6, ab):.1f}" fill="url(#escleraE)" stroke="{t["contorno"]}" stroke-width="1.6"/>'
                   f'<ellipse cx="{ex + p["mira"][0] * 4 * c:.1f}" cy="{ey:.1f}" rx="{4 * c:.1f}" ry="{min(ab, 4.2):.1f}" fill="{t["iris"]}"/>'
                   f'<ellipse cx="{ex + p["mira"][0] * 4 * c:.1f}" cy="{ey:.1f}" rx="{1.2 * c:.1f}" ry="{min(ab, 3.4):.1f}" fill="#1a0418"/>'
                   f'<circle cx="{ex - 2 * c:.1f}" cy="{ey - 2:.1f}" r="1.2" fill="#ffffff"/>')
        if p["carga"] > 0:
            grande += (f'<circle cx="{ex:.1f}" cy="{ey:.1f}" r="{6 + 10 * p["carga"]:.1f}" fill="{t["rayo"]}" opacity=".5" filter="url(#brillo)"/>'
                       f'<circle cx="{ex:.1f}" cy="{ey:.1f}" r="{3 + 4 * p["carga"]:.1f}" fill="#ffffff"/>')
    if p["grieta"] > 0:
        g = p["grieta"]
        pts = [(cx - 3, base - 20), (cx + 4, base - 30), (cx - 2, base - 40 - 8 * g), (cx + 5, base - 48 - 6 * g)]
        grande += (f'<path d="M{" L".join(P(*q) for q in pts[:2 + int(g * 1.5)])}" fill="none" stroke="#ffffff" stroke-width="{1.4 + g:.1f}" '
                   f'stroke-linejoin="round" opacity=".9" filter="url(#brillo)"/>')
    piezas.append((0.05, grande))
    dibujo = "".join(x for _, x in sorted(piezas, key=lambda q: q[0]))
    out += con_flash(dibujo, p["flash"])
    # Destellos alrededor, que dan vueltas.
    for i in range(3):
        a = math.radians(theta * .5 + i * 120 + f * 30)
        sx, sy = 96 + 34 * math.cos(a), suelo - 40 + 12 * math.sin(a)
        out += f'<path d="M{sx:.1f},{sy - 4:.1f} L{sx + 1:.1f},{sy - 1:.1f} L{sx + 4:.1f},{sy:.1f} L{sx + 1:.1f},{sy + 1:.1f} L{sx:.1f},{sy + 4:.1f} L{sx - 1:.1f},{sy + 1:.1f} L{sx - 4:.1f},{sy:.1f} L{sx - 1:.1f},{sy - 1:.1f} Z" fill="#ffffff" opacity=".8"/>'
    if p["rayo"] >= 0:
        out += _rayo_cristal(cx, base - 36, theta, p["rayo"], t)
    return lienzo(192, 192, out, defs)


def _rayo_cristal(x, y, theta, paso, t):
    s, c = sc(theta)
    largo = 90
    tx, ty = x + s * largo, y + c * largo * PIES + 10 * c
    w = 7 - paso * 3
    op = 1 - paso * .45
    return (f'<path d="M{x:.1f},{y:.1f} L{tx:.1f},{ty:.1f}" stroke="{t["iris"]}" stroke-width="{w * 2.6:.1f}" stroke-linecap="round" opacity="{.45 * op:.2f}" filter="url(#brillo)"/>'
            f'<path d="M{x:.1f},{y:.1f} L{tx:.1f},{ty:.1f}" stroke="{t["rayo"]}" stroke-width="{w:.1f}" stroke-linecap="round" opacity="{op:.2f}"/>'
            f'<path d="M{x:.1f},{y:.1f} L{tx:.1f},{ty:.1f}" stroke="#ffffff" stroke-width="{w * .35:.1f}" stroke-linecap="round" opacity="{op:.2f}"/>'
            f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{9 - paso * 3:.1f}" fill="#ffffff" opacity="{op:.2f}" filter="url(#brillo)"/>')


def _cristal_roto(theta, q, t):
    """Revienta: cada cristal sale despedido hacia fuera, cae y se apaga."""
    out = ""
    cx, suelo = 96, 162
    op = 1 - max(0, q - .55) / .45
    for i, (phi, r, largo, ancho, inc) in enumerate(CR_RACIMO + [(0, 0, 50, 12, 0)]):
        a = math.radians(theta + phi + 20 * i)
        lejos = 10 + 40 * min(1, q * 1.5) * (.6 + .4 * (i % 3) / 2)
        x = cx + math.sin(a) * lejos
        altura = (30 + 6 * (i % 4)) * (1 - min(1, q * 1.6)) + 6
        y = suelo - altura + math.cos(a) * lejos * PIES
        giro = math.radians(60 * i + 220 * q)
        L = largo * .45
        out += amatista(x - math.cos(giro) * L * .5, y - math.sin(giro) * L * .5, x + math.cos(giro) * L * .5,
                        y + math.sin(giro) * L * .5, ancho * .7, theta + phi, t, max(0, 1 - q * 2))
    out += f'<path d="{piedra(cx, suelo - 6, 24, 4, .45, 8)}" fill="url(#rocaC)" stroke="{t["contorno"]}" stroke-width="2.2"/>'
    if q < .6:
        out += f'<path d="{blob_d(cx, suelo - 30, 30 + q * 40, 5, 8, .2)}" fill="{t["brillo"]}" opacity="{.5 - q * .8:.2f}" filter="url(#difuso)"/>'
    return f'<g opacity="{op:.2f}">{out}</g>'


# ======================================================== 8. FANTASMA ===
# Lienzo de 192; flota, con la sombra en y = 166. Una sabana con la cabeza
# redonda, dos bracitos y el borde de abajo ondeando. Al atacar se lanza con la
# boca abierta; al morir se deshace hacia arriba.
FANTASMA = dict(cuerpo=("#ffffff", "#dce6ff", "#8a9ad8"), contorno="#1a1e3a", aura="#a8c0ff", boca="#1a1430",
                ojo="#1a1430", mejilla="#ffb8d8")
FA_ALTO, FA_ANCHO = 62, 24


def pose_fantasma(anim, f):
    p = dict(bob=[0, -3, -5, -3][f % 4], onda=f * math.pi / 2, lean=0.0, avance=0.0, brazos=0.0, boca=0.0,
             flash=False, op=1.0, deshace=0.0, estira=0.0, ojos=1.0, enfado=0.0)
    if anim == "atacar":
        p.update(bob=[0, -6, -2, 0, -2, -1][f], avance=[0, -6, 10, 18, 10, 2][f], lean=[0, -8, 12, 16, 8, 0][f],
                 brazos=[0, .6, 1, 1, .5, 0][f], boca=[0, .3, .8, 1, .5, 0][f], enfado=[0, .6, 1, 1, .6, .2][f],
                 estira=[0, -.06, .1, .14, .05, 0][f])
    elif anim == "dano":
        p.update(flash=f == 0, avance=[-8, -5, -2][f], lean=[-12, -7, -2][f], op=[1, .55, .85][f], ojos=[.3, .6, 1][f])
    elif anim == "muerte":
        q = f / 7
        p.update(flash=f == 0, deshace=q, op=1 - q * .85, bob=-q * 26, ojos=max(0, 1 - f / 2.5), brazos=.4 * (1 - q),
                 estira=.25 * q, boca=.4 * min(1, f / 2) * (1 - q))
    return p


def svg_fantasma(anim, theta, f):
    t = FANTASMA
    p = pose_fantasma(anim, f)
    defs = (degradado("sabana", t["cuerpo"], True, .38, .25, .9)
            + f'<radialGradient id="auraF"><stop offset="0" stop-color="{t["aura"]}" stop-opacity=".55"/><stop offset="1" stop-color="{t["aura"]}" stop-opacity="0"/></radialGradient>')
    s, c = sc(theta)
    cx = 96 + p["avance"] * s
    abajo = 150 + p["bob"] + p["avance"] * c * PIES
    out = sombra(96 + p["avance"] * s, 166 + p["avance"] * c * PIES, 26 + p["bob"] * .6, 7 - p["bob"] * .15, .8 * p["op"])
    alto = FA_ALTO * (1 + p["estira"])
    arriba = abajo - alto
    out += f'<ellipse cx="{cx:.1f}" cy="{abajo - alto * .5:.1f}" rx="44" ry="50" fill="url(#auraF)" opacity="{p["op"]:.2f}"/>'
    # La silueta: media esfera arriba, los lados que se abren un poco y el
    # borde de abajo en ondas que corren (la onda gira con el cuerpo, asi que
    # se ve dar la vuelta).
    lado_d, lado_i = [], []
    for j in range(10):
        a = math.pi / 2 * j / 9
        lado_d.append((cx + FA_ANCHO * math.sin(a), arriba + FA_ANCHO - FA_ANCHO * math.cos(a)))
    for j in range(1, 6):
        q = j / 5
        lado_d.append((cx + FA_ANCHO * (1 + .22 * q), arriba + FA_ANCHO + (alto - FA_ANCHO) * q))
    borde = []
    n = 24
    for j in range(n + 1):
        q = j / n
        x = cx + FA_ANCHO * 1.22 * (1 - 2 * q)
        y = abajo + 6 * math.sin(q * math.pi * 4 + p["onda"] + math.radians(theta) * 2) + 4 * math.sin(q * math.pi)
        borde.append((x, y))
    for x, y in reversed(lado_d):
        lado_i.append((2 * cx - x, y))
    lean = p["lean"]

    def doblar(pt):
        # Inclinarse: lo de abajo se queda atras y la cabeza va delante.
        x, y = pt
        k = (abajo - y) / alto
        return x + lean * k * s, y + abs(lean) * k * .15 * (1 if lean < 0 else -1)
    silueta = [doblar(q) for q in lado_d + borde + lado_i]
    d = "M" + " L".join(P(*q) for q in silueta) + " Z"
    cuerpo = ""
    # Los bracitos, a los lados: el de atras antes que el cuerpo. Cada uno sale
    # hacia su lado en 3D; de perfil, el de este lado apunta a la camara y se
    # queda en un munon redondo (las puntas redondas del trazo).
    brazos = []
    for lado in (-1, 1):
        a = math.radians(theta + lado * 80)
        x, y, z = cil(theta, lado * 80, FA_ANCHO * 1.02, cx, arriba + alto * .5)
        x, y = doblar((x, y))
        bx = x + 11 * math.sin(a) + 9 * p["brazos"] * s
        by = y + 11 * math.cos(a) * PROF + 5 - 9 * p["brazos"]
        brazos.append((z, tubo([(x, y), ((x + bx) / 2, (y + by) / 2 - 1), (bx, by)], 7, t["cuerpo"][1], t["contorno"], 2)))
    cuerpo += "".join(b for z, b in brazos if z < 0)
    cuerpo += f'<path d="{d}" fill="url(#sabana)" stroke="{t["contorno"]}" stroke-width="2.4" stroke-linejoin="round"/>'
    # Pliegues de la sabana, que giran con ella.
    for phi in (-50, 0, 50, 130, 180, 230):
        a = math.radians(theta + phi)
        if math.cos(a) < .2:
            continue
        x0 = cx + FA_ANCHO * .9 * math.sin(a)
        p0, p1 = doblar((x0, arriba + alto * .45)), doblar((x0 * 1.0 + 4 * math.sin(a), abajo - 2))
        cuerpo += f'<path d="M{P(*p0)} L{P(*p1)}" stroke="{t["cuerpo"][2]}" stroke-width="2" stroke-linecap="round" opacity="{.35 * math.cos(a):.2f}"/>'
    # La cara: cada ojo en su sitio de la cabeza (a 24 grados del centro), asi
    # de perfil se ve uno de lado y de espaldas ninguno.
    R = FA_ANCHO * .98
    hy0 = arriba + FA_ANCHO * .95
    if p["ojos"] > 0:
        for lado in (-1, 1):
            a = math.radians(theta + lado * 24)
            z = math.cos(a)
            if z < .12:
                continue
            ex, ey = doblar((cx + R * math.sin(a), hy0 + R * z * PROF * .3))
            rx, ry = 4.2 * z, 5.5 * p["ojos"]
            # Ojos huecos, con una luz fria al fondo: da mas miedo que el blanco.
            cuerpo += f'<ellipse cx="{ex:.1f}" cy="{ey:.1f}" rx="{rx:.1f}" ry="{ry:.1f}" fill="{t["ojo"]}"/>'
            cuerpo += f'<circle cx="{ex + lado * .6 * z:.1f}" cy="{ey + 1:.1f}" r="2.6" fill="#7ad8ff" opacity=".45" filter="url(#brillo)"/>'
            cuerpo += f'<circle cx="{ex + lado * .6 * z:.1f}" cy="{ey + 1:.1f}" r="1.2" fill="#c8f4ff"/>'
            if p["enfado"] > 0:
                # La punta de dentro, mas baja: enfadado y no triste.
                cuerpo += (f'<path d="M{ex - 5 * z:.1f},{ey - 7 + lado * 3 * p["enfado"]:.1f} L{ex + 5 * z:.1f},{ey - 7 - lado * 3 * p["enfado"]:.1f}" '
                           f'stroke="{t["ojo"]}" stroke-width="2.2" stroke-linecap="round"/>')
        z = c
        if z > .12:
            mx, my = doblar((cx + R * s, hy0 + 9))
            if p["boca"] > 0:
                cuerpo += f'<ellipse cx="{mx:.1f}" cy="{my + 1:.1f}" rx="{(4 + 4 * p["boca"]) * z:.1f}" ry="{2 + 7 * p["boca"]:.1f}" fill="{t["boca"]}"/>'
            else:
                cuerpo += f'<ellipse cx="{mx:.1f}" cy="{my:.1f}" rx="{2.6 * z:.1f}" ry="3" fill="{t["boca"]}"/>'
    cuerpo += "".join(b for z, b in brazos if z >= 0)
    dibujo = con_flash(cuerpo, p["flash"])
    if p["deshace"] > 0:
        # Se deshace en jirones que suben.
        q = p["deshace"]
        jirones = ""
        for i in range(6):
            a = i * 1.1
            jx = cx + 22 * math.sin(a + q * 3) * (1 - .3 * q)
            jy = abajo - alto * (.2 + .15 * i) - 40 * q - i * 4 * q
            jirones += f'<path d="{blob_d(jx, jy, 6 + 4 * q, i, 6, .25)}" fill="{t["aura"]}" opacity="{.5 * (1 - q):.2f}" filter="url(#difuso)"/>'
        dibujo = f'<g opacity="{1 - q * .7:.2f}">{dibujo}</g>' + jirones
    return lienzo(192, 192, f'<g opacity="{p["op"]:.2f}">{dibujo}</g>', defs)


# ===================================================== 9. PLANTA AZUL ===
# Lienzo de 192, el suelo en y = 164. Un capullo de cinco petalos azules que
# brillan, sobre un tallo corto y una roseta de hojas en el suelo. Por la
# juntura de delante asoman los dientes: es lo que dice hacia donde mira. Al
# atacar se abre del todo y muerde; vive bajo tierra, y al morir se hunde.
PLANTA_A = dict(petalo=("#a8f4ff", "#2ab4c8", "#0a4a5a"), hoja=("#2e6a2a", "#123a14"), borde="#04141a",
                dentro="#1a0614", diente="#f0f4e0", luz="#8af8ff", tierra=("#5a4630", "#2a1e12"))


def pose_planta_a(anim, f):
    p = dict(abre=[.06, .1, .06, .02][f % 4], lean=[0, 2, 0, -2][f % 4], agacha=0.0, flash=False, marchita=0.0,
             hunde=0.0, onda=f * math.pi / 2, op=1.0)
    if anim == "atacar":
        p.update(abre=[.05, .15, .6, 1, 0, .05][f], lean=[0, -7, 10, 14, 7, 1][f], agacha=[0, .3, 0, 0, .1, 0][f])
    elif anim == "dano":
        p.update(flash=f == 0, abre=0, lean=[-9, -5, -2][f], agacha=[.25, .12, 0][f])
    elif anim == "muerte":
        q = f / 7
        p.update(flash=f == 0, abre=.3 + .9 * min(1, q * 1.6), marchita=q, lean=-6 * q, hunde=max(0, q - .35) / .65,
                 op=1 - max(0, f - 5) / 3)
    return p


def svg_planta_azul(anim, theta, f):
    t = PLANTA_A
    p = pose_planta_a(anim, f)
    seca = p["marchita"]
    petalo = [_mezcla(c, m, seca * .85) for c, m in zip(t["petalo"], ("#b8b8c0", "#5a6068", "#22262a"))]
    hoja = [_mezcla(c, m, seca * .8) for c, m in zip(t["hoja"], ("#5a5a3a", "#2a2418"))]
    defs = degradado("petaloA", petalo, True, .4, .25, .85) + degradado("tierraA", t["tierra"], True, .4, .3, .8)
    s, c = sc(theta)
    k = Cuerpo(theta, 96, 164)
    out = sombra(96, 166, 40, 12)
    hunde = p["hunde"] * 46
    # La roseta: cinco hojas tumbadas en el suelo.
    for i in range(5):
        phi = math.radians(i * 72 + 36)
        ond = 2 * math.sin(p["onda"] + i)
        tres = [k.punto(6 * math.cos(phi), 6 * math.sin(phi), 2), k.punto(20 * math.cos(phi + .12), 20 * math.sin(phi + .12), 5 + ond),
                k.punto(36 * math.cos(phi + .2), 36 * math.sin(phi + .2), 0)]
        k.poner(-50, 0, hoja_colgante(tres, 7, hoja, t["borde"], "#5a9a4a"))
    # El tallo y, encima, el capullo, inclinado hacia donde mira.
    lean = p["lean"]
    alto_tallo = 16 * (1 - p["agacha"])
    bx, by = k.punto(lean * .4, 0, alto_tallo)
    tallo = tubo([k.punto(0, 0, 0), k.punto(lean * .15, 0, alto_tallo * .5), (bx, by)], 7, hoja[0], t["borde"], 2)
    cx, cy = bx + lean * .6 * s, by - 18 + hunde * 0
    abre = p["abre"]
    piezas = []
    for i in range(5):
        phi = i * 72 + 36
        a = math.radians(theta + phi)
        z = math.cos(a)
        r = 9 + 10 * abre
        x = cx + r * math.sin(a)
        # Al abrirse, los de delante se tumban hacia la camara (bajan y se ven
        # mas cortos) y dejan ver la boca, que queda arriba.
        y = cy + r * z * PROF + 4 * abre + 12 * abre * max(0, z)
        giro = math.sin(a) * (14 + 70 * abre)
        rx, ry = 12, (19 - 3 * abre) * (1 - .45 * abre * max(0, z))
        cuerpo = (f'<ellipse cx="{x:.1f}" cy="{y:.1f}" rx="{rx:.1f}" ry="{ry:.1f}" transform="rotate({giro:.1f} {x:.1f} {cy + 14:.1f})" '
                  f'fill="url(#petaloA)" stroke="{t["borde"]}" stroke-width="2.4"/>')
        # El nervio del petalo, que brilla.
        cuerpo += (f'<path d="M{x:.1f},{y + ry * .7:.1f} Q{x + 2:.1f},{y:.1f} {x:.1f},{y - ry * .75:.1f}" transform="rotate({giro:.1f} {x:.1f} {cy + 14:.1f})" '
                   f'fill="none" stroke="{t["luz"]}" stroke-width="1.6" opacity="{.6 * (1 - seca):.2f}"/>')
        for j in range(2):
            px_, py_ = x - 4 + j * 6, y - 6 + j * 7
            cuerpo += f'<circle cx="{px_:.1f}" cy="{py_:.1f}" r="1.6" fill="{t["luz"]}" opacity="{.8 * (1 - seca):.2f}" transform="rotate({giro:.1f} {x:.1f} {cy + 14:.1f})"/>'
        piezas.append((z, cuerpo))
    # Lo de dentro: la boca, con su anillo de dientes y el fondo que brilla.
    rb = 6 + 12 * abre
    dentro = ""
    if abre > .12:
        my = cy - 4 + 4 * abre
        dentro += elipse(cx, my, rb, rb * .75, 0, t["dentro"], t["borde"], 1.8)
        dentro += f'<ellipse cx="{cx:.1f}" cy="{my + 2:.1f}" rx="{rb * .45:.1f}" ry="{rb * .35:.1f}" fill="{t["luz"]}" opacity=".7" filter="url(#brillo)"/>'
        for i in range(12):
            a = math.radians(i * 30)
            x0, y0 = cx + rb * math.cos(a), my + rb * .75 * math.sin(a)
            x1, y1 = cx + rb * .55 * math.cos(a), my + rb * .4 * math.sin(a)
            dentro += f'<path d="M{x0 - 1.8:.1f},{y0:.1f} L{x1:.1f},{y1:.1f} L{x0 + 1.8:.1f},{y0:.1f} Z" fill="{t["diente"]}" stroke="{t["borde"]}" stroke-width=".6"/>'
    capullo = "".join(x for z, x in sorted(piezas, key=lambda q: q[0]) if z < -.2)
    capullo += dentro
    capullo += "".join(x for z, x in sorted(piezas, key=lambda q: q[0]) if z >= -.2)
    if abre <= .12 and c > .05:
        # Cerrado, los dientes asoman por la juntura de delante.
        jx, jy = cx + 9 * s, cy + 9 * c * PROF + 4
        for i in range(3):
            dx = (i - 1) * 3.2 * c
            capullo += f'<path d="M{jx + dx - 1.5:.1f},{jy - 2:.1f} L{jx + dx:.1f},{jy + 3:.1f} L{jx + dx + 1.5:.1f},{jy - 2:.1f} Z" fill="{t["diente"]}" stroke="{t["borde"]}" stroke-width=".7"/>'
    k.poner(.1, 0, tallo + capullo)
    dibujo = con_flash(k.pintar(), p["flash"])
    if hunde > 0:
        # Se hunde: se recorta lo que queda bajo el suelo y sale un monton de tierra.
        dibujo = (f'<clipPath id="sobreSuelo"><rect x="0" y="0" width="192" height="{164 - 4 + hunde * .1:.1f}"/></clipPath>'
                  f'<g clip-path="url(#sobreSuelo)"><g transform="translate(0 {hunde:.1f})">{dibujo}</g></g>')
        dibujo += f'<path d="{piedra(96, 162, 22 + 6 * p["hunde"], 9, .45, 9)}" fill="url(#tierraA)" stroke="{t["borde"]}" stroke-width="2"/>'
    return lienzo(192, 192, f'<g opacity="{p["op"]:.2f}">{out}{dibujo}</g>', defs)


# ======================================================== EL REGISTRO ===
# Por enemigo: su funcion de dibujo, el lienzo en el que dibuja y sus
# animaciones (poses, poses por segundo, si da vueltas). Los que disparan
# (serpiente, planta venenosa, golem) hacen el ataque a 6 por segundo: asi el
# disparo sale en la pose 3, a los 0,5 s de su tiempo_apuntar, como el vigia.
ANIMS = {"caminar": (4, 8.0, True), "atacar": (6, 10.0, False), "dano": (3, 12.0, False), "muerte": (8, 10.0, False)}
ANIMS_DISPARO = dict(ANIMS, atacar=(6, 6.0, False))
CRIATURAS = {
    "slime_verde": {"svg": lambda a, th, f: svg_slime("slime_verde", a, th, f), "lienzo": 192, "animaciones": ANIMS},
    "slime_naranja": {"svg": lambda a, th, f: svg_slime("slime_naranja", a, th, f), "lienzo": 192, "animaciones": ANIMS},
    "slime_magma": {"svg": lambda a, th, f: svg_slime("slime_magma", a, th, f), "lienzo": 192, "animaciones": ANIMS},
    # Ocupa lo que ocupaba la rata, a la que sustituye: ver medidas().
    "escorpion": {"svg": svg_escorpion, "lienzo": 192, "animaciones": ANIMS, "como": "rata"},
    "serpiente": {"svg": svg_serpiente, "lienzo": 192, "animaciones": ANIMS_DISPARO},
    "planta_venenosa": {"svg": svg_planta_venenosa, "lienzo": 192, "animaciones": ANIMS_DISPARO},
    "murcielago": {"svg": svg_murcielago, "lienzo": 128,
                   "animaciones": {"caminar": (4, 8.0, True), "atacar": (4, 12.0, False), "dano": (3, 12.0, False),
                                   "muerte": (6, 10.0, False)}},
    "golem_roca": {"svg": svg_golem_roca, "lienzo": 192, "animaciones": ANIMS_DISPARO},
    "cristal_vivo": {"svg": svg_cristal_vivo, "lienzo": 192, "animaciones": ANIMS},
    "fantasma": {"svg": svg_fantasma, "lienzo": 192, "animaciones": ANIMS},
    "planta_azul": {"svg": svg_planta_azul, "lienzo": 192, "animaciones": ANIMS},
}
# La carpeta de cada uno en assets/criaturas/: «antiguo_» delante, para que no
# se confunda con el murcielago y el golem nuevos (murcielago_corteza...).
CARPETA = "antiguo_%s"


# ===================================================== EL TAMANO ===
def _caja(imagen, umbral=150):
    """Lo que ocupa el cuerpo: sin la sombra ni los brillos, que son
    semitransparentes (la sombra no pasa de 0,5)."""
    return imagen.getchannel("A").point(lambda v: 255 if v > umbral else 0).getbbox()


def _pintar(texto, px, carpeta):
    """Un SVG a PNG de px x px, por rsvg-convert, en una carpeta temporal."""
    fd, ruta = tempfile.mkstemp(suffix=".svg", dir=carpeta)
    with os.fdopen(fd, "w") as f:
        f.write(texto)
    subprocess.run(["rsvg-convert", "-w", str(px), "-h", str(px), ruta, "-o", ruta[:-4] + ".png"], check=True)
    return ruta[:-4] + ".png"


def medidas(nombre, tmp):
    """El px de la casilla y donde cae el centro del cuerpo.

    Se quiere que se vea del tamano de antes: la hoja vieja (128 x 96, la que
    el juego escalaba para que sus 96 de alto midieran 'alto') se mide igual,
    y se iguala el area de lo que ocupa (raiz de ancho por alto), de lado y
    quieto, como estaba dibujada. Igualar solo el alto encogeria la rata y la
    serpiente, que son largas y bajas."""
    datos = CRIATURAS[nombre]
    lienzo_px = datos["lienzo"]
    alto = _alto_de(nombre)
    # El de antes con el que se mide: el suyo, o el que sustituye ('como').
    vieja = Image.open(os.path.join(RAIZ, "assets", "enemigos", "%s_00.png" % datos.get("como", nombre))).convert("RGBA")
    x0, y0, x1, y1 = _caja(vieja)
    antes = math.sqrt((x1 - x0) * (y1 - y0)) * alto / vieja.height
    lado = Image.open(_pintar(datos["svg"]("caminar", 90, 0), lienzo_px, tmp)).convert("RGBA")
    x0, y0, x1, y1 = _caja(lado)
    ahora = math.sqrt((x1 - x0) * (y1 - y0))          # en unidades del lienzo
    px = round(lienzo_px * antes / ahora)
    frente = Image.open(_pintar(datos["svg"]("caminar", 0, 0), lienzo_px, tmp)).convert("RGBA")
    x0, y0, x1, y1 = _caja(frente)
    return px, (y0 + y1) / 2


def _alto_de(nombre):
    texto = open(os.path.join(RECURSOS, nombre + ".tres"), encoding="utf-8").read()
    return float(re.search(r"^alto = ([\d.]+)", texto, re.M).group(1))


# ===================================================== LA EXPORTACION ===
def exportar(nombre):
    datos = CRIATURAS[nombre]
    carpeta = CARPETA % nombre
    destino = os.path.join(DESTINO, carpeta)
    os.makedirs(destino, exist_ok=True)
    tmp = tempfile.mkdtemp()
    px, centro = medidas(nombre, tmp)
    doble = px * 2              # se pinta al doble y se reduce: el borde sale mas fino
    cuadros = {}
    for anim, (poses, _, _) in datos["animaciones"].items():
        trabajos = [(fila, pose, datos["svg"](anim, theta_de_fila(fila), pose))
                    for fila in range(len(DIRECCIONES)) for pose in range(poses)]
        with ThreadPoolExecutor(8) as e:
            rutas = list(e.map(lambda t: _pintar(t[2], doble, tmp), trabajos))
        for (fila, pose, _), ruta in zip(trabajos, rutas):
            cuadros[anim, fila, pose] = reducir(Image.open(ruta).convert("RGBA"), (px, px))
    # La casilla se recorta a lo que ocupa de verdad (todas las poses juntas):
    # el lienzo deja sitio de sobra para saltos y mordiscos, y cuadrado y
    # entero las once hojas pesaban 12 MB. De lado se recorta lo mismo por los
    # dos lados, para que el dibujo siga centrado en el circulo que choca.
    cajas = [im.getchannel("A").point(lambda v: 255 if v > 2 else 0).getbbox() for im in cuadros.values()]
    cajas = [c for c in cajas if c]
    mitad = max(max(px / 2 - c[0], c[2] - px / 2) for c in cajas)
    x0, x1 = max(0, math.floor(px / 2 - mitad - 1)), min(px, math.ceil(px / 2 + mitad + 1))
    y0, y1 = max(0, min(c[1] for c in cajas) - 1), min(px, max(c[3] for c in cajas) + 1)
    ancho, alto = x1 - x0, y1 - y0
    externos, recortes, bloques = [], [], []
    for anim, (poses, fps, bucle) in datos["animaciones"].items():
        hoja = Image.new("RGBA", (ancho * poses, alto * len(DIRECCIONES)))
        for fila, direccion in enumerate(DIRECCIONES):
            ids = []
            for pose in range(poses):
                hoja.alpha_composite(cuadros[anim, fila, pose].crop((x0, y0, x1, y1)), (pose * ancho, fila * alto))
                id_cuadro = "%s_%s_%d" % (anim, direccion, pose)
                ids.append(id_cuadro)
                recortes += ['[sub_resource type="AtlasTexture" id="%s"]' % id_cuadro,
                             'atlas = ExtResource("t_%s")' % anim,
                             "region = Rect2(%d, %d, %d, %d)" % (pose * ancho, fila * alto, ancho, alto), ""]
            bloques.append(animacion("%s_%s" % (anim, direccion), ids, fps, bucle))
        hoja.save(os.path.join(destino, anim + ".png"), optimize=True)
        externos.append('[ext_resource type="Texture2D" path="res://assets/criaturas/%s/%s.png" id="t_%s"]'
                        % (carpeta, anim, anim))
    lineas = ['[gd_resource type="SpriteFrames" load_steps=%d format=3]' % (1 + len(externos) + len(recortes) // 4), ""]
    lineas += externos + [""] + recortes
    lineas += ["[resource]", "animations = [%s]" % ", ".join(bloques)]
    guardar_texto(os.path.join(destino, "animaciones.tres"), lineas)
    shutil.rmtree(tmp, ignore_errors=True)
    # El sprite se pinta centrado en la casilla recortada; se mueve para que el
    # centro del cuerpo (centro, en el lienzo) caiga en el del circulo.
    desfase = -(centro * px / datos["lienzo"] - (y0 + y1) / 2)
    apuntar_recurso(nombre, carpeta, desfase)
    print("%-16s %3d x %3d px  desfase_dibujo = Vector2(0, %.2f)" % (nombre, ancho, alto, desfase))


def apuntar_recurso(nombre, carpeta, desfase):
    """Su .tres de enemigos_antiguos pasa a usar el dibujo nuevo, a escala 1 y
    con el centro del cuerpo en el del circulo que choca."""
    ruta = os.path.join(RECURSOS, nombre + ".tres")
    texto = open(ruta, encoding="utf-8").read()
    texto = re.sub(r'path="res://assets/[^"]*animaciones[^"]*\.tres"',
                   'path="res://assets/criaturas/%s/animaciones.tres"' % carpeta, texto, count=1)
    texto = re.sub(r"^escala_dibujo = .*\n", "", texto, flags=re.M)
    texto = re.sub(r"^desfase_dibujo = .*\n", "", texto, flags=re.M)
    texto = re.sub(r"^(alto = .*\n)", r"\1escala_dibujo = 1.0\ndesfase_dibujo = Vector2(0, %.2f)\n" % desfase,
                   texto, count=1, flags=re.M)
    texto = re.sub(r'(\[ext_resource type="SpriteFrames" path="[^"]*") uid="[^"]*"', r"\1", texto)
    with open(ruta, "w", encoding="utf-8", newline="\n") as f:
        f.write(texto)


if __name__ == "__main__":
    for nombre in (sys.argv[1:] or list(CRIATURAS)):
        exportar(nombre)
