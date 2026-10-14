## Un numero de dano que salta del enemigo al darle (o del jugador al recibir
## un golpe), sube un poco y se apaga. Pedido por Matias el 2026-10-14: ver
## cuanto quita cada cosa.
##
## POR QUE TAMANO DE PANTALLA Y NO DE MUNDO: el zoom va de 0,6 (piso 1) a 1,35
## (piso 12). Con un tamano fijo en el mundo, en el piso 1 los numeros serian
## la mitad de pequenos que en el 12. Se escala al reves que la camara y asi
## miden siempre lo mismo en pantalla.
##
## Se crea con NumeroDano.soltar(), colgado de la sala o del piso, no del
## enemigo: el numero del golpe que lo mata tiene que seguir viendose.
class_name NumeroDano
extends Node2D

## De donde viene, para el color y el tamano.
enum Estilo { NORMAL, FUERTE, FUEGO, VACIO, JUGADOR }

const DURACION: float = 0.8
## Lo que sube, en px de pantalla.
const SUBIDA: float = 36.0
## Lo que tarda en ponerse de su tamano (sale un poco mas grande, de golpe).
const SALTO: float = 0.12

const TAMANOS := {
	Estilo.NORMAL: 17, Estilo.FUERTE: 24, Estilo.FUEGO: 14, Estilo.VACIO: 15, Estilo.JUGADOR: 19,
}
const COLORES := {
	Estilo.NORMAL: Color(1.0, 1.0, 1.0),
	Estilo.FUERTE: Color(1.0, 0.84, 0.3),
	Estilo.FUEGO: Color(1.0, 0.56, 0.2),
	Estilo.VACIO: Color(0.82, 0.62, 1.0),
	Estilo.JUGADOR: Color(1.0, 0.32, 0.3),
}

var _texto: String = ""
var _estilo: Estilo = Estilo.NORMAL
var _tiempo: float = 0.0
var _deriva: float = 0.0


## Suelta un numero en 'posicion' (global), colgado de 'padre'. 'cantidad' se
## redondea: medio punto de quemadura no se lee bien.
static func soltar(padre: Node, posicion: Vector2, cantidad: float, estilo: Estilo) -> void:
	if padre == null or cantidad <= 0.0:
		return
	var numero := NumeroDano.new()
	numero._texto = ("-" if estilo == Estilo.JUGADOR else "") + str(maxi(1, roundi(cantidad)))
	numero._estilo = estilo
	# Un poco a un lado o a otro: si llegan varios seguidos (el agujero negro,
	# la quemadura), no se pintan uno encima de otro.
	numero._deriva = randf_range(-14.0, 14.0)
	padre.add_child(numero)
	numero.global_position = posicion


func _ready() -> void:
	# Por encima de todo lo del mundo: enemigos, disparos, el jugador.
	z_index = 20
	z_as_relative = false
	_colocar()


func _process(delta: float) -> void:
	_tiempo += delta
	if _tiempo >= DURACION:
		queue_free()
		return
	_colocar()
	queue_redraw()


## Al reves que la camara, para medir siempre lo mismo en pantalla.
func _colocar() -> void:
	var camara := get_viewport().get_camera_2d()
	var zoom := camara.zoom.x if camara != null else 1.0
	var salto := 1.0 + 0.35 * clampf(1.0 - _tiempo / SALTO, 0.0, 1.0)
	scale = Vector2.ONE * salto / maxf(zoom, 0.05)


func _draw() -> void:
	var t := _tiempo / DURACION
	var alfa := clampf((1.0 - t) / 0.45, 0.0, 1.0)
	var subida := -SUBIDA * (1.0 - pow(1.0 - t, 2.0))
	var fuente := ThemeDB.fallback_font
	var tamano: int = TAMANOS[_estilo]
	var ancho := fuente.get_string_size(_texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamano).x
	var sitio := Vector2(-ancho * 0.5 + _deriva * t, subida)
	draw_string_outline(fuente, sitio, _texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamano, 5,
		Color(0.0, 0.0, 0.0, 0.85 * alfa))
	draw_string(fuente, sitio, _texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamano,
		Color(COLORES[_estilo], alfa))
