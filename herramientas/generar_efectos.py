# -*- coding: utf-8 -*-
"""Genera los efectos de sonido del juego en assets/sonido/efectos/, uno por
archivo .wav. El autoload Sonido los carga todos por su nombre: un efecto
nuevo es una funcion mas en EFECTOS y una llamada Sonido.tocar(&"nombre").

Cada efecto se normaliza a su propio pico: los que suenan sin parar (el
disparo, cada medio segundo) van flojos, y los que importan y son raros (te
han dado, se cierran las puertas) van fuertes. Asi el equilibrio entre ellos
esta en un sitio, aqui, y no repartido por el codigo.

Es determinista (cada efecto con su semilla): sale siempre igual.

    python herramientas/generar_efectos.py
"""
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sintesis import (adsr, banda, barrido, golpe, guardar_wav, hz, medir,  # noqa: E402
                      normalizar, oscilador, parciales, paso_alto,
                      paso_bajo, reverberacion, ruido, saturar, sumar, vacio)

RAIZ = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
DESTINO = os.path.join(RAIZ, "assets", "sonido", "efectos")
SR = 32000


def _mezcla(*capas):
    n = max(len(c) for c, _ in capas)
    salida = vacio(n)
    for c, g in capas:
        sumar(salida, c, 0, g)
    return salida


# --- Jugador ------------------------------------------------------------------

def disparo(azar):
    """Bola normal: un "fiu" corto y suave. Suena cada medio segundo, asi que
    nada de agudos que cansen."""
    tono = golpe(barrido(980, 430, 0.11, SR, "triangulo", curva=1.6), SR, 0.002, 26.0)
    soplo = golpe(banda(ruido(int(0.08 * SR), azar), SR, lambda t: 2600 - 1400 * t, 3.0), SR, 0.001, 40.0)
    return paso_bajo(_mezcla((tono, 1.0), (soplo, 0.35)), SR, 4200)


def disparo_cargado(azar):
    """La bola cargada: un zumbido grave que se lanza, con soplido."""
    n = int(0.55 * SR)
    grave = golpe(barrido(320, 95, 0.55, SR, "triangulo", curva=1.4), SR, 0.004, 5.0)
    sub = golpe(barrido(110, 50, 0.55, SR), SR, 0.004, 6.0)
    soplo = golpe(banda(ruido(n, azar), SR, lambda t: 3000 * (1 - t) + 300, 2.0), SR, 0.01, 6.0)
    return _mezcla((grave, 0.8), (sub, 0.7), (soplo, 0.6))


def carga_lista(azar):
    """El aro se ha cerrado: un brillo de campanita."""
    return _mezcla(
        (parciales(hz("E6"), 0.4, SR, [(1, 1.0, 9), (2.76, 0.4, 14), (5.4, 0.15, 20)]), 1.0),
        (parciales(hz("B6"), 0.4, SR, [(1, 0.6, 11), (2.76, 0.2, 16)], ataque=0.03), 0.7))


def herido(azar):
    """Te han dado: un golpe sordo con un quejido que baja."""
    n = int(0.35 * SR)
    sordo = golpe(barrido(150, 55, 0.25, SR), SR, 0.002, 12.0)
    queja = golpe(paso_bajo(barrido(420, 190, 0.3, SR, "cuadrada"), SR, 1800), SR, 0.004, 9.0)
    chasquido = golpe(paso_bajo(ruido(n, azar), SR, 2500), SR, 0.001, 35.0)
    return saturar(_mezcla((sordo, 1.0), (queja, 0.45), (chasquido, 0.5)), 1.2)


def caida(azar):
    """Caer por un agujero: un silbido que baja hasta perderse."""
    silbido = adsr(barrido(900, 110, 0.6, SR, curva=0.8), SR, 0.01, 0.0, 1.0, 0.25)
    viento = adsr(banda(ruido(int(0.6 * SR), azar), SR, lambda t: 1500 - 1100 * t, 3.0), SR, 0.05, 0.0, 1.0, 0.3)
    return _mezcla((silbido, 0.7), (viento, 0.5))


def escudo(azar):
    """Sacar el escudo: un brillo que sube, de cristal."""
    salida = vacio(int(0.6 * SR))
    for k, nota in enumerate(("A5", "E6", "A6", "C#7")):
        tono = parciales(hz(nota), 0.45, SR, [(1, 1.0, 7), (2.0, 0.25, 12)], ataque=0.01)
        sumar(salida, tono, int(k * 0.04 * SR), 0.5)
    return reverberacion(salida, SR, mezcla=0.35, tamano=0.7)


