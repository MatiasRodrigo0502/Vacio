# assets/

Arte del juego. Aquí entra **solo lo que se usa**, ya recortado y reescalado;
los packs originales viven fuera del repositorio (ver `CREDITS.md` en la raíz).

## personaje/

El mago jugable (BlueWizard). 40 PNG de 73×128:

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
| 1 | `cueva/catalogo_cueva_vegetal.tres` | rocas de cueva + su vegetación seca |
| 2 | `musgo/catalogo_musgo.tres` | matorrales, rocas con musgo, lianas con pinchos y plantas |
| 3–12 | `cueva/catalogo_cueva.tres` (por defecto) | solo rocas, sin vegetación |

Los pisos 3 al 12 se quedan con roca pelada a propósito, hasta que haya arte
propio para ellos. Y sin vegetación: no crecen plantas en el manto.

### Las familias de un catálogo

- `piedra_*` — piezas pequeñas, decoración del suelo, sin colisión
- `roca_*` — obstáculos principales, familia por defecto
- `bloque_*` — obstáculos angulares, para los pisos del núcleo
- `grupo_*` — obstáculos grandes; en el pack de musgo son las lianas con pinchos
- `vegetacion_*` — plantas, solo decoración, repartidas más grandes que las
  piedras porque si no no se distinguen del suelo

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

### Tinte

Las rocas y plantas se tintan en tiempo de ejecución según la profundidad. Ese
tinte no es decorativo: decide si el obstáculo se distingue del suelo. Está
explicado y medido en `tinte_profundidad()`, en `scripts/piso.gd`.
