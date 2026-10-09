## Autoload Sonido: los efectos y la musica de todo el juego.
##
## OJO: este script NO declara class_name a proposito, como GestorProgreso: un
## class_name igual al nombre del autoload da "hides an autoload singleton".
##
## POR QUE UN AUTOLOAD:
## suenan cosas desde todas partes (el jugador, los enemigos, las salas, los
## menus), y la musica tiene que seguir sonando cuando se pasa del menu al
## juego, que son escenas distintas. Un nodo que vive siempre lo resuelve:
## cada sitio dice Sonido.tocar(&"golpe_enemigo") y ya.
##
## POR QUE LOS EFECTOS SE BUSCAN POR NOMBRE DE ARCHIVO:
## todo lo que haya en assets/sonido/efectos/ se puede tocar por su nombre,
## sin una lista que mantener. Un efecto nuevo es un .wav mas (lo hace
## herramientas/generar_efectos.py) y una llamada donde tenga que sonar.
##
## Todo el sonido es nuestro: lo generan herramientas/generar_efectos.py y
## generar_musica.py, por sintesis, sin nada bajado.
extends Node

const RUTA_EFECTOS := "res://assets/sonido/efectos"
const RUTA_MUSICA := "res://assets/sonido/musica"
## Los buses estan en default_bus_layout.tres. Por ellos van los dos
## volumenes del menu de pausa.
const BUS_MUSICA := &"Musica"
const BUS_EFECTOS := &"Efectos"
const ARCHIVO_AJUSTES := "user://ajustes.cfg"

## Efectos sonando a la vez como mucho. Pasado esto, el nuevo corta al mas
## viejo en vez de amontonarse (con F4 mueren veinte enemigos de golpe).
const VOCES: int = 16
## El mismo efecto dos veces en menos de esto suena como uno, mas fuerte, y
## satura: la segunda no se toca. Pasa al reventar varios slimes a la vez.
const SEPARACION_MINIMA_MS: int = 30
## Cuanto cambia el tono de un efecto a otro, al azar. Sin esto, el disparo
## repetido cada medio segundo suena a maquina.
const VARIACION_TONO: float = 0.05
## Lo que tarda una musica en dar paso a otra.
const FUNDIDO: float = 1.5
const FUNDIDO_CORTO: float = 0.3

## Lo que se espera al salir del juego con todo parado (ver salir()).
const ESPERA_AL_SALIR: float = 0.2

const VOLUMEN_MUSICA_INICIAL: float = 0.6
const VOLUMEN_EFECTOS_INICIAL: float = 0.8

## De 0 a 1. Se guardan en user://ajustes.cfg y se recuerdan.
var volumen_musica: float = VOLUMEN_MUSICA_INICIAL:
	set = _poner_volumen_musica
var volumen_efectos: float = VOLUMEN_EFECTOS_INICIAL:
	set = _poner_volumen_efectos

var _efectos: Dictionary = {}
var _ultima_vez: Dictionary = {}
var _avisados: Dictionary = {}
var _voces: Array[AudioStreamPlayer] = []
var _siguiente_voz: int = 0
## Dos reproductores de musica, para fundir una con otra: la que entra y la
## que sale.
var _musica: AudioStreamPlayer
var _musica_saliente: AudioStreamPlayer
var _fundido: Tween = null
var _guardado: Timer
var _saliendo: bool = false
## Sin pantalla (la prueba de arranque de la release, las pruebas del equipo)
## no hay quien oiga la musica: se elige, pero no se reproduce. Ademas asi no
## sale el aviso del motor al cerrar (ver salir()), que ahi no se puede
## esquivar: esas pruebas cierran el juego de golpe, sin pasar por salir().
var _sin_altavoces: bool = false


func _ready() -> void:
	# Sigue sonando con el juego en pausa: la musica no se corta y los botones
	# del menu de pausa hacen clic.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_sin_altavoces = DisplayServer.get_name() == "headless"
	# Cerrar la ventana pasa por salir(), para parar el sonido antes.
	get_tree().auto_accept_quit = false
	_asegurar_bus(BUS_MUSICA)
	_asegurar_bus(BUS_EFECTOS)
	_cargar_efectos()
	for i in VOCES:
		var voz := AudioStreamPlayer.new()
		voz.bus = BUS_EFECTOS
		add_child(voz)
		_voces.append(voz)
	_musica = _reproductor_musica()
	_musica_saliente = _reproductor_musica()
	# Guardar los volumenes un momento despues de tocarlos, no en cada paso de
	# la barra mientras se arrastra.
	_guardado = Timer.new()
	_guardado.one_shot = true
	_guardado.wait_time = 0.5
	_guardado.timeout.connect(_guardar_ajustes)
	add_child(_guardado)
	_cargar_ajustes()
	# Todos los botones del juego hacen clic al pulsarlos, sin que cada menu
	# tenga que acordarse.
	get_tree().node_added.connect(_al_anadir_nodo)


