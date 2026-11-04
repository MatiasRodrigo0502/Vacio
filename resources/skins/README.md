# resources/skins/

Un `.tres` por skin (`SkinMago`, `scripts/skin_mago.gd`). `Coleccion` lee esta carpeta
y el gacha de monedas las reparte según su `tier` (0 B, 1 A, 2 S, 3 S+): una skin nueva
es un `.tres` más, y sale sola.

Las de ahora las saca `herramientas/generar_skins.py` del arte de cada mago, una de
cada tier. Si llega una dibujada a mano, basta con apuntar su `.tres` a su arte: su
`SpriteFrames` necesita las 16 animaciones de los magos. `mago` es su
`PersonajeJugable.nombre`. `aura`, el color del aura a los pies (`AuraSkin`;
transparente, sin aura), y `arcoiris`, que cambie de color sin parar.

Solo cambian el aspecto, no cómo juega el mago.
