## El cofre de la sala secreta. Al pasar por encima se abre y sale la ruleta
## (Ruleta) con las ventajas: la que toque es para el jugador, para toda la
## partida, como un objeto recogido.
##
## Pedido por Matias el 2026-10-29: «dentro un cofre, y que al pasar por
## encima salga una ruleta con las ventajas y que te toque una al azar». Y el
## 2026-11-05, que tanto el cofre como su animacion eran «muy basicos».
##
## Lo que toca sale de la suerte, no de la semilla del piso, como lo que
## sueltan los enemigos: el sitio del cofre es fijo, el premio no.
##
## EL DIBUJO es una tira (assets/cofre/cofre.png, de herramientas/generar_cofre.py)
## con la tapa en cada momento de abrirse, de un cofre en 3D proyectado: al
## abrirse, la tapa gira de verdad sobre la bisagra. Lo que se mueve encima lo
## pinta este script:
##
## - cerrado: un brillo que late detras, destellos alrededor y, de vez en cuando,
##   un saltito, como si dentro hubiera algo vivo;
## - al pisarlo: tiembla cada vez mas, con luz saliendo por la rendija de la
##   tapa; salta el cierre, la tapa se abre (y se pasa un poco, como una tapa
##   pesada), sale un haz de luz hacia arriba con rayos girando detras, saltan
##   monedas y chispas y la camara da un golpe; y entonces, la ruleta;
## - abierto: el tesoro sigue brillando y sube alguna chispa.
class_name Cofre
extends Node2D

enum Estado { CERRADO, TEMBLANDO, ABRIENDO, ABIERTO }

## Lo cerca que tienen que estar los pies del jugador para abrirlo.
const RADIO_TOCAR: float = 52.0
const COLOR_ORO := Color(1.0, 0.8, 0.3)
const TEXTURA := preload("res://assets/cofre/cofre.png")
## Lo que mide cada casilla de la tira y donde quedan en ella los pies del
## cofre (lo que da generar_cofre.py al acabar).
const LADO: float = 192.0
const PIES := Vector2(96.0, 144.0)
const CUADROS: int = 9
## La tira se pinta a este tamano: el cofre sale de unos 90 px de ancho, algo
## mas que el de antes (73), para que se vea que es lo importante de la sala.
const ESCALA: float = 0.76
## Sitios de la tira, desde los pies y en px de la tira: el centro de la
## abertura (de donde sale la luz), la rendija de la tapa (de la esquina de
## delante a la izquierda, a la de delante a la derecha y a la de atras a la
## derecha) y la cerradura.
const ABERTURA := Vector2(0.0, -32.0)
const RENDIJA: Array[Vector2] = [Vector2(-58.3, -30.7), Vector2(37.6, -4.4), Vector2(58.3, -33.1)]
const CERRADURA := Vector2(-10.4, -6.9)
## Cuanto dura cada parte de abrirse y cuando sale la ruleta.
const TEMBLAR: float = 0.55
const ABRIR: float = 0.45
const RULETA_TRAS: float = 0.8
## Cada cuanto da un saltito cerrado, y lo que dura.
const SALTITO_CADA: float = 3.2
const SALTITO: float = 0.4
const GRAVEDAD: float = 900.0

var abierto: bool = false

var _numero_piso: int = 1
var _tiempo: float = 0.0
var _estado: int = Estado.CERRADO
## Tiempo desde que se empezo a abrir (desde que tiembla).
var _desde: float = 0.0
var _jugador: Jugador = null
var _con_ruleta: bool = true
var _ruleta_puesta: bool = false
## Lo fuerte que esta el haz de luz, de 0 a 1: sube al abrirse y se apaga luego.
var _haz: float = 0.0
var _particulas: Array[Dictionary] = []


func _init(numero_piso: int = 1) -> void:
	_numero_piso = numero_piso
	name = "Cofre"
	# Como los objetos: por encima del suelo y de lo que hay en el.
	z_index = 4


func _ready() -> void:
	# De pie con la vista girada (Vista): se abre por distancia, no choca.
	add_to_group("de_pie")
	rotation = Vista.giro
	# Que no parpadeen todos los cofres a la vez si hubiera varios a la vista.
	_tiempo = randf() * SALTITO_CADA


