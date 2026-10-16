## Panel del cooperativo en el menu: crear una sala o entrar en la de otro con
## su codigo y, ya dentro, la sala de espera (quien esta, con que mago, y el
## boton de empezar del anfitrion). Fase 1 del multijugador (Matias,
## 2026-10-16). La conexion la lleva el autoload Red; esto solo la ensena.
##
## POR QUE SE MONTA POR CODIGO Y NO EN UNA ESCENA: como las fichas de los
## magos del menu, los botones de mago salen de resources/personajes/: un mago
## nuevo aparece aqui sin tocar nada.
class_name SalaCooperativo
extends Control

## Se ha pulsado Volver con el panel fuera de cualquier sala.
signal cerrado

const COLOR_TITULO := Color(1.0, 0.741, 0.361)
const COLOR_TEXTO := Color(0.85, 0.82, 0.78)
const COLOR_FLOJO := Color(0.62, 0.58, 0.55)
const COLOR_AVISO := Color(1.0, 0.55, 0.45)

# Fuera de una sala.
var _fuera: VBoxContainer
var _codigo: LineEdit
var _boton_crear: Button
var _boton_unirse: Button
var _mensaje: Label
# Dentro de una sala.
var _dentro: VBoxContainer
var _titulo_sala: Label
var _direccion: Label
var _lista: VBoxContainer
var _magos: HBoxContainer
var _boton_empezar: Button
var _espera: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var fondo := ColorRect.new()
	fondo.color = Color(0.0627, 0.047, 0.043)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)
	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centro)
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 18)
	centro.add_child(caja)
	caja.add_child(_etiqueta("COOPERATIVO EN RED LOCAL", 40, COLOR_TITULO))
	_montar_fuera(caja)
	_montar_dentro(caja)

	Red.lista_cambiada.connect(_actualizar)
	Red.fallo.connect(_al_fallar)
	Red.sala_cerrada.connect(_al_fallar)
	visibility_changed.connect(_actualizar)
	_actualizar()


func _montar_fuera(caja: VBoxContainer) -> void:
	_fuera = VBoxContainer.new()
	_fuera.add_theme_constant_override("separation", 16)
	caja.add_child(_fuera)
	_fuera.add_child(_etiqueta(
		"Hasta 3 jugadores en la misma red (la wifi de clase o de casa).\n" +
		"Uno crea la sala y los demás entran con su código.", 18, COLOR_TEXTO))

	_boton_crear = _boton("Crear sala", 260)
	_boton_crear.pressed.connect(_al_crear)
	_fuera.add_child(_centrado(_boton_crear))

	_fuera.add_child(_etiqueta("o entra en la de otro:", 16, COLOR_FLOJO))
	var fila := HBoxContainer.new()
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	fila.add_theme_constant_override("separation", 10)
	_codigo = LineEdit.new()
	_codigo.placeholder_text = "Código de la sala"
	_codigo.custom_minimum_size = Vector2(240, 44)
	_codigo.add_theme_font_size_override("font_size", 20)
	_codigo.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_codigo.max_length = 15
	_codigo.text_submitted.connect(func(_texto: String) -> void: _al_unirse())
	fila.add_child(_codigo)
	_boton_unirse = _boton("Unirse", 140)
	_boton_unirse.pressed.connect(_al_unirse)
	fila.add_child(_boton_unirse)
	_fuera.add_child(fila)

	_mensaje = _etiqueta("", 16, COLOR_AVISO)
	_fuera.add_child(_mensaje)
	_fuera.add_child(_etiqueta(
		"Si Windows pregunta por el cortafuegos al crear la sala, dale permiso en redes privadas.",
		14, COLOR_FLOJO))
	var volver := _boton("Volver", 240)
	volver.pressed.connect(func() -> void: cerrado.emit())
	_fuera.add_child(_centrado(volver))


