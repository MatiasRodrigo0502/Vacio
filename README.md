# Vacío

> Proyecto 1 DAM

**Todo lo hecho hasta ahora, en un documento:** [docs/todo-lo-hecho.md](docs/todo-lo-hecho.md)

Juego 2D top-down de habilidad hecho en **Godot 4.7** (GDScript). El jugador
desciende piso a piso por una estructura con forma de embudo: 12 niveles fijos
basados en las capas de la Tierra, de la corteza continental al núcleo interno.
Cada piso es un mapa de salas unidas por puertas, y cada uno tiene más salas,
y más pequeñas, que el anterior.

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
- **Mac:** [Vacio-mac.zip](https://github.com/MatiasRodrigo0502/Vacio/releases/latest/download/Vacio-mac.zip)
  (desde la 0.21). Se abre el `.zip` y luego `Vacio.app`; vale para los Mac
  con chip de Apple y para los de Intel. **La primera vez** macOS dice que no
  puede comprobar si es segura, porque no está verificada por Apple (eso
  cuesta 99 € al año): *Ajustes del Sistema → Privacidad y seguridad → Abrir
  igualmente*. Solo una vez. En versiones de macOS anteriores a la 15 basta
  con clic derecho sobre la app → *Abrir*.

Página de la release:
[releases/latest](https://github.com/MatiasRodrigo0502/Vacio/releases/latest).

**Cada vez que el juego cambia hay una versión nueva**, con su número: la
0.1, la 0.2, la 0.3... GitHub la publica sola con cada push a `main`
(`.github/workflows/publicar.yml`, unos minutos), con su etiqueta (`v0.1`...),
sus archivos (Windows, Linux y Mac) y la lista de lo que cambia desde la anterior. Los enlaces de
arriba llevan siempre a la última, y las anteriores siguen en
[releases](https://github.com/MatiasRodrigo0502/Vacio/releases). Si solo cambian
archivos `.md`, no hay versión nueva. Antes de publicar, GitHub arranca la
versión de Linux y la de Mac (en un Mac de verdad, que presta GitHub), y no
publica nada si alguna da errores. En Mac también comprueba que va firmada y
que trae los dos procesadores.

El juego enseña su versión abajo a la derecha del menú. El `.exe` de cada
ordenador (ver abajo) dice «0.3 + cambios» si tiene cosas que aún no están en
ninguna versión publicada, y desde Godot dice «en desarrollo».

**Desde la 0.18, el juego avisa solo cuando hay una versión más nueva.** Al
abrirlo pregunta a GitHub y, si la hay, sale un aviso encima del número de
versión con lo que trae. En Windows, *Actualizar ahora* baja el `.exe` nuevo
(unos 115 MB), lo pone en lugar del de ahora y, con *Abrirla ahora*, se abre
ya la versión nueva. Si no, será la que se abra la próxima vez. En Linux, el
botón lleva a la página de descarga. Sin internet no sale nada y se juega
igual. Las versiones de antes de la 0.18 no saben avisar: quien tenga una de
esas tiene que bajar la última a mano una vez.

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

**La de Mac solo la saca GitHub**, para la release: hace falta la plantilla
de Mac (`instalar_plantillas.py --mac`) y en los ordenadores del equipo no
merece la pena. Quien la quiera en local, con esa plantilla y
`EXPORTAR_MAC=1 bash herramientas/exportar.sh`.

Si Godot no está en una de las rutas que conoce el script, hay que definir la
variable `GODOT` con la ruta del ejecutable de Godot (o añadirla en
`herramientas/exportar.sh`). Para rehacerlos a mano, sin commit:
`bash herramientas/exportar.sh`. Si una exportación falla, la versión anterior
se queda y el motivo está en `build/exportar.log`.

## Controles

| Acción | Tecla |
|---|---|
| Moverse | WASD (o las flechas: se elige en **Controles**) |
| Disparar | Flechas (o WASD, si te mueves con las flechas), o clic izquierdo apuntando con el ratón |
| Ataque especial | Clic derecho o espacio, **una vez por piso**. Mago oscuro y rojo: **mantenido**, carga una bola que se suelta cuando el aro se cierra. Con el clic derecho sale hacia el ratón; con el espacio, hacia donde apuntan las flechas o, sin ninguna, hacia donde mira el mago (para jugar sin ratón). Mago blanco: saca el escudo |
| Pausa (continuar, reiniciar o volver al menú) | Esc |
| Pantalla completa o ventana | F11 (o Alt+Intro). El juego empieza a pantalla completa y se acuerda de lo último que elegiste |

En el panel **Controles** del menú se elige **moverse con WASD o con las
flechas**. Con las flechas, se dispara con WASD: son las mismas dos manos al
revés. Se acuerda para la próxima vez, y los carteles del piso 1 dicen las
teclas que hayas elegido.

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
- Cuanto más bajas, más salas y más pequeñas. La cámara está igual de lejos
  en todos los pisos, así que los enemigos, las rocas y el mago se ven
  siempre del mismo tamaño, y la sala entera cabe en pantalla.
- **Solo se ve la sala en la que estás**: lo que asoma de las de al lado
  queda a oscuras (más cuanto más hondo, porque las salas encogen), y al
  cruzar una puerta la luz se desliza con la cámara.

Antes de empezar eliges **con qué mago juegas**, y no es solo el color:

| Mago | Ventaja | Pega |
|---|---|---|
| **Mago oscuro** | Anda un 13 % más rápido, y su bola cargada abre un **agujero negro** donde se acaba, que atrae a los enemigos y quita vida a los del centro | Su bola cargada llega menos lejos que la del rojo |
| **Mago rojo** | 30 de vida más, y el ataque cargado sale en medio tiempo y quita 50: mata de un golpe a cualquier enemigo. Sus disparos **queman**: 3 de vida por segundo durante 3 s | Anda un 9 % más lento |
| **Mago blanco** | Su ataque especial es una burbuja que lo cubre entero durante 5 s: los disparos rebotan en ella (y los rebotados dañan a los enemigos) y los enemigos que la tocan salen despedidos. Sus disparos frenan a los enemigos a la mitad durante 1,5 s | No tiene bola cargada: su ataque especial protege, pero no hace daño |

La ventaja dura toda la partida y no se pierde al reiniciar: es lo que *es* ese
mago, no un objeto que se recoge.

Al acabar una partida (ganes o pierdas), además de volver a empezar con el
mismo mago (botón o tecla R), puedes darle a **Cambiar mago**: salen los
magos que no has usado en esa partida y empiezas de cero, en el piso 1, con
el que elijas.

Sea cual sea, el mago se gira a **ocho direcciones**, diagonales incluidas, y
mira hacia donde disparas antes que hacia donde andas: si estás peleando de
espaldas, te ve a ti y no a la salida.

Las rocas y plataformas son sólidas: no se cruzan ni se rompen, pero te sirven
de parapeto. Lo que te quita vida son los **enemigos** al tocarte, con ~1 s de
invulnerabilidad después de cada golpe.

**La vida va en puntos** (desde la 0.25): tienes **100** (130 el mago rojo), en
una barra arriba a la izquierda que baja lo que te quita cada golpe; lo que se
acaba de perder se queda un momento en blanco. Cada golpe enseña encima del
mago lo que te ha quitado, en rojo. A los enemigos les pasa lo mismo: al
darles salta **el número de vida que les quitas** (blanco el disparo normal,
dorado y grande el cargado, naranja la quemadura y violeta el agujero negro).
Un disparo normal quita **10** (hasta 13: varía un poco hacia arriba) y el
cargado 30; una rata o un murciélago tienen 10, un slime 20, un gólem 50. Un
golpe de un enemigo te quita de 20 (una rata) a 45 (el magma del gólem), y
el **vendaje** cura 60. Es lo único que cura: sale como objeto, a veces lo
suelta un enemigo y, al limpiar una sala, cae uno de cada cuatro veces. Con
la vida llena no se coge: se queda en el suelo para luego. Del piso 2 en adelante los hay, y van a
más según bajas. **Cada uno pelea a su manera**: los slimes saltan (el de
magma dejando lava) o rebotan por la sala, la rata corre en zigzag, el
murciélago se lanza en picado, el fantasma atraviesa rocas y se desvanece, la
planta azul se entierra y sale debajo de ti, la serpiente dispara en abanico,
la planta venenosa suelta anillos de esporas, el gólem da pisotones con onda y
el cristal se teletransporta. Todos avisan antes de lo que pega de golpe. Lo
que hace cada uno está en [`resources/enemigos/`](resources/enemigos/README.md).

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

El mago blanco no carga bola: con ese mismo botón saca su **escudo**, una
burbuja que lo cubre entero durante 5 s (parpadea cuando se va a acabar). Los
disparos enemigos rebotan en ella (el magma del gólem bota y cae fuera) y, si
el rebote da a un enemigo, le quita lo mismo que te habría quitado a ti. Los
enemigos que la tocan salen despedidos. Mientras está, nada de lo que lanzan
los enemigos le quita vida; lo del suelo (lava, pinchos, caer) sí.

**El ataque especial, sea cual sea, es uno por piso.** Arriba a la izquierda,
debajo de la vida, pone si te queda («ESPECIAL · AGUJERO NEGRO») o si ya lo
has usado. Vuelve al bajar al piso siguiente.

En cada piso hay además un objeto que te mejora para el resto de la partida, y
las mejoras se notan también en el ataque cargado, que parte de esos números.

**El piso 12 acaba en la sala del jefe.** De su sala más lejana sale una
**antesala** tranquila, sin enemigos, con un vendaje y un **altar** que, al
pisarlo, recupera el ataque especial. Delante hay una puerta con runas que
brillan, y detrás está la **sala del jefe**: más grande que las demás (la
cámara se abre para que se vea entera), con un sello grabado en el suelo,
cuatro pilares de cristal para cubrirse y la bajada en el centro. En el
minimapa sale con una estrella roja desde que pisas la antesala.

**El jefe es el Mago Caído**, el cuarto mago, el que bajó antes que tú:
negro y oro, con una guadaña. Se presenta al cerrarse las puertas, su vida sale en una barra abajo y, en vez
de bolas, dispara **rayos** (con su línea de aviso). Además usa lo de los
otros tres magos, más cuanto menos vida le queda:

- **Fase 1:** el agujero negro del oscuro, al revés: se abre donde estás y
  tira de ti. Sal mientras crece.
- **Fase 2:** el escudo del blanco: no se le puede dar y suelta anillos de
  esquirlas de hielo que frenan. Y los rayos salen de tres en tres.
- **Fase 3:** el ataque cargado del rojo: un rayo de fuego enorme que deja la
  sala ardiendo. Un pilar te cubre, pero el rayo lo rompe: cada pilar sirve
  una vez. Y los rayos salen de cinco en cinco.

Cada fase va más deprisa que la anterior.

Al cambiar de fase suelta una onda y deja un vendaje. Mientras vive, la bajada
está tapada; al morir se abre. Sus números están en
[`resources/jefes/`](resources/jefes/README.md).

Superar el piso 12 gana; quedarte sin vida termina la partida.

### Sonido y música

Todo el sonido es nuestro: lo generan por síntesis
`herramientas/generar_efectos.py` (23 efectos) y `generar_musica.py` (la
música), sin nada bajado. Suena una música en la portada, otra en los pisos
1 a 6, otra más grave, con tambores, en los 7 a 12, y la del jefe, más
rápida, en su pelea; al ganar y al perder, la suya. Hay efecto para los disparos (los tuyos y los de cada enemigo), los
golpes, las muertes, las explosiones, las puertas, los objetos, el escudo, el
agujero negro, caer, bajar de piso y los botones.

El volumen de la música y el de los efectos se cambian abajo a la izquierda
de la portada o en el menú de pausa (Esc), y se recuerdan para la próxima
vez.

### Cooperativo en red local

Hasta **3 jugadores en la misma red** (la wifi de clase o de casa), cada uno
en su ordenador. En **Jugar → Cooperativo en red local**:

1. Uno pulsa **Crear sala** y le sale un código de 7 letras y números
   (`30AG-R1N`). Si Windows pregunta por el cortafuegos, hay que darle permiso
   en redes privadas, o los demás no podrán entrar.
2. Los demás escriben ese código y pulsan **Unirse**. También vale la
   dirección que sale debajo (`192.168.1.37`).
3. Cada uno elige un mago **distinto**, y quien creó la sala pulsa
   **Empezar**.

Tenéis que tener **la misma versión** del juego: si no, la sala no deja
entrar. Se juega **la partida entera**, del piso 1 al jefe:

- **Las peleas son de todos:** cuando uno entra en una sala con enemigos, se
  cierran las puertas y los demás aparecen dentro. Una sala a la vez.
- **Los enemigos tienen más vida** cuantos más sois (×1,5 con dos, ×2 con
  tres) y van a por el que tengan más cerca.
- **Se baja juntos:** cuando uno llega al agujero, bajáis todos.
- **El que cae** no vuelve hasta el piso siguiente, y con media vida.
  Mientras, su cámara sigue a un compañero. Si caéis todos, se acaba.
- **Los objetos son para todos** menos para quien esté caído. El ataque
  especial sigue siendo uno por piso para cada uno.
- La vida de los compañeros sale abajo a la izquierda.
- En la pausa el juego no se para (los demás siguen) y no se puede
  reiniciar; *Salir de la sala* deja la partida, y si se va quien la creó,
  se acaba para todos.

Falta probarlo en la wifi del instituto y jugarlo por internet (fase 3). El
estudio y las fases están en
[`docs/mejoras-futuras/multijugador.md`](docs/mejoras-futuras/multijugador.md).

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

## Registro de partidas (para equilibrar)

Cada partida se guarda sola en un archivo `.json`, en la carpeta de datos del
juego. Se apunta cuánto se tarda en cada piso y en cada sala de pelea, cada
golpe recibido (de qué y cuánta vida), la vida recuperada, los enemigos
muertos, los objetos cogidos, el ataque especial y cómo acaba la partida
(`scripts/registro_partida.gd`). El tiempo en pausa no cuenta, y las partidas
de menos de 10 s que se reinician o se dejan no se guardan. No sale nada del
ordenador.

- **Dónde están:** botón *Abrir la carpeta de partidas* en el menú de pausa y
  en la pantalla final. En Windows es
  `%APPDATA%\Godot\app_userdata\Vacio\partidas`.
- **Para equilibrar:** cada uno juega partidas normales y manda su carpeta.
  Luego, desde la raíz del proyecto:

  ```
  python herramientas/analizar_partidas.py carpeta_dani carpeta_matias ...
  ```

  Sin carpetas lee las de su propio ordenador. Saca, por mago, victorias y
  piso medio; por piso, cuántos mueren ahí, el tiempo, la vida perdida y
  recuperada y lo que más quita; lo que más vida quita en total; las salas más
  duras, y los objetos cogidos.
- **Las partidas con atajos de prueba (F1-F5) quedan marcadas** y el análisis
  las deja fuera (`--con-trucos` para verlas): no son partidas normales.

## Qué NO está hecho todavía (fases siguientes)

Las mejoras grandes que el equipo ha valorado para más adelante, con su
estudio (qué haría falta, riesgos y decisiones pendientes), están en
[`docs/mejoras-futuras/`](docs/mejoras-futuras/): de momento, el multijugador
cooperativo con sala por código, que ya se juega entero en red local (fases
1 y 2); falta jugarlo por internet (fase 3).

Sistema de puntuación y guardado. Los obstáculos móviles ya
están: del piso 4 en adelante, parte de las rocas van y vienen, y es la primera
`Mecanica` del proyecto. El suelo sigue siendo color
plano a propósito: ninguno de los packs trae una textura cenital repetible, y
el color interpolado por profundidad es lo que comunica las 12 capas. La Fase 1 deja los enganches puestos:
`velocidad_obstaculos` ya llega a cada obstáculo, y `Mecanica` ya se carga y se
aplica aunque todavía no haya ninguna.
