# -*- coding: utf-8 -*-
"""Genera las armas (el gacha de diamantes): su dibujo y su .tres.

Pedido por Matias el 2026-11-04: armas "super guays", cada una disparando de una
forma distinta, en cuatro tiers:

    raro        solo cambia el aspecto
    epico       el aspecto y la forma de disparar
    legendario  ademas, una animacion al matar
    mitico      ademas, varios modos de ataque

Todo sale de la tabla ARMAS: para equilibrar o anadir una, se cambia alli y se
vuelve a ejecutar. Salen, por arma:

- assets/armas/<id>.png: el icono, 96 px, mirando a la derecha (flota junto al
  mago apuntando, ArmaFlotante).
- assets/armas/<id>_grande.png: la ilustracion, 256 px, inclinada, para el gacha
  y la coleccion. Con lo que da el tier alrededor: resplandor desde las epicas,
  destellos desde las legendarias y un anillo de runas en las miticas.
- resources/armas/<id>.tres, que es lo que lee el gacha.

Desde el 2026-11-05 se dibujan en SVG, con el mismo trazo que los magos (borde
oscuro grueso, degradados y brillos), en vez de con lineas de Pillow. Necesita
rsvg-convert, como magos_vectorial.py.

Los numeros de cada modo son multiplicadores sobre un disparo normal (10 de dano,
uno cada 0,5 s). Dano por tiempo si dan todas las bolas, y contando la explosion:
un epico, de un 25 a un 35 % mas; un legendario, de un 50 a un 70 %; un mitico,
hasta algo mas del doble. A cambio, casi nunca dan todas. Es a ojo: hay que
jugarlas para ajustarlos.

    python herramientas/generar_armas.py
"""
import math
import os
import shutil
import subprocess
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor

from PIL import Image, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from generar_magos import guardar_texto, reducir  # noqa: E402

RAIZ = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
ICONOS = os.path.join(RAIZ, "assets", "armas")
RECURSOS = os.path.join(RAIZ, "resources", "armas")

LADO = 96
GRANDE = 256

# Los de BolaMagica.Estilo y AnimacionMuerte.Tipo, en el mismo orden.
ORBE, ESTRELLA, FLECHA, RUNA, CUCHILLA, RAYO = range(6)
SIN_ANIMACION, RAYOS, TORBELLINO, LLAMARADA, ALMAS, ESQUIRLAS = range(6)
RARO, EPICO, LEGENDARIO, MITICO = range(4)
# El resplandor de la ilustracion (en px de 256), por tier. El icono lleva la mitad.
BRILLO = {RARO: 0, EPICO: 5, LEGENDARIO: 7, MITICO: 9}


def modo(nombre="Normal", **campos):
    return dict(nombre=nombre, **campos)


ARMAS = [
    # --- Raros: solo el aspecto ------------------------------------------------
    dict(id="1_varita_roble", nombre="Varita de roble", tier=RARO, forma="varita", color="#b8e06a", halo="#5a8a2a",
         estilo=ESTRELLA, muerte=SIN_ANIMACION, descripcion="Estrellas de savia. Dispara como siempre.", modos=[modo()]),
    dict(id="1_cetro_coral", nombre="Cetro de coral", tier=RARO, forma="cetro", color="#ff9a8a", halo="#d84a5a",
         estilo=ORBE, muerte=SIN_ANIMACION, descripcion="Perlas de coral. Dispara como siempre.", modos=[modo()]),
    dict(id="1_daga_plata", nombre="Daga de plata", tier=RARO, forma="daga", color="#e4ecf4", halo="#8a9ab0",
         estilo=CUCHILLA, muerte=SIN_ANIMACION, descripcion="Filos de plata. Dispara como siempre.", modos=[modo()]),
    dict(id="1_tomo_azul", nombre="Tomo azul", tier=RARO, forma="tomo", color="#7ab8ff", halo="#2a5ad8",
         estilo=RUNA, muerte=SIN_ANIMACION, descripcion="Runas azules. Dispara como siempre.", modos=[modo()]),
    # --- Epicos: aspecto y forma de disparar -----------------------------------
    dict(id="2_varita_bifurcada", nombre="Varita bifurcada", tier=EPICO, forma="horquilla", color="#ffe066",
         halo="#e09a10", estilo=FLECHA, muerte=SIN_ANIMACION, descripcion="Tres flechas en abanico.",
         modos=[modo(proyectiles=3, apertura=16.0, dano=0.45)]),
    dict(id="2_dagas_gemelas", nombre="Dagas gemelas", tier=EPICO, forma="gemelas", color="#ff7ab0", halo="#c02a70",
         estilo=CUCHILLA, muerte=SIN_ANIMACION, descripcion="Una ráfaga de tres filos.",
         modos=[modo(rafaga=3, pausa_rafaga=0.08, dano=0.45, cadencia=1.05, velocidad=1.15)]),
    dict(id="2_cetro_serpiente", nombre="Cetro serpiente", tier=EPICO, forma="serpiente", color="#7affb0",
         halo="#16a060", estilo=ESTRELLA, muerte=SIN_ANIMACION, descripcion="Sus disparos serpentean.",
         modos=[modo(onda=46.0, dano=1.25, velocidad=0.85, radio=1.15)]),
    dict(id="2_orbe_saltarin", nombre="Orbe saltarín", tier=EPICO, forma="orbe", color="#80f0ff", halo="#1a90c0",
         estilo=ORBE, muerte=SIN_ANIMACION, descripcion="Sus bolas rebotan tres veces en muros y rocas.",
         modos=[modo(rebotes=3, dano=0.95, velocidad=0.95)]),
    # --- Legendarios: ademas, animacion al matar -------------------------------
    dict(id="3_tridente_solar", nombre="Tridente solar", tier=LEGENDARIO, forma="tridente", color="#ffd040",
         halo="#ff6a10", estilo=FLECHA, muerte=LLAMARADA,
         descripcion="Tres rayos de sol que atraviesan. Al matar, una llamarada.",
         modos=[modo(proyectiles=3, apertura=12.0, atraviesa=True, dano=0.5, velocidad=1.2)]),
    dict(id="3_guadana_almas", nombre="Guadaña de almas", tier=LEGENDARIO, forma="guadana", color="#b0ffe0",
         halo="#30a890", estilo=CUCHILLA, muerte=ALMAS,
         descripcion="Dos filos que se cruzan en el aire. Al matar, se le va el alma.",
         modos=[modo(proyectiles=2, onda=42.0, dano=0.75, velocidad=0.9)]),
    dict(id="3_martillo_runico", nombre="Martillo rúnico", tier=LEGENDARIO, forma="martillo", color="#a0c8ff",
         halo="#3a60e0", estilo=RUNA, muerte=ESQUIRLAS,
         descripcion="Runas lentas que explotan. Al matar, lo hace añicos.",
         modos=[modo(explosion=80.0, dano=1.7, velocidad=0.7, radio=1.4, cadencia=1.5)]),
    # --- Miticos: ademas, varios modos -----------------------------------------
    dict(id="4_cetro_abismo", nombre="Cetro del abismo", tier=MITICO, forma="abismo", color="#c88aff", halo="#6a20e0",
         estilo=ORBE, muerte=TORBELLINO,
         descripcion="Tres modos (rueda del ratón). Al matar, se lo traga un torbellino.",
         modos=[modo("Ráfaga", rafaga=4, pausa_rafaga=0.06, dano=0.5, velocidad=1.1),
                modo("Abanico", proyectiles=5, apertura=44.0, dano=0.45),
                modo("Lanza", atraviesa=True, dano=1.6, velocidad=1.9, radio=1.25, cadencia=1.3, estilo=RAYO)]),
    dict(id="4_corona_tormentas", nombre="Corona de tormentas", tier=MITICO, forma="corona", color="#90e8ff",
         halo="#2070ff", estilo=RAYO, muerte=RAYOS,
         descripcion="Tres modos (rueda del ratón). Al matar, lo fulmina un rayo.",
         modos=[modo("Chispas", proyectiles=2, apertura=30.0, busca=240.0, dano=0.7, velocidad=0.9, estilo=ESTRELLA),
                modo("Trueno", explosion=100.0, dano=2.2, velocidad=0.8, radio=1.5, cadencia=1.6, estilo=ORBE),
                modo("Cadena", rebotes=5, dano=1.0, velocidad=1.3)]),
]


