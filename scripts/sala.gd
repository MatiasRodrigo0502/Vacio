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
## Se emite cada vez que muere un enemigo de la sala. La usa la mecanica de
## objetos para que, alguna vez, suelte una ventaja.
signal enemigo_muerto(enemigo: Enemigo)

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

# --- Arte del borde (herramientas/generar_bordes.py) ---
## Roca maciza que rellena la franja del muro, detras de las rocas del borde.
const MURO := preload("res://assets/bordes/muro.png")
const PILAR := preload("res://assets/bordes/pilar.png")
## Mide lo mismo que el hueco de la puerta (ANCHO_PUERTA x GROSOR_MURO).
const REJA := preload("res://assets/bordes/reja.png")
## La roca del muro, respecto al color del suelo: algo mas oscura, para que
## las rocas del borde destaquen encima y se lea que ahi ya no se pisa.
const FACTOR_MURO: float = 1.3
## Cuanto tarda la franja del muro en fundirse con la roca oscura del fondo
## (la pinta el piso) por los lados sin puerta.
const FUNDIDO_MURO: float = 90.0
## Sombra en el filo del suelo: ancho y lo oscura que es junto a la pared. Es
## lo que hace que la sala se lea hundida entre paredes de roca y no como un
## suelo con rocas pegadas encima.
const SOMBRA_ANCHO: float = 52.0
const SOMBRA_FUERZA: float = 0.5
## Lo que tarda el rastrillo en bajar o subir del todo.
const DURACION_REJA: float = 0.22

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
## El tinte de las rocas del piso: los pilares son de la misma piedra.
var _tinte: Color = Color.WHITE
## Cuanto ha bajado el rastrillo: 0 abierto, 1 cerrado. Se anima hacia
## _reja_objetivo en _process, que solo corre mientras se mueve.
var _reja: float = 0.0
var _reja_objetivo: float = 0.0
var _cerrada: bool = false
## True desde que el jugador entra del todo por primera vez.
var _activada: bool = false
var _enemigos: Array[Enemigo] = []
var _cierres: Dictionary = {}
## Las rocas del filo: centro (x, y) y radio, en local. Ver anadir_roca_filo().
var _rocas_filo: Array[Vector3] = []
var _cuerpo_filo: StaticBody2D = null
## Las cajas de colision de las rocas y plataformas de dentro, en local. Las
## apunta el piso al colocarlas. Ver sacar_de_las_rocas().
var _rocas: Array[Rect2] = []


## Monta la sala. La llama Piso justo despues de add_child().
func construir(celda_sala: Vector2i, tipo_sala: MapaSalas.Tipo, tamano_sala: Vector2,
		puertas_sala: Array[Vector2i], color_suelo: Color, color_borde: Color,
		tinte: Color = Color.WHITE) -> void:
	celda = celda_sala
	tipo = tipo_sala
	tamano = tamano_sala
	puertas = puertas_sala
	_color_suelo = color_suelo
	_color_borde = color_borde
	_tinte = tinte
	# El muro se pinta repitiendo su textura, y eso hay que pedirlo.
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	set_process(false)

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


## Apunta una roca del filo de la sala: las que tapan el borde recto del suelo
## y se meten un poco en el. Chocan como las rocas de dentro (su capa), asi que
## paran al jugador, sus bolas y los disparos enemigos.
##
## POR QUE HACE FALTA QUE CHOQUEN:
## el muro de verdad sigue siendo recto, justo en el borde del suelo. Una roca
## que se mete en la sala y no choca se atravesaria, y el jugador tiene que
## poder fiarse de lo que ve: el limite de la sala ahora son las rocas.
func anadir_roca_filo(centro: Vector2, radio: float) -> void:
	if _cuerpo_filo == null:
		_cuerpo_filo = StaticBody2D.new()
		_cuerpo_filo.name = "Filo"
		_cuerpo_filo.collision_layer = Terreno.CAPA_ROCAS
		_cuerpo_filo.collision_mask = 0
		add_child(_cuerpo_filo)
	var forma := CollisionShape2D.new()
	var circulo := CircleShape2D.new()
	circulo.radius = radio
	forma.shape = circulo
	forma.position = centro
	_cuerpo_filo.add_child(forma)
	_rocas_filo.append(Vector3(centro.x, centro.y, radio))


