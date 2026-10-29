## Pantalla de fin de partida: victoria (piso 12 superado) o derrota (sin vida).
## Una sola escena para los dos casos porque solo cambian los textos; separarlas
## duplicaria layout para nada.
##
## CAMBIAR MAGO (2026-10-29, pedido por Matias): ensena las fichas de los magos
## que no se han usado en la partida que acaba (FichaMago, las mismas del
## menu) y empieza una nueva desde el piso 1 con el que se elija. Principal no
## sabe nada de esto: el mago va en GestorProgreso.personaje_elegido, y
## reiniciar ya lo lee de ahi.
class_name PantallaFinal
extends CanvasLayer

signal reinicio_solicitado
signal menu_solicitado

@onready var _titulo: Label = $Centro/Caja/Titulo
@onready var _subtitulo: Label = $Centro/Caja/Subtitulo
@onready var _boton: Button = $Centro/Caja/BotonReiniciar
@onready var _boton_cambiar: Button = $Centro/Caja/BotonCambiarMago
@onready var _boton_menu: Button = $Centro/Caja/BotonMenu
@onready var _caja: Control = $Centro/Caja
@onready var _eleccion: Control = $Centro/Eleccion
@onready var _fichas: HBoxContainer = $Centro/Eleccion/Fichas


func _ready() -> void:
	_boton.pressed.connect(func() -> void: reinicio_solicitado.emit())
	_boton_cambiar.pressed.connect(_ver_eleccion.bind(true))
	_boton_menu.pressed.connect(func() -> void: menu_solicitado.emit())
	$Centro/Caja/BotonPartidas.pressed.connect(func() -> void: RegistroPartida.abrir_carpeta())
	$Centro/Eleccion/BotonVolver.pressed.connect(_ver_eleccion.bind(false))


## R vuelve a empezar con el mismo mago, como dice el boton; Escape, desde la
## eleccion de mago, vuelve atras. Con la eleccion abierta, R no hace nada: ahi
## se esta escogiendo otro mago.
func _unhandled_input(evento: InputEvent) -> void:
	if not visible:
		return
	if _eleccion.visible:
		if evento.is_action_pressed("pausar"):
			_ver_eleccion(false)
			get_viewport().set_input_as_handled()
		return
	if _boton.visible and evento is InputEventKey and evento.pressed and not evento.echo \
			and (evento as InputEventKey).keycode == KEY_R:
		get_viewport().set_input_as_handled()
		reinicio_solicitado.emit()


func mostrar_victoria(total_pisos: int) -> void:
	_titulo.text = "HAS LLEGADO AL NUCLEO"
	_titulo.modulate = Color(1.0, 0.78, 0.3)
	_subtitulo.text = "%d pisos superados. El vacio tiene fondo." % total_pisos
	_boton.text = "Jugar otra vez  (R)"
	_mostrar()


func mostrar_derrota(numero_piso: int) -> void:
	_titulo.text = "TE HAS QUEDADO EN EL PISO %d" % numero_piso
	_titulo.modulate = Color(0.95, 0.35, 0.28)
	_subtitulo.text = "Sin vida. El descenso termina aqui."
	_boton.text = "Reintentar  (R)"
	_mostrar()


## Cooperativo: no se puede volver a empezar para uno solo (ni con otro
## mago); solo salir de la sala (Principal lo hace por Red).
func modo_cooperativo() -> void:
	_boton.visible = false
	_boton_cambiar.visible = false
	_boton_menu.text = "Salir de la sala"


func ocultar() -> void:
	visible = false
	_ver_eleccion(false)


func _mostrar() -> void:
	visible = true
	_ver_eleccion(false)
	# Si no hay otro mago que elegir (solo uno en resources/personajes/), el
	# boton no lleva a nada.
	if _boton.visible:
		_boton_cambiar.visible = not _otros_magos().is_empty()
	if _boton.visible:
		_boton.grab_focus()
	else:
		_boton_menu.grab_focus()


## Los magos que no se han usado en esta partida: todos menos el elegido.
func _otros_magos() -> Array[PersonajeJugable]:
	var otros: Array[PersonajeJugable] = []
	for personaje in GestorProgreso.personajes:
		if personaje != GestorProgreso.personaje_elegido:
			otros.append(personaje)
	return otros


## Cambia entre los botones del final y la eleccion de mago. Las fichas se
## montan cada vez que se abre: el mago usado cambia de una partida a otra.
func _ver_eleccion(ver: bool) -> void:
	if not is_node_ready():
		return
	_caja.visible = not ver
	_eleccion.visible = ver
	# Fuera del contenedor ya: queue_free espera al final del fotograma, y
	# mientras las fichas viejas y las nuevas saldrian juntas.
	for hijo in _fichas.get_children():
		_fichas.remove_child(hijo)
		hijo.queue_free()
	if not ver:
		if visible:
			_boton_cambiar.grab_focus()
		return
	var primera: Button = null
	for personaje in _otros_magos():
		var ficha := FichaMago.new(personaje, "Empezar con %s" % personaje.nombre.to_lower())
		ficha.elegido.connect(_al_elegir)
		_fichas.add_child(ficha)
		if primera == null:
			primera = ficha.boton
	if primera != null:
		primera.grab_focus()


## Se empieza de cero con el mago elegido: Principal reinicia con el que haya
## en GestorProgreso (vida, ventaja, ataque especial y mejoras, desde cero).
func _al_elegir(personaje: PersonajeJugable) -> void:
	GestorProgreso.elegir_personaje(personaje)
	reinicio_solicitado.emit()
