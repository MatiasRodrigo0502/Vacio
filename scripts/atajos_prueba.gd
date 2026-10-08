## Atajos de teclado para probar y equilibrar el juego sin jugarlo entero:
##
##   F1  invencible (si / no)
##   F2  piso anterior
##   F3  piso siguiente
##   F4  matar a los enemigos de la sala en la que estas
##
## SOLO EXISTEN AL JUGAR DESDE GODOT (el editor o jugar.bat). Principal crea
## este nodo solo si OS.is_debug_build(), que en el .exe exportado es false:
## quien juegue la version entregada no puede saltarse nada por accidente.
##
## POR QUE TECLAS SUELTAS Y NO ACCIONES DEL MAPA DE TECLAS:
## no son controles del juego, sino una herramienta del equipo. En el mapa de
## teclas saldrian junto a moverse y disparar, como si fueran parte del juego.
class_name AtajosPrueba
extends CanvasLayer

## Cuantas vueltas da F4 como mucho. Los slimes sueltan crias al morir, y las
## crias se apuntan en la sala un fotograma despues: hay que repetir hasta que
## no quede nadie. Las crias no se dividen, asi que bastan dos o tres.
const VUELTAS_LIMPIAR: int = 5

var _jugador: Jugador
## Devuelve el piso que esta montado ahora. Es una funcion y no el piso en si
## porque el piso cambia (y el de antes se libera) en cada salto.
var _piso_actual: Callable
var _etiqueta: Label


func _init(jugador: Jugador, piso_actual: Callable) -> void:
	_jugador = jugador
	_piso_actual = piso_actual
	# Encima del HUD (capa 2) y debajo de la pantalla final (3) y la pausa (4).
	layer = 2


func _ready() -> void:
	# Abajo a la izquierda, donde no hay nada del HUD, y discreto: tiene que
	# recordar que existen sin estorbar mientras se prueba el juego.
	_etiqueta = Label.new()
	_etiqueta.position = Vector2(16.0, 0.0)
	_etiqueta.add_theme_font_size_override("font_size", 13)
	_etiqueta.add_theme_color_override("font_outline_color", Color.BLACK)
	_etiqueta.add_theme_constant_override("outline_size", 4)
	add_child(_etiqueta)
	get_viewport().size_changed.connect(_colocar)
	_actualizar_texto()


func _unhandled_input(evento: InputEvent) -> void:
	var tecla := evento as InputEventKey
	if tecla == null or not tecla.pressed or tecla.echo:
		return
	match tecla.keycode:
		KEY_F1:
			_jugador.invencible = not _jugador.invencible
			_actualizar_texto()
		KEY_F2:
			GestorProgreso.ir_a_piso(GestorProgreso.piso_actual - 1)
		KEY_F3:
			GestorProgreso.ir_a_piso(GestorProgreso.piso_actual + 1)
		KEY_F4:
			_limpiar_sala()
		_:
			return
	get_viewport().set_input_as_handled()


func _limpiar_sala() -> void:
	var piso: Piso = _piso_actual.call()
	if piso == null or piso.sala_actual() == null:
		return
	var sala := piso.sala_actual()
	for vuelta in VUELTAS_LIMPIAR:
		if sala.esta_despejada():
			return
		for enemigo in sala.enemigos():
			enemigo.matar()
		# La muerte va diferida y las crias nacen en ella: hay que esperar a
		# que pase para ver si queda alguien.
		await get_tree().physics_frame
		await get_tree().physics_frame
		if not is_instance_valid(sala):
			return


func _actualizar_texto() -> void:
	var estado := "SÍ" if _jugador.invencible else "no"
	_etiqueta.text = "PRUEBA  F1 invencible: %s   F2/F3 piso anterior/siguiente   F4 limpiar sala" % estado
	# En rojo mientras se es invencible: probando el equilibrio, olvidarse de
	# que esta puesto da conclusiones falsas («este piso es facil»).
	_etiqueta.modulate = Color(1.0, 0.45, 0.4) if _jugador.invencible else Color(1.0, 1.0, 1.0, 0.55)
	_colocar()


func _colocar() -> void:
	_etiqueta.reset_size()
	_etiqueta.position.y = get_viewport().get_visible_rect().size.y - _etiqueta.size.y - 10.0