## Cierra el juego: para todo el sonido, deja pasar un momento y sale. Lo
## usan el boton "Salir" del menu y cerrar la ventana (ver _notification).
##
## POR QUE NO SALIR DIRECTAMENTE: si se cierra con una musica en bucle
## sonando, Godot no llega a soltarla y avisa al salir ("1 resources still in
## use at exit"). Parar no basta: la cancion parada la suelta el bucle del
## juego en su siguiente fotograma, y al cerrar ya no hay mas fotogramas.
## Comprobado con una escena de un solo reproductor, sin nada de esto: es del
## motor. Esperar dentro del cierre (OS.delay_msec) tampoco sirve, por eso.
func salir() -> void:
	if _saliendo:
		return
	_saliendo = true
	for reproductor in _voces + [_musica, _musica_saliente]:
		reproductor.stop()
	await get_tree().create_timer(ESPERA_AL_SALIR, true, false, true).timeout
	get_tree().quit()


func _notification(que: int) -> void:
	if que == NOTIFICATION_WM_CLOSE_REQUEST:
		salir()


## Toca un efecto por su nombre (el del archivo, sin .wav).
func tocar(nombre: StringName) -> void:
	var sonido: AudioStream = _efectos.get(nombre)
	if sonido == null:
		# Una vez por nombre: un efecto que falta no tiene que llenar la
		# consola a cada disparo.
		if not _avisados.has(nombre):
			_avisados[nombre] = true
			push_warning("No hay ningun efecto llamado '%s' en %s." % [nombre, RUTA_EFECTOS])
		return
	var ahora := Time.get_ticks_msec()
	if ahora - int(_ultima_vez.get(nombre, -100000)) < SEPARACION_MINIMA_MS:
		return
	_ultima_vez[nombre] = ahora
	var voz := _voz_libre()
	voz.stream = sonido
	voz.pitch_scale = 1.0 + randf_range(-VARIACION_TONO, VARIACION_TONO)
	voz.play()


## Pone una musica, fundiendose con la que suene. Si ya es esa, no hace nada:
## al pasar de piso con la misma musica sigue sin cortarse.
func poner_musica(musica: AudioStream, segundos: float = FUNDIDO) -> void:
	if musica == null:
		parar_musica()
		return
	if _musica.stream == musica and (_musica.playing or _sin_altavoces):
		return
	var sale := _musica
	_musica = _musica_saliente
	_musica_saliente = sale
	_musica.stream = musica
	_musica.volume_db = linear_to_db(0.001)
	if not _sin_altavoces:
		_musica.play()
	_fundir(segundos)


## La musica de victoria o derrota: corta la que haya y suena una vez.
func tocar_final(nombre: StringName) -> void:
	var ruta := RUTA_MUSICA.path_join(String(nombre) + ".wav")
	if not ResourceLoader.exists(ruta):
		push_warning("No existe la musica %s." % ruta)
		return
	poner_musica(load(ruta), FUNDIDO_CORTO)


func parar_musica() -> void:
	var sale := _musica
	_musica = _musica_saliente
	_musica_saliente = sale
	_musica.stop()
	_musica.stream = null
	_fundir(FUNDIDO_CORTO)


func _fundir(segundos: float) -> void:
	if _fundido != null and _fundido.is_valid():
		_fundido.kill()
	var entra := _musica
	var sale := _musica_saliente
	var volumen_salida := db_to_linear(sale.volume_db) if sale.playing else 0.0
	# Sin nada sonando (sin altavoces, o parando lo que ya estaba parado) no
	# hay nada que fundir, y un Tween vacio es un error del motor.
	if not entra.playing and volumen_salida <= 0.0:
		return
	_fundido = create_tween().set_parallel()
	# En lineal y no en dB: un fundido en dB se queda casi en silencio la
	# mitad del tiempo y luego entra de golpe.
	if entra.playing:
		_fundido.tween_method(func(v: float) -> void: entra.volume_db = linear_to_db(maxf(v, 0.001)),
			0.0, 1.0, segundos)
	if volumen_salida > 0.0:
		_fundido.tween_method(func(v: float) -> void: sale.volume_db = linear_to_db(maxf(v, 0.001)),
			volumen_salida, 0.0, segundos)
		_fundido.chain().tween_callback(sale.stop)


