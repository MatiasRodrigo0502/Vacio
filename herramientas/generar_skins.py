# -*- coding: utf-8 -*-
"""Genera las skins de los magos (el gacha de monedas) desde su dibujo vectorial.

Rehechas el 2026-11-05 (Matias: «mejora las skins y las armas»). Hasta
entonces salian de recolorear pixel a pixel la hoja del mago, y una S+ era el
mismo dibujo con otro color y un halo. Ahora salen del dibujo vectorial
(magos_vectorial.py), en las ocho direcciones, y cada tier da mas que el de
debajo:

- B: otro color. Todo el dibujo con otro tono.
- A: otra paleta y un efecto suyo (ceniza, petalos, burbujas, gotas).
- S: un traje: paleta, piezas propias (mascara de pico, hombreras de cristal,
  un eclipse, grietas de lava) y resplandor.
- S+: una transformacion: piezas grandes (alas, cintas de aurora, planetas),
  resplandor y el aura de arcoiris en el juego (AuraSkin). Dos llevan ademas un
  brillo iridiscente que les corre por el cuerpo al andar.

LOS COLORES: el dibujo de serie lleva todos sus colores en minuscula, y la
receta de cada skin (`receta`) los cambia todos. Lo que anade una skin va en
MAYUSCULAS si tiene que quedarse como esta (los ojos de la mascara, la lava) y
en minuscula si tiene que seguir a la receta (las burbujas de la toxina).

Lo que sale, por skin, en assets/skins/<id>/: atlas.png (32 poses a 72 px),
animaciones.tres, retrato.png (el gacha) y giro.png (las 8 direcciones en
grande, para la ficha y la cinematica). Y resources/skins/<id>.tres, que es lo
que lee el gacha. Tambien el giro.png de los cuatro magos de serie, en
assets/mago_<color>/.

Necesita rsvg-convert, como magos_vectorial.py. Unos 40 s con 8 hilos.

    python herramientas/generar_skins.py [rojo_smas ...]
"""
import colorsys
import math
import os
import re
import shutil
import subprocess
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor

from PIL import Image, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import magos_vectorial as mv  # noqa: E402
from generar_magos import (ALTO_RETRATO, DIRECCIONES, PASOS, POSE_PX, VELOCIDAD_PASO,  # noqa: E402
                           animacion, guardar_texto, reducir)

RAIZ = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
ASSETS = os.path.join(RAIZ, "assets")
RECURSOS = os.path.join(RAIZ, "resources", "skins")
ORIGEN_PX = 128
GIRO_PX = 256
TAU = 2 * math.pi
B, A, S, S_MAS = range(4)


# =============================================================== COLORES ===
# Sin "(" ni letra delante: url(#cab) es una referencia, no un color.
HEX = re.compile(r"(?<![\w(])#([0-9a-f]{6}|[0-9a-f]{3})(?![0-9A-Za-z])")


def c(texto):
    return tuple(int(texto[i:i + 2], 16) / 255.0 for i in (1, 3, 5))


def recolorear(texto, receta):
    """Pasa cada color en minuscula del SVG por la receta (r, g, b de 0 a 1)."""
    def cambio(m):
        h = m.group(1)
        if len(h) == 3:
            h = "".join(ch * 2 for ch in h)
        r, g, b = receta(*(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)))
        return "#%02x%02x%02x" % tuple(max(0, min(255, round(v * 255))) for v in (r, g, b))
    return HEX.sub(cambio, texto)


def luz(r, g, b):
    return 0.3 * r + 0.59 * g + 0.11 * b


def girar(tono, saturar=1.0):
    def receta(r, g, b):
        h, s, v = colorsys.rgb_to_hsv(r, g, b)
        return colorsys.hsv_to_rgb((h + tono) % 1.0, min(1.0, s * saturar), v)
    return receta


def en_paleta(paleta, t):
    t = min(max(t, 0.0), 1.0) * (len(paleta) - 1)
    i = min(int(t), len(paleta) - 2)
    k = t - i
    return tuple(paleta[i][n] + (paleta[i + 1][n] - paleta[i][n]) * k for n in range(3))


def paleta(colores, curva=0.7, dejar=None):
    """Cada color toma el de la paleta que le toca por lo claro que es. Con
    algo de contraste (curva): el arte es muy oscuro, y sin ella casi todo se
    queda en los dos primeros tonos. 'dejar' respeta los que diga (el fuego)."""
    tonos = [c(t) for t in colores]

    def receta(r, g, b):
        if dejar is not None and dejar(r, g, b):
            return r, g, b
        return en_paleta(tonos, luz(r, g, b) ** curva)
    return receta


def es_fuego(r, g, b):
    # Solo lo que brilla: el rojo de la capucha (b02a1c) y el borde oscuro de
    # las llamas (b8180c) son casi el mismo color, y con v > 0,5 la capucha se
    # quedaba roja en la Ceniza.
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    return (h < 0.17 or h > 0.95) and s > 0.45 and v > 0.8


def es_toxico(r, g, b):
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    return 0.15 < h < 0.45 and s > 0.45 and v > 0.55


# ============================================================ PIEZAS ===
def pluma(base, punta, ancho, relleno, borde, curva=0.0):
    """Una pluma (o una lengua) afilada de la base a la punta."""
    mx, my = (base[0] + punta[0]) / 2, (base[1] + punta[1]) / 2
    dx, dy = punta[0] - base[0], punta[1] - base[1]
    control = (mx - dy * curva, my + dx * curva)
    d, _, _ = mv.poligono_curvo(base, control, punta, ancho, N=10)
    return f'<path d="{d}" fill="{relleno}" stroke="{borde}" stroke-width="1.8" stroke-linejoin="round"/>'


def en_ala(P, raiz, lado, a, b):
    """Un punto del plano del ala (a hacia fuera, b hacia arriba) en pantalla.
    De perfil el ala se veria como una raya: se barre hacia atras."""
    lx, lz = mv.sc(P.theta, lado * 90)
    return (raiz[0] + a * lx - P.sin * a * 0.45 * abs(lz), raiz[1] - b + a * lz * 0.16)


