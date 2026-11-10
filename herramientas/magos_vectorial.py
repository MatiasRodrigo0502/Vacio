# -*- coding: utf-8 -*-
"""El dibujo vectorial de los cuatro magos: el codigo que hizo las hojas de
assets/magos_fuente/ (vacio_magos_y_hechizos.zip, que trajo Matias el
2026-11-04). Con el, las skins (generar_skins.py) salen del mismo dibujo en
las ocho direcciones, con piezas suyas, y no de recolorear la hoja ya pintada.

Ejecutado a solas, vuelve a sacar las hojas de los magos en
assets/magos_fuente/magos/ (y luego generar_magos.py las reduce para el
juego). Sale igual pixel a pixel que las del paquete: comprobado el
2026-11-05 en la fila del sur de los cuatro.

Necesita rsvg-convert (librsvg) para pasar cada SVG a PNG: en Linux viene en
el paquete librsvg2-bin; en Windows, con MSYS2 (pacman -S
mingw-w64-x86_64-librsvg) o con Chocolatey. Las hojas ya hechas estan en el
repositorio: solo hace falta para cambiar el dibujo.

    python herramientas/magos_vectorial.py [piromante] [envenenador] [criomante] [vacio]

Piromante = mago rojo, Envenenador = mago verde, Criomante = mago blanco,
Mago del Vacio = mago oscuro.

TÉCNICA "PSEUDO-3D"
Cada pieza del mago vive en un ángulo `phi` alrededor del cuerpo, como si
estuviera pegada a un cilindro (phi=0 es el frente, -90 su derecha, +90 su
izquierda, 180 la espalda). Para dibujar una dirección `theta` giramos el
cilindro y proyectamos:
    x = centro + r * sin(theta + phi)      (posición horizontal en pantalla)
    z = cos(theta + phi)                   (profundidad: >0 hacia la cámara)
Con z decidimos si la pieza se pinta DELANTE o DETRÁS del cuerpo, y además
bajamos un poco en pantalla lo que está cerca de la cámara (vista cenital).

theta = 0 mira a cámara (sur), 90 mira a la derecha (este), 180 de espaldas.
"""
import math, os, shutil, subprocess
from PIL import Image

RAIZ = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "magos_fuente", "magos")
FRAME_PX = 128
TAU = 2 * math.pi
CX = 128            # centro del lienzo SVG (256x256)
PROF_Y = 0.2        # cuánto baja en pantalla lo cercano a la cámara

# Filas del sprite sheet en el orden de Vector2.angle() de Godot (0 = derecha)
DIRECCIONES = ["E", "SE", "S", "SO", "O", "NO", "N", "NE"]
REBOTE = [0, -3, 0, -3]
PASO = [0, 1, 0, -1]
PULSO = [0.65, 0.9, 0.7, 1.0]


def theta_de_fila(k):
    """Fila k de Godot (k*45° desde la derecha) -> nuestro theta."""
    return 90 - 45 * k


def sc(theta, phi=0):
    a = math.radians(theta + phi)
    return math.sin(a), math.cos(a)


def fp(p):
    return f"{p[0]:.1f},{p[1]:.1f}"


# ======================================================== GEOMETRÍA BASE ===
class Pose:
    """Todo lo que depende de la dirección y del frame de animación."""

    def __init__(self, theta, f, flota=False):
        self.theta, self.f = theta, f
        self.flota = flota
        self.sin, self.cos = sc(theta)
        s = abs(self.sin)
        self.cx = CX + 3 * self.sin          # centro del cuerpo
        self.hx = CX + 6 * self.sin          # la cabeza se adelanta un poco
        self.wt = 27 - 4 * s                 # media anchura de la túnica arriba
        self.wb = 56 - 13 * s                # ... y en el bajo (de perfil es más estrecha)
        self.rebote, self.paso = REBOTE[f], PASO[f]
        if flota:   # levita: sube 9 px y oscila suavemente en vez de dar pasos
            self.rebote = -9 + 2.5 * math.sin(f * math.pi / 2)
        self.punta = -14 * self.sin          # la punta de la capucha cae hacia atrás
        self.sgn = -1 if self.sin < -0.3 else 1

    def ancho(self, y):
        return self.wt + (self.wb - self.wt) * (y - 130) / 98

    def punto(self, phi, r, y):
        s, z = sc(self.theta, phi)
        return self.cx + r * s, y + z * r * PROF_Y, z

    def mano(self, phi, r=60, avance=0, y=192):
        """Mano a un ángulo phi, adelantada `avance` px en la dirección de la mirada."""
        s, z = sc(self.theta, phi)
        return (self.cx + r * s + avance * self.sin,
                y + z * r * PROF_Y + avance * self.cos * 0.3, z)

    def T(self, x, y):
        """Transforma un punto de la capucha (dibujada de frente) a esta dirección."""
        w = max(0.0, (136 - y) / 96) ** 1.6
        return f"{self.hx + (x - CX) + self.punta * w:.1f},{y}"


def jirones(x0, x1, y, n, prof, f, semilla=0):
    """Borde deshilachado en zigzag: azar fijo + vaivén según el frame."""
    pts = []
    for i in range(n + 1):
        x = x0 + (x1 - x0) * i / n
        ruido = ((i * 37 + semilla * 11) % 7) - 3
        vaiven = 2.5 * math.sin(f * math.pi / 2 + i * 1.3)
        pts.append(f"{x:.1f},{y + (prof if i % 2 else 0) + ruido + vaiven:.1f}")
    return " L".join(pts)


def zigzag(p0, p1, n, prof, f, semilla, u):
    """Como jirones pero entre dos puntos cualesquiera; las puntas salen hacia u."""
    pts = []
    for i in range(n + 1):
        t = i / n
        off = (prof if i % 2 else 0) + (((i * 37 + semilla * 11) % 5) - 2) * 0.7 \
            + 1.5 * math.sin(f * math.pi / 2 + i * 1.3)
        pts.append(fp((p0[0] + (p1[0] - p0[0]) * t + u[0] * off,
                       p0[1] + (p1[1] - p0[1]) * t + u[1] * off)))
    return " L".join(pts)


def poligono_curvo(B, C, Tp, w0, N=12):
    """Forma afilada a lo largo de una curva Bézier (cuernos, pinchos)."""
    izq, der = [], []
    for i in range(N + 1):
        t = i / N
        x = (1 - t) ** 2 * B[0] + 2 * (1 - t) * t * C[0] + t * t * Tp[0]
        y = (1 - t) ** 2 * B[1] + 2 * (1 - t) * t * C[1] + t * t * Tp[1]
        dx = 2 * (1 - t) * (C[0] - B[0]) + 2 * t * (Tp[0] - C[0])
        dy = 2 * (1 - t) * (C[1] - B[1]) + 2 * t * (Tp[1] - C[1])
        L = math.hypot(dx, dy) or 1
        w = w0 * (1 - t) ** 0.9 + 0.4
        izq.append((x - dy / L * w, y + dx / L * w))
        der.append((x + dy / L * w, y - dx / L * w))
    return "M" + " L".join(fp(p) for p in izq + der[::-1]) + " Z", izq, der


# ===================================================== PIEZAS COMUNES ===
def sombra_suelo(P):
    k = 0.75 if P.flota else 1.0            # si flota, la sombra es más pequeña y suave
    return (f'<ellipse cx="{P.cx:.1f}" cy="236" rx="{(56 - 10 * abs(P.sin)) * k:.1f}" ry="{12 * k:.1f}" '
            f'fill="url(#sombra)" opacity="{0.7 if P.flota else 1}"/>')


def niebla(P, delante=False):
    base = [(80, 234, 34), (128, 240, 44), (178, 234, 34), (104, 228, 26), (154, 228, 26)]
    if delante:
        base = [(92, 242, 26), (166, 242, 26)]
    out = ""
    for i, (x, y, rx) in enumerate(base):
        dx = 6 * math.sin(P.f * math.pi / 2 + i * 1.7)
        out += f'<ellipse cx="{x + dx:.1f}" cy="{y}" rx="{rx}" ry="{rx * 0.32:.1f}" fill="url(#niebla)"/>'
    return out


def pies(P):
    botas = []
    for phi, s in ((-90, P.paso), (90, -P.paso)):
        x, y, z = P.punto(phi, 13, 229)
        x += 9 * s * P.sin
        y += 4 * s * P.cos
        botas.append((y, f'<ellipse class="c" cx="{x:.1f}" cy="{y:.1f}" rx="{11 + 4 * abs(P.sin):.1f}" ry="7" fill="url(#bota)"/>'))
    return "".join(b for _, b in sorted(botas))


def capa(P, pj, encima):
    """Capa exterior. Cae detrás del cuerpo; de espaldas se pinta por encima."""
    c = CX - 14 * P.sin                       # se queda atrás al girar
    wb = 82 - 20 * abs(P.sin)
    borde = jirones(c - wb, c + wb, 229, 12, 10, P.f, 1)
    d = f"M{c - 36:.1f},128 Q{c - wb + 10:.1f},170 {c - wb:.1f},226 L{borde} Q{c + wb - 10:.1f},170 {c + 36:.1f},128 Z"
    out = f'<path class="c" d="{d}" fill="url(#capa)"/><path d="{d}" fill="url(#resplandorBajo)"/>'
    if encima:
        for phi in (180, 150, 210, 125, 235):
            s, z = sc(P.theta, phi)
            if z < 0.2:
                continue
            xt, xb = c + 30 * s, c + wb * 0.85 * s
            out += (f'<path d="M{xt:.1f},140 Q{(xt + xb) / 2:.1f},185 {xb:.1f},226" fill="none" '
                    f'stroke="#000" stroke-width="2.4" opacity="{0.4 + 0.5 * z:.2f}"/>')
    return out + pj.borde_capa(borde)


def tunica_d(P, prof):
    x0, x1 = P.cx - P.wb, P.cx + P.wb
    return (f"M{P.cx - P.wt:.1f},130 C{P.cx - P.wt - 6:.1f},165 {x0 + 8:.1f},200 {x0:.1f},226 "
            f"L{jirones(x0, x1, 228, 10, prof, P.f, 2)} C{x1 - 8:.1f},200 {P.cx + P.wt + 6:.1f},165 {P.cx + P.wt:.1f},130 Z")


def pliegues(P, color):
    """Pliegues pegados a la túnica: giran con el cuerpo y solo se ven por delante."""
    out = ""
    for phi in (-55, -25, 25, 55, 125, -125, 160, -160):
        s, z = sc(P.theta, phi)
        if z < 0.2:
            continue
        xt, xb = P.cx + P.ancho(182) * 0.85 * s, P.cx + P.wb * 0.88 * s
        out += (f'<path d="M{xt:.1f},182 Q{(xt + xb) / 2:.1f},205 {xb:.1f},226" fill="none" '
                f'stroke="{color}" stroke-width="2.2" opacity="{0.35 + 0.5 * z:.2f}"/>')
    return out


def tunica(P, pj):
    d = tunica_d(P, pj.prof_bajo)
    return (f'<g transform="rotate({1.8 * P.paso} {P.cx:.1f} 150)">'
            f'<path class="c" d="{d}" fill="url(#tunica)"/><path d="{d}" fill="url(#tunicaV)"/>'
            f'<path d="{d}" fill="url(#resplandorBajo)"/>'
            + pliegues(P, pj.color_pliegue) + pj.tunica_extra(P, d) + '</g>')


def cinturon(P):
    w1, w2 = P.ancho(164) + 1.5, P.ancho(175) + 1.5
    return (f'<path class="c" d="M{P.cx - w1:.1f},164 Q{P.cx:.1f},174 {P.cx + w1:.1f},164 '
            f'L{P.cx + w2:.1f},175 Q{P.cx:.1f},185 {P.cx - w2:.1f},175 Z" fill="url(#cuero)"/>')


