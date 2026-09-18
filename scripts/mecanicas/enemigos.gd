## Mecanica: reparte enemigos por el piso.
##
## Como las rocas moviles, no hay ni una linea de esto en el gestor ni en el
## piso: el gestor la carga de la carpeta y el piso la aplica sin saber que
## hace. Para que aparezcan antes o despues, `piso_desbloqueo`; para que haya
## mas o menos, `base` y `por_piso`; para quitarlos, `activa = false`.
class_name MecanicaEnemigos
extends Mecanica

const ESCENA_ENEMIGO := preload("res://scenes/Enemigo.tscn")
## Carpeta de tipos. Se lee entera: dejar un .tres nuevo ahi basta para que ese
## enemigo empiece a salir, sin tocar codigo ni esta mecanica.
const RUTA_TIPOS := "res://resources/enemigos"

## Enemigos del primer piso en el que aparecen.
@export var base: int = 2
## Cuantos mas se anaden por cada piso que se baja.
@export var por_piso: float = 0.6
## Tope, para que el piso 12 no sea una pared de slimes.
@export var maximo: int = 9

## Espacio libre alrededor de la entrada y de la salida. Aparecer encima de un
## enemigo, o encontrarselo pegado al circulo de salida, seria injusto.
@export var despeje: float = 240.0


var _tipos: Array[TipoEnemigo] = []


func aplicar_a_piso(piso: Node) -> void:
	if _tipos.is_empty():
		_tipos = _cargar_tipos()
	# Solo los que ya pueden salir a esta profundidad.
	var disponibles: Array[TipoEnemigo] = []
	for tipo in _tipos:
		if piso.numero_piso >= tipo.piso_minimo:
			disponibles.append(tipo)
	if disponibles.is_empty():
		return

	var generador := RandomNumberGenerator.new()
	# Semilla propia derivada del piso: los 12 niveles siguen siendo iguales en
	# todas las partidas y en las tres maquinas del equipo.
	generador.seed = hash(nombre_mecanica) + piso.numero_piso * 31013

	var cuantos: int = mini(
		base + int((piso.numero_piso - piso_desbloqueo) * por_piso), maximo)
	var entrada: Vector2 = piso.to_local(piso.punto_entrada())
	var salida: Vector2 = piso.to_local(piso.punto_salida())
	var mitad_ancho: float = piso.datos.ancho_area * 0.5
	var mitad_alto: float = piso.datos.alto_area * 0.5

	for _i in cuantos:
		for _intento in 20:
			var sitio := Vector2(
				generador.randf_range(-mitad_ancho + 90.0, mitad_ancho - 90.0),
				generador.randf_range(-mitad_alto + 150.0, mitad_alto - 150.0))
			if sitio.distance_to(entrada) < despeje:
				continue
			if sitio.distance_to(salida) < despeje:
				continue

			var enemigo: Enemigo = ESCENA_ENEMIGO.instantiate()
			piso.add_child(enemigo)
			enemigo.preparar(disponibles[generador.randi() % disponibles.size()],
				piso.to_global(sitio))
			break


## Lee la carpeta de tipos, ordenada por nombre de archivo para que el reparto
## sea igual en todas las maquinas.
func _cargar_tipos() -> Array[TipoEnemigo]:
	var resultado: Array[TipoEnemigo] = []
	var carpeta := DirAccess.open(RUTA_TIPOS)
	if carpeta == null:
		push_warning("No se puede abrir %s" % RUTA_TIPOS)
		return resultado
	var nombres := carpeta.get_files()
	nombres.sort()
	for nombre in nombres:
		var limpio := nombre.trim_suffix(".remap")
		if limpio.get_extension().to_lower() != "tres":
			continue
		var recurso := load(RUTA_TIPOS.path_join(limpio))
		if recurso is TipoEnemigo:
			resultado.append(recurso)
	return resultado