func _reproductor_musica() -> AudioStreamPlayer:
	var reproductor := AudioStreamPlayer.new()
	reproductor.bus = BUS_MUSICA
	add_child(reproductor)
	return reproductor


## Una voz que no este sonando; si suenan todas, la siguiente en la rueda,
## que es la que mas tiempo lleva.
func _voz_libre() -> AudioStreamPlayer:
	for i in VOCES:
		var voz := _voces[(_siguiente_voz + i) % VOCES]
		if not voz.playing:
			_siguiente_voz = (_siguiente_voz + i + 1) % VOCES
			return voz
	var vieja := _voces[_siguiente_voz]
	_siguiente_voz = (_siguiente_voz + 1) % VOCES
	return vieja


func _al_anadir_nodo(nodo: Node) -> void:
	if nodo is BaseButton:
		nodo.pressed.connect(tocar.bind(&"clic"))


# --- Volumen --------------------------------------------------------------------

func _poner_volumen_musica(valor: float) -> void:
	volumen_musica = clampf(valor, 0.0, 1.0)
	_aplicar(BUS_MUSICA, volumen_musica)


func _poner_volumen_efectos(valor: float) -> void:
	volumen_efectos = clampf(valor, 0.0, 1.0)
	_aplicar(BUS_EFECTOS, volumen_efectos)


func _aplicar(bus: StringName, valor: float) -> void:
	var indice := AudioServer.get_bus_index(bus)
	if indice < 0:
		return
	# A cero, silencio de verdad: linear_to_db(0) es -infinito.
	AudioServer.set_bus_mute(indice, valor <= 0.001)
	AudioServer.set_bus_volume_db(indice, linear_to_db(maxf(valor, 0.001)))
	if is_instance_valid(_guardado) and _guardado.is_inside_tree():
		_guardado.start()


func _cargar_ajustes() -> void:
	var ajustes := ConfigFile.new()
	# Si no hay archivo (la primera vez), se quedan los de fabrica.
	ajustes.load(ARCHIVO_AJUSTES)
	volumen_musica = ajustes.get_value("sonido", "musica", VOLUMEN_MUSICA_INICIAL)
	volumen_efectos = ajustes.get_value("sonido", "efectos", VOLUMEN_EFECTOS_INICIAL)


func _guardar_ajustes() -> void:
	var ajustes := ConfigFile.new()
	ajustes.load(ARCHIVO_AJUSTES)
	ajustes.set_value("sonido", "musica", volumen_musica)
	ajustes.set_value("sonido", "efectos", volumen_efectos)
	ajustes.save(ARCHIVO_AJUSTES)


## Por si default_bus_layout.tres faltara: sin el bus, el sonido iria al
## Master y los volumenes no harian nada, pero sonaria igual.
func _asegurar_bus(nombre: StringName) -> void:
	if AudioServer.get_bus_index(nombre) >= 0:
		return
	AudioServer.add_bus()
	var indice := AudioServer.bus_count - 1
	AudioServer.set_bus_name(indice, nombre)
	AudioServer.set_bus_send(indice, &"Master")


# --- Carga ------------------------------------------------------------------------

func _cargar_efectos() -> void:
	for nombre in _listar(RUTA_EFECTOS):
		var sonido := load(RUTA_EFECTOS.path_join(nombre)) as AudioStream
		if sonido != null:
			_efectos[StringName(nombre.get_basename())] = sonido


## Los sonidos de una carpeta. En el .exe exportado el .wav no esta tal cual:
## esta su ".import" (el sonido ya convertido va aparte), asi que se quita
## ese sufijo, igual que GestorProgreso hace con los ".remap" de los .tres.
func _listar(carpeta: String) -> PackedStringArray:
	var nombres := PackedStringArray()
	var dir := DirAccess.open(carpeta)
	if dir == null:
		push_warning("No se ha podido abrir la carpeta %s" % carpeta)
		return nombres
	for archivo in dir.get_files():
		var limpio := archivo.trim_suffix(".import").trim_suffix(".remap")
		if limpio.get_extension().to_lower() in ["wav", "ogg", "mp3"] and not nombres.has(limpio):
			nombres.append(limpio)
	nombres.sort()
	return nombres
