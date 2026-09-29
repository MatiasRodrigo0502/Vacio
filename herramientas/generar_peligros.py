# -*- coding: utf-8 -*-
"""Genera el arte de la lava, los pinchos y el vacio en assets/peligros/.

Mismo estilo que los packs del manto y del nucleo: volumen suave con luz desde
arriba a la izquierda, contorno oscuro y brillo incandescente. Se dibuja al
doble de tamano y se reduce al final, que es lo que suaviza los bordes.

Solo usa PIL (no hay numpy en las maquinas del equipo) y semillas fijas: volver
a ejecutarlo da exactamente los mismos PNG.

    python herramientas/generar_peligros.py

OJO: la colocacion de los agujeros de los pinchos (MARGEN, GROSOR, FILAS y el
tamano del agujero) la repite scripts/pinchos.gd para sacar cada pincho por su
agujero. Si se cambia aqui, se cambia alli.
"""
import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter

RAIZ = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SALIDA = os.path.join(RAIZ, "assets", "peligros")
SUPER = 2  # se dibuja al doble y se reduce


# --- Ruido --------------------------------------------------------------------

def _hash(x, y, semilla):
    n = (x * 374761393 + y * 668265263 + semilla * 1442695041) & 0xFFFFFFFF
    n = ((n ^ (n >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 0xFFFF) / 65535.0


def ruido(x, y, semilla):
    """Ruido de valor suavizado, de 0 a 1."""
    xi, yi = math.floor(x), math.floor(y)
    fx, fy = x - xi, y - yi
    fx = fx * fx * (3 - 2 * fx)
    fy = fy * fy * (3 - 2 * fy)
    a = _hash(xi, yi, semilla)
    b = _hash(xi + 1, yi, semilla)
    c = _hash(xi, yi + 1, semilla)
    d = _hash(xi + 1, yi + 1, semilla)
    return a + (b - a) * fx + (c - a) * fy + (a - b - c + d) * fx * fy


def fbm(x, y, semilla, octavas=3):
    total, amplitud, suma = 0.0, 1.0, 0.0
    for o in range(octavas):
        total += ruido(x, y, semilla + o * 17) * amplitud
        suma += amplitud
        x, y, amplitud = x * 2.03, y * 2.03, amplitud * 0.5
    return total / suma


def mezclar(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(len(a)))


def rampa(paradas, t):
    """Color a lo largo de una rampa [(t, color), ...]."""
    t = max(0.0, min(1.0, t))
    for i in range(len(paradas) - 1):
        t0, c0 = paradas[i]
        t1, c1 = paradas[i + 1]
        if t <= t1:
            return mezclar(c0, c1, (t - t0) / (t1 - t0))
    return paradas[-1][1]


def a_bytes(color):
    return tuple(int(max(0, min(255, round(c)))) for c in color)


# --- Lava ---------------------------------------------------------------------

# Colores de la roca: los del manto, para que el borde sea de la misma piedra.
ROCA_ARRIBA = (82, 70, 86)
ROCA_ABAJO = (30, 25, 34)
CONTORNO = (16, 10, 13)
# Lava de fria a caliente.
LAVA = [(0.0, (150, 30, 10)), (0.35, (225, 80, 16)), (0.7, (250, 150, 35)), (1.0, (255, 232, 140))]
COSTRA = (58, 24, 20)
COSTRA_LUZ = (96, 44, 30)
GRIETA = (255, 214, 110)
# Radio del charco dentro del lienzo. Lo de fuera es el resplandor sobre el
# suelo. lava.gd lo usa para escalar la textura al radio del charco.
RADIO_CHARCO = 0.78


def generar_lava(semilla, lado_final=192):
    lado = lado_final * SUPER
    centro = lado / 2.0
    radio = RADIO_CHARCO * lado / 2.0
    aleatorio = random.Random(semilla)
    fases = [aleatorio.uniform(0, math.tau) for _ in range(4)]

    # Placas de costra flotando: puntos de Voronoi dentro del charco. Ninguna en
    # el centro, que es lo mas caliente.
    puntos = []
    while len(puntos) < 17:
        angulo = aleatorio.uniform(0, math.tau)
        distancia = math.sqrt(aleatorio.uniform(0.04, 0.6)) * radio
        puntos.append((centro + math.cos(angulo) * distancia,
                       centro + math.sin(angulo) * distancia,
                       aleatorio.random()))

    color = Image.new("RGBA", (lado, lado), (0, 0, 0, 0))
    calor = Image.new("L", (lado, lado), 0)
    pc, pk = color.load(), calor.load()
    luz = (-0.55, -0.83)

    for y in range(lado):
        for x in range(lado):
            dx, dy = x - centro, y - centro
            angulo = math.atan2(dy, dx)
            borde = (1.0 + 0.07 * math.sin(3 * angulo + fases[0])
                     + 0.045 * math.sin(5 * angulo + fases[1])
                     + 0.025 * math.sin(9 * angulo + fases[2]))
            r = math.hypot(dx, dy) / (radio * borde)
            if r > 1.035:
                # Resplandor de la lava sobre el suelo.
                fuera = (r - 1.035) / 0.24
                if fuera < 1.0:
                    alfa = (1.0 - fuera) ** 2 * 110
                    pc[x, y] = (255, 110, 30, int(alfa))
                    pk[x, y] = int((1.0 - fuera) ** 2 * 90)
                continue
            if r > 1.0:
                pc[x, y] = CONTORNO + (255,)
                continue

            radial = (dx / max(math.hypot(dx, dy), 1e-6), dy / max(math.hypot(dx, dy), 1e-6))
            interior = 0.78 + 0.05 * math.sin(4 * angulo + fases[3]) \
                + 0.05 * (fbm(x * 0.03, y * 0.03, semilla + 5) - 0.5)
            if r > interior:
                # Borde de basalto: un reborde. Por fuera mira hacia fuera y por
                # dentro hacia dentro, y la luz de arriba ilumina la cara que le
                # toca: asi se lee como un labio de roca y no como una raya.
                medio = (interior + 1.0) / 2.0
                normal = radial if r > medio else (-radial[0], -radial[1])
                sombra = 0.72 + 0.38 * (normal[0] * luz[0] + normal[1] * luz[1])
                base = mezclar(ROCA_ARRIBA, ROCA_ABAJO, y / lado)
                grano = 0.85 + 0.3 * fbm(x * 0.09, y * 0.09, semilla + 9)
                c = tuple(v * sombra * grano for v in base)
                # El labio de dentro recibe la luz de la lava.
                cerca = 1.0 - (r - interior) / 0.07
                if cerca > 0:
                    c = mezclar(c, (255, 120, 40), cerca * 0.75)
                    pk[x, y] = int(cerca * 110)
                pc[x, y] = a_bytes(c) + (255,)
                continue

            # Lava. El calor sube hacia el centro, con manchas.
            mancha = fbm(x * 0.022, y * 0.022, semilla + 1)
            caliente = 1.0 - r / interior * 0.85 + (mancha - 0.5) * 0.7
            c = rampa(LAVA, caliente)
            h = 0.6 + 0.4 * max(0.0, min(1.0, caliente))

            # Costra: la celda de Voronoi mas cercana, y lo cerca que esta la
            # frontera con la siguiente (la grieta).
            d1, d2, celda = 1e9, 1e9, None
            for px, py, azar in puntos:
                d = (x - px) ** 2 + (y - py) ** 2
                if d < d1:
                    d2, d1, celda = d1, d, (px, py, azar)
                elif d < d2:
                    d2 = d
            frontera = math.sqrt(d2) - math.sqrt(d1)
            es_costra = celda[2] < 0.55 and math.hypot(celda[0] - centro, celda[1] - centro) > radio * 0.25
            ancho_grieta = 2.6 * SUPER
            if es_costra and frontera > ancho_grieta:
                # Placa de costra: al rojo en el borde y enfriandose hacia
                # dentro, que es como se ve la lava que empieza a solidificar.
                # Encima, un poco de luz de arriba a la izquierda para que
                # tenga volumen.
                hacia_dentro = (frontera - ancho_grieta) / (7.0 * SUPER)
                placa = mezclar((190, 62, 18), COSTRA, hacia_dentro ** 0.7)
                hacia = ((celda[0] - x), (celda[1] - y))
                largo = max(math.hypot(*hacia), 1e-6)
                luz_canto = -(hacia[0] / largo * luz[0] + hacia[1] / largo * luz[1])
                if hacia_dentro > 0.35:
                    placa = mezclar(placa, COSTRA_LUZ, max(0.0, luz_canto) * 0.5)
                placa = tuple(v * (0.85 + 0.3 * fbm(x * 0.12, y * 0.12, semilla + 3)) for v in placa)
                c = placa
                h = max(0.08, 0.7 * (1.0 - min(1.0, hacia_dentro)))
            elif es_costra:
                # Grieta entre placas: lo mas brillante de la lava.
                c = mezclar(GRIETA, c, frontera / ancho_grieta)
                h = 1.0
            pc[x, y] = a_bytes(c) + (255,)
            pk[x, y] = int(h * 255)

    final = color.resize((lado_final, lado_final), Image.LANCZOS)
    mascara = calor.resize((lado_final, lado_final), Image.LANCZOS).filter(ImageFilter.GaussianBlur(0.6))
    return final, mascara


# --- Pinchos ------------------------------------------------------------------

# Geometria de la placa, en fraccion del lado. La repite pinchos.gd.
MARGEN = 0.05      # hueco entre el borde del lienzo y la placa
GROSOR = 0.08      # canto frontal de la placa (su grosor, visto en 3/4)
FILAS = 3
AGUJERO_ANCHO = 0.26  # semieje del agujero, en fraccion de la celda
AGUJERO_ALTO = 0.52   # alto del agujero respecto a su ancho: visto en 3/4

METAL_ARRIBA = (104, 98, 104)
METAL_ABAJO = (64, 60, 66)
CANTO_ARRIBA = (46, 42, 48)
CANTO_ABAJO = (24, 21, 26)


def _agujeros(lado):
    m = MARGEN * lado
    ancho = lado - 2 * m
    alto = lado - 2 * m - GROSOR * lado
    celda_x, celda_y = ancho / FILAS, alto / FILAS
    a = celda_x * AGUJERO_ANCHO
    b = a * AGUJERO_ALTO
    for fila in range(FILAS):
        for columna in range(FILAS):
            yield (fila, m + (columna + 0.5) * celda_x, m + (fila + 0.5) * celda_y, a, b)


def generar_pinchos_base(lado_final=128):
    lado = lado_final * SUPER
    m = MARGEN * lado
    grosor = GROSOR * lado
    radio_esquina = 0.07 * lado
    cara_abajo = lado - m - grosor

    placa = Image.new("RGBA", (lado, lado), (0, 0, 0, 0))
    dibujo = ImageDraw.Draw(placa)
    # Contorno y canto frontal, y encima la cara de arriba.
    dibujo.rounded_rectangle((m - 3, m - 3, lado - m + 3, lado - m + 3), radio_esquina + 3, fill=CONTORNO + (255,))
    dibujo.rounded_rectangle((m, m, lado - m, lado - m), radio_esquina, fill=(255, 0, 255, 255))
    dibujo.rounded_rectangle((m, m, lado - m, cara_abajo), radio_esquina, fill=(0, 255, 0, 255))
    pp = placa.load()
    for y in range(lado):
        for x in range(lado):
            r, g, b, a = pp[x, y]
            if (r, g, b) == (255, 0, 255):
                t = (y - cara_abajo) / grosor
                c = mezclar(CANTO_ARRIBA, CANTO_ABAJO, t)
                pp[x, y] = a_bytes(c) + (255,)
            elif (r, g, b) == (0, 255, 0):
                t = (y - m) / (cara_abajo - m)
                c = mezclar(METAL_ARRIBA, METAL_ABAJO, t)
                grano = 0.88 + 0.24 * fbm(x * 0.05, y * 0.35, 41)  # cepillado horizontal
                c = tuple(v * grano for v in c)
                pp[x, y] = a_bytes(c) + (255,)
    # Biseles: filo de arriba y de la izquierda iluminado, el de la derecha en
    # sombra, y una linea de luz donde la cara se dobla hacia el canto.
    dibujo.line((m + radio_esquina, m + 2, lado - m - radio_esquina, m + 2), fill=(168, 160, 166, 255), width=3)
    dibujo.line((m + 2, m + radio_esquina, m + 2, cara_abajo - radio_esquina), fill=(140, 132, 138, 255), width=3)
    dibujo.line((lado - m - 2, m + radio_esquina, lado - m - 2, cara_abajo - radio_esquina), fill=(44, 40, 46, 255), width=3)
    dibujo.line((m + radio_esquina, cara_abajo, lado - m - radio_esquina, cara_abajo), fill=(130, 122, 128, 255), width=2)
    # Remaches en las esquinas.
    for rx, ry in ((m + 0.06 * lado, m + 0.06 * lado), (lado - m - 0.06 * lado, m + 0.06 * lado),
                   (m + 0.06 * lado, cara_abajo - 0.05 * lado), (lado - m - 0.06 * lado, cara_abajo - 0.05 * lado)):
        rr = 0.022 * lado
        dibujo.ellipse((rx - rr, ry - rr + 1.5, rx + rr, ry + rr + 1.5), fill=(30, 27, 32, 255))
        dibujo.ellipse((rx - rr, ry - rr, rx + rr, ry + rr), fill=(150, 144, 150, 255))
        dibujo.ellipse((rx - rr * 0.45, ry - rr * 0.55, rx + rr * 0.1, ry), fill=(210, 205, 210, 255))

    frente = Image.new("RGBA", (lado, lado), (0, 0, 0, 0))
    dibujo_frente = ImageDraw.Draw(frente)
    for _fila, cx, cy, a, b in _agujeros(lado):
        # Sombra alrededor del agujero, el hueco negro, y la pared de dentro
        # (la de arriba se ve, la de abajo no: vista en 3/4).
        dibujo.ellipse((cx - a - 3, cy - b - 3, cx + a + 3, cy + b + 4), fill=(40, 36, 42, 255))
        dibujo.ellipse((cx - a, cy - b, cx + a, cy + b), fill=(8, 6, 8, 255))
        dibujo.chord((cx - a, cy - b, cx + a, cy + b), 180, 360, fill=(30, 27, 32, 255))
        dibujo.ellipse((cx - a * 0.9, cy - b * 0.35, cx + a * 0.9, cy + b * 0.95), fill=(6, 4, 6, 255))
        # El labio de delante: la mitad de abajo del agujero con su filo de
        # luz. Va aparte (pinchos_frente.png) porque se pinta ENCIMA del
        # pincho: asi el pincho sale de dentro del agujero y no de encima.
        dibujo_frente.chord((cx - a, cy - b * 0.15, cx + a, cy + b), 0, 180, fill=(6, 4, 6, 255))
        dibujo_frente.arc((cx - a, cy - b, cx + a, cy + b + 1), 20, 160, fill=(176, 168, 174, 255), width=3)

    return (placa.resize((lado_final, lado_final), Image.LANCZOS),
            frente.resize((lado_final, lado_final), Image.LANCZOS))


def generar_pincho(ancho_final=32, alto_final=80):
    """Un pincho de acero, en 3/4: cono con la luz desde la izquierda."""
    ancho, alto = ancho_final * SUPER, alto_final * SUPER
    imagen = Image.new("RGBA", (ancho, alto), (0, 0, 0, 0))
    pixeles = imagen.load()
    cx = ancho / 2.0
    punta, base = 3.0 * SUPER, alto - 5.0 * SUPER
    semiancho = ancho / 2.0 - 2.5 * SUPER
    oscuro, claro = (40, 42, 52), (226, 229, 238)
    for y in range(alto):
        if y < punta:
            continue
        t = min((y - punta) / (base - punta), 1.0)
        w = semiancho * t ** 0.95
        # La base del cono es una elipse: redondea el pie del pincho.
        if y > base:
            e = (y - base) / (alto - base - SUPER)
            if e >= 1.0:
                continue
            w = semiancho * math.sqrt(max(0.0, 1.0 - e * e))
        for x in range(ancho):
            u = (x + 0.5 - cx) / max(w, 0.5)
            if abs(u) > 1.0 + 0.9 / max(w, 0.5):
                continue
            if abs(u) > 1.0:
                pixeles[x, y] = CONTORNO + (255,)
                continue
            luz = 0.52 - 0.42 * u + 0.22 * (1.0 - u * u)
            c = mezclar(oscuro, claro, luz)
            # Brillo del metal: una franja estrecha en el lado iluminado.
            brillo = math.exp(-((u + 0.42) / 0.12) ** 2)
            c = mezclar(c, (255, 255, 255), brillo * 0.7)
            # El pie, en sombra: esta metido en el agujero.
            if t > 0.8:
                c = mezclar(c, (20, 18, 24), (t - 0.8) / 0.2 * 0.6)
            pixeles[x, y] = a_bytes(c) + (255,)
    return imagen.resize((ancho_final, alto_final), Image.LANCZOS)


# --- Vacio --------------------------------------------------------------------

# Medidas del agujero, en pixeles de la textura final. Se pinta en nueve trozos
# (StyleBoxTexture): las esquinas y los bordes no se estiran, solo el centro.
# Asi un agujero grande y uno pequeno tienen el mismo reborde. Los MARGENES
# los repite scripts/vacio.gd; si se cambian aqui, alli tambien.
VACIO_LADO = 160
VACIO_LABIO = 8          # reborde que queda por FUERA del agujero
VACIO_MARGEN_ARRIBA = 48  # incluye la pared del fondo, que se ve en 3/4
VACIO_MARGEN_LADOS = 24
VACIO_MARGEN_ABAJO = 22


def generar_vacio(semilla=5):
    """El agujero: negro por dentro, con la pared del fondo a la vista (vista
    en 3/4) y rodeado de piedras sueltas, que es lo que queda del suelo que se
    hundio. Las piedras son las que le quitan el aire de marco de cuadro que
    tenia con un reborde liso."""
    lado = VACIO_LADO * SUPER
    labio = VACIO_LABIO * SUPER
    pared = (VACIO_MARGEN_ARRIBA - 6) * SUPER   # donde la pared del fondo ya es negra
    lado_pared = (VACIO_MARGEN_LADOS - 4) * SUPER
    imagen = Image.new("RGBA", (lado, lado), (0, 0, 0, 0))
    pixeles = imagen.load()
    aleatorio = random.Random(semilla)

    # Piedras repartidas por el reborde, con tamanos y sitios algo al azar.
    piedras = []
    # La linea de piedras va por el filo del agujero, lo bastante dentro del
    # lienzo para que ninguna piedra quede cortada por el borde de la imagen:
    # cortadas, el contorno salia recto y el agujero parecia una caja.
    borde = labio * 0.95
    paso = 7.5 * SUPER
    tramos = [((borde, borde), (lado - borde, borde)), ((lado - borde, borde), (lado - borde, lado - borde)),
              ((lado - borde, lado - borde), (borde, lado - borde)), ((borde, lado - borde), (borde, borde))]
    for (x0, y0), (x1, y1) in tramos:
        largo = math.hypot(x1 - x0, y1 - y0)
        n = int(largo / paso)
        for i in range(n):
            t = (i + aleatorio.uniform(0.1, 0.9)) / n
            px = x0 + (x1 - x0) * t + aleatorio.uniform(-1.5, 1.5) * SUPER
            py = y0 + (y1 - y0) * t + aleatorio.uniform(-1.5, 1.5) * SUPER
            # Cada piedra con su tono: todas iguales parecerian adoquines.
            piedras.append((px, py, aleatorio.uniform(4.5, 6.2) * SUPER, aleatorio.uniform(0.8, 1.12)))

    luz = (-0.45, -0.65, 0.6)
    largo_luz = math.sqrt(sum(v * v for v in luz))
    luz = tuple(v / largo_luz for v in luz)
    negro = (5, 3, 6)

    for y in range(lado):
        for x in range(lado):
            # El agujero, con el filo algo roto.
            roto = (fbm(x * 0.05, y * 0.05, semilla) - 0.5) * 3.0 * SUPER
            dentro_x = min(x, lado - 1 - x) - labio + roto
            dentro_y_arriba = y - labio + roto
            dentro_y_abajo = (lado - 1 - y) - labio + roto
            dentro = min(dentro_x, dentro_y_arriba, dentro_y_abajo)

            c = None
            if dentro >= 0:
                c = negro
                if dentro_y_arriba < pared and dentro_y_arriba <= dentro_x + pared * 0.4:
                    # Pared del fondo: vetas de roca que se pierden en lo negro.
                    t = dentro_y_arriba / pared
                    veta = 0.75 + 0.5 * fbm(x * 0.012, y * 0.22, semilla + 7)
                    grieta = fbm(x * 0.05, y * 0.05, semilla + 8)
                    # Mas clara que la roca de fuera: le da la luz de arriba de
                    # lleno. Con el tinte de los pisos hondos, si fuera igual de
                    # oscura no se veria, y es la pared la que dice "hondo".
                    pared_color = tuple(v * veta for v in mezclar((128, 112, 126), (40, 32, 42), t * 0.8))
                    if 0.47 < grieta < 0.5:
                        pared_color = tuple(v * 0.45 for v in pared_color)
                    c = mezclar(pared_color, negro, t ** 1.3)
                elif dentro_x < lado_pared:
                    t = dentro_x / lado_pared
                    lateral = mezclar((70, 60, 72), negro, 0.2 + 0.8 * t)
                    c = mezclar(lateral, negro, max(0.0, min(1.0, (y - labio - pared) / (lado * 0.3))))
                if dentro_y_abajo < 6 * SUPER:
                    c = mezclar(c, (0, 0, 0), 1.0 - dentro_y_abajo / (6 * SUPER))

            # Las piedras del reborde, encima. La mas cercana manda; entre dos
            # piedras queda una junta oscura.
            if dentro < 9 * SUPER:
                d1, d2, cerca = 1e9, 1e9, None
                for piedra in piedras:
                    d = math.hypot(x - piedra[0], y - piedra[1])
                    if d < d1:
                        d2, d1, cerca = d1, d, piedra
                    elif d < d2:
                        d2 = d
                if cerca is not None and d1 < cerca[2]:
                    if d1 > cerca[2] - 1.3 * SUPER or d2 - d1 < 1.2 * SUPER:
                        c = CONTORNO
                    else:
                        # Cada piedra, abombada y con la luz de arriba a la
                        # izquierda: asi se leen como bultos y no como manchas.
                        nx = (x - cerca[0]) / cerca[2]
                        ny = (y - cerca[1]) / cerca[2]
                        nz = math.sqrt(max(0.0, 1.0 - nx * nx - ny * ny))
                        brillo = nx * luz[0] + ny * luz[1] + nz * luz[2]
                        base = mezclar(ROCA_ABAJO, ROCA_ARRIBA, 0.25 + 0.75 * brillo)
                        grano = 0.88 + 0.24 * fbm(x * 0.12, y * 0.12, semilla + 4)
                        c = tuple(v * grano * cerca[3] for v in base)

            if c is not None:
                pixeles[x, y] = a_bytes(c) + (255,)

    return imagen.resize((VACIO_LADO, VACIO_LADO), Image.LANCZOS)


def main():
    os.makedirs(SALIDA, exist_ok=True)
    for n, semilla in enumerate((7, 29, 83)):
        color, calor = generar_lava(semilla)
        color.save(os.path.join(SALIDA, "lava_%02d.png" % n))
        calor.save(os.path.join(SALIDA, "lava_%02d_calor.png" % n))
        print("lava_%02d" % n)
    base, frente = generar_pinchos_base()
    base.save(os.path.join(SALIDA, "pinchos_base.png"))
    frente.save(os.path.join(SALIDA, "pinchos_frente.png"))
    generar_pincho().save(os.path.join(SALIDA, "pincho.png"))
    print("pinchos")
    generar_vacio().save(os.path.join(SALIDA, "vacio.png"))
    print("vacio")


if __name__ == "__main__":
    main()
