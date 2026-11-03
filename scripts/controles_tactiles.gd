## Los mandos del movil (pedido por Matias el 2026-11-03): un joystick a cada
## lado de la pantalla, como en Brawl Stars. Cada uno sale donde se pone el
## dedo y se va al levantarlo: el de la izquierda (azul) mueve al mago, y el
## de la derecha (rojo) apunta y dispara mientras se aparta del centro.
##
## Cada joystick es una bola pequena opaca (donde esta el dedo), un circulo
## grande translucido (hasta donde llega) y la circunferencia de ese circulo,
## entre opaca y translucida.
##
## Ademas, dos botones fijos que el teclado tenia y la pantalla no: el ataque
## especial (abajo a la derecha, del color del mago; se arrastra para
## apuntarlo, como el super de Brawl Stars) y la pausa (arriba en el centro).
##
## COMO LLEGA AL JUGADOR: por tres vectores estaticos, en la pantalla
## (movimiento, apuntado, especial), que el jugador lee y pasa al mundo con
## Vista. Asi el jugador no sabe nada de dedos, y con el movil en vertical
## arriba sigue siendo arriba. El especial, pulsando la accion del espacio
## (cargar_ataque_teclado), que ya sabe cargar, soltar y sacar el escudo.
##
## Los crea Principal solo en el movil (hace_falta). Para probarlos en el
## ordenador: arrancar con --tactil (detras de --), y el raton hace de dedo.
class_name ControlesTactiles
extends CanvasLayer

## Lo que piden ahora, en la pantalla, de 0 a 1 de largo. ZERO = nada.
static var movimiento: Vector2 = Vector2.ZERO
static var apuntado: Vector2 = Vector2.ZERO
## Hacia donde se ha arrastrado el especial. Se queda al soltar: el jugador
## lo lee en el paso siguiente, al lanzarlo.
static var especial: Vector2 = Vector2.ZERO
## True mientras estan puestos. El jugador deja de hacer caso al clic
## izquierdo: cada dedo que toca la pantalla hace tambien de clic.
static var activos: bool = false

## Hasta donde llega la bola, del centro al borde del circulo grande, y lo
## que mide ella. En pixeles de la pantalla del juego (1152 x 648 o mas).
const RADIO: float = 95.0
const RADIO_BOLA: float = 38.0
## Por debajo de esto (en parte del radio) no pide nada: un dedo apoyado
## siempre se mueve un poco.
const ZONA_MUERTA: float = 0.18
const AZUL := Color(0.25, 0.58, 1.0)
const ROJO := Color(1.0, 0.3, 0.3)
## Lo opaco de cada parte: la bola, el circulo y su circunferencia.
const ALFA_BOLA: float = 1.0
const ALFA_CIRCULO: float = 0.22
const ALFA_BORDE: float = 0.6
const GROSOR_BORDE: float = 4.0
## El boton del especial: su radio y su sitio, desde la esquina de abajo a
## la derecha.
const RADIO_ESPECIAL: float = 54.0
const SITIO_ESPECIAL := Vector2(-130.0, -230.0)
## El de la pausa, arriba en el centro.
const RADIO_PAUSA: float = 30.0
const SITIO_PAUSA_ALTO: float = 44.0
## El dedo que hace el raton al probarlos en el ordenador.
const DEDO_RATON: int = 99


## Un joystick: el dedo que lo lleva, donde se puso y donde esta ahora.
class Palanca:
	var dedo: int = -1
	var centro: Vector2 = Vector2.ZERO
	var punta: Vector2 = Vector2.ZERO

	func activa() -> bool:
		return dedo >= 0

	func empezar(indice: int, sitio: Vector2) -> void:
		dedo = indice
		centro = sitio
		punta = sitio

	func soltar() -> void:
		dedo = -1

	## Lo que pide, de 0 a 1 de largo, con la zona muerta quitada.
	func vector() -> Vector2:
		if not activa():
			return Vector2.ZERO
		var desvio := (punta - centro) / RADIO
		var largo := minf(desvio.length(), 1.0)
		if largo < ZONA_MUERTA:
			return Vector2.ZERO
		return desvio.normalized() * (largo - ZONA_MUERTA) / (1.0 - ZONA_MUERTA)

	## Donde se pinta la bola: el dedo, sin salirse del circulo.
	func bola() -> Vector2:
		return centro + (punta - centro).limit_length(RADIO)


