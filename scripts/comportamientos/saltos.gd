## Avanza a saltos: se aplasta (es el aviso), salta hacia el jugador y
## descansa un momento al caer. Los slimes. Con charco_radio > 0 deja un
## charco de lava donde cae (el slime de magma).
class_name ComportamientoSaltos
extends ComportamientoEnemigo

## Lo que tarda en aplastarse antes de saltar: el aviso de que va a saltar.
const AVISO: float = 0.25
## Lo que tarda en recuperarse del golpe al caer.
const CAIDA: float = 0.12

## Segundos en el aire.
@export var duracion_salto: float = 0.4
## Segundos en el suelo entre un salto y el siguiente.
@export var pausa: float = 0.5
## Altura del arco del salto, en px.
@export var altura: float = 16.0
## Velocidad en el aire respecto a la de su tipo. En el aire va mas deprisa
## porque luego se para: de media avanza parecido a como andaba.
@export var factor_velocidad: float = 2.0
## Radio del charco de lava que deja al caer, en px. 0 = ninguno.
@export var charco_radio: float = 0.0
@export var charco_duracion: float = 2.5


func empezar(enemigo: Enemigo) -> void:
	super.empezar(enemigo)
	enemigo.estado["en_aire"] = false
	# Cada uno a destiempo: si toda la sala saltara a la vez, pareceria un baile.
	enemigo.estado["t"] = randf() * pausa
	enemigo.estado["dir"] = Vector2.ZERO


func procesar(enemigo: Enemigo, delta: float) -> void:
	var t: float = enemigo.estado["t"] + delta
	if enemigo.estado["en_aire"]:
		enemigo.andar(enemigo.estado["dir"], delta, factor_velocidad)
		var arco := sin(PI * minf(t / duracion_salto, 1.0))
		# Estirado en el aire.
		enemigo.poner_sprite(Vector2(0.0, -altura * arco), Vector2(0.9, 1.12), 1.0)
		if t >= duracion_salto:
			enemigo.estado["en_aire"] = false
			t = 0.0
			if charco_radio > 0.0:
				_dejar_charco(enemigo)
	else:
		# Aplastado al caer, que se le pasa enseguida, y otra vez al final de
		# la pausa, cogiendo impulso.
		var aplastado := 0.0
		if t < CAIDA:
			aplastado = 1.0 - t / CAIDA
		elif t > pausa - AVISO:
			aplastado = (t - (pausa - AVISO)) / AVISO
		enemigo.poner_sprite(Vector2.ZERO, Vector2(1.0 + 0.2 * aplastado, 1.0 - 0.2 * aplastado), 1.0)
		if t >= pausa:
			enemigo.estado["en_aire"] = true
			enemigo.estado["dir"] = enemigo.hacia_objetivo().normalized()
			t = 0.0
	enemigo.estado["t"] = t


func _dejar_charco(enemigo: Enemigo) -> void:
	var sala := enemigo.sala()
	if sala == null:
		return
	var lava := Lava.new()
	lava.radio = charco_radio
	lava.duracion = charco_duracion
	# A los pies, que es donde ha caido.
	lava.position = sala.to_local(enemigo.global_position + Vector2(0.0, enemigo.tipo.alto * 0.3))
	# Diferido: esto llega en mitad del paso de fisica, y el charco trae su
	# area de colision.
	sala.add_child.call_deferred(lava)
