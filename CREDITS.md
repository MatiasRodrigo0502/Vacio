# Créditos de assets

Todo el arte del juego viene de packs de terceros publicados en itch.io.

> **Falta un dato**: la licencia exacta de cada pack. No he podido abrir las
> páginas de itch.io desde aquí para leer sus términos, así que en vez de
> suponerlos los dejo marcados como *sin verificar*. Antes de entregar o
> publicar el juego, entra en cada enlace y copia aquí lo que diga su sección
> de licencia o el `README`/`LICENSE` del propio pack. Lo que hay que mirar es
> si permite uso comercial y si exige atribución; casi todos los packs
> gratuitos la exigen, y esta página es precisamente la atribución.

## En uso

### Mago rojo — personaje jugable

- **Pack**: sin identificar (brújula animada de 8 direcciones)
- **Autor**: sin identificar
- **URL**: —
- **Licencia**: **SIN VERIFICAR — hay que aclararla antes de publicar nada**
- **Archivos**: `assets/mago_rojo/atlas_8dir.png`, `animaciones_mago_rojo.tres`
  y `retrato.png`
- **Procesado**: extraído de un GIF de 576×648 y 6 fotogramas colocado como
  brújula, dividiendo por 3 (el GIF es un 3× de píxel entero, así que no se
  pierde nada), quitando el fondo y centrando cada dirección sobre sus botas.
- **Nota**: lo aportó Matías, sin decir de dónde salía. **Hay que averiguar de
  dónde viene.**

### Mago oscuro — personaje jugable

- **Pack**: «Mago oscuro — sprites de caminata en 8 direcciones»
- **Autor**: sin identificar
- **URL**: —
- **Licencia**: **SIN VERIFICAR — hay que aclararla antes de publicar nada**
- **Archivos**: `assets/mago_oscuro/atlas_8dir.png` (8×6 fotogramas de 64×72),
  `animaciones_mago_oscuro.tres` y `retrato.png`
- **Procesado**: se parte del `atlas_8dir_64px.png` del pack. Solo se ha
  centrado cada dirección sobre el eje de sus botas, desplazando un número
  entero de píxeles; no se ha reescalado ni recoloreado nada.
- **Nota**: lo aportó Matías, sin decir de dónde salía. **Hay que averiguar de
  dónde viene.**

### Mago de 4 direcciones — personaje jugable anterior (fuera de uso)

- **Pack**: sin identificar
- **Autor**: sin identificar
- **URL**: —
- **Licencia**: **SIN VERIFICAR — hay que aclararla antes de publicar nada**
- **Archivos**: `assets/mago/*.png` (15 frames) + `animaciones_mago.tres`
- **Estado**: sustituido por el mago oscuro de 8 direcciones.
- **Procesado**: recortado de una hoja de 4×4 casillas rotuladas (1254×1254),
  quitando rótulos y rejilla y reescalado a 108×134. Las dos filas de lado de
  la hoja son la misma pose mirando a la derecha, así que la izquierda se
  genera reflejándola; y el fotograma «arriba 3» se descarta porque trae dos
  báculos.
- **Nota**: la imagen la aportó Matías en el chat, sin decir de dónde salía.
  **Hay que averiguar de dónde viene.**

### Nigromante — personaje jugable anterior (fuera de uso)

- **Pack**: sin identificar
- **Autor**: sin identificar
- **URL**: —
- **Licencia**: **SIN VERIFICAR — hay que aclararla antes de publicar nada**
- **Archivos**: `assets/nigromante/*.png` (6 frames) + `animaciones_nigromante.tres`
- **Estado**: sustituido por el mago de 4 direcciones. Se conserva en el
  repositorio para poder volver atrás.
- **Procesado**: recortado de una hoja de 2172×724 con seis viñetas enmarcadas,
  quitando el fondo gris y los marcos, y reescalado a 134×150.
- **Nota**: la imagen la aportó Matías en el chat, sin decir de dónde salía. Es
  el único asset del proyecto del que no consta ni autor ni origen, así que es
  el que más riesgo tiene: **hay que averiguar de dónde viene**.

### BlueWizard — personaje jugable anterior (fuera de uso)

- **Pack**: Mossy Cavern
- **Autor**: maaot
- **URL**: https://maaot.itch.io/mossy-cavern
- **Licencia**: sin verificar
- **Archivos**: `assets/personaje/*.png` (40 frames) + `animaciones_mago.tres`
- **Estado**: sustituido por el nigromante. Se conserva en el repositorio
  para poder volver atrás.
