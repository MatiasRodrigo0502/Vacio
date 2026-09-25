# -*- coding: utf-8 -*-
"""Genera el pack de arte del NUCLEO (pisos 9 a 12): assets/nucleo/.

Sigue el estilo del pack del manto que hizo Matias: sombreado suave de arriba
(claro) a abajo (oscuro), contorno oscuro y vetas finas incandescentes. Cambia
el material: el nucleo de la Tierra es hierro y niquel, asi que la roca es
metal (mas fria y con un brillo cepillado) y las vetas son mas calientes, casi
blancas, porque el nucleo esta mas caliente que el manto. En lugar de cristales
de olivino, cristales de hierro.

Las mismas familias, prefijos y cantidades que manto/, asi que el juego lo usa
sin tocar GDScript: basta con apuntar el catalogo_arte del piso.

COMO USARLO:
    python herramientas/generar_nucleo.py
desde la raiz del proyecto. Todo sale de semillas fijas: volver a ejecutarlo da
exactamente los mismos PNG en las tres maquinas del equipo. Despues hay que
abrir Godot (o importar en headless) para que genere los .import.

POR QUE SOLO CON PIL:
es lo unico que ya esta instalado en los equipos del instituto. Sin numpy, el
sombreado se hace componiendo capas (degradados, bordes desplazados, blur), que
es mas lento pero para cuarenta piezas da igual.
"""
import io
import math
import os
import random

from PIL import Image, ImageChops, ImageDraw, ImageFilter

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DESTINO = os.path.join(RAIZ, "assets", "nucleo")

## Se dibuja a 4x y se reduce al final: bordes suaves sin depender de nada mas.
ESCALA = 4

# --- Paleta ------------------------------------------------------------------
# Luminosidad calibrada con la misma medida que el manto (media de los pixeles
# del todo opacos): sus rocas dan 31 y las de la cueva 33. El tinte por
# profundidad de piso.gd esta ajustado para ese brillo, y lo que estorba tiene
# que verse igual en todos los pisos. Ver MEDIDAS al final.
METAL_ARRIBA = (57, 59, 70)
METAL_ABAJO = (10, 10, 15)
CONTORNO = (8, 8, 12)
BRILLO_BORDE = (178, 186, 206)
CEPILLADO = (190, 200, 222)
VETA_NUCLEO = (255, 246, 214)
VETA_HALO = (255, 158, 58)

## Las columnas son la roca de los pisos 9-12 (su familia_obstaculos es "bloque"),
## asi que son las que mas tienen que distinguirse del suelo. Medido con la misma
## cuenta que la nota de tinte_profundidad() en piso.gd (luminosidad de la roca
## tintada entre la del suelo): la cueva da 0,32 en el piso 9, y con el metal
## normal las columnas daban 0,55, pasado el 0,48 en el que la nota dice que la
## roca se empieza a fundir con el suelo. Oscurecidas asi quedan a la par que
## la cueva.
OSCURECER_COLUMNAS = 0.55
## Las losas se oscurecen por la misma razon. piso.gd las pinta con un 0,6
## encima para que acaben tan claras como las rocas ("lo que estorba tiene que
## verse igual"): con el manto sale clavado (losas 55 x 0,6 = 33, rocas 34,5).
## Aqui las rocas son las columnas, mas oscuras, asi que las losas tambien.
OSCURECER_LOSAS = 0.45

CRISTAL_ARRIBA = (156, 166, 192)
CRISTAL_ABAJO = (40, 46, 64)
CRISTAL_CALIENTE_ARRIBA = (250, 210, 150)
CRISTAL_CALIENTE_ABAJO = (150, 66, 22)


# --- Utilidades --------------------------------------------------------------

def _lienzo(ancho, alto):
    return Image.new("L", (ancho * ESCALA, alto * ESCALA), 0)


