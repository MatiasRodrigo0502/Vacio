# -*- coding: utf-8 -*-
"""Instala la plantilla de exportacion de Windows de Godot, sin el resto.

Para sacar el .exe del juego, Godot necesita sus "plantillas de exportacion".
El gestor del editor baja un .tpz oficial de 1,28 GB con todas las
plataformas, pero aqui solo hace falta una: windows_release_x86_64.exe
(unos 38 MB). El .tpz es un zip, y GitHub deja pedir trozos sueltos de un
archivo (cabecera Range). Asi que se lee el indice del zip, que esta al
final, y se bajan solo los bytes de lo que hace falta.

Cada archivo se comprueba con el CRC32 que trae el propio indice: si la
descarga llega mal, no se instala.

    python herramientas/instalar_plantilla_windows.py

Solo hace falta una vez por ordenador y por version de Godot. Si se cambia
de version, se cambia VERSION abajo.
"""
import os
import struct
import sys
import urllib.request
import zlib

VERSION = "4.7.2"
URL = ("https://github.com/godotengine/godot/releases/download/"
       "%s-stable/Godot_v%s-stable_export_templates.tpz" % (VERSION, VERSION))
# Lo que se instala. version.txt lo usa el gestor del editor para saber que
# version hay; la exportacion en si solo necesita el .exe.
QUEREMOS = ["templates/version.txt", "templates/windows_release_x86_64.exe"]

def carpeta_godot():
    """Donde guarda Godot sus datos en cada sistema. Ademas de Windows, Linux:
    GitHub exporta el .exe para la release en una maquina Linux
    (.github/workflows/publicar.yml) con este mismo script."""
    if sys.platform == "win32":
        return os.path.join(os.environ["APPDATA"], "Godot")
    if sys.platform == "darwin":
        return os.path.expanduser("~/Library/Application Support/Godot")
    datos = os.environ.get("XDG_DATA_HOME") or os.path.expanduser("~/.local/share")
    return os.path.join(datos, "godot")


DESTINO = os.path.join(carpeta_godot(), "export_templates", VERSION + ".stable")
TROZO = 1 << 20


def pedir(desde, hasta):
    """Abre la descarga de los bytes de `desde` a `hasta`, los dos incluidos."""
    peticion = urllib.request.Request(URL, headers={"Range": "bytes=%d-%d" % (desde, hasta)})
    respuesta = urllib.request.urlopen(peticion)
    # 206 = el servidor ha hecho caso del rango. Con 200 mandaria el archivo
    # entero, y leerlo como si fuera el trozo pedido daria basura.
    if respuesta.status != 206:
        sys.exit("El servidor no acepta descargas por trozos (HTTP %d)." % respuesta.status)
    return respuesta


def leer_indice():
    """Devuelve {nombre: (metodo, crc, tam_comprimido, tam_real, desplazamiento)}
    leyendo el directorio central del zip."""
    # El servidor de GitHub no acepta "los ultimos N bytes" (responde 501):
    # hay que preguntar primero cuanto mide y pedir el rango exacto.
    total = int(urllib.request.urlopen(urllib.request.Request(URL, method="HEAD"))
                .headers["Content-Length"])
    cola = pedir(total - 65536, total - 1).read()
    # El registro final del zip lleva esta firma; puede haber un comentario
    # detras, por eso se busca desde el final.
    pos = cola.rfind(b"PK\x05\x06")
    if pos < 0:
        sys.exit("No encuentro el indice del .tpz.")
    tam_indice, ini_indice = struct.unpack("<II", cola[pos + 12:pos + 20])
    indice = pedir(ini_indice, ini_indice + tam_indice - 1).read()
    entradas = {}
    i = 0
    while i < len(indice):
        campos = struct.unpack("<IHHHHHHIIIHHHHHII", indice[i:i + 46])
        metodo, crc, comp, real = campos[4], campos[7], campos[8], campos[9]
        largo_nombre, largo_extra, largo_coment, desplazamiento = (
            campos[10], campos[11], campos[12], campos[16])
        nombre = indice[i + 46:i + 46 + largo_nombre].decode("utf-8")
        entradas[nombre] = (metodo, crc, comp, real, desplazamiento)
        i += 46 + largo_nombre + largo_extra + largo_coment
    return entradas


def bajar(nombre, entrada):
    """Baja y descomprime una entrada a DESTINO, comprobando su CRC32."""
    metodo, crc, comp, real, desplazamiento = entrada
    # La cabecera local puede llevar un campo extra distinto del del indice:
    # hay que leerla para saber donde empiezan los datos de verdad.
    cabecera = pedir(desplazamiento, desplazamiento + 29).read()
    largo_nombre, largo_extra = struct.unpack("<HH", cabecera[26:30])
    inicio = desplazamiento + 30 + largo_nombre + largo_extra

    final = os.path.join(DESTINO, os.path.basename(nombre))
    temporal = final + ".descargando"
    descomprimir = zlib.decompressobj(-15) if metodo == 8 else None
    crc_leido = 0
    leidos = 0
    respuesta = pedir(inicio, inicio + comp - 1) if comp > 0 else None
    with open(temporal, "wb") as salida:
        while respuesta is not None:
            datos = respuesta.read(TROZO)
            if not datos:
                break
            leidos += len(datos)
            if descomprimir is not None:
                datos = descomprimir.decompress(datos)
            crc_leido = zlib.crc32(datos, crc_leido)
            salida.write(datos)
            print("\r  %s: %.1f / %.1f MB" % (os.path.basename(nombre), leidos / 1e6, comp / 1e6),
                  end="", flush=True)
        if descomprimir is not None:
            resto = descomprimir.flush()
            crc_leido = zlib.crc32(resto, crc_leido)
            salida.write(resto)
    print()
    if crc_leido != crc or os.path.getsize(temporal) != real:
        os.remove(temporal)
        sys.exit("%s ha llegado mal (no cuadra el CRC). Vuelve a intentarlo." % nombre)
    # Se escribe aparte y se mueve al final: si la descarga se corta, no
    # queda una plantilla a medias que Godot intentaria usar.
    os.replace(temporal, final)


def main():
    os.makedirs(DESTINO, exist_ok=True)
    print("Leyendo el indice de", URL)
    entradas = leer_indice()
    for nombre in QUEREMOS:
        if nombre not in entradas:
            sys.exit("El .tpz no trae %s." % nombre)
        bajar(nombre, entradas[nombre])
    print("Plantilla instalada en", DESTINO)


if __name__ == "__main__":
    main()
