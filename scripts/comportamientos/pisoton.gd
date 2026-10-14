## De lejos, lo de siempre: se queda a su distancia y lanza magma. Si el
## jugador se le acerca, pisoton: brilla, marca en el suelo hasta donde llega y
## suelta una onda (OndaChoque) que hay que esquivar alejandose. Asi no basta
## con pegarse a el para que no pueda disparar. El golem.
class_name ComportamientoPisoton
extends ComportamientoEnemigo

## Mas cerca que esto, pisa.
@export var distancia_pisoton: float = 160.0
## Segundos de aviso antes de la onda.
@export var aviso: float = 0.7
## Hasta donde llega la onda, en px.
@export var radio_onda: float = 190.0
## Lo que tarda la onda en llegar hasta ahi.
@export var duracion_onda: float = 0.5
## Segundos sin poder volver a pisar.
@export var recarga: float = 3.0
@export var dano_onda: int = 30


func empezar(enemigo: Enemigo) -> void:
	super.empezar(enemigo)
	enemigo.estado["pisando"] = false
	enemigo.estado["t"] = 0.0
	enemigo.estado["recarga"] = 0.0


func procesar(enemigo: Enemigo, delta: float) -> void:
	enemigo.estado["recarga"] = maxf(0.0, enemigo.estado["recarga"] - delta)
	if enemigo.estado["pisando"]:
		var t: float = enemigo.estado["t"] + delta
		enemigo.estado["t"] = t
		enemigo.brillo(t / aviso)
		# Se encoge cogiendo impulso.
		enemigo.poner_sprite(Vector2.ZERO, Vector2(1.0 + 0.08 * t / aviso, 1.0 - 0.1 * t / aviso), 1.0)
		if t >= aviso:
			_pisar(enemigo)
		return

	var hacia := enemigo.hacia_objetivo()
	var distancia := hacia.length()
	if enemigo.estado["recarga"] <= 0.0 and distancia < distancia_pisoton \
			and not enemigo.esta_apuntando():
		enemigo.estado["pisando"] = true
		enemigo.estado["t"] = 0.0
		return
	enemigo.pelear_a_distancia(delta, hacia, distancia)


func _pisar(enemigo: Enemigo) -> void:
	enemigo.estado["pisando"] = false
	enemigo.estado["recarga"] = recarga
	enemigo.brillo(0.0)
	enemigo.poner_sprite(Vector2.ZERO, Vector2.ONE, 1.0)
	var sala := enemigo.sala()
	if sala == null:
		return
	var onda := OndaChoque.new()
	onda.radio_maximo = radio_onda
	onda.duracion = duracion_onda
	onda.dano = dano_onda
	onda.color = enemigo.tipo.color_efectos
	onda.origen = enemigo.tipo.nombre + " (pisotón)"
	onda.position = sala.to_local(enemigo.global_position + _pies(enemigo))
	sala.add_child(onda)
	Sonido.tocar(&"pisoton")


func _pies(enemigo: Enemigo) -> Vector2:
	return Vector2(0.0, enemigo.tipo.alto * 0.42)


## Mientras avisa, hasta donde va a llegar la onda: un aro en el suelo.
func dibujar(enemigo: Enemigo) -> void:
	if not enemigo.estado.get("pisando", false):
		return
	var avance: float = clampf(enemigo.estado["t"] / aviso, 0.0, 1.0)
	var color := enemigo.tipo.color_efectos
	enemigo.draw_set_transform(_pies(enemigo), 0.0, Vector2(1.0, OndaChoque.ACHATADO))
	enemigo.draw_arc(Vector2.ZERO, radio_onda, 0.0, TAU, 56, Color(color, 0.2 + 0.5 * avance), 2.0, true)
	enemigo.draw_circle(Vector2.ZERO, radio_onda * avance, Color(color, 0.08))
	enemigo.draw_set_transform(Vector2.ZERO)
