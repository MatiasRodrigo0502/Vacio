# -*- coding: utf-8 -*-
"""Genera las skins de los magos (el gacha de monedas), a partir de su arte.

Pedido por Matias el 2026-11-04: skins exclusivas para cada mago, en tiers B, A,
S y S+. Cada mago tiene una de cada, y salen de su propio atlas y su retrato:

- B: otro color, girando el tono (lo demas igual).
- A: otra paleta entera: cada pixel toma el color que le toca por lo claro que
  es, con los tonos de la skin.
- S: como la A, y con un resplandor alrededor de la figura.
- S+: iridiscente: el color cambia a lo largo de la figura y de una pose a otra,
  asi que al andar corre por el cuerpo. Resplandor, y aura de arcoiris en el
  juego (AuraSkin).

Lo que sale: assets/skins/<id>/ (atlas.png, retrato.png y animaciones.tres) y
resources/skins/<id>.tres, que es lo que lee el gacha. Si llega arte de una skin
hecha a mano, basta con apuntar su .tres a el.

Sin numpy, pixel a pixel: tarda unos segundos, y no hace falta mas.

    python herramientas/generar_skins.py
"""
import colorsys
import os
import sys

from PIL import Image, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from generar_magos import DIRECCIONES, PASOS, POSE_PX, VELOCIDAD_PASO, animacion, guardar_texto  # noqa: E402

RAIZ = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
ASSETS = os.path.join(RAIZ, "assets")
RECURSOS = os.path.join(RAIZ, "resources", "skins")


def c(texto):
    return tuple(int(texto[i:i + 2], 16) for i in (1, 3, 5))


# Mago del juego, su carpeta y sus cuatro skins:
# (sufijo, nombre, tier, receta, parametros, aura)
MAGOS = {
    "rojo": ("Mago rojo", "mago_rojo", [
        ("b", "Llama azul", 0, "girar", 0.58, None),
        ("a", "Ceniza", 1, "paleta", ["#0b0a0c", "#3c3a44", "#8d8a96", "#ffd9a0"], None),
        ("s", "Magma negro", 2, "paleta", ["#060303", "#1a0a08", "#ff4a10", "#fff2a0"], "#ff6a20"),
        ("smas", "Fénix", 3, "iris", (0.02, 0.15), "#ffc040"),
    ]),
    "oscuro": ("Mago oscuro", "mago_oscuro", [
        ("b", "Noche azul", 0, "girar", -0.15, None),
        ("a", "Sangre", 1, "paleta", ["#080204", "#4a0a18", "#c0162e", "#ffb0a0"], None),
        ("s", "Eclipse dorado", 2, "paleta", ["#040302", "#2a2008", "#d8a020", "#fff4c0"], "#e8b030"),
        ("smas", "Cosmos", 3, "iris", (0.55, 0.95), "#a060ff"),
    ]),
    "blanco": ("Mago blanco", "mago_blanco", [
        ("b", "Glaciar", 0, "girar", -0.1, None),
        ("a", "Sakura", 1, "paleta", ["#1a0812", "#8a2c5c", "#f08cc0", "#fff0f6"], None),
        ("s", "Diamante", 2, "paleta", ["#0a1020", "#2c5a9a", "#a8dcff", "#ffffff"], "#a0e0ff"),
        ("smas", "Aurora", 3, "iris", (0.3, 0.8), "#60ffc0"),
    ]),
    "verde": ("Mago verde", "mago_verde", [
        ("b", "Pantano", 0, "girar", -0.12, None),
        ("a", "Toxina púrpura", 1, "girar", 0.45, None),
        ("s", "Radiactivo", 2, "paleta", ["#040804", "#2a4a08", "#b0ff20", "#ffffc0"], "#b0ff30"),
        ("smas", "Plaga arcoíris", 3, "iris", (0.0, 1.0), "#ffffff"),
    ]),
}


def en_paleta(paleta, t):
    """El color de la paleta para una luz de 0 a 1."""
    t = min(max(t, 0.0), 1.0) * (len(paleta) - 1)
    i = min(int(t), len(paleta) - 2)
    k = t - i
    a, b = paleta[i], paleta[i + 1]
    return tuple(round(a[n] + (b[n] - a[n]) * k) for n in range(3))


def recolor(imagen, receta, parametros, fase=0.0):
    """Cambia los colores de una imagen RGBA. 'fase' mueve el iridiscente."""
    salida = imagen.copy()
    px = salida.load()
    w, h = salida.size
    if receta == "paleta":
        paleta = [c(t) for t in parametros]
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            if receta == "paleta":
                # Con algo de contraste: el arte es muy oscuro, y sin esto
                # casi todo se queda en los dos primeros tonos.
                luz = (0.3 * r + 0.59 * g + 0.11 * b) / 255.0
                px[x, y] = en_paleta(paleta, luz ** 0.7) + (a,)
                continue
            hh, s, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
            if receta == "girar":
                hh = (hh + parametros) % 1.0
            else:
                desde, hasta = parametros
                avance = (y / h * 0.75 + x / w * 0.25 + fase) % 1.0
                # Ida y vuelta: que no haya un corte al dar la vuelta.
                avance = 1.0 - abs(avance * 2.0 - 1.0)
                hh = (desde + (hasta - desde) * avance) % 1.0
                s = max(s, 0.75)
                v = min(1.0, v ** 0.8 * 1.1)
            nr, ng, nb = colorsys.hsv_to_rgb(hh, s, v)
            px[x, y] = (round(nr * 255), round(ng * 255), round(nb * 255), a)
    return salida


