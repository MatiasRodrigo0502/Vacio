## La escarcha a los pies de quien va frenado por el frio: un aro helado en
## el suelo y unos copos que giran. La llevan los enemigos que frena el
## disparo del mago blanco y, desde el 2026-11-03, el mago que pisa una
## trampa de hielo (Matias: «se representara igual que los enemigos que son
## alcanzados por los proyectiles del mago blanco»). Por eso se pinta aqui y
## no en cada uno: los dos tienen que verse igual.
##
## Va a los pies y por debajo del sprite: en el cuerpo la taparia el dibujo.
## Con el aro, el color: quien la lleva se tinta de COLOR (el enemigo, el
## nodo entero; el mago, su sprite).
class_name Escarcha
extends RefCounted

const COLOR := Color(0.62, 0.84, 1.25)


## Pinta la escarcha en 'lienzo' con los pies en 'pies' (en local), de radio
## 'radio' y girando segun 'fase' (segundos).
static func pintar(lienzo: CanvasItem, pies: Vector2, radio: float, fase: float) -> void:
	var color := Color(0.78, 0.94, 1.0, 0.85)
	# Achatado: es un circulo en el suelo visto en 3/4.
	lienzo.draw_set_transform(pies, 0.0, Vector2(1.0, 0.4))
	lienzo.draw_circle(Vector2.ZERO, radio, Color(0.6, 0.85, 1.0, 0.22))
	lienzo.draw_arc(Vector2.ZERO, radio, 0.0, TAU, 32, color, 2.5, true)
	lienzo.draw_set_transform(Vector2.ZERO)
	for k in 5:
		var angulo := fase * 1.2 + k * TAU / 5.0
		var copo := pies + Vector2(cos(angulo) * radio, sin(angulo) * radio * 0.4)
		lienzo.draw_line(copo - Vector2(3.5, 0.0), copo + Vector2(3.5, 0.0), Color.WHITE, 1.4)
		lienzo.draw_line(copo - Vector2(0.0, 3.5), copo + Vector2(0.0, 3.5), Color.WHITE, 1.4)
