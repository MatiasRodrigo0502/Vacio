## La ruleta del cofre de la sala secreta: una cinta con las ventajas que pasa
## por debajo de una marca, cada vez mas despacio, hasta pararse en la que
## toca. Lo que toca ya esta decidido al abrirse (Cofre): la cinta solo lo
## ensena con un poco de suspense.
##
## Como la ventana del tutorial (AvisoTutorial): para el juego mientras gira,
## salvo en cooperativo, y Escape no llega a la pausa. Montada por codigo.
##
## Desde el 2026-11-05 (Matias: la animacion del cofre era «muy basica») la
## ventana sale de golpe hacia fuera, con rayos dorados girando detras; la
## casilla que pasa por la marca crece y las de los lados se apagan; y al
## pararse, la ganada da un destello de su color, con chispas.
class_name Ruleta
extends CanvasLayer

## Se ha cogido lo que ha tocado.
signal terminada(mejora: ObjetoMejora)

## Encima del HUD (2), debajo de la pausa (4), como la ventana del tutorial.
const CAPA: int = 3
const ANCHO_CASILLA: float = 130.0
const ALTO_CASILLA: float = 150.0
## Casillas que se ven a la vez. Impar: la del centro es la que cuenta.
const VISIBLES: int = 5
## Vueltas enteras a la lista antes de pararse.
const VUELTAS: int = 6
const DURACION: float = 3.4
const COLOR_ORO := Color(1.0, 0.8, 0.3)

var _opciones: Array[ObjetoMejora] = []
var _ganada: ObjetoMejora
var _cinta: Control
var _casillas: Array[Control] = []
var _resultado: RichTextLabel
var _boton: Button
var _parada: bool = false
var _he_parado_el_juego: bool = false
## La casilla que esta debajo de la marca, para que suene un clic al cambiar.
var _bajo_la_marca: int = -1
var _objetivo: int = 0
var _panel: PanelContainer
var _titulo: Label
var _fondo: FondoRuleta
var _marca: MarcaRuleta
var _chispas: ChispasRuleta


func _init(opciones: Array[ObjetoMejora], ganada: ObjetoMejora) -> void:
	name = "Ruleta"
	layer = CAPA
	process_mode = Node.PROCESS_MODE_ALWAYS
	_opciones = opciones
	_ganada = ganada


func _ready() -> void:
	_montar()
	if not Red.cooperativo() and not get_tree().paused:
		get_tree().paused = true
		_he_parado_el_juego = true
	_entrar()
	_girar()


