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
import zlib

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


def rocio(azar):
    """El rocio del mago verde: un soplo de spray. Suena como mucho cada
    0,13 s mientras se dispara y dura un poco mas, asi que seguidos se oyen
    como un chorro. Suave y sin golpe: suena sin parar."""
    n = int(0.17 * SR)
    soplo = golpe(banda(ruido(n, azar), SR, lambda t: 2600 - 600 * t, 1.5), SR, 0.03, 8.0)
    return paso_bajo(soplo, SR, 5000)


def veneno_lanzado(azar):
    """El especial del mago verde, al salir sus proyectiles: un soplo que se
    abre y unos "blup" de burbuja, viscosos, como el veneno de la serpiente
    pero mas grande."""
    n = int(0.5 * SR)
    soplo = golpe(banda(ruido(n, azar), SR, lambda t: 900 + 1800 * t, 2.0), SR, 0.01, 6.0)
    burbujas = vacio(n)
    for i, (f0, f1) in enumerate([(220, 480), (300, 620), (180, 420), (260, 560)]):
        blup = golpe(barrido(f0, f1, 0.1, SR, curva=0.7), SR, 0.003, 20.0)
        sumar(burbujas, blup, int((0.02 + i * 0.07) * SR), 0.6)
    return paso_bajo(_mezcla((soplo, 0.7), (burbujas, 1.0)), SR, 3000)


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


def pisoton(azar):
    """El golem pisa: golpe sordo y grave que retumba."""
    n = int(0.9 * SR)
    golpe_grave = golpe(barrido(85, 30, 0.7, SR, curva=1.5), SR, 0.002, 5.0)
    tierra = golpe(paso_bajo(ruido(n, azar), SR, lambda t: 900 * (1 - t) + 120), SR, 0.002, 6.0)
    return reverberacion(saturar(_mezcla((golpe_grave, 1.0), (tierra, 0.8)), 1.6), SR, 0.25, 0.7)


def teletransporte(azar):
    """El cristal se desvanece: un brillo que sube y se corta."""
    n = int(0.5 * SR)
    subida = adsr(barrido(500, 2400, 0.45, SR, "triangulo", curva=0.8), SR, 0.02, 0.0, 1.0, 0.12)
    soplo = adsr(banda(ruido(n, azar), SR, lambda t: 1200 + 3500 * t, 4.0), SR, 0.05, 0.0, 1.0, 0.1)
    chispas = vacio(n)
    for k, nota in enumerate(("E6", "B6", "E7")):
        sumar(chispas, parciales(hz(nota), 0.3, SR, [(1, 1.0, 12), (2.76, 0.3, 18)]), int(k * 0.08 * SR), 0.4)
    return reverberacion(_mezcla((subida, 0.5), (soplo, 0.4), (chispas, 0.6)), SR, 0.35, 0.75)


def emerger(azar):
    """La planta sale del suelo: tierra que salta y un mordisco."""
    n = int(0.4 * SR)
    tierra = golpe(banda(ruido(n, azar), SR, lambda t: 900 - 500 * t, 1.5), SR, 0.002, 9.0)
    mordisco = vacio(n)
    for k in range(2):
        sumar(mordisco, golpe(barrido(320, 140, 0.06, SR), SR, 0.001, 45.0), int((0.05 + k * 0.07) * SR))
    return _mezcla((tierra, 0.8), (mordisco, 0.9))


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


# --- Gacha (2026-11-05) -------------------------------------------------------

def gacha_carga(azar):
    """La invocacion: un zumbido que crece y sube, con un brillo de cristal
    encima. Dura lo que la parte comun de todas las tiradas."""
    n = int(1.7 * SR)
    zumbido = adsr(barrido(70, 160, 1.7, SR, "triangulo", curva=1.6), SR, 0.3, 0.2, 0.9, 0.25)
    aire = adsr(banda(ruido(n, azar), SR, lambda t: 500 + 3500 * t * t, 3.0), SR, 0.4, 0.2, 0.8, 0.3)
    brillo = vacio(n)
    for k in range(9):
        nota = parciales(hz("E6") * (1 + k * 0.06), 0.35, SR, [(1, 1.0, 12), (2.76, 0.3, 18)], ataque=0.01)
        sumar(brillo, nota, int((0.25 + k * 0.15) * SR), 0.2 + k * 0.03)
    return reverberacion(_mezcla((zumbido, 0.6), (aire, 0.4), (brillo, 0.5)), SR, 0.35, 0.8)


