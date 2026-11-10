## La tabla de teclas del panel de controles (Matias, 2026-11-10): una fila por
## accion, con lo que hace, su tecla principal y su tecla secundaria. Se cambia una
## pulsandola y luego la tecla o el boton del raton que se quiera (Esc deja la que
## habia); la × de al lado la quita. Lo guarda y lo aplica el autoload Controles.
##
## Montada por codigo, como el gacha: son catorce filas iguales.
class_name TablaControles
extends VBoxContainer

const ANCHO_FUNCION: float = 330.0
const ANCHO_TECLA: float = 190.0
const ALTO_FILA: float = 32.0
## Lo que se ve de la lista sin desplazarse: con las catorce, el panel no cabia
## en 648 de alto.
const ALTO_LISTA: float = 300.0
const COLOR_TEXTO := Color(0.85, 0.82, 0.78)
const COLOR_TITULO := Color(1.0, 0.74, 0.36)
const COLOR_VACIA := Color(0.55, 0.52, 0.5)

## Accion -> [boton de la principal, boton de la secundaria].
var _botones: Dictionary = {}
## Accion -> [la x de la principal, la de la secundaria].
var _quitar: Dictionary = {}
## [accion, hueco] mientras se espera la tecla nueva; vacio si no.
var _esperando: Array = []


func _ready() -> void:
	add_theme_constant_override("separation", 4)
	var cabecera := HBoxContainer.new()
	cabecera.add_child(_celda("Función", ANCHO_FUNCION, COLOR_TITULO))
	cabecera.add_child(_celda("Tecla principal", ANCHO_TECLA + 38.0, COLOR_TITULO))
	cabecera.add_child(_celda("Tecla secundaria", ANCHO_TECLA + 38.0, COLOR_TITULO))
	add_child(cabecera)
	var desplazar := ScrollContainer.new()
	desplazar.custom_minimum_size = Vector2(0.0, ALTO_LISTA)
	desplazar.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(desplazar)
	var filas := VBoxContainer.new()
	filas.add_theme_constant_override("separation", 2)
	desplazar.add_child(filas)
	for accion in Controles.ACCIONES:
		var fila := HBoxContainer.new()
		fila.add_child(_celda(accion[1], ANCHO_FUNCION, COLOR_TEXTO))
		var botones: Array = []
		var cruces: Array = []
		for hueco in Controles.HUECOS:
			var tecla := Button.new()
			tecla.custom_minimum_size = Vector2(ANCHO_TECLA, ALTO_FILA)
			tecla.add_theme_font_size_override("font_size", 16)
			tecla.tooltip_text = "Púlsalo y luego la tecla o el botón del ratón que quieras (Esc, para dejarla)"
			tecla.pressed.connect(_esperar_tecla.bind(accion[0], hueco))
			var quitar := Button.new()
			quitar.text = "×"
			quitar.custom_minimum_size = Vector2(ALTO_FILA, ALTO_FILA)
			quitar.add_theme_font_size_override("font_size", 16)
			quitar.tooltip_text = "Quitar esta tecla"
			quitar.pressed.connect(_quitar_tecla.bind(accion[0], hueco))
			fila.add_child(tecla)
			fila.add_child(quitar)
			if hueco < Controles.HUECOS - 1:
				var hueco_vacio := Control.new()
				hueco_vacio.custom_minimum_size = Vector2(6.0, 0.0)
				fila.add_child(hueco_vacio)
			botones.append(tecla)
			cruces.append(quitar)
		_botones[accion[0]] = botones
		_quitar[accion[0]] = cruces
		filas.add_child(fila)
	var abajo := HBoxContainer.new()
	abajo.add_theme_constant_override("separation", 16)
	var nota := _celda("Pulsa una tecla para cambiarla; la × la quita.  F11 pantalla completa  ·  F3 estadísticas",
		ANCHO_FUNCION + (ANCHO_TECLA + 38.0) * 2.0 - 180.0, COLOR_VACIA)
	nota.add_theme_font_size_override("font_size", 15)
	abajo.add_child(nota)
	var restablecer := Button.new()
	restablecer.text = "Restablecer"
	restablecer.custom_minimum_size = Vector2(160.0, ALTO_FILA)
	restablecer.add_theme_font_size_override("font_size", 16)
	restablecer.pressed.connect(func() -> void:
		_esperando.clear()
		Controles.restablecer())
	abajo.add_child(restablecer)
	add_child(abajo)
	Controles.cambiado.connect(_poner_textos)
	_poner_textos()


func _celda(texto: String, ancho: float, color: Color) -> Label:
	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.custom_minimum_size = Vector2(ancho, 0.0)
	etiqueta.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	etiqueta.add_theme_font_size_override("font_size", 17)
	etiqueta.add_theme_color_override("font_color", color)
	return etiqueta


func _poner_textos() -> void:
	for accion in _botones:
		var teclas: Array = Controles.teclas_de(accion)
		for hueco in Controles.HUECOS:
			var boton: Button = _botones[accion][hueco]
			var hay: bool = teclas[hueco] != null
			boton.text = Controles.nombre_de(teclas[hueco]) if hay else "—"
			boton.add_theme_color_override("font_color", Color.WHITE if hay else COLOR_VACIA)
			_quitar[accion][hueco].disabled = not hay
	if not _esperando.is_empty():
		_botones[_esperando[0]][_esperando[1]].text = "Pulsa una tecla…"


func _esperar_tecla(accion: String, hueco: int) -> void:
	_esperando = [accion, hueco]
	_poner_textos()


func _quitar_tecla(accion: String, hueco: int) -> void:
	_esperando.clear()
	Controles.poner_tecla(accion, hueco, null)


## La tecla o el boton que llegue mientras se espera. En _input, antes que nada: si
## no, Esc cerraria el panel y el clic pulsaria lo que haya debajo.
func _input(evento: InputEvent) -> void:
	if _esperando.is_empty() or not is_visible_in_tree():
		return
	var nueva: InputEvent = null
	if evento is InputEventKey and evento.pressed and not evento.echo:
		if evento.physical_keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_esperando.clear()
			_poner_textos()
			return
		nueva = InputEventKey.new()
		nueva.physical_keycode = evento.physical_keycode if evento.physical_keycode != KEY_NONE else evento.keycode
	elif evento is InputEventMouseButton and evento.pressed:
		nueva = InputEventMouseButton.new()
		nueva.button_index = evento.button_index
	if nueva == null:
		return
	get_viewport().set_input_as_handled()
	var cual := _esperando.duplicate()
	_esperando.clear()
	Controles.poner_tecla(cual[0], cual[1], nueva)
