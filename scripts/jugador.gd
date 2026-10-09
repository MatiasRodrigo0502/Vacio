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
## Se emite en cada disparo, con el punto de salida, hacia donde va y si es el
## ataque cargado. Va en la misma senal y no en otra aparte porque quien la
## escucha hace lo mismo en los dos casos: crear una bola, con otros numeros.
signal bola_lanzada(desde: Vector2, direccion: Vector2, cargada: bool)
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
@export var vida_maxima: int = 3
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
@export var dano_bola_cargada: int = 3
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
var dano_disparo: float = 1.0
var frena_disparo: float = 0.0
## El escudo direccional, si es el ataque especial del mago. Si no, null, y
## el especial es la bola cargada.
var _escudo: EscudoDireccional = null
## El mago con el que se juega. Principal mira aqui lo que es solo de un mago
## y no del jugador en general (el agujero negro de su bola cargada).
var mago: PersonajeJugable = null
## Si queda el ataque especial en este piso. Se gasta al soltar la bola
## cargada o sacar el escudo, y vuelve al llegar al piso siguiente.
##
## POR QUE UNA VEZ POR PISO (pedido por Matias, 2026-10-09): asi el especial
## es una decision, no algo que se tira cada vez que se puede. Hay que
## guardarlo para la sala que lo merece.
var especial_disponible: bool = true

## Tope de cadencia: por debajo de esto el disparo se vuelve una manguera y el
## juego deja de tener tension.
const CADENCIA_MINIMA: float = 0.09

## Por debajo de esta velocidad se considera que el personaje esta parado y se
## pasa a la animacion de reposo. No es 0 porque la friccion deja residuos.
const VELOCIDAD_MINIMA_ANDAR: float = 12.0

## Envenenado se va a esta fraccion de la velocidad. Frenar es lo que hace
## peligroso al veneno: no quita mas vida, pero te deja a tiro del siguiente.
const FACTOR_VENENO: float = 0.6
const COLOR_VENENO := Color(0.6, 1.0, 0.55)
## Lo que tarda la animacion de caer por un agujero.
const DURACION_CAIDA: float = 0.4
## Lo que cuesta caerse.
const DANO_CAIDA: int = 1

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

## Direccion a la que mira el sprite: "abajo", "izquierda", "derecha", "arriba".
## Se guarda en vez de recalcularse cada vez porque, al soltar los controles, el
## mago tiene que quedarse mirando a donde estaba, no volver a una por defecto.
var _mirando: StringName = &"abajo"

## Segundos que le quedan envenenado (frenado). 0 = sano.
var _tiempo_veneno: float = 0.0
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

	# Siempre desde los valores de la escena, nunca desde los de ahora: asi
	# llamarla dos veces con el mismo mago deja al jugador igual.
	_base_vida_maxima = _escena_vida_maxima + personaje.vida_maxima_extra
	_base_velocidad = _escena_velocidad + personaje.velocidad_extra
	_base_cadencia = maxf(_escena_cadencia * personaje.cadencia_multiplicador,
		CADENCIA_MINIMA)
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
		_escudo = EscudoDireccional.new(self)
		add_child(_escudo)
	elif not con_escudo and _escudo != null:
		_escudo.queue_free()
		_escudo = null
	if _escudo != null:
		_escudo.duracion = personaje.duracion_escudo

	# restaurar_vida() es lo que copia los valores de fabrica a los de verdad,
	# asi que sirve igual para "empezar de cero" que para "estrenar mago".
	restaurar_vida()


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


func _physics_process(delta: float) -> void:
	_actualizar_estados(delta)

	var direccion := Vector2.ZERO
	if _control_activo:
		# Input.get_vector ya normaliza: nada de ir mas rapido en diagonal.
		direccion = Input.get_vector(
			"mover_izquierda", "mover_derecha", "mover_arriba", "mover_abajo")

	if direccion != Vector2.ZERO:
		var punta := velocidad_maxima * (FACTOR_VENENO if esta_envenenado() else 1.0)
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

	# Cargando se apunta con el raton igual que disparando, asi que el mago
	# mira hacia donde va a soltar el ataque.
	if _cargando:
		return _direccion_raton()

	# El raton manda sobre las flechas: si estas apuntando, es lo que quieres.
	# Con el raton se apunta libre, en cualquier angulo; con las flechas solo a
	# las cuatro direcciones, que es el esquema clasico de teclado.
	if Input.is_action_pressed("disparar_raton"):
		return _direccion_raton()

	var flechas := Input.get_vector(
		"disparar_izquierda", "disparar_derecha", "disparar_arriba", "disparar_abajo")
	if flechas == Vector2.ZERO:
		return Vector2.ZERO
	# Con dos flechas a la vez manda la mas marcada: las diagonales harian el
	# disparo de teclado mas facil de lo que toca.
	if absf(flechas.x) > absf(flechas.y):
		return Vector2(signf(flechas.x), 0.0)
	return Vector2(0.0, signf(flechas.y))


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

	# El mago del escudo no carga nada: el mismo boton lo saca. Al pulsar y
	# no al mantener, para que sacarlo sea siempre algo que se decide.
	if _escudo != null:
		if Input.is_action_just_pressed("cargar_ataque") and _escudo.levantar():
			_gastar_especial()
			Sonido.tocar(&"escudo")
		return

	if Input.is_action_pressed("cargar_ataque"):
		_cargando = true
		var antes := _carga
		_carga = minf(_carga + delta, tiempo_carga)
		# Al cerrarse el aro, un brillo: ya se puede soltar sin mirarlo.
		if antes < tiempo_carga and _carga >= tiempo_carga:
			Sonido.tocar(&"carga_lista")
		_carga_visual.actualizar(_carga / tiempo_carga, _direccion_raton())
		return

	# Se ha soltado el boton (o no estaba pulsado).
	if _cargando and _carga >= tiempo_carga:
		bola_lanzada.emit(centro_colision(), _direccion_raton(), true)
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
func _actualizar_disparo(delta: float) -> void:
	_espera_disparo = maxf(_espera_disparo - delta, 0.0)
	# Mientras cargas no sale el disparo normal: estas canalizando, y si salieran
	# los dos a la vez no se sabria cual ha matado a que.
	if not _control_activo or _cargando or _espera_disparo > 0.0:
		return

	var direccion := _direccion_apuntada()
	if direccion == Vector2.ZERO:
		return

	_espera_disparo = cadencia_disparo
	# Sale del centro del cuerpo y no de los pies, para que se vea nacer del
	# personaje y no del suelo.
	bola_lanzada.emit(centro_colision(), direccion, false)


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


