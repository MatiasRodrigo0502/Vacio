## Piso generico: una sola escena que se construye leyendo un DatosPiso.
##
## POR QUE UNA UNICA ESCENA PARA LOS 12 PISOS:
## si cada piso fuera su propia escena tendriamos 12 archivos .tscn casi
## identicos que habria que tocar a mano cada vez que cambie algo estructural
## (y 12 focos de conflicto de merge). Aqui la geometria se genera en tiempo de
## ejecucion a partir del .tres, asi que el contenido de un piso se ajusta
## editando datos, nunca escenas.
##
## DE PASILLO A MAPA DE SALAS:
## cada piso era un pasillo que se bajaba de arriba abajo. Ahora es un mapa de
## salas unidas por puertas, como en The Binding of Isaac: MapaSalas decide la
## forma, cada Sala se construye a si misma, y este script las coloca, las
## llena de rocas y decoracion y sigue en cual esta el jugador. El embudo sigue
## ahi: cuanto mas se baja, mas salas, mas pequenas y menos se ve de cada una.
class_name Piso
extends Node2D

## Se emite cuando el jugador alcanza la zona de salida.
signal salida_alcanzada
## Se emite cuando el jugador pasa de una sala a otra. Principal la usa para
## encajar la camara en la sala nueva.
signal sala_cambiada(sala: Sala)

## Espacio libre delante de cada puerta: nada que la tape por dentro.
const DESPEJE_PUERTA: float = 190.0
## Espacio libre alrededor del agujero de bajada.
const DESPEJE_SALIDA: float = 150.0
## Margen que se deja libre por encima y por debajo de cada cartel del tutorial.
const HOLGURA_CARTEL: float = 34.0
## Cuanto tiene que haber entrado el jugador en una sala para que se cierren
## las puertas: su radio (15) y un poco mas. Con menos, el cierre podria nacer
## rozandole el cuerpo en el umbral.
const MARGEN_ENTRAR: float = 26.0

## Catalogo de rocas por defecto. Cada piso puede sobreescribirlo desde su .tres.
const CATALOGO_POR_DEFECTO := preload("res://assets/cueva/catalogo_cueva.tres")

## Carteles de controles. Solo se instancian en los pisos que lo pidan.
const ESCENA_TUTORIAL := preload("res://scenes/Tutorial.tscn")

var datos: DatosPiso = null
var numero_piso: int = 1

var _pool: PoolObstaculos = null
var _obstaculos: Array[Obstaculo] = []
var _mecanicas: Array[Mecanica] = []
var _salida_usada: bool = false
## Rectangulos donde no se puede colocar nada: ahora mismo, los carteles del
## tutorial. En coordenadas locales del piso.
var _zonas_prohibidas: Array[Rect2] = []

var _mapa: MapaSalas = null
## Las salas por casilla, para encontrar en cual esta un punto sin recorrerlas.
var _salas: Dictionary = {}
## Las mismas, en el orden del mapa. Lo que se reparte al azar recorre esta
## lista y no el diccionario, para que el orden sea el mismo en todas partes.
var _orden_salas: Array[Sala] = []
var _sala_actual: Sala = null
var _jugador: Node2D = null

@onready var _contenedor_salas: Node2D = $Salas
@onready var _decoracion: Node2D = $Decoracion
@onready var _zona_salida: Area2D = $ZonaSalida
@onready var _forma_salida: CollisionShape2D = $ZonaSalida/Forma


func _ready() -> void:
	_zona_salida.body_entered.connect(_al_entrar_en_salida)


## Construye el piso. Principal la llama justo despues de add_child(), para que
## los @onready ya esten resueltos.
func configurar(datos_piso: DatosPiso, numero: int, pool: PoolObstaculos,
		mecanicas: Array[Mecanica]) -> void:
	datos = datos_piso
	numero_piso = numero
	_pool = pool
	_mecanicas = mecanicas
	_salida_usada = false

	# El nodo de decoracion se vacia AQUI y no dentro de cada funcion que lo
	# llena: plataformas, decoracion suelta y borde escriben en el mismo nodo,
	# y si cada una lo vaciara, la ultima borraria el trabajo de las anteriores.
	for hijo in _decoracion.get_children():
		hijo.queue_free()

	_construir_salas()
	_colocar_salida()
	# El tutorial va ANTES que las rocas a proposito: deja apuntadas las zonas
	# que ocupan sus carteles para que nada se coloque encima.
	_colocar_tutorial()
	_colocar_obstaculos()

	# Las mecanicas se aplican al final, cuando las salas ya existen: asi pueden
	# repartir enemigos y objetos por ellas. El piso no sabe que hace cada una.
	for mecanica in _mecanicas:
		mecanica.aplicar_a_piso(self)

	_sala_actual = sala_de_tipo(MapaSalas.Tipo.INICIO)
	_sala_actual.activar()

	# La bajada no se puede usar hasta limpiar su sala. En el piso 1, que no
	# tiene enemigos, esta abierta desde el principio.
	var salida := sala_de_tipo(MapaSalas.Tipo.SALIDA)
	_zona_salida.set_deferred("monitoring", salida.esta_despejada())
	salida.despejada.connect(_al_despejar_salida)


