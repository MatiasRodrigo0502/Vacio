## Autoload Estadisticas: los FPS, el rendimiento, la partida y el ping,
## encima de todo. Pedido por Matias el 2026-11-03: «ver los FPS y
## estadisticas, asi como el ping en el modo multijugador; que quede como el
## F3 de Minecraft o las funciones de HUD de Fortnite».
##
## Tres modos, que F3 va pasando y que tambien se eligen en el panel de
## controles del menu y en la pausa (boton()):
## - No: nada.
## - FPS y ping: una linea arriba a la derecha, encima del minimapa, como el
##   HUD de Fortnite. El ping solo en cooperativo.
## - Todas: una columna a la derecha, debajo del minimapa, como el F3 de
##   Minecraft: rendimiento, partida y red, cada linea con su fondo oscuro
##   para que se lea encima de cualquier cosa.
## Se guarda en user://ajustes.cfg, como lo demas.
##
## OJO: sin class_name a proposito, como Controles y Sonido: un class_name
## igual al nombre del autoload da "hides an autoload singleton".
##
## POR QUE UN AUTOLOAD: tiene que verse en el menu y en la partida, y seguir
## contando en la pausa. Lo de la partida lo busca el mismo en la escena que
## haya (Principal), sin que la partida sepa que existe.
##
## EL PING es el que mide la propia conexion (ENet: lo que tarda un paquete
## en ir y volver, de media). Cada ordenador solo habla con el anfitrion: el
## anfitrion ve el de cada uno de los demas, y los demas, el suyo con el.
extends CanvasLayer

## Ha cambiado el modo. Lo escuchan las listas del menu y de la pausa, para
## seguir a la otra y a F3. Lleva el modo para poder conectarle el metodo de
## la lista tal cual (OptionButton.select): una conexion a un metodo se quita
## sola al liberarse la lista; una funcion anonima que la guardara no, y al
## volver de la partida al menu daba error («Lambda capture was freed»).
signal cambiado(modo: int)

enum Modo { NADA, BASICO, COMPLETO }
const NOMBRES: Array[String] = ["No", "FPS y ping", "Todas"]

const ARCHIVO_AJUSTES := "user://ajustes.cfg"
## Cada cuanto se reescribe: cada fotograma cuesta y no da tiempo a leerlo.
const REFRESCO: float = 0.25
## El peor fotograma que se ensena es el de este ultimo rato.
const VENTANA_PEOR: float = 1.0
const TAMANO_LETRA: int = 14
const ALTO_LINEA: float = 19.0
## Debajo del minimapa del HUD (que acaba a 152) y a su mismo margen.
const ARRIBA_COMPLETO: float = 166.0
const MARGEN: float = 18.0
const COLOR_TEXTO := Color(0.93, 0.92, 0.88)
const COLOR_TITULO := Color(1.0, 0.8, 0.4)
const COLOR_BIEN := Color(0.55, 0.95, 0.5)
const COLOR_REGULAR := Color(1.0, 0.85, 0.35)
const COLOR_MAL := Color(1.0, 0.42, 0.38)
const COLOR_FONDO := Color(0.0, 0.0, 0.0, 0.55)

var modo: int = Modo.NADA

## Lo que se pinta: [texto, color] por linea.
var _lineas: Array = []
var _reloj: float = 0.0
var _peor: float = 0.0
var _peor_ahora: float = 0.0
var _reloj_peor: float = 0.0
var _lienzo: Control


func _ready() -> void:
	# Por encima de todo: el HUD (1), la pantalla final (3) y la pausa (4).
	layer = 50
	# Sigue contando en la pausa y en las ventanas del tutorial.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_lienzo = Control.new()
	_lienzo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lienzo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lienzo.draw.connect(_pintar)
	add_child(_lienzo)
	var ajustes := ConfigFile.new()
	ajustes.load(ARCHIVO_AJUSTES)
	modo = clampi(int(ajustes.get_value("pantalla", "estadisticas", Modo.NADA)), 0, NOMBRES.size() - 1)
	_aplicar()


func elegir(nuevo: int) -> void:
	nuevo = posmod(nuevo, NOMBRES.size())
	if nuevo == modo:
		return
	modo = nuevo
	_aplicar()
	var ajustes := ConfigFile.new()
	ajustes.load(ARCHIVO_AJUSTES)
	ajustes.set_value("pantalla", "estadisticas", modo)
	ajustes.save(ARCHIVO_AJUSTES)
	cambiado.emit(modo)


