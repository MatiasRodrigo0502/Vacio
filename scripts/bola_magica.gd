## Bola magica: el unico ataque del jugador. Una por piso y siempre hacia abajo.
##
## POR QUE SOLO HACIA ABAJO:
## el juego va de bajar. Una bola que apunta a cualquier lado convertiria el
## piso en un tiroteo; bajando en linea recta es una herramienta para abrirse
## paso, que es lo que se busca. Y al ser una sola por piso, hay que decidir
## cuando gastarla en vez de disparar por disparar.
class_name BolaMagica
extends Area2D

## Se emite al romper algo, por si en el futuro hay sonido o particulas.
signal impacto(obstaculo: Node2D)

@export var velocidad: float = 620.0
@export var radio: float = 12.0
## Si no choca con nada, se apaga sola despues de recorrer esto.
@export var alcance: float = 1500.0
## Si es true atraviesa y rompe todo lo que pilla. En false, rompe lo primero
## que toca y se apaga: una bola, una roca.
@export var atraviesa: bool = false

var _recorrido: float = 0.0
var _fase: float = 0.0

@onready var _forma: CollisionShape2D = $Forma


func _ready() -> void:
	area_entered.connect(_al_tocar)
	var circulo := CircleShape2D.new()
	circulo.radius = radio
	_forma.shape = circulo


func _physics_process(delta: float) -> void:
	var paso := velocidad * delta
	position.y += paso
	_recorrido += paso
	_fase += delta
	queue_redraw()
	if _recorrido >= alcance:
		queue_free()


func _al_tocar(area: Area2D) -> void:
	# Duck typing, como en el resto del proyecto: la bola no pregunta si es una
	# roca o una plataforma, solo si se puede romper.
	if not area.has_method("romper"):
		return
	area.romper()
	impacto.emit(area)
	if not atraviesa:
		queue_free()


## Dibujada por codigo, como los corazones: no hay arte de proyectil en los
## packs y una bola de luz se resuelve con tres circulos y un rastro.
func _draw() -> void:
	var pulso := 1.0 + sin(_fase * 22.0) * 0.12

	# Rastro que se va apagando hacia arriba.
	for i in 5:
		var t := float(i) / 5.0
		draw_circle(Vector2(0.0, -radio * (0.9 + i * 0.85)),
			radio * (0.72 - t * 0.5) * pulso,
			Color(0.45, 0.72, 1.0, 0.30 - t * 0.24))

	draw_circle(Vector2.ZERO, radio * 1.75 * pulso, Color(0.35, 0.60, 1.0, 0.22))
	draw_circle(Vector2.ZERO, radio * pulso, Color(0.62, 0.84, 1.0, 0.95))
	draw_circle(Vector2(-radio * 0.22, -radio * 0.22), radio * 0.42 * pulso,
		Color(1.0, 1.0, 1.0, 0.95))
