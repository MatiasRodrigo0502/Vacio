## La pared de roca que rodea una sala: su forma, lo que choca y como se pinta.
##
## POR QUE UNA PARED Y NO FILAS DE ROCAS:
## antes el limite eran rocas sueltas puestas en fila, las mismas en varios
## pisos, y se leia como eso: piedras alineadas. Ahora es una pared continua
## de la roca de cada capa (EstiloBorde), con el canto irregular (el limite
## sigue sin ser un rectangulo), una cara que se ve de frente en la de arriba
## (vista 3/4, como en Isaac), sombra al pie, y lo que crece, cuelga o
## sobresale de ella segun el piso.
##
## No es un nodo: la sala lo llama desde su _draw(), entre el suelo y las
## puertas. Como nodo hijo se pintaria encima de las puertas y los pilares.
##
## Todo va en coordenadas locales de la sala. Cada lado se describe con un
## PERFIL: cuanto se mete la pared en la sala a lo largo de ese lado, medido
## cada PASO px. De ahi sale todo: lo que se pinta, lo que choca y donde van
## las piezas.
##
## EN VERTICAL (Vista, el movil de pie) la vista gira 90 grados, y la pared que
## queda arriba en la pantalla es la de la derecha del mundo. La cara va en esa
## ('arriba'), y las piezas (adornos, colgantes, salientes) se pintan de pie en
## la pantalla, giradas con la vista: si no, se veia la cara a un lado y todo
## lo que crece en la pared, tumbado.
##
## LO QUE CHOCA ES SIEMPRE LO DE HORIZONTAL, en las dos vistas. De donde choca
## la pared depende donde se reparten los peligros y los enemigos: con otra
## pared en vertical, el piso salia distinto (y en cooperativo cada uno veria
## el suyo). Lo que cambia es el dibujo, que se acerca a donde choca: el canto
## de la pared de arriba del mundo y el de la cara se mueven SUBE_CARA.
class_name ParedSala
extends RefCounted

## Cada cuanto se mide el perfil a lo largo de un lado.
const PASO: float = 10.0
## Lo que se come cada esquina de mas: en una cueva las esquinas no son
## angulos rectos.
const ESQUINA: float = 34.0
## Hasta donde llega, desde la esquina, ese redondeo.
const ALCANCE_ESQUINA: float = 120.0
## Lo que se aparta la pared de una puerta: el hueco entero y un poco mas, y
## luego vuelve poco a poco a su sitio. Con la pared pegada al hueco, la
## puerta se veria mas estrecha de lo que es.
const LIBRE_PUERTA: float = Sala.ANCHO_PUERTA * 0.5 + 6.0
const RAMPA_PUERTA: float = 54.0
## Radio de los circulos con los que choca la pared. Pegados unos a otros a lo
## largo del canto, dan su forma sin tener que construir un poligono.
const RADIO_CHOQUE: float = 18.0
## En la pared de arriba se choca un poco por encima del pie de la cara: con
## vista 3/4, el cuerpo del mago se pinta delante de la cara y solo los pies
## tienen que quedarse en el suelo.
const SUBE_CARA: float = 16.0
## Cada cuantos puntos del perfil se pintan la sombra y la cara. Con todos
## (cada 10 px) eran tantas piezas que el juego iba un tercio mas lento sin
## que se notara la diferencia; cada 30 px la sombra y cada 20 la cara se ven
## igual.
const SALTO_SOMBRA: int = 3
const SALTO_CARA: int = 2
## Sombra que echa la pared sobre el suelo.
const SOMBRA_ANCHO: float = 46.0
const SOMBRA_FUERZA: float = 0.55
## Bultos: trozos de pared que se meten mas en la sala, como un saliente de
## roca. Uno cada tantos px de lado (de media), y lo que se meten y lo anchos
## que son.
const LADO_POR_BULTO: float = 420.0
const BULTO_ENTRADA := Vector2(24.0, 44.0)
const BULTO_ANCHO := Vector2(30.0, 55.0)

