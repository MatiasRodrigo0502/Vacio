## El gacha, en el menu: dos pestanas (skins con monedas y armas con diamantes),
## el boton de tirar, las probabilidades y la coleccion, donde se elige lo que se
## lleva puesto. Pedido por Matias el 2026-11-04.
##
## Montado por codigo, como la sala del cooperativo y por lo mismo que las fichas
## de los magos: una skin o un arma nuevas son un .tres mas, y salen aqui solas.
class_name PanelGacha
extends Control

signal cerrado

const COLOR_TITULO := Color(1.0, 0.74, 0.36)
const COLOR_TEXTO := Color(0.85, 0.82, 0.78)
const COLOR_APAGADO := Color(0.62, 0.58, 0.55)
## Cuatro filas caben sin deslizar (una por mago) y el nombre mas largo no se corta.
const TARJETA := Vector2(140.0, 118.0)
## Lo que tarda en destaparse, para que haya algo de intriga.
const ESPERA_REVELAR: float = 0.9

var _tirada: TiradaGacha
var _boton_skins: Button
var _boton_armas: Button
var _titulo_tirada: Label
var _tiers: VBoxContainer
var _boton_tirar: Button
var _estado: Label
var _detalle: Label
var _rejilla: GridContainer

var _revelacion: Control
var _rayos: Control
var _imagen: TextureRect
var _incognita: Label
var _tier_sacado: Label
var _nombre_sacado: Label
var _resultado: Label
var _boton_seguir: Button
var _color_revelado: Color = Color.WHITE
var _fase_rayos: float = 0.0


func _init() -> void:
	name = "PanelGacha"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false


func _ready() -> void:
	var fondo := ColorRect.new()
	fondo.color = Color(0.0627, 0.0471, 0.0431)
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)
	var margen := MarginContainer.new()
	margen.set_anchors_preset(Control.PRESET_FULL_RECT)
	for lado in ["left", "right"]:
		margen.add_theme_constant_override("margin_" + lado, 28)
	for lado in ["top", "bottom"]:
		margen.add_theme_constant_override("margin_" + lado, 16)
	add_child(margen)
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 10)
	margen.add_child(caja)
	caja.add_child(_cabecera())
	caja.add_child(_cuerpo())
	var volver := Button.new()
	volver.text = "Volver"
	volver.custom_minimum_size = Vector2(240.0, 42.0)
	volver.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	volver.add_theme_font_size_override("font_size", 18)
	volver.pressed.connect(func() -> void: cerrado.emit())
	caja.add_child(volver)
	_montar_revelacion()
	Coleccion.cambiado.connect(_al_cambiar)
	_elegir(Coleccion.gacha_skins)


## Abre el panel (o vuelve a la coleccion, si estaba destapando algo).
func abrir() -> void:
	_revelacion.visible = false
	visible = true
	_rellenar()
	_boton_tirar.grab_focus()


func _process(delta: float) -> void:
	if _revelacion != null and _revelacion.visible:
		_fase_rayos += delta
		_rayos.queue_redraw()


# --- Montaje -----------------------------------------------------------------

func _cabecera() -> Control:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 12)
	var titulo := _etiqueta("GACHA", 30, COLOR_TITULO)
	titulo.autowrap_mode = TextServer.AUTOWRAP_OFF
	titulo.custom_minimum_size = Vector2.ZERO
	fila.add_child(titulo)
	_boton_skins = _pestana("Skins (monedas)", Coleccion.gacha_skins)
	_boton_armas = _pestana("Armas (diamantes)", Coleccion.gacha_armas)
	var grupo := ButtonGroup.new()
	_boton_skins.button_group = grupo
	_boton_armas.button_group = grupo
	fila.add_child(_boton_skins)
	fila.add_child(_boton_armas)
	var hueco := Control.new()
	hueco.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(hueco)
	fila.add_child(Monedero.new())
	return fila


func _pestana(texto: String, tirada: TiradaGacha) -> Button:
	var boton := Button.new()
	boton.text = texto
	boton.toggle_mode = true
	boton.custom_minimum_size = Vector2(190.0, 40.0)
	boton.add_theme_font_size_override("font_size", 17)
	boton.pressed.connect(_elegir.bind(tirada))
	return boton


func _cuerpo() -> Control:
	var fila := HBoxContainer.new()
	fila.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fila.add_theme_constant_override("separation", 20)
	var izquierda := VBoxContainer.new()
	izquierda.custom_minimum_size = Vector2(270.0, 0.0)
	izquierda.add_theme_constant_override("separation", 8)
	fila.add_child(izquierda)
	_titulo_tirada = _etiqueta("", 22, COLOR_TEXTO)
	izquierda.add_child(_titulo_tirada)
	_tiers = VBoxContainer.new()
	_tiers.add_theme_constant_override("separation", 2)
	izquierda.add_child(_tiers)
	_boton_tirar = Button.new()
	_boton_tirar.custom_minimum_size = Vector2(0.0, 58.0)
	_boton_tirar.add_theme_font_size_override("font_size", 20)
	_boton_tirar.pressed.connect(_tirar)
	izquierda.add_child(_boton_tirar)
	_estado = _etiqueta("", 15, COLOR_APAGADO)
	izquierda.add_child(_estado)
	_detalle = _etiqueta("", 16, COLOR_TEXTO)
	izquierda.add_child(_detalle)
	var desliza := ScrollContainer.new()
	desliza.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desliza.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	fila.add_child(desliza)
	_rejilla = GridContainer.new()
	_rejilla.columns = 5
	_rejilla.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rejilla.add_theme_constant_override("h_separation", 8)
	_rejilla.add_theme_constant_override("v_separation", 8)
	desliza.add_child(_rejilla)
	return fila


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
	_detalle.text = ""
	_rellenar()


