## Una sala del piso: su suelo, sus muros con los huecos de las puertas y lo que
## pasa dentro (quien vive aqui, si esta cerrada, si ya se ha limpiado).
##
## Todo se construye por codigo, como antes los muros del piso: las medidas
## salen del .tres del piso y cambian en cada capa, asi que una escena fija no
## serviria de nada.
##
## COMO SE UNEN DOS SALAS:
## cada sala tiene un muro de GROSOR_MURO por fuera de su suelo, y las salas se
## colocan pegadas muro con muro. Entre dos vecinas queda una franja de dos
## muros, y la puerta es el mismo hueco abierto en los dos. Cada sala dibuja y
## cierra SU mitad del pasillo, asi que no hace falta que ninguna sepa nada de
## la otra: si una esta cerrada, el paso esta cerrado.
class_name Sala
extends Node2D

## Se emite cuando no queda ningun enemigo vivo dentro.
signal despejada(sala: Sala)

## Grosor de cada muro. Generoso a proposito: con muros finos y velocidades
## altas el jugador puede atravesarlos (tunneling).
const GROSOR_MURO: float = 64.0
## Ancho del hueco de las puertas. El jugador mide 30 px: con 130 pasa sin
## tener que apuntar, que es lo que se espera de una puerta.
const ANCHO_PUERTA: float = 130.0
## Radio del agujero de bajada, en la sala de salida.
const RADIO_SALIDA: float = 46.0
## Capa de fisica de los muros. Los cierres de las puertas van en la misma:
## para el jugador una puerta cerrada es muro, y asi no hay que tocar su mascara.
const CAPA_MUROS: int = 2

var celda: Vector2i = Vector2i.ZERO
var tipo: MapaSalas.Tipo = MapaSalas.Tipo.NORMAL
## Medidas del suelo, sin contar los muros.
var tamano: Vector2 = Vector2(1200.0, 700.0)
## Direcciones con puerta (Vector2i.UP, RIGHT...).
var puertas: Array[Vector2i] = []
## Si el jugador ya ha estado dentro. Lo usa el minimapa.
var visitada: bool = false

var _color_suelo: Color = Color(0.16, 0.13, 0.12)
var _color_borde: Color = Color(0.55, 0.40, 0.28)
var _cerrada: bool = false
## True desde que el jugador entra del todo por primera vez.
var _activada: bool = false
var _enemigos: Array[Enemigo] = []
var _cierres: Dictionary = {}


## Monta la sala. La llama Piso justo despues de add_child().
func construir(celda_sala: Vector2i, tipo_sala: MapaSalas.Tipo, tamano_sala: Vector2,
		puertas_sala: Array[Vector2i], color_suelo: Color, color_borde: Color) -> void:
	celda = celda_sala
	tipo = tipo_sala
	tamano = tamano_sala
	puertas = puertas_sala
	_color_suelo = color_suelo
	_color_borde = color_borde

	var muros := StaticBody2D.new()
	muros.name = "Muros"
	muros.collision_layer = CAPA_MUROS
	muros.collision_mask = 0
	add_child(muros)

	# Los cierres son un cuerpo aparte para poder encenderlos y apagarlos sin
	# tocar los muros de verdad.
	var cierres := StaticBody2D.new()
	cierres.name = "Cierres"
	cierres.collision_layer = CAPA_MUROS
	cierres.collision_mask = 0
	add_child(cierres)

	for direccion in MapaSalas.DIRECCIONES:
		var banda := _banda(direccion)
		if direccion in puertas:
			var hueco := _hueco(direccion)
			for trozo in _restar(banda, hueco, direccion):
				_anadir_forma(muros, trozo)
			# Abiertas al empezar. set_deferred no hace falta aqui porque la sala
			# se construye fuera del paso de fisica.
			_cierres[direccion] = _anadir_forma(cierres, hueco)
			_cierres[direccion].disabled = true
		else:
			_anadir_forma(muros, banda)
	queue_redraw()


## Suelo de la sala en coordenadas locales.
func rect_suelo() -> Rect2:
	return Rect2(-tamano * 0.5, tamano)


## Suelo de la sala en coordenadas del mundo. Lo usan la camara y las bolas.
func rect_suelo_global() -> Rect2:
	return Rect2(global_position - tamano * 0.5, tamano)


## El suelo y la mitad de muro que es de esta sala, en el mundo: la casilla
## entera. Lo usa la camara, para que se vea donde acaba la sala y por donde se
## sale, y lo usan las bolas, que se apagan al salir de aqui (asi disparar
## desde el umbral de la puerta tambien funciona).
func rect_con_muros() -> Rect2:
	return rect_suelo_global().grow(GROSOR_MURO)


## Punto del borde del suelo donde esta cada puerta, en local.
func punto_puerta(direccion: Vector2i) -> Vector2:
	return Vector2(direccion) * tamano * 0.5


## True si ese punto (local) esta pegado a alguna puerta. Para que ni rocas ni
## enemigos aparezcan tapando la entrada a la sala.
func cerca_de_puerta(punto: Vector2, distancia: float) -> bool:
	for direccion in puertas:
		if punto.distance_to(punto_puerta(direccion)) < distancia:
			return true
	return false


