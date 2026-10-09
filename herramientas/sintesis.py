# -*- coding: utf-8 -*-
"""Herramientas de sintesis de sonido para generar_efectos.py y
generar_musica.py: osciladores, envolventes, filtros, eco, reverberacion y
escritura de WAV.

POR QUE SINTESIS Y NO SONIDOS BAJADOS:
como con el arte de los escenarios, asi todo el sonido es nuestro (sin
licencias que aclarar) y se puede cambiar tocando un numero y volviendo a
generar. Va en Python puro, sin numpy, para que funcione en cualquier
ordenador del equipo sin instalar nada: por eso los bucles estan escritos con
cuidado (variables locales, sin llamadas dentro), que en Python es lo que
marca la diferencia.

Todo trabaja con listas de floats entre -1 y 1, una muestra por elemento.
"""
import math
import random
import struct

DOS_PI = 2.0 * math.pi

_NOTAS = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def hz(nombre):
    """'A4' -> 440.0. Admite sostenidos y bemoles: 'C#3', 'Bb2'."""
    letra = nombre[0].upper()
    resto = nombre[1:]
    semitono = _NOTAS[letra]
    while resto and resto[0] in "#b":
        semitono += 1 if resto[0] == "#" else -1
        resto = resto[1:]
    octava = int(resto)
    midi = 12 * (octava + 1) + semitono
    return 440.0 * 2.0 ** ((midi - 69) / 12.0)


def vacio(n):
    return [0.0] * n


def sumar(destino, origen, inicio=0, ganancia=1.0, bucle=False):
    """Suma 'origen' en 'destino' desde 'inicio'. Con 'bucle', lo que pasa
    del final vuelve por el principio: asi una nota que suena al acabar la
    musica se oye al empezar la vuelta siguiente, y el bucle no se nota."""
    n = len(destino)
    if bucle:
        for i, v in enumerate(origen):
            destino[(inicio + i) % n] += v * ganancia
    else:
        fin = min(len(origen), n - inicio)
        for i in range(max(0, fin)):
            destino[inicio + i] += origen[i] * ganancia


# --- Osciladores --------------------------------------------------------------

def parciales(freq, segundos, sr, lista, ataque=0.004):
    """Una nota hecha de parciales que se apagan cada uno a su ritmo.

    'lista' es [(razon, amplitud, apagado_por_segundo)]. Con razones enteras
    sale una cuerda pulsada (los agudos se apagan antes); con razones raras,
    una campana o un golpe de metal. Cada parcial se calcula girando un vector
    (un seno sin llamar a sin() en cada muestra), que es mucho mas rapido."""
    n = int(segundos * sr)
    salida = [0.0] * n
    nyquist = sr * 0.45
    for razon, amplitud, apagado in lista:
        f = freq * razon
        if f >= nyquist or amplitud == 0.0:
            continue
        w = DOS_PI * f / sr
        cw, sw = math.cos(w), math.sin(w)
        c, s = 1.0, 0.0
        g = amplitud
        k = math.exp(-apagado / sr)
        for i in range(n):
            salida[i] += s * g
            c, s = c * cw - s * sw, s * cw + c * sw
            g *= k
    _bordes(salida, sr, ataque)
    return salida


def _bordes(x, sr, ataque, cierre=0.006):
    """Rampa de entrada y de salida: sin ellas, empezar o cortar una onda a
    media altura suena a chasquido."""
    n = len(x)
    na = min(n, max(1, int(ataque * sr)))
    for i in range(na):
        x[i] *= i / na
    nc = min(n, max(1, int(cierre * sr)))
    for i in range(nc):
        x[n - 1 - i] *= i / nc


_TAM_TABLA = 2048
_tablas = {}


def tabla(forma, armonicos):
    """Un ciclo de onda con 'armonicos' armonicos como mucho, guardado para
    reutilizarlo. Limitar los armonicos a lo que cabe por debajo de la mitad
    de la frecuencia de muestreo evita el chirrido metalico (aliasing) de una
    sierra calculada a lo bruto."""
    clave = (forma, armonicos)
    if clave in _tablas:
        return _tablas[clave]
    t = [0.0] * _TAM_TABLA
    for k in range(1, armonicos + 1):
        if forma == "sierra":
            a = 1.0 / k
        elif forma == "sierra_suave":
            a = math.exp(-(k - 1) / 5.0) / k
        elif forma == "cuadrada":
            a = 1.0 / k if k % 2 else 0.0
        elif forma == "organo":
            a = {1: 1.0, 2: 0.5, 3: 0.3, 4: 0.18, 6: 0.08}.get(k, 0.0)
        else:
            a = 1.0 if k == 1 else 0.0
        if a == 0.0:
            continue
        for i in range(_TAM_TABLA):
            t[i] += a * math.sin(DOS_PI * k * i / _TAM_TABLA)
    pico = max(abs(v) for v in t) or 1.0
    t = [v / pico for v in t]
    _tablas[clave] = t
    return t


