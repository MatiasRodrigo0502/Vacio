## Autoload Pantalla: el juego a pantalla completa, y F11 (o Alt+Intro) para
## pasar a ventana y volver. Pedido por Matias el 2026-10-14.
##
## OJO: sin class_name a proposito, como Sonido y GestorProgreso: un class_name
## igual al nombre del autoload da "hides an autoload singleton".
##
## POR QUE PANTALLA COMPLETA "SIN BORDES" Y NO LA EXCLUSIVA:
## WINDOW_MODE_FULLSCREEN es una ventana del tamano de la pantalla. No cambia
## la resolucion del monitor, asi que Alt+Tab es inmediato y no parpadea. La
## exclusiva solo gana algo de rendimiento en Windows, y este juego no lo
## necesita. El dibujo se estira solo (stretch canvas_items + expand en
## project.godot): en 16:9 se ve igual que en la ventana, solo mas grande.
##
## POR QUE NO EN project.godot (window/size/mode):
## asi no se puede elegir. Aqui se lee lo ultimo que eligio el jugador, en
## user://ajustes.cfg, junto a los volumenes.
##
## SOLO EN EL JUEGO EXPORTADO: jugando desde Godot (el editor o jugar.bat)
## sale en ventana, para ver el depurador y la consola al lado. F11 funciona
## igual, pero lo que se elija ahi no se guarda: si no, cambiaria como
## arranca el .exe del mismo ordenador, que comparte user://.
extends Node

const ARCHIVO_AJUSTES := "user://ajustes.cfg"

## Lo que hay ahora: true pantalla completa, false ventana.
var completa: bool = true


func _ready() -> void:
	# Tambien en pausa: F11 tiene que funcionar en el menu de pausa.
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not _se_puede():
		completa = false
		return
	if OS.has_feature("editor"):
		completa = false
		return
	var ajustes := ConfigFile.new()
	# Sin archivo (la primera vez), pantalla completa.
	ajustes.load(ARCHIVO_AJUSTES)
	completa = ajustes.get_value("pantalla", "completa", true)
	_aplicar()


## Pasa de pantalla completa a ventana o al reves, y lo recuerda.
func alternar() -> void:
	if not _se_puede():
		return
	completa = not completa
	_aplicar()
	if OS.has_feature("editor"):
		return
	var ajustes := ConfigFile.new()
	ajustes.load(ARCHIVO_AJUSTES)
	ajustes.set_value("pantalla", "completa", completa)
	ajustes.save(ARCHIVO_AJUSTES)


# En _input y no en _unhandled_input: un boton con el foco no deja pasar las
# teclas, y F11 tiene que ir en cualquier menu.
func _input(evento: InputEvent) -> void:
	var tecla := evento as InputEventKey
	if tecla == null or not tecla.pressed or tecla.echo:
		return
	var f11 := tecla.keycode == KEY_F11
	var alt_intro := tecla.alt_pressed and (tecla.keycode == KEY_ENTER or tecla.keycode == KEY_KP_ENTER)
	if f11 or alt_intro:
		get_viewport().set_input_as_handled()
		alternar()


func _aplicar() -> void:
	if completa:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


## Sin ventana (las pruebas en headless) o metido dentro del editor (la
## pestana Juego) no hay pantalla que cambiar.
func _se_puede() -> bool:
	return DisplayServer.get_name() != "headless" and not Engine.is_embedded_in_editor()
