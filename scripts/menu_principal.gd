## Menu principal: lo primero que se ve al abrir el juego.
##
## POR QUE ES LA ESCENA PRINCIPAL Y NO UNA CAPA DENTRO DE Principal.tscn:
## el menu no necesita nada del juego (ni gestor, ni pool, ni pisos) y el juego
## no necesita nada del menu. Teniendolos como escenas separadas, entrar a jugar
## libera el menu entero y salir del juego libera la partida entera, sin tener
## que acordarse de limpiar estados a mano.
extends Control

const ESCENA_JUEGO := "res://scenes/Principal.tscn"

@onready var _panel_controles: Control = $PanelControles
@onready var _boton_jugar: Button = $Centro/Caja/BotonJugar


func _ready() -> void:
	$Centro/Caja/BotonJugar.pressed.connect(_al_jugar)
	$Centro/Caja/BotonControles.pressed.connect(_mostrar_controles.bind(true))
	$Centro/Caja/BotonSalir.pressed.connect(_al_salir)
	$PanelControles/Centro/Caja/BotonVolver.pressed.connect(_mostrar_controles.bind(false))

	_panel_controles.hide()
	_boton_jugar.grab_focus()


func _unhandled_input(evento: InputEvent) -> void:
	# Escape cierra los controles si estan abiertos. Es lo que espera cualquiera
	# que abra un panel, y evita tener que apuntar al boton con el raton.
	if evento.is_action_pressed("ui_cancel") and _panel_controles.visible:
		_mostrar_controles(false)
		get_viewport().set_input_as_handled()


func _al_jugar() -> void:
	get_tree().change_scene_to_file(ESCENA_JUEGO)


func _al_salir() -> void:
	get_tree().quit()


func _mostrar_controles(visible_ahora: bool) -> void:
	_panel_controles.visible = visible_ahora
	# El foco se mueve al panel y vuelve al menu, para que el teclado siga
	# sirviendo para moverse sin tocar el raton.
	if visible_ahora:
		$PanelControles/Centro/Caja/BotonVolver.grab_focus()
	else:
		_boton_jugar.grab_focus()
