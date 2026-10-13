## Onda de un pisoton (el del golem): un aro que crece desde el suelo y quita
## vida al jugador si le pilla el borde al pasar.
##
## POR QUE EL BORDE Y NO EL CIRCULO ENTERO: una onda se esquiva alejandose
## antes de que llegue, o estando muy lejos. Si dañara todo lo de dentro, con
## estar cerca al pisar ya no habria escapatoria. Asi el aviso (el golem brilla
## y marca hasta donde llega) sirve de algo.
class_name OndaChoque
extends Node2D

## Lo que el jugador ocupa alrededor de su centro.
const RADIO_JUGADOR: float = 15.0
## Lo ancho que es el borde que daña.
const GROSOR: float = 18.0
## Lo que se achata en vertical: va por el suelo, visto en 3/4. El daño se
## mide con el mismo achatado que el dibujo, o pegaria donde no se ve el aro.
const ACHATADO: float = 0.55

var radio_maximo: float = 170.0
var duracion: float = 0.45
var dano: int = 1
var color: Color = Color(1.0, 0.6, 0.2)
## Como sale en el registro de partidas. La pone quien da el pisoton.
var origen: String = "Onda"

var _tiempo: float = 0.0
var _ha_dado: bool = false
var _jugador: Node2D = null


func _ready() -> void:
	# Por encima del suelo y las rocas, por debajo de los enemigos.
	z_index = 4
	_jugador = get_tree().get_first_node_in_group("jugador")


func _physics_process(delta: float) -> void:
	_tiempo += delta
	if _tiempo >= duracion:
		queue_free()
		return
	queue_redraw()
	if _ha_dado or not is_instance_valid(_jugador) or not _jugador.has_method("centro_colision"):
		return
	var hacia: Vector2 = _jugador.centro_colision() - global_position
	var distancia := Vector2(hacia.x, hacia.y / ACHATADO).length()
	if absf(distancia - _radio()) <= GROSOR * 0.5 + RADIO_JUGADOR:
		_ha_dado = true
		# El escudo del mago blanco la para.
		if not (_jugador.has_method("escudo_activo") and _jugador.escudo_activo()):
			_jugador.recibir_dano(dano, false, origen)


func _radio() -> float:
	# Sale rapido y frena al final, como una onda de verdad.
	var t := _tiempo / duracion
	return radio_maximo * (1.0 - (1.0 - t) * (1.0 - t))


func _draw() -> void:
	var t := _tiempo / duracion
	var r := _radio()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, ACHATADO))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(color, 0.85 * (1.0 - t)), GROSOR * (1.0 - 0.5 * t), true)
	draw_arc(Vector2.ZERO, r * 0.82, 0.0, TAU, 48, Color(1.0, 0.95, 0.8, 0.5 * (1.0 - t)), 2.0, true)
	draw_set_transform(Vector2.ZERO)
