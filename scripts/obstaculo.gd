## Obstaculo: roca que resta vida al tocarla.
##
## POR QUE Area2D Y NO StaticBody2D:
## un cuerpo solido frenaria al jugador y el golpe se sentiria como un choque de
## plataformas. Con un Area2D el jugador la atraviesa, pierde vida y sigue en
## movimiento, que es lo que pide un juego de habilidad y precision.
##
## Este nodo esta pensado para vivir en un pool: nunca se libera, se recicla.
## Por eso todo el estado (textura, escala, tinte, tamano) se fija en preparar()
## y no en _ready().
class_name Obstaculo
extends Area2D

## Vida que quita cada impacto.
@export var dano: int = 1

## La colision es mas pequena que el dibujo, a proposito. Dos razones: la caja
## de la textura incluye esquinas transparentes, y en un juego de precision el
## jugador tiene que sentir que "ha pasado raspando", no que le golpea el aire.
const FACTOR_COLISION: float = 0.72

## Velocidad heredada del piso. En Fase 1 no se usa (rocas estaticas), pero se
## guarda para que los obstaculos moviles de fases futuras la lean tal cual.
var velocidad: float = 0.0

var _tamano: Vector2 = Vector2(48, 48)

@onready var _sprite: Sprite2D = $Sprite
@onready var _forma: CollisionShape2D = $Forma


func _ready() -> void:
	body_entered.connect(_al_entrar_cuerpo)


## Configura la roca antes de activarla. La llama el piso al construirse.
## lado_objetivo es el lado mayor que debe ocupar en el mundo: la textura se
## escala de forma uniforme para no deformar la roca.
func preparar(posicion: Vector2, textura: Texture2D, lado_objetivo: float,
		tinte: Color, velocidad_piso: float) -> void:
	global_position = posicion
	velocidad = velocidad_piso

	_sprite.texture = textura
	_sprite.modulate = tinte

	var tam_textura := Vector2(textura.get_size())
	var escala := lado_objetivo / maxf(tam_textura.x, tam_textura.y)
	_sprite.scale = Vector2(escala, escala)
	_tamano = tam_textura * escala

	var rectangulo := RectangleShape2D.new()
	rectangulo.size = _tamano * FACTOR_COLISION
	_forma.shape = rectangulo

	activar()


func activar() -> void:
	visible = true
	# set_deferred porque activar o desactivar el monitoreo en mitad de un paso
	# de fisica dispara un error del motor.
	set_deferred("monitoring", true)


func desactivar() -> void:
	visible = false
	set_deferred("monitoring", false)
	# Se aparca lejos del area jugable: una roca reciclada nunca debe quedarse
	# detectando colisiones en la posicion del piso anterior.
	global_position = Vector2(-100000, -100000)


func tamano() -> Vector2:
	return _tamano


func _al_entrar_cuerpo(cuerpo: Node2D) -> void:
	# El obstaculo no sabe que es un "Jugador" concreto: solo pide que sepa
	# recibir dano. Asi la misma roca servira para otras entidades.
	if cuerpo.has_method("recibir_dano"):
		cuerpo.recibir_dano(dano)
