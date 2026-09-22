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
@onready var _esquivar: Label = $Esquivar
@onready var _bajar: Label = $Bajar
@onready var _reiniciar: Label = $Reiniciar


## Reparte los carteles por el piso. La llama Piso al construirse.
func colocar(punto_entrada: Vector2, punto_salida: Vector2, alto_piso: float) -> void:
	_centrar(_mover, punto_entrada + Vector2(0.0, 78.0))
	_centrar(_reiniciar, punto_entrada + Vector2(0.0, 132.0))
	_centrar(_bola, punto_entrada + Vector2(0.0, 200.0))
	_centrar(_cargado, punto_entrada + Vector2(0.0, 256.0))
	# A media altura entre la entrada y la salida: el jugador lo lee cuando ya
	# se esta moviendo, justo antes de encontrarse las primeras rocas.
	_centrar(_esquivar, Vector2(0.0, -alto_piso * 0.5 + 640.0))
	_centrar(_bajar, punto_salida - Vector2(0.0, 130.0))


## Un Label coloca su esquina superior izquierda en position, asi que hay que
## restarle medio tamano para centrarlo de verdad en el punto pedido.
func _centrar(etiqueta: Label, punto: Vector2) -> void:
	etiqueta.position = punto - etiqueta.size * 0.5
