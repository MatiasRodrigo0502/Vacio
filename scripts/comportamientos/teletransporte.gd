## Dispara como siempre (el rayo del cristal) y, poco despues de cada
## disparo, se desvanece y aparece en otro sitio de la sala, lejos del
## jugador: hay que volver a buscarlo. Mientras se desvanece no se le puede
## dar. El cristal vivo.
class_name ComportamientoTeletransporte
extends ComportamientoEnemigo

## Segundos despues del disparo antes de irse.
@export var retardo: float = 0.6
## Lo que tarda en desvanecerse y en aparecer.
@export var transicion: float = 0.3
## Aparece al menos a esta distancia del jugador.
@export var distancia_minima: float = 220.0
## Separacion de los muros al aparecer, en px.
@export var margen: float = 60.0


func empezar(enemigo: Enemigo) -> void:
	super.empezar(enemigo)
	enemigo.estado["fase"] = &"normal"
	enemigo.estado["t"] = 0.0
	enemigo.estado["vistos"] = enemigo.disparos


func procesar(enemigo: Enemigo, delta: float) -> void:
	var t: float = enemigo.estado["t"] + delta
	enemigo.estado["t"] = t
	match enemigo.estado["fase"]:
		&"normal", &"esperando":
			var hacia := enemigo.hacia_objetivo()
			enemigo.pelear_a_distancia(delta, hacia, hacia.length())
			if enemigo.estado["fase"] == &"normal" and enemigo.disparos > enemigo.estado["vistos"]:
				enemigo.estado["vistos"] = enemigo.disparos
				_pasar(enemigo, &"esperando")
			elif enemigo.estado["fase"] == &"esperando" and t >= retardo:
				_pasar(enemigo, &"yendose")
				Sonido.tocar(&"teletransporte")
		&"yendose":
			var k := clampf(t / transicion, 0.0, 1.0)
			enemigo.poner_sprite(Vector2.ZERO, Vector2(1.0 - 0.6 * k, 1.0 + 0.4 * k), 1.0 - k)
			if t >= transicion:
				enemigo.global_position = _sitio_nuevo(enemigo)
				_pasar(enemigo, &"llegando")
		&"llegando":
			var k := clampf(t / transicion, 0.0, 1.0)
			enemigo.poner_sprite(Vector2.ZERO, Vector2(0.4 + 0.6 * k, 1.4 - 0.4 * k), k)
			if t >= transicion:
				enemigo.poner_sprite(Vector2.ZERO, Vector2.ONE, 1.0)
				_pasar(enemigo, &"normal")


func _pasar(enemigo: Enemigo, fase: StringName) -> void:
	enemigo.estado["fase"] = fase
	enemigo.estado["t"] = 0.0


func tangible(enemigo: Enemigo) -> bool:
	var fase: StringName = enemigo.estado.get("fase", &"normal")
	return fase == &"normal" or fase == &"esperando"


## Un sitio de la sala lejos del jugador y fuera de las rocas. Se prueban unos
## cuantos al azar; si ninguno vale (sala pequena, jugador en medio), el mas
## lejano de los probados.
func _sitio_nuevo(enemigo: Enemigo) -> Vector2:
	var sala := enemigo.sala()
	if sala == null:
		return enemigo.global_position
	var suelo := sala.rect_suelo_global().grow(-margen)
	var jugador := enemigo.global_position + enemigo.hacia_objetivo()
	var radio := enemigo.tipo.alto * 0.4
	var mejor := enemigo.global_position
	var mejor_distancia := -1.0
	for i in 24:
		var punto := Vector2(randf_range(suelo.position.x, suelo.end.x),
			randf_range(suelo.position.y, suelo.end.y))
		# Si la sala lo tiene que sacar de una roca, ese sitio no esta libre.
		if not sala.sacar_de_las_rocas(punto, radio).is_equal_approx(punto):
			continue
		var distancia := punto.distance_to(jugador)
		if distancia >= distancia_minima:
			return punto
		if distancia > mejor_distancia:
			mejor = punto
			mejor_distancia = distancia
	return mejor
