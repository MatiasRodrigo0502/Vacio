## Autoload GestorProgreso: unica fuente de verdad del progreso de la partida.
##
## OJO: este script NO declara class_name a proposito. En Godot 4 un class_name
## igual al nombre de un autoload provoca el error "hides an autoload singleton".
##
## POR QUE CENTRALIZAR AQUI:
## la escena Principal solo reacciona a senales; no decide en que piso esta ni
## cuando se gana. Asi, cuando en fases futuras haya menus, seleccion de piso o
## continuar partida, basta con llamar a este gestor desde cualquier sitio.
extends Node

## Ruta donde viven los .tres de los pisos. Se lee la carpeta entera en vez de
## mantener una lista hardcodeada: anadir o reordenar pisos no requiere tocar codigo.
const RUTA_PISOS := "res://resources/pisos"
const RUTA_MECANICAS := "res://resources/mecanicas"
const RUTA_PERSONAJES := "res://resources/personajes"

## Numero total de pisos esperado. Solo sirve de aviso si falta algun .tres.
const TOTAL_PISOS_ESPERADO := 12

## Se emite cada vez que hay que construir un piso (tambien en el primero).
signal piso_cambiado(numero_piso: int, datos: DatosPiso)
## Se emite al superar el piso marcado como final.
signal partida_ganada
## Se emite cuando el jugador se queda sin vida.
signal partida_perdida
## Se emite al reiniciar, antes de volver al piso 1.
signal partida_reiniciada

## Piso en el que esta el jugador ahora mismo (1..12). 0 = partida no empezada.
var piso_actual: int = 0

## Los 12 DatosPiso, en orden de profundidad (indice 0 = piso 1).
var pisos: Array[DatosPiso] = []

## Todas las mecanicas encontradas en disco, ordenadas por piso de desbloqueo.
var mecanicas: Array[Mecanica] = []

## true cuando la partida ha terminado (ganada o perdida): bloquea avances extra.
var partida_terminada: bool = false

## Los magos que se pueden elegir, en el orden de sus archivos.
var personajes: Array[PersonajeJugable] = []

## El mago elegido en el menu. Vive aqui y no en la escena del juego porque el
## menu y la partida son escenas distintas: al entrar a jugar el menu se libera
## entero, y la eleccion tiene que sobrevivir a eso.
var personaje_elegido: PersonajeJugable = null


func _ready() -> void:
	pisos = _cargar_pisos()
	mecanicas = _cargar_mecanicas()
	personajes = _cargar_personajes()
	# Si nadie ha elegido (por ejemplo al abrir Principal.tscn directamente
	# desde el editor), se juega con el primero.
	if not personajes.is_empty():
		personaje_elegido = personajes[0]

	if pisos.size() != TOTAL_PISOS_ESPERADO:
		push_warning("Se esperaban %d pisos en %s y se han cargado %d."
			% [TOTAL_PISOS_ESPERADO, RUTA_PISOS, pisos.size()])


## Arranca una partida desde el primer piso.
func iniciar_partida() -> void:
	partida_terminada = false
	piso_actual = 0
	avanzar_piso()


## Vuelve a empezar desde cero. Lo usan las pantallas de victoria y derrota.
func reiniciar_partida() -> void:
	partida_reiniciada.emit()
	iniciar_partida()


## Pasa al siguiente piso o termina la partida si el piso actual era el final.
## Es el unico punto del proyecto que decide "se avanza o se gana".
func avanzar_piso() -> void:
	if partida_terminada:
		return

	# Si el piso que acabamos de superar estaba marcado como final, se gana.
	var datos_actuales := obtener_datos_piso(piso_actual)
	if datos_actuales != null and datos_actuales.es_nivel_final:
		partida_terminada = true
		partida_ganada.emit()
		return

	piso_actual += 1

	# Red de seguridad: si alguien olvida marcar es_nivel_final en el ultimo
	# .tres, la partida termina igualmente al quedarse sin pisos.
	if piso_actual > pisos.size():
		partida_terminada = true
		partida_ganada.emit()
		return

	piso_cambiado.emit(piso_actual, pisos[piso_actual - 1])


