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

### Los cuatro magos y sus hechizos — personajes jugables

- **Origen**: los trajo Matías el 2026-11-04 (`vacio_magos_y_hechizos.zip`):
  ilustración vectorial hecha con scripts (SVG por pose), con un LEEME que está
  en `assets/magos_fuente/LEEME_del_paquete.md`. Piromante = mago rojo,
  Envenenador = mago verde, Criomante = mago blanco, Mago del Vacío = mago
  oscuro.
- **Archivos**: los originales en `assets/magos_fuente/` (Godot no los importa);
  lo que usa el juego, en `assets/mago_<color>/` (`atlas_8dir.png`,
  `animaciones_mago_<color>.tres`, `retrato.png` y `hechizos/`).
- **Procesado**: `herramientas/generar_magos.py` (reducir cada hoja a lo que
  mide en el juego y montar sus `SpriteFrames` y `ArteHechizo`).
- **Sustituyen** a las hojas de antes: la del mago oscuro y la del mago rojo,
  de origen sin identificar, y el mago blanco, que era el rojo con otra paleta.

### Skins y armas del gacha

Propias, generadas por script: las skins salen del arte de los cuatro magos cambiando
sus colores (`herramientas/generar_skins.py`), y los iconos de las armas se dibujan a
código (`herramientas/generar_armas.py`).

### Portada — «Los tres Magos de Vacío: El Bosque Ancestral»

- **Archivo**: `assets/portada/portada.jpg` (1416 × 752), el fondo del menú
  principal.
- **Origen**: la trajo Matías el 2026-10-14. **Hay que apuntar aquí de dónde
  sale y con qué licencia** (quién la hizo o con qué herramienta) antes de
  entregar o publicar.

### Mago Caído — el jefe del piso 12

- **De dónde sale**: de la hoja antigua del mago rojo (hoy en
  `assets/mago_caido/origen/`), con otra paleta. Esa hoja la aportó Matías sin
  decir de dónde salía (un GIF de 576×648 y 6 fotogramas en forma de brújula):
  **hay que averiguar su origen y su licencia antes de publicar nada**.

- **Origen**: la hoja del **mago rojo** (ver abajo) con otra paleta (túnica
  negra, ribete de oro, ojos amarillos) y, en vez del báculo con el orbe, una
  guadaña dibujada por código en cada pose. Mismas poses y misma animación,
  dibujado a ×2.
- **Archivos**: `assets/mago_caido/atlas_8dir.png` y
  `animaciones_mago_caido.tres`
- **Procesado**: `herramientas/generar_mago_caido.py`: color a color, y la
  guadaña con `ImageDraw` (la hoja es nuestra).
- **Licencia**: la misma duda que el mago rojo, del que sale.

### Personajes de antes — borrados del proyecto

El mago de 4 direcciones, el nigromante y el BlueWizard (de *Mossy Cavern*, de
maaot) se borraron el 2026-10-09: ya no los usaba nada. Los dos primeros eran
los únicos assets sin autor ni origen; al no estar en el proyecto, ya no
hace falta aclararlos. Siguen en el historial de git.

### Musgo — arte del piso 1 (ya sin usar)

- **Pack**: Mossy Cavern
- **Autor**: maaot
- **URL**: https://maaot.itch.io/mossy-cavern
- **Licencia**: sin verificar
- **Archivos**: `assets/musgo/*.png` (41 texturas) + `catalogo_musgo.tres`
- **Procesado**: los atlas `Decorations&Hazards`, `FloatingPlatforms` y
  `MossyHills` se partieron en piezas sueltas y se eligieron matorrales, rocas
  con musgo y lianas con pinchos (que en el pack original ya son peligros, así
  que aquí también hacen daño). Las plantas animadas aportan un frame cada una.

### Cueva — arte de los pisos 2 y 3 (ya sin usar)

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

### Manto — arte de los pisos 4 a 8 (ya sin usar)

- **Autor**: Matías (pack propio, sale de su generador procedural)
- **Licencia**: propio, sin problema de licencia
- **Archivos**: `assets/manto/` (42 piezas y dos catálogos: con cristales de
  olivino para los pisos 4-6 y pelado para los 7-8)

### Sonido y música

- **Autor**: hecho para el proyecto, por síntesis, con
  `herramientas/generar_efectos.py` y `herramientas/generar_musica.py`
  (comparten `herramientas/sintesis.py`)
- **Licencia**: propio, sin problema de licencia
- **Archivos**: `assets/sonido/efectos/` (23 efectos) y
  `assets/sonido/musica/` (portada, superficie, profundo, victoria y derrota)
- **Nota**: no hay ni una muestra grabada ni bajada: todo son osciladores,
  ruido y filtros calculados en Python.

### Título del menú — VACÍO en piedra con lava

- **Autor**: hecho para el proyecto, con `herramientas/generar_titulo.py`
- **Licencia**: propio, sin problema de licencia
- **Archivos**: `assets/titulo/` (`titulo.png` y `titulo_brillo.png`)
- **Nota**: dibujado en pixel art y no con una fuente, para que vaya con los
  magos; así tampoco hay ninguna fuente que bajar ni licenciar.

### Rocas de dentro de las salas — una por piso

- **Autor**: hecho para el proyecto, con `herramientas/generar_rocas.py`
- **Licencia**: propio, sin problema de licencia
- **Archivos**: `assets/rocas/` (`piso_01/` a `piso_12/`)
- **Nota**: desde el 2026-10-08 sustituyen en el juego a los packs de musgo,
  cueva, manto y núcleo, que siguen en `assets/` sin usar.

### Pared de las salas — una por piso, con sus pilares, piezas y la reja

- **Autor**: hecho para el proyecto, con `herramientas/generar_bordes.py`
- **Licencia**: propio, sin problema de licencia
- **Archivos**: `assets/bordes/` (`piso_01/` a `piso_12/` y `reja.png`)

### Peligros — lava, pinchos y vacío

- **Autor**: hecho para el proyecto, con `herramientas/generar_peligros.py`
- **Licencia**: propio, sin problema de licencia
- **Archivos**: `assets/peligros/` y `shaders/lava.gdshader`

### Núcleo — arte de los pisos 9 a 12 (ya sin usar)

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
