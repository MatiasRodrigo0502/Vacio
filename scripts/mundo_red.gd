## El mundo de la partida en cooperativo: los enemigos, sus disparos y lo que
## crean (charcos, ondas, el pozo y el fuego del jefe, lo que sueltan). Fase 2
## del multijugador (Matias, 2026-10-16). Lo crea Cooperativo; jugando solo no
## existe (MundoRed.actual es null) y todo lo de aqui hace lo de siempre.
##
## EL ANFITRION MANDA EN EL MUNDO: sus enemigos piensan, se mueven, pierden
## vida, mueren y sueltan cosas. Unas 20 veces por segundo manda como estan
## los que estan despiertos, y en los demas ordenadores esos enemigos son un
## espejo que se pone igual (Enemigo.aplicar_red). Lo que pasa de golpe
## (nacer una cria, morir, un golpe, un disparo, un charco) se avisa al
## momento.
##
## CADA UNO DECIDE LO QUE LE DA A EL: los disparos, charcos, ondas y
## explosiones se crean en todos los ordenadores, y cada copia solo hace dano
## al jugador de su ordenador. Asi, si en tu pantalla lo esquivas, lo has
## esquivado: no hay golpes que llegan de un sitio donde ya no estabas.
##
## LAS BOLAS DE LOS MAGOS DAN EN EL ANFITRION: alli estan los enemigos de
## verdad. En los demas, todas las bolas (las propias tambien) solo se ven
## (BolaMagica.solo_ver). El agujero negro del mago oscuro, igual.
##
## Las funciones estaticas (crear_lava, crear_onda...) son las que usa el
## juego para crear esas cosas: las crean aqui y, si este es el anfitrion,
## tambien en los demas. Jugando solo, solo aqui.
class_name MundoRed
extends Node

## El de la partida en marcha, o null jugando solo.
static var actual: MundoRed = null

## Cada cuanto se manda como estan los enemigos despiertos.
const CADA: float = 0.05
## Distancia maxima para reconocer en otro ordenador algo que no tiene nombre
## de red (un pilar), por donde esta.
const MISMO_SITIO: float = 4.0

## Devuelve el piso montado (lo pone Principal).
var _piso: Callable
var _reloj: float = 0.0
## Las salas que se mandaron la ultima vez: si se duermen, se mandan una vez
## mas, para que el espejo se quede como el anfitrion las ha dejado.
var _salas_enviadas: Array[Sala] = []
## id_red -> Enemigo, en este ordenador.
var _enemigos: Dictionary = {}
## id_red -> ProyectilEnemigo.
var _proyectiles: Dictionary = {}
var _siguiente_proyectil: int = 0


func _init(piso: Callable) -> void:
	_piso = piso
	name = "MundoRed"


func _enter_tree() -> void:
	actual = self


func _exit_tree() -> void:
	if actual == self:
		actual = null


## Al montar otro piso: lo de antes ya no existe.
func nuevo_piso() -> void:
	_enemigos.clear()
	_proyectiles.clear()
	_salas_enviadas.clear()


# --- Lo que manda el anfitrion -------------------------------------------------

func _physics_process(delta: float) -> void:
	if not _difunde():
		return
	_reloj += delta
	if _reloj < CADA:
		return
	_reloj = 0.0
	var piso: Piso = _piso.call()
	if piso == null:
		return
	var salas: Array[Sala] = []
	for sala in piso.salas():
		for enemigo in sala.enemigos():
			if is_instance_valid(enemigo) and enemigo.esta_despierto():
				salas.append(sala)
				break
	var lista: Array = []
	for sala in salas + _salas_enviadas.filter(func(s: Sala) -> bool:
			return is_instance_valid(s) and not s in salas):
		for enemigo in sala.enemigos():
			if is_instance_valid(enemigo) and enemigo.tipo != null:
				lista.append(enemigo.estado_red())
	_salas_enviadas = salas
	if lista.is_empty():
		return
	for id: int in Red.listos():
		_enemigos_red.rpc_id(id, lista)


static func _difunde() -> bool:
	return actual != null and Red.cooperativo() and Red.es_anfitrion()


static func _en_red() -> bool:
	return actual != null and Red.cooperativo()


static func anunciar_herido(enemigo: Enemigo, cantidad: float, estilo: NumeroDano.Estilo) -> void:
	if _difunde():
		for id: int in Red.listos():
			actual._herido.rpc_id(id, enemigo.id_red, cantidad, estilo)


static func anunciar_muerte(enemigo: Enemigo) -> void:
	if _difunde():
		actual._enemigos.erase(enemigo.id_red)
		for id: int in Red.listos():
			actual._muerto.rpc_id(id, enemigo.id_red)


