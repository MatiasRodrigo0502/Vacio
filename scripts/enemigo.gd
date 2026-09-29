## Enemigo: un slime que persigue al jugador y le quita vida al tocarlo.
##
## POR QUE Area2D Y NO CharacterBody2D:
## por lo mismo que los obstaculos. Un cuerpo solido frenaria al jugador al
## chocar y este juego va de atravesar huecos con inercia; aqui el contacto
## resta vida y todo el mundo sigue moviendose. Ademas asi la bola magica, que
## tambien es un Area2D, lo detecta sin tener que mezclar capas de fisica.
##
## Expone romper() igual que las rocas: la bola no pregunta contra que choca,
## solo si eso se puede romper.
class_name Enemigo
extends Area2D

signal muerto(enemigo: Enemigo)

## De donde salen vida, velocidad, dibujo y demas. Lo pone la mecanica que los
## reparte; sin tipo, el enemigo no sabe que es y no se coloca.
var tipo: TipoEnemigo = null

var _vida: int = 0
var _objetivo: Node2D = null
## Dormido no se mueve. La sala lo duerme al registrarlo y lo despierta cuando
## el jugador entra.
##
## POR QUE HACE FALTA:
## el enemigo es un Area2D que va directo hacia el jugador, sin chocar con
## nada. Con salas pegadas, uno de la sala de al lado lo veria a traves del
## muro y lo cruzaria para perseguirlo. Dormido hasta que entras, cada sala es
## su propia pelea. Empieza despierto para que, suelto fuera de una sala,
## siga funcionando como siempre.
var _despierto: bool = true
var _fase: float = 0.0

@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _forma: CollisionShape2D = $Forma


func _ready() -> void:
	# El enemigo busca al jugador por grupo en vez de que se lo pasen: asi la
	# mecanica que los coloca no necesita conocer la escena del juego.
	_objetivo = get_tree().get_first_node_in_group("jugador")


## Lo llama la mecanica que los reparte por el piso.
##
## POR QUE NO SE TINTAN CON EL COLOR DEL PISO, como las rocas: un enemigo tiene
## que verse siempre. Con el tinte del piso 12, que tira a rojo, el slime verde
## se camuflaba con el suelo, y eso en un juego donde te quita vida al tocarte
## no vale. Las rocas se tintan para integrarse; los enemigos, para destacar.
func preparar(tipo_enemigo: TipoEnemigo, posicion: Vector2) -> void:
	tipo = tipo_enemigo
	global_position = posicion
	_vida = tipo.vida
	_sprite.modulate = Color.WHITE
	_sprite.sprite_frames = tipo.animaciones
	_sprite.play(&"moverse")

	var tam := tipo.animaciones.get_frame_texture(&"moverse", 0).get_size()
	var escala := tipo.alto / tam.y
	_sprite.scale = Vector2(escala, escala)

	var forma := CircleShape2D.new()
	# El circulo cubre el cuerpo, un poco mas pequeno que el dibujo: igual que
	# con las rocas, mejor que el jugador sienta que ha pasado raspando a que le
	# golpee el aire.
	forma.radius = tipo.alto * 0.40
	_forma.shape = forma


func _physics_process(delta: float) -> void:
	_fase += delta
	_golpear_lo_que_toca()
	if not _despierto:
		return
	if not is_instance_valid(_objetivo):
		return

	if tipo == null:
		return
	var hacia := _objetivo.global_position - global_position
	if hacia.length() > tipo.radio_vision:
		return

	global_position += hacia.normalized() * tipo.velocidad * delta
	# Mira hacia donde va: el slime es simetrico, pero el volteo da sensacion
	# de intencion y sale gratis.
	_sprite.flip_h = hacia.x < 0.0


func dormir() -> void:
	_despierto = false


func despertar() -> void:
	_despierto = true


func esta_despierto() -> bool:
	return _despierto


## La llama la bola magica. Aguanta varios impactos.
##
## El ataque cargado reparte varios impactos de golpe, asi que puede llamar a
## esto cuando el enemigo ya esta muerto: queue_free() no lo borra hasta el
## final del fotograma y hasta entonces sigue siendo un objeto valido. Sin este
## guardia, emitiria "muerto" mas de una vez.
func romper() -> void:
	if _vida <= 0:
		return
	_vida -= 1
	if _vida > 0:
		# Parpadeo blanco para que se vea que ha entrado el disparo.
		_sprite.modulate = Color(2.0, 2.0, 2.0)
		await get_tree().create_timer(0.08).timeout
		if is_instance_valid(self):
			_sprite.modulate = Color.WHITE
		return

	muerto.emit(self)
	queue_free()


## Hace dano a todo lo que este tocando, en cada paso de fisica.
##
## POR QUE MIRANDO EL SOLAPE Y NO CON body_entered:
## body_entered avisa una sola vez, al entrar. El enemigo va directo hacia el
## jugador y se le queda encima, asi que solo le pegaba al primer contacto:
## quedarse quieto con un slime encima costaba un corazon y ya. Mirando el
## solape en cada paso vuelve a pegar en cuanto acaba la invulnerabilidad, y
## no pega de mas porque recibir_dano() ignora los golpes mientras dura.
func _golpear_lo_que_toca() -> void:
	if tipo == null:
		return
	for cuerpo in get_overlapping_bodies():
		if cuerpo.has_method("recibir_dano"):
			cuerpo.recibir_dano(tipo.dano)
