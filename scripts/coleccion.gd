## Autoload Coleccion: las monedas, los diamantes, lo que se ha sacado del gacha
## y lo que se lleva puesto. Pedido por Matias el 2026-11-04.
##
## Dura entre partidas (user://coleccion.cfg), al contrario que los objetos, que
## se pierden al empezar otra: es lo que se gana jugando y se gasta en el menu.
##
## Lo ganan los enemigos al morir (TipoEnemigo.monedas y diamantes); los
## diamantes solo los dan los jefes. Se reparten igual en cooperativo: cada
## ordenador cuenta lo suyo al morir cada enemigo.
##
## El catalogo se lee de las carpetas, como los magos y los objetos: una skin o
## un arma nuevas son un .tres mas.
##
## OJO: sin class_name a proposito, como los demas autoloads.
extends Node

## Ha cambiado lo que se tiene, lo que se lleva o el dinero.
signal cambiado

const ARCHIVO := "user://coleccion.cfg"
const CARPETA_SKINS := "res://resources/skins"
const CARPETA_ARMAS := "res://resources/armas"
const RUTA_GACHA_SKINS := "res://resources/gacha/skins.tres"
const RUTA_GACHA_ARMAS := "res://resources/gacha/armas.tres"
## Se guarda un momento despues de ganar algo, no por cada enemigo.
const ESPERA_GUARDAR: float = 1.0

var monedas: int = 0
var diamantes: int = 0
var skins: Array[SkinMago] = []
var armas: Array[ArmaMago] = []
var gacha_skins: TiradaGacha
var gacha_armas: TiradaGacha

## Donde se guarda. Las pruebas lo cambian (usar_archivo) para no tocar la
## coleccion de quien las lanza.
var _archivo: String = ARCHIVO
## Lo que se tiene: el id (el nombre del archivo) de cada skin y cada arma.
var _tengo: Dictionary = {}
## Nombre del mago -> id de la skin puesta. Sin entrada, la de siempre.
var _skin_puesta: Dictionary = {}
var _arma_puesta: String = ""
## Gacha (su _clave) -> tiradas seguidas sin sacar su tier mas alto. Se guarda: la
## garantia no se pierde por cerrar el juego.
var _sin_maximo: Dictionary = {}
var _guardado: Timer


func _ready() -> void:
	# Tambien en la pausa: se puede tirar del menu sin haber jugado, y lo ganado
	# justo antes de pausar se tiene que guardar.
	process_mode = Node.PROCESS_MODE_ALWAYS
	gacha_skins = load(RUTA_GACHA_SKINS)
	gacha_armas = load(RUTA_GACHA_ARMAS)
	for ruta in _listar(CARPETA_SKINS):
		skins.append(load(ruta))
	for ruta in _listar(CARPETA_ARMAS):
		armas.append(load(ruta))
	_guardado = Timer.new()
	_guardado.one_shot = true
	_guardado.wait_time = ESPERA_GUARDAR
	_guardado.timeout.connect(guardar)
	add_child(_guardado)
	_cargar()


## Lo que da un enemigo al morir.
func ganar(cuantas_monedas: int, cuantos_diamantes: int = 0) -> void:
	if cuantas_monedas <= 0 and cuantos_diamantes <= 0:
		return
	monedas += maxi(cuantas_monedas, 0)
	diamantes += maxi(cuantos_diamantes, 0)
	cambiado.emit()
	if _guardado.is_stopped():
		_guardado.start()


func dinero_de(tirada: TiradaGacha) -> int:
	return diamantes if tirada.usa_diamantes else monedas


func puede_tirar(tirada: TiradaGacha, veces: int = 1) -> bool:
	return dinero_de(tirada) >= tirada.coste_de(veces)


## Una tirada: paga, saca un tier segun sus probabilidades y, de ese tier, una
## cosa al azar. Lo repetido da algo, mas cuanto mas raro (TiradaGacha.devolucion;
## Matias, 2026-11-05: en las skins, 20 la B y mas en cada tier). Devuelve {} si no llega
## el dinero; si no, {"objeto", "tier", "nuevo", "devuelto", "garantizada"}.
func tirar(tirada: TiradaGacha) -> Dictionary:
	if not puede_tirar(tirada):
		return {}
	_pagar(tirada, -tirada.coste)
	var resultado := _sacar(tirada, 0)
	guardar()
	cambiado.emit()
	return resultado


