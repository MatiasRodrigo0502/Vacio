## Autoload Controles: con que teclas se hace cada cosa.
##
## Desde el 2026-11-10 (Matias: «en controles debe haber la columna de funciones, la
## columna de tecla principal y la columna de tecla secundaria. Debes poder activar y
## desactivar a voluntad») cada accion tiene dos teclas, una principal y una
## secundaria, y cualquiera se puede cambiar o quitar (TablaControles). Antes solo se
## podia elegir moverse con WASD o con las flechas (2026-10-18), que sigue estando
## como atajo: pone las principales de moverse y disparar de una forma o de la otra.
##
## OJO: sin class_name a proposito, como Pantalla y Sonido: un class_name igual
## al nombre del autoload da "hides an autoload singleton".
##
## COMO: las acciones del mapa de teclas no cambian de nombre; aqui se les cambian
## los eventos. Asi nada de lo que las usa (el jugador, la pausa) sabe que se pueden
## cambiar. Se parte siempre de las de project.godot, que son las de fabrica.
##
## Se guarda en user://ajustes.cfg ([teclas]), junto al volumen y la pantalla completa.
extends Node

## Ha cambiado alguna tecla. La escuchan los textos que nombran teclas (el panel
## de controles, el tutorial y el HUD).
signal cambiado
## Ha cambiado el disparo automatico. Aparte de cambiado y con el valor, para
## conectarle tal cual el metodo del interruptor (boton_disparo_automatico):
## esa conexion se quita sola al liberarse el interruptor. La de antes era una
## funcion anonima que lo guardaba, y al volver de la partida al menu y tocar
## el del menu daba error por el de la pausa, ya liberado.
signal disparo_automatico_cambiado(activo: bool)

const ARCHIVO_AJUSTES := "user://ajustes.cfg"
const LADOS: Array[String] = ["arriba", "izquierda", "abajo", "derecha"]
## Las acciones que se pueden cambiar, en el orden de la tabla, con lo que hacen.
const ACCIONES: Array = [
	["mover_arriba", "Moverse arriba"],
	["mover_izquierda", "Moverse a la izquierda"],
	["mover_abajo", "Moverse abajo"],
	["mover_derecha", "Moverse a la derecha"],
	["andar_despacio", "Andar despacio"],
	["disparar_arriba", "Disparar arriba"],
	["disparar_izquierda", "Disparar a la izquierda"],
	["disparar_abajo", "Disparar abajo"],
	["disparar_derecha", "Disparar a la derecha"],
	["disparar_raton", "Disparar hacia el ratón"],
	["cargar_ataque", "Ataque especial hacia el ratón"],
	["cargar_ataque_teclado", "Ataque especial hacia donde apuntas"],
	["cambiar_modo_arma", "Cambiar la forma del arma"],
	["pausar", "Pausa"],
]
## Cuantas teclas tiene cada accion: la principal y la secundaria.
const HUECOS: int = 2
const NOMBRES_RATON := {
	MOUSE_BUTTON_LEFT: "Clic izquierdo",
	MOUSE_BUTTON_RIGHT: "Clic derecho",
	MOUSE_BUTTON_MIDDLE: "Clic central",
	MOUSE_BUTTON_WHEEL_UP: "Rueda arriba",
	MOUSE_BUTTON_WHEEL_DOWN: "Rueda abajo",
	MOUSE_BUTTON_XBUTTON1: "Botón lateral 1",
	MOUSE_BUTTON_XBUTTON2: "Botón lateral 2",
}
## Las teclas que se nombran de otra forma que como las llama Godot.
const NOMBRES_TECLA := {
	KEY_UP: "Flecha arriba",
	KEY_DOWN: "Flecha abajo",
	KEY_LEFT: "Flecha izquierda",
	KEY_RIGHT: "Flecha derecha",
	KEY_SPACE: "Espacio",
	KEY_ESCAPE: "Esc",
	KEY_SHIFT: "Shift",
	KEY_CTRL: "Ctrl",
	KEY_ALT: "Alt",
	KEY_ENTER: "Intro",
	KEY_BACKSPACE: "Retroceso",
	KEY_TAB: "Tabulador",
	KEY_DELETE: "Supr",
}

