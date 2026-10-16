## Registro de partidas: apunta lo que pasa en cada partida y lo guarda en un
## archivo por partida, en user://partidas/. Cuanto se tarda en cada piso y en
## cada sala de pelea, cada golpe recibido (de que y cuanto), la vida
## recuperada, los enemigos muertos, los objetos cogidos, el ataque especial y
## como acaba.
##
## PARA QUE: equilibrar la dificultad con datos y no a ojo (pedido por Matias
## el 2026-10-13). El equipo juega, junta los archivos y
## herramientas/analizar_partidas.py saca las medias: en que piso se muere,
## que enemigo quita mas vida, cuanto dura cada sala.
##
## POR QUE UN NODO DE LA PARTIDA Y NO UN AUTOLOAD: una partida vive en la
## escena Principal. Al volver al menu se libera, y con ella este nodo, que en
## ese momento cierra el archivo como "abandonada". Lo crea y lo conecta
## Principal, como los atajos de prueba.
##
## POR QUE SE GUARDA EN CADA PISO Y NO SOLO AL ACABAR: si el juego se cierra
## de golpe (se cuelga, se apaga el ordenador), lo jugado hasta el ultimo piso
## se queda guardado.
##
## No sale nada del ordenador: los archivos se quedan en la carpeta de datos
## del juego hasta que alguien los mande.
class_name RegistroPartida
extends Node

const CARPETA := "user://partidas"
## Version de lo que se guarda. Si cambia la forma del archivo, se sube, y el
## analizador sabe que esperar.
const FORMATO: int = 1
## Una partida reiniciada o abandonada antes de esto no se guarda: es haber
## entrado y salido, o reiniciar al momento, y solo ensuciaria las medias.
const SEGUNDOS_MINIMOS: float = 10.0

var _jugador: Jugador
## La partida que se esta jugando, tal cual se guarda. Vacio entre partidas.
var _partida: Dictionary = {}
## El piso que se esta jugando: uno de los de _partida.pisos (es el mismo
## diccionario, asi que cambiarlo cambia la partida).
var _piso: Dictionary = {}
var _piso_nodo: Piso = null
## La sala que se esta peleando (puertas cerradas): una de las de _piso.salas.
var _pelea: Dictionary = {}
var _sala_pelea: Sala = null
var _archivo: String = ""
## La vida de antes de cada cambio, para saber cuanto se ha recuperado.
var _ultima_vida: int = 0
## El ultimo golpe: si la partida acaba en derrota, es lo que la ha matado.
var _ultimo_golpe: Dictionary = {}
## True si a la partida no la ha montado el juego sino una escena de prueba.
## Esas no se guardan (ver _ready).
var _de_prueba: bool = false


func _init(jugador: Jugador) -> void:
	_jugador = jugador
	name = "RegistroPartida"


func _ready() -> void:
	# LAS ESCENAS DE PRUEBA NO GUARDAN PARTIDAS (2026-10-16). Montan
	# Principal dentro de su propia escena, y el juego (el menu, o abrir
	# Principal.tscn desde el editor) la pone colgando de la raiz. No son
	# partidas: de las nueve primeras guardadas, cuatro eran pruebas de
	# Claude y salian en las medias como si alguien hubiera jugado.
	_de_prueba = get_parent().get_parent() != get_tree().root
	_jugador.golpeado.connect(_al_recibir_golpe)
	_jugador.veneno_quita.connect(_al_quitar_veneno)
	_jugador.vida_cambiada.connect(_al_cambiar_vida)
	_jugador.bola_lanzada.connect(_al_disparar)
	_jugador.especial_cambiado.connect(_al_cambiar_especial)
	_jugador.mejora_recogida.connect(_al_recoger)
	GestorProgreso.partida_ganada.connect(terminar.bind("victoria"))
	GestorProgreso.partida_perdida.connect(terminar.bind("derrota"))


## El tiempo cuenta solo jugando: este nodo se para con la pausa, como el
## resto de la partida, asi que el rato en el menu de pausa no suma.
func _process(delta: float) -> void:
	if _piso.is_empty():
		return
	_partida.segundos += delta
	_piso.segundos += delta
	if not _pelea.is_empty():
		_pelea.segundos += delta