# ================================================================ DIBUJO ===
# Todo en un lienzo de 256 x 256 con el arma centrada y la punta a la derecha.
TRAZO = "#0c0810"
# Materiales: claro, medio y oscuro. Se pintan de arriba (luz) a abajo (sombra).
MADERA = ("#c89058", "#7a4e2a", "#2e1a0c")
ORO = ("#fff2b0", "#e8b440", "#7a4a10")
PLATA = ("#ffffff", "#c4ceda", "#4e586c")
HIERRO = ("#a8aebc", "#4e5464", "#161a26")
CUERO = ("#9a5a36", "#4a2414", "#1a0a04")
OBSIDIANA = ("#6a5a8a", "#1e1430", "#050308")


def fp(p):
    return f"{p[0]:.1f},{p[1]:.1f}"


def aclarar(color, k):
    """k > 0 hacia el blanco, k < 0 hacia el negro."""
    r, g, b = (int(color[i:i + 2], 16) for i in (1, 3, 5))
    if k >= 0:
        r, g, b = (v + (255 - v) * k for v in (r, g, b))
    else:
        r, g, b = (v * (1 + k) for v in (r, g, b))
    return "#%02x%02x%02x" % tuple(round(v) for v in (r, g, b))


class Lienzo:
    """Junta las definiciones (degradados) y el dibujo. Cada degradado lleva su
    numero: dos piezas no pueden compartir id."""

    def __init__(self, arma):
        self.arma = arma
        self.claro, self.halo = arma["color"], arma["halo"]
        self.defs, self.cuerpo, self.n = [], [], 0

    def __iadd__(self, svg):
        self.cuerpo.append(svg)
        return self

    def degradado(self, a, b, colores):
        """Lineal de a a b, en coordenadas del lienzo: un degradado en
        coordenadas de la caja se rompe en lo que no tiene alto (una barra recta)."""
        self.n += 1
        paradas = "".join(f'<stop offset="{i / (len(colores) - 1):.2f}" stop-color="{c}"/>' for i, c in enumerate(colores))
        self.defs.append(f'<linearGradient id="d{self.n}" gradientUnits="userSpaceOnUse" x1="{a[0]:.1f}" y1="{a[1]:.1f}" '
                         f'x2="{b[0]:.1f}" y2="{b[1]:.1f}">{paradas}</linearGradient>')
        return f"url(#d{self.n})"

    def radial(self, cx, cy, r, colores, foco=(-0.35, -0.4)):
        self.n += 1
        paradas = "".join(f'<stop offset="{i / (len(colores) - 1):.2f}" stop-color="{c}"/>' for i, c in enumerate(colores))
        self.defs.append(f'<radialGradient id="d{self.n}" gradientUnits="userSpaceOnUse" cx="{cx:.1f}" cy="{cy:.1f}" r="{r:.1f}" '
                         f'fx="{cx + foco[0] * r:.1f}" fy="{cy + foco[1] * r:.1f}">{paradas}</radialGradient>')
        return f"url(#d{self.n})"

    def luz(self, cx, cy, r, color, fuerza=0.6):
        """Un resplandor redondo que se apaga hacia fuera. Un circulo
        semitransparente con desenfoque se veia como un disco turbio."""
        self.n += 1
        self.defs.append(f'<radialGradient id="d{self.n}" gradientUnits="userSpaceOnUse" cx="{cx:.1f}" cy="{cy:.1f}" r="{r:.1f}">'
                         f'<stop offset="0" stop-color="{color}" stop-opacity="{fuerza}"/>'
                         f'<stop offset=".45" stop-color="{color}" stop-opacity="{fuerza * .45:.2f}"/>'
                         f'<stop offset="1" stop-color="{color}" stop-opacity="0"/></radialGradient>')
        return f'<circle cx="{cx:.1f}" cy="{cy:.1f}" r="{r:.1f}" fill="url(#d{self.n})"/>'

    def svg(self, envolver=lambda s: s, fondo=""):
        return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256" width="256" height="256"><defs>'
                f'<filter id="resplandor" x="-60%" y="-60%" width="220%" height="220%"><feGaussianBlur stdDeviation="3" result="b"/>'
                f'<feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter>'
                f'{"".join(self.defs)}</defs>{fondo}{envolver("".join(self.cuerpo))}</svg>')


