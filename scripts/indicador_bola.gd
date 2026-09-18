## Indicador de la bola magica en el HUD: encendido si queda, apagado si ya se
## ha gastado en este piso.
##
## Dibujado por codigo por lo mismo que los corazones: la fuente no trae simbolos
## y no hay arte de interfaz en los packs.
class_name IndicadorBola
extends Control

@export var radio: float = 11.0

const COLOR_LISTA := Color(0.62, 0.84, 1.0)
const COLOR_HALO := Color(0.35, 0.60, 1.0, 0.30)
const COLOR_GASTADA := Color(0.30, 0.34, 0.40, 0.75)

var _disponible: bool = true
var _fase: float = 0.0


func _process(delta: float) -> void:
	# Solo late mientras esta lista: gastada no necesita repintarse.
	if not _disponible:
		return
	_fase += delta
	queue_redraw()


func actualizar(disponible: bool) -> void:
	_disponible = disponible
	_fase = 0.0
	queue_redraw()


func _draw() -> void:
	var centro := Vector2(radio + 2.0, size.y * 0.5)
	if _disponible:
		var pulso := 1.0 + sin(_fase * 5.0) * 0.08
		draw_circle(centro, radio * 1.9 * pulso, COLOR_HALO)
		draw_circle(centro, radio * pulso, COLOR_LISTA)
		draw_circle(centro + Vector2(-radio * 0.25, -radio * 0.25), radio * 0.38,
			Color(1, 1, 1, 0.9))
	else:
		# Gastada: solo el contorno, para que se vea que ahi habia algo.
		draw_arc(centro, radio, 0.0, TAU, 24, COLOR_GASTADA, 2.5, true)
