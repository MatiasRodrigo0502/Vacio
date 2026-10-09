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
| Mago oscuro | +35 px/s de velocidad; su bola cargada abre un agujero negro | su bola cargada llega a 320 px |
| Mago rojo | +1 corazón, tiempo de carga ×0,5, +2 de daño cargado | −25 px/s de velocidad |
| Mago blanco | ataque especial: escudo direccional (5 s); su disparo frena 1,5 s | su disparo quita 0,5 en vez de 1; no tiene bola cargada |

## Cómo añadir uno

1. Mete su arte en `assets/<lo que sea>/` con su `SpriteFrames`. Necesita las
   16 animaciones (`caminar_` y `quieto_` por cada una de las ocho
   direcciones), y un PNG suelto de retrato para el menú.
2. Copia uno de estos `.tres`, cámbiale el nombre del archivo por uno que
   empiece por el número que le toque, y rellena los campos.
3. Ya está. Arranca el juego y su ficha sale en «Elegir mago».

## Disparo normal y ataque especial

- `dano_disparo`: lo que quita cada bola normal (1 de siempre; 0,5 el mago
  blanco, que necesita el doble de impactos). El cargado no cambia.
- `frena_disparo`: segundos que deja frenado al enemigo que toca. Frenado,
  anda, apunta y recarga a la mitad, y lleva un aro de escarcha a los pies.
- Los tres disparan una bola cada 0,5 s (`cadencia_disparo` del jugador;
  `cadencia_multiplicador` a 1 en los tres). Los objetos la siguen bajando.
- `ataque_especial`: lo que sale con el clic derecho o el espacio. **Bola
  cargada** (oscuro y rojo) o **Escudo** (blanco). Sea cual sea, **se usa
  una vez por piso** (lo cuenta `Jugador.especial_disponible`; el HUD dice si
  queda). El escudo se saca al pulsar y dura `duracion_escudo` (5 s en el blanco). Es un
  arco pequeño (76°,
  a 30 px) delante del mago, hacia donde mira, que para los disparos enemigos
  de frente. No para lo que le llega de lado o por la espalda, ni el magma del
  gólem (cae desde arriba), ni los golpes de los de cuerpo a cuerpo. Ver
  `scripts/escudo_direccional.gd`.
- `alcance_cargado`: hasta dónde llega la bola cargada, en px (0 = hasta
  chocar, como la del rojo; 320 la del oscuro).
- `agujero_negro`: la bola cargada abre un agujero negro donde se acaba (al
  llegar a su alcance, en una roca o en el muro). Dura `duracion_agujero`
  (2,5 s), atrae a los enemigos de su sala que están a `radio_agujero`
  (150 px) y a los del centro les quita `dano_agujero` (2) por segundo. Ver
  `scripts/agujero_negro.gd`.

## Colores del disparo

Cada mago dispara de su color: el oscuro en azul (y morado el cargado), el rojo
en rojo, el blanco en azul hielo (no tiene cargado). Son cuatro campos, centro y resplandor para cada ataque
(`color_disparo`, `halo_disparo`, `color_cargado`, `halo_cargado`). La bola que
se forma mientras cargas sale de los dos del cargado, así que lo que se forma y
lo que sale al soltar son la misma cosa.

El resplandor se pide aparte en vez de deducirlo del centro con una fórmula. Se
probó, y la fórmula movía el halo del mago oscuro 0,10 en un canal: estaba
ajustado a mano y no había por qué tocarlo.

## Sobre las ventajas

Los campos de ventaja se **suman a los valores de fábrica** del jugador, no se
aplican como un objeto recogido. La diferencia importa: los objetos que se
cogen por los pisos se pierden al empezar otra partida, y lo del mago no, que
es lo que ES ese mago.

Que cada mago tenga también una **pega** no es decoración: si uno fuera mejor a
secas, elegir dejaría de ser una decisión. La pega se enseña en su ficha, al
lado de la ventaja.
