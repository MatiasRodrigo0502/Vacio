## Trampa de hielo: como los pinchos (el mismo ciclo: dentro, aviso temblando,
## fuera), pero lo que sale son cristales de hielo y no hacen dano: te frenan.
## Pedida por Matias el 2026-11-03: «tendra el mismo funcionamiento que los
## pinchos, pero en vez de hacer dano te da efecto de ralentizacion».
##
## Hereda de Pinchos para no repetir el ciclo ni donde van los agujeros: aqui
## solo cambia lo que hace al pisarla y como se pinta. La placa es la de los
## pinchos, teñida de frio; de cada agujero sale un cristal; mientras avisan,
## los agujeros brillan; y fuera, una neblina de escarcha encima.
##
## No las reparte la mecanica de peligros al azar: sustituye 'trampas_hielo'
## de sus pinchos, repartidas entre los pisos 9 a 12 (MecanicaPeligros).
class_name TrampaHielo
extends Pinchos

## Lo que dura el frio desde que se deja de pisar, en segundos. Como el
## disparo del mago blanco a los enemigos (1,5), un poco mas: el mago tiene
## que notarlo al salir de la placa.
const FRIO: float = 2.0
const COLOR_PLACA := Color(0.72, 0.86, 1.08)
const HIELO := Color(0.78, 0.94, 1.0, 0.93)
const HIELO_SOMBRA := Color(0.5, 0.76, 1.0, 0.95)


func _al_pisar(cuerpo: Node2D) -> void:
	if estan_fuera() and cuerpo.has_method("congelar"):
		cuerpo.congelar(FRIO)


func _pintar_placa(caja: Rect2) -> void:
	draw_texture_rect(PLACA, caja, false, tinte * COLOR_PLACA)


## Un cristal de hielo saliendo del agujero: una punta de cinco lados con una
## cara en sombra y un brillo, en vez del pincho de metal.
func _pintar_pincho(x: float, pie: float, ancho: float, alto_visible: float, salida: float,
		_metal: Color) -> void:
	var medio := ancho * 0.5
	var alto := alto_visible
	var cristal := PackedVector2Array([Vector2(x - medio, pie), Vector2(x - medio, pie - alto * 0.55),
		Vector2(x, pie - alto), Vector2(x + medio, pie - alto * 0.55), Vector2(x + medio, pie)])
	draw_colored_polygon(cristal, HIELO)
	draw_colored_polygon(PackedVector2Array([Vector2(x - medio, pie), Vector2(x - medio, pie - alto * 0.55),
		Vector2(x, pie - alto), Vector2(x, pie)]), HIELO_SOMBRA)
	draw_line(Vector2(x + medio * 0.3, pie - alto * 0.2), Vector2(x + medio * 0.1, pie - alto * 0.8),
		Color(1.0, 1.0, 1.0, 0.75 * salida), 1.5, true)


## Encima de todo: mientras avisan, los agujeros brillan de frio; fuera, una
## neblina de escarcha sobre la placa, con unos destellos.
func _pintar_encima(caja: Rect2, salida: float) -> void:
	if not estan_fuera():
		if salida > 0.05:
			var brillo := Color(0.7, 0.9, 1.0, 0.35 * salida / ASOMADO)
			draw_set_transform(caja.get_center(), 0.0, Vector2(1.0, 0.75))
			draw_circle(Vector2.ZERO, caja.size.x * 0.45, Color(brillo, brillo.a * 0.4))
			draw_set_transform(Vector2.ZERO)
		return
	draw_set_transform(caja.get_center(), 0.0, Vector2(1.0, 0.75))
	draw_circle(Vector2.ZERO, caja.size.x * 0.55, Color(0.75, 0.92, 1.0, 0.16))
	draw_set_transform(Vector2.ZERO)
	for k in 6:
		var angulo := _fase * 0.8 + k * TAU / 6.0
		var destello := caja.get_center() + Vector2(cos(angulo), sin(angulo) * 0.6) * caja.size.x * 0.38
		var largo := 3.0 + 1.5 * sin(_fase * 6.0 + k)
		draw_line(destello - Vector2(largo, 0.0), destello + Vector2(largo, 0.0), Color.WHITE, 1.2)
		draw_line(destello - Vector2(0.0, largo), destello + Vector2(0.0, largo), Color.WHITE, 1.2)
