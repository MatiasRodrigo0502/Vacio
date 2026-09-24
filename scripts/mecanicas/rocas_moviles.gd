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

## Espacio que se respeta alrededor de las puertas y del agujero de bajada:
## ninguna roca se acerca a menos de esto, ni en el extremo de su recorrido.
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

	for obstaculo in obstaculos:
		if generador.randf() > proporcion_moviles:
			continue
		# Cada roca va y viene dentro de SU sala. Con el pasillo de antes el
		# limite era el piso entero; con salas, una roca que se saliera de la
		# suya atravesaria el muro y apareceria en la de al lado.
		var sala: Sala = piso.sala_en(obstaculo.global_position)
		if sala == null:
			continue

		var horizontal := generador.randf() < proporcion_horizontales
		var direccion := Vector2.RIGHT if horizontal else Vector2.DOWN
		var amplitud := generador.randf_range(amplitud_minima, amplitud_maxima)
		amplitud = _recortar(amplitud, obstaculo, direccion, sala)

		if amplitud >= RECORRIDO_MINIMO:
			obstaculo.activar_vaiven(direccion, amplitud)


## Recorta el recorrido para que la roca no se salga de su sala ni se plante
## delante de una puerta o encima del agujero de bajada, que son los sitios
## por los que el jugador tiene que pasar si o si.
func _recortar(amplitud: float, obstaculo: Node2D, direccion: Vector2,
		sala: Sala) -> float:
	var centro: Vector2 = sala.to_local(obstaculo.global_position)
	var medio_tamano: Vector2 = obstaculo.tamano() * 0.5
	var medio_sala: Vector2 = sala.tamano * 0.5

	# Limite por los muros.
	if direccion.x != 0.0:
		amplitud = minf(amplitud, medio_sala.x - absf(centro.x) - medio_tamano.x - 20.0)
	else:
		amplitud = minf(amplitud, medio_sala.y - absf(centro.y) - medio_tamano.y - 20.0)

	# Limite por las puertas y el agujero.
	var puntos: Array[Vector2] = []
	for puerta in sala.puertas:
		puntos.append(sala.punto_puerta(puerta))
	if sala.tipo == MapaSalas.Tipo.SALIDA:
		puntos.append(Vector2.ZERO)
	for punto in puntos:
		var distancia: float = centro.distance_to(punto)
		amplitud = minf(amplitud, maxf(distancia - despeje_extremos, 0.0))

	return amplitud