## La eleccion del modo, igual en el panel de controles del menu y en la
## pausa: se crea aqui para que las dos sean la misma, como el disparo
## automatico (Controles.boton_disparo_automatico).
func boton() -> HBoxContainer:
	var fila := HBoxContainer.new()
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	fila.add_theme_constant_override("separation", 8)
	fila.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var etiqueta := Label.new()
	etiqueta.text = "Estadísticas (F3):"
	etiqueta.add_theme_font_size_override("font_size", 18)
	fila.add_child(etiqueta)
	var lista := OptionButton.new()
	for nombre in NOMBRES:
		lista.add_item(nombre)
	lista.add_theme_font_size_override("font_size", 18)
	lista.tooltip_text = "Los FPS (y el ping en cooperativo), o todo: rendimiento, partida y red"
	lista.selected = modo
	lista.item_selected.connect(elegir)
	cambiado.connect(lista.select)
	fila.add_child(lista)
	return fila


# En _input y no en _unhandled_input, como F11: un boton con el foco no deja
# pasar las teclas, y F3 tiene que ir tambien en los menus.
func _input(evento: InputEvent) -> void:
	var tecla := evento as InputEventKey
	if tecla == null or not tecla.pressed or tecla.echo or tecla.keycode != KEY_F3:
		return
	get_viewport().set_input_as_handled()
	elegir(modo + 1)


func _aplicar() -> void:
	visible = modo != Modo.NADA
	_reloj = 0.0
	_actualizar()


func _process(delta: float) -> void:
	if modo == Modo.NADA:
		return
	# El peor fotograma del ultimo segundo: los FPS son una media, y un tiron
	# suelto no se ve en ellos.
	_peor_ahora = maxf(_peor_ahora, delta)
	_reloj_peor += delta
	if _reloj_peor >= VENTANA_PEOR:
		_peor = _peor_ahora
		_peor_ahora = 0.0
		_reloj_peor = 0.0
	_reloj -= delta
	if _reloj <= 0.0:
		_reloj = REFRESCO
		_actualizar()


func _actualizar() -> void:
	_lineas.clear()
	if modo == Modo.BASICO:
		var linea := "%d FPS" % Engine.get_frames_per_second()
		var ping := _ping_resumen()
		if ping != "":
			linea += "  ·  " + ping
		_lineas.append([linea, _color_fps(Engine.get_frames_per_second())])
	elif modo == Modo.COMPLETO:
		_lineas_rendimiento()
		_lineas_partida()
		_lineas_red()
	_lienzo.queue_redraw()


func _lineas_rendimiento() -> void:
	var fps := Engine.get_frames_per_second()
	_titulo("Vacío %s" % GestorProgreso.version_juego())
	_linea("%d FPS" % fps, _color_fps(fps))
	# TIME_PROCESS es el fotograma entero (con la espera del VSync), no solo
	# los scripts: por eso se llama asi.
	_linea("Fotograma %s ms (el peor, %s)  ·  física %s ms" % [
		_dec(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0),
		_dec(maxf(_peor, _peor_ahora) * 1000.0),
		_dec(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)])
	_linea("Dibujado: %d llamadas, %d objetos" % [
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)])
	_linea("Nodos %d  ·  memoria %.0f MB" % [
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0])
	var ventana := DisplayServer.window_get_size()
	var sincronia := DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED
	_linea("Ventana %d × %d  ·  VSync %s" % [ventana.x, ventana.y, "sí" if sincronia else "no"])


## Lo de la partida, si hay una. Se llega por el jugador: su padre es
## Principal, que lleva el piso. (No por la escena actual: las pruebas montan
## Principal dentro de la suya.)
func _lineas_partida() -> void:
	var jugador := get_tree().get_first_node_in_group("jugador") as Jugador
	if jugador == null or not ("_piso_actual" in jugador.get_parent()):
		return
	var piso: Piso = jugador.get_parent().get("_piso_actual")
	if piso == null or not is_instance_valid(piso):
		return
	_titulo("Partida")
	var mago := jugador.mago.nombre if jugador.mago != null else "?"
	_linea("%s  ·  vida %d / %d" % [mago, jugador.vida_actual, jugador.vida_maxima])
	_linea("Piso %d / %d: %s" % [GestorProgreso.piso_actual, GestorProgreso.total_pisos(),
		piso.datos.nombre_capa if piso.datos != null else "?"])
	var sala := piso.sala_actual()
	var vivos := 0
	for otra in piso.salas():
		vivos += otra.enemigos_vivos()
	if sala != null:
		_linea("Sala (%d, %d) %s  ·  %d salas" % [sala.celda.x, sala.celda.y,
			MapaSalas.Tipo.keys()[sala.tipo].to_lower(), piso.salas().size()])
		_linea("Enemigos: %d en la sala, %d en el piso" % [sala.enemigos_vivos(), vivos])
	var posicion := jugador.global_position
	_linea("Posición %.0f, %.0f  ·  velocidad %.0f" % [posicion.x, posicion.y, jugador.velocity.length()])
	var disparos := 0
	for hijo in piso.get_children():
		if hijo is BolaMagica or hijo is BolaVenenosa:
			disparos += 1
	_linea("Disparos tuyos en el aire: %d  ·  uno cada %s s" % [disparos,
		_dec(jugador.cadencia_disparo, 3)])