def raiz_alas(P, y=124):
    x, yy, _ = P.punto(180, 12, y)
    return x, yy


def por_profundidad(P, piezas_por_lado):
    """El ala lejana primero. piezas_por_lado: {lado: svg}."""
    return "".join(piezas_por_lado[lado] for lado in sorted(piezas_por_lado, key=lambda l: mv.sc(P.theta, l * 90)[1]))


def redondeado(pts):
    """Un poligono cerrado con las esquinas redondeadas: cada lado va de punto
    medio a punto medio, curvandose en el vertice."""
    medios = [((pts[i][0] + pts[(i + 1) % len(pts)][0]) / 2, (pts[i][1] + pts[(i + 1) % len(pts)][1]) / 2) for i in range(len(pts))]
    d = f"M{medios[-1][0]:.1f},{medios[-1][1]:.1f}"
    for i, p in enumerate(pts):
        d += f" Q{p[0]:.1f},{p[1]:.1f} {medios[i][0]:.1f},{medios[i][1]:.1f}"
    return d + " Z"


def estrella(x, y, r, color, op=1.0):
    return (f'<path d="M{x:.1f},{y - r:.1f} Q{x:.1f},{y:.1f} {x + r:.1f},{y:.1f} Q{x:.1f},{y:.1f} {x:.1f},{y + r:.1f} '
            f'Q{x:.1f},{y:.1f} {x - r:.1f},{y:.1f} Q{x:.1f},{y:.1f} {x:.1f},{y - r:.1f} Z" fill="{color}" opacity="{op:.2f}"/>')


def iridiscente(P, cuerpo, colores, opacidad=0.85, periodo=150.0):
    """Un degradado de arcoiris por encima del cuerpo, mezclado en modo color
    (se queda la luz del dibujo y cambia el tono) y recortado a su silueta. Se
    desplaza un periodo cada 4 pasos: al andar, corre por el cuerpo sin saltos."""
    paso = periodo / 4.0
    stops = "".join(f'<stop offset="{i / (len(colores) - 1):.3f}" stop-color="{col}"/>' for i, col in enumerate(colores))
    return (f'<defs><linearGradient id="arcoIris" gradientUnits="userSpaceOnUse" x1="0" y1="0" x2="{periodo}" y2="0" '
            f'spreadMethod="repeat" gradientTransform="rotate(28 128 128) translate({P.f * paso:.1f} 0)">{stops}</linearGradient>'
            f'<filter id="blancoIris"><feColorMatrix type="matrix" values="0 0 0 0 1  0 0 0 0 1  0 0 0 0 1  0 0 0 1 0"/></filter>'
            f'<g id="figIris">{cuerpo}</g>'
            f'<mask id="mascaraIris" maskUnits="userSpaceOnUse" x="0" y="0" width="256" height="256">'
            f'<use xlink:href="#figIris" filter="url(#blancoIris)"/></mask></defs>'
            f'<g mask="url(#mascaraIris)"><use xlink:href="#figIris"/>'
            f'<rect x="0" y="0" width="256" height="256" fill="url(#arcoIris)" opacity="{opacidad}" style="mix-blend-mode:color"/></g>')


# ============================================================ SKINS ===
class Skin:
    """Lo comun: el id (nombre de la carpeta), el nombre que se ve, el mago, el
    tier, la receta de color, el aura y su texto."""
    id = ""
    titulo = ""
    mago = ""
    tier = B
    receta = None
    aura = None
    arcoiris = False
    descripcion = ""

    def colorear(self, texto):
        return recolorear(texto, self.receta) if self.receta else texto


# --------------------------------------------------------- Mago rojo ---
class LlamaAzul(Skin, mv.Piromante):
    id, titulo, mago, tier = "rojo_b", "Llama azul", "Mago rojo", B
    receta = staticmethod(girar(0.58))
    descripcion = "El fuego de siempre, pero frío como un zafiro."


class Ceniza(Skin, mv.Piromante):
    id, titulo, mago, tier = "rojo_a", "Ceniza", "Mago rojo", A
    descripcion = "Lo que queda cuando todo ha ardido. Las brasas siguen vivas."

    @staticmethod
    def receta(r, g, b):
        if es_fuego(r, g, b):
            return r, g, b
        gris = luz(r, g, b) ** 0.85
        return gris * 0.96, gris * 0.97, gris * 1.04

    def efectos(self, P):
        def copo(c_, x, ph):
            y = 236 - ph * 200
            op = min(1, ph * 5) * (1 - max(0, ph - .7) / .3)
            g = ph * 300 + c_ * 40
            return (f'<rect x="{x + 8 * math.sin(ph * TAU + c_):.1f}" y="{y:.1f}" width="3.2" height="2.2" fill="#B8B0A8" '
                    f'opacity="{op * .85:.2f}" transform="rotate({g:.0f} {x:.1f} {y:.1f})"/>')
        return super().efectos(P) + mv.particulas_carril([P.cx - 70, P.cx - 30, P.cx + 34, P.cx + 72], 2, P.f, 4, copo)


