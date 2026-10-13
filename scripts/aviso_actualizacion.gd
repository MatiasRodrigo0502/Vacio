## El aviso de la portada de que hay una version mas nueva del juego, con el
## boton para bajarla. Lo de verdad (buscar, bajar, cambiar el .exe) lo hace el
## autoload Actualizacion; esto solo lo ensena y le pasa los clics.
##
## POR QUE ABAJO A LA DERECHA Y NO UNA VENTANA EN MEDIO: es un aviso, no algo
## que haya que contestar para poder jugar. Va encima del numero de version,
## que es de lo que habla, y no tapa el titulo, los magos ni los botones.
extends PanelContainer

## Cambios que se ensenan como mucho. Si hay mas (se han saltado varias
## versiones), se dice cuantos quedan.
const MAX_CAMBIOS: int = 5
const BYTES_POR_MB: float = 1024.0 * 1024.0

@onready var _titulo: Label = $Caja/Titulo
@onready var _texto: Label = $Caja/Texto
@onready var _cambios: Label = $Caja/Cambios
@onready var _barra: ProgressBar = $Caja/Barra
@onready var _principal: Button = $Caja/Botones/Principal
@onready var _secundario: Button = $Caja/Botones/Secundario

## Para que entre con su animacion y su sonido solo la primera vez que sale,
## no cada vez que cambia de estado.
var _ya_salio: bool = false


func _ready() -> void:
	_principal.pressed.connect(_al_principal)
	_secundario.pressed.connect(_al_secundario)
	Actualizacion.cambiado.connect(_mostrar)
	_mostrar()


func _process(_delta: float) -> void:
	var total := Actualizacion.total()
	var bajado := Actualizacion.bajado()
	_barra.value = 100.0 * bajado / total if total > 0 else 0.0
	# El porcentaje va en el texto y no encima de la barra: ahi, sobre el
	# relleno naranja, no se leia.
	_texto.text = "%d de %d MB  (%d %%)" % [roundi(bajado / BYTES_POR_MB),
		roundi(total / BYTES_POR_MB), roundi(_barra.value)]


func _mostrar() -> void:
	var estado: int = Actualizacion.estado
	var hay_algo := estado in [Actualizacion.Estado.HAY_NUEVA, Actualizacion.Estado.DESCARGANDO,
		Actualizacion.Estado.LISTA, Actualizacion.Estado.FALLO]
	visible = hay_algo and not Actualizacion.aviso_cerrado
	set_process(visible and estado == Actualizacion.Estado.DESCARGANDO)
	if not visible:
		return
	var version := String(Actualizacion.nueva.get("version", ""))
	_cambios.visible = false
	_barra.visible = false
	_secundario.visible = true
	match estado:
		Actualizacion.Estado.HAY_NUEVA:
			_titulo.text = "¡Hay una versión nueva!"
			_texto.text = "Ya está la %s (tú tienes la %s)." % [version, Actualizacion.version_local]
			_poner_cambios()
			_principal.text = "Actualizar ahora" if Actualizacion.se_puede_instalar() else "Bajarla de la web"
			_secundario.text = "Ahora no"
		Actualizacion.Estado.DESCARGANDO:
			_titulo.text = "Bajando la %s..." % version
			_barra.visible = true
			_principal.text = "Cancelar"
			_secundario.visible = false
			_process(0.0)
		Actualizacion.Estado.LISTA:
			_titulo.text = "¡Versión %s lista!" % version
			_texto.text = "Ya está instalada: la próxima vez que abras el juego será esta. También puedes abrirla ya."
			_principal.text = "Abrirla ahora"
			_secundario.text = "Luego"
		Actualizacion.Estado.FALLO:
			_titulo.text = "No se ha podido actualizar"
			_texto.text = Actualizacion.motivo
			_principal.text = "Reintentar"
			_secundario.text = "Bajarla de la web"
	if not _ya_salio:
		_ya_salio = true
		_entrar()


## La lista de lo que cambia, una linea por cosa, con un punto delante.
func _poner_cambios() -> void:
	var cambios: PackedStringArray = Actualizacion.nueva.get("cambios", PackedStringArray())
	if cambios.is_empty():
		return
	var lineas := PackedStringArray()
	for i in mini(cambios.size(), MAX_CAMBIOS):
		lineas.append("•  " + cambios[i])
	if cambios.size() > MAX_CAMBIOS:
		lineas.append("...y %d cosas más" % (cambios.size() - MAX_CAMBIOS))
	_cambios.text = "\n".join(lineas)
	_cambios.visible = true


## Aparece fundiendose y con un sonido, para que se vea que acaba de llegar
## (sale un momento despues de abrir el juego, cuando contesta GitHub). Sin
## moverlo: su sitio lo pone el contenedor, que lo recoloca al cambiar el
## texto.
func _entrar() -> void:
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.35)
	Sonido.tocar(&"objeto")


func _al_principal() -> void:
	match Actualizacion.estado:
		Actualizacion.Estado.HAY_NUEVA, Actualizacion.Estado.FALLO:
			Actualizacion.descargar()
		Actualizacion.Estado.DESCARGANDO:
			Actualizacion.cancelar()
		Actualizacion.Estado.LISTA:
			Actualizacion.reiniciar()


func _al_secundario() -> void:
	if Actualizacion.estado == Actualizacion.Estado.FALLO:
		Actualizacion.abrir_pagina()
	else:
		Actualizacion.cerrar_aviso()
