## El cooperativo dentro de la partida: los magos de los demas, sus disparos,
## los objetos, las peleas, la bajada y quien cae. Lo crea Principal solo si
## la partida es cooperativa (Red.cooperativo()); jugando solo, ni existe.
## Fase 1 (2026-10-16): verse, andar y disparar en el piso 1. Fase 2 (el
## mismo dia): el juego entero.
##
## CADA UNO MANDA EN SU MAGO: se mueve en su ordenador, sin esperar a nadie,
## y avisa a los demas de donde esta y de su vida unas 20 veces por segundo.
## El mundo (enemigos, sus disparos, lo que sueltan) lo lleva MundoRed, hijo
## de este nodo: lo decide el anfitrion.
##
## LAS PELEAS, PARA TODOS A LA VEZ (como el cooperativo de Isaac): al entrar
## uno en una sala con enemigos, se lo pide al anfitrion (Sala.quiere_pelea),
## que la empieza en todos los ordenadores, y los demas aparecen dentro. Solo
## una a la vez: si otro pide otra sala mientras tanto, espera.
##
## LA BAJADA, TAMBIEN JUNTOS: el que llega al agujero se lo pide al anfitrion
## y todos bajan a la vez. Los pisos salen de una semilla: basta con que cada
## ordenador construya el siguiente.
##
## EL QUE CAE NO VUELVE HASTA EL PISO SIGUIENTE, y con media vida (Matias,
## 2026-10-16). Mientras, no se le ve y su camara sigue a otro. Si caen
## todos, se acaba la partida para todos (lo decide el anfitrion).
##
## LOS OBJETOS SON PARA TODOS menos para quien este caido: el que lo coge
## avisa y a los demas se les aplica igual y se les quita del suelo. Se
## reconoce por donde esta y que es.
##
## Sus llamadas por la red van a /root/Principal/Cooperativo, la misma ruta en
## todos. Solo se habla a los que ya tienen la partida montada (Red.listos()):
## a uno que aun la esta cargando le llegaria a un nodo que no existe.
class_name Cooperativo
extends Node

## Cada cuanto se manda donde esta el mago.
const CADA: float = 0.05
## Cada cuanto se repinta la vida de los companeros en el HUD.
const CADA_COMPANEROS: float = 0.25
## Separacion entre los magos al empezar un piso o al aparecer en una pelea,
## para no salir uno encima de otro.
const SEPARACION_SALIDA: float = 44.0
## Lo que se aparta de los muros quien aparece dentro de una pelea.
const MARGEN_DENTRO: float = 40.0
const RADIO_JUGADOR: float = 20.0

var _jugador: Jugador
var _principal: Node
var _hud: Hud
var _camara: CamaraJuego
var _mundo: MundoRed
## id de red -> MagoRemoto.
var _remotos: Dictionary = {}
var _reloj: float = 0.0
var _reloj_companeros: float = 0.0
## Este mago ha caido: no vuelve hasta el piso siguiente.
var _caido: bool = false
## A quien sigue la camara mientras esta caido, y en que sala esta.
var _mirando: MagoRemoto = null
var _sala_mirada: Sala = null
# Solo cuenta en el anfitrion:
## La pelea en marcha (una a la vez para todos).
var _pelea: Sala = null
var _bajando: bool = false
var _derrota_avisada: bool = false


func _init(jugador: Jugador, principal: Node, hud: Hud, camara: CamaraJuego) -> void:
	_jugador = jugador
	_principal = principal
	_hud = hud
	_camara = camara
	name = "Cooperativo"


func _ready() -> void:
	# Por grupo, para que un Objeto avise sin saber si hay cooperativo.
	add_to_group("cooperativo")
	_mundo = MundoRed.new(func() -> Piso: return _principal._piso_actual)
	add_child(_mundo)
	Red.jugador_salio.connect(_al_irse)
	Red.jugador_listo.connect(func(_id: int) -> void: _mandar_estado())
	Red.avisar_listo()
	_hud.avisar("Cooperativo · %d jugadores" % Red.jugadores.size(), Color(0.62, 0.9, 1.0))


## Donde sale este jugador respecto a la entrada del piso: uno al lado del
## otro, por su numero.
func desfase_salida() -> Vector2:
	return Vector2((Red.mi_numero() - 2) * SEPARACION_SALIDA, 0.0)


## Lo llama Principal al montar cada piso, con el jugador ya en la entrada.
func al_nuevo_piso(piso: Piso) -> void:
	_mundo.nuevo_piso()
	_pelea = null
	_bajando = false
	for sala in piso.salas():
		sala.quiere_pelea.connect(_al_querer_pelea)
	if _caido:
		_caido = false
		_mirando = null
		_sala_mirada = null
		_jugador.revivir(ceili(_jugador.vida_maxima * 0.5))
		_hud.avisar("Vuelves con media vida", Color(0.62, 0.9, 1.0))
		_mandar_estado()


