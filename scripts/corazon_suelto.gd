## Un corazon en el suelo: lo que cae a veces al limpiar una sala. Cura uno.
##
## Con la vida llena no se coge: se queda en el suelo para cuando haga falta,
## como en Isaac. Recogerlo sin necesitarlo seria tirarlo.
##
## Se crea por codigo (CorazonSuelto.new()): no tiene nada que una escena
## aportara. El dibujo es el mismo que los corazones del HUD, para que se
## reconozca sin pensar.
class_name CorazonSuelto
extends Area2D

## Corazones que cura.
const CURA: int = 1
## Ancho del dibujo. Algo mas grande que los del HUD: en el suelo, con la
## camara lejos en los pisos hondos, tiene que verse.
const ANCHO: float = 30.0
## Lo que tarda en aparecer, con un pequeno salto.
const APARECER: float = 0.35

var _fase: float = 0.0
var _recogido: bool = false


func _ready() -> void:
	# Solo vigila al jugador.
	collision_layer = 0
	collision_mask = 1
	monitorable = false
	# Encima del suelo y los peligros, debajo de los enemigos (5).
	z_index = 4
	var forma := CollisionShape2D.new()
	var circulo := CircleShape2D.new()
	circulo.radius = 20.0
	forma.shape = circulo
	add_child(forma)


## Se mira en cada paso quien lo esta tocando, y no con body_entered: si el
## jugador llega con la vida llena y se queda encima, y luego le dan, tiene
## que poder cogerlo sin salir y volver a entrar. body_entered solo avisa una
## vez, al entrar.
func _physics_process(delta: float) -> void:
	_fase += delta
	queue_redraw()
	if _recogido:
		return
	for cuerpo in get_overlapping_bodies():
		if cuerpo.has_method("curar") and cuerpo.curar(CURA):
			_recogido = true
			Sonido.tocar(&"corazon")
			queue_free()
			return


func _draw() -> void:
	# Aparece creciendo con un pequeno pasado de largo, y luego flota.
	var aparecer := clampf(_fase / APARECER, 0.0, 1.0)
	var escala := aparecer + sin(aparecer * PI) * 0.3
	var flota := sin(_fase * 2.6) * 4.0 if aparecer >= 1.0 else 0.0
	var centro := Vector2(0.0, flota - 6.0)

	# Sombra en el suelo, que se encoge cuando sube: asi se lee que flota.
	draw_set_transform(Vector2(0.0, 10.0), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, ANCHO * 0.42 * escala * (1.0 - flota * 0.03),
		Color(0.0, 0.0, 0.0, 0.35))
	draw_set_transform(Vector2.ZERO)
	# Un halo rojo que late: se ve desde lejos aunque la sala este llena.
	var latido := 0.5 + 0.5 * sin(_fase * 4.0)
	draw_circle(centro, ANCHO * 0.75 * escala, Color(1.0, 0.25, 0.28, 0.12 + 0.1 * latido))

	Corazones.pintar_corazon(self, centro + Vector2(0.0, 1.5), ANCHO * escala * 1.12,
		Color(0.25, 0.04, 0.05))
	Corazones.pintar_corazon(self, centro, ANCHO * escala, Corazones.COLOR_LLENO)
	draw_circle(centro + Vector2(-ANCHO * 0.18, -ANCHO * 0.22) * escala,
		ANCHO * 0.09 * escala, Corazones.COLOR_BRILLO)
