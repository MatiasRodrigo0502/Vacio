## Autoload Red: la conexion del cooperativo y la sala de espera. Pedido por
## Matias el 2026-10-16: fase 1 del multijugador, en red local
## (docs/mejoras-futuras/multijugador.md).
##
## OJO: sin class_name a proposito, como Sonido y GestorProgreso: un class_name
## igual al nombre del autoload da "hides an autoload singleton".
##
## QUE HACE: crear una sala (este ordenador hace de anfitrion), entrar en la
## de otro con su codigo, la lista de quien esta y con que mago, y empezar la
## partida en todos a la vez. Lo que pasa dentro de la partida lo lleva
## Cooperativo (scripts/cooperativo.gd), que vive en Principal.
##
## POR QUE UN AUTOLOAD: la conexion tiene que seguir viva al pasar del menu a
## la partida, que son escenas distintas. Y sus llamadas por la red llegan a
## /root/Red en todos los ordenadores: esta ruta existe siempre, haya o no
## partida montada.
##
## POR QUE LA CONEXION VA APARTE DEL JUEGO: para la fase 3 (por internet) solo
## deberia cambiar como se conectan los ordenadores (aqui), no la partida.
##
## EL CODIGO DE LA SALA es la direccion del anfitrion en la red local escrita
## con 7 letras y numeros (ver codigo_de_ip). En la misma red los ordenadores
## se ven directamente, sin servidor en medio: basta con saber a quien llamar.
## Tambien se puede escribir la direccion tal cual (192.168.1.37).
##
## QUIEN MANDA EN LA SALA: el anfitrion. Los demas le piden cosas (entrar,
## elegir mago) y el reparte la lista a todos. Asi dos que eligen el mismo
## mago a la vez no se lo quedan los dos.
extends Node

## Cambia la lista de jugadores de la sala.
signal lista_cambiada
## No se ha podido entrar en una sala, o el anfitrion no te ha dejado.
signal fallo(mensaje: String)
## La sala se ha cerrado: el anfitrion se ha ido o se ha perdido la conexion.
signal sala_cerrada(mensaje: String)
## Alguien se ha ido de la sala (o de la partida).
signal jugador_salio(id: int, numero: int)
## Otro ordenador ya tiene la partida montada: ya se le puede hablar.
signal jugador_listo(id: int)

## El puerto de la sala. Uno poco usado: el mismo en todos los ordenadores.
const PUERTO: int = 24701
## Contandose a uno mismo.
const MAXIMO_JUGADORES: int = 3
## Lo que se espera a que conteste una sala antes de darla por perdida. ENet
## por su cuenta tarda casi medio minuto en rendirse.
const ESPERA_CONEXION: float = 6.0
## Las letras del codigo (base 32 de Crockford): sin I, L, O ni U, que se
## confunden con 1, 0 y V al dictarlo.
const ALFABETO := "0123456789ABCDEFGHJKMNPQRSTVWXYZ"
const ESCENA_PARTIDA := "res://scenes/Principal.tscn"
const ESCENA_MENU := "res://scenes/MenuPrincipal.tscn"

## Los de la sala: id de red -> {"numero": 1..3, "mago": indice en
## GestorProgreso.personajes, -1 si aun no ha elegido}. La reparte el anfitrion.
var jugadores: Dictionary = {}
## El codigo de la sala en la que se esta ("K7QA-2MB"). Vacio sin sala.
var codigo: String = ""
## La direccion de la red local del anfitrion, por si el codigo no sirve.
var direccion: String = ""
## Donde escucha el anfitrion. "*" son todas las redes del ordenador; las
## pruebas usan "127.0.0.1" para que Windows no pregunte por el cortafuegos.
var ip_escucha: String = "*"
## True desde que empieza la partida hasta que se vuelve al menu.
var en_partida: bool = false
## Lo que tiene que contar el menu al volver (la sala se ha cerrado...).
var mensaje_pendiente: String = ""

## Los ordenadores que ya tienen la partida montada.
var _listos: Dictionary = {}
var _estoy_listo: bool = false
var _espera: SceneTreeTimer = null


func _ready() -> void:
	multiplayer.peer_connected.connect(_al_conectar_otro)
	multiplayer.peer_disconnected.connect(_al_desconectar_otro)
	multiplayer.connected_to_server.connect(_al_entrar)
	multiplayer.connection_failed.connect(_al_fallar)
	multiplayer.server_disconnected.connect(_al_cerrarse_la_sala)