class MagmaNegro(Skin, mv.Piromante):
    id, titulo, mago, tier = "rojo_s", "Magma negro", "Mago rojo", S
    aura = "#ff6a20"
    descripcion = "Túnica de obsidiana con grietas de lava que nunca se enfrían."

    @staticmethod
    def receta(r, g, b):
        if es_fuego(r, g, b):
            h, s, v = colorsys.rgb_to_hsv(r, g, b)
            return colorsys.hsv_to_rgb(h * 0.8, min(1, s * 1.1), min(1, v * 1.05))
        return en_paleta([c("#050303"), c("#1c0a08"), c("#4a1810"), c("#8a3a24")], luz(r, g, b) ** 0.8)

    GRIETAS = [(-58, [(150, 0), (168, 6), (186, -4), (206, 5)]), (-22, [(160, 0), (180, -6), (198, 4), (220, -3)]),
               (18, [(148, 0), (170, 5), (190, -5), (214, 4)]), (52, [(158, 0), (176, -5), (196, 6), (222, 0)]),
               (150, [(150, 0), (172, 6), (200, -4)]), (-150, [(156, 0), (178, -6), (204, 4)]), (95, [(170, 0), (196, 5)]),
               (-95, [(166, 0), (194, -5)])]

    def tunica_extra(self, P, d):
        # Grietas de lava pegadas a la tunica: giran con el cuerpo.
        lava = ""
        for phi, tramo in self.GRIETAS:
            pts = []
            for y, dphi in tramo:
                x, yy, z = P.punto(phi + dphi, P.ancho(y) * 0.98, y)
                pts.append((x, yy, z))
            if min(p[2] for p in pts) < 0.12:
                continue
            ruta = "M" + " L".join(f"{x:.1f},{y:.1f}" for x, y, _ in pts)
            pulso = 0.75 + 0.25 * math.sin(P.f * math.pi / 2 + phi)
            lava += (f'<path d="{ruta}" fill="none" stroke="#1A0402" stroke-width="5.5" stroke-linecap="round"/>'
                     f'<path d="{ruta}" fill="none" stroke="#FF5A14" stroke-width="2.8" stroke-linecap="round" '
                     f'opacity="{pulso:.2f}" filter="url(#resplandor)"/>'
                     f'<path d="{ruta}" fill="none" stroke="#FFE08A" stroke-width="1" stroke-linecap="round"/>')
        return super().tunica_extra(P, d) + f'<clipPath id="clipLava"><path d="{d}"/></clipPath><g clip-path="url(#clipLava)">{lava}</g>'

    def delante_capucha(self, P):
        # Las puntas de los cuernos, al rojo vivo.
        out = super().delante_capucha(P)
        for phi in (-55, 55):
            s_, z = mv.sc(P.theta, phi)
            if z < -0.2:
                continue
            bx = P.hx + 24 * s_ + P.punta * 0.5
            tx, ty = bx + 22 * s_ - 20 * P.sin, 74 + z * 24 * mv.PROF_Y - 42
            out += (f'<circle cx="{tx:.1f}" cy="{ty:.1f}" r="6" fill="#FF7A1A" opacity=".55" filter="url(#resplandor)"/>'
                    f'<circle cx="{tx:.1f}" cy="{ty:.1f}" r="2.4" fill="#FFF1B8"/>')
        return out


class Fenix(Skin, mv.Piromante):
    id, titulo, mago, tier = "rojo_smas", "Fénix", "Mago rojo", S_MAS
    aura, arcoiris = "#ffc040", True
    descripcion = "Renace de sus cenizas con alas de fuego y una cresta de plumas doradas."
    defs_extra = """
  <linearGradient id="plumaDorada" x1="0" x2="0" y1="1" y2="0"><stop offset="0" stop-color="#C8200C"/><stop offset=".55" stop-color="#FF9A1F"/><stop offset="1" stop-color="#FFF4C0"/></linearGradient>
"""

    ORO = [c("#160202"), c("#5a0a06"), c("#b0280c"), c("#ffa030"), c("#fff0c0")]

    @staticmethod
    def receta(r, g, b):
        # Todo hacia el oro: lo oscuro rojo sangre, lo claro dorado. Mas claro
        # que el dibujo (curva 0,75): un fenix no puede ser marron.
        h, s, v = colorsys.rgb_to_hsv(r, g, b)
        if s < 0.12 and v > 0.9:
            return r, g, b          # los brillos blancos, blancos
        return en_paleta(Fenix.ORO, luz(r, g, b) ** 0.75)

    # (angulo, largo): de casi horizontal a casi vertical. Tienen que asomar por
    # encima de los hombros, o de frente el cuerpo las tapa enteras.
    PLUMAS = [(-20, .55), (0, .75), (20, .92), (40, 1.0), (60, .95), (80, .8), (100, .62)]

    def espalda(self, P):
        rx, ry = raiz_alas(P)
        aleteo = 9 * math.sin(P.f * math.pi / 2)
        alas = {}
        for lado in (-1, 1):
            ala = (f'<defs><radialGradient id="alaFuego{lado + 1}" gradientUnits="userSpaceOnUse" cx="{rx:.1f}" cy="{ry:.1f}" r="110">'
                   f'<stop offset=".1" stop-color="#FFF4C0"/><stop offset=".45" stop-color="#FFB22E"/>'
                   f'<stop offset=".8" stop-color="#FF4A10"/><stop offset="1" stop-color="#A8140A"/></radialGradient></defs>')
            # Cada capa es un abanico entero con el borde festoneado (una punta por
            # pluma): plumas sueltas, a 72 px, parecian pinchos.
            for capa_, largo, relleno in ((0, 108, f"url(#alaFuego{lado + 1})"), (1, 66, "#FFD25A")):
                puntas = []
                for j, (beta, k) in enumerate(self.PLUMAS):
                    b_ = math.radians(beta + aleteo * (1 - capa_ * 0.4))
                    puntas.append(en_ala(P, (rx, ry), lado, largo * k * math.cos(b_), largo * k * math.sin(b_)))
                    if j < len(self.PLUMAS) - 1:
                        b2 = math.radians((beta + self.PLUMAS[j + 1][0]) / 2 + aleteo * (1 - capa_ * 0.4))
                        l2 = largo * min(k, self.PLUMAS[j + 1][1]) * 0.8
                        puntas.append(en_ala(P, (rx, ry), lado, l2 * math.cos(b2), l2 * math.sin(b2)))
                ruta = f"M{rx:.1f},{ry:.1f} L" + " L".join(f"{x:.1f},{y:.1f}" for x, y in puntas) + " Z"
                ala += f'<path d="{ruta}" fill="{relleno}" stroke="#5A0C04" stroke-width="2" stroke-linejoin="round"/>'
                # El canon de cada pluma, del arranque a su punta.
                ala += "".join(f'<path d="M{rx:.1f},{ry:.1f} L{(rx + x) / 2 + (x - rx) * .35:.1f},{(ry + y) / 2 + (y - ry) * .35:.1f}" '
                               f'stroke="#8A1A08" stroke-width="1.1" opacity=".55"/>' for x, y in puntas[::2])
            alas[lado] = f'<g filter="url(#resplandor)">{ala}</g>'
        return por_profundidad(P, alas)

    def _cuerno(self, P, phi):
        # En vez de cuernos, una cresta de plumas que se abre hacia atras.
        s_, z = mv.sc(P.theta, phi)
        bx, by = P.hx + 22 * s_ + P.punta * 0.5, 72 + z * 24 * mv.PROF_Y
        out = ""
        for k, (alto, abre) in enumerate(((46, 16), (38, 26), (30, 34))):
            punta = (bx + abre * s_ - (18 + 6 * k) * P.sin, by - alto)
            out += pluma((bx, by), punta, 6.5 - k, "url(#plumaDorada)", "#5A0C04", curva=-0.15 * (1 if s_ >= 0 else -1))
        return z, out