var _jugador: Jugador
var _izquierda := Palanca.new()
var _derecha := Palanca.new()
var _especial := Palanca.new()
var _lienzo: Control
var _con_raton: bool = false


## Solo en el movil, o en el ordenador si se pide con --tactil.
static func hace_falta() -> bool:
	return OS.has_feature("mobile") or "--tactil" in OS.get_cmdline_user_args()


func _init(jugador: Jugador) -> void:
	_jugador = jugador
	name = "ControlesTactiles"
	# Encima del HUD (1) y debajo de la pantalla final (3) y la pausa (4).
	layer = 2


func _ready() -> void:
	activos = true
	_con_raton = not OS.has_feature("mobile")
	_lienzo = Control.new()
	_lienzo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lienzo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lienzo.draw.connect(_pintar)
	add_child(_lienzo)


func _exit_tree() -> void:
	_soltar_todo()
	activos = false


## Al pausar (la pausa, las ventanas del tutorial, la ruleta) se sueltan:
## mientras tanto no llegan los dedos que se levantan, y al volver se
## quedarian pulsados.
func _notification(que: int) -> void:
	if que == NOTIFICATION_PAUSED or que == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_soltar_todo()


func _input(evento: InputEvent) -> void:
	# Muerto (o al acabar la partida) no se pinta nada: mandan los botones de
	# la pantalla final.
	if not _jugador.sigue_vivo():
		if _izquierda.activa() or _derecha.activa() or _especial.activa():
			_soltar_todo()
		return
	var toque := evento as InputEventScreenTouch
	var arrastre := evento as InputEventScreenDrag
	if _con_raton:
		var boton := evento as InputEventMouseButton
		var movido := evento as InputEventMouseMotion
		if boton != null and boton.button_index == MOUSE_BUTTON_LEFT:
			_tocar(DEDO_RATON, boton.position, boton.pressed)
		elif movido != null and movido.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_arrastrar(DEDO_RATON, movido.position)
	if toque != null:
		_tocar(toque.index, toque.position, toque.pressed)
	elif arrastre != null:
		_arrastrar(arrastre.index, arrastre.position)


func _tocar(dedo: int, sitio: Vector2, pulsado: bool) -> void:
	if not pulsado:
		_levantar(dedo)
		return
	var pantalla := _lienzo.size
	if sitio.distance_to(_sitio_pausa()) <= RADIO_PAUSA * 1.3:
		_pausar()
		return
	if sitio.distance_to(_sitio_especial()) <= RADIO_ESPECIAL * 1.2:
		if not _especial.activa() and _jugador.especial_disponible:
			_especial.empezar(dedo, _sitio_especial())
			_especial.punta = sitio
			especial = Vector2.ZERO
			Input.action_press("cargar_ataque_teclado")
		return
	if sitio.x < pantalla.x * 0.5:
		if not _izquierda.activa():
			_izquierda.empezar(dedo, sitio)
	elif not _derecha.activa():
		_derecha.empezar(dedo, sitio)
	_actualizar()


func _arrastrar(dedo: int, sitio: Vector2) -> void:
	for palanca in [_izquierda, _derecha, _especial]:
		if palanca.dedo == dedo:
			palanca.punta = sitio
	_actualizar()


func _levantar(dedo: int) -> void:
	if _especial.dedo == dedo:
		especial = _especial.vector()
		_especial.soltar()
		Input.action_release("cargar_ataque_teclado")
	if _izquierda.dedo == dedo:
		_izquierda.soltar()
	if _derecha.dedo == dedo:
		_derecha.soltar()
	_actualizar()


