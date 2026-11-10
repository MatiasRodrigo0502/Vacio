# -*- coding: utf-8 -*-
"""Los magos y sus skins sin el baston, para cuando llevan un arma del gacha.

Matias, 2026-11-10: «cuando usas una varita con el mago, debe quitarse el arma
default. Hay que separar los assets». El baston va dibujado dentro de cada pose,
asi que aqui se saca otra hoja de cada mago y de cada skin sin el, con la mano
cerrada y vacia, que es donde el juego pone el arma (ArmaFlotante).

COMO, SIN TOCAR EL DIBUJO DE SIEMPRE: las hojas del juego las pinto rsvg-convert,
que en este ordenador no esta. Se pinta cada pose dos veces con resvg (resvg-py,
de PyPI), con baston y sin el; lo que cambia entre las dos es el baston y su
brillo. En la hoja de siempre solo se cambian esos pixeles, por los de la pose sin
baston. Todo lo demas sale identico. resvg y rsvg-convert pintan casi igual
(medido el 2026-11-10: 2 de 255 de diferencia media, solo en los bordes), asi que
no se nota la costura.

Lo que sale, junto a cada atlas: atlas_8dir_sin_arma.png (o atlas_sin_arma.png en
las skins) y su SpriteFrames, con las mismas animaciones y, en su metadato
"manos", donde queda la mano del baston en cada pose: Vector3(x, y, z) en pixeles
de la pose (72 x 72), con z < -0.3 si la mano queda detras del cuerpo.

Hay que volver a ejecutarlo despues de generar_magos.py o de generar_skins.py.

    pip install resvg-py
    python herramientas/generar_sin_baston.py [mago_rojo rojo_smas ...]
"""
import io
import os
import sys

from PIL import Image, ImageChops, ImageFilter, ImageStat
import resvg_py

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import magos_vectorial as mv  # noqa: E402
from generar_magos import ASSETS, DIRECCIONES, PASOS, POSE_PX, VELOCIDAD_PASO, animacion, guardar_texto, reducir  # noqa: E402
from generar_skins import ORIGEN_PX, S, SKINS, con_resplandor  # noqa: E402

LIENZO = 256
## Lo que se da por igual entre la pose con baston y la de sin el (de 255): por
## debajo, son los bordes que resvg suaviza un poco distinto en cada una.
UMBRAL = 3
## Hasta donde se mira alrededor para igualar el tono (_al_tono), en pixeles.
RADIO_TONO = 4
## Detras del cuerpo, como en magos_vectorial.construir.
DETRAS = -0.3

MAGOS = {
    "mago_oscuro": mv.MagoVacio,
    "mago_rojo": mv.Piromante,
    "mago_blanco": mv.Criomante,
    "mago_verde": mv.Envenenador,
}


def pinta(texto):
    datos = resvg_py.svg_to_bytes(svg_string=texto, width=ORIGEN_PX, height=ORIGEN_PX)
    return Image.open(io.BytesIO(datos)).convert("RGBA")


def sin_baston(pj, atlas, aura):
    """La hoja sin baston y cuanto se parecia la pose de resvg a la de siempre."""
    salida = atlas.copy()
    diferencias = []
    for k in range(len(DIRECCIONES)):
        for p in range(PASOS):
            caja = (p * POSE_PX, k * POSE_PX, (p + 1) * POSE_PX, (k + 1) * POSE_PX)
            con = reducir(pinta(mv.svg(pj, mv.theta_de_fila(k), p)), (POSE_PX, POSE_PX))
            sin = reducir(pinta(mv.svg(pj, mv.theta_de_fila(k), p, False)), (POSE_PX, POSE_PX))
            if aura:
                con = con_resplandor(con, aura, 2.5)
                sin = con_resplandor(sin, aura, 2.5)
            original = atlas.crop(caja)
            # Lo que es baston: donde cambia algun canal (tambien el alfa: el baston
            # sobre el fondo vacio), con un pixel de margen para el borde suavizado.
            # Con el color ya multiplicado por su alfa: lo del todo transparente
            # guarda colores que no se ven (el del aura de las S), y no cuenta.
            canales = ImageChops.difference(con.convert("RGBa"), sin.convert("RGBa")).split()
            mascara = canales[0]
            for canal in canales[1:]:
                mascara = ImageChops.lighter(mascara, canal)
            mascara = mascara.point(lambda v: 255 if v > UMBRAL else 0).filter(ImageFilter.MaxFilter(3))
            salida.paste(Image.composite(_al_tono(sin, con, original, mascara), original, mascara), caja[:2])
            diferencias.append(sum(ImageStat.Stat(ImageChops.difference(con.convert("RGBa"), original.convert("RGBa"))).mean) / 4)
    return salida, sum(diferencias) / len(diferencias)