def con_resplandor(imagen, color, radio):
    """Un halo del color por detras de la figura, sin salirse de su casilla."""
    alfa = imagen.getchannel("A").filter(ImageFilter.GaussianBlur(radio))
    alfa = alfa.point(lambda v: min(255, v * 2))
    halo = Image.new("RGBA", imagen.size, c(color) + (0,))
    halo.putalpha(alfa)
    return Image.alpha_composite(halo, imagen)


def hacer_skin(id_skin, nombre_mago, carpeta, nombre, tier, receta, parametros, aura):
    destino = os.path.join(ASSETS, "skins", id_skin)
    os.makedirs(destino, exist_ok=True)
    origen = Image.open(os.path.join(ASSETS, carpeta, "atlas_8dir.png")).convert("RGBA")
    atlas = Image.new("RGBA", origen.size)
    for fila in range(len(DIRECCIONES)):
        for paso in range(PASOS):
            caja = (paso * POSE_PX, fila * POSE_PX, (paso + 1) * POSE_PX, (fila + 1) * POSE_PX)
            pose = recolor(origen.crop(caja), receta, parametros, paso / PASOS)
            if aura:
                pose = con_resplandor(pose, aura, 2.5)
            atlas.alpha_composite(pose, caja[:2])
    atlas.save(os.path.join(destino, "atlas.png"))

    retrato = recolor(Image.open(os.path.join(ASSETS, carpeta, "retrato.png")).convert("RGBA"), receta, parametros)
    if aura:
        # Con margen: si no, el halo se corta en el borde de la imagen.
        lienzo = Image.new("RGBA", (retrato.width + 40, retrato.height + 40))
        lienzo.alpha_composite(retrato, (20, 20))
        retrato = con_resplandor(lienzo, aura, 8)
    retrato.save(os.path.join(destino, "retrato.png"))

    ruta = "res://assets/skins/%s/" % id_skin
    lineas = ['[gd_resource type="SpriteFrames" load_steps=%d format=3]' % (2 + len(DIRECCIONES) * PASOS), "",
              '[ext_resource type="Texture2D" path="%satlas.png" id="atlas"]' % ruta, ""]
    for fila, direccion in enumerate(DIRECCIONES):
        for paso in range(PASOS):
            lineas += ['[sub_resource type="AtlasTexture" id="%s_%d"]' % (direccion, paso),
                       'atlas = ExtResource("atlas")',
                       "region = Rect2(%d, %d, %d, %d)" % (paso * POSE_PX, fila * POSE_PX, POSE_PX, POSE_PX),
                       ""]
    animaciones = [animacion("caminar_" + d, ["%s_%d" % (d, p) for p in range(PASOS)], VELOCIDAD_PASO, True)
                   for d in DIRECCIONES]
    animaciones += [animacion("quieto_" + d, ["%s_0" % d], 1.0, True) for d in DIRECCIONES]
    lineas += ["[resource]", "animations = [%s]" % ", ".join(animaciones)]
    guardar_texto(os.path.join(destino, "animaciones.tres"), lineas)

    color_aura = "Color(%.3f, %.3f, %.3f, 1)" % tuple(v / 255.0 for v in c(aura)) if aura else "Color(0, 0, 0, 0)"
    guardar_texto(os.path.join(RECURSOS, id_skin + ".tres"), [
        '[gd_resource type="Resource" script_class="SkinMago" load_steps=4 format=3]', "",
        '[ext_resource type="Script" path="res://scripts/skin_mago.gd" id="1_script"]',
        '[ext_resource type="SpriteFrames" path="%sanimaciones.tres" id="2_animaciones"]' % ruta,
        '[ext_resource type="Texture2D" path="%sretrato.png" id="3_retrato"]' % ruta, "",
        "[resource]", 'script = ExtResource("1_script")',
        'nombre = "%s"' % nombre, 'mago = "%s"' % nombre_mago, "tier = %d" % tier,
        'animaciones = ExtResource("2_animaciones")', 'retrato = ExtResource("3_retrato")',
        "aura = %s" % color_aura, "arcoiris = %s" % ("true" if receta == "iris" else "false"),
    ])


def main():
    os.makedirs(RECURSOS, exist_ok=True)
    for sufijo_mago, (nombre_mago, carpeta, recetas) in MAGOS.items():
        for sufijo, nombre, tier, receta, parametros, aura in recetas:
            hacer_skin("%s_%s" % (sufijo_mago, sufijo), nombre_mago, carpeta, nombre, tier, receta, parametros, aura)
            print(sufijo_mago, sufijo, nombre)


if __name__ == "__main__":
    main()
