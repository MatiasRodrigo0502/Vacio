## Va a por ti y, a su alcance, se para, levanta los brazos y descarga un golpe a
## dos manos contra el suelo. El golem.
##
## Lo que avisa es lo que hace el dibujo: el golpe cae en la pose en la que caen
## las manos, y hasta ahi hay tiempo de apartarse. Aparte de esto, tocarle quita
## vida como tocar a cualquier enemigo.
##
## El golpe es una onda (OndaChoque) corta, delante de el, y no una comprobacion
## de distancia, por el cooperativo: la onda sale en todos los ordenadores y cada
## uno mira si le da a SU jugador, que es lo que mandaria hacer MundoRed de todas
## formas (y el polvo de la hoja ya parece una).
class_name ComportamientoGolpe
extends ComportamientoEnemigo

## Mas cerca que esto, de centro a centro, golpea.
@export var alcance: float = 72.0
## La pose de "atacar" en la que caen las manos.
@export var pose_golpe: int = 3
## Hasta donde llega el golpe por el suelo. Tiene que ser bastante mas que el
## alcance: la onda va achatada (OndaChoque.ACHATADO), y por arriba y por abajo se
## queda en un poco mas de la mitad.
@export var radio_golpe: float = 130.0
@export var duracion_golpe: float = 0.22
@export var dano_golpe: int = 25
## Segundos desde que empieza un golpe hasta que puede empezar otro.
@export var recarga: float = 1.4
## Segundos que va de lado cuando algo le corta el paso.
@export var rodeo: float = 0.7

## Donde caen las manos, delante de el.
const DELANTE: float = 28.0


func empezar(enemigo: Enemigo) -> void:
	super.empezar(enemigo)
	enemigo.estado["golpeando"] = false
	enemigo.estado["dado"] = false
	enemigo.estado["dir"] = Vector2.DOWN
	enemigo.estado["recarga"] = 0.0
	enemigo.estado["rodeo"] = 0.0
	enemigo.estado["lado"] = 1.0 if randf() < 0.5 else -1.0


func procesar(enemigo: Enemigo, delta: float) -> void:
	enemigo.estado["recarga"] = maxf(0.0, enemigo.estado["recarga"] - delta)
	if enemigo.estado["golpeando"]:
		_seguir_golpe(enemigo)
		return
	var hacia := enemigo.hacia_objetivo()
	var distancia := maxf(hacia.length(), 1.0)
	if distancia <= alcance and enemigo.estado["recarga"] <= 0.0:
		enemigo.estado["golpeando"] = true
		enemigo.estado["dado"] = false
		enemigo.estado["dir"] = hacia / distancia
		enemigo.estado["recarga"] = recarga
		enemigo.mirar_a(hacia)
		enemigo.gesto(&"atacar")
		return
	# Sin echarsele encima: a su alcance espera a poder golpear otra vez.
	if distancia > alcance * 0.8:
		_andar(enemigo, hacia / distancia, delta)


## Hacia el jugador y, si algo le corta el paso, de lado un rato. Solo en linea
## recta, de frente contra una roca o un agujero se quedaba parado para siempre,
## porque lo devuelven justo donde estaba. Medido en salas de verdad con el mago
## quieto 25 s: sin esto no llegaban 13 de 66, con esto 5, y la rata de antes, que
## va en zigzag, 2. Rodear mas cada vez que tropieza no mejoraba nada.
func _andar(enemigo: Enemigo, hacia: Vector2, delta: float) -> void:
	var rodeando: bool = enemigo.estado["rodeo"] > 0.0
	var lado: float = enemigo.estado["lado"]
	enemigo.estado["rodeo"] = maxf(0.0, enemigo.estado["rodeo"] - delta)
	var antes := enemigo.global_position
	enemigo.andar(hacia.orthogonal() * lado if rodeando else hacia, delta)
	if enemigo.global_position.distance_to(antes) >= enemigo.tipo.velocidad * delta * 0.3:
		return
	# De lado tampoco puede (un muro): al otro lado.
	if rodeando:
		enemigo.estado["lado"] = -lado
	enemigo.estado["rodeo"] = rodeo


func _seguir_golpe(enemigo: Enemigo) -> void:
	var pose := enemigo.pose_ataque()
	if pose < 0:
		enemigo.estado["golpeando"] = false
		enemigo.brillo(0.0)
		return
	if enemigo.estado["dado"]:
		return
	enemigo.brillo(float(pose) / pose_golpe)
	if pose >= pose_golpe:
		enemigo.estado["dado"] = true
		enemigo.brillo(0.0)
		_golpear(enemigo)


func _golpear(enemigo: Enemigo) -> void:
	var sala := enemigo.sala()
	if sala == null:
		return
	# Por MundoRed: en cooperativo, la onda sale en todos los ordenadores.
	MundoRed.crear_onda(sala, sala.to_local(enemigo.global_position + enemigo.estado["dir"] * DELANTE),
		radio_golpe, duracion_golpe, dano_golpe, enemigo.tipo.color_efectos,
		enemigo.tipo.nombre + " (golpe)")


## Mientras levanta los brazos, hasta donde va a llegar: un aro en el suelo.
func dibujar(enemigo: Enemigo) -> void:
	if not enemigo.estado.get("golpeando", false) or enemigo.estado.get("dado", false):
		return
	var avance := clampf(float(enemigo.pose_ataque()) / pose_golpe, 0.0, 1.0)
	var color := enemigo.tipo.color_efectos
	# Hacia un sitio del mundo: sin el giro del golem (Vista).
	var centro: Vector2 = (enemigo.estado["dir"] * DELANTE).rotated(-enemigo.rotation)
	enemigo.draw_set_transform(centro, 0.0, Vector2(1.0, OndaChoque.ACHATADO))
	enemigo.draw_arc(Vector2.ZERO, radio_golpe, 0.0, TAU, 48, Color(color, 0.2 + 0.5 * avance), 2.0, true)
	enemigo.draw_circle(Vector2.ZERO, radio_golpe * avance, Color(color, 0.08))
	enemigo.draw_set_transform(Vector2.ZERO)
