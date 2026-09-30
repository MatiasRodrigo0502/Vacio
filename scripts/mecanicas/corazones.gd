## Mecanica: al limpiar una sala, a veces cae un corazon que cura uno.
##
## POR QUE HACE FALTA:
## con muchos enemigos, disparos que quitan dos y un suelo que hace dano, y
## solo tres o cuatro corazones, curarse dependia de que saliera el vendaje o
## el corazon de roca entre los objetos. Asi limpiar una sala, ademas de abrir
## las puertas, a veces te devuelve algo. Es lo que hace Isaac.
##
## Como las demas mecanicas, ni el gestor ni el piso saben que existe. Para
## que caigan mas o menos, `probabilidad`; para quitarlos, `activa = false`.
class_name MecanicaCorazones
extends Mecanica

## Probabilidad de que caiga un corazon al limpiar una sala de pelea. Una
## partida tiene 63 salas con enemigos: con 0,25, unos 16 corazones.
@export_range(0.0, 1.0) var probabilidad: float = 0.25


func aplicar_a_piso(piso: Node) -> void:
	# Todas las salas: solo avisan de que se han limpiado las que tenian
	# enemigos, asi que da igual si esta mecanica se aplica antes o despues de
	# la que los reparte.
	for sala in piso.salas():
		sala.despejada.connect(_al_despejar.bind(piso))


## El azar es suerte, no semilla del piso: los pisos son fijos, pero lo que
## cae al limpiar una sala puede cambiar de una partida a otra.
func _al_despejar(sala: Sala, piso: Node) -> void:
	if randf() >= probabilidad:
		return
	# En el centro, que es donde se mira al acabar la pelea; si ahi hay una
	# roca, un peligro o la bajada, lo mas cerca posible.
	var sitio: Variant = piso.sitio_libre_cerca(sala.global_position, sala, 24.0)
	if sitio == null:
		return
	var corazon := CorazonSuelto.new()
	corazon.position = sala.to_local(sitio)
	sala.add_child(corazon)