## Sigue en que sala esta el jugador.
func _physics_process(_delta: float) -> void:
	if _mapa == null:
		return
	if not is_instance_valid(_jugador):
		_jugador = get_tree().get_first_node_in_group("jugador")
		if _jugador == null:
			return

	var centro: Vector2 = _jugador.centro_colision()
	var sala := sala_en(centro)
	if sala != null and sala != _sala_actual:
		_sala_actual = sala
		sala.visitada = true
		sala_cambiada.emit(sala)

	# La camara cambia de sala a mitad del pasillo, pero las puertas no se
	# cierran hasta que el jugador ha entrado del todo.
	if not _sala_actual.esta_activada() \
			and _sala_actual.contiene_del_todo(centro, MARGEN_ENTRAR):
		_sala_actual.activar()


## Punto de aparicion del jugador: el centro de la sala de inicio.
func punto_entrada() -> Vector2:
	return sala_de_tipo(MapaSalas.Tipo.INICIO).global_position


## Centro del agujero de bajada.
func punto_salida() -> Vector2:
	return sala_de_tipo(MapaSalas.Tipo.SALIDA).global_position


## Todas las salas, en el orden del mapa. Lo usan las mecanicas para repartir
## lo suyo sala por sala.
func salas() -> Array[Sala]:
	return _orden_salas


func sala_actual() -> Sala:
	return _sala_actual


func mapa() -> MapaSalas:
	return _mapa


## La primera sala de ese tipo, o null si el mapa no tiene ninguna (puede
## pasar con la del objeto en un piso de muy pocas salas).
func sala_de_tipo(tipo: MapaSalas.Tipo) -> Sala:
	for sala in _orden_salas:
		if sala.tipo == tipo:
			return sala
	return null


## La sala que contiene ese punto del mundo, o null si cae fuera de todas.
##
## Cada sala es duena de una casilla de la cuadricula de un paso de lado, asi
## que basta con dividir y redondear. La frontera entre dos salas cae en mitad
## del pasillo que las une, y ahi es donde la camara cambia de sala.
func sala_en(punto_global: Vector2) -> Sala:
	var local := to_local(punto_global)
	var paso := _paso()
	var celda := Vector2i(roundi(local.x / paso.x), roundi(local.y / paso.y))
	return _salas.get(celda, null)


## Los obstaculos de este piso. Lo usan las mecanicas: es la unica forma que
## tienen de tocarlos sin que el piso sepa que hace cada mecanica.
func obstaculos() -> Array[Obstaculo]:
	return _obstaculos


## Devuelve sus obstaculos al pool. Principal la llama antes de destruir el piso.
func devolver_obstaculos() -> void:
	if _pool == null:
		return
	for obstaculo in _obstaculos:
		_pool.liberar(obstaculo)
	_obstaculos.clear()


## Medidas del suelo de cada sala. Todas las salas de un piso miden lo mismo:
## asi encajan en la cuadricula sin huecos ni solapes.
func _tamano_sala() -> Vector2:
	if datos == null:
		return Vector2(1200.0, 700.0)
	return Vector2(datos.ancho_area, datos.alto_area)


## Distancia entre los centros de dos salas vecinas: el suelo mas los dos
## muros que las separan. Con este paso las salas quedan pegadas muro con muro.
func _paso() -> Vector2:
	return _tamano_sala() + Vector2.ONE * Sala.GROSOR_MURO * 2.0


# --- Construccion -----------------------------------------------------------