def en_cinturon(P, phi, y=171):
    s, z = sc(P.theta, phi)
    return P.cx + (P.ancho(y) + 1.5) * s, y + 5 * z, z


def manga(P, hombro, mano, semilla, pj):
    """Manga acampanada del hombro a la mano, con el puño deshilachado/adornado."""
    (sx, sy), (hx, hy) = hombro, mano
    L = math.hypot(hx - sx, hy - sy) or 1
    ux, uy = (hx - sx) / L, (hy - sy) / L
    nx, ny = -uy, ux
    ex, ey = hx - ux * 6, hy - uy * 6
    a1, a2 = (sx + nx * 9, sy + ny * 9), (sx - nx * 9, sy - ny * 9)
    b1, b2 = (ex + nx * 14, ey + ny * 14), (ex - nx * 14, ey - ny * 14)
    m1 = ((a1[0] + b1[0]) / 2 + nx * 4, (a1[1] + b1[1]) / 2 + ny * 4)
    m2 = ((a2[0] + b2[0]) / 2 - nx * 4, (a2[1] + b2[1]) / 2 - ny * 4)
    borde = zigzag(b1, b2, 4, pj.prof_manga, P.f, semilla, (ux, uy))
    d = f"M{fp(a1)} Q{fp(m1)} {fp(b1)} L{borde} L{fp(b2)} Q{fp(m2)} {fp(a2)} Z"
    return f'<path class="c" d="{d}" fill="url(#manga)"/>' + pj.adorno_manga(borde)


def capucha_d(P):
    T = P.T
    return (f"M{T(128, 40)} Q{T(152, 48)} {T(164, 78)} Q{T(174, 106)} {T(170, 136)} Q{T(150, 144)} {T(128, 144)} "
            f"Q{T(106, 144)} {T(86, 136)} Q{T(82, 106)} {T(92, 78)} Q{T(104, 48)} {T(128, 40)} Z")


def capucha(P, pj):
    T, g = P.T, P.sgn
    d = capucha_d(P)
    out = f'<path class="c" d="{d}" fill="url(#capucha)"/>'
    if pj.rizo:
        out += (f'<path d="M{T(128, 40)} Q{T(128 - 10 * g, 32)} {T(128 - 20 * g, 38)} Q{T(128 - 10 * g, 36)} {T(128 - 6 * g, 44)}" '
                f'fill="url(#capucha)" stroke="#040605" stroke-width="2"/>')
    out += (f'<path d="M{T(96, 86)} Q{T(90, 110)} {T(92, 132)}" fill="none" stroke="{pj.brillo_borde}" '
            f'stroke-width="2" opacity=".6" stroke-linecap="round"/>'
            f'<path d="M{T(160, 84)} Q{T(166, 110)} {T(164, 132)}" fill="none" stroke="#000" stroke-width="2" opacity=".7"/>')
    if P.cos > -0.2:
        # Hueco de la capucha: se desplaza y se estrecha al girar la cabeza
        vx = P.hx + 22 * P.sin
        vw = 29 * (0.38 + 0.62 * max(P.cos, 0))
        dv = (f"M{vx:.1f},74 Q{vx + 0.86 * vw:.1f},76 {vx + vw:.1f},106 Q{vx + 0.93 * vw:.1f},132 {vx:.1f},140 "
              f"Q{vx - 0.93 * vw:.1f},132 {vx - vw:.1f},106 Q{vx - 0.86 * vw:.1f},76 {vx:.1f},74 Z")
        out += (f'<clipPath id="clipCapucha"><path d="{d}"/></clipPath><g clip-path="url(#clipCapucha)">'
                f'<path class="c" d="{dv}" fill="url(#vacio)"/>'
                f'<path d="M{vx:.1f},74 Q{vx + 0.86 * vw:.1f},76 {vx + vw:.1f},106" fill="none" '
                f'stroke="{pj.brillo_borde}" stroke-width="2" opacity=".7"/>'
                + pj.cara(P, vx, vw) + '</g>')
    else:
        # De espaldas: costuras de la capucha
        for phi, w in ((180, 2.2), (130, 1.6), (230, 1.6)):
            s, z = sc(P.theta, phi)
            if z < 0.15:
                continue
            xa, xm, xb = P.hx + P.punta * 0.5 + 14 * s, P.hx + 28 * s, P.hx + 32 * s
            out += (f'<path d="M{xa:.1f},58 Q{xm:.1f},100 {xb:.1f},142" fill="none" stroke="#000" '
                    f'stroke-width="{w}" opacity="{0.4 + 0.5 * z:.2f}"/>')
    return out


def esclavina(P, semilla=6, prof=9, n=10):
    h = P.hx
    borde = jirones(h + 48, h - 48, 152, n, prof, P.f, semilla)
    d = f"M{h - 42:.1f},130 Q{h:.1f},114 {h + 42:.1f},130 L{h + 48:.1f},152 L{borde} Z"
    return f'<path class="c" d="{d}" fill="url(#manto)"/>', borde


def ojos(P, glow, nucleo, ancho=5.5, alto=2.0, ranura=None):
    out = ""
    for phi, rot in ((-27, 18), (27, -18)):
        s, z = sc(P.theta, phi)
        if z < 0.2:
            continue
        x, k = P.hx + 24 * s, z ** 0.6
        if ranura:
            out += (f'<ellipse cx="{x:.1f}" cy="108" rx="{(ancho + 2) * k:.1f}" ry="{alto + 1.6:.1f}" '
                    f'fill="{ranura}" transform="rotate({rot} {x:.1f} 108)"/>')
        out += (f'<circle cx="{x:.1f}" cy="108" r="{12 * k:.1f}" fill="{glow}" opacity="{PULSO[P.f]}"/>'
                f'<ellipse cx="{x:.1f}" cy="108" rx="{ancho * k:.1f}" ry="{alto}" fill="{nucleo}" '
                f'transform="rotate({rot} {x:.1f} 108)"/>')
    return out


def gota(x, y, r, op, relleno="url(#veneno)", borde="#0a2a0c"):
    return (f'<path d="M{x:.1f},{y - r * 1.8:.1f} Q{x + r:.1f},{y - r * 0.2:.1f} {x:.1f},{y + r:.1f} '
            f'Q{x - r:.1f},{y - r * 0.2:.1f} {x:.1f},{y - r * 1.8:.1f} Z" fill="{relleno}" opacity="{op:.2f}" '
            f'stroke="{borde}" stroke-width="1"/>')


def puno(cx, cy, linea, unas):
    """Mano huesuda agarrando el bastón."""
    return f"""
  <ellipse class="c" cx="{cx:.1f}" cy="{cy:.1f}" rx="9" ry="8" fill="url(#piel)" stroke-width="2"/>
  <path d="M{cx - 8:.1f},{cy - 3:.1f} L{cx + 8:.1f},{cy - 3:.1f} M{cx - 8:.1f},{cy + 1:.1f} L{cx + 8:.1f},{cy + 1:.1f} M{cx - 7:.1f},{cy + 5:.1f} L{cx + 7:.1f},{cy + 5:.1f}" stroke="{linea}" stroke-width="1.3"/>
  <path d="M{cx + 8:.1f},{cy - 4:.1f} l5,1 l-4,2 M{cx + 8:.1f},{cy:.1f} l5,1 l-4,2" fill="{unas}" stroke="{unas}" stroke-width="1.2" stroke-linejoin="round"/>"""


def garra(cx, cy, dedo, unas):
    """Mano abierta con garras, palma hacia arriba."""
    out = ""
    for k in (-1.5, -0.5, 0.5, 1.5):
        x0, x2 = cx + k * 4, cx + k * 6.5
        c = f"M{x0:.1f},{cy - 3:.1f} Q{cx + k * 6:.1f},{cy - 11:.1f} {x2:.1f},{cy - 16:.1f}"
        out += (f'<path d="{c}" fill="none" stroke="#040605" stroke-width="5" stroke-linecap="round"/>'
                f'<path d="{c}" fill="none" stroke="{dedo}" stroke-width="2.6" stroke-linecap="round"/>'
                f'<path d="M{x2 - 1.5:.1f},{cy - 15:.1f} L{x2 + k * 0.8:.1f},{cy - 21:.1f} L{x2 + 1.5:.1f},{cy - 15:.1f} Z" fill="{unas}"/>')
    return out + f'<ellipse class="c" cx="{cx:.1f}" cy="{cy:.1f}" rx="9" ry="7" fill="url(#piel)" stroke-width="2"/>'


DEFS_COMUN = """
  <style>.c{stroke:#040605;stroke-width:2.5;stroke-linejoin:round;stroke-linecap:round}</style>
  <radialGradient id="sombra"><stop offset="0" stop-color="#000" stop-opacity=".55"/><stop offset="1" stop-color="#000" stop-opacity="0"/></radialGradient>
  <filter id="resplandor" x="-60%" y="-60%" width="220%" height="220%"><feGaussianBlur stdDeviation="2.2" result="b"/><feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter>
"""


# ================================================== EL ENVENENADOR ===
def craneo_baston(x, y_mano, f):
    """Bastón retorcido coronado por un cráneo con cuernos que gotea veneno."""
    caida = [0, 9, 18, 27][f]
    return f"""<g transform="translate(0 {y_mano - 196:.1f})">
  <circle cx="{x:.1f}" cy="40" r="34" fill="url(#aura)" opacity="{PULSO[f] * 0.8:.2f}"/>
  <path class="c" d="M{x:.1f},242 Q{x + 5:.1f},200 {x - 3:.1f},160 Q{x + 6:.1f},120 {x - 2:.1f},86 Q{x + 4:.1f},70 {x:.1f},56" fill="none" stroke-width="10"/>
  <path d="M{x:.1f},242 Q{x + 5:.1f},200 {x - 3:.1f},160 Q{x + 6:.1f},120 {x - 2:.1f},86 Q{x + 4:.1f},70 {x:.1f},56" fill="none" stroke="url(#madera)" stroke-width="7" stroke-linecap="round"/>
  <path d="M{x - 2:.1f},150 q-7,-4 -9,-12 M{x + 3:.1f},110 q8,-3 10,-10" fill="none" stroke="#040605" stroke-width="4" stroke-linecap="round"/>
  <path d="M{x - 2:.1f},150 q-7,-4 -9,-12 M{x + 3:.1f},110 q8,-3 10,-10" fill="none" stroke="#3a2a1e" stroke-width="2" stroke-linecap="round"/>
  <path class="c" d="M{x - 9:.1f},34 Q{x - 26:.1f},30 {x - 24:.1f},10 Q{x - 20:.1f},24 {x - 6:.1f},26 Z" fill="url(#cuerno)" stroke-width="2"/>
  <path class="c" d="M{x + 9:.1f},34 Q{x + 26:.1f},30 {x + 24:.1f},10 Q{x + 20:.1f},24 {x + 6:.1f},26 Z" fill="url(#cuerno)" stroke-width="2"/>
  <path class="c" d="M{x - 12:.1f},38 Q{x - 13:.1f},22 {x:.1f},22 Q{x + 13:.1f},22 {x + 12:.1f},38 Q{x + 11:.1f},46 {x + 7:.1f},48 L{x + 6:.1f},56 L{x - 6:.1f},56 L{x - 7:.1f},48 Q{x - 11:.1f},46 {x - 12:.1f},38 Z" fill="url(#hueso)" stroke-width="2"/>
  <path d="M{x - 4:.1f},50 L{x - 4:.1f},56 M{x:.1f},50 L{x:.1f},56 M{x + 4:.1f},50 L{x + 4:.1f},56" stroke="#3a3428" stroke-width="1.2"/>
  <ellipse cx="{x - 5:.1f}" cy="38" rx="4" ry="4.5" fill="#0a0a08"/><ellipse cx="{x + 5:.1f}" cy="38" rx="4" ry="4.5" fill="#0a0a08"/>
  <g filter="url(#resplandor)"><circle cx="{x - 5:.1f}" cy="38" r="2" fill="#c8ff4a" opacity="{PULSO[f]}"/><circle cx="{x + 5:.1f}" cy="38" r="2" fill="#c8ff4a" opacity="{PULSO[f]}"/></g>
  <path d="M{x:.1f},42 L{x - 2:.1f},46 L{x + 2:.1f},46 Z" fill="#2a261c"/>
  <path d="M{x - 6:.1f},56 Q{x:.1f},60 {x + 6:.1f},56" fill="none" stroke="#7dff3a" stroke-width="2.5" opacity=".85"/>
  {gota(x + 1, 62 + caida, 2.6, 1 - f * 0.22)}</g>"""