## Varias de golpe (diez, en el gacha), con su precio de lote. Si ninguna de las
## anteriores llega al tier de 'garantia_diez', la ultima sale de ese o mejor.
## Devuelve [] si no llega el dinero.
func tirar_varias(tirada: TiradaGacha, veces: int = 10) -> Array[Dictionary]:
	var resultados: Array[Dictionary] = []
	if not puede_tirar(tirada, veces):
		return resultados
	_pagar(tirada, -tirada.coste_de(veces))
	var mejor := -1
	for i in veces:
		var minimo := 0
		if veces == 10 and i == veces - 1 and mejor < tirada.garantia_diez:
			minimo = tirada.garantia_diez
		var resultado := _sacar(tirada, minimo)
		mejor = maxi(mejor, resultado.tier)
		resultados.append(resultado)
	guardar()
	cambiado.emit()
	return resultados


## Cuantas tiradas faltan, como mucho, para que salga seguro el tier mas alto.
## -1 si ese gacha no tiene garantia.
func tiradas_hasta_garantia(tirada: TiradaGacha) -> int:
	if tirada.garantia_maxima <= 0:
		return -1
	return tirada.garantia_maxima - int(_sin_maximo.get(_clave(tirada), 0))


## Lo que sale en ese gacha: las skins o las armas.
func catalogo_de(tirada: TiradaGacha) -> Array:
	return skins if tirada == gacha_skins else armas


## Cuantas cosas de ese gacha se tienen, de cuantas hay.
func progreso(tirada: TiradaGacha) -> Vector2i:
	var catalogo := catalogo_de(tirada)
	var tenidas := catalogo.filter(func(cosa: Resource) -> bool: return tiene(cosa)).size()
	return Vector2i(tenidas, catalogo.size())


func tiene(objeto: Resource) -> bool:
	return _tengo.has(id_de(objeto))


func id_de(objeto: Resource) -> String:
	return objeto.resource_path.get_file().get_basename()


# --- Skins -----------------------------------------------------------------

## Las skins de un mago, de la mas comun a la mas rara.
func skins_de(nombre_mago: String) -> Array[SkinMago]:
	var lista: Array[SkinMago] = []
	for skin in skins:
		if skin.mago == nombre_mago:
			lista.append(skin)
	lista.sort_custom(func(a: SkinMago, b: SkinMago) -> bool: return a.tier < b.tier)
	return lista


## La que lleva puesta ese mago, o null si lleva la de siempre.
func skin_puesta(nombre_mago: String) -> SkinMago:
	var id: String = _skin_puesta.get(nombre_mago, "")
	for skin in skins:
		if id_de(skin) == id:
			return skin
	return null


## Con null, vuelve a la de siempre. Solo se puede poner lo que se tiene.
func poner_skin(nombre_mago: String, skin: SkinMago) -> void:
	if skin == null:
		_skin_puesta.erase(nombre_mago)
	elif tiene(skin) and skin.mago == nombre_mago:
		_skin_puesta[nombre_mago] = id_de(skin)
	guardar()
	cambiado.emit()


func retrato_de(personaje: PersonajeJugable) -> Texture2D:
	var skin := skin_puesta(personaje.nombre)
	return skin.retrato if skin != null else personaje.retrato


## Las skins por su sitio en el catalogo, para mandarlas por la red: el
## cooperativo exige la misma version, asi que en todos el orden es el mismo.
func indice_de_skin(skin: SkinMago) -> int:
	return skins.find(skin)


func skin_por_indice(indice: int) -> SkinMago:
	return skins[indice] if indice >= 0 and indice < skins.size() else null


# --- Armas -----------------------------------------------------------------

func arma_puesta() -> ArmaMago:
	for arma in armas:
		if id_de(arma) == _arma_puesta:
			return arma
	return null


