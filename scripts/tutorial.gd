## Carteles de tutorial pintados sobre el suelo del primer piso.
##
## POR QUE EN EL MUNDO Y NO EN EL HUD:
## un HUD tapa el juego y hay que decidir cuando quitarlo. Sobre el suelo, cada
## aviso esta donde hace falta (el de moverse en la entrada, el de la salida
## junto al circulo) y se resuelve solo: al bajar de piso el jugador los deja
## atras y no vuelven a aparecer. Cero logica de temporizadores.
##
## Los textos y los tamanos estan en Tutorial.tscn, no aqui: se pueden reescribir
## desde el editor sin tocar codigo. Este script solo los coloca, porque las
## posiciones dependen del tamano del piso, que sale del .tres.
class_name Tutorial
extends Node2D

@onready var _mover: Label = $Mover
@onready var _bola: Label = $Bola
@onready var _cargado: Label = $Cargado
@onready var _puertas: Label = $Puertas
@onready var _esquivar: Label = $Esquivar
@onready var _bajar: Label = $Bajar
@onready var _reiniciar: Label = $Reiniciar


## Reparte los carteles. La llama Piso al construirse, con el centro de la
## sala de inicio, el tamano de las salas y el centro de la sala de salida,
## todo en coordenadas del piso.
##
## Los de controles van en la sala de inicio, debajo de donde aparece el
## jugador, que es lo primero que lee. El de las rocas arriba, y el de las
## puertas abajo del todo: es lo ultimo que se lee antes de salir de la sala,
## que es justo cuando hace falta saberlo. El de bajar, junto al agujero.
func colocar(inicio: Vector2, tamano_sala: Vector2, salida: Vector2) -> void:
	_centrar(_mover, inicio + Vector2(0.0, 78.0))
	_centrar(_reiniciar, inicio + Vector2(0.0, 132.0))
	_centrar(_bola, inicio + Vector2(0.0, 200.0))
	_centrar(_cargado, inicio + Vector2(0.0, 256.0))
	_centrar(_puertas, inicio + Vector2(0.0, tamano_sala.y * 0.5 - 70.0))
	_centrar(_esquivar, inicio + Vector2(0.0, -tamano_sala.y * 0.5 + 90.0))
	_centrar(_bajar, salida - Vector2(0.0, 130.0))


## Un Label coloca su esquina superior izquierda en position, asi que hay que
## restarle medio tamano para centrarlo de verdad en el punto pedido.
func _centrar(etiqueta: Label, punto: Vector2) -> void:
	etiqueta.position = punto - etiqueta.size * 0.5
