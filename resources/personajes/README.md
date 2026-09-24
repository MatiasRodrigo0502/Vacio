# resources/personajes/

Un `.tres` por mago elegible. Cada uno es un `PersonajeJugable`
(`scripts/personaje_jugable.gd`): su arte y la ventaja con la que empieza.

`GestorProgreso` lee esta carpeta al arrancar y el menú monta una ficha por
cada archivo, con su retrato, su ventaja y su pega. **Añadir un mago es dejar
su `.tres` aquí**: no hay que tocar el menú, ni el jugador, ni el gestor.

El orden alfabético manda, por eso los archivos empiezan por un número. El
primero es el que se usa si nadie ha elegido (por ejemplo al abrir
`Principal.tscn` directamente desde el editor).

## Los que hay

| Mago | Ventaja | Pega |
|---|---|---|
| Mago oscuro | +35 px/s de velocidad, cadencia ×0,85 | — |
| Mago rojo | +1 corazón, tiempo de carga ×0,5, +2 de daño cargado | −25 px/s de velocidad |

## Cómo añadir uno

1. Mete su arte en `assets/<lo que sea>/` con su `SpriteFrames`. Necesita las
   16 animaciones (`caminar_` y `quieto_` por cada una de las ocho
   direcciones), y un PNG suelto de retrato para el menú.
2. Copia uno de estos `.tres`, cámbiale el nombre del archivo por uno que
   empiece por el número que le toque, y rellena los campos.
3. Ya está. Arranca el juego y su ficha sale en «Elegir mago».

## Sobre las ventajas

Los campos de ventaja se **suman a los valores de fábrica** del jugador, no se
aplican como un objeto recogido. La diferencia importa: los objetos que se
cogen por los pisos se pierden al empezar otra partida, y lo del mago no, que
es lo que ES ese mago.

Que cada mago tenga también una **pega** no es decoración: si uno fuera mejor a
secas, elegir dejaría de ser una decisión. La pega se enseña en su ficha, al
lado de la ventaja.
