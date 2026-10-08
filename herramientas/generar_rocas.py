# -*- coding: utf-8 -*-
"""Genera las rocas de dentro de las salas, distintas en cada piso, en
assets/rocas/piso_NN/.

Son de la misma roca que la pared de su piso (herramientas/generar_bordes.py,
de donde salen las paletas y las piezas): cantos con musgo arriba del todo,
basalto mojado, caliza, rocas con grietas de magma, olivino, ringwoodita,
columnas, escoria con lava, hierro y al final cristal.

Por piso:
- roca_K.png, grupo_K.png, bloque_K.png: los obstaculos (cada piso usa una de
  las tres familias, la de su .tres).
- piedra_K.png: piedrecitas del suelo, sin colision.
- plataforma_K.png: losas anchas y bajas. Lo que crece encima son los mismos
  adornos de la pared del piso (assets/bordes/piso_NN/adorno_K.png).
- catalogo.tres: el CatalogoObstaculos del piso, con colores_propios: el juego
  no las tine.

LA LUZ ESTA MEDIDA, NO A OJO:
una roca se tiene que leer contra el suelo de un vistazo, porque estorba. El
cuerpo de cada roca se lleva a una luminosidad media que es un multiplo de la
del suelo de su piso ('contraste' en ROCAS): por debajo de 0,45 se lee como
roca oscura, por encima de 1,6 como roca clara. En medio se funde con el suelo
(ver CLAUDE.md, "Las rocas de un pack nuevo se calibran..."). Lo que brilla
(grietas, cristales) va encima, despues de medir.

Solo PIL y semillas fijas: volver a ejecutarlo da los mismos archivos.

    python herramientas/generar_rocas.py           (todos los pisos)
    python herramientas/generar_rocas.py 3 7       (solo esos)
"""
import math
import os
import random
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageStat

from generar_bordes import (E, TEMAS, a_bytes, cerrar, columnas, con_alfa, con_vetas_brillantes,
                            cristales, degradado, desplazar, mezclar, plano, reducir, volumen)

RAIZ = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SALIDA = os.path.join(RAIZ, "assets", "rocas")


def luz_suelo(numero):
    """Luminosidad (0-1) del suelo del piso, la misma cuenta que
    Piso._colores_suelo()."""
    p = (numero - 1) / 11.0
    a, b = (0.16, 0.13, 0.12), (0.42, 0.13, 0.06)
    c = [a[i] + (b[i] - a[i]) * p for i in range(3)]
    return 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]


def ajustar_luz(color, mascara, objetivo):
    """Lleva la luminosidad media de lo que hay bajo la mascara a 'objetivo'."""
    solida = mascara.point(lambda v: 255 if v > 200 else 0)
    media = ImageStat.Stat(color.convert("L"), mask=solida).mean[0] / 255.0
    factor = objetivo / max(media, 1e-3)
    return color.point(lambda v: int(max(0, min(255, v * factor))))


def ajustar_luz_rgba(pieza, objetivo):
    rgb = pieza.convert("RGB")
    rgb = ajustar_luz(rgb, pieza.getchannel("A"), objetivo)
    rgb.putalpha(pieza.getchannel("A"))
    return rgb


def halo_pequeno(pieza, color, radio=4, fuerza=0.7):
    """Resplandor para una pieza ya reducida (a tamano real)."""
    margen = radio * 3
    grande = Image.new("RGBA", (pieza.width + margen * 2, pieza.height + margen * 2), (0, 0, 0, 0))
    grande.paste(pieza, (margen, margen))
    luz = con_alfa(grande.getchannel("A").filter(ImageFilter.GaussianBlur(radio)), fuerza)
    fondo = Image.new("RGBA", grande.size, a_bytes(color) + (0,))
    fondo.putalpha(luz)
    return reducir_1x(Image.alpha_composite(fondo, grande))


def reducir_1x(pieza, margen=2):
    caja = pieza.getchannel("A").point(lambda v: 255 if v > 6 else 0).getbbox()
    if caja is None:
        return pieza
    return pieza.crop((max(0, caja[0] - margen), max(0, caja[1] - margen),
                       min(pieza.width, caja[2] + margen), min(pieza.height, caja[3] + margen)))


# --- Formas (mascaras a 4x) -----------------------------------------------------

def _lienzo(ancho, alto):
    return Image.new("L", (int(ancho * E), int(alto * E)), 0)


