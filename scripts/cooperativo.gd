## El cooperativo dentro de la partida: manda a los demas ordenadores donde
## esta el mago de este y lo que dispara, ensena los suyos (MagoRemoto) y
## reparte los objetos. Lo crea Principal solo si la partida es cooperativa
## (Red.cooperativo()); jugando solo, ni existe. Fase 1 (Matias, 2026-10-16).
##
## CADA UNO MANDA EN SU MAGO: se mueve en su ordenador, sin esperar a nadie,
## y avisa a los demas de donde esta unas 20 veces por segundo. Es lo que dice
## el estudio para que andar no tenga retraso. Lo que en la fase 2 tenga que
## ser igual para todos (enemigos, dano, lo que sueltan) lo decidira el
## anfitrion.
##
## DE MOMENTO, SOLO EL PISO 1: no tiene enemigos ni peligros, asi que todos
## ven lo mismo sin que nadie tenga que mandar sobre nada mas. La bajada
## esta cerrada hasta la fase 2 (ver bajada_cerrada).
##
## LOS OBJETOS SON PARA TODOS (Matias, 2026-10-16), menos para quien este
## muerto: el que lo coge avisa y a los demas se les aplica igual y se les
## quita del suelo. Se reconoce por donde esta y que es, que es igual en
## todos los ordenadores: los pisos salen de una semilla.
##
## Sus llamadas por la red van a /root/Principal/Cooperativo, la misma ruta en
## todos. Solo se habla a los que ya tienen la partida montada (Red.listos()):
## a uno que aun la esta cargando le llegaria a un nodo que no existe.
class_name Cooperativo
extends Node

## Cada cuanto se manda donde esta el mago.
const CADA: float = 0.05
## Separacion entre los magos al empezar un piso, para no salir uno encima
## de otro.
const SEPARACION_SALIDA: float = 44.0

var _jugador: Jugador
var _principal: Node
var _hud: Hud
## id de red -> MagoRemoto.
var _remotos: Dictionary = {}
var _reloj: float = 0.0


func _init(jugador: Jugador, principal: Node, hud: Hud) -> void:
	_jugador = jugador
	_principal = principal
	_hud = hud
	name = "Cooperativo"


func _ready() -> void:
	# Por grupo, para que un Objeto avise sin saber si hay cooperativo.
	add_to_group("cooperativo")
	Red.jugador_salio.connect(_al_irse)
	Red.jugador_listo.connect(func(_id: int) -> void: _mandar_estado())
	Red.avisar_listo()
	var otros := Red.jugadores.size() - 1
	_hud.avisar("Cooperativo · %d jugadores · de momento solo el piso 1" % (otros + 1),
		Color(0.62, 0.9, 1.0))


## Donde sale este jugador respecto a la entrada del piso: uno al lado del
## otro, por su numero.
func desfase_salida() -> Vector2:
	return Vector2((Red.mi_numero() - 2) * SEPARACION_SALIDA, 0.0)


## La bajada, de momento cerrada: bajar uno solo lo dejaria en un piso con
## enemigos que cada ordenador moveria por su cuenta. Juntos, con el
## anfitrion mandando en los enemigos, en la fase 2. Devuelve true si no se
## puede bajar.
func bajada_cerrada() -> bool:
	_hud.avisar("En cooperativo, de momento solo se juega el piso 1", Color(1.0, 0.75, 0.4))
	return true


func _physics_process(delta: float) -> void:
	_reloj += delta
	if _reloj < CADA:
		return
	_reloj = 0.0
	_mandar_estado()


func _mandar_estado() -> void:
	if not Red.cooperativo():
		return
	for id: int in Red.listos():
		_estado.rpc_id(id, _jugador.global_position, _jugador.animacion_actual(),
			_jugador.color_actual(), _jugador.escudo_activo())


## Un disparo de este mago, a los demas: la bola tal cual ha salido aqui,
## con lo que haya mejorado, para que alli sea la misma.
func mandar_disparo(bola: BolaMagica, desde: Vector2, mago: PersonajeJugable) -> void:
	var datos := {
		"desde": desde,
		"direccion": bola.direccion,
		"velocidad": bola.velocidad,
		"radio": bola.radio,
		"color": bola.color,
		"color_halo": bola.color_halo,
		"dano": bola.dano,
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


# --- Lo que llega de los demas ---------------------------------------------

@rpc("any_peer", "call_remote", "unreliable_ordered")
func _estado(posicion: Vector2, animacion: StringName, color: Color, escudo: bool) -> void:
	var remoto := _remoto(multiplayer.get_remote_sender_id())
	if remoto != null:
		remoto.recibir(posicion, animacion, color, escudo)


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
	if _jugador.vida_actual > 0:
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
