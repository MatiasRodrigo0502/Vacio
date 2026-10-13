## No persigue a nadie: cruza la sala en diagonal y rebota en muros y rocas,
## como una pelota. Hay que leer por donde va a pasar y cortarle el paso, o
## apartarse. El slime naranja.
class_name ComportamientoRebote
extends ComportamientoEnemigo

## Velocidad respecto a la de su tipo.
@export var factor_velocidad: float = 1.15
## Lo que bota al avanzar, en px: se lee como una pelota de goma.
@export var bote: float = 7.0
## Botes por segundo.
@export var ritmo_bote: float = 3.0


func empezar(enemigo: Enemigo) -> void:
	super.empezar(enemigo)
	# Una de las cuatro diagonales: en recta horizontal o vertical se quedaria
	# yendo y viniendo por la misma linea.
	var x := 1.0 if randf() < 0.5 else -1.0
	var y := 1.0 if randf() < 0.5 else -1.0
	enemigo.estado["dir"] = Vector2(x, y).normalized()
	enemigo.estado["t"] = randf()


func procesar(enemigo: Enemigo, delta: float) -> void:
	enemigo.estado["dir"] = enemigo.andar_rebotando(enemigo.estado["dir"], delta, factor_velocidad)
	var t: float = enemigo.estado["t"] + delta
	enemigo.estado["t"] = t
	var arriba := absf(sin(t * ritmo_bote * PI))
	# Abajo del bote se aplasta un poco.
	var aplastado := 1.0 - arriba
	enemigo.poner_sprite(Vector2(0.0, -bote * arriba),
		Vector2(1.0 + 0.12 * aplastado, 1.0 - 0.12 * aplastado), 1.0)
