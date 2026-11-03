## Las burbujas de quien esta envenenado por el mago verde: un charco verde en
## el suelo y unas burbujas que suben, crecen y revientan, cada una a su
## ritmo. Se pintan aqui, como las llamas (Llamas) y la escarcha (Escarcha),
## para que el veneno se vea igual en todos los enemigos.
##
## A los pies y por debajo del sprite: en el cuerpo las taparia el dibujo.
## Por eso suben por los lados, en un aro mas ancho que el enemigo.
class_name Burbujas
extends RefCounted

const COLOR := Color(0.55, 1.0, 0.3)
const CUANTAS: int = 6


## Pinta las burbujas en 'lienzo' con los pies en 'pies' (en local), en un aro
## de radio 'radio', subiendo hasta 'alto' y moviendose segun 'fase'.
static func pintar(lienzo: CanvasItem, pies: Vector2, radio: float, alto: float, fase: float) -> void:
	lienzo.draw_set_transform(pies, 0.0, Vector2(1.0, 0.4))
	lienzo.draw_circle(Vector2.ZERO, radio * 1.05,
		Color(COLOR.r * 0.5, COLOR.g * 0.8, COLOR.b * 0.4, 0.28 + 0.06 * sin(fase * 5.0)))
	lienzo.draw_set_transform(Vector2.ZERO)
	for k in CUANTAS:
		# Cada una va por su parte del camino: no salen todas a la vez.
		var t := fmod(fase * 0.8 + float(k) / CUANTAS, 1.0)
		var angulo := k * TAU / CUANTAS + 0.3
		var base := pies + Vector2(cos(angulo) * radio, sin(angulo) * radio * 0.4)
		var sitio := base + Vector2(sin(fase * 4.0 + k * 2.1) * 3.0, -alto * 0.75 * t)
		var tamano := 2.0 + 3.5 * t
		var alfa := 0.9 * (1.0 - t * t * t)
		lienzo.draw_circle(sitio, tamano, Color(COLOR.r, COLOR.g, COLOR.b, alfa))
		lienzo.draw_circle(sitio + Vector2(-tamano, -tamano) * 0.35, tamano * 0.35,
			Color(1.0, 1.0, 1.0, alfa * 0.8))
