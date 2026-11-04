"""Hechizos del Piromante (Vacío): bola de fuego y ultimate "bola de fuego gigante".

Ideas clave:
- El fuego se dibuja en 4 CAPAS (rojo -> naranja -> amarillo -> blanco). Una
  función "generador(k)" devuelve las formas para una escala k: k=1 es la capa
  exterior y k pequeño la interior, más caliente. Primero se pinta la silueta
  exterior con un trazo oscuro (contorno) y encima los rellenos.
- Las animaciones en BUCLE usan t = 2*pi*frame/N dentro de senos: al llegar al
  frame N todo vuelve exactamente al principio, así no hay salto.
- Las partículas usan una fase (i/n + frame/N) % 1, que también cierra el bucle.
- El núcleo de magma de la ultimate es una esfera con placas de roca colocadas
  en latitud/longitud que se proyectan a pantalla (la misma idea pseudo-3D que
  los magos) y que rota 45° por ciclo: como las placas se repiten cada 45°, el
  bucle es perfecto.
"""
import math, os, os, random, shutil, subprocess
from PIL import Image

RAIZ = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..") + "/hechizos/piromante"
TMP = f"{RAIZ}/_tmp"
TAU = 2 * math.pi
CONTORNO = "#2a0402"
FUEGO = [("#b8180c", 1.0), ("#ff5a14", 0.8), ("#ffaa22", 0.58), ("#fff1b8", 0.32)]

DEFS = """
  <filter id="brillo" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="3" result="b"/><feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter>
  <filter id="brilloFuerte" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="7" result="b"/><feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter>
  <filter id="difuso" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="5"/></filter>
  <radialGradient id="aura"><stop offset="0" stop-color="#ffb02a" stop-opacity=".75"/><stop offset=".45" stop-color="#ff5a14" stop-opacity=".25"/><stop offset="1" stop-color="#ff3a0a" stop-opacity="0"/></radialGradient>
  <radialGradient id="destello"><stop offset="0" stop-color="#ffffff"/><stop offset=".35" stop-color="#fff4c0" stop-opacity=".9"/><stop offset="1" stop-color="#ffaa22" stop-opacity="0"/></radialGradient>
  <radialGradient id="magma" cx=".42" cy=".4" r=".65"><stop offset="0" stop-color="#fffbe0"/><stop offset=".3" stop-color="#ffd45a"/><stop offset=".7" stop-color="#ff6a14"/><stop offset="1" stop-color="#c41e0c"/></radialGradient>
  <radialGradient id="limbo" cx=".5" cy=".5" r=".5"><stop offset=".6" stop-color="#3a0602" stop-opacity="0"/><stop offset="1" stop-color="#3a0602" stop-opacity=".55"/></radialGradient>
  <radialGradient id="corteza" cx=".38" cy=".34" r=".72"><stop offset="0" stop-color="#b2482a"/><stop offset=".45" stop-color="#621c0c"/><stop offset="1" stop-color="#200604"/></radialGradient>
  <linearGradient id="costra" x1="0" x2="1" y1="0" y2="1"><stop offset="0" stop-color="#6a2c18"/><stop offset=".5" stop-color="#2e0e08"/><stop offset="1" stop-color="#120403"/></linearGradient>
  <radialGradient id="humo" cx=".4" cy=".35" r=".7"><stop offset="0" stop-color="#5e4e48"/><stop offset="1" stop-color="#1e1614"/></radialGradient>
  <radialGradient id="quemadura"><stop offset="0" stop-color="#080202" stop-opacity=".95"/><stop offset=".55" stop-color="#1e0a06" stop-opacity=".85"/><stop offset=".85" stop-color="#2a140c" stop-opacity=".45"/><stop offset="1" stop-color="#2a140c" stop-opacity="0"/></radialGradient>
  <radialGradient id="sueloArdiente"><stop offset="0" stop-color="#ffd25a" stop-opacity=".9"/><stop offset=".4" stop-color="#ff5a14" stop-opacity=".5"/><stop offset="1" stop-color="#ff3a0a" stop-opacity="0"/></radialGradient>
"""


# ============================================================ UTILIDADES ===
def P(x, y):
    return f"{x:.1f},{y:.1f}"


def svg(w, h, contenido, defs_extra=""):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" width="{w}" height="{h}">'
            f'<defs>{DEFS}{defs_extra}</defs>{contenido}</svg>')


def render(texto, nombre, w, h, carpeta=None):
    base = carpeta or RAIZ
    os.makedirs(f"{base}/svg", exist_ok=True)
    os.makedirs(f"{base}/_tmp", exist_ok=True)
    ruta_svg, ruta_png = f"{base}/svg/{nombre}.svg", f"{base}/_tmp/{nombre}.png"
    with open(ruta_svg, "w") as fh:
        fh.write(texto)
    subprocess.run(["rsvg-convert", "-w", str(w), "-h", str(h), ruta_svg, "-o", ruta_png], check=True)
    return Image.open(ruta_png).convert("RGBA")