def _subida(nota):
    def efecto(azar):
        """El orbe cambia al color de un tier mejor: una campana, mas aguda
        cuanto mas alto el tier."""
        tono = parciales(hz(nota), 0.7, SR, [(1, 1.0, 6), (2.0, 0.45, 9), (3.0, 0.2, 13), (4.2, 0.1, 18)], ataque=0.004)
        soplo = adsr(banda(ruido(int(0.25 * SR), azar), SR, lambda t: 1500 + 4000 * t, 4.0), SR, 0.02, 0.05, 0.5, 0.15)
        return reverberacion(_mezcla((tono, 1.0), (soplo, 0.25)), SR, 0.35, 0.75)
    return efecto


def gacha_estallido(azar):
    """El orbe revienta y sale lo que ha tocado: golpe grave, un "fsss" de
    chispas y un acorde que se abre."""
    n = int(1.4 * SR)
    boom = golpe(barrido(120, 40, 0.6, SR), SR, 0.002, 5.0)
    chispas = adsr(paso_alto(ruido(n, azar), SR, 3000), SR, 0.002, 0.3, 0.2, 0.8)
    acorde = vacio(n)
    for k, nota in enumerate(("C5", "G5", "C6", "E6")):
        sumar(acorde, parciales(hz(nota), 1.1, SR, [(1, 1.0, 3), (2, 0.3, 6)], ataque=0.01), int(k * 0.03 * SR), 0.3)
    return reverberacion(saturar(_mezcla((boom, 1.0), (chispas, 0.35), (acorde, 0.6)), 1.2), SR, 0.4, 0.85)


def gacha_carta(azar):
    """Una carta se da la vuelta: un "fip" de papel."""
    n = int(0.16 * SR)
    papel = adsr(banda(ruido(n, azar), SR, lambda t: 2500 + 3000 * t, 2.0), SR, 0.003, 0.04, 0.3, 0.08)
    return _mezcla((papel, 1.0), (golpe(barrido(900, 1400, 0.05, SR, "triangulo"), SR, 0.001, 50.0), 0.3))


def gacha_trueno(azar):
    """Un rayo cae sobre el orbe (solo si va a salir algo de los dos tiers de
    arriba): chasquido y retumbo."""
    n = int(1.2 * SR)
    chasquido = golpe(paso_alto(ruido(n, azar), SR, 1800), SR, 0.001, 14.0)
    retumbo = adsr(paso_bajo(ruido(n, azar), SR, 160), SR, 0.03, 0.3, 0.6, 0.8)
    return reverberacion(saturar(_mezcla((chasquido, 1.0), (retumbo, 0.9)), 1.4), SR, 0.3, 0.8)


def gacha_grieta(azar):
    """El orbe se agrieta (solo antes del tier mas alto): cristal que cruje."""
    salida = vacio(int(0.9 * SR))
    for k in range(6):
        f = 2400 + azar.random() * 3000
        sumar(salida, parciales(f, 0.25, SR, [(1, 1.0, 25), (1.5, 0.5, 30), (2.3, 0.3, 40)], ataque=0.001),
              int((k * 0.09 + azar.random() * 0.03) * SR), 0.4)
    crujido = golpe(paso_alto(ruido(int(0.4 * SR), azar), SR, 2500), SR, 0.001, 18.0)
    sumar(salida, crujido, 0, 0.6)
    return reverberacion(salida, SR, 0.35, 0.7)


def gacha_revelar(azar):
    """Se destapa algo de los tiers de abajo: arpegio corto que sube."""
    salida = vacio(int(1.1 * SR))
    for k, nota in enumerate(("G4", "C5", "E5", "G5")):
        sumar(salida, parciales(hz(nota), 0.7, SR, [(1, 1.0, 6), (2, 0.3, 9), (3, 0.12, 12)]), int(k * 0.06 * SR), 0.45)
    return reverberacion(salida, SR, 0.35, 0.8)


