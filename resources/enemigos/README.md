# resources/enemigos/

Un `.tres` por tipo de enemigo. Cada uno es un `TipoEnemigo`
(`scripts/tipo_enemigo.gd`).

**Añadir un enemigo nuevo no toca código**: la mecánica `enemigos.tres` lee esta
carpeta entera y reparte por el piso los tipos que ya pueden salir a esa
profundidad. Basta con dejar aquí otro `.tres`.

## Los que hay

**Cada uno hace algo distinto** (pedido por Matías el 2026-10-13): lo decide
su `comportamiento`, un recurso de `scripts/comportamientos/` con sus números
ajustables, que va dentro del propio `.tres` (ver «Comportamientos» más abajo).

Además, dos formas de pelear (`ataque`), que deciden el reparto:

- **Cuerpo a cuerpo**: van directos a por ti y son **rápidos**. Hay que
  pararlos antes de que lleguen.
- **A distancia**: **lentos**, se quedan a su `distancia_preferida` (si te
  acercas, retroceden) y disparan cada `cadencia` segundos. Pegan más fuerte,
  pero antes de cada disparo se paran y avisan durante `tiempo_apuntar`: el
  aviso es lo que hace justo el daño alto. Las rocas paran sus disparos. Con
  `tiempo_apuntar` a 0 dispara sin avisar, y si es un rayo su línea sale a la
  vez que el disparo (el cristal).

La vida va en puntos (un disparo normal quita 10) y «Contacto» es lo que te
quitan al tocarte (tú tienes 100).

| Tipo | Ataque | Vida | Contacto | Velocidad | Desde el piso | Qué hace (`comportamiento`) |
|---|---|---|---|---|---|---|
| Slime verde | cuerpo a cuerpo | 20 | 25 | 100 | 1 | **a saltos**: se aplasta (el aviso), salta hacia ti y descansa. Al morir explota (radio 70) y se parte en 4 crías |
| Rata | cuerpo a cuerpo | 10 | 20 | 160 | 2 | **en zigzag**: corre hacia ti haciendo eses; de cerca, recta |
| Serpiente | distancia: **veneno** | 20 | 25 | 68 | 2 | **en abanico**: te rodea de lado y dispara 3 bolas abiertas. **Busca tenerte a tiro**: si hay una roca en medio, va al sitio más cercano desde el que no la haya, y no dispara hasta tenerte. El veneno quita 20, te frena 3 s y en ese rato te quita 2 más |
| Planta venenosa («el pulpo») | distancia: **veneno** | 30 | 25 | 12 → 300 | 3 | **en anillo**: se hincha y suelta 8 esporas en todas direcciones, cada anillo girado. Quieta hasta que se cierran las puertas; entonces **te persigue**, a 12 px/s y +45 cada 2 s (lo de las Botas ligeras), hasta 300. Hay que matarla pronto |
| Murciélago | cuerpo a cuerpo | 10 | 20 | **195** | 3 | **en picado**: da vueltas a tu alrededor, marca una línea y se lanza por ella, pasando de largo. **Vuela** (`vuela`): ni los agujeros ni la lava le afectan |
| Gólem de roca | distancia: **magma** | 50 | 35 | 38 | 4 | **pisotón**: de lejos tira magma (quita 45 y deja lava 3,5 s); si te acercas, avisa con un aro y suelta una onda (quita 30) que hay que esquivar alejándose |
| Slime naranja | cuerpo a cuerpo | 30 | 25 | 132 | 5 | **rebota**: no te persigue; cruza la sala en diagonal y rebota en muros y rocas. Explota (75) y se parte en 4 |
| Slime de magma | cuerpo a cuerpo | 30 | 30 | 118 | 5 | **a saltos, dejando lava** donde cae (2,5 s). Explota (85) y se parte en 4 |
| Cristal vivo | distancia: **rayo** (quita 50) | 30 | 25 | **0** | 5 | **teletransporte**: dispara en cuanto sale su línea y, poco después, desaparece y sale en otro sitio de la sala, lejos de ti |
| Fantasma | cuerpo a cuerpo | 20 | 25 | 115 | 6 | **se desvanece**: atraviesa las rocas y, a ratos, se vuelve casi invisible; entonces ni le das ni te da. **Flota** (`vuela`): ni los agujeros ni la lava le afectan |
| Planta azul | cuerpo a cuerpo | 20 | 30 | 150 | 7 | **excava**: se entierra, el montículo avanza bajo el suelo y sale debajo de ti tras avisar con un aro; bajo tierra no se le puede dar |