def _desplazar(mascara, dx, dy):
    """Desplaza sin dar la vuelta (ImageChops.offset envuelve los bordes)."""
    fuera = Image.new(mascara.mode, mascara.size, 0)
    fuera.paste(mascara, (dx, dy))
    return fuera


def _degradado(tamano, arriba, abajo, y0, y1):
    """Degradado vertical de 'arriba' en y0 a 'abajo' en y1, en RGB."""
    ancho, alto = tamano
    columna = Image.new("RGB", (1, alto))
    px = columna.load()
    for y in range(alto):
        t = min(1.0, max(0.0, (y - y0) / max(1.0, float(y1 - y0))))
        px[0, y] = tuple(int(a + (b - a) * t) for a, b in zip(arriba, abajo))
    return columna.resize((ancho, alto))


def _plano(tamano, color):
    return Image.new("RGB", tamano, color)


def _con_alfa(mascara, factor):
    return mascara.point(lambda v: int(v * factor))


def _vetas(mascara, generador, cuantas, largo_min, largo_max):
    """Grietas: caminos al azar dentro de la pieza, lejos del borde."""
    capa = Image.new("L", mascara.size, 0)
    dibujo = ImageDraw.Draw(capa)
    dentro = mascara.filter(ImageFilter.MinFilter(ESCALA * 6 + 1))
    caja = dentro.getbbox()
    if caja is None:
        return capa
    px = dentro.load()
    for _ in range(cuantas):
        for _intento in range(40):
            x = generador.uniform(caja[0], caja[2])
            y = generador.uniform(caja[1], caja[3])
            if px[int(x), int(y)] > 200:
                break
        else:
            continue
        angulo = generador.uniform(0, math.tau)
        puntos = [(x, y)]
        for _paso in range(generador.randint(largo_min, largo_max)):
            angulo += generador.uniform(-0.9, 0.9)
            x += math.cos(angulo) * ESCALA * 3.5
            y += math.sin(angulo) * ESCALA * 3.5
            if not (0 <= x < mascara.width and 0 <= y < mascara.height):
                break
            if px[int(x), int(y)] < 200:
                break
            puntos.append((x, y))
        if len(puntos) > 1:
            dibujo.line(puntos, fill=255, width=int(ESCALA * 2.2), joint="curve")
    return ImageChops.multiply(capa, dentro)


