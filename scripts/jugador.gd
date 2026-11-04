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
## Cada golpe que quita vida: cuanta y quien lo ha dado ("Rata", "Lava"...).
## Lo apunta el registro de partidas (RegistroPartida). Va aparte de
## dano_recibido porque a esa la escucha la camara con un valor ya atado, y un
## argumento mas se lo descolocaria.
signal golpeado(cantidad: int, origen: String)
## Cada punto que quita el veneno mientras dura. Va aparte de golpeado porque
## no es un golpe: ni tiembla la camara, ni parpadea, ni suena, y el registro
## no lo cuenta como un golpe mas de la pelea.
signal veneno_quita(cantidad: int, origen: String)
## Cada golpe de la quemadura (el aliento de fuego del jefe). Como el veneno,
## aparte de golpeado: no es un golpe, va poco a poco.
signal quemadura_quita(cantidad: int, origen: String)
signal sin_vida
## Se emite en cada disparo, con el punto de salida, hacia donde va y si es el
## ataque cargado. Va en la misma senal y no en otra aparte porque quien la
## escucha hace lo mismo en los dos casos: crear una bola, con otros numeros.
signal bola_lanzada(desde: Vector2, direccion: Vector2, cargada: bool)
## El ataque especial del mago verde: los proyectiles de veneno, que salen
## todos a la vez alrededor del mago. Aparte de bola_lanzada porque no es una
## bola con otros numeros: son varias, y cada una se mueve sola.
signal veneno_lanzado(desde: Vector2, direccion: Vector2)
## Ha cambiado el arma o su modo, para que el HUD lo diga. Con null, sin arma.
signal modo_arma_cambiado(arma: ArmaMago, modo: ModoArma)
## Se emite al recoger un objeto, para que el HUD lo anuncie.
signal mejora_recogida(mejora: ObjetoMejora)
## Se emite al gastar el ataque especial y al recuperarlo en el piso
## siguiente, para que el HUD diga si queda.
signal especial_cambiado(disponible: bool)
## Se emite al acabar de caer por un agujero. Principal lo devuelve a la
## entrada de la sala: el jugador no sabe donde esta eso, el piso si.
signal caido

@export_group("Movimiento")
## Velocidad punta en px/s.
@export var velocidad_maxima: float = 265.0
## Cuanto cuesta arrancar (px/s^2). Mas alto = respuesta mas inmediata.
@export var aceleracion: float = 2400.0
## Cuanto cuesta parar (px/s^2). Mas alto = frenada mas seca.
@export var friccion: float = 2800.0

@export_group("Vida")
@export var vida_maxima: int = 100
## Segundos de invulnerabilidad tras un golpe. Evita perder toda la vida de
## golpe cuando el jugador se queda encima de un obstaculo.
@export var duracion_invulnerabilidad: float = 1.1

@export_group("Disparo")
## Segundos entre disparo y disparo. Es la cadencia: mas bajo, mas rapido.
## Medio segundo desde el 2026-10-09 (pedido por Matias; antes 0,34): que cada
## bola cuente y no sea una rafaga constante. Los objetos que hacen disparar
## mas seguido la siguen bajando durante la partida.
@export var cadencia_disparo: float = 0.5
## Velocidad de las bolas. La lee Principal al crearlas.
@export var velocidad_bola: float = 620.0
## Radio de las bolas. Tambien lo lee Principal.
@export var radio_bola: float = 11.0

@export_group("Ataque cargado")
## Segundos que hay que mantener el boton derecho antes de poder soltarlo.
@export var tiempo_carga: float = 0.75
## Dano del disparo cargado. El normal hace 1. Con 3 mata de una a todos los
## enemigos menos al golem, que aguanta 5 (el del mago rojo, con +2, tambien a
## ese).
@export var dano_bola_cargada: int = 30
## Lo grande y lo rapida que sale respecto al disparo normal.
@export var factor_radio_cargada: float = 2.1
@export var factor_velocidad_cargada: float = 1.3

@export_group("Colores del disparo")
## Los pone el mago elegido. Los lee Principal al crear cada bola.
@export var color_disparo: Color = Color(0.62, 0.84, 1.0)
@export var halo_disparo: Color = Color(0.35, 0.60, 1.0)
@export var color_cargado: Color = Color(0.72, 0.52, 1.0)
@export var halo_cargado: Color = Color(0.52, 0.28, 0.95)

## Lo que quita y lo que frena cada bola normal. Son del mago (los pone
## usar_personaje) y ningun objeto los cambia. Ver PersonajeJugable.
var dano_disparo: float = 10.0
var frena_disparo: float = 0.0
## El escudo direccional, si es el ataque especial del mago. Si no, null, y
## el especial es la bola cargada.
var _escudo: EscudoBurbuja = null
## El mago con el que se juega. Principal mira aqui lo que es solo de un mago
## y no del jugador en general (el agujero negro de su bola cargada).
var mago: PersonajeJugable = null
## El arma que lleva puesta (el gacha de diamantes, ver ArmaMago) y en que modo.
## Se ponen, con la skin, al estrenar mago (_ponerse_coleccion).
var arma: ArmaMago = null
var modo_arma: int = 0
var _arma_flotante: ArmaFlotante = null
var _aura: AuraSkin = null
## Si queda el ataque especial en este piso. Se gasta al soltar la bola
## cargada o sacar el escudo, y vuelve al llegar al piso siguiente.
##
## POR QUE UNA VEZ POR PISO (pedido por Matias, 2026-10-09): asi el especial
## es una decision, no algo que se tira cada vez que se puede. Hay que
## guardarlo para la sala que lo merece.
var especial_disponible: bool = true

