## El tutorial del piso 1: una ventana (AvisoTutorial) al entrar en cada sala.
##
## Pedido por Matias el 2026-10-29: «que te explique como funciona todo y en
## la tercera sala te explique que hay que matar a los enemigos», y luego
## «que en vez de texto se abriera un pop up». El piso 1 es una fila de salas
## (MapaSalas, en_fila) y cada una ensena una cosa:
##   1. a que se juega, moverse, disparar y la pausa;
##   2. el ataque especial (el del mago elegido), las rocas, la vida y el mapa;
##   3. la primera pelea: hay que matarlos a todos para que se abran las
##      puertas (los enemigos los pone Piso, de DatosPiso.enemigos_tutorial);
##   4. los objetos (el del piso esta en el centro) y los vendajes;
##   5. la bajada, y lo que espera mas abajo.
## Antes eran carteles pintados en el suelo de la sala de inicio.
##
## Cada ventana sale UNA SOLA VEZ, tambien si se cierra el juego (Matias,
## 2026-11-05: «que el tutorial salga una vez solo, no cada vez que empieces una
## partida»): las que ya han salido se guardan en user://ajustes.cfg. Una a una, al
## salir: quien lo deja a medias ve las que le faltan cuando llegue a ellas. La del
## especial va por mago, porque con otro cuenta otra cosa. El piso 1 sigue siendo
## igual, con su fila de salas y su pelea: lo que deja de salir son las ventanas.
##
## Las escenas de prueba, que montan Principal dentro de la suya y pasan todas por
## el piso 1, ni leen ni guardan (_de_prueba, como RegistroPartida): si no, darian
## el tutorial por visto en el ordenador de quien las lanza.
##
## Los textos estan aqui y no en una escena porque dependen de las teclas
## elegidas en Controles y del mago: [k]...[/k] resalta (AvisoTutorial), y
## {mover}, {disparar}, {raton}, {pausa} y {especial} se rellenan al abrir la
## ventana, con las teclas que haya en la tabla de controles.
class_name Tutorial
extends Node

## Lo que espera desde que se entra en una sala hasta que sale su ventana: lo
## que tarda la camara en llegar a ella. La ventana para el juego, y parado a
## medio camino se veria media sala de cada.
const ESPERA: float = 0.45
const ARCHIVO_AJUSTES := "user://ajustes.cfg"

const PASOS: Array[Dictionary] = [
	{
		"titulo": "Bienvenido a Vacío",
		"color": Color(1.0, 0.85, 0.55),
		"texto": "Tienes que bajar los 12 pisos, hasta el núcleo de la Tierra.\n"
			+ "[k]{mover}[/k] para moverte.\n"
			+ "[k]{disparar}[/k] o [k]{raton}[/k] para disparar.\n"
			+ "[k]{pausa}[/k]: pausa, reiniciar o volver al menú.\n"
			+ "Cuando quieras, cruza la puerta: cada sala te enseña algo nuevo.",
	},
	{
		"titulo": "Tu ataque especial",
		"color": Color(0.8, 0.66, 1.0),
		"texto": "{especial}\n"
			+ "Solo tienes [k]uno por piso[/k]: vuelve al bajar al siguiente.\n"
			+ "Las [k]rocas[/k] son sólidas: te tapan y no las puedes cruzar.\n"
			+ "Arriba a la izquierda, tu [k]vida[/k]; arriba a la derecha, el [k]mapa[/k] del piso.",
	},
	{
		"titulo": "¡Enemigos!",
		"color": Color(1.0, 0.45, 0.38),
		"texto": "[k]Mata a todos los enemigos[/k]: las puertas no se abren hasta que no quede ninguno.\n"
			+ "El [k]gólem[/k] golpea el suelo a dos manos: apártate cuando levante los brazos.\n"
			+ "Los [k]murciélagos[/k] marcan una línea y se lanzan por ella: sal de la línea.\n"
			+ "Cada número es la vida que quitas; en rojo, la que te quitan.",
	},
	{
		"titulo": "Objetos",
		"color": Color(0.6, 1.0, 0.66),
		"texto": "Los [k]objetos[/k] te mejoran para toda la partida: pasa por encima para cogerlo.\n"
			+ "Hay uno en cada piso, y a veces lo suelta un enemigo.\n"
			+ "Desde el piso 2, al limpiar una sala puede caer un [k]vendaje[/k]: cura 60.",
	},
	{
		"titulo": "La bajada",
		"color": Color(1.0, 0.85, 0.55),
		"texto": "Entra en el [k]círculo[/k] para bajar al piso 2.\n"
			+ "Más abajo: más salas, más enemigos, pinchos, lava y agujeros.\n"
			+ "Cada piso esconde una [k]sala secreta[/k] con un cofre: si ves una pared agrietada, dispárale.\n"
			+ "Y en el piso 12 te espera el [k]Corazón del Núcleo[/k]. Suerte.",
	},
]

