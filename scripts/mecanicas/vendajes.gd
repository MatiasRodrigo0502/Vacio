## Mecanica: al limpiar una sala, a veces cae un vendaje que cura 60.
##
## POR QUE HACE FALTA:
## con muchos enemigos, disparos que quitan hasta 50 y un suelo que hace dano,
## curarse dependia de que saliera el vendaje entre los objetos. Asi limpiar
## una sala, ademas de abrir las puertas, a veces te devuelve algo. Es lo que
## hace Isaac.
##
## POR QUE UN VENDAJE Y NO UN CORAZON (Matias, 2026-10-14): hasta entonces caia
## un corazon que curaba 30, lo que antes era un corazon de los tres. En los
## pisos hondos se quedaba corto, y ahora cae el mismo vendaje que hay entre
## los objetos (resources/objetos/vendaje.tres): cura el doble y se reconoce
## igual en todas partes. Como el corazon, con la vida llena no se coge y se
## queda en el suelo (Objeto, solo_cura).
##
## Como las demas mecanicas, ni el gestor ni el piso saben que existe. Para
## que caigan mas o menos, `probabilidad`; para quitarlos, `activa = false`.
class_name MecanicaVendajes
extends Mecanica

## Probabilidad de que caiga uno al limpiar una sala de pelea. Una partida
## tiene 63 salas con enemigos: con 0,25, unos 16.
@export_range(0.0, 1.0) var probabilidad: float = 0.25
## Lo que cae. El vendaje de los objetos.
@export var objeto: ObjetoMejora


func aplicar_a_piso(piso: Node) -> void:
	# Todas las salas: solo avisan de que se han limpiado las que tenian
	# enemigos, asi que da igual si esta mecanica se aplica antes o despues de
	# la que los reparte.
	for sala in piso.salas():
		sala.despejada.connect(_al_despejar.bind(piso))


## El azar es suerte, no semilla del piso: los pisos son fijos, pero lo que
## cae al limpiar una sala puede cambiar de una partida a otra.
func _al_despejar(sala: Sala, piso: Node) -> void:
	# En cooperativo lo decide el anfitrion y lo manda (MundoRed).
	if objeto == null or not Red.manda() or randf() >= probabilidad:
		return
	# En el centro, que es donde se mira al acabar la pelea; si ahi hay una
	# roca, un peligro o la bajada, lo mas cerca posible.
	var sitio: Variant = piso.sitio_libre_cerca(sala.global_position, sala, 30.0)
	if sitio == null:
		return
	MundoRed.soltar_objeto(sala, objeto, sitio)