def oscilador(forma, freq, segundos, sr, fase=0.0, vibrato=0.0, ritmo_vibrato=5.0):
    """Lee la tabla de 'forma' a 'freq' durante 'segundos'. 'vibrato' en
    fraccion de la frecuencia (0.004 = un poco)."""
    n = int(segundos * sr)
    armonicos = max(1, min(40, int(sr * 0.45 / freq)))
    t = tabla(forma, armonicos)
    tam = _TAM_TABLA
    mascara = tam - 1
    salida = [0.0] * n
    p = (fase % 1.0) * tam
    inc = freq * tam / sr
    if vibrato == 0.0:
        for i in range(n):
            ip = int(p)
            fr = p - ip
            a = t[ip & mascara]
            salida[i] = a + (t[(ip + 1) & mascara] - a) * fr
            p += inc
            if p >= tam:
                p -= tam
    else:
        wv = DOS_PI * ritmo_vibrato / sr
        for i in range(n):
            ip = int(p)
            fr = p - ip
            a = t[ip & mascara]
            salida[i] = a + (t[(ip + 1) & mascara] - a) * fr
            p += inc * (1.0 + vibrato * math.sin(wv * i))
            if p >= tam:
                p -= tam
    return salida


def barrido(f0, f1, segundos, sr, forma="seno", curva=1.0):
    """Un tono que va de f0 a f1 (exponencial, como suena natural). 'curva'
    > 1 hace que el cambio se concentre al principio."""
    n = int(segundos * sr)
    salida = [0.0] * n
    fase = 0.0
    razon = f1 / f0
    for i in range(n):
        t = (i / n) ** (1.0 / curva) if curva != 1.0 else i / n
        f = f0 * razon ** t
        fase += DOS_PI * f / sr
        if forma == "seno":
            salida[i] = math.sin(fase)
        elif forma == "triangulo":
            ciclo = (fase / DOS_PI) % 1.0
            salida[i] = 4.0 * abs(ciclo - 0.5) - 1.0
        else:  # cuadrada suave: seno saturado
            salida[i] = math.tanh(3.0 * math.sin(fase))
    return salida


def ruido(n, azar):
    u = azar.uniform
    return [u(-1.0, 1.0) for _ in range(n)]


# --- Envolventes ------------------------------------------------------------

def golpe(x, sr, ataque=0.003, apagado=8.0):
    """Entra en 'ataque' segundos y se apaga exponencialmente ('apagado' por
    segundo: 8 = se va en medio segundo)."""
    n = len(x)
    na = max(1, int(ataque * sr))
    k = math.exp(-apagado / sr)
    g = 1.0
    for i in range(n):
        if i < na:
            x[i] *= i / na
        else:
            x[i] *= g
            g *= k
    _bordes(x, sr, 0.0005)
    return x


def adsr(x, sr, ataque, caida, sostenido, soltar):
    """Envolvente clasica. La nota dura len(x); el 'soltar' va dentro, al
    final."""
    n = len(x)
    na = int(ataque * sr)
    nd = int(caida * sr)
    nr = min(n, int(soltar * sr))
    fin_sostenido = n - nr
    for i in range(n):
        if i < na:
            g = i / na
        elif i < na + nd:
            g = 1.0 - (1.0 - sostenido) * (i - na) / max(1, nd)
        else:
            g = sostenido
        if i >= fin_sostenido:
            g *= (n - i) / max(1, nr)
        x[i] *= g
    return x


# --- Filtros ------------------------------------------------------------------

def paso_bajo(x, sr, corte):
    """Filtro de un polo. 'corte' es un numero o una funcion de 0..1 (el
    avance por el sonido) para barrerlo."""
    n = len(x)
    y = 0.0
    salida = [0.0] * n
    if callable(corte):
        for i in range(n):
            if i % 32 == 0:
                a = 1.0 - math.exp(-DOS_PI * corte(i / n) / sr)
            y += a * (x[i] - y)
            salida[i] = y
    else:
        a = 1.0 - math.exp(-DOS_PI * corte / sr)
        for i in range(n):
            y += a * (x[i] - y)
            salida[i] = y
    return salida


def paso_alto(x, sr, corte):
    bajo = paso_bajo(x, sr, corte)
    return [a - b for a, b in zip(x, bajo)]


def banda(x, sr, centro, q=4.0):
    """Paso banda resonante (biquad). 'centro' puede ser una funcion de 0..1
    para barrerlo: es lo que hace que un ruido suene a soplido que sube o
    baja."""
    n = len(x)
    salida = [0.0] * n
    x1 = x2 = y1 = y2 = 0.0
    b0 = b2 = a1 = a2 = 0.0
    for i in range(n):
        if i % 16 == 0:
            f = centro(i / n) if callable(centro) else centro
            w = DOS_PI * min(f, sr * 0.45) / sr
            alfa = math.sin(w) / (2.0 * q)
            a0 = 1.0 + alfa
            b0 = alfa / a0
            b2 = -alfa / a0
            a1 = -2.0 * math.cos(w) / a0
            a2 = (1.0 - alfa) / a0
        v = x[i]
        y = b0 * v + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1 = x1, v
        y2, y1 = y1, y
        salida[i] = y
    return salida


