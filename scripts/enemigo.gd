## Enemigo: persigue al jugador o le dispara desde lejos, segun su tipo.
##
## POR QUE Area2D Y NO CharacterBody2D:
## por lo mismo que los obstaculos. Un cuerpo solido frenaria al jugador al
## chocar y este juego va de atravesar huecos con inercia; aqui el contacto
## resta vida y todo el mundo sigue moviendose. Ademas asi la bola magica, que
## tambien es un Area2D, lo detecta sin tener que mezclar capas de fisica.
##
## DOS FORMAS DE PELEAR (las decide TipoEnemigo.ataque):
## - cuerpo a cuerpo: va directo a por ti, rapido. Hay que pararlo antes.
## - a distancia: lento, se queda a su distancia y dispara. Antes de cada
##   disparo se para y avisa (destello, y el cristal una linea de mira): pega
##   fuerte, y el aviso es lo que hace que eso sea justo.
##
## Expone romper() igual que las rocas: la bola no pregunta contra que choca,
## solo si eso se puede romper.
class_name Enemigo
extends Area2D

signal muerto(enemigo: Enemigo)

## La escena se carga al soltar crias y no con preload: el script es parte de
## la propia escena, y precargarla desde aqui seria una referencia circular.
const RUTA_ESCENA := "res://scenes/Enemigo.tscn"
## Radio del jugador, para saber si una explosion le alcanza.
const RADIO_JUGADOR: float = 15.0
## Frenado (por el disparo del mago blanco): todo a este ritmo, y de este
## color, para que se vea por que va lento.
const RITMO_FRENADO: float = 0.5
const COLOR_FRENADO := Color(0.62, 0.84, 1.25)
## Quemadura (por los disparos del mago rojo): quita vida a golpes de un
## segundo, no un poco cada fotograma, porque cada golpe hace parpadear al
## enemigo y eso es lo que dice que le esta quemando.
const TIC_QUEMADURA: float = 1.0
## Lo que dura la linea del rayo que sale con el disparo, sin apuntar antes.
const DURACION_LINEA_DISPARO: float = 0.3
## Lo que frena el empuje del escudo, en px/s por segundo.
const FRENO_EMPUJE: float = 1600.0
## A un jefe el frio del mago blanco le dura esta parte: con el frio entero,
## disparandole sin parar iria siempre a la mitad, y la pelea final seria la
## mas facil del juego.
const FRIO_JEFE: float = 0.4

## De donde salen vida, velocidad, dibujo y demas. Lo pone la mecanica que los
## reparte; sin tipo, el enemigo no sabe que es y no se coloca.
var tipo: TipoEnemigo = null

## Con decimales: la quemadura del mago rojo quita 0,25 por golpe y el
## agujero negro del oscuro, medio punto en cada tic.
var _vida: float = 0.0
## Segundos de frenado que le quedan (ver herir).
var _frenado: float = 0.0
## Golpes de quemadura que le quedan, lo que quita cada uno y cuanto falta
## para el siguiente. 0 golpes = no se quema.
var _quemaduras: int = 0
var _dano_quemadura: float = 0.0
var _tic_quemadura: float = 0.0
var _objetivo: Node2D = null
## Dormido no se mueve ni dispara. La sala lo duerme al registrarlo y lo
## despierta cuando el jugador entra.
##
## POR QUE HACE FALTA:
## el enemigo va directo hacia el jugador, sin chocar con nada. Con salas
## pegadas, uno de la sala de al lado lo veria a traves del muro y lo cruzaria
## para perseguirlo. Dormido hasta que entras, cada sala es su propia pelea.
## Empieza despierto para que, suelto fuera de una sala, siga funcionando.
var _despierto: bool = true
var _fase: float = 0.0
## True desde el golpe que lo mata hasta que se libera: ya no pega ni se mueve.
var _muriendo: bool = false

