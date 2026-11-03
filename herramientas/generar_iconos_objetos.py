# -*- coding: utf-8 -*-
"""Dibuja los iconos de los objetos recogibles (assets/objetos/icono_*.png).

Pedido por Matias el 2026-11-03, en dos pasos. Primero: «me gusta la
sencillez del color, pero no me convencen todos los dibujos» (se cambiaron
los dibujos y se metieron en un orbe de su color con el simbolo en blanco).
Luego: «que sea minimalista: que el dibujo solo tenga uno o dos tonos de un
solo color, que se pinte el dibujo (lo que era blanco) y se deje
transparente entre la circunferencia exterior y el dibujo».

Asi que cada icono es un aro del color del objeto (el de su .tres: verde
movimiento, azul disparo, naranja velocidad de bola, morado tamano de bola,
rojo vida) y, dentro, el simbolo pintado de ese mismo color, con su borde y
sus detalles en un tono mas oscuro del mismo color. Entre el aro y el
simbolo no hay nada: se ve el suelo.

- Botas ligeras (velocidad): una bota con tres rayas de prisa detras.
- Chispa veloz (disparar mas seguido): un rayo.
- Nucleo ardiente (bola mas rapida): una bola de fuego.
- Orbe hinchado (bola mas grande): una bola con cuatro flechas hacia fuera.
- Vendaje (cura): una tirita.

Se dibuja a 4 veces el tamano y se reduce, para que los bordes salgan suaves.
Los de antes estan en el historial de git.

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
RADIO_ARO = 43 * X
GROSOR_ARO = 5 * X
TRAZO = int(2.6 * X)
# Lo que se oscurece el color para el segundo tono (borde y detalles).
OSCURECER = 0.5

# Los del .tres de cada objeto (color), en 0-255.
COLORES = {
    "bota": (115, 230, 128),
    "rayo": (128, 191, 255),
    "llama": (255, 166, 64),
    "orbe": (204, 140, 255),
    "cruz": (242, 115, 115),
}


class Pincel:
    """Los dos tonos de un objeto y como pintar con ellos."""

    def __init__(self, color):
        self.imagen = Image.new("RGBA", (L, L), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.imagen)
        self.tono = tuple(color) + (255,)
        self.sombra = tuple(round(c * (1.0 - OSCURECER)) for c in color) + (255,)
        # El aro de fuera: un borde oscuro fino y el aro del color encima.
        self.d.ellipse([C - RADIO_ARO, C - RADIO_ARO, C + RADIO_ARO, C + RADIO_ARO],
                       outline=self.sombra, width=GROSOR_ARO + TRAZO)
        r = RADIO_ARO - TRAZO * 0.5
        self.d.ellipse([C - r, C - r, C + r, C + r], outline=self.tono, width=GROSOR_ARO)

    def poligono(self, puntos, relleno=None):
        """Del color, con el borde en el tono oscuro."""
        self.d.line(puntos + [puntos[0]], fill=self.sombra, width=TRAZO * 2, joint="curve")
        for x, y in puntos:
            self.d.ellipse([x - TRAZO, y - TRAZO, x + TRAZO, y + TRAZO], fill=self.sombra)
        self.d.polygon(puntos, fill=relleno or self.tono)

    def circulo(self, x, y, r):
        self.d.ellipse([x - r - TRAZO, y - r - TRAZO, x + r + TRAZO, y + r + TRAZO], fill=self.sombra)
        self.d.ellipse([x - r, y - r, x + r, y + r], fill=self.tono)

    def raya(self, a, b, grueso):
        """Una raya redondeada del color, con su borde oscuro."""
        for color, ancho in ((self.sombra, grueso + TRAZO * 2 / X), (self.tono, grueso)):
            self.d.line([p(*a), p(*b)], fill=color, width=int(ancho * X))
            for x, y in (a, b):
                r = ancho / 2
                self.d.ellipse([p(x - r, y - r), p(x + r, y + r)], fill=color)

    def detalle(self, a, b, grueso=3.0):
        """Una linea fina en el tono oscuro, encima del dibujo."""
        self.d.line([p(*a), p(*b)], fill=self.sombra, width=int(grueso * X))


def p(x, y):
    """De coordenadas de 96 x 96 a las del lienzo grande."""
    return (x * X, y * X)


def bota():
    pincel = Pincel(COLORES["bota"])
    for y, x0, largo in ((34, 22, 11), (45, 17, 15), (56, 22, 11)):
        pincel.raya((x0, y), (x0 + largo, y), 3.6)
    pincel.poligono([p(39, 22), p(56, 22), p(54, 46), p(66, 51), p(72, 57), p(72, 66), p(40, 66)])
    # La vuelta de arriba y la suela: que se lea que es una bota y no una L.
    pincel.detalle((41, 29), (54, 29))
    pincel.detalle((42, 62), (70, 62))
    return pincel.imagen


def rayo():
    pincel = Pincel(COLORES["rayo"])
    pincel.poligono([p(53, 18), p(32, 52), p(46, 52), p(40, 78), p(64, 42), p(50, 42), p(58, 18)])
    return pincel.imagen


def llama():
    """Una bola de fuego: la bola y tres lenguas detras, hacia abajo a la
    izquierda, la del medio mas larga. (Con una cola recta se leia como un
    cucurucho de helado.)"""
    pincel = Pincel(COLORES["llama"])
    cx, cy, r = 60, 38, 12
    atras = (-math.sqrt(0.5), math.sqrt(0.5))
    lado = (math.sqrt(0.5), math.sqrt(0.5))

    def punto(de_lado, de_atras):
        return p(cx + lado[0] * de_lado + atras[0] * de_atras,
                 cy + lado[1] * de_lado + atras[1] * de_atras)

    pincel.poligono([punto(r, 0), punto(10, 26), punto(4, 18), punto(0, 36),
                     punto(-4, 18), punto(-10, 26), punto(-r, 0)])
    pincel.circulo(*p(cx, cy), r * X)
    return pincel.imagen


def orbe_hinchado():
    pincel = Pincel(COLORES["orbe"])
    pincel.circulo(*p(48, 48), 12 * X)
    # Cuatro flechas hacia fuera, en diagonal: la bola crece.
    for angulo in (45, 135, 225, 315):
        a = math.radians(angulo)
        dx, dy = math.cos(a), math.sin(a)
        punta = (48 + dx * 33, 48 + dy * 33)
        base = (48 + dx * 22, 48 + dy * 22)
        lado = (-dy * 7, dx * 7)
        pincel.poligono([p(*punta), p(base[0] + lado[0], base[1] + lado[1]),
                         p(base[0] - lado[0], base[1] - lado[1])])
    return pincel.imagen


def cruz():
    """La cruz de curar, hecha con dos tiritas, y la gasa en medio. Una
    tirita sola en diagonal, dentro del aro, era la senal de prohibido; dos
    en X se leian como un «no»."""
    pincel = Pincel(COLORES["cruz"])
    pincel.raya((48, 27), (48, 69), 16)
    pincel.raya((27, 48), (69, 48), 16)
    # La gasa, en el tono oscuro, con sus agujeritos del color.
    pincel.poligono([p(41, 41), p(55, 41), p(55, 55), p(41, 55)], pincel.sombra)
    for x, y in ((45, 45), (51, 45), (45, 51), (51, 51)):
        pincel.d.ellipse([p(x - 1.5, y - 1.5), p(x + 1.5, y + 1.5)], fill=pincel.tono)
    return pincel.imagen


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
