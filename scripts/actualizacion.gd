## Autoload Actualizacion: mira en GitHub si hay una version del juego mas
## nueva que esta, la baja y la pone en lugar de la que se esta usando: en
## Windows el .exe; desde el 2026-11-03 (Matias) tambien en Linux (el
## ejecutable, que viene en un .tar.gz) y en Mac (la carpeta Vacio.app, que
## viene en un .zip; ver Desempaquetar). Lo ensena la portada
## (AvisoActualizacion).
##
## LINUX Y MAC NO SE HAN PROBADO DE VERDAD: en este ordenador no hay ninguno.
## Se probo aqui lo que se puede (sacar del .tar.gz y del .zip hechos a mano, y
## los cambios de nombre); falta probarlo en uno de cada.
##
## OJO: este script NO declara class_name a proposito, como Sonido: un
## class_name igual al nombre del autoload da "hides an autoload singleton".
##
## POR QUE UN AUTOLOAD Y NO DENTRO DEL MENU: bajar el .exe (unos 115 MB) tarda,
## y si mientras tanto se entra a jugar, el menu se libera. Aqui sigue bajando,
## y al volver a la portada el aviso ensena como va.
##
## COMO SE CAMBIA EL .exe QUE ESTA ABIERTO: Windows no deja sobrescribir ni
## borrar un .exe que se esta ejecutando, pero si renombrarlo (es lo mismo que
## hace herramientas/exportar.sh). Se baja el nuevo al lado, el abierto pasa a
## llamarse Vacio.viejo.<hora>.exe y el nuevo ocupa su nombre. La proxima vez
## que se abre el juego ya es el nuevo, y borra el viejo (_limpiar). En Linux
## y en Mac igual: tambien dejan renombrar lo que esta abierto. En Mac lo que
## se cambia es la carpeta Vacio.app entera.
##
## MAC, SI SE ABRE DESDE DESCARGAS: una app bajada de internet que no se ha
## movido de donde se descomprimio, macOS la abre desde una copia escondida y
## de solo lectura (App Translocation, en una ruta con "/AppTranslocation/").
## Desde ahi no se puede cambiar nada: el aviso dice que se mueva antes a
## Aplicaciones (por_que_no). La version que se pone al actualizar ya no pasa
## por eso: la baja el juego, no el navegador, y macOS no la marca como bajada
## de internet.
##
## CUANDO BUSCA: solo en el juego exportado y con un numero de version
## publicado ("0.17"). Desde Godot no hay version. El .exe de cada ordenador del
## equipo con cambios sin publicar ("0.17 + cambios") lleva cosas que no estan
## en ninguna version: avisarle de que la 0.18 es mas nueva podria ser mentira.
## Sin pantalla tampoco: la prueba de arranque de la release no tiene que salir
## a internet. Sin internet o si GitHub no contesta, no pasa nada: no se avisa.
extends Node

## Cada vez que cambia 'estado' o lo que se sabe de la version nueva.
signal cambiado

enum Estado { NADA, BUSCANDO, HAY_NUEVA, DESCARGANDO, LISTA, FALLO, INSTALANDO }

## Las ultimas versiones publicadas, con lo que cambia en cada una (las notas
## que escribe .github/workflows/publicar.yml). Sin sesion: GitHub deja 60
## consultas por hora desde cada conexion, y se hace una al abrir el juego.
const URL_VERSIONES := "https://api.github.com/repos/MatiasRodrigo0502/Vacio/releases?per_page=30"
## Para bajarla a mano cuando aqui no se puede: en un Mac abierta desde
## Descargas, sin permiso para escribir en la carpeta del juego o si falla la
## descarga.
const PAGINA_DESCARGA := "https://github.com/MatiasRodrigo0502/Vacio/releases/latest"
## El archivo de cada version que es el juego de cada sistema (los que sube
## .github/workflows/publicar.yml), y el ejecutable que va dentro del de Linux.
const ARCHIVO_WINDOWS := "Vacio.exe"
const ARCHIVO_LINUX := "Vacio-linux.tar.gz"
const ARCHIVO_MAC := "Vacio-mac.zip"
const ARCHIVO_ANDROID := "Vacio-android.apk"
const EJECUTABLE_LINUX := "Vacio.x86_64"
## Lo que se espera a la lista de versiones. Sin internet, mejor rendirse
## pronto: es un aviso, no algo que haga falta para jugar.
const ESPERA_BUSCAR: float = 10.0
## Lo que se lee de golpe al bajar el .exe. Con lo que trae Godot de serie
## (64 KB) la descarga va bastante mas lenta.
const TROZO_DESCARGA: int = 1 << 20
## Recien bajado, el antivirus suele abrir el .exe nuevo para mirarlo, y
## mientras tanto no se puede renombrar. Se reintenta un rato.
const INTENTOS_RENOMBRAR: int = 20
const PAUSA_RENOMBRAR: float = 0.25
## Al abrir la version nueva, la vieja tarda un momento en cerrarse y su .exe
## no se puede borrar hasta entonces: se vuelve a intentar pasado esto.
const ESPERA_LIMPIAR: float = 3.0

