## Autoload Cuenta: iniciar sesion con correo y contrasena, registrarse con un apodo
## y subir la mejor partida a la clasificacion (Matias, 2026-11-19).
##
## OJO: sin class_name a proposito, como Sonido y Pantalla: un class_name igual al
## nombre del autoload da "hides an autoload singleton".
##
## LAS CUENTAS LAS LLEVA SUPABASE, NO EL JUEGO: el correo y la contrasena viajan
## una sola vez, al entrar o registrarse, directos a su servicio de cuentas (por
## HTTPS). Aqui se guarda solo la sesion (user://sesion.cfg): el token de acceso,
## que caduca en una hora, y el de renovarlo, que Supabase cambia cada vez que se
## usa. La contrasena no se guarda en ningun sitio. Cerrar sesion borra el archivo
## y avisa a Supabase para que ese token deje de valer.
##
## SE PUEDE JUGAR SIN CUENTA: lo unico que la pide es subir puntuaciones. Sin
## Supabase configurado (resources/cuentas/servicio.tres vacio) todo esto se
## apaga y el menu lo dice.
##
## El apodo es unico sin mirar mayusculas («Matias» y «matias», el mismo) y de 1 a
## 16 caracteres, cualquiera menos los de control. Lo garantiza la base de datos
## (servidor/supabase/migrations); aqui se mira antes para avisar sin esperar.
extends Node

signal sesion_cambiada

const CONFIGURACION := "res://resources/cuentas/servicio.tres"
const ARCHIVO_SESION := "user://sesion.cfg"
const APODO_MAXIMO: int = 16
## Lo que pide Supabase por defecto.
const CONTRASENA_MINIMA: int = 6
## Segundos antes de dar una peticion por perdida.
const TIEMPO_ESPERA: float = 15.0
## Se renueva el token si le queda menos que esto: que no caduque a mitad de subir.
const MARGEN_CADUCA: int = 60

var configuracion: ConfiguracionCuentas
var correo: String = ""
var apodo: String = ""

var _archivo: String = ARCHIVO_SESION
var _token: String = ""
var _renovar: String = ""
## Cuando caduca _token, en segundos desde 1970.
var _caduca: int = 0


func _ready() -> void:
	# Tambien en pausa: la pantalla final y los menus pueden estar con el juego parado.
	process_mode = Node.PROCESS_MODE_ALWAYS
	configuracion = load(CONFIGURACION) as ConfiguracionCuentas
	_cargar()


## Para las pruebas: otro archivo de sesion, para no tocar la de quien las lanza.
func usar_archivo(ruta: String) -> void:
	_archivo = ruta
	_cargar()


## Para las pruebas: otro servicio (uno falso en este ordenador).
func usar_configuracion(otra: ConfiguracionCuentas) -> void:
	configuracion = otra


## Si hay un proyecto de Supabase puesto. Sin el, ni entrar ni subir.
func hay_servicio() -> bool:
	return configuracion != null and configuracion.cuentas_listas()


func con_sesion() -> bool:
	return _renovar != ""


# --- Comprobaciones de lo que se escribe ------------------------------------------

## El apodo tal como se guarda: sin espacios a los lados.
static func limpiar_apodo(texto: String) -> String:
	return texto.strip_edges()


## Que le pasa a un apodo, o "" si vale.
static func problema_apodo(texto: String) -> String:
	var limpio := limpiar_apodo(texto)
	if limpio.is_empty():
		return "Escribe un apodo."
	if limpio.length() > APODO_MAXIMO:
		return "El apodo puede tener %d caracteres como mucho." % APODO_MAXIMO
	for i in limpio.length():
		var codigo := limpio.unicode_at(i)
		if codigo < 32 or (codigo >= 127 and codigo < 160):
			return "El apodo no puede llevar saltos de línea ni caracteres de control."
	return ""


static func problema_correo(texto: String) -> String:
	var limpio := texto.strip_edges()
	var arroba := limpio.find("@")
	if arroba <= 0 or limpio.find(".", arroba) < 0 or limpio.contains(" "):
		return "Ese correo no es válido."
	return ""


static func problema_contrasena(texto: String) -> String:
	if texto.length() < CONTRASENA_MINIMA:
		return "La contraseña tiene que tener al menos %d caracteres." % CONTRASENA_MINIMA
	return ""


# --- Entrar, registrarse y salir ----------------------------------------------------

