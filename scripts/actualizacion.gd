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
## LINUX, SOLO LO QUE CAMBIA (Matias, 2026-11-17: «que la actualización se integre
## en el archivo que ya hay, realizando sólo los cambios necesarios»): cada version
## trae un parche desde la anterior (PARCHE_LINUX, de herramientas/parche_juego.py).
## Si se tiene justo esa, se baja el parche, unos MB en vez de 140, y Parche monta
## con el y con el juego de ahora el nuevo. Si no hay parche para la nuestra (se ha
## saltado alguna version) o no sale bien, se baja entero, como antes. Y el viejo
## se borra en cuanto el nuevo esta en su sitio: Linux deja borrar un programa
## abierto (sigue funcionando hasta que se cierra), asi que no queda otro archivo
## al lado. En Windows no se puede: lo borra _limpiar al abrir la nueva.
##
## ANDROID, POR PAQUETES (Matias, 2026-11-18): un .apk no se puede cambiar desde
## dentro sin un plugin de Android, pero el juego si puede bajarse los paquetes (.pck)
## con lo que cambia de version a version (PAQUETE_ANDROID, unos KB o MB) y cargarlos
## al arrancar (Parches). Se baja la cadena desde la version que se tiene hasta la
## ultima, uno detras de otro, y quedan para la proxima vez que se abra. Si falta un
## eslabon (la version cambio el motor o los ajustes del proyecto, que un paquete no
## puede cambiar), hay que bajar el .apk entero desde la web, como antes; con la
## clave de firma fija (secretos de GitHub, desde el 2026-11-18) se instala encima.
##
## WINDOWS, CON EL LANZADOR (Matias, 2026-11-19: «que instale algo parecido a lo que
## tiene el Minecraft, que puedes instalar la versión que quieras y jugarla, así
## también ahorramos problemas de actualizaciones»): en Windows el juego ya no se
## cambia a si mismo. Cada version la baja el lanzador (lanzador/, en el instalador)
## a su carpeta, y se abre de ahi. Aqui solo se avisa de que hay una mas nueva y se
## manda a bajar el lanzador (por_que_no). Y abierto desde el lanzador (con
## -- --desde-lanzador, en Windows y en Linux), ni se busca: eso es del lanzador.
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
## El parche de Linux desde una version (la que se tiene): lo cuelga cada version
## para la anterior (.github/workflows/publicar.yml).
const PARCHE_LINUX := "Vacio-linux-desde-%s.parche"
## El paquete de Android desde una version: lo cuelga cada version para la anterior,
## salvo si necesita el .apk entero (ver arriba, ANDROID).
const PAQUETE_ANDROID := "Vacio-android-desde-%s.pck"
## Lo que pasa el lanzador al abrir una version (lanzador/lanzador.gd).
const DESDE_LANZADOR := "--desde-lanzador"
## Lo que se espera a la lista de versiones. Sin internet, mejor rendirse
## pronto: es un aviso, no algo que haga falta para jugar.
const ESPERA_BUSCAR: float = 10.0
## Lo que se lee de golpe al bajar el .exe. Con lo que trae Godot de serie
## (64 KB) la descarga va bastante mas lenta.
const TROZO_DESCARGA: int = 1 << 20
## Recien bajado, el antivirus suele abrir el .exe nuevo para mirarlo, y
## mientras tanto no se puede renombrar. Se reintenta un rato: hasta un minuto.
## Eran 5 s (20 de 0,25), y desde la 0.71 no bastaban (Matias, 2026-11-13: «no se
## ha podido cambiar el juego por el nuevo»): con el video de la portada el .exe
## paso de 166 a 170 MB, y revisarlo le cuesta mas al antivirus. Mientras, el
## aviso dice «Instalando...».
const INTENTOS_RENOMBRAR: int = 120
const PAUSA_RENOMBRAR: float = 0.5
## Donde se baja la version nueva antes de ponerla junto al juego, dentro de la
## carpeta de datos (user://). Al lado del juego, si esta en una carpeta de
## OneDrive (el Escritorio de Matias lo esta), OneDrive se pone a subir los 170 MB
## en cuanto aparecen y los tiene ocupados mientras: no se pueden mover.
const CARPETA_DESCARGA := "user://actualizacion"
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
## Donde se va bajando la version nueva: en CARPETA_DESCARGA si esta en el mismo
## disco que el juego, y si no al lado de la de ahora. Cambiarlas es renombrar, y
## entre discos distintos no se puede.
var _descarga: String = ""
## Si lo que se baja es el parche (ver arriba, LINUX) y no el juego entero.
var _con_parche: bool = false
## El parche fallo: se baja entero, hasta que se cierre el juego.
var _sin_parche: bool = false
## Lo que tiene que medir lo que se baja.
var _tamano_esperado: int = 0
## Donde quedo el juego de antes al poner el nuevo (poner_en_su_sitio).
var _viejo: String = ""
## En Android, los paquetes que quedan por bajar (los de nueva.paquetes) y lo que
## ya se ha bajado de los anteriores, para la barra.
var _paquetes: Array = []
var _bajado_antes: int = 0


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

	# En el navegador no hay nada que actualizar: la web siempre es la ultima.
	if OS.has_feature("editor") or OS.has_feature("web") or DisplayServer.get_name() == "headless":
		return
	version_local = GestorProgreso.version_juego()
	# Desde el lanzador: las versiones las lleva el (ver arriba, WINDOWS).
	if DESDE_LANZADOR in OS.get_cmdline_user_args():
		return
	match OS.get_name():
		"Windows":
			# Solo para borrar lo que dejaron las actualizaciones de antes (_limpiar):
			# en Windows ya no se instala nada desde aqui (se_puede_instalar).
			ruta_exe = OS.get_executable_path()
			por_que_no = "En Windows, las versiones se juegan con el lanzador de Vacío: bájate Vacio-instalador.exe de la web e instálalo. Ahí eliges la versión que quieras."
		"Linux":
			ruta_exe = OS.get_executable_path()
		"macOS":
			ruta_exe = _app_de_mac(OS.get_executable_path())
		"Android":
			# Por paquetes (ver arriba, ANDROID). Si no los hay, lo dice _al_buscar.
			pass
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
	if OS.get_name() == "Windows":
		return false
	if _por_paquetes():
		return not nueva.get("paquetes", []).is_empty()
	return ruta_exe != "" and String(nueva.get("url", "")) != ""


