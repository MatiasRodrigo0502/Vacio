## Datos de un proyectil enemigo: el veneno de la serpiente, el magma del golem,
## el rayo del cristal.
##
## POR QUE UN RESOURCE APARTE Y NO CAMPOS EN TipoEnemigo:
## dos enemigos pueden tirar lo mismo (la serpiente y la planta venenosa
## escupen el mismo veneno), y un proyectil nuevo no deberia obligar a tocar
## ningun enemigo. Un .tres en resources/proyectiles/ y se apunta desde el
## enemigo que lo use. Todos se mueven y se dibujan con el mismo script
## (proyectil_enemigo.gd); lo que cambia son estos numeros.
class_name TipoProyectil
extends Resource

## Como vuela y como se dibuja.
## - BOLA: en linea recta; la paran las rocas y los muros.
## - RAYO: igual, pero muy rapido y dibujado como un relampago.
## - PARABOLA: lanzado por el aire hasta donde estabas al tirarlo. Pasa por
##   encima de las rocas (va por arriba) y hace dano al caer.
enum Estilo { BOLA, RAYO, PARABOLA }

@export var nombre: String = "Proyectil"
@export var estilo: Estilo = Estilo.BOLA

## Color del centro y del resplandor.
@export var color: Color = Color(0.5, 1.0, 0.4)
@export var color_halo: Color = Color(0.2, 0.7, 0.15)

## px/s. En la parabola es la velocidad sobre el suelo.
@export var velocidad: float = 320.0
@export var radio: float = 9.0
## Corazones que quita al acertar.
@export var dano: int = 1
## Distancia maxima. La parabola no la usa: cae donde apunto.
@export var alcance: float = 900.0
## El efecto que suena al dispararlo: el nombre de un archivo de
## assets/sonido/efectos/, sin el .wav. Cada proyectil el suyo, para saber de
## oido que te viene sin mirarlo.
@export var sonido: StringName = &"disparo_enemigo"

@export_group("Efectos")
## Segundos que el jugador va frenado (envenenado) tras recibirlo. 0 = nada.
@export var ralentiza: float = 0.0
## Al caer deja un charco de lava de este radio. 0 = no deja nada.
@export var charco_radio: float = 0.0
## Segundos que dura el charco antes de enfriarse.
@export var charco_duracion: float = 3.0