func _construir_salas() -> void:
	for hijo in _contenedor_salas.get_children():
		hijo.queue_free()
	_salas.clear()
	_orden_salas.clear()

	var cantidad := datos.cantidad_salas if datos != null else 5
	var nombre := datos.nombre_capa if datos != null else ""
	# Semilla propia del mapa, distinta de la de las rocas: asi retocar el
	# reparto de rocas no cambia la forma del mapa, ni al reves.
	_mapa = MapaSalas.generar(cantidad, hash(nombre) + numero_piso * 15485863)

	var colores := _colores_suelo()
	for celda in _mapa.celdas:
		var sala := Sala.new()
		sala.name = "Sala_%d_%d" % [celda.x, celda.y]
		sala.position = Vector2(celda) * _paso()
		_contenedor_salas.add_child(sala)
		sala.construir(celda, _mapa.tipo_de(celda), _tamano_sala(),
			_mapa.puertas_de(celda), colores[0], colores[1])
		_salas[celda] = sala
		_orden_salas.append(sala)


## Suelo y borde segun la profundidad: de marron de cueva a rojo incandescente.
func _colores_suelo() -> Array[Color]:
	var profundidad := clampf(float(numero_piso - 1) / 11.0, 0.0, 1.0)
	return [
		Color(0.16, 0.13, 0.12).lerp(Color(0.42, 0.13, 0.06), profundidad),
		Color(0.55, 0.40, 0.28).lerp(Color(1.0, 0.72, 0.25), profundidad),
	]


## La zona de salida se coloca sobre el agujero de la sala de salida. El
## agujero lo pinta la propia sala.
func _colocar_salida() -> void:
	var circulo := CircleShape2D.new()
	circulo.radius = Sala.RADIO_SALIDA
	_forma_salida.shape = circulo
	_zona_salida.position = sala_de_tipo(MapaSalas.Tipo.SALIDA).position


## Solo las salas donde hay pelea llevan rocas. El inicio va limpio para
## empezar cada piso con sitio, y la del objeto tambien: es una recompensa, no
## un obstaculo mas.
func _lleva_rocas(sala: Sala) -> bool:
	return sala.tipo == MapaSalas.Tipo.NORMAL or sala.tipo == MapaSalas.Tipo.SALIDA


## Reparte las rocas, sala por sala.
##
## POR QUE UNA SEMILLA FIJA:
## el encargo pide 12 niveles FIJOS. Con la semilla derivada del numero de piso,
## el reparto es aleatorio pero identico en todas las partidas y en todas las
## maquinas: el jugador puede memorizar el piso y las tres personas del equipo
## ven exactamente el mismo escenario al probarlo.
func _colocar_obstaculos() -> void:
	if _pool == null or datos == null:
		return

	var catalogo: CatalogoObstaculos = datos.catalogo_arte
	if catalogo == null:
		catalogo = CATALOGO_POR_DEFECTO
	var texturas := catalogo.texturas_de(datos.familia_obstaculos)
	if texturas.is_empty():
		push_warning("El catalogo del piso %d no tiene texturas." % numero_piso)
		return

	var generador := RandomNumberGenerator.new()
	generador.seed = hash(datos.nombre_capa) + numero_piso * 7919
	var tinte := tinte_profundidad()

	# Las rocas se encogen con la profundidad porque las salas tambien: si no,
	# en el piso 12 no cabria nada jugable.
	var lado_base := clampf(_tamano_sala().x * 0.075, 34.0, 96.0)

	for sala in _orden_salas:
		if _lleva_rocas(sala):
			_rocas_en_sala(sala, generador, texturas, tinte, lado_base)

	_colocar_plataformas(generador, tinte, catalogo)
	_colocar_decoracion(generador, tinte, catalogo)
	_colocar_borde(generador, tinte, catalogo)


func _rocas_en_sala(sala: Sala, generador: RandomNumberGenerator,
		texturas: Array[Texture2D], tinte: Color, lado_base: float) -> void:
	var posiciones: Array[Vector2] = []
	var lados: Array[float] = []

	for _i in datos.cantidad_obstaculos:
		var lado := lado_base * generador.randf_range(0.75, 1.6)

		# Hasta 24 intentos de encontrar un hueco valido. Si no lo encuentra,
		# se descarta esa roca: mejor una sala con una menos que una puerta
		# tapada.
		for _intento in 24:
			var local := sala.punto_al_azar(generador, lado)
			if sala.cerca_de_puerta(local, DESPEJE_PUERTA):
				continue
			if sala.tipo == MapaSalas.Tipo.SALIDA and local.length() < DESPEJE_SALIDA:
				continue
			var en_piso := sala.position + local
			if _pisa_un_cartel(en_piso, Vector2(lado, lado)):
				continue

			# La separacion depende del tamano de las dos rocas implicadas, no
			# de un valor fijo: si no, las grandes se solapan y las pequenas
			# quedan absurdamente espaciadas.
			var libre := true
			for n in posiciones.size():
				if en_piso.distance_to(posiciones[n]) < (lado + lados[n]) * 0.6 + 40.0:
					libre = false
					break
			if not libre:
				continue

			var obstaculo := _pool.obtener()
			obstaculo.preparar(to_global(en_piso),
				texturas[generador.randi() % texturas.size()],
				lado, tinte, datos.velocidad_obstaculos)
			_obstaculos.append(obstaculo)
			posiciones.append(en_piso)
			lados.append(lado)
			break