func _process(delta: float) -> void:
	_tiempo += delta
	match _estado:
		Estado.TEMBLANDO:
			_desde += delta
			if randf() < 0.5:
				_chispa(_punto(RENDIJA.pick_random()), Vector2(randf_range(-30.0, 30.0), randf_range(-90.0, -40.0)), COLOR_ORO)
			if _desde >= TEMBLAR:
				_saltar_cierre()
		Estado.ABRIENDO:
			_desde += delta
			_haz = minf(1.0, _haz + delta * 3.0)
			if _desde >= TEMBLAR + ABRIR:
				_estado = Estado.ABIERTO
		Estado.ABIERTO:
			_desde += delta
			# El haz se va apagando; la ruleta (que para el juego) lo deja como
			# estaba mientras se elige.
			if _ruleta_puesta or not _con_ruleta:
				_haz = maxf(0.0, _haz - delta * 0.6)
			if randf() < delta * 3.0:
				_chispa(_punto(ABERTURA + Vector2(randf_range(-40.0, 40.0), randf_range(-4.0, 6.0))),
					Vector2(randf_range(-10.0, 10.0), randf_range(-60.0, -30.0)), COLOR_ORO.lightened(0.3), 1.4)
		Estado.CERRADO:
			if randf() < delta * 1.2:
				var sitio := Vector2(randf_range(-60.0, 60.0), randf_range(-80.0, -10.0))
				_particulas.append({"tipo": "destello", "p": _punto(sitio), "v": Vector2.ZERO, "vida": 0.0, "max": 0.9,
					"r": randf_range(4.0, 7.0)})
	# La ruleta sale cuando ya se ha visto abrirse, con la tapa quieta: se mira
	# fuera del match porque para entonces la tapa ya ha acabado (ABIERTO).
	if _con_ruleta and not _ruleta_puesta and _estado >= Estado.ABRIENDO and _desde >= TEMBLAR + RULETA_TRAS:
		_poner_ruleta()
	_mover_particulas(delta)
	queue_redraw()


## Se mira en cada paso si el jugador de este ordenador lo esta pisando. Solo
## ese: en cooperativo, el que lo abre ve la ruleta, y a los demas les llega la
## ventaja por la red (Cooperativo.cofre_abierto).
func _physics_process(_delta: float) -> void:
	if abierto or not is_visible_in_tree():
		return
	var jugador := get_tree().get_first_node_in_group("jugador") as Jugador
	if jugador == null or not jugador.sigue_vivo():
		return
	if jugador.global_position.distance_to(global_position) < RADIO_TOCAR:
		_empezar(jugador, true)


## Lo abre sin ruleta. Lo usa el cooperativo cuando lo ha abierto otro jugador:
## aqui se ve abrirse igual, pero la ventaja ya llega por la red.
func marcar_abierto() -> void:
	if abierto:
		return
	_empezar(null, false)


## Las ventajas que pueden tocar: las que duran (el vendaje, que solo cura,
## no es una ventaja) y que ya pueden salir a esta profundidad.
func ventajas() -> Array[ObjetoMejora]:
	var lista: Array[ObjetoMejora] = []
	for mejora in ObjetoMejora.cargar_todos():
		if mejora.es_permanente() and mejora.piso_minimo <= _numero_piso:
			lista.append(mejora)
	return lista


func _empezar(jugador: Jugador, con_ruleta: bool) -> void:
	# Abierto desde ya (el minimapa deja de marcarlo y nadie lo vuelve a abrir),
	# aunque la tapa tarde un poco en levantarse.
	abierto = true
	_jugador = jugador
	_con_ruleta = con_ruleta
	_estado = Estado.TEMBLANDO
	_desde = 0.0
	Sonido.tocar(&"cofre_traqueteo")


## Salta el cierre: la tapa empieza a abrirse y sale todo de golpe.
func _saltar_cierre() -> void:
	_estado = Estado.ABRIENDO
	Sonido.tocar(&"cofre_abre")
	var camara := get_viewport().get_camera_2d()
	if camara != null and camara.has_method("sacudir"):
		camara.sacudir(5.0)
	var boca := _punto(ABERTURA)
	for i in 26:
		# Monedas que saltan y caen al suelo, alrededor del cofre.
		var hacia := Vector2(randf_range(-170.0, 170.0), randf_range(-430.0, -260.0))
		_particulas.append({"tipo": "moneda", "p": boca + Vector2(randf_range(-25.0, 25.0), 0.0), "v": hacia, "vida": 0.0,
			"max": randf_range(1.6, 2.4), "suelo": randf_range(-6.0, 26.0), "giro": randf() * TAU, "botes": 0})
	for i in 30:
		_chispa(boca, Vector2.from_angle(randf_range(-PI, 0.0)) * randf_range(120.0, 360.0),
			COLOR_ORO.lightened(randf() * 0.6), randf_range(0.5, 1.0))
	_particulas.append({"tipo": "onda", "p": Vector2.ZERO, "v": Vector2.ZERO, "vida": 0.0, "max": 0.6})


func _poner_ruleta() -> void:
	_ruleta_puesta = true
	var lista := ventajas()
	if lista.is_empty() or not is_instance_valid(_jugador):
		return
	var ganada: ObjetoMejora = lista[randi() % lista.size()]
	var ruleta := Ruleta.new(lista, ganada)
	ruleta.terminada.connect(_entregar.bind(_jugador))
	add_child(ruleta)


