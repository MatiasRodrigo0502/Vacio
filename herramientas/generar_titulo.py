# -*- coding: utf-8 -*-
"""Genera el titulo del menu, VACIO, en pixel art: letras de piedra tallada
con grietas de lava y estalactitas colgando.

POR QUE DIBUJADO Y NO CON UNA FUENTE:
los magos son pixel art, y unas letras de una fuente lisa al lado se veian de
otro juego. Ademas asi no hay que bajar ni licenciar ninguna fuente: son cinco
letras, hechas con poligonos en una rejilla pequena y ampliadas sin suavizar,
igual que los sprites. La piedra y la lava son las del juego: se baja por
capas de roca hasta el nucleo, que arde.

Salen dos imagenes del mismo tamano, que el menu pone una encima de otra:

- assets/titulo/titulo.png: las letras, con su sombra.
- assets/titulo/titulo_brillo.png: el resplandor de la lava, suave. Va aparte
  para que el menu lo haga latir sin tocar las letras.

Es determinista (semilla fija): sale siempre igual.

    python herramientas/generar_titulo.py
"""
import os
import random

from PIL import Image, ImageDraw, ImageFilter

RAIZ = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
DESTINO = os.path.join(RAIZ, "assets", "titulo")

## Cada pixel del dibujo son ESCALA pixeles de la imagen. Los magos del menu
## van a x2 y sus pixeles son mas finos; el titulo, mas grueso, manda.
ESCALA = 4
ALTO = 24          # alto de las letras, en pixeles del dibujo
ARRIBA = 11        # sitio encima para la tilde de la I
ABAJO = 9          # sitio debajo para las estalactitas
MARGEN = 8         # a los lados, para el resplandor
SEPARACION = 4

# Piedra: clara arriba y oscura abajo, como la luz que llega desde arriba.
PIEDRA_ARRIBA = (222, 208, 190)
PIEDRA_ABAJO = (112, 86, 78)
CONTORNO = (28, 16, 20)
SOMBRA = (10, 6, 10)
LAVA = (255, 132, 40)
LAVA_CLARA = (255, 226, 150)
RESPLANDOR = (255, 96, 30)


# --- Las letras: poligonos en una caja de 'ancho' x ALTO -------------------

def octogono(x0, y0, x1, y1, corte):
    return [(x0 + corte, y0), (x1 - corte, y0), (x1, y0 + corte), (x1, y1 - corte),
            (x1 - corte, y1), (x0 + corte, y1), (x0, y1 - corte), (x0, y0 + corte)]


def letra_v(d):
    d.polygon([(0, 0), (7, 0), (10, 14), (13, 0), (20, 0), (12, 23), (8, 23)], fill=255)
    return 21


def letra_a(d):
    d.polygon([(8, 0), (12, 0), (20, 23), (14, 23), (13, 19), (7, 19), (6, 23), (0, 23)], fill=255)
    d.polygon([(10, 7), (12, 14), (8, 14)], fill=0)
    return 21


def letra_c(d):
    d.polygon(octogono(0, 0, 19, 23, 6), fill=255)
    d.polygon(octogono(6, 6, 13, 17, 2), fill=0)
    # La boca, con los extremos cortados en bisel.
    d.polygon([(11, 9), (20, 6), (20, 17), (11, 14)], fill=0)
    return 20


def letra_i_tilde(d):
    d.rectangle([1, 0, 7, 23], fill=255)
    # Remates arriba y abajo: le dan peso de piedra tallada.
    d.rectangle([0, 0, 8, 3], fill=255)
    d.rectangle([0, 20, 8, 23], fill=255)
    # La tilde, inclinada, por encima de la letra.
    d.polygon([(4, -3), (9, -9), (11, -7), (6, -2)], fill=255)
    return 9


def letra_o(d):
    d.polygon(octogono(0, 0, 19, 23, 6), fill=255)
    d.polygon(octogono(6, 6, 13, 17, 2), fill=0)
    return 20


LETRAS = [letra_v, letra_a, letra_c, letra_i_tilde, letra_o]


class Desplazado:
    """Un ImageDraw que suma (dx, dy) a todo: cada letra se dibuja como si
    empezara en (0, 0)."""

    def __init__(self, dibujo, dx, dy):
        self.d, self.dx, self.dy = dibujo, dx, dy

    def _mover(self, puntos):
        return [(x + self.dx, y + self.dy) for x, y in puntos]

    def polygon(self, puntos, fill):
        self.d.polygon(self._mover(puntos), fill=fill)

    def rectangle(self, caja, fill):
        x0, y0, x1, y1 = caja
        self.d.rectangle([x0 + self.dx, y0 + self.dy, x1 + self.dx, y1 + self.dy], fill=fill)


def silueta():
    """La mascara de las cinco letras, en pixeles del dibujo."""
    ancho_letras = 0
    # Primero se mide en un lienzo de prueba, para saber el ancho total.
    prueba = Image.new("L", (400, 80), 0)
    anchos = [f(Desplazado(ImageDraw.Draw(prueba), 0, 30)) for f in LETRAS]
    ancho_letras = sum(anchos) + SEPARACION * (len(anchos) - 1)
    ancho = ancho_letras + MARGEN * 2
    alto = ARRIBA + ALTO + ABAJO
    mascara = Image.new("L", (ancho, alto), 0)
    dibujo = ImageDraw.Draw(mascara)
    x = MARGEN
    for f, a in zip(LETRAS, anchos):
        f(Desplazado(dibujo, x, ARRIBA))
        x += a + SEPARACION
    return mascara


def lleno(m, x, y):
    return 0 <= x < m.width and 0 <= y < m.height and m.getpixel((x, y)) > 0


