## El lanzador de Vacío (Matías, 2026-11-19: «que instale algo parecido a lo que
## tiene el Minecraft, que puedes instalar la versión que quieras y jugarla, así
## también ahorramos problemas de actualizaciones»).
##
## A la izquierda, todas las versiones publicadas en GitHub (las mismas releases que
## lee el aviso del juego), la última arriba y elegida. A la derecha, lo que trae la
## elegida y «Jugar»: si no está bajada, la baja; luego la abre y se cierra.
##
## CADA VERSION EN SU CARPETA (carpeta_versiones()/0.N/), y nunca se cambia un
## ejecutable abierto: se acabaron el «no se ha podido cambiar el juego por el nuevo»
## del antivirus y de OneDrive. Lo guardado (monedas, skins, ajustes, partidas) es el
## mismo para todas, como en Minecraft: el juego lo guarda en su carpeta de datos, que
## no depende de dónde esté el ejecutable.
##
## EL JUEGO, ABIERTO DESDE AQUI, NO SE ACTUALIZA SOLO: va con -- --desde-lanzador
## (Actualizacion lo mira). Las versiones de antes de eso no lo saben, pero en Windows
## la que se abre ya está en su carpeta: actualizarse ahí solo cambiaría esa copia.
##
## En Windows y en Linux (Matías). Sin internet, solo salen las que ya están bajadas.
extends Control

const URL_VERSIONES := "https://api.github.com/repos/MatiasRodrigo0502/Vacio/releases?per_page=100"
const PAGINA := "https://github.com/MatiasRodrigo0502/Vacio/releases"
## El archivo de cada version para este sistema y el ejecutable que queda en su carpeta.
const ARCHIVO_WINDOWS := "Vacio.exe"
const ARCHIVO_LINUX := "Vacio-linux.tar.gz"
const EJECUTABLE_LINUX := "Vacio.x86_64"
const ARGUMENTO := "--desde-lanzador"
## Lo que se lee de golpe al bajar: con lo de serie (64 KB) va bastante mas lento.
const TROZO_DESCARGA: int = 1 << 20
## Los colores de la portada, como el panel de controles del juego (PaletaPortada).
const FONDO_PANEL := Color(0.075, 0.024, 0.106, 0.82)
const TITULO := Color("e9b8f2")
const TEXTO := Color("ece0f2")
const FLOJO := Color("9d84ab")
const CAJA := Color("2c0d3b")
const CAJA_ENCIMA := Color("420e54")
const CAJA_PULSADA := Color("5b1970")
const BORDE := Color("582470")
const BORDE_ENCIMA := Color("8b3aa1")

## Las versiones, de la mas nueva a la mas vieja: "version" ("0.78"), "fecha",
## "cambios" (PackedStringArray), "url" y "tamano" del archivo de este sistema
## ("" si no lo trae).
var _versiones: Array[Dictionary] = []
var _elegida: int = -1
var _bajador: HTTPRequest
var _buscador: HTTPRequest
var _bajando: Dictionary = {}

var _lista: ItemList
var _titulo_version: Label
var _detalle: Label
var _cambios: Label
var _boton_jugar: Button
var _boton_borrar: Button
var _barra: ProgressBar
var _estado: Label


func _ready() -> void:
	_montar()
	_buscador = HTTPRequest.new()
	_buscador.timeout = 15.0
	_buscador.request_completed.connect(_al_buscar)
	add_child(_buscador)
	_bajador = HTTPRequest.new()
	_bajador.use_threads = true
	_bajador.download_chunk_size = TROZO_DESCARGA
	_bajador.request_completed.connect(_al_bajar)
	add_child(_bajador)
	DirAccess.make_dir_recursive_absolute(carpeta_versiones())
	# Primero las que ya hay: sin internet, son las unicas.
	_poner_versiones(_instaladas_sin_internet())
	_estado.text = "Buscando versiones..."
	if _buscador.request(URL_VERSIONES, ["Accept: application/vnd.github+json", "User-Agent: Vacio-lanzador"]) != OK:
		_estado.text = "Sin conexión: solo puedes jugar las versiones que ya tienes."


