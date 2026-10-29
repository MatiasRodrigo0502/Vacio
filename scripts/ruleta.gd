## La ruleta del cofre de la sala secreta: una cinta con las ventajas que pasa
## por debajo de una marca, cada vez mas despacio, hasta pararse en la que
## toca. Lo que toca ya esta decidido al abrirse (Cofre): la cinta solo lo
## ensena con un poco de suspense.
##
## Como la ventana del tutorial (AvisoTutorial): para el juego mientras gira,
## salvo en cooperativo, y Escape no llega a la pausa. Montada por codigo.
class_name Ruleta
extends CanvasLayer

## Se ha cogido lo que ha tocado.
signal terminada(mejora: ObjetoMejora)

## Encima del HUD (2), debajo de la pausa (4), como la ventana del tutorial.
const CAPA: int = 3
const ANCHO_CASILLA: float = 130.0
const ALTO_CASILLA: float = 150.0
## Casillas que se ven a la vez. Impar: la del centro es la que cuenta.
const VISIBLES: int = 5
## Vueltas enteras a la lista antes de pararse.
const VUELTAS: int = 6
const DURACION: float = 3.4
const COLOR_ORO := Color(1.0, 0.8, 0.3)

var _opciones: Array[ObjetoMejora] = []
var _ganada: ObjetoMejora
var _cinta: Control
var _casillas: Array[Control] = []
var _resultado: RichTextLabel
var _boton: Button
var _parada: bool = false
var _he_parado_el_juego: bool = false
## La casilla que esta debajo de la marca, para que suene un clic al cambiar.
var _bajo_la_marca: int = -1
var _objetivo: int = 0


func _init(opciones: Array[ObjetoMejora], ganada: ObjetoMejora) -> void:
	name = "Ruleta"
	layer = CAPA
	process_mode = Node.PROCESS_MODE_ALWAYS
	_opciones = opciones
	_ganada = ganada


func _ready() -> void:
	_montar()
	if not Red.cooperativo() and not get_tree().paused:
		get_tree().paused = true
		_he_parado_el_juego = true
	_girar()


## La cinta lleva la lista repetida; se para en la ganada de la ultima vuelta,
## con el giro frenando como una ruleta de verdad (rapido al principio).
func _girar() -> void:
	var centro := ANCHO_CASILLA * VISIBLES * 0.5
	_objetivo = VUELTAS * _opciones.size() + maxi(_opciones.find(_ganada), 0)
	var desde := centro - ANCHO_CASILLA * 0.5
	var hasta := centro - (_objetivo + 0.5) * ANCHO_CASILLA
	var giro := create_tween()
	giro.tween_method(_mover, desde, hasta, DURACION) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	giro.finished.connect(_al_parar)


func _mover(x: float) -> void:
	_cinta.position.x = x
	var centro := ANCHO_CASILLA * VISIBLES * 0.5
	var bajo := int(floor((centro - x) / ANCHO_CASILLA))
	if bajo != _bajo_la_marca:
		_bajo_la_marca = bajo
		Sonido.tocar(&"clic")


func _al_parar() -> void:
	_parada = true
	Sonido.tocar(&"objeto")
	var casilla := _casillas[_objetivo]
	casilla.pivot_offset = casilla.size * 0.5
	var latido := create_tween()
	latido.tween_property(casilla, "scale", Vector2(1.12, 1.12), 0.15)
	latido.tween_property(casilla, "scale", Vector2.ONE, 0.2)
	_resultado.text = "[center]Te ha tocado [color=#%s]%s[/color]\n[color=#cfc6b8]%s[/color][/center]" % [
		_ganada.color.to_html(false), _ganada.nombre, _ganada.descripcion]
	_resultado.modulate.a = 1.0
	_boton.modulate.a = 1.0
	_boton.disabled = false
	_boton.grab_focus()


## Escape: mientras gira no hace nada (y no abre la pausa); parada, coge.
func _input(evento: InputEvent) -> void:
	if evento.is_action_pressed("pausar"):
		get_viewport().set_input_as_handled()
		if _parada:
			_coger()


func _coger() -> void:
	if not _parada:
		return
	_parada = false
	if _he_parado_el_juego:
		get_tree().paused = false
	get_viewport().gui_release_focus()
	terminada.emit(_ganada)
	queue_free()


