# -*- coding: utf-8 -*-
"""Genera las armas (el gacha de diamantes): su icono y su .tres.

Pedido por Matias el 2026-11-04: armas "super guays", cada una disparando de una
forma distinta, en cuatro tiers:

    raro        solo cambia el aspecto
    epico       el aspecto y la forma de disparar
    legendario  ademas, una animacion al matar
    mitico      ademas, varios modos de ataque

Todo sale de la tabla ARMAS: para equilibrar o anadir una, se cambia alli y se
vuelve a ejecutar. Salen assets/armas/<id>.png (dibujada mirando a la derecha,
porque flota apuntando) y resources/armas/<id>.tres, que es lo que lee el gacha.

Los numeros de cada modo son multiplicadores sobre un disparo normal (10 de dano,
uno cada 0,5 s). Dano por tiempo si dan todas las bolas, y contando la explosion:
un epico, de un 25 a un 35 % mas; un legendario, de un 50 a un 70 %; un mitico,
hasta algo mas del doble. A cambio, casi nunca dan todas. Es a ojo: hay que
jugarlas para ajustarlos.

    python herramientas/generar_armas.py
"""
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from generar_magos import guardar_texto  # noqa: E402

RAIZ = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
ICONOS = os.path.join(RAIZ, "assets", "armas")
RECURSOS = os.path.join(RAIZ, "resources", "armas")

LADO = 96
X = 4
OSCURO = (24, 18, 22, 255)

# Los de BolaMagica.Estilo y AnimacionMuerte.Tipo, en el mismo orden.
ORBE, ESTRELLA, FLECHA, RUNA, CUCHILLA, RAYO = range(6)
SIN_ANIMACION, RAYOS, TORBELLINO, LLAMARADA, ALMAS, ESQUIRLAS = range(6)
RARO, EPICO, LEGENDARIO, MITICO = range(4)
# El resplandor del icono, por tier.
BRILLO = {RARO: 0, EPICO: 2, LEGENDARIO: 3, MITICO: 4}


def modo(nombre="Normal", **campos):
    return dict(nombre=nombre, **campos)