var estado: Estado = Estado.NADA
## La version del juego que se esta usando. La pone _ready; una prueba puede
## cambiarla para hacer como si fuera otra.
var version_local: String = ""
## Lo que se cambia al actualizar: el .exe en Windows, el ejecutable en Linux
## y la carpeta Vacio.app en Mac. Vacio si no se puede cambiar (desde Godot, o
## en Mac abierta desde una copia de solo lectura): entonces el aviso manda a
## la pagina de descarga.
var ruta_exe: String = ""
## Por que no se puede actualizar desde aqui, si se sabe (Mac abierta desde
## Descargas). Lo dice el aviso.
var por_que_no: String = ""
## La version mas nueva publicada: "version" ("0.18"), "url" y "tamano" de su
## archivo para este sistema (url vacia si no lo trae) y "cambios", lo que
## cambia desde la nuestra,
## lo mas nuevo primero. Vacio si no hay ninguna mas nueva.
var nueva: Dictionary = {}
## Por que ha fallado, para el aviso.
var motivo: String = ""
## Con "Ahora no", el aviso no vuelve a salir hasta que se abra otra vez el
## juego, aunque se vuelva a la portada.
var aviso_cerrado: bool = false

var _buscador: HTTPRequest
var _bajador: HTTPRequest
## Donde se va bajando la version nueva: al lado de la de ahora, para que
## cambiarlas sea renombrar (entre carpetas de discos distintos no se puede).
var _descarga: String = ""


func _ready() -> void:
	# La descarga sigue con el juego en pausa.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_buscador = HTTPRequest.new()
	_buscador.timeout = ESPERA_BUSCAR
	_buscador.request_completed.connect(_al_buscar)
	add_child(_buscador)
	_bajador = HTTPRequest.new()
	# En un hilo aparte: si no, lee un trozo por fotograma y la descarga
	# depende de los fps.
	_bajador.use_threads = true
	_bajador.download_chunk_size = TROZO_DESCARGA
	_bajador.request_completed.connect(_al_bajar)
	add_child(_bajador)

	if OS.has_feature("editor") or DisplayServer.get_name() == "headless":
		return
	version_local = GestorProgreso.version_juego()
	match OS.get_name():
		"Windows", "Linux":
			ruta_exe = OS.get_executable_path()
		"macOS":
			ruta_exe = _app_de_mac(OS.get_executable_path())
		"Android":
			# Un .apk no se puede cambiar desde dentro sin pedir permiso para
			# instalar apps: se baja de la web y lo instala Android.
			por_que_no = "En el móvil se baja desde la web: descarga Vacio-android.apk y ábrelo para instalarla."
	if ruta_exe != "":
		_limpiar()
		get_tree().create_timer(ESPERA_LIMPIAR, true, false, true).timeout.connect(_limpiar)
	if not _numeros(version_local).is_empty():
		buscar()


## Pregunta a GitHub por las versiones publicadas. Contesta con 'cambiado'.
func buscar() -> void:
	if estado in [Estado.BUSCANDO, Estado.DESCARGANDO, Estado.INSTALANDO, Estado.LISTA]:
		return
	_poner(Estado.BUSCANDO)
	# GitHub no contesta a quien no dice quien es (User-Agent).
	var error := _buscador.request(URL_VERSIONES,
		["Accept: application/vnd.github+json", "User-Agent: Vacio"])
	if error != OK:
		_poner(Estado.NADA)


## True si la version nueva se puede bajar e instalar desde aqui. Si no, el
## aviso manda a la pagina de descarga.
func se_puede_instalar() -> bool:
	return ruta_exe != "" and String(nueva.get("url", "")) != ""


