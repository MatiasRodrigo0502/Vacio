## El sello del suelo de la sala del jefe: anillos grabados con runas alrededor
## de la bajada, que brillan flojo y giran despacio.
##
## POR QUE: sin el, la sala del jefe es una sala normal mas grande. El sello
## dice que es un sitio aparte y marca el centro, que es donde estara el jefe.
## Flojo a proposito: en mitad de la pelea no puede quitarle protagonismo a
## los disparos, que son lo que hay que ver.
class_name SelloJefe
extends Node2D

## Cuantas runas lleva el anillo.
const RUNAS: int = 12
## Vueltas por segundo del anillo de runas. Muy lento: se nota, no marea.
const GIRO: float = 0.02
const LATIDO: float = 4.0

var _radio: float
var _fase: float = 0.0


## 'tamano' es el del suelo de la sala: el sello se ajusta a su lado corto.
func _init(tamano: Vector2) -> void:
	name = "SelloJefe"
	_radio = minf(tamano.x, tamano.y) * 0.36
	# Por encima del suelo, por debajo de todo lo demas (rocas, peligros,
	# enemigos y el jugador van por encima).
	z_index = 0


func _process(delta: float) -> void:
	_fase += delta
	queue_redraw()


func _draw() -> void:
	var latido := 0.5 + 0.5 * sin(_fase * TAU / LATIDO)
	var color := Color(Runas.COLOR, 0.16 + 0.08 * latido)
	# Dos anillos por fuera, uno por dentro (alrededor de la bajada) y radios
	# entre ellos: un circulo de invocacion.
	draw_arc(Vector2.ZERO, _radio, 0.0, TAU, 96, color, 3.0, true)
	draw_arc(Vector2.ZERO, _radio - 14.0, 0.0, TAU, 96, color, 1.5, true)
	var interior := _radio * 0.45
	draw_arc(Vector2.ZERO, interior, 0.0, TAU, 64, color, 2.0, true)
	for i in 6:
		var hacia := Vector2.RIGHT.rotated(i * TAU / 6.0 + PI / 6.0)
		draw_line(hacia * interior, hacia * (_radio - 40.0), Color(color, color.a * 0.7), 1.5, true)
	# Las runas, entre los dos anillos de fuera, girando.
	var giro := _fase * GIRO * TAU
	for i in RUNAS:
		var sitio := Vector2.RIGHT.rotated(giro + i * TAU / RUNAS) * (_radio - 34.0)
		Runas.pintar(self, sitio, 18.0, i, Runas.COLOR, 0.35 + 0.25 * latido)
