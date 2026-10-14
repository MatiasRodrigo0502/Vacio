# -*- coding: utf-8 -*-
"""Genera el Mago Caido, el jefe del piso 12, a partir del mago rojo.

Como el mago blanco (generar_mago_blanco.py): la hoja del rojo es pixel art de
25 colores, y basta con cambiar unos por otros para tener las mismas 48 poses
(8 direcciones x 6 pasos) con otra piel. Es el cuarto mago, el que bajo antes
que tu y se lo trago el vacio.

NEGRO Y ORO (Matias, 2026-10-14): la primera version era violeta y se
confundia con el mago oscuro. Ahora:

- la tunica y el sombrero, negros, con el contorno aun mas negro;
- el ribete, de oro vivo, y los ojos, amarillos encendidos: lo primero que
  se ve de el;
- la barba, color ceniza;
- y en vez del baculo con el orbe, una GUADANA: el mango negro con anillas de
  oro y una hoja curva de acero oscuro con el filo dorado, hacia fuera del
  cuerpo. Se quita el orbe y su resplandor, se alarga el mango hasta donde
  estaba y se dibuja la hoja en cada una de las 48 poses, siguiendo el
  mango (sube y baja al andar).

La hoja no cabe en las casillas de 64 px del mago rojo, que tienen el
baculo pegado al borde: cada casilla pasa a medir 96 x 72, con el mago en
el centro (16 px mas a cada lado). Como se ensancha lo mismo por los dos
lados, el mago sigue en el centro del dibujo y Enemigo no nota nada.

Se dibuja a x2 (Enemigo lo escala a su TipoEnemigo.alto, 144 = 72 x 2): un
numero entero, para que el pixel art no se emborrone.

Salen assets/mago_caido/atlas_8dir.png y su SpriteFrames, que es el del rojo
con las rutas y los recortes cambiados y una animacion mas, "moverse" (la
misma que caminar_abajo): es la que pide Enemigo.preparar() para medir el
dibujo. Sin retrato: el jefe no sale en la eleccion de mago.

    python herramientas/generar_mago_caido.py
"""
import os
import re

from PIL import Image, ImageDraw

RAIZ = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
ORIGEN = os.path.join(RAIZ, "assets", "mago_rojo")
DESTINO = os.path.join(RAIZ, "assets", "mago_caido")

ANCHO, ALTO = 64, 72
NUEVO_ANCHO = 96
MARGEN = (NUEVO_ANCHO - ANCHO) // 2

CONTORNO_ROJO = (28, 10, 8)
# El orbe del baculo y el aro de luz de alrededor, que se quitan.
ORBE = {(214, 56, 16), (255, 132, 24), (255, 214, 72), (255, 226, 120), (255, 252, 214)}
RESPLANDOR = {(133, 61, 21), (192, 128, 42)}
# Las dos tiras del palo, clara y oscura, entre los contornos.
PALO_CLARO = (126, 74, 36)
PALO_OSCURO = (82, 44, 20)
TUNICA = {(204, 62, 38), (158, 32, 30), (104, 18, 22)}

CAMBIOS = {
    # Tunica y sombrero: negros, de la luz a la sombra.
    (204, 62, 38): (62, 60, 66),
    (158, 32, 30): (40, 38, 44),
    (104, 18, 22): (26, 25, 30),
    (44, 16, 12): (14, 13, 16),
    # Contorno: mas negro todavia, para que se lea contra el suelo rojo.
    CONTORNO_ROJO: (4, 4, 6),
    # Ribete: oro vivo.
    (236, 176, 52): (252, 206, 66),
    (168, 104, 28): (188, 140, 36),
    # Ojos, amarillos encendidos.
    (255, 214, 90): (255, 246, 150),
    # Barba, ceniza.
    (200, 192, 186): (168, 164, 172),
    (160, 150, 144): (118, 114, 122),
    (112, 102, 98): (78, 74, 82),
    # Mango, cinturon y botas: negro metal.
    PALO_CLARO: (74, 70, 70),
    (122, 70, 38): (66, 62, 62),
    (86, 46, 24): (44, 42, 44),
    PALO_OSCURO: (40, 38, 40),
    (72, 40, 26): (34, 32, 34),
    (46, 24, 16): (20, 19, 21),
}

ACERO = (52, 52, 60)
ACERO_LUZ = (120, 118, 132)
FILO = (252, 206, 66)
NEGRO = (4, 4, 6)


def color(px, x, y):
    r, g, b, a = px[x, y]
    return (r, g, b) if a else None


