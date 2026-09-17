## Camara que sigue al jugador y ajusta el zoom segun el piso.
##
## POR QUE NO ES HIJA DEL JUGADOR:
## como nodo independiente podemos interpolar el seguimiento (la camara "va
## detras" del jugador, no pegada) y sobre todo reutilizar la misma camara entre
## pisos. Si fuera hija del jugador, cada cambio de piso teletransportaria la
## vista de golpe.
class_name CamaraJuego
extends Camera2D

## Suavizado del seguimiento. Mas alto = camara mas pegada al jugador.
@export var velocidad_seguimiento: float = 9.0
## Suavizado del cambio de zoom entre pisos. Bajo a proposito: el cierre de
## vision al bajar de piso se debe notar como algo gradual, no como un corte.
@export var velocidad_zoom: float = 2.5

var _objetivo: Node2D = null
var _zoom_objetivo: Vector2 = Vector2.ONE


func _ready() -> void:
	# El suavizado propio de Camera2D se desactiva porque lo hacemos a mano:
	# asi controlamos posicion y zoom con la misma curva y el mismo delta.
	position_smoothing_enabled = false
	make_current()


func _process(delta: float) -> void:
	if is_instance_valid(_objetivo):
		# Interpolacion exponencial: independiente de los FPS, a diferencia de
		# un lerp con factor fijo por frame.
		var peso := 1.0 - exp(-velocidad_seguimiento * delta)
		global_position = global_position.lerp(_objetivo.global_position, peso)

	var peso_zoom := 1.0 - exp(-velocidad_zoom * delta)
	zoom = zoom.lerp(_zoom_objetivo, peso_zoom)


func seguir(objetivo: Node2D, inmediato: bool = false) -> void:
	_objetivo = objetivo
	if inmediato and is_instance_valid(objetivo):
		global_position = objetivo.global_position


## Traduce el radio de vision del piso (en pixeles de mundo) a zoom de camara.
## radio_vision = media altura visible, asi que zoom = (alto_ventana/2) / radio.
func aplicar_radio_vision(radio_vision: float, inmediato: bool = false) -> void:
	if radio_vision <= 0.0:
		return
	var alto_ventana := float(get_viewport_rect().size.y)
	var factor := (alto_ventana * 0.5) / radio_vision
	_zoom_objetivo = Vector2(factor, factor)
	if inmediato:
		zoom = _zoom_objetivo