func _process(_delta: float) -> void:
	if _bajando.is_empty():
		return
	var total := maxi(_bajador.get_body_size(), int(_bajando.tamano))
	var bajado := _bajador.get_downloaded_bytes()
	_barra.value = 100.0 * bajado / total if total > 0 else 0.0
	_estado.text = "Bajando la %s: %d de %d MB" % [_bajando.version, bajado >> 20, total >> 20]


# --- Donde va cada cosa ------------------------------------------------------------

## Donde se guardan las versiones bajadas: en Windows, %LOCALAPPDATA%\Vacio\versiones
## (lo de cada usuario, fuera de OneDrive); en Linux, ~/.local/share/vacio/versiones.
static func carpeta_versiones() -> String:
	if OS.get_name() == "Windows":
		var local := OS.get_environment("LOCALAPPDATA")
		if local == "":
			local = OS.get_environment("USERPROFILE").path_join("AppData/Local")
		return local.replace("\\", "/").path_join("Vacio/versiones")
	var datos := OS.get_environment("XDG_DATA_HOME")
	if datos == "":
		datos = OS.get_environment("HOME").path_join(".local/share")
	return datos.path_join("vacio/versiones")


static func ejecutable(version: String) -> String:
	var nombre := ARCHIVO_WINDOWS if OS.get_name() == "Windows" else EJECUTABLE_LINUX
	return carpeta_versiones().path_join(version).path_join(nombre)


static func instalada(version: String) -> bool:
	return FileAccess.file_exists(ejecutable(version))


static func archivo_de_aqui() -> String:
	return ARCHIVO_WINDOWS if OS.get_name() == "Windows" else ARCHIVO_LINUX


# --- Las versiones -----------------------------------------------------------------

func _instaladas_sin_internet() -> Array[Dictionary]:
	var lista: Array[Dictionary] = []
	for carpeta in DirAccess.get_directories_at(carpeta_versiones()):
		if instalada(carpeta):
			lista.append({"version": carpeta, "fecha": "", "cambios": PackedStringArray(), "url": "", "tamano": 0})
	lista.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return mas_nueva(a.version, b.version))
	return lista


func _al_buscar(resultado: int, codigo: int, _cabeceras: PackedStringArray, cuerpo: PackedByteArray) -> void:
	if resultado != HTTPRequest.RESULT_SUCCESS or codigo != 200:
		_estado.text = "Sin conexión con GitHub: solo puedes jugar las versiones que ya tienes."
		return
	var datos: Variant = JSON.parse_string(cuerpo.get_string_from_utf8())
	if not datos is Array:
		return
	var lista := leer_versiones(datos, archivo_de_aqui())
	# Las bajadas que ya no estan en la lista (alguna de prueba) tambien salen.
	var vistas := {}
	for una in lista:
		vistas[una.version] = true
	for una in _instaladas_sin_internet():
		if not vistas.has(una.version):
			lista.append(una)
	lista.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return mas_nueva(a.version, b.version))
	_poner_versiones(lista)
	_estado.text = ""


## De la lista de releases de GitHub, las versiones con numero (etiqueta v0.N), con
## su fecha, lo que cambia y el archivo de este sistema. Sin tocar nada: se prueba
## con una lista hecha a mano.
static func leer_versiones(releases: Array, archivo: String) -> Array[Dictionary]:
	var lista: Array[Dictionary] = []
	for publicada: Variant in releases:
		if not publicada is Dictionary or publicada.get("draft", false) or publicada.get("prerelease", false):
			continue
		var etiqueta := String(publicada.get("tag_name", ""))
		if not etiqueta.begins_with("v") or numeros(etiqueta.trim_prefix("v")).is_empty():
			continue
		var una := {"version": etiqueta.trim_prefix("v"), "fecha": String(publicada.get("published_at", "")).left(10),
			"cambios": cambios(String(publicada.get("body", ""))), "url": "", "tamano": 0}
		for subido: Variant in publicada.get("assets", []):
			if subido is Dictionary and subido.get("name", "") == archivo:
				una.url = String(subido.get("browser_download_url", ""))
				una.tamano = int(subido.get("size", 0))
		lista.append(una)
	lista.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return mas_nueva(a.version, b.version))
	return lista


