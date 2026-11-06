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
## Plantas y hierba. Solo decoracion, como las piedras, pero se reparten en
## tamanos mayores porque si no no se ven.
@export var vegetacion: Array[Texture2D] = []
## Repisas y losas anchas. Se reparten por el suelo como plataformas bajas y la
## vegetacion crece encima de ellas, en vez de suelta por el piso.
@export var plataformas: Array[Texture2D] = []
## Las piezas ya vienen con el color de su piso y con la luz medida contra su
## suelo (las de herramientas/generar_rocas.py): el piso no las tine ni
## oscurece. Los packs de antes (musgo, cueva, manto, nucleo) son grises o
## marrones y se tinen con Piso.tinte_profundidad().
@export var colores_propios: bool = false

@export_group("En vertical")
## Las mismas piezas para el movil en vertical (Vista): cada una, la de su
## misma posicion en la lista de arriba, con los lados cambiados y la luz desde
## arriba de la pantalla. Las rocas se ven de lado al girar la vista; las de
## aqui, de pie. Vacias = se usa la de siempre, girada.
@export var rocas_vertical: Array[Texture2D] = []
@export var bloques_vertical: Array[Texture2D] = []
@export var grupos_vertical: Array[Texture2D] = []
@export var plataformas_vertical: Array[Texture2D] = []


## Devuelve las texturas de una familia. Si el nombre no existe, cae en rocas:
## un piso mal configurado debe verse raro, no romper la partida.
func texturas_de(familia: String) -> Array[Texture2D]:
	match familia:
		"piedra": return piedras
		"bloque": return bloques
		"grupo": return grupos
		"roca": return rocas
		"vegetacion": return vegetacion
		"plataforma": return plataformas
		_:
			push_warning("Familia de obstaculos desconocida: '%s'. Se usan rocas." % familia)
			return rocas


## El dibujo de vertical de una pieza, o null si no tiene.
func vertical_de(textura: Texture2D) -> Texture2D:
	for par in [[rocas, rocas_vertical], [bloques, bloques_vertical], [grupos, grupos_vertical],
			[plataformas, plataformas_vertical]]:
		var i: int = par[0].find(textura)
		if i >= 0 and i < par[1].size():
			return par[1][i]
	return null


## Comprueba que el catalogo no esta vacio antes de usarlo.
func esta_completo() -> bool:
	return not piedras.is_empty() and not rocas.is_empty() \
		and not bloques.is_empty() and not grupos.is_empty()


## Todas las piezas grandes del pack juntas. Se usan para el borde del area,
## donde da igual la familia: lo que importa es que tengan volumen.
func rocas_todas() -> Array[Texture2D]:
	var todas: Array[Texture2D] = []
	todas.append_array(rocas)
	todas.append_array(bloques)
	todas.append_array(grupos)
	return todas
