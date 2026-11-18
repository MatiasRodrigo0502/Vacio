## Como estan los tres joysticks de la pantalla tactil (Matias, 2026-11-18): el
## izquierdo (moverse), el derecho (apuntar y disparar) y el del ataque especial
## (la ulti). De cada uno, donde esta, lo grande que es y dos interruptores:
##
## - oculto: no se ve hasta que se pone el dedo, y sale donde se pone (como eran
##   antes todos). Si no, se ve siempre en su sitio, translucido hasta que se toca
##   la pantalla.
## - estatico: no se mueve aunque el dedo salga del circulo grande. Si no, lo sigue:
##   el circulo se arrastra detras del dedo. En los dos casos el centro es donde se
##   pone el dedo al empezar.
##
## EL SITIO VA EN PARTES DE LA PANTALLA (0 a 1), no en pixeles: asi sirve igual en
## horizontal y en vertical (Vista) y en pantallas de cualquier tamano.
##
## Todo estatico, como Controles: lo leen los mandos de la partida
## (ControlesTactiles) y lo cambia el editor de controles (EditorMandos), que lo
## guarda en ARCHIVO con cada cambio. Se lee la primera vez que hace falta.
class_name AjustesMandos
extends RefCounted

const IZQUIERDO := &"izquierdo"
const DERECHO := &"derecho"
const ULTI := &"ulti"
const MANDOS: Array[StringName] = [IZQUIERDO, DERECHO, ULTI]
## Lo que se ensena de cada uno.
const NOMBRES := {IZQUIERDO: "Moverse", DERECHO: "Apuntar y disparar", ULTI: "Ataque especial"}
## Lo mas pequeno y lo mas grande que se pueden hacer, en veces su tamano normal.
const TAMANO_MINIMO: float = 0.6
const TAMANO_MAXIMO: float = 1.8

## Los de fabrica. En las esquinas de abajo (Matias: «por defecto están en las
## esquinas inferiores»): el de moverse a la izquierda y el de apuntar a la derecha,
## con la ulti a su lado, hacia el centro. Ocultos ninguno; estaticos el derecho y
## la ulti, para apuntar sin que se escape el circulo.
const DE_FABRICA := {
	IZQUIERDO: {"sitio": Vector2(0.13, 0.78), "tamano": 1.0, "oculto": false, "estatico": false},
	DERECHO: {"sitio": Vector2(0.87, 0.78), "tamano": 1.0, "oculto": false, "estatico": true},
	ULTI: {"sitio": Vector2(0.70, 0.84), "tamano": 1.0, "oculto": false, "estatico": true},
}

## Donde se guardan: aparte de los ajustes de siempre (ajustes.cfg), que son de
## Controles y del tutorial.
const ARCHIVO := "user://mandos.cfg"

static var _mandos: Dictionary = {}
static var _archivo: String = ARCHIVO


## Lo de un mando: "sitio", "tamano", "oculto" o "estatico".
static func dato(mando: StringName, clave: String) -> Variant:
	if _mandos.is_empty():
		_cargar()
	return _mandos[mando][clave]


static func poner(mando: StringName, clave: String, valor: Variant) -> void:
	if _mandos.is_empty():
		_cargar()
	if clave == "tamano":
		valor = clampf(valor, TAMANO_MINIMO, TAMANO_MAXIMO)
	elif clave == "sitio":
		valor = (valor as Vector2).clamp(Vector2.ZERO, Vector2.ONE)
	_mandos[mando][clave] = valor


## Donde esta, en pixeles de una pantalla de ese tamano.
static func sitio_en(mando: StringName, pantalla: Vector2) -> Vector2:
	return pantalla * (dato(mando, "sitio") as Vector2)


static func guardar() -> void:
	var archivo := ConfigFile.new()
	for mando in MANDOS:
		for clave: String in _mandos[mando]:
			archivo.set_value(mando, clave, _mandos[mando][clave])
	archivo.save(_archivo)


## Los de fabrica, y guardados.
static func restablecer() -> void:
	_mandos = DE_FABRICA.duplicate(true)
	guardar()


## Para las pruebas: lee y guarda en otro archivo, sin tocar el de quien las lanza.
static func usar_archivo(ruta: String) -> void:
	_archivo = ruta
	_mandos.clear()


## Lo guardado encima de lo de fabrica: lo que falte (un mando o una clave nuevos)
## se queda como viene.
static func _cargar() -> void:
	_mandos = DE_FABRICA.duplicate(true)
	var archivo := ConfigFile.new()
	if archivo.load(_archivo) != OK:
		return
	for mando in MANDOS:
		for clave: String in _mandos[mando]:
			var guardado: Variant = archivo.get_value(mando, clave, null)
			if guardado != null and typeof(guardado) == typeof(_mandos[mando][clave]):
				_mandos[mando][clave] = guardado
