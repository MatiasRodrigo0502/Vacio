# -*- coding: utf-8 -*-
"""Dibuja los iconos de los objetos recogibles (assets/objetos/icono_*.png).

Pedido por Matias el 2026-11-03: «me gusta la sencillez del color, pero no me
convencen todos los dibujos». Se queda el color plano de cada uno (el de su
.tres: verde movimiento, azul disparo, naranja velocidad de bola, morado
tamano de bola, rojo vida) y cambia el dibujo: ahora cada objeto es un orbe
de su color, con un borde oscuro y un brillo, y dentro un simbolo blanco de lo
que hace. Asi todos se leen como "cosa que se coge" y se distinguen por el
color de lejos y por el simbolo de cerca.

- Botas ligeras (velocidad): una bota con dos rayas de prisa detras.
- Chispa veloz (disparar mas seguido): un rayo.
- Nucleo ardiente (bola mas rapida): un cometa, la bola con su estela.
- Orbe hinchado (bola mas grande): una bola con cuatro flechas hacia fuera.
- Vendaje (cura): una venda cruzada con su gasa.

Se dibuja a 4 veces el tamano y se reduce, para que los bordes salgan suaves.
Los antiguos (formas sueltas de color, sin orbe) estan en el historial de git.

    python herramientas/generar_iconos_objetos.py
"""
import math
import os

from PIL import Image, ImageDraw

RAIZ = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
DESTINO = os.path.join(RAIZ, "assets", "objetos")

LADO = 96
X = 4  # se dibuja a X veces y se reduce
L = LADO * X
C = L / 2
RADIO = 43 * X
BORDE = 4 * X
OSCURO = (28, 20, 18, 255)
BLANCO = (255, 250, 238, 255)
TRAZO = int(3.2 * X)

# Los del .tres de cada objeto (color), en 0-255.
COLORES = {
    "bota": (115, 230, 128),
    "rayo": (128, 191, 255),
    "llama": (255, 166, 64),
    "orbe": (204, 140, 255),
    "cruz": (242, 115, 115),
}


def mezclar(color, otro, t):
    return tuple(round(a + (b - a) * t) for a, b in zip(color, otro))


def orbe(color):
    """El orbe: borde oscuro, cuerpo del color, una media luna mas oscura
    abajo a la derecha (para que tenga volumen sin dejar de ser plano) y un
    brillo arriba a la izquierda."""
    imagen = Image.new("RGBA", (L, L), (0, 0, 0, 0))
    d = ImageDraw.Draw(imagen)
    d.ellipse([C - RADIO, C - RADIO, C + RADIO, C + RADIO], fill=OSCURO)
    r = RADIO - BORDE
    sombra = mezclar(color, (0, 0, 0), 0.22) + (255,)
    d.ellipse([C - r, C - r, C + r, C + r], fill=sombra)
    # El cuerpo, un poco hacia arriba a la izquierda: lo que queda a la
    # vista de la sombra es la media luna.
    cuerpo = r * 0.94
    dx = -r * 0.07
    d.ellipse([C + dx - cuerpo, C + dx - cuerpo, C + dx + cuerpo, C + dx + cuerpo], fill=tuple(color) + (255,))
    brillo = mezclar(color, (255, 255, 255), 0.55) + (255,)
    bx, by = C - r * 0.5, C - r * 0.55
    d.ellipse([bx - r * 0.2, by - r * 0.13, bx + r * 0.2, by + r * 0.13], fill=brillo)
    return imagen, d


def con_borde(d, puntos, relleno=BLANCO):
    """Un poligono blanco con el contorno oscuro, como el borde del orbe."""
    d.line(puntos + [puntos[0]], fill=OSCURO, width=TRAZO * 2, joint="curve")
    for x, y in puntos:
        d.ellipse([x - TRAZO, y - TRAZO, x + TRAZO, y + TRAZO], fill=OSCURO)
    d.polygon(puntos, fill=relleno)


def circulo(d, x, y, r, relleno=BLANCO):
    d.ellipse([x - r - TRAZO, y - r - TRAZO, x + r + TRAZO, y + r + TRAZO], fill=OSCURO)
    d.ellipse([x - r, y - r, x + r, y + r], fill=relleno)


def p(x, y):
    """De coordenadas de 96 x 96 a las del lienzo grande."""
    return (x * X, y * X)


