# -*- coding: utf-8 -*-
"""Prepara el arte de los cuatro magos y sus hechizos, del paquete que trajo
Matias el 2026-11-04 (vacio_magos_y_hechizos.zip).

Los originales estan en assets/magos_fuente/, que Godot no importa (.gdignore),
con el LEEME del paquete. Todos los magos del paquete y los del juego son los
mismos, con otro nombre:

    Piromante = mago rojo, Envenenador = mago verde, Criomante = mago blanco,
    Mago del Vacio = mago oscuro.

Lo que sale, en assets/mago_<color>/:

- atlas_8dir.png: las 32 poses (4 pasos x 8 direcciones) a 72 px, que es lo
  que mide un mago en el juego, y animaciones_mago_<color>.tres, el
  SpriteFrames con las 16 animaciones que pide el jugador. Las filas de la
  hoja van en el mismo orden que Jugador.LADOS. Se reducen aqui, con buen
  filtro, y no en el juego: Godot las encogeria sin suavizar y este dibujo,
  que no es pixel art, se veria con dientes.
- retrato.png: el mago recortado, al doble de lo que mide en la ficha del menu.
- hechizos/: las hojas de cada hechizo, reducidas a lo que miden en el juego, y
  un ArteHechizo (.tres) por hechizo, con sus animaciones y sus desfases.

POR QUE LOS TAMANOS DE ABAJO: la bola tiene que parecer de lo que choca (radio
11 la normal, 23 la cargada), el escudo tiene que medir lo que su radio (42) y
lo negro del agujero, lo que su centro (34).

    python herramientas/generar_magos.py
"""
import os

from PIL import Image

RAIZ = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
ASSETS = os.path.join(RAIZ, "assets")
FUENTE = os.path.join(ASSETS, "magos_fuente")

ORIGEN_PX = 128
POSE_PX = 72
PASOS = 4
VELOCIDAD_PASO = 8.0  # con 4 poses, el paso dura lo que el de antes
ALTO_RETRATO = 340
# Cada direccion con su fila de la hoja (el orden de Vector2.angle()).
DIRECCIONES = ["derecha", "abajo_derecha", "abajo", "abajo_izquierda",
               "izquierda", "arriba_izquierda", "arriba", "arriba_derecha"]

MAGOS = {
    "mago_oscuro": "vacio",
    "mago_rojo": "piromante",
    "mago_blanco": "criomante",
    "mago_verde": "envenenador",
}

# Las medidas de cada hoja: ancho y alto de la pose, cuantas, en cuantas
# columnas, poses por segundo, si da vueltas y su desfase (lo de la columna
# "Desfase" del LEEME del paquete).
BOLA_VUELO = (128, 64, 6, 6, 12.0, True, (-26, 0))
BOLA_IMPACTO = (128, 128, 8, 8, 16.0, False, (0, 2))
ESCUDO_APARECE = (256, 256, 8, 4, 14.0, False, (0, 0))
ESCUDO_BUCLE = (256, 256, 6, 3, 8.0, True, (0, 0))
ESCALA_ESCUDO = 42.0 / 95.0
AGUJERO = (384, 384, 8, 4, 12.0, False, (0, -4))

