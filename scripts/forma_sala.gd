## La forma de una sala: los bloques de obra maciza que se meten en ella y
## hacen que no sea un rectangulo (en L, en T, en cruz, con las esquinas en
## escalon, con columnas o con muretes). Pedido por Matias el 2026-11-19, con el
## castillo: «tambien la forma» de las salas.
##
## POR QUE BLOQUES DENTRO DE LA SALA Y NO SALAS DE OTRA FORMA:
## todo lo demas cuenta con que la sala es una casilla rectangular de la
## cuadricula: las puertas en el centro de cada lado, la camara, la penumbra, el
## minimapa, el reparto de rocas, enemigos y peligros, el cooperativo. Una sala
## en L de verdad obligaria a rehacer todo eso. Un bloque macizo es, para el
## juego, una roca muy grande: choca como ellas (capa de rocas), la sala lo
## apunta entre sus rocas (Sala.registrar_roca) y asi lo esquivan solos los
## enemigos (sacar_de_las_rocas) y todo lo que se reparte (Sala.punto_al_azar,
## Piso.lugar_libre). Lo que cambia es como se ve: como la pared, con su roca por
## encima y su cara de frente, y pegado a ella cuando esta en una esquina. Asi
## se lee como que la sala tiene esa forma.
##
## LO QUE NUNCA TAPAN: la cruz que une las puertas con el centro (BANDA_X y
## BANDA_Y), que es por donde se entra y se sale, donde va el pasillo de
## pinchos y donde estan la bajada, el objeto y el cofre. Asi cualquier puerta
## sigue llevando a cualquier otra, sea cual sea la forma.
##
## Como ParedSala, no es un nodo: la sala lo pinta desde su _draw(), despues de
## la pared (los bloques de las esquinas la tapan) y antes de las puertas.
class_name FormaSala
extends RefCounted

## Las formas que hay. DatosPiso.formas_salas elige de estas.
const FORMAS: PackedStringArray = ["ele", "te", "cruz", "esquinas", "columnas", "muretes"]
## Media anchura de la franja libre de arriba abajo (la de las puertas de arriba
## y abajo) y media altura de la de lado a lado. El pasillo de pinchos ocupa 150
## a cada lado de su eje (60 de paso y 90 de placa), y la bajada, 150 de radio.
const BANDA_X: float = 180.0
const BANDA_Y: float = 160.0
## Sombra que echan sobre el suelo: la de delante (bajo la cara), mas ancha.
const SOMBRA: float = 30.0
const SOMBRA_CARA: float = 54.0
const FUERZA_SOMBRA: float = 0.5
## Lo menos que se ve de roca encima de la cara en un bloque bajo (los muretes):
## si la cara lo ocupara todo, parecería una pared pintada en el suelo.
const ROCA_ENCIMA: float = 12.0

## El nombre de la forma ("" = rectangular).
var nombre: String = ""
## Los bloques, en coordenadas de la sala, solo la parte que esta sobre el suelo.
var bloques: Array[Rect2] = []

var _tamano: Vector2