def normal(a, b):
    dx, dy = b[0] - a[0], b[1] - a[1]
    largo = math.hypot(dx, dy) or 1
    n = (-dy / largo, dx / largo)
    # Siempre hacia abajo (o a la derecha): asi el lado de arriba es el de la luz.
    if n[1] < 0 or (n[1] == 0 and n[0] < 0):
        n = (-n[0], -n[1])
    return n, largo


def barra(L, a, b, ancho, material, brillo=True):
    """Un palo de a a b con las puntas redondas y luz por arriba."""
    n, _ = normal(a, b)
    h = ancho / 2
    p1, p2 = (a[0] - n[0] * h, a[1] - n[1] * h), (b[0] - n[0] * h, b[1] - n[1] * h)
    p3, p4 = (b[0] + n[0] * h, b[1] + n[1] * h), (a[0] + n[0] * h, a[1] + n[1] * h)
    medio = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
    relleno = L.degradado((medio[0] - n[0] * h, medio[1] - n[1] * h), (medio[0] + n[0] * h, medio[1] + n[1] * h), material)
    out = (f'<path d="M{fp(p1)} L{fp(p2)} A{h:.1f},{h:.1f} 0 0 1 {fp(p3)} L{fp(p4)} A{h:.1f},{h:.1f} 0 0 1 {fp(p1)} Z" '
           f'fill="{relleno}" stroke="{TRAZO}" stroke-width="4.5" stroke-linejoin="round"/>')
    if brillo:
        k = h * 0.45
        out += (f'<path d="M{a[0] - n[0] * k:.1f},{a[1] - n[1] * k:.1f} L{b[0] - n[0] * k:.1f},{b[1] - n[1] * k:.1f}" '
                f'stroke="#ffffff" stroke-width="{max(1.2, ancho * 0.16):.1f}" stroke-linecap="round" opacity=".38"/>')
    return out


def anillo(L, centro, eje, ancho, alto, material=ORO):
    """Una abrazadera alrededor de un palo: un rectangulo corto cruzado."""
    n, _ = normal((0, 0), eje)
    d = (eje[0] / math.hypot(*eje), eje[1] / math.hypot(*eje))
    a = (centro[0] - d[0] * ancho / 2, centro[1] - d[1] * ancho / 2)
    b = (centro[0] + d[0] * ancho / 2, centro[1] + d[1] * ancho / 2)
    pts = [(a[0] - n[0] * alto / 2, a[1] - n[1] * alto / 2), (b[0] - n[0] * alto / 2, b[1] - n[1] * alto / 2),
           (b[0] + n[0] * alto / 2, b[1] + n[1] * alto / 2), (a[0] + n[0] * alto / 2, a[1] + n[1] * alto / 2)]
    relleno = L.degradado(pts[0], pts[3], material)
    return f'<path d="M{" L".join(fp(p) for p in pts)} Z" fill="{relleno}" stroke="{TRAZO}" stroke-width="3.5" stroke-linejoin="round"/>'


def gema(L, cx, cy, r, claro, oscuro, brilla=True):
    """Una piedra redonda tallada: degradado, facetas y un brillo."""
    relleno = L.radial(cx, cy, r, ["#ffffff", claro, oscuro])
    out = ""
    if brilla:
        out += L.luz(cx, cy, r * 2.1, claro)
    out += f'<circle cx="{cx:.1f}" cy="{cy:.1f}" r="{r:.1f}" fill="{relleno}" stroke="{TRAZO}" stroke-width="4"/>'
    if r < 25:      # las facetas, solo en las pequenas: en una grande parecian una ventana
        out += (f'<path d="M{cx - r * .55:.1f},{cy - r * .1:.1f} L{cx:.1f},{cy - r * .6:.1f} L{cx + r * .55:.1f},{cy - r * .1:.1f} '
                f'L{cx:.1f},{cy + r * .5:.1f} Z" fill="none" stroke="#ffffff" stroke-width="1.3" opacity=".45"/>')
    out += (f'<ellipse cx="{cx - r * .35:.1f}" cy="{cy - r * .4:.1f}" rx="{r * .28:.1f}" ry="{r * .18:.1f}" fill="#ffffff" opacity=".85" '
            f'transform="rotate(-30 {cx - r * .35:.1f} {cy - r * .4:.1f})"/>')
    return out


def estrella(L, cx, cy, r, puntas, claro, oscuro, interior=0.42, giro=-90, brilla=True):
    pts = []
    for i in range(puntas * 2):
        a = math.radians(giro + i * 180 / puntas)
        k = r if i % 2 == 0 else r * interior
        pts.append((cx + math.cos(a) * k, cy + math.sin(a) * k))
    relleno = L.radial(cx, cy, r, ["#ffffff", claro, oscuro], foco=(0, 0))
    out = L.luz(cx, cy, r * 1.7, claro) if brilla else ""
    return out + (f'<path d="M{" L".join(fp(p) for p in pts)} Z" fill="{relleno}" stroke="{TRAZO}" stroke-width="4" '
                  f'stroke-linejoin="round"/>')


