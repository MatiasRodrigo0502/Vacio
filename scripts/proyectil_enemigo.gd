## Proyectil de un enemigo: veneno, magma o rayo, segun su TipoProyectil.
##
## Se crea por codigo (ProyectilEnemigo.new()) y no desde una escena: todo lo
## que lo distingue sale del .tres, y una escena solo tendria una forma de
## colision que de todas formas hay que dimensionar aqui.
##
## Cuelga de la sala del enemigo que lo dispara, asi que se va con el piso.
class_name ProyectilEnemigo
extends Area2D

## Al jugador lo detecta la propia area (capa 1). El terreno, muros y rocas,
## se mira a mano con Terreno: un Area2D no detecta los StaticBody2D. Las rocas
## lo paran igual que paran las bolas del jugador: son el parapeto de los dos.
const CAPA_JUGADOR: int = 1
const MASCARA_TERRENO: int = Terreno.CAPA_MUROS | Terreno.CAPA_ROCAS
## Radio del jugador, para saber si la parabola le cae encima.
const RADIO_JUGADOR: float = 15.0
## Altura maxima del arco de la parabola, en pixeles de pantalla.
const ALTURA_MAXIMA: float = 150.0

var tipo: TipoProyectil = null
var direccion: Vector2 = Vector2.RIGHT
## Casilla de la sala, como en las bolas del jugador: lo que sale de ella se
## apaga, para que un disparo no cruce una puerta abierta.
var limite: Rect2 = Rect2()

var _recorrido: float = 0.0
var _fase: float = 0.0
var _acabado: bool = false
# Parabola: de donde sale, donde cae y cuanto tarda.
var _origen: Vector2 = Vector2.ZERO
var _destino: Vector2 = Vector2.ZERO
var _duracion: float = 1.0
var _tiempo: float = 0.0


## Lo prepara antes de meterlo en el arbol. 'destino' solo lo usa la parabola.
func configurar(tipo_proyectil: TipoProyectil, desde: Vector2, hacia: Vector2,
		destino: Vector2, limite_sala: Rect2) -> void:
	tipo = tipo_proyectil
	direccion = hacia.normalized() if hacia != Vector2.ZERO else Vector2.DOWN
	limite = limite_sala
	_origen = desde
	_destino = destino
	_duracion = maxf(desde.distance_to(destino) / maxf(tipo.velocidad, 1.0), 0.35)


func _ready() -> void:
	collision_layer = 0
	monitorable = false
	# Por encima de los enemigos (z 5): un disparo tapado por quien lo tira no
	# se ve salir.
	z_index = 6
	# La parabola va por el aire: no choca con nada hasta caer.
	collision_mask = 0 if tipo.estilo == TipoProyectil.Estilo.PARABOLA else CAPA_JUGADOR
	var forma := CollisionShape2D.new()
	var circulo := CircleShape2D.new()
	circulo.radius = tipo.radio
	forma.shape = circulo
	add_child(forma)
	body_entered.connect(_al_tocar)
	global_position = _origen


func _physics_process(delta: float) -> void:
	_fase += delta
	queue_redraw()
	if _acabado:
		return

	if tipo.estilo == TipoProyectil.Estilo.PARABOLA:
		_tiempo += delta
		global_position = _origen.lerp(_destino, minf(_tiempo / _duracion, 1.0))
		if _tiempo >= _duracion:
			_caer()
		return

	var paso := tipo.velocidad * delta
	var antes := global_position
	global_position += direccion * paso
	_recorrido += paso
	if Terreno.choque(get_world_2d(), antes, global_position, tipo.radio, MASCARA_TERRENO) != null:
		_acabar()
	elif _recorrido >= tipo.alcance:
		_acabar()
	elif limite.has_area() and not limite.has_point(global_position):
		_acabar()


func _al_tocar(cuerpo: Node2D) -> void:
	if _acabado:
		return
	if cuerpo.has_method("recibir_dano"):
		_golpear(cuerpo)
	_acabar()


func _golpear(jugador: Node2D) -> void:
	# El efecto solo si el golpe ha contado: durante la invulnerabilidad el
	# jugador no recibe nada, tampoco el veneno.
	if jugador.recibir_dano(tipo.dano) and tipo.ralentiza > 0.0 \
			and jugador.has_method("envenenar"):
		jugador.envenenar(tipo.ralentiza)


