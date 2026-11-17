# -*- coding: utf-8 -*-
"""Parches para actualizar el juego bajando solo lo que cambia (Matias, 2026-11-17:
«en Linux, actualizar el juego crea otro archivo, pero a mí me interesa que la
actualización se integre en el archivo que ya hay, realizando sólo los cambios
necesarios en vez de instalar el juego de nuevo»).

COMO ES UN EJECUTABLE DE GODOT: el motor (73 MB, igual en todas las versiones
mientras no cambie Godot) y detras el paquete del juego (.pck), con cada archivo
del proyecto seguido de otro, su directorio al final (nombre, donde esta, cuanto
mide y su md5) y un cierre (tamano del paquete y "GDPC"). Entre una version y la
siguiente cambian unos pocos archivos, pero los que van detras se mueven de sitio.

EL PARCHE dice como montar el nuevo con trozos del viejo: «copia de aqui tanto» o
«pon estos bytes». El motor y los archivos del paquete que no han cambiado (mismo
md5 y tamano) se copian del viejo, aunque esten en otro sitio; lo demas va dentro
del parche, comprimido con gzip. Lo aplica el juego (scripts/parche.gd) y lo
comprueba con el sha256 del resultado, que va en el parche.

FORMATO (little endian):
    "VPAR", u32 version (1)
    u64 tamano del viejo, 32 bytes sha256 del viejo
    u64 tamano del nuevo, 32 bytes sha256 del nuevo
    u32 cuantas operaciones, y cada una:
        u8 0 (copiar): u64 desde (en el viejo), u64 cuanto
        u8 1 (poner):  u64 cuanto sin comprimir, u64 cuanto comprimido, los bytes (gzip)

    python herramientas/parche_juego.py crear VIEJO NUEVO PARCHE
    python herramientas/parche_juego.py aplicar VIEJO PARCHE RESULTADO

'crear' lo comprueba aplicandolo antes de dar el parche por bueno: si no sale
identico al nuevo, falla y no se publica (el juego se bajara entero).
"""
import gzip
import hashlib
import struct
import sys

MAGIA = b"VPAR"
VERSION = 1
COPIAR, PONER = 0, 1
# Lo que va como mucho en una operacion de poner: el juego la descomprime de una
# vez, y asi no necesita mas memoria que esto.
TROZO_PONER = 8 << 20
# Los bloques en que se compara el motor del viejo con el del nuevo.
BLOQUE_MOTOR = 64 << 10


def paquete(datos):
    """(donde empieza el .pck, base de los archivos, {(md5, tamano): donde}, [(donde, tamano, md5)])."""
    if datos[-4:] != b"GDPC":
        raise ValueError("no lleva un paquete de Godot al final")
    tamano = struct.unpack("<Q", datos[-12:-4])[0]
    inicio = len(datos) - 12 - tamano
    if datos[inicio:inicio + 4] != b"GDPC":
        raise ValueError("el paquete no empieza donde dice")
    version, = struct.unpack("<I", datos[inicio + 4:inicio + 8])
    if version < 3:
        raise ValueError("formato de paquete %d: se esperaba el 3 o mas nuevo" % version)
    flags, = struct.unpack("<I", datos[inicio + 20:inicio + 24])
    base, directorio = struct.unpack("<QQ", datos[inicio + 24:inicio + 40])
    # Con PACK_REL_FILEBASE (2) la base cuenta desde el paquete; si no, desde el archivo.
    base_abs = inicio + base if flags & 2 else base
    p = inicio + directorio
    cuantos, = struct.unpack("<I", datos[p:p + 4])
    p += 4
    por_contenido = {}
    archivos = []
    for _ in range(cuantos):
        largo, = struct.unpack("<I", datos[p:p + 4])
        p += 4 + largo
        donde, cuanto = struct.unpack("<QQ", datos[p:p + 16])
        md5 = datos[p + 16:p + 32]
        p += 36
        absoluto = base_abs + donde
        if absoluto + cuanto > len(datos) or hashlib.md5(datos[absoluto:absoluto + cuanto]).digest() != md5:
            raise ValueError("un archivo del paquete no casa con su md5")
        por_contenido.setdefault((md5, cuanto), absoluto)
        archivos.append((absoluto, cuanto, md5))
    archivos.sort()
    return inicio, por_contenido, archivos


