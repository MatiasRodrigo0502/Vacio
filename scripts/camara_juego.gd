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
## Zona del mundo de la que la camara no se sale: la sala en la que esta el
## jugador. Vacia = sin limite.
var _limite: Rect2 = Rect2()


func _ready() -> void:
	# El suavizado propio de Camera2D se desactiva porque lo hacemos a mano:
	# asi controlamos posicion y zoom con la misma curva y el mismo delta.
	position_smoothing_enabled = false
	make_current()


func _process(delta: float) -> void:
	if is_instance_valid(_objetivo):
		# Interpolacion exponencial: independiente de los FPS, a diferencia de
		# un lerp con factor fijo por frame. Es tambien lo que hace que, al
		# cambiar de sala, la camara se deslice a la nueva en vez de saltar.
		var peso := 1.0 - exp(-velocidad_seguimiento * delta)
		global_position = global_position.lerp(_encajar(_objetivo.global_position), peso)

	var peso_zoom := 1.0 - exp(-velocidad_zoom * delta)
	zoom = zoom.lerp(_zoom_objetivo, peso_zoom)


func seguir(objetivo: Node2D, inmediato: bool = false) -> void:
	_objetivo = objetivo
	if inmediato and is_instance_valid(objetivo):
		global_position = _encajar(objetivo.global_position)


## Encierra la camara en una zona del mundo: la sala en la que esta el jugador.
##
## COMO EN ISAAC, PERO CON EL EMBUDO:
## si la sala cabe entera en pantalla, la camara se queda quieta en su centro y
## se ve toda, que es lo que hace Isaac. Si no cabe (en los pisos hondos el
## radio de vision es menor que la sala), la camara sigue al jugador sin
## asomarse fuera de la sala. Asi "cada piso se ve menos" sigue siendo verdad.
func limitar_a(zona: Rect2, inmediato: bool = false) -> void:
	_limite = zona
	if inmediato and is_instance_valid(_objetivo):
		global_position = _encajar(_objetivo.global_position)


## El punto al que deberia ir la camara para mirar a 'punto' sin salirse del
## limite. Eje a eje: si la zona es mas estrecha que la pantalla en ese eje, se
## centra en ella; si es mas ancha, se deja seguir al punto hasta el borde.
func _encajar(punto: Vector2) -> Vector2:
	if not _limite.has_area():
		return punto
	# Media pantalla, en pixeles de mundo. Con el zoom de ahora y no con el de
	# destino: durante el cambio de piso el zoom se interpola, y con el de
	# destino la camara se encajaria antes de tiempo y daria un tiron.
	var medio := get_viewport_rect().size * 0.5 / zoom
	var resultado := punto
	for eje in 2:
		var desde := _limite.position[eje] + medio[eje]
		var hasta := _limite.end[eje] - medio[eje]
		if desde >= hasta:
			resultado[eje] = _limite.get_center()[eje]
		else:
			resultado[eje] = clampf(punto[eje], desde, hasta)
	return resultado


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
