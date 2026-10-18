## Se entierra, avanza bajo el suelo hacia el jugador (se ve el monticulo de
## tierra moverse, tambien por debajo de las rocas) y sale debajo de el,
## avisando antes con un aro en el suelo. Fuera, se queda plantada un rato.
## Bajo tierra no se le puede dar ni hace dano. La planta azul.
class_name ComportamientoExcavar
extends ComportamientoEnemigo

## Lo que tarda en hundirse y en salir.
const HUNDIRSE: float = 0.3
const SALIR: float = 0.18
const TIERRA := Color(0.36, 0.26, 0.18)

## Segundos fuera, plantada, entre excavacion y excavacion.
@export var tiempo_fuera: float = 1.8
## Segundos bajo tierra como mucho: si no te alcanza antes, sale donde este.
@export var tiempo_bajo_tierra: float = 2.2
## Segundos de aviso (el aro) antes de salir.
@export var aviso: float = 0.5
## Velocidad bajo tierra, respecto a la de su tipo.
@export var factor_bajo_tierra: float = 1.0
## Radio del aro de aviso, en px.
@export var radio_aviso: float = 44.0


func empezar(enemigo: Enemigo) -> void:
	super.empezar(enemigo)
	enemigo.estado["fase"] = &"fuera"
	enemigo.estado["t"] = randf() * tiempo_fuera


func procesar(enemigo: Enemigo, delta: float) -> void:
	var t: float = enemigo.estado["t"] + delta
	enemigo.estado["t"] = t
	var alto := enemigo.tipo.alto
	match enemigo.estado["fase"]:
		&"fuera":
			enemigo.poner_sprite(Vector2.ZERO, Vector2.ONE, 1.0)
			if t >= tiempo_fuera:
				_pasar(enemigo, &"hundiendose")
		&"hundiendose":
			var k := clampf(t / HUNDIRSE, 0.0, 1.0)
			# Baja hacia los pies y se aplasta: se mete en el suelo.
			enemigo.poner_sprite(Vector2(0.0, alto * 0.4 * k), Vector2(1.0 + 0.15 * k, 1.0 - k), 1.0 - k)
			if t >= HUNDIRSE:
				_pasar(enemigo, &"bajo_tierra")
		&"bajo_tierra":
			enemigo.poner_sprite(Vector2.ZERO, Vector2.ONE, 0.0)
			var hacia := enemigo.hacia_objetivo()
			if hacia.length() > 20.0:
				enemigo.andar(hacia.normalized(), delta, factor_bajo_tierra, true)
			if hacia.length() <= 20.0 or t >= tiempo_bajo_tierra:
				_pasar(enemigo, &"aviso")
		&"aviso":
			# Sigue escondida: lo que se ve es el aro.
			enemigo.poner_sprite(Vector2.ZERO, Vector2.ONE, 0.0)
			if t >= aviso:
				_pasar(enemigo, &"saliendo")
				enemigo.sonar(&"emerger")
		&"saliendo":
			var k := clampf(t / SALIR, 0.0, 1.0)
			enemigo.poner_sprite(Vector2(0.0, alto * 0.4 * (1.0 - k)), Vector2(1.0, k), k)
			if t >= SALIR:
				_pasar(enemigo, &"fuera")


func _pasar(enemigo: Enemigo, fase: StringName) -> void:
	enemigo.estado["fase"] = fase
	enemigo.estado["t"] = 0.0


## Fuera y saliendo (el mordisco al salir), si. Hundida o bajo tierra, no.
func tangible(enemigo: Enemigo) -> bool:
	var fase: StringName = enemigo.estado.get("fase", &"fuera")
	return fase == &"fuera" or fase == &"saliendo"


func dibujar(enemigo: Enemigo) -> void:
	var fase: StringName = enemigo.estado.get("fase", &"fuera")
	if fase != &"bajo_tierra" and fase != &"aviso":
		return
	var pies := Vector2(0.0, enemigo.tipo.alto * 0.42)
	var t: float = enemigo.estado["t"]
	# El monticulo: tierra levantada, con piedrecitas que saltan.
	enemigo.draw_set_transform(pies, 0.0, Vector2(1.0, 0.45))
	enemigo.draw_circle(Vector2.ZERO, 20.0, Color(TIERRA, 0.9))
	enemigo.draw_circle(Vector2(-4.0, -5.0), 12.0, Color(TIERRA.lightened(0.25), 0.9))
	enemigo.draw_set_transform(Vector2.ZERO)
	for k in 3:
		var salto := absf(sin(t * 9.0 + k * 2.1)) * 7.0
		enemigo.draw_circle(pies + Vector2(-12.0 + 12.0 * k, -4.0 - salto), 2.5, TIERRA.lightened(0.35))
	if fase == &"aviso":
		var avance := clampf(t / aviso, 0.0, 1.0)
		var color := enemigo.tipo.color_efectos
		enemigo.draw_set_transform(pies, 0.0, Vector2(1.0, 0.45))
		enemigo.draw_circle(Vector2.ZERO, radio_aviso, Color(color, 0.12 + 0.18 * avance))
		enemigo.draw_arc(Vector2.ZERO, radio_aviso, 0.0, TAU, 40, Color(color, 0.5 + 0.5 * avance), 3.0, true)
		enemigo.draw_set_transform(Vector2.ZERO)