## Pone, como mucho, una plataforma baja en cada sala de pelea, con vegetacion
## encima.
##
## POR QUE AGRUPAR LAS PLANTAS EN PLATAFORMAS:
## repartidas sueltas parecian puestas al azar, porque lo estaban. Agrupadas
## sobre una repisa cuentan algo: ahi hay tierra y por eso crece algo.
##
## Las plataformas son solidas, igual que las rocas: pasan por el pool de
## obstaculos. La vegetacion de encima es decoracion y no choca, para que el
## borde de la losa sea exactamente lo que estorba y el jugador pueda fiarse de
## lo que ve.
##
## Una como mucho y solo en la mitad de las salas: son anchas, y dos por sala
## dejaban las salas pequenas sin sitio para pelear.
func _colocar_plataformas(generador: RandomNumberGenerator, tinte: Color,
		catalogo: CatalogoObstaculos) -> void:
	var losas := catalogo.texturas_de("plataforma")
	if losas.is_empty():
		return
	var plantas := catalogo.texturas_de("vegetacion")
	var tamano := _tamano_sala()

	# Las plataformas se oscurecen hasta la luminosidad de las rocas.
	#
	# El 0.6 no es a ojo: la textura de las repisas es de por si mucho mas clara
	# que la de las rocas, asi que darles el mismo tinte no bastaba. Medido sobre
	# una captura del piso 1, el suelo esta en 34 de luminosidad, las rocas entre
	# 18 y 53, y las losas se quedaban en 71. Con este factor caen a la mitad de
	# ese rango y no destacan como si fueran otra cosa.
	var tinte_losa := Color(tinte.r * 0.6, tinte.g * 0.6, tinte.b * 0.6, 1.0)

	for sala in _orden_salas:
		if not _lleva_rocas(sala) or generador.randf() < 0.5:
			continue
		var ancho_losa := clampf(tamano.x * 0.3, 210.0, 470.0) * generador.randf_range(0.8, 1.35)

		for _intento in 16:
			var local := sala.punto_al_azar(generador, ancho_losa * 0.6)
			if sala.cerca_de_puerta(local, DESPEJE_PUERTA + ancho_losa * 0.5):
				continue
			if sala.tipo == MapaSalas.Tipo.SALIDA \
					and local.length() < DESPEJE_SALIDA + ancho_losa * 0.5:
				continue
			var en_piso := sala.position + local
			# El alto de la losa no se sabe hasta elegir textura, asi que se
			# reserva un cuadrado de su ancho: es conservador y sale gratis.
			if _pisa_un_cartel(en_piso, Vector2(ancho_losa, ancho_losa)):
				continue

			var textura: Texture2D = losas[generador.randi() % losas.size()]
			var losa := _pool.obtener()
			losa.preparar(to_global(en_piso), textura, ancho_losa, tinte_losa,
				datos.velocidad_obstaculos)
			_obstaculos.append(losa)
			_plantar_encima(en_piso, losa.tamano(), generador, tinte, plantas)
			break


## Siembra unas cuantas plantas sobre una plataforma ya colocada.
##
## Recibe la posicion y el tamano en vez del nodo de la losa porque la losa vive
## en el pool de obstaculos (coordenadas globales) y las plantas cuelgan del
## nodo de decoracion del piso (coordenadas locales).
func _plantar_encima(centro_losa: Vector2, tamano_losa: Vector2,
		generador: RandomNumberGenerator, tinte: Color,
		plantas: Array[Texture2D]) -> void:
	if plantas.is_empty():
		return

	var ancho_losa := tamano_losa.x
	var alto_losa := tamano_losa.y
	for _i in generador.randi_range(2, 5):
		var textura: Texture2D = plantas[generador.randi() % plantas.size()]
		var planta := Sprite2D.new()
		planta.texture = textura
		var lado := generador.randf_range(34.0, 76.0)
		planta.scale = Vector2.ONE * (lado / maxf(textura.get_size().x, textura.get_size().y))
		planta.flip_h = generador.randf() < 0.5
		planta.modulate = Color(tinte.r, tinte.g, tinte.b, 1.0)
		# Repartidas a lo ancho de la losa y pegadas a su mitad superior, que es
		# donde se apoyarian si la plataforma tuviera altura de verdad.
		planta.position = centro_losa + Vector2(
			generador.randf_range(-ancho_losa * 0.38, ancho_losa * 0.38),
			generador.randf_range(-alto_losa * 0.35, alto_losa * 0.1))
		_decoracion.add_child(planta)