def escudo_golpe(azar):
    """Un disparo se estrella en el escudo: clinc de metal."""
    return _mezcla(
        (parciales(1480, 0.25, SR, [(1, 1.0, 22), (1.62, 0.7, 30), (2.63, 0.4, 40), (3.9, 0.2, 55)], ataque=0.0008), 1.0),
        (golpe(paso_alto(ruido(int(0.03 * SR), azar), SR, 3000), SR, 0.0005, 120.0), 0.4))


def agujero_negro(azar):
    """El agujero se abre: un "uuuum" grave que tira hacia dentro."""
    n = int(1.8 * SR)
    grave = adsr(barrido(95, 38, 1.8, SR), SR, 0.08, 0.3, 0.8, 0.9)
    remolino = adsr(banda(ruido(n, azar), SR, lambda t: 200 + 1600 * (1 - t) ** 2, 5.0), SR, 0.3, 0.2, 0.8, 0.8)
    zumbido = adsr(oscilador("sierra_suave", 55, 1.8, SR, vibrato=0.02, ritmo_vibrato=7.0), SR, 0.15, 0.2, 0.7, 0.8)
    return reverberacion(_mezcla((grave, 1.0), (remolino, 0.7), (paso_bajo(zumbido, SR, 600), 0.5)), SR, 0.4, 0.8)


# --- Enemigos -----------------------------------------------------------------

def golpe_enemigo(azar):
    """La bola le da a un enemigo: un "tok" seco."""
    tono = golpe(barrido(260, 120, 0.08, SR), SR, 0.001, 30.0)
    chasquido = golpe(paso_bajo(ruido(int(0.02 * SR), azar), SR, 3500), SR, 0.0005, 90.0)
    return _mezcla((tono, 1.0), (chasquido, 0.6))


def muerte_enemigo(azar):
    """Un enemigo muere: un "plof" que se deshace. Hay unas 600 por partida:
    tiene que ser agradable, no un susto."""
    n = int(0.3 * SR)
    tono = golpe(barrido(520, 90, 0.25, SR, curva=1.5), SR, 0.002, 14.0)
    polvo = golpe(paso_bajo(ruido(n, azar), SR, lambda t: 4000 * (1 - t) + 300), SR, 0.002, 12.0)
    return _mezcla((tono, 0.8), (polvo, 0.7))


def explosion(azar):
    """Un slime revienta: estallido con cola grave."""
    n = int(0.8 * SR)
    estallido = golpe(paso_bajo(ruido(n, azar), SR, lambda t: 5000 * (1 - t) ** 2 + 150), SR, 0.002, 5.0)
    boom = golpe(barrido(90, 32, 0.7, SR), SR, 0.003, 5.0)
    return saturar(_mezcla((estallido, 0.9), (boom, 1.0)), 1.5)


def disparo_enemigo(azar):
    """Bola de veneno: un "blup" que sube, viscoso."""
    tono = golpe(barrido(240, 520, 0.14, SR, curva=0.7), SR, 0.004, 14.0)
    burbuja = golpe(barrido(600, 900, 0.06, SR), SR, 0.002, 40.0)
    return paso_bajo(_mezcla((tono, 1.0), (burbuja, 0.3)), SR, 2600)


def rayo(azar):
    """El rayo del cristal: un zumbido electrico rapido."""
    n = int(0.22 * SR)
    zap = golpe(paso_bajo(barrido(1700, 260, 0.22, SR, "cuadrada", curva=1.8), SR, 5000), SR, 0.001, 12.0)
    chispa = golpe(paso_alto(ruido(n, azar), SR, 2500), SR, 0.001, 25.0)
    anillo = parciales(hz("D6"), 0.22, SR, [(1, 0.5, 18), (1.5, 0.3, 22)])
    return _mezcla((zap, 0.8), (chispa, 0.35), (anillo, 0.4))


def magma(azar):
    """El golem lanza magma: un "fuuum" grave, de fuego."""
    n = int(0.4 * SR)
    fuego = adsr(banda(ruido(n, azar), SR, lambda t: 400 + 900 * t, 1.5), SR, 0.03, 0.1, 0.6, 0.2)
    grave = golpe(barrido(140, 85, 0.4, SR), SR, 0.01, 7.0)
    return _mezcla((fuego, 1.0), (grave, 0.8))


# --- Salas y objetos ------------------------------------------------------------

def puertas_cierran(azar):
    """El rastrillo cae: golpe de hierro y piedra que retumba."""
    n = int(0.9 * SR)
    piedra = golpe(paso_bajo(ruido(n, azar), SR, 900), SR, 0.002, 9.0)
    grave = golpe(barrido(75, 45, 0.6, SR), SR, 0.002, 6.0)
    hierro = parciales(196, 0.9, SR, [(1, 0.5, 6), (2.71, 0.5, 9), (5.13, 0.35, 13), (8.2, 0.2, 18)], ataque=0.001)
    return reverberacion(saturar(_mezcla((piedra, 0.9), (grave, 1.0), (hierro, 0.45)), 1.3), SR, 0.3, 0.75)


