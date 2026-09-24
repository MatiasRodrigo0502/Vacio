## Menu principal: lo primero que se ve al abrir el juego.
##
## POR QUE ES LA ESCENA PRINCIPAL Y NO UNA CAPA DENTRO DE Principal.tscn:
## el menu no necesita nada del juego (ni gestor, ni pool, ni pisos) y el juego
## no necesita nada del menu. Teniendolos como escenas separadas, entrar a jugar
## libera el menu entero y salir del juego libera la partida entera, sin tener
## que acordarse de limpiar estados a mano.
extends Control

const ESCENA_JUEGO := "res://scenes/Principal.tscn"

## Ancho de cada ficha de mago. Fijo para que los textos de ventaja partan
## linea por el mismo sitio y las fichas queden del mismo tamano aunque uno
## tenga la ventaja mas larga.
const ANCHO_FICHA: float = 300.0

@onready var _panel_controles: Control = $PanelControles
@onready var _panel_personajes: Control = $PanelPersonajes
@onready var _fichas: HBoxContainer = $PanelPersonajes/Centro/Caja/Fichas
@onready var _boton_jugar: Button = $Centro/Caja/BotonJugar

## El primer boton de mago, para dejarle el foco al abrir el panel.
var _primer_boton: Button = null


func _ready() -> void:
	$Centro/Caja/BotonJugar.pressed.connect(_mostrar_personajes.bind(true))
	$Centro/Caja/BotonControles.pressed.connect(_mostrar_controles.bind(true))
	$Centro/Caja/BotonSalir.pressed.connect(_al_salir)
	$PanelControles/Centro/Caja/BotonVolver.pressed.connect(_mostrar_controles.bind(false))
	$PanelPersonajes/Centro/Caja/BotonVolver.pressed.connect(_mostrar_personajes.bind(false))

	_montar_fichas()
	_panel_controles.hide()
	_panel_personajes.hide()
	_boton_jugar.grab_focus()


## Crea una ficha por cada mago que haya en disco.
##
## POR QUE SE MONTA POR CODIGO Y NO EN LA ESCENA:
## asi anadir un mago es dejar su .tres en resources/personajes/ y ya sale en el
## menu, con su retrato y su ventaja. Si las fichas estuvieran dibujadas en el
## .tscn, cada mago nuevo obligaria a abrir el editor y copiar nodos a mano.
func _montar_fichas() -> void:
	for hijo in _fichas.get_children():
		hijo.queue_free()
	_primer_boton = null

	for personaje in GestorProgreso.personajes:
		var ficha := VBoxContainer.new()
		ficha.custom_minimum_size = Vector2(ANCHO_FICHA, 0.0)
		ficha.add_theme_constant_override("separation", 10)

		var retrato := TextureRect.new()
		retrato.texture = personaje.retrato
		retrato.custom_minimum_size = Vector2(0.0, 170.0)
		retrato.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		retrato.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ficha.add_child(retrato)

		ficha.add_child(_etiqueta(personaje.nombre, 26, personaje.color))
		ficha.add_child(_etiqueta(personaje.ventaja, 17, Color(0.85, 0.82, 0.78)))
		ficha.add_child(_etiqueta(personaje.pega, 15, Color(0.62, 0.58, 0.55)))

		# Relleno elastico: las ventajas no miden lo mismo, y sin esto el boton
		# de cada ficha quedaria a una altura distinta.
		ficha.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var hueco := Control.new()
		hueco.size_flags_vertical = Control.SIZE_EXPAND_FILL
		ficha.add_child(hueco)

		var boton := Button.new()
		boton.text = "Jugar con %s" % personaje.nombre.to_lower()
		boton.custom_minimum_size = Vector2(0.0, 44.0)
		boton.add_theme_font_size_override("font_size", 18)
		boton.pressed.connect(_al_elegir.bind(personaje))
		ficha.add_child(boton)

		_fichas.add_child(ficha)
		if _primer_boton == null:
			_primer_boton = boton


func _etiqueta(texto: String, tamano: int, color: Color) -> Label:
	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.add_theme_font_size_override("font_size", tamano)
	etiqueta.add_theme_color_override("font_color", color)
	etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Las ventajas son frases, no titulos: sin esto se salen de la ficha.
	etiqueta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	etiqueta.custom_minimum_size = Vector2(ANCHO_FICHA, 0.0)
	return etiqueta


func _al_elegir(personaje: PersonajeJugable) -> void:
	GestorProgreso.elegir_personaje(personaje)
	_al_jugar()


func _unhandled_input(evento: InputEvent) -> void:
	# Escape cierra los controles si estan abiertos. Es lo que espera cualquiera
	# que abra un panel, y evita tener que apuntar al boton con el raton.
	if not evento.is_action_pressed("ui_cancel"):
		return
	if _panel_controles.visible:
		_mostrar_controles(false)
		get_viewport().set_input_as_handled()
	elif _panel_personajes.visible:
		_mostrar_personajes(false)
		get_viewport().set_input_as_handled()


func _al_jugar() -> void:
	get_tree().change_scene_to_file(ESCENA_JUEGO)


func _al_salir() -> void:
	get_tree().quit()


func _mostrar_personajes(visible_ahora: bool) -> void:
	_panel_personajes.visible = visible_ahora
	if visible_ahora and _primer_boton != null:
		_primer_boton.grab_focus()
	elif not visible_ahora:
		_boton_jugar.grab_focus()


func _mostrar_controles(visible_ahora: bool) -> void:
	_panel_controles.visible = visible_ahora
	# El foco se mueve al panel y vuelve al menu, para que el teclado siga
	# sirviendo para moverse sin tocar el raton.
	if visible_ahora:
		$PanelControles/Centro/Caja/BotonVolver.grab_focus()
	else:
		_boton_jugar.grab_focus()
