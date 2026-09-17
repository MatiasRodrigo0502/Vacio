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

## Radio visual (y de colision) del jugador.
const RADIO: float = 13.0

var vida_actual: int = 0

## Tiempo que queda de invulnerabilidad. > 0 significa invulnerable.
var _tiempo_invulnerable: float = 0.0
## Controla el parpadeo durante la invulnerabilidad.
var _fase_parpadeo: float = 0.0
## Mientras es false el jugador no responde a los controles (cambios de piso).
var _control_activo: bool = true


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


func _actualizar_invulnerabilidad(delta: float) -> void:
	if _tiempo_invulnerable <= 0.0:
		return
	_tiempo_invulnerable -= delta
	_fase_parpadeo += delta
	queue_redraw()
	if _tiempo_invulnerable <= 0.0:
		_fase_parpadeo = 0.0
		queue_redraw()


## Aplica dano. Devuelve true solo si el golpe ha contado (util para que el
## obstaculo decida si reproducir efectos). Si esta invulnerable, se ignora.
func recibir_dano(cantidad: int = 1) -> bool:
	if esta_invulnerable() or vida_actual <= 0:
		return false

	vida_actual = maxi(vida_actual - cantidad, 0)
	_tiempo_invulnerable = duracion_invulnerabilidad
	dano_recibido.emit()
	vida_cambiada.emit(vida_actual, vida_maxima)
	queue_redraw()

	if vida_actual == 0:
		_control_activo = false
		velocity = Vector2.ZERO
		sin_vida.emit()
	return true


func esta_invulnerable() -> bool:
	return _tiempo_invulnerable > 0.0


## Coloca al jugador al principio de un piso: posicion, inercia y control.
## La vida NO se toca aqui a proposito: se arrastra de piso a piso, que es lo
## que hace que el descenso tenga tension.
func reubicar(posicion: Vector2) -> void:
	global_position = posicion
	velocity = Vector2.ZERO
	_control_activo = true


## Restaura la vida al maximo. Solo se usa al empezar una partida nueva.
func restaurar_vida() -> void:
	vida_actual = vida_maxima
	_tiempo_invulnerable = 0.0
	_control_activo = true
	vida_cambiada.emit(vida_actual, vida_maxima)
	queue_redraw()


## Congela al jugador (final de partida, transiciones).
func bloquear_control() -> void:
	_control_activo = false
	velocity = Vector2.ZERO


# El aspecto se dibuja por codigo en vez de usar un sprite: en Fase 1 no hay
# arte todavia y asi el repo no arrastra binarios que compliquen los merges.
func _draw() -> void:
	var color_base := Color(0.96, 0.93, 0.85)
	if esta_invulnerable():
		# Parpadeo a ~10 Hz mientras dura la invulnerabilidad.
		var visible_ahora := fmod(_fase_parpadeo, 0.2) < 0.1
		color_base = Color(1.0, 0.45, 0.35, 1.0 if visible_ahora else 0.35)

	draw_circle(Vector2.ZERO, RADIO, color_base)
	draw_arc(Vector2.ZERO, RADIO, 0.0, TAU, 24, Color(0.1, 0.08, 0.07, 0.9), 2.5, true)