def vial(x, y, morado=False):
    rel = "url(#venenoMorado)" if morado else "url(#veneno)"
    return f"""
  <path d="M{x:.1f},{y - 8:.1f} L{x:.1f},{y - 3:.1f}" stroke="#2a1e14" stroke-width="1.5"/>
  <path class="c" d="M{x - 2.5:.1f},{y - 3:.1f} L{x + 2.5:.1f},{y - 3:.1f} L{x + 2.5:.1f},{y:.1f} Q{x + 7:.1f},{y + 3:.1f} {x + 6:.1f},{y + 8:.1f} Q{x:.1f},{y + 13:.1f} {x - 6:.1f},{y + 8:.1f} Q{x - 7:.1f},{y + 3:.1f} {x - 2.5:.1f},{y:.1f} Z" fill="#1a2a20" stroke-width="1.6"/>
  <path d="M{x - 5.5:.1f},{y + 5:.1f} Q{x:.1f},{y + 3:.1f} {x + 5.5:.1f},{y + 5:.1f} Q{x + 5:.1f},{y + 10:.1f} {x:.1f},{y + 11:.1f} Q{x - 5:.1f},{y + 10:.1f} {x - 5.5:.1f},{y + 5:.1f} Z" fill="{rel}"/>
  <rect x="{x - 3:.1f}" y="{y - 6:.1f}" width="6" height="3" rx="1" fill="#4a3424"/>
  <circle cx="{x - 2:.1f}" cy="{y + 4:.1f}" r="1" fill="#fff" opacity=".6"/>"""


def calavera_hebilla(x, y):
    return f"""
  <path class="c" d="M{x - 6:.1f},{y:.1f} Q{x - 6:.1f},{y - 7:.1f} {x:.1f},{y - 7:.1f} Q{x + 6:.1f},{y - 7:.1f} {x + 6:.1f},{y:.1f} Q{x + 5:.1f},{y + 3:.1f} {x + 3:.1f},{y + 4:.1f} L{x + 3:.1f},{y + 6:.1f} L{x - 3:.1f},{y + 6:.1f} L{x - 3:.1f},{y + 4:.1f} Q{x - 5:.1f},{y + 3:.1f} {x - 6:.1f},{y:.1f} Z" fill="url(#hueso)" stroke-width="1.5"/>
  <circle cx="{x - 2.3:.1f}" cy="{y - 1:.1f}" r="1.7" fill="#0a0a08"/><circle cx="{x + 2.3:.1f}" cy="{y - 1:.1f}" r="1.7" fill="#0a0a08"/>"""


class Envenenador:
    nombre = "envenenador"
    prof_bajo, prof_manga = 9, 8
    color_pliegue = "#000"
    brillo_borde = "#4d6a55"
    rizo = True
    defs = """
  <radialGradient id="niebla"><stop offset="0" stop-color="#8cff3a" stop-opacity=".42"/><stop offset=".6" stop-color="#3fd94a" stop-opacity=".16"/><stop offset="1" stop-color="#3fd94a" stop-opacity="0"/></radialGradient>
  <linearGradient id="tunica" x1="0" x2="1"><stop offset="0" stop-color="#2b3d2e"/><stop offset=".45" stop-color="#141f17"/><stop offset="1" stop-color="#060a07"/></linearGradient>
  <linearGradient id="manga" x1="0" x2="1"><stop offset="0" stop-color="#2f4432"/><stop offset=".5" stop-color="#141f17"/><stop offset="1" stop-color="#060a07"/></linearGradient>
  <linearGradient id="tunicaV" x1="0" x2="0" y1="0" y2="1"><stop offset=".2" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#000" stop-opacity=".5"/></linearGradient>
  <linearGradient id="resplandorBajo" x1="0" x2="0" y1="0" y2="1"><stop offset=".6" stop-color="#7dff3a" stop-opacity="0"/><stop offset="1" stop-color="#7dff3a" stop-opacity=".22"/></linearGradient>
  <linearGradient id="capa" x1="0" x2="1"><stop offset="0" stop-color="#111a13"/><stop offset="1" stop-color="#030504"/></linearGradient>
  <linearGradient id="forro" x1="0" x2="0" y1="0" y2="1"><stop offset="0" stop-color="#4a2466"/><stop offset="1" stop-color="#1a0b26"/></linearGradient>
  <linearGradient id="capucha" x1="0" x2="1"><stop offset="0" stop-color="#34493a"/><stop offset=".5" stop-color="#172419"/><stop offset="1" stop-color="#070b08"/></linearGradient>
  <linearGradient id="manto" x1="0" x2="1"><stop offset="0" stop-color="#2e4233"/><stop offset=".5" stop-color="#152117"/><stop offset="1" stop-color="#070b08"/></linearGradient>
  <radialGradient id="vacio" cx=".5" cy=".55" r=".6"><stop offset="0" stop-color="#000"/><stop offset=".75" stop-color="#030604"/><stop offset="1" stop-color="#14251a"/></radialGradient>
  <radialGradient id="ojo"><stop offset="0" stop-color="#d8ff5a" stop-opacity=".95"/><stop offset=".45" stop-color="#5dff3a" stop-opacity=".4"/><stop offset="1" stop-color="#5dff3a" stop-opacity="0"/></radialGradient>
  <linearGradient id="piel" x1="0" x2="1"><stop offset="0" stop-color="#b9c7a8"/><stop offset="1" stop-color="#5f6e58"/></linearGradient>
  <linearGradient id="madera" x1="0" x2="1"><stop offset="0" stop-color="#4a3626"/><stop offset="1" stop-color="#110b07"/></linearGradient>
  <radialGradient id="hueso" cx=".4" cy=".35" r=".7"><stop offset="0" stop-color="#ece5cf"/><stop offset="1" stop-color="#8f8670"/></radialGradient>
  <linearGradient id="cuerno" x1="0" x2="0" y1="0" y2="1"><stop offset="0" stop-color="#1a1410"/><stop offset="1" stop-color="#5a4a3a"/></linearGradient>
  <radialGradient id="veneno" cx=".35" cy=".35" r=".75"><stop offset="0" stop-color="#f2ffb0"/><stop offset=".35" stop-color="#9dff3a"/><stop offset=".8" stop-color="#2fb83a"/><stop offset="1" stop-color="#145c1c"/></radialGradient>
  <radialGradient id="aura"><stop offset="0" stop-color="#9dff3a" stop-opacity=".75"/><stop offset=".45" stop-color="#5dff3a" stop-opacity=".25"/><stop offset="1" stop-color="#5dff3a" stop-opacity="0"/></radialGradient>
  <radialGradient id="venenoMorado" cx=".35" cy=".35" r=".75"><stop offset="0" stop-color="#f0c8ff"/><stop offset=".4" stop-color="#b14cff"/><stop offset="1" stop-color="#4a1470"/></radialGradient>
  <linearGradient id="cuero" x1="0" x2="0" y1="0" y2="1"><stop offset="0" stop-color="#3a2a1e"/><stop offset="1" stop-color="#160e08"/></linearGradient>
  <linearGradient id="bota" x1="0" x2="0" y1="0" y2="1"><stop offset="0" stop-color="#1c241e"/><stop offset="1" stop-color="#060806"/></linearGradient>
"""

    def baston(self, x, y, f):
        return craneo_baston(x, y, f)

    def puno(self, x, y):
        return puno(x, y, "#3b4636", "#0d0d0b")

    def mano_hechizo(self, cx, cy, f):
        oy = cy - 30 + [0, -2, 0, 2][f]
        return garra(cx, cy, "#9aa98d", "#0d0d0b") + f"""
  <circle cx="{cx:.1f}" cy="{oy:.1f}" r="22" fill="url(#aura)" opacity="{PULSO[f]}"/>
  <circle cx="{cx:.1f}" cy="{oy:.1f}" r="9" fill="url(#veneno)" stroke="#0a2a0c" stroke-width="1.5" filter="url(#resplandor)"/>
  <circle cx="{cx - 3:.1f}" cy="{oy - 3:.1f}" r="2.2" fill="#fff" opacity=".7"/>
  <circle cx="{cx + 5:.1f}" cy="{oy - 12 - f * 3:.1f}" r="2" fill="none" stroke="#9dff3a" stroke-width="1" opacity="{1 - f * 0.2:.2f}"/>
  <circle cx="{cx - 6:.1f}" cy="{oy - 8 - ((f + 2) % 4) * 3:.1f}" r="1.5" fill="none" stroke="#9dff3a" stroke-width="1" opacity=".8"/>
  {gota(cx + 2, oy + 12 + f * 4, 2, 0.9 - f * 0.2)}"""

    def tunica_extra(self, P, d):
        if P.cos < 0.25:
            return ""
        # Abertura delantera con forro morado (en phi = 0)
        xt, xb = P.cx + P.ancho(176) * P.sin * 0.95, P.cx + P.wb * P.sin * 0.95
        wt, wb = 7 * P.cos, 12 * P.cos
        dd = f"M{xt - wt:.1f},176 L{xb - wb:.1f},229 L{jirones(xb - wb, xb + wb, 230, 4, 6, P.f, 3)} L{xt + wt:.1f},176 Z"
        return f'<path d="{dd}" fill="url(#forro)" stroke="#040605" stroke-width="2"/>'

    def cintura(self, P):
        piezas = []
        for phi, morado in ((-38, False), (32, True), (52, False)):
            x, y, z = en_cinturon(P, phi)
            if z > 0.15:
                piezas.append((z, vial(x, y + 10, morado)))
        x, y, z = en_cinturon(P, 0)
        if z > 0.25:
            piezas.append((z, calavera_hebilla(x, y + 2)))
        return cinturon(P) + "".join(s for _, s in sorted(piezas))

    def adorno_manga(self, borde):
        return ""

    def borde_capa(self, borde):
        return ""

    def esclavina(self, P):
        return esclavina(P)[0]

    def detras_capucha(self, P):
        return ""

    def cara(self, P, vx, vw):
        out = ""
        if P.cos > 0.5:
            w = 12 * P.cos
            out += f'<path d="M{vx - w:.1f},124 Q{vx:.1f},131 {vx + w:.1f},124" fill="none" stroke="#1d2b21" stroke-width="1.5"/>'
        return out + ojos(P, "url(#ojo)", "#efffa0")

    def delante_capucha(self, P):
        # Volutas tóxicas que salen de la capucha
        x, y, f = P.hx + P.punta * 0.6, 72, P.f
        s = f * 5
        return (f'<path d="M{x - 6:.1f},{y - s} q-8,-10 0,-18 q8,-8 0,-16" fill="none" stroke="#7dff3a" '
                f'stroke-width="2.5" opacity="{0.35 - f * 0.06:.2f}" stroke-linecap="round"/>'
                f'<path d="M{x + 8:.1f},{y - 6 - ((f + 2) % 4) * 5} q8,-9 0,-16 q-7,-8 1,-14" fill="none" '
                f'stroke="#7dff3a" stroke-width="2" opacity=".25" stroke-linecap="round"/>')

    def efectos(self, P):
        return ""