## En Android: se actualiza bajando paquetes (Parches).
func _por_paquetes() -> bool:
	return Parches.activo()


## Empieza a bajar el .exe de la version nueva, al lado del de ahora.
func descargar() -> void:
	if estado != Estado.HAY_NUEVA and estado != Estado.FALLO:
		return
	if not se_puede_instalar():
		abrir_pagina()
		return
	if _por_paquetes():
		_paquetes = (nueva.paquetes as Array).duplicate()
		_bajado_antes = 0
		_tamano_esperado = 0
		for paquete: Dictionary in _paquetes:
			_tamano_esperado += int(paquete.tamano)
		_bajar_paquete()
		return
	_descarga = _donde_bajar()
	# Antes de bajar 170 MB, que se pueda escribir ahi.
	var prueba := FileAccess.open(_descarga, FileAccess.WRITE)
	if prueba == null:
		_fallar("No se puede escribir en la carpeta del juego. Bájala desde la web y cámbiala tú.")
		return
	prueba.close()
	_bajador.download_file = _descarga
	_con_parche = not _sin_parche and String(nueva.get("parche_url", "")) != ""
	var url := String(nueva.parche_url if _con_parche else nueva.url)
	_tamano_esperado = int(nueva.parche_tamano if _con_parche else nueva.tamano)
	var error := _bajador.request(url, ["User-Agent: Vacio"])
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
	return _bajado_antes + _bajador.get_downloaded_bytes()


func total() -> int:
	if _por_paquetes():
		return _tamano_esperado
	var tamano := _bajador.get_body_size()
	return tamano if tamano > 0 else _tamano_esperado


## Abre la version nueva y cierra esta. Solo con la nueva ya en su sitio. En
## Mac una .app se abre con "open" (-n: otra aunque esta siga abierta).
func reiniciar() -> void:
	if estado != Estado.LISTA:
		return
	# Android no deja abrir otra vez la app desde ella misma: se cierra, y al
	# abrirla se cargan los paquetes nuevos (Parches).
	if _por_paquetes():
		Sonido.salir()
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
	if _por_paquetes() and not nueva.is_empty() and nueva.paquetes.is_empty():
		por_que_no = "Esta versión necesita el juego entero: descarga Vacio-android.apk desde la web y ábrelo para instalarla."
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
		elegida = {"numeros": numeros, "version": etiqueta.trim_prefix("v"), "url": "", "tamano": 0,
			"parche_url": "", "parche_tamano": 0}
		# El parche, solo en Linux y desde la version que se tiene (ver arriba).
		var parche := PARCHE_LINUX % local if archivo == ARCHIVO_LINUX else ""
		for subido: Variant in publicada.get("assets", []):
			if not subido is Dictionary:
				continue
			if subido.get("name", "") == archivo:
				elegida.url = String(subido.get("browser_download_url", ""))
				elegida.tamano = int(subido.get("size", 0))
			elif parche != "" and subido.get("name", "") == parche:
				elegida.parche_url = String(subido.get("browser_download_url", ""))
				elegida.parche_tamano = int(subido.get("size", 0))
	if elegida.is_empty():
		return {}
	elegida.paquetes = _cadena_de_paquetes(versiones, local, elegida.version) if archivo == ARCHIVO_ANDROID else []
	por_version.sort_custom(func(a: Array, b: Array) -> bool: return _mas_nueva(a[0], b[0]))
	var cambios := PackedStringArray()
	for una: Array in por_version:
		cambios.append_array(una[1])
	elegida.cambios = cambios
	return elegida