# --- A distancia ---
## Segundos hasta poder empezar el siguiente disparo.
var _espera: float = 0.0
## Segundos de aviso que quedan. > 0 = esta apuntando, quieto.
var _apuntando: float = 0.0
## Hacia donde saldra el rayo. Se fija al empezar a apuntar, para que la linea
## de mira diga la verdad: el rayo sale justo por ahi.
var _mira: Vector2 = Vector2.DOWN
## Hasta donde llega el rayo por esa mira: hasta la primera roca o muro. La
## linea de aviso se pinta solo hasta ahi. Pintada entera, cruzaba las rocas
## y te avisaba de un peligro que detras de la roca no existe: el rayo se para
## en ella.
var _largo_mira: float = 0.0
## Lo que le queda a la linea del rayo cuando sale con el disparo, sin apuntar
## antes (tiempo_apuntar = 0). Se ve un momento y se apaga.
var _linea_disparo: float = 0.0
## Cuantos disparos lleva. Lo mira el cristal para saltar despues de cada uno.
var disparos: int = 0
## Velocidad con la que sale despedido (al chocar con el escudo del mago
## blanco). Se frena sola; mientras dura, no hace lo suyo: se le ve rebotar.
var _empuje: Vector2 = Vector2.ZERO

## Lo que el comportamiento de su tipo necesita recordar de ESTE enemigo (en
## que fase va, cuanto le queda). El comportamiento es uno para todo el tipo,
## asi que no puede guardarlo el (ver ComportamientoEnemigo).
var estado: Dictionary = {}
## Escala del dibujo al tamano de su tipo. Los comportamientos la estiran y la
## aplastan (saltos) a partir de esta.
var _escala_base: Vector2 = Vector2.ONE

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
	_escala_base = Vector2(escala, escala)
	_sprite.scale = _escala_base

	var forma := CircleShape2D.new()
	# El circulo cubre el cuerpo, un poco mas pequeno que el dibujo: igual que
	# con las rocas, mejor que el jugador sienta que ha pasado raspando a que le
	# golpee el aire.
	forma.radius = tipo.alto * 0.40
	_forma.shape = forma

	# El primer disparo llega antes que los siguientes, y cada enemigo con su
	# ritmo: si todos los de una sala dispararan a la vez, seria una rafaga
	# imposible de esquivar.
	_espera = tipo.cadencia * randf_range(0.45, 0.9)
	if tipo.comportamiento != null:
		tipo.comportamiento.empezar(self)


func _physics_process(delta: float) -> void:
	_fase += delta
	if _muriendo:
		return
	_golpear_lo_que_toca()
	_arder(delta)
	if _muriendo:
		return
	if _empuje != Vector2.ZERO:
		global_position += _empuje * delta
		_empuje = _empuje.move_toward(Vector2.ZERO, FRENO_EMPUJE * delta)
		mantener_en_la_sala()
		return
	# Frenado, anda, apunta y recarga a la mitad: el tiempo le pasa mas lento.
	# Pegar al tocarte no: eso no depende de su ritmo, sino de que le toques.
	if _frenado > 0.0:
		_frenado -= delta
		if _frenado <= 0.0:
			_dejar_de_frenar()
		else:
			delta *= RITMO_FRENADO
			queue_redraw()
	if not _despierto or tipo == null or not is_instance_valid(_objetivo):
		return

	if tipo.comportamiento != null:
		tipo.comportamiento.procesar(self, delta)
		if tipo.comportamiento.voltear(self):
			_sprite.flip_h = _objetivo.global_position.x < global_position.x
		queue_redraw()
		return

	# Despierto, va a por el jugador este donde este de la sala: la sala ya
	# limita a quien despierta (ver Sala.asomar). Antes habia ademas una
	# distancia de vision por tipo, de cuando no habia salas, y en las salas
	# grandes dejaba enemigos plantados en una esquina con las puertas
	# cerradas hasta que te acercabas (Matias, 2026-10-09).
	var hacia := _objetivo.global_position - global_position
	var distancia := hacia.length()

	if tipo.es_a_distancia():
		_pelear_a_distancia(delta, hacia, distancia)
	elif distancia > 0.0:
		_mover(hacia / distancia, delta)
	# Mira hacia donde esta el jugador: el volteo da sensacion de intencion y
	# sale gratis.
	_sprite.flip_h = hacia.x < 0.0


func dormir() -> void:
	_despierto = false
	# Su comportamiento vuelve al principio: dormido no puede quedarse a
	# medias (bajo tierra, invisible) hasta que alguien entre.
	if tipo != null and tipo.comportamiento != null:
		tipo.comportamiento.empezar(self)
	# Si se duerme a mitad de apuntar (el jugador se ha asomado y se ha ido,
	# ver Sala.asomar), se le quita el brillo y la mira: dormido no se mueve
	# nada, y se quedaba apuntando para siempre.
	_dejar_de_apuntar()


