## Menu principal: lo primero que se ve al abrir el juego.
##
## LA PORTADA (2026-10-14, la trajo Matias): la ilustracion de los tres magos
## (assets/portada/portada.jpg) ocupa toda la pantalla, recortada para
## cubrirla sin deformarse (si la ventana es mas ancha o mas alta que el
## dibujo, se recorta por los lados o por arriba y abajo). Ya trae el titulo y
## los tres magos, asi que el titulo de piedra y los magos en pixel art de
## antes (assets/titulo/) ya no salen: dos titulos uno encima de otro no se
## leerian. Los botones van abajo, en fila, sobre una sombra que los separa del
## dibujo, para no tapar a los magos; el volumen, abajo a la izquierda.
##
## POR QUE ES LA ESCENA PRINCIPAL Y NO UNA CAPA DENTRO DE Principal.tscn:
## el menu no necesita nada del juego (ni gestor, ni pool, ni pisos) y el juego
## no necesita nada del menu. Teniendolos como escenas separadas, entrar a jugar
## libera el menu entero y salir del juego libera la partida entera, sin tener
## que acordarse de limpiar estados a mano.
extends Control

const ESCENA_JUEGO := "res://scenes/Principal.tscn"
## La musica de la portada. La del juego la pone cada piso (DatosPiso.musica).
const MUSICA := preload("res://assets/sonido/musica/portada.wav")

## Ancho de cada ficha de mago. Fijo para que los textos de ventaja partan
## linea por el mismo sitio y las fichas queden del mismo tamano aunque uno
## tenga la ventaja mas larga.
const ANCHO_FICHA: float = 300.0

@onready var _panel_controles: Control = $PanelControles
@onready var _panel_personajes: Control = $PanelPersonajes
@onready var _fichas: HBoxContainer = $PanelPersonajes/Centro/Caja/Fichas
@onready var _boton_jugar: Button = $Botones/BotonJugar
@onready var _teclas: Label = $PanelControles/Centro/Caja/Teclas/Botones
@onready var _reglas: Label = $PanelControles/Centro/Caja/Reglas

## El primer boton de mago, para dejarle el foco al abrir el panel.
var _primer_boton: Button = null
## El panel del cooperativo (crear sala, unirse, sala de espera).
var _cooperativo: SalaCooperativo
var _boton_cooperativo: Button
## Los dos botones de "Moverse con" del panel de controles, y las reglas tal
## cual estan en la escena (con las flechas para disparar).
var _boton_wasd: Button
var _boton_flechas: Button
var _reglas_base: String = ""


func _ready() -> void:
	$Botones/BotonJugar.pressed.connect(_mostrar_personajes.bind(true))
	$Botones/BotonControles.pressed.connect(_mostrar_controles.bind(true))
	$Botones/BotonSalir.pressed.connect(_al_salir)
	$PanelControles/Centro/Caja/BotonVolver.pressed.connect(_mostrar_controles.bind(false))
	$PanelPersonajes/Centro/Caja/BotonVolver.pressed.connect(_mostrar_personajes.bind(false))

	_montar_fichas()
	_montar_cooperativo()
	_montar_eleccion_teclas()
	_poner_version()
	Sonido.poner_musica(MUSICA)
	_panel_controles.hide()
	_panel_personajes.hide()
	_boton_jugar.grab_focus()
	# Se vuelve de una partida cooperativa que se ha cortado: se cuenta por
	# que, en el propio panel del cooperativo.
	if Red.mensaje_pendiente != "":
		_mostrar_cooperativo(true)
		_cooperativo.mostrar_mensaje(Red.mensaje_pendiente)
		Red.mensaje_pendiente = ""


