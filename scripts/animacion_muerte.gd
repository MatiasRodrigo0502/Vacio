## La animacion al matar con un arma legendaria o mitica (ArmaMago.muerte). Solo
## se ve: el enemigo ya esta muerto, y esto es lo que queda de el un momento,
## con su propio dibujo. Dibujada por codigo, como las bolas.
##
## De pie con la vista girada (Vista), como el enemigo del que sale.
class_name AnimacionMuerte
extends Node2D

## En el orden de herramientas/generar_armas.py.
enum Tipo { NINGUNA, RAYOS, TORBELLINO, LLAMARADA, ALMAS, ESQUIRLAS }

const DURACION: float = 0.8
const ESQUIRLAS_CUANTAS: int = 12
const RAYOS_CUANTOS: int = 6

var _tipo: int = Tipo.NINGUNA
var _color: Color = Color.WHITE
var _figura: Texture2D = null
## Lo que mide el enemigo.
var _alto: float = 40.0
var _voltear: bool = false
var _t: float = 0.0
## Un reparto fijo para todo su tiempo: si cambiara en cada fotograma, los rayos
## y las esquirlas temblarian en vez de moverse.
var _azar: PackedFloat32Array = PackedFloat32Array()


## La del enemigo que acaba de morir, aqui y en los demas ordenadores.
static func soltar_de(enemigo: Enemigo, tipo: int, color: Color) -> void:
	if tipo == Tipo.NINGUNA or enemigo.tipo == null:
		return
	soltar_local(enemigo, tipo, color)
	MundoRed.anunciar_muerte_arma(enemigo, tipo, color)


static func soltar_local(enemigo: Enemigo, tipo: int, color: Color) -> void:
	var animacion := AnimacionMuerte.new()
	animacion._tipo = tipo
	animacion._color = color
	animacion._figura = enemigo.figura()
	animacion._alto = enemigo.tipo.alto
	animacion._voltear = enemigo.mira_a_la_izquierda()
	enemigo.get_parent().add_child(animacion)
	animacion.global_position = enemigo.global_position


func _ready() -> void:
	z_index = 8
	rotation = Vista.giro
	add_to_group("de_pie")
	for i in 40:
		_azar.append(randf())


func _process(delta: float) -> void:
	_t += delta / DURACION
	if _t >= 1.0:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	match _tipo:
		Tipo.RAYOS:
			_pintar_rayos()
		Tipo.TORBELLINO:
			_pintar_torbellino()
		Tipo.LLAMARADA:
			_pintar_llamarada()
		Tipo.ALMAS:
			_pintar_almas()
		Tipo.ESQUIRLAS:
			_pintar_esquirlas()


## El dibujo del enemigo, centrado, con este giro, tamano y color.
func _pintar_figura(desplazado: Vector2, giro: float, escala: float, tinte: Color) -> void:
	if _figura == null:
		return
	var tamano := _figura.get_size() * _alto / _figura.get_size().y
	draw_set_transform(desplazado, giro, Vector2(-escala if _voltear else escala, escala))
	draw_texture_rect(_figura, Rect2(-tamano * 0.5, tamano), false, tinte)
	draw_set_transform(Vector2.ZERO)


## Lo fulmina un rayo: el cuerpo en blanco, temblando, y rayos que salen de el.
func _pintar_rayos() -> void:
	var queda := 1.0 - _t
	var temblor := Vector2(sin(_t * 90.0), cos(_t * 70.0)) * 3.0 * queda
	_pintar_figura(temblor, 0.0, 1.0, Color(3.0, 3.0, 3.0, queda))
	draw_circle(Vector2.ZERO, _alto * (0.5 + _t), Color(_color, 0.3 * queda))
	for i in RAYOS_CUANTOS:
		var punto := Vector2.ZERO
		var rumbo := i * TAU / RAYOS_CUANTOS + _azar[i] * 0.8
		var largo := _alto * (0.3 + _t * 0.9)
		# Tres tramos quebrados: un rayo recto no parece un rayo.
		for k in 3:
			var siguiente := punto + Vector2.from_angle(rumbo + (_azar[i + k * 7] - 0.5) * 1.6) * largo
			draw_line(punto, siguiente, Color(_color, queda), 4.0 * queda + 1.0, true)
			draw_line(punto, siguiente, Color(1.0, 1.0, 1.0, queda), 1.5, true)
			punto = siguiente