# Mago -> hechizo -> (radio_base, {animacion: (archivo, medidas, escala)}).
# radio_base: el radio de bola para el que "vuelo" mide lo que mide. Una bola
# mas gorda (el orbe hinchado) se pinta mas grande en la misma proporcion.
ESCALA_BOLA = 0.75
HECHIZOS = {
    "mago_rojo": {
        "disparo": (11.0, {
            "vuelo": ("bola_fuego_vuelo", BOLA_VUELO, ESCALA_BOLA),
            "impacto": ("bola_fuego_impacto", (128, 128, 8, 8, 16.0, False, (0, 0)), ESCALA_BOLA),
        }),
        "especial": (23.1, {
            # Con la escala de los magos (72/128): lo que hay en la demo.
            "vuelo": ("ultimate_vuelo", (512, 256, 6, 3, 12.0, True, (-116, 0)), 0.5625),
            "carga": ("ultimate_carga", (256, 256, 8, 4, 12.0, False, (0, 0)), 0.42),
            "explosion": ("ultimate_explosion", (512, 512, 12, 4, 14.0, False, (0, -74)), 0.45),
        }),
    },
    "mago_oscuro": {
        "disparo": (11.0, {
            "vuelo": ("bola_morada_vuelo", BOLA_VUELO, ESCALA_BOLA),
            "impacto": ("bola_morada_impacto", BOLA_IMPACTO, ESCALA_BOLA),
        }),
        "especial": (17.0, {
            # Sin reducir: la bola cargada (radio 23) es mas gorda que la hoja.
            "vuelo": ("agujero_orbe_vuelo", BOLA_VUELO, 1.0),
            # Lo negro mide 42 de radio en la hoja, y el centro del agujero, 34.
            "abrir": ("agujero_abrir", AGUJERO, 0.8),
            "bucle": ("agujero_bucle", AGUJERO[:5] + (True,) + AGUJERO[6:], 0.8),
            "colapso": ("agujero_colapso", (384, 384, 8, 4, 14.0, False, (0, -4)), 0.8),
        }),
    },
    "mago_blanco": {
        "disparo": (11.0, {
            "vuelo": ("lanza_vuelo", (128, 48, 4, 4, 12.0, True, (-55, 0)), ESCALA_BOLA),
            "impacto": ("lanza_impacto", BOLA_IMPACTO, ESCALA_BOLA),
        }),
        # La burbuja mide 95 de radio en la hoja, y la del juego, 42.
        "especial": (42.0, {
            "aparece_detras": ("escudo_aparece_detras", ESCUDO_APARECE, ESCALA_ESCUDO),
            "aparece_delante": ("escudo_aparece_delante", ESCUDO_APARECE, ESCALA_ESCUDO),
            "bucle_detras": ("escudo_bucle_detras", ESCUDO_BUCLE, ESCALA_ESCUDO),
            "bucle_delante": ("escudo_bucle_delante", ESCUDO_BUCLE, ESCALA_ESCUDO),
            "rompe_detras": ("escudo_rompe_detras", ESCUDO_APARECE, ESCALA_ESCUDO),
            "rompe_delante": ("escudo_rompe_delante", ESCUDO_APARECE, ESCALA_ESCUDO),
        }),
    },
    "mago_verde": {
        # El rocio se sigue pintando por codigo (BolaMagica): es una rafaga, no
        # un proyectil. Los dardos del paquete son sus proyectiles de veneno.
        "especial": (10.0, {
            "vuelo": ("dardo_vuelo", (96, 32, 4, 4, 12.0, True, (-42, 0)), ESCALA_BOLA),
            "impacto": ("dardo_impacto", (96, 96, 6, 6, 16.0, False, (0, -4)), ESCALA_BOLA),
        }),
    },
}

# Lo que se copia tal cual, sin animacion ni ArteHechizo: la marca del meteoro
# en el suelo (reducida como su explosion) y los estados de los enemigos, que
# pintan Burbujas y Escarcha.
SUELTOS = [
    ("mago_rojo", "ultimate_marca_suelo", "marca", 0.45),
    ("mago_blanco", "estado_ralentizado", "estado_ralentizado", 1.0),
    ("mago_verde", "estado_envenenado", "estado_envenenado", 1.0),
]


def reducir(imagen, tamano):
    # Con el alfa premultiplicado: si no, el borde transparente (negro)
    # mancharia el contorno al mezclarse.
    if imagen.size == tuple(tamano):
        return imagen
    return imagen.convert("RGBa").resize(tamano, Image.LANCZOS).convert("RGBA")


def guardar_texto(ruta, lineas):
    with open(ruta, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lineas) + "\n")


def cuadro(cuadros_id):
    return ", ".join('{\n"duration": 1.0,\n"texture": SubResource("%s")\n}' % c for c in cuadros_id)


def animacion(nombre, cuadros_id, velocidad, bucle):
    return '{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %.1f\n}' % (
        cuadro(cuadros_id), "true" if bucle else "false", nombre, velocidad)


