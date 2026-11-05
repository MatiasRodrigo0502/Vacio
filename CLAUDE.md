# Vacío — contexto para Claude

Claude Code lee este archivo al empezar cada sesión. Sirve para no tener que
explicar otra vez qué es el proyecto, cómo se trabaja en él y qué se decidió ya.

**Última actualización: 2026-11-04.**

---

## Qué es

Juego 2D top-down en **Godot 4.7** (GDScript). Se desciende piso a piso por un
embudo: **12 niveles fijos** basados en las capas de la Tierra, de la corteza al
núcleo interno. Cada piso es un **mapa de salas unidas por puertas**, y cada uno
tiene más salas, y más llenas. Todas las salas miden lo mismo en todos los
pisos (desde el 2026-11-03; antes encogían) y la cámara ve lo mismo en todos
(desde el 2026-10-22; antes se acercaba al bajar).

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
| Arte de los enemigos y el jefe | `herramientas/generar_enemigos.py`, de `_assets_origen/vacio_completo/enemigos/` (fuera del repositorio) → `assets/criaturas/` | cambiar sus tablas y volver a ejecutarlo |
| Proyectiles enemigos | `resources/proyectiles/*.tres` (`TipoProyectil`) | otro `.tres` |
| Cómo se mueve y ataca cada enemigo | `scripts/comportamientos/*.gd` (`ComportamientoEnemigo`), dentro del `.tres` del enemigo como `comportamiento` | números en el `.tres`; uno nuevo, otro script en esa carpeta |
| Peligros del suelo | `resources/mecanicas/peligros.tres` + `scripts/{pinchos,lava,vacio}.gd` | números en el `.tres`; un peligro nuevo, un script que herede de `Peligro` |
| Objetos recogibles | `resources/objetos/*.tres` (`ObjetoMejora`) | otro `.tres` |
| Magos elegibles | `resources/personajes/*.tres` (`PersonajeJugable`) | otro `.tres` |
| Skins (gacha de monedas) | `herramientas/generar_skins.py` → `assets/skins/<id>/` + `resources/skins/<id>.tres` (`SkinMago`) | otro `.tres`, o una receta más en el script |
| Armas (gacha de diamantes) | `herramientas/generar_armas.py` (la tabla `ARMAS`) → `assets/armas/` + `resources/armas/*.tres` (`ArmaMago`, con sus `ModoArma`) | una entrada más en la tabla |
| Precios y probabilidades de los gachas | `resources/gacha/{skins,armas}.tres` (`TiradaGacha`) | editando números |
| Monedas y diamantes de cada enemigo | `monedas` y `diamantes` en su `.tres` (`TipoEnemigo`) | editando números |
| Arte de los magos y sus hechizos | `herramientas/generar_magos.py`, de `assets/magos_fuente/` → `assets/mago_<color>/` (atlas, retrato y `hechizos/`, con un `ArteHechizo` por hechizo), y `arte_disparo`/`arte_especial` en el `.tres` del mago | cambiar las tablas del script y volver a ejecutarlo |
| Rocas de dentro, una por piso | `herramientas/generar_rocas.py` → `assets/rocas/piso_NN/` (+ `catalogo.tres`, al que apunta el `.tres` del piso) | cambiar el piso en `ROCAS` y volver a ejecutarlo |
| Pack de arte del núcleo (ya sin usar) | `herramientas/generar_nucleo.py` → `assets/nucleo/` | editar el script y volver a ejecutarlo |
| Pared de las salas, una por piso | `herramientas/generar_bordes.py` → `assets/bordes/piso_NN/` (texturas + `estilo_borde.tres`), y `estilo_borde` en el `.tres` del piso | cambiar el tema del piso en `TEMAS` y volver a ejecutarlo |
| Arte de lava, pinchos y vacío | `herramientas/generar_peligros.py` → `assets/peligros/` (+ `shaders/lava.gdshader`) | editar el script y volver a ejecutarlo |

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

**Los ejecutables, `build/Vacio.exe` (Windows) y `build/Vacio.x86_64`
(Linux), se rehacen solos** tras cada commit y cada
pull (`.githooks/post-commit` y `post-merge` → `herramientas/exportar.sh`, en
segundo plano, ~15 s). No hay que hacer nada después de commitear; si falla, el
motivo está en `build/exportar.log` y el `.exe` anterior se queda. En este
ordenador ya están las plantillas de Windows y Linux y `core.hooksPath`.
Los sistemas que se exportan están en la lista `SISTEMAS` de
`exportar.sh`; si uno falla, los demás se exportan igual. `build/` lleva un
`.gdignore` (lo crea el script): las capturas que se dejaban ahí acababan
dentro del `.exe` (+5 MB).

**En GitHub, cada push a `main` que cambia el juego es una versión nueva**
(pedido por Matías el 2026-10-08): `.github/workflows/publicar.yml` elige el
número (la última etiqueta `v0.N` más uno; la primera, la 0.1), exporta con
`VERSION_JUEGO` y publica la release «Versión 0.N» con los dos archivos y los
commits desde la anterior. Si el commit ya tiene versión (relanzado a mano),
no publica otra. El número va dentro del juego (`version.txt`, ignorado por
git, metido en el `.exe` con `include_filter`) y el menú lo enseña
(`GestorProgreso.version_juego()`); el `.exe` local pone «0.N + cambios
(commit)» si no es justo una versión. Lo hace todo en Linux, con los mismos
scripts de `herramientas/`. Antes de publicar
arranca la versión de Linux sin ventana y para si hay errores: es la única
prueba del binario de Linux, porque en este ordenador no hay WSL. No hay que
hacer nada tras el push. Comprobado el 2026-10-08 que se actualiza bien. Si
falla, el registro sale en la pestaña Actions. `gh` no tiene sesión iniciada en
este ordenador: el estado de las ejecuciones se mira con la API pública
(`curl https://api.github.com/repos/MatiasRodrigo0502/Vacio/actions/runs`).
**Sin sesión, la API deja 60 consultas por hora**: preguntarle cada 20 s
durante varias versiones seguidas la agotó (2026-10-14). Para esperar a que
salga una versión, mejor `git ls-remote --tags origin 'v0.*'`, que no cuenta:
la etiqueta solo aparece cuando la release ya está publicada.

**Versión de Mac** (2026-10-13, pedida por Matías): `Vacio-mac.zip` con
`Vacio.app` universal (chip de Apple e Intel), preset «macOS» de
`export_presets.cfg`. **Solo la saca GitHub**: `instalar_plantillas.py --mac`
y `EXPORTAR_MAC=1` en el workflow; los hooks locales siguen con Windows y
Linux. El workflow tiene tres trabajos: `exportar` (Linux), `probar-mac`
(un `macos-latest` de GitHub: firma ad-hoc, `lipo` con arm64 y x86_64 y
arranque sin ventana sin errores) y `publicar`, que solo corre si los dos
anteriores salen bien. Firma **ad-hoc** (`codesign/codesign=1`, la gratuita):
sin firma, los Mac con chip de Apple no la abren; sin notarizar (99 €/año),
la primera vez hay que darle a *Abrir igualmente* en Privacidad y seguridad.
Nadie del equipo la ha probado con ventana en un Mac todavía.

Para probar algo **dentro del `.exe` exportado** (no en el editor): exportar a
otra carpeta y dejar al lado un `override.cfg` con
`[application] run/main_scene="res://<escena de prueba>.tscn"`. Los binarios
exportados no aceptan una escena por la línea de comandos. La escena de prueba
no puede llamarse `prueba_temporal.*`: el preset la excluye.

## Estado actual del juego

Arranca en `MenuPrincipal.tscn` (jugar, controles, salir). La partida vive en
`Principal.tscn` y se vuelve al menú desde la pantalla final.

- **El Corazón del Núcleo, jefe del piso 12** (2026-11-04, lo trajo Matías en
  `vacio_completo.zip`, en lugar del Mago Caído, el cuarto mago negro y oro de
  antes). Es un `TipoEnemigo` con `jefe = true` en
  `resources/jefes/corazon_nucleo.tres` (no en `resources/enemigos/`, que se reparte
  al azar) y lo pone el piso (`DatosPiso.jefe`, en `Piso._preparar_jefe`). Su pelea es
  `scripts/comportamientos/corazon_nucleo.gd`: **se quedó la del Mago Caído**, que es
  lo que Matías fue pidiendo («las habilidades de los otros magos», «más difícil» el
  2026-10-21, el aliento el 2026-11-03), **y se le añadió la del paquete**, que sola
  sería un jefe mucho más fácil. Lo que cambia: dispara **bolas de magma** con arte
  (`proyectiles/bola_nucleo.tres`, abanico de 1, 3 y 5, `bolas_por_fase`) en vez de
  rayos, y la **nova** en las tres fases (acción `nova`: 0,9 s de aviso con un aro,
  `_soltar_nova`: onda desde su sombra con `MundoRed.crear_onda` y anillo de 8 bolas;
  `atacar` empieza 0,4 s antes para que la onda del dibujo salga a la vez). La furia
  del paquete no: ya acelera en cada fase. **Falta que Matías diga si quiere otra
  cosa.** Lo demás sigue igual: tres fases por vida (agujero negro al revés,
  `PozoVacio`; escudo con anillos de esquirlas de hielo; rayo de fuego cargado que deja
  charcos y rompe el pilar que lo para, con `Escombros`), y el aliento de fuego
  (`AlientoFuego`, `scripts/aliento_fuego.gd`, por `MundoRed.crear_aliento`: aviso de
  0,6 s, sale a ±10° y gira 90° en 2 s, quita 15 y quema con `Jugador.quemar`). Sus
  efectos van en oro (`COLOR_ORO`). Solo `atacar` en la nova: con cada disparo parecería
  una (`Enemigo.pelear_a_distancia` no la pone si es jefe). Todo detallado en
  `resources/jefes/README.md`. Para el jefe, `ComportamientoEnemigo` ganó
  `invulnerable`/`bloqueado` (la bola se gasta sin quitar vida), `voltear`,
  `marcas_vida` y `al_morir`, y `Enemigo` `fraccion_vida`, `es_invulnerable` y un
  segundo proyectil en `disparar_hacia`. Barra de vida y presentación:
  `scripts/barra_jefe.gd`, en el HUD, que pone Principal cuando se cierran las puertas
  (`Sala.pelea_empezada`), con su música (`DatosPiso.musica_jefe`, `jefe.wav`). Tiene
  **1500 de vida** y 3,5 s entre habilidades. Probado sin ventana: todas las
  habilidades, las fases, el abanico de 5, su muerte y el botín; y capturas. **Las
  medidas de dificultad del README son de antes de cambiar los rayos por bolas. Nadie
  lo ha jugado.**
- **Sala del jefe del piso 12** (2026-10-13, pedida por Matías). Con `DatosPiso.sala_jefe`, `MapaSalas` cuelga de
  la sala más lejana (o de la siguiente, si no cabe) una **antesala** y detrás
  la sala del **jefe** (`Tipo.ANTESALA` y `Tipo.JEFE`; con jefe no hay
  `SALIDA`). La del jefe mide `tamano_sala_jefe` (1600 × 860 desde el
  2026-11-03, lo justo para caber en pantalla sin alejar la cámara; antes
  1200 × 700) y tapa varias
  casillas: las demás quedan reservadas (`casillas_del_jefe`) y todas apuntan
  a ella en `Piso.sala_en`. Va centrada en el eje de la antesala, con el muro
  pegado al suyo (`Piso._posicion_jefe`), para que las dos puertas queden
  enfrente. La bajada está en la del jefe: **para la sala con bajada, usar
  `Piso.sala_bajada()` y `Sala.tiene_bajada()`, nunca `Tipo.SALIDA`**.
  Antesala: altar que recarga el especial al pisarlo
  (`scripts/altar_especial.gd`) y un vendaje (`DatosPiso.objeto_antesala`). Puerta con runas a los dos lados
  (`runas_puerta.gd`, signos en `runas.gd`), sello en el suelo del jefe
  (`sello_jefe.gd`), cuatro pilares simétricos (`Piso._pilares_jefe`) y la
  cámara abierta para verla entera (`CamaraJuego.ver_entera`, desde
  `Principal._al_cambiar_sala`; solo abre, nunca acerca: con la vista de
  todos los pisos ya cabe). Minimapa: de su tamaño (`Piso.casillas_de`)
  y con una estrella roja. Ni enemigos ni peligros: `admite_enemigos()` es
  false en las dos.