def _al_tono(sin, con, original, mascara):
    """La pose sin baston con el tono de la de siempre. Donde el baston tapaba el
    cuerpo, a cada pixel de resvg se le suma lo que se separa resvg de la hoja de
    siempre en el cuerpo de alrededor (RADIO_TONO). Hace falta en las S+ con brillo
    iridiscente (generar_skins.iridiscente): su mezcla de color no la pintan igual
    rsvg y resvg, y sin esto quedaba una franja de otro color donde iba el baston."""
    salida = sin.copy()
    s, c, o, m, d = sin.load(), con.load(), original.load(), mascara.load(), salida.load()
    ancho, alto = sin.size
    for y in range(alto):
        for x in range(ancho):
            if not m[x, y] or s[x, y][3] == 0:
                continue
            suma, cuantos = [0, 0, 0], 0
            for v in range(max(0, y - RADIO_TONO), min(alto, y + RADIO_TONO + 1)):
                for u in range(max(0, x - RADIO_TONO), min(ancho, x + RADIO_TONO + 1)):
                    if m[u, v] or o[u, v][3] < 200 or c[u, v][3] < 200:
                        continue
                    for i in range(3):
                        suma[i] += o[u, v][i] - c[u, v][i]
                    cuantos += 1
            if cuantos:
                d[x, y] = tuple(max(0, min(255, s[x, y][i] + round(suma[i] / cuantos))) for i in range(3)) + (s[x, y][3],)
    return salida


def manos(pj):
    """'caminar_<lado>' y 'quieto_<lado>' -> la mano del baston en cada pose."""
    escala = POSE_PX / LIENZO
    resultado = []
    for k, lado in enumerate(DIRECCIONES):
        puntos = []
        for p in range(PASOS):
            x, y, z = mv.mano_baston(pj, mv.theta_de_fila(k), p)
            puntos.append("Vector3(%.2f, %.2f, %.2f)" % (x * escala, y * escala, z))
        resultado.append('"caminar_%s": [%s]' % (lado, ", ".join(puntos)))
        resultado.append('"quieto_%s": [%s]' % (lado, puntos[0]))
    return "{%s}" % ", ".join(resultado)


def sprite_frames(ruta_atlas, ruta_tres, pj):
    lineas = ['[gd_resource type="SpriteFrames" load_steps=%d format=3]' % (2 + len(DIRECCIONES) * PASOS), "",
              '[ext_resource type="Texture2D" path="%s" id="atlas"]' % ruta_atlas, ""]
    for fila, lado in enumerate(DIRECCIONES):
        for paso in range(PASOS):
            lineas += ['[sub_resource type="AtlasTexture" id="%s_%d"]' % (lado, paso),
                       'atlas = ExtResource("atlas")',
                       "region = Rect2(%d, %d, %d, %d)" % (paso * POSE_PX, fila * POSE_PX, POSE_PX, POSE_PX), ""]
    animaciones = [animacion("caminar_" + d, ["%s_%d" % (d, p) for p in range(PASOS)], VELOCIDAD_PASO, True) for d in DIRECCIONES]
    animaciones += [animacion("quieto_" + d, ["%s_0" % d], 1.0, True) for d in DIRECCIONES]
    lineas += ["[resource]", "animations = [%s]" % ", ".join(animaciones), "metadata/manos = %s" % manos(pj)]
    guardar_texto(ruta_tres, lineas)


def main():
    elegidos = sys.argv[1:]
    for carpeta, clase in MAGOS.items():
        if elegidos and carpeta not in elegidos:
            continue
        destino = os.path.join(ASSETS, carpeta)
        atlas = Image.open(os.path.join(destino, "atlas_8dir.png")).convert("RGBA")
        hoja, parecido = sin_baston(clase(), atlas, None)
        hoja.save(os.path.join(destino, "atlas_8dir_sin_arma.png"))
        sprite_frames("res://assets/%s/atlas_8dir_sin_arma.png" % carpeta,
                      os.path.join(destino, "animaciones_%s_sin_arma.tres" % carpeta), clase())
        print("%-12s diferencia con la de siempre: %.2f" % (carpeta, parecido))
    for clase in SKINS:
        skin = clase()
        if elegidos and skin.id not in elegidos:
            continue
        destino = os.path.join(ASSETS, "skins", skin.id)
        atlas = Image.open(os.path.join(destino, "atlas.png")).convert("RGBA")
        aura = skin.aura if skin.aura and skin.tier >= S else None
        hoja, parecido = sin_baston(skin, atlas, aura)
        hoja.save(os.path.join(destino, "atlas_sin_arma.png"))
        sprite_frames("res://assets/skins/%s/atlas_sin_arma.png" % skin.id,
                      os.path.join(destino, "animaciones_sin_arma.tres"), skin)
        print("%-12s diferencia con la de siempre: %.2f" % (skin.id, parecido))


if __name__ == "__main__":
    main()
