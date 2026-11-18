## El editor de los joysticks de la pantalla tactil (Matias, 2026-11-18): se abre
## desde el panel de controles con «Editar controles» (en Android y en el
## navegador). Sobre una imagen de la primera sala del juego salen los tres
## joysticks donde estan en la partida (AjustesMandos):
##
## - arrastrando uno, se mueve a cualquier sitio de la pantalla;
## - al pulsarlo se elige: sale su tirador (el circulo pequeno de su borde, que se
##   arrastra para hacerlo mas grande o mas pequeno; tambien se puede pellizcar con
##   dos dedos, o con la rueda del raton) y, arriba en el centro, sus dos
##   interruptores, Oculto y Estatico (que es cada uno: AjustesMandos);
## - Restablecer los deja como vienen.
##
## Cada cambio se guarda al momento (AjustesMandos.guardar): no hay que darle a nada.
##
## POR QUE CON EL RATON Y NO CON LOS DEDOS: en el movil y en el navegador, el primer
## dedo llega tambien como raton (lo hace el sistema), y asi se prueba igual en el
## ordenador. Los dedos de verdad solo se miran para el pellizco, que necesita dos.
##
## Montado por codigo, como la sala del cooperativo.
class_name EditorMandos
extends Control

## Se ha pulsado Listo.
signal cerrado

const FONDO := preload("res://assets/editor_mandos/primera_sala.jpg")
## Lo que se oscurece la sala de fondo: que se vean bien los joysticks y los textos.
const VELO := Color(0.0, 0.0, 0.0, 0.35)
## El tirador de cambiar el tamano: su radio, y donde va (en el borde, abajo a la
## derecha del circulo).
const RADIO_TIRADOR: float = 16.0
const ANGULO_TIRADOR: float = PI * 0.25
const COLOR_ELEGIDO := Color(1.0, 0.92, 0.55)
## Lo que crece o encoge cada paso de la rueda del raton.
const PASO_RUEDA: float = 0.05
## Un oculto se ve, pero a medias: asi se sabe donde esta y que no se vera.
const ALFA_OCULTO: float = 0.45

var _elegido: StringName = &""
## Que se esta arrastrando: "" (nada), "mover" o "tamano".
var _arrastre: String = ""
## Del dedo o el raton al centro del elegido, al empezar a moverlo: asi no salta.
var _agarre: Vector2 = Vector2.ZERO
## Los dedos de verdad en la pantalla (indice -> sitio), para el pellizco.
var _dedos: Dictionary = {}
var _pellizco_inicio: float = 0.0
var _tamano_inicio: float = 1.0

var _fondo: TextureRect
var _imagen_tumbada: ImageTexture
var _titulo: Label
var _interruptores: HBoxContainer
var _oculto: CheckButton
var _estatico: CheckButton


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_fondo = TextureRect.new()
	_fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fondo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_fondo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fondo)
	var velo := ColorRect.new()
	velo.color = VELO
	velo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(velo)
	# Lo de dibujar los joysticks va en un hijo encima del fondo: lo que pinta el
	# propio Control quedaria debajo de sus hijos.
	var lienzo := Control.new()
	lienzo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lienzo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lienzo.draw.connect(_pintar.bind(lienzo))
	add_child(lienzo)
	_montar_arriba()
	_montar_abajo()
	resized.connect(_poner_fondo)
	_poner_fondo()
	_elegir(&"")


## Arriba en el centro: lo que hay elegido y sus dos interruptores. Cada
## interruptor con su palabra a la derecha, y lo que se centra es el conjunto
## (Matias: «centra el conjunto (switch + palabra), no solo el switch»).
func _montar_arriba() -> void:
	var caja := VBoxContainer.new()
	caja.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	caja.grow_horizontal = Control.GROW_DIRECTION_BOTH
	caja.offset_top = 14.0
	caja.alignment = BoxContainer.ALIGNMENT_CENTER
	caja.add_theme_constant_override("separation", 6)
	add_child(caja)
	_titulo = Label.new()
	_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_titulo.add_theme_font_size_override("font_size", 20)
	_titulo.add_theme_color_override("font_outline_color", Color.BLACK)
	_titulo.add_theme_constant_override("outline_size", 6)
	caja.add_child(_titulo)
	_interruptores = HBoxContainer.new()
	_interruptores.alignment = BoxContainer.ALIGNMENT_CENTER
	_interruptores.add_theme_constant_override("separation", 34)
	caja.add_child(_interruptores)
	_oculto = _interruptor("Oculto", "oculto")
	_estatico = _interruptor("Estático", "estatico")