# ===================================================== EL PIROMANTE ===
FUEGO = [("#b8180c", 1.0), ("#ff5a14", 0.8), ("#ffaa22", 0.58), ("#fff1b8", 0.32)]


def llama(x, y, h, w, f, semilla, borde=True, paleta=None, color_borde="#3a0602"):
    """Llama en 4 capas (rojo -> blanco). La punta oscila y la altura vibra por frame."""
    out = ""
    vib = 1 + 0.13 * math.sin(f * math.pi / 2 + semilla)
    for i, (col, k) in enumerate(paleta or FUEGO):
        hh, ww = h * k * vib, w * k
        wig = 4.5 * k * math.sin(f * math.pi / 2 + semilla * 1.7 + i)
        yb = y - (1 - k) * w * 0.7
        trazo = f' stroke="{color_borde}" stroke-width="1.6"' if (i == 0 and borde) else ""
        out += (f'<path d="M{x - ww:.1f},{yb:.1f} C{x - ww:.1f},{yb - hh * 0.45:.1f} {x - ww * 0.3 + wig:.1f},{yb - hh * 0.7:.1f} '
                f'{x + wig:.1f},{yb - hh:.1f} C{x + ww * 0.3 + wig:.1f},{yb - hh * 0.7:.1f} {x + ww:.1f},{yb - hh * 0.45:.1f} '
                f'{x + ww:.1f},{yb:.1f} Q{x + ww:.1f},{yb + ww * 0.9:.1f} {x:.1f},{yb + ww * 0.9:.1f} '
                f'Q{x - ww:.1f},{yb + ww * 0.9:.1f} {x - ww:.1f},{yb:.1f} Z" fill="{col}"{trazo}/>')
    return out


def baston_fuego(x, y_mano, f):
    """Bastón de hierro con anillos de oro y unas garras que sujetan una llama viva."""
    garra_d = lambda s: f"M{x + 3 * s:.1f},74 Q{x + 22 * s:.1f},64 {x + 17 * s:.1f},36 Q{x + 14 * s:.1f},52 {x + 2 * s:.1f},62 Z"
    anillos = "".join(f'<rect class="c" x="{x - 6:.1f}" y="{yy}" width="12" height="5" rx="2" fill="url(#oro)" stroke-width="1.5"/>'
                      for yy in (78, 128, 168))
    return f"""<g transform="translate(0 {y_mano - 196:.1f})">
  <circle cx="{x:.1f}" cy="42" r="44" fill="url(#aura)" opacity="{PULSO[f] * 0.9:.2f}"/>
  <path class="c" d="M{x:.1f},246 L{x - 4:.1f},236 L{x:.1f},72" fill="none" stroke-width="10"/>
  <path d="M{x:.1f},244 L{x - 3:.1f},236 L{x:.1f},72" fill="none" stroke="url(#hierro)" stroke-width="7"/>
  <path d="M{x - 1.5:.1f},230 L{x - 1.5:.1f},80" stroke="#8a8284" stroke-width="1.2" opacity=".6"/>
  {anillos}
  <path class="c" d="{garra_d(-1)}" fill="url(#hierro)" stroke-width="2"/>
  <g filter="url(#resplandor)">{llama(x - 9, 64, 22, 6, f, 2.5)}{llama(x + 9, 64, 22, 6, f, 4.0)}{llama(x, 60, 44, 12, f, 1.0)}</g>
  <path class="c" d="{garra_d(1)}" fill="url(#hierro)" stroke-width="2"/>
  <circle cx="{x + 4 - f * 2:.1f}" cy="{14 - f * 6:.1f}" r="1.8" fill="#ffd36b" opacity="{1 - f * 0.22:.2f}"/>
  <circle cx="{x - 7 + f:.1f}" cy="{22 - ((f + 2) % 4) * 6:.1f}" r="1.4" fill="#ff8a1a" opacity=".85"/></g>"""


def grimorio(x, y):
    return (f'<rect class="c" x="{x - 7:.1f}" y="{y - 2:.1f}" width="14" height="17" rx="2" fill="#4a0e0a" stroke-width="1.8"/>'
            f'<rect x="{x - 5:.1f}" y="{y:.1f}" width="10" height="13" rx="1" fill="none" stroke="url(#oro)" stroke-width="1.2"/>'
            f'<circle cx="{x:.1f}" cy="{y + 6.5:.1f}" r="2.2" fill="#ff8a1a" filter="url(#resplandor)"/>')


def bolsa(x, y):
    return (f'<path d="M{x:.1f},{y - 4:.1f} L{x:.1f},{y:.1f}" stroke="#2a1a10" stroke-width="1.5"/>'
            f'<path class="c" d="M{x - 6:.1f},{y + 1:.1f} Q{x:.1f},{y - 2:.1f} {x + 6:.1f},{y + 1:.1f} Q{x + 8:.1f},{y + 12:.1f} {x:.1f},{y + 13:.1f} Q{x - 8:.1f},{y + 12:.1f} {x - 6:.1f},{y + 1:.1f} Z" fill="url(#cuero)" stroke-width="1.8"/>'
            f'<path d="M{x - 5:.1f},{y + 2:.1f} Q{x:.1f},{y + 5:.1f} {x + 5:.1f},{y + 2:.1f}" fill="none" stroke="url(#oro)" stroke-width="1.2"/>')


