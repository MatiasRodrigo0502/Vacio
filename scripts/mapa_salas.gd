## El plano de un piso: que salas hay, en que casilla esta cada una y cual es
## cual (inicio, normal, objeto, salida y, en el piso del jefe, antesala y
## sala del jefe).
##
## POR QUE VA SEPARADO DE LA CONSTRUCCION DE LAS SALAS:
## decidir la forma del mapa no necesita ni un nodo; construirlo (muros, suelo,
## rocas) si. Asi el plano se genera y se comprueba en un test sin montar
## ninguna escena, y quien quiera retocar la forma de los mapas no tiene que
## abrir piso.gd.
##
## El mapa es una cuadricula: cada sala ocupa una casilla y las puertas unen
## salas vecinas. Es como lo hace The Binding of Isaac, y tiene la ventaja de
## que colocar las salas en el mundo es multiplicar la casilla por un paso fijo.
class_name MapaSalas
extends RefCounted

## ANTESALA y JEFE solo los tiene un piso con jefe (DatosPiso.sala_jefe): la
## sala del jefe hace de salida (la bajada esta en ella) y no hay SALIDA.
## SECRETA, una en cada piso (ver _anadir_secreta). Va la ultima para no
## cambiar el numero de las demas.
enum Tipo { INICIO, NORMAL, OBJETO, SALIDA, ANTESALA, JEFE, SECRETA }

## Las cuatro direcciones en que puede haber puerta.
const DIRECCIONES: Array[Vector2i] = [
	Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT,
]

## Casillas ocupadas, en el orden en que se crearon. La primera es el inicio.
var celdas: Array[Vector2i] = []

var _ocupadas: Dictionary = {}
var _tipos: Dictionary = {}
var _distancias: Dictionary = {}
## Las casillas que ocupa la sala del jefe ademas de la suya (es mas grande que
## una casilla). No son salas: nadie tiene puerta hacia ellas.
var _reservadas: Array[Vector2i] = []
## Hacia donde se va de la antesala a la sala del jefe. ZERO si no hay jefe.
var direccion_jefe: Vector2i = Vector2i.ZERO
## La sala de la que cuelga la secreta (por su puerta escondida) y hacia
## donde queda la secreta desde ella. ZERO si el piso se ha quedado sin.
var padre_secreta: Vector2i = Vector2i.ZERO
var direccion_secreta: Vector2i = Vector2i.ZERO


## Genera el plano de un piso.
##
## La semilla la pone el piso a partir de su numero: el mapa es aleatorio pero
## el mismo en todas las partidas y en las tres maquinas del equipo, igual que
## lo eran los pisos de antes. "Doce niveles fijos" sigue siendo verdad.
##
## 'jefe' es lo que mide la sala del jefe, con sus muros, contado en casillas
## (1,5 = casilla y media). Vector2.ZERO = el piso no tiene jefe.
##
## 'en_fila': las salas salen una detras de otra, sin ramas. Lo pide el piso
## del tutorial, que ensena una cosa en cada sala y en orden: asi «la tercera
## sala» es siempre la tercera que se cruza. En fila, la salida es la ultima y
## el objeto la penultima (no hay callejones; ver _repartir_tipos).
static func generar(cantidad: int, semilla: int, jefe: Vector2 = Vector2.ZERO,
		en_fila: bool = false) -> MapaSalas:
	var mapa := MapaSalas.new()
	# Menos de tres no da para inicio, objeto y salida.
	mapa._crecer(maxi(cantidad, 3), semilla, en_fila)
	mapa._medir_distancias()
	if jefe != Vector2.ZERO and mapa._anadir_jefe(jefe):
		mapa._medir_distancias()
	mapa._repartir_tipos()
	# Despues de repartir los tipos: si no, siendo la mas lejana, la secreta
	# podria quedarse con la salida o con el objeto.
	mapa._anadir_secreta(semilla)
	return mapa


## True si este piso tiene sala secreta (todos, salvo que no quepa).
func tiene_secreta() -> bool:
	return direccion_secreta != Vector2i.ZERO