# --- Preguntas -----------------------------------------------------------

## True si este ordenador esta en una sala (como anfitrion o no).
func en_sala() -> bool:
	var peer := multiplayer.multiplayer_peer
	return peer != null and not (peer is OfflineMultiplayerPeer) \
		and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


func es_anfitrion() -> bool:
	return en_sala() and multiplayer.is_server()


## True en una partida cooperativa. Lo pregunta Principal al montarse.
func cooperativo() -> bool:
	return en_partida and en_sala()


## True en un ordenador que no crea la sala, ya en la partida. En ese, el
## mundo (los enemigos, su vida, lo que sueltan) es una copia de lo que manda
## el anfitrion: aqui solo se ensena (fase 2, ver MundoRed).
func es_espejo() -> bool:
	return cooperativo() and not multiplayer.is_server()


## True si este ordenador decide lo que pasa en el mundo: jugando solo, o
## siendo el anfitrion. Lo preguntan lo que reparte al azar (lo que sueltan
## los enemigos, los vendajes) para que no salga distinto en cada uno.
func manda() -> bool:
	return not es_espejo()


## Por cuanto se multiplica la vida de los enemigos: con mas jugadores,
## enemigos mas fuertes y no mas enemigos (Matias, 2026-10-16). La mitad mas
## por cada jugador de mas: 1,5 con dos y el doble con tres.
func factor_vida_enemigos() -> float:
	if not cooperativo():
		return 1.0
	return 1.0 + 0.5 * maxi(jugadores.size() - 1, 0)


func mi_id() -> int:
	return multiplayer.get_unique_id()


## El numero de jugador de este ordenador (1 el anfitrion).
func mi_numero() -> int:
	return int(jugadores.get(mi_id(), {}).get("numero", 1))


## El mago de un jugador, o null si aun no ha elegido.
func mago_de(id: int) -> PersonajeJugable:
	var indice := int(jugadores.get(id, {}).get("mago", -1))
	if indice < 0 or indice >= GestorProgreso.personajes.size():
		return null
	return GestorProgreso.personajes[indice]


## Quien tiene ese mago, o 0 si nadie. Cada uno elige uno distinto (Matias,
## 2026-10-16): con tres magos para tres jugadores, cada uno se distingue.
func quien_tiene(indice: int) -> int:
	for id: int in jugadores:
		if int(jugadores[id].mago) == indice:
			return id
	return 0


## Lo que falta para poder empezar, o "" si ya se puede.
func falta_para_empezar() -> String:
	if jugadores.size() < 2:
		return "Falta que entre alguien más."
	for id: int in jugadores:
		if int(jugadores[id].mago) < 0:
			return "Falta que el jugador %d elija mago." % int(jugadores[id].numero)
	return ""


## Los ordenadores a los que ya se les puede hablar dentro de la partida.
func listos() -> Array:
	return _listos.keys()


# --- Crear, entrar y salir -------------------------------------------------

## Crea una sala en este ordenador. Devuelve OK o el error de la red (el
## puerto ocupado, normalmente: otra sala abierta en el mismo ordenador).
func crear_sala() -> Error:
	salir()
	var peer := ENetMultiplayerPeer.new()
	peer.set_bind_ip(ip_escucha)
	# Un sitio de mas: al que sobra lo echa _presentarse diciendole que esta
	# llena. Sin el, la red lo cortaria antes y le saldria «no se encuentra».
	var error := peer.create_server(PUERTO, MAXIMO_JUGADORES)
	if error != OK:
		return error
	multiplayer.multiplayer_peer = peer
	direccion = ip_local()
	codigo = codigo_de_ip(direccion)
	jugadores = {1: {"numero": 1, "mago": -1}}
	lista_cambiada.emit()
	return OK


## Entra en la sala de ese codigo (o de esa direccion). Lo que pase se sabe
## por las senales: lista_cambiada al entrar, fallo si no se puede.
func unirse(texto: String) -> void:
	salir()
	var ip := ip_de_codigo(texto)
	if ip == "":
		fallo.emit("Ese código no es válido: son 7 letras y números (K7QA-2MB).")
		return
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(ip, PUERTO)
	if error != OK:
		fallo.emit("No se ha podido conectar (error %d)." % error)
		return
	multiplayer.multiplayer_peer = peer
	direccion = ip
	codigo = codigo_de_ip(ip)
	_espera = get_tree().create_timer(ESPERA_CONEXION, true, false, true)
	_espera.timeout.connect(_al_no_contestar.bind(peer))