func _montar_dentro(caja: VBoxContainer) -> void:
	_dentro = VBoxContainer.new()
	_dentro.add_theme_constant_override("separation", 14)
	caja.add_child(_dentro)
	_titulo_sala = _etiqueta("", 34, Color.WHITE)
	_dentro.add_child(_titulo_sala)
	_direccion = _etiqueta("", 14, COLOR_FLOJO)
	_dentro.add_child(_direccion)
	_lista = VBoxContainer.new()
	_lista.add_theme_constant_override("separation", 4)
	_dentro.add_child(_lista)

	_dentro.add_child(_etiqueta("Elige tu mago (cada uno, uno distinto):", 17, COLOR_TEXTO))
	_magos = HBoxContainer.new()
	_magos.alignment = BoxContainer.ALIGNMENT_CENTER
	_magos.add_theme_constant_override("separation", 12)
	_dentro.add_child(_magos)
	for indice in GestorProgreso.personajes.size():
		var boton := _boton(GestorProgreso.personajes[indice].nombre, 220)
		boton.toggle_mode = true
		boton.pressed.connect(func() -> void: Red.elegir_mago(indice))
		_magos.add_child(boton)

	_boton_empezar = _boton("Empezar", 260)
	_boton_empezar.pressed.connect(Red.empezar)
	_dentro.add_child(_centrado(_boton_empezar))
	_espera = _etiqueta("", 16, COLOR_FLOJO)
	_dentro.add_child(_espera)
	_dentro.add_child(_etiqueta(
		"De momento (fase 1) se juega solo el piso 1: os veis, andáis y disparáis juntos.",
		14, COLOR_FLOJO))
	var salir := _boton("Salir de la sala", 240)
	salir.pressed.connect(func() -> void:
		Red.salir()
		_mensaje.text = ""
		_actualizar())
	_dentro.add_child(_centrado(salir))


## Lo pone todo como esta la sala ahora. Se llama con cada cambio de la lista.
func _actualizar() -> void:
	if _fuera == null:
		return
	var en_sala := Red.en_sala() and not Red.jugadores.is_empty()
	_fuera.visible = not en_sala
	_dentro.visible = en_sala
	if not en_sala:
		_boton_crear.disabled = false
		_boton_unirse.disabled = false
		return

	_titulo_sala.text = "SALA  %s" % Red.codigo
	_direccion.text = "Pasa el código a los demás: entran con «Unirse». (Dirección: %s)" % Red.direccion

	for hijo in _lista.get_children():
		hijo.queue_free()
	var ids := Red.jugadores.keys()
	ids.sort_custom(func(a: int, b: int) -> bool:
		return int(Red.jugadores[a].numero) < int(Red.jugadores[b].numero))
	for id: int in ids:
		var datos: Dictionary = Red.jugadores[id]
		var mago := Red.mago_de(id)
		var texto := "Jugador %d" % int(datos.numero)
		if id == 1:
			texto += " · crea la sala"
		if id == Red.mi_id():
			texto += " · tú"
		texto += "  —  " + (mago.nombre if mago != null else "eligiendo mago…")
		_lista.add_child(_etiqueta(texto, 20, mago.color if mago != null else COLOR_TEXTO))

	for indice in _magos.get_child_count():
		var boton: Button = _magos.get_child(indice)
		var dueno := Red.quien_tiene(indice)
		var nombre := GestorProgreso.personajes[indice].nombre
		boton.set_pressed_no_signal(dueno == Red.mi_id())
		boton.disabled = dueno != 0 and dueno != Red.mi_id()
		boton.text = nombre if dueno == 0 or dueno == Red.mi_id() \
			else "%s · jugador %d" % [nombre, int(Red.jugadores[dueno].numero)]

	var falta := Red.falta_para_empezar()
	_boton_empezar.visible = Red.es_anfitrion()
	_boton_empezar.disabled = falta != ""
	if Red.es_anfitrion():
		_espera.text = falta
	else:
		_espera.text = falta if falta != "" else "Esperando a que el jugador 1 empiece la partida…"


func _al_crear() -> void:
	_mensaje.text = ""
	var error := Red.crear_sala()
	if error != OK:
		_mensaje.text = "No se ha podido crear la sala (error %d). ¿Hay otra abierta en este ordenador?" % error
	_actualizar()


func _al_unirse() -> void:
	if _codigo.text.strip_edges() == "":
		_mensaje.text = "Escribe el código que te pase quien ha creado la sala."
		return
	_mensaje.text = "Buscando la sala…"
	_boton_crear.disabled = true
	_boton_unirse.disabled = true
	Red.unirse(_codigo.text)


## Un mensaje en el panel, fuera de la sala. Lo usa el menu al volver de
## una partida que se ha cortado.
func mostrar_mensaje(mensaje: String) -> void:
	_mensaje.text = mensaje
	_actualizar()


func _al_fallar(mensaje: String) -> void:
	_mensaje.text = mensaje
	_actualizar()


func _etiqueta(texto: String, tamano: int, color: Color) -> Label:
	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.add_theme_font_size_override("font_size", tamano)
	etiqueta.add_theme_color_override("font_color", color)
	etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return etiqueta


func _boton(texto: String, ancho: float) -> Button:
	var boton := Button.new()
	boton.text = texto
	boton.custom_minimum_size = Vector2(ancho, 46)
	boton.add_theme_font_size_override("font_size", 18)
	return boton


func _centrado(control: Control) -> Control:
	control.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return control