def forma_monticulo(g, ancho, alto, punta=None):
    """Roca redondeada, apoyada en el suelo: base casi plana, lomo con ruido."""
    W, H = ancho + 12, alto + 12
    m = _lienzo(W, H)
    punta = punta if punta is not None else g.uniform(0.5, 1.0)
    sesgo = g.uniform(0.75, 1.3)
    fases = [g.uniform(0, math.tau) for _ in range(2)]
    base = H - 5
    puntos = []
    for i in range(49):
        t = i / 48
        perfil = math.sin(math.pi * (t ** sesgo)) ** punta
        r = 1.0 + 0.08 * math.sin(t * 7 + fases[0]) + 0.05 * math.sin(t * 17 + fases[1])
        puntos.append(((W / 2 - ancho / 2 + ancho * t) * E, (base - alto * perfil * r) * E))
    puntos += [((W / 2 + ancho * 0.45) * E, (base + 2) * E), ((W / 2 - ancho * 0.45) * E, (base + 2) * E)]
    ImageDraw.Draw(m).polygon(puntos, fill=255)
    return m


def forma_almohada(g, ancho, alto):
    """Roca de almohadilla (basalto): un bollo, mas plano por abajo."""
    W, H = ancho + 12, alto + 12
    m = _lienzo(W, H)
    fases = [g.uniform(0, math.tau) for _ in range(2)]
    cx, cy = W / 2, H / 2 + 1
    puntos = []
    for i in range(60):
        a = math.tau * i / 60
        r = 1.0 + 0.07 * math.sin(a * 3 + fases[0]) + 0.04 * math.sin(a * 5 + fases[1])
        ry = alto / 2 * (0.82 if math.sin(a) > 0 else 1.0)
        puntos.append(((cx + math.cos(a) * ancho / 2 * r) * E, (cy + math.sin(a) * ry * r) * E))
    ImageDraw.Draw(m).polygon(puntos, fill=255)
    return m


def forma_angular(g, ancho, alto, lados=None):
    """Bloque partido: pocos vertices, cantos rectos."""
    W, H = ancho + 12, alto + 12
    m = _lienzo(W, H)
    lados = lados or g.randint(5, 7)
    cx, cy = W / 2, H / 2 + 1
    giro = g.uniform(0, math.tau)
    puntos = []
    for k in range(lados):
        a = giro + math.tau * k / lados + g.uniform(-0.25, 0.25)
        r = g.uniform(0.82, 1.0)
        y = cy + math.sin(a) * alto / 2 * r
        puntos.append(((cx + math.cos(a) * ancho / 2 * r) * E, min(y, H - 5) * E))
    ImageDraw.Draw(m).polygon(puntos, fill=255)
    return m


def forma(t, g, ancho, alto, familia):
    if familia == "bloque":
        return forma_angular(g, ancho, alto)
    estilo = g.choice(t["formas"])
    if estilo == "almohada":
        return forma_almohada(g, ancho, alto * 0.8)
    if estilo == "angular":
        return forma_angular(g, ancho, alto)
    if estilo == "aguja":
        return forma_monticulo(g, ancho * 0.75, alto * 1.25, punta=g.uniform(1.6, 2.4))
    return forma_monticulo(g, ancho, alto)


# --- Pintar una roca --------------------------------------------------------------

