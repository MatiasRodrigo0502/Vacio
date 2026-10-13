## Flota hacia el jugador ondulando y atravesando las rocas y, a ratos, se
## desvanece: casi invisible, ni se le puede dar ni hace dano, y va un poco
## mas deprisa. Hay que darle mientras se ve. El fantasma.
class_name ComportamientoFantasma
extends ComportamientoEnemigo

## Lo que se le ve al desvanecerse: casi nada, pero algo, para no perderlo.
const ALFA_DESVANECIDO: float = 0.15

## Segundos visible entre desvanecimiento y desvanecimiento.
@export var tiempo_visible: float = 3.2
## Segundos desvanecido.
@export var desvanecido: float = 1.4
## Lo que tarda en desvanecerse y en volver.
@export var transicion: float = 0.3
## Velocidad desvanecido, respecto a la de su tipo.
@export var factor_desvanecido: float = 1.3
## Cuanto ondula a los lados al avanzar.
@export var ondulacion: float = 0.35


func empezar(enemigo: Enemigo) -> void:
	super.empezar(enemigo)
	enemigo.estado["se_ve"] = true
	# A destiempo de los demas fantasmas de la sala.
	enemigo.estado["t"] = randf() * tiempo_visible
	enemigo.estado["fase"] = randf() * TAU
	enemigo.estado["alfa"] = 1.0


func procesar(enemigo: Enemigo, delta: float) -> void:
	var t: float = enemigo.estado["t"] + delta
	var se_ve: bool = enemigo.estado["se_ve"]
	if se_ve and t >= tiempo_visible:
		se_ve = false
		t = 0.0
	elif not se_ve and t >= desvanecido:
		se_ve = true
		t = 0.0
	enemigo.estado["t"] = t
	enemigo.estado["se_ve"] = se_ve

	# Visible, se apaga al final; desvanecido, vuelve al final.
	var alfa := 1.0
	if se_ve:
		alfa = lerpf(1.0, ALFA_DESVANECIDO, clampf((t - (tiempo_visible - transicion)) / transicion, 0.0, 1.0))
	else:
		alfa = lerpf(ALFA_DESVANECIDO, 1.0, clampf((t - (desvanecido - transicion)) / transicion, 0.0, 1.0))
	enemigo.estado["alfa"] = alfa

	var fase: float = enemigo.estado["fase"] + delta * 3.0
	enemigo.estado["fase"] = fase
	var hacia := enemigo.hacia_objetivo()
	if hacia.length() > 1.0:
		var direccion := hacia.normalized()
		direccion = (direccion + direccion.orthogonal() * sin(fase) * ondulacion).normalized()
		enemigo.andar(direccion, delta, 1.0 if se_ve else factor_desvanecido, true)
	enemigo.poner_sprite(Vector2(0.0, sin(fase * 1.3) * 3.0), Vector2.ONE, alfa)


## Se le puede dar mientras se ve mas que menos.
func tangible(enemigo: Enemigo) -> bool:
	return enemigo.estado.get("alfa", 1.0) > 0.5
