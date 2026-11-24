## Panel de la cuenta, en el menu principal (Matias, 2026-11-19): entrar con correo y
## contrasena, registrarse (correo, contrasena y apodo, que es el nombre de la
## clasificacion) y cerrar la sesion. Todo lo de verdad lo hace el autoload Cuenta;
## esto solo lo pide y ensena lo que contesta.
##
## Se puede jugar sin cuenta: el panel solo hace falta para subir partidas.
## Por codigo, como el gacha: asi MenuPrincipal.tscn no cambia.
class_name PanelCuenta
extends Control

signal cerrado

const ANCHO: float = 440.0

var _titulo: Label
var _formulario: VBoxContainer
var _sesion: VBoxContainer
var _correo: LineEdit
var _contrasena: LineEdit
var _apodo: LineEdit
var _fila_apodo: Control
var _boton_enviar: Button
var _boton_cambiar: Button
var _boton_salir_sesion: Button
var _boton_volver: Button
var _quien: Label
var _mensaje: Label
var _registrando: bool = false
var _ocupado: bool = false


func _init() -> void:
	name = "PanelCuenta"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = PaletaPortada.tema()
	visible = false


func _ready() -> void:
	var fondo := ColorRect.new()
	fondo.color = PaletaPortada.FONDO
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centro)
	var caja := VBoxContainer.new()
	caja.custom_minimum_size.x = ANCHO
	caja.add_theme_constant_override("separation", 10)
	centro.add_child(caja)

	_titulo = _etiqueta("Cuenta", 34, PaletaPortada.TITULO)
	_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caja.add_child(_titulo)

	_formulario = VBoxContainer.new()
	_formulario.add_theme_constant_override("separation", 6)
	caja.add_child(_formulario)
	_correo = _campo(_formulario, "Correo electrónico", "tu@correo.com")
	_correo.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS
	_contrasena = _campo(_formulario, "Contraseña", "")
	_contrasena.secret = true
	_contrasena.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_PASSWORD
	_apodo = _campo(_formulario, "Apodo (el nombre que sale en la clasificación)", "Hasta %d caracteres" % Cuenta.APODO_MAXIMO)
	_apodo.max_length = Cuenta.APODO_MAXIMO
	_fila_apodo = _apodo.get_parent()
	# Intro en el ultimo campo envia, como en cualquier formulario.
	_contrasena.text_submitted.connect(_al_intro.bind(false))
	_apodo.text_submitted.connect(_al_intro.bind(true))
	_boton_enviar = _boton(_formulario, "Entrar", 22)
	_boton_enviar.pressed.connect(_enviar)
	_boton_cambiar = _boton(_formulario, "", 16)
	_boton_cambiar.flat = true
	_boton_cambiar.pressed.connect(_cambiar_modo)

	_sesion = VBoxContainer.new()
	_sesion.add_theme_constant_override("separation", 10)
	caja.add_child(_sesion)
	_quien = _etiqueta("", 20, PaletaPortada.TEXTO)
	_quien.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_quien.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sesion.add_child(_quien)
	_boton_salir_sesion = _boton(_sesion, "Cerrar sesión", 20)
	_boton_salir_sesion.pressed.connect(_cerrar_sesion)

	_mensaje = _etiqueta("", 16, PaletaPortada.FLOJO)
	_mensaje.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mensaje.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mensaje.custom_minimum_size.x = ANCHO
	caja.add_child(_mensaje)

	_boton_volver = _boton(caja, "Volver", 18)
	_boton_volver.pressed.connect(func() -> void: cerrado.emit())
	Cuenta.sesion_cambiada.connect(_actualizar)


func abrir() -> void:
	visible = true
	_mensaje.text = ""
	_contrasena.text = ""
	_actualizar()


func _actualizar() -> void:
	var con_sesion := Cuenta.con_sesion()
	var servicio := Cuenta.hay_servicio()
	_formulario.visible = servicio and not con_sesion
	_sesion.visible = con_sesion
	_fila_apodo.visible = _registrando
	_titulo.text = "Crear cuenta" if _registrando and not con_sesion else "Cuenta"
	_boton_enviar.text = "Crear cuenta" if _registrando else "Entrar"
	_boton_cambiar.text = "Ya tengo cuenta: entrar" if _registrando else "¿No tienes cuenta? Regístrate"
	if con_sesion:
		_quien.text = "Has entrado como %s\n%s" % [Cuenta.apodo, Cuenta.correo]
	if not servicio and not con_sesion:
		_mensaje.text = "Las cuentas aún no están configuradas en esta versión. Puedes jugar igual: la cuenta solo hace falta para subir partidas a la clasificación."
	_ocupar(false)
	if not visible:
		return
	if _formulario.visible:
		_correo.grab_focus()
	elif con_sesion:
		_boton_salir_sesion.grab_focus()
	else:
		_boton_volver.grab_focus()


## Intro en la contrasena envia al entrar; al registrarse, en el apodo, que va despues.
func _al_intro(_texto: String, en_apodo: bool) -> void:
	if en_apodo == _registrando:
		_enviar()


func _cambiar_modo() -> void:
	_registrando = not _registrando
	_mensaje.text = ""
	_actualizar()


func _enviar() -> void:
	if _ocupado:
		return
	_ocupar(true)
	_mensaje.add_theme_color_override("font_color", PaletaPortada.FLOJO)
	_mensaje.text = "Conectando…"
	var respuesta: Dictionary
	if _registrando:
		respuesta = await Cuenta.registrarse(_correo.text, _contrasena.text, _apodo.text)
		# Con la cuenta creada falta confirmar el correo: se pasa a «Entrar» con el
		# correo ya puesto.
		if respuesta.ok and not Cuenta.con_sesion():
			_registrando = false
	else:
		respuesta = await Cuenta.iniciar_sesion(_correo.text, _contrasena.text)
	if not is_inside_tree():
		return
	_contrasena.text = ""
	_actualizar()
	_mensaje.add_theme_color_override("font_color", PaletaPortada.TITULO if respuesta.ok else Color(1.0, 0.55, 0.5))
	_mensaje.text = respuesta.mensaje


func _cerrar_sesion() -> void:
	Cuenta.cerrar_sesion()
	_mensaje.add_theme_color_override("font_color", PaletaPortada.FLOJO)
	_mensaje.text = "Has cerrado la sesión. Puedes seguir jugando sin cuenta."
	_actualizar()


func _ocupar(ocupado: bool) -> void:
	_ocupado = ocupado
	for boton in [_boton_enviar, _boton_cambiar, _boton_salir_sesion]:
		boton.disabled = ocupado


func _campo(dentro: Control, texto: String, ayuda: String) -> LineEdit:
	var fila := VBoxContainer.new()
	fila.add_theme_constant_override("separation", 2)
	dentro.add_child(fila)
	fila.add_child(_etiqueta(texto, 15, PaletaPortada.FLOJO))
	var campo := LineEdit.new()
	campo.placeholder_text = ayuda
	# Alto comodo para el dedo en el movil.
	campo.custom_minimum_size.y = 44.0
	campo.add_theme_font_size_override("font_size", 18)
	fila.add_child(campo)
	return campo


func _boton(dentro: Control, texto: String, letra: int) -> Button:
	var boton := Button.new()
	boton.text = texto
	boton.custom_minimum_size.y = 46.0
	boton.add_theme_font_size_override("font_size", letra)
	dentro.add_child(boton)
	return boton


func _etiqueta(texto: String, letra: int, color: Color) -> Label:
	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.add_theme_font_size_override("font_size", letra)
	etiqueta.add_theme_color_override("font_color", color)
	return etiqueta
