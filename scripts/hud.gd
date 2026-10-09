## HUD: piso actual, nombre de la capa, vida, ataque especial, ventajas
## recogidas y minimapa.
## Es una CanvasLayer para que no le afecten ni el zoom ni el movimiento de la
## camara: el interfaz debe quedarse quieto mientras el mundo se estrecha.
class_name Hud
extends CanvasLayer

@onready var _etiqueta_piso: Label = $EtiquetaPiso
@onready var _etiqueta_capa: Label = $EtiquetaCapa
@onready var _corazones: Corazones = $Corazones
@onready var _especial: Label = $Especial
@onready var _aviso: Label = $Aviso
@onready var _minimapa: Minimapa = $Minimapa
@onready var _mejoras: MejorasRecogidas = $Mejoras

## Cuanto dura en pantalla el aviso de un objeto recogido.
const DURACION_AVISO: float = 2.6

## El desvanecido del aviso que esta en pantalla. Se cancela al llegar otro:
## si no, el del primer objeto seguia corriendo y escondia el aviso del
## segundo a medias. Con los enemigos soltando ventajas, coger dos cosas en
## menos de tres segundos pasa.
var _desvanecer: Tween = null


func actualizar_piso(numero_piso: int, total: int, nombre_capa: String) -> void:
	_etiqueta_piso.text = "PISO %d / %d" % [numero_piso, total]
	_etiqueta_capa.text = nombre_capa.to_upper()


## Enseña el mapa del piso recien construido.
func mostrar_mapa(piso: Piso) -> void:
	_minimapa.mostrar(piso)


func actualizar_vida(vida_actual: int, vida_maxima: int) -> void:
	_corazones.actualizar(vida_actual, vida_maxima)


## Dice si queda el ataque especial en este piso (es uno por piso): con su
## nombre y el color del mago si queda, apagado si ya se ha usado. Sin esto no
## se sabria si pulsar el boton va a hacer algo.
func actualizar_especial(disponible: bool, nombre: String, color: Color) -> void:
	if disponible:
		_especial.text = "ESPECIAL  ·  %s" % nombre.to_upper()
		_especial.modulate = color
	else:
		_especial.text = "ESPECIAL  ·  USADO EN ESTE PISO"
		_especial.modulate = Color(1.0, 1.0, 1.0, 0.4)


## Vacia la fila de ventajas. Principal la llama al empezar otra partida.
func vaciar_mejoras() -> void:
	_mejoras.vaciar()


## Anuncia un objeto recien recogido. Sin esto, el jugador ve desaparecer algo
## del suelo y no se entera de que le ha tocado. Y lo deja en la fila de
## ventajas, que no se va.
func anunciar_mejora(mejora: ObjetoMejora) -> void:
	_mejoras.anadir(mejora)
	_aviso.text = "%s  ·  %s" % [mejora.nombre, mejora.descripcion]
	_aviso.modulate = mejora.color
	_aviso.show()

	if _desvanecer != null and _desvanecer.is_valid():
		_desvanecer.kill()
	_desvanecer = create_tween()
	_desvanecer.tween_interval(DURACION_AVISO)
	_desvanecer.tween_property(_aviso, "modulate:a", 0.0, 0.6)
	_desvanecer.tween_callback(_aviso.hide)
