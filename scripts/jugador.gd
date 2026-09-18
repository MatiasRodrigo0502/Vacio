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
## Se emite al lanzar la bola magica, con el punto de salida.
signal bola_lanzada(desde: Vector2)
## Avisa al HUD de si queda bola o no.
signal bola_cambiada(disponible: bool)

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

## Por debajo de esta velocidad se considera que el personaje esta parado y se
## pasa a la animacion de reposo. No es 0 porque la friccion deja residuos.
const VELOCIDAD_MINIMA_ANDAR: float = 12.0

var vida_actual: int = 0

## Tiempo que queda de invulnerabilidad. > 0 significa invulnerable.
var _tiempo_invulnerable: float = 0.0
## Controla el parpadeo durante la invulnerabilidad.
var _fase_parpadeo: float = 0.0
## Mientras es false el jugador no responde a los controles (cambios de piso).
var _control_activo: bool = true
## Una bola por piso. Se recarga al entrar en el siguiente, en reubicar().
var _bola_disponible: bool = true

## El sprite se escala y se desplaza desde la escena, no desde aqui: el origen
## del nodo esta a los pies del mago y la forma de colision cubre la base de la
## tunica. Asi, en vista cenital, lo que choca es la "huella" en el suelo y no
## la cabeza, que es lo que espera el jugador.
@onready var _sprite: AnimatedSprite2D = $Sprite


func _ready() -> void:
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

	if _control_activo and Input.is_action_just_pressed("lanzar_bola"):
		_lanzar_bola()


## Lanza la bola hacia abajo, si queda. Sale del centro del cuerpo y no de los
## pies, para que se vea nacer del mago y no del suelo.
func _lanzar_bola() -> void:
	if not _bola_disponible:
		return
	_bola_disponible = false
	bola_lanzada.emit(centro_colision())
	bola_cambiada.emit(false)


func tiene_bola() -> bool:
	return _bola_disponible


## Elige la animacion segun el movimiento real, no segun la tecla pulsada: asi
## el mago sigue "andando" durante el deslizamiento por inercia, que es lo que
## se ve en pantalla.
func _actualizar_animacion() -> void:
	var animacion := &"caminar" if velocity.length() > VELOCIDAD_MINIMA_ANDAR else &"quieto"
	if _sprite.animation != animacion:
		_sprite.play(animacion)


func _actualizar_invulnerabilidad(delta: float) -> void:
	if _tiempo_invulnerable <= 0.0:
		return

	_tiempo_invulnerable -= delta
	_fase_parpadeo += delta

	# Parpadeo rojo a ~10 Hz mientras dura la invulnerabilidad. Se hace con
	# modulate y no cambiando de animacion porque este pack no trae pose de
	# golpe: asi el aviso funciona sobre cualquier animacion.
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


func esta_invulnerable() -> bool:
	return _tiempo_invulnerable > 0.0


## Coloca al jugador al principio de un piso: posicion, inercia y control.
## La vida NO se toca aqui a proposito: se arrastra de piso a piso, que es lo
## que hace que el descenso tenga tension.
func reubicar(posicion: Vector2) -> void:
	global_position = posicion
	velocity = Vector2.ZERO
	_control_activo = true
	# La bola se recarga en cada piso: es una por piso, no una por partida.
	_bola_disponible = true
	bola_cambiada.emit(true)


## Restaura la vida al maximo. Solo se usa al empezar una partida nueva.
func restaurar_vida() -> void:
	vida_actual = vida_maxima
	_tiempo_invulnerable = 0.0
	_fase_parpadeo = 0.0
	_control_activo = true
	_sprite.modulate = Color.WHITE
	_bola_disponible = true
	vida_cambiada.emit(vida_actual, vida_maxima)
	bola_cambiada.emit(true)


## Congela al jugador (final de partida, transiciones).
func bloquear_control() -> void:
	_control_activo = false
	velocity = Vector2.ZERO
