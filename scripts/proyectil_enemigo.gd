## Proyectil de un enemigo: veneno, magma o rayo, segun su TipoProyectil.
##
## Se crea por codigo (ProyectilEnemigo.new()) y no desde una escena: todo lo
## que lo distingue sale del .tres, y una escena solo tendria una forma de
## colision que de todas formas hay que dimensionar aqui.
##
## Cuelga de la sala del enemigo que lo dispara, asi que se va con el piso.
##
## EN COOPERATIVO sale en todos los ordenadores (lo dispara el enemigo del
## anfitrion y MundoRed lo crea en los demas, con el mismo id_red), y cada uno
## mira si le da a SU jugador. Lo que solo pasa en uno se avisa a los demas:
## que ha rebotado en su escudo (avisar_cambio) o que le ha dado y se ha
## acabado (avisar_fin). Si no, en los otros seguiria de largo.
class_name ProyectilEnemigo
extends Area2D

## Al jugador lo detecta la propia area (capa 1). El terreno, muros y rocas,
## se mira a mano con Terreno: un Area2D no detecta los StaticBody2D. Las rocas
## lo paran igual que paran las bolas del jugador: son el parapeto de los dos.
const CAPA_JUGADOR: int = 1
## Capa de los enemigos (Enemigo.tscn). Solo la mira lo rebotado en el escudo.
const CAPA_ENEMIGOS: int = 32
## Lo que se separa del borde de la burbuja al rebotar, para quedar fuera.
const HOLGURA_ESCUDO: float = 1.0
## Lo mas rapido que sale un rebote, en veces su velocidad.
const RAQUETA_MAXIMA: float = 2.0
const MASCARA_TERRENO: int = Terreno.CAPA_MUROS | Terreno.CAPA_ROCAS
## Radio del jugador, para saber si la parabola le cae encima.
const RADIO_JUGADOR: float = 15.0
## Altura maxima del arco de la parabola, en pixeles de pantalla.
const ALTURA_MAXIMA: float = 150.0

var tipo: TipoProyectil = null
var direccion: Vector2 = Vector2.RIGHT
## px/s. La de su tipo, salvo despues de rebotar en la burbuja de un mago que
## anda hacia el: entonces sale mas rapido, como de una raqueta.
var _velocidad: float = 0.0
## Casilla de la sala, como en las bolas del jugador: lo que sale de ella se
## apaga, para que un disparo no cruce una puerta abierta.
var limite: Rect2 = Rect2()