ARMAS = [
    # --- Raros: solo el aspecto ------------------------------------------------
    dict(id="1_varita_roble", nombre="Varita de roble", tier=RARO, forma="varita", color="#b8e06a", halo="#5a8a2a",
         estilo=ESTRELLA, muerte=SIN_ANIMACION, descripcion="Estrellas de savia. Dispara como siempre.", modos=[modo()]),
    dict(id="1_cetro_coral", nombre="Cetro de coral", tier=RARO, forma="cetro", color="#ff9a8a", halo="#d84a5a",
         estilo=ORBE, muerte=SIN_ANIMACION, descripcion="Perlas de coral. Dispara como siempre.", modos=[modo()]),
    dict(id="1_daga_plata", nombre="Daga de plata", tier=RARO, forma="daga", color="#e4ecf4", halo="#8a9ab0",
         estilo=CUCHILLA, muerte=SIN_ANIMACION, descripcion="Filos de plata. Dispara como siempre.", modos=[modo()]),
    dict(id="1_tomo_azul", nombre="Tomo azul", tier=RARO, forma="tomo", color="#7ab8ff", halo="#2a5ad8",
         estilo=RUNA, muerte=SIN_ANIMACION, descripcion="Runas azules. Dispara como siempre.", modos=[modo()]),
    # --- Epicos: aspecto y forma de disparar -----------------------------------
    dict(id="2_varita_bifurcada", nombre="Varita bifurcada", tier=EPICO, forma="horquilla", color="#ffe066",
         halo="#e09a10", estilo=FLECHA, muerte=SIN_ANIMACION, descripcion="Tres flechas en abanico.",
         modos=[modo(proyectiles=3, apertura=16.0, dano=0.45)]),
    dict(id="2_dagas_gemelas", nombre="Dagas gemelas", tier=EPICO, forma="daga", color="#ff7ab0", halo="#c02a70",
         estilo=CUCHILLA, muerte=SIN_ANIMACION, descripcion="Una ráfaga de tres filos.",
         modos=[modo(rafaga=3, pausa_rafaga=0.08, dano=0.45, cadencia=1.05, velocidad=1.15)]),
    dict(id="2_cetro_serpiente", nombre="Cetro serpiente", tier=EPICO, forma="serpiente", color="#7affb0",
         halo="#16a060", estilo=ESTRELLA, muerte=SIN_ANIMACION, descripcion="Sus disparos serpentean.",
         modos=[modo(onda=46.0, dano=1.25, velocidad=0.85, radio=1.15)]),
    dict(id="2_orbe_saltarin", nombre="Orbe saltarín", tier=EPICO, forma="orbe", color="#80f0ff", halo="#1a90c0",
         estilo=ORBE, muerte=SIN_ANIMACION, descripcion="Sus bolas rebotan tres veces en muros y rocas.",
         modos=[modo(rebotes=3, dano=0.95, velocidad=0.95)]),
    # --- Legendarios: ademas, animacion al matar -------------------------------
    dict(id="3_tridente_solar", nombre="Tridente solar", tier=LEGENDARIO, forma="tridente", color="#ffd040",
         halo="#ff6a10", estilo=FLECHA, muerte=LLAMARADA,
         descripcion="Tres rayos de sol que atraviesan. Al matar, una llamarada.",
         modos=[modo(proyectiles=3, apertura=12.0, atraviesa=True, dano=0.5, velocidad=1.2)]),
    dict(id="3_guadana_almas", nombre="Guadaña de almas", tier=LEGENDARIO, forma="guadana", color="#b0ffe0",
         halo="#30a890", estilo=CUCHILLA, muerte=ALMAS,
         descripcion="Dos filos que se cruzan en el aire. Al matar, se le va el alma.",
         modos=[modo(proyectiles=2, onda=42.0, dano=0.75, velocidad=0.9)]),
    dict(id="3_martillo_runico", nombre="Martillo rúnico", tier=LEGENDARIO, forma="martillo", color="#a0c8ff",
         halo="#3a60e0", estilo=RUNA, muerte=ESQUIRLAS,
         descripcion="Runas lentas que explotan. Al matar, lo hace añicos.",
         modos=[modo(explosion=80.0, dano=1.7, velocidad=0.7, radio=1.4, cadencia=1.5)]),
    # --- Miticos: ademas, varios modos -----------------------------------------
    dict(id="4_cetro_abismo", nombre="Cetro del abismo", tier=MITICO, forma="abismo", color="#c88aff", halo="#6a20e0",
         estilo=ORBE, muerte=TORBELLINO,
         descripcion="Tres modos (rueda del ratón). Al matar, se lo traga un torbellino.",
         modos=[modo("Ráfaga", rafaga=4, pausa_rafaga=0.06, dano=0.5, velocidad=1.1),
                modo("Abanico", proyectiles=5, apertura=44.0, dano=0.45),
                modo("Lanza", atraviesa=True, dano=1.6, velocidad=1.9, radio=1.25, cadencia=1.3, estilo=RAYO)]),
    dict(id="4_corona_tormentas", nombre="Corona de tormentas", tier=MITICO, forma="corona", color="#90e8ff",
         halo="#2070ff", estilo=RAYO, muerte=RAYOS,
         descripcion="Tres modos (rueda del ratón). Al matar, lo fulmina un rayo.",
         modos=[modo("Chispas", proyectiles=2, apertura=30.0, busca=240.0, dano=0.7, velocidad=0.9, estilo=ESTRELLA),
                modo("Trueno", explosion=100.0, dano=2.2, velocidad=0.8, radio=1.5, cadencia=1.6, estilo=ORBE),
                modo("Cadena", rebotes=5, dano=1.0, velocidad=1.3)]),
]


def c(texto):
    return tuple(int(texto[i:i + 2], 16) for i in (1, 3, 5)) + (255,)


def oscurecer(color, k=0.55):
    return tuple(round(v * k) for v in color[:3]) + (255,)


def p(x, y):
    return (x * X, y * X)


class Lapiz:
    """Dibuja con borde oscuro: lo primero que se pinta es el contorno de todo."""

    def __init__(self):
        self.imagen = Image.new("RGBA", (LADO * X, LADO * X), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.imagen)

    def linea(self, a, b, grueso, color):
        for tinta, ancho in ((OSCURO, grueso + 3.0), (color, grueso)):
            self.d.line([p(*a), p(*b)], fill=tinta, width=int(ancho * X))
            for x, y in (a, b):
                r = ancho / 2
                self.d.ellipse([p(x - r, y - r), p(x + r, y + r)], fill=tinta)

    def poligono(self, puntos, color):
        grandes = [p(*q) for q in puntos]
        self.d.line(grandes + [grandes[0]], fill=OSCURO, width=int(3.0 * X), joint="curve")
        for q in grandes:
            r = 1.5 * X
            self.d.ellipse([q[0] - r, q[1] - r, q[0] + r, q[1] + r], fill=OSCURO)
        self.d.polygon(grandes, fill=color)

    def circulo(self, x, y, r, color):
        self.d.ellipse([p(x - r - 1.5, y - r - 1.5), p(x + r + 1.5, y + r + 1.5)], fill=OSCURO)
        self.d.ellipse([p(x - r, y - r), p(x + r, y + r)], fill=color)
        self.d.ellipse([p(x - r * 0.5, y - r * 0.55), p(x - r * 0.05, y - r * 0.15)], fill=(255, 255, 255, 200))