def operaciones(viejo, nuevo):
    """La lista de [COPIAR, desde, cuanto] y [PONER, desde_en_nuevo, cuanto] que monta 'nuevo'."""
    inicio_viejo, en_viejo, _ = paquete(viejo)
    inicio_nuevo, _, archivos = paquete(nuevo)
    ops = []

    def copiar(desde, cuanto):
        # Seguida de la anterior en los dos: una sola.
        if ops and ops[-1][0] == COPIAR and ops[-1][1] + ops[-1][2] == desde:
            ops[-1][2] += cuanto
        else:
            ops.append([COPIAR, desde, cuanto])

    def poner(desde, cuanto):
        if cuanto <= 0:
            return
        # Lo que va entre dos archivos (relleno, cabeceras): si sigue igual que en el
        # viejo justo detras de lo ultimo copiado, se copia tambien.
        if ops and ops[-1][0] == COPIAR:
            fin = ops[-1][1] + ops[-1][2]
            if viejo[fin:fin + cuanto] == nuevo[desde:desde + cuanto]:
                ops[-1][2] += cuanto
                return
        if ops and ops[-1][0] == PONER and ops[-1][1] + ops[-1][2] == desde:
            ops[-1][2] += cuanto
        else:
            ops.append([PONER, desde, cuanto])

    # El motor, por bloques: Godot apunta en el el tamano del paquete (en Linux, en
    # la cabecera de su seccion), asi que no sale identico aunque no cambie Godot.
    # Solo va en el parche el bloque donde esta eso.
    if inicio_viejo == inicio_nuevo:
        for desde in range(0, inicio_nuevo, BLOQUE_MOTOR):
            hasta = min(desde + BLOQUE_MOTOR, inicio_nuevo)
            if viejo[desde:hasta] == nuevo[desde:hasta]:
                copiar(desde, hasta - desde)
            else:
                poner(desde, hasta - desde)
    else:
        poner(0, inicio_nuevo)
    cursor = inicio_nuevo
    for absoluto, cuanto, md5 in archivos:
        poner(cursor, absoluto - cursor)
        en = en_viejo.get((md5, cuanto))
        if en is not None:
            copiar(en, cuanto)
        else:
            poner(absoluto, cuanto)
        cursor = absoluto + cuanto
    poner(cursor, len(nuevo) - cursor)
    return ops


def crear(viejo, nuevo):
    partes = [MAGIA, struct.pack("<I", VERSION),
              struct.pack("<Q", len(viejo)), hashlib.sha256(viejo).digest(),
              struct.pack("<Q", len(nuevo)), hashlib.sha256(nuevo).digest()]
    cuerpo = []
    for op in operaciones(viejo, nuevo):
        if op[0] == COPIAR:
            cuerpo.append(struct.pack("<BQQ", COPIAR, op[1], op[2]))
            continue
        for desde in range(op[1], op[1] + op[2], TROZO_PONER):
            crudo = nuevo[desde:min(desde + TROZO_PONER, op[1] + op[2])]
            comprimido = gzip.compress(crudo, 6)
            cuerpo.append(struct.pack("<BQQ", PONER, len(crudo), len(comprimido)) + comprimido)
    partes.append(struct.pack("<I", len(cuerpo)))
    return b"".join(partes + cuerpo)


def aplicar(viejo, parche):
    if parche[:4] != MAGIA or struct.unpack("<I", parche[4:8])[0] != VERSION:
        raise ValueError("no es un parche de este formato")
    p = 8
    largo_viejo, = struct.unpack("<Q", parche[p:p + 8])
    huella_viejo = parche[p + 8:p + 40]
    largo_nuevo, = struct.unpack("<Q", parche[p + 40:p + 48])
    huella_nueva = parche[p + 48:p + 80]
    p += 80
    if len(viejo) != largo_viejo or hashlib.sha256(viejo).digest() != huella_viejo:
        raise ValueError("el parche es para otra version")
    cuantas, = struct.unpack("<I", parche[p:p + 4])
    p += 4
    salida = bytearray()
    for _ in range(cuantas):
        tipo, a, b = struct.unpack("<BQQ", parche[p:p + 17])
        p += 17
        if tipo == COPIAR:
            salida += viejo[a:a + b]
        else:
            crudo = gzip.decompress(parche[p:p + b])
            if len(crudo) != a:
                raise ValueError("un trozo no mide lo que dice")
            salida += crudo
            p += b
    if len(salida) != largo_nuevo or hashlib.sha256(salida).digest() != huella_nueva:
        raise ValueError("no sale igual que el nuevo")
    return bytes(salida)


def main():
    if len(sys.argv) != 5 or sys.argv[1] not in ("crear", "aplicar"):
        sys.exit(__doc__)
    a = open(sys.argv[2], "rb").read()
    b = open(sys.argv[3], "rb").read()
    if sys.argv[1] == "crear":
        parche = crear(a, b)
        # Que funcione antes de darlo por bueno.
        if aplicar(a, parche) != b:
            sys.exit("el parche no reconstruye el nuevo")
        open(sys.argv[4], "wb").write(parche)
        print("parche: %d KB (el nuevo entero, %d KB)" % (len(parche) // 1024, len(b) // 1024))
    else:
        open(sys.argv[4], "wb").write(aplicar(a, b))
        print("aplicado: %s" % sys.argv[4])


if __name__ == "__main__":
    main()
