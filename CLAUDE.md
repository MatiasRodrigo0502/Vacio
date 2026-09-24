# Vacío — contexto para Claude

Claude Code lee este archivo al empezar cada sesión. Sirve para no tener que
explicar otra vez qué es el proyecto, cómo se trabaja en él y qué se decidió ya.

**Última actualización: 2026-09-24.**

---

## Qué es

Juego 2D top-down en **Godot 4.7** (GDScript). Se desciende piso a piso por un
embudo: **12 niveles fijos** basados en las capas de la Tierra, de la corteza al
núcleo interno. Cada piso es un **mapa de salas unidas por puertas**, y cada uno
tiene más salas, más pequeñas, y se ve menos.

Proyecto de clase (1 DAM). Lo trabajan **3 personas en paralelo**.

- Repo bueno: `origin` → https://github.com/MatiasRodrigo0502/Vacio
- Repo del instituto: `instituto` → https://github.com/matias0502/Vacio
  (se queda atrás a propósito; solo se sube si Matías lo pide)

**Rumbo actual: parecerse a The Binding of Isaac.** Pedido el 2026-09-18 en
cuatro pasos: 1) disparo en cuatro direcciones ✅, 2) enemigos que persiguen ✅,
3) objetos que mejoran ✅, 4) salas con puertas ✅ (2026-09-24). Los cuatro
hechos.

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
| Magos elegibles | `resources/personajes/*.tres` (`PersonajeJugable`) | otro `.tres` |

`GestorProgreso` (autoload) lee las carpetas y no conoce ninguna mecánica,
enemigo ni objeto concreto. `Principal.tscn` solo reacciona a sus señales.

**Cómo se construye un piso con salas** (tres archivos, cada uno a lo suyo):

- `scripts/mapa_salas.gd` (`MapaSalas`, sin nodos): el plano. Qué casillas
  hay, de qué tipo es cada una (inicio, normal, objeto, salida) y dónde hay
  puerta. Se puede probar sin montar ninguna escena.
- `scripts/sala.gd` (`Sala`): una sala se construye sola: suelo, muros con los
  huecos de puerta, un cierre por puerta, sus enemigos y si está cerrada.
- `scripts/piso.gd` (`Piso`): coloca las salas en la cuadrícula, reparte rocas
  y decoración sala por sala, y sigue en qué sala está el jugador. Emite
  `sala_cambiada`, que Principal usa para encajar la cámara.

Las mecánicas reparten lo suyo recorriendo `piso.salas()`.

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

- **Elección de mago**: al pulsar Jugar se elige entre los magos de
  `resources/personajes/`. Cada uno trae su arte y su ventaja, y la ventaja va
  a los valores **de fábrica** del jugador, así que sobrevive a reiniciar. El
  menú monta una ficha por `.tres`, así que un mago nuevo no toca código.
  Cada mago trae también **el color de sus disparos** (centro y resplandor del
  normal y del cargado): el oscuro azul y morado, el rojo en rojo.
- **Jugador**: mago animado **en las ocho direcciones** (las cuatro
  cardinales y las cuatro diagonales), con `caminar_` y `quieto_` por cada una:
  16 animaciones recortadas de un atlas con `AtlasTexture`. WASD mueve.
  Apuntar manda sobre moverse: si disparas a un enemigo, el mago lo mira
  aunque te estés alejando.
- **Disparo**: flechas (cuatro direcciones) o clic izquierdo apuntando con el
  ratón, con cadencia. Matan enemigos; **no** rompen rocas.
- **Ataque cargado**: clic derecho mantenido. Se carga en `tiempo_carga`
  (0,75 s), hay que **soltarlo** para que salga y soltarlo antes de tiempo no
  dispara nada. Atraviesa enemigos y hace 3 de daño; las rocas lo paran igual.
  Mientras cargas, el disparo normal se calla. El aviso visual lo dibuja
  `scripts/carga_ataque.gd` en un nodo aparte del jugador.
- **Salas**: cada piso es un mapa de 4 a 10 salas en cuadrícula, con forma de
  árbol (un solo camino entre dos salas). La salida es la sala más lejana del
  inicio; el objeto va en el callejón más lejano. Al entrar **del todo** en una
  sala con enemigos, sus puertas se cierran (rejas) hasta limpiarla; los
  enemigos duermen hasta entonces. La bajada está tapada hasta limpiar su
  sala. La cámara se encaja en la sala: si cabe se queda quieta, si no se
  mueve dentro. Las bolas se apagan al salir de la casilla de su sala.
- **Minimapa** arriba a la derecha (`scripts/minimapa.gd`): visitadas
  rellenas, vecinas en contorno, objeto y bajada marcados en cuanto se conocen.
- **Rocas y plataformas**: `StaticBody2D` sólidos. Se choca con ellas, **no
  hacen daño** y paran los disparos, así que sirven de parapeto.