func _al_cambiar() -> void:
	if visible:
		_poner_boton()


func _rellenar() -> void:
	_titulo_tirada.text = "Probabilidades"
	for hijo in _tiers.get_children():
		hijo.queue_free()
	for i in _tirada.tiers.size():
		_tiers.add_child(_etiqueta("%s   %s %%" % [_tirada.tiers[i], String.num(_tirada.probabilidades[i], 1).replace(".", ",")], 18, _tirada.colores[i]))
	_poner_boton()
	for hijo in _rejilla.get_children():
		_rejilla.remove_child(hijo)
		hijo.queue_free()
	if _tirada == Coleccion.gacha_skins:
		_rellenar_skins()
	else:
		_rellenar_armas()


func _poner_boton() -> void:
	_boton_tirar.text = "Tirar: %d %s" % [_tirada.coste, _tirada.moneda()]
	var llega := Coleccion.puede_tirar(_tirada)
	_boton_tirar.disabled = not llega
	if llega:
		_estado.text = _texto_repetida()
	elif _tirada.usa_diamantes:
		_estado.text = "No tienes diamantes bastantes: solo los dan los jefes."
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
		var puesta := Coleccion.skin_puesta(personaje.nombre)
		_rejilla.add_child(_tarjeta(personaje.retrato, personaje.nombre, personaje.color, true, puesta == null,
			func() -> void: Coleccion.poner_skin(personaje.nombre, null), "De serie"))
		for skin in Coleccion.skins_de(personaje.nombre):
			var tengo := Coleccion.tiene(skin)
			_rejilla.add_child(_tarjeta(skin.retrato if tengo else null, skin.nombre if tengo else "???",
				_tirada.colores[skin.tier], tengo, puesta == skin,
				func() -> void: Coleccion.poner_skin(skin.mago, skin), _tirada.tiers[skin.tier]))


## Sin arma, y las armas de la mas comun a la mas rara.
func _rellenar_armas() -> void:
	var puesta := Coleccion.arma_puesta()
	_rejilla.add_child(_tarjeta(null, "Sin arma", COLOR_APAGADO, true, puesta == null,
		func() -> void: _poner_arma(null), "De serie"))
	for arma in Coleccion.armas:
		var tengo := Coleccion.tiene(arma)
		_rejilla.add_child(_tarjeta(arma.icono if tengo else null, arma.nombre if tengo else "???",
			_tirada.colores[arma.tier], tengo, puesta == arma,
			func() -> void: _poner_arma(arma), _tirada.tiers[arma.tier]))


func _poner_arma(arma: ArmaMago) -> void:
	Coleccion.poner_arma(arma)
	_detalle.text = "" if arma == null else "%s\n%s" % [arma.nombre, arma.descripcion]


## Una tarjeta: su dibujo, su nombre y su tier. Puesta, con el borde mas gordo;
## sin tener, apagada y sin dibujo.
func _tarjeta(imagen: Texture2D, nombre: String, color: Color, tengo: bool, puesta: bool,
		al_pulsar: Callable, rotulo: String) -> Button:
	var boton := Button.new()
	boton.custom_minimum_size = TARJETA
	boton.icon = imagen
	boton.expand_icon = true
	boton.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boton.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	boton.text = "%s\n%s" % [nombre, rotulo]
	boton.clip_text = true
	boton.add_theme_font_size_override("font_size", 13)
	boton.add_theme_color_override("font_color", color)
	boton.add_theme_color_override("font_disabled_color", Color(color, 0.45))
	boton.disabled = not tengo
	var marco := StyleBoxFlat.new()
	marco.bg_color = Color(color, 0.22) if puesta else Color(0.09, 0.07, 0.07)
	marco.border_color = color if tengo else Color(color, 0.3)
	marco.set_border_width_all(4 if puesta else 1)
	marco.set_corner_radius_all(6)
	marco.set_content_margin_all(6.0)
	for estado in ["normal", "hover", "pressed", "disabled", "focus"]:
		boton.add_theme_stylebox_override(estado, marco)
	# Vuelve a pintarlas por el borde de la puesta. Diferido: no se puede borrar
	# un boton en mitad de su propia senal.
	boton.pressed.connect(func() -> void:
		al_pulsar.call()
		_rellenar.call_deferred())
	return boton


# --- Tirar ----------------------------------------------------------------------