## Lo que cambia en una version: la lista de debajo de "### " en sus notas, como la
## lee el aviso del juego (Actualizacion._cambios).
static func cambios(notas: String) -> PackedStringArray:
	var lista := PackedStringArray()
	var dentro := false
	for linea in notas.split("\n"):
		linea = linea.strip_edges()
		if linea.begins_with("### "):
			dentro = true
		elif dentro and linea.begins_with("- "):
			lista.append(linea.substr(2).strip_edges())
	return lista


static func numeros(texto: String) -> PackedInt32Array:
	var partes := PackedInt32Array()
	for parte in texto.split("."):
		if not parte.is_valid_int():
			return PackedInt32Array()
		partes.append(parte.to_int())
	return partes


static func mas_nueva(a: String, b: String) -> bool:
	var na := numeros(a)
	var nb := numeros(b)
	for i in mini(na.size(), nb.size()):
		if na[i] != nb[i]:
			return na[i] > nb[i]
	return na.size() > nb.size()


func _poner_versiones(lista: Array[Dictionary]) -> void:
	var antes: String = _versiones[_elegida].version if _elegida >= 0 and _elegida < _versiones.size() else ""
	_versiones = lista
	_lista.clear()
	for i in _versiones.size():
		var una := _versiones[i]
		var texto := "Versión %s" % una.version
		if i == 0 and una.fecha != "":
			texto += "   · la última"
		if instalada(una.version):
			texto += "   ✓"
		_lista.add_item(texto)
		if not instalada(una.version) and una.url == "":
			_lista.set_item_custom_fg_color(i, FLOJO)
	var elegir := 0
	for i in _versiones.size():
		if _versiones[i].version == antes:
			elegir = i
	if not _versiones.is_empty():
		_lista.select(elegir)
		_elegir(elegir)
	else:
		_elegir(-1)


func _elegir(indice: int) -> void:
	_elegida = indice
	if indice < 0:
		_titulo_version.text = "Ninguna versión"
		_detalle.text = "Sin conexión y sin ninguna versión bajada todavía."
		_cambios.text = ""
		_boton_jugar.disabled = true
		_boton_borrar.visible = false
		return
	var una := _versiones[indice]
	var esta := instalada(una.version)
	_titulo_version.text = "Versión %s" % una.version
	var partes := PackedStringArray()
	if una.fecha != "":
		var f := String(una.fecha).split("-")
		partes.append("Publicada el %s/%s/%s" % [f[2], f[1], f[0]])
	if esta:
		partes.append("ya la tienes")
	elif una.url != "":
		partes.append("se baja al jugar (%d MB)" % (int(una.tamano) >> 20))
	else:
		partes.append("no hay versión para este sistema")
	_detalle.text = " · ".join(partes)
	var lineas := PackedStringArray()
	for cambio in una.cambios:
		lineas.append("•  " + cambio)
	_cambios.text = "\n".join(lineas) if not lineas.is_empty() else ""
	_boton_jugar.disabled = not esta and una.url == "" or not _bajando.is_empty()
	_boton_jugar.text = "Jugar" if esta else "Bajar y jugar"
	_boton_borrar.visible = esta and _bajando.is_empty()


# --- Jugar, bajar y borrar ----------------------------------------------------------

func _jugar() -> void:
	if _elegida < 0:
		return
	var una := _versiones[_elegida]
	if instalada(una.version):
		_abrir(una.version)
	else:
		_bajar(una)


func _abrir(version: String) -> void:
	var ruta := ejecutable(version)
	var pid := OS.create_process(ruta, ["--", ARGUMENTO])
	if pid <= 0:
		_estado.text = "No se ha podido abrir la %s. Bórrala y vuelve a bajarla." % version
		return
	_estado.text = "Abriendo la %s..." % version
	# Un momento, para que se vea que algo pasa; luego el lanzador se va.
	await get_tree().create_timer(1.0).timeout
	get_tree().quit()


func _bajar(una: Dictionary) -> void:
	var carpeta := carpeta_versiones().path_join(una.version)
	DirAccess.make_dir_recursive_absolute(carpeta)
	_bajando = una.duplicate()
	_bajando.descarga = carpeta.path_join(archivo_de_aqui() + ".descarga")
	_bajador.download_file = _bajando.descarga
	if _bajador.request(String(una.url), ["User-Agent: Vacio-lanzador"]) != OK:
		_fallar("No se ha podido empezar la descarga.")
		return
	_barra.visible = true
	_elegir(_elegida)