## Traza la forma 'que' para una sala de ese tamano. Con el generador de la sala:
## en todos los ordenadores y en las dos vistas sale la misma.
static func trazar(que: String, tamano: Vector2, generador: RandomNumberGenerator) -> FormaSala:
	var forma := FormaSala.new()
	forma.nombre = que
	forma._tamano = tamano
	var m := tamano * 0.5
	match que:
		"ele":
			# Una esquina maciza, grande: la sala queda en L.
			var esquina := _esquina_al_azar(generador)
			forma._esquina(esquina, generador.randf_range(250.0, 320.0), generador.randf_range(185.0, 240.0))
		"te":
			# Las dos esquinas de un mismo lado: en T.
			var lado: Vector2 = [Vector2(0, -1), Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0)][generador.randi() % 4]
			var x0 := generador.randf_range(280.0, 340.0)
			var y0 := generador.randf_range(195.0, 245.0)
			for signo in [-1.0, 1.0]:
				var esquina := Vector2(signo, lado.y) if lado.y != 0.0 else Vector2(lado.x, signo)
				forma._esquina(esquina, x0, y0)
		"cruz":
			var x0 := generador.randf_range(320.0, 380.0)
			var y0 := generador.randf_range(210.0, 255.0)
			for esquina in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
				forma._esquina(esquina, x0, y0)
		"esquinas":
			# Las cuatro esquinas en escalon: la sala casi octogonal, como una
			# torre.
			var a := generador.randf_range(150.0, 190.0)
			var b := generador.randf_range(60.0, 80.0)
			for esquina in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
				forma._esquina(esquina, m.x - a, m.y - b)
				forma._esquina(esquina, m.x - b, m.y - a * 0.85)
		"columnas":
			# Columnas sueltas, en simetria: cuatro o seis.
			var lado_columna := generador.randf_range(78.0, 96.0)
			var y := generador.randf_range(210.0, 250.0)
			var xs: Array[float] = [generador.randf_range(360.0, 430.0)]
			if generador.randf() < 0.5:
				xs = [generador.randf_range(250.0, 280.0), generador.randf_range(470.0, 520.0)]
			for x in xs:
				for sx in [-1.0, 1.0]:
					for sy in [-1.0, 1.0]:
						var centro := Vector2(sx * x, sy * y)
						forma.bloques.append(Rect2(centro - Vector2.ONE * lado_columna * 0.5,
							Vector2.ONE * lado_columna))
		"muretes":
			# Un murete en cada cuarto, a lo largo: como los bancos de una capilla
			# o los pesebres de un establo. Se puede pasar por los lados.
			var y := generador.randf_range(225.0, 265.0)
			var grueso := generador.randf_range(54.0, 66.0)
			var x0 := generador.randf_range(BANDA_X + 40.0, 260.0)
			var x1 := generador.randf_range(470.0, 540.0)
			for sx in [-1.0, 1.0]:
				for sy in [-1.0, 1.0]:
					var a := Vector2(minf(sx * x0, sx * x1), sy * y - grueso * 0.5)
					forma.bloques.append(Rect2(a, Vector2(x1 - x0, grueso)))
	# Nada en la cruz de las puertas, por si un numero de arriba se pasa.
	for i in forma.bloques.size():
		forma.bloques[i] = forma._fuera_de_la_cruz(forma.bloques[i])
	# assign y no '=': filter() devuelve un Array sin tipo.
	forma.bloques.assign(forma.bloques.filter(func(r: Rect2) -> bool: return r.size.x > 8.0 and r.size.y > 8.0))
	return forma


static func _esquina_al_azar(generador: RandomNumberGenerator) -> Vector2:
	return [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)][generador.randi() % 4]


## Un bloque en la esquina 'esquina' (-1 o 1 en cada eje) que empieza a 'x0' del
## centro a lo ancho y a 'y0' a lo alto, hasta las paredes.
func _esquina(esquina: Vector2, x0: float, y0: float) -> void:
	var m := _tamano * 0.5
	var a := Vector2(x0 if esquina.x > 0.0 else -m.x, y0 if esquina.y > 0.0 else -m.y)
	var b := Vector2(m.x if esquina.x > 0.0 else -x0, m.y if esquina.y > 0.0 else -y0)
	bloques.append(Rect2(a, b - a))


## El trozo del bloque que queda fuera de la cruz de las puertas.
func _fuera_de_la_cruz(r: Rect2) -> Rect2:
	var a := r.position
	var b := r.end
	# Se recorta por el lado de la cruz que le queda mas cerca.
	if a.x < BANDA_X and b.x > -BANDA_X and a.y < BANDA_Y and b.y > -BANDA_Y:
		return Rect2()
	if a.x < BANDA_X and b.x > -BANDA_X:
		if r.get_center().x > 0.0:
			a.x = BANDA_X
		else:
			b.x = -BANDA_X
	if a.y < BANDA_Y and b.y > -BANDA_Y:
		if r.get_center().y > 0.0:
			a.y = BANDA_Y
		else:
			b.y = -BANDA_Y
	return Rect2(a, b - a)