var _recorrido: float = 0.0
var _fase: float = 0.0
var _acabado: bool = false
## True despues de rebotar en el escudo del mago blanco: ya no le hace dano
## (sale despedido lejos de el) ni vuelve a rebotar si cae encima, y ahora se
## lo hace a los enemigos que toque (pedido por Matias el 2026-10-15).
var _rebotado: bool = false
## Quien lo ha disparado (el nombre de su tipo de enemigo). Para el registro
## de partidas: el veneno lo tiran dos enemigos distintos.
var autor: String = ""
## Su numero en la red (cooperativo). -1 = jugando solo.
var id_red: int = -1
## Se ha acabado porque lo ha dicho otro ordenador: no hay que volver a avisar.
var _acabado_por_red: bool = false
## El jugador, para preguntarle si su escudo para el disparo.
var _jugador: Node = null
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
	_velocidad = tipo.velocidad
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
	_jugador = get_tree().get_first_node_in_group("jugador")


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

	var paso := _velocidad * delta
	var antes := global_position
	global_position += direccion * paso
	_recorrido += paso
	# El escudo del mago blanco, antes que nada: se mira aqui, recien movido,
	# y no al tocar al jugador, para que el disparo rebote en la burbuja y no
	# llegue a tocarle. La parabola no pasa por aqui: cae desde arriba (ver
	# _caer).
	if _jugador != null and _jugador.has_method("escudo_rebota"):
		# La burbuja va con el mago, que puede ir andando: el rebote se hace
		# con lo que se mueven el uno respecto al otro, como una pelota contra
		# una raqueta. Si no, al andar hacia un disparo que pasa de lado, este
		# rebotaba hacia donde el mago iba a seguir empujandolo y se quedaba
		# un rato resbalando por el borde, que se ve como pegado.
		var mueve: Vector2 = _jugador.velocity if _jugador is CharacterBody2D else Vector2.ZERO
		var relativa := direccion * _velocidad - mueve
		var normal: Vector2 = _jugador.escudo_rebota(antes, global_position, tipo.radio, relativa)
		if normal != Vector2.ZERO:
			_rebotado = true
			# Fuera de la burbuja, al borde. ANTES SE DEVOLVIA A DONDE ESTABA EN
			# EL PASO ANTERIOR, y eso lo dejaba pegado: si ese sitio ya quedaba
			# dentro (el mago andando hacia el, o la burbuja abriendose encima),
			# volvia a el en cada paso sin avanzar nunca.
			var centro: Vector2 = _jugador.escudo_centro()
			var fuera := EscudoBurbuja.RADIO + tipo.radio + HOLGURA_ESCUDO
			# Solo si se acercaba a la burbuja: uno que ya se aleja no se gira.
			if relativa.dot(normal) < 0.0:
				var sale := relativa.bounce(normal) + mueve
				direccion = sale.normalized() if sale.length() > 0.01 else normal
				# Y con la velocidad que le da el golpe: el mago blanco anda a
				# 265 y el veneno va a 300; a su velocidad de siempre apenas le
				# sacaba ventaja y la burbuja lo volvia a alcanzar. Nunca mas
				# lento que la suya.
				_velocidad = clampf(sale.length(), tipo.velocidad, tipo.velocidad * RAQUETA_MAXIMA)
				# Desde donde la toco.
				global_position = centro + normal * fuera
				MundoRed.avisar_cambio(self)
			elif global_position.distance_to(centro) < fuera:
				# Ya se alejaba: se le deja lo que ha avanzado y, si aun asi
				# sigue dentro, se saca por donde esta ahora. Con la normal del
				# sitio de antes perdia el paso entero y no salia nunca.
				var desde_centro := global_position - centro
				var hacia_fuera := desde_centro.normalized() if desde_centro.length() > 0.01 else normal
				global_position = centro + hacia_fuera * fuera
	if _rebotado and _golpear_enemigos(antes, global_position, tipo.radio):
		_acabar()
	elif Terreno.choque(get_world_2d(), antes, global_position, tipo.radio, MASCARA_TERRENO) != null:
		_acabar()
	elif _recorrido >= tipo.alcance:
		_acabar()
	elif limite.has_area() and not limite.has_point(global_position):
		_acabar()


func _al_tocar(cuerpo: Node2D) -> void:
	if _acabado or _rebotado:
		return
	# Por si acaso llega a tocarle con el escudo puesto (un disparo que nace
	# dentro de la burbuja): no hace dano y se deshace.
	if cuerpo.has_method("escudo_activo") and cuerpo.escudo_activo():
		_acabar()
		return
	if cuerpo.has_method("recibir_dano"):
		_golpear(cuerpo)
	_acabar()


func _golpear(jugador: Node2D) -> void:
	# El efecto solo si el golpe ha contado: durante la invulnerabilidad el
	# jugador no recibe nada, tampoco el veneno.
	if jugador.recibir_dano(tipo.dano, false, _origen_golpe()) and tipo.ralentiza > 0.0 \
			and jugador.has_method("envenenar"):
		jugador.envenenar(tipo.ralentiza, tipo.veneno_vida, _origen_golpe())


## La parabola llega al suelo: dano a quien este debajo y, si toca, el charco.
func _caer() -> void:
	var jugador := get_tree().get_first_node_in_group("jugador")
	# Cae sobre la burbuja del mago blanco: bota y cae un poco mas alla, fuera
	# de ella (con su charco, si lo deja). Una vez; la segunda cae donde sea.
	if not _rebotado and jugador != null and jugador.has_method("escudo_cubre") \
			and jugador.escudo_cubre(global_position, tipo.radio * 1.6):
		var centro: Vector2 = jugador.escudo_centro()
		var fuera := global_position - centro
		fuera = fuera.normalized() if fuera.length() > 1.0 else Vector2.DOWN
		_rebotado = true
		_origen = global_position
		_destino = centro + fuera * (EscudoBurbuja.RADIO + tipo.charco_radio + 40.0)
		_tiempo = 0.0
		_duracion = 0.35
		Sonido.tocar(&"escudo_golpe")
		MundoRed.avisar_cambio(self)
		return
	# Lo rebotado ya no es del enemigo: cae sobre los enemigos, no sobre el
	# mago.
	if _rebotado:
		_golpear_enemigos(global_position, global_position, tipo.radio * 1.6)
		_acabar()
		return
	if jugador != null and jugador.has_method("centro_colision") \
			and jugador.centro_colision().distance_to(global_position) \
				< tipo.radio * 1.6 + RADIO_JUGADOR \
			and not (jugador.has_method("escudo_activo") and jugador.escudo_activo()):
		_golpear(jugador)
	_acabar()