## La ventana sale del centro hacia fuera, pasandose un poco, y el fondo se
## oscurece. Se espera un fotograma: hasta entonces el panel no tiene tamano,
## y lo hace crecer desde su esquina.
func _entrar() -> void:
	_panel.modulate.a = 0.0
	await get_tree().process_frame
	_panel.pivot_offset = _panel.size * 0.5
	_panel.scale = Vector2.ONE * 0.6
	var entrada := create_tween().set_parallel()
	entrada.tween_property(_panel, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	entrada.tween_property(_panel, "modulate:a", 1.0, 0.2)
	entrada.tween_property(_fondo, "fuerza", 1.0, 0.4)


## La cinta lleva la lista repetida; se para en la ganada de la ultima vuelta,
## con el giro frenando como una ruleta de verdad (rapido al principio).
func _girar() -> void:
	var centro := ANCHO_CASILLA * VISIBLES * 0.5
	_objetivo = VUELTAS * _opciones.size() + maxi(_opciones.find(_ganada), 0)
	var desde := centro - ANCHO_CASILLA * 0.5
	var hasta := centro - (_objetivo + 0.5) * ANCHO_CASILLA
	var giro := create_tween()
	giro.tween_method(_mover, desde, hasta, DURACION) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	giro.finished.connect(_al_parar)


func _mover(x: float) -> void:
	_cinta.position.x = x
	var centro := ANCHO_CASILLA * VISIBLES * 0.5
	var bajo := int(floor((centro - x) / ANCHO_CASILLA))
	if bajo != _bajo_la_marca:
		_bajo_la_marca = bajo
		Sonido.tocar(&"clic")
	# La que pasa por la marca, grande y con toda su luz; las de los lados, mas
	# pequenas y a oscuras. Solo las que estan cerca: las demas no se ven.
	for i in range(maxi(0, bajo - 3), mini(_casillas.size(), bajo + 4)):
		var casilla := _casillas[i]
		var distancia := absf(casilla.position.x + casilla.size.x * 0.5 + x - centro) / ANCHO_CASILLA
		var cerca := 1.0 - clampf(distancia / 2.0, 0.0, 1.0)
		casilla.scale = Vector2.ONE * lerpf(0.84, 1.06, cerca)
		casilla.modulate = Color.WHITE.lerp(Color(0.5, 0.48, 0.46), 1.0 - cerca)


func _al_parar() -> void:
	_parada = true
	Sonido.tocar(&"objeto")
	Sonido.tocar(&"gacha_revelar")
	var casilla := _casillas[_objetivo]
	var latido := create_tween()
	latido.tween_property(casilla, "scale", Vector2(1.2, 1.2), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	latido.tween_property(casilla, "scale", Vector2(1.08, 1.08), 0.25)
	_titulo.text = "¡Te ha tocado!"
	_titulo.add_theme_color_override("font_color", _ganada.color.lerp(Color.WHITE, 0.3))
	_marca.ganar(_ganada.color)
	_fondo.ganar(_ganada.color)
	_chispas.soltar(casilla.get_global_rect().get_center(), _ganada.color)
	# Sin «Te ha tocado»: ya lo dice el titulo.
	_resultado.text = "[center][color=#%s]%s[/color]\n[color=#cfc6b8]%s[/color][/center]" % [
		_ganada.color.to_html(false), _ganada.nombre, _ganada.descripcion]
	_resultado.modulate.a = 1.0
	_boton.modulate.a = 1.0
	_boton.disabled = false
	_boton.grab_focus()


## Escape: mientras gira no hace nada (y no abre la pausa); parada, coge.
func _input(evento: InputEvent) -> void:
	if evento.is_action_pressed("pausar"):
		get_viewport().set_input_as_handled()
		if _parada:
			_coger()


func _coger() -> void:
	if not _parada:
		return
	_parada = false
	if _he_parado_el_juego:
		get_tree().paused = false
	get_viewport().gui_release_focus()
	terminada.emit(_ganada)
	queue_free()


func _montar() -> void:
	_fondo = FondoRuleta.new()
	_fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_fondo)

	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centro)

	var panel := PanelContainer.new()
	_panel = panel
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.07, 0.055, 0.05, 0.96)
	estilo.border_color = COLOR_ORO
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(10)
	estilo.content_margin_left = 30.0
	estilo.content_margin_right = 30.0
	estilo.content_margin_top = 22.0
	estilo.content_margin_bottom = 22.0
	estilo.shadow_color = Color(1.0, 0.75, 0.25, 0.35)
	estilo.shadow_size = 16
	panel.add_theme_stylebox_override("panel", estilo)
	centro.add_child(panel)

	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 14)
	panel.add_child(caja)

	var titulo := Label.new()
	titulo.text = "Cofre secreto"
	titulo.add_theme_font_size_override("font_size", 30)
	titulo.add_theme_color_override("font_color", COLOR_ORO)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_color_override("font_outline_color", Color(0.25, 0.12, 0.0))
	titulo.add_theme_constant_override("outline_size", 6)
	_titulo = titulo
	caja.add_child(titulo)

	# La ventana por la que pasa la cinta: recorta lo que se sale.
	var ventana := Control.new()
	ventana.custom_minimum_size = Vector2(ANCHO_CASILLA * VISIBLES, ALTO_CASILLA)
	ventana.clip_contents = true
	caja.add_child(ventana)

	_cinta = Control.new()
	ventana.add_child(_cinta)
	for vuelta in VUELTAS + 2:
		for mejora in _opciones:
			_casillas.append(_casilla(mejora, _casillas.size()))

	# La marca del centro, encima de la cinta.
	var marca := MarcaRuleta.new()
	marca.set_anchors_preset(Control.PRESET_FULL_RECT)
	marca.ancho_casilla = ANCHO_CASILLA
	marca.color = COLOR_ORO
	ventana.add_child(marca)
	_marca = marca

	_resultado = RichTextLabel.new()
	_resultado.bbcode_enabled = true
	_resultado.fit_content = true
	_resultado.scroll_active = false
	_resultado.custom_minimum_size = Vector2(ANCHO_CASILLA * VISIBLES, 0.0)
	_resultado.add_theme_font_size_override("normal_font_size", 20)
	_resultado.add_theme_constant_override("line_separation", 6)
	# Ocupa su sitio desde el principio (invisible): si no, al pararse la
	# ventana crece y la cinta da un salto.
	_resultado.text = "[center] \n [/center]"
	_resultado.modulate.a = 0.0
	caja.add_child(_resultado)

	_boton = Button.new()
	_boton.text = "Coger"
	_boton.custom_minimum_size = Vector2(220.0, 44.0)
	_boton.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_boton.add_theme_font_size_override("font_size", 18)
	_boton.pressed.connect(_coger)
	# Igual que el resultado: ocupa su sitio desde el principio, sin verse.
	_boton.modulate.a = 0.0
	_boton.disabled = true
	caja.add_child(_boton)

	# Las chispas van por encima de todo, tambien del panel.
	_chispas = ChispasRuleta.new()
	_chispas.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_chispas)


