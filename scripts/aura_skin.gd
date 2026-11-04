## El aura de las skins S y S+ a los pies del mago: un resplandor en el suelo y
## unas chispas que suben. En las S+ cambia de color sin parar. Va por debajo de
## su dibujo, para no taparlo (la pone Jugador.usar_personaje).
class_name AuraSkin
extends Node2D

const CHISPAS: int = 8
const RADIO: float = 26.0
const ALTO: float = 62.0

var _skin: SkinMago
var _fase: float = 0.0


func _init(skin: SkinMago) -> void:
	_skin = skin
	name = "AuraSkin"


func _process(delta: float) -> void:
	_fase += delta
	queue_redraw()


func _color(desfase: float) -> Color:
	if _skin.arcoiris:
		return Color.from_hsv(fposmod(_fase * 0.35 + desfase, 1.0), 0.8, 1.0)
	return _skin.aura


func _draw() -> void:
	var pies := Vector2(0.0, -3.0)
	draw_set_transform(pies, 0.0, Vector2(1.0, 0.4))
	var base := _color(0.0)
	draw_circle(Vector2.ZERO, RADIO * 1.15, Color(base, 0.16 + 0.05 * sin(_fase * 4.0)))
	draw_circle(Vector2.ZERO, RADIO * 0.75, Color(base, 0.22))
	draw_set_transform(Vector2.ZERO)
	for k in CHISPAS:
		var t := fmod(_fase * 0.7 + float(k) / CHISPAS, 1.0)
		var angulo := k * 2.4
		var sitio := pies + Vector2(cos(angulo) * RADIO * (1.0 - t * 0.3) + sin(_fase * 3.0 + k) * 2.0, -ALTO * t)
		var color := _color(float(k) / CHISPAS)
		draw_circle(sitio, 2.4 * (1.0 - t) + 0.8, Color(color, 1.0 - t * t))
