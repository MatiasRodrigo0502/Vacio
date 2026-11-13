## Menu principal: lo primero que se ve al abrir el juego.
##
## LA PORTADA (2026-11-12, la trajo Matias: «cambia el menu principal por este
## mp4»): un video de 8 s en bucle, el mago oscuro en un bosque morado con el
## titulo arriba (assets/portada/portada.ogv, de herramientas/convertir_portada.py:
## Godot no reproduce MP4, solo Ogg Theora). Ocupa toda la pantalla, recortado para
## cubrirla sin deformarse: un VideoStreamPlayer no sabe recortar, y lo hace el
## AspectRatioContainer que lo lleva dentro (EncajeVideo, en modo cubrir). Debajo
## va su primera imagen quieta (Portada), encajada igual: es lo que se ve hasta
## que el video da la primera, y si no cargara. Ya trae el titulo, asi que los
## botones van abajo, en fila, sobre una sombra que los separa del dibujo; el
## volumen, abajo a la izquierda. Hasta entonces la portada era la ilustracion de
## los tres magos (portada.jpg, del 2026-10-14, que sigue ahi sin usar).
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
## Lo que se deja entre el volumen y el primer boton (_apartar_botones_del_volumen).
const HUECO_VOLUMEN: float = 24.0

@onready var _panel_controles: Control = $PanelControles
@onready var _panel_personajes: Control = $PanelPersonajes
@onready var _fichas: HBoxContainer = $PanelPersonajes/Centro/Caja/Fichas
@onready var _boton_jugar: Button = $Botones/BotonJugar
@onready var _reglas: Label = $PanelControles/Centro/Caja/Reglas

## El primer boton de mago, para dejarle el foco al abrir el panel.
var _primer_boton: Button = null
## El panel del cooperativo (crear sala, unirse, sala de espera).
var _cooperativo: SalaCooperativo
var _boton_cooperativo: Button
## El gacha (PanelGacha), y el boton que lo abre.
var _gacha: PanelGacha
var _boton_gacha: Button
## Los dos botones de "Moverse con" del panel de controles, y las reglas tal
## cual estan en la escena (con las flechas para disparar).
var _boton_wasd: Button
var _boton_flechas: Button
var _reglas_base: String = ""
## La tabla de teclas y la fila de encima, que solo salen en la pestana «Teclas».
var _tabla: TablaControles
var _fila_teclas: HBoxContainer


func _ready() -> void:
	$Botones/BotonJugar.pressed.connect(_mostrar_personajes.bind(true))
	$Botones/BotonControles.pressed.connect(_mostrar_controles.bind(true))
	$Botones/BotonSalir.pressed.connect(_al_salir)
	# En el navegador se sale cerrando la pestana: cerrar el juego dejaria la
	# pagina en negro.
	$Botones/BotonSalir.visible = not OS.has_feature("web")
	$PanelControles/Centro/Caja/BotonVolver.pressed.connect(_mostrar_controles.bind(false))
	$PanelPersonajes/Centro/Caja/BotonVolver.pressed.connect(_mostrar_personajes.bind(false))

	_montar_fichas()
	_montar_cooperativo()
	_montar_gacha()
	_montar_eleccion_teclas()
	_poner_version()
	Sonido.poner_musica(MUSICA)
	# Despues de montarlo todo y con el tamano ya puesto: hasta el primer fotograma
	# los botones no saben cuanto miden.
	_apartar_botones_del_volumen.call_deferred()
	get_viewport().size_changed.connect(_apartar_botones_del_volumen)
	_panel_controles.hide()
	_panel_personajes.hide()
	_boton_jugar.grab_focus()
	# Se vuelve de una partida cooperativa que se ha cortado: se cuenta por
	# que, en el propio panel del cooperativo.
	if Red.mensaje_pendiente != "":
		_mostrar_cooperativo(true)
		_cooperativo.mostrar_mensaje(Red.mensaje_pendiente)
		Red.mensaje_pendiente = ""


## El boton del gacha, entre Jugar y Controles, y las monedas y los diamantes
## arriba a la derecha de la portada. Por codigo y copiando el boton de al lado,
## para que quede igual que los de la escena.
func _montar_gacha() -> void:
	_boton_gacha = $Botones/BotonControles.duplicate()
	_boton_gacha.name = "BotonGacha"
	_boton_gacha.text = "Gacha"
	# Mas estrecho que Controles: con cuatro botones, Jugar tocaba el volumen.
	_boton_gacha.custom_minimum_size.x = 130.0
	$Botones.add_child(_boton_gacha)
	$Botones.move_child(_boton_gacha, 1)
	_boton_gacha.pressed.connect(_mostrar_gacha.bind(true))
	var monedero := Monedero.new()
	monedero.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	monedero.position = Vector2(size.x - Monedero.ANCHO - 16.0, 26.0)
	monedero.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	monedero.offset_left = -Monedero.ANCHO - 16.0
	monedero.offset_right = -16.0
	monedero.offset_top = 26.0
	add_child(monedero)
	_gacha = PanelGacha.new()
	_gacha.cerrado.connect(_mostrar_gacha.bind(false))
	add_child(_gacha)


func _mostrar_gacha(visible_ahora: bool) -> void:
	if visible_ahora:
		_gacha.abrir()
		return
	_gacha.visible = false
	# Las fichas de los magos enseñan la skin que se lleva puesta.
	_montar_fichas()
	_boton_gacha.grab_focus()