## Crea la cuenta. Supabase manda un correo para confirmarla: hasta abrir el enlace no
## se puede entrar (ni subir nada). Devuelve {ok, mensaje}.
func registrarse(correo_nuevo: String, contrasena: String, apodo_nuevo: String) -> Dictionary:
	correo_nuevo = correo_nuevo.strip_edges()
	apodo_nuevo = limpiar_apodo(apodo_nuevo)
	for problema in [problema_correo(correo_nuevo), problema_contrasena(contrasena), problema_apodo(apodo_nuevo)]:
		if problema != "":
			return {"ok": false, "mensaje": problema}
	if not hay_servicio():
		return _sin_servicio()
	var libre := await apodo_libre(apodo_nuevo)
	if libre.has("error"):
		return {"ok": false, "mensaje": libre.error}
	if not libre.libre:
		return {"ok": false, "mensaje": "Ese apodo ya está en uso."}
	var respuesta := await _pedir(HTTPClient.METHOD_POST, "/auth/v1/signup",
		{"email": correo_nuevo, "password": contrasena, "data": {"apodo": apodo_nuevo}})
	if respuesta.codigo != 200:
		return {"ok": false, "mensaje": _mensaje_error(respuesta, true)}
	var datos: Dictionary = respuesta.datos if respuesta.datos is Dictionary else {}
	# Con la confirmacion de correo apagada en Supabase, ya trae la sesion.
	if datos.has("access_token"):
		_poner_sesion(datos)
		return {"ok": true, "mensaje": "Cuenta creada. Ya has entrado como %s." % apodo}
	# Si el correo ya tenia cuenta, Supabase no lo dice (para no descubrir correos
	# ajenos): devuelve una cuenta sin identidades.
	var usuario: Dictionary = datos.get("user", datos)
	if usuario.get("identities", [null]) is Array and (usuario.get("identities", [null]) as Array).is_empty():
		return {"ok": false, "mensaje": "Ese correo ya tiene cuenta. Inicia sesión."}
	return {"ok": true, "mensaje": "Te hemos enviado un correo a %s. Abre el enlace para confirmar la cuenta y luego inicia sesión aquí." % correo_nuevo}


## Devuelve {libre: bool} o {error: mensaje}.
func apodo_libre(texto: String) -> Dictionary:
	if not hay_servicio():
		return {"error": _sin_servicio().mensaje}
	var respuesta := await _pedir(HTTPClient.METHOD_POST, "/rest/v1/rpc/apodo_libre",
		{"p_apodo": limpiar_apodo(texto)})
	if respuesta.codigo != 200 or not respuesta.datos is bool:
		return {"error": _mensaje_error(respuesta)}
	return {"libre": respuesta.datos}


## Devuelve {ok, mensaje}.
func iniciar_sesion(correo_dado: String, contrasena: String) -> Dictionary:
	correo_dado = correo_dado.strip_edges()
	if problema_correo(correo_dado) != "":
		return {"ok": false, "mensaje": problema_correo(correo_dado)}
	if contrasena.is_empty():
		return {"ok": false, "mensaje": "Escribe la contraseña."}
	if not hay_servicio():
		return _sin_servicio()
	var respuesta := await _pedir(HTTPClient.METHOD_POST, "/auth/v1/token?grant_type=password",
		{"email": correo_dado, "password": contrasena})
	if respuesta.codigo != 200 or not respuesta.datos is Dictionary:
		return {"ok": false, "mensaje": _mensaje_error(respuesta)}
	_poner_sesion(respuesta.datos)
	return {"ok": true, "mensaje": "Has entrado como %s." % apodo}


## Borra la sesion de aqui y avisa a Supabase (scope=local: solo la de este aparato,
## no la de los demas en los que se haya entrado), sin esperarle: aunque no conteste
## (sin internet), aqui ya no hay sesion.
func cerrar_sesion() -> void:
	if hay_servicio() and _token != "" and _caduca > _ahora():
		_pedir(HTTPClient.METHOD_POST, "/auth/v1/logout?scope=local", {}, _token)
	_olvidar_sesion()


