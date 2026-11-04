## Las monedas y los diamantes que se tienen: en el HUD, en la portada y en el
## gacha. Dibujado por codigo y siguiendo a Coleccion: se pone en cualquier sitio
## y ya.
class_name Monedero
extends Control

const COLOR_MONEDA := Color(1.0, 0.8, 0.25)
const COLOR_DIAMANTE := Color(0.5, 0.9, 1.0)
const RADIO: float = 10.0
const ANCHO: float = 210.0
const ALTO: float = 26.0
const TAMANO_LETRA: int = 19


func _init() -> void:
	custom_minimum_size = Vector2(ANCHO, ALTO)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	Coleccion.cambiado.connect(queue_redraw)


## Una moneda: el disco, su canto oscuro y un brillo.
static func pintar_moneda(lienzo: CanvasItem, centro: Vector2, radio: float) -> void:
	lienzo.draw_circle(centro, radio, COLOR_MONEDA.darkened(0.45))
	lienzo.draw_circle(centro, radio * 0.8, COLOR_MONEDA)
	lienzo.draw_arc(centro, radio * 0.5, 0.0, TAU, 16, COLOR_MONEDA.darkened(0.3), 1.5, true)
	lienzo.draw_circle(centro + Vector2(-radio, -radio) * 0.3, radio * 0.18, Color.WHITE)


## Un diamante: la silueta, y la parte de arriba mas clara.
static func pintar_diamante(lienzo: CanvasItem, centro: Vector2, radio: float) -> void:
	var r := radio * 1.1
	lienzo.draw_colored_polygon(PackedVector2Array([centro + Vector2(-r, -r * 0.3), centro + Vector2(-r * 0.5, -r * 0.8),
		centro + Vector2(r * 0.5, -r * 0.8), centro + Vector2(r, -r * 0.3), centro + Vector2(0.0, r)]), COLOR_DIAMANTE.darkened(0.25))
	lienzo.draw_colored_polygon(PackedVector2Array([centro + Vector2(-r, -r * 0.3), centro + Vector2(-r * 0.5, -r * 0.8),
		centro + Vector2(r * 0.5, -r * 0.8), centro + Vector2(r, -r * 0.3)]), COLOR_DIAMANTE.lightened(0.35))


func _draw() -> void:
	var fuente := ThemeDB.fallback_font
	var y := ALTO * 0.5
	var x := RADIO + 2.0
	pintar_moneda(self, Vector2(x, y), RADIO)
	x += RADIO + 6.0
	x = _numero(fuente, x, Coleccion.monedas, COLOR_MONEDA) + 18.0 + RADIO
	pintar_diamante(self, Vector2(x, y), RADIO)
	_numero(fuente, x + RADIO + 6.0, Coleccion.diamantes, COLOR_DIAMANTE)


func _numero(fuente: Font, x: float, cuanto: int, color: Color) -> float:
	var texto := str(cuanto)
	var base := Vector2(x, ALTO * 0.5 + TAMANO_LETRA * 0.36)
	draw_string_outline(fuente, base, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, TAMANO_LETRA, 4, Color(0.0, 0.0, 0.0, 0.8))
	draw_string(fuente, base, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, TAMANO_LETRA, color)
	return x + fuente.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, TAMANO_LETRA).x
