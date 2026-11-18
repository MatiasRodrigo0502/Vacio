## Los mandos del movil (pedido por Matias el 2026-11-03), como en Brawl Stars: el
## joystick de la izquierda (azul) mueve al mago, el de la derecha (rojo) apunta y
## dispara mientras se aparta del centro, y el del ataque especial (del color del
## mago) se arrastra para apuntarlo, como el super.
##
## Cada joystick es una bola pequena opaca (donde esta el dedo), un circulo
## grande translucido (hasta donde llega) y la circunferencia de ese circulo,
## entre opaca y translucida.
##
## DONDE ESTAN Y COMO SE PORTAN (Matias, 2026-11-18): cada uno tiene su sitio, su
## tamano y dos interruptores, oculto y estatico (AjustesMandos, que explica cada
## cosa y los cambia el editor de controles). Por defecto se ven en las esquinas de
## abajo, translucidos (ALFA_REPOSO, un 75 % transparentes) hasta que se toca la
## pantalla. Un dedo coge el joystick de la ulti si cae en su boton; si no, el de
## moverse o el de apuntar, el que tenga mas cerca. El centro es donde cae el dedo;
## el que no es estatico (el de moverse, por defecto) sigue al dedo si se sale del
## circulo grande.
##
## Ademas, dos botones que el teclado tenia y la pantalla no: la pausa (arriba en el
## centro) y, con un arma mitica, el de cambiar de modo (al lado de la ulti).
##
## COMO LLEGA AL JUGADOR: por tres vectores estaticos, en la pantalla
## (movimiento, apuntado, especial), que el jugador lee y pasa al mundo con
## Vista. Asi el jugador no sabe nada de dedos, y con el movil en vertical
## arriba sigue siendo arriba. El especial, pulsando la accion del espacio
## (cargar_ataque_teclado), que ya sabe cargar, soltar y sacar el escudo.
##
## Los crea Principal solo con pantalla tactil (hace_falta). Para probarlos en el
## ordenador: arrancar con --tactil (detras de --), y el raton hace de dedo.
##
## EN EL NAVEGADOR, TACTIL Y TECLADO A LA VEZ (Matias, 2026-11-18: «si el jugador usa
## teclado o ratón, se ocultan los joysticks; si toca la pantalla, se muestran»): una
## tableta con teclado, o un portatil con pantalla tactil, puede usar las dos cosas.
## Manda lo ultimo que se ha usado: una tecla o el raton de verdad apagan los mandos
## (activos a false: el jugador vuelve a hacer caso al raton) y tocar la pantalla los
## enciende. El raton que el navegador se inventa con cada dedo (el de «emulacion»)
## no cuenta.
class_name ControlesTactiles
extends CanvasLayer

## Lo que piden ahora, en la pantalla, de 0 a 1 de largo. ZERO = nada.
static var movimiento: Vector2 = Vector2.ZERO
static var apuntado: Vector2 = Vector2.ZERO
## Hacia donde se ha arrastrado el especial. Se queda al soltar: el jugador
## lo lee en el paso siguiente, al lanzarlo.
static var especial: Vector2 = Vector2.ZERO
## True mientras se juega tocando la pantalla. El jugador deja de hacer caso al
## clic izquierdo: cada dedo que toca la pantalla hace tambien de clic. Con teclado
## o raton (ver arriba, EN EL NAVEGADOR), false: los mandos ni se ven.
static var activos: bool = false

## Hasta donde llega la bola, del centro al borde del circulo grande, y lo
## que mide ella, con el tamano normal (AjustesMandos "tamano" lo multiplica). En
## pixeles de la pantalla del juego (1152 x 648 o mas).
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
## Lo opaco que se ven sin ningun dedo en la pantalla: un 75 % transparentes
## (Matias, 2026-11-18). Con un dedo, del todo. Va pasando de uno a otro en
## CAMBIO_ALFA segundos, sin saltos.
const ALFA_REPOSO: float = 0.25
const CAMBIO_ALFA: float = 0.15
## El boton de la ulti en reposo: su radio con el tamano normal.
const RADIO_ESPECIAL: float = 54.0
## El de la pausa, arriba en el centro.
const RADIO_PAUSA: float = 30.0
const SITIO_PAUSA_ALTO: float = 44.0
## El de cambiar de modo, con un arma mitica, al lado de la ulti (desde ella): sin
## rueda ni tecla, es la unica forma.
const RADIO_MODO: float = 36.0
const SITIO_MODO := Vector2(-120.0, 40.0)
## El dedo que hace el raton al probarlos en el ordenador.
const DEDO_RATON: int = 99
## Lo que se ignora el raton de verdad despues de tocar la pantalla: algunos
## navegadores mandan, ademas del toque, un clic de raton por compatibilidad.
const RATON_TRAS_TOQUE_MS: int = 600