## Abre un piso nuevo en el registro. La llama Principal al montarlo, con el
## piso ya construido (hacen falta sus salas). El primero de una partida
## empieza la partida.
func nuevo_piso(numero: int, datos: DatosPiso, piso: Piso) -> void:
	if _partida.is_empty():
		_empezar()
	else:
		_cerrar_piso()
	_piso_nodo = piso
	var con_enemigos := 0
	for sala in piso.salas():
		if sala.enemigos_vivos() > 0:
			con_enemigos += 1
		sala.pelea_empezada.connect(_al_empezar_pelea)
		sala.despejada.connect(_al_despejar)
		sala.enemigo_muerto.connect(_al_morir_enemigo)
	_piso = {
		"piso": numero,
		"capa": datos.nombre_capa,
		"segundos": 0.0,
		"vida_al_entrar": _jugador.vida_actual,
		"vida_al_salir": _jugador.vida_actual,
		"vida_maxima": _jugador.vida_maxima,
		"golpes": [],
		"vida_recuperada": 0,
		"objetos": [],
		"especial_usado": 0,
		"disparos": 0,
		"disparos_cargados": 0,
		"enemigos_muertos": {},
		"salas_con_enemigos": con_enemigos,
		"salas_limpiadas": 0,
		"salas": [],
	}
	_partida.pisos.append(_piso)
	_partida.piso_alcanzado = numero
	_guardar()


## Cierra la partida con su resultado ("victoria", "derrota", "reiniciada" o
## "abandonada") y la guarda. Si no hay ninguna abierta, no hace nada: asi da
## igual que la llamen dos veces (perder y luego reiniciar).
func terminar(resultado: String) -> void:
	if _partida.is_empty():
		return
	_cerrar_piso()
	_partida.resultado = resultado
	if resultado == "derrota" and not _ultimo_golpe.is_empty():
		_partida.muerte = {"piso": _piso.piso, "sala": _ultimo_golpe.sala, "por": _ultimo_golpe.origen}
	var corta: bool = resultado in ["reiniciada", "abandonada"] and _partida.segundos < SEGUNDOS_MINIMOS
	if corta:
		if FileAccess.file_exists(_archivo):
			DirAccess.remove_absolute(_archivo)
	else:
		_guardar()
	_partida = {}
	_piso = {}
	_piso_nodo = null
	_pelea = {}
	_sala_pelea = null
	_ultimo_golpe = {}


## Se ha usado un atajo de prueba (F1-F5): la partida no vale para equilibrar
## y el analizador la deja fuera.
func marcar_trucos() -> void:
	if not _partida.is_empty():
		_partida.trucos = true


## Abre la carpeta de los registros en el explorador de archivos, para
## mandarlos. La usan la pantalla final y el menu de pausa.
static func abrir_carpeta() -> void:
	DirAccess.make_dir_recursive_absolute(CARPETA)
	OS.shell_open(ProjectSettings.globalize_path(CARPETA))


func _exit_tree() -> void:
	terminar("abandonada")


func _notification(que: int) -> void:
	# Cerrar la ventana a mitad de partida.
	if que == NOTIFICATION_WM_CLOSE_REQUEST:
		terminar("abandonada")


func _empezar() -> void:
	var mago := GestorProgreso.personaje_elegido
	var ahora := Time.get_datetime_string_from_system(false, true)
	_partida = {
		"formato": FORMATO,
		"version": GestorProgreso.version_juego(),
		"empezada": ahora,
		"mago": mago.nombre if mago != null else "",
		"resultado": "jugando",
		"piso_alcanzado": 0,
		"segundos": 0.0,
		"muerte": null,
		"trucos": false,
		"resumen": {},
		"pisos": [],
	}
	# Un archivo por partida, con la hora en el nombre: ordenados por nombre,
	# salen en el orden en que se jugaron.
	DirAccess.make_dir_recursive_absolute(CARPETA)
	var base := CARPETA.path_join("partida_" + ahora.replace(":", "-").replace(" ", "_"))
	_archivo = base + ".json"
	var otra := 2
	while FileAccess.file_exists(_archivo):
		_archivo = "%s_%d.json" % [base, otra]
		otra += 1
	_ultima_vida = _jugador.vida_actual
	_ultimo_golpe = {}


func _cerrar_piso() -> void:
	if _piso.is_empty():
		return
	_piso.vida_al_salir = _jugador.vida_actual
	# Una pelea a medias (por un atajo, o al morir) se queda como estaba.
	_pelea = {}
	_sala_pelea = null


func _al_recibir_golpe(cantidad: int, origen: String) -> void:
	if _piso.is_empty():
		return
	var golpe := {
		"segundo": _piso.segundos,
		"sala": _nombre_sala(_piso_nodo.sala_actual() if is_instance_valid(_piso_nodo) else null),
		"por": origen if origen != "" else "desconocido",
		"vida": cantidad,
		"queda": _jugador.vida_actual,
	}
	_piso.golpes.append(golpe)
	if not _pelea.is_empty():
		_pelea.golpes += 1
		_pelea.vida_perdida += cantidad
	_ultimo_golpe = {"sala": golpe.sala, "origen": golpe.por}


