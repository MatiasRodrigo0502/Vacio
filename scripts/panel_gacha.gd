## El gacha, en el menu: dos pestanas (skins con monedas y armas con diamantes).
## Pedido por Matias el 2026-11-04 y rehecho el 2026-11-05 («mejora el gacha»):
##
## - a la izquierda, el escaparate (lo mas raro que puede salir, dando vueltas),
##   las probabilidades en barras, cuanto falta para la garantia y los botones
##   de tirar una o diez (diez cuestan menos y traen una del segundo tier o mejor);
## - a la derecha, la coleccion: lo que se tiene en color y lo que no en
##   silueta, con cuanto se lleva. Al pulsar una, su ficha (DetalleGacha), que es
##   donde se pone.
##
## Lo que sale lo ensena la CinematicaGacha.
##
## Montado por codigo, como la sala del cooperativo y por lo mismo que las fichas
## de los magos: una skin o un arma nuevas son un .tres mas, y salen aqui solas.
class_name PanelGacha
extends Control

signal cerrado

const COLOR_TITULO := Color(1.0, 0.74, 0.36)
const COLOR_TEXTO := Color(0.85, 0.82, 0.78)
const COLOR_APAGADO := Color(0.62, 0.58, 0.55)
const FONDO := Color(0.045, 0.036, 0.05)
## Cinco por fila caben en la columna de la derecha a 1152 de ancho.
const TARJETA := Vector2(124.0, 150.0)
## Cada cuanto cambia lo del escaparate.
const CAMBIO_ESCAPARATE: float = 3.5

var _tirada: TiradaGacha
var _boton_skins: Button
var _boton_armas: Button
var _escaparate: Control
var _giro_escaparate: GiroGacha
var _destacados: Array = []
var _destacado: int = 0
var _reloj: float = 0.0
var _probabilidades: Control
var _garantia: Label
var _boton_uno: Button
var _boton_diez: Button
var _estado: Label
var _progreso: Label
var _barra_progreso: ProgressBar
var _lista: VBoxContainer
var _detalle: DetalleGacha
var _cinematica: CinematicaGacha


func _init() -> void:
	name = "PanelGacha"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false


func _ready() -> void:
	var margen := MarginContainer.new()
	margen.set_anchors_preset(Control.PRESET_FULL_RECT)
	for lado in ["left", "right"]:
		margen.add_theme_constant_override("margin_" + lado, 26)
	for lado in ["top", "bottom"]:
		margen.add_theme_constant_override("margin_" + lado, 14)
	add_child(margen)
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 12)
	margen.add_child(caja)
	caja.add_child(_cabecera())
	var cuerpo := HBoxContainer.new()
	cuerpo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cuerpo.add_theme_constant_override("separation", 22)
	caja.add_child(cuerpo)
	cuerpo.add_child(_columna_tirar())
	cuerpo.add_child(_columna_coleccion())
	_detalle = DetalleGacha.new()
	_detalle.cerrado.connect(func() -> void: _rellenar())
	add_child(_detalle)
	_cinematica = CinematicaGacha.new()
	_cinematica.terminada.connect(_al_acabar_cinematica)
	_cinematica.otra_vez.connect(_tirar)
	add_child(_cinematica)
	Coleccion.cambiado.connect(_al_cambiar)
	_elegir(Coleccion.gacha_skins)


## Abre el panel (o vuelve a la coleccion, si estaba destapando algo).
func abrir() -> void:
	_cinematica.visible = false
	_detalle.visible = false
	visible = true
	_rellenar()
	_boton_uno.grab_focus()


func _process(delta: float) -> void:
	if not visible or _cinematica.visible:
		return
	_reloj += delta
	if _destacados.size() > 1 and _reloj >= CAMBIO_ESCAPARATE:
		_reloj = 0.0
		_destacado = (_destacado + 1) % _destacados.size()
		_poner_destacado()
	_escaparate.queue_redraw()
	queue_redraw()


## El fondo: oscuro, con unas motas del color del tier mas alto subiendo.
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), FONDO)
	var color := _tirada.colores[_tirada.tier_maximo()] if _tirada != null else COLOR_TITULO
	var tiempo := Time.get_ticks_msec() / 1000.0
	for i in 40:
		var x := fposmod(i * 197.3, size.x)
		var y := size.y - fposmod(i * 83.1 + tiempo * (12.0 + (i % 5) * 6.0), size.y + 40.0)
		draw_circle(Vector2(x, y), 1.2 + (i % 3) * 0.8, Color(color, 0.12 + (i % 4) * 0.04))