## El ping: en el anfitrion, el de cada uno de los demas; en los demas, el
## suyo con el anfitrion. Con la perdida de paquetes, que es lo que de
## verdad se nota.
func _lineas_red() -> void:
	if not Red.en_sala():
		return
	_titulo("Red  ·  " + ("anfitrión" if Red.es_anfitrion() else "jugador %d" % Red.mi_numero()))
	_linea("%d jugadores en la sala" % Red.jugadores.size())
	for id: int in _otros():
		var conexion := _conexion(id)
		if conexion == null:
			continue
		var ms := int(conexion.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME))
		var perdida := conexion.get_statistic(ENetPacketPeer.PEER_PACKET_LOSS) \
			/ float(ENetPacketPeer.PACKET_LOSS_SCALE) * 100.0
		_linea("%s: %d ms  ·  pérdida %s %%" % [_quien(id), ms, _dec(perdida)], _color_ping(ms))


## Para el modo de una linea: el ping con el anfitrion, o el peor de los
## demas si este es el anfitrion. Vacio si no se juega en red.
func _ping_resumen() -> String:
	if not Red.en_sala():
		return ""
	var peor := -1
	for id: int in _otros():
		var conexion := _conexion(id)
		if conexion != null:
			peor = maxi(peor, int(conexion.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME)))
	return "" if peor < 0 else "%d ms" % peor


## Con quien habla este ordenador: el anfitrion con todos; los demas, solo
## con el anfitrion (id 1).
func _otros() -> Array[int]:
	var otros: Array[int] = []
	if Red.es_anfitrion():
		for id: int in Red.jugadores:
			if id != Red.mi_id():
				otros.append(id)
	else:
		otros.append(1)
	return otros


func _conexion(id: int) -> ENetPacketPeer:
	var red := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if red == null:
		return null
	return red.get_peer(id)


func _quien(id: int) -> String:
	var numero := int(Red.jugadores.get(id, {}).get("numero", 0))
	var mago := Red.mago_de(id)
	var texto := "Anfitrión" if id == 1 else "Jugador %d" % numero
	return texto + (" (%s)" % mago.nombre if mago != null else "")


## Un numero con decimales, con coma, como en el resto del juego.
func _dec(valor: float, decimales: int = 1) -> String:
	return String.num(valor, decimales).replace(".", ",") if decimales > 0 else str(roundi(valor))


func _titulo(texto: String) -> void:
	_lineas.append([texto, COLOR_TITULO])


func _linea(texto: String, color: Color = COLOR_TEXTO) -> void:
	_lineas.append(["  " + texto, color])


func _color_fps(fps: float) -> Color:
	if fps >= 55.0:
		return COLOR_BIEN
	return COLOR_REGULAR if fps >= 30.0 else COLOR_MAL


func _color_ping(ms: int) -> Color:
	if ms <= 60:
		return COLOR_BIEN
	return COLOR_REGULAR if ms <= 150 else COLOR_MAL


## Cada linea con su fondo oscuro, del ancho de su texto: se lee encima de
## cualquier cosa y tapa lo menos posible (como el F3 de Minecraft).
func _pintar() -> void:
	var fuente := ThemeDB.fallback_font
	var ancho_pantalla := _lienzo.size.x
	# La linea sola, arriba del todo y a la derecha, encima del minimapa (que
	# empieza a 18): en el centro tapaba los titulos de los menus.
	var y := 0.0 if modo == Modo.BASICO else ARRIBA_COMPLETO
	for linea in _lineas:
		var texto: String = linea[0]
		var ancho := fuente.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, TAMANO_LETRA).x
		var x := ancho_pantalla - MARGEN - ancho
		_lienzo.draw_rect(Rect2(x - 5.0, y, ancho + 10.0, ALTO_LINEA), COLOR_FONDO)
		_lienzo.draw_string(fuente, Vector2(x, y + ALTO_LINEA - 5.0), texto,
			HORIZONTAL_ALIGNMENT_LEFT, -1, TAMANO_LETRA, linea[1])
		y += ALTO_LINEA