var estilo: EstiloBorde
var tamano: Vector2
## La pared que se ve arriba en la pantalla, la que tiene cara: la de arriba
## del mundo en horizontal y la de la derecha en vertical.
var arriba: Vector2i = Vector2i.UP
## Lo girada que estaba la vista (Vista.giro) al levantarla. Las piezas se
## guardan en coordenadas de la pantalla (girada) y se pintan con este giro.
var giro: float = 0.0
## Las puertas que se ven: delante de ellas la pared se aparta y no choca.
var puertas: Array[Vector2i] = []
## Todas, tambien la de la sala secreta mientras esta escondida
## (Sala.puerta_secreta). Lo que se reparte al azar (bultos, adornos) cuenta
## con ellas: asi, al romperse esa pared y levantarse otra vez, el generador
## da los mismos numeros y la pared sale igual salvo delante de esa puerta.
## Que no haya adornos ni bultos justo ahi es lo unico que la delata.
var _puertas_todas: Array[Vector2i] = []
## Donde esta la sala en el piso: la roca se pinta alineada con el mundo.
var origen: Vector2
## Piezas mas pequenas en las salas pequenas del fondo.
var escala: float = 1.0

## direccion -> PackedFloat32Array con lo que se mete la pared cada PASO px.
var _perfiles: Dictionary = {}
## direccion -> donde empieza el perfil, a lo largo del lado.
var _desde: Dictionary = {}
## Los bultos de la pared, donde van los salientes: [direccion, s].
var _bultos: Array = []
## Alto de la cara de la pared de arriba en cada punto de su perfil.
var _alto_cara: PackedFloat32Array
## Como va y viene ese alto (ver _trazar_cara): se guarda para poder calcularlo
## en otra pared sin volver a tirar del generador.
var _onda_cara := Vector2.ZERO
## Lo que se pinta encima de la pared: [textura, rect, abajo del todo, grande].
## Ordenado: primero los adornos, juntos los de la misma textura; luego los
## salientes, de atras hacia delante (ver levantar). Los rect van en
## coordenadas de la pantalla (ver en_pantalla): en horizontal son las de la
## sala.
var _piezas: Array = []
## Lo que cuelga de la cara de arriba: [textura, rect], tambien en la pantalla.
var _colgantes: Array = []


## Traza la pared y coloca sus piezas. Las colisiones se las pide a la sala
## (Sala.anadir_roca_filo), que es quien las guarda y las consulta.
##
## 'rocas' son las cajas de las rocas y plataformas de dentro (en local de la
## sala): ni los bultos ni los adornos van encima.
func levantar(sala: Sala, estilo_pared: EstiloBorde, semilla: int, rocas: Array[Rect2]) -> void:
	estilo = estilo_pared
	tamano = sala.tamano
	puertas = sala.puertas_visibles()
	_puertas_todas = sala.puertas
	origen = sala.position
	escala = clampf(tamano.x / 1400.0, 0.75, 1.0)
	giro = Vista.giro
	arriba = Vector2i(Vector2(Vector2i.UP).rotated(giro).round())
	var generador := RandomNumberGenerator.new()
	generador.seed = semilla

	for direccion in MapaSalas.DIRECCIONES:
		_trazar_perfil(direccion, generador, rocas)
	_trazar_cara(generador)
	_poner_choques(sala)
	if arriba == Vector2i.UP:
		_poner_adornos(generador, rocas)
		_poner_colgantes(generador)
		_poner_salientes(sala, generador)
	else:
		# En vertical se tira del generador como en horizontal, aunque no se
		# use lo que sale: asi los salientes, que chocan, caen en el mismo
		# sitio en las dos vistas (en cooperativo cada uno puede tener la
		# suya), y la horizontal sale igual que siempre. Lo que solo se ve
		# (adornos y colgantes) se reparte despues con otro generador.
		var de_verdad := [arriba, giro]
		arriba = Vector2i.UP
		giro = 0.0
		_calcular_alto_cara()
		_poner_adornos(generador, rocas)
		_poner_colgantes(generador)
		_piezas.clear()
		_colgantes.clear()
		arriba = de_verdad[0]
		giro = de_verdad[1]
		_poner_salientes(sala, generador)
		_ver_como_choca()
		_calcular_alto_cara()
		var otro := RandomNumberGenerator.new()
		otro.seed = semilla + 1
		_poner_adornos(otro, rocas)
		_poner_colgantes(otro)
	# Los adornos son pequenos y no se tapan entre ellos: se pintan agrupados
	# por textura, que es lo que deja al motor pintarlos de una vez. Uno detras
	# de otro alternando texturas, el juego iba casi un tercio mas lento. Los
	# salientes si se tapan, y van despues, de atras hacia delante.
	_piezas.sort_custom(func(a: Array, b: Array) -> bool:
		if a[3] != b[3]:
			return not a[3]
		if a[3]:
			return a[2] < b[2]
		return a[0].get_rid().get_id() < b[0].get_rid().get_id())