## Tope de cadencia: por debajo de esto el disparo se vuelve una manguera y el
## juego deja de tener tension. Es el de un mago que dispara cada medio
## segundo; el que dispara mas seguido (el rocio del mago verde, 9 veces mas)
## tiene el tope igual de mas bajo (_cadencia_minima): si no, el suyo ya
## empezaria por debajo y ningun objeto de cadencia le serviria de nada.
const CADENCIA_MINIMA: float = 0.09
var _cadencia_minima: float = CADENCIA_MINIMA

## Por debajo de esta velocidad se considera que el personaje esta parado y se
## pasa a la animacion de reposo. No es 0 porque la friccion deja residuos.
const VELOCIDAD_MINIMA_ANDAR: float = 12.0

## Envenenado se va a esta fraccion de la velocidad. Frenar es lo que mas
## pesa del veneno: te deja a tiro del siguiente. Desde el 2026-10-14 (Matias)
## ademas quita un poco de vida mientras dura (TipoProyectil.veneno_vida).
const FACTOR_VENENO: float = 0.6
## Lo que va con frio (la trampa de hielo): a la mitad, como los enemigos que
## frena el disparo del mago blanco (Enemigo.RITMO_FRENADO).
const FACTOR_FRIO: float = 0.5
const COLOR_VENENO := Color(0.6, 1.0, 0.55)
## Lo que tarda la animacion de caer por un agujero.
const DURACION_CAIDA: float = 0.4
## Lo que cuesta caerse.
const DANO_CAIDA: int = 30

## Las ocho direcciones del mago, en el orden de los sectores de 45 grados que
## devuelve Vector2.angle(): empieza en la derecha y gira en el sentido de las
## agujas del reloj, porque en pantalla la y crece hacia abajo.
const LADOS: Array[StringName] = [
	&"derecha", &"abajo_derecha", &"abajo", &"abajo_izquierda",
	&"izquierda", &"arriba_izquierda", &"arriba", &"arriba_derecha",
]

var vida_actual: int = 0
## Ningun golpe quita vida, ni la caida. Solo lo enciende el atajo de prueba
## F1 (AtajosPrueba), que no existe en el .exe: sirve para ver los pisos de
## abajo sin morir por el camino.
var invencible: bool = false
## La sala en la que esta: la pone Principal al cambiar de sala. La usa el
## disparo automatico para buscar a quien apuntar.
var sala_actual: Sala = null

## Valores de fabrica, para poder devolver al jugador a como empezo cuando se
## empieza una partida nueva. Las mejoras se acumulan durante toda la partida,
## asi que sin esto la siguiente empezaria con las de la anterior.
var _base_vida_maxima: int = 0
var _base_velocidad: float = 0.0
var _base_cadencia: float = 0.0
var _base_velocidad_bola: float = 0.0
var _base_radio_bola: float = 0.0

## Los valores de la escena, sin mago ni mejoras. Hacen falta aparte de los de
## fabrica porque la ventaja del mago se calcula desde aqui: si se sumara a los
## de fabrica, cada reinicio (que vuelve a llamar a usar_personaje) la sumaria
## otra vez. Paso: tres reinicios dejaban al mago rojo con 7 corazones y una
## carga de 0,05 s.
var _escena_vida_maxima: int = 0
var _escena_velocidad: float = 0.0
var _escena_cadencia: float = 0.0
var _escena_velocidad_bola: float = 0.0
var _escena_radio_bola: float = 0.0
var _escena_tiempo_carga: float = 0.0
var _escena_dano_cargado: int = 0

## Tiempo que queda de invulnerabilidad. > 0 significa invulnerable.
var _tiempo_invulnerable: float = 0.0
## Controla el parpadeo durante la invulnerabilidad.
var _fase_parpadeo: float = 0.0
## Mientras es false el jugador no responde a los controles (cambios de piso).
var _control_activo: bool = true
## Cuanto falta para poder volver a disparar.
var _espera_disparo: float = 0.0
## Segundos que se lleva cargando el ataque. 0 = no se esta cargando.
var _carga: float = 0.0
## True mientras el boton derecho esta pulsado. Lo miran el disparo normal (que
## se calla mientras cargas) y la animacion (para mirar a donde cargas).
var _cargando: bool = false
## True si el ataque especial se esta cargando con el espacio y no con el
## raton: entonces sale hacia las flechas o hacia donde mira el mago (ver
## _direccion_especial).
var _especial_por_teclado: bool = false

## Direccion a la que mira el sprite: "abajo", "izquierda", "derecha", "arriba".
## Se guarda en vez de recalcularse cada vez porque, al soltar los controles, el
## mago tiene que quedarse mirando a donde estaba, no volver a una por defecto.
var _mirando: StringName = &"abajo"

## Segundos que le quedan envenenado (frenado). 0 = sano.
var _tiempo_veneno: float = 0.0
## Lo que le queda de frio (TrampaHielo). Con frio va a FACTOR_FRIO, anima a
## esa velocidad, se tiñe de Escarcha.COLOR y lleva la escarcha a los pies.
var _tiempo_frio: float = 0.0
var _escarcha: Node2D = null
## La quemadura (Jugador.quemar): lo que le queda, cada cuanto quita, lo que
## quita y de donde viene, y las llamas a los pies.
var _quemadura: float = 0.0
var _quemadura_reloj: float = 0.0
var _quemadura_dano: int = 0
var _quemadura_origen: String = ""
var _llamas: Node2D = null
## Cada cuanto quita la quemadura: como la del mago rojo a los enemigos.
const TIC_QUEMADURA: float = 0.5
## Los puntos de vida que le quedan por quitar al veneno, cada cuanto quita
## uno, lo que falta para el siguiente y quien lo tiro (para el registro).
var _veneno_quedan: int = 0
var _veneno_cada: float = 0.0
var _veneno_reloj: float = 0.0
var _veneno_origen: String = ""
## True mientras cae por un agujero: sin control y sin recibir golpes, que ya
## le va a costar un corazon la caida.
var _cayendo: bool = false
var _animacion_caida: Tween = null
## Escala del sprite en la escena, para devolverla despues de caer.
var _escala_sprite: Vector2 = Vector2.ONE

