## Charco de lava: quema siempre que lo pisas.
##
## Hay dos: los fijos, que reparte la mecanica de peligros en los pisos hondos,
## y los que deja el magma del golem al caer, que se enfrian y desaparecen
## (duracion > 0).
class_name Lava
extends Peligro

const DANO: int = 1
## Lo que tarda en apagarse al final, para que no desaparezca de golpe.
const ENFRIADO: float = 0.8

var radio: float = 50.0
## Segundos que dura. 0 = para siempre.
var duracion: float = 0.0


func _ready() -> void:
	tamano = Vector2.ONE * radio * 2.0
	super()


func _crear_forma() -> Shape2D:
	var circulo := CircleShape2D.new()
	circulo.radius = radio * 0.82
	return circulo


func _physics_process(delta: float) -> void:
	super(delta)
	if duracion > 0.0 and _fase >= duracion:
		queue_free()


func _al_pisar(cuerpo: Node2D) -> void:
	# Un charco que se esta enfriando ya no quema: si se ve apagandose, que
	# no pegue.
	if _enfriandose():
		return
	if cuerpo.has_method("recibir_dano"):
		cuerpo.recibir_dano(DANO)


func _enfriandose() -> bool:
	return duracion > 0.0 and _fase >= duracion - ENFRIADO


func _draw() -> void:
	var opacidad := 1.0
	if _enfriandose():
		opacidad = clampf((duracion - _fase) / ENFRIADO, 0.0, 1.0)
	# Los charcos que deja el magma aparecen creciendo: el golpe se ve caer.
	var crecer := clampf(_fase / 0.18, 0.0, 1.0)

	var costra := Color(0.22, 0.06, 0.03, opacidad)
	var lava := Color(1.0, 0.42, 0.08, opacidad)
	var brillo := Color(1.0, 0.82, 0.3, opacidad)
	# El borde irregular sale de senos fijos por charco (la semilla es su
	# posicion): una circunferencia perfecta se leeria como un boton, no como
	# un charco.
	var semilla := fmod(absf(position.x * 0.013 + position.y * 0.007), TAU)
	_pintar_mancha(radio * crecer, semilla, costra)
	_pintar_mancha(radio * 0.84 * crecer, semilla, lava)
	var pulso := 0.5 + 0.5 * sin(_fase * 3.0 + semilla)
	_pintar_mancha(radio * (0.42 + 0.1 * pulso) * crecer, semilla + 1.0,
		Color(brillo.r, brillo.g, brillo.b, opacidad * 0.8))
	# Burbujas que suben y revientan.
	for i in 3:
		var vida := fmod(_fase * 0.9 + i * 0.37 + semilla, 1.0)
		var sitio := Vector2.RIGHT.rotated(semilla + i * 2.1) * radio * 0.45 * crecer
		draw_circle(sitio, radio * 0.09 * (1.0 - vida),
			Color(1.0, 0.9, 0.55, opacidad * (1.0 - vida)))


func _pintar_mancha(r: float, semilla: float, color: Color) -> void:
	if r <= 1.0:
		return
	var puntos := PackedVector2Array()
	for i in 20:
		var angulo := TAU * i / 20.0
		var borde := 1.0 + 0.08 * sin(angulo * 3.0 + semilla) + 0.05 * sin(angulo * 5.0 + semilla * 2.0)
		puntos.append(Vector2.RIGHT.rotated(angulo) * r * borde)
	draw_colored_polygon(puntos, color)