func tiene(celda: Vector2i) -> bool:
	return _ocupadas.has(celda)


func tipo_de(celda: Vector2i) -> Tipo:
	return _tipos.get(celda, Tipo.NORMAL)


## Cuantas puertas hay que cruzar desde el inicio hasta esa sala.
func distancia_de(celda: Vector2i) -> int:
	return _distancias.get(celda, -1)


## La primera sala de ese tipo, o (0, 0) si no hay ninguna.
func celda_de(tipo: Tipo) -> Vector2i:
	for celda in celdas:
		if _tipos[celda] == tipo:
			return celda
	return Vector2i.ZERO


## Las casillas que ocupa la sala del jefe, la suya y las de alrededor que
## tapa por ser mas grande. Vacio si no hay jefe.
func casillas_del_jefe() -> Array[Vector2i]:
	if direccion_jefe == Vector2i.ZERO:
		return []
	var todas: Array[Vector2i] = [celda_de(Tipo.JEFE)]
	todas.append_array(_reservadas)
	return todas


## Direcciones en las que esa sala tiene vecina, o sea, puerta.
func puertas_de(celda: Vector2i) -> Array[Vector2i]:
	var resultado: Array[Vector2i] = []
	for direccion in DIRECCIONES:
		if _ocupadas.has(celda + direccion):
			resultado.append(direccion)
	return resultado


# --- Generacion -------------------------------------------------------------

## Hace crecer el mapa desde el inicio, pegando salas a las que ya hay.
##
## LA REGLA QUE LE DA FORMA:
## una casilla nueva solo se acepta si toca a UNA sala. Sin esa regla el mapa
## sale como un bloque macizo donde todo esta al lado de todo; con ella sale
## ramificado, con pasillos y callejones sin salida. Los callejones son los que
## dan sitio a la sala del objeto y los que hacen que haya que explorar.
##
## Consecuencia buscada: el mapa es un arbol. Entre dos salas hay un solo camino
## y cada sala vecina es una puerta, sin atajos ni vueltas.
func _crecer(cantidad: int, semilla: int, en_fila: bool = false) -> void:
	var generador := RandomNumberGenerator.new()
	generador.seed = semilla
	celdas = [Vector2i.ZERO]
	_ocupadas = {Vector2i.ZERO: true}

	# Tope de intentos para no colgarse si la regla deja el mapa sin sitio,
	# que con muchas salas puede pasar.
	var intentos := 0
	while celdas.size() < cantidad and intentos < cantidad * 400:
		intentos += 1
		# En fila, siempre de la ultima: cada sala nueva sigue el camino.
		var base := celdas[-1] if en_fila else celdas[generador.randi() % celdas.size()]
		var nueva := base + DIRECCIONES[generador.randi() % DIRECCIONES.size()]
		if _ocupadas.has(nueva):
			continue
		if _vecinas_ocupadas(nueva) > 1:
			continue
		celdas.append(nueva)
		_ocupadas[nueva] = true

	if celdas.size() < cantidad:
		push_warning("El mapa se quedo en %d salas de %d." % [celdas.size(), cantidad])


func _vecinas_ocupadas(celda: Vector2i) -> int:
	var cuantas := 0
	for direccion in DIRECCIONES:
		if _ocupadas.has(celda + direccion):
			cuantas += 1
	return cuantas


## Puertas que hay que cruzar desde el inicio hasta cada sala (recorrido en
## anchura: la primera vez que se llega a una sala es por el camino mas corto).
func _medir_distancias() -> void:
	_distancias = {celdas[0]: 0}
	var pendientes: Array[Vector2i] = [celdas[0]]
	while not pendientes.is_empty():
		var actual: Vector2i = pendientes.pop_front()
		for direccion in DIRECCIONES:
			var vecina := actual + direccion
			if _ocupadas.has(vecina) and not _distancias.has(vecina):
				_distancias[vecina] = _distancias[actual] + 1
				pendientes.append(vecina)


