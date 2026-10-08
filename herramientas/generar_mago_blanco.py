# -*- coding: utf-8 -*-
"""Genera el mago blanco a partir del mago rojo, cambiando su paleta.

La hoja del mago rojo es pixel art con solo 25 colores, asi que basta con
cambiar unos colores por otros, uno a uno: las 48 poses (8 direcciones x 6
pasos), el centrado de cada direccion y la animacion quedan exactamente
iguales. Lo que cambia:

- la tunica y el sombrero: de rojo a blanco, con las sombras frias (azul
  grisaceo), que es lo que hace que el blanco no se vea plano;
- el orbe del baculo, su resplandor y los ojos: de fuego a hielo, a juego con
  su ataque, que ralentiza;
- se quedan el ribete dorado, el baculo de madera, la barba, las manos y las
  botas.

Salen assets/mago_blanco/atlas_8dir.png y retrato.png. El SpriteFrames es el
del mago rojo con las rutas cambiadas: misma hoja, mismos recortes.

    python herramientas/generar_mago_blanco.py
"""
import os

from PIL import Image

RAIZ = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
ORIGEN = os.path.join(RAIZ, "assets", "mago_rojo")
DESTINO = os.path.join(RAIZ, "assets", "mago_blanco")

CAMBIOS = {
    # Tunica y sombrero: de la luz a la sombra.
    (204, 62, 38): (246, 246, 240),
    (158, 32, 30): (214, 218, 228),
    (104, 18, 22): (150, 158, 180),
    (44, 16, 12): (78, 84, 106),
    # Contorno: igual de oscuro (se tiene que leer contra el suelo), algo frio.
    (28, 10, 8): (24, 26, 38),
    # Orbe del baculo y su resplandor, de fuego a hielo.
    (255, 252, 214): (240, 252, 255),
    (255, 214, 72): (186, 238, 255),
    (255, 226, 120): (214, 246, 255),
    (255, 132, 24): (110, 200, 255),
    (214, 56, 16): (64, 156, 224),
    (192, 128, 42): (104, 176, 220),
    (133, 61, 21): (52, 104, 150),
    # Ojos.
    (255, 214, 90): (170, 232, 255),
}


def cambiar(imagen):
    imagen = imagen.convert("RGBA")
    px = imagen.load()
    for y in range(imagen.height):
        for x in range(imagen.width):
            r, g, b, a = px[x, y]
            if a and (r, g, b) in CAMBIOS:
                px[x, y] = CAMBIOS[(r, g, b)] + (a,)
    return imagen


def main():
    os.makedirs(DESTINO, exist_ok=True)
    for nombre in ("atlas_8dir.png", "retrato.png"):
        cambiar(Image.open(os.path.join(ORIGEN, nombre))).save(os.path.join(DESTINO, nombre))
    with open(os.path.join(ORIGEN, "animaciones_mago_rojo.tres"), encoding="utf-8") as f:
        animaciones = f.read()
    animaciones = animaciones.replace("res://assets/mago_rojo/", "res://assets/mago_blanco/")
    with open(os.path.join(DESTINO, "animaciones_mago_blanco.tres"), "w", encoding="utf-8", newline="\n") as f:
        f.write(animaciones)
    print("mago blanco en", os.path.normpath(DESTINO))


if __name__ == "__main__":
    main()