## Apunta la caja de colision (global) de una roca o plataforma de dentro.
func registrar_roca(caja_global: Rect2) -> void:
	_rocas.append(Rect2(to_local(caja_global.position), caja_global.size))


## El punto (global) mas cercano en el que algo de ese radio no queda dentro de
## ninguna roca de la sala.
##
## POR QUE HACE FALTA:
## los enemigos son areas y atraviesan las rocas, pero las rocas paran las
## bolas. Un enemigo a distancia retrocede al acercarte, y arrinconado contra
## el borde podria acabar metido en una roca del filo: la bola chocaria con la
## roca y no le llegaria nunca, y la sala no se abriria. Es preventivo: no se
## llego a ver pasar (la sala que no se abria en la prueba era otra cosa, el
## radio de la bola; ver BolaMagica.RADIO_CONTRA_ROCAS). Sacandolos de las
## rocas, a todo enemigo se le puede dar.
func sacar_de_las_rocas(punto_global: Vector2, radio: float) -> Vector2:
	var punto := to_local(punto_global)
	for roca in _rocas_filo:
		var centro := Vector2(roca.x, roca.y)
		var hacia := punto - centro
		var minimo := roca.z + radio
		if hacia.length() < minimo:
			# Justo en el centro no hay direccion: hacia el centro de la sala,
			# que es hacia donde queda sitio.
			var direccion := hacia.normalized() if hacia.length() > 0.01 else -centro.normalized()
			punto = centro + direccion * minimo
	for caja in _rocas:
		var grande := caja.grow(radio)
		if not grande.has_point(punto):
			continue
		# Por el lado mas cercano: es el empujon mas pequeno.
		var izquierda := punto.x - grande.position.x
		var derecha := grande.end.x - punto.x
		var arriba := punto.y - grande.position.y
		var abajo := grande.end.y - punto.y
		var menor := minf(minf(izquierda, derecha), minf(arriba, abajo))
		if menor == izquierda:
			punto.x = grande.position.x
		elif menor == derecha:
			punto.x = grande.end.x
		elif menor == arriba:
			punto.y = grande.position.y
		else:
			punto.y = grande.end.y
	return to_global(punto)


## True si algo de ese radio en ese punto (global) quedaria encima de una roca
## del filo.
func pisa_roca_filo(punto_global: Vector2, radio: float) -> bool:
	var punto := to_local(punto_global)
	for roca in _rocas_filo:
		if punto.distance_to(Vector2(roca.x, roca.y)) < roca.z + radio:
			return true
	return false


## Colores de la sala. Los peligros los usan para ser de la misma piedra.
func color_suelo() -> Color:
	return _color_suelo


func color_borde() -> Color:
	return _color_borde


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
	# El cierre choca ya; el rastrillo baja (o sube) en un momento. Verlo
	# moverse es lo que dice "te han encerrado" y "ya puedes salir".
	_reja_objetivo = 1.0 if cerrar else 0.0
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	_reja = move_toward(_reja, _reja_objetivo, delta / DURACION_REJA)
	queue_redraw()
	if is_equal_approx(_reja, _reja_objetivo):
		# Justo al valor: "casi 0" dejaba el rastrillo con una millonesima
		# bajada, que no se ve pero cuenta como bajado.
		_reja = _reja_objetivo
		set_process(false)


## Cuanto ocupa a lo largo del muro lo que se pone a cada lado de una puerta
## (el pilar). El piso no pone rocas del fondo ahi, o lo taparian.
func tramo_pilar(direccion: Vector2i) -> float:
	if direccion == Vector2i.UP or direccion == Vector2i.DOWN:
		return float(PILAR.get_width())
	return float(PILAR.get_height())


