## Datos de configuracion de un piso (una capa de la Tierra).
##
## POR QUE UN RESOURCE Y NO CONSTANTES EN CODIGO:
## cada piso vive en su propio archivo .tres dentro de res://resources/pisos/.
## Asi tres personas pueden estar retocando tres pisos distintos a la vez sin
## tocar ni una linea de GDScript y sin pisarse en el mismo archivo (cero
## conflictos de merge). Ademas los valores son editables desde el inspector
## del editor, con el juego abierto.
class_name DatosPiso
extends Resource

## Nombre de la capa geologica. Se muestra en el HUD.
@export var nombre_capa: String = "Capa sin nombre"

## Ancho del area jugable en pixeles. El embudo se estrecha piso a piso,
## asi que este valor debe ir bajando del piso 1 al 12.
@export var ancho_area: float = 1200.0

## Velocidad base de los obstaculos de este piso (px/s).
## En la Fase 1 los obstaculos son bloques estaticos, pero el dato ya viaja
## hasta ellos para que las fases siguientes (obstaculos moviles) no tengan
## que cambiar ni el gestor ni la escena de piso.
@export var velocidad_obstaculos: float = 100.0

## Radio de vision en pixeles: media altura visible de la camara.
## Cuanto mas pequeno, mas cerrado el zoom y menos ve el jugador.
@export var radio_vision: float = 500.0

## Marca el ultimo piso: al superarlo se gana la partida en vez de avanzar.
@export var es_nivel_final: bool = false

# --- Ajustes secundarios de dificultad -------------------------------------
# No estaban en el encargo original, pero sin ellos la densidad de obstaculos
# y el largo del piso quedarian codificados en GDScript, y el objetivo es que
# TODA la dificultad de un piso se pueda tocar desde su .tres.

## Largo del piso en pixeles (distancia de la entrada a la zona de salida).
@export var alto_area: float = 1700.0

## Cuantos obstaculos se colocan en el piso.
@export var cantidad_obstaculos: int = 6

## Que familia de rocas usa este piso. Cambiarla es la forma mas barata de dar
## personalidad a una capa sin tocar nada mas.
@export_enum("roca", "piedra", "bloque", "grupo") var familia_obstaculos: String = "roca"

## Pinta los carteles de controles sobre el suelo. Solo el piso 1 los lleva,
## pero es un interruptor por piso y no un "if numero_piso == 1" escondido en el
## codigo: si manana se quiere recordar algo en el piso 6, se marca su .tres.
@export var mostrar_tutorial: bool = false

## Catalogo de texturas alternativo. Si se deja vacio se usa el de la cueva.
## Existe para que en el futuro se pueda meter un pack de arte distinto en los
## pisos profundos (lava, cristal...) sin tocar una linea de codigo.
@export var catalogo_obstaculos: CatalogoObstaculos = null
