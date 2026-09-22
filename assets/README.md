# assets/

Arte del juego. Aquí entra **solo lo que se usa**, ya recortado y reescalado;
los packs originales viven fuera del repositorio (ver `CREDITS.md` en la raíz).

## mago/

El personaje jugable **que se usa ahora**, y el primero que mira a los cuatro
lados. 15 PNG de 108×134 (`abajo_0..3`, `izquierda_0..3`, `derecha_0..3`,
`arriba_0..2`) y `animaciones_mago.tres`, con ocho animaciones: `caminar_` y
`quieto_` por cada dirección.

Salieron de una hoja de 4×4 casillas rotuladas. Esa hoja traía dos defectos,
los dos encontrados midiendo y no mirando:

- **Las dos filas de lado son la misma pose y miran al mismo sitio**: siluetas
  93 % iguales tal cual y solo 62 % en espejo. Y miran a la **derecha**, no a la
  izquierda que dice el rótulo: el centro de la piel de la cara cae 10 px a la
  derecha del centro de la cabeza, mientras que en la fila frontal (que sabemos
  que es de frente) ese desvío es de 4. Así que la fila de lado se usa tal cual
  para la derecha y **reflejada** para la izquierda.
- **El fotograma ARRIBA 3 tiene dos báculos**, uno en cada mano. Se descarta,
  así que andar hacia arriba usa tres poses en vez de cuatro. Para que el paso
  no vaya más rápido, esa animación va a 7,5 fps en vez de 10: el ciclo dura
  los mismos 0,4 s.

Cada fila de la hoja tenía al mago a una altura distinta dentro de su casilla,
así que la línea de suelo se mide **por dirección**; si se midiera para toda la
hoja, el mago pegaría un salto vertical al girarse. La referencia son las filas
con píxeles sólidos (alfa alto y anchura de bota), no la caja del alfa: debajo
de los pies hay restos de sombra suave, distintos en cada fila. Con ese filtro
las cuatro direcciones miden lo mismo de alto (221 px en la hoja), que es la
señal de que la referencia es buena.

El lienzo se centra en los pies y es simétrico, porque la derecha es la
izquierda reflejada y el eje tiene que caer en el mismo sitio.

**Contraste medido contra el suelo: 1,43:1.** Es el personaje más oscuro que ha
tenido el juego (el nigromante daba 1,81:1 y el mago azul original 1,55:1). Se
lee gracias al orbe morado y al ribete claro de la túnica.

## nigromante/

**Fuera de uso** (no tenía más que vista de frente). 6 PNG de 134×150 más su
`SpriteFrames`. Se deja para poder volver atrás cambiando una línea en
`Jugador.tscn`.

## personaje/

El mago anterior (BlueWizard), **ya no se usa**: se deja para poder volver
atrás cambiando una línea en `Jugador.tscn`. 40 PNG de 73×128:

- `quieto_00..19.png` — animación de reposo
- `caminar_00..19.png` — animación de andar
- `animaciones_mago.tres` — el `SpriteFrames` que las agrupa, con sus
  velocidades. Es lo que carga `Jugador.tscn`.

Los frames originales eran de 512×512 con el personaje ocupando solo 160×280
en el centro: un 83% del archivo era transparencia. Recortarlos a la caja común
de las tres animaciones (la misma para todas, o el personaje daría saltos al
cambiar de animación) bajó el conjunto de 4,1 MB a 441 KB.

**Tamaño en pantalla**: el sprite se dibuja a escala 0,5 desde `Jugador.tscn`,
o sea 64 px de alto, y el origen del nodo está a los pies. Si quieres el mago
más grande o más pequeño, cambia esa escala en la escena; la forma de colisión
es independiente y está aparte (círculo de radio 15 sobre la base de la túnica).

Nota sobre `.gitignore`: los `*.import` no se versionan, los regenera Godot al
abrir el proyecto.

## cueva/ y musgo/