## Reparte piedras pequenas por el suelo de cada sala. Son decoracion: ni
## chocan ni hacen dano.
##
## POR QUE NO SON SOLIDAS COMO LAS ROCAS GRANDES:
## son muchas y miden 16-34 px. Con colision, moverse seria un engancharse
## continuo en chinas, y este juego va de deslizarse con inercia. Las rocas
## grandes son terreno; estas son el suelo.
func _colocar_decoracion(generador: RandomNumberGenerator, tinte: Color,
		catalogo: CatalogoObstaculos) -> void:
	# Solo piedras: la vegetacion va sobre las plataformas, agrupada.
	var piedras := catalogo.texturas_de("piedra")
	if piedras.is_empty():
		return

	var tamano := _tamano_sala()
	# La cantidad sale de la superficie, no de un numero fijo: las salas del
	# piso 1 tienen el doble de area que las del 12.
	var por_sala := int(tamano.x * tamano.y / 80000.0) + datos.cantidad_obstaculos
	for sala in _orden_salas:
		for _i in por_sala:
			var lado := generador.randf_range(16.0, 34.0)
			var sitio := sala.position + sala.punto_al_azar(generador, 24.0)
			if _pisa_un_cartel(sitio, Vector2(lado, lado)):
				continue

			var textura: Texture2D = piedras[generador.randi() % piedras.size()]
			var adorno := Sprite2D.new()
			adorno.texture = textura
			adorno.scale = Vector2.ONE * (lado / maxf(textura.get_size().x, textura.get_size().y))
			# Volteo horizontal en vez de rotacion: el arte tiene la luz desde
			# arriba y rotarlo delataria que son recortes de un atlas.
			adorno.flip_h = generador.randf() < 0.5
			adorno.modulate = Color(tinte.r, tinte.g, tinte.b, 0.8)
			adorno.position = sitio
			_decoracion.add_child(adorno)


## Rodea cada sala con rocas, para que el limite deje de ser una linea dibujada
## y parezca la pared de la cueva.
##
## Van en la franja de muro, por fuera del suelo, y no chocan con nada: la
## colision la ponen los muros de la sala. Dejan libres los huecos de puerta.
##
## POR QUE TAN PEGADAS Y TAN PEQUENAS:
## entre dos salas vecinas solo hay 128 px de muro (dos de 64). Una roca mas
## grande o mas alejada asomaria en el suelo de la sala de al lado, y ahi
## pareceria un obstaculo que luego no choca. El jugador tiene que poder
## fiarse de lo que ve.
func _colocar_borde(generador: RandomNumberGenerator, tinte: Color,
		catalogo: CatalogoObstaculos) -> void:
	var piezas := catalogo.rocas_todas()
	if piezas.is_empty():
		return

	var tamano := _tamano_sala()
	var tope := Sala.GROSOR_MURO * 1.7
	var lado_medio := clampf(tamano.x * 0.07, 50.0, 96.0)

	for sala in _orden_salas:
		for direccion in MapaSalas.DIRECCIONES:
			var horizontal := direccion == Vector2i.UP or direccion == Vector2i.DOWN
			var largo := tamano.x if horizontal else tamano.y
			var recorrido := -largo * 0.5 - Sala.GROSOR_MURO * 0.5
			while recorrido < largo * 0.5 + Sala.GROSOR_MURO * 0.5:
				var lado := minf(lado_medio * generador.randf_range(0.7, 1.4), tope)
				recorrido += lado * generador.randf_range(0.45, 0.8)

				if direccion in sala.puertas \
						and absf(recorrido) < Sala.ANCHO_PUERTA * 0.5 + lado * 0.5:
					continue

				var fuera := lado * generador.randf_range(0.45, 0.7)
				var local: Vector2
				if horizontal:
					local = Vector2(recorrido, direccion.y * (tamano.y * 0.5 + fuera))
				else:
					local = Vector2(direccion.x * (tamano.x * 0.5 + fuera), recorrido)

				var textura: Texture2D = piezas[generador.randi() % piezas.size()]
				var roca := Sprite2D.new()
				roca.texture = textura
				roca.scale = Vector2.ONE * (lado / maxf(textura.get_size().x, textura.get_size().y))
				roca.flip_h = generador.randf() < 0.5
				roca.modulate = Color(tinte.r, tinte.g, tinte.b, 1.0)
				roca.position = sala.position + local
				_decoracion.add_child(roca)