def gacha_s(azar):
    """El sello de una S o una legendaria: golpe de tambor grande y un acorde
    mayor que se queda sonando."""
    n = int(2.2 * SR)
    tambor = golpe(barrido(95, 42, 0.8, SR), SR, 0.002, 4.0)
    golpe_ruido = golpe(paso_bajo(ruido(n, azar), SR, 2500), SR, 0.001, 12.0)
    acorde = vacio(n)
    for k, nota in enumerate(("D4", "A4", "D5", "F#5", "A5")):
        sumar(acorde, adsr(oscilador("sierra", hz(nota), 1.9, SR, vibrato=0.004), SR, 0.04, 0.3, 0.6, 0.9), int(0.05 * SR), 0.12)
        sumar(acorde, parciales(hz(nota) * 2, 1.6, SR, [(1, 1.0, 3), (2, 0.3, 5)], ataque=0.01), int((0.08 + k * 0.05) * SR), 0.18)
    acorde = paso_bajo(acorde, SR, 3500)
    return reverberacion(saturar(_mezcla((tambor, 1.0), (golpe_ruido, 0.5), (acorde, 0.8)), 1.2), SR, 0.45, 0.9)


def gacha_smas(azar):
    """Lo mas raro (S+ o mitica): un barrido que sube, el estallido y un acorde
    brillante que se abre en arpegio, con destellos."""
    n = int(3.0 * SR)
    salida = vacio(n)
    subida = adsr(barrido(200, 2400, 0.55, SR, "sierra", curva=1.8), SR, 0.05, 0.05, 0.9, 0.05)
    sumar(salida, paso_bajo(subida, SR, 5000), 0, 0.25)
    sumar(salida, golpe(barrido(110, 38, 0.9, SR), SR, 0.002, 3.5), int(0.55 * SR), 1.0)
    sumar(salida, golpe(paso_alto(ruido(int(1.5 * SR), azar), SR, 2000), SR, 0.001, 4.0), int(0.55 * SR), 0.45)
    for k, nota in enumerate(("C4", "G4", "C5", "E5", "G5", "C6", "E6", "G6")):
        sumar(salida, parciales(hz(nota), 1.8, SR, [(1, 1.0, 2.5), (2, 0.35, 4), (3, 0.15, 6)], ataque=0.008),
              int((0.6 + k * 0.07) * SR), 0.22)
    for k in range(10):
        sumar(salida, parciales(hz("C7") * (1 + azar.random() * 0.5), 0.3, SR, [(1, 1.0, 14), (2.76, 0.3, 20)]),
              int((0.9 + k * 0.17) * SR), 0.12)
    return reverberacion(saturar(salida, 1.15), SR, 0.5, 0.92)


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
    "pisoton": (pisoton, -3.0),
    "teletransporte": (teletransporte, -8.0),
    "emerger": (emerger, -6.0),
    "rocio": (rocio, -15.0),
    "veneno_lanzado": (veneno_lanzado, -5.0),
    "gacha_carga": (gacha_carga, -9.0),
    "gacha_sube_0": (_subida("C5"), -9.0),
    "gacha_sube_1": (_subida("E5"), -8.0),
    "gacha_sube_2": (_subida("G5"), -7.0),
    "gacha_sube_3": (_subida("C6"), -6.0),
    "gacha_estallido": (gacha_estallido, -4.0),
    "gacha_carta": (gacha_carta, -12.0),
    "gacha_trueno": (gacha_trueno, -4.0),
    "gacha_grieta": (gacha_grieta, -7.0),
    "gacha_revelar": (gacha_revelar, -6.0),
    "gacha_s": (gacha_s, -3.0),
    "gacha_smas": (gacha_smas, -2.0),
}

# La semilla de cada efecto. Los 20 primeros la sacaban de su puesto en orden
# alfabetico, y anadir uno la cambiaba a todos los de detras: se conservan
# esas, para que no cambien al regenerar. Los nuevos la sacan de su nombre,
# que no depende de cuantos haya.
ORIGINALES = ["agujero_negro", "bajar", "caida", "carga_lista", "clic", "corazon",
              "disparo", "disparo_cargado", "disparo_enemigo", "escudo", "escudo_golpe",
              "explosion", "golpe_enemigo", "herido", "magma", "muerte_enemigo", "objeto",
              "puertas_abren", "puertas_cierran", "rayo"]


def semilla(nombre):
    if nombre in ORIGINALES:
        return 100 + ORIGINALES.index(nombre)
    return zlib.crc32(nombre.encode("utf-8"))


def main():
    os.makedirs(DESTINO, exist_ok=True)
    for nombre, (funcion, pico) in sorted(EFECTOS.items()):
        sonido = normalizar(funcion(random.Random(semilla(nombre))), pico)
        guardar_wav(os.path.join(DESTINO, nombre + ".wav"), sonido, SR)
        print(nombre, medir(sonido, SR))


if __name__ == "__main__":
    main()