func _actualizar() -> void:
	movimiento = _izquierda.vector()
	apuntado = _derecha.vector()
	if _especial.activa():
		especial = _especial.vector()
	_lienzo.queue_redraw()


func _soltar_todo() -> void:
	if _especial.activa():
		Input.action_release("cargar_ataque_teclado")
	_izquierda.soltar()
	_derecha.soltar()
	_especial.soltar()
	movimiento = Vector2.ZERO
	apuntado = Vector2.ZERO
	especial = Vector2.ZERO
	if _lienzo != null:
		_lienzo.queue_redraw()


## La pausa como si se pulsara Escape: la abre MenuPausa, que ya sabe todo.
func _pausar() -> void:
	_soltar_todo()
	var pausa := InputEventAction.new()
	pausa.action = "pausar"
	pausa.pressed = true
	Input.parse_input_event(pausa)


func _sitio_especial() -> Vector2:
	return _lienzo.size + SITIO_ESPECIAL


func _sitio_pausa() -> Vector2:
	return Vector2(_lienzo.size.x * 0.5, SITIO_PAUSA_ALTO)


func _process(_delta: float) -> void:
	# El boton del especial cambia al gastarlo y al recuperarlo.
	_lienzo.queue_redraw()


func _pintar() -> void:
	if not _jugador.sigue_vivo():
		return
	_pintar_pausa()
	_pintar_boton_especial()
	if _izquierda.activa():
		_pintar_palanca(_izquierda, AZUL)
	if _derecha.activa():
		_pintar_palanca(_derecha, ROJO)


## La bola opaca, el circulo translucido y su circunferencia a medias.
func _pintar_palanca(palanca: Palanca, color: Color) -> void:
	_lienzo.draw_circle(palanca.centro, RADIO, Color(color, ALFA_CIRCULO))
	_lienzo.draw_arc(palanca.centro, RADIO, 0.0, TAU, 64, Color(color, ALFA_BORDE),
		GROSOR_BORDE, true)
	_lienzo.draw_circle(palanca.bola(), RADIO_BOLA, Color(color, ALFA_BOLA))


## Del color del mago mientras queda; gris si ya se ha usado en este piso.
## Mientras se arrastra, es un joystick mas, desde el boton.
func _pintar_boton_especial() -> void:
	var sitio := _sitio_especial()
	var color := _jugador.mago.color if _jugador.mago != null else Color.WHITE
	if not _jugador.especial_disponible:
		color = Color(0.55, 0.55, 0.55)
	if _especial.activa():
		var palanca_color := color
		_pintar_palanca(_especial, palanca_color)
		return
	var alfa := 1.0 if _jugador.especial_disponible else 0.45
	_lienzo.draw_circle(sitio, RADIO_ESPECIAL, Color(color, ALFA_CIRCULO * 1.4 * alfa))
	_lienzo.draw_arc(sitio, RADIO_ESPECIAL, 0.0, TAU, 48, Color(color, ALFA_BORDE * alfa),
		GROSOR_BORDE, true)
	# Una estrella de cuatro puntas: lo especial.
	var puntos := PackedVector2Array()
	for i in 8:
		var largo := RADIO_ESPECIAL * (0.55 if i % 2 == 0 else 0.2)
		puntos.append(sitio + Vector2.UP.rotated(i * TAU / 8.0) * largo)
	_lienzo.draw_colored_polygon(puntos, Color(color, alfa))


func _pintar_pausa() -> void:
	var sitio := _sitio_pausa()
	_lienzo.draw_circle(sitio, RADIO_PAUSA, Color(0.0, 0.0, 0.0, 0.35))
	_lienzo.draw_arc(sitio, RADIO_PAUSA, 0.0, TAU, 40, Color(1.0, 1.0, 1.0, ALFA_BORDE),
		3.0, true)
	for lado in [-1.0, 1.0]:
		_lienzo.draw_rect(Rect2(sitio + Vector2(lado * 7.0 - 3.5, -10.0), Vector2(7.0, 20.0)),
			Color(1.0, 1.0, 1.0, 0.9))
