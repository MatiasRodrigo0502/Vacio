# assets/

Arte del juego. Aquí entra **solo lo que se usa**, ya recortado y reescalado;
los packs originales viven fuera del repositorio (ver `CREDITS.md` en la raíz).

## personaje/

El mago jugable (BlueWizard). 40 PNG de 73×128:

- `quieto_00..19.png` — animación de reposo
- `caminar_00..19.png` — animación de andar
- `animaciones_mago.tres` — el `SpriteFrames` que las agrupa, con sus
  velocidades. Es lo que carga `Jugador.tscn`.

Los frames originales eran de 512×512 con el personaje ocupando solo 160×280
en el centro: un 83% del archivo era transparencia. Recortarlos a la caja común
de las tres animaciones (la misma para todas, o el personaje daría saltos al
cambiar de animación) bajó el conjunto de 4,1 MB a 441 KB.

**Tamaño en pantalla**: el sprite se dibuja a escala 0,5 desde `Jugador.tscn`,
o sea 64 px de alto, y el origen del nodo está a los pies. Si quieres el mago
más grande o más pequeño, cambia esa escala en la escena; la forma de colisión
es independiente y está aparte (círculo de radio 15 sobre la base de la túnica).

Nota sobre `.gitignore`: los `*.import` no se versionan, los regenera Godot al
abrir el proyecto.