func _montar_revelacion() -> void:
	_revelacion = Control.new()
	_revelacion.set_anchors_preset(Control.PRESET_FULL_RECT)
	_revelacion.visible = false
	add_child(_revelacion)
	var oscuro := ColorRect.new()
	oscuro.color = Color(0.0, 0.0, 0.0, 0.88)
	oscuro.set_anchors_preset(Control.PRESET_FULL_RECT)
	_revelacion.add_child(oscuro)
	_rayos = Control.new()
	_rayos.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rayos.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rayos.draw.connect(_pintar_rayos)
	_revelacion.add_child(_rayos)
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	_revelacion.add_child(centro)
	var caja := VBoxContainer.new()
	caja.alignment = BoxContainer.ALIGNMENT_CENTER
	caja.add_theme_constant_override("separation", 10)
	centro.add_child(caja)
	_imagen = TextureRect.new()
	_imagen.custom_minimum_size = Vector2(340.0, 280.0)
	_imagen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_imagen.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	caja.add_child(_imagen)
	_incognita = _etiqueta("?", 150, COLOR_TEXTO)
	_incognita.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caja.add_child(_incognita)
	_tier_sacado = _centrada(34)
	caja.add_child(_tier_sacado)
	_nombre_sacado = _centrada(26)
	caja.add_child(_nombre_sacado)
	_resultado = _centrada(18)
	caja.add_child(_resultado)
	_boton_seguir = Button.new()
	_boton_seguir.text = "Seguir"
	_boton_seguir.custom_minimum_size = Vector2(240.0, 46.0)
	_boton_seguir.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_boton_seguir.add_theme_font_size_override("font_size", 20)
	_boton_seguir.pressed.connect(_al_seguir)
	caja.add_child(_boton_seguir)


func _centrada(tamano: int) -> Label:
	var etiqueta := _etiqueta("", tamano, COLOR_TEXTO)
	etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	etiqueta.custom_minimum_size = Vector2(620.0, 0.0)
	return etiqueta


func _tirar() -> void:
	var salida := Coleccion.tirar(_tirada)
	if salida.is_empty():
		return
	_revelar(salida)


## Primero la incognita, que cambia de color de tier en tier, y luego lo que ha
## salido. Se puede saltar la espera: el premio ya esta dado.
func _revelar(salida: Dictionary) -> void:
	var tier: int = salida.tier
	_revelacion.visible = true
	_boton_seguir.visible = false
	_imagen.visible = false
	_incognita.visible = true
	_tier_sacado.text = ""
	_nombre_sacado.text = ""
	_resultado.text = ""
	_color_revelado = Color(0.5, 0.5, 0.5)
	Sonido.tocar(&"carga_lista")
	var pasos := 9
	for i in pasos:
		_incognita.add_theme_color_override("font_color", _tirada.colores[i % _tirada.colores.size()])
		_color_revelado = _tirada.colores[i % _tirada.colores.size()]
		await get_tree().create_timer(ESPERA_REVELAR / pasos).timeout
		if not is_inside_tree() or not _revelacion.visible:
			return
	var objeto: Resource = salida.objeto
	_color_revelado = _tirada.colores[tier]
	_incognita.visible = false
	_imagen.visible = true
	_imagen.texture = objeto.retrato if objeto is SkinMago else objeto.icono
	_imagen.pivot_offset = _imagen.size * 0.5
	_imagen.scale = Vector2.ONE * 0.4
	create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT) \
		.tween_property(_imagen, "scale", Vector2.ONE, 0.35)
	_tier_sacado.text = _tirada.tiers[tier]
	_tier_sacado.add_theme_color_override("font_color", _color_revelado)
	_nombre_sacado.text = objeto.nombre if objeto is ArmaMago else "%s · %s" % [objeto.nombre, objeto.mago]
	if salida.nuevo:
		_resultado.text = "¡Nueva!"
		_resultado.add_theme_color_override("font_color", COLOR_TITULO)
	else:
		_resultado.text = "Ya la tenías: ganas %d %s" % [salida.devuelto, _tirada.moneda()]
		_resultado.add_theme_color_override("font_color", COLOR_APAGADO)
	Sonido.tocar(&"puertas_abren" if tier >= 2 else &"objeto")
	_boton_seguir.visible = true
	_boton_seguir.grab_focus()


func _al_seguir() -> void:
	_revelacion.visible = false
	_rellenar()
	_boton_tirar.grab_focus()


## Rayos del color del tier, girando detras de lo que ha salido.
func _pintar_rayos() -> void:
	var centro := _rayos.size * 0.5 - Vector2(0.0, 60.0)
	var largo := _rayos.size.length()
	for i in 12:
		var angulo := i * TAU / 12.0 + _fase_rayos * 0.3
		_rayos.draw_colored_polygon(PackedVector2Array([centro,
			centro + Vector2.from_angle(angulo - 0.09) * largo,
			centro + Vector2.from_angle(angulo + 0.09) * largo]), Color(_color_revelado, 0.12))
	_rayos.draw_circle(centro, 170.0, Color(_color_revelado, 0.14))
