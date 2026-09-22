# Vacío — contexto para Claude

Claude Code lee este archivo al empezar cada sesión. Sirve para no tener que
explicar otra vez qué es el proyecto, cómo se trabaja en él y qué se decidió ya.

**Última actualización: 2026-09-22.**

---

## Qué es

Juego 2D top-down en **Godot 4.7** (GDScript). Se desciende piso a piso por un
embudo: **12 niveles fijos** basados en las capas de la Tierra, de la corteza al
núcleo interno. Cada piso es más estrecho, más denso y se ve menos.

Proyecto de clase (1 DAM). Lo trabajan **3 personas en paralelo**.

- Repo bueno: `origin` → https://github.com/MatiasRodrigo0502/Vacio
- Repo del instituto: `instituto` → https://github.com/matias0502/Vacio
  (se queda atrás a propósito; solo se sube si Matías lo pide)

**Rumbo actual: parecerse a The Binding of Isaac.** Pedido el 2026-09-18 en
cuatro pasos: 1) disparo en cuatro direcciones ✅, 2) enemigos que persiguen ✅,
3) objetos que mejoran ✅, 4) **salas con puertas — pendiente y es el gordo**:
toca rehacer generación de piso, cámara y avance.

## Reglas de este proyecto

1. **Todo en español**: scripts, clases, variables, funciones, nodos y
   comentarios. Sin excepciones.
2. **Los comentarios explican el porqué**, no el qué. Si se descartó una
   alternativa razonable, se dice por qué.
3. **Ampliar el juego no debe tocar código.** Todo lo que se repite vive en
   `.tres`: pisos, catálogos de arte, mecánicas, tipos de enemigo y objetos.
4. **Un archivo por unidad de trabajo**, para que tres personas no se pisen.
5. **Subir a GitHub después de cada cambio terminado**, sin que haga falta
   pedirlo.

## Cómo está montado

| Qué | Dónde | Se amplía |
|---|---|---|
| Dificultad de cada piso | `resources/pisos/piso_NN_*.tres` | editando números |
| Arte de un piso | `assets/<pack>/catalogo_*.tres` + `catalogo_arte` del piso | otro `.tres` |
| Mecánicas | `resources/mecanicas/*.tres` (+ script que herede de `Mecanica`) | otro `.tres` |
| Tipos de enemigo | `resources/enemigos/*.tres` (`TipoEnemigo`) | otro `.tres` |
| Objetos recogibles | `resources/objetos/*.tres` (`ObjetoMejora`) | otro `.tres` |

`GestorProgreso` (autoload) lee las carpetas y no conoce ninguna mecánica,
enemigo ni objeto concreto. `Principal.tscn` solo reacciona a sus señales.

## Cómo verificar los cambios (importante)

Godot **no está en el PATH**. El binario está en:
`C:\Users\Matias\OneDrive - vidalibarraquer.net\Escritorio\Godot_v4.7.2-stable_win64.exe`

Después de tocar scripts o `.tres`, **siempre**:

1. `--headless --path <proyecto> --import` → registra los `class_name` nuevos y
   saca errores de parseo. Un `class_name` nuevo **no existe** hasta reimportar.
2. Una escena de prueba temporal en la raíz (`prueba_temporal.gd/.tscn`, están
   en `.gitignore`) que instancia `Principal.tscn` y comprueba lo que toque.
   Borrarla al terminar, **incluido su `.gd.uid`**, que Godot genera aparte.
3. Capturar stdout **y stderr**: los errores de GDScript van por stderr y, si
   solo se redirige stdout, parecen no existir.

**Capturas de pantalla**: solo desde dentro del juego
(`get_viewport().get_texture().get_image().save_png("user://...")`). Nunca con
`CopyFromScreen` de Windows: copia la región de pantalla y, si el juego no está
delante, captura ventanas privadas del usuario. Ya pasó una vez.

**Verificar con datos antes que con capturas.** Varias veces la pantalla decía
"falta algo" y lo resolvió contar nodos o medir píxeles: las plataformas que no
aparecían (0 sprites con 8 texturas cargadas) y el contraste de las rocas (mi
impresión visual era la contraria a la medición).

Para lanzar el juego: `jugar.bat` en la raíz.

## Estado actual del juego

Arranca en `MenuPrincipal.tscn` (jugar, controles, salir). La partida vive en
`Principal.tscn` y se vuelve al menú desde la pantalla final.

- **Jugador**: nigromante animado, **de frente**. Solo tiene animación de
  andar (6 fotogramas); `quieto` es un único fotograma porque la hoja no
  trae pose de reposo. WASD mueve.
- **Disparo**: flechas (cuatro direcciones) o clic izquierdo apuntando con el
  ratón, con cadencia. Matan enemigos; **no** rompen rocas.
- **Rocas y plataformas**: `StaticBody2D` sólidos. Se choca con ellas, **no
  hacen daño** y paran los disparos, así que sirven de parapeto.
- **Piedras pequeñas**: decoración sin colisión. Treinta chinas sólidas por piso
  harían el movimiento un engancharse continuo.
- **Enemigos**: desde el piso 2, cuatro tipos que persiguen dentro de su radio
  de visión. Son lo único que quita vida.
