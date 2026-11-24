## La clasificacion, en el menu principal (Matias, 2026-11-19): una tabla general
## con la mejor partida de cada jugador, leida de GitHub (Cuenta.leer_clasificacion).
## Ordenada por el piso mas hondo y, a igual piso, ganar antes que perder y menos
## tiempo: lo mismo que decide en el servidor cual es la mejor (esMejor en
## servidor/supabase/functions/subir-puntuacion/index.ts).
##
## Cada fila: puesto, cara del mago, apodo, piso, tiempo, precision del disparo
## basico, metodo de control y dispositivo. La de quien ha iniciado sesion, resaltada.
## Verla no pide cuenta.
class_name PanelClasificacion
extends Control

signal cerrado

## Ancho de cada columna. La cara va en la segunda.
const COLUMNAS := [
	["#", 44.0], ["", 48.0], ["Apodo", 190.0], ["Piso", 120.0], ["Tiempo", 96.0],
	["Precisión", 100.0], ["Control", 200.0], ["Dispositivo", 116.0],
]
const LADO_CARA: float = 40.0
const DISPOSITIVOS := {"pc": "PC", "movil": "Móvil", "navegador": "Navegador"}
const COLOR_MIA := Color(1.0, 0.86, 0.5)

var _estado: Label
var _filas: VBoxContainer
var _boton_volver: Button
var _cargando: bool = false


func _init() -> void:
	name = "PanelClasificacion"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = PaletaPortada.tema()
	visible = false


func _ready() -> void:
	var fondo := ColorRect.new()
	fondo.color = PaletaPortada.FONDO
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)
	var margen := MarginContainer.new()
	margen.set_anchors_preset(Control.PRESET_FULL_RECT)
	for lado in ["left", "right", "top", "bottom"]:
		margen.add_theme_constant_override("margin_" + lado, 24)
	add_child(margen)
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 10)
	margen.add_child(caja)

	var titulo := _etiqueta("Clasificación", 34, PaletaPortada.TITULO)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caja.add_child(titulo)
	var cabecera := _fila()
	for columna in COLUMNAS:
		cabecera.add_child(_celda(columna[0], columna[1], PaletaPortada.FLOJO))
	var centro_cabecera := CenterContainer.new()
	centro_cabecera.add_child(cabecera)
	caja.add_child(centro_cabecera)

	var desplazar := ScrollContainer.new()
	desplazar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desplazar.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	caja.add_child(desplazar)
	var centro := CenterContainer.new()
	centro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desplazar.add_child(centro)
	_filas = VBoxContainer.new()
	_filas.add_theme_constant_override("separation", 4)
	centro.add_child(_filas)

	_estado = _etiqueta("", 18, PaletaPortada.FLOJO)
	_estado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_estado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caja.add_child(_estado)

	var abajo := HBoxContainer.new()
	abajo.alignment = BoxContainer.ALIGNMENT_CENTER
	abajo.add_theme_constant_override("separation", 16)
	caja.add_child(abajo)
	var recargar := _boton("Actualizar")
	recargar.pressed.connect(_cargar)
	abajo.add_child(recargar)
	_boton_volver = _boton("Volver")
	_boton_volver.pressed.connect(func() -> void: cerrado.emit())
	abajo.add_child(_boton_volver)


func abrir() -> void:
	visible = true
	_boton_volver.grab_focus()
	_cargar()


func _cargar() -> void:
	if _cargando:
		return
	_cargando = true
	_estado.text = "Cargando…"
	var respuesta: Dictionary = await Cuenta.leer_clasificacion()
	_cargando = false
	if not is_inside_tree():
		return
	if not respuesta.ok:
		_estado.text = respuesta.mensaje
		return
	mostrar(respuesta.entradas)