## Lo que quita el veneno poco a poco va con los golpes, para que la vida
## perdida cuadre, pero marcado ("veneno": true) y con su propio nombre
## ("Serpiente (veneno), poco a poco"): asi no cuenta como un golpe mas y se
## ve aparte cuanto quita el veneno y cuanto el escupitajo.
func _al_quitar_veneno(cantidad: int, origen: String) -> void:
	if _piso.is_empty():
		return
	var golpe := {
		"segundo": _piso.segundos,
		"sala": _nombre_sala(_piso_nodo.sala_actual() if is_instance_valid(_piso_nodo) else null),
		"por": (origen if origen != "" else "veneno") + ", poco a poco",
		"vida": cantidad,
		"queda": _jugador.vida_actual,
		"veneno": true,
	}
	_piso.golpes.append(golpe)
	if not _pelea.is_empty():
		_pelea.vida_perdida += cantidad
	# _ultimo_golpe no se toca: el veneno no mata, asi que nunca es la muerte.


func _al_cambiar_vida(vida: int, _maxima: int) -> void:
	if not _piso.is_empty() and vida > _ultima_vida:
		_piso.vida_recuperada += vida - _ultima_vida
	_ultima_vida = vida


func _al_disparar(_desde: Vector2, _direccion: Vector2, cargada: bool) -> void:
	if _piso.is_empty():
		return
	if cargada:
		_piso.disparos_cargados += 1
	else:
		_piso.disparos += 1


func _al_cambiar_especial(disponible: bool) -> void:
	if not _piso.is_empty() and not disponible:
		_piso.especial_usado += 1


func _al_recoger(mejora: ObjetoMejora) -> void:
	if not _piso.is_empty():
		_piso.objetos.append(mejora.nombre)


func _al_empezar_pelea(sala: Sala) -> void:
	if _piso.is_empty():
		return
	var tipos := {}
	for enemigo in sala.enemigos():
		if is_instance_valid(enemigo) and enemigo.tipo != null:
			tipos[enemigo.tipo.nombre] = int(tipos.get(enemigo.tipo.nombre, 0)) + 1
	_sala_pelea = sala
	_pelea = {
		"sala": _nombre_sala(sala),
		"enemigos": tipos,
		"segundos": 0.0,
		"golpes": 0,
		"vida_perdida": 0,
		"acabada": false,
	}
	_piso.salas.append(_pelea)


func _al_despejar(sala: Sala) -> void:
	if _piso.is_empty():
		return
	_piso.salas_limpiadas += 1
	if sala == _sala_pelea:
		_pelea.acabada = true
		_pelea = {}
		_sala_pelea = null


func _al_morir_enemigo(enemigo: Enemigo) -> void:
	if _piso.is_empty() or enemigo.tipo == null:
		return
	var muertos: Dictionary = _piso.enemigos_muertos
	muertos[enemigo.tipo.nombre] = int(muertos.get(enemigo.tipo.nombre, 0)) + 1


## La sala por su casilla en el mapa del piso ("2,-1"): es fija para cada
## piso, porque los pisos son siempre iguales.
func _nombre_sala(sala: Sala) -> String:
	if sala == null:
		return ""
	return "%d,%d" % [sala.celda.x, sala.celda.y]


func _guardar() -> void:
	if _de_prueba:
		return
	_partida.resumen = _resumen()
	var archivo := FileAccess.open(_archivo, FileAccess.WRITE)
	if archivo == null:
		push_warning("No se puede guardar el registro de la partida en %s." % _archivo)
		return
	# Sin ordenar las claves: asi el archivo se lee en el orden en que se
	# cuenta la partida.
	archivo.store_string(JSON.stringify(_redondear(_partida), "\t", false))
	archivo.close()


## Lo que se mira primero al abrir un archivo, sumado de todos los pisos.
func _resumen() -> Dictionary:
	var golpes := 0
	var vida_perdida := 0
	var vida_recuperada := 0
	var muertos := 0
	for piso: Dictionary in _partida.pisos:
		for golpe: Dictionary in piso.golpes:
			vida_perdida += int(golpe.vida)
			if not golpe.get("veneno", false):
				golpes += 1
		vida_recuperada += int(piso.vida_recuperada)
		for cuantos: int in piso.enemigos_muertos.values():
			muertos += cuantos
	return {"golpes": golpes, "vida_perdida": vida_perdida,
		"vida_recuperada": vida_recuperada, "enemigos_muertos": muertos}


## Una copia con los segundos a una decima: 95.30000001 no dice nada mas que
## 95.3 y ensucia el archivo.
func _redondear(valor: Variant) -> Variant:
	if valor is float:
		return snappedf(valor, 0.1)
	if valor is Dictionary:
		var copia := {}
		for clave: Variant in valor:
			copia[clave] = _redondear(valor[clave])
		return copia
	if valor is Array:
		var lista := []
		for elemento: Variant in valor:
			lista.append(_redondear(elemento))
		return lista
	return valor
