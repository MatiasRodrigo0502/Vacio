# Vacío

> Proyecto 1 DAM

**Todo lo hecho hasta ahora, en un documento:** [docs/todo-lo-hecho.md](docs/todo-lo-hecho.md)

Juego 2D top-down de habilidad hecho en **Godot 4.7** (GDScript). El jugador
desciende piso a piso por una estructura con forma de embudo: 12 niveles fijos
basados en las capas de la Tierra, de la corteza continental al núcleo interno.
Cada piso es un mapa de salas unidas por puertas, y cada uno tiene más salas,
y más llenas, que el anterior.

Estado: **jugable de principio a fin**, y en pleno giro hacia algo parecido a
*The Binding of Isaac*. Menú principal, los 12 pisos, disparo, enemigos que te
persiguen o te disparan de lejos, pinchos (y en los últimos pisos, algunas trampas de hielo que te frenan y quitan solo 1), lava y agujeros en el suelo, objetos
que te mejoran, pausa, victoria y derrota. Se elige entre **cuatro magos**, cada uno con
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
- **Android:** [Vacio-android.apk](https://github.com/MatiasRodrigo0502/Vacio/releases/latest/download/Vacio-android.apk)
  (desde la 0.54). Se baja desde el móvil y se abre: la primera vez Android
  pide permiso para instalar apps del navegador. Para que las versiones
  siguientes se instalen encima, todas tienen que ir firmadas con la misma
  clave, que GitHub guarda como secreto (ver
  `herramientas/exportar_android.sh`); sin ella, cada versión lleva una clave
  nueva y para actualizar hay que desinstalar antes la anterior. **Nadie lo
  ha probado todavía en un móvil.**
- **Desde el navegador, sin instalar nada:** <https://matiasrodrigo0502.github.io/Vacio/>
  (desde la 0.62). En el móvil (también en **iPhone**, donde instalar una app sin
  la App Store pide firmarla) o en el ordenador. Sale sola con cada versión. Es
  **solo para un jugador** (el cooperativo usa UDP, y un navegador no puede), y lo
  que ganas (monedas, skins, armas) se guarda **en ese navegador**: en otro móvil o
  en el `.exe` empiezas de cero, y si borras los datos del navegador o usas el
  modo privado, se pierde. En el iPhone, mejor añadirla a la pantalla de inicio
  (*Compartir → Añadir a pantalla de inicio*): se abre sin las barras del
  navegador. **Nadie la ha probado todavía en un iPhone.**

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
ya la versión nueva. Si no, será la que se abra la próxima vez. **Desde la
0.50, igual en Linux y en Mac**: baja el `.tar.gz` o el `.zip` y saca de ahí
el juego nuevo. En Mac solo si `Vacio.app` se ha movido antes de donde se
descomprimió (por ejemplo, a *Aplicaciones*): si no, macOS la abre desde una
copia que no se puede cambiar, y el aviso lo dice. Sin internet no sale nada y se juega
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

## Monedas, diamantes y gacha

Al matar enemigos ganas **monedas** (de 1 los más débiles a 10 los más fuertes, 200
el jefe). Los **diamantes** solo los dan los jefes (10 el Corazón del Núcleo). Se guardan
entre partidas, y se gastan en el botón **Gacha** de la portada:

| Gacha | Una tirada | Diez de golpe | Tiers y probabilidad | Garantía |
|---|---|---|---|---|
| **Skins**, una de cada tier para cada mago | 100 monedas | 900 monedas | B 70 %, A 20 %, S 9 %, S+ 1 % | una S+ cada 60 tiradas como mucho |
| **Armas**, para cualquier mago | 5 diamantes | 45 diamantes | Raro 70 %, Épico 20 %, Legendario 9 %, Mítico 1 % | una mítica cada 30 como mucho |

Diez de golpe traen siempre al menos una A (o una épica). Al abrir sale una cinemática,
más larga cuanto más raro es lo que ha tocado: la S y la legendaria tienen la suya, y la
S+ y la mítica otra todavía mayor. Un clic la adelanta y *Saltar* la acaba.

Si te sale algo que ya tienes, ganas más cuanto más raro es: una skin repetida da 20
monedas la B, 50 la A, 100 la S y 250 la S+, y un arma repetida, 1, 2, 3 o 5 diamantes.
En la colección (lo que no tienes sale en silueta) pulsas una para verla en grande y ponértela. Cada tier de arma da más que el anterior:

- **Raro**: solo cambia el aspecto.
- **Épico**: el aspecto y la forma de disparar (abanico, ráfaga, serpenteando, rebotando).
- **Legendario**: además, una animación al matar.
- **Mítico**: además, varios modos de ataque, que cambias con la **rueda del ratón** o la **Q** (en el móvil, con su botón).

## Controles

| Acción | Tecla |
|---|---|
| Moverse | WASD (o las flechas: se elige en **Controles**) |
| Andar despacio | Shift: un tercio más lento, para pasar entre pinchos |
| Disparar | Flechas (o WASD, si te mueves con las flechas), o clic izquierdo apuntando con el ratón |
| Ataque especial | Clic derecho o espacio, **una vez por piso**. Mago oscuro y rojo: **mantenido**, carga una bola que se suelta cuando el aro se cierra. Con el clic derecho sale hacia el ratón; con el espacio, hacia donde apuntan las flechas o, sin ninguna, hacia donde mira el mago (para jugar sin ratón). Mago blanco: saca el escudo |
| Pausa (continuar, reiniciar o volver al menú) | Esc |
| Pantalla completa o ventana | F11 (o Alt+Intro). El juego empieza a pantalla completa y se acuerda de lo último que elegiste |
| Estadísticas | F3, que va pasando entre *No*, *FPS y ping* (una línea arriba a la derecha) y *Todas* (rendimiento, partida y red, como el F3 de Minecraft). También se elige en Controles y en la pausa, y se recuerda |

**En el móvil** (desde la 0.54), como en Brawl Stars: el dedo en la mitad
izquierda de la pantalla saca un **joystick azul** que mueve al mago, y en la
mitad derecha uno **rojo** que apunta y dispara mientras lo apartas del
centro. Cada uno sale donde pones el dedo y se va al levantarlo. El **ataque
especial** es el botón de la estrella, abajo a la derecha (del color de tu
mago): se mantiene y se arrastra hacia donde quieres que salga, y se suelta.
La **pausa**, el botón de arriba en el centro. Si pones el móvil **en
vertical**, la vista gira 90 grados: la sala queda a lo largo de la pantalla
y las paredes se ven de lado, pero el mago, los enemigos y los objetos
siguen de pie, nada cambia de sitio y arriba en la pantalla sigue siendo
arriba. En el ordenador se pueden probar los joysticks arrancando el juego
con `-- --tactil` (el ratón hace de dedo).

En el panel **Controles** del menú, la pestaña **Teclas** tiene una tabla con
cada acción, su **tecla principal** y su **tecla secundaria**. Para cambiar una,
púlsala y luego la tecla o el botón del ratón que quieras (Esc la deja como
estaba); la **×** de al lado la quita, y *Restablecer* las deja como de fábrica.
Una tecla solo hace una cosa: si la pones en otra acción, se le quita a la que la
tenía. Encima hay un atajo para **moverse con WASD o con las flechas** (con las
flechas, se dispara con WASD). Todo se acuerda para la próxima vez, y el tutorial
dice las teclas que hayas elegido. Las reglas están en la otra pestaña, **Cómo
se juega**.

Al lado está el **disparo automático** (también en la pausa): encendido, el
mago dispara sin parar al enemigo más cercano de la sala, antes a los que
tiene a tiro, mientras no apuntes tú con el ratón o las teclas.

No hace falta memorizarlos: están en el botón **Controles** del menú, y además
el piso 1 es un **tutorial**: cinco salas en fila, y al entrar en cada una
sale una ventana que explica una cosa (el juego se para mientras la lees, y
se cierra con *Entendido*, Intro o Escape):

1. A qué se juega, moverse, disparar y la pausa.
2. El ataque especial (el de tu mago), las rocas, la vida y el mapa.
3. **La primera pelea** (un gólem y dos murciélagos): hay que matar a todos los
   enemigos para que se abran las puertas.
4. Los objetos (el del piso está en el centro) y los vendajes.
5. La bajada, y lo que espera más abajo.

Cada ventana sale **una sola vez**, aunque cierres el juego: las siguientes partidas
empiezan igual en el piso 1, pero sin parar a explicar nada. La del ataque especial sale
la primera vez que juegas con cada mago, porque cada uno tiene el suyo.

Cada ventana sale una vez cada vez que abres el juego: si reinicias, no
vuelven a salir (la del ataque especial sí, si cambias de mago).

### Atajos de prueba (solo para el equipo)

Para probar y equilibrar sin jugar la partida entera. **Solo funcionan al jugar
desde Godot** (el editor o `jugar.bat`); en el juego exportado no existen. Se recuerdan
abajo a la izquierda de la pantalla, en rojo mientras eres invencible.

| Tecla | Qué hace |
|---|---|
| F1 | Invencible sí / no: ni los golpes ni las caídas quitan vida |
| F7 | Piso anterior (hasta el 3 de noviembre de 2026, F2) |
| F8 | Piso siguiente (era F3, que ahora enseña las estadísticas) |
| F4 | Mata a los enemigos de la sala en la que estás (con su animación de muerte) |
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
- Y una **sala secreta**, que no sale en el mapa: está detrás de una pared
  con unas grietas finas. Tres disparos a esa pared la rompen y se abre el
  paso. Dentro hay un **cofre**: al pasar por encima sale una **ruleta** con
  las ventajas y te toca una al azar, para toda la partida.
- Arriba a la derecha va un **minimapa**: las salas en las que has estado, las
  de al lado en contorno, y el objeto y la bajada marcados en cuanto las
  conoces. El resto se descubre andando.
- Cuanto más bajas, más salas y con más enemigos y rocas. Todas las salas
  miden lo mismo en todos los pisos y la cámara está igual de lejos, así
  que los enemigos, las rocas y el mago se ven siempre del mismo tamaño, y
  la sala entera cabe en pantalla. La del jefe es más grande.
- **Solo se ve la sala en la que estás**: lo que asoma de las de al lado
  queda a oscuras, y al cruzar una puerta la luz se desliza con la cámara.

Antes de empezar eliges **con qué mago juegas**, y no es solo el color:

| Mago | Ventaja | Pega |
|---|---|---|
| **Mago oscuro** | Anda un 13 % más rápido, sus disparos **queman** con llamas moradas (3 de vida por segundo durante 3 s) y su bola cargada abre un **agujero negro** donde se acaba, que atrae a los enemigos y quita vida a los del centro | Su bola cargada llega menos lejos que la del rojo |
| **Mago rojo** | 30 de vida más, y el ataque cargado sale en medio tiempo y quita 50: mata de un golpe a cualquier enemigo. Sus disparos **queman**: 3 de vida por segundo durante 3 s | Anda un 9 % más lento |
| **Mago blanco** | Su ataque especial es una burbuja que lo cubre entero durante 5 s: los disparos rebotan en ella (y los rebotados dañan a los enemigos) y los enemigos que la tocan salen despedidos. Sus disparos frenan a los enemigos a la mitad durante 1,5 s | No tiene bola cargada: su ataque especial protege, pero no hace daño |
| **Mago verde** | **Rocía veneno**: dispara 4,5 veces más rápido y cada gota **envenena** (3 por segundo durante 3 s; las gotas no se suman, rellenan el mismo veneno). Su ataque especial son 8 proyectiles rápidos que salen a su alrededor y luego persiguen al enemigo más cercano; el que da lo **envenena** (5 por segundo durante 5 s), y si le dan varios, esos venenos se suman | Cada gota quita 1, diez veces menos. Los proyectiles giran tan poco que muchos se estrellan contra rocas y paredes |

Cada mago tiene su arte: su figura en ocho direcciones y sus hechizos (la bola
de fuego y el meteoro del rojo, la bola morada y el agujero negro del oscuro,
la lanza de hielo y la burbuja del blanco, y los dardos del verde).

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
cargado 30; un murciélago tiene de 10 a 20, un vigía de 30 a 50 y un gólem de 60 a
100, según la capa. Un golpe de un enemigo te quita de 20 (un murciélago de arriba)
a 40 (la esquirla de un vigía del núcleo), y
el **vendaje** cura 60. Es lo único que cura: sale como objeto, a veces lo
suelta un enemigo y, al limpiar una sala, cae uno de cada cuatro veces. Con
la vida llena no se coge: se queda en el suelo para luego. Del piso 2 en adelante los hay, y van a
más según bajas. Son **tres criaturas, con una variante por capa** (corteza, manto y
núcleo), más fuertes cuanto más abajo, y **cada una pelea a su manera**: el **gólem**
va a por ti, levanta los brazos y golpea el suelo a dos manos; el **vigía** flota, te
rodea y dispara esquirlas, y si te escondes tras una roca, se mueve hasta tenerte a
tiro; los **murciélagos** van de tres en tres, dan vueltas a tu alrededor, marcan una
línea y se lanzan en picado. Desde el piso 2 sale también el **escorpión**: corre hacia
ti haciendo eses, así que cuesta apuntarle, y te pica. Desde el piso 5, el **cristal
vivo**: no se mueve, te dispara un rayo que quita 50 **sin avisar** y luego se
teletransporta a otro sitio de la sala. Todos los demás avisan antes de lo que pega de
golpe. Lo que hace
cada uno está en [`resources/enemigos/`](resources/enemigos/README.md).

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

El mago verde tampoco carga: al pulsar salen sus **8 proyectiles de veneno**,
en círculo a su alrededor. Medio segundo después cada uno va a por el enemigo
que tenga más cerca, pero gira muy poco: de cerca aciertan, de lejos muchos
acaban en una roca o en la pared, y ahí se deshacen.

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

**El jefe es el Corazón del Núcleo**: una esfera de magma que flota, con un ojo que
te sigue. Se presenta al cerrarse las puertas, su vida sale en una barra abajo y
dispara **bolas de magma**, en abanico. Cada poco suelta una **nova**: avisa con un
aro en el suelo y sale una onda y un anillo de ocho bolas. Y sabe más cuanta menos
vida le queda:

- **Fase 1:** un agujero negro al revés: se abre donde estás y tira de ti. Sal
  mientras crece.
- **Fase 2:** un escudo: no se le puede dar y suelta anillos de esquirlas de hielo que
  frenan. Y las bolas salen de tres en tres.
- **Fase 3:** un rayo de fuego enorme que deja la sala ardiendo. Un pilar te cubre,
  pero el rayo lo rompe: cada pilar sirve una vez. Y las bolas salen de cinco en cinco.

Cada fase va más deprisa que la anterior. Y de vez en cuando **escupe
fuego**: avisa con una línea y una flecha, y luego un chorro que empieza a
un lado de donde estabas y gira hacia ti hasta la pared. Si te toca, te
quemas unos segundos.

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
   (`30AG-R1N`). Si Windows pregunta por el cortafuegos, hay que marcar
   **«Redes públicas» y «Redes privadas»** y pulsar Permitir, o los demás no
   podrán entrar: Windows da por pública casi cualquier red, también la de
   casa.
   Si ya se contestó otra cosa, en la sala está el botón **Abrir el
   cortafuegos**: ahí, *Cambiar la configuración* y marcar *Privada* y
   *Pública* en `vacio.exe`. Si aun así no entra nadie, que cree la sala otro
   ordenador.
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
│   ├── tutorial.gd        # el tutorial del piso 1: qué ventana sale en cada sala
│   ├── aviso_tutorial.gd  # la ventana del tutorial
│   ├── cofre.gd           # el cofre de la sala secreta
│   ├── ruleta.gd          # la ruleta de ventajas que sale al abrir el cofre
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
