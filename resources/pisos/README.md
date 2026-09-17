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
| `ancho_area` | Ancho del área jugable en píxeles. Es el embudo: baja piso a piso. |
| `alto_area` | Largo del descenso, de la entrada a la salida. |
| `velocidad_obstaculos` | Velocidad base de los obstáculos (px/s). En Fase 1 los bloques son estáticos, pero el valor ya llega hasta ellos. |
| `radio_vision` | Media altura visible de la cámara, en píxeles. Menor = zoom más cerrado = se ve menos. |
| `cantidad_obstaculos` | Cuántos bloques se reparten por el piso. |
| `es_nivel_final` | Solo `true` en el piso 12. Al superarlo se gana la partida. |
| `familia_obstaculos` | Qué rocas usa el piso: `roca`, `bloque`, `grupo` o `piedra`. |
| `catalogo_obstaculos` | Catálogo de texturas alternativo. Vacío = el de la cueva. |
| `mostrar_tutorial` | Pinta los carteles de controles sobre el suelo. Solo el piso 1. |

## Valores de partida (sin jugar todavía, pendientes de ajuste)

| # | Capa | ancho | alto | vel. | visión | obst. |
|---|---|---|---|---|---|---|
| 01 | Corteza continental | 1600 | 1800 | 80 | 520 | 4 |
| 02 | Corteza oceánica | 1480 | 1780 | 95 | 495 | 5 |
| 03 | Litosfera superior | 1360 | 1760 | 110 | 470 | 6 |
| 04 | Astenosfera | 1240 | 1740 | 130 | 445 | 8 |
| 05 | Manto superior | 1120 | 1720 | 150 | 420 | 9 |
| 06 | Zona de transición | 1000 | 1700 | 175 | 395 | 11 |
| 07 | Manto inferior | 900 | 1680 | 200 | 370 | 13 |
| 08 | Capa D'' | 800 | 1660 | 230 | 345 | 15 |
| 09 | Núcleo externo exterior | 700 | 1640 | 265 | 320 | 16 |
| 10 | Núcleo externo interior | 610 | 1620 | 300 | 295 | 17 |
| 11 | Límite del núcleo interno | 530 | 1600 | 340 | 270 | 18 |
| 12 | Núcleo interno | 460 | 1580 | 390 | 240 | 18 |

Notas de diseño de la curva:

- El piso 1 es una escuela: sitio de sobra para entender la inercia.
- El 4 (astenosfera) es el primer salto real de densidad.
- El 6 (zona de transición) es el punto de inflexión de la curva.
- Del 9 en adelante la visión ya está muy cerrada; la dificultad viene tanto de
  no ver como de no caber.

## Ajustar un piso

Abre el `.tres` en el inspector de Godot (o edítalo a mano, es texto plano),
cambia los números y guarda. No hay que recompilar ni tocar GDScript.

Cuidado con dos cosas:

- `ancho_area` por debajo de ~420 px deja el piso casi intransitable con el
  tamaño actual del jugador (radio 13) y de los bloques.
- Subir mucho `cantidad_obstaculos` sin subir `ancho_area`/`alto_area` no
  rompe nada: el repartidor descarta los bloques que no encuentran hueco libre
  tras 24 intentos. Si un piso te sale con menos bloques de los que pediste, es
  eso.

El reparto de obstáculos usa una semilla derivada del nombre de la capa y del
número de piso, así que **el piso es siempre idéntico** en todas las partidas y
en las tres máquinas del equipo. Si cambias `nombre_capa`, cambia el reparto.