def hoja(frames, columnas):
    w, h = frames[0].size
    filas = math.ceil(len(frames) / columnas)
    img = Image.new("RGBA", (w * columnas, h * filas))
    for i, fr in enumerate(frames):
        img.alpha_composite(fr, ((i % columnas) * w, (i // columnas) * h))
    return img


def suave(p, potencia=2.2):
    """Curva 'ease-out': rápido al principio y frena al final (como una explosión)."""
    return 1 - (1 - min(max(p, 0), 1)) ** potencia


def lengua(bx, by, tx, ty, w, curva=0.0):
    """Lengua de fuego de la base (bx,by) a la punta (tx,ty). `curva` la dobla en S."""
    dx, dy = tx - bx, ty - by
    L = math.hypot(dx, dy) or 1
    ux, uy, nx, ny = dx / L, dy / L, -dy / L, dx / L
    b1, b2 = (bx + nx * w, by + ny * w), (bx - nx * w, by - ny * w)
    c1 = (bx + ux * L * .45 + nx * (w * 1.05 + curva), by + uy * L * .45 + ny * (w * 1.05 + curva))
    c2 = (tx - ux * L * .25 + nx * (w * .25 + curva * .6), ty - uy * L * .25 + ny * (w * .25 + curva * .6))
    c3 = (tx - ux * L * .25 - nx * (w * .25 - curva * .6), ty - uy * L * .25 - ny * (w * .25 - curva * .6))
    c4 = (bx + ux * L * .45 - nx * (w * 1.05 - curva), by + uy * L * .45 - ny * (w * 1.05 - curva))
    atras = (bx - ux * w * 1.4, by - uy * w * 1.4)
    return (f"M{P(*b1)} C{P(*c1)} {P(*c2)} {P(tx, ty)} C{P(*c3)} {P(*c4)} {P(*b2)} "
            f"Q{P(*atras)} {P(*b1)} Z")


def circulo_d(cx, cy, r):
    return f"M{cx - r:.1f},{cy:.1f} a{r:.1f},{r:.1f} 0 1,0 {2 * r:.1f},0 a{r:.1f},{r:.1f} 0 1,0 {-2 * r:.1f},0 Z"


def blob_d(cx, cy, r, fase, bultos=7, irr=0.12, n=48, achatar=1.0):
    """Círculo con bultos (nube de fuego o de humo)."""
    pts = []
    for i in range(n):
        a = TAU * i / n
        rr = r * (1 + irr * math.sin(bultos * a + fase) + irr * .6 * math.sin((bultos + 4) * a - fase * 1.3))
        pts.append(P(cx + rr * math.cos(a), cy + rr * math.sin(a) * achatar))
    return "M" + " L".join(pts) + " Z"


def fuego_en_capas(generador, capas=4, opacidad=1.0, ancho_contorno=4, filtro="brillo", paleta=None, contorno=None):
    """Pinta el contorno de la capa exterior y luego los rellenos de fuera a dentro."""
    paleta, contorno = paleta or FUEGO, contorno or CONTORNO
    exterior = generador(1.0)
    out = f'<g opacity="{opacidad:.2f}" filter="url(#{filtro})">'
    out += "".join(f'<path d="{d}" fill="{contorno}" stroke="{contorno}" stroke-width="{ancho_contorno}" '
                   f'stroke-linejoin="round"/>' for d in exterior)
    for i, (color, k) in enumerate(paleta[:capas]):
        formas = exterior if i == 0 else generador(k)
        out += "".join(f'<path d="{d}" fill="{color}"/>' for d in formas)
    return out + "</g>"


def particulas_bucle(n, f, N, fn):
    """Partículas que cierran el bucle: cada una recorre su fase de 0 a 1 en N frames."""
    return "".join(fn(i, (i / n + f / N) % 1) for i in range(n))


# =================================================== 1. BOLA DE FUEGO ===
# (desplazamiento vertical, largo, ancho, fase) de cada lengua de la estela
ESTELA = [(0, 110, 15, 0.0), (-11, 85, 10, 1.3), (11, 90, 10, 2.6), (-18, 62, 7, 3.9),
          (18, 66, 7, 5.1), (-4, 128, 7, 0.7), (6, 120, 6, 4.4)]


def gen_bola(cx, cy, R, t, k):
    formas = []
    hx = cx + R * (1 - k) * 0.4               # lo más caliente va delante
    formas.append(circulo_d(hx, cy, R * k))
    for dy, L, w, ph in ESTELA:
        largo = L * (0.35 + 0.65 * k) * (1 + 0.1 * math.sin(t + ph))
        punta_y = cy + dy * (0.6 + 0.4 * k) + 6 * math.sin(t + ph) * k
        formas.append(lengua(hx, cy + dy * 0.35 * k, hx - largo, punta_y, w * k, 7 * math.sin(t + ph * 1.3) * k))
    # lamidas alrededor del frente, empujadas hacia atrás por el aire
    for i, a in enumerate((-115, -80, -45, 45, 80, 115)):
        ar = math.radians(a)
        at = math.radians(a + 38 * (1 if a > 0 else -1))
        lon = R * k * (1.45 + 0.25 * math.sin(2 * t + i * 1.7))
        formas.append(lengua(hx + R * k * .7 * math.cos(ar), cy + R * k * .7 * math.sin(ar),
                             hx + lon * math.cos(at), cy + lon * math.sin(at), R * k * .3))
    return formas


# Un "tema" agrupa los colores de un hechizo; así la misma geometría sirve para otros elementos
TEMA_FUEGO = dict(paleta=FUEGO, contorno=CONTORNO, aura="aura", chispa="#ffd36b", brasa="#ff7a1a",
                  anillo="#ffb02a", destello="destello", nucleo="#ffffff", humo="humo", defs="")


def svg_bola_vuelo(f, N=6, tema=TEMA_FUEGO):
    t = TAU * f / N
    cx, cy, R = 180, 64, 22

    def humo(i, ph):
        x, y = cx - 70 - ph * 90, cy + 10 * math.sin(i * 2.3)
        op = 0.5 * (1 - ph) * min(1, ph * 4)
        return f'<path d="{blob_d(x, y, 5 + 9 * ph, i + ph * 3, 5, .15)}" fill="url(#{tema["humo"]})" opacity="{op:.2f}"/>'

    def brasa(i, ph):
        x = cx - 20 - ph * 150
        y = cy + (1 if i % 2 else -1) * (6 + 18 * ph) * abs(math.sin(i * 1.7 + 1))
        return (f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{2.4 * (1 - ph) + .6:.1f}" '
                f'fill="{tema["chispa"] if i % 3 else tema["brasa"]}" opacity="{1 - ph:.2f}"/>')

    c = (f'<ellipse cx="{cx - 30}" cy="{cy}" rx="112" ry="54" fill="url(#{tema["aura"]})" opacity="{0.75 + 0.15 * math.sin(t):.2f}"/>'
         + particulas_bucle(4, f, N, humo)
         + fuego_en_capas(lambda k: gen_bola(cx, cy, R, t, k), ancho_contorno=5, paleta=tema["paleta"], contorno=tema["contorno"])
         + f'<circle cx="{cx + 5}" cy="{cy - 1}" r="7" fill="{tema["nucleo"]}" filter="url(#brillo)" opacity=".9"/>'
         + particulas_bucle(9, f, N, brasa))
    return svg(256, 128, c, tema["defs"])


# Parámetros fijos (con azar reproducible) para el impacto
_r = random.Random(7)
IMP_LENGUAS = [(i * 360 / 11 + _r.uniform(-12, 12), _r.uniform(55, 90), _r.uniform(10, 16)) for i in range(11)]
IMP_HUMO = [(i * 45 + _r.uniform(-15, 15), _r.uniform(40, 70), _r.uniform(14, 22)) for i in range(8)]
IMP_CHISPAS = [(_r.uniform(0, 360), _r.uniform(70, 115), _r.uniform(8, 16)) for _ in range(16)]


def svg_bola_impacto(f, N=8, tema=TEMA_FUEGO):
    p = f / (N - 1)
    e = suave(p)
    cx, cy = 128, 124
    capas = 4 if p < .25 else 3 if p < .5 else 2 if p < .75 else 1
    out = (f'<ellipse cx="{cx}" cy="{cy + 22}" rx="{18 + 95 * e:.1f}" ry="{(18 + 95 * e) * .45:.1f}" fill="none" '
           f'stroke="{tema["anillo"]}" stroke-width="{7 * (1 - p) + .5:.1f}" opacity="{(1 - p) * .9:.2f}" filter="url(#brillo)"/>')
    op_humo = min(1, p * 3) * (1 - max(0, (p - .55) / .45)) * .85
    for i, (ang, dist, tam) in enumerate(IMP_HUMO):
        a = math.radians(ang)
        r = dist * (.3 + .9 * e)
        x, y = cx + math.cos(a) * r, cy + math.sin(a) * r * .8 - 25 * p
        out += (f'<path d="{blob_d(x, y, tam * (.4 + .9 * e), i + p * 2, 5, .14)}" fill="url(#{tema["humo"]})" '
                f'stroke="#0e0808" stroke-width="2" opacity="{op_humo:.2f}"/>')

    def gen(k):
        rc = 44 * (1 - p) ** .6 * (.7 + .6 * min(1, p * 4))
        formas = [blob_d(cx, cy - (1 - k) * 6, rc * k ** 1.4, p * 5, 6, .14)]
        for i in range(4):          # nubecillas que se separan del centro
            a = math.radians(45 + 90 * i)
            formas.append(blob_d(cx + math.cos(a) * 26 * e, cy + math.sin(a) * 20 * e - 8 * e,
                                 22 * (1 - p) ** .5 * k ** 1.4, i + p * 4, 5, .15))
        for ang, largo, ancho in IMP_LENGUAS:
            a = math.radians(ang)
            L = largo * (.45 + .75 * e) * (1 - .5 * max(0, p - .6) / .4) * (.35 + .65 * k)
            formas.append(lengua(cx, cy, cx + math.cos(a) * L, cy + math.sin(a) * L * .8 - 10 * e,
                                 (ancho * 1.25 * (1 - p) ** .8 + 1.5) * k, 11 * math.sin(ang * 3 + p * 4) * k))
        return formas

    out += fuego_en_capas(gen, capas, 1 if p < .6 else 1 - (p - .6) / .4 * .85, paleta=tema["paleta"], contorno=tema["contorno"])
    if f <= 2:
        out += f'<circle cx="{cx}" cy="{cy}" r="{30 + 30 * f}" fill="url(#{tema["destello"]})" opacity="{1 - f / 3:.2f}"/>'
    for ang, vel, largo in IMP_CHISPAS:
        a = math.radians(ang)
        r0 = 8 + vel * e
        r1 = r0 + largo * (1 - p) + 2
        out += (f'<path d="M{P(cx + math.cos(a) * r0, cy + math.sin(a) * r0)} L{P(cx + math.cos(a) * r1, cy + math.sin(a) * r1)}" '
                f'stroke="{tema["chispa"]}" stroke-width="{2 * (1 - p) + .3:.1f}" stroke-linecap="round" opacity="{1 - p:.2f}"/>')
    return svg(256, 256, out, tema["defs"])


# ======================================================= 2. ULTIMATE ===
INCLINACION = math.radians(22)     # el polo norte se inclina hacia la cámara
# Red de grietas en latitud/longitud. Todo se repite cada 45° de longitud, así
# que girando 45° por ciclo el bucle es perfecto.
GRIETAS_LAT = [-54, -20, 16, 50, 76]
GRIETAS_BANDAS = [(-80, -54, 0), (-54, -20, 22.5), (-20, 16, 0), (16, 50, 22.5), (50, 76, 0)]


def proyectar_esfera(cx, cy, R, lat, lon):
    """(lat, lon) -> pantalla. Devuelve también z (>0 = cara visible)."""
    la, lo = math.radians(lat), math.radians(lon)
    X, Y, Z = math.cos(la) * math.sin(lo), math.sin(la), math.cos(la) * math.cos(lo)
    Y2 = Y * math.cos(INCLINACION) - Z * math.sin(INCLINACION)
    Z2 = Y * math.sin(INCLINACION) + Z * math.cos(INCLINACION)
    return cx + R * X, cy - R * Y2, Z2


def grietas_esfera(cx, cy, R, rot, color="#ff8a1a", color_nucleo="#fff1b8", grosor=1.0):
    lineas = []
    for i, lat in enumerate(GRIETAS_LAT):                 # paralelos irregulares
        pts = []
        for lon in range(0, 361, 6):
            l = math.radians(lon)
            pts.append(proyectar_esfera(cx, cy, R, lat + 3.5 * math.sin(8 * l + i * 1.7) + 1.5 * math.sin(16 * l + i), lon + rot))
        lineas.append(pts)
    for j, (la0, la1, desfase) in enumerate(GRIETAS_BANDAS):  # meridianos entre paralelos
        for k in range(8):
            pts = [proyectar_esfera(cx, cy, R, lat, k * 45 + desfase + 6 * math.sin(lat * .15 + j) + rot)
                   for lat in range(la0, la1 + 1, 4)]
            lineas.append(pts)
    oscuro, brillo, nucleo = "", "", ""
    for pts in lineas:
        tramo = []
        for pt in pts + [None]:                           # dibujamos solo los tramos visibles
            if pt is not None and pt[2] > 0.03:
                tramo.append(pt)
                continue
            if len(tramo) >= 2:
                z = sum(p[2] for p in tramo) / len(tramo)
                w = R / 15 * (.35 + .65 * z) * grosor
                d = "M" + " L".join(P(x, y) for x, y, _ in tramo)
                oscuro += f'<path d="{d}" fill="none" stroke="#0e0201" stroke-width="{w * 2.6:.1f}" stroke-linejoin="round" stroke-linecap="round"/>'
                brillo += f'<path d="{d}" fill="none" stroke="{color}" stroke-width="{w:.1f}" stroke-linejoin="round" stroke-linecap="round"/>'
                if z > .45:
                    nucleo += f'<path d="{d}" fill="none" stroke="{color_nucleo}" stroke-width="{w * .35:.1f}" stroke-linecap="round"/>'
            tramo = []
    return oscuro + f'<g filter="url(#brillo)">{brillo}</g>' + nucleo


def nucleo_magma(cx, cy, R, rot):
    """Esfera de roca fundida con grietas incandescentes que giran (rot en grados)."""
    return (f'<circle cx="{cx}" cy="{cy}" r="{R:.1f}" fill="url(#corteza)" stroke="{CONTORNO}" stroke-width="{max(2, R / 14):.1f}"/>'
            f'<clipPath id="clipEsfera"><circle cx="{cx}" cy="{cy}" r="{R:.1f}"/></clipPath>'
            f'<g clip-path="url(#clipEsfera)">{grietas_esfera(cx, cy, R, rot)}'
            f'<circle cx="{cx}" cy="{cy}" r="{R:.1f}" fill="url(#limbo)"/></g>'
            f'<circle cx="{cx}" cy="{cy}" r="{R * .96:.1f}" fill="none" stroke="#ff7a1a" stroke-width="{R / 12:.1f}" '
            f'opacity=".45" filter="url(#brillo)"/>'
            f'<ellipse cx="{cx - R * .32:.1f}" cy="{cy - R * .34:.1f}" rx="{R * .3:.1f}" ry="{R * .2:.1f}" '
            f'fill="#ffc890" opacity=".22" filter="url(#difuso)"/>')


ESTELA_G = [(0, 330, 34, 0.0), (-26, 250, 24, 1.2), (26, 265, 24, 2.5), (-44, 175, 16, 3.7),
            (44, 185, 16, 4.9), (-12, 360, 14, 0.6), (14, 345, 13, 4.2), (-36, 215, 12, 5.6), (36, 225, 12, 2.0)]


def gen_gigante(cx, cy, R, t, k):
    formas = [circulo_d(cx, cy, R * (1 + .42 * k))]       # halo de fuego alrededor del núcleo
    for dy, L, w, ph in ESTELA_G:
        largo = L * (.4 + .6 * k) * (1 + .08 * math.sin(t + ph))
        formas.append(lengua(cx, cy + dy * .4, cx - largo, cy + dy * (.7 + .3 * k) + 12 * math.sin(t + ph) * k,
                             w * k ** .7, 14 * math.sin(t + ph * 1.3) * k))
    for i in range(11):
        a = -150 + i * 30
        if abs(a) < 25:
            continue
        ar, at = math.radians(a), math.radians(a + 34 * (1 if a > 0 else -1))
        lon = R * (1.3 + (.45 + .15 * math.sin(2 * t + i * 1.9)) * k)
        formas.append(lengua(cx + R * .8 * math.cos(ar), cy + R * .8 * math.sin(ar),
                             cx + lon * math.cos(at), cy + lon * math.sin(at), R * .22 * k))
    return formas


def svg_ultimate_vuelo(f, N=6):
    t = TAU * f / N
    cx, cy, R = 372, 128, 58

    def humo(i, ph):
        x = cx - 80 - ph * 360
        y = cy + (1 if i % 2 else -1) * (10 + 40 * ph) * .8 + 8 * math.sin(i)
        op = .75 * (1 - ph) * min(1, ph * 5)
        return (f'<path d="{blob_d(x, y, 14 + 34 * ph, i + ph * 3, 5, .14)}" fill="url(#humo)" '
                f'stroke="#0e0808" stroke-width="2" opacity="{op:.2f}"/>')

    def brasa(i, ph):
        x = cx - 40 - ph * 420
        y = cy + (1 if i % 2 else -1) * (14 + 60 * ph) * abs(math.sin(i * 1.3 + .5))
        return f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{3.2 * (1 - ph) + .8:.1f}" fill="{"#ffd36b" if i % 3 else "#ff7a1a"}" opacity="{1 - ph:.2f}"/>'

    def chispa(i, ph):
        x = cx - R * .6 - ph * 300
        y = cy + (i - 3.5) * 13 * (0.5 + ph)
        return (f'<path d="M{P(x, y)} L{P(x - 26 * (1 - ph) - 6, y)}" stroke="#fff1b8" stroke-width="2" '
                f'stroke-linecap="round" opacity="{(1 - ph) * .8:.2f}"/>')

    c = (f'<ellipse cx="{cx - 60}" cy="{cy}" rx="250" ry="118" fill="url(#aura)" opacity="{.8 + .12 * math.sin(t):.2f}"/>'
         + particulas_bucle(7, f, N, humo)
         + fuego_en_capas(lambda k: gen_gigante(cx, cy, R, t, k), ancho_contorno=6, filtro="brilloFuerte")
         + nucleo_magma(cx, cy, R, rot=7.5 * f)          # 45° por ciclo de 6 frames
         + f'<circle cx="{cx}" cy="{cy}" r="{R + 3}" fill="none" stroke="#ffd25a" stroke-width="3" opacity=".7" filter="url(#brillo)"/>'
         + particulas_bucle(8, f, N, chispa) + particulas_bucle(16, f, N, brasa))
    return svg(512, 256, c)


def svg_ultimate_carga(f, N=8):
    p = (f + 1) / N
    e = suave(min(1, p * 1.25), 2)       # llega al tamaño final en el frame 6
    cx = cy = 128
    R = 8 + 50 * e

    def particula(i, ph):
        ang = math.radians(i * 20 + ph * 140)
        d = R + 14 + (1 - ph) * (106 - R)
        x, y = cx + math.cos(ang) * d, cy + math.sin(ang) * d
        x2, y2 = cx + math.cos(ang) * (d + 8 + 10 * (1 - ph)), cy + math.sin(ang) * (d + 8 + 10 * (1 - ph))
        return (f'<path d="M{P(x, y)} L{P(x2, y2)}" stroke="{"#ffd36b" if i % 2 else "#ff7a1a"}" stroke-width="2.6" '
                f'stroke-linecap="round" opacity="{min(1, ph * 1.6) * (1 - max(0, ph - .85) / .15):.2f}"/>')

    def gen(k):
        formas = [circulo_d(cx, cy, R * (1 + .38 * k))]
        for i in range(12):
            a = math.radians(i * 30 + f * 15)
            lon = R * (1.3 + (.4 + .15 * math.sin(f * 1.7 + i * 2.1)) * k) + 6 * k
            formas.append(lengua(cx + R * .8 * math.cos(a), cy + R * .8 * math.sin(a),
                                 cx + lon * math.cos(a + .35), cy + lon * math.sin(a + .35), R * .24 * k + 1))
        return formas

    c = (f'<circle cx="{cx}" cy="{cy}" r="{R * 2.3:.1f}" fill="url(#aura)" opacity="{.6 + .4 * p:.2f}"/>'
         + "".join(particula(i, (i / 18 + f * .17) % 1) for i in range(18))
         + fuego_en_capas(gen, ancho_contorno=4, filtro="brilloFuerte")
         + nucleo_magma(cx, cy, R, rot=9 * f))
    if f >= 6:      # pulso final: está lista para salir disparada
        c += (f'<circle cx="{cx}" cy="{cy}" r="{R * (1.25 + .15 * (f - 6)):.1f}" fill="none" stroke="#fff1b8" '
              f'stroke-width="3" opacity="{.8 - .3 * (f - 6):.2f}" filter="url(#brillo)"/>')
    return svg(256, 256, c)


_r = random.Random(3)
# Nubes de fuego (dx, dy, radio, cuánto suben, fase) colocadas como un hongo:
EXP_BLOBS = ([(math.cos(math.radians(a)) * 95, math.sin(math.radians(a)) * 95, _r.uniform(40, 50), _r.uniform(10, 30), _r.uniform(0, 6))
              for a in range(0, 360, 45)]                                                    # base, a ras de suelo
             + [(0, 0, 50, 60, .5), (-12, 0, 42, 105, 1.5), (12, 0, 42, 115, 2.5)]           # tallo
             + [(dx, 0, r, sube, fase) for dx, r, sube, fase in
                ((-82, 46, 168, 3.1), (-42, 54, 188, 4.2), (0, 60, 200, 5.0), (42, 54, 190, .9), (82, 46, 170, 2.2))])  # sombrero
EXP_HUMO = [(a + _r.uniform(-15, 15), _r.uniform(110, 170), _r.uniform(34, 50), _r.uniform(30, 210)) for a in range(0, 360, 30)]
EXP_CHORROS = [a + _r.uniform(-8, 8) for a in range(0, 360, 36)]
EXP_ESCOMBROS = [(_r.uniform(0, 360), _r.uniform(140, 240), _r.uniform(8, 15), _r.uniform(-2, 2), _r.uniform(90, 170),
                  [(TAU * v / 6 + _r.uniform(-.3, .3), _r.uniform(.7, 1.1)) for v in range(6)]) for _ in range(11)]
EXP_CHISPAS = [(_r.uniform(0, 360), _r.uniform(160, 250), _r.uniform(14, 28)) for _ in range(26)]
EXP_LLAMAS = [(a + _r.uniform(-10, 10), _r.uniform(.45, .9)) for a in range(0, 360, 50)]


def llamita(x, y, h, sem, p):
    """Grupito de 3 lenguas finas que se quedan ardiendo en el suelo."""
    def gen(k):
        return [lengua(x + dx, y, x + dx * 1.5 + 3 * math.sin(sem + p * 9 + dx), y - h * hh * (.4 + .6 * k), w * k,
                       4 * math.sin(sem * 2 + p * 7 + dx) * k)
                for dx, hh, w in ((-5, .7, 3.6), (0, 1.0, 4.6), (5, .6, 3.2))]
    return fuego_en_capas(gen, capas=3, ancho_contorno=3)


def svg_ultimate_explosion(f, N=12):
    p = f / (N - 1)
    e = suave(p, 2.4)
    cx, cy, gy = 256, 300, 330            # centro del estallido y altura del suelo
    out = ""
    # suelo: primero brilla, luego queda quemado
    out += (f'<ellipse cx="{cx}" cy="{gy}" rx="{70 + 170 * e:.1f}" ry="{(70 + 170 * e) * .42:.1f}" fill="url(#sueloArdiente)" opacity="{(1 - p) * .8:.2f}"/>'
            f'<path d="{blob_d(cx, gy, 60 + 90 * e, 1.0, 9, .1, achatar=.42)}" fill="url(#quemadura)" opacity="{min(.8, p * 1.6):.2f}"/>')
    # onda expansiva en el suelo + anillo de polvo
    rx = 40 + 225 * e
    out += (f'<path d="{blob_d(cx, gy, rx * .95, p * 3, 11, .06, achatar=.42)}" fill="none" stroke="#3a2a22" '
            f'stroke-width="{26 * (1 - p) + 2:.1f}" opacity="{min(1, p * 4) * (1 - p) * .6:.2f}" filter="url(#difuso)"/>'
            f'<ellipse cx="{cx}" cy="{gy}" rx="{rx:.1f}" ry="{rx * .42:.1f}" fill="none" stroke="#ffb02a" '
            f'stroke-width="{16 * (1 - p) + 1:.1f}" opacity="{(1 - p) * .95:.2f}" filter="url(#brillo)"/>')
    if p < .4:   # onda en el aire, muy rápida
        ra = 80 + 400 * p          # máximo 240: no se sale del frame
        out += f'<circle cx="{cx}" cy="{cy}" r="{ra:.1f}" fill="none" stroke="#fff4c0" stroke-width="{6 * (1 - p / .4):.1f}" opacity="{(1 - p / .4) * .7:.2f}"/>'
    # humo detrás del fuego
    op_humo = min(1, p * 2.5) * (1 - max(0, (p - .6) / .4)) * .9
    for i, (ang, dist, tam, sube) in enumerate(EXP_HUMO):
        a = math.radians(ang)
        x, y = cx + math.cos(a) * dist * e, cy + math.sin(a) * dist * e * .45 - sube * e
        out += (f'<path d="{blob_d(x, y, tam * (.3 + .9 * e), i + p * 2, 6, .13)}" fill="url(#humo)" '
                f'stroke="#0e0808" stroke-width="2.5" opacity="{op_humo:.2f}"/>')

    # bola de fuego que se expande y sube como una columna
    def gen(k):
        formas = []
        enfria = 1 - .55 * max(0, p - .5) / .5
        for dx, dy, r, sube, fase in EXP_BLOBS:
            x, y = cx + dx * e * 1.15, cy + dy * e * .55 - sube * e
            rr = r * (.45 + .75 * e) * enfria
            # las capas interiores encogen más (k**1.6) para que se vean los núcleos calientes
            formas.append(blob_d(x, y - (1 - k) * rr * .25, rr * k ** 1.6, fase + p * 2.5, 6, .13))
        if p < .6:
            for ang in EXP_CHORROS:
                a = math.radians(ang)
                L = (60 + 150 * e) * (1 - p / .6 * .6) * (.35 + .65 * k)
                formas.append(lengua(cx, gy - 10, cx + math.cos(a) * L, gy - 10 + math.sin(a) * L * .45,
                                     18 * (1 - p / .6) * k + 2, 8 * math.sin(ang) * k))
        return formas

    capas = 4 if p < .25 else 3 if p < .6 else 2 if p < .8 else 1     # se enfría: pierde las capas calientes
    out += fuego_en_capas(gen, capas, 1 if p < .65 else 1 - (p - .65) / .35, ancho_contorno=6, filtro="brilloFuerte")

    # escombros de la costra del meteorito (trayectoria parabólica)
    if p < .95:
        for ang, vel, tam, giro, altura, forma in EXP_ESCOMBROS:
            a = math.radians(ang)
            x = cx + math.cos(a) * vel * e * 1.2
            y = gy - 30 + math.sin(a) * vel * e * .45 - altura * 4 * p * (1 - p)
            g = giro * p * 6
            pts = [P(x + tam * rr * math.cos(b + g), y + tam * rr * math.sin(b + g)) for b, rr in forma]
            dentro = [P(x + tam * .45 * rr * math.cos(b + g), y + tam * .45 * rr * math.sin(b + g)) for b, rr in forma]
            op = 1 - max(0, p - .8) / .15
            out += (f'<path d="M{" L".join(pts)} Z" fill="#2a0a05" stroke="#ff6a1a" stroke-width="1.8" '
                    f'stroke-linejoin="round" opacity="{op:.2f}"/>'
                    f'<path d="M{" L".join(dentro)} Z" fill="#ff8a1a" opacity="{op:.2f}" filter="url(#brillo)"/>')
    # llamas que quedan ardiendo en el suelo
    if p > .62:
        h = 36 * (1 - (p - .62) / .38) + 8
        for i, (ang, dist) in enumerate(EXP_LLAMAS):
            a = math.radians(ang)
            out += llamita(cx + math.cos(a) * 160 * dist, gy + math.sin(a) * 160 * dist * .42, h, i, p)
    if f <= 2:
        out += f'<circle cx="{cx}" cy="{cy}" r="{110 + 60 * f}" fill="url(#destello)" opacity="{[1, .7, .3][f]}"/>'
    if p < .75:
        for ang, vel, largo in EXP_CHISPAS:
            a = math.radians(ang)
            r0 = 20 + vel * e
            r1 = r0 + largo * (1 - p) + 3
            out += (f'<path d="M{P(cx + math.cos(a) * r0, cy + math.sin(a) * r0 * .7)} '
                    f'L{P(cx + math.cos(a) * r1, cy + math.sin(a) * r1 * .7)}" stroke="#ffd36b" '
                    f'stroke-width="{3 * (1 - p) + .5:.1f}" stroke-linecap="round" opacity="{1 - p / .75:.2f}"/>')
    if p > .35:  # brasas flotando al final
        for i in range(14):
            x = cx - 150 + (i * 53) % 300
            y = gy - 20 - ((i * 37) % 60) - (p - .35) * 260
            out += f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{1.5 + (i % 3) * .7:.1f}" fill="#ffb22e" opacity="{(1 - p) * 1.5:.2f}"/>'
    return svg(512, 512, out)


def svg_marca_suelo():
    cx, cy = 192, 96
    out = (f'<path d="{blob_d(cx, cy, 150, 2.0, 11, .08, achatar=.45)}" fill="none" stroke="#6a5648" '
           f'stroke-width="22" opacity=".3" filter="url(#difuso)"/>'                       # anillo de ceniza
           f'<path d="{blob_d(cx, cy, 160, 1.0, 9, .1, achatar=.45)}" fill="url(#quemadura)"/>')
    r = random.Random(11)

    def grieta(x, y, a, largo, ancho):
        """Grieta que se estrecha y a veces se ramifica (recursiva)."""
        s, d = "", 0
        while d < largo:
            paso = r.uniform(12, 20)
            a += r.uniform(-.35, .35)
            x2, y2 = x + math.cos(a) * paso, y + math.sin(a) * paso * .45
            w = ancho * (1 - d / largo) + .5
            seg = f"M{P(x, y)} L{P(x2, y2)}"
            s += (f'<path d="{seg}" stroke="#0a0302" stroke-width="{w * 3:.1f}" stroke-linecap="round" opacity=".8"/>'
                  f'<path d="{seg}" stroke="#ff6a1a" stroke-width="{w:.1f}" stroke-linecap="round" opacity=".8" filter="url(#brillo)"/>')
            if ancho > 1.2 and r.random() < .3:
                s += grieta(x2, y2, a + r.choice((-.8, .8)), (largo - d) * .5, ancho * .5)
            x, y, d = x2, y2, d + paso
        return s

    for i in range(12):
        out += grieta(cx, cy, TAU * i / 12 + r.uniform(-.2, .2), r.uniform(85, 135), 2.4)
    out += f'<ellipse cx="{cx}" cy="{cy}" rx="34" ry="15" fill="#ff5a14" opacity=".35" filter="url(#difuso)"/>'
    for i in range(10):
        a, d = r.uniform(0, TAU), r.uniform(20, 130)
        out += f'<circle cx="{cx + math.cos(a) * d:.1f}" cy="{cy + math.sin(a) * d * .45:.1f}" r="{r.uniform(1, 2.2):.1f}" fill="#ff8a1a" opacity="{r.uniform(.4, .9):.2f}"/>'
    return svg(384, 192, out)


# ========================================================== GENERACIÓN ===
def generar():
    os.makedirs(f"{RAIZ}/svg", exist_ok=True)
    os.makedirs(TMP, exist_ok=True)
    r = {}
    r["bola_vuelo"] = [render(svg_bola_vuelo(f), f"bola_fuego_vuelo_{f}", 128, 64) for f in range(6)]
    r["bola_impacto"] = [render(svg_bola_impacto(f), f"bola_fuego_impacto_{f}", 128, 128) for f in range(8)]
    r["ult_carga"] = [render(svg_ultimate_carga(f), f"ultimate_carga_{f}", 256, 256) for f in range(8)]
    r["ult_vuelo"] = [render(svg_ultimate_vuelo(f), f"ultimate_vuelo_{f}", 512, 256) for f in range(6)]
    r["ult_explosion"] = [render(svg_ultimate_explosion(f), f"ultimate_explosion_{f}", 512, 512) for f in range(12)]
    r["marca"] = render(svg_marca_suelo(), "ultimate_marca_suelo", 384, 192)

    hoja(r["bola_vuelo"], 6).save(f"{RAIZ}/bola_fuego_vuelo.png")
    hoja(r["bola_impacto"], 8).save(f"{RAIZ}/bola_fuego_impacto.png")
    hoja(r["ult_carga"], 4).save(f"{RAIZ}/ultimate_carga.png")
    hoja(r["ult_vuelo"], 3).save(f"{RAIZ}/ultimate_vuelo.png")
    hoja(r["ult_explosion"], 4).save(f"{RAIZ}/ultimate_explosion.png")
    r["marca"].save(f"{RAIZ}/ultimate_marca_suelo.png")
    return r


if __name__ == "__main__":
    generar()
    print("ok")
