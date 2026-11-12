## Bola magica: el disparo del jugador.
##
## Sale en la direccion que marquen las flechas y rompe lo primero que toca,
## sea una roca, una plataforma o (en cuanto existan) un enemigo.
##
## POR QUE NO PASA POR UN POOL:
## el pool del proyecto existe para los obstaculos, que son decenas por piso y
## se reciclan en cada cambio. Las bolas son tres o cuatro por segundo y viven
## menos de un segundo; montarles un pool seria contabilidad a cambio de nada.
## Si algun dia la cadencia sube mucho, este es el sitio donde mirarlo.
class_name BolaMagica
extends Area2D

## Como se pinta con un arma (ArmaMago.estilo).
enum Estilo { ORBE, ESTRELLA, FLECHA, RUNA, CUCHILLA, RAYO }

## Se emite al romper algo, por si en el futuro hay sonido o particulas.
signal impacto(objetivo: Node2D)
## Se emite al acabar su trayecto, con el punto donde se acaba: al llegar a su
## alcance, al chocar con una roca o al salir de la sala. La usa el agujero
## negro del mago oscuro, que se abre ahi. La bola no sabe nada de agujeros:
## solo avisa de donde se ha apagado.
signal apagada(punto: Vector2)

@export var velocidad: float = 620.0
@export var radio: float = 11.0
## Si no choca con nada, se apaga sola despues de recorrer esto.
@export var alcance: float = 1200.0
## Si es true atraviesa y rompe todo lo que pilla. En false, rompe lo primero
## que toca y se apaga.
@export var atraviesa: bool = false
## En cooperativo, en los ordenadores que no crean la sala: la bola solo se
## ve. Los enemigos de verdad estan en el anfitrion, y alli otra bola igual es
## la que les quita vida (MundoRed). Aqui se apaga al tocarlos, sin mas.
@export var solo_ver: bool = false

## Cuanta vida quita a lo que toca. El disparo normal quita 10 (desde el
## 2026-10-14; antes 1, con la vida de los enemigos en disparos); el ataque
## cargado, 30 o mas.
##
## A los enemigos se lo pasa con herir(). A lo demas que se pueda romper, con
## romper() repetido (un golpe por cada 10), que es el contrato de siempre
## ("un golpe, sin parametros"): asi nada de lo que ya era rompible tiene que
## cambiar.
@export var dano: float = 10.0
## Cada golpe quita entre 'dano' y esto por 'dano' (10 a 13 el normal).
const VARIACION: float = 1.3
## Segundos que deja frenado al enemigo que toca. 0 = no frena.
@export var frena: float = 0.0
## Segundos que deja quemandose al enemigo que toca, y lo que le quita la
## quemadura cada segundo. 0 segundos = no quema.
@export var quema: float = 0.0
@export var dano_quema: float = 0.0
## De que color es esa quemadura (Llamas): fuera y dentro. Transparentes, de fuego.
@export var color_quema: Color = Color(0.0, 0.0, 0.0, 0.0)
@export var dentro_quema: Color = Color(0.0, 0.0, 0.0, 0.0)
## Lo mismo con el veneno del disparo (PersonajeJugable.veneno_disparo_duracion).
@export var envenena: float = 0.0
@export var dano_veneno: float = 0.0

## Marca el disparo cargado. Ya no decide el color (eso lo hace `color`), pero
## sirve para saber que bola es cual sin mirar su tamano.
@export var cargada: bool = false
## Una gota del rocio del mago verde (PersonajeJugable.rocio): se pinta como
## una gota de veneno con su estela y no como una bola de luz, y al dar no suena
## ni saca su numero: lo junta el enemigo (Enemigo.TIC_ROCIO). Salen 9 por
## segundo (18 hasta el 2026-11-10).
@export var rocio: bool = false
## Lo largo de la estela de una gota del rocio, en radios.
const LARGO_ESTELA_ROCIO: float = 3.2

## Color del centro de la bola y de su resplandor. Los pone Principal con los
## del mago que dispara, asi que cada mago tiene sus bolas sin que la bola sepa
## de magos. Por defecto, los del disparo normal del mago oscuro.
@export var color: Color = Color(0.62, 0.84, 1.0)
@export var color_halo: Color = Color(0.35, 0.60, 1.0)

