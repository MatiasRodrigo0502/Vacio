## Lo de fuera de la sala en la que se juega, a oscuras.
##
## POR QUE: la pantalla es mas ancha y mas alta que la sala en todos los
## pisos (con la vista del piso 2, que tienen todos desde el 2026-10-22,
## sobran 116 px de mundo por lado en el 1 y 446 en el 12), asi que asomaba
## un trozo de las salas de al lado: sus enemigos dormidos, sus rocas, su
## objeto. Distraia, y ensenaba lo que hay detras de una puerta antes de
## cruzarla. Como en Isaac, solo se ve la sala en la que estas. Dentro de la
## sala no cambia nada.
##
## La sala con luz es la casilla entera (`Sala.rect_con_muros`, lo mismo a lo
## que se encaja la camara): su medio muro se ve, porque por ahi se sale, y
## el de la vecina se va apagando. La da la camara
## (`CamaraJuego.zona_iluminada`), que la mueve con su mismo suavizado; asi
## sirve igual en la sala del jefe, que es mas grande, y para quien mira a un
## companero en cooperativo.
##
## Son cuatro bandas pintadas en el mundo, no un shader de pantalla: con eso
## basta, y solo se repintan cuando la luz se mueve. Va encima de todo lo del
## mundo (lo mas alto, los numeros de dano, va a z 20) y debajo del HUD, que
## es otra capa.
class_name Penumbra
extends Node2D

## Lo oscuro que queda lo de fuera. No del todo negro: se intuye que sigue
## habiendo roca, pero no lo que hay en ella.
const OPACIDAD: float = 0.92
## Lo que tarda en oscurecerse del todo desde el borde de la casilla, en
## pixeles de mundo. Un corte en seco parecia un error de dibujo.
const DEGRADADO: float = 48.0
## Hasta donde llega lo oscuro desde la sala. Con la vista mas abierta (el
## piso 1, unos 1850 x 1040 px de mundo) sobra.
const ALCANCE: float = 4000.0

var _camara: CamaraJuego
## La zona con la que se pinto por ultima vez: si la de la camara no ha
## cambiado, no hace falta repintar.
var _pintada: Rect2 = Rect2()


func _init(camara: CamaraJuego) -> void:
	_camara = camara
	name = "Penumbra"
	z_index = 30


func _process(_delta: float) -> void:
	var zona := _camara.zona_iluminada()
	# Aproximado y no exacto: el suavizado se acerca al destino sin llegar
	# nunca a la ultima cifra, y se repintaria siempre.
	if not zona.is_equal_approx(_pintada):
		_pintada = zona
		queue_redraw()


func _draw() -> void:
	if not _pintada.has_area():
		return
	var oscuro := Color(0.0, 0.0, 0.0, OPACIDAD)
	var claro := Color(0.0, 0.0, 0.0, 0.0)
	var dentro := _pintada
	var medio := dentro.grow(DEGRADADO)
	var fuera := dentro.grow(ALCANCE)

	# Oscuro del todo, de 'medio' hacia fuera: arriba y abajo de lado a lado,
	# y a los lados solo la altura de en medio, para que no se pisen (donde se
	# pisan, se veria mas oscuro).
	draw_rect(Rect2(fuera.position.x, fuera.position.y,
		fuera.size.x, medio.position.y - fuera.position.y), oscuro)
	draw_rect(Rect2(fuera.position.x, medio.end.y,
		fuera.size.x, fuera.end.y - medio.end.y), oscuro)
	draw_rect(Rect2(fuera.position.x, medio.position.y,
		medio.position.x - fuera.position.x, medio.size.y), oscuro)
	draw_rect(Rect2(medio.end.x, medio.position.y,
		fuera.end.x - medio.end.x, medio.size.y), oscuro)

	# El degradado: un trapecio por lado, transparente pegado a la sala y
	# oscuro por fuera. En las esquinas se juntan en diagonal, a la misma
	# opacidad por los dos lados, asi que no se nota la union.
	var esquinas_dentro := _esquinas(dentro)
	var esquinas_medio := _esquinas(medio)
	for i in 4:
		var j := (i + 1) % 4
		draw_polygon(
			PackedVector2Array([esquinas_dentro[i], esquinas_dentro[j],
				esquinas_medio[j], esquinas_medio[i]]),
			PackedColorArray([claro, claro, oscuro, oscuro]))


## Las cuatro esquinas de una zona, en el sentido de las agujas del reloj.
func _esquinas(zona: Rect2) -> PackedVector2Array:
	return PackedVector2Array([zona.position, Vector2(zona.end.x, zona.position.y),
		zona.end, Vector2(zona.position.x, zona.end.y)])