## Cuelga del mapa la antesala y, detras, la sala del jefe.
##
## DONDE: de la sala mas lejana del inicio, como la salida de los demas pisos:
## hay que cruzar el piso entero para llegar al jefe. Si ahi no cabe (la sala
## del jefe ocupa varias casillas y alrededor puede haber otras salas), de la
## siguiente mas lejana, y asi. En empate, la que se creo antes.
##
## La antesala es un callejon con dos puertas: la de la sala de la que cuelga y
## la del jefe. Asi solo se llega al jefe por ella, y nada mas da a la sala del
## jefe. Devuelve false si no ha cabido en ningun sitio (no deberia pasar).
func _anadir_jefe(medida: Vector2) -> bool:
	var lejana := 0
	for celda in celdas:
		lejana = maxi(lejana, _distancias[celda])
	# Desde 1: la antesala no cuelga del inicio, seria llegar al jefe sin piso.
	for distancia in range(lejana, 0, -1):
		for celda in celdas:
			if _distancias[celda] != distancia:
				continue
			for direccion in DIRECCIONES:
				var bloque := _bloque_jefe(celda + direccion * 2, direccion, medida)
				if _cabe_jefe(celda, direccion, bloque):
					var antesala := celda + direccion
					celdas.append(antesala)
					_ocupadas[antesala] = true
					celdas.append(bloque[0])
					_ocupadas[bloque[0]] = true
					_reservadas.assign(bloque.slice(1))
					direccion_jefe = direccion
					return true
	push_warning("No cabe la sala del jefe en el mapa: el piso se queda sin ella.")
	return false


## Las casillas que tapa la sala del jefe si su casilla es 'celda' y se entra
## en 'direccion'. La primera, la suya.
##
## Se entra por el centro de un lado: la puerta tiene que quedar enfrente de la
## de la antesala. Por eso va centrada en la antesala a lo ancho (y tapa lo
## mismo a cada lado) y empieza en el muro de la antesala a lo largo.
func _bloque_jefe(celda: Vector2i, direccion: Vector2i, medida: Vector2) -> Array[Vector2i]:
	var vertical := direccion.y != 0
	var largo := medida.y if vertical else medida.x
	var ancho := medida.x if vertical else medida.y
	var lado := Vector2i(1, 0) if vertical else Vector2i(0, 1)
	# Casillas que hacen falta a lo largo, y cuantas tapa a cada lado a lo
	# ancho (la suya mide 1, y lo que sobra se reparte a los dos lados). El
	# 0,001 es para que una medida justa no pida una casilla de mas.
	var a_lo_largo := maxi(1, ceili(largo - 0.001))
	var a_cada_lado := maxi(0, ceili(ancho * 0.5 - 0.5 - 0.001))
	var bloque: Array[Vector2i] = [celda]
	for i in a_lo_largo:
		for j in range(-a_cada_lado, a_cada_lado + 1):
			var otra := celda + direccion * i + lado * j
			if otra != celda:
				bloque.append(otra)
	return bloque


## True si la antesala (junto a 'desde', hacia 'direccion') y el bloque de la
## sala del jefe caben sin tocar a ninguna otra sala: libres, y sin vecinas que
## les abririan una puerta de mas.
func _cabe_jefe(desde: Vector2i, direccion: Vector2i, bloque: Array[Vector2i]) -> bool:
	var antesala := desde + direccion
	if _ocupadas.has(antesala):
		return false
	for vecina in DIRECCIONES:
		if antesala + vecina != desde and _ocupadas.has(antesala + vecina):
			return false
	for celda in bloque:
		if _ocupadas.has(celda):
			return false
	for vecina in DIRECCIONES:
		var junto := bloque[0] + vecina
		if junto != antesala and _ocupadas.has(junto):
			return false
	return true


