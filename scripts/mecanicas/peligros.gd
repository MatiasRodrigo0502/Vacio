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
## Nada de peligros al azar delante de las puertas: cruzar una puerta y caer a
## un agujero seria un golpe que no se puede ver venir. Los pinchos de las
## puertas son aparte (ver "Pinchos en las puertas").
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

@export_group("Pinchos en las puertas")
## Algunas puertas tienen pinchos justo al cruzarlas, de lado a lado del paso.
##
## POR QUE PINCHOS SI Y AGUJEROS O LAVA NO:
## los pinchos salen a ratos y avisan antes (asoman y tiemblan), y se ven
## desde el pasillo, antes de entrar. Se cruzan esperando a que bajen. Un
## agujero o lava en la puerta no se podria cruzar sin pagarlo.
@export_range(1, 12) var piso_pinchos_puerta: int = 3
## De cada puerta que da a una sala de pelea, la probabilidad de que tenga.
@export_range(0.0, 1.0) var probabilidad_puerta: float = 0.4

@export_group("Trampas de hielo")
## Cuantas trampas de pinchos pasan a ser de hielo (TrampaHielo: frenan en
## vez de pinchar), repartidas al azar entre los pisos de 'pisos_hielo'.
## Pedido por Matias el 2026-11-03: «sustituye 5 trampas de pinchos al azar a
## repartir entre los pisos 9, 10, 11 y 12».
@export var trampas_hielo: int = 5
@export var pisos_hielo: Vector2i = Vector2i(9, 12)

## Lado de la placa de una puerta: casi el ancho del hueco, para que no se
## pueda pasar por un lado. Con el jugador midiendo 30 px, los 5 de cada lado
## no le dejan colarse.
const LADO_PUERTA: float = Sala.ANCHO_PUERTA - 10.0


func aplicar_a_piso(piso: Node) -> void:
	_pinchos_en_puertas(piso)
	_repartir(piso)
	# Al final, con todos los pinchos ya puestos (los de las puertas tambien).
	_poner_hielo(piso)


## Cuantas trampas de hielo le tocan a ese piso: las 'trampas_hielo'
## repartidas entre los pisos de 'pisos_hielo', a partes iguales y las que
## sobran a pisos al azar (con 5 en 4 pisos: una en cada uno y otra mas en
## uno). Al azar del todo, con la primera semilla salian 1, 0, 0 y 4: dos
## pisos sin ninguna no es repartirlas. La semilla es fija: el reparto sale
## siempre igual, como todo lo de los pisos.
func hielo_en_piso(numero: int) -> int:
	if numero < pisos_hielo.x or numero > pisos_hielo.y:
		return 0
	var pisos := pisos_hielo.y - pisos_hielo.x + 1
	var cuantas := trampas_hielo / pisos
	var generador := RandomNumberGenerator.new()
	generador.seed = hash(nombre_mecanica + " reparto del hielo")
	var con_una_mas: Array[int] = []
	for piso in range(pisos_hielo.x, pisos_hielo.y + 1):
		con_una_mas.append(piso)
	for _i in trampas_hielo % pisos:
		if con_una_mas.pop_at(generador.randi() % con_una_mas.size()) == numero:
			cuantas += 1
	return cuantas


## Cambia por trampas de hielo las pinchos que le toquen a este piso, elegidos
## al azar (con la semilla del piso) entre todos los suyos, los de las puertas
## tambien. La trampa nueva va en el mismo sitio, del mismo tamano y con el
## mismo ritmo: solo cambia lo que sale del suelo.
func _poner_hielo(piso: Node) -> void:
	var cuantas := hielo_en_piso(piso.numero_piso)
	if cuantas <= 0:
		return
	var pinchos: Array[Pinchos] = []
	for sala in piso.salas():
		for hijo in sala.get_children():
			if hijo is Pinchos and not hijo is TrampaHielo:
				pinchos.append(hijo)
	var generador := RandomNumberGenerator.new()
	generador.seed = hash(nombre_mecanica + " hielo") + piso.numero_piso * 7727
	for _i in mini(cuantas, pinchos.size()):
		var cual: Pinchos = pinchos.pop_at(generador.randi() % pinchos.size())
		var hielo := TrampaHielo.new()
		hielo.desfase = cual.desfase
		hielo.tinte = cual.tinte
		hielo.tamano = cual.tamano
		hielo.color_suelo = cual.color_suelo
		hielo.color_borde = cual.color_borde
		hielo.position = cual.position
		var sala: Node = cual.get_parent()
		var sitio := cual.get_index()
		sala.remove_child(cual)
		cual.queue_free()
		sala.add_child(hielo)
		sala.move_child(hielo, sitio)


## Los peligros al azar de cada sala de pelea.
func _repartir(piso: Node) -> void:
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


## Pone pinchos en la entrada de algunas puertas, por dentro de la sala.
##
## Cada puerta se decide una sola vez aunque la compartan dos salas, y la
## trampa va en el lado de la sala de pelea: una puerta con pinchos a los dos
## lados serian dos trampas seguidas.
func _pinchos_en_puertas(piso: Node) -> void:
	if piso.numero_piso < piso_pinchos_puerta:
		return
	var generador := RandomNumberGenerator.new()
	# Semilla aparte de la del resto de peligros: con la misma, anadir esto
	# habria movido todos los que ya habia en los 12 pisos.
	generador.seed = hash(nombre_mecanica + "puertas") + piso.numero_piso * 7727
	var decididas := {}
	for sala in piso.salas():
		if not sala.admite_enemigos():
			continue
		# La escondida no: unos pinchos delante de una pared la delatarian.
		for puerta in sala.puertas_visibles():
			var clave := [sala.celda, sala.celda + puerta]
			clave.sort()
			if decididas.has(str(clave)):
				continue
			decididas[str(clave)] = true
			if generador.randf() >= probabilidad_puerta:
				continue
			# Pegada al filo del suelo, entrando en la sala: lo primero que se
			# pisa al cruzar. Por fuera, en el pasillo, la tapaba el rastrillo.
			var sitio: Vector2 = sala.punto_puerta(puerta) - Vector2(puerta) * LADO_PUERTA * 0.5
			# Solo el centro: a los lados del paso esta la pared, y
			# con la placa entera nunca saldria libre.
			if not piso.lugar_libre(sala.to_global(sitio), 30.0):
				continue
			_colocar(piso, sala, "pinchos", sitio, Vector2.ONE * LADO_PUERTA, generador)
			sala.anadir_trampa_puerta(puerta, LADO_PUERTA)


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
	if sala.tiene_bajada() and sitio.length() < despeje_salida + medio:
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
			pinchos.tinte = piso.tinte_profundidad()
			peligro = pinchos
		"vacio":
			var vacio := Vacio.new()
			vacio.tinte = piso.tinte_profundidad()
			peligro = vacio
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
	# Con un margen: una china pegada al borde tambien se veria encima.
	piso.despejar_decoracion(Rect2(sala.to_global(sitio) - tamano * 0.5, tamano).grow(14.0))