## Las ventanas que ya han salido. Estatico: el piso (y este nodo con el) se rehace
## al reiniciar, y la lista tiene que seguir sin volver a leer el archivo.
static var _vistas: Dictionary = {}
static var _cargadas: bool = false
static var _archivo: String = ARCHIVO_AJUSTES

var _salas: Array[Sala] = []
var _aviso: AvisoTutorial


## Para las pruebas que quieren ver como se guarda, sin tocar los ajustes de quien
## las lanza. Tienen que montar Principal en la raiz (ver _de_prueba).
static func usar_archivo(ruta: String) -> void:
	_archivo = ruta
	_vistas.clear()
	_cargadas = false


## Lo arranca Piso al construirse, con las salas ya hechas. La primera
## ventana sale nada mas empezar; las demas, al entrar en su sala.
func empezar(piso: Piso) -> void:
	_cargar()
	_salas = piso.salas()
	_aviso = AvisoTutorial.new()
	add_child(_aviso)
	piso.sala_cambiada.connect(_al_entrar)
	_al_entrar(_salas[0])


func _al_entrar(sala: Sala) -> void:
	var indice := _salas.find(sala)
	if indice < 0 or indice >= PASOS.size() or _vistas.has(_clave(indice)):
		return
	# Un temporizador que se para con el juego (el false): si se pausa justo
	# al entrar, la ventana espera a que se quite la pausa. Conectado a este
	# nodo y no con await: si el piso se va antes (en cooperativo se puede
	# bajar sin haberla cerrado), la conexion se va con el.
	get_tree().create_timer(ESPERA, false).timeout.connect(_mostrar.bind(indice))


func _mostrar(indice: int) -> void:
	var clave := _clave(indice)
	if _vistas.has(clave):
		return
	_vistas[clave] = true
	_guardar()
	var paso: Dictionary = PASOS[indice]
	_aviso.mostrar(paso["titulo"], _rellenar(paso["texto"]), paso["color"])


func _cargar() -> void:
	if _cargadas or _de_prueba():
		return
	_cargadas = true
	var ajustes := ConfigFile.new()
	# Sin archivo (la primera vez), ninguna vista.
	ajustes.load(_archivo)
	for clave: String in ajustes.get_value("tutorial", "vistas", PackedStringArray()):
		_vistas[clave] = true


func _guardar() -> void:
	if _de_prueba():
		return
	var ajustes := ConfigFile.new()
	ajustes.load(_archivo)
	ajustes.set_value("tutorial", "vistas", PackedStringArray(_vistas.keys()))
	ajustes.save(_archivo)


## La partida de verdad cuelga de la raiz; la de una escena de prueba, de esa escena.
func _de_prueba() -> bool:
	return not get_tree().root.has_node("Principal")


## La del especial va por mago: con otro mago cuenta otra cosa.
func _clave(indice: int) -> String:
	if indice == 1 and GestorProgreso.personaje_elegido != null:
		return "%d:%s" % [indice, GestorProgreso.personaje_elegido.nombre]
	return str(indice)


func _rellenar(texto: String) -> String:
	return texto.format({
		"mover": _mayuscula(Controles.teclas_mover()),
		"disparar": _mayuscula(Controles.teclas_disparar()),
		"raton": _tecla("disparar_raton"),
		"pausa": _tecla("pausar"),
		"especial": _linea_especial(),
	})


## La primera tecla que tenga esa accion, en minuscula si es una palabra («clic
## derecho», «espacio») y tal cual si es una letra («Q»).
static func _tecla(accion: String) -> String:
	for evento in Controles.teclas_de(accion):
		if evento != null:
			var nombre: String = Controles.nombre_de(evento)
			return nombre.to_lower() if nombre.length() > 1 else nombre
	return "sin tecla"


static func _mayuscula(texto: String) -> String:
	return texto.left(1).to_upper() + texto.substr(1)


## «[k]clic derecho[/k] o [k]espacio[/k]»: las dos formas de sacar el especial.
static func _teclas_especial() -> String:
	return "[k]%s[/k] o [k]%s[/k]" % [_tecla("cargar_ataque"), _tecla("cargar_ataque_teclado")]


## Lo que hace el especial del mago con el que se juega, y como se saca.
func _linea_especial() -> String:
	var mago := GestorProgreso.personaje_elegido
	if mago != null and mago.ataque_especial == PersonajeJugable.ESPECIAL_ESCUDO:
		return "Pulsa %s: sale tu [k]escudo burbuja[/k], que te cubre unos segundos." % _teclas_especial()
	if mago != null and mago.ataque_especial == PersonajeJugable.ESPECIAL_VENENO:
		return "Pulsa %s: salen tus [k]proyectiles de veneno[/k], que persiguen a los enemigos y los envenenan. Giran poco: mejor de cerca." % _teclas_especial()
	var nombre := mago.nombre_especial() if mago != null else "bola cargada"
	return "Mantén %s y suéltalo: sale tu [k]%s[/k]." % [_teclas_especial(), nombre]
