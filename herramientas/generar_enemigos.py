# -*- coding: utf-8 -*-
"""Prepara el arte de los enemigos, del paquete que trajo Matias el 2026-11-04
(vacio_completo.zip).

Las hojas originales pesan 31 MB (solo las del jefe, 23) y no se versionan, como
los demas originales (ver CREDITS.md): estan en
_assets_origen/vacio_completo/enemigos/, al lado del repositorio. En el repositorio
se queda lo que hace falta para volver a sacarlas, en assets/enemigos_fuente/: el
LEEME del paquete y sus scripts, que las dibujan desde vectores. Lo que sale de
aqui, en assets/criaturas/:

- <enemigo>_<capa>/: gólem, vigia y murcielago, cada uno en las tres capas
  (corteza, manto y nucleo), y jefe/, el Corazon del Nucleo. Una hoja por
  animacion (caminar, atacar, dano y muerte: 8 filas, una por direccion, en el
  orden de Jugador.LADOS) y animaciones.tres, el SpriteFrames con una animacion
  por direccion: caminar_abajo, atacar_abajo...
- esquirla.tres y bola.tres: un ArteHechizo con el vuelo y el impacto de lo que
  disparan el vigia y el jefe (TipoProyectil.arte), como los hechizos de los
  magos.

POR QUE SE REDUCEN AQUI: como los magos, no es pixel art, y Godot los encogeria
sin suavizar. Y el jefe original pesa 23 MB: 384 px por pose, en 8 filas.

POR QUE ESTOS TAMANOS: en el paquete todo esta a la misma escala y el gólem
(88 px de cuerpo) sale algo mas bajo que un mago (98), que aqui se quedaria
corto: era el mas grande de los enemigos de antes (66). El gólem y el vigia van a
0,8: miden 70 y 53 de alto, y un mago, 55. El murcielago, a 1: a 0,8 medía 38 y
costaba verlo en una sala llena. El jefe, a
0,5625, la escala de los magos: su esfera mide 93 de ancho y con los anillos,
205; mas, y cada hoja suya ocuparia unos 30 MB de memoria.

"centro" es la altura del centro del cuerpo en la casilla original, medida en
las hojas (sin la sombra de debajo): el circulo que choca va ahi
(TipoEnemigo.desfase_dibujo), y no en los pies como en el paquete, porque en el
juego los enemigos chocan con un circulo en su centro.

    python herramientas/generar_enemigos.py
"""
import os
import sys

from PIL import Image

from generar_magos import ASSETS, DIRECCIONES, RAIZ, animacion, guardar_texto, reducir

FUENTE = os.path.join(RAIZ, "..", "_assets_origen", "vacio_completo", "enemigos")
DESTINO = os.path.join(ASSETS, "criaturas")
CAPAS = ["corteza", "manto", "nucleo"]

# Poses, poses por segundo y si da vueltas (los FPS del LEEME, salvo donde se
# dice). Las hojas del jefe se llaman "flotar" donde las demas "caminar": aqui
# todas caminar, para que el enemigo no tenga que saber quien es.
ENEMIGOS = {
    "golem": {
        "casilla": 128, "px": 102, "centro": 72,
        "animaciones": {
            "caminar": ("caminar", 4, 8.0, True),
            # A 8 y no a 12: el golpe sale en la pose 3, y a 12 serian 0,25 s
            # para apartarse. A 8, 0,375, y pesa mas.
            "atacar": ("atacar", 6, 8.0, False),
            "dano": ("dano", 3, 12.0, False),
            "muerte": ("muerte", 8, 10.0, False),
        },
    },
    "vigia": {
        "casilla": 96, "px": 77, "centro": 44,
        "animaciones": {
            "caminar": ("caminar", 4, 8.0, True),
            # A 6: la esquirla sale en la pose 3, a los 0,5 s de tiempo_apuntar.
            "atacar": ("atacar", 6, 6.0, False),
            "dano": ("dano", 3, 12.0, False),
            "muerte": ("muerte", 8, 10.0, False),
        },
    },
    "murcielago": {
        "casilla": 64, "px": 64, "centro": 25,
        "animaciones": {
            "caminar": ("caminar", 4, 8.0, True),
            "atacar": ("atacar", 4, 12.0, False),
            "dano": ("dano", 3, 12.0, False),
            "muerte": ("muerte", 6, 10.0, False),
        },
    },
}
JEFE = {
    "casilla": 384, "px": 216, "centro": 170,
    "animaciones": {
        "caminar": ("flotar", 6, 8.0, True),
        "atacar": ("atacar", 8, 10.0, False),
        "dano": ("dano", 3, 12.0, False),
        "muerte": ("muerte", 10, 8.0, False),
    },
}

# Lo que dispara: (ancho, alto, poses, poses por segundo, si da vueltas, desfase).
ESQUIRLA = {
    "vuelo": ("esquirla_vuelo", (64, 32, 4, 12.0, True, (-27, 0))),
    "impacto": ("esquirla_impacto", (64, 64, 6, 16.0, False, (0, 0))),
}
BOLA = {
    "vuelo": ("bola_vuelo", (128, 64, 6, 12.0, True, (-26, 0))),
    "impacto": ("bola_impacto", (128, 128, 8, 16.0, False, (0, 0))),
}
# El radio con el que chocan (TipoProyectil.radio), y la escala que hace que el
# dibujo mida eso: la bola, como las de los magos.
RADIO_ESQUIRLA, ESCALA_ESQUIRLA = 7.0, 1.0
RADIO_BOLA, ESCALA_BOLA = 13.0, 0.75