## Disparo automatico con autoapuntado (Matias, 2026-11-03): mientras no
## apuntes tu, el mago dispara sin parar al enemigo mas cercano de su sala
## (Jugador._direccion_automatica). Se guarda como lo demas.
var disparo_automatico: bool = false
## Accion -> [principal, secundaria]: un InputEvent, o null si esta desactivada.
var _teclas: Dictionary = {}
## Las de project.godot, con la misma forma: para restablecer.
var _de_fabrica: Dictionary = {}
## Donde se guarda. Las pruebas lo cambian (usar_archivo) para no tocar los
## ajustes de quien las lanza.
var _archivo: String = ARCHIVO_AJUSTES


func _ready() -> void:
	InputMap.load_from_project_settings()
	for fila in ACCIONES:
		var eventos := InputMap.action_get_events(fila[0])
		var huecos: Array = []
		for i in HUECOS:
			huecos.append(eventos[i] if i < eventos.size() else null)
		_de_fabrica[fila[0]] = huecos
	var ajustes := ConfigFile.new()
	ajustes.load(ARCHIVO_AJUSTES)
	disparo_automatico = ajustes.get_value("controles", "disparo_automatico", false)
	_teclas = _copia(_de_fabrica)
	if ajustes.has_section("teclas"):
		for fila in ACCIONES:
			var guardadas: Array = ajustes.get_value("teclas", fila[0], [])
			for i in mini(guardadas.size(), HUECOS):
				_teclas[fila[0]][i] = _evento_de(guardadas[i])
	elif ajustes.get_value("controles", "mover", "wasd") == "flechas":
		# Quien eligio las flechas antes de que hubiera tabla.
		_poner_principales(true)
	_aplicar()


## Para las pruebas: guarda en otro archivo y vuelve a las teclas de fabrica, sin
## tocar las de quien las lanza.
func usar_archivo(ruta: String) -> void:
	_archivo = ruta
	_teclas = _copia(_de_fabrica)
	_aplicar()


# --- Leer -------------------------------------------------------------------------

## [principal, secundaria] de esa accion; null donde no hay tecla.
func teclas_de(accion: String) -> Array:
	return _teclas.get(accion, [null, null])


## El nombre de una tecla o boton, para ensenarlo: "W", "Flecha arriba", "Clic
## derecho". Vacio si no hay.
func nombre_de(evento: InputEvent) -> String:
	if evento is InputEventKey:
		var codigo: Key = evento.physical_keycode if evento.physical_keycode != KEY_NONE else evento.keycode
		if NOMBRES_TECLA.has(codigo):
			return NOMBRES_TECLA[codigo]
		# La letra de esa tecla en un teclado QWERTY, como el espanol. La de la
		# distribucion de cada teclado (keyboard_get_keycode_from_physical) da error
		# sin ventana y en el navegador: lo pillo la prueba de arranque de la release.
		return OS.get_keycode_string(codigo)
	if evento is InputEventMouseButton:
		return NOMBRES_RATON.get(evento.button_index, "Botón %d del ratón" % evento.button_index)
	return ""


## Las teclas de una accion en un texto: "Q", "Clic derecho o Espacio", o
## "sin tecla" si las dos estan quitadas.
func nombres(accion: String) -> String:
	var lista: PackedStringArray = []
	for evento in teclas_de(accion):
		if evento != null:
			lista.append(nombre_de(evento))
	return " o ".join(lista) if not lista.is_empty() else "sin tecla"


## Las teclas de moverse y las de disparar, para los textos: "W A S D",
## "flechas" o las cuatro que haya.
func teclas_mover() -> String:
	return _cuatro("mover_")


func teclas_disparar() -> String:
	return _cuatro("disparar_")


## True si se mueve con las flechas (y se dispara con WASD): el atajo del panel.
func flechas_para_mover() -> bool:
	return teclas_mover() == "flechas"


func _cuatro(prefijo: String) -> String:
	var letras: PackedStringArray = []
	for lado in LADOS:
		letras.append(nombre_de(teclas_de(prefijo + lado)[0]) if teclas_de(prefijo + lado)[0] != null else "-")
	if letras == PackedStringArray(["Flecha arriba", "Flecha izquierda", "Flecha abajo", "Flecha derecha"]):
		return "flechas"
	# En el orden de LADOS, las de fabrica se leen "W A S D".
	return " ".join(letras)


# --- Cambiar -----------------------------------------------------------------------

