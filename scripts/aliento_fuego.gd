## El aliento de fuego del jefe: un chorro de fuego que sale de el y
## gira barriendo la sala. Pedido por Matias el 2026-11-03: «escupira fuego de
## vez en cuando, quemando al jugador. Toma como referencia la posicion del
## jugador al empezar a escupirlo; apunta a 10 grados de ese punto, en sentido
## horario o antihorario al azar, y gira 90 grados en 2 segundos en el sentido
## contrario (hacia el jugador). Llega hasta el limite de la sala».
##
## Lo crea el jefe (ComportamientoCorazonNucleo, la accion "aliento") por MundoRed:
## sale en todos los ordenadores y cada uno mira si le da al jugador del suyo,
## como el resto de lo del jefe.
##
## Antes de salir avisa 'aviso' segundos: una linea por donde va a empezar y
## una flecha hacia donde va a girar. Todo lo que pega de golpe avisa antes.
##
## El chorro llega hasta el limite del suelo de la sala, pasando por encima
## de rocas y pilares (no se para en ellos ni los rompe, como pidio Matias).
## A quien toca le quita 'dano' (con el parpadeo de siempre entre golpe y
## golpe) y le deja quemandose (Jugador.quemar). El escudo del mago blanco lo
## para, como todo lo de los enemigos.
class_name AlientoFuego
extends Node2D

const COLOR_FUEGO := Color(1.0, 0.55, 0.15)
const COLOR_NUCLEO := Color(1.0, 0.92, 0.55)
## Lo que tarda en apagarse al acabar, para que no desaparezca de golpe.
const APAGADO: float = 0.3
## Ancho del chorro en la boca: crece hasta 'ancho' al final.
const ANCHO_BOCA: float = 16.0
## El radio del cuerpo del jugador (el mismo que usan los proyectiles).
const RADIO_JUGADOR: float = 15.0

## Hacia donde sale (radianes, como Vector2.angle()) y cuanto gira hasta el
## final (con signo: hacia el jugador).
var angulo_inicio: float = 0.0
var giro: float = PI * 0.5
var aviso: float = 0.6
var duracion: float = 2.0
var ancho: float = 44.0
var dano: int = 15
var quema_segundos: float = 3.0
var quema_dano: int = 3
var origen: String = "Corazón del Núcleo (aliento de fuego)"
## Suelo de la sala, en el mundo: hasta ahi llega el chorro.
var limite: Rect2 = Rect2()

var _t: float = 0.0
var _sonado: bool = false


func _ready() -> void:
	# Por encima del suelo, las rocas y los enemigos (5); por debajo del
	# jugador (10), que tiene que verse dentro del fuego.
	z_index = 6


func _process(delta: float) -> void:
	_t += delta
	if not _sonado and _t >= aviso:
		_sonado = true
		Sonido.tocar(&"magma")
	if _t >= aviso + duracion + APAGADO:
		queue_free()
		return
	queue_redraw()


func _physics_process(_delta: float) -> void:
	if _t < aviso or _t > aviso + duracion:
		return
	var jugador := get_tree().get_first_node_in_group("jugador") as Jugador
	if jugador == null or not jugador.sigue_vivo() or jugador.escudo_activo():
		return
	var centro := jugador.centro_colision()
	var cerca := Geometry2D.get_closest_point_to_segment(centro, global_position,
		global_position + punta(angulo_actual()))
	if centro.distance_to(cerca) < ancho * 0.5 + RADIO_JUGADOR:
		jugador.recibir_dano(dano, false, origen)
		# Quemandose mientras le toque: la quemadura se rellena.
		jugador.quemar(quema_segundos, quema_dano, origen)


## Hacia donde apunta ahora: el de salida hasta que acaba el aviso, y luego
## girando a ritmo constante hasta el final.
func angulo_actual() -> float:
	var avance := clampf((_t - aviso) / maxf(duracion, 0.01), 0.0, 1.0)
	return angulo_inicio + giro * avance


