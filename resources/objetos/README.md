# resources/objetos/

Un `.tres` por objeto recogible. Cada uno es un `ObjetoMejora`
(`scripts/objeto_mejora.gd`).

La mecánica `objetos.tres` deja **uno por piso**, elegido entre los que ya
pueden salir a esa profundidad. Las mejoras **se acumulan durante toda la
partida** y se pierden al empezar una nueva.

## Los que hay

| Objeto | Qué hace | Desde el piso |
|---|---|---|
| Vendaje | Cura 60 de vida | 1 |
| Botas ligeras | +45 de velocidad | 1 |
| Dedal rápido | Cadencia ×0,76 (disparas más seguido) | 2 |
| Núcleo ardiente | +190 de velocidad de bola | 3 |
| Piedra hinchada | +6 de radio de bola | 4 |

**Ningún objeto sube la vida máxima** (decisión de Matías, 2026-10-13): los
la vida solo se recupera, no se añade. **Lo único que cura es el vendaje**
(60): sale como objeto, a veces lo suelta un enemigo y cae al limpiar una sala
una de cada cuatro veces (`resources/mecanicas/vendajes.tres`). Con la vida
llena no se coge (`ObjetoMejora.solo_cura`). Había un «Corazón de roca» que daba
uno más; se quitó, y está en el historial de git. El campo
`vida_maxima_extra` sigue en `ObjetoMejora` por si algún día vuelve.

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