## La cria no tiene .tres propio: su tipo sale del de la madre
## (TipoEnemigo.cria), asi que se manda el de la madre y alli se saca igual.
static func anunciar_cria(cria: Enemigo, madre: TipoEnemigo) -> void:
	if not _difunde() or cria.sala() == null:
		return
	actual._enemigos[cria.id_red] = cria
	for id: int in Red.listos():
		actual._nacer.rpc_id(id, cria.id_red, madre.resource_path, cria.global_position,
			cria.sala().celda)


static func anunciar_proyectil(proyectil: ProyectilEnemigo) -> void:
	if not _difunde():
		return
	var sala := proyectil.get_parent() as Sala
	if sala == null:
		return
	proyectil.id_red = actual._siguiente_proyectil
	actual._siguiente_proyectil += 1
	actual._proyectiles[proyectil.id_red] = proyectil
	for id: int in Red.listos():
		actual._proyectil.rpc_id(id, proyectil.id_red, proyectil.tipo.resource_path,
			proyectil._origen, proyectil.direccion, proyectil._destino, proyectil.limite,
			proyectil.autor, sala.celda)


static func anunciar_sonido(nombre: StringName) -> void:
	if _difunde():
		for id: int in Red.listos():
			actual._sonido.rpc_id(id, nombre)


## Desde cualquier ordenador: un disparo enemigo ha rebotado en el escudo
## del jugador de este.
static func avisar_cambio(proyectil: ProyectilEnemigo) -> void:
	if _en_red() and proyectil.id_red >= 0:
		for id: int in Red.listos():
			actual._proyectil_cambio.rpc_id(id, proyectil.id_red, proyectil.datos_red())


## Desde cualquier ordenador: un disparo enemigo se ha acabado aqui (le ha
## dado a este jugador, o ha chocado).
static func avisar_fin(proyectil: ProyectilEnemigo) -> void:
	if _en_red() and proyectil.id_red >= 0:
		for id: int in Red.listos():
			actual._proyectil_fin.rpc_id(id, proyectil.id_red)


## Desde un espejo: el escudo del jugador de este ha despedido a un enemigo.
## Lo mueve el anfitrion.
static func pedir_empuje(enemigo: Enemigo, impulso: Vector2) -> void:
	if _en_red() and enemigo.id_red != "":
		actual._empuje.rpc_id(1, enemigo.id_red, impulso)


# --- Lo que el juego crea (aqui y, en el anfitrion, en todos) -------------------

## Un charco de lava o de fuego, en 'posicion' (de la sala).
static func crear_lava(sala: Sala, posicion: Vector2, radio: float, duracion: float, origen: String) -> void:
	_crear_lava(sala, posicion, radio, duracion, origen)
	_mandar_efecto(&"lava", {"celda": sala.celda, "posicion": posicion, "radio": radio,
		"duracion": duracion, "origen": origen})


static func _crear_lava(sala: Sala, posicion: Vector2, radio: float, duracion: float, origen: String) -> void:
	var lava := Lava.new()
	lava.radio = radio
	lava.duracion = duracion
	lava.origen = origen
	lava.position = posicion
	# Diferido: suele llegar en mitad del paso de fisica, y el charco trae su
	# area de colision.
	sala.add_child.call_deferred(lava)


## Una onda de choque (el pisoton del golem, el cambio de fase del jefe).
static func crear_onda(sala: Sala, posicion: Vector2, radio_maximo: float, duracion: float,
		dano: int, color: Color, origen: String) -> void:
	_crear_onda(sala, posicion, radio_maximo, duracion, dano, color, origen)
	_mandar_efecto(&"onda", {"celda": sala.celda, "posicion": posicion, "radio": radio_maximo,
		"duracion": duracion, "dano": dano, "color": color, "origen": origen})


static func _crear_onda(sala: Sala, posicion: Vector2, radio_maximo: float, duracion: float,
		dano: int, color: Color, origen: String) -> void:
	var onda := OndaChoque.new()
	onda.radio_maximo = radio_maximo
	onda.duracion = duracion
	onda.dano = dano
	onda.color = color
	onda.origen = origen
	onda.position = posicion
	sala.add_child(onda)
	Sonido.tocar(&"pisoton")