func _al_morir_enemigo(enemigo: Enemigo) -> void:
	_enemigos.erase(enemigo)
	enemigo_muerto.emit(enemigo)
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
	_pintar_muro()
	var suelo := rect_suelo()
	# Sin linea de limite: el borde del suelo lo tapan las rocas del filo, que
	# chocan, y son ellas las que dicen donde acaba la sala. Una raya recta por
	# debajo delataria el cuadrado.
	draw_rect(suelo, _color_suelo)
	_pintar_sombra_filo()

	for direccion in puertas:
		# El suelo del pasillo, en la mitad que es de esta sala, algo mas oscuro
		# (ya esta dentro de la roca). Se alarga unos pixeles hacia dentro para
		# que no quede una rendija entre el suelo de la sala y el del pasillo.
		var hueco := _hueco(direccion).grow_individual(
			4.0 if direccion == Vector2i.RIGHT else 0.0,
			4.0 if direccion == Vector2i.DOWN else 0.0,
			4.0 if direccion == Vector2i.LEFT else 0.0,
			4.0 if direccion == Vector2i.UP else 0.0)
		draw_rect(hueco, _color_suelo.darkened(0.12))
		_pintar_sombra_pasillo(direccion)
		if _reja > 0.0:
			_pintar_reja(direccion)
		_pintar_pilares(direccion)

	if tipo == MapaSalas.Tipo.SALIDA:
		_pintar_salida()


## La roca maciza de detras del borde: la franja del muro entera, y por los
## lados sin puerta un fundido hacia la roca oscura del fondo, que pinta el
## piso. Asi la sala queda como lo unico iluminado y la roca se hunde en la
## oscuridad al alejarse.
##
## SE PINTA ALINEADA CON EL MUNDO, NO CON LA SALA:
## las coordenadas de la textura salen de la posicion en el piso. Asi la roca
## sigue igual de una sala a otra y la del fondo casa con la de la franja: los
## trozos que se pisan (el fundido de una sala con el de la que tiene en
## diagonal) son la misma roca en el mismo sitio, y no se nota. Con cada sala
## repitiendo la textura desde su esquina, en esos cruces salian cortes rectos.
func _pintar_muro() -> void:
	var zona := rect_suelo().grow(GROSOR_MURO)
	var color := color_muro()
	var nada := Color(color.r, color.g, color.b, 0.0)
	_poligono_muro([zona.position, Vector2(zona.end.x, zona.position.y), zona.end,
		Vector2(zona.position.x, zona.end.y)], [color, color, color, color])

	var f := FUNDIDO_MURO
	var a := zona.position
	var b := zona.end
	# Un fundido por cada lado sin puerta, y en las esquinas un cuarto que
	# se apaga hacia fuera, para que no quede un escalon.
	if not Vector2i.UP in puertas:
		_poligono_muro([Vector2(a.x, a.y - f), Vector2(b.x, a.y - f), Vector2(b.x, a.y), a],
			[nada, nada, color, color])
	if not Vector2i.DOWN in puertas:
		_poligono_muro([Vector2(a.x, b.y), b, Vector2(b.x, b.y + f), Vector2(a.x, b.y + f)],
			[color, color, nada, nada])
	if not Vector2i.LEFT in puertas:
		_poligono_muro([Vector2(a.x - f, a.y), a, Vector2(a.x, b.y), Vector2(a.x - f, b.y)],
			[nada, color, color, nada])
	if not Vector2i.RIGHT in puertas:
		_poligono_muro([Vector2(b.x, a.y), Vector2(b.x + f, a.y), Vector2(b.x + f, b.y), b],
			[color, nada, nada, color])
	for esquina in [a, Vector2(b.x, a.y), b, Vector2(a.x, b.y)]:
		var sx := -1.0 if esquina.x == a.x else 1.0
		var sy := -1.0 if esquina.y == a.y else 1.0
		_poligono_muro([esquina, esquina + Vector2(sx * f, 0.0), esquina + Vector2(sx * f, sy * f),
			esquina + Vector2(0.0, sy * f)], [color, nada, nada, nada])