MADERA = (120, 84, 52, 255)
METAL = (150, 158, 176, 255)
ORO = (232, 186, 74, 255)


def estrella(l, x, y, r, color, puntas=4):
    l.poligono([(x + math.cos(i * math.pi / puntas) * (r if i % 2 == 0 else r * 0.4),
                 y + math.sin(i * math.pi / puntas) * (r if i % 2 == 0 else r * 0.4))
                for i in range(puntas * 2)], color)


def f_varita(l, a, _o):
    l.linea((14, 56), (66, 42), 5, MADERA)
    estrella(l, 74, 40, 13, a)


def f_cetro(l, a, o):
    l.linea((12, 60), (64, 44), 6, ORO)
    l.linea((58, 38), (62, 52), 4, ORO)
    l.circulo(74, 41, 11, a)


def f_daga(l, a, o):
    l.poligono([(38, 39), (84, 46), (38, 55)], a)
    l.poligono([(38, 39), (84, 46), (38, 47)], tuple(min(255, v + 40) for v in a[:3]) + (255,))
    l.linea((36, 30), (36, 62), 5, ORO)
    l.linea((14, 47), (34, 47), 7, MADERA)
    l.circulo(12, 47, 4, o)


def f_tomo(l, a, o):
    l.poligono([(22, 24), (72, 24), (72, 72), (22, 72)], o)
    l.poligono([(30, 24), (72, 24), (72, 66), (30, 66)], (240, 234, 216, 255))
    estrella(l, 52, 45, 13, a, 3)
    l.linea((22, 24), (22, 72), 6, oscurecer(o))


def f_horquilla(l, a, _o):
    l.linea((12, 58), (46, 48), 6, MADERA)
    l.linea((46, 48), (78, 26), 4.5, MADERA)
    l.linea((46, 48), (84, 50), 4.5, MADERA)
    l.linea((46, 48), (76, 72), 4.5, MADERA)
    for x, y in ((80, 25), (86, 50), (78, 73)):
        estrella(l, x, y, 7, a)


def f_serpiente(l, a, o):
    puntos = [(10 + i * 7, 48 + math.sin(i * 0.95) * 11) for i in range(10)]
    for q, r in zip(puntos, puntos[1:]):
        l.linea(q, r, 6, o)
    for q, r in zip(puntos, puntos[1:]):
        l.d.line([p(*q), p(*r)], fill=o, width=int(6 * X))
    l.circulo(80, puntos[-1][1], 9, a)


def f_orbe(l, a, o):
    l.d.ellipse([p(16, 26), p(80, 70)], outline=OSCURO, width=int(6 * X))
    l.d.ellipse([p(16, 26), p(80, 70)], outline=o, width=int(3 * X))
    l.circulo(48, 48, 18, a)


def f_tridente(l, a, _o):
    l.linea((8, 48), (58, 48), 6, ORO)
    l.linea((58, 28), (58, 68), 5, ORO)
    for y, punta in ((28, 80), (48, 90), (68, 80)):
        l.linea((58, y), (punta - 6, y), 4.5, ORO)
        l.poligono([(punta - 8, y - 7), (punta + 4, y), (punta - 8, y + 7)], a)


def f_guadana(l, a, o):
    l.linea((10, 78), (60, 20), 5.5, oscurecer(o, 0.8))
    puntos = [(60 + math.cos(t) * 28 - 4, 34 + math.sin(t) * 28) for t in [-1.9 + i * 0.32 for i in range(9)]]
    interior = [(58 + math.cos(t) * 18 + 4, 36 + math.sin(t) * 13) for t in [-1.9 + i * 0.32 for i in range(8, -1, -1)]]
    l.poligono(puntos + interior, a)