## El sprite se escala y se desplaza desde la escena, no desde aqui: el origen
## del nodo esta a los pies del personaje y la forma de colision cubre la base
## de la tunica. Asi, en vista cenital, lo que choca es la "huella" en el suelo y no
## la cabeza, que es lo que espera el jugador.
@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _carga_visual: CargaAtaque = $Carga


## Deja al jugador siendo el mago elegido: su arte y su ventaja.
##
## La ventaja se mete en los valores DE FABRICA y no como una mejora recogida,
## porque restaurar_vida() vuelve a esos valores al empezar otra partida: si se
## aplicara como un objeto del piso, el mago perderia lo suyo al reiniciar.
func usar_personaje(personaje: PersonajeJugable) -> void:
	if personaje == null:
		return

	mago = personaje
	if personaje.animaciones != null:
		_sprite.sprite_frames = personaje.animaciones

	color_disparo = personaje.color_disparo
	halo_disparo = personaje.halo_disparo
	color_cargado = personaje.color_cargado
	halo_cargado = personaje.halo_cargado
	_carga_visual.pintar_con(color_cargado, halo_cargado)
	_carga_visual.usar_arte(personaje.arte_especial)

	# Siempre desde los valores de la escena, nunca desde los de ahora: asi
	# llamarla dos veces con el mismo mago deja al jugador igual.
	_base_vida_maxima = _escena_vida_maxima + personaje.vida_maxima_extra
	_base_velocidad = _escena_velocidad + personaje.velocidad_extra
	_cadencia_minima = CADENCIA_MINIMA * minf(personaje.cadencia_multiplicador, 1.0)
	_base_cadencia = maxf(_escena_cadencia * personaje.cadencia_multiplicador,
		_cadencia_minima)
	_base_velocidad_bola = _escena_velocidad_bola + personaje.velocidad_bola_extra
	_base_radio_bola = _escena_radio_bola + personaje.radio_bola_extra

	tiempo_carga = _escena_tiempo_carga * personaje.tiempo_carga_multiplicador
	dano_bola_cargada = _escena_dano_cargado + personaje.dano_cargado_extra
	dano_disparo = personaje.dano_disparo
	frena_disparo = personaje.frena_disparo

	# El escudo va con el mago: se pone o se quita al estrenarlo, y no se
	# duplica si se vuelve a llamar con el mismo (cada reinicio lo hace).
	var con_escudo := personaje.ataque_especial == PersonajeJugable.ESPECIAL_ESCUDO
	if con_escudo and _escudo == null:
		_escudo = EscudoBurbuja.new(self)
		add_child(_escudo)
	elif not con_escudo and _escudo != null:
		_escudo.queue_free()
		_escudo = null
	if _escudo != null:
		_escudo.duracion = personaje.duracion_escudo
		_escudo.usar_arte(personaje.arte_especial)

	# restaurar_vida() es lo que copia los valores de fabrica a los de verdad,
	# asi que sirve igual para "empezar de cero" que para "estrenar mago".
	restaurar_vida()
	_ponerse_coleccion(personaje)


## La skin de ese mago y el arma, lo que se haya elegido en el gacha (Coleccion).
func _ponerse_coleccion(personaje: PersonajeJugable) -> void:
	var skin := Coleccion.skin_puesta(personaje.nombre)
	if skin != null:
		_sprite.sprite_frames = skin.animaciones
	if _aura != null:
		_aura.queue_free()
		_aura = null
	if skin != null and skin.aura.a > 0.0:
		_aura = AuraSkin.new(skin)
		add_child(_aura)
		# La primera: por debajo de su dibujo.
		move_child(_aura, 0)
		_poner_de_pie()
	arma = Coleccion.arma_puesta()
	modo_arma = 0
	if _arma_flotante != null:
		_arma_flotante.queue_free()
		_arma_flotante = null
	if arma != null:
		_arma_flotante = ArmaFlotante.new(arma)
		add_child(_arma_flotante)
	modo_arma_cambiado.emit(arma, modo_actual())


## La forma de disparar de ahora, o null sin arma.
func modo_actual() -> ModoArma:
	return arma.modos[modo_arma] if arma != null else null


## Pasa al modo siguiente (o al anterior) de un arma con varios: las miticas.
func cambiar_modo_arma(paso: int = 1) -> void:
	if arma == null or not arma.tiene_modos():
		return
	modo_arma = posmod(modo_arma + paso, arma.modos.size())
	Sonido.tocar(&"clic")
	modo_arma_cambiado.emit(arma, modo_actual())


## La rueda del raton cambia de modo, y la tecla Q para quien juega sin el.
func _unhandled_input(evento: InputEvent) -> void:
	if not _control_activo or arma == null or not arma.tiene_modos():
		return
	var boton := evento as InputEventMouseButton
	if boton != null and boton.pressed and boton.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		cambiar_modo_arma(1 if boton.button_index == MOUSE_BUTTON_WHEEL_UP else -1)
		get_viewport().set_input_as_handled()
	elif evento.is_action_pressed("cambiar_modo_arma"):
		cambiar_modo_arma()
		get_viewport().set_input_as_handled()


