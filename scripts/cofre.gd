## El cofre de la sala secreta. Al pasar por encima se abre y sale la ruleta
## (Ruleta) con las ventajas: la que toque es para el jugador, para toda la
## partida, como un objeto recogido.
##
## Pedido por Matias el 2026-10-29: «dentro un cofre, y que al pasar por
## encima salga una ruleta con las ventajas y que te toque una al azar».
##
## Lo que toca sale de la suerte, no de la semilla del piso, como lo que
## sueltan los enemigos: el sitio del cofre es fijo, el premio no.
##
## Dibujado por codigo, como los escombros y las explosiones: una caja con
## tapa, bandas y cerradura no necesita arte, y asi brilla y se abre sin hojas
## de animacion.
class_name Cofre
extends Node2D

## Lo cerca que tienen que estar los pies del jugador para abrirlo.
const RADIO_TOCAR: float = 48.0
## Las medidas de abajo son las de un cofre de 54 px de ancho: se veia
## pequeno en una sala de 1400, y asi se agranda todo de una vez.
const ESCALA: float = 1.35
const COLOR_MADERA := Color(0.46, 0.27, 0.13)
const COLOR_MADERA_OSCURA := Color(0.27, 0.15, 0.07)
const COLOR_ORO := Color(1.0, 0.8, 0.3)

var abierto: bool = false

var _numero_piso: int = 1
var _tiempo: float = 0.0


func _init(numero_piso: int = 1) -> void:
	_numero_piso = numero_piso
	name = "Cofre"
	# Como los objetos: por encima del suelo y de lo que hay en el.
	z_index = 4


func _process(delta: float) -> void:
	_tiempo += delta
	queue_redraw()


## Se mira en cada paso si el jugador de este ordenador lo esta pisando. Solo
## ese: en cooperativo, el que lo abre ve la ruleta, y a los demas les llega la
## ventaja por la red (Cooperativo.cofre_abierto).
func _physics_process(_delta: float) -> void:
	if abierto or not is_visible_in_tree():
		return
	var jugador := get_tree().get_first_node_in_group("jugador") as Jugador
	if jugador == null or not jugador.sigue_vivo():
		return
	if jugador.global_position.distance_to(global_position) < RADIO_TOCAR:
		_abrir(jugador)


## Lo marca abierto sin ruleta. Lo usa el cooperativo cuando lo ha abierto
## otro jugador.
func marcar_abierto() -> void:
	abierto = true
	queue_redraw()


## Las ventajas que pueden tocar: las que duran (el vendaje, que solo cura,
## no es una ventaja) y que ya pueden salir a esta profundidad.
func ventajas() -> Array[ObjetoMejora]:
	var lista: Array[ObjetoMejora] = []
	for mejora in ObjetoMejora.cargar_todos():
		if mejora.es_permanente() and mejora.piso_minimo <= _numero_piso:
			lista.append(mejora)
	return lista


func _abrir(jugador: Jugador) -> void:
	abierto = true
	queue_redraw()
	Sonido.tocar(&"carga_lista")
	var lista := ventajas()
	if lista.is_empty():
		return
	var ganada: ObjetoMejora = lista[randi() % lista.size()]
	var ruleta := Ruleta.new(lista, ganada)
	ruleta.terminada.connect(_entregar.bind(jugador))
	add_child(ruleta)


func _entregar(mejora: ObjetoMejora, jugador: Jugador) -> void:
	if not is_instance_valid(jugador):
		return
	# Por donde pasa un objeto recogido: el HUD lo anuncia y lo ensena, y el
	# registro de la partida lo apunta (Jugador.mejora_recogida).
	jugador.aplicar_mejora(mejora)
	Sonido.tocar(&"objeto")
	# En cooperativo, para todos, como los objetos. Jugando solo no hay nadie
	# en el grupo.
	get_tree().call_group("cooperativo", "cofre_abierto", mejora)


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(ESCALA, ESCALA))
	# Sombra en el suelo.
	_elipse(Vector2(0.0, 2.0), Vector2(34.0, 8.0), Color(0.0, 0.0, 0.0, 0.35))
	if abierto:
		_pintar_abierto()
	else:
		_pintar_cerrado()


