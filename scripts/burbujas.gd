## El estado de quien esta envenenado por el mago verde: la calavera, las
## burbujas y el charco del arte de Matias (2026-11-04). Se pinta aqui, como las
## llamas (Llamas) y la escarcha (Escarcha), para que el veneno se vea igual en
## todos los enemigos.
##
## Encima del sprite de quien lo lleva: por debajo, el cuerpo lo tapaba.
class_name Burbujas
extends RefCounted

## Se carga la primera vez y no con preload: una imagen no existe hasta que
## Godot la importa, y con preload, en una copia recien bajada del proyecto, este
## script (y todo lo que depende de el) no compilaria en esa primera importacion.
const RUTA_HOJA := "res://assets/mago_verde/hechizos/estado_envenenado.png"
static var _hoja: Texture2D = null


## Lo pinta en 'lienzo' con los pies en 'pies' (en local), al tamano de 'radio'
## y moviendose segun 'fase' (segundos).
static func pintar(lienzo: CanvasItem, pies: Vector2, radio: float, fase: float) -> void:
	if _hoja == null:
		_hoja = load(RUTA_HOJA)
	ArteHechizo.pintar_estado(lienzo, _hoja, pies, radio, fase)
