# resources/objetos/

Un `.tres` por objeto recogible. Cada uno es un `ObjetoMejora`
(`scripts/objeto_mejora.gd`).

La mecánica `objetos.tres` deja **uno por piso**, elegido entre los que ya
pueden salir a esa profundidad. El **cofre de la sala secreta** de cada piso
(`scripts/cofre.gd`) sortea con una ruleta entre los que duran (todos menos
el vendaje) que ya pueden salir en ese piso: un objeto nuevo entra solo en
la ruleta. Las mejoras **se acumulan durante toda la
partida** y se pierden al empezar una nueva.

## Los que hay

| Objeto | Qué hace | Desde el piso |
|---|---|---|
| Vendaje | Cura 60 de vida | 1 |
| Botas ligeras | +45 de velocidad | 1 |
| Dedal rápido | Cadencia ×0,76 (disparas más seguido) | 2 |
| Núcleo ardiente | +190 de velocidad de bola | 3 |
| Piedra hinchada | +6 de radio de bola (no agranda la bola cargada del mago rojo) | 4 |

**Ningún objeto sube la vida máxima** (decisión de Matías, 2026-10-13): los
la vida solo se recupera, no se añade. **Lo único que cura es el vendaje**
(60): sale como objeto, a veces lo suelta un enemigo y cae al limpiar una sala
una de cada cuatro veces (`resources/mecanicas/vendajes.tres`). Con la vida
llena no se coge (`ObjetoMejora.solo_cura`). Había un «Corazón de roca» que daba
uno más; se quitó, y está en el historial de git. El campo
`vida_maxima_extra` sigue en `ObjetoMejora` por si algún día vuelve.

## Los iconos

Cada objeto es un aro de su color con el símbolo dentro, pintado del mismo
color, con el borde y los detalles en un tono más oscuro de ese color; entre
el aro y el símbolo, transparente (bota con rayas de prisa, rayo, bola de
fuego, bola con flechas hacia fuera, cruz de tiritas). Los dibuja
`herramientas/generar_iconos_objetos.py` desde el 2026-11-03. Matías pidió
primero otros dibujos («me gusta la sencillez del color, pero no me
convencen todos los dibujos»); salió un orbe relleno con el símbolo en
blanco, y lo quiso más sencillo: «uno o dos tonos de un solo color». Como el
aro ya va en el icono, el objeto del suelo (`Objeto`) y la fila del HUD
(`MejorasRecogidas`) ya no pintan el suyo. Antes eran formas sueltas de
color (bota, rayo, llama, bola, cruz); están en el historial de git. Un
objeto nuevo: una función más en el script.

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
