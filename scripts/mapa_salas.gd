## El plano de un piso: que salas hay, en que casilla esta cada una y cual es
## cual (inicio, normal, objeto o salida).
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

enum Tipo { INICIO, NORMAL, OBJETO, SALIDA }

## Las cuatro direcciones en que puede haber puerta.
const DIRECCIONES: Array[Vector2i] = [
	Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT,
]

## Casillas ocupadas, en el orden en que se crearon. La primera es el inicio.
var celdas: Array[Vector2i] = []

var _ocupadas: Dictionary = {}
var _tipos: Dictionary = {}
var _distancias: Dictionary = {}


## Genera el plano de un piso.
##
## La semilla la pone el piso a partir de su numero: el mapa es aleatorio pero
## el mismo en todas las partidas y en las tres maquinas del equipo, igual que
## lo eran los pisos de antes. "Doce niveles fijos" sigue siendo verdad.
static func generar(cantidad: int, semilla: int) -> MapaSalas:
	var mapa := MapaSalas.new()
	# Menos de tres no da para inicio, objeto y salida.
	mapa._crecer(maxi(cantidad, 3), semilla)
	mapa._medir_distancias()
	mapa._repartir_tipos()
	return mapa


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
func _crecer(cantidad: int, semilla: int) -> void:
	var generador := RandomNumberGenerator.new()
	generador.seed = semilla
	celdas = [Vector2i.ZERO]
	_ocupadas = {Vector2i.ZERO: true}

	# Tope de intentos para no colgarse si la regla deja el mapa sin sitio,
	# que con muchas salas puede pasar.
	var intentos := 0
	while celdas.size() < cantidad and intentos < cantidad * 400:
		intentos += 1
		var base := celdas[generador.randi() % celdas.size()]
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
func _repartir_tipos() -> void:
	var inicio := celdas[0]
	for celda in celdas:
		_tipos[celda] = Tipo.NORMAL
	_tipos[inicio] = Tipo.INICIO

	var salida := inicio
	for celda in celdas:
		if _distancias[celda] > _distancias[salida]:
			salida = celda
	_tipos[salida] = Tipo.SALIDA

	var objeto := Vector2i(999999, 999999)
	var mejor := -1
	# Primera pasada: callejones sin salida. Segunda: cualquiera que quede.
	for solo_callejones in [true, false]:
		for celda in celdas:
			if celda == inicio or celda == salida:
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
