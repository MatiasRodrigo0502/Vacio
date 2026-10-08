# -*- coding: utf-8 -*-
"""Genera el borde de las salas, distinto en cada piso, en assets/bordes/.

Cada piso es una capa de la Tierra y su pared es de su roca: tierra con
hierba arriba del todo, basalto mojado en la corteza oceanica, caliza con
estalactitas, el manto con olivino y ringwoodita, la capa D'' con lava y el
nucleo de hierro, primero fundido y al final cristal al rojo blanco.

Por piso, en assets/bordes/piso_NN/:
- muro.png: la roca de la pared vista desde arriba. Se repite sin costuras.
- cara.png: la cara vertical de la pared de arriba, que en vista 3/4 se ve
  de frente. Se repite en horizontal.
- pilar.png: el pilar de cada lado de las puertas.
- adorno_K.png: lo que crece o asoma encima de la pared.
- colgante_K.png: lo que cuelga de la cara de la pared de arriba.
- saliente_K.png: piezas grandes que salen de la pared hacia la sala. Chocan.
- estilo_borde.tres: el recurso que lo junta todo para el juego (EstiloBorde).

Comun a todos: reja.png, el rastrillo de las puertas.

Mismo estilo que el resto del arte: volumen con luz de arriba a la izquierda
y contorno oscuro. Aqui ya va el color de cada piso: el juego no lo tine.

Solo PIL y semillas fijas: volver a ejecutarlo da los mismos archivos. Para
cambiar el borde de un piso, se cambia su tema en TEMAS y se vuelve a
ejecutar. El .tres tambien sale de aqui: lo que se toque a mano en el se
pierde al regenerar.

    python herramientas/generar_bordes.py          (todos los pisos)
    python herramientas/generar_bordes.py 3 7      (solo los pisos 3 y 7)
"""
import math
import os
import random
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageStat

RAIZ = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SALIDA = os.path.join(RAIZ, "assets", "bordes")
# Las piezas sueltas se dibujan a 4x y se reducen: asi salen suaves.
E = 4
CONTORNO_BASE = (14, 10, 12)
LUZ = (-0.45, -0.65, 0.6)
_l = math.sqrt(sum(v * v for v in LUZ))
LUZ = tuple(v / _l for v in LUZ)
LADO_MURO = 256
ANCHO_CARA, ALTO_CARA = 256, 64


# --- Utilidades -----------------------------------------------------------------

