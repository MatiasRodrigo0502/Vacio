# Vacío

> Proyecto 1 DAM

**Todo lo hecho hasta ahora, en un documento:** [docs/todo-lo-hecho.md](docs/todo-lo-hecho.md)

Juego 2D top-down de habilidad hecho en **Godot 4.7** (GDScript). El jugador
desciende piso a piso por una estructura con forma de embudo: 12 niveles fijos
basados en las capas de la Tierra, de la corteza continental al núcleo interno.
Cada piso es un mapa de salas unidas por puertas, y cada uno tiene más salas,
más pequeñas, y se ve menos que el anterior.

Estado: **jugable de principio a fin**, y en pleno giro hacia algo parecido a
*The Binding of Isaac*. Menú principal, los 12 pisos, disparo, enemigos que te
persiguen o te disparan de lejos, pinchos, lava y agujeros en el suelo, objetos
que te mejoran, pausa, victoria y derrota. Se elige entre **tres magos**, cada uno con
sus ventajas, y miran a los ocho lados; el piso 1 hace de tutorial. Cada uno de los 12 pisos
tiene su propia pared y sus propias rocas, de la roca de su capa: de la tierra con hierba del
piso 1 al cristal de hierro al rojo blanco del 12.

## Descargar el juego

La última versión, lista para jugar sin instalar nada ni tener Godot:

