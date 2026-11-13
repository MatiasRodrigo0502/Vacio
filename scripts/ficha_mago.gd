## La ficha de un mago para elegirlo: retrato, nombre, ventaja, pega y un
## boton. La usan el menu (al pulsar Jugar) y la pantalla del final (Cambiar
## mago): asi un mago se presenta igual en los dos sitios, y un cambio en la
## ficha no hay que hacerlo dos veces.
##
## Se monta por codigo a partir del .tres del mago: anadir un mago es dejar su
## .tres en resources/personajes/ y ya sale, con su retrato y su ventaja.
class_name FichaMago
extends VBoxContainer

signal elegido(personaje: PersonajeJugable)

## Ancho de la ficha. Fijo para que los textos de ventaja partan linea por el
## mismo sitio y las fichas queden del mismo tamano aunque uno tenga la
## ventaja mas larga. 250 desde que hay cuatro magos (2026-11-03): con 300,
## cuatro fichas y sus huecos median 1320 y la ventana 1152.
const ANCHO: float = 250.0
## Lo alto del retrato y el tamano de la letra de la ventaja y la pega. Con 170 y 17,
## y las descripciones del 2026-11-12 (la del oscuro con su quemadura, la del verde
## con su veneno), el panel de elegir mago medía 817 de alto en una pantalla de 648:
## los botones de jugar se cortaban y «Volver» quedaba fuera (Matias, 2026-11-13).
const ALTO_RETRATO: float = 130.0
const LETRA_VENTAJA: int = 15
const LETRA_PEGA: int = 14

var personaje: PersonajeJugable
## Para dejarle el foco a la primera ficha al abrir el panel.
var boton: Button


func _init(de: PersonajeJugable, texto_boton: String) -> void:
	personaje = de
	custom_minimum_size = Vector2(ANCHO, 0.0)
	add_theme_constant_override("separation", 8)

	var retrato := TextureRect.new()
	# Con la skin que lleva puesta, si lleva (Coleccion).
	retrato.texture = Coleccion.retrato_de(personaje)
	retrato.custom_minimum_size = Vector2(0.0, ALTO_RETRATO)
	retrato.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	retrato.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(retrato)

	add_child(_etiqueta(personaje.nombre, 26, personaje.color))
	add_child(_etiqueta(personaje.ventaja, LETRA_VENTAJA, Color(0.85, 0.82, 0.78)))
	add_child(_etiqueta(personaje.pega, LETRA_PEGA, Color(0.62, 0.58, 0.55)))

	# Relleno elastico: las ventajas no miden lo mismo, y sin esto el boton
	# de cada ficha quedaria a una altura distinta.
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var hueco := Control.new()
	hueco.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(hueco)

	boton = Button.new()
	boton.text = texto_boton
	boton.custom_minimum_size = Vector2(0.0, 44.0)
	boton.add_theme_font_size_override("font_size", 18)
	boton.pressed.connect(func() -> void: elegido.emit(personaje))
	add_child(boton)


func _etiqueta(texto: String, tamano: int, color: Color) -> Label:
	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.add_theme_font_size_override("font_size", tamano)
	etiqueta.add_theme_color_override("font_color", color)
	etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Las ventajas son frases, no titulos: sin esto se salen de la ficha.
	etiqueta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	etiqueta.custom_minimum_size = Vector2(ANCHO, 0.0)
	return etiqueta
