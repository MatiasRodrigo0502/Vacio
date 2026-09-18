## Un objeto que el jugador recoge y le mejora para el resto de la partida.
##
## POR QUE UN RESOURCE:
## lo mismo que con los tipos de enemigo. Todos los objetos hacen lo mismo
## (esperar en el suelo y sumar numeros al jugador al tocarlos); lo unico que
## cambia son esos numeros, el nombre y el color. Anadir un objeto nuevo es
## dejar otro .tres en resources/objetos/, sin tocar codigo.
class_name ObjetoMejora
extends Resource

## Nombre que se ensena al recogerlo.
@export var nombre: String = "Objeto"

## Frase corta que explica que hace, para el aviso del HUD.
@export var descripcion: String = ""

## Color con el que se tine el objeto en el suelo. Es la unica pista visual de
## que hace, asi que conviene mantener el codigo: rojo vida, verde velocidad,
## azul disparo.
@export var color: Color = Color(0.6, 0.8, 1.0)

@export_group("Lo que mejora")
## Corazones que suma al maximo. Ademas cura esa misma cantidad.
@export var vida_maxima_extra: int = 0
## Corazones que cura sin subir el maximo.
@export var cura: int = 0
## Velocidad de movimiento que suma, en px/s.
@export var velocidad_extra: float = 0.0
## Multiplica la cadencia de disparo. Por debajo de 1 dispara mas rapido.
@export var cadencia_multiplicador: float = 1.0
## Velocidad que suma a la bola, en px/s.
@export var velocidad_bola_extra: float = 0.0
## Radio que suma a la bola. Bola mas gorda, mas facil acertar.
@export var radio_bola_extra: float = 0.0

@export_group("Cuando aparece")
## Primer piso en el que puede salir.
@export_range(1, 12) var piso_minimo: int = 1