- **Procesado**: recortados de 512×512 a la caja útil del personaje (160×280) y
  reescalados a 73×128. Los originales no están en el repo (ver más abajo).

### Musgo — arte del piso 1

- **Pack**: Mossy Cavern
- **Autor**: maaot
- **URL**: https://maaot.itch.io/mossy-cavern
- **Licencia**: sin verificar
- **Archivos**: `assets/musgo/*.png` (41 texturas) + `catalogo_musgo.tres`
- **Procesado**: los atlas `Decorations&Hazards`, `FloatingPlatforms` y
  `MossyHills` se partieron en piezas sueltas y se eligieron matorrales, rocas
  con musgo y lianas con pinchos (que en el pack original ya son peligros, así
  que aquí también hacen daño). Las plantas animadas aportan un frame cada una.

### Cueva — arte de los pisos 2 y 3

- **Pack**: 2D Brown Cave Assets
- **Autor**: maaot
- **URL**: https://maaot.itch.io/2d-browncave-assets
- **Licencia**: sin verificar
- **Archivos**: `assets/cueva/*.png` (53 texturas) + `catalogo_cueva.tres` y
  `catalogo_cueva_vegetal.tres`
- **Procesado**: los cuatro atlas de cueva se partieron automáticamente en 100
  piezas sueltas (detectando islas de píxeles opacos) y se eligieron a mano las
  que funcionan en vista cenital: cantos rodados, bloques, grupos de rocas y
  repisas planas para plataformas. Se descartaron estalagmitas, estalactitas y
  esquirlas, porque delatan la vista lateral. Más su vegetación seca.

### Manto — arte de los pisos 4 a 8

- **Autor**: Matías (pack propio, sale de su generador procedural)
- **Licencia**: propio, sin problema de licencia
- **Archivos**: `assets/manto/` (42 piezas y dos catálogos: con cristales de
  olivino para los pisos 4-6 y pelado para los 7-8)

### Núcleo — arte de los pisos 9 a 12

- **Autor**: hecho para el proyecto, con `herramientas/generar_nucleo.py`
- **Licencia**: propio, sin problema de licencia
- **Archivos**: `assets/nucleo/` (42 piezas y dos catálogos: pelado para el
  núcleo externo, pisos 9-10, y con cristales de hierro para el interno,
  pisos 11-12)
- **Nota**: sigue el estilo del pack del manto. Volver a ejecutar el script da
  exactamente los mismos PNG.

### Enemigos nuevos — rata, serpiente, murciélago, gólem, slime de magma, cristal vivo y fantasma

- **Autor**: Matías (propio)
- **Licencia**: propio, sin problema de licencia
- **Archivos**: `assets/enemigos/<nombre>_00..09.png` y
  `animaciones_<nombre>.tres`

## Descargado y descartado

### Tiny RPG Character Asset Pack (Soldier & Orc)

- **Autor**: Zerie
- **URL**: https://zerie.itch.io/tiny-rpg-character-asset-pack
- **Licencia**: sin verificar
- **Por qué no se usa**: es pixel art y los otros dos packs son arte
  renderizado. Mezclarlos canta mucho. Se valoró como personaje jugable (es el
  único con animación de golpe y de muerte) y se descartó por eso.

**No hay ningún archivo suyo en el repositorio**, así que hoy por hoy no
requiere atribución. Si algún día se usa, hay que moverlo a la lista de arriba.

## Pendiente de usar

| Pack | Contenido sin usar | Uso previsto |
|---|---|---|
| Mossy Cavern | Slimes | obstáculos móviles de la Fase 2 |
| 2D Brown Cave Assets | secuencias completas de animación | animar la vegetación |

## Dónde están los originales

Fuera del repositorio, en `C:\Users\Matias\Gamedev\_assets_origen\`.

**Por qué no se versionan**: son 97 MB y unos 1.250 archivos, con PNGs sueltos
de hasta 5 MB y animaciones de 90 frames como imágenes individuales. Git guarda
todas las versiones de todo lo que entra, así que meterlos enteros infla el
repositorio para siempre aunque luego se borren. En `assets/` entra solo lo que
el juego usa de verdad, ya recortado y reescalado.

Si alguien del equipo clona el repo y necesita los originales, que se los baje
de los enlaces de arriba y los extraiga en su propia carpeta `_assets_origen/`.
