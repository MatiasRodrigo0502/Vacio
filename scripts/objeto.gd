## El objeto tal y como aparece en el suelo, esperando a que lo recojan.
##
## Toda la logica de que hace esta en su ObjetoMejora; este nodo solo lo ensena,
## detecta al jugador y se lo entrega. Asi un objeto nuevo no necesita escena
## propia: cambia el .tres y ya.
class_name Objeto
extends Area2D

signal recogido(mejora: ObjetoMejora)

## La escena se carga al soltarlo y no con preload: el script es parte de la
## propia escena, y precargarla desde aqui seria una referencia circular.
const RUTA_ESCENA := "res://scenes/Objeto.tscn"

## Alto que ocupa en el mundo.
@export var alto_objetivo: float = 58.0

var mejora: ObjetoMejora = null

var _fase: float = 0.0
var _recogido: bool = false

@onready var _sprite: Sprite2D = $Sprite


## Deja 'mejora_objeto' en el suelo de 'sala', en 'posicion' (global). Lo usan
## lo que suelta un vendaje: la mecanica de vendajes, la antesala del jefe y
## el jefe al cambiar de fase.
static func soltar(sala: Node, mejora_objeto: ObjetoMejora, posicion: Vector2) -> Objeto:
	var objeto: Objeto = load(RUTA_ESCENA).instantiate()
	sala.add_child(objeto)
	objeto.preparar(mejora_objeto, posicion)
	return objeto


func _ready() -> void:
	# Para que el cooperativo los encuentre al cogerlos otro jugador.
	add_to_group("objetos")


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


## Se mira en cada paso quien lo esta tocando, y no con body_entered: lo que
## solo cura no se coge con la vida llena, y si al jugador le dan estando
## encima, tiene que poder cogerlo sin salir y volver a entrar. body_entered
## solo avisa una vez (era lo que hacian los corazones del suelo).
func _physics_process(_delta: float) -> void:
	if _recogido or mejora == null:
		return
	for cuerpo in get_overlapping_bodies():
		if cuerpo.has_method("aplicar_mejora") and _le_hace_falta(cuerpo):
			_entregar(cuerpo)
			return


## Con la vida llena, lo que solo cura se queda en el suelo: cogerlo seria
## tirarlo (como en Isaac).
func _le_hace_falta(cuerpo: Node2D) -> bool:
	# Un mago caido (cooperativo) no recoge nada: los objetos son para los
	# que siguen vivos (Matias, 2026-10-16).
	if "vida_actual" in cuerpo and cuerpo.vida_actual <= 0:
		return false
	if not mejora.solo_cura():
		return true
	return not ("vida_actual" in cuerpo and cuerpo.vida_actual >= cuerpo.vida_maxima)


func _entregar(cuerpo: Node2D) -> void:
	_recogido = true
	cuerpo.aplicar_mejora(mejora)
	# En cooperativo, para todos (Cooperativo.objeto_recogido). Jugando solo
	# no hay nadie en el grupo y no pasa nada.
	get_tree().call_group("cooperativo", "objeto_recogido", self)
	Sonido.tocar(&"objeto")
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