def destello(cx, cy, r, color="#ffffff", op=1.0):
    """Un brillo de cuatro puntas finas, sin borde."""
    return (f'<path d="M{cx:.1f},{cy - r:.1f} Q{cx:.1f},{cy:.1f} {cx + r:.1f},{cy:.1f} Q{cx:.1f},{cy:.1f} {cx:.1f},{cy + r:.1f} '
            f'Q{cx:.1f},{cy:.1f} {cx - r:.1f},{cy:.1f} Q{cx:.1f},{cy:.1f} {cx:.1f},{cy - r:.1f} Z" fill="{color}" opacity="{op:.2f}"/>')


def poligono(L, pts, colores, a=None, b=None, ancho=4):
    """Relleno con un degradado de a a b (por defecto, de arriba a abajo)."""
    if a is None:
        ys = [p[1] for p in pts]
        xm = sum(p[0] for p in pts) / len(pts)
        a, b = (xm, min(ys)), (xm, max(ys))
    relleno = L.degradado(a, b, colores)
    return f'<path d="M{" L".join(fp(p) for p in pts)} Z" fill="{relleno}" stroke="{TRAZO}" stroke-width="{ancho}" stroke-linejoin="round"/>'


def hoja_daga(L, base, punta, ancho, colores):
    """La hoja: ancha en la base, filo hasta la punta, con su vaceo en medio."""
    n, largo = normal(base, punta)
    d = ((punta[0] - base[0]) / largo, (punta[1] - base[1]) / largo)
    h = ancho / 2
    hombro = (base[0] + d[0] * largo * .78, base[1] + d[1] * largo * .78)
    pts = [(base[0] - n[0] * h, base[1] - n[1] * h), (hombro[0] - n[0] * h * .8, hombro[1] - n[1] * h * .8), punta,
           (hombro[0] + n[0] * h * .8, hombro[1] + n[1] * h * .8), (base[0] + n[0] * h, base[1] + n[1] * h)]
    out = poligono(L, pts, colores, pts[0], pts[4])
    # La mitad de arriba, mas clara: la hoja tiene dos caras.
    out += f'<path d="M{fp(pts[0])} L{fp(pts[1])} L{fp(punta)} L{fp(base)} Z" fill="#ffffff" opacity=".28"/>'
    fin = (base[0] + d[0] * largo * .66, base[1] + d[1] * largo * .66)
    out += f'<path d="M{base[0] + d[0] * 6:.1f},{base[1] + d[1] * 6:.1f} L{fp(fin)}" stroke="{TRAZO}" stroke-width="3" opacity=".45" stroke-linecap="round"/>'
    return out


def daga(L, x0, y, largo, hoja, gema_color):
    """Puno de cuero, guarda de oro y hoja, a lo largo de y. x0 es el pomo."""
    out = barra(L, (x0 + 8, y), (x0 + 58, y), 15, CUERO)
    out += "".join(f'<path d="M{x0 + 16 + k * 9:.1f},{y - 7:.1f} L{x0 + 22 + k * 9:.1f},{y + 7:.1f}" stroke="{TRAZO}" stroke-width="2" opacity=".55"/>'
                   for k in range(5))
    out += gema(L, x0 + 4, y, 9, gema_color, aclarar(gema_color, -.5), brilla=False)
    out += hoja_daga(L, (x0 + 66, y), (x0 + largo, y), 30, hoja)
    out += barra(L, (x0 + 64, y - 30), (x0 + 64, y + 30), 11, ORO)
    out += f'<circle cx="{x0 + 64:.1f}" cy="{y - 33:.1f}" r="6" fill="{L.radial(x0 + 64, y - 33, 6, ORO)}" stroke="{TRAZO}" stroke-width="3.5"/>'
    out += f'<circle cx="{x0 + 64:.1f}" cy="{y + 33:.1f}" r="6" fill="{L.radial(x0 + 64, y + 33, 6, ORO)}" stroke="{TRAZO}" stroke-width="3.5"/>'
    out += gema(L, x0 + 64, y, 7, gema_color, aclarar(gema_color, -.5), brilla=False)
    return out


def rayo_zigzag(puntos, color, ancho=5):
    d = "M" + " L".join(fp(p) for p in puntos)
    return (f'<path d="{d}" fill="none" stroke="{color}" stroke-width="{ancho * 2.4:.1f}" stroke-linejoin="round" opacity=".35" filter="url(#resplandor)"/>'
            f'<path d="{d}" fill="none" stroke="{TRAZO}" stroke-width="{ancho + 3:.1f}" stroke-linejoin="round" stroke-linecap="round"/>'
            f'<path d="{d}" fill="none" stroke="{color}" stroke-width="{ancho:.1f}" stroke-linejoin="round" stroke-linecap="round"/>'
            f'<path d="{d}" fill="none" stroke="#ffffff" stroke-width="{ancho * .35:.1f}" stroke-linejoin="round" stroke-linecap="round"/>')


# ----------------------------------------------------------- las formas ---
def f_varita(L):
    c, h = L.claro, L.halo
    L += barra(L, (34, 158), (176, 112), 13, MADERA)
    # Nudos de la madera
    L += f'<ellipse cx="88" cy="140" rx="6" ry="3.5" fill="#2e1a0c" transform="rotate(-18 88 140)"/>'
    L += f'<ellipse cx="132" cy="126" rx="5" ry="3" fill="#2e1a0c" transform="rotate(-18 132 126)"/>'
    for (bx, by, tx, ty) in ((164, 112, 150, 84), (166, 120, 160, 146)):     # hojas
        mx, my = (bx + tx) / 2, (by + ty) / 2
        L += poligono(L, [(bx, by), (mx - 9, my - 2), (tx, ty), (mx + 9, my + 2)], ["#d8ff8a", "#5aa02a", "#1e4a10"], ancho=3.5)
        L += f'<path d="M{bx},{by} L{tx},{ty}" stroke="#1e4a10" stroke-width="1.6"/>'
    L += anillo(L, (170, 114), (142, -46), 12, 20, ORO)
    L += estrella(L, 198, 104, 30, 4, c, h, interior=0.36)
    L += destello(214, 84, 7) + destello(184, 128, 5)