## Como se ve (del mago que dispara, ver ArteHechizo). Sin arte, una bola de luz
## pintada por codigo con los dos colores de arriba.
var arte: ArteHechizo = null

## El arma que la dispara (ArmaMago), y lo que cambia de la bola. Lo pone
## usar_arma; sin arma, todo esto se queda en nada.
var arma: ArmaMago = null
var estilo: int = Estilo.ORBE
## Cuanto serpentea, en px a cada lado, y hacia cual empieza.
var onda: float = 0.0
var signo_onda: float = 1.0
## Cuantos rebotes le quedan en muros y rocas.
var rebotes: int = 0
## Lo que gira hacia el enemigo mas cercano, en radianes por segundo.
var busca: float = 0.0
## Radio de la explosion al acabarse.
var explosion: float = 0.0
## Su sala: a quien busca y a quien alcanza su explosion, y donde rebota.
var sala: Sala = null

## Si es true, los disparos tambien destruyen rocas y plataformas. Esta en false
## porque las rocas son el terreno: si el disparo las borra, el piso se limpia
## solo y esquivar deja de importar. Ahora la roca para la bola y sirve de
## parapeto, que es lo que hace en Isaac.
@export var rompe_obstaculos: bool = false

## Hacia donde va. La fija el jugador al dispararla.
var direccion: Vector2 = Vector2.DOWN

## Casilla de la sala desde la que se disparo (su suelo y su mitad de muro), en
## coordenadas del mundo. La bola se apaga al salir de ella.
##
## POR QUE HACE FALTA:
## las salas estan pegadas, y una bola que cruzara una puerta abierta seguiria
## hasta la sala de al lado y mataria enemigos que el jugador ni ha visto. En
## Isaac las lagrimas no salen de la sala; aqui tampoco. Vacio = sin limite.
var limite: Rect2 = Rect2()

## Contra las rocas solo cuenta el nucleo de la bola, no todo su tamano.
##
## POR QUE:
## el tamano de la bola esta para acertar a los enemigos. Si contara entero
## contra las rocas, hacer la bola mas grande (el orbe hinchado, el ataque
## cargado, que la dobla) la haria morir en cualquier roca que rozara aunque
## el camino estuviera libre: mejorarla te dejaria peor. Lo encontro la prueba
## de la partida entera: con radio 23, la bola nacia tocando una roca y no
## llegaba a un enemigo que tenia delante. Es la misma idea que las rocas,
## que chocan con el 72 % de su dibujo: mejor pasar raspando.
const RADIO_CONTRA_ROCAS: float = 10.0
## Lo que recorre en una vuelta de la onda, en px.
const LARGO_ONDA: float = 220.0
## Hasta donde llega una que rebota: con el alcance normal se apagaria en el
## segundo rebote.
const ALCANCE_REBOTANDO: float = 4000.0
const SHADER_RECORTE := preload("res://shaders/recorte_bola.gdshader")
## Lo que tiene que pasar la bola de la linea del recorte, en radios, para quitarlo:
## lo mas largo que deja detras es la lanza de hielo del blanco (8,1 radios: su
## casilla mide 96 px y va 41 px atras, con radio_base 11).
const FIN_RECORTE_RADIOS: float = 9.0

var _recorrido: float = 0.0
var _fase: float = 0.0
## El dibujo, si tiene arte. Mirando hacia donde va: las hojas estan dibujadas
## mirando a la derecha. A la escala de su radio: el orbe hinchado la agranda.
var _dibujo: AnimatedSprite2D = null
## Hasta donde (en '_recorrido') lleva el recorte de recortar_desde; -1, sin el.
var _recorte_hasta: float = -1.0

@onready var _forma: CollisionShape2D = $Forma


func _ready() -> void:
	# Los enemigos son areas y se detectan con la senal. Las rocas no: son
	# StaticBody2D, y un Area2D no los detecta. Esas se miran a mano en cada
	# paso (ver Terreno).
	area_entered.connect(_al_tocar)
	var circulo := CircleShape2D.new()
	circulo.radius = radio
	_forma.shape = circulo
	if arte != null and arte.tiene(&"vuelo"):
		_dibujo = AnimatedSprite2D.new()
		add_child(_dibujo)
		_dibujo.rotation = direccion.angle()
		_dibujo.scale = Vector2.ONE * radio / arte.radio_base
		arte.poner(_dibujo, &"vuelo")


