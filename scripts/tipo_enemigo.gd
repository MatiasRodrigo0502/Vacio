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

## Las animaciones: una por direccion (caminar_abajo, atacar_abajo, dano_abajo,
## muerte_abajo...), de herramientas/generar_enemigos.py. Las de los enemigos de
## antes (resources/enemigos_antiguos/) tienen una sola, "moverse", y se voltean.
@export var animaciones: SpriteFrames = null

## Cuanta vida tiene. Un disparo normal quita 10 (de 10 a 13).
@export var vida: int = 20

## Velocidad de persecucion en px/s. A 0 se queda quieto, como el cristal.
@export var velocidad: float = 78.0

## Vida que quita al tocar al jugador.
@export var dano: int = 25

## Alto del cuerpo en el mundo: de esto salen el circulo que choca y donde tiene
## los pies.
@export var alto: float = 54.0

## El dibujo, si no llena su casilla (las hojas de ocho direcciones traen margen
## para los brazos del golpe y la sombra): a que escala se pinta, y cuanto se
## mueve para que el centro del cuerpo caiga en el del circulo que choca. Escala
## 0 = que la casilla entera mida 'alto'.
@export var escala_dibujo: float = 0.0
@export var desfase_dibujo: Vector2 = Vector2.ZERO

## Primer piso en el que puede aparecer. Sirve para que los enemigos duros no
## salgan en los pisos de arriba.
@export_range(1, 12) var piso_minimo: int = 1
## Ultimo piso en el que puede aparecer. Cada enemigo tiene una variante por capa
## de la Tierra (corteza, manto, nucleo): sin esto, las de arriba seguirian
## saliendo abajo.
@export_range(1, 12) var piso_maximo: int = 12
## Cuantos salen juntos por cada sitio que le toca en una sala: el enjambre de
## murcielagos. Cuentan como uno al repartir, porque entre todos tienen la vida
## de un enemigo normal.
@export var grupo: int = 1
## Va por el aire (el murcielago) o flota (el fantasma): los agujeros del
## suelo no le estorban ni se cae en ellos, y la lava no le quema.
@export var vuela: bool = false

## Color de sus efectos: el destello al apuntar y la explosion al morir.
@export var color_efectos: Color = Color(1.0, 0.9, 0.6)

@export_group("Ataque")
@export var ataque: Ataque = Ataque.CUERPO_A_CUERPO
## Lo que dispara. Solo lo usan los de distancia.
@export var proyectil: TipoProyectil = null
## Segundos entre un disparo y el siguiente.
@export var cadencia: float = 2.0
## Segundos que se queda quieto avisando antes de disparar. Es lo que hace
## justo el dano alto: siempre se ve venir. 0 = dispara en cuanto le toca, sin
## avisar; si es un rayo, su linea sale a la vez que el disparo (el cristal,
## desde el 2026-10-09).
@export var tiempo_apuntar: float = 0.5
## La pose de su "atacar" en la que sale el disparo en el dibujo. Solo cuenta si
## dispara sin avisar (tiempo_apuntar 0): el gesto empieza ahi, con el disparo, y lo
## de antes (cargar) no se ve, porque seria un aviso. El rayo del cristal.
@export var pose_disparo: int = 0
## A que distancia del jugador intenta quedarse. Si te acercas, retrocede.
@export var distancia_preferida: float = 320.0

@export_group("Comportamiento")
## Como se mueve y ataca: un recurso de scripts/comportamientos/ (saltos,
## zigzag, picado, abanico...). Vacio = lo de siempre: cuerpo a cuerpo va
## directo a por ti; a distancia se queda lejos y dispara. Los de distancia lo
## siguen siendo para el reparto (como mucho la mitad de cada sala), lleven el
## comportamiento que lleven.
@export var comportamiento: ComportamientoEnemigo = null

@export_group("Jefe")
## Es un jefe: lo coloca su piso (DatosPiso.jefe), no el reparto al azar, y
## su vida sale en una barra arriba (BarraJefe). Ni el agujero negro del mago
## oscuro ni la burbuja del blanco lo mueven, y el frio del blanco le dura
## menos (FRIO_JEFE en enemigo.gd).
@export var jefe: bool = false
## La frase que sale debajo de su nombre al presentarse.
@export var titulo: String = ""

@export_group("Botin")
## Las monedas que da al morir, para el gacha de skins (se quedan entre
## partidas, en Coleccion). Pocas los debiles y mas los fuertes: la vida entre 10.
@export var monedas: int = 1
## Los diamantes que da al morir, para el gacha de armas. Solo los jefes.
@export var diamantes: int = 0

@export_group("Al morir")
## Cuantas crias suelta al morir. Las crias son el mismo enemigo en pequeno,
## con 1 de vida y sin dividirse otra vez.
@export var division: int = 0
## Radio de la explosion al morir. 0 = no explota.
@export var radio_explosion: float = 0.0
## Vida que quita la explosion si pilla al jugador dentro.
@export var dano_explosion: int = 25

## La cria se fabrica una vez y se reutiliza: todas las crias de un tipo son
## iguales, y asi no se crea un Resource nuevo por cada slime que muere.
var _cria: TipoEnemigo = null
## True en las crias. Las usa la mecanica de objetos: las crias no sueltan
## ventajas, o matar slimes seria la forma de conseguirlas.
var es_cria: bool = false


func es_a_distancia() -> bool:
	return ataque == Ataque.DISTANCIA and proyectil != null


## El mismo enemigo en pequeno: mas rapido, 10 de vida, sin crias ni
## explosion. Si las crias explotaran o se dividieran, matar un slime
## desataria una cadena que no se puede esquivar.
func cria() -> TipoEnemigo:
	if _cria == null:
		_cria = duplicate()
		_cria.nombre = nombre + " (cria)"
		_cria.vida = 10
		_cria.monedas = 1
		_cria.diamantes = 0
		_cria.alto = alto * 0.62
		_cria.velocidad = velocidad * 1.25
		_cria.division = 0
		_cria.radio_explosion = 0.0
		_cria.es_cria = true
	return _cria