def puertas_abren(azar):
    """Sala limpia, se abren: el rastrillo sube con un acorde que resuelve."""
    n = int(1.2 * SR)
    salida = vacio(n)
    arrastre = adsr(paso_bajo(ruido(int(0.5 * SR), azar), SR, 700), SR, 0.05, 0.1, 0.7, 0.2)
    sumar(salida, arrastre, 0, 0.5)
    for k, nota in enumerate(("D4", "A4", "D5", "F#5")):
        tono = parciales(hz(nota), 0.9, SR, [(1, 1.0, 4), (2, 0.35, 7), (3, 0.15, 10)], ataque=0.006)
        sumar(salida, tono, int((0.12 + k * 0.07) * SR), 0.35)
    return reverberacion(salida, SR, 0.35, 0.8)


def objeto(azar):
    """Coger un objeto: arpegio magico hacia arriba."""
    salida = vacio(int(1.3 * SR))
    for k, nota in enumerate(("C5", "E5", "G5", "C6", "E6")):
        tono = parciales(hz(nota), 0.8, SR, [(1, 1.0, 5), (2.0, 0.3, 9), (3.0, 0.12, 12)])
        sumar(salida, tono, int(k * 0.065 * SR), 0.45)
    return reverberacion(salida, SR, 0.4, 0.8)


def corazon(azar):
    """Coger un corazon: dos notas calidas."""
    salida = vacio(int(0.9 * SR))
    for k, nota in enumerate(("A4", "E5")):
        tono = parciales(hz(nota), 0.7, SR, [(1, 1.0, 5), (2, 0.4, 8), (3, 0.1, 12)], ataque=0.008)
        sumar(salida, tono, int(k * 0.11 * SR), 0.6)
    return reverberacion(salida, SR, 0.3, 0.7)


def bajar(azar):
    """Saltar al agujero de la salida: soplido que baja y un golpe al llegar."""
    n = int(1.1 * SR)
    viento = adsr(banda(ruido(n, azar), SR, lambda t: 2200 * (1 - t) + 180, 2.5), SR, 0.05, 0.2, 0.8, 0.4)
    tono = adsr(barrido(600, 70, 1.1, SR, curva=0.9), SR, 0.02, 0.2, 0.8, 0.4)
    llegada = vacio(n)
    sumar(llegada, golpe(barrido(110, 45, 0.3, SR), SR, 0.002, 10.0), int(0.75 * SR))
    return reverberacion(_mezcla((viento, 0.7), (tono, 0.4), (llegada, 1.0)), SR, 0.3, 0.75)


def clic(azar):
    """Los botones de los menus."""
    return golpe(barrido(1300, 900, 0.04, SR, "triangulo"), SR, 0.0008, 70.0)


# Nombre del archivo -> (funcion, pico en dB). El pico es el volumen de cada
# uno respecto a los demas.
EFECTOS = {
    "disparo": (disparo, -11.0),
    "disparo_cargado": (disparo_cargado, -4.0),
    "carga_lista": (carga_lista, -12.0),
    "herido": (herido, -2.0),
    "caida": (caida, -5.0),
    "escudo": (escudo, -6.0),
    "escudo_golpe": (escudo_golpe, -7.0),
    "agujero_negro": (agujero_negro, -3.0),
    "golpe_enemigo": (golpe_enemigo, -10.0),
    "muerte_enemigo": (muerte_enemigo, -9.0),
    "explosion": (explosion, -4.0),
    "disparo_enemigo": (disparo_enemigo, -10.0),
    "rayo": (rayo, -8.0),
    "magma": (magma, -8.0),
    "puertas_cierran": (puertas_cierran, -4.0),
    "puertas_abren": (puertas_abren, -7.0),
    "objeto": (objeto, -5.0),
    "corazon": (corazon, -7.0),
    "bajar": (bajar, -4.0),
    "clic": (clic, -14.0),
}


def main():
    os.makedirs(DESTINO, exist_ok=True)
    for k, (nombre, (funcion, pico)) in enumerate(sorted(EFECTOS.items())):
        sonido = normalizar(funcion(random.Random(100 + k)), pico)
        guardar_wav(os.path.join(DESTINO, nombre + ".wav"), sonido, SR)
        print(nombre, medir(sonido, SR))


if __name__ == "__main__":
    main()
