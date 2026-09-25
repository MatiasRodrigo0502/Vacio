# resources/enemigos/

Un `.tres` por tipo de enemigo. Cada uno es un `TipoEnemigo`
(`scripts/tipo_enemigo.gd`).

**Añadir un enemigo nuevo no toca código**: la mecánica `enemigos.tres` lee esta
carpeta entera y reparte por el piso los tipos que ya pueden salir a esa
profundidad. Basta con dejar aquí otro `.tres`.

## Los que hay

| Tipo | Vida | Velocidad | Visión | Alto | Desde el piso |
|---|---|---|---|---|---|
| Slime verde | 2 | 78 | 620 | 54 | 1 |
| Rata | 1 | 125 | 560 | 40 | 2 |
| Serpiente | 2 | 95 | 520 | 44 | 2 |
| Planta venenosa | 3 | 46 | 300 | 62 | 3 |
| Murciélago | 1 | 145 | 700 | 44 | 3 |
| Gólem de roca | 5 | 52 | 480 | 66 | 4 |
| Slime naranja | 3 | 104 | 760 | 58 | 5 |
| Slime de magma | 3 | 90 | 640 | 56 | 5 |
| Cristal vivo | 3 | **0** | 400 | 56 | 5 |
| Fantasma | 2 | 88 | 800 | 54 | 6 |
| Planta azul | 2 | 132 | 420 | 50 | 7 |

Todos hacen 1 de daño.

**Salen al azar.** Cada sala elige entre todos los tipos cuyo `piso_minimo` ya
se ha alcanzado, así que del piso 7 en adelante puede salir cualquiera de los
once. El piso mínimo solo escalona la dificultad: los flojos y rápidos (rata,
serpiente, murciélago) desde arriba; los que aguantan mucho (gólem, slime de
magma) más abajo.

Algunos con carácter propio:

- **Rata y murciélago** mueren de un disparo, pero son los más rápidos: se
  echan encima antes de que apuntes.
- **Gólem de roca**: cinco de vida y lento. Es el que pide el ataque cargado
  (el del mago rojo lo mata de un golpe).
- **Cristal vivo**: no se mueve (velocidad 0), como dice su descripción en
  `assets/README.md`. Es una trampa fija, pero la sala no se abre hasta
  romperlo, así que hay que ir a por él.
- **Fantasma**: el que ve desde más lejos (800): te persigue por toda la sala.

`radio_vision` cambia mucho el carácter: la planta venenosa tiene 300, así que
no se entera de que estás ahí hasta que la tienes encima y funciona como
emboscada; el fantasma y el slime naranja te persiguen desde lejos.

## Por qué son Resources y no una escena por enemigo

Todos se comportan igual: perseguir y hacer daño al tocar. Lo único que cambia
son los números y el dibujo. Con una escena por enemigo habría once archivos
casi idénticos que mantener.
