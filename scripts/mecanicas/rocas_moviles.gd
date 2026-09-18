## Mecanica: a partir de cierto piso, parte de las rocas van y vienen.
##
## No hay una sola linea de esto en gestor_progreso.gd ni en piso.gd. El gestor
## lee la carpeta de mecanicas, pregunta cual esta desbloqueada en este piso y
## el piso llama a aplicar_a_piso() sin saber que hace. Para desactivarla basta
## con poner activa = false en su .tres; para cambiarla de piso, tocar
## piso_desbloqueo. Nada de codigo.
class_name MecanicaRocasMoviles
extends Mecanica

## Recorrido minimo y maximo de cada roca, hacia cada lado del punto de partida.
@export var amplitud_minima: float = 70.0
@export var amplitud_maxima: float = 200.0

## Que parte de las rocas del piso se mueven. 1.0 serian todas.
@export_range(0.0, 1.0) var proporcion_moviles: float = 0.55

## Cuantas se mueven en horizontal frente a en vertical. En un juego donde se
## baja, las horizontales molestan mas y se leen mejor.
@export_range(0.0, 1.0) var proporcion_horizontales: float = 0.7

## Espacio que se respeta alrededor de la entrada y de la salida: ninguna roca
## se acerca a menos de esto, ni siquiera en el extremo de su recorrido.
@export var despeje_extremos: float = 190.0

## Recorrido minimo util. Por debajo, la roca se queda quieta: un vaiven de
## veinte pixeles no se aprecia y solo gasta un _physics_process.
const RECORRIDO_MINIMO: float = 35.0


func aplicar_a_piso(piso: Node) -> void:
	var obstaculos: Array = piso.obstaculos()
	if obstaculos.is_empty():
		return

	# Semilla derivada del piso, como el reparto de rocas: los 12 niveles tienen
	# que ser identicos en todas las partidas y en las tres maquinas del equipo.
	var generador := RandomNumberGenerator.new()
	generador.seed = hash(nombre_mecanica) + piso.numero_piso * 104729

	var entrada: Vector2 = piso.punto_entrada()
	var salida: Vector2 = piso.punto_salida()
	var mitad_ancho: float = piso.datos.ancho_area * 0.5
	var mitad_alto: float = piso.datos.alto_area * 0.5

	for obstaculo in obstaculos:
		if generador.randf() > proporcion_moviles:
			continue

		var horizontal := generador.randf() < proporcion_horizontales
		var direccion := Vector2.RIGHT if horizontal else Vector2.DOWN
		var amplitud := generador.randf_range(amplitud_minima, amplitud_maxima)
		amplitud = _recortar(amplitud, obstaculo, direccion, entrada, salida,
			mitad_ancho, mitad_alto, piso)

		if amplitud >= RECORRIDO_MINIMO:
			obstaculo.activar_vaiven(direccion, amplitud)


## Recorta el recorrido para que la roca no se salga del area ni invada la
## entrada o la salida. Sin esto, una roca del borde se saldria del piso y otra
## podria plantarse encima del circulo de salida, que es donde el jugador tiene
## que llegar si o si.
func _recortar(amplitud: float, obstaculo: Node2D, direccion: Vector2,
		entrada: Vector2, salida: Vector2, mitad_ancho: float, mitad_alto: float,
		piso: Node) -> float:
	var centro: Vector2 = piso.to_local(obstaculo.global_position)
	var medio_tamano: Vector2 = obstaculo.tamano() * 0.5

	# Limite por los muros.
	if direccion.x != 0.0:
		amplitud = minf(amplitud, mitad_ancho - absf(centro.x) - medio_tamano.x - 20.0)
	else:
		amplitud = minf(amplitud, mitad_alto - absf(centro.y) - medio_tamano.y - 20.0)

	# Limite por la entrada y la salida.
	for punto in [piso.to_local(entrada), piso.to_local(salida)]:
		var distancia: float = centro.distance_to(punto)
		amplitud = minf(amplitud, maxf(distancia - despeje_extremos, 0.0))

	return amplitud