El más lento de cuerpo a cuerpo (100) es casi el doble de rápido que el más
rápido a distancia (55).

**Salen al azar.** Cada sala elige entre todos los tipos cuyo `piso_minimo` ya
se ha alcanzado. Como mucho **la mitad** de una sala son de distancia
(`proporcion_distancia` en `resources/mecanicas/enemigos.tres`): una sala solo
de tiradores sería una lluvia de disparos desde todas partes.

**Los slimes** (`division`, `radio_explosion`): al morir explotan en un radio
pequeño, que te quita 25 si estás dentro, y sueltan cuatro crías (dos hasta el
2026-11-03), que heredan lo que le quedaba a la madre de frío, quemadura y
veneno. Las crías son el
mismo slime en pequeño, más rápidas y con 10 de vida, y ni explotan ni se
dividen: si no, matar un slime desataría una cadena imposible de esquivar. La
sala no se abre hasta matar también a las crías. Matarlos de lejos sale a
cuenta.

**Los agujeros del suelo** se esquivan: andando, ningún enemigo se mete en
uno (lo rodea). Si lo empujan (la burbuja del mago blanco, el agujero negro
del oscuro) sí, y entonces cae y muere, sin explotar ni soltar crías. Los
que tienen `vuela` (murciélago y fantasma) pasan por encima y no caen.

Los proyectiles (veneno, magma, rayo) son su propio `.tres`, en
`resources/proyectiles/`: dos enemigos pueden tirar lo mismo.

## Comportamientos

Cada uno es un script de `scripts/comportamientos/` que hereda de
`ComportamientoEnemigo`, con sus números como `@export` (duración del salto,
radio de la órbita, balas del abanico...). En el `.tres` del enemigo va como
`comportamiento` y se le cambian los números ahí mismo, en el inspector.
Varios enemigos pueden usar el mismo (los slimes verde y de magma usan
`saltos.gd`, el de magma con charco). Sin comportamiento, el enemigo hace lo
de antes: ir directo a por ti, o quedarse lejos y disparar.

| Script | Lo usa | Qué hace |
|---|---|---|
| `saltos.gd` | slime verde, slime de magma | avanza a saltos; con `charco_radio` deja lava al caer |
| `zigzag.gd` | rata | corre haciendo eses |
| `picado.gd` | murciélago | órbita, aviso con línea y picado |
| `rebote.gd` | slime naranja | cruza la sala rebotando |
| `fantasma.gd` | fantasma | atraviesa rocas y se desvanece a ratos |
| `excavar.gd` | planta azul | se entierra y sale debajo de ti |
| `abanico.gd` | serpiente | se mueve de lado y dispara en abanico; sin tiro (una roca o un muro en medio), busca alrededor un sitio con tiro y va alli (`cada_busqueda`, `radio_busqueda`) |
| `anillo.gd` | planta venenosa | anillos de esporas; con las puertas cerradas, persigue cada vez más rápido (`velocidad_inicial`, `aumento`, `cada_aumento`, `velocidad_maxima`) |
| `pisoton.gd` | gólem | magma de lejos, onda de cerca (`OndaChoque`) |
| `teletransporte.gd` | cristal vivo | dispara y salta a otro sitio |

Todos avisan antes de lo que pega fuerte o de golpe (aplastarse, una línea,
un aro), igual que los de distancia antes de disparar. Lo que va escondido o
desvanecido es **intocable**: las bolas lo atraviesan y no hace daño al tocar.

Un comportamiento nuevo es un script más en esa carpeta: lo que guarda de
cada enemigo va en `enemigo.estado` (el recurso es uno para todo el tipo).

## Por qué son Resources y no una escena por enemigo

Todos comparten el mismo cuerpo: moverse, hacer daño al tocar y morir. Lo que
cambia son los números, el dibujo y la forma de atacar. Con una escena por enemigo habría once archivos
casi idénticos que mantener.
