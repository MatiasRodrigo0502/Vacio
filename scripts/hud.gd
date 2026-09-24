## HUD: piso actual, nombre de la capa, vida y minimapa.
## Es una CanvasLayer para que no le afecten ni el zoom ni el movimiento de la
## camara: el interfaz debe quedarse quieto mientras el mundo se estrecha.
class_name Hud
extends CanvasLayer

@onready var _etiqueta_piso: Label = $EtiquetaPiso
@onready var _etiqueta_capa: Label = $EtiquetaCapa
@onready var _corazones: Corazones = $Corazones
@onready var _aviso: Label = $Aviso
@onready var _minimapa: Minimapa = $Minimapa

## Cuanto dura en pantalla el aviso de un objeto recogido.
const DURACION_AVISO: float = 2.6


func actualizar_piso(numero_piso: int, total: int, nombre_capa: String) -> void:
	_etiqueta_piso.text = "PISO %d / %d" % [numero_piso, total]
	_etiqueta_capa.text = nombre_capa.to_upper()


## Enseña el mapa del piso recien construido.
func mostrar_mapa(piso: Piso) -> void:
	_minimapa.mostrar(piso)


func actualizar_vida(vida_actual: int, vida_maxima: int) -> void:
	_corazones.actualizar(vida_actual, vida_maxima)


## Anuncia un objeto recien recogido. Sin esto, el jugador ve desaparecer algo
## del suelo y no se entera de que le ha tocado.
func anunciar_mejora(mejora: ObjetoMejora) -> void:
	_aviso.text = "%s  ·  %s" % [mejora.nombre, mejora.descripcion]
	_aviso.modulate = mejora.color
	_aviso.show()

	var desvanecer := create_tween()
	desvanecer.tween_interval(DURACION_AVISO)
	desvanecer.tween_property(_aviso, "modulate:a", 0.0, 0.6)
	desvanecer.tween_callback(_aviso.hide)