## Un punto al azar del suelo, en local, a cierta distancia de las paredes.
func punto_al_azar(generador: RandomNumberGenerator, margen: float) -> Vector2:
	var medio := tamano * 0.5 - Vector2(margen, margen)
	return Vector2(generador.randf_range(-medio.x, medio.x),
		generador.randf_range(-medio.y, medio.y))


## Las salas normales y la de salida tienen enemigos. El inicio no, para no
## empezar un piso recibiendo golpes; la del objeto tampoco, porque es el premio
## por desviarse, no otra pelea.
func admite_enemigos() -> bool:
	return tipo == MapaSalas.Tipo.NORMAL or tipo == MapaSalas.Tipo.SALIDA


## Apunta un enemigo como vecino de esta sala. Lo llama la mecanica que los
## reparte, despues de colocarlo.
func registrar_enemigo(enemigo: Enemigo) -> void:
	_enemigos.append(enemigo)
	enemigo.muerto.connect(_al_morir_enemigo)
	# Duerme hasta que el jugador entre: si no, vendria a por el a traves de
	# los muros desde la sala de al lado.
	if not _activada:
		enemigo.dormir()


func enemigos_vivos() -> int:
	return _enemigos.size()


func esta_despejada() -> bool:
	return _enemigos.is_empty()


func esta_cerrada() -> bool:
	return _cerrada


func esta_activada() -> bool:
	return _activada


## El jugador acaba de entrar del todo. Si quedan enemigos, se cierran las
## puertas y se despiertan: no se sale hasta limpiar la sala.
##
## Solo la primera vez: una sala despejada se queda abierta para siempre, y una
## que no se ha limpiado no se puede dejar (tiene las puertas cerradas).
func activar() -> void:
	if _activada:
		return
	_activada = true
	visitada = true
	if esta_despejada():
		return
	cerrar_puertas(true)
	for enemigo in _enemigos:
		# En el juego un enemigo solo desaparece muriendo, y al morir sale de la
		# lista. La guarda es por si algun dia algo lo quita de otra forma:
		# despertar a un nodo liberado revienta el juego.
		if is_instance_valid(enemigo):
			enemigo.despertar()


## True si el circulo (centro global, radio) cabe entero en el suelo. Las
## puertas solo se cierran cuando el jugador ha entrado del todo: si se
## cerraran con medio cuerpo en el hueco, el cierre naceria encima de el.
func contiene_del_todo(centro_global: Vector2, radio: float) -> bool:
	return rect_suelo_global().grow(-radio).has_point(centro_global)


## Cierra o abre todas las puertas.
##
## set_deferred porque esto se llama desde el paso de fisica (el jugador acaba
## de cruzar el umbral), y encender una forma de colision en mitad de ese paso
## hace que el motor se queje.
func cerrar_puertas(cerrar: bool) -> void:
	_cerrada = cerrar
	for direccion in _cierres:
		_cierres[direccion].set_deferred("disabled", not cerrar)
	queue_redraw()


func _al_morir_enemigo(enemigo: Enemigo) -> void:
	_enemigos.erase(enemigo)
	if _enemigos.is_empty():
		cerrar_puertas(false)
		despejada.emit(self)


# --- Geometria de los muros ------------------------------------------------

## La franja de muro de un lado, por fuera del suelo. Se alarga GROSOR_MURO por
## cada extremo para que las esquinas queden tapadas: sin eso, en cada esquina
## habria un hueco cuadrado por el que colarse.
func _banda(direccion: Vector2i) -> Rect2:
	var medio := tamano * 0.5
	var g := GROSOR_MURO
	match direccion:
		Vector2i.UP:
			return Rect2(-medio.x - g, -medio.y - g, tamano.x + g * 2.0, g)
		Vector2i.DOWN:
			return Rect2(-medio.x - g, medio.y, tamano.x + g * 2.0, g)
		Vector2i.LEFT:
			return Rect2(-medio.x - g, -medio.y - g, g, tamano.y + g * 2.0)
		_:
			return Rect2(medio.x, -medio.y - g, g, tamano.y + g * 2.0)


## El hueco de la puerta dentro de la franja de ese lado, centrado.
func _hueco(direccion: Vector2i) -> Rect2:
	var banda := _banda(direccion)
	if direccion == Vector2i.UP or direccion == Vector2i.DOWN:
		return Rect2(-ANCHO_PUERTA * 0.5, banda.position.y, ANCHO_PUERTA, banda.size.y)
	return Rect2(banda.position.x, -ANCHO_PUERTA * 0.5, banda.size.x, ANCHO_PUERTA)