- **Registro de partidas** (2026-10-13, pedido por Matías para equilibrar
  con datos): `RegistroPartida` (`scripts/registro_partida.gd`), un nodo que
  crea Principal, guarda cada partida en `user://partidas/partida_<fecha>.json`
  y la reescribe en cada piso (si el juego se cierra de golpe, lo jugado se
  queda). Por piso: tiempo, vida al entrar y al salir, cada golpe (segundo,
  sala, `por`, vida), vida recuperada, objetos, especial, disparos, enemigos
  muertos y cada pelea de sala (enemigos, tiempo, golpes). Por partida: mago,
  versión, resultado (`victoria`, `derrota`, `reiniciada`, `abandonada`),
  qué mató y `trucos` si se usó un atajo (`AtajosPrueba.usado`). El origen de
  cada golpe lo pasa quien lo da como tercer argumento de
  `Jugador.recibir_dano(cantidad, forzar, origen)` y sale en la señal
  `golpeado` («Murciélago de la corteza», «Vigía del manto (esquirla)», «Gólem del
  núcleo (golpe)», «Corazón del Núcleo (nova)», «Lava», «Pinchos», «Caída al vacío»).
  **Lo nuevo que quite vida tiene que pasar su origen**, o saldrá como
  «desconocido». Las peleas las marca `Sala.pelea_empezada`. El resumen de
  todos los archivos, `herramientas/analizar_partidas.py`. Botón *Abrir la
  carpeta de partidas* en la pausa y en la pantalla final.

- **Aviso de versión nueva y actualización desde el juego** (2026-10-13,
  pedido por Matías). El autoload `Actualizacion` (`scripts/actualizacion.gd`)
  pregunta al abrir el juego por las releases (API pública de GitHub, sin
  sesión) y la portada lo enseña abajo a la derecha
  (`scenes/AvisoActualizacion.tscn`), con lo que cambia en todas las versiones
  saltadas (lo lee de la lista «### Qué cambia» de las notas que escribe
  `publicar.yml`). En Windows baja el `Vacio.exe` nuevo al lado
  (`Vacio.exe.descarga`), comprueba tamaño y que empiece por `MZ`, renombra el
  abierto a `Vacio.viejo.<hora>.exe` y pone el nuevo en su sitio; *Abrirla
  ahora* lo lanza (`OS.create_process`) y cierra por `Sonido.salir()`. El
  siguiente arranque borra los viejos. Probado de punta a punta con un `.exe` exportado que decía ser la
  0.16: encontró la 0.17, la bajó (48 s, lo mismo que `curl` con esta
  conexión), se cambió y se abrió. **Desde el 2026-11-03 también en Linux y
  en Mac** (Matías: «que le pudiese dar a Actualizar en vez de un botón que
  me lleva a GitHub»): cada sistema baja su archivo de la release
  (`Actualizacion.archivo_de_aqui`, comprueba que empiece por `1F 8B` o `PK`)
  y lo saca en otro hilo (estado `INSTALANDO`, unos 2,5 s) con
  `Desempaquetar` (`scripts/desempaquetar.gd`): en Linux, `Vacio.x86_64`
  del `.tar.gz` (gzip con `decompress_dynamic`; el tar, que Godot no lee, a
  mano) con permiso 755; en Mac, la `Vacio.app` entera del `.zip` con
  `ZIPReader`, dando permiso de ejecutarse a `Contents/MacOS/`. Luego lo
  mismo que en Windows (`poner_en_su_sitio`: renombrar lo abierto a
  `.viejo.<hora>` y lo nuevo a su sitio); en Mac lo que se cambia es la
  carpeta `.app` y se abre con `open -n`. **En Mac, abierta sin moverla de
  donde se descomprimió**, macOS la abre desde una copia de solo lectura
  (ruta con `/AppTranslocation/`): ahí no se puede, y el aviso dice que se
  mueva a Aplicaciones (`por_que_no`). Probado aquí lo que se puede sin
  esos sistemas: sacar del `.tar.gz` el ejecutable de Linux de verdad
  (idéntico byte a byte, en formato GNU y PAX), sacar una `.app` de prueba
  del `.zip`, los cambios de nombre con archivo y con carpeta, la limpieza,
  los paquetes rotos y que en Windows sigue igual. **Nadie lo ha probado
  todavía en un Linux ni en un Mac.** Ojo: GDScript no tiene números en
  octal (`0o755` no compila): el permiso va en binario.

- **Portada del menú** (2026-10-14, la trajo Matías): la ilustración
  «Los tres Magos de Vacío: El Bosque Ancestral»
  (`assets/portada/portada.jpg`, 1416 × 752) a pantalla completa, recortada
  para cubrirla sin deformarse (`stretch_mode` 6). Ya trae el título y los
  tres magos, así que los botones van abajo en fila, sobre una sombra
  degradada, el volumen abajo a la izquierda (barras más estrechas,
  `ControlVolumen.ancho_barra = 150`) y la versión abajo a la derecha. El
  aviso de versión nueva sube encima de los botones. **Sustituye** al título
  de piedra en pixel art y a los magos flotando del 2026-10-09
  (`assets/titulo/` y `generar_titulo.py` siguen ahí, sin usar; el código que
  los montaba está en el historial de git).

- **Sonido y música** (2026-10-09, pedido por Matías), todo generado por
  síntesis: `herramientas/sintesis.py` (osciladores, filtros, eco,
  reverberación, WAV), `generar_efectos.py` (23 efectos en
  `assets/sonido/efectos/`) y `generar_musica.py` (portada, superficie para
  los pisos 1-6, profundo para los 7-12, jefe, victoria y derrota). El autoload
  `Sonido` (`scripts/sonido.gd`) toca los efectos por nombre de archivo
  (`Sonido.tocar(&"golpe_enemigo")`) y funde la música
  (`Sonido.poner_musica`); cada piso dice la suya en `DatosPiso.musica` y el
  disparo de cada proyectil, en `TipoProyectil.sonido`. Los botones hacen
  clic solos (`node_added`). Buses `Musica` y `Efectos` en
  `default_bus_layout.tres`; sus volúmenes, en el menú de pausa y abajo a la
  izquierda de la portada (`ControlVolumen`, el mismo nodo en los dos) y
  guardados en `user://ajustes.cfg`. **Nadie del equipo
  lo había oído al hacerlo**: Claude no puede oír, solo medir (picos, volumen
  medio, recortes, que el bucle empalme). Hay que escucharlo y ajustar.

- **Cooperativo en red local, fases 1 y 2** (2026-10-16 y 18, pedido por
  Matías; estudio y fases en `docs/mejoras-futuras/multijugador.md`). En
  **Jugar → Cooperativo en red local** (`scripts/sala_cooperativo.gd`,
  montado por código en el menú): crear sala, unirse con código y sala de
  espera. Hasta 3 jugadores, **cada uno con un mago distinto** (lo confirmó
  Matías el 2026-10-20: no se repiten), y misma
  versión del juego (si no, no entra). **Se juega la partida entera.** Piezas:
  - Autoload **`Red`** (`scripts/red.gd`): la conexión (ENet, puerto 24701)
    y la sala. El **código** es la IP local del anfitrión en 7 caracteres de
    base 32 de Crockford (`codigo_de_ip`/`ip_de_codigo`; también vale la IP
    tal cual). El anfitrión reparte la lista (`jugadores`: id → número y
    mago) y decide quién entra (`_presentarse`: versión, sala llena,
    partida empezada). `Red.cooperativo()` es lo que pregunta el juego.
  - **`Cooperativo`** (`scripts/cooperativo.gd`), que crea Principal solo en
    cooperativo: **cada uno manda en su mago** y avisa de dónde está unas 20
    veces por segundo; los de los demás se enseñan con **`MagoRemoto`**
    (`scripts/mago_remoto.gd`: sprite, «J2» encima y la burbuja si la lleva;
    no es un `Jugador` ni está en el grupo `jugador`). Los disparos van ya
    hechos (`mandar_disparo` → `Principal.lanzar_bola_remota`). **Los objetos
    son para todos menos para quien esté muerto** (Matías): el que lo coge
    avisa (`Objeto` → grupo `cooperativo`) y a los demás se les quita del
    suelo y se les aplica. Se reconocen por sitio y recurso: los pisos salen
    de una semilla.
  - Llamadas por la red: a `/root/Red` (siempre existe) y a
    `/root/Principal/Cooperativo`, **solo a los que ya tienen la partida
    montada** (`Red.listos()`, con el aviso `_listo` de ida y vuelta).
  - La pausa no congela (`MenuPausa.modo_cooperativo`): para a este mago y
    quita *Reiniciar* (y la pantalla final también, `PantallaFinal.modo_cooperativo`);
    *Salir de la sala* vuelve al menú. Si se va el anfitrión, los demás
    vuelven al menú con el porqué (`Red.mensaje_pendiente`). Sin atajos de
    prueba. El registro sí guarda las cooperativas, con `"jugadores": N`, y
    el análisis las deja fuera salvo con `--con-cooperativo`.
  - **El mundo lo lleva el anfitrión** (fase 2, **`MundoRed`**,
    `scripts/mundo_red.gd`, hijo de `Cooperativo`): sus enemigos piensan,
    pierden vida, mueren y sueltan cosas. En los demás ordenadores cada
    enemigo es un **espejo** (`Enemigo._espejo`, `Red.es_espejo()`): no
    piensa; se pone como manda el anfitrión unas 20 veces por segundo
    (`Enemigo.estado_red`/`aplicar_red`, con su `estado` sin objetos) y muere
    cuando se lo dicen (`morir_espejo`). Cada enemigo tiene un nombre igual en
    todos (`id_red`, «p3:2,-1#0», que pone `Sala.registrar_enemigo`; las crías
    lo traen del anfitrión, que manda el `.tres` de la madre porque la cría no
    tiene). Van a por el jugador vivo más cercano, antes los de su sala
    (`Enemigo._buscar_objetivo`; los demás magos están en el grupo
    `jugadores_remotos`).
  - **Cada uno decide lo que le da a él:** los disparos enemigos (con
    número, `ProyectilEnemigo.id_red`), charcos, ondas, el pozo y el fuego del
    jefe se crean en todos (`MundoRed.crear_lava`, `crear_onda`, `crear_pozo`,
    `fuego`, `romper_pilar`, `soltar_objeto`: el juego los usa también jugando
    solo) y cada copia solo hace daño al jugador de su ordenador. Lo que pasa
    solo en uno se avisa: rebotar en su escudo (`avisar_cambio`), darle
    (`avisar_fin`), que su burbuja empuje a un enemigo (`pedir_empuje`).
  - **Las bolas de los magos dan en el anfitrión:** en los demás todas son
    `BolaMagica.solo_ver` (se apagan al tocar, sin quitar vida), y el agujero
    negro allí no tira. Lo que sale al azar (lo que sueltan, los vendajes)
    solo lo tira el anfitrión (`Red.manda()`) y lo manda.
  - **Peleas para todos, una a la vez:** `Sala.activar` en cooperativo no
    cierra sola; emite `quiere_pelea`, el anfitrión decide
    (`Cooperativo._pedir_pelea`) y la empieza en todos (`Sala.empezar_pelea`);
    quien esté fuera aparece dentro. **Se baja juntos**
    (`Cooperativo.pedir_bajar`). **El que cae** (`al_caer_yo`, en vez de
    acabar la partida) se esconde y su cámara sigue a otro; vuelve al piso
    siguiente con media vida (`Jugador.revivir`). Si caen todos, el
    anfitrión acaba la partida en todos. Enemigos con más vida por jugador
    (`Red.factor_vida_enemigos`: ×1,5 con dos, ×2 con tres). La vida de los
    compañeros, abajo a la izquierda (`VidasCompaneros`).