def f_cetro(L):
    c, h = L.claro, L.halo
    L += barra(L, (28, 164), (162, 122), 12, ORO)
    L += anillo(L, (60, 154), (134, -42), 14, 20, ORO)
    L += gema(L, 24, 166, 9, h, aclarar(h, -.5), brilla=False)
    # Ramas de coral que abrazan la perla
    for d in ("M156,124 Q170,112 168,90 Q166,78 176,70", "M160,124 Q190,128 206,112 Q214,104 222,108",
              "M158,122 Q176,96 196,92"):
        L += f'<path d="{d}" fill="none" stroke="{TRAZO}" stroke-width="12" stroke-linecap="round"/>'
        L += f'<path d="{d}" fill="none" stroke="{aclarar(c, -.2)}" stroke-width="7" stroke-linecap="round"/>'
        L += f'<path d="{d}" fill="none" stroke="{aclarar(c, .5)}" stroke-width="2.2" stroke-linecap="round" opacity=".8"/>'
    L += gema(L, 192, 106, 22, "#fff4f0", c)
    L += destello(206, 92, 6)


def f_daga(L):
    L += daga(L, 30, 128, 206, ["#ffffff", L.claro, aclarar(L.halo, -.35)], L.halo)
    L += destello(222, 116, 8)


def f_tomo(L):
    c, h = L.claro, L.halo
    tapa = [(62, 62), (198, 74), (192, 190), (56, 178)]
    paginas = [(198, 74), (210, 84), (204, 198), (192, 190)]
    abajo = [(56, 178), (192, 190), (204, 198), (68, 188)]
    L += poligono(L, paginas, ["#fff8e8", "#d8c8a0"], (198, 74), (210, 84))
    L += poligono(L, abajo, ["#fff8e8", "#c8b890"])
    for k in range(1, 4):           # canto de las hojas
        L += f'<path d="M{198 + k * 3},{76 + k * 2.6:.1f} L{192 + k * 3},{191 + k * 2.2:.1f}" stroke="#a89870" stroke-width="1"/>'
    L += poligono(L, tapa, [aclarar(h, .25), h, aclarar(h, -.55)], (62, 62), (192, 190))
    L += barra(L, (62, 66), (56, 176), 14, [aclarar(h, -.2), aclarar(h, -.5), aclarar(h, -.75)])   # lomo
    for (x, y, dx, dy) in ((198, 74, -1, 1), (192, 190, -1, -1)):            # esquinas de plata
        L += poligono(L, [(x, y), (x + 26 * dx, y + 2 * dy), (x - 2 * dx, y + 26 * dy)], PLATA, ancho=3.5)
    L += f'<circle cx="126" cy="126" r="34" fill="none" stroke="{aclarar(h, -.6)}" stroke-width="7"/>'
    L += f'<circle cx="126" cy="126" r="34" fill="none" stroke="{c}" stroke-width="3" filter="url(#resplandor)"/>'
    L += (f'<g filter="url(#resplandor)"><path d="M126,98 L126,154 M106,112 L146,140 M146,112 L106,140" stroke="{c}" '
          f'stroke-width="5" stroke-linecap="round"/><circle cx="126" cy="126" r="6" fill="#ffffff"/></g>')
    L += barra(L, (186, 118), (214, 120), 12, PLATA)     # cierre
    L += destello(150, 92, 6)


def f_horquilla(L):
    c, h = L.claro, L.halo
    L += barra(L, (22, 142), (118, 128), 13, MADERA)
    for (tx, ty) in ((190, 80), (206, 128), (190, 176)):
        L += barra(L, (114, 128), (tx, ty), 9, MADERA)
    L += anillo(L, (112, 129), (96, -14), 16, 22, ORO)
    for (tx, ty) in ((190, 80), (206, 128), (190, 176)):
        dx, dy = tx - 114, ty - 128
        lg = math.hypot(dx, dy)
        ux, uy = dx / lg, dy / lg
        nx, ny = -uy, ux
        punta = (tx + ux * 30, ty + uy * 30)
        pts = [(tx - nx * 10, ty - ny * 10), punta, (tx + nx * 10, ty + ny * 10), (tx + ux * 6, ty + uy * 6)]
        L += f'<path d="M{fp((tx, ty))} L{fp(punta)}" stroke="{c}" stroke-width="16" opacity=".35" filter="url(#resplandor)"/>'
        L += poligono(L, pts, ["#ffffff", c, h], pts[0], pts[2], ancho=3.5)
    L += destello(226, 104, 6) + destello(214, 166, 5)


def f_dagas_gemelas(L):
    hoja = ["#ffffff", L.claro, aclarar(L.halo, -.35)]
    for giro in (-22, 22):
        # Cruzadas por el centro: una hacia arriba y otra hacia abajo.
        L += (f'<g transform="rotate({giro} 128 128) translate(128 128) scale(.86) translate(-128 -128)">'
              + daga(L, 26, 128, 204, hoja, L.halo) + '</g>')
    L += destello(214, 58, 7) + destello(214, 198, 6)