## Pone 'evento' en ese hueco (0 la principal, 1 la secundaria) de la accion, o lo
## quita con null. Una tecla solo hace una cosa: si ya la tenia otra accion, se le
## quita a esa (lo dice el panel al ensenarlo vacio).
func poner_tecla(accion: String, hueco: int, evento: InputEvent) -> void:
	if evento != null:
		for otra in _teclas:
			for i in HUECOS:
				if _teclas[otra][i] != null and _mismo(_teclas[otra][i], evento):
					_teclas[otra][i] = null
	_teclas[accion][hueco] = evento
	_aplicar()
	_guardar()


## Todas como de fabrica.
func restablecer() -> void:
	_teclas = _copia(_de_fabrica)
	_aplicar()
	_guardar()


## El atajo de "Moverse con": las principales de moverse y disparar, con WASD y
## flechas en un sitio o en el otro. Las secundarias no se tocan.
func elegir(con_flechas: bool) -> void:
	_poner_principales(con_flechas)
	_aplicar()
	_guardar()


func _poner_principales(con_flechas: bool) -> void:
	for lado in LADOS:
		var wasd: InputEvent = _de_fabrica["mover_" + lado][0]
		var flecha: InputEvent = _de_fabrica["disparar_" + lado][0]
		_teclas["mover_" + lado][0] = flecha if con_flechas else wasd
		_teclas["disparar_" + lado][0] = wasd if con_flechas else flecha


func elegir_disparo_automatico(activo: bool) -> void:
	if activo == disparo_automatico:
		return
	disparo_automatico = activo
	var ajustes := ConfigFile.new()
	ajustes.load(_archivo)
	ajustes.set_value("controles", "disparo_automatico", activo)
	ajustes.save(_archivo)
	disparo_automatico_cambiado.emit(activo)
	cambiado.emit()


## El interruptor del disparo automatico, igual en el panel de controles del
## menu y en la pausa: se crea aqui para que los dos sean el mismo, y cada
## uno sigue al otro si se cambia (cambiado).
func boton_disparo_automatico() -> CheckButton:
	var boton := CheckButton.new()
	boton.text = "Disparo automático"
	boton.tooltip_text = "Dispara solo al enemigo más cercano de la sala mientras no apuntes tú"
	boton.add_theme_font_size_override("font_size", 18)
	boton.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	boton.button_pressed = disparo_automatico
	boton.toggled.connect(elegir_disparo_automatico)
	disparo_automatico_cambiado.connect(boton.set_pressed_no_signal)
	return boton


# --- Por dentro --------------------------------------------------------------------

## Las del proyecto, cambiadas por las de la tabla. Las acciones que no estan en
## ACCIONES (ui_*) se quedan como vienen.
func _aplicar() -> void:
	InputMap.load_from_project_settings()
	for fila in ACCIONES:
		InputMap.action_erase_events(fila[0])
		for evento in _teclas[fila[0]]:
			if evento != null:
				InputMap.action_add_event(fila[0], evento)
	cambiado.emit()


func _guardar() -> void:
	var ajustes := ConfigFile.new()
	ajustes.load(_archivo)
	for fila in ACCIONES:
		var guardadas: Array = []
		for evento in _teclas[fila[0]]:
			guardadas.append(_texto_de(evento))
		ajustes.set_value("teclas", fila[0], guardadas)
	# El de antes ya no manda: lo dice la tabla.
	if ajustes.has_section_key("controles", "mover"):
		ajustes.erase_section_key("controles", "mover")
	ajustes.save(_archivo)


## "tecla:87", "raton:2" o "" (sin tecla): asi se guarda.
func _texto_de(evento: InputEvent) -> String:
	if evento is InputEventKey:
		return "tecla:%d" % (evento.physical_keycode if evento.physical_keycode != KEY_NONE else evento.keycode)
	if evento is InputEventMouseButton:
		return "raton:%d" % evento.button_index
	return ""


func _evento_de(texto: String) -> InputEvent:
	var partes := texto.split(":")
	if partes.size() != 2 or not partes[1].is_valid_int():
		return null
	if partes[0] == "tecla":
		var tecla := InputEventKey.new()
		tecla.physical_keycode = int(partes[1]) as Key
		return tecla
	if partes[0] == "raton":
		var boton := InputEventMouseButton.new()
		boton.button_index = int(partes[1]) as MouseButton
		return boton
	return null


func _mismo(uno: InputEvent, otro: InputEvent) -> bool:
	return _texto_de(uno) == _texto_de(otro)


func _copia(de: Dictionary) -> Dictionary:
	var copia := {}
	for accion in de:
		copia[accion] = de[accion].duplicate()
	return copia