## Los dos trozos de franja que quedan a los lados del hueco.
func _restar(banda: Rect2, hueco: Rect2, direccion: Vector2i) -> Array[Rect2]:
	if direccion == Vector2i.UP or direccion == Vector2i.DOWN:
		return [
			Rect2(banda.position.x, banda.position.y,
				hueco.position.x - banda.position.x, banda.size.y),
			Rect2(hueco.end.x, banda.position.y, banda.end.x - hueco.end.x, banda.size.y),
		]
	return [
		Rect2(banda.position.x, banda.position.y,
			banda.size.x, hueco.position.y - banda.position.y),
		Rect2(banda.position.x, hueco.end.y, banda.size.x, banda.end.y - hueco.end.y),
	]


func _anadir_forma(cuerpo: StaticBody2D, rect: Rect2) -> CollisionShape2D:
	var forma := CollisionShape2D.new()
	var rectangulo := RectangleShape2D.new()
	rectangulo.size = rect.size
	forma.shape = rectangulo
	forma.position = rect.get_center()
	cuerpo.add_child(forma)
	return forma


# --- Pintado ----------------------------------------------------------------

func _draw() -> void:
	var suelo := rect_suelo()
	draw_rect(suelo, _color_suelo)
	# La linea del limite va tenue: las rocas de alrededor ya dicen donde acaba
	# la sala. Se mantiene porque marca exactamente el muro invisible, y en un
	# juego de precision el jugador lo agradece.
	draw_rect(suelo, Color(_color_borde.r, _color_borde.g, _color_borde.b, 0.35), false, 4.0)

	for direccion in puertas:
		# El suelo del pasillo, en la mitad que es de esta sala. Se alarga unos
		# pixeles hacia dentro para tapar la linea del limite: una raya cruzando
		# la puerta se leeria como una puerta cerrada.
		var hueco := _hueco(direccion).grow_individual(
			4.0 if direccion == Vector2i.RIGHT else 0.0,
			4.0 if direccion == Vector2i.DOWN else 0.0,
			4.0 if direccion == Vector2i.LEFT else 0.0,
			4.0 if direccion == Vector2i.UP else 0.0)
		draw_rect(hueco, _color_suelo)
		# Jambas: dos marcas a los lados del hueco, para que la puerta se vea
		# como puerta y no como un trozo de muro que falta.
		_pintar_jambas(direccion)
		if _cerrada:
			_pintar_reja(_hueco(direccion), direccion)

	if tipo == MapaSalas.Tipo.SALIDA:
		_pintar_salida()


func _pintar_jambas(direccion: Vector2i) -> void:
	var color := Color(_color_borde.r, _color_borde.g, _color_borde.b, 0.8)
	var a := ANCHO_PUERTA * 0.5
	var borde := punto_puerta(direccion)
	var lado := Vector2(direccion.y, direccion.x).abs()
	var fuera := Vector2(direccion) * GROSOR_MURO
	for signo in [-1.0, 1.0]:
		var p: Vector2 = borde + lado * a * signo
		draw_line(p, p + fuera, color, 4.0)


## La puerta cerrada: una reja del color del borde. Barrotes y no una losa
## maciza, para que se entienda que se abrira, que no es un muro.
func _pintar_reja(hueco: Rect2, direccion: Vector2i) -> void:
	draw_rect(hueco, Color(0.05, 0.03, 0.03, 0.85))
	var color := Color(_color_borde.r, _color_borde.g, _color_borde.b, 0.95)
	var vertical := direccion == Vector2i.UP or direccion == Vector2i.DOWN
	var barrotes := 5
	for i in barrotes + 1:
		var t := float(i) / barrotes
		if vertical:
			var x := hueco.position.x + hueco.size.x * t
			draw_line(Vector2(x, hueco.position.y), Vector2(x, hueco.end.y), color, 4.0)
		else:
			var y := hueco.position.y + hueco.size.y * t
			draw_line(Vector2(hueco.position.x, y), Vector2(hueco.end.x, y), color, 4.0)
	draw_rect(hueco, color, false, 3.0)


## El agujero de bajada. Mientras la sala tiene enemigos esta tapado: se ve
## donde esta, pero no se puede usar hasta limpiar la sala.
func _pintar_salida() -> void:
	if esta_despejada():
		draw_circle(Vector2.ZERO, RADIO_SALIDA, Color(0.05, 0.03, 0.03, 0.9))
		draw_arc(Vector2.ZERO, RADIO_SALIDA, 0.0, TAU, 32, _color_borde, 4.0, true)
		draw_arc(Vector2.ZERO, RADIO_SALIDA * 0.55, 0.0, TAU, 24,
			Color(_color_borde.r, _color_borde.g, _color_borde.b, 0.5), 3.0, true)
	else:
		draw_circle(Vector2.ZERO, RADIO_SALIDA, Color(_color_borde.r * 0.5,
			_color_borde.g * 0.5, _color_borde.b * 0.5, 0.9))
		var color := Color(_color_borde.r, _color_borde.g, _color_borde.b, 0.7)
		var r := RADIO_SALIDA * 0.7
		draw_line(Vector2(-r, -r), Vector2(r, r), color, 4.0)
		draw_line(Vector2(-r, r), Vector2(r, -r), color, 4.0)
		draw_arc(Vector2.ZERO, RADIO_SALIDA, 0.0, TAU, 32, color, 3.0, true)