## Una casilla de la cinta: el icono de la ventaja, su nombre y un marco de
## su color.
func _casilla(mejora: ObjetoMejora, indice: int) -> Control:
	var casilla := Panel.new()
	casilla.position = Vector2(indice * ANCHO_CASILLA + 6.0, 6.0)
	casilla.size = Vector2(ANCHO_CASILLA - 12.0, ALTO_CASILLA - 12.0)
	# Crece y se encoge desde su centro (al pasar por la marca y al ganar).
	casilla.pivot_offset = casilla.size * 0.5
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.12, 0.1, 0.09)
	estilo.border_color = mejora.color
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(8)
	casilla.add_theme_stylebox_override("panel", estilo)
	_cinta.add_child(casilla)

	var icono := TextureRect.new()
	icono.texture = mejora.icono
	icono.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icono.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icono.position = Vector2(19.0, 14.0)
	icono.size = Vector2(casilla.size.x - 38.0, 70.0)
	casilla.add_child(icono)

	var nombre := Label.new()
	nombre.text = mejora.nombre
	nombre.add_theme_font_size_override("font_size", 15)
	nombre.add_theme_color_override("font_color", mejora.color.lerp(Color.WHITE, 0.35))
	nombre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nombre.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nombre.position = Vector2(4.0, 90.0)
	nombre.size = Vector2(casilla.size.x - 8.0, 44.0)
	casilla.add_child(nombre)
	return casilla


