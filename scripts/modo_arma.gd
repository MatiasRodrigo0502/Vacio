## Una forma de disparar de un arma (ArmaMago). Las miticas tienen varias, y se
## cambia de una a otra con la rueda del raton.
##
## Los multiplicadores son sobre el disparo de un mago normal: 10 de dano y uno
## cada medio segundo. Si un disparo sale en varias bolas, cada una quita menos.
class_name ModoArma
extends Resource

@export var nombre: String = "Normal"
## Cuantas bolas salen a la vez, repartidas en 'apertura' grados.
@export var proyectiles: int = 1
@export var apertura: float = 0.0
## Cuantos disparos seguidos salen por cada uno, separados 'pausa_rafaga' s.
@export var rafaga: int = 1
@export var pausa_rafaga: float = 0.08
## Multiplican el tiempo entre disparos (por encima de 1, mas lento), el dano,
## la velocidad y el tamano de cada bola.
@export var cadencia: float = 1.0
@export var dano: float = 1.0
@export var velocidad: float = 1.0
@export var radio: float = 1.0
## Cuanto serpentea, en px a cada lado (0 = recta). Con dos bolas, cada una a un
## lado: se cruzan.
@export var onda: float = 0.0
## Atraviesa enemigos, como la bola cargada.
@export var atraviesa: bool = false
## Cuantas veces rebota en muros y rocas antes de apagarse.
@export var rebotes: int = 0
## Lo que gira hacia el enemigo mas cercano, en grados por segundo. 0 = recta.
@export var busca: float = 0.0
## Radio de la explosion al acabarse. Quita la mitad del dano de la bola a los
## que pille dentro. 0 = no explota.
@export var explosion: float = 0.0
## Como se pinta en este modo (BolaMagica.Estilo). -1 = el del arma.
@export var estilo: int = -1