func _entregar(mejora: ObjetoMejora, jugador: Jugador) -> void:
	if not is_instance_valid(jugador):
		return
	# Por donde pasa un objeto recogido: el HUD lo anuncia y lo ensena, y el
	# registro de la partida lo apunta (Jugador.mejora_recogida).
	jugador.aplicar_mejora(mejora)
	Sonido.tocar(&"objeto")
	# En cooperativo, para todos, como los objetos. Jugando solo no hay nadie
	# en el grupo.
	get_tree().call_group("cooperativo", "cofre_abierto", mejora)


# --- Particulas -------------------------------------------------------------------

## Un sitio de la tira (desde los pies, en px de la tira) en el nodo.
func _punto(en_tira: Vector2) -> Vector2:
	return en_tira * ESCALA


func _chispa(desde: Vector2, velocidad: Vector2, color: Color, vida: float = 0.6) -> void:
	_particulas.append({"tipo": "chispa", "p": desde, "v": velocidad, "vida": 0.0, "max": vida, "color": color})


func _mover_particulas(delta: float) -> void:
	for i in range(_particulas.size() - 1, -1, -1):
		var p := _particulas[i]
		p.vida += delta
		match p.tipo:
			"moneda":
				p.giro += delta * 12.0
				# Cae, bota una vez en el suelo (y, su profundidad) y se queda.
				if p.botes < 2:
					p.v.y += GRAVEDAD * delta
					p.p += p.v * delta
					if p.v.y > 0.0 and p.p.y >= p.suelo:
						p.p.y = p.suelo
						p.v = Vector2(p.v.x * 0.5, -p.v.y * 0.3)
						p.botes += 1
						if p.botes >= 2:
							p.v = Vector2.ZERO
			"chispa":
				p.v *= 1.0 - minf(1.0, 2.5 * delta)
				p.v.y -= 30.0 * delta
				p.p += p.v * delta
		if p.vida >= p.max:
			_particulas.remove_at(i)


# --- Dibujo -----------------------------------------------------------------------

func _draw() -> void:
	var boca := _punto(ABERTURA)
	# Detras: el resplandor y, al abrirse, los rayos.
	var latido := 0.5 + 0.5 * sin(_tiempo * 3.0)
	var fuerza := 0.35 + 0.25 * latido
	if _estado == Estado.TEMBLANDO:
		fuerza = 0.6 + 0.8 * (_desde / TEMBLAR)
	elif _estado != Estado.CERRADO:
		fuerza = 0.5 + 1.0 * _haz
	for k in 7:
		draw_circle(boca + Vector2(0.0, 6.0), (30.0 + k * 11.0) * (0.9 + 0.1 * latido), Color(1.0, 0.78, 0.3, 0.035 * fuerza))
	if _haz > 0.0:
		_pintar_rayos(boca, _haz)
	# El cofre, con su temblor o su saltito.
	var giro := 0.0
	var desplazado := Vector2.ZERO
	var aplastado := Vector2.ONE
	match _estado:
		Estado.CERRADO:
			var u := fposmod(_tiempo, SALTITO_CADA) / SALTITO
			if u < 1.0:
				giro = sin(u * TAU * 2.0) * 0.05 * (1.0 - u)
				desplazado.y = -4.0 * sin(u * PI)
		Estado.TEMBLANDO:
			var u := _desde / TEMBLAR
			giro = sin(_desde * 55.0) * 0.06 * u
			desplazado = Vector2(sin(_desde * 71.0), cos(_desde * 63.0)) * 2.5 * u
			aplastado = Vector2(1.0 + 0.04 * u, 1.0 - 0.05 * u)
		Estado.ABRIENDO:
			# Al saltar el cierre, un estiron hacia arriba que vuelve.
			var u := clampf((_desde - TEMBLAR) / 0.25, 0.0, 1.0)
			aplastado = Vector2(1.0 - 0.05 * sin(u * PI), 1.0 + 0.08 * sin(u * PI))
	draw_set_transform(desplazado, giro, aplastado)
	var cuadro := _cuadro()
	draw_texture_rect_region(TEXTURA, Rect2(-PIES * ESCALA, Vector2(LADO, LADO) * ESCALA), Rect2(cuadro * LADO, 0.0, LADO, LADO))
	if _estado == Estado.TEMBLANDO:
		_pintar_rendija(_desde / TEMBLAR)
	elif _estado == Estado.CERRADO:
		# La cerradura brilla un poco con el latido.
		draw_circle(_punto(CERRADURA), 5.0, Color(1.0, 0.9, 0.5, 0.25 * latido))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Delante: el haz de luz que sale de la abertura y las particulas.
	if _haz > 0.0:
		_pintar_haz(boca, _haz)
	_pintar_particulas()