## Un interruptor sin texto y su palabra al lado, a la derecha. CheckButton pinta la
## palabra a la izquierda del interruptor, por eso va aparte.
func _interruptor(palabra: String, clave: String) -> CheckButton:
	var grupo := HBoxContainer.new()
	grupo.add_theme_constant_override("separation", 6)
	var boton := CheckButton.new()
	boton.focus_mode = Control.FOCUS_NONE
	boton.toggled.connect(func(activo: bool) -> void:
		if _elegido != &"":
			AjustesMandos.poner(_elegido, clave, activo)
			AjustesMandos.guardar()
			queue_redraw_lienzo())
	grupo.add_child(boton)
	var etiqueta := Label.new()
	etiqueta.text = palabra
	etiqueta.add_theme_font_size_override("font_size", 20)
	etiqueta.add_theme_color_override("font_outline_color", Color.BLACK)
	etiqueta.add_theme_constant_override("outline_size", 6)
	# Tocar la palabra tambien cambia el interruptor.
	etiqueta.mouse_filter = Control.MOUSE_FILTER_STOP
	etiqueta.gui_input.connect(func(evento: InputEvent) -> void:
		if evento is InputEventMouseButton and evento.pressed and evento.button_index == MOUSE_BUTTON_LEFT:
			boton.button_pressed = not boton.button_pressed)
	grupo.add_child(etiqueta)
	_interruptores.add_child(grupo)
	return boton


## Abajo en el centro: restablecer y salir.
func _montar_abajo() -> void:
	var fila := HBoxContainer.new()
	fila.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	fila.grow_horizontal = Control.GROW_DIRECTION_BOTH
	fila.grow_vertical = Control.GROW_DIRECTION_BEGIN
	fila.offset_bottom = -16.0
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	fila.add_theme_constant_override("separation", 16)
	add_child(fila)
	var restablecer := _boton("Restablecer")
	restablecer.pressed.connect(func() -> void:
		AjustesMandos.restablecer()
		_elegir(_elegido))
	fila.add_child(restablecer)
	var listo := _boton("Listo")
	listo.pressed.connect(func() -> void: cerrado.emit())
	fila.add_child(listo)


func _boton(texto: String) -> Button:
	var boton := Button.new()
	boton.text = texto
	boton.custom_minimum_size = Vector2(180.0, 44.0)
	boton.add_theme_font_size_override("font_size", 18)
	boton.focus_mode = Control.FOCUS_NONE
	return boton


## La sala de fondo, tumbada si la pantalla esta en vertical: asi se ve como en la
## partida, donde el mundo gira con ella (Vista).
func _poner_fondo() -> void:
	if size.y > size.x:
		if _imagen_tumbada == null:
			var imagen := FONDO.get_image()
			imagen.rotate_90(CLOCKWISE)
			_imagen_tumbada = ImageTexture.create_from_image(imagen)
		_fondo.texture = _imagen_tumbada
	else:
		_fondo.texture = FONDO
	queue_redraw_lienzo()


func queue_redraw_lienzo() -> void:
	for hijo in get_children():
		if hijo is Control and hijo.draw.is_connected(_pintar):
			hijo.queue_redraw()


func _elegir(mando: StringName) -> void:
	_elegido = mando
	_interruptores.visible = mando != &""
	if mando == &"":
		_titulo.text = "Arrastra un joystick para moverlo; tócalo para cambiarlo"
	else:
		_titulo.text = AjustesMandos.NOMBRES[mando]
		_oculto.set_pressed_no_signal(AjustesMandos.dato(mando, "oculto"))
		_estatico.set_pressed_no_signal(AjustesMandos.dato(mando, "estatico"))
	queue_redraw_lienzo()


# --- Lo que mide y donde esta cada uno ------------------------------------------

func _centro(mando: StringName) -> Vector2:
	return AjustesMandos.sitio_en(mando, size)


## El radio con el que se ve: el circulo grande, y en la ulti su boton.
func _radio(mando: StringName) -> float:
	var base: float = ControlesTactiles.RADIO_ESPECIAL if mando == AjustesMandos.ULTI else ControlesTactiles.RADIO
	return base * AjustesMandos.dato(mando, "tamano")


func _sitio_tirador(mando: StringName) -> Vector2:
	return _centro(mando) + Vector2.from_angle(ANGULO_TIRADOR) * _radio(mando)


## El que hay bajo ese punto, o &"". Si se pisan, el de encima: la ulti.
func _mando_en(punto: Vector2) -> StringName:
	for mando in [AjustesMandos.ULTI, AjustesMandos.DERECHO, AjustesMandos.IZQUIERDO]:
		if punto.distance_to(_centro(mando)) <= _radio(mando):
			return mando
	return &""


# --- Raton (y el primer dedo, que llega como raton) ---------------------------

