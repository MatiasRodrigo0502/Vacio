## Catalogo de texturas de obstaculos, agrupadas por familia.
##
## POR QUE UN RESOURCE Y NO UNA CARPETA QUE SE LEE SOLA:
## el orden de los archivos en disco no es estable entre sistemas, y los pisos
## tienen que ser identicos en las tres maquinas del equipo. Con una lista fija
## dentro de un .tres, la piedra numero 3 es la misma para todo el mundo.
##
## Anadir un pack de arte nuevo (lava, hielo...) = crear otro .tres de este tipo
## y apuntarlo desde el DatosPiso del piso que lo use. Sin tocar codigo.
class_name CatalogoObstaculos
extends Resource

## Piedras pequenas. Se usan como decoracion del suelo, sin colision.
@export var piedras: Array[Texture2D] = []
## Rocas sueltas de tamano medio. Familia por defecto de los obstaculos.
@export var rocas: Array[Texture2D] = []
## Bloques angulares. Pensados para los pisos profundos, de roca fracturada.
@export var bloques: Array[Texture2D] = []
## Grupos de varias rocas juntas. Ocupan mas y cierran mas el paso.
@export var grupos: Array[Texture2D] = []


## Devuelve las texturas de una familia. Si el nombre no existe, cae en rocas:
## un piso mal configurado debe verse raro, no romper la partida.
func texturas_de(familia: String) -> Array[Texture2D]:
	match familia:
		"piedra": return piedras
		"bloque": return bloques
		"grupo": return grupos
		"roca": return rocas
		_:
			push_warning("Familia de obstaculos desconocida: '%s'. Se usan rocas." % familia)
			return rocas


## Comprueba que el catalogo no esta vacio antes de usarlo.
func esta_completo() -> bool:
	return not piedras.is_empty() and not rocas.is_empty() \
		and not bloques.is_empty() and not grupos.is_empty()