## Que no se vea lo que queda detras de 'punto' mirando hacia donde va. La bola del
## mago nace en su centro y, si es grande (la lanza de hielo del blanco, el orbe
## hinchado), asomaba por detras de el (Matias, 2026-11-10: «que solo se vea a partir
## de la parte delantera del mago»). Se quita cuando ya ha salido entera: con un
## material propio, su dibujo no se junta con el de las demas.
func recortar_desde(punto: Vector2) -> void:
	var recorte := ShaderMaterial.new()
	recorte.shader = SHADER_RECORTE
	recorte.set_shader_parameter("punto", punto)
	recorte.set_shader_parameter("delante", direccion)
	material = recorte
	if _dibujo != null:
		_dibujo.use_parent_material = true
	_recorte_hasta = global_position.distance_to(punto) + radio * FIN_RECORTE_RADIOS


## Lo que tiene del arma que la dispara. Solo el aspecto, si es rara. Lo demas,
## en todos los ordenadores igual: es lo que la mueve. El dano, el tamano y la
## velocidad ya vienen puestos (Principal), porque en los demas ordenadores
## llegan ya hechos.
func usar_arma(de_arma: ArmaMago, modo: ModoArma, en_sala: Sala) -> void:
	arma = de_arma
	arte = null
	color = de_arma.color
	color_halo = de_arma.halo
	estilo = de_arma.estilo if modo.estilo < 0 else modo.estilo
	if de_arma.solo_aspecto():
		return
	rocio = false
	onda = modo.onda
	atraviesa = modo.atraviesa
	rebotes = modo.rebotes
	busca = deg_to_rad(modo.busca)
	explosion = modo.explosion
	sala = en_sala
	if rebotes > 0:
		alcance = ALCANCE_REBOTANDO


func _physics_process(delta: float) -> void:
	var paso := velocidad * delta
	var antes := global_position
	if busca > 0.0:
		_buscar(delta)
	position += direccion * paso
	if onda > 0.0:
		var k := TAU / LARGO_ONDA
		position += direccion.orthogonal() * (sin((_recorrido + paso) * k) - sin(_recorrido * k)) * onda * signo_onda
	_recorrido += paso
	if _recorte_hasta >= 0.0 and _recorrido > _recorte_hasta:
		_recorte_hasta = -1.0
		material = null
	var roca := Terreno.choque(get_world_2d(), antes, global_position,
		minf(radio, RADIO_CONTRA_ROCAS), Terreno.CAPA_ROCAS)
	if roca != null:
		if rebotes > 0 and roca is Node2D:
			rebotes -= 1
			var normal: Vector2 = (antes - roca.global_position).normalized()
			direccion = direccion.bounce(normal) if normal != Vector2.ZERO else -direccion
			global_position = antes
			return
		_al_tocar_roca(roca, antes)
		return
	_fase += delta
	queue_redraw()
	if _recorrido >= alcance:
		_apagar(global_position)
		return
	if rebotes > 0 and _rebotar_en_el_muro(antes):
		return
	if limite.has_area() and not limite.has_point(global_position):
		_apagar(antes)


## Gira hacia el enemigo mas cercano, como mucho 'busca' por segundo.
func _buscar(delta: float) -> void:
	if not is_instance_valid(sala):
		return
	var enemigo := sala.enemigo_mas_cercano(global_position)
	if enemigo == null:
		return
	var falta := wrapf((enemigo.global_position - global_position).angle() - direccion.angle(), -PI, PI)
	direccion = direccion.rotated(clampf(falta, -busca * delta, busca * delta))


## Rebota en el borde del suelo de su sala. True si ha rebotado.
func _rebotar_en_el_muro(antes: Vector2) -> bool:
	if not is_instance_valid(sala):
		return false
	var suelo := sala.rect_suelo_global()
	var aqui := global_position
	var rebota := false
	if aqui.x < suelo.position.x or aqui.x > suelo.end.x:
		direccion.x = -direccion.x
		rebota = true
	if aqui.y < suelo.position.y or aqui.y > suelo.end.y:
		direccion.y = -direccion.y
		rebota = true
	if rebota:
		rebotes -= 1
		global_position = antes
	return rebota