## Un joystick: de que mando es, el dedo que lo lleva, donde esta su centro y donde
## esta el dedo.
class Palanca:
	var mando: StringName
	var dedo: int = -1
	var centro: Vector2 = Vector2.ZERO
	var punta: Vector2 = Vector2.ZERO

	func _init(cual: StringName) -> void:
		mando = cual

	func activa() -> bool:
		return dedo >= 0

	func radio() -> float:
		return RADIO * AjustesMandos.dato(mando, "tamano")

	func empezar(indice: int, sitio: Vector2) -> void:
		dedo = indice
		centro = sitio
		punta = sitio

	## El dedo se mueve. Si no es estatico y se sale del circulo, el circulo va
	## detras: se queda con el dedo justo en su borde.
	func mover(sitio: Vector2) -> void:
		punta = sitio
		var desvio := punta - centro
		if not AjustesMandos.dato(mando, "estatico") and desvio.length() > radio():
			centro = punta - desvio.normalized() * radio()

	func soltar() -> void:
		dedo = -1

	## Lo que pide, de 0 a 1 de largo, con la zona muerta quitada.
	func vector() -> Vector2:
		if not activa():
			return Vector2.ZERO
		var desvio := (punta - centro) / radio()
		var largo := minf(desvio.length(), 1.0)
		if largo < ZONA_MUERTA:
			return Vector2.ZERO
		return desvio.normalized() * (largo - ZONA_MUERTA) / (1.0 - ZONA_MUERTA)

	## Donde se pinta la bola: el dedo, sin salirse del circulo.
	func bola() -> Vector2:
		return centro + (punta - centro).limit_length(radio())


var _jugador: Jugador
var _izquierda := Palanca.new(AjustesMandos.IZQUIERDO)
var _derecha := Palanca.new(AjustesMandos.DERECHO)
var _especial := Palanca.new(AjustesMandos.ULTI)
var _lienzo: Control
var _con_raton: bool = false
## Cuando se toco la pantalla por ultima vez (Time.get_ticks_msec).
var _ultimo_toque: int = -RATON_TRAS_TOQUE_MS
## Los dedos que hay ahora en la pantalla, y lo opaco que se ven los mandos.
var _dedos: Dictionary = {}
var _alfa: float = ALFA_REPOSO


## Si se juega en un movil, con la app o en su navegador. Aparte, porque en el
## navegador "mobile" es falso aunque sea un movil: lo dicen web_android y web_ios.
static func en_el_movil() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")


## Si la pantalla se puede tocar: el movil (la app o su navegador) y, en el
## navegador, cualquier aparato con pantalla tactil. Una tableta no siempre es
## "mobile": el navegador del iPad se presenta como el de un Mac.
static func pantalla_tactil() -> bool:
	return en_el_movil() or (OS.has_feature("web") and DisplayServer.is_touchscreen_available())


## Con pantalla tactil, o en el ordenador si se pide con --tactil.
static func hace_falta() -> bool:
	return pantalla_tactil() or "--tactil" in OS.get_cmdline_user_args()


## Un joystick: el circulo translucido, su circunferencia y la bola. 'alfa'
## multiplica lo opaco de todo. Tambien lo usa el editor de controles.
static func pintar_palanca(lienzo: CanvasItem, centro: Vector2, bola: Vector2, radio: float,
		color: Color, alfa: float) -> void:
	lienzo.draw_circle(centro, radio, Color(color, ALFA_CIRCULO * alfa))
	lienzo.draw_arc(centro, radio, 0.0, TAU, 64, Color(color, ALFA_BORDE * alfa), GROSOR_BORDE, true)
	lienzo.draw_circle(bola, RADIO_BOLA * radio / RADIO, Color(color, ALFA_BOLA * alfa))