# --- Forma ------------------------------------------------------------------

func _largo(direccion: Vector2i) -> float:
	return tamano.x if direccion.y != 0 else tamano.y


## El perfil de un lado: una media, tres ondas de distinto largo encima (una
## larga que da la forma, otra media y otra corta que la rompen), algun bulto
## (ver _elegir_bultos), las esquinas redondeadas y nada delante de las puertas.
##
## Va un muro mas alla de cada esquina: asi la pared de un lado tapa el final
## de la cara de la de arriba, y la esquina queda maciza.
func _trazar_perfil(direccion: Vector2i, generador: RandomNumberGenerator, rocas: Array[Rect2]) -> void:
	var largo := _largo(direccion)
	var desde := -largo * 0.5 - Sala.GROSOR_MURO
	var cuantos := int(ceil((largo + Sala.GROSOR_MURO * 2.0) / PASO)) + 1
	var entrada := estilo.entrada * escala
	var amplitud := estilo.ondulacion * escala
	var ondas: Array[Vector2] = [
		Vector2(TAU / generador.randf_range(200.0, 300.0), generador.randf() * TAU),
		Vector2(TAU / generador.randf_range(70.0, 110.0), generador.randf() * TAU),
		Vector2(TAU / generador.randf_range(28.0, 40.0), generador.randf() * TAU),
	]
	var pesos := [0.6, 0.3, 0.1]
	var bultos := _elegir_bultos(direccion, generador, rocas)
	var valores := PackedFloat32Array()
	valores.resize(cuantos)
	for i in cuantos:
		var s := desde + i * PASO
		var onda := 0.0
		for k in 3:
			onda += pesos[k] * sin(s * ondas[k].x + ondas[k].y)
		var d := entrada + amplitud * onda
		for bulto: Vector3 in bultos:
			d += bulto.y * exp(-pow((s - bulto.x) / bulto.z, 2.0))
		var hasta_esquina := largo * 0.5 - absf(s)
		d += ESQUINA * escala * pow(1.0 - clampf(hasta_esquina / ALCANCE_ESQUINA, 0.0, 1.0), 2.0)
		if direccion in puertas:
			d *= smoothstep(LIBRE_PUERTA, LIBRE_PUERTA + RAMPA_PUERTA, absf(s))
		valores[i] = maxf(d, 0.0)
	_perfiles[direccion] = valores
	_desde[direccion] = desde


## Los bultos de un lado: (donde, cuanto se meten, ancho). Lejos de las
## puertas, de las esquinas, unos de otros y de las rocas de dentro: un bulto
## encima de una roca la enterraria.
func _elegir_bultos(direccion: Vector2i, generador: RandomNumberGenerator,
		rocas: Array[Rect2]) -> Array[Vector3]:
	var largo := _largo(direccion)
	var bultos: Array[Vector3] = []
	var cuantos := int(round(largo / LADO_POR_BULTO * generador.randf_range(0.5, 1.3)))
	for _i in cuantos:
		for _intento in 10:
			var ancho := generador.randf_range(BULTO_ANCHO.x, BULTO_ANCHO.y) * escala
			var entra := generador.randf_range(BULTO_ENTRADA.x, BULTO_ENTRADA.y) * escala
			var s := generador.randf_range(-largo * 0.5 + 100.0, largo * 0.5 - 100.0)
			if _es_puerta(direccion, s, RAMPA_PUERTA + ancho * 1.5):
				continue
			var lejos := true
			for otro in bultos:
				if absf(otro.x - s) < (otro.z + ancho) * 2.5:
					lejos = false
			var punta := punto(direccion, s, estilo.entrada * escala + entra)
			if not lejos or _choca_con(Rect2(punta, Vector2.ZERO).grow(entra + 30.0), rocas):
				continue
			bultos.append(Vector3(s, entra, ancho))
			_bultos.append([direccion, s])
			break
	return bultos


## Alto de la cara de arriba a lo largo de su perfil: va y viene un poco, para
## que el labio de arriba tampoco sea una raya.
func _trazar_cara(generador: RandomNumberGenerator) -> void:
	_onda_cara.x = TAU / generador.randf_range(90.0, 140.0)
	_onda_cara.y = generador.randf() * TAU
	_calcular_alto_cara()


