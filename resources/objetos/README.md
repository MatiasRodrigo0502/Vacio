# resources/objetos/

Un `.tres` por objeto recogible. Cada uno es un `ObjetoMejora`
(`scripts/objeto_mejora.gd`).

La mecánica `objetos.tres` deja **uno por piso**, elegido entre los que ya
pueden salir a esa profundidad. Las mejoras **se acumulan durante toda la
partida** y se pierden al empezar una nueva.

## Los que hay

| Objeto | Qué hace | Desde el piso |
|---|---|---|
| Corazón de roca | +1 al máximo de vida (y lo llena) | 1 |
| Vendaje | Cura 2 corazones | 1 |
| Botas ligeras | +45 de velocidad | 1 |
| Dedal rápido | Cadencia ×0,76 (disparas más seguido) | 2 |
| Núcleo ardiente | +190 de velocidad de bola | 3 |
| Piedra hinchada | +6 de radio de bola | 4 |

## El código de color

El color del `.tres` es la única pista visual de lo que hace, así que conviene
mantenerlo: **rojo** vida, **verde** movimiento, **azul** disparo, **naranja**
velocidad de bola, **morado** tamaño de bola.

## Añadir uno nuevo

Crea otro `.tres` aquí con sus números y ya sale. No hay escena por objeto: la
misma `Objeto.tscn` sirve para todos y se tiñe del color que le digas.

Cuidado con `cadencia_multiplicador`: se multiplica, así que dos dedales dejan
la cadencia en 0,58 veces la original. Hay un tope en `Jugador.CADENCIA_MINIMA`
(0,09 s) para que el disparo no acabe siendo una manguera.
