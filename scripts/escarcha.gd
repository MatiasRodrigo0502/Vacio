## La escarcha de quien va frenado por el frio: el aro de hielo a los pies, los
## copos y el copo grande del arte de Matias (2026-11-04). La llevan los enemigos
## que frena el disparo del mago blanco y, desde el 2026-11-03, el mago que pisa
## una trampa de hielo (Matias: «se representara igual que los enemigos que son
## alcanzados por los proyectiles del mago blanco»). Por eso se pinta aqui y no
## en cada uno: los dos tienen que verse igual.
##
## Encima del sprite de quien la lleva: por debajo, el cuerpo la tapaba.
## Con el dibujo, el color: quien la lleva se
## tinta de COLOR (el enemigo, el nodo entero; el mago, su sprite).
class_name Escarcha
extends RefCounted

const COLOR := Color(0.62, 0.84, 1.25)
## Se carga la primera vez y no con preload: una imagen no existe hasta que
## Godot la importa, y con preload, en una copia recien bajada del proyecto, este
## script (y todo lo que depende de el) no compilaria en esa primera importacion.
const RUTA_HOJA := "res://assets/mago_blanco/hechizos/estado_ralentizado.png"
static var _hoja: Texture2D = null


## La pinta en 'lienzo' con los pies en 'pies' (en local), al tamano de 'radio'
## y moviendose segun 'fase' (segundos).
static func pintar(lienzo: CanvasItem, pies: Vector2, radio: float, fase: float) -> void:
	if _hoja == null:
		_hoja = load(RUTA_HOJA)
	ArteHechizo.pintar_estado(lienzo, _hoja, pies, radio, fase)
