## El agujero negro del Mago Caido: el del mago oscuro, al reves. Se abre
## donde esta el jugador y tira de EL, no de los enemigos, y en el centro le
## quita vida.
##
## POR QUE HEREDA DE AgujeroNegro: se dibuja igual (es la misma magia,
## robada), y asi el jugador que haya jugado con el mago oscuro lo reconoce al
## momento. Lo que cambia es a quien atrae y que tarda mas en abrirse: mientras
## se abre no tira, y ese rato es el aviso para salir de el.
class_name PozoVacio
extends AgujeroNegro

## Lo que tarda en abrirse antes de tirar. Es el aviso: se ve crecer.
var aviso: float = 0.9
## Lo que tira del jugador, en px/s: en el centro y en el borde. Menos de lo
## que corre (265): se sale corriendo, pero cuesta.
var tiron_centro: float = 190.0
var tiron_borde: float = 90.0
var _jugador: Jugador = null


func _ready() -> void:
	_jugador = get_tree().get_first_node_in_group("jugador") as Jugador


func _physics_process(delta: float) -> void:
	_tiempo += delta
	if _tiempo >= _duracion or not is_instance_valid(_sala):
		queue_free()
		return
	queue_redraw()
	_nucleo.queue_redraw()
	if _tiempo < aviso or _jugador == null or _jugador.vida_actual <= 0 or _jugador.esta_cayendo():
		return
	var hacia := global_position - _jugador.centro_colision()
	var distancia := hacia.length()
	if distancia > _radio:
		return
	if distancia > 1.0:
		var tiron := lerpf(tiron_centro, tiron_borde, distancia / _radio) * _fuerza()
		# Con move_and_collide y no moviendolo a mano: asi no lo mete en una
		# roca ni lo saca de la sala.
		_jugador.move_and_collide(hacia / distancia * minf(tiron * delta, distancia))
	# La invulnerabilidad del jugador tras un golpe ya hace de ritmo: no
	# hace falta contar tics.
	if distancia <= NUCLEO and not _jugador.escudo_activo():
		_jugador.recibir_dano(int(_dano), false, "Mago caído (agujero negro)")


## Crece durante el aviso entero (no en el cuarto de segundo del del mago
## oscuro) y se cierra igual.
func _fuerza() -> float:
	return clampf(minf(_tiempo / aviso, (_duracion - _tiempo) / CIERRE), 0.0, 1.0)
