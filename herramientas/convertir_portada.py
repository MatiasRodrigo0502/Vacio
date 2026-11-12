# -*- coding: utf-8 -*-
"""Prepara el video de la portada del menu (Matias, 2026-11-12: «cambia el menu
principal por este mp4»).

Godot no reproduce MP4: solo Ogg Theora (.ogv). De un video cualquiera saca, en
assets/portada/:

- portada.ogv: el video sin sonido, a 1024 x 576 (16:9; recorta lo que sobre, sin
  deformar). Multiplos de 16, que es como trabaja Theora. Calidad 9 de 10: es lo
  primero que se ve del juego, y a 7 las sombras moradas hacian bandas.
- portada_quieta.jpg: su primera imagen, que va debajo del video en el menu: es lo
  que se ve hasta que sale la primera imagen, y si el video no cargara.

Necesita ffmpeg: en el PATH, o el del paquete imageio-ffmpeg (pip install
imageio-ffmpeg), que lo trae dentro.

    python herramientas/convertir_portada.py ruta/al/video.mp4
"""
import os
import shutil
import subprocess
import sys

DESTINO = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "portada")
ANCHO, ALTO = 1024, 576
CALIDAD = 9
ENCAJE = "scale=%d:%d:force_original_aspect_ratio=increase:flags=lanczos,crop=%d:%d" % (ANCHO, ALTO, ANCHO, ALTO)


def ffmpeg():
    en_path = shutil.which("ffmpeg")
    if en_path:
        return en_path
    try:
        import imageio_ffmpeg
    except ImportError:
        sys.exit("Hace falta ffmpeg en el PATH, o pip install imageio-ffmpeg")
    return imageio_ffmpeg.get_ffmpeg_exe()


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    origen = sys.argv[1]
    programa = ffmpeg()
    video = os.path.join(DESTINO, "portada.ogv")
    quieta = os.path.join(DESTINO, "portada_quieta.jpg")
    # Una imagen clave por segundo: el bucle vuelve a la primera sin tiron.
    subprocess.run([programa, "-hide_banner", "-loglevel", "error", "-y", "-i", origen, "-vf", ENCAJE,
                    "-c:v", "libtheora", "-q:v", str(CALIDAD), "-g", "30", "-an", video], check=True)
    # Del .ogv y no del original: asi la quieta y el video casan pixel a pixel.
    subprocess.run([programa, "-hide_banner", "-loglevel", "error", "-y", "-i", video, "-frames:v", "1",
                    "-q:v", "2", quieta], check=True)
    for ruta in (video, quieta):
        print("%s: %d KB" % (os.path.basename(ruta), os.path.getsize(ruta) // 1024))


if __name__ == "__main__":
    main()