# --- Montaje -----------------------------------------------------------------

func _cabecera() -> Control:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 12)
	var titulo := _etiqueta("GACHA", 32, COLOR_TITULO)
	titulo.autowrap_mode = TextServer.AUTOWRAP_OFF
	titulo.add_theme_color_override("font_outline_color", Color(0.25, 0.1, 0.0))
	titulo.add_theme_constant_override("outline_size", 6)
	fila.add_child(titulo)
	_boton_skins = _pestana("Skins", Coleccion.gacha_skins)
	_boton_armas = _pestana("Armas", Coleccion.gacha_armas)
	var grupo := ButtonGroup.new()
	_boton_skins.button_group = grupo
	_boton_armas.button_group = grupo
	fila.add_child(_boton_skins)
	fila.add_child(_boton_armas)
	var hueco := Control.new()
	hueco.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(hueco)
	var monedero := Monedero.new()
	monedero.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fila.add_child(monedero)
	var volver := Button.new()
	volver.text = "Volver"
	volver.custom_minimum_size = Vector2(130.0, 40.0)
	volver.add_theme_font_size_override("font_size", 17)
	volver.pressed.connect(func() -> void: cerrado.emit())
	fila.add_child(volver)
	return fila


func _pestana(texto: String, tirada: TiradaGacha) -> Button:
	var boton := Button.new()
	boton.text = "%s · %s" % [texto, tirada.moneda()]
	boton.toggle_mode = true
	boton.custom_minimum_size = Vector2(190.0, 40.0)
	boton.add_theme_font_size_override("font_size", 17)
	boton.pressed.connect(_elegir.bind(tirada))
	return boton


func _columna_tirar() -> Control:
	var columna := VBoxContainer.new()
	columna.custom_minimum_size = Vector2(380.0, 0.0)
	columna.add_theme_constant_override("separation", 8)
	_escaparate = Control.new()
	_escaparate.custom_minimum_size = Vector2(380.0, 250.0)
	_escaparate.clip_contents = true
	_escaparate.draw.connect(_pintar_escaparate)
	columna.add_child(_escaparate)
	_giro_escaparate = GiroGacha.new()
	_giro_escaparate.position = Vector2(200.0, 10.0)
	_giro_escaparate.size = Vector2(180.0, 230.0)
	_giro_escaparate.velocidad = 2.0
	_escaparate.add_child(_giro_escaparate)
	_probabilidades = Control.new()
	_probabilidades.custom_minimum_size = Vector2(380.0, 96.0)
	_probabilidades.draw.connect(_pintar_probabilidades)
	columna.add_child(_probabilidades)
	_garantia = _etiqueta("", 15, COLOR_TITULO)
	columna.add_child(_garantia)
	var botones := HBoxContainer.new()
	botones.add_theme_constant_override("separation", 10)
	columna.add_child(botones)
	_boton_uno = _boton_tirar()
	_boton_uno.pressed.connect(_tirar.bind(1))
	botones.add_child(_boton_uno)
	_boton_diez = _boton_tirar()
	_boton_diez.pressed.connect(_tirar.bind(10))
	botones.add_child(_boton_diez)
	_estado = _etiqueta("", 14, COLOR_APAGADO)
	columna.add_child(_estado)
	return columna


func _boton_tirar() -> Button:
	var boton := Button.new()
	boton.custom_minimum_size = Vector2(185.0, 62.0)
	boton.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boton.add_theme_font_size_override("font_size", 17)
	return boton


func _columna_coleccion() -> Control:
	var columna := VBoxContainer.new()
	columna.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columna.add_theme_constant_override("separation", 8)
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 12)
	columna.add_child(fila)
	var titulo := _etiqueta("Colección", 22, COLOR_TEXTO)
	titulo.autowrap_mode = TextServer.AUTOWRAP_OFF
	fila.add_child(titulo)
	_barra_progreso = ProgressBar.new()
	_barra_progreso.show_percentage = false
	_barra_progreso.custom_minimum_size = Vector2(0.0, 14.0)
	_barra_progreso.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_barra_progreso.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fila.add_child(_barra_progreso)
	_progreso = _etiqueta("", 18, COLOR_TEXTO)
	_progreso.autowrap_mode = TextServer.AUTOWRAP_OFF
	fila.add_child(_progreso)
	var ayuda := _etiqueta("Pulsa una para verla y ponértela.", 14, COLOR_APAGADO)
	columna.add_child(ayuda)
	var desliza := ScrollContainer.new()
	desliza.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desliza.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	columna.add_child(desliza)
	_lista = VBoxContainer.new()
	_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lista.add_theme_constant_override("separation", 6)
	desliza.add_child(_lista)
	return columna