def f_serpiente(L):
    c, h = L.claro, L.halo
    L += barra(L, (24, 156), (196, 116), 11, OBSIDIANA)
    # El cuerpo de la serpiente, enroscado al baston
    pts = []
    for i in range(41):
        t = i / 40
        x = 34 + 160 * t
        y = 154 - 40 * t + 16 * math.sin(t * math.pi * 4.5)
        pts.append((x, y))
    d = "M" + " L".join(fp(p) for p in pts)
    L += f'<path d="{d}" fill="none" stroke="{TRAZO}" stroke-width="17" stroke-linecap="round" stroke-linejoin="round"/>'
    L += f'<path d="{d}" fill="none" stroke="{h}" stroke-width="11" stroke-linecap="round" stroke-linejoin="round"/>'
    L += f'<path d="{d}" fill="none" stroke="{c}" stroke-width="5" stroke-linecap="round" stroke-dasharray="7 7"/>'
    L += f'<path d="{d}" fill="none" stroke="#ffffff" stroke-width="1.6" stroke-linecap="round" opacity=".55" transform="translate(0 -3)"/>'
    # Cabeza, con la boca abierta hacia la derecha
    L += poligono(L, [(186, 104), (214, 96), (232, 106), (214, 120), (190, 122)], ["#ffffff", c, h], (200, 94), (200, 124))
    L += f'<path d="M232,108 L244,104 M232,108 L244,114" stroke="#ff4a5a" stroke-width="2.4" stroke-linecap="round"/>'
    L += f'<ellipse cx="208" cy="104" rx="4" ry="3" fill="#ff3a3a" stroke="{TRAZO}" stroke-width="1.5"/>'
    L += gema(L, 30, 154, 10, c, h, brilla=False)


def f_orbe(L):
    c, h = L.claro, L.halo
    L += f'<ellipse cx="128" cy="128" rx="96" ry="34" fill="none" stroke="{TRAZO}" stroke-width="12" transform="rotate(-16 128 128)"/>'
    L += f'<ellipse cx="128" cy="128" rx="96" ry="34" fill="none" stroke="{L.degradado((128, 94), (128, 162), PLATA)}" stroke-width="6" transform="rotate(-16 128 128)"/>'
    L += gema(L, 128, 128, 44, aclarar(c, .1), h)
    # Bolitas que botan por el anillo, con su estela
    for (x, y, r) in ((40, 150, 11), (214, 104, 9), (150, 90, 7)):
        L += L.luz(x, y, r * 2.4, c)
        L += f'<circle cx="{x}" cy="{y}" r="{r}" fill="{L.radial(x, y, r, ["#ffffff", c, h])}" stroke="{TRAZO}" stroke-width="3"/>'
    L += f'<path d="M58,146 Q70,120 84,140" fill="none" stroke="{c}" stroke-width="2.4" stroke-dasharray="4 4" stroke-linecap="round"/>'
    L += f'<path d="M196,108 Q186,82 170,96" fill="none" stroke="{c}" stroke-width="2.4" stroke-dasharray="4 4" stroke-linecap="round"/>'


def f_tridente(L):
    c, h = L.claro, L.halo
    L += barra(L, (16, 132), (150, 128), 12, ORO)
    L += f'<path d="M150,80 Q132,128 150,176" fill="none" stroke="{TRAZO}" stroke-width="16" stroke-linecap="round"/>'
    L += f'<path d="M150,80 Q132,128 150,176" fill="none" stroke="{L.degradado((140, 80), (150, 176), ORO)}" stroke-width="10" stroke-linecap="round"/>'
    for (y0, y1) in ((80, 82), (128, 128), (176, 174)):
        x1 = 214 if y0 == 128 else 198
        L += barra(L, (150, y0), (x1, y1), 8, ORO)
        L += poligono(L, [(x1 - 6, y1 - 11), (x1 + 26, y1), (x1 - 6, y1 + 11), (x1 + 2, y1)], ["#ffffff", c, h], (x1, y1 - 11), (x1, y1 + 11), ancho=3.5)
    # El sol en el cruce
    rayos = []
    for i in range(12):
        a = math.radians(i * 30)
        largo = 34 if i % 2 else 28
        rayos.append(f"M{140 + math.cos(a - .14) * 18:.1f},{128 + math.sin(a - .14) * 18:.1f} L{140 + math.cos(a) * largo:.1f},"
                     f"{128 + math.sin(a) * largo:.1f} L{140 + math.cos(a + .14) * 18:.1f},{128 + math.sin(a + .14) * 18:.1f} Z")
    L += f'<path d="{" ".join(rayos)}" fill="{c}" stroke="{TRAZO}" stroke-width="2.5" stroke-linejoin="round" filter="url(#resplandor)"/>'
    L += gema(L, 140, 128, 18, "#fff4c0", h)
    L += destello(236, 112, 7)


def f_guadana(L):
    c, h = L.claro, L.halo
    L += barra(L, (22, 186), (176, 92), 11, OBSIDIANA)
    L += barra(L, (40, 175), (62, 162), 13, CUERO, brillo=False)
    # La hoja: media luna fantasmal que sale del extremo y se curva hacia atras
    exterior = [(130 + math.cos(math.radians(a)) * 100, 150 + math.sin(math.radians(a)) * 100) for a in range(-22, -128, -8)]
    interior = [(142 + math.cos(math.radians(a)) * 76, 162 + math.sin(math.radians(a)) * 66) for a in range(-124, -30, 8)]
    pts = exterior + interior
    L += f'<path d="M{" L".join(fp(p) for p in pts)} Z" fill="{c}" opacity=".35" filter="url(#resplandor)"/>'
    L += poligono(L, pts, ["#ffffff", c, h], (120, 50), (150, 110))
    L += f'<path d="M{" L".join(fp(p) for p in exterior)}" fill="none" stroke="#ffffff" stroke-width="2.2" opacity=".85"/>'
    # Almas que se escapan del filo
    for (x, y, k) in ((70, 76, 1), (104, 52, -1), (40, 108, 1)):
        L += (f'<path d="M{x},{y} q{-8 * k},-10 0,-20 q{8 * k},-10 0,-20" fill="none" stroke="{c}" stroke-width="3" '
              f'stroke-linecap="round" opacity=".7" filter="url(#resplandor)"/>')
    # Calavera en la union
    L += f'<circle cx="176" cy="94" r="14" fill="{L.radial(176, 94, 14, ["#ffffff", "#e8e0c8", "#8a826c"])}" stroke="{TRAZO}" stroke-width="3.5"/>'
    L += f'<circle cx="171" cy="93" r="3.6" fill="{TRAZO}"/><circle cx="181" cy="93" r="3.6" fill="{TRAZO}"/>'
    L += f'<circle cx="171" cy="93" r="1.6" fill="{c}"/><circle cx="181" cy="93" r="1.6" fill="{c}"/>'