## El mago de este ordenador se ha quedado sin vida. En cooperativo no acaba
## la partida (Principal lo conecta aqui en vez de a GestorProgreso).
func al_caer_yo() -> void:
	_caido = true
	_jugador.visible = false
	_hud.avisar("Has caído: vuelves en el piso siguiente, con media vida", Color(1.0, 0.55, 0.45))
	_mandar_estado()


## El jugador de este ordenador ha llegado a la bajada.
func pedir_bajar() -> void:
	if Red.es_anfitrion():
		_pedir_bajar(GestorProgreso.piso_actual)
	else:
		_pedir_bajar.rpc_id(1, GestorProgreso.piso_actual)


func _physics_process(delta: float) -> void:
	_reloj += delta
	_reloj_companeros += delta
	if _reloj >= CADA:
		_reloj = 0.0
		_mandar_estado()
	if _reloj_companeros >= CADA_COMPANEROS:
		_reloj_companeros = 0.0
		_hud.actualizar_companeros(_companeros())
	if Red.es_anfitrion() and not _derrota_avisada and _todos_caidos():
		_derrota_avisada = true
		_derrota.rpc()


## Caido, la camara sigue a un companero vivo y se encaja en su sala.
func _process(_delta: float) -> void:
	if not _caido:
		return
	if not is_instance_valid(_mirando) or not _mirando.vivo:
		_mirando = null
		for remoto: MagoRemoto in _remotos.values():
			if is_instance_valid(remoto) and remoto.vivo:
				_mirando = remoto
				_camara.seguir(remoto)
				break
	if _mirando == null:
		return
	var piso: Piso = _principal._piso_actual
	var sala := piso.sala_en(_mirando.global_position) if piso != null else null
	if sala != null and sala != _sala_mirada:
		_sala_mirada = sala
		_camara.limitar_a(sala.rect_con_muros())


func _mandar_estado() -> void:
	if not Red.cooperativo():
		return
	for id: int in Red.listos():
		_estado.rpc_id(id, _jugador.global_position, _jugador.animacion_actual(),
			_jugador.color_actual(), _jugador.escudo_activo(), _jugador.vida_actual,
			_jugador.vida_maxima, not _caido and _jugador.sigue_vivo())


## Un disparo de este mago, a los demas: la bola tal cual ha salido aqui,
## con lo que haya mejorado, para que alli sea la misma. En el anfitrion es
## la que da a los enemigos, asi que lleva tambien el frio y el fuego.
func mandar_disparo(bola: BolaMagica, desde: Vector2, mago: PersonajeJugable) -> void:
	var datos := {
		"desde": desde,
		"direccion": bola.direccion,
		"velocidad": bola.velocidad,
		"radio": bola.radio,
		"color": bola.color,
		"color_halo": bola.color_halo,
		"dano": bola.dano,
		"frena": bola.frena,
		"quema": bola.quema,
		"dano_quema": bola.dano_quema,
		"cargada": bola.cargada,
		"atraviesa": bola.atraviesa,
		"alcance": bola.alcance,
		"agujero": bola.cargada and mago != null and mago.agujero_negro,
	}
	for id: int in Red.listos():
		_disparo.rpc_id(id, datos)


## Lo llama un Objeto al recogerlo el mago de este ordenador.
func objeto_recogido(objeto: Objeto) -> void:
	if objeto.mejora == null:
		return
	for id: int in Red.listos():
		_objeto.rpc_id(id, objeto.global_position, objeto.mejora.resource_path)


# --- Peleas --------------------------------------------------------------------

## El jugador de este ordenador ha entrado del todo en una sala con enemigos:
## se pide la pelea al anfitrion.
func _al_querer_pelea(sala: Sala) -> void:
	if _caido:
		return
	if Red.es_anfitrion():
		_pedir_pelea(sala.celda, _jugador.global_position)
	else:
		_pedir_pelea.rpc_id(1, sala.celda, _jugador.global_position)


@rpc("any_peer", "call_remote", "reliable")
func _pedir_pelea(celda: Vector2i, posicion: Vector2) -> void:
	if not Red.es_anfitrion():
		return
	var sala := _sala(celda)
	if sala == null or sala.esta_activada() or sala.esta_despejada():
		return
	# Una a la vez: la otra sala espera (su jugador lo vuelve a pedir).
	if is_instance_valid(_pelea) and _pelea != sala and not _pelea.esta_despejada():
		return
	_pelea = sala
	_empezar_pelea.rpc(celda, posicion)


## En todos: empieza la pelea de esa sala y el que este fuera (y vivo)
## aparece dentro, al lado de donde ha entrado el primero.
@rpc("authority", "call_local", "reliable")
func _empezar_pelea(celda: Vector2i, posicion: Vector2) -> void:
	var sala := _sala(celda)
	if sala == null:
		return
	sala.empezar_pelea()
	if _caido or not _jugador.sigue_vivo():
		return
	if sala.contiene_del_todo(_jugador.centro_colision(), RADIO_JUGADOR):
		return
	var dentro := sala.rect_suelo_global().grow(-MARGEN_DENTRO)
	var punto := (posicion + desfase_salida()).clamp(dentro.position, dentro.end)
	_jugador.global_position = sala.sacar_de_las_rocas(punto, RADIO_JUGADOR)
	_jugador.velocity = Vector2.ZERO
	_hud.avisar("¡A pelear!", Color(1.0, 0.75, 0.4))