## Decide que es cada sala.
##
## La SALIDA es la mas lejana del inicio: para bajar hay que cruzar el piso, no
## encontrarse el agujero en la sala de al lado.
##
## El OBJETO va en un callejon sin salida, el mas lejano que haya. Asi cogerlo
## es una decision (me desvio o sigo hacia la salida) y no algo que te
## encuentras de camino. Si no hay callejones libres, en la sala mas lejana que
## no sea ni el inicio ni la salida.
##
## En empate gana la sala que se creo antes: recorrer celdas en su orden hace
## que el resultado no dependa de como el diccionario guarde las claves.
## Cuelga la sala secreta de una sala del piso (pedida por Matias el
## 2026-10-29: «una sala secreta por piso que no se sepa donde esta, con un
## cofre dentro»). Una casilla libre al lado de una sala que no toque a
## ninguna otra: asi su unica puerta es la escondida, y el mapa sigue siendo
## un arbol.
##
## No cuelga de la antesala ni de la sala del jefe, ni toca lo que tapa la
## sala del jefe. Y nunca queda por encima de la sala de la que cuelga: la
## pared de arriba es la que tiene cara (vista 3/4), y una puerta escondida
## ahi no hay forma de taparla bien. Con su semilla, la del mapa y una mas:
## sale siempre en el mismo sitio de cada piso.
func _anadir_secreta(semilla: int) -> void:
	var tapadas := {}
	for reservada in _reservadas:
		tapadas[reservada] = true
	var opciones: Array[Vector2i] = []
	for celda in celdas:
		if _tipos[celda] == Tipo.ANTESALA or _tipos[celda] == Tipo.JEFE:
			continue
		for direccion in DIRECCIONES:
			if direccion == Vector2i.UP:
				continue
			var nueva := celda + direccion
			if _ocupadas.has(nueva) or tapadas.has(nueva) or _vecinas_ocupadas(nueva) != 1:
				continue
			var junto_al_jefe := false
			for otra in DIRECCIONES:
				if tapadas.has(nueva + otra):
					junto_al_jefe = true
			if not junto_al_jefe:
				# De dos en dos: la sala de la que cuelga y hacia donde.
				opciones.append(celda)
				opciones.append(direccion)
	if opciones.is_empty():
		push_warning("No cabe la sala secreta en el mapa: el piso se queda sin ella.")
		return
	var generador := RandomNumberGenerator.new()
	generador.seed = semilla + 7907
	var cual := generador.randi() % (opciones.size() / 2)
	padre_secreta = opciones[cual * 2]
	direccion_secreta = opciones[cual * 2 + 1]
	var secreta := padre_secreta + direccion_secreta
	celdas.append(secreta)
	_ocupadas[secreta] = true
	_tipos[secreta] = Tipo.SECRETA
	_distancias[secreta] = _distancias[padre_secreta] + 1


func _repartir_tipos() -> void:
	var inicio := celdas[0]
	for celda in celdas:
		_tipos[celda] = Tipo.NORMAL
	_tipos[inicio] = Tipo.INICIO

	# Con jefe, la bajada esta en su sala: no hay SALIDA. Son las dos ultimas
	# casillas que se anadieron (ver _anadir_jefe).
	var salida := inicio
	if direccion_jefe != Vector2i.ZERO:
		_tipos[celdas[-2]] = Tipo.ANTESALA
		_tipos[celdas[-1]] = Tipo.JEFE
		salida = celdas[-1]
	else:
		for celda in celdas:
			if _distancias[celda] > _distancias[salida]:
				salida = celda
		_tipos[salida] = Tipo.SALIDA

	var objeto := Vector2i(999999, 999999)
	var mejor := -1
	# Primera pasada: callejones sin salida. Segunda: cualquiera que quede.
	for solo_callejones in [true, false]:
		for celda in celdas:
			if celda == inicio or celda == salida or _tipos[celda] == Tipo.ANTESALA:
				continue
			if solo_callejones and _vecinas_ocupadas(celda) != 1:
				continue
			if _distancias[celda] > mejor:
				mejor = _distancias[celda]
				objeto = celda
		if mejor >= 0:
			break
	if mejor >= 0:
		_tipos[objeto] = Tipo.OBJETO
