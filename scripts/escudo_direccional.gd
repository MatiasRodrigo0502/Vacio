## Escudo direccional: el ataque especial del mago blanco. Un arco de luz
## pequeno delante del mago, hacia donde mira, que para los disparos enemigos
## que le llegan de frente.
##
## POR QUE SE SACA Y NO ESTA SIEMPRE:
## al principio era una pasiva, siempre puesta, y Matias lo cambio (2026-10-09):
## es su ataque especial, el que los otros magos usan para la bola cargada. Se
## pulsa el clic derecho o el espacio y dura 'duracion' segundos, una vez por
## piso, como los demas ataques especiales (eso lo cuenta el jugador). Asi hay
## que elegir cuando sacarlo: cuando viene la rafaga, no antes.
##
## POR QUE PEQUENO Y SOLO DE FRENTE:
## un escudo que lo parara todo dejaria a los enemigos a distancia sin nada que
## hacer. Asi hay que encararlos: el que te dispara por la espalda o de lado te
## sigue dando, y los que pegan cuerpo a cuerpo, tambien. Tampoco para el magma
## del golem: va por el aire y cae desde arriba.
##
## Lo crea el jugador al estrenar un mago con el escudo de ataque especial
## (PersonajeJugable.ataque_especial). Los proyectiles preguntan al jugador si
## les para (Jugador.escudo_bloquea), y el jugador se lo pregunta a esto.
class_name EscudoDireccional
extends Node2D

## Distancia del arco al centro del cuerpo del mago (el radio de su colision
## es 15): lo bastante cerca para no estorbar, lo bastante lejos para que el
## disparo se pare antes de tocarle.
const RADIO: float = 30.0
## Medio arco, en grados: 76 en total, poco mas que el ancho del mago.
const SEMIANGULO: float = deg_to_rad(38.0)
const GROSOR: float = 5.0
## Lo rapido que gira hacia donde mira el mago. Gira y no salta: con ocho
## direcciones, saltar de una a otra se veia a tirones.
const GIRO: float = 14.0
const COLOR := Color(0.62, 0.9, 1.0)
## Destello al parar un disparo: que se note que ha servido de algo.
const DURACION_DESTELLO: float = 0.2
## Lo que tarda en abrirse al sacarlo: se ve salir, no aparecer de golpe.
const APERTURA: float = 0.12
## En el ultimo tramo parpadea, para avisar de que se va a bajar.
const AVISO_FIN: float = 0.8

## La pone el jugador desde el mago (PersonajeJugable).
var duracion: float = 3.0

var _jugador: Jugador
var _angulo: float = PI * 0.5
var _destello: float = 0.0
var _detras: bool = false
## Segundos que le quedan levantado. 0 = bajado.
var _levantado: float = 0.0


func _init(jugador: Jugador) -> void:
	_jugador = jugador
	name = "Escudo"


func _ready() -> void:
	# En el centro del cuerpo, no a los pies (donde esta el origen del jugador).
	position = _jugador.centro_colision() - _jugador.global_position
	_angulo = _jugador.direccion_mirada().angle()
	visible = false


func _process(delta: float) -> void:
	_levantado = maxf(0.0, _levantado - delta)
	_angulo = lerp_angle(_angulo, _jugador.direccion_mirada().angle(), minf(1.0, GIRO * delta))
	_destello = maxf(0.0, _destello - delta)
	visible = activo()
	# Mirando hacia arriba, el escudo esta detras del mago (vista 3/4): se pinta
	# antes que el sprite. Mirando hacia abajo, delante.
	var detras := sin(_angulo) < -0.2
	if detras != _detras:
		_detras = detras
		_jugador.move_child(self, 0 if detras else -1)
	queue_redraw()


## Lo saca. Devuelve false si no se puede: ya levantado, sin vida o cayendo.
## Si cuenta como el especial del piso lo decide el jugador, con lo que
## devuelve esto.
func levantar() -> bool:
	if activo() or _jugador.vida_actual <= 0 or _jugador.esta_cayendo():
		return false
	_levantado = duracion
	return true


## Lo baja. Al empezar partida y al llegar a un piso.
func bajar() -> void:
	_levantado = 0.0


## Levantado, y con el mago vivo y en pie: cayendo por un agujero no esta.
func activo() -> bool:
	return _levantado > 0.0 and _jugador.vida_actual > 0 and not _jugador.esta_cayendo()


## True si algo de 'radio' que ha ido de 'desde' a 'hasta' (en el mundo) en
## este paso cruza el arco. Se mira en varios puntos del tramo: un rayo va
## rapido y en un solo punto podria saltarse el arco de un paso a otro.
func bloquea(desde: Vector2, hasta: Vector2, radio: float) -> bool:
	if not activo():
		return false
	var centro := global_position
	# Un disparo gordo que roza el borde del arco tambien cuenta.
	var margen := asin(clampf(radio / RADIO, 0.0, 1.0))
	for k in 5:
		var v := desde.lerp(hasta, k / 4.0) - centro
		if absf(v.length() - RADIO) > GROSOR * 0.5 + radio:
			continue
		if absf(angle_difference(_angulo, v.angle())) <= SEMIANGULO + margen:
			_destello = DURACION_DESTELLO
			return true
	return false


func _draw() -> void:
	if not activo():
		return
	# Se abre desde el centro al sacarlo, y parpadea cuando le queda poco.
	var abierto := minf(1.0, (duracion - _levantado) / APERTURA)
	var alfa := 1.0
	if _levantado < AVISO_FIN:
		alfa = 0.35 + 0.65 * absf(cos(_levantado * TAU * 3.0))
	_pintar_arco(SEMIANGULO * abierto, alfa, _destello / DURACION_DESTELLO)


## Resplandor, el arco y un filo claro por dentro.
func _pintar_arco(semiangulo: float, alfa: float, brillo: float) -> void:
	if semiangulo <= 0.01 or alfa <= 0.0:
		return
	var desde := _angulo - semiangulo
	var hasta := _angulo + semiangulo
	draw_arc(Vector2.ZERO, RADIO, desde, hasta, 18, Color(COLOR, (0.22 + 0.35 * brillo) * alfa),
		GROSOR + 6.0 + 6.0 * brillo, true)
	draw_arc(Vector2.ZERO, RADIO, desde, hasta, 18, Color(COLOR, 0.85 * alfa), GROSOR, true)
	# El filo va un poco mas corto que el arco; recien sacado aun no cabe.
	if semiangulo > 0.12:
		draw_arc(Vector2.ZERO, RADIO - 1.0, desde + 0.06, hasta - 0.06, 18,
			Color(1.0, 1.0, 1.0, (0.55 + 0.45 * brillo) * alfa), 1.5, true)
