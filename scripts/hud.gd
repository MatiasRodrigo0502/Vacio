## HUD minimo de la Fase 1: piso actual, nombre de la capa y vida.
## Es una CanvasLayer para que no le afecten ni el zoom ni el movimiento de la
## camara: el interfaz debe quedarse quieto mientras el mundo se estrecha.
class_name Hud
extends CanvasLayer

@onready var _etiqueta_piso: Label = $EtiquetaPiso
@onready var _etiqueta_capa: Label = $EtiquetaCapa
@onready var _corazones: Corazones = $Corazones


func actualizar_piso(numero_piso: int, total: int, nombre_capa: String) -> void:
	_etiqueta_piso.text = "PISO %d / %d" % [numero_piso, total]
	_etiqueta_capa.text = nombre_capa.to_upper()


func actualizar_vida(vida_actual: int, vida_maxima: int) -> void:
	_corazones.actualizar(vida_actual, vida_maxima)

