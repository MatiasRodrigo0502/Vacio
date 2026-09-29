## Menu de pausa: Escape congela la partida y lo enseña; Escape otra vez, o
## "Continuar", la reanuda.
##
## POR QUE PAUSA EL ARBOL ENTERO (get_tree().paused) Y NO CADA COSA:
## con el arbol en pausa se paran solos el jugador, los enemigos, las bolas, la
## camara y los avisos del HUD, sin que ninguno tenga que saber que existe una
## pausa. Pausar cosa por cosa obligaria a tocar cada script y a acordarse de
## cada una que se anada despues.
##
## Este nodo es el unico que sigue vivo durante la pausa (process_mode =
## ALWAYS en su escena): si se pausara con el resto, no podria oir el Escape
## que la quita.
class_name MenuPausa
extends CanvasLayer

signal reinicio_solicitado
signal menu_solicitado

@onready var _subtitulo: Label = $Centro/Caja/Subtitulo
@onready var _boton_continuar: Button = $Centro/Caja/BotonContinuar


func _ready() -> void:
	visible = false
	_boton_continuar.pressed.connect(continuar)
	$Centro/Caja/BotonReiniciar.pressed.connect(_al_reiniciar)
	$Centro/Caja/BotonMenu.pressed.connect(_al_ir_al_menu)


func _unhandled_input(evento: InputEvent) -> void:
	if not evento.is_action_pressed("pausar"):
		return
	if visible:
		continuar()
	elif not GestorProgreso.partida_terminada:
		# Con la partida acabada ya esta la pantalla final, que tiene sus
		# propios botones: una pausa encima no pintaria nada.
		pausar()
	get_viewport().set_input_as_handled()


func pausar() -> void:
	var datos := GestorProgreso.obtener_datos_piso(GestorProgreso.piso_actual)
	var capa := datos.nombre_capa.to_upper() if datos != null else ""
	_subtitulo.text = "Piso %d de %d  ·  %s" % [
		GestorProgreso.piso_actual, GestorProgreso.total_pisos(), capa]
	visible = true
	get_tree().paused = true
	# El foco en "Continuar", para que con el teclado baste con Enter.
	_boton_continuar.grab_focus()


func continuar() -> void:
	visible = false
	get_tree().paused = false
	# Sin esto el boton se quedaria con el foco, escondido, y un Enter o un
	# Espacio en mitad de la partida lo pulsaria.
	get_viewport().gui_release_focus()


## La pausa se quita ANTES de avisar: reiniciar construye un piso nuevo, y
## volver al menu cambia de escena; con el arbol en pausa, lo nuevo naceria
## congelado.
func _al_reiniciar() -> void:
	continuar()
	reinicio_solicitado.emit()


func _al_ir_al_menu() -> void:
	continuar()
	menu_solicitado.emit()