## Se lo traga un torbellino: gira, se encoge hacia el centro, y se cierra.
func _pintar_torbellino() -> void:
	var queda := 1.0 - _t
	for k in 3:
		var radio := _alto * (1.1 - _t * 0.7) * (1.0 - k * 0.25)
		var desde := _t * 14.0 + k * 2.1
		draw_arc(Vector2.ZERO, radio, desde, desde + 4.2, 32, Color(_color, 0.8 * queda), 4.0, true)
	_pintar_figura(Vector2.ZERO, _t * _t * 16.0, maxf(queda, 0.02), Color(1.0, 1.0, 1.0, minf(queda * 2.0, 1.0)))
	draw_circle(Vector2.ZERO, _alto * 0.22 * sin(_t * PI), Color(0.02, 0.0, 0.05, 0.95))


## Arde entero: el cuerpo se ennegrece y se apaga mientras suben las llamas.
func _pintar_llamarada() -> void:
	var queda := 1.0 - _t
	var ennegrecido := Color(1.0, 1.0, 1.0).lerp(Color(0.1, 0.05, 0.05), minf(_t * 2.0, 1.0))
	ennegrecido.a = minf(queda * 1.6, 1.0)
	_pintar_figura(Vector2.ZERO, 0.0, 1.0, ennegrecido)
	for i in 10:
		var x := (_azar[i] - 0.5) * _alto * 1.2
		var sube := fmod(_t * 2.2 + _azar[i + 10], 1.0)
		var alto := _alto * (0.5 + 0.6 * _azar[i + 20]) * queda
		var base := Vector2(x, _alto * 0.45 - sube * _alto * 1.2)
		var ancho := 7.0 + 5.0 * _azar[i + 5]
		var llama := PackedVector2Array([base + Vector2(-ancho, 0.0), base + Vector2(0.0, -alto), base + Vector2(ancho, 0.0)])
		draw_colored_polygon(llama, Color(_color, queda))
		var dentro := PackedVector2Array([base + Vector2(-ancho * 0.5, 0.0), base + Vector2(0.0, -alto * 0.55), base + Vector2(ancho * 0.5, 0.0)])
		draw_colored_polygon(dentro, Color(1.0, 0.95, 0.6, queda))


## Se le va el alma: el cuerpo se apaga en el suelo y el alma sube serpenteando.
func _pintar_almas() -> void:
	var queda := 1.0 - _t
	_pintar_figura(Vector2.ZERO, 0.0, 1.0, Color(0.25, 0.25, 0.3, minf(queda * 2.0, 1.0)))
	var sitio := Vector2(sin(_t * 9.0) * 12.0, -_t * _alto * 2.4)
	_pintar_figura(sitio, 0.0, 1.0 - _t * 0.3, Color(_color.r, _color.g, _color.b, 0.75 * queda))
	for i in 5:
		var mota := Vector2(sin(_t * 7.0 + i * 1.3) * _alto * 0.6, -_t * _alto * (1.0 + _azar[i] * 1.5))
		draw_circle(mota, 3.0 * queda + 1.0, Color(_color, queda))


## Se hace anicos: un fogonazo y trozos de su color que salen y caen.
func _pintar_esquirlas() -> void:
	var queda := 1.0 - _t
	draw_circle(Vector2.ZERO, _alto * 0.7 * queda, Color(1.0, 1.0, 1.0, 0.5 * queda * queda))
	for i in ESQUIRLAS_CUANTAS:
		var rumbo := i * TAU / ESQUIRLAS_CUANTAS + _azar[i] * 0.5
		var lejos := _alto * (0.3 + _t * (1.0 + _azar[i + 12]))
		var sitio := Vector2.from_angle(rumbo) * lejos + Vector2(0.0, _t * _t * _alto * 0.8)
		var lado := (5.0 + 7.0 * _azar[i + 24]) * queda + 2.0
		var giro := rumbo + _t * 9.0
		var trozo := PackedVector2Array([sitio + Vector2.from_angle(giro) * lado,
			sitio + Vector2.from_angle(giro + 2.2) * lado * 0.7,
			sitio + Vector2.from_angle(giro + 4.2) * lado * 0.8])
		draw_colored_polygon(trozo, Color(_color, minf(queda * 1.5, 1.0)))
