# Vacío

> Proyecto 1 DAM

Juego 2D top-down de habilidad hecho en **Godot 4.7** (GDScript). El jugador
desciende piso a piso por una estructura con forma de embudo: 12 niveles fijos
basados en las capas de la Tierra, de la corteza continental al núcleo interno.
Cada piso es más estrecho, más denso y se ve menos que el anterior.

Estado: **Fase 1 — base jugable**. Moverse, bajar del piso 1 al 12, vida,
cámara y ancho reaccionando al piso, y pantalla de victoria al superar el 12.
El jugador ya es el mago (BlueWizard) con animaciones de reposo y de andar, y
los obstáculos son rocas de cueva con decoración repartida por el suelo.

## Controles

| Acción | Tecla |
|---|---|
| Moverse | WASD o flechas |
| Reiniciar partida | R |

## Cómo se juega ahora mismo

Apareces arriba del piso. Bajas esquivando bloques (cada toque quita 1 de vida,
con ~1 s de invulnerabilidad después) hasta el círculo de salida del fondo. Al
tocarlo pasas al piso siguiente, con la vida que te quede. Superar el piso 12
gana la partida; quedarte sin vida la termina.

## Estructura del proyecto

```
Vacio/
├── project.godot          # autoload, mapa de teclas, capas de física
├── scenes/
│   ├── Principal.tscn     # escena raíz: monta pisos, jugador, cámara, HUD
│   ├── Piso.tscn          # UNA escena genérica para los 12 pisos
│   ├── Jugador.tscn
│   ├── Obstaculo.tscn     # bloque reciclado por el pool
│   ├── Hud.tscn
│   └── PantallaFinal.tscn # victoria y derrota comparten pantalla
├── scripts/
│   ├── gestor_progreso.gd # AUTOLOAD: piso actual, los 12 DatosPiso, victoria
│   ├── datos_piso.gd      # class_name DatosPiso extends Resource
│   ├── mecanica.gd        # class_name Mecanica extends Resource (clase base)
│   ├── principal.gd
│   ├── piso.gd
│   ├── jugador.gd
│   ├── camara_juego.gd
│   ├── obstaculo.gd
│   ├── pool_obstaculos.gd
│   ├── hud.gd
│   └── pantalla_final.gd
├── resources/
│   ├── pisos/             # los 12 .tres, uno por capa (ver su README)
│   └── mecanicas/         # .tres de mecánicas (vacío en Fase 1, ver su README)
└── assets/
    ├── personaje/      # frames del mago + animaciones_mago.tres
    └── obstaculos/     # 33 rocas + catalogo_cueva.tres
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

Obstáculos **móviles** (los de ahora son rocas estáticas), mecánicas concretas,
menú principal, sistema de puntuación y guardado. El suelo sigue siendo color
plano a propósito: ninguno de los packs trae una textura cenital repetible, y
el color interpolado por profundidad es lo que comunica las 12 capas. La Fase 1 deja los enganches puestos:
`velocidad_obstaculos` ya llega a cada obstáculo, y `Mecanica` ya se carga y se
aplica aunque todavía no haya ninguna.
