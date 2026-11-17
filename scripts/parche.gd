## Aplica un parche de herramientas/parche_juego.py: monta la version nueva del
## juego con trozos de la que hay y lo que trae el parche (Matias, 2026-11-17: en
## Linux, que la actualizacion haga «sólo los cambios necesarios en vez de instalar
## el juego de nuevo»). Lo usa Actualizacion; el formato esta explicado alli, en el
## .py, que es quien los crea.
##
## POR QUE TAN POCO: entre una version y la siguiente, el motor (73 MB) es el mismo
## y del paquete del juego cambian unos pocos archivos. El parche dice «copia de
## aqui tanto» o «pon estos bytes», y basta con seguirlo en orden.
##
## SE COMPRUEBA EL RESULTADO, no el viejo: el sha256 de lo que sale tiene que ser el
## que dice el parche. Si el viejo no era el que esperaba (otra version, un archivo
## tocado), no sale igual y no se usa: se baja el juego entero.
##
## Todo estatico, sin tocar nada mas que lo que se le pasa: se prueba con archivos
## hechos a mano, en cualquier sistema. Actualizacion lo llama en otro hilo.
class_name Parche
extends RefCounted

const MAGIA := "VPAR"
const VERSION: int = 1
const COPIAR: int = 0
const PONER: int = 1
## Lo que se copia del viejo de golpe: sin tener los 140 MB en memoria a la vez.
const TROZO_COPIA: int = 4 << 20


## Escribe en 'destino' el resultado de aplicar 'ruta_parche' a 'ruta_viejo', con
## permiso para ejecutarse. OK, o el error; si falla, 'destino' puede quedar a
## medias y lo borra quien lo llama.
static func aplicar(ruta_parche: String, ruta_viejo: String, destino: String) -> Error:
	var parche := FileAccess.open(ruta_parche, FileAccess.READ)
	var viejo := FileAccess.open(ruta_viejo, FileAccess.READ)
	if parche == null or viejo == null:
		return ERR_FILE_CANT_OPEN
	if parche.get_buffer(4).get_string_from_ascii() != MAGIA or parche.get_32() != VERSION:
		return ERR_FILE_UNRECOGNIZED
	var largo_viejo := parche.get_64()
	# La huella del viejo no se mira: leerlo entero otra vez cuesta, y si no era
	# el que tocaba, el resultado no casa con la suya.
	parche.get_buffer(32)
	var largo_nuevo := parche.get_64()
	var huella := parche.get_buffer(32)
	if viejo.get_length() != largo_viejo:
		return ERR_INVALID_DATA
	var salida := FileAccess.open(destino, FileAccess.WRITE)
	if salida == null:
		return ERR_FILE_CANT_WRITE
	var cuenta := HashingContext.new()
	cuenta.start(HashingContext.HASH_SHA256)
	var escrito := 0
	for i in parche.get_32():
		var tipo := parche.get_8()
		var a := parche.get_64()
		var b := parche.get_64()
		if tipo == COPIAR:
			viejo.seek(a)
			var queda := b
			while queda > 0:
				var trozo := viejo.get_buffer(mini(queda, TROZO_COPIA))
				if trozo.is_empty():
					return ERR_FILE_EOF
				salida.store_buffer(trozo)
				cuenta.update(trozo)
				queda -= trozo.size()
				escrito += trozo.size()
		elif tipo == PONER:
			var crudo := parche.get_buffer(b).decompress(a, FileAccess.COMPRESSION_GZIP)
			if crudo.size() != a:
				return ERR_FILE_CORRUPT
			salida.store_buffer(crudo)
			cuenta.update(crudo)
			escrito += a
		else:
			return ERR_FILE_CORRUPT
	salida.close()
	if escrito != largo_nuevo or cuenta.finish() != huella:
		return ERR_FILE_CORRUPT
	if OS.get_name() != "Windows":
		FileAccess.set_unix_permissions(destino, Desempaquetar.EJECUTABLE)
	return OK
