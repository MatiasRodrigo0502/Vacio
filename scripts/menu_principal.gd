## Menu principal: lo primero que se ve al abrir el juego.
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

## Los magos de la portada: a x2, como pixel art, y lo que suben y bajan
## flotando. Cada uno a su ritmo, para que no parezcan uno repetido.
const ESCALA_MAGO: float = 2.0
const FLOTE: float = 4.0
const RITMO_FLOTE: float = 1.6

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
	_montar_magos()
	_latir_titulo()
	_poner_brasas()
	_poner_version()
	Sonido.poner_musica(MUSICA)
	_panel_controles.hide()
	_panel_personajes.hide()
	_boton_jugar.grab_focus()


## Los magos que se pueden elegir, en la portada, debajo del titulo.
##
## POR QUE LEIDOS DE GestorProgreso Y NO PUESTOS EN LA ESCENA: igual que las
## fichas, un mago nuevo sale aqui solo con dejar su .tres. Miran hacia el
## centro, los de la izquierda a la derecha y al reves: asi se ven en grupo y
## no tres sueltos mirando a la camara.
func _montar_magos() -> void:
	var fila: HBoxContainer = $Centro/Caja/Magos
	var magos := GestorProgreso.personajes
	for i in magos.size():
		var personaje: PersonajeJugable = magos[i]
		if personaje.animaciones == null:
			continue
		var hueco := Control.new()
		hueco.custom_minimum_size = Vector2(64.0, 72.0) * ESCALA_MAGO
		hueco.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sprite := AnimatedSprite2D.new()
		sprite.sprite_frames = personaje.animaciones
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.scale = Vector2(ESCALA_MAGO, ESCALA_MAGO)
		sprite.position = hueco.custom_minimum_size * 0.5
		var lado := float(i) - (magos.size() - 1) * 0.5
		var animacion := &"quieto_abajo"
		if lado < 0.0:
			animacion = &"quieto_abajo_derecha"
		elif lado > 0.0:
			animacion = &"quieto_abajo_izquierda"
		sprite.play(animacion)
		hueco.add_child(sprite)
		fila.add_child(hueco)
		_flotar(sprite, i * 0.45)


## Sube y baja un poco, sin parar. Empieza tras 'retraso' segundos, para que
## cada mago vaya a destiempo de los demas.
func _flotar(sprite: Node2D, retraso: float) -> void:
	var base := sprite.position.y
	await get_tree().create_timer(retraso).timeout
	if not is_instance_valid(sprite):
		return
	var vaiven := sprite.create_tween().set_loops()
	vaiven.tween_property(sprite, "position:y", base - FLOTE, RITMO_FLOTE) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	vaiven.tween_property(sprite, "position:y", base, RITMO_FLOTE) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## El resplandor de la lava del titulo late despacio. Va en otra imagen que
## las letras (herramientas/generar_titulo.py), asi late sin que las letras
## cambien.
func _latir_titulo() -> void:
	var brillo: CanvasItem = $Centro/Caja/Titulo/Brillo
	var latido := create_tween().set_loops()
	latido.tween_property(brillo, "modulate:a", 0.55, 1.4).set_trans(Tween.TRANS_SINE)
	latido.tween_property(brillo, "modulate:a", 1.0, 1.4).set_trans(Tween.TRANS_SINE)


## Brasas que suben despacio desde abajo, por detras de todo: el nucleo esta
## abajo y arde. Cuadradas, sin textura, como pixeles sueltos.
func _poner_brasas() -> void:
	var brasas := CPUParticles2D.new()
	brasas.name = "Brasas"
	brasas.amount = 36
	brasas.lifetime = 7.0
	brasas.preprocess = 7.0
	brasas.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	brasas.direction = Vector2.UP
	brasas.spread = 12.0
	brasas.gravity = Vector2.ZERO
	brasas.initial_velocity_min = 40.0
	brasas.initial_velocity_max = 90.0
	brasas.scale_amount_min = 2.0
	brasas.scale_amount_max = 4.0
	var rampa := Gradient.new()
	rampa.set_color(0, Color(1.0, 0.75, 0.35, 0.9))
	rampa.set_color(1, Color(1.0, 0.3, 0.1, 0.0))
	brasas.color_ramp = rampa
	add_child(brasas)
	# Justo encima del fondo y debajo de los botones.
	move_child(brasas, $Fondo.get_index() + 1)
	var colocar := func() -> void:
		brasas.position = Vector2(size.x * 0.5, size.y + 8.0)
		brasas.emission_rect_extents = Vector2(size.x * 0.5, 4.0)
	resized.connect(colocar)
	colocar.call()


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