func _montar() -> void:
	var fondo := ColorRect.new()
	fondo.color = Color(0.0, 0.0, 0.0, 0.5)
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)

	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centro)

	var panel := PanelContainer.new()
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.07, 0.055, 0.05, 0.96)
	estilo.border_color = COLOR_ORO
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(10)
	estilo.content_margin_left = 30.0
	estilo.content_margin_right = 30.0
	estilo.content_margin_top = 22.0
	estilo.content_margin_bottom = 22.0
	panel.add_theme_stylebox_override("panel", estilo)
	centro.add_child(panel)

	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 14)
	panel.add_child(caja)

	var titulo := Label.new()
	titulo.text = "Cofre secreto"
	titulo.add_theme_font_size_override("font_size", 30)
	titulo.add_theme_color_override("font_color", COLOR_ORO)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caja.add_child(titulo)

	# La ventana por la que pasa la cinta: recorta lo que se sale.
	var ventana := Control.new()
	ventana.custom_minimum_size = Vector2(ANCHO_CASILLA * VISIBLES, ALTO_CASILLA)
	ventana.clip_contents = true
	caja.add_child(ventana)

	_cinta = Control.new()
	ventana.add_child(_cinta)
	for vuelta in VUELTAS + 2:
		for mejora in _opciones:
			_casillas.append(_casilla(mejora, _casillas.size()))

	# La marca del centro, encima de la cinta.
	var marca := MarcaRuleta.new()
	marca.set_anchors_preset(Control.PRESET_FULL_RECT)
	marca.ancho_casilla = ANCHO_CASILLA
	marca.color = COLOR_ORO
	ventana.add_child(marca)

	_resultado = RichTextLabel.new()
	_resultado.bbcode_enabled = true
	_resultado.fit_content = true
	_resultado.scroll_active = false
	_resultado.custom_minimum_size = Vector2(ANCHO_CASILLA * VISIBLES, 0.0)
	_resultado.add_theme_font_size_override("normal_font_size", 20)
	_resultado.add_theme_constant_override("line_separation", 6)
	# Ocupa su sitio desde el principio (invisible): si no, al pararse la
	# ventana crece y la cinta da un salto.
	_resultado.text = "[center] \n [/center]"
	_resultado.modulate.a = 0.0
	caja.add_child(_resultado)

	_boton = Button.new()
	_boton.text = "Coger"
	_boton.custom_minimum_size = Vector2(220.0, 44.0)
	_boton.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_boton.add_theme_font_size_override("font_size", 18)
	_boton.pressed.connect(_coger)
	# Igual que el resultado: ocupa su sitio desde el principio, sin verse.
	_boton.modulate.a = 0.0
	_boton.disabled = true
	caja.add_child(_boton)


## Una casilla de la cinta: el icono de la ventaja, su nombre y un marco de
## su color.
func _casilla(mejora: ObjetoMejora, indice: int) -> Control:
	var casilla := Panel.new()
	casilla.position = Vector2(indice * ANCHO_CASILLA + 6.0, 6.0)
	casilla.size = Vector2(ANCHO_CASILLA - 12.0, ALTO_CASILLA - 12.0)
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.12, 0.1, 0.09)
	estilo.border_color = mejora.color
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(8)
	casilla.add_theme_stylebox_override("panel", estilo)
	_cinta.add_child(casilla)

	var icono := TextureRect.new()
	icono.texture = mejora.icono
	icono.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icono.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icono.position = Vector2(19.0, 14.0)
	icono.size = Vector2(casilla.size.x - 38.0, 70.0)
	casilla.add_child(icono)

	var nombre := Label.new()
	nombre.text = mejora.nombre
	nombre.add_theme_font_size_override("font_size", 15)
	nombre.add_theme_color_override("font_color", mejora.color.lerp(Color.WHITE, 0.35))
	nombre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nombre.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nombre.position = Vector2(4.0, 90.0)
	nombre.size = Vector2(casilla.size.x - 8.0, 44.0)
	casilla.add_child(nombre)
	return casilla


## La marca del centro de la ruleta: un marco de oro sobre la casilla que
## cuenta y un pico arriba y abajo. Un Control aparte para que quede por
## encima de la cinta.
class MarcaRuleta extends Control:
	var ancho_casilla: float = 130.0
	var color: Color = Color.WHITE

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var x := (size.x - ancho_casilla) * 0.5
		draw_rect(Rect2(x + 2.0, 2.0, ancho_casilla - 4.0, size.y - 4.0), color, false, 3.0)
		var medio := size.x * 0.5
		draw_colored_polygon(PackedVector2Array([Vector2(medio - 10.0, 0.0),
			Vector2(medio + 10.0, 0.0), Vector2(medio, 12.0)]), color)
		draw_colored_polygon(PackedVector2Array([Vector2(medio - 10.0, size.y),
			Vector2(medio + 10.0, size.y), Vector2(medio, size.y - 12.0)]), color)
		# Las de los lados, un poco a oscuras: la atencion, en el centro.
		draw_rect(Rect2(0.0, 0.0, x, size.y), Color(0.0, 0.0, 0.0, 0.35))
		draw_rect(Rect2(x + ancho_casilla, 0.0, x, size.y), Color(0.0, 0.0, 0.0, 0.35))
