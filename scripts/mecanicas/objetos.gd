## Mecanica: deja un objeto por piso.
##
## Como las demas, no hay ni una linea de esto en el gestor ni en el piso. Y
## como los enemigos, lee su carpeta entera: para anadir un objeto basta con
## dejar otro .tres en resources/objetos/.
class_name MecanicaObjetos
extends Mecanica

const ESCENA_OBJETO := preload("res://scenes/Objeto.tscn")
const RUTA_OBJETOS := "res://resources/objetos"

## Cuantos objetos deja por piso. El primero va en la sala del objeto; los
## demas, si los hay, en salas normales al azar.
@export var por_piso: int = 1

## Espacio libre delante de las puertas, para los objetos que van en salas
## normales. Un objeto en el umbral se cogeria sin verlo.
@export var despeje: float = 260.0

## Probabilidad de que un enemigo suelte una ventaja al morir. Baja a
## proposito: el objeto de cada piso sigue siendo la recompensa gorda, y esto
## es la sorpresa de vez en cuando. Con 0,03, uno de cada ~33 enemigos.
@export_range(0.0, 1.0) var probabilidad_al_matar: float = 0.03

var _objetos: Array[ObjetoMejora] = []


func aplicar_a_piso(piso: Node) -> void:
	if _objetos.is_empty():
		_objetos = _cargar()
	var disponibles: Array[ObjetoMejora] = []
	for objeto in _objetos:
		if piso.numero_piso >= objeto.piso_minimo:
			disponibles.append(objeto)
	if disponibles.is_empty():
		return

	var generador := RandomNumberGenerator.new()
	generador.seed = hash(nombre_mecanica) + piso.numero_piso * 60077

	# Cada sala avisa cuando le muere un enemigo, y a veces sale una ventaja.
	for sala in piso.salas():
		sala.enemigo_muerto.connect(_al_morir_enemigo.bind(sala, piso, disponibles))

	# El primero, en el centro de su sala: es un premio, se tiene que ver nada
	# mas asomarse. Si el mapa no tiene sala de objeto (pocas salas), va al
	# inicio, que es el unico sitio seguro que siempre existe.
	var sala_objeto: Sala = piso.sala_de_tipo(MapaSalas.Tipo.OBJETO)
	if sala_objeto == null:
		sala_objeto = piso.sala_de_tipo(MapaSalas.Tipo.INICIO)
	_dejar(sala_objeto, Vector2.ZERO, disponibles, generador)

	var normales: Array[Sala] = []
	for sala in piso.salas():
		if sala.tipo == MapaSalas.Tipo.NORMAL:
			normales.append(sala)
	for _i in por_piso - 1:
		if normales.is_empty():
			return
		var sala: Sala = normales[generador.randi() % normales.size()]
		for _intento in 24:
			var sitio := sala.punto_al_azar(generador, 110.0)
			if sala.cerca_de_puerta(sitio, despeje):
				continue
			_dejar(sala, sitio, disponibles, generador)
			break


## Al morir un enemigo, a veces suelta una ventaja al azar.
##
## Aqui el azar NO sale de la semilla del piso, a diferencia del resto: los
## pisos son fijos, pero lo que suelta un enemigo es suerte, y tiene que poder
## cambiar de una partida a otra.
func _al_morir_enemigo(enemigo: Enemigo, sala: Sala, piso: Node,
		disponibles: Array[ObjetoMejora]) -> void:
	if enemigo.tipo == null or enemigo.tipo.es_cria:
		return
	if randf() >= probabilidad_al_matar:
		return
	# Donde murio si se puede, y si no, lo mas cerca posible (ver el piso).
	var sitio: Variant = piso.sitio_libre_cerca(enemigo.global_position, sala)
	if sitio == null:
		return
	var azar := RandomNumberGenerator.new()
	azar.randomize()
	_dejar(sala, sala.to_local(sitio), disponibles, azar)


func _dejar(sala: Sala, sitio: Vector2, disponibles: Array[ObjetoMejora],
		generador: RandomNumberGenerator) -> void:
	var objeto: Objeto = ESCENA_OBJETO.instantiate()
	sala.add_child(objeto)
	objeto.preparar(disponibles[generador.randi() % disponibles.size()],
		sala.to_global(sitio))


func _cargar() -> Array[ObjetoMejora]:
	var resultado: Array[ObjetoMejora] = []
	var carpeta := DirAccess.open(RUTA_OBJETOS)
	if carpeta == null:
		push_warning("No se puede abrir %s" % RUTA_OBJETOS)
		return resultado
	var nombres := carpeta.get_files()
	nombres.sort()
	for nombre in nombres:
		var limpio := nombre.trim_suffix(".remap")
		if limpio.get_extension().to_lower() != "tres":
			continue
		var recurso := load(RUTA_OBJETOS.path_join(limpio))
		if recurso is ObjetoMejora:
			resultado.append(recurso)
	return resultado