def guadana(celda):
    """Quita el orbe de una pose (64 x 72, colores del mago rojo) y devuelve
    la pose en 96 x 72 con la guadana en su sitio, todavia en los colores del
    rojo salvo la hoja."""
    px = celda.load()
    # El palo: la columna de su tira clara, en la mitad de abajo.
    columnas = {}
    for y in range(24, 62):
        for x in range(ANCHO):
            if color(px, x, y) == PALO_CLARO:
                columnas[x] = columnas.get(x, 0) + 1
    palo = max(columnas, key=columnas.get)
    # El centro del orbe: donde estan sus colores, arriba y cerca del palo.
    orbe = [(x, y) for y in range(0, 22) for x in range(max(0, palo - 12), min(ANCHO, palo + 13))
            if color(px, x, y) in ORBE]
    cx = sum(p[0] for p in orbe) / len(orbe)
    cy = sum(p[1] for p in orbe) / len(orbe)
    # Fuera el orbe, su aro y su contorno.
    for y in range(0, 24):
        for x in range(max(0, palo - 12), min(ANCHO, palo + 13)):
            c = color(px, x, y)
            cerca = (x - cx) ** 2 + (y - cy) ** 2 <= 7.5 ** 2
            if c in ORBE or c in RESPLANDOR or (cerca and c not in TUNICA and c is not None):
                px[x, y] = (0, 0, 0, 0)
    # El mango, hasta donde estaba el orbe: contorno, claro, oscuro, contorno.
    arriba = int(round(cy)) - 3
    for y in range(max(0, arriba), 24):
        if color(px, palo, y) in (PALO_CLARO, PALO_OSCURO):
            break
        for dx, c in ((-1, CONTORNO_ROJO), (0, PALO_CLARO), (1, PALO_OSCURO), (2, CONTORNO_ROJO)):
            if 0 <= palo + dx < ANCHO and color(px, palo + dx, y) not in TUNICA:
                px[palo + dx, y] = c + (255,)

    grande = Image.new("RGBA", (NUEVO_ANCHO, ALTO), (0, 0, 0, 0))
    grande.alpha_composite(celda, (MARGEN, 0))
    # Hacia fuera del cuerpo: al lado contrario de donde queda la tunica.
    tunica = [x for y in range(20, 60) for x in range(ANCHO) if color(px, x, y) in TUNICA]
    lado = -1 if palo < sum(tunica) / len(tunica) else 1
    _hoja(grande, palo + MARGEN, arriba + 1, lado)
    return grande


def _hoja(imagen, x, y, lado):
    """La hoja de la guadana, colgada del mango en (x, y) hacia 'lado'."""
    dibujo = ImageDraw.Draw(imagen)

    def p(dx, dy):
        return (x + 0.5 + lado * dx, y + dy)

    hoja = [p(0, -1), p(4, -5), p(10, -7), p(16, -6), p(21, -3), p(24, 2),
            p(19, -1), p(13, -2), p(7, -1), p(2, 2)]
    dibujo.polygon(hoja, fill=ACERO + (255,), outline=NEGRO + (255,))
    # Brillo en el lomo y el filo dorado por dentro.
    dibujo.line([p(5, -4), p(10, -6), p(16, -5), p(20, -3)], fill=ACERO_LUZ + (255,))
    dibujo.line([p(21, 0), p(18, -2), p(13, -3), p(7, -2)], fill=FILO + (255,))
    # La anilla de oro donde la hoja se une al mango.
    dibujo.rectangle([x - 1, y - 1, x + 2, y], fill=FILO + (255,))


def cambiar(imagen):
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
    rojo = Image.open(os.path.join(ORIGEN, "atlas_8dir.png")).convert("RGBA")
    columnas, filas = rojo.width // ANCHO, rojo.height // ALTO
    atlas = Image.new("RGBA", (columnas * NUEVO_ANCHO, filas * ALTO), (0, 0, 0, 0))
    for fila in range(filas):
        for columna in range(columnas):
            celda = rojo.crop((columna * ANCHO, fila * ALTO, (columna + 1) * ANCHO, (fila + 1) * ALTO))
            atlas.alpha_composite(guadana(celda), (columna * NUEVO_ANCHO, fila * ALTO))
    cambiar(atlas).save(os.path.join(DESTINO, "atlas_8dir.png"))

    with open(os.path.join(ORIGEN, "animaciones_mago_rojo.tres"), encoding="utf-8") as f:
        animaciones = f.read()
    animaciones = animaciones.replace("res://assets/mago_rojo/", "res://assets/mago_caido/")
    animaciones = re.sub(r"Rect2\((\d+), (\d+), %d, %d\)" % (ANCHO, ALTO),
                         lambda m: "Rect2(%d, %s, %d, %d)" % (int(m.group(1)) // ANCHO * NUEVO_ANCHO,
                                                             m.group(2), NUEVO_ANCHO, ALTO),
                         animaciones)
    animaciones = con_moverse(animaciones)
    with open(os.path.join(DESTINO, "animaciones_mago_caido.tres"), "w", encoding="utf-8", newline="\n") as f:
        f.write(animaciones)
    print("mago caido en", os.path.normpath(DESTINO))


if __name__ == "__main__":
    main()
