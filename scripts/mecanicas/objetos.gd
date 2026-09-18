## Mecanica: deja un objeto por piso.
##
## Como las demas, no hay ni una linea de esto en el gestor ni en el piso. Y
## como los enemigos, lee su carpeta entera: para anadir un objeto basta con
## dejar otro .tres en resources/objetos/.
class_name MecanicaObjetos
extends Mecanica

const ESCENA_OBJETO := preload("res://scenes/Objeto.tscn")
const RUTA_OBJETOS := "res://resources/objetos"

## Cuantos objetos deja por piso.
@export var por_piso: int = 1

## Espacio libre alrededor de la entrada y de la salida. Un objeto pegado a la
## salida se cogeria sin merito; pegado a la entrada, sin verlo.
@export var despeje: float = 260.0

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

	var entrada: Vector2 = piso.to_local(piso.punto_entrada())
	var salida: Vector2 = piso.to_local(piso.punto_salida())
	var mitad_ancho: float = piso.datos.ancho_area * 0.5
	var mitad_alto: float = piso.datos.alto_area * 0.5

	for _i in por_piso:
		for _intento in 24:
			var sitio := Vector2(
				generador.randf_range(-mitad_ancho + 110.0, mitad_ancho - 110.0),
				generador.randf_range(-mitad_alto + 200.0, mitad_alto - 200.0))
			if sitio.distance_to(entrada) < despeje:
				continue
			if sitio.distance_to(salida) < despeje:
				continue

			var objeto: Objeto = ESCENA_OBJETO.instantiate()
			piso.add_child(objeto)
			objeto.preparar(disponibles[generador.randi() % disponibles.size()],
				piso.to_global(sitio))
			break


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
