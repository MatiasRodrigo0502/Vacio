## Runas del vacio: los signos que marcan lo que tiene que ver con el jefe (la
## puerta de su sala, el sello de su suelo). Solo dibujo, sin nodos: quien las
## usa las pinta en su _draw() con Runas.pintar().
##
## POR QUE SIGNOS INVENTADOS Y NO LETRAS: tienen que leerse como "aqui pasa
## algo" sin decir nada concreto, y una fuente de texto no los trae. Son trazos
## rectos, como grabados a cincel en la roca, y brillan como el nucleo.
class_name Runas
extends RefCounted

## Cada runa, en una caja de 1 de ancho por 1,4 de alto centrada en (0, 0):
## una lista de trazos [desde, hasta].
const SIGNOS: Array = [
	[[Vector2(0, -0.7), Vector2(0, 0.7)], [Vector2(0, -0.3), Vector2(0.45, -0.65)], [Vector2(0, 0.05), Vector2(0.45, -0.3)]],
	[[Vector2(-0.3, -0.7), Vector2(-0.3, 0.7)], [Vector2(-0.3, -0.7), Vector2(0.4, 0.0)], [Vector2(0.4, 0.0), Vector2(-0.3, 0.7)]],
	[[Vector2(0, -0.7), Vector2(0, 0.7)], [Vector2(-0.45, -0.25), Vector2(0.45, 0.25)], [Vector2(0.45, -0.25), Vector2(-0.45, 0.25)]],
	[[Vector2(-0.4, -0.7), Vector2(-0.4, 0.7)], [Vector2(0.4, -0.7), Vector2(0.4, 0.7)], [Vector2(-0.4, -0.2), Vector2(0.4, 0.2)]],
	[[Vector2(0, -0.7), Vector2(-0.45, 0.0)], [Vector2(-0.45, 0.0), Vector2(0, 0.7)], [Vector2(0, -0.7), Vector2(0.45, 0.0)], [Vector2(0.45, 0.0), Vector2(0, 0.7)]],
	[[Vector2(0, -0.7), Vector2(0, 0.7)], [Vector2(-0.45, -0.7), Vector2(0, -0.25)], [Vector2(0.45, -0.7), Vector2(0, -0.25)]],
	[[Vector2(-0.35, -0.35), Vector2(0, -0.7)], [Vector2(0, -0.7), Vector2(0.35, -0.35)], [Vector2(0.35, -0.35), Vector2(-0.35, 0.7)], [Vector2(-0.35, -0.35), Vector2(0.35, 0.7)]],
]

## El brillo del nucleo: blanco tirando a dorado.
const COLOR := Color(1.0, 0.82, 0.55)


## Pinta la runa numero 'indice' (da la vuelta a la lista) en 'centro', de
## 'alto' px de alto. Tres pasadas por trazo, de ancha y floja a fina y
## fuerte: es lo que hace que parezca que brilla y no que esta pintada.
static func pintar(lienzo: CanvasItem, centro: Vector2, alto: float, indice: int,
		color: Color = COLOR, alfa: float = 1.0) -> void:
	var escala := alto / 1.4
	var signo: Array = SIGNOS[posmod(indice, SIGNOS.size())]
	for pasada: Array in [[7.0, 0.12], [4.0, 0.3], [1.8, 1.0]]:
		var tinta := Color(color, color.a * alfa * float(pasada[1]))
		for trazo: Array in signo:
			lienzo.draw_line(centro + trazo[0] * escala, centro + trazo[1] * escala,
				tinta, float(pasada[0]) * alto / 22.0, true)
