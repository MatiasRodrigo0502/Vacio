## Obstaculo: roca o plataforma. Es terreno solido, no se puede atravesar.
##
## POR QUE StaticBody2D Y NO RigidBody2D:
## un RigidBody2D es un cuerpo que la fisica empuja: las rocas saldrian rodando
## al chocar contra ellas. Lo que hace falta es un cuerpo inmovil contra el que
## chocar, y eso es StaticBody2D.
##
## Antes era un Area2D que restaba vida al atravesarla. Ahora no hace dano: si
## no puedes atravesarla, cobrarte vida ademas te castigaria por rozar una pared
## mientras la esquivas. El dano viene de los enemigos.
##
## Este nodo esta pensado para vivir en un pool: nunca se libera, se recicla.
## Por eso todo el estado (textura, escala, tinte, tamano) se fija en preparar()
## y no en _ready().
class_name Obstaculo
extends StaticBody2D

## La colision es mas pequena que el dibujo, a proposito: la caja de la textura
## incluye esquinas transparentes, y en un juego de precision el jugador tiene
## que sentir que "ha pasado raspando", no que choca contra el aire.
const FACTOR_COLISION: float = 0.72

## Velocidad heredada del piso. En Fase 1 no se usa (rocas estaticas), pero se
## guarda para que los obstaculos moviles de fases futuras la lean tal cual.
var velocidad: float = 0.0

var _tamano: Vector2 = Vector2(48, 48)
## Su dibujo, y el de verlo con el movil en vertical (Vista): la misma caja
## con los lados cambiados y la luz desde arriba de la pantalla. Lo hace
## herramientas/generar_rocas.py. Sin el de vertical, se ve el de siempre
## girado con la vista.
var _textura: Texture2D = null
var _textura_vertical: Texture2D = null

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
	# Quieto hasta que alguien lo mueva: la mayoria de las rocas no se mueven y
	# no tiene sentido gastar un _physics_process por cada una.
	set_physics_process(false)
	Vista.cambiada.connect(_poner_dibujo.unbind(1))


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
		tinte: Color, velocidad_piso: float, textura_vertical: Texture2D = null) -> void:
	_parar()
	global_position = posicion
	velocidad = velocidad_piso

	_textura = textura
	_textura_vertical = textura_vertical
	_sprite.modulate = tinte

	var tam_textura := Vector2(textura.get_size())
	var escala := lado_objetivo / maxf(tam_textura.x, tam_textura.y)
	_tamano = tam_textura * escala
	_poner_dibujo()

	var rectangulo := RectangleShape2D.new()
	rectangulo.size = _tamano * FACTOR_COLISION
	_forma.shape = rectangulo

	activar()


func activar() -> void:
	visible = true
	# set_deferred porque encender o apagar una forma de colision en mitad de un
	# paso de fisica dispara un error del motor.
	_forma.set_deferred("disabled", false)


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
	_forma.set_deferred("disabled", true)
	# Se aparca lejos del area jugable: una roca reciclada nunca debe quedarse
	# detectando colisiones en la posicion del piso anterior.
	global_position = Vector2(-100000, -100000)


## Lo llama la bola magica. No se libera al pool aqui a proposito: el piso lo
## hara al desmontarse, como con el resto. Asi la roca rota no puede reaparecer
## a media partida reciclada en otro sitio.
func romper() -> void:
	desactivar()


func tamano() -> Vector2:
	return _tamano


## El dibujo que toca con la vista de ahora. La caja que choca es siempre la
## misma (la del mundo): en vertical se pinta el dibujo de vertical, girado
## con la vista para que salga de pie, y estirado lo justo para llenar esa
## caja (el generador lo hace ya con los lados cambiados).
func _poner_dibujo() -> void:
	if _textura == null:
		return
	if Vista.vertical() and _textura_vertical != null:
		var tam := Vector2(_textura_vertical.get_size())
		_sprite.texture = _textura_vertical
		_sprite.rotation = Vista.giro
		_sprite.scale = Vector2(_tamano.y / tam.x, _tamano.x / tam.y)
	else:
		_sprite.texture = _textura
		_sprite.rotation = 0.0
		_sprite.scale = _tamano / Vector2(_textura.get_size())
