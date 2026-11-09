## Corre hacia el jugador haciendo eses, y cuesta apuntarle. Cuando ya esta
## cerca va recto, a picar. El escorpion (antes, la rata).
class_name ComportamientoZigzag
extends ComportamientoEnemigo

## Cuanto se aparta a los lados: 1 = tanto como avanza.
@export var amplitud: float = 1.1
## Lo rapido que cambia de lado, en radianes por segundo (4 = una ese cada
## segundo y medio, mas o menos).
@export var frecuencia: float = 4.0
## Mas cerca que esto, va recto.
@export var distancia_recta: float = 90.0
## Mas cerca que esto, pica: hace su "atacar". Solo es el dibujo; lo que quita
## sigue siendo el contacto, como antes. El escorpion clava en su pose 3, a
## 0,3 s, y en ese rato a 160 recorre unos 50 px: empieza antes de tocarte para
## que el aguijon caiga cuando te toca.
@export var alcance_picar: float = 75.0
## Segundos entre un picotazo y el siguiente, si sigue encima.
@export var recarga_picar: float = 0.8


func empezar(enemigo: Enemigo) -> void:
	super.empezar(enemigo)
	# Cada uno empieza su ese en un punto distinto.
	enemigo.estado["fase"] = randf() * TAU
	enemigo.estado["recarga"] = 0.0


func procesar(enemigo: Enemigo, delta: float) -> void:
	var fase: float = enemigo.estado["fase"] + frecuencia * delta
	enemigo.estado["fase"] = fase
	enemigo.estado["recarga"] = maxf(0.0, enemigo.estado["recarga"] - delta)
	var hacia := enemigo.hacia_objetivo()
	var distancia := hacia.length()
	# Pica sin pararse: va a por ti corriendo y pararlo antes es cosa tuya. Antes
	# de mirar si ya esta encima: ahi la distancia baja de 1 y no picaba mas.
	if distancia <= alcance_picar and enemigo.estado["recarga"] <= 0.0 and enemigo.pose_ataque() < 0:
		enemigo.estado["recarga"] = recarga_picar
		enemigo.mirar_a(hacia)
		enemigo.gesto(&"atacar")
	if distancia < 1.0:
		return
	var direccion := hacia / distancia
	if distancia > distancia_recta:
		direccion = (direccion + direccion.orthogonal() * sin(fase) * amplitud).normalized()
	enemigo.andar(direccion, delta)