def criatura(carpeta, patron, datos):
    """Las hojas y el SpriteFrames de una criatura. 'patron' es la ruta de sus
    hojas originales, con un %s donde va la animacion."""
    destino = os.path.join(DESTINO, carpeta)
    os.makedirs(destino, exist_ok=True)
    lado, px = datos["casilla"], datos["px"]
    externos, recortes, bloques = [], [], []
    for nombre, (archivo, poses, fps, bucle) in datos["animaciones"].items():
        hoja = Image.open(patron % archivo).convert("RGBA")
        salida = Image.new("RGBA", (px * poses, px * len(DIRECCIONES)))
        for fila, direccion in enumerate(DIRECCIONES):
            ids = []
            for pose in range(poses):
                recorte = hoja.crop((pose * lado, fila * lado, (pose + 1) * lado, (fila + 1) * lado))
                salida.alpha_composite(reducir(recorte, (px, px)), (pose * px, fila * px))
                id_cuadro = "%s_%s_%d" % (nombre, direccion, pose)
                ids.append(id_cuadro)
                recortes += ['[sub_resource type="AtlasTexture" id="%s"]' % id_cuadro,
                             'atlas = ExtResource("t_%s")' % nombre,
                             "region = Rect2(%d, %d, %d, %d)" % (pose * px, fila * px, px, px), ""]
            bloques.append(animacion("%s_%s" % (nombre, direccion), ids, fps, bucle))
        salida.save(os.path.join(destino, nombre + ".png"), optimize=True)
        externos.append('[ext_resource type="Texture2D" path="res://assets/criaturas/%s/%s.png" id="t_%s"]'
                        % (carpeta, nombre, nombre))
    lineas = ['[gd_resource type="SpriteFrames" load_steps=%d format=3]'
              % (1 + len(externos) + len(recortes) // 4), ""]
    lineas += externos + [""] + recortes
    lineas += ["[resource]", "animations = [%s]" % ", ".join(bloques)]
    guardar_texto(os.path.join(destino, "animaciones.tres"), lineas)
    escala = px / lado
    print("%-22s %3d px  desfase_dibujo = Vector2(0, %.2f)"
          % (carpeta, px, -(datos["centro"] - lado / 2.0) * escala))


def arte_proyectil(carpeta, nombre, patron, animaciones, escala, radio):
    """El ArteHechizo de lo que dispara: como los de los magos (generar_magos.py)."""
    destino = os.path.join(DESTINO, carpeta)
    os.makedirs(destino, exist_ok=True)
    externos = ['[ext_resource type="Script" path="res://scripts/arte_hechizo.gd" id="1_script"]']
    recortes, bloques, desfases = [], [], []
    for anim, (archivo, (w, h, poses, fps, bucle, desfase)) in animaciones.items():
        hoja = Image.open(patron % archivo).convert("RGBA")
        cw, ch = round(w * escala), round(h * escala)
        salida = Image.new("RGBA", (cw * poses, ch))
        ids = []
        for k in range(poses):
            recorte = hoja.crop((k * w, 0, (k + 1) * w, h))
            salida.alpha_composite(reducir(recorte, (cw, ch)), (k * cw, 0))
            id_cuadro = "%s_%d" % (anim, k)
            ids.append(id_cuadro)
            recortes += ['[sub_resource type="AtlasTexture" id="%s"]' % id_cuadro,
                         'atlas = ExtResource("t_%s")' % anim,
                         "region = Rect2(%d, 0, %d, %d)" % (k * cw, cw, ch), ""]
        png = "%s_%s.png" % (nombre, anim)
        salida.save(os.path.join(destino, png), optimize=True)
        externos.append('[ext_resource type="Texture2D" path="res://assets/criaturas/%s/%s" id="t_%s"]'
                        % (carpeta, png, anim))
        bloques.append(animacion(anim, ids, fps, bucle))
        desfases.append('"%s": Vector2(%.2f, %.2f)' % (anim, desfase[0] * escala, desfase[1] * escala))
    lineas = ['[gd_resource type="Resource" script_class="ArteHechizo" load_steps=%d format=3]'
              % (len(externos) + len(recortes) // 4 + 2), ""]
    lineas += externos + [""] + recortes
    lineas += ['[sub_resource type="SpriteFrames" id="animaciones"]',
               "animations = [%s]" % ", ".join(bloques), "",
               "[resource]", 'script = ExtResource("1_script")',
               'animaciones = SubResource("animaciones")',
               "desfases = {%s}" % ", ".join(desfases),
               "radio_base = %.1f" % radio]
    guardar_texto(os.path.join(destino, nombre + ".tres"), lineas)


def main():
    if not os.path.isdir(FUENTE):
        sys.exit("No estan las hojas originales en %s: sacalas de vacio_completo.zip "
                 "(enemigos/) o con los scripts de assets/enemigos_fuente/." % FUENTE)
    for enemigo, datos in ENEMIGOS.items():
        for capa in CAPAS:
            carpeta = "%s_%s" % (enemigo, capa)
            base = os.path.join(FUENTE, enemigo, carpeta + "_%s.png")
            criatura(carpeta, base, datos)
            if enemigo == "vigia":
                arte_proyectil(carpeta, "esquirla", base, ESQUIRLA, ESCALA_ESQUIRLA, RADIO_ESQUIRLA)
    base_jefe = os.path.join(FUENTE, "jefe", "jefe_%s.png")
    criatura("jefe", base_jefe, JEFE)
    arte_proyectil("jefe", "bola", base_jefe, BOLA, ESCALA_BOLA, RADIO_BOLA)
    print("Listo: los enemigos y el jefe")


if __name__ == "__main__":
    main()
