## Datos de un tipo de enemigo.
##
## POR QUE UN RESOURCE Y NO UNA ESCENA POR ENEMIGO:
## todos los enemigos comparten el mismo cuerpo (moverse, hacer dano al tocar,
## morir); lo que cambia son los numeros, el dibujo y como atacan. Con una
## escena por enemigo habria que mantener once archivos casi identicos. Asi,
## anadir un enemigo nuevo es crear un .tres y dejarlo en resources/enemigos/:
## la mecanica lee la carpeta entera y no hay que tocar ni una linea de codigo.
class_name TipoEnemigo
extends Resource

## Cuerpo a cuerpo o a distancia. Es la division que ordena el combate: los de
## cuerpo a cuerpo son rapidos y hay que pararlos antes de que lleguen; los de
## distancia son lentos, se quedan lejos y pegan mas fuerte, y hay que ir a
## por ellos cubriendose con las rocas.
enum Ataque { CUERPO_A_CUERPO, DISTANCIA }

## Nombre legible, para depuracion.
@export var nombre: String = "Enemigo"

## Las animaciones. Ahora mismo todas tienen una sola: "moverse".
@export var animaciones: SpriteFrames = null

## Cuantos disparos aguanta.
@export var vida: int = 2

## Velocidad de persecucion en px/s. A 0 se queda quieto, como el cristal.
@export var velocidad: float = 78.0

## Vida que quita al tocar al jugador.
@export var dano: int = 1

## Alto que ocupa en el mundo. El sprite se escala a esto.
@export var alto: float = 54.0

## A partir de que distancia deja de perseguir (y de disparar). Un radio corto
## convierte al enemigo en una emboscada: no se entera hasta que lo tienes
## encima.
@export var radio_vision: float = 620.0

## Primer piso en el que puede aparecer. Sirve para que los enemigos duros no
## salgan en los pisos de arriba.
@export_range(1, 12) var piso_minimo: int = 1

## Color de sus efectos: el destello al apuntar y la explosion al morir.
@export var color_efectos: Color = Color(1.0, 0.9, 0.6)

@export_group("Ataque")
@export var ataque: Ataque = Ataque.CUERPO_A_CUERPO
## Lo que dispara. Solo lo usan los de distancia.
@export var proyectil: TipoProyectil = null
## Segundos entre un disparo y el siguiente.
@export var cadencia: float = 2.0
## Segundos que se queda quieto avisando antes de disparar. Es lo que hace
## justo el dano alto: siempre se ve venir.
@export var tiempo_apuntar: float = 0.5
## A que distancia del jugador intenta quedarse. Si te acercas, retrocede.
@export var distancia_preferida: float = 320.0

@export_group("Al morir")
## Cuantas crias suelta al morir. Las crias son el mismo enemigo en pequeno,
## con 1 de vida y sin dividirse otra vez.
@export var division: int = 0
## Radio de la explosion al morir. 0 = no explota.
@export var radio_explosion: float = 0.0
## Corazones que quita la explosion si pilla al jugador dentro.
@export var dano_explosion: int = 1

## La cria se fabrica una vez y se reutiliza: todas las crias de un tipo son
## iguales, y asi no se crea un Resource nuevo por cada slime que muere.
var _cria: TipoEnemigo = null


func es_a_distancia() -> bool:
	return ataque == Ataque.DISTANCIA and proyectil != null


## El mismo enemigo en pequeno: mas rapido, 1 de vida, sin crias ni
## explosion. Si las crias explotaran o se dividieran, matar un slime
## desataria una cadena que no se puede esquivar.
func cria() -> TipoEnemigo:
	if _cria == null:
		_cria = duplicate()
		_cria.nombre = nombre + " (cria)"
		_cria.vida = 1
		_cria.alto = alto * 0.62
		_cria.velocidad = velocidad * 1.25
		_cria.division = 0
		_cria.radio_explosion = 0.0
	return _cria