func _calcular_alto_cara() -> void:
	var cuantos: int = _perfiles[arriba].size()
	_alto_cara.resize(cuantos)
	for i in cuantos:
		var s: float = _desde[arriba] + i * PASO
		_alto_cara[i] = estilo.alto_cara * escala * (1.0 + 0.1 * sin(s * _onda_cara.x + _onda_cara.y))


## Cuanto se mete la pared en 's' (a lo largo del lado), interpolando.
func entrada_en(direccion: Vector2i, s: float) -> float:
	var valores: PackedFloat32Array = _perfiles[direccion]
	var i: float = (s - _desde[direccion]) / PASO
	var a := clampi(int(floor(i)), 0, valores.size() - 1)
	var b := mini(a + 1, valores.size() - 1)
	return lerpf(valores[a], valores[b], clampf(i - a, 0.0, 1.0))


func _alto_cara_en(s: float) -> float:
	var i: float = (s - _desde[arriba]) / PASO
	var a := clampi(int(floor(i)), 0, _alto_cara.size() - 1)
	var b := mini(a + 1, _alto_cara.size() - 1)
	return lerpf(_alto_cara[a], _alto_cara[b], clampf(i - a, 0.0, 1.0))


## El punto del lado 'direccion' que esta en 's' a lo largo y 'dentro' px
## hacia la sala desde el filo del suelo.
func punto(direccion: Vector2i, s: float, dentro: float) -> Vector2:
	var medio := tamano * 0.5
	match direccion:
		Vector2i.UP:
			return Vector2(s, -medio.y + dentro)
		Vector2i.DOWN:
			return Vector2(s, medio.y - dentro)
		Vector2i.LEFT:
			return Vector2(-medio.x + dentro, s)
		_:
			return Vector2(medio.x - dentro, s)


## Un punto de la sala en coordenadas de la pantalla: las de la sala giradas
## con la vista. En horizontal, las mismas.
func en_pantalla(p: Vector2) -> Vector2:
	return p.rotated(-giro)


## Al reves: de la pantalla a la sala.
func en_sala(p: Vector2) -> Vector2:
	return p.rotated(giro)


## Una caja de la pantalla, en la sala: la que la contiene (con el giro de 90
## grados, la misma caja con los lados cambiados).
func _caja_en_sala(caja: Rect2) -> Rect2:
	var a := en_sala(caja.position)
	var b := en_sala(caja.end)
	return Rect2(a.min(b), (b - a).abs())


## Al reves que punto(): de un punto a (a lo largo, hacia dentro) de ese lado.
func _coordenadas(direccion: Vector2i, p: Vector2) -> Vector2:
	var medio := tamano * 0.5
	match direccion:
		Vector2i.UP:
			return Vector2(p.x, p.y + medio.y)
		Vector2i.DOWN:
			return Vector2(p.x, medio.y - p.y)
		Vector2i.LEFT:
			return Vector2(p.y, p.x + medio.x)
		_:
			return Vector2(p.y, medio.x - p.x)


## True si el punto queda dentro de la roca de otro lado que no sea 'salvo'.
## Sirve para cortar el canto de un lado donde lo tapa la pared de al lado,
## en las esquinas. De la pared de arriba cuenta solo lo de encima de la cara:
## la cara la tapan las paredes de los lados.
func _dentro_de_otra(p: Vector2, salvo: Vector2i) -> bool:
	for direccion in MapaSalas.DIRECCIONES:
		if direccion == salvo:
			continue
		var c := _coordenadas(direccion, p)
		var limite := entrada_en(direccion, c.x)
		if direccion == arriba:
			limite -= _alto_cara_en(c.x)
		if c.y < limite:
			return true
	return false


## Para lo que se reparte al azar: cuenta tambien la puerta escondida.
func _es_puerta(direccion: Vector2i, s: float, margen: float = 0.0) -> bool:
	return direccion in _puertas_todas and absf(s) < Sala.ANCHO_PUERTA * 0.5 + margen


## Para lo que choca y lo que se pinta (la cara, la sombra, los cantos): solo
## las puertas que se ven. La escondida es pared, con su sombra y su canto: si
## no, el hueco en la sombra la delataria mas que las grietas.
func _es_hueco(direccion: Vector2i, s: float, margen: float = 0.0) -> bool:
	return direccion in puertas and absf(s) < Sala.ANCHO_PUERTA * 0.5 + margen