def pintar(t, g, mascara, objetivo, tapa=False):
    """Volumen, extras del piso, luz medida y lo que brilla encima. RGBA a 4x.

    'tapa': la cara de arriba plana y mas clara, como en las losas y bloques."""
    paleta = t["paleta"]
    color = volumen(mascara, paleta, g)
    if tapa:
        arriba = ImageChops.subtract(mascara, desplazar(mascara, 0, E * g.randint(10, 15)))
        arriba = arriba.filter(ImageFilter.GaussianBlur(E)).point(lambda v: 255 if v > 120 else 0)
        color = Image.composite(plano(mascara.size, mezclar(paleta[1], paleta[2], 0.55)), color, arriba)
    if "metal" in t:
        rayas = Image.new("L", mascara.size, 0)
        d = ImageDraw.Draw(rayas)
        caja = mascara.getbbox()
        for _ in range(3):
            y = g.uniform(caja[1], caja[1] + (caja[3] - caja[1]) * 0.6)
            d.line([(caja[0], y), (caja[2], y + g.uniform(-0.1, 0.1) * (caja[2] - caja[0]))], fill=255,
                   width=int(E * g.uniform(1.5, 3)))
        rayas = ImageChops.multiply(rayas.filter(ImageFilter.GaussianBlur(E * 1.2)), mascara)
        color = Image.composite(plano(mascara.size, t["metal"]), color, con_alfa(rayas, 0.3))
    if "musgo" in t:
        arriba = ImageChops.subtract(mascara, desplazar(mascara, 0, E * g.randint(7, 12)))
        arriba = arriba.filter(ImageFilter.GaussianBlur(E * 1.2)).point(lambda v: 255 if v > 110 else 0)
        verde = degradado(mascara.size, mezclar(t["musgo"], (230, 255, 160), 0.25),
                          mezclar(t["musgo"], (0, 0, 0), 0.35), 0, mascara.height)
        color = Image.composite(verde, color, arriba)
    color = ajustar_luz(color, mascara, objetivo)
    # Lo que brilla, despues de medir: es un detalle, no el cuerpo de la roca.
    if "brillo" in t:
        color = con_vetas_brillantes(color, mascara, g, t["brillo"], g.randint(1, 3))
    if "motas" in t:
        d = ImageDraw.Draw(color)
        caja = mascara.getbbox()
        px = mascara.load()
        for _ in range(int((caja[2] - caja[0]) * (caja[3] - caja[1]) / (E * E * 320))):
            x, y = g.uniform(caja[0], caja[2]), g.uniform(caja[1], caja[3])
            if px[int(x), int(y)] > 200:
                r = g.uniform(1.0, 2.0) * E
                d.ellipse((x - r, y - r, x + r, y + r), fill=a_bytes(mezclar(t["motas"], (255, 255, 255),
                                                                            g.uniform(0, 0.4))))
    if "mojado" in t:
        # Brillo de agua: un reflejo largo y fino en lo alto, como en la
        # piedra mojada. Con manchitas redondas parecian ojos.
        brillo = Image.new("L", mascara.size, 0)
        d = ImageDraw.Draw(brillo)
        caja = mascara.getbbox()
        for _ in range(g.randint(1, 2)):
            x = g.uniform(caja[0] + (caja[2] - caja[0]) * 0.2, caja[0] + (caja[2] - caja[0]) * 0.5)
            y = g.uniform(caja[1] + (caja[3] - caja[1]) * 0.2, caja[1] + (caja[3] - caja[1]) * 0.4)
            largo = (caja[2] - caja[0]) * g.uniform(0.15, 0.3)
            d.line([(x, y), (x + largo, y + largo * 0.15)], fill=255, width=int(E * 1.6))
        brillo = ImageChops.multiply(brillo.filter(ImageFilter.GaussianBlur(E * 0.8)), mascara)
        color = Image.composite(plano(mascara.size, t["mojado"]), color, con_alfa(brillo, 0.7))
    pieza = cerrar(color, mascara, mezclar(paleta[0], (0, 0, 0), 0.75))
    return pieza


def con_cristales(pieza, t, g, cuantos):
    """Unos cristales asomando por arriba de la roca (ya reducida)."""
    for _ in range(cuantos):
        c = cristales(t["cristal"], g, ancho=g.randint(14, 22), alto=g.randint(14, 22), cuantos=3, brillo=0.4)
        x = int(g.uniform(0.15, 0.6) * pieza.width)
        y = int(g.uniform(0.0, 0.25) * pieza.height)
        lienzo = Image.new("RGBA", (max(pieza.width, x + c.width), max(pieza.height, y + c.height)), (0, 0, 0, 0))
        lienzo.paste(pieza, (0, 0))
        capa = Image.new("RGBA", lienzo.size, (0, 0, 0, 0))
        capa.paste(c, (x, y))
        pieza = Image.alpha_composite(lienzo, capa)
    return pieza


def roca(t, g, objetivo, familia):
    if t.get("cristalina"):
        # En el nucleo interno las rocas son cristal de hierro.
        c = cristales(t["cristal"], g, ancho=g.randint(54, 70), alto=g.randint(56, 74),
                      cuantos=g.randint(4, 6), brillo=0)
        c = ajustar_luz_rgba(c, objetivo)
        return halo_pequeno(c, t["cristal"], 4, 0.5)
    if familia == "grupo" and t.get("columnas"):
        c = columnas(t["paleta"], g)
        return ajustar_luz_rgba(c, objetivo)
    ancho = g.randint(60, 80)
    alto = g.randint(46, 62)
    pieza = reducir(pintar(t, g, forma(t, g, ancho, alto, familia), objetivo, tapa=(familia == "bloque")))
    if "cristal" in t and g.random() < t.get("con_cristal", 0.0):
        pieza = con_cristales(pieza, t, g, g.randint(1, 2))
    if "brillo" in t:
        pieza = halo_pequeno(pieza, t["brillo"], 4, 0.25)
    return pieza