- **Monedas, diamantes y gachas** (2026-11-04, pedido por Matías). Lo que se
  gana **dura entre partidas**: autoload `Coleccion` (`scripts/coleccion.gd`,
  `user://coleccion.cfg`): dinero, lo que se tiene, lo que se lleva puesto y el
  catálogo, leído de las carpetas. **Una prueba no puede tocar la colección de
  quien la lanza: `Coleccion.usar_archivo("user://otro.cfg")` antes de nada**.
  - **Botín**: `TipoEnemigo.monedas` (la vida entre 10: de 1 a 5; las crías, 1; el
    jefe, 200) y `diamantes` (solo el jefe, 10), que da `Enemigo._dar_botin` al
    morir, con su número (estilos `MONEDA` y `DIAMANTE`); en cooperativo, a cada
    ordenador. Se ve en `Monedero` (`scripts/monedero.gd`, en el HUD, la portada y
    el gacha). **Solo hay un jefe, en el piso 12: hasta que lo mates no hay
    diamantes.** En debug, F9 da 1000 monedas y 50 diamantes (`AtajosPrueba`).
  - **Gachas**: botón *Gacha* de la portada, `PanelGacha`
    (`scripts/panel_gacha.gd`, por código): pestañas de skins (100 monedas) y armas
    (5 diamantes), probabilidades (70, 20, 9 y 1 %, medido en 200 000 tiradas),
    tirada con destape, y la colección, donde se elige lo que se lleva. Cada
    `TiradaGacha` saca un tier y, de ese tier, algo al azar; lo repetido da algo,
    más cuanto más raro (`devolucion`: skins 20, 50, 100 y 250 monedas, desde el
    2026-11-05, Matías puso los 20 de la B; armas 1, 2, 3 y 5 diamantes). El panel lo
    dice, sacado del `.tres`.
  - **Skins** (`SkinMago`, una de cada tier por mago, 16): las saca
    `generar_skins.py` del propio atlas del mago, por colores (B gira el tono; A,
    otra paleta; S, paleta y resplandor; S+, iridiscente y `AuraSkin`). Solo
    cambian el aspecto. Las pone `Jugador._ponerse_coleccion`; en cooperativo van
    por su sitio en el catálogo en `_estado` (`MagoRemoto`).
  - **Armas** (`ArmaMago`, 13, y sirven para cualquier mago): raro, solo aspecto
    (el rocío del verde se queda); épico, también `ModoArma` (abanico, ráfaga,
    onda, rebotes); legendario, también `AnimacionMuerte` (`muerte`, por código,
    con el dibujo del enemigo: llamarada, almas, esquirlas, torbellino, rayos);
    mítico, también varios modos, que se cambian con **la rueda del ratón**, la Q
    o un botón en el móvil (`Jugador.cambiar_modo_arma`; el HUD los dice). Solo
    cambian el disparo normal: el especial es del mago, y la quemadura y el frío
    siguen en las bolas. `BolaMagica.usar_arma` pone lo que mueve la bola (`onda`,
    `rebotes`, `busca`, `explosion`) y cómo se pinta (`Estilo`); dano y cadencia
    parten de un mago normal (`ArmaMago.DANO_BASE`, `Jugador._cadencia_con_arma`),
    para que el rocío del verde no los multiplique. `ArmaFlotante` la enseña junto
    al mago. Principal: `_disparar_arma`. En cooperativo la bola lleva su arma y
    modo por índice, y `MundoRed.anunciar_muerte_arma` la animación.
  **Probado** con una prueba de todo (reparto, tiradas, guardado, botín, cada arma
  y cada modo, formas, animaciones, rueda) y capturas. **El cooperativo no se ha
  probado con dos juegos. Los precios y los daños son a ojo: nadie lo ha jugado.**
- **Arte nuevo de los cuatro magos y sus hechizos** (2026-11-04, lo trajo
  Matías: `vacio_magos_y_hechizos.zip`, con su LEEME en
  `assets/magos_fuente/`). Piromante = rojo, Envenenador = verde, Criomante =
  blanco, Vacío = oscuro. Hojas de 128 px por pose, 4 pasos × 8 direcciones,
  **en el orden de `Jugador.LADOS`**; `herramientas/generar_magos.py` las reduce
  a 72 px, y los pies quedan a 66,4 px de la casilla (por eso el `offset` del
  sprite es −30, en `Jugador.tscn` y en `MagoRemoto`). **Se cambió el arte, no
  cómo juegan.** Cada hechizo es un `ArteHechizo` (`scripts/arte_hechizo.gd`:
  sus animaciones, sus desfases y `radio_base`), que el mago dice en su `.tres`
  (`arte_disparo`, `arte_especial`, `marca_especial`); sin arte, todo sigue
  pintándose por código (el rocío del verde). `EfectoHechizo`
  (`scripts/efecto_hechizo.gd`) pinta una animación una vez y se va, y deja la
  marca del suelo. Lo que usa cada cosa:
  - `BolaMagica`: `vuelo` (girada hacia donde va, a la escala de su radio entre
    `radio_base`) e `impacto` al acabarse. Fuego, lanza de hielo, bola morada.
  - **Meteoro del rojo**: `carga` en `CargaAtaque` (la pose la manda lo cargado,
    no el reloj: carga en 0,375 s), `vuelo` y, al apagarse,
    `Principal._explotar_especial`: `explosion` y la marca (4 s y se apaga en 2).
    **La explosión solo se ve; el daño lo hace la bola al pasar**, como antes.
  - **Agujero negro del oscuro**: `abrir`, `bucle` y `colapso` por debajo de los
    enemigos; se quedan el círculo de alcance y lo negro por código, encima de
    ellos, para que se les vea tragados (mide 34, lo negro de la hoja al 80 %).
    Al acabarse el tiempo deja de tirar y se va al acabar `colapso`.
  - **Burbuja del blanco**: dos capas (`_detras` con z −1 y `_delante` con z +1,
    con el mago en medio), `aparece`, `bucle` y `rompe`. Mientras se rompe ya no
    protege. Al cambiar de piso se va sin romperse. Sin aro del tiempo desde el 2026-11-05 (Matías):
    avisa el parpadeo de los últimos 0,8 s.
    `MagoRemoto` pinta el `bucle`.
  - **Proyectiles del verde**: `dardo` e impacto, girando con el proyectil.
  - **Estados** (`estado_envenenado`, `estado_ralentizado`): los pintan `Burbujas`
    y `Escarcha` (`ArteHechizo.pintar_estado`), **encima del sprite** (en un nodo
    `_estados` del enemigo): por debajo, en un slime casi no se veían.
  **El paquete trae más de lo que se usa** (en `assets/magos_fuente/`): el
  verde allí dispara 3 dardos en abanico y su ultimate es una lluvia de veneno
  (`lluvia_*`, sin usar); la explosión del meteoro y el colapso del agujero
  hacen daño, y el escudo aguanta 3 golpes. Aquí se dejó lo que había pedido
  Matías; **falta que diga si quiere cambiar algo de eso**. La portada sigue
  enseñando los tres magos de antes. Probado con los cuatro: cada hechizo sale,
  se ve en su sitio y se va, también en vertical. **Nadie lo ha jugado.**
- **Versión para móvil** (2026-11-03, pedido por Matías: «un joystick a
  cada lado, como en Brawl Stars; si pone el móvil en vertical, que todas
  las entes giren 90º, que no cambie nada de posición, pero que cambie el
  POV»). **Android** solo: un `.apk` que saca GitHub en el trabajo `android`
  de `publicar.yml` (`herramientas/exportar_android.sh`: plantillas con
  `instalar_plantillas.py --android`, el SDK de la máquina de GitHub, Java
  17, el *version code* = la N de 0.N, puesto en el preset solo allí). Si
  falla, la versión sale igual sin el `.apk`. **La clave de firma no va en
  el repositorio** (`*.keystore` en `.gitignore`: con ella cualquiera
  firmaría como nosotros): la toma de los secretos del repositorio
  `ANDROID_CLAVE_BASE64`, `ANDROID_CLAVE_ALIAS` y `ANDROID_CLAVE_CONTRASENA`,
  que tiene que poner Matías. Sin ellos firma con una clave nueva en cada
  versión, y para actualizar hay que desinstalar antes. iPhone no: sin cuenta de
  desarrollador de Apple no se puede instalar. En Android el aviso de versión
  nueva lleva a la web (`Actualizacion.por_que_no`). **Nadie lo ha probado en
  un móvil.** Piezas:
  - **`ControlesTactiles`** (`scripts/controles_tactiles.gd`, capa 2, lo crea
    Principal si `hace_falta()`: en el móvil, o con `-- --tactil` en el
    ordenador, donde el ratón hace de dedo): joystick azul en la mitad
    izquierda (mueve) y rojo en la derecha (apunta y dispara), cada uno donde
    se pone el dedo; bola opaca, círculo translúcido (0,22) y circunferencia
    a medias (0,6). Botón del especial abajo a la derecha (del color del
    mago, gris si ya se usó; se arrastra para apuntarlo, y pulsa la acción
    del espacio, `cargar_ataque_teclado`) y de pausa arriba en el centro
    (manda la acción `pausar`). Llega al jugador por tres vectores estáticos
    de pantalla (`movimiento`, `apuntado`, `especial`). Con ellos puestos
    (`activos`) el jugador no hace caso al clic izquierdo: cada dedo es
    también un clic. Al pausar se sueltan todos.
  - **`Vista`** (autoload, `scripts/vista.gd`): con la pantalla más alta que
    ancha, `giro` = 90°. `CamaraJuego` gira (`ignore_rotation = false`) y
    calcula el zoom y el encaje con la pantalla girada
    (`_pantalla_en_mundo`): el mundo se ve al mismo tamaño en las dos
    posiciones. Paredes, rocas y suelo giran con la vista; lo que está en
    el grupo `de_pie` gira al revés y sigue derecho: enemigos, objetos,
    cofre, altar, magos de los demás (y los números de daño al nacer). Se
    pueden girar enteros porque chocan con un círculo en su centro; lo que
    pintan hacia un sitio del mundo (la mira del cristal, el picado) deshace
    el giro. **El mago no gira**: su círculo está 16 px por encima de los
    pies; giran su dibujo y lo de sus pies alrededor de ese círculo
    (`Jugador._poner_de_pie`, `Vista.poner_de_pie`). Los mandos son de la
    pantalla: el jugador pasa lo que pide al mundo (`Vista.en_mundo`) y lo
    que mira, a la pantalla para elegir el dibujo (`_lado`, `_vector_de`),
    igual que el jefe (`MagoCaido._mirar`) y el volteo de los enemigos. El
    minimapa y el arco del magma también giran. Probado en una ventana
    estrecha: la cámara y los entes giran, y arrastrar el joystick hacia
    arriba lleva al mago hacia arriba en la pantalla.
- **Estadísticas** (2026-11-03, pedido por Matías: «ver los FPS y
  estadísticas, así como el ping en el modo multijugador, como el F3 de
  Minecraft o el HUD de Fortnite»): el autoload `Estadisticas`
  (`scripts/estadisticas.gd`, capa 50, sigue en la pausa). Tres modos que
  **F3** va pasando (en `_input`, como F11) y que también se eligen en
  Controles (en la fila de «Moverse con»; en otra, «Volver» se salía 40 px
  por abajo) y en la pausa (`Estadisticas.boton()`), guardados en
  `user://ajustes.cfg` (`[pantalla] estadisticas`): *No*, *FPS y ping* (una
  línea arriba a la derecha, encima del minimapa) y *Todas* (columna a la
  derecha, debajo del minimapa, cada línea con su fondo: FPS, fotograma y
  el peor del último segundo, física, llamadas de dibujo, nodos, memoria,
  ventana y VSync; y en la partida, mago y vida, piso, sala, enemigos,
  posición y disparos en el aire; y en red, el **ping** y la pérdida de
  paquetes). El ping es el de ENet (`ENetPacketPeer.PEER_ROUND_TRIP_TIME`):
  el anfitrión ve el de cada uno; los demás, el suyo con el anfitrión
  (solo hablan con él). Probado con dos juegos en este ordenador: 10-17 ms.
  **Por F3, los atajos de prueba de piso pasaron de F2/F3 a F7/F8.** Las
  listas y el interruptor del disparo automático se conectan al método del
  botón (`cambiado(modo)`, `Controles.disparo_automatico_cambiado`) y no a
  una función anónima: esa quedaba viva al liberarse la pausa y daba error
  al volver al menú.
- **Pantalla completa** (2026-10-14, pedido por Matías): el autoload
  `Pantalla` (`scripts/pantalla.gd`) pone el juego exportado a pantalla
  completa sin bordes (`WINDOW_MODE_FULLSCREEN`, no la exclusiva: no cambia la
  resolución y Alt+Tab no parpadea). F11 o Alt+Intro pasan a ventana y
  vuelven, también en pausa, y se guarda en `user://ajustes.cfg`
  (`[pantalla] completa`). **Desde Godot (editor o `jugar.bat`) arranca en
  ventana** y lo que se elija con F11 no se guarda, para no cambiar cómo
  arranca el `.exe` del mismo ordenador. Las pruebas con ventana de Claude
  usan el binario del editor, así que tampoco se ponen a pantalla completa.