## La parabola llega al suelo: dano a quien este debajo y, si toca, el charco.
func _caer() -> void:
	var jugador := get_tree().get_first_node_in_group("jugador")
	if jugador != null and jugador.has_method("centro_colision") \
			and jugador.centro_colision().distance_to(global_position) \
				< tipo.radio * 1.6 + RADIO_JUGADOR:
		_golpear(jugador)
	_acabar()


func _acabar() -> void:
	if _acabado:
		return
	_acabado = true
	if tipo.charco_radio > 0.0 and get_parent() != null:
		var charco := Lava.new()
		charco.radio = tipo.charco_radio
		charco.duracion = tipo.charco_duracion
		charco.position = get_parent().to_local(global_position)
		# Diferido: esto puede venir de body_entered, en mitad del paso de
		# fisica, y meter un Area2D nueva ahi hace quejarse al motor.
		get_parent().add_child.call_deferred(charco)
	queue_free()


# --- Dibujo -----------------------------------------------------------------

func _draw() -> void:
	match tipo.estilo:
		TipoProyectil.Estilo.RAYO:
			_pintar_rayo()
		TipoProyectil.Estilo.PARABOLA:
			_pintar_parabola()
		_:
			_pintar_bola(Vector2.ZERO)


func _pintar_bola(centro: Vector2) -> void:
	var halo := tipo.color_halo
	var pulso := 1.0 + sin(_fase * 18.0) * 0.1
	for i in 3:
		var t := float(i) / 3.0
		draw_circle(centro - direccion * tipo.radio * (1.1 + i * 0.9),
			tipo.radio * (0.7 - t * 0.35), Color(halo.r, halo.g, halo.b, 0.3 - t * 0.2))
	draw_circle(centro, tipo.radio * 1.7 * pulso, Color(halo.r, halo.g, halo.b, 0.25))
	draw_circle(centro, tipo.radio * pulso, tipo.color)
	draw_circle(centro + Vector2(-0.25, -0.25) * tipo.radio, tipo.radio * 0.35,
		Color(1.0, 1.0, 1.0, 0.8))


## Un relampago: una linea quebrada hacia atras que cambia cada fotograma.
func _pintar_rayo() -> void:
	var largo := minf(_recorrido, 130.0)
	var lado := Vector2(-direccion.y, direccion.x)
	var puntos := PackedVector2Array([Vector2.ZERO])
	var tramos := 6
	for i in range(1, tramos + 1):
		var t := float(i) / tramos
		# El zigzag sale del seno de la fase y del tramo: se mueve solo, sin
		# numeros aleatorios que harian parpadear el rayo a saltos.
		var quiebro := sin(_fase * 60.0 + i * 2.3) * 9.0 * (1.0 - t * 0.3)
		puntos.append(-direccion * largo * t + lado * quiebro)
	var halo := tipo.color_halo
	draw_polyline(puntos, Color(halo.r, halo.g, halo.b, 0.45), tipo.radio * 1.6)
	draw_polyline(puntos, tipo.color, tipo.radio * 0.6)
	draw_polyline(puntos, Color.WHITE, 1.5)
	draw_circle(Vector2.ZERO, tipo.radio, Color.WHITE)


## Por el aire: la bola va arriba, su sombra en el suelo, y donde va a caer
## se marca con un aro. El aro es el aviso: hay tiempo de apartarse.
func _pintar_parabola() -> void:
	var avance := clampf(_tiempo / _duracion, 0.0, 1.0)
	var altura := sin(avance * PI) * minf(_origen.distance_to(_destino) * 0.4, ALTURA_MAXIMA)

	var marca := to_local(_destino)
	var aviso := Color(tipo.color.r, tipo.color.g, tipo.color.b, 0.35 + 0.45 * avance)
	draw_arc(marca, tipo.radio * 1.6 + RADIO_JUGADOR, 0.0, TAU, 28, aviso, 2.5, true)
	draw_circle(marca, (tipo.radio * 1.6 + RADIO_JUGADOR) * avance,
		Color(tipo.color_halo.r, tipo.color_halo.g, tipo.color_halo.b, 0.18))

	draw_circle(Vector2.ZERO, tipo.radio * (0.6 + 0.4 * avance), Color(0.0, 0.0, 0.0, 0.35))
	_pintar_bola(Vector2(0.0, -altura))