## Empieza a bajar el .exe de la version nueva, al lado del de ahora.
func descargar() -> void:
	if estado != Estado.HAY_NUEVA and estado != Estado.FALLO:
		return
	if not se_puede_instalar():
		abrir_pagina()
		return
	_descarga = ruta_exe + ".descarga"
	# Antes de bajar 115 MB, que se pueda escribir ahi.
	var prueba := FileAccess.open(_descarga, FileAccess.WRITE)
	if prueba == null:
		_fallar("No se puede escribir en la carpeta del juego. Bájala desde la web y cámbiala tú.")
		return
	prueba.close()
	_bajador.download_file = _descarga
	var error := _bajador.request(String(nueva.url), ["User-Agent: Vacio"])
	if error != OK:
		_borrar_descarga()
		_fallar("No se ha podido empezar la descarga.")
		return
	_poner(Estado.DESCARGANDO)


## Para la descarga y la tira: se puede volver a empezar.
func cancelar() -> void:
	if estado != Estado.DESCARGANDO:
		return
	_bajador.cancel_request()
	_borrar_descarga()
	_poner(Estado.HAY_NUEVA)


## Bytes bajados y total, para la barra. El total, el que dice la descarga; si
## aun no lo ha dicho, el que dice la lista de versiones.
func bajado() -> int:
	return _bajador.get_downloaded_bytes()


func total() -> int:
	var tamano := _bajador.get_body_size()
	return tamano if tamano > 0 else int(nueva.get("tamano", 0))


## Abre la version nueva y cierra esta. Solo con la nueva ya en su sitio. En
## Mac una .app se abre con "open" (-n: otra aunque esta siga abierta).
func reiniciar() -> void:
	if estado != Estado.LISTA:
		return
	if OS.get_name() == "macOS":
		OS.create_process("open", ["-n", ruta_exe])
	else:
		OS.create_process(ruta_exe, [])
	Sonido.salir()


## La carpeta .app de la que sale el ejecutable de Mac
## (".../Vacio.app/Contents/MacOS/Vacio" -> ".../Vacio.app"). Vacia si no se
## puede cambiar: si macOS la ha abierto desde una copia de solo lectura (ver
## arriba), se apunta el porque para el aviso.
func _app_de_mac(ejecutable: String) -> String:
	var fin := ejecutable.rfind(".app/Contents/MacOS/")
	if fin < 0:
		return ""
	if ejecutable.contains("/AppTranslocation/"):
		por_que_no = "Para actualizar desde aquí, mueve Vacio.app a Aplicaciones (o a otra carpeta) y ábrela desde allí: macOS la está abriendo desde una copia que no se puede cambiar."
		return ""
	return ejecutable.substr(0, fin + 4)


## El archivo de las versiones que es el juego de este sistema.
static func archivo_de_aqui() -> String:
	match OS.get_name():
		"Linux":
			return ARCHIVO_LINUX
		"macOS":
			return ARCHIVO_MAC
		"Android":
			return ARCHIVO_ANDROID
	return ARCHIVO_WINDOWS


func abrir_pagina() -> void:
	OS.shell_open(PAGINA_DESCARGA)


func cerrar_aviso() -> void:
	aviso_cerrado = true
	cambiado.emit()


func _al_buscar(resultado: int, codigo: int, _cabeceras: PackedStringArray, cuerpo: PackedByteArray) -> void:
	# Sin internet, GitHub caido o sin consultas (403): no se avisa y ya.
	if resultado != HTTPRequest.RESULT_SUCCESS or codigo != 200:
		_poner(Estado.NADA)
		return
	var versiones: Variant = JSON.parse_string(cuerpo.get_string_from_utf8())
	nueva = elegir_nueva(versiones, version_local, archivo_de_aqui()) if versiones is Array else {}
	_poner(Estado.HAY_NUEVA if not nueva.is_empty() else Estado.NADA)


