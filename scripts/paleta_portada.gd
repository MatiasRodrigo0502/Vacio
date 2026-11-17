## Los colores de la portada (el video del mago oscuro en el bosque morado) para
## los paneles del menu que los usan: el de controles (Matias, 2026-11-17: «en el
## apartado de controles, usa la paleta de colores de la portada actual»).
##
## DE DONDE SALEN: de assets/portada/portada_quieta.jpg reducida a sus 10 colores
## mas usados (de mas a menos: #2c0d3b, #210a2d, #3b164e, #420e54, #13061b,
## #5b1970, #582470, #822799, #8b3aa1, #b46abb). Los textos van mas claros que
## el mas claro de la portada: con esos morados de fondo, #b46abb no se leia bien.
##
## Con un tema (tema()) y no color a color: asi cogen los colores tambien los
## botones que monta otro (el del disparo automatico, el de las estadisticas).
class_name PaletaPortada
extends RefCounted

const FONDO := Color("13061b")
const CAJA := Color("2c0d3b")
const CAJA_ENCIMA := Color("420e54")
const CAJA_PULSADA := Color("5b1970")
const CAJA_APAGADA := Color("210a2d")
const BORDE := Color("582470")
const BORDE_ENCIMA := Color("8b3aa1")
const BORDE_PULSADO := Color("b46abb")
const TITULO := Color("e9b8f2")
const TEXTO := Color("ece0f2")
const FLOJO := Color("9d84ab")


## Un tema con estos colores para botones y textos. Se pone en el nodo de arriba
## del panel y lo heredan todos los de dentro.
static func tema() -> Theme:
	var tema_nuevo := Theme.new()
	var normal := _caja(CAJA, BORDE)
	tema_nuevo.set_stylebox("normal", "Button", normal)
	tema_nuevo.set_stylebox("hover", "Button", _caja(CAJA_ENCIMA, BORDE_ENCIMA))
	tema_nuevo.set_stylebox("pressed", "Button", _caja(CAJA_PULSADA, BORDE_PULSADO))
	tema_nuevo.set_stylebox("hover_pressed", "Button", _caja(CAJA_PULSADA, TITULO))
	tema_nuevo.set_stylebox("disabled", "Button", _caja(CAJA_APAGADA, CAJA))
	var foco := _caja(Color(0.0, 0.0, 0.0, 0.0), TITULO)
	foco.draw_center = false
	tema_nuevo.set_stylebox("focus", "Button", foco)
	tema_nuevo.set_color("font_color", "Button", TEXTO)
	tema_nuevo.set_color("font_hover_color", "Button", Color.WHITE)
	tema_nuevo.set_color("font_pressed_color", "Button", Color.WHITE)
	tema_nuevo.set_color("font_hover_pressed_color", "Button", Color.WHITE)
	tema_nuevo.set_color("font_focus_color", "Button", Color.WHITE)
	tema_nuevo.set_color("font_disabled_color", "Button", FLOJO)
	tema_nuevo.set_color("font_color", "Label", TEXTO)
	# La barra de desplazar la lista de teclas.
	tema_nuevo.set_stylebox("scroll", "VScrollBar", _caja(CAJA_APAGADA, CAJA_APAGADA, 3.0))
	tema_nuevo.set_stylebox("grabber", "VScrollBar", _caja(BORDE, BORDE, 3.0))
	tema_nuevo.set_stylebox("grabber_highlight", "VScrollBar", _caja(BORDE_ENCIMA, BORDE_ENCIMA, 3.0))
	tema_nuevo.set_stylebox("grabber_pressed", "VScrollBar", _caja(BORDE_PULSADO, BORDE_PULSADO, 3.0))
	# El texto de ayuda al pasar por encima de una tecla.
	tema_nuevo.set_stylebox("panel", "TooltipPanel", _caja(CAJA, BORDE_ENCIMA))
	tema_nuevo.set_color("font_color", "TooltipLabel", TEXTO)
	return tema_nuevo


## 'margen': el de los lados. La barra de desplazar lo usa de ancho, y la quiere fina.
static func _caja(fondo: Color, borde: Color, margen: float = 10.0) -> StyleBoxFlat:
	var caja := StyleBoxFlat.new()
	caja.bg_color = fondo
	caja.border_color = borde
	caja.set_border_width_all(1)
	caja.set_corner_radius_all(4)
	caja.content_margin_left = margen
	caja.content_margin_right = margen
	caja.content_margin_top = minf(margen, 4.0)
	caja.content_margin_bottom = minf(margen, 4.0)
	return caja
