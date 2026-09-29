## Mecanica: reparte peligros por el suelo de las salas de pelea. Pinchos que
## salen a ratos, charcos de lava y agujeros por los que caerse.
##
## Como las demas mecanicas, ni el gestor ni el piso saben que existe. Para
## cambiar desde que piso sale cada peligro, los `piso_*`; para que haya mas
## o menos, `base`, `por_piso` y `maximo`; para quitarlos, `activa = false`.
class_name MecanicaPeligros
extends Mecanica

@export_group("Desde que piso")
## Los pinchos son los primeros: avisan antes de salir, asi que ensenan que
## el suelo tambien hace dano sin castigar de mas.
@export_range(1, 12) var piso_pinchos: int = 2
@export_range(1, 12) var piso_vacio: int = 3
## La lava, en el manto y el nucleo, que es donde la roca esta fundida.
@export_range(1, 12) var piso_lava: int = 4

@export_group("Cuantos")
## Peligros por sala en el primer piso en el que aparecen.
@export var base: int = 1
## Cuantos mas por sala por cada piso que se baja.
@export var por_piso: float = 0.25
## Tope por sala: las salas del fondo son pequenas, y con mas no quedaria
## suelo para pelear.
@export var maximo: int = 3

@export_group("Espacio que se respeta")
## Nada de peligros delante de las puertas: cruzar una puerta y caer a un
## agujero seria un golpe que no se puede ver venir.
@export var despeje_puerta: float = 210.0
## Ancho del paso libre desde el centro de la sala hasta cada puerta.
##
## POR QUE HACE FALTA:
## repartidos al azar, dos peligros juntos podrian cerrar el camino a una
## puerta. Con estos pasos libres, de cualquier puerta se llega al centro y
## del centro a cualquier otra puerta sin pisar nada.
@export var ancho_paso: float = 160.0
## Espacio libre alrededor del agujero de bajada.
@export var despeje_salida: float = 170.0


func aplicar_a_piso(piso: Node) -> void:
	var clases: Array[String] = []
	if piso.numero_piso >= piso_pinchos:
		clases.append("pinchos")
	if piso.numero_piso >= piso_vacio:
		clases.append("vacio")
	if piso.numero_piso >= piso_lava:
		clases.append("lava")
	if clases.is_empty():
		return

	var generador := RandomNumberGenerator.new()
	# Semilla del piso, como todo lo demas: los 12 niveles son fijos.
	generador.seed = hash(nombre_mecanica) + piso.numero_piso * 7727
	var esperados := minf(base + (piso.numero_piso - piso_desbloqueo) * por_piso, maximo)

	for sala in piso.salas():
		# Donde hay pelea. El inicio y la sala del objeto van limpios, como
		# con las rocas.
		if not sala.admite_enemigos():
			continue
		# Como los enemigos: la parte decimal de la media, al azar. Asi sube
		# poco a poco con el piso y no a saltos.
		var cuantos := int(esperados)
		if generador.randf() < esperados - cuantos:
			cuantos += 1
		for _i in cuantos:
			var clase: String = clases[generador.randi() % clases.size()]
			var tamano := _tamano(clase, sala, generador)
			for _intento in 30:
				var sitio: Vector2 = sala.punto_al_azar(generador, maxf(tamano.x, tamano.y) * 0.5 + 24.0)
				if not _sitio_valido(piso, sala, sitio, tamano):
					continue
				_colocar(piso, sala, clase, sitio, tamano, generador)
				break


## Medidas segun el peligro y el tamano de la sala: en las salas pequenas del
## fondo, un agujero del tamano de los de arriba ocuparia media sala.
func _tamano(clase: String, sala: Sala, generador: RandomNumberGenerator) -> Vector2:
	var escala := clampf(sala.tamano.x / 1400.0, 0.7, 1.0)
	match clase:
		"pinchos":
			return Vector2.ONE * generador.randf_range(84.0, 120.0) * escala
		"vacio":
			return Vector2(generador.randf_range(110.0, 190.0),
				generador.randf_range(90.0, 150.0)) * escala
		_:
			return Vector2.ONE * generador.randf_range(90.0, 150.0) * escala


func _sitio_valido(piso: Node, sala: Sala, sitio: Vector2, tamano: Vector2) -> bool:
	var medio := maxf(tamano.x, tamano.y) * 0.5
	if sala.cerca_de_puerta(sitio, despeje_puerta + medio):
		return false
	if sala.tipo == MapaSalas.Tipo.SALIDA and sitio.length() < despeje_salida + medio:
		return false
	for puerta in sala.puertas:
		var paso := Geometry2D.get_closest_point_to_segment(sitio, Vector2.ZERO,
			sala.punto_puerta(puerta))
		if sitio.distance_to(paso) < ancho_paso * 0.5 + medio:
			return false
	return piso.lugar_libre(sala.to_global(sitio), medio)


func _colocar(piso: Node, sala: Sala, clase: String, sitio: Vector2, tamano: Vector2,
		generador: RandomNumberGenerator) -> void:
	var peligro: Peligro
	match clase:
		"pinchos":
			var pinchos := Pinchos.new()
			# Cada trampa con su ritmo: todas a la vez serian un semaforo.
			pinchos.desfase = generador.randf() * (Pinchos.DENTRO + Pinchos.AVISO + Pinchos.FUERA)
			peligro = pinchos
		"vacio":
			peligro = Vacio.new()
		_:
			var lava := Lava.new()
			lava.radio = tamano.x * 0.5
			peligro = lava
	peligro.tamano = tamano
	peligro.color_suelo = sala.color_suelo()
	peligro.color_borde = sala.color_borde()
	peligro.position = sitio
	sala.add_child(peligro)
	# El primero de la sala: se pinta justo encima del suelo y debajo de los
	# enemigos, que son hijos de la sala igual que el.
	sala.move_child(peligro, 0)
	piso.despejar_decoracion(Rect2(sala.to_global(sitio) - tamano * 0.5, tamano))
