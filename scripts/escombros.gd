## Lo que queda al romperse un pilar: trozos que saltan y caen, y una nube de
## polvo. Solo se ve; el pilar ya se ha quitado (Obstaculo.romper).
##
## Dibujado por codigo, como las explosiones: una docena de trozos y un
## circulo no necesitan arte. Los trozos suben y caen hasta el suelo de donde
## estaba el pilar: en la vista en 3/4, "arriba" en pantalla es saltar.
class_name Escombros
extends Node2D

const DURACION: float = 0.8
const TROZOS: int = 14
const GRAVEDAD: float = 900.0

var color: Color = Color(0.86, 0.8, 0.68)
## Lo ancho que era lo que se ha roto: los trozos salen de todo su ancho.
var ancho: float = 80.0

var _tiempo: float = 0.0
## Por trozo: [posicion, velocidad, giro, velocidad de giro, tamano, suelo].
var _trozos: Array = []


func _ready() -> void:
	# Por encima de los enemigos y sus disparos: es lo que se acaba de romper.
	z_index = 6
	for i in TROZOS:
		var salida := Vector2(randf_range(-0.5, 0.5) * ancho, randf_range(-0.4, 0.2) * ancho)
		var velocidad := Vector2(randf_range(-220.0, 220.0), randf_range(-420.0, -160.0))
		_trozos.append([salida, velocidad, randf() * TAU, randf_range(-12.0, 12.0),
			randf_range(4.0, 10.0), randf_range(0.1, 0.35) * ancho])


func _process(delta: float) -> void:
	_tiempo += delta
	if _tiempo >= DURACION:
		queue_free()
		return
	for trozo: Array in _trozos:
		var sitio: Vector2 = trozo[0]
		var velocidad: Vector2 = trozo[1]
		# Hasta que vuelve a caer al suelo de donde salio.
		if sitio.y < trozo[5] or velocidad.y < 0.0:
			velocidad.y += GRAVEDAD * delta
			trozo[0] = sitio + velocidad * delta
			trozo[1] = velocidad
			trozo[2] = float(trozo[2]) + float(trozo[3]) * delta
	queue_redraw()


func _draw() -> void:
	var t := _tiempo / DURACION
	var alfa := clampf((1.0 - t) * 2.0, 0.0, 1.0)
	# El polvo: un circulo achatado que crece y se apaga.
	draw_set_transform(Vector2(0.0, ancho * 0.25), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, ancho * (0.5 + 0.7 * t), Color(color, 0.35 * (1.0 - t)))
	draw_set_transform(Vector2.ZERO)
	for trozo in _trozos:
		var lado: float = trozo[4]
		draw_set_transform(trozo[0], trozo[2])
		var caja := Rect2(-lado * 0.5, -lado * 0.35, lado, lado * 0.7)
		draw_rect(caja, Color(color, alfa))
		draw_rect(caja, Color(0.1, 0.08, 0.06, alfa), false, 1.0)
	draw_set_transform(Vector2.ZERO)