## Lo que choca de un bloque: el bloque menos, por delante, lo que sube la cara
## (ParedSala.SUBE_CARA), como la pared de arriba: con vista 3/4 el cuerpo del
## mago se pinta delante de la cara y solo los pies tienen que quedarse en el
## suelo. Delante es abajo en el mundo tambien en vertical: lo que choca es
## siempre lo de horizontal (ver ParedSala).
func choque(bloque: Rect2) -> Rect2:
	if _borde_libre(bloque, Vector2i.DOWN):
		return bloque.grow_individual(0.0, 0.0, 0.0, -ParedSala.SUBE_CARA)
	return bloque


## True si el lado 'direccion' del bloque da al suelo de la sala (y no a la
## pared, como el de fuera de un bloque de esquina).
func _borde_libre(bloque: Rect2, direccion: Vector2i) -> bool:
	var m := _tamano * 0.5 - Vector2.ONE
	match direccion:
		Vector2i.UP:
			return bloque.position.y > -m.y
		Vector2i.DOWN:
			return bloque.end.y < m.y
		Vector2i.LEFT:
			return bloque.position.x > -m.x
		_:
			return bloque.end.x < m.x


## El bloque como se pinta: los lados pegados a la pared se alargan hasta el
## final del muro, para que la roca de encima siga sin corte la de la pared.
func _pintado(bloque: Rect2) -> Rect2:
	var g := Sala.GROSOR_MURO
	return bloque.grow_individual(
		0.0 if _borde_libre(bloque, Vector2i.LEFT) else g,
		0.0 if _borde_libre(bloque, Vector2i.UP) else g,
		0.0 if _borde_libre(bloque, Vector2i.RIGHT) else g,
		0.0 if _borde_libre(bloque, Vector2i.DOWN) else g)


# --- Pintado ------------------------------------------------------------------

## Pinta los bloques en 'lienzo' (la sala). 'origen' es donde esta la sala en el
## piso: la roca de encima va alineada con el mundo, como la de la pared.
##
## La cara va en el lado que da hacia abajo en la pantalla (en vertical, el de
## la izquierda del mundo), que es el que se ve de frente con vista 3/4, igual
## que la de la pared de arriba.
func pintar(lienzo: CanvasItem, estilo: EstiloBorde, origen: Vector2, color_muro: Color) -> void:
	var arriba := Vector2i(Vector2(Vector2i.UP).rotated(Vista.giro).round())
	var delante := -arriba
	for bloque in bloques:
		_pintar_sombra(lienzo, bloque, delante, estilo)
	for bloque in bloques:
		var caja := _pintado(bloque)
		_poligono_roca(lienzo, _esquinas(caja), estilo, origen, color_muro)
		if _borde_libre(bloque, delante):
			_pintar_cara(lienzo, bloque, delante, arriba, estilo, origen)
		_pintar_cantos(lienzo, bloque, delante, arriba, estilo)


func _esquinas(caja: Rect2) -> PackedVector2Array:
	return PackedVector2Array([caja.position, Vector2(caja.end.x, caja.position.y), caja.end,
		Vector2(caja.position.x, caja.end.y)])


func _poligono_roca(lienzo: CanvasItem, puntos: PackedVector2Array, estilo: EstiloBorde,
		origen: Vector2, color: Color) -> void:
	var tam := estilo.muro.get_size()
	var uvs := PackedVector2Array()
	var colores := PackedColorArray()
	for p in puntos:
		uvs.append(ParedSala.uv_muro(origen + p, tam))
		colores.append(color)
	lienzo.draw_polygon(puntos, colores, uvs, estilo.muro)


