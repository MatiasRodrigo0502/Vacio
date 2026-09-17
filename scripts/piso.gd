## Piso generico: una sola escena que se construye leyendo un DatosPiso.
##
## POR QUE UNA UNICA ESCENA PARA LOS 12 PISOS:
## si cada piso fuera su propia escena tendriamos 12 archivos .tscn casi
## identicos que habria que tocar a mano cada vez que cambie algo estructural
## (y 12 focos de conflicto de merge). Aqui la geometria se genera en tiempo de
## ejecucion a partir del .tres, asi que el contenido de un piso se ajusta
## editando datos, nunca escenas.
class_name Piso
extends Node2D

## Se emite cuando el jugador alcanza la zona de salida.
signal salida_alcanzada

## Grosor de los muros de colision. Generoso a proposito: con muros finos y
## velocidades altas el jugador puede atravesarlos (tunneling).
const GROSOR_MURO: float = 64.0
## Distancia desde el borde superior a la que aparece el jugador.
const MARGEN_ENTRADA: float = 110.0
## Distancia desde el borde inferior a la que se coloca la salida.
const MARGEN_SALIDA: float = 110.0
## Radio de la zona de salida.
const RADIO_SALIDA: float = 46.0
## Espacio libre alrededor de la entrada y de la salida donde no se colocan
## obstaculos: sin esto el jugador podria aparecer dentro de uno.
const DESPEJE_ENTRADA: float = 150.0
const DESPEJE_SALIDA: float = 130.0

## Catalogo de rocas por defecto. Cada piso puede sobreescribirlo desde su .tres.
const CATALOGO_POR_DEFECTO := preload("res://assets/obstaculos/catalogo_cueva.tres")

var datos: DatosPiso = null
var numero_piso: int = 1

var _pool: PoolObstaculos = null
var _obstaculos: Array[Obstaculo] = []
var _mecanicas: Array[Mecanica] = []
var _salida_usada: bool = false

@onready var _muros: StaticBody2D = $Muros
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

	_construir_muros()
	_colocar_salida()
	_colocar_obstaculos()

	# Las mecanicas se aplican al final, cuando el piso ya existe: asi pueden
	# anadir o modificar lo que haga falta. El piso no sabe que hace cada una.
	for mecanica in _mecanicas:
		mecanica.aplicar_a_piso(self)

	queue_redraw()


## Punto de aparicion del jugador (arriba del piso, centrado).
func punto_entrada() -> Vector2:
	return to_global(Vector2(0.0, -_alto() * 0.5 + MARGEN_ENTRADA))


## Punto central de la zona de salida.
func punto_salida() -> Vector2:
	return to_global(Vector2(0.0, _alto() * 0.5 - MARGEN_SALIDA))


## Devuelve sus obstaculos al pool. Principal la llama antes de destruir el piso.
func devolver_obstaculos() -> void:
	if _pool == null:
		return
	for obstaculo in _obstaculos:
		_pool.liberar(obstaculo)
	_obstaculos.clear()


func _ancho() -> float:
	return datos.ancho_area if datos != null else 1200.0


func _alto() -> float:
	return datos.alto_area if datos != null else 1700.0


# --- Construccion -----------------------------------------------------------

## Crea las cuatro paredes por codigo a partir del ancho/alto del .tres.
## Se generan aqui y no en la escena porque sus medidas cambian en cada piso.
func _construir_muros() -> void:
	for hijo in _muros.get_children():
		hijo.queue_free()

	var mitad_ancho := _ancho() * 0.5
	var mitad_alto := _alto() * 0.5
	var medio_grosor := GROSOR_MURO * 0.5

	# Los muros se solapan en las esquinas para que no queden huecos.
	_anadir_muro(Vector2(-mitad_ancho - medio_grosor, 0.0),
		Vector2(GROSOR_MURO, _alto() + GROSOR_MURO * 2.0))
	_anadir_muro(Vector2(mitad_ancho + medio_grosor, 0.0),
		Vector2(GROSOR_MURO, _alto() + GROSOR_MURO * 2.0))
	_anadir_muro(Vector2(0.0, -mitad_alto - medio_grosor),
		Vector2(_ancho() + GROSOR_MURO * 2.0, GROSOR_MURO))
	_anadir_muro(Vector2(0.0, mitad_alto + medio_grosor),
		Vector2(_ancho() + GROSOR_MURO * 2.0, GROSOR_MURO))