# --- Choques ------------------------------------------------------------------

## Circulos pegados a lo largo del canto, por fuera: su borde de dentro es el
## canto. Solo a lo largo del suelo (mas alla estan los muros rectos) y nunca
## en el hueco de una puerta, o lo estrecharian.
func _poner_choques(sala: Sala) -> void:
	var radio := RADIO_CHOQUE * escala
	for direccion in MapaSalas.DIRECCIONES:
		var largo := _largo(direccion)
		var s := -largo * 0.5 + radio * 0.5
		while s < largo * 0.5:
			if not _es_hueco(direccion, s, radio + 4.0):
				var dentro := entrada_en(direccion, s)
				# La de arriba del mundo, tambien en vertical (ver arriba).
				if direccion == Vector2i.UP:
					dentro -= SUBE_CARA
				if dentro > 0.0:
					sala.anadir_roca_filo(punto(direccion, s, dentro - radio), radio)
			s += radio


# --- Piezas -------------------------------------------------------------------

func _choca_con(rect: Rect2, rocas: Array[Rect2]) -> bool:
	for roca in rocas:
		if roca.intersects(rect):
			return true
	return false


## Tamano en pantalla de una pieza: el de su textura, en las salas pequenas
## algo menor, y con un poco de variacion para que no se vean repetidas.
func _medida(textura: Texture2D, generador: RandomNumberGenerator, variacion: float = 0.15) -> Vector2:
	return textura.get_size() * escala * generador.randf_range(1.0 - variacion, 1.0 + variacion)


## En vertical, el canto que se pinta se lleva a donde choca (los choques son
## los de horizontal, ver arriba): la pared de arriba del mundo, que choca
## SUBE_CARA por fuera de su canto, se pinta asi de mas fuera; y la de la cara,
## que en horizontal no tiene ese margen, asi de mas dentro, para que los pies
## del mago lleguen al pie de la cara como en la de arriba. Delante de las
## puertas no se toca: la pared no puede meterse en el hueco.
func _ver_como_choca() -> void:
	for direccion in [Vector2i.UP, arriba]:
		var mover := -SUBE_CARA if direccion == Vector2i.UP else SUBE_CARA
		var valores: PackedFloat32Array = _perfiles[direccion]
		for i in valores.size():
			var s: float = _desde[direccion] + i * PASO
			var cuanto := 1.0
			if direccion in puertas:
				cuanto = smoothstep(LIBRE_PUERTA, LIBRE_PUERTA + RAMPA_PUERTA, absf(s))
			valores[i] = maxf(valores[i] + mover * cuanto, 0.0)
		_perfiles[direccion] = valores


## Lo que crece encima de la pared, junto al canto. En la de arriba, sobre el
## labio de la cara; en las demas, un poco por fuera del canto, sobre la roca.
func _poner_adornos(generador: RandomNumberGenerator, rocas: Array[Rect2]) -> void:
	if estilo.adornos.is_empty():
		return
	for direccion in MapaSalas.DIRECCIONES:
		var largo := _largo(direccion)
		var s := -largo * 0.5 + generador.randf_range(10.0, estilo.adornos_cada)
		while s < largo * 0.5 - 10.0:
			if not _es_puerta(direccion, s, 70.0):
				var textura: Texture2D = estilo.adornos[generador.randi() % estilo.adornos.size()]
				var medida := _medida(textura, generador)
				var pie: Vector2
				if direccion == arriba:
					pie = punto(direccion, s, entrada_en(direccion, s) - _alto_cara_en(s) + 3.0)
				else:
					pie = punto(direccion, s, entrada_en(direccion, s) - generador.randf_range(4.0, 14.0))
				# De pie en la pantalla: el pie abajo y la pieza hacia arriba.
				var rect := Rect2(en_pantalla(pie) - Vector2(medida.x * 0.5, medida.y), medida)
				if not _choca_con(_caja_en_sala(rect), rocas) and not _dentro_de_otra(pie, direccion):
					_anadir_pieza(textura, rect, generador, false)
			s += estilo.adornos_cada * generador.randf_range(0.5, 1.5)