def _hash(x, y, semilla):
    n = (x * 374761393 + y * 668265263 + semilla * 1442695041) & 0xFFFFFFFF
    n = ((n ^ (n >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 0xFFFF) / 65535.0


def ruido(x, y, periodo_x, periodo_y, semilla):
    """Ruido de valor que se repite cada 'periodo' celdas (en y, si periodo_y
    es 0, no se repite)."""
    xi, yi = math.floor(x), math.floor(y)
    fx, fy = x - xi, y - yi
    fx = fx * fx * (3 - 2 * fx)
    fy = fy * fy * (3 - 2 * fy)
    x0, x1 = xi % periodo_x, (xi + 1) % periodo_x
    y0, y1 = (yi % periodo_y, (yi + 1) % periodo_y) if periodo_y else (yi, yi + 1)
    a = _hash(x0, y0, semilla)
    b = _hash(x1, y0, semilla)
    c = _hash(x0, y1, semilla)
    d = _hash(x1, y1, semilla)
    return a + (b - a) * fx + (c - a) * fy + (a - b - c + d) * fx * fy


def fbm(x, y, periodo_x, periodo_y, semilla, octavas=3):
    total, amplitud, suma = 0.0, 1.0, 0.0
    for o in range(octavas):
        total += ruido(x, y, periodo_x, periodo_y, semilla + o * 17) * amplitud
        suma += amplitud
        x, y, amplitud = x * 2, y * 2, amplitud * 0.5
        periodo_x *= 2
        periodo_y *= 2
    return total / suma


def mezclar(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def rampa(paleta, t):
    """Color en una rampa oscuro -> medio -> claro, con t de 0 a 1."""
    t = max(0.0, min(1.0, t))
    if t < 0.5:
        return mezclar(paleta[0], paleta[1], t * 2)
    return mezclar(paleta[1], paleta[2], (t - 0.5) * 2)


def a_bytes(color):
    return tuple(int(max(0, min(255, round(c)))) for c in color[:3])


def suave(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def plano(tamano, color):
    return Image.new("RGB", tamano, a_bytes(color))


def con_alfa(mascara, factor):
    return mascara.point(lambda v: int(min(255, v * factor)))


def desplazar(mascara, dx, dy):
    """Desplaza sin dar la vuelta (ImageChops.offset envuelve los bordes)."""
    fuera = Image.new(mascara.mode, mascara.size, 0)
    fuera.paste(mascara, (int(dx), int(dy)))
    return fuera


def degradado(tamano, arriba, abajo, y0, y1):
    ancho, alto = tamano
    columna = Image.new("RGB", (1, alto))
    px = columna.load()
    for y in range(alto):
        px[0, y] = a_bytes(mezclar(arriba, abajo, (y - y0) / max(1.0, float(y1 - y0))))
    return columna.resize((ancho, alto))


def degradado_h(tamano, izquierda, derecha, x0, x1):
    ancho, alto = tamano
    fila = Image.new("RGB", (ancho, 1))
    px = fila.load()
    for x in range(ancho):
        px[x, 0] = a_bytes(mezclar(izquierda, derecha, (x - x0) / max(1.0, float(x1 - x0))))
    return fila.resize((ancho, alto))


def volumen(mascara, paleta, generador, motas=True):
    """Pinta una pieza con volumen sobre su mascara: degradado de arriba a
    abajo, canto de arriba a la izquierda con luz y el de abajo a la derecha en
    sombra. Devuelve RGB del tamano de la mascara."""
    caja = mascara.getbbox()
    color = degradado(mascara.size, paleta[2], paleta[0], caja[1], caja[3])
    color = Image.blend(color, degradado(mascara.size, paleta[1], paleta[0], caja[1], caja[3]), 0.5)
    filo = ImageChops.subtract(mascara, desplazar(mascara, E * 3, E * 4))
    filo = filo.filter(ImageFilter.GaussianBlur(E * 1.5))
    color = Image.composite(plano(mascara.size, paleta[2]), color, con_alfa(filo, 0.7))
    fondo = ImageChops.subtract(mascara, desplazar(mascara, -E * 3, -E * 5))
    fondo = fondo.filter(ImageFilter.GaussianBlur(E * 2))
    color = Image.composite(plano(mascara.size, paleta[0]), color, con_alfa(fondo, 0.7))
    if motas:
        oscuras = Image.new("L", mascara.size, 0)
        claras = Image.new("L", mascara.size, 0)
        d_o, d_c = ImageDraw.Draw(oscuras), ImageDraw.Draw(claras)
        for _ in range(int(mascara.width * mascara.height / (E * E * 500))):
            x = generador.uniform(caja[0], caja[2])
            y = generador.uniform(caja[1], caja[3])
            r = generador.uniform(1.0, 3.0) * E
            (d_c if generador.random() < 0.35 else d_o).ellipse((x - r * 1.5, y - r, x + r * 1.5, y + r), fill=255)
        oscuras = ImageChops.multiply(oscuras.filter(ImageFilter.GaussianBlur(E)), mascara)
        claras = ImageChops.multiply(claras.filter(ImageFilter.GaussianBlur(E)), mascara)
        color = Image.composite(plano(mascara.size, paleta[0]), color, con_alfa(oscuras, 0.3))
        color = Image.composite(plano(mascara.size, paleta[2]), color, con_alfa(claras, 0.15))
    return color


def cerrar(color, mascara, contorno=CONTORNO_BASE, grosor=2):
    """Contorno oscuro por fuera y el alfa de la pieza. RGBA."""
    grande = mascara.filter(ImageFilter.MaxFilter(E * grosor + 1)) if grosor > 0 else mascara
    color = Image.composite(color, plano(mascara.size, contorno), mascara)
    pieza = color.convert("RGBA")
    pieza.putalpha(grande)
    return pieza


def halo(pieza, mascara, color, radio, fuerza):
    """Resplandor alrededor de una pieza: lo que brilla tine el aire de su
    color. Va por debajo de la pieza.

    Se agranda el lienzo antes: si la pieza llega al borde, el resplandor se
    cortaba en recto y se veia la caja de la imagen."""
    margen = int(radio * 3)
    grande = Image.new("RGBA", (pieza.width + margen * 2, pieza.height + margen * 2), (0, 0, 0, 0))
    grande.paste(pieza, (margen, margen))
    pieza = grande
    m = Image.new("L", pieza.size, 0)
    m.paste(mascara, (margen, margen))
    mascara = m
    luz = mascara.filter(ImageFilter.GaussianBlur(radio))
    luz = con_alfa(luz, fuerza)
    fondo = Image.new("RGBA", pieza.size, a_bytes(color) + (0,))
    fondo.putalpha(luz)
    return Image.alpha_composite(fondo, pieza)


def reducir(pieza, margen=2):
    """De 4x a tamano real, recortada a su contenido."""
    pequena = pieza.resize((pieza.width // E, pieza.height // E), Image.LANCZOS)
    caja = pequena.getchannel("A").point(lambda v: 255 if v > 6 else 0).getbbox()
    if caja is None:
        return pequena
    caja = (max(0, caja[0] - margen), max(0, caja[1] - margen),
            min(pequena.width, caja[2] + margen), min(pequena.height, caja[3] + margen))
    return pequena.crop(caja)


def vetas(mascara, generador, cuantas, largo_min, largo_max, grosor=2.2):
    """Grietas: caminos al azar dentro de la pieza, lejos del borde."""
    capa = Image.new("L", mascara.size, 0)
    dibujo = ImageDraw.Draw(capa)
    dentro = mascara.filter(ImageFilter.MinFilter(E * 4 + 1))
    caja = dentro.getbbox()
    if caja is None:
        return capa
    px = dentro.load()
    for _ in range(cuantas):
        for _intento in range(40):
            x = generador.uniform(caja[0], caja[2])
            y = generador.uniform(caja[1], caja[3])
            if px[int(x), int(y)] > 200:
                break
        else:
            continue
        angulo = generador.uniform(0, math.tau)
        puntos = [(x, y)]
        for _paso in range(generador.randint(largo_min, largo_max)):
            angulo += generador.uniform(-0.9, 0.9)
            x += math.cos(angulo) * E * 3
            y += math.sin(angulo) * E * 3
            if not (0 <= x < mascara.width and 0 <= y < mascara.height) or px[int(x), int(y)] < 200:
                break
            puntos.append((x, y))
        if len(puntos) > 1:
            dibujo.line(puntos, fill=255, width=int(E * grosor), joint="curve")
    return ImageChops.multiply(capa, dentro)


def con_vetas_brillantes(color, mascara, generador, brillo, cuantas):
    """Grietas incandescentes: halo de su color y el hilo casi blanco."""
    grietas = vetas(mascara, generador, cuantas, 4, 10)
    resplandor = grietas.filter(ImageFilter.GaussianBlur(E * 2.5))
    color = Image.composite(plano(mascara.size, brillo), color,
                            con_alfa(resplandor, 1.8))
    nucleo = mezclar(brillo, (255, 250, 230), 0.6)
    return Image.composite(plano(mascara.size, nucleo), color, grietas)


# --- Texturas de la pared ------------------------------------------------------

def a_luz(imagen, objetivo):
    """Lleva la luminosidad media de una textura a 'objetivo' (0-1).

    POR QUE: cada tema tiene su paleta, y sin esto unas paredes salian casi
    blancas (la caliza, el oro del nucleo) y otras casi negras. La pared es el
    marco de la sala: tiene que leerse en todas igual de fuerte, sin competir
    con lo de dentro. El color sigue siendo el de cada capa."""
    media = ImageStat.Stat(imagen.convert("L")).mean[0] / 255.0
    factor = objetivo / max(media, 1e-3)
    return imagen.point(lambda v: int(max(0, min(255, v * factor))))


def _voronoi_toro(lado, celdas, semilla, estirar_y=1.0):
    """Puntos de un Voronoi que se repite: uno por casilla de una cuadricula de
    celdas x celdas, movido al azar dentro de ella. Devuelve una funcion que da
    (distancia al mas cercano, al segundo, punto mas cercano) para un pixel.

    Buscar solo en las 3x3 casillas vecinas (dando la vuelta por los bordes)
    lo hace rapido sin numpy, y la vuelta es lo que hace que no haya costuras."""
    paso = lado / celdas
    puntos = {}
    for cy in range(celdas):
        for cx in range(celdas):
            px = (cx + 0.15 + 0.7 * _hash(cx, cy, semilla)) * paso
            py = (cy + 0.15 + 0.7 * _hash(cx, cy, semilla + 1)) * paso
            puntos[(cx, cy)] = (px, py, _hash(cx, cy, semilla + 2), _hash(cx, cy, semilla + 3),
                                _hash(cx, cy, semilla + 4))

    def mirar(x, y):
        cx, cy = int(x // paso), int(y // paso)
        d1, d2, cerca = 1e18, 1e18, None
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                gx, gy = cx + dx, cy + dy
                p = puntos[(gx % celdas, gy % celdas)]
                qx = p[0] + (gx - gx % celdas) * paso
                qy = p[1] + (gy - gy % celdas) * paso
                d = (x - qx) ** 2 + ((y - qy) * estirar_y) ** 2
                if d < d1:
                    d2, d1, cerca = d1, d, (qx, qy) + p[2:]
                elif d < d2:
                    d2 = d
        return math.sqrt(d1), math.sqrt(d2), cerca
    return mirar


def textura_muro(t, semilla):
    """La roca de la pared vista desde arriba: bloques con los cantos
    biselados (o facetas planas, en las de cristal), grietas entre ellos y
    lo que lleve cada piso encima: musgo, motas de cristal, grietas que
    brillan o vetas de metal."""
    lado = LADO_MURO
    m = t["muro"]
    mirar = _voronoi_toro(lado, m.get("celdas", 4), semilla)
    imagen = Image.new("RGB", (lado, lado))
    px = imagen.load()
    periodo = 8
    escala = periodo / lado
    grieta = m.get("grieta", 1.6)
    bisel = m.get("bisel", 10.0)
    facetas = m.get("facetas", False)
    for y in range(lado):
        for x in range(lado):
            # Torcer el Voronoi con ruido: sin esto los bloques salen con
            # lados rectos y se leen como adoquines, no como roca partida. Al
            # cristal no: sus caras son planas y sus aristas, rectas.
            torcer = 0 if facetas else 34
            tx = (fbm(x * escala * 1.5, y * escala * 1.5, 12, 12, semilla + 41) - 0.5) * torcer
            ty = (fbm(x * escala * 1.5, y * escala * 1.5, 12, 12, semilla + 43) - 0.5) * torcer
            d1, d2, cerca = mirar(x + tx, y + ty)
            junta = d2 - d1
            grano = fbm(x * escala * 4, y * escala * 4, periodo * 4, periodo * 4, semilla)
            mancha = fbm(x * escala, y * escala, periodo, periodo, semilla + 5)
            if facetas:
                # Cada cara del cristal, plana y con su propia inclinacion.
                nx, ny = (cerca[2] - 0.5) * 1.2, (cerca[3] - 0.5) * 1.2
                nz = math.sqrt(max(0.05, 1 - nx * nx - ny * ny))
                brillo = nx * LUZ[0] + ny * LUZ[1] + nz * LUZ[2]
                valor = 0.25 + 0.6 * brillo + 0.15 * (mancha - 0.5)
                # Arista clara entre cara y cara.
                valor += 0.35 * (1 - suave(0, grieta * 2.2, junta))
            else:
                caida = max(0.0, 1.0 - max(0.0, junta - grieta) / bisel)
                fx, fy = x + tx - cerca[0], y + ty - cerca[1]
                largo = max(math.hypot(fx, fy), 1e-6)
                nx, ny = fx / largo * caida * 0.6, fy / largo * caida * 0.6
                nz = math.sqrt(max(0.0, 1.0 - nx * nx - ny * ny))
                brillo = nx * LUZ[0] + ny * LUZ[1] + nz * LUZ[2]
                # Relieve dentro de cada bloque: la roca no es plana.
                relieve = fbm(x * escala * 3, y * escala * 3, periodo * 3, periodo * 3, semilla + 13)
                valor = (0.2 + 0.5 * brillo) * (0.85 + 0.25 * cerca[4]) * (0.75 + 0.5 * mancha)
                valor += 0.18 * (relieve - 0.5)
            # Grietas finas: ruido "de cresta", que solo es alto en lineas.
            cresta = 1 - abs(2 * fbm(x * escala * 2.5, y * escala * 2.5, 20, 20,
                                     semilla + 57) - 1)
            if cresta > 0.93 and not facetas:
                valor *= 0.55 + 0.45 * (1 - (cresta - 0.93) / 0.07)
            valor *= 0.85 + 0.3 * grano
            color = rampa(m["paleta"], valor)
            if "musgo" in m:
                # Musgo en manchas, mas en lo alto de cada bloque (lo plano).
                tono, cantidad = m["musgo"]
                capa = fbm(x * escala * 2, y * escala * 2, periodo * 2, periodo * 2, semilla + 9)
                f = suave(1 - cantidad, 1 - cantidad + 0.12, capa) * (1 - caida * 0.6 if not facetas else 1)
                color = mezclar(color, mezclar(tono, (min(255, tono[0] * 1.5), min(255, tono[1] * 1.4),
                                                       tono[2] * 1.2), grano), f * 0.9)
            if "metal" in m:
                # Cepillado: rayas largas en horizontal.
                raya = fbm(x * escala * 0.5, y * escala * 6, periodo // 2, periodo * 6, semilla + 21)
                color = mezclar(color, m["metal"], max(0.0, raya - 0.55) * 1.4)
            if junta < grieta * 3:
                if "brillo" in m:
                    # Grietas que brillan: el nucleo casi blanco y un halo.
                    nucleo = mezclar(m["brillo"], (255, 250, 230), 0.55)
                    if junta < grieta:
                        color = mezclar(color, nucleo, (1 - junta / grieta) * m.get("fuerza", 1.0))
                    color = mezclar(color, m["brillo"], (1 - junta / (grieta * 3)) * 0.65 * m.get("fuerza", 1.0))
                elif junta < grieta and not facetas:
                    color = mezclar(color, m["paleta"][0], 0.75 * (1 - junta / grieta))
            if "motas" in m:
                tono, densidad = m["motas"]
                h = _hash(x // 3, y // 3, semilla + 33)
                if h < densidad:
                    centro = _hash(x // 3, y // 3, semilla + 34)
                    color = mezclar(color, mezclar(tono, (255, 255, 255), 0.3 if centro > 0.7 else 0.0), 0.85)
            px[x, y] = a_bytes(color)
    return a_luz(imagen, m.get("luz", 0.28))


def _sombrear_cara(color, y, alto):
    """La cara vertical: el labio de arriba coge luz y al pie, donde toca el
    suelo, la sombra se cierra."""
    t = y / alto
    factor = 1.15 - 0.45 * t
    if t < 0.06:
        factor += 0.35 * (1 - t / 0.06)
    if t > 0.82:
        factor *= 1 - 0.45 * (t - 0.82) / 0.18
    return tuple(c * factor for c in color)


def textura_cara(t, semilla):
    """La cara vertical de la pared de arriba, que en 3/4 se ve de frente. Se
    calcula al doble y se reduce."""
    c = t["cara"]
    s = 2
    ancho, alto = ANCHO_CARA * s, ALTO_CARA * s
    imagen = Image.new("RGB", (ancho, alto))
    px = imagen.load()
    paleta = c["paleta"]
    estilo = c["estilo"]
    g = random.Random(semilla)
    periodo = 8

    # Lo que cada estilo necesita preparar una vez.
    if estilo in ("estratos", "fundido"):
        bordes = [0.0]
        while bordes[-1] < alto * 1.4:
            bordes.append(bordes[-1] + g.uniform(*c.get("grosor", (9, 22))) * s)
        tonos = [g.uniform(0.75, 1.15) for _ in bordes]
        brillan = [g.random() < c.get("lava", 0.0) for _ in bordes]
    if estilo == "bloques":
        filas = []
        y = 0.0
        while y < alto:
            h = g.uniform(16, 28) * s
            cortes = []
            xx = g.uniform(0, 30) * s
            while xx < ancho:
                cortes.append(xx)
                xx += g.uniform(26, 60) * s
            filas.append((y, y + h, cortes, [g.uniform(0.8, 1.15) for _ in cortes]))
            y += h
    if estilo == "columnas":
        cortes = []
        xx = 0.0
        while xx < ancho - 14 * s:
            cortes.append(xx)
            xx += g.uniform(18, 30) * s
        tonos_col = [g.uniform(0.8, 1.15) for _ in cortes]
        juntas = [g.uniform(0.15, 0.85) * alto for _ in cortes]
    if estilo == "cristalino":
        mirar = _voronoi_toro(ancho, 9, semilla, estirar_y=0.55)
    if estilo == "almohadillas":
        bolas = []
        fila = 0
        y = 6 * s
        while y < alto + 20 * s:
            xx = (fila % 2) * 22 * s
            while xx < ancho:
                bolas.append((xx + g.uniform(-4, 4) * s, y + g.uniform(-3, 3) * s,
                              g.uniform(19, 26) * s, g.uniform(12, 16) * s, g.uniform(0.85, 1.15)))
                xx += 44 * s
            y += 25 * s
            fila += 1

    for y in range(alto):
        for x in range(ancho):
            grano = fbm(x / ancho * periodo * 4, y / ancho * periodo * 4, periodo * 4, 0, semilla)
            valor, brillo_aqui = 0.5, 0.0
            if estilo in ("estratos", "fundido"):
                onda = (fbm(x / ancho * periodo, y / alto, periodo, 0, semilla + 3) - 0.5)
                amp = 18 if estilo == "fundido" else 7
                yy = y + onda * amp * s
                i = 0
                while i + 1 < len(bordes) and bordes[i + 1] <= yy:
                    i += 1
                dentro_t = (yy - bordes[i]) / max(1.0, bordes[i + 1] - bordes[i])
                valor = 0.5 * tonos[i] + 0.18 * (1 - dentro_t) - 0.2 * suave(0.75, 1.0, dentro_t)
                if dentro_t < 0.08 or dentro_t > 0.94:
                    valor *= 0.55
                if brillan[i] and dentro_t < 0.12:
                    brillo_aqui = 1 - dentro_t / 0.12
            elif estilo == "bloques":
                for (y0, y1, cortes, tonos_b) in filas:
                    if y0 <= y < y1:
                        j = 0
                        for k, corte in enumerate(cortes):
                            if x >= corte:
                                j = k
                        xa = cortes[j]
                        xb = cortes[j + 1] if j + 1 < len(cortes) else cortes[0] + ancho
                        if x < cortes[0]:
                            xa, xb = cortes[-1] - ancho, cortes[0]
                            j = len(cortes) - 1
                        u = (x - xa) / (xb - xa)
                        v = (y - y0) / (y1 - y0)
                        valor = 0.5 * tonos_b[j]
                        valor += 0.25 * (1 - suave(0, 0.18, v)) - 0.25 * suave(0.7, 1, v)
                        valor += 0.12 * (1 - suave(0, 0.1, u)) - 0.18 * suave(0.88, 1, u)
                        if u < 0.02 or u > 0.985 or v < 0.04 or v > 0.96:
                            valor = 0.08
                        break
            elif estilo == "columnas":
                j = 0
                for k, corte in enumerate(cortes):
                    if x >= corte:
                        j = k
                xa = cortes[j]
                xb = cortes[j + 1] if j + 1 < len(cortes) else ancho
                u = (x - xa) / (xb - xa)
                # Columna de seis caras vista de frente: tres franjas, la de
                # la izquierda con luz, la de la derecha en sombra.
                if u < 0.3:
                    valor = 0.72
                elif u < 0.7:
                    valor = 0.52
                else:
                    valor = 0.32
                valor *= tonos_col[j]
                if u < 0.04 or u > 0.96:
                    valor = 0.06
                    if c.get("lava", 0) > 0:
                        brillo_aqui = 0.9
                if abs(y - juntas[j]) < 1.2 * s:
                    valor = 0.1
            elif estilo == "cristalino":
                d1, d2, cerca = mirar(x, y)
                nx, ny = (cerca[2] - 0.5) * 1.4, (cerca[3] - 0.5) * 1.0
                nz = math.sqrt(max(0.05, 1 - nx * nx - ny * ny))
                valor = 0.2 + 0.6 * (nx * LUZ[0] + ny * LUZ[1] + nz * LUZ[2])
                if d2 - d1 < 2.0 * s:
                    valor += 0.35
                    if c.get("lava", 0) > 0:
                        brillo_aqui = 0.5
            elif estilo == "almohadillas":
                valor = 0.06
                mejor = 9.0
                for (bx, by, rx, ry, tono) in bolas:
                    for desplaza in (-ancho, 0, ancho):
                        dx = (x - bx - desplaza) / rx
                        dy = (y - by) / ry
                        d = dx * dx + dy * dy
                        if d < 1 and d < mejor:
                            mejor = d
                            nz = math.sqrt(1 - d)
                            valor = (0.2 + 0.65 * (dx * 0.8 * LUZ[0] + dy * 0.8 * LUZ[1] + nz * LUZ[2])) * tono
            elif estilo == "placas":
                fila_h = 30 * s
                fila = int(y // fila_h)
                desfase = (fila % 2) * 40 * s
                xx = (x + desfase) % (80 * s)
                v = (y % fila_h) / fila_h
                u = xx / (80 * s)
                valor = 0.5 + 0.15 * (1 - v) - 0.15 * suave(0.85, 1, v)
                valor += 0.15 * (fbm(x / ancho * 2, y / alto * 40, 2, 0, semilla + 7) - 0.5)
                if u < 0.015 or v < 0.04 or v > 0.96:
                    valor = 0.08
                    if c.get("lava", 0) > 0 and fila % 2 == 0:
                        brillo_aqui = 0.7
                # Remaches en las esquinas de cada placa.
                for (rx, ry) in ((0.06, 0.2), (0.94, 0.2), (0.06, 0.8), (0.94, 0.8)):
                    if (u - rx) ** 2 * 6 + (v - ry) ** 2 < 0.0035:
                        valor = 0.85 if (u - rx) + (v - ry) < 0 else 0.3
            valor *= 0.82 + 0.36 * grano
            color = rampa(paleta, valor)
            if brillo_aqui > 0 and "brillo" in c:
                color = mezclar(color, mezclar(c["brillo"], (255, 250, 230), brillo_aqui * 0.5), brillo_aqui)
            color = _sombrear_cara(color, y, alto)
            if "musgo" in c:
                # Musgo que cae del labio de arriba, en goterones.
                largo = (5 + 16 * fbm(x / ancho * 16, 0.5, 16, 0, semilla + 11)) * s
                if y < largo:
                    claro = mezclar(c["musgo"], (255, 255, 200), 0.25 * (1 - y / largo))
                    color = mezclar(color, claro, 0.92 if y < largo - 2 * s else 0.4)
            px[x, y] = a_bytes(color)
    imagen = imagen.resize((ANCHO_CARA, ALTO_CARA), Image.LANCZOS)
    # La cara recibe menos luz que lo de arriba: algo mas oscura que el muro.
    imagen = a_luz(imagen, t["muro"].get("luz", 0.28) * 0.85)
    if c.get("vetas", 0) > 0 and "brillo" in c:
        imagen = _vetas_cara(imagen, c, semilla)
    return imagen


def _vetas_cara(imagen, c, semilla):
    """Grietas que brillan en la cara. Se dibujan tres veces, desplazadas un
    ancho a cada lado, para que la textura siga repitiendose sin costura."""
    g = random.Random(semilla + 50)
    capa = Image.new("L", imagen.size, 0)
    dibujo = ImageDraw.Draw(capa)
    for _ in range(c["vetas"]):
        x, y = g.uniform(0, ANCHO_CARA), g.uniform(ALTO_CARA * 0.2, ALTO_CARA * 0.8)
        angulo = g.uniform(0, math.tau)
        puntos = [(x, y)]
        for _paso in range(g.randint(5, 12)):
            angulo += g.uniform(-0.8, 0.8)
            x += math.cos(angulo) * 4
            y = max(4, min(ALTO_CARA - 6, y + math.sin(angulo) * 4))
            puntos.append((x, y))
        for desplaza in (-ANCHO_CARA, 0, ANCHO_CARA):
            dibujo.line([(px + desplaza, py) for px, py in puntos], fill=255, width=1)
    resplandor = capa.filter(ImageFilter.GaussianBlur(2.2))
    imagen = Image.composite(plano(imagen.size, c["brillo"]), imagen, con_alfa(resplandor, 2.2))
    return Image.composite(plano(imagen.size, mezclar(c["brillo"], (255, 250, 230), 0.6)), imagen, capa)


# --- Pilares -------------------------------------------------------------------

def _caja(pixeles, x0, x1, y_tapa, y0, y1, paleta, semilla, veta=None):
    """Un bloque de piedra en 3/4: la tapa (cara de arriba, clara) de y_tapa a
    y0 y el frente de y0 a y1. Luz de arriba a la izquierda."""
    for y in range(int(y_tapa), int(y1)):
        for x in range(int(x0), int(x1)):
            u = (x - x0) / max(x1 - x0 - 1, 1)
            grano = 0.86 + 0.28 * _hash(x // 2, y // 2, semilla)
            if y < y0:
                c = mezclar(paleta[2], paleta[1], 0.3 * (y - y_tapa) / max(y0 - y_tapa, 1))
            else:
                tt = (y - y0) / max(y1 - y0, 1)
                c = mezclar(paleta[1], paleta[0], 0.1 + 0.75 * tt)
                if u < 0.14:
                    c = mezclar(c, paleta[2], 0.4)
                elif u > 0.84:
                    c = tuple(v * 0.6 for v in c)
                if veta and abs((x - (x0 + x1) / 2) * 0.8 - (y - (y0 + y1) / 2) * 0.45
                               + 5 * math.sin(y * 0.09)) < 2.4 and 0.2 < u < 0.8:
                    c = mezclar(c, veta, 0.9)
            c = tuple(v * grano for v in c)
            pixeles[x, y] = a_bytes(c) + (255,)


def _contorno(imagen, color=CONTORNO_BASE, grosor=2):
    alfa = imagen.getchannel("A")
    grande = alfa.filter(ImageFilter.MaxFilter(grosor * 2 + 1))
    fondo = Image.new("RGBA", imagen.size, a_bytes(color) + (0,))
    fondo.putalpha(grande)
    return Image.alpha_composite(fondo, imagen)


def pilar(t, semilla):
    """El pilar de cada lado de las puertas, del tamano de siempre (48x88)."""
    p = t["pilar"]
    paleta = p["paleta"]
    ancho_f, alto_f = 48, 88
    s = 2
    ancho, alto = ancho_f * s, alto_f * s
    imagen = Image.new("RGBA", (ancho, alto), (0, 0, 0, 0))
    estilo = p.get("estilo", "bloques")
    veta = p.get("veta")
    if estilo == "bloques":
        px = imagen.load()
        borde = 2 * s
        fuste = 6 * s
        tapa = 9 * s
        y = borde
        _caja(px, borde, ancho - borde, y, y + tapa, y + tapa + 11 * s, paleta, semilla)
        y += tapa + 11 * s
        alto_fuste = alto - borde - y - 15 * s
        for i in range(3):
            alto_bloque = alto_fuste / 3.0
            desvio = (_hash(i, 7, semilla) - 0.5) * 3 * s
            _caja(px, borde + fuste + desvio, ancho - borde - fuste + desvio, y, y, y + alto_bloque - s,
                  paleta, semilla + i, veta=veta if i == 1 else None)
            y += alto_bloque
        _caja(px, borde, ancho - borde, y, y + 3 * s, alto - borde, paleta, semilla + 9)
    else:
        # Columna (de basalto o de metal) u obelisco de cristal: un prisma de
        # seis caras visto de frente, con tres franjas de luz.
        px = imagen.load()
        x0, x1 = 8 * s, ancho - 8 * s
        punta = 22 * s if estilo == "obelisco" else 0
        for y in range(2 * s, alto - 2 * s):
            for x in range(x0, x1):
                u = (x - x0) / (x1 - x0)
                if punta and y < 2 * s + punta:
                    # La punta del obelisco: se estrecha hacia arriba.
                    medio = (y - 2 * s) / punta
                    if abs(u - 0.5) > medio * 0.5:
                        continue
                if u < 0.33:
                    c = paleta[2]
                elif u < 0.68:
                    c = paleta[1]
                else:
                    c = mezclar(paleta[1], paleta[0], 0.7)
                c = tuple(v * (0.9 + 0.2 * _hash(x // 3, y // 5, semilla)) for v in c)
                if estilo == "columna" and p.get("bandas"):
                    for banda in (0.16, 0.5, 0.84):
                        if abs(y / alto - banda) < 0.025:
                            c = mezclar(p["bandas"], (255, 255, 255), 0.25 if u < 0.3 else 0.0)
                if veta and abs(u - 0.5 - 0.12 * math.sin(y * 0.06)) < 0.035 and 0.15 < y / alto < 0.9:
                    c = mezclar(veta, (255, 250, 230), 0.4)
                if estilo == "obelisco" and abs(u - 0.33) < 0.02:
                    c = mezclar(c, (255, 255, 255), 0.5)
                px[x, y] = a_bytes(c) + (255,)
        if estilo == "columna":
            # Capitel y basa, mas anchos.
            _caja(px, 2 * s, ancho - 2 * s, 2 * s, 8 * s, 14 * s, paleta, semilla)
            _caja(px, 2 * s, ancho - 2 * s, alto - 14 * s, alto - 11 * s, alto - 2 * s, paleta, semilla + 1)
    imagen = _contorno(imagen, grosor=2 * s // 2 + 1)
    if p.get("musgo"):
        imagen = _musgo_encima(imagen, p["musgo"], semilla)
    if p.get("cristal"):
        imagen = _cristal_encima(imagen, p["cristal"], semilla)
    if veta:
        imagen = _brillo_suave(imagen, veta)
    return imagen.resize((ancho_f, alto_f), Image.LANCZOS)


def _musgo_encima(imagen, tono, semilla):
    """Musgo sobre la tapa del pilar, cayendo un poco por delante."""
    g = random.Random(semilla + 70)
    capa = Image.new("RGBA", imagen.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(capa)
    w = imagen.width
    for _ in range(26):
        x = g.uniform(w * 0.08, w * 0.92)
        y = g.uniform(4, 22)
        r = g.uniform(4, 9)
        claro = mezclar(tono, (230, 255, 160), g.uniform(0, 0.35))
        d.ellipse((x - r, y - r * 0.7, x + r, y + r * 0.7), fill=a_bytes(claro) + (255,))
    for _ in range(7):
        x = g.uniform(w * 0.15, w * 0.85)
        largo = g.uniform(10, 34)
        d.line([(x, 18), (x + g.uniform(-3, 3), 18 + largo)], fill=a_bytes(mezclar(tono, (0, 0, 0), 0.25)) + (255,),
               width=4)
    capa = _contorno(capa, grosor=2)
    return Image.alpha_composite(imagen, capa)


def _cristal_encima(imagen, tono, semilla):
    """Un grupito de cristales asomando por encima del pilar."""
    pieza = cristales(tono, random.Random(semilla + 80), ancho=40, alto=30, cuantos=4, brillo=0.5)
    pieza = pieza.resize((pieza.width * 2, pieza.height * 2), Image.LANCZOS)
    lienzo = Image.new("RGBA", imagen.size, (0, 0, 0, 0))
    lienzo.paste(pieza, ((imagen.width - pieza.width) // 2, max(0, 14 - pieza.height)), pieza)
    # El pilar se encoge un poco por arriba para dejar sitio: se pega encima.
    return Image.alpha_composite(imagen, lienzo)


def _brillo_suave(imagen, tono):
    alfa = imagen.getchannel("A").filter(ImageFilter.GaussianBlur(6))
    fondo = Image.new("RGBA", imagen.size, a_bytes(tono) + (0,))
    fondo.putalpha(con_alfa(alfa, 0.25))
    return Image.alpha_composite(fondo, imagen)


# --- Piezas sueltas --------------------------------------------------------------

def mechon(tono, g, ancho=40, alto=30, flores=None, hoja=1.0):
    """Hierba (o helecho, con hoja ancha): hojas finas que salen de un punto
    y se abren, las de detras mas oscuras."""
    W, H = ancho * E, alto * E
    color = Image.new("RGB", (W, H))
    mascara = Image.new("L", (W, H), 0)
    dc, dm = ImageDraw.Draw(color), ImageDraw.Draw(mascara)
    cuantas = g.randint(9, 14)
    hojas = []
    for _ in range(cuantas):
        hojas.append((g.uniform(-0.95, 0.95), g.uniform(0.5, 1.0), g.uniform(0, 1)))
    hojas.sort(key=lambda h: h[2])
    for angulo, largo, luz in hojas:
        x0 = W / 2 + g.uniform(-W * 0.18, W * 0.18)
        y0 = H - 2 * E
        L = largo * (H - 4 * E)
        curva = g.uniform(-0.4, 0.4)
        puntos_i, puntos_d = [], []
        for i in range(13):
            t = i / 12
            a = angulo * t + curva * t * t
            x = x0 + math.sin(a) * L * t * 0.9
            y = y0 - math.cos(a) * L * t
            grosor = (2.4 * hoja * E) * (1 - t) ** 0.8 + 0.4 * E
            if hoja > 1.2:
                grosor *= 0.6 + 1.6 * math.sin(math.pi * min(1, t * 1.1))
            nx, ny = math.cos(a), math.sin(a)
            puntos_i.append((x - nx * grosor, y - ny * grosor))
            puntos_d.append((x + nx * grosor, y + ny * grosor))
        poligono = puntos_i + puntos_d[::-1]
        c = mezclar(mezclar(tono, (0, 0, 0), 0.45), mezclar(tono, (255, 255, 210), 0.3), luz)
        dc.polygon(poligono, fill=a_bytes(c))
        dm.polygon(poligono, fill=255)
        if flores and g.random() < 0.3:
            fx, fy = puntos_i[-1]
            r = 1.8 * E
            dc.ellipse((fx - r, fy - r, fx + r, fy + r), fill=a_bytes(flores))
            dm.ellipse((fx - r, fy - r, fx + r, fy + r), fill=255)
    return reducir(cerrar(color, mascara, mezclar(tono, (0, 0, 0), 0.8), grosor=1))


def seta(tono, g, brillo=None, tam=1.0):
    """Dos o tres setas juntas. Con brillo, el sombrero da luz."""
    W, H = int(34 * E * tam), int(30 * E * tam)
    color = Image.new("RGB", (W, H))
    mascara = Image.new("L", (W, H), 0)
    dc, dm = ImageDraw.Draw(color), ImageDraw.Draw(mascara)
    setas = sorted([(g.uniform(0.25, 0.75) * W, g.uniform(0.45, 1.0)) for _ in range(g.randint(2, 3))],
                   key=lambda s: s[1])
    for cx, escala in setas:
        alto = 22 * E * escala * tam
        ancho_s = 14 * E * escala * tam
        pie = H - 2 * E
        grueso = 2 * E * escala * tam
        # Pie.
        dc.rectangle((cx - grueso, pie - alto * 0.75, cx + grueso, pie), fill=(206, 196, 170))
        dm.rectangle((cx - grueso, pie - alto * 0.75, cx + grueso, pie), fill=255)
        # Sombrero.
        caja = (cx - ancho_s / 2, pie - alto, cx + ancho_s / 2, pie - alto * 0.5)
        dc.pieslice(caja, 180, 360, fill=a_bytes(tono))
        dm.pieslice(caja, 180, 360, fill=255)
        luz = (caja[0] + ancho_s * 0.15, caja[1] + alto * 0.06, caja[0] + ancho_s * 0.5, caja[1] + alto * 0.18)
        dc.ellipse(luz, fill=a_bytes(mezclar(tono, (255, 255, 255), 0.5)))
    pieza = cerrar(color, mascara, (20, 16, 20), grosor=1)
    if brillo:
        pieza = halo(pieza, mascara, brillo, E * 4, 0.8)
    return reducir(pieza)


def raices(tono, g, alto=44):
    """Raices que cuelgan: lineas que bajan serpenteando y se afinan."""
    W, H = 30 * E, alto * E
    color = Image.new("RGB", (W, H))
    mascara = Image.new("L", (W, H), 0)
    dc, dm = ImageDraw.Draw(color), ImageDraw.Draw(mascara)
    for _ in range(g.randint(3, 5)):
        x = g.uniform(W * 0.2, W * 0.8)
        y = 0.0
        largo = g.uniform(0.5, 1.0) * H
        angulo = math.pi / 2 + g.uniform(-0.3, 0.3)
        grosor = g.uniform(2.2, 3.4) * E
        c = mezclar(tono, (0, 0, 0), g.uniform(0, 0.3))
        while y < largo:
            angulo += g.uniform(-0.35, 0.35)
            angulo = max(math.pi / 2 - 0.7, min(math.pi / 2 + 0.7, angulo))
            nx, ny = x + math.cos(angulo) * 3 * E, y + math.sin(angulo) * 3 * E
            w = max(0.6 * E, grosor * (1 - y / largo))
            dc.line((x, y, nx, ny), fill=a_bytes(c), width=int(w))
            dm.line((x, y, nx, ny), fill=255, width=int(w))
            dc.line((x - w * 0.25, y, nx - w * 0.25, ny), fill=a_bytes(mezclar(c, (255, 230, 190), 0.3)),
                    width=max(1, int(w * 0.3)))
            x, y = nx, ny
    return reducir(cerrar(color, mascara, mezclar(tono, (0, 0, 0), 0.75), grosor=1))


def musgo_colgante(tono, g, alto=34):
    """Musgo que cuelga en hebras desde una mata."""
    W, H = 34 * E, alto * E
    color = Image.new("RGB", (W, H))
    mascara = Image.new("L", (W, H), 0)
    dc, dm = ImageDraw.Draw(color), ImageDraw.Draw(mascara)
    for _ in range(g.randint(14, 22)):
        x = g.uniform(W * 0.12, W * 0.88)
        largo = g.uniform(0.3, 1.0) * (H - 4 * E)
        puntos = [(x + math.sin(i * 0.9 + x) * 1.2 * E, largo * i / 8) for i in range(9)]
        c = mezclar(mezclar(tono, (0, 0, 0), 0.35), mezclar(tono, (255, 255, 200), 0.2), g.random())
        dc.line(puntos, fill=a_bytes(c), width=int(1.8 * E))
        dm.line(puntos, fill=255, width=int(1.8 * E))
    dc.ellipse((W * 0.08, -6 * E, W * 0.92, 7 * E), fill=a_bytes(tono))
    dm.ellipse((W * 0.08, -6 * E, W * 0.92, 7 * E), fill=255)
    return reducir(cerrar(color, mascara, mezclar(tono, (0, 0, 0), 0.8), grosor=1))


def cono(paleta, g, ancho, alto, hacia_abajo, cuantos=1, gota=None):
    """Estalactitas (hacia abajo) o estalagmitas (hacia arriba): conos con la
    luz por la izquierda y anillos de crecimiento."""
    W, H = int(ancho * E), int(alto * E)
    color = Image.new("RGB", (W, H))
    mascara = Image.new("L", (W, H), 0)
    conos = []
    for i in range(cuantos):
        escala = 1.0 if i == 0 else g.uniform(0.45, 0.75)
        cx = W / 2 if i == 0 else W / 2 + g.choice((-1, 1)) * g.uniform(0.2, 0.32) * W
        conos.append((escala, cx))
    conos.sort(key=lambda c: c[0])
    for escala, cx in conos:
        largo = (H - 3 * E) * escala
        base = W * 0.36 * escala
        sesgo = g.uniform(-0.12, 0.12) * W
        capa = Image.new("L", (W, H), 0)
        puntos = []
        for k in range(21):
            t = k / 20
            ancho_t = base * (1 - t) ** 1.3 + 0.6 * E
            y = t * largo
            x = cx + sesgo * t * t
            puntos.append((x - ancho_t, y, x + ancho_t))
        izquierda = [(p[0], p[1]) for p in puntos]
        derecha = [(p[2], p[1]) for p in puntos[::-1]]
        ImageDraw.Draw(capa).polygon(izquierda + derecha, fill=255)
        if not hacia_abajo:
            capa = capa.transpose(Image.FLIP_TOP_BOTTOM)
        # Luz por la izquierda, sombra por la derecha.
        fondo = degradado_h((W, H), paleta[2], mezclar(paleta[1], paleta[0], 0.7), cx - base, cx + base)
        anillos = Image.new("L", (W, H), 0)
        da = ImageDraw.Draw(anillos)
        for k in range(1, 7):
            yy = largo * k / 7
            if not hacia_abajo:
                yy = H - yy
            da.line((0, yy, W, yy + g.uniform(-2, 2) * E), fill=90, width=E)
        fondo = Image.composite(plano((W, H), paleta[0]), fondo, con_alfa(anillos, 0.6))
        color = Image.composite(fondo, color, capa)
        mascara = ImageChops.lighter(mascara, capa)
    pieza = cerrar(color, mascara, mezclar(paleta[0], (0, 0, 0), 0.6), grosor=1)
    if gota and hacia_abajo:
        d = ImageDraw.Draw(pieza)
        cx = conos[-1][1]
        d.ellipse((cx - 2 * E, H - 6 * E, cx + 2 * E, H - 1 * E), fill=a_bytes(gota) + (255,))
    return reducir(pieza)


def cristales(tono, g, ancho=60, alto=60, cuantos=5, brillo=0.6, hacia_abajo=False, irregular=False):
    """Un grupo de cristales: prismas que salen de una base, con la cara
    izquierda iluminada, la derecha en sombra y la arista del medio clara.
    Con 'irregular', astillas de metal en vez de cristales limpios."""
    W, H = int(ancho * E), int(alto * E)
    color = Image.new("RGB", (W, H))
    mascara = Image.new("L", (W, H), 0)
    dc, dm = ImageDraw.Draw(color), ImageDraw.Draw(mascara)
    claro = mezclar(tono, (255, 255, 255), 0.45)
    oscuro = mezclar(tono, (0, 0, 0), 0.55)
    prismas = []
    for i in range(cuantos):
        escala = 1.0 if i == 0 else g.uniform(0.4, 0.85)
        angulo = g.uniform(-0.55, 0.55) * (0.3 if i == 0 else 1.0)
        prismas.append((escala, angulo, g.uniform(-0.18, 0.18) * W))
    prismas.sort(key=lambda p: p[0])
    base_y = 2 * E if hacia_abajo else H - 2 * E
    for escala, angulo, dx in prismas:
        largo = (H - 6 * E) * escala
        ancho_p = W * 0.16 * (0.7 + 0.5 * escala)
        sentido = 1 if hacia_abajo else -1
        ux, uy = math.sin(angulo), sentido * math.cos(angulo)
        nx, ny = -uy, ux
        bx, by = W / 2 + dx, base_y
        punta_l = largo * (0.22 if not irregular else g.uniform(0.3, 0.6))
        cuerpo = largo - punta_l
        p_iz = (bx - nx * ancho_p, by - ny * ancho_p)
        p_de = (bx + nx * ancho_p, by + ny * ancho_p)
        a_iz = (p_iz[0] + ux * cuerpo, p_iz[1] + uy * cuerpo)
        a_de = (p_de[0] + ux * cuerpo, p_de[1] + uy * cuerpo)
        centro_b = (bx, by)
        centro_a = (bx + ux * cuerpo, by + uy * cuerpo)
        punta = (bx + ux * largo, by + uy * largo)
        if irregular:
            punta = (punta[0] + nx * g.uniform(-0.6, 0.6) * ancho_p, punta[1])
        lado_luz = [p_iz, a_iz, punta, centro_a, centro_b] if nx * LUZ[0] + ny * LUZ[1] <= 0 else \
            [p_de, a_de, punta, centro_a, centro_b]
        lado_sombra = [p_de, a_de, punta, centro_a, centro_b] if lado_luz[0] == p_iz else \
            [p_iz, a_iz, punta, centro_a, centro_b]
        tono_p = mezclar(tono, (255, 255, 255), g.uniform(-0.1, 0.15)) if not irregular else tono
        dc.polygon(lado_sombra, fill=a_bytes(mezclar(tono_p, oscuro, 0.6)))
        dc.polygon(lado_luz, fill=a_bytes(mezclar(tono_p, claro, 0.35)))
        dm.polygon(lado_sombra, fill=255)
        dm.polygon(lado_luz, fill=255)
        # Arista del medio y reflejo en la punta.
        dc.line([centro_b, centro_a, punta], fill=a_bytes(mezclar(claro, (255, 255, 255), 0.5)),
                width=max(1, int(E * 0.9)))
    pieza = cerrar(color, mascara, mezclar(tono, (0, 0, 0), 0.82), grosor=1)
    if brillo > 0:
        pieza = halo(pieza, mascara, mezclar(tono, (255, 255, 255), 0.3), E * 5, brillo)
    return reducir(pieza)


def gota(tono, g, alto=30):
    """Una gota que cuelga (agua, magma o metal fundido): un hilo desde arriba
    que engorda en una gota. Las calientes brillan."""
    W, H = 16 * E, alto * E
    mascara = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(mascara)
    cx = W / 2
    largo = g.uniform(0.55, 1.0) * (H - 10 * E)
    d.polygon([(cx - 3 * E, 0), (cx + 3 * E, 0), (cx + 1 * E, largo), (cx - 1 * E, largo)], fill=255)
    r = g.uniform(3.2, 4.4) * E
    d.ellipse((cx - r, largo - r * 0.4, cx + r, largo + r * 1.6), fill=255)
    color = degradado((W, H), mezclar(tono, (0, 0, 0), 0.3), mezclar(tono, (255, 250, 230), 0.55), 0, largo + r)
    brillo_d = ImageDraw.Draw(color)
    brillo_d.ellipse((cx - r * 0.5, largo + r * 0.1, cx - r * 0.05, largo + r * 0.6),
                     fill=a_bytes(mezclar(tono, (255, 255, 255), 0.8)))
    pieza = cerrar(color, mascara, mezclar(tono, (0, 0, 0), 0.75), grosor=1)
    pieza = halo(pieza, mascara, tono, E * 4, 0.9)
    return reducir(pieza)


def roca(paleta, g, ancho=90, alto=70, musgo=None, brillo=None, motas=None, punta=None):
    """Una roca grande que sale de la pared: monticulo con volumen y, segun el
    piso, musgo por encima, grietas que brillan o motas de cristal."""
    W, H = int((ancho + 16) * E), int((alto + 16) * E)
    mascara = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(mascara)
    punta = punta if punta is not None else g.uniform(0.5, 1.2)
    fases = [g.uniform(0, math.tau) for _ in range(3)]
    sesgo = g.uniform(0.75, 1.3)
    base = H - 6 * E
    puntos = []
    for i in range(49):
        t = i / 48
        perfil = math.sin(math.pi * (t ** sesgo)) ** punta
        ruido_p = 1.0 + 0.08 * math.sin(t * 7 + fases[0]) + 0.05 * math.sin(t * 17 + fases[1])
        x = W / 2 - ancho * E / 2 + ancho * E * t
        puntos.append((x, base - alto * E * perfil * ruido_p))
    puntos.append((W / 2 + ancho * E * 0.45, base + 3 * E))
    puntos.append((W / 2 - ancho * E * 0.45, base + 3 * E))
    d.polygon(puntos, fill=255)
    color = volumen(mascara, paleta, g)
    if motas:
        dm = ImageDraw.Draw(color)
        caja = mascara.getbbox()
        mpx = mascara.load()
        for _ in range(int(ancho * alto / 60)):
            x = g.uniform(caja[0], caja[2])
            y = g.uniform(caja[1], caja[3])
            if mpx[int(x), int(y)] > 200:
                r = g.uniform(1.0, 2.2) * E
                dm.ellipse((x - r, y - r, x + r, y + r), fill=a_bytes(mezclar(motas, (255, 255, 255), g.uniform(0, 0.4))))
    if brillo:
        color = con_vetas_brillantes(color, mascara, g, brillo, g.randint(2, 4))
    if musgo:
        # Lo de arriba de la roca: la mascara menos ella misma bajada.
        arriba = ImageChops.subtract(mascara, desplazar(mascara, 0, E * g.randint(9, 14)))
        arriba = arriba.filter(ImageFilter.GaussianBlur(E * 1.2)).point(lambda v: 255 if v > 110 else 0)
        verde = degradado(mascara.size, mezclar(musgo, (230, 255, 160), 0.3), mezclar(musgo, (0, 0, 0), 0.3),
                          0, H)
        color = Image.composite(verde, color, arriba)
    pieza = cerrar(color, mascara, mezclar(paleta[0], (0, 0, 0), 0.7))
    if brillo:
        pieza = halo(pieza, mascara, brillo, E * 6, 0.35)
    return reducir(pieza)


def columnas(paleta, g, brillo=None):
    """Columnas de basalto: prismas de seis caras de distinta altura, con su
    tapa vista desde arriba."""
    W, H = 124 * E, 124 * E
    color = Image.new("RGB", (W, H))
    mascara = Image.new("L", (W, H), 0)
    dc, dm = ImageDraw.Draw(color), ImageDraw.Draw(mascara)
    piezas = []
    for i in range(g.randint(3, 5)):
        piezas.append((g.uniform(0.18, 0.82) * W, g.uniform(0.4, 1.0), g.uniform(16, 22) * E))
    # Las altas detras.
    piezas.sort(key=lambda p: -p[1])
    for cx, alto_rel, r in piezas:
        base = H - 4 * E - g.uniform(0, 6) * E
        arriba = base - (H - 26 * E) * alto_rel
        tapa_h = r * 0.5
        cuerpo = [(cx - r, arriba), (cx + r, arriba), (cx + r, base), (cx - r, base)]
        dm.polygon(cuerpo, fill=255)
        dc.polygon([(cx - r, arriba), (cx - r * 0.35, arriba), (cx - r * 0.35, base), (cx - r, base)],
                   fill=a_bytes(paleta[2]))
        dc.polygon([(cx - r * 0.35, arriba), (cx + r * 0.35, arriba), (cx + r * 0.35, base), (cx - r * 0.35, base)],
                   fill=a_bytes(paleta[1]))
        dc.polygon([(cx + r * 0.35, arriba), (cx + r, arriba), (cx + r, base), (cx + r * 0.35, base)],
                   fill=a_bytes(mezclar(paleta[1], paleta[0], 0.7)))
        # Junta horizontal.
        jy = g.uniform(arriba + (base - arriba) * 0.3, base - 4 * E)
        dc.line((cx - r, jy, cx + r, jy + g.uniform(-2, 2) * E), fill=a_bytes(paleta[0]), width=E)
        # Tapa hexagonal.
        hexagono = [(cx + math.cos(a) * r, arriba + math.sin(a) * tapa_h)
                    for a in [k * math.tau / 6 for k in range(6)]]
        dm.polygon(hexagono, fill=255)
        dc.polygon(hexagono, fill=a_bytes(mezclar(paleta[2], (255, 255, 255), 0.12)))
        if brillo and g.random() < 0.6:
            dc.line([(cx - r * 0.5, arriba), (cx + r * 0.3, arriba + tapa_h * 0.4)], fill=a_bytes(brillo), width=E)
    pieza = cerrar(color, mascara, mezclar(paleta[0], (0, 0, 0), 0.7))
    if brillo:
        pieza = halo(pieza, mascara, brillo, E * 5, 0.25)
    return reducir(pieza)


def brasa(paleta, brillo, g):
    """Piedrecitas con grietas al rojo, del tamano de un adorno."""
    W, H = 40 * E, 26 * E
    mascara = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(mascara)
    for _ in range(g.randint(2, 4)):
        cx, rx = g.uniform(0.25, 0.75) * W, g.uniform(5, 9) * E
        ry = rx * g.uniform(0.6, 0.8)
        d.ellipse((cx - rx, H - 2 * E - ry * 2, cx + rx, H - 2 * E), fill=255)
    color = volumen(mascara, paleta, g, motas=False)
    color = con_vetas_brillantes(color, mascara, g, brillo, 3)
    pieza = cerrar(color, mascara, mezclar(paleta[0], (0, 0, 0), 0.7), grosor=1)
    pieza = halo(pieza, mascara, brillo, E * 4, 0.6)
    return reducir(pieza)


# --- Reja (comun) --------------------------------------------------------------

def generar_reja(ancho_final=130, alto_final=64):
    """Rastrillo de hierro, con las puntas abajo. Barrotes redondos con su
    brillo, dos travesanos con remaches y un contorno oscuro."""
    s = 2
    ancho, alto = ancho_final * s, alto_final * s
    imagen = Image.new("RGBA", (ancho, alto), (0, 0, 0, 0))
    pixeles = imagen.load()
    barrotes = 7
    grosor = 6.5 * s
    paso = ancho / barrotes
    punta = 11 * s
    travesanos = [alto * 0.2, alto * 0.62]
    ancho_trav = 5 * s
    oscuro, claro = (30, 30, 36), (170, 172, 184)

    def metal(u):
        luz = 0.5 - 0.45 * u + 0.25 * (1 - u * u)
        c = mezclar(oscuro, claro, luz)
        return mezclar(c, (255, 255, 255), math.exp(-((u + 0.45) / 0.14) ** 2) * 0.5)

    for y in range(alto):
        for x in range(ancho):
            c = None
            for t in travesanos:
                v = (y - t) / (ancho_trav / 2)
                if abs(v) <= 1.0:
                    c = metal(v * 0.8) if abs(v) < 0.8 else CONTORNO_BASE
            i = int(x // paso)
            centro = (i + 0.5) * paso
            w = grosor / 2
            fondo_barrote = alto - 1
            if y > fondo_barrote - punta:
                w = grosor / 2 * max(0.0, (fondo_barrote - y) / punta)
            if w > 0:
                u = (x + 0.5 - centro) / w
                if abs(u) <= 1.0:
                    c = metal(u)
                elif abs(u) <= 1.0 + 1.2 * s / max(w, 1.0):
                    c = CONTORNO_BASE
            if c is not None:
                pixeles[x, y] = a_bytes(c) + (255,)
    dibujo = ImageDraw.Draw(imagen)
    for i in range(barrotes):
        cx = (i + 0.5) * paso
        for t in travesanos:
            r = 3.2 * s
            dibujo.ellipse((cx - r, t - r, cx + r, t + r), fill=CONTORNO_BASE + (255,))
            dibujo.ellipse((cx - r + s, t - r + s, cx + r - s, t + r - s), fill=(120, 120, 130, 255))
            dibujo.ellipse((cx - r * 0.6, t - r * 0.6, cx, t), fill=(210, 210, 220, 255))
    return imagen.resize((ancho_final, alto_final), Image.LANCZOS)


# --- Temas: la pared de cada piso ------------------------------------------------
#
# paleta = (oscuro, medio, claro). Cada pieza es (funcion, argumentos): la
# funcion recibe el generador al azar al final. 'juego' son los numeros que
# usa el juego para levantar la pared (van al .tres).

def _p(*colores):
    return tuple(colores)


TIERRA = _p((40, 30, 22), (96, 76, 54), (156, 132, 96))
VERDE = (72, 120, 40)
BASALTO = _p((20, 26, 34), (50, 62, 76), (98, 114, 130))
TEAL = (40, 112, 92)
CALIZA = _p((54, 48, 40), (110, 100, 86), (168, 156, 134))
ASTENO = _p((32, 18, 16), (82, 50, 40), (132, 90, 70))
MAGMA = (255, 128, 44)
OLIVO = _p((26, 34, 20), (70, 84, 46), (124, 142, 84))
OLIVINO = (140, 206, 64)
VIOLETA = _p((28, 22, 40), (66, 54, 88), (112, 98, 142))
RINGWOOD = (80, 130, 255)
BRIDG = _p((28, 14, 12), (72, 38, 30), (118, 70, 56))
ESCORIA = _p((12, 9, 9), (40, 30, 30), (78, 62, 58))
LAVA = (255, 160, 56)
HIERRO = _p((18, 18, 24), (54, 54, 66), (104, 106, 122))
FUNDIDO = (255, 170, 70)
ACERO = _p((16, 20, 28), (50, 60, 78), (108, 124, 150))
PLATA = _p((40, 40, 48), (100, 102, 114), (178, 180, 194))
ORO = _p((88, 54, 26), (170, 122, 66), (250, 220, 158))
BLANCO_CALIENTE = (255, 236, 190)

TEMAS = {
    1: {
        "nombre": "Corteza continental: tierra y piedra, con hierba encima y raices",
        "muro": {"paleta": TIERRA, "musgo": (VERDE, 0.32), "luz": 0.27},
        "cara": {"estilo": "estratos", "paleta": _p((48, 34, 24), (112, 86, 58), (170, 140, 98)),
                 "musgo": VERDE},
        "pilar": {"estilo": "bloques", "paleta": _p((50, 44, 40), (112, 102, 90), (170, 160, 142)),
                  "musgo": VERDE},
        "adornos": [(mechon, (VERDE,), {"flores": (240, 230, 140)}), (mechon, ((86, 140, 46),), {}),
                    (mechon, ((60, 104, 36),), {"hoja": 1.8})] * 2,
        "colgantes": [(raices, ((104, 76, 50),), {}), (raices, ((92, 66, 44),), {}),
                      (musgo_colgante, (VERDE,), {})],
        "salientes": [],
        "juego": {"luz": (220, 200, 150), "sombra": (16, 10, 8), "alto_cara": 54, "entrada": 20,
                  "ondulacion": 14, "adornos_cada": 46, "colgantes_cada": 70, "salientes": 3},
    },
    2: {
        "nombre": "Corteza oceanica: basalto en almohadillas, mojado, con algas y setas que brillan",
        "muro": {"paleta": BASALTO, "musgo": (TEAL, 0.25), "motas": ((150, 200, 215), 0.015), "luz": 0.24},
        "cara": {"estilo": "almohadillas", "paleta": BASALTO, "musgo": TEAL},
        "pilar": {"estilo": "bloques", "paleta": BASALTO, "musgo": TEAL},
        "adornos": [(mechon, (TEAL,), {"hoja": 1.9}), (seta, ((60, 200, 200),), {"brillo": (90, 240, 230)}),
                    (mechon, ((52, 130, 104),), {"hoja": 1.5}), (seta, ((90, 160, 220),), {"brillo": (120, 200, 255)})],
        "colgantes": [(musgo_colgante, (TEAL,), {}), (gota, ((150, 210, 240),), {}),
                      (musgo_colgante, ((50, 120, 100),), {})],
        "salientes": [(seta, ((60, 200, 200),), {"brillo": (90, 240, 230), "tam": 2.2}),
                      (seta, ((90, 160, 220),), {"brillo": (120, 200, 255), "tam": 2.0})],
        "juego": {"luz": (150, 200, 210), "sombra": (6, 10, 14), "alto_cara": 52, "entrada": 20,
                  "ondulacion": 14, "adornos_cada": 60, "colgantes_cada": 64, "salientes": 3},
    },
    3: {
        "nombre": "Litosfera: caliza en estratos, con estalactitas y estalagmitas",
        "muro": {"paleta": CALIZA, "luz": 0.3},
        "cara": {"estilo": "estratos", "paleta": CALIZA, "grosor": (5, 12)},
        "pilar": {"estilo": "bloques", "paleta": CALIZA},
        "adornos": [(cono, (CALIZA, 22, 24, False), {"cuantos": 2}), (cono, (CALIZA, 16, 18, False), {}),
                    (cono, (CALIZA, 26, 30, False), {"cuantos": 3})],
        "colgantes": [(cono, (CALIZA, 18, 40, True), {"gota": (210, 230, 240)}),
                      (cono, (CALIZA, 24, 44, True), {"cuantos": 2, "gota": (210, 230, 240)}),
                      (cono, (CALIZA, 14, 30, True), {})],
        "salientes": [(cono, (CALIZA, 64, 92, False), {"cuantos": 3}), (cono, (CALIZA, 56, 80, False), {"cuantos": 2})],
        "juego": {"luz": (235, 225, 200), "sombra": (14, 12, 10), "alto_cara": 52, "entrada": 18,
                  "ondulacion": 12, "adornos_cada": 90, "colgantes_cada": 44, "salientes": 3},
    },
    4: {
        "nombre": "Astenosfera: roca blanda que empieza a fundirse, con grietas de magma",
        "muro": {"paleta": ASTENO, "brillo": MAGMA, "fuerza": 0.45, "luz": 0.24},
        "cara": {"estilo": "fundido", "paleta": ASTENO, "brillo": MAGMA, "lava": 0.2, "vetas": 3},
        "pilar": {"estilo": "bloques", "paleta": ASTENO, "veta": MAGMA},
        "adornos": [(brasa, (ASTENO, MAGMA), {}), (cristales, (OLIVINO,), {"ancho": 24, "alto": 22, "cuantos": 3,
                                                                          "brillo": 0.3})],
        "colgantes": [(gota, (MAGMA,), {}), (gota, ((255, 100, 30),), {"alto": 22})],
        "salientes": [(cristales, (OLIVINO,), {"ancho": 50, "alto": 56, "cuantos": 5, "brillo": 0.4})],
        "juego": {"luz": (240, 160, 110), "sombra": (14, 6, 4), "alto_cara": 50, "entrada": 18,
                  "ondulacion": 13, "adornos_cada": 80, "colgantes_cada": 80, "salientes": 3},
    },
    5: {
        "nombre": "Manto superior: peridotita verde llena de olivino",
        "muro": {"paleta": OLIVO, "motas": (OLIVINO, 0.03), "luz": 0.24},
        "cara": {"estilo": "bloques", "paleta": OLIVO},
        "pilar": {"estilo": "bloques", "paleta": OLIVO, "cristal": OLIVINO},
        "adornos": [(cristales, (OLIVINO,), {"ancho": 26, "alto": 26, "cuantos": 4}),
                    (cristales, ((110, 180, 50),), {"ancho": 20, "alto": 20, "cuantos": 3})],
        "colgantes": [(cristales, (OLIVINO,), {"ancho": 24, "alto": 30, "cuantos": 3, "hacia_abajo": True})],
        "salientes": [(cristales, (OLIVINO,), {"ancho": 70, "alto": 84, "cuantos": 6}),
                      (cristales, ((120, 196, 60),), {"ancho": 60, "alto": 70, "cuantos": 5})],
        "juego": {"luz": (190, 230, 130), "sombra": (8, 12, 6), "alto_cara": 50, "entrada": 18,
                  "ondulacion": 12, "adornos_cada": 70, "colgantes_cada": 96, "salientes": 3},
    },
    6: {
        "nombre": "Zona de transicion: roca violeta con cristales azules de ringwoodita",
        "muro": {"paleta": VIOLETA, "motas": (RINGWOOD, 0.03), "luz": 0.24},
        "cara": {"estilo": "cristalino", "paleta": VIOLETA},
        "pilar": {"estilo": "bloques", "paleta": VIOLETA, "cristal": RINGWOOD},
        "adornos": [(cristales, (RINGWOOD,), {"ancho": 26, "alto": 28, "cuantos": 4}),
                    (cristales, ((120, 110, 255),), {"ancho": 20, "alto": 22, "cuantos": 3})],
        "colgantes": [(cristales, (RINGWOOD,), {"ancho": 26, "alto": 34, "cuantos": 4, "hacia_abajo": True}),
                      (cristales, ((120, 110, 255),), {"ancho": 20, "alto": 26, "cuantos": 3, "hacia_abajo": True})],
        "salientes": [(cristales, (RINGWOOD,), {"ancho": 72, "alto": 88, "cuantos": 6}),
                      (cristales, ((110, 100, 250),), {"ancho": 64, "alto": 76, "cuantos": 5})],
        "juego": {"luz": (160, 175, 255), "sombra": (8, 6, 16), "alto_cara": 48, "entrada": 17,
                  "ondulacion": 12, "adornos_cada": 64, "colgantes_cada": 70, "salientes": 3},
    },
    7: {
        "nombre": "Manto inferior: columnas de roca densa con costuras al rojo",
        "muro": {"paleta": BRIDG, "celdas": 5, "brillo": (255, 110, 40), "fuerza": 0.4, "luz": 0.22},
        "cara": {"estilo": "columnas", "paleta": BRIDG, "brillo": (255, 110, 40), "lava": 1},
        "pilar": {"estilo": "columna", "paleta": BRIDG, "veta": (255, 110, 40)},
        "adornos": [(brasa, (BRIDG, (255, 110, 40)), {})],
        "colgantes": [(gota, ((255, 110, 40),), {})],
        "salientes": [(columnas, (BRIDG,), {"brillo": (255, 130, 50)}), (columnas, (BRIDG,), {})],
        "juego": {"luz": (255, 160, 110), "sombra": (12, 4, 2), "alto_cara": 48, "entrada": 16,
                  "ondulacion": 10, "adornos_cada": 110, "colgantes_cada": 110, "salientes": 3},
    },
    8: {
        "nombre": "Capa D'': escoria negra partida por rios de lava",
        "muro": {"paleta": ESCORIA, "brillo": LAVA, "fuerza": 0.6, "luz": 0.16},
        "cara": {"estilo": "fundido", "paleta": ESCORIA, "brillo": LAVA, "lava": 0.45, "vetas": 6},
        "pilar": {"estilo": "bloques", "paleta": ESCORIA, "veta": LAVA},
        "adornos": [(brasa, (ESCORIA, LAVA), {})],
        "colgantes": [(gota, (LAVA,), {}), (gota, ((255, 200, 90),), {"alto": 36})],
        "salientes": [],
        "juego": {"luz": (255, 190, 120), "sombra": (6, 2, 2), "alto_cara": 46, "entrada": 16,
                  "ondulacion": 12, "adornos_cada": 90, "colgantes_cada": 60, "salientes": 3},
    },
    9: {
        "nombre": "Nucleo externo: hierro oscuro del que gotea metal fundido",
        "muro": {"paleta": HIERRO, "brillo": FUNDIDO, "fuerza": 0.45, "metal": (130, 134, 152), "luz": 0.2},
        "cara": {"estilo": "placas", "paleta": HIERRO, "brillo": FUNDIDO, "lava": 1, "vetas": 2},
        "pilar": {"estilo": "columna", "paleta": HIERRO, "bandas": (60, 60, 72), "veta": FUNDIDO},
        "adornos": [(brasa, (HIERRO, FUNDIDO), {})],
        "colgantes": [(gota, (FUNDIDO,), {}), (gota, ((255, 210, 120),), {"alto": 36})],
        "salientes": [],
        "juego": {"luz": (255, 205, 150), "sombra": (4, 4, 6), "alto_cara": 44, "entrada": 15,
                  "ondulacion": 10, "adornos_cada": 100, "colgantes_cada": 56, "salientes": 2},
    },
    10: {
        "nombre": "Nucleo externo interior: placas de hierro y niquel, astillas de metal",
        "muro": {"paleta": ACERO, "metal": (150, 166, 196), "luz": 0.24},
        "cara": {"estilo": "placas", "paleta": ACERO},
        "pilar": {"estilo": "columna", "paleta": ACERO, "bandas": (40, 46, 60)},
        "adornos": [(cristales, ((120, 136, 166),), {"ancho": 26, "alto": 26, "cuantos": 4, "brillo": 0,
                                                    "irregular": True})],
        "colgantes": [(gota, ((255, 190, 100),), {"alto": 26})],
        "salientes": [(cristales, ((110, 126, 156),), {"ancho": 66, "alto": 80, "cuantos": 6, "brillo": 0,
                                                       "irregular": True})],
        "juego": {"luz": (200, 216, 245), "sombra": (4, 6, 10), "alto_cara": 44, "entrada": 15,
                  "ondulacion": 10, "adornos_cada": 70, "colgantes_cada": 110, "salientes": 3},
    },
    11: {
        "nombre": "Limite del nucleo interno: hierro que cristaliza, plateado y caliente",
        "muro": {"paleta": PLATA, "celdas": 5, "facetas": True, "brillo": (255, 170, 90), "fuerza": 0.3,
                 "luz": 0.28},
        "cara": {"estilo": "cristalino", "paleta": PLATA, "brillo": (255, 170, 90), "lava": 1},
        "pilar": {"estilo": "obelisco", "paleta": PLATA},
        "adornos": [(cristales, ((176, 180, 196),), {"ancho": 26, "alto": 28, "cuantos": 4, "brillo": 0.3})],
        "colgantes": [(cristales, ((176, 180, 196),), {"ancho": 24, "alto": 32, "cuantos": 3, "hacia_abajo": True,
                                                      "brillo": 0.3})],
        "salientes": [(cristales, ((180, 184, 200),), {"ancho": 72, "alto": 90, "cuantos": 6, "brillo": 0.35}),
                      (cristales, ((200, 190, 180),), {"ancho": 62, "alto": 74, "cuantos": 5, "brillo": 0.35})],
        "juego": {"luz": (245, 235, 225), "sombra": (8, 8, 10), "alto_cara": 42, "entrada": 14,
                  "ondulacion": 10, "adornos_cada": 60, "colgantes_cada": 70, "salientes": 3},
    },
    12: {
        "nombre": "Nucleo interno: cristal de hierro al rojo blanco",
        "muro": {"paleta": ORO, "celdas": 5, "facetas": True, "brillo": BLANCO_CALIENTE, "fuerza": 0.7,
                 "luz": 0.3},
        "cara": {"estilo": "cristalino", "paleta": ORO, "brillo": BLANCO_CALIENTE, "lava": 1},
        "pilar": {"estilo": "obelisco", "paleta": ORO, "veta": BLANCO_CALIENTE},
        "adornos": [(cristales, ((255, 214, 140),), {"ancho": 26, "alto": 28, "cuantos": 4, "brillo": 0.6})],
        "colgantes": [(cristales, ((255, 214, 140),), {"ancho": 24, "alto": 32, "cuantos": 3, "hacia_abajo": True,
                                                      "brillo": 0.6})],
        "salientes": [(cristales, ((255, 220, 150),), {"ancho": 72, "alto": 92, "cuantos": 6, "brillo": 0.7}),
                      (cristales, ((255, 200, 120),), {"ancho": 62, "alto": 76, "cuantos": 5, "brillo": 0.7})],
        "juego": {"luz": (255, 245, 215), "sombra": (20, 8, 2), "alto_cara": 40, "entrada": 14,
                  "ondulacion": 9, "adornos_cada": 56, "colgantes_cada": 64, "salientes": 3},
    },
}


# --- Recurso para el juego --------------------------------------------------------

def _color_godot(c):
    return "Color(%.3f, %.3f, %.3f, 1)" % tuple(v / 255.0 for v in c)


def escribir_estilo(numero, carpeta, archivos, juego):
    """El EstiloBorde del piso: las texturas y los numeros de 'juego'."""
    ruta = "res://assets/bordes/piso_%02d/" % numero
    externos = [("Script", "res://scripts/estilo_borde.gd", "1_script")]
    ids = {}
    for nombre in archivos:
        clave = nombre.replace(".png", "")
        ids[clave] = "%d_%s" % (len(externos) + 1, clave)
        externos.append(("Texture2D", ruta + nombre, ids[clave]))

    def lista(prefijo):
        claves = sorted(c for c in ids if c.startswith(prefijo))
        return "Array[Texture2D]([%s])" % ", ".join('ExtResource("%s")' % ids[c] for c in claves)

    lineas = ['[gd_resource type="Resource" script_class="EstiloBorde" load_steps=%d format=3]' % (len(externos) + 1),
              ""]
    for tipo, camino, ident in externos:
        lineas.append('[ext_resource type="%s" path="%s" id="%s"]' % (tipo, camino, ident))
    lineas += ["", "[resource]", 'script = ExtResource("1_script")',
               'muro = ExtResource("%s")' % ids["muro"],
               'cara = ExtResource("%s")' % ids["cara"],
               'pilar = ExtResource("%s")' % ids["pilar"],
               "adornos = " + lista("adorno_"),
               "colgantes = " + lista("colgante_"),
               "salientes = " + lista("saliente_"),
               "color_luz = " + _color_godot(juego["luz"]),
               "color_sombra = " + _color_godot(juego["sombra"]),
               "alto_cara = %.1f" % juego["alto_cara"],
               "entrada = %.1f" % juego["entrada"],
               "ondulacion = %.1f" % juego["ondulacion"],
               "adornos_cada = %.1f" % juego["adornos_cada"],
               "colgantes_cada = %.1f" % juego["colgantes_cada"],
               "salientes_por_sala = %d" % juego["salientes"],
               ""]
    with open(os.path.join(carpeta, "estilo_borde.tres"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lineas))


def generar_piso(numero):
    t = TEMAS[numero]
    carpeta = os.path.join(SALIDA, "piso_%02d" % numero)
    os.makedirs(carpeta, exist_ok=True)
    # Lo de una vez anterior, fuera: si un tema tiene menos piezas que antes,
    # las sobrantes no se quedan colgando.
    for viejo in os.listdir(carpeta):
        if viejo.endswith(".png"):
            os.remove(os.path.join(carpeta, viejo))
    semilla = 1000 + numero * 101
    archivos = []

    def guardar(imagen, nombre):
        imagen.save(os.path.join(carpeta, nombre))
        archivos.append(nombre)

    guardar(textura_muro(t, semilla), "muro.png")
    guardar(textura_cara(t, semilla + 1), "cara.png")
    guardar(pilar(t, semilla + 2), "pilar.png")
    for grupo, prefijo in (("adornos", "adorno"), ("colgantes", "colgante"), ("salientes", "saliente")):
        for i, (funcion, argumentos, opciones) in enumerate(t[grupo]):
            g = random.Random(semilla * 7 + len(archivos) * 31)
            if funcion in (cono, columnas, roca, brasa):
                # Estas reciben la paleta y el generador en otro orden.
                if funcion is cono:
                    pieza = cono(argumentos[0], g, *argumentos[1:], **opciones)
                elif funcion is brasa:
                    pieza = brasa(argumentos[0], argumentos[1], g)
                else:
                    pieza = funcion(argumentos[0], g, **opciones)
            else:
                pieza = funcion(argumentos[0], g, **opciones)
            guardar(pieza, "%s_%d.png" % (prefijo, i))
    escribir_estilo(numero, carpeta, archivos, t["juego"])
    print("piso %2d: %s (%d archivos)" % (numero, t["nombre"], len(archivos)))


def main():
    os.makedirs(SALIDA, exist_ok=True)
    pisos = [int(a) for a in sys.argv[1:]] or sorted(TEMAS)
    if not sys.argv[1:]:
        generar_reja().save(os.path.join(SALIDA, "reja.png"))
        print("reja")
    for numero in pisos:
        generar_piso(numero)


if __name__ == "__main__":
    main()
