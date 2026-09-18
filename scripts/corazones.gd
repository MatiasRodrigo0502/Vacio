## Indicador de vida: dibuja un corazon por punto de vida.
##
## POR QUE DIBUJADOS Y NO UN CARACTER NI UN EMOJI:
## la fuente por defecto de Godot (Open Sans) no trae ningun glifo de corazon.
## Comprobado: U+2665, U+2661, U+2764 y los emoji no existen en ella, asi que un
## texto "♥" saldria como un cuadradito. Dibujarlos con draw_circle y un
## triangulo funciona siempre, escala a cualquier tamano y no anade un archivo
## de fuente al repo.
class_name Corazones
extends Control

## Ancho de cada corazon en pixeles.
@export var tamano: float = 26.0
## Separacion entre corazones.
@export var separacion: float = 8.0

const COLOR_LLENO := Color(0.90, 0.22, 0.25)
const COLOR_BRILLO := Color(1.0, 0.55, 0.55)
const COLOR_VACIO := Color(0.32, 0.14, 0.15)

var _vida_actual: int = 0
var _vida_maxima: int = 0


func actualizar(vida_actual: int, vida_maxima: int) -> void:
	_vida_actual = vida_actual
	_vida_maxima = vida_maxima
	queue_redraw()


func _draw() -> void:
	for i in _vida_maxima:
		var centro := Vector2(tamano * 0.5 + i * (tamano + separacion), size.y * 0.5)
		var lleno := i < _vida_actual
		_dibujar_corazon(centro, tamano, COLOR_LLENO if lleno else COLOR_VACIO)
		if lleno:
			# Un punto de brillo arriba a la izquierda: sin el, a este tamano el
			# corazon se lee como una mancha roja.
			draw_circle(centro + Vector2(-tamano * 0.18, -tamano * 0.22),
				tamano * 0.09, COLOR_BRILLO)


## Un corazon son dos circulos arriba y un triangulo apuntando hacia abajo.
func _dibujar_corazon(centro: Vector2, ancho: float, color: Color) -> void:
	var radio := ancho * 0.28
	var alto := ancho * 0.92
	draw_circle(centro + Vector2(-ancho * 0.22, -alto * 0.18), radio, color)
	draw_circle(centro + Vector2(ancho * 0.22, -alto * 0.18), radio, color)
	draw_colored_polygon(PackedVector2Array([
		centro + Vector2(-ancho * 0.48, -alto * 0.10),
		centro + Vector2(ancho * 0.48, -alto * 0.10),
		centro + Vector2(0.0, alto * 0.48)]), color)