- **Windows:** [Vacio.exe](https://github.com/MatiasRodrigo0502/Vacio/releases/latest/download/Vacio.exe).
  Puede avisar de que es de un editor desconocido (no está firmado):
  *Más información → Ejecutar de todas formas*.
- **Linux:** [Vacio-linux.tar.gz](https://github.com/MatiasRodrigo0502/Vacio/releases/latest/download/Vacio-linux.tar.gz).
  Se extrae (clic derecho → *Extraer aquí*) y se abre `Vacio.x86_64` con
  doble clic. Va comprimido porque un programa suelto bajado con el navegador
  pierde el permiso de ejecutarse, y Ubuntu no lo abre («no se ha encontrado
  la aplicación predeterminada para application/x-executable»); dentro del
  `.tar.gz` el permiso se conserva. La 0.1 lleva el archivo suelto: para
  abrirlo, clic derecho → *Propiedades* → *Ejecutable como programa*, o
  `chmod +x Vacio.x86_64` en una terminal.

Página de la release:
[releases/latest](https://github.com/MatiasRodrigo0502/Vacio/releases/latest).

**Cada vez que el juego cambia hay una versión nueva**, con su número: la
0.1, la 0.2, la 0.3... GitHub la publica sola con cada push a `main`
(`.github/workflows/publicar.yml`, unos minutos), con su etiqueta (`v0.1`...),
sus dos archivos y la lista de lo que cambia desde la anterior. Los enlaces de
arriba llevan siempre a la última, y las anteriores siguen en
[releases](https://github.com/MatiasRodrigo0502/Vacio/releases). Si solo cambian
archivos `.md`, no hay versión nueva. Antes de publicar, GitHub arranca la
versión de Linux y no publica nada si da errores.

El juego enseña su versión abajo a la derecha del menú. El `.exe` de cada
ordenador (ver abajo) dice «0.3 + cambios» si tiene cosas que aún no están en
ninguna versión publicada, y desde Godot dice «en desarrollo».

## Jugar sin Godot: `build/`

El juego exportado es **un solo archivo** por sistema, que se abre sin tener
Godot: `build/Vacio.exe` para Windows y `build/Vacio.x86_64` para Linux. No se
suben a git (pesan 110 y 78 MB); cada uno los genera en su ordenador, y **se
rehacen solos después de cada commit y cada pull**, en segundo plano (unos 15
segundos). Se pueden abrir mientras se actualizan: el abierto sigue
funcionando y la próxima vez arranca el nuevo.

Para que funcione, una sola vez por ordenador:

```bash
python herramientas/instalar_plantillas.py
git config core.hooksPath .githooks
```

La primera línea baja de la release oficial de Godot solo las plantillas de
Windows y Linux (66 MB en vez del paquete entero de 1,28 GB). La segunda activa
los hooks de `.githooks/`: git no los activa solo, por seguridad.

Si Godot no está en una de las rutas que conoce el script, hay que definir la
variable `GODOT` con la ruta del ejecutable de Godot (o añadirla en
`herramientas/exportar.sh`). Para rehacerlos a mano, sin commit:
`bash herramientas/exportar.sh`. Si una exportación falla, la versión anterior
se queda y el motivo está en `build/exportar.log`.

## Controles

| Acción | Tecla |
|---|---|
| Moverse | WASD |
| Disparar | Flechas, o clic izquierdo apuntando con el ratón |
| Ataque especial | Clic derecho o espacio, **una vez por piso**. Mago oscuro y rojo: **mantenido**, carga una bola que se suelta cuando el aro se cierra (apunta al ratón). Mago blanco: saca el escudo |
| Pausa (continuar, reiniciar o volver al menú) | Esc |

No hace falta memorizarlos: están en el botón **Controles** del menú, y además
el piso 1 hace de tutorial y los explica con carteles pintados sobre el suelo,
cada uno donde hace falta.

### Atajos de prueba (solo para el equipo)

Para probar y equilibrar sin jugar la partida entera. **Solo funcionan al jugar
desde Godot** (el editor o `jugar.bat`); en el juego exportado no existen. Se recuerdan
abajo a la izquierda de la pantalla, en rojo mientras eres invencible.

| Tecla | Qué hace |
|---|---|
| F1 | Invencible sí / no: ni los golpes ni las caídas quitan vida |
| F2 | Piso anterior |
| F3 | Piso siguiente |
| F4 | Mata a los enemigos de la sala en la que estás (con explosiones y crías) |
| F5 | Recupera el ataque especial, que si no es uno por piso |

Al equilibrar, ojo con dejar puesta la invencibilidad: un piso parece fácil
cuando no te pueden dar.

## Cómo se juega ahora mismo

Cada piso es un **mapa de salas** unidas por puertas, como en *Isaac*. Empiezas
en una sala tranquila y tienes que encontrar la que tiene el **agujero** para
bajar al siguiente piso, con la vida que te quede.

- **Al entrar en una sala con enemigos, las puertas se cierran** y no se abren
  hasta que acabas con todos. Los enemigos duermen hasta que entras.
- **La bajada está tapada** hasta que limpias su sala, que siempre es la más
  lejana del inicio.
- En cada piso hay una **sala con un objeto** en algún callejón: cogerlo es
  desviarte del camino.
- Arriba a la derecha va un **minimapa**: las salas en las que has estado, las
  de al lado en contorno, y el objeto y la bajada marcados en cuanto las
  conoces. El resto se descubre andando.
- Cuanto más bajas, más salas y más pequeñas, y la cámara se cierra más: en
  los pisos hondos ya no ves la sala entera.

Antes de empezar eliges **con qué mago juegas**, y no es solo el color:

| Mago | Ventaja | Pega |
|---|---|---|
| **Mago oscuro** | Anda un 13 % más rápido, y su bola cargada abre un **agujero negro** donde se acaba, que atrae a los enemigos y quita vida a los del centro | Su bola cargada llega menos lejos que la del rojo |
| **Mago rojo** | Un corazón más, y el ataque cargado sale en medio tiempo y mata de un golpe a cualquier cosa. Sus disparos **queman**: 0,25 de vida por segundo durante 3 s | Anda un 9 % más lento |
| **Mago blanco** | Su ataque especial es un escudo pequeño delante que para los disparos enemigos de frente durante 5 s. Sus disparos frenan a los enemigos a la mitad durante 1,5 s | Su disparo normal quita la mitad y no tiene bola cargada |

La ventaja dura toda la partida y no se pierde al reiniciar: es lo que *es* ese
mago, no un objeto que se recoge.

Sea cual sea, el mago se gira a **ocho direcciones**, diagonales incluidas, y
mira hacia donde disparas antes que hacia donde andas: si estás peleando de
espaldas, te ve a ti y no a la salida.

Las rocas y plataformas son sólidas: no se cruzan ni se rompen, pero te sirven
de parapeto. Lo que te quita vida son los **enemigos** al tocarte, con ~1 s de
invulnerabilidad después de cada golpe. Del piso 2 en adelante los hay, y van a
más según bajas.

Disparas bolas mágicas para matarlos, con las flechas en las cuatro direcciones
o con el clic izquierdo apuntando donde quieras: una cada medio segundo,
aunque mantengas el botón.

Manteniendo el **clic derecho** o el **espacio** cargas un ataque más fuerte: delante del mago se
forma una bola morada que crece, y un aro que se va cerrando dice cuánto falta.
Cuando el aro se cierra, sueltas y sale. Atraviesa a los enemigos y mata de un
golpe a los que hay ahora, pero las rocas lo paran igual que al disparo normal.
Mientras cargas no puedes disparar, y si sueltas antes de tiempo no sale nada:
o está cargado o no hay ataque.

La bola del mago oscuro llega menos lejos (320 px, media sala) y, donde se
acaba, abre un **agujero negro** durante 2,5 s: tira de los enemigos que están
cerca hacia su centro y a los que llegan les quita vida (2 por segundo).

El mago blanco no carga bola: con ese mismo botón saca su **escudo**, un arco
pequeño delante que para los disparos enemigos que le llegan de frente. Dura
5 s y parpadea cuando se va a acabar.

**El ataque especial, sea cual sea, es uno por piso.** Arriba a la izquierda,
debajo de la vida, pone si te queda («ESPECIAL · AGUJERO NEGRO») o si ya lo
has usado. Vuelve al bajar al piso siguiente.

En cada piso hay además un objeto que te mejora para el resto de la partida, y
las mejoras se notan también en el ataque cargado, que parte de esos números.

Superar el piso 12 gana; quedarte sin vida termina la partida.

### Sonido y música

Todo el sonido es nuestro: lo generan por síntesis
`herramientas/generar_efectos.py` (20 efectos) y `generar_musica.py` (la
música), sin nada bajado. Suena una música en la portada, otra en los pisos
1 a 6 y otra más grave, con tambores, en los 7 a 12; al ganar y al perder,
la suya. Hay efecto para los disparos (los tuyos y los de cada enemigo), los
golpes, las muertes, las explosiones, las puertas, los objetos, el escudo, el
agujero negro, caer, bajar de piso y los botones.

El volumen de la música y el de los efectos se cambian abajo a la izquierda
de la portada o en el menú de pausa (Esc), y se recuerdan para la próxima
vez.

## Estructura del proyecto

```
Vacio/
├── project.godot          # autoload, mapa de teclas, capas de física
├── scenes/
│   ├── MenuPrincipal.tscn # ESCENA PRINCIPAL: jugar, controles, salir
│   ├── Principal.tscn     # la partida: monta pisos, jugador, cámara, HUD
│   ├── Piso.tscn          # UNA escena genérica para los 12 pisos
│   ├── Tutorial.tscn      # carteles de controles (solo en los pisos que lo piden)
│   ├── Jugador.tscn
│   ├── Obstaculo.tscn     # bloque reciclado por el pool
│   ├── Hud.tscn
│   └── PantallaFinal.tscn # victoria y derrota comparten pantalla
├── scripts/
│   ├── gestor_progreso.gd # AUTOLOAD: piso actual, los 12 DatosPiso, victoria
│   ├── datos_piso.gd      # class_name DatosPiso extends Resource
│   ├── mecanica.gd        # class_name Mecanica extends Resource (clase base)
│   ├── menu_principal.gd
│   ├── principal.gd
│   ├── piso.gd
│   ├── tutorial.gd
│   ├── jugador.gd
│   ├── camara_juego.gd
│   ├── obstaculo.gd
│   ├── pool_obstaculos.gd
│   ├── hud.gd
│   └── pantalla_final.gd
├── resources/
│   ├── pisos/             # los 12 .tres, uno por capa (ver su README)
│   ├── enemigos/          # un .tres por tipo de enemigo (ver su README)
│   ├── objetos/           # un .tres por objeto recogible (ver su README)
│   └── mecanicas/         # .tres de mecánicas (vacío en Fase 1, ver su README)
└── assets/
    ├── mago_oscuro/   # mago elegible: atlas de 8 direcciones + su SpriteFrames
    ├── mago_rojo/     # el otro mago elegible, mismo formato
    ├── bordes/        # la pared de las salas, una por piso (+ la reja)
    ├── rocas/         # las rocas de dentro, una por piso
    ├── sonido/        # efectos/ y musica/, generados (ver herramientas/)
    ├── titulo/        # el título del menú, generado
    └── cueva/, musgo/, manto/, nucleo/  # packs de antes, ya sin usar
```

## Decisiones de arquitectura

**Las reglas viven en el autoload, no en la escena.** `GestorProgreso` es el
único sitio que sabe en qué piso estamos y cuándo se gana. `Principal.tscn` solo
reacciona a sus señales y monta/desmonta escenas. Cuando haya menús o modos de
juego, la vista cambia y las reglas no.

**Los datos de piso son Resources, uno por archivo.** Reequilibrar el juego no
toca código ni escenas: se editan `.tres`. Y como el gestor lee la carpeta
entera ordenada por nombre, añadir o quitar pisos tampoco toca código.

**Una sola escena de piso para los 12.** La geometría (muros, salida, reparto de
obstáculos) se genera en runtime desde el `.tres`. 12 escenas casi idénticas
serían 12 sitios que mantener y 12 focos de conflicto de merge.

**Las mecánicas son Resources con `piso_desbloqueo`.** El gestor no conoce
ninguna mecánica concreta: las carga de la carpeta y pregunta si están activas
en este piso. Añadir una mecánica nueva = un script + un `.tres`, sin tocar el
gestor ni el piso.

**Pooling de obstáculos.** El pool cuelga de `Principal`, no del piso: si
viviera dentro del piso se destruiría en cada transición y no habría reciclaje.
Los obstáculos se crean una vez y cambian de posición al cambiar de piso.

**Pisos deterministas.** El reparto de obstáculos usa una semilla derivada del
piso, así que los 12 niveles son fijos y reproducibles en las tres máquinas.

## Trabajo en equipo (3 personas)

La regla práctica para no pisarse:

- **Ajustar dificultad** → solo `resources/pisos/piso_NN_*.tres`. Un piso por
  persona, cero conflictos.
- **Mecánicas nuevas** → un script nuevo en `scripts/` + un `.tres` nuevo en
  `resources/mecanicas/`. Nada de código compartido que tocar.
- **Escenas `.tscn`** → son el recurso más conflictivo (Godot reordena y
  renumera al guardar). Que las toque una persona por rama y se avisa.
- `.godot/` y los `*.import` están en `.gitignore`: se regeneran solos. Si
  aparecen en un `git status`, algo va mal.
- Los `*.gd.uid` **sí se versionan** (recomendación oficial de Godot 4.4+): son
  el identificador estable de cada script, y si cada persona genera el suyo las
  escenas empiezan a apuntar a scripts distintos.
- `.gitattributes` fuerza LF en todos los archivos de texto para que Windows no
  genere diffs falsos.
- `export_presets.cfg` **sí se versiona**: es la receta del `.exe` y del ejecutable de Linux. Si alguien
  cambia la exportación desde el editor, se sube como cualquier otro cambio.

## Qué NO está hecho todavía (fases siguientes)

Sistema de puntuación y guardado. Los obstáculos móviles ya
están: del piso 4 en adelante, parte de las rocas van y vienen, y es la primera
`Mecanica` del proyecto. El suelo sigue siendo color
plano a propósito: ninguno de los packs trae una textura cenital repetible, y
el color interpolado por profundidad es lo que comunica las 12 capas. La Fase 1 deja los enganches puestos:
`velocidad_obstaculos` ya llega a cada obstáculo, y `Mecanica` ya se carga y se
aplica aunque todavía no haya ninguna.