## Del jefe al limite de la sala en esa direccion, en local.
func punta(angulo: float) -> Vector2:
	var direccion := Vector2.RIGHT.rotated(angulo)
	if not limite.has_area():
		return direccion * 1000.0
	var largo := INF
	var desde := global_position
	if direccion.x > 0.001:
		largo = minf(largo, (limite.end.x - desde.x) / direccion.x)
	elif direccion.x < -0.001:
		largo = minf(largo, (limite.position.x - desde.x) / direccion.x)
	if direccion.y > 0.001:
		largo = minf(largo, (limite.end.y - desde.y) / direccion.y)
	elif direccion.y < -0.001:
		largo = minf(largo, (limite.position.y - desde.y) / direccion.y)
	return direccion * maxf(largo, 0.0)


func _draw() -> void:
	if _t < aviso:
		_pintar_aviso()
		return
	var queda := 1.0
	if _t > aviso + duracion:
		queda = 1.0 - (_t - aviso - duracion) / APAGADO
	_pintar_chorro(punta(angulo_actual()), clampf(queda, 0.0, 1.0))


## Por donde va a empezar (una linea que late) y una flecha en arco hacia
## donde va a girar: con eso se sabe hacia que lado apartarse.
func _pintar_aviso() -> void:
	var avance := _t / maxf(aviso, 0.01)
	var alfa := 0.25 + 0.55 * avance * (0.6 + 0.4 * absf(sin(_t * 18.0)))
	draw_line(Vector2.ZERO, punta(angulo_inicio), Color(COLOR_FUEGO, alfa), 2.0 + 4.0 * avance)
	var radio := 110.0
	var hasta := angulo_inicio + giro * 0.4
	draw_arc(Vector2.ZERO, radio, angulo_inicio, hasta, 16, Color(COLOR_NUCLEO, alfa), 4.0, true)
	# La punta de la flecha, al final del arco, apuntando hacia donde gira.
	var final := Vector2.RIGHT.rotated(hasta) * radio
	var tangente := Vector2.RIGHT.rotated(hasta + signf(giro) * PI * 0.5)
	var lado := final.normalized()
	draw_colored_polygon(PackedVector2Array([final + tangente * 14.0, final + lado * 9.0,
		final - lado * 9.0]), Color(COLOR_NUCLEO, alfa))
	draw_circle(Vector2.ZERO, 10.0 + 14.0 * avance, Color(COLOR_FUEGO, 0.3 + 0.3 * avance))


## El chorro: una cuña que se ensancha de la boca a la punta, naranja por fuera
## y amarilla por dentro, que tiembla, con unas lenguas de fuego por el borde.
func _pintar_chorro(hasta: Vector2, queda: float) -> void:
	var largo := hasta.length()
	if largo < 1.0:
		return
	var direccion := hasta / largo
	var lado := direccion.orthogonal()
	var temblor := 1.0 + 0.08 * sin(_t * 40.0)
	var fuera := ancho * 0.6 * temblor
	var cuna := PackedVector2Array([lado * ANCHO_BOCA * 0.5, hasta + lado * fuera,
		hasta - lado * fuera, -lado * ANCHO_BOCA * 0.5])
	draw_colored_polygon(cuna, Color(COLOR_FUEGO, 0.75 * queda))
	var dentro := PackedVector2Array([lado * ANCHO_BOCA * 0.25, hasta + lado * fuera * 0.45,
		hasta - lado * fuera * 0.45, -lado * ANCHO_BOCA * 0.25])
	draw_colored_polygon(dentro, Color(COLOR_NUCLEO, 0.85 * queda))
	for k in 10:
		var avance := fposmod(_t * 1.8 + k * 0.1, 1.0)
		var sitio := direccion * largo * avance + lado * sin(_t * 23.0 + k * 2.1) * fuera * avance * 0.7
		draw_circle(sitio, (5.0 + 9.0 * avance) * queda, Color(1.0, 0.7 + 0.2 * sin(k), 0.2, 0.55 * queda))
	draw_circle(Vector2.ZERO, 20.0 * temblor, Color(COLOR_NUCLEO, 0.6 * queda))