func _etiqueta(texto: String, tamano: int, color: Color) -> Label:
	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.add_theme_font_size_override("font_size", tamano)
	etiqueta.add_theme_color_override("font_color", color)
	etiqueta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return etiqueta


# --- Lo de cada pestana --------------------------------------------------------

func _elegir(tirada: TiradaGacha) -> void:
	_tirada = tirada
	_boton_skins.set_pressed_no_signal(tirada == Coleccion.gacha_skins)
	_boton_armas.set_pressed_no_signal(tirada == Coleccion.gacha_armas)
	# El escaparate: lo del tier mas alto.
	_destacados = Coleccion.catalogo_de(tirada).filter(func(cosa: Resource) -> bool: return cosa.tier == tirada.tier_maximo())
	_destacado = 0
	_reloj = 0.0
	_poner_destacado()
	_rellenar()


func _al_cambiar() -> void:
	if visible:
		_poner_botones()
		_probabilidades.queue_redraw()


func _rellenar() -> void:
	_poner_botones()
	_probabilidades.queue_redraw()
	var progreso := Coleccion.progreso(_tirada)
	_progreso.text = "%d / %d" % [progreso.x, progreso.y]
	_barra_progreso.max_value = progreso.y
	_barra_progreso.value = progreso.x
	for hijo in _lista.get_children():
		_lista.remove_child(hijo)
		hijo.queue_free()
	if _tirada == Coleccion.gacha_skins:
		_rellenar_skins()
	else:
		_rellenar_armas()


func _poner_botones() -> void:
	for boton: Button in [_boton_uno, _boton_diez]:
		var veces := 1 if boton == _boton_uno else 10
		boton.text = "Tirar ×%d\n%d %s" % [veces, _tirada.coste_de(veces), _tirada.moneda()]
		boton.disabled = not Coleccion.puede_tirar(_tirada, veces)
	var faltan := Coleccion.tiradas_hasta_garantia(_tirada)
	var arriba: String = _tirada.tiers[_tirada.tier_maximo()]
	_garantia.text = "" if faltan < 0 else "Garantía: %s en %d tiradas como mucho." % [arriba, faltan]
	if _tirada.garantia_diez > 0:
		_garantia.text += "\nDiez de golpe: al menos una de tier %s o mejor." % _tirada.tiers[_tirada.garantia_diez]
	if Coleccion.puede_tirar(_tirada):
		_estado.text = _texto_repetida()
	elif _tirada.usa_diamantes:
		_estado.text = "No tienes diamantes bastantes: solo los da el jefe del piso 12."
	else:
		_estado.text = "No tienes monedas bastantes: las dan los enemigos."


## Lo que da una repetida en este gacha, de su .tres: "20, 50, 100 o 250 monedas".
func _texto_repetida() -> String:
	var cantidades := PackedStringArray()
	for cantidad in _tirada.devolucion:
		cantidades.append(str(cantidad))
	var ultima := cantidades[-1]
	cantidades.resize(cantidades.size() - 1)
	return "Si te sale repetida, te da %s o %s %s, según su tier." % [", ".join(cantidades), ultima, _tirada.moneda()]


## Una fila por mago: la de siempre y las suyas.
func _rellenar_skins() -> void:
	for personaje in GestorProgreso.personajes:
		var suyas := Coleccion.skins_de(personaje.nombre)
		var tenidas := suyas.filter(func(skin: SkinMago) -> bool: return Coleccion.tiene(skin)).size()
		var rotulo := _etiqueta("%s   %d/%d" % [personaje.nombre, tenidas, suyas.size()], 16, personaje.color)
		_lista.add_child(rotulo)
		var fila := HBoxContainer.new()
		fila.add_theme_constant_override("separation", 8)
		_lista.add_child(fila)
		var puesta := Coleccion.skin_puesta(personaje.nombre)
		fila.add_child(_tarjeta(personaje, personaje.retrato, "De serie", "", COLOR_APAGADO, true, puesta == null))
		for skin in suyas:
			var tengo := Coleccion.tiene(skin)
			fila.add_child(_tarjeta(skin, skin.retrato, skin.nombre if tengo else "???", _tirada.tiers[skin.tier],
				_tirada.colores[skin.tier], tengo, puesta == skin))


