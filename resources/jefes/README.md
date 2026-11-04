# resources/jefes/

Los jefes, uno por `.tres`. Son `TipoEnemigo` como los de
`resources/enemigos/`, con `jefe = true`.

**Van en otra carpeta a propósito**: la mecánica de enemigos reparte al azar
todo lo que hay en `resources/enemigos/`, y un jefe no puede salir en una sala
cualquiera. A un jefe lo pone su piso: `DatosPiso.jefe` (en el grupo «Sala del
jefe» del `.tres` del piso), en el centro de la sala del jefe. Mientras vive,
la bajada está tapada; al morir, la sala queda limpia y se abre.

Ser jefe (`jefe = true`) también quiere decir:

- su vida sale en una barra abajo, con su nombre, y se presenta con su
  `titulo` al cerrarse las puertas (`scripts/barra_jefe.gd`);
- ni el agujero negro del mago oscuro ni la burbuja del mago blanco lo
  mueven (el agujero sí le quita vida);
- el frío del mago blanco le dura el 40 % (`Enemigo.FRIO_JEFE`).

## corazon_nucleo.tres — el Corazón del Núcleo (piso 12)

Lo trajo Matías el 2026-11-04 (`vacio_completo.zip`), en lugar del Mago Caído: una
esfera de magma que flota, con un ojo que te sigue, anillos y púas de cristal. El
arte, de `herramientas/generar_enemigos.py` → `assets/criaturas/jefe/`.

**Se queda la pelea que tenía el Mago Caído y se le añade la del paquete.** Esa
pelea es lo que Matías fue pidiendo (las habilidades de los otros magos, «más
difícil», el aliento de fuego), y la del paquete sola, una nova cada 3,5 s, sería
un jefe mucho más fácil. La furia del paquete (más rápido por debajo del 50 %) no
hace falta: ya va más rápido en cada fase. Lo que trae el paquete, tal cual, está
en `assets/enemigos_fuente/del_paquete/jefe_nucleo.gd`.

| | |
|---|---|
| Vida | 1500 |
| Bola de magma (`proyectiles/bola_nucleo.tres`) | quita 20, a 440 px/s, cada 1,5 s, con 0,55 s de aviso (brilla). En abanico: 1, 3 y 5 según la fase (`bolas_por_fase`, a 16° una de otra). Hasta el Mago Caído, eran rayos |
| Distancia | se queda a unos 380 px |
| Botín | 200 monedas y 10 diamantes |

Cómo pelea lo decide `scripts/comportamientos/corazon_nucleo.gd`, con todos sus
números en el `.tres` (el `comportamiento`):

- **En las tres fases, la nova** (del paquete): avisa 0,9 s con un aro en el suelo y
  suelta una onda desde su sombra, que llega a 380 px y quita 30, y un anillo de 8
  bolas, girado al azar. Su animación `atacar` empieza a tiempo para que la onda del
  dibujo salga con la de verdad.
- **Fase 1 (100–66 %)**: además, un **agujero negro** al revés: se abre donde estás
  (0,9 s de aviso mientras crece), mide 200 px y tira de ti; en el centro quita 20.
  Ver `scripts/pozo_vacio.gd`.
- **Fase 2 (66–33 %)**: además, un **escudo**: 4 s en los que no se le puede dar (ni
  quemar) y suelta un anillo de 14 esquirlas de hielo cada 0,85 s, que frenan y
  quitan 12 (`proyectiles/esquirla_hielo.tres`).
- **Fase 3 (33–0 %)**: además, un **rayo de fuego**: carga 1,2 s (la línea te sigue y
  se queda quieta los últimos 0,45 s), quita 50 y deja 7 charcos de fuego que duran
  4 s. **Un pilar lo para, pero se rompe** (`Obstaculo.romper()`, con escombros):
  cada pilar cubre una vez.
- **En las tres fases, el aliento de fuego** (desde el 2026-11-03, pedido por Matías;
  `scripts/aliento_fuego.gd`): toma como referencia dónde estás al empezar, avisa
  0,6 s (una línea por donde va a salir y una flecha hacia donde va a girar) y escupe
  un chorro que sale 10° a un lado de ti (al azar cuál) y gira 90° en 2 s hacia el
  otro, pasando por encima de ti, hasta el borde de la sala (no lo paran las rocas ni
  los pilares). Si te toca, quita 15 y te deja quemándote 3 s (3 cada medio segundo,
  con llamas a los pies; como el veneno, no mata). El escudo del mago blanco lo para.
  Mientras escupe, el jefe no se mueve.
- **La rueda de habilidades**: fase 1 nova, pozo y aliento; fase 2 escudo, nova, pozo y
  aliento; fase 3 rayo de fuego, nova, pozo, aliento, rayo de fuego y escudo.
- Cada fase va más deprisa (`ritmo_fases`: 1,1, 1,3 y 1,5) y entre una habilidad y
  otra pasan 3,5 s.
- **Al cambiar de fase** se va al centro, no se le puede dar 1,6 s, suelta una onda
  (quita 25) y deja un vendaje (cura 60).
- **Al morir**: su animación de muerte (se agrieta, estalla y deja los trozos) y un
  segundo a cámara lenta.

Hasta que se cierran las puertas y acaba su presentación (2,2 s) no se le puede dar:
si no, desde el umbral de la puerta se le quitaba vida sin pelear.

**Más difícil desde el 2026-10-21** (Matías, aún con el Mago Caído: «que el boss
final sea más complicado»). Antes: 900 de vida, ritmo 1 / 1,15 / 1,35, una habilidad cada
5 s, rayos de uno en uno hasta la fase 3 (y de tres en tres en ella), pozo de
170 px que quitaba 15, anillos de 10 esquirlas cada 1,1 s y un rayo de fuego
que cargaba 1,4 s con 5 charcos de 3 s. Medido con un mago oscuro sin
mejoras que se queda quieto y le dispara sin parar (sin esquivar nada): la
pelea pasó de 55 a 95 s, y lo que le quitan, de 537 a 1124 de vida. Con
100 de vida y los tres vendajes de por medio (antesala y dos cambios de
fase), ahora hay que esquivar mucho más de la mitad. Esas medidas son de antes de
cambiar los rayos por bolas y añadir la nova: **no se han repetido**.

**Nadie lo ha jugado todavía**: estos números son un punto de partida. El
registro de partidas apunta cada golpe suyo («Corazón del Núcleo (nova)»…)
y cuánto dura la pelea.