# -------------------------------------------------------- Mago oscuro ---
class NocheAzul(Skin, mv.MagoVacio):
    id, titulo, mago, tier = "oscuro_b", "Noche azul", "Mago oscuro", B
    receta = staticmethod(girar(-0.15))
    descripcion = "El vacío, del color de la noche."


class Sangre(Skin, mv.MagoVacio):
    id, titulo, mago, tier = "oscuro_a", "Sangre", "Mago oscuro", A
    receta = staticmethod(girar(0.24, 1.1))
    descripcion = "Las runas le sangran, y la túnica gotea."

    def tunica_extra(self, P, d):
        out = super().tunica_extra(P, d)
        for i, phi in enumerate((-60, -25, 10, 40, 75)):
            x, y, z = P.punto(phi, P.wb * 0.92, 214)
            if z < 0.15:
                continue
            ph = ((P.f + i) % 4) / 4.0
            largo = 6 + 14 * ph
            out += (f'<path d="M{x:.1f},{y:.1f} L{x:.1f},{y + largo:.1f}" stroke="#7A0610" stroke-width="3.2" stroke-linecap="round"/>'
                    f'<circle cx="{x:.1f}" cy="{y + largo + 1.5:.1f}" r="2.6" fill="#B0101E"/>'
                    f'<circle cx="{x - .8:.1f}" cy="{y + largo + .6:.1f}" r=".8" fill="#FFB0B0"/>')
        return out


class EclipseDorado(Skin, mv.MagoVacio):
    id, titulo, mago, tier = "oscuro_s", "Eclipse dorado", "Mago oscuro", S
    aura = "#e8b030"
    receta = staticmethod(paleta(["#040302", "#2a2008", "#d8a020", "#fff4c0"]))
    descripcion = "Un sol negro le arde detrás de la cabeza."

    def detras_capucha(self, P):
        # El eclipse sustituye al halo roto: 12 rayos, largos y cortos alternos.
        # Giran 15 grados por paso: en 4 pasos, 60, y cada rayo largo llega al
        # sitio del siguiente largo (con 7,5 llegaria al de uno corto y saltaria).
        cx, cy = P.hx + P.punta * 0.55, 64
        out = f'<circle cx="{cx:.1f}" cy="{cy:.1f}" r="60" fill="#FFB02A" opacity=".18" filter="url(#resplandor)"/>'
        for i in range(12):
            a = math.radians(i * 30 + P.f * 15)
            largo = 58 if i % 2 else 50
            pts = [(cx + math.cos(a - .09) * 36, cy + math.sin(a - .09) * 36), (cx + math.cos(a) * largo, cy + math.sin(a) * largo),
                   (cx + math.cos(a + .09) * 36, cy + math.sin(a + .09) * 36)]
            out += f'<path d="M{" L".join(f"{x:.1f},{y:.1f}" for x, y in pts)} Z" fill="#FFD46A" stroke="#5A3A08" stroke-width="1.2"/>'
        out += (f'<circle cx="{cx:.1f}" cy="{cy:.1f}" r="37" fill="none" stroke="#5A3A08" stroke-width="7"/>'
                f'<circle cx="{cx:.1f}" cy="{cy:.1f}" r="37" fill="none" stroke="#FFD46A" stroke-width="4" filter="url(#resplandor)"/>'
                f'<circle cx="{cx:.1f}" cy="{cy:.1f}" r="33" fill="#050302"/>'
                f'<circle cx="{cx:.1f}" cy="{cy:.1f}" r="33" fill="none" stroke="#FFF4C0" stroke-width="1.4" opacity=".9"/>')
        return out

    def delante_capucha(self, P):
        return ""