- **Elección de mago**: al pulsar Jugar se elige entre los magos de
  `resources/personajes/`. Cada uno trae su arte y su ventaja, y la ventaja va
  a los valores **de fábrica** del jugador, así que sobrevive a reiniciar. El
  menú monta una ficha por `.tres` (`FichaMago`, `scripts/ficha_mago.gd`), así
  que un mago nuevo no toca código.
- **Cambiar mago al acabar la partida** (2026-10-29, pedido por Matías): la
  pantalla final (`PantallaFinal`, al ganar o al perder) tiene un botón
  *Cambiar mago* que enseña las fichas (`FichaMago`, las mismas del menú) de
  los magos que no se han usado en esa partida: todos menos
  `GestorProgreso.personaje_elegido`. Al elegir uno se guarda ahí y se
  reinicia: `Principal._reiniciar` ya lee el mago de `GestorProgreso`, así
  que empieza de cero en el piso 1 con su vida, su ventaja y su especial, y
  el registro lo apunta como otra partida. Escape vuelve atrás. No sale en
  cooperativo ni si solo hay un mago. Ese día empezó a funcionar también la
  tecla R de *Reintentar*: el botón la anunciaba desde el principio, pero
  nada la leía. Y la pausa ya no se queda con Escape cuando la partida ha
  acabado (`MenuPausa._unhandled_input`): se lo quitaba a la pantalla
  final.
  Cada mago trae también **el color de sus disparos** (centro y resplandor del
  normal y del cargado): el oscuro lila (el normal, del color de la llama de
  su bastón, desde el 2026-10-14; antes azul) y morado el cargado, el rojo en
  rojo, el blanco en azul hielo.
- **Mago blanco** (2026-10-08, pedido por Matías). Su disparo normal quita **lo
  mismo que los demás**, 1 (`dano_disparo`; quitaba medio punto hasta el
  2026-10-14, cuando Matías lo igualó; su pega es no tener bola cargada) y
  **frena** 1,5 s
  (`frena_disparo`: anda, apunta y recarga a la mitad, con un aro de escarcha
  a los pies). Su **ataque especial es un escudo burbuja**
  (`scripts/escudo_burbuja.gd`, desde el 2026-10-13) que lo cubre entero
  durante 5 s: los disparos rebotan (`Jugador.escudo_rebota`; el magma bota y
  cae fuera) y, rebotados, **quitan a los enemigos que toquen lo mismo que
  quitaban al mago** (desde el 2026-10-15, `ProyectilEnemigo._golpear_enemigos`;
  también a quien lo tiró y al jefe). Hasta el 2026-11-03 casi nunca
  llegaban: el proyectil se apagaba al recorrer su `alcance` (800 el
  veneno) contando lo que había hecho hasta el escudo; ahora **ningún
  proyectil enemigo tiene distancia máxima**, vuelan hasta dar con algo.
  Rebotan como una pelota en una esfera: si dan por debajo del centro de la
  burbuja salen torcidos, no siempre hacia quien los tiró. El charco del
  magma rebotado **quema también a los enemigos** (`Lava.quema_enemigos`,
  10 cada 0,5 s, no a los que `vuelan`). Los enemigos que la tocan salen despedidos (`Enemigo.empujar`)
  y mientras está nada de los enemigos le quita vida (lo comprueba quien hace
  el daño con `Jugador.escudo_activo`); lo del suelo sí. Se saca con el clic
  derecho o el espacio (`PersonajeJugable.ataque_especial`,
  `duracion_escudo`). No tiene bola cargada. Antes fue un arco pequeño
  delante, primero como pasiva siempre puesta y luego como especial: lo
  cambió Matías las dos veces.
- **Mago verde** (2026-11-03, pedido por Matías). **Disparo en rocío**: `cadencia_multiplicador` 1/9 (18 por
  segundo) y `dano_disparo` 1. El tope de cadencia baja con él
  (`Jugador._cadencia_minima`) y la espera entre disparos guarda lo que
  sobra del paso de física (sin eso salían 15 por segundo). Cada gota es una
  `BolaMagica` con `rocio` (nubecilla verde, un poco torcida al azar,
  `dispersion_disparo` 5°), que no suena al dar: el enemigo junta lo que le
  quitan y lo enseña en un número cada 0,25 s (`Enemigo.TIC_ROCIO`, estilo
  `ROCIO`), con un parpadeo y un golpe; el escudo del jefe también bloquea
  al mismo ritmo. Al disparar suena un soplo (`rocio.wav`) como mucho cada
  0,13 s (`Sonido.tocar(nombre, separacion_ms)`). **Especial «Veneno»**
  (`ESPECIAL_VENENO`): al pulsar (no se carga) salen 8 `BolaVenenosa`
  (`scripts/bola_venenosa.gd`) a 45° una de otra, la primera hacia donde
  apunta: 0,5 s rectas a 210 px/s y luego hacia el enemigo más cercano a
  cada una, girando como mucho 80°/s. Se acaban al chocar con roca o muro,
  al salir del suelo de la sala o a los 8 s. La que da envenena
  (`Enemigo.envenenar`): 5 cada segundo durante 5 s, y **los venenos se
  suman** (`_venenos`, cada uno con su reloj), con burbujas verdes a los
  pies (`Burbujas.pintar`) y números `TOXICO`. Todo en el `.tres`
  (`proyectiles_veneno`, `velocidad_veneno`, `salida_veneno`,
  `giro_veneno`, `veneno_duracion`, `veneno_dano`). En cooperativo,
  `Cooperativo.mandar_veneno` y `Principal.lanzar_veneno_remoto`; el
  envenenado va en `estado_red` (posición 18). Probado sin ventana: 37
  disparos en 2 s, dos venenos quitan 10 por segundo, las cuatro crías
  heredan, y de 8 proyectiles 5 dieron a un gólem quieto. **Nadie lo ha
  jugado.** Con cuatro magos, las fichas del menú miden 250 de ancho
  (`FichaMago.ANCHO`; con 300 no cabían).
- **Jugador**: mago animado **en las ocho direcciones** (las cuatro
  cardinales y las cuatro diagonales), con `caminar_` y `quieto_` por cada una:
  16 animaciones recortadas de un atlas con `AtlasTexture`. WASD mueve (o las
  flechas, ver «Moverse con» más abajo).
  Apuntar manda sobre moverse: si disparas a un enemigo, el mago lo mira
  aunque te estés alejando.
- **Una sala secreta en cada piso** (2026-10-29, pedido por Matías: «una
  sala secreta por piso que no se sepa dónde están, con un cofre, y que al
  pasar por encima salga una ruleta con las ventajas y te toque una al
  azar»). `MapaSalas._anadir_secreta` (después de repartir los tipos, con
  su semilla) cuelga `Tipo.SECRETA` de una sala que no sea la antesala ni la
  del jefe, en una casilla que solo toca a esa y **nunca por encima** (la
  pared de arriba tiene cara, y una puerta escondida ahí no se tapa bien).
  `Piso._preparar_secreta`: la sala de la que cuelga **esconde esa puerta**
  (`Sala.esconder_puerta`: la puerta está en `puertas`, así que nada se
  pone delante, pero su cierre está puesto, no se pinta, y
  `puertas_visibles()` la deja fuera para la pared, el pintado, los pinchos
  de puerta y `cerrar_puertas`), y la secreta queda `oculta` e invisible
  (ni se ve a través de lo oscuro ni sale en el minimapa). **Se descubre a
  disparos**: Principal engancha `BolaMagica.apagada` de las bolas de este
  jugador a `Piso.golpe_de_bola`, y tres que se apagan contra esa pared
  (`Sala.golpear_secreta`, `GOLPES_SECRETA`) la rompen: más grietas con
  cada golpe y polvo (`Escombros`), y al tercero `abrir_secreta` quita el
  cierre y **vuelve a levantar la pared con la misma semilla**. Para que
  salga igual, `ParedSala` distingue `puertas` (las que se ven: perfil,
  choques, cara, sombra y cantos) de `_puertas_todas` (lo que se reparte al
  azar, bultos y adornos): el generador da los mismos números antes y
  después (medido: 36 piezas iguales en el piso 3), y lo único que delata
  la pared escondida son tres grietas finas y que ahí no crece nada. Dentro,
  el **`Cofre`** (`scripts/cofre.gd`, dibujado por código): al pisarlo, la
  **`Ruleta`** (`scripts/ruleta.gd`, capa 3, para el juego salvo en
  cooperativo) gira entre las ventajas que duran y ya pueden salir en el
  piso (`ObjetoMejora.cargar_todos`) y se para en una sacada con `randi()`
  (la suerte, como lo que sueltan los enemigos); *Coger* la aplica con
  `Jugador.aplicar_mejora` (HUD y registro, como un objeto). En cooperativo
  la pared y el cofre se abren en todos y la ventaja es para todos
  (`Cooperativo.secreta_descubierta`/`cofre_abierto`); no se ha probado con
  dos juegos. El tutorial lo cuenta en la ventana de la bajada.
- **El piso 1 es un tutorial** (2026-10-29, pedido por Matías: «que te
  explique cómo funciona todo y en la tercera sala te explique que hay que
  matar a los enemigos»). Con `DatosPiso.mostrar_tutorial` el mapa sale **en
  fila** (`MapaSalas.generar(..., en_fila)`: cada sala nueva cuelga de la
  última), así que «la tercera sala» es siempre la tercera que se cruza; la
  salida es la última y el objeto la penúltima. Cinco salas: 1) a qué se
  juega, moverse, disparar, pausa; 2) el especial (el texto sale del mago,
  `Tutorial._ready`), rocas, vida y mapa; 3) la primera pelea, con
  `DatosPiso.enemigos_tutorial` (un gólem y dos murciélagos) en
  `sala_pelea_tutorial`, que coloca `Piso._colocar_enemigos_tutorial` con
  semilla propia después de las rocas (la mecánica de enemigos sigue
  empezando en el 2); 4) objetos y vendajes; 5) la bajada y lo que espera
  abajo. **Cada sala lo cuenta en una ventana** (Matías, el mismo día: «que
  en vez de texto se abriera un pop up»): `Tutorial` (`scripts/tutorial.gd`,
  un `Node` que crea el piso) escucha `Piso.sala_cambiada` y, 0,45 s después
  de entrar (lo que tarda la cámara en llegar), abre `AvisoTutorial`
  (`scripts/aviso_tutorial.gd`, capa 3, montado por código): título, texto
  con BBCode (`[k]…[/k]` resalta) y *Entendido*. **Para el juego** como la
  pausa (en la de la pelea los enemigos ya están despiertos), salvo en
  cooperativo; Escape la cierra y no llega a la pausa (`_input`). Los textos
  están en `Tutorial.PASOS`, con `{mover}`, `{disparar}` y `{especial}`
  rellenados con las teclas de Controles y el mago. **Una vez por sesión**
  (`Tutorial._vistas`, estático): al reiniciar no se repiten, salvo la del
  especial con otro mago. Antes eran carteles pintados en el suelo: desde
  el 17/09, siete juntos en la sala de inicio de un piso de cuatro salas sin
  enemigos.
- **Moverse con WASD o con las flechas** (2026-10-18, pedido por Matías): en
  el panel Controles del menú (`MenuPrincipal._montar_eleccion_teclas`). El
  autoload `Controles` (`scripts/controles.gd`) **intercambia las teclas** de
  `mover_*` y `disparar_*` en el mapa de teclas (las acciones no cambian de
  nombre, así que el jugador no sabe nada) y lo guarda en
  `user://ajustes.cfg` (`[controles] mover`). Con las flechas para moverse,
  se dispara con WASD. Los textos con teclas (el panel del menú, con
  `Controles.teclas_mover()` / `teclas_disparar()`, y las ventanas del
  tutorial, `Tutorial._rellenar`) dicen las elegidas.
- **Disparo automático** (2026-11-03, pedido por Matías: «disparando sin
  parar mientras tenga a un enemigo a tiro, en la misma sala»): un
  interruptor en el panel Controles del menú (en la fila de «Moverse con»;
  en otra fila el panel ya no cabía) y en la pausa, los dos creados por
  `Controles.boton_disparo_automatico()` y guardado en `user://ajustes.cfg`
  (`[controles] disparo_automatico`). Encendido, si no apuntas tú (ratón o
  teclas, que mandan), `Jugador._direccion_automatica` apunta al enemigo más
  cercano de la sala en la que está el mago (`Jugador.sala_actual`, que pone
  Principal al cambiar de sala), antes los que tiene a tiro (sin roca ni muro
  en medio); sin enemigos, no dispara. Probado: 4 enemigos del piso 3 en
  5,9 s con 12 disparos, y ninguno con la sala vacía.