## Color de la roca del muro. Algo mas oscuro que el suelo: las rocas del borde
## destacan encima y se lee que ahi ya no se pisa. El piso lo usa tambien para
## la roca del fondo, mas oscura todavia.
func color_muro() -> Color:
	return Color(_color_suelo.r * FACTOR_MURO, _color_suelo.g * FACTOR_MURO,
		_color_suelo.b * FACTOR_MURO, 1.0)


## Un poligono con la textura del muro, alineada con el mundo (ver _pintar_muro).
func _poligono_muro(puntos: Array, colores: Array) -> void:
	var tam := MURO.get_size()
	var uvs := PackedVector2Array()
	for punto: Vector2 in puntos:
		uvs.append((position + punto) / tam)
	draw_polygon(PackedVector2Array(puntos), PackedColorArray(colores), uvs, MURO)


## Sombra por dentro del filo del suelo, de oscura junto a la pared a nada.
## Delante de las puertas no hay: por ahi el suelo sigue.
func _pintar_sombra_filo() -> void:
	var medio := tamano * 0.5
	for direccion in MapaSalas.DIRECCIONES:
		var horizontal := direccion == Vector2i.UP or direccion == Vector2i.DOWN
		var largo := medio.x if horizontal else medio.y
		var tramos: Array[Vector2] = [Vector2(-largo, largo)]
		if direccion in puertas:
			tramos = [Vector2(-largo, -ANCHO_PUERTA * 0.5), Vector2(ANCHO_PUERTA * 0.5, largo)]
		for tramo in tramos:
			_franja_sombra(direccion, tramo.x, tramo.y)


## Una franja de sombra pegada al lado 'direccion' del suelo, de 'desde' a
## 'hasta' a lo largo de ese lado.
func _franja_sombra(direccion: Vector2i, desde: float, hasta: float) -> void:
	var medio := tamano * 0.5
	var oscuro := Color(0.0, 0.0, 0.0, SOMBRA_FUERZA)
	var nada := Color(0.0, 0.0, 0.0, 0.0)
	var puntos: PackedVector2Array
	match direccion:
		Vector2i.UP:
			puntos = [Vector2(desde, -medio.y), Vector2(hasta, -medio.y),
				Vector2(hasta, -medio.y + SOMBRA_ANCHO), Vector2(desde, -medio.y + SOMBRA_ANCHO)]
		Vector2i.DOWN:
			puntos = [Vector2(desde, medio.y), Vector2(hasta, medio.y),
				Vector2(hasta, medio.y - SOMBRA_ANCHO), Vector2(desde, medio.y - SOMBRA_ANCHO)]
		Vector2i.LEFT:
			puntos = [Vector2(-medio.x, desde), Vector2(-medio.x, hasta),
				Vector2(-medio.x + SOMBRA_ANCHO, hasta), Vector2(-medio.x + SOMBRA_ANCHO, desde)]
		_:
			puntos = [Vector2(medio.x, desde), Vector2(medio.x, hasta),
				Vector2(medio.x - SOMBRA_ANCHO, hasta), Vector2(medio.x - SOMBRA_ANCHO, desde)]
	draw_polygon(puntos, PackedColorArray([oscuro, oscuro, nada, nada]))


