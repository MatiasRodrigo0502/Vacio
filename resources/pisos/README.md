# resources/pisos/

Los 12 pisos del juego, uno por archivo `.tres`. Cada archivo es una instancia
de `DatosPiso` (`scripts/datos_piso.gd`).

**Un piso = un archivo.** Es la unidad de trabajo del equipo: si cada persona
ajusta un piso distinto, git no tiene nada que fusionar y no hay conflictos.

`GestorProgreso` carga la carpeta entera **ordenada por nombre de archivo**, así
que el prefijo `piso_NN_` es el que define la profundidad. No hay ninguna lista
de pisos en el código.

## Campos

| Campo | Qué hace |
|---|---|
| `nombre_capa` | Texto que aparece en el HUD. |
| `ancho_area` | Ancho del suelo de **cada sala**, en píxeles. Es el embudo: baja piso a piso. |
| `alto_area` | Alto del suelo de cada sala. |
| `cantidad_salas` | Cuántas salas tiene el piso, contando el inicio, la del objeto y la de salida. |
| `velocidad_obstaculos` | Velocidad base de los obstáculos (px/s). En Fase 1 las rocas son estáticas, pero el valor ya llega hasta ellas. |
| `radio_vision` | Media altura visible de la cámara, en píxeles. Menor = zoom más cerrado = se ve menos y todo más grande. **495 en todos los pisos** desde el 2026-10-22 (ver las notas de abajo). |
| `cantidad_obstaculos` | Cuántas rocas lleva **cada sala de pelea** (el inicio y la del objeto van limpias). |
| `es_nivel_final` | Solo `true` en el piso 12. Al superarlo se gana la partida. |
| `familia_obstaculos` | Qué rocas usa el piso: `roca`, `bloque`, `grupo` o `piedra`. |
| `catalogo_arte` | Pack de arte del piso (rocas, piedras, plataformas y vegetación). Vacío = el de la cueva sin vegetación. |
| `mostrar_tutorial` | El piso es un tutorial: sus salas van en fila y al entrar en cada una sale una ventana que explica algo (`scripts/tutorial.gd`). Solo el piso 1. |
| `enemigos_tutorial` | Con el tutorial, los enemigos de su primera pelea (en el piso 1, un slime verde y dos ratas). |
| `sala_pelea_tutorial` | En qué sala, contando desde el inicio, va esa pelea (la 3). |
| `sala_jefe` | El piso acaba en la sala del jefe: antesala con altar y vendaje (`objeto_antesala`), y detrás la sala del jefe, con la bajada. No cuenta en `cantidad_salas` (son dos salas más). Solo el piso 12. |
| `tamano_sala_jefe` | Lo que mide el suelo de la sala del jefe (1200 × 700 en el 12). La cámara la enseña entera. |

## Valores de partida (sin jugar todavía, pendientes de ajuste)

| # | Capa | sala (ancho × alto) | salas | rocas/sala | vel. | visión |
|---|---|---|---|---|---|---|
| 01 | Corteza continental | 1400 × 820 | 5 | 2 | 80 | 495 |
| 02 | Corteza oceánica | 1340 × 800 | 5 | 3 | 95 | 495 |
| 03 | Litosfera superior | 1280 × 780 | 6 | 3 | 110 | 495 |
| 04 | Astenosfera | 1220 × 760 | 6 | 3 | 130 | 495 |
| 05 | Manto superior | 1160 × 740 | 7 | 4 | 150 | 495 |
| 06 | Zona de transición | 1100 × 720 | 7 | 4 | 175 | 495 |
| 07 | Manto inferior | 1040 × 700 | 8 | 4 | 200 | 495 |
| 08 | Capa D'' | 980 × 680 | 8 | 5 | 230 | 495 |
| 09 | Núcleo externo exterior | 920 × 660 | 9 | 5 | 265 | 495 |
| 10 | Núcleo externo interior | 860 × 640 | 9 | 5 | 300 | 495 |
| 11 | Límite del núcleo interno | 800 × 620 | 10 | 6 | 340 | 495 |
| 12 | Núcleo interno | 740 × 600 | 10 | 6 | 390 | 495 |

Notas de diseño de la curva:

- El piso 1 es el tutorial (desde el 2026-10-29; antes, cuatro salas sin
  enemigos con todos los carteles en la de inicio): cinco salas en fila, una
  ventana que explica una cosa al entrar en cada una, y en la tercera la
  primera pelea, un slime verde y dos ratas (`enemigos_tutorial`). La mecánica de enemigos sigue empezando en el
  2: esos tres son los únicos del piso.
- **Todos los pisos ven lo mismo que el 2** (`radio_vision` 495, desde el
  2026-10-22, pedido por Matías: en los últimos pisos los enemigos, las rocas
  y todo lo demás se veían el doble de grandes, y tienen que verse siempre
  igual). Antes bajaba de 520 en el 1 a 240 en el 12, y la cámara se iba
  acercando: del 9 en adelante no cabía ni el suelo de la sala. Ahora la
  sala cabe entera en todos los pisos, con sus muros, y la cámara se queda
  quieta. Lo de «cada piso se ve menos» lo dan las salas, que encogen: en el
  12 la sala ocupa la mitad del ancho de la pantalla, y lo de fuera está a
  oscuras (`Penumbra`). La sala del jefe también cabe, y la cámara no se
  acerca a ella (`CamaraJuego.ver_entera` solo abre).
- Las salas se encogen y las rocas por sala suben: cada sala es más densa.
- **Arte por capa**: 1 musgo, 2-3 cueva, 4-8 manto (con cristales hasta el 6),
  9-12 núcleo (con cristales de hierro en el 11 y el 12). Se cambia con
  `catalogo_arte`.

## Ajustar un piso

Abre el `.tres` en el inspector de Godot (o edítalo a mano, es texto plano),
cambia los números y guarda. No hay que recompilar ni tocar GDScript.

Cuidado con dos cosas:

- `ancho_area` o `alto_area` por debajo de ~600 px dejan poco sitio para
  pelear, y las rocas y los enemigos no pueden ponerse delante de las puertas
  (se reservan 190 px), así que en salas muy pequeñas salen menos de los que
  pides.
- Cuando `radio_vision` es menor que media sala (`alto_area / 2`), el suelo ya
  no cabe en pantalla y se pierden de vista partes de la sala, y bajarlo
  agranda todo lo que se ve. Hasta el 2026-10-22 se hacía a propósito en los
  pisos hondos; bajarlo mucho deja enemigos atacando desde fuera de la vista.
- Subir mucho `cantidad_obstaculos` sin subir `ancho_area`/`alto_area` no
  rompe nada: el repartidor descarta los bloques que no encuentran hueco libre
  tras 24 intentos. Si un piso te sale con menos bloques de los que pediste, es
  eso.

El mapa de salas y el reparto de rocas usan semillas derivadas del nombre de
la capa y del número de piso, así que **el piso es siempre idéntico** en todas
las partidas y en las tres máquinas del equipo. Si cambias `nombre_capa` o
`cantidad_salas`, cambia el mapa.