func despertar() -> void:
	_despierto = true


func esta_despierto() -> bool:
	return _despierto


func esta_apuntando() -> bool:
	return _apuntando > 0.0


## Muere ya, con la vida que le quede. Muere como con el ultimo disparo
## (explosion, crias, avisos), porque eso es lo que se quiere probar. Solo la
## usa el atajo de prueba F4 (AtajosPrueba).
func matar() -> void:
	if _vida <= 0:
		return
	_vida = 1
	# Directo al dano, sin pasar por herir(): este muere aunque este
	# intocable (bajo tierra, desvanecido). Si no, F4 dejaba vivos al fantasma
	# y a la planta azul a mitad de lo suyo, y la sala no se abria.
	_quitar_vida(1.0, 0.0)


## Un golpe: el contrato de todo lo que se puede romper. Lo que quita un
## disparo normal (10).
func romper() -> void:
	herir(10.0)


## La llama la bola magica: le quita 'cantidad' de vida (1 el disparo
## normal, varios el cargado; cada mago puede cambiarlo, ver
## PersonajeJugable.dano_disparo) y, si 'frena' > 0, lo deja ese
## tiempo frenado. Intocable (bajo tierra, desvanecido), no le entra.
##
## 'estilo' es de donde viene, para el numero que salta (NumeroDano): el
## disparo, el cargado, la quemadura, el agujero negro.
func herir(cantidad: float, frena: float = 0.0, estilo: NumeroDano.Estilo = NumeroDano.Estilo.NORMAL) -> void:
	if not es_tangible():
		return
	if es_invulnerable():
		tipo.comportamiento.bloqueado(self)
		return
	_quitar_vida(cantidad, frena, estilo)


## El dano de verdad, para herir() y matar().
##
## Puede llegar cuando el enemigo ya esta muerto: queue_free() no lo borra
## hasta el final del fotograma y hasta entonces sigue siendo un objeto
## valido. Sin este guardia, emitiria "muerto" mas de una vez.
func _quitar_vida(cantidad: float, frena: float, estilo: NumeroDano.Estilo = NumeroDano.Estilo.NORMAL) -> void:
	if _vida <= 0:
		return
	# Lo que le ha quitado, encima de la cabeza. Con lo que de verdad quita:
	# al ultimo golpe no le sobra vida que quitar.
	NumeroDano.soltar(get_parent(), global_position + Vector2(0.0, -tipo.alto * 0.55),
		minf(cantidad, _vida), estilo)
	_vida -= cantidad
	if frena > 0.0 and _vida > 0:
		frenar(frena)
	if _vida > 0:
		# Parpadeo blanco para que se vea que ha entrado el disparo.
		_sprite.modulate = Color(2.0, 2.0, 2.0)
		await get_tree().create_timer(0.08).timeout
		if is_instance_valid(self):
			_sprite.modulate = Color.WHITE
		return

	_muriendo = true
	visible = false
	# Diferido: romper() llega desde el area_entered de la bola, en mitad del
	# paso de fisica, y al morir se crean nodos con colision (las crias). El
	# motor no deja meterlos ahi.
	_morir.call_deferred()


## Lo deja quemandose 'segundos': le quita 'dano' cada segundo. Lo llama la
## bola del mago rojo en cada golpe.
##
## Otro golpe mientras arde vuelve a poner la cuenta en 'segundos', pero NO
## reinicia el tic: el mago dispara cada medio segundo, y si cada bola
## reiniciara la espera del primer golpe, disparandole sin parar no le
## quemaria nunca.
func quemar(segundos: float, dano: float) -> void:
	if _vida <= 0 or segundos <= 0.0 or es_invulnerable():
		return
	if _quemaduras == 0:
		_tic_quemadura = TIC_QUEMADURA
	_quemaduras = maxi(_quemaduras, ceili(segundos / TIC_QUEMADURA))
	_dano_quemadura = dano


func esta_quemado() -> bool:
	return _quemaduras > 0


## Cuenta la quemadura. Va a tiempo real, no al ritmo del frenado: el fuego
## no se frena porque el enemigo vaya lento.
func _arder(delta: float) -> void:
	if _quemaduras <= 0:
		return
	queue_redraw()
	_tic_quemadura -= delta
	if _tic_quemadura > 0.0:
		return
	_tic_quemadura += TIC_QUEMADURA
	_quemaduras -= 1
	herir(_dano_quemadura, 0.0, NumeroDano.Estilo.FUEGO)


