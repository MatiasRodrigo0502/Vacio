## El altar de la antesala del jefe: al pisarlo, recupera el ataque especial.
##
## POR QUE: el especial es uno por piso. Sin esto, quien lo gasta por el camino
## llega al jefe sin el, y es justo la pelea en la que mas falta hace. Es lo
## que hace Isaac con la sala de antes del jefe: un respiro para llegar entero.
##
## Se pisa, no se toca: es una losa en el suelo con un cristal flotando
## encima, y esta en el centro de la antesala, de camino de una puerta a la
## otra. Recarga cada vez que se pisa sin el especial; con el especial ya
## listo, no hace nada.
class_name AltarEspecial
extends Area2D

## Radio de la losa.
const RADIO: float = 34.0
## Hasta donde sube y baja el cristal, y cada cuanto.
const FLOTE: float = 4.0
const RITMO: float = 1.8
## Lo que dura el destello al recargar.
const DESTELLO: float = 0.7
const COLOR_PIEDRA := Color(0.16, 0.11, 0.1)

var _fase: float = 0.0
var _destello: float = 0.0


func _ready() -> void:
	name = "AltarEspecial"
	# Solo vigila al jugador.
	collision_layer = 0
	collision_mask = 1
	monitorable = false
	# Encima del suelo, debajo del jugador.
	z_index = 3
	var forma := CollisionShape2D.new()
	var circulo := CircleShape2D.new()
	circulo.radius = RADIO * 0.8
	forma.shape = circulo
	add_child(forma)
	# Lo que hace, escrito en el suelo como los carteles del tutorial: un
	# altar que nadie sabe para que sirve no se usa.
	var cartel := Label.new()
	cartel.text = "recarga el ataque especial"
	cartel.add_theme_font_size_override("font_size", 15)
	cartel.add_theme_color_override("font_color", Color(Runas.COLOR, 0.8))
	cartel.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.7))
	cartel.add_theme_constant_override("outline_size", 4)
	cartel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cartel.size = Vector2(260.0, 24.0)
	cartel.position = Vector2(-130.0, RADIO + 10.0)
	add_child(cartel)


## Se mira en cada paso quien esta encima, y no al entrar: si se gasta el
## especial estando encima, tiene que poder recargarse sin salir y volver.
func _physics_process(_delta: float) -> void:
	for cuerpo in get_overlapping_bodies():
		var jugador := cuerpo as Jugador
		if jugador != null and not jugador.especial_disponible and jugador.vida_actual > 0:
			jugador.recargar_especial()
			_destello = DESTELLO
			Sonido.tocar(&"carga_lista")


func _process(delta: float) -> void:
	_fase += delta
	_destello = maxf(0.0, _destello - delta)
	queue_redraw()


func _draw() -> void:
	var brillo := _destello / DESTELLO
	var latido := 0.5 + 0.5 * sin(_fase * TAU / RITMO)
	# La losa: piedra oscura con el canto encendido y una runa en cada punto
	# cardinal.
	draw_circle(Vector2.ZERO, RADIO, COLOR_PIEDRA)
	draw_arc(Vector2.ZERO, RADIO, 0.0, TAU, 40, Color(Runas.COLOR, 0.5 + 0.3 * latido), 3.0, true)
	draw_arc(Vector2.ZERO, RADIO * 0.62, 0.0, TAU, 32, Color(Runas.COLOR, 0.25), 1.5, true)
	for i in 4:
		Runas.pintar(self, Vector2.RIGHT.rotated(i * TAU / 4.0) * RADIO * 0.81, 9.0, i + 2,
			Runas.COLOR, 0.6)
	# El destello al recargar: un aro que se abre.
	if brillo > 0.0:
		draw_arc(Vector2.ZERO, RADIO + (1.0 - brillo) * 40.0, 0.0, TAU, 40,
			Color(Runas.COLOR, brillo), 4.0, true)
	# El cristal, flotando por encima de la losa (en 3/4, encima es mas
	# arriba en pantalla), con su sombra en la losa.
	var arriba := Vector2(0.0, -30.0 - FLOTE * sin(_fase * TAU / RITMO))
	draw_circle(Vector2(0.0, 2.0), 9.0, Color(0.0, 0.0, 0.0, 0.35))
	draw_circle(arriba, 22.0 + 6.0 * brillo, Color(Runas.COLOR, 0.12 + 0.1 * latido + 0.3 * brillo))
	var cristal := PackedVector2Array([arriba + Vector2(0.0, -16.0), arriba + Vector2(9.0, 0.0),
		arriba + Vector2(0.0, 16.0), arriba + Vector2(-9.0, 0.0)])
	draw_colored_polygon(cristal, Color(1.0, 0.92, 0.78).lerp(Color.WHITE, brillo))
	draw_polyline(cristal + PackedVector2Array([cristal[0]]), Color(1.0, 0.7, 0.35), 1.5, true)
	draw_line(arriba + Vector2(0.0, -16.0), arriba + Vector2(0.0, 16.0), Color(1.0, 0.75, 0.45, 0.8), 1.0, true)