## Que casilla de la tira toca: la tapa sube hasta pasarse (la 7) y vuelve a
## donde se queda (la 8).
func _cuadro() -> int:
	match _estado:
		Estado.CERRADO, Estado.TEMBLANDO:
			return 0
		Estado.ABRIENDO:
			var u := clampf((_desde - TEMBLAR) / ABRIR, 0.0, 1.0)
			if u >= 0.85:
				return CUADROS - 1
			# Rapido al principio y frenando: como una tapa empujada desde dentro.
			return 1 + mini(CUADROS - 3, int((1.0 - pow(1.0 - u / 0.85, 2.0)) * (CUADROS - 2)))
	return CUADROS - 1


## La luz que se escapa por la rendija de la tapa mientras tiembla.
func _pintar_rendija(u: float) -> void:
	var puntos := PackedVector2Array()
	for p in RENDIJA:
		puntos.append(_punto(p) + Vector2(0.0, -1.0))
	draw_polyline(puntos, Color(1.0, 0.75, 0.25, 0.35 * u), 9.0 * ESCALA, true)
	draw_polyline(puntos, Color(1.0, 0.95, 0.7, 0.85 * u), 2.5 * ESCALA, true)


func _pintar_rayos(boca: Vector2, fuerza: float) -> void:
	for i in 10:
		var angulo := i * TAU / 10.0 + _tiempo * 0.5
		var largo := 150.0 * (0.8 + 0.2 * sin(_tiempo * 2.0 + i))
		draw_colored_polygon(PackedVector2Array([boca, boca + Vector2.from_angle(angulo - 0.09) * largo,
			boca + Vector2.from_angle(angulo + 0.09) * largo]), Color(1.0, 0.85, 0.4, 0.1 * fuerza))


## El haz: dos trapecios hacia arriba, el de fuera dorado y ancho, y el de
## dentro casi blanco, que se apagan hacia arriba.
func _pintar_haz(boca: Vector2, fuerza: float) -> void:
	var alto := 230.0 * (0.4 + 0.6 * fuerza)
	for capa in [[46.0, 30.0, Color(1.0, 0.75, 0.25)], [22.0, 12.0, Color(1.0, 0.97, 0.8)]]:
		var abajo: float = capa[0]
		var arriba: float = capa[1]
		var color: Color = capa[2]
		draw_polygon(PackedVector2Array([boca + Vector2(-abajo, 4.0), boca + Vector2(abajo, 4.0),
			boca + Vector2(arriba, -alto), boca + Vector2(-arriba, -alto)]),
			PackedColorArray([Color(color, 0.5 * fuerza), Color(color, 0.5 * fuerza), Color(color, 0.0), Color(color, 0.0)]))


func _pintar_particulas() -> void:
	for p in _particulas:
		var vida: float = 1.0 - p.vida / p.max
		match p.tipo:
			"moneda":
				var ancho: float = 5.0 * absf(cos(p.giro))
				var alfa := minf(1.0, vida * 3.0)
				draw_set_transform(p.p, 0.0, Vector2(maxf(ancho, 1.0) / 5.0, 1.0))
				draw_circle(Vector2.ZERO, 5.0, Color(0.42, 0.26, 0.05, alfa))
				draw_circle(Vector2.ZERO, 4.0, Color(1.0, 0.78, 0.25, alfa))
				draw_circle(Vector2(-1.2, -1.2), 1.4, Color(1.0, 0.97, 0.75, alfa))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"chispa":
				var color: Color = p.color
				var cola: Vector2 = p.v * 0.04
				draw_line(p.p - cola, p.p, Color(color, vida), 2.5, true)
				draw_circle(p.p, 1.6, Color(1.0, 1.0, 0.9, vida))
			"destello":
				var r: float = p.r * sin(vida * PI)
				_estrella(p.p, r, Color(1.0, 0.95, 0.7, 0.9))
			"onda":
				var u := 1.0 - vida
				draw_set_transform(Vector2(0.0, -4.0), 0.0, Vector2(1.0, 0.45))
				draw_arc(Vector2.ZERO, 40.0 + 120.0 * u, 0.0, TAU, 48, Color(1.0, 0.85, 0.4, 0.8 * vida), 6.0 * vida + 1.0, true)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Un destello de cuatro puntas finas.
func _estrella(centro: Vector2, r: float, color: Color) -> void:
	if r <= 0.3:
		return
	var fina := r * 0.22
	draw_colored_polygon(PackedVector2Array([centro + Vector2(0.0, -r), centro + Vector2(fina, -fina), centro + Vector2(r, 0.0),
		centro + Vector2(fina, fina), centro + Vector2(0.0, r), centro + Vector2(-fina, fina), centro + Vector2(-r, 0.0),
		centro + Vector2(-fina, -fina)]), color)
