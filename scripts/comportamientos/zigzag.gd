## Corre hacia el jugador haciendo eses, y cuesta apuntarle. Cuando ya esta
## cerca va recto, a morder. La rata.
class_name ComportamientoZigzag
extends ComportamientoEnemigo

## Cuanto se aparta a los lados: 1 = tanto como avanza.
@export var amplitud: float = 1.1
## Lo rapido que cambia de lado, en radianes por segundo (4 = una ese cada
## segundo y medio, mas o menos).
@export var frecuencia: float = 4.0
## Mas cerca que esto, va recto.
@export var distancia_recta: float = 90.0


func empezar(enemigo: Enemigo) -> void:
	super.empezar(enemigo)
	# Cada rata empieza su ese en un punto distinto.
	enemigo.estado["fase"] = randf() * TAU


func procesar(enemigo: Enemigo, delta: float) -> void:
	var fase: float = enemigo.estado["fase"] + frecuencia * delta
	enemigo.estado["fase"] = fase
	var hacia := enemigo.hacia_objetivo()
	var distancia := hacia.length()
	if distancia < 1.0:
		return
	var direccion := hacia / distancia
	if distancia > distancia_recta:
		direccion = (direccion + direccion.orthogonal() * sin(fase) * amplitud).normalized()
	enemigo.andar(direccion, delta)
