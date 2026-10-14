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

## mago_caido.tres — el Mago Caído (piso 12)

Pedido por Matías el 2026-10-14: el cuarto mago, el que bajó antes que tú,
con las habilidades de los otros tres y **rayos en vez de bolas**. El dibujo
es el del mago rojo **en negro y oro y con una guadaña** en vez del báculo, a
×2 (`herramientas/generar_mago_caido.py` → `assets/mago_caido/`). Al
principio era violeta y se confundía con el mago oscuro: Matías lo cambió el
mismo día. Sus efectos (rayos, aura, barra, agujero negro) también van en
oro.

| | |
|---|---|
| Vida | 900 |
| Rayo (`proyectiles/rayo_caido.tres`) | quita 20, cada 1,5 s, con 0,55 s de línea de aviso |
| Distancia | se queda a unos 380 px |

Cómo pelea lo decide `scripts/comportamientos/mago_caido.gd`, con todos sus
números en el `.tres` (el `comportamiento`):

- **Fase 1 (100–66 %)**: rayos y el **agujero negro** del mago oscuro al
  revés: se abre donde estás (0,9 s de aviso mientras crece) y tira de ti;
  en el centro quita 15. Ver `scripts/pozo_vacio.gd`.
- **Fase 2 (66–33 %)**: además, el **escudo** del mago blanco: 4 s en los que
  no se le puede dar (ni quemar) y suelta anillos de 10 esquirlas de hielo
  que frenan y quitan 12 (`proyectiles/esquirla_hielo.tres`).
- **Fase 3 (33–0 %)**: además, el **ataque cargado** del mago rojo: carga
  1,4 s un rayo de fuego (la línea te sigue y se queda quieta los últimos
  0,45 s), quita 50 y deja charcos de fuego. **Un pilar lo para, pero se
  rompe** (`Obstaculo.romper()`, con escombros): cada pilar cubre una vez.
  Los rayos salen de tres en tres.
- Cada fase va más deprisa (`ritmo_fases`: 1, 1,15 y 1,35) y entre una
  habilidad y otra pasan 5 s.
- **Al cambiar de fase** se va al centro, no se le puede dar 1,6 s, suelta
  una onda (quita 25) y deja un corazón.
- **Al morir**: explosión grande y un segundo a cámara lenta.

Hasta que se cierran las puertas y acaba su presentación (2,2 s) no se le
puede dar: si no, desde el umbral de la puerta se le quitaba vida sin pelear.

**Nadie lo ha jugado todavía**: estos números son un punto de partida. El
registro de partidas apunta cada golpe suyo («Mago caído (rayo de fuego)»…)
y cuánto dura la pelea.
