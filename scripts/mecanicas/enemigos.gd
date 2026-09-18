## Mecanica: reparte enemigos por el piso.
##
## Como las rocas moviles, no hay ni una linea de esto en el gestor ni en el
## piso: el gestor la carga de la carpeta y el piso la aplica sin saber que
## hace. Para que aparezcan antes o despues, `piso_desbloqueo`; para que haya
## mas o menos, `base` y `por_piso`; para quitarlos, `activa = false`.
class_name MecanicaEnemigos
extends Mecanica

const ESCENA_ENEMIGO := preload("res://scenes/Enemigo.tscn")

## Enemigos del primer piso en el que aparecen.
@export var base: int = 2
## Cuantos mas se anaden por cada piso que se baja.
@export var por_piso: float = 0.6
## Tope, para que el piso 12 no sea una pared de slimes.
@export var maximo: int = 9

## Espacio libre alrededor de la entrada y de la salida. Aparecer encima de un
## enemigo, o encontrarselo pegado al circulo de salida, seria injusto.
@export var despeje: float = 240.0


func aplicar_a_piso(piso: Node) -> void:
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
			enemigo.preparar(piso.to_global(sitio))
			break