class Cosmos(Skin, mv.MagoVacio):
    id, titulo, mago, tier = "oscuro_smas", "Cosmos", "Mago oscuro", S_MAS
    aura, arcoiris = "#a060ff", True
    receta = staticmethod(girar(-0.04, 1.15))
    descripcion = "Lleva el cielo entero en la túnica, y planetas girando a su alrededor."
    ESTRELLAS = [((i * 47) % 360 - 180, 138 + (i * 29) % 92, 0.8 + (i % 3) * 0.5) for i in range(30)]
    # Dos planetas con anillo y dos lunas, alternos: giran 45 grados por paso, y
    # en 4 pasos (180) cada uno llega al sitio del otro de su clase. Con tres
    # distintos el bucle no cerraria: al volver al paso 0 saltarian.
    PLANETAS = [(10, "#7AD8FF", "#1A3A8A", True), (6.5, "#FFD46A", "#8A4A10", False),
                (10, "#7AD8FF", "#1A3A8A", True), (6.5, "#FFD46A", "#8A4A10", False)]

    def tunica_extra(self, P, d):
        cielo = ""
        for i, (dx, dy, r, col) in enumerate(((-40, 166, 40, "#B060FF"), (30, 196, 36, "#3AC8FF"), (-5, 224, 34, "#FF5AC8"),
                                              (150, 180, 40, "#6A4AFF"), (-150, 214, 36, "#3AC8FF"))):
            x, y, _ = P.punto(dx, P.ancho(dy) * 0.5, dy)
            cielo += (f'<ellipse cx="{x:.1f}" cy="{y:.1f}" rx="{r}" ry="{r * .55:.1f}" fill="{col}" opacity=".42" filter="url(#resplandor)"/>'
                      f'<ellipse cx="{x:.1f}" cy="{y:.1f}" rx="{r * .45:.1f}" ry="{r * .25:.1f}" fill="#FFFFFF" opacity=".18"/>')
        for i, (phi, y, r) in enumerate(self.ESTRELLAS):
            x, yy, z = P.punto(phi, P.ancho(y) * 0.92, y)
            if z < 0.05:
                continue
            brillo = 0.45 + 0.55 * abs(math.sin(P.f * 1.3 + i))
            cielo += estrella(x, yy, r * 1.8 * (0.6 + 0.4 * z), "#FFFFFF", brillo)
        return super().tunica_extra(P, d) + f'<clipPath id="clipCosmos"><path d="{d}"/></clipPath><g clip-path="url(#clipCosmos)">{cielo}</g>'

    def orbitas(self, P):
        piezas = []
        for i, (r, claro, oscuro, anillo) in enumerate(self.PLANETAS):
            a = math.radians(P.f * 45 + i * 90)
            x, y, z = P.cx + 84 * math.cos(a), 146 + 26 * math.sin(a), math.sin(a)
            k = 0.85 + 0.15 * z
            pid = f"planeta{i}"
            s_ = (f'<defs><radialGradient id="{pid}" cx=".35" cy=".3" r=".8"><stop offset="0" stop-color="{claro}"/>'
                  f'<stop offset="1" stop-color="{oscuro}"/></radialGradient></defs>'
                  f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{r * k + 3:.1f}" fill="{claro}" opacity=".25" filter="url(#resplandor)"/>'
                  f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{r * k:.1f}" fill="url(#{pid})" stroke="#0A0414" stroke-width="1.4"/>')
            if anillo:
                s_ += (f'<ellipse cx="{x:.1f}" cy="{y:.1f}" rx="{r * 1.9 * k:.1f}" ry="{r * 0.55 * k:.1f}" fill="none" '
                       f'stroke="#E8D8FF" stroke-width="1.6" transform="rotate(-18 {x:.1f} {y:.1f})"/>')
            piezas.append((z, s_))
        return piezas


# -------------------------------------------------------- Mago blanco ---
class Glaciar(Skin, mv.Criomante):
    id, titulo, mago, tier = "blanco_b", "Glaciar", "Mago blanco", B
    receta = staticmethod(girar(-0.1))
    descripcion = "Hielo viejo, verde como el fondo de un glaciar."


class Sakura(Skin, mv.Criomante):
    id, titulo, mago, tier = "blanco_a", "Sakura", "Mago blanco", A
    receta = staticmethod(paleta(["#1a0812", "#8a2c5c", "#f08cc0", "#fff0f6"]))
    descripcion = "Pétalos de cerezo en vez de copos de nieve."

    def efectos(self, P):
        def petalo(c_, x, ph):
            y = 24 + ph * 210
            op = min(1, ph * 5) * (1 - max(0, ph - .8) / .2)
            x2 = x + 10 * math.sin(ph * TAU + c_)
            g = ph * 360 + c_ * 70
            return (f'<path d="M{x2:.1f},{y - 4:.1f} Q{x2 + 4:.1f},{y:.1f} {x2:.1f},{y + 4:.1f} Q{x2 - 4:.1f},{y:.1f} {x2:.1f},{y - 4:.1f} Z" '
                    f'fill="#FFB0D8" stroke="#C04A8A" stroke-width=".8" opacity="{op:.2f}" transform="rotate({g:.0f} {x2:.1f} {y:.1f})"/>')
        return mv.particulas_carril([P.cx - 74, P.cx - 40, P.cx + 44, P.cx + 76, P.cx + 8], 2, P.f, 4, petalo)


class Diamante(Skin, mv.Criomante):
    id, titulo, mago, tier = "blanco_s", "Diamante", "Mago blanco", S
    aura = "#a0e0ff"
    receta = staticmethod(paleta(["#0a1020", "#2c5a9a", "#a8dcff", "#ffffff"]))
    descripcion = "Hombreras y corona de cristal tallado que destellan a cada paso."

    def _corona(self, P):
        piezas = []
        for phi, h in ((-62, 20), (-38, 30), (-16, 40), (0, 52), (16, 40), (38, 30), (62, 20)):
            s_, z = mv.sc(P.theta, phi)
            bx, by = P.hx + 22 * s_ + P.punta * .45, 72 + z * 22 * mv.PROF_Y
            piezas.append((z, mv.cristal(bx, by, bx + 8 * s_ - 5 * P.sin, by - h, 5.2)))
        return piezas

    def _hombreras(self, P):
        piezas = []
        for lado in (-1, 1):
            x, y, z = P.punto(lado * 90, 36, 132)
            s_, _ = mv.sc(P.theta, lado * 90)
            racimo = ""
            for k, (dx, alto, ancho) in enumerate(((-6, 18, 5), (4, 26, 6), (12, 16, 4.5))):
                racimo += mv.cristal(x + dx * 0.6, y, x + dx + 12 * s_, y - alto, ancho)
            piezas.append((z, racimo))
        return piezas

    def detras_capucha(self, P):
        return super().detras_capucha(P) + "".join(s_ for z, s_ in self._hombreras(P) if z < -0.2)

    def delante_capucha(self, P):
        return super().delante_capucha(P) + "".join(s_ for z, s_ in self._hombreras(P) if z >= -0.2)

    def efectos(self, P):
        destellos = ""
        for i, (dx, y) in enumerate(((-44, 100), (40, 128), (-30, 170), (36, 196), (0, 60), (-52, 210))):
            brillo = max(0.0, math.sin(P.f * math.pi / 2 + i * 1.7))
            if brillo > 0.2:
                destellos += estrella(P.cx + dx, y, 4 + 3 * brillo, "#FFFFFF", brillo)
        return super().efectos(P) + destellos


class Aurora(Skin, mv.Criomante):
    id, titulo, mago, tier = "blanco_smas", "Aurora", "Mago blanco", S_MAS
    aura, arcoiris = "#60ffc0", True
    receta = staticmethod(girar(0.06))
    descripcion = "La luz del norte le corre por el cuerpo y le hace un arco sobre la cabeza."
    COLORES = ["#40FF9A", "#40E0FF", "#7A6AFF", "#C060FF", "#40FF9A"]

    def espalda(self, P):
        # Tres arcos de luz por detras, de un hombro a otro pasando por encima de
        # la cabeza, ondeando (verde, azul y violeta, como la aurora). Con cintas
        # que subian de los hombros parecian antenas. Estan en el plano de los
        # hombros: de perfil se ven como una cuña echada hacia atras.
        rx, ry = raiz_alas(P, 136)
        lx, lz = mv.sc(P.theta, 90)
        arcos = ""
        for k, (radio, col) in enumerate(((96, "#40FF9A"), (82, "#40E0FF"), (68, "#9A6AFF"))):
            pts = []
            for i in range(25):
                a = math.radians(-105 + 210 * i / 24)
                r = radio + 5 * math.sin(4 * a + P.f * math.pi / 2 + k * 1.3)
                lateral, alto = r * math.sin(a), r * math.cos(a) + 8
                pts.append((rx + lateral * lx - P.sin * abs(lateral) * 0.5 * abs(lz), ry - alto + lateral * lz * 0.16))
            ruta_ = "M" + " L".join(f"{x:.1f},{y:.1f}" for x, y in pts)
            arcos += (f'<path d="{ruta_}" fill="none" stroke="{col}" stroke-width="16" stroke-linecap="round" opacity=".22" filter="url(#resplandor)"/>'
                      f'<path d="{ruta_}" fill="none" stroke="{col}" stroke-width="6" stroke-linecap="round" opacity=".75"/>'
                      f'<path d="{ruta_}" fill="none" stroke="#FFFFFF" stroke-width="1.6" stroke-linecap="round" opacity=".7"/>')
        return arcos

    def envolver(self, P, cuerpo):
        return iridiscente(P, cuerpo, self.COLORES, opacidad=0.7)


# --------------------------------------------------------- Mago verde ---
class Pantano(Skin, mv.Envenenador):
    id, titulo, mago, tier = "verde_b", "Pantano", "Mago verde", B
    receta = staticmethod(girar(-0.12))
    descripcion = "Huele a ciénaga. Y envenena igual."


class ToxinaPurpura(Skin, mv.Envenenador):
    id, titulo, mago, tier = "verde_a", "Toxina púrpura", "Mago verde", A
    receta = staticmethod(girar(0.45))
    descripcion = "Un veneno morado que burbujea sin parar."

    def efectos(self, P):
        def burbuja(c_, x, ph):
            y = 228 - ph * 150
            r = 2.5 + 1.5 * math.sin(c_ + ph * 6)
            op = min(1, ph * 6) * (1 - max(0, ph - .75) / .25)
            return (f'<circle cx="{x + 5 * math.sin(ph * TAU + c_):.1f}" cy="{y:.1f}" r="{r:.1f}" fill="#7dff3a" fill-opacity=".2" '
                    f'stroke="#c8ff6a" stroke-width="1.4" opacity="{op:.2f}"/>')
        return mv.particulas_carril([P.cx - 60, P.cx - 28, P.cx + 30, P.cx + 62], 2, P.f, 4, burbuja)


class DoctorPlaga(Skin, mv.Envenenador):
    id, titulo, mago, tier = "verde_s", "Doctor de la plaga", "Mago verde", S
    aura = "#b0ff30"
    receta = staticmethod(paleta(["#0a0604", "#2e1c10", "#6a4a2c", "#d8c09a"], dejar=es_toxico))
    descripcion = "Máscara de pico y lentes que brillan en la oscuridad."
    defs_extra = """
  <linearGradient id="cueroPico" x1="0" x2="1" y1="0" y2="1"><stop offset="0" stop-color="#8A5E38"/><stop offset=".55" stop-color="#4A2E18"/><stop offset="1" stop-color="#1E1208"/></linearGradient>
  <radialGradient id="lente" cx=".4" cy=".35" r=".7"><stop offset="0" stop-color="#F4FFB0"/><stop offset=".45" stop-color="#9DFF3A"/><stop offset="1" stop-color="#1E6A10"/></radialGradient>
"""

    def cara(self, P, vx, vw):
        out = ""
        for phi in (-27, 27):
            s_, z = mv.sc(P.theta, phi)
            if z < 0.2:
                continue
            x, k = P.hx + 24 * s_, z ** 0.6
            out += (f'<circle cx="{x:.1f}" cy="106" r="{13 * k:.1f}" fill="#9DFF3A" opacity="{.25 * mv.PULSO[P.f] + .1:.2f}" filter="url(#resplandor)"/>'
                    f'<ellipse cx="{x:.1f}" cy="106" rx="{7.5 * k:.1f}" ry="7.5" fill="#B08A3A" stroke="#1E1208" stroke-width="1.6"/>'
                    f'<ellipse cx="{x:.1f}" cy="106" rx="{5.2 * k:.1f}" ry="5.2" fill="url(#lente)"/>'
                    f'<ellipse cx="{x - 1.6 * k:.1f}" cy="104" rx="{1.6 * k:.1f}" ry="1.4" fill="#FFFFFF" opacity=".85"/>')
        return out

    def delante_capucha(self, P):
        out = super().delante_capucha(P)
        if P.cos < -0.2:
            return out
        # El pico sale de la cara hacia donde mira: de frente apunta abajo (hacia
        # la camara, se ve corto); de perfil se ve entero.
        bx, by = P.hx + 22 * P.sin, 116
        tx, ty = bx + 36 * P.sin, by + 6 + 18 * max(P.cos, 0)
        control = ((bx + tx) / 2, (by + ty) / 2 - 5)
        d, izq, der = mv.poligono_curvo((bx, by), control, (tx, ty), 8.5 * (0.75 + 0.25 * abs(P.sin)), N=10)
        costura = "M" + " L".join(f"{(a[0] + b_[0]) / 2:.1f},{(a[1] + b_[1]) / 2:.1f}" for a, b_ in zip(izq[1:-2], der[1:-2]))
        return out + (f'<path d="{d}" fill="url(#cueroPico)" stroke="#140C06" stroke-width="2" stroke-linejoin="round"/>'
                      f'<path d="{costura}" fill="none" stroke="#C8A070" stroke-width="1" stroke-dasharray="2 2"/>')


class PlagaArcoiris(Skin, mv.Envenenador):
    id, titulo, mago, tier = "verde_smas", "Plaga arcoíris", "Mago verde", S_MAS
    aura, arcoiris = "#ffffff", True
    descripcion = "Alas de polilla y un brillo de mil colores. Venenoso y precioso."
    COLORES = ["#FF3A6A", "#FFB02A", "#E8FF3A", "#3AFF8A", "#3AC8FF", "#9A5AFF", "#FF3A6A"]
    # Grandes: el cuerpo tapa la mitad de cada ala.
    ALA_ARRIBA = [(0, 0), (22, 34), (60, 60), (96, 56), (110, 28), (92, 0), (54, -8)]
    ALA_ABAJO = [(0, 0), (38, -12), (64, -38), (56, -66), (28, -58), (10, -30)]

    def espalda(self, P):
        rx, ry = raiz_alas(P, 120)
        abre = 1.0 + 0.12 * math.sin(P.f * math.pi / 2)
        alas = {}
        for lado in (-1, 1):
            ala = ""
            for forma, relleno in ((self.ALA_ARRIBA, "#6AD8C8"), (self.ALA_ABAJO, "#4AA8C8")):
                pts = [en_ala(P, (rx, ry), lado, a, b_ * abre) for a, b_ in forma]
                ala += (f'<path d="{redondeado(pts)}" fill="{relleno}" fill-opacity=".78" '
                        f'stroke="#0A1E1A" stroke-width="2" stroke-linejoin="round"/>')
                for a, b_ in forma[2:-1:2]:
                    x, y = en_ala(P, (rx, ry), lado, a * 0.9, b_ * abre * 0.9)
                    ala += f'<path d="M{rx:.1f},{ry:.1f} L{x:.1f},{y:.1f}" stroke="#0A1E1A" stroke-width="1" opacity=".5"/>'
            ox, oy = en_ala(P, (rx, ry), lado, 72, 32 * abre)
            ancho = max(0.35, abs(mv.sc(P.theta, lado * 90)[0]))
            ala += (f'<ellipse cx="{ox:.1f}" cy="{oy:.1f}" rx="{12 * ancho:.1f}" ry="12" fill="#0A1E1A"/>'
                    f'<ellipse cx="{ox:.1f}" cy="{oy:.1f}" rx="{8 * ancho:.1f}" ry="8" fill="#FFE08A"/>'
                    f'<ellipse cx="{ox:.1f}" cy="{oy:.1f}" rx="{3.4 * ancho:.1f}" ry="3.4" fill="#0A1E1A"/>')
            alas[lado] = ala
        return por_profundidad(P, alas)

    def efectos(self, P):
        def espora(c_, x, ph):
            y = 230 - ph * 190
            op = min(1, ph * 5) * (1 - max(0, ph - .7) / .3)
            return f'<circle cx="{x + 9 * math.sin(ph * TAU * 1.5 + c_):.1f}" cy="{y:.1f}" r="1.8" fill="#FFFFFF" opacity="{op:.2f}" filter="url(#resplandor)"/>'
        return mv.particulas_carril([P.cx - 64, P.cx - 22, P.cx + 26, P.cx + 66], 2, P.f, 4, espora)

    def envolver(self, P, cuerpo):
        return iridiscente(P, cuerpo, self.COLORES, opacidad=0.55, periodo=200.0)


SKINS = [LlamaAzul, Ceniza, MagmaNegro, Fenix, NocheAzul, Sangre, EclipseDorado, Cosmos,
         Glaciar, Sakura, Diamante, Aurora, Pantano, ToxinaPurpura, DoctorPlaga, PlagaArcoiris]
DE_SERIE = {"mago_rojo": mv.Piromante, "mago_oscuro": mv.MagoVacio, "mago_blanco": mv.Criomante, "mago_verde": mv.Envenenador}


# ========================================================= RENDER ===
def render_lote(trabajos, tmp):
    """[(svg, nombre, px)] -> {nombre: Image}. Con 8 hilos: rsvg-convert va solo."""
    def uno(t):
        texto, nombre, px = t
        ruta = os.path.join(tmp, nombre)
        with open(ruta + ".svg", "w", encoding="utf-8") as f:
            f.write(texto)
        subprocess.run(["rsvg-convert", "-w", str(px), "-h", str(px), ruta + ".svg", "-o", ruta + ".png"], check=True)
        return nombre, Image.open(ruta + ".png").convert("RGBA")
    with ThreadPoolExecutor(max_workers=8) as hilos:
        return dict(hilos.map(uno, trabajos))


def con_resplandor(imagen, color, radio):
    """Un halo del color por detras de la figura. Sale solo de lo opaco: con el
    alfa entero, lo casi transparente (la niebla, el bajo que se desvanece del
    mago oscuro) tambien brillaba, y el Eclipse salia dentro de una caja dorada."""
    alfa = imagen.getchannel("A").point(lambda v: 255 if v > 140 else 0).filter(ImageFilter.GaussianBlur(radio))
    alfa = alfa.point(lambda v: min(190, round(v * 1.5)))
    halo = Image.new("RGBA", imagen.size, tuple(round(v * 255) for v in c(color)) + (0,))
    halo.putalpha(alfa)
    return Image.alpha_composite(halo, imagen)


def giro(pj, tmp, aura=None):
    """Las 8 direcciones en grande, en el orden de las filas (DIRECCIONES)."""
    hechas = render_lote([(mv.svg(pj, mv.theta_de_fila(k), 0), f"giro_{k}", GIRO_PX * 2) for k in range(8)], tmp)
    tira = Image.new("RGBA", (GIRO_PX * 8, GIRO_PX))
    for k in range(8):
        pose = reducir(hechas[f"giro_{k}"], (GIRO_PX, GIRO_PX))
        if aura:
            pose = con_resplandor(pose, aura, 5)
        tira.alpha_composite(pose, (k * GIRO_PX, 0))
    return tira


def hacer_skin(clase, tmp):
    skin = clase()
    destino = os.path.join(ASSETS, "skins", skin.id)
    os.makedirs(destino, exist_ok=True)
    trabajos = [(mv.svg(skin, mv.theta_de_fila(k), p), f"pose_{k}_{p}", ORIGEN_PX) for k in range(8) for p in range(PASOS)]
    trabajos.append((mv.svg(skin, 0, 1), "retrato", 512))
    hechas = render_lote(trabajos, tmp)

    atlas = Image.new("RGBA", (POSE_PX * PASOS, POSE_PX * len(DIRECCIONES)))
    for k in range(8):
        for p in range(PASOS):
            pose = reducir(hechas[f"pose_{k}_{p}"], (POSE_PX, POSE_PX))
            if skin.aura and skin.tier >= S:
                pose = con_resplandor(pose, skin.aura, 2.5)
            atlas.alpha_composite(pose, (p * POSE_PX, k * POSE_PX))
    atlas.save(os.path.join(destino, "atlas.png"))

    entero = hechas["retrato"]
    entero = entero.crop(entero.getbbox())
    retrato = reducir(entero, (round(entero.width * ALTO_RETRATO / entero.height), ALTO_RETRATO))
    if skin.aura and skin.tier >= S:
        # Con margen: si no, el halo se corta en el borde de la imagen.
        lienzo = Image.new("RGBA", (retrato.width + 40, retrato.height + 40))
        lienzo.alpha_composite(retrato, (20, 20))
        retrato = con_resplandor(lienzo, skin.aura, 8)
    retrato.save(os.path.join(destino, "retrato.png"))
    giro(skin, tmp, skin.aura if skin.tier >= S else None).save(os.path.join(destino, "giro.png"))

    ruta = "res://assets/skins/%s/" % skin.id
    lineas = ['[gd_resource type="SpriteFrames" load_steps=%d format=3]' % (2 + len(DIRECCIONES) * PASOS), "",
              '[ext_resource type="Texture2D" path="%satlas.png" id="atlas"]' % ruta, ""]
    for fila, direccion in enumerate(DIRECCIONES):
        for paso in range(PASOS):
            lineas += ['[sub_resource type="AtlasTexture" id="%s_%d"]' % (direccion, paso),
                       'atlas = ExtResource("atlas")',
                       "region = Rect2(%d, %d, %d, %d)" % (paso * POSE_PX, fila * POSE_PX, POSE_PX, POSE_PX), ""]
    animaciones = [animacion("caminar_" + d, ["%s_%d" % (d, p) for p in range(PASOS)], VELOCIDAD_PASO, True) for d in DIRECCIONES]
    animaciones += [animacion("quieto_" + d, ["%s_0" % d], 1.0, True) for d in DIRECCIONES]
    lineas += ["[resource]", "animations = [%s]" % ", ".join(animaciones)]
    guardar_texto(os.path.join(destino, "animaciones.tres"), lineas)

    color_aura = "Color(%.3f, %.3f, %.3f, 1)" % c(skin.aura) if skin.aura else "Color(0, 0, 0, 0)"
    guardar_texto(os.path.join(RECURSOS, skin.id + ".tres"), [
        '[gd_resource type="Resource" script_class="SkinMago" load_steps=5 format=3]', "",
        '[ext_resource type="Script" path="res://scripts/skin_mago.gd" id="1_script"]',
        '[ext_resource type="SpriteFrames" path="%sanimaciones.tres" id="2_animaciones"]' % ruta,
        '[ext_resource type="Texture2D" path="%sretrato.png" id="3_retrato"]' % ruta,
        '[ext_resource type="Texture2D" path="%sgiro.png" id="4_giro"]' % ruta, "",
        "[resource]", 'script = ExtResource("1_script")',
        'nombre = "%s"' % skin.titulo, 'mago = "%s"' % skin.mago, "tier = %d" % skin.tier,
        'descripcion = "%s"' % skin.descripcion,
        'animaciones = ExtResource("2_animaciones")', 'retrato = ExtResource("3_retrato")', 'giro = ExtResource("4_giro")',
        "aura = %s" % color_aura, "arcoiris = %s" % ("true" if skin.arcoiris else "false"),
    ])


def main():
    os.makedirs(RECURSOS, exist_ok=True)
    elegidas = sys.argv[1:]
    tmp = tempfile.mkdtemp(prefix="skins_")
    try:
        for clase in SKINS:
            if not elegidas or clase.id in elegidas:
                hacer_skin(clase, tmp)
                print(clase.id, clase.titulo)
        if not elegidas:
            for carpeta, clase in DE_SERIE.items():
                giro(clase(), tmp).save(os.path.join(ASSETS, carpeta, "giro.png"))
                print(carpeta, "giro")
    finally:
        shutil.rmtree(tmp)


if __name__ == "__main__":
    main()