- **Piedras pequeñas**: decoración sin colisión. Treinta chinas sólidas por piso
  harían el movimiento un engancharse continuo.
- **Enemigos**: desde el piso 2, cuatro tipos que persiguen dentro de su radio
  de visión, de 1 a 4 por sala de pelea. Son lo único que quita vida.
- **Objetos**: uno por piso, en el centro de su sala, con icono de lo que hacen. Las mejoras se acumulan
  toda la partida y se pierden al empezar otra.
- **Vida**: corazones dibujados por código. La fuente de Godot no tiene glifos
  de corazón ni emoji: un "♥" de texto sale como un cuadradito.
- **Arte por piso**: 1 musgo, 2 cueva con vegetación, 3-12 roca de cueva pelada.
- **Rocas móviles**: hechas pero **desactivadas** (`activa = false` en su
  `.tres`), porque no convencieron al jugarlas. El código sigue ahí.

## Pendiente

- **De dónde salen las hojas del personaje.** Ni la del nigromante ni la del
  mago de 4 direcciones traen autor ni origen (ver `CREDITS.md`). Son los
  únicos assets así. Hay que aclararlo antes de entregar o publicar.
- **Contraste del mago oscuro: 1,66:1** contra el suelo. Mejor que el mago
  morado al que sustituye (1,40:1), por debajo del nigromante (1,81:1).
- **Limpiar las carpetas de personajes.** Ya son cuatro: `mago_oscuro/` en uso
  y `mago/`, `nigromante/` y `personaje/` muertas. Borrar las tres muertas en
  cuanto Matías lo confirme; el historial de git las conserva.
- **Licencias**: `CREDITS.md` tiene packs, autores y URLs, pero la licencia de
  cada uno está "sin verificar" (no se pudo abrir itch.io desde aquí).
- **Equilibrar la dificultad jugando.** Los 12 `.tres` se pusieron a ojo el
  primer día y el juego ha cambiado mucho desde entonces. Ojo sobre todo a los
  enemigos: con salas, el total por piso ha pasado de 2-9 a 4-28 (de 1 a 4 por
  sala de pelea). Nadie lo ha jugado entero todavía.
- **Posibles mejoras de las salas**, no pedidas: oscurecer las salas vecinas
  (cuando la vista es más ancha o más alta que la sala, se asoma un trozo de
  las de al lado), una sala de jefe en el piso 12, y salas de otras formas.
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
- **El mapa de salas es un árbol.** Una casilla nueva solo se acepta si toca a
  una sola sala: sale ramificado, con callejones, y entre dos salas hay un solo
  camino. Los callejones son los que dan sitio a la sala del objeto.
- **La salida es la sala más lejana y el objeto va en un callejón.** Así hay
  que cruzar el piso para bajar, y coger el objeto es desviarse a propósito.
- **Todas las salas de un piso miden lo mismo** (`ancho_area` × `alto_area`).
  Es lo que las deja encajar en la cuadrícula muro con muro, sin huecos.
- **Los enemigos duermen hasta que entras en su sala.** Son `Area2D` que van
  directos al jugador sin chocar con nada; despiertos, los de la sala de al
  lado cruzaban el muro para perseguirte.
- **Las puertas se cierran al entrar DEL TODO, no al cruzar el umbral.** La
  cámara cambia de sala a mitad del pasillo, pero el cierre espera a que el
  jugador esté dentro con margen (`MARGEN_ENTRAR`), o nacería encima de él.
- **Las bolas no salen de la casilla de su sala.** Si no, por una puerta
  abierta matarían enemigos de la sala de al lado que ni has visto.
- **La cámara se encaja en la sala; los radios de visión no se han tocado.**
  Pisos 1-4: la sala cabe entera y la cámara se queda quieta. 5-8: cabe el
  suelo, no los muros. 9-12: ni el suelo (en el 12 se ve el 80 % del alto).
  Medido con la ventana de 1152×648.
- **La ventaja de un mago se suma a los valores de fábrica, no se aplica como
  un objeto recogido.** `restaurar_vida()` vuelve a esos valores al empezar
  otra partida: si la ventaja fuera un objeto del piso, el mago perdería lo
  suyo al reiniciar.
- **El resplandor de las bolas se declara, no se deduce.** Una fórmula que
  sacaba el halo del color del centro movía el del mago oscuro 0,10 en un
  canal, y ese estaba ajustado a mano. Dos colores por ataque y cada mago queda
  exactamente como se quiere.
- **Cada mago tiene también una pega, y se enseña.** Si uno fuera mejor a
  secas, elegir dejaría de ser una decisión.
- **El mago se gira por ángulo, no comparando x contra y.** Con cuatro
  direcciones bastaba un `if`; con ocho, la misma idea sería una escalera de
  comparaciones. `_lado()` redondea el ángulo al sector de 45° más cercano y
  `LADOS` da el nombre. `_vector_de()` es la vuelta, girando `Vector2.RIGHT`.