def mago(carpeta, paquete):
    destino = os.path.join(ASSETS, carpeta)
    os.makedirs(destino, exist_ok=True)
    hoja = Image.open(os.path.join(FUENTE, "magos", paquete, paquete + "_spritesheet_8dir.png")).convert("RGBA")
    atlas = Image.new("RGBA", (POSE_PX * PASOS, POSE_PX * len(DIRECCIONES)))
    for fila in range(len(DIRECCIONES)):
        for paso in range(PASOS):
            pose = hoja.crop((paso * ORIGEN_PX, fila * ORIGEN_PX,
                              (paso + 1) * ORIGEN_PX, (fila + 1) * ORIGEN_PX))
            atlas.alpha_composite(reducir(pose, (POSE_PX, POSE_PX)), (paso * POSE_PX, fila * POSE_PX))
    atlas.save(os.path.join(destino, "atlas_8dir.png"))

    entero = Image.open(os.path.join(FUENTE, "magos", paquete, paquete + "_S_512.png")).convert("RGBA")
    entero = entero.crop(entero.getbbox())
    ancho = round(entero.width * ALTO_RETRATO / entero.height)
    reducir(entero, (ancho, ALTO_RETRATO)).save(os.path.join(destino, "retrato.png"))

    lineas = ['[gd_resource type="SpriteFrames" load_steps=%d format=3]' % (2 + len(DIRECCIONES) * PASOS), "",
              '[ext_resource type="Texture2D" path="res://assets/%s/atlas_8dir.png" id="atlas"]' % carpeta, ""]
    for fila, direccion in enumerate(DIRECCIONES):
        for paso in range(PASOS):
            lineas += ['[sub_resource type="AtlasTexture" id="%s_%d"]' % (direccion, paso),
                       'atlas = ExtResource("atlas")',
                       "region = Rect2(%d, %d, %d, %d)" % (paso * POSE_PX, fila * POSE_PX, POSE_PX, POSE_PX),
                       ""]
    animaciones = []
    for direccion in DIRECCIONES:
        animaciones.append(animacion("caminar_" + direccion,
                                     ["%s_%d" % (direccion, p) for p in range(PASOS)], VELOCIDAD_PASO, True))
    # Quieto, la primera pose: la que el paquete da para el reposo.
    for direccion in DIRECCIONES:
        animaciones.append(animacion("quieto_" + direccion, ["%s_0" % direccion], 1.0, True))
    lineas += ["[resource]", "animations = [%s]" % ", ".join(animaciones)]
    guardar_texto(os.path.join(destino, "animaciones_%s.tres" % carpeta), lineas)


def hechizo(carpeta, paquete, nombre, radio_base, animaciones):
    destino = os.path.join(ASSETS, carpeta, "hechizos")
    os.makedirs(destino, exist_ok=True)
    externos = ['[ext_resource type="Script" path="res://scripts/arte_hechizo.gd" id="1_script"]']
    recortes = []
    bloques = []
    desfases = []
    for anim, (archivo, (w, h, cuantas, columnas, fps, bucle, desfase), escala) in animaciones.items():
        hoja = Image.open(os.path.join(FUENTE, "hechizos", paquete, archivo + ".png")).convert("RGBA")
        cw, ch = round(w * escala), round(h * escala)
        filas = (cuantas + columnas - 1) // columnas
        salida = Image.new("RGBA", (cw * columnas, ch * filas))
        ids = []
        for k in range(cuantas):
            x, y = k % columnas, k // columnas
            pose = hoja.crop((x * w, y * h, (x + 1) * w, (y + 1) * h))
            salida.alpha_composite(reducir(pose, (cw, ch)), (x * cw, y * ch))
            id_cuadro = "%s_%d" % (anim, k)
            ids.append(id_cuadro)
            recortes += ['[sub_resource type="AtlasTexture" id="%s"]' % id_cuadro,
                         'atlas = ExtResource("t_%s")' % anim,
                         "region = Rect2(%d, %d, %d, %d)" % (x * cw, y * ch, cw, ch), ""]
        png = "%s_%s.png" % (nombre, anim)
        salida.save(os.path.join(destino, png))
        externos.append('[ext_resource type="Texture2D" path="res://assets/%s/hechizos/%s" id="t_%s"]'
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
               "radio_base = %.1f" % radio_base]
    guardar_texto(os.path.join(destino, nombre + ".tres"), lineas)


def main():
    for carpeta, paquete in MAGOS.items():
        mago(carpeta, paquete)
        for nombre, (radio_base, animaciones) in HECHIZOS[carpeta].items():
            hechizo(carpeta, paquete, nombre, radio_base, animaciones)
    for carpeta, archivo, nombre, escala in SUELTOS:
        paquete = MAGOS[carpeta]
        imagen = Image.open(os.path.join(FUENTE, "hechizos", paquete, archivo + ".png")).convert("RGBA")
        tamano = (round(imagen.width * escala), round(imagen.height * escala))
        os.makedirs(os.path.join(ASSETS, carpeta, "hechizos"), exist_ok=True)
        reducir(imagen, tamano).save(os.path.join(ASSETS, carpeta, "hechizos", nombre + ".png"))
    print("Listo: los cuatro magos y sus hechizos")


if __name__ == "__main__":
    main()
