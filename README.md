# Vacío

> Proyecto 1 DAM

Juego 2D top-down de habilidad hecho en **Godot 4.7** (GDScript). El jugador
desciende piso a piso por una estructura con forma de embudo: 12 niveles fijos
basados en las capas de la Tierra, de la corteza continental al núcleo interno.
Cada piso es más estrecho, más denso y se ve menos que el anterior.

Estado: **jugable de principio a fin**, y en pleno giro hacia algo parecido a
*The Binding of Isaac*. Menú principal, los 12 pisos, disparo, enemigos que te
persiguen, objetos que te mejoran, victoria y derrota. El jugador es un nigromante
animado; el piso 1 hace de tutorial con arte de musgo y el 2 de
cueva; del 3 al 12 se reutiliza la roca de cueva hasta que haya más arte.

## Controles

| Acción | Tecla |
|---|---|
| Moverse | WASD |
| Disparar | Flechas, o clic izquierdo apuntando con el ratón |
| Reiniciar partida | R |

No hace falta memorizarlos: están en el botón **Controles** del menú, y además
el piso 1 hace de tutorial y los explica con carteles pintados sobre el suelo,
cada uno donde hace falta.

## Cómo se juega ahora mismo

Apareces arriba del piso y bajas hasta el círculo de salida del fondo. Al
tocarlo pasas al siguiente, con la vida que te quede.

Las rocas y plataformas son sólidas: no se cruzan ni se rompen, pero te sirven
de parapeto. Lo que te quita vida son los **enemigos** al tocarte, con ~1 s de
invulnerabilidad después de cada golpe. Del piso 2 en adelante los hay, y van a
más según bajas.

Disparas bolas mágicas para matarlos, con las flechas en las cuatro direcciones
o con el clic izquierdo apuntando donde quieras. En cada piso hay además un
objeto que te mejora para el resto de la partida.

Superar el piso 12 gana; quedarte sin vida termina la partida.

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
    ├── nigromante/    # frames del personaje jugable + su SpriteFrames
    ├── personaje/     # el mago anterior, fuera de uso
    ├── cueva/          # rocas y vegetación del piso 1 (y base del 3 al 12)
    └── musgo/          # arte del piso 2
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

## Qué NO está hecho todavía (fases siguientes)

Sistema de puntuación y guardado. Los obstáculos móviles ya
están: del piso 4 en adelante, parte de las rocas van y vienen, y es la primera
`Mecanica` del proyecto. El suelo sigue siendo color
plano a propósito: ninguno de los packs trae una textura cenital repetible, y
el color interpolado por profundidad es lo que comunica las 12 capas. La Fase 1 deja los enganches puestos:
`velocidad_obstaculos` ya llega a cada obstáculo, y `Mecanica` ya se carga y se
aplica aunque todavía no haya ninguna.