def bota():
    """Una bota con tres rayas de prisa detras. (Con un ala en el talon se
    probo: a este tamano las plumas parecian dedos.)"""
    imagen, d = orbe(COLORES["bota"])
    oscuro = mezclar(COLORES["bota"], (0, 0, 0), 0.35) + (255,)
    for y, x0, largo in ((34, 22, 11), (45, 17, 15), (56, 22, 11)):
        d.line([p(x0, y), p(x0 + largo, y)], fill=OSCURO, width=int(7 * X))
        for x in (x0, x0 + largo):
            d.ellipse([p(x - 3.5, y - 3.5), p(x + 3.5, y + 3.5)], fill=OSCURO)
        d.line([p(x0, y), p(x0 + largo, y)], fill=BLANCO, width=int(3.4 * X))
        for x in (x0, x0 + largo):
            d.ellipse([p(x - 1.7, y - 1.7), p(x + 1.7, y + 1.7)], fill=BLANCO)
    # La bota: cana con la boca mas ancha, empeine y puntera redondeada.
    con_borde(d, [p(39, 22), p(56, 22), p(54, 46), p(66, 51), p(72, 57), p(72, 66), p(40, 66)])
    # La vuelta de arriba y la suela, del color del orbe, para que se lea
    # que es una bota y no una L.
    d.line([p(41, 29), p(54, 29)], fill=oscuro, width=int(3 * X))
    d.line([p(42, 62), p(70, 62)], fill=oscuro, width=int(3 * X))
    return imagen


def rayo():
    imagen, d = orbe(COLORES["rayo"])
    con_borde(d, [p(53, 18), p(32, 52), p(46, 52), p(40, 78), p(64, 42), p(50, 42), p(58, 18)])
    return imagen


def llama():
    """Un cometa: la bola delante y la estela detras, que se afina."""
    imagen, d = orbe(COLORES["llama"])
    # La estela, de fuego: tres lenguas que salen de la bola hacia abajo a la
    # izquierda, la del medio mas larga. Con una cola recta se leia como un
    # cucurucho de helado.
    cx, cy, r = 60, 38, 12
    atras = (-math.sqrt(0.5), math.sqrt(0.5))
    lado = (math.sqrt(0.5), math.sqrt(0.5))

    def punto(de_lado, de_atras):
        return p(cx + lado[0] * de_lado + atras[0] * de_atras,
                 cy + lado[1] * de_lado + atras[1] * de_atras)

    con_borde(d, [punto(r, 0), punto(10, 26), punto(4, 18), punto(0, 36),
                  punto(-4, 18), punto(-10, 26), punto(-r, 0)])
    circulo(d, *p(cx, cy), r * X)
    return imagen


def orbe_hinchado():
    imagen, d = orbe(COLORES["orbe"])
    circulo(d, *p(48, 48), 12 * X)
    # Cuatro flechas hacia fuera, en diagonal: la bola crece.
    for angulo in (45, 135, 225, 315):
        a = math.radians(angulo)
        dx, dy = math.cos(a), math.sin(a)
        punta = (48 + dx * 33, 48 + dy * 33)
        base = (48 + dx * 22, 48 + dy * 22)
        lado = (-dy * 7, dx * 7)
        con_borde(d, [p(*punta), p(base[0] + lado[0], base[1] + lado[1]),
                      p(base[0] - lado[0], base[1] - lado[1])])
    return imagen


def cruz():
    """Una tirita: una venda en diagonal con la gasa en medio. Era una cruz;
    dos vendas en X se leian como un «no»."""
    imagen, d = orbe(COLORES["cruz"])
    dx, dy = 22 * math.sqrt(0.5), -22 * math.sqrt(0.5)
    a, b = (48 - dx, 48 - dy), (48 + dx, 48 + dy)
    d.line([p(*a), p(*b)], fill=OSCURO, width=int(25 * X))
    for sx, sy in (a, b):
        d.ellipse([p(sx - 12.5, sy - 12.5), p(sx + 12.5, sy + 12.5)], fill=OSCURO)
    d.line([p(*a), p(*b)], fill=BLANCO, width=int(18 * X))
    for sx, sy in (a, b):
        d.ellipse([p(sx - 9, sy - 9), p(sx + 9, sy + 9)], fill=BLANCO)
    # La gasa, un cuadrado girado del color del orbe con sus agujeritos.
    gasa = mezclar(COLORES["cruz"], (255, 255, 255), 0.45) + (255,)
    con_borde(d, [p(48, 37), p(59, 48), p(48, 59), p(37, 48)], gasa)
    agujero = mezclar(COLORES["cruz"], (0, 0, 0), 0.2) + (255,)
    for x, y in ((48, 43), (53, 48), (48, 53), (43, 48)):
        d.ellipse([p(x - 1.4, y - 1.4), p(x + 1.4, y + 1.4)], fill=agujero)
    return imagen


ICONOS = {
    "bota": bota,
    "rayo": rayo,
    "llama": llama,
    "orbe": orbe_hinchado,
    "cruz": cruz,
}


def main():
    for nombre, dibujar in ICONOS.items():
        grande = dibujar()
        pequeno = grande.convert("RGBa").resize((LADO, LADO), Image.LANCZOS).convert("RGBA")
        pequeno.save(os.path.join(DESTINO, "icono_%s.png" % nombre))
        print("icono_%s.png" % nombre)


if __name__ == "__main__":
    main()
