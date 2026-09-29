## Un agujero en el suelo: si lo pisas, te caes.
##
## Caer cuesta un corazon y te devuelve a la entrada de la sala. No mata de
## golpe: con tres corazones, un agujero que matara seria un "vuelve a
## empezar" por un paso mal dado, y eso frustra mas de lo que tensa.
##
## Se cae cuando los PIES estan dentro, no cuando el cuerpo roza el borde: en
## vista cenital el borde se puede pisar, y asi el jugador puede apurar.
class_name Vacio
extends Peligro

## Lo que hay que meterse para caer, en pixeles desde el borde.
const MARGEN_CAIDA: float = 10.0


func _al_pisar(cuerpo: Node2D) -> void:
	if not cuerpo.has_method("caer_al_vacio"):
		return
	var pies := to_local(cuerpo.global_position)
	if Rect2(-tamano * 0.5, tamano).grow(-MARGEN_CAIDA).has_point(pies):
		cuerpo.caer_al_vacio()


func _crear_forma() -> Shape2D:
	# La forma entera: aqui lo que decide es donde estan los pies, no el roce.
	var rectangulo := RectangleShape2D.new()
	rectangulo.size = tamano
	return rectangulo


func _draw() -> void:
	var caja := Rect2(-tamano * 0.5, tamano)
	# De fuera hacia dentro, cada vez mas oscuro: se lee como profundidad.
	draw_rect(caja.grow(4.0), color_suelo.darkened(0.25))
	for i in 5:
		var t := float(i) / 5.0
		draw_rect(caja.grow(-t * minf(tamano.x, tamano.y) * 0.22),
			Color(0.0, 0.0, 0.0, 0.55 + t * 0.45))
	# El filo de arriba iluminado y el de abajo en sombra, como un corte en la
	# roca visto desde arriba.
	draw_line(caja.position, Vector2(caja.end.x, caja.position.y),
		Color(color_borde.r, color_borde.g, color_borde.b, 0.8), 3.0)
	draw_line(Vector2(caja.position.x, caja.end.y), caja.end,
		Color(color_borde.r, color_borde.g, color_borde.b, 0.3), 2.0)