## Sin arma, y las armas de la mas comun a la mas rara.
func _rellenar_armas() -> void:
	var rejilla := GridContainer.new()
	rejilla.columns = 5
	rejilla.add_theme_constant_override("h_separation", 8)
	rejilla.add_theme_constant_override("v_separation", 8)
	_lista.add_child(rejilla)
	var puesta := Coleccion.arma_puesta()
	rejilla.add_child(_tarjeta(null, null, "Sin arma", "", COLOR_APAGADO, true, puesta == null))
	var ordenadas := Coleccion.armas.duplicate()
	ordenadas.sort_custom(func(a: ArmaMago, b: ArmaMago) -> bool: return a.tier < b.tier)
	for arma: ArmaMago in ordenadas:
		var tengo := Coleccion.tiene(arma)
		rejilla.add_child(_tarjeta(arma, arma.ilustracion if arma.ilustracion != null else arma.icono,
			arma.nombre if tengo else "???", _tirada.tiers[arma.tier], _tirada.colores[arma.tier], tengo, puesta == arma))


## Una tarjeta: su dibujo (en silueta si no se tiene), su nombre y su tier. La
## puesta, con el borde gordo y el rotulo. Al pulsarla, su ficha.
func _tarjeta(cosa: Resource, imagen: Texture2D, nombre: String, rotulo: String, color: Color, tengo: bool,
		puesta: bool) -> Button:
	var boton := Button.new()
	boton.custom_minimum_size = TARJETA
	boton.tooltip_text = nombre
	for estado in ["normal", "hover", "pressed", "disabled", "focus"]:
		var marco := StyleBoxFlat.new()
		marco.bg_color = Color(0.07, 0.055, 0.07).blend(Color(color, 0.22 if puesta else 0.1)) if tengo else Color(0.05, 0.04, 0.05)
		if estado == "hover" or estado == "focus":
			marco.bg_color = marco.bg_color.lightened(0.12)
		marco.border_color = color if tengo else Color(color, 0.35)
		marco.set_border_width_all(4 if puesta else (2 if estado == "focus" else 1))
		marco.set_corner_radius_all(8)
		if tengo and color != COLOR_APAGADO:
			marco.shadow_color = Color(color, 0.3)
			marco.shadow_size = 4
		boton.add_theme_stylebox_override(estado, marco)
	var dibujo := TextureRect.new()
	dibujo.texture = imagen
	dibujo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	dibujo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	dibujo.set_anchors_preset(Control.PRESET_FULL_RECT)
	dibujo.offset_left = 8.0
	dibujo.offset_right = -8.0
	dibujo.offset_top = 20.0
	dibujo.offset_bottom = -36.0
	dibujo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not tengo:
		dibujo.modulate = Color(0.0, 0.0, 0.0, 0.85)
	boton.add_child(dibujo)
	var arriba := _etiqueta("PUESTA" if puesta else rotulo, 12, COLOR_TITULO if puesta else color)
	arriba.autowrap_mode = TextServer.AUTOWRAP_OFF
	arriba.position = Vector2(8.0, 3.0)
	arriba.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boton.add_child(arriba)
	var abajo := _etiqueta(nombre, 13, Color.WHITE if tengo else COLOR_APAGADO)
	abajo.autowrap_mode = TextServer.AUTOWRAP_OFF
	abajo.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	abajo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	abajo.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	abajo.offset_top = -32.0
	abajo.offset_bottom = -8.0
	abajo.offset_left = 4.0
	abajo.offset_right = -4.0
	abajo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boton.add_child(abajo)
	boton.pressed.connect(func() -> void: _detalle.ensenar(cosa, _tirada))
	return boton


# --- El escaparate y las probabilidades -------------------------------------------

func _poner_destacado() -> void:
	if _destacados.is_empty():
		_giro_escaparate.visible = false
		return
	var cosa: Resource = _destacados[_destacado]
	_giro_escaparate.visible = true
	_giro_escaparate.mostrar(cosa)
	_giro_escaparate.color_tier = _tirada.colores[cosa.tier]
	_giro_escaparate.silueta = false