Un pack de arte por carpeta, y **un piso apunta a su pack desde su `.tres`**.
Ahora mismo:

| Piso | Catálogo | Qué se ve |
|---|---|---|
| 1 | `musgo/catalogo_musgo.tres` | matorrales, rocas con musgo, lianas con pinchos y plantas |
| 2 | `cueva/catalogo_cueva_vegetal.tres` | rocas de cueva + su vegetación seca |
| 3–12 | `cueva/catalogo_cueva.tres` (por defecto) | solo rocas, sin vegetación |

El musgo va arriba y la cueva debajo, que es el orden que pide el tema: se
empieza en la superficie y se baja a la roca. Los pisos 3 al 12 se quedan con
roca pelada a propósito, hasta que haya arte
propio para ellos. Y sin vegetación: no crecen plantas en el manto.

### Las familias de un catálogo

- `piedra_*` — piezas pequeñas repartidas por el suelo; **también quitan vida**
- `roca_*` — obstáculos principales, familia por defecto
- `bloque_*` — obstáculos angulares, para los pisos del núcleo
- `grupo_*` — obstáculos grandes; en el pack de musgo son las lianas con pinchos
- `vegetacion_*` — plantas; crecen sobre las plataformas y son lo único
  decorativo que queda: no chocan, porque una planta no es una roca
- `plataforma_*` — repisas y losas anchas que se reparten por el suelo

**Por qué un catálogo `.tres` y no leer la carpeta**: el orden de los archivos
en disco no es estable entre sistemas, y los 12 pisos tienen que ser idénticos
en las tres máquinas del equipo. Con la lista fija dentro del `.tres`, la roca
número 3 es la misma para todo el mundo.

### Añadir un pack nuevo (pisos 3 al 12)

1. Recorta las piezas y guárdalas en `assets/<pack>/` con los prefijos de
   arriba.
2. Crea `catalogo_<pack>.tres` con las cinco listas.
3. En el `.tres` del piso, apunta `catalogo_arte` a ese catálogo.

No hace falta tocar ni una línea de GDScript.

### Plataformas

Cada piso reparte entre 3 y 6 plataformas bajas, y la vegetación crece **encima
de ellas** en vez de suelta por el suelo. Sueltas parecían puestas al azar,
porque lo estaban; agrupadas sobre una repisa cuentan algo: ahí hay tierra y por
eso crece algo.

**Las plataformas hacen daño**, igual que las rocas: pasan por el pool de
obstáculos, no son decoración. La vegetación que crece encima sí es decoración
y no choca, para que el borde de la losa sea exactamente lo que quita vida.

Se pintan **a la misma luminosidad que las rocas**: lo que hace daño tiene que
verse igual, sea roca o losa. No basta con darles el mismo tinte, porque la
textura de las repisas es de por sí mucho más clara; llevan un factor 0,6
encima, calculado midiendo una captura (suelo 34, rocas 49, losas sin corregir
71). Está en `tinte_losa`, dentro de `_colocar_plataformas()`.

Los pisos 3 al 12 tienen plataformas de piedra pero sin plantas: sus catálogos
no llevan vegetación.

### El borde del área

Cada piso se rodea de rocas del pack que tenga asignado, para que el límite no
sea una línea dibujada sino la pared de la cueva. Son **decoración pura**: van
por fuera del borde y no chocan con nada, la colisión sigue siendo el muro
invisible. Se dejan huecos en el centro de arriba y de abajo, donde aparece el
jugador y donde está el círculo de salida.

Salen unos 100-135 sprites por piso, sin física. Para hacerlo más o menos denso
está `_colocar_borde()` en `scripts/piso.gd`.

### Tinte

Las rocas y plantas se tintan en tiempo de ejecución según la profundidad. Ese
tinte no es decorativo: decide si el obstáculo se distingue del suelo. Está
explicado y medido en `tinte_profundidad()`, en `scripts/piso.gd`.