## Lo que cuelga de la cara de la pared de arriba, desde el labio. Nunca mas
## largo que la cara: colgaria sobre el suelo.
func _poner_colgantes(generador: RandomNumberGenerator) -> void:
	if estilo.colgantes.is_empty():
		return
	var largo := _largo(arriba)
	var s := -largo * 0.5 + generador.randf_range(20.0, estilo.colgantes_cada)
	while s < largo * 0.5 - 20.0:
		if not _es_puerta(arriba, s, 70.0):
			var textura: Texture2D = estilo.colgantes[generador.randi() % estilo.colgantes.size()]
			var medida := _medida(textura, generador)
			var alto := _alto_cara_en(s) * 0.92
			if medida.y > alto:
				medida *= alto / medida.y
			var labio := punto(arriba, s, entrada_en(arriba, s) - _alto_cara_en(s) + 2.0)
			if not _dentro_de_otra(labio + en_sala(Vector2(0.0, 6.0)), arriba):
				var rect := Rect2(en_pantalla(labio) - Vector2(medida.x * 0.5, 0.0), medida)
				if generador.randf() < 0.5:
					rect = Rect2(rect.position + Vector2(rect.size.x, 0.0), Vector2(-rect.size.x, rect.size.y))
				_colgantes.append([textura, rect])
		s += estilo.colgantes_cada * generador.randf_range(0.6, 1.4)


## Piezas grandes en los bultos de la pared: los cristales, estalagmitas o
## columnas de cada piso, que salen de la roca hacia la sala. Van en los bultos
## y no sueltas por el canto: asi se leen como parte de la pared, y no como
## algo plantado en el suelo. Chocan, como la pared.
func _poner_salientes(sala: Sala, generador: RandomNumberGenerator) -> void:
	if estilo.salientes.is_empty() or _bultos.is_empty():
		return
	var cuantos := mini(_bultos.size(), maxi(0, estilo.salientes_por_sala + generador.randi_range(-1, 1)))
	var orden := range(_bultos.size())
	# Barajado con el generador de la sala, no con shuffle(): asi sale igual
	# en todas las partidas, como el resto del piso.
	for i in range(orden.size() - 1, 0, -1):
		var j := generador.randi_range(0, i)
		var temporal: int = orden[i]
		orden[i] = orden[j]
		orden[j] = temporal
	for k in cuantos:
		var bulto: Array = _bultos[orden[k]]
		var direccion: Vector2i = bulto[0]
		var s: float = bulto[1]
		var textura: Texture2D = estilo.salientes[generador.randi() % estilo.salientes.size()]
		var medida := _medida(textura, generador, 0.12)
		# Con el pie un poco dentro de la roca: sale de ella.
		var pie := punto(direccion, s, entrada_en(direccion, s) - 4.0)
		var radio := medida.x * 0.32
		# Choca un poco por encima del pie, en el mundo (igual en las dos
		# vistas). En vertical el pie se pinta debajo de ese circulo en la
		# pantalla, como en horizontal, aunque quede algo corrido del canto.
		var centro := pie - Vector2(0.0, radio * 0.7)
		sala.anadir_roca_filo(centro, radio)
		var base := centro + en_sala(Vector2(0.0, radio * 0.7))
		var rect := Rect2(en_pantalla(base) - Vector2(medida.x * 0.5, medida.y), medida)
		_anadir_pieza(textura, rect, generador, true)


## Apunta una pieza para pintarla, volteada a veces: con la luz de arriba,
## voltear en horizontal no se nota y duplica las variantes.
func _anadir_pieza(textura: Texture2D, rect: Rect2, generador: RandomNumberGenerator,
		grande: bool) -> void:
	var abajo := rect.end.y
	if generador.randf() < 0.5:
		rect = Rect2(rect.position + Vector2(rect.size.x, 0.0), Vector2(-rect.size.x, rect.size.y))
	_piezas.append([textura, rect, abajo, grande])


# --- Pintado ------------------------------------------------------------------

## Pinta la pared en 'lienzo' (la sala, desde su _draw). 'color_muro' tine la
## roca vista desde arriba, igual que la franja del muro, para que casen.
func pintar(lienzo: CanvasItem, color_muro: Color) -> void:
	_pintar_sombras(lienzo)
	_pintar_cara(lienzo, color_muro)
	for direccion in MapaSalas.DIRECCIONES:
		if direccion != arriba:
			_pintar_entrada(lienzo, direccion, color_muro)
	_pintar_cantos(lienzo)
	# Las piezas, de pie en la pantalla: con un solo giro para todas, que no
	# rompe los lotes de dibujo (ver levantar).
	lienzo.draw_set_transform(Vector2.ZERO, giro)
	for pieza in _piezas:
		lienzo.draw_texture_rect(pieza[0], pieza[1], false)
	lienzo.draw_set_transform(Vector2.ZERO)


