## La vida del jefe, abajo en el centro de la pantalla, y su presentacion al
## empezar la pelea: su nombre en grande y su frase (TipoEnemigo.titulo).
##
## POR QUE UNA BARRA Y NO EL PARPADEO DE SIEMPRE: los enemigos normales mueren
## en unos pocos disparos y no hace falta saber cuanto les queda. Al jefe hay
## que darle durante un par de minutos, y sin ver que baja no se sabe si se le
## esta haciendo algo. Las rayitas marcan donde cambia de fase.
##
## Abajo y no arriba: arriba a la izquierda esta la vida del jugador y arriba a
## la derecha el minimapa.
##
## La pone el HUD (Hud.mostrar_jefe) cuando se cierran las puertas de la sala
## del jefe, y se va sola cuando el jefe muere.
class_name BarraJefe
extends Control

const ANCHO: float = 460.0
const ALTO: float = 14.0
const MARGEN_ABAJO: float = 40.0
const COLOR_RELLENO := Color(0.72, 0.42, 1.0)
const COLOR_FONDO := Color(0.05, 0.02, 0.08, 0.85)
## Lo que tarda en salir la barra: despues de la presentacion.
const ESPERA_BARRA: float = 1.6
## Lo que acaba de perder se queda un momento en blanco y baja despacio:
## asi se ve cuanto ha quitado el ultimo golpe.
const BAJADA_RASTRO: float = 0.35

var _jefe: Enemigo = null
var _marcas: PackedFloat32Array = PackedFloat32Array()
## Lo que ensena la barra (sigue a la vida de verdad, deprisa) y el rastro
## blanco (la sigue despacio).
var _mostrada: float = 1.0
var _rastro: float = 1.0
var _alfa_barra: float = 0.0
var _titulo: Label
var _subtitulo: Label
var _nombre: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_titulo = _etiqueta(46, Color(0.86, 0.72, 1.0))
	_subtitulo = _etiqueta(18, Color(0.85, 0.8, 0.9))
	_nombre = _etiqueta(17, Color(0.9, 0.82, 1.0))
	resized.connect(_colocar)
	_colocar()


## Empieza la pelea con 'jefe': presentacion y, despues, la barra.
func presentar(jefe: Enemigo) -> void:
	_jefe = jefe
	_marcas = jefe.tipo.comportamiento.marcas_vida() if jefe.tipo.comportamiento != null else PackedFloat32Array()
	_mostrada = jefe.fraccion_vida()
	_rastro = _mostrada
	_alfa_barra = 0.0
	_titulo.text = jefe.tipo.nombre.to_upper()
	_subtitulo.text = jefe.tipo.titulo
	_nombre.text = jefe.tipo.nombre.to_upper()
	_nombre.modulate.a = 0.0
	visible = true
	for etiqueta in [_titulo, _subtitulo]:
		etiqueta.modulate.a = 0.0
		var presentacion := create_tween()
		presentacion.tween_property(etiqueta, "modulate:a", 1.0, 0.45)
		presentacion.tween_interval(1.2)
		presentacion.tween_property(etiqueta, "modulate:a", 0.0, 0.5)
	var barra := create_tween()
	barra.tween_interval(ESPERA_BARRA)
	barra.tween_property(self, "_alfa_barra", 1.0, 0.4)
	barra.parallel().tween_property(_nombre, "modulate:a", 1.0, 0.4)


func _process(delta: float) -> void:
	if not visible:
		return
	if not is_instance_valid(_jefe) or _jefe.fraccion_vida() <= 0.0:
		# Muerto: la barra se vacia y se va.
		_mostrada = move_toward(_mostrada, 0.0, delta * 2.0)
		_rastro = move_toward(_rastro, 0.0, delta * 2.0)
		_alfa_barra = move_toward(_alfa_barra, 0.0, delta * 0.8)
		_nombre.modulate.a = _alfa_barra
		if _alfa_barra <= 0.0:
			visible = false
	else:
		var vida := _jefe.fraccion_vida()
		_mostrada = move_toward(_mostrada, vida, delta * 1.5)
		_rastro = move_toward(_rastro, _mostrada, delta * BAJADA_RASTRO)
		_rastro = maxf(_rastro, _mostrada)
	queue_redraw()


func _draw() -> void:
	if _alfa_barra <= 0.0:
		return
	var caja := _caja()
	draw_rect(caja.grow(3.0), Color(COLOR_FONDO, COLOR_FONDO.a * _alfa_barra))
	draw_rect(Rect2(caja.position, Vector2(caja.size.x * _rastro, caja.size.y)),
		Color(1.0, 0.95, 1.0, 0.7 * _alfa_barra))
	draw_rect(Rect2(caja.position, Vector2(caja.size.x * _mostrada, caja.size.y)),
		Color(COLOR_RELLENO, _alfa_barra))
	# Un brillo arriba del relleno, para que no sea un rectangulo plano.
	draw_rect(Rect2(caja.position, Vector2(caja.size.x * _mostrada, 3.0)),
		Color(1.0, 0.9, 1.0, 0.35 * _alfa_barra))
	for marca in _marcas:
		var x := caja.position.x + caja.size.x * marca
		draw_line(Vector2(x, caja.position.y - 3.0), Vector2(x, caja.end.y + 3.0),
			Color(1.0, 1.0, 1.0, 0.55 * _alfa_barra), 2.0)
	draw_rect(caja.grow(3.0), Color(COLOR_RELLENO, 0.6 * _alfa_barra), false, 1.5)


func _caja() -> Rect2:
	return Rect2(Vector2((size.x - ANCHO) * 0.5, size.y - MARGEN_ABAJO - ALTO), Vector2(ANCHO, ALTO))


func _colocar() -> void:
	var caja := _caja()
	_titulo.position = Vector2(0.0, size.y * 0.3)
	_titulo.size = Vector2(size.x, 60.0)
	_subtitulo.position = Vector2(0.0, size.y * 0.3 + 62.0)
	_subtitulo.size = Vector2(size.x, 30.0)
	_nombre.position = Vector2(0.0, caja.position.y - 30.0)
	_nombre.size = Vector2(size.x, 26.0)


func _etiqueta(tamano: int, color: Color) -> Label:
	var etiqueta := Label.new()
	etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	etiqueta.add_theme_font_size_override("font_size", tamano)
	etiqueta.add_theme_color_override("font_color", color)
	etiqueta.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	etiqueta.add_theme_constant_override("outline_size", 6)
	etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(etiqueta)
	return etiqueta
