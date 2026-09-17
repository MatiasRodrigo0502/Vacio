## Obstaculo basico: bloque estatico que resta vida al tocarlo.
##
## POR QUE Area2D Y NO StaticBody2D:
## un cuerpo solido frenaria al jugador y el golpe se sentiria como un choque
## de plataformas. Con un Area2D el jugador lo atraviesa, pierde vida y sigue
## en movimiento, que es lo que pide un juego de habilidad y precision.
##
## Este nodo esta pensado para vivir en un pool: nunca se libera, se recicla.
## Por eso todo el estado se resetea en preparar() y no en _ready().
class_name Obstaculo
extends Area2D

## Vida que quita cada impacto.
@export var dano: int = 1

## Velocidad heredada del piso. En Fase 1 no se usa (bloques estaticos), pero
## se guarda para que los obstaculos moviles de fases futuras la lean tal cual.
var velocidad: float = 0.0

var _tamano: Vector2 = Vector2(48, 48)

@onready var _forma: CollisionShape2D = $Forma


func _ready() -> void:
	body_entered.connect(_al_entrar_cuerpo)


## Configura el obstaculo antes de activarlo. Lo llama el piso al construirse.
func preparar(posicion: Vector2, tamano: Vector2, velocidad_piso: float) -> void:
	global_position = posicion
	_tamano = tamano
	velocidad = velocidad_piso

	var rectangulo := RectangleShape2D.new()
	rectangulo.size = _tamano
	_forma.shape = rectangulo

	activar()


func activar() -> void:
	visible = true
	# set_deferred porque activar o desactivar el monitoreo en mitad de un paso
	# de fisica dispara un error del motor.
	set_deferred("monitoring", true)
	queue_redraw()


func desactivar() -> void:
	visible = false
	set_deferred("monitoring", false)
	# Se aparca lejos del area jugable: un obstaculo reciclado nunca debe
	# quedarse detectando colisiones en la posicion del piso anterior.
	global_position = Vector2(-100000, -100000)


func tamano() -> Vector2:
	return _tamano


func _al_entrar_cuerpo(cuerpo: Node2D) -> void:
	# El obstaculo no sabe que es un "Jugador" concreto: solo pide que sepa
	# recibir dano. Asi el mismo obstaculo servira para otras entidades.
	if cuerpo.has_method("recibir_dano"):
		cuerpo.recibir_dano(dano)


func _draw() -> void:
	var rectangulo := Rect2(-_tamano * 0.5, _tamano)
	draw_rect(rectangulo, Color(0.13, 0.11, 0.12, 0.95))
	draw_rect(rectangulo, Color(0.85, 0.32, 0.22, 0.9), false, 3.0)