## "Moverse con: W A S D / Flechas", debajo del titulo de los controles
## (Matias, 2026-10-18). Lo que se elige lo guarda y lo aplica el autoload
## Controles; aqui se ensena y se ponen los textos con las teclas elegidas.
func _montar_eleccion_teclas() -> void:
	var caja := $PanelControles/Centro/Caja
	# Un poco mas juntos: con la fila nueva, el panel no cabia en 648 de alto.
	caja.add_theme_constant_override("separation", 8)
	var fila := HBoxContainer.new()
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	fila.add_theme_constant_override("separation", 12)
	var etiqueta := Label.new()
	etiqueta.text = "Moverse con:"
	etiqueta.add_theme_font_size_override("font_size", 20)
	etiqueta.add_theme_color_override("font_color", Color(0.85, 0.82, 0.78))
	fila.add_child(etiqueta)
	var grupo := ButtonGroup.new()
	_boton_wasd = _boton_teclas("W A S D", false, grupo)
	_boton_flechas = _boton_teclas("Flechas", true, grupo)
	fila.add_child(_boton_wasd)
	fila.add_child(_boton_flechas)
	caja.add_child(fila)
	# Justo debajo del titulo: es lo primero que se mira al abrir el panel.
	caja.move_child(fila, 1)
	_reglas_base = _reglas.text
	Controles.cambiado.connect(_poner_teclas)
	_poner_teclas()


func _boton_teclas(texto: String, con_flechas: bool, grupo: ButtonGroup) -> Button:
	var boton := Button.new()
	boton.text = texto
	boton.toggle_mode = true
	boton.button_group = grupo
	boton.custom_minimum_size = Vector2(150, 40)
	boton.add_theme_font_size_override("font_size", 18)
	boton.pressed.connect(func() -> void: Controles.elegir(con_flechas))
	return boton


## Los textos del panel con las teclas que tocan. Las reglas de la escena
## hablan de disparar con "las flechas": con las flechas para moverse, se
## dispara con WASD.
func _poner_teclas() -> void:
	_boton_wasd.set_pressed_no_signal(not Controles.flechas_para_mover)
	_boton_flechas.set_pressed_no_signal(Controles.flechas_para_mover)
	_teclas.text = "%s\n%s o clic izq.\nclic der. o espacio\nEsc\nF11" % [
		Controles.teclas_mover(), Controles.teclas_disparar()]
	_reglas.text = _reglas_base
	if Controles.flechas_para_mover:
		_reglas.text = _reglas_base.replace("las flechas", "las teclas W A S D")


## El cooperativo sale desde "Jugar", debajo de los magos: es otra forma de
## jugar, no otra cosa del menu. En la fila de abajo no cabia otro boton sin
## pisar el volumen.
func _montar_cooperativo() -> void:
	_cooperativo = SalaCooperativo.new()
	_cooperativo.visible = false
	_cooperativo.cerrado.connect(_mostrar_cooperativo.bind(false))
	add_child(_cooperativo)

	var caja := $PanelPersonajes/Centro/Caja
	var volver: Button = $PanelPersonajes/Centro/Caja/BotonVolver
	var fila := HBoxContainer.new()
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	fila.add_theme_constant_override("separation", 16)
	caja.add_child(fila)
	caja.move_child(fila, volver.get_index())
	_boton_cooperativo = Button.new()
	_boton_cooperativo.text = "Cooperativo en red local"
	_boton_cooperativo.custom_minimum_size = Vector2(300, 46)
	_boton_cooperativo.add_theme_font_size_override("font_size", 20)
	_boton_cooperativo.pressed.connect(_mostrar_cooperativo.bind(true))
	volver.reparent(fila)
	fila.add_child(_boton_cooperativo)


func _mostrar_cooperativo(visible_ahora: bool) -> void:
	_cooperativo.visible = visible_ahora
	_panel_personajes.visible = not visible_ahora
	if not visible_ahora:
		_boton_cooperativo.grab_focus()


## La version del juego, pequena abajo a la derecha. Por codigo y no en la
## escena: es una etiqueta suelta, y asi la escena del menu no cambia.
func _poner_version() -> void:
	var etiqueta := Label.new()
	etiqueta.name = "Version"
	etiqueta.text = "versión " + GestorProgreso.version_juego()
	etiqueta.add_theme_font_size_override("font_size", 14)
	etiqueta.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.45))
	etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	etiqueta.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 14)
	etiqueta.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	etiqueta.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(etiqueta)


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
	elif _cooperativo.visible:
		# Dentro de una sala no: salir de ella tiene su boton.
		if not Red.en_sala():
			_mostrar_cooperativo(false)
		get_viewport().set_input_as_handled()
	elif _panel_personajes.visible:
		_mostrar_personajes(false)
		get_viewport().set_input_as_handled()


func _al_jugar() -> void:
	get_tree().change_scene_to_file(ESCENA_JUEGO)


## Sale por Sonido, que para la musica antes de cerrar (ver Sonido.salir).
func _al_salir() -> void:
	Sonido.salir()


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