## Sombra en los dos lados del pasillo de una puerta: sus paredes son roca.
func _pintar_sombra_pasillo(direccion: Vector2i) -> void:
	var hueco := _hueco(direccion)
	var ancho := 16.0
	var oscuro := Color(0.0, 0.0, 0.0, SOMBRA_FUERZA)
	var nada := Color(0.0, 0.0, 0.0, 0.0)
	if direccion == Vector2i.UP or direccion == Vector2i.DOWN:
		var y0 := hueco.position.y
		var y1 := hueco.end.y
		var x0 := hueco.position.x
		var x1 := hueco.end.x
		draw_polygon(PackedVector2Array([Vector2(x0, y0), Vector2(x0 + ancho, y0),
			Vector2(x0 + ancho, y1), Vector2(x0, y1)]), PackedColorArray([oscuro, nada, nada, oscuro]))
		draw_polygon(PackedVector2Array([Vector2(x1, y0), Vector2(x1 - ancho, y0),
			Vector2(x1 - ancho, y1), Vector2(x1, y1)]), PackedColorArray([oscuro, nada, nada, oscuro]))
	else:
		var x0 := hueco.position.x
		var x1 := hueco.end.x
		var y0 := hueco.position.y
		var y1 := hueco.end.y
		draw_polygon(PackedVector2Array([Vector2(x0, y0), Vector2(x0, y0 + ancho),
			Vector2(x1, y0 + ancho), Vector2(x1, y0)]), PackedColorArray([oscuro, nada, nada, oscuro]))
		draw_polygon(PackedVector2Array([Vector2(x0, y1), Vector2(x0, y1 - ancho),
			Vector2(x1, y1 - ancho), Vector2(x1, y1)]), PackedColorArray([oscuro, nada, nada, oscuro]))


## El rastrillo de una puerta, bajado lo que diga _reja. Sale desde fuera de la
## sala hacia dentro, con las puntas por delante.
##
## Se dibuja en el espacio de la puerta: el mismo rastrillo girado para que
## las puntas miren siempre hacia la sala, como las puertas de Isaac.
func _pintar_reja(direccion: Vector2i) -> void:
	var hueco := _hueco(direccion)
	# La textura tiene las puntas hacia abajo (+y); se gira para que apunten
	# hacia la sala, que esta en -direccion.
	var giro := (-Vector2(direccion)).angle() - PI * 0.5
	draw_set_transform(hueco.get_center(), giro)
	var ancho := ANCHO_PUERTA
	var fondo := GROSOR_MURO
	var visible_alto := fondo * _reja
	var tam := REJA.get_size()
	# Fondo oscuro detras de los barrotes: por el hueco ya no se ve el pasillo.
	draw_rect(Rect2(-ancho * 0.5, -fondo * 0.5, ancho, visible_alto), Color(0.03, 0.02, 0.02, 0.55))
	draw_texture_rect_region(REJA,
		Rect2(-ancho * 0.5, -fondo * 0.5, ancho, visible_alto),
		Rect2(0.0, tam.y * (1.0 - _reja), tam.x, tam.y * _reja))
	draw_set_transform(Vector2.ZERO)


## Un pilar a cada lado de la puerta, de pie en la franja del muro. Con la
## base en el filo del suelo para las puertas de arriba y abajo; en las de los
## lados, uno encima y otro debajo del hueco.
func _pintar_pilares(direccion: Vector2i) -> void:
	var tam := PILAR.get_size()
	var medio := tamano * 0.5
	var hueco := _hueco(direccion)
	var sitios: Array[Rect2] = []
	match direccion:
		Vector2i.UP:
			for signo in [-1.0, 1.0]:
				var x: float = signo * (ANCHO_PUERTA + tam.x) * 0.5
				sitios.append(Rect2(x - tam.x * 0.5, -medio.y - tam.y + 10.0, tam.x, tam.y))
		Vector2i.DOWN:
			for signo in [-1.0, 1.0]:
				var x: float = signo * (ANCHO_PUERTA + tam.x) * 0.5
				sitios.append(Rect2(x - tam.x * 0.5, medio.y - 8.0, tam.x, tam.y))
		_:
			var x := hueco.get_center().x - tam.x * 0.5
			sitios.append(Rect2(x, -ANCHO_PUERTA * 0.5 - tam.y - 2.0, tam.x, tam.y))
			sitios.append(Rect2(x, ANCHO_PUERTA * 0.5 - 6.0, tam.x, tam.y))
	for sitio in sitios:
		draw_texture_rect(PILAR, sitio, false, _tinte)


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