## Lo deja frenado 'segundos' (si ya lo estaba, se queda con lo que dure mas).
func frenar(segundos: float) -> void:
	if tipo != null and tipo.jefe:
		segundos *= FRIO_JEFE
	_frenado = maxf(_frenado, segundos)
	# El color va en el nodo y no en el sprite: el sprite ya cambia de color al
	# recibir un golpe y al apuntar, y se pisarian.
	modulate = COLOR_FRENADO
	_sprite.speed_scale = RITMO_FRENADO


func esta_frenado() -> bool:
	return _frenado > 0.0


func _dejar_de_frenar() -> void:
	_frenado = 0.0
	modulate = Color.WHITE
	_sprite.speed_scale = 1.0
	queue_redraw()


## Un aro de escarcha en el suelo, a sus pies, con unos copos girando
## despacio. El tinte azul solo no bastaba: sobre un slime verde casi no se
## notaba. Va en el suelo y mas ancho que el cuerpo porque el sprite se pinta
## encima de esto: en el cuerpo quedaria tapado.
func _pintar_escarcha() -> void:
	var radio := tipo.alto * 0.62
	var pies := Vector2(0.0, tipo.alto * 0.42)
	var color := Color(0.78, 0.94, 1.0, 0.85)
	# Achatado: es un circulo en el suelo visto en 3/4.
	draw_set_transform(pies, 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, radio, Color(0.6, 0.85, 1.0, 0.22))
	draw_arc(Vector2.ZERO, radio, 0.0, TAU, 32, color, 2.5, true)
	draw_set_transform(Vector2.ZERO)
	for k in 5:
		var angulo := _fase * 1.2 + k * TAU / 5.0
		var copo := pies + Vector2(cos(angulo) * radio, sin(angulo) * radio * 0.4)
		draw_line(copo - Vector2(3.5, 0.0), copo + Vector2(3.5, 0.0), Color.WHITE, 1.4)
		draw_line(copo - Vector2(0.0, 3.5), copo + Vector2(0.0, 3.5), Color.WHITE, 1.4)


## Unas llamas a los pies, por el mismo motivo que la escarcha: el sprite se
## pinta encima de esto, asi que en el cuerpo quedarian tapadas. Suben y
## bajan cada una a su ritmo, para que se vea que arden.
func _pintar_llamas() -> void:
	var radio := tipo.alto * 0.62
	var pies := Vector2(0.0, tipo.alto * 0.42)
	# Un resplandor naranja en el suelo, achatado como la escarcha: se ve
	# aunque el cuerpo tape las llamas de detras.
	draw_set_transform(pies, 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, radio * 1.1, Color(1.0, 0.4, 0.05, 0.25 + 0.08 * sin(_fase * 9.0)))
	draw_set_transform(Vector2.ZERO)
	for k in 7:
		var angulo := k * TAU / 7.0 + 0.4
		var base := pies + Vector2(cos(angulo) * radio, sin(angulo) * radio * 0.4)
		var alto := tipo.alto * (0.38 + 0.14 * sin(_fase * 11.0 + k * 1.7))
		var ancho := 6.0
		var llama := PackedVector2Array([
			base + Vector2(-ancho, 0.0), base + Vector2(0.0, -alto), base + Vector2(ancho, 0.0)])
		draw_colored_polygon(llama, Color(1.0, 0.45, 0.1, 0.9))
		var dentro := PackedVector2Array([
			base + Vector2(-ancho * 0.5, 0.0), base + Vector2(0.0, -alto * 0.55),
			base + Vector2(ancho * 0.5, 0.0)])
		draw_colored_polygon(dentro, Color(1.0, 0.9, 0.35, 0.95))


# --- Movimiento y ataque ----------------------------------------------------

func _mover(direccion: Vector2, delta: float) -> void:
	andar(direccion, delta)