def _pintar_metal(mascara, generador, vetas, arriba=METAL_ARRIBA, abajo=METAL_ABAJO,
                  cepillado=True):
    """Pinta una pieza de metal sobre su mascara. Devuelve RGBA a 4x."""
    caja = mascara.getbbox()
    y0, y1 = caja[1], caja[3]
    color = _degradado(mascara.size, arriba, abajo, y0, y1)

    # Luz de borde arriba: la mascara menos ella misma bajada unos pixeles
    # deja solo el filo de arriba. Difuminado, es el brillo del canto.
    filo = ImageChops.subtract(mascara, _desplazar(mascara, 0, ESCALA * 4))
    filo = filo.filter(ImageFilter.GaussianBlur(ESCALA * 1.5))
    color = Image.composite(_plano(mascara.size, BRILLO_BORDE), color, _con_alfa(filo, 0.45))

    # Sombra de abajo, igual pero al reves.
    fondo = ImageChops.subtract(mascara, _desplazar(mascara, 0, -ESCALA * 5))
    fondo = fondo.filter(ImageFilter.GaussianBlur(ESCALA * 2))
    color = Image.composite(_plano(mascara.size, CONTORNO), color, _con_alfa(fondo, 0.6))

    # Motas: el metal fundido y vuelto a enfriar no es liso.
    motas = Image.new("L", mascara.size, 0)
    claras = Image.new("L", mascara.size, 0)
    d_motas = ImageDraw.Draw(motas)
    d_claras = ImageDraw.Draw(claras)
    for _ in range(int(mascara.width * mascara.height / (ESCALA * ESCALA * 620))):
        x = generador.uniform(caja[0], caja[2])
        y = generador.uniform(caja[1], caja[3])
        r = generador.uniform(1.0, 3.2) * ESCALA
        destino = d_claras if generador.random() < 0.35 else d_motas
        destino.ellipse((x - r * 1.6, y - r, x + r * 1.6, y + r), fill=255)
    motas = ImageChops.multiply(motas.filter(ImageFilter.GaussianBlur(ESCALA)), mascara)
    claras = ImageChops.multiply(claras.filter(ImageFilter.GaussianBlur(ESCALA)), mascara)
    color = Image.composite(_plano(mascara.size, CONTORNO), color, _con_alfa(motas, 0.18))
    color = Image.composite(_plano(mascara.size, BRILLO_BORDE), color, _con_alfa(claras, 0.07))

    # Cepillado: dos o tres rayas de brillo casi horizontales. Es lo que dice
    # "metal" en vez de "roca", y lo que distingue esto del basalto del manto.
    if cepillado:
        rayas = Image.new("L", mascara.size, 0)
        d_rayas = ImageDraw.Draw(rayas)
        for _ in range(generador.randint(2, 3)):
            y = generador.uniform(y0 + (y1 - y0) * 0.18, y0 + (y1 - y0) * 0.55)
            inclinacion = generador.uniform(-0.12, 0.12) * (caja[2] - caja[0])
            d_rayas.line([(caja[0], y), (caja[2], y + inclinacion)], fill=255,
                         width=int(ESCALA * generador.uniform(1.5, 3.0)))
        rayas = ImageChops.multiply(rayas.filter(ImageFilter.GaussianBlur(ESCALA * 1.2)), mascara)
        color = Image.composite(_plano(mascara.size, CEPILLADO), color, _con_alfa(rayas, 0.16))

    # Vetas incandescentes: halo ancho y naranja, y encima el hilo casi blanco.
    if vetas > 0:
        grietas = _vetas(mascara, generador, vetas, 4, 11)
        halo = grietas.filter(ImageFilter.GaussianBlur(ESCALA * 2.8))
        color = Image.composite(_plano(mascara.size, VETA_HALO), color,
                                _con_alfa(halo.point(lambda v: min(255, v * 2)), 0.9))
        color = Image.composite(_plano(mascara.size, VETA_NUCLEO), color, grietas)

    return _cerrar(color, mascara)


def _cerrar(color, mascara):
    """Contorno oscuro de 2 px por fuera, y el alfa de la pieza."""
    grande = mascara.filter(ImageFilter.MaxFilter(ESCALA * 2 + 1))
    color = Image.composite(color, _plano(mascara.size, CONTORNO), mascara)
    pieza = color.convert("RGBA")
    pieza.putalpha(grande)
    return pieza


