## Pool (piscina) de obstaculos reutilizables.
##
## POR QUE POOLING:
## instanciar y liberar decenas de Area2D cada vez que se cambia de piso provoca
## picos de recoleccion de basura y microtirones, justo lo que mata a un juego
## de precision. Aqui los obstaculos se crean una vez y se reciclan: cambiar de
## piso solo cambia posiciones.
##
## POR QUE CUELGA DE Principal Y NO DE Piso:
## la escena del piso se destruye en cada transicion. Si el pool viviera dentro,
## se destruiria con ella y no habria reciclaje ninguno. Los obstaculos son
## hijos del pool y se posicionan en coordenadas globales.
class_name PoolObstaculos
extends Node2D

const ESCENA_OBSTACULO := preload("res://scenes/Obstaculo.tscn")

## Cuantos obstaculos se crean al arrancar. Conviene que cubra el piso mas
## cargado para no instanciar nada durante la partida.
@export var tamano_inicial: int = 40

var _libres: Array[Obstaculo] = []
var _en_uso: Array[Obstaculo] = []


func _ready() -> void:
	for _i in tamano_inicial:
		_libres.append(_crear_obstaculo())


## Devuelve un obstaculo listo para usar, creando uno nuevo solo si se agota el
## pool (asi el juego nunca se queda sin obstaculos, aunque pierda la ventaja).
func obtener() -> Obstaculo:
	var obstaculo: Obstaculo
	if _libres.is_empty():
		obstaculo = _crear_obstaculo()
	else:
		obstaculo = _libres.pop_back()
	_en_uso.append(obstaculo)
	return obstaculo


## Devuelve un obstaculo concreto al pool.
func liberar(obstaculo: Obstaculo) -> void:
	if obstaculo == null:
		return
	_en_uso.erase(obstaculo)
	obstaculo.desactivar()
	_libres.append(obstaculo)


## Devuelve todos los obstaculos en uso. Se llama al abandonar un piso.
func liberar_todos() -> void:
	for obstaculo in _en_uso:
		obstaculo.desactivar()
		_libres.append(obstaculo)
	_en_uso.clear()


## Util para depurar el dimensionado del pool.
func estado() -> String:
	return "obstaculos en uso: %d | libres: %d" % [_en_uso.size(), _libres.size()]


func _crear_obstaculo() -> Obstaculo:
	var obstaculo: Obstaculo = ESCENA_OBSTACULO.instantiate()
	add_child(obstaculo)
	obstaculo.desactivar()
	return obstaculo
