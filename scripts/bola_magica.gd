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

## Se emite al romper algo, por si en el futuro hay sonido o particulas.
signal impacto(objetivo: Node2D)

@export var velocidad: float = 620.0
@export var radio: float = 11.0
## Si no choca con nada, se apaga sola despues de recorrer esto.
@export var alcance: float = 1200.0
## Si es true atraviesa y rompe todo lo que pilla. En false, rompe lo primero
## que toca y se apaga.
@export var atraviesa: bool = false

## Cuantos impactos reparte a lo que toca. El disparo normal hace 1; el ataque
## cargado, mas. No se pasa como argumento a romper() a proposito: el contrato
## del proyecto es "romper() sin parametros", y cambiarlo obligaria a tocar
## todo lo que sea rompible ahora y en el futuro.
@export var dano: int = 1

## Marca el disparo cargado. Ya no decide el color (eso lo hace `color`), pero
## sirve para saber que bola es cual sin mirar su tamano.
@export var cargada: bool = false

## Color del centro de la bola y de su resplandor. Los pone Principal con los
## del mago que dispara, asi que cada mago tiene sus bolas sin que la bola sepa
## de magos. Por defecto, los del disparo normal del mago oscuro.
@export var color: Color = Color(0.62, 0.84, 1.0)
@export var color_halo: Color = Color(0.35, 0.60, 1.0)

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

var _recorrido: float = 0.0
var _fase: float = 0.0

@onready var _forma: CollisionShape2D = $Forma


func _ready() -> void:
	area_entered.connect(_al_tocar)
	# Las rocas son cuerpos solidos y los enemigos areas, asi que hacen falta
	# las dos senales.
	body_entered.connect(_al_tocar_cuerpo)
	var circulo := CircleShape2D.new()
	circulo.radius = radio
	_forma.shape = circulo


func _physics_process(delta: float) -> void:
	var paso := velocidad * delta
	position += direccion * paso
	_recorrido += paso
	_fase += delta
	queue_redraw()
	if _recorrido >= alcance:
		queue_free()
		return
	if limite.has_area() and not limite.has_point(global_position):
		queue_free()


## Choque contra una roca o plataforma: la bola se apaga y la roca aguanta, asi
## que la roca sirve de parapeto.
func _al_tocar_cuerpo(cuerpo: Node2D) -> void:
	if cuerpo is Obstaculo and rompe_obstaculos:
		cuerpo.romper()
		impacto.emit(cuerpo)
	queue_free()


func _al_tocar(area: Area2D) -> void:
	# Duck typing como en todo el proyecto: la bola no pregunta contra que ha
	# chocado, solo si eso se puede romper.
	if not area.has_method("romper"):
		return
	for i in dano:
		if not is_instance_valid(area):
			break
		area.romper()
	impacto.emit(area)
	if not atraviesa:
		queue_free()


## Dibujada por codigo, como los corazones: no hay arte de proyectil en los
## packs y una bola de luz se resuelve con unos circulos y un rastro.
func _draw() -> void:
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