class Piromante:
    nombre = "piromante"
    prof_bajo, prof_manga = 6, 5
    color_pliegue = "#1a0302"
    brillo_borde = "#c4462a"
    rizo = False
    defs = """
  <radialGradient id="niebla"><stop offset="0" stop-color="#ff7a1a" stop-opacity=".45"/><stop offset=".6" stop-color="#ff3a0a" stop-opacity=".16"/><stop offset="1" stop-color="#ff3a0a" stop-opacity="0"/></radialGradient>
  <linearGradient id="tunica" x1="0" x2="1"><stop offset="0" stop-color="#9a2216"/><stop offset=".45" stop-color="#5a0e08"/><stop offset="1" stop-color="#1c0302"/></linearGradient>
  <linearGradient id="manga" x1="0" x2="1"><stop offset="0" stop-color="#a8281a"/><stop offset=".5" stop-color="#5a0e08"/><stop offset="1" stop-color="#1c0302"/></linearGradient>
  <linearGradient id="tunicaV" x1="0" x2="0" y1="0" y2="1"><stop offset=".15" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#000" stop-opacity=".45"/></linearGradient>
  <linearGradient id="resplandorBajo" x1="0" x2="0" y1="0" y2="1"><stop offset=".55" stop-color="#ff5a14" stop-opacity="0"/><stop offset="1" stop-color="#ff5a14" stop-opacity=".35"/></linearGradient>
  <linearGradient id="capa" x1="0" x2="1"><stop offset="0" stop-color="#3a0806"/><stop offset="1" stop-color="#0e0101"/></linearGradient>
  <linearGradient id="capucha" x1="0" x2="1"><stop offset="0" stop-color="#b02a1c"/><stop offset=".5" stop-color="#5c0e08"/><stop offset="1" stop-color="#1e0302"/></linearGradient>
  <linearGradient id="manto" x1="0" x2="1"><stop offset="0" stop-color="#6a120c"/><stop offset=".5" stop-color="#360604"/><stop offset="1" stop-color="#120101"/></linearGradient>
  <radialGradient id="vacio" cx=".5" cy=".55" r=".6"><stop offset="0" stop-color="#000"/><stop offset=".75" stop-color="#060101"/><stop offset="1" stop-color="#3a0a06"/></radialGradient>
  <radialGradient id="ojo"><stop offset="0" stop-color="#fff2a0" stop-opacity=".95"/><stop offset=".45" stop-color="#ff7a1a" stop-opacity=".45"/><stop offset="1" stop-color="#ff5a14" stop-opacity="0"/></radialGradient>
  <linearGradient id="mascara" x1="0" x2="1"><stop offset="0" stop-color="#8a5a3a"/><stop offset=".5" stop-color="#4a2a1a"/><stop offset="1" stop-color="#1e0f08"/></linearGradient>
  <linearGradient id="piel" x1="0" x2="1"><stop offset="0" stop-color="#6e6668"/><stop offset="1" stop-color="#262022"/></linearGradient>
  <linearGradient id="hierro" x1="0" x2="1"><stop offset="0" stop-color="#77706f"/><stop offset=".5" stop-color="#36302f"/><stop offset="1" stop-color="#110d0d"/></linearGradient>
  <radialGradient id="hombrera" cx=".35" cy=".3" r=".8"><stop offset="0" stop-color="#7a7270"/><stop offset=".55" stop-color="#2e2828"/><stop offset="1" stop-color="#0c0909"/></radialGradient>
  <linearGradient id="cuerno" x1="0" x2="0" y1="1" y2="0"><stop offset="0" stop-color="#140c0a"/><stop offset=".7" stop-color="#3a2420"/><stop offset="1" stop-color="#9a5a3a"/></linearGradient>
  <radialGradient id="aura"><stop offset="0" stop-color="#ffb02a" stop-opacity=".8"/><stop offset=".45" stop-color="#ff5a14" stop-opacity=".28"/><stop offset="1" stop-color="#ff3a0a" stop-opacity="0"/></radialGradient>
  <radialGradient id="nucleo"><stop offset="0" stop-color="#ffffff"/><stop offset=".5" stop-color="#fff1a0"/><stop offset="1" stop-color="#ffaa22"/></radialGradient>
  <linearGradient id="oro" x1="0" x2="0" y1="0" y2="1"><stop offset="0" stop-color="#ffe08a"/><stop offset="1" stop-color="#b07a24"/></linearGradient>
  <linearGradient id="cuero" x1="0" x2="0" y1="0" y2="1"><stop offset="0" stop-color="#3a2018"/><stop offset="1" stop-color="#160a06"/></linearGradient>
  <linearGradient id="bota" x1="0" x2="0" y1="0" y2="1"><stop offset="0" stop-color="#3a3232"/><stop offset="1" stop-color="#0c0909"/></linearGradient>
  <linearGradient id="fuegoBajo" x1="0" x2="0" y1="0" y2="1"><stop offset="0" stop-color="#ff3a0a" stop-opacity="0"/><stop offset=".45" stop-color="#ff5a14" stop-opacity=".8"/><stop offset="1" stop-color="#ffc43a"/></linearGradient>
  <linearGradient id="fuegoBajo2" x1="0" x2="0" y1="0" y2="1"><stop offset="0" stop-color="#ffaa22" stop-opacity="0"/><stop offset=".5" stop-color="#ffd25a" stop-opacity=".85"/><stop offset="1" stop-color="#fff4c0"/></linearGradient>
"""

    def baston(self, x, y, f):
        return baston_fuego(x, y, f)

    def puno(self, x, y):
        return puno(x, y, "#141010", "#0a0808")

    def mano_hechizo(self, cx, cy, f):
        oy = cy - 28 + [0, -2, 0, 2][f]
        chispas = "".join(f'<circle cx="{cx + dx:.1f}" cy="{oy - 20 - ((f + k) % 4) * 6:.1f}" r="{r}" fill="#ffc24a" '
                          f'opacity="{1 - ((f + k) % 4) * 0.25:.2f}"/>' for k, (dx, r) in enumerate([(-7, 1.6), (5, 1.3), (1, 1.8)]))
        return garra(cx, cy, "#4a4244", "#0a0808") + f"""
  <circle cx="{cx:.1f}" cy="{oy:.1f}" r="26" fill="url(#aura)" opacity="{PULSO[f]}"/>
  <g filter="url(#resplandor)">{llama(cx, oy + 6, 30, 10, f, 3.3)}
  <circle cx="{cx:.1f}" cy="{oy + 3:.1f}" r="5" fill="url(#nucleo)"/></g>{chispas}"""

    def tunica_extra(self, P, d):
        out = ""
        # Ribetes dorados de la pechera (phi = ±15) y emblema de llama en el centro
        for phi in (-15, 15):
            s, z = sc(P.theta, phi)
            if z < 0.2:
                continue
            xt, xb = P.cx + P.ancho(176) * s, P.cx + P.wb * s * 0.97
            out += (f'<path d="M{xt:.1f},176 Q{(xt + xb) / 2:.1f},200 {xb:.1f},224" fill="none" stroke="url(#oro)" '
                    f'stroke-width="2.4" opacity="{0.5 + 0.5 * z:.2f}"/>')
        if P.cos > 0.35:
            x, k = P.cx + P.ancho(194) * P.sin, P.cos
            out += (f'<path class="c" d="M{x - 5 * k:.1f},202 Q{x - 7 * k:.1f},193 {x - 1 * k:.1f},185 Q{x:.1f},192 {x + 2 * k:.1f},183 '
                    f'Q{x + 8 * k:.1f},193 {x + 5 * k:.1f},202 Q{x:.1f},206 {x - 5 * k:.1f},202 Z" fill="url(#oro)" stroke-width="1.5"/>')
        # Bajo de la túnica ardiendo: lenguas de fuego recortadas a la forma de la túnica
        x0, x1 = P.cx - P.wb - 6, P.cx + P.wb + 6
        capas = ""
        for grad, alt, n in (("url(#fuegoBajo)", 1.0, 9), ("url(#fuegoBajo2)", 0.55, 7)):
            pts = [f"{x0:.1f},245"]
            for i in range(2 * n + 1):
                x = x0 + (x1 - x0) * i / (2 * n)
                if i % 2:
                    h = (15 + 8 * math.sin(P.f * math.pi / 2 + i * 1.9) + ((i * 13) % 5) * 2) * alt
                    y = 228 - h
                else:
                    y = 228 - 3 * alt
                pts.append(f"{x:.1f},{y:.1f}")
            pts.append(f"{x1:.1f},245")
            capas += f'<path d="M{" L".join(pts)} Z" fill="{grad}"/>'
        out += f'<clipPath id="clipTunica"><path d="{d}"/></clipPath><g clip-path="url(#clipTunica)">{capas}</g>'
        return out

    def cintura(self, P):
        piezas = []
        for phi, fn in ((40, grimorio), (-42, bolsa)):
            x, y, z = en_cinturon(P, phi)
            if z > 0.15:
                piezas.append((z, fn(x, y + 6)))
        x, y, z = en_cinturon(P, 0)
        if z > 0.25:
            k = 0.5 + 0.5 * z
            piezas.append((z, f'<ellipse class="c" cx="{x:.1f}" cy="{y + 1:.1f}" rx="{8 * k:.1f}" ry="8" fill="url(#oro)" stroke-width="1.8"/>'
                              f'<ellipse cx="{x:.1f}" cy="{y + 1:.1f}" rx="{3.6 * k:.1f}" ry="3.6" fill="#ff5a14" stroke="#3a0602" stroke-width="1" filter="url(#resplandor)"/>'))
        return cinturon(P) + "".join(s for _, s in sorted(piezas))

    def adorno_manga(self, borde):
        return f'<path d="M{borde}" fill="none" stroke="url(#oro)" stroke-width="2.6" stroke-linejoin="round"/>'

    def borde_capa(self, borde):
        return (f'<path d="M{borde}" fill="none" stroke="#ff6a1a" stroke-width="2.2" opacity=".85" '
                f'stroke-linejoin="round" filter="url(#resplandor)"/>')

    def esclavina(self, P):
        forma, borde = esclavina(P, semilla=3, prof=8, n=8)
        return forma + f'<path d="M{borde}" fill="none" stroke="url(#oro)" stroke-width="2.4" stroke-linejoin="round"/>'

    # ----- cuernos y hombreras: se ordenan delante/detrás según su z
    def _cuerno(self, P, phi):
        s, z = sc(P.theta, phi)
        bx, by = P.hx + 24 * s + P.punta * 0.5, 74 + z * 24 * PROF_Y
        C = (bx + 26 * s - 6 * P.sin, by - 8)
        Tp = (bx + 22 * s - 20 * P.sin, by - 42)
        d, izq, der = poligono_curvo((bx, by), C, Tp, 7.5)
        anillos = "".join(f'<path d="M{fp(izq[i])} L{fp(der[i])}" stroke="#040605" stroke-width="1.3"/>' for i in (2, 4, 6))
        return z, f'<path class="c" d="{d}" fill="url(#cuerno)" stroke-width="2"/>' + anillos

    def _hombrera(self, P, phi):
        x, y, z = P.punto(phi, 40, 138)
        s, _ = sc(P.theta, phi)
        out = ""
        for dx, alto in ((-5, 24), (5, 20)):
            b = (x + dx, y - 6)
            d, _, _ = poligono_curvo(b, (b[0] + 5 * s, b[1] - alto * 0.6), (b[0] + 11 * s, b[1] - alto), 4.2, N=6)
            out += f'<path class="c" d="{d}" fill="url(#cuerno)" stroke-width="1.8"/>'
        out += (f'<ellipse class="c" cx="{x:.1f}" cy="{y:.1f}" rx="16" ry="11" fill="url(#hombrera)"/>'
                f'<path d="M{x - 15:.1f},{y + 2:.1f} Q{x:.1f},{y + 14:.1f} {x + 15:.1f},{y + 2:.1f}" fill="none" stroke="url(#oro)" stroke-width="3"/>'
                f'<circle cx="{x:.1f}" cy="{y - 1:.1f}" r="3" fill="#ff5a14" stroke="#3a0602" stroke-width="1" filter="url(#resplandor)"/>')
        return z, out

    def detras_capucha(self, P):
        piezas = [self._cuerno(P, -55), self._cuerno(P, 55), self._hombrera(P, -90), self._hombrera(P, 90)]
        return "".join(s for z, s in sorted(piezas, key=lambda t: t[0]) if z < -0.2)

    def delante_capucha(self, P):
        piezas = [self._cuerno(P, -55), self._cuerno(P, 55), self._hombrera(P, -90), self._hombrera(P, 90)]
        return "".join(s for z, s in sorted(piezas, key=lambda t: t[0]) if z >= -0.2)

    def cara(self, P, vx, vw):
        """Máscara de bronce ennegrecido con ranuras incandescentes y lágrimas de lava."""
        rx = vw * 0.8
        d = (f"M{vx:.1f},81 Q{vx + rx:.1f},82 {vx + rx:.1f},103 Q{vx + rx * 0.85:.1f},124 {vx:.1f},136 "
             f"Q{vx - rx * 0.85:.1f},124 {vx - rx:.1f},103 Q{vx - rx:.1f},82 {vx:.1f},81 Z")
        out = (f'<path class="c" d="{d}" fill="url(#mascara)" stroke-width="2"/>'
               f'<path d="M{vx - rx * 0.8:.1f},88 Q{vx:.1f},82 {vx + rx * 0.5:.1f},86" fill="none" stroke="#c48a5a" stroke-width="1.5" opacity=".6"/>')
        if P.cos > 0.3:
            out += (f'<path d="M{vx:.1f},86 L{vx:.1f},128" stroke="#140804" stroke-width="2"/>'
                    f'<path d="M{vx - 1.2:.1f},88 L{vx - 1.2:.1f},124" stroke="#a87048" stroke-width="1" opacity=".6"/>')
            w = 7 * P.cos
            out += "".join(f'<path d="M{vx + dx * w:.1f},125 L{vx + dx * w:.1f},131" stroke="#ff6a1a" stroke-width="1.6" filter="url(#resplandor)"/>'
                           for dx in (-0.6, 0, 0.6))
        # grietas y lágrimas de lava bajo cada ojo
        for phi in (-27, 27):
            s, z = sc(P.theta, phi)
            if z < 0.2:
                continue
            x = P.hx + 24 * s
            out += (f'<path d="M{x:.1f},111 Q{x + 1.5:.1f},118 {x - 0.5:.1f},124 L{x + 1:.1f},128" fill="none" '
                    f'stroke="#ff7a1a" stroke-width="1.8" opacity=".9" filter="url(#resplandor)"/>')
        return out + ojos(P, "url(#ojo)", "#fff4b0", ancho=6, alto=2.2, ranura="#0a0302")

    def efectos(self, P):
        """Brasas que suben alrededor del mago."""
        out = ""
        for i in range(11):
            ciclo = (i * 29 + P.f * 15) % 120
            x = P.cx - 72 + (i * 47) % 144 + 4 * math.sin(i + P.f)
            y = 238 - ciclo * 1.7
            r = 1.2 + (i % 3) * 0.6
            out += f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{r:.1f}" fill="{"#ffd36b" if i % 2 else "#ff7a1a"}" opacity="{max(0, 1 - ciclo / 120):.2f}"/>'
        return out


# ================================================ UTILIDADES NUEVAS ===
def particulas_carril(xs, por_carril, f, N, fn):
    """Partículas que se mueven despacio y aun así cierran el bucle en N frames.
    Cada carril (una x fija) tiene `por_carril` partículas idénticas separadas en
    fase; en N frames cada una avanza justo hasta donde estaba la siguiente."""
    out = ""
    for c, x in enumerate(xs):
        for j in range(por_carril):
            out += fn(c, x, (j / por_carril + f / (N * por_carril) + c * 0.37) % 1)
    return out


def copo(x, y, r, rot=0, color="#f4fcff", borde="#0a2a44", ancho=1.6):
    """Copo de nieve de 6 brazos con ramitas (simétrico cada 60°)."""
    d = ""
    for i in range(6):
        a = math.radians(rot + i * 60)
        ca, sa = math.cos(a), math.sin(a)
        d += f"M{x:.1f},{y:.1f} L{x + ca * r:.1f},{y + sa * r:.1f} "
        for k, l in ((0.55, 0.34), (0.8, 0.22)):
            bx, by = x + ca * r * k, y + sa * r * k
            for s in (-1, 1):
                b = a + s * math.radians(45)
                d += f"M{bx:.1f},{by:.1f} L{bx + math.cos(b) * r * l:.1f},{by + math.sin(b) * r * l:.1f} "
    return (f'<path d="{d}" fill="none" stroke="{borde}" stroke-width="{ancho + 2:.1f}" stroke-linecap="round"/>'
            f'<path d="{d}" fill="none" stroke="{color}" stroke-width="{ancho:.1f}" stroke-linecap="round"/>')


def cristal(bx, by, tx, ty, w, relleno="url(#cristal)", borde="#0a2a44", ancho=1.8):
    """Cristal de hielo alargado de la base a la punta, con una cara iluminada."""
    dx, dy = tx - bx, ty - by
    L = math.hypot(dx, dy) or 1
    nx, ny = -dy / L, dx / L
    m = (bx + dx * .35, by + dy * .35)
    p1, p2 = (m[0] + nx * w, m[1] + ny * w), (m[0] - nx * w, m[1] - ny * w)
    base = (bx - dx / L * w * .6, by - dy / L * w * .6)
    return (f'<path d="M{fp(base)} L{fp(p1)} L{tx:.1f},{ty:.1f} L{fp(p2)} Z" fill="{relleno}" stroke="{borde}" '
            f'stroke-width="{ancho}" stroke-linejoin="round"/>'
            f'<path d="M{fp(base)} L{fp(p1)} L{tx:.1f},{ty:.1f} L{fp(m)} Z" fill="#ffffff" opacity=".35"/>'
            f'<path d="M{fp(m)} L{tx:.1f},{ty:.1f}" stroke="#ffffff" stroke-width="{ancho * .6:.1f}" opacity=".7"/>')


