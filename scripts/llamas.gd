## Las llamas a los pies de quien se quema: un resplandor naranja en el suelo
## y unas llamas que suben y bajan, cada una a su ritmo. Las llevan los
## enemigos que quema el mago rojo y, desde el 2026-11-03, el mago al que
## alcanza el aliento de fuego del jefe (AlientoFuego): tienen que verse igual,
## asi que se pintan aqui, como la escarcha (Escarcha).
##
## A los pies y por debajo del sprite: en el cuerpo las taparia el dibujo.
class_name Llamas
extends RefCounted


## Pinta las llamas en 'lienzo' con los pies en 'pies' (en local), en un aro
## de radio 'radio', de hasta 'alto' de altas y moviendose segun 'fase'.
static func pintar(lienzo: CanvasItem, pies: Vector2, radio: float, alto: float, fase: float) -> void:
	# Un resplandor naranja en el suelo, achatado como la escarcha: se ve
	# aunque el cuerpo tape las llamas de detras.
	lienzo.draw_set_transform(pies, 0.0, Vector2(1.0, 0.4))
	lienzo.draw_circle(Vector2.ZERO, radio * 1.1, Color(1.0, 0.4, 0.05, 0.25 + 0.08 * sin(fase * 9.0)))
	lienzo.draw_set_transform(Vector2.ZERO)
	for k in 7:
		var angulo := k * TAU / 7.0 + 0.4
		var base := pies + Vector2(cos(angulo) * radio, sin(angulo) * radio * 0.4)
		var largo := alto * (0.38 + 0.14 * sin(fase * 11.0 + k * 1.7))
		var ancho := 6.0
		var llama := PackedVector2Array([
			base + Vector2(-ancho, 0.0), base + Vector2(0.0, -largo), base + Vector2(ancho, 0.0)])
		lienzo.draw_colored_polygon(llama, Color(1.0, 0.45, 0.1, 0.9))
		var dentro := PackedVector2Array([
			base + Vector2(-ancho * 0.5, 0.0), base + Vector2(0.0, -largo * 0.55),
			base + Vector2(ancho * 0.5, 0.0)])
		lienzo.draw_colored_polygon(dentro, Color(1.0, 0.9, 0.35, 0.95))
