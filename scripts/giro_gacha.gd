## Lo que sale en el gacha, en grande: una skin dando vueltas (las 8 direcciones
## de su tira 'giro', SkinMago.giro) o un arma flotando (su ilustracion). Lo usan
## el escaparate, la ficha y la cinematica del gacha.
##
## Dibujado por codigo, y no con un AnimatedSprite: tiene que poder ir en
## silueta (lo que aun no se tiene se ve negro), con un resplandor del color de
## su tier detras y a la velocidad que diga quien lo use (la cinematica lo hace
## girar rapido y frenar).
class_name GiroGacha
extends Control

## Direcciones por segundo. 0, quieto en 'direccion'.
var velocidad: float = 2.5
## La direccion en la que empieza (o se queda, quieto), en el orden de
## Jugador.LADOS: 2 = de frente.
var direccion: float = 2.0
## Negro, para lo que aun no se tiene.
var silueta: bool = false
## Color del resplandor de detras. Transparente, sin resplandor.
var color_tier: Color = Color(0.0, 0.0, 0.0, 0.0)

var _tira: Texture2D
var _imagen: Texture2D
var _cuadros: int = 1
var _fase: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Una skin o un PersonajeJugable (con su 'giro'), o un arma (su ilustracion).
func mostrar(cosa: Resource) -> void:
	_tira = null
	_imagen = null
	if cosa is SkinMago or cosa is PersonajeJugable:
		_tira = cosa.giro
		if _tira == null:
			_imagen = cosa.retrato
	elif cosa is ArmaMago:
		_imagen = cosa.ilustracion if cosa.ilustracion != null else cosa.icono
	_cuadros = maxi(1, roundi(float(_tira.get_width()) / _tira.get_height())) if _tira != null else 1
	_fase = 0.0
	queue_redraw()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_fase += delta
	direccion = fposmod(direccion + velocidad * delta, float(_cuadros))
	queue_redraw()


func _draw() -> void:
	var centro := size * 0.5
	var lado := minf(size.x, size.y)
	if color_tier.a > 0.0:
		_pintar_resplandor(centro, lado * 0.46)
	var color := Color(0.02, 0.01, 0.03, 0.92) if silueta else Color.WHITE
	if _tira != null:
		var alto := float(_tira.get_height())
		var cuadro := int(direccion) % _cuadros
		var region := Rect2(cuadro * alto, 0.0, alto, alto)
		draw_texture_rect_region(_tira, Rect2(centro - Vector2.ONE * lado * 0.5, Vector2.ONE * lado), region, color)
	elif _imagen != null:
		# El arma flota: sube y baja un poco y se mece.
		var alto := lado * 0.92
		var tamano := _imagen.get_size() * (alto / maxf(_imagen.get_width(), _imagen.get_height()))
		draw_set_transform(centro + Vector2(0.0, sin(_fase * 2.0) * lado * 0.02), sin(_fase * 1.3) * 0.05, Vector2.ONE)
		draw_texture_rect(_imagen, Rect2(-tamano * 0.5, tamano), false, color)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Un circulo que se apaga hacia fuera, en anillos (sin sombreador: basta y se
## ve igual en todos los sistemas).
func _pintar_resplandor(centro: Vector2, radio: float) -> void:
	var pulso := 0.85 + 0.15 * sin(_fase * 2.4)
	for i in 10:
		var k := 1.0 - i / 10.0
		draw_circle(centro, radio * k * pulso, Color(color_tier, 0.05 + 0.03 * i / 10.0))