def prisma(x, cy, w, arriba, abajo, borde="#0a2a44"):
    """Cristal hexagonal flotante (dos puntas) con caras de luz y sombra."""
    pts = [(x, cy - arriba), (x + w, cy - arriba * .45), (x + w, cy + abajo * .45), (x, cy + abajo),
           (x - w, cy + abajo * .45), (x - w, cy - arriba * .45)]
    d = "M" + " L".join(fp(p) for p in pts) + " Z"
    luz = f"M{fp(pts[0])} L{fp(pts[5])} L{fp(pts[4])} L{fp(pts[3])} L{x - w * .15:.1f},{cy:.1f} Z"
    sombra = f"M{fp(pts[0])} L{fp(pts[1])} L{fp(pts[2])} L{fp(pts[3])} L{x + w * .2:.1f},{cy:.1f} Z"
    return (f'<path d="{d}" fill="url(#cristal)" stroke="{borde}" stroke-width="2.2" stroke-linejoin="round"/>'
            f'<path d="{luz}" fill="#ffffff" opacity=".4"/><path d="{sombra}" fill="#1a5a98" opacity=".3"/>'
            f'<path d="M{fp(pts[0])} L{x:.1f},{cy + abajo:.1f}" stroke="#ffffff" stroke-width="1.2" opacity=".8"/>')


# ==================================================== EL CRIOMANTE ===
def baston_hielo(x, y_mano, f):
    """Bastón de abedul plateado con un cristal flotante y 3 esquirlas en órbita."""
    cy = 36 + [0, -2, 0, 2][f]
    orbitas = []
    for i in range(3):              # 3 esquirlas a 120°: girando 30°/frame cierra el bucle en 4
        a = math.radians(f * 30 + i * 120)
        sx, sy, z = x + 21 * math.cos(a), cy + 4 + 7 * math.sin(a), math.sin(a)
        s = 3.4 + 1.2 * z
        orbitas.append((z, cristal(sx, sy + s, sx, sy - s * 1.7, s * .7, ancho=1.2)))
    atras = "".join(s for z, s in orbitas if z < 0)
    delante = "".join(s for z, s in orbitas if z >= 0)
    bandas = "".join(f'<path d="M{x - 5:.1f},{yy} L{x + 5:.1f},{yy - 3}" stroke="#ffffff" stroke-width="2.4" opacity=".85"/>'
                     for yy in (100, 142, 182))
    punta = lambda s: f"M{x + 2 * s:.1f},70 Q{x + 17 * s:.1f},64 {x + 14 * s:.1f},46 Q{x + 11 * s:.1f},60 {x + 1 * s:.1f},64 Z"
    return f"""<g transform="translate(0 {y_mano - 196:.1f})">
  <circle cx="{x:.1f}" cy="{cy}" r="40" fill="url(#aura)" opacity="{PULSO[f] * 0.85:.2f}"/>
  <path class="c" d="M{x:.1f},244 Q{x + 2:.1f},160 {x:.1f},66" fill="none" stroke-width="10"/>
  <path d="M{x:.1f},244 Q{x + 2:.1f},160 {x:.1f},66" fill="none" stroke="url(#madera)" stroke-width="7"/>
  {bandas}
  <path class="c" d="{punta(-1)}" fill="url(#plata)" stroke-width="2"/><path class="c" d="{punta(1)}" fill="url(#plata)" stroke-width="2"/>
  {atras}{prisma(x, cy, 9, 26, 20)}{delante}
  <path d="M{x + 12:.1f},{cy - 18} l2,5 l5,2 l-5,2 l-2,5 l-2,-5 l-5,-2 l5,-2 Z" fill="#ffffff" opacity="{PULSO[f]:.2f}"/></g>"""


class Criomante:
    nombre = "criomante"
    prof_bajo, prof_manga = 5, 5
    color_pliegue = "#061226"
    brillo_borde = "#ffffff"
    rizo = False
    defs = """
  <radialGradient id="niebla"><stop offset="0" stop-color="#dff8ff" stop-opacity=".45"/><stop offset=".6" stop-color="#8ad8ff" stop-opacity=".16"/><stop offset="1" stop-color="#8ad8ff" stop-opacity="0"/></radialGradient>
  <linearGradient id="tunica" x1="0" x2="1"><stop offset="0" stop-color="#4a7ec4"/><stop offset=".45" stop-color="#1c3c78"/><stop offset="1" stop-color="#081a3a"/></linearGradient>
  <linearGradient id="manga" x1="0" x2="1"><stop offset="0" stop-color="#5a8ed2"/><stop offset=".5" stop-color="#1c3c78"/><stop offset="1" stop-color="#081a3a"/></linearGradient>
  <linearGradient id="tunicaV" x1="0" x2="0" y1="0" y2="1"><stop offset=".2" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#000" stop-opacity=".35"/></linearGradient>
  <linearGradient id="resplandorBajo" x1="0" x2="0" y1="0" y2="1"><stop offset=".6" stop-color="#dff8ff" stop-opacity="0"/><stop offset="1" stop-color="#dff8ff" stop-opacity=".35"/></linearGradient>
  <linearGradient id="capa" x1="0" x2="1"><stop offset="0" stop-color="#16305a"/><stop offset="1" stop-color="#040a18"/></linearGradient>
  <linearGradient id="capucha" x1="0" x2="1"><stop offset="0" stop-color="#ffffff"/><stop offset=".45" stop-color="#a8cce8"/><stop offset="1" stop-color="#3c6a98"/></linearGradient>
  <linearGradient id="manto" x1="0" x2="1"><stop offset="0" stop-color="#ffffff"/><stop offset=".5" stop-color="#d0e2f0"/><stop offset="1" stop-color="#7c98b4"/></linearGradient>
  <radialGradient id="vacio" cx=".5" cy=".55" r=".6"><stop offset="0" stop-color="#02060c"/><stop offset=".75" stop-color="#06142a"/><stop offset="1" stop-color="#2a4c70"/></radialGradient>
  <radialGradient id="ojo"><stop offset="0" stop-color="#f0ffff" stop-opacity=".95"/><stop offset=".45" stop-color="#5ae0ff" stop-opacity=".45"/><stop offset="1" stop-color="#5ae0ff" stop-opacity="0"/></radialGradient>
  <linearGradient id="piel" x1="0" x2="1"><stop offset="0" stop-color="#dcefff"/><stop offset="1" stop-color="#7aa2c6"/></linearGradient>
  <linearGradient id="madera" x1="0" x2="1"><stop offset="0" stop-color="#eef4fa"/><stop offset="1" stop-color="#6a84a0"/></linearGradient>
  <linearGradient id="plata" x1="0" x2="1"><stop offset="0" stop-color="#ffffff"/><stop offset="1" stop-color="#8aa0b6"/></linearGradient>
  <linearGradient id="cristal" x1="0" x2="1" y1="0" y2="1"><stop offset="0" stop-color="#ffffff"/><stop offset=".45" stop-color="#aeeaff"/><stop offset="1" stop-color="#3a96d6"/></linearGradient>
  <linearGradient id="barbaHielo" x1="0" x2="0" y1="0" y2="1"><stop offset="0" stop-color="#ffffff"/><stop offset="1" stop-color="#9ad8f8"/></linearGradient>
  <radialGradient id="aura"><stop offset="0" stop-color="#e8fbff" stop-opacity=".8"/><stop offset=".45" stop-color="#6ad4ff" stop-opacity=".25"/><stop offset="1" stop-color="#6ad4ff" stop-opacity="0"/></radialGradient>
  <linearGradient id="cuero" x1="0" x2="0" y1="0" y2="1"><stop offset="0" stop-color="#26385a"/><stop offset="1" stop-color="#0c1424"/></linearGradient>
  <linearGradient id="bota" x1="0" x2="0" y1="0" y2="1"><stop offset="0" stop-color="#2c3e60"/><stop offset="1" stop-color="#0a1222"/></linearGradient>
"""

    def baston(self, x, y, f):
        return baston_hielo(x, y, f)

    def puno(self, x, y):
        return puno(x, y, "#5a7a98", "#e8f8ff")

    def mano_hechizo(self, cx, cy, f):
        oy = cy - 30 + [0, -2, 0, 2][f]
        return garra(cx, cy, "#c6dff2", "#e8f8ff") + (
            f'<circle cx="{cx:.1f}" cy="{oy:.1f}" r="24" fill="url(#aura)" opacity="{PULSO[f]}"/>'
            f'<g filter="url(#resplandor)">{copo(cx, oy, 10, rot=f * 15)}</g>'   # 15°x4 = 60°: bucle perfecto
            f'<circle cx="{cx:.1f}" cy="{oy:.1f}" r="3" fill="#ffffff"/>')

    def tunica_extra(self, P, d):
        out = ""
        for phi in (-15, 15):                       # ribetes plateados de la pechera
            s, z = sc(P.theta, phi)
            if z < 0.2:
                continue
            xt, xb = P.cx + P.ancho(176) * s, P.cx + P.wb * s * .97
            out += (f'<path d="M{xt:.1f},176 Q{(xt + xb) / 2:.1f},200 {xb:.1f},224" fill="none" stroke="url(#plata)" '
                    f'stroke-width="2.4" opacity="{.5 + .5 * z:.2f}"/>')
        if P.cos > 0.35:                            # copo bordado en el centro
            x = P.cx + P.ancho(196) * P.sin
            out += f'<g transform="translate({x:.1f} 197) scale({P.cos:.2f} 1)">{copo(0, 0, 7, ancho=1.3)}</g>'
        carambanos = []                             # carámbanos colgando del bajo, todo alrededor
        for i, phi in enumerate(range(-180, 180, 24)):
            s, z = sc(P.theta, phi)
            if z < 0.1:
                continue
            x = P.cx + P.wb * .97 * s
            largo = 7 + 4 * (i % 3)
            carambanos.append((z, cristal(x, 226, x, 228 + largo, 2.6, ancho=1.2)))
        return out + "".join(s for _, s in sorted(carambanos))

    def cintura(self, P):
        piezas = []
        for phi in (-36, 34):                       # colgantes de cristal
            x, y, z = en_cinturon(P, phi)
            if z > 0.15:
                piezas.append((z, f'<path d="M{x:.1f},{y + 4:.1f} L{x:.1f},{y + 10:.1f}" stroke="url(#plata)" stroke-width="1.5"/>'
                                  + cristal(x, y + 10, x, y + 24, 3.2, ancho=1.3)))
        x, y, z = en_cinturon(P, 0)
        if z > 0.25:
            piezas.append((z, f'<g filter="url(#resplandor)">{prisma(x, y + 1, 4.5 * (.5 + .5 * z), 8, 7)}</g>'))
        return cinturon(P) + "".join(s for _, s in sorted(piezas))

    def adorno_manga(self, borde):
        return f'<path d="M{borde}" fill="none" stroke="#f4fbff" stroke-width="4.5" stroke-linejoin="round" stroke-linecap="round"/>'

    def borde_capa(self, borde):
        return (f'<path d="M{borde}" fill="none" stroke="#d8f4ff" stroke-width="2" opacity=".8" '
                f'stroke-linejoin="round" filter="url(#resplandor)"/>')

    def esclavina(self, P):
        # manto de pelo blanco: borde con muchas puntas cortas
        return esclavina(P, semilla=5, prof=5, n=18)[0]

    def _corona(self, P):
        piezas = []
        for phi, h in ((-50, 18), (-25, 26), (0, 36), (25, 26), (50, 18)):
            s, z = sc(P.theta, phi)
            bx, by = P.hx + 22 * s + P.punta * .45, 72 + z * 22 * PROF_Y
            piezas.append((z, cristal(bx, by, bx + 7 * s - 4 * P.sin, by - h, 4.6)))
        return piezas

    def detras_capucha(self, P):
        return "".join(s for z, s in sorted(self._corona(P), key=lambda t: t[0]) if z < -0.2)

    def delante_capucha(self, P):
        out = "".join(s for z, s in sorted(self._corona(P), key=lambda t: t[0]) if z >= -0.2)
        if P.cos > -0.1:                           # barba de carámbanos (fuera del recorte de la capucha)
            barba = []
            for phi, largo in ((-22, 14), (-11, 22), (0, 30), (11, 22), (22, 14)):
                s, z = sc(P.theta, phi)
                if z < 0.15:
                    continue
                x = P.hx + 20 * s
                barba.append((z, cristal(x, 124, x + 2 * s, 124 + largo, 3.4 * z ** .5 + 1, relleno="url(#barbaHielo)", ancho=1.4)))
            out += "".join(s for _, s in sorted(barba))
        return out

    def cara(self, P, vx, vw):
        """Cara pálida y helada: cejas fruncidas y ojos que brillan desde cuencas oscuras."""
        rx = vw * .8
        d = (f"M{vx:.1f},84 Q{vx + rx:.1f},85 {vx + rx:.1f},104 Q{vx + rx * .85:.1f},122 {vx:.1f},132 "
             f"Q{vx - rx * .85:.1f},122 {vx - rx:.1f},104 Q{vx - rx:.1f},85 {vx:.1f},84 Z")
        out = f'<path class="c" d="{d}" fill="url(#piel)" stroke-width="2"/>'
        for phi, rot in ((-27, 18), (27, -18)):     # cejas
            s, z = sc(P.theta, phi)
            if z < 0.2:
                continue
            x, k = P.hx + 24 * s, z ** .6
            out += (f'<path d="M{x - 7 * k:.1f},100 L{x + 7 * k:.1f},103" stroke="#0e2440" stroke-width="2.4" '
                    f'stroke-linecap="round" transform="rotate({rot} {x:.1f} 101)"/>')
        if P.cos > 0.4:
            out += f'<path d="M{vx - 5 * P.cos:.1f},122 Q{vx:.1f},119 {vx + 5 * P.cos:.1f},122" fill="none" stroke="#1a3a5a" stroke-width="1.6"/>'
        return out + ojos(P, "url(#ojo)", "#effcff", ancho=5, alto=2, ranura="#06121e")

    def efectos(self, P):
        """Copos que caen despacio alrededor del mago."""
        def caer(c, x, ph):
            y = 24 + ph * 210
            op = min(1, ph * 5) * (1 - max(0, ph - .8) / .2)
            return f'<g opacity="{op:.2f}">{copo(x + 6 * math.sin(ph * TAU + c), y, 3 + (c % 2), rot=ph * 120, ancho=1)}</g>'
        return particulas_carril([P.cx - 74, P.cx - 40, P.cx + 44, P.cx + 76, P.cx + 8], 2, P.f, 4, caer)


