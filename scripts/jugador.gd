## Jugador: movimiento top-down libre y de precision + sistema de vida.
##
## POR QUE CharacterBody2D Y NO RigidBody2D:
## en un juego de habilidad el control tiene que ser 100% predecible. Con
## aceleracion/friccion explicitas podemos afinar el "peso" del personaje piso
## a piso sin pelearnos con la simulacion fisica.
class_name Jugador
extends CharacterBody2D

signal vida_cambiada(vida_actual: int, vida_maxima: int)
signal dano_recibido
signal sin_vida
## Se emite en cada disparo, con el punto de salida y hacia donde va.
signal bola_lanzada(desde: Vector2, direccion: Vector2)
## Se emite al recoger un objeto, para que el HUD lo anuncie.
signal mejora_recogida(mejora: ObjetoMejora)

@export_group("Movimiento")
## Velocidad punta en px/s.
@export var velocidad_maxima: float = 265.0
## Cuanto cuesta arrancar (px/s^2). Mas alto = respuesta mas inmediata.
@export var aceleracion: float = 2400.0
## Cuanto cuesta parar (px/s^2). Mas alto = frenada mas seca.
@export var friccion: float = 2800.0

@export_group("Vida")
@export var vida_maxima: int = 3
## Segundos de invulnerabilidad tras un golpe. Evita perder toda la vida de
## golpe cuando el jugador se queda encima de un obstaculo.
@export var duracion_invulnerabilidad: float = 1.1

@export_group("Disparo")
## Segundos entre disparo y disparo. Es la cadencia: mas bajo, mas rapido.
@export var cadencia_disparo: float = 0.34
## Velocidad de las bolas. La lee Principal al crearlas.
@export var velocidad_bola: float = 620.0
## Radio de las bolas. Tambien lo lee Principal.
@export var radio_bola: float = 11.0

## Tope de cadencia: por debajo de esto el disparo se vuelve una manguera y el
## juego deja de tener tension.
const CADENCIA_MINIMA: float = 0.09

## Por debajo de esta velocidad se considera que el personaje esta parado y se
## pasa a la animacion de reposo. No es 0 porque la friccion deja residuos.
const VELOCIDAD_MINIMA_ANDAR: float = 12.0

var vida_actual: int = 0

## Valores de fabrica, para poder devolver al jugador a como empezo cuando se
## empieza una partida nueva. Las mejoras se acumulan durante toda la partida,
## asi que sin esto la siguiente empezaria con las de la anterior.
var _base_vida_maxima: int = 0
var _base_velocidad: float = 0.0
var _base_cadencia: float = 0.0
var _base_velocidad_bola: float = 0.0
var _base_radio_bola: float = 0.0

## Tiempo que queda de invulnerabilidad. > 0 significa invulnerable.
var _tiempo_invulnerable: float = 0.0
## Controla el parpadeo durante la invulnerabilidad.
var _fase_parpadeo: float = 0.0
## Mientras es false el jugador no responde a los controles (cambios de piso).
var _control_activo: bool = true
## Cuanto falta para poder volver a disparar.
var _espera_disparo: float = 0.0
## Direccion a la que mira el sprite: "abajo", "izquierda", "derecha", "arriba".
## Se guarda en vez de recalcularse cada vez porque, al soltar los controles, el
## mago tiene que quedarse mirando a donde estaba, no volver a una por defecto.
var _mirando: StringName = &"abajo"

## El sprite se escala y se desplaza desde la escena, no desde aqui: el origen
## del nodo esta a los pies del personaje y la forma de colision cubre la base
## de la tunica. Asi, en vista cenital, lo que choca es la "huella" en el suelo y no
## la cabeza, que es lo que espera el jugador.
@onready var _sprite: AnimatedSprite2D = $Sprite


func _ready() -> void:
	_base_vida_maxima = vida_maxima
	_base_velocidad = velocidad_maxima
	_base_cadencia = cadencia_disparo
	_base_velocidad_bola = velocidad_bola
	_base_radio_bola = radio_bola

	vida_actual = vida_maxima
	vida_cambiada.emit(vida_actual, vida_maxima)