def f_martillo(L):
    c, h = L.claro, L.halo
    L += barra(L, (20, 140), (150, 128), 13, MADERA)
    for x in (34, 46, 58):
        L += f'<path d="M{x},{132:.0f} L{x + 5},{148}" stroke="{TRAZO}" stroke-width="2.4" opacity=".6"/>'
    L += barra(L, (22, 132), (66, 128), 15, CUERO, brillo=False)
    L += poligono(L, [(10, 140), (24, 132), (24, 148)], HIERRO, ancho=3.5)
    cabeza = [(142, 72), (206, 72), (218, 86), (218, 170), (206, 184), (142, 184), (130, 170), (130, 86)]
    L += poligono(L, cabeza, HIERRO, (130, 128), (218, 128))
    L += poligono(L, [(142, 72), (206, 72), (218, 86), (130, 86)], ["#d0d6e0", "#8a90a0"], ancho=3)
    L += poligono(L, [(130, 170), (218, 170), (206, 184), (142, 184)], ["#3a4050", "#0e1018"], ancho=3)
    for x in (146, 202):
        L += barra(L, (x, 88), (x, 168), 8, PLATA)
    L += f'<circle cx="174" cy="128" r="28" fill="{aclarar(h, -.6)}" stroke="{TRAZO}" stroke-width="3.5"/>'
    L += (f'<g filter="url(#resplandor)"><path d="M174,108 L174,148 M160,116 L174,128 L188,116 M160,142 L188,142" fill="none" '
          f'stroke="{c}" stroke-width="5" stroke-linecap="round" stroke-linejoin="round"/></g>')
    L += destello(212, 80, 6)


def f_abismo(L):
    c, h = L.claro, L.halo
    L += barra(L, (20, 160), (156, 126), 12, OBSIDIANA)
    for k in (-1, 1):                # las garras que sujetan el orbe
        d = f"M152,{126 + k * 4} Q{160 + 0},{126 + k * 44} {200},{118 + k * 40} Q{214},{118 + k * 34} {222},{118 + k * 20}"
        L += f'<path d="{d}" fill="none" stroke="{TRAZO}" stroke-width="13" stroke-linecap="round"/>'
        L += f'<path d="{d}" fill="none" stroke="#3a2a58" stroke-width="7" stroke-linecap="round"/>'
        L += f'<path d="{d}" fill="none" stroke="{c}" stroke-width="1.6" stroke-linecap="round" opacity=".7"/>'
    L += L.luz(190, 118, 62, c, .7)
    L += (f'<ellipse cx="190" cy="118" rx="50" ry="13" fill="none" stroke="{c}" stroke-width="5" transform="rotate(-18 190 118)" '
          f'stroke-dasharray="80 30" filter="url(#resplandor)"/>')
    L += f'<circle cx="190" cy="118" r="26" fill="#000000" stroke="{aclarar(c, .4)}" stroke-width="3"/>'
    L += f'<circle cx="190" cy="118" r="20" fill="none" stroke="{h}" stroke-width="2" opacity=".8"/>'
    L += (f'<path d="M140,118 A50,13 0 0,0 240,118" fill="none" stroke="#ffffff" stroke-width="2.4" transform="rotate(-18 190 118)" '
          f'opacity=".9"/>')
    for (x, y, r) in ((230, 76, 5), (150, 82, 4), (238, 150, 4)):
        L += destello(x, y, r * 1.6, aclarar(c, .5))
    L += gema(L, 24, 158, 9, c, h, brilla=False)


def f_corona(L):
    c, h = L.claro, L.halo
    picos = [(54, 158), (40, 82), (82, 120), (104, 60), (128, 108), (152, 60), (174, 120), (216, 82), (202, 158)]
    L += poligono(L, picos, ORO, (128, 60), (128, 158))
    L += poligono(L, [(50, 154), (206, 154), (200, 192), (56, 192)], ORO, (128, 154), (128, 192))
    L += f'<path d="M56,166 L200,166" stroke="#7a4a10" stroke-width="2.2" opacity=".7"/>'
    for (x, y, r) in ((40, 78, 10), (104, 56, 11), (152, 56, 11), (216, 78, 10)):
        L += gema(L, x, y, r, c, h)
    for (x, r) in ((88, 9), (128, 12), (168, 9)):
        L += gema(L, x, 174, r, c, h, brilla=(r > 10))
    # Rayos que saltan de las puntas
    L += rayo_zigzag([(104, 44), (92, 30), (102, 22), (86, 6)], c, 4)
    L += rayo_zigzag([(152, 44), (166, 32), (156, 22), (172, 8)], c, 4)
    L += rayo_zigzag([(222, 66), (236, 58), (230, 46), (246, 40)], c, 3)
    L += destello(128, 96, 8)


FORMAS = {"varita": f_varita, "cetro": f_cetro, "daga": f_daga, "tomo": f_tomo, "horquilla": f_horquilla,
          "gemelas": f_dagas_gemelas, "serpiente": f_serpiente, "orbe": f_orbe, "tridente": f_tridente,
          "guadana": f_guadana, "martillo": f_martillo, "abismo": f_abismo, "corona": f_corona}


# ============================================================== TIERS ===
def anillo_runas(color, claro):
    """Detras de las miticas: dos anillos de runas, uno dentro de otro."""
    out = (f'<circle cx="128" cy="128" r="116" fill="none" stroke="{color}" stroke-width="3" opacity=".55"/>'
           f'<circle cx="128" cy="128" r="104" fill="none" stroke="{color}" stroke-width="1.6" opacity=".45" stroke-dasharray="3 6"/>')
    for i in range(12):
        a = math.radians(i * 30)
        x, y = 128 + math.cos(a) * 110, 128 + math.sin(a) * 110
        out += (f'<g transform="translate({x:.1f} {y:.1f}) rotate({i * 30 + 90})" opacity=".8">'
                f'<path d="M-4,-5 L0,5 L4,-5 M-3,-1 L3,-1" fill="none" stroke="{claro}" stroke-width="2" stroke-linecap="round"/></g>')
    return out