## Pinta las filas. Aparte de _cargar para poder probarla con datos sin internet.
func mostrar(entradas: Array) -> void:
	for hijo in _filas.get_children():
		hijo.queue_free()
	var ordenadas := entradas.filter(func(e: Variant) -> bool: return e is Dictionary)
	ordenadas.sort_custom(es_mejor)
	var mia := Cuenta.apodo.to_lower() if Cuenta.con_sesion() else ""
	for i in ordenadas.size():
		_filas.add_child(_fila_de(i + 1, ordenadas[i], mia))
	if ordenadas.is_empty():
		_estado.text = "Aún no hay ninguna partida. ¡Sé el primero!"
	elif Cuenta.con_sesion():
		_estado.text = "Sale tu mejor partida. Se sube sola al acabar cada una."
	else:
		_estado.text = "Inicia sesión en el menú para que salgan tus partidas."


## Mas hondo; a igual piso, ganar antes que perder; luego menos tiempo.
static func es_mejor(a: Dictionary, b: Dictionary) -> bool:
	var piso_a := int(a.get("piso", 0))
	var piso_b := int(b.get("piso", 0))
	if piso_a != piso_b:
		return piso_a > piso_b
	if bool(a.get("victoria", false)) != bool(b.get("victoria", false)):
		return bool(a.get("victoria", false))
	return float(a.get("tiempo_s", 0.0)) < float(b.get("tiempo_s", 0.0))


## 1:05:09 o 12:34.
static func texto_tiempo(segundos: float) -> String:
	var total := int(segundos)
	var horas := total / 3600
	var minutos := (total % 3600) / 60
	if horas > 0:
		return "%d:%02d:%02d" % [horas, minutos, total % 60]
	return "%d:%02d" % [minutos, total % 60]


static func texto_control(nombre: String) -> String:
	var indice := MarcadorPartida.NOMBRES_CONTROL.find(nombre)
	return MarcadorPartida.TEXTOS_CONTROL[indice] if indice >= 0 else nombre


## La cara del mago, de su retrato. Un mago que ya no este en el juego sale sin cara.
static func cara_de(id_mago: String) -> Texture2D:
	for personaje in GestorProgreso.personajes:
		if MarcadorPartida.id_mago(personaje) == id_mago:
			return personaje.retrato
	return null


func _fila_de(puesto: int, entrada: Dictionary, mia: String) -> Control:
	var apodo := String(entrada.get("apodo", "?"))
	var color := COLOR_MIA if apodo.to_lower() == mia and mia != "" else PaletaPortada.TEXTO
	var fila := _fila()
	fila.add_child(_celda(str(puesto), COLUMNAS[0][1], color))
	var cara := TextureRect.new()
	cara.texture = cara_de(String(entrada.get("mago", "")))
	cara.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cara.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cara.custom_minimum_size = Vector2(COLUMNAS[1][1], LADO_CARA)
	fila.add_child(cara)
	fila.add_child(_celda(apodo, COLUMNAS[2][1], color))
	var piso := str(int(entrada.get("piso", 0)))
	if entrada.get("victoria", false):
		piso += " · ganada"
	fila.add_child(_celda(piso, COLUMNAS[3][1], color))
	fila.add_child(_celda(texto_tiempo(float(entrada.get("tiempo_s", 0.0))), COLUMNAS[4][1], color))
	fila.add_child(_celda("%.1f %%" % float(entrada.get("precision", 0.0)), COLUMNAS[5][1], color))
	fila.add_child(_celda(texto_control(String(entrada.get("control", ""))), COLUMNAS[6][1], color))
	var dispositivo := String(entrada.get("dispositivo", ""))
	fila.add_child(_celda(DISPOSITIVOS.get(dispositivo, dispositivo), COLUMNAS[7][1], color))
	return fila


func _fila() -> HBoxContainer:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 8)
	return fila


func _celda(texto: String, ancho: float, color: Color) -> Label:
	var celda := _etiqueta(texto, 18, color)
	celda.custom_minimum_size = Vector2(ancho, LADO_CARA)
	celda.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	celda.clip_text = true
	celda.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return celda


func _boton(texto: String) -> Button:
	var boton := Button.new()
	boton.text = texto
	boton.custom_minimum_size = Vector2(160.0, 46.0)
	boton.add_theme_font_size_override("font_size", 18)
	return boton


func _etiqueta(texto: String, letra: int, color: Color) -> Label:
	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.add_theme_font_size_override("font_size", letra)
	etiqueta.add_theme_color_override("font_color", color)
	return etiqueta
