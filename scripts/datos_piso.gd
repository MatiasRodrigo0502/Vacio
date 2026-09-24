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

## Ancho del suelo de cada sala, en pixeles. El embudo se estrecha piso a
## piso, asi que este valor debe ir bajando del piso 1 al 12.
##
## Antes era el ancho del pasillo entero; desde que cada piso es un mapa de
## salas, es el de cada sala. Todas las salas de un piso miden lo mismo para
## encajar en la cuadricula.
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

## Alto del suelo de cada sala, en pixeles.
##
## OJO CON EL RADIO DE VISION: mientras la sala quepa en pantalla, la camara se
## queda quieta y se ve entera. Cuando el radio de vision es menor que media
## sala, la camara se mueve dentro de ella y ya no se ve toda: asi es como
## "cada piso se ve menos" sigue siendo verdad con salas.
@export var alto_area: float = 700.0

## Cuantas salas tiene el piso, contando el inicio, la del objeto y la de la
## salida. Mas salas es mas piso que cruzar y mas callejones que explorar.
@export var cantidad_salas: int = 6

## Cuantas rocas se colocan en CADA sala de pelea (el inicio y la del objeto
## van limpias).
@export var cantidad_obstaculos: int = 3

## Que familia de rocas usa este piso. Cambiarla es la forma mas barata de dar
## personalidad a una capa sin tocar nada mas.
@export_enum("roca", "piedra", "bloque", "grupo") var familia_obstaculos: String = "roca"

## Pinta los carteles de controles sobre el suelo. Solo el piso 1 los lleva,
## pero es un interruptor por piso y no un "if numero_piso == 1" escondido en el
## codigo: si manana se quiere recordar algo en el piso 6, se marca su .tres.
@export var mostrar_tutorial: bool = false

## Pack de arte del piso: rocas, piedras y vegetacion. Si se deja vacio se usa
## el de la cueva. Es lo que permite que cada piso tenga su propio aspecto sin
## tocar codigo: basta con apuntar a otro catalogo.
@export var catalogo_arte: CatalogoObstaculos = null
