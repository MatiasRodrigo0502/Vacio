## Autoload Controles: con que teclas se mueve y con cuales se dispara.
## Pedido por Matias el 2026-10-18: poder moverse con WASD o con las flechas.
##
## OJO: sin class_name a proposito, como Pantalla y Sonido: un class_name igual
## al nombre del autoload da "hides an autoload singleton".
##
## POR QUE SE CAMBIAN LAS DOS COSAS A LA VEZ: el juego se mueve con unas
## teclas y dispara con otras. Moverse con las flechas deja el disparo sin
## teclas, asi que pasa a WASD: es la misma disposicion, al reves (para quien
## prefiere moverse con la derecha). El raton apunta igual en las dos.
##
## COMO: las acciones del mapa de teclas (mover_* y disparar_*) no cambian de
## nombre; aqui se intercambian sus teclas. Asi nada de lo que las usa (el
## jugador, la carga con el espacio) tiene que saber que hay dos formas.
##
## Se guarda en user://ajustes.cfg, junto al volumen y la pantalla completa.
extends Node

## Cambia la eleccion. La escuchan los textos que nombran las teclas (el
## panel de controles del menu y los carteles del piso 1).
signal cambiado

const ARCHIVO_AJUSTES := "user://ajustes.cfg"
const LADOS: Array[String] = ["izquierda", "derecha", "arriba", "abajo"]

## True = moverse con las flechas y disparar con WASD.
var flechas_para_mover: bool = false


func _ready() -> void:
	var ajustes := ConfigFile.new()
	# Sin archivo (la primera vez), WASD para moverse, como siempre.
	ajustes.load(ARCHIVO_AJUSTES)
	flechas_para_mover = ajustes.get_value("controles", "mover", "wasd") == "flechas"
	_aplicar()


func elegir(con_flechas: bool) -> void:
	if con_flechas == flechas_para_mover:
		return
	flechas_para_mover = con_flechas
	_aplicar()
	var ajustes := ConfigFile.new()
	ajustes.load(ARCHIVO_AJUSTES)
	ajustes.set_value("controles", "mover", "flechas" if con_flechas else "wasd")
	ajustes.save(ARCHIVO_AJUSTES)
	cambiado.emit()


## Las teclas de moverse y las de disparar, para los textos: "W A S D" o
## "flechas".
func teclas_mover() -> String:
	return "flechas" if flechas_para_mover else "W A S D"


func teclas_disparar() -> String:
	return "W A S D" if flechas_para_mover else "flechas"


## Desde las teclas de project.godot, y con las flechas, intercambiadas.
## Partir siempre de las del proyecto hace que elegir dos veces lo mismo no
## las vuelva a cambiar.
func _aplicar() -> void:
	InputMap.load_from_project_settings()
	if not flechas_para_mover:
		return
	for lado in LADOS:
		var mover := "mover_" + lado
		var disparar := "disparar_" + lado
		var de_mover := InputMap.action_get_events(mover)
		var de_disparar := InputMap.action_get_events(disparar)
		InputMap.action_erase_events(mover)
		InputMap.action_erase_events(disparar)
		for evento in de_disparar:
			InputMap.action_add_event(mover, evento)
		for evento in de_mover:
			InputMap.action_add_event(disparar, evento)
