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

@export_group("Pinchos alrededor del cofre")
## En algunos pisos el cofre de la sala secreta esta rodeado de pinchos (Matias,
## 2026-11-10: «pon trampas de pinchos alrededor de algunos cofres»). Un anillo de
## placas que salen todas a la vez: para llegar al cofre, y para irse con la
## ventaja, hay que esperar a que bajen.
@export_range(1, 12) var piso_pinchos_cofre: int = 2
## De cada piso desde 'piso_pinchos_cofre', la probabilidad de que su cofre los tenga.
@export_range(0.0, 1.0) var probabilidad_cofre: float = 0.5

@export_group("Pasillo de pinchos")
## En una sala de pelea de cada piso, un pasillo con una fila de pinchos a cada lado
## (Matias, 2026-11-10: «haz un pasillo entre trampas de pinchos en una sala»): de
## una puerta a la de enfrente o, si no hay, de una puerta al centro. Por el pasillo
## no se pisa nada; salirse de el, a destiempo, si.
@export_range(1, 12) var piso_pasillo: int = 3
## Ancho del paso libre entre las dos filas. El mago mide 30.
@export var ancho_pasillo: float = 120.0

## Lado de la placa de una puerta: casi el ancho del hueco, para que no se
## pueda pasar por un lado. Con el jugador midiendo 30 px, los 5 de cada lado
## no le dejan colarse.
const LADO_PUERTA: float = Sala.ANCHO_PUERTA - 10.0
## Lado de cada placa del anillo del cofre: cuatro por lado, con un hueco de
## 200 x 200 en medio, donde cabe el cofre (146 de ancho) y se pisa sin tocarlas.
const LADO_ANILLO: float = 100.0
## Lado de cada placa de las filas del pasillo.
const LADO_PASILLO: float = 90.0
## Lo que se aparta de la pared el pasillo al empezar: la placa de la puerta,
## cuando la hay, llega a 120 de la pared, pero va en medio y las filas a los lados.
const MARGEN_PASILLO: float = 70.0
## Lo que tarda la onda de los pinchos en ir de una punta del pasillo a la otra.
const ONDA_PASILLO: float = 1.2


func aplicar_a_piso(piso: Node) -> void:
	_pinchos_en_puertas(piso)
	# Antes que los de al azar, que asi lo esquivan.
	_pasillo(piso)
	_repartir(piso)
	_pinchos_del_cofre(piso)
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


## Rodea el cofre de la sala secreta con un anillo de pinchos, en algunos pisos.
## Todas las placas con el mismo ritmo: es una sola trampa, y lo que se ve es
## cuando se puede pasar.
func _pinchos_del_cofre(piso: Node) -> void:
	var secreta: Sala = piso.sala_secreta()
	if secreta == null or piso.numero_piso < piso_pinchos_cofre:
		return
	var generador := RandomNumberGenerator.new()
	generador.seed = hash(nombre_mecanica + " cofre") + piso.numero_piso * 7727
	if generador.randf() >= probabilidad_cofre:
		return
	var sitios: Array[Vector2] = []
	for i in 4:
		for j in 4:
			if i == 0 or i == 3 or j == 0 or j == 3:
				sitios.append(Vector2(i - 1.5, j - 1.5) * LADO_ANILLO)
	var desfase := generador.randf() * (Pinchos.DENTRO + Pinchos.AVISO + Pinchos.FUERA)
	for sitio in sitios:
		var pinchos := _colocar(piso, secreta, "pinchos", sitio, Vector2.ONE * LADO_ANILLO, generador) as Pinchos
		pinchos.desfase = desfase


