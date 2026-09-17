## Clase base de las mecanicas del juego.
##
## POR QUE ESTO ES UN RESOURCE:
## el gestor de progreso no conoce ninguna mecanica concreta. Solo lee la
## carpeta res://resources/mecanicas/, carga lo que encuentre y pregunta a cada
## recurso "a partir de que piso te activas". Anadir una mecanica nueva en las
## fases siguientes = crear un script que herede de Mecanica + su .tres, sin
## tocar gestor_progreso.gd ni piso.gd. Esto evita el clasico match/if gigante
## que crece con cada mecanica.
class_name Mecanica
extends Resource

## Nombre legible de la mecanica (para HUD y depuracion).
@export var nombre_mecanica: String = "Mecanica sin nombre"

## Explicacion corta de que hace.
@export var descripcion: String = ""

## Primer piso en el que la mecanica esta activa (1..12).
@export_range(1, 12) var piso_desbloqueo: int = 1

## Permite desactivar una mecanica sin borrar su archivo.
@export var activa: bool = true


## Devuelve true si la mecanica debe aplicarse en el piso indicado.
func esta_desbloqueada(numero_piso: int) -> bool:
	return activa and numero_piso >= piso_desbloqueo


## Gancho que se llama al construir un piso. Las mecanicas hijas lo sobrescriben
## (por ejemplo para anadir nodos, spawnear cosas o cambiar los limites).
## Se recibe el piso como Node para no acoplar esta clase base a la escena.
func aplicar_a_piso(_piso: Node) -> void:
	pass


## Gancho que se llama sobre el jugador al entrar en un piso
## (por ejemplo para modificar friccion, velocidad o vida).
func aplicar_a_jugador(_jugador: Node) -> void:
	pass


## Gancho que se llama al salir del piso, para deshacer lo que haga falta.
func retirar_de_piso(_piso: Node) -> void:
	pass