## La llama la escena Principal cuando el jugador se queda sin vida.
func terminar_por_derrota() -> void:
	if partida_terminada:
		return
	partida_terminada = true
	partida_perdida.emit()


## Devuelve los datos de un piso por numero (1..N) o null si no existe.
func obtener_datos_piso(numero_piso: int) -> DatosPiso:
	if numero_piso < 1 or numero_piso > pisos.size():
		return null
	return pisos[numero_piso - 1]


## Mecanicas que deben estar activas en el piso indicado.
## Piso.gd las aplica sin saber que hace cada una (polimorfismo puro).
func obtener_mecanicas_activas(numero_piso: int) -> Array[Mecanica]:
	var activas: Array[Mecanica] = []
	for mecanica in mecanicas:
		if mecanica.esta_desbloqueada(numero_piso):
			activas.append(mecanica)
	return activas


## Guarda el mago con el que se va a jugar. La llama el menu.
func elegir_personaje(personaje: PersonajeJugable) -> void:
	if personaje != null:
		personaje_elegido = personaje


## Cuantos pisos hay en total (para el HUD: "Piso 3 / 12").
func total_pisos() -> int:
	return pisos.size()


# --- Carga desde disco ------------------------------------------------------

## Lee la carpeta de pisos y devuelve los recursos ordenados por nombre de archivo.
## POR QUE POR NOMBRE: los archivos se llaman piso_01_..., piso_02_..., asi que
## el orden alfabetico ES el orden de profundidad. Un piso nuevo solo necesita
## el prefijo numerico correcto.
func _cargar_pisos() -> Array[DatosPiso]:
	var resultado: Array[DatosPiso] = []
	for ruta in _listar_recursos(RUTA_PISOS):
		var recurso := load(ruta)
		if recurso is DatosPiso:
			resultado.append(recurso)
		else:
			push_warning("El archivo %s no es un DatosPiso valido." % ruta)
	return resultado


func _cargar_mecanicas() -> Array[Mecanica]:
	var resultado: Array[Mecanica] = []
	for ruta in _listar_recursos(RUTA_MECANICAS):
		var recurso := load(ruta)
		if recurso is Mecanica:
			resultado.append(recurso)
	# Ordenadas por piso de desbloqueo para que se apliquen siempre en el mismo
	# orden, sin depender de como el sistema de archivos devuelva los nombres.
	resultado.sort_custom(_comparar_mecanicas)
	return resultado


func _comparar_mecanicas(a: Mecanica, b: Mecanica) -> bool:
	return a.piso_desbloqueo < b.piso_desbloqueo


## Lee la carpeta de personajes. Igual que con los pisos, el orden alfabetico
## manda: los archivos empiezan por un numero, asi que anadir un mago es dejar
## su .tres ahi y ya sale en el menu.
func _cargar_personajes() -> Array[PersonajeJugable]:
	var resultado: Array[PersonajeJugable] = []
	for ruta in _listar_recursos(RUTA_PERSONAJES):
		var recurso := load(ruta)
		if recurso is PersonajeJugable:
			resultado.append(recurso)
		else:
			push_warning("El archivo %s no es un PersonajeJugable valido." % ruta)
	if resultado.is_empty():
		push_warning("No hay ningun personaje en %s." % RUTA_PERSONAJES)
	return resultado


## Devuelve las rutas .tres de una carpeta, ordenadas alfabeticamente.
## En una exportacion los .tres pueden aparecer como .tres.remap, por eso se
## limpia el sufijo antes de cargar.
func _listar_recursos(ruta_carpeta: String) -> PackedStringArray:
	var rutas := PackedStringArray()
	var carpeta := DirAccess.open(ruta_carpeta)
	if carpeta == null:
		push_warning("No se ha podido abrir la carpeta %s" % ruta_carpeta)
		return rutas

	var nombres := carpeta.get_files()
	nombres.sort()
	for nombre in nombres:
		var limpio := nombre.trim_suffix(".remap")
		if limpio.get_extension().to_lower() == "tres":
			rutas.append(ruta_carpeta.path_join(limpio))
	return rutas
