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
@export var base: int = 3
## Cuantos mas por sala se anaden por cada piso que se baja.
@export var por_piso: float = 0.5
## Tope por sala. Isaac pone entre dos y seis.
@export var maximo: int = 9

## Que parte de cada sala pueden ser enemigos a distancia, como mucho. Una sala
## solo de tiradores es una lluvia de disparos desde todas partes; con la mitad
## como tope, siempre hay alguien que viene a por ti y alguien que te cubre.
@export_range(0.0, 1.0) var proporcion_distancia: float = 0.5

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

	# Separados por forma de pelear, para poder limitar los de distancia.
	var cuerpo_a_cuerpo: Array[TipoEnemigo] = []
	var a_distancia: Array[TipoEnemigo] = []
	for tipo in disponibles:
		if tipo.es_a_distancia():
			a_distancia.append(tipo)
		else:
			cuerpo_a_cuerpo.append(tipo)

	var generador := RandomNumberGenerator.new()
	# Semilla propia derivada del piso: los 12 niveles siguen siendo iguales en
	# todas las partidas y en las tres maquinas del equipo.
	generador.seed = hash(nombre_mecanica) + piso.numero_piso * 31013
	var esperados := media_por_sala(piso.numero_piso)

	for sala in piso.salas():
		if not sala.admite_enemigos():
			continue
		var cuantos := _redondear_al_azar(esperados, generador)
		var tope_distancia := ceili(cuantos * proporcion_distancia)
		var de_distancia := 0
		for _i in cuantos:
			# El tipo se elige antes que el sitio: el hueco que necesita
			# depende de lo grande que sea. Al azar entre todos, salvo que la
			# sala ya tenga su cupo de tiradores.
			var tipo: TipoEnemigo = disponibles[generador.randi() % disponibles.size()]
			if tipo.es_a_distancia() and de_distancia >= tope_distancia 					and not cuerpo_a_cuerpo.is_empty():
				tipo = cuerpo_a_cuerpo[generador.randi() % cuerpo_a_cuerpo.size()]
			for _intento in 30:
				var sitio: Vector2 = sala.punto_al_azar(generador, 90.0)
				if sala.cerca_de_puerta(sitio, despeje):
					continue
				# En la sala de salida, tampoco encima del agujero.
				if sala.tipo == MapaSalas.Tipo.SALIDA and sitio.length() < despeje * 0.6:
					continue
				# Ni encima de rocas, peligros u otros enemigos. Las rocas
				# importan mas de lo que parece: el cristal vivo no se mueve, y
				# enterrado en una, la bola chocaria con la roca antes de
				# llegarle y la sala podria no abrirse.
				if not piso.lugar_libre(sala.to_global(sitio), tipo.alto * 0.5):
					continue

				var enemigo: Enemigo = ESCENA_ENEMIGO.instantiate()
				# Hijo de su sala y no del piso: asi la sala sabe quien vive en
				# ella y puede despertarlos al entrar el jugador.
				sala.add_child(enemigo)
				enemigo.preparar(tipo, sala.to_global(sitio))
				sala.registrar_enemigo(enemigo)
				if tipo.es_a_distancia():
					de_distancia += 1
				break


## Cuantos enemigos salen de media en cada sala de ese piso.
##
## Sube lo mismo en cada piso (`por_piso`), sin saltos: la media de un piso
## nunca es menor que la del de arriba. Antes se sumaba un enemigo de mas al
## azar en algunas salas, y eso hacia que un piso pudiera salir mas flojo que
## el anterior (del 7 al 9 la media bajaba: 4,7 / 4,5 / 4,3).
func media_por_sala(numero_piso: int) -> float:
	return minf(base + (numero_piso - piso_desbloqueo) * por_piso, maximo)


## La parte entera siempre, y uno mas con la probabilidad de la parte
## decimal: con 2,4 de media, el 60 % de las salas tienen 2 y el 40 % tienen 3.
## Asi hay salas mas cargadas que otras y la media es justo la que toca.
func _redondear_al_azar(media: float, generador: RandomNumberGenerator) -> int:
	var cuantos := int(media)
	if generador.randf() < media - cuantos:
		cuantos += 1
	return mini(cuantos, maximo)


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
