## Destello de una explosion. Solo se ve: el dano lo decide quien explota, en
## el momento de explotar, para que no dependa de cuanto dura el dibujo.
class_name Explosion
extends Node2D

const DURACION: float = 0.35

var radio: float = 70.0
var color: Color = Color(1.0, 0.8, 0.4)

var _tiempo: float = 0.0


func _ready() -> void:
	z_index = 7


func _process(delta: float) -> void:
	_tiempo += delta
	if _tiempo >= DURACION:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t := _tiempo / DURACION
	# El aro llega al radio de verdad: lo que queda dentro es lo que pego.
	draw_circle(Vector2.ZERO, radio * (0.4 + 0.6 * t), Color(color.r, color.g, color.b, 0.35 * (1.0 - t)))
	draw_arc(Vector2.ZERO, radio * (0.3 + 0.7 * t), 0.0, TAU, 32,
		Color(color.r, color.g, color.b, 1.0 - t), 4.0 * (1.0 - t) + 1.0, true)
	draw_circle(Vector2.ZERO, radio * 0.35 * (1.0 - t), Color(1.0, 1.0, 0.9, 0.9 * (1.0 - t)))