func _pintar_cerrado() -> void:
	# Un brillo que late detras, para que se vea que ahi hay algo.
	var latido := 0.5 + 0.5 * sin(_tiempo * 3.0)
	_elipse(Vector2(0.0, -22.0), Vector2(44.0, 34.0), Color(1.0, 0.8, 0.3, 0.07 + 0.08 * latido))
	_caja()
	# Tapa, abombada.
	var tapa := PackedVector2Array()
	for i in 13:
		var angulo := PI + PI * i / 12.0
		tapa.append(Vector2(cos(angulo) * 29.0, -30.0 + sin(angulo) * 13.0))
	draw_colored_polygon(tapa, COLOR_MADERA.lightened(0.08))
	draw_polyline(tapa + PackedVector2Array([tapa[0]]), COLOR_MADERA_OSCURA, 2.0, true)
	draw_line(Vector2(-29.0, -30.0), Vector2(29.0, -30.0), COLOR_MADERA_OSCURA, 2.0)
	# Bandas de oro por la tapa y la caja.
	for x in [-17.0, 15.0]:
		draw_rect(Rect2(x, -42.0, 5.0, 42.0), COLOR_ORO.darkened(0.15))
	# Cerradura.
	draw_rect(Rect2(-6.0, -34.0, 12.0, 12.0), COLOR_ORO)
	draw_circle(Vector2(0.0, -29.5), 2.2, COLOR_MADERA_OSCURA)
	draw_rect(Rect2(-1.0, -29.0, 2.0, 4.5), COLOR_MADERA_OSCURA)
	# Un destello que pasa de vez en cuando por el oro.
	var destello := fposmod(_tiempo * 0.6, 1.0)
	if destello < 0.25:
		var x := lerpf(-30.0, 30.0, destello / 0.25)
		draw_line(Vector2(x, -40.0), Vector2(x + 6.0, -2.0), Color(1.0, 1.0, 0.9, 0.35), 3.0)


func _pintar_abierto() -> void:
	_caja()
	# Dentro, oscuro, con lo que queda del brillo.
	draw_rect(Rect2(-26.0, -32.0, 52.0, 8.0), Color(0.08, 0.05, 0.03))
	_elipse(Vector2(0.0, -30.0), Vector2(22.0, 5.0), Color(1.0, 0.85, 0.4, 0.25))
	# La tapa, echada hacia atras: se ve de canto, por encima.
	draw_rect(Rect2(-29.0, -52.0, 58.0, 18.0), COLOR_MADERA.darkened(0.1))
	draw_rect(Rect2(-29.0, -52.0, 58.0, 18.0), COLOR_MADERA_OSCURA, false, 2.0)
	for x in [-17.0, 15.0]:
		draw_rect(Rect2(x, -52.0, 5.0, 18.0), COLOR_ORO.darkened(0.25))


## La caja de abajo, igual abierta que cerrada.
func _caja() -> void:
	draw_rect(Rect2(-27.0, -30.0, 54.0, 30.0), COLOR_MADERA)
	draw_rect(Rect2(-27.0, -30.0, 54.0, 30.0), COLOR_MADERA_OSCURA, false, 2.0)
	# Tablas.
	draw_line(Vector2(-27.0, -15.0), Vector2(27.0, -15.0), COLOR_MADERA_OSCURA.lerp(COLOR_MADERA, 0.4), 1.5)
	for x in [-17.0, 15.0]:
		draw_rect(Rect2(x, -30.0, 5.0, 30.0), COLOR_ORO.darkened(0.15))


func _elipse(centro: Vector2, radios: Vector2, color: Color) -> void:
	var puntos := PackedVector2Array()
	for i in 24:
		var angulo := TAU * i / 24.0
		puntos.append(centro + Vector2(cos(angulo) * radios.x, sin(angulo) * radios.y))
	draw_colored_polygon(puntos, color)
