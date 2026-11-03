## Un proyectil de veneno: el ataque especial del mago verde (pedido por
## Matias el 2026-11-03). Salen varios a la vez, repartidos en circulo
## alrededor del mago (PersonajeJugable.proyectiles_veneno).
##
## Va recto un momento ('salida') y luego persigue al enemigo mas cercano a
## el, pero gira muy poco ('giro'): muchos no llegan a doblar y se estrellan
## contra una roca o el muro, y ahi se acaban. El que da a un enemigo lo
## envenena (Enemigo.envenenar) y se acaba. No quita vida al dar: lo que hace
## es el veneno.
##
## POR QUE NO ES UNA BolaMagica: la bola va recta y solo sabe chocar; esta
## decide cada paso hacia donde girar. Lo que comparten (chocar con rocas,
## apagarse al salir del suelo) son dos lineas.
class_name BolaVenenosa
extends Area2D

## Lo que dura como mucho. Girando tan poco, una puede quedarse dando vueltas
## alrededor de un enemigo sin llegar a tocarlo nunca: a los 8 s se deshace.
const VIDA_MAXIMA: float = 8.0
const DESVANECER: float = 0.4
const RADIO: float = 10.0
## La capa de los disparos del jugador y la de los enemigos, como la bola.
const CAPA_DISPAROS: int = 16
const CAPA_ENEMIGOS: int = 32
const COLOR := Color(0.62, 1.0, 0.32)
const COLOR_HALO := Color(0.2, 0.62, 0.16)

## Hacia donde va. Gira poco a poco hacia el enemigo que persigue.
var direccion: Vector2 = Vector2.RIGHT
var velocidad: float = 210.0
## Segundos que va recto antes de empezar a perseguir.
var salida: float = 0.5
## Lo que gira como mucho, en radianes por segundo.
var giro: float = deg_to_rad(80.0)
var veneno_duracion: float = 5.0
var veneno_dano: float = 5.0
## La sala de la que sale: persigue a sus enemigos y se acaba al salir de su
## suelo (al tocar el muro o cruzar una puerta).
var sala: Sala = null
## En cooperativo, fuera del anfitrion: solo se ve, como la bola. Alli otra
## igual es la que envenena (MundoRed).
var solo_ver: bool = false

var _vida: float = 0.0
var _fase: float = 0.0
var _acabada: bool = false


func _ready() -> void:
	z_index = 9
	collision_layer = CAPA_DISPAROS
	collision_mask = CAPA_ENEMIGOS
	monitorable = false
	var forma := CollisionShape2D.new()
	var circulo := CircleShape2D.new()
	circulo.radius = RADIO
	forma.shape = circulo
	add_child(forma)
	area_entered.connect(_al_tocar)
	# Cada una con su vaiven: si no, las ocho latirian a la vez.
	_fase = randf() * TAU


func _physics_process(delta: float) -> void:
	if _acabada:
		return
	_vida += delta
	_fase += delta
	if _vida >= VIDA_MAXIMA:
		_acabar(false)
		return
	if _vida >= salida:
		_girar_hacia_enemigo(delta)
	var antes := global_position
	global_position += direccion * velocidad * delta
	var choque := Terreno.choque(get_world_2d(), antes, global_position,
		RADIO * 0.8, Terreno.CAPA_MUROS | Terreno.CAPA_ROCAS)
	if choque != null:
		global_position = antes
		_acabar(true)
		return
	if is_instance_valid(sala) and not sala.rect_suelo_global().has_point(global_position):
		global_position = antes
		_acabar(true)
		return
	queue_redraw()


## Gira hacia el enemigo mas cercano de su sala, como mucho 'giro' por
## segundo. Sin enemigos, sigue recto.
func _girar_hacia_enemigo(delta: float) -> void:
	var objetivo := _enemigo_mas_cercano()
	if objetivo == null:
		return
	var hacia := objetivo.global_position - global_position
	var falta := wrapf(hacia.angle() - direccion.angle(), -PI, PI)
	direccion = direccion.rotated(clampf(falta, -giro * delta, giro * delta))


func _enemigo_mas_cercano() -> Enemigo:
	if not is_instance_valid(sala):
		return null
	var mejor: Enemigo = null
	var mejor_distancia := INF
	for enemigo in sala.enemigos():
		if not is_instance_valid(enemigo) or enemigo.is_queued_for_deletion() \
				or not enemigo.visible or not enemigo.es_tangible() or enemigo.fraccion_vida() <= 0.0:
			continue
		var distancia := global_position.distance_squared_to(enemigo.global_position)
		if distancia < mejor_distancia:
			mejor_distancia = distancia
			mejor = enemigo
	return mejor


func _al_tocar(area: Area2D) -> void:
	if _acabada or not area.has_method("envenenar"):
		return
	# Un enemigo intocable (el fantasma desvanecido, la planta bajo tierra)
	# no la para: sigue de largo, como la bola.
	if area.has_method("es_tangible") and not area.es_tangible():
		return
	if not solo_ver:
		if area.es_invulnerable():
			# El escudo del jefe: no le entra, pero que se note el golpe.
			area.herir(0.0)
		else:
			area.envenenar(veneno_duracion, veneno_dano)
			Sonido.tocar(&"golpe_enemigo")
	_acabar(true)


## Se acaba: con un chapoteo verde si ha chocado con algo, o deshaciendose si
## se le ha pasado el tiempo.
func _acabar(chocada: bool) -> void:
	if _acabada:
		return
	_acabada = true
	set_deferred("monitoring", false)
	if chocada:
		var chapoteo := Explosion.new()
		chapoteo.radio = RADIO * 2.2
		chapoteo.color = COLOR
		chapoteo.position = position
		get_parent().add_child(chapoteo)
		queue_free()
		return
	var desvanecer := create_tween()
	desvanecer.tween_property(self, "modulate:a", 0.0, DESVANECER)
	desvanecer.tween_callback(queue_free)


## Una gota de veneno gorda: halo, cuerpo verde con un borde oscuro, brillo,
## y un rastro de gotitas detras.
func _draw() -> void:
	var pulso := 1.0 + sin(_fase * 9.0) * 0.1
	var atras := -direccion
	for i in 4:
		var t := float(i + 1) / 5.0
		draw_circle(atras * RADIO * (1.1 + i * 0.9) + atras.orthogonal() * sin(_fase * 7.0 + i) * 2.0,
			RADIO * (0.5 - t * 0.3), Color(COLOR.r, COLOR.g, COLOR.b, 0.55 - t * 0.4))
	draw_circle(Vector2.ZERO, RADIO * 1.8 * pulso, Color(COLOR_HALO.r, COLOR_HALO.g, COLOR_HALO.b, 0.25))
	draw_circle(Vector2.ZERO, RADIO * 1.05 * pulso, Color(0.04, 0.16, 0.05, 0.95))
	draw_circle(Vector2.ZERO, RADIO * 0.85 * pulso, Color(COLOR.r, COLOR.g, COLOR.b, 0.95))
	draw_circle(Vector2(-RADIO * 0.3, -RADIO * 0.3), RADIO * 0.3, Color(1.0, 1.0, 0.85, 0.9))
