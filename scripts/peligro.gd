## Base de los peligros del suelo: pinchos, lava y vacio.
##
## POR QUE UNA BASE COMUN:
## los tres ocupan un trozo de suelo, detectan al jugador y se dibujan por
## codigo con los colores de su sala. Lo que cambia es que le hacen: los
## pinchos pegan a ratos, la lava siempre y el vacio te tira. Cada uno en su
## archivo; aqui lo que comparten.
##
## Son Area2D y no cuerpos solidos: se pueden pisar, que es justo el riesgo.
## Se crean por codigo (Pinchos.new()...), como los muros de las salas: sus
## medidas salen del reparto y una escena fija no aportaria nada.
class_name Peligro
extends Area2D

## Caja que ocupa en el suelo, centrada en el nodo.
var tamano: Vector2 = Vector2(96.0, 96.0)
## Colores de la sala, para que el peligro sea de la misma piedra que el suelo.
var color_suelo: Color = Color(0.16, 0.13, 0.12)
var color_borde: Color = Color(0.55, 0.40, 0.28)

var _fase: float = 0.0


func _ready() -> void:
	# Solo vigila al jugador. Nadie tiene que detectarlo a el.
	collision_layer = 0
	collision_mask = 1
	monitorable = false
	var forma := CollisionShape2D.new()
	forma.shape = _crear_forma()
	add_child(forma)


func _physics_process(delta: float) -> void:
	_fase += delta
	queue_redraw()
	for cuerpo in get_overlapping_bodies():
		_al_pisar(cuerpo)


## La caja en coordenadas del mundo. La usa el piso para no poner nada encima.
func rect_global() -> Rect2:
	return Rect2(global_position - tamano * 0.5, tamano)


## Forma de colision. Por defecto, la caja algo mas pequena que el dibujo:
## como con las rocas, mejor que el jugador sienta que ha pasado raspando a
## que le queme el aire.
func _crear_forma() -> Shape2D:
	var rectangulo := RectangleShape2D.new()
	rectangulo.size = tamano * 0.82
	return rectangulo


## Lo que le hace a quien lo pisa. Cada peligro lo sobrescribe.
func _al_pisar(_cuerpo: Node2D) -> void:
	pass