## El pozo del jefe (su agujero negro al reves), en 'posicion' (global).
static func crear_pozo(sala: Sala, posicion: Vector2, duracion: float, radio: float,
		dano: float, color: Color, halo: Color, aviso: float) -> void:
	_crear_pozo(sala, posicion, duracion, radio, dano, color, halo, aviso)
	_mandar_efecto(&"pozo", {"celda": sala.celda, "posicion": posicion, "duracion": duracion,
		"radio": radio, "dano": dano, "color": color, "halo": halo, "aviso": aviso})


static func _crear_pozo(sala: Sala, posicion: Vector2, duracion: float, radio: float,
		dano: float, color: Color, halo: Color, aviso: float) -> void:
	var pozo := PozoVacio.new(sala, duracion, radio, dano, color, halo)
	pozo.aviso = aviso
	sala.add_child(pozo)
	pozo.global_position = posicion
	Sonido.tocar(&"agujero_negro")


## El rayo de fuego del jefe: quita vida al jugador de cada ordenador que
## este en la linea (de 'desde' a 'hasta', globales), salvo con el escudo.
static func fuego(desde: Vector2, hasta: Vector2, ancho: float, dano: int, origen: String) -> void:
	_fuego(desde, hasta, ancho, dano, origen)
	_mandar_efecto(&"fuego", {"desde": desde, "hasta": hasta, "ancho": ancho, "dano": dano,
		"origen": origen})


static func _fuego(desde: Vector2, hasta: Vector2, ancho: float, dano: int, origen: String) -> void:
	Sonido.tocar(&"disparo_cargado")
	var arbol := Engine.get_main_loop() as SceneTree
	var jugador := arbol.get_first_node_in_group("jugador") as Jugador
	if jugador == null:
		return
	var centro := jugador.centro_colision()
	var cerca := Geometry2D.get_closest_point_to_segment(centro, desde, hasta)
	if centro.distance_to(cerca) <= ancho * 0.5 + 15.0 and not jugador.escudo_activo():
		jugador.recibir_dano(dano, false, origen)


## Rompe un pilar de la sala del jefe: se quita (y la sala lo olvida, para
## no seguir apartando a nadie de donde estaba) y saltan sus trozos.
static func romper_pilar(sala: Sala, pilar: Obstaculo) -> void:
	var donde := pilar.global_position
	_romper_pilar(sala, pilar)
	_mandar_efecto(&"pilar", {"celda": sala.celda, "posicion": donde})


static func _romper_pilar(sala: Sala, pilar: Obstaculo) -> void:
	var donde := pilar.global_position
	sala.olvidar_roca(donde)
	var escombros := Escombros.new()
	escombros.ancho = pilar.tamano().x
	escombros.position = sala.to_local(donde)
	sala.add_child(escombros)
	pilar.romper()
	Sonido.tocar(&"explosion")


## Deja un objeto en el suelo (lo que sueltan los enemigos, los vendajes). En
## cooperativo lo decide el anfitrion: el azar solo se tira en uno.
static func soltar_objeto(sala: Sala, mejora: ObjetoMejora, posicion: Vector2) -> void:
	Objeto.soltar(sala, mejora, posicion)
	_mandar_efecto(&"objeto", {"celda": sala.celda, "ruta": mejora.resource_path,
		"posicion": posicion})


static func _mandar_efecto(que: StringName, datos: Dictionary) -> void:
	if _difunde():
		for id: int in Red.listos():
			actual._efecto.rpc_id(id, que, datos)


# --- Lo que llega a los espejos ----------------------------------------------

@rpc("authority", "call_remote", "unreliable_ordered")
func _enemigos_red(lista: Array) -> void:
	for datos: Array in lista:
		var enemigo := _enemigo(datos[0])
		if enemigo != null:
			enemigo.aplicar_red(datos)


@rpc("authority", "call_remote", "reliable")
func _herido(id: String, cantidad: float, estilo: int) -> void:
	var enemigo := _enemigo(id)
	if enemigo != null and enemigo.tipo != null:
		NumeroDano.soltar(enemigo.get_parent(),
			enemigo.global_position + Vector2(0.0, -enemigo.tipo.alto * 0.55), cantidad, estilo)


@rpc("authority", "call_remote", "reliable")
func _muerto(id: String) -> void:
	var enemigo := _enemigo(id)
	_enemigos.erase(id)
	if enemigo != null:
		enemigo.morir_espejo()


@rpc("authority", "call_remote", "reliable")
func _nacer(id: String, ruta_madre: String, posicion: Vector2, celda: Vector2i) -> void:
	var sala := _sala(celda)
	var madre := load(ruta_madre) as TipoEnemigo
	if sala == null or madre == null or _enemigos.has(id):
		return
	var tipo := madre.cria()
	var cria: Enemigo = load(Enemigo.RUTA_ESCENA).instantiate()
	cria.id_red = id
	sala.add_child(cria)
	cria.preparar(tipo, posicion)
	sala.registrar_enemigo(cria)
	_enemigos[id] = cria