func _ready() -> void:
	_escala_sprite = _sprite.scale
	_escena_vida_maxima = vida_maxima
	_escena_velocidad = velocidad_maxima
	_escena_cadencia = cadencia_disparo
	_escena_velocidad_bola = velocidad_bola
	_escena_radio_bola = radio_bola
	_escena_tiempo_carga = tiempo_carga
	_escena_dano_cargado = dano_bola_cargada

	_base_vida_maxima = vida_maxima
	_base_velocidad = velocidad_maxima
	_base_cadencia = cadencia_disparo
	_base_velocidad_bola = velocidad_bola
	_base_radio_bola = radio_bola

	vida_actual = vida_maxima
	vida_cambiada.emit(vida_actual, vida_maxima)
	Vista.cambiada.connect(_poner_de_pie.unbind(1))
	_poner_de_pie()


## Con la vista girada (el movil en vertical, ver Vista), el dibujo del mago
## y lo que lleva a los pies (llamas, escarcha) se giran al reves para seguir
## de pie en la pantalla. Alrededor del circulo con el que choca, no de los
## pies: asi donde le dan sigue estando donde se le ve. El mago en si no gira:
## su circulo esta 16 px por encima de los pies, y girandolo se moveria.
func _poner_de_pie() -> void:
	var centro: Vector2 = $Forma.position
	for nodo in [_sprite, _llamas, _escarcha, _aura]:
		if nodo != null:
			Vista.poner_de_pie(nodo, Vector2.ZERO, centro)


func _physics_process(delta: float) -> void:
	_actualizar_estados(delta)

	var direccion := Vector2.ZERO
	if _control_activo:
		# Input.get_vector ya normaliza: nada de ir mas rapido en diagonal.
		direccion = Input.get_vector(
			"mover_izquierda", "mover_derecha", "mover_arriba", "mover_abajo")
		# En el movil, el joystick de la izquierda: con lo que se aparta del
		# centro, se anda mas o menos deprisa.
		if ControlesTactiles.movimiento != Vector2.ZERO:
			direccion = ControlesTactiles.movimiento
		# Arriba en la pantalla es arriba aunque la vista este girada (Vista).
		direccion = Vista.en_mundo(direccion)

	if direccion != Vector2.ZERO:
		var punta := velocidad_maxima * (FACTOR_VENENO if esta_envenenado() else 1.0) \
			* (FACTOR_FRIO if tiene_frio() else 1.0)
		velocity = velocity.move_toward(direccion * punta, aceleracion * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friccion * delta)

	move_and_slide()
	# La carga va antes de la animacion para que el mago mire ya hacia donde
	# esta cargando, y antes del disparo normal, que se calla mientras cargas.
	_actualizar_carga(delta)
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

	# Cargando, el mago mira hacia donde va a soltar el ataque.
	if _cargando:
		return _direccion_especial()

	# En el movil, el joystick de la derecha: apunta libre, como el raton.
	if ControlesTactiles.apuntado != Vector2.ZERO:
		return Vista.en_mundo(ControlesTactiles.apuntado).normalized()

	# El raton manda sobre las flechas: si estas apuntando, es lo que quieres.
	# Con el raton se apunta libre, en cualquier angulo; con las flechas solo a
	# las cuatro direcciones, que es el esquema clasico de teclado. Con los
	# mandos del movil, no: cada dedo que toca la pantalla hace tambien de
	# clic izquierdo, y el mago dispararia hacia el pulgar con el que anda.
	if Input.is_action_pressed("disparar_raton") and not ControlesTactiles.activos:
		return _direccion_raton()

	var flechas := _direccion_flechas()
	if flechas != Vector2.ZERO or not Controles.disparo_automatico:
		return flechas
	return _direccion_automatica()


## El disparo automatico (Controles.disparo_automatico): hacia el enemigo mas
## cercano de la sala en la que esta el mago, antes los que tiene a tiro (sin
## roca ni muro en medio). ZERO si no queda ninguno: entonces no dispara.
## Apuntar tu (raton o teclas) manda sobre esto.
func _direccion_automatica() -> Vector2:
	if not is_instance_valid(sala_actual):
		return Vector2.ZERO
	var desde := centro_colision()
	var espacio := get_world_2d().direct_space_state
	var mejor := Vector2.ZERO
	var mejor_distancia := INF
	var mejor_a_tiro := false
	for enemigo in sala_actual.enemigos():
		if not is_instance_valid(enemigo) or enemigo.is_queued_for_deletion() \
				or not enemigo.visible or not enemigo.es_tangible() or enemigo.fraccion_vida() <= 0.0:
			continue
		var punto := enemigo.global_position
		var distancia := desde.distance_to(punto)
		var rayo := PhysicsRayQueryParameters2D.create(desde, punto,
			Terreno.CAPA_MUROS | Terreno.CAPA_ROCAS)
		var a_tiro := espacio.intersect_ray(rayo).is_empty()
		if (a_tiro and not mejor_a_tiro) or (a_tiro == mejor_a_tiro and distancia < mejor_distancia):
			mejor = punto
			mejor_distancia = distancia
			mejor_a_tiro = a_tiro
	if mejor_distancia == INF or mejor_distancia < 1.0:
		return Vector2.ZERO
	return (mejor - desde).normalized()


## Hacia donde apuntan las flechas, en cuatro direcciones; ZERO si no se pulsa
## ninguna.
func _direccion_flechas() -> Vector2:
	var flechas := Input.get_vector(
		"disparar_izquierda", "disparar_derecha", "disparar_arriba", "disparar_abajo")
	if flechas == Vector2.ZERO:
		return Vector2.ZERO
	# Con dos flechas a la vez manda la mas marcada: las diagonales harian el
	# disparo de teclado mas facil de lo que toca.
	if absf(flechas.x) > absf(flechas.y):
		return Vista.en_mundo(Vector2(signf(flechas.x), 0.0))
	return Vista.en_mundo(Vector2(0.0, signf(flechas.y)))