- **Disparo**: flechas (cuatro direcciones) o clic izquierdo apuntando con el
  ratón, una bola cada **0,5 s** en el oscuro, el rojo y el blanco (pedido
  por Matías el 2026-10-09; antes 0,34, y el oscuro ×0,85); el verde rocía
  9 veces más rápido. Matan enemigos; **no** rompen rocas, y las rocas los
  paran (ver la trampa del `Area2D` más abajo).
- **Ataque cargado**: clic derecho o espacio, mantenido. Con el clic derecho
  apunta al ratón; con el espacio (acción aparte, `cargar_ataque_teclado`),
  a las flechas o, sin ninguna, hacia donde mira el mago: es para jugar sin
  ratón, y el ratón no manda aunque esté encima (Matías, 2026-10-09; ver
  `Jugador._direccion_especial`). Se carga en `tiempo_carga`
  (0,75 s), hay que **soltarlo** para que salga y soltarlo antes de tiempo no
  dispara nada. Atraviesa enemigos y hace 3 de daño; las rocas lo paran igual.
  Mientras cargas, el disparo normal se calla. El aviso visual lo dibuja
  `scripts/carga_ataque.gd` en un nodo aparte del jugador.
- **Quemadura del mago rojo** (2026-10-09, pedido por Matías): cada bola
  suya que da a un enemigo lo deja quemándose 3 s, 0,25 de vida por segundo
  (`PersonajeJugable.quemadura_duracion`/`quemadura_dano`,
  `Enemigo.quemar()`). Va a golpes de 1 s, a tiempo real (el frenado no la
  frena). Un golpe nuevo rellena la cuenta a 3 golpes pero **no reinicia el
  tic**: dispara cada 0,5 s, y si cada bola reiniciara la espera, disparándole
  sin parar no le quemaría nunca. Tampoco se suman dos quemaduras.
- **El ataque especial es uno por piso** (pedido por Matías el 2026-10-09),
  sea la bola cargada o el escudo: `Jugador.especial_disponible`, que se gasta
  al soltar la bola o sacar el escudo y vuelve en `reubicar()` (piso nuevo) y
  `restaurar_vida()`. El HUD lo enseña debajo de la vida
  (`Hud.actualizar_especial`).
- **Agujero negro del mago oscuro** (2026-10-09): su bola cargada llega a
  320 px (`alcance_cargado`; la del rojo, hasta chocar) y donde se apaga
  (`BolaMagica.apagada`) Principal abre un `AgujeroNegro`
  (`scripts/agujero_negro.gd`): 2,5 s atrayendo a los enemigos de su sala a
  150 px y quitando 2 por segundo, a tics de 0,5 s, a los del centro. El
  centro negro va en un nodo hijo con z 8, encima de los enemigos (z 5), para
  que lo que llega se vea tragado; el resto, debajo.
- **Salas**: cada piso es un mapa de 4 a 10 salas en cuadrícula, con forma de
  árbol (un solo camino entre dos salas). La salida es la sala más lejana del
  inicio; el objeto va en el callejón más lejano. Al entrar **del todo** en una
  sala con enemigos, sus puertas se cierran (rejas) hasta limpiarla; los
  enemigos duermen hasta entonces. La bajada está tapada hasta limpiar su
  sala. La cámara se encaja en la sala: si cabe se queda quieta, si no se
  mueve dentro. Las bolas se apagan al salir de la casilla de su sala.
- **Lo de fuera de la sala, a oscuras** (2026-10-20, pedido por Matías):
  `Penumbra` (`scripts/penumbra.gd`, la crea Principal) pinta encima de todo
  lo del mundo (z 30) cuatro bandas negras al 92 % alrededor de la casilla de
  la sala, con 48 px de degradado. La pantalla es más ancha y más alta que
  la sala en todos los pisos (con la vista del piso 2, 1760 × 990 px de
  mundo, y salas de 1340 × 800: sobran 146 px por lado), y asomaba lo de
  las salas vecinas. La zona con
  luz la da `CamaraJuego.zona_iluminada()`, que va hacia el límite con el
  mismo suavizado que la cámara y salta con ella (`seguir`/`limitar_a` con
  `inmediato`): al cruzar una puerta la luz se desliza con la vista, y vale
  igual para la sala del jefe y para quien mira a un compañero en
  cooperativo. Dentro de la sala no cambia nada (medido: la misma luz con y
  sin ella). Los compañeros que estén en otra sala quedan también a oscuras.
- **Pausa con Escape** (`scripts/menu_pausa.gd`, `scenes/MenuPausa.tscn`):
  continuar, reiniciar o volver al menú. Pausa el árbol entero
  (`get_tree().paused`), así que todo se congela sin que ningún script sepa
  de la pausa; el menú es lo único con `process_mode = ALWAYS`. No se abre con
  la pantalla final puesta. Al pausar se tira la carga del ataque: si no,
  soltar el botón en pausa lo disparaba al continuar.
- **Ventajas en el HUD** (`scripts/mejoras_recogidas.gd`), debajo de los
  corazones: el icono de cada objeto recogido con un aro de su color, y
  «x2» si se repite. Solo las que duran: el vendaje, que solo cura, no sale.
  Se vacía al reiniciar.
- **Minimapa** arriba a la derecha (`scripts/minimapa.gd`): visitadas
  rellenas, vecinas en contorno, objeto y bajada marcados en cuanto se conocen.
- **Rocas y plataformas**: `StaticBody2D` sólidos. Se choca con ellas, **no
  hacen daño** y paran los disparos, así que sirven de parapeto.
- **El límite de cada sala es una pared de roca**, distinta en cada piso
  (`scripts/pared_sala.gd`, `EstiloBorde`), desde el 2026-10-08. Antes eran
  filas de rocas sueltas, las mismas en varios pisos. La pared:
  - tiene el **canto irregular** (ondas, esquinas redondeadas y algún
    **bulto** que se mete más en la sala). Nunca es un rectángulo, como pidió
    Matías, y se abre delante de las puertas;
  - **choca** con círculos pegados a lo largo del canto
    (`Sala.anadir_roca_filo`). El muro recto sigue detrás, por si acaso;
  - en la de **arriba** se ve su **cara** de frente (vista 3/4), con lo que
    cuelga de ella. En las demás, el canto con luz y la sombra al pie;
  - lleva encima **adornos** de su capa (hierba, setas, cristales, brasas...)
    y en los bultos **salientes** grandes que chocan (estalagmitas, cristales,
    columnas, astillas);
  - cada piso tiene su roca, su cara, sus **pilares** de puerta y sus piezas.
    La roca del fondo de todo el piso es la misma, más oscura (`Piso._draw`).
  El **rastrillo** de las puertas es igual en todos los pisos: baja al
  cerrarse y sube al abrirse (0,22 s).
- **Piedras pequeñas**: decoración sin colisión. Treinta chinas sólidas por piso
  harían el movimiento un engancharse continuo.
- **Enemigos** (nuevos desde el 2026-11-04: Matías trajo `vacio_completo.zip`, «cambia
  los enemigos actuales por los nuevos»): desde el piso 2, **tres criaturas con una
  variante por capa**, corteza (pisos 1-4), manto (5-8) y núcleo (9-12; el paquete dice
  9-11 porque su 12 es solo el jefe, y aquí el 12 tiene más salas), con
  `TipoEnemigo.piso_maximo`. Salen al azar. De media 3 sitios por sala en el piso 2 y
  0,5 más por piso, hasta 8 en el 12: de 17 enemigos en el piso 2 a 130 en el 12, unos
  650 por partida (medido). Números **a ojo**, en cada `.tres`. Ninguno se queda dentro
  de una roca (`Sala.sacar_de_las_rocas`). Tabla en `resources/enemigos/README.md`.
  - **Gólem** (cuerpo a cuerpo, 60-100 de vida, velocidad 95-115): `ComportamientoGolpe`
    (`scripts/comportamientos/golpe.gd`): va a por ti y, a 72 px, se para, levanta los
    brazos (el aro marca hasta dónde llega) y en la pose 3 de `atacar` (0,375 s, a 8 por
    segundo) golpea: una `OndaChoque` corta por `MundoRed.crear_onda`, delante de él, que
    en cooperativo sale en todos y cada uno mira la suya. Si apenas avanza, va de lado
    `rodeo` s: en línea recta, de frente contra una roca o un agujero, se quedaba parado
    para siempre. Medido con el mago quieto 25 s en 66 sitios: sin rodeo no llegaban 13,
    con él 5; la rata de antes, en zigzag, 2. **La velocidad del paquete (45) se subió**:
    aquí los de cuerpo a cuerpo son rápidos (decisión de abajo).
  - **Vigía** (a distancia, 30-50 de vida, velocidad 60-70, `vuela`):
    `ComportamientoAbanico`, el de la serpiente: te rodea, busca tenerte a tiro si una
    roca tapa la línea y dispara 1, 3 y 3 esquirlas (20, 30 y 40 de daño).
  - **Murciélago** (cuerpo a cuerpo, 10-20 de vida, velocidad 150-190, `vuela`):
    `ComportamientoPicado`, de **tres en tres** (`TipoEnemigo.grupo`, que cuentan como un
    sitio al repartir: `MecanicaEnemigos._colocar`). `atacar` al lanzarse, mirando a
    donde se lanza.
  - **El dibujo** (`Enemigo`): una animación por dirección (`caminar_`, `atacar_`, `dano_`,
    `muerte_` + `Jugador.LADOS`), elegida por dónde se ve en la pantalla (`mirar_a`, con
    `Vista.en_pantalla`). `gesto` hace una vez `atacar` o `dano` y vuelve a andar; un
    golpe no interrumpe un ataque ni vuelve a empezar (con el rocío se quedaría en la
    pose blanca). `pose_ataque` dice por qué pose va: el golpe sale en la pose, y frenado
    también va más lento. Al girarse andando sigue en la misma pose (`_animar`), y quieto
    se queda en la primera, salvo lo que vuela (`_marcar_el_paso`). `alto` es el cuerpo,
    y `escala_dibujo` y `desfase_dibujo` colocan la casilla, que trae margen.
  - **Al morir, `RestosEnemigo`** (`scripts/restos_enemigo.gd`): un nodo aparte que hace
    `muerte_<lado>` y deja los restos 1,5 s. Para el juego el enemigo muere de golpe,
    como antes (la sala lo cuenta, botín, puertas): si se quedara haciendo su animación,
    todo lo que mira a los enemigos tendría que saber que ese ya no cuenta. No salen si lo
    mata un arma con su animación (`Enemigo.sin_restos`, `AnimacionMuerte`). También en
    los espejos, con la dirección sacada del nombre de la animación.
  - **Proyectiles con dibujo**: `TipoProyectil.arte` (`ArteHechizo`, como los hechizos):
    `vuelo` girado en `ProyectilEnemigo._dibujo` e `impacto` al acabarse.
  - **Los once de antes están en `resources/enemigos_antiguos/`** (el arte, en
    `assets/enemigos/`, y sus comportamientos siguen): para que uno vuelva basta con
    moverlo a `resources/enemigos/`. Con ellos se fue lo que tenían de especial: los
    slimes y sus cuatro crías que heredan estados (`division`, `heredar_estados`, que
    siguen en el código), la explosión al morir, saltos, zigzag, rebotes, el fantasma, la
    planta que excava, la que persigue cada vez más rápido, el teletransporte y el veneno
    que frena. **Si Matías echa de menos algo, se recupera de ahí.** `Enemigo` sigue
    pintando los de una animación (`moverse`, volteándose): probado con el slime verde.
  **Probado** sin ventana (recursos, qué sale en cada piso, el golpe y apartarse, morir y
  los restos, el arma, esquirlas, picado, tutorial) y con capturas de las tres capas, las
  ocho direcciones y la vista en vertical. **En cooperativo solo se ha probado el espejo a
  mano (`aplicar_red`, `morir_espejo`), no con dos juegos. Nadie lo ha jugado.**