@rpc("authority", "call_remote", "reliable")
func _proyectil(id: int, ruta: String, desde: Vector2, direccion: Vector2, destino: Vector2,
		limite: Rect2, autor: String, celda: Vector2i) -> void:
	var sala := _sala(celda)
	var tipo := load(ruta) as TipoProyectil
	if sala == null or tipo == null:
		return
	var proyectil := ProyectilEnemigo.new()
	proyectil.configurar(tipo, desde, direccion, destino, limite)
	proyectil.autor = autor
	proyectil.id_red = id
	sala.add_child(proyectil)
	_proyectiles[id] = proyectil
	Sonido.tocar(tipo.sonido)


@rpc("any_peer", "call_remote", "reliable")
func _proyectil_cambio(id: int, datos: Dictionary) -> void:
	var proyectil := _proyectil_de(id)
	if proyectil != null:
		proyectil.cambiar_red(datos)


@rpc("any_peer", "call_remote", "reliable")
func _proyectil_fin(id: int) -> void:
	var proyectil := _proyectil_de(id)
	if proyectil != null:
		proyectil.terminar_red()
	_proyectiles.erase(id)


@rpc("any_peer", "call_remote", "reliable")
func _empuje(id: String, impulso: Vector2) -> void:
	if not Red.es_anfitrion():
		return
	var enemigo := _enemigo(id)
	if enemigo != null:
		enemigo.empujar(impulso)


@rpc("authority", "call_remote", "reliable")
func _sonido(nombre: StringName) -> void:
	Sonido.tocar(nombre)


@rpc("authority", "call_remote", "reliable")
func _efecto(que: StringName, datos: Dictionary) -> void:
	var sala: Sala = _sala(datos.celda) if datos.has("celda") else null
	match que:
		&"lava":
			if sala != null:
				_crear_lava(sala, datos.posicion, datos.radio, datos.duracion, datos.origen)
		&"onda":
			if sala != null:
				_crear_onda(sala, datos.posicion, datos.radio, datos.duracion, datos.dano,
					datos.color, datos.origen)
		&"pozo":
			if sala != null:
				_crear_pozo(sala, datos.posicion, datos.duracion, datos.radio, datos.dano,
					datos.color, datos.halo, datos.aviso)
		&"fuego":
			_fuego(datos.desde, datos.hasta, datos.ancho, datos.dano, datos.origen)
		&"pilar":
			var pilar := _pilar_en(datos.posicion)
			if sala != null and pilar != null:
				_romper_pilar(sala, pilar)
		&"objeto":
			var mejora := load(datos.ruta) as ObjetoMejora
			if sala != null and mejora != null:
				Objeto.soltar(sala, mejora, datos.posicion)


# --- Ayudas ------------------------------------------------------------------

func _sala(celda: Vector2i) -> Sala:
	var piso: Piso = _piso.call()
	if piso == null:
		return null
	for sala in piso.salas():
		if sala.celda == celda:
			return sala
	return null


## El enemigo de ese nombre en este ordenador. Si no esta apuntado (es del
## piso recien montado), se apuntan todos los del piso.
##
## Lo guardado se mira como Variant antes de darle tipo: un enemigo ya
## liberado no se puede meter en una variable de tipo Enemigo (el motor
## avisa con un error).
func _enemigo(id: String) -> Enemigo:
	var guardado: Variant = _enemigos.get(id)
	if is_instance_valid(guardado):
		return guardado
	var piso: Piso = _piso.call()
	if piso == null:
		return null
	for sala in piso.salas():
		for otro in sala.enemigos():
			if is_instance_valid(otro):
				_enemigos[otro.id_red] = otro
	guardado = _enemigos.get(id)
	if is_instance_valid(guardado):
		return guardado
	_enemigos.erase(id)
	return null


func _proyectil_de(id: int) -> ProyectilEnemigo:
	var guardado: Variant = _proyectiles.get(id)
	if is_instance_valid(guardado) and not guardado.is_queued_for_deletion():
		return guardado
	_proyectiles.erase(id)
	return null


func _pilar_en(posicion: Vector2) -> Obstaculo:
	var piso: Piso = _piso.call()
	if piso == null:
		return null
	for obstaculo in piso.obstaculos():
		if is_instance_valid(obstaculo) and obstaculo.global_position.distance_to(posicion) < MISMO_SITIO:
			return obstaculo
	return null