## El pasillo entre pinchos de una sala del piso, elegida al azar (con su semilla).
## Mejor una con dos puertas enfrente: ahi el pasillo cruza la sala entera; si no
## hay ninguna, va de una puerta al centro. Quita las rocas que tenga en medio y
## salta las placas que caerian en un bulto de la pared o en otro peligro (la placa
## de la puerta).
func _pasillo(piso: Node) -> void:
	if piso.numero_piso < piso_pasillo:
		return
	var generador := RandomNumberGenerator.new()
	generador.seed = hash(nombre_mecanica + " pasillo") + piso.numero_piso * 7727
	var cruzan: Array = []
	var al_centro: Array = []
	for sala in piso.salas():
		if not sala.admite_enemigos() or sala.tiene_bajada():
			continue
		var puertas: Array[Vector2i] = sala.puertas_visibles()
		for direccion in [Vector2i.LEFT, Vector2i.UP]:
			if direccion in puertas and -direccion in puertas:
				cruzan.append([sala, sala.punto_puerta(direccion) - Vector2(direccion) * MARGEN_PASILLO,
					sala.punto_puerta(-direccion) + Vector2(direccion) * MARGEN_PASILLO])
		for direccion in puertas:
			al_centro.append([sala, sala.punto_puerta(direccion) - Vector2(direccion) * MARGEN_PASILLO, Vector2.ZERO])
	_barajar(cruzan, generador)
	_barajar(al_centro, generador)
	var opciones := cruzan + al_centro
	if opciones.is_empty():
		return
	var sala: Sala = opciones[0][0]
	var desde: Vector2 = opciones[0][1]
	var hasta: Vector2 = opciones[0][2]
	var lado := (hasta - desde).normalized().orthogonal() * (ancho_pasillo * 0.5 + LADO_PASILLO)
	var zona := Rect2(sala.to_global(desde + lado), Vector2.ZERO).expand(sala.to_global(desde - lado)) \
			.expand(sala.to_global(hasta + lado)).expand(sala.to_global(hasta - lado))
	piso.quitar_rocas_en(zona)
	# Una onda que recorre el pasillo: las placas salen una detras de otra, de una
	# punta a la otra, en vez de todas a la vez o cada una a su aire.
	var largo := desde.distance_to(hasta)
	# Primero se miran todas y luego se ponen: puesta una, la de al lado ya no
	# estaria libre (lugar_libre mira tambien los peligros).
	var libres: Array[Vector2] = []
	for sitio in _sitios_pasillo(sala, desde, hasta):
		# Sin mirar a los enemigos: ya estan repartidos, y en cuanto entras se mueven.
		if piso.lugar_libre(sala.to_global(sitio), LADO_PASILLO * 0.5, false):
			libres.append(sitio)
	for sitio in libres:
		var pinchos := _colocar(piso, sala, "pinchos", sitio, Vector2.ONE * LADO_PASILLO, generador) as Pinchos
		pinchos.desfase = desde.distance_to(sitio) / largo * ONDA_PASILLO


## Los centros de las placas de las dos filas de un pasillo que va de 'desde' a
## 'hasta' (en la sala): una a cada lado del paso libre, pegadas unas a otras. Con
## un hueco donde sale el paso del centro a otra puerta de la sala, de lado: si no,
## para ir a ella habria que cruzar los pinchos.
func _sitios_pasillo(sala: Sala, desde: Vector2, hasta: Vector2) -> Array[Vector2]:
	var eje := (hasta - desde).normalized()
	var cuantas := int(desde.distance_to(hasta) / LADO_PASILLO)
	var lado := eje.orthogonal() * (ancho_pasillo + LADO_PASILLO) * 0.5
	var sitios: Array[Vector2] = []
	for i in cuantas:
		var centro := desde + eje * LADO_PASILLO * (i + 0.5)
		for sitio in [centro + lado, centro - lado]:
			if not _tapa_otro_paso(sala, eje, sitio):
				sitios.append(sitio)
	return sitios


## True si la placa en 'sitio' queda en el paso del centro a una puerta que sale de
## lado del pasillo (que va a lo largo de 'eje').
func _tapa_otro_paso(sala: Sala, eje: Vector2, sitio: Vector2) -> bool:
	for puerta in sala.puertas_visibles():
		var hacia := Vector2(puerta)
		if absf(hacia.dot(eje)) > 0.5 or sitio.dot(hacia) <= 0.0:
			continue
		if absf(sitio.dot(eje)) < (ancho_paso + LADO_PASILLO) * 0.5:
			return true
	return false


## Fisher-Yates con el generador del piso: shuffle() tira de la suerte global y
## los pisos tienen que salir siempre iguales.
func _barajar(lista: Array, generador: RandomNumberGenerator) -> void:
	for i in range(lista.size() - 1, 0, -1):
		var j := generador.randi() % (i + 1)
		var otro: Variant = lista[i]
		lista[i] = lista[j]
		lista[j] = otro


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
		generador: RandomNumberGenerator) -> Peligro:
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
	return peligro