## De la lista de versiones de GitHub, la mas nueva que 'local', con lo que ha
## cambiado en todas las que hay entre medias (si se han saltado tres, las
## tres). Vacio si no hay ninguna mas nueva. Sin tocar nada: se puede probar
## con una lista hecha a mano. 'archivo' es el de este sistema
## (archivo_de_aqui), y se puede pasar otro para probar.
func elegir_nueva(versiones: Array, local: String, archivo: String = ARCHIVO_WINDOWS) -> Dictionary:
	var mia := _numeros(local)
	if mia.is_empty():
		return {}
	var elegida: Dictionary = {}
	var por_version: Array = []
	for publicada: Variant in versiones:
		if not publicada is Dictionary or publicada.get("draft", false) \
				or publicada.get("prerelease", false):
			continue
		# Las etiquetas son v0.N; cualquier otra (alguna release vieja) no es
		# una version con numero.
		var etiqueta := String(publicada.get("tag_name", ""))
		var numeros := _numeros(etiqueta.trim_prefix("v"))
		if not etiqueta.begins_with("v") or numeros.is_empty() or not _mas_nueva(numeros, mia):
			continue
		por_version.append([numeros, _cambios(String(publicada.get("body", "")))])
		if not elegida.is_empty() and not _mas_nueva(numeros, elegida.numeros):
			continue
		elegida = {"numeros": numeros, "version": etiqueta.trim_prefix("v"), "url": "", "tamano": 0}
		for subido: Variant in publicada.get("assets", []):
			if subido is Dictionary and subido.get("name", "") == archivo:
				elegida.url = String(subido.get("browser_download_url", ""))
				elegida.tamano = int(subido.get("size", 0))
	if elegida.is_empty():
		return {}
	por_version.sort_custom(func(a: Array, b: Array) -> bool: return _mas_nueva(a[0], b[0]))
	var cambios := PackedStringArray()
	for una: Array in por_version:
		cambios.append_array(una[1])
	elegida.cambios = cambios
	return elegida


## Lo que cambia en una version: la lista de debajo de "### Qué cambia..." en
## sus notas (una linea por commit). Lo de antes de ese titulo es como
## descargarla, que aqui no hace falta.
func _cambios(notas: String) -> PackedStringArray:
	var cambios := PackedStringArray()
	var dentro := false
	for linea in notas.split("\n"):
		linea = linea.strip_edges()
		if linea.begins_with("### "):
			dentro = true
		elif dentro and linea.begins_with("- "):
			cambios.append(linea.substr(2).strip_edges())
	return cambios


func _al_bajar(resultado: int, codigo: int, _cabeceras: PackedStringArray, _cuerpo: PackedByteArray) -> void:
	# Cancelada: ya se ha tirado.
	if estado != Estado.DESCARGANDO:
		return
	if resultado != HTTPRequest.RESULT_SUCCESS or codigo != 200:
		_borrar_descarga()
		_fallar("Se ha cortado la descarga. Comprueba la conexión y vuelve a intentarlo.")
		return
	# Que haya llegado entero y sea lo que tiene que ser (un programa de
	# Windows empieza por "MZ", un .gz por 1F 8B y un .zip por "PK"), no una
	# pagina de error: si no, el juego no volveria a abrirse.
	var archivo := FileAccess.open(_descarga, FileAccess.READ)
	var entero := archivo != null and archivo.get_length() == int(nueva.tamano) \
		and archivo.get_buffer(2) == _comienzo_esperado()
	if archivo != null:
		archivo.close()
	if not entero:
		_borrar_descarga()
		_fallar("La descarga ha llegado incompleta. Vuelve a intentarlo.")
		return
	_instalar()


func _comienzo_esperado() -> PackedByteArray:
	match OS.get_name():
		"Linux":
			return PackedByteArray([0x1f, 0x8b])
		"macOS":
			return "PK".to_ascii_buffer()
	return "MZ".to_ascii_buffer()


## Pone lo bajado en lugar de lo de ahora (ver arriba: lo abierto se
## renombra, no se borra). En Windows lo bajado ya es el .exe; en Linux y en
## Mac antes hay que sacarlo del .tar.gz o del .zip, y eso se hace en otro
## hilo (son unos 115 MB: el juego se quedaria parado unos segundos). Si algo
## falla, deja lo de ahora como estaba.
func _instalar() -> void:
	var nuevo := _descarga
	if OS.get_name() != "Windows":
		_poner(Estado.INSTALANDO)
		nuevo = ruta_exe + ".nuevo"
		var error: Error = await _sacar(_descarga, nuevo, OS.get_name() == "macOS")
		_borrar_descarga()
		if error != OK:
			_borrar(nuevo)
			_fallar("La versión nueva ha llegado mal y no se ha podido sacar (error %d). Bájala desde la web." % error)
			return
	if not await poner_en_su_sitio(nuevo, ruta_exe):
		_borrar(nuevo)
		_borrar_descarga()
		_fallar("No se ha podido cambiar el juego por el nuevo. Bájalo desde la web.")
		return
	_poner(Estado.LISTA)