## Hacia donde sale el ataque especial (y hacia donde mira el mago mientras
## carga).
##
## Con el clic derecho, hacia el raton. Con el espacio, hacia donde apuntan
## las flechas o, sin ninguna pulsada, hacia donde mira el mago: el espacio es
## para quien juega sin raton, con las flechas, y el raton no puede mandar.
## Con la flecha de abajo sale hacia abajo aunque el cursor este encima del
## mago (Matias, 2026-10-09).
##
## En el movil, el boton del especial es tambien un joystick: hacia donde se
## arrastra (ControlesTactiles.especial).
func _direccion_especial() -> Vector2:
	if not _especial_por_teclado:
		return _direccion_raton()
	if ControlesTactiles.especial != Vector2.ZERO:
		return Vista.en_mundo(ControlesTactiles.especial).normalized()
	var flechas := _direccion_flechas()
	return flechas if flechas != Vector2.ZERO else _vector_de(_mirando)


## True mientras se mantiene el ataque especial, con el raton o con el
## espacio.
func _especial_pulsado() -> bool:
	return Input.is_action_pressed("cargar_ataque") \
		or Input.is_action_pressed("cargar_ataque_teclado")


## Del mago al cursor. Si el raton esta justo encima, no hay direccion fiable,
## asi que se tira de la ultima a la que miraba: soltar el ataque hacia un lado
## al azar seria peor que soltarlo hacia donde ya estabas mirando.
func _direccion_raton() -> Vector2:
	var hacia := get_global_mouse_position() - centro_colision()
	if hacia.length() > 1.0:
		return hacia.normalized()
	return _vector_de(_mirando)


## Ataque cargado: se mantiene el boton derecho y se suelta cuando esta listo.
##
## POR QUE HAY QUE SOLTARLO Y NO SALE SOLO AL CARGARSE:
## soltandolo tu, eliges el momento y puedes reapuntar mientras cargas. Si
## saliera solo, cargar seria una cuenta atras a la que llegas apuntando a
## donde sea. Si quieres que salga solo, es una linea: lanzar en cuanto
## _carga >= tiempo_carga en vez de esperar a que se suelte el boton.
##
## POR QUE SOLTARLO ANTES DE TIEMPO NO DISPARA NADA:
## un disparo flojo por soltar pronto se confundiria con el disparo normal y no
## se sabria nunca por que ha salido una cosa u otra. Asi la regla es una: o
## esta cargado o no hay ataque.
func _actualizar_carga(delta: float) -> void:
	if not _control_activo:
		_cancelar_carga()
		return

	# Ya usado en este piso: ni se carga ni sale nada hasta el siguiente.
	if not especial_disponible:
		_cancelar_carga()
		return

	# El mago verde tampoco carga: al pulsar salen sus proyectiles de veneno,
	# alrededor de el, empezando por hacia donde apunta.
	if mago != null and mago.ataque_especial == PersonajeJugable.ESPECIAL_VENENO:
		var teclado := Input.is_action_just_pressed("cargar_ataque_teclado")
		if Input.is_action_just_pressed("cargar_ataque") or teclado:
			_especial_por_teclado = teclado
			veneno_lanzado.emit(centro_colision(), _direccion_especial())
			_gastar_especial()
		return

	# El mago del escudo no carga nada: el mismo boton lo saca. Al pulsar y
	# no al mantener, para que sacarlo sea siempre algo que se decide.
	if _escudo != null:
		var pulsado := Input.is_action_just_pressed("cargar_ataque") \
			or Input.is_action_just_pressed("cargar_ataque_teclado")
		if pulsado and _escudo.levantar():
			_gastar_especial()
			Sonido.tocar(&"escudo")
		return

	if _especial_pulsado():
		# Con que se carga decide hacia donde sale. Con los dos a la vez manda
		# el espacio: quien lo pulsa esta jugando con el teclado.
		_especial_por_teclado = Input.is_action_pressed("cargar_ataque_teclado")
		_cargando = true
		var antes := _carga
		_carga = minf(_carga + delta, tiempo_carga)
		# Al cerrarse el aro, un brillo: ya se puede soltar sin mirarlo.
		if antes < tiempo_carga and _carga >= tiempo_carga:
			Sonido.tocar(&"carga_lista")
		_carga_visual.actualizar(_carga / tiempo_carga, _direccion_especial())
		return

	# Se ha soltado el boton (o no estaba pulsado). Sale hacia donde se
	# apuntaba con lo ultimo que se cargo.
	if _cargando and _carga >= tiempo_carga:
		bola_lanzada.emit(centro_colision(), _direccion_especial(), true)
		_gastar_especial()
	_cancelar_carga()


func _gastar_especial() -> void:
	especial_disponible = false
	especial_cambiado.emit(false)


## Vuelve a dejar el ataque especial disponible. Al llegar a un piso, al
## empezar partida y con el atajo de prueba F5.
func recargar_especial() -> void:
	especial_disponible = true
	especial_cambiado.emit(true)


func _cancelar_carga() -> void:
	_cargando = false
	_carga = 0.0
	_carga_visual.apagar()


## Dispara mientras se mantenga pulsado, con una cadencia fija.
##
## Lo que se pasa de la espera en el paso en que toca disparar se le descuenta
## a la siguiente. Con el rocio del mago verde (un disparo cada 0,056 s) hace
## falta: cada disparo esperaba al paso de fisica siguiente entero y salian 15
## por segundo en vez de 18. Sin disparar, la espera se queda en 0: no se
## guardan disparos para luego.
func _actualizar_disparo(delta: float) -> void:
	_espera_disparo -= delta
	if _espera_disparo > 0.0:
		return

	# Mientras cargas no sale el disparo normal: estas canalizando, y si salieran
	# los dos a la vez no se sabria cual ha matado a que.
	var direccion := Vector2.ZERO
	if _control_activo and not _cargando:
		direccion = _direccion_apuntada()
	if direccion == Vector2.ZERO:
		_espera_disparo = 0.0
		return

	_espera_disparo += _cadencia_con_arma()
	# Sale del centro del cuerpo y no de los pies, para que se vea nacer del
	# personaje y no del suelo.
	bola_lanzada.emit(centro_colision(), direccion, false)


