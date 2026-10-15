## Escudo del mago blanco, su ataque especial: una burbuja de luz que lo cubre
## entero mientras dura. Los disparos enemigos rebotan en ella y los enemigos
## que la tocan salen despedidos. Mientras esta levantada, nada de lo que
## lanzan los enemigos le quita vida: ni el contacto, ni los disparos, ni las
## explosiones, ni la onda del golem. Lo del suelo (lava, pinchos, caer por un
## agujero) si: no lo lanza nadie, y el escudo no lo para.
##
## COMO HA CAMBIADO (todo pedido por Matias): primero fue una pasiva siempre
## puesta, un arco pequeno delante que paraba lo que llegaba de frente; luego
## ese mismo arco como ataque especial; desde el 2026-10-13, la burbuja
## entera, que hace rebotar en vez de solo parar.
##
## Lo crea el jugador al estrenar un mago con el escudo de ataque especial
## (PersonajeJugable.ataque_especial). Los proyectiles le preguntan al jugador
## si rebotan (Jugador.escudo_rebota); a los enemigos los empuja la propia
## burbuja, que los ve con un Area2D.
##
## LO REBOTADO DA A LOS ENEMIGOS (Matias, 2026-10-15): un disparo que sale de
## la burbuja quita a quien toque lo mismo que quitaba al mago, tambien a
## quien lo tiro y al jefe (ProyectilEnemigo._golpear_enemigos). Ese mismo
## dia se arreglo que algunos rebotes se quedaran pegados a la burbuja.
class_name EscudoBurbuja
extends Node2D

## Radio de la burbuja: el dibujo del mago mide unos 72 px de alto y se pinta
## 33 px por encima de los pies, asi que con 42 lo cubre entero con margen.
const RADIO: float = 42.0
## Centro de la burbuja respecto a los pies del jugador (su origen): el centro
## del dibujo del mago (el offset del sprite en Jugador.tscn).
const CENTRO := Vector2(0.0, -33.0)
## Velocidad con la que salen despedidos los enemigos que la tocan, en px/s.
## Se frena sola en el enemigo (Enemigo.empujar): unos 70 px de rebote.
const EMPUJE: float = 480.0
## Capa de los enemigos (Enemigo.tscn): la burbuja solo mira esa.
const CAPA_ENEMIGOS: int = 32
const COLOR := Color(0.62, 0.9, 1.0)
## Destello al rebotar algo: que se note que ha servido.
const DURACION_DESTELLO: float = 0.2
## Lo que tarda en hincharse al sacarla.
const APERTURA: float = 0.15
## En el ultimo tramo parpadea, para avisar de que se va a acabar.
const AVISO_FIN: float = 0.8

## La pone el jugador desde el mago (PersonajeJugable.duracion_escudo).
var duracion: float = 5.0

var _jugador: Jugador
## Segundos que le quedan levantada. 0 = bajada.
var _levantado: float = 0.0
var _destello: float = 0.0
var _fase: float = 0.0
## Lo que ve a los enemigos que tocan la burbuja.
var _zona: Area2D


func _init(jugador: Jugador) -> void:
	_jugador = jugador
	name = "Escudo"


func _ready() -> void:
	position = CENTRO
	visible = false
	_zona = Area2D.new()
	_zona.collision_layer = 0
	_zona.collision_mask = CAPA_ENEMIGOS
	_zona.monitorable = false
	_zona.monitoring = false
	var forma := CollisionShape2D.new()
	var circulo := CircleShape2D.new()
	circulo.radius = RADIO
	forma.shape = circulo
	_zona.add_child(forma)
	add_child(_zona)


func _process(delta: float) -> void:
	_levantado = maxf(0.0, _levantado - delta)
	_destello = maxf(0.0, _destello - delta)
	_fase += delta
	visible = activo()
	# Fuera del paso de fisica: encender o apagar un area en mitad de el hace
	# quejarse al motor.
	if _zona.monitoring != activo():
		_zona.monitoring = activo()
	queue_redraw()


## Los enemigos que la tocan salen despedidos. En cada paso, y no al entrar:
## uno que siga empujando hacia el mago tiene que seguir rebotando.
func _physics_process(_delta: float) -> void:
	if not activo() or not _zona.monitoring:
		return
	for area in _zona.get_overlapping_areas():
		var enemigo := area as Enemigo
		# Lo que va escondido (la planta bajo tierra) no choca con nada.
		if enemigo != null and enemigo.es_tangible():
			_despedir(enemigo)


func _despedir(enemigo: Enemigo) -> void:
	# Al jefe no: es demasiado grande para salir rebotado. La burbuja le
	# sigue parando el golpe (mientras esta, el contacto no quita vida).
	if enemigo.tipo.jefe:
		return
	var hacia := enemigo.global_position - global_position
	var normal := hacia.normalized() if hacia.length() > 1.0 else Vector2.DOWN
	# Fuera de la burbuja ya, para que no llegue a tocar al mago.
	var fuera := RADIO + enemigo.tipo.alto * 0.4
	if hacia.length() < fuera:
		enemigo.global_position = global_position + normal * fuera
		enemigo.mantener_en_la_sala()
	enemigo.empujar(normal * EMPUJE)
	_destello = DURACION_DESTELLO
	Sonido.tocar(&"escudo_golpe")


