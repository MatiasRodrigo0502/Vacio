# -*- coding: utf-8 -*-
"""Genera el arte del borde de las salas en assets/bordes/.

- muro.png: roca maciza vista desde arriba, que se repite sin costuras. Rellena
  la franja del muro detras de las rocas del borde: sin ella, entre roca y roca
  asomaba negro.
- pilar.png: pilar de piedra en 3/4, uno a cada lado de cada puerta.
- reja.png: el rastrillo de hierro que cierra una puerta, con las puntas abajo.

Mismo estilo que los packs del manto y del nucleo: volumen con luz de arriba a
la izquierda, contorno oscuro y alguna veta incandescente. Casi todo en grises:
el juego lo tine con el color de cada piso, como las rocas.

Solo PIL y semillas fijas: volver a ejecutarlo da los mismos PNG.

    python herramientas/generar_bordes.py
"""
import math
import os
import random

from PIL import Image, ImageDraw

RAIZ = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SALIDA = os.path.join(RAIZ, "assets", "bordes")
SUPER = 2
CONTORNO = (16, 12, 15)
LUZ = (-0.45, -0.65, 0.6)
_l = math.sqrt(sum(v * v for v in LUZ))
LUZ = tuple(v / _l for v in LUZ)


# --- Ruido que se repite (para que el muro no tenga costuras) ------------------