def destellos_tier(tier, claro):
    if tier < LEGENDARIO:
        return ""
    sitios = [(44, 52, 9), (214, 40, 7), (226, 206, 10), (36, 198, 6)]
    if tier == MITICO:
        sitios += [(128, 18, 8), (240, 128, 6), (16, 128, 6)]
    return "".join(destello(x, y, r, "#ffffff") + destello(x, y, r * .55, claro) for x, y, r in sitios)


def con_resplandor(imagen, color, radio):
    alfa = imagen.getchannel("A").point(lambda v: 255 if v > 120 else 0).filter(ImageFilter.GaussianBlur(radio))
    alfa = alfa.point(lambda v: min(210, round(v * 1.7)))
    halo = Image.new("RGBA", imagen.size, tuple(int(color[i:i + 2], 16) for i in (1, 3, 5)) + (0,))
    halo.putalpha(alfa)
    return Image.alpha_composite(halo, imagen)


def svgs(arma):
    """El del icono (recto) y el de la ilustracion (inclinado, con lo del tier)."""
    L = Lienzo(arma)
    FORMAS[arma["forma"]](L)
    icono = L.svg()
    tier = arma["tier"]
    fondo = anillo_runas(arma["halo"], arma["color"]) if tier == MITICO else ""
    grande = L.svg(lambda s: f'<g transform="rotate(-32 128 128) translate(128 128) scale(.9) translate(-128 -128)">{s}</g>'
                   + destellos_tier(tier, arma["color"]), fondo)
    return icono, grande


def renderizar(trabajos, tmp):
    """[(svg, nombre, px)] -> {nombre: Image}, con 8 hilos."""
    def uno(t):
        texto, nombre, px = t
        ruta = os.path.join(tmp, nombre)
        with open(ruta + ".svg", "w", encoding="utf-8") as f:
            f.write(texto)
        subprocess.run(["rsvg-convert", "-w", str(px), "-h", str(px), ruta + ".svg", "-o", ruta + ".png"], check=True)
        return nombre, Image.open(ruta + ".png").convert("RGBA")
    with ThreadPoolExecutor(max_workers=8) as hilos:
        return dict(hilos.map(uno, trabajos))


def imagenes(arma, tmp):
    icono, grande = svgs(arma)
    # Al doble y reducido: con el filtro bueno sale mas fino que a su tamano.
    hechas = renderizar([(icono, arma["id"] + "_i", LADO * 2), (grande, arma["id"] + "_g", GRANDE * 2)], tmp)
    brillo = BRILLO[arma["tier"]]
    pequeno = reducir(hechas[arma["id"] + "_i"], (LADO, LADO))
    ilustracion = reducir(hechas[arma["id"] + "_g"], (GRANDE, GRANDE))
    if brillo:
        pequeno = con_resplandor(pequeno, arma["halo"], brillo * LADO / GRANDE)
        ilustracion = con_resplandor(ilustracion, arma["halo"], brillo)
    pequeno.save(os.path.join(ICONOS, arma["id"] + ".png"))
    ilustracion.save(os.path.join(ICONOS, arma["id"] + "_grande.png"))


def valor(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, str):
        return '"%s"' % v
    return repr(v)


def color_godot(texto):
    return "Color(%.3f, %.3f, %.3f, 1)" % tuple(int(texto[i:i + 2], 16) / 255.0 for i in (1, 3, 5))


def recurso(arma):
    lineas = ['[gd_resource type="Resource" script_class="ArmaMago" load_steps=%d format=3]' % (5 + len(arma["modos"])),
              "", '[ext_resource type="Script" path="res://scripts/arma_mago.gd" id="1_arma"]',
              '[ext_resource type="Script" path="res://scripts/modo_arma.gd" id="2_modo"]',
              '[ext_resource type="Texture2D" path="res://assets/armas/%s.png" id="3_icono"]' % arma["id"],
              '[ext_resource type="Texture2D" path="res://assets/armas/%s_grande.png" id="4_ilustracion"]' % arma["id"], ""]
    for i, m in enumerate(arma["modos"]):
        lineas += ['[sub_resource type="Resource" id="modo_%d"]' % i, 'script = ExtResource("2_modo")']
        lineas += ["%s = %s" % (k, valor(v)) for k, v in m.items()]
        lineas.append("")
    modos = ", ".join('SubResource("modo_%d")' % i for i in range(len(arma["modos"])))
    lineas += ["[resource]", 'script = ExtResource("1_arma")', 'nombre = "%s"' % arma["nombre"],
               'descripcion = "%s"' % arma["descripcion"], "tier = %d" % arma["tier"], 'icono = ExtResource("3_icono")',
               'ilustracion = ExtResource("4_ilustracion")',
               "color = %s" % color_godot(arma["color"]), "halo = %s" % color_godot(arma["halo"]),
               "estilo = %d" % arma["estilo"], "muerte = %d" % arma["muerte"],
               'modos = Array[ExtResource("2_modo")]([%s])' % modos]
    guardar_texto(os.path.join(RECURSOS, arma["id"] + ".tres"), lineas)


def main():
    os.makedirs(ICONOS, exist_ok=True)
    os.makedirs(RECURSOS, exist_ok=True)
    elegidas = sys.argv[1:]
    tmp = tempfile.mkdtemp(prefix="armas_")
    try:
        for arma in ARMAS:
            if not elegidas or arma["id"] in elegidas:
                imagenes(arma, tmp)
                recurso(arma)
    finally:
        shutil.rmtree(tmp)
    print("Listo: %d armas" % len(ARMAS))


if __name__ == "__main__":
    main()