## La saca. Devuelve false si no se puede: ya levantada, sin vida o cayendo.
## Si cuenta como el especial del piso lo decide el jugador, con lo que
## devuelve esto.
func levantar() -> bool:
	if activo() or _jugador.vida_actual <= 0 or _jugador.esta_cayendo():
		return false
	_levantado = duracion
	return true


## La baja. Al empezar partida y al llegar a un piso.
func bajar() -> void:
	_levantado = 0.0


## Levantada, y con el mago vivo y en pie: cayendo por un agujero no esta.
func activo() -> bool:
	return _levantado > 0.0 and _jugador.vida_actual > 0 and not _jugador.esta_cayendo()


## Si algo de 'radio' que ha ido de 'desde' a 'hasta' (en el mundo) en este
## paso ha tocado la burbuja, la normal de la burbuja alli (hacia fuera), para
## rebotarlo. Si no, Vector2.ZERO. Se mira en varios puntos del tramo: el rayo
## va tan deprisa que, en un solo punto, la cruzaria de un paso al siguiente.
##
## El destello y el sonido, solo si se acercaba a la burbuja ('direccion',
## como se mueve respecto a ella: el proyectil le resta lo que anda el mago).
## Uno que ya se aleja y al que la burbuja toca se aparta sin mas; si no,
## sonaria en cada paso.
func rebota(desde: Vector2, hasta: Vector2, radio: float, direccion: Vector2) -> Vector2:
	if not activo():
		return Vector2.ZERO
	for k in 5:
		var v := desde.lerp(hasta, k / 4.0) - global_position
		if v.length() <= RADIO + radio:
			# Justo en el centro no hay normal: la de por donde venia y, si
			# tampoco, la contraria a hacia donde va.
			var normal := v.normalized()
			if v.length() <= 0.01:
				normal = (desde - global_position).normalized()
			if normal == Vector2.ZERO:
				normal = -direccion.normalized() if direccion != Vector2.ZERO else Vector2.UP
			if direccion.dot(normal) < 0.0:
				_destello = DURACION_DESTELLO
				Sonido.tocar(&"escudo_golpe")
			return normal
	return Vector2.ZERO


## True si un punto (con su radio) cae dentro de la burbuja. Lo usa el magma,
## que llega desde arriba y no cruza el borde.
func cubre(punto: Vector2, radio: float) -> bool:
	return activo() and punto.distance_to(global_position) <= RADIO + radio


func _draw() -> void:
	if not activo():
		return
	# Se hincha al sacarla y parpadea cuando le queda poco.
	var abierta := minf(1.0, (duracion - _levantado) / APERTURA)
	var alfa := 1.0
	if _levantado < AVISO_FIN:
		alfa = 0.35 + 0.65 * absf(cos(_levantado * TAU * 3.0))
	var brillo := _destello / DURACION_DESTELLO
	var r := RADIO * abierta
	# El interior, muy flojo: se ve al mago dentro.
	draw_circle(Vector2.ZERO, r, Color(COLOR, (0.1 + 0.12 * brillo) * alfa))
	# El borde, con un resplandor por fuera.
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(COLOR, (0.25 + 0.35 * brillo) * alfa), 7.0 + 5.0 * brillo, true)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(COLOR, 0.85 * alfa), 2.5, true)
	# Un brillo que da la vuelta despacio y el reflejo de arriba a la
	# izquierda: se lee como una burbuja y no como un aro plano.
	var giro := _fase * 1.6
	draw_arc(Vector2.ZERO, r - 3.0, giro, giro + 0.9, 12, Color(1.0, 1.0, 1.0, 0.55 * alfa), 2.0, true)
	# El tiempo que le queda: un aro por fuera que se va vaciando desde arriba,
	# en el sentido del reloj (pedido por Matias el 2026-10-14). El hueco se
	# ve flojo, para que se lea cuanto falta.
	var queda := _levantado / duracion
	draw_arc(Vector2.ZERO, r + 8.0, 0.0, TAU, 48, Color(0.0, 0.0, 0.0, 0.35 * alfa), 5.0, true)
	draw_arc(Vector2.ZERO, r + 8.0, -PI * 0.5, -PI * 0.5 + TAU * queda, 48,
		Color(1.0, 1.0, 1.0, 0.9 * alfa), 3.5, true)
	draw_arc(Vector2.ZERO, r * 0.72, deg_to_rad(200.0), deg_to_rad(245.0), 10,
		Color(1.0, 1.0, 1.0, 0.6 * alfa), 3.0, true)