def grupo(t, g, objetivo):
    """Dos o tres rocas juntas: las de detras mas altas, pintadas una a una."""
    if t.get("columnas") or t.get("cristalina"):
        return roca(t, g, objetivo, "grupo")
    cuantas = g.randint(2, 3)
    piezas = [roca(t, g, objetivo, "roca") for _ in range(cuantas)]
    ancho = sum(p.width for p in piezas) * 0.72 + 10
    alto = max(p.height for p in piezas) + 14
    lienzo = Image.new("RGBA", (int(ancho), int(alto)), (0, 0, 0, 0))
    x = 0.0
    # De atras (arriba) hacia delante (abajo).
    orden = sorted(range(cuantas), key=lambda i: g.random())
    for k, i in enumerate(orden):
        p = piezas[i]
        y = int(alto - p.height - (cuantas - 1 - k) * 5)
        capa = Image.new("RGBA", lienzo.size, (0, 0, 0, 0))
        capa.paste(p, (int(x), max(0, y)))
        lienzo = Image.alpha_composite(lienzo, capa)
        x += p.width * 0.68
    return reducir_1x(lienzo)


def piedra(t, g, objetivo):
    ancho, alto = g.randint(22, 32), g.randint(14, 20)
    if t.get("cristalina"):
        c = cristales(t["cristal"], g, ancho=22, alto=20, cuantos=3, brillo=0)
        return ajustar_luz_rgba(c, objetivo)
    m = forma_almohada(g, ancho, alto) if g.random() < 0.5 else forma_monticulo(g, ancho, alto)
    return reducir(pintar(t, g, m, objetivo))


def plataforma(t, g, objetivo):
    """Losa ancha y baja vista en 3/4: la cara de arriba plana y clara, el
    frente mas oscuro. Encima crece lo del piso."""
    ancho, alto = g.randint(130, 160), g.randint(44, 56)
    W, H = ancho + 12, alto + 12
    m = _lienzo(W, H)
    d = ImageDraw.Draw(m)
    fases = [g.uniform(0, math.tau) for _ in range(3)]
    puntos = []
    for i in range(80):
        a = math.tau * i / 80
        r = 1.0 + 0.05 * math.sin(a * 3 + fases[0]) + 0.03 * math.sin(a * 7 + fases[1])
        x = W / 2 + math.cos(a) * ancho / 2 * r
        y = H / 2 + math.sin(a) * alto / 2 * r
        # Mas recta por abajo: es el canto de la losa.
        if math.sin(a) > 0:
            y = H / 2 + alto / 2 * min(1.0, math.sin(a) * 1.6) * r
        puntos.append((x * E, y * E))
    d.polygon(puntos, fill=255)
    pieza = pintar(t, g, m, objetivo, tapa=True)
    return reducir(pieza)


# --- Rocas de cada piso --------------------------------------------------------------
#
# 'contraste': luminosidad del cuerpo de la roca respecto a la del suelo.
# Por debajo de 0,45, roca oscura; por encima de 1,6, clara. Nunca en medio.

def _pal(n):
    return TEMAS[n]["muro"]["paleta"]


ROCAS = {
    1: {"paleta": ((52, 46, 40), (118, 106, 92), (178, 164, 144)), "formas": ["monticulo", "almohada"],
        "musgo": (72, 120, 40), "contraste": 1.9},
    2: {"paleta": _pal(2), "formas": ["almohada"], "musgo": (40, 112, 92), "mojado": (150, 200, 220),
        "contraste": 0.42},
    3: {"paleta": ((70, 64, 54), (140, 130, 112), (200, 190, 168)), "formas": ["angular", "aguja", "monticulo"],
        "contraste": 2.0},
    4: {"paleta": _pal(4), "formas": ["monticulo", "almohada"], "brillo": (255, 128, 44),
        "cristal": (140, 206, 64), "con_cristal": 0.25, "contraste": 0.42},
    5: {"paleta": _pal(5), "formas": ["monticulo", "angular"], "motas": (140, 206, 64),
        "cristal": (140, 206, 64), "con_cristal": 0.6, "contraste": 0.45},
    6: {"paleta": _pal(6), "formas": ["angular", "monticulo"], "motas": (80, 130, 255),
        "cristal": (80, 130, 255), "con_cristal": 0.6, "contraste": 0.45},
    7: {"paleta": _pal(7), "formas": ["angular"], "brillo": (255, 110, 40), "columnas": True,
        "contraste": 0.42},
    8: {"paleta": _pal(8), "formas": ["aguja", "angular"], "brillo": (255, 160, 56), "contraste": 0.32},
    9: {"paleta": _pal(9), "formas": ["monticulo", "angular"], "brillo": (255, 170, 70),
        "metal": (150, 154, 172), "contraste": 0.34},
    10: {"paleta": _pal(10), "formas": ["angular"], "metal": (170, 186, 216), "contraste": 0.42},
    11: {"paleta": _pal(11), "formas": ["angular"], "cristal": (178, 182, 198), "cristalina": True,
         "contraste": 1.9},
    12: {"paleta": _pal(12), "formas": ["angular"], "cristal": (255, 214, 140), "cristalina": True,
         "contraste": 2.1},
}