def _hash(x, y, semilla):
    n = (x * 374761393 + y * 668265263 + semilla * 1442695041) & 0xFFFFFFFF
    n = ((n ^ (n >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 0xFFFF) / 65535.0


def ruido_periodico(x, y, periodo, semilla):
    """Ruido de valor que se repite cada 'periodo' celdas en x y en y."""
    xi, yi = math.floor(x), math.floor(y)
    fx, fy = x - xi, y - yi
    fx = fx * fx * (3 - 2 * fx)
    fy = fy * fy * (3 - 2 * fy)
    x0, y0 = xi % periodo, yi % periodo
    x1, y1 = (xi + 1) % periodo, (yi + 1) % periodo
    a = _hash(x0, y0, semilla)
    b = _hash(x1, y0, semilla)
    c = _hash(x0, y1, semilla)
    d = _hash(x1, y1, semilla)
    return a + (b - a) * fx + (c - a) * fy + (a - b - c + d) * fx * fy


def fbm_periodico(x, y, periodo, semilla, octavas=3):
    total, amplitud, suma = 0.0, 1.0, 0.0
    for o in range(octavas):
        total += ruido_periodico(x, y, periodo, semilla + o * 17) * amplitud
        suma += amplitud
        x, y, periodo, amplitud = x * 2, y * 2, periodo * 2, amplitud * 0.5
    return total / suma


def mezclar(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(len(a)))


def a_bytes(color):
    return tuple(int(max(0, min(255, round(c)))) for c in color)


# --- Muro ---------------------------------------------------------------------

def generar_muro(semilla=11, lado_final=256):
    """Bloques de roca apinados, vistos desde arriba: la cara de arriba plana,
    los cantos biselados (el de arriba a la izquierda coge luz, el de abajo a
    la derecha queda en sombra) y grietas oscuras entre ellos.

    Voronoi sobre un toro: el punto mas cercano se busca tambien en las copias
    de los lados, y asi el borde derecho casa con el izquierdo y el de arriba
    con el de abajo."""
    lado = lado_final * SUPER
    aleatorio = random.Random(semilla)
    puntos = [(aleatorio.uniform(0, lado), aleatorio.uniform(0, lado), aleatorio.uniform(0.8, 1.15))
              for _ in range(22)]
    copias = []
    for px, py, tono in puntos:
        for dx in (-lado, 0, lado):
            for dy in (-lado, 0, lado):
                copias.append((px + dx, py + dy, tono))
    periodo = 8
    escala = periodo / lado
    grieta = 2.0 * SUPER
    bisel = 9.0 * SUPER
    imagen = Image.new("RGB", (lado, lado))
    pixeles = imagen.load()
    for y in range(lado):
        for x in range(lado):
            d1, d2, cerca = 1e18, 1e18, None
            for px, py, tono in copias:
                d = (x - px) ** 2 + (y - py) ** 2
                if d < d1:
                    d2, d1, cerca = d1, d, (px, py, tono)
                elif d < d2:
                    d2 = d
            junta = math.sqrt(d2) - math.sqrt(d1)
            grano = 0.88 + 0.24 * fbm_periodico(x * escala * 4, y * escala * 4, periodo * 4, semilla)
            mancha = 0.85 + 0.3 * fbm_periodico(x * escala, y * escala, periodo, semilla + 5)
            if junta < grieta:
                valor = 48 + 18 * junta / grieta
            else:
                # Cara de arriba plana y cantos que caen hacia la grieta. La
                # normal del canto apunta hacia fuera del bloque.
                caida = max(0.0, 1.0 - (junta - grieta) / bisel)
                fuera_x, fuera_y = x - cerca[0], y - cerca[1]
                largo = max(math.hypot(fuera_x, fuera_y), 1e-6)
                nx = fuera_x / largo * caida * 0.85
                ny = fuera_y / largo * caida * 0.85
                nz = math.sqrt(max(0.0, 1.0 - nx * nx - ny * ny))
                brillo = nx * LUZ[0] + ny * LUZ[1] + nz * LUZ[2]
                # Contraste contenido a proposito: es fondo. Con mas, los
                # bloques se leian como un caparazon y competian con la sala.
                valor = (72 + 68 * brillo) * cerca[2] * mancha
            valor *= grano
            pixeles[x, y] = a_bytes((valor, valor * 0.96, valor * 1.03))
    return imagen.resize((lado_final, lado_final), Image.LANCZOS)


# --- Pilar --------------------------------------------------------------------

# La paleta de las rocas del manto, para que el pilar sea de la misma piedra.
ROCA_ARRIBA = (104, 92, 108)
ROCA_ABAJO = (34, 28, 38)
CARA_ARRIBA = (150, 136, 152)


def _caja(pixeles, x0, x1, y_tapa, y0, y1, semilla, veta=False):
    """Un bloque de piedra en 3/4: la tapa (cara de arriba, clara) de y_tapa a
    y0 y el frente de y0 a y1. Luz de arriba a la izquierda."""
    for y in range(int(y_tapa), int(y1)):
        for x in range(int(x0), int(x1)):
            u = (x - x0) / max(x1 - x0 - 1, 1)
            grano = 0.86 + 0.28 * _hash(x // 2, y // 2, semilla)
            if y < y0:
                t = (y - y_tapa) / max(y0 - y_tapa, 1)
                c = mezclar(CARA_ARRIBA, mezclar(CARA_ARRIBA, ROCA_ARRIBA, 0.5), t)
            else:
                t = (y - y0) / max(y1 - y0, 1)
                c = mezclar(ROCA_ARRIBA, ROCA_ABAJO, 0.15 + 0.7 * t)
                # Canto izquierdo iluminado, derecho en sombra.
                if u < 0.12:
                    c = mezclar(c, CARA_ARRIBA, 0.45)
                elif u > 0.86:
                    c = tuple(v * 0.6 for v in c)
                if veta and abs((x - (x0 + x1) / 2) * 0.8 - (y - (y0 + y1) / 2) * 0.45
                               + 5 * math.sin(y * 0.09)) < 1.2 * SUPER and 0.2 < u < 0.8:
                    c = mezclar(c, (255, 140, 50), 0.9)
            c = tuple(v * grano for v in c)
            pixeles[x, y] = a_bytes(c) + (255,)


def generar_pilar(ancho_final=48, alto_final=88, semilla=3):
    """Pilar de bloques de piedra apilados en 3/4: una losa ancha arriba, tres
    bloques de fuste con sus juntas, y una basa ancha abajo. Una veta
    incandescente como las rocas del manto."""
    ancho, alto = ancho_final * SUPER, alto_final * SUPER
    imagen = Image.new("RGBA", (ancho, alto), (0, 0, 0, 0))
    pixeles = imagen.load()
    borde = 2 * SUPER
    fuste = 6 * SUPER            # cuanto mas estrecho es el fuste que las losas
    tapa = 9 * SUPER             # alto de la cara de arriba
    y = borde
    # Losa de arriba (capitel).
    _caja(pixeles, borde, ancho - borde, y, y + tapa, y + tapa + 11 * SUPER, semilla)
    y += tapa + 11 * SUPER
    # Tres bloques de fuste, cada uno un poco distinto.
    alto_fuste = alto - borde - y - 15 * SUPER
    for i in range(3):
        alto_bloque = alto_fuste / 3.0
        desvio = (_hash(i, 7, semilla) - 0.5) * 3 * SUPER
        _caja(pixeles, borde + fuste + desvio, ancho - borde - fuste + desvio, y, y, y + alto_bloque - SUPER,
              semilla + i, veta=(i == 1))
        y += alto_bloque
    # Basa: losa ancha con un poco de tapa asomando.
    _caja(pixeles, borde, ancho - borde, y, y + 3 * SUPER, alto - borde, semilla + 9)

    # Contorno oscuro alrededor de todo lo pintado.
    alfa = imagen.getchannel("A")
    contorno = Image.new("RGBA", (ancho, alto), (0, 0, 0, 0))
    cp = contorno.load()
    ap = alfa.load()
    for yy in range(alto):
        for xx in range(ancho):
            if ap[xx, yy] > 0:
                continue
            for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1), (-2, 0), (2, 0), (0, -2), (0, 2)):
                vx, vy = xx + dx, yy + dy
                if 0 <= vx < ancho and 0 <= vy < alto and ap[vx, vy] > 0:
                    cp[xx, yy] = CONTORNO + (255,)
                    break
    imagen = Image.alpha_composite(contorno, imagen)
    return imagen.resize((ancho_final, alto_final), Image.LANCZOS)


# --- Reja ---------------------------------------------------------------------

def generar_reja(ancho_final=130, alto_final=64):
    """Rastrillo de hierro, con las puntas abajo. Barrotes redondos con su
    brillo, dos travesanos con remaches y un contorno oscuro."""
    ancho, alto = ancho_final * SUPER, alto_final * SUPER
    imagen = Image.new("RGBA", (ancho, alto), (0, 0, 0, 0))
    pixeles = imagen.load()
    barrotes = 7
    grosor = 6.5 * SUPER
    paso = ancho / barrotes
    punta = 11 * SUPER
    travesanos = [alto * 0.2, alto * 0.62]
    ancho_trav = 5 * SUPER
    oscuro, claro = (30, 30, 36), (170, 172, 184)

    def metal(u):
        luz = 0.5 - 0.45 * u + 0.25 * (1 - u * u)
        c = mezclar(oscuro, claro, luz)
        return mezclar(c, (255, 255, 255), math.exp(-((u + 0.45) / 0.14) ** 2) * 0.5)

    for y in range(alto):
        for x in range(ancho):
            c = None
            # Travesanos: por detras de los barrotes.
            for t in travesanos:
                v = (y - t) / (ancho_trav / 2)
                if abs(v) <= 1.0:
                    c = metal(v * 0.8) if abs(v) < 0.8 else CONTORNO
            # Barrotes, con punta abajo.
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
                elif abs(u) <= 1.0 + 1.2 * SUPER / max(w, 1.0):
                    c = CONTORNO
            if c is not None:
                pixeles[x, y] = a_bytes(c) + (255,)
    # Remaches en los cruces.
    dibujo = ImageDraw.Draw(imagen)
    for i in range(barrotes):
        cx = (i + 0.5) * paso
        for t in travesanos:
            r = 3.2 * SUPER
            dibujo.ellipse((cx - r, t - r, cx + r, t + r), fill=CONTORNO + (255,))
            dibujo.ellipse((cx - r + SUPER, t - r + SUPER, cx + r - SUPER, t + r - SUPER), fill=(120, 120, 130, 255))
            dibujo.ellipse((cx - r * 0.6, t - r * 0.6, cx, t), fill=(210, 210, 220, 255))
    return imagen.resize((ancho_final, alto_final), Image.LANCZOS)


def main():
    os.makedirs(SALIDA, exist_ok=True)
    generar_muro().save(os.path.join(SALIDA, "muro.png"))
    print("muro")
    generar_pilar().save(os.path.join(SALIDA, "pilar.png"))
    print("pilar")
    generar_reja().save(os.path.join(SALIDA, "reja.png"))
    print("reja")


if __name__ == "__main__":
    main()
