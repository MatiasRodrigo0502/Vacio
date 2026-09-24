## Mecanica: reparte enemigos por el piso.
##
## Como las rocas moviles, no hay ni una linea de esto en el gestor ni en el
## piso: el gestor la carga de la carpeta y el piso la aplica sin saber que
## hace. Para que aparezcan antes o despues, `piso_desbloqueo`; para que haya
## mas o menos por sala, `base`, `por_piso` y `maximo`; para quitarlos,
## `activa = false`.
class_name MecanicaEnemigos
extends Mecanica

const ESCENA_ENEMIGO := preload("res://scenes/Enemigo.tscn")
## Carpeta de tipos. Se lee entera: dejar un .tres nuevo ahi basta para que ese
## enemigo empiece a salir, sin tocar codigo ni esta mecanica.
const RUTA_TIPOS := "res://resources/enemigos"

## Enemigos por sala en el primer piso en el que aparecen.
@export var base: int = 1
## Cuantos mas por sala se anaden por cada piso que se baja.
@export var por_piso: float = 0.25
## Tope por sala. Isaac pone entre dos y seis; aqui las salas son mas pequenas.
@export var maximo: int = 4

## Espacio libre delante de cada puerta. Encontrarse un enemigo pegado a la
## puerta nada mas cruzarla seria un golpe sin tiempo de reaccionar.
@export var despeje: float = 200.0


var _tipos: Array[TipoEnemigo] = []


## Los reparte sala por sala.
##
## POR QUE POR SALA Y NO POR PISO:
## con salas, lo que importa es cuantos hay en cada una, porque cada sala es
## una pelea: las puertas se cierran al entrar y no se abren hasta limpiarla.
## Contarlos por piso haria que unas salas salieran vacias y otras llenas.
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
	var por_sala: int = base + int((piso.numero_piso - piso_desbloqueo) * por_piso)

	for sala in piso.salas():
		if not sala.admite_enemigos():
			continue
		# Uno de mas en algunas salas, para que no todas pesen igual.
		var cuantos: int = mini(por_sala + generador.randi_range(0, 1), maximo)
		for _i in cuantos:
			for _intento in 20:
				var sitio: Vector2 = sala.punto_al_azar(generador, 90.0)
				if sala.cerca_de_puerta(sitio, despeje):
					continue
				# En la sala de salida, tampoco encima del agujero.
				if sala.tipo == MapaSalas.Tipo.SALIDA and sitio.length() < despeje * 0.6:
					continue

				var enemigo: Enemigo = ESCENA_ENEMIGO.instantiate()
				# Hijo de su sala y no del piso: asi la sala sabe quien vive en
				# ella y puede despertarlos al entrar el jugador.
				sala.add_child(enemigo)
				enemigo.preparar(disponibles[generador.randi() % disponibles.size()],
					sala.to_global(sitio))
				sala.registrar_enemigo(enemigo)
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
