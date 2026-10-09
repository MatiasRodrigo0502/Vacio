# -*- coding: utf-8 -*-
"""Genera la musica del juego en assets/sonido/musica/:

- portada.wav: el menu. Lenta y misteriosa, en re menor.
- superficie.wav: pisos 1 a 6. Ritmo de aventura, en la menor.
- profundo.wav: pisos 7 a 12. Mas grave y con tambores, en mi menor.
- victoria.wav y derrota.wav: lo que suena al ganar o perder (no se repiten).

Las tres primeras se repiten sin corte: las notas que suenan al acabar caen
al principio de la vuelta siguiente, y la reverberacion se calcula sobre dos
vueltas (ver sintesis.en_bucle). El WAV lleva el punto de repeticion dentro,
y Godot lo lee al importar.

Cada pieza esta escrita aqui como lo que es: acordes, un bajo, un arpegio,
una melodia y (las de juego) una bateria, en pulsos (negras). Cambiar una
nota es cambiar una cadena como "E5" y volver a generar. Es determinista.

    python herramientas/generar_musica.py

Tarda alrededor de un minuto por pieza: es Python puro, sin numpy.
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sintesis import (adsr, banda, barrido, eco, en_bucle, golpe, guardar_wav,  # noqa: E402
                      hz, medir, multiplicar, oscilador, parciales,
                      paso_alto, paso_bajo, reverberacion, ruido, sumar, vacio)

RAIZ = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
DESTINO = os.path.join(RAIZ, "assets", "sonido", "musica")
SR = 22050


# --- Instrumentos -------------------------------------------------------------

def pad(nota, segundos):
    """Colchon de fondo: dos sierras suaves un pelo desafinadas entre si (eso
    es lo que lo hace ancho) y oscurecidas."""
    f = hz(nota)
    a = oscilador("sierra_suave", f * 1.004, segundos, SR, fase=0.0)
    b = oscilador("sierra_suave", f * 0.996, segundos, SR, fase=0.37)
    mezcla = [x + y for x, y in zip(a, b)]
    return adsr(paso_bajo(mezcla, SR, 1300), SR, 0.7, 0.4, 0.75, 1.1)


def pulsada(nota, segundos=1.2):
    """Cuerda pulsada, para los arpegios: los agudos se apagan antes."""
    return parciales(hz(nota), segundos, SR,
                     [(1, 1.0, 3.0), (2, 0.5, 5.0), (3, 0.28, 8.0), (4, 0.14, 11.0), (5, 0.07, 15.0)])


def campana(nota, segundos=2.5):
    """Como un vibrafono: la fundamental larga y dos parciales que se apagan
    antes. Para las melodias."""
    return parciales(hz(nota), segundos, SR, [(1, 1.0, 1.6), (4.0, 0.22, 6.0), (10.0, 0.05, 14.0)],
                     ataque=0.003)


def lider(nota, segundos):
    """Melodia de la musica de aventura: una cuadrada suave con vibrato."""
    tono = oscilador("cuadrada", hz(nota), segundos + 0.15, SR, vibrato=0.004, ritmo_vibrato=5.5)
    return adsr(paso_bajo(tono, SR, 2200), SR, 0.02, 0.1, 0.7, 0.15)


def bajo(nota, segundos):
    f = hz(nota)
    cuerpo = oscilador("sierra_suave", f, segundos, SR)
    sub = oscilador("seno", f, segundos, SR)
    mezcla = [0.6 * x + 0.7 * y for x, y in zip(cuerpo, sub)]
    return adsr(paso_bajo(mezcla, SR, 650), SR, 0.008, 0.12, 0.7, 0.06)


def dron(nota, segundos):
    tono = oscilador("organo", hz(nota), segundos, SR, vibrato=0.002, ritmo_vibrato=0.3)
    return adsr(paso_bajo(tono, SR, 420), SR, 2.0, 0.0, 1.0, 2.0)


def bombo(azar):
    cuerpo = golpe(barrido(115, 42, 0.38, SR, curva=1.6), SR, 0.002, 9.0)
    clic = golpe(paso_bajo(ruido(int(0.01 * SR), azar), SR, 3000), SR, 0.0005, 200.0)
    return [x + 0.3 * y for x, y in zip(cuerpo, clic + [0.0] * len(cuerpo))]


def charles(azar):
    return golpe(paso_alto(ruido(int(0.06 * SR), azar), SR, 6000), SR, 0.0008, 70.0)


def caja(azar):
    tono = golpe(barrido(210, 160, 0.15, SR), SR, 0.001, 22.0)
    piel = golpe(banda(ruido(int(0.18 * SR), azar), SR, 1900, 1.2), SR, 0.001, 18.0)
    return [0.5 * x + 0.8 * y for x, y in zip(tono, piel)]


def timbal(nota, azar):
    f = hz(nota)
    cuerpo = golpe(barrido(f * 1.5, f, 0.5, SR, curva=2.0), SR, 0.002, 6.5)
    piel = golpe(paso_bajo(ruido(int(0.05 * SR), azar), SR, 1500), SR, 0.001, 60.0)
    return [x + 0.25 * y for x, y in zip(cuerpo, piel + [0.0] * len(cuerpo))]


# --- Partitura ----------------------------------------------------------------

class Pieza:
    """Una pieza de 'compases' compases de 4 pulsos a 'bpm'. Cada pista se
    escribe aparte y se mezcla al final, para poder darle a cada una su eco."""

    def __init__(self, bpm, compases, bucle=True):
        self.pulso = 60.0 / bpm
        self.pulsos = compases * 4
        self.n = int(self.pulsos * self.pulso * SR)
        self.bucle = bucle
        self.pistas = {}

    def pista(self, nombre):
        if nombre not in self.pistas:
            self.pistas[nombre] = vacio(self.n)
        return self.pistas[nombre]

    def poner(self, nombre, pulso, sonido, ganancia=1.0):
        sumar(self.pista(nombre), sonido, int(pulso * self.pulso * SR), ganancia, self.bucle)

    def segundos(self, pulsos):
        return pulsos * self.pulso

    def mezclar(self, ganancias, efectos=None):
        efectos = efectos or {}
        salida = vacio(self.n)
        for nombre, datos in self.pistas.items():
            if nombre in efectos:
                efecto = efectos[nombre]
                datos = en_bucle(efecto, datos) if self.bucle else efecto(datos)
            sumar(salida, datos, 0, ganancias.get(nombre, 1.0))
        return salida


def acordes(pieza, progresion, pulsos_por_acorde, ganancia=1.0):
    """El colchon: cada acorde suena lo que dura y se solapa con el siguiente
    al soltarse."""
    for k, notas in enumerate(progresion):
        for nota in notas:
            pieza.poner("pad", k * pulsos_por_acorde,
                        pad(nota, pieza.segundos(pulsos_por_acorde) + 1.0), ganancia)


def arpegio(pieza, arpegios, pulsos_por_acorde, patron, paso=0.5, ganancia=1.0, azar=None):
    """Recorre las notas de cada acorde con 'patron' (indices), una cada
    'paso' pulsos. Con un poco de azar en la fuerza: tocado a maquina, todas
    iguales, suena a maquina."""
    for k, notas in enumerate(arpegios):
        golpes = int(pulsos_por_acorde / paso)
        for j in range(golpes):
            fuerza = 1.0 if j % 2 == 0 else 0.75
            if azar:
                fuerza *= azar.uniform(0.85, 1.0)
            nota = notas[patron[j % len(patron)]]
            pieza.poner("arpegio", k * pulsos_por_acorde + j * paso, pulsada(nota), ganancia * fuerza)


def melodia(pieza, notas, instrumento, inicio=0.0, pista="melodia", ganancia=1.0):
    """'notas': [(pulso, nota, duracion en pulsos)]."""
    for pulso, nota, dur in notas:
        if instrumento == "campana":
            sonido = campana(nota, max(1.5, pieza.segundos(dur) + 1.0))
        else:
            sonido = lider(nota, pieza.segundos(dur))
        pieza.poner(pista, inicio + pulso, sonido, ganancia)


# --- Las piezas -----------------------------------------------------------------

def portada():
    """Menu: re menor, lenta. Dm - Bb - F - C, dos compases cada uno, dos
    vueltas; en la segunda entra la melodia."""
    azar = random.Random(1)
    p = Pieza(bpm=64, compases=16)
    colchon = [["D3", "A3", "D4", "F4"], ["Bb2", "F3", "Bb3", "D4"],
               ["F3", "A3", "C4", "F4"], ["C3", "G3", "C4", "E4"]] * 2
    acordes(p, colchon, 8, 0.11)
    raices = ["D2", "Bb1", "F2", "C2"] * 2
    for k, raiz in enumerate(raices):
        for c in range(2):
            p.poner("bajo", k * 8 + c * 4, bajo(raiz, p.segundos(3.8)), 0.32)
    arpegios = [["D4", "F4", "A4", "D5"], ["Bb3", "D4", "F4", "Bb4"],
                ["F4", "A4", "C5", "F5"], ["C4", "E4", "G4", "C5"]] * 2
    arpegio(p, arpegios, 8, [0, 1, 2, 3, 1, 2, 3, 2], ganancia=0.13, azar=azar)
    melodia(p, [(0, "A5", 2), (2, "F5", 1), (3, "E5", 1), (4, "D5", 3),
                (8, "F5", 2), (10, "D5", 1), (11, "C5", 1), (12, "D5", 3),
                (16, "C6", 2), (18, "A5", 1), (19, "G5", 1), (20, "A5", 3),
                (24, "G5", 2), (26, "E5", 1), (27, "F5", 1), (28, "E5", 4)],
            "campana", inicio=32, ganancia=0.2)
    mezcla = p.mezclar({"pad": 1.0, "bajo": 1.0, "arpegio": 1.0, "melodia": 1.0},
                       {"arpegio": lambda x: eco(x, SR, p.segundos(0.75), 0.4, 0.45)})
    return en_bucle(lambda x: reverberacion(x, SR, 0.5, 0.86, 0.4), mezcla)


def superficie():
    """Pisos 1 a 6: la menor, a 92. Am - F - C - G y Am - F - G - E, con
    bajo a corcheas y bateria suave; la melodia entra en la segunda mitad."""
    azar = random.Random(2)
    p = Pieza(bpm=92, compases=16)
    colchon = [["A3", "C4", "E4"], ["F3", "A3", "C4"], ["C4", "E4", "G4"], ["G3", "B3", "D4"],
               ["A3", "C4", "E4"], ["F3", "A3", "C4"], ["G3", "B3", "D4"], ["E3", "G#3", "B3"]]
    acordes(p, colchon, 8, 0.07)
    raices = [("A1", "A2", "E2"), ("F1", "F2", "C2"), ("C2", "C3", "G2"), ("G1", "G2", "D2"),
              ("A1", "A2", "E2"), ("F1", "F2", "C2"), ("G1", "G2", "D2"), ("E1", "E2", "B1")]
    patron_bajo = [0, 0, 1, 0, 0, 0, 2, 0]
    for k, (raiz, octava, quinta) in enumerate(raices):
        opciones = (raiz, octava, quinta)
        for c in range(2):
            for j, idx in enumerate(patron_bajo):
                p.poner("bajo", k * 8 + c * 4 + j * 0.5, bajo(opciones[idx], p.segundos(0.42)),
                        0.3 if j % 2 == 0 else 0.22)
    arpegios = [["A4", "C5", "E5", "A5"], ["F4", "A4", "C5", "F5"], ["C5", "E5", "G5", "C6"],
                ["G4", "B4", "D5", "G5"], ["A4", "C5", "E5", "A5"], ["F4", "A4", "C5", "F5"],
                ["G4", "B4", "D5", "G5"], ["E4", "G#4", "B4", "E5"]]
    arpegio(p, arpegios, 8, [0, 2, 1, 3, 2, 1, 3, 1], ganancia=0.09, azar=azar)
    for compas in range(16):
        base = compas * 4
        p.poner("bateria", base, bombo(azar), 0.55)
        p.poner("bateria", base + 2, bombo(azar), 0.5)
        if compas % 2 == 1:
            p.poner("bateria", base + 3.5, bombo(azar), 0.35)
        p.poner("bateria", base + 1, caja(azar), 0.22)
        p.poner("bateria", base + 3, caja(azar), 0.25)
        for j in range(4):
            p.poner("bateria", base + j + 0.5, charles(azar), 0.13 * azar.uniform(0.7, 1.0))
    melodia(p, [(0, "E5", 1.5), (1.5, "D5", 0.5), (2, "C5", 1), (3, "D5", 1), (4, "E5", 3),
                (8, "A5", 1.5), (9.5, "G5", 0.5), (10, "F5", 1), (11, "E5", 1), (12, "C5", 3),
                (16, "D5", 1.5), (17.5, "E5", 0.5), (18, "D5", 1), (19, "B4", 1), (20, "G4", 2),
                (22, "B4", 1), (23, "D5", 1),
                (24, "E5", 2), (26, "B4", 1), (27, "G#4", 1), (28, "E5", 3.5)],
            "lider", inicio=32, ganancia=0.13)
    mezcla = p.mezclar({"pad": 1.0, "bajo": 1.0, "arpegio": 1.0, "bateria": 1.0, "melodia": 1.0},
                       {"arpegio": lambda x: eco(x, SR, p.segundos(0.75), 0.3, 0.35),
                        "melodia": lambda x: eco(x, SR, p.segundos(0.5), 0.25, 0.25)})
    return en_bucle(lambda x: reverberacion(x, SR, 0.3, 0.78, 0.45), mezcla)


def profundo():
    """Pisos 7 a 12: mi menor, a 100, con un dron grave y timbales. Em - C -
    Am - B y Em - F - Em - B: el fa natural (frigio) es lo que la oscurece y
    el si mayor tira de vuelta a mi."""
    azar = random.Random(3)
    p = Pieza(bpm=100, compases=16)
    p.poner("dron", 0, dron("E1", p.segundos(64)), 0.5)
    p.poner("dron", 0, dron("B1", p.segundos(64)), 0.25)
    colchon = [["E3", "G3", "B3"], ["C3", "E3", "G3"], ["A2", "C3", "E3"], ["B2", "D#3", "F#3"],
               ["E3", "G3", "B3"], ["F3", "A3", "C4"], ["E3", "G3", "B3"], ["B2", "D#3", "F#3"]]
    acordes(p, colchon, 8, 0.06)
    raices = ["E2", "C2", "A1", "B1", "E2", "F2", "E2", "B1"]
    # Ostinato: nota, silencio, nota, nota... y la octava al final.
    patron = [(0, 0), (0.75, 0), (1.5, 0), (2, 0), (2.75, 0), (3.5, 12)]
    for k, raiz in enumerate(raices):
        for c in range(2):
            for pulso, salto in patron:
                nota = raiz if salto == 0 else raiz[:-1] + str(int(raiz[-1]) + 1)
                p.poner("bajo", k * 8 + c * 4 + pulso, bajo(nota, p.segundos(0.4)), 0.3)
    for compas in range(16):
        base = compas * 4
        p.poner("bateria", base, bombo(azar), 0.6)
        p.poner("bateria", base + 2, bombo(azar), 0.5)
        p.poner("bateria", base + 1.5, timbal("A2", azar), 0.3)
        p.poner("bateria", base + 3, timbal("E2", azar), 0.35)
        if compas % 4 == 3:
            p.poner("bateria", base + 3.5, timbal("C3", azar), 0.3)
            p.poner("bateria", base + 3.75, timbal("A2", azar), 0.3)
        for j in range(8):
            p.poner("bateria", base + j * 0.5 + 0.25, charles(azar), (0.09 if j % 2 else 0.06) * azar.uniform(0.7, 1.0))
    arpegios = [["E4", "G4", "B4"], ["C4", "E4", "G4"], ["A3", "C4", "E4"], ["B3", "D#4", "F#4"],
                ["E4", "G4", "B4"], ["F4", "A4", "C5"], ["E4", "G4", "B4"], ["B3", "D#4", "F#4"]]
    arpegio(p, arpegios, 8, [0, 1, 2, 1], paso=1.0, ganancia=0.08, azar=azar)
    melodia(p, [(0, "B4", 1), (1, "E5", 1), (2, "G5", 2), (4, "F#5", 2), (6, "E5", 2),
                (8, "F5", 2), (10, "A5", 2), (12, "C6", 2), (14, "A5", 2),
                (16, "G5", 2), (18, "F#5", 1), (19, "E5", 1), (20, "B4", 4),
                (24, "D#5", 2), (26, "F#5", 2), (28, "B5", 3), (31, "F#5", 1)],
            "campana", inicio=32, ganancia=0.17)
    mezcla = p.mezclar({"dron": 1.0, "pad": 1.0, "bajo": 1.0, "bateria": 1.0, "arpegio": 1.0, "melodia": 1.0},
                       {"arpegio": lambda x: eco(x, SR, p.segundos(0.75), 0.35, 0.4),
                        "melodia": lambda x: eco(x, SR, p.segundos(1.5), 0.3, 0.3)})
    return en_bucle(lambda x: reverberacion(x, SR, 0.38, 0.84, 0.4), mezcla)


def victoria():
    """Al ganar: arpegio de do mayor hacia arriba y el acorde abierto."""
    p = Pieza(bpm=100, compases=3, bucle=False)
    for k, nota in enumerate(("C5", "E5", "G5", "C6", "E6")):
        p.poner("melodia", k * 0.33, campana(nota, 4.0), 0.3)
    for nota in ("C3", "G3", "C4", "E4", "G4"):
        p.poner("pad", 1.4, pad(nota, 4.0), 0.12)
    p.poner("bajo", 1.4, bajo("C2", 3.0), 0.35)
    return reverberacion(p.mezclar({}), SR, 0.5, 0.85, 0.35)


def derrota():
    """Al perder: notas que bajan, en re menor, sobre un dron."""
    p = Pieza(bpm=72, compases=3, bucle=False)
    p.poner("dron", 0, dron("D2", p.segundos(12)), 0.5)
    for k, nota in enumerate(("A4", "F4", "D4", "A3")):
        p.poner("arpegio", k * 1.0, pulsada(nota, 2.2), 0.4)
    p.poner("pad", 4.0, pad("D3", 4.5), 0.1)
    p.poner("pad", 4.0, pad("F3", 4.5), 0.1)
    p.poner("pad", 4.0, pad("A3", 4.5), 0.1)
    return reverberacion(p.mezclar({}), SR, 0.5, 0.85, 0.4)


def igualar(x, rms_db, pico_maximo_db=-1.0):
    """Todas al mismo volumen medio (RMS), no al mismo pico: la de los pisos
    hondos, con dron y tambores, tiene menos diferencia entre pico y media, y
    normalizada por el pico sonaba casi 4 dB mas fuerte que la de arriba. El
    pico solo pone el tope."""
    media = math.sqrt(sum(v * v for v in x) / len(x))
    pico = max(abs(v) for v in x)
    g = min(10.0 ** (rms_db / 20.0) / media, 10.0 ** (pico_maximo_db / 20.0) / pico)
    return multiplicar(x, g)


PIEZAS = {
    "portada": (portada, True),
    "superficie": (superficie, True),
    "profundo": (profundo, True),
    "victoria": (victoria, False),
    "derrota": (derrota, False),
}


def main():
    os.makedirs(DESTINO, exist_ok=True)
    elegidas = sys.argv[1:] or list(PIEZAS)
    for nombre in elegidas:
        funcion, bucle = PIEZAS[nombre]
        musica = igualar(funcion(), -18.0 if bucle else -16.0)
        guardar_wav(os.path.join(DESTINO, nombre + ".wav"), musica, SR, bucle=bucle)
        datos = medir(musica, SR)
        datos["salto_en_el_bucle"] = round(abs(musica[-1] - musica[0]), 4) if bucle else None
        print(nombre, datos, flush=True)


if __name__ == "__main__":
    main()