## El panel de controles, en dos pestanas: «Teclas», con la tabla de cada accion y
## su tecla principal y secundaria (TablaControles, Matias, 2026-11-10), y «Cómo se
## juega», con las reglas que antes iban debajo de la lista de teclas: con la
## tabla no cabian las dos cosas en 648 de alto. Encima de la tabla, el atajo
## "Moverse con: W A S D / Flechas" (Matias, 2026-10-18), el disparo automatico y
## las estadisticas. Lo que se elige lo guarda y lo aplica el autoload Controles.
func _montar_eleccion_teclas() -> void:
	var caja := $PanelControles/Centro/Caja
	# Un poco mas juntos: con la fila nueva, el panel no cabia en 648 de alto.
	caja.add_theme_constant_override("separation", 8)
	# La lista de teclas de texto de la escena la sustituye la tabla.
	$PanelControles/Centro/Caja/Teclas.visible = false
	var pestanas := HBoxContainer.new()
	pestanas.alignment = BoxContainer.ALIGNMENT_CENTER
	pestanas.add_theme_constant_override("separation", 10)
	var grupo_pestanas := ButtonGroup.new()
	var de_teclas := _boton_pestana("Teclas", grupo_pestanas)
	var de_reglas := _boton_pestana("Cómo se juega", grupo_pestanas)
	de_teclas.button_pressed = true
	pestanas.add_child(de_teclas)
	pestanas.add_child(de_reglas)
	caja.add_child(pestanas)
	caja.move_child(pestanas, 1)
	_tabla = TablaControles.new()
	caja.add_child(_tabla)
	caja.move_child(_tabla, _reglas.get_index())
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
	# El disparo automatico, en la misma fila: en una aparte el panel ya no
	# cabia en 648 de alto (se salia 3 px por arriba y por abajo).
	var hueco := Control.new()
	hueco.custom_minimum_size = Vector2(24.0, 0.0)
	fila.add_child(hueco)
	fila.add_child(Controles.boton_disparo_automatico())
	# Y las estadisticas (F3), tambien aqui por lo mismo: en una fila aparte
	# «Volver» se salia 40 px por abajo. F3 va con F11 en la lista de teclas,
	# en la misma linea, por la misma razon.
	var otro_hueco := Control.new()
	otro_hueco.custom_minimum_size = Vector2(18.0, 0.0)
	fila.add_child(otro_hueco)
	fila.add_child(Estadisticas.boton())
	caja.add_child(fila)
	# Debajo de las pestanas, encima de la tabla: es lo primero que se mira.
	caja.move_child(fila, 2)
	_fila_teclas = fila
	_reglas_base = _reglas.text
	de_teclas.toggled.connect(_ver_pestana_teclas)
	_ver_pestana_teclas(true)
	Controles.cambiado.connect(_poner_teclas)
	_poner_teclas()


func _boton_pestana(texto: String, grupo: ButtonGroup) -> Button:
	var boton := Button.new()
	boton.text = texto
	boton.toggle_mode = true
	boton.button_group = grupo
	boton.custom_minimum_size = Vector2(190, 36)
	boton.add_theme_font_size_override("font_size", 18)
	return boton


func _ver_pestana_teclas(teclas: bool) -> void:
	_tabla.visible = teclas
	_fila_teclas.visible = teclas
	_reglas.visible = not teclas


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
	var flechas := Controles.flechas_para_mover()
	_boton_wasd.set_pressed_no_signal(Controles.teclas_mover() == "W A S D")
	_boton_flechas.set_pressed_no_signal(flechas)
	_reglas.text = _reglas_base
	if Controles.teclas_disparar() != "flechas":
		_reglas.text = _reglas_base.replace("las flechas", "las teclas " + Controles.teclas_disparar())


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
	# Va por ENet, y un navegador no puede usar UDP. Jugar juntos desde la web
	# pediria un servidor (docs/mejoras-futuras/multijugador.md).
	_boton_cooperativo.visible = not OS.has_feature("web")
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


## Crea una ficha por cada mago que haya en disco (FichaMago).
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
		var ficha := FichaMago.new(personaje, "Jugar con %s" % personaje.nombre.to_lower())
		ficha.elegido.connect(_al_elegir)
		_fichas.add_child(ficha)
		if _primer_boton == null:
			_primer_boton = ficha.boton


func _al_elegir(personaje: PersonajeJugable) -> void:
	GestorProgreso.elegir_personaje(personaje)
	_al_jugar()


func _unhandled_input(evento: InputEvent) -> void:
	# Escape cierra los controles si estan abiertos. Es lo que espera cualquiera
	# que abra un panel, y evita tener que apuntar al boton con el raton.
	if not evento.is_action_pressed("ui_cancel"):
		return
	if _gacha.visible:
		_mostrar_gacha(false)
		get_viewport().set_input_as_handled()
	elif _panel_controles.visible:
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


## La fila de botones va centrada abajo, pero no puede pisar el volumen, que va a
## su izquierda. Con los cuatro (Gacha se anade por codigo, _montar_gacha) mide 702
## y, centrada en 1152 de ancho, empezaba en 225, con las barras del volumen hasta
## 240 por debajo de «Jugar» (Matias, 2026-11-13: «se solapa el volumen con los
## botones»). Si centrada no cabe, se corre a la derecha lo justo; en una pantalla
## ancha, o en la web sin «Salir», sigue centrada. A la derecha queda sitio: la
## version es un texto corto pegado al borde.
func _apartar_botones_del_volumen() -> void:
	var botones: Control = $Botones
	var volumen: Control = $Volumen
	var ancho_pantalla := get_viewport_rect().size.x
	var ancho_fila := botones.get_combined_minimum_size().x
	var centrada := (ancho_pantalla - ancho_fila) * 0.5
	var izquierda := maxf(centrada, volumen.get_global_rect().end.x + HUECO_VOLUMEN)
	# Las anclas estan en el centro de la pantalla: el desfase cuenta desde ahi.
	botones.offset_left = izquierda - ancho_pantalla * 0.5
	botones.offset_right = botones.offset_left + ancho_fila


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