func _physics_process(delta: float) -> void:
	_actualizar_invulnerabilidad(delta)

	var direccion := Vector2.ZERO
	if _control_activo:
		# Input.get_vector ya normaliza: nada de ir mas rapido en diagonal.
		direccion = Input.get_vector(
			"mover_izquierda", "mover_derecha", "mover_arriba", "mover_abajo")

	if direccion != Vector2.ZERO:
		velocity = velocity.move_toward(direccion * velocidad_maxima, aceleracion * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friccion * delta)

	move_and_slide()
	_actualizar_animacion()

	_actualizar_disparo(delta)


## Hacia donde esta apuntando el jugador, sin mirar la cadencia.
##
## Esta aparte del disparo porque la usan dos cosas: disparar y decidir a que
## lado mira el sprite. Si estuviera dentro de _actualizar_disparo, el mago
## dejaria de mirar al enemigo entre bala y bala, que es justo cuando se ve.
func _direccion_apuntada() -> Vector2:
	if not _control_activo:
		return Vector2.ZERO

	# El raton manda sobre las flechas: si estas apuntando, es lo que quieres.
	# Con el raton se apunta libre, en cualquier angulo; con las flechas solo a
	# las cuatro direcciones, que es el esquema clasico de teclado.
	if Input.is_action_pressed("disparar_raton"):
		var hacia := get_global_mouse_position() - centro_colision()
		return hacia.normalized() if hacia.length() > 1.0 else Vector2.ZERO

	var flechas := Input.get_vector(
		"disparar_izquierda", "disparar_derecha", "disparar_arriba", "disparar_abajo")
	if flechas == Vector2.ZERO:
		return Vector2.ZERO
	# Con dos flechas a la vez manda la mas marcada: las diagonales harian el
	# disparo de teclado mas facil de lo que toca.
	if absf(flechas.x) > absf(flechas.y):
		return Vector2(signf(flechas.x), 0.0)
	return Vector2(0.0, signf(flechas.y))


## Dispara mientras se mantenga pulsado, con una cadencia fija.
func _actualizar_disparo(delta: float) -> void:
	_espera_disparo = maxf(_espera_disparo - delta, 0.0)
	if not _control_activo or _espera_disparo > 0.0:
		return

	var direccion := _direccion_apuntada()
	if direccion == Vector2.ZERO:
		return

	_espera_disparo = cadencia_disparo
	# Sale del centro del cuerpo y no de los pies, para que se vea nacer del
	# personaje y no del suelo.
	bola_lanzada.emit(centro_colision(), direccion)


## Elige la animacion: accion (andar o estar quieto) por direccion.
##
## El movimiento se mira por la velocidad real y no por la tecla pulsada, para
## que el mago siga "andando" durante el deslizamiento por inercia, que es lo
## que se ve en pantalla.
##
## Apuntar manda sobre moverse: si estas disparando a un enemigo, el mago tiene
## que mirarlo aunque te estes alejando de el. Es como funciona Isaac, y sin
## esto pelear retrocediendo se ve al reves de lo que estas haciendo.
func _actualizar_animacion() -> void:
	var apuntando := _direccion_apuntada()
	if apuntando != Vector2.ZERO:
		_mirando = _lado(apuntando)
	elif velocity.length() > VELOCIDAD_MINIMA_ANDAR:
		_mirando = _lado(velocity)

	var accion := "caminar" if velocity.length() > VELOCIDAD_MINIMA_ANDAR else "quieto"
	var animacion := StringName(accion + "_" + _mirando)
	if _sprite.animation == animacion:
		return

	# Al girarse se conserva el punto del ciclo de andar: si cada giro empezara
	# la animacion de cero, el mago daria un tiron con cada cambio de rumbo.
	# Se limita el indice porque "arriba" tiene una pose menos que las demas.
	var marco := _sprite.frame
	var avance := _sprite.frame_progress
	_sprite.play(animacion)
	if accion == "caminar":
		var tope := _sprite.sprite_frames.get_frame_count(animacion) - 1
		_sprite.set_frame_and_progress(mini(marco, tope), avance)