func _anadir_muro(posicion: Vector2, tamano: Vector2) -> void:
	var forma := CollisionShape2D.new()
	var rectangulo := RectangleShape2D.new()
	rectangulo.size = tamano
	forma.shape = rectangulo
	forma.position = posicion
	_muros.add_child(forma)


func _colocar_salida() -> void:
	var circulo := CircleShape2D.new()
	circulo.radius = RADIO_SALIDA
	_forma_salida.shape = circulo
	_zona_salida.position = Vector2(0.0, _alto() * 0.5 - MARGEN_SALIDA)


## Reparte los obstaculos del piso.
##
## POR QUE UNA SEMILLA FIJA:
## el encargo pide 12 niveles FIJOS. Con la semilla derivada del numero de piso,
## el reparto es aleatorio pero identico en todas las partidas y en todas las
## maquinas: el jugador puede memorizar el piso y las tres personas del equipo
## ven exactamente el mismo escenario al probarlo.
func _colocar_obstaculos() -> void:
	if _pool == null or datos == null:
		return

	var catalogo: CatalogoObstaculos = datos.catalogo_obstaculos
	if catalogo == null:
		catalogo = CATALOGO_POR_DEFECTO
	var texturas := catalogo.texturas_de(datos.familia_obstaculos)
	if texturas.is_empty():
		push_warning("El catalogo del piso %d no tiene texturas." % numero_piso)
		return

	var generador := RandomNumberGenerator.new()
	generador.seed = hash(datos.nombre_capa) + numero_piso * 7919
	var tinte := tinte_profundidad()

	var entrada := Vector2(0.0, -_alto() * 0.5 + MARGEN_ENTRADA)
	var salida := Vector2(0.0, _alto() * 0.5 - MARGEN_SALIDA)

	# Las rocas se encogen con la profundidad porque el area tambien se
	# estrecha: si no, en el piso 12 no cabria nada jugable.
	var lado_base := clampf(_ancho() * 0.075, 34.0, 96.0)
	var posiciones: Array[Vector2] = []
	var lados: Array[float] = []

	for _i in datos.cantidad_obstaculos:
		var lado := lado_base * generador.randf_range(0.75, 1.6)

		# Hasta 24 intentos de encontrar un hueco valido. Si no lo encuentra,
		# se descarta esa roca: mejor un piso con una menos que un piso
		# imposible de pasar.
		for _intento in 24:
			var candidata := Vector2(
				generador.randf_range(-_ancho() * 0.5 + lado, _ancho() * 0.5 - lado),
				generador.randf_range(entrada.y + DESPEJE_ENTRADA, salida.y - DESPEJE_SALIDA))

			if candidata.distance_to(entrada) < DESPEJE_ENTRADA:
				continue
			if candidata.distance_to(salida) < DESPEJE_SALIDA:
				continue

			# La separacion depende del tamano de las dos rocas implicadas, no
			# de un valor fijo: si no, las grandes se solapan y las pequenas
			# quedan absurdamente espaciadas.
			var libre := true
			for n in posiciones.size():
				if candidata.distance_to(posiciones[n]) < (lado + lados[n]) * 0.6 + 40.0:
					libre = false
					break
			if not libre:
				continue

			var obstaculo := _pool.obtener()
			obstaculo.preparar(to_global(candidata),
				texturas[generador.randi() % texturas.size()],
				lado, tinte, datos.velocidad_obstaculos)
			_obstaculos.append(obstaculo)
			posiciones.append(candidata)
			lados.append(lado)
			break

	_colocar_decoracion(generador, tinte, catalogo)