## Lo contrario de _lado(): del nombre de la direccion al vector que la
## representa. Si el nombre no existe, se mira hacia abajo, que es como empieza
## cada piso.
func _vector_de(lado: StringName) -> Vector2:
	var sector := LADOS.find(lado)
	if sector < 0:
		return Vector2.DOWN
	return Vector2.RIGHT.rotated(sector * TAU / 8.0)


## Traduce un vector a una de las ocho direcciones del mago.
##
## POR QUE POR ANGULO Y NO COMPARANDO x CONTRA y:
## con cuatro direcciones bastaba un if; con ocho, la misma idea se convierte en
## una escalera de comparaciones que no se lee ni se comprueba. Redondear el
## angulo al sector de 45 grados mas cercano es la misma regla escrita una vez.
func _lado(v: Vector2) -> StringName:
	return LADOS[posmod(int(roundf(v.angle() / (TAU / 8.0))), 8)]


## Invulnerabilidad y veneno: cuentan hacia atras y deciden el color.
func _actualizar_estados(delta: float) -> void:
	_tiempo_veneno = maxf(_tiempo_veneno - delta, 0.0)
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
func recibir_dano(cantidad: int = 1, forzar: bool = false) -> bool:
	if vida_actual <= 0 or invencible:
		return false
	if not forzar and (esta_invulnerable() or _cayendo):
		return false

	vida_actual = maxi(vida_actual - cantidad, 0)
	_tiempo_invulnerable = duracion_invulnerabilidad
	dano_recibido.emit()
	Sonido.tocar(&"herido")
	vida_cambiada.emit(vida_actual, vida_maxima)

	if vida_actual == 0:
		_control_activo = false
		velocity = Vector2.ZERO
		sin_vida.emit()
	return true


## Hacia donde mira el mago, como vector: hacia donde apunta o, si no apunta,
## hacia donde anda. La usa el escudo para encararse.
func direccion_mirada() -> Vector2:
	return _vector_de(_mirando)


## True si el escudo para algo de 'radio' que ha ido de 'desde' a 'hasta' en
## este paso. Lo preguntan los proyectiles enemigos; sin escudo, nunca.
func escudo_bloquea(desde: Vector2, hasta: Vector2, radio: float) -> bool:
	return _escudo != null and _escudo.bloquea(desde, hasta, radio)


## Centro real de la forma de colision, que NO es el origen del nodo: el origen
## esta a los pies y el circulo esta mas arriba, sobre la base de la tunica.
## Lo usan los obstaculos para comprobar si un impacto es de verdad.
func centro_colision() -> Vector2:
	return $Forma.global_position


## Cura sin pasar del maximo. Devuelve false si no ha curado nada: con la vida
## llena, el corazon del suelo se queda donde esta para cuando haga falta.
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
	# Un corazon nuevo viene lleno, y ademas se cura lo que diga el objeto.
	vida_actual = mini(vida_actual + mejora.vida_maxima_extra + mejora.cura, vida_maxima)

	velocidad_maxima += mejora.velocidad_extra
	cadencia_disparo = maxf(cadencia_disparo * mejora.cadencia_multiplicador,
		CADENCIA_MINIMA)
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


## Lo frena un rato. Lo llama el proyectil de veneno al acertar. No se suma:
## un segundo veneno reinicia la cuenta, no la alarga.
func envenenar(segundos: float) -> void:
	_tiempo_veneno = maxf(_tiempo_veneno, segundos)


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
	recibir_dano(DANO_CAIDA, true)


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
	_tiempo_veneno = 0.0
	# Cada piso trae su ataque especial, y empieza con el escudo bajado.
	if _escudo != null:
		_escudo.bajar()
	recargar_especial()
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
	_parar_caida()
	_tiempo_veneno = 0.0
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
