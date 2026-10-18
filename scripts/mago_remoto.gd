## El mago de otro jugador, tal como se ve en este ordenador. Fase 1 del
## cooperativo (Matias, 2026-10-16).
##
## POR QUE NO ES UN Jugador: cada uno mueve SU mago en su ordenador, sin
## esperar a la red (como en el estudio: asi no hay retraso al andar). Los de
## los demas solo se ensenan donde dicen que estan. Si fueran un Jugador
## entero, en este ordenador recogerian objetos, pisarian pinchos y les
## pegarian los enemigos por su cuenta, y cada pantalla contaria otra cosa.
## Por eso tampoco esta en el grupo "jugador" ni tiene colision.
class_name MagoRemoto
extends Node2D

## Lo rapido que alcanza el sitio que le han mandado. Llegan unos 20 avisos
## por segundo: sin suavizar, iria a saltos.
const SUAVIZADO: float = 18.0
## A mas distancia que esto, salta de golpe (ha caido por un agujero, o es
## el primer aviso).
const SALTO_MAXIMO: float = 160.0
## Mismo sitio y tamano que en Jugador.tscn y EscudoBurbuja.
const DESFASE_SPRITE := Vector2(0.0, -33.0)
const RADIO_ESCUDO: float = 42.0
const COLOR_ESCUDO := Color(0.62, 0.9, 1.0)

var numero: int = 2
var personaje: PersonajeJugable
## Lo que manda su ordenador de su vida. Caido, no se ensena y los enemigos
## no van a por el.
var vivo: bool = true
var vida: int = 100
var vida_maxima: int = 100

var _objetivo: Vector2 = Vector2.ZERO
var _recibido: bool = false
var _escudo: bool = false
var _sprite: AnimatedSprite2D


func _init(mago: PersonajeJugable, numero_jugador: int) -> void:
	personaje = mago
	numero = numero_jugador
	name = "MagoRemoto%d" % numero_jugador


func _ready() -> void:
	# Los enemigos del anfitrion lo buscan aqui para elegir a por quien van
	# (Enemigo._buscar_objetivo): no esta en el grupo "jugador", que es el
	# del mago de este ordenador, al que se le hace dano.
	add_to_group("jugadores_remotos")
	# Como el del jugador: por encima del suelo y de los enemigos.
	z_index = 10
	visible = false
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = personaje.animaciones
	_sprite.offset = DESFASE_SPRITE
	_sprite.play(&"quieto_abajo")
	add_child(_sprite)


func sigue_vivo() -> bool:
	return vivo


## Donde le apuntan los enemigos: al cuerpo, como al jugador (16 px por
## encima de los pies).
func centro_colision() -> Vector2:
	return global_position + Vector2(0.0, -16.0)


## Lo que ha mandado su ordenador: donde esta, como se le ve y su vida.
func recibir(posicion: Vector2, animacion: StringName, color: Color, escudo: bool,
		vida_ahora: int = 100, maxima: int = 100, sigue: bool = true) -> void:
	_objetivo = posicion
	if not _recibido or global_position.distance_to(posicion) > SALTO_MAXIMO:
		global_position = posicion
	_recibido = true
	vida = vida_ahora
	vida_maxima = maxima
	vivo = sigue
	visible = sigue
	if _sprite.animation != animacion and _sprite.sprite_frames.has_animation(animacion):
		_sprite.play(animacion)
	_sprite.modulate = color
	_escudo = escudo


func _process(delta: float) -> void:
	if not _recibido:
		return
	global_position = global_position.lerp(_objetivo, 1.0 - exp(-SUAVIZADO * delta))
	queue_redraw()


## El escudo del mago blanco, si lo lleva puesto, y su numero encima, para
## saber quien es quien (dos magos pueden parecerse de lejos).
func _draw() -> void:
	if _escudo:
		draw_circle(DESFASE_SPRITE, RADIO_ESCUDO, Color(COLOR_ESCUDO, 0.14))
		draw_arc(DESFASE_SPRITE, RADIO_ESCUDO, 0.0, TAU, 48, Color(COLOR_ESCUDO, 0.85), 2.5, true)
	# El rotulo mide lo mismo en pantalla con cualquier zoom, como los
	# numeros de dano.
	var camara := get_viewport().get_camera_2d()
	var zoom := camara.zoom.x if camara != null else 1.0
	var escala := 1.0 / maxf(zoom, 0.05)
	var texto := "J%d" % numero
	var fuente := ThemeDB.fallback_font
	var tamano := 15
	var ancho := fuente.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamano).x
	draw_set_transform(Vector2(0.0, -78.0), 0.0, Vector2(escala, escala))
	var sitio := Vector2(-ancho * 0.5, 0.0)
	draw_string_outline(fuente, sitio, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamano, 4, Color(0, 0, 0, 0.8))
	draw_string(fuente, sitio, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamano, personaje.color.lightened(0.3))
	draw_set_transform(Vector2.ZERO)