def _reducir(pieza, recortar=True, margen=2):
    """De 4x a tamano real. Recortada a su contenido, como las del manto."""
    pequena = pieza.resize((pieza.width // ESCALA, pieza.height // ESCALA), Image.LANCZOS)
    if not recortar:
        return pequena
    caja = pequena.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()
    caja = (max(0, caja[0] - margen), max(0, caja[1] - margen),
            min(pequena.width, caja[2] + margen), min(pequena.height, caja[3] + margen))
    return pequena.crop(caja)


# --- Formas ------------------------------------------------------------------

def _monticulo(mascara, cx, base, ancho, alto, generador, punta=None):
    """Un monticulo: base casi plana y perfil de arriba con ruido."""
    dibujo = ImageDraw.Draw(mascara)
    punta = punta if punta is not None else generador.uniform(0.4, 1.3)
    sesgo = generador.uniform(0.7, 1.4)
    fases = [generador.uniform(0, math.tau) for _ in range(3)]
    puntos = []
    pasos = 40
    for i in range(pasos + 1):
        t = i / pasos
        perfil = math.sin(math.pi * (t ** sesgo)) ** punta
        ruido = 1.0 + 0.07 * math.sin(t * 7 + fases[0]) + 0.05 * math.sin(t * 13 + fases[1])
        x = cx - ancho / 2 + ancho * t
        puntos.append((x * ESCALA, (base - alto * perfil * ruido) * ESCALA))
    # Base con las esquinas redondeadas hacia dentro.
    puntos.append(((cx + ancho / 2 - ancho * 0.05) * ESCALA, (base + alto * 0.05) * ESCALA))
    puntos.append(((cx - ancho / 2 + ancho * 0.05) * ESCALA, (base + alto * 0.05) * ESCALA))
    dibujo.polygon(puntos, fill=255)


def _pepita(mascara, cx, cy, radio_x, radio_y, generador):
    """Una piedra pequena: elipse con el borde irregular."""
    dibujo = ImageDraw.Draw(mascara)
    fases = [generador.uniform(0, math.tau) for _ in range(3)]
    puntos = []
    for i in range(48):
        a = math.tau * i / 48
        r = 1.0 + 0.10 * math.sin(a * 3 + fases[0]) + 0.06 * math.sin(a * 5 + fases[1])
        # Mas plana por abajo: esta apoyada en el suelo.
        ry = radio_y * (0.78 if math.sin(a) > 0 else 1.0)
        puntos.append(((cx + math.cos(a) * radio_x * r) * ESCALA,
                       (cy + math.sin(a) * ry * r) * ESCALA))
    dibujo.polygon(puntos, fill=255)


# --- Familias ----------------------------------------------------------------

def roca(indice):
    g = random.Random(1000 + indice)
    ancho, alto = g.randint(120, 160), g.randint(95, 140)
    lienzo = _lienzo(ancho + 20, alto + 20)
    _monticulo(lienzo, (ancho + 20) / 2, alto + 12, ancho, alto, g)
    return _reducir(_pintar_metal(lienzo, g, vetas=g.randint(1, 3)))


def piedra(indice):
    g = random.Random(2000 + indice)
    rx, ry = g.randint(46, 64), g.randint(32, 52)
    lienzo = _lienzo(rx * 2 + 20, ry * 2 + 20)
    _pepita(lienzo, rx + 10, ry + 10, rx, ry, g)
    return _reducir(_pintar_metal(lienzo, g, vetas=g.choice([0, 0, 1])))


def grupo(indice):
    g = random.Random(3000 + indice)
    ancho_total, alto_total = 170, 150
    capas = []
    cuantos = g.randint(3, 5)
    for n in range(cuantos):
        lienzo = _lienzo(ancho_total, alto_total)
        # Los de atras, mas arriba y mas oscuros; los de delante, abajo.
        fondo = n / max(1, cuantos - 1)
        ancho = g.randint(55, 95)
        alto = g.randint(50, 95)
        cx = g.uniform(ancho / 2 + 6, ancho_total - ancho / 2 - 6)
        base = alto_total - 8 - (1.0 - fondo) * g.uniform(10, 28)
        _monticulo(lienzo, cx, base, ancho, alto, g)
        oscurecer = 0.7 + 0.3 * fondo
        arriba = tuple(int(c * oscurecer) for c in METAL_ARRIBA)
        capas.append(_pintar_metal(lienzo, g, vetas=g.choice([0, 1, 1]), arriba=arriba))
    pieza = capas[0]
    for capa in capas[1:]:
        pieza = Image.alpha_composite(pieza, capa)
    return _reducir(pieza)


def bloque(indice):
    """Prismas hexagonales de hierro, de uno a tres juntos.

    El hierro del nucleo interno cristaliza en red hexagonal, asi que la forma
    de columna del manto vale tambien aqui, y encaja con el pack de Matias.
    """
    g = random.Random(4000 + indice)
    cuantas = g.choice([1, 1, 2, 2, 3])
    ancho_total, alto_total = 150, 175
    pieza = Image.new("RGBA", (ancho_total * ESCALA, alto_total * ESCALA), (0, 0, 0, 0))
    columnas = []
    for n in range(cuantas):
        w = g.randint(34, 46)
        h = g.randint(85, 150)
        columnas.append((w, h))
    columnas.sort(key=lambda c: -c[1])
    x = ancho_total / 2 - sum(c[0] for c in columnas) * 0.42
    for w, h in columnas:
        cx = x + w / 2
        x += w * 0.84
        base = alto_total - 10 - g.uniform(0, 8)
        pieza = Image.alpha_composite(pieza, _columna(cx, base, w, h, g, ancho_total, alto_total))
    return _reducir(pieza)


def _columna(cx, base, w, h, g, ancho_total, alto_total):
    ry = w * 0.24
    arriba = base - h
    e = ESCALA
    caras = {
        "izquierda": [(cx - w / 2, arriba), (cx - w / 4, arriba + ry), (cx - w / 4, base + ry), (cx - w / 2, base)],
        "centro": [(cx - w / 4, arriba + ry), (cx + w / 4, arriba + ry), (cx + w / 4, base + ry), (cx - w / 4, base + ry)],
        "derecha": [(cx + w / 4, arriba + ry), (cx + w / 2, arriba), (cx + w / 2, base), (cx + w / 4, base + ry)],
        "tapa": [(cx - w / 2, arriba), (cx - w / 4, arriba - ry), (cx + w / 4, arriba - ry),
                 (cx + w / 2, arriba), (cx + w / 4, arriba + ry), (cx - w / 4, arriba + ry)],
    }
    # Luz de arriba a la izquierda: la tapa es lo mas claro, la cara derecha
    # lo mas oscuro.
    tonos = {"tapa": 1.25, "izquierda": 0.85, "centro": 1.0, "derecha": 0.62}
    mascara = _lienzo(ancho_total, alto_total)
    color = Image.new("RGB", mascara.size, CONTORNO)
    for cara, puntos in caras.items():
        m = _lienzo(ancho_total, alto_total)
        ImageDraw.Draw(m).polygon([(px * e, py * e) for px, py in puntos], fill=255)
        tono = tonos[cara] * OSCURECER_COLUMNAS
        a = tuple(min(255, int(c * tono)) for c in METAL_ARRIBA)
        b = tuple(min(255, int(c * tono)) for c in METAL_ABAJO)
        color = Image.composite(_degradado(m.size, a, b, (arriba - ry) * e, (base + ry) * e), color, m)
        mascara = ImageChops.lighter(mascara, m)
    # Aristas: lineas finas de brillo donde se juntan las caras.
    aristas = Image.new("L", mascara.size, 0)
    d = ImageDraw.Draw(aristas)
    for px_ in (cx - w / 4, cx + w / 4):
        d.line([(px_ * e, (arriba + ry) * e), (px_ * e, (base + ry) * e)], fill=255, width=e)
    d.line([((cx - w / 2) * e, arriba * e), ((cx - w / 4) * e, (arriba + ry) * e),
            ((cx + w / 4) * e, (arriba + ry) * e), ((cx + w / 2) * e, arriba * e)], fill=255, width=e)
    color = Image.composite(_plano(mascara.size, BRILLO_BORDE), color, _con_alfa(aristas, 0.3))
    # Alguna veta caliente en las caras.
    if g.random() < 0.7:
        grietas = _vetas(mascara, g, g.randint(1, 2), 3, 7)
        halo = grietas.filter(ImageFilter.GaussianBlur(ESCALA * 2.0))
        color = Image.composite(_plano(mascara.size, VETA_HALO), color, _con_alfa(halo, 0.85))
        color = Image.composite(_plano(mascara.size, VETA_NUCLEO), color, grietas)
    return _cerrar(color, mascara)


def plataforma(indice):
    """Costra de metal enfriado sobre el metal liquido, con juntas al rojo."""
    g = random.Random(5000 + indice)
    ancho, alto = g.randint(210, 250), g.randint(38, 58)
    lienzo = _lienzo(ancho + 16, alto + 16)
    _pepita(lienzo, (ancho + 16) / 2, (alto + 16) / 2, ancho / 2, alto / 2, g)
    pieza = _pintar_metal(lienzo, g, vetas=0, cepillado=False,
                          arriba=tuple(int(c * OSCURECER_LOSAS) for c in METAL_ARRIBA),
                          abajo=tuple(int(c * OSCURECER_LOSAS) for c in METAL_ABAJO))
    # Juntas: cada punto se une con sus dos vecinos mas cercanos, que es como
    # se rompe una costra al enfriarse (placas, no rayas sueltas).
    juntas = Image.new("L", lienzo.size, 0)
    d = ImageDraw.Draw(juntas)
    puntos = [((g.uniform(0.1, 0.9) * ancho + 8) * ESCALA, (g.uniform(0.2, 0.8) * alto + 8) * ESCALA)
              for _ in range(g.randint(9, 13))]
    for p in puntos:
        cercanos = sorted(puntos, key=lambda q: (q[0] - p[0]) ** 2 + (q[1] - p[1]) ** 2)[1:3]
        for q in cercanos:
            d.line([p, q], fill=255, width=int(ESCALA * 2.0))
    dentro = lienzo.filter(ImageFilter.MinFilter(ESCALA * 3 + 1))
    juntas = ImageChops.multiply(juntas, dentro)
    halo = juntas.filter(ImageFilter.GaussianBlur(ESCALA * 1.8))
    rgb = pieza.convert("RGB")
    rgb = Image.composite(_plano(rgb.size, VETA_HALO), rgb, _con_alfa(halo, 0.8))
    rgb = Image.composite(_plano(rgb.size, VETA_NUCLEO), rgb, juntas)
    rgb = rgb.convert("RGBA")
    rgb.putalpha(pieza.getchannel("A"))
    return _reducir(rgb)


def cristal(indice):
    """Cristales de hierro: agujas plateadas, y algunas al rojo blanco.

    Conservan un lienzo de 192x192 con aire alrededor, como la vegetacion de
    la cueva y los cristales del manto: el juego los planta sobre las
    plataformas y cuenta con ese tamano.
    """
    g = random.Random(6000 + indice)
    caliente = indice % 3 == 2
    arriba = CRISTAL_CALIENTE_ARRIBA if caliente else CRISTAL_ARRIBA
    abajo = CRISTAL_CALIENTE_ABAJO if caliente else CRISTAL_ABAJO
    lado = 192
    pieza = Image.new("RGBA", (lado * ESCALA, lado * ESCALA), (0, 0, 0, 0))
    base_x, base_y = lado / 2, lado * 0.72
    cuantos = g.randint(3, 5)
    agujas = []
    for n in range(cuantos):
        angulo = math.radians(g.uniform(-38, 38))
        largo = g.uniform(46, 82)
        grosor = g.uniform(9, 15)
        agujas.append((abs(angulo), angulo, largo, grosor))
    # Las mas inclinadas, detras.
    agujas.sort(key=lambda a: -a[0])
    for _, angulo, largo, grosor in agujas:
        x0 = base_x + g.uniform(-10, 10)
        punta = (x0 + math.sin(angulo) * largo, base_y - math.cos(angulo) * largo)
        normal = (math.cos(angulo) * grosor / 2, math.sin(angulo) * grosor / 2)
        medio = (x0 + math.sin(angulo) * largo * 0.72, base_y - math.cos(angulo) * largo * 0.72)
        forma = [(x0 - normal[0], base_y - normal[1]),
                 (medio[0] - normal[0], medio[1] - normal[1]),
                 punta,
                 (medio[0] + normal[0], medio[1] + normal[1]),
                 (x0 + normal[0], base_y + normal[1])]
        m = _lienzo(lado, lado)
        ImageDraw.Draw(m).polygon([(px * ESCALA, py * ESCALA) for px, py in forma], fill=255)
        color = _degradado(m.size, arriba, abajo, (base_y - largo) * ESCALA, base_y * ESCALA)
        # Mitad izquierda mas clara: una cara del cristal a la luz.
        izquierda = _lienzo(lado, lado)
        ImageDraw.Draw(izquierda).polygon(
            [(px * ESCALA, py * ESCALA) for px, py in forma[:3] + [(x0, base_y)]], fill=255)
        color = Image.composite(_plano(m.size, (255, 255, 255)), color,
                                _con_alfa(ImageChops.multiply(izquierda, m), 0.22))
        pieza = Image.alpha_composite(pieza, _cerrar(color, m))
    if caliente:
        # Un resplandor suave detras: estan tan calientes que alumbran.
        resplandor = pieza.getchannel("A").filter(ImageFilter.GaussianBlur(ESCALA * 5))
        fondo = Image.new("RGBA", pieza.size, VETA_HALO + (0,))
        fondo.putalpha(_con_alfa(resplandor, 0.45))
        pieza = Image.alpha_composite(fondo, pieza)
    return _reducir(pieza, recortar=False)


FAMILIAS = [("piedra", piedra, 8), ("roca", roca, 10), ("bloque", bloque, 7),
            ("grupo", grupo, 6), ("plataforma", plataforma, 5), ("vegetacion", cristal, 6)]


def _luminosidad(pieza):
    """La misma medida que el pack del manto: media de lo del todo opaco."""
    datos = pieza.get_flattened_data() if hasattr(pieza, "get_flattened_data") else pieza.getdata()
    vals = [0.299 * r + 0.587 * g + 0.114 * b for r, g, b, a in datos if a > 250]
    return sum(vals) / len(vals) if vals else 0.0


def _catalogo(nombre, con_cristales, archivos):
    """Escribe el .tres del catalogo, con el mismo formato que los del manto."""
    lineas = ['[ext_resource type="Script" path="res://scripts/catalogo_obstaculos.gd" id="0_catalogo"]']
    listas = {}
    for familia, _f, cuantas in FAMILIAS:
        if familia == "vegetacion" and not con_cristales:
            listas[familia] = []
            continue
        ids = []
        for i in range(cuantas):
            ide = "nuc_%s_%02d" % (familia, i)
            lineas.append('[ext_resource type="Texture2D" path="res://assets/nucleo/%s_%02d.png" id="%s"]'
                          % (familia, i, ide))
            ids.append('ExtResource("%s")' % ide)
        listas[familia] = ids
    campos = {"piedra": "piedras", "roca": "rocas", "bloque": "bloques", "grupo": "grupos",
              "vegetacion": "vegetacion", "plataforma": "plataformas"}
    texto = '[gd_resource type="Resource" script_class="CatalogoObstaculos" load_steps=%d format=3]\n\n' % (len(lineas) + 1)
    texto += "\n".join(lineas) + '\n\n[resource]\nscript = ExtResource("0_catalogo")\n'
    for familia in ("piedra", "roca", "bloque", "grupo", "vegetacion", "plataforma"):
        texto += "%s = Array[Texture2D]([%s])\n" % (campos[familia], ", ".join(listas[familia]))
    with io.open(os.path.join(DESTINO, nombre), "w", encoding="utf-8", newline="\n") as f:
        f.write(texto)


def main():
    os.makedirs(DESTINO, exist_ok=True)
    medidas = {}
    for familia, funcion, cuantas in FAMILIAS:
        valores = []
        for i in range(cuantas):
            pieza = funcion(i)
            pieza.save(os.path.join(DESTINO, "%s_%02d.png" % (familia, i)))
            valores.append(_luminosidad(pieza))
        medidas[familia] = sum(valores) / len(valores)
        print("%-11s %2d piezas  luminosidad media %.1f" % (familia, cuantas, medidas[familia]))
    _catalogo("catalogo_nucleo.tres", True, None)
    _catalogo("catalogo_nucleo_sin_cristales.tres", False, None)
    print("catalogos escritos en", DESTINO)


if __name__ == "__main__":
    main()
