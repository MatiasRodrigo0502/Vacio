## La ventana del tutorial: un titulo, unas lineas y «Entendido». La abre
## Tutorial al entrar en cada sala del piso 1.
##
## POR QUE PARA EL JUEGO: en la sala de la primera pelea los enemigos ya estan
## despiertos, y leyendo sin pausa te comerian. Como la pausa (MenuPausa), para
## el arbol entero y solo esta ventana sigue (process_mode ALWAYS); el jugador
## suelta solo la carga del ataque al pararse (Jugador._notification). En
## cooperativo no se puede parar, porque los demas siguen jugando: sale igual,
## sin parar nada.
##
## Se monta por codigo, como el panel del cooperativo: es poca cosa y cambia de
## titulo, texto y color con cada sala.
class_name AvisoTutorial
extends CanvasLayer

signal cerrado

## Encima del HUD (capa 2) y debajo de la pausa (4). La pantalla final esta
## tambien en la 3, pero no coinciden: con la partida acabada no se entra en
## ninguna sala.
const CAPA: int = 3
## Las teclas y lo importante, resaltados en el texto.
const COLOR_RESALTE := "#ffd27a"

var _estilo: StyleBoxFlat
var _titulo: Label
var _texto: RichTextLabel
var _boton: Button
## Si la pausa la ha puesto esta ventana (y por tanto la quita al cerrarse).
var _he_parado: bool = false


func _init() -> void:
	name = "AvisoTutorial"
	layer = CAPA
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_montar()


## Abre la ventana. El texto admite [color] de BBCode; [k]...[/k] lo resalta
## con COLOR_RESALTE.
func mostrar(titulo: String, texto: String, color: Color) -> void:
	_titulo.text = titulo
	_titulo.add_theme_color_override("font_color", color)
	_estilo.border_color = color
	_texto.text = texto.replace("[k]", "[color=%s]" % COLOR_RESALTE).replace("[/k]", "[/color]")
	visible = true
	if not Red.cooperativo() and not get_tree().paused:
		get_tree().paused = true
		_he_parado = true
	_boton.grab_focus()


func esta_abierto() -> bool:
	return visible


## Escape la cierra, y no llega a la pausa: si la abriera encima, al continuar
## quitaria la pausa con esta ventana todavia abierta.
func _input(evento: InputEvent) -> void:
	if visible and evento.is_action_pressed("pausar"):
		get_viewport().set_input_as_handled()
		_cerrar()


func _cerrar() -> void:
	if not visible:
		return
	visible = false
	if _he_parado:
		get_tree().paused = false
		_he_parado = false
	# Sin esto el boton se quedaria con el foco, escondido, y un Intro en mitad
	# de la partida lo pulsaria.
	get_viewport().gui_release_focus()
	cerrado.emit()


func _montar() -> void:
	# Oscurece un poco el juego de detras, para que se vea que esta parado.
	var fondo := ColorRect.new()
	fondo.color = Color(0.0, 0.0, 0.0, 0.45)
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)

	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centro)

	var panel := PanelContainer.new()
	_estilo = StyleBoxFlat.new()
	_estilo.bg_color = Color(0.07, 0.055, 0.05, 0.96)
	_estilo.set_border_width_all(2)
	_estilo.set_corner_radius_all(10)
	_estilo.content_margin_left = 34.0
	_estilo.content_margin_right = 34.0
	_estilo.content_margin_top = 24.0
	_estilo.content_margin_bottom = 24.0
	panel.add_theme_stylebox_override("panel", _estilo)
	centro.add_child(panel)

	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 18)
	panel.add_child(caja)

	_titulo = Label.new()
	_titulo.add_theme_font_size_override("font_size", 30)
	_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caja.add_child(_titulo)

	_texto = RichTextLabel.new()
	_texto.bbcode_enabled = true
	_texto.fit_content = true
	_texto.scroll_active = false
	_texto.custom_minimum_size = Vector2(680.0, 0.0)
	_texto.add_theme_font_size_override("normal_font_size", 20)
	# Mas espacio entre una linea y la siguiente que dentro de una que no
	# cabe: cada linea es una cosa distinta, y asi se ve donde empieza.
	_texto.add_theme_constant_override("line_separation", 3)
	_texto.add_theme_constant_override("paragraph_separation", 12)
	_texto.add_theme_color_override("default_color", Color(0.9, 0.87, 0.82))
	caja.add_child(_texto)

	_boton = Button.new()
	_boton.text = "Entendido"
	_boton.custom_minimum_size = Vector2(220.0, 44.0)
	_boton.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_boton.add_theme_font_size_override("font_size", 18)
	_boton.pressed.connect(_cerrar)
	caja.add_child(_boton)
