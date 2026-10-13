## Las runas de la puerta de la sala del jefe: un arco de signos que brillan en
## el suelo, delante del hueco, y la luz que sale por el. Van a los dos lados de
## la puerta, en la antesala y en la sala del jefe.
##
## POR QUE: las puertas son todas iguales, y esta no. Tiene que decir "detras
## hay algo distinto" antes de cruzarla, para que el jugador llegue preparado
## (con vida, con el especial) y no se lo encuentre de golpe.
class_name RunasPuerta
extends Node2D

## Radio del arco de runas, desde el centro del hueco en el filo del suelo.
const RADIO_ARCO: float = 100.0
const CUANTAS: int = 5
## Hasta donde se abre el arco a cada lado, desde la linea que entra en la sala.
## 68 grados, en radianes.
const APERTURA: float = 1.187
const ALTO_RUNA: float = 20.0
## Lo que tarda en latir, ida y vuelta, en segundos.
const LATIDO: float = 2.6

## Hacia la sala desde la puerta (la direccion de la puerta, al reves).
var _dentro: Vector2
var _fase: float = 0.0


## 'direccion' es la de la puerta en esa sala (Vector2i.UP si esta arriba).
func _init(sala: Sala, direccion: Vector2i) -> void:
	name = "RunasPuerta"
	position = sala.punto_puerta(direccion)
	_dentro = -Vector2(direccion)


func _process(delta: float) -> void:
	_fase += delta
	queue_redraw()


func _draw() -> void:
	var latido := 0.5 + 0.5 * sin(_fase * TAU / LATIDO)
	# La luz que sale por la puerta, en capas cada vez mas pequenas y fuertes.
	for capa in [[170.0, 0.035], [120.0, 0.05], [75.0, 0.07]]:
		draw_circle(Vector2.ZERO, capa[0], Color(Runas.COLOR, capa[1] * (0.6 + 0.4 * latido)))
	for i in CUANTAS:
		var angulo := lerpf(-APERTURA, APERTURA, float(i) / float(CUANTAS - 1))
		var sitio := _dentro.rotated(angulo) * RADIO_ARCO
		# Cada una a destiempo: el brillo recorre el arco.
		var propio := 0.5 + 0.5 * sin(_fase * TAU / LATIDO - i * 0.7)
		Runas.pintar(self, sitio, ALTO_RUNA, i * 2 + 1, Runas.COLOR, 0.45 + 0.55 * propio)
