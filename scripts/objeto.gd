## El objeto tal y como aparece en el suelo, esperando a que lo recojan.
##
## Toda la logica de que hace esta en su ObjetoMejora; este nodo solo lo ensena,
## detecta al jugador y se lo entrega. Asi un objeto nuevo no necesita escena
## propia: cambia el .tres y ya.
class_name Objeto
extends Area2D

signal recogido(mejora: ObjetoMejora)

## Alto que ocupa en el mundo.
@export var alto_objetivo: float = 58.0

var mejora: ObjetoMejora = null

var _fase: float = 0.0
var _recogido: bool = false

@onready var _sprite: Sprite2D = $Sprite


func _ready() -> void:
	body_entered.connect(_al_entrar_cuerpo)


## Lo llama la mecanica que los reparte.
func preparar(mejora_objeto: ObjetoMejora, posicion: Vector2) -> void:
	mejora = mejora_objeto
	global_position = posicion
	_sprite.texture = mejora.icono
	# El icono ya viene con su color; el tinte solo sirve para el halo.
	_sprite.modulate = Color.WHITE

	if mejora.icono != null:
		var escala := alto_objetivo / mejora.icono.get_size().y
		_sprite.scale = Vector2(escala, escala)


func _process(delta: float) -> void:
	# Flota un poco para que se distinga de la decoracion, que esta quieta.
	_fase += delta
	_sprite.position.y = sin(_fase * 2.4) * 5.0
	queue_redraw()


func _al_entrar_cuerpo(cuerpo: Node2D) -> void:
	# La guarda evita entregarlo dos veces si el jugador entra y sale en dos
	# frames seguidos, que con la inercia pasa.
	if _recogido or mejora == null:
		return
	if not cuerpo.has_method("aplicar_mejora"):
		return
	_recogido = true
	cuerpo.aplicar_mejora(mejora)
	recogido.emit(mejora)
	queue_free()


## Un halo debajo del objeto, del color de lo que da. Dibujado por codigo porque
## el pack no trae nada parecido y hace falta que se vea desde lejos.
func _draw() -> void:
	if mejora == null:
		return
	var pulso := 1.0 + sin(_fase * 3.0) * 0.12
	var base := Color(mejora.color.r, mejora.color.g, mejora.color.b, 0.16)
	draw_circle(Vector2.ZERO, alto_objetivo * 0.62 * pulso, base)
	draw_arc(Vector2.ZERO, alto_objetivo * 0.42 * pulso, 0.0, TAU, 28,
		Color(mejora.color.r, mejora.color.g, mejora.color.b, 0.55), 2.5, true)