## Los dos extremos del lado 'direccion' del bloque, de izquierda a derecha en la
## pantalla.
func _lado(caja: Rect2, direccion: Vector2i) -> Array[Vector2]:
	var puntos: Array[Vector2]
	match direccion:
		Vector2i.UP:
			puntos = [caja.position, Vector2(caja.end.x, caja.position.y)]
		Vector2i.DOWN:
			puntos = [Vector2(caja.position.x, caja.end.y), caja.end]
		Vector2i.LEFT:
			puntos = [caja.position, Vector2(caja.position.x, caja.end.y)]
		_:
			puntos = [Vector2(caja.end.x, caja.position.y), caja.end]
	if puntos[0].rotated(-Vista.giro).x > puntos[1].rotated(-Vista.giro).x:
		puntos.reverse()
	return puntos


## La cara del bloque, de frente: del pie (el lado de delante) hacia arriba en
## la pantalla, con la textura de la cara de la pared.
func _pintar_cara(lienzo: CanvasItem, bloque: Rect2, delante: Vector2i, arriba: Vector2i,
		estilo: EstiloBorde, origen: Vector2) -> void:
	var fondo := absf(Vector2(arriba).dot(bloque.size))
	var alto := minf(estilo.alto_cara, fondo - ROCA_ENCIMA)
	if alto <= 4.0:
		return
	var pie := _lado(bloque, delante)
	var subir := Vector2(arriba) * alto
	var ancho_textura := estilo.cara.get_size().x
	var u0 := (origen + pie[0]).rotated(-Vista.giro).x / ancho_textura
	var u1 := (origen + pie[1]).rotated(-Vista.giro).x / ancho_textura
	var blanco := PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE])
	lienzo.draw_primitive(PackedVector2Array([pie[0] + subir, pie[1] + subir, pie[1], pie[0]]), blanco,
		PackedVector2Array([Vector2(u0, 0.0), Vector2(u1, 0.0), Vector2(u1, 1.0), Vector2(u0, 1.0)]),
		estilo.cara)


## La luz en el canto de arriba (en la de delante, en el labio de la cara) y la
## raya oscura del pie. Solo en los lados que dan al suelo.
func _pintar_cantos(lienzo: CanvasItem, bloque: Rect2, delante: Vector2i, arriba: Vector2i,
		estilo: EstiloBorde) -> void:
	var luz := Color(estilo.color_luz, 0.85)
	var pie := Color(estilo.color_sombra, 0.9)
	for direccion in MapaSalas.DIRECCIONES:
		if not _borde_libre(bloque, direccion):
			continue
		var lado := _lado(bloque, direccion)
		lienzo.draw_line(lado[0], lado[1], pie, 2.5, true)
		var hacia_dentro := -Vector2(direccion)
		var labio_en := 1.5
		if direccion == delante:
			var fondo := absf(Vector2(arriba).dot(bloque.size))
			labio_en = minf(estilo.alto_cara, fondo - ROCA_ENCIMA)
		lienzo.draw_line(lado[0] + hacia_dentro * labio_en, lado[1] + hacia_dentro * labio_en, luz, 2.0, true)


## La sombra que echa el bloque sobre el suelo, por los lados que dan a el. La de
## delante, mas ancha: la cara es alta y tapa la luz.
func _pintar_sombra(lienzo: CanvasItem, bloque: Rect2, delante: Vector2i, estilo: EstiloBorde) -> void:
	for direccion in MapaSalas.DIRECCIONES:
		if not _borde_libre(bloque, direccion):
			continue
		var ancho := SOMBRA_CARA if direccion == delante else SOMBRA
		var lado := _lado(bloque, direccion)
		var fuera := Vector2(direccion) * ancho
		var oscuro := Color(estilo.color_sombra, FUERZA_SOMBRA)
		var nada := Color(estilo.color_sombra, 0.0)
		lienzo.draw_primitive(PackedVector2Array([lado[0], lado[1], lado[1] + fuera, lado[0] + fuera]),
			PackedColorArray([oscuro, oscuro, nada, nada]), PackedVector2Array())