## El boton de la ulti en reposo: un circulo con una estrella de cuatro puntas.
static func pintar_boton_especial(lienzo: CanvasItem, sitio: Vector2, radio: float, color: Color,
		alfa: float) -> void:
	lienzo.draw_circle(sitio, radio, Color(color, ALFA_CIRCULO * 1.4 * alfa))
	lienzo.draw_arc(sitio, radio, 0.0, TAU, 48, Color(color, ALFA_BORDE * alfa), GROSOR_BORDE, true)
	var puntos := PackedVector2Array()
	for i in 8:
		var largo := radio * (0.55 if i % 2 == 0 else 0.2)
		puntos.append(sitio + Vector2.UP.rotated(i * TAU / 8.0) * largo)
	lienzo.draw_colored_polygon(puntos, Color(color, alfa))


func _init(jugador: Jugador) -> void:
	_jugador = jugador
	name = "ControlesTactiles"
	# Encima del HUD (1) y debajo de la pantalla final (3) y la pausa (4).
	layer = 2


func _ready() -> void:
	_con_raton = not pantalla_tactil()
	# En el movil se empieza tocando; con teclado puede que no: hasta el primer toque.
	activos = en_el_movil() or _con_raton
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
	if toque != null or arrastre != null:
		_ultimo_toque = Time.get_ticks_msec()
		if not activos:
			activos = true
			_lienzo.queue_redraw()
	elif not _con_raton and activos and _es_teclado_o_raton(evento):
		_soltar_todo()
		activos = false
		return
	if not activos:
		return
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


## Una tecla, o el raton de verdad: no el que se inventa el sistema con cada dedo
## (DEVICE_ID_EMULATION), ni un clic que llega justo despues de un toque.
func _es_teclado_o_raton(evento: InputEvent) -> bool:
	if evento is InputEventKey:
		return evento.pressed
	if evento is InputEventMouseButton or evento is InputEventMouseMotion:
		return evento.device != InputEvent.DEVICE_ID_EMULATION \
			and Time.get_ticks_msec() - _ultimo_toque > RATON_TRAS_TOQUE_MS
	return false


func _tocar(dedo: int, sitio: Vector2, pulsado: bool) -> void:
	if not pulsado:
		_dedos.erase(dedo)
		_levantar(dedo)
		return
	_dedos[dedo] = true
	if sitio.distance_to(_sitio_pausa()) <= RADIO_PAUSA * 1.3:
		_pausar()
		return
	if _hay_modos() and sitio.distance_to(_sitio_modo()) <= RADIO_MODO * 1.3:
		_jugador.cambiar_modo_arma()
		return
	if sitio.distance_to(_reposo(AjustesMandos.ULTI)) <= _radio_boton_especial() * 1.2:
		if not _especial.activa() and _jugador.especial_disponible:
			_especial.empezar(dedo, sitio)
			especial = Vector2.ZERO
			Input.action_press("cargar_ataque_teclado")
		return
	# El de moverse o el de apuntar: el que este mas cerca de donde cae el dedo.
	# Con los de fabrica, es como antes: la mitad izquierda mueve y la derecha apunta.
	var cerca_izquierda := sitio.distance_to(_reposo(AjustesMandos.IZQUIERDO)) \
		<= sitio.distance_to(_reposo(AjustesMandos.DERECHO))
	var palanca := _izquierda if cerca_izquierda else _derecha
	if not palanca.activa():
		palanca.empezar(dedo, sitio)
	_actualizar()


func _arrastrar(dedo: int, sitio: Vector2) -> void:
	for palanca in [_izquierda, _derecha, _especial]:
		if palanca.dedo == dedo:
			palanca.mover(sitio)
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
	_dedos.clear()
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


## Donde descansa un mando, en la pantalla de ahora.
func _reposo(mando: StringName) -> Vector2:
	return AjustesMandos.sitio_en(mando, _lienzo.size)