## El tiempo entre disparos. Un arma que dispara a su manera parte del de un mago
## normal: quita la cadencia del mago, para que el rocio del verde (9 veces mas
## rapido, y por eso 10 veces mas flojo) no multiplique las bolas del arma. Lo de
## los objetos se queda.
func _cadencia_con_arma() -> float:
	if arma == null or arma.solo_aspecto():
		return cadencia_disparo
	var del_mago := mago.cadencia_multiplicador if mago != null else 1.0
	return cadencia_disparo / del_mago * modo_actual().cadencia


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
	if _arma_flotante != null:
		_arma_flotante.apuntar(apuntando if apuntando != Vector2.ZERO else _vector_de(_mirando))

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


## Lo contrario de _lado(): del nombre de la direccion al vector que la
## representa. Si el nombre no existe, se mira hacia abajo, que es como empieza
## cada piso.
##
## Los nombres son de la pantalla (el dibujo que se ve), y el vector, del
## mundo: con la vista girada (movil en vertical), "abajo" es hacia donde se
## ve abajo, no el abajo de la sala.
func _vector_de(lado: StringName) -> Vector2:
	var sector := LADOS.find(lado)
	if sector < 0:
		return Vista.en_mundo(Vector2.DOWN)
	return Vista.en_mundo(Vector2.RIGHT.rotated(sector * TAU / 8.0))


## Traduce un vector a una de las ocho direcciones del mago.
##
## POR QUE POR ANGULO Y NO COMPARANDO x CONTRA y:
## con cuatro direcciones bastaba un if; con ocho, la misma idea se convierte en
## una escalera de comparaciones que no se lee ni se comprueba. Redondear el
## angulo al sector de 45 grados mas cercano es la misma regla escrita una vez.
func _lado(v: Vector2) -> StringName:
	v = Vista.en_pantalla(v)
	return LADOS[posmod(int(roundf(v.angle() / (TAU / 8.0))), 8)]


## Invulnerabilidad y veneno: cuentan hacia atras y deciden el color.
func _actualizar_estados(delta: float) -> void:
	_tiempo_veneno = maxf(_tiempo_veneno - delta, 0.0)
	_actualizar_veneno(delta)
	_actualizar_frio(delta)
	_actualizar_quemadura(delta)
	if _tiempo_invulnerable <= 0.0:
		_sprite.modulate = _color_normal()
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
		_sprite.modulate = _color_normal()


## Verde mientras dura el veneno: si vas lento, que se vea por que.
func _color_normal() -> Color:
	return COLOR_VENENO if esta_envenenado() else Color.WHITE


## Aplica dano. Devuelve true solo si el golpe ha contado (util para que el
## obstaculo decida si reproducir efectos). Si esta invulnerable, se ignora.
##
## 'forzar' se salta la invulnerabilidad. Solo lo usa la caida: caerse tiene
## que costar siempre, o caer justo despues de un golpe saldria gratis.
## 'origen' dice quien lo da, para el registro de partidas: el nombre del
## enemigo, del peligro o del disparo. Vacio si no se sabe.
func recibir_dano(cantidad: int = 1, forzar: bool = false, origen: String = "") -> bool:
	if vida_actual <= 0 or invencible:
		return false
	if not forzar and (esta_invulnerable() or _cayendo):
		return false

	# Lo que quita de verdad: con 10 de vida, un golpe de 30 quita 10.
	var quitada := mini(cantidad, vida_actual)
	vida_actual -= quitada
	_tiempo_invulnerable = duracion_invulnerabilidad
	dano_recibido.emit()
	Sonido.tocar(&"herido")
	vida_cambiada.emit(vida_actual, vida_maxima)
	# Antes que sin_vida: el registro tiene que saber que golpe ha matado
	# antes de enterarse de que la partida se ha perdido.
	golpeado.emit(quitada, origen)

	if vida_actual == 0:
		_control_activo = false
		velocity = Vector2.ZERO
		sin_vida.emit()
	return true


## Hacia donde mira el mago, como vector: hacia donde apunta o, si no apunta,
## hacia donde anda. La usa el escudo para encararse.
func direccion_mirada() -> Vector2:
	return _vector_de(_mirando)


## Si el escudo hace rebotar algo de 'radio' que ha ido de 'desde' a 'hasta'
## en este paso, yendo hacia 'direccion', la normal del rebote; si no,
## Vector2.ZERO. Lo preguntan los proyectiles enemigos; sin escudo, nunca.
func escudo_rebota(desde: Vector2, hasta: Vector2, radio: float, direccion: Vector2) -> Vector2:
	if _escudo == null:
		return Vector2.ZERO
	return _escudo.rebota(desde, hasta, radio, direccion)


## True mientras el escudo esta levantado. Mientras, nada de lo que lanzan los
## enemigos (contacto, explosiones, ondas) le quita vida; lo comprueba quien
## hace el dano, antes de hacerlo.
func escudo_activo() -> bool:
	return _escudo != null and _escudo.activo()


## Si un punto con su radio cae dentro del escudo. El magma, que cae desde
## arriba, lo pregunta al llegar al suelo.
func escudo_cubre(punto: Vector2, radio: float) -> bool:
	return _escudo != null and _escudo.cubre(punto, radio)