## Lo deja dentro del suelo de su sala y fuera de sus rocas.
##
## Los de cuerpo a cuerpo nunca salian, porque van hacia el jugador y el
## jugador esta dentro. Los de distancia retroceden, y sin esto cruzarian el
## muro de espaldas y dispararian desde la sala de al lado. Y fuera de las
## rocas porque las rocas paran las bolas: uno metido en una no se podria
## matar (ver Sala.sacar_de_las_rocas).
func mantener_en_la_sala(con_rocas: bool = true) -> void:
	var sala := get_parent() as Sala
	if sala == null or tipo == null:
		return
	var dentro := sala.rect_suelo_global().grow(-tipo.alto * 0.45)
	global_position = global_position.clamp(dentro.position, dentro.end)
	if not con_rocas:
		return
	global_position = sala.sacar_de_las_rocas(global_position, tipo.alto * 0.4)
	# Otra vez dentro del suelo: salir de una roca pegada al muro podria
	# haberlo empujado hacia fuera.
	global_position = global_position.clamp(dentro.position, dentro.end)


func _pelear_a_distancia(delta: float, hacia: Vector2, distancia: float) -> void:
	pelear_a_distancia(delta, hacia, distancia)


## Lo de siempre de los de distancia: quedarse a su distancia, avisar y
## disparar. Publico porque algun comportamiento lo usa de base y le anade lo
## suyo (el pisoton del golem, el salto del cristal).
func pelear_a_distancia(delta: float, hacia: Vector2, distancia: float) -> void:
	if _linea_disparo > 0.0:
		_linea_disparo = maxf(0.0, _linea_disparo - delta)
		queue_redraw()
	if _apuntando > 0.0:
		_apuntando -= delta
		var avance := 1.0 - _apuntando / tipo.tiempo_apuntar
		_sprite.modulate = Color.WHITE.lerp(tipo.color_efectos * 1.8, avance)
		queue_redraw()
		if _apuntando <= 0.0:
			_disparar()
		return

	# A su distancia: se acerca si estas lejos y se aparta si te acercas. El
	# hueco entre los dos umbrales evita que tiemble adelante y atras.
	if distancia > 0.0:
		var direccion := hacia / distancia
		if distancia > tipo.distancia_preferida + 40.0:
			_mover(direccion, delta)
		elif distancia < tipo.distancia_preferida - 80.0:
			_mover(-direccion, delta)

	_espera -= delta
	if _espera <= 0.0:
		_mira = (_punto_objetivo() - global_position).normalized()
		_largo_mira = _alcance_libre(_mira)
		# Sin tiempo de apuntar, dispara ya, y la linea sale con el disparo.
		# Hace falta aparte: con _apuntando a 0 nunca llegaria a la cuenta
		# atras de arriba, que es la que dispara.
		if tipo.tiempo_apuntar <= 0.0:
			_disparar()
			_linea_disparo = DURACION_LINEA_DISPARO
		else:
			_apuntando = tipo.tiempo_apuntar


## Distancia hasta la primera roca o muro en esa direccion, o el alcance del
## proyectil si no hay nada. Las rocas no se mueven, asi que basta con
## mirarlo al empezar a apuntar.
func _alcance_libre(direccion: Vector2) -> float:
	var alcance := tipo.proyectil.alcance
	var rayo := PhysicsRayQueryParameters2D.create(global_position,
		global_position + direccion * alcance, Terreno.CAPA_MUROS | Terreno.CAPA_ROCAS)
	var golpe := get_world_2d().direct_space_state.intersect_ray(rayo)
	if golpe.is_empty():
		return alcance
	return global_position.distance_to(golpe["position"])


func _disparar() -> void:
	_apuntando = 0.0
	_espera = tipo.cadencia
	_sprite.modulate = Color.WHITE
	queue_redraw()

	# El rayo sale por donde marco la mira; lo demas, hacia donde estas ahora:
	# es mas lento y se esquiva moviendose.
	var direccion := _mira
	if tipo.proyectil.estilo != TipoProyectil.Estilo.RAYO:
		direccion = (_punto_objetivo() - global_position).normalized()
	disparar_hacia(direccion)
	disparos += 1


func _dejar_de_apuntar() -> void:
	if _apuntando <= 0.0:
		return
	_apuntando = 0.0
	_sprite.modulate = Color.WHITE
	queue_redraw()


# --- Lo que usan los comportamientos (scripts/comportamientos/) ---------------

