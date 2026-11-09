## Autoload Vista: si la pantalla del movil esta en vertical, el mundo se ve
## girado 90 grados (en el ordenador, nunca: ver puede_girar). Pedido por
## Matias el 2026-11-03 para el movil: «si el jugador pone el movil en
## vertical, que todas las entes giren 90º y listo, que no cambie nada de
## posicion, pero que cambie el POV, que cambie la vista de las paredes».
##
## COMO: en vertical, la camara gira 90 grados (CamaraJuego) y la sala, que es
## mas ancha que alta, queda a lo largo de la pantalla. Nada se mueve en el
## mundo: ni el mago, ni los enemigos, ni las rocas, ni las paredes. Lo que se
## ve de lado son las paredes, las rocas y el suelo, que giran con la vista.
## Lo que es un ente (el mago, los enemigos, los objetos, el cofre, el altar,
## los numeros que saltan) se gira lo mismo al reves y sigue de pie en la
## pantalla: lo hace cada uno con giro, al nacer y al cambiar (cambiada).
##
## Y LOS MANDOS: arriba en la pantalla tiene que seguir siendo arriba. El
## jugador gira lo que pide (teclas o joystick) con en_mundo(), y lo que mira
## en el mundo vuelve a la pantalla con en_pantalla() para elegir su dibujo.
##
## OJO: sin class_name a proposito, como los demas autoloads.
extends Node

## Ha cambiado la orientacion. Lleva el giro, en radianes.
signal cambiada(giro: float)

## Lo que esta girada la vista: 0 en horizontal, PI/2 en vertical.
var giro: float = 0.0


func _ready() -> void:
	get_viewport().size_changed.connect(_mirar)
	_mirar()


func vertical() -> bool:
	return giro != 0.0


## De la pantalla al mundo: un "arriba" del joystick o de las teclas, al
## arriba del mundo que se ve arriba en la pantalla.
func en_mundo(direccion: Vector2) -> Vector2:
	return direccion.rotated(giro)


## Del mundo a la pantalla: hacia donde se ve en la pantalla algo que va en
## esa direccion en el mundo.
func en_pantalla(direccion: Vector2) -> Vector2:
	return direccion.rotated(-giro)


## Pone 'nodo' de pie en la pantalla girandolo alrededor de 'pivote' (en el
## espacio de su padre); 'base' es donde esta sin girar. El mago lo usa con
## su centro: el circulo con el que choca esta 16 px por encima de los pies, y
## girando el dibujo desde los pies se veria a un lado de donde le dan.
func poner_de_pie(nodo: Node2D, base: Vector2, pivote: Vector2) -> void:
	nodo.rotation = giro
	nodo.position = pivote + (base - pivote).rotated(giro)


## Solo la version del movil gira (Matias, 2026-11-09: «lo de vertical era
## para la version de movil»). En el ordenador una ventana tambien puede quedar
## mas alta que ancha (pegada a media pantalla, un monitor de pie) y entonces
## se giraba todo; ahi se sigue viendo en horizontal, con mas suelo por arriba
## y por abajo. Para probarlo en el ordenador vale lo mismo que para los mandos
## tactiles: -- --tactil (ControlesTactiles.hace_falta).
func puede_girar() -> bool:
	return ControlesTactiles.hace_falta()


func _mirar() -> void:
	var tamano := get_viewport().get_visible_rect().size
	var nuevo := PI * 0.5 if tamano.y > tamano.x and puede_girar() else 0.0
	if nuevo == giro:
		return
	giro = nuevo
	cambiada.emit(giro)
	# Lo que esta de pie lo sigue sin tener que escucharlo cada uno.
	get_tree().call_group("de_pie", "set_rotation", giro)