- **Objetos**: uno por piso, con icono de lo que hacen. Las mejoras se acumulan
  toda la partida y se pierden al empezar otra.
- **Vida**: corazones dibujados por código. La fuente de Godot no tiene glifos
  de corazón ni emoji: un "♥" de texto sale como un cuadradito.
- **Arte por piso**: 1 musgo, 2 cueva con vegetación, 3-12 roca de cueva pelada.
- **Rocas móviles**: hechas pero **desactivadas** (`activa = false` en su
  `.tres`), porque no convencieron al jugarlas. El código sigue ahí.

## Pendiente

- **Paso 4 del rumbo Isaac: salas con puertas.** Lo más grande que queda.
- **Animación del personaje en 4 direcciones.** *Imposible con lo que hay*: ni
  el BlueWizard ni la hoja del nigromante traen más que vistas de frente. Hace
  falta un pack de personaje top-down con 4 direcciones.
- **De dónde sale el nigromante.** Es el único asset sin autor ni origen
  conocidos (ver `CREDITS.md`). Hay que aclararlo.
- **Licencias**: `CREDITS.md` tiene packs, autores y URLs, pero la licencia de
  cada uno está "sin verificar" (no se pudo abrir itch.io desde aquí).
- **Equilibrar la dificultad jugando.** Los 12 `.tres` se pusieron a ojo el
  primer día y el juego ha cambiado mucho desde entonces.
- **Arte de los pisos 3 al 12**, cuando Matías consiga más packs.

## Decisiones tomadas (no deshacerlas sin hablarlo)

- **Las rocas no hacen daño.** Si no se pueden atravesar, cobrar vida además
  castigaría por rozar una pared al esquivar. El daño viene de los enemigos.
- **Los disparos no rompen rocas.** Las rocas son el terreno; si el disparo las
  borra, el piso se limpia desde lejos y esquivar deja de importar.
- **Los enemigos no se tintan con el color del piso**, las rocas sí. Con el
  tinte rojo del piso 12 un slime verde se camuflaba con el suelo.
- **Las plataformas se pintan a la misma luminosidad que las rocas** (factor
  0,6 medido): lo que hace daño o estorba tiene que verse igual.
- **Los niveles son deterministas.** Cada reparto usa una semilla derivada del
  piso, así que los 12 pisos son idénticos en las tres máquinas del equipo.
- **El pack pixel art de Zerie está descartado**: desentona con el arte
  renderizado del resto.
- **El mago BlueWizard se queda en el repositorio** aunque no se use. Cambiar
  de personaje es una línea de `Jugador.tscn`, y así volver atrás es gratis.
- **El sprite del jugador se centra en los pies, no en el dibujo.** El báculo y
  el halo del nigromante sobresalen a la derecha; centrando el lienzo en el
  dibujo, el cuerpo se iría a la izquierda y dejaría de cuadrar con el círculo
  de colisión, que no se ha tocado (radio 15 en y=−16).

## Trampas ya pisadas (no repetirlas)

- **Editar por índices de texto es peligroso.** Dos veces, cortar un bloque de
  `piso.gd` entre dos marcas se llevó funciones que estaban en medio
  (`_al_entrar_en_salida`, `_colocar_tutorial`). Reemplazar bloques exactos y
  comprobar después que la función sigue ahí.
- **Un `replace` que no encuentra su ancla no falla, simplemente no hace nada.**
  Pasó con `rocas_todas()`: se dio por añadida y no estaba. Verificar el
  resultado, no el mensaje de "hecho".
- **Cambiar de piso desde `body_entered` revienta.** Hay que diferirlo
  (`call_deferred`) o el motor se queja de "flushing queries" al destruir los
  cuerpos en mitad del paso de física.
- **Godot avisa de solapamientos con posiciones caducadas.** Como todos los
  pisos se construyen en el origen, la salida del piso nuevo nacía donde estaba
  la del anterior y el juego saltaba del piso 1 al 3. Por eso
  `_al_entrar_en_salida()` comprueba la distancia real. **Y se mide contra
  `centro_colision()`**, no contra el origen del nodo: el origen del jugador
  está a los pies y su círculo 16 px más arriba.
- **El tutorial se monta antes que los obstáculos**, para dejar apuntadas las
  zonas de sus carteles en `_zonas_prohibidas` y que nada tape el texto.
- **Un solo nodo `Decoracion` lo llenan tres funciones** (plataformas,
  decoración suelta y borde). El vaciado se hace **una vez** en `configurar()`.
- **En Python, `\` al final de línea dentro de una cadena normal es continuación
  de línea**: se come la barra y el salto, y rompió una línea de GDScript
  generada desde un script. Los heredoc de bash también se comen barras: para
  scripts con barras, escribir el `.py` a archivo y ejecutarlo.
- **La impresión visual vuelve a fallar con el contraste.** El nigromante
  parecía perderse contra el suelo más que el mago anterior; medido, es al
  revés: 1,81:1 contra 1,55:1. Tercera vez que la medición contradice al ojo.
- **Al cambiar una regla del juego, revisar los textos que la cuentan**: el
  panel de controles del menú y los carteles del tutorial se quedaron diciendo
  que las rocas quitaban vida mucho después de que dejaran de hacerlo.