## La marca del centro de la ruleta: un marco de oro sobre la casilla que
## cuenta y un pico arriba y abajo. Un Control aparte para que quede por
## encima de la cinta.
class MarcaRuleta extends Control:
	var ancho_casilla: float = 130.0
	var color: Color = Color.WHITE
	## Desde que se paro (-1, aun gira) y el color de la ganada.
	var _ganada: float = -1.0
	var _color_ganada := Color.WHITE

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func ganar(color_ganada: Color) -> void:
		_ganada = 0.0
		_color_ganada = color_ganada

	func _process(delta: float) -> void:
		if _ganada >= 0.0:
			_ganada += delta
			queue_redraw()

	func _draw() -> void:
		var x := (size.x - ancho_casilla) * 0.5
		if _ganada >= 0.0:
			# Un resplandor de su color alrededor, que late, y un destello blanco
			# que se apaga en un tercio de segundo.
			var latido := 0.6 + 0.4 * sin(_ganada * 5.0)
			for k in 5:
				var crece := 2.0 + k * 3.0
				draw_rect(Rect2(x - crece, -crece, ancho_casilla + crece * 2.0, size.y + crece * 2.0), Color(_color_ganada, 0.12 * latido), false, 3.0)
			var destello := maxf(0.0, 1.0 - _ganada / 0.35)
			if destello > 0.0:
				draw_rect(Rect2(x, 0.0, ancho_casilla, size.y), Color(1.0, 1.0, 1.0, 0.6 * destello))
		draw_rect(Rect2(x + 2.0, 2.0, ancho_casilla - 4.0, size.y - 4.0), _color_ganada if _ganada >= 0.0 else color, false, 3.0)
		var medio := size.x * 0.5
		draw_colored_polygon(PackedVector2Array([Vector2(medio - 10.0, 0.0),
			Vector2(medio + 10.0, 0.0), Vector2(medio, 12.0)]), color)
		draw_colored_polygon(PackedVector2Array([Vector2(medio - 10.0, size.y),
			Vector2(medio + 10.0, size.y), Vector2(medio, size.y - 12.0)]), color)
		# Las de los lados, un poco a oscuras: la atencion, en el centro.
		draw_rect(Rect2(0.0, 0.0, x, size.y), Color(0.0, 0.0, 0.0, 0.35))
		draw_rect(Rect2(x + ancho_casilla, 0.0, x, size.y), Color(0.0, 0.0, 0.0, 0.35))



## El fondo de la ruleta: oscuro, con rayos dorados girando desde el centro.
## Al ganar, los rayos se tinen del color de la ventaja y crecen.
class FondoRuleta extends Control:
	## De 0 a 1, lo que se ha oscurecido al entrar (lo sube Ruleta._entrar).
	var fuerza: float = 0.0
	var _tiempo: float = 0.0
	var _color := Color(1.0, 0.8, 0.3)
	var _ganada: float = -1.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func ganar(color: Color) -> void:
		_color = color.lerp(Color(1.0, 0.85, 0.4), 0.3)
		_ganada = 0.0

	func _process(delta: float) -> void:
		_tiempo += delta
		if _ganada >= 0.0:
			_ganada += delta
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.6 * fuerza))
		var centro := size * 0.5
		var largo := size.length()
		var extra := clampf(_ganada / 0.4, 0.0, 1.0) if _ganada >= 0.0 else 0.0
		for i in 16:
			var angulo := i * TAU / 16.0 + _tiempo * (0.25 + 0.5 * extra)
			var ancho := 0.06 + 0.03 * extra
			draw_colored_polygon(PackedVector2Array([centro, centro + Vector2.from_angle(angulo - ancho) * largo,
				centro + Vector2.from_angle(angulo + ancho) * largo]), Color(_color, (0.06 + 0.06 * extra) * fuerza))


## Las chispas que saltan de la casilla ganada, por encima de todo.
class ChispasRuleta extends Control:
	var _chispas: Array[Dictionary] = []

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func soltar(desde: Vector2, color: Color) -> void:
		var local := desde - get_global_rect().position
		for i in 40:
			var tono := color.lerp(Color.WHITE, randf() * 0.6)
			_chispas.append({"p": local, "v": Vector2.from_angle(randf() * TAU) * randf_range(160.0, 520.0),
				"vida": 0.0, "max": randf_range(0.5, 1.1), "color": tono})

	func _process(delta: float) -> void:
		for i in range(_chispas.size() - 1, -1, -1):
			var c := _chispas[i]
			c.vida += delta
			c.v *= 1.0 - minf(1.0, 2.6 * delta)
			c.v.y += 260.0 * delta
			c.p += c.v * delta
			if c.vida >= c.max:
				_chispas.remove_at(i)
		queue_redraw()

	func _draw() -> void:
		for c in _chispas:
			var vida: float = 1.0 - c.vida / c.max
			var color: Color = c.color
			var cola: Vector2 = c.v * 0.035
			draw_line(c.p - cola, c.p, Color(color, vida), 3.0, true)
			draw_circle(c.p, 2.0, Color(1.0, 1.0, 0.95, vida))