## Choque contra una roca o plataforma: la bola se apaga y la roca aguanta, asi
## que la roca sirve de parapeto.
func _al_tocar_roca(cuerpo: Object, antes: Vector2) -> void:
	if cuerpo is Obstaculo and rompe_obstaculos:
		cuerpo.romper()
		impacto.emit(cuerpo)
	# Donde estaba antes de meterse en la roca, no dentro de ella.
	_apagar(antes)


func _apagar(punto: Vector2) -> void:
	# Con el juego a tirones caben dos pasos de fisica en un fotograma, antes
	# de que queue_free() la borre: sin esto se abririan dos agujeros.
	if is_queued_for_deletion():
		return
	apagada.emit(punto)
	EfectoHechizo.soltar(get_parent(), arte, &"impacto", punto, z_index)
	_explotar(punto)
	queue_free()


func _al_tocar(area: Area2D) -> void:
	# Duck typing como en todo el proyecto: la bola no pregunta contra que ha
	# chocado, solo si eso se puede romper.
	# Un enemigo intocable (el fantasma desvanecido, la planta bajo tierra) no
	# se lleva la bola: la bola sigue de largo.
	if area.has_method("es_tangible") and not area.es_tangible():
		return
	if solo_ver:
		if (area.has_method("herir") or area.has_method("romper")) and not atraviesa:
			EfectoHechizo.soltar(get_parent(), arte, &"impacto", global_position, z_index)
			_explotar(global_position)
			queue_free()
		return
	if area.has_method("herir"):
		# Lo que quita varia un poco hacia arriba (de 10 a 13 el normal): los
		# numeros que saltan no son siempre el mismo. Solo hacia arriba, para
		# que lo que caia de un disparo siga cayendo de uno.
		var golpe := float(roundi(dano * randf_range(1.0, VARIACION)))
		var estilo_numero := NumeroDano.Estilo.FUERTE if cargada else NumeroDano.Estilo.NORMAL
		if rocio:
			estilo_numero = NumeroDano.Estilo.ROCIO
		_golpear(area, golpe, estilo_numero)
		if not rocio:
			Sonido.tocar(&"golpe_enemigo")
		if quema > 0.0 and area.has_method("quemar"):
			area.quemar(quema, dano_quema, color_quema, dentro_quema)
		if envenena > 0.0 and area.has_method("envenenar"):
			area.envenenar(envenena, dano_veneno, false)
	elif area.has_method("romper"):
		# romper() es un golpe de un disparo normal (10).
		for i in int(ceil(dano / 10.0)):
			if not is_instance_valid(area):
				break
			area.romper()
	else:
		return
	impacto.emit(area)
	if not atraviesa:
		EfectoHechizo.soltar(get_parent(), arte, &"impacto", global_position, z_index)
		_explotar(global_position)
		queue_free()


## Le quita vida y, si lo mata y el arma lo tiene, su animacion al matar.
func _golpear(area: Area2D, cuanto: float, estilo_numero: NumeroDano.Estilo) -> void:
	area.herir(cuanto, frena, estilo_numero)
	if arma != null and area is Enemigo and area.fraccion_vida() <= 0.0:
		AnimacionMuerte.soltar_de(area, arma.muerte, arma.color)


## La explosion de las armas que la tienen: la mitad de su dano a los que pille
## dentro, tambien al que le ha dado. La vida la quita solo quien manda (solo_ver).
func _explotar(punto: Vector2) -> void:
	if explosion <= 0.0:
		return
	var destello := Explosion.new()
	destello.radio = explosion
	destello.color = color
	get_parent().add_child(destello)
	destello.global_position = punto
	Sonido.tocar(&"explosion")
	if solo_ver or not is_instance_valid(sala):
		return
	for enemigo in sala.enemigos():
		if is_instance_valid(enemigo) and enemigo.es_tangible() and enemigo.tipo != null \
				and enemigo.global_position.distance_to(punto) <= explosion + enemigo.tipo.alto * 0.4:
			_golpear(enemigo, roundf(dano * 0.5), NumeroDano.Estilo.FUERTE)


