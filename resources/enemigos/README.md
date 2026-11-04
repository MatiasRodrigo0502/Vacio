# resources/enemigos/

Un `.tres` por tipo de enemigo. Cada uno es un `TipoEnemigo`
(`scripts/tipo_enemigo.gd`).

**Añadir un enemigo nuevo no toca código**: la mecánica `enemigos.tres` lee esta
carpeta entera y reparte por el piso los tipos que pueden salir a esa
profundidad. Basta con dejar aquí otro `.tres`.

## Los que hay

Tres criaturas, cada una con **una variante por capa de la Tierra**: corteza
(pisos 1 a 4), manto (5 a 8) y núcleo (9 a 12). Las trajo Matías el 2026-11-04
(`vacio_completo.zip`) para sustituir a los once de antes, que siguen en
[`resources/enemigos_antiguos/`](../enemigos_antiguos/README.md). El arte y su
tamaño salen de `herramientas/generar_enemigos.py`.

**Cada una hace algo distinto** (pedido por Matías el 2026-10-13): lo decide su
`comportamiento`, un recurso de `scripts/comportamientos/` con sus números
ajustables, que va dentro del propio `.tres`.

Además, dos formas de pelear (`ataque`), que deciden el reparto:

- **Cuerpo a cuerpo**: van a por ti y son **más rápidos** (de 95 a 190). Hay que
  pararlos antes de que lleguen.
- **A distancia**: **lentos** (de 60 a 70), se quedan a su `distancia_preferida`
  y disparan cada `cadencia` segundos. Antes de cada disparo se paran y avisan
  durante `tiempo_apuntar`. Las rocas paran sus disparos.

La vida va en puntos (un disparo normal quita 10) y «Contacto» es lo que te
quitan al tocarte (tú tienes 100). Los números van **a ojo: nadie lo ha jugado**.

| Tipo (corteza / manto / núcleo) | Vida | Contacto | Velocidad | Monedas | Qué hace |
|---|---|---|---|---|---|
| **Gólem** | 60 / 80 / 100 | 25 / 30 / 35 | 95 / 105 / 115 | 6 / 8 / 10 | `golpe.gd`: va a por ti y, a tu lado, se para, levanta los brazos (un aro marca hasta dónde llega) y golpea el suelo a dos manos. Quita lo mismo que al tocarle; es una onda de 130 / 140 / 150 de radio. Si algo le corta el paso, va de lado un rato |
| **Vigía** | 30 / 40 / 50 | 25 / 25 / 30 | 60 / 65 / 70 | 3 / 4 / 5 | `abanico.gd`: te rodea de lado y dispara 1 / 3 / 3 esquirlas, cada 2,2 / 2 / 1,8 s, que quitan 20 / 30 / 40. **Busca tenerte a tiro**: si hay una roca en medio, va al sitio más cercano desde el que no la haya. **Flota** (`vuela`) |
| **Murciélago** | 10 / 10 / 20 | 20 / 25 / 30 | 150 / 170 / 190 | 1 / 1 / 2 | `picado.gd`: da vueltas a tu alrededor, marca una línea y se lanza por ella, pasando de largo. **Vuela** (`vuela`). Salen **de tres en tres** (`grupo`) |

**Salen al azar.** Cada sala elige entre los tipos cuyo piso está entre
`piso_minimo` y `piso_maximo`. Como mucho **la mitad** de una sala son de
distancia (`proporcion_distancia` en `resources/mecanicas/enemigos.tres`). Los
tres murciélagos cuentan como **uno** al repartir: entre todos tienen la vida de
un vigía de la corteza.

Medido: de 17 enemigos en el piso 2 a 130 en el 12, unos 650 en toda la partida
(antes, 378 más las crías, unas 600 muertes).

**Al morir** hacen su animación de muerte y dejan los restos un momento
(`RestosEnemigo`), salvo si los mata un arma con su propia animación
(`AnimacionMuerte`). Para el juego mueren de golpe: la sala los deja de contar en
ese instante.

**Los agujeros del suelo** se esquivan: andando, ningún enemigo se mete en uno
(lo rodea). Si lo empujan (la burbuja del mago blanco, el agujero negro del
oscuro) sí, y entonces cae y muere. Los que tienen `vuela` pasan por encima y no
caen.

Los proyectiles son su propio `.tres`, en `resources/proyectiles/`.

## El dibujo

`animaciones` es un `SpriteFrames` con **una animación por dirección**:
`caminar_`, `atacar_`, `dano_` y `muerte_` + uno de los ocho lados de
`Jugador.LADOS`. Quien elige cuál es `Enemigo` (`mirar_a`, `gesto`):

- `caminar` da vueltas; `atacar` y `dano` se hacen una vez y vuelve a andar.
  Que le den no interrumpe un ataque.
- `alto` es lo que mide **el cuerpo**: de ahí salen el círculo que choca (0,4) y
  los pies. La casilla de la hoja es mayor, con margen para los brazos y la
  sombra: `escala_dibujo` es a cuánto se pinta y `desfase_dibujo`, lo que se mueve
  para que el centro del cuerpo caiga en el del círculo.

## Comportamientos

Cada uno es un script de `scripts/comportamientos/` que hereda de
`ComportamientoEnemigo`, con sus números como `@export`. En el `.tres` del enemigo
va como `comportamiento` y se le cambian los números ahí mismo. Sin
comportamiento, el enemigo hace lo de antes: ir directo a por ti, o quedarse lejos
y disparar.

| Script | Lo usa | Qué hace |
|---|---|---|
| `golpe.gd` | gólem | va a por ti y golpea a dos manos (`alcance`, `pose_golpe`, `radio_golpe`, `dano_golpe`, `recarga`, `rodeo`) |
| `abanico.gd` | vigía | se mueve de lado y dispara en abanico (`disparos`, `apertura`); sin tiro, busca alrededor un sitio con tiro y va allí (`cada_busqueda`, `radio_busqueda`) |
| `picado.gd` | murciélago | órbita, aviso con línea y picado |
| `corazon_nucleo.gd` | el jefe | ver [`resources/jefes/`](../jefes/README.md) |

`saltos.gd`, `zigzag.gd`, `rebote.gd`, `fantasma.gd`, `excavar.gd`, `anillo.gd`,
`pisoton.gd` y `teletransporte.gd` son de los enemigos de antes: no los usa ninguno
de los de ahora, pero sirven para cualquiera nuevo.

Todos avisan antes de lo que pega fuerte o de golpe (un aro, una línea, el brillo,
lo que hace el dibujo). Un comportamiento nuevo es un script más en esa carpeta:
lo que guarda de cada enemigo va en `enemigo.estado` (el recurso es uno para todo
el tipo).

## Por qué son Resources y no una escena por enemigo

Todos comparten el mismo cuerpo: moverse, hacer daño al tocar y morir. Lo que
cambia son los números, el dibujo y la forma de atacar. Con una escena por enemigo
habría nueve archivos casi idénticos que mantener.
