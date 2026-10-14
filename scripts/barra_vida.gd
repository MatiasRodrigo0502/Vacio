## La vida del jugador como barra, con el numero dentro («75 / 100»). Pedido
## por Matias el 2026-10-14, en lugar de los corazones.
##
## POR QUE UNA BARRA: con la vida en puntos (100, y cada golpe quita lo suyo:
## 20 una rata, 50 un rayo), los corazones se quedaban cortos. La barra baja
## lo que quita cada golpe, y lo que se acaba de perder se queda un momento en
## blanco y baja despacio: asi se ve cuanto ha quitado.
##
## Es mas larga cuanta mas vida maxima hay (ANCHO_POR_PUNTO): el mago rojo,
## con 30 de mas, la tiene mas larga, como antes tenia un corazon mas.
class_name BarraVida
extends Control

## px de barra por punto de vida maxima.
const ANCHO_POR_PUNTO: float = 2.0
const ALTO: float = 18.0
const COLOR_FONDO := Color(0.12, 0.05, 0.06, 0.9)
const COLOR_VIDA := Color(0.86, 0.2, 0.24)
const COLOR_BRILLO := Color(1.0, 0.5, 0.5)
const COLOR_CURA := Color(0.5, 1.0, 0.55)
## Por debajo de esta parte de la vida, la barra late: queda poco.
const POCA_VIDA: float = 0.3
## Lo que baja el rastro blanco, en partes de la barra por segundo.
const BAJADA_RASTRO: float = 0.45

var _actual: int = 0
var _maxima: int = 1
## Lo que ensena el rastro blanco (sigue a la vida despacio, solo bajando).
var _rastro: float = 0.0
## Cuanto queda del destello verde al curarse.
var _cura: float = 0.0
var _fase: float = 0.0


func actualizar(vida_actual: int, vida_maxima: int) -> void:
	var antes := _actual
	_actual = vida_actual
	_maxima = maxi(vida_maxima, 1)
	if vida_actual > antes:
		_cura = 1.0
	if _rastro < float(_actual):
		_rastro = float(_actual)
	queue_redraw()


func _process(delta: float) -> void:
	_fase += delta
	_cura = maxf(0.0, _cura - delta * 2.0)
	_rastro = maxf(float(_actual), _rastro - BAJADA_RASTRO * _maxima * delta)
	queue_redraw()


func _draw() -> void:
	var ancho := _maxima * ANCHO_POR_PUNTO
	var caja := Rect2(Vector2(0.0, (size.y - ALTO) * 0.5), Vector2(ancho, ALTO))
	draw_rect(caja.grow(2.0), Color(0.0, 0.0, 0.0, 0.6))
	draw_rect(caja, COLOR_FONDO)
	var parte := clampf(float(_actual) / _maxima, 0.0, 1.0)
	var rastro := clampf(_rastro / _maxima, 0.0, 1.0)
	draw_rect(Rect2(caja.position, Vector2(ancho * rastro, ALTO)), Color(1.0, 0.95, 0.9, 0.75))
	var color := COLOR_VIDA
	if parte <= POCA_VIDA and parte > 0.0:
		color = COLOR_VIDA.lerp(Color(1.0, 0.45, 0.4), 0.5 + 0.5 * sin(_fase * 8.0))
	color = color.lerp(COLOR_CURA, _cura * 0.7)
	draw_rect(Rect2(caja.position, Vector2(ancho * parte, ALTO)), color)
	# Un brillo arriba del relleno, para que no sea un rectangulo plano.
	draw_rect(Rect2(caja.position, Vector2(ancho * parte, 4.0)), Color(COLOR_BRILLO, 0.45))
	draw_rect(caja, Color(1.0, 1.0, 1.0, 0.25), false, 1.0)
	var texto := "%d / %d" % [_actual, _maxima]
	var fuente := ThemeDB.fallback_font
	var tamano := 14
	var medida := fuente.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamano)
	var sitio := Vector2((ancho - medida.x) * 0.5, caja.position.y + (ALTO + medida.y) * 0.5 - 4.0)
	draw_string_outline(fuente, sitio, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamano, 4, Color(0, 0, 0, 0.85))
	draw_string(fuente, sitio, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamano, Color.WHITE)
