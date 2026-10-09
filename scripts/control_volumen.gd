## Dos barras: el volumen de la musica y el de los efectos. Va en el menu de
## pausa; lo que se elige lo guarda el autoload Sonido y se recuerda.
##
## POR QUE SE MONTA POR CODIGO: son dos filas iguales (nombre y barra), y asi
## ponerlo en otro menu es anadir este nodo, sin copiar ocho nodos a mano.
class_name ControlVolumen
extends GridContainer

const ANCHO_BARRA: float = 220.0


func _ready() -> void:
	columns = 2
	add_theme_constant_override("h_separation", 16)
	add_theme_constant_override("v_separation", 8)
	_fila("Música", Sonido.volumen_musica, func(valor: float) -> void:
		Sonido.volumen_musica = valor)
	var efectos := _fila("Efectos", Sonido.volumen_efectos, func(valor: float) -> void:
		Sonido.volumen_efectos = valor)
	# Al soltar la barra de efectos suena uno, para oir como queda. Al
	# soltar y no mientras se arrastra: arrastrando sonaria a ametralladora.
	efectos.drag_ended.connect(func(_cambiado: bool) -> void: Sonido.tocar(&"objeto"))


func _fila(nombre: String, valor: float, al_cambiar: Callable) -> HSlider:
	var etiqueta := Label.new()
	etiqueta.text = nombre
	etiqueta.add_theme_font_size_override("font_size", 16)
	etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(etiqueta)
	var barra := HSlider.new()
	barra.min_value = 0.0
	barra.max_value = 1.0
	barra.step = 0.05
	barra.value = valor
	barra.custom_minimum_size = Vector2(ANCHO_BARRA, 24.0)
	barra.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	barra.value_changed.connect(al_cambiar)
	add_child(barra)
	return barra