func _al_bajar(resultado: int, codigo: int, _cabeceras: PackedStringArray, _cuerpo: PackedByteArray) -> void:
	var descarga := String(_bajando.descarga)
	if resultado != HTTPRequest.RESULT_SUCCESS or codigo != 200:
		_fallar("Se ha cortado la descarga. Comprueba la conexión y vuelve a intentarlo.")
		return
	# Que haya llegado entera y sea lo que tiene que ser (un programa de Windows empieza
	# por "MZ"; un .gz, por 1F 8B), no una pagina de error.
	var archivo := FileAccess.open(descarga, FileAccess.READ)
	var comienzo := "MZ".to_ascii_buffer() if OS.get_name() == "Windows" else PackedByteArray([0x1f, 0x8b])
	var bien := archivo != null and archivo.get_length() == int(_bajando.tamano) and archivo.get_buffer(2) == comienzo
	if archivo != null:
		archivo.close()
	if not bien:
		_fallar("La descarga ha llegado incompleta. Vuelve a intentarlo.")
		return
	var version := String(_bajando.version)
	var error := OK
	if OS.get_name() == "Windows":
		error = DirAccess.rename_absolute(descarga, ejecutable(version))
	else:
		_estado.text = "Sacándola de lo bajado..."
		var hilo := Thread.new()
		hilo.start(Desempaquetar.sacar_de_tar_gz.bind(descarga, EJECUTABLE_LINUX, ejecutable(version)))
		while hilo.is_alive():
			await get_tree().process_frame
		error = hilo.wait_to_finish()
		DirAccess.remove_absolute(descarga)
	if error != OK:
		_fallar("No se ha podido instalar la %s (error %d)." % [version, error])
		return
	_bajando = {}
	_barra.visible = false
	_poner_versiones(_versiones)
	_abrir(version)


func _fallar(motivo: String) -> void:
	if not _bajando.is_empty() and FileAccess.file_exists(String(_bajando.descarga)):
		DirAccess.remove_absolute(String(_bajando.descarga))
	_bajando = {}
	_barra.visible = false
	_estado.text = motivo
	_elegir(_elegida)


## Borra la version elegida de este ordenador (solo su carpeta: lo guardado no esta
## ahi). Se puede volver a bajar.
func _borrar() -> void:
	if _elegida < 0:
		return
	var version := String(_versiones[_elegida].version)
	var carpeta := carpeta_versiones().path_join(version)
	for archivo in DirAccess.get_files_at(carpeta):
		DirAccess.remove_absolute(carpeta.path_join(archivo))
	DirAccess.remove_absolute(carpeta)
	_estado.text = "Versión %s borrada de este ordenador." % version
	_poner_versiones(_versiones)


# --- Lo que se ve --------------------------------------------------------------------

