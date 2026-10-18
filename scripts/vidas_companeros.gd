## La vida de los demas jugadores del cooperativo, abajo a la izquierda: una
## linea por companero con su numero, su mago y una barra pequena. Fase 2
## (Matias, 2026-10-16). La propia sigue arriba, en su barra grande.
##
## POR QUE ABAJO A LA IZQUIERDA: arriba a la izquierda va lo de este jugador
## (piso, vida, especial, ventajas), arriba a la derecha el minimapa y abajo
## en el centro la barra del jefe. Esa esquina estaba libre (en cooperativo
## no hay atajos de prueba, que escriben ahi).
##
## Lo rellena Cooperativo con lo que manda cada ordenador (actualizar).
class_name VidasCompaneros
extends Control

const ANCHO_BARRA: float = 120.0
const ALTO_BARRA: float = 10.0
const ALTO_LINEA: float = 24.0
const MARGEN: float = 18.0

## Uno por companero: {"numero", "nombre", "color", "vida", "maxima", "vivo"}.
var _companeros: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func actualizar(companeros: Array) -> void:
	_companeros = companeros
	queue_redraw()


func _draw() -> void:
	var fuente := ThemeDB.fallback_font
	var y := size.y - MARGEN - _companeros.size() * ALTO_LINEA
	for datos: Dictionary in _companeros:
		var vivo: bool = datos.vivo
		var color: Color = datos.color if vivo else Color(0.55, 0.52, 0.5)
		var texto := "J%d  %s" % [int(datos.numero), datos.nombre]
		var sitio := Vector2(MARGEN, y + 16.0)
		draw_string_outline(fuente, sitio, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 4, Color(0, 0, 0, 0.7))
		draw_string(fuente, sitio, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, color)
		var x := MARGEN + 150.0
		var caja := Rect2(Vector2(x, y + 6.0), Vector2(ANCHO_BARRA, ALTO_BARRA))
		draw_rect(caja.grow(1.5), Color(0, 0, 0, 0.6))
		draw_rect(caja, Color(0.12, 0.05, 0.06, 0.9))
		if vivo:
			var parte := clampf(float(datos.vida) / maxf(float(datos.maxima), 1.0), 0.0, 1.0)
			draw_rect(Rect2(caja.position, Vector2(ANCHO_BARRA * parte, ALTO_BARRA)), Color(0.86, 0.2, 0.24))
			var numeros := "%d / %d" % [int(datos.vida), int(datos.maxima)]
			draw_string(fuente, Vector2(x + ANCHO_BARRA + 8.0, y + 16.0), numeros,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.85))
		else:
			# Caido: vuelve en el piso siguiente, con media vida.
			draw_string(fuente, Vector2(x + ANCHO_BARRA + 8.0, y + 16.0), "caído",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.7, 0.66, 0.62))
		y += ALTO_LINEA