## La roca de un lado vista desde arriba, del filo del suelo al canto. En
## trozos, cortados donde la pared no se mete (delante de las puertas): un
## poligono con lados de ancho cero no se puede triangular.
func _pintar_entrada(lienzo: CanvasItem, direccion: Vector2i, color: Color) -> void:
	var valores: PackedFloat32Array = _perfiles[direccion]
	var desde: float = _desde[direccion]
	var filo := PackedVector2Array()
	var canto := PackedVector2Array()
	for i in valores.size():
		if valores[i] > 0.5:
			var s := desde + i * PASO
			filo.append(punto(direccion, s, 0.0))
			canto.append(punto(direccion, s, valores[i]))
		elif filo.size() > 1:
			_poligono_roca(lienzo, filo, canto, color)
			filo = PackedVector2Array()
			canto = PackedVector2Array()
		else:
			filo.clear()
			canto.clear()
	if filo.size() > 1:
		_poligono_roca(lienzo, filo, canto, color)


func _poligono_roca(lienzo: CanvasItem, filo: PackedVector2Array, canto: PackedVector2Array,
		color: Color) -> void:
	var puntos := filo.duplicate()
	var reves := canto.duplicate()
	reves.reverse()
	puntos.append_array(reves)
	var tam := estilo.muro.get_size()
	var uvs := PackedVector2Array()
	var colores := PackedColorArray()
	for p in puntos:
		uvs.append(uv_muro(origen + p, tam))
		colores.append(color)
	lienzo.draw_polygon(puntos, colores, uvs, estilo.muro)


## Donde cae en la textura de la roca un punto del piso. Alineada con el mundo
## y, en vertical, girada con la vista: asi la roca se ve igual en la pantalla
## (su luz viene de arriba) en las dos vistas. La usan tambien la sala y el
## piso para su roca, para que todo case.
static func uv_muro(en_piso: Vector2, tam: Vector2) -> Vector2:
	return en_piso.rotated(-Vista.giro) / tam


## La pared de arriba: la roca hasta el labio (donde la cara empieza por
## debajo del filo del suelo, en las esquinas) y la cara vertical, en franjas,
## con lo que cuelga de ella. La textura de la cara va alineada con el mundo a
## lo largo (en la pantalla, de izquierda a derecha) y de arriba (labio) a
## abajo (pie) en la cara.
func _pintar_cara(lienzo: CanvasItem, color: Color) -> void:
	var valores: PackedFloat32Array = _perfiles[arriba]
	var desde: float = _desde[arriba]
	var medio := _largo(arriba) * 0.5
	var ancho_textura := estilo.cara.get_size().x
	var fuera := Vector2(arriba)
	var blanco := PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE])
	for i in range(0, valores.size() - 1, SALTO_CARA):
		var j := mini(i + SALTO_CARA, valores.size() - 1)
		var s0 := desde + i * PASO
		var s1 := desde + j * PASO
		if s1 < -medio or s0 > medio:
			continue
		# El hueco de la puerta se salta entero, aunque el trozo lo pise solo
		# en parte: la cara no puede tapar el pasillo.
		if _es_hueco(arriba, s0) or _es_hueco(arriba, s1):
			continue
		var b0 := punto(arriba, s0, valores[i])
		var b1 := punto(arriba, s1, valores[j])
		var t0 := b0 + fuera * _alto_cara[i]
		var t1 := b1 + fuera * _alto_cara[j]
		# Si la cara empieza por debajo del filo, lo de encima es roca.
		var dentro0 := valores[i] - _alto_cara[i]
		var dentro1 := valores[j] - _alto_cara[j]
		if dentro0 > 0.0 or dentro1 > 0.0:
			var encima := PackedVector2Array([punto(arriba, s0, 0.0), punto(arriba, s1, 0.0),
				punto(arriba, s1, maxf(dentro1, 0.0)), punto(arriba, s0, maxf(dentro0, 0.0))])
			var tam := estilo.muro.get_size()
			var uvs_r := PackedVector2Array()
			for p in encima:
				uvs_r.append(uv_muro(origen + p, tam))
			lienzo.draw_polygon(encima, PackedColorArray([color, color, color, color]), uvs_r, estilo.muro)
		var u0 := en_pantalla(origen + b0).x / ancho_textura
		var u1 := en_pantalla(origen + b1).x / ancho_textura
		lienzo.draw_primitive(PackedVector2Array([t0, t1, b1, b0]), blanco,
			PackedVector2Array([Vector2(u0, 0.0), Vector2(u1, 0.0), Vector2(u1, 1.0), Vector2(u0, 1.0)]),
			estilo.cara)
	lienzo.draw_set_transform(Vector2.ZERO, giro)
	for colgante in _colgantes:
		lienzo.draw_texture_rect(colgante[0], colgante[1], false)
	lienzo.draw_set_transform(Vector2.ZERO)