## Los paquetes de Android para ir de 'local' a 'ultima', en orden: cada version
## cuelga el suyo desde la anterior (PAQUETE_ANDROID). Vacio si falta alguno: entonces
## hace falta el .apk entero.
func _cadena_de_paquetes(versiones: Array, local: String, ultima: String) -> Array:
	var desde_cada: Dictionary = {}
	var prefijo := PAQUETE_ANDROID.get_slice("%s", 0)
	for publicada: Variant in versiones:
		if not publicada is Dictionary or publicada.get("draft", false):
			continue
		var version := String(publicada.get("tag_name", "")).trim_prefix("v")
		for subido: Variant in publicada.get("assets", []):
			if not subido is Dictionary:
				continue
			var nombre := String(subido.get("name", ""))
			if nombre.begins_with(prefijo) and nombre.ends_with(".pck"):
				desde_cada[nombre.trim_prefix(prefijo).trim_suffix(".pck")] = {"version": version,
					"nombre": nombre, "url": String(subido.get("browser_download_url", "")),
					"tamano": int(subido.get("size", 0)),
					# GitHub da el sha256 de cada archivo ("sha256:..."): se comprueba al bajarlo.
					"huella": String(subido.get("digest", "")).trim_prefix("sha256:")}
	var cadena: Array = []
	var version := local
	while desde_cada.has(version) and cadena.size() < versiones.size():
		var paquete: Dictionary = desde_cada[version]
		cadena.append(paquete)
		version = paquete.version
	return cadena if version == ultima else []


## Baja el primero de los paquetes que quedan. Va a la carpeta de Parches con otro
## nombre hasta que esta entero y comprobado.
func _bajar_paquete() -> void:
	var paquete: Dictionary = _paquetes[0]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(Parches.CARPETA))
	_descarga = ProjectSettings.globalize_path(Parches.CARPETA.path_join(paquete.nombre + ".descarga"))
	_bajador.download_file = _descarga
	if _bajador.request(String(paquete.url), ["User-Agent: Vacio"]) != OK:
		_borrar_descarga()
		_fallar("No se ha podido empezar la descarga.")
		return
	_poner(Estado.DESCARGANDO)


## Uno bajado: si es el que tiene que ser, se apunta en Parches y se baja el siguiente.
func _paquete_bajado() -> void:
	var paquete: Dictionary = _paquetes[0]
	var archivo := FileAccess.open(_descarga, FileAccess.READ)
	var bien := archivo != null and archivo.get_length() == int(paquete.tamano) \
		and archivo.get_buffer(4) == "GDPC".to_ascii_buffer()
	if archivo != null:
		archivo.close()
	if bien and String(paquete.huella) != "":
		bien = FileAccess.get_sha256(_descarga) == String(paquete.huella)
	var destino := ProjectSettings.globalize_path(Parches.CARPETA.path_join(paquete.nombre))
	if not bien or DirAccess.rename_absolute(_descarga, destino) != OK:
		_borrar_descarga()
		_fallar("La descarga ha llegado incompleta. Vuelve a intentarlo.")
		return
	Parches.anadir(paquete.nombre)
	_bajado_antes += int(paquete.tamano)
	_paquetes.pop_front()
	if _paquetes.is_empty():
		_poner(Estado.LISTA)
	else:
		_bajar_paquete()


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
	if _por_paquetes():
		_paquete_bajado()
		return
	# Que haya llegado entero y sea lo que tiene que ser (un programa de
	# Windows empieza por "MZ", un .gz por 1F 8B y un .zip por "PK"), no una
	# pagina de error: si no, el juego no volveria a abrirse.
	var archivo := FileAccess.open(_descarga, FileAccess.READ)
	var entero := archivo != null and archivo.get_length() == _tamano_esperado \
		and archivo.get_buffer(2) == _comienzo_esperado()
	if archivo != null:
		archivo.close()
	if not entero:
		_borrar_descarga()
		_fallar("La descarga ha llegado incompleta. Vuelve a intentarlo.")
		return
	_instalar()