func _montar() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = _tema()
	var fondo := TextureRect.new()
	fondo.texture = preload("res://fondo.jpg")
	fondo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fondo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)
	var velo := ColorRect.new()
	velo.color = Color(0.0, 0.0, 0.0, 0.35)
	velo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(velo)

	var margen := MarginContainer.new()
	margen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for lado in ["left", "right", "top", "bottom"]:
		margen.add_theme_constant_override("margin_" + lado, 24)
	add_child(margen)
	var columnas := HBoxContainer.new()
	columnas.add_theme_constant_override("separation", 18)
	margen.add_child(columnas)

	# Izquierda: las versiones.
	var izquierda := _panel(columnas, 300.0)
	izquierda.add_child(_etiqueta("Versiones", 22, TITULO))
	_lista = ItemList.new()
	_lista.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_lista.add_theme_font_size_override("font_size", 17)
	_lista.item_selected.connect(_elegir)
	_lista.item_activated.connect(func(_i: int) -> void: _jugar())
	izquierda.add_child(_lista)
	var web := Button.new()
	web.text = "Ver las versiones en la web"
	web.pressed.connect(func() -> void: OS.shell_open(PAGINA))
	izquierda.add_child(web)

	# Derecha: la elegida.
	var derecha := _panel(columnas, 0.0)
	derecha.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_titulo_version = _etiqueta("", 32, Color.WHITE)
	derecha.add_child(_titulo_version)
	_detalle = _etiqueta("", 16, FLOJO)
	derecha.add_child(_detalle)
	derecha.add_child(_etiqueta("Lo que trae", 18, TITULO))
	var desplazar := ScrollContainer.new()
	desplazar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desplazar.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	derecha.add_child(desplazar)
	_cambios = _etiqueta("", 15, TEXTO)
	_cambios.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_cambios.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desplazar.add_child(_cambios)
	_barra = ProgressBar.new()
	_barra.custom_minimum_size = Vector2(0.0, 18.0)
	_barra.show_percentage = false
	_barra.visible = false
	derecha.add_child(_barra)
	_estado = _etiqueta("", 15, TEXTO)
	_estado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	derecha.add_child(_estado)
	var botones := HBoxContainer.new()
	botones.add_theme_constant_override("separation", 12)
	derecha.add_child(botones)
	_boton_jugar = Button.new()
	_boton_jugar.text = "Jugar"
	_boton_jugar.custom_minimum_size = Vector2(240.0, 54.0)
	_boton_jugar.add_theme_font_size_override("font_size", 24)
	_boton_jugar.pressed.connect(_jugar)
	botones.add_child(_boton_jugar)
	_boton_borrar = Button.new()
	_boton_borrar.text = "Borrar esta versión"
	_boton_borrar.custom_minimum_size = Vector2(0.0, 54.0)
	_boton_borrar.pressed.connect(_borrar)
	botones.add_child(_boton_borrar)


func _panel(padre: Control, ancho: float) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(ancho, 0.0)
	var caja := StyleBoxFlat.new()
	caja.bg_color = FONDO_PANEL
	caja.border_color = BORDE
	caja.set_border_width_all(1)
	caja.set_corner_radius_all(6)
	caja.set_content_margin_all(16.0)
	panel.add_theme_stylebox_override("panel", caja)
	padre.add_child(panel)
	var dentro := VBoxContainer.new()
	dentro.add_theme_constant_override("separation", 10)
	panel.add_child(dentro)
	return dentro


func _etiqueta(texto: String, tamano: int, color: Color) -> Label:
	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.add_theme_font_size_override("font_size", tamano)
	etiqueta.add_theme_color_override("font_color", color)
	return etiqueta


## Los botones y la lista con los morados de la portada.
func _tema() -> Theme:
	var tema := Theme.new()
	tema.set_stylebox("normal", "Button", _caja(CAJA, BORDE))
	tema.set_stylebox("hover", "Button", _caja(CAJA_ENCIMA, BORDE_ENCIMA))
	tema.set_stylebox("pressed", "Button", _caja(CAJA_PULSADA, TITULO))
	tema.set_stylebox("disabled", "Button", _caja(Color(CAJA, 0.6), Color(BORDE, 0.5)))
	tema.set_stylebox("focus", "Button", _caja(Color(0, 0, 0, 0), TITULO))
	tema.set_color("font_color", "Button", TEXTO)
	tema.set_color("font_disabled_color", "Button", FLOJO)
	tema.set_stylebox("panel", "ItemList", _caja(Color(0, 0, 0, 0.25), BORDE))
	tema.set_stylebox("selected", "ItemList", _caja(CAJA_PULSADA, BORDE_ENCIMA))
	tema.set_stylebox("selected_focus", "ItemList", _caja(CAJA_PULSADA, TITULO))
	tema.set_stylebox("hovered", "ItemList", _caja(CAJA_ENCIMA, CAJA_ENCIMA))
	tema.set_color("font_color", "ItemList", TEXTO)
	tema.set_color("font_selected_color", "ItemList", Color.WHITE)
	tema.set_stylebox("background", "ProgressBar", _caja(CAJA, BORDE))
	tema.set_stylebox("fill", "ProgressBar", _caja(BORDE_ENCIMA, BORDE_ENCIMA))
	return tema


func _caja(fondo: Color, borde: Color) -> StyleBoxFlat:
	var caja := StyleBoxFlat.new()
	caja.bg_color = fondo
	caja.border_color = borde
	caja.set_border_width_all(1)
	caja.set_corner_radius_all(4)
	caja.set_content_margin_all(8.0)
	return caja