## Traduce un vector a la direccion de la hoja de sprites.
##
## En empate (diagonal exacta) gana el eje horizontal: las vistas de lado
## tienen mas detalle que la de espaldas y se lee mejor a quien estas mirando.
func _lado(v: Vector2) -> StringName:
	if absf(v.x) >= absf(v.y):
		return &"derecha" if v.x > 0.0 else &"izquierda"
	return &"abajo" if v.y > 0.0 else &"arriba"


func _actualizar_invulnerabilidad(delta: float) -> void:
	if _tiempo_invulnerable <= 0.0:
		return

	_tiempo_invulnerable -= delta
	_fase_parpadeo += delta

	# Parpadeo rojo a ~10 Hz mientras dura la invulnerabilidad. Se hace con
	# modulate y no cambiando de animacion porque ningun pack de los probados
	# trae pose de golpe: asi el aviso funciona sobre cualquier animacion.
	var encendido := fmod(_fase_parpadeo, 0.2) < 0.1
	_sprite.modulate = Color(1.0, 0.4, 0.35, 1.0) if encendido else Color(1.0, 1.0, 1.0, 0.45)

	if _tiempo_invulnerable <= 0.0:
		_fase_parpadeo = 0.0
		_sprite.modulate = Color.WHITE


## Aplica dano. Devuelve true solo si el golpe ha contado (util para que el
## obstaculo decida si reproducir efectos). Si esta invulnerable, se ignora.
func recibir_dano(cantidad: int = 1) -> bool:
	if esta_invulnerable() or vida_actual <= 0:
		return false

	vida_actual = maxi(vida_actual - cantidad, 0)
	_tiempo_invulnerable = duracion_invulnerabilidad
	dano_recibido.emit()
	vida_cambiada.emit(vida_actual, vida_maxima)

	if vida_actual == 0:
		_control_activo = false
		velocity = Vector2.ZERO
		sin_vida.emit()
	return true


## Centro real de la forma de colision, que NO es el origen del nodo: el origen
## esta a los pies y el circulo esta mas arriba, sobre la base de la tunica.
## Lo usan los obstaculos para comprobar si un impacto es de verdad.
func centro_colision() -> Vector2:
	return $Forma.global_position


## Aplica un objeto recogido. Las mejoras se suman y duran toda la partida.
func aplicar_mejora(mejora: ObjetoMejora) -> void:
	if mejora == null:
		return

	vida_maxima += mejora.vida_maxima_extra
	# Un corazon nuevo viene lleno, y ademas se cura lo que diga el objeto.
	vida_actual = mini(vida_actual + mejora.vida_maxima_extra + mejora.cura, vida_maxima)

	velocidad_maxima += mejora.velocidad_extra
	cadencia_disparo = maxf(cadencia_disparo * mejora.cadencia_multiplicador,
		CADENCIA_MINIMA)
	velocidad_bola += mejora.velocidad_bola_extra
	radio_bola += mejora.radio_bola_extra

	vida_cambiada.emit(vida_actual, vida_maxima)
	mejora_recogida.emit(mejora)


func esta_invulnerable() -> bool:
	return _tiempo_invulnerable > 0.0


## Coloca al jugador al principio de un piso: posicion, inercia y control.
## La vida NO se toca aqui a proposito: se arrastra de piso a piso, que es lo
## que hace que el descenso tenga tension.
func reubicar(posicion: Vector2) -> void:
	global_position = posicion
	velocity = Vector2.ZERO
	_control_activo = true
	_espera_disparo = 0.0
	# Cada piso empieza mirando hacia donde se baja.
	_mirando = &"abajo"


## Deja al jugador como al empezar: vida llena y sin ninguna mejora recogida.
## Solo se usa al empezar una partida nueva.
func restaurar_vida() -> void:
	vida_maxima = _base_vida_maxima
	velocidad_maxima = _base_velocidad
	cadencia_disparo = _base_cadencia
	velocidad_bola = _base_velocidad_bola
	radio_bola = _base_radio_bola

	vida_actual = vida_maxima
	_tiempo_invulnerable = 0.0
	_fase_parpadeo = 0.0
	_control_activo = true
	_sprite.modulate = Color.WHITE
	_espera_disparo = 0.0
	vida_cambiada.emit(vida_actual, vida_maxima)


## Congela al jugador (final de partida, transiciones).
func bloquear_control() -> void:
	_control_activo = false
	velocity = Vector2.ZERO