## Con null, sin arma. Solo se puede poner lo que se tiene.
func poner_arma(arma: ArmaMago) -> void:
	if arma == null:
		_arma_puesta = ""
	elif tiene(arma):
		_arma_puesta = id_de(arma)
	guardar()
	cambiado.emit()


func indice_de_arma(arma: ArmaMago) -> int:
	return armas.find(arma)


func arma_por_indice(indice: int) -> ArmaMago:
	return armas[indice] if indice >= 0 and indice < armas.size() else null


# --- Guardar ---------------------------------------------------------------

## Para las pruebas: lee y guarda en otro archivo, empezando de lo que haya alli.
func usar_archivo(ruta: String) -> void:
	_archivo = ruta
	_cargar()


func guardar() -> void:
	var datos := ConfigFile.new()
	datos.set_value("dinero", "monedas", monedas)
	datos.set_value("dinero", "diamantes", diamantes)
	datos.set_value("tengo", "ids", _tengo.keys())
	datos.set_value("puesto", "skins", _skin_puesta)
	datos.set_value("puesto", "arma", _arma_puesta)
	datos.set_value("gacha", "sin_maximo", _sin_maximo)
	datos.save(_archivo)


func _cargar() -> void:
	var datos := ConfigFile.new()
	datos.load(_archivo)
	monedas = int(datos.get_value("dinero", "monedas", 0))
	diamantes = int(datos.get_value("dinero", "diamantes", 0))
	_tengo.clear()
	for id: Variant in datos.get_value("tengo", "ids", []):
		_tengo[String(id)] = true
	_skin_puesta = datos.get_value("puesto", "skins", {})
	_arma_puesta = datos.get_value("puesto", "arma", "")
	_sin_maximo = datos.get_value("gacha", "sin_maximo", {})
	cambiado.emit()


func _pagar(tirada: TiradaGacha, cuanto: int) -> void:
	if tirada.usa_diamantes:
		diamantes += cuanto
	else:
		monedas += cuanto


## Una tirada ya pagada: el tier (con la garantia y un minimo), la cosa y si es
## nueva. Lo repetido devuelve su parte.
func _sacar(tirada: TiradaGacha, minimo: int) -> Dictionary:
	var clave := _clave(tirada)
	var sin_maximo: int = int(_sin_maximo.get(clave, 0)) + 1
	var maximo := tirada.tier_maximo()
	var garantizada := tirada.garantia_maxima > 0 and sin_maximo >= tirada.garantia_maxima
	var tier := maximo if garantizada else maxi(tirada.sacar_tier(), minimo)
	_sin_maximo[clave] = 0 if tier == maximo else sin_maximo
	var objeto: Resource = _de_tier(catalogo_de(tirada), tier)
	var id := id_de(objeto)
	var nuevo := not _tengo.has(id)
	var devuelto := 0
	if nuevo:
		_tengo[id] = true
	else:
		devuelto = tirada.devolucion[tier]
		_pagar(tirada, devuelto)
	return {"objeto": objeto, "tier": tier, "nuevo": nuevo, "devuelto": devuelto, "garantizada": garantizada}


func _clave(tirada: TiradaGacha) -> String:
	return tirada.resource_path.get_file().get_basename()


## Una cosa al azar de ese tier. Si de ese tier no hay ninguna, la del tier de
## debajo mas cercano: que falte una skin no puede dejar la tirada en nada.
func _de_tier(catalogo: Array, tier: int) -> Resource:
	for t in range(tier, -1, -1):
		var delTier := catalogo.filter(func(cosa: Resource) -> bool: return cosa.tier == t)
		if not delTier.is_empty():
			return delTier[randi() % delTier.size()]
	return catalogo[0]


## En el juego exportado se ve nombre.tres.remap (ver CLAUDE.md).
func _listar(carpeta: String) -> PackedStringArray:
	var rutas := PackedStringArray()
	var dir := DirAccess.open(carpeta)
	if dir == null:
		push_warning("No se ha podido abrir la carpeta %s" % carpeta)
		return rutas
	var nombres := dir.get_files()
	nombres.sort()
	for nombre in nombres:
		var limpio := nombre.trim_suffix(".remap")
		if limpio.get_extension().to_lower() == "tres":
			rutas.append(carpeta.path_join(limpio))
	return rutas