CUANTAS = {"roca": 6, "grupo": 4, "bloque": 4, "piedra": 5, "plataforma": 3}


def escribir_catalogo(numero, carpeta, archivos):
    ruta = "res://assets/rocas/piso_%02d/" % numero
    adornos = "res://assets/bordes/piso_%02d/" % numero
    externos = [("Script", "res://scripts/catalogo_obstaculos.gd", "1_script")]
    listas = {"piedras": [], "rocas": [], "bloques": [], "grupos": [], "vegetacion": [], "plataformas": []}
    familia_lista = {"piedra": "piedras", "roca": "rocas", "bloque": "bloques", "grupo": "grupos",
                     "plataforma": "plataformas"}
    for nombre in archivos:
        ident = "%d_%s" % (len(externos) + 1, nombre.replace(".png", ""))
        externos.append(("Texture2D", ruta + nombre, ident))
        listas[familia_lista[nombre.split("_")[0]]].append(ident)
    # Lo que crece en las losas: los adornos de la pared del piso, sin copiar.
    for nombre in sorted(os.listdir(os.path.join(RAIZ, "assets", "bordes", "piso_%02d" % numero))):
        if nombre.startswith("adorno_") and nombre.endswith(".png"):
            ident = "%d_veg_%s" % (len(externos) + 1, nombre.replace(".png", ""))
            externos.append(("Texture2D", adornos + nombre, ident))
            listas["vegetacion"].append(ident)
    lineas = ['[gd_resource type="Resource" script_class="CatalogoObstaculos" load_steps=%d format=3]'
              % (len(externos) + 1), ""]
    for tipo, camino, ident in externos:
        lineas.append('[ext_resource type="%s" path="%s" id="%s"]' % (tipo, camino, ident))
    lineas += ["", "[resource]", 'script = ExtResource("1_script")']
    for campo in ("piedras", "rocas", "bloques", "grupos", "vegetacion", "plataformas"):
        lineas.append("%s = Array[Texture2D]([%s])" % (
            campo, ", ".join('ExtResource("%s")' % i for i in listas[campo])))
    lineas += ["colores_propios = true", ""]
    with open(os.path.join(carpeta, "catalogo.tres"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lineas))


def generar_piso(numero):
    t = ROCAS[numero]
    objetivo = luz_suelo(numero) * t["contraste"]
    carpeta = os.path.join(SALIDA, "piso_%02d" % numero)
    os.makedirs(carpeta, exist_ok=True)
    for viejo in os.listdir(carpeta):
        if viejo.endswith(".png"):
            os.remove(os.path.join(carpeta, viejo))
    archivos = []
    for familia, cuantas in CUANTAS.items():
        for i in range(cuantas):
            g = random.Random(numero * 1000 + len(archivos) * 37)
            if familia == "grupo":
                pieza = grupo(t, g, objetivo)
            elif familia == "piedra":
                pieza = piedra(t, g, objetivo)
            elif familia == "plataforma":
                pieza = plataforma(t, g, objetivo)
            else:
                pieza = roca(t, g, objetivo, familia)
            nombre = "%s_%d.png" % (familia, i)
            pieza.save(os.path.join(carpeta, nombre))
            archivos.append(nombre)
    escribir_catalogo(numero, carpeta, archivos)
    print("piso %2d: %d piezas, luz del cuerpo %.3f (suelo %.3f x %.2f)" % (
        numero, len(archivos), objetivo, luz_suelo(numero), t["contraste"]))


def main():
    pisos = [int(a) for a in sys.argv[1:]] or sorted(ROCAS)
    for numero in pisos:
        generar_piso(numero)


if __name__ == "__main__":
    main()