## Un token de acceso que valga, renovandolo si va a caducar. "" si la sesion ya
## no vale (y entonces se cierra).
func token_valido() -> String:
	if not con_sesion() or not hay_servicio():
		return ""
	if _token != "" and _caduca - MARGEN_CADUCA > _ahora():
		return _token
	var respuesta := await _pedir(HTTPClient.METHOD_POST, "/auth/v1/token?grant_type=refresh_token",
		{"refresh_token": _renovar})
	if respuesta.codigo == 200 and respuesta.datos is Dictionary:
		_poner_sesion(respuesta.datos)
		return _token
	# Sin internet la sesion sigue: ya se renovara. Rechazada (cerrada en otro
	# sitio, cuenta borrada), se olvida.
	if respuesta.codigo >= 400 and respuesta.codigo < 500:
		_olvidar_sesion()
	return ""


# --- Clasificacion ---------------------------------------------------------------

## Sube la partida (MarcadorPartida.datos). La funcion del servidor la valida y solo
## la guarda si es la mejor de este jugador. Devuelve {ok, mensaje}.
func subir_puntuacion(partida: Dictionary) -> Dictionary:
	if not hay_servicio():
		return _sin_servicio()
	if not con_sesion():
		return {"ok": false, "mensaje": "Inicia sesión en el menú para subir tus partidas."}
	var token := await token_valido()
	if token == "":
		if not con_sesion():
			return {"ok": false, "mensaje": "La sesión ha caducado: vuelve a entrar en el menú."}
		return {"ok": false, "mensaje": "No se ha podido conectar. La partida no se ha subido."}
	var cuerpo := partida.duplicate()
	cuerpo["apodo"] = apodo
	var respuesta := await _pedir(HTTPClient.METHOD_POST, "/functions/v1/subir-puntuacion", cuerpo, token)
	var datos: Dictionary = respuesta.datos if respuesta.datos is Dictionary else {}
	if respuesta.codigo == 200:
		var puesto := int(datos.get("puesto", 0))
		if datos.get("subida", false):
			return {"ok": true, "mensaje": "¡Nueva mejor partida! Puesto %d de la clasificación." % puesto}
		return {"ok": true, "mensaje": "No mejora tu mejor partida (puesto %d)." % puesto}
	match String(datos.get("error", "")):
		"correo_sin_confirmar":
			return {"ok": false, "mensaje": "Confirma tu correo para subir partidas."}
		"sesion_caducada", "sin_sesion":
			return {"ok": false, "mensaje": "La sesión ha caducado: vuelve a entrar en el menú."}
		"datos_invalidos":
			return {"ok": false, "mensaje": "El servidor no ha aceptado la partida (%s)." % datos.get("detalle", "")}
	return {"ok": false, "mensaje": _mensaje_error(respuesta)}


## La clasificacion entera, de GitHub. Devuelve {ok, entradas} o {ok: false, mensaje}.
func leer_clasificacion() -> Dictionary:
	if configuracion == null or configuracion.url_clasificacion == "":
		return {"ok": false, "mensaje": "La clasificación no está configurada."}
	# Lo de detras de la ? es para saltarse copias viejas por el camino: GitHub
	# guarda el archivo unos minutos, y una partida recien subida tardaria en salir.
	var url := "%s?v=%d" % [configuracion.url_clasificacion, _ahora()]
	var respuesta := await _pedir_url(HTTPClient.METHOD_GET, url, PackedStringArray(), "")
	# Sin archivo aun: nadie ha subido nada.
	if respuesta.codigo == 404:
		return {"ok": true, "entradas": []}
	if respuesta.codigo != 200 or not respuesta.datos is Dictionary \
			or not (respuesta.datos as Dictionary).get("entradas") is Array:
		return {"ok": false, "mensaje": _mensaje_error(respuesta)}
	return {"ok": true, "entradas": respuesta.datos.entradas}


# --- Por dentro ----------------------------------------------------------------------

func _sin_servicio() -> Dictionary:
	return {"ok": false, "mensaje": "Las cuentas aún no están configuradas en esta versión."}


func _ahora() -> int:
	return int(Time.get_unix_time_from_system())


func _poner_sesion(datos: Dictionary) -> void:
	_token = String(datos.get("access_token", ""))
	_renovar = String(datos.get("refresh_token", _renovar))
	var caduca := int(datos.get("expires_at", 0))
	if caduca == 0:
		caduca = _ahora() + int(datos.get("expires_in", 3600))
	_caduca = caduca
	var usuario: Dictionary = datos.get("user", {})
	if not usuario.is_empty():
		correo = String(usuario.get("email", correo))
		var metadatos: Dictionary = usuario.get("user_metadata", {})
		apodo = String(metadatos.get("apodo", apodo))
	_guardar()
	sesion_cambiada.emit()