# ================================================== EL MAGO DEL VACÍO ===
FUEGO_VACIO = [("#3a0a6a", 1.0), ("#7a2ad0", 0.8), ("#c070ff", 0.58), ("#f4e0ff", 0.32)]
RUNAS = ["M-4,-6 L0,-2 L4,-6 M0,-2 L0,6 M-3,3 L3,3", "M-4,-5 L0,5 L4,-5 M-3,-1 L3,-1",
         "M0,-6 L0,6 M-4,-2 L0,2 L4,-2", "M-4,6 L0,-6 L4,6 M-2,1 L2,1"]


def baston_vacio(x, y_mano, f):
    """Bastón de obsidiana con una luna creciente que sujeta un agujero negro diminuto."""
    cy = 34
    off = -f * 2.5                    # el anillo punteado gira: 2.5 x 4 frames = 10 = un periodo de "6 4"
    return f"""<g transform="translate(0 {y_mano - 196:.1f})">
  <circle cx="{x:.1f}" cy="{cy}" r="38" fill="url(#aura)" opacity="{PULSO[f] * 0.85:.2f}"/>
  <path class="c" d="M{x:.1f},244 L{x:.1f},58" fill="none" stroke-width="10"/>
  <path d="M{x:.1f},244 L{x:.1f},58" fill="none" stroke="url(#madera)" stroke-width="7"/>
  <path d="M{x - 1:.1f},120 l3,8 l-3,7 M{x + 1:.1f},170 l-3,6 l3,8" fill="none" stroke="#c070ff" stroke-width="1.4" filter="url(#resplandor)"/>
  <path class="c" d="M{x - 18:.1f},24 Q{x - 24:.1f},58 {x:.1f},62 Q{x + 24:.1f},58 {x + 18:.1f},24 Q{x + 14:.1f},50 {x:.1f},52 Q{x - 14:.1f},50 {x - 18:.1f},24 Z" fill="url(#madera)" stroke-width="2"/>
  <path d="M{x - 15:.1f},30 Q{x - 12:.1f},48 {x:.1f},50" fill="none" stroke="#a060ff" stroke-width="1.3" opacity=".8"/>
  <path d="M{x - 15:.1f},{cy} A15,4.5 0 0,1 {x + 15:.1f},{cy}" fill="none" stroke="#c070ff" stroke-width="2" stroke-dasharray="6 4" stroke-dashoffset="{off}" filter="url(#resplandor)"/>
  <circle cx="{x:.1f}" cy="{cy}" r="9" fill="#000" stroke="#d8a8ff" stroke-width="1.6" filter="url(#resplandor)"/>
  <path d="M{x + 15:.1f},{cy} A15,4.5 0 0,1 {x - 15:.1f},{cy}" fill="none" stroke="#e8c8ff" stroke-width="2.2" stroke-dasharray="6 4" stroke-dashoffset="{off}" filter="url(#resplandor)"/>
  <circle cx="{x + 12 - f * 3:.1f}" cy="{cy - 10 + f * 2:.1f}" r="1.4" fill="#e8c8ff" opacity="{1 - f * .2:.2f}"/></g>"""