func _comienzo_esperado() -> PackedByteArray:
	if _con_parche:
		return Parche.MAGIA.substr(0, 2).to_ascii_buffer()
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
	# En Windows tambien: poner el nuevo en su sitio puede tardar hasta un minuto si
	# el antivirus lo esta revisando (INTENTOS_RENOMBRAR).
	_poner(Estado.INSTALANDO)
	if _con_parche:
		nuevo = ruta_exe + ".nuevo"
		var error_parche: Error = await _en_otro_hilo(Parche.aplicar.bind(_descarga, ruta_exe, nuevo))
		_borrar_descarga()
		if error_parche != OK:
			# Se baja entero, como si no hubiera parche.
			push_warning("Actualizacion: el parche no ha servido (error %d); se baja entera" % error_parche)
			_borrar(nuevo)
			_sin_parche = true
			_poner(Estado.HAY_NUEVA)
			descargar()
			return
	elif OS.get_name() != "Windows":
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
		if ruta_exe.containsn("onedrive"):
			_fallar("No se ha podido cambiar el juego por el nuevo: OneDrive o el antivirus lo tenían ocupado. Pon el juego en una carpeta fuera de OneDrive (por ejemplo, C:\\Juegos) o bájalo desde la web.")
		else:
			_fallar("No se ha podido cambiar el juego por el nuevo: el antivirus o algún programa lo tenía ocupado. Vuelve a intentarlo o bájalo desde la web.")
		return
	# En Linux el de antes se va ya, aunque siga abierto (ver arriba, LINUX).
	if OS.get_name() == "Linux":
		DirAccess.remove_absolute(_viejo)
	_poner(Estado.LISTA)


## Saca de 'paquete' el juego (el ejecutable de Linux, o la Vacio.app de Mac
## si 'es_mac') y lo deja en 'destino', en otro hilo.
func _sacar(paquete: String, destino: String, es_mac: bool) -> Error:
	_borrar(destino)
	if es_mac:
		return await _en_otro_hilo(Desempaquetar.sacar_app_de_zip.bind(paquete, destino))
	return await _en_otro_hilo(Desempaquetar.sacar_de_tar_gz.bind(paquete, EJECUTABLE_LINUX, destino))


## Lo hace en otro hilo y espera sin parar el juego: son 140 MB que leer y escribir.
func _en_otro_hilo(tarea: Callable) -> Error:
	var hilo := Thread.new()
	hilo.start(tarea)
	while hilo.is_alive():
		await get_tree().process_frame
	return hilo.wait_to_finish()


## Lo de 'actual' pasa a llamarse <nombre>.viejo.<hora>.<extension> y 'nuevo'
## ocupa su nombre. Si lo segundo falla, lo de ahora vuelve a su sitio.
## Vale para un archivo y para una carpeta (la .app). Devuelve si ha ido bien.
func poner_en_su_sitio(nuevo: String, actual: String) -> bool:
	var viejo := "%s.viejo.%d.%s" % [actual.get_basename(), int(Time.get_unix_time_from_system()),
		actual.get_extension()]
	_viejo = viejo
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
	var error := OK
	for intento in INTENTOS_RENOMBRAR:
		error = DirAccess.rename_absolute(desde, hasta)
		if error == OK:
			return true
		await get_tree().create_timer(PAUSA_RENOMBRAR, true, false, true).timeout
	# Al registro (logs/godot.log de la carpeta de datos): que se sepa cual de los
	# dos no se dejo mover y por que.
	push_warning("Actualizacion: no se ha podido mover %s a %s (error %d)" % [desde, hasta, error])
	return false


## Donde bajar la version nueva: en CARPETA_DESCARGA, fuera de la carpeta del juego
## (ver arriba, OneDrive), si esta en el mismo disco que el juego; si no, al lado,
## como antes.
func _donde_bajar() -> String:
	var carpeta := ProjectSettings.globalize_path(CARPETA_DESCARGA)
	if _disco(carpeta) == _disco(ruta_exe) and DirAccess.make_dir_recursive_absolute(carpeta) == OK:
		return carpeta.path_join(ruta_exe.get_file() + ".descarga")
	return ruta_exe + ".descarga"


## La letra de la unidad en Windows ("C:"); en Linux y Mac, lo mismo para todo.
func _disco(ruta: String) -> String:
	return ruta.substr(0, 2).to_upper() if OS.get_name() == "Windows" else "/"


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
	# Y lo que quedara a medias en la carpeta de las descargas.
	var descargas := ProjectSettings.globalize_path(CARPETA_DESCARGA)
	for archivo in DirAccess.get_files_at(descargas):
		if archivo.ends_with(".descarga"):
			DirAccess.remove_absolute(descargas.path_join(archivo))


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