## Pinta los carteles de controles si este piso los pide desde su .tres: los
## de controles en la sala de inicio y el de bajar junto al agujero.
func _colocar_tutorial() -> void:
	_zonas_prohibidas.clear()
	if datos == null or not datos.mostrar_tutorial:
		return
	var tutorial: Tutorial = ESCENA_TUTORIAL.instantiate()
	# add_child antes de colocar(): los @onready del tutorial tienen que estar
	# resueltos, y los Label necesitan estar en el arbol para saber su tamano.
	add_child(tutorial)
	tutorial.colocar(sala_de_tipo(MapaSalas.Tipo.INICIO).position, _tamano_sala(),
		sala_de_tipo(MapaSalas.Tipo.SALIDA).position)

	# Cada cartel reserva su rectangulo, con holgura por arriba y por abajo para
	# que nada quede pegado al texto y lo haga ilegible igualmente.
	for etiqueta in tutorial.get_children():
		if etiqueta is Control:
			_zonas_prohibidas.append(Rect2(
				etiqueta.position - Vector2(0.0, HOLGURA_CARTEL),
				etiqueta.size + Vector2(0.0, HOLGURA_CARTEL * 2.0)))


## True si una pieza de ese tamano en ese sitio taparia un cartel del tutorial.
func _pisa_un_cartel(centro: Vector2, tamano: Vector2) -> bool:
	if _zonas_prohibidas.is_empty():
		return false
	var caja := Rect2(centro - tamano * 0.5, tamano)
	for zona in _zonas_prohibidas:
		if caja.intersects(zona):
			return true
	return false


## Al limpiar la sala de salida se destapa el agujero. set_deferred porque el
## ultimo enemigo muere dentro del paso de fisica (lo mata una bola).
##
## Encender la zona con el jugador ya encima avisa igual de que ha entrado: si
## estaba pisando el agujero tapado al matar al ultimo, baja sin tener que
## salir y volver a entrar.
func _al_despejar_salida(_sala: Sala) -> void:
	_zona_salida.set_deferred("monitoring", true)


func _al_entrar_en_salida(cuerpo: Node2D) -> void:
	# La salida solo cuenta una vez: sin esta guarda, dos frames dentro del area
	# emitirian dos avances de piso seguidos.
	if _salida_usada:
		return
	if not (cuerpo is Jugador):
		return

	# Y ademas comprobamos que el jugador este DE VERDAD encima del circulo.
	#
	# POR QUE HACE FALTA:
	# Godot avisa del solapamiento con la posicion que el cuerpo tenia al empezar
	# el paso de fisica, no con la que tiene ya. Al cambiar de piso la salida del
	# piso nuevo puede nacer donde estaba el jugador en el anterior, el jugador
	# todavia figura ahi aunque ya lo hemos movido, y el piso nuevo se daria por
	# superado al nacer. Paso con el pasillo de antes: del piso 1 al 3.
	if cuerpo.centro_colision().distance_to(_zona_salida.global_position) > Sala.RADIO_SALIDA * 2.0:
		return

	_salida_usada = true
	salida_alcanzada.emit()


## El arte de las rocas es marron de cueva y a partir del piso 8 el suelo tira a
## rojo incandescente, asi que sin tinte la roca canta como pieza de otro juego.
##
## OJO AL AJUSTARLO: el tinte tambien decide si el obstaculo se ve, y eso pesa
## mas que el estilo. Medido sobre una captura del piso 9, con estos valores la
## roca queda a 0,33 veces la luminancia del suelo (contraste ~3:1, se lee de un
## vistazo). Aclararlas para lucir mas el dibujo de la roca lo baja a 0,48 (~2:1)
## y el obstaculo empieza a fundirse con el fondo. Probado y descartado.
func tinte_profundidad() -> Color:
	var profundidad := clampf(float(numero_piso - 1) / 11.0, 0.0, 1.0)
	return Color(0.92, 0.88, 0.84).lerp(Color(1.0, 0.52, 0.34), profundidad)