## Un disparo de su proyectil hacia 'direccion', con su sonido. La parabola
## cae donde esta el jugador ahora. Con 'otro', ese proyectil y no el suyo (el
## jefe tira mas de una cosa).
func disparar_hacia(direccion: Vector2, otro: TipoProyectil = null) -> void:
	var que := otro if otro != null else tipo.proyectil
	var sala_propia := sala()
	var limite := sala_propia.rect_con_muros() if sala_propia != null else Rect2()
	var proyectil := ProyectilEnemigo.new()
	proyectil.configurar(que, global_position, direccion, _punto_objetivo(), limite)
	proyectil.autor = tipo.nombre
	get_parent().add_child(proyectil)
	Sonido.tocar(que.sonido)


## Pone esa animacion de su SpriteFrames, si la tiene y no esta ya puesta.
## La usa el jefe, que tiene una por direccion como los magos.
func animar(nombre: StringName) -> void:
	if _sprite.sprite_frames != null and _sprite.sprite_frames.has_animation(nombre) \
			and _sprite.animation != nombre:
		_sprite.play(nombre)


## La vida que le queda, de 0 a 1. La ensena la barra del jefe.
func fraccion_vida() -> float:
	return clampf(_vida / tipo.vida, 0.0, 1.0) if tipo != null and tipo.vida > 0 else 0.0


## True mientras su comportamiento lo hace invulnerable (el escudo del jefe).
func es_invulnerable() -> bool:
	return tipo != null and tipo.comportamiento != null and tipo.comportamiento.invulnerable(self)


## Anda a su velocidad por 'factor' hacia 'direccion' sin salir de su sala.
## Con 'atravesar_rocas' (el fantasma, lo que va bajo tierra) las rocas no le
## paran.
func andar(direccion: Vector2, delta: float, factor: float = 1.0, atravesar_rocas: bool = false) -> void:
	global_position += direccion * tipo.velocidad * factor * delta
	mantener_en_la_sala(not atravesar_rocas)


## Anda en linea recta y, si choca con un muro o una roca, rebota como una
## pelota. Devuelve la direccion despues del rebote.
func andar_rebotando(direccion: Vector2, delta: float, factor: float = 1.0) -> Vector2:
	var intento := global_position + direccion * tipo.velocidad * factor * delta
	global_position = intento
	mantener_en_la_sala()
	# Lo que la sala le ha empujado para dejarlo dentro es la normal de lo que
	# ha tocado: se refleja contra ella.
	var empuje := global_position - intento
	if empuje.length() > 0.01:
		direccion = direccion.bounce(empuje.normalized())
	return direccion


## Del enemigo al cuerpo del jugador.
func hacia_objetivo() -> Vector2:
	return _punto_objetivo() - global_position


## El brillo de "va a atacar", de 0 (nada) a 1 (a punto). El mismo aviso que
## los de distancia antes de disparar.
func brillo(avance: float) -> void:
	_sprite.modulate = Color.WHITE.lerp(tipo.color_efectos * 1.8, clampf(avance, 0.0, 1.0))


## Mueve, estira y transparenta el dibujo sin mover al enemigo: el arco de un
## salto, el aplastarse antes de saltar, desvanecerse.
func poner_sprite(desplazamiento: Vector2, escala: Vector2, alfa: float) -> void:
	_sprite.position = desplazamiento
	_sprite.scale = _escala_base * escala
	_sprite.self_modulate.a = alfa


## Lo despide con esa velocidad (px/s), que se frena sola. Lo usa el escudo
## del mago blanco con lo que le toca.
func empujar(impulso: Vector2) -> void:
	_empuje = impulso


func sala() -> Sala:
	return get_parent() as Sala


## False mientras su comportamiento lo hace intocable (desvanecido, bajo
## tierra): ni se le puede dar ni hace dano al tocar. Las bolas lo atraviesan.
func es_tangible() -> bool:
	return tipo == null or tipo.comportamiento == null or tipo.comportamiento.tangible(self)


## Donde apuntar: al cuerpo del jugador, no a sus pies.
func _punto_objetivo() -> Vector2:
	if _objetivo.has_method("centro_colision"):
		return _objetivo.centro_colision()
	return _objetivo.global_position


