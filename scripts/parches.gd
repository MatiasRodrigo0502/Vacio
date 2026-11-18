## Autoload Parches, EL PRIMERO DE TODOS: en Android, carga al arrancar los paquetes
## (.pck) con lo que ha cambiado desde la version del .apk instalado (Matias,
## 2026-11-18: «que la actualización se descargue desde dentro del juego y se aplique
## solo lo que ha cambiado»). Los baja Actualizacion; aqui solo se cargan.
##
## COMO: cada version publica un paquete con los archivos que han cambiado desde la
## anterior (Vacio-android-desde-<anterior>.pck, ver publicar.yml). Se guardan en
## CARPETA y, al abrir el juego, se cargan en orden con
## ProjectSettings.load_resource_pack: lo de cada uno tapa lo del .apk y lo de los
## anteriores. Entre ellos va version.txt, asi que el juego dice ya la version nueva.
##
## POR QUE EL PRIMERO Y EN _init: Godot carga los autoloads uno detras de otro, y
## cada uno al crearlo. Cargando aqui los paquetes antes de que se cree el
## siguiente, los scripts de los demas autoloads (y todo lo que se cargue despues)
## ya salen de los paquetes. Este no: el suyo es siempre el del .apk.
##
## LO QUE NO PUEDE CAMBIAR UN PAQUETE (y entonces la version pide el .apk entero,
## ver publicar.yml): el motor, los ajustes del proyecto (project.godot, que se leen
## antes que nada), lo de exportar y este script.
##
## SI EL .APK CAMBIA (se ha instalado otro), los paquetes eran para el de antes: se
## borran sin cargarlos. Se sabe por la version del .apk con la que se bajaron.
##
## OJO: sin class_name a proposito, como los demas autoloads.
extends Node

const CARPETA := "user://parches"
## La lista: "base" (la version del .apk para la que son) y "archivos" (en orden).
const LISTA := "user://parches/lista.cfg"

## La version del .apk, antes de cargar ningun paquete.
var version_base: String = ""
## Los paquetes que se han cargado al arrancar, en orden.
var cargados: PackedStringArray = []


func _init() -> void:
	version_base = _leer_version()
	if not activo():
		return
	var lista := ConfigFile.new()
	if lista.load(LISTA) != OK:
		return
	if String(lista.get_value("parches", "base", "")) != version_base:
		borrar_todo()
		return
	for archivo: String in lista.get_value("parches", "archivos", PackedStringArray()):
		if not ProjectSettings.load_resource_pack(CARPETA.path_join(archivo), true):
			# Uno roto: se tiran todos. Se vuelve a la version del .apk la proxima vez,
			# y desde ahi se puede actualizar otra vez.
			push_warning("Parches: no se ha podido cargar %s; se borran todos" % archivo)
			borrar_todo()
			return
		cargados.append(archivo)


## Solo en Android. Con --probar-parches tambien en el ordenador, para probarlo con
## un .pck de base (--main-pack).
static func activo() -> bool:
	return OS.has_feature("android") or "--probar-parches" in OS.get_cmdline_user_args()


## Apunta un paquete mas, ya bajado y comprobado en CARPETA: se carga la proxima vez
## que se abra el juego.
func anadir(archivo: String) -> void:
	var lista := ConfigFile.new()
	lista.load(LISTA)
	var archivos: PackedStringArray = lista.get_value("parches", "archivos", PackedStringArray())
	# Bajado otra vez (se corto la cadena y se volvio a empezar): ya estaba apuntado.
	if archivo in archivos:
		return
	archivos.append(archivo)
	lista.set_value("parches", "base", version_base)
	lista.set_value("parches", "archivos", archivos)
	lista.save(LISTA)


func borrar_todo() -> void:
	var carpeta := ProjectSettings.globalize_path(CARPETA)
	for archivo in DirAccess.get_files_at(carpeta):
		DirAccess.remove_absolute(carpeta.path_join(archivo))


static func _leer_version() -> String:
	return FileAccess.get_file_as_string("res://version.txt").strip_edges()
