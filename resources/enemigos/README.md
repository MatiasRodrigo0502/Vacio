# resources/enemigos/

Un `.tres` por tipo de enemigo. Cada uno es un `TipoEnemigo`
(`scripts/tipo_enemigo.gd`).

**Añadir un enemigo nuevo no toca código**: la mecánica `enemigos.tres` lee esta
carpeta entera y reparte por el piso los tipos que ya pueden salir a esa
profundidad. Basta con dejar aquí otro `.tres`.

## Los que hay

Dos formas de pelear (`ataque`):

- **Cuerpo a cuerpo**: van directos a por ti y son **rápidos**. Hay que
  pararlos antes de que lleguen.
- **A distancia**: **lentos**, se quedan a su `distancia_preferida` (si te
  acercas, retroceden) y disparan cada `cadencia` segundos. Pegan más fuerte,
  pero antes de cada disparo se paran y avisan durante `tiempo_apuntar`: el
  aviso es lo que hace justo el daño alto. Las rocas paran sus disparos.

| Tipo | Ataque | Vida | Velocidad | Desde el piso | Qué tiene de especial |
|---|---|---|---|---|---|
| Slime verde | cuerpo a cuerpo | 2 | 100 | 1 | al morir, explota (radio 70) y se parte en 2 crías |
| Rata | cuerpo a cuerpo | 1 | 160 | 2 | |
| Serpiente | distancia: **veneno** | 2 | 55 | 2 | el veneno quita 1 y te frena 2,5 s |
| Planta venenosa | distancia: **veneno** | 3 | 28 | 3 | ve poco (360): emboscada |
| Murciélago | cuerpo a cuerpo | 1 | **195** | 3 | el más rápido del juego |
| Gólem de roca | distancia: **magma** | 5 | 38 | 4 | lo tira por el aire: quita 2 y deja lava 3,5 s |
| Slime naranja | cuerpo a cuerpo | 3 | 132 | 5 | explota (75) y se parte en 2 |
| Slime de magma | cuerpo a cuerpo | 3 | 118 | 5 | explota (85) y se parte en 2 |
| Cristal vivo | distancia: **rayo** | 3 | **0** | 5 | apunta 0,8 s con una línea; el rayo quita 2 |
| Fantasma | cuerpo a cuerpo | 2 | 115 | 6 | ve desde más lejos que nadie (800) |
| Planta azul | cuerpo a cuerpo | 2 | 150 | 7 | |

El más lento de cuerpo a cuerpo (100) es casi el doble de rápido que el más
rápido a distancia (55). El contacto quita 1 en todos.

**Salen al azar.** Cada sala elige entre todos los tipos cuyo `piso_minimo` ya
se ha alcanzado. Como mucho **la mitad** de una sala son de distancia
(`proporcion_distancia` en `resources/mecanicas/enemigos.tres`): una sala solo
de tiradores sería una lluvia de disparos desde todas partes.

**Los slimes** (`division`, `radio_explosion`): al morir explotan en un radio
pequeño, que te quita 1 si estás dentro, y sueltan dos crías. Las crías son el
mismo slime en pequeño, más rápidas y con 1 de vida, y ni explotan ni se
dividen: si no, matar un slime desataría una cadena imposible de esquivar. La
sala no se abre hasta matar también a las crías. Matarlos de lejos sale a
cuenta.

Los proyectiles (veneno, magma, rayo) son su propio `.tres`, en
`resources/proyectiles/`: dos enemigos pueden tirar lo mismo.

## Por qué son Resources y no una escena por enemigo

Todos comparten el mismo cuerpo: moverse, hacer daño al tocar y morir. Lo que
cambia son los números, el dibujo y la forma de atacar. Con una escena por enemigo habría once archivos
casi idénticos que mantener.