def estalactitas(mascara, azar):
    """Puntas de roca que cuelgan del borde de abajo de las letras: el titulo
    cuelga como el techo de una cueva."""
    base = mascara.copy()
    for x in range(base.width):
        for y in range(ARRIBA + 14, ARRIBA + ALTO):
            # Borde de abajo: lleno y vacio justo debajo.
            if not lleno(base, x, y) or lleno(base, x, y + 1):
                continue
            if azar.random() > 0.22:
                continue
            largo = azar.choice([2, 3, 3, 4, 5, 6])
            for k in range(1, largo + 1):
                mascara.putpixel((x, y + k), 255)
                # Mas gruesa arriba: dos pixeles en la primera mitad.
                if k <= largo // 2 and lleno(base, x + 1, y):
                    mascara.putpixel((x + 1, y + k), 255)
    return mascara


def ruido(azar, ancho, alto):
    return [[azar.uniform(-1.0, 1.0) for _ in range(ancho)] for _ in range(alto)]


def grietas(mascara, azar):
    """Grietas de lava: caminos que bajan en zigzag por dentro de la piedra,
    lejos del borde (en el borde parecerian el contorno)."""
    lava = set()
    interior = [(x, y) for y in range(ARRIBA, ARRIBA + ALTO) for x in range(mascara.width)
                if all(lleno(mascara, x + dx, y + dy) for dx in (-1, 0, 1) for dy in (-1, 0, 1))]
    azar.shuffle(interior)
    for x, y in interior[:11]:
        for _ in range(azar.randint(6, 12)):
            if not all(lleno(mascara, x + dx, y + dy) for dx in (-1, 0, 1) for dy in (-1, 0, 1)):
                break
            lava.add((x, y))
            paso = azar.choice([-1, 0, 0, 1])
            # Al torcer se pinta tambien el de al lado: si no, la grieta
            # queda en puntos sueltos que se tocan solo por la esquina.
            if paso:
                lava.add((x + paso, y))
            y += 1
            x += paso
    return lava


def pintar(mascara, lava, azar):
    ancho, alto = mascara.size
    letras = Image.new("RGBA", (ancho, alto), (0, 0, 0, 0))
    grano = ruido(azar, ancho, alto)
    for y in range(alto):
        for x in range(ancho):
            if not lleno(mascara, x, y):
                # Contorno oscuro de un pixel alrededor de la piedra.
                if any(lleno(mascara, x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    letras.putpixel((x, y), CONTORNO + (255,))
                continue
            if (x, y) in lava:
                caliente = (x + y) % 3 == 0
                letras.putpixel((x, y), (LAVA_CLARA if caliente else LAVA) + (255,))
                continue
            t = min(1.0, max(0.0, (y - ARRIBA + 4) / (ALTO + 4)))
            color = [PIEDRA_ARRIBA[i] + (PIEDRA_ABAJO[i] - PIEDRA_ARRIBA[i]) * t for i in range(3)]
            luz = grano[y][x] * 10
            # Tallado: el canto de arriba y el izquierdo cogen luz, el de
            # abajo y el derecho quedan en sombra.
            if not lleno(mascara, x, y - 1):
                luz += 34
            elif not lleno(mascara, x - 1, y):
                luz += 16
            if not lleno(mascara, x, y + 1):
                luz -= 40
            elif not lleno(mascara, x + 1, y):
                luz -= 22
            # Junto a la lava la piedra se calienta.
            if any((x + dx, y + dy) in lava for dx in (-1, 0, 1) for dy in (-1, 0, 1)):
                color = [color[0] + 40, color[1] + 8, color[2] - 10]
            letras.putpixel((x, y), tuple(int(max(0, min(255, c + luz))) for c in color) + (255,))
    # Sombra: la silueta, corrida abajo a la derecha, detras de todo.
    sombra = Image.new("RGBA", (ancho, alto), (0, 0, 0, 0))
    for y in range(alto):
        for x in range(ancho):
            if letras.getpixel((x, y))[3] > 0 and x + 1 < ancho and y + 2 < alto:
                sombra.putpixel((x + 1, y + 2), SOMBRA + (170,))
    return Image.alpha_composite(sombra, letras)


def brillo(mascara, lava):
    """El resplandor, a tamano final y suave: alrededor de las letras, flojo,
    y mas fuerte donde hay lava."""
    ancho, alto = mascara.size[0] * ESCALA, mascara.size[1] * ESCALA
    fuente = Image.new("L", mascara.size, 0)
    for y in range(mascara.height):
        for x in range(mascara.width):
            if lleno(mascara, x, y):
                fuente.putpixel((x, y), 70)
    for x, y in lava:
        fuente.putpixel((x, y), 255)
    fuente = fuente.resize((ancho, alto), Image.NEAREST).filter(ImageFilter.GaussianBlur(ESCALA * 3))
    capa = Image.new("RGBA", (ancho, alto), RESPLANDOR + (0,))
    capa.putalpha(fuente.point(lambda v: min(255, int(v * 1.6))))
    return capa


def main():
    azar = random.Random(12)
    mascara = estalactitas(silueta(), azar)
    lava = grietas(mascara, azar)
    letras = pintar(mascara, lava, azar)
    grande = (letras.width * ESCALA, letras.height * ESCALA)
    os.makedirs(DESTINO, exist_ok=True)
    letras.resize(grande, Image.NEAREST).save(os.path.join(DESTINO, "titulo.png"))
    brillo(mascara, lava).save(os.path.join(DESTINO, "titulo_brillo.png"))
    print("titulo: %dx%d" % grande)


if __name__ == "__main__":
    main()