## Cierra la conexion y olvida la sala. No avisa a nadie: los demas se
## enteran solos de que este ordenador se ha ido.
func salir() -> void:
	var peer := multiplayer.multiplayer_peer
	if peer != null and not (peer is OfflineMultiplayerPeer):
		peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	jugadores = {}
	codigo = ""
	direccion = ""
	en_partida = false
	_listos = {}
	_estoy_listo = false
	_espera = null


## Elige mago en la sala. Se lo pide al anfitrion, que es quien reparte.
func elegir_mago(indice: int) -> void:
	if not en_sala():
		return
	if es_anfitrion():
		_pedir_mago(indice)
	else:
		_pedir_mago.rpc_id(1, indice)


## Solo el anfitrion, y cuando ya se puede: empieza la partida en todos.
func empezar() -> void:
	if es_anfitrion() and falta_para_empezar() == "":
		_empezar.rpc()


## Lo llama Cooperativo cuando la partida ya esta montada en este ordenador.
func avisar_listo() -> void:
	_estoy_listo = true
	_listo.rpc()


## Vuelve al menu dejando la sala, con un mensaje para el menu si hace falta.
func volver_al_menu(mensaje: String = "") -> void:
	salir()
	mensaje_pendiente = mensaje
	get_tree().paused = false
	get_tree().change_scene_to_file(ESCENA_MENU)


# --- Lo que llega por la red ---------------------------------------------

## El que entra se presenta con su version: con versiones distintas, lo que
## se mandan no casaria (otros objetos, otras salas, otras llamadas).
@rpc("any_peer", "call_remote", "reliable")
func _presentarse(version: String) -> void:
	if not es_anfitrion():
		return
	var id := multiplayer.get_remote_sender_id()
	var mia := GestorProgreso.version_juego()
	if en_partida:
		_echar(id, "La partida de esa sala ya ha empezado.")
	elif version != mia:
		_echar(id, "Tenéis versiones distintas del juego: la sala es de la %s y tú tienes la %s." % [mia, version])
	elif jugadores.size() >= MAXIMO_JUGADORES:
		_echar(id, "La sala está llena (%d jugadores)." % MAXIMO_JUGADORES)
	else:
		jugadores[id] = {"numero": _numero_libre(), "mago": -1}
		_repartir_lista()


@rpc("authority", "call_remote", "reliable")
func _rechazado(mensaje: String) -> void:
	# Diferido: cerrar la conexion en mitad de leer lo que llega de ella
	# deja a la red a medias.
	salir.call_deferred()
	fallo.emit(mensaje)


@rpc("any_peer", "call_remote", "reliable")
func _pedir_mago(indice: int) -> void:
	if not es_anfitrion():
		return
	var id := multiplayer.get_remote_sender_id()
	if id == 0:
		id = 1
	if not jugadores.has(id) or indice < 0 or indice >= GestorProgreso.personajes.size():
		return
	var otro := quien_tiene(indice)
	if otro != 0 and otro != id:
		# Ya es de otro: se le vuelve a mandar la lista, que es lo que le
		# dice que no.
		_repartir_lista()
		return
	jugadores[id].mago = indice
	_repartir_lista()


@rpc("authority", "call_remote", "reliable")
func _lista(datos: Dictionary) -> void:
	jugadores = datos
	lista_cambiada.emit()


@rpc("authority", "call_local", "reliable")
func _empezar() -> void:
	var mago := mago_de(mi_id())
	if mago == null:
		return
	en_partida = true
	_listos = {}
	_estoy_listo = false
	GestorProgreso.elegir_personaje(mago)
	get_tree().paused = false
	get_tree().change_scene_to_file(ESCENA_PARTIDA)


## Otro ordenador ya tiene la partida montada. Se le contesta si este tambien
## la tiene: si no, el que llego antes no sabria nunca del que llego despues.
@rpc("any_peer", "call_remote", "reliable")
func _listo() -> void:
	var id := multiplayer.get_remote_sender_id()
	var nuevo := not _listos.has(id)
	_listos[id] = true
	if nuevo:
		jugador_listo.emit(id)
		if _estoy_listo:
			_listo.rpc_id(id)


# --- Senales de la conexion -----------------------------------------------

func _al_entrar() -> void:
	_espera = null
	_presentarse.rpc_id(1, GestorProgreso.version_juego())