# --- Bajada y final -------------------------------------------------------------

@rpc("any_peer", "call_remote", "reliable")
func _pedir_bajar(piso: int) -> void:
	if not Red.es_anfitrion() or _bajando or piso != GestorProgreso.piso_actual:
		return
	_bajando = true
	_bajar.rpc()


@rpc("authority", "call_local", "reliable")
func _bajar() -> void:
	Sonido.tocar(&"bajar")
	# Diferido, como al bajar jugando solo: puede llegar en mitad del paso de
	# fisica, y bajar destruye el piso con sus cuerpos.
	GestorProgreso.avanzar_piso.call_deferred()


## Caidos todos (los que siguen en la sala): se acaba para todos.
func _todos_caidos() -> bool:
	if not _caido and _jugador.sigue_vivo():
		return false
	for id: int in Red.jugadores:
		if id == Red.mi_id():
			continue
		var remoto: Variant = _remotos.get(id)
		# Sin noticias todavia de ese, se le da por vivo.
		if not is_instance_valid(remoto) or remoto.vivo:
			return false
	return true


@rpc("authority", "call_local", "reliable")
func _derrota() -> void:
	GestorProgreso.terminar_por_derrota()


# --- Lo que llega de los demas ---------------------------------------------

@rpc("any_peer", "call_remote", "unreliable_ordered")
func _estado(posicion: Vector2, animacion: StringName, color: Color, escudo: bool,
		vida: int, vida_maxima: int, vivo: bool) -> void:
	var remoto := _remoto(multiplayer.get_remote_sender_id())
	if remoto != null:
		remoto.recibir(posicion, animacion, color, escudo, vida, vida_maxima, vivo)


@rpc("any_peer", "call_remote", "reliable")
func _disparo(datos: Dictionary) -> void:
	var id := multiplayer.get_remote_sender_id()
	var mago := Red.mago_de(id)
	if mago != null and _principal.has_method("lanzar_bola_remota"):
		_principal.lanzar_bola_remota(datos, mago)


## Otro ha cogido un objeto: aqui se quita del suelo y, si este mago esta
## vivo, se le aplica tambien.
@rpc("any_peer", "call_remote", "reliable")
func _objeto(posicion: Vector2, ruta: String) -> void:
	var objeto := _buscar_objeto(posicion, ruta)
	if objeto == null:
		# Ya no esta: lo ha cogido este tambien a la vez. Se queda con el suyo.
		return
	var mejora := objeto.mejora
	objeto.queue_free()
	if _caido or not _jugador.sigue_vivo():
		return
	_jugador.aplicar_mejora(mejora)
	var quien := int(Red.jugadores.get(multiplayer.get_remote_sender_id(), {}).get("numero", 0))
	if quien > 0:
		_hud.avisar("El jugador %d ha cogido %s: también es tuyo" % [quien, mejora.nombre.to_lower()],
			mejora.color)


# --- Ayudas ------------------------------------------------------------------

## El mago de ese jugador en este ordenador. Se crea la primera vez que dice
## algo: asi da igual quien monto antes la partida.
func _remoto(id: int) -> MagoRemoto:
	if _remotos.has(id):
		return _remotos[id]
	var mago := Red.mago_de(id)
	if mago == null:
		return null
	var remoto := MagoRemoto.new(mago, int(Red.jugadores[id].numero))
	# En Principal y no en el piso: cambiar de piso no tiene que borrarlo.
	_principal.add_child(remoto)
	_remotos[id] = remoto
	return remoto


## Los companeros para el HUD, por numero.
func _companeros() -> Array:
	var lista: Array = []
	for remoto: MagoRemoto in _remotos.values():
		if is_instance_valid(remoto):
			lista.append({"numero": remoto.numero, "nombre": remoto.personaje.nombre,
				"color": remoto.personaje.color, "vida": remoto.vida,
				"maxima": remoto.vida_maxima, "vivo": remoto.vivo})
	lista.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.numero < b.numero)
	return lista


func _sala(celda: Vector2i) -> Sala:
	var piso: Piso = _principal._piso_actual
	if piso == null:
		return null
	for sala in piso.salas():
		if sala.celda == celda:
			return sala
	return null


func _buscar_objeto(posicion: Vector2, ruta: String) -> Objeto:
	for nodo in get_tree().get_nodes_in_group("objetos"):
		var objeto := nodo as Objeto
		if objeto != null and objeto.mejora != null and objeto.mejora.resource_path == ruta \
				and objeto.global_position.distance_to(posicion) < 4.0 and not objeto.is_queued_for_deletion():
			return objeto
	return null


func _al_irse(id: int, numero: int) -> void:
	if _remotos.has(id):
		_remotos[id].queue_free()
		_remotos.erase(id)
	_hud.avisar("El jugador %d se ha ido de la partida" % numero, Color(1.0, 0.75, 0.4))
