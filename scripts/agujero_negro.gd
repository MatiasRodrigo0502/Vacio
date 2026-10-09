## Agujero negro: lo que abre la bola cargada del mago oscuro donde se acaba.
## Atrae a los enemigos de la sala que estan a su alcance y quita vida a los
## que llegan al centro, durante unos segundos.
##
## POR QUE LA BOLA LLEGA MENOS LEJOS QUE LA DEL MAGO ROJO:
## la del rojo va hasta chocar y mata de un golpe lo que pilla; la del oscuro
## se queda a media sala (PersonajeJugable.alcance_cargado) y lo que gana es
## esto, que junta a los enemigos y los va gastando. Son dos formas de usar el
## ataque especial: apuntar a uno o a un grupo.
##
## POR QUE SOLO LOS ENEMIGOS DE SU SALA:
## las bolas no salen de la sala (BolaMagica.limite) y esto tampoco: tirar de
## enemigos de la sala de al lado, que el jugador no ve, los sacaria de su
## sitio sin que nadie lo entienda.
##
## Lo crea Principal al apagarse la bola (BolaMagica.apagada). Dibujado por
## codigo, como las bolas: no hay arte de esto en los packs.
class_name AgujeroNegro
extends Node2D

## Radio del centro, donde hace dano.
const NUCLEO: float = 34.0
## Cada cuanto quita vida. A tics y no un poco cada fotograma: cada golpe hace
## parpadear al enemigo, y parpadeando sin parar no se veria nada.
const TIC: float = 0.5
## Lo que tira de un enemigo, en px/s: en el centro y en el borde. Mas que la
## velocidad de casi todos (el murcielago, 195), para que no se le escapen
## andando, salvo desde el mismo borde.
const TIRON_CENTRO: float = 330.0
const TIRON_BORDE: float = 150.0
## Lo que tarda en abrirse y en cerrarse: crece y se encoge, no salta.
const APERTURA: float = 0.25
const CIERRE: float = 0.35
## Motas de luz que caen hacia el centro en espiral.
const MOTAS: int = 28
const NEGRO := Color(0.02, 0.0, 0.05)

var _sala: Sala
var _duracion: float
var _radio: float
var _dano: float
var _color: Color
var _halo: Color
var _tiempo: float = 0.0
## El primer tic llega pronto: lo que ya esta en el centro al abrirse lo nota.
var _tic: float = TIC * 0.5
## El centro negro y su disco van en un nodo aparte, por encima de los
## enemigos (z 5): asi lo que llega al centro se ve tragado. Lo demas (el
## circulo de alcance y las motas) va por debajo, para no tapar a nadie.
var _nucleo: Node2D


func _init(sala: Sala, duracion: float, radio: float, dano_por_segundo: float,
		color: Color, halo: Color) -> void:
	_sala = sala
	_duracion = duracion
	_radio = radio
	_dano = dano_por_segundo
	_color = color
	_halo = halo
	name = "AgujeroNegro"
	# Por encima del suelo y de las rocas, por debajo de objetos y enemigos.
	z_index = 3
	_nucleo = Node2D.new()
	# Por encima de enemigos, sus disparos y las explosiones; por debajo de las
	# bolas del jugador (9) y del jugador (10).
	_nucleo.z_index = 8
	_nucleo.z_as_relative = false
	_nucleo.draw.connect(_pintar_nucleo)
	add_child(_nucleo)


func _physics_process(delta: float) -> void:
	_tiempo += delta
	if _tiempo >= _duracion or not is_instance_valid(_sala):
		queue_free()
		return
	_tic -= delta
	var toca_dano := _tic <= 0.0
	if toca_dano:
		_tic += TIC
	var fuerza := _fuerza()
	for enemigo in _sala.enemigos():
		if not is_instance_valid(enemigo):
			continue
		var hacia := global_position - enemigo.global_position
		var distancia := hacia.length()
		if distancia > _radio:
			continue
		if distancia > 1.0:
			var tiron := lerpf(TIRON_CENTRO, TIRON_BORDE, distancia / _radio) * fuerza
			# Sin pasarse del centro: si no, lo que esta dentro tiembla de
			# un lado al otro.
			enemigo.global_position += hacia / distancia * minf(tiron * delta, distancia)
			# Que el tiron no lo meta en una roca ni lo saque de la sala.
			enemigo.mantener_en_la_sala()
		if toca_dano and distancia <= NUCLEO:
			enemigo.herir(_dano * TIC)
	queue_redraw()
	_nucleo.queue_redraw()


## De 0 a 1: crece al abrirse y se encoge al cerrarse. Tira con esa fuerza y
## se dibuja de ese tamano.
func _fuerza() -> float:
	return clampf(minf(_tiempo / APERTURA, (_duracion - _tiempo) / CIERRE), 0.0, 1.0)


func _draw() -> void:
	var f := _fuerza()
	if f <= 0.0:
		return
	# Hasta donde atrae: un circulo flojo, para que se vea que hay que salir.
	draw_circle(Vector2.ZERO, _radio * f, Color(_halo, 0.08))
	draw_arc(Vector2.ZERO, _radio * f, 0.0, TAU, 48, Color(_halo, 0.3), 1.5, true)
	# Se oscurece hacia dentro: se lee como un hoyo y no como un circulo plano.
	for k in 4:
		draw_circle(Vector2.ZERO, lerpf(_radio * 0.7, NUCLEO * 1.2, k / 3.0) * f, Color(NEGRO, 0.13))

	# Motas en espiral: cada una entra desde el borde y gira mas deprisa
	# cuanto mas cerca del centro, como el agua por un desague.
	for k in MOTAS:
		var avance := fposmod(_tiempo * 0.6 + float(k) / MOTAS + 0.37 * k, 1.0)
		var r := lerpf(_radio, NUCLEO * 0.7, avance) * f
		var angulo := k * 2.399 + _tiempo * 1.4 + avance * 5.0
		var punto := Vector2.from_angle(angulo) * r
		var estela := Vector2.from_angle(angulo - 0.45) * (r + 16.0)
		draw_line(estela, punto, Color(_color, 0.3 + 0.7 * avance), 2.5, true)


func _pintar_nucleo() -> void:
	var f := _fuerza()
	if f <= 0.0:
		return
	# El disco que gira alrededor del centro, con dos tramos mas brillantes.
	var giro := _tiempo * 4.0
	_nucleo.draw_arc(Vector2.ZERO, NUCLEO * f, 0.0, TAU, 40, Color(_halo, 0.55), 7.0, true)
	for k in 2:
		var desde := giro + k * PI
		_nucleo.draw_arc(Vector2.ZERO, NUCLEO * f, desde, desde + 1.6, 16, Color(_color, 0.9), 3.0, true)

	# El centro, negro, con un filo de luz.
	_nucleo.draw_circle(Vector2.ZERO, NUCLEO * 0.72 * f, NEGRO)
	_nucleo.draw_arc(Vector2.ZERO, NUCLEO * 0.72 * f, 0.0, TAU, 32, Color(1.0, 0.9, 1.0, 0.7), 1.5, true)