- **Al recibir un golpe, la cámara tiembla** 7 px durante un cuarto de
  segundo (`CamaraJuego.sacudir`). Va en el `offset`, así que no se mezcla
  con el seguimiento ni con el límite de la sala.
- **Peligros del suelo** (`scripts/mecanicas/peligros.gd`), de 1 a 3 por sala
  de pelea: **pinchos** que salen a ratos (desde el piso 2), **agujeros** que
  cuestan 30 de vida y te devuelven a la entrada de la sala (desde el 3) y
  **lava** (desde el 4). Nunca pisan el paso de una puerta al centro.
  **Trampas de hielo** (`TrampaHielo`, `scripts/trampa_hielo.gd`; Matías,
  2026-11-03: «el mismo funcionamiento que los pinchos, pero en vez de hacer
  daño te da efecto de ralentización»): hereda de `Pinchos` (el mismo ciclo
  y los mismos agujeros; `Pinchos._draw` se partió en `_pintar_placa`,
  `_pintar_pincho` y `_pintar_encima` para que pinte lo suyo): placa teñida
  de frío, cristales de hielo en vez de pinchos, los agujeros brillan al
  avisar y una neblina con destellos fuera. Pisada fuera, `Jugador.congelar`
  2 s: va a la mitad (`FACTOR_FRIO`), anima a la mitad, su sprite se tiñe de
  `Escarcha.COLOR` y lleva la escarcha a los pies, la misma de los enemigos
  frenados por el mago blanco (`Escarcha.pintar`, que ahora usan los dos).
  Quita 1 de vida (`DANO_HIELO`; Matías la quiso así al verla; los pinchos
  quitan 25). `MecanicaPeligros._poner_hielo` cambia por ellas
  `trampas_hielo` (5) de los pinchos de `pisos_hielo` (9 a 12), al final del
  piso y con los de las puertas incluidos: una por piso y la que sobra en
  uno al azar (`hielo_en_piso`; al azar del todo salían 1, 0, 0 y 4).
  **Los enemigos esquivan los agujeros y caen si los empujan** (Matías,
  2026-11-03): `Enemigo.andar` (y `andar_rebotando`, que rebota en ellos
  como en un muro) no deja que un paso los meta en uno (`Sala.pozo_en`, con
  `MARGEN_POZO` más su cuerpo): lo rodea, de lado respecto al agujero y
  hacia donde iba; parándose sin más se quedaba en el borde para siempre.
  Empujados (la burbuja del mago blanco, el agujero negro) sí pueden
  meterse, y entonces caen (`_caer_si_pisa_pozo`, en cada paso): se hunden
  y mueren, cuentan como matados y no explotan ni sueltan crías. No caen ni
  esquivan los que vuelan (`TipoEnemigo.vuela`: murciélago y fantasma), ni
  el jefe. El cristal no se teletransporta encima de uno, y las crías no
  nacen encima. Probado en el piso 4: una rata rodea el agujero para llegar
  al mago sin pisarlo; empujados, el slime y la rata caen y el murciélago
  no.
- **Pinchos en las puertas** (pedido por Matías el 2026-10-08): desde el
  piso 3, un 40 % de las puertas de las salas de pelea tienen una placa de
  pinchos justo al cruzarlas, de lado a lado del hueco (26 en una partida).
  Se cruzan esperando a que bajen. Quien cae a un agujero reaparece por
  detrás de la placa (`Sala.fondo_trampa`, `Piso.MARGEN_TRAMPA`).
- **Veneno**: 3 s en los que el jugador va al 60 % de velocidad, en verde, y
  pierde 2 de vida poco a poco (uno cada segundo y medio, en verde encima del
  mago). Lo de la vida se pidió el 2026-10-14 (Matías: «un punto o 2 como
  mucho en 3 segundos»); está en `veneno.tres` (`veneno_vida`, y la duración
  en `ralentiza`, que pasó de 2,5 a 3 s). No es un golpe: ni parpadea, ni
  tiembla, ni suena; señal aparte `Jugador.veneno_quita`, y en el registro va
  marcado `"veneno": true` como «Serpiente (veneno), poco a poco».
- **Objetos**: uno por piso, en el centro de su sala, con icono de lo que hacen.
  Además, cada enemigo que muere tiene un **3 %** de soltar otro al azar
  (entre 9 y 16 por partida en las pruebas); las crías no sueltan nada. Nunca cae
  encima de un agujero, lava, pinchos, una roca o la bajada: si el enemigo
  murió ahí, cae en el sitio libre más cercano. Las mejoras se acumulan toda
  la partida y se pierden al empezar otra.
- **Vendajes al limpiar una sala** (`scripts/mecanicas/vendajes.gd`): un
  25 % de que caiga un vendaje que cura 60, en el centro o en el sitio libre
  más cercano. Una partida tiene 63 salas con enemigos: unos 16. **Hasta el
  2026-10-14 caía un corazón que curaba 30**; Matías lo cambió por el vendaje
  porque en los pisos hondos se quedaba corto. Es el mismo vendaje que hay
  entre los objetos (`Objeto.soltar`), y lo deja también la antesala del
  jefe y el jefe al cambiar de fase. **Lo que solo cura no se coge con la
  vida llena** (`ObjetoMejora.solo_cura`, mirado en cada paso en
  `Objeto._physics_process`): se queda en el suelo para luego.
- **Vida y daño en puntos** (2026-10-14, pedido por Matías: «ver el número
  de vida que le quitas»). El jugador tiene **100** (130 el rojo) en una barra
  (`scripts/barra_vida.gd`, en lugar de los corazones), más larga cuanta más
  vida máxima, con lo que se acaba de perder en blanco un momento. Va
  **arriba a la izquierda**: en la 0.27 estuvo abajo a la derecha y Matías la
  devolvió (2026-10-14) porque en la sala del jefe quedaba junto a la barra
  del jefe y se veía mal. Todo va
  ×10 respecto a antes: un disparo normal quita **10** (de 10 a 13,
  `BolaMagica.VARIACION`, solo hacia arriba para que lo que caía de un
  disparo siga cayendo de uno), el cargado 30 (50 el del rojo), la quemadura
  3 por tic y el agujero negro 10 por tic; los enemigos tienen de 10 (rata,
  murciélago, crías) a 50 (gólem), y el jefe 1500. Lo que quitan ellos ya no
  es 1 para todos: de 20 (rata, murciélago, veneno) a 50 (rayo del cristal),
  45 el magma del gólem, pinchos 25, lava 20, caer 30; el vendaje cura 60.
  **El rayo del cristal ha ido y vuelto**: quitaba 50; el 2026-10-15 Matías
  lo bajó a 30 (en sus cinco partidas guardadas, de la 0.27 a la 0.31, mató
  en tres, todas en los pisos 5 y 6, y ninguna pasó del 7), y el 2026-10-21
  lo volvió a dejar en 50. Sigue disparando sin avisar. **Cada golpe enseña su número** (`scripts/numero_dano.gd`, del
  tamaño de pantalla aunque cambie el zoom): blanco el normal, dorado el
  cargado, naranja la quemadura, violeta el agujero negro y rojo encima del
  jugador. El número es lo que quita de verdad (el golpe que mata enseña lo
  que le quedaba). **El escudo del jefe lleva un aro**
  por fuera que se vacía con el tiempo que le queda. El del mago blanco lo llevó
  hasta el 2026-11-05, cuando Matías lo quitó.
- **Arte por piso**: desde el 2026-10-08, cada uno de los 12 pisos tiene sus
  propias rocas de dentro (`assets/rocas/piso_NN/`), de la misma roca que su
  pared: cantos con musgo, basalto mojado, caliza, magma con olivino,
  peridotita, ringwoodita, columnas, escoria con lava, hierro, níquel y
  cristal de hierro plateado y dorado. Lo que crece en las losas son los
  adornos de la pared del piso. Los packs de antes (musgo y cueva de maaot,
  manto de Matías, núcleo generado) siguen en `assets/` sin usar: volver a
  uno es apuntar `catalogo_arte` del `.tres` del piso a su catálogo.
- **Atajos de prueba** (`scripts/atajos_prueba.gd`): F1 invencible, F7/F8
  piso anterior/siguiente (F2/F3 hasta el 2026-11-03: F3 es ahora la de
  las estadísticas, también en el `.exe`), F4 matar a los de la sala, F5 recuperar el
  ataque especial. Solo con
  `OS.is_debug_build()` (editor y `jugar.bat`); en el `.exe` el nodo ni se
  crea. Usan `Jugador.invencible`, `GestorProgreso.ir_a_piso()`,
  `Sala.enemigos()` y `Enemigo.matar()`, que no usa nada más.
- **Rocas móviles**: hechas pero **desactivadas** (`activa = false` en su
  `.tres`), porque no convencieron al jugarlas. El código sigue ahí.

## Pendiente

- **Licencias**: `CREDITS.md` tiene packs, autores y URLs, pero la licencia de
  cada uno está "sin verificar" (no se pudo abrir itch.io desde aquí). Desde
  el 2026-10-08 los escenarios son todos propios y los packs de itch.io ya no
  se usan, y desde el 2026-11-04 tampoco está la hoja de la que salía el Mago Caído.
- **Multijugador: fases 1 y 2 hechas (2026-10-18), falta probarlas en
  clase.** El estudio está en `docs/mejoras-futuras/multijugador.md`. Se
  probó en un ordenador con dos juegos abiertos (peleas, crías, objetos,
  caer y volver, bajar juntos, derrota, el jefe con sus fases y pilares);
  **en la wifi del instituto, no**, y es el mayor riesgo (muchas no dejan
  que los ordenadores se hablen). Nadie lo ha jugado con varias personas.
  Falta la fase 3 (internet), sin decidir cómo.
- **Equilibrar la dificultad jugando.** Los 12 `.tres` se pusieron a ojo el
  primer día y el juego ha cambiado mucho desde entonces. Ojo sobre todo a los
  enemigos: desde el 2026-11-04 salen de 17 (piso 2) a 130 (piso 12) al empezar
  el piso: una partida entera son unas 650 muertes, y cada una tiene un 3 % de
  soltar una ventaja, además de las 12 de los pisos.
  Al limpiar salas caen además unos 16 vendajes por partida (60 cada uno).
  Los de distancia quitan de 20 a 40 y hay pinchos, lava y agujeros, con 100
  de vida (130 el rojo). Nadie lo ha jugado entero todavía. Todo se toca en los `.tres`
  (`resources/mecanicas/`, `resources/enemigos/`, `resources/proyectiles/`).
- **Posibles mejoras de las salas**, no pedidas: salas de otras formas.

## Decisiones tomadas (no deshacerlas sin hablarlo)

- **Al jefe no lo mueve nada** (ni el agujero negro ni la burbuja) **y el
  frío le dura el 40 %**: arrastrarlo a un rincón o tenerlo siempre a medio
  ritmo haría de la pelea final la más fácil del juego.
- **El jefe no se puede dañar hasta acabar su presentación**: desde el
  umbral (la sala ya es la actual, las puertas aún no se han cerrado) se le
  podía quitar vida sin que pelease.
- **La antesala recarga el especial con un altar que se pisa, no sola al
  entrar**: tiene que verse de dónde sale. Está en el centro, de camino entre
  las dos puertas, así que se pisa sin buscarlo, y lleva escrito qué hace.
- **Los pilares de la sala del jefe los rompe el rayo de fuego del jefe**
  (Matías, 2026-10-14), y nada más: los disparos del jugador siguen sin
  romper rocas. El pilar para ese rayo (no te da) y se rompe: cada pilar
  cubre una vez, y la fase 3 se va quedando sin sitios donde esconderse. Al
  romperse, la sala lo olvida (`Sala.olvidar_roca`) para no seguir
  apartando a nadie de donde estaba.
- **El registro apunta, no juzga**: guarda lo que pasa y el análisis va
  aparte, en Python. Así se pueden sacar otras cuentas de partidas ya jugadas
  sin volver a jugarlas. Las reiniciadas o dejadas antes de 10 s no se
  guardan (entrar y salir ensuciaría las medias); el tiempo en pausa no
  cuenta. **Las de las escenas de prueba tampoco** (2026-10-16): montan
  `Principal` dentro de su escena, y el juego la cuelga de la raíz, que es
  lo que mira `RegistroPartida._de_prueba`. De las nueve primeras partidas
  guardadas, cuatro eran pruebas de Claude; se movieron a
  `user://partidas_de_prueba/`, fuera de lo que lee el análisis. Una prueba
  que quiera que se guarde tiene que añadir `Principal` a la raíz.