func _olvidar_sesion() -> void:
	var habia := con_sesion()
	_token = ""
	_renovar = ""
	_caduca = 0
	correo = ""
	apodo = ""
	if FileAccess.file_exists(_archivo):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_archivo))
	if habia:
		sesion_cambiada.emit()


func _cargar() -> void:
	_token = ""
	_renovar = ""
	_caduca = 0
	correo = ""
	apodo = ""
	var datos := ConfigFile.new()
	if datos.load(_archivo) != OK:
		return
	_token = datos.get_value("sesion", "token", "")
	_renovar = datos.get_value("sesion", "renovar", "")
	_caduca = datos.get_value("sesion", "caduca", 0)
	correo = datos.get_value("sesion", "correo", "")
	apodo = datos.get_value("sesion", "apodo", "")


func _guardar() -> void:
	var datos := ConfigFile.new()
	datos.set_value("sesion", "token", _token)
	datos.set_value("sesion", "renovar", _renovar)
	datos.set_value("sesion", "caduca", _caduca)
	datos.set_value("sesion", "correo", correo)
	datos.set_value("sesion", "apodo", apodo)
	datos.save(_archivo)


## Una peticion a Supabase. Con token, como esa cuenta; sin el, como cualquiera (la
## clave publica). Devuelve {codigo, datos}: codigo 0 si no se ha podido conectar.
func _pedir(metodo: int, ruta: String, cuerpo: Dictionary, token: String = "") -> Dictionary:
	# Authorization, solo con la sesion de alguien: las claves nuevas de Supabase
	# (sb_publishable_...) no son un token y van nada mas en apikey.
	var cabeceras := PackedStringArray([
		"apikey: " + configuracion.clave_publica,
		"Content-Type: application/json",
	])
	if token != "":
		cabeceras.append("Authorization: Bearer " + token)
	return await _pedir_url(metodo, configuracion.url_supabase + ruta, cabeceras, JSON.stringify(cuerpo))


func _pedir_url(metodo: int, url: String, cabeceras: PackedStringArray, cuerpo: String) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = TIEMPO_ESPERA
	add_child(http)
	if http.request(url, cabeceras, metodo, cuerpo) != OK:
		http.queue_free()
		return {"codigo": 0, "datos": null}
	var fin: Array = await http.request_completed
	http.queue_free()
	if fin[0] != HTTPRequest.RESULT_SUCCESS:
		return {"codigo": 0, "datos": null}
	var texto := (fin[3] as PackedByteArray).get_string_from_utf8()
	var datos: Variant = JSON.parse_string(texto) if not texto.is_empty() else null
	return {"codigo": int(fin[1]), "datos": datos}


## Lo que ha dicho Supabase, en castellano. Sus errores llegan como error_code (los
## nuevos) o error_description/msg (los de antes).
func _mensaje_error(respuesta: Dictionary, registrando: bool = false) -> String:
	if respuesta.codigo == 0:
		return "No se ha podido conectar. ¿Hay internet?"
	var datos: Dictionary = respuesta.datos if respuesta.datos is Dictionary else {}
	var codigo := String(datos.get("error_code", datos.get("error", "")))
	var texto := String(datos.get("msg", datos.get("error_description", datos.get("message", ""))))
	if codigo == "invalid_credentials" or texto.contains("Invalid login credentials"):
		return "Correo o contraseña incorrectos."
	if codigo == "email_not_confirmed" or texto.contains("Email not confirmed"):
		return "Aún no has confirmado el correo: abre el enlace que te enviamos."
	if codigo in ["user_already_exists", "email_exists"]:
		return "Ese correo ya tiene cuenta. Inicia sesión."
	if codigo == "weak_password":
		return "La contraseña es demasiado débil."
	if codigo in ["email_address_invalid", "validation_failed"]:
		return "Ese correo no es válido."
	if codigo.begins_with("over_") or respuesta.codigo == 429:
		return "Demasiados intentos. Espera un poco y vuelve a probar."
	# El apodo lo comprueba la base de datos al crear la cuenta: si otro lo ha cogido
	# justo entre medias, Supabase solo dice que no ha podido guardar al usuario.
	if registrando and (codigo == "unexpected_failure" or texto.contains("Database error saving new user")):
		return "Ese apodo ya está en uso."
	return "Algo ha fallado (código %d). Vuelve a probar en un rato." % respuesta.codigo
