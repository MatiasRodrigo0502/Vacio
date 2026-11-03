# -*- coding: utf-8 -*-
"""Prepara el arte del mago verde a partir del que hizo Matias (2026-11-03).

Lo que llego es una hoja de 4 direcciones x 4 pasos, de 128 px por pose
(filas: abajo, izquierda, derecha, arriba), y el mago suelto en 512 px. Estan
en assets/mago_verde/fuente/, que Godot no importa (.gdignore): solo se usan
aqui.

Lo que sale, en assets/mago_verde/:

- atlas_4dir.png: las 16 poses a 72 px, el alto de los otros magos (que van
  en casillas de 64 x 72). Se reducen aqui, con buen filtro, y no en el
  juego: Godot las encogeria sin suavizar y el dibujo, que no es pixel art,
  se veria con dientes.
- retrato.png: el mago recortado, al doble de lo que mide en la ficha del
  menu (170 px de alto), para que se vea bien tambien a pantalla completa.
- animaciones_mago_verde.tres: el SpriteFrames, con las 16 animaciones que
  pide el jugador. Las diagonales usan la vista de lado (izquierda o
  derecha): solo hay cuatro direcciones, y andando en diagonal se lee mejor
  hacia que lado va que si sube o baja. Anda a 8 poses por segundo: con 4
  poses, el paso dura lo mismo que el de los otros (6 poses a 12).

    python herramientas/generar_mago_verde.py
"""
import os

from PIL import Image

RAIZ = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
CARPETA = os.path.join(RAIZ, "assets", "mago_verde")
FUENTE = os.path.join(CARPETA, "fuente")

ORIGEN_PX = 128
POSE_PX = 72
PASOS = 4
FILAS = ["abajo", "izquierda", "derecha", "arriba"]
# Cada una de las ocho direcciones del jugador, con la fila que usa.
DIRECCIONES = {
    "abajo": "abajo", "abajo_izquierda": "izquierda", "izquierda": "izquierda",
    "arriba_izquierda": "izquierda", "arriba": "arriba", "arriba_derecha": "derecha",
    "derecha": "derecha", "abajo_derecha": "derecha",
}
VELOCIDAD_PASO = 8.0
ALTO_RETRATO = 340


def reducir(imagen, tamano):
    # Con el alfa premultiplicado: si no, el borde transparente (negro)
    # mancharia el contorno al mezclarse.
    return imagen.convert("RGBa").resize(tamano, Image.LANCZOS).convert("RGBA")


def atlas():
    hoja = Image.open(os.path.join(FUENTE, "envenenador_spritesheet.png"))
    salida = Image.new("RGBA", (POSE_PX * PASOS, POSE_PX * len(FILAS)))
    for fila in range(len(FILAS)):
        for paso in range(PASOS):
            pose = hoja.crop((paso * ORIGEN_PX, fila * ORIGEN_PX,
                              (paso + 1) * ORIGEN_PX, (fila + 1) * ORIGEN_PX))
            salida.alpha_composite(reducir(pose, (POSE_PX, POSE_PX)),
                                   (paso * POSE_PX, fila * POSE_PX))
    salida.save(os.path.join(CARPETA, "atlas_4dir.png"))


def retrato():
    mago = Image.open(os.path.join(FUENTE, "envenenador_512_transparente.png")).convert("RGBA")
    mago = mago.crop(mago.getbbox())
    ancho = round(mago.width * ALTO_RETRATO / mago.height)
    reducir(mago, (ancho, ALTO_RETRATO)).save(os.path.join(CARPETA, "retrato.png"))


def sprite_frames():
    lineas = ['[gd_resource type="SpriteFrames" load_steps=%d format=3]' % (2 + len(FILAS) * PASOS), "",
              '[ext_resource type="Texture2D" path="res://assets/mago_verde/atlas_4dir.png" id="atlas"]', ""]
    for fila, nombre in enumerate(FILAS):
        for paso in range(PASOS):
            lineas += ['[sub_resource type="AtlasTexture" id="%s_%d"]' % (nombre, paso),
                       'atlas = ExtResource("atlas")',
                       "region = Rect2(%d, %d, %d, %d)" % (paso * POSE_PX, fila * POSE_PX, POSE_PX, POSE_PX),
                       ""]

    def animacion(nombre, poses, velocidad):
        cuadros = ", ".join('{\n"duration": 1.0,\n"texture": SubResource("%s")\n}' % p for p in poses)
        return '{\n"frames": [%s],\n"loop": true,\n"name": &"%s",\n"speed": %.1f\n}' % (cuadros, nombre, velocidad)

    animaciones = []
    for direccion, fila in DIRECCIONES.items():
        animaciones.append(animacion("caminar_" + direccion,
                                     ["%s_%d" % (fila, p) for p in range(PASOS)], VELOCIDAD_PASO))
    # Quieto, la primera pose: es la de los pies juntos.
    for direccion, fila in DIRECCIONES.items():
        animaciones.append(animacion("quieto_" + direccion, ["%s_0" % fila], 1.0))
    lineas += ["[resource]", "animations = [%s]" % ", ".join(animaciones), ""]
    with open(os.path.join(CARPETA, "animaciones_mago_verde.tres"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lineas))


def main():
    atlas()
    retrato()
    sprite_frames()
    print("Listo:", os.path.normpath(CARPETA))


if __name__ == "__main__":
    main()
