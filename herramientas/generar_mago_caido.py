# -*- coding: utf-8 -*-
"""Genera el Mago Caido, el jefe del piso 12, a partir del mago rojo.

Como el mago blanco (generar_mago_blanco.py): la hoja del rojo es pixel art de
25 colores, y basta con cambiar unos por otros para tener las mismas 48 poses
(8 direcciones x 6 pasos) con otra piel. Es el cuarto mago, el que bajo antes
que tu y se lo trago el vacio. Lo que cambia:

- la tunica y el sombrero: casi negros, violeta muy oscuro, con el contorno
  aun mas negro;
- el ribete dorado, apagado a plata violacea: el oro se lo ha comido el vacio;
- el orbe del baculo y su resplandor: violeta con el centro blanco, el color
  de sus rayos;
- la barba, color ceniza, y el baculo de madera, chamuscado;
- los ojos, encendidos en magenta: lo primero que se ve de el.

Se dibuja a x2 (Enemigo lo escala a su TipoEnemigo.alto, 144 = 72 x 2): un
numero entero, para que el pixel art no se emborrone.

Salen assets/mago_caido/atlas_8dir.png, retrato.png y el SpriteFrames, que es
el del rojo con las rutas cambiadas y una animacion mas, "moverse" (la misma
que caminar_abajo): es la que pide Enemigo.preparar() para medir el dibujo.

    python herramientas/generar_mago_caido.py
"""
import os
import re

from PIL import Image

RAIZ = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
ORIGEN = os.path.join(RAIZ, "assets", "mago_rojo")
DESTINO = os.path.join(RAIZ, "assets", "mago_caido")

CAMBIOS = {
    # Tunica y sombrero: de la luz a la sombra.
    (204, 62, 38): (70, 44, 96),
    (158, 32, 30): (46, 26, 66),
    (104, 18, 22): (30, 16, 46),
    (44, 16, 12): (18, 8, 28),
    # Contorno: mas negro todavia, para que se lea contra el suelo rojo.
    (28, 10, 8): (8, 3, 12),
    # Ribete: del oro a una plata violacea apagada.
    (236, 176, 52): (178, 160, 200),
    (168, 104, 28): (118, 100, 142),
    # Orbe del baculo y su resplandor: violeta con el centro blanco.
    (255, 252, 214): (252, 244, 255),
    (255, 214, 72): (216, 172, 255),
    (255, 226, 120): (234, 206, 255),
    (255, 132, 24): (176, 96, 255),
    (214, 56, 16): (124, 46, 214),
    (192, 128, 42): (150, 84, 224),
    (133, 61, 21): (82, 32, 146),
    # Ojos, encendidos.
    (255, 214, 90): (255, 92, 214),
    # Barba, ceniza.
    (200, 192, 186): (168, 164, 178),
    (160, 150, 144): (118, 114, 128),
    (112, 102, 98): (78, 74, 90),
    # Baculo, chamuscado.
    (126, 74, 36): (70, 56, 62),
    (122, 70, 38): (66, 52, 58),
    (86, 46, 24): (46, 34, 40),
    (82, 44, 20): (40, 30, 36),
    (72, 40, 26): (36, 26, 32),
    (46, 24, 16): (24, 16, 20),
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


def con_moverse(animaciones):
    """Copia la animacion caminar_abajo con el nombre "moverse" y la pone la
    primera: Enemigo.preparar() la reproduce al prepararlo y mide el dibujo
    con su primer fotograma."""
    bloque = re.search(r'\{\n"frames": \[.*?\],\n"loop": true,\n"name": &"caminar_abajo",\n"speed": [0-9.]+\n\}',
                       animaciones, re.S)
    if bloque is None:
        raise SystemExit("No encuentro la animacion caminar_abajo en el SpriteFrames del mago rojo.")
    moverse = bloque.group(0).replace('&"caminar_abajo"', '&"moverse"')
    return animaciones.replace("animations = [", "animations = [" + moverse + ", ", 1)


def main():
    os.makedirs(DESTINO, exist_ok=True)
    for nombre in ("atlas_8dir.png", "retrato.png"):
        cambiar(Image.open(os.path.join(ORIGEN, nombre))).save(os.path.join(DESTINO, nombre))
    with open(os.path.join(ORIGEN, "animaciones_mago_rojo.tres"), encoding="utf-8") as f:
        animaciones = f.read()
    animaciones = animaciones.replace("res://assets/mago_rojo/", "res://assets/mago_caido/")
    animaciones = con_moverse(animaciones)
    with open(os.path.join(DESTINO, "animaciones_mago_caido.tres"), "w", encoding="utf-8", newline="\n") as f:
        f.write(animaciones)
    print("mago caido en", os.path.normpath(DESTINO))


if __name__ == "__main__":
    main()
