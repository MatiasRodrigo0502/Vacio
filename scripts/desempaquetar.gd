## Saca el juego de lo que se baja de GitHub para actualizarlo: el ejecutable
## de Linux de su .tar.gz y la carpeta Vacio.app de Mac de su .zip. Lo usa
## Actualizacion (pedido por Matias el 2026-11-03: poder darle a Actualizar
## tambien en Linux y en Mac, y no solo ir a la web).
##
## POR QUE VIENEN EMPAQUETADOS: un ejecutable suelto bajado de internet pierde
## el permiso de ejecutarse (le paso a Matias con la 0.1 en Linux). Por eso la
## release publica el de Linux dentro de un .tar.gz, que lo guarda, y el de Mac
## es una carpeta (.app) dentro de un .zip. Al sacarlos aqui se les vuelve a
## dar ese permiso.
##
## Godot sabe descomprimir gzip y leer zip, pero no el formato tar: se lee a
## mano, que es sencillo (bloques de 512 bytes: una cabecera con el nombre, el
## tamano y el modo en octal, y detras el contenido).
##
## Todo estatico y sin tocar nada mas que lo que se le pasa: se puede probar
## con archivos hechos a mano, en cualquier sistema.
class_name Desempaquetar
extends RefCounted

const BLOQUE: int = 512
## Hasta cuanto se deja crecer el .tar al descomprimirlo (el juego mide unos
## 115 MB): con algo de sobra, pero con tope, por si llega algo roto.
const TAMANO_MAXIMO: int = 1 << 30
## Permiso de ejecutarse: lectura y escritura para el dueno, lectura y
## ejecucion para todos (rwxr-xr-x, el 755 de chmod). En binario porque
## GDScript no tiene numeros en octal: cada grupo de tres es rwx.
const EJECUTABLE: int = 0b111_101_101


## Del .tar.gz 'origen', el archivo que se llama 'nombre' (sin mirar en que
## carpeta va), escrito en 'destino' y con permiso para ejecutarse. OK, o el
## error.
static func sacar_de_tar_gz(origen: String, nombre: String, destino: String) -> Error:
	var comprimido := FileAccess.get_file_as_bytes(origen)
	if comprimido.is_empty():
		return ERR_FILE_CANT_READ
	var tar := comprimido.decompress_dynamic(TAMANO_MAXIMO, FileAccess.COMPRESSION_GZIP)
	if tar.is_empty():
		return ERR_FILE_CORRUPT
	var sitio := 0
	while sitio + BLOQUE <= tar.size():
		var cabecera := tar.slice(sitio, sitio + BLOQUE)
		var entrada := _texto(cabecera, 0, 100)
		# Un bloque vacio: se acabo el archivo.
		if entrada == "":
			break
		var prefijo := _texto(cabecera, 345, 155)
		if prefijo != "":
			entrada = prefijo.path_join(entrada)
		var tamano := _octal(cabecera, 124, 12)
		# '0' (o nada, en los tar antiguos) es un archivo normal; lo demas
		# (carpetas, enlaces, cabeceras extendidas) se salta.
		var normal := cabecera[156] == 0 or cabecera[156] == "0".unicode_at(0)
		var datos := sitio + BLOQUE
		if normal and entrada.get_file() == nombre:
			if datos + tamano > tar.size():
				return ERR_FILE_CORRUPT
			var error := _escribir(destino, tar.slice(datos, datos + tamano))
			if error != OK:
				return error
			_poder_ejecutar(destino)
			return OK
		sitio = datos + ceili(tamano / float(BLOQUE)) * BLOQUE
	return ERR_FILE_NOT_FOUND


## Del .zip 'origen', la primera carpeta .app que traiga, con todo lo de
## dentro, escrita en 'destino' (que hace de esa carpeta). A lo de
## Contents/MacOS (el programa en si) se le da permiso para ejecutarse: el zip
## lo guarda, pero ZIPReader no lo devuelve. OK, o el error.
static func sacar_app_de_zip(origen: String, destino: String) -> Error:
	var zip := ZIPReader.new()
	var error := zip.open(origen)
	if error != OK:
		return error
	var app := ""
	for entrada in zip.get_files():
		var fin := entrada.find(".app/")
		# __MACOSX/ es lo que anade el compresor del Finder (datos aparte de
		# cada archivo), no la app. El .zip de Godot no lo trae; uno rehecho
		# a mano podria.
		if fin >= 0 and not entrada.begins_with("__MACOSX/"):
			app = entrada.substr(0, fin + 5)
			break
	if app == "":
		zip.close()
		return ERR_FILE_NOT_FOUND
	var puestos := 0
	for entrada in zip.get_files():
		if not entrada.begins_with(app) or entrada == app:
			continue
		var dentro := entrada.substr(app.length())
		var ruta := destino.path_join(dentro)
		if entrada.ends_with("/"):
			DirAccess.make_dir_recursive_absolute(ruta)
			continue
		DirAccess.make_dir_recursive_absolute(ruta.get_base_dir())
		error = _escribir(ruta, zip.read_file(entrada))
		if error != OK:
			zip.close()
			return error
		if dentro.begins_with("Contents/MacOS/"):
			_poder_ejecutar(ruta)
		puestos += 1
	zip.close()
	return OK if puestos > 0 else ERR_FILE_NOT_FOUND


## Borra una carpeta con todo lo que tenga dentro (la Vacio.app vieja).
## Tambien lo escondido: el Finder del Mac deja un .DS_Store en las carpetas
## que se abren, y con el dentro la carpeta no se dejaria borrar. Un enlace
## se quita sin entrar en el: si no, se borraria aquello a lo que apunta.
static func borrar_carpeta(ruta: String) -> void:
	var carpeta := DirAccess.open(ruta)
	if carpeta == null:
		return
	carpeta.include_hidden = true
	for archivo in carpeta.get_files():
		DirAccess.remove_absolute(ruta.path_join(archivo))
	for dentro in carpeta.get_directories():
		var sitio := ruta.path_join(dentro)
		if carpeta.is_link(sitio):
			DirAccess.remove_absolute(sitio)
		else:
			borrar_carpeta(sitio)
	DirAccess.remove_absolute(ruta)


static func _escribir(ruta: String, datos: PackedByteArray) -> Error:
	var archivo := FileAccess.open(ruta, FileAccess.WRITE)
	if archivo == null:
		return FileAccess.get_open_error()
	archivo.store_buffer(datos)
	archivo.close()
	return OK


## En Windows no hay permisos de Unix: ahi no hace nada (y no hace falta).
static func _poder_ejecutar(ruta: String) -> void:
	if OS.get_name() != "Windows":
		FileAccess.set_unix_permissions(ruta, EJECUTABLE)


## Un texto de la cabecera del tar: hasta el primer byte a cero.
static func _texto(cabecera: PackedByteArray, desde: int, largo: int) -> String:
	var trozo := cabecera.slice(desde, desde + largo)
	var fin := trozo.find(0)
	if fin >= 0:
		trozo = trozo.slice(0, fin)
	return trozo.get_string_from_utf8()


## Un numero de la cabecera del tar: en octal, en texto, con ceros o espacios
## de relleno.
static func _octal(cabecera: PackedByteArray, desde: int, largo: int) -> int:
	var valor := 0
	for i in range(desde, desde + largo):
		var cifra := cabecera[i]
		if cifra >= 0x30 and cifra <= 0x37:
			valor = valor * 8 + (cifra - 0x30)
		elif valor > 0:
			break
	return valor