## Saca de 'paquete' el juego (el ejecutable de Linux, o la Vacio.app de Mac
## si 'es_mac') y lo deja en 'destino', en otro hilo.
func _sacar(paquete: String, destino: String, es_mac: bool) -> Error:
	_borrar(destino)
	var hilo := Thread.new()
	if es_mac:
		hilo.start(Desempaquetar.sacar_app_de_zip.bind(paquete, destino))
	else:
		hilo.start(Desempaquetar.sacar_de_tar_gz.bind(paquete, EJECUTABLE_LINUX, destino))
	while hilo.is_alive():
		await get_tree().process_frame
	return hilo.wait_to_finish()


## Lo de 'actual' pasa a llamarse <nombre>.viejo.<hora>.<extension> y 'nuevo'
## ocupa su nombre. Si lo segundo falla, lo de ahora vuelve a su sitio.
## Vale para un archivo y para una carpeta (la .app). Devuelve si ha ido bien.
func poner_en_su_sitio(nuevo: String, actual: String) -> bool:
	var viejo := "%s.viejo.%d.%s" % [actual.get_basename(), int(Time.get_unix_time_from_system()),
		actual.get_extension()]
	if not await _renombrar(actual, viejo):
		return false
	if not await _renombrar(nuevo, actual):
		await _renombrar(viejo, actual)
		return false
	return true


## Borra un archivo o una carpeta, si esta.
func _borrar(ruta: String) -> void:
	if DirAccess.dir_exists_absolute(ruta):
		Desempaquetar.borrar_carpeta(ruta)
	elif FileAccess.file_exists(ruta):
		DirAccess.remove_absolute(ruta)


func _renombrar(desde: String, hasta: String) -> bool:
	for intento in INTENTOS_RENOMBRAR:
		if DirAccess.rename_absolute(desde, hasta) == OK:
			return true
		await get_tree().create_timer(PAUSA_RENOMBRAR, true, false, true).timeout
	return false


## Borra lo que quede de otras veces junto al juego: los viejos que aparto
## _instalar y lo que quedara a medias (se cerro el juego mientras bajaba o
## sacaba). El viejo de la vez que se acaba de actualizar sigue abierto un
## momento y no se deja borrar: por eso se llama otra vez pasados unos
## segundos. En Mac los viejos son carpetas (.app).
func _limpiar() -> void:
	var carpeta := ruta_exe.get_base_dir()
	var nombre := ruta_exe.get_file()
	var viejos := nombre.get_basename() + ".viejo."
	var extension := nombre.get_extension()
	for archivo in DirAccess.get_files_at(carpeta):
		if (archivo.begins_with(viejos) and archivo.get_extension() == extension) \
				or archivo == nombre + ".descarga" or archivo == nombre + ".nuevo":
			DirAccess.remove_absolute(carpeta.path_join(archivo))
	for dentro in DirAccess.get_directories_at(carpeta):
		if (dentro.begins_with(viejos) and dentro.get_extension() == extension) \
				or dentro == nombre + ".nuevo":
			Desempaquetar.borrar_carpeta(carpeta.path_join(dentro))


func _borrar_descarga() -> void:
	if _descarga != "" and FileAccess.file_exists(_descarga):
		DirAccess.remove_absolute(_descarga)


func _fallar(por_que: String) -> void:
	motivo = por_que
	_poner(Estado.FALLO)


func _poner(nuevo: Estado) -> void:
	estado = nuevo
	cambiado.emit()


## "0.17" -> [0, 17]. Vacio si no es un numero de version publicado: "0.17 +
## cambios (abc1234)", "en desarrollo", "sin número".
static func _numeros(texto: String) -> PackedInt32Array:
	var numeros := PackedInt32Array()
	var partes := texto.strip_edges().split(".")
	if partes.size() < 2:
		return numeros
	for parte in partes:
		if not parte.is_valid_int() or not parte[0].is_valid_int():
			return PackedInt32Array()
		numeros.append(parte.to_int())
	return numeros


## True si la version 'a' es mas nueva que la 'b' ("0.10" lo es que "0.9").
static func _mas_nueva(a: PackedInt32Array, b: PackedInt32Array) -> bool:
	for i in maxi(a.size(), b.size()):
		var x := a[i] if i < a.size() else 0
		var y := b[i] if i < b.size() else 0
		if x != y:
			return x > y
	return false
