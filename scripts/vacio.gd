## Un agujero en el suelo: si lo pisas, te caes.
##
## Caer cuesta un corazon y te devuelve a la entrada de la sala. No mata de
## golpe: con tres corazones, un agujero que matara seria un "vuelve a
## empezar" por un paso mal dado, y eso frustra mas de lo que tensa.
##
## Se cae cuando los PIES estan dentro, no cuando el cuerpo roza el borde: en
## vista cenital el borde se puede pisar, y asi el jugador puede apurar.
##
## El dibujo sale de herramientas/generar_peligros.py (vacio.png) y se pinta en
## nueve trozos: esquinas y bordes a su tamano, y solo el centro estirado. Los
## agujeros miden cada uno lo suyo, y estirando la imagen entera el reborde
## saldria gordo en los grandes y fino en los pequenos.
class_name Vacio
extends Peligro

## Lo que hay que meterse para caer, en pixeles desde el borde.
const MARGEN_CAIDA: float = 10.0

const TEXTURA := preload("res://assets/peligros/vacio.png")
# Los cortes de los nueve trozos, en pixeles de la textura. Son los VACIO_*
# del generador: si se cambian alli, aqui tambien.
const LABIO: float = 8.0
const MARGEN_ARRIBA: float = 48.0
const MARGEN_LADOS: float = 24.0
const MARGEN_ABAJO: float = 22.0
## Tamano de agujero al que el reborde sale a escala 1. Los grandes lo
## agrandan (hasta ESCALA_MAXIMA) y los pequenos lo encogen, o el reborde se
## comeria el agujero. Con la camara de los pisos hondos, a escala 1 las
## piedras del reborde salian de pocos pixeles y se leian como un punteado.
const TAMANO_REFERENCIA: float = 100.0
const ESCALA_MINIMA: float = 0.7
const ESCALA_MAXIMA: float = 1.5

## Chinas que caen al agujero: dicen que ahi abajo no hay suelo.
const CHINAS: int = 4
const CAIDA: float = 1.6

## Tinte del piso, como el de las rocas: el reborde es de la misma piedra.
var tinte: Color = Color.WHITE

var _caja: StyleBoxTexture = null


func _ready() -> void:
	_caja = StyleBoxTexture.new()
	_caja.texture = TEXTURA
	_caja.texture_margin_left = MARGEN_LADOS
	_caja.texture_margin_right = MARGEN_LADOS
	_caja.texture_margin_top = MARGEN_ARRIBA
	_caja.texture_margin_bottom = MARGEN_ABAJO
	_caja.modulate_color = tinte
	super()


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
	# El reborde a escala, y dibujado por fuera del agujero: lo negro coincide
	# con la zona en la que te caes.
	var escala := clampf(minf(tamano.x, tamano.y) / TAMANO_REFERENCIA, ESCALA_MINIMA, ESCALA_MAXIMA)
	var caja := Rect2(-tamano * 0.5, tamano).grow(LABIO * escala)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * escala)
	draw_style_box(_caja, Rect2(caja.position / escala, caja.size / escala))
	draw_set_transform(Vector2.ZERO)
	_pintar_chinas()


## Chinas que se sueltan del borde de arriba y caen hacia lo negro,
## encogiendose y apagandose: se hunden, no llegan a ningun sitio.
func _pintar_chinas() -> void:
	var semilla := absf(position.x * 0.017 + position.y * 0.011)
	for i in CHINAS:
		var ciclo := fmod(_fase / CAIDA + i * 0.29 + semilla, 1.0)
		var x := (fmod(semilla * 37.0 + i * 0.61, 1.0) - 0.5) * tamano.x * 0.7
		var y := -tamano.y * 0.5 + tamano.y * 0.55 * ciclo * ciclo
		var lado := 3.0 * (1.0 - ciclo * 0.8)
		var color := Color(tinte.r * 0.55, tinte.g * 0.5, tinte.b * 0.5, 1.0 - ciclo)
		draw_rect(Rect2(x - lado * 0.5, y - lado * 0.5, lado, lado), color)