## Lo rebotado en el escudo le da al primer enemigo que toque entre 'desde' y
## 'hasta': le quita lo mismo que le habria quitado al mago. Tambien a quien
## lo tiro, y al jefe. Devuelve true si ha dado a alguno.
##
## Se pregunta al mundo a mano y no con la senal de la propia area: en el
## paso del rebote ya tiene que poder dar, y la senal llegaria un paso tarde.
## Se mira en varios puntos del tramo, como el escudo: el rayo va tan deprisa
## que podria saltar por encima de un enemigo pequeno.
func _golpear_enemigos(desde: Vector2, hasta: Vector2, radio: float) -> bool:
	var circulo := CircleShape2D.new()
	circulo.radius = radio
	var consulta := PhysicsShapeQueryParameters2D.new()
	consulta.shape = circulo
	consulta.collision_mask = CAPA_ENEMIGOS
	consulta.collide_with_areas = true
	consulta.collide_with_bodies = false
	var espacio := get_world_2d().direct_space_state
	var puntos := maxi(1, ceili(desde.distance_to(hasta) / maxf(radio, 1.0)))
	for k in range(1, puntos + 1):
		consulta.transform = Transform2D(0.0, desde.lerp(hasta, float(k) / puntos))
		for tocado: Dictionary in espacio.intersect_shape(consulta, 4):
			var enemigo := tocado.collider as Enemigo
			# Lo escondido (el fantasma desvanecido, la planta bajo tierra) no
			# se lleva el disparo, como con las bolas del mago.
			if enemigo != null and enemigo.es_tangible():
				enemigo.herir(float(tipo.dano))
				Sonido.tocar(&"golpe_enemigo")
				return true
	return false


## "Serpiente (veneno)": quien lo ha tirado y con que.
func _origen_golpe() -> String:
	if autor == "":
		return tipo.nombre
	return "%s (%s)" % [autor, tipo.nombre.to_lower()]


func _acabar() -> void:
	if _acabado:
		return
	_acabado = true
	# La parabola no: cae en el mismo sitio en todos, y cada uno tiene que
	# dejar su charco aunque otro haya caido antes.
	if not _acabado_por_red and tipo.estilo != TipoProyectil.Estilo.PARABOLA:
		MundoRed.avisar_fin(self)
	if tipo.charco_radio > 0.0 and get_parent() != null:
		var charco := Lava.new()
		charco.radio = tipo.charco_radio
		charco.duracion = tipo.charco_duracion
		charco.origen = "Charco de %s" % tipo.nombre.to_lower()
		if autor != "":
			charco.origen += " (%s)" % autor
		charco.position = get_parent().to_local(global_position)
		# Diferido: esto puede venir de body_entered, en mitad del paso de
		# fisica, y meter un Area2D nueva ahi hace quejarse al motor.
		get_parent().add_child.call_deferred(charco)
	queue_free()


# --- Cooperativo ---------------------------------------------------------------

## Como va ahora, para que los otros ordenadores lo pongan igual tras un
## rebote en el escudo.
func datos_red() -> Dictionary:
	if tipo.estilo == TipoProyectil.Estilo.PARABOLA:
		return {"origen": _origen, "destino": _destino, "duracion": _duracion,
			"rebotado": _rebotado}
	return {"posicion": global_position, "direccion": direccion, "velocidad": _velocidad,
		"rebotado": _rebotado}


func cambiar_red(datos: Dictionary) -> void:
	if _acabado:
		return
	_rebotado = datos.get("rebotado", _rebotado)
	if datos.has("destino"):
		_origen = datos.origen
		_destino = datos.destino
		_duracion = datos.duracion
		_tiempo = 0.0
		global_position = _origen
	else:
		global_position = datos.posicion
		direccion = datos.direccion
		_velocidad = datos.velocidad


## Otro ordenador dice que se ha acabado (le ha dado a su jugador). Se va sin
## mas: sin charco y sin volver a avisar.
func terminar_red() -> void:
	if _acabado or tipo.estilo == TipoProyectil.Estilo.PARABOLA:
		return
	_acabado_por_red = true
	_acabado = true
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
