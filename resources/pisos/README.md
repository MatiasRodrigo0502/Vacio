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
| `radio_vision` | Media altura visible de la cámara, en píxeles. Menor = zoom más cerrado = se ve menos. |
| `cantidad_obstaculos` | Cuántas rocas lleva **cada sala de pelea** (el inicio y la del objeto van limpias). |
| `es_nivel_final` | Solo `true` en el piso 12. Al superarlo se gana la partida. |
| `familia_obstaculos` | Qué rocas usa el piso: `roca`, `bloque`, `grupo` o `piedra`. |
| `catalogo_arte` | Pack de arte del piso (rocas, piedras, plataformas y vegetación). Vacío = el de la cueva sin vegetación. |
| `mostrar_tutorial` | Pinta los carteles de controles sobre el suelo. Solo el piso 1. |

## Valores de partida (sin jugar todavía, pendientes de ajuste)

| # | Capa | sala (ancho × alto) | salas | rocas/sala | vel. | visión |
|---|---|---|---|---|---|---|
| 01 | Corteza continental | 1400 × 820 | 4 | 2 | 80 | 520 |
| 02 | Corteza oceánica | 1340 × 800 | 5 | 3 | 95 | 495 |
| 03 | Litosfera superior | 1280 × 780 | 6 | 3 | 110 | 470 |
| 04 | Astenosfera | 1220 × 760 | 6 | 3 | 130 | 445 |
| 05 | Manto superior | 1160 × 740 | 7 | 4 | 150 | 420 |
| 06 | Zona de transición | 1100 × 720 | 7 | 4 | 175 | 395 |
| 07 | Manto inferior | 1040 × 700 | 8 | 4 | 200 | 370 |
| 08 | Capa D'' | 980 × 680 | 8 | 5 | 230 | 345 |
| 09 | Núcleo externo exterior | 920 × 660 | 9 | 5 | 265 | 320 |
| 10 | Núcleo externo interior | 860 × 640 | 9 | 5 | 300 | 295 |
| 11 | Límite del núcleo interno | 800 × 620 | 10 | 6 | 340 | 270 |
| 12 | Núcleo interno | 740 × 600 | 10 | 6 | 390 | 240 |

Notas de diseño de la curva:

- El piso 1 es una escuela: cuatro salas, sin enemigos, y los carteles de
  controles en la sala de inicio.
- **La visión cae más deprisa que el tamaño de las salas.** Medido con la
  ventana de 1152×648: en los pisos 1 a 4 la sala cabe entera en pantalla,
  muros incluidos, y la cámara se queda quieta. Del 5 al 8 cabe el suelo pero
  no los muros, y la cámara se mueve un poco. Del 9 en adelante ya no cabe ni
  el suelo: en el 12 se ve el 80 % del alto de la sala. Es como sigue siendo
  verdad lo de «cada piso se ve menos» ahora que hay salas; para apretarlo más,
  bajar `radio_vision`.
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
  no cabe en pantalla y se pierden de vista partes de la sala. Es a propósito
  en los pisos hondos, pero bajarlo mucho deja enemigos atacando desde fuera
  de la vista.
- Subir mucho `cantidad_obstaculos` sin subir `ancho_area`/`alto_area` no
  rompe nada: el repartidor descarta los bloques que no encuentran hueco libre
  tras 24 intentos. Si un piso te sale con menos bloques de los que pediste, es
  eso.

El mapa de salas y el reparto de rocas usan semillas derivadas del nombre de
la capa y del número de piso, así que **el piso es siempre idéntico** en todas
las partidas y en las tres máquinas del equipo. Si cambias `nombre_capa` o
`cantidad_salas`, cambia el mapa.
