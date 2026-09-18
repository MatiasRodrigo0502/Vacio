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

## Holgura al comprobar el impacto, del tamano del jugador. Sin ella, un roce
## legitimo en el borde se descartaria por unos pocos pixeles.
const TOLERANCIA: float = 16.0

## Velocidad heredada del piso. En Fase 1 no se usa (rocas estaticas), pero se
## guarda para que los obstaculos moviles de fases futuras la lean tal cual.
var velocidad: float = 0.0

var _tamano: Vector2 = Vector2(48, 48)

# --- Vaiven (lo activa la mecanica de rocas moviles, a partir del piso 4) ---
## Punto alrededor del cual oscila. Vector2.ZERO mientras este quieta.
var _origen: Vector2 = Vector2.ZERO
## Direccion del recorrido, normalizada.
var _direccion: Vector2 = Vector2.ZERO
## Cuanto se aleja del origen, en pixeles, hacia cada lado.
var _amplitud: float = 0.0
## Desplazamiento actual respecto al origen, entre -_amplitud y +_amplitud.
var _avance: float = 0.0
## 1.0 de ida, -1.0 de vuelta.
var _sentido: float = 1.0

@onready var _sprite: Sprite2D = $Sprite
@onready var _forma: CollisionShape2D = $Forma


func _ready() -> void:
	body_entered.connect(_al_entrar_cuerpo)
	# Quieto hasta que alguien lo mueva: la mayoria de las rocas no se mueven y
	# no tiene sentido gastar un _physics_process por cada una.
	set_physics_process(false)


## Recorrido de ida y vuelta en linea recta. Lo activa la mecanica de rocas
## moviles; la velocidad es la que traiga el piso en su .tres.
func activar_vaiven(direccion: Vector2, amplitud: float) -> void:
	if direccion == Vector2.ZERO or amplitud <= 0.0 or velocidad <= 0.0:
		return
	_origen = global_position
	_direccion = direccion.normalized()
	_amplitud = amplitud
	_avance = 0.0
	_sentido = 1.0
	set_physics_process(true)


func esta_en_movimiento() -> bool:
	return _direccion != Vector2.ZERO


func _physics_process(delta: float) -> void:
	_avance += velocidad * _sentido * delta
	# Al llegar al extremo se da la vuelta. Se recorta el avance ademas de
	# invertir el sentido: sin eso, con velocidades altas la roca se pasaria un
	# poco de largo en cada rebote y el recorrido se iria agrandando.
	if absf(_avance) >= _amplitud:
		_avance = clampf(_avance, -_amplitud, _amplitud)
		_sentido = -_sentido
	global_position = _origen + _direccion * _avance


## Configura la roca antes de activarla. La llama el piso al construirse.
## lado_objetivo es el lado mayor que debe ocupar en el mundo: la textura se
## escala de forma uniforme para no deformar la roca.
func preparar(posicion: Vector2, textura: Texture2D, lado_objetivo: float,
		tinte: Color, velocidad_piso: float) -> void:
	_parar()
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


## Deja la roca quieta. Se llama al reciclarla, porque una roca que vuelve del
## pool no debe heredar el recorrido que tenia en el piso anterior.
func _parar() -> void:
	_direccion = Vector2.ZERO
	_amplitud = 0.0
	_avance = 0.0
	_sentido = 1.0
	set_physics_process(false)


func desactivar() -> void:
	_parar()
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
	if not cuerpo.has_method("recibir_dano"):
		return

	# Misma precaucion que en la zona de salida del piso: el aviso de Godot puede
	# llegar con la posicion que el cuerpo tenia al empezar el paso de fisica.
	# Como las rocas se reciclan y aparecen en otro sitio en cada piso, sin esta
	# comprobacion el jugador recibia golpes fantasma nada mas entrar en un piso
	# nuevo, de una roca que ya no esta donde el motor cree.
	# Se mide contra el CENTRO DE COLISION del cuerpo, no contra su origen. El
	# origen del jugador esta a los pies y su circulo 16 px mas arriba, asi que
	# midiendo desde el origen se descartaban golpes buenos: acercandose a una
	# roca por abajo, el circulo la tocaba de verdad pero el origen quedaba
	# demasiado lejos y el golpe no contaba.
	var centro_cuerpo: Vector2 = cuerpo.global_position
	if cuerpo.has_method("centro_colision"):
		centro_cuerpo = cuerpo.centro_colision()

	var mitad := _tamano * 0.5 * FACTOR_COLISION + Vector2(TOLERANCIA, TOLERANCIA)
	var distancia := (centro_cuerpo - global_position).abs()
	if distancia.x > mitad.x or distancia.y > mitad.y:
		return

	cuerpo.recibir_dano(dano)
