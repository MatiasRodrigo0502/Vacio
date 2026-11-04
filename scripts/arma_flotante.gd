## El arma que lleva el mago: flota a su lado y apunta hacia donde dispara. Es lo
## que hace que se vea que lleva un arma: en su dibujo solo va su baston.
class_name ArmaFlotante
extends Sprite2D

## A que distancia del centro del mago flota, y lo que mide (el icono es de 96).
const DISTANCIA: float = 34.0
const ESCALA: float = 0.55
## El centro del mago, respecto a sus pies (su circulo, en Jugador.tscn).
const CENTRO := Vector2(0.0, -16.0)
## Lo rapido que llega a donde apunta: si saltara, daria un tiron con cada giro.
const SUAVIZADO: float = 14.0

var _objetivo: Vector2 = Vector2.DOWN
var _fase: float = 0.0
var _rumbo: Vector2 = Vector2.DOWN


func _init(arma: ArmaMago) -> void:
	texture = arma.icono
	name = "ArmaFlotante"
	scale = Vector2.ONE * ESCALA
	# Por encima del mago, para que se vea cuando apunta hacia abajo.
	z_index = 1


## Hacia donde apunta, en el mundo. La llama el jugador en cada paso.
func apuntar(direccion: Vector2) -> void:
	if direccion != Vector2.ZERO:
		_objetivo = direccion


func _process(delta: float) -> void:
	_fase += delta
	_rumbo = _rumbo.lerp(_objetivo, 1.0 - exp(-SUAVIZADO * delta)).normalized()
	if _rumbo == Vector2.ZERO:
		_rumbo = _objetivo
	position = CENTRO + _rumbo * DISTANCIA + Vista.en_mundo(Vector2(0.0, sin(_fase * 3.0) * 2.0))
	rotation = _rumbo.angle()
	# Apuntando a la izquierda de la pantalla se daria la vuelta: boca abajo.
	scale.y = ESCALA * (-1.0 if Vista.en_pantalla(_rumbo).x < 0.0 else 1.0)
