## Vuela en circulo alrededor del jugador y, cada poco, se para, marca la
## linea por la que va a ir y se lanza en picado, pasando de largo. El
## murcielago.
##
## La linea se fija al empezar el aviso, no al lanzarse: asi el aviso sirve,
## y apartarse de la linea es esquivarlo.
class_name ComportamientoPicado
extends ComportamientoEnemigo

## A que distancia del jugador da vueltas.
@export var radio_orbita: float = 150.0
## Segundos dando vueltas entre picado y picado.
@export var tiempo_orbita: float = 1.8
## Segundos parado marcando la linea antes de lanzarse.
@export var aviso: float = 0.45
## Velocidad del picado respecto a la de su tipo.
@export var factor_picado: float = 2.3
## Hasta donde llega el picado, en px.
@export var largo_picado: float = 360.0


func empezar(enemigo: Enemigo) -> void:
	super.empezar(enemigo)
	enemigo.estado["fase"] = &"orbita"
	enemigo.estado["t"] = randf() * tiempo_orbita * 0.5
	enemigo.estado["giro"] = 1.0 if randf() < 0.5 else -1.0
	enemigo.estado["dir"] = Vector2.DOWN
	enemigo.estado["recorrido"] = 0.0


func procesar(enemigo: Enemigo, delta: float) -> void:
	var t: float = enemigo.estado["t"] + delta
	enemigo.estado["t"] = t
	match enemigo.estado["fase"]:
		&"orbita":
			var hacia := enemigo.hacia_objetivo()
			var distancia := maxf(hacia.length(), 1.0)
			var radial := hacia / distancia
			# Da vueltas, y a la vez se acerca o se aleja hasta su radio.
			var correccion := clampf((distancia - radio_orbita) / radio_orbita, -1.0, 1.0)
			var tangente: Vector2 = radial.orthogonal() * enemigo.estado["giro"]
			var antes := enemigo.global_position
			enemigo.andar((tangente + radial * correccion * 1.5).normalized(), delta)
			# Contra un muro, da la vuelta al reves.
			if enemigo.global_position.distance_to(antes) < enemigo.tipo.velocidad * delta * 0.3:
				enemigo.estado["giro"] = -enemigo.estado["giro"]
			if t >= tiempo_orbita and distancia < radio_orbita * 1.6:
				enemigo.estado["fase"] = &"aviso"
				enemigo.estado["t"] = 0.0
				enemigo.estado["dir"] = radial
		&"aviso":
			enemigo.brillo(t / aviso)
			if t >= aviso:
				enemigo.brillo(0.0)
				enemigo.estado["fase"] = &"picado"
				enemigo.estado["t"] = 0.0
				enemigo.estado["recorrido"] = 0.0
		&"picado":
			var antes := enemigo.global_position
			enemigo.andar(enemigo.estado["dir"], delta, factor_picado)
			var avance := enemigo.global_position.distance_to(antes)
			enemigo.estado["recorrido"] += avance
			# Acaba al llegar a su largo o al chocar (muro o roca).
			var esperado := enemigo.tipo.velocidad * factor_picado * delta
			if enemigo.estado["recorrido"] >= largo_picado or avance < esperado * 0.3:
				enemigo.estado["fase"] = &"orbita"
				enemigo.estado["t"] = 0.0
				enemigo.estado["giro"] = -enemigo.estado["giro"]


func dibujar(enemigo: Enemigo) -> void:
	if enemigo.estado.get("fase") != &"aviso":
		return
	var avance: float = clampf(enemigo.estado["t"] / aviso, 0.0, 1.0)
	var color := enemigo.tipo.color_efectos
	var hasta: Vector2 = enemigo.estado["dir"] * largo_picado
	enemigo.draw_line(Vector2.ZERO, hasta, Color(color, 0.15 + 0.45 * avance), 1.5 + 2.5 * avance, true)