def f_martillo(l, a, o):
    l.linea((10, 54), (56, 48), 6.5, MADERA)
    l.poligono([(52, 24), (82, 24), (82, 74), (52, 74)], METAL)
    l.poligono([(52, 24), (82, 24), (82, 34), (52, 34)], oscurecer(METAL, 0.75))
    estrella(l, 67, 50, 11, a)


def f_abismo(l, a, o):
    l.linea((10, 62), (56, 50), 6, (40, 28, 60, 255))
    for k in range(5):
        giro = k * 1.26 + 0.3
        l.linea((70, 44), (70 + math.cos(giro) * 22, 44 + math.sin(giro) * 22), 3.5, o)
    l.circulo(70, 44, 13, (10, 4, 24, 255))
    l.d.ellipse([p(50, 34), p(90, 54)], outline=a, width=int(2.5 * X))


def f_corona(l, a, o):
    l.poligono([(16, 70), (12, 32), (30, 50), (48, 22), (66, 50), (84, 32), (80, 70)], ORO)
    l.linea((16, 70), (80, 70), 6, oscurecer(ORO, 0.75))
    for x, y in ((12, 28), (48, 18), (84, 28)):
        l.circulo(x, y, 6, a)
    estrella(l, 48, 58, 9, a)


FORMAS = {"varita": f_varita, "cetro": f_cetro, "daga": f_daga, "tomo": f_tomo, "horquilla": f_horquilla,
          "serpiente": f_serpiente, "orbe": f_orbe, "tridente": f_tridente, "guadana": f_guadana,
          "martillo": f_martillo, "abismo": f_abismo, "corona": f_corona}


def icono(arma):
    l = Lapiz()
    FORMAS[arma["forma"]](l, c(arma["color"]), c(arma["halo"]))
    imagen = l.imagen
    brillo = BRILLO[arma["tier"]]
    if brillo:
        alfa = imagen.getchannel("A").filter(ImageFilter.GaussianBlur(brillo * X))
        alfa = alfa.point(lambda v: min(255, int(v * 1.6)))
        halo = Image.new("RGBA", imagen.size, c(arma["halo"])[:3] + (0,))
        halo.putalpha(alfa)
        imagen = Image.alpha_composite(halo, imagen)
    imagen.convert("RGBa").resize((LADO, LADO), Image.LANCZOS).convert("RGBA").save(
        os.path.join(ICONOS, arma["id"] + ".png"))


def valor(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, str):
        return '"%s"' % v
    return repr(v)


def recurso(arma):
    lineas = ['[gd_resource type="Resource" script_class="ArmaMago" load_steps=%d format=3]' % (4 + len(arma["modos"])),
              "", '[ext_resource type="Script" path="res://scripts/arma_mago.gd" id="1_arma"]',
              '[ext_resource type="Script" path="res://scripts/modo_arma.gd" id="2_modo"]',
              '[ext_resource type="Texture2D" path="res://assets/armas/%s.png" id="3_icono"]' % arma["id"], ""]
    for i, m in enumerate(arma["modos"]):
        lineas += ['[sub_resource type="Resource" id="modo_%d"]' % i, 'script = ExtResource("2_modo")']
        lineas += ["%s = %s" % (k, valor(v)) for k, v in m.items()]
        lineas.append("")
    colores = ["Color(%.3f, %.3f, %.3f, 1)" % tuple(v / 255.0 for v in c(arma[k])[:3]) for k in ("color", "halo")]
    modos = ", ".join('SubResource("modo_%d")' % i for i in range(len(arma["modos"])))
    lineas += ["[resource]", 'script = ExtResource("1_arma")', 'nombre = "%s"' % arma["nombre"],
               'descripcion = "%s"' % arma["descripcion"], "tier = %d" % arma["tier"], 'icono = ExtResource("3_icono")',
               "color = %s" % colores[0], "halo = %s" % colores[1], "estilo = %d" % arma["estilo"],
               "muerte = %d" % arma["muerte"], 'modos = Array[ExtResource("2_modo")]([%s])' % modos]
    guardar_texto(os.path.join(RECURSOS, arma["id"] + ".tres"), lineas)


def main():
    os.makedirs(ICONOS, exist_ok=True)
    os.makedirs(RECURSOS, exist_ok=True)
    for arma in ARMAS:
        icono(arma)
        recurso(arma)
    print("Listo: %d armas" % len(ARMAS))


if __name__ == "__main__":
    main()