class MagoVacio:
    nombre = "vacio"
    prof_bajo, prof_manga = 10, 9
    color_pliegue = "#000"
    brillo_borde = "#7a4ab0"
    rizo = True
    flota = True          # levita: sin pies
    disolver = True       # la túnica y la capa se desvanecen hacia abajo
    defs = """
  <radialGradient id="niebla"><stop offset="0" stop-color="#b060ff" stop-opacity=".38"/><stop offset=".6" stop-color="#6a2ad0" stop-opacity=".14"/><stop offset="1" stop-color="#6a2ad0" stop-opacity="0"/></radialGradient>
  <linearGradient id="tunica" x1="0" x2="1"><stop offset="0" stop-color="#34204e"/><stop offset=".45" stop-color="#140a26"/><stop offset="1" stop-color="#05020a"/></linearGradient>
  <linearGradient id="manga" x1="0" x2="1"><stop offset="0" stop-color="#3c2658"/><stop offset=".5" stop-color="#140a26"/><stop offset="1" stop-color="#05020a"/></linearGradient>
  <linearGradient id="tunicaV" x1="0" x2="0" y1="0" y2="1"><stop offset=".2" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#000" stop-opacity=".4"/></linearGradient>
  <linearGradient id="resplandorBajo" x1="0" x2="0" y1="0" y2="1"><stop offset=".55" stop-color="#a04aff" stop-opacity="0"/><stop offset="1" stop-color="#a04aff" stop-opacity=".3"/></linearGradient>
  <linearGradient id="capa" x1="0" x2="1"><stop offset="0" stop-color="#1c1030"/><stop offset="1" stop-color="#030108"/></linearGradient>
  <linearGradient id="capucha" x1="0" x2="1"><stop offset="0" stop-color="#462a6c"/><stop offset=".5" stop-color="#1c0f32"/><stop offset="1" stop-color="#07030f"/></linearGradient>
  <linearGradient id="manto" x1="0" x2="1"><stop offset="0" stop-color="#3a2258"/><stop offset=".5" stop-color="#160c2a"/><stop offset="1" stop-color="#05020c"/></linearGradient>
  <radialGradient id="vacio" cx=".5" cy=".55" r=".6"><stop offset="0" stop-color="#000"/><stop offset=".7" stop-color="#05020e"/><stop offset="1" stop-color="#2e1a50"/></radialGradient>
  <radialGradient id="ojo"><stop offset="0" stop-color="#f6e8ff" stop-opacity=".95"/><stop offset=".45" stop-color="#b060ff" stop-opacity=".45"/><stop offset="1" stop-color="#b060ff" stop-opacity="0"/></radialGradient>
  <linearGradient id="piel" x1="0" x2="1"><stop offset="0" stop-color="#c4b6dc"/><stop offset="1" stop-color="#5a4a78"/></linearGradient>
  <linearGradient id="madera" x1="0" x2="1"><stop offset="0" stop-color="#4a3e5c"/><stop offset=".5" stop-color="#1a1424"/><stop offset="1" stop-color="#06040a"/></linearGradient>
  <radialGradient id="aura"><stop offset="0" stop-color="#c070ff" stop-opacity=".75"/><stop offset=".45" stop-color="#7a2ad0" stop-opacity=".25"/><stop offset="1" stop-color="#7a2ad0" stop-opacity="0"/></radialGradient>
  <linearGradient id="cuero" x1="0" x2="0" y1="0" y2="1"><stop offset="0" stop-color="#2a1a3c"/><stop offset="1" stop-color="#0c0614"/></linearGradient>
  <linearGradient id="bota" x1="0" x2="0" y1="0" y2="1"><stop offset="0" stop-color="#2a1a3c"/><stop offset="1" stop-color="#0c0614"/></linearGradient>
  <linearGradient id="gradDisolver" gradientUnits="userSpaceOnUse" x1="0" y1="176" x2="0" y2="246"><stop offset="0" stop-color="#fff"/><stop offset="1" stop-color="#000"/></linearGradient>
  <mask id="disolver" maskUnits="userSpaceOnUse" x="0" y="0" width="256" height="256"><rect x="0" y="0" width="256" height="256" fill="url(#gradDisolver)"/></mask>
"""

    def baston(self, x, y, f):
        return baston_vacio(x, y, f)

    def puno(self, x, y):
        return puno(x, y, "#3a2a50", "#0a0610")

    def mano_hechizo(self, cx, cy, f):
        oy = cy - 28 + [0, -2, 0, 2][f]
        return garra(cx, cy, "#a89ac4", "#0a0610") + (
            f'<circle cx="{cx:.1f}" cy="{oy:.1f}" r="26" fill="url(#aura)" opacity="{PULSO[f]}"/>'
            f'<g filter="url(#resplandor)">{llama(cx, oy + 6, 30, 10, f, 3.3, paleta=FUEGO_VACIO, color_borde="#0e0218")}'
            f'<circle cx="{cx:.1f}" cy="{oy + 3:.1f}" r="4.5" fill="#0a0014" stroke="#f4e0ff" stroke-width="1.2"/></g>')

    def tunica_extra(self, P, d):
        out = ""
        for i, phi in enumerate((-50, 0, 50, 130, 180, 230)):     # runas brillantes en la túnica
            s, z = sc(P.theta, phi)
            if z < 0.25:
                continue
            x = P.cx + P.ancho(200) * .9 * s
            out += (f'<g transform="translate({x:.1f} 200) scale({.9 * z:.2f} .9)" opacity="{(.4 + .6 * z) * PULSO[P.f]:.2f}">'
                    f'<path d="{RUNAS[i % 4]}" fill="none" stroke="#c070ff" stroke-width="2" stroke-linecap="round" filter="url(#resplandor)"/></g>')
        for i, phi in enumerate(range(-150, 180, 30)):              # jirones de humo bajo el bajo
            s, z = sc(P.theta, phi)
            if z < 0:
                continue
            x = P.cx + P.wb * .9 * s
            sw = 4 * math.sin(P.f * math.pi / 2 + i)
            out += f'<path d="M{x - 5:.1f},222 Q{x - 3:.1f},238 {x + sw:.1f},252 Q{x + 3:.1f},238 {x + 5:.1f},222 Z" fill="#2a1648" opacity=".8"/>'
        return out

    def cintura(self, P):
        piezas = []
        for phi in (-36, 34):                       # orbes negros colgantes
            x, y, z = en_cinturon(P, phi)
            if z > 0.15:
                piezas.append((z, f'<path d="M{x:.1f},{y + 4:.1f} L{x:.1f},{y + 10:.1f}" stroke="#4a3a5c" stroke-width="1.5"/>'
                                  f'<circle cx="{x:.1f}" cy="{y + 14:.1f}" r="4" fill="#000" stroke="#c070ff" stroke-width="1.3" filter="url(#resplandor)"/>'))
        x, y, z = en_cinturon(P, 0)
        if z > 0.25:
            piezas.append((z, f'<ellipse class="c" cx="{x:.1f}" cy="{y + 1:.1f}" rx="{6 * (.5 + .5 * z):.1f}" ry="6" fill="#1a0a2e" stroke-width="1.8"/>'
                              f'<ellipse cx="{x:.1f}" cy="{y + 1:.1f}" rx="{3 * (.5 + .5 * z):.1f}" ry="3" fill="#c070ff" filter="url(#resplandor)"/>'))
        return cinturon(P) + "".join(s for _, s in sorted(piezas))

    def adorno_manga(self, borde):
        return f'<path d="M{borde}" fill="none" stroke="#9a4aff" stroke-width="2" stroke-linejoin="round" filter="url(#resplandor)"/>'

    def borde_capa(self, borde):
        return f'<path d="M{borde}" fill="none" stroke="#7a3ad0" stroke-width="1.6" opacity=".7" stroke-linejoin="round"/>'

    def esclavina(self, P):
        forma, borde = esclavina(P, semilla=8, prof=10, n=10)
        return forma + f'<path d="M{borde}" fill="none" stroke="#8a4ae0" stroke-width="1.4" opacity=".8" stroke-linejoin="round"/>'

    def _halo(self, P, delante):
        """Anillo roto que flota sobre la cabeza: 3 arcos que giran (120° de simetría)."""
        cx, cy = P.hx + P.punta * .9, 24
        tramos, tramo = [], []
        for k in range(3):
            for g in range(0, 81, 5):
                a = math.radians(P.f * 30 + k * 120 + g)
                pt = (cx + 31 * math.cos(a), cy + 9 * math.sin(a))
                if (math.sin(a) >= 0) == delante:
                    tramo.append(pt)
                elif tramo:
                    tramos.append(tramo); tramo = []
            if tramo:
                tramos.append(tramo); tramo = []
        out = ""
        for t in tramos:
            if len(t) < 2:
                continue
            d = "M" + " L".join(fp(p) for p in t)
            out += (f'<path d="{d}" fill="none" stroke="#0a0414" stroke-width="5.5" stroke-linecap="round"/>'
                    f'<path d="{d}" fill="none" stroke="#9a4aff" stroke-width="3.2" stroke-linecap="round" filter="url(#resplandor)"/>'
                    f'<path d="{d}" fill="none" stroke="#f0d8ff" stroke-width="1.1" stroke-linecap="round"/>')
        return out

    def detras_capucha(self, P):
        return self._halo(P, False)

    def delante_capucha(self, P):
        return self._halo(P, True)

    def cara(self, P, vx, vw):
        """Dentro de la capucha hay un cielo estrellado... y un tercer ojo."""
        out = ""
        for i in range(12):
            u = ((i * 37) % 100) / 100 * 1.6 - .8
            v = ((i * 53) % 100) / 100
            op = .35 + .5 * abs(math.sin(i + P.f * 1.3))
            out += f'<circle cx="{vx + vw * u:.1f}" cy="{80 + 54 * v:.1f}" r="{.6 + (i % 3) * .4:.1f}" fill="#e8d8ff" opacity="{op:.2f}"/>'
        out += ojos(P, "url(#ojo)", "#f6e8ff")
        if P.cos > 0.3:
            out += (f'<circle cx="{vx:.1f}" cy="90" r="8" fill="url(#ojo)" opacity="{PULSO[P.f]}"/>'
                    f'<ellipse cx="{vx:.1f}" cy="90" rx="{1.8 * P.cos:.1f}" ry="5" fill="#ff6ae0" filter="url(#resplandor)"/>')
        return out

    def efectos(self, P):
        """Motas del vacío que suben flotando."""
        def subir(c, x, ph):
            y = 240 - ph * 170
            op = min(1, ph * 5) * (1 - max(0, ph - .7) / .3)
            s = 2.2
            return f'<path d="M{x:.1f},{y - s:.1f} L{x + s:.1f},{y:.1f} L{x:.1f},{y + s:.1f} L{x - s:.1f},{y:.1f} Z" fill="#c070ff" opacity="{op:.2f}"/>'
        return particulas_carril([P.cx - 66, P.cx - 34, P.cx + 30, P.cx + 64], 2, P.f, 4, subir)


# ================================================== MONTAJE DE CAPAS ===
def construir(pj, theta, f, con_baston=True):
    """Las capas de una pose. Sin bastón (con_baston=False), la mano se queda
    cerrada y vacía: es la que sujeta el arma del gacha (Matías, 2026-11-10: «cuando
    usas una varita con el mago, debe quitarse el arma default»)."""
    P = Pose(theta, f, getattr(pj, "flota", False))
    # Manos: la derecha (phi=-100) lleva el bastón; la izquierda (phi=+70), el hechizo
    xs, ys, zs = _mano_del_baston(P)
    xo, yo, zo = P.mano(70, 60, avance=20)
    hd = P.punto(-90, 24, 140)[:2]
    hi = P.punto(90, 24, 140)[:2]
    manga_d, manga_i = manga(P, hd, (xs, ys), 4, pj), manga(P, hi, (xo, yo), 5, pj)
    baston = pj.baston(xs, ys, f) if con_baston else ""
    puno_d = pj.puno(xs, ys)
    hechizo = pj.mano_hechizo(xo, yo, f)

    atras, mangas_del, manos_del = "", "", ""
    if zs < -0.3:
        atras += baston + manga_d + puno_d
    else:
        mangas_del += manga_d
        manos_del += baston + puno_d
    if zo < -0.45:
        atras += manga_i + hechizo
    else:
        mangas_del += manga_i
        manos_del += hechizo

    de_espaldas = P.cos < -0.3
    if de_espaldas:
        ropa = tunica(P, pj) + pj.cintura(P) + capa(P, pj, True)
    else:
        ropa = capa(P, pj, False) + tunica(P, pj) + pj.cintura(P)
    if getattr(pj, "disolver", False):     # máscara: la ropa se desvanece hacia abajo
        ropa = f'<g mask="url(#disolver)">{ropa}</g>'
    # Ganchos de las skins (ver generar_skins.py): lo que llevan a la espalda
    # (alas, cintas) va detrás del cuerpo salvo de espaldas, que se ve encima
    # de la capa; lo que gira alrededor (orbitas) se ordena por su z.
    espalda = pj.espalda(P) if hasattr(pj, "espalda") else ""
    orbitas = pj.orbitas(P) if hasattr(pj, "orbitas") else []
    detras_todo = "".join(o for z, o in sorted(orbitas, key=lambda t: t[0]) if z < 0)
    delante_todo = "".join(o for z, o in sorted(orbitas, key=lambda t: t[0]) if z >= 0)
    if de_espaldas:
        ropa += espalda
    else:
        atras = espalda + atras
    cuerpo = (detras_todo + atras + ropa + mangas_del + pj.esclavina(P) + pj.detras_capucha(P) + capucha(P, pj)
              + pj.delante_capucha(P) + manos_del + pj.efectos(P) + delante_todo)
    if hasattr(pj, "envolver"):
        cuerpo = pj.envolver(P, cuerpo)
    return (sombra_suelo(P) + niebla(P) + ("" if P.flota else pies(P))
            + f'<g transform="translate(0 {P.rebote:.1f})">{cuerpo}</g>' + niebla(P, True))


def svg(pj, theta, f, con_baston=True):
    texto = (f'<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" '
             f'viewBox="0 0 256 256" width="256" height="256">'
             f'<defs>{DEFS_COMUN}{pj.defs}{getattr(pj, "defs_extra", "")}</defs>{construir(pj, theta, f, con_baston)}</svg>')
    # Las skins cambian los colores del dibujo de serie (ver generar_skins.py).
    return pj.colorear(texto) if hasattr(pj, "colorear") else texto


def mano_baston(pj, theta, f):
    """Donde está la mano del bastón en esa pose, en el lienzo de 256: (x, y, z),
    con el rebote del paso ya puesto, y z < -0.3 si queda detrás del cuerpo (lo
    mismo que mira construir). Ahí se pinta el arma del gacha en el juego."""
    P = Pose(theta, f, getattr(pj, "flota", False))
    xs, ys, zs = _mano_del_baston(P)
    return xs, ys + P.rebote, zs


def _mano_del_baston(P):
    # De perfil adelantamos más el bastón para que no tape la cara; de espaldas, menos
    avance = 48 * (0.55 + 0.45 * max(P.cos, 0)) + 36 * abs(P.sin) ** 6
    return P.mano(-100, 60, avance=avance)


def render(texto, ruta_svg, ruta_png, px):
    with open(ruta_svg, "w") as fh:
        fh.write(texto)
    subprocess.run(["rsvg-convert", "-w", str(px), "-h", str(px), ruta_svg, "-o", ruta_png], check=True)
    return Image.open(ruta_png).convert("RGBA")


def generar(pj):
    """La hoja de 4 pasos x 8 direcciones a 128 px y el sur a 512 (el retrato)."""
    base = os.path.join(RAIZ, pj.nombre)
    tmp = os.path.join(base, "_tmp")
    os.makedirs(tmp, exist_ok=True)
    hoja = Image.new("RGBA", (FRAME_PX * 4, FRAME_PX * 8))
    for k in range(len(DIRECCIONES)):
        for f in range(4):
            img = render(svg(pj, theta_de_fila(k), f), os.path.join(tmp, "f.svg"), os.path.join(tmp, "f.png"), FRAME_PX)
            hoja.alpha_composite(img, (f * FRAME_PX, k * FRAME_PX))
    hoja.save(os.path.join(base, pj.nombre + "_spritesheet_8dir.png"))
    render(svg(pj, 0, 1), os.path.join(tmp, "r.svg"), os.path.join(tmp, "r.png"), 512).save(
        os.path.join(base, pj.nombre + "_S_512.png"))
    shutil.rmtree(tmp)


if __name__ == "__main__":
    import sys
    todos = {"envenenador": Envenenador, "piromante": Piromante, "criomante": Criomante, "vacio": MagoVacio}
    for nombre in (sys.argv[1:] or list(todos)):
        generar(todos[nombre]())
        print(nombre)