- **El pixel art se mueve en píxeles enteros y se dibuja a escala 1.** El atlas
  del mago oscuro es pixel art de verdad (64×72): centrar cada dirección se
  hizo desplazando un número entero de píxeles, y la escena lo dibuja sin
  escalar. Un decimal en cualquiera de los dos sitios emborrona los bordes.
- **La izquierda del mago morado (fuera de uso) era la derecha reflejada.** Las dos filas de lado de
  la hoja son la misma pose y las dos miran a la derecha, aunque una se
  rotule «izquierda». Reflejar garantiza el par.
- **Andar hacia arriba tiene tres poses y no cuatro**: el fotograma «arriba 3»
  de la hoja trae dos báculos. Esa animación va a 7,5 fps en vez de 10 para
  que el ciclo dure lo mismo (0,4 s) y el paso no se acelere.
- **El ataque cargado hay que soltarlo, no sale solo al cargarse.** Soltándolo
  tú eliges el momento y puedes reapuntar mientras cargas. Si saliera solo,
  cargar sería una cuenta atrás a la que llegas apuntando a donde sea. Cambiarlo
  es una línea en `_actualizar_carga()`.
- **Soltar el cargado antes de tiempo no dispara nada.** Un disparo flojo se
  confundiría con el normal y no se sabría por qué sale una cosa u otra.
- **El daño del cargado se reparte llamando `romper()` varias veces**, no
  pasándole un parámetro: el contrato del proyecto es `romper()` sin argumentos,
  y cambiarlo obligaría a tocar todo lo rompible, ahora y en el futuro.
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
- **Que dos poses sean espejo no dice cuál es cuál, y la cara tampoco siempre.**
  Con el mago rojo, el desvío de la barba daba las diagonales invertidas porque
  el detector cazaba también la bolsa gris del cinturón. Lo que sí lo resuelve
  es comparar cada diagonal con los perfiles ya confirmados: 94 % con su lado
  contra 69 % con el contrario. **Dos medidas independientes o ninguna.**
- **El eje de los pies también se mide por dirección.** En el atlas del mago
  oscuro estaba a 23,7 px mirando a la derecha y a 39,3 mirando a la izquierda:
  el mago se corría 15 px de lado al girarse. Y se mide sobre las **botas**
  (alfa ≥ 230 en las filas de abajo), no sobre toda la silueta: la sombra es
  más ancha que los pies y arrastra el eje.
- **La línea de suelo de una hoja se mide por dirección, no para toda.** Cada
  fila de la hoja del mago tenía al personaje a una altura distinta dentro de
  su casilla; con una sola referencia, el mago pegaba un salto vertical al
  girarse. Y se mide sobre píxeles sólidos (alfa alto y anchura de bota), no
  sobre la caja del alfa: debajo de los pies hay restos de sombra suave. La
  señal de que la referencia es buena es que las cuatro direcciones midan lo
  mismo de alto.
- **Comprobar que dos poses son iguales no dice a dónde miran.** Con el mago
  medí que las filas «izquierda» y «derecha» eran la misma pose, di por bueno
  el rótulo y reflejé al revés: el mago andaba de espaldas al ir a la derecha,
  y lo pilló Matías jugando. La medida que sí lo resuelve es dónde cae la piel
  de la cara respecto al centro de la cabeza, con la vista frontal de
  referencia. **Los rótulos de una hoja de sprites son una pista, no un dato.**
- **La impresión visual vuelve a fallar con el contraste.** El nigromante
  parecía perderse contra el suelo más que el mago anterior; medido, es al
  revés: 1,81:1 contra 1,55:1. Tercera vez que la medición contradice al ojo.
- **Un error de script en la escena de prueba la deja colgada**, no la hace
  fallar: `_ready()` se corta antes del `quit()` y el proceso se queda ahí sin
  decir nada (pasó llamando a `configurar()` en vez de `preparar()`). Vale la
  pena meterle un `Timer` de vigía que llame a `quit()` pase lo que pase.
- **Una afirmación en un comentario también se comprueba.** Escribí que la
  fórmula del halo reproducía los colores de antes; el test lo desmintió. Si un
  comentario dice «da lo mismo que antes», el test tiene que medirlo.
- **Los números de un texto se calculan antes de escribirlos.** Al documentar
  las salas escribí de memoria «la sala cabe entera hasta el piso 7» y «en el
  12 se ve media sala»; calculado, era hasta el 4 y el 80 %. Igual que con los
  comentarios: si un texto da un número, sale de una medida.
- **Al cambiar una regla del juego, revisar los textos que la cuentan**: el
  panel de controles del menú y los carteles del tutorial se quedaron diciendo
  que las rocas quitaban vida mucho después de que dejaran de hacerlo.
