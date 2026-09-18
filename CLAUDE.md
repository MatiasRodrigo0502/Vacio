# Vacío — contexto para Claude

Este archivo lo lee Claude Code al empezar cada sesión. Sirve para no tener que
explicar otra vez qué es el proyecto ni cómo se trabaja en él.

**Última actualización: 2026-09-18.**

## Qué es

Juego 2D top-down de habilidad en **Godot 4.7** (GDScript). Se desciende piso a
piso por un embudo: 12 niveles fijos basados en las capas de la Tierra, de la
corteza al núcleo interno. Cada piso es más estrecho, más denso y se ve menos.
Proyecto de clase (1 DAM), lo trabajan **3 personas en paralelo**.

Repo bueno: `origin` → https://github.com/MatiasRodrigo0502/Vacio
Repo del instituto: `instituto` → https://github.com/matias0502/Vacio (se queda
atrás a propósito; solo se sube si Matías lo pide).

## Reglas de este proyecto

1. **Todo en español**: nombres de scripts, clases, variables, funciones, nodos
   y comentarios. Sin excepciones.
2. **Los comentarios explican el porqué**, no el qué. Si una decisión tiene una
   alternativa razonable que se descartó, se dice por qué se descartó.
3. **Ampliar el juego no debe tocar código.** La dificultad vive en
   `resources/pisos/*.tres` (uno por piso) y el arte en `assets/<pack>/
   catalogo_*.tres`. Añadir mecánicas = un script que herede de `Mecanica` + su
   `.tres`, sin tocar `gestor_progreso.gd` ni `piso.gd`.
4. **Un archivo por unidad de trabajo**, para que tres personas no se pisen: un
   piso = un `.tres`, una mecánica = un `.tres`.

## Cómo verificar los cambios (importante)

Godot **no está en el PATH**. El binario está en:
`C:\Users\Matias\OneDrive - vidalibarraquer.net\Escritorio\Godot_v4.7.2-stable_win64.exe`

Después de tocar scripts o `.tres`, **siempre**:

1. `--headless --path <proyecto> --import` → registra los `class_name` nuevos y
   saca los errores de parseo. Un `class_name` nuevo NO existe hasta que se
   reimporta.
2. Una escena de prueba temporal en la raíz (`prueba_temporal.gd/.tscn`, están
   en `.gitignore`) que instancia `Principal.tscn`, recorre los 12 pisos e
   imprime lo que haya que comprobar. Borrarla al terminar, **incluido su
   `.gd.uid`**, que Godot genera aparte.
3. Capturar stdout **y stderr**: los errores de GDScript van por stderr, y si
   solo se redirige stdout parecen no existir.

**Capturas de pantalla**: solo desde dentro del juego
(`get_viewport().get_texture().get_image().save_png("user://...")`). Nunca con
`CopyFromScreen` de Windows: copia la región de pantalla, y si el juego no está
delante acaba capturando ventanas privadas del usuario. Ya pasó una vez.

**Verificar con datos antes que con capturas.** Varias veces la pantalla decía
"falta algo" y lo que lo resolvió fue contar nodos o medir píxeles. Ejemplos
reales: las plataformas que no aparecían (había 0 sprites con 8 texturas
cargadas) y el contraste de las rocas (mi impresión visual era la contraria a
lo que decía la medición).

## Estado actual

Fase 1 cerrada y jugable: movimiento con inercia, vida con invulnerabilidad,
cámara con zoom por piso, los 12 pisos, victoria y derrota, pooling de
obstáculos. El jugador es el mago (BlueWizard) animado. Los obstáculos son
rocas y plataformas (las dos cosas quitan vida), con vegetación encima de las
plataformas y un borde de roca alrededor del área. El piso 1 enseña los
controles con carteles sobre el suelo. La vida se muestra con corazones
dibujados por código: la fuente de Godot no tiene glifos de corazón ni emoji,
así que un "♥" de texto saldría como un cuadradito.

Arte por piso: piso 1 musgo (superficie), piso 2 cueva con vegetación, pisos
3-12 roca de cueva pelada (esperando packs).

## Pendiente

- **Licencias**: `CREDITS.md` tiene los packs, autores y URLs, pero la licencia
  de cada uno está "sin verificar". No se pudo abrir itch.io desde aquí.
- **Equilibrar la dificultad jugando**. Los valores de los 12 `.tres` se
  pusieron a ojo el primer día y nadie los ha jugado del tirón.
- **Fase 2**: obstáculos móviles. Los slimes del pack Mossy Cavern encajan
  (están dibujados de frente, como el mago) y `velocidad_obstaculos` ya viaja
  hasta cada obstáculo esperando eso.
- Arte de los pisos 3 al 12 cuando Matías consiga más packs.

## Trampas ya pisadas (no repetirlas)

- **Editar por índices de texto es peligroso.** Dos veces, cortar un bloque de
  `piso.gd` entre dos marcas se llevó por delante funciones que estaban en
  medio (`_al_entrar_en_salida`, `_colocar_tutorial`). Reemplazar por bloques
  exactos y comprobar después que la función sigue ahí.
- **Un `replace` que no encuentra su ancla no falla, simplemente no hace nada.**
  Pasó con `rocas_todas()`: se dio por añadida y no estaba. Verificar siempre
  el resultado, no el mensaje de "hecho".
- **Cambiar de piso desde `body_entered` revienta.** Hay que diferirlo
  (`call_deferred`), o el motor se queja de "flushing queries" al destruir los
  cuerpos en mitad del paso de física.
- **En Python, `\` al final de línea dentro de una cadena normal es continuación
  de línea**: se come la barra y el salto. Rompió una línea de GDScript al
  generarla desde un script.
- **Godot avisa de solapamientos con posiciones caducadas.** `body_entered`
  puede llegar con la posición que el cuerpo tenía al empezar el paso de física,
  no la que ya tiene. Como todos los pisos se construyen en el origen, la salida
  del piso nuevo nacía donde estaba la del anterior y el juego saltaba del piso
  1 al 3. Lo mismo con las rocas recicladas: golpes fantasma al entrar en un
  piso. Por eso tanto `_al_entrar_en_salida()` como `_al_entrar_cuerpo()`
  comprueban la distancia real antes de hacer nada. No quitar esas
  comprobaciones.
- Un solo nodo `Decoracion` lo llenan tres funciones (plataformas, decoración
  suelta y borde). El vaciado se hace **una vez** en `configurar()`. Si alguna
  vuelve a vaciarlo, borra el trabajo de las anteriores.