## Dibujada por codigo, como los corazones: no hay arte de proyectil en los
## packs y una bola de luz se resuelve con unos circulos y un rastro.
func _draw() -> void:
	if _dibujo != null:
		return
	if rocio:
		_pintar_rocio()
		return
	if arma != null and estilo != Estilo.ORBE:
		_pintar_estilo()
		return
	var pulso := 1.0 + sin(_fase * 22.0) * 0.12
	# El rastro va siempre detras, sea cual sea la direccion del disparo.
	var atras := -direccion
	var nucleo := color
	var halo := color_halo

	for i in 5:
		var t := float(i) / 5.0
		draw_circle(atras * radio * (0.9 + i * 0.85),
			radio * (0.72 - t * 0.5) * pulso,
			Color(halo.r, halo.g, halo.b, 0.30 - t * 0.24))

	draw_circle(Vector2.ZERO, radio * 1.75 * pulso, Color(halo.r, halo.g, halo.b, 0.22))
	draw_circle(Vector2.ZERO, radio * pulso, Color(nucleo.r, nucleo.g, nucleo.b, 0.95))
	draw_circle(Vector2(-radio * 0.22, -radio * 0.22), radio * 0.42 * pulso,
		Color(1.0, 1.0, 1.0, 0.95))


## Las bolas de las armas. Por codigo, como la de luz: con dos colores por arma,
## cada una se ve distinta sin una hoja de dibujos para cada una.
func _pintar_estilo() -> void:
	var atras := -direccion
	var lado := direccion.orthogonal()
	draw_circle(Vector2.ZERO, radio * 1.7, Color(color_halo, 0.25))
	match estilo:
		Estilo.ESTRELLA:
			var puntos := PackedVector2Array()
			for i in 10:
				var r := radio * (1.25 if i % 2 == 0 else 0.5)
				puntos.append(Vector2.from_angle(_fase * 6.0 + i * TAU / 10.0) * r)
			draw_colored_polygon(puntos, color)
			draw_circle(Vector2.ZERO, radio * 0.35, Color.WHITE)
		Estilo.FLECHA:
			draw_line(atras * radio * 3.0, Vector2.ZERO, Color(color_halo, 0.8), radio * 0.5, true)
			draw_colored_polygon(PackedVector2Array([direccion * radio * 1.5, lado * radio * 0.8, -lado * radio * 0.8]), color)
			draw_colored_polygon(PackedVector2Array([direccion * radio * 0.9, lado * radio * 0.3, -lado * radio * 0.3]), Color.WHITE)
		Estilo.RUNA:
			var r := radio * 1.1
			var giro := _fase * 4.0
			var cuadro := PackedVector2Array()
			for i in 4:
				cuadro.append(Vector2.from_angle(giro + i * TAU / 4.0) * r)
			draw_colored_polygon(cuadro, color_halo)
			draw_arc(Vector2.ZERO, r * 0.62, -giro, -giro + TAU * 0.8, 16, color, radio * 0.25, true)
			draw_circle(Vector2.ZERO, r * 0.22, Color.WHITE)
		Estilo.CUCHILLA:
			var filo := PackedVector2Array()
			for i in 7:
				var angulo := direccion.angle() - 1.3 + i * 2.6 / 6.0
				filo.append(Vector2.from_angle(angulo) * radio * 1.4)
			for i in range(6, -1, -1):
				var angulo := direccion.angle() - 1.3 + i * 2.6 / 6.0
				filo.append(Vector2.from_angle(angulo) * radio * 0.7 + atras * radio * 0.4)
			draw_colored_polygon(filo, color)
		Estilo.RAYO:
			draw_line(atras * radio * 6.0, direccion * radio, Color(color_halo, 0.55), radio * 1.2, true)
			draw_line(atras * radio * 5.0, direccion * radio, color, radio * 0.6, true)
			draw_line(atras * radio * 3.0, direccion * radio, Color.WHITE, radio * 0.25, true)


## Una gota de veneno con su estela: una cola que se afina y se apaga detras,
## siempre igual. Hasta el 2026-11-10 era una nubecilla de vapor que cambiaba en
## cada fotograma (bolitas que giraban a los lados) y, con tantas seguidas, mareaba
## (Matias: «cambia esa niebla por una estela»).
func _pintar_rocio() -> void:
	var atras := -direccion
	var lado := direccion.orthogonal() * radio * 0.45
	var cola := atras * radio * LARGO_ESTELA_ROCIO
	var halo := Color(color_halo, 0.55)
	draw_polygon(PackedVector2Array([lado, cola, -lado]),
		PackedColorArray([halo, Color(color_halo, 0.0), halo]))
	draw_circle(Vector2.ZERO, radio * 0.5, Color(color, 0.9))
