# resources/skins/

Un `.tres` por skin (`SkinMago`, `scripts/skin_mago.gd`). `Coleccion` lee esta carpeta
y el gacha de monedas las reparte según su `tier` (0 B, 1 A, 2 S, 3 S+): una skin nueva
es un `.tres` más, y sale sola.

Las de ahora las saca `herramientas/generar_skins.py` del dibujo vectorial de cada mago
(`magos_vectorial.py`), una de cada tier, cada una una clase: **para cambiar una, se
cambia allí y se vuelve a ejecutar** (lo que se toque aquí a mano se pierde). Si llega
una dibujada a mano, basta con apuntar su `.tres` a su arte: su `SpriteFrames` necesita
las 16 animaciones de los magos. `mago` es su `PersonajeJugable.nombre`. `aura`, el
color del aura a los pies (`AuraSkin`; transparente, sin aura), y `arcoiris`, que
cambie de color sin parar. `descripcion` es la frase de su ficha y `giro`, una tira con
las 8 direcciones (casillas cuadradas, en el orden de `Jugador.LADOS`) que la ficha y la
cinemática del gacha hacen girar; sin ella se enseña el `retrato`.

| Tier | Qué trae |
|---|---|
| B | otro tono |
| A | otra paleta y un efecto suyo |
| S | un traje con piezas propias, y resplandor |
| S+ | piezas grandes (alas, planetas, arcos de luz), aura de arcoíris y en dos un brillo iridiscente |

Solo cambian el aspecto, no cómo juega el mago.