# --- Efectos de espacio -------------------------------------------------------

def eco(x, sr, segundos, realimentacion=0.35, mezcla=0.3, oscurecer=2500.0):
    """Eco que se repite apagandose y cada vez mas oscuro."""
    n = len(x)
    d = max(1, int(segundos * sr))
    linea = [0.0] * d
    salida = [0.0] * n
    a = 1.0 - math.exp(-DOS_PI * oscurecer / sr)
    lp = 0.0
    j = 0
    for i in range(n):
        retrasado = linea[j]
        lp += a * (retrasado - lp)
        linea[j] = x[i] + lp * realimentacion
        salida[i] = x[i] + lp * mezcla
        j += 1
        if j == d:
            j = 0
    return salida


def reverberacion(x, sr, mezcla=0.25, tamano=0.8, amortiguar=0.35):
    """Reverberacion de cuatro peines y dos pasatodo (la idea de Freeverb).
    Da la sala de piedra: sin ella, la musica sintetizada suena seca, metida
    en una caja."""
    n = len(x)
    escala = sr / 44100.0
    peines = [int(t * escala) for t in (1116, 1188, 1277, 1356)]
    pasatodos = [int(t * escala) for t in (556, 441)]
    humedo = [0.0] * n
    for largo in peines:
        linea = [0.0] * largo
        j = 0
        filtro = 0.0
        for i in range(n):
            v = linea[j]
            filtro = v * (1.0 - amortiguar) + filtro * amortiguar
            linea[j] = x[i] + filtro * tamano
            humedo[i] += v
            j += 1
            if j == largo:
                j = 0
    for largo in pasatodos:
        linea = [0.0] * largo
        j = 0
        for i in range(n):
            v = linea[j]
            entrada = humedo[i]
            linea[j] = entrada + v * 0.5
            humedo[i] = v - entrada
            j += 1
            if j == largo:
                j = 0
    return [a + b * mezcla * 0.25 for a, b in zip(x, humedo)]


def en_bucle(efecto, x):
    """Aplica un efecto con cola (eco, reverberacion) a algo que se repite:
    se procesa dos veces seguido y se queda la segunda vuelta, que ya trae la
    cola de la primera. Asi el final empalma con el principio sin corte."""
    doble = efecto(x + x)
    return doble[len(x):]


# --- Mezcla final ---------------------------------------------------------------

def saturar(x, fuerza=1.0):
    """Saturacion suave (tanh): redondea los picos en vez de cortarlos."""
    if fuerza <= 0.0:
        return x
    norma = math.tanh(fuerza)
    return [math.tanh(v * fuerza) / norma for v in x]


def normalizar(x, pico_db=-1.0):
    pico = max((abs(v) for v in x), default=0.0)
    if pico == 0.0:
        return x
    g = 10.0 ** (pico_db / 20.0) / pico
    return [v * g for v in x]


def multiplicar(x, g):
    return [v * g for v in x]


def guardar_wav(ruta, x, sr, bucle=False):
    """WAV de 16 bits, mono. Con 'bucle' lleva un bloque 'smpl' que dice que
    se repite entero: Godot lo lee al importar ("Detect From WAV") y la musica
    se repite sola, sin codigo y sin hueco entre vuelta y vuelta."""
    muestras = bytearray()
    for v in x:
        muestras += struct.pack("<h", int(max(-1.0, min(1.0, v)) * 32767.0))
    fmt = struct.pack("<4sIHHIIHH", b"fmt ", 16, 1, 1, sr, sr * 2, 2, 16)
    datos = struct.pack("<4sI", b"data", len(muestras)) + bytes(muestras)
    extra = b""
    if bucle:
        cuerpo = struct.pack("<9I", 0, 0, int(1e9 / sr), 60, 0, 0, 0, 1, 0)
        cuerpo += struct.pack("<6I", 0, 0, 0, len(x) - 1, 0, 0)
        extra = struct.pack("<4sI", b"smpl", len(cuerpo)) + cuerpo
    riff = b"WAVE" + fmt + datos + extra
    with open(ruta, "wb") as f:
        f.write(struct.pack("<4sI", b"RIFF", len(riff)) + riff)


def medir(x, sr):
    """Pico, volumen medio (RMS) y si hay recortes. Lo que se puede comprobar
    de un sonido sin oirlo."""
    pico = max((abs(v) for v in x), default=0.0)
    rms = math.sqrt(sum(v * v for v in x) / max(1, len(x)))
    db = lambda v: 20.0 * math.log10(v) if v > 0 else -120.0
    return {"segundos": round(len(x) / sr, 2), "pico_db": round(db(pico), 1),
            "rms_db": round(db(rms), 1), "recortes": sum(1 for v in x if abs(v) >= 0.999)}