- **Solo busca versiones nuevas el juego exportado con número publicado**
  («0.17»). Desde Godot no hay versión, y el `.exe` de cada ordenador con
  cambios sin publicar («0.17 + cambios») lleva cosas que no están en
  ninguna: decirle que la 0.18 es más nueva podría ser mentira. Sin pantalla
  tampoco: la prueba de arranque de la release no tiene que salir a internet.
- **El aviso no interrumpe**: va en una esquina de la portada, y si la
  descarga acaba jugando, no se reinicia nada. La versión nueva se abre con
  el botón o la próxima vez. «Ahora no» lo esconde hasta volver a abrir el
  juego.
- **Los corazones solo se recuperan, no se añaden** (Matías, 2026-10-13):
  ningún objeto sube la vida máxima. Se quitó el «Corazón de roca»
  (`resources/objetos/`); solo cura el vendaje. La
  vida de más del mago rojo es de salida, no se gana jugando.
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
- **Los personajes de antes se borraron** (2026-10-09, pedido por Matías):
  `mago/`, `nigromante/` y `personaje/` (BlueWizard). No los usaba nada; si
  hiciera falta alguno, está en el historial de git.
- **El mapa de salas es un árbol.** Una casilla nueva solo se acepta si toca a
  una sola sala: sale ramificado, con callejones, y entre dos salas hay un solo
  camino. Los callejones son los que dan sitio a la sala del objeto.
- **La salida es la sala más lejana y el objeto va en un callejón.** Así hay
  que cruzar el piso para bajar, y coger el objeto es desviarse a propósito.
- **Todas las salas miden lo mismo** (`ancho_area` × `alto_area`, 1340 × 800
  en los 12 pisos), salvo la del jefe. Dentro de un piso es lo que las deja
  encajar en la cuadrícula muro con muro, sin huecos; entre pisos, lo pidió
  Matías el 2026-11-03.
- **Los enemigos duermen hasta que entras en su sala.** Son `Area2D` que van
  directos al jugador sin chocar con nada; despiertos, los de la sala de al
  lado cruzaban el muro para perseguirte.
- **Las puertas se cierran al entrar DEL TODO, no al cruzar el umbral.** La
  cámara cambia de sala a mitad del pasillo, pero el cierre espera a que el
  jugador esté dentro con margen (`MARGEN_ENTRAR`), o nacería encima de él.
- **Las bolas no salen de la casilla de su sala.** Si no, por una puerta
  abierta matarían enemigos de la sala de al lado que ni has visto.
- **Todo se ve del mismo tamaño en todos los pisos** (Matías, 2026-10-22:
  «que se vean siempre con el mismo tamaño que el piso 2, y los assets lo
  mismo»). `radio_vision` es 495 en los 12 `.tres` de piso. Antes bajaba
  de 520 a 240 y la cámara se acercaba el doble en el 12: enemigos, rocas y
  mago se veían más grandes, y del 9 en adelante no cabía ni el suelo. Ahora
  la sala cabe entera en todos (zoom 0,655 medido en los pisos 2, 7 y 12 y
  en la sala del jefe) y la cámara se queda quieta en ella. Con la ventana
  de 1152×648. **Y desde el 2026-11-03 las salas también miden lo mismo
  en todos los pisos** (Matías: «no en todas las salas tienen el mismo
  tamaño»): 1340 × 800, las del piso 2. Antes encogían de 1400 × 820 a
  740 × 600, y con ellas lo que sale de su ancho: las rocas
  (`Piso._colocar_obstaculos`, lado = 7,5 % del ancho, hasta 96), los
  peligros y las piezas de la pared. La del jefe, 1600 × 860. Lo que sube
  al bajar es lo de dentro: salas, enemigos y rocas.
- **La ventaja de un mago se suma a los valores de fábrica, no se aplica como
  un objeto recogido.** `restaurar_vida()` vuelve a esos valores al empezar
  otra partida: si la ventaja fuera un objeto del piso, el mago perdería lo
  suyo al reiniciar. Se calcula **desde los valores de la escena**
  (`_escena_*`), nunca sumándola a los de ahora: `usar_personaje()` se vuelve
  a llamar en cada reinicio.
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
- **El pixel art se mueve en píxeles enteros y se dibuja a escala 1.** Valía para
  el Mago Caído, lo último en pixel art, hasta el 2026-11-04: centrar cada dirección
  se hizo desplazando un número entero de píxeles, y la escena lo dibujaba sin escalar.
  Los cuatro magos, desde el 2026-11-04, son vectoriales: se reducen con buen
  filtro en `generar_magos.py`, nunca en el juego.
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
- **El daño admite medios, pero `romper()` sigue sin parámetros.** La vida
  de los enemigos es `float` y la bola les llama `herir(cantidad, frena)`; a
  todo lo demás que se rompa, `romper()` repetido, que es el contrato de
  siempre. Así lo que ya era rompible no tuvo que cambiar.
- **El escudo se saca al pulsar, no al mantener.** Sacarlo tiene que ser
  una decisión: es el especial del piso.
- **El agujero negro tira con más fuerza que lo que corren los enemigos**
  (330 px/s en el centro, 150 en el borde; el murciélago va a 195). Si no,
  los rápidos se le escapaban andando hacia el jugador. Después de moverlos
  llama a `Enemigo.mantener_en_la_sala()`, para que el tirón no los meta en
  una roca.
- **El escudo burbuja para todo lo de los enemigos, pero no el suelo**
  (Matías, 2026-10-13: «que cubra todo el personaje»). Antes solo paraba lo
  de frente para que los de distancia tuvieran algo que hacer; ahora eso lo
  da que dure 5 s y sea uno por piso. Lava, pinchos y caer no los lanza nadie
  y siguen haciendo daño. Los disparos lo preguntan justo después de moverse
  (`Jugador.escudo_rebota`). El rebote se hace **con lo que se mueven el uno
  respecto al otro** (el mago puede ir andando), como una pelota contra una
  raqueta: sale más rápido si el mago iba hacia él (`RAQUETA_MAXIMA`, hasta
  el doble), nunca más lento. Se saca al borde de la burbuja. Rebotados ya
  no hacen daño al jugador, sino a los enemigos.
- **Las rocas se calibran contra el suelo de su piso.** La cuenta es la de
  la nota de `tinte_profundidad()`: luminosidad de la roca entre la del suelo
  (gamma, no lineal). La cueva daba 0,32 en el piso 9, y a partir de 0,48 la
  roca se funde con el suelo. Las rocas de cada piso (`generar_rocas.py`) se
  llevan a un valor fijo, y **nunca entre 0,45 y 1,6**: oscuras (0,32-0,45)
  en la mayoría, claras (1,9-2,1) en los pisos 1, 3, 11 y 12, donde la roca
  es clara de por sí (cantos, caliza, cristal). Lo que brilla (grietas,
  cristales) va encima, después de medir. Ya traen su color y su luz: el piso
  no las tiñe ni oscurece las losas (`CatalogoObstaculos.colores_propios`).
  Con los packs de antes la cuenta daba de 1,13 (piso 1) a 0,27 (piso 12).
- **Cuerpo a cuerpo rápido, distancia lento y letal** (pedido por Matías el
  2026-09-29; por eso el gólem va a 95-115 y no a los 45 de su paquete). Los de distancia avisan antes de cada disparo (se paran y
  brillan), porque quitan 2: sin aviso, un golpe así no se puede esquivar y
  solo frustra. El cristal es la excepción desde el 2026-10-09, por petición
  de Matías: dispara sin avisar.
- **Como mucho la mitad de cada sala son de distancia.** Una sala solo de
  tiradores es una lluvia de disparos desde todas partes.
- **El veneno quita poco y no mata.** Lo que más pesa es que frena: el
  peligro es el siguiente golpe. Desde el 2026-10-14 quita además 2 en 3 s,
  pero nunca el último punto (como caer por un agujero): aguantar el
  escupitajo con 2 de vida y morir después por el veneno sería injusto. Un
  segundo veneno reinicia la cuenta, no se suma.
- **Las crías de slime ni explotan ni se dividen**, o matar un slime
  desataría una cadena que no se puede esquivar. Y **se apuntan en la sala
  antes de que la madre avise de que muere**: si no, las puertas se abrirían
  un instante con las crías vivas.
- **Caer por un agujero cuesta 30 de vida y no mata.** Se reaparece dentro de
  la puerta por la que se entró (que siempre está libre). Cuesta aunque se
  esté parpadeando tras un golpe (`recibir_dano(..., true)`): si no, caer
  justo después de un golpe saldría gratis.
- **Los peligros al azar nunca tapan el paso de una puerta al centro de la
  sala** (`ancho_paso`): así desde cualquier puerta se llega a cualquier otra.
  Se comprobó recorriendo en cuadrícula las salas de los 12 pisos. La
  excepción son los **pinchos de las puertas**, a propósito: salen a ratos y
  avisan, así que siempre se puede pasar. Agujeros o lava en una puerta no.
- **Los pinchos de una puerta van en un solo lado**, el de la sala de pelea, y
  con su propia semilla: con la de los demás peligros, añadirlos habría movido
  todos los que ya había (se comprobó que siguen exactamente igual).
- **El número de enemigos sube lo mismo en cada piso.** Antes se sumaba uno de
  más al azar por sala, y la media podía bajar de un piso al siguiente (del 7
  al 9: 4,7 / 4,5 / 4,3). Ahora la media sale de la fórmula y solo la parte
  decimal se reparte al azar.
- **La pared choca donde se ve.** Se mete en la sala, y lo que se ve y no
  choca se atravesaría: el jugador tiene que poder fiarse de lo que ve. En la
  de arriba se choca 16 px por encima del pie de la cara (`SUBE_CARA`): con
  vista 3/4 el cuerpo del mago se pinta delante de la cara. Delante de las
  puertas la pared se aparta, y deja libre el ancho entero del hueco.
- **Los salientes van en los bultos de la pared, no sueltos por el canto.**
  Sueltos parecían pirámides plantadas en el suelo; saliendo de un bulto se
  leen como parte de la roca. Los pisos sin pieza propia (1, 4 de roca, 8 y
  9) solo tienen los bultos.
- **Cada textura de la pared se lleva a la misma luz** (`a_luz` en el
  generador, con la `luz` de cada tema): sin eso la caliza y el oro salían
  casi blancos y le quitaban protagonismo a la sala.
- **Contra las rocas, la bola solo cuenta con su núcleo**
  (`BolaMagica.RADIO_CONTRA_ROCAS`, 10 px). Con su radio entero, agrandarla
  (orbe hinchado, ataque cargado) la hacía morir en cualquier roca que rozara:
  mejorarla te dejaba peor.
- **Las ventajas que sueltan los enemigos salen de la suerte, no de la
  semilla del piso.** Los pisos son fijos; el botín puede cambiar de una
  partida a otra. Y las crías no sueltan nada, o matar slimes sería la forma
  de conseguirlas.
- **Lo que solo cura (el vendaje) no se coge con la vida llena** (como en
  Isaac): recogerlo sin necesitarlo sería tirarlo. Por eso se mira quién lo
  toca en cada paso y no con `body_entered`: si llegas lleno, te quedas
  encima y te dan, tiene que poder cogerse sin salir y volver a entrar. Lo
  hacían los corazones del suelo; desde el 2026-10-14, el vendaje.
- **Lo que cae para recoger busca sitio con `Piso.sitio_libre_cerca()`**, la
  misma para las ventajas y los vendajes: nunca encima de un agujero, lava,
  pinchos, una roca o la bajada.
- **El muro se pinta alineado con el mundo, no con cada sala.** Las
  coordenadas de su textura salen de la posición en el piso, así que la roca
  sigue igual de una sala a otra y casa con la del fondo. Por eso los trozos
  que se pisan no se notan.
- **Los pilares van en la franja del muro, no en el suelo**, y son bajos para
  caber: en el suelo estorbarían sin chocar.
- **Los enemigos salen al azar**, como pidió Matías: cada sala elige entre los
  tipos que pueden salir a esa profundidad. Desde el 2026-11-04 con **tope por
  abajo** (`piso_maximo`): cada criatura tiene una variante por capa, y sin tope, los
  de la corteza seguirían saliendo en el núcleo.
- **El sprite del jugador se centra en los pies, no en el dibujo.** El báculo y
  el halo del nigromante sobresalen a la derecha; centrando el lienzo en el
  dibujo, el cuerpo se iría a la izquierda y dejaría de cuadrar con el círculo
  de colisión, que no se ha tocado (radio 15 en y=−16).

