## El arma que lleva el mago, apuntando hacia donde dispara.
##
## Desde el 2026-11-10 (Matias: «cuando usas una varita con el mago, debe quitarse el
## arma default») el mago con un arma se dibuja sin su baston, y el arma va en esa
## mano: el dibujo sin baston dice donde queda la mano en cada pose (su metadato
## "manos", de herramientas/generar_sin_baston.py), y el arma la sigue al andar y
## se pinta detras del cuerpo cuando la mano queda detras. Si el dibujo no lo dice
## (un mago o una skin sin esa hoja), flota a su lado, como antes.
class_name ArmaFlotante
extends Sprite2D

## A que distancia del centro del mago flota, y lo que mide (el icono es de 96).
const DISTANCIA: float = 34.0
const ESCALA: float = 0.55
## En la mano, algo mas pequena (43 px, con el mago de 72): a 0,55 la llevaba como
## una lanza, y apuntando abajo le pasaba de los pies.
const ESCALA_MANO: float = 0.45
## El centro del mago, respecto a sus pies (su circulo, en Jugador.tscn).
const CENTRO := Vector2(0.0, -16.0)
## Lo rapido que llega a donde apunta: si saltara, daria un tiron con cada giro.
const SUAVIZADO: float = 14.0
## Por donde se coge el icono (dibujado recto, mirando a la derecha): a un cuarto de
## su largo desde atras. Ahi va la mano, y el arma sale hacia delante.
const EMPUNADURA: float = 0.25
## Una mano con z por debajo de esto queda detras del cuerpo (como en
## magos_vectorial.construir, que decide ahi si pinta el baston detras).
const DETRAS: float = -0.3

var _objetivo: Vector2 = Vector2.DOWN
var _fase: float = 0.0
var _rumbo: Vector2 = Vector2.DOWN
## El dibujo del mago: de su animacion y su pose sale donde esta la mano.
var _sprite: AnimatedSprite2D
var _detras: bool = false


func _init(arma: ArmaMago, sprite: AnimatedSprite2D = null) -> void:
	texture = arma.icono
	name = "ArmaFlotante"
	scale = Vector2.ONE * ESCALA
	_sprite = sprite
	# Por encima del mago, para que se vea cuando apunta hacia abajo. En la mano
	# va por orden de dibujo (_ponerse_detras), y el z se queda en 0.
	z_index = 1


## Hacia donde apunta, en el mundo. La llama el jugador en cada paso.
func apuntar(direccion: Vector2) -> void:
	if direccion != Vector2.ZERO:
		_objetivo = direccion


## True si va en la mano del mago (su dibujo dice donde esta).
func en_la_mano() -> bool:
	return not _mano().is_empty()


func _process(delta: float) -> void:
	_fase += delta
	_rumbo = _rumbo.lerp(_objetivo, 1.0 - exp(-SUAVIZADO * delta)).normalized()
	if _rumbo == Vector2.ZERO:
		_rumbo = _objetivo
	var mano := _mano()
	var escala := ESCALA if mano.is_empty() else ESCALA_MANO
	if mano.is_empty():
		offset = Vector2.ZERO
		z_index = 1
		position = CENTRO + _rumbo * DISTANCIA + Vista.en_mundo(Vector2(0.0, sin(_fase * 3.0) * 2.0))
	else:
		# De la pose a donde esta el dibujo: centrado, con su desfase y girado como
		# el (Vista: en vertical, el mago se pinta de pie).
		var tamano := _sprite.sprite_frames.get_frame_texture(_sprite.animation, _sprite.frame).get_size()
		position = _sprite.transform * (Vector2(mano[0], mano[1]) - tamano * 0.5 + _sprite.offset)
		offset = Vector2(texture.get_width() * (0.5 - EMPUNADURA), 0.0)
		z_index = 0
		_ponerse_detras(mano[2] < DETRAS)
	rotation = _rumbo.angle()
	# Apuntando a la izquierda de la pantalla se daria la vuelta: boca abajo.
	scale = Vector2(escala, escala * (-1.0 if Vista.en_pantalla(_rumbo).x < 0.0 else 1.0))


## Donde esta la mano del baston en la pose de ahora, [x, y, z] en pixeles de la
## pose; vacio si el dibujo no lo dice.
func _mano() -> Array:
	if _sprite == null or _sprite.sprite_frames == null or not _sprite.sprite_frames.has_meta("manos"):
		return []
	var poses: Array = _sprite.sprite_frames.get_meta("manos").get(String(_sprite.animation), [])
	if poses.is_empty():
		return []
	var mano: Vector3 = poses[mini(_sprite.frame, poses.size() - 1)]
	return [mano.x, mano.y, mano.z]


## Delante o detras del dibujo del mago, por orden: el que va antes se pinta debajo.
## Al sitio del dibujo en los dos casos: si estaba despues, queda justo antes; si
## estaba antes, el dibujo baja uno al quitarlo y queda justo despues.
func _ponerse_detras(detras: bool) -> void:
	if detras == _detras or get_parent() == null:
		return
	_detras = detras
	get_parent().move_child(self, _sprite.get_index())