func _al_fallar() -> void:
	salir()
	fallo.emit("No se encuentra la sala. ¿Estáis en la misma red?")


func _al_no_contestar(peer: MultiplayerPeer) -> void:
	# Solo si sigue siendo el mismo intento y no ha entrado.
	if multiplayer.multiplayer_peer == peer and not en_sala():
		salir()
		fallo.emit("No contesta nadie con ese código. ¿Estáis en la misma red y la sala sigue abierta?")


func _al_conectar_otro(_id: int) -> void:
	# Nada hasta que se presente: puede venir con otra version.
	pass


func _al_desconectar_otro(id: int) -> void:
	_listos.erase(id)
	if not jugadores.has(id):
		return
	var numero := int(jugadores[id].numero)
	jugadores.erase(id)
	jugador_salio.emit(id, numero)
	lista_cambiada.emit()
	if es_anfitrion():
		_repartir_lista()


func _al_cerrarse_la_sala() -> void:
	var estaba_jugando := en_partida
	salir()
	var mensaje := "El jugador 1 ha cerrado la sala."
	if estaba_jugando:
		volver_al_menu(mensaje)
	else:
		sala_cerrada.emit(mensaje)


# --- Ayudas ----------------------------------------------------------------

func _repartir_lista() -> void:
	_lista.rpc(jugadores)
	lista_cambiada.emit()


func _numero_libre() -> int:
	var usados := []
	for id: int in jugadores:
		usados.append(int(jugadores[id].numero))
	for numero in range(1, MAXIMO_JUGADORES + 1):
		if not numero in usados:
			return numero
	return MAXIMO_JUGADORES


func _echar(id: int, mensaje: String) -> void:
	_rechazado.rpc_id(id, mensaje)
	# Sin forzar: primero sale el mensaje, luego se corta.
	(multiplayer.multiplayer_peer as ENetMultiplayerPeer).get_peer(id).peer_disconnect_later()


## La direccion de este ordenador en la red local. Entre varias (cable, wifi,
## maquinas virtuales), la de una red de casa o de clase: 192.168, 10 o 172.16
## a 172.31. Sin ninguna, la del propio ordenador, que solo sirve para probar
## con dos ventanas.
static func ip_local() -> String:
	var mejor := ""
	var nota_mejor := 0
	for ip: String in IP.get_local_addresses():
		var nota := 0
		if ip.begins_with("192.168."):
			nota = 3
		elif ip.begins_with("10."):
			nota = 2
		elif ip.begins_with("172."):
			var segundo := ip.get_slice(".", 1).to_int()
			if segundo >= 16 and segundo <= 31:
				nota = 1
		if nota > nota_mejor:
			mejor = ip
			nota_mejor = nota
	return mejor if mejor != "" else "127.0.0.1"


## 192.168.1.37 -> "60L8-0X5". Los 4 numeros de la direccion son 32 bits, y
## 7 letras de 32 son 35: caben con sitio.
static func codigo_de_ip(ip: String) -> String:
	var partes := ip.split(".")
	if partes.size() != 4:
		return ""
	var valor := 0
	for parte in partes:
		valor = valor * 256 + clampi(parte.to_int(), 0, 255)
	var letras := ""
	for i in 7:
		letras = ALFABETO[valor % 32] + letras
		valor = valor / 32
	return letras.substr(0, 4) + "-" + letras.substr(4)


## Lo contrario: del codigo a la direccion. Admite tambien la direccion tal
## cual. "" si no es ni lo uno ni lo otro.
static func ip_de_codigo(texto: String) -> String:
	var limpio := texto.strip_edges().to_upper()
	if limpio == "LOCALHOST":
		return "127.0.0.1"
	if limpio.count(".") == 3 and limpio.is_valid_ip_address():
		return limpio
	limpio = limpio.replace("-", "").replace(" ", "")
	# Lo que se confunde al dictarlo, como en Crockford.
	limpio = limpio.replace("O", "0").replace("I", "1").replace("L", "1")
	if limpio.length() != 7:
		return ""
	var valor := 0
	for letra in limpio:
		var cifra := ALFABETO.find(letra)
		if cifra < 0:
			return ""
		valor = valor * 32 + cifra
	if valor > 0xFFFFFFFF:
		return ""
	return "%d.%d.%d.%d" % [(valor >> 24) & 255, (valor >> 16) & 255, (valor >> 8) & 255, valor & 255]