## Trampas ya pisadas (no repetirlas)

- **Para probar el cooperativo hacen falta dos juegos a la vez**, y el
  controlador de cada prueba tiene que **colgar de la raíz** (un nodo creado
  desde la escena de prueba con `root.add_child`): la escena de prueba se
  libera al empezar la partida (cambio de escena) y se llevaría la prueba.
  Uno con ventana para las capturas y otro con `--headless`, el anfitrión
  escuchando en `127.0.0.1` (`Red.ip_escucha`) para que Windows no pregunte
  por el cortafuegos. **Cada uno con su archivo de registro, nuevo en cada
  intento**: una prueba anterior colgada siguió escribiendo en el mismo y lo
  dejó ilegible (2026-10-16).
- **Sin ventana (`--headless`) no se dibuja nunca**, así que una prueba que
  espera `RenderingServer.frame_post_draw` para hacer una captura se queda
  parada para siempre (y Godot sin ventana gasta toda la CPU, que no es
  señal de bucle). La del cooperativo pareció un fallo del juego hasta verlo
  (2026-10-18): las capturas, siempre en el juego con ventana.
- **Un objeto ya liberado no se puede guardar en una variable con tipo**
  (`var e: Enemigo = diccionario.get(id)`): el motor da «Trying to assign
  invalid previously freed instance». Mirarlo antes como `Variant` con
  `is_instance_valid` (`MundoRed._enemigo`).
- **Cambiar un botón de sitio (`reparent`) lo vuelve a meter en el árbol**, y
  `Sonido` le conectaba el clic otra vez: error del motor por conexión
  repetida. Ahora mira si ya lo está (`Sonido._al_anadir_nodo`).
- **Exportar a Mac universal pide `import_etc2_astc` en el proyecto**
  (`rendering/textures/vram_compression/import_etc2_astc=true` en
  `project.godot`). Sin eso Godot se niega a exportar para arm64. Se vio
  intentando la exportación aquí sin la plantilla: Godot lista todos los
  errores de configuración, no solo el de la plantilla. El `.exe` de Windows
  no cambia (su preset tiene `etc2_astc=false`).
- **Un rebote no puede devolver el disparo a donde estaba.** El escudo
  dejaba el disparo rebotado en su sitio del paso anterior. Si ese sitio ya
  quedaba dentro de la burbuja (el mago andando hacia el disparo, o la
  burbuja abriéndose encima), volvía a él en cada paso y se quedaba pegado
  hasta que acababa el escudo (lo vio Matías jugando). Se arregló el
  2026-10-15 sacándolo al borde: por donde la tocó si rebota, por donde está
  ahora si ya se alejaba. Ojo: el escudo mira también el sitio de antes del
  disparo, que con la burbuja moviéndose cuenta como tocarla aunque el
  disparo ya se aleje; sacarlo con la normal de ese sitio también lo
  pegaba. Medido con el mago andando de verdad (`Input.action_press`): con
  la posición cambiada a mano su `velocity` es 0 y el fallo no sale.
- **Intocable no puede querer decir inmortal.** Con los comportamientos, un
  enemigo escondido o desvanecido no recibe daño (`herir` lo ignora), y
  `matar()` (F4) pasaba por ahí: dejaba vivos al fantasma y a la planta bajo
  tierra, y la sala no se abría. `matar()` va directo a `_quitar_vida()`. Lo
  destapó la revisión de las 63 salas: 18 no se abrían.
- **En GDScript, una función anónima copia las variables locales al crearse.**
  Un contador sumado dentro de una lambda conectada a una señal se queda a 0
  fuera. Para contar desde una lambda, un diccionario o un array (que se
  comparten).

- **Los enemigos despiertan al asomarse a su sala, no al entrar del todo.**
  Las puertas sí esperan a que el jugador entre del todo (el rastrillo no
  puede caerle encima), y si los enemigos esperaban a eso, desde el umbral se
  veían congelados y se les podía disparar sin que reaccionaran. Ahora
  `Sala.asomar()` los despierta cuando la sala pasa a ser la actual y los
  vuelve a dormir si el jugador se va sin entrar.
- **Ya no hay distancia de visión por enemigo.** Era de antes de las salas:
  en una sala de 1400 px, la planta venenosa (360) se quedaba plantada con
  las puertas cerradas hasta que te acercabas. Despierto, un enemigo va a por
  ti esté donde esté de su sala. La revisión de las 63 salas con enemigos
  (2026-10-09) comprobó que todos se mueven o disparan.

- **Cerrar el juego con música sonando deja un aviso del motor** («1
  resources still in use at exit»), y la prueba de arranque de la release lo
  toma por un error. La canción parada la suelta el bucle del juego en el
  fotograma siguiente; al cerrar ya no lo hay, y esperar dentro del cierre
  (`OS.delay_msec`) no sirve. Comprobado con una escena de un solo
  reproductor: es del motor. Por eso se sale siempre por `Sonido.salir()`
  (para el sonido, espera 0,2 s y cierra; cerrar la ventana también pasa por
  ahí, con `auto_accept_quit = false`), y sin pantalla (`--headless`) la
  música se elige pero no se reproduce.
- **La música se iguala por volumen medio (RMS), no por pico.** Por pico, la
  de los pisos hondos (dron y tambores, poca diferencia entre pico y media)
  sonaba casi 4 dB más fuerte que la de arriba.

- **Un ejecutable de Linux suelto no se abre al bajarlo con el navegador.**
  Pierde el permiso de ejecutarse y Ubuntu dice que no encuentra «la
  aplicación predeterminada para application/x-executable» (le pasó a Matías
  con la 0.1 en el instituto). La release lo publica dentro de
  `Vacio-linux.tar.gz`, que conserva el permiso, y el workflow comprueba que
  va con él.

- **Muchas piezas con texturas alternadas hunden el rendimiento.** La pared
  nueva bajó el piso 1 de 946 a 600 FPS sin límite: casi cien adornos por
  sala, pintados uno detrás de otro cambiando de textura, rompían los lotes de
  dibujo. Agrupados por textura (`ParedSala.levantar`) y con la sombra y la
  cara en trozos de 20-30 px, se quedó en 911. Medido apagando cada parte por
  turnos, no a ojo.
- **Un resplandor (halo) necesita margen en su lienzo.** Los cristales que
  llegaban al borde de su imagen cortaban el halo en recto y se veía la caja.

- **En el juego exportado, `DirAccess` ve `nombre.tres.remap`, no
  `nombre.tres`.** Godot pasa los `.tres` a binario al exportar. Las tres
  funciones que leen carpetas (`_listar_recursos` en `gestor_progreso.gd`,
  `_cargar_tipos` en `mecanicas/enemigos.gd` y
  `ObjetoMejora.cargar_todos`, que usan la mecánica de objetos y el cofre de
  la sala secreta) ya quitan el `.remap`; una cuarta que se escriba tiene
  que hacer lo mismo, o en el `.exe` no cargará nada aunque en el editor
  funcione.
- **El servidor de las releases de GitHub no acepta `Range: bytes=-N`** (los
  últimos N bytes): responde 501. `instalar_plantillas.py` pide primero
  el tamaño con un HEAD y luego el rango exacto.

- **En Python, `open(ruta, "w", ...)` vacía el archivo antes de comprobar el
  resto de argumentos.** Un `newline` mal escrito hizo fallar la llamada, y
  `generar_bordes.py` (aún sin subir) se quedó a 0 bytes. Hubo que rehacerlo.
  Antes de reescribir un archivo desde un script: que esté en git, o
  escribirlo con la herramienta de archivos.
- **Con vsync, el monitor de tiempo de física engaña.** Marcaba 12 ms en el
  piso 12 tras los bordes nuevos y 2,4 sin ellos. Con el vsync quitado, los
  dos daban 13 ms, y los FPS reales eran 900 frente a 1000: el coste de verdad
  eran 0,1 ms por fotograma. Para medir rendimiento, FPS sin vsync y comparar
  con el código de antes (`git stash`).
- **Las salas en diagonal también existen.** Alargué la roca de cada sala por
  los lados sin puerta pensando que ahí no había nadie. Pero la sala de la
  diagonal alargaba la suya hacia el mismo hueco, con el degradado hacia otro
  lado, y se veían cortes rectos. Se arregló pintando todo alineado con el
  mundo y un fondo único.

- **Un tween que esconde algo se cancela si ese algo vuelve a mostrarse.**
  El aviso del HUD creaba un desvanecido nuevo con cada objeto y el anterior
  seguía corriendo: al coger dos objetos en menos de 3 s, el del primero
  escondía el aviso del segundo al segundo de salir. No se notaba con un
  objeto por piso; con los enemigos soltando ventajas, sí. Se guarda el tween
  y se hace `kill()` antes de crear otro.

- **Una prueba que usa el jugador de verdad acumula lo que recoge.** En la
  partida entera, el jugador de la prueba iba cogiendo ventajas y la bola
  llegó a radio 23. Con eso destapó un fallo real (la bola moría en cualquier
  roca que rozara), pero antes de verlo supuse que era un enemigo metido en
  una roca y lo "arreglé" sin comprobarlo. Medir primero: el mismo disparo
  con radio 11 y con radio 23 lo dejó claro.

- **En el `fragment()` de un shader de canvas, `COLOR` ya trae la textura
  multiplicada.** El de la lava hacía `COLOR = texture(TEXTURE, UV) * COLOR`
  y pintaba la textura al cuadrado: el borde de basalto salía negro y el
  resplandor, que es semitransparente, desaparecía. Se vio comparando el mismo
  charco con y sin shader en una captura. El tinte se coge en `vertex()` y se
  pasa con un `varying`.
- **Para medir si algo se anima, la cámara tiene que estar quieta.** La
  primera medida de la lava daba mucho cambio entre dos capturas, pero las
  rocas también cambiaban: era la cámara acabando de moverse. Con una zona de
  control (suelo y rocas a 0) se ve lo que es de verdad animación.

- **Un `Area2D` no detecta los `StaticBody2D` en Godot 4.7.** Las bolas son
  `Area2D` y las rocas `StaticBody2D`, así que las rocas **nunca** pararon
  ninguna bola, aunque este archivo decía que sí. Se comprobó con una roca
  del pool, una movida y una recién creada: las tres dejaban pasar la bola. Al
  jugador (`CharacterBody2D`) sí lo detecta. Lo destapó el 2026-09-29 la
  prueba de que las rocas paran el veneno. Ahora el terreno se consulta a mano
  en cada paso con `Terreno.choque()` (rayo del tramo recorrido y círculo en
  el punto nuevo). **Todo lo que tenga que chocar con rocas o muros siendo un
  `Area2D`, por ahí.**

- **Lo que se vuelve a llamar al reiniciar tiene que partir de valores fijos.**
  `usar_personaje()` sumaba la ventaja a los valores de fábrica, y Principal la
  llama también en cada reinicio: tres reinicios dejaban al mago rojo con 7
  corazones, 165 de velocidad y una carga de 0,05 s. Lo encontró la revisión
  del 2026-09-29, no jugando: nadie reinicia tres veces seguidas probando.
- **`body_entered` avisa una vez, al entrar.** El daño de los enemigos iba por
  ahí, y como se quedan encima del jugador, solo pegaban al primer contacto:
  cuatro segundos con un enemigo encima costaban un corazón. Para «mientras
  toque», `get_overlapping_bodies()` en cada paso.
- **Lo que se reparte después de las rocas tiene que mirarlas.** Los enemigos
  se colocaban sin mirarlas: 38 de 164 salían encima de una y 3 enterrados. Con
  el cristal vivo, que no se mueve, la bola choca con la roca antes de
  llegarle: enterrado del todo, la sala podría no abrirse nunca (no se llegó a
  ver pasar; se arregló al medir el solape).
- **Nunca `git add -A` en este repo: se añaden los archivos por su ruta.** En
  esta carpeta trabaja más de uno a la vez. El 2026-09-24, mientras se hacían
  las salas, Matías añadió 121 archivos (7 enemigos nuevos en
  `assets/enemigos/` y el pack `assets/manto/`) y un `git add -A` los subió
  dentro del commit del minimapa (`cb5a4f6`), con un mensaje que no los
  menciona. Se quedan ahí, porque son suyos y los quería subidos, pero pudo no
  ser así. Antes de cada commit: `git status`, y añadir solo lo propio.
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