## Hace dano a todo lo que este tocando, en cada paso de fisica.
##
## POR QUE MIRANDO EL SOLAPE Y NO CON body_entered:
## body_entered avisa una sola vez, al entrar. El enemigo va directo hacia el
## jugador y se le queda encima, asi que solo le pegaba al primer contacto:
## quedarse quieto con un slime encima costaba un corazon y ya. Mirando el
## solape en cada paso vuelve a pegar en cuanto acaba la invulnerabilidad, y
## no pega de mas porque recibir_dano() ignora los golpes mientras dura.
func _golpear_lo_que_toca() -> void:
	if tipo == null or not es_tangible():
		return
	for cuerpo in get_overlapping_bodies():
		# Con el escudo del mago blanco puesto no le hace nada: la burbuja lo
		# despide (EscudoBurbuja).
		if cuerpo.has_method("escudo_activo") and cuerpo.escudo_activo():
			continue
		if cuerpo.has_method("recibir_dano"):
			cuerpo.recibir_dano(tipo.dano, false, tipo.nombre)


# --- Muerte -----------------------------------------------------------------

## Explota y suelta crias si su tipo lo dice, y luego avisa de que ha muerto.
##
## LAS CRIAS SE APUNTAN EN LA SALA ANTES DE AVISAR: la sala abre las puertas
## cuando se queda sin enemigos. Si el aviso fuera primero, al matar al ultimo
## slime las puertas se abririan un instante con sus crias todavia vivas.
func _morir() -> void:
	if tipo.radio_explosion > 0.0:
		_explotar()
		Sonido.tocar(&"explosion")
	else:
		_destello_muerte()
		Sonido.tocar(&"muerte_enemigo")
	for i in tipo.division:
		_soltar_cria(i)
	if tipo.comportamiento != null:
		tipo.comportamiento.al_morir(self)
	muerto.emit(self)
	queue_free()


func _explotar() -> void:
	var destello := Explosion.new()
	destello.radio = tipo.radio_explosion
	destello.color = tipo.color_efectos
	destello.position = position
	get_parent().add_child(destello)
	if is_instance_valid(_objetivo) and _objetivo.has_method("centro_colision") \
			and _objetivo.centro_colision().distance_to(global_position) \
				< tipo.radio_explosion + RADIO_JUGADOR \
			and not (_objetivo.has_method("escudo_activo") and _objetivo.escudo_activo()):
		_objetivo.recibir_dano(tipo.dano_explosion, false, tipo.nombre + " (explosión)")


## Un destello pequeno de su color al morir, sin dano. Antes los enemigos
## desaparecian sin mas: en una sala con ocho, no se sabia bien cual habia
## caido. Es la misma explosion de los slimes, del tamano del enemigo.
func _destello_muerte() -> void:
	var destello := Explosion.new()
	destello.radio = tipo.alto * 0.6
	destello.color = tipo.color_efectos
	destello.position = position
	get_parent().add_child(destello)


func _soltar_cria(numero: int) -> void:
	var cria: Enemigo = load(RUTA_ESCENA).instantiate()
	get_parent().add_child(cria)
	# Repartidas en circulo alrededor de donde murio la madre.
	var angulo := TAU * numero / tipo.division + _fase
	cria.preparar(tipo.cria(), global_position + Vector2.RIGHT.rotated(angulo) * tipo.alto * 0.5)
	cria.mantener_en_la_sala()
	var sala := get_parent() as Sala
	if sala != null:
		sala.registrar_enemigo(cria)


## La linea de mira del rayo: mientras apunta, o un momento con el disparo
## si no apunta. Solo el rayo la lleva.
func _draw() -> void:
	if _frenado > 0.0 and tipo != null:
		_pintar_escarcha()
	if _quemaduras > 0 and tipo != null:
		_pintar_llamas()
	if tipo != null and tipo.comportamiento != null:
		tipo.comportamiento.dibujar(self)
	if tipo == null or not tipo.es_a_distancia():
		return
	if tipo.proyectil.estilo != TipoProyectil.Estilo.RAYO:
		return
	var color := tipo.proyectil.color
	if _linea_disparo > 0.0:
		# Sale entera y gruesa, y se apaga.
		var queda := _linea_disparo / DURACION_LINEA_DISPARO
		draw_line(Vector2.ZERO, _mira * _largo_mira,
			Color(color.r, color.g, color.b, 0.75 * queda), 1.0 + 3.0 * queda)
		return
	if _apuntando <= 0.0:
		return
	var avance := 1.0 - _apuntando / tipo.tiempo_apuntar
	draw_line(Vector2.ZERO, _mira * _largo_mira,
		Color(color.r, color.g, color.b, 0.2 + 0.5 * avance), 1.0 + 2.5 * avance)