## La sombra que echa la pared sobre el suelo, del pie hacia dentro. La de
## arriba, mas fuerte: la cara es alta y tapa la luz.
func _pintar_sombras(lienzo: CanvasItem) -> void:
	var oscuro := Color(estilo.color_sombra, SOMBRA_FUERZA)
	var nada := Color(estilo.color_sombra, 0.0)
	for direccion in MapaSalas.DIRECCIONES:
		var largo := _largo(direccion)
		var ancho := SOMBRA_ANCHO * (1.3 if direccion == arriba else 1.0)
		var fuerte := Color(oscuro, minf(1.0, SOMBRA_FUERZA * (1.25 if direccion == arriba else 1.0)))
		var colores := PackedColorArray([fuerte, fuerte, nada, nada])
		var s := -largo * 0.5
		while s < largo * 0.5:
			var s1 := minf(s + PASO * SALTO_SOMBRA, largo * 0.5)
			if not _es_hueco(direccion, s) and not _es_hueco(direccion, s1):
				var d0 := entrada_en(direccion, s)
				var d1 := entrada_en(direccion, s1)
				lienzo.draw_primitive(PackedVector2Array([punto(direccion, s, d0), punto(direccion, s1, d1),
					punto(direccion, s1, d1 + ancho), punto(direccion, s, d0 + ancho)]), colores,
					PackedVector2Array())
			s = s1


## Los cantos: la raya de luz donde la roca de arriba se acaba y la oscura del
## pie. En la de arriba, la luz va en el labio de la cara y la oscura al pie.
## Se cortan donde los tapa la pared de al lado.
func _pintar_cantos(lienzo: CanvasItem) -> void:
	var luz := Color(estilo.color_luz, 0.85)
	var pie := Color(estilo.color_sombra, 0.9)
	for direccion in MapaSalas.DIRECCIONES:
		var valores: PackedFloat32Array = _perfiles[direccion]
		var desde: float = _desde[direccion]
		var fuera := Vector2(direccion)
		var tramo_luz := PackedVector2Array()
		var tramo_pie := PackedVector2Array()
		# Uno de cada dos puntos: a 20 px la raya sigue igual de suave, y son la
		# mitad de trozos que pintar.
		for i in range(0, valores.size(), 2):
			var s := desde + i * PASO
			var d := valores[i]
			var visible := d > 0.5 or not _es_hueco(direccion, s, 2.0)
			var p_pie := punto(direccion, s, d)
			var p_luz := p_pie
			if direccion == arriba:
				p_luz = p_pie + fuera * (_alto_cara[i] - 1.0)
				visible = visible and absf(s) <= _largo(direccion) * 0.5
			else:
				p_luz = p_pie + fuera * 1.5
			visible = visible and not _dentro_de_otra(p_pie, direccion)
			if visible:
				tramo_luz.append(p_luz)
				tramo_pie.append(p_pie)
			else:
				_raya(lienzo, tramo_luz, luz, 2.0)
				_raya(lienzo, tramo_pie, pie, 2.5)
				tramo_luz = PackedVector2Array()
				tramo_pie = PackedVector2Array()
		_raya(lienzo, tramo_luz, luz, 2.0)
		_raya(lienzo, tramo_pie, pie, 2.5)


func _raya(lienzo: CanvasItem, puntos: PackedVector2Array, color: Color, ancho: float) -> void:
	if puntos.size() > 1:
		lienzo.draw_polyline(puntos, color, ancho, true)