func _gui_input(evento: InputEvent) -> void:
	var boton := evento as InputEventMouseButton
	var movido := evento as InputEventMouseMotion
	if boton != null and boton.button_index == MOUSE_BUTTON_LEFT:
		if boton.pressed:
			_empezar_arrastre(boton.position)
		elif _arrastre != "":
			_arrastre = ""
			AjustesMandos.guardar()
		accept_event()
	elif boton != null and boton.pressed and _elegido != &"" \
			and boton.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		var paso := PASO_RUEDA if boton.button_index == MOUSE_BUTTON_WHEEL_UP else -PASO_RUEDA
		_cambiar_tamano(AjustesMandos.dato(_elegido, "tamano") + paso)
		AjustesMandos.guardar()
		accept_event()
	elif movido != null and _arrastre != "" and _dedos.size() < 2:
		if _arrastre == "mover":
			AjustesMandos.poner(_elegido, "sitio", (movido.position + _agarre) / size)
		else:
			var base: float = _radio(_elegido) / AjustesMandos.dato(_elegido, "tamano")
			_cambiar_tamano(movido.position.distance_to(_centro(_elegido)) / base)
		queue_redraw_lienzo()
		accept_event()


func _empezar_arrastre(punto: Vector2) -> void:
	# Primero el tirador del elegido: puede caer fuera de su circulo.
	if _elegido != &"" and punto.distance_to(_sitio_tirador(_elegido)) <= RADIO_TIRADOR * 1.6:
		_arrastre = "tamano"
		return
	var mando := _mando_en(punto)
	_elegir(mando)
	if mando != &"":
		_arrastre = "mover"
		_agarre = _centro(mando) - punto


func _cambiar_tamano(tamano: float) -> void:
	AjustesMandos.poner(_elegido, "tamano", tamano)
	queue_redraw_lienzo()


# --- Dos dedos: pellizco -------------------------------------------------------

func _input(evento: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	var toque := evento as InputEventScreenTouch
	var arrastre := evento as InputEventScreenDrag
	if toque != null:
		if toque.pressed:
			_dedos[toque.index] = toque.position
		else:
			_dedos.erase(toque.index)
		if _dedos.size() == 2 and _elegido != &"":
			_pellizco_inicio = _distancia_dedos()
			_tamano_inicio = AjustesMandos.dato(_elegido, "tamano")
		elif _dedos.size() < 2 and _pellizco_inicio > 0.0:
			_pellizco_inicio = 0.0
			AjustesMandos.guardar()
	elif arrastre != null and _dedos.has(arrastre.index):
		_dedos[arrastre.index] = arrastre.position
		if _dedos.size() == 2 and _elegido != &"" and _pellizco_inicio > 0.0:
			_cambiar_tamano(_tamano_inicio * _distancia_dedos() / _pellizco_inicio)
	elif evento is InputEventMagnifyGesture and _elegido != &"":
		_cambiar_tamano(AjustesMandos.dato(_elegido, "tamano") * evento.factor)
		AjustesMandos.guardar()


func _distancia_dedos() -> float:
	var sitios := _dedos.values()
	return maxf((sitios[0] as Vector2).distance_to(sitios[1]), 1.0)


# --- Dibujo ----------------------------------------------------------------------

func _pintar(lienzo: Control) -> void:
	var colores := {AjustesMandos.IZQUIERDO: ControlesTactiles.AZUL, AjustesMandos.DERECHO: ControlesTactiles.ROJO,
		AjustesMandos.ULTI: PaletaPortada.BORDE_PULSADO}
	for mando in AjustesMandos.MANDOS:
		var centro := _centro(mando)
		var alfa := ALFA_OCULTO if AjustesMandos.dato(mando, "oculto") else 1.0
		if mando == AjustesMandos.ULTI:
			ControlesTactiles.pintar_boton_especial(lienzo, centro, _radio(mando), colores[mando], alfa)
		else:
			ControlesTactiles.pintar_palanca(lienzo, centro, centro, _radio(mando), colores[mando], alfa)
		if mando == _elegido:
			lienzo.draw_arc(centro, _radio(mando) + 6.0, 0.0, TAU, 64, COLOR_ELEGIDO, 3.0, true)
			var tirador := _sitio_tirador(mando)
			lienzo.draw_circle(tirador, RADIO_TIRADOR, COLOR_ELEGIDO)
			lienzo.draw_arc(tirador, RADIO_TIRADOR, 0.0, TAU, 24, Color.BLACK, 2.0, true)
			# Dos flechitas hacia fuera y hacia dentro: se estira.
			var eje := Vector2.from_angle(ANGULO_TIRADOR)
			lienzo.draw_line(tirador - eje * 8.0, tirador + eje * 8.0, Color.BLACK, 2.5, true)