## Centro del escudo en el mundo: desde donde rebota lo que cae encima.
func escudo_centro() -> Vector2:
	return _escudo.global_position if _escudo != null else centro_colision()


## Centro real de la forma de colision, que NO es el origen del nodo: el origen
## esta a los pies y el circulo esta mas arriba, sobre la base de la tunica.
## Lo usan los obstaculos para comprobar si un impacto es de verdad.
func centro_colision() -> Vector2:
	return $Forma.global_position


## Cura sin pasar del maximo. Devuelve false si no ha curado nada (con la
## vida llena).
func curar(cantidad: int) -> bool:
	if vida_actual <= 0 or vida_actual >= vida_maxima or _cayendo:
		return false
	vida_actual = mini(vida_actual + cantidad, vida_maxima)
	vida_cambiada.emit(vida_actual, vida_maxima)
	return true


## Aplica un objeto recogido. Las mejoras se suman y duran toda la partida.
func aplicar_mejora(mejora: ObjetoMejora) -> void:
	if mejora == null:
		return

	vida_maxima += mejora.vida_maxima_extra
	# La vida maxima de mas viene llena, y ademas se cura lo que diga el objeto.
	vida_actual = mini(vida_actual + mejora.vida_maxima_extra + mejora.cura, vida_maxima)

	velocidad_maxima += mejora.velocidad_extra
	cadencia_disparo = maxf(cadencia_disparo * mejora.cadencia_multiplicador,
		_cadencia_minima)
	velocidad_bola += mejora.velocidad_bola_extra
	radio_bola += mejora.radio_bola_extra

	vida_cambiada.emit(vida_actual, vida_maxima)
	mejora_recogida.emit(mejora)


## Al pausar se tira la carga. Si no, soltar el boton durante la pausa haria
## salir el ataque cargado nada mas continuar, hacia donde estuviera el raton
## al pulsar "Continuar", que no es donde apuntabas.
func _notification(que: int) -> void:
	if que == NOTIFICATION_PAUSED:
		_cancelar_carga()


## Lo frena un rato y, si 'vida' > 0, le quita esa vida de punto en punto
## mientras dura. Lo llama el proyectil de veneno al acertar. No se suma: un
## segundo veneno reinicia la cuenta, no la alarga ni quita el doble.
func envenenar(segundos: float, vida: int = 0, origen: String = "") -> void:
	_tiempo_veneno = maxf(_tiempo_veneno, segundos)
	if vida <= 0 or segundos <= 0.0:
		return
	_veneno_quedan = vida
	_veneno_cada = segundos / vida
	_veneno_reloj = _veneno_cada
	_veneno_origen = origen


## Lo frena 'segundos' (la trampa de hielo): no se suma, se rellena. Como los
## enemigos que frena el disparo del mago blanco: a la mitad, azulado y con
## escarcha a los pies (Escarcha). No quita vida.
func congelar(segundos: float) -> void:
	if vida_actual <= 0:
		return
	_tiempo_frio = maxf(_tiempo_frio, segundos)
	if _escarcha == null:
		_escarcha = EscarchaMago.new()
		# Despues del sprite: encima de el, como la de los enemigos.
		add_child(_escarcha)
		_poner_de_pie()
	_escarcha.visible = true
	_sprite.self_modulate = Escarcha.COLOR
	_sprite.speed_scale = FACTOR_FRIO


func tiene_frio() -> bool:
	return _tiempo_frio > 0.0


func _actualizar_frio(delta: float) -> void:
	if _tiempo_frio <= 0.0:
		return
	_tiempo_frio = maxf(_tiempo_frio - delta, 0.0)
	if _tiempo_frio <= 0.0:
		_quitar_frio()


func _quitar_frio() -> void:
	_tiempo_frio = 0.0
	_sprite.self_modulate = Color.WHITE
	_sprite.speed_scale = 1.0
	if _escarcha != null:
		_escarcha.visible = false


## Lo deja quemandose 'segundos': le quita 'dano' cada TIC_QUEMADURA, con
## llamas a los pies (Llamas, las de los enemigos que quema el mago rojo). Lo
## llama el aliento de fuego del jefe mientras le toca: no se suma, se
## rellena, y el tic no se reinicia (si no, tocandole sin parar no quemaria).
## Como el veneno, no mata: el ultimo punto lo deja.
func quemar(segundos: float, dano: int, origen: String = "") -> void:
	if vida_actual <= 0:
		return
	if _quemadura <= 0.0:
		_quemadura_reloj = TIC_QUEMADURA
	_quemadura = maxf(_quemadura, segundos)
	_quemadura_dano = dano
	_quemadura_origen = origen
	if _llamas == null:
		_llamas = LlamasMago.new()
		add_child(_llamas)
		move_child(_llamas, 0)
		_poner_de_pie()
	_llamas.visible = true


func esta_quemandose() -> bool:
	return _quemadura > 0.0


func _actualizar_quemadura(delta: float) -> void:
	if _quemadura <= 0.0:
		return
	_quemadura = maxf(_quemadura - delta, 0.0)
	_quemadura_reloj -= delta
	if _quemadura_reloj <= 0.0:
		_quemadura_reloj += TIC_QUEMADURA
		if not invencible and vida_actual > 1 and _control_activo:
			var cuanto := mini(_quemadura_dano, vida_actual - 1)
			vida_actual -= cuanto
			vida_cambiada.emit(vida_actual, vida_maxima)
			quemadura_quita.emit(cuanto, _quemadura_origen)
	if _quemadura <= 0.0:
		_quitar_quemadura()


func _quitar_quemadura() -> void:
	_quemadura = 0.0
	if _llamas != null:
		_llamas.visible = false