func _radio_boton_especial() -> float:
	return RADIO_ESPECIAL * AjustesMandos.dato(AjustesMandos.ULTI, "tamano")


func _sitio_modo() -> Vector2:
	return _reposo(AjustesMandos.ULTI) + SITIO_MODO


func _hay_modos() -> bool:
	return _jugador.arma != null and _jugador.arma.tiene_modos()


func _sitio_pausa() -> Vector2:
	return Vector2(_lienzo.size.x * 0.5, SITIO_PAUSA_ALTO)


func _process(delta: float) -> void:
	# Opacos con un dedo en la pantalla; translucidos sin ninguno.
	var objetivo := 1.0 if not _dedos.is_empty() else ALFA_REPOSO
	_alfa = move_toward(_alfa, objetivo, delta * (1.0 - ALFA_REPOSO) / CAMBIO_ALFA)
	# El boton del especial cambia al gastarlo y al recuperarlo.
	_lienzo.queue_redraw()


func _pintar() -> void:
	if not _jugador.sigue_vivo() or not activos:
		return
	_pintar_pausa()
	_pintar_especial()
	if _hay_modos():
		_pintar_boton_modo()
	_pintar_mando(_izquierda, AZUL)
	_pintar_mando(_derecha, ROJO)


## Un joystick: donde esta el dedo si lo lleva, en su sitio si no. El oculto, solo
## con el dedo puesto.
func _pintar_mando(palanca: Palanca, color: Color) -> void:
	if palanca.activa():
		pintar_palanca(_lienzo, palanca.centro, palanca.bola(), palanca.radio(), color, _alfa)
	elif not AjustesMandos.dato(palanca.mando, "oculto"):
		var sitio := _reposo(palanca.mando)
		pintar_palanca(_lienzo, sitio, sitio, palanca.radio(), color, _alfa)


## El de la ulti, del color del mago mientras queda; gris si ya se ha usado en este
## piso. En reposo, un boton; mientras se arrastra, un joystick mas.
func _pintar_especial() -> void:
	var color := _jugador.mago.color if _jugador.mago != null else Color.WHITE
	if not _jugador.especial_disponible:
		color = Color(0.55, 0.55, 0.55)
	if _especial.activa():
		pintar_palanca(_lienzo, _especial.centro, _especial.bola(), _especial.radio(), color, _alfa)
	elif not AjustesMandos.dato(AjustesMandos.ULTI, "oculto"):
		var alfa := _alfa * (1.0 if _jugador.especial_disponible else 0.45)
		pintar_boton_especial(_lienzo, _reposo(AjustesMandos.ULTI), _radio_boton_especial(), color, alfa)


## Una flecha en circulo, del color del arma.
func _pintar_boton_modo() -> void:
	var sitio := _sitio_modo()
	var color := _jugador.arma.color
	_lienzo.draw_circle(sitio, RADIO_MODO, Color(color, ALFA_CIRCULO))
	_lienzo.draw_arc(sitio, RADIO_MODO, 0.0, TAU, 40, Color(color, ALFA_BORDE), 3.0, true)
	_lienzo.draw_arc(sitio, RADIO_MODO * 0.5, -0.4, 4.6, 24, color, 4.0, true)
	var punta := sitio + Vector2.from_angle(-0.4) * RADIO_MODO * 0.5
	_lienzo.draw_colored_polygon(PackedVector2Array([punta + Vector2(-8.0, -3.0), punta + Vector2(8.0, -5.0),
		punta + Vector2(1.0, 9.0)]), color)


func _pintar_pausa() -> void:
	var sitio := _sitio_pausa()
	_lienzo.draw_circle(sitio, RADIO_PAUSA, Color(0.0, 0.0, 0.0, 0.35))
	_lienzo.draw_arc(sitio, RADIO_PAUSA, 0.0, TAU, 40, Color(1.0, 1.0, 1.0, ALFA_BORDE),
		3.0, true)
	for lado in [-1.0, 1.0]:
		_lienzo.draw_rect(Rect2(sitio + Vector2(lado * 7.0 - 3.5, -10.0), Vector2(7.0, 20.0)),
			Color(1.0, 1.0, 1.0, 0.9))
