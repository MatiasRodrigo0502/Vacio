## Pantalla de fin de partida: victoria (piso 12 superado) o derrota (sin vida).
## Una sola escena para los dos casos porque solo cambian los textos; separarlas
## duplicaria layout para nada.
class_name PantallaFinal
extends CanvasLayer

signal reinicio_solicitado

@onready var _titulo: Label = $Centro/Caja/Titulo
@onready var _subtitulo: Label = $Centro/Caja/Subtitulo
@onready var _boton: Button = $Centro/Caja/BotonReiniciar


func _ready() -> void:
	_boton.pressed.connect(func() -> void: reinicio_solicitado.emit())


func mostrar_victoria(total_pisos: int) -> void:
	_titulo.text = "HAS LLEGADO AL NUCLEO"
	_titulo.modulate = Color(1.0, 0.78, 0.3)
	_subtitulo.text = "%d pisos superados. El vacio tiene fondo." % total_pisos
	_boton.text = "Jugar otra vez  (R)"
	_mostrar()


func mostrar_derrota(numero_piso: int) -> void:
	_titulo.text = "TE HAS QUEDADO EN EL PISO %d" % numero_piso
	_titulo.modulate = Color(0.95, 0.35, 0.28)
	_subtitulo.text = "Sin vida. El descenso termina aqui."
	_boton.text = "Reintentar  (R)"
	_mostrar()


func ocultar() -> void:
	visible = false


func _mostrar() -> void:
	visible = true
	_boton.grab_focus()