## Las llamas a los pies del mago, como la escarcha: un nodo aparte que pinta
## las de Llamas.
class LlamasMago extends Node2D:
	var _fase: float = 0.0

	func _process(delta: float) -> void:
		_fase += delta
		queue_redraw()

	func _draw() -> void:
		Llamas.pintar(self, Vector2(0.0, -4.0), 22.0, 50.0, _fase)


## La escarcha a los pies del mago: un nodo aparte (el jugador no se pinta a
## si mismo) que pinta la de Escarcha, la misma de los enemigos. Con el radio de
## un enemigo de su alto (72 px, Enemigo._pintar_escarcha).
class EscarchaMago extends Node2D:
	const RADIO_ESTADO: float = 44.0

	var _fase: float = 0.0

	func _process(delta: float) -> void:
		_fase += delta
		queue_redraw()

	func _draw() -> void:
		Escarcha.pintar(self, Vector2(0.0, -4.0), RADIO_ESTADO, _fase)


## Quita un punto cada _veneno_cada segundos hasta que no le quede. Sin
## invulnerabilidad de por medio: viene del golpe de antes, que ya la dio. Se
## para sin control (cayendo por un agujero, al acabar la partida).
##
## NO MATA, como caer por un agujero: el ultimo punto no lo quita. Si has
## aguantado el escupitajo con 2 de vida, morir segundos despues por lo que
## queda del veneno se sentiria injusto.
func _actualizar_veneno(delta: float) -> void:
	if _veneno_quedan <= 0 or not _control_activo:
		return
	_veneno_reloj -= delta
	if _veneno_reloj > 0.0:
		return
	_veneno_reloj += _veneno_cada
	_veneno_quedan -= 1
	if invencible or vida_actual <= 1:
		return
	vida_actual -= 1
	vida_cambiada.emit(vida_actual, vida_maxima)
	veneno_quita.emit(1, _veneno_origen)


func _parar_veneno() -> void:
	_tiempo_veneno = 0.0
	_veneno_quedan = 0


func esta_envenenado() -> bool:
	return _tiempo_veneno > 0.0


## Empieza a caer por un agujero. Lo llama el Vacio en cada paso mientras
## los pies esten dentro; la guarda hace que solo cuente la primera.
func caer_al_vacio() -> void:
	if _cayendo or vida_actual <= 0:
		return
	_cayendo = true
	_control_activo = false
	velocity = Vector2.ZERO
	_cancelar_carga()
	Sonido.tocar(&"caida")
	# Se encoge y se desvanece: se lee como caer hacia abajo, visto desde
	# arriba. Se anima el nodo entero para no pelearse con el color del sprite,
	# que ya lo usan el parpadeo y el veneno.
	_animacion_caida = create_tween()
	_animacion_caida.tween_property(_sprite, "scale", _escala_sprite * 0.2, DURACION_CAIDA)
	_animacion_caida.parallel().tween_property(self, "modulate:a", 0.0, DURACION_CAIDA)
	_animacion_caida.tween_callback(func() -> void: caido.emit())


func esta_cayendo() -> bool:
	return _cayendo


## Vuelve a aparecer despues de caer, y paga la caida.
func reaparecer(posicion: Vector2) -> void:
	_parar_caida()
	global_position = posicion
	velocity = Vector2.ZERO
	_control_activo = true
	recibir_dano(DANO_CAIDA, true, "Caída al vacío")


func _parar_caida() -> void:
	if _animacion_caida != null:
		_animacion_caida.kill()
		_animacion_caida = null
	_cayendo = false
	_sprite.scale = _escala_sprite
	modulate.a = 1.0


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
	_cancelar_carga()
	_parar_caida()
	_parar_veneno()
	_quitar_frio()
	_quitar_quemadura()
	# Cada piso trae su ataque especial, y empieza con el escudo bajado.
	if _escudo != null:
		_escudo.bajar()
	recargar_especial()
	# Cada piso empieza mirando hacia donde se baja.
	_mirando = &"abajo"


## Si sigue con vida. Lo preguntan los enemigos en cooperativo para elegir a
## por quien van (a un caido no).
func sigue_vivo() -> bool:
	return vida_actual > 0


## Cooperativo: vuelve en el piso siguiente con esa vida (la mitad, decidio
## Matias el 2026-10-16), visible y con control. Las mejoras no se pierden.
func revivir(vida: int) -> void:
	vida_actual = clampi(vida, 1, vida_maxima)
	visible = true
	_control_activo = true
	_tiempo_invulnerable = duracion_invulnerabilidad
	_sprite.modulate = Color.WHITE
	vida_cambiada.emit(vida_actual, vida_maxima)


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
	_parar_caida()
	_parar_veneno()
	_quitar_frio()
	_quitar_quemadura()
	_espera_disparo = 0.0
	_cancelar_carga()
	if _escudo != null:
		_escudo.bajar()
	recargar_especial()
	vida_cambiada.emit(vida_actual, vida_maxima)


## Congela al jugador (final de partida, transiciones).
func bloquear_control() -> void:
	_control_activo = false
	velocity = Vector2.ZERO
	_cancelar_carga()


## Lo contrario, si sigue vivo. Lo usa el cooperativo al cerrar la pausa,
## que alli no congela el juego: solo para al mago mientras esta abierta.
func desbloquear_control() -> void:
	if vida_actual > 0 and not _cayendo:
		_control_activo = true


## Como se le ve ahora, para ensenarlo igual en los otros ordenadores del
## cooperativo: la animacion y el color (el parpadeo de un golpe, el verde
## del veneno).
func animacion_actual() -> StringName:
	return _sprite.animation


func color_actual() -> Color:
	return _sprite.modulate