func _pintar_escaparate() -> void:
	var lienzo := _escaparate
	var rect := Rect2(Vector2.ZERO, lienzo.size)
	var color := _tirada.colores[_tirada.tier_maximo()]
	var tiempo := Time.get_ticks_msec() / 1000.0
	var caja := StyleBoxFlat.new()
	caja.bg_color = color.darkened(0.82)
	caja.border_color = color
	caja.set_border_width_all(2)
	caja.set_corner_radius_all(12)
	lienzo.draw_style_box(caja, rect)
	# Rayos de su color girando detras de lo destacado.
	var centro := _giro_escaparate.position + _giro_escaparate.size * 0.5
	for i in 12:
		var angulo := i * TAU / 12.0 + tiempo * 0.3
		lienzo.draw_colored_polygon(PackedVector2Array([centro, centro + Vector2.from_angle(angulo - 0.1) * 300.0,
			centro + Vector2.from_angle(angulo + 0.1) * 300.0]), Color(color, 0.07))
	var fuente := get_theme_default_font()
	var arriba: String = _tirada.tiers[_tirada.tier_maximo()]
	_rotulo(lienzo, fuente, Vector2(18.0, 38.0), "DESTACADO", 15, COLOR_APAGADO)
	_rotulo(lienzo, fuente, Vector2(18.0, 84.0), arriba.to_upper(), 46, color)
	if _destacados.is_empty():
		return
	var cosa: Resource = _destacados[_destacado]
	_rotulo(lienzo, fuente, Vector2(18.0, 128.0), cosa.nombre, 22, Color.WHITE)
	if cosa is SkinMago:
		_rotulo(lienzo, fuente, Vector2(18.0, 152.0), cosa.mago, 15, COLOR_TEXTO)
	var por_ciento := String.num(_tirada.probabilidades[_tirada.tier_maximo()], 1).replace(".", ",")
	_rotulo(lienzo, fuente, Vector2(18.0, 196.0), "%s %% en cada tirada" % por_ciento, 15, COLOR_TEXTO)
	if Coleccion.tiene(cosa):
		_rotulo(lienzo, fuente, Vector2(18.0, 220.0), "¡Ya es tuya!", 15, COLOR_TITULO)
	# Puntos: cual de las destacadas se ve.
	for i in _destacados.size():
		lienzo.draw_circle(Vector2(lienzo.size.x - 18.0 - (_destacados.size() - 1 - i) * 14.0, lienzo.size.y - 14.0), 4.0,
			color if i == _destacado else Color(color, 0.3))


func _rotulo(lienzo: CanvasItem, fuente: Font, donde: Vector2, texto: String, tamano: int, color: Color) -> void:
	lienzo.draw_string_outline(fuente, donde, texto, HORIZONTAL_ALIGNMENT_LEFT, 190.0, tamano, 5, Color(0.0, 0.0, 0.0, 0.8))
	lienzo.draw_string(fuente, donde, texto, HORIZONTAL_ALIGNMENT_LEFT, 190.0, tamano, color)


## Una barra por tier, proporcional a su probabilidad (la de arriba, con un
## minimo para que se vea).
func _pintar_probabilidades() -> void:
	var lienzo := _probabilidades
	var fuente := get_theme_default_font()
	var alto := lienzo.size.y / _tirada.tiers.size()
	for i in _tirada.tiers.size():
		var y := i * alto
		var color := _tirada.colores[i]
		_rotulo(lienzo, fuente, Vector2(0.0, y + alto * 0.72), _tirada.tiers[i], 16, color)
		var fondo := Rect2(96.0, y + alto * 0.25, lienzo.size.x - 170.0, alto * 0.5)
		lienzo.draw_rect(fondo, Color(1.0, 1.0, 1.0, 0.06))
		var largo := maxf(4.0, fondo.size.x * _tirada.probabilidades[i] / 100.0)
		lienzo.draw_rect(Rect2(fondo.position, Vector2(largo, fondo.size.y)), color)
		var texto := "%s %%" % String.num(_tirada.probabilidades[i], 1).replace(".", ",")
		_rotulo(lienzo, fuente, Vector2(lienzo.size.x - 62.0, y + alto * 0.72), texto, 15, COLOR_TEXTO)


# --- Tirar ----------------------------------------------------------------------

func _tirar(veces: int) -> void:
	var resultados: Array[Dictionary] = []
	if veces == 1:
		var una := Coleccion.tirar(_tirada)
		if not una.is_empty():
			resultados.append(una)
	else:
		resultados = Coleccion.tirar_varias(_tirada, veces)
	if resultados.is_empty():
		return
	_cinematica.empezar(_tirada, resultados)


func _al_acabar_cinematica() -> void:
	_rellenar()
	_boton_uno.grab_focus()