## Reparte piedras pequenas por el suelo. Son solo decoracion: sin colision y
## sin logica.
##
## POR QUE NO PASAN POR EL POOL: no tienen fisica, son pocas y mueren con el
## piso. Meterlas en el pool anadiria contabilidad a cambio de nada. El pool
## existe por los Area2D, que son los caros de crear y destruir.
##
## Se generan con el MISMO generador que las rocas y despues que ellas, para no
## alterar la secuencia de numeros: si no, anadir decoracion moveria de sitio
## todos los obstaculos y los 12 pisos dejarian de ser los de siempre.
func _colocar_decoracion(generador: RandomNumberGenerator, tinte: Color,
		catalogo: CatalogoObstaculos) -> void:
	for hijo in _decoracion.get_children():
		hijo.queue_free()

	var piedras := catalogo.texturas_de("piedra")
	if piedras.is_empty():
		return

	var cuantas := datos.cantidad_obstaculos * 2 + 6
	for _i in cuantas:
		var textura: Texture2D = piedras[generador.randi() % piedras.size()]
		var piedra := Sprite2D.new()
		piedra.texture = textura
		var lado := generador.randf_range(10.0, 26.0)
		var escala := lado / maxf(textura.get_size().x, textura.get_size().y)
		piedra.scale = Vector2(escala, escala)
		# Volteo horizontal en vez de rotacion: el arte tiene la luz desde
		# arriba y rotarlo delataria que son recortes de un atlas.
		piedra.flip_h = generador.randf() < 0.5
		piedra.modulate = Color(tinte.r, tinte.g, tinte.b, 0.8)
		piedra.position = Vector2(
			generador.randf_range(-_ancho() * 0.5 + 24.0, _ancho() * 0.5 - 24.0),
			generador.randf_range(-_alto() * 0.5 + 24.0, _alto() * 0.5 - 24.0))
		_decoracion.add_child(piedra)


func _al_entrar_en_salida(cuerpo: Node2D) -> void:
	# La salida solo cuenta una vez: sin esta guarda, dos frames dentro del area
	# emitirian dos avances de piso seguidos.
	if _salida_usada:
		return
	if not (cuerpo is Jugador):
		return
	_salida_usada = true
	salida_alcanzada.emit()


## Tinte que se aplica a rocas y piedras segun la profundidad.
##
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


# --- Pintado ----------------------------------------------------------------

func _draw() -> void:
	var profundidad := clampf(float(numero_piso - 1) / 11.0, 0.0, 1.0)
	var color_suelo := Color(0.16, 0.13, 0.12).lerp(Color(0.42, 0.13, 0.06), profundidad)
	var color_borde := Color(0.55, 0.40, 0.28).lerp(Color(1.0, 0.72, 0.25), profundidad)

	var rectangulo := Rect2(Vector2(-_ancho() * 0.5, -_alto() * 0.5), Vector2(_ancho(), _alto()))
	draw_rect(rectangulo, color_suelo)
	draw_rect(rectangulo, color_borde, false, 6.0)

	# Lineas horizontales de referencia: sin ellas cuesta percibir el avance
	# vertical sobre un fondo plano.
	var paso := 220.0
	var y := -_alto() * 0.5 + paso
	while y < _alto() * 0.5:
		draw_line(Vector2(-_ancho() * 0.5, y), Vector2(_ancho() * 0.5, y),
			Color(color_borde.r, color_borde.g, color_borde.b, 0.10), 2.0)
		y += paso

	# Marca visual de la salida.
	var centro_salida := Vector2(0.0, _alto() * 0.5 - MARGEN_SALIDA)
	draw_circle(centro_salida, RADIO_SALIDA, Color(0.05, 0.03, 0.03, 0.9))
	draw_arc(centro_salida, RADIO_SALIDA, 0.0, TAU, 32, color_borde, 4.0, true)
	draw_arc(centro_salida, RADIO_SALIDA * 0.55, 0.0, TAU, 24,
		Color(color_borde.r, color_borde.g, color_borde.b, 0.5), 3.0, true)
